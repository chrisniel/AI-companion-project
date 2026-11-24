"""Host Resource Governance & Auto Gaming Mode engine (PC-RESOURCE-001..004, DEBT-V1-07)."""

from __future__ import annotations

import asyncio
import ctypes
from ctypes import wintypes
import logging
import sys
import time
from typing import Callable, Optional

from app.core.config import settings
from app.schemas.health import ResourcePolicyStatusOut, ResourcePolicyUpdateRequest
from app.services.hardware_probe import (
    probe_live_gpu_telemetry,
    probe_live_system_memory,
)
from app.services.host_config import (
    get_resource_policy_config,
    get_saved_hardware_profile,
    save_resource_policy_config,
)
from app.services.llm.base import BaseLLMProvider, ResourceApplyOutcome

logger = logging.getLogger("app.services.resource_governor")

_TH32CS_SNAPPROCESS = 0x00000002
_INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value


class _PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD),
        ("cntUsage", wintypes.DWORD),
        ("th32ProcessID", wintypes.DWORD),
        ("th32DefaultHeapID", ctypes.c_size_t),
        ("th32ModuleID", wintypes.DWORD),
        ("cntThreads", wintypes.DWORD),
        ("th32ParentProcessID", wintypes.DWORD),
        ("pcPriClassBase", wintypes.LONG),
        ("dwFlags", wintypes.DWORD),
        ("szExeFile", wintypes.WCHAR * 260),
    ]


def scan_running_process_names() -> set[str]:
    """Enumerate running process executable basenames via standard-user Win32 Toolhelp32."""
    if sys.platform != "win32":
        return set()

    kernel32 = ctypes.windll.kernel32
    kernel32.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel32.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(_PROCESSENTRY32W)]
    kernel32.Process32FirstW.restype = wintypes.BOOL
    kernel32.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(_PROCESSENTRY32W)]
    kernel32.Process32NextW.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL

    snapshot = kernel32.CreateToolhelp32Snapshot(_TH32CS_SNAPPROCESS, 0)
    if not snapshot or snapshot == _INVALID_HANDLE_VALUE:
        return set()

    names: set[str] = set()
    try:
        entry = _PROCESSENTRY32W()
        entry.dwSize = ctypes.sizeof(_PROCESSENTRY32W)
        ok = kernel32.Process32FirstW(snapshot, ctypes.byref(entry))
        while ok:
            exe = (entry.szExeFile or "").strip().lower()
            if exe:
                names.add(exe)
            ok = kernel32.Process32NextW(snapshot, ctypes.byref(entry))
    except Exception as exc:
        logger.debug("Win32 process snapshot enumeration failed: %s", exc)
    finally:
        kernel32.CloseHandle(snapshot)
    return names


def _default_provider_resolver() -> BaseLLMProvider:
    from app.services.llm.manager import llm_manager

    return llm_manager.get_provider()


class ResourceGovernor:
    """Coordinates Normal, Low-Impact, and Auto Gaming host posture."""

    never_triggers_cloud: bool = True

    def __init__(
        self,
        *,
        process_scanner: Callable[[], set[str]] = scan_running_process_names,
        clock: Callable[[], float] = time.monotonic,
        provider_resolver: Callable[[], BaseLLMProvider] = _default_provider_resolver,
    ) -> None:
        self._process_scanner = process_scanner
        self._clock = clock
        self._provider_resolver = provider_resolver
        self._lock: Optional[asyncio.Lock] = None
        self._lock_loop: Optional[asyncio.AbstractEventLoop] = None

        self._requested_mode: str = "normal"
        self._effective_mode: str = "normal"
        self._low_impact_active: bool = False
        self._low_impact_strategy: str = "cpu_eco"
        self._low_impact_model_id: Optional[str] = None
        self._game_process_list: list[str] = []
        self._detected_active_games: list[str] = []
        self._cooldown_seconds: int = 45
        self._cooldown_started_at: Optional[float] = None
        self._cooldown_remaining_seconds: int = 0
        self._transition_state: str = "idle"
        self._degradation_reason: Optional[str] = None

    def _get_lock(self) -> asyncio.Lock:
        loop = asyncio.get_running_loop()
        if self._lock is None or self._lock_loop is not loop:
            self._lock = asyncio.Lock()
            self._lock_loop = loop
        return self._lock

    @property
    def low_impact_active(self) -> bool:
        return self._low_impact_active

    @property
    def should_defer_background_work(self) -> bool:
        return self._low_impact_active

    @property
    def detected_active_games(self) -> list[str]:
        return list(self._detected_active_games)

    @property
    def cooldown_remaining_seconds(self) -> int:
        return self._cooldown_remaining_seconds

    async def evaluate_once(self) -> ResourceApplyOutcome:
        """Evaluate host configuration + process watchlist and apply non-blocking LLM policy."""
        async with self._get_lock():
            cfg = get_resource_policy_config()
            mode = cfg["resource_mode"]
            strategy = cfg["low_impact_strategy"]
            model_id = cfg["low_impact_model_id"]
            watchlist: list[str] = cfg["game_process_list"]
            cooldown_secs = int(cfg["cooldown_seconds"])

            self._requested_mode = mode
            self._low_impact_strategy = strategy
            self._low_impact_model_id = model_id
            self._game_process_list = list(watchlist)
            self._cooldown_seconds = cooldown_secs

            now_mono = self._clock()
            target_low_impact = False
            effective_mode = "normal"
            detected_games: list[str] = []

            if mode == "normal":
                self._cooldown_started_at = None
                self._cooldown_remaining_seconds = 0
                target_low_impact = False
                effective_mode = "normal"
            elif mode == "low_impact":
                self._cooldown_started_at = None
                self._cooldown_remaining_seconds = 0
                target_low_impact = True
                effective_mode = "low_impact"
            else:  # "auto"
                if watchlist:
                    try:
                        running = {name.lower() for name in self._process_scanner()}
                    except Exception as exc:
                        logger.debug("Process scanner error: %s", exc)
                        running = set()
                    detected_games = [exe for exe in watchlist if exe in running]

                if detected_games:
                    self._cooldown_started_at = None
                    self._cooldown_remaining_seconds = 0
                    target_low_impact = True
                    effective_mode = "low_impact"
                elif self._low_impact_active:
                    # Hysteresis cooldown window after game processes close.
                    if self._cooldown_started_at is None:
                        self._cooldown_started_at = now_mono
                    elapsed = max(0.0, now_mono - self._cooldown_started_at)
                    remaining = max(0, int(round(cooldown_secs - elapsed)))
                    if elapsed < float(cooldown_secs) and remaining > 0:
                        self._cooldown_remaining_seconds = remaining
                        target_low_impact = True
                        effective_mode = "low_impact"
                    else:
                        self._cooldown_started_at = None
                        self._cooldown_remaining_seconds = 0
                        target_low_impact = False
                        effective_mode = "normal"
                else:
                    self._cooldown_started_at = None
                    self._cooldown_remaining_seconds = 0
                    target_low_impact = False
                    effective_mode = "normal"

            self._detected_active_games = detected_games
            self._low_impact_active = target_low_impact
            self._effective_mode = effective_mode

            provider = self._provider_resolver()
            self._transition_state = "applying"
            outcome = await provider.apply_resource_policy(
                low_impact_active=target_low_impact,
                strategy=strategy,
                lightweight_model_id=model_id,
            )
            if not outcome.applied:
                self._transition_state = outcome.deferred_reason or "deferred_model_load"
            else:
                self._transition_state = "idle"
            self._degradation_reason = outcome.degradation_reason
            return outcome

    async def get_status(self) -> ResourcePolicyStatusOut:
        """Assemble truthful live resource governance status and hardware telemetry."""
        cfg = get_resource_policy_config()
        provider = self._provider_resolver()
        override = provider.get_resource_override_status()
        provider_status = await provider.get_status()

        total_ram, avail_ram, ram_src = probe_live_system_memory()
        gpu_name, gpu_vram, gpu_src = probe_live_gpu_telemetry()

        if ram_src != "unavailable" and gpu_src != "unavailable":
            telemetry_source = f"{ram_src}+{gpu_src}"
        elif ram_src != "unavailable":
            telemetry_source = ram_src
        elif gpu_src != "unavailable":
            telemetry_source = gpu_src
        else:
            telemetry_source = "unavailable"

        requested_profile = (
            getattr(provider_status, "requested_profile", None)
            or get_saved_hardware_profile()
            or settings.LLM_PROFILE
        )
        applied_profile = (
            getattr(provider_status, "applied_profile", None)
            or override.get("effective_profile")
        )

        return ResourcePolicyStatusOut(
            requested_mode=cfg["resource_mode"],
            effective_mode=self._effective_mode if self._requested_mode == cfg["resource_mode"] else ("low_impact" if self._low_impact_active else "normal"),
            low_impact_active=self._low_impact_active,
            low_impact_strategy=cfg["low_impact_strategy"],
            low_impact_model_id=cfg["low_impact_model_id"],
            game_process_list=cfg["game_process_list"],
            detected_active_games=list(self._detected_active_games),
            cooldown_seconds=cfg["cooldown_seconds"],
            cooldown_remaining_seconds=self._cooldown_remaining_seconds,
            transition_state=self._transition_state,
            degradation_reason=self._degradation_reason or override.get("degradation_reason"),
            deferred_background_work=self.should_defer_background_work,
            host_gpu_name=gpu_name,
            host_vram_gb=gpu_vram,
            host_ram_gb=total_ram,
            available_ram_gb=avail_ram,
            applied_profile=applied_profile,
            requested_profile=requested_profile,
            telemetry_source=telemetry_source,
        )

    async def update_policy(self, request: ResourcePolicyUpdateRequest) -> ResourcePolicyStatusOut:
        """Persist validated host resource settings, reset cooldown on explicit switch, and apply."""
        save_resource_policy_config(
            resource_mode=request.resource_mode,
            low_impact_strategy=request.low_impact_strategy,
            low_impact_model_id=request.low_impact_model_id,
            clear_low_impact_model=request.clear_low_impact_model,
            game_process_list=request.game_process_list,
            cooldown_seconds=request.cooldown_seconds,
        )
        if request.resource_mode in ("normal", "low_impact"):
            self._cooldown_started_at = None
            self._cooldown_remaining_seconds = 0
        await self.evaluate_once()
        return await self.get_status()


resource_governor = ResourceGovernor()


async def run_periodic_resource_governor(
    governor: Optional[ResourceGovernor] = None,
    interval_seconds: Optional[float] = None,
) -> None:
    """Periodic host resource monitor loop run inside FastAPI lifespan."""
    gov = governor or resource_governor
    interval = max(1.0, float(interval_seconds or settings.RESOURCE_POLL_INTERVAL_SECONDS))
    try:
        await gov.evaluate_once()
    except asyncio.CancelledError:
        return
    except Exception as exc:
        logger.warning("Initial resource governor evaluation failed: %s", exc)

    while True:
        try:
            await asyncio.sleep(interval)
            await gov.evaluate_once()
        except asyncio.CancelledError:
            break
        except Exception as exc:
            logger.error("Error in resource governor loop: %s", exc, exc_info=True)
