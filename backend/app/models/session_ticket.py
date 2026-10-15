"""One-use Desktop tickets and browser proof-of-possession approval requests."""

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import UUIDPrimaryKeyMixin, utc_now


class SessionTicket(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "session_tickets"

    ticket_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, unique=True, index=True)
    profile_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=True, index=True)
    claim_secret_hash: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, index=True)
    origin: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    redeemed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
