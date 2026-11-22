"""Decision D6 controlled local model import, verification, atomic install & uninstall service."""

import hashlib
import json
import logging
import os
import re
import shutil
import struct
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from app.core.config import settings
from app.schemas.model_registry import (
    ModelDeleteOut,
    ModelImportCandidateOut,
    ModelImportInstallOut,
    ModelImportInstallRequest,
    ModelImportScanOut,
    ModelVariant,
)
from app.services.host_config import clear_model_selection, get_saved_model_selection
from app.services.model_registry import (
    GGUFMetadata,
    assess_hardware_suitability,
    build_model_list,
    find_model_registry_entry,
    read_gguf_metadata,
)

logger = logging.getLogger("app.services.model_import")

MODEL_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{1,63}$")


class ModelImportValidationError(ValueError):
    """Raised when an inbox artifact, model ID, or path fails D6 validation (400)."""


class ModelImportConflictError(RuntimeError):
    """Raised when install or delete conflicts with active runtime or existing entry (409)."""


class ModelImportNotFoundError(LookupError):
    """Raised when the requested inbox artifact or installed model ID does not exist (404)."""


def _contain_relative_path(base_dir: Path, rel_path: str) -> Path:
    """Resolve a user/candidate relative path strictly within base_dir, blocking symlink escapes."""
    if not rel_path or not isinstance(rel_path, str):
        raise ModelImportValidationError("Relative path must be a non-empty string.")
    p = Path(rel_path)
    if p.is_absolute():
        raise ModelImportValidationError("Absolute paths are not permitted; specify a path relative to inbox.")
    base_resolved = base_dir.resolve()
    candidate = base_dir / p
    # Reject symlinks along any component inside base_dir before resolving
    cur = base_dir
    for part in p.parts:
        cur = cur / part
        if cur.is_symlink():
            raise ModelImportValidationError(f"Symlink escapes are not permitted inside inbox: '{rel_path}'.")
    resolved = candidate.resolve()
    if not resolved.is_relative_to(base_resolved) or resolved == base_resolved:
        raise ModelImportValidationError(f"Path traversal outside inbox is not permitted: '{rel_path}'.")
    return resolved


def _sanitize_model_id(raw_id: str) -> str:
    candidate = (raw_id or "").strip().lower()
    if candidate in (".", "..") or ".." in candidate or not MODEL_ID_PATTERN.fullmatch(candidate):
        raise ModelImportValidationError(
            "model_id must be 2-64 lowercase alphanumeric/dot/dash/underscore characters starting with [a-z0-9]."
        )
    return candidate


def _suggest_model_id(stem: str) -> str:
    cleaned = re.sub(r"[^a-z0-9._-]+", "-", stem.lower()).strip("._-")
    if not cleaned:
        cleaned = f"imported-model-{uuid.uuid4().hex[:6]}"
    cleaned = cleaned[:64].rstrip("._-")
    if len(cleaned) < 2 or not cleaned[0].isalnum():
        cleaned = f"m-{cleaned}"[:64]
    return cleaned


def _verify_gguf_header_strict(path: Path) -> Tuple[bool, Optional[str], GGUFMetadata]:
    """Validate minimal GGUF v2/v3 header and inspect metadata safely."""
    if not path.is_file():
        return False, "File not found or not a regular file.", GGUFMetadata()
    size = path.stat().st_size
    if size < 24:
        return False, "File is smaller than minimum 24-byte GGUF v2/v3 header.", GGUFMetadata()
    try:
        with open(path, "rb") as f:
            magic = f.read(4)
            if magic != b"GGUF":
                return False, "Missing 'GGUF' magic header.", GGUFMetadata()
            (version,) = struct.unpack("<I", f.read(4))
            if version not in (2, 3):
                return False, f"Unsupported GGUF version {version} (v2/v3 required).", GGUFMetadata()
    except OSError as exc:
        return False, f"Unable to read GGUF header: {exc}", GGUFMetadata()

    meta = read_gguf_metadata(path)
    if not meta.architecture and not meta.model_name and meta.context_length is None:
        return False, "Corrupt or unreadable GGUF metadata table.", meta
    return True, None, meta


def _is_mmproj_artifact(path: Path, meta: GGUFMetadata) -> bool:
    name_l = path.name.lower()
    return (
        name_l.startswith("mmproj")
        or meta.general_type.lower() == "mmproj"
        or meta.architecture.lower() == "clip"
    )


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()


def _infer_variant(filename: str, meta_name: str) -> str:
    combined = f"{filename} {meta_name}".lower()
    if "think" in combined:
        return ModelVariant.thinking.value
    if "instruct" in combined or "-it" in combined or "_it" in combined:
        return ModelVariant.instruct.value
    if "coder" in combined or "code" in combined:
        return ModelVariant.code.value
    if "base" in combined:
        return ModelVariant.base.value
    return ModelVariant.unknown.value


def scan_import_inbox() -> ModelImportScanOut:
    """Manual Decision D6 inbox scan over IMPORT_INBOX_DIR (never background-watched)."""
    inbox = settings.IMPORT_INBOX_DIR
    inbox.mkdir(parents=True, exist_ok=True)
    inbox_resolved = inbox.resolve()

    warnings: List[str] = []
    valid_files: List[Tuple[Path, Path, bool, Optional[str], GGUFMetadata]] = []

    for root, dirs, files in os.walk(inbox):
        root_path = Path(root)
        # Do not traverse into symlinked subdirectories
        kept_dirs = []
        for d in dirs:
            dp = root_path / d
            if dp.is_symlink():
                warnings.append(f"Skipped symlink directory inside inbox: '{dp.name}'.")
                continue
            kept_dirs.append(d)
        dirs[:] = kept_dirs

        for fname in sorted(files):
            fpath = root_path / fname
            if fpath.is_symlink():
                warnings.append(f"Skipped symlink file inside inbox: '{fname}'.")
                continue
            ext = fpath.suffix.lower()
            if ext != ".gguf":
                if ext in {".pt", ".pth", ".pkl", ".ckpt"}:
                    warnings.append(
                        f"Blocked unsafe Python pickle file '{fname}' for security (Safe Model Format policy). Use a safe .gguf model instead."
                    )
                elif ext == ".safetensors":
                    warnings.append(
                        f"Ignored SafeTensors file '{fname}': llama.cpp requires .gguf format. Download a .gguf quantization to run locally."
                    )
                elif ext == ".onnx":
                    warnings.append(
                        f"Ignored ONNX file '{fname}': ONNX models are used for local voice engines, not llama.cpp chat models. Use .gguf here."
                    )
                elif ext == ".bin":
                    warnings.append(
                        f"Ignored legacy .bin file '{fname}': llama.cpp b10936 requires .gguf format for chat models."
                    )
                continue
            try:
                rel = fpath.resolve().relative_to(inbox_resolved)
            except ValueError:
                warnings.append(f"Skipped out-of-inbox file: '{fname}'.")
                continue
            ok, err, meta = _verify_gguf_header_strict(fpath)
            valid_files.append((fpath, rel, ok, err, meta))

    mmprojs = [(fp, rel, ok, meta) for fp, rel, ok, _, meta in valid_files if _is_mmproj_candidate_entry(fp, ok, meta)]
    primaries = [(fp, rel, ok, err, meta) for fp, rel, ok, err, meta in valid_files if not _is_mmproj_candidate_entry(fp, ok, meta)]

    candidates: List[ModelImportCandidateOut] = []
    for fp, rel, ok, err, meta in primaries:
        size_bytes = fp.stat().st_size

        # Pair companion mmproj residing in same directory (prefer valid match)
        paired_mmproj: Optional[Tuple[Path, Path]] = None
        same_dir_mmprojs = [
            (mfp, mrel) for mfp, mrel, mok, _ in mmprojs if mok and mfp.parent.resolve() == fp.parent.resolve()
        ]
        if len(same_dir_mmprojs) == 1:
            paired_mmproj = same_dir_mmprojs[0]
        elif len(same_dir_mmprojs) > 1:
            stem_l = fp.stem.lower()
            for mfp, mrel in same_dir_mmprojs:
                if stem_l in mfp.stem.lower() or mfp.stem.lower().replace("mmproj-", "") in stem_l:
                    paired_mmproj = (mfp, mrel)
                    break
            if paired_mmproj is None:
                paired_mmproj = same_dir_mmprojs[0]

        companion_bytes = paired_mmproj[0].stat().st_size if paired_mmproj else 0
        size_gb = round(size_bytes / (1024 ** 3), 2)
        preflight = assess_hardware_suitability(
            size_bytes,
            architecture=meta.architecture,
            companion_size_bytes=companion_bytes,
        )

        has_vision = paired_mmproj is not None or meta.has_vision_encoder
        caps = ["chat"] if ok else []
        if ok and has_vision:
            caps.append("vision")
        inferred_variant = _infer_variant(fp.name, meta.model_name)

        candidates.append(
            ModelImportCandidateOut(
                relative_path=rel.as_posix(),
                primary_filename=fp.name,
                suggested_model_id=_suggest_model_id(fp.stem),
                display_name=meta.model_name or fp.stem,
                file_size_bytes=size_bytes,
                size_gb=size_gb,
                artifact_valid=ok,
                validation_error=err,
                architecture=meta.architecture,
                quantization=meta.quantization,
                parameters=meta.size_label,
                variant=inferred_variant,
                family=meta.architecture.capitalize() if meta.architecture else "",
                license=meta.license_name,
                model_max_context=meta.context_length,
                has_chat_template=meta.has_chat_template,
                has_vision_projector=has_vision,
                companion_mmproj_relative_path=paired_mmproj[1].as_posix() if paired_mmproj else None,
                companion_mmproj_filename=paired_mmproj[0].name if paired_mmproj else None,
                detected_capabilities=caps,
                preflight=preflight,
            )
        )

    return ModelImportScanOut(
        inbox_dir=str(inbox_resolved),
        candidates=candidates,
        warnings=warnings,
    )


def _is_mmproj_candidate_entry(path: Path, header_ok: bool, meta: GGUFMetadata) -> bool:
    if path.name.lower().startswith("mmproj"):
        return True
    if header_ok and _is_mmproj_artifact(path, meta):
        return True
    return False


def _read_installed_registry_raw(reg_path: Path) -> Dict[str, Any]:
    if not reg_path.exists():
        return {"_schema_version": "3", "models": []}
    try:
        data = json.loads(reg_path.read_text(encoding="utf-8"))
        if isinstance(data, dict) and isinstance(data.get("models"), list):
            data.setdefault("_schema_version", "3")
            return data
    except Exception:
        pass
    return {"_schema_version": "3", "models": []}


def _write_installed_registry_atomic(reg_path: Path, payload: Dict[str, Any]) -> None:
    reg_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = reg_path.parent / f"{reg_path.name}.tmp.{os.getpid()}"
    try:
        tmp_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        os.replace(tmp_path, reg_path)
    finally:
        if tmp_path.exists():
            try:
                tmp_path.unlink()
            except OSError:
                pass


def install_inbox_candidate(request: ModelImportInstallRequest) -> ModelImportInstallOut:
    """Verify, stage, SHA-256 hash, atomically install, and register a D6 candidate bundle."""
    inbox = settings.IMPORT_INBOX_DIR
    inbox.mkdir(parents=True, exist_ok=True)

    primary_src = _contain_relative_path(inbox, request.relative_path)
    if not primary_src.is_file():
        raise ModelImportNotFoundError(f"Inbox model file not found: '{request.relative_path}'.")

    ok, err, meta = _verify_gguf_header_strict(primary_src)
    if not ok:
        raise ModelImportValidationError(err or "Invalid GGUF model artifact.")
    if _is_mmproj_artifact(primary_src, meta):
        raise ModelImportValidationError("Companion mmproj file cannot be installed as a primary model.")

    companion_src: Optional[Path] = None
    companion_meta: Optional[GGUFMetadata] = None
    if request.companion_relative_path:
        companion_src = _contain_relative_path(inbox, request.companion_relative_path)
        if not companion_src.is_file():
            raise ModelImportNotFoundError(f"Companion mmproj file not found: '{request.companion_relative_path}'.")
        c_ok, c_err, companion_meta = _verify_gguf_header_strict(companion_src)
        if not c_ok:
            raise ModelImportValidationError(f"Invalid companion mmproj GGUF: {c_err}")

    model_id = _sanitize_model_id(request.model_id)

    # Guard duplicate ID against existing factory or installed models
    existing = build_model_list()
    if any(e.manifest.id == model_id for e in existing):
        raise ModelImportConflictError(f"Model ID '{model_id}' already exists in registry.")

    target_dir = (settings.MODEL_LIBRARY_DIR / model_id).resolve()
    if not target_dir.is_relative_to(settings.MODEL_LIBRARY_DIR.resolve()):
        raise ModelImportValidationError("Invalid model target directory.")
    if target_dir.exists():
        raise ModelImportConflictError(f"Target directory already exists for model '{model_id}'.")

    staging_root = settings.IMPORT_STAGING_DIR
    staging_root.mkdir(parents=True, exist_ok=True)
    stage_dir = staging_root / f"{model_id}-{uuid.uuid4().hex[:8]}"
    stage_dir.mkdir(parents=True, exist_ok=False)

    try:
        settings.MODEL_LIBRARY_DIR.mkdir(parents=True, exist_ok=True)

        primary_sha = _sha256_file(primary_src)
        staged_primary = stage_dir / primary_src.name
        shutil.copy2(primary_src, staged_primary)
        if _sha256_file(staged_primary) != primary_sha:
            raise ModelImportValidationError("SHA-256 verification failed after staging primary GGUF.")

        companion_entries: List[Dict[str, Any]] = []
        if companion_src is not None:
            comp_sha = _sha256_file(companion_src)
            staged_comp = stage_dir / companion_src.name
            shutil.copy2(companion_src, staged_comp)
            if _sha256_file(staged_comp) != comp_sha:
                raise ModelImportValidationError("SHA-256 verification failed after staging companion mmproj.")
            companion_entries.append(
                {
                    "role": "mmproj",
                    "path": f"{model_id}/{companion_src.name}",
                    "sha256": comp_sha,
                }
            )

        # Atomic same-volume directory placement (IMPORT_STAGING_DIR -> MODEL_LIBRARY_DIR/<model_id>)
        os.replace(str(stage_dir), str(target_dir))
    except Exception:
        if stage_dir.exists():
            shutil.rmtree(stage_dir, ignore_errors=True)
        raise

    # Consume inbox source files only when transfer_mode == 'move' (default)
    if request.transfer_mode == "move":
        try:
            src_parent = primary_src.parent
            primary_src.unlink(missing_ok=True)
            if companion_src is not None:
                companion_src.unlink(missing_ok=True)
            if src_parent != inbox and src_parent.exists() and not any(src_parent.iterdir()):
                src_parent.rmdir()
        except OSError as exc:
            logger.warning(f"Post-install inbox cleanup warning: {exc}")

    # Compose Schema v3 entry preserving truthful intrinsic header facts
    size_bytes = (target_dir / primary_src.name).stat().st_size
    comp_bytes = (target_dir / companion_src.name).stat().st_size if companion_src is not None else 0
    preflight = assess_hardware_suitability(
        size_bytes,
        architecture=meta.architecture,
        companion_size_bytes=comp_bytes,
    )
    caps = ["chat"]
    modalities = ["text"]
    provenance = [{"capability": "chat", "supported": True, "provenance": "detected"}]
    if companion_entries or meta.has_vision_encoder:
        caps.append("vision")
        modalities.append("image")
        provenance.append({"capability": "vision", "supported": True, "provenance": "detected"})

    variant_val = (
        request.variant.value
        if isinstance(request.variant, ModelVariant)
        else _infer_variant(primary_src.name, meta.model_name)
    )
    display_name = (request.display_name or "").strip() or meta.model_name or model_id
    primary_rel = f"{model_id}/{primary_src.name}"

    raw_entry: Dict[str, Any] = {
        "id": model_id,
        "display_name": display_name,
        "asset_type": "gguf",
        "family": (request.family or "").strip() or (meta.architecture.capitalize() if meta.architecture else ""),
        "architecture": meta.architecture,
        "variant": variant_val,
        "parameters": meta.size_label,
        "quantization": meta.quantization,
        "reasoning_mode": "unknown",
        "capabilities": caps,
        "input_modalities": modalities,
        "capability_provenance": provenance,
        "model_max_context": meta.context_length,
        "runtime_compatibility": ["llama.cpp"],
        "primary_file": primary_rel,
        "companion_files": companion_entries,
        "license": (request.license or "").strip() or meta.license_name,
        "source": "local_d6_import",
        "sha256_primary": primary_sha,
        "runtime_model_id": model_id,
        "recommended_profiles": [preflight.recommended_profile],
        "estimated_vram_gb": preflight.estimated_vram_gb,
        "estimated_ram_gb": round((size_bytes / (1024 ** 3)) * 0.25 + 0.3, 2),
    }

    reg_path = settings.INSTALLED_REGISTRY_PATH
    reg_payload = _read_installed_registry_raw(reg_path)
    reg_payload["models"] = [m for m in reg_payload.get("models", []) if isinstance(m, dict) and m.get("id") != model_id]
    reg_payload["models"].append(raw_entry)
    _write_installed_registry_atomic(reg_path, reg_payload)

    from app.services.llm.manager import llm_manager
    llm_manager.refresh_auto_provider_if_idle()

    return ModelImportInstallOut(
        installed_id=model_id,
        display_name=display_name,
        primary_file=primary_rel,
        validation_status="verified",
        sha256_primary=primary_sha,
    )


async def delete_installed_model(model_id: str) -> ModelDeleteOut:
    """Remove a user-installed D6 model from MODEL_LIBRARY_DIR and Schema v3 models.json."""
    clean_id = _sanitize_model_id(model_id)
    entries = build_model_list()
    target = find_model_registry_entry(clean_id, entries=entries)
    if target is None or target.manifest.id != clean_id:
        raise ModelImportNotFoundError(f"Installed model '{model_id}' not found.")
    if target.registry_source != "installed":
        raise ModelImportValidationError(f"Factory model '{model_id}' cannot be uninstalled.")

    from app.services.llm.manager import llm_manager
    provider = llm_manager._provider
    if provider is not None:
        if getattr(provider, "has_active_generation", False):
            raise ModelImportConflictError("Cannot uninstall a model while generation is active.")
        if provider.is_loaded():
            status_obj = await provider.get_status()
            active_identifiers = {
                target.manifest.id,
                target.runtime_model_id,
                target.manifest.primary_file,
                Path(target.manifest.primary_file).name,
                Path(target.manifest.primary_file).stem,
            }
            if status_obj.active_model in active_identifiers or getattr(provider, "_active_model_name", None) in active_identifiers:
                raise ModelImportConflictError(
                    f"Unload '{target.manifest.display_name}' before uninstalling it."
                )

    lib_base = settings.MODEL_LIBRARY_DIR.resolve()
    primary_rel = Path(target.manifest.primary_file)
    if not primary_rel.is_absolute():
        resolved_primary = (lib_base / primary_rel).resolve()
        if resolved_primary.is_relative_to(lib_base):
            bundle_dir = resolved_primary.parent
            if bundle_dir != lib_base and bundle_dir.is_relative_to(lib_base) and bundle_dir.exists():
                shutil.rmtree(bundle_dir, ignore_errors=False)
            elif resolved_primary.is_file():
                resolved_primary.unlink(missing_ok=True)
                for comp in target.manifest.companion_files:
                    comp_p = (lib_base / comp.path).resolve()
                    if comp_p.is_relative_to(lib_base) and comp_p.is_file():
                        comp_p.unlink(missing_ok=True)

    reg_path = settings.INSTALLED_REGISTRY_PATH
    if reg_path.exists():
        reg_payload = _read_installed_registry_raw(reg_path)
        reg_payload["models"] = [
            m for m in reg_payload.get("models", []) if isinstance(m, dict) and m.get("id") != clean_id
        ]
        _write_installed_registry_atomic(reg_path, reg_payload)

    saved = get_saved_model_selection()
    if saved in {
        target.manifest.id,
        target.runtime_model_id,
        target.manifest.primary_file,
        Path(target.manifest.primary_file).name,
        Path(target.manifest.primary_file).stem,
    }:
        clear_model_selection()

    return ModelDeleteOut(
        deleted_id=clean_id,
        message=f"Uninstalled model '{clean_id}'.",
    )
