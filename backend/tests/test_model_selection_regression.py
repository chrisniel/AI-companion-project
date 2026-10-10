"""
Regression tests for model selection, verified registry matching,
obsolete default handling, router mismatch, and active model reuse.
"""

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch
import pytest

from app.core.config import settings
from app.schemas.model_registry import (
    ModelAssetType,
    ModelDiscoveryState,
    ModelLibraryState,
    ModelManifest,
    ModelRegistryEntry,
    ModelRuntimeHints,
    ModelVariant,
    ReasoningMode,
    ValidationStatus,
)
from app.services.llm.llama_cpp import LlamaCppProvider
from app.services.llm.runtime_state import LLMRuntimeState


def _make_entry(entry_id: str, runtime_id: str, file_exists: bool = True) -> ModelRegistryEntry:
    manifest = ModelManifest(
        id=entry_id,
        display_name=entry_id,
        asset_type=ModelAssetType.gguf,
        family="qwen",
        architecture="qwen2",
        variant=ModelVariant.instruct,
        parameters="2B",
        quantization="Q4_K_M",
        reasoning_mode=ReasoningMode.unsupported,
        capabilities=[],
        input_modalities=[],
        model_max_context=4096,
        runtime_compatibility=[],
        primary_file=f"vision/{runtime_id}/{runtime_id}.gguf",
        companion_files=[],
    )
    library_state = ModelLibraryState(
        discovery_state=ModelDiscoveryState.discovered,
        validation_status=ValidationStatus.verified if file_exists else ValidationStatus.missing_primary,
        primary_file_exists=file_exists,
        size_gb=1.5,
        companion_artifact_statuses=[],
        available_capabilities=[],
        capability_provenance=[],
    )
    hints = ModelRuntimeHints(
        recommended_profiles=["balanced"],
        estimated_vram_gb=2.0,
        estimated_ram_gb=4.0,
    )
    return ModelRegistryEntry(
        manifest=manifest,
        library_state=library_state,
        hints=hints,
        runtime_model_id=runtime_id,
        registry_source="factory",
    )


@pytest.fixture
def llama_provider(tmp_path, monkeypatch):
    runtime_dir = tmp_path / "runtime" / "llama.cpp"
    runtime_dir.mkdir(parents=True)

    fake_server = runtime_dir / "llama-server.exe"
    fake_server.write_bytes(b"")

    models_dir = tmp_path / "models"
    models_dir.mkdir(parents=True)

    data_dir = tmp_path / "data"
    data_dir.mkdir(parents=True)

    monkeypatch.setattr(settings, "LLAMA_CPP_BIN_DIR", runtime_dir)
    monkeypatch.setattr(settings, "LLAMA_MODELS_DIR", models_dir)
    monkeypatch.setattr(settings, "MODELS_DIR", models_dir)
    monkeypatch.setattr(type(settings), "DATA_DIR", property(lambda self: data_dir))

    provider = LlamaCppProvider()
    yield provider


@pytest.mark.asyncio
async def test_obsolete_default_with_other_valid_entries_fails_closed(llama_provider, monkeypatch):
    """
    When settings.DEFAULT_MODEL_NAME is obsolete and not present in registry/disk,
    load_model() with no argument MUST NOT guess or pick another model.
    It must fail closed with CONFIGURED_MODEL_NOT_FOUND.
    """
    monkeypatch.setattr(settings, "DEFAULT_MODEL_NAME", "Qwen2.5-7B-Instruct-Q4_K_M.gguf")

    valid_entry = _make_entry("qwen3-vl-2b-instruct", "qwen3-vl-2b-instruct", file_exists=True)

    def mock_find(identifier, entries=None):
        if identifier in ("qwen3-vl-2b-instruct", valid_entry.manifest.primary_file):
            return valid_entry
        return None

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", side_effect=mock_find):
        result = await llama_provider.load_model()

        assert result is False
        assert llama_provider._runtime_state == LLMRuntimeState.MODEL_ERROR
        assert "CONFIGURED_MODEL_NOT_FOUND" in (llama_provider._last_error or "")
        assert "Qwen2.5-7B-Instruct-Q4_K_M.gguf" in (llama_provider._last_error or "")


@pytest.mark.asyncio
async def test_valid_explicitly_selected_model_succeeds(llama_provider):
    """
    When an explicitly specified model is verified in the registry with primary_file_exists=True,
    load_model() loads it via the router.
    """
    valid_entry = _make_entry("qwen3-vl-2b-instruct", "qwen3-vl-2b-instruct", file_exists=True)

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", return_value=valid_entry), \
         patch.object(llama_provider, "_check_port_listening", return_value=True), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock, return_value=True) as mock_router_load:

        result = await llama_provider.load_model("qwen3-vl-2b-instruct")

        assert result is True
        assert llama_provider._runtime_state == LLMRuntimeState.MODEL_READY
        assert llama_provider._active_model_name == "qwen3-vl-2b-instruct"
        mock_router_load.assert_called_once_with("qwen3-vl-2b-instruct")


@pytest.mark.asyncio
async def test_no_verified_model_available_fails(llama_provider):
    """
    When the requested model does not exist or has primary_file_exists=False,
    load_model() fails closed with CONFIGURED_MODEL_NOT_FOUND.
    """
    missing_entry = _make_entry("non-existent-model", "non-existent-model", file_exists=False)

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", return_value=missing_entry):
        result = await llama_provider.load_model("non-existent-model")

        assert result is False
        assert llama_provider._runtime_state == LLMRuntimeState.MODEL_ERROR
        assert "CONFIGURED_MODEL_NOT_FOUND: non-existent-model" in (llama_provider._last_error or "")


@pytest.mark.asyncio
async def test_router_model_identifier_mismatch_fails(llama_provider):
    """
    When the router returns false or times out because the identifier doesn't match or load fails,
    load_model() reports MODEL_LOAD_FAILED.
    """
    valid_entry = _make_entry("qwen3-vl-2b-instruct", "qwen3-vl-2b-instruct", file_exists=True)

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", return_value=valid_entry), \
         patch.object(llama_provider, "_check_port_listening", return_value=True), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock, return_value=False):

        result = await llama_provider.load_model("qwen3-vl-2b-instruct")

        assert result is False
        assert llama_provider._runtime_state == LLMRuntimeState.MODEL_ERROR
        assert "MODEL_LOAD_FAILED: qwen3-vl-2b-instruct" in (llama_provider._last_error or "")


@pytest.mark.asyncio
async def test_existing_ready_model_reuse_without_reload(llama_provider):
    """
    When a model is already loaded and ready (or sleeping), calling load_model()
    with None or the same model reuses the active model without invoking the router.
    """
    llama_provider._server_is_active = True
    llama_provider._runtime_state = LLMRuntimeState.MODEL_READY
    llama_provider._active_model_name = "qwen3-vl-2b-instruct"

    valid_entry = _make_entry("qwen3-vl-2b-instruct", "qwen3-vl-2b-instruct", file_exists=True)

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", return_value=valid_entry), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock) as mock_router_load, \
         patch.object(llama_provider, "_router_unload_model", new_callable=AsyncMock) as mock_router_unload:

        # 1. Calling with None reuses active model
        result_none = await llama_provider.load_model(None)
        assert result_none is True
        mock_router_load.assert_not_called()
        mock_router_unload.assert_not_called()

        # 2. Calling with matching model reuses active model
        result_same = await llama_provider.load_model("qwen3-vl-2b-instruct")
        assert result_same is True
        mock_router_load.assert_not_called()
        mock_router_unload.assert_not_called()
