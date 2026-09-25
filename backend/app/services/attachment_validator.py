"""Service for validating image attachments according to Phase 8B contracts and security policies."""

import io
import warnings
from dataclasses import dataclass
from typing import Optional
from PIL import Image

from app.schemas.attachment import (
    ALLOWED_MIME_TYPES,
    MAX_MEGAPIXELS,
    MAX_PIXEL_DIMENSION,
    MAX_SIZE_BYTES,
)


@dataclass(frozen=True)
class ValidatedImageMetadata:
    """Metadata extracted and verified from valid image bytes."""
    mime_type: str
    size_bytes: int
    image_width: int
    image_height: int
    format: str


# ===========================================================================
# Exception Hierarchy
# ===========================================================================

class AttachmentValidationError(Exception):
    """Base exception for image attachment validation failures."""
    def __init__(self, message: str, code: str):
        super().__init__(message)
        self.message = message
        self.code = code


class ImageEmptyError(AttachmentValidationError):
    """Raised when uploaded image payload is 0 bytes or negative."""
    def __init__(self, message: str = "Image data cannot be empty"):
        super().__init__(message=message, code="IMAGE_EMPTY")


class ImageTooLargeError(AttachmentValidationError):
    """Raised when uploaded image exceeds MAX_SIZE_BYTES."""
    def __init__(
        self,
        size_bytes: int = 0,
        max_bytes: int = MAX_SIZE_BYTES,
        message: Optional[str] = None,
    ):
        self.size_bytes = size_bytes
        self.max_bytes = max_bytes
        msg = message or f"Image size {size_bytes} bytes exceeds maximum allowed {max_bytes} bytes"
        super().__init__(message=msg, code="IMAGE_TOO_LARGE")


class UnsupportedImageTypeError(AttachmentValidationError):
    """Raised when MIME type or image signature is not supported."""
    def __init__(self, message: str = "Unsupported image type"):
        super().__init__(message=message, code="UNSUPPORTED_IMAGE_TYPE")


class AnimatedImageNotSupportedError(AttachmentValidationError):
    """Raised when multi-frame or animated images (e.g. APNG, GIF) are uploaded."""
    def __init__(self, message: str = "Animated images are not supported in Phase 8B"):
        super().__init__(message=message, code="ANIMATED_IMAGE_NOT_SUPPORTED")


class ImageDimensionsTooLargeError(AttachmentValidationError):
    """Raised when pixel dimensions or total megapixels exceed maximum boundaries."""
    def __init__(
        self,
        message: str = "Image dimensions exceed allowed limits",
        width: Optional[int] = None,
        height: Optional[int] = None,
        megapixels: Optional[float] = None,
    ):
        self.width = width
        self.height = height
        self.megapixels = megapixels
        super().__init__(message=message, code="IMAGE_DIMENSIONS_TOO_LARGE")


class CorruptedImageDataError(AttachmentValidationError):
    """Raised when image bytes cannot be decoded or raster stream is truncated."""
    def __init__(self, message: str = "Corrupted or invalid image data"):
        super().__init__(message=message, code="CORRUPTED_IMAGE_DATA")


class DecompressionBombDetectedError(AttachmentValidationError):
    """Raised when an image triggers Pillow decompression bomb defenses."""
    def __init__(self, message: str = "Image exceeds decompression bomb thresholds"):
        super().__init__(message=message, code="DECOMPRESSION_BOMB_DETECTED")


# ===========================================================================
# Pure Helper Functions
# ===========================================================================

def check_image_size(size_bytes: int) -> None:
    """Validate raw image byte size against strict boundaries.

    - 0 or negative -> ImageEmptyError
    - 1 .. MAX_SIZE_BYTES -> allowed
    - > MAX_SIZE_BYTES -> ImageTooLargeError
    """
    if size_bytes <= 0:
        raise ImageEmptyError()
    if size_bytes > MAX_SIZE_BYTES:
        raise ImageTooLargeError(size_bytes=size_bytes, max_bytes=MAX_SIZE_BYTES)


def detect_image_mime(data: bytes) -> Optional[str]:
    """Detect image MIME type purely from byte signatures without inspecting filename or extension.

    - PNG: canonical 8-byte PNG signature b"\\x89PNG\\r\\n\\x1a\\n"
    - JPEG: starts with b"\\xff\\xd8\\xff"
    - WebP: begins with b"RIFF" and bytes 8:12 are b"WEBP"
    - Return None for unknown/unsupported formats.
    """
    if len(data) >= 8 and data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(data) >= 3 and data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp"
    return None


def check_image_dimensions(width: int, height: int) -> None:
    """Validate width, height, and megapixel bounds without requiring raster allocation.

    - width <= 0 or height <= 0 -> CorruptedImageDataError
    - side > 8192 px -> ImageDimensionsTooLargeError
    - total pixels > 32.0 MP -> ImageDimensionsTooLargeError
    """
    if width <= 0 or height <= 0:
        raise CorruptedImageDataError("Image dimensions must be positive integers")
    if width > MAX_PIXEL_DIMENSION:
        raise ImageDimensionsTooLargeError(
            f"Image width ({width}px) exceeds maximum allowed {MAX_PIXEL_DIMENSION}px",
            width=width,
            height=height,
        )
    if height > MAX_PIXEL_DIMENSION:
        raise ImageDimensionsTooLargeError(
            f"Image height ({height}px) exceeds maximum allowed {MAX_PIXEL_DIMENSION}px",
            width=width,
            height=height,
        )
    megapixels = (width * height) / 1_000_000.0
    if megapixels > MAX_MEGAPIXELS:
        raise ImageDimensionsTooLargeError(
            f"Image total pixels ({width}x{height} = {megapixels:.2f}MP) exceeds maximum allowed {MAX_MEGAPIXELS}MP",
            width=width,
            height=height,
            megapixels=megapixels,
        )


# ===========================================================================
# Main Image Validation
# ===========================================================================

def validate_image_bytes(data: bytes, filename: Optional[str] = None) -> ValidatedImageMetadata:
    """Validate raw image payload against Phase 8B security boundaries and decode integrity.

    Execution sequence:
    1. check_image_size(len(data))
    2. detect_image_mime(data) - rejects WebP with deferred message, rejects unknown MIME
    3. Pillow inspection in local warnings context:
       - checks format consistency
       - checks animation flags (rejects APNG)
       - check_image_dimensions(width, height)
       - img.verify()
       - reopen fresh BytesIO and img.load() to verify full raster stream integrity
    """
    # 1. Size checks
    check_image_size(len(data))

    # 2. Magic byte sniffing
    detected_mime = detect_image_mime(data)
    if detected_mime == "image/webp":
        raise UnsupportedImageTypeError("WebP images are deferred and not supported in Phase 8B")
    if not detected_mime or detected_mime not in ALLOWED_MIME_TYPES:
        raise UnsupportedImageTypeError(f"Unsupported image type: {detected_mime}")

    # 3. Decode & integrity verification
    with warnings.catch_warnings():
        warnings.filterwarnings("error", category=Image.DecompressionBombWarning)
        try:
            bio = io.BytesIO(data)
            img = Image.open(bio)

            fmt = (img.format or "").upper()
            if detected_mime == "image/png" and fmt != "PNG":
                raise UnsupportedImageTypeError(f"MIME detected as PNG but image format is {fmt}")
            if detected_mime == "image/jpeg" and fmt not in ("JPEG", "JPG"):
                raise UnsupportedImageTypeError(f"MIME detected as JPEG but image format is {fmt}")

            is_animated = getattr(img, "is_animated", False)
            n_frames = getattr(img, "n_frames", 1)
            if is_animated or n_frames > 1:
                raise AnimatedImageNotSupportedError("Animated images are not supported in Phase 8B")

            width, height = img.size
            check_image_dimensions(width, height)

            # verify() checks container structure without decompressing full raster
            img.verify()

            # Re-open stream to load raster data and catch truncated streams
            raster_bio = io.BytesIO(data)
            raster_img = Image.open(raster_bio)
            raster_img.load()

            return ValidatedImageMetadata(
                mime_type=detected_mime,
                size_bytes=len(data),
                image_width=width,
                image_height=height,
                format=fmt,
            )
        except AttachmentValidationError:
            raise
        except (Image.DecompressionBombError, Image.DecompressionBombWarning) as e:
            raise DecompressionBombDetectedError(f"Decompression bomb detected: {e}") from e
        except (SyntaxError, ValueError, OSError, EOFError) as e:
            raise CorruptedImageDataError(f"Corrupted or invalid image data: {e}") from e
