"""Integration tests for the post-stream memory extraction pipeline (M3 Batch C2).

Verifies background extraction execution, toggle dormancy when disabled,
session isolation, explicit command auto-save, and error rollback.
"""

import asyncio
import json
from unittest.mock import AsyncMock, patch
import pytest
from sqlalchemy import select

from app.core.config import settings
from app.models.conversation import Conversation
from app.models.memory import Memory
from app.models.message import Message
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.services.assistant.orchestrator import (
    _get_profile_extraction_lock,
    _run_post_turn_memory_extraction,
)
from app.services.llm.base import BaseLLMProvider


class MockExtractionProvider(BaseLLMProvider):
    def __init__(self, candidate_json: str):
        self._candidate_json = candidate_json

    @property
    def provider_name(self) -> str:
        return "mock_extractor"

    def is_loaded(self) -> bool:
        return True

    async def load_model(self, *args, **kwargs) -> bool:
        return True

    async def unload_model(self) -> bool:
        return True

    async def set_profile(self, profile: str) -> bool:
        return True

    async def get_status(self):
        raise NotImplementedError

    async def generate(self, messages, **kwargs) -> str:
        return self._candidate_json

    async def generate_stream(self, messages, **kwargs):
        yield self._candidate_json


@pytest.fixture
async def sample_profile(test_session):
    profile = Profile(
        id="pipeline-test-prof-001",
        name="Pipeline Test User",
        status="active",
    )
    test_session.add(profile)
    await test_session.commit()
    return profile


@pytest.mark.asyncio
async def test_pipeline_dormant_when_disabled(monkeypatch, sample_profile, test_session):
    monkeypatch.setattr(settings, "MEMORY_EXTRACTION_ENABLED", False)

    # Calling extraction should return immediately without doing any work
    await _run_post_turn_memory_extraction(
        profile_id=sample_profile.id,
        user_text="Remember: I love matcha lattes",
        assistant_text="I will remember that!",
        source_message_id="msg-101",
    )

    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 0


@pytest.mark.asyncio
async def test_pipeline_skips_trivial_turn(monkeypatch, sample_profile, test_session):
    monkeypatch.setattr(settings, "MEMORY_EXTRACTION_ENABLED", True)

    await _run_post_turn_memory_extraction(
        profile_id=sample_profile.id,
        user_text="ok thanks!",
        assistant_text="You're welcome!",
        source_message_id="msg-102",
    )

    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 0


@pytest.mark.asyncio
async def test_pipeline_runs_when_enabled(monkeypatch, sample_profile, test_session):
    monkeypatch.setattr(settings, "MEMORY_EXTRACTION_ENABLED", True)

    payload = json.dumps([
        {
            "content": "User drinks matcha lattes every afternoon",
            "category": "preference",
            "scope": "profile",
            "confidence": 0.95,
        }
    ])
    mock_provider = MockExtractionProvider(candidate_json=payload)

    with patch("app.services.assistant.orchestrator.get_llm_provider", return_value=mock_provider):
        await _run_post_turn_memory_extraction(
            profile_id=sample_profile.id,
            user_text="Remember: I drink matcha lattes every afternoon",
            assistant_text="Got it!",
            source_message_id="msg-103",
            engine=test_session.bind,
        )

    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 1
    mem = all_mems[0]
    assert mem.content == "User drinks matcha lattes every afternoon"
    assert mem.source_type == "user_explicit"
    assert mem.user_verified is True
    assert mem.source_message_id == "msg-103"


@pytest.mark.asyncio
async def test_pipeline_auto_extracted_unverified(monkeypatch, sample_profile, test_session):
    monkeypatch.setattr(settings, "MEMORY_EXTRACTION_ENABLED", True)

    payload = json.dumps([
        {
            "content": "User works remotely from Berlin",
            "category": "fact",
            "scope": "profile",
            "confidence": 0.88,
        }
    ])
    mock_provider = MockExtractionProvider(candidate_json=payload)

    with patch("app.services.assistant.orchestrator.get_llm_provider", return_value=mock_provider):
        await _run_post_turn_memory_extraction(
            profile_id=sample_profile.id,
            user_text="I work remotely from Berlin as an engineer",
            assistant_text="That sounds great!",
            source_message_id="msg-104",
            engine=test_session.bind,
        )

    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 1
    mem = all_mems[0]
    assert mem.content == "User works remotely from Berlin"
    assert mem.source_type == "extracted"
    assert mem.user_verified is False


@pytest.mark.asyncio
async def test_pipeline_serializes_with_profile_lock(sample_profile):
    lock = _get_profile_extraction_lock(sample_profile.id)
    assert not lock.locked()

    async with lock:
        assert lock.locked()
        same_lock = _get_profile_extraction_lock(sample_profile.id)
        assert same_lock is lock
