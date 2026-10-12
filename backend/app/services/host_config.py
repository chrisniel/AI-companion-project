"""Host/Account-level persistent configuration management.

Stores machine-level host preferences (such as selected LLM model)
under COMPANION_DATA_ROOT/config/host_config.json.
This configuration is host/Account-owned, NOT Profile-owned and NOT primarily in .env.
"""

import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

from app.core.config import settings

logger = logging.getLogger("app.services.host_config")

HOST_CONFIG_FILENAME = "host_config.json"
SCHEMA_VERSION = 1


def get_host_config_dir() -> Path:
    """Return the canonical host configuration directory under COMPANION_DATA_ROOT."""
    return settings.COMPANION_DATA_ROOT / "config"


def get_host_config_path() -> Path:
    """Return the canonical host_config.json path."""
    return get_host_config_dir() / HOST_CONFIG_FILENAME


def read_host_config() -> Dict[str, Any]:
    """Read host configuration from disk. Returns empty dict if missing or unparseable."""
    path = get_host_config_path()
    if not path.is_file():
        return {}
    try:
        content = path.read_text(encoding="utf-8")
        data = json.loads(content)
        if isinstance(data, dict):
            return data
    except Exception as exc:
        logger.warning(f"Failed to parse host configuration from {path}: {exc}")
    return {}


def write_host_config(config_data: Dict[str, Any]) -> None:
    """Atomically write host configuration to disk."""
    config_dir = get_host_config_dir()
    config_dir.mkdir(parents=True, exist_ok=True)
    target_path = get_host_config_path()

    payload = dict(config_data)
    payload["schema_version"] = SCHEMA_VERSION
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()

    temp_path = config_dir / f"{HOST_CONFIG_FILENAME}.tmp.{os.getpid()}"
    try:
        temp_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        temp_path.replace(target_path)
    finally:
        if temp_path.exists():
            try:
                temp_path.unlink()
            except OSError:
                pass


def get_saved_model_selection() -> Optional[str]:
    """Read the saved host-level model selection, or None if not set."""
    cfg = read_host_config()
    model = cfg.get("selected_model")
    if isinstance(model, str) and model.strip():
        return model.strip()
    return None


def save_model_selection(model_identifier: str) -> None:
    """Persist the host-level model selection into host_config.json."""
    if not model_identifier or not model_identifier.strip():
        raise ValueError("Model identifier cannot be empty")
    cfg = read_host_config()
    cfg["selected_model"] = model_identifier.strip()
    write_host_config(cfg)
    logger.info(f"Persisted host-level model selection: {model_identifier.strip()}")


def clear_model_selection() -> None:
    """Clear the host-level model selection."""
    cfg = read_host_config()
    if "selected_model" in cfg:
        del cfg["selected_model"]
        write_host_config(cfg)
        logger.info("Cleared host-level model selection.")


def resolve_effective_model(
    explicit_model: Optional[str] = None,
) -> Tuple[Optional[str], str]:
    """
    Establish model selection precedence:
    1. Explicitly requested model for the operation
    2. Saved host-level model selection
    3. Explicit development environment override, if present
    4. Otherwise MODEL_SELECTION_REQUIRED

    An explicit missing or incompatible model must never silently fall back to another.

    Returns:
        (resolved_identifier, precedence_source)
    """
    # 1. Explicitly requested model for the operation
    if explicit_model and explicit_model.strip():
        return explicit_model.strip(), "explicit"

    # 2. Saved host-level model selection
    saved = get_saved_model_selection()
    if saved and saved.strip():
        return saved.strip(), "saved_host_selection"

    # 3. Explicit development environment override, if present
    dev_override = (
        os.environ.get("COMPANION_DEV_MODEL")
        or os.environ.get("COMPANION_MODEL_OVERRIDE")
        or getattr(settings, "DEV_MODEL_OVERRIDE", None)
        or getattr(settings, "DEFAULT_MODEL_NAME", None)
    )
    if dev_override and str(dev_override).strip():
        return str(dev_override).strip(), "dev_override"

    # 4. Otherwise MODEL_SELECTION_REQUIRED
    return None, "MODEL_SELECTION_REQUIRED"
