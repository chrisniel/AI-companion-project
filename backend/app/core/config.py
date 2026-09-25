"""Core application configuration via Pydantic Settings."""

import os
import secrets
from pathlib import Path
from typing import List, Union

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Base directories
BASE_DIR = Path(__file__).resolve().parent.parent.parent
DEFAULT_DATA_DIR = BASE_DIR / "data"
ENV_FILE = BASE_DIR / ".env"


class Settings(BaseSettings):
    """Application runtime settings with environment overrides."""

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Server Info — "Local AI Runtime" is the canonical backend name (supersedes legacy "Local AI Core")
    PROJECT_NAME: str = "Local AI Runtime"
    VERSION: str = "0.1.0"
    ENVIRONMENT: str = "development"
    API_V1_STR: str = "/api/v1"
    HOST: str = "127.0.0.1"
    PORT: int = 8000
    DEBUG: bool = False
    MAX_REQUEST_BODY_BYTES: int = 2 * 1024 * 1024  # 2 MB max payload
    MAX_ATTACHMENT_REQUEST_BODY_BYTES: int = 12 * 1024 * 1024  # 12 MiB max multipart envelope ceiling for attachments

    # Security & Pairing Token
    COMPANION_API_KEY: str = Field(default="")

    # CORS Configuration
    CORS_ORIGINS: Union[List[str], str] = [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]

    # Database & Retention Policy (Section 16.1)
    DATA_RETENTION_DAYS: int = 30

    # Native Runtime Engines & Local LLM (Track B4, Sections 11-14, Phase 8P.2)
    LLM_ENGINE: str = "llama_cpp"
    LLM_ACCELERATION: str = "vulkan"
    LLAMA_ENGINE_VERSION: str = "b10936"

    BASE_DIR: Path = BASE_DIR
    FACTORY_MODEL_ROOT: Path = BASE_DIR.parent / "models"
    FACTORY_REGISTRY_TEMPLATE: Path = BASE_DIR.parent / "models" / "registry.template.json"
    RUNTIME_DIR: Path = BASE_DIR.parent / "runtime"
    LLAMA_CPP_BIN_DIR: Path = RUNTIME_DIR / "llama.cpp"
    BIN_DIR: Path = RUNTIME_DIR  # backward-compatibility alias
    MODELS_DIR: Path = BASE_DIR.parent / "models"
    LLAMA_MODELS_DIR: Path = BASE_DIR.parent / "models" / "vision"

    # Persistent Storage Root & Canonical Paths (Batch 8P.3B)
    @property
    def COMPANION_DATA_ROOT(self) -> Path:
        """Resolved persistent storage root (precedence: env -> bootstrap -> OS default)."""
        from app.core.storage import resolve_data_root
        return resolve_data_root()

    @property
    def canonical_paths(self):
        from app.core.storage import get_canonical_paths
        return get_canonical_paths(self.COMPANION_DATA_ROOT)

    @property
    def DATABASE_DIR(self) -> Path:
        return self.canonical_paths.DATABASE_DIR

    @property
    def DATABASE_PATH(self) -> Path:
        return self.canonical_paths.DATABASE_PATH

    @property
    def DATABASE_URL(self) -> str:
        return self.canonical_paths.DATABASE_URL

    @property
    def DATA_DIR(self) -> Path:
        """Backward-compatibility alias to canonical DATABASE_DIR."""
        return self.canonical_paths.DATABASE_DIR

    @property
    def LIBRARY_DIR(self) -> Path:
        return self.canonical_paths.LIBRARY_DIR

    @property
    def MODEL_LIBRARY_DIR(self) -> Path:
        return self.canonical_paths.MODEL_LIBRARY_DIR

    @property
    def INSTALLED_REGISTRY_PATH(self) -> Path:
        return self.canonical_paths.INSTALLED_REGISTRY_PATH

    @property
    def VOICE_LIBRARY_DIR(self) -> Path:
        return self.canonical_paths.VOICE_LIBRARY_DIR

    @property
    def ATTACHMENT_DIR(self) -> Path:
        return self.canonical_paths.ATTACHMENT_DIR

    @property
    def IMPORT_INBOX_DIR(self) -> Path:
        return self.canonical_paths.IMPORT_INBOX_DIR

    @property
    def IMPORT_STAGING_DIR(self) -> Path:
        return self.canonical_paths.IMPORT_STAGING_DIR

    @property
    def CHARACTER_DIR(self) -> Path:
        return self.canonical_paths.CHARACTER_DIR

    @property
    def MEMORY_DIR(self) -> Path:
        return self.canonical_paths.MEMORY_DIR

    @property
    def BACKUP_DIR(self) -> Path:
        return self.canonical_paths.BACKUP_DIR
    DEFAULT_MODEL_NAME: str = "Qwen2.5-7B-Instruct-Q4_K_M.gguf"
    LLM_PROVIDER: str = "auto"  # "auto" | "llama_cpp" | "mock"
    LLM_PROFILE: str = "balanced"  # "eco" | "balanced" | "maximum"
    LLM_IDLE_TIMEOUT_SECONDS: int = 900  # 15 minutes auto-unload
    LLAMA_SERVER_URL: str = "http://127.0.0.1:8085/v1"

    # Hardware Performance Profiles (Batch 8P.2 — env-overridable)
    PROFILE_ECO_CTX: int = 2048
    PROFILE_ECO_GPU_LAYERS: int = 0
    PROFILE_ECO_THREADS: int = 4
    PROFILE_ECO_MMPROJ_OFFLOAD: bool = False

    PROFILE_BALANCED_CTX: int = 4096
    PROFILE_BALANCED_GPU_LAYERS: int = 28
    PROFILE_BALANCED_THREADS: int = 6
    PROFILE_BALANCED_MMPROJ_OFFLOAD: bool = True

    PROFILE_MAXIMUM_CTX: int = 8192
    PROFILE_MAXIMUM_GPU_LAYERS: int = 33
    PROFILE_MAXIMUM_THREADS: int = 8
    PROFILE_MAXIMUM_MMPROJ_OFFLOAD: bool = True

    # Retained backward-compatibility alias for balanced GPU offload (mock / legacy consumers)
    LLM_GPU_LAYERS: int = 28

    # LLM Router launch (LLAMA_CPP_RUNTIME_ARCHITECTURE.md §3)
    LLAMA_ROUTER_HOST: str = "127.0.0.1"  # localhost only — never 0.0.0.0
    LLAMA_ROUTER_PORT: int = 8085
    LLAMA_ROUTER_IDLE_TIMEOUT: int = 900  # --sleep-idle-seconds; MODEL_SLEEPING trigger
    LLAMA_ROUTER_MODELS_MAX: int = 1  # --models-max; one-primary-model residency rule

    # B5: Conversation & Memory
    CONVERSATION_HISTORY_LIMIT: int = 50
    MEMORY_SEARCH_LIMIT: int = 5
    GENERATION_RESERVE_TOKENS: int = 512
    MEMORY_BUDGET_TOKENS: int = 256

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            origins = [i.strip() for i in v.split(",") if i.strip()]
        elif isinstance(v, list):
            origins = [str(i).strip() for i in v if str(i).strip()]
        elif isinstance(v, str):
            origins = [v.strip()]
        else:
            raise ValueError(f"Invalid CORS origins value: {v}")

        for origin in origins:
            if origin == "*":
                raise ValueError("CORS wildcard '*' is strictly forbidden for security.")
            if not (origin.startswith("http://") or origin.startswith("https://")):
                raise ValueError(
                    f"CORS origin '{origin}' is invalid. Explicit scheme (http:// or https://) is required."
                )

        return origins

    def ensure_pairing_token(self) -> str:
        """Ensure a valid 32-byte pairing token exists, generating one if missing."""
        if not self.COMPANION_API_KEY or len(self.COMPANION_API_KEY.strip()) < 16:
            new_key = f"companion_sec_{secrets.token_urlsafe(32)}"
            self.COMPANION_API_KEY = new_key
            self._persist_key_to_env(new_key)
        return self.COMPANION_API_KEY

    def _persist_key_to_env(self, key: str) -> None:
        """Persist generated pairing token to .env file for permanent reuse."""
        try:
            lines: List[str] = []
            found = False
            if ENV_FILE.exists():
                with open(ENV_FILE, "r", encoding="utf-8") as f:
                    for line in f:
                        if line.startswith("COMPANION_API_KEY="):
                            lines.append(f"COMPANION_API_KEY={key}\n")
                            found = True
                        else:
                            lines.append(line)
            if not found:
                lines.append(f"COMPANION_API_KEY={key}\n")
            with open(ENV_FILE, "w", encoding="utf-8") as f:
                f.writelines(lines)
        except Exception:
            # Fall back gracefully in read-only environments
            pass


settings = Settings()
# Initialize pairing token on load
settings.ensure_pairing_token()
