"""REST API, WebSocket duplex voice, D9 parity, Profile isolation, and barge-in tests."""

import asyncio
import base64
from datetime import datetime, timedelta, timezone
import json
import math
import struct
import uuid

from fastapi.testclient import TestClient
import pytest
from sqlalchemy import select
from starlette.websockets import WebSocketDisconnect

from app.core.config import settings
from app.core.profile_sessions import token_hash
from app.core.runtime_lifecycle import runtime_lifecycle
from app.core.storage import prepare_database_schema
from app.db.session import dispose_database_runtime, get_session_factory, initialize_database_runtime
from app.main import app
from app.models.character_template import CharacterTemplate
from app.models.conversation import Conversation
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.models.tool_runtime_config import ToolRuntimeConfig
from app.services.llm.base import GeneratedText, GenerationStream
from app.services.llm.manager import llm_manager
from app.services.voice.audio_utils import MAX_TRANSCRIBE_WAV_BYTES, VAD_FRAME_SAMPLES, pcm16_to_wav_bytes
from app.services.voice.manager import VoiceManager, reset_voice_manager, set_voice_manager
from app.services.voice.stt import MockSttProvider
from app.services.voice.tts import MockTtsProvider
from app.services.voice.vad import AdaptiveEnergyVadProvider


def _tone_pcm16(amplitude: int, num_samples: int = VAD_FRAME_SAMPLES, freq_hz: float = 280.0) -> bytes:
    samples = [
        int(amplitude * math.sin(2.0 * math.pi * freq_hz * i / 16000.0))
        for i in range(num_samples)
    ]
    return struct.pack(f"<{num_samples}h", *samples)


class _SlowStreamingMockProvider:
    def __init__(self) -> None:
        self.mode = "mock"
        self.tool_call_queue: list[list[dict]] = []

    def is_loaded(self) -> bool:
        return True

    async def get_status(self):
        from app.schemas.llm import ModelStatusResponse
        from app.services.llm.runtime_state import LLMRuntimeState

        return ModelStatusResponse(
            provider="mock",
            model_loaded=True,
            model_resident=True,
            model_awake=True,
            active_model="mock-voice-llm",
            runtime_state=LLMRuntimeState.MODEL_READY,
        )

    async def load_model(self) -> bool:
        return True

    def generate_stream(self, messages, temperature: float = 0.7, max_tokens: int = 1024, *, tools=None, **kwargs):
        queued = self.tool_call_queue.pop(0) if self.tool_call_queue else []
        if queued:
            async def _empty():
                if False:
                    yield ""
            return GenerationStream(_empty(), meta={"tool_calls": queued, "finish_reason": "tool_calls"})

        async def _tokens():
            for part in [
                "First sentence completed cleanly. ",
                "Second sentence starts now and keeps streaming slowly. ",
                "Third sentence should be cancelled by barge in.",
            ]:
                await asyncio.sleep(0.06)
                yield part

        return GenerationStream(_tokens(), meta={"finish_reason": "stop"})

    async def generate(self, messages, **kwargs):
        return GeneratedText(content="Okay.", finish_reason="stop")

    async def shutdown(self):
        return None


def _seed_voice_env(monkeypatch):
    prepare_database_schema(settings.DATABASE_PATH)
    p1_id = str(uuid.uuid4())
    p2_id = str(uuid.uuid4())
    tok1 = f"psk_voice_a_{uuid.uuid4().hex}"
    tok2 = f"psk_voice_b_{uuid.uuid4().hex}"
    conv1_id = str(uuid.uuid4())
    conv2_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    async def _seed():
        initialize_database_runtime(settings.DATABASE_URL)
        factory = get_session_factory()
        async with factory() as db:
            tmpl_id = await db.scalar(
                select(CharacterTemplate.id).where(CharacterTemplate.is_neutral_fallback.is_(False)).limit(1)
            )
            assert tmpl_id is not None

            cfg = await db.get(ToolRuntimeConfig, "default")
            if cfg is None:
                db.add(ToolRuntimeConfig(id="default", global_kill_switch=False))
            else:
                cfg.global_kill_switch = False

            db.add(Profile(id=p1_id, name="Profile A", is_default=False, status="active"))
            db.add(Profile(id=p2_id, name="Profile B", is_default=False, status="active"))
            await db.flush()

            db.add(
                ProfileSession(
                    id=str(uuid.uuid4()),
                    profile_id=p1_id,
                    token_hash=token_hash(tok1),
                    client_type="desktop",
                    created_at=now,
                    last_active_at=now,
                    expires_at=now + timedelta(hours=12),
                )
            )
            db.add(
                ProfileSession(
                    id=str(uuid.uuid4()),
                    profile_id=p2_id,
                    token_hash=token_hash(tok2),
                    client_type="desktop",
                    created_at=now,
                    last_active_at=now,
                    expires_at=now + timedelta(hours=12),
                )
            )
            db.add(Conversation(id=conv1_id, profile_id=p1_id, title="Voice Conv A"))
            db.add(Conversation(id=conv2_id, profile_id=p2_id, title="Voice Conv B"))
            await db.commit()
        await dispose_database_runtime()
        return tmpl_id

    tmpl_id = asyncio.run(_seed())

    stt = MockSttProvider(scripted_texts=["Check my voice turn", "Second interrupting turn"])
    tts = MockTtsProvider()
    vad = AdaptiveEnergyVadProvider(sensitivity="medium")
    vm = VoiceManager(stt=stt, vad=vad, tts=tts)
    set_voice_manager(vm)

    fake_llm = _SlowStreamingMockProvider()
    llm_manager.set_provider(fake_llm)  # type: ignore[arg-type]

    return {
        "p1_id": p1_id,
        "p2_id": p2_id,
        "tok1": tok1,
        "tok2": tok2,
        "conv1_id": conv1_id,
        "conv2_id": conv2_id,
        "tmpl_id": tmpl_id,
        "stt": stt,
        "tts": tts,
        "vm": vm,
        "llm": fake_llm,
    }


@pytest.fixture
def voice_test_env(monkeypatch):
    runtime_lifecycle.reset()
    env = _seed_voice_env(monkeypatch)
    try:
        yield env
    finally:
        llm_manager.reset()
        asyncio.run(reset_voice_manager())
        runtime_lifecycle.reset()
        asyncio.run(dispose_database_runtime())


def test_voice_rest_endpoints_auth_settings_character_voice_and_limits(voice_test_env):
    env = voice_test_env
    h1 = {"Authorization": f"Bearer {env['tok1']}"}
    h2 = {"Authorization": f"Bearer {env['tok2']}"}

    with TestClient(app) as client:
        assert client.get("/api/v1/voice/status").status_code == 401
        assert client.get("/api/v1/voice/voices").status_code == 401
        assert client.get("/api/v1/voice/settings").status_code == 401

        status_r = client.get("/api/v1/voice/status", headers=h1)
        assert status_r.status_code == 200
        assert status_r.json()["stt_available"] is True
        assert status_r.json()["tts_provider"] == "mock"

        voices_r = client.get("/api/v1/voice/voices", headers=h1)
        assert voices_r.status_code == 200
        assert any(v["voice_id"] == "af_nicole" for v in voices_r.json()["voices"])

        s1 = client.get("/api/v1/voice/settings", headers=h1)
        assert s1.status_code == 200
        assert s1.json()["proactive_speech_enabled"] is False
        assert s1.json()["auto_read_replies"] is False

        upd = client.patch(
            "/api/v1/voice/settings",
            headers=h1,
            json={"barge_in_policy": "strict_noisy", "vad_sensitivity": "low", "tts_speed": 1.25, "auto_read_replies": True},
        )
        assert upd.status_code == 200
        assert upd.json()["barge_in_policy"] == "strict_noisy"
        assert upd.json()["auto_read_replies"] is True

        # Profile B remains untouched at defaults
        s2 = client.get("/api/v1/voice/settings", headers=h2)
        assert s2.status_code == 200
        assert s2.json()["barge_in_policy"] == "smart_auto"
        assert s2.json()["auto_read_replies"] is False

        assert client.patch("/api/v1/voice/settings", headers=h1, json={"tts_speed": 3.5}).status_code == 422
        assert client.patch("/api/v1/voice/settings", headers=h1, json={"unknown_flag": True}).status_code == 422

        # CharacterInstance.voice_id override & explicit null clear -> Profile default fallback
        created_char = client.post(
            "/api/v1/characters/instances",
            headers=h1,
            json={"template_id": env["tmpl_id"], "name": "VoiceTestChar", "voice_id": "am_michael"},
        )
        assert created_char.status_code == 201
        char_id = created_char.json()["id"]
        assert created_char.json()["voice_id"] == "am_michael"
        assert client.put("/api/v1/characters/active", headers=h1, json={"character_id": char_id}).status_code == 200

        synth_char = client.post("/api/v1/voice/synthesize", headers=h1, json={"text": "Hello from character"})
        assert synth_char.status_code == 200
        assert synth_char.json()["voice_id"] == "am_michael"

        cleared = client.patch(f"/api/v1/characters/instances/{char_id}", headers=h1, json={"voice_id": None})
        assert cleared.status_code == 200
        assert cleared.json()["voice_id"] is None

        synth_default = client.post("/api/v1/voice/synthesize", headers=h1, json={"text": "Hello default"})
        assert synth_default.status_code == 200
        assert synth_default.json()["voice_id"] == "af_nicole"

        wav = pcm16_to_wav_bytes(_tone_pcm16(6000, num_samples=1600), sample_rate=16000)
        tr = client.post(
            "/api/v1/voice/transcribe",
            headers=h1,
            json={"audio_base64": base64.b64encode(wav).decode("ascii"), "format": "wav"},
        )
        assert tr.status_code == 200
        assert tr.json()["text"] == "Check my voice turn"

        bad_tr = client.post(
            "/api/v1/voice/transcribe",
            headers=h1,
            json={"audio_base64": base64.b64encode(b"bad-wav").decode("ascii"), "format": "wav"},
        )
        assert bad_tr.status_code == 422

        oversize_raw = b"\x00" * (MAX_TRANSCRIBE_WAV_BYTES + 4)
        big_tr = client.post(
            "/api/v1/voice/transcribe",
            headers=h1,
            json={"audio_base64": base64.b64encode(oversize_raw).decode("ascii"), "format": "pcm16"},
        )
        assert big_tr.status_code == 422


def test_voice_ws_rejects_unauth_and_cross_profile_hijack(voice_test_env):
    env = voice_test_env
    with TestClient(app) as client:
        with pytest.raises(WebSocketDisconnect) as exc:
            with client.websocket_connect("/api/v1/voice/ws") as ws:
                ws.send_json({"type": "session.start", "session_token": "psk_invalid", "conversation_id": env["conv1_id"]})
                ws.receive_json()
        assert exc.value.code == 4401

        with pytest.raises(WebSocketDisconnect) as exc2:
            with client.websocket_connect("/api/v1/voice/ws") as ws:
                ws.send_json({"type": "session.start", "session_token": env["tok1"], "conversation_id": env["conv2_id"]})
                ws.receive_json()
        assert exc2.value.code in (4401, 4404)


def test_voice_ws_full_turn_d9_parity_and_barge_in_identity(voice_test_env):
    env = voice_test_env

    with TestClient(app) as client:
        with client.websocket_connect("/api/v1/voice/ws") as ws:
            ws.send_json(
                {
                    "type": "session.start",
                    "session_token": env["tok1"],
                    "conversation_id": env["conv1_id"],
                }
            )
            ready = ws.receive_json()
            assert ready["type"] == "session.ready"
            voice_session_id = ready["voice_session_id"]

            ws.send_json({"type": "ping"})
            assert ws.receive_json()["type"] == "pong"

            chunk_b64 = base64.b64encode(_tone_pcm16(7000, num_samples=1600)).decode("ascii")
            ws.send_json({"type": "audio.chunk", "pcm16_base64": chunk_b64})
            ws.send_json({"type": "audio.commit"})

            events = []
            saw_tts_chunk = False
            while len(events) < 25:
                msg = ws.receive_json()
                events.append(msg)
                if msg["type"] == "tts.audio.chunk" and not saw_tts_chunk:
                    saw_tts_chunk = True
                    assert msg["voice_session_id"] == voice_session_id
                    assert msg["turn_id"] == 1
                    ws.send_json({"type": "barge_in", "reason": "manual_barge_in"})
                if msg["type"] in ("turn.cancelled", "error"):
                    break

            assert not any(e["type"] == "error" for e in events), events

            assert saw_tts_chunk is True
            cancelled = [e for e in events if e["type"] == "turn.cancelled"]
            assert len(cancelled) == 1
            assert cancelled[0]["turn_id"] == 1
            assert cancelled[0]["voice_session_id"] == voice_session_id

            env["llm"].tool_call_queue.append(
                [
                    {
                        "id": "call_voice_del",
                        "function": {
                            "name": "delete_task",
                            "arguments": json.dumps({"task_id": "11111111-1111-1111-1111-111111111111"}),
                        },
                    }
                ]
            )
            ws.send_json({"type": "audio.chunk", "pcm16_base64": chunk_b64})
            ws.send_json({"type": "audio.commit"})

            turn2_events = []
            while len(turn2_events) < 30:
                msg = ws.receive_json()
                turn2_events.append(msg)
                if (msg["type"] == "tts.end" and msg.get("turn_id") == 2) or msg["type"] == "error":
                    break

            assert not any(e["type"] == "error" for e in turn2_events), turn2_events
            types2 = [e["type"] for e in turn2_events]
            assert "stt.final" in types2
            assert any(e["turn_id"] == 2 for e in turn2_events if "turn_id" in e)
            assert "tool.intent" in types2
            assert "tool.confirmation_required" in types2

            ws.send_json({"type": "session.stop"})


def test_voice_ws_vad_auto_barge_in_ignores_short_noise_and_fires_on_speech(voice_test_env):
    env = voice_test_env

    with TestClient(app) as client:
        with client.websocket_connect("/api/v1/voice/ws") as ws:
            ws.send_json(
                {
                    "type": "session.start",
                    "session_token": env["tok1"],
                    "conversation_id": env["conv1_id"],
                    "barge_in_policy": "smart_auto",
                    "vad_sensitivity": "medium",
                }
            )
            ready = ws.receive_json()
            assert ready["type"] == "session.ready"

            # Commit Turn 1
            ws.send_json(
                {
                    "type": "audio.chunk",
                    "pcm16_base64": base64.b64encode(_tone_pcm16(7000, num_samples=1600)).decode("ascii"),
                }
            )
            ws.send_json({"type": "audio.commit"})

            saw_tts = False
            while not saw_tts:
                msg = ws.receive_json()
                if msg["type"] == "tts.audio.chunk":
                    saw_tts = True

            # Send 2 brief 512-sample noise frames (< 280ms hold) -> followed by silence -> must NOT cancel
            loud_frame = _tone_pcm16(10000, num_samples=VAD_FRAME_SAMPLES)
            silent_frame = b"\x00\x00" * VAD_FRAME_SAMPLES
            for frame in (loud_frame, loud_frame, silent_frame, silent_frame):
                ws.send_bytes(frame)

            # Now send 10 consecutive loud speech frames (~320ms >= 280ms hold) -> triggers vad_barge_in!
            for _ in range(10):
                ws.send_bytes(loud_frame)

            events = []
            while len(events) < 25:
                msg = ws.receive_json()
                events.append(msg)
                if msg["type"] in ("turn.cancelled", "error"):
                    break

            assert not any(e["type"] == "error" for e in events), events

            cancelled = [e for e in events if e["type"] == "turn.cancelled"]
            assert len(cancelled) == 1
            assert cancelled[0]["reason"] == "vad_barge_in"
            assert cancelled[0]["turn_id"] == 1

            ws.send_json({"type": "session.stop"})


def test_voice_ws_session_killed_on_revoke_and_buffers_cleared(voice_test_env):
    env = voice_test_env

    with TestClient(app) as client:
        with client.websocket_connect("/api/v1/voice/ws") as ws:
            ws.send_json(
                {
                    "type": "session.start",
                    "session_token": env["tok1"],
                    "conversation_id": env["conv1_id"],
                }
            )
            ready = ws.receive_json()
            assert ready["type"] == "session.ready"
            vsid = ready["voice_session_id"]

            # Buffer some partial audio in RAM
            ws.send_bytes(_tone_pcm16(5000, num_samples=VAD_FRAME_SAMPLES))
            ws.send_json({"type": "ping"})
            assert ws.receive_json()["type"] == "pong"

            active_orch = env["vm"]._active_sessions.get(vsid)
            assert active_orch is not None
            assert active_orch.buffered_audio_bytes > 0

            # Revoking the Profile session immediately kills the live voice session and clears RAM buffers
            rev = client.post("/api/v1/auth/session/revoke", headers={"Authorization": f"Bearer {env['tok1']}"})
            assert rev.status_code == 204
            assert active_orch.buffered_audio_bytes == 0

            with pytest.raises(WebSocketDisconnect) as disc:
                ws.receive_json()
            assert disc.value.code == 4401


def test_voice_ws_hands_free_vad_auto_commits_after_silence_without_commit(voice_test_env):
    env = voice_test_env

    with TestClient(app) as client:
        with client.websocket_connect("/api/v1/voice/ws") as ws:
            ws.send_json(
                {
                    "type": "session.start",
                    "session_token": env["tok1"],
                    "conversation_id": env["conv1_id"],
                }
            )
            ready = ws.receive_json()
            assert ready["type"] == "session.ready"
            vsid = ready["voice_session_id"]
            orch = env["vm"]._active_sessions[vsid]

            # Stream two 4-frame speech bursts separated by a brief 20-frame (~640ms) thinking pause
            # -> must NOT auto-commit early; only >=40 trailing silence frames auto-commits the full turn!
            loud_frame = _tone_pcm16(9000, num_samples=VAD_FRAME_SAMPLES)
            silent_frame = b"\x00\x00" * VAD_FRAME_SAMPLES
            for _ in range(4):
                ws.send_bytes(loud_frame)
            for _ in range(20):
                ws.send_bytes(silent_frame)
            ws.send_json({"type": "ping"})
            while True:
                pause_msg = ws.receive_json()
                if pause_msg["type"] == "pong":
                    break
            assert orch._active_turn_id == 0

            for _ in range(4):
                ws.send_bytes(loud_frame)
            for _ in range(42):
                ws.send_bytes(silent_frame)

            # Fail fast without blocking forever if VAD auto-commit did not start a turn
            ws.send_json({"type": "ping"})
            events = []
            while len(events) < 10:
                msg = ws.receive_json()
                events.append(msg)
                if msg["type"] == "pong":
                    break
            assert orch._active_turn_id == 1

            while len(events) < 25:
                if any(e.get("type") in ("tts.end", "error") for e in events):
                    break
                msg = ws.receive_json()
                events.append(msg)
                if msg["type"] in ("tts.end", "error"):
                    break

            assert not any(e["type"] == "error" for e in events), events
            types = [e["type"] for e in events]
            assert "stt.final" in types
            assert "tts.audio.chunk" in types
            assert "tts.end" in types

            ws.send_json({"type": "session.stop"})


def test_voice_ws_discards_non_interrupting_speaker_bleed_while_speaking(voice_test_env):
    env = voice_test_env

    with TestClient(app) as client:
        with client.websocket_connect("/api/v1/voice/ws") as ws:
            ws.send_json(
                {
                    "type": "session.start",
                    "session_token": env["tok1"],
                    "conversation_id": env["conv1_id"],
                    "barge_in_policy": "manual_only",
                }
            )
            ready = ws.receive_json()
            assert ready["type"] == "session.ready"
            vsid = ready["voice_session_id"]
            orch = env["vm"]._active_sessions[vsid]

            # Hold speaking gate True as while assistant playback is active
            orch._barge_in_gate.set_speaking(True, assistant_output_rms=0.05)
            for _ in range(5):
                ws.send_bytes(_tone_pcm16(500, num_samples=VAD_FRAME_SAMPLES))
            ws.send_json({"type": "ping"})
            assert ws.receive_json()["type"] == "pong"

            assert orch.buffered_audio_bytes == 0
            ws.send_json({"type": "session.stop"})

