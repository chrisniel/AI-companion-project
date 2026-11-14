"""Unit and integration tests for Milestone M3 Batch E — Memory & Knowledge Architecture V2."""

from datetime import datetime, timedelta, timezone
import json
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.character_instance import CharacterInstance
from app.models.memory import Memory
from app.models.message import Message
from app.schemas.llm import ChatMessage
from app.services.assistant.orchestrator import _build_context, _estimate_tokens
from app.services.llm.mock import MockLLMProvider
from app.services.memory.extractor import MemoryCandidate, extract_memory_candidates
from app.services.memory.reconciler import reconcile_candidate
from app.services.memory.retriever import (
    get_active_short_term_memories,
    get_core_memories,
    get_triggered_knowledge,
    search_relevant_memories,
)
from tests.profile_helpers import session_for_owner


@pytest.mark.anyio
async def test_memory_tier_filtering_counts_and_trigger_keywords_crud(
    client: AsyncClient,
    auth_headers: dict,
):
    """CRUD and ?tier filtering separate knowledge, long_term, and short_term with accurate counts."""
    now = datetime.now(timezone.utc)

    # 1. Knowledge & Profile: pinned core + keyword lorebook
    res_core = await client.post(
        "/api/v1/memories",
        json={
            "content": "User prefers concise, honest answers.",
            "category": "preference",
            "is_core": True,
            "trigger_keywords": ["style", "Tone", "style"],
        },
        headers=auth_headers,
    )
    assert res_core.status_code == 201
    core_data = res_core.json()
    assert core_data["trigger_keywords"] == ["style", "tone"]
    assert core_data["recall_count"] == 0

    # 2. Long-Term Memory (created with user_explicit, non-core, permanent)
    res_lt = await client.post(
        "/api/v1/memories",
        json={
            "content": "User visited Osaka castle last spring.",
            "category": "fact",
            "source_type": "user_explicit",
            "is_core": False,
        },
        headers=auth_headers,
    )
    assert res_lt.status_code == 201
    lt_id = res_lt.json()["id"]

    # 3. Short-Term Context (72h TTL)
    res_st = await client.post(
        "/api/v1/memories",
        json={
            "content": "User is feeling exhausted from late-night debugging today.",
            "category": "context",
            "expires_at": (now + timedelta(hours=72)).isoformat(),
        },
        headers=auth_headers,
    )
    assert res_st.status_code == 201
    st_id = res_st.json()["id"]

    # Tier list filtering & profile-wide counts
    knowledge_res = await client.get("/api/v1/memories?tier=knowledge", headers=auth_headers)
    assert knowledge_res.status_code == 200
    k_body = knowledge_res.json()
    assert [m["id"] for m in k_body["items"]] == [core_data["id"]]
    assert k_body["knowledge_count"] == 1
    assert k_body["long_term_count"] == 1
    assert k_body["short_term_count"] == 1

    lt_res = await client.get("/api/v1/memories?tier=long_term", headers=auth_headers)
    assert [m["id"] for m in lt_res.json()["items"]] == [lt_id]

    st_res = await client.get("/api/v1/memories?tier=short_term", headers=auth_headers)
    assert [m["id"] for m in st_res.json()["items"]] == [st_id]

    # Promote Short-Term -> Long-Term via PATCH
    promote_res = await client.patch(
        f"/api/v1/memories/{st_id}",
        json={"expires_at": None, "category": "fact", "source_type": "user_explicit"},
        headers=auth_headers,
    )
    assert promote_res.status_code == 200
    assert promote_res.json()["expires_at"] is None
    assert promote_res.json()["category"] == "fact"

    lt_after = await client.get("/api/v1/memories?tier=long_term", headers=auth_headers)
    assert lt_after.json()["long_term_count"] == 2
    assert lt_after.json()["short_term_count"] == 0


@pytest.mark.anyio
async def test_extractor_assigns_deterministic_72h_ttl_and_explicit_intent_boost():
    """Context / temporal candidates get 72h TTL; explicit remember commands get verified + importance >= 1.5."""
    provider = MockLLMProvider()
    provider.is_loaded = lambda: True

    # 1. Situational context with null expires_at -> deterministic ~72h TTL
    async def mock_context_extract(**kwargs):
        return json.dumps([
            {
                "content": "User has a stressful presentation tonight",
                "category": "context",
                "scope": "profile",
                "is_core": False,
                "expires_at": None,
                "confidence": 0.9,
            }
        ])

    provider.generate = mock_context_extract
    before = datetime.now(timezone.utc)
    ctx_candidates = await extract_memory_candidates(
        user_text="I have a huge presentation tonight and feel nervous.",
        provider=provider,
    )
    assert len(ctx_candidates) == 1
    assert ctx_candidates[0].expires_at is not None
    ttl_hours = (ctx_candidates[0].expires_at - before).total_seconds() / 3600.0
    assert 71.5 <= ttl_hours <= 72.5

    # 2. Explicit "Remember that..." boosts verification and importance >= 1.5
    async def mock_explicit_extract(**kwargs):
        return json.dumps([
            {
                "content": "User is severely allergic to peanuts",
                "category": "fact",
                "scope": "profile",
                "is_core": False,
                "expires_at": None,
                "confidence": 0.85,
            }
        ])

    provider.generate = mock_explicit_extract
    exp_candidates = await extract_memory_candidates(
        user_text="Please remember that I am severely allergic to peanuts.",
        provider=provider,
    )
    assert len(exp_candidates) == 1
    assert exp_candidates[0].user_verified is True
    assert exp_candidates[0].importance >= 1.5
    assert exp_candidates[0].expires_at is None


@pytest.mark.anyio
async def test_reconciler_protects_fixed_knowledge_from_auto_overwrite(
    test_session: AsyncSession,
    profile_session,
):
    """Auto-extracted candidates must NEVER mutate is_core, manual, or lorebook fixed knowledge."""
    locked = Memory(
        id=str(uuid.uuid4()),
        profile_id=profile_session.profile_id,
        owner_id=profile_session.profile_id,
        category="fact",
        content="User works as a backend engineer in Manila",
        importance=1.6,
        source_type="manual",
        user_verified=True,
        scope="profile",
        is_core=True,
        trigger_keywords=json.dumps(["work", "manila"]),
    )
    test_session.add(locked)
    await test_session.commit()

    # Complementary or update-style auto-extracted candidate must NOT overwrite locked entry
    update_cand = MemoryCandidate(
        content="User works as a backend engineer now in Tokyo office",
        category="fact",
        scope="profile",
        confidence=0.92,
    )
    result = await reconcile_candidate(
        db=test_session,
        profile_id=profile_session.profile_id,
        candidate=update_cand,
        source_type="extracted",
    )
    await test_session.commit()
    await test_session.refresh(locked)

    assert locked.content == "User works as a backend engineer in Manila"
    assert locked.source_type == "manual"
    assert result is not None
    assert result.id != locked.id


@pytest.mark.anyio
async def test_reconciler_consolidates_and_promotes_recurring_short_term_memory(
    test_session: AsyncSession,
    profile_session,
):
    """Re-mentioning short-term context >12h later extends TTL first, then promotes to permanent."""
    now = datetime.now(timezone.utc)
    st_mem = Memory(
        id=str(uuid.uuid4()),
        profile_id=profile_session.profile_id,
        owner_id=profile_session.profile_id,
        category="context",
        content="User is practicing marathon running training",
        importance=0.9,
        source_type="extracted",
        user_verified=False,
        scope="profile",
        valid_from=now - timedelta(hours=20),
        last_verified_at=now - timedelta(hours=20),
        expires_at=now + timedelta(hours=52),
    )
    test_session.add(st_mem)
    await test_session.commit()

    cand = MemoryCandidate(
        content="User is practicing marathon running training",
        category="context",
        scope="profile",
        confidence=0.9,
        expires_at=now + timedelta(hours=72),
    )

    # First cross-session recurrence (>12h since valid_from) extends TTL ~72h from now
    reconciled_1 = await reconcile_candidate(
        db=test_session,
        profile_id=profile_session.profile_id,
        candidate=cand,
        source_type="extracted",
        now=now,
    )
    assert reconciled_1.id == st_mem.id
    assert reconciled_1.expires_at is not None
    exp_norm = reconciled_1.expires_at.replace(tzinfo=timezone.utc) if reconciled_1.expires_at.tzinfo is None else reconciled_1.expires_at
    assert (exp_norm - now).total_seconds() >= 70 * 3600

    # Second cross-session recurrence (last_verified_at is already >12h after valid_from) promotes to Long-Term
    later = now + timedelta(hours=16)
    reconciled_2 = await reconcile_candidate(
        db=test_session,
        profile_id=profile_session.profile_id,
        candidate=cand,
        source_type="extracted",
        now=later,
    )
    assert reconciled_2.id == st_mem.id
    assert reconciled_2.expires_at is None
    assert reconciled_2.category == "fact"


@pytest.mark.anyio
async def test_stem_aware_lorebook_triggers_and_recall_count_increment(
    test_session: AsyncSession,
    client: AsyncClient,
    auth_headers: dict,
    profile_session,
):
    """Keyword lorebook activates on stem/prefix matches; FTS retrieval uses prefix & increments recall_count."""
    res_lore = await client.post(
        "/api/v1/memories",
        json={
            "content": "Sarah loves handmade sourdough bread and spicy ramen.",
            "category": "fact",
            "trigger_keywords": ["sarah", "cook"],
        },
        headers=auth_headers,
    )
    assert res_lore.status_code == 201
    lore_id = res_lore.json()["id"]

    res_lt = await client.post(
        "/api/v1/memories",
        json={
            "content": "User enjoys baking cinnamon rolls on rainy Sundays.",
            "category": "preference",
            "source_type": "user_explicit",
        },
        headers=auth_headers,
    )
    assert res_lt.status_code == 201
    lt_id = res_lt.json()["id"]

    # Unrelated message must NOT activate dormant lorebook
    untriggered = await get_triggered_knowledge(
        db=test_session,
        profile_session=profile_session,
        query="What is the weather tomorrow?",
    )
    assert untriggered == []

    # Punctuation + stem match ("Sarah's" & "cooking" match triggers ["sarah", "cook"])
    triggered = await get_triggered_knowledge(
        db=test_session,
        profile_session=profile_session,
        query="I'm cooking dinner for Sarah's birthday tonight!",
        increment_recall=True,
    )
    assert [m.id for m in triggered] == [lore_id]
    assert triggered[0].recall_count == 1

    # FTS prefix match ("bak" matches "baking") and recall_count increment
    fts_hits = await search_relevant_memories(
        db=test_session,
        query="bak",
        profile_session=profile_session,
        increment_recall=True,
    )
    assert any(m.id == lt_id for m in fts_hits)
    refreshed_lt = await test_session.scalar(select(Memory).where(Memory.id == lt_id))
    assert refreshed_lt.recall_count >= 1


def test_build_context_outputs_four_semantic_xml_sections_within_budgets():
    """Prompt assembly partitions tiers into distinct XML tags within per-section token caps."""
    core = [
        Memory(id="c1", profile_id="p1", category="fact", content="User's name is Chris.", is_core=True, source_type="manual"),
    ]
    lore = [
        Memory(id="l1", profile_id="p1", category="fact", content="Project-X uses FastAPI and Flutter.", trigger_keywords='["project-x"]', source_type="manual"),
    ]
    long_term = [
        Memory(id="m1", profile_id="p1", category="preference", content="User prefers dark roast pour-over coffee.", source_type="extracted"),
    ]
    short_term = [
        Memory(id="s1", profile_id="p1", category="context", content="User is debugging local runtime today.", source_type="extracted", expires_at=datetime.now(timezone.utc) + timedelta(hours=24)),
    ]

    context = _build_context(
        history=[Message(profile_id="p1", sender="user", content="Hi!", sequence_no=1)],
        system_prompt="You are a warm companion.",
        user_text="How is Project-X going?",
        memories=long_term,
        core_memories=core,
        triggered_lore=lore,
        short_term_memories=short_term,
        context_capacity=2048,
        generation_reserve=256,
        memory_budget=600,
    )

    sys_content = context[0].content
    assert "<retrieved_memories>" in sys_content
    assert "<user_core_profile>" in sys_content
    assert "<triggered_knowledge_lore>" in sys_content
    assert "<episodic_and_long_term_memories>" in sys_content
    assert "<short_term_context>" in sys_content
    assert "User's name is Chris." in sys_content
    assert "Project-X uses FastAPI and Flutter." in sys_content
    assert "dark roast pour-over coffee" in sys_content
    assert "debugging local runtime today" in sys_content

    # Omitting triggered_lore omits <triggered_knowledge_lore> completely
    context_no_lore = _build_context(
        history=[],
        system_prompt="You are a warm companion.",
        user_text="Hello",
        memories=long_term,
        core_memories=core,
        triggered_lore=[],
        short_term_memories=[],
        context_capacity=2048,
    )
    assert "<triggered_knowledge_lore>" not in context_no_lore[0].content
    assert "<short_term_context>" not in context_no_lore[0].content


@pytest.mark.anyio
async def test_emotion_weighted_importance_boost_and_null_safe_extractor():
    """Distress/gratitude emotion events add +0.3 importance (clamped <= 2.0) and null/bad fields skip safely."""

    class _StubProvider:
        def __init__(self, payload: str):
            self.payload = payload

        def is_loaded(self) -> bool:
            return True

        async def generate(self, *args, **kwargs):
            return self.payload

    raw = json.dumps([
        {"category": "fact", "content": None, "confidence": 0.95},
        {"category": "fact", "content": "Bad confidence item", "confidence": "not-a-number"},
        {"category": "fact", "content": "User lost their job today and feels overwhelmed", "confidence": 0.9},
    ])
    provider = _StubProvider(raw)

    distress_candidates = await extract_memory_candidates(
        user_text="I lost my job today and I am really stressed",
        provider=provider,
        emotion_event="user_distress",
    )
    assert len(distress_candidates) == 1
    assert distress_candidates[0].content == "User lost their job today and feels overwhelmed"
    assert distress_candidates[0].importance == pytest.approx(1.2, abs=1e-4)

    explicit_clamped = await extract_memory_candidates(
        user_text="Remember that I love matcha lattes",
        provider=_StubProvider(json.dumps([
            {"category": "preference", "content": "Bad explicit importance", "importance": "bad-float"},
            {"category": "preference", "content": "User loves matcha lattes", "confidence": 0.95, "importance": 1.85},
        ])),
        emotion_event="user_gratitude",
    )
    assert len(explicit_clamped) == 1
    assert explicit_clamped[0].content == "User loves matcha lattes"
    # 1.85 + 0.3 clamps cleanly at 2.0
    assert explicit_clamped[0].importance == pytest.approx(2.0, abs=1e-4)

    neutral_candidates = await extract_memory_candidates(
        user_text="We were discussing my upcoming errands and appointments this Tuesday afternoon.",
        provider=_StubProvider(json.dumps([
            {"category": "fact", "content": "User has a dentist appointment Tuesday", "confidence": 0.9},
        ])),
        emotion_event="neutral_turn",
    )
    assert len(neutral_candidates) == 1
    assert neutral_candidates[0].importance == pytest.approx(0.9, abs=1e-4)


@pytest.mark.anyio
async def test_temporal_supersession_preserves_bounded_single_step_history(
    test_session: AsyncSession,
    profile_id: str,
):
    """Durable memory updates retain one bounded (previously: ... until YYYY-MM) clause without nesting."""
    session = await session_for_owner(test_session, "local_user")

    first = Memory(
        profile_id=session.profile_id,
        owner_id=session.profile_id,
        scope="profile",
        category="fact",
        content="User lives in Manila",
        importance=1.0,
        source_type="extracted",
        valid_from=datetime(2026, 9, 1, tzinfo=timezone.utc),
    )
    test_session.add(first)
    await test_session.flush()

    t1 = datetime(2026, 10, 15, tzinfo=timezone.utc)
    res1 = await reconcile_candidate(
        db=test_session,
        profile_id=session.profile_id,
        candidate=MemoryCandidate(
            category="fact",
            content="User lives in Tokyo",
            scope="profile",
            confidence=0.95,
            importance=1.0,
        ),
        source_type="extracted",
        now=t1,
    )
    assert res1.id == first.id
    assert first.content == "User lives in Tokyo (previously: User lives in Manila until 2026-10)"

    # Subsequent update replaces prior supersession clause instead of nesting infinitely
    t2 = datetime(2026, 11, 14, tzinfo=timezone.utc)
    res2 = await reconcile_candidate(
        db=test_session,
        profile_id=session.profile_id,
        candidate=MemoryCandidate(
            category="fact",
            content="User lives in Kyoto",
            scope="profile",
            confidence=0.95,
            importance=1.0,
        ),
        source_type="extracted",
        now=t2,
    )
    assert res2.id == first.id
    assert first.content == "User lives in Kyoto (previously: User lives in Tokyo until 2026-11)"
    assert first.content.count("(previously:") == 1


@pytest.mark.anyio
async def test_batch_e_hardening_fts_near_pre_slice_filtering_and_clear_expires_at(
    client: AsyncClient,
    auth_headers: dict,
    test_session: AsyncSession,
):
    """Verify Batch E review fixes: NEAR quoting, pre-slice exclude_ids/short_term, trigger_keywords guard, clear_expires_at."""
    session = await session_for_owner(test_session, "local_user")
    now = datetime.now(timezone.utc)

    core = Memory(
        profile_id=session.profile_id,
        scope="profile",
        category="fact",
        content="User lives near Tokyo station",
        is_core=True,
        source_type="manual",
        importance=1.5,
        valid_from=now,
    )
    lore_ctx = Memory(
        profile_id=session.profile_id,
        scope="profile",
        category="context",
        content="When Tokyo trip comes up, remind user about JR Pass",
        is_core=False,
        trigger_keywords=json.dumps(["tokyo"]),
        source_type="manual",
        importance=1.0,
        valid_from=now,
    )
    long_term = Memory(
        profile_id=session.profile_id,
        scope="profile",
        category="fact",
        content="User enjoys walking near Tokyo Imperial Palace",
        is_core=False,
        source_type="extracted",
        importance=1.0,
        valid_from=now,
    )
    short_term = Memory(
        profile_id=session.profile_id,
        scope="profile",
        category="context",
        content="User is near Tokyo airport right now",
        is_core=False,
        source_type="extracted",
        expires_at=now + timedelta(hours=24),
        importance=0.9,
        valid_from=now,
    )
    test_session.add_all([core, lore_ctx, long_term, short_term])
    await test_session.commit()
    core_id = core.id
    lore_ctx_id = lore_ctx.id
    long_term_id = long_term.id
    short_term_id = short_term.id
    prof_id = session.profile_id

    # 1. FTS query containing reserved word NEAR must not fail, and pre-slice exclusions skip recall_count increments
    hits = await search_relevant_memories(
        db=test_session,
        query="walking near Tokyo",
        profile_session=session,
        limit=5,
        increment_recall=True,
        exclude_ids={core_id, lore_ctx_id},
        exclude_short_term=True,
    )
    hit_ids = [m.id for m in hits]
    assert hit_ids == [long_term_id]

    test_session.expire_all()
    refreshed_core = await test_session.scalar(select(Memory).where(Memory.id == core_id))
    refreshed_st = await test_session.scalar(select(Memory).where(Memory.id == short_term_id))
    refreshed_lt = await test_session.scalar(select(Memory).where(Memory.id == long_term_id))
    assert refreshed_core.recall_count == 0
    assert refreshed_st.recall_count == 0
    assert refreshed_lt.recall_count == 1

    # 2. Keyword-triggered context memory without expires_at is NOT treated as ambient short-term context
    st_list = await get_active_short_term_memories(db=test_session, profile_id=prof_id, now=now)
    st_ids = {m.id for m in st_list}
    assert short_term_id in st_ids
    assert lore_ctx_id not in st_ids

    # 3. PATCH omitting expires_at preserves existing TTL; clear_expires_at: true promotes/clears TTL
    approve_res = await client.patch(
        f"/api/v1/memories/{short_term_id}",
        json={"user_verified": True},
        headers=auth_headers,
    )
    assert approve_res.status_code == 200
    assert approve_res.json()["expires_at"] is not None

    promote_res = await client.patch(
        f"/api/v1/memories/{short_term_id}",
        json={"clear_expires_at": True, "category": "fact", "source_type": "user_explicit"},
        headers=auth_headers,
    )
    assert promote_res.status_code == 200
    assert promote_res.json()["expires_at"] is None
