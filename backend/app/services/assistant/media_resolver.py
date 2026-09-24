"""Media resolution service for Phase 8B.5 Vision Provider Integration.

Resolves committed Attachment records to validated, in-memory ResolvedImageContent blocks.
Enforces owner, conversation, message binding, MIME, canonical storage containment,
file-size integrity, and signature validation before feeding image bytes to the provider layer.
"""

import asyncio
import logging
from pathlib import Path
from typing import Optional, Union

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.attachment import Attachment
from app.schemas.multimodal import ImageAttachmentRef, ResolvedImageContent
from app.services.attachment_validator import detect_image_mime

logger = logging.getLogger("app.services.assistant.media_resolver")

MAX_ATTACHMENT_SIZE_BYTES: int = 10 * 1024 * 1024  # 10 MiB
SUPPORTED_IMAGE_MIMES = ("image/png", "image/jpeg")


# ===========================================================================
# Domain Exception Hierarchy
# ===========================================================================

class MediaResolverError(Exception):
    """Base exception for media resolution failures."""


class MediaAttachmentNotFoundError(MediaResolverError):
    """Attachment does not exist or does not belong to the conversation."""


class MediaAttachmentForbiddenError(MediaResolverError):
    """Attachment belongs to a different owner."""


class MediaAttachmentNotBoundError(MediaResolverError):
    """Attachment is staged (message_id is None)."""


class MediaAttachmentWrongMessageError(MediaResolverError):
    """Attachment is bound to a different message_id."""


class MediaAttachmentDeletedError(MediaResolverError):
    """Attachment is soft-deleted."""


class MediaSecurityError(MediaResolverError):
    """Attachment path containment or tampering violation."""


class MediaFileNotFoundError(MediaResolverError):
    """Physical file does not exist on disk."""


class MediaInvalidFileError(MediaResolverError):
    """Target path is not a regular file."""


class MediaFileTooLargeError(MediaResolverError):
    """Physical file exceeds maximum allowed size."""


class MediaCorruptedFileError(MediaResolverError):
    """Physical file content signature, size, or metadata integrity violation."""


# ===========================================================================
# Synchronous Worker Helpers
# ===========================================================================

def _read_file_sync(path: Path, expected_size: int, expected_mime: str) -> bytes:
    """Read attachment file synchronously inside a worker thread with strict bounds."""
    if not path.exists():
        raise MediaFileNotFoundError("Attachment file not found on disk.")
    if not path.is_file():
        raise MediaInvalidFileError("Attachment path does not point to a regular file.")

    st_size = path.stat().st_size
    if st_size > MAX_ATTACHMENT_SIZE_BYTES:
        raise MediaFileTooLargeError(
            f"Physical file size ({st_size} bytes) exceeds maximum ceiling of {MAX_ATTACHMENT_SIZE_BYTES} bytes."
        )
    if st_size != expected_size:
        raise MediaCorruptedFileError(
            f"Physical file size ({st_size} bytes) does not match recorded size ({expected_size} bytes)."
        )

    with open(path, "rb") as f:
        data = f.read(MAX_ATTACHMENT_SIZE_BYTES + 1)

    if len(data) > MAX_ATTACHMENT_SIZE_BYTES:
        raise MediaFileTooLargeError(
            f"File read exceeds maximum allowed {MAX_ATTACHMENT_SIZE_BYTES} bytes."
        )
    if len(data) != expected_size:
        raise MediaCorruptedFileError(
            f"Read data size ({len(data)} bytes) does not match recorded size ({expected_size} bytes)."
        )

    detected_mime = detect_image_mime(data[:12])
    if not detected_mime or detected_mime != expected_mime:
        raise MediaCorruptedFileError(
            f"Physical file signature '{detected_mime}' does not match expected MIME '{expected_mime}'."
        )

    return data


# ===========================================================================
# Primary Resolution Boundary
# ===========================================================================

async def resolve_image_content(
    session: AsyncSession,
    ref: Union[ImageAttachmentRef, Attachment],
    *,
    owner_id: str,
    conversation_id: str,
    message_id: str,
) -> ResolvedImageContent:
    """Resolve an ImageAttachmentRef or Attachment model to verified ResolvedImageContent.

    Enforces:
    1. Attachment existence in database.
    2. Non-enumeration cross-conversation isolation (404-style error).
    3. Cross-owner BOLA isolation (403-style error).
    4. Active (non-deleted) state.
    5. Exact message binding to the current turn's message_id.
    6. MIME authority (persisted MIME must be supported; ref MIME must match).
    7. Storage path canonical containment without Python assert.
    8. Physical file existence, size integrity, and signature verification.
    """
    if isinstance(ref, Attachment):
        att = ref
        ref_mime = att.mime_type
    else:
        stmt = select(Attachment).where(Attachment.id == ref.attachment_id)
        res = await session.execute(stmt)
        att = res.scalar_one_or_none()
        ref_mime = ref.mime_type

    if att is None:
        att_id_str = getattr(ref, "attachment_id", str(ref))
        raise MediaAttachmentNotFoundError(f"Attachment '{att_id_str}' not found.")
    if att.conversation_id != conversation_id:
        raise MediaAttachmentNotFoundError("Attachment does not belong to the requested conversation.")
    if att.owner_id != owner_id:
        raise MediaAttachmentForbiddenError("Access to attachment is forbidden.")
    if att.is_deleted:
        raise MediaAttachmentDeletedError("Attachment is soft-deleted.")
    if att.message_id is None:
        raise MediaAttachmentNotBoundError("Attachment is staged and not bound to a message.")
    if att.message_id != message_id:
        raise MediaAttachmentWrongMessageError("Attachment is bound to a different message.")

    # MIME integrity & authority
    if att.mime_type not in SUPPORTED_IMAGE_MIMES:
        raise MediaCorruptedFileError(f"Unsupported persisted attachment MIME type: {att.mime_type}")
    if ref_mime != att.mime_type:
        raise MediaCorruptedFileError(
            f"Reference MIME '{ref_mime}' does not match persisted MIME '{att.mime_type}'."
        )

    # Path containment and structure integrity (never use Python assert)
    storage_p = Path(att.storage_path)
    if storage_p.is_absolute():
        raise MediaSecurityError("Storage path must be relative.")
    if ".." in storage_p.parts:
        raise MediaSecurityError("Path traversal not permitted in storage path.")

    expected_rel_parent = Path("attachments") / owner_id / conversation_id
    if storage_p.parent != expected_rel_parent:
        raise MediaSecurityError("Storage path directory structure mismatch.")
    if storage_p.name != att.storage_filename:
        raise MediaSecurityError("Storage filename does not match storage path.")

    attachment_dir = settings.ATTACHMENT_DIR.resolve()
    expected_dir = (settings.ATTACHMENT_DIR / owner_id / conversation_id).resolve()
    candidate_path = (settings.COMPANION_DATA_ROOT / att.storage_path).resolve()

    if candidate_path.parent != expected_dir or attachment_dir not in candidate_path.parents:
        raise MediaSecurityError("Storage path containment violation.")

    # Read bytes off the main event loop
    data = await asyncio.to_thread(_read_file_sync, candidate_path, att.size_bytes, att.mime_type)

    return ResolvedImageContent(
        type="image_bytes",
        mime_type=att.mime_type,
        data=data,
    )
