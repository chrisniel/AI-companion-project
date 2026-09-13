"""
Regression tests for single-router ownership, process liveness guard,
failed startup cleanup, port conflict prevention, and polling verification.
(Phase 0 — Reproduce & Instrument)
"""

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
import pytest

from app.services.llm.llama_cpp import LlamaCppProvider
from app.services.llm.runtime_state import LLMRuntimeState


@pytest.fixture
def llama_provider():
    provider = LlamaCppProvider()
    yield provider


@pytest.mark.asyncio
async def test_router_singleton_spawn_guard(llama_provider):
    """
    If a router process is already alive (poll() is None),
    load_model() MUST NOT spawn a second process.
    """
    mock_existing_proc = MagicMock()
    mock_existing_proc.poll.return_value = None  # Process is alive
    mock_existing_proc.pid = 9999

    llama_provider._server_process = mock_existing_proc
    llama_provider._server_pid = 9999
    llama_provider._server_is_active = True
    llama_provider._managed_by_core = True

    with patch("subprocess.Popen") as mock_popen, \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock) as mock_router_load:
        mock_router_load.return_value = True

        result = await llama_provider.load_model("qwen3-vl-4b-instruct")

        assert result is True
        mock_popen.assert_not_called()
        assert llama_provider._server_pid == 9999


@pytest.mark.asyncio
async def test_failed_startup_terminates_child_process(llama_provider):
    """
    If FastAPI Core spawns a child router process but the health check times out or fails,
    Core MUST cleanly kill the child process so no orphaned process is left holding port 8085.
    """
    mock_child_proc = MagicMock()
    mock_child_proc.poll.return_value = None  # Still alive during startup
    mock_child_proc.pid = 12345

    with patch("subprocess.Popen", return_value=mock_child_proc), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock) as mock_check, \
         patch.object(llama_provider, "_check_port_listening", return_value=False), \
         patch("asyncio.sleep", new_callable=AsyncMock):
        # Health check never succeeds
        mock_check.return_value = False

        result = await llama_provider.load_model("qwen3-vl-4b-instruct")

        assert result is False
        # Child process must have been terminated / killed
        assert mock_child_proc.kill.called or mock_child_proc.terminate.called
        # Internal process state must be reset to None
        assert llama_provider._server_process is None
        assert llama_provider._server_pid is None


@pytest.mark.asyncio
async def test_port_conflict_refuses_spawn(llama_provider):
    """
    If port 8085 is already listening and unresponsive to llama-server /health (alien process),
    FastAPI Core MUST refuse to spawn and set a descriptive PORT_CONFLICT error.
    """
    with patch.object(llama_provider, "_check_port_listening", return_value=True), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock) as mock_check, \
         patch("subprocess.Popen") as mock_popen:
        mock_check.return_value = False  # Alien process on 8085

        result = await llama_provider.load_model("qwen3-vl-4b-instruct")

        assert result is False
        mock_popen.assert_not_called()
        assert "PORT_CONFLICT" in (llama_provider._last_error or "")


@pytest.mark.asyncio
async def test_router_load_polling_timeout_returns_false(llama_provider):
    """
    If _router_load_model() polls /models and timeout expires without status.value == 'loaded',
    it MUST return False (never True).
    """
    mock_client = AsyncMock()
    mock_post_resp = MagicMock()
    mock_post_resp.status_code = 200
    mock_client.post.return_value = mock_post_resp

    mock_get_resp = MagicMock()
    mock_get_resp.status_code = 200
    # Model remains 'unloaded'
    mock_get_resp.json.return_value = {
        "data": [{"id": "qwen3-vl-4b-instruct", "status": {"value": "unloaded"}}]
    }
    mock_client.get.return_value = mock_get_resp

    with patch("httpx.AsyncClient") as mock_http_cls, \
         patch("asyncio.sleep", new_callable=AsyncMock):
        mock_http_cls.return_value.__aenter__.return_value = mock_client

        # Force shorter poll count for testing
        result = await llama_provider._router_load_model("qwen3-vl-4b-instruct")

        assert result is False, "Load timeout must return False, not True"


@pytest.mark.asyncio
async def test_router_unload_polling_timeout_returns_false(llama_provider):
    """
    If _router_unload_model() polls /models and timeout expires without status.value == 'unloaded',
    it MUST return False (never True).
    """
    mock_client = AsyncMock()
    mock_post_resp = MagicMock()
    mock_post_resp.status_code = 200
    mock_client.post.return_value = mock_post_resp

    mock_get_resp = MagicMock()
    mock_get_resp.status_code = 200
    # Model remains 'loaded'
    mock_get_resp.json.return_value = {
        "data": [{"id": "qwen3-vl-4b-instruct", "status": {"value": "loaded"}}]
    }
    mock_client.get.return_value = mock_get_resp

    with patch("httpx.AsyncClient") as mock_http_cls, \
         patch("asyncio.sleep", new_callable=AsyncMock):
        mock_http_cls.return_value.__aenter__.return_value = mock_client

        result = await llama_provider._router_unload_model("qwen3-vl-4b-instruct")

        assert result is False, "Unload timeout must return False, not True"


@pytest.mark.asyncio
async def test_router_launch_args_contain_ctx_size_and_profile_params(llama_provider):
    """
    Router launch args MUST contain --ctx-size, --n-gpu-layers, and --threads
    derived strictly from the active profile.
    """
    llama_provider._active_profile = "eco"
    mock_proc = MagicMock()
    mock_proc.poll.return_value = None
    mock_proc.pid = 4321

    with patch.object(llama_provider, "_check_port_listening", return_value=False), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock, return_value=True), \
         patch("subprocess.Popen", return_value=mock_proc) as mock_popen:
        
        result = await llama_provider.load_model("qwen3-vl-2b-instruct")
        assert result is True
        assert mock_popen.called
        args = mock_popen.call_args[0][0]
        
        # Verify --ctx-size 2048 for eco
        assert "--ctx-size" in args, "Launch args must contain --ctx-size"
        ctx_idx = args.index("--ctx-size")
        assert args[ctx_idx + 1] == "2048", "Eco profile must pass ctx-size 2048"

        # Verify --n-gpu-layers 0 for eco
        assert "--n-gpu-layers" in args
        ngl_idx = args.index("--n-gpu-layers")
        assert args[ngl_idx + 1] == "0", "Eco profile must pass 0 GPU layers"

        # Verify --threads 4 for eco
        assert "--threads" in args
        t_idx = args.index("--threads")
        assert args[t_idx + 1] == "4", "Eco profile must pass 4 threads"


@pytest.mark.asyncio
async def test_set_profile_terminates_core_managed_router_for_respawn(llama_provider):
    """
    Evidence-gated profile switching:
    Because b10936 binds launch args at router startup, changing the profile
    while a Core-managed router is running must cleanly terminate the running
    router so it will respawn with the new profile flags on next use.
    """
    mock_proc = MagicMock()
    mock_proc.poll.return_value = None
    mock_proc.pid = 5555

    llama_provider._server_process = mock_proc
    llama_provider._server_pid = 5555
    llama_provider._managed_by_core = True
    llama_provider._server_is_active = True
    llama_provider._active_profile = "balanced"
    llama_provider._active_model_name = "qwen3-vl-2b-instruct"

    with patch.object(llama_provider, "_router_unload_model", new_callable=AsyncMock, return_value=True) as mock_unload:
        success = await llama_provider.set_profile("eco")
        assert success is True
        assert llama_provider._active_profile == "eco"
        # Old router process must have been terminated
        assert mock_proc.terminate.called or mock_proc.kill.called
        assert llama_provider._server_process is None
        assert llama_provider._server_pid is None


@pytest.mark.asyncio
async def test_set_profile_rejected_during_active_generation(llama_provider):
    """
    Profile changes MUST be rejected if generation is active.
    """
    llama_provider._active_profile = "balanced"
    llama_provider._generation_active = True

    success = await llama_provider.set_profile("eco")
    assert success is False, "Profile change must be rejected when generation is active"
    assert llama_provider._active_profile == "balanced"


@pytest.mark.asyncio
async def test_idle_monitor_neutralized_when_native_sleep_active(llama_provider):
    """
    When router is active with native --sleep-idle-seconds > 0,
    the Python idle monitor must NOT issue an explicit unload_model() call,
    preventing conflict with llama-server native sleep.
    """
    llama_provider._server_is_active = True
    llama_provider._active_model_name = "qwen3-vl-2b-instruct"
    llama_provider._runtime_state = LLMRuntimeState.MODEL_READY

    with patch.object(llama_provider, "unload_model", new_callable=AsyncMock) as mock_unload:
        # Run idle monitor loop iteration
        await llama_provider._idle_monitor_loop()
        # unload_model must NOT have been called
        mock_unload.assert_not_called()


# ==============================================================================
# Phase 3: Backend Runtime Truth & Telemetry Contract Tests
# ==============================================================================

@pytest.mark.asyncio
async def test_status_contract_stopped_router(llama_provider):
    """
    SERVER_STOPPED Semantics:
    - router_running = False
    - model_resident = False
    - model_loaded = False
    - model_awake = False
    - active_model = None
    - applied_profile = None
    - applied_context_size = None
    - applied_gpu_layers = None
    - applied_mmproj_offload = None
    - requested_mmproj_offload = True (for balanced default)
    - seconds_until_idle = None
    - seconds_until_unload = None
    - is_loaded = False
    """
    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=False):
        status = await llama_provider.get_status()
        assert status.router_running is False
        assert status.managed_by_core is False
        assert status.runtime_state == LLMRuntimeState.SERVER_STOPPED
        assert status.active_model is None
        assert status.model_resident is False
        assert status.model_loaded is False
        assert status.model_awake is False
        assert status.applied_profile is None
        assert status.applied_context_size is None
        assert status.applied_gpu_layers is None
        assert status.applied_mmproj_offload is None
        assert status.requested_mmproj_offload is True
        assert status.seconds_until_idle is None
        assert status.seconds_until_unload is None
        assert status.is_loaded is False


@pytest.mark.asyncio
async def test_status_contract_running_router_no_model(llama_provider):
    """
    MODEL_UNLOADED Semantics:
    - router_running = True
    - model_resident = False
    - model_loaded = False
    - model_awake = False
    - active_model = None
    - applied_profile matches verified router launch args
    - applied_mmproj_offload = True
    - seconds_until_idle = None
    - seconds_until_unload = None
    """
    llama_provider._managed_by_core = True
    llama_provider._applied_profile = "balanced"
    llama_provider._applied_context_size = 4096
    llama_provider._applied_gpu_layers = 28
    llama_provider._applied_mmproj_offload = True

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"data": []}

    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):
        status = await llama_provider.get_status()
        assert status.router_running is True
        assert status.runtime_state == LLMRuntimeState.MODEL_UNLOADED
        assert status.active_model is None
        assert status.model_resident is False
        assert status.model_loaded is False
        assert status.model_awake is False
        assert status.applied_profile == "balanced"
        assert status.applied_context_size == 4096
        assert status.applied_gpu_layers == 28
        assert status.requested_mmproj_offload is True
        assert status.applied_mmproj_offload is True
        assert status.mmproj_offload is True
        assert status.seconds_until_idle is None
        assert status.seconds_until_unload is None
        assert status.is_loaded is False


@pytest.mark.asyncio
async def test_status_contract_model_ready(llama_provider):
    """
    MODEL_READY Semantics:
    - router_running = True
    - model_resident = True (GPU memory active)
    - model_loaded = True
    - model_awake = True
    - active_model is populated
    - applied_profile reflects active router flags
    - applied_mmproj_offload = True
    - seconds_until_idle is a positive sleep countdown
    - seconds_until_unload is strictly None
    """
    llama_provider._managed_by_core = True
    llama_provider._applied_profile = "balanced"
    llama_provider._applied_context_size = 4096
    llama_provider._applied_gpu_layers = 28
    llama_provider._applied_mmproj_offload = True

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "data": [{"id": "qwen3-vl-2b-instruct", "status": {"value": "loaded"}}]
    }

    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):
        status = await llama_provider.get_status()
        assert status.router_running is True
        assert status.runtime_state == LLMRuntimeState.MODEL_READY
        assert status.active_model == "qwen3-vl-2b-instruct"
        assert status.model_resident is True
        assert status.model_loaded is True
        assert status.model_awake is True
        assert status.applied_profile == "balanced"
        assert status.applied_context_size == 4096
        assert status.applied_gpu_layers == 28
        assert status.requested_mmproj_offload is True
        assert status.applied_mmproj_offload is True
        assert status.mmproj_offload is True
        assert status.seconds_until_idle is not None
        assert status.seconds_until_idle > 0
        assert status.seconds_until_unload is None
        assert status.is_loaded is True


@pytest.mark.asyncio
async def test_status_contract_model_sleeping(llama_provider):
    """
    MODEL_SLEEPING Expressive Semantics:
    - router_running = True
    - active_model is populated
    - model_loaded = True (Worker alive, model logically selected)
    - model_awake = False (Sleeping, GPU allocations unmapped)
    - model_resident = False (VRAM released)
    - applied_mmproj_offload = True
    - seconds_until_idle = 0 (already in sleep)
    - seconds_until_unload = None (never falsely reports unload)
    - Distinct from MODEL_UNLOADED (active_model != None, model_loaded == True)
    """
    llama_provider._managed_by_core = True
    llama_provider._applied_profile = "balanced"
    llama_provider._applied_context_size = 4096
    llama_provider._applied_gpu_layers = 28
    llama_provider._applied_mmproj_offload = True

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "data": [{"id": "qwen3-vl-2b-instruct", "status": {"value": "sleeping"}}]
    }

    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):
        status = await llama_provider.get_status()
        assert status.router_running is True
        assert status.runtime_state == LLMRuntimeState.MODEL_SLEEPING
        assert status.active_model == "qwen3-vl-2b-instruct"
        assert status.model_resident is False
        assert status.model_loaded is True
        assert status.model_awake is False
        assert status.applied_profile == "balanced"
        assert status.applied_context_size == 4096
        assert status.applied_gpu_layers == 28
        assert status.requested_mmproj_offload is True
        assert status.applied_mmproj_offload is True
        assert status.mmproj_offload is True
        assert status.seconds_until_idle == 0
        assert status.seconds_until_unload is None
        assert status.is_loaded is True


@pytest.mark.asyncio
async def test_status_contract_explicit_unload(llama_provider):
    """
    Explicit Unload Semantics:
    Router remains running; model is evicted from memory.
    - router_running = True
    - runtime_state = MODEL_UNLOADED
    - active_model = None
    - model_resident = False
    - model_loaded = False
    - model_awake = False
    - applied_profile remains intact on running router
    - seconds_until_idle = None
    - seconds_until_unload = None
    """
    llama_provider._server_is_active = True
    llama_provider._active_model_name = "qwen3-vl-2b-instruct"
    llama_provider._applied_profile = "balanced"
    llama_provider._applied_context_size = 4096
    llama_provider._applied_gpu_layers = 28
    llama_provider._applied_mmproj_offload = True

    with patch.object(llama_provider, "_router_unload_model", new_callable=AsyncMock, return_value=True):
        unload_res = await llama_provider.unload_model()
        assert unload_res is True
        assert llama_provider._runtime_state == LLMRuntimeState.MODEL_UNLOADED
        assert llama_provider._active_model_name is None

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"data": []}

    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):
        status = await llama_provider.get_status()
        assert status.router_running is True
        assert status.runtime_state == LLMRuntimeState.MODEL_UNLOADED
        assert status.active_model is None
        assert status.model_resident is False
        assert status.model_loaded is False
        assert status.model_awake is False
        assert status.applied_profile == "balanced"
        assert status.applied_context_size == 4096
        assert status.applied_gpu_layers == 28
        assert status.requested_mmproj_offload is True
        assert status.applied_mmproj_offload is True
        assert status.seconds_until_idle is None
        assert status.seconds_until_unload is None
        assert status.is_loaded is False


@pytest.mark.asyncio
async def test_status_contract_profile_changed_before_activation(llama_provider):
    """
    Profile Transition Invariant:
    When profile switches while router is running, the old router is terminated.
    The backend MUST NOT report the new profile as applied until the new router is launched.
    - requested_profile = "eco"
    - requested_mmproj_offload = False
    - applied_profile = None (NOT eco!)
    - applied_context_size = None
    - applied_gpu_layers = None
    - applied_mmproj_offload = None (stopped/pending router)
    - seconds_until_idle = None
    - seconds_until_unload = None
    - router_running = False
    - runtime_state = SERVER_STOPPED
    """
    mock_proc = MagicMock()
    mock_proc.poll.return_value = None
    mock_proc.pid = 9999

    llama_provider._server_process = mock_proc
    llama_provider._server_pid = 9999
    llama_provider._managed_by_core = True
    llama_provider._server_is_active = True
    llama_provider._active_profile = "balanced"
    llama_provider._applied_profile = "balanced"
    llama_provider._applied_context_size = 4096
    llama_provider._applied_gpu_layers = 28
    llama_provider._applied_mmproj_offload = True
    llama_provider._active_model_name = "qwen3-vl-2b-instruct"

    with patch.object(llama_provider, "_router_unload_model", new_callable=AsyncMock, return_value=True):
        switch_success = await llama_provider.set_profile("eco")
        assert switch_success is True

    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=False):
        status = await llama_provider.get_status()
        assert status.requested_profile == "eco"
        assert status.requested_mmproj_offload is False
        assert status.applied_profile is None, "New profile must NOT be reported as applied before router launch"
        assert status.applied_context_size is None
        assert status.applied_gpu_layers is None
        assert status.applied_mmproj_offload is None, "Stopped/pending router must have applied_mmproj_offload = null"
        assert status.seconds_until_idle is None
        assert status.seconds_until_unload is None
        assert status.router_running is False
        assert status.runtime_state == LLMRuntimeState.SERVER_STOPPED
        assert status.active_model is None
        assert status.is_loaded is False


@pytest.mark.asyncio
async def test_status_contract_applied_eco_launch_args_and_mmproj_policy(llama_provider):
    """
    Eco Profile Policy:
    When loaded under Eco, launch args MUST contain:
    - --ctx-size 2048
    - --n-gpu-layers 0
    - --threads 4
    - --no-mmproj-offload
    And status MUST reflect:
    - requested_mmproj_offload = False
    - applied_mmproj_offload = False
    - mmproj_offload = False
    - seconds_until_unload = None
    """
    llama_provider._active_profile = "eco"
    mock_proc = MagicMock()
    mock_proc.poll.return_value = None
    mock_proc.pid = 7777

    with patch.object(llama_provider, "_check_port_listening", return_value=False), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock, return_value=True), \
         patch("subprocess.Popen", return_value=mock_proc) as mock_popen:
        
        result = await llama_provider.load_model("qwen3-vl-2b-instruct")
        assert result is True
        args = mock_popen.call_args[0][0]

        # Verify exact Eco launch args
        assert "--ctx-size" in args and args[args.index("--ctx-size") + 1] == "2048"
        assert "--n-gpu-layers" in args and args[args.index("--n-gpu-layers") + 1] == "0"
        assert "--threads" in args and args[args.index("--threads") + 1] == "4"
        assert "--no-mmproj-offload" in args, "Eco profile must explicitly pass --no-mmproj-offload"

        # Verify applied settings in provider
        assert llama_provider._applied_profile == "eco"
        assert llama_provider._applied_context_size == 2048
        assert llama_provider._applied_gpu_layers == 0
        assert llama_provider._applied_mmproj_offload is False

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "data": [{"id": "qwen3-vl-2b-instruct", "status": {"value": "loaded"}}]
    }

    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):
        status = await llama_provider.get_status()
        assert status.requested_profile == "eco"
        assert status.applied_profile == "eco"
        assert status.applied_context_size == 2048
        assert status.applied_gpu_layers == 0
        assert status.requested_mmproj_offload is False
        assert status.applied_mmproj_offload is False
        assert status.mmproj_offload is False
        assert status.seconds_until_unload is None


@pytest.mark.asyncio
async def test_status_contract_applied_balanced_launch_args_and_mmproj_policy(llama_provider):
    """
    Balanced Profile Policy:
    When loaded under Balanced, launch args MUST contain:
    - --ctx-size 4096
    - --n-gpu-layers 28
    - --threads 6
    - NO --no-mmproj-offload
    And status MUST reflect:
    - requested_mmproj_offload = True
    - applied_mmproj_offload = True
    - mmproj_offload = True
    - seconds_until_unload = None
    """
    llama_provider._active_profile = "balanced"
    mock_proc = MagicMock()
    mock_proc.poll.return_value = None
    mock_proc.pid = 8888

    with patch.object(llama_provider, "_check_port_listening", return_value=False), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock, return_value=True), \
         patch("subprocess.Popen", return_value=mock_proc) as mock_popen:
        
        result = await llama_provider.load_model("qwen3-vl-2b-instruct")
        assert result is True
        args = mock_popen.call_args[0][0]

        # Verify exact Balanced launch args
        assert "--ctx-size" in args and args[args.index("--ctx-size") + 1] == "4096"
        assert "--n-gpu-layers" in args and args[args.index("--n-gpu-layers") + 1] == "28"
        assert "--threads" in args and args[args.index("--threads") + 1] == "6"
        assert "--no-mmproj-offload" not in args, "Balanced profile must NOT pass --no-mmproj-offload"

        # Verify applied settings in provider
        assert llama_provider._applied_profile == "balanced"
        assert llama_provider._applied_context_size == 4096
        assert llama_provider._applied_gpu_layers == 28
        assert llama_provider._applied_mmproj_offload is True

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "data": [{"id": "qwen3-vl-2b-instruct", "status": {"value": "loaded"}}]
    }

    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):
        status = await llama_provider.get_status()
        assert status.requested_profile == "balanced"
        assert status.applied_profile == "balanced"
        assert status.applied_context_size == 4096
        assert status.applied_gpu_layers == 28
        assert status.requested_mmproj_offload is True
        assert status.applied_mmproj_offload is True
        assert status.mmproj_offload is True
        assert status.seconds_until_unload is None


@pytest.mark.asyncio
async def test_status_contract_runtime_error_state(llama_provider):
    """
    Error Telemetry Semantics:
    When engine launch fails, runtime_state reflects error and last_runtime_error
    contains the failure diagnostic.
    """
    with patch.object(llama_provider, "_check_port_listening", return_value=False), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=False), \
         patch("subprocess.Popen", side_effect=OSError("Exec format error")):
        
        result = await llama_provider.load_model("qwen3-vl-2b-instruct")
        assert result is False
        assert llama_provider._runtime_state == LLMRuntimeState.SERVER_ERROR
        assert "LAUNCH_FAILED" in llama_provider._last_error

        status = await llama_provider.get_status()
        assert status.runtime_state == LLMRuntimeState.SERVER_ERROR
        assert status.last_runtime_error is not None
        assert "LAUNCH_FAILED" in status.last_runtime_error
        assert status.router_running is False
        assert status.applied_profile is None
        assert status.applied_mmproj_offload is None
        assert status.seconds_until_idle is None
        assert status.seconds_until_unload is None


@pytest.mark.asyncio
async def test_status_contract_backwards_compatible_fields(llama_provider):
    """
    Backward Compatibility Semantics:
    - is_loaded equals model_loaded
    - active_profile equals requested_profile
    - context_size and gpu_layers match applied when running, requested default otherwise
    - mmproj_offload equals applied_mmproj_offload when running, requested otherwise
    - seconds_until_unload is strictly None (neutralized auto-unload)
    """
    llama_provider._active_profile = "balanced"
    llama_provider._applied_profile = "balanced"
    llama_provider._applied_context_size = 4096
    llama_provider._applied_gpu_layers = 28
    llama_provider._applied_mmproj_offload = True

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "data": [{"id": "qwen3-vl-2b-instruct", "status": {"value": "loaded"}}]
    }

    with patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):
        status = await llama_provider.get_status()
        assert status.is_loaded == status.model_loaded == True
        assert status.active_profile == status.requested_profile == "balanced"
        assert status.context_size == 4096
        assert status.gpu_layers == 28
        assert status.mmproj_offload == status.applied_mmproj_offload == True
        assert status.idle_timeout_seconds > 0
        assert status.seconds_until_unload is None
        assert isinstance(status.available_models, list)


