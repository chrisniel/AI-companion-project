"""Rolling conversation compaction & episode digest service (Milestone M3 Batch F).

Preserves full immutability of raw `messages` rows (`D-SHARED-AI-02`) and keeps
transient conversation episode digests strictly separate from canonical `D7`
`memories` rows (`D-SHARED-AI-03`).
"""

from dataclasses import dataclass
from datetime import datetime
import logging
import re
from typing import Literal, Optional, Sequence

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.base import utc_now
from app.models.conversation_summary import ConversationSummary
from app.models.message import Message
from app.schemas.llm import ChatMessage
from app.services.llm.base import BaseLLMProvider

logger = logging.getLogger("app.services.assistant.compactor")

CompactionTrigger = Literal["auto", "manual"]


@dataclass
class CompactionExecutionResult:
    """Structured result returned after evaluating or running compaction."""

    summary: Optional[ConversationSummary]
    compacted: bool
    reason: str
    active_summary: Optional[ConversationSummary]


def estimate_tokens(text: str) -> int:
    """Coarse ~4 chars/token heuristic aligned with orchestrator prompt budgeting."""
    return (len(text) + 3) // 4 if text else 0


def escape_prompt_xml_delimiters(text: str) -> str:
    """Neutralize angle brackets in injected digests/memory bullets to prevent XML tag spoofing."""
    if not text:
        return ""
    return text.replace("<", "&lt;").replace(">", "&gt;")


def _normalize_single_line(text: str) -> str:
    """Collapse newlines/tabs and repeated whitespace into a single clean line."""
    return re.sub(r"\s+", " ", text or "").strip()


def _truncate_clean(text: str, max_chars: int) -> str:
    """Truncate text cleanly to `max_chars` without ugly mid-word cuts when avoidable."""
    cleaned = text.strip()
    if len(cleaned) <= max_chars:
        return cleaned
    if max_chars <= 3:
        return cleaned[:max_chars]
    cutoff = cleaned[: max_chars - 1]
    last_space = cutoff.rfind(" ")
    if last_space > max_chars // 2:
        cutoff = cutoff[:last_space].rstrip()
    return f"{cutoff}…"


def _is_generic_mock_output(text: str) -> bool:
    """Detect canned mock or placeholder model outputs unsuitable for real episode digests."""
    lowered = _normalize_single_line(text).lower()
    if not lowered:
        return True
    markers = (
        "[mock ai companion]:",
        "local ai runtime is operational",
        "i received your message:",
        "hello! i am a mock ai assistant",
        "mock ai assistant",
        "this is a mocked response",
    )
    return any(marker in lowered for marker in markers)


def _extractive_episode_digest(
    prior_summary: Optional[ConversationSummary],
    messages_to_compact: Sequence[Message],
    max_chars: int = 720,
) -> str:
    """Deterministically build a bounded extractive episode digest across older turns."""
    lines: list[str] = []

    if prior_summary is not None and prior_summary.summary_text.strip():
        prior_body = prior_summary.summary_text.strip()
        prior_budget = max(140, max_chars // 3)
        prior_snippet = _truncate_clean(_normalize_single_line(prior_body), prior_budget)
        if prior_snippet:
            lines.append(f"Earlier context: {prior_snippet}")

    # Walk recent-most first among the compacted slice so key latest compacted beats survive cap
    turn_lines: list[str] = []
    remaining_chars = max_chars - sum(len(x) + 1 for x in lines)
    per_line_cap = 140 if len(messages_to_compact) > 4 else 200

    for msg in reversed(messages_to_compact):
        speaker = "User" if msg.sender == "user" else "Assistant"
        snippet = _truncate_clean(_normalize_single_line(msg.content), per_line_cap)
        if not snippet:
            continue
        candidate_line = f"- {speaker} (turn {msg.sequence_no}): {snippet}"
        needed = len(candidate_line) + 1
        if remaining_chars - needed < 0:
            if not turn_lines:
                clipped = _truncate_clean(candidate_line, max(40, remaining_chars))
                if clipped:
                    turn_lines.append(clipped)
            break
        turn_lines.append(candidate_line)
        remaining_chars -= needed

    turn_lines.reverse()
    lines.extend(turn_lines)

    combined = "\n".join(lines).strip()
    if not combined:
        combined = "Earlier conversation turns compacted."
    return _truncate_clean(combined, max_chars)


async def get_active_conversation_summary(
    db: AsyncSession,
    conversation_id: str,
    profile_id: str,
) -> Optional[ConversationSummary]:
    """Return the currently active, non-deleted rolling summary for a conversation."""
    stmt = (
        select(ConversationSummary)
        .where(
            ConversationSummary.conversation_id == conversation_id,
            ConversationSummary.profile_id == profile_id,
            ConversationSummary.is_active.is_(True),
            ConversationSummary.is_deleted.is_(False),
        )
        .order_by(ConversationSummary.to_sequence_no.desc(), ConversationSummary.updated_at.desc())
        .limit(1)
    )
    return await db.scalar(stmt)


def should_compact_conversation(
    estimated_prompt_tokens: int,
    context_capacity: int,
    generation_reserve: int,
    trigger_ratio: Optional[float] = None,
) -> bool:
    """Return True when assembled prompt approaches the safe token watermark."""
    if not settings.CONTEXT_COMPACTION_ENABLED:
        return False
    ratio = (
        settings.CONTEXT_COMPACTION_TRIGGER_RATIO
        if trigger_ratio is None
        else trigger_ratio
    )
    available = max(1, context_capacity - generation_reserve)
    watermark = int(available * ratio)
    return estimated_prompt_tokens >= watermark


async def _generate_llm_digest(
    provider: Optional[BaseLLMProvider],
    prior_summary: Optional[ConversationSummary],
    messages_to_compact: Sequence[Message],
    max_tokens: int,
) -> Optional[str]:
    """Request a concise third-person episode summary from the loaded provider, or None on fallback."""
    if provider is None or not provider.is_loaded():
        return None

    transcript_lines: list[str] = []
    if prior_summary is not None and prior_summary.summary_text.strip():
        transcript_lines.append(
            f"[Previous episode digest covering turns {prior_summary.from_sequence_no}-{prior_summary.to_sequence_no}]:\n"
            f"{escape_prompt_xml_delimiters(prior_summary.summary_text.strip())}"
        )

    transcript_lines.append("[Older conversation turns to fold into the rolling digest]:")
    for msg in messages_to_compact:
        role_label = "User" if msg.sender == "user" else "Assistant"
        cleaned = _truncate_clean(_normalize_single_line(msg.content), 320)
        transcript_lines.append(
            f"- {role_label} (turn {msg.sequence_no}): {escape_prompt_xml_delimiters(cleaned)}"
        )

    system_msg = ChatMessage(
        role="system",
        content=(
            "You maintain a factual, compact rolling episode summary for an ongoing conversation.\n"
            "Preserve key user goals, decisions, constraints, pending questions, and emotional context.\n"
            "Do NOT invent facts. Write concise third-person bullet points under 160 words."
        ),
    )
    user_msg = ChatMessage(role="user", content="\n".join(transcript_lines))

    try:
        generated = await provider.generate(
            messages=[system_msg, user_msg],
            temperature=settings.CONTEXT_COMPACTION_TEMPERATURE,
            max_tokens=max_tokens,
        )
        raw_text = str(generated).strip()
        if not raw_text or _is_generic_mock_output(raw_text):
            return None
        return raw_text
    except Exception as exc:
        logger.warning("LLM compaction generation failed; falling back to extractive digest: %s", exc)
        return None


async def compact_conversation(
    db: AsyncSession,
    conversation_id: str,
    profile_id: str,
    provider: Optional[BaseLLMProvider] = None,
    *,
    force: bool = False,
    trigger: CompactionTrigger = "auto",
    keep_recent_messages: Optional[int] = None,
    min_messages_to_compact: Optional[int] = None,
    before_sequence_no: Optional[int] = None,
    now: Optional[datetime] = None,
) -> CompactionExecutionResult:
    """Compact older uncompacted turns into one active rolling `ConversationSummary`.

    Raw `messages` rows remain untouched and canonical `memories` are never written.
    """
    prior = await get_active_conversation_summary(db, conversation_id, profile_id)
    after_seq = prior.to_sequence_no if prior is not None else 0

    stmt = select(Message).where(
        Message.conversation_id == conversation_id,
        Message.profile_id == profile_id,
        Message.deleted_at.is_(None),
        Message.sequence_no > after_seq,
    )
    if before_sequence_no is not None:
        stmt = stmt.where(Message.sequence_no < before_sequence_no)
    stmt = stmt.order_by(Message.sequence_no.asc())

    uncompacted = list((await db.scalars(stmt)).all())
    if not uncompacted:
        return CompactionExecutionResult(
            summary=prior,
            compacted=False,
            reason="nothing_new_to_compact" if prior is not None else "insufficient_messages",
            active_summary=prior,
        )

    if keep_recent_messages is not None:
        effective_keep = max(0, keep_recent_messages)
    elif force:
        effective_keep = min(
            settings.CONTEXT_COMPACTION_KEEP_RECENT_MESSAGES,
            max(2, len(uncompacted) // 2),
        )
    else:
        effective_keep = max(1, settings.CONTEXT_COMPACTION_KEEP_RECENT_MESSAGES)

    if len(uncompacted) <= effective_keep:
        return CompactionExecutionResult(
            summary=prior,
            compacted=False,
            reason="nothing_new_to_compact" if prior is not None else "insufficient_messages",
            active_summary=prior,
        )

    slice_end = len(uncompacted) - effective_keep if effective_keep > 0 else len(uncompacted)
    to_compact = uncompacted[:slice_end]

    min_req = (
        1
        if (force and min_messages_to_compact is None)
        else (
            settings.CONTEXT_COMPACTION_MIN_MESSAGES
            if min_messages_to_compact is None
            else max(1, min_messages_to_compact)
        )
    )
    if len(to_compact) < min_req:
        return CompactionExecutionResult(
            summary=prior,
            compacted=False,
            reason="insufficient_messages",
            active_summary=prior,
        )

    max_summary_tokens = max(64, settings.CONTEXT_COMPACTION_SUMMARY_MAX_TOKENS)
    max_summary_chars = max_summary_tokens * 4

    llm_digest = await _generate_llm_digest(
        provider=provider,
        prior_summary=prior,
        messages_to_compact=to_compact,
        max_tokens=settings.CONTEXT_COMPACTION_LLM_MAX_TOKENS,
    )
    if llm_digest is not None:
        summary_text = _truncate_clean(llm_digest, max_summary_chars)
        source_value = "manual" if trigger == "manual" else "auto"
    else:
        summary_text = _extractive_episode_digest(
            prior_summary=prior,
            messages_to_compact=to_compact,
            max_chars=max_summary_chars,
        )
        source_value = "extractive_fallback"

    current_now = now or utc_now()

    # Deactivate existing active summary rows first to satisfy partial unique index
    await db.execute(
        update(ConversationSummary)
        .where(
            ConversationSummary.conversation_id == conversation_id,
            ConversationSummary.profile_id == profile_id,
            ConversationSummary.is_active.is_(True),
            ConversationSummary.is_deleted.is_(False),
        )
        .values(is_active=False, updated_at=current_now)
    )
    await db.flush()

    from_seq = prior.from_sequence_no if prior is not None else to_compact[0].sequence_no
    to_seq = to_compact[-1].sequence_no
    total_compacted = (prior.compacted_message_count if prior is not None else 0) + len(to_compact)
    tok_est = estimate_tokens(summary_text)

    new_summary = ConversationSummary(
        profile_id=profile_id,
        conversation_id=conversation_id,
        summary_text=summary_text,
        from_sequence_no=from_seq,
        to_sequence_no=to_seq,
        compacted_message_count=total_compacted,
        token_estimate=tok_est,
        source=source_value,
        is_active=True,
    )
    db.add(new_summary)
    await db.flush()

    return CompactionExecutionResult(
        summary=new_summary,
        compacted=True,
        reason="manual_compacted" if trigger == "manual" else "compacted",
        active_summary=new_summary,
    )


def build_continuation_messages(
    prompt_messages: Sequence[ChatMessage],
    partial_response_text: str,
    tail_chars: int = 320,
    head_summary_chars: int = 280,
) -> list[ChatMessage]:
    """Compact an interrupted reply's head while preserving its exact tail for 1-hop continuation."""
    continuation_messages = list(prompt_messages)
    partial = partial_response_text or ""

    if tail_chars <= 0 or len(partial) <= tail_chars:
        cutoff_tail = partial
        assistant_content = cutoff_tail
    else:
        head_raw = partial[:-tail_chars]
        cutoff_tail = partial[-tail_chars:]
        head_snippet = _truncate_clean(_normalize_single_line(head_raw), head_summary_chars)
        if head_snippet:
            assistant_content = f"[Earlier part of response compacted]: {head_snippet}\n...{cutoff_tail}"
        else:
            assistant_content = cutoff_tail

    tail_anchor = escape_prompt_xml_delimiters(_normalize_single_line(cutoff_tail[-80:]))
    continuation_messages.append(ChatMessage(role="assistant", content=assistant_content))
    continuation_messages.append(
        ChatMessage(
            role="user",
            content=(
                f'Your previous response reached the output length limit and cut off at: "...{tail_anchor}". '
                "Continue seamlessly from that exact cutoff point without repeating earlier text, "
                "and conclude your response cleanly."
            ),
        )
    )
    return continuation_messages
