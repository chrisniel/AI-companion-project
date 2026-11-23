"""Lazy host GPU VRAM and System RAM probe for dynamic model recommendations."""

import ctypes
from dataclasses import dataclass
import logging
import os
import sys
from typing import Optional

from app.core.config import settings

logger = logging.getLogger("app.services.hardware_probe")


@dataclass(frozen=True)
class HostHardwareInfo:
    """Detected or configured local host compute memory profile."""

    gpu_name: Optional[str]
    dedicated_vram_gb: float
    total_ram_gb: float
    available_ram_gb: float
    detection_source: str


_CACHED_HARDWARE: Optional[HostHardwareInfo] = None


def clear_hardware_probe_cache() -> None:
    """Reset cached hardware probe snapshot (for unit tests)."""
    global _CACHED_HARDWARE
    _CACHED_HARDWARE = None


def _probe_windows_memory() -> tuple[float, float]:
    """Read physical system RAM via Win32 GlobalMemoryStatusEx without external deps."""
    if sys.platform != "win32":
        return 16.0, 8.0

    class _MemoryStatusEx(ctypes.Structure):
        _fields_ = [
            ("dwLength", ctypes.c_ulong),
            ("dwMemoryLoad", ctypes.c_ulong),
            ("ullTotalPhys", ctypes.c_ulonglong),
            ("ullAvailPhys", ctypes.c_ulonglong),
            ("ullTotalPageFile", ctypes.c_ulonglong),
            ("ullAvailPageFile", ctypes.c_ulonglong),
            ("ullTotalVirtual", ctypes.c_ulonglong),
            ("ullAvailVirtual", ctypes.c_ulonglong),
            ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
        ]

    try:
        ms = _MemoryStatusEx()
        ms.dwLength = ctypes.sizeof(_MemoryStatusEx)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(ms)):
            total_gb = round(ms.ullTotalPhys / (1024 ** 3), 2)
            avail_gb = round(ms.ullAvailPhys / (1024 ** 3), 2)
            return max(total_gb, 0.5), max(avail_gb, 0.25)
    except Exception as exc:
        logger.debug(f"GlobalMemoryStatusEx probe failed: {exc}")
    return 16.0, 8.0


def _probe_windows_gpu_vram() -> tuple[Optional[str], Optional[float]]:
    """Inspect Windows display adapter registry keys (64-bit qwMemorySize) for max discrete VRAM."""
    if sys.platform != "win32":
        return None, None
    try:
        import winreg

        base_key = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
        best_name: Optional[str] = None
        best_vram_bytes = 0

        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, base_key) as root_key:
            for idx in range(32):
                try:
                    sub_name = winreg.EnumKey(root_key, idx)
                except OSError:
                    break
                if not sub_name.isdigit():
                    continue
                try:
                    with winreg.OpenKey(root_key, sub_name) as sub_key:
                        try:
                            desc = str(winreg.QueryValueEx(sub_key, "DriverDesc")[0]).strip()
                        except OSError:
                            continue
                        if not desc or "microsoft basic display" in desc.lower():
                            continue

                        vram_bytes = 0
                        try:
                            raw_qw = winreg.QueryValueEx(sub_key, "HardwareInformation.qwMemorySize")[0]
                            if isinstance(raw_qw, bytes):
                                vram_bytes = int.from_bytes(raw_qw, "little", signed=False)
                            else:
                                vram_bytes = int(raw_qw)
                        except (OSError, ValueError, TypeError):
                            try:
                                raw_dw, _ = winreg.QueryValueEx(sub_key, "HardwareInformation.MemorySize")
                                if isinstance(raw_dw, bytes):
                                    vram_bytes = int.from_bytes(raw_dw, "little", signed=False)
                                else:
                                    vram_bytes = int(raw_dw) & 0xFFFFFFFF
                            except (OSError, ValueError, TypeError):
                                vram_bytes = 0

                        # Ignore adapters reporting under 256 MB (basic/virtual stubs)
                        if vram_bytes >= 256 * 1024 * 1024 and vram_bytes > best_vram_bytes:
                            best_vram_bytes = vram_bytes
                            best_name = desc
                except OSError:
                    continue

        if best_vram_bytes > 0:
            return best_name, round(best_vram_bytes / (1024 ** 3), 2)
    except Exception as exc:
        logger.debug(f"Windows GPU registry probe failed: {exc}")
    return None, None


def probe_host_hardware(*, force_refresh: bool = False) -> HostHardwareInfo:
    """Return cached or freshly probed host GPU VRAM and RAM details (lazy, no import side effects)."""
    global _CACHED_HARDWARE
    if _CACHED_HARDWARE is not None and not force_refresh:
        return _CACHED_HARDWARE

    env_vram_raw = os.environ.get("HOST_DEDICATED_VRAM_GB", "").strip()
    total_ram_gb, avail_ram_gb = _probe_windows_memory()

    if env_vram_raw:
        try:
            env_vram = max(0.5, float(env_vram_raw))
            info = HostHardwareInfo(
                gpu_name="Configured VRAM Override",
                dedicated_vram_gb=round(env_vram, 2),
                total_ram_gb=total_ram_gb,
                available_ram_gb=avail_ram_gb,
                detection_source="env_override",
            )
            _CACHED_HARDWARE = info
            return info
        except ValueError:
            pass

    gpu_name, probed_vram = _probe_windows_gpu_vram()
    if probed_vram is not None:
        info = HostHardwareInfo(
            gpu_name=gpu_name,
            dedicated_vram_gb=probed_vram,
            total_ram_gb=total_ram_gb,
            available_ram_gb=avail_ram_gb,
            detection_source="windows_winreg",
        )
        _CACHED_HARDWARE = info
        return info

    fallback = HostHardwareInfo(
        gpu_name=None,
        dedicated_vram_gb=round(float(settings.HOST_DEDICATED_VRAM_GB), 2),
        total_ram_gb=total_ram_gb,
        available_ram_gb=avail_ram_gb,
        detection_source="config_default",
    )
    _CACHED_HARDWARE = fallback
    return fallback
