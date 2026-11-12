"""Unit and integration tests for persistent mood engine, turn appraisal, grounding, and DRY/stream guard (PC-CHAR-003, PC-CHAR-004)."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch
import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.conversation import Conversation
from app.models.profile_session import ProfileSession
from app.schemas.character import CharacterInstanceCreate, CharacterTraitVector
from app.schemas.llm import ChatMessage
from app.services.assistant.orchestrator import _guard_repetitive_stream
from app.services.character_service import (
    PRESET_REGISTRY,
    appraise_and_update_conversation_mood,
    create_character_instance,
    get_profile_character_instance,
    resolve_turn_persona_prompt,
)
from app.services.emotion import (
    apply_emotion_transition,
    appraise_user_turn,
    build_mood_and_grounding_lines,
    rebalance_mood_for_elapsed_time,
    resolve_baseline_mood,
)
from app.services.llm.llama_cpp import LlamaCppProvider
from app.services.llm.runtime_state import LLMRuntimeState


def test_resolve_baseline_mood_from_traits():
    """Verify baseline resting mood derivation from character traits."""
    assert resolve_baseline_mood(None) == "calm"
    assert resolve_baseline_mood(PRESET_REGISTRY["warm_companion"]["traits"]) == "cheerful"
    assert resolve_baseline_mood(PRESET_REGISTRY["playful"]["traits"]) == "playful"
    assert resolve_baseline_mood(PRESET_REGISTRY["formal_advisor"]["traits"]) == "attentive"
    assert resolve_baseline_mood(PRESET_REGISTRY["kuudere"]["traits"]) == "calm"
    assert resolve_baseline_mood(PRESET_REGISTRY["tsundere"]["traits"]) == "calm"


def test_rebalance_mood_for_elapsed_time_deterministic_step_decay():
    """Verify 5-point step decay per 30 minutes and 4-hour baseline settlement."""
    t0 = datetime(2026, 11, 12, 10, 0, 0, tzinfo=timezone.utc)

    # < 30 minutes: no decay
    m, i, changed = rebalance_mood_for_elapsed_time(
        "empathetic", 75, t0, t0 + timedelta(minutes=20), baseline_mood="calm"
    )
    assert (m, i, changed) == ("empathetic", 75, False)

    # 1 hour (2 steps = -10 points): 75 -> 65, retains mood
    m, i, changed = rebalance_mood_for_elapsed_time(
        "empathetic", 75, t0, t0 + timedelta(hours=1), baseline_mood="calm"
    )
    assert (m, i, changed) == ("empathetic", 65, True)

    # 2.5 hours (5 steps = -25 points): 75 -> 50, still < 4 hours so mood remains empathetic
    m, i, changed = rebalance_mood_for_elapsed_time(
        "empathetic", 75, t0, t0 + timedelta(minutes=150), baseline_mood="calm"
    )
    assert (m, i, changed) == ("empathetic", 50, True)

    # >= 4 hours and intensity reaches 50: settles back to character's baseline mood
    m, i, changed = rebalance_mood_for_elapsed_time(
        "empathetic", 75, t0, t0 + timedelta(hours=4), baseline_mood="cheerful"
    )
    assert (m, i, changed) == ("cheerful", 50, True)

    # Below-50 intensity steps UP toward 50
    m, i, changed = rebalance_mood_for_elapsed_time(
        "thoughtful", 35, t0, t0 + timedelta(minutes=60), baseline_mood="calm"
    )
    assert (m, i, changed) == ("thoughtful", 45, True)


def test_appraise_user_turn_categories():
    """Verify deterministic <1ms appraisal across conversational cues."""
    r_distress = appraise_user_turn("I had such a rough day and feel completely overwhelmed.")
    assert r_distress.event_type == "user_distress"
    assert r_distress.target_mood == "empathetic"
    assert r_distress.intensity_delta == 15

    r_playful = appraise_user_turn("Haha you're just teasing me now lol 😂")
    assert r_playful.event_type == "user_playful"
    assert r_playful.target_mood == "playful"
    assert r_playful.intensity_delta == 12

    r_gratitude = appraise_user_turn("Thank you so much! That is awesome news, I passed!")
    assert r_gratitude.event_type == "user_gratitude"
    assert r_gratitude.target_mood == "cheerful"
    assert r_gratitude.intensity_delta == 12

    r_analytical = appraise_user_turn("Let's think through the architecture tradeoffs from first principles.")
    assert r_analytical.event_type == "user_analytical"
    assert r_analytical.target_mood == "thoughtful"
    assert r_analytical.intensity_delta == 10

    r_curious = appraise_user_turn("What if we explored binary stars? Tell me about how they form?")
    assert r_curious.event_type == "user_curiosity"
    assert r_curious.target_mood == "curious"
    assert r_curious.intensity_delta == 10

    r_neutral = appraise_user_turn("Got it, let's check the next item on the list.")
    assert r_neutral.event_type == "neutral_turn"
    assert r_neutral.target_mood is None


def test_apply_emotion_transition_trait_modulation():
    """Verify guardedness dampens, expressiveness boosts, and low-teasing redirects playful to cheerful."""
    low_tease_traits = PRESET_REGISTRY["formal_advisor"]["traits"]  # teasing=10
    mood, intensity = apply_emotion_transition("attentive", 50, "playful", 12, low_tease_traits)
    assert mood == "cheerful"
    assert 50 <= intensity <= 85

    # Repeating the same mood accumulates bounded intensity up to 90
    warm_traits = PRESET_REGISTRY["warm_companion"]["traits"]  # expressiveness=75
    mood2, intensity2 = apply_emotion_transition("cheerful", 60, "cheerful", 12, warm_traits)
    assert mood2 == "cheerful"
    assert intensity2 > 60


@pytest.mark.asyncio
async def test_turn_appraisal_persists_mood_and_injects_grounding_in_persona_prompt(
    test_session: AsyncSession,
    profile_session: ProfileSession,
):
    """Verify pre-generation turn appraisal updates SQLite mood and injects grounding inside <character_persona>."""
    instance = await create_character_instance(
        test_session,
        profile_session,
        CharacterInstanceCreate(
            template_id="warm-companion",
            preset_id="warm_companion",
            name="Lyra",
            summary="A caring companion.",
            system_prompt="Be supportive and natural.",
            lore="Loves stargazing.",
        ),
    )
    assert instance.current_mood == "cheerful"
    assert instance.mood_intensity == 50

    conv = Conversation(
        id=str(uuid.uuid4()),
        profile_id=profile_session.profile_id,
        title="Evening Check-in",
        character_id=instance.id,
        character_instance_id=instance.id,
    )
    test_session.add(conv)
    await test_session.commit()

    # User expresses distress -> companion shifts to empathetic before prompt resolution
    updated = await appraise_and_update_conversation_mood(
        test_session,
        profile_session,
        conv,
        "I had a terrible day and feel really stressed and exhausted.",
    )
    assert updated is not None
    assert updated.current_mood == "empathetic"
    assert updated.mood_intensity is not None and updated.mood_intensity > 50

    # Verify persisted via GET service
    fetched = await get_profile_character_instance(test_session, profile_session, instance.id)
    assert fetched.current_mood == "empathetic"

    # Verify resolve_turn_persona_prompt includes Current Mood and Conversational Grounding inside <character_persona>
    prompt = await resolve_turn_persona_prompt(test_session, profile_session, conv)
    assert "- Current Mood: empathetic" in prompt
    assert "- Conversational Grounding: Speak naturally like a real companion in direct dialogue." in prompt
    assert "Never use asterisk stage directions" in prompt
    assert prompt.endswith("</character_persona>")


@pytest.mark.asyncio
async def test_guard_repetitive_stream_cuts_off_4gram_loop():
    """Verify sliding-window stream circuit breaker halts when a 4-word phrase repeats >= 3 times."""
    async def _runaway_tokens():
        chunks = [
            "Wait no I mean ",
            "let me think, ",
            "wait no I mean ",
            "actually hold on, ",
            "wait no I mean ",
            "this should never be yielded!",
        ]
        for c in chunks:
            yield c

    state = {}
    collected = []
    async for tok in _guard_repetitive_stream(_runaway_tokens(), state=state):
        collected.append(tok)

    joined = "".join(collected)
    assert "this should never be yielded!" not in joined
    assert state.get("repetition_cutoff") is True
    assert state.get("finish_reason") == "repetition_cutoff"


@pytest.mark.asyncio
async def test_guard_repetitive_stream_allows_normal_conversation():
    """Verify normal expressive companion responses pass through untouched."""
    async def _normal_tokens():
        for word in ["Hey ", "there! ", "I'm ", "really ", "glad ", "you ", "asked ", "about ", "that."]:
            yield word

    state = {}
    collected = [tok async for tok in _guard_repetitive_stream(_normal_tokens(), state=state)]
    assert "".join(collected) == "Hey there! I'm really glad you asked about that."
    assert state.get("repetition_cutoff") is None


@pytest.mark.asyncio
async def test_llama_cpp_server_payload_includes_dry_sampling_params():
    """Verify standalone llama-server HTTP payload includes DRY anti-repetition parameters."""
    provider = LlamaCppProvider()
    provider._server_is_active = True
    provider._runtime_state = LLMRuntimeState.MODEL_READY
    provider._active_model_name = "Qwen2.5-7B-Instruct"

    captured_payloads = []

    class _FakeResponse:
        is_success = True

        def json(self):
            return {
                "choices": [
                    {
                        "message": {"content": "Hello!"},
                        "finish_reason": "stop",
                    }
                ]
            }

    class _FakeClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def post(self, url, json=None):
            captured_payloads.append(json)
            return _FakeResponse()

    with patch("app.services.llm.llama_cpp.httpx.AsyncClient", _FakeClient):
        res = await provider.generate([ChatMessage(role="user", content="Hi")])
        assert res == "Hello!"

    assert len(captured_payloads) == 1
    payload = captured_payloads[0]
    assert payload["dry_multiplier"] == 0.8
    assert payload["dry_base"] == 1.75
    assert payload["dry_allowed_length"] == 2
    assert payload["dry_penalty_last_n"] == 128
    assert payload["repeat_penalty"] == 1.15
    assert payload["min_p"] == 0.05
