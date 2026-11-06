"""Unit tests for the deterministic slot reconciler (M3 Batch C2).

Verifies NEW, DUPLICATE, MERGE, UPDATE, and CONFLICT transitions,
scoping normalization, confidence thresholding, and touch semantics.
"""

from datetime import datetime, timezone
import pytest
from sqlalchemy import select

from app.models.memory import Memory
from app.models.profile import Profile
from app.services.memory.extractor import MemoryCandidate
from app.services.memory.reconciler import reconcile_candidate


@pytest.fixture
async def sample_profile(test_session):
    profile = Profile(
        id="reconcile-test-prof-001",
        name="Reconcile Test User",
        status="active",
    )
    test_session.add(profile)
    await test_session.commit()
    return profile


@pytest.mark.asyncio
async def test_reconcile_low_confidence_discarded(test_session, sample_profile):
    candidate = MemoryCandidate(
        content="User might like jazz music",
        category="preference",
        scope="profile",
        confidence=0.6,  # below 0.8
    )
    result = await reconcile_candidate(
        db=test_session,
        profile_id=sample_profile.id,
        candidate=candidate,
        source_type="extracted",
    )
    assert result is None
    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 0


@pytest.mark.asyncio
async def test_reconcile_low_confidence_explicit_persisted(test_session, sample_profile):
    candidate = MemoryCandidate(
        content="User loves jazz music",
        category="preference",
        scope="profile",
        confidence=0.6,
    )
    result = await reconcile_candidate(
        db=test_session,
        profile_id=sample_profile.id,
        candidate=candidate,
        source_type="user_explicit",
        user_verified=True,
    )
    assert result is not None
    assert result.content == "User loves jazz music"
    assert result.source_type == "user_explicit"
    assert result.user_verified is True


@pytest.mark.asyncio
async def test_reconcile_character_scope_normalization(test_session, sample_profile):
    candidate = MemoryCandidate(
        content="User plays guitar",
        category="fact",
        scope="character",  # character requested
        confidence=0.9,
    )
    # But active_character_instance_id is None!
    result = await reconcile_candidate(
        db=test_session,
        profile_id=sample_profile.id,
        candidate=candidate,
        active_character_instance_id=None,
    )
    assert result is not None
    assert result.scope == "profile"
    assert result.character_instance_id is None


@pytest.mark.asyncio
async def test_reconcile_slot_new(test_session, sample_profile):
    candidate = MemoryCandidate(
        content="User prefers oat milk over dairy in coffee",
        category="preference",
        scope="profile",
        confidence=0.9,
    )
    result = await reconcile_candidate(
        db=test_session,
        profile_id=sample_profile.id,
        candidate=candidate,
        source_message_id="msg-001",
    )
    assert result is not None
    assert result.content == "User prefers oat milk over dairy in coffee"
    assert result.source_type == "extracted"
    assert result.user_verified is False
    assert result.source_message_id == "msg-001"


@pytest.mark.asyncio
async def test_reconcile_slot_duplicate_touch(test_session, sample_profile):
    candidate1 = MemoryCandidate(
        content="User has a golden retriever named Max",
        category="fact",
        scope="profile",
        confidence=0.9,
    )
    mem1 = await reconcile_candidate(
        db=test_session,
        profile_id=sample_profile.id,
        candidate=candidate1,
    )
    assert mem1 is not None
    initial_verified_at = mem1.last_verified_at

    # Now exact duplicate candidate
    candidate2 = MemoryCandidate(
        content="User has a golden retriever named Max",
        category="fact",
        scope="profile",
        confidence=0.95,
    )
    mem2 = await reconcile_candidate(
        db=test_session,
        profile_id=sample_profile.id,
        candidate=candidate2,
    )
    assert mem2 is not None
    assert mem2.id == mem1.id  # Same record
    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 1  # No duplicate rows created!


@pytest.mark.asyncio
async def test_reconcile_slot_merge(test_session, sample_profile):
    # Existing basic fact
    cand1 = MemoryCandidate(
        content="User drinks coffee every morning",
        category="fact",
        scope="profile",
        confidence=0.9,
    )
    mem1 = await reconcile_candidate(db=test_session, profile_id=sample_profile.id, candidate=cand1)
    assert mem1 is not None

    # Candidate fact adds detail
    cand2 = MemoryCandidate(
        content="User drinks dark roast coffee with oat milk every morning",
        category="preference",
        scope="profile",
        confidence=0.92,
    )
    mem2 = await reconcile_candidate(db=test_session, profile_id=sample_profile.id, candidate=cand2)
    assert mem2 is not None
    assert mem2.id == mem1.id
    assert "dark roast coffee with oat milk" in mem2.content
    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 1


@pytest.mark.asyncio
async def test_reconcile_slot_update(test_session, sample_profile):
    cand1 = MemoryCandidate(
        content="User lives in Berlin",
        category="fact",
        scope="profile",
        confidence=0.9,
    )
    mem1 = await reconcile_candidate(db=test_session, profile_id=sample_profile.id, candidate=cand1)
    assert mem1 is not None

    cand2 = MemoryCandidate(
        content="User moved and now lives in Tokyo",
        category="fact",
        scope="profile",
        confidence=0.95,
    )
    mem2 = await reconcile_candidate(db=test_session, profile_id=sample_profile.id, candidate=cand2)
    assert mem2 is not None
    assert mem2.id == mem1.id
    assert "Tokyo" in mem2.content
    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 1


@pytest.mark.asyncio
async def test_reconcile_slot_conflict(test_session, sample_profile):
    cand1 = MemoryCandidate(
        content="User loves dark roast coffee",
        category="preference",
        scope="profile",
        confidence=0.9,
    )
    mem1 = await reconcile_candidate(db=test_session, profile_id=sample_profile.id, candidate=cand1)
    assert mem1 is not None

    # Directly contradictory candidate
    cand2 = MemoryCandidate(
        content="User hates coffee and dislikes the taste",
        category="preference",
        scope="profile",
        confidence=0.95,
    )
    mem2 = await reconcile_candidate(db=test_session, profile_id=sample_profile.id, candidate=cand2)
    assert mem2 is not None
    assert mem2.id != mem1.id  # Separate record preserved!
    assert mem2.source_type == "conflict"
    assert mem2.user_verified is False

    # Check both records exist in DB
    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 2
    contents = [m.content for m in all_mems]
    assert "User loves dark roast coffee" in contents
    assert "User hates coffee and dislikes the taste" in contents


@pytest.mark.asyncio
async def test_reconcile_slot_update_healing_cessation(test_session, sample_profile):
    cand1 = MemoryCandidate(
        content="User is allergic to shrimp",
        category="fact",
        scope="profile",
        confidence=0.9,
    )
    mem1 = await reconcile_candidate(db=test_session, profile_id=sample_profile.id, candidate=cand1)
    assert mem1 is not None

    cand2 = MemoryCandidate(
        content="User previously had a shrimp allergy but is now healed and no longer allergic to it.",
        category="fact",
        scope="profile",
        confidence=0.95,
    )
    mem2 = await reconcile_candidate(db=test_session, profile_id=sample_profile.id, candidate=cand2)
    assert mem2 is not None
    assert mem2.id == mem1.id  # Successfully updated existing row!
    assert "healed and no longer allergic" in mem2.content
    all_mems = (await test_session.scalars(select(Memory).where(Memory.profile_id == sample_profile.id))).all()
    assert len(all_mems) == 1

