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
    CapabilityProvenance,
    InboxMmprojOut,
    ModelDeleteOut,
    ModelImportCandidateOut,
    ModelImportInstallOut,
    ModelImportInstallRequest,
    ModelImportScanOut,
    ModelVariant,
    ReasoningMode,
)
from app.services.host_config import clear_model_selection, get_saved_model_selection
from app.services.model_registry import (
    GGUFMetadata,
    assess_context_options,
    assess_hardware_suitability,
    build_model_list,
    compute_recommended_profiles_for_model,
    find_model_registry_entry,
    is_vision_capable_primary,
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


def _normalize_family_token(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (text or "").lower())


def _projector_matches_arch(projector_type: str, architecture: str) -> bool:
    p = _normalize_family_token(projector_type)
    a = _normalize_family_token(architecture)
    if not p or not a:
        return True
    if a in p or p in a:
        return True
    if p.startswith("qwen") and a.startswith("qwen"):
        return p[:6] == a[:6]
    if p.startswith("gemma") and a.startswith("gemma"):
        return p[:6] == a[:6]
    if p in ("mlp", "ldp", "resampler", "adapter", "projector"):
        return True
    return False


def _extract_family_signature(text: str) -> Optional[str]:
    low = (text or "").lower()
    m = re.search(
        r"\b(gemma[-_ ]?[0-9]+|qwen[-_ ]?[0-9]+(?:vl)?|llama[-_ ]?[0-9]+|mistral|pixtral|internvl|minicpm)\b",
        low,
    )
    if m:
        return re.sub(r"[-_ ]+", "", m.group(1))
    for fam in ("gemma", "qwen", "llama", "mistral", "pixtral", "internvl", "minicpm", "llava"):
        if fam in low:
            return fam
    return None


def score_mmproj_compatibility(
    primary_path: Path,
    primary_meta: GGUFMetadata,
    mmproj_path: Path,
    mmproj_meta: GGUFMetadata,
) -> Optional[int]:
    """Return ranked compatibility score for (primary, mmproj), or None if incompatible."""
    if (
        primary_meta.embedding_length is not None
        and mmproj_meta.vision_projection_dim is not None
        and primary_meta.embedding_length != mmproj_meta.vision_projection_dim
    ):
        return None

    if mmproj_meta.projector_type and primary_meta.architecture:
        if not _projector_matches_arch(mmproj_meta.projector_type, primary_meta.architecture):
            return None

    p_sig = _extract_family_signature(
        f"{primary_meta.architecture} {primary_meta.model_name} {primary_meta.basename} {primary_path.stem}"
    )
    m_sig = _extract_family_signature(
        f"{mmproj_meta.projector_type} {mmproj_meta.model_name} {mmproj_meta.basename} {mmproj_path.stem}"
    )
    if p_sig and m_sig and p_sig != m_sig and not (p_sig.startswith(m_sig) or m_sig.startswith(p_sig)):
        return None

    score = 1
    if mmproj_path.parent.resolve() == primary_path.parent.resolve():
        score += 50

    p_name_n = _normalize_family_token(primary_meta.model_name)
    m_name_n = _normalize_family_token(mmproj_meta.model_name)
    if p_name_n and m_name_n:
        if p_name_n == m_name_n:
            score += 100
        elif p_name_n in m_name_n or m_name_n in p_name_n:
            score += 60

    p_base_n = _normalize_family_token(primary_meta.basename)
    m_base_n = _normalize_family_token(mmproj_meta.basename)
    if p_base_n and m_base_n and (p_base_n == m_base_n or p_base_n in m_base_n or m_base_n in p_base_n):
        score += 30

    p_variant_txt = f"{primary_meta.model_name} {primary_path.stem}".lower()
    m_variant_txt = f"{mmproj_meta.model_name} {mmproj_path.stem}".lower()
    p_think = "think" in p_variant_txt
    m_think = "think" in m_variant_txt
    p_inst = "instruct" in p_variant_txt
    m_inst = "instruct" in m_variant_txt
    if (p_think and m_think) or (p_inst and m_inst):
        score += 40
    elif (p_think and m_inst) or (p_inst and m_think):
        score -= 25

    p_tokens = {t for t in re.split(r"[^a-z0-9]+", primary_path.stem.lower()) if len(t) >= 2}
    m_tokens = {
        t
        for t in re.split(r"[^a-z0-9]+", mmproj_path.stem.lower())
        if len(t) >= 2 and t not in ("mmproj", "model", "f16", "f32", "bf16", "q8")
    }
    score += min(30, len(p_tokens & m_tokens) * 10)

    if (
        primary_meta.embedding_length is not None
        and mmproj_meta.vision_projection_dim is not None
        and primary_meta.embedding_length == mmproj_meta.vision_projection_dim
    ):
        score += 20

    return score if score > 0 else 1


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

    available_mmprojs: List[InboxMmprojOut] = []
    valid_mmprojs: List[Tuple[Path, Path, GGUFMetadata]] = []
    for mfp, mrel, mok, mmeta in mmprojs:
        if mok:
            valid_mmprojs.append((mfp, mrel, mmeta))
            available_mmprojs.append(
                InboxMmprojOut(
                    relative_path=mrel.as_posix(),
                    filename=mfp.name,
                    size_gb=round(mfp.stat().st_size / (1024 ** 3), 2),
                    model_name=mmeta.model_name,
                    projector_type=mmeta.projector_type,
                    vision_projection_dim=mmeta.vision_projection_dim,
                )
            )
        else:
            warnings.append(f"Skipped invalid/corrupt mmproj file '{mfp.name}'.")

    candidates: List[ModelImportCandidateOut] = []
    for fp, rel, ok, err, meta in primaries:
        size_bytes = fp.stat().st_size

        # Header-verified ranked matching across all valid mmproj files in inbox (no blind [0] fallback)
        scored_matches: List[Tuple[int, Path, Path]] = []
        if ok:
            for mfp, mrel, mmeta in valid_mmprojs:
                score = score_mmproj_compatibility(fp, meta, mfp, mmeta)
                if score is not None:
                    scored_matches.append((score, mfp, mrel))
        scored_matches.sort(key=lambda item: (-item[0], item[2].as_posix()))

        paired_mmproj: Optional[Tuple[Path, Path]] = (
            (scored_matches[0][1], scored_matches[0][2]) if scored_matches else None
        )
        compatible_mmproj_paths = [mrel.as_posix() for _, _, mrel in scored_matches]

        companion_bytes = paired_mmproj[0].stat().st_size if paired_mmproj else 0
        size_gb = round(size_bytes / (1024 ** 3), 2)
        preflight = assess_hardware_suitability(
            size_bytes,
            architecture=meta.architecture,
            companion_size_bytes=companion_bytes,
        )
        context_options = assess_context_options(
            size_bytes,
            companion_size_bytes=companion_bytes,
            profile=preflight.recommended_profile,
            model_max_context=meta.context_length,
        )

        has_vision = paired_mmproj is not None or meta.has_vision_encoder
        expects_vision = ok and (has_vision or is_vision_capable_primary(meta))
        reasoning_mode = meta.reasoning_mode if ok else "unknown"
        caps = ["chat"] if ok else []
        if ok and has_vision:
            caps.append("vision")
        if ok and reasoning_mode in (ReasoningMode.always_on.value, ReasoningMode.toggleable.value):
            caps.append("reasoning")
        inferred_variant = _infer_variant(fp.name, meta.model_name)

        if expects_vision and not has_vision:
            if valid_mmprojs:
                warnings.append(
                    f"'{fp.name}' is a vision-capable model, but none of the mmproj files in inbox matched its header dimensions/architecture."
                )
            else:
                warnings.append(
                    f"'{fp.name}' is a vision-capable model, but no matching mmproj-*.gguf file was found in inbox (vision will be disabled unless attached)."
                )

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
                expects_vision_projector=expects_vision,
                reasoning_mode=reasoning_mode,
                companion_mmproj_relative_path=paired_mmproj[1].as_posix() if paired_mmproj else None,
                companion_mmproj_filename=paired_mmproj[0].name if paired_mmproj else None,
                compatible_mmproj_paths=compatible_mmproj_paths,
                detected_capabilities=caps,
                context_options=context_options,
                preflight=preflight,
            )
        )

    return ModelImportScanOut(
        inbox_dir=str(inbox_resolved),
        candidates=candidates,
        available_mmprojs=available_mmprojs,
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
        assert companion_meta is not None
        if not _is_mmproj_artifact(companion_src, companion_meta):
            raise ModelImportValidationError(
                f"Companion file '{companion_src.name}' is not a valid mmproj vision projector GGUF."
            )
        if score_mmproj_compatibility(primary_src, meta, companion_src, companion_meta) is None:
            raise ModelImportValidationError(
                f"Companion mmproj '{companion_src.name}' is incompatible with '{primary_src.name}' (header architecture or projection dimension mismatch)."
            )

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
    rec_profiles, _ = compute_recommended_profiles_for_model(
        file_size_bytes=size_bytes,
        companion_size_bytes=comp_bytes,
    )
    caps = ["chat"]
    modalities = ["text"]
    provenance = [{"capability": "chat", "supported": True, "provenance": CapabilityProvenance.detected.value}]
    if companion_entries or meta.has_vision_encoder:
        caps.append("vision")
        modalities.append("image")
        provenance.append({"capability": "vision", "supported": True, "provenance": CapabilityProvenance.detected.value})

    detected_reasoning = (
        meta.reasoning_mode
        if meta.reasoning_mode
        in (
            ReasoningMode.always_on.value,
            ReasoningMode.toggleable.value,
            ReasoningMode.unsupported.value,
        )
        else ReasoningMode.unknown.value
    )
    if detected_reasoning in (ReasoningMode.always_on.value, ReasoningMode.toggleable.value):
        caps.append("reasoning")
        provenance.append({"capability": "reasoning", "supported": True, "provenance": CapabilityProvenance.detected.value})

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
        "reasoning_mode": detected_reasoning,
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
        "recommended_profiles": rec_profiles or [preflight.recommended_profile],
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
