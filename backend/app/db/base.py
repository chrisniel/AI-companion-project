"""Aggregate all models for Alembic autogenerate discovery."""

from app.db.session import Base
from app.models.task import Task

__all__ = ["Base", "Task"]
