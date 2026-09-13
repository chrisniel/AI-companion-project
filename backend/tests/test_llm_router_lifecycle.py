"""Tests for LLM router lifecycle, 9-state machine, scoped PID termination, and path security."""

import inspect
import pytest
from app.services.llm.llama_cpp import LlamaCppProvider
from app.services.llm.runtime_state import LLMRuntimeState


def test_runtime_state_enum_coverage():
    """Verify all 9 runtime states from LLAMA_CPP_RUNTIME_ARCHITECTURE.md §4 exist."""
    expected_states = {
        "SERVER_STOPPED",
        "SERVER_STARTING",
        "MODEL_UNLOADED",
        "MODEL_LOADING",
        "MODEL_READY",
        "MODEL_SLEEPING",
        "MODEL_UNLOADING",
        "MODEL_ERROR",
        "SERVER_ERROR",
    }
    actual_states = {s.value for s in LLMRuntimeState}
    assert expected_states == actual_states


def test_taskkill_blind_im_absent_from_codebase():
    """Permanent Invariant 1: taskkill /IM llama-server.exe must NOT exist in executable code."""
    source = inspect.getsource(LlamaCppProvider)
    # Check that any execution of taskkill /IM is absent
    executable_lines = [line.strip() for line in source.splitlines() if not line.strip().startswith("#")]
    for line in executable_lines:
        assert '["taskkill", "/IM"' not in line
        assert "taskkill /IM" not in line


@pytest.mark.anyio
async def test_path_traversal_model_rejected():
    """Verify load_model rejects path traversal attempts."""
    provider = LlamaCppProvider()
    assert await provider.load_model("../../etc/passwd") is False
    assert provider._last_error == "MODEL_PATH_TRAVERSAL"

    assert await provider.load_model("..\\windows\\system32\\calc.exe") is False
    assert provider._last_error == "MODEL_PATH_TRAVERSAL"

    assert await provider.load_model("/etc/shadow") is False
    assert provider._last_error == "MODEL_PATH_TRAVERSAL"

    assert await provider.load_model("../outside.gguf") is False
    assert provider._last_error == "MODEL_PATH_TRAVERSAL"


@pytest.mark.anyio
async def test_model_busy_rejects_unload():
    """Verify unload_model rejects while generation is active."""
    provider = LlamaCppProvider()
    provider._generation_active = True
    result = await provider.unload_model()
    assert result is False
    assert "MODEL_BUSY" in str(provider._last_error)
    provider._generation_active = False


@pytest.mark.anyio
async def test_external_router_not_killed_on_unload():
    """Verify external server is not terminated if managed_by_core=False."""
    provider = LlamaCppProvider()
    provider._managed_by_core = False
    provider._server_is_active = True
    provider._server_process = None

    # Unload should attempt router API unload or clean exit without killing foreign processes
    res = await provider.unload_model()
    assert res is True
    assert provider._server_process is None
