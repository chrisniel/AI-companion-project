"""Attachment REST endpoints adhering to Phase 8B.3 specifications and security boundaries."""

import asyncio
from contextlib import suppress
import os
from pathlib import Path
from typing import Optional
from urllib.parse import quote

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db
from app.core.profile_sessions import validate_profile_session
from app.models.profile_session import ProfileSession
from app.core.config import settings
from app.models.attachment import Attachment
from app.models.base import generate_uuid, utc_now
from app.models.conversation import Conversation
from app.models.message import Message
from app.schemas.attachment import AttachmentOut, MAX_SIZE_BYTES
from app.services.attachment_validator import (
    AttachmentValidationError,
    ImageTooLargeError,
    validate_image_bytes,
)

router = APIRouter()


class SecurityException(Exception):
    """Raised when an internal path traversal or storage escape is detected."""
    pass


def sanitize_display_filename(raw_filename: Optional[str]) -> str:
    """Normalize user-supplied filename into a safe display-only metadata string.

    - Normalizes both '/' and '\\' path separators regardless of host OS.
    - Extracts only the final basename component (no directory traversal prefix).
    - Strips NUL bytes and ASCII control characters (ord < 32).
    - Enforces 255-character maximum length matching ORM String(255).
    - Falls back to 'attachment' if raw input is absent, empty, or whitespace-only.
    """
    if not raw_filename:
        return "attachment"

    normalized = raw_filename.replace("\\", "/")
    basename = normalized.rstrip("/").split("/")[-1]
    cleaned = "".join(ch for ch in basename if ord(ch) >= 32 and ch != "\x7f").strip()
    cleaned = cleaned[:255].strip()
    return cleaned if cleaned else "attachment"


def resolve_and_verify_attachment_path(storage_path: str) -> Path:
    """Verify that a storage_path string resolves strictly within ATTACHMENT_DIR."""
    p = Path(storage_path)
    if p.is_absolute():
        raise SecurityException("Absolute storage path is forbidden")

    candidate = (settings.COMPANION_DATA_ROOT / p).resolve()
    attachment_root = settings.ATTACHMENT_DIR.resolve()

    if not candidate.is_relative_to(attachment_root) or candidate == attachment_root:
        raise SecurityException("Attachment path escapes attachment storage root")

    return candidate


def save_attachment_file_no_clobber(
    target_dir: Path,
    data: bytes,
    canonical_ext: str,
    preferred_filename: Optional[str] = None,
    max_retries: int = 3,
) -> tuple[str, Path]:
    """Write validated bytes to target_dir guaranteeing existing files are NEVER overwritten.

    Returns (storage_filename, target_path).
    Raises RuntimeError if collision cannot be resolved after max_retries.
    """
    target_dir.mkdir(parents=True, exist_ok=True)

    candidate_name = preferred_filename
    for attempt in range(max_retries):
        if not candidate_name or attempt > 0:
            candidate_id = generate_uuid()
            candidate_name = f"{candidate_id}{canonical_ext}"

        target_path = target_dir / candidate_name
        temp_path = target_dir / f".tmp_{candidate_name}"

        if target_path.exists() or temp_path.exists():
            continue  # Collision detected, regenerate fresh UUID

        temp_created = False
        try:
            # Write to temp file exclusively (mode="xb" fails if temp_path already exists)
            with temp_path.open("xb") as handle:
                temp_created = True
                handle.write(data)

            # Pre-promotion check: ensure destination did not appear concurrently
            if target_path.exists():
                temp_path.unlink(missing_ok=True)
                temp_created = False
                continue

            # On Windows, os.rename raises FileExistsError if target exists.
            os.rename(temp_path, target_path)
            return candidate_name, target_path
        except FileExistsError:
            # If target or temp already existed, only clean up temp if THIS attempt created it
            if temp_created:
                temp_path.unlink(missing_ok=True)
            continue
        except Exception:
            if temp_created:
                temp_path.unlink(missing_ok=True)
            raise

    raise RuntimeError("Failed to generate a non-colliding attachment filename after maximum retries")


# ===========================================================================
# Endpoints
# ===========================================================================

@router.post(
    "/{conversation_id}/attachments",
    response_model=AttachmentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Upload Attachment",
)
async def upload_attachment(
    conversation_id: str,
    file: UploadFile = File(...),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> AttachmentOut:
    """Upload a new staged image attachment associated with an active conversation."""
    # 1. Verify parent conversation exists, is owned by current user, and is not soft-deleted
    conv_stmt = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.profile_id == session.profile_id,
        Conversation.deleted_at.is_(None),
    )
    conv = (await db.execute(conv_stmt)).scalar_one_or_none()
    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    # 2. Normalize display filename safely
    safe_display_name = sanitize_display_filename(file.filename)

    # 3. Bounded streaming read (max 10 MiB)
    chunk_size = 64 * 1024  # 64 KiB
    chunks = []
    total_bytes = 0
    try:
        while True:
            chunk = await file.read(chunk_size)
            if not chunk:
                break
            total_bytes += len(chunk)
            if total_bytes > MAX_SIZE_BYTES:
                raise HTTPException(
                    status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                    detail=f"Image file exceeds maximum allowed size of {MAX_SIZE_BYTES} bytes",
                )
            chunks.append(chunk)
        data = b"".join(chunks)
    finally:
        await file.close()
    await validate_profile_session(db, session)

    # 4. In-memory validation
    try:
        validated_meta = validate_image_bytes(data, filename=safe_display_name)
    except ImageTooLargeError as exc:
        raise HTTPException(status_code=status.HTTP_413_CONTENT_TOO_LARGE, detail=exc.message)
    except AttachmentValidationError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=exc.message)

    # 5. Storage paths preflight
    canonical_ext = ".png" if validated_meta.mime_type == "image/png" else ".jpg"
    target_dir = settings.ATTACHMENT_DIR / session.profile_id / conversation_id

    attachment_root = settings.ATTACHMENT_DIR.resolve()
    if not target_dir.resolve().is_relative_to(attachment_root):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Storage directory configuration error",
        )

    target_dir.mkdir(parents=True, exist_ok=True)

    # Determine collision-free initial candidate before ORM flush
    attachment_id = generate_uuid()
    initial_storage_filename = f"{attachment_id}{canonical_ext}"
    for _ in range(3):
        cand_target = target_dir / initial_storage_filename
        cand_tmp = target_dir / f".tmp_{initial_storage_filename}"
        if not cand_target.exists() and not cand_tmp.exists():
            break
        attachment_id = generate_uuid()
        initial_storage_filename = f"{attachment_id}{canonical_ext}"

    initial_storage_path = f"attachments/{session.profile_id}/{conversation_id}/{initial_storage_filename}"

    # 6. Construct ORM instance
    attachment = Attachment(
        id=attachment_id,
        profile_id=session.profile_id,
        conversation_id=conversation_id,
        message_id=None,  # Staged
        filename_display=safe_display_name,
        storage_filename=initial_storage_filename,
        storage_path=initial_storage_path,
        mime_type=validated_meta.mime_type,
        size_bytes=validated_meta.size_bytes,
        image_width=validated_meta.image_width,
        image_height=validated_meta.image_height,
    )
    db.add(attachment)

    # 7. DB Flush (Validates database constraints BEFORE any disk write)
    try:
        await db.flush()
    except Exception:
        await db.rollback()
        raise

    # 8. Exclusive Disk Write & Promotion followed by Commit
    final_target_path: Optional[Path] = None
    try:
        await validate_profile_session(db, session)
        final_filename, final_target_path = await asyncio.to_thread(
            save_attachment_file_no_clobber,
            target_dir,
            data,
            canonical_ext,
            initial_storage_filename,
        )
        if final_filename != initial_storage_filename:
            attachment.storage_filename = final_filename
            attachment.storage_path = f"attachments/{session.profile_id}/{conversation_id}/{final_filename}"
            await db.flush()

        await validate_profile_session(db, session)

        await db.commit()
    except Exception:
        await db.rollback()
        if final_target_path is not None:
            await asyncio.to_thread(final_target_path.unlink, missing_ok=True)
        raise

    # 9. Return response (Committed DB state and file are preserved)
    return AttachmentOut(
        id=attachment.id,
        conversation_id=attachment.conversation_id,
        message_id=attachment.message_id,
        filename_display=attachment.filename_display,
        mime_type=attachment.mime_type,
        size_bytes=attachment.size_bytes,
        image_width=attachment.image_width,
        image_height=attachment.image_height,
        created_at=attachment.created_at,
    )


@router.get(
    "/{conversation_id}/attachments/{attachment_id}/preview",
    summary="Preview Attachment",
)
async def preview_attachment(
    conversation_id: str,
    attachment_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """Stream attachment image content if parent conversation and attachment are active and owned."""
    # 1. Verify parent conversation
    conv_stmt = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.profile_id == session.profile_id,
        Conversation.deleted_at.is_(None),
    )
    conv = (await db.execute(conv_stmt)).scalar_one_or_none()
    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    # 2. Verify attachment
    att_stmt = select(Attachment).where(
        Attachment.id == attachment_id,
        Attachment.profile_id == session.profile_id,
        Attachment.conversation_id == conversation_id,
        Attachment.is_deleted.is_(False),
    )
    att = (await db.execute(att_stmt)).scalar_one_or_none()
    if not att or att.conversation_id != conversation_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attachment not found",
        )

    if att.profile_id != session.profile_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this attachment",
        )

    await _require_attachment_message(db, session, att)

    # 3. Verify path containment and physical file existence
    try:
        file_path = resolve_and_verify_attachment_path(att.storage_path)
    except SecurityException:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attachment not found",
        )

    if not file_path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attachment file not found",
        )

    encoded_filename = quote(att.filename_display)
    disposition = (
        f"attachment; filename*=utf-8''{encoded_filename}"
        if encoded_filename != att.filename_display
        else f'attachment; filename="{att.filename_display}"'
    )
    return _AttachmentPreviewResponse(
        _stream_attachment_file(db, session, conversation_id, attachment_id, file_path),
        media_type=att.mime_type,
        headers={
            "Content-Disposition": disposition,
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
        },
    )


class _AttachmentPreviewResponse(StreamingResponse):
    """Close the download iterator even when cancellation happens during send."""

    async def __call__(self, scope, receive, send):
        try:
            await super().__call__(scope, receive, send)
        finally:
            await asyncio.shield(self.body_iterator.aclose())


async def _require_download_authority(db, session, conversation_id, attachment_id):
    # Complete a DB check before consumer cancellation can invalidate SQLite's
    # connection, matching the chat stream's cancellation protection.
    check = asyncio.create_task(_validate_download_authority(db, session, conversation_id, attachment_id))
    try:
        await asyncio.shield(check)
    except asyncio.CancelledError:
        with suppress(Exception):
            await asyncio.shield(check)
        raise


async def _validate_download_authority(db, session, conversation_id, attachment_id):
    await validate_profile_session(db, session)
    att = await db.scalar(select(Attachment).join(
        Conversation, Conversation.id == Attachment.conversation_id,
    ).where(
        Attachment.id == attachment_id,
        Attachment.profile_id == session.profile_id,
        Attachment.conversation_id == conversation_id,
        Attachment.is_deleted.is_(False), Attachment.deleted_at.is_(None),
        Conversation.profile_id == session.profile_id,
        Conversation.is_deleted.is_(False), Conversation.deleted_at.is_(None),
    ).execution_options(populate_existing=True))
    if att is None:
        raise HTTPException(status_code=404, detail="Attachment not found")
    await _require_attachment_message(db, session, att)


async def _stream_attachment_file(db, session, conversation_id, attachment_id, file_path):
    """Own the file and revalidate before every chunk and while a read is idle."""
    pending = None
    try:
        await _require_download_authority(db, session, conversation_id, attachment_id)
        with file_path.open("rb") as handle:
            try:
                while True:
                    await _require_download_authority(db, session, conversation_id, attachment_id)
                    pending = asyncio.create_task(asyncio.to_thread(handle.read, 65536))
                    while True:
                        done, _ = await asyncio.wait({pending}, timeout=0.25)
                        await _require_download_authority(db, session, conversation_id, attachment_id)
                        if done:
                            break
                    chunk = pending.result()
                    pending = None
                    if not chunk:
                        return
                    yield chunk
            finally:
                if pending is not None:
                    # A thread performing a file read cannot be forcibly stopped.
                    # Finish it without emitting bytes before closing its handle.
                    with suppress(Exception):
                        await asyncio.shield(pending)
    except HTTPException as exc:
        if exc.status_code in (401, 403, 404):
            return
        raise


@router.delete(
    "/{conversation_id}/attachments/{attachment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete Attachment",
)
async def delete_attachment(
    conversation_id: str,
    attachment_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Soft-delete an attachment. Retains physical file on disk for retention lifecycle."""
    # 1. Verify parent conversation
    conv_stmt = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.profile_id == session.profile_id,
        Conversation.deleted_at.is_(None),
    )
    conv = (await db.execute(conv_stmt)).scalar_one_or_none()
    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )

    # 2. Verify attachment
    att_stmt = select(Attachment).where(
        Attachment.id == attachment_id,
        Attachment.profile_id == session.profile_id,
        Attachment.conversation_id == conversation_id,
        Attachment.is_deleted.is_(False),
    )
    att = (await db.execute(att_stmt)).scalar_one_or_none()
    if not att or att.conversation_id != conversation_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attachment not found",
        )

    if att.profile_id != session.profile_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to access this attachment",
        )

    await _require_attachment_message(db, session, att)

    # 3. Soft-delete
    att.is_deleted = True
    att.deleted_at = utc_now()
    await validate_profile_session(db, session)
    await db.commit()


async def _require_attachment_message(db: AsyncSession, session: ProfileSession, att: Attachment) -> None:
    """A bound attachment also requires the same active, owned message parent."""
    if att.message_id is None:
        return
    message = await db.scalar(select(Message.id).where(
        Message.id == att.message_id, Message.profile_id == session.profile_id,
        Message.conversation_id == att.conversation_id, Message.deleted_at.is_(None),
        Message.is_deleted.is_(False),
    ))
    if message is None:
        raise HTTPException(status_code=404, detail="Attachment not found")
