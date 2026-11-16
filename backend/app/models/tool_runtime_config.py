"""Host-level persistent D9 runtime config and Web provider settings."""

from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, CheckConstraint, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class ToolRuntimeConfig(Base, TimestampMixin):
    """Singleton host-level D9 Global Kill Switch and non-secret Web provider settings."""

    __tablename__ = "tool_runtime_config"
    __table_args__ = (
        CheckConstraint("id = 'default'", name="ck_tool_runtime_config_singleton_id"),
        CheckConstraint("global_kill_switch IN (0, 1)", name="ck_tool_runtime_config_kill_bool"),
        CheckConstraint(
            "weather_provider IN ('open_meteo', 'disabled')",
            name="ck_tool_runtime_config_weather_provider",
        ),
        CheckConstraint(
            "web_search_provider IN ('public_search', 'searxng', 'tavily', 'brave', 'disabled')",
            name="ck_tool_runtime_config_web_search_provider",
        ),
    )

    id: Mapped[str] = mapped_column(String(16), primary_key=True, default="default")
    global_kill_switch: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="0",
    )
    kill_switch_updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    kill_switch_reason: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    weather_provider: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="open_meteo",
        server_default="open_meteo",
    )
    web_search_provider: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="public_search",
        server_default="public_search",
    )
    searxng_base_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
