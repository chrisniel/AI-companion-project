"""Aggregate all models for Alembic autogenerate discovery."""

from app.db.session import Base
from app.models.attachment import Attachment
from app.models.conversation import Conversation
from app.models.memory import Memory
from app.models.message import Message
from app.models.task import Task

__all__ = [
    "Base",
    "Task",
    "Conversation",
    "Message",
    "Memory",
    "Attachment",
]
