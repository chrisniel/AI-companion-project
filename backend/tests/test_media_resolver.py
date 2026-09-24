"""Comprehensive unit tests for MediaResolver service in Phase 8B.5."""

from pathlib import Path
import uuid
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.attachment import Attachment
from app.models.base import utc_now
from app.models.conversation import Conversation
from app.models.message import Message
from app.schemas.multimodal import ImageAttachmentRef
from app.services.assistant.media_resolver import (
    MediaAttachmentDeletedError,
    MediaAttachmentForbiddenError,
    MediaAttachmentNotBoundError,
    MediaAttachmentNotFoundError,
    MediaAttachmentWrongMessageError,
    MediaCorruptedFileError,
    MediaFileNotFoundError,
    MediaFileTooLargeError,
    MediaInvalidFileError,
    MediaSecurityError,
    resolve_image_content,
)

# Canonical sample image signatures
SAMPLE_PNG_BYTES = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00"
    b"\x1f\x15c4\x00\x00\x00\rIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfe\xa74e\xd8\x00\x00\x00\x00IEND\xaeB`\x82"
)
SAMPLE_JPEG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00testjpegdata"
SAMPLE_WEBP_BYTES = b"RIFF\x1a\x00\x00\x00WEBPVP8 \x0e\x00\x00\x00\x30\x01\x00\x9d\x01\x2a\x01\x00\x01\x00"


async def _setup_turn(
    session: AsyncSession,
    owner_id: str = "test-owner",
) -> tuple[Conversation, Message]:
    """Helper to create a conversation and a user message."""
    conv_id = f"conv-{uuid.uuid4().hex[:8]}"
    msg_id = f"msg-{uuid.uuid4().hex[:8]}"

    conv = Conversation(id=conv_id, owner_id=owner_id, title="Media Test", character_id="default")
    session.add(conv)
    await session.flush()

    msg = Message(
        id=msg_id,
        conversation_id=conv_id,
        owner_id=owner_id,
        sender="user",
        content="Test query",
        status="completed",
        sequence_no=1,
    )
    session.add(msg)
    await session.commit()
    return conv, msg


def _create_physical_file(
    owner_id: str,
    conversation_id: str,
    storage_filename: str,
    data: bytes,
) -> Path:
    """Helper to create a physical file in the canonical attachments directory."""
    target_dir = settings.ATTACHMENT_DIR / owner_id / conversation_id
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / storage_filename
    target_file.write_bytes(data)
    return target_file


@pytest.mark.anyio
async def test_resolve_valid_bound_png_returns_exact_bytes(test_session: AsyncSession):
    """Verify resolving a valid bound PNG returns exact bytes and metadata."""
    owner_id = "owner-png"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    resolved = await resolve_image_content(
        session=test_session,
        ref=ref,
        owner_id=owner_id,
        conversation_id=conv.id,
        message_id=msg.id,
    )

    assert resolved.type == "image_bytes"
    assert resolved.mime_type == "image/png"
    assert resolved.data == SAMPLE_PNG_BYTES


@pytest.mark.anyio
async def test_resolve_valid_bound_jpeg_returns_exact_bytes(test_session: AsyncSession):
    """Verify resolving a valid bound JPEG returns exact bytes."""
    owner_id = "owner-jpeg"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.jpeg"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_JPEG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.jpeg",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/jpeg",
        size_bytes=len(SAMPLE_JPEG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/jpeg")
    resolved = await resolve_image_content(
        session=test_session,
        ref=ref,
        owner_id=owner_id,
        conversation_id=conv.id,
        message_id=msg.id,
    )

    assert resolved.mime_type == "image/jpeg"
    assert resolved.data == SAMPLE_JPEG_BYTES


@pytest.mark.anyio
async def test_resolve_returns_mime_from_attachment_metadata(test_session: AsyncSession):
    """Persisted attachment metadata determines returned MIME."""
    owner_id = "owner-meta"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    resolved = await resolve_image_content(
        session=test_session,
        ref=ref,
        owner_id=owner_id,
        conversation_id=conv.id,
        message_id=msg.id,
    )
    assert resolved.mime_type == "image/png"


@pytest.mark.anyio
async def test_resolve_nonexistent_attachment_raises_not_found(test_session: AsyncSession):
    """Nonexistent attachment ID raises MediaAttachmentNotFoundError."""
    conv, msg = await _setup_turn(test_session)
    ref = ImageAttachmentRef(attachment_id="nonexistent-att-id", mime_type="image/png")
    with pytest.raises(MediaAttachmentNotFoundError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id="test-owner",
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_wrong_conversation_raises_not_found(test_session: AsyncSession):
    """Attachment belonging to a different conversation raises MediaAttachmentNotFoundError."""
    owner_id = "owner-diff-conv"
    conv1, msg1 = await _setup_turn(test_session, owner_id=owner_id)
    conv2, msg2 = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv1.id}/{filename}"
    _create_physical_file(owner_id, conv1.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv1.id,
        owner_id=owner_id,
        message_id=msg1.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    # Querying under conv2 must fail
    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaAttachmentNotFoundError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv2.id,
            message_id=msg2.id,
        )


@pytest.mark.anyio
async def test_resolve_wrong_owner_raises_forbidden(test_session: AsyncSession):
    """Attachment belonging to foreign owner raises MediaAttachmentForbiddenError."""
    conv, msg = await _setup_turn(test_session, owner_id="legit-owner")

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/legit-owner/{conv.id}/{filename}"
    _create_physical_file("legit-owner", conv.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id="foreign-owner",  # BOLA foreign owner
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaAttachmentForbiddenError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id="legit-owner",
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_staged_unbound_attachment_raises_not_bound(test_session: AsyncSession):
    """Attachment with message_id=None raises MediaAttachmentNotBoundError."""
    owner_id = "owner-staged"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=None,  # Staged
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaAttachmentNotBoundError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_attachment_bound_to_different_message_raises_wrong_message(test_session: AsyncSession):
    """Attachment bound to another message_id raises MediaAttachmentWrongMessageError."""
    owner_id = "owner-wrong-msg"
    conv, msg1 = await _setup_turn(test_session, owner_id=owner_id)
    msg2 = Message(
        id=f"msg-{uuid.uuid4().hex[:8]}",
        conversation_id=conv.id,
        owner_id=owner_id,
        sender="user",
        content="Second turn",
        status="completed",
        sequence_no=2,
    )
    test_session.add(msg2)
    await test_session.commit()

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg1.id,  # Bound to msg1
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    # Attempting to resolve under msg2 must fail
    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaAttachmentWrongMessageError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg2.id,
        )


@pytest.mark.anyio
async def test_resolve_soft_deleted_attachment_raises_deleted(test_session: AsyncSession):
    """Soft-deleted attachment raises MediaAttachmentDeletedError."""
    owner_id = "owner-del"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
        is_deleted=True,
        deleted_at=utc_now(),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaAttachmentDeletedError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_absolute_storage_path_raises_security_error(test_session: AsyncSession):
    """Absolute storage path raises MediaSecurityError."""
    owner_id = "owner-abs"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=f"{att_id}.png",
        storage_path="C:/Windows/System32/calc.exe",
        mime_type="image/png",
        size_bytes=100,
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaSecurityError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_traversal_dot_dot_path_raises_security_error(test_session: AsyncSession):
    """Storage path containing '..' raises MediaSecurityError."""
    owner_id = "owner-dotdot"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=f"{att_id}.png",
        storage_path=f"attachments/{owner_id}/../../etc/passwd",
        mime_type="image/png",
        size_bytes=100,
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaSecurityError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_foreign_owner_path_tamper_raises_security_error(test_session: AsyncSession):
    """Storage path pointing to another owner's directory raises MediaSecurityError."""
    owner_id = "owner-tamper1"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    # Points to victim-owner instead of owner-tamper1
    storage_path = f"attachments/victim-owner/{conv.id}/{filename}"

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaSecurityError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_foreign_conversation_path_tamper_raises_security_error(test_session: AsyncSession):
    """Storage path pointing to another conversation directory raises MediaSecurityError."""
    owner_id = "owner-tamper2"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    # Points to other-conv-id instead of conv.id
    storage_path = f"attachments/{owner_id}/other-conv-id/{filename}"

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaSecurityError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_storage_filename_mismatch_raises_security_error(test_session: AsyncSession):
    """Storage path filename differing from storage_filename raises MediaSecurityError."""
    owner_id = "owner-namemismatch"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    storage_path = f"attachments/{owner_id}/{conv.id}/actual_target.png"

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename="different_target.png",  # Mismatch
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaSecurityError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_missing_physical_file_raises_file_not_found(test_session: AsyncSession):
    """Missing physical file on disk raises MediaFileNotFoundError."""
    owner_id = "owner-missing"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    # Intentionally do NOT create physical file

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=100,
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaFileNotFoundError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_directory_target_raises_invalid_file(test_session: AsyncSession):
    """Storage path pointing to a directory instead of a regular file raises MediaInvalidFileError."""
    owner_id = "owner-dir"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"

    # Create directory at that path
    target_dir = settings.ATTACHMENT_DIR / owner_id / conv.id / filename
    target_dir.mkdir(parents=True, exist_ok=True)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=100,
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaInvalidFileError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_physical_file_exceeding_size_ceiling_raises_too_large(test_session: AsyncSession):
    """Physical file exceeding 10 MiB ceiling raises MediaFileTooLargeError."""
    owner_id = "owner-huge"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"

    # Create dummy 10 MiB + 10 bytes file
    huge_data = b"\x89PNG\r\n\x1a\n" + b"0" * (10 * 1024 * 1024 + 10)
    _create_physical_file(owner_id, conv.id, filename, huge_data)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(huge_data),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaFileTooLargeError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_ref_mime_mismatches_persisted_mime_raises_corrupted_file(test_session: AsyncSession):
    """Reference MIME mismatching persisted MIME raises MediaCorruptedFileError."""
    owner_id = "owner-mimemismatch"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",  # Persisted is PNG
        size_bytes=len(SAMPLE_PNG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    # Ref claims it's JPEG
    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/jpeg")
    with pytest.raises(MediaCorruptedFileError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_physical_file_size_mismatches_persisted_size_raises_corrupted_file(test_session: AsyncSession):
    """Physical file size differing from persisted attachment.size_bytes raises MediaCorruptedFileError."""
    owner_id = "owner-sizemismatch"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_PNG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_PNG_BYTES) + 50,  # Recorded size differs from real file
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaCorruptedFileError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_physical_file_signature_mismatch_raises_corrupted_file(test_session: AsyncSession):
    """Physical file signature not matching metadata raises MediaCorruptedFileError."""
    owner_id = "owner-sigmismatch"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    # Persist as PNG, but write JPEG bytes to disk
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_JPEG_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(SAMPLE_JPEG_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaCorruptedFileError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_malformed_unknown_signature_rejected(test_session: AsyncSession):
    """File containing arbitrary non-image bytes raises MediaCorruptedFileError."""
    owner_id = "owner-badmagic"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.png"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    bad_bytes = b"MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00"  # PE binary header
    _create_physical_file(owner_id, conv.id, filename, bad_bytes)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.png",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/png",
        size_bytes=len(bad_bytes),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/png")
    with pytest.raises(MediaCorruptedFileError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )


@pytest.mark.anyio
async def test_resolve_unsupported_persisted_mime_rejected(test_session: AsyncSession):
    """Persisted MIME outside image/png or image/jpeg (e.g. image/webp) is rejected even if ref matches."""
    owner_id = "owner-webp"
    conv, msg = await _setup_turn(test_session, owner_id=owner_id)

    att_id = f"att-{uuid.uuid4().hex[:8]}"
    filename = f"{att_id}.webp"
    storage_path = f"attachments/{owner_id}/{conv.id}/{filename}"
    _create_physical_file(owner_id, conv.id, filename, SAMPLE_WEBP_BYTES)

    att = Attachment(
        id=att_id,
        conversation_id=conv.id,
        owner_id=owner_id,
        message_id=msg.id,
        filename_display="sample.webp",
        storage_filename=filename,
        storage_path=storage_path,
        mime_type="image/webp",  # WebP not supported in 8B.5
        size_bytes=len(SAMPLE_WEBP_BYTES),
    )
    test_session.add(att)
    await test_session.commit()

    ref = ImageAttachmentRef(attachment_id=att_id, mime_type="image/webp")
    with pytest.raises(MediaCorruptedFileError):
        await resolve_image_content(
            session=test_session,
            ref=ref,
            owner_id=owner_id,
            conversation_id=conv.id,
            message_id=msg.id,
        )
