"""Tests for Phase 8B.2: Attachment schemas, multimodal contracts, and image validation."""

import io
import pytest
from datetime import datetime, timezone
from pydantic import ValidationError
from PIL import Image

from app.schemas.attachment import (
    ALLOWED_MIME_TYPES,
    MAX_ATTACHMENTS_PER_MESSAGE,
    MAX_MEGAPIXELS,
    MAX_PIXEL_DIMENSION,
    MAX_SIZE_BYTES,
    AttachmentOut,
    AttachmentRef,
)
from app.schemas.multimodal import (
    ContentBlock,
    ImageAttachmentRef,
    ResolvedImageContent,
    TextContent,
)
from app.schemas.message import MessageOut, MessageSend
from app.schemas.llm import ChatMessage
from app.services.attachment_validator import (
    AnimatedImageNotSupportedError,
    AttachmentValidationError,
    CorruptedImageDataError,
    DecompressionBombDetectedError,
    ImageDimensionsTooLargeError,
    ImageEmptyError,
    ImageTooLargeError,
    UnsupportedImageTypeError,
    ValidatedImageMetadata,
    check_image_dimensions,
    check_image_size,
    detect_image_mime,
    validate_image_bytes,
)


# ===========================================================================
# 1. Pure Helper Tests: check_image_size
# ===========================================================================

def test_check_image_size_exact_boundary():
    """Exactly MAX_SIZE_BYTES (10,485,760 bytes) is permitted."""
    check_image_size(10 * 1024 * 1024)


def test_check_image_size_normal():
    """Normal positive size within limit is permitted."""
    check_image_size(500 * 1024)
    check_image_size(1)


def test_check_image_size_exceeded_by_one_byte():
    """MAX_SIZE_BYTES + 1 byte is rejected with ImageTooLargeError."""
    with pytest.raises(ImageTooLargeError) as exc_info:
        check_image_size(10 * 1024 * 1024 + 1)
    assert exc_info.value.code == "IMAGE_TOO_LARGE"
    assert exc_info.value.size_bytes == 10 * 1024 * 1024 + 1
    assert exc_info.value.max_bytes == 10 * 1024 * 1024


def test_check_image_size_empty_or_negative():
    """0 bytes and negative sizes are rejected with ImageEmptyError."""
    with pytest.raises(ImageEmptyError) as exc_info:
        check_image_size(0)
    assert exc_info.value.code == "IMAGE_EMPTY"

    with pytest.raises(ImageEmptyError):
        check_image_size(-10)


# ===========================================================================
# 2. Pure Helper Tests: check_image_dimensions
# ===========================================================================

def test_check_image_dimensions_normal():
    """Standard resolution images pass cleanly."""
    check_image_dimensions(1920, 1080)
    check_image_dimensions(1, 1)


def test_check_image_dimensions_exact_8192_allowed():
    """Exact 8192 pixel width/height is permitted if megapixel budget is satisfied."""
    # 8192 * 3900 = 31,948,800 pixels <= 32,000,000 pixels (32.0 MP)
    check_image_dimensions(8192, 3900)
    check_image_dimensions(3900, 8192)


def test_check_image_dimensions_width_8193_rejected():
    """Width of 8193 px is rejected even if total megapixels are small."""
    with pytest.raises(ImageDimensionsTooLargeError) as exc_info:
        check_image_dimensions(8193, 100)
    assert exc_info.value.code == "IMAGE_DIMENSIONS_TOO_LARGE"
    assert exc_info.value.width == 8193


def test_check_image_dimensions_height_8193_rejected():
    """Height of 8193 px is rejected even if total megapixels are small."""
    with pytest.raises(ImageDimensionsTooLargeError) as exc_info:
        check_image_dimensions(100, 8193)
    assert exc_info.value.code == "IMAGE_DIMENSIONS_TOO_LARGE"
    assert exc_info.value.height == 8193


def test_check_image_dimensions_exact_32_megapixels_allowed():
    """Exactly 32,000,000 pixels (32.0 MP) is permitted."""
    # 8000 * 4000 = 32,000,000 pixels
    check_image_dimensions(8000, 4000)


def test_check_image_dimensions_exceed_32_megapixels_rejected():
    """32,008,000 pixels (> 32.0 MP) is rejected even when sides are <= 8192."""
    # 8000 * 4001 = 32,008,000 pixels
    with pytest.raises(ImageDimensionsTooLargeError) as exc_info:
        check_image_dimensions(8000, 4001)
    assert exc_info.value.code == "IMAGE_DIMENSIONS_TOO_LARGE"
    assert exc_info.value.megapixels > 32.0


def test_check_image_dimensions_non_positive_rejected():
    """Non-positive dimensions are rejected as corrupted image data."""
    with pytest.raises(CorruptedImageDataError) as exc_info:
        check_image_dimensions(0, 100)
    assert exc_info.value.code == "CORRUPTED_IMAGE_DATA"

    with pytest.raises(CorruptedImageDataError):
        check_image_dimensions(100, -5)


# ===========================================================================
# 3. Pure Helper Tests: detect_image_mime
# ===========================================================================

def test_detect_image_mime_png():
    """Canonical 8-byte PNG signature returns image/png."""
    png_header = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
    assert detect_image_mime(png_header) == "image/png"


def test_detect_image_mime_jpeg():
    """Starting bytes b'\\xff\\xd8\\xff' return image/jpeg."""
    jpeg_header = b"\xff\xd8\xff\xe0\x00\x10JFIF"
    assert detect_image_mime(jpeg_header) == "image/jpeg"

    jpeg_exif = b"\xff\xd8\xff\xe1\x00\x22Exif"
    assert detect_image_mime(jpeg_exif) == "image/jpeg"


def test_detect_image_mime_webp():
    """RIFF + WEBP signature returns image/webp."""
    webp_header = b"RIFF\x24\x00\x00\x00WEBPVP8 "
    assert detect_image_mime(webp_header) == "image/webp"


def test_detect_image_mime_unknown_or_short():
    """Non-matching or short byte sequences return None."""
    assert detect_image_mime(b"") is None
    assert detect_image_mime(b"\x89PNG") is None  # Too short for 8-byte PNG header
    assert detect_image_mime(b"GIF89a\x01\x00") is None
    assert detect_image_mime(b"%PDF-1.4\n") is None
    assert detect_image_mime(b"Hello world, plain text") is None


# ===========================================================================
# 4. End-to-End Image Validation Tests: validate_image_bytes
# ===========================================================================

def _create_test_image(format: str, size=(64, 64), color="blue") -> bytes:
    """Helper to generate a minimal valid in-memory image byte stream."""
    img = Image.new("RGB", size, color=color)
    buf = io.BytesIO()
    img.save(buf, format=format)
    return buf.getvalue()


def test_validate_valid_png():
    """Valid in-memory PNG validates and returns correct metadata."""
    data = _create_test_image("PNG", size=(64, 48))
    meta = validate_image_bytes(data, filename="sample.png")
    assert isinstance(meta, ValidatedImageMetadata)
    assert meta.mime_type == "image/png"
    assert meta.format == "PNG"
    assert meta.image_width == 64
    assert meta.image_height == 48
    assert meta.size_bytes == len(data)


def test_validate_valid_jpeg():
    """Valid in-memory JPEG validates and returns correct metadata."""
    data = _create_test_image("JPEG", size=(80, 60))
    meta = validate_image_bytes(data, filename="sample.jpg")
    assert isinstance(meta, ValidatedImageMetadata)
    assert meta.mime_type == "image/jpeg"
    assert meta.format == "JPEG"
    assert meta.image_width == 80
    assert meta.image_height == 60
    assert meta.size_bytes == len(data)


def test_validate_webp_rejected_with_deferred_message():
    """Valid WebP image is rejected with explicit deferred status message."""
    img = Image.new("RGB", (32, 32), color="green")
    buf = io.BytesIO()
    img.save(buf, format="WEBP")
    webp_data = buf.getvalue()

    with pytest.raises(UnsupportedImageTypeError) as exc_info:
        validate_image_bytes(webp_data, filename="sample.webp")
    assert exc_info.value.code == "UNSUPPORTED_IMAGE_TYPE"
    assert "deferred" in exc_info.value.message.lower()


def test_validate_spoofed_extension_and_mime():
    """Text file named sample.png is rejected by signature sniffing."""
    spoofed = b"This is just plain text, not a PNG file at all!"
    with pytest.raises(UnsupportedImageTypeError) as exc_info:
        validate_image_bytes(spoofed, filename="sample.png")
    assert exc_info.value.code == "UNSUPPORTED_IMAGE_TYPE"


def test_validate_truncated_png_body_rejected():
    """PNG with valid 8-byte signature but truncated/garbage IDAT body is rejected."""
    corrupt_png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x10\x00\x00\x00\x10\x08\x02\x00\x00\x00corrupted_payload"
    with pytest.raises(CorruptedImageDataError) as exc_info:
        validate_image_bytes(corrupt_png, filename="corrupt.png")
    assert exc_info.value.code == "CORRUPTED_IMAGE_DATA"


def test_validate_truncated_jpeg_body_rejected():
    """JPEG with valid SOI marker but truncated stream is rejected."""
    corrupt_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xdb\x00corrupted"
    with pytest.raises(CorruptedImageDataError) as exc_info:
        validate_image_bytes(corrupt_jpeg, filename="corrupt.jpg")
    assert exc_info.value.code == "CORRUPTED_IMAGE_DATA"


def test_validate_animated_png_rejected():
    """Multi-frame PNG (APNG) is rejected for Phase 8B."""
    img1 = Image.new("RGBA", (32, 32), color="red")
    img2 = Image.new("RGBA", (32, 32), color="blue")
    buf = io.BytesIO()
    img1.save(buf, format="PNG", save_all=True, append_images=[img2])
    apng_data = buf.getvalue()

    with pytest.raises(AnimatedImageNotSupportedError) as exc_info:
        validate_image_bytes(apng_data, filename="anim.png")
    assert exc_info.value.code == "ANIMATED_IMAGE_NOT_SUPPORTED"
    assert "animated" in exc_info.value.message.lower()


def test_validate_decompression_bomb_rejected_locally():
    """Pillow decompression bomb is caught and normalized without mutating global settings."""
    original_max = Image.MAX_IMAGE_PIXELS
    data = _create_test_image("PNG", size=(64, 64))

    try:
        # Set a tiny temporary limit locally for testing
        Image.MAX_IMAGE_PIXELS = 100  # 64*64 = 4096 pixels > 100
        with pytest.raises(DecompressionBombDetectedError) as exc_info:
            validate_image_bytes(data, filename="bomb.png")
        assert exc_info.value.code == "DECOMPRESSION_BOMB_DETECTED"
    finally:
        # Guarantee restoration of global Pillow threshold
        Image.MAX_IMAGE_PIXELS = original_max

    # Confirm restoration
    assert Image.MAX_IMAGE_PIXELS == original_max


# ===========================================================================
# 5. Schema Contract Tests
# ===========================================================================

def test_attachment_out_forbids_storage_path():
    """AttachmentOut does not include storage_path and forbids extra fields."""
    assert "storage_path" not in AttachmentOut.model_fields
    assert "storage_filename" not in AttachmentOut.model_fields
    assert "owner_id" not in AttachmentOut.model_fields

    now = datetime.now(timezone.utc)
    valid_payload = {
        "id": "att-123",
        "conversation_id": "conv-456",
        "message_id": None,
        "filename_display": "photo.jpg",
        "mime_type": "image/jpeg",
        "size_bytes": 1024,
        "image_width": 1920,
        "image_height": 1080,
        "created_at": now,
    }
    obj = AttachmentOut(**valid_payload)
    assert obj.id == "att-123"

    # Attempting to supply storage_path must fail with extra="forbid"
    with pytest.raises(ValidationError):
        AttachmentOut(**{**valid_payload, "storage_path": "attachments/secret/path.jpg"})


def test_attachment_ref_fields():
    """AttachmentRef contains only lightweight public reference fields."""
    expected_fields = {"id", "filename_display", "mime_type", "size_bytes"}
    assert set(AttachmentRef.model_fields.keys()) == expected_fields


def test_multimodal_content_blocks():
    """Multimodal ContentBlock discriminated union parses TextContent and ResolvedImageContent."""
    text_data = {"type": "text", "text": "Describe this image"}
    text_block = TextContent(**text_data)
    assert text_block.type == "text"
    assert text_block.text == "Describe this image"

    img_data = {"type": "image_bytes", "mime_type": "image/png", "data": b"fake_png_bytes"}
    img_block = ResolvedImageContent(**img_data)
    assert img_block.type == "image_bytes"
    assert img_block.data == b"fake_png_bytes"

    # Test ImageAttachmentRef (used by orchestrator prior to byte resolution)
    ref = ImageAttachmentRef(attachment_id="att-99", mime_type="image/jpeg")
    assert ref.type == "image_attachment"
    assert ref.attachment_id == "att-99"
    assert "storage_path" not in ImageAttachmentRef.model_fields


def test_chat_message_multimodal_and_backward_compatibility():
    """ChatMessage supports both plain str content and List[ContentBlock]."""
    # 1. Backward-compatible text-only format
    msg_str = ChatMessage(role="user", content="Hello, companion!")
    assert msg_str.role == "user"
    assert msg_str.content == "Hello, companion!"

    # 2. Multimodal format
    blocks = [
        TextContent(text="Look at this:"),
        ResolvedImageContent(mime_type="image/png", data=b"PNG_BYTES"),
    ]
    msg_multi = ChatMessage(role="user", content=blocks)
    assert msg_multi.role == "user"
    assert isinstance(msg_multi.content, list)
    assert len(msg_multi.content) == 2
    assert msg_multi.content[0].type == "text"
    assert msg_multi.content[1].type == "image_bytes"


def test_message_send_and_out_attachment_fields():
    """MessageSend and MessageOut provide default empty attachment collections."""
    # MessageSend defaults attachment_ids to empty list
    send_default = MessageSend(user_text="What's on my schedule?")
    assert send_default.attachment_ids == []

    send_with_att = MessageSend(user_text="Schedule", attachment_ids=["att-1", "att-2"])
    assert send_with_att.attachment_ids == ["att-1", "att-2"]

    # MessageOut defaults attachments to empty list
    now = datetime.now(timezone.utc)
    out_default = MessageOut(
        id="m-1",
        conversation_id="c-1",
        sender="assistant",
        content="Here is your schedule",
        status="completed",
        sequence_no=1,
        created_at=now,
    )
    assert out_default.attachments == []

    ref = AttachmentRef(id="att-1", filename_display="diagram.png", mime_type="image/png", size_bytes=2048)
    out_with_att = MessageOut(
        id="m-2",
        conversation_id="c-1",
        sender="user",
        content="Here is the diagram",
        status="completed",
        sequence_no=2,
        created_at=now,
        attachments=[ref],
    )
    assert len(out_with_att.attachments) == 1
    assert out_with_att.attachments[0].id == "att-1"
