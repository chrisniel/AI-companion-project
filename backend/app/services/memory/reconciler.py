"""Deterministic Slot Reconciliation Service — M3 Batch C2 (PC-MEM-002).

Reconciles candidate facts against active Profile and Character memories
using deterministic slot resolution: DUPLICATE, NEW, MERGE, UPDATE, and CONFLICT.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
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
    "promoted to", "resigned", "healed", "no longer", "cured", "recovered",
    "previously had", "used to be", "used to have", "stopped being",
    "don't have", "do not have",
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


def _as_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """Normalize SQLite naive timestamps to UTC-aware datetimes."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _create_new_memory(
    *,
    profile_id: str,
    candidate: MemoryCandidate,
    effective_scope: str,
    effective_character_instance_id: Optional[str],
    is_explicit: bool,
    user_verified: bool,
    source_message_id: Optional[str],
    now: datetime,
    source_type_override: Optional[str] = None,
) -> Memory:
    effective_verified = True if (is_explicit or user_verified or candidate.user_verified) else False
    effective_importance = max(float(candidate.importance), float(candidate.confidence))
    if is_explicit:
        effective_importance = max(effective_importance, 1.5)
    return Memory(
        id=str(uuid.uuid4()),
        profile_id=profile_id,
        owner_id=profile_id,
        category=candidate.category,
        content=candidate.content,
        importance=min(2.0, effective_importance),
        source_type=source_type_override or ("user_explicit" if is_explicit else "extracted"),
        source_message_id=source_message_id,
        user_verified=effective_verified if source_type_override != "conflict" else False,
        scope=effective_scope,
        character_instance_id=effective_character_instance_id,
        valid_from=now,
        expires_at=candidate.expires_at,
        last_verified_at=now,
        is_core=candidate.is_core,
        recall_count=0,
    )


_PREVIOUSLY_SUFFIX_RE = re.compile(
    r"\s*\(previously:\s*.*?\s+until\s+\d{4}-\d{2}\)\s*$"
)


def _format_temporal_supersession(
    old_content: str,
    new_content: str,
    now: datetime,
    max_length: int = 1000,
) -> str:
    """Append a bounded single-step supersession note preserving prior state with YYYY-MM."""
    old_base = _PREVIOUSLY_SUFFIX_RE.sub("", old_content or "").strip()
    new_base = _PREVIOUSLY_SUFFIX_RE.sub("", new_content or "").strip()

    if not old_base or old_base.rstrip(".").lower() == new_base.rstrip(".").lower():
        return new_base[:max_length]

    month_label = now.strftime("%Y-%m")
    prefix = f"{new_base} (previously: "
    tail = f" until {month_label})"
    overhead = len(prefix) + len(tail)
    if overhead >= max_length - 10:
        return new_base[:max_length]

    avail_old = max_length - overhead
    if len(old_base) > avail_old:
        old_base = f"{old_base[: max(1, avail_old - 1)].rstrip()}…"

    return f"{prefix}{old_base}{tail}"


async def reconcile_candidate(
    db: AsyncSession,
    profile_id: str,
    candidate: MemoryCandidate,
    source_message_id: Optional[str] = None,
    active_character_instance_id: Optional[str] = None,
    source_type: str = "extracted",
    user_verified: bool = False,
    now: Optional[datetime] = None,
) -> Optional[Memory]:
    """Reconcile a candidate memory against existing profile and character memories.

    Applies deterministic slot logic (DUPLICATE, NEW, MERGE, UPDATE, CONFLICT),
    enforces Fixed Knowledge write-protection, and consolidates recurring Short-Term Context.
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

    current_now = now or datetime.now(timezone.utc)

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
        min_len = min(len(cand_tokens), len(mem_tokens))
        overlap = len(intersection) / max(1, min_len)
        if overlap > best_overlap:
            best_overlap = overlap
            best_match = mem

    # 5. Slot Determination
    # Slot: NEW (no significant overlap with any existing memory)
    if not best_match or best_overlap < 0.25:
        new_memory = _create_new_memory(
            profile_id=profile_id,
            candidate=candidate,
            effective_scope=effective_scope,
            effective_character_instance_id=effective_character_instance_id,
            is_explicit=is_explicit,
            user_verified=user_verified,
            source_message_id=source_message_id,
            now=current_now,
        )
        db.add(new_memory)
        await db.flush()
        return new_memory

    cand_clean = candidate.content.strip().lower()
    ex_clean = best_match.content.strip().lower()
    mem_tokens = _tokenize(best_match.content)
    jaccard = len(cand_tokens & mem_tokens) / max(1, len(cand_tokens | mem_tokens))

    # Fixed Knowledge Protection (Tier 1 lock against background AI overwrites)
    if best_match.is_fixed_knowledge and not is_explicit:
        if cand_clean == ex_clean or jaccard >= 0.80:
            best_match.last_verified_at = current_now
            db.add(best_match)
            await db.flush()
            return best_match
        if _is_contradiction(best_match.content, candidate.content):
            conflict_memory = _create_new_memory(
                profile_id=profile_id,
                candidate=candidate,
                effective_scope=effective_scope,
                effective_character_instance_id=effective_character_instance_id,
                is_explicit=False,
                user_verified=False,
                source_message_id=source_message_id,
                now=current_now,
                source_type_override="conflict",
            )
            db.add(conflict_memory)
            await db.flush()
            return conflict_memory
        # Non-contradictory auto-extracted detail cannot mutate fixed knowledge; insert as separate NEW item
        isolated_memory = _create_new_memory(
            profile_id=profile_id,
            candidate=candidate,
            effective_scope=effective_scope,
            effective_character_instance_id=effective_character_instance_id,
            is_explicit=False,
            user_verified=False,
            source_message_id=source_message_id,
            now=current_now,
        )
        db.add(isolated_memory)
        await db.flush()
        return isolated_memory

    # Short-Term Consolidation across sessions (> 12h after initial observation)
    if best_match.is_short_term and not _is_contradiction(best_match.content, candidate.content):
        baseline = _as_utc(best_match.valid_from) or _as_utc(best_match.created_at) or current_now
        last_verified = _as_utc(best_match.last_verified_at) or baseline
        hours_since_origin = (current_now - baseline).total_seconds() / 3600.0
        already_reinforced_later = (last_verified - baseline).total_seconds() >= 12 * 3600
        if hours_since_origin >= 12.0:
            if already_reinforced_later or (best_match.recall_count or 0) >= 1:
                best_match.expires_at = None
                if best_match.category == "context":
                    best_match.category = "fact"
            else:
                best_match.expires_at = current_now + timedelta(hours=72)
            best_match.last_verified_at = current_now
            if is_explicit or user_verified or candidate.user_verified:
                best_match.user_verified = True
            db.add(best_match)
            await db.flush()
            return best_match

    # Slot: DUPLICATE (content is identical or almost identical)
    if cand_clean == ex_clean or jaccard >= 0.80:
        best_match.last_verified_at = current_now
        if candidate.is_core:
            best_match.is_core = True
        if is_explicit or user_verified or candidate.user_verified:
            best_match.user_verified = True
        if is_explicit:
            best_match.importance = min(2.0, max(float(best_match.importance), 1.5))
        db.add(best_match)
        await db.flush()
        return best_match

    # Slot: CONFLICT (contradiction on common subject)
    if _is_contradiction(best_match.content, candidate.content):
        conflict_memory = _create_new_memory(
            profile_id=profile_id,
            candidate=candidate,
            effective_scope=effective_scope,
            effective_character_instance_id=effective_character_instance_id,
            is_explicit=is_explicit,
            user_verified=False,
            source_message_id=source_message_id,
            now=current_now,
            source_type_override="conflict",
        )
        db.add(conflict_memory)
        await db.flush()
        return conflict_memory

    # Slot: UPDATE (explicit update signal or single-attribute replacement)
    if _is_update(best_match.content, candidate.content):
        if not best_match.is_short_term and candidate.category in (
            "fact",
            "preference",
            "context",
        ):
            best_match.content = _format_temporal_supersession(
                best_match.content,
                candidate.content,
                current_now,
            )
        else:
            best_match.content = candidate.content
        best_match.category = candidate.category
        best_match.last_verified_at = current_now
        if is_explicit or user_verified or candidate.user_verified:
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
    best_match.last_verified_at = current_now
    if is_explicit or user_verified or candidate.user_verified:
        best_match.user_verified = True
        best_match.source_type = "user_explicit"
    if candidate.is_core:
        best_match.is_core = True
    db.add(best_match)
    await db.flush()
    return best_match
