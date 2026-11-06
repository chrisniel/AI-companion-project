"""Selective Memory Extraction Service — M3 Batch C2 (PC-MEM-002).

Provides disclosure-aware heuristic skip filtering, explicit intent detection,
candidate memory extraction prompt assembly, and robust JSON parsing.
"""

from __future__ import annotations

import json
import logging
import re
from datetime import datetime, timezone
from typing import List, Literal, Optional, Union

from pydantic import BaseModel, Field

from app.core.config import settings
from app.schemas.llm import ChatMessage
from app.services.llm.base import BaseLLMProvider

logger = logging.getLogger("app.services.memory.extractor")

EXPLICIT_INTENT_PATTERN = re.compile(
    r"(?i)\b(remember|please remember|don't forget|keep in mind)\b"
)

DISCLOSURE_PATTERN = re.compile(
    r"(?i)\b(i am|i'm|my|i have|i've|i like|i love|i hate|i dislike|i prefer|"
    r"i live|i work|i play|call me|i go|i run|i eat|i drink|i study|i speak|i use)\b"
)

TRIVIAL_WORDS = {
    "ok",
    "okay",
    "yes",
    "yeah",
    "yep",
    "no",
    "nope",
    "thanks",
    "thank you",
    "cool",
    "cool cool",
    "bye",
    "goodbye",
    "see ya",
    "lol",
    "haha",
    "hahaha",
    "sure",
    "alright",
    "got it",
}

# Regex patterns for sensitive secrets that must never be extracted as memory
SECRET_PATTERNS = [
    re.compile(r"(?i)\b(password|passwd|secret|api[_-]?key|bearer)\b\s*(?:is\s*[:=]?|[:=])\s*\S+"),
    re.compile(r"\b(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|eyJ[a-zA-Z0-9_-]{20,})\b"),
    re.compile(r"\b(?:\d{4}[ -]?){3}\d{4}\b"),  # Credit card numbers
]

EXTRACTION_SYSTEM_PROMPT = """You are a precise, background memory extraction engine for a local AI companion.
Your job is to analyze the user's turn and extract long-term, durable personal facts, preferences, habits, or context about the USER.

RULES:
1. Extract facts strictly about the USER or the user's relationship with the companion. Never extract facts about the assistant or general world knowledge.
2. Ignore transient states, fleeting moods, or temporary events unless they are significant.
3. NEVER extract passwords, API keys, credentials, or private secrets.
4. Output a JSON array of candidate objects. If no permanent user facts are present, return an empty array `[]`.

CANDIDATE SCHEMA:
Each item in the array MUST be a JSON object with:
- "content": (string, 1-2 concise factual sentences in 3rd person, e.g. "User prefers oat milk over dairy in coffee")
- "category": ("fact" | "preference" | "context")
- "scope": ("profile" | "character") (use "profile" for user facts, "character" only for character-specific interactions)
- "is_core": (boolean, true only for vital identity facts like name, severe allergies, or core identity)
- "expires_at": (null or ISO8601 string if the fact has an obvious expiration)
- "confidence": (float between 0.0 and 1.0)

Output ONLY valid JSON inside a json array. Do not write explanations or markdown outside the JSON."""


class MemoryCandidate(BaseModel):
    """Structured candidate fact extracted from a conversation turn."""

    content: str = Field(..., min_length=1, max_length=1000)
    category: Literal["fact", "preference", "context"] = Field(default="fact")
    scope: Literal["profile", "character"] = Field(default="profile")
    is_core: bool = Field(default=False)
    expires_at: Optional[datetime] = Field(default=None)
    confidence: float = Field(default=0.9, ge=0.0, le=1.0)


def is_explicit_intent(user_text: str) -> bool:
    """Return True if user explicitly commands the companion to remember something."""
    if not user_text:
        return False
    return bool(EXPLICIT_INTENT_PATTERN.search(user_text.strip()))


def should_skip_extraction(user_text: str) -> bool:
    """Heuristic gate: return True if turn should skip LLM extraction.

    Protects first-person disclosures and explicit intent, while filtering out
    trivial acknowledgments, code blocks, URLs, and pure banter.
    """
    if not user_text or not user_text.strip():
        return True

    text = user_text.strip()

    # Explicit memory commands always bypass the skip gate
    if is_explicit_intent(text):
        return False

    # Skip code blocks
    if text.startswith("```") and text.endswith("```"):
        return True

    # Check for pure emojis or punctuation
    cleaned = re.sub(r"[^\w\s]", "", text, flags=re.UNICODE).strip()
    if not cleaned:
        return True

    # Check against known trivial fillers
    normalized_lower = re.sub(r"[^\w\s]", "", text).lower().strip()
    if normalized_lower in TRIVIAL_WORDS:
        return True

    # If first-person disclosure marker is present, NEVER skip (even if short)
    if DISCLOSURE_PATTERN.search(text):
        return False

    # Short utterances without disclosures are skipped
    words = text.split()
    if len(words) < 4:
        return True

    # Questions or prompts without self-disclosure are skipped
    if text.endswith("?") and not DISCLOSURE_PATTERN.search(text):
        return True

    # If there are no self-disclosure markers and no explicit intent, skip
    return True


def contains_secrets(text: str) -> bool:
    """Check if text contains credentials, tokens, or credit cards."""
    for pattern in SECRET_PATTERNS:
        if pattern.search(text):
            return True
    return False


def _clean_json_response(raw_text: str) -> str:
    """Strip markdown code blocks and surrounding whitespace from LLM output."""
    cleaned = raw_text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.splitlines()
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        cleaned = "\n".join(lines).strip()
    return cleaned


async def extract_memory_candidates(
    user_text: str,
    assistant_text: Optional[str] = None,
    provider: Optional[BaseLLMProvider] = None,
) -> List[MemoryCandidate]:
    """Extract structured candidate facts from user turn using active LLM provider.

    Returns an empty list on skip, unloaded model, parse error, or secret detection.
    """
    if should_skip_extraction(user_text):
        return []

    if provider is None:
        logger.debug("No LLM provider supplied for memory extraction.")
        return []

    # Model readiness pre-flight check
    if not provider.is_loaded():
        logger.debug("LLM provider model is not loaded; skipping memory extraction.")
        return []

    # Build prompt
    conversation_context = f"User said: \"{user_text}\""
    if assistant_text:
        conversation_context += f"\nAssistant replied: \"{assistant_text}\""

    messages = [
        ChatMessage(role="system", content=EXTRACTION_SYSTEM_PROMPT),
        ChatMessage(
            role="user",
            content=f"Analyze this turn and extract candidate memories as a JSON array:\n\n{conversation_context}",
        ),
    ]

    try:
        raw_output = await provider.generate(
            messages=messages,
            temperature=settings.MEMORY_EXTRACTION_TEMPERATURE,
            max_tokens=settings.MEMORY_EXTRACTION_MAX_TOKENS,
        )
    except Exception as exc:
        logger.warning(f"Memory extraction LLM generation failed: {exc}")
        return []

    cleaned_json = _clean_json_response(str(raw_output))
    if not cleaned_json or cleaned_json == "[]":
        return []

    try:
        parsed_data = json.loads(cleaned_json)
        if not isinstance(parsed_data, list):
            logger.debug("LLM extraction output was not a list.")
            return []
    except Exception as exc:
        logger.debug(f"Failed to parse LLM extraction JSON: {exc} | raw={cleaned_json[:100]}")
        return []

    candidates: List[MemoryCandidate] = []
    is_explicit = is_explicit_intent(user_text)

    for item in parsed_data[: settings.MEMORY_EXTRACTION_MAX_CANDIDATES]:
        if not isinstance(item, dict):
            continue

        content = item.get("content", "").strip()
        if not content or contains_secrets(content):
            continue

        # Explicit commands boost confidence to 1.0
        confidence = 1.0 if is_explicit else float(item.get("confidence", 0.9))

        try:
            candidate = MemoryCandidate(
                content=content,
                category=item.get("category", "fact"),
                scope=item.get("scope", "profile"),
                is_core=bool(item.get("is_core", False)),
                expires_at=item.get("expires_at"),
                confidence=confidence,
            )
            candidates.append(candidate)
        except Exception as val_exc:
            logger.debug(f"Validation error on candidate: {val_exc}")
            continue

    return candidates
