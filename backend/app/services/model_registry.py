"""
Model Registry service — Master Plan §16.2.
Reads models/registry.json and scans models/ for GGUF files.
Never writes to models/.
"""
import json
import logging
from pathlib import Path
from typing import List

from app.core.config import settings
from app.schemas.model_registry import (
    CompanionFile, ModelCapability, ModelRegistryEntry, ValidationStatus,
)

logger = logging.getLogger("app.services.model_registry")
_EXCLUDE_PREFIXES = ("mmproj-", "lfs-test")
_MIN_SIZE_BYTES = 100 * 1024 * 1024


def _load_registry_json() -> list:
    registry_path = settings.MODELS_DIR / "registry.json"
    if not registry_path.exists():
        logger.info("models/registry.json not found — using scan-only discovery")
        return []
    try:
        with open(registry_path, "r", encoding="utf-8") as f:
            return json.load(f).get("models", [])
    except Exception as exc:
        logger.warning(f"Failed to parse models/registry.json: {exc}")
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
    primary = settings.MODELS_DIR / entry.primary_file
    entry.primary_file_exists = primary.exists()
    if not entry.primary_file_exists:
        entry.validation_status = ValidationStatus.missing_primary
        return entry
    entry.size_gb = round(primary.stat().st_size / (1024 ** 3), 2)
    for companion in entry.companion_files:
        if not (settings.MODELS_DIR / companion.path).exists():
            entry.companion_files_valid = False
            entry.validation_status = ValidationStatus.missing_companion
            return entry
    entry.validation_status = ValidationStatus.verified
    return entry


def build_model_list() -> List[ModelRegistryEntry]:
    """
    1. Parse registry.json and validate each entry against disk.
    2. Scan models/ for any .gguf not in registry.
    3. Return: registered (instruct < thinking < base) then unregistered.
    """
    raw_entries = _load_registry_json()
    registered_primary_files: set = set()
    registered: List[ModelRegistryEntry] = []
    variant_order = {"instruct": 0, "thinking": 1, "base": 2}

    for raw in raw_entries:
        try:
            companion_files = [
                CompanionFile(role=c["role"], path=c["path"])
                for c in raw.get("companion_files", [])
            ]
            capabilities = []
            for cap_str in raw.get("capabilities", []):
                try:
                    capabilities.append(ModelCapability(cap_str))
                except ValueError:
                    pass
            entry = ModelRegistryEntry(
                id=raw["id"],
                display_name=raw.get("display_name", raw["id"]),
                family=raw.get("family", ""),
                variant=raw.get("variant", "instruct"),
                primary_file=raw["primary_file"],
                companion_files=companion_files,
                quantization=raw.get("quantization", ""),
                parameters=raw.get("parameters", ""),
                context_limit=raw.get("context_limit", 4096),
                capabilities=capabilities,
                recommended_profiles=raw.get("recommended_profiles", ["balanced"]),
                estimated_vram_gb=raw.get("estimated_vram_gb", 0.0),
                estimated_ram_gb=raw.get("estimated_ram_gb", 0.0),
                license=raw.get("license", ""),
                source=raw.get("source", ""),
            )
            entry = _validate_entry(entry)
            registered_primary_files.add(entry.primary_file)
            registered.append(entry)
        except Exception as exc:
            logger.warning(f"Skipping malformed registry entry: {exc}")

    registered.sort(key=lambda e: variant_order.get(e.variant, 99))

    unregistered: List[ModelRegistryEntry] = []
    for path in _scan_models_dir():
        relative = path.relative_to(settings.MODELS_DIR).as_posix()
        if relative in registered_primary_files:
            continue
        size_gb = round(path.stat().st_size / (1024 ** 3), 2)
        unregistered.append(ModelRegistryEntry(
            id=path.stem.lower().replace("_", "-").replace(".", "-"),
            display_name=path.stem,
            family="",
            variant="instruct",
            primary_file=relative,
            capabilities=[ModelCapability.chat],
            validation_status=ValidationStatus.unregistered,
            primary_file_exists=True,
            size_gb=size_gb,
        ))

    result = registered + unregistered
    logger.info(f"Model registry: {len(registered)} registered, {len(unregistered)} unregistered")
    return result
