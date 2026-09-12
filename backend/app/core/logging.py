"""Structured logging configuration with sensitive data sanitization."""

import logging
import re
import sys
from typing import Any, Dict

# Regex to detect pairing tokens and authorization headers
TOKEN_RE = re.compile(r"(companion_sec_[a-zA-Z0-9_-]{16,})|(Bearer\s+[a-zA-Z0-9_.-]{16,})")


def sanitize_message(msg: str) -> str:
    """Mask pairing tokens, secrets, and auth credentials from logs."""
    return TOKEN_RE.sub(r"***REDACTED_TOKEN***", msg)


class SanitizingFormatter(logging.Formatter):
    """Custom formatter that automatically redacts secrets from log output."""

    def format(self, record: logging.LogRecord) -> str:
        original = super().format(record)
        return sanitize_message(original)


def setup_logging(debug: bool = False) -> None:
    """Configure root logger with structured formatting and secret sanitization."""
    log_level = logging.DEBUG if debug else logging.INFO

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(log_level)
    handler.setFormatter(
        SanitizingFormatter(
            fmt="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
    )

    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    # Remove existing handlers to prevent duplicate lines
    root_logger.handlers.clear()
    root_logger.addHandler(handler)

    # Quieten overly verbose libraries
    logging.getLogger("uvicorn.access").handlers = [handler]
    logging.getLogger("aiosqlite").setLevel(logging.WARNING)


logger = logging.getLogger("companion.core")
