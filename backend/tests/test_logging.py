"""Tests for backend logging and secret sanitization with rotating file handler."""

import logging
import os
from logging.handlers import RotatingFileHandler
from pathlib import Path

import pytest
from app.core.logging import (
    SanitizingFormatter,
    sanitize_message,
    setup_logging,
)


def test_sanitize_message_masks_tokens():
    raw_message = (
        "User authenticated with token companion_sec_abcdef1234567890_extra "
        "and header Bearer secret_token_value_123456"
    )
    sanitized = sanitize_message(raw_message)
    assert "companion_sec_abcdef1234567890_extra" not in sanitized
    assert "secret_token_value_123456" not in sanitized
    assert "***REDACTED_TOKEN***" in sanitized


def test_setup_logging_with_companion_log_file_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    log_file = tmp_path / "test_logs" / "runtime.log"
    monkeypatch.setenv("COMPANION_LOG_FILE", str(log_file))

    setup_logging(debug=True)

    root = logging.getLogger()
    file_handlers = [h for h in root.handlers if isinstance(h, RotatingFileHandler)]
    assert len(file_handlers) == 1
    fh = file_handlers[0]
    assert fh.maxBytes == 10 * 1024 * 1024
    assert fh.backupCount == 5
    assert fh.encoding == "utf-8"

    # Emit log with secret
    test_logger = logging.getLogger("companion.test")
    test_logger.info("Starting runtime with secret companion_sec_1234567890abcdef1234")
    fh.flush()

    assert log_file.exists()
    content = log_file.read_text(encoding="utf-8")
    assert "companion_sec_1234567890abcdef1234" not in content
    assert "***REDACTED_TOKEN***" in content

    # Cleanup handler to release file lock on Windows
    fh.close()
    root.removeHandler(fh)


def test_setup_logging_explicit_param(tmp_path: Path):
    log_file = tmp_path / "custom" / "companion.log"

    setup_logging(debug=False, log_file=str(log_file))

    root = logging.getLogger()
    file_handlers = [h for h in root.handlers if isinstance(h, RotatingFileHandler)]
    assert len(file_handlers) == 1
    fh = file_handlers[0]

    test_logger = logging.getLogger("companion.custom")
    test_logger.warning("Warning message with Bearer my_bearer_token_1234567")
    fh.flush()

    assert log_file.exists()
    content = log_file.read_text(encoding="utf-8")
    assert "my_bearer_token_1234567" not in content
    assert "***REDACTED_TOKEN***" in content

    # Cleanup handler
    fh.close()
    root.removeHandler(fh)
