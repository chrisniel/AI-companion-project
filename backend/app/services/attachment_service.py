"""Attachment domain service for atomic claiming, list validation, and error classification."""

import logging
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attachment import Attachment
from app.schemas.attachment import MAX_ATTACHMENTS_PER_MESSAGE

logger = logging.getLogger("app.services.attachment_service")


class AttachmentNotFoundError(HTTPException):
    """Raised when an attachment does not exist or belongs to another conversation."""

    def __init__(self, detail: str = "ATTACHMENT_NOT_FOUND") -> None:
        super().__init__(status_code=status.HTTP_404_NOT_FOUND, detail=detail)


class AttachmentForbiddenError(HTTPException):
    """Raised when an attachment belongs to a foreign owner (BOLA violation)."""

    def __init__(self, detail: str = "ATTACHMENT_FORBIDDEN") -> None:
        super().__init__(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


class AttachmentNotAvailableError(HTTPException):
    """Raised when an attachment is soft-deleted or otherwise unavailable."""

    def __init__(self, detail: str = "ATTACHMENT_NOT_AVAILABLE") -> None:
        super().__init__(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=detail)


class AttachmentAlreadyClaimedError(HTTPException):
    """Raised when an attachment is already bound to another message."""

    def __init__(self, detail: str = "ATTACHMENT_ALREADY_CLAIMED") -> None:
        super().__init__(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=detail)


def validate_attachment_ids_syntax(attachment_ids: Optional[list[str]]) -> None:
    """Validate list length, uniqueness, and format before any database operations.

    Pure validation function; raises HTTP 422 immediately if input violates constraints:
    - len(attachment_ids) <= MAX_ATTACHMENTS_PER_MESSAGE (4)
    - All IDs must be unique (no duplicate IDs in the same request payload)
    - All IDs must be non-empty strings
    """
    if not attachment_ids:
        return

    if len(attachment_ids) > MAX_ATTACHMENTS_PER_MESSAGE:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Maximum of {MAX_ATTACHMENTS_PER_MESSAGE} attachments allowed per message",
        )

    if len(attachment_ids) != len(set(attachment_ids)):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Duplicate attachment IDs in message payload are forbidden",
        )

    for att_id in attachment_ids:
        if not att_id or not isinstance(att_id, str) or not att_id.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Empty or whitespace-only attachment ID is invalid",
            )


async def claim_attachments_for_message(
    db: AsyncSession,
    attachment_ids: list[str],
    *,
    message_id: str,
    owner_id: str,
    conversation_id: str,
) -> None:
    """Claim staged attachments atomically for message_id within the caller's transaction.

    DOES NOT COMMIT. If any claim fails, raises an appropriate HTTPException:
    - AttachmentNotFoundError (404) if attachment doesn't exist or conversation mismatch
    - AttachmentForbiddenError (403) if attachment belongs to a foreign owner
    - AttachmentNotAvailableError (422) if attachment is soft-deleted
    - AttachmentAlreadyClaimedError (422) if attachment is already bound to a message

    The caller must catch exceptions and roll back the entire preparation transaction.
    """
    if not attachment_ids:
        return

    for att_id in attachment_ids:
        # Atomic conditional UPDATE
        stmt = (
            update(Attachment)
            .where(
                Attachment.id == att_id,
                Attachment.owner_id == owner_id,
                Attachment.conversation_id == conversation_id,
                Attachment.message_id.is_(None),
                Attachment.is_deleted.is_(False),
            )
            .values(message_id=message_id)
            .returning(Attachment.id)
        )
        result = await db.execute(stmt)
        claimed_id = result.scalar_one_or_none()

        if claimed_id is None:
            # Conditional update matched 0 rows -> perform read-only classification
            classify_stmt = select(Attachment).where(Attachment.id == att_id)
            classify_res = await db.execute(classify_stmt)
            att = classify_res.scalar_one_or_none()

            # Rule 1: Nonexistent or cross-conversation disclosure guard
            if not att or att.conversation_id != conversation_id:
                raise AttachmentNotFoundError("ATTACHMENT_NOT_FOUND")

            # Rule 2: Foreign owner under validated parent conversation (BOLA guard)
            if att.owner_id != owner_id:
                raise AttachmentForbiddenError("ATTACHMENT_FORBIDDEN")

            # Rule 3: Soft-deleted
            if att.is_deleted:
                raise AttachmentNotAvailableError("ATTACHMENT_NOT_AVAILABLE")

            # Rule 4: Already claimed
            if att.message_id is not None:
                raise AttachmentAlreadyClaimedError("ATTACHMENT_ALREADY_CLAIMED")

            # Fallback
            raise AttachmentNotAvailableError("ATTACHMENT_NOT_AVAILABLE")
