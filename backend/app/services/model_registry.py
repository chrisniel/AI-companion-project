"""
Model Registry service — Master Plan §16.2 (Batch 8P.4 Schema v3).
Reads models/registry.json (or template) and scans models/ for GGUF files.
Constructs canonical three-layer ModelRegistryEntry with temporary flat bridge.
Never writes to models/.
"""
import json
import logging
from pathlib import Path
from typing import List, Optional

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


def _load_registry_json() -> list:
    registry_path = settings.MODELS_DIR / "registry.json"
    if not registry_path.exists():
        template_path = settings.MODELS_DIR / "registry.template.json"
        if template_path.exists():
            registry_path = template_path
        else:
            logger.info("models/registry.json and template not found — using scan-only discovery")
            return []
    try:
        with open(registry_path, "r", encoding="utf-8") as f:
            return json.load(f).get("models", [])
    except Exception as exc:
        logger.warning(f"Failed to parse registry file: {exc}")
        return []


def _scan_models_dir() -> List[Path]:
    results: List[Path] = []
    if not settings.MODELS_DIR.exists():
        return results
    for gguf in settings.MODELS_DIR.rglob("*.gguf"):
        if not gguf.is_file():
            continue
        if any(gguf.name.startswith(p) for p in _EXCLUDE_PREFIXES):
            continue
        if gguf.stat().st_size < _MIN_SIZE_BYTES:
            continue
        results.append(gguf)
    return results


def _validate_entry(entry: ModelRegistryEntry) -> ModelRegistryEntry:
    primary = settings.MODELS_DIR / entry.manifest.primary_file
    primary_exists = primary.exists()
    entry.library_state.primary_file_exists = primary_exists
    if not primary_exists:
        entry.library_state.validation_status = ValidationStatus.missing_primary
        entry.library_state.discovery_state = ModelDiscoveryState.registered
        return entry
    entry.library_state.size_gb = round(primary.stat().st_size / (1024 ** 3), 2)

    companion_statuses: List[CompanionArtifactStatus] = []
    all_companions_valid = True
    for companion in entry.manifest.companion_files:
        comp_exists = (settings.MODELS_DIR / companion.path).exists()
        companion_statuses.append(CompanionArtifactStatus(artifact=companion, exists=comp_exists))
        if not comp_exists:
            all_companions_valid = False

    entry.library_state.companion_artifact_statuses = companion_statuses
    if not all_companions_valid:
        entry.library_state.validation_status = ValidationStatus.missing_companion
        entry.library_state.discovery_state = ModelDiscoveryState.registered
        return entry

    entry.library_state.validation_status = ValidationStatus.verified
    entry.library_state.discovery_state = ModelDiscoveryState.verified
    return entry


def build_model_list() -> List[ModelRegistryEntry]:
    """
    1. Parse registry.json (or registry.template.json) and validate each entry against disk.
    2. Scan models/ for any .gguf not in registry.
    3. Return: registered (instruct < thinking < base < code < unknown) then unregistered.
    """
    raw_entries = _load_registry_json()
    registered_primary_files: set = set()
    registered: List[ModelRegistryEntry] = []
    variant_order = {"instruct": 0, "thinking": 1, "base": 2, "code": 3, "unknown": 99}

    for raw in raw_entries:
        try:
            companion_files = [
                CompanionFile(
                    role=c["role"],
                    path=c["path"],
                    sha256=c.get("sha256"),
                )
                for c in raw.get("companion_files", [])
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
            if not input_modalities:
                input_modalities = [InputModality.text, InputModality.image] if ModelCapability.vision in capabilities else [InputModality.text]

            variant_val = raw.get("variant", "instruct")
            try:
                variant = ModelVariant(variant_val)
            except ValueError:
                variant = ModelVariant.unknown

            reasoning_mode_val = raw.get("reasoning_mode")
            if reasoning_mode_val:
                try:
                    reasoning_mode = ReasoningMode(reasoning_mode_val)
                except ValueError:
                    reasoning_mode = ReasoningMode.unknown
            else:
                reasoning_mode = ReasoningMode.always_on if variant == ModelVariant.thinking else ReasoningMode.unsupported

            raw_asset_type = raw.get("asset_type", "gguf")
            try:
                asset_type = ModelAssetType(raw_asset_type)
            except ValueError:
                asset_type = ModelAssetType.gguf

            model_max_context = raw.get("model_max_context", raw.get("context_limit", 32768))

            manifest = ModelManifest(
                id=raw["id"],
                display_name=raw.get("display_name", raw["id"]),
                asset_type=asset_type,
                family=raw.get("family", ""),
                architecture=raw.get("architecture", "qwen3vl" if "qwen" in raw["id"].lower() else ""),
                variant=variant,
                parameters=raw.get("parameters", ""),
                quantization=raw.get("quantization", ""),
                reasoning_mode=reasoning_mode,
                capabilities=capabilities,
                input_modalities=input_modalities,
                model_max_context=model_max_context,
                runtime_compatibility=raw.get("runtime_compatibility", ["llama.cpp"]),
                primary_file=raw["primary_file"],
                companion_files=companion_files,
                chat_template=raw.get("chat_template"),
                license=raw.get("license", ""),
                source=raw.get("source", ""),
                sha256_primary=raw.get("sha256_primary"),
            )

            library_state = ModelLibraryState(
                discovery_state=ModelDiscoveryState.registered,
                validation_status=ValidationStatus.unregistered,
                primary_file_exists=False,
                size_gb=None,
                companion_artifact_statuses=[],
                available_capabilities=list(capabilities),
                capability_provenance=[
                    CapabilityEntry(capability=c, supported=True, provenance=CapabilityProvenance.declared)
                    for c in capabilities
                ],
            )

            gen_defaults = None
            if raw.get("generation_defaults"):
                gen_defaults = GenerationDefaults(**raw["generation_defaults"])

            hints = ModelRuntimeHints(
                recommended_profiles=raw.get("recommended_profiles", ["balanced"]),
                estimated_vram_gb=float(raw.get("estimated_vram_gb", 0.0)),
                estimated_ram_gb=float(raw.get("estimated_ram_gb", 0.0)),
                generation_defaults=gen_defaults,
            )

            entry = ModelRegistryEntry(
                manifest=manifest,
                library_state=library_state,
                hints=hints,
                runtime_model_id=raw.get("runtime_model_id") or raw["id"],
                registry_source="factory",
            )
            entry = _validate_entry(entry)
            registered_primary_files.add(entry.manifest.primary_file)
            registered.append(entry)
        except Exception as exc:
            logger.warning(f"Skipping malformed registry entry: {exc}")

    registered.sort(key=lambda e: variant_order.get(e.manifest.variant.value if isinstance(e.manifest.variant, ModelVariant) else str(e.manifest.variant), 99))

    unregistered: List[ModelRegistryEntry] = []
    for path in _scan_models_dir():
        relative = path.relative_to(settings.MODELS_DIR).as_posix()
        if relative in registered_primary_files:
            continue
        size_gb = round(path.stat().st_size / (1024 ** 3), 2)
        folder_name = path.parent.name if path.parent not in (settings.MODELS_DIR, settings.LLAMA_MODELS_DIR) else path.stem
        manifest = ModelManifest(
            id=path.stem.lower().replace("_", "-").replace(".", "-"),
            display_name=path.stem,
            asset_type=ModelAssetType.gguf,
            family="",
            variant=ModelVariant.instruct,
            primary_file=relative,
            capabilities=[ModelCapability.chat],
            model_max_context=4096,
        )
        library_state = ModelLibraryState(
            discovery_state=ModelDiscoveryState.discovered,
            validation_status=ValidationStatus.unregistered,
            primary_file_exists=True,
            size_gb=size_gb,
            available_capabilities=[ModelCapability.chat],
            capability_provenance=[
                CapabilityEntry(capability=ModelCapability.chat, supported=True, provenance=CapabilityProvenance.declared)
            ],
        )
        hints = ModelRuntimeHints(
            recommended_profiles=["balanced"],
            estimated_vram_gb=0.0,
            estimated_ram_gb=0.0,
        )
        unregistered.append(ModelRegistryEntry(
            manifest=manifest,
            library_state=library_state,
            hints=hints,
            runtime_model_id=folder_name,
            registry_source="factory",
        ))

    result = registered + unregistered
    logger.info(f"Model registry: {len(registered)} registered, {len(unregistered)} unregistered")
    return result


def resolve_runtime_model_id(identifier: Optional[str]) -> str:
    """Resolve an incoming identifier (id, primary_file, or filename) to the router runtime_model_id."""
    if not identifier:
        return ""
    clean_id = identifier.replace("\\", "/").strip()
    entries = build_model_list()
    for entry in entries:
        candidate_matches = {
            entry.manifest.id,
            entry.runtime_model_id,
            entry.manifest.primary_file,
            Path(entry.manifest.primary_file).name,
            Path(entry.manifest.primary_file).stem,
        }
        if clean_id in candidate_matches:
            return entry.runtime_model_id or entry.manifest.id

    p = Path(clean_id)
    if p.parent and p.parent.name and p.parent.name not in (".", "vision", "models"):
        return p.parent.name
    return p.stem or clean_id
