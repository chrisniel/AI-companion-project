"""Pydantic schemas for Reminders, Alarms, Routines, Notifications & Quiet Hours (D10 / PC-HOST-003)."""

from datetime import datetime
from enum import Enum
from typing import Any, List, Literal, Optional
import uuid
from pydantic import Field, field_validator, model_validator

from app.schemas.common import BaseSchema
from app.services.scheduler.service import (
    parse_hhmm,
    parse_recurrence_days,
    validate_timezone_name,
)


def _validate_uuid4_optional(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    raw = value.strip()
    if not raw:
        raise ValueError("id cannot be blank when provided")
    parsed = uuid.UUID(raw)
    if parsed.version != 4:
        raise ValueError("Client-supplied id must be a valid UUIDv4")
    return str(parsed)


def _validate_hhmm_str(value: str) -> str:
    h, m = parse_hhmm(value)
    return f"{h:02d}:{m:02d}"


class ReminderStatus(str, Enum):
    scheduled = "scheduled"
    fired = "fired"
    snoozed = "snoozed"
    acknowledged = "acknowledged"
    dismissed = "dismissed"
    missed = "missed"
    cancelled = "cancelled"


class AlarmStatus(str, Enum):
    armed = "armed"
    ringing = "ringing"
    snoozed = "snoozed"
    acknowledged = "acknowledged"
    dismissed = "dismissed"
    missed = "missed"


class NotificationSourceType(str, Enum):
    reminder = "reminder"
    alarm = "alarm"
    routine = "routine"
    task_reminder = "task_reminder"


class NotificationUrgency(str, Enum):
    high = "high"
    standard = "standard"
    informational = "informational"


class NotificationStatus(str, Enum):
    unread = "unread"
    read = "read"
    acknowledged = "acknowledged"
    dismissed = "dismissed"
    snoozed = "snoozed"
    suppressed_quiet_hours = "suppressed_quiet_hours"
    missed_catchup = "missed_catchup"


class DeliveryPolicy(str, Enum):
    immediate = "immediate"
    quiet_hours_suppressed = "quiet_hours_suppressed"
    missed_catchup = "missed_catchup"


class QuietHoursOut(BaseSchema):
    """Per-profile Quiet Hours configuration."""

    quiet_hours_enabled: bool = False
    quiet_hours_start: str = "22:00"
    quiet_hours_end: str = "07:00"
    quiet_hours_timezone: str = "UTC"


class QuietHoursUpdate(BaseSchema):
    """Partial update payload for the active profile's Quiet Hours."""

    quiet_hours_enabled: Optional[bool] = None
    quiet_hours_start: Optional[str] = None
    quiet_hours_end: Optional[str] = None
    quiet_hours_timezone: Optional[str] = None

    @field_validator("quiet_hours_start", "quiet_hours_end")
    @classmethod
    def validate_times(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return _validate_hhmm_str(value)

    @field_validator("quiet_hours_timezone")
    @classmethod
    def validate_tz(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return validate_timezone_name(value)

    @model_validator(mode="after")
    def validate_window(self) -> "QuietHoursUpdate":
        if (
            self.quiet_hours_enabled is True
            and self.quiet_hours_start is not None
            and self.quiet_hours_end is not None
            and self.quiet_hours_start == self.quiet_hours_end
        ):
            raise ValueError("quiet_hours_start and quiet_hours_end cannot be identical when enabled")
        return self


class SnoozeRequest(BaseSchema):
    """Payload to snooze a reminder, alarm, or notification."""

    minutes: int = Field(default=10, ge=1, le=1440, description="Snooze duration in minutes.")
    until: Optional[datetime] = Field(default=None, description="Explicit future UTC timestamp to re-fire.")


class AcknowledgeRequest(BaseSchema):
    """Payload to acknowledge a reminder or notification."""

    complete_task: bool = Field(
        default=True,
        description="Whether acknowledging a task-linked reminder or task notification completes the associated Task.",
    )


class ReminderCreate(BaseSchema):
    """Payload to create a standalone or task-linked reminder."""

    id: Optional[str] = Field(default=None, description="Optional client-generated UUIDv4 identifier.")
    task_id: Optional[str] = None
    title: str = Field(..., min_length=1, max_length=255)
    notes: Optional[str] = None
    scheduled_at: datetime
    timezone: str = Field(default="UTC", max_length=64)
    bypass_quiet_hours: bool = False
    origin: Literal["host", "mobile"] = "host"

    @field_validator("id")
    @classmethod
    def validate_id(cls, value: Optional[str]) -> Optional[str]:
        return _validate_uuid4_optional(value)

    @field_validator("timezone")
    @classmethod
    def validate_tz(cls, value: str) -> str:
        return validate_timezone_name(value)


class ReminderUpdate(BaseSchema):
    """Partial update payload for an existing reminder."""

    task_id: Optional[str] = None
    clear_task_id: bool = False
    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    notes: Optional[str] = None
    clear_notes: bool = False
    scheduled_at: Optional[datetime] = None
    timezone: Optional[str] = Field(default=None, max_length=64)
    status: Optional[ReminderStatus] = None
    snoozed_until: Optional[datetime] = None
    clear_snoozed_until: bool = False
    bypass_quiet_hours: Optional[bool] = None

    @field_validator("timezone")
    @classmethod
    def validate_tz(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return validate_timezone_name(value)


class ReminderOut(BaseSchema):
    """Output representation of a stored Reminder."""

    id: str
    profile_id: str
    task_id: Optional[str] = None
    title: str
    notes: Optional[str] = None
    scheduled_at: datetime
    timezone: str
    status: ReminderStatus
    snoozed_until: Optional[datetime] = None
    bypass_quiet_hours: bool
    origin: str
    fired_at: Optional[datetime] = None
    acknowledged_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class ReminderListOut(BaseSchema):
    """Paginated collection of Reminders."""

    items: List[ReminderOut] = Field(default_factory=list)
    total: int


class AlarmCreate(BaseSchema):
    """Payload to create a one-shot or recurring weekday Alarm."""

    id: Optional[str] = Field(default=None, description="Optional client-generated UUIDv4 identifier.")
    label: str = Field(..., min_length=1, max_length=255)
    scheduled_at: Optional[datetime] = None
    time_of_day: Optional[str] = None
    recurrence_days: Optional[List[int]] = None
    timezone: str = Field(default="UTC", max_length=64)
    enabled: bool = True
    bypass_quiet_hours: bool = True
    origin: Literal["host", "mobile"] = "host"

    @field_validator("id")
    @classmethod
    def validate_id(cls, value: Optional[str]) -> Optional[str]:
        return _validate_uuid4_optional(value)

    @field_validator("time_of_day")
    @classmethod
    def validate_time(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return _validate_hhmm_str(value)

    @field_validator("recurrence_days")
    @classmethod
    def validate_days(cls, value: Optional[List[int]]) -> Optional[List[int]]:
        if value is None:
            return None
        return parse_recurrence_days(value)

    @field_validator("timezone")
    @classmethod
    def validate_tz(cls, value: str) -> str:
        return validate_timezone_name(value)

    @model_validator(mode="after")
    def validate_schedule_fields(self) -> "AlarmCreate":
        if self.scheduled_at is None and self.time_of_day is None:
            raise ValueError("Either scheduled_at or time_of_day is required to create an alarm")
        return self


class AlarmUpdate(BaseSchema):
    """Partial update payload for an existing Alarm."""

    label: Optional[str] = Field(default=None, min_length=1, max_length=255)
    scheduled_at: Optional[datetime] = None
    time_of_day: Optional[str] = None
    clear_time_of_day: bool = False
    recurrence_days: Optional[List[int]] = None
    clear_recurrence_days: bool = False
    timezone: Optional[str] = Field(default=None, max_length=64)
    enabled: Optional[bool] = None
    status: Optional[AlarmStatus] = None
    snoozed_until: Optional[datetime] = None
    clear_snoozed_until: bool = False
    bypass_quiet_hours: Optional[bool] = None

    @field_validator("time_of_day")
    @classmethod
    def validate_time(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return _validate_hhmm_str(value)

    @field_validator("recurrence_days")
    @classmethod
    def validate_days(cls, value: Optional[List[int]]) -> Optional[List[int]]:
        if value is None:
            return None
        return parse_recurrence_days(value)

    @field_validator("timezone")
    @classmethod
    def validate_tz(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return validate_timezone_name(value)


class AlarmOut(BaseSchema):
    """Output representation of a stored Alarm."""

    id: str
    profile_id: str
    label: str
    scheduled_at: datetime
    time_of_day: Optional[str] = None
    recurrence_days: List[int] = Field(default_factory=list)
    timezone: str
    enabled: bool
    status: AlarmStatus
    snoozed_until: Optional[datetime] = None
    bypass_quiet_hours: bool
    origin: str
    last_fired_at: Optional[datetime] = None
    acknowledged_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    @field_validator("recurrence_days", mode="before")
    @classmethod
    def parse_days(cls, value: Any) -> List[int]:
        return parse_recurrence_days(value)


class AlarmListOut(BaseSchema):
    """Paginated collection of Alarms."""

    items: List[AlarmOut] = Field(default_factory=list)
    total: int


class RoutineCreate(BaseSchema):
    """Payload to create a scheduled companion check-in Routine."""

    title: str = Field(..., min_length=1, max_length=255)
    prompt_template: Optional[str] = None
    fallback_message: str = Field(..., min_length=1, max_length=2000)
    time_of_day: str
    recurrence_days: Optional[List[int]] = None
    timezone: str = Field(default="UTC", max_length=64)
    enabled: bool = True
    bypass_quiet_hours: bool = False

    @field_validator("time_of_day")
    @classmethod
    def validate_time(cls, value: str) -> str:
        return _validate_hhmm_str(value)

    @field_validator("recurrence_days")
    @classmethod
    def validate_days(cls, value: Optional[List[int]]) -> Optional[List[int]]:
        if value is None:
            return None
        return parse_recurrence_days(value)

    @field_validator("timezone")
    @classmethod
    def validate_tz(cls, value: str) -> str:
        return validate_timezone_name(value)


class RoutineUpdate(BaseSchema):
    """Partial update payload for an existing Routine."""

    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    prompt_template: Optional[str] = None
    clear_prompt_template: bool = False
    fallback_message: Optional[str] = Field(default=None, min_length=1, max_length=2000)
    time_of_day: Optional[str] = None
    recurrence_days: Optional[List[int]] = None
    clear_recurrence_days: bool = False
    timezone: Optional[str] = Field(default=None, max_length=64)
    enabled: Optional[bool] = None
    bypass_quiet_hours: Optional[bool] = None

    @field_validator("time_of_day")
    @classmethod
    def validate_time(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return _validate_hhmm_str(value)

    @field_validator("recurrence_days")
    @classmethod
    def validate_days(cls, value: Optional[List[int]]) -> Optional[List[int]]:
        if value is None:
            return None
        return parse_recurrence_days(value)

    @field_validator("timezone")
    @classmethod
    def validate_tz(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return validate_timezone_name(value)


class RoutineOut(BaseSchema):
    """Output representation of a stored Routine."""

    id: str
    profile_id: str
    title: str
    prompt_template: Optional[str] = None
    fallback_message: str
    time_of_day: str
    recurrence_days: List[int] = Field(default_factory=list)
    timezone: str
    enabled: bool
    bypass_quiet_hours: bool
    next_run_at: Optional[datetime] = None
    last_run_at: Optional[datetime] = None
    last_status: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    @field_validator("recurrence_days", mode="before")
    @classmethod
    def parse_days(cls, value: Any) -> List[int]:
        return parse_recurrence_days(value)


class RoutineListOut(BaseSchema):
    """Paginated collection of Routines."""

    items: List[RoutineOut] = Field(default_factory=list)
    total: int


class NotificationEventOut(BaseSchema):
    """Output representation of a durable Notification Backlog event."""

    id: str
    profile_id: str
    source_type: NotificationSourceType
    source_id: str
    urgency: NotificationUrgency
    title: str
    body: Optional[str] = None
    status: NotificationStatus
    delivery_policy: DeliveryPolicy
    is_missed_catchup: bool
    triggered_at: datetime
    read_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class NotificationListOut(BaseSchema):
    """Paginated collection of Notification Backlog events plus summary counts."""

    items: List[NotificationEventOut] = Field(default_factory=list)
    total: int
    unread_count: int
    missed_count: int


class NotificationClearResponse(BaseSchema):
    """Result summary after clearing active notifications."""

    cleared_count: int
