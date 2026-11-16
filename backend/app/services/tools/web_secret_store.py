"""Lazy ACL-protected storage for device-local Web Search API credentials."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

from app.core.windows_security import (
    reject_reparse_path,
    secure_private_path,
    validate_private_path,
)


def web_search_secret_path() -> Path:
    """Resolve the device-local Web Search API secret path lazily at call time."""
    override = os.environ.get("COMPANION_WEB_SEARCH_SECRET_FILE")
    if override:
        return Path(override)
    root = os.environ.get("LOCALAPPDATA")
    if not root:
        raise RuntimeError("LOCALAPPDATA is required for Web Search secret storage")
    return Path(root) / "AICompanion" / "secrets" / "web_search_api.secret"


def has_web_search_api_key() -> bool:
    """Return True if a readable local Web Search API key file exists without raising."""
    try:
        path = web_search_secret_path()
        reject_reparse_path(path)
        return path.exists() and path.is_file() and path.stat().st_size > 0
    except Exception:
        return False


def read_web_search_api_key() -> Optional[str]:
    """Read the device-local Web Search API key with Windows SID ACL and reparse validation."""
    path = web_search_secret_path()
    if not path.exists():
        return None
    validate_private_path(path.parent)
    validate_private_path(path)
    value = path.read_text(encoding="utf-8").strip()
    return value or None


def write_web_search_api_key(api_key: str) -> None:
    """Persist the Web Search API key strictly into ACL-locked host secret storage."""
    cleaned = api_key.strip()
    if not cleaned or len(cleaned) > 512:
        raise ValueError("Invalid Web Search API key length.")

    path = web_search_secret_path()
    reject_reparse_path(path)
    reject_reparse_path(path.parent)
    if path.parent.exists():
        validate_private_path(path.parent)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        secure_private_path(path.parent)

    path.write_text(cleaned, encoding="utf-8")
    secure_private_path(path)


def clear_web_search_api_key() -> bool:
    """Remove the stored Web Search API key file if present."""
    path = web_search_secret_path()
    reject_reparse_path(path)
    if path.exists():
        path.unlink()
        return True
    return False
