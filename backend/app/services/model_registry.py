"""
Model Registry service — Master Plan §16.2 (Batch 8P.5 Effective Registry & GGUF Inspection).
Constructs canonical three-layer ModelRegistryEntry with temporary flat bridge.
Reads canonical factory template (models/registry.template.json) and installed registry
(COMPANION_DATA_ROOT/library/registry/models.json), merging them deterministically.
Inspects unregistered GGUFs using a pure-Python, bounded GGUF header reader.
Never writes to repository models/ directory or mutates model weights.
"""
import json
import logging
from dataclasses import dataclass, field, replace
from pathlib import Path
import struct
from typing import Any, Dict, List, Literal, Optional, Tuple

from app.core.config import settings
from app.schemas.model_registry import (
    CapabilityEntry,
    CapabilityProvenance,
    CompanionArtifactStatus,
    CompanionFile,
    GenerationDefaults,
    InputModality,
    ModelAssetType,
    ModelCapability,
    ModelDiscoveryState,
    ModelLibraryState,
    ModelManifest,
    ModelRegistryEntry,
    ModelRuntimeHints,
    ModelVariant,
    ReasoningMode,
    ValidationStatus,
)

logger = logging.getLogger("app.services.model_registry")
_EXCLUDE_PREFIXES = ("mmproj-", "lfs-test")
_MIN_SIZE_BYTES = 100 * 1024 * 1024

MAX_METADATA_KV_COUNT = 256
MAX_STRING_LENGTH = 1024
MAX_ARRAY_LENGTH = 64
MAX_SKIP_ARRAY_LENGTH = 1_000_000
MAX_CHAT_TEMPLATE_LENGTH = 65_536

_GGUF_SCALAR_SIZES: Dict[int, int] = {
    0: 1,   # UINT8
    1: 1,   # INT8
    2: 2,   # UINT16
    3: 2,   # INT16
    4: 4,   # UINT32
    5: 4,   # INT32
    6: 4,   # FLOAT32
    7: 1,   # BOOL
    10: 8,  # UINT64
    11: 8,  # INT64
    12: 8,  # FLOAT64
}

# Standard GGUF file_type (llama_ftype from include/llama.h at llama.cpp b10936)
GGUF_FILE_TYPE_MAP: Dict[int, str] = {
    0: "F32",
    1: "F16",
    2: "Q4_0",
    3: "Q4_1",
    7: "Q8_0",
    8: "Q5_0",
    9: "Q5_1",
    10: "Q2_K",
    11: "Q3_K_S",
    12: "Q3_K_M",
    13: "Q3_K_L",
    14: "Q4_K_S",
    15: "Q4_K_M",
    16: "Q5_K_S",
    17: "Q5_K_M",
    18: "Q6_K",
    19: "IQ2_XXS",
    20: "IQ2_XS",
    21: "Q2_K_S",
    22: "IQ3_XS",
    23: "IQ3_XXS",
    24: "IQ1_S",
    25: "IQ4_NL",
    26: "IQ3_S",
    27: "IQ3_M",
    28: "IQ2_S",
    29: "IQ2_M",
    30: "IQ4_XS",
    31: "IQ1_M",
    32: "BF16",
    # 33, 34, 35 removed from GGUF files in llama.cpp b10936
    36: "TQ1_0",
    37: "TQ2_0",
    38: "MXFP4_MOE",
    39: "NVFP4",
    40: "Q1_0",
    41: "Q2_0",
}


@dataclass
class GGUFMetadata:
    architecture: str = ""
    context_length: Optional[int] = None
    quantization: str = ""
    quantization_version: Optional[int] = None
    general_type: str = ""
    model_name: str = ""
    size_label: str = ""
    license_name: str = ""
    has_chat_template: bool = False
    has_vision_encoder: bool = False
    raw_metadata: Dict[str, Any] = field(default_factory=dict)


_STRUCT_U64 = struct.Struct("<Q")
_GGUF_METADATA_CACHE: Dict[Tuple[str, int, int], GGUFMetadata] = {}


def _seek_forward_bounded(f, skip_bytes: int, file_size: int) -> None:
    if skip_bytes < 0:
        raise ValueError(f"Negative GGUF seek offset: {skip_bytes}")
    pos = f.tell()
    if pos + skip_bytes > file_size:
        raise EOFError(f"GGUF skip offset {pos + skip_bytes} exceeds file size {file_size}")
    f.seek(pos + skip_bytes)


def _skip_gguf_array(f, file_size: int) -> None:
    elem_type = struct.unpack("<I", _read_exact(f, 4))[0]
    if elem_type == 9:
        raise ValueError("Nested arrays are not supported in GGUF metadata")
    (arr_len,) = struct.unpack("<Q", _read_exact(f, 8))
    if arr_len < 0 or arr_len > MAX_SKIP_ARRAY_LENGTH:
        raise ValueError(f"Skippable GGUF array length {arr_len} outside bounds [0, {MAX_SKIP_ARRAY_LENGTH}]")
    if elem_type in _GGUF_SCALAR_SIZES:
        _seek_forward_bounded(f, arr_len * _GGUF_SCALAR_SIZES[elem_type], file_size)
        return
    if elem_type == 8:
        f_read = f.read
        unpack_u64 = _STRUCT_U64.unpack
        for _ in range(arr_len):
            raw_len = f_read(8)
            if len(raw_len) < 8:
                raise EOFError("Unexpected EOF reading GGUF array string length")
            (slen,) = unpack_u64(raw_len)
            if slen < 0 or slen > MAX_CHAT_TEMPLATE_LENGTH:
                raise ValueError(f"Array element string length {slen} outside bounds")
            if slen <= 65536:
                data = f_read(slen)
                if len(data) < slen:
                    raise EOFError("Unexpected EOF skipping GGUF array string")
            else:
                _seek_forward_bounded(f, slen, file_size)
        return
    raise ValueError(f"Unsupported GGUF array element type: {elem_type}")


def _read_exact(f, n: int) -> bytes:
    if n < 0:
        raise ValueError(f"Invalid byte count to read: {n}")
    data = f.read(n)
    if len(data) < n:
        raise EOFError(f"Unexpected EOF reading GGUF header (expected {n} bytes, got {len(data)})")
    return data


def _read_gguf_string(f) -> str:
    (slen,) = struct.unpack("<Q", _read_exact(f, 8))
    if slen < 0 or slen > MAX_STRING_LENGTH:
        raise ValueError(f"String length {slen} outside allowed bounds [0, {MAX_STRING_LENGTH}]")
    raw = _read_exact(f, slen)
    return raw.decode("utf-8", errors="replace")


def _read_gguf_value(f, val_type: int) -> Any:
    if val_type == 0:  # UINT8
        return struct.unpack("<B", _read_exact(f, 1))[0]
    elif val_type == 1:  # INT8
        return struct.unpack("<b", _read_exact(f, 1))[0]
    elif val_type == 2:  # UINT16
        return struct.unpack("<H", _read_exact(f, 2))[0]
    elif val_type == 3:  # INT16
        return struct.unpack("<h", _read_exact(f, 2))[0]
    elif val_type == 4:  # UINT32
        return struct.unpack("<I", _read_exact(f, 4))[0]
    elif val_type == 5:  # INT32
        return struct.unpack("<i", _read_exact(f, 4))[0]
    elif val_type == 6:  # FLOAT32
        return struct.unpack("<f", _read_exact(f, 4))[0]
    elif val_type == 7:  # BOOL
        return bool(struct.unpack("<B", _read_exact(f, 1))[0])
    elif val_type == 8:  # STRING
        return _read_gguf_string(f)
    elif val_type == 9:  # ARRAY
        elem_type = struct.unpack("<I", _read_exact(f, 4))[0]
        if elem_type == 9:
            raise ValueError("Nested arrays are not supported in GGUF metadata")
        (arr_len,) = struct.unpack("<Q", _read_exact(f, 8))
        if arr_len < 0 or arr_len > MAX_ARRAY_LENGTH:
            raise ValueError(f"Array length {arr_len} outside allowed bounds [0, {MAX_ARRAY_LENGTH}]")
        return [_read_gguf_value(f, elem_type) for _ in range(arr_len)]
    elif val_type == 10:  # UINT64
        return struct.unpack("<Q", _read_exact(f, 8))[0]
    elif val_type == 11:  # INT64
        return struct.unpack("<q", _read_exact(f, 8))[0]
    elif val_type == 12:  # FLOAT64
        return struct.unpack("<d", _read_exact(f, 8))[0]
    else:
        raise ValueError(f"Unsupported GGUF value type: {val_type}")


def read_gguf_metadata(path: Path) -> GGUFMetadata:
    """
    Pure Python, bounded, zero-dependency GGUF header reader.
    Supports GGUF v2 and v3 (aligned with llama.cpp b10936). GGUF v1 and unsupported
    versions fail safely to empty metadata.
    Reads metadata only; never loads tensor payloads or memory-maps the model.
    Returns safe default GGUFMetadata on missing, truncated, or malformed files.
    """
    result = GGUFMetadata()
    if not path.is_file():
        return result

    try:
        st = path.stat()
        file_size = st.st_size
        cache_key = (str(path), file_size, st.st_mtime_ns) if file_size >= 65536 else None
        if cache_key is not None and cache_key in _GGUF_METADATA_CACHE:
            cached = _GGUF_METADATA_CACHE[cache_key]
            return replace(cached, raw_metadata=dict(cached.raw_metadata))
        with open(path, "rb", buffering=256 * 1024) as f:
            magic = f.read(4)
            if magic != b"GGUF":
                return result

            (version,) = struct.unpack("<I", _read_exact(f, 4))
            if version not in (2, 3):
                return result

            (tensor_count,) = struct.unpack("<Q", _read_exact(f, 8))
            (kv_count,) = struct.unpack("<Q", _read_exact(f, 8))

            if kv_count < 0 or kv_count > MAX_METADATA_KV_COUNT:
                logger.debug(
                    f"GGUF metadata kv_count {kv_count} outside bounds [0, {MAX_METADATA_KV_COUNT}] for {path.name}"
                )
                return result

            raw_metadata: Dict[str, Any] = {}
            for _ in range(kv_count):
                key = _read_gguf_string(f)
                val_type = struct.unpack("<I", _read_exact(f, 4))[0]
                if val_type == 9 and key.startswith("tokenizer.ggml."):
                    _skip_gguf_array(f, file_size)
                    continue
                if val_type == 8 and key == "tokenizer.chat_template":
                    (slen,) = struct.unpack("<Q", _read_exact(f, 8))
                    if slen < 0 or slen > MAX_CHAT_TEMPLATE_LENGTH:
                        raise ValueError(
                            f"tokenizer.chat_template length {slen} outside bounds [0, {MAX_CHAT_TEMPLATE_LENGTH}]"
                        )
                    _seek_forward_bounded(f, slen, file_size)
                    if slen > 0:
                        result.has_chat_template = True
                    continue
                val = _read_gguf_value(f, val_type)
                raw_metadata[key] = val

            result.raw_metadata = raw_metadata

            # 1. Architecture & extended general metadata
            arch = raw_metadata.get("general.architecture")
            if isinstance(arch, str) and arch:
                result.architecture = arch
                ctx_key = f"{arch}.context_length"
                ctx_val = raw_metadata.get(ctx_key)
                if isinstance(ctx_val, int) and ctx_val > 0:
                    result.context_length = ctx_val

            gtype = raw_metadata.get("general.type")
            if isinstance(gtype, str):
                result.general_type = gtype
            gname = raw_metadata.get("general.name")
            if isinstance(gname, str):
                result.model_name = gname
            slabel = raw_metadata.get("general.size_label")
            if isinstance(slabel, str):
                result.size_label = slabel
            glic = raw_metadata.get("general.license")
            if isinstance(glic, str):
                result.license_name = glic
            clip_vision = raw_metadata.get("clip.has_vision_encoder")
            if isinstance(clip_vision, bool):
                result.has_vision_encoder = clip_vision

            # 3. Quantization from general.file_type ONLY (llama.cpp b10936 llama_ftype mapping)
            ftype = raw_metadata.get("general.file_type")
            if isinstance(ftype, int):
                result.quantization = GGUF_FILE_TYPE_MAP.get(ftype, "")

            # 4. Quantization version (format version metadata only, NOT quantization scheme)
            qver = raw_metadata.get("general.quantization_version")
            if isinstance(qver, int):
                result.quantization_version = qver

            if cache_key is not None:
                _GGUF_METADATA_CACHE[cache_key] = replace(
                    result, raw_metadata=dict(result.raw_metadata)
                )

    except Exception as exc:
        logger.debug(f"GGUF header inspection error on {path.name}: {exc}")
        return result

    return result


def assess_hardware_suitability(
    file_size_bytes: int,
    architecture: str = "",
    dedicated_vram_gb: Optional[float] = None,
    companion_size_bytes: int = 0,
    context_size: Optional[int] = None,
    total_ram_gb: Optional[float] = None,
):
    """Advisory VRAM/hardware preflight assessment (runtime-and-models.md §2.8)."""
    from app.schemas.model_registry import PreflightAssessmentOut
    from app.services.hardware_probe import probe_host_hardware

    hw = None
    if dedicated_vram_gb is None or total_ram_gb is None:
        hw = probe_host_hardware()
    vram_budget = float(
        dedicated_vram_gb if dedicated_vram_gb is not None else hw.dedicated_vram_gb
    )

    weights_gb = max(0.0, float(file_size_bytes + companion_size_bytes)) / (1024 ** 3)
    os_reserve_gb = max(1.2, vram_budget * 0.15)
    usable_vram_gb = max(0.0, vram_budget - os_reserve_gb)

    ctx = context_size or 4096
    kv_overhead_gb = (
        0.85
        if ctx <= 4096
        else (1.75 if ctx <= 8192 else (3.3 if ctx <= 16384 else 5.0))
    )
    estimated_vram_gb = round(weights_gb * 1.15 + kv_overhead_gb, 2)
    est_max_gb = round(weights_gb * 1.15 + 1.75, 2)

    if estimated_vram_gb <= usable_vram_gb * 0.78:
        status: Literal["recommended", "supported_with_warning", "not_recommended"] = "recommended"
        if est_max_gb <= usable_vram_gb * 0.65 and (vram_budget >= 12.0 or weights_gb <= 1.2):
            profile: Literal["eco", "balanced", "maximum"] = "maximum"
        else:
            profile = "balanced"
        message = (
            f"Fits comfortably on {vram_budget:.1f} GB GPU "
            f"(~{estimated_vram_gb:.1f} GB est. VRAM; ~{usable_vram_gb:.1f} GB usable after OS reserve)."
        )
    elif estimated_vram_gb <= usable_vram_gb:
        status = "supported_with_warning"
        profile = "balanced"
        message = (
            f"Tight fit on {vram_budget:.1f} GB GPU (~{estimated_vram_gb:.1f} GB est. VRAM vs "
            f"~{usable_vram_gb:.1f} GB usable); Balanced recommended."
        )
    else:
        status = "not_recommended"
        profile = "eco"
        message = (
            f"Needs ~{estimated_vram_gb:.1f} GB VRAM, exceeding ~{usable_vram_gb:.1f} GB usable on "
            f"{vram_budget:.1f} GB GPU; Eco (CPU offload) recommended to avoid RAM spillover."
        )

    return PreflightAssessmentOut(
        status=status,
        estimated_vram_gb=estimated_vram_gb,
        host_dedicated_vram_gb=round(vram_budget, 2),
        recommended_profile=profile,
        message=message,
    )


def compute_recommended_profiles_for_model(
    file_size_bytes: int,
    companion_size_bytes: int = 0,
    fallback_vram_gb: float = 0.0,
    dedicated_vram_gb: Optional[float] = None,
) -> Tuple[List[str], float]:
    """Derive PC-aware ordered recommended profiles and est. VRAM for a model entry."""
    effective_bytes = file_size_bytes
    if effective_bytes <= 0 and fallback_vram_gb > 0.0:
        # Approximate GGUF+companion weights from template VRAM hint when weights aren't on disk
        effective_bytes = int(max(0.5, fallback_vram_gb * 0.85) * (1024 ** 3))

    balanced = assess_hardware_suitability(
        effective_bytes,
        dedicated_vram_gb=dedicated_vram_gb,
        companion_size_bytes=companion_size_bytes,
        context_size=4096,
    )
    maximum = assess_hardware_suitability(
        effective_bytes,
        dedicated_vram_gb=dedicated_vram_gb,
        companion_size_bytes=companion_size_bytes,
        context_size=8192,
    )

    ordered: List[str] = []
    if balanced.status == "not_recommended":
        ordered = ["eco"]
    else:
        ordered.append("balanced")
        if maximum.status == "recommended":
            ordered.append("maximum")
        elif balanced.status == "supported_with_warning":
            ordered.append("eco")
    return ordered, balanced.estimated_vram_gb


def _get_factory_model_root() -> Path:
    if settings.MODELS_DIR != (settings.BASE_DIR.parent / "models"):
        return settings.MODELS_DIR
    return settings.FACTORY_MODEL_ROOT


def _get_factory_template_path() -> Path:
    root = _get_factory_model_root()
    template = root / "registry.template.json"
    if template.exists():
        return template
    if root != (settings.BASE_DIR.parent / "models"):
        mock_reg = root / "registry.json"
        if mock_reg.exists():
            return mock_reg
    return settings.FACTORY_REGISTRY_TEMPLATE


def _get_installed_registry_path() -> Path:
    return settings.INSTALLED_REGISTRY_PATH


def _get_model_library_dir() -> Path:
    return settings.MODEL_LIBRARY_DIR


def _asset_root_for_entry(entry: ModelRegistryEntry) -> Path:
    if entry.registry_source == "installed":
        return _get_model_library_dir()
    return _get_factory_model_root()


def _resolve_asset_path(base_dir: Path, rel_path: str) -> Optional[Path]:
    """
    Safely resolve a relative path against base_dir.
    Returns None if rel_path is absolute, empty, or escapes base_dir.
    """
    if not rel_path or not isinstance(rel_path, str):
        return None
    p = Path(rel_path)
    if p.is_absolute():
        return None
    try:
        base_resolved = base_dir.resolve()
        candidate = (base_dir / p).resolve()
        candidate.relative_to(base_resolved)
        return candidate
    except (ValueError, RuntimeError):
        return None


def _load_registry_json() -> list:
    """Legacy helper for loading raw registry models from factory template."""
    p = _get_factory_template_path()
    if not p.exists():
        return []
    try:
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f).get("models", [])
    except Exception:
        return []


def _parse_registry_entry_dict(raw: dict, source: Literal["factory", "installed"]) -> Optional[ModelRegistryEntry]:
    """Parse a single raw registry dictionary into a ModelRegistryEntry."""
    if not isinstance(raw, dict) or "id" not in raw or not raw["id"] or "primary_file" not in raw:
        return None
    try:
        companion_files = [
            CompanionFile(
                role=c["role"],
                path=c["path"],
                sha256=c.get("sha256"),
            )
            for c in raw.get("companion_files", [])
            if isinstance(c, dict) and "role" in c and "path" in c
        ]

        capabilities: List[ModelCapability] = []
        for cap_str in raw.get("capabilities", []):
            try:
                capabilities.append(ModelCapability(cap_str))
            except ValueError:
                pass

        input_modalities: List[InputModality] = []
        for mod_str in raw.get("input_modalities", []):
            try:
                input_modalities.append(InputModality(mod_str))
            except ValueError:
                pass

        variant_val = raw.get("variant")
        if variant_val:
            try:
                variant = ModelVariant(variant_val)
            except ValueError:
                variant = ModelVariant.unknown
        else:
            variant = ModelVariant.unknown

        reasoning_mode_val = raw.get("reasoning_mode")
        if reasoning_mode_val:
            try:
                reasoning_mode = ReasoningMode(reasoning_mode_val)
            except ValueError:
                reasoning_mode = ReasoningMode.unknown
        else:
            reasoning_mode = ReasoningMode.unknown

        raw_asset_type = raw.get("asset_type")
        if raw_asset_type:
            try:
                asset_type = ModelAssetType(raw_asset_type)
            except ValueError:
                asset_type = ModelAssetType.gguf
        else:
            asset_type = ModelAssetType.gguf

        model_max_context = raw.get("model_max_context", raw.get("context_limit"))
        if model_max_context is not None:
            try:
                model_max_context = int(model_max_context)
            except (ValueError, TypeError):
                model_max_context = None

        runtime_compat = raw.get("runtime_compatibility")
        if runtime_compat is not None and isinstance(runtime_compat, list):
            runtime_compatibility = [str(r) for r in runtime_compat]
        else:
            runtime_compatibility = []

        manifest = ModelManifest(
            id=str(raw["id"]),
            display_name=str(raw.get("display_name", raw["id"])),
            asset_type=asset_type,
            family=str(raw.get("family", "")),
            architecture=str(raw.get("architecture", "")),
            variant=variant,
            parameters=str(raw.get("parameters", "")),
            quantization=str(raw.get("quantization", "")),
            reasoning_mode=reasoning_mode,
            capabilities=capabilities,
            input_modalities=input_modalities,
            model_max_context=model_max_context,
            runtime_compatibility=runtime_compatibility,
            primary_file=str(raw["primary_file"]),
            companion_files=companion_files,
            chat_template=raw.get("chat_template"),
            license=str(raw.get("license", "")),
            source=str(raw.get("source", "")),
            sha256_primary=raw.get("sha256_primary"),
        )

        parsed_provenance: List[CapabilityEntry] = []
        raw_prov = raw.get("capability_provenance")
        if isinstance(raw_prov, list):
            for item in raw_prov:
                if isinstance(item, dict) and "capability" in item:
                    try:
                        parsed_provenance.append(
                            CapabilityEntry(
                                capability=ModelCapability(item["capability"]),
                                supported=bool(item.get("supported", True)),
                                provenance=CapabilityProvenance(
                                    item.get("provenance", CapabilityProvenance.declared.value)
                                ),
                            )
                        )
                    except ValueError:
                        pass
        if not parsed_provenance:
            parsed_provenance = [
                CapabilityEntry(capability=c, supported=True, provenance=CapabilityProvenance.declared)
                for c in capabilities
            ]

        library_state = ModelLibraryState(
            discovery_state=ModelDiscoveryState.registered,
            validation_status=ValidationStatus.unregistered,
            primary_file_exists=False,
            size_gb=None,
            companion_artifact_statuses=[],
            available_capabilities=list(capabilities),
            capability_provenance=parsed_provenance,
        )

        gen_defaults = None
        if raw.get("generation_defaults") and isinstance(raw["generation_defaults"], dict):
            gen_defaults = GenerationDefaults(**raw["generation_defaults"])

        hints = ModelRuntimeHints(
            recommended_profiles=list(raw.get("recommended_profiles", ["balanced"])),
            estimated_vram_gb=float(raw.get("estimated_vram_gb", 0.0)),
            estimated_ram_gb=float(raw.get("estimated_ram_gb", 0.0)),
            generation_defaults=gen_defaults,
        )

        entry = ModelRegistryEntry(
            manifest=manifest,
            library_state=library_state,
            hints=hints,
            runtime_model_id=str(raw.get("runtime_model_id") or raw["id"]),
            registry_source=source,
        )
        return entry
    except Exception as exc:
        logger.warning(f"Failed to parse model entry from {source}: {exc}")
        return None


def _build_effective_registry() -> List[ModelRegistryEntry]:
    """
    Build the effective model registry by merging factory and installed registries.
    1. Factory template is loaded from canonical factory source.
    2. Legacy models/registry.json is checked and logged as deprecated local state if present.
    3. Installed registry is loaded from settings.INSTALLED_REGISTRY_PATH if present.
    4. Merged: installed entries shadow factory entries with the same ID.
       New installed entries are appended.
       Malformed installed entries/files fail safely and preserve factory entries.
    """
    # Check legacy local state (read-only notification)
    legacy_path = settings.FACTORY_MODEL_ROOT / "registry.json"
    if legacy_path.exists():
        logger.debug(
            "Found legacy models/registry.json - deprecated local state, ignored in favor of canonical factory/installed sources"
        )

    # 1. Load factory registry
    factory_entries: List[ModelRegistryEntry] = []
    factory_path = _get_factory_template_path()
    if factory_path.exists():
        try:
            with open(factory_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            raw_models = data.get("models", []) if isinstance(data, dict) else []
            for item in raw_models:
                entry = _parse_registry_entry_dict(item, source="factory")
                if entry:
                    factory_entries.append(entry)
        except Exception as exc:
            logger.warning(f"Failed to load factory registry template from {factory_path}: {exc}")

    # 2. Check installed registry
    installed_path = _get_installed_registry_path()
    if not installed_path.exists():
        return factory_entries

    try:
        with open(installed_path, "r", encoding="utf-8") as f:
            installed_data = json.load(f)
    except Exception as exc:
        logger.warning(f"Failed to parse installed registry {installed_path}: {exc} - falling back to factory entries")
        return factory_entries

    if not isinstance(installed_data, dict):
        logger.warning(f"Installed registry {installed_path} root is not a dictionary - falling back to factory entries")
        return factory_entries

    raw_installed_models = installed_data.get("models")
    if not raw_installed_models or not isinstance(raw_installed_models, list):
        return factory_entries

    installed_entries: List[ModelRegistryEntry] = []
    for item in raw_installed_models:
        entry = _parse_registry_entry_dict(item, source="installed")
        if entry:
            installed_entries.append(entry)
        else:
            logger.warning(f"Skipping malformed installed registry entry in {installed_path}")

    # Merge:
    # Installed entry with same ID shadows factory entry in-place.
    # New installed entries are appended.
    installed_by_id = {e.manifest.id: e for e in installed_entries}
    effective: List[ModelRegistryEntry] = []
    seen_ids = set()

    for fe in factory_entries:
        mid = fe.manifest.id
        if mid in installed_by_id:
            effective.append(installed_by_id[mid])
            seen_ids.add(mid)
        else:
            effective.append(fe)
            seen_ids.add(mid)

    for ie in installed_entries:
        mid = ie.manifest.id
        if mid not in seen_ids:
            effective.append(ie)
            seen_ids.add(mid)

    return effective


def _validate_entry(entry: ModelRegistryEntry) -> ModelRegistryEntry:
    """
    Validate an entry against disk according to its registry_source.
    Handles graceful degradation: missing mmproj removes vision capability
    from library_state.available_capabilities without prohibiting model or mutating manifest.
    Missing primary marks model unavailable (available_capabilities=[]).
    """
    base_dir = _asset_root_for_entry(entry)
    preserved_prov = {
        cp.capability: cp.provenance for cp in entry.library_state.capability_provenance
    }
    primary_resolved = _resolve_asset_path(base_dir, entry.manifest.primary_file)
    primary_exists = primary_resolved is not None and primary_resolved.is_file()
    entry.library_state.primary_file_exists = primary_exists

    if not primary_exists:
        entry.library_state.validation_status = ValidationStatus.missing_primary
        entry.library_state.discovery_state = (
            ModelDiscoveryState.discovered
            if entry.library_state.discovery_state == ModelDiscoveryState.discovered
            else ModelDiscoveryState.registered
        )
        entry.library_state.size_gb = None
        entry.library_state.available_capabilities = []
        entry.library_state.companion_artifact_statuses = []
        entry.library_state.capability_provenance = [
            CapabilityEntry(
                capability=c,
                supported=False,
                provenance=preserved_prov.get(c, CapabilityProvenance.declared),
            )
            for c in entry.manifest.capabilities
        ]
        return entry

    assert primary_resolved is not None
    entry.library_state.size_gb = round(primary_resolved.stat().st_size / (1024 ** 3), 2)

    companion_statuses: List[CompanionArtifactStatus] = []
    missing_roles = set()
    all_companions_valid = True

    for companion in entry.manifest.companion_files:
        comp_resolved = _resolve_asset_path(base_dir, companion.path)
        comp_exists = comp_resolved is not None and comp_resolved.is_file()
        companion_statuses.append(CompanionArtifactStatus(artifact=companion, exists=comp_exists))
        if not comp_exists:
            all_companions_valid = False
            missing_roles.add(companion.role.lower())

    entry.library_state.companion_artifact_statuses = companion_statuses

    if not all_companions_valid:
        entry.library_state.validation_status = ValidationStatus.missing_companion
        entry.library_state.discovery_state = (
            ModelDiscoveryState.discovered
            if entry.library_state.discovery_state == ModelDiscoveryState.discovered
            else ModelDiscoveryState.registered
        )
        # Graceful capability degradation
        available = list(entry.manifest.capabilities)
        if "mmproj" in missing_roles:
            if ModelCapability.vision in available:
                available.remove(ModelCapability.vision)
        entry.library_state.available_capabilities = available
        entry.library_state.capability_provenance = [
            CapabilityEntry(
                capability=c,
                supported=(c in available),
                provenance=preserved_prov.get(c, CapabilityProvenance.declared),
            )
            for c in entry.manifest.capabilities
        ]
        return entry

    # All artifacts present
    entry.library_state.validation_status = ValidationStatus.verified
    entry.library_state.discovery_state = ModelDiscoveryState.verified
    entry.library_state.available_capabilities = list(entry.manifest.capabilities)
    entry.library_state.capability_provenance = [
        CapabilityEntry(
            capability=c,
            supported=True,
            provenance=preserved_prov.get(c, CapabilityProvenance.declared),
        )
        for c in entry.manifest.capabilities
    ]
    return entry


def _scan_directory_for_ggufs(root: Path) -> List[Path]:
    """Scan a root directory recursively for candidate GGUF files."""
    results: List[Path] = []
    if not root.exists() or not root.is_dir():
        return results
    for gguf in root.rglob("*.gguf"):
        if not gguf.is_file():
            continue
        if any(gguf.name.startswith(p) for p in _EXCLUDE_PREFIXES):
            continue
        if gguf.stat().st_size < _MIN_SIZE_BYTES:
            continue
        results.append(gguf)
    return results


def _scan_models_dir(root: Optional[Path] = None) -> List[Path]:
    """Legacy wrapper scanning the factory models directory."""
    target_root = root or _get_factory_model_root()
    return _scan_directory_for_ggufs(target_root)


def build_model_list() -> List[ModelRegistryEntry]:
    """
    1. Parse and merge factory and installed registries via _build_effective_registry().
    2. Validate each entry against disk using source-aware paths.
    3. Scan factory and installed roots for unregistered .gguf files.
    4. Return registered entries (instruct < thinking < base < code < unknown) followed by unregistered.
    """
    effective_entries = _build_effective_registry()
    registered: List[ModelRegistryEntry] = []
    registered_primary_files = set()

    for entry in effective_entries:
        validated_entry = _validate_entry(entry)
        base_dir = _asset_root_for_entry(validated_entry)
        primary_bytes = 0
        companion_bytes = 0
        if validated_entry.library_state.primary_file_exists:
            p_path = _resolve_asset_path(base_dir, validated_entry.manifest.primary_file)
            if p_path is not None and p_path.is_file():
                primary_bytes = p_path.stat().st_size
            for comp in validated_entry.manifest.companion_files:
                c_path = _resolve_asset_path(base_dir, comp.path)
                if c_path is not None and c_path.is_file():
                    companion_bytes += c_path.stat().st_size
        rec_profiles, est_vram = compute_recommended_profiles_for_model(
            file_size_bytes=primary_bytes,
            companion_size_bytes=companion_bytes,
            fallback_vram_gb=validated_entry.hints.estimated_vram_gb,
        )
        validated_entry.hints.recommended_profiles = rec_profiles
        validated_entry.hints.estimated_vram_gb = est_vram
        registered_primary_files.add((validated_entry.registry_source, validated_entry.manifest.primary_file))
        registered.append(validated_entry)

    variant_order = {"instruct": 0, "thinking": 1, "base": 2, "code": 3, "unknown": 99}
    registered.sort(
        key=lambda e: variant_order.get(
            e.manifest.variant.value if isinstance(e.manifest.variant, ModelVariant) else str(e.manifest.variant), 99
        )
    )

    unregistered: List[ModelRegistryEntry] = []
    sources: List[Tuple[Literal["factory", "installed"], Path]] = [
        ("factory", _get_factory_model_root()),
        ("installed", _get_model_library_dir()),
    ]
    seen_unregistered_ids = set(e.manifest.id for e in registered)

    for source, root in sources:
        for path in _scan_directory_for_ggufs(root):
            try:
                relative = path.relative_to(root).as_posix()
            except ValueError:
                continue
            if (source, relative) in registered_primary_files:
                continue

            size_gb = round(path.stat().st_size / (1024 ** 3), 2)
            folder_name = path.parent.name if path.parent not in (root, root / "vision") else path.stem

            meta = read_gguf_metadata(path)

            base_id = path.stem.lower().replace("_", "-").replace(".", "-")
            uid = base_id
            if uid in seen_unregistered_ids:
                uid = f"{base_id}-{source}"
            seen_unregistered_ids.add(uid)

            manifest = ModelManifest(
                id=uid,
                display_name=path.stem,
                asset_type=ModelAssetType.gguf,
                family="",
                architecture=meta.architecture,
                variant=ModelVariant.unknown,
                parameters="",
                quantization=meta.quantization,
                reasoning_mode=ReasoningMode.unknown,
                capabilities=[],
                input_modalities=[],
                model_max_context=meta.context_length,
                runtime_compatibility=[],
                primary_file=relative,
                companion_files=[],
            )
            library_state = ModelLibraryState(
                discovery_state=ModelDiscoveryState.discovered,
                validation_status=ValidationStatus.unregistered,
                primary_file_exists=True,
                size_gb=size_gb,
                companion_artifact_statuses=[],
                available_capabilities=[],
                capability_provenance=[],
            )
            rec_unreg, est_unreg = compute_recommended_profiles_for_model(
                file_size_bytes=path.stat().st_size,
            )
            hints = ModelRuntimeHints(
                recommended_profiles=rec_unreg,
                estimated_vram_gb=est_unreg,
                estimated_ram_gb=0.0,
            )
            unregistered.append(
                ModelRegistryEntry(
                    manifest=manifest,
                    library_state=library_state,
                    hints=hints,
                    runtime_model_id=folder_name,
                    registry_source=source,
                )
            )

    result = registered + unregistered
    logger.info(f"Model registry: {len(registered)} registered, {len(unregistered)} unregistered")
    return result


def find_model_registry_entry(
    identifier: Optional[str],
    entries: Optional[List[ModelRegistryEntry]] = None,
) -> Optional[ModelRegistryEntry]:
    """Canonical model matcher: finds a ModelRegistryEntry across manifest.id, runtime_model_id, primary_file, or filename/stem."""
    if not identifier:
        return None
    clean_id = identifier.replace("\\", "/").strip()
    model_entries = entries if entries is not None else build_model_list()
    for entry in model_entries:
        candidate_matches = {
            entry.manifest.id,
            entry.runtime_model_id,
            entry.manifest.primary_file,
            Path(entry.manifest.primary_file).name,
            Path(entry.manifest.primary_file).stem,
        }
        if clean_id in {c for c in candidate_matches if c}:
            return entry
    return None


def resolve_runtime_model_id(
    identifier: Optional[str],
    entries: Optional[List[ModelRegistryEntry]] = None,
) -> str:
    """Resolve an incoming identifier to the router runtime_model_id, sharing canonical registry matching."""
    if not identifier:
        return ""
    clean_id = identifier.replace("\\", "/").strip()
    matched_entry = find_model_registry_entry(clean_id, entries=entries)
    if matched_entry:
        return matched_entry.runtime_model_id or matched_entry.manifest.id

    p = Path(clean_id)
    if p.parent and p.parent.name and p.parent.name not in (".", "vision", "models"):
        return p.parent.name
    return p.stem or clean_id
