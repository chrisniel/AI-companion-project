"""Tests for M5 Batch A Host Resource Governance & Gaming Mode (PC-RESOURCE-001..004)."""

import asyncio
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path
import time
import uuid

from httpx import AsyncClient
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.alarm import Alarm
from app.models.conversation import Conversation
from app.models.profile import Profile
from app.models.reminder import Reminder
from app.models.routine import Routine
from app.services.llm.mock import MockLLMProvider
from app.services.llm.runtime_state import LLMRuntimeState


def _configure_temp_host_config(tmp_path: Path, monkeypatch) -> Path:
    data_root = tmp_path / "data"
    library_dir = tmp_path / "library"
    models_dir = tmp_path / "models"
    (data_root / "config").mkdir(parents=True, exist_ok=True)
    library_dir.mkdir(parents=True, exist_ok=True)
    models_dir.mkdir(parents=True, exist_ok=True)
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(data_root))
    monkeypatch.setenv("COMPANION_LIBRARY_ROOT", str(library_dir))
    monkeypatch.setattr(settings, "MODELS_DIR", models_dir)
    monkeypatch.setattr(settings, "LLAMA_MODELS_DIR", models_dir)
    return data_root


def test_host_config_resource_policy_validation_and_thread_safety(tmp_path, monkeypatch):
    from app.services.host_config import (
        get_resource_policy_config,
        get_saved_hardware_profile,
        get_saved_model_selection,
        normalize_game_process_list,
        save_hardware_profile,
        save_model_selection,
        save_resource_policy_config,
    )

    _configure_temp_host_config(tmp_path, monkeypatch)
    save_model_selection("qwen3-8b")
    save_hardware_profile("maximum")

    # Rejects paths, invalid Windows filename chars, non-exe, forbidden system/runtime executables, and >64 items
    with pytest.raises(ValueError):
        normalize_game_process_list([r"C:\Games\game.exe"])
    with pytest.raises(ValueError):
        normalize_game_process_list(["not_an_exe.txt"])
    with pytest.raises(ValueError):
        normalize_game_process_list(["bad*name.exe"])
    with pytest.raises(ValueError):
        normalize_game_process_list(["bad?.exe"])
    with pytest.raises(ValueError):
        normalize_game_process_list(["..exe"])
    with pytest.raises(ValueError):
        normalize_game_process_list(["svchost.exe"])
    with pytest.raises(ValueError):
        normalize_game_process_list(["ai_companion_desktop.exe"])
    with pytest.raises(ValueError):
        normalize_game_process_list([f"game_{i}.exe" for i in range(65)])

    # Accepts valid Windows symbols (+, (), [], &) and deduplicates case-insensitively
    normalized = normalize_game_process_list([
        "Cyberpunk2077.exe",
        "cyberpunk2077.exe",
        "Valorant.exe",
        "Notepad++.exe",
        "Game (x64).exe",
        "Subnautica [DX11].exe",
        "A&B!@#.exe",
    ])
    assert normalized == [
        "cyberpunk2077.exe",
        "valorant.exe",
        "notepad++.exe",
        "game (x64).exe",
        "subnautica [dx11].exe",
        "a&b!@#.exe",
    ]

    saved = save_resource_policy_config(
        resource_mode="auto",
        low_impact_strategy="cpu_eco",
        game_process_list=["Cyberpunk2077.exe", "eldenring.exe"],
        cooldown_seconds=30,
    )
    assert saved["resource_mode"] == "auto"
    assert saved["game_process_list"] == ["cyberpunk2077.exe", "eldenring.exe"]
    assert saved["cooldown_seconds"] == 30
    assert get_saved_model_selection() == "qwen3-8b"
    assert get_saved_hardware_profile() == "maximum"

    # Concurrent read/write stress test across threads never corrupts JSON or loses model selection
    def _worker(idx: int) -> None:
        save_resource_policy_config(
            resource_mode="low_impact" if idx % 2 else "auto",
            cooldown_seconds=15 + (idx % 10),
        )

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(_worker, range(32)))

    cfg = get_resource_policy_config()
    assert cfg["resource_mode"] in ("low_impact", "auto")
    assert get_saved_model_selection() == "qwen3-8b"
    assert get_saved_hardware_profile() == "maximum"


def test_hardware_probe_live_telemetry_is_truthful_without_fabrication(monkeypatch):
    from app.services.hardware_probe import probe_live_gpu_telemetry, probe_live_system_memory

    monkeypatch.delenv("HOST_DEDICATED_VRAM_GB", raising=False)
    # When Windows API probe returns unavailable (simulated non-win32), returns None cleanly
    monkeypatch.setattr("app.services.hardware_probe.sys.platform", "linux")
    total_ram, avail_ram, ram_src = probe_live_system_memory()
    gpu_name, gpu_vram, gpu_src = probe_live_gpu_telemetry()
    assert total_ram is None and avail_ram is None and ram_src == "unavailable"
    assert gpu_name is None and gpu_vram is None and gpu_src == "unavailable"


@pytest.mark.asyncio
async def test_resource_governor_auto_gaming_hysteresis_cooldown_and_manual_override(tmp_path, monkeypatch):
    from app.services.host_config import save_resource_policy_config
    from app.services.resource_governor import ResourceGovernor

    _configure_temp_host_config(tmp_path, monkeypatch)
    save_resource_policy_config(
        resource_mode="auto",
        low_impact_strategy="cpu_eco",
        game_process_list=["eldenring.exe"],
        cooldown_seconds=20,
    )

    fake_now = [1000.0]
    running_procs = [set()]
    provider = MockLLMProvider(default_model="qwen3-8b")
    await provider.load_model("qwen3-8b", profile="balanced")

    governor = ResourceGovernor(
        process_scanner=lambda: set(running_procs[0]),
        clock=lambda: fake_now[0],
        provider_resolver=lambda: provider,
    )

    # 1. Idle normal state
    await governor.evaluate_once()
    assert governor.low_impact_active is False
    assert governor.should_defer_background_work is False

    # 2. Game detected -> enters Low-Impact immediately, unloads heavy model, sets runtime override only
    running_procs[0] = {"eldenring.exe", "explorer.exe"}
    await governor.evaluate_once()
    assert governor.low_impact_active is True
    assert governor.should_defer_background_work is True
    assert governor.detected_active_games == ["eldenring.exe"]
    assert provider.is_loaded() is False
    override = provider.get_resource_override_status()
    assert override["low_impact_active"] is True
    assert override["effective_profile"] == "eco"

    # 3. Game exits -> enters cooldown window, stays in Low-Impact for cooldown_seconds
    running_procs[0] = {"explorer.exe"}
    fake_now[0] = 1005.0
    await governor.evaluate_once()
    assert governor.low_impact_active is True
    assert governor.cooldown_remaining_seconds == 20

    fake_now[0] = 1020.0
    await governor.evaluate_once()
    assert governor.low_impact_active is True
    assert governor.cooldown_remaining_seconds == 5

    # 4. Game relaunches mid-cooldown -> resets cooldown cleanly
    running_procs[0] = {"eldenring.exe"}
    fake_now[0] = 1021.0
    await governor.evaluate_once()
    assert governor.low_impact_active is True
    assert governor.cooldown_remaining_seconds == 0

    # 5. Game exits and full cooldown elapses -> returns to Normal lazily (does NOT eager reload heavy model)
    running_procs[0] = set()
    fake_now[0] = 1030.0
    await governor.evaluate_once()
    fake_now[0] = 1051.0
    await governor.evaluate_once()
    assert governor.low_impact_active is False
    assert provider.is_loaded() is False  # Lazy exit invariant: never eagerly reloads heavy model

    # 6. Manual Normal while in Auto+cooldown resets cooldown immediately
    running_procs[0] = {"eldenring.exe"}
    fake_now[0] = 1060.0
    await governor.evaluate_once()
    running_procs[0] = set()
    fake_now[0] = 1061.0
    await governor.evaluate_once()
    assert governor.cooldown_remaining_seconds == 20

    save_resource_policy_config(resource_mode="normal")
    await governor.evaluate_once()
    assert governor.low_impact_active is False
    assert governor.cooldown_remaining_seconds == 0


@pytest.mark.asyncio
async def test_llama_cpp_non_blocking_deferral_and_transitional_zero_ngl_snapshot(tmp_path, monkeypatch):
    from app.services.host_config import save_hardware_profile, save_resource_policy_config
    from app.services.llm.llama_cpp import LlamaCppProvider

    _configure_temp_host_config(tmp_path, monkeypatch)
    save_hardware_profile("balanced")
    provider = LlamaCppProvider()

    # Active generation returns immediately without awaiting _lock
    lease = object()
    provider._active_generations.add(lease)
    res_turn = await provider.apply_resource_policy(
        low_impact_active=True,
        strategy="cpu_eco",
    )
    assert res_turn.applied is False
    assert res_turn.deferred_reason == "deferred_active_turn"
    provider._active_generations.clear()

    # Locked provider returns deferred_model_load immediately without hanging
    await provider._lock.acquire()
    try:
        res_locked = await asyncio.wait_for(
            provider.apply_resource_policy(low_impact_active=True, strategy="cpu_eco"),
            timeout=0.5,
        )
        assert res_locked.applied is False
        assert res_locked.deferred_reason == "deferred_model_load"
    finally:
        provider._lock.release()

    # Light-weight strategy missing model degrades cleanly to cpu_eco with degradation_reason
    res_deg = await provider.apply_resource_policy(
        low_impact_active=True,
        strategy="lightweight_model",
        lightweight_model_id="missing-tiny-model.gguf",
    )
    assert res_deg.applied is True
    assert res_deg.effective_profile == "eco"
    assert res_deg.degradation_reason == "lightweight_model_unavailable"

    # Transitional MODEL_LOADING status with _applied_gpu_layers == 0 must NOT falsy fallback to balanced (28)
    provider._runtime_state = LLMRuntimeState.MODEL_LOADING
    provider._applied_profile = "eco"
    provider._applied_gpu_layers = 0
    provider._applied_context_size = 2048
    snap = await provider.get_status()
    assert snap.applied_gpu_layers == 0
    assert snap.gpu_layers == 0
    assert snap.requested_profile == "balanced"
    assert snap.applied_profile == "eco"

    # Unload when idle enforces RESOURCE_LOW_IMPACT_IDLE_SECONDS even with router sleep enabled
    monkeypatch.setattr(settings, "RESOURCE_LOW_IMPACT_IDLE_SECONDS", 1.0)
    monkeypatch.setattr(settings, "LLAMA_ROUTER_IDLE_TIMEOUT", 900)
    provider._runtime_state = LLMRuntimeState.MODEL_READY
    provider._server_is_active = True
    provider._active_model_name = "qwen3-8b"
    provider._last_active_at = datetime.now(timezone.utc) - timedelta(seconds=10)
    unload_calls = []

    async def _fake_router_unload(runtime_id: str) -> bool:
        unload_calls.append(runtime_id)
        return True

    monkeypatch.setattr(provider, "_router_unload_model", _fake_router_unload)
    res_idle = await provider.apply_resource_policy(
        low_impact_active=True,
        strategy="unload_when_idle",
    )
    assert res_idle.applied is True
    assert provider.is_loaded() is False
    assert len(unload_calls) == 1

    # Lazy exit stops eco Core-managed router instead of eagerly starting balanced heavy load
    save_resource_policy_config(resource_mode="normal")
    res_exit = await provider.apply_resource_policy(low_impact_active=False, strategy="cpu_eco")
    assert res_exit.applied is True
    assert provider.is_loaded() is False


@pytest.mark.asyncio
async def test_llama_cpp_mode0_mode1_lightweight_sets_temp_flag_and_strategy_switch_unloads(
    tmp_path, monkeypatch
):
    from app.services.host_config import save_hardware_profile, save_resource_policy_config
    from app.services.llm.llama_cpp import LlamaCppProvider

    _configure_temp_host_config(tmp_path, monkeypatch)
    save_hardware_profile("balanced")
    save_resource_policy_config(
        resource_mode="low_impact",
        low_impact_strategy="lightweight_model",
        low_impact_model_id="tiny-helper.gguf",
    )

    class _AliveProc:
        def poll(self):
            return None

    async def _always_healthy():
        return True

    async def _always_loaded(_runtime_id: str) -> bool:
        return True

    from types import SimpleNamespace

    fake_entry = SimpleNamespace(
        runtime_model_id="tiny-helper",
        manifest=SimpleNamespace(id="tiny-helper", primary_file="tiny-helper.gguf"),
        library_state=SimpleNamespace(primary_file_exists=True, root_kind="factory"),
    )
    monkeypatch.setattr(
        "app.services.llm.llama_cpp.find_model_registry_entry",
        lambda _ident: fake_entry,
    )

    for mode_label in ("mode0", "mode1"):
        provider = LlamaCppProvider()
        monkeypatch.setattr(provider, "_models_dir_for_entry", lambda _e: tmp_path / "models")
        if mode_label == "mode0":
            provider._managed_by_core = True
            provider._server_process = _AliveProc()
            provider._server_is_active = True
            provider._active_models_dir = (tmp_path / "models").resolve()
            provider._applied_profile = "balanced"
        else:
            provider._managed_by_core = False
            monkeypatch.setattr(provider, "_check_port_listening", lambda _h, _p: True)

        monkeypatch.setattr(provider, "_check_external_server", _always_healthy)
        monkeypatch.setattr(provider, "_router_load_model", _always_loaded)
        monkeypatch.setattr(provider, "_start_idle_monitor", lambda: None)

        await provider.apply_resource_policy(
            low_impact_active=True,
            strategy="lightweight_model",
            lightweight_model_id="tiny-helper.gguf",
        )
        ok = await provider.load_model()
        assert ok is True
        assert provider._resource_using_temporary_model is True

        unload_calls = []

        async def _track_unload():
            unload_calls.append("unloaded")
            provider._runtime_state = LLMRuntimeState.MODEL_UNLOADED
            provider._active_model_name = None
            provider._resource_using_temporary_model = False

        monkeypatch.setattr(provider, "_unload_model_locked", _track_unload)
        await provider.apply_resource_policy(
            low_impact_active=False,
            strategy="lightweight_model",
        )
        assert unload_calls == ["unloaded"]
        assert provider._resource_using_temporary_model is False

    # Switching lightweight_model -> unload_when_idle while already in Low-Impact unloads immediately
    switch_provider = LlamaCppProvider()
    switch_provider._resource_low_impact_active = True
    switch_provider._resource_strategy = "lightweight_model"
    switch_provider._resource_lightweight_model_id = "tiny-helper.gguf"
    switch_provider._runtime_state = LLMRuntimeState.MODEL_READY
    switch_provider._server_is_active = True
    switch_provider._active_model_name = "tiny-helper.gguf"
    switch_unloads = []

    async def _track_switch_unload():
        switch_unloads.append("unloaded")
        switch_provider._runtime_state = LLMRuntimeState.MODEL_UNLOADED
        switch_provider._active_model_name = None
        switch_provider._resource_using_temporary_model = False

    monkeypatch.setattr(switch_provider, "_unload_model_locked", _track_switch_unload)
    await switch_provider.apply_resource_policy(
        low_impact_active=True,
        strategy="unload_when_idle",
    )
    assert switch_unloads == ["unloaded"]


@pytest.mark.asyncio
async def test_low_impact_defers_routines_and_non_explicit_extraction_while_preserving_alarms_and_reminders(
    tmp_path, monkeypatch, test_session: AsyncSession, profile_id: str
):
    from app.services.assistant.orchestrator import _run_post_turn_memory_extraction
    from app.services.resource_governor import resource_governor
    from app.services.scheduler.service import SchedulerService

    _configure_temp_host_config(tmp_path, monkeypatch)
    profile = await test_session.get(Profile, profile_id)
    assert profile is not None
    now = datetime(2026, 11, 24, 12, 0, 0, tzinfo=timezone.utc)

    due_alarm = Alarm(
        id=str(uuid.uuid4()),
        profile_id=profile_id,
        label="Critical Alarm",
        scheduled_at=now - timedelta(seconds=10),
        time_of_day="12:00",
        timezone="UTC",
        enabled=True,
        status="armed",
        bypass_quiet_hours=True,
        origin="user",
    )
    due_reminder = Reminder(
        id=str(uuid.uuid4()),
        profile_id=profile_id,
        title="Medication",
        scheduled_at=now - timedelta(seconds=10),
        timezone="UTC",
        status="scheduled",
        bypass_quiet_hours=False,
        origin="user",
    )
    due_routine = Routine(
        id=str(uuid.uuid4()),
        profile_id=profile_id,
        title="Evening Digest",
        time_of_day="12:00",
        timezone="UTC",
        enabled=True,
        bypass_quiet_hours=False,
        fallback_message="Check your day",
        next_run_at=now - timedelta(seconds=10),
    )
    test_session.add_all([due_alarm, due_reminder, due_routine])
    await test_session.commit()

    monkeypatch.setattr(resource_governor, "_low_impact_active", True)
    try:
        svc = SchedulerService(test_session)
        emitted = await svc.run_tick(
            now=now,
            sweep_memories=False,
            defer_non_bypass_routines=resource_governor.should_defer_background_work,
        )
        emitted_types = {ev.source_type for ev in emitted}
        assert "alarm" in emitted_types
        assert "reminder" in emitted_types
        assert "routine" not in emitted_types

        # Routine kept original next_run_at -> after Low-Impact ends past grace window, emits truthful missed_catchup
        await test_session.refresh(due_routine)
        assert due_routine.last_status != "completed"
        later = now + timedelta(seconds=settings.SCHEDULER_MISSED_GRACE_SECONDS + 30)
        monkeypatch.setattr(resource_governor, "_low_impact_active", False)
        emitted_after = await svc.run_tick(now=later, defer_non_bypass_routines=False)
        routine_evs = [ev for ev in emitted_after if ev.source_id == due_routine.id]
        assert len(routine_evs) == 1
        assert routine_evs[0].status == "missed_catchup"

        # Non-explicit memory extraction skipped under Low-Impact; explicit intent proceeds
        conv = Conversation(id=str(uuid.uuid4()), profile_id=profile_id, title="Gov test")
        test_session.add(conv)
        await test_session.commit()
        monkeypatch.setattr(resource_governor, "_low_impact_active", True)
        extract_calls = []

        async def _fake_extract(**kwargs):
            extract_calls.append(kwargs["user_text"])
            return []

        monkeypatch.setattr("app.services.assistant.orchestrator.extract_memory_candidates", _fake_extract)
        dummy_provider = MockLLMProvider(default_model="qwen3-8b")
        await dummy_provider.load_model("qwen3-8b")
        monkeypatch.setattr("app.services.assistant.orchestrator.get_llm_provider", lambda: dummy_provider)

        await _run_post_turn_memory_extraction(
            profile_id=profile_id,
            user_text="I went for a walk in the park today",
            assistant_text="Sounds nice!",
            source_message_id=str(uuid.uuid4()),
            engine=test_session.bind,
        )
        assert extract_calls == []

        await _run_post_turn_memory_extraction(
            profile_id=profile_id,
            user_text="Remember that I am allergic to peanuts",
            assistant_text="Got it, I will remember that.",
            source_message_id=str(uuid.uuid4()),
            engine=test_session.bind,
        )
        assert len(extract_calls) == 1
    finally:
        monkeypatch.setattr(resource_governor, "_low_impact_active", False)


@pytest.mark.asyncio
async def test_system_resources_endpoints_host_admin_and_shutdown_guard(
    tmp_path, monkeypatch, client: AsyncClient, auth_headers: dict, host_admin_headers: dict
):
    from app.core.runtime_lifecycle import runtime_lifecycle
    from app.services.resource_governor import resource_governor

    _configure_temp_host_config(tmp_path, monkeypatch)

    # Unauthenticated / profile session rejected fail-closed
    unauth = await client.get("/api/v1/system/resources")
    assert unauth.status_code in (401, 403)
    prof_only = await client.get("/api/v1/system/resources", headers=auth_headers)
    assert prof_only.status_code in (401, 403)

    # Host Admin GET succeeds
    get_res = await client.get("/api/v1/system/resources", headers=host_admin_headers)
    assert get_res.status_code == 200
    body = get_res.json()
    assert body["requested_mode"] == "normal"
    assert "never_triggers_cloud" not in body
    assert resource_governor.never_triggers_cloud is True
    assert len(body.keys()) == 19

    # Host Admin PUT validates and updates policy
    bad_put = await client.put(
        "/api/v1/system/resources",
        headers=host_admin_headers,
        json={"resource_mode": "auto", "game_process_list": [r"C:\bad\path.exe"]},
    )
    assert bad_put.status_code == 422

    ok_put = await client.put(
        "/api/v1/system/resources",
        headers=host_admin_headers,
        json={
            "resource_mode": "low_impact",
            "low_impact_strategy": "cpu_eco",
            "game_process_list": ["EldenRing.exe"],
            "cooldown_seconds": 60,
        },
    )
    assert ok_put.status_code == 200
    assert ok_put.json()["effective_mode"] == "low_impact"
    assert ok_put.json()["low_impact_active"] is True
    assert ok_put.json()["deferred_background_work"] is True

    # Reset back to normal
    reset_put = await client.put(
        "/api/v1/system/resources",
        headers=host_admin_headers,
        json={"resource_mode": "normal"},
    )
    assert reset_put.status_code == 200
    assert reset_put.json()["low_impact_active"] is False

    # During shutdown, GET remains exempt in NON_DB_GET_PATHS while PUT fails closed with 503
    monkeypatch.setattr(runtime_lifecycle, "_is_shutting_down", True)
    try:
        during_get = await client.get("/api/v1/system/resources", headers=host_admin_headers)
        assert during_get.status_code == 200
        during_put = await client.put(
            "/api/v1/system/resources",
            headers=host_admin_headers,
            json={"resource_mode": "normal"},
        )
        assert during_put.status_code == 503
    finally:
        monkeypatch.setattr(runtime_lifecycle, "_is_shutting_down", False)
