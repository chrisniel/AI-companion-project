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
from sqlalchemy import or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.profile_sessions import validate_profile_session
from app.models.memory import Memory
from app.models.profile_session import ProfileSession

logger = logging.getLogger("app.services.memory.retriever")

FTS5_RESERVED = {"OR", "AND", "NOT"}


def _sanitize_fts_query(raw: str) -> str:
    """Extract safe alphanumeric and multilingual word tokens, filtering FTS5 operators."""
    tokens = re.findall(r"[a-zA-Z0-9\u3040-\u9FFF\uAC00-\uD7AF\u0080-\u024F]+", raw)
    clean_tokens = [t.strip() for t in tokens if t.strip() and t.upper() not in FTS5_RESERVED]
    return " OR ".join(clean_tokens) if clean_tokens else ""


async def search_relevant_memories(
    db: AsyncSession,
    query: str,
    profile_session: ProfileSession,
    character_instance_id: Optional[str] = None,
    limit: int = 5,
    now: Optional[datetime] = None,
) -> List[Memory]:
    """Retrieve relevant memories matching query tokens for a freshly validated Profile Session."""
    profile_session = await validate_profile_session(db, profile_session)
    fts_query = _sanitize_fts_query(query)
    if not fts_query:
        return []

    current_now = now or datetime.now(timezone.utc)

    sql = text("""
        SELECT m.id, m.created_at, m.updated_at, m.deleted_at, m.is_deleted, m.owner_id, m.profile_id,
               m.category, m.content, m.importance, m.source_type,
               m.source_message_id, m.user_verified,
               m.scope, m.character_instance_id, m.valid_from, m.expires_at, m.last_verified_at, m.is_core
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
        ORDER BY rank LIMIT :limit
    """)
    try:
        result = await db.execute(
            sql,
            {
                "fts_query": fts_query,
                "profile_id": profile_session.profile_id,
                "limit": limit,
                "now": current_now,
                "character_instance_id": character_instance_id,
            },
        )
        rows = result.mappings().fetchall()
        memories = [Memory(**dict(r)) for r in rows]
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
    """Retrieve non-temporary, profile-scoped core facts."""
    current_now = now or datetime.now(timezone.utc)
    stmt = (
        select(Memory)
        .where(
            Memory.profile_id == profile_id,
            Memory.deleted_at.is_(None),
            Memory.scope == "profile",
            Memory.expires_at.is_(None),
            Memory.valid_from <= current_now,
            or_(Memory.is_core.is_(True), Memory.importance >= 1.5),
        )
        .order_by(Memory.is_core.desc(), Memory.importance.desc(), Memory.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())
