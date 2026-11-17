"""Speech-to-Text providers driving supervised local whisper-server.exe over loopback."""

from abc import ABC, abstractmethod
import asyncio
from dataclasses import dataclass
from pathlib import Path
import socket
import subprocess
import sys
from typing import Any, Callable, Optional

import httpx

from app.core.config import settings
from app.services.voice.audio_utils import VOICE_SAMPLE_RATE, pcm16_to_wav_bytes

_CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


@dataclass(frozen=True)
class SttResult:
    """Ephemeral speech-to-text recognition outcome."""

    text: str
    language: str
    duration_ms: int
    provider: str


class SttProvider(ABC):
    """Abstract STT provider interface."""

    name: str = "abstract"

    @property
    def model_label(self) -> Optional[str]:
        return None

    @property
    def unavailable_reason(self) -> Optional[str]:
        return None

    @abstractmethod
    def is_available(self) -> bool:
        """Return True when the STT backend is ready to transcribe audio."""

    @abstractmethod
    async def transcribe(self, pcm16_bytes: bytes, *, language: str = "auto") -> SttResult:
        """Transcribe 16kHz mono PCM16 bytes in-memory without touching disk."""

    async def shutdown(self) -> None:
        """Cleanly terminate any owned STT child processes or HTTP clients."""


class MockSttProvider(SttProvider):
    """Deterministic in-memory STT provider for isolated unit and WebSocket tests."""

    name = "mock"

    def __init__(self, *, scripted_texts: Optional[list[str]] = None) -> None:
        self._scripted_texts: list[str] = list(scripted_texts or [])

    @property
    def model_label(self) -> Optional[str]:
        return "mock-stt-v1"

    def enqueue_transcript(self, text: str) -> None:
        self._scripted_texts.append(text)

    def is_available(self) -> bool:
        return True

    async def transcribe(self, pcm16_bytes: bytes, *, language: str = "auto") -> SttResult:
        duration_ms = max(1, int(round((len(pcm16_bytes) / 2.0) / VOICE_SAMPLE_RATE * 1000.0)))
        text = self._scripted_texts.pop(0) if self._scripted_texts else "Hello companion"
        resolved_lang = "en" if language == "auto" else language
        return SttResult(text=text, language=resolved_lang, duration_ms=duration_ms, provider=self.name)


def _pick_free_loopback_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def discover_whisper_binary() -> Path:
    return settings.RUNTIME_DIR / "whisper.cpp" / "whisper-server.exe"


def discover_whisper_model(explicit_path: Optional[Path] = None) -> Optional[Path]:
    if explicit_path is not None:
        return explicit_path if explicit_path.is_file() else None
    if settings.VOICE_STT_MODEL_PATH:
        env_path = Path(settings.VOICE_STT_MODEL_PATH)
        if env_path.is_file():
            return env_path
    search_roots = [
        settings.VOICE_LIBRARY_DIR / "stt",
        settings.MODELS_DIR / "stt" / "whisper",
        settings.MODELS_DIR / "stt",
    ]
    for root in search_roots:
        try:
            if not root.is_dir():
                continue
            bins = sorted(
                [p for p in root.rglob("*.bin") if p.is_file()],
                key=lambda p: p.stat().st_mtime,
                reverse=True,
            )
            if bins:
                return bins[0]
        except OSError:
            continue
    return None


class WhisperCppSttProvider(SttProvider):
    """Managed localhost-only CPU-first whisper-server.exe STT provider."""

    name = "whisper_cpp"

    def __init__(
        self,
        *,
        binary_path: Optional[Path] = None,
        model_path: Optional[Path] = None,
        vad_model_path: Optional[Path] = None,
        threads: int = 4,
        port: int = 0,
        process_launcher: Optional[Callable[[list[str]], Any]] = None,
        http_client_factory: Optional[Callable[[], Any]] = None,
    ) -> None:
        self._binary_path = binary_path or discover_whisper_binary()
        self._explicit_model_path = model_path
        self._vad_model_path = vad_model_path
        self._threads = max(1, threads)
        self._configured_port = port
        self._active_port: Optional[int] = None
        self._process: Any = None
        self._http_client: Any = None
        self._process_launcher = process_launcher
        self._http_client_factory = http_client_factory
        self._lock = asyncio.Lock()

    def _resolve_model(self) -> Optional[Path]:
        if self._explicit_model_path is not None:
            return self._explicit_model_path if Path(self._explicit_model_path).is_file() else None
        return discover_whisper_model()

    @property
    def model_label(self) -> Optional[str]:
        m = self._resolve_model()
        return m.name if m is not None else None

    @property
    def unavailable_reason(self) -> Optional[str]:
        if not Path(self._binary_path).is_file():
            return f"whisper-server binary not found at {self._binary_path}"
        if self._resolve_model() is None:
            return "No Whisper GGML .bin model found under voice library or models/stt/whisper"
        return None

    def is_available(self) -> bool:
        return self.unavailable_reason is None

    def build_command(self, *, port: int, language: str = "auto") -> list[str]:
        model = self._resolve_model()
        if model is None:
            raise RuntimeError("Whisper model path is missing")
        cmd = [
            str(self._binary_path),
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
            "-ng",
            "--threads",
            str(self._threads),
            "-m",
            str(model),
            "-l",
            language or "auto",
            "-nt",
        ]
        vad_path = self._vad_model_path
        # whisper-server --vad -vm strictly expects a GGML .bin VAD model (never .onnx).
        if vad_path is not None and Path(vad_path).is_file() and str(vad_path).lower().endswith(".bin"):
            cmd.extend(["--vad", "-vm", str(vad_path)])
        return cmd

    def _spawn_process(self, cmd: list[str]) -> Any:
        if self._process_launcher is not None:
            return self._process_launcher(cmd)
        kwargs: dict[str, Any] = {
            "stdin": subprocess.DEVNULL,
            "stdout": subprocess.DEVNULL,
            "stderr": subprocess.DEVNULL,
        }
        if sys.platform == "win32":
            kwargs["creationflags"] = _CREATE_NO_WINDOW
        return subprocess.Popen(cmd, **kwargs)

    def _build_client(self) -> Any:
        if self._http_client_factory is not None:
            return self._http_client_factory()
        return httpx.AsyncClient(timeout=httpx.Timeout(30.0, connect=3.0))

    async def _ensure_running(self, *, language: str = "auto") -> str:
        if not self.is_available():
            raise RuntimeError(self.unavailable_reason or "Whisper STT is unavailable")

        async with self._lock:
            alive = self._process is not None and self._process.poll() is None
            if not alive or self._active_port is None:
                port = self._configured_port if self._configured_port > 0 else _pick_free_loopback_port()
                cmd = self.build_command(port=port, language=language)
                self._process = self._spawn_process(cmd)
                self._active_port = port
                if self._http_client is None:
                    self._http_client = self._build_client()
                base_url = f"http://127.0.0.1:{port}"
                # Poll localhost readiness briefly without blocking the event loop
                for _ in range(30):
                    if self._process.poll() is not None:
                        raise RuntimeError("whisper-server exited unexpectedly during startup")
                    try:
                        resp = await self._http_client.get(f"{base_url}/")
                        if resp.status_code < 500:
                            break
                    except Exception:
                        await asyncio.sleep(0.1)
            elif self._http_client is None:
                self._http_client = self._build_client()

            return f"http://127.0.0.1:{self._active_port}"

    async def transcribe(self, pcm16_bytes: bytes, *, language: str = "auto") -> SttResult:
        base_url = await self._ensure_running(language=language)
        duration_ms = max(1, int(round((len(pcm16_bytes) / 2.0) / VOICE_SAMPLE_RATE * 1000.0)))
        wav_bytes = pcm16_to_wav_bytes(pcm16_bytes, sample_rate=VOICE_SAMPLE_RATE)
        form_data = {
            "temperature": "0.0",
            "response_format": "json",
            "language": language or "auto",
        }
        resp = await self._http_client.post(
            f"{base_url}/inference",
            files={"file": ("turn.wav", wav_bytes, "audio/wav")},
            data=form_data,
        )
        resp.raise_for_status()
        payload = resp.json()
        text = str(payload.get("text") or "").strip()
        detected_lang = str(payload.get("language") or language or "auto")
        return SttResult(
            text=text,
            language=detected_lang,
            duration_ms=duration_ms,
            provider=self.name,
        )

    async def shutdown(self) -> None:
        async with self._lock:
            if self._http_client is not None:
                try:
                    await self._http_client.aclose()
                except Exception:
                    pass
                self._http_client = None
            proc = self._process
            self._process = None
            self._active_port = None
            if proc is not None and proc.poll() is None:
                try:
                    proc.terminate()
                    proc.wait(timeout=3.0)
                except Exception:
                    try:
                        proc.kill()
                    except Exception:
                        pass
