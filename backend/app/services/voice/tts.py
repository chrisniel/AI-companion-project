"""Text-to-Speech providers: Kokoro-82M ONNX (CPU-first), native Windows SAPI fallback, and Mock."""

from abc import ABC, abstractmethod
from array import array
import asyncio
import base64
from dataclasses import dataclass
from datetime import datetime
import io
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import threading
from typing import Any, AsyncIterator, Optional
import wave

from app.core.config import settings
from app.services.voice.audio_utils import VOICE_SAMPLE_RATE, pcm16_to_wav_bytes

_CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
_SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+|\n+")
_MD_LINK_RE = re.compile(r"\[([^\]]+)\]\((?:https?://|www\.)[^)]+\)")
_URL_RE = re.compile(r"https?://\S+|www\.\S+", re.IGNORECASE)
_EMOJI_RE = re.compile(
    r"[\U00010000-\U0010FFFF\u2600-\u27BF\u2300-\u23FF\u2B00-\u2BFF]+",
    flags=re.UNICODE,
)
_ACRONYM_RE = re.compile(r"\b(CPU|GPU|API|RAM|UI|TTS|STT|LLM|JSON|SQL|PC|SDK|WS)\b")

_TAGALOG_LEXICON_IPA: dict[str, str] = {
    "ako": "ɑkˈɔ",
    "ang": "ɑŋ",
    "ano": "ɑnˈɔ",
    "ay": "ɑj",
    "ayaw": "ɑjˈɑw",
    "ba": "bɑ",
    "bahay": "bˈɑhɑj",
    "bakit": "bˈɑkit",
    "bawal": "bˈɑwɑl",
    "bayan": "bˈɑjɑn",
    "bukas": "bˈukɑs",
    "cebu": "sɛbˈu",
    "charot": "tʃˈɑɾɔt",
    "davao": "dˈɑvɑw",
    "daw": "dɑw",
    "din": "din",
    "dito": "dˈitɔ",
    "diyan": "djˈɑn",
    "doon": "dɔˈɔn",
    "gabi": "ɡɑbˈi",
    "ganon": "ɡɑnˈɔn",
    "ganun": "ɡɑnˈun",
    "gusto": "ɡustˈɔ",
    "hapon": "hˈɑpɔn",
    "hindi": "hindˈi",
    "ikaw": "ikˈɑw",
    "ingat": "ˈiŋɑt",
    "ito": "itˈɔ",
    "iyan": "ijˈɑn",
    "iyon": "ijˈɔn",
    "ka": "kɑ",
    "kahapon": "kɑhˈɑpɔn",
    "kailan": "kɑilˈɑn",
    "kain": "kˈɑin",
    "kami": "kɑmˈi",
    "kamusta": "kɑmustˈɑ",
    "kasi": "kɑsˈi",
    "kaya": "kɑjˈɑ",
    "kayo": "kɑjˈɔ",
    "ko": "kɔ",
    "kumusta": "kumustˈɑ",
    "lang": "lɑŋ",
    "lungsod": "luŋsˈɔd",
    "magandang": "mɑɡɑndˈɑŋ",
    "mahal": "mɑhˈɑl",
    "makati": "mɑkˈɑti",
    "manila": "mɑnˈilɑ",
    "maraming": "mɑɾˈɑmiŋ",
    "masyado": "mɑʃˈɑdɔ",
    "mga": "mɑŋˈɑ",
    "mo": "mɔ",
    "muna": "mˈunɑ",
    "na": "nɑ",
    "naman": "nɑmˈɑn",
    "namin": "nˈɑmin",
    "natin": "nˈɑtin",
    "ng": "nɑŋ",
    "ngayon": "ŋɑjˈɔn",
    "nila": "nilˈɑ",
    "ninyo": "ninjˈɔ",
    "niya": "njˈɑ",
    "oo": "ˈɔɔ",
    "opo": "ˈɔpɔ",
    "pa": "pɑ",
    "paano": "pɑˈɑnɔ",
    "pala": "pɑlˈɑ",
    "para": "pˈɑɾɑ",
    "pero": "pˈɛɾɔ",
    "pilipinas": "pˌilipˈinɑs",
    "po": "pɔ",
    "puwede": "puwˈɛdɛ",
    "pwede": "pwˈɛdɛ",
    "quezon": "kˈɛzɔn",
    "raw": "ɾɑw",
    "rin": "ɾin",
    "sa": "sɑ",
    "saan": "sɑˈɑn",
    "salamat": "sɑlˈɑmɑt",
    "si": "si",
    "sige": "sˈiɡɛ",
    "siguro": "siɡˈuɾɔ",
    "sila": "silˈɑ",
    "sino": "sˈinɔ",
    "siya": "ʃˈɑ",
    "tagalog": "tɑɡˈɑlɔɡ",
    "talaga": "tɑlɑɡˈɑ",
    "tanghali": "tɑŋhˈɑli",
    "tara": "tˈɑɾɑ",
    "tayo": "tˈɑjɔ",
    "tulog": "tˈulɔɡ",
    "ulit": "ˈulit",
    "umaga": "umˈɑɡɑ",
    "ung": "uŋ",
    "yun": "jun",
    "yung": "juŋ",
}

# Lightweight pure-Python English grapheme-to-IPA mapping for Kokoro's phoneme vocab
# when system espeak-ng is not present; covers common conversational English cleanly.
_IPA_DIGRAPHS: tuple[tuple[str, str], ...] = (
    ("tion", "ʃən"),
    ("sion", "ʒən"),
    ("ch", "tʃ"),
    ("sh", "ʃ"),
    ("th", "θ"),
    ("ph", "f"),
    ("ng", "ŋ"),
    ("qu", "kw"),
    ("ee", "iː"),
    ("oo", "uː"),
    ("ai", "eɪ"),
    ("ay", "eɪ"),
    ("oa", "oʊ"),
    ("ow", "aʊ"),
    ("ou", "aʊ"),
    ("oy", "ɔɪ"),
    ("oi", "ɔɪ"),
    ("ar", "ɑɹ"),
    ("er", "ɚ"),
    ("ir", "ɚ"),
    ("ur", "ɚ"),
    ("or", "ɔɹ"),
)

_IPA_SINGLES: dict[str, str] = {
    "a": "æ",
    "b": "b",
    "c": "k",
    "d": "d",
    "e": "ɛ",
    "f": "f",
    "g": "ɡ",
    "h": "h",
    "i": "ɪ",
    "j": "dʒ",
    "k": "k",
    "l": "l",
    "m": "m",
    "n": "n",
    "o": "ɑ",
    "p": "p",
    "q": "k",
    "r": "ɹ",
    "s": "s",
    "t": "t",
    "u": "ʌ",
    "v": "v",
    "w": "w",
    "x": "ks",
    "y": "j",
    "z": "z",
}

_COMMON_WORDS_IPA: dict[str, str] = {
    "a": "ə",
    "the": "ðə",
    "and": "ænd",
    "are": "ɑɹ",
    "you": "juː",
    "your": "jʊɹ",
    "hello": "həloʊ",
    "hi": "haɪ",
    "how": "haʊ",
    "is": "ɪz",
    "it": "ɪt",
    "i": "aɪ",
    "my": "maɪ",
    "me": "miː",
    "we": "wiː",
    "what": "wʌt",
    "where": "wɛɹ",
    "when": "wɛn",
    "why": "waɪ",
    "weather": "wɛðɚ",
    "companion": "kəmpænjən",
    "yes": "jɛs",
    "no": "noʊ",
    "okay": "oʊkeɪ",
    "ok": "oʊkeɪ",
    "thank": "θæŋk",
    "thanks": "θæŋks",
    "please": "pliːz",
    "sorry": "sɑɹi",
    "good": "ɡʊd",
    "morning": "mɔɹnɪŋ",
    "night": "naɪt",
    "today": "tədeɪ",
    "tomorrow": "təmɑɹoʊ",
    "reminder": "ɹɪmaɪndɚ",
    "alarm": "əlɑɹm",
    "task": "tæsk",
}


@dataclass(frozen=True)
class VoiceDescriptor:
    """Discoverable TTS voice metadata."""

    voice_id: str
    name: str
    provider: str
    language: str
    sample_rate: int


@dataclass(frozen=True)
class TtsResult:
    """In-memory synthesized WAV payload for one text segment or full reply."""

    wav_bytes: bytes
    sample_rate: int
    duration_ms: int
    voice_id: str
    provider: str


def split_sentences_for_tts(text: str, *, max_chars: int = 240) -> list[str]:
    """Split text into natural spoken chunks bounded to Kokoro/SAPI latency limits."""
    cleaned = " ".join(text.strip().split())
    if not cleaned:
        return []
    raw_parts = [p.strip() for p in _SENTENCE_SPLIT_RE.split(cleaned) if p.strip()]
    chunks: list[str] = []
    for part in raw_parts:
        if len(part) <= max_chars:
            chunks.append(part)
            continue
        words = part.split(" ")
        buf = ""
        for word in words:
            if not buf:
                buf = word
            elif len(buf) + 1 + len(word) <= max_chars:
                buf = f"{buf} {word}"
            else:
                chunks.append(buf)
                buf = word
        if buf:
            chunks.append(buf)
    return chunks


def preprocess_text_for_tts(text: str) -> str:
    """Clean Markdown, URLs, apostrophes, temperatures, decimals, symbols, slashes, and acronyms before G2P."""
    cleaned = text or ""
    cleaned = (
        cleaned.replace("\u2019", "'")
        .replace("\u2018", "'")
        .replace("\u02bc", "'")
        .replace("\u2032", "'")
        .replace("\u201c", '"')
        .replace("\u201d", '"')
    )
    cleaned = _MD_LINK_RE.sub(r"\1", cleaned)
    cleaned = _URL_RE.sub("", cleaned)
    cleaned = cleaned.replace("```", " ").replace("`", "")
    cleaned = re.sub(r"[*_~]+", "", cleaned)

    def _format_iso_datetime(m: re.Match[str]) -> str:
        try:
            dt = datetime(
                int(m.group(1)),
                int(m.group(2)),
                int(m.group(3)),
                int(m.group(4)),
                int(m.group(5)),
            )
        except ValueError:
            return m.group(0)
        hour_12 = dt.hour % 12 or 12
        am_pm = "AM" if dt.hour < 12 else "PM"
        return f"{dt.strftime('%B')} {dt.day}, {dt.year} at {hour_12}:{dt.minute:02d} {am_pm}"

    def _format_iso_date(m: re.Match[str]) -> str:
        try:
            dt = datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            return m.group(0)
        return f"{dt.strftime('%B')} {dt.day}, {dt.year}"

    cleaned = re.sub(
        r"\b(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?\b",
        _format_iso_datetime,
        cleaned,
    )
    cleaned = re.sub(
        r"\b(\d{4})-(\d{2})-(\d{2})\b",
        _format_iso_date,
        cleaned,
    )

    def _unit_name(unit: str) -> str:
        return "degrees Celsius" if unit.lower() == "c" else "degrees Fahrenheit"

    def _format_temp_range(m: re.Match[str]) -> str:
        if m.group(2) and m.group(2).lower() != m.group(4).lower():
            return f"{m.group(1)} {_unit_name(m.group(2))} to {m.group(3)} {_unit_name(m.group(4))}"
        return f"{m.group(1)} to {m.group(3)} {_unit_name(m.group(4))}"

    cleaned = re.sub(
        r"(-?\d+(?:\.\d+)?)\s*(?:°?\s*([CcFf]))?\s*[–—\-]\s*(-?\d+(?:\.\d+)?)\s*°\s*([CcFf])\b",
        _format_temp_range,
        cleaned,
    )
    cleaned = re.sub(
        r"(-?\d+(?:\.\d+)?)\s*(?:°?\s*([CcFf]))?\s*[–—\-]\s*(-?\d+(?:\.\d+)?)\s*([CcFf])\b",
        _format_temp_range,
        cleaned,
    )
    cleaned = re.sub(
        r"(-?\d+(?:\.\d+)?)\s*°\s*([CcFf])\b",
        lambda m: f"{m.group(1)} {_unit_name(m.group(2))}",
        cleaned,
    )
    cleaned = re.sub(
        r"\b(-?\d+\.\d+)\s*([CcFf])\b",
        lambda m: f"{m.group(1)} {_unit_name(m.group(2))}",
        cleaned,
    )
    cleaned = re.sub(r"(\d+(?:\.\d+)?)\s*°(?!\s*[CcFf]\b)", r"\1 degrees ", cleaned)
    cleaned = re.sub(
        r"(?<![\d\-])(\d+(?:\.\d+)?)\s*[–—\-]\s*(\d+(?:\.\d+)?)(?![\d\-])",
        r"\1 to \2",
        cleaned,
    )
    # Normalize prose em/en-dashes to natural comma pauses before espeak-ng splits clauses on '—'.
    cleaned = re.sub(r"(?<=[,.;:!?])\s*[—–]+\s*", " ", cleaned)
    cleaned = re.sub(r"\s*[—–]+\s*(?=[.!?]|$)", "", cleaned)
    cleaned = re.sub(r"\s*[—–]+\s*", ", ", cleaned)
    cleaned = re.sub(r"(\d+(?:\.\d+)?)\s*%", r"\1 percent", cleaned)
    cleaned = re.sub(r"(\d+)\.(\d+)", r"\1 point \2", cleaned)
    cleaned = re.sub(r"\s*(?:->|=>|[→⇒➜➔⟶])\s*", ", ", cleaned)
    cleaned = re.sub(r"[\u2190-\u21FF\u25A0-\u25FF]+", " ", cleaned)
    cleaned = re.sub(r"(?<=[A-Za-z])\s*/\s*(?=[A-Za-z])", " or ", cleaned)
    cleaned = re.sub(r"[*_~#>]+", " ", cleaned)
    cleaned = _EMOJI_RE.sub(" ", cleaned)
    cleaned = _ACRONYM_RE.sub(lambda m: " ".join(m.group(1)), cleaned)
    normalized = " ".join(cleaned.split())
    if not normalized or not re.search(r"[A-Za-z0-9]", normalized):
        return ""
    return normalized


class _LazyEspeakPhonemizer:
    """Thread-safe lazy ctypes wrapper over bundled espeak-ng shared library."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._attempted = False
        self._lib: Any = None
        self._ctypes: Any = None
        self._active_voice: Optional[bytes] = None

    def _ensure_loaded(self) -> bool:
        if self._attempted:
            return self._lib is not None
        self._attempted = True
        try:
            import ctypes
            import espeakng_loader  # type: ignore[import-not-found]

            lib_path = espeakng_loader.get_library_path()
            data_path = espeakng_loader.get_data_path()
            lib = ctypes.CDLL(str(lib_path))
            lib.espeak_Initialize.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
            lib.espeak_Initialize.restype = ctypes.c_int
            lib.espeak_SetVoiceByName.argtypes = [ctypes.c_char_p]
            lib.espeak_SetVoiceByName.restype = ctypes.c_int
            lib.espeak_TextToPhonemes.argtypes = [
                ctypes.POINTER(ctypes.c_void_p),
                ctypes.c_int,
                ctypes.c_int,
            ]
            lib.espeak_TextToPhonemes.restype = ctypes.c_char_p
            sr = lib.espeak_Initialize(2, 0, str(data_path).encode("utf-8"), 0)
            if sr <= 0:
                return False
            self._lib = lib
            self._ctypes = ctypes
            return True
        except Exception:
            self._lib = None
            return False

    def phonemize(self, text: str, *, espeak_voice: str = "en-us") -> Optional[str]:
        if not text.strip():
            return ""
        with self._lock:
            if not self._ensure_loaded():
                return None
            ctypes = self._ctypes
            lib = self._lib
            voice_bytes = espeak_voice.encode("utf-8")
            if self._active_voice != voice_bytes:
                if lib.espeak_SetVoiceByName(voice_bytes) == 0:
                    self._active_voice = voice_bytes
                else:
                    lib.espeak_SetVoiceByName(b"en-us")
                    self._active_voice = b"en-us"
            clause_matches = list(re.finditer(r"([^.,!?;:—]*)([.,!?;:—]*)", text))
            clause_phonemes: list[str] = []
            for m in clause_matches:
                body = (m.group(1) or "").strip()
                punct = (m.group(2) or "").strip()
                if not body and not punct:
                    continue
                if not body:
                    if clause_phonemes:
                        clause_phonemes[-1] = f"{clause_phonemes[-1]}{punct}"
                    else:
                        clause_phonemes.append(punct)
                    continue
                clause_input = f"{body}{punct}"
                buf = ctypes.create_string_buffer(clause_input.encode("utf-8"))
                ptr = ctypes.c_void_p(ctypes.addressof(buf))
                segments: list[str] = []
                while ptr.value:
                    res = lib.espeak_TextToPhonemes(ctypes.byref(ptr), 1, 2)
                    if not res:
                        break
                    piece = res.decode("utf-8", errors="ignore").strip()
                    if piece:
                        segments.append(piece.replace("g", "ɡ"))
                joined = " ".join(segments).strip()
                if joined:
                    if punct and not joined.endswith(punct[-1]):
                        joined = f"{joined}{punct}"
                    clause_phonemes.append(joined)
                elif punct:
                    clause_phonemes.append(punct)
            return " ".join(clause_phonemes)


_ESPEAK_PHONEMIZER = _LazyEspeakPhonemizer()


def _fallback_word_to_ipa(word: str) -> str:
    low = word.lower()
    if low in _TAGALOG_LEXICON_IPA:
        return _TAGALOG_LEXICON_IPA[low]
    if low in _COMMON_WORDS_IPA:
        return _COMMON_WORDS_IPA[low]
    out: list[str] = []
    i = 0
    while i < len(low):
        if low.startswith("c", i) and i + 1 < len(low) and low[i + 1] in ("e", "i", "y"):
            out.append("s")
            i += 1
            continue
        matched = False
        for digraph, ipa in _IPA_DIGRAPHS:
            if low.startswith(digraph, i):
                out.append(ipa)
                i += len(digraph)
                matched = True
                break
        if matched:
            continue
        ch = low[i]
        out.append(_IPA_SINGLES.get(ch, ch))
        i += 1
    return "".join(out)


def text_to_kokoro_ipa(text: str, *, language: str = "en-us") -> str:
    """Convert cleaned English/Taglish text into Kokoro-compatible IPA phonemes."""
    cleaned = preprocess_text_for_tts(text)
    if not cleaned:
        return ""
    tokens = re.findall(r"[A-Za-z0-9']+|[.,!?;:()—\-]+|[^\w\s]+|\s+", cleaned)
    rendered: list[str] = []
    english_buf: list[str] = []

    def _flush_english() -> None:
        if not english_buf:
            return
        phrase = "".join(english_buf).strip()
        english_buf.clear()
        if not phrase:
            return
        espeak_out = _ESPEAK_PHONEMIZER.phonemize(phrase, espeak_voice=language)
        if espeak_out:
            rendered.append(espeak_out)
        else:
            fallback_parts = [
                _fallback_word_to_ipa(tok) if tok.isalpha() else tok
                for tok in re.findall(r"[A-Za-z]+|\s+|[^\w\s]+|[0-9]+", phrase)
            ]
            rendered.append("".join(fallback_parts))

    for tok in tokens:
        low = tok.lower()
        if low.isalpha() and low in _TAGALOG_LEXICON_IPA:
            _flush_english()
            if rendered and not rendered[-1].endswith((" ", "(", "—")):
                rendered.append(" ")
            rendered.append(_TAGALOG_LEXICON_IPA[low])
        elif tok.isspace():
            if english_buf:
                if not english_buf[-1].endswith(" "):
                    english_buf.append(" ")
            elif rendered and not rendered[-1].endswith(" "):
                rendered.append(" ")
        elif re.fullmatch(r"[.,!?;:()—\-]+", tok):
            if any(any(c.isalnum() for c in s) for s in english_buf):
                english_buf.append(tok)
            else:
                _flush_english()
                rendered.append(tok)
        else:
            if english_buf and not english_buf[-1].endswith((" ", "-", "(")):
                english_buf.append(" ")
            english_buf.append(tok)

    _flush_english()
    ipa = "".join(rendered)
    ipa = re.sub(r"\s+([.,!?;:])", r"\1", ipa)
    return " ".join(ipa.split())


def text_to_kokoro_tokens(
    text: str,
    vocab: dict[str, int],
    *,
    max_tokens: int = 510,
    language: str = "en-us",
) -> list[int]:
    """Convert text -> IPA characters -> Kokoro tokenizer IDs padded with [0, ..., 0]."""
    pad_id = int(vocab.get("$", 0))
    ipa = text_to_kokoro_ipa(text, language=language)
    ids: list[int] = []
    for ch in ipa:
        if ch in vocab:
            ids.append(int(vocab[ch]))
        elif ch.lower() in vocab:
            ids.append(int(vocab[ch.lower()]))
        if len(ids) >= max_tokens:
            break
    return [pad_id, *ids, pad_id]


def load_kokoro_voice_style_vector(voice_path: Path, *, token_count: int) -> list[float]:
    """Read float32 [*, 1, 256] Kokoro style embedding row matching token length."""
    raw = voice_path.read_bytes()
    stride_floats = 256
    stride_bytes = stride_floats * 4
    if len(raw) < stride_bytes or len(raw) % stride_bytes != 0:
        raise ValueError(f"Invalid Kokoro voice style binary size: {voice_path}")
    num_rows = len(raw) // stride_bytes
    row_idx = max(0, min(num_rows - 1, max(0, token_count - 2)))
    offset = row_idx * stride_bytes
    return list(struct.unpack("<256f", raw[offset : offset + stride_bytes]))


class TtsProvider(ABC):
    """Abstract Text-to-Speech provider interface."""

    name: str = "abstract"

    @property
    def unavailable_reason(self) -> Optional[str]:
        return None

    @abstractmethod
    def is_available(self) -> bool:
        """Return True when the TTS engine is ready to synthesize audio."""

    @abstractmethod
    def list_voices(self) -> list[VoiceDescriptor]:
        """Return discoverable voices for this TTS engine."""

    @abstractmethod
    async def synthesize(
        self,
        text: str,
        *,
        voice_id: Optional[str] = None,
        speed: float = 1.0,
    ) -> TtsResult:
        """Synthesize spoken audio as in-memory RIFF WAV bytes."""

    async def synthesize_stream(
        self,
        text: str,
        *,
        voice_id: Optional[str] = None,
        speed: float = 1.0,
    ) -> AsyncIterator[TtsResult]:
        """Yield sentence-chunked synthesized WAV segments for low-latency playback."""
        chunks = split_sentences_for_tts(text)
        for chunk in chunks:
            yield await self.synthesize(chunk, voice_id=voice_id, speed=speed)

    async def shutdown(self) -> None:
        """Release any held TTS resources."""


class MockTtsProvider(TtsProvider):
    """Deterministic in-memory WAV tone generator for unit and WebSocket tests."""

    name = "mock"

    def is_available(self) -> bool:
        return True

    def list_voices(self) -> list[VoiceDescriptor]:
        return [
            VoiceDescriptor(
                voice_id="af_nicole",
                name="Nicole (Mock Voice)",
                provider=self.name,
                language="en",
                sample_rate=VOICE_SAMPLE_RATE,
            ),
            VoiceDescriptor(
                voice_id="am_michael",
                name="Michael (Mock Voice)",
                provider=self.name,
                language="en",
                sample_rate=VOICE_SAMPLE_RATE,
            ),
        ]

    async def synthesize(
        self,
        text: str,
        *,
        voice_id: Optional[str] = None,
        speed: float = 1.0,
    ) -> TtsResult:
        resolved_voice = (voice_id or "af_nicole").strip() or "af_nicole"
        clamped_speed = max(0.5, min(2.0, float(speed)))
        duration_ms = max(80, min(600, int((len(text.strip()) * 8) / clamped_speed)))
        num_samples = int(VOICE_SAMPLE_RATE * (duration_ms / 1000.0))
        freq = 330.0 if resolved_voice == "af_nicole" else 220.0
        samples = array(
            "h",
            [
                int(2400 * math.sin(2.0 * math.pi * freq * i / float(VOICE_SAMPLE_RATE)))
                for i in range(num_samples)
            ],
        )
        if sys.byteorder != "little":
            samples.byteswap()
        wav_bytes = pcm16_to_wav_bytes(samples.tobytes(), sample_rate=VOICE_SAMPLE_RATE)
        return TtsResult(
            wav_bytes=wav_bytes,
            sample_rate=VOICE_SAMPLE_RATE,
            duration_ms=duration_ms,
            voice_id=resolved_voice,
            provider=self.name,
        )


def _discover_kokoro_root() -> Optional[Path]:
    for candidate in (
        settings.VOICE_LIBRARY_DIR / "tts" / "kokoro-82m-v1.0",
        settings.MODELS_DIR / "tts" / "kokoro-82m-v1.0",
    ):
        if (candidate / "model_quantized.onnx").is_file():
            return candidate
    return None


class KokoroOnnxTtsProvider(TtsProvider):
    """CPU-first Kokoro-82M ONNX neural TTS provider when onnxruntime+numpy+weights exist."""

    name = "kokoro_onnx"
    _SAMPLE_RATE = 24000

    def __init__(
        self,
        *,
        model_root: Optional[Path] = None,
        vocab: Optional[dict[str, int]] = None,
        voices: Optional[dict[str, list[list[float]]]] = None,
        session: Any = None,
    ) -> None:
        self._root = model_root
        self._vocab = vocab
        self._voices_cache = voices
        self._session = session
        self._voice_paths: dict[str, Path] = {}
        self._np: Any = None
        self._init_error: Optional[str] = None
        if self._session is None:
            self._try_init_lazy()
        else:
            self._init_with_injected_session()

    def _init_with_injected_session(self) -> None:
        try:
            import numpy as np  # type: ignore[import-not-found]
            self._np = np
        except Exception:
            self._np = None

    def _try_init_lazy(self) -> None:
        root = self._root or _discover_kokoro_root()
        if root is None:
            self._init_error = "Kokoro-82M model directory or model_quantized.onnx not found"
            return
        tok_file = root / "tokenizer.json"
        if not tok_file.is_file():
            self._init_error = f"Kokoro tokenizer.json missing in {root}"
            return
        voices_dir = root / "voices"
        if voices_dir.is_dir():
            for vp in sorted(voices_dir.glob("*.bin")):
                self._voice_paths[vp.stem] = vp
        if not self._voice_paths and not self._voices_cache:
            self._init_error = f"No Kokoro voice style .bin files found under {voices_dir}"
            return
        try:
            import numpy as np  # type: ignore[import-not-found]
            import onnxruntime as ort  # type: ignore[import-not-found]
        except Exception as exc:
            self._init_error = f"onnxruntime/numpy unavailable: {exc}"
            return
        self._np = np
        if self._vocab is None:
            tok_data = json.loads(tok_file.read_text(encoding="utf-8"))
            self._vocab = dict(tok_data.get("model", {}).get("vocab", {}))
        opts = ort.SessionOptions()
        opts.inter_op_num_threads = 1
        opts.intra_op_num_threads = min(6, max(2, os.cpu_count() or 4))
        self._session = ort.InferenceSession(
            str(root / "model_quantized.onnx"),
            sess_options=opts,
            providers=["CPUExecutionProvider"],
        )

    @property
    def unavailable_reason(self) -> Optional[str]:
        return self._init_error

    def is_available(self) -> bool:
        return (
            self._session is not None
            and self._vocab is not None
            and (bool(self._voice_paths) or bool(self._voices_cache))
        )

    def list_voices(self) -> list[VoiceDescriptor]:
        ids = sorted(set(self._voice_paths.keys()) | set((self._voices_cache or {}).keys()))
        if not ids:
            return []
        return [
            VoiceDescriptor(
                voice_id=vid,
                name=vid.replace("_", " ").title(),
                provider=self.name,
                language="en",
                sample_rate=self._SAMPLE_RATE,
            )
            for vid in ids
        ]

    def _resolve_style(self, voice_id: Optional[str], token_count: int) -> tuple[str, list[float]]:
        available = sorted(set(self._voice_paths.keys()) | set((self._voices_cache or {}).keys()))
        chosen = voice_id if voice_id in available else (available[0] if available else "af_nicole")
        if self._voices_cache and chosen in self._voices_cache:
            rows = self._voices_cache[chosen]
            idx = max(0, min(len(rows) - 1, max(0, token_count - 2)))
            return chosen, list(rows[idx])
        return chosen, load_kokoro_voice_style_vector(self._voice_paths[chosen], token_count=token_count)

    def _split_token_bounded_chunks(
        self,
        text: str,
        *,
        language: str,
        max_body_tokens: int = 480,
    ) -> list[str]:
        assert self._vocab is not None
        cleaned = preprocess_text_for_tts(text)
        if not cleaned:
            return []
        raw_chunks = split_sentences_for_tts(cleaned, max_chars=420)
        bounded: list[str] = []
        for chunk in raw_chunks:
            if len(text_to_kokoro_tokens(chunk, self._vocab, max_tokens=510, language=language)) <= max_body_tokens + 2:
                bounded.append(chunk)
                continue
            # Prefer splitting oversize sentences cleanly at clause boundaries before word fallback.
            clauses = [c.strip() for c in re.split(r"(?<=[,;—:])\s+", chunk) if c.strip()]
            words = clauses if len(clauses) > 1 else chunk.split(" ")
            buf = ""
            for unit in words:
                candidate = unit if not buf else f"{buf} {unit}"
                if len(text_to_kokoro_tokens(candidate, self._vocab, max_tokens=510, language=language)) <= max_body_tokens + 2:
                    buf = candidate
                else:
                    if buf:
                        bounded.append(buf)
                    if len(text_to_kokoro_tokens(unit, self._vocab, max_tokens=510, language=language)) <= max_body_tokens + 2:
                        buf = unit
                    else:
                        sub_buf = ""
                        for word in unit.split(" "):
                            sub_cand = word if not sub_buf else f"{sub_buf} {word}"
                            if len(text_to_kokoro_tokens(sub_cand, self._vocab, max_tokens=510, language=language)) <= max_body_tokens + 2:
                                sub_buf = sub_cand
                            else:
                                if sub_buf:
                                    bounded.append(sub_buf)
                                sub_buf = word
                        buf = sub_buf
            if buf:
                bounded.append(buf)
        return bounded

    def _run_chunk_sync(
        self,
        chunk_text: str,
        chosen_voice: str,
        clamped_speed: float,
        language: str,
    ) -> array:
        assert self._vocab is not None and self._session is not None
        tokens = text_to_kokoro_tokens(
            chunk_text,
            self._vocab,
            max_tokens=510,
            language=language,
        )
        _, style_vec = self._resolve_style(chosen_voice, len(tokens))
        if self._np is not None:
            np = self._np
            feed = {
                "input_ids": np.array([tokens], dtype=np.int64),
                "style": np.array([style_vec], dtype=np.float32),
                "speed": np.array([clamped_speed], dtype=np.float32),
            }
        else:
            feed = {
                "input_ids": [tokens],
                "style": [style_vec],
                "speed": [clamped_speed],
            }
        outputs = self._session.run(None, feed)
        raw_audio = outputs[0]
        if hasattr(raw_audio, "reshape"):
            flat = raw_audio.reshape(-1).tolist()
        elif isinstance(raw_audio, list) and raw_audio and isinstance(raw_audio[0], list):
            flat = raw_audio[0]
        else:
            flat = list(raw_audio)

        pcm = array("h")
        for sample in flat:
            clipped = max(-1.0, min(1.0, float(sample)))
            pcm.append(int(round(clipped * 32767.0)))
        return pcm

    def _run_sync(self, text: str, voice_id: Optional[str], speed: float) -> TtsResult:
        assert self._vocab is not None and self._session is not None
        available = sorted(set(self._voice_paths.keys()) | set((self._voices_cache or {}).keys()))
        chosen_voice = voice_id if voice_id in available else (available[0] if available else "af_nicole")
        language = "en-gb" if chosen_voice.startswith(("bf_", "bm_")) else "en-us"
        clamped_speed = max(0.5, min(2.0, float(speed)))

        chunks = [c for c in self._split_token_bounded_chunks(text, language=language) if c.strip()]
        combined_pcm = array("h")
        if not chunks:
            combined_pcm.extend([0] * int(self._SAMPLE_RATE * 0.04))
        else:
            lead_silence = array("h", [0] * int(self._SAMPLE_RATE * 0.05))
            gap_samples = array("h", [0] * int(self._SAMPLE_RATE * 0.09))
            tail_silence = array("h", [0] * int(self._SAMPLE_RATE * 0.12))
            combined_pcm.extend(lead_silence)
            for idx, chunk in enumerate(chunks):
                chunk_pcm = self._run_chunk_sync(chunk, chosen_voice, clamped_speed, language)
                combined_pcm.extend(chunk_pcm)
                if idx + 1 < len(chunks):
                    combined_pcm.extend(gap_samples)
            combined_pcm.extend(tail_silence)

        if sys.byteorder != "little":
            combined_pcm.byteswap()
        wav_bytes = pcm16_to_wav_bytes(combined_pcm.tobytes(), sample_rate=self._SAMPLE_RATE)
        duration_ms = max(1, int(round(len(combined_pcm) / float(self._SAMPLE_RATE) * 1000.0)))
        return TtsResult(
            wav_bytes=wav_bytes,
            sample_rate=self._SAMPLE_RATE,
            duration_ms=duration_ms,
            voice_id=chosen_voice,
            provider=self.name,
        )

    async def synthesize(
        self,
        text: str,
        *,
        voice_id: Optional[str] = None,
        speed: float = 1.0,
    ) -> TtsResult:
        if not self.is_available():
            raise RuntimeError(self._init_error or "Kokoro ONNX TTS provider is unavailable")
        return await asyncio.to_thread(self._run_sync, text, voice_id, speed)


class WindowsSapiTtsProvider(TtsProvider):
    """Zero-dependency native Windows System.Speech memory-stream TTS fallback."""

    name = "windows_sapi"

    def is_available(self) -> bool:
        return sys.platform == "win32"

    @property
    def unavailable_reason(self) -> Optional[str]:
        return None if self.is_available() else "Windows SAPI is only available on win32 hosts"

    def list_voices(self) -> list[VoiceDescriptor]:
        if not self.is_available():
            return []
        return [
            VoiceDescriptor(
                voice_id="windows_sapi_default",
                name="Windows Default Voice (SAPI)",
                provider=self.name,
                language="en",
                sample_rate=22050,
            )
        ]

    @staticmethod
    def _synthesize_sync(text: str, speed: float) -> bytes:
        # Map 0.5..2.0 speed to SAPI Rate -10..10 gently (-5..5)
        clamped = max(0.5, min(2.0, float(speed)))
        rate = max(-10, min(10, int(round((clamped - 1.0) * 8.0))))
        text_b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
        script = (
            "Add-Type -AssemblyName System.Speech; "
            "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
            "$ms = New-Object System.IO.MemoryStream; "
            f"$s.Rate = {rate}; "
            "$s.SetOutputToWaveStream($ms); "
            f"$txt = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{text_b64}')); "
            "$s.Speak($txt); "
            "$s.SetOutputToNull(); "
            "[Console]::Out.Write([Convert]::ToBase64String($ms.ToArray())); "
            "$ms.Dispose(); $s.Dispose()"
        )
        proc = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=20,
            creationflags=_CREATE_NO_WINDOW if sys.platform == "win32" else 0,
            check=True,
        )
        return base64.b64decode(proc.stdout.strip())

    async def synthesize(
        self,
        text: str,
        *,
        voice_id: Optional[str] = None,
        speed: float = 1.0,
    ) -> TtsResult:
        if not self.is_available():
            raise RuntimeError("Windows SAPI TTS is unavailable on this OS")
        wav_bytes = await asyncio.to_thread(self._synthesize_sync, text, speed)
        with wave.open(io.BytesIO(wav_bytes), "rb") as wf:
            sr = wf.getframerate()
            frames = wf.getnframes()
        duration_ms = max(1, int(round(frames / float(max(1, sr)) * 1000.0)))
        return TtsResult(
            wav_bytes=wav_bytes,
            sample_rate=sr,
            duration_ms=duration_ms,
            voice_id="windows_sapi_default",
            provider=self.name,
        )
