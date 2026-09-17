"""Tests for model registry service — Master Plan §16.2."""
import json
import importlib
from typing import Any, Dict, List, Optional, Tuple
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
        ModelManifest.model_validate({
            "id": "m", "display_name": "M", "primary_file": "p", "unrecognized_manifest_field": "bad"
        })

    with pytest.raises(ValidationError):
        ModelRuntimeHints.model_validate({"unrecognized_hints_field": 123})

    with pytest.raises(ValidationError):
        ModelRegistryEntry.model_validate({
            "manifest": {"id": "m", "display_name": "M", "primary_file": "p"},
            "library_state": {},
            "hints": {},
            "unrecognized_entry_field": "bad"
        })


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


# ==============================================================================
# Phase 8P.5 Effective Registry, Validation, Degradation & GGUF Parser Tests
# ==============================================================================

def make_synthetic_gguf(
    arch: Optional[str] = None,
    context_length: Optional[int] = None,
    file_type: Optional[int] = None,
    quantization_version: Optional[int] = None,
    magic: bytes = b"GGUF",
    version: int = 3,
    tensor_count: int = 0,
    extra_kvs: Optional[dict] = None,
    raw_payload_at_end: bytes = b"",
    override_kv_count: Optional[int] = None,
) -> bytes:
    """Build a minimal synthetic GGUF binary header for unit testing."""
    import struct
    buf = bytearray()
    buf.extend(magic)
    buf.extend(struct.pack("<I", version))
    buf.extend(struct.pack("<Q", tensor_count))

    kvs = []
    if arch is not None:
        kvs.append(("general.architecture", 8, arch))
    if context_length is not None and arch:
        kvs.append((f"{arch}.context_length", 4, context_length))
    if file_type is not None:
        kvs.append(("general.file_type", 4, file_type))
    if quantization_version is not None:
        kvs.append(("general.quantization_version", 4, quantization_version))
    if extra_kvs:
        for k, (t, v) in extra_kvs.items():
            kvs.append((k, t, v))

    kv_count = len(kvs) if override_kv_count is None else override_kv_count
    buf.extend(struct.pack("<Q", kv_count))

    for k, vtype, val in kvs:
        k_bytes = k.encode("utf-8")
        buf.extend(struct.pack("<Q", len(k_bytes)))
        buf.extend(k_bytes)
        buf.extend(struct.pack("<I", vtype))
        if vtype == 4:  # UINT32
            buf.extend(struct.pack("<I", val))
        elif vtype == 8:  # STRING
            val_bytes = val.encode("utf-8") if isinstance(val, str) else val
            buf.extend(struct.pack("<Q", len(val_bytes)))
            buf.extend(val_bytes)
        elif vtype == 9:  # ARRAY
            elem_type, items = val
            buf.extend(struct.pack("<I", elem_type))
            buf.extend(struct.pack("<Q", len(items)))
            for item in items:
                if elem_type == 4:
                    buf.extend(struct.pack("<I", item))
                elif elem_type == 8:
                    item_bytes = item.encode("utf-8") if isinstance(item, str) else item
                    buf.extend(struct.pack("<Q", len(item_bytes)))
                    buf.extend(item_bytes)

    if raw_payload_at_end:
        buf.extend(raw_payload_at_end)

    return bytes(buf)


def test_gguf_parser_valid_metadata(tmp_path):
    """Verify GGUF parser extracts architecture, dynamic context_length, quantization, and format version."""
    from app.services.model_registry import read_gguf_metadata
    gguf_bytes = make_synthetic_gguf(
        arch="qwen3vl",
        context_length=32768,
        file_type=15,  # Q4_K_M
        quantization_version=2,
    )
    test_file = tmp_path / "valid.gguf"
    test_file.write_bytes(gguf_bytes)

    meta = read_gguf_metadata(test_file)
    assert meta.architecture == "qwen3vl"
    assert meta.context_length == 32768
    assert meta.quantization == "Q4_K_M"
    assert meta.quantization_version == 2
    # Ensure quantization_version is NOT used as the quantization scheme
    assert meta.quantization != "2"


def test_gguf_parser_rejects_bad_magic(tmp_path):
    """Verify GGUF parser safely rejects invalid magic bytes."""
    from app.services.model_registry import read_gguf_metadata
    bad_file = tmp_path / "bad_magic.gguf"
    bad_file.write_bytes(b"NOTGGUF_HEADER_DATA")
    meta = read_gguf_metadata(bad_file)
    assert meta.architecture == ""
    assert meta.context_length is None
    assert meta.quantization == ""


def test_gguf_parser_handles_truncated_file(tmp_path):
    """Verify GGUF parser safely handles truncated files without crashing."""
    from app.services.model_registry import read_gguf_metadata
    full = make_synthetic_gguf(arch="llama", context_length=8192)
    trunc_file = tmp_path / "truncated.gguf"
    trunc_file.write_bytes(full[:14])  # Truncate mid-header
    meta = read_gguf_metadata(trunc_file)
    assert meta.architecture == ""
    assert meta.context_length is None


def test_gguf_parser_bounds_excessive_kv_count(tmp_path):
    """Verify GGUF parser stops safely when metadata_kv_count exceeds 256."""
    from app.services.model_registry import read_gguf_metadata
    huge_kv_bytes = make_synthetic_gguf(arch="test", override_kv_count=300)
    test_file = tmp_path / "huge_kv.gguf"
    test_file.write_bytes(huge_kv_bytes)
    meta = read_gguf_metadata(test_file)
    assert meta.architecture == ""


def test_gguf_parser_bounds_excessive_string_length(tmp_path):
    """Verify GGUF parser stops safely when string length exceeds 1024."""
    from app.services.model_registry import read_gguf_metadata
    import struct
    buf = bytearray(b"GGUF")
    buf.extend(struct.pack("<I", 3))  # version
    buf.extend(struct.pack("<Q", 0))  # tensor_count
    buf.extend(struct.pack("<Q", 1))  # kv_count = 1
    buf.extend(struct.pack("<Q", 2048))  # key string length = 2048 (> 1024 limit)
    buf.extend(b"x" * 2048)
    buf.extend(struct.pack("<I", 4))
    buf.extend(struct.pack("<I", 123))

    test_file = tmp_path / "long_str.gguf"
    test_file.write_bytes(bytes(buf))
    meta = read_gguf_metadata(test_file)
    assert meta.architecture == ""


def test_gguf_parser_bounds_excessive_array_length(tmp_path):
    """Verify GGUF parser stops safely when array element count exceeds 64."""
    from app.services.model_registry import read_gguf_metadata
    huge_arr = (4, [i for i in range(100)])  # 100 items > 64 limit
    buf = make_synthetic_gguf(extra_kvs={"tokenizer.tokens": (9, huge_arr)})
    test_file = tmp_path / "huge_arr.gguf"
    test_file.write_bytes(buf)
    meta = read_gguf_metadata(test_file)
    assert meta.architecture == ""


def test_gguf_parser_unknown_file_type_produces_empty_quantization(tmp_path):
    """Verify unknown general.file_type produces quantization='' without fabricating names."""
    from app.services.model_registry import read_gguf_metadata
    buf = make_synthetic_gguf(arch="llama", file_type=99999)
    test_file = tmp_path / "unknown_ftype.gguf"
    test_file.write_bytes(buf)
    meta = read_gguf_metadata(test_file)
    assert meta.architecture == "llama"
    assert meta.quantization == ""


@pytest.mark.parametrize(
    "ftype,expected_quant",
    [
        (15, "Q4_K_M"),
        (32, "BF16"),
        (33, ""),  # Removed from GGUF in llama.cpp b10936
        (34, ""),  # Removed from GGUF in llama.cpp b10936
        (35, ""),  # Removed from GGUF in llama.cpp b10936
        (36, "TQ1_0"),
        (37, "TQ2_0"),
        (38, "MXFP4_MOE"),
        (39, "NVFP4"),
        (40, "Q1_0"),
        (41, "Q2_0"),
        (999, ""),
    ]
)
def test_gguf_file_type_mappings_aligned_to_llama_b10936(tmp_path, ftype, expected_quant):
    """Verify general.file_type precisely follows llama.cpp b10936 llama_ftype enum."""
    from app.services.model_registry import read_gguf_metadata
    buf = make_synthetic_gguf(arch="test", file_type=ftype)
    test_file = tmp_path / f"ftype_{ftype}.gguf"
    test_file.write_bytes(buf)
    meta = read_gguf_metadata(test_file)
    assert meta.architecture == "test"
    assert meta.quantization == expected_quant


def test_gguf_parser_version_support_and_rejection(tmp_path):
    """Verify GGUF parser strictly supports v2/v3 and safely rejects v1, v0, and future versions > 3."""
    from app.services.model_registry import read_gguf_metadata

    # 1. GGUF v2 parses valid bounded metadata
    v2_buf = make_synthetic_gguf(arch="qwen3vl", context_length=16384, file_type=15, version=2)
    v2_file = tmp_path / "v2.gguf"
    v2_file.write_bytes(v2_buf)
    v2_meta = read_gguf_metadata(v2_file)
    assert v2_meta.architecture == "qwen3vl"
    assert v2_meta.context_length == 16384
    assert v2_meta.quantization == "Q4_K_M"

    # 2. GGUF v3 parses valid bounded metadata
    v3_buf = make_synthetic_gguf(arch="qwen3vl", context_length=32768, file_type=15, version=3)
    v3_file = tmp_path / "v3.gguf"
    v3_file.write_bytes(v3_buf)
    v3_meta = read_gguf_metadata(v3_file)
    assert v3_meta.architecture == "qwen3vl"
    assert v3_meta.context_length == 32768
    assert v3_meta.quantization == "Q4_K_M"

    # 3. GGUF v1 is safely rejected (unsupported by llama.cpp b10936)
    v1_buf = make_synthetic_gguf(arch="qwen3vl", context_length=8192, version=1)
    v1_file = tmp_path / "v1.gguf"
    v1_file.write_bytes(v1_buf)
    v1_meta = read_gguf_metadata(v1_file)
    assert v1_meta.architecture == ""
    assert v1_meta.context_length is None
    assert v1_meta.quantization == ""

    # 4. GGUF v0 is safely rejected
    v0_buf = make_synthetic_gguf(arch="qwen3vl", version=0)
    v0_file = tmp_path / "v0.gguf"
    v0_file.write_bytes(v0_buf)
    v0_meta = read_gguf_metadata(v0_file)
    assert v0_meta.architecture == ""

    # 5. Future version > 3 (e.g. v4, v99) is safely rejected
    for bad_ver in (4, 99):
        f_buf = make_synthetic_gguf(arch="qwen3vl", version=bad_ver)
        f_file = tmp_path / f"v{bad_ver}.gguf"
        f_file.write_bytes(f_buf)
        f_meta = read_gguf_metadata(f_file)
        assert f_meta.architecture == ""
        assert f_meta.context_length is None
        assert f_meta.quantization == ""


def test_gguf_parser_never_reads_tensor_payloads(tmp_path):
    """Verify GGUF parser stops after metadata and does not read trailing tensor bytes."""
    from app.services.model_registry import read_gguf_metadata
    trailing_payload = b"DO_NOT_READ_RAW_TENSOR_BYTES" * 100
    buf = make_synthetic_gguf(arch="qwen3vl", context_length=16384, raw_payload_at_end=trailing_payload)
    test_file = tmp_path / "tensor_payload.gguf"
    test_file.write_bytes(buf)
    meta = read_gguf_metadata(test_file)
    assert meta.architecture == "qwen3vl"
    assert meta.context_length == 16384


def test_effective_registry_factory_when_installed_absent(tmp_path):
    """Verify factory registry loads normally when installed registry does not exist."""
    import app.services.model_registry as mr

    factory_dir = tmp_path / "factory"
    factory_dir.mkdir()
    template_file = factory_dir / "registry.template.json"
    template_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "model-f1",
            "display_name": "Factory Model 1",
            "primary_file": "vision/model1.gguf",
            "capabilities": ["chat"],
        }]
    }), encoding="utf-8")

    nonexistent_installed = tmp_path / "nonexistent" / "models.json"

    with patch.object(mr, "_get_factory_model_root", return_value=factory_dir), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_get_installed_registry_path", return_value=nonexistent_installed):
        entries = mr._build_effective_registry()

    assert len(entries) == 1
    assert entries[0].manifest.id == "model-f1"
    assert entries[0].registry_source == "factory"


def test_empty_installed_registry_preserves_factory(tmp_path):
    """Verify an empty installed registry file preserves factory models."""
    import app.services.model_registry as mr

    factory_dir = tmp_path / "factory"
    factory_dir.mkdir()
    template_file = factory_dir / "registry.template.json"
    template_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "model-f1",
            "display_name": "Factory Model 1",
            "primary_file": "vision/model1.gguf",
        }]
    }), encoding="utf-8")

    installed_file = tmp_path / "installed" / "models.json"
    installed_file.parent.mkdir()
    installed_file.write_text(json.dumps({"_schema_version": "3", "models": []}), encoding="utf-8")

    with patch.object(mr, "_get_factory_model_root", return_value=factory_dir), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_get_installed_registry_path", return_value=installed_file):
        entries = mr._build_effective_registry()

    assert len(entries) == 1
    assert entries[0].manifest.id == "model-f1"
    assert entries[0].registry_source == "factory"


def test_installed_model_with_new_id_appends(tmp_path):
    """Verify an installed model with a new ID is appended to the effective registry."""
    import app.services.model_registry as mr

    factory_dir = tmp_path / "factory"
    factory_dir.mkdir()
    template_file = factory_dir / "registry.template.json"
    template_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "model-f1",
            "display_name": "Factory Model 1",
            "primary_file": "vision/model1.gguf",
        }]
    }), encoding="utf-8")

    installed_file = tmp_path / "installed" / "models.json"
    installed_file.parent.mkdir()
    installed_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "model-installed-new",
            "display_name": "Installed Model",
            "primary_file": "llm/new_model.gguf",
        }]
    }), encoding="utf-8")

    with patch.object(mr, "_get_factory_model_root", return_value=factory_dir), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_get_installed_registry_path", return_value=installed_file):
        entries = mr._build_effective_registry()

    assert len(entries) == 2
    ids = [e.manifest.id for e in entries]
    assert ids == ["model-f1", "model-installed-new"]
    sources = [e.registry_source for e in entries]
    assert sources == ["factory", "installed"]


def test_installed_model_shadows_factory_model_same_id(tmp_path):
    """Verify an installed model shadows a factory model of the same ID, appearing only once."""
    import app.services.model_registry as mr

    factory_dir = tmp_path / "factory"
    factory_dir.mkdir()
    template_file = factory_dir / "registry.template.json"
    template_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "qwen3-vl-4b-instruct",
            "display_name": "Factory Qwen 4B",
            "primary_file": "vision/factory_4b.gguf",
        }]
    }), encoding="utf-8")

    installed_file = tmp_path / "installed" / "models.json"
    installed_file.parent.mkdir()
    installed_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "qwen3-vl-4b-instruct",
            "display_name": "Custom Installed Qwen 4B",
            "primary_file": "custom/qwen4b.gguf",
        }]
    }), encoding="utf-8")

    with patch.object(mr, "_get_factory_model_root", return_value=factory_dir), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_get_installed_registry_path", return_value=installed_file):
        entries = mr._build_effective_registry()

    # Appears only once
    assert len(entries) == 1
    entry = entries[0]
    assert entry.manifest.id == "qwen3-vl-4b-instruct"
    assert entry.manifest.display_name == "Custom Installed Qwen 4B"
    assert entry.manifest.primary_file == "custom/qwen4b.gguf"
    assert entry.registry_source == "installed"


def test_malformed_installed_entry_preserves_factory_entry(tmp_path):
    """Verify a malformed individual installed entry does not erase a valid factory entry of the same ID."""
    import app.services.model_registry as mr

    factory_dir = tmp_path / "factory"
    factory_dir.mkdir()
    template_file = factory_dir / "registry.template.json"
    template_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "model-target",
            "display_name": "Valid Factory Target",
            "primary_file": "target.gguf",
        }]
    }), encoding="utf-8")

    installed_file = tmp_path / "installed" / "models.json"
    installed_file.parent.mkdir()
    # Missing required primary_file
    installed_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "model-target",
            "display_name": "Malformed Entry",
        }]
    }), encoding="utf-8")

    with patch.object(mr, "_get_factory_model_root", return_value=factory_dir), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_get_installed_registry_path", return_value=installed_file):
        entries = mr._build_effective_registry()

    assert len(entries) == 1
    assert entries[0].manifest.id == "model-target"
    assert entries[0].manifest.display_name == "Valid Factory Target"
    assert entries[0].registry_source == "factory"


def test_malformed_installed_registry_file_preserves_factory(tmp_path):
    """Verify a corrupted installed registry JSON file fails safely and preserves factory entries."""
    import app.services.model_registry as mr

    factory_dir = tmp_path / "factory"
    factory_dir.mkdir()
    template_file = factory_dir / "registry.template.json"
    template_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "model-f1",
            "display_name": "Factory 1",
            "primary_file": "f1.gguf",
        }]
    }), encoding="utf-8")

    installed_file = tmp_path / "installed" / "models.json"
    installed_file.parent.mkdir()
    installed_file.write_text("NOT_VALID_JSON{:::broken", encoding="utf-8")

    with patch.object(mr, "_get_factory_model_root", return_value=factory_dir), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_get_installed_registry_path", return_value=installed_file):
        entries = mr._build_effective_registry()

    assert len(entries) == 1
    assert entries[0].manifest.id == "model-f1"
    assert entries[0].registry_source == "factory"


def test_source_aware_asset_root_resolution(tmp_path):
    """Verify factory asset paths resolve under FACTORY_MODEL_ROOT and installed under MODEL_LIBRARY_DIR."""
    import app.services.model_registry as mr
    from app.schemas.model_registry import ModelManifest, ModelLibraryState, ModelRuntimeHints, ModelRegistryEntry

    factory_root = tmp_path / "factory_root"
    factory_root.mkdir()
    installed_root = tmp_path / "installed_root"
    installed_root.mkdir()

    (factory_root / "f_model.gguf").write_bytes(b"F" * 100)
    (installed_root / "i_model.gguf").write_bytes(b"I" * 100)

    f_entry = ModelRegistryEntry(
        manifest=ModelManifest(id="f", display_name="F", primary_file="f_model.gguf"),
        library_state=ModelLibraryState(),
        hints=ModelRuntimeHints(),
        registry_source="factory",
    )
    i_entry = ModelRegistryEntry(
        manifest=ModelManifest(id="i", display_name="I", primary_file="i_model.gguf"),
        library_state=ModelLibraryState(),
        hints=ModelRuntimeHints(),
        registry_source="installed",
    )

    with patch.object(mr, "_get_factory_model_root", return_value=factory_root), \
         patch.object(mr, "_get_model_library_dir", return_value=installed_root):
        val_f = mr._validate_entry(f_entry)
        val_i = mr._validate_entry(i_entry)

    assert val_f.primary_file_exists is True
    assert val_i.primary_file_exists is True


def test_path_traversal_and_absolute_paths_rejected(tmp_path):
    """Verify path traversal (..) and absolute paths are rejected and cannot escape source root."""
    import app.services.model_registry as mr
    from app.schemas.model_registry import ModelManifest, ModelLibraryState, ModelRuntimeHints, ModelRegistryEntry

    base_dir = tmp_path / "root"
    base_dir.mkdir()

    # Traversal test
    assert mr._resolve_asset_path(base_dir, "../../../escaped.gguf") is None
    # Absolute path test
    assert mr._resolve_asset_path(base_dir, "C:/Windows/System32/calc.exe") is None
    assert mr._resolve_asset_path(base_dir, "/etc/passwd") is None

    entry = ModelRegistryEntry(
        manifest=ModelManifest(id="bad-traversal", display_name="Bad", primary_file="../../secret.txt"),
        library_state=ModelLibraryState(),
        hints=ModelRuntimeHints(),
        registry_source="installed",
    )

    with patch.object(mr, "_get_model_library_dir", return_value=base_dir):
        validated = mr._validate_entry(entry)

    assert validated.primary_file_exists is False
    assert validated.validation_status.value == "missing_primary"


def test_missing_primary_validation_semantics(tmp_path):
    """Verify missing primary file produces missing_primary, primary_file_exists=False, available_capabilities=[]."""
    import app.services.model_registry as mr
    from app.schemas.model_registry import ModelManifest, ModelLibraryState, ModelRuntimeHints, ModelRegistryEntry, ModelCapability

    models_dir = tmp_path / "models"
    models_dir.mkdir()

    entry = ModelRegistryEntry(
        manifest=ModelManifest(
            id="missing-p",
            display_name="Missing Primary",
            primary_file="nonexistent.gguf",
            capabilities=[ModelCapability.chat, ModelCapability.vision],
        ),
        library_state=ModelLibraryState(),
        hints=ModelRuntimeHints(),
        registry_source="factory",
    )

    with patch.object(mr, "_get_factory_model_root", return_value=models_dir):
        res = mr._validate_entry(entry)

    assert res.validation_status.value == "missing_primary"
    assert res.primary_file_exists is False
    assert res.library_state.available_capabilities == []
    # Manifest capabilities must NOT be cleared
    assert res.manifest.capabilities == [ModelCapability.chat, ModelCapability.vision]


def test_complete_model_verified_semantics(tmp_path):
    """Verify present primary file and companions produce verified validation state."""
    import app.services.model_registry as mr
    from app.schemas.model_registry import (
        ModelManifest, ModelLibraryState, ModelRuntimeHints,
        ModelRegistryEntry, ModelCapability, CompanionFile
    )

    models_dir = tmp_path / "models"
    models_dir.mkdir()
    (models_dir / "primary.gguf").write_bytes(b"P" * 1024)
    (models_dir / "mmproj.gguf").write_bytes(b"M" * 512)

    entry = ModelRegistryEntry(
        manifest=ModelManifest(
            id="complete-model",
            display_name="Complete",
            primary_file="primary.gguf",
            companion_files=[CompanionFile(role="mmproj", path="mmproj.gguf")],
            capabilities=[ModelCapability.chat, ModelCapability.vision],
        ),
        library_state=ModelLibraryState(),
        hints=ModelRuntimeHints(),
        registry_source="factory",
    )

    with patch.object(mr, "_get_factory_model_root", return_value=models_dir):
        res = mr._validate_entry(entry)

    assert res.validation_status.value == "verified"
    assert res.library_state.discovery_state.value == "verified"
    assert res.primary_file_exists is True
    assert res.companion_files_valid is True
    assert res.library_state.available_capabilities == [ModelCapability.chat, ModelCapability.vision]


def test_missing_mmproj_graceful_capability_degradation(tmp_path):
    """Verify missing mmproj degrades vision from available_capabilities, keeps chat, and leaves manifest untouched."""
    import app.services.model_registry as mr
    from app.schemas.model_registry import (
        ModelManifest, ModelLibraryState, ModelRuntimeHints,
        ModelRegistryEntry, ModelCapability, CompanionFile, ValidationStatus
    )

    models_dir = tmp_path / "models"
    models_dir.mkdir()
    (models_dir / "primary.gguf").write_bytes(b"P" * 1024)
    # mmproj is deliberately missing!

    entry = ModelRegistryEntry(
        manifest=ModelManifest(
            id="degraded-model",
            display_name="Degraded",
            primary_file="primary.gguf",
            companion_files=[CompanionFile(role="mmproj", path="missing_mmproj.gguf")],
            capabilities=[ModelCapability.chat, ModelCapability.vision, ModelCapability.multilingual],
        ),
        library_state=ModelLibraryState(),
        hints=ModelRuntimeHints(),
        registry_source="factory",
    )

    with patch.object(mr, "_get_factory_model_root", return_value=models_dir):
        res = mr._validate_entry(entry)

    # Status is missing_companion, NOT incompatible
    assert res.validation_status == ValidationStatus.missing_companion
    assert res.validation_status != ValidationStatus.incompatible
    assert res.primary_file_exists is True
    assert res.companion_files_valid is False

    # Vision capability degraded from available_capabilities
    assert ModelCapability.vision not in res.library_state.available_capabilities
    # Text capabilities preserved
    assert ModelCapability.chat in res.library_state.available_capabilities
    assert ModelCapability.multilingual in res.library_state.available_capabilities

    # Manifest capabilities MUST REMAIN UNCHANGED
    assert res.manifest.capabilities == [ModelCapability.chat, ModelCapability.vision, ModelCapability.multilingual]


def test_truthful_unregistered_scanner(tmp_path):
    """Verify unregistered GGUF scanner returns truthful UNKNOWN metadata without fabricating capabilities or context."""
    import app.services.model_registry as mr
    from app.schemas.model_registry import ModelVariant, ReasoningMode, ModelDiscoveryState, ValidationStatus

    factory_models = tmp_path / "factory_models"
    factory_models.mkdir()
    template_file = factory_models / "registry.template.json"
    template_file.write_text(json.dumps({"_schema_version": "3", "models": []}), encoding="utf-8")

    # Write synthetic GGUF with architecture and context
    gguf_data = make_synthetic_gguf(arch="qwen3vl", context_length=32768, file_type=15)
    # Even if filename contains "VL", "Vision", "Thinking", NO capabilities may be inferred!
    model_file = factory_models / "Qwen3-VL-Vision-Thinking-7B.gguf"
    model_file.write_bytes(gguf_data)

    with patch.object(mr, "_get_factory_model_root", return_value=factory_models), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_MIN_SIZE_BYTES", 0):
        entries = mr.build_model_list()

    assert len(entries) == 1
    entry = entries[0]

    # Truthful unregistered metadata
    assert entry.manifest.variant == ModelVariant.unknown
    assert entry.variant == "unknown"
    assert entry.manifest.capabilities == []
    assert entry.capabilities == []
    assert entry.manifest.input_modalities == []
    assert entry.manifest.runtime_compatibility == []
    assert entry.manifest.reasoning_mode == ReasoningMode.unknown
    assert entry.library_state.discovery_state == ModelDiscoveryState.discovered
    assert entry.validation_status == ValidationStatus.unregistered
    assert entry.primary_file_exists is True

    # Metadata detected from GGUF header
    assert entry.manifest.architecture == "qwen3vl"
    assert entry.manifest.model_max_context == 32768
    assert entry.context_limit == 32768
    assert entry.manifest.quantization == "Q4_K_M"
    assert entry.quantization == "Q4_K_M"



def test_malformed_gguf_remains_discoverable_as_unregistered(tmp_path):
    """Verify a malformed or non-GGUF file remains discoverable with unknown metadata."""
    from app.core.config import settings
    import app.services.model_registry as mr
    from app.schemas.model_registry import ModelVariant

    factory_models = tmp_path / "factory_models"
    factory_models.mkdir()
    template_file = factory_models / "registry.template.json"
    template_file.write_text(json.dumps({"_schema_version": "3", "models": []}), encoding="utf-8")

    # Corrupt GGUF file
    model_file = factory_models / "corrupt_model.gguf"
    model_file.write_bytes(b"CORRUPT_NOT_GGUF_HEADER")

    with patch.object(settings, "FACTORY_MODEL_ROOT", factory_models), \
         patch.object(settings, "FACTORY_REGISTRY_TEMPLATE", template_file), \
         patch.object(settings, "MODELS_DIR", factory_models), \
         patch.object(mr, "_MIN_SIZE_BYTES", 0):
        entries = mr.build_model_list()

    assert len(entries) == 1
    entry = entries[0]
    assert entry.manifest.id == "corrupt-model"
    assert entry.manifest.variant == ModelVariant.unknown
    assert entry.manifest.architecture == ""
    assert entry.manifest.quantization == ""


def test_legacy_registry_json_does_not_override_factory(tmp_path):
    """Verify legacy repository models/registry.json is ignored in favor of canonical factory template."""
    import app.services.model_registry as mr

    factory_dir = tmp_path / "factory"
    factory_dir.mkdir()
    template_file = factory_dir / "registry.template.json"
    template_file.write_text(json.dumps({
        "_schema_version": "3",
        "models": [{
            "id": "canonical-factory-model",
            "display_name": "Canonical Template Model",
            "primary_file": "canonical.gguf",
        }]
    }), encoding="utf-8")

    # Legacy gitignored registry.json in same dir with different data
    legacy_file = factory_dir / "registry.json"
    legacy_file.write_text(json.dumps({
        "_schema_version": "1",
        "models": [{
            "id": "legacy-override-attempt",
            "display_name": "Should Be Ignored",
            "primary_file": "legacy.gguf",
        }]
    }), encoding="utf-8")

    with patch.object(mr, "_get_factory_model_root", return_value=factory_dir), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_get_installed_registry_path", return_value=tmp_path / "no_installed.json"):
        entries = mr._build_effective_registry()

    assert len(entries) == 1
    assert entries[0].manifest.id == "canonical-factory-model"
    assert entries[0].manifest.display_name == "Canonical Template Model"


def test_unregistered_model_without_gguf_metadata_has_none_context(tmp_path):
    """Verify unregistered GGUF without context_length in header has model_max_context=None and context_limit=None."""
    import app.services.model_registry as mr

    factory_models = tmp_path / "factory_models"
    factory_models.mkdir()
    template_file = factory_models / "registry.template.json"
    template_file.write_text(json.dumps({"_schema_version": "3", "models": []}), encoding="utf-8")

    # Write synthetic GGUF with architecture but NO context_length
    gguf_data = make_synthetic_gguf(arch="llama", context_length=None)
    model_file = factory_models / "plain_llama.gguf"
    model_file.write_bytes(gguf_data)

    with patch.object(mr, "_get_factory_model_root", return_value=factory_models), \
         patch.object(mr, "_get_factory_template_path", return_value=template_file), \
         patch.object(mr, "_MIN_SIZE_BYTES", 0):
        entries = mr.build_model_list()

    assert len(entries) == 1
    entry = entries[0]
    assert entry.manifest.architecture == "llama"
    assert entry.manifest.model_max_context is None
    assert entry.context_limit is None
