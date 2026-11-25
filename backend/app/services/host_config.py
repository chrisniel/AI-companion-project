"""Host/Account-level persistent configuration management.

Stores machine-level host preferences (such as selected LLM model)
under COMPANION_DATA_ROOT/config/host_config.json.
This configuration is host/Account-owned, NOT Profile-owned and NOT primarily in .env.
"""

import json
import logging
import os
import re
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, Optional, Tuple

from app.core.config import settings

logger = logging.getLogger("app.services.host_config")

HOST_CONFIG_FILENAME = "host_config.json"
SCHEMA_VERSION = 1
_HOST_CONFIG_LOCK = threading.RLock()


def get_host_config_dir() -> Path:
    """Return the canonical host configuration directory under COMPANION_DATA_ROOT."""
    return settings.COMPANION_DATA_ROOT / "config"


def get_host_config_path() -> Path:
    """Return the canonical host_config.json path."""
    return get_host_config_dir() / HOST_CONFIG_FILENAME


def read_host_config() -> Dict[str, Any]:
    """Read host configuration from disk. Returns empty dict if missing or unparseable."""
    with _HOST_CONFIG_LOCK:
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
    """Atomically write host configuration to disk under module RLock."""
    with _HOST_CONFIG_LOCK:
        config_dir = get_host_config_dir()
        config_dir.mkdir(parents=True, exist_ok=True)
        target_path = get_host_config_path()

        payload = dict(config_data)
        payload["schema_version"] = SCHEMA_VERSION
        payload["updated_at"] = datetime.now(timezone.utc).isoformat()

        temp_path = config_dir / (
            f"{HOST_CONFIG_FILENAME}.tmp.{os.getpid()}.{threading.get_ident()}.{uuid.uuid4().hex[:8]}"
        )
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
    with _HOST_CONFIG_LOCK:
        cfg = read_host_config()
        cfg["selected_model"] = model_identifier.strip()
        write_host_config(cfg)
    logger.info(f"Persisted host-level model selection: {model_identifier.strip()}")


def clear_model_selection() -> None:
    """Clear the host-level model selection."""
    with _HOST_CONFIG_LOCK:
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


VALID_HARDWARE_PROFILES = ("eco", "balanced", "maximum")
VALID_CONTEXT_MODES = ("profile", "2k", "4k", "8k", "16k", "32k", "model_max")


def get_saved_hardware_profile() -> Optional[str]:
    """Read the persisted host-level LLM hardware profile, or None if unset/invalid."""
    cfg = read_host_config()
    raw = cfg.get("hardware_profile")
    if isinstance(raw, str):
        normalized = raw.strip().lower()
        if normalized in VALID_HARDWARE_PROFILES:
            return normalized
    return None


def save_hardware_profile(profile: str) -> None:
    """Persist the host-level LLM hardware profile (eco/balanced/maximum) in host_config.json."""
    normalized = (profile or "").strip().lower()
    if normalized not in VALID_HARDWARE_PROFILES:
        raise ValueError(f"Unsupported hardware profile '{profile}'.")
    with _HOST_CONFIG_LOCK:
        cfg = read_host_config()
        cfg["hardware_profile"] = normalized
        write_host_config(cfg)
    logger.info(f"Persisted host-level hardware profile: {normalized}")


def get_saved_context_mode() -> str:
    """Read persisted experimental context window override ('profile', '16k', or 'model_max')."""
    cfg = read_host_config()
    raw = cfg.get("context_mode")
    if isinstance(raw, str):
        normalized = raw.strip().lower()
        if normalized in VALID_CONTEXT_MODES:
            return normalized
    return "profile"


def save_context_mode(mode: str) -> None:
    """Persist host-level experimental context window override in host_config.json."""
    normalized = (mode or "").strip().lower()
    if normalized not in VALID_CONTEXT_MODES:
        raise ValueError(f"Unsupported context mode '{mode}'.")
    with _HOST_CONFIG_LOCK:
        cfg = read_host_config()
        cfg["context_mode"] = normalized
        write_host_config(cfg)
    logger.info(f"Persisted host-level context mode: {normalized}")


def get_autostart_preferences() -> Dict[str, bool]:
    """Read persisted autostart preference flags from host_config.json."""
    cfg = read_host_config()
    return {
        "enabled": bool(cfg.get("autostart_enabled", False)),
        "minimized_to_tray": bool(cfg.get("autostart_minimized_to_tray", True)),
    }


def save_autostart_preferences(enabled: bool, minimized_to_tray: bool = True) -> None:
    """Persist autostart preference flags in host_config.json."""
    with _HOST_CONFIG_LOCK:
        cfg = read_host_config()
        cfg["autostart_enabled"] = bool(enabled)
        cfg["autostart_minimized_to_tray"] = bool(minimized_to_tray)
        write_host_config(cfg)
    logger.info(
        f"Persisted autostart preferences: enabled={bool(enabled)}, minimized_to_tray={bool(minimized_to_tray)}"
    )


VALID_RESOURCE_MODES = ("normal", "low_impact", "auto")
VALID_LOW_IMPACT_STRATEGIES = ("cpu_eco", "unload_when_idle", "lightweight_model")
MAX_GAME_PROCESS_LIST_ENTRIES = 64
MIN_RESOURCE_COOLDOWN_SECONDS = 5
MAX_RESOURCE_COOLDOWN_SECONDS = 300
DEFAULT_RESOURCE_COOLDOWN_SECONDS = 45
FORBIDDEN_GAME_PROCESS_NAMES = frozenset({
    "system",
    "registry",
    "smss.exe",
    "csrss.exe",
    "wininit.exe",
    "winlogon.exe",
    "services.exe",
    "lsass.exe",
    "svchost.exe",
    "explorer.exe",
    "dwm.exe",
    "conhost.exe",
    "ai_companion_desktop.exe",
    "python.exe",
    "pythonw.exe",
    "python3.exe",
    "llama-server.exe",
    "whisper-server.exe",
})
_INVALID_EXE_CHARS_RE = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def normalize_game_process_list(entries: Optional[Iterable[str]]) -> list[str]:
    """Validate and normalize monitored executable basenames for Auto Gaming Mode."""
    if entries is None:
        return []
    seen: set[str] = set()
    normalized: list[str] = []
    for raw in entries:
        if not isinstance(raw, str):
            raise ValueError("Game process entries must be executable filename strings.")
        cleaned = raw.strip().lower()
        if not cleaned:
            raise ValueError("Game process entries cannot be empty.")
        if "/" in cleaned or "\\" in cleaned or ":" in cleaned or ".." in cleaned:
            raise ValueError(f"Game process entry '{raw}' must be an .exe basename without directory paths.")
        if (
            len(cleaned) > 255
            or not cleaned.endswith(".exe")
            or cleaned == ".exe"
            or _INVALID_EXE_CHARS_RE.search(cleaned)
            or cleaned[:-4].endswith((".", " "))
        ):
            raise ValueError(f"Game process entry '{raw}' must end with '.exe' and use valid filename characters.")
        if cleaned in FORBIDDEN_GAME_PROCESS_NAMES:
            raise ValueError(f"Process '{cleaned}' is protected and cannot be added to Auto Gaming watchlist.")
        if cleaned in seen:
            continue
        seen.add(cleaned)
        if len(normalized) >= MAX_GAME_PROCESS_LIST_ENTRIES:
            raise ValueError(f"Game process list cannot exceed {MAX_GAME_PROCESS_LIST_ENTRIES} entries.")
        normalized.append(cleaned)
    return normalized


def get_resource_policy_config() -> Dict[str, Any]:
    """Read host-level resource governance & gaming mode preferences safely."""
    with _HOST_CONFIG_LOCK:
        cfg = read_host_config()
    raw_mode = str(cfg.get("resource_mode") or "normal").strip().lower()
    mode = raw_mode if raw_mode in VALID_RESOURCE_MODES else "normal"

    raw_strategy = str(cfg.get("low_impact_strategy") or "cpu_eco").strip().lower()
    strategy = raw_strategy if raw_strategy in VALID_LOW_IMPACT_STRATEGIES else "cpu_eco"

    raw_model = cfg.get("low_impact_model_id")
    model_id = raw_model.strip() if isinstance(raw_model, str) and raw_model.strip() else None

    raw_games = cfg.get("game_process_list")
    game_list: list[str] = []
    if isinstance(raw_games, list):
        try:
            game_list = normalize_game_process_list([g for g in raw_games if isinstance(g, str) and g.strip()])
        except ValueError:
            # Filter best-effort if host_config.json was hand-edited
            seen: set[str] = set()
            for g in raw_games:
                if not isinstance(g, str):
                    continue
                try:
                    for item in normalize_game_process_list([g]):
                        if item not in seen and len(game_list) < MAX_GAME_PROCESS_LIST_ENTRIES:
                            seen.add(item)
                            game_list.append(item)
                except ValueError:
                    continue

    raw_cd = cfg.get("cooldown_seconds", DEFAULT_RESOURCE_COOLDOWN_SECONDS)
    try:
        cooldown = int(raw_cd)
    except (TypeError, ValueError):
        cooldown = DEFAULT_RESOURCE_COOLDOWN_SECONDS
    cooldown = max(MIN_RESOURCE_COOLDOWN_SECONDS, min(MAX_RESOURCE_COOLDOWN_SECONDS, cooldown))

    return {
        "resource_mode": mode,
        "low_impact_strategy": strategy,
        "low_impact_model_id": model_id,
        "game_process_list": game_list,
        "cooldown_seconds": cooldown,
    }


def save_resource_policy_config(
    *,
    resource_mode: Optional[str] = None,
    low_impact_strategy: Optional[str] = None,
    low_impact_model_id: Optional[str] = None,
    clear_low_impact_model: bool = False,
    game_process_list: Optional[Iterable[str]] = None,
    cooldown_seconds: Optional[int] = None,
) -> Dict[str, Any]:
    """Validate and persist host-level resource governance policy atomically."""
    with _HOST_CONFIG_LOCK:
        current = get_resource_policy_config()
        cfg = read_host_config()

        next_mode = current["resource_mode"]
        if resource_mode is not None:
            normalized_mode = resource_mode.strip().lower()
            if normalized_mode not in VALID_RESOURCE_MODES:
                raise ValueError(f"Unsupported resource mode '{resource_mode}'.")
            next_mode = normalized_mode

        next_strategy = current["low_impact_strategy"]
        if low_impact_strategy is not None:
            normalized_strat = low_impact_strategy.strip().lower()
            if normalized_strat not in VALID_LOW_IMPACT_STRATEGIES:
                raise ValueError(f"Unsupported low-impact strategy '{low_impact_strategy}'.")
            next_strategy = normalized_strat

        next_model = current["low_impact_model_id"]
        if clear_low_impact_model:
            next_model = None
        elif low_impact_model_id is not None:
            stripped = low_impact_model_id.strip()
            if not stripped:
                next_model = None
            elif ".." in stripped or "/" in stripped or "\\" in stripped:
                raise ValueError("Invalid lightweight model identifier.")
            else:
                next_model = stripped

        next_games = current["game_process_list"]
        if game_process_list is not None:
            next_games = normalize_game_process_list(game_process_list)

        next_cooldown = current["cooldown_seconds"]
        if cooldown_seconds is not None:
            if isinstance(cooldown_seconds, bool):
                raise ValueError("cooldown_seconds must be an integer.")
            cd_val = int(cooldown_seconds)
            if cd_val < MIN_RESOURCE_COOLDOWN_SECONDS or cd_val > MAX_RESOURCE_COOLDOWN_SECONDS:
                raise ValueError(
                    f"cooldown_seconds must be between {MIN_RESOURCE_COOLDOWN_SECONDS} and {MAX_RESOURCE_COOLDOWN_SECONDS}."
                )
            next_cooldown = cd_val

        cfg["resource_mode"] = next_mode
        cfg["low_impact_strategy"] = next_strategy
        cfg["low_impact_model_id"] = next_model
        cfg["game_process_list"] = next_games
        cfg["cooldown_seconds"] = next_cooldown
        write_host_config(cfg)

        return {
            "resource_mode": next_mode,
            "low_impact_strategy": next_strategy,
            "low_impact_model_id": next_model,
            "game_process_list": next_games,
            "cooldown_seconds": next_cooldown,
        }
