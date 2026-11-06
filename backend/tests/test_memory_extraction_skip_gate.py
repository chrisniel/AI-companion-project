"""Unit tests for the turn extraction skip gate and explicit intent filter (M3 Batch C2)."""

import pytest

from app.services.memory.extractor import is_explicit_intent, should_skip_extraction


def test_skip_empty_or_whitespace():
    assert should_skip_extraction("") is True
    assert should_skip_extraction("   ") is True
    assert should_skip_extraction("\n\t  \r") is True


def test_skip_trivial_acknowledgments():
    trivial_phrases = [
        "ok",
        "OK",
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
    ]
    for phrase in trivial_phrases:
        assert should_skip_extraction(phrase) is True, f"Failed for phrase: '{phrase}'"


def test_skip_standalone_emojis():
    emojis = ["👍", "😊❤️", "🎉🚀", "🙌", "😂", "✨✨"]
    for emoji_str in emojis:
        assert should_skip_extraction(emoji_str) is True, f"Failed for emoji: '{emoji_str}'"


def test_skip_code_blocks():
    code_snippets = [
        "```python\ndef hello():\n    print('world')\n```",
        "```json\n{\"foo\": \"bar\"}\n```",
        "```\nSELECT * FROM users;\n```",
    ]
    for code in code_snippets:
        assert should_skip_extraction(code) is True


def test_preserve_first_person_disclosures():
    disclosures = [
        "I'm vegetarian",
        "I have celiac",
        "I like tea",
        "I love dark roast coffee",
        "I hate waking up early",
        "I dislike crowded places",
        "I work as a software engineer in Berlin",
        "I live in Tokyo",
        "My dog is named Max",
        "Call me Chris",
        "I prefer oat milk over dairy",
        "I've been learning Spanish for two years",
        "I play tennis on weekends",
    ]
    for disclosure in disclosures:
        assert should_skip_extraction(disclosure) is False, f"Unexpectedly skipped: '{disclosure}'"
        assert is_explicit_intent(disclosure) is False


def test_explicit_intent_bypass_and_detection():
    explicit_cues = [
        "Remember: I like green tea",
        "Please remember that my birthday is July 4th",
        "Don't forget that I'm allergic to pollen",
        "Keep in mind that I work remotely on Fridays",
        "remember to use tabs instead of spaces",
        "DON'T FORGET I have a meeting tomorrow",
    ]
    for cue in explicit_cues:
        assert should_skip_extraction(cue) is False, f"Skipped explicit cue: '{cue}'"
        assert is_explicit_intent(cue) is True, f"Failed explicit detection: '{cue}'"


def test_ordinary_long_conversations():
    # Long text without disclosure or explicit cue should evaluate if it has substance
    # e.g., describing an event or asking a question
    assert should_skip_extraction("What is the capital of France?") is True
    assert should_skip_extraction("Can you explain how neural networks work?") is True
