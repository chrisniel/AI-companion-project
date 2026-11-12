"""Deterministic pre-generation turn appraisal engine and typed emotion events (PC-CHAR-004)."""

from dataclasses import dataclass
import re
from typing import Literal, Optional

from app.services.emotion.mood_engine import CharacterMoodId

EmotionEventType = Literal[
    "user_distress",
    "user_gratitude",
    "user_playful",
    "user_analytical",
    "user_curiosity",
    "neutral_turn",
]


@dataclass(frozen=True)
class EmotionAppraisalResult:
    """Typed appraisal output for a single user conversational turn."""

    event_type: EmotionEventType
    target_mood: Optional[CharacterMoodId]
    intensity_delta: int
    reason: str


_DISTRESS_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"\b(overwhelmed|stressed|exhausted|anxious|depressed|lonely|heartbroken|devastated)\b",
        r"\b(rough day|hard day|bad day|terrible day|awful day)\b",
        r"\b(burn(?:ed|t)? out|burnout|tired of everything|feeling down|feel awful)\b",
        r"\b(crying|scared|terrified|struggling|so frustrated|really sad|so sad)\b",
    )
)

_GRATITUDE_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"\b(thank you|thanks so much|tysm|really appreciate|appreciate it|grateful)\b",
        r"\b(you(?:'re| are) the best|awesome|amazing|wonderful|great news|good news)\b",
        r"\b(so happy|really happy|excited|thrilled|yay|horray|hooray|we did it|i passed)\b",
    )
)

_PLAYFUL_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"\b(haha+|hehe+|lol+|lmao+|rofl)\b",
        r"\b(just kidding|teasing|joking|roast me|bet you can't|silly|banter)\b",
        r"[😜😂🤣😉😆]",
    )
)

_ANALYTICAL_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"\b(philosophy|philosophical|meaning of life|deep down|in retrospect|reflecting on)\b",
        r"\b(trade-?offs?|architecture|first principles|analyze|let's think through|perspective)\b",
        r"\b(why do people|human nature|morally|ethically)\b",
    )
)

_CURIOSITY_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"\b(what if|how does|how do|why does|why is|have you ever|curious about)\b",
        r"\b(tell me about|what do you think|wonder if|wonder how|explain how)\b",
    )
)


def appraise_user_turn(user_text: str) -> EmotionAppraisalResult:
    """Appraise user message text into a bounded typed emotion event in <1ms."""
    cleaned = (user_text or "").strip()
    if not cleaned:
        return EmotionAppraisalResult(
            event_type="neutral_turn",
            target_mood=None,
            intensity_delta=0,
            reason="Empty or whitespace user turn",
        )

    for pattern in _DISTRESS_PATTERNS:
        if pattern.search(cleaned):
            return EmotionAppraisalResult(
                event_type="user_distress",
                target_mood="empathetic",
                intensity_delta=15,
                reason="User expressed distress, fatigue, or vulnerability",
            )

    for pattern in _PLAYFUL_PATTERNS:
        if pattern.search(cleaned):
            return EmotionAppraisalResult(
                event_type="user_playful",
                target_mood="playful",
                intensity_delta=12,
                reason="User used humor, laughter, or playful banter",
            )

    for pattern in _GRATITUDE_PATTERNS:
        if pattern.search(cleaned):
            return EmotionAppraisalResult(
                event_type="user_gratitude",
                target_mood="cheerful",
                intensity_delta=12,
                reason="User expressed gratitude, warmth, or celebration",
            )

    for pattern in _ANALYTICAL_PATTERNS:
        if pattern.search(cleaned):
            return EmotionAppraisalResult(
                event_type="user_analytical",
                target_mood="thoughtful",
                intensity_delta=10,
                reason="User initiated reflective or analytical discussion",
            )

    if "?" in cleaned:
        for pattern in _CURIOSITY_PATTERNS:
            if pattern.search(cleaned):
                return EmotionAppraisalResult(
                    event_type="user_curiosity",
                    target_mood="curious",
                    intensity_delta=10,
                    reason="User asked an exploratory or inquisitive question",
                )

    return EmotionAppraisalResult(
        event_type="neutral_turn",
        target_mood=None,
        intensity_delta=0,
        reason="Standard conversational turn; gentle homeostasis toward baseline",
    )
