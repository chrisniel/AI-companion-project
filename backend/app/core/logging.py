"""Structured logging configuration with sensitive data sanitization."""

import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import re
import sys
from typing import Any, Dict, Optional

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


def setup_logging(debug: bool = False, log_file: Optional[str] = None) -> None:
    """Configure root logger with structured formatting, secret sanitization, and optional rotating file."""
    log_level = logging.DEBUG if debug else logging.INFO

    stream_handler = logging.StreamHandler(sys.stdout)
    stream_handler.setLevel(log_level)
    formatter = SanitizingFormatter(
        fmt="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    stream_handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    # Remove existing handlers to prevent duplicate lines
    root_logger.handlers.clear()
    root_logger.addHandler(stream_handler)

    uvicorn_handlers: list[logging.Handler] = [stream_handler]

    # File logging (e.g. for detached background process logging)
    target_log_file = log_file or os.environ.get("COMPANION_LOG_FILE")
    if target_log_file:
        log_path = Path(target_log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        file_handler = RotatingFileHandler(
            target_log_file,
            maxBytes=10 * 1024 * 1024,
            backupCount=5,
            encoding="utf-8",
        )
        file_handler.setLevel(log_level)
        file_handler.setFormatter(formatter)
        root_logger.addHandler(file_handler)
        uvicorn_handlers.append(file_handler)

    # Quieten overly verbose libraries and configure access logging
    logging.getLogger("uvicorn.access").handlers = uvicorn_handlers
    logging.getLogger("aiosqlite").setLevel(logging.WARNING)


logger = logging.getLogger("companion.core")
