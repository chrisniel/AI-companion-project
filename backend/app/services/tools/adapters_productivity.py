"""Narrow Profile-scoped productivity, scheduling, and memory adapters for D9 tools."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.tasks import _cancel_task_reminders_and_notifications
from app.models.alarm import Alarm
from app.models.base import generate_uuid, utc_now
from app.models.notification_event import NotificationEvent
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.models.reminder import Reminder
from app.models.task import Task
from app.services.memory.retriever import search_relevant_memories
from app.services.scheduler.service import (
    as_utc,
    compute_next_occurrence,
    format_recurrence_days,
    is_within_quiet_hours,
    parse_recurrence_days,
    resolve_timezone,
)


def _parse_iso_utc(raw: str) -> datetime:
    dt = datetime.fromisoformat(raw.strip().replace("Z", "+00:00"))
    normalized = as_utc(dt)
    if normalized is None:
        raise ValueError("Invalid ISO-8601 timestamp.")
    return normalized


async def _get_owned_row(db: AsyncSession, model_cls, row_id: str, profile_id: str, label: str):
    row = (
        await db.execute(
            select(model_cls).where(
                model_cls.id == row_id,
                model_cls.profile_id == profile_id,
                model_cls.is_deleted.is_(False),
            )
        )
    ).scalar_one_or_none()
    if row is None:
        raise LookupError(f"{label} '{row_id}' not found for active profile.")
    return row


async def run_list_tasks(db: AsyncSession, profile_id: str, args: dict[str, Any]) -> dict[str, Any]:
    stmt = select(Task).where(Task.profile_id == profile_id, Task.is_deleted.is_(False))
    if args.get("status"):
        stmt = stmt.where(Task.status == args["status"])
    stmt = stmt.order_by(Task.created_at.desc()).limit(int(args.get("limit", 20)))
    rows = (await db.execute(stmt)).scalars().all()
    items = [
        {"id": r.id, "title": r.title, "status": r.status, "priority": r.priority, "due_at": r.due_date.isoformat() if r.due_date else None}
        for r in rows
    ]
    return {"summary": f"Listed {len(items)} active task(s).", "items": items, "target_summary": f"{len(items)} task(s)"}


async def run_list_reminders(db: AsyncSession, profile_id: str, args: dict[str, Any]) -> dict[str, Any]:
    stmt = select(Reminder).where(Reminder.profile_id == profile_id, Reminder.is_deleted.is_(False))
    if args.get("status"):
        stmt = stmt.where(Reminder.status == args["status"])
    stmt = stmt.order_by(Reminder.scheduled_at.asc()).limit(int(args.get("limit", 20)))
    rows = (await db.execute(stmt)).scalars().all()
    items = [
        {
            "id": r.id,
            "title": r.title,
            "status": r.status,
            "scheduled_at": r.scheduled_at.isoformat() if r.scheduled_at else None,
            "bypass_quiet_hours": r.bypass_quiet_hours,
        }
        for r in rows
    ]
    return {"summary": f"Listed {len(items)} reminder(s).", "items": items, "target_summary": f"{len(items)} reminder(s)"}


async def run_list_alarms(db: AsyncSession, profile_id: str, args: dict[str, Any]) -> dict[str, Any]:
    stmt = select(Alarm).where(Alarm.profile_id == profile_id, Alarm.is_deleted.is_(False))
    if args.get("enabled_only"):
        stmt = stmt.where(Alarm.enabled.is_(True))
    stmt = stmt.order_by(Alarm.scheduled_at.asc()).limit(int(args.get("limit", 20)))
    rows = (await db.execute(stmt)).scalars().all()
    items = [
        {
            "id": r.id,
            "label": r.label,
            "time_of_day": r.time_of_day,
            "enabled": r.enabled,
            "status": r.status,
            "scheduled_at": r.scheduled_at.isoformat() if r.scheduled_at else None,
        }
        for r in rows
    ]
    return {"summary": f"Listed {len(items)} alarm(s).", "items": items, "target_summary": f"{len(items)} alarm(s)"}


async def run_search_memories(
    db: AsyncSession,
    profile_session: ProfileSession,
    args: dict[str, Any],
) -> dict[str, Any]:
    memories = await search_relevant_memories(
        db=db,
        profile_session=profile_session,
        query=args["query"],
        limit=int(args.get("limit", 5)),
        increment_recall=False,
    )
    items = [{"id": m.id, "category": m.category, "content": m.content, "is_core": m.is_core} for m in memories]
    return {"summary": f"Found {len(items)} memory match(es).", "items": items, "target_summary": args["query"][:60]}


async def run_create_task(db: AsyncSession, profile_id: str, args: dict[str, Any]) -> dict[str, Any]:
    due_dt = _parse_iso_utc(args["due_at"]) if args.get("due_at") else None
    task = Task(
        id=generate_uuid(),
        profile_id=profile_id,
        title=args["title"],
        notes=args.get("description"),
        priority=args.get("priority", "medium"),
        category=args.get("category", "personal"),
        status="pending",
        due_date=due_dt,
    )
    db.add(task)
    await db.flush()
    return {
        "summary": f'Created task "{task.title}".',
        "task": {"id": task.id, "title": task.title, "status": task.status, "priority": task.priority},
        "target_summary": task.title,
    }


async def run_update_task(db: AsyncSession, profile_id: str, args: dict[str, Any]) -> dict[str, Any]:
    task = await _get_owned_row(db, Task, args["task_id"], profile_id, "Task")
    now = utc_now()
    if args.get("title") is not None:
        task.title = args["title"]
    if args.get("priority") is not None:
        task.priority = args["priority"]
    if args.get("status") is not None:
        task.status = args["status"]
        if args["status"] in ("completed", "cancelled"):
            await _cancel_task_reminders_and_notifications(db, profile_id, task.id, now)
    task.updated_at = now
    await db.flush()
    return {
        "summary": f'Updated task "{task.title}" ({task.status}).',
        "task": {"id": task.id, "title": task.title, "status": task.status, "priority": task.priority},
        "target_summary": task.title,
    }


async def run_delete_task(db: AsyncSession, profile_id: str, args: dict[str, Any]) -> dict[str, Any]:
    task = await _get_owned_row(db, Task, args["task_id"], profile_id, "Task")
    now = utc_now()
    task.is_deleted = True
    task.deleted_at = now
    task.updated_at = now
    await _cancel_task_reminders_and_notifications(db, profile_id, task.id, now)
    await db.flush()
    return {
        "summary": f'Moved task "{task.title}" to 30-day trash.',
        "task_id": task.id,
        "target_summary": task.title,
    }


async def run_create_reminder(
    db: AsyncSession,
    profile_id: str,
    profile: Optional[Profile],
    args: dict[str, Any],
) -> dict[str, Any]:
    scheduled_at = _parse_iso_utc(args["scheduled_at"])
    tz_name = getattr(profile, "quiet_hours_timezone", "UTC") or "UTC"
    resolve_timezone(tz_name)
    rem = Reminder(
        id=generate_uuid(),
        profile_id=profile_id,
        title=args["title"],
        notes=args.get("notes"),
        scheduled_at=scheduled_at,
        timezone=tz_name,
        status="scheduled",
        bypass_quiet_hours=bool(args.get("bypass_quiet_hours", False)),
        center_popup=bool(args.get("center_popup", True)),
        origin="assistant_tool",
    )
    db.add(rem)
    await db.flush()
    quiet_note = ""
    if profile is not None and is_within_quiet_hours(profile, scheduled_at) and not rem.bypass_quiet_hours:
        quiet_note = " (will respect Quiet Hours)"
    return {
        "summary": f'Scheduled reminder "{rem.title}" for {scheduled_at.isoformat()}{quiet_note}.',
        "reminder": {"id": rem.id, "title": rem.title, "scheduled_at": scheduled_at.isoformat()},
        "target_summary": rem.title,
    }


async def run_delete_reminder(db: AsyncSession, profile_id: str, args: dict[str, Any]) -> dict[str, Any]:
    rem = await _get_owned_row(db, Reminder, args["reminder_id"], profile_id, "Reminder")
    now = utc_now()
    rem.is_deleted = True
    rem.deleted_at = now
    rem.status = "cancelled"
    rem.updated_at = now
    await db.flush()
    return {
        "summary": f'Deleted reminder "{rem.title}".',
        "reminder_id": rem.id,
        "target_summary": rem.title,
    }


async def run_create_alarm(
    db: AsyncSession,
    profile_id: str,
    profile: Optional[Profile],
    args: dict[str, Any],
) -> dict[str, Any]:
    tz_name = args.get("timezone") or (getattr(profile, "quiet_hours_timezone", "UTC") or "UTC")
    resolve_timezone(tz_name)
    days = parse_recurrence_days(args.get("recurrence_days"))
    next_dt = compute_next_occurrence(
        time_of_day=args["time_of_day"],
        recurrence_days=days,
        timezone_name=tz_name,
        after_utc=utc_now(),
    )
    alarm = Alarm(
        id=generate_uuid(),
        profile_id=profile_id,
        label=args["label"],
        scheduled_at=next_dt,
        time_of_day=args["time_of_day"],
        recurrence_days=format_recurrence_days(days),
        timezone=tz_name,
        enabled=True,
        status="armed",
        bypass_quiet_hours=bool(args.get("bypass_quiet_hours", True)),
        origin="assistant_tool",
    )
    db.add(alarm)
    await db.flush()
    quiet_status = "bypasses quiet hours by default" if alarm.bypass_quiet_hours else "respects quiet hours"
    return {
        "summary": f'Created alarm "{alarm.label}" at {alarm.time_of_day} ({quiet_status}).',
        "alarm": {"id": alarm.id, "label": alarm.label, "scheduled_at": next_dt.isoformat()},
        "target_summary": alarm.label,
    }


async def run_delete_alarm(db: AsyncSession, profile_id: str, args: dict[str, Any]) -> dict[str, Any]:
    alarm = await _get_owned_row(db, Alarm, args["alarm_id"], profile_id, "Alarm")
    now = utc_now()
    alarm.is_deleted = True
    alarm.deleted_at = now
    alarm.enabled = False
    alarm.status = "disabled"
    alarm.updated_at = now
    await db.flush()
    return {
        "summary": f'Deleted alarm "{alarm.label}".',
        "alarm_id": alarm.id,
        "target_summary": alarm.label,
    }
