"""Tests for model registry service — Master Plan §16.2."""
import json
import importlib
import pytest
from unittest.mock import patch


def test_scan_excludes_mmproj_and_small_files(tmp_path):
    """Auto-scan must not surface mmproj-* or files under 100 MB."""
    from app.core.config import settings
    models_dir = tmp_path / "models"
    (models_dir / "vision").mkdir(parents=True)
    # Valid primary model
    (models_dir / "vision" / "TestModel-Q4.gguf").write_bytes(b"x" * (101 * 1024 * 1024))
    # Companion — excluded by prefix
    (models_dir / "vision" / "mmproj-TestModel.gguf").write_bytes(b"x" * (200 * 1024 * 1024))
    # Too small — excluded by size
    (models_dir / "vision" / "small.gguf").write_bytes(b"x" * (50 * 1024 * 1024))

    with patch.object(settings, "MODELS_DIR", models_dir):
        import app.services.model_registry as mr
        importlib.reload(mr)
        found = mr._scan_models_dir()

    names = [p.name for p in found]
    assert "TestModel-Q4.gguf" in names
    assert "mmproj-TestModel.gguf" not in names
    assert "small.gguf" not in names


def test_missing_registry_json_returns_scan_only(tmp_path):
    """build_model_list returns scan-only results when registry.json is absent."""
    from app.core.config import settings
    models_dir = tmp_path / "models"
    models_dir.mkdir()
    with patch.object(settings, "MODELS_DIR", models_dir):
        import app.services.model_registry as mr
        importlib.reload(mr)
        result = mr.build_model_list()
    assert isinstance(result, list)


def test_registry_validates_missing_primary(tmp_path):
    """Entry with missing primary_file gets validation_status=missing_primary."""
    from app.core.config import settings
    models_dir = tmp_path / "models"
    models_dir.mkdir()
    registry = {
        "_schema_version": "1",
        "models": [{
            "id": "test-model",
            "display_name": "Test",
            "family": "Test",
            "variant": "instruct",
            "primary_file": "vision/nonexistent.gguf",
            "companion_files": [],
            "quantization": "Q4_K_M",
            "parameters": "4B",
            "context_limit": 4096,
            "capabilities": ["chat"],
            "recommended_profiles": ["balanced"],
            "estimated_vram_gb": 4.0,
            "estimated_ram_gb": 0.8,
            "license": "Apache-2.0",
        }]
    }
    (models_dir / "registry.json").write_text(json.dumps(registry), encoding="utf-8")
    with patch.object(settings, "MODELS_DIR", models_dir):
        import app.services.model_registry as mr
        importlib.reload(mr)
        result = mr.build_model_list()
    assert len(result) == 1
    assert result[0].validation_status == "missing_primary"
    assert result[0].primary_file_exists is False


@pytest.mark.asyncio
async def test_registry_endpoint_requires_auth(client):
    """GET /api/v1/models/registry must reject unauthenticated requests."""
    res = await client.get("/api/v1/models/registry")
    assert res.status_code in (401, 403)


def test_resolve_runtime_model_id():
    """Verify resolve_runtime_model_id correctly resolves IDs, paths, and filenames."""
    from app.services.model_registry import resolve_runtime_model_id
    # Empty / None
    assert resolve_runtime_model_id(None) == ""
    assert resolve_runtime_model_id("") == ""
    # Direct folder ID
    assert resolve_runtime_model_id("qwen3-vl-4b-instruct") == "qwen3-vl-4b-instruct"
    # Relative path
    assert resolve_runtime_model_id("vision/qwen3-vl-4b-instruct/Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf") == "qwen3-vl-4b-instruct"
    # Bare filename
    assert resolve_runtime_model_id("Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf") == "qwen3-vl-4b-instruct"


def test_mock_provider_cold_boot_truthfulness():
    """Verify MockLLMProvider starts in unloaded state without fabricating active model."""
    from app.services.llm.mock import MockLLMProvider
    mock = MockLLMProvider()
    assert mock.is_loaded() is False
    assert mock._active_model is None


def test_router_config_port_and_models_dir():
    """Verify LLAMA_ROUTER_PORT is 8085 (preventing 8080 conflict) and LLAMA_MODELS_DIR is models/vision."""
    from app.core.config import settings
    assert settings.LLAMA_ROUTER_PORT == 8085
    assert "8085" in settings.LLAMA_SERVER_URL
    assert settings.LLAMA_MODELS_DIR.name == "vision"
    assert settings.LLAMA_MODELS_DIR.parent == settings.MODELS_DIR

