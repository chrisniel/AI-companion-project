"""
FTS5-based memory retrieval — Master Plan §18, Milestone M3 Batch C1.

Security: raw user text NEVER passed to MATCH. Only sanitized tokens.
Soft-deleted memories excluded by trigger + defensive SQL filter.
Scope isolation: returns Profile global memories + matching Character instance memories.
Temporal filter: bound :now parameter excludes expired memories.
Core fact assembly: retrieves persistent profile facts for context injection.
Language coverage: ASCII, Latin extended, CJK, Hangul (EN/FIL/JA).
"""

from datetime import datetime, timezone
import logging
import re
from typing import List, Optional

from fastapi import HTTPException
from sqlalchemy import and_, or_, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.profile_sessions import validate_profile_session
from app.models.memory import Memory
from app.models.profile_session import ProfileSession

logger = logging.getLogger("app.services.memory.retriever")

FTS5_RESERVED = {"OR", "AND", "NOT"}
_TOKEN_RE = re.compile(r"[a-zA-Z0-9\u3040-\u9FFF\uAC00-\uD7AF\u0080-\u024F]+")


def _sanitize_fts_query(raw: str) -> str:
    """Extract safe alphanumeric and multilingual word tokens, filtering FTS5 operators."""
    tokens = _TOKEN_RE.findall(raw)
    clean_tokens = [t.strip() for t in tokens if t.strip() and t.upper() not in FTS5_RESERVED]
    return " OR ".join(clean_tokens) if clean_tokens else ""


def _sanitize_fts_prefix_query(raw: str) -> str:
    """Build prefix-aware FTS5 OR query (`token*` for len >= 3 ASCII/Latin tokens) to handle word stems."""
    tokens = _TOKEN_RE.findall(raw)
    clean_tokens = [t.strip() for t in tokens if t.strip() and t.upper() not in FTS5_RESERVED]
    if not clean_tokens:
        return ""
    prefixed = [f"{t}*" if (t.isascii() and len(t) >= 3) else t for t in clean_tokens]
    return " OR ".join(prefixed)


async def _increment_recall_counts(db: AsyncSession, memory_ids: List[str]) -> None:
    """Atomically increment recall_count for memories surfaced into active conversation context."""
    if not memory_ids:
        return
    await db.execute(
        update(Memory)
        .where(Memory.id.in_(memory_ids))
        .values(recall_count=Memory.recall_count + 1)
    )
    await db.flush()


async def search_relevant_memories(
    db: AsyncSession,
    query: str,
    profile_session: ProfileSession,
    character_instance_id: Optional[str] = None,
    limit: int = 5,
    now: Optional[datetime] = None,
    increment_recall: bool = False,
) -> List[Memory]:
    """Retrieve relevant long-term/episodic memories matching query tokens for a freshly validated Profile Session."""
    profile_session = await validate_profile_session(db, profile_session)
    fts_query = _sanitize_fts_prefix_query(query)
    if not fts_query:
        return []

    current_now = now or datetime.now(timezone.utc)
    candidate_pool = min(max(limit * 3, limit), 25)

    sql = text("""
        SELECT m.id, m.created_at, m.updated_at, m.deleted_at, m.is_deleted, m.owner_id, m.profile_id,
               m.category, m.content, m.importance, m.source_type,
               m.source_message_id, m.user_verified,
               m.scope, m.character_instance_id, m.valid_from, m.expires_at, m.last_verified_at,
               m.is_core, m.trigger_keywords, m.recall_count,
               rank AS fts_rank
        FROM memories m
        JOIN memories_fts f ON m.id = f.id
        WHERE memories_fts MATCH :fts_query
          AND m.profile_id = :profile_id
          AND m.deleted_at IS NULL
          AND (m.expires_at IS NULL OR m.expires_at > :now)
          AND (
            m.scope = 'profile'
            OR (m.scope = 'character' AND m.character_instance_id = :character_instance_id)
          )
        ORDER BY rank LIMIT :candidate_pool
    """)
    try:
        result = await db.execute(
            sql,
            {
                "fts_query": fts_query,
                "profile_id": profile_session.profile_id,
                "candidate_pool": candidate_pool,
                "now": current_now,
                "character_instance_id": character_instance_id,
            },
        )
        rows = result.mappings().fetchall()
        scored: list[tuple[float, Memory]] = []
        for idx, r in enumerate(rows):
            row_dict = dict(r)
            row_dict.pop("fts_rank", None)
            mem = Memory(**row_dict)
            # Bounded recall-frequency + importance boost over base FTS ordering
            base_score = float(len(rows) - idx)
            freq_boost = 0.05 * min(int(mem.recall_count or 0), 10)
            scored.append((base_score + float(mem.importance or 0.0) * 0.2 + freq_boost, mem))

        scored.sort(key=lambda pair: pair[0], reverse=True)
        memories = [mem for _, mem in scored[:limit]]

        if increment_recall and memories:
            await _increment_recall_counts(db, [m.id for m in memories])
            for m in memories:
                m.recall_count = (m.recall_count or 0) + 1

        await validate_profile_session(db, profile_session)
        return memories
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("FTS5 memory retrieval failed (%s)", type(exc).__name__)
        return []


async def get_core_memories(
    db: AsyncSession,
    profile_id: str,
    limit: int = 5,
    now: Optional[datetime] = None,
) -> List[Memory]:
    """Retrieve non-temporary, profile-scoped core facts without trigger-keyword gating."""
    current_now = now or datetime.now(timezone.utc)
    stmt = (
        select(Memory)
        .where(
            Memory.profile_id == profile_id,
            Memory.deleted_at.is_(None),
            Memory.scope == "profile",
            Memory.expires_at.is_(None),
            Memory.valid_from <= current_now,
            or_(
                Memory.trigger_keywords.is_(None),
                Memory.trigger_keywords == "",
                Memory.trigger_keywords == "[]",
            ),
            or_(Memory.is_core.is_(True), Memory.importance >= 1.5),
        )
        .order_by(Memory.is_core.desc(), Memory.importance.desc(), Memory.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


def _keyword_matches_query(keyword: str, normalized_text: str, message_tokens: set[str]) -> bool:
    """Match normalized phrase or stem/prefix overlap (e.g. 'cook' matches 'cooking', 'sarah' matches \"Sarah's\")."""
    kw_clean = keyword.strip().lower()
    if not kw_clean:
        return False

    kw_tokens = [t.lower() for t in _TOKEN_RE.findall(kw_clean) if t]
    if not kw_tokens:
        return False

    if len(kw_tokens) > 1:
        phrase = " ".join(kw_tokens)
        return phrase in normalized_text

    kw = kw_tokens[0]
    if kw in message_tokens:
        return True
    if kw.isascii() and len(kw) >= 3:
        return any(tok.startswith(kw) or (len(tok) >= 3 and kw.startswith(tok)) for tok in message_tokens)
    return kw in normalized_text


async def get_triggered_knowledge(
    db: AsyncSession,
    profile_session: ProfileSession,
    query: str,
    character_instance_id: Optional[str] = None,
    limit: int = 5,
    now: Optional[datetime] = None,
    increment_recall: bool = False,
) -> List[Memory]:
    """Activate dormant knowledge/lorebook entries whose trigger keywords match user text."""
    profile_session = await validate_profile_session(db, profile_session)
    tokens_list = [t.lower() for t in _TOKEN_RE.findall(query or "") if t]
    if not tokens_list:
        return []

    message_tokens = set(tokens_list)
    normalized_text = " ".join(tokens_list)
    current_now = now or datetime.now(timezone.utc)

    scope_filter = Memory.scope == "profile"
    if character_instance_id:
        scope_filter = or_(
            Memory.scope == "profile",
            and_(
                Memory.scope == "character",
                Memory.character_instance_id == character_instance_id,
            ),
        )

    stmt = (
        select(Memory)
        .where(
            Memory.profile_id == profile_session.profile_id,
            Memory.deleted_at.is_(None),
            Memory.trigger_keywords.is_not(None),
            Memory.trigger_keywords != "",
            Memory.trigger_keywords != "[]",
            or_(Memory.expires_at.is_(None), Memory.expires_at > current_now),
            scope_filter,
        )
        .order_by(Memory.is_core.desc(), Memory.importance.desc(), Memory.recall_count.desc())
    )
    candidates = list((await db.execute(stmt)).scalars().all())
    matched: list[tuple[int, Memory]] = []
    for mem in candidates:
        keywords = mem.trigger_keywords_list
        if not keywords:
            continue
        hits = sum(1 for kw in keywords if _keyword_matches_query(kw, normalized_text, message_tokens))
        if hits > 0:
            matched.append((hits, mem))

    matched.sort(key=lambda pair: (pair[0], pair[1].importance or 0.0, pair[1].recall_count or 0), reverse=True)
    selected = [mem for _, mem in matched[:limit]]

    if increment_recall and selected:
        await _increment_recall_counts(db, [m.id for m in selected])

    return selected


async def get_active_short_term_memories(
    db: AsyncSession,
    profile_id: str,
    character_instance_id: Optional[str] = None,
    limit: int = 5,
    now: Optional[datetime] = None,
) -> List[Memory]:
    """Retrieve active non-expired Short-Term Context items for prompt injection."""
    current_now = now or datetime.now(timezone.utc)
    scope_filter = Memory.scope == "profile"
    if character_instance_id:
        scope_filter = or_(
            Memory.scope == "profile",
            and_(
                Memory.scope == "character",
                Memory.character_instance_id == character_instance_id,
            ),
        )

    stmt = (
        select(Memory)
        .where(
            Memory.profile_id == profile_id,
            Memory.deleted_at.is_(None),
            scope_filter,
            or_(
                Memory.expires_at > current_now,
                and_(
                    Memory.expires_at.is_(None),
                    Memory.category == "context",
                    Memory.is_core.is_(False),
                ),
            ),
        )
        .order_by(Memory.last_verified_at.desc(), Memory.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())
