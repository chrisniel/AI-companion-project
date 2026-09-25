"""Comprehensive test suite for Phase 8B.3: Secure Attachment API."""

import io
import os
from pathlib import Path
from typing import AsyncGenerator
import pytest
from httpx import ASGITransport, AsyncClient
from PIL import Image
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_owner, get_db
from app.core.config import settings
from app.main import app
from app.models.attachment import Attachment
from app.models.base import utc_now
from app.models.conversation import Conversation


def _create_minimal_png(size=(32, 32), color="blue", compress_level=None) -> bytes:
    """Generate minimal valid PNG bytes."""
    img = Image.new("RGB", size, color=color)
    buf = io.BytesIO()
    if compress_level is not None:
        img.save(buf, format="PNG", compress_level=compress_level)
    else:
        img.save(buf, format="PNG")
    return buf.getvalue()


def _create_minimal_jpeg(size=(32, 32), color="red") -> bytes:
    """Generate minimal valid JPEG bytes."""
    img = Image.new("RGB", size, color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


async def _create_test_conversation(
    session: AsyncSession,
    owner_id: str = "local_user",
    title: str = "Test Conv",
    deleted: bool = False,
) -> Conversation:
    """Create a persistent test conversation in DB."""
    import uuid
    conv = Conversation(
        id=f"conv-{uuid.uuid4().hex[:8]}",
        owner_id=owner_id,
        title=title,
        character_id="default",
        deleted_at=utc_now() if deleted else None,
    )
    session.add(conv)
    await session.commit()
    await session.refresh(conv)
    return conv


@pytest.fixture
async def error_client(test_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Test client configured with raise_app_exceptions=False to test unhandled server errors (500)."""
    app.dependency_overrides[get_db] = lambda: test_session
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac
    app.dependency_overrides.clear()


# ===========================================================================
# 1. Middleware & Request Ceiling Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_middleware_ordinary_endpoint_rejects_over_2mb(client: AsyncClient, auth_headers: dict):
    """Ordinary endpoints (like /api/v1/tasks) continue to enforce the 2 MiB ceiling."""
    oversized = "x" * (settings.MAX_REQUEST_BODY_BYTES + 1024)
    headers = {
        **auth_headers,
        "Content-Length": str(len(oversized)),
        "Content-Type": "application/json",
    }
    response = await client.post("/api/v1/tasks", content=oversized, headers=headers)
    assert response.status_code == 413
    assert response.json()["error"]["code"] == "PAYLOAD_TOO_LARGE"
    assert "2097152" in response.json()["error"]["message"]


@pytest.mark.asyncio
async def test_middleware_attachment_upload_allows_envelope_between_2mb_and_12mb(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Attachment upload endpoint allows a valid image payload > 2 MiB (e.g. 2.7 MiB) within 12 MiB envelope."""
    conv = await _create_test_conversation(test_session)
    # 1000x900 uncompressed PNG is ~2.7 MiB (> 2 MiB, < 10 MiB, < 32 MP)
    png_bytes = _create_minimal_png(size=(1000, 900), compress_level=0)
    assert len(png_bytes) > 2 * 1024 * 1024
    assert len(png_bytes) < 10 * 1024 * 1024

    files = {"file": ("large_2mb.png", png_bytes, "image/png")}
    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 201
    assert response.json()["size_bytes"] == len(png_bytes)


@pytest.mark.asyncio
async def test_middleware_attachment_upload_rejects_envelope_over_12mb(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Attachment upload endpoint rejects an envelope exceeding MAX_ATTACHMENT_REQUEST_BODY_BYTES (12 MiB)."""
    conv = await _create_test_conversation(test_session)

    # Use Content-Length fast-path check
    headers = {
        **auth_headers,
        "Content-Length": str(settings.MAX_ATTACHMENT_REQUEST_BODY_BYTES + 1024),
        "Content-Type": "multipart/form-data; boundary=boundary123",
    }

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        content=b"--boundary123--",
        headers=headers,
    )
    assert response.status_code == 413
    assert response.json()["error"]["code"] == "PAYLOAD_TOO_LARGE"
    assert "12582912" in response.json()["error"]["message"]


@pytest.mark.asyncio
async def test_middleware_attachment_upload_streaming_chunked_exceeds_route_limit_413(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """Chunked streaming upload exceeding route-specific limit returns 413 PAYLOAD_TOO_LARGE without persisting row or file."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    target_dir = settings.ATTACHMENT_DIR / "local_user" / conv_id

    # Monkeypatch route-specific attachment limit to a lightweight test value (8 KiB)
    test_limit = 8 * 1024
    monkeypatch.setattr(settings, "MAX_ATTACHMENT_REQUEST_BODY_BYTES", test_limit)

    # Stream chunks totaling more than test_limit (e.g. 3 chunks of 4 KiB = 12 KiB)
    chunk_size = 4 * 1024
    total_chunks = (test_limit // chunk_size) + 1  # 3 chunks = 12 KiB > 8 KiB

    async def streaming_multipart():
        yield b"--boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"test.png\"\r\nContent-Type: image/png\r\n\r\n"
        for _ in range(total_chunks):
            yield b"x" * chunk_size
        yield b"\r\n--boundary--\r\n"

    headers = {
        **auth_headers,
        "Content-Type": "multipart/form-data; boundary=boundary",
    }
    # Ensure Content-Length is NOT in headers
    assert "Content-Length" not in headers

    response = await client.post(
        f"/api/v1/conversations/{conv_id}/attachments",
        content=streaming_multipart(),
        headers=headers,
    )

    # Assertions
    assert response.status_code == 413
    error_data = response.json()["error"]
    assert error_data["code"] == "PAYLOAD_TOO_LARGE"
    # Prove the route-specific attachment limit was used, not the ordinary 2 MiB limit (2097152)
    assert str(test_limit) in error_data["message"]
    assert str(settings.MAX_REQUEST_BODY_BYTES) not in error_data["message"]

    # Verify no Attachment row was persisted
    stmt = select(Attachment).where(Attachment.conversation_id == conv_id)
    records = (await test_session.execute(stmt)).scalars().all()
    assert len(records) == 0

    # Verify no physical file was created
    if target_dir.exists():
        assert len(list(target_dir.iterdir())) == 0


@pytest.mark.asyncio
async def test_middleware_other_conversation_routes_remain_2mb_limit(
    client: AsyncClient, auth_headers: dict
):
    """Other POST routes under /conversations remain strictly capped at 2 MiB."""
    oversized = "x" * (settings.MAX_REQUEST_BODY_BYTES + 1024)
    headers = {
        **auth_headers,
        "Content-Length": str(len(oversized)),
        "Content-Type": "application/json",
    }
    response = await client.post("/api/v1/conversations", content=oversized, headers=headers)
    assert response.status_code == 413
    assert "2097152" in response.json()["error"]["message"]


# ===========================================================================
# 2. Authentication & Parent Authorization Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_upload_unauthenticated_returns_401(client: AsyncClient):
    """Missing authentication token returns 401."""
    files = {"file": ("test.png", _create_minimal_png(), "image/png")}
    response = await client.post("/api/v1/conversations/conv-123/attachments", files=files)
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTHENTICATION_REQUIRED"


@pytest.mark.asyncio
async def test_upload_nonexistent_conversation_returns_404(client: AsyncClient, auth_headers: dict):
    """Uploading to nonexistent conversation ID returns 404."""
    files = {"file": ("test.png", _create_minimal_png(), "image/png")}
    response = await client.post(
        "/api/v1/conversations/nonexistent-conv-id/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 404
    assert "conversation not found" in response.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_upload_foreign_owned_conversation_returns_404(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Uploading to conversation owned by another user returns 404 (no information disclosure)."""
    conv = await _create_test_conversation(test_session, owner_id="foreign_owner")
    files = {"file": ("test.png", _create_minimal_png(), "image/png")}
    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 404
    assert "conversation not found" in response.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_upload_deleted_conversation_returns_404(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Uploading to soft-deleted conversation returns 404."""
    conv = await _create_test_conversation(test_session, deleted=True)
    files = {"file": ("test.png", _create_minimal_png(), "image/png")}
    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 404
    assert "conversation not found" in response.json()["error"]["message"].lower()


# ===========================================================================
# 3. Upload Validation & Persistence Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_upload_valid_png_success(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Uploading valid PNG produces 201 AttachmentOut and valid DB record."""
    conv = await _create_test_conversation(test_session)
    png_bytes = _create_minimal_png(size=(48, 36))
    files = {"file": ("diagram.png", png_bytes, "image/png")}

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["conversation_id"] == conv.id
    assert data["filename_display"] == "diagram.png"
    assert data["mime_type"] == "image/png"
    assert data["image_width"] == 48
    assert data["image_height"] == 36
    assert data["size_bytes"] == len(png_bytes)
    assert data["message_id"] is None
    assert "storage_path" not in data
    assert "storage_filename" not in data
    assert "owner_id" not in data


@pytest.mark.asyncio
async def test_upload_valid_jpeg_success(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Uploading valid JPEG produces 201 AttachmentOut."""
    conv = await _create_test_conversation(test_session)
    jpg_bytes = _create_minimal_jpeg(size=(60, 40))
    files = {"file": ("photo.jpg", jpg_bytes, "image/jpeg")}

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["mime_type"] == "image/jpeg"
    assert data["image_width"] == 60
    assert data["image_height"] == 40


@pytest.mark.asyncio
async def test_upload_mime_sniffing_overrides_content_type(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """MIME sniffing from raw bytes overrides declared multipart Content-Type."""
    conv = await _create_test_conversation(test_session)
    png_bytes = _create_minimal_png()
    # Deliberately spoof Content-Type header as JPEG
    files = {"file": ("diagram.jpg", png_bytes, "image/jpeg")}

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 201
    assert response.json()["mime_type"] == "image/png"


@pytest.mark.asyncio
async def test_upload_webp_rejected_422(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Uploading WebP returns 422 with explicit deferred message."""
    conv = await _create_test_conversation(test_session)
    img = Image.new("RGB", (32, 32), color="green")
    buf = io.BytesIO()
    img.save(buf, format="WEBP")

    files = {"file": ("sample.webp", buf.getvalue(), "image/webp")}
    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 422
    assert "deferred" in response.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_upload_corrupt_data_rejected_422(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Corrupted image payload returns 422."""
    conv = await _create_test_conversation(test_session)
    corrupted_data = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRcorrupted"
    files = {"file": ("corrupt.png", corrupted_data, "image/png")}

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_upload_raw_bytes_exceeding_10mb_returns_413(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """Raw image bytes > 10 MiB is rejected with 413 even if envelope fits."""
    conv = await _create_test_conversation(test_session)

    # Patch MAX_SIZE_BYTES in attachments module to test boundary without allocating 10 MiB
    monkeypatch.setattr("app.api.v1.endpoints.attachments.MAX_SIZE_BYTES", 100)
    data = _create_minimal_png()  # > 100 bytes

    files = {"file": ("big.png", data, "image/png")}
    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 413


@pytest.mark.asyncio
async def test_upload_created_attachment_is_staged_and_db_verified(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Newly uploaded attachment has message_id=None and valid relative storage_path."""
    conv = await _create_test_conversation(test_session)
    png_bytes = _create_minimal_png()
    files = {"file": ("staged.png", png_bytes, "image/png")}

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 201
    att_id = response.json()["id"]

    stmt = select(Attachment).where(Attachment.id == att_id)
    att = (await test_session.execute(stmt)).scalar_one()
    assert att.message_id is None
    assert att.owner_id == "local_user"
    assert att.conversation_id == conv.id
    assert att.storage_path.startswith("attachments/local_user/")
    assert att.storage_filename.endswith(".png")


@pytest.mark.asyncio
async def test_upload_traversal_filename_cannot_affect_storage(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Path traversal filename (POSIX and Windows style) is sanitized to display-only basename."""
    conv = await _create_test_conversation(test_session)
    png_bytes = _create_minimal_png()

    # Test POSIX traversal
    files_posix = {"file": ("../../etc/passwd.png", png_bytes, "image/png")}
    res_posix = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files_posix,
        headers=auth_headers,
    )
    assert res_posix.status_code == 201
    assert res_posix.json()["filename_display"] == "passwd.png"

    # Test Windows traversal
    files_win = {"file": ("..\\..\\Windows\\System32\\cmd.exe.png", png_bytes, "image/png")}
    res_win = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files_win,
        headers=auth_headers,
    )
    assert res_win.status_code == 201
    assert res_win.json()["filename_display"] == "cmd.exe.png"


@pytest.mark.asyncio
async def test_upload_duplicate_display_filenames_unique_storage(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Uploading two files with identical display names creates distinct storage records and files."""
    conv = await _create_test_conversation(test_session)
    png_bytes = _create_minimal_png()

    res1 = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("same_name.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    res2 = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("same_name.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    assert res1.status_code == 201
    assert res2.status_code == 201
    assert res1.json()["id"] != res2.json()["id"]

    stmt = select(Attachment).where(Attachment.id.in_([res1.json()["id"], res2.json()["id"]]))
    records = (await test_session.execute(stmt)).scalars().all()
    assert len(records) == 2
    assert records[0].storage_filename != records[1].storage_filename


# ===========================================================================
# 4. Failure Cleanup, Ordering & Atomicity Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_upload_validation_failure_leaves_no_file_or_row(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Validation failure leaves 0 files on disk and 0 DB rows."""
    conv = await _create_test_conversation(test_session)
    files = {"file": ("text.png", b"plain text payload", "image/png")}

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files=files,
        headers=auth_headers,
    )
    assert response.status_code == 422

    stmt = select(Attachment).where(Attachment.conversation_id == conv.id)
    assert len((await test_session.execute(stmt)).scalars().all()) == 0

    target_dir = settings.ATTACHMENT_DIR / "local_user" / conv.id
    if target_dir.exists():
        assert len(list(target_dir.iterdir())) == 0


@pytest.mark.asyncio
async def test_upload_db_flush_failure_leaves_no_file_or_row(
    error_client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """Database flush failure occurs before disk write, leaving no file on disk and no DB row."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    target_dir = settings.ATTACHMENT_DIR / "local_user" / conv_id
    png_bytes = _create_minimal_png()

    async def fake_flush():
        raise RuntimeError("Simulated DB flush constraint failure")

    monkeypatch.setattr(test_session, "flush", fake_flush)

    response = await error_client.post(
        f"/api/v1/conversations/{conv_id}/attachments",
        files={"file": ("test.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    assert response.status_code == 500

    stmt = select(Attachment).where(Attachment.conversation_id == conv_id)
    assert len((await test_session.execute(stmt)).scalars().all()) == 0

    if target_dir.exists():
        assert len(list(target_dir.iterdir())) == 0


@pytest.mark.asyncio
async def test_upload_disk_write_failure_leaves_no_db_row(
    error_client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """Filesystem write failure rolls back DB transaction and cleans temp file."""
    import app.api.v1.endpoints.attachments as att_module
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    png_bytes = _create_minimal_png()

    def fake_save(*args, **kwargs):
        raise OSError("Simulated disk full or I/O failure")

    monkeypatch.setattr(att_module, "save_attachment_file_no_clobber", fake_save)

    response = await error_client.post(
        f"/api/v1/conversations/{conv_id}/attachments",
        files={"file": ("test.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    assert response.status_code == 500

    stmt = select(Attachment).where(Attachment.conversation_id == conv_id)
    assert len((await test_session.execute(stmt)).scalars().all()) == 0


@pytest.mark.asyncio
async def test_upload_db_second_flush_failure_cleans_up_promoted_file(
    error_client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """A second-flush failure after physical promotion rolls back DB and unlinks newly created file without deleting collisions."""
    import app.api.v1.endpoints.attachments as att_module
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    target_dir = settings.ATTACHMENT_DIR / "local_user" / conv_id
    target_dir.mkdir(parents=True, exist_ok=True)

    # Pre-create an existing file that causes a collision during file save
    collision_file = target_dir / "colliding_name.png"
    collision_file.write_bytes(b"EXISTING_COLLISION_DATA_DO_NOT_TOUCH")

    # UUID generation:
    # Call 1: initial_storage_filename before initial flush -> "name_one"
    # In save_attachment_file_no_clobber: "name_one.png" already exists, so it retries with "name_two"
    calls = 0
    def fake_uuid():
        nonlocal calls
        calls += 1
        if calls == 1:
            return "name_one"
        if calls == 2:
            return "name_two"
        return f"name_{calls}"

    monkeypatch.setattr(att_module, "generate_uuid", fake_uuid)

    # Wrap save_attachment_file_no_clobber to create name_one.png right as save begins,
    # simulating a concurrent upload that claimed name_one.png after our preflight check
    real_save = att_module.save_attachment_file_no_clobber
    def wrapping_save(td, d, ext, preferred_filename=None, **kwargs):
        if preferred_filename:
            (td / preferred_filename).write_bytes(b"CONCURRENT_COLLISION")
        return real_save(td, d, ext, preferred_filename=preferred_filename, **kwargs)

    monkeypatch.setattr(att_module, "save_attachment_file_no_clobber", wrapping_save)

    # Monkeypatch flush so 1st flush (initial) succeeds, but 2nd flush (after name change) fails
    original_flush = test_session.flush
    flush_count = 0
    async def fake_flush():
        nonlocal flush_count
        flush_count += 1
        if flush_count > 1:
            raise RuntimeError("Simulated second DB flush failure")
        await original_flush()

    monkeypatch.setattr(test_session, "flush", fake_flush)

    png_bytes = _create_minimal_png()
    response = await error_client.post(
        f"/api/v1/conversations/{conv_id}/attachments",
        files={"file": ("test.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    assert response.status_code == 500

    # 1. DB record was rolled back: 0 rows
    stmt = select(Attachment).where(Attachment.conversation_id == conv_id)
    assert len((await test_session.execute(stmt)).scalars().all()) == 0

    # 2. The newly promoted file (name_two.png) was unlinked and does NOT exist
    assert not (target_dir / "name_two.png").exists()

    # 3. The pre-existing collision files (name_one.png, colliding_name.png) are completely intact!
    assert (target_dir / "name_one.png").exists()
    assert (target_dir / "name_one.png").read_bytes() == b"CONCURRENT_COLLISION"
    assert collision_file.exists()
    assert collision_file.read_bytes() == b"EXISTING_COLLISION_DATA_DO_NOT_TOUCH"


@pytest.mark.asyncio
async def test_upload_db_commit_failure_cleans_up_promoted_file(
    error_client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """Commit failure rolls back DB and deletes newly promoted physical file."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    target_dir = settings.ATTACHMENT_DIR / "local_user" / conv_id
    png_bytes = _create_minimal_png()

    async def fake_commit():
        raise RuntimeError("Simulated DB commit error")

    monkeypatch.setattr(test_session, "commit", fake_commit)

    response = await error_client.post(
        f"/api/v1/conversations/{conv_id}/attachments",
        files={"file": ("test.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    assert response.status_code == 500

    stmt = select(Attachment).where(Attachment.conversation_id == conv_id)
    assert len((await test_session.execute(stmt)).scalars().all()) == 0

    if target_dir.exists():
        # All files, including promoted ones, must be removed
        assert len(list(target_dir.iterdir())) == 0


@pytest.mark.asyncio
async def test_upload_post_commit_failure_preserves_db_and_file(
    error_client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """If an error occurs during response construction after commit, DB row and file are preserved."""
    import app.api.v1.endpoints.attachments as att_module
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    png_bytes = _create_minimal_png()

    # Monkeypatch AttachmentOut constructor in attachments endpoint to raise an exception after commit
    def fake_attachment_out(*args, **kwargs):
        raise RuntimeError("Simulated response serialization failure")

    monkeypatch.setattr(att_module, "AttachmentOut", fake_attachment_out)

    response = await error_client.post(
        f"/api/v1/conversations/{conv_id}/attachments",
        files={"file": ("test.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    assert response.status_code == 500

    # Verify that the DB record and disk file were NOT rolled back or destroyed
    stmt = select(Attachment).where(Attachment.conversation_id == conv_id)
    records = (await test_session.execute(stmt)).scalars().all()
    assert len(records) == 1
    disk_path = settings.COMPANION_DATA_ROOT / records[0].storage_path
    assert disk_path.exists()


@pytest.mark.asyncio
async def test_upload_storage_collision_no_clobber(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """Pre-existing file on disk is NEVER overwritten by an attachment upload."""
    import app.api.v1.endpoints.attachments as att_module
    conv = await _create_test_conversation(test_session)
    target_dir = settings.ATTACHMENT_DIR / "local_user" / conv.id
    target_dir.mkdir(parents=True, exist_ok=True)

    # Pre-create an existing file with specific content
    collision_file = target_dir / "colliding_name.png"
    collision_file.write_bytes(b"DO_NOT_OVERWRITE_THIS_EXISTING_DATA")

    png_bytes = _create_minimal_png()

    # Force candidate generation to return the collision name once, then a non-colliding name
    calls = 0
    def fake_uuid():
        nonlocal calls
        calls += 1
        if calls == 1:
            return "colliding_name"
        return "fresh_safe_uuid"

    monkeypatch.setattr(att_module, "generate_uuid", fake_uuid)

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("test.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    assert response.status_code == 201

    # Verify the pre-existing file content is completely intact
    assert collision_file.read_bytes() == b"DO_NOT_OVERWRITE_THIS_EXISTING_DATA"
    # Verify the new attachment was saved under the alternate non-colliding name
    fresh_file = target_dir / "fresh_safe_uuid.png"
    assert fresh_file.exists()


@pytest.mark.asyncio
async def test_upload_exclusive_temp_file_collision_preserves_existing_temp(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch
):
    """Existing temp file created by foreign or stale process is never overwritten or deleted."""
    import app.api.v1.endpoints.attachments as att_module
    conv = await _create_test_conversation(test_session)
    target_dir = settings.ATTACHMENT_DIR / "local_user" / conv.id
    target_dir.mkdir(parents=True, exist_ok=True)

    # Pre-create an existing temp file
    foreign_temp = target_dir / ".tmp_temp_colliding.png"
    foreign_temp.write_bytes(b"FOREIGN_TEMP_DO_NOT_OVERWRITE_OR_DELETE")

    png_bytes = _create_minimal_png()

    calls = 0
    def fake_uuid():
        nonlocal calls
        calls += 1
        if calls <= 2:
            return "temp_colliding"
        return "fresh_after_temp_collision"

    monkeypatch.setattr(att_module, "generate_uuid", fake_uuid)

    response = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("test.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    assert response.status_code == 201

    # Verify foreign temp file was preserved untouched
    assert foreign_temp.exists()
    assert foreign_temp.read_bytes() == b"FOREIGN_TEMP_DO_NOT_OVERWRITE_OR_DELETE"

    # Verify new attachment was saved under the non-colliding candidate
    promoted = target_dir / "fresh_after_temp_collision.png"
    assert promoted.exists()


# ===========================================================================
# 5. Preview Endpoint Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_preview_valid_authenticated_returns_image_stream(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Previewing valid attachment returns 200 with raw binary matching original image."""
    conv = await _create_test_conversation(test_session)
    png_bytes = _create_minimal_png(size=(40, 40), color="yellow")

    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("yellow.png", png_bytes, "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    preview_res = await client.get(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}/preview",
        headers=auth_headers,
    )
    assert preview_res.status_code == 200
    assert preview_res.headers["Content-Type"].startswith("image/png")
    assert preview_res.content == png_bytes


@pytest.mark.asyncio
async def test_preview_staged_attachment_is_previewable(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Staged attachment (message_id is None) is fully previewable."""
    conv = await _create_test_conversation(test_session)
    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("staged.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    res = await client.get(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}/preview",
        headers=auth_headers,
    )
    assert res.status_code == 200


@pytest.mark.asyncio
async def test_preview_wrong_conversation_returns_404(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Requesting an attachment under a different conversation returns 404."""
    conv1 = await _create_test_conversation(test_session, title="Conv 1")
    conv2 = await _create_test_conversation(test_session, title="Conv 2")

    upload_res = await client.post(
        f"/api/v1/conversations/{conv1.id}/attachments",
        files={"file": ("conv1.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    res = await client.get(
        f"/api/v1/conversations/{conv2.id}/attachments/{att_id}/preview",
        headers=auth_headers,
    )
    assert res.status_code == 404
    assert "attachment not found" in res.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_preview_foreign_owner_returns_403(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Attachment row with foreign owner_id under owned conversation returns 403."""
    conv = await _create_test_conversation(test_session)
    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("photo.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    # Tamper with attachment owner in DB to simulate foreign owner
    stmt = select(Attachment).where(Attachment.id == att_id)
    att = (await test_session.execute(stmt)).scalar_one()
    att.owner_id = "foreign_owner"
    await test_session.commit()

    res = await client.get(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}/preview",
        headers=auth_headers,
    )
    assert res.status_code == 403
    assert "not authorized" in res.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_preview_soft_deleted_attachment_returns_404(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Soft-deleted attachment returns 404 on preview."""
    conv = await _create_test_conversation(test_session)
    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("deleted.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    # Soft-delete the attachment
    stmt = select(Attachment).where(Attachment.id == att_id)
    att = (await test_session.execute(stmt)).scalar_one()
    att.is_deleted = True
    att.deleted_at = utc_now()
    await test_session.commit()

    res = await client.get(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}/preview",
        headers=auth_headers,
    )
    assert res.status_code == 404


@pytest.mark.asyncio
async def test_preview_missing_physical_file_returns_404(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """If DB row exists but file is missing on disk, return clean 404 without leaking path."""
    conv = await _create_test_conversation(test_session)
    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("missing.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    stmt = select(Attachment).where(Attachment.id == att_id)
    att = (await test_session.execute(stmt)).scalar_one()
    disk_path = settings.COMPANION_DATA_ROOT / att.storage_path
    disk_path.unlink()

    res = await client.get(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}/preview",
        headers=auth_headers,
    )
    assert res.status_code == 404
    assert str(disk_path) not in res.text


@pytest.mark.asyncio
async def test_preview_traversal_storage_path_fails_containment(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Tampered DB row with storage_path escaping ATTACHMENT_DIR returns 404."""
    conv = await _create_test_conversation(test_session)
    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("safe.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    # Tamper storage_path in DB
    stmt = select(Attachment).where(Attachment.id == att_id)
    att = (await test_session.execute(stmt)).scalar_one()
    att.storage_path = "../../../secret_data.txt"
    await test_session.commit()

    res = await client.get(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}/preview",
        headers=auth_headers,
    )
    assert res.status_code == 404


# ===========================================================================
# 6. Delete Endpoint Tests
# ===========================================================================

@pytest.mark.asyncio
async def test_delete_attachment_success_204(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """DELETE /attachments/{id} sets is_deleted=True, sets deleted_at, and retains physical file."""
    conv = await _create_test_conversation(test_session)
    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("to_delete.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    del_res = await client.delete(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}",
        headers=auth_headers,
    )
    assert del_res.status_code == 204

    stmt = select(Attachment).where(Attachment.id == att_id)
    att = (await test_session.execute(stmt)).scalar_one()
    assert att.is_deleted is True
    assert att.deleted_at is not None

    # Physical file MUST still exist on disk (retention owns physical purge)
    disk_path = settings.COMPANION_DATA_ROOT / att.storage_path
    assert disk_path.exists()


@pytest.mark.asyncio
async def test_delete_subsequent_preview_returns_404(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Previewing an attachment after DELETE returns 404."""
    conv = await _create_test_conversation(test_session)
    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("del.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    await client.delete(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}",
        headers=auth_headers,
    )

    prev_res = await client.get(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}/preview",
        headers=auth_headers,
    )
    assert prev_res.status_code == 404


@pytest.mark.asyncio
async def test_delete_repeated_delete_returns_404(
    client: AsyncClient, auth_headers: dict, test_session: AsyncSession
):
    """Calling DELETE twice on the same attachment returns 404 on the second call."""
    conv = await _create_test_conversation(test_session)
    upload_res = await client.post(
        f"/api/v1/conversations/{conv.id}/attachments",
        files={"file": ("del2.png", _create_minimal_png(), "image/png")},
        headers=auth_headers,
    )
    att_id = upload_res.json()["id"]

    del1 = await client.delete(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}",
        headers=auth_headers,
    )
    assert del1.status_code == 204

    del2 = await client.delete(
        f"/api/v1/conversations/{conv.id}/attachments/{att_id}",
        headers=auth_headers,
    )
    assert del2.status_code == 404
