"""Deterministic bounded emotion, mood decay, and turn appraisal services (PC-CHAR-003, PC-CHAR-004)."""

from app.services.emotion.appraisal import (
    EmotionAppraisalResult,
    EmotionEventType,
    appraise_user_turn,
)
from app.services.emotion.mood_engine import (
    ALLOWED_MOODS,
    CharacterMoodId,
    apply_emotion_transition,
    build_mood_and_grounding_lines,
    rebalance_mood_for_elapsed_time,
    resolve_baseline_mood,
)

__all__ = [
    "ALLOWED_MOODS",
    "CharacterMoodId",
    "EmotionAppraisalResult",
    "EmotionEventType",
    "apply_emotion_transition",
    "appraise_user_turn",
    "build_mood_and_grounding_lines",
    "rebalance_mood_for_elapsed_time",
    "resolve_baseline_mood",
]
