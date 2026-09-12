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

    # Server Info
    PROJECT_NAME: str = "Local AI Runtime"
    VERSION: str = "0.1.0"
    ENVIRONMENT: str = "development"
    API_V1_STR: str = "/api/v1"
    HOST: str = "127.0.0.1"
    PORT: int = 8000
    DEBUG: bool = False
    MAX_REQUEST_BODY_BYTES: int = 2 * 1024 * 1024  # 2 MB max payload

    # Security & Pairing Token
    COMPANION_API_KEY: str = Field(default="")

    # CORS Configuration
    CORS_ORIGINS: Union[List[str], str] = [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]

    # Database
    DATA_DIR: Path = DEFAULT_DATA_DIR
    DATABASE_URL: str = "sqlite+aiosqlite:///./data/companion.db"

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
