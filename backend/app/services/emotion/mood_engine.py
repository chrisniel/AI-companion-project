"""Persistent bounded mood state machine and elapsed-time rebalancing (PC-CHAR-003)."""

from datetime import datetime, timezone
from typing import Any, Literal, Optional

CharacterMoodId = Literal[
    "calm",
    "cheerful",
    "playful",
    "thoughtful",
    "empathetic",
    "curious",
    "attentive",
]

ALLOWED_MOODS: tuple[CharacterMoodId, ...] = (
    "calm",
    "cheerful",
    "playful",
    "thoughtful",
    "empathetic",
    "curious",
    "attentive",
)

DEFAULT_MOOD: CharacterMoodId = "calm"
EQUILIBRIUM_INTENSITY: int = 50
DECAY_STEP_SECONDS: int = 1800  # 30 minutes
DECAY_STEP_POINTS: int = 5
BASELINE_SETTLE_SECONDS: int = 14400  # 4 hours

_MOOD_DESCRIPTORS: dict[str, str] = {
    "calm": "relaxed, steady, and grounded",
    "cheerful": "upbeat, bright, and genuinely glad to talk",
    "playful": "witty, lightly mischievous, and enjoying friendly banter",
    "thoughtful": "reflective, attentive to nuance, and measured",
    "empathetic": "gentle, emotionally supportive, and caring",
    "curious": "inquisitive, engaged, and eager to explore the topic",
    "attentive": "focused, composed, and responsive",
}


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def clamp_intensity(value: int) -> int:
    return max(0, min(100, int(value)))


def resolve_baseline_mood(traits_source: Optional[Any] = None) -> CharacterMoodId:
    """Derive a character's natural resting mood from its personality trait vector."""
    if traits_source is None:
        return DEFAULT_MOOD

    warmth = getattr(traits_source, "warmth", None)
    teasing = getattr(traits_source, "teasing", None)
    guardedness = getattr(traits_source, "guardedness", None)
    formality = getattr(traits_source, "formality", None)

    warmth_val = 50 if warmth is None else int(warmth)
    teasing_val = 50 if teasing is None else int(teasing)
    guarded_val = 50 if guardedness is None else int(guardedness)
    formal_val = 50 if formality is None else int(formality)

    if teasing_val >= 75 and guarded_val < 60 and teasing_val >= warmth_val:
        return "playful"
    if warmth_val >= 75 and guarded_val < 60:
        return "cheerful"
    if formal_val >= 75:
        return "attentive"
    return "calm"


def rebalance_mood_for_elapsed_time(
    current_mood: Optional[str],
    mood_intensity: Optional[int],
    mood_updated_at: Optional[datetime],
    now: datetime,
    baseline_mood: CharacterMoodId = DEFAULT_MOOD,
) -> tuple[CharacterMoodId, int, bool]:
    """Rebalance mood intensity toward 50 and settle mood to baseline after extended absence.

    Per canonical spec `characters-personality-and-emotion.md` §2.1.5, uses deterministic
    integer step decay (5 points per 30 minutes toward equilibrium 50; settles to baseline
    mood when elapsed >= 4 hours and intensity reaches 50).
    """
    valid_mood: CharacterMoodId = (
        current_mood if current_mood in ALLOWED_MOODS else baseline_mood  # type: ignore[assignment]
    )
    intensity = clamp_intensity(EQUILIBRIUM_INTENSITY if mood_intensity is None else mood_intensity)

    if mood_updated_at is None:
        changed = (current_mood != valid_mood) or (mood_intensity != intensity)
        return valid_mood, intensity, changed

    now_utc = _ensure_utc(now)
    updated_utc = _ensure_utc(mood_updated_at)
    elapsed_seconds = max(0.0, (now_utc - updated_utc).total_seconds())

    steps = int(elapsed_seconds // DECAY_STEP_SECONDS)
    if steps <= 0:
        changed = (current_mood != valid_mood) or (mood_intensity != intensity)
        return valid_mood, intensity, changed

    total_decay = steps * DECAY_STEP_POINTS
    if intensity > EQUILIBRIUM_INTENSITY:
        new_intensity = max(EQUILIBRIUM_INTENSITY, intensity - total_decay)
    elif intensity < EQUILIBRIUM_INTENSITY:
        new_intensity = min(EQUILIBRIUM_INTENSITY, intensity + total_decay)
    else:
        new_intensity = EQUILIBRIUM_INTENSITY

    new_mood: CharacterMoodId = valid_mood
    if elapsed_seconds >= BASELINE_SETTLE_SECONDS and new_intensity == EQUILIBRIUM_INTENSITY:
        new_mood = baseline_mood

    did_change = (new_mood != current_mood) or (new_intensity != mood_intensity)
    return new_mood, new_intensity, did_change


def apply_emotion_transition(
    current_mood: Optional[str],
    mood_intensity: Optional[int],
    target_mood: Optional[CharacterMoodId],
    delta_intensity: int,
    traits_source: Optional[Any] = None,
) -> tuple[CharacterMoodId, int]:
    """Apply a bounded turn-appraisal transition modulated by character traits."""
    baseline = resolve_baseline_mood(traits_source)
    active_mood: CharacterMoodId = (
        current_mood if current_mood in ALLOWED_MOODS else baseline  # type: ignore[assignment]
    )
    active_intensity = clamp_intensity(
        EQUILIBRIUM_INTENSITY if mood_intensity is None else mood_intensity
    )

    adjusted_delta = int(delta_intensity)
    if traits_source is not None and adjusted_delta > 0:
        expressiveness = getattr(traits_source, "expressiveness", None)
        guardedness = getattr(traits_source, "guardedness", None)
        if guardedness is not None and int(guardedness) >= 75:
            adjusted_delta = max(4, int(round(adjusted_delta * 0.7)))
        elif expressiveness is not None and int(expressiveness) >= 75:
            adjusted_delta = min(25, int(round(adjusted_delta * 1.15)))

    if target_mood is None:
        # Neutral turn: gently step intensity 2 points toward equilibrium 50
        if active_intensity > EQUILIBRIUM_INTENSITY:
            next_intensity = max(EQUILIBRIUM_INTENSITY, active_intensity - 2)
        elif active_intensity < EQUILIBRIUM_INTENSITY:
            next_intensity = min(EQUILIBRIUM_INTENSITY, active_intensity + 2)
        else:
            next_intensity = EQUILIBRIUM_INTENSITY
        return active_mood, next_intensity

    if target_mood == "playful" and traits_source is not None:
        teasing = getattr(traits_source, "teasing", None)
        if teasing is not None and int(teasing) < 30:
            target_mood = "cheerful"

    if target_mood == active_mood:
        next_intensity = max(25, min(90, active_intensity + adjusted_delta))
        return active_mood, next_intensity

    # Transitioning to a new mood starts at a grounded moderate-to-warm intensity
    base_shift_intensity = 52 + max(0, adjusted_delta // 2)
    next_intensity = max(35, min(85, base_shift_intensity))
    return target_mood, next_intensity


def build_mood_and_grounding_lines(
    current_mood: Optional[str],
    mood_intensity: Optional[int],
) -> list[str]:
    """Build compact prompt instructions for current mood and natural companion grounding.

    Strictly obeys D11 Mood Isolation: modulates conversational style and tone only;
    never alters factual truthfulness, memory recall, permissions, or tool policies.
    """
    mood_key = current_mood if current_mood in _MOOD_DESCRIPTORS else DEFAULT_MOOD
    intensity = clamp_intensity(EQUILIBRIUM_INTENSITY if mood_intensity is None else mood_intensity)
    desc = _MOOD_DESCRIPTORS[mood_key]

    if intensity >= 70:
        band = "strong"
    elif intensity <= 35:
        band = "subtle"
    else:
        band = "moderate"

    return [
        f"- Current Mood: {mood_key} ({band} intensity, {intensity}/100) — let a {desc} undertone color your phrasing.",
        "- Conversational Grounding: Speak naturally like a real companion in direct dialogue. Never use asterisk stage directions (*smiles*, *sighs*), scripted self-interruptions ('Wait... nope!'), or repetitive catchphrases.",
    ]
