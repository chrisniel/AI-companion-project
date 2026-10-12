"""
Regression tests for model selection, verified registry matching,
obsolete default handling, router mismatch, and active model reuse.
"""

from datetime import datetime, timezone
import json
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
from httpx import AsyncClient

from app.schemas.llm import ModelStatusResponse
from app.services.host_config import (
    clear_model_selection,
    get_saved_model_selection,
    resolve_effective_model,
    save_model_selection,
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
    monkeypatch.setattr(type(settings), "COMPANION_DATA_ROOT", property(lambda self: data_dir))
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


@pytest.mark.asyncio
async def test_selection_precedence_hierarchy(tmp_path, monkeypatch):
    """
    Selection precedence hierarchy:
    1. Explicitly requested model for the operation
    2. Saved host-level model selection (host_config.json)
    3. Development environment override (COMPANION_DEV_MODEL)
    4. Otherwise MODEL_SELECTION_REQUIRED (fail-closed)
    """
    data_dir = tmp_path / "data"
    data_dir.mkdir(parents=True)
    monkeypatch.setattr(type(settings), "COMPANION_DATA_ROOT", property(lambda self: data_dir))
    monkeypatch.delenv("COMPANION_DEV_MODEL", raising=False)
    monkeypatch.delenv("COMPANION_MODEL_OVERRIDE", raising=False)
    monkeypatch.setattr(settings, "DEV_MODEL_OVERRIDE", None)
    monkeypatch.setattr(settings, "DEFAULT_MODEL_NAME", None)

    # 4. Fail-closed when no selection, no override, no explicit
    model, source = resolve_effective_model(None)
    assert model is None
    assert source == "MODEL_SELECTION_REQUIRED"

    # 3. Environment override takes effect when no saved host selection
    monkeypatch.setenv("COMPANION_DEV_MODEL", "qwen-dev-env")
    model, source = resolve_effective_model(None)
    assert model == "qwen-dev-env"
    assert source == "dev_override"

    # 2. Saved host selection beats environment override
    save_model_selection("qwen3-vl-2b-instruct")
    model, source = resolve_effective_model(None)
    assert model == "qwen3-vl-2b-instruct"
    assert source == "saved_host_selection"

    # 1. Explicit model beats saved host selection AND environment override
    model, source = resolve_effective_model("explicit-request-model")
    assert model == "explicit-request-model"
    assert source == "explicit"


def test_persistence_across_restart(tmp_path, monkeypatch):
    """
    Model selection persisted in host_config.json survives across reloads,
    updates cleanly, and clears cleanly.
    """
    data_dir = tmp_path / "data"
    data_dir.mkdir(parents=True)
    monkeypatch.setattr(type(settings), "COMPANION_DATA_ROOT", property(lambda self: data_dir))

    assert get_saved_model_selection() is None

    # Persist model A
    save_model_selection("qwen3-vl-2b-instruct")
    assert get_saved_model_selection() == "qwen3-vl-2b-instruct"

    # Verify JSON file structure on disk
    config_file = data_dir / "config" / "host_config.json"
    assert config_file.is_file()
    data = json.loads(config_file.read_text(encoding="utf-8"))
    assert data["selected_model"] == "qwen3-vl-2b-instruct"
    assert data["schema_version"] == 1
    assert "updated_at" in data

    # Update to model B
    save_model_selection("qwen2.5-coder-7b")
    assert get_saved_model_selection() == "qwen2.5-coder-7b"

    # Clear selection
    clear_model_selection()
    assert get_saved_model_selection() is None


@pytest.mark.asyncio
async def test_one_time_loading_without_changing_default(llama_provider):
    """
    Calling load_model(model_name=X) loads the model into memory/router,
    but does NOT mutate the saved persistent host selection in host_config.json.
    """
    save_model_selection("default-saved-model")
    assert get_saved_model_selection() == "default-saved-model"

    temp_entry = _make_entry("temp-one-time-model", "temp-one-time-model", file_exists=True)
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"data": [{"id": "temp-one-time-model", "status": {"value": "loaded"}}]}

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", return_value=temp_entry), \
         patch.object(llama_provider, "_check_port_listening", return_value=True), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock, return_value=True) as mock_router_load, \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):

        result = await llama_provider.load_model("temp-one-time-model")

        assert result is True
        assert llama_provider._active_model_name == "temp-one-time-model"
        assert llama_provider.is_loaded() is True
        mock_router_load.assert_called_once_with("temp-one-time-model")

        # Invariant: Saved default in host_config.json MUST remain untouched
        assert get_saved_model_selection() == "default-saved-model"

        # Status must report selected != active
        status = await llama_provider.get_status()
        assert status.selected_model == "default-saved-model"
        assert status.active_model == "temp-one-time-model"
        assert status.model_loaded is True
        assert status.runtime_state == LLMRuntimeState.MODEL_READY


@pytest.mark.asyncio
async def test_load_failure_never_reports_model_as_active(llama_provider):
    """
    When model loading fails in the router/engine:
    - load_model() returns False
    - provider reports MODEL_ERROR
    - active_model is strictly None
    - status never falsely claims model is active or loaded
    """
    save_model_selection("qwen3-vl-2b-instruct")
    valid_entry = _make_entry("qwen3-vl-2b-instruct", "qwen3-vl-2b-instruct", file_exists=True)

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", return_value=valid_entry), \
         patch.object(llama_provider, "_check_port_listening", return_value=True), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock, return_value=False):

        result = await llama_provider.load_model("qwen3-vl-2b-instruct")

        assert result is False
        assert llama_provider.is_loaded() is False
        assert llama_provider._active_model_name is None
        assert llama_provider._runtime_state == LLMRuntimeState.MODEL_ERROR
        assert "MODEL_LOAD_FAILED" in (llama_provider._last_error or "")

        # In get_status(), router is running with no model loaded
        mock_empty_resp = MagicMock()
        mock_empty_resp.status_code = 200
        mock_empty_resp.json.return_value = {"data": []}

        with patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_empty_resp):
            status = await llama_provider.get_status()
            assert status.active_model is None
            assert status.model_loaded is False
            assert status.model_resident is False
            assert status.selected_model == "qwen3-vl-2b-instruct"
            assert status.runtime_state == LLMRuntimeState.MODEL_ERROR


@pytest.mark.asyncio
async def test_model_status_reporting_states(llama_provider):
    """
    Verify get_status() truthful reporting across:
    1. Unloaded with no selection
    2. Unloaded with saved selection
    3. Loaded and active
    4. Explicit unload
    """
    # 1. Unloaded with no saved selection
    assert get_saved_model_selection() is None
    status_empty = await llama_provider.get_status()
    assert status_empty.selected_model is None
    assert status_empty.active_model is None
    assert status_empty.model_loaded is False

    # 2. Saved selection present, but server stopped
    save_model_selection("qwen3-vl-2b-instruct")
    status_saved = await llama_provider.get_status()
    assert status_saved.selected_model == "qwen3-vl-2b-instruct"
    assert status_saved.active_model is None
    assert status_saved.model_loaded is False

    # 3. Model loaded and ready
    valid_entry = _make_entry("qwen3-vl-2b-instruct", "qwen3-vl-2b-instruct", file_exists=True)
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"data": [{"id": "qwen3-vl-2b-instruct", "status": {"value": "loaded"}}]}

    with patch("app.services.llm.llama_cpp.find_model_registry_entry", return_value=valid_entry), \
         patch.object(llama_provider, "_check_port_listening", return_value=True), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_router_load_model", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_resp):
        await llama_provider.load_model("qwen3-vl-2b-instruct")

        status_ready = await llama_provider.get_status()
        assert status_ready.selected_model == "qwen3-vl-2b-instruct"
        assert status_ready.active_model == "qwen3-vl-2b-instruct"
        assert status_ready.model_loaded is True
        assert status_ready.runtime_state == LLMRuntimeState.MODEL_READY

    # 4. Explicit unload: router alive, active_model cleared, selected preserved
    mock_empty_resp = MagicMock()
    mock_empty_resp.status_code = 200
    mock_empty_resp.json.return_value = {"data": []}

    with patch.object(llama_provider, "_router_unload_model", new_callable=AsyncMock, return_value=True), \
         patch.object(llama_provider, "_check_external_server", new_callable=AsyncMock, return_value=True), \
         patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_empty_resp):
        unload_success = await llama_provider.unload_model()
        assert unload_success is True

        status_unloaded = await llama_provider.get_status()
        assert status_unloaded.selected_model == "qwen3-vl-2b-instruct"
        assert status_unloaded.active_model is None
        assert status_unloaded.model_loaded is False
        assert status_unloaded.runtime_state == LLMRuntimeState.MODEL_UNLOADED


@pytest.mark.asyncio
async def test_api_endpoints_model_selection_and_load(client: AsyncClient, auth_headers: dict, tmp_path, monkeypatch):
    """
    Test API endpoints for model selection, load, and contract compliance:
    1. POST /api/v1/models/select with unknown model -> 404
    2. POST /api/v1/models/select with model missing primary file -> 400
    3. POST /api/v1/models/select with valid model, load_immediately=False -> 200 (persists in host_config)
    4. POST /api/v1/models/load with no model and no selection -> 422 MODEL_SELECTION_REQUIRED
    5. POST /api/v1/models/select with load_immediately=True when load fails -> 500, selection is saved, active_model is null
    """
    data_dir = tmp_path / "data"
    data_dir.mkdir(parents=True)
    monkeypatch.setattr(type(settings), "COMPANION_DATA_ROOT", property(lambda self: data_dir))
    monkeypatch.delenv("COMPANION_DEV_MODEL", raising=False)
    monkeypatch.setattr(settings, "DEV_MODEL_OVERRIDE", None)
    monkeypatch.setattr(settings, "DEFAULT_MODEL_NAME", None)
    clear_model_selection()

    def _get_err(resp):
        data = resp.json()
        return (data.get("error", {}).get("message") or data.get("detail") or "")

    # 1. 404 when model is not in registry
    with patch("app.api.v1.endpoints.llm.find_model_registry_entry", return_value=None):
        resp_404 = await client.post(
            "/api/v1/models/select",
            json={"model_name": "unknown-nonexistent-model"},
            headers=auth_headers,
        )
        assert resp_404.status_code == 404
        assert "not found in registry" in _get_err(resp_404).lower()

    # 2. 400 when model primary file is missing
    missing_entry = _make_entry("model-missing-file", "model-missing-file", file_exists=False)
    with patch("app.api.v1.endpoints.llm.find_model_registry_entry", return_value=missing_entry):
        resp_400 = await client.post(
            "/api/v1/models/select",
            json={"model_name": "model-missing-file"},
            headers=auth_headers,
        )
        assert resp_400.status_code == 400
        assert "missing on host" in _get_err(resp_400).lower()

    # 3. 200 with valid model and load_immediately=False
    valid_entry = _make_entry("qwen3-vl-2b-instruct", "qwen3-vl-2b-instruct", file_exists=True)
    with patch("app.api.v1.endpoints.llm.find_model_registry_entry", return_value=valid_entry):
        resp_select = await client.post(
            "/api/v1/models/select",
            json={"model_name": "qwen3-vl-2b-instruct", "load_immediately": False},
            headers=auth_headers,
        )
        assert resp_select.status_code == 200
        data_sel = resp_select.json()
        assert data_sel["selected_model"] == "qwen3-vl-2b-instruct"
        assert get_saved_model_selection() == "qwen3-vl-2b-instruct"

    # 4. 422 when load requested with no model specified and no selection present
    clear_model_selection()
    from app.services.llm.manager import get_llm_provider
    current_provider = get_llm_provider()
    current_provider._default_mock_model = None
    await current_provider.unload_model()
    resp_load_unselected = await client.post(
        "/api/v1/models/load",
        json={"profile": "balanced"},
        headers=auth_headers,
    )
    assert resp_load_unselected.status_code == 422
    assert "MODEL_SELECTION_REQUIRED" in _get_err(resp_load_unselected)

    # 5. 500 when load_immediately=True fails, but selection remains saved and active_model is null
    from app.services.llm.manager import llm_manager
    mock_provider = AsyncMock()
    mock_provider.load_model = AsyncMock(return_value=False)
    mock_provider._last_error = "ENGINE_GPU_OOM: Insufficient VRAM"
    mock_provider.get_status = AsyncMock(
        return_value=ModelStatusResponse(
            provider="mock",
            selected_model="qwen3-vl-2b-instruct",
            active_model=None,
            model_loaded=False,
            runtime_state=LLMRuntimeState.MODEL_ERROR,
        )
    )

    prev_provider = llm_manager.get_provider()
    llm_manager.set_provider(mock_provider)
    try:
        with patch("app.api.v1.endpoints.llm.find_model_registry_entry", return_value=valid_entry):
            resp_load_fail = await client.post(
                "/api/v1/models/select",
                json={"model_name": "qwen3-vl-2b-instruct", "load_immediately": True},
                headers=auth_headers,
            )
            assert resp_load_fail.status_code == 500
            assert "ENGINE_GPU_OOM" in _get_err(resp_load_fail)
            # Invariant: Selection was persisted in host_config.json
            assert get_saved_model_selection() == "qwen3-vl-2b-instruct"
    finally:
        llm_manager.set_provider(prev_provider)
