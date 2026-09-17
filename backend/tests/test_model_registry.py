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


@pytest.mark.asyncio
async def test_registry_endpoint_authenticated_shape(client, auth_headers):
    """GET /api/v1/models/registry with auth returns both structured layers and flat bridge."""
    res = await client.get("/api/v1/models/registry", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert isinstance(data, list)
    if data:
        entry = data[0]
        # Verify structured layers
        assert "manifest" in entry
        assert "library_state" in entry
        assert "hints" in entry
        assert "runtime_model_id" in entry
        assert "registry_source" in entry
        # Verify full flat compatibility bridge for frontend
        flat_fields = [
            "id", "display_name", "family", "variant", "primary_file", "companion_files",
            "capabilities", "recommended_profiles", "estimated_vram_gb", "estimated_ram_gb",
            "quantization", "parameters", "context_limit", "license", "source",
            "validation_status", "primary_file_exists", "companion_files_valid", "size_gb"
        ]
        for field in flat_fields:
            assert field in entry, f"Missing flat field '{field}' in API response"


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


# ==============================================================================
# Phase 8P.4 Schema v3 & Bridge Verification Tests
# ==============================================================================

def test_schema_v3_enums():
    """Verify all new enums and values required by Phase 8P.4."""
    from app.schemas.model_registry import (
        ModelAssetType, ModelVariant, InputModality,
        ModelDiscoveryState, ReasoningMode, CapabilityProvenance, ValidationStatus
    )
    # 1. New enum values
    assert [e.value for e in ModelAssetType] == ["gguf", "mmproj", "lora", "embedding", "tokenizer"]
    assert [e.value for e in ModelVariant] == ["instruct", "thinking", "base", "code", "unknown"]
    assert [e.value for e in InputModality] == ["text", "image", "audio", "video"]
    assert [e.value for e in ModelDiscoveryState] == ["discovered", "registered", "verified", "incompatible"]
    assert [e.value for e in ReasoningMode] == ["always_on", "toggleable", "unsupported", "unknown"]
    assert [e.value for e in CapabilityProvenance] == ["declared", "detected", "verified", "unknown"]
    # 2. ValidationStatus includes incompatible
    assert ValidationStatus.incompatible.value == "incompatible"
    assert "incompatible" in [s.value for s in ValidationStatus]


def test_schema_v3_subschemas():
    """Verify CompanionFile, CapabilityEntry, CompanionArtifactStatus, GenerationDefaults."""
    from app.schemas.model_registry import (
        CompanionFile, CapabilityEntry, CompanionArtifactStatus, GenerationDefaults,
        ModelCapability, CapabilityProvenance
    )
    # 6. CompanionFile accepts legacy role/path without sha256
    cf = CompanionFile(role="mmproj", path="vision/mmproj.gguf")
    assert cf.sha256 is None
    cf_with_hash = CompanionFile(role="mmproj", path="vision/mmproj.gguf", sha256="abc123hash")
    assert cf_with_hash.sha256 == "abc123hash"

    # 7. CapabilityEntry preserves capability + supported + provenance
    cap = CapabilityEntry(capability=ModelCapability.vision, supported=True, provenance=CapabilityProvenance.declared)
    assert cap.capability == ModelCapability.vision
    assert cap.supported is True
    assert cap.provenance == CapabilityProvenance.declared

    cas = CompanionArtifactStatus(artifact=cf, exists=True)
    assert cas.exists is True
    assert cas.artifact.path == "vision/mmproj.gguf"

    gd = GenerationDefaults(temperature=0.7, top_p=0.9, top_k=40, min_p=0.05, repeat_penalty=1.1)
    assert gd.temperature == 0.7


def test_model_manifest_fields_and_defaults():
    """Verify ModelManifest accepted fields, default_factory, and context separation."""
    from app.schemas.model_registry import (
        ModelManifest, ModelAssetType, ModelVariant, ModelCapability, InputModality, ReasoningMode, CompanionFile
    )
    # 3. ModelManifest accepts valid schema-v3 model metadata
    m1 = ModelManifest(
        id="test-m",
        display_name="Test Model",
        asset_type=ModelAssetType.gguf,
        family="Qwen3-VL",
        architecture="qwen3vl",
        variant=ModelVariant.instruct,
        parameters="2B",
        quantization="Q4_K_M",
        reasoning_mode=ReasoningMode.unsupported,
        capabilities=[ModelCapability.chat, ModelCapability.vision],
        input_modalities=[InputModality.text, InputModality.image],
        model_max_context=32768,
        runtime_compatibility=["llama.cpp"],
        primary_file="vision/test.gguf",
        companion_files=[CompanionFile(role="mmproj", path="vision/mmproj.gguf")],
        license="Apache-2.0",
        source="local"
    )
    assert m1.id == "test-m"
    assert m1.model_max_context == 32768
    # 4. model_max_context permits None (for unknown/unregistered)
    m_none = ModelManifest(
        id="test-none",
        display_name="Test None",
        primary_file="vision/test.gguf",
        model_max_context=None
    )
    assert m_none.model_max_context is None

    # 5. runtime_compatibility defaults safely via default_factory
    m2 = ModelManifest(id="test-2", display_name="Test 2", primary_file="vision/test2.gguf")
    m3 = ModelManifest(id="test-3", display_name="Test 3", primary_file="vision/test3.gguf")
    assert m2.runtime_compatibility == []
    assert m2.runtime_compatibility is not m3.runtime_compatibility


def test_model_registry_entry_structured_and_flat_bridge():
    """Verify ModelRegistryEntry composition, structured serialization, and complete flat bridge."""
    from app.schemas.model_registry import (
        ModelRegistryEntry, ModelManifest, ModelLibraryState, ModelRuntimeHints,
        ModelAssetType, ModelVariant, ModelCapability, InputModality, ReasoningMode,
        ValidationStatus, CompanionFile, CompanionArtifactStatus
    )
    cf = CompanionFile(role="mmproj", path="vision/mmproj.gguf")
    manifest = ModelManifest(
        id="qwen3-vl-2b-instruct",
        display_name="Qwen3-VL 2B Instruct",
        asset_type=ModelAssetType.gguf,
        family="Qwen3-VL",
        architecture="qwen3vl",
        variant=ModelVariant.instruct,
        parameters="2.0B",
        quantization="Q4_K_M",
        reasoning_mode=ReasoningMode.unsupported,
        capabilities=[ModelCapability.chat, ModelCapability.vision],
        input_modalities=[InputModality.text, InputModality.image],
        model_max_context=32768,
        runtime_compatibility=["llama.cpp"],
        primary_file="vision/qwen3-vl-2b-instruct/Qwen.gguf",
        companion_files=[cf],
        license="Apache-2.0",
        source="local"
    )
    library_state = ModelLibraryState(
        validation_status=ValidationStatus.verified,
        primary_file_exists=True,
        size_gb=1.6,
        companion_artifact_statuses=[CompanionArtifactStatus(artifact=cf, exists=True)],
        available_capabilities=[ModelCapability.chat, ModelCapability.vision]
    )
    hints = ModelRuntimeHints(
        recommended_profiles=["eco", "balanced"],
        estimated_vram_gb=2.4,
        estimated_ram_gb=0.6
    )
    entry = ModelRegistryEntry(
        manifest=manifest,
        library_state=library_state,
        hints=hints,
        runtime_model_id="qwen3-vl-2b-instruct",
        registry_source="factory"
    )

    # 8. Structured layers serialized
    dump = entry.model_dump()
    assert "manifest" in dump
    assert "library_state" in dump
    assert "hints" in dump
    assert dump["runtime_model_id"] == "qwen3-vl-2b-instruct"
    assert dump["registry_source"] == "factory"

    # 9, 10-18. Temporary flat serialization bridge verification
    assert entry.id == "qwen3-vl-2b-instruct"
    assert entry.display_name == "Qwen3-VL 2B Instruct"
    assert entry.family == "Qwen3-VL"
    assert entry.variant == "instruct"
    assert entry.primary_file == "vision/qwen3-vl-2b-instruct/Qwen.gguf"
    assert len(entry.companion_files) == 1
    assert entry.quantization == "Q4_K_M"
    assert entry.parameters == "2.0B"
    assert entry.context_limit == 32768
    assert entry.context_limit == entry.manifest.model_max_context
    assert entry.capabilities == [ModelCapability.chat, ModelCapability.vision]
    assert entry.recommended_profiles == ["eco", "balanced"]
    assert entry.estimated_vram_gb == 2.4
    assert entry.estimated_ram_gb == 0.6
    assert entry.license == "Apache-2.0"
    assert entry.source == "local"
    assert entry.validation_status == ValidationStatus.verified
    assert entry.primary_file_exists is True
    assert entry.companion_files_valid is True
    assert entry.size_gb == 1.6

    # 19. The COMPLETE current frontend RegistryEntry shape is present in serialized output
    frontend_required_fields = [
        "id", "display_name", "family", "variant", "primary_file", "companion_files",
        "capabilities", "recommended_profiles", "estimated_vram_gb", "estimated_ram_gb",
        "quantization", "parameters", "context_limit", "license", "source",
        "validation_status", "primary_file_exists", "companion_files_valid", "size_gb"
    ]
    for field_name in frontend_required_fields:
        assert field_name in dump, f"Missing frontend compatibility field: {field_name}"


def test_companion_files_valid_derivation():
    """Verify companion_files_valid truthfully reflects artifact existence."""
    from app.schemas.model_registry import (
        ModelRegistryEntry, ModelManifest, ModelLibraryState, ModelRuntimeHints,
        CompanionFile, CompanionArtifactStatus
    )
    cf1 = CompanionFile(role="mmproj", path="vision/mmproj.gguf")
    manifest = ModelManifest(
        id="test", display_name="Test", primary_file="test.gguf",
        companion_files=[cf1]
    )
    # When companion exists -> True
    e_valid = ModelRegistryEntry(
        manifest=manifest,
        library_state=ModelLibraryState(companion_artifact_statuses=[CompanionArtifactStatus(artifact=cf1, exists=True)]),
        hints=ModelRuntimeHints()
    )
    assert e_valid.companion_files_valid is True

    # When companion missing -> False
    e_invalid = ModelRegistryEntry(
        manifest=manifest,
        library_state=ModelLibraryState(companion_artifact_statuses=[CompanionArtifactStatus(artifact=cf1, exists=False)]),
        hints=ModelRuntimeHints()
    )
    assert e_invalid.companion_files_valid is False

    # When no companions declared -> True
    m_no_comp = ModelManifest(id="test2", display_name="Test 2", primary_file="test2.gguf", companion_files=[])
    e_no_comp = ModelRegistryEntry(manifest=m_no_comp, library_state=ModelLibraryState(), hints=ModelRuntimeHints())
    assert e_no_comp.companion_files_valid is True


def test_schema_extra_forbid():
    """Verify BaseSchema extra='forbid' rejects unrecognized fields."""
    from pydantic import ValidationError
    from app.schemas.model_registry import ModelManifest, ModelRegistryEntry, ModelRuntimeHints, ModelLibraryState

    with pytest.raises(ValidationError):
        ModelManifest(id="m", display_name="M", primary_file="p", unrecognized_manifest_field="bad")

    with pytest.raises(ValidationError):
        ModelRuntimeHints(unrecognized_hints_field=123)

    with pytest.raises(ValidationError):
        ModelRegistryEntry(
            manifest=ModelManifest(id="m", display_name="M", primary_file="p"),
            library_state=ModelLibraryState(),
            hints=ModelRuntimeHints(),
            unrecognized_entry_field="bad"
        )


def test_registry_template_v3_structure_and_parsing():
    """Verify models/registry.template.json schema version 3 and parse all 5 factory entries."""
    from app.core.config import settings
    from app.schemas.model_registry import (
        ModelAssetType, ModelVariant, ModelRegistryEntry
    )
    template_path = settings.MODELS_DIR / "registry.template.json"
    assert template_path.exists()
    content = json.loads(template_path.read_text(encoding="utf-8"))

    # 20. _schema_version == "3"
    assert content.get("_schema_version") == "3"
    assert "_note" in content
    assert "not a model whitelist" in content["_note"].lower() or "not a restrictive whitelist" in content["_note"].lower()

    models = content.get("models", [])
    assert len(models) == 5

    # 21 & 22. All five factory entries contain new fields and parse under schema v3
    for m in models:
        assert m["asset_type"] == "gguf"
        assert m["architecture"] == "qwen3vl"
        assert m["input_modalities"] == ["text", "image"]
        assert m["model_max_context"] == 32768
        assert m["runtime_compatibility"] == ["llama.cpp"]
        if m["variant"] == "thinking":
            assert m["reasoning_mode"] == "always_on"
        else:
            assert m["reasoning_mode"] == "unsupported"

        # Verify it parses into ModelRegistryEntry
        entry = ModelRegistryEntry(**m)
        assert entry.manifest.asset_type == ModelAssetType.gguf
        assert entry.manifest.model_max_context == 32768
        assert entry.context_limit == 32768
        assert entry.variant in (ModelVariant.instruct.value, ModelVariant.thinking.value)
