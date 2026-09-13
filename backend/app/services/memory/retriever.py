"""
FTS5-based memory retrieval — Master Plan §18.

Security: raw user text NEVER passed to MATCH. Only sanitized tokens.
Soft-deleted memories excluded by trigger + defensive SQL filter.
On any exception: return [] and log — never raise to callers.
Language coverage: ASCII, Latin extended, CJK, Hangul (EN/FIL/JA).
"""
import logging
import re
from typing import List
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.memory import Memory

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
    owner_id: str,
    limit: int = 5,
) -> List[Memory]:
    """Retrieve relevant memories matching query tokens for the specified owner."""
    fts_query = _sanitize_fts_query(query)
    if not fts_query:
        return []

    sql = text("""
        SELECT m.id, m.created_at, m.updated_at, m.deleted_at, m.owner_id,
               m.category, m.content, m.importance, m.source_type,
               m.source_message_id, m.user_verified
        FROM memories m
        JOIN memories_fts f ON m.id = f.id
        WHERE memories_fts MATCH :fts_query
          AND m.owner_id = :owner_id
          AND m.deleted_at IS NULL
        ORDER BY rank LIMIT :limit
    """)
    try:
        result = await db.execute(sql, {"fts_query": fts_query, "owner_id": owner_id, "limit": limit})
        rows = result.mappings().fetchall()
        return [Memory(**dict(r)) for r in rows]
    except Exception as exc:
        logger.warning(f"FTS5 search failed ('{fts_query}'): {exc}")
        return []
