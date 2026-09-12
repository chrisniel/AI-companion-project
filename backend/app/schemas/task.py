"""Task request and response schemas adhering to strict Pydantic v2 validation."""

from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import Field

from app.schemas.common import BaseSchema


class TaskStatus(str, Enum):
    """Lifecycle statuses for companion tasks and action items."""

    pending = "pending"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"


class TaskPriority(str, Enum):
    """Urgency ratings for scheduling."""

    low = "low"
    medium = "medium"
    high = "high"
    urgent = "urgent"


class TaskCategory(str, Enum):
    """Category classification matching Android TaskCategory."""

    general = "general"
    work = "work"
    personal = "personal"
    dev = "dev"
    shopping = "shopping"
    health = "health"


class TaskCreate(BaseSchema):
    """Payload to create a new task."""

    title: str = Field(..., min_length=1, max_length=255, description="Short title of the task.")
    notes: Optional[str] = Field(default=None, description="Detailed instructions or context.")
    category: TaskCategory = Field(default=TaskCategory.general, description="Category or project tag.")
    priority: TaskPriority = Field(default=TaskPriority.medium, description="Urgency rating.")
    due_date: Optional[datetime] = Field(default=None, description="Target completion timestamp in ISO-8601.")
    reminder_minutes_before: Optional[int] = Field(default=None, ge=0, description="Minutes before due date to alert.")
    reminder_at: Optional[datetime] = Field(default=None, description="Explicit alert timestamp in ISO-8601.")


class TaskUpdate(BaseSchema):
    """Payload to update an existing task. Fields omitted remain unchanged."""

    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    notes: Optional[str] = Field(default=None)
    category: Optional[TaskCategory] = Field(default=None)
    status: Optional[TaskStatus] = Field(default=None)
    priority: Optional[TaskPriority] = Field(default=None)
    due_date: Optional[datetime] = Field(default=None)
    reminder_minutes_before: Optional[int] = Field(default=None, ge=0)
    reminder_at: Optional[datetime] = Field(default=None)


class TaskResponse(BaseSchema):
    """Output representation of a stored task."""

    id: str = Field(..., description="Unique UUID identifier.")
    owner_id: str = Field(..., description="Account/profile ownership identifier.")
    title: str = Field(..., description="Task title.")
    notes: Optional[str] = Field(default=None, description="Task notes.")
    category: TaskCategory = Field(default=TaskCategory.general, description="Category or project tag.")
    status: TaskStatus = Field(..., description="Current lifecycle state.")
    priority: TaskPriority = Field(..., description="Urgency rating.")
    due_date: Optional[datetime] = Field(default=None, description="Due date timestamp.")
    reminder_minutes_before: Optional[int] = Field(default=None, description="Minutes before due date to alert.")
    reminder_at: Optional[datetime] = Field(default=None, description="Alert trigger timestamp.")
    is_deleted: bool = Field(default=False, description="Soft-deletion flag.")
    deleted_at: Optional[datetime] = Field(default=None, description="Soft-deletion timestamp.")
    created_at: datetime = Field(..., description="Creation timestamp in UTC.")
    updated_at: datetime = Field(..., description="Last modification timestamp in UTC.")


class TrashTaskResponse(TaskResponse):
    """Representation of a soft-deleted task residing in the Recycle Bin."""

    expires_in_days: int = Field(..., ge=0, description="Days remaining before permanent automated purge.")


class TaskListResponse(BaseSchema):
    """Paginated or listed collection of active tasks."""

    items: List[TaskResponse] = Field(default_factory=list, description="List of matching tasks.")
    total: int = Field(..., description="Total count of tasks matching query.")


class TrashListResponse(BaseSchema):
    """Paginated or listed collection of soft-deleted tasks."""

    items: List[TrashTaskResponse] = Field(default_factory=list, description="List of soft-deleted tasks.")
    total: int = Field(..., description="Total count of soft-deleted tasks matching query.")
