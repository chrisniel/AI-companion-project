"""Deterministic Slot Reconciliation Service — M3 Batch C2 (PC-MEM-002).

Reconciles candidate facts against active Profile and Character memories
using deterministic slot resolution: DUPLICATE, NEW, MERGE, UPDATE, and CONFLICT.
"""

from __future__ import annotations

from datetime import datetime, timezone
import logging
import re
from typing import List, Optional, Set
import uuid

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.memory import Memory
from app.services.memory.extractor import MemoryCandidate

logger = logging.getLogger("app.services.memory.reconciler")

STOPWORDS = {
    "user", "the", "a", "an", "is", "are", "was", "were", "in", "and", "or",
    "to", "with", "for", "on", "of", "at", "by", "from", "it", "this", "that",
    "has", "have", "had", "be", "been", "every",
}

NEGATIVE_SENTIMENT_WORDS = {
    "hate", "hates", "hated", "dislike", "dislikes", "disliked",
    "allergic", "allergy", "cannot", "cant", "can't", "no longer",
    "stopped", "quit", "refuse", "refuses", "never", "not", "despise",
}

POSITIVE_SENTIMENT_WORDS = {
    "love", "loves", "loved", "like", "likes", "liked", "prefer",
    "prefers", "favorite", "favourite", "enjoys", "enjoy", "drinks", "eats",
}

UPDATE_SIGNALS = {
    "moved", "now lives", "now works", "changed", "switched", "new",
    "promoted to", "resigned",
}


def _tokenize(text: str) -> Set[str]:
    """Extract significant lowercase word tokens, removing punctuation and common stopwords."""
    raw_tokens = re.findall(r"[a-zA-Z0-9\u3040-\u9FFF\uAC00-\uD7AF\u0080-\u024F]+", text.lower())
    return {t for t in raw_tokens if t not in STOPWORDS and len(t) > 1}


def _is_contradiction(existing_text: str, candidate_text: str) -> bool:
    """Return True if candidate contradicts existing memory on the same topic."""
    ex_lower = existing_text.lower()
    cand_lower = candidate_text.lower()

    ex_tokens = _tokenize(existing_text)
    cand_tokens = _tokenize(candidate_text)

    # Check for direct negation on common subject
    has_existing_pos = any(w in ex_lower for w in POSITIVE_SENTIMENT_WORDS)
    has_existing_neg = any(w in ex_lower for w in NEGATIVE_SENTIMENT_WORDS)
    has_cand_pos = any(w in cand_lower for w in POSITIVE_SENTIMENT_WORDS)
    has_cand_neg = any(w in cand_lower for w in NEGATIVE_SENTIMENT_WORDS)

    if (has_existing_pos and has_cand_neg) or (has_existing_neg and has_cand_pos):
        return True

    # Mutually exclusive keywords
    if "vegetarian" in ex_tokens and ("meat" in cand_tokens or "bacon" in cand_tokens or "steak" in cand_tokens):
        return True
    if "vegetarian" in cand_tokens and ("meat" in ex_tokens or "bacon" in ex_tokens or "steak" in ex_tokens):
        return True

    return False


def _is_update(existing_text: str, candidate_text: str) -> bool:
    """Return True if candidate represents an explicit replacement or update of an existing fact."""
    cand_lower = candidate_text.lower()
    ex_lower = existing_text.lower()

    # If candidate explicitly uses update words
    if any(sig in cand_lower for sig in UPDATE_SIGNALS):
        return True

    # Same subject attribute replacement (e.g., "lives in X" vs "lives in Y")
    if "lives in" in ex_lower and "lives in" in cand_lower:
        return True
    if "works at" in ex_lower and "works at" in cand_lower:
        return True

    return False


async def reconcile_candidate(
    db: AsyncSession,
    profile_id: str,
    candidate: MemoryCandidate,
    source_message_id: Optional[str] = None,
    active_character_instance_id: Optional[str] = None,
    source_type: str = "extracted",
    user_verified: bool = False,
) -> Optional[Memory]:
    """Reconcile a candidate memory against existing profile and character memories.

    Applies deterministic slot logic (DUPLICATE, NEW, MERGE, UPDATE, CONFLICT).
    Enforces scoping check constraints and confidence thresholds.
    """
    # 1. Confidence threshold check
    is_explicit = source_type == "user_explicit" or candidate.confidence >= 1.0
    if not is_explicit and candidate.confidence < settings.MEMORY_EXTRACTION_CONFIDENCE_THRESHOLD:
        logger.debug(
            f"Candidate rejected: confidence {candidate.confidence} < threshold {settings.MEMORY_EXTRACTION_CONFIDENCE_THRESHOLD}"
        )
        return None

    # 2. Scope validation and normalization
    effective_scope = candidate.scope
    effective_character_instance_id: Optional[str] = None

    if effective_scope == "character":
        if active_character_instance_id is None:
            # Force profile scope to prevent constraint violation ck_memories_character_scope
            effective_scope = "profile"
            effective_character_instance_id = None
        else:
            effective_character_instance_id = active_character_instance_id
    else:
        effective_scope = "profile"
        effective_character_instance_id = None

    now = datetime.now(timezone.utc)

    # 3. Retrieve existing active memories for this profile & scope
    stmt = select(Memory).where(
        Memory.profile_id == profile_id,
        Memory.is_deleted == False,
    )
    if effective_character_instance_id:
        stmt = stmt.where(
            or_(
                Memory.scope == "profile",
                and_(
                    Memory.scope == "character",
                    Memory.character_instance_id == effective_character_instance_id,
                ),
            )
        )
    else:
        stmt = stmt.where(Memory.scope == "profile")

    existing_memories = (await db.scalars(stmt)).all()

    # 4. Find best matching memory based on token overlap
    cand_tokens = _tokenize(candidate.content)
    best_match: Optional[Memory] = None
    best_overlap: float = 0.0

    for mem in existing_memories:
        mem_tokens = _tokenize(mem.content)
        if not mem_tokens or not cand_tokens:
            continue
        intersection = cand_tokens & mem_tokens
        overlap = len(intersection) / max(1, len(cand_tokens))
        if overlap > best_overlap:
            best_overlap = overlap
            best_match = mem

    # 5. Slot Determination
    # Slot: NEW (no significant overlap with any existing memory)
    if not best_match or best_overlap < 0.25:
        new_memory = Memory(
            id=str(uuid.uuid4()),
            profile_id=profile_id,
            owner_id=profile_id,
            category=candidate.category,
            content=candidate.content,
            importance=candidate.confidence,
            source_type="user_explicit" if is_explicit else "extracted",
            source_message_id=source_message_id,
            user_verified=True if is_explicit else False,
            scope=effective_scope,
            character_instance_id=effective_character_instance_id,
            valid_from=now,
            expires_at=candidate.expires_at,
            last_verified_at=now,
            is_core=candidate.is_core,
        )
        db.add(new_memory)
        await db.flush()
        return new_memory

    # Slot: DUPLICATE (content is identical or almost identical)
    cand_clean = candidate.content.strip().lower()
    ex_clean = best_match.content.strip().lower()
    if cand_clean == ex_clean or best_overlap >= 0.85:
        best_match.last_verified_at = now
        if candidate.is_core:
            best_match.is_core = True
        if is_explicit or user_verified:
            best_match.user_verified = True
        db.add(best_match)
        await db.flush()
        return best_match

    # Slot: CONFLICT (contradiction on common subject)
    if _is_contradiction(best_match.content, candidate.content):
        conflict_memory = Memory(
            id=str(uuid.uuid4()),
            profile_id=profile_id,
            owner_id=profile_id,
            category=candidate.category,
            content=candidate.content,
            importance=candidate.confidence,
            source_type="conflict",
            source_message_id=source_message_id,
            user_verified=False,  # Unverified until resolved in UI or chat
            scope=effective_scope,
            character_instance_id=effective_character_instance_id,
            valid_from=now,
            expires_at=candidate.expires_at,
            last_verified_at=now,
            is_core=candidate.is_core,
        )
        db.add(conflict_memory)
        await db.flush()
        return conflict_memory

    # Slot: UPDATE (explicit update signal or single-attribute replacement)
    if _is_update(best_match.content, candidate.content):
        best_match.content = candidate.content
        best_match.category = candidate.category
        best_match.last_verified_at = now
        if is_explicit or user_verified:
            best_match.user_verified = True
            best_match.source_type = "user_explicit"
        if candidate.is_core:
            best_match.is_core = True
        if candidate.expires_at is not None:
            best_match.expires_at = candidate.expires_at
        db.add(best_match)
        await db.flush()
        return best_match

    # Slot: MERGE (enrichment with complementary information)
    best_match.content = candidate.content
    best_match.category = candidate.category
    best_match.last_verified_at = now
    if is_explicit or user_verified:
        best_match.user_verified = True
        best_match.source_type = "user_explicit"
    if candidate.is_core:
        best_match.is_core = True
    db.add(best_match)
    await db.flush()
    return best_match
