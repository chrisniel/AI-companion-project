"""Tests for LlamaCppProvider strict lock ownership, cancellation-aware lifecycle, and shutdown."""

import asyncio
from dataclasses import is_dataclass
from unittest.mock import AsyncMock, MagicMock, patch
import pytest

from app.schemas.llm import ChatMessage, ModelStatusResponse
from app.services.llm.base import BaseLLMProvider, ProviderShutdownResult
from app.services.llm.llama_cpp import LlamaCppProvider, ProviderGenerationError
from app.services.llm.runtime_state import LLMRuntimeState


def test_provider_shutdown_result_contract():
    """Verify ProviderShutdownResult dataclass exists and has required fields."""
    res = ProviderShutdownResult(
        completed_cleanly=True,
        lock_acquired=True,
        reason=None,
        managed_llm_pid=1234,
        managed_by_core=True,
    )
    assert is_dataclass(res)
    assert res.completed_cleanly is True
    assert res.lock_acquired is True
    assert res.reason is None
    assert res.managed_llm_pid == 1234
    assert res.managed_by_core is True


@pytest.mark.anyio
async def test_signal_shutdown_immediately_no_unlocked_mutation():
    """Verify signal_shutdown_immediately sets flags/events without mutating shared provider state."""
    provider = LlamaCppProvider()
    mock_proc = MagicMock()
    mock_client = AsyncMock()
    provider._server_process = mock_proc
    provider._server_pid = 9999
    provider._managed_by_core = True
    provider._server_client = mock_client
    provider._runtime_state = LLMRuntimeState.MODEL_READY

    provider.signal_shutdown_immediately()

    # Shared state must NOT be cleared or mutated by signal_shutdown_immediately
    assert provider._closing is True
    assert provider._shutdown_event.is_set() is True
    assert provider._server_process is mock_proc
    assert provider._server_pid == 9999
    assert provider._managed_by_core is True
    assert provider._server_client is mock_client
    assert provider._runtime_state == LLMRuntimeState.MODEL_READY
    # Neither process nor client should be closed/terminated without the lock
    mock_proc.terminate.assert_not_called()
    mock_proc.kill.assert_not_called()


@pytest.mark.anyio
async def test_s12_cooperative_abort_during_load_model():
    """S12: Calling signal_shutdown_immediately() while load_model is waiting aborts load under lock."""
    provider = LlamaCppProvider()

    # Simulate load_model in progress: sleeping in _sleep_or_abort
    async def run_load():
        # Will run load_model which should check shutdown_event or sleep_or_abort
        return await provider.load_model("test_model")

    # Mock engine binary exists and models dir exists, but sleep during readiness polling
    mock_registry_entry = MagicMock()
    mock_registry_entry.library_state.primary_file_exists = True
    mock_registry_entry.runtime_model_id = "test_model"
    mock_registry_entry.manifest.id = "test_model"

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", return_value=mock_registry_entry), \
         patch("app.services.llm.llama_cpp.settings") as mock_settings, \
         patch("app.services.llm.llama_cpp.subprocess.Popen") as mock_popen, \
         patch("app.services.llm.llama_cpp.resolve_effective_model", return_value=("test_model.gguf", "explicit")):
        mock_settings.LLAMA_CPP_BIN_DIR.resolve.return_value = "bin"
        mock_settings.LLAMA_MODELS_DIR.resolve.return_value = "models"
        mock_settings.MODELS_DIR.resolve.return_value = "models"
        mock_settings.DATA_DIR.mkdir.return_value = None
        mock_settings.DATA_DIR.__truediv__.return_value.resolve.return_value = "data/llama.log"
        mock_settings.LLAMA_ROUTER_HOST = "127.0.0.1"
        mock_settings.LLAMA_ROUTER_PORT = 8080
        mock_settings.LLAMA_ROUTER_IDLE_TIMEOUT = 0
        mock_settings.LLAMA_ROUTER_MODELS_MAX = 1
        mock_settings.PROFILE_BALANCED_CTX = 2048
        mock_settings.PROFILE_BALANCED_GPU_LAYERS = 20
        mock_settings.PROFILE_BALANCED_THREADS = 4
        mock_settings.PROFILE_BALANCED_MMPROJ_OFFLOAD = True
        mock_settings.LLM_PROFILE = "balanced"

        mock_server_exe = MagicMock()
        mock_server_exe.exists.return_value = True
        mock_settings.LLAMA_CPP_BIN_DIR.__truediv__.return_value = mock_server_exe
        mock_settings.LLAMA_MODELS_DIR.exists.return_value = True

        fake_proc = MagicMock()
        fake_proc.pid = 4321
        fake_proc.poll.return_value = None
        mock_popen.return_value = fake_proc

        load_task = asyncio.create_task(provider.load_model("test_model"))
        # Allow load_model to enter readiness loop
        await asyncio.sleep(0.05)
        assert provider._runtime_state == LLMRuntimeState.SERVER_STARTING

        # Now signal shutdown
        provider.signal_shutdown_immediately()

        result = await load_task
        assert result is False
        # Child process cleaned up under lock
        fake_proc.terminate.assert_called()
        assert provider._server_process is None
        assert provider._managed_by_core is False
        assert provider._runtime_state == LLMRuntimeState.SERVER_STOPPED


@pytest.mark.anyio
async def test_s13_provider_lock_acquisition_timeout_preserves_state():
    """S13: When self._lock cannot be acquired within lock_timeout, shutdown returns failure without unlocked cleanup."""
    provider = LlamaCppProvider()
    mock_proc = MagicMock()
    mock_proc.pid = 5555
    provider._server_process = mock_proc
    provider._server_pid = 5555
    provider._managed_by_core = True
    provider._runtime_state = LLMRuntimeState.MODEL_READY

    # Hold the lock externally to simulate a cancellation-resistant operation
    await provider._lock.acquire()
    try:
        res = await provider.shutdown(drain_timeout=0.1, lock_timeout=0.2)
        assert res.completed_cleanly is False
        assert res.lock_acquired is False
        assert res.reason == "PROVIDER_LOCK_TIMEOUT"
        assert res.managed_llm_pid == 5555
        assert res.managed_by_core is True

        # Invariant: NO unlocked cleanup must have been called!
        assert provider._server_process is mock_proc
        assert provider._server_pid == 5555
        assert provider._managed_by_core is True
        mock_proc.terminate.assert_not_called()
        mock_proc.kill.assert_not_called()
    finally:
        provider._lock.release()


@pytest.mark.anyio
async def test_s15_unload_model_vs_stop_managed_router_locked_vs_external():
    """S15: unload_model keeps router alive on router API success; shutdown stops Core router; external router preserved."""
    provider = LlamaCppProvider()
    mock_proc = MagicMock()
    mock_proc.pid = 6666
    mock_proc.poll.return_value = None
    provider._server_process = mock_proc
    provider._server_pid = 6666
    provider._managed_by_core = True
    provider._server_is_active = True
    provider._active_model_name = "test_model"
    provider._runtime_state = LLMRuntimeState.MODEL_READY

    # Case 1: unload_model() with successful router API unload keeps router alive
    with patch.object(provider, "_router_unload_model", AsyncMock(return_value=True)):
        unload_res = await provider.unload_model()
        assert unload_res is True
        # Router process should still be alive
        assert provider._server_process is mock_proc
        assert provider._server_pid == 6666
        assert provider._managed_by_core is True
        assert provider._runtime_state == LLMRuntimeState.MODEL_UNLOADED
        mock_proc.terminate.assert_not_called()

    # Case 2: shutdown() terminates Core-managed router under lock
    shutdown_res = await provider.shutdown(drain_timeout=0.1, lock_timeout=1.0)
    assert shutdown_res.completed_cleanly is True
    assert shutdown_res.lock_acquired is True
    assert provider._server_process is None
    assert provider._server_pid is None
    assert provider._managed_by_core is False
    assert provider._runtime_state == LLMRuntimeState.SERVER_STOPPED
    mock_proc.terminate.assert_called()

    # Case 3: External router (_managed_by_core == False) is NEVER terminated by shutdown()
    ext_provider = LlamaCppProvider()
    ext_provider._managed_by_core = False
    ext_provider._server_is_active = True
    ext_provider._active_model_name = "ext_model"
    ext_provider._server_process = None

    with patch.object(ext_provider, "_router_unload_model", AsyncMock(return_value=True)):
        ext_res = await ext_provider.shutdown(drain_timeout=0.1, lock_timeout=1.0)
        assert ext_res.completed_cleanly is True
        assert ext_res.managed_by_core is False
        assert ext_provider._server_process is None


@pytest.mark.anyio
async def test_s14_route_b_native_worker_active_guard():
    """S14: If native inference worker is still running past drain timeout, self._llm is NOT freed."""
    provider = LlamaCppProvider()
    fake_native_llm = MagicMock()
    provider._llm = fake_native_llm
    lease = await provider._acquire_generation()

    try:
        # Drain timeout expires while active generation is held
        res = await provider.shutdown(drain_timeout=0.1, lock_timeout=1.0)
        assert res.completed_cleanly is False
        assert res.reason == "DRAIN_TIMEOUT"
        # Crucial safeguard: fake_native_llm must NOT be deleted while worker holds generation lease
        assert provider._llm is fake_native_llm
    finally:
        provider._release_generation(lease)

    # After lease released, clean shutdown unloads model
    clean_res = await provider.shutdown(drain_timeout=0.1, lock_timeout=1.0)
    assert clean_res.completed_cleanly is True
    assert provider._llm is None


@pytest.mark.anyio
async def test_m5_lock_free_snapshot_get_status_during_transitional_state():
    """M5: get_status returns immediate snapshot without acquiring lock during SERVER_STARTING or MODEL_LOADING."""
    provider = LlamaCppProvider()
    provider._runtime_state = LLMRuntimeState.SERVER_STARTING
    provider._active_model_name = "loading_model"

    # Hold the lock to prove get_status does not block on it
    await provider._lock.acquire()
    try:
        status: ModelStatusResponse = await provider.get_status()
        assert status.runtime_state == LLMRuntimeState.SERVER_STARTING
    finally:
        provider._lock.release()


@pytest.mark.anyio
async def test_m6_model_id_normalization():
    """M6: get_status normalizes loaded_model_id via find_model_registry_entry."""
    provider = LlamaCppProvider()
    provider._server_is_active = True
    provider._llm = None

    with patch("app.services.llm.llama_cpp.httpx.AsyncClient") as mock_client_cls, \
         patch.object(provider, "_check_external_server", AsyncMock(return_value=True)), \
         patch("app.services.llm.llama_cpp.find_model_registry_entry") as mock_registry:

        # Mock router /models returning a raw filename
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "data": [{"id": "meta-llama-3-8b-instruct.Q4_K_M.gguf", "status": {"value": "loaded"}}]
        }
        mock_client = AsyncMock()
        mock_client.get.return_value = mock_resp
        mock_client_cls.return_value.__aenter__.return_value = mock_client

        # Mock registry mapping filename to canonical manifest id
        mock_entry = MagicMock()
        mock_entry.manifest.id = "llama-3-8b-instruct"
        mock_registry.return_value = mock_entry

        status = await provider.get_status()
        assert status.active_model == "llama-3-8b-instruct"
        assert provider._active_model_name == "llama-3-8b-instruct"
