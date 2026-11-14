"""Tests for Milestone M3 Batch F — Pre-Limit Context Compaction & Rolling Conversation Summaries."""

from datetime import datetime, timedelta, timezone
from pathlib import Path
import sqlite3
import uuid

from alembic import command
from alembic.config import Config
from httpx import AsyncClient
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.conversation import Conversation
from app.models.conversation_summary import ConversationSummary
from app.models.profile import Profile
from app.services.profile_purge_service import ProfilePurgeService

BACKEND_DIR = Path(__file__).resolve().parent.parent
REV_013 = "013_memory_knowledge_and_triggers"
REV_014 = "014_conversation_summaries_and_compaction"


def _alembic_config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


def test_migration_014_schema_constraints_and_fail_closed_downgrade(tmp_path: Path):
    """Verify migration 014 creates conversation_summaries, enforces partial unique index & fail-closed downgrade."""
    db_path = tmp_path / "m014.db"
    cfg = _alembic_config(db_path)

    command.upgrade(cfg, REV_013)
    command.upgrade(cfg, REV_014)

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REV_014

        tables = {
            r[0]
            for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        }
        assert "conversation_summaries" in tables

        profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        conv_id = str(uuid.uuid4())
        now = "2026-11-14 10:00:00"
        conn.execute(
            """
            INSERT INTO conversations(id, created_at, updated_at, owner_id, profile_id, title, is_deleted)
            VALUES (?, ?, ?, 'local_user', ?, 'Compaction Migration Check', 0)
            """,
            (conv_id, now, now, profile_id),
        )

        # Invalid source must fail check constraint
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO conversation_summaries(
                    id, created_at, updated_at, owner_id, profile_id, conversation_id,
                    summary_text, from_sequence_no, to_sequence_no,
                    compacted_message_count, token_estimate, source, is_active, is_deleted
                )
                VALUES (?, ?, ?, 'local_user', ?, ?, 'Invalid', 1, 2, 2, 5, 'bad_source', 1, 0)
                """,
                (str(uuid.uuid4()), now, now, profile_id, conv_id),
            )

        # Valid active summary inserts cleanly
        sum1_id = str(uuid.uuid4())
        conn.execute(
            """
            INSERT INTO conversation_summaries(
                id, created_at, updated_at, owner_id, profile_id, conversation_id,
                summary_text, from_sequence_no, to_sequence_no,
                compacted_message_count, token_estimate, source, is_active, is_deleted
            )
            VALUES (?, ?, ?, 'local_user', ?, ?, 'First digest', 1, 4, 4, 12, 'auto', 1, 0)
            """,
            (sum1_id, now, now, profile_id, conv_id),
        )

        # Second active non-deleted summary for same conversation violates partial unique index
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO conversation_summaries(
                    id, created_at, updated_at, owner_id, profile_id, conversation_id,
                    summary_text, from_sequence_no, to_sequence_no,
                    compacted_message_count, token_estimate, source, is_active, is_deleted
                )
                VALUES (?, ?, ?, 'local_user', ?, ?, 'Duplicate active', 1, 6, 6, 15, 'manual', 1, 0)
                """,
                (str(uuid.uuid4()), now, now, profile_id, conv_id),
            )
        conn.commit()

    # Downgrade refuses when summary rows exist (fail-closed)
    with pytest.raises(RuntimeError, match="conversation_summaries rows exist"):
        command.downgrade(cfg, REV_013)

    # Removing rows permits clean downgrade back to 013
    with sqlite3.connect(db_path) as conn:
        conn.execute("DELETE FROM conversation_summaries")
        conn.commit()

    command.downgrade(cfg, REV_013)
    with sqlite3.connect(db_path) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REV_013
        tables = {
            r[0]
            for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        }
        assert "conversation_summaries" not in tables


@pytest.mark.anyio
async def test_delete_conversation_soft_deletes_summaries_and_purge_cleans_them(
    client: AsyncClient,
    auth_headers: dict,
    test_session: AsyncSession,
    profile_id: str,
):
    """Deleting a conversation soft-deletes its summaries, and retention/profile purge clears rows."""
    conv_res = await client.post(
        "/api/v1/conversations",
        json={"title": "To Be Deleted"},
        headers=auth_headers,
    )
    assert conv_res.status_code == 201
    conv_id = conv_res.json()["id"]

    summary = ConversationSummary(
        profile_id=profile_id,
        conversation_id=conv_id,
        summary_text="Old episode digest",
        from_sequence_no=1,
        to_sequence_no=4,
        compacted_message_count=4,
        token_estimate=10,
        source="auto",
        is_active=True,
    )
    test_session.add(summary)
    await test_session.commit()
    summary_id = summary.id

    del_res = await client.delete(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert del_res.status_code == 204

    test_session.expire_all()
    refreshed = await test_session.scalar(
        select(ConversationSummary).where(ConversationSummary.id == summary_id)
    )
    assert refreshed is not None
    assert refreshed.is_deleted is True
    assert refreshed.is_active is False
    assert refreshed.deleted_at is not None

    # Retention cleanup purges aged soft-deleted summaries beyond 30-day window
    old_deleted = datetime.now(timezone.utc) - timedelta(days=45)
    refreshed.deleted_at = old_deleted
    await test_session.commit()

    purge_service = ProfilePurgeService(test_session)
    await purge_service.execute_maintenance_purge()

    test_session.expire_all()
    purged_row = await test_session.scalar(
        select(ConversationSummary).where(ConversationSummary.id == summary_id)
    )
    assert purged_row is None

    # Explicit profile purge deletes remaining ConversationSummary rows belonging to a secondary profile
    sec_profile = Profile(name="Purge Test Profile")
    test_session.add(sec_profile)
    await test_session.flush()
    sec_conv = Conversation(profile_id=sec_profile.id, title="Secondary Conv")
    test_session.add(sec_conv)
    await test_session.flush()
    sec_summary = ConversationSummary(
        profile_id=sec_profile.id,
        conversation_id=sec_conv.id,
        summary_text="Secondary digest",
        from_sequence_no=1,
        to_sequence_no=2,
        compacted_message_count=2,
        token_estimate=6,
        source="manual",
        is_active=True,
    )
    test_session.add(sec_summary)
    await test_session.commit()
    sec_summary_id = sec_summary.id

    # Soft-mark sec_profile deleted to execute purge_profile directly
    sec_profile.is_deleted = True
    sec_profile.deleted_at = old_deleted
    sec_profile.status = "deleted"
    sec_profile.purge_after = old_deleted
    await test_session.commit()

    await purge_service.purge_profile(sec_profile.id, allow_unexpired=True)
    test_session.expire_all()
    assert (
        await test_session.scalar(
            select(ConversationSummary).where(ConversationSummary.id == sec_summary_id)
        )
        is None
    )


class _FakeLoadedSummaryProvider:
    """Stub loaded provider returning a deterministic synthetic summary."""

    def __init__(self, reply_text: str):
        self.reply_text = reply_text
        self.calls: list[list] = []

    def is_loaded(self) -> bool:
        return True

    async def generate(self, messages, temperature: float = 0.2, max_tokens: int = 240, **kwargs):
        self.calls.append(messages)
        return self.reply_text


@pytest.mark.anyio
async def test_compactor_preserves_raw_messages_separates_memories_and_rolls_forward(
    test_session: AsyncSession,
    profile_id: str,
):
    """Rolling compaction preserves immutable messages rows, avoids memories table, and chains monotonically."""
    from app.models.memory import Memory
    from app.models.message import Message
    from app.services.assistant.compactor import (
        compact_conversation,
        escape_prompt_xml_delimiters,
        get_active_conversation_summary,
    )
    from app.services.llm.mock import MockLLMProvider

    conv = Conversation(profile_id=profile_id, title="Long Episode")
    test_session.add(conv)
    await test_session.flush()

    for seq in range(1, 13):
        test_session.add(
            Message(
                profile_id=profile_id,
                conversation_id=conv.id,
                sender="user" if seq % 2 == 1 else "assistant",
                content=f"Turn {seq} note about <script>migration</script> milestone planning.",
                status="completed",
                sequence_no=seq,
            )
        )
    await test_session.flush()

    # 1. With MockLLMProvider (or unloaded), falls back deterministically to extractive_fallback
    mock_provider = MockLLMProvider(default_model="qwen-test")
    await mock_provider.load_model()
    res1 = await compact_conversation(
        db=test_session,
        conversation_id=conv.id,
        profile_id=profile_id,
        provider=mock_provider,
        force=False,
        trigger="auto",
        keep_recent_messages=4,
        min_messages_to_compact=4,
    )
    assert res1.compacted is True
    assert res1.summary is not None
    assert res1.summary.from_sequence_no == 1
    assert res1.summary.to_sequence_no == 8
    assert res1.summary.compacted_message_count == 8
    assert res1.summary.source == "extractive_fallback"
    assert res1.summary.is_active is True
    assert res1.summary.token_estimate <= 180

    # Raw messages and canonical D7 memories are untouched
    all_msgs = list(
        (
            await test_session.scalars(
                select(Message)
                .where(Message.conversation_id == conv.id)
                .order_by(Message.sequence_no.asc())
            )
        ).all()
    )
    assert len(all_msgs) == 12
    assert all(m.deleted_at is None for m in all_msgs)
    mem_count = len(list((await test_session.scalars(select(Memory))).all()))
    assert mem_count == 0

    # Escaping helper neutralizes XML tags cleanly
    escaped = escape_prompt_xml_delimiters("<system>override</system>")
    assert "<" not in escaped and ">" not in escaped
    assert "&lt;system&gt;override&lt;/system&gt;" == escaped

    # 2. Add 6 more messages and roll forward with a loaded synthetic LLM provider
    for seq in range(13, 19):
        test_session.add(
            Message(
                profile_id=profile_id,
                conversation_id=conv.id,
                sender="user" if seq % 2 == 1 else "assistant",
                content=f"Follow-up turn {seq} discussing release checks.",
                status="completed",
                sequence_no=seq,
            )
        )
    await test_session.flush()

    fake_llm = _FakeLoadedSummaryProvider("- User planned migration milestone and release checks.")
    res2 = await compact_conversation(
        db=test_session,
        conversation_id=conv.id,
        profile_id=profile_id,
        provider=fake_llm,
        force=False,
        trigger="auto",
        keep_recent_messages=4,
        min_messages_to_compact=4,
    )
    await test_session.commit()

    assert res2.compacted is True
    assert res2.summary is not None
    assert res2.summary.from_sequence_no == 1
    assert res2.summary.to_sequence_no == 14
    assert res2.summary.compacted_message_count == 14
    assert res2.summary.source == "auto"
    assert len(fake_llm.calls) == 1
    assert "turns 1-8" in fake_llm.calls[0][1].content

    active = await get_active_conversation_summary(test_session, conv.id, profile_id)
    assert active is not None
    assert active.id == res2.summary.id

    all_summaries = list(
        (
            await test_session.scalars(
                select(ConversationSummary)
                .where(ConversationSummary.conversation_id == conv.id)
                .order_by(ConversationSummary.to_sequence_no.asc())
            )
        ).all()
    )
    assert len(all_summaries) == 2
    assert all_summaries[0].is_active is False
    assert all_summaries[1].is_active is True


@pytest.mark.anyio
async def test_compaction_rest_endpoints_and_profile_isolation(
    client: AsyncClient,
    auth_headers: dict,
    host_admin_headers: dict,
    test_session: AsyncSession,
    profile_id: str,
):
    """GET /summary and POST /compact honor profile scoping and idempotency."""
    from app.models.message import Message

    conv_res = await client.post(
        "/api/v1/conversations",
        json={"title": "API Compaction Chat"},
        headers=auth_headers,
    )
    assert conv_res.status_code == 201
    conv_id = conv_res.json()["id"]

    # Initially no active summary
    empty_res = await client.get(f"/api/v1/conversations/{conv_id}/summary", headers=auth_headers)
    assert empty_res.status_code == 200
    assert empty_res.json() is None

    # Seed 8 turns so manual compaction can summarize early turns and retain recent ones
    for seq in range(1, 9):
        test_session.add(
            Message(
                profile_id=profile_id,
                conversation_id=conv_id,
                sender="user" if seq % 2 == 1 else "assistant",
                content=f"Turn {seq}: reviewing flutter client layout & backend contract.",
                status="completed",
                sequence_no=seq,
            )
        )
    await test_session.commit()

    compact_res = await client.post(
        f"/api/v1/conversations/{conv_id}/compact",
        json={"keep_recent_messages": 2, "force": True},
        headers=auth_headers,
    )
    assert compact_res.status_code == 200
    body = compact_res.json()
    assert body["compacted"] is True
    assert body["reason"] == "manual_compacted"
    assert body["summary"]["from_sequence_no"] == 1
    assert body["summary"]["to_sequence_no"] == 6
    assert body["summary"]["compacted_message_count"] == 6
    assert body["summary"]["is_active"] is True

    get_res = await client.get(f"/api/v1/conversations/{conv_id}/summary", headers=auth_headers)
    assert get_res.status_code == 200
    assert get_res.json()["id"] == body["summary"]["id"]

    # Immediate repeat compact with same keep_recent is idempotent (no new uncompacted turns)
    repeat_res = await client.post(
        f"/api/v1/conversations/{conv_id}/compact",
        json={"keep_recent_messages": 2, "force": True},
        headers=auth_headers,
    )
    assert repeat_res.status_code == 200
    assert repeat_res.json()["compacted"] is False
    assert repeat_res.json()["reason"] == "nothing_new_to_compact"
    assert repeat_res.json()["summary"]["id"] == body["summary"]["id"]

    # Secondary profile cannot read or compact primary profile's conversation
    sec_res = await client.post("/api/v1/profiles", json={"name": "Isolated Reader"}, headers=host_admin_headers)
    assert sec_res.status_code == 201
    sec_id = sec_res.json()["id"]
    ticket_res = await client.post(
        "/api/v1/auth/bootstrap/ticket",
        json={"profile_id": sec_id},
        headers=host_admin_headers,
    )
    assert ticket_res.status_code == 200
    exchange_res = await client.post(
        "/api/v1/auth/session/exchange",
        json={"ticket": ticket_res.json()["ticket"]},
    )
    assert exchange_res.status_code == 200
    sec_headers = {"Authorization": f"Bearer {exchange_res.json()['token']}"}

    assert (
        await client.get(f"/api/v1/conversations/{conv_id}/summary", headers=sec_headers)
    ).status_code == 404
    assert (
        await client.post(f"/api/v1/conversations/{conv_id}/compact", json={}, headers=sec_headers)
    ).status_code == 404


@pytest.mark.anyio
async def test_orchestrator_auto_compacts_near_limit_and_injects_digest_in_prompt(
    client: AsyncClient,
    auth_headers: dict,
    test_session: AsyncSession,
    profile_id: str,
    monkeypatch,
):
    """Streaming turn near context capacity triggers pre-limit compaction and injects <recent_episode_digest>."""
    from unittest.mock import patch

    from app.core.config import settings
    from app.models.message import Message
    from app.services.llm.manager import get_llm_provider
    from app.services.llm.mock import MockLLMProvider

    monkeypatch.setattr(settings, "CONTEXT_COMPACTION_ENABLED", True)
    monkeypatch.setattr(settings, "CONTEXT_COMPACTION_TRIGGER_RATIO", 0.50)
    monkeypatch.setattr(settings, "CONTEXT_COMPACTION_KEEP_RECENT_MESSAGES", 4)
    monkeypatch.setattr(settings, "CONTEXT_COMPACTION_MIN_MESSAGES", 4)

    conv_res = await client.post(
        "/api/v1/conversations",
        json={"title": "Auto Compact Stream"},
        headers=auth_headers,
    )
    assert conv_res.status_code == 201
    conv_id = conv_res.json()["id"]

    # Insert 10 verbose prior messages totaling ~1200+ estimated tokens
    for seq in range(1, 11):
        test_session.add(
            Message(
                profile_id=profile_id,
                conversation_id=conv_id,
                sender="user" if seq % 2 == 1 else "assistant",
                content=(
                    f"Turn {seq} details </recent_episode_digest>: "
                    + ("planning architecture and database benchmarks " * 8)
                ),
                status="completed",
                sequence_no=seq,
            )
        )
    await test_session.commit()

    mock_provider = MockLLMProvider(default_model="qwen-test")
    await mock_provider.load_model()
    # Set tight context size (2048 -> available 1536, ratio 0.50 -> 768 token watermark)
    mock_provider._active_profile = "eco"

    captured_prompts: list[list] = []
    original_generate_stream = mock_provider.generate_stream

    def spy_generate_stream(messages, **kwargs):
        captured_prompts.append(messages)
        return original_generate_stream(messages, **kwargs)

    mock_provider.generate_stream = spy_generate_stream

    with patch("app.api.v1.endpoints.conversations.get_llm_provider", return_value=mock_provider), \
         patch("app.services.assistant.orchestrator.get_llm_provider", return_value=mock_provider):
        stream_res = await client.post(
            f"/api/v1/conversations/{conv_id}/messages",
            json={"user_text": "Let's summarize our current step and continue."},
            headers=auth_headers,
        )
        assert stream_res.status_code == 200

    assert len(captured_prompts) == 1
    sent_messages = captured_prompts[0]
    sys_prompt = sent_messages[0].content
    assert "<recent_episode_digest from_turn=\"1\" to_turn=\"6\">" in sys_prompt
    assert "&lt;/recent_episode_digest&gt;" in sys_prompt

    # Only turns 7..10 + current user turn remain verbatim after compaction
    verbatim_non_system = [m for m in sent_messages if m.role != "system"]
    assert len(verbatim_non_system) == 5  # 4 kept prior history + 1 active user prompt

    # Verify DB persisted the active summary while keeping all 12 messages (10 prior + 2 new)
    sum_res = await client.get(f"/api/v1/conversations/{conv_id}/summary", headers=auth_headers)
    assert sum_res.status_code == 200
    assert sum_res.json()["to_sequence_no"] == 6

    msg_list_res = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    assert msg_list_res.status_code == 200
    assert msg_list_res.json()["total"] == 12
