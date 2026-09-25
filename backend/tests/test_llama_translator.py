"""Unit tests for llama.cpp message translation layer in Phase 8B.5."""

import base64
from typing import Any
import pytest

from app.schemas.llm import ChatMessage
from app.schemas.multimodal import ResolvedImageContent, TextContent
from app.services.llm.llama_cpp import LlamaCppProvider, _translate_messages


def test_translate_plain_string_content_preserved():
    """Plain string content passes through unchanged as role + content."""
    messages = [
        ChatMessage(role="system", content="You are an assistant."),
        ChatMessage(role="user", content="Hello world"),
    ]
    wire = _translate_messages(messages)
    assert len(wire) == 2
    assert wire[0] == {"role": "system", "content": "You are an assistant."}
    assert wire[1] == {"role": "user", "content": "Hello world"}


def test_translate_text_content_block_to_wire_dict():
    """TextContent block converts to {'type': 'text', 'text': ...}."""
    messages = [
        ChatMessage(role="user", content=[TextContent(type="text", text="Just text")])
    ]
    wire = _translate_messages(messages)
    assert len(wire) == 1
    assert wire[0]["role"] == "user"
    assert wire[0]["content"] == [{"type": "text", "text": "Just text"}]


def test_translate_png_bytes_to_nested_image_url_data_uri():
    """ResolvedImageContent PNG bytes translate to nested image_url data URI."""
    raw_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00testpngdata"
    messages = [
        ChatMessage(
            role="user",
            content=[
                ResolvedImageContent(type="image_bytes", mime_type="image/png", data=raw_bytes)
            ],
        )
    ]
    wire = _translate_messages(messages)
    assert len(wire) == 1
    content = wire[0]["content"]
    assert len(content) == 1
    assert content[0]["type"] == "image_url"
    url = content[0]["image_url"]["url"]
    assert url.startswith("data:image/png;base64,")
    b64_part = url.split("data:image/png;base64,")[1]
    assert base64.b64decode(b64_part) == raw_bytes


def test_translate_jpeg_bytes_to_nested_image_url_data_uri():
    """ResolvedImageContent JPEG bytes translate to nested image_url data URI."""
    raw_bytes = b"\xff\xd8\xff\xe0testjpegdata"
    messages = [
        ChatMessage(
            role="user",
            content=[
                ResolvedImageContent(type="image_bytes", mime_type="image/jpeg", data=raw_bytes)
            ],
        )
    ]
    wire = _translate_messages(messages)
    url = wire[0]["content"][0]["image_url"]["url"]
    assert url.startswith("data:image/jpeg;base64,")
    b64_part = url.split("data:image/jpeg;base64,")[1]
    assert base64.b64decode(b64_part) == raw_bytes


def test_translate_base64_payload_round_trip():
    """Base64 payload encoded by translator round-trips exactly to input bytes."""
    data = b"RoundTripPayloadWithBinary\x00\xff\xfe\x01\x10"
    messages = [
        ChatMessage(
            role="user",
            content=[ResolvedImageContent(type="image_bytes", mime_type="image/png", data=data)],
        )
    ]
    wire = _translate_messages(messages)
    url = wire[0]["content"][0]["image_url"]["url"]
    encoded = url.replace("data:image/png;base64,", "")
    assert base64.b64decode(encoded) == data


def test_translate_base64_has_no_newlines_or_whitespace():
    """Base64 string must not contain newlines or whitespace characters."""
    large_data = b"A" * 5000  # Large enough that mime-encoding might split lines if wrapped
    messages = [
        ChatMessage(
            role="user",
            content=[ResolvedImageContent(type="image_bytes", mime_type="image/png", data=large_data)],
        )
    ]
    wire = _translate_messages(messages)
    url = wire[0]["content"][0]["image_url"]["url"]
    encoded = url.replace("data:image/png;base64,", "")
    assert "\n" not in encoded
    assert "\r" not in encoded
    assert " " not in encoded


def test_translate_preserves_content_block_ordering():
    """Ordering of mixed text and image content blocks is strictly preserved."""
    img1 = ResolvedImageContent(type="image_bytes", mime_type="image/png", data=b"img1")
    txt1 = TextContent(type="text", text="Before image")
    img2 = ResolvedImageContent(type="image_bytes", mime_type="image/jpeg", data=b"img2")
    txt2 = TextContent(type="text", text="After image")

    messages = [ChatMessage(role="user", content=[txt1, img1, img2, txt2])]
    wire = _translate_messages(messages)
    parts = wire[0]["content"]
    assert len(parts) == 4
    assert parts[0]["type"] == "text"
    assert parts[0]["text"] == "Before image"
    assert parts[1]["type"] == "image_url"
    assert parts[2]["type"] == "image_url"
    assert parts[3]["type"] == "text"
    assert parts[3]["text"] == "After image"


def test_translate_multiple_images_preserved():
    """Multiple images in single turn are preserved in sequence."""
    img_blocks = [
        ResolvedImageContent(type="image_bytes", mime_type="image/png", data=f"img_{i}".encode())
        for i in range(4)
    ]
    messages = [ChatMessage(role="user", content=img_blocks)]
    wire = _translate_messages(messages)
    parts = wire[0]["content"]
    assert len(parts) == 4
    for i, p in enumerate(parts):
        assert p["type"] == "image_url"
        b64 = p["image_url"]["url"].split("base64,")[1]
        assert base64.b64decode(b64) == f"img_{i}".encode()


def test_translate_unsupported_mime_raises_value_error():
    """Unsupported image MIME (e.g. image/webp, image/gif) raises ValueError."""
    messages = [
        ChatMessage(
            role="user",
            content=[
                ResolvedImageContent(type="image_bytes", mime_type="image/webp", data=b"webpdata")
            ],
        )
    ]
    with pytest.raises(ValueError, match="Unsupported image MIME type"):
        _translate_messages(messages)


def test_translate_unsupported_content_block_type_raises_type_error():
    """Unexpected block object raises TypeError."""
    class DummyUnknownBlock:
        type = "unknown_block"

    messages = [ChatMessage.model_construct(role="user", content=[DummyUnknownBlock()])]
    with pytest.raises(TypeError, match="Unsupported content block type"):
        _translate_messages(messages)


def test_translate_unsupported_message_content_type_raises_type_error():
    """Message content that is neither str nor list raises TypeError."""
    messages = [ChatMessage.model_construct(role="user", content=12345)]
    with pytest.raises(TypeError, match="Unsupported message content type"):
        _translate_messages(messages)


@pytest.mark.anyio
async def test_sync_generate_translation_failure_resets_generation_active():
    """If _translate_messages raises during sync generate, _generation_active remains False."""
    provider = LlamaCppProvider()
    assert provider._generation_active is False

    invalid_messages = [
        ChatMessage(
            role="user",
            content=[
                ResolvedImageContent(type="image_bytes", mime_type="image/webp", data=b"webpdata")
            ],
        )
    ]

    with pytest.raises(ValueError):
        await provider.generate(invalid_messages)

    assert provider._generation_active is False


@pytest.mark.anyio
async def test_stream_generate_translation_failure_resets_generation_active():
    """If _translate_messages raises during generate_stream, _generation_active remains False."""
    provider = LlamaCppProvider()
    assert provider._generation_active is False

    invalid_messages = [
        ChatMessage(
            role="user",
            content=[
                ResolvedImageContent(type="image_bytes", mime_type="image/webp", data=b"webpdata")
            ],
        )
    ]

    with pytest.raises(ValueError):
        async for _ in provider.generate_stream(invalid_messages):
            pass

    assert provider._generation_active is False
