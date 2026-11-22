"""Standard-user Windows Task Scheduler autostart service (PC-HOST-002)."""

import logging
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional
from xml.sax.saxutils import escape as xml_escape

from app.core.config import settings
from app.schemas.health import AutostartStatusOut
from app.services.host_config import get_autostart_preferences, save_autostart_preferences

logger = logging.getLogger("app.services.autostart")

TASK_NAME = "AICompanionAutostart"


class AutostartConfigurationError(RuntimeError):
    """Raised when autostart registration fails or desktop binary is unavailable."""


class WindowsAutostartService:
    """Manages standard-user Windows Task Scheduler logon registration (LeastPrivilege, zero UAC)."""

    def _resolve_desktop_executable(self, explicit_exe: Optional[str] = None) -> Path:
        if explicit_exe and explicit_exe.strip():
            return Path(explicit_exe.strip()).resolve()
        env_exe = os.environ.get("COMPANION_DESKTOP_EXE", "").strip()
        if env_exe:
            return Path(env_exe).resolve()

        install_root = settings.APP_INSTALL_ROOT
        candidates = [
            install_root / "ai_companion_desktop.exe",
            install_root
            / "frontend"
            / "flutter"
            / "apps"
            / "desktop"
            / "build"
            / "windows"
            / "x64"
            / "runner"
            / "Release"
            / "ai_companion_desktop.exe",
            install_root
            / "frontend"
            / "flutter"
            / "apps"
            / "desktop"
            / "build"
            / "windows"
            / "x64"
            / "runner"
            / "Debug"
            / "ai_companion_desktop.exe",
        ]
        for candidate in candidates:
            if candidate.is_file():
                return candidate.resolve()
        return candidates[1].resolve()

    def build_task_xml(
        self,
        *,
        command: str,
        arguments: str,
        working_directory: str,
    ) -> str:
        """Render Task Scheduler v1.2 XML using entity-escaped fields and LeastPrivilege."""
        escaped_cmd = xml_escape(command)
        escaped_args = xml_escape(arguments)
        escaped_wd = xml_escape(working_directory)
        return (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">\n'
            "  <RegistrationInfo>\n"
            "    <Description>Start AI Companion Desktop at user logon.</Description>\n"
            "  </RegistrationInfo>\n"
            "  <Triggers>\n"
            "    <LogonTrigger>\n"
            "      <Enabled>true</Enabled>\n"
            "    </LogonTrigger>\n"
            "  </Triggers>\n"
            '  <Principals>\n'
            '    <Principal id="Author">\n'
            "      <LogonType>InteractiveToken</LogonType>\n"
            "      <RunLevel>LeastPrivilege</RunLevel>\n"
            "    </Principal>\n"
            "  </Principals>\n"
            "  <Settings>\n"
            "    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>\n"
            "    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>\n"
            "    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>\n"
            "    <AllowHardTerminate>false</AllowHardTerminate>\n"
            "    <StartWhenAvailable>true</StartWhenAvailable>\n"
            "    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>\n"
            "    <AllowStartOnDemand>true</AllowStartOnDemand>\n"
            "    <Enabled>true</Enabled>\n"
            "    <Hidden>false</Hidden>\n"
            "    <RunOnlyIfIdle>false</RunOnlyIfIdle>\n"
            "    <WakeToRun>false</WakeToRun>\n"
            "    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>\n"
            "    <Priority>7</Priority>\n"
            "  </Settings>\n"
            '  <Actions Context="Author">\n'
            "    <Exec>\n"
            f"      <Command>{escaped_cmd}</Command>\n"
            f"      <Arguments>{escaped_args}</Arguments>\n"
            f"      <WorkingDirectory>{escaped_wd}</WorkingDirectory>\n"
            "    </Exec>\n"
            "  </Actions>\n"
            "</Task>\n"
        )

    def _run_schtasks(self, args: list[str]) -> subprocess.CompletedProcess[str]:
        kwargs: dict = {
            "capture_output": True,
            "text": True,
            "timeout": 15,
        }
        if sys.platform == "win32":
            kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
        return subprocess.run(["schtasks.exe", *args], **kwargs)

    def get_status(self) -> AutostartStatusOut:
        prefs = get_autostart_preferences()
        if sys.platform != "win32":
            return AutostartStatusOut(
                supported=False,
                enabled=prefs["enabled"],
                task_registered=False,
                task_name=TASK_NAME,
                minimized_to_tray=prefs["minimized_to_tray"],
                command=None,
                working_directory=None,
                status_detail="Windows Task Scheduler autostart is unavailable on non-Windows hosts.",
            )

        registered = False
        registered_cmd: Optional[str] = None
        registered_wd: Optional[str] = None
        minimized = prefs["minimized_to_tray"]
        try:
            proc = self._run_schtasks(["/Query", "/TN", TASK_NAME, "/XML"])
            if proc.returncode == 0 and proc.stdout.strip():
                registered = True
                try:
                    root = ET.fromstring(proc.stdout)
                    ns = {"t": "http://schemas.microsoft.com/windows/2004/02/mit/task"}
                    cmd_el = root.find(".//t:Exec/t:Command", ns)
                    args_el = root.find(".//t:Exec/t:Arguments", ns)
                    wd_el = root.find(".//t:Exec/t:WorkingDirectory", ns)
                    cmd_text = cmd_el.text.strip() if cmd_el is not None and cmd_el.text else ""
                    args_text = args_el.text.strip() if args_el is not None and args_el.text else ""
                    registered_cmd = f"{cmd_text} {args_text}".strip() if cmd_text else None
                    registered_wd = wd_el.text.strip() if wd_el is not None and wd_el.text else None
                    if args_text:
                        minimized = "--minimized-to-tray" in args_text or "--autostart" in args_text
                except ET.ParseError:
                    pass
        except OSError as exc:
            return AutostartStatusOut(
                supported=True,
                enabled=False,
                task_registered=False,
                task_name=TASK_NAME,
                minimized_to_tray=minimized,
                command=None,
                working_directory=None,
                status_detail=f"Unable to query Windows Task Scheduler: {exc}",
            )

        return AutostartStatusOut(
            supported=True,
            enabled=registered,
            task_registered=registered,
            task_name=TASK_NAME,
            minimized_to_tray=minimized,
            command=registered_cmd,
            working_directory=registered_wd,
            status_detail=(
                "Registered in Windows Task Scheduler (LeastPrivilege, At Logon)."
                if registered
                else "Not registered in Windows Task Scheduler."
            ),
        )

    def set_enabled(
        self,
        enabled: bool,
        *,
        minimized_to_tray: bool = True,
        executable_path: Optional[str] = None,
        working_directory: Optional[str] = None,
    ) -> AutostartStatusOut:
        if sys.platform != "win32":
            save_autostart_preferences(enabled, minimized_to_tray)
            return AutostartStatusOut(
                supported=False,
                enabled=False,
                task_registered=False,
                task_name=TASK_NAME,
                minimized_to_tray=minimized_to_tray,
                status_detail="Windows Task Scheduler autostart is unavailable on non-Windows hosts.",
            )

        if not enabled:
            proc = self._run_schtasks(["/Delete", "/TN", TASK_NAME, "/F"])
            if proc.returncode != 0:
                verify = self._run_schtasks(["/Query", "/TN", TASK_NAME])
                if verify.returncode == 0:
                    err = (proc.stderr or proc.stdout or "").strip()
                    raise AutostartConfigurationError(f"Failed to remove Task Scheduler entry: {err}")
            save_autostart_preferences(False, minimized_to_tray)
            return AutostartStatusOut(
                supported=True,
                enabled=False,
                task_registered=False,
                task_name=TASK_NAME,
                minimized_to_tray=minimized_to_tray,
                command=None,
                working_directory=None,
                status_detail="Disabled (removed from Windows Task Scheduler).",
            )

        exe_path = self._resolve_desktop_executable(executable_path)
        if not exe_path.is_file():
            raise AutostartConfigurationError(
                f"Desktop executable not found at '{exe_path}'. Build or install AI Companion Desktop first."
            )
        wd_path = Path(working_directory).resolve() if working_directory else exe_path.parent
        args = "--minimized-to-tray" if minimized_to_tray else "--autostart-windowed"
        xml_content = self.build_task_xml(
            command=str(exe_path),
            arguments=args,
            working_directory=str(wd_path),
        )

        tmp_xml: Optional[Path] = None
        try:
            fd, raw_path = tempfile.mkstemp(prefix="aicompanion_autostart_", suffix=".xml")
            os.close(fd)
            tmp_xml = Path(raw_path)
            tmp_xml.write_text(xml_content, encoding="utf-8")
            proc = self._run_schtasks(["/Create", "/TN", TASK_NAME, "/XML", str(tmp_xml), "/F"])
            if proc.returncode != 0:
                err = (proc.stderr or proc.stdout or "").strip()
                raise AutostartConfigurationError(f"Failed to register Task Scheduler entry: {err}")
        finally:
            if tmp_xml is not None and tmp_xml.exists():
                try:
                    tmp_xml.unlink()
                except OSError:
                    pass

        save_autostart_preferences(True, minimized_to_tray)
        return AutostartStatusOut(
            supported=True,
            enabled=True,
            task_registered=True,
            task_name=TASK_NAME,
            minimized_to_tray=minimized_to_tray,
            command=f"{exe_path} {args}",
            working_directory=str(wd_path),
            status_detail="Registered in Windows Task Scheduler (LeastPrivilege, At Logon).",
        )
