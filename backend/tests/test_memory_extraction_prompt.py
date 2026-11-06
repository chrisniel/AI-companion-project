"""Unit tests for the memory extraction prompt assembly, JSON parsing, and secret filtering (M3 Batch C2)."""

import json
from unittest.mock import AsyncMock, MagicMock
import pytest

from app.services.llm.base import BaseLLMProvider
from app.services.memory.extractor import (
    contains_secrets,
    extract_memory_candidates,
    MemoryCandidate,
)


class DummyLoadedProvider(BaseLLMProvider):
    def __init__(self, output_text: str = "[]", loaded: bool = True):
        self._output_text = output_text
        self._loaded = loaded

    @property
    def provider_name(self) -> str:
        return "dummy"

    def is_loaded(self) -> bool:
        return self._loaded

    async def load_model(self, *args, **kwargs) -> bool:
        return True

    async def unload_model(self) -> bool:
        return True

    async def set_profile(self, profile: str) -> bool:
        return True

    async def get_status(self):
        raise NotImplementedError

    async def generate(self, messages, **kwargs) -> str:
        return self._output_text

    async def generate_stream(self, messages, **kwargs):
        yield self._output_text


@pytest.mark.asyncio
async def test_extract_clean_json():
    json_payload = json.dumps([
        {
            "content": "User prefers oat milk over dairy in coffee",
            "category": "preference",
            "scope": "profile",
            "is_core": False,
            "expires_at": None,
            "confidence": 0.95,
        }
    ])
    provider = DummyLoadedProvider(output_text=json_payload, loaded=True)

    candidates = await extract_memory_candidates(
        user_text="I prefer oat milk over dairy in coffee",
        provider=provider,
    )
    assert len(candidates) == 1
    assert candidates[0].content == "User prefers oat milk over dairy in coffee"
    assert candidates[0].category == "preference"
    assert candidates[0].scope == "profile"
    assert candidates[0].is_core is False
    assert candidates[0].confidence == 0.95


@pytest.mark.asyncio
async def test_strip_markdown_code_fences():
    fenced_output = """```json
[
  {
    "content": "User has a golden retriever named Max",
    "category": "fact",
    "scope": "profile",
    "is_core": false,
    "confidence": 0.9
  }
]
```"""
    provider = DummyLoadedProvider(output_text=fenced_output, loaded=True)

    candidates = await extract_memory_candidates(
        user_text="My dog is a golden retriever named Max",
        provider=provider,
    )
    assert len(candidates) == 1
    assert candidates[0].content == "User has a golden retriever named Max"
    assert candidates[0].category == "fact"


@pytest.mark.asyncio
async def test_filter_secrets():
    assert contains_secrets("My password is: secret_pass_123!") is True
    assert contains_secrets("sk-123456789012345678901234567890") is True
    assert contains_secrets("User likes dark roast coffee") is False

    json_payload = json.dumps([
        {
            "content": "User secret api_key: sk-123456789012345678901234567890",
            "category": "fact",
            "scope": "profile",
            "confidence": 0.95,
        },
        {
            "content": "User loves chocolate ice cream",
            "category": "preference",
            "scope": "profile",
            "confidence": 0.9,
        },
    ])
    provider = DummyLoadedProvider(output_text=json_payload, loaded=True)

    candidates = await extract_memory_candidates(
        user_text="I like chocolate ice cream",
        provider=provider,
    )
    assert len(candidates) == 1
    assert candidates[0].content == "User loves chocolate ice cream"


@pytest.mark.asyncio
async def test_model_unloaded_preflight():
    provider = DummyLoadedProvider(output_text="[]", loaded=False)
    candidates = await extract_memory_candidates(
        user_text="I live in Tokyo",
        provider=provider,
    )
    assert candidates == []


@pytest.mark.asyncio
async def test_malformed_json_fallback():
    provider = DummyLoadedProvider(
        output_text="Sure! Here is what I extracted: [NOT VALID JSON}", loaded=True
    )
    candidates = await extract_memory_candidates(
        user_text="I work as a software engineer",
        provider=provider,
    )
    assert candidates == []


@pytest.mark.asyncio
async def test_explicit_command_confidence_boost():
    json_payload = json.dumps([
        {
            "content": "User lives in New York City",
            "category": "fact",
            "scope": "profile",
            "confidence": 0.75,
        }
    ])
    provider = DummyLoadedProvider(output_text=json_payload, loaded=True)

    candidates = await extract_memory_candidates(
        user_text="Remember: I live in New York City",
        provider=provider,
    )
    assert len(candidates) == 1
    assert candidates[0].confidence == 1.0


@pytest.mark.asyncio
async def test_candidate_max_limit_enforced():
    items = [
        {"content": f"User fact number {i}", "category": "fact", "confidence": 0.9}
        for i in range(10)
    ]
    provider = DummyLoadedProvider(output_text=json.dumps(items), loaded=True)

    candidates = await extract_memory_candidates(
        user_text="I love many things: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10",
        provider=provider,
    )
    assert len(candidates) == 3
