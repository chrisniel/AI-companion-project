"""Voice Activity Detection providers and anti-false-trigger BargeInGate."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
import math
from pathlib import Path
from typing import Any, Optional

from app.services.voice.audio_utils import (
    VAD_FRAME_MS,
    VAD_FRAME_SAMPLES,
    VOICE_SAMPLE_RATE,
    compute_pcm16_rms,
    compute_zero_crossing_rate,
)

SENSITIVITY_THRESHOLDS: dict[str, tuple[float, float]] = {
    # (speech_prob_threshold, min_rms_threshold)
    "high": (0.42, 0.012),
    "medium": (0.55, 0.020),
    "low": (0.68, 0.032),
}

POLICY_HOLD_MS: dict[str, Optional[int]] = {
    "smart_auto": 280,
    "strict_noisy": 400,
    "manual_only": None,
}


@dataclass(frozen=True)
class VadFrameResult:
    """Single-frame speech evaluation outcome."""

    probability: float
    is_speech: bool
    rms: float
    provider: str


class VadProvider(ABC):
    """Abstract interface for frame-by-frame Voice Activity Detection."""

    name: str = "abstract"

    @abstractmethod
    def is_available(self) -> bool:
        """Return True when the VAD provider is ready to score audio frames."""

    @abstractmethod
    def evaluate_frame(self, pcm16_frame: bytes) -> VadFrameResult:
        """Evaluate one 16kHz mono PCM16 frame (~32ms / 512 samples)."""

    def reset(self) -> None:
        """Reset any recurrent hidden state between turns."""


class AdaptiveEnergyVadProvider(VadProvider):
    """Deterministic zero-dependency RMS + zero-crossing-rate VAD with noise-floor adaptation."""

    name = "adaptive_energy"

    def __init__(self, sensitivity: str = "medium") -> None:
        self.sensitivity = sensitivity if sensitivity in SENSITIVITY_THRESHOLDS else "medium"
        self._noise_floor = 0.008

    def is_available(self) -> bool:
        return True

    def reset(self) -> None:
        self._noise_floor = 0.008

    def evaluate_frame(self, pcm16_frame: bytes) -> VadFrameResult:
        rms = compute_pcm16_rms(pcm16_frame)
        zcr = compute_zero_crossing_rate(pcm16_frame)
        prob_thresh, rms_floor = SENSITIVITY_THRESHOLDS[self.sensitivity]

        # Track ambient noise floor slowly when frames sit near background levels.
        dynamic_gate = max(rms_floor, self._noise_floor * 2.2)
        if rms < dynamic_gate:
            self._noise_floor = 0.90 * self._noise_floor + 0.10 * max(0.002, rms)

        # Voiced human speech predominantly falls well below noisy broadband hiss/clicks in ZCR.
        zcr_factor = 1.0 if zcr <= 0.35 else max(0.35, 1.0 - (zcr - 0.35) * 1.4)
        snr_ratio = rms / max(0.004, self._noise_floor)
        raw_score = 1.0 / (1.0 + math.exp(-0.9 * (snr_ratio - 3.0)))
        probability = max(0.0, min(1.0, raw_score * zcr_factor))
        if rms < rms_floor:
            probability = min(probability, 0.25)

        return VadFrameResult(
            probability=probability,
            is_speech=(probability >= prob_thresh and rms >= rms_floor),
            rms=rms,
            provider=self.name,
        )


class SileroOnnxVadProvider(VadProvider):
    """Optional Silero VAD ONNX provider; gracefully inactive unless onnxruntime+numpy+model exist."""

    name = "silero_onnx"
    _CONTEXT_SAMPLES = 64

    def __init__(
        self,
        model_path: Optional[Path] = None,
        *,
        sensitivity: str = "medium",
        session: Any = None,
    ) -> None:
        self.model_path = model_path
        self.sensitivity = sensitivity if sensitivity in SENSITIVITY_THRESHOLDS else "medium"
        self._session = session
        self._np: Any = None
        self._state: Any = None
        self._context: Any = None
        self._init_error: Optional[str] = None
        if self._session is None:
            self._try_init_lazy()
        else:
            self._ensure_np_and_state()

    def _ensure_np_and_state(self) -> None:
        try:
            import numpy as np  # type: ignore[import-not-found]
        except Exception as exc:
            self._init_error = f"numpy unavailable: {exc}"
            self._np = None
            return
        self._np = np
        self.reset()

    def _try_init_lazy(self) -> None:
        if self.model_path is None or not Path(self.model_path).is_file():
            self._init_error = "silero_vad.onnx model file not staged"
            return
        try:
            import numpy as np  # type: ignore[import-not-found]
            import onnxruntime as ort  # type: ignore[import-not-found]
        except Exception as exc:
            self._init_error = f"onnxruntime/numpy unavailable: {exc}"
            return
        self._np = np
        opts = ort.SessionOptions()
        opts.inter_op_num_threads = 1
        opts.intra_op_num_threads = 1
        self._session = ort.InferenceSession(
            str(self.model_path),
            sess_options=opts,
            providers=["CPUExecutionProvider"],
        )
        self.reset()

    @property
    def unavailable_reason(self) -> Optional[str]:
        return self._init_error

    def is_available(self) -> bool:
        return self._session is not None and self._np is not None

    def reset(self) -> None:
        if self._np is not None:
            self._state = self._np.zeros((2, 1, 128), dtype=self._np.float32)
            self._context = self._np.zeros((1, self._CONTEXT_SAMPLES), dtype=self._np.float32)

    def evaluate_frame(self, pcm16_frame: bytes) -> VadFrameResult:
        if not self.is_available():
            raise RuntimeError(self._init_error or "Silero ONNX provider is not available")
        np = self._np
        samples = np.frombuffer(pcm16_frame, dtype="<i2").astype(np.float32) / 32768.0
        if len(samples) != VAD_FRAME_SAMPLES:
            if len(samples) < VAD_FRAME_SAMPLES:
                samples = np.pad(samples, (0, VAD_FRAME_SAMPLES - len(samples)))
            else:
                samples = samples[:VAD_FRAME_SAMPLES]
        frame_batch = samples.reshape(1, VAD_FRAME_SAMPLES)
        if self._context is None:
            self._context = np.zeros((1, self._CONTEXT_SAMPLES), dtype=np.float32)
        audio_input = np.concatenate([self._context, frame_batch], axis=1)
        self._context = frame_batch[:, -self._CONTEXT_SAMPLES :]
        sr_tensor = np.array(VOICE_SAMPLE_RATE, dtype=np.int64)
        inputs = {"input": audio_input, "state": self._state, "sr": sr_tensor}
        out, new_state = self._session.run(None, inputs)
        self._state = new_state
        prob = float(out[0][0]) if hasattr(out[0], "__len__") else float(out[0])
        rms = compute_pcm16_rms(pcm16_frame)
        prob_thresh, rms_floor = SENSITIVITY_THRESHOLDS[self.sensitivity]
        return VadFrameResult(
            probability=max(0.0, min(1.0, prob)),
            is_speech=(prob >= prob_thresh and rms >= rms_floor * 0.6),
            rms=rms,
            provider=self.name,
        )


class BargeInGate:
    """Anti-false-trigger speech-hold state machine protecting active TTS from brief noises."""

    def __init__(
        self,
        *,
        vad: VadProvider,
        policy: str = "smart_auto",
        sensitivity: str = "medium",
        frame_ms: int = VAD_FRAME_MS,
    ) -> None:
        self.vad = vad
        self.policy = policy if policy in POLICY_HOLD_MS else "smart_auto"
        self.sensitivity = sensitivity if sensitivity in SENSITIVITY_THRESHOLDS else "medium"
        self.frame_ms = max(10, frame_ms)
        self.is_speaking: bool = False
        self.assistant_output_rms: float = 0.0
        self._speech_frames: int = 0
        self._gap_frames: int = 0
        self._triggered: bool = False

    def configure(self, *, policy: Optional[str] = None, sensitivity: Optional[str] = None) -> None:
        if policy in POLICY_HOLD_MS:
            self.policy = policy
        if sensitivity in SENSITIVITY_THRESHOLDS:
            self.sensitivity = sensitivity
            if hasattr(self.vad, "sensitivity"):
                setattr(self.vad, "sensitivity", sensitivity)

    def set_speaking(self, speaking: bool, *, assistant_output_rms: float = 0.0) -> None:
        self.is_speaking = speaking
        self.assistant_output_rms = max(0.0, min(1.0, assistant_output_rms))
        if not speaking:
            self.reset_hold()

    def reset_hold(self) -> None:
        self._speech_frames = 0
        self._gap_frames = 0
        self._triggered = False

    def required_hold_frames(self) -> Optional[int]:
        hold_ms = POLICY_HOLD_MS[self.policy]
        if hold_ms is None:
            return None
        return max(1, math.ceil(hold_ms / float(self.frame_ms)))

    def process_pcm16_frame(self, pcm16_frame: bytes) -> bool:
        """Evaluate an incoming mic frame while speaking; return True once barge-in fires."""
        if not self.is_speaking or self._triggered:
            return False
        req_frames = self.required_hold_frames()
        if req_frames is None:
            # manual_only disables automatic speech interruption
            return False

        res = self.vad.evaluate_frame(pcm16_frame)
        prob_thresh, rms_floor = SENSITIVITY_THRESHOLDS[self.sensitivity]
        if self.policy == "strict_noisy":
            prob_thresh = min(0.88, prob_thresh + 0.08)
            rms_floor *= 1.35

        # Echo guard when speaker output telemetry is supplied.
        echo_floor = max(rms_floor, self.assistant_output_rms * 0.45)
        qualifies = res.is_speech and res.probability >= prob_thresh and res.rms >= echo_floor

        if qualifies:
            self._speech_frames += 1
            self._gap_frames = 0
        else:
            # Allow at most 1 brief inter-syllable dip once sustained speech started.
            if self._speech_frames >= 2 and self._gap_frames < 1:
                self._gap_frames += 1
            else:
                self._speech_frames = 0
                self._gap_frames = 0

        if self._speech_frames >= req_frames:
            self._triggered = True
            return True
        return False
