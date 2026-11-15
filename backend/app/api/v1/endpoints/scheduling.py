"""Profile-scoped REST endpoints for Reminders, Alarms, Routines & Notification Backlog."""

from datetime import datetime, timedelta, timezone
from typing import List, Optional, Type, TypeVar
from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db
from app.core.errors import CompanionNotFoundError
from app.core.profile_sessions import validate_profile_session
from app.models.alarm import Alarm
from app.models.notification_event import NotificationEvent
from app.models.profile_session import ProfileSession
from app.models.reminder import Reminder
from app.models.routine import Routine
from app.models.task import Task
from app.schemas.scheduling import (
    AcknowledgeRequest,
    AlarmCreate,
    AlarmListOut,
    AlarmOut,
    AlarmStatus,
    AlarmUpdate,
    NotificationClearResponse,
    NotificationEventOut,
    NotificationListOut,
    NotificationMarkReadResponse,
    NotificationSourceType,
    NotificationStatus,
    ReminderCreate,
    ReminderListOut,
    ReminderOut,
    ReminderStatus,
    ReminderUpdate,
    RoutineCreate,
    RoutineListOut,
    RoutineOut,
    RoutineUpdate,
    SnoozeRequest,
)
from app.services.scheduler.service import (
    SchedulerService,
    as_utc,
    compute_next_occurrence,
    format_recurrence_days,
    parse_recurrence_days,
    resolve_timezone,
)

router = APIRouter(tags=["Scheduling"])

TModel = TypeVar("TModel")

ACTIVE_NOTIFICATION_STATUSES = (
    NotificationStatus.unread.value,
    NotificationStatus.read.value,
    NotificationStatus.suppressed_quiet_hours.value,
    NotificationStatus.missed_catchup.value,
)

UNREAD_BACKLOG_STATUSES = (
    NotificationStatus.unread.value,
    NotificationStatus.suppressed_quiet_hours.value,
    NotificationStatus.missed_catchup.value,
)


async def _get_owned_entity(
    db: AsyncSession,
    model_cls: Type[TModel],
    entity_id: str,
    profile_id: str,
    label: str,
) -> TModel:
    stmt = select(model_cls).where(
        model_cls.id == entity_id,
        model_cls.profile_id == profile_id,
        model_cls.is_deleted.is_(False),
    )
    row = (await db.execute(stmt)).scalar_one_or_none()
    if row is None:
        raise CompanionNotFoundError(message=f"{label} with ID {entity_id!r} not found.")
    return row


async def _ensure_task_owned(db: AsyncSession, task_id: str, profile_id: str) -> Task:
    return await _get_owned_entity(db, Task, task_id, profile_id, "Task")


def _resolve_snooze_until(payload: SnoozeRequest, now: datetime) -> datetime:
    if payload.until is not None:
        target = as_utc(payload.until)
        if target is None or target <= now:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Snooze 'until' timestamp must be in the future.",
            )
        return target
    return now + timedelta(minutes=payload.minutes)


async def _resolve_notifications_for_source(
    db: AsyncSession,
    profile_id: str,
    source_type: str,
    source_id: str,
    new_status: str,
    now: datetime,
) -> None:
    stmt = select(NotificationEvent).where(
        NotificationEvent.profile_id == profile_id,
        NotificationEvent.source_type == source_type,
        NotificationEvent.source_id == source_id,
        NotificationEvent.is_deleted.is_(False),
        NotificationEvent.status.in_(ACTIVE_NOTIFICATION_STATUSES),
    )
    rows = (await db.execute(stmt)).scalars().all()
    for ev in rows:
        ev.status = new_status
        ev.read_at = ev.read_at or now
        ev.resolved_at = now
        ev.updated_at = now


async def _complete_linked_task_if_active(
    db: AsyncSession,
    profile_id: str,
    task_id: Optional[str],
    now: datetime,
) -> None:
    if not task_id:
        return
    stmt = select(Task).where(
        Task.id == task_id,
        Task.profile_id == profile_id,
        Task.is_deleted.is_(False),
    )
    task = (await db.execute(stmt)).scalar_one_or_none()
    if task is not None and task.status in ("pending", "in_progress"):
        task.status = "completed"
        task.updated_at = now


def _apply_reminder_snooze(reminder: Reminder, until: datetime, now: datetime) -> None:
    reminder.status = ReminderStatus.snoozed.value
    reminder.snoozed_until = until
    reminder.updated_at = now


def _apply_reminder_resolution(reminder: Reminder, *, acknowledge: bool, now: datetime) -> None:
    if acknowledge:
        reminder.status = ReminderStatus.acknowledged.value
        reminder.acknowledged_at = now
    else:
        reminder.status = ReminderStatus.dismissed.value
    reminder.snoozed_until = None
    reminder.updated_at = now


def _apply_alarm_snooze(alarm: Alarm, until: datetime, now: datetime) -> None:
    alarm.status = AlarmStatus.snoozed.value
    alarm.snoozed_until = until
    alarm.enabled = True
    alarm.updated_at = now


def _apply_alarm_resolution(alarm: Alarm, *, acknowledge: bool, now: datetime) -> None:
    if acknowledge:
        alarm.acknowledged_at = now
    days = alarm.recurrence_days_list
    if days and alarm.time_of_day and alarm.enabled:
        alarm.scheduled_at = compute_next_occurrence(
            alarm.time_of_day,
            days,
            alarm.timezone,
            now,
        )
        alarm.status = AlarmStatus.armed.value
    else:
        alarm.status = AlarmStatus.acknowledged.value if acknowledge else AlarmStatus.dismissed.value
        alarm.enabled = False
    alarm.snoozed_until = None
    alarm.updated_at = now


async def _paginate_profile_query(
    db: AsyncSession,
    base_stmt,
    order_col,
    skip: int,
    limit: int,
):
    count_stmt = select(func.count()).select_from(base_stmt.subquery())
    total = (await db.execute(count_stmt)).scalar_one_or_none() or 0
    rows = (
        await db.execute(base_stmt.order_by(order_col).offset(skip).limit(limit))
    ).scalars().all()
    return rows, total


# ---------------------------------------------------------------------------
# Reminders (/api/v1/reminders)
# ---------------------------------------------------------------------------


@router.get("/reminders", response_model=ReminderListOut, summary="List Reminders")
async def list_reminders(
    status_filter: Optional[ReminderStatus] = Query(None, alias="status"),
    task_id: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ReminderListOut:
    query = select(Reminder).where(
        Reminder.profile_id == session.profile_id,
        Reminder.is_deleted.is_(False),
    )
    if status_filter is not None:
        query = query.where(Reminder.status == status_filter.value)
    if task_id is not None:
        query = query.where(Reminder.task_id == task_id)
    rows, total = await _paginate_profile_query(db, query, Reminder.scheduled_at.asc(), skip, limit)
    return ReminderListOut(items=[ReminderOut.model_validate(r) for r in rows], total=total)


@router.post("/reminders", response_model=ReminderOut, status_code=status.HTTP_201_CREATED, summary="Create Reminder")
async def create_reminder(
    payload: ReminderCreate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ReminderOut:
    if payload.id is not None:
        existing = (
            await db.execute(select(Reminder.id).where(Reminder.id == payload.id))
        ).scalar_one_or_none()
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Reminder with id '{payload.id}' already exists.",
            )
    if payload.task_id is not None:
        await _ensure_task_owned(db, payload.task_id, session.profile_id)

    kwargs = {}
    if payload.id is not None:
        kwargs["id"] = payload.id

    reminder = Reminder(
        **kwargs,
        profile_id=session.profile_id,
        task_id=payload.task_id,
        title=payload.title,
        notes=payload.notes,
        scheduled_at=as_utc(payload.scheduled_at) or payload.scheduled_at,
        timezone=payload.timezone,
        status=ReminderStatus.scheduled.value,
        bypass_quiet_hours=payload.bypass_quiet_hours,
        center_popup=payload.center_popup,
        origin=payload.origin,
        is_deleted=False,
        deleted_at=None,
    )
    db.add(reminder)
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(reminder)
    return ReminderOut.model_validate(reminder)


@router.get("/reminders/{reminder_id}", response_model=ReminderOut, summary="Get Reminder")
async def get_reminder(
    reminder_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ReminderOut:
    reminder = await _get_owned_entity(db, Reminder, reminder_id, session.profile_id, "Reminder")
    return ReminderOut.model_validate(reminder)


@router.patch("/reminders/{reminder_id}", response_model=ReminderOut, summary="Update Reminder")
async def update_reminder(
    reminder_id: str,
    payload: ReminderUpdate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ReminderOut:
    reminder = await _get_owned_entity(db, Reminder, reminder_id, session.profile_id, "Reminder")
    if payload.clear_task_id:
        reminder.task_id = None
    elif payload.task_id is not None:
        await _ensure_task_owned(db, payload.task_id, session.profile_id)
        reminder.task_id = payload.task_id

    if payload.title is not None:
        reminder.title = payload.title
    if payload.clear_notes:
        reminder.notes = None
    elif payload.notes is not None:
        reminder.notes = payload.notes
    if payload.scheduled_at is not None:
        reminder.scheduled_at = as_utc(payload.scheduled_at) or payload.scheduled_at
    if payload.timezone is not None:
        reminder.timezone = payload.timezone
    if payload.status is not None:
        reminder.status = payload.status.value
    if payload.clear_snoozed_until:
        reminder.snoozed_until = None
    elif payload.snoozed_until is not None:
        reminder.snoozed_until = as_utc(payload.snoozed_until)
    if payload.bypass_quiet_hours is not None:
        reminder.bypass_quiet_hours = payload.bypass_quiet_hours
    if payload.center_popup is not None:
        reminder.center_popup = payload.center_popup
    reminder.updated_at = datetime.now(timezone.utc)

    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(reminder)
    return ReminderOut.model_validate(reminder)


@router.delete("/reminders/{reminder_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete Reminder")
async def delete_reminder(
    reminder_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> None:
    reminder = await _get_owned_entity(db, Reminder, reminder_id, session.profile_id, "Reminder")
    now = datetime.now(timezone.utc)
    reminder.is_deleted = True
    reminder.deleted_at = now
    reminder.status = ReminderStatus.cancelled.value
    reminder.updated_at = now
    await _resolve_notifications_for_source(
        db,
        session.profile_id,
        NotificationSourceType.reminder.value,
        reminder.id,
        NotificationStatus.dismissed.value,
        now,
    )
    await validate_profile_session(db, session)
    await db.commit()


@router.post("/reminders/{reminder_id}/snooze", response_model=ReminderOut, summary="Snooze Reminder")
async def snooze_reminder(
    reminder_id: str,
    payload: SnoozeRequest = Body(default_factory=SnoozeRequest),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ReminderOut:
    reminder = await _get_owned_entity(db, Reminder, reminder_id, session.profile_id, "Reminder")
    now = datetime.now(timezone.utc)
    target = _resolve_snooze_until(payload, now)
    _apply_reminder_snooze(reminder, target, now)
    await _resolve_notifications_for_source(
        db,
        session.profile_id,
        NotificationSourceType.reminder.value,
        reminder.id,
        NotificationStatus.snoozed.value,
        now,
    )
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(reminder)
    return ReminderOut.model_validate(reminder)


@router.post("/reminders/{reminder_id}/acknowledge", response_model=ReminderOut, summary="Acknowledge Reminder")
async def acknowledge_reminder(
    reminder_id: str,
    payload: AcknowledgeRequest = Body(default_factory=AcknowledgeRequest),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ReminderOut:
    reminder = await _get_owned_entity(db, Reminder, reminder_id, session.profile_id, "Reminder")
    now = datetime.now(timezone.utc)
    _apply_reminder_resolution(reminder, acknowledge=True, now=now)
    if payload.complete_task:
        await _complete_linked_task_if_active(db, session.profile_id, reminder.task_id, now)
    await _resolve_notifications_for_source(
        db,
        session.profile_id,
        NotificationSourceType.reminder.value,
        reminder.id,
        NotificationStatus.acknowledged.value,
        now,
    )
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(reminder)
    return ReminderOut.model_validate(reminder)


@router.post("/reminders/{reminder_id}/dismiss", response_model=ReminderOut, summary="Dismiss Reminder")
async def dismiss_reminder(
    reminder_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ReminderOut:
    reminder = await _get_owned_entity(db, Reminder, reminder_id, session.profile_id, "Reminder")
    now = datetime.now(timezone.utc)
    _apply_reminder_resolution(reminder, acknowledge=False, now=now)
    await _resolve_notifications_for_source(
        db,
        session.profile_id,
        NotificationSourceType.reminder.value,
        reminder.id,
        NotificationStatus.dismissed.value,
        now,
    )
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(reminder)
    return ReminderOut.model_validate(reminder)


# ---------------------------------------------------------------------------
# Alarms (/api/v1/alarms)
# ---------------------------------------------------------------------------


@router.get("/alarms", response_model=AlarmListOut, summary="List Alarms")
async def list_alarms(
    enabled: Optional[bool] = Query(None),
    status_filter: Optional[AlarmStatus] = Query(None, alias="status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> AlarmListOut:
    query = select(Alarm).where(
        Alarm.profile_id == session.profile_id,
        Alarm.is_deleted.is_(False),
    )
    if enabled is not None:
        query = query.where(Alarm.enabled.is_(enabled))
    if status_filter is not None:
        query = query.where(Alarm.status == status_filter.value)
    rows, total = await _paginate_profile_query(db, query, Alarm.scheduled_at.asc(), skip, limit)
    return AlarmListOut(items=[AlarmOut.model_validate(a) for a in rows], total=total)


@router.post("/alarms", response_model=AlarmOut, status_code=status.HTTP_201_CREATED, summary="Create Alarm")
async def create_alarm(
    payload: AlarmCreate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> AlarmOut:
    if payload.id is not None:
        existing = (
            await db.execute(select(Alarm.id).where(Alarm.id == payload.id))
        ).scalar_one_or_none()
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Alarm with id '{payload.id}' already exists.",
            )

    now = datetime.now(timezone.utc)
    days = parse_recurrence_days(payload.recurrence_days)
    time_of_day = payload.time_of_day
    scheduled_at = as_utc(payload.scheduled_at) if payload.scheduled_at is not None else None

    if days and time_of_day is None and scheduled_at is not None:
        time_of_day = scheduled_at.astimezone(
            resolve_timezone(payload.timezone, allow_fallback_utc=True)
        ).strftime("%H:%M")

    if scheduled_at is None or (payload.enabled and days and time_of_day and scheduled_at <= now):
        assert time_of_day is not None
        scheduled_at = compute_next_occurrence(time_of_day, days, payload.timezone, now)

    kwargs = {}
    if payload.id is not None:
        kwargs["id"] = payload.id

    alarm = Alarm(
        **kwargs,
        profile_id=session.profile_id,
        label=payload.label,
        scheduled_at=scheduled_at,
        time_of_day=time_of_day,
        recurrence_days=format_recurrence_days(days),
        timezone=payload.timezone,
        enabled=payload.enabled,
        status=AlarmStatus.armed.value if payload.enabled else AlarmStatus.dismissed.value,
        bypass_quiet_hours=payload.bypass_quiet_hours,
        origin=payload.origin,
        is_deleted=False,
        deleted_at=None,
    )
    db.add(alarm)
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(alarm)
    return AlarmOut.model_validate(alarm)


@router.get("/alarms/{alarm_id}", response_model=AlarmOut, summary="Get Alarm")
async def get_alarm(
    alarm_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> AlarmOut:
    alarm = await _get_owned_entity(db, Alarm, alarm_id, session.profile_id, "Alarm")
    return AlarmOut.model_validate(alarm)


@router.patch("/alarms/{alarm_id}", response_model=AlarmOut, summary="Update Alarm")
async def update_alarm(
    alarm_id: str,
    payload: AlarmUpdate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> AlarmOut:
    alarm = await _get_owned_entity(db, Alarm, alarm_id, session.profile_id, "Alarm")
    now = datetime.now(timezone.utc)
    was_enabled = bool(alarm.enabled)
    recompute_scheduled = False

    if payload.label is not None:
        alarm.label = payload.label
    if payload.timezone is not None and payload.timezone != alarm.timezone:
        alarm.timezone = payload.timezone
        recompute_scheduled = True
    if payload.clear_time_of_day:
        if alarm.time_of_day is not None:
            recompute_scheduled = True
        alarm.time_of_day = None
    elif payload.time_of_day is not None and payload.time_of_day != alarm.time_of_day:
        alarm.time_of_day = payload.time_of_day
        recompute_scheduled = True
    if payload.clear_recurrence_days:
        if alarm.recurrence_days is not None:
            recompute_scheduled = True
        alarm.recurrence_days = None
    elif payload.recurrence_days is not None:
        formatted_days = format_recurrence_days(payload.recurrence_days)
        if formatted_days != alarm.recurrence_days:
            alarm.recurrence_days = formatted_days
            recompute_scheduled = True
    if payload.scheduled_at is not None:
        alarm.scheduled_at = as_utc(payload.scheduled_at) or payload.scheduled_at
    if payload.enabled is not None:
        alarm.enabled = payload.enabled
    if payload.status is not None:
        alarm.status = payload.status.value
    elif payload.enabled is True and alarm.status in (AlarmStatus.dismissed.value, AlarmStatus.acknowledged.value, AlarmStatus.missed.value):
        alarm.status = AlarmStatus.armed.value
    if payload.clear_snoozed_until:
        alarm.snoozed_until = None
    elif payload.snoozed_until is not None:
        alarm.snoozed_until = as_utc(payload.snoozed_until)
    if payload.bypass_quiet_hours is not None:
        alarm.bypass_quiet_hours = payload.bypass_quiet_hours

    days = alarm.recurrence_days_list
    if days and not alarm.time_of_day:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Recurring alarms require time_of_day (cannot clear time_of_day while recurrence_days is set).",
        )

    enabled_transitioned_to_true = (not was_enabled) and bool(alarm.enabled)
    is_past_or_due = (as_utc(alarm.scheduled_at) or now) <= now
    should_recompute = (
        recompute_scheduled
        or (bool(days) and is_past_or_due)
        or (enabled_transitioned_to_true and bool(days))
    )
    if (
        alarm.enabled
        and alarm.time_of_day
        and payload.scheduled_at is None
        and alarm.status == AlarmStatus.armed.value
        and should_recompute
    ):
        alarm.scheduled_at = compute_next_occurrence(alarm.time_of_day, days, alarm.timezone, now)

    alarm.updated_at = now
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(alarm)
    return AlarmOut.model_validate(alarm)


@router.delete("/alarms/{alarm_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete Alarm")
async def delete_alarm(
    alarm_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> None:
    alarm = await _get_owned_entity(db, Alarm, alarm_id, session.profile_id, "Alarm")
    now = datetime.now(timezone.utc)
    alarm.is_deleted = True
    alarm.deleted_at = now
    alarm.enabled = False
    alarm.updated_at = now
    await _resolve_notifications_for_source(
        db,
        session.profile_id,
        NotificationSourceType.alarm.value,
        alarm.id,
        NotificationStatus.dismissed.value,
        now,
    )
    await validate_profile_session(db, session)
    await db.commit()


@router.post("/alarms/{alarm_id}/snooze", response_model=AlarmOut, summary="Snooze Alarm")
async def snooze_alarm(
    alarm_id: str,
    payload: SnoozeRequest = Body(default_factory=SnoozeRequest),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> AlarmOut:
    alarm = await _get_owned_entity(db, Alarm, alarm_id, session.profile_id, "Alarm")
    now = datetime.now(timezone.utc)
    target = _resolve_snooze_until(payload, now)
    _apply_alarm_snooze(alarm, target, now)
    await _resolve_notifications_for_source(
        db,
        session.profile_id,
        NotificationSourceType.alarm.value,
        alarm.id,
        NotificationStatus.snoozed.value,
        now,
    )
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(alarm)
    return AlarmOut.model_validate(alarm)


@router.post("/alarms/{alarm_id}/acknowledge", response_model=AlarmOut, summary="Acknowledge Alarm")
async def acknowledge_alarm(
    alarm_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> AlarmOut:
    alarm = await _get_owned_entity(db, Alarm, alarm_id, session.profile_id, "Alarm")
    now = datetime.now(timezone.utc)
    _apply_alarm_resolution(alarm, acknowledge=True, now=now)
    await _resolve_notifications_for_source(
        db,
        session.profile_id,
        NotificationSourceType.alarm.value,
        alarm.id,
        NotificationStatus.acknowledged.value,
        now,
    )
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(alarm)
    return AlarmOut.model_validate(alarm)


@router.post("/alarms/{alarm_id}/dismiss", response_model=AlarmOut, summary="Dismiss Alarm")
async def dismiss_alarm(
    alarm_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> AlarmOut:
    alarm = await _get_owned_entity(db, Alarm, alarm_id, session.profile_id, "Alarm")
    now = datetime.now(timezone.utc)
    _apply_alarm_resolution(alarm, acknowledge=False, now=now)
    await _resolve_notifications_for_source(
        db,
        session.profile_id,
        NotificationSourceType.alarm.value,
        alarm.id,
        NotificationStatus.dismissed.value,
        now,
    )
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(alarm)
    return AlarmOut.model_validate(alarm)


# ---------------------------------------------------------------------------
# Routines (/api/v1/routines)
# ---------------------------------------------------------------------------


@router.get("/routines", response_model=RoutineListOut, summary="List Routines")
async def list_routines(
    enabled: Optional[bool] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> RoutineListOut:
    query = select(Routine).where(
        Routine.profile_id == session.profile_id,
        Routine.is_deleted.is_(False),
    )
    if enabled is not None:
        query = query.where(Routine.enabled.is_(enabled))
    rows, total = await _paginate_profile_query(db, query, Routine.created_at.desc(), skip, limit)
    return RoutineListOut(items=[RoutineOut.model_validate(r) for r in rows], total=total)


@router.post("/routines", response_model=RoutineOut, status_code=status.HTTP_201_CREATED, summary="Create Routine")
async def create_routine(
    payload: RoutineCreate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> RoutineOut:
    now = datetime.now(timezone.utc)
    days = parse_recurrence_days(payload.recurrence_days)
    next_run_at = (
        compute_next_occurrence(payload.time_of_day, days, payload.timezone, now)
        if payload.enabled
        else None
    )
    routine = Routine(
        profile_id=session.profile_id,
        title=payload.title,
        prompt_template=payload.prompt_template,
        fallback_message=payload.fallback_message,
        time_of_day=payload.time_of_day,
        recurrence_days=format_recurrence_days(days),
        timezone=payload.timezone,
        enabled=payload.enabled,
        bypass_quiet_hours=payload.bypass_quiet_hours,
        next_run_at=next_run_at,
        is_deleted=False,
        deleted_at=None,
    )
    db.add(routine)
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(routine)
    return RoutineOut.model_validate(routine)


@router.get("/routines/{routine_id}", response_model=RoutineOut, summary="Get Routine")
async def get_routine(
    routine_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> RoutineOut:
    routine = await _get_owned_entity(db, Routine, routine_id, session.profile_id, "Routine")
    return RoutineOut.model_validate(routine)


@router.patch("/routines/{routine_id}", response_model=RoutineOut, summary="Update Routine")
async def update_routine(
    routine_id: str,
    payload: RoutineUpdate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> RoutineOut:
    routine = await _get_owned_entity(db, Routine, routine_id, session.profile_id, "Routine")
    now = datetime.now(timezone.utc)

    recompute_next = False
    if payload.title is not None:
        routine.title = payload.title
    if payload.clear_prompt_template:
        routine.prompt_template = None
    elif payload.prompt_template is not None:
        routine.prompt_template = payload.prompt_template
    if payload.fallback_message is not None:
        routine.fallback_message = payload.fallback_message
    if payload.time_of_day is not None:
        routine.time_of_day = payload.time_of_day
        recompute_next = True
    if payload.clear_recurrence_days:
        routine.recurrence_days = None
        recompute_next = True
    elif payload.recurrence_days is not None:
        routine.recurrence_days = format_recurrence_days(payload.recurrence_days)
        recompute_next = True
    if payload.timezone is not None:
        routine.timezone = payload.timezone
        recompute_next = True
    if payload.enabled is not None:
        routine.enabled = payload.enabled
        recompute_next = True
    if payload.bypass_quiet_hours is not None:
        routine.bypass_quiet_hours = payload.bypass_quiet_hours

    if not routine.enabled:
        routine.next_run_at = None
    elif recompute_next or routine.next_run_at is None:
        routine.next_run_at = compute_next_occurrence(
            routine.time_of_day,
            routine.recurrence_days_list,
            routine.timezone,
            now,
        )

    routine.updated_at = now
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(routine)
    return RoutineOut.model_validate(routine)


@router.delete("/routines/{routine_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete Routine")
async def delete_routine(
    routine_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> None:
    routine = await _get_owned_entity(db, Routine, routine_id, session.profile_id, "Routine")
    now = datetime.now(timezone.utc)
    routine.is_deleted = True
    routine.deleted_at = now
    routine.enabled = False
    routine.next_run_at = None
    routine.updated_at = now
    await validate_profile_session(db, session)
    await db.commit()


@router.post("/routines/{routine_id}/run", response_model=NotificationEventOut, summary="Trigger Routine Immediately")
async def run_routine_now(
    routine_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NotificationEventOut:
    routine = await _get_owned_entity(db, Routine, routine_id, session.profile_id, "Routine")
    await validate_profile_session(db, session)
    event = await SchedulerService(db).trigger_routine_now(routine, commit=True)
    return NotificationEventOut.model_validate(event)


# ---------------------------------------------------------------------------
# Durable Notification Backlog (/api/v1/notifications)
# ---------------------------------------------------------------------------


@router.get("/notifications", response_model=NotificationListOut, summary="List Notification Backlog")
async def list_notifications(
    status_filter: Optional[NotificationStatus] = Query(None, alias="status"),
    source_type: Optional[NotificationSourceType] = Query(None),
    unread_only: bool = Query(False),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NotificationListOut:
    base_profile = select(NotificationEvent).where(
        NotificationEvent.profile_id == session.profile_id,
        NotificationEvent.is_deleted.is_(False),
    )

    unread_count = (
        await db.execute(
            select(func.count()).select_from(
                base_profile.where(
                    NotificationEvent.status.in_(UNREAD_BACKLOG_STATUSES),
                    NotificationEvent.read_at.is_(None),
                ).subquery()
            )
        )
    ).scalar_one_or_none() or 0

    missed_count = (
        await db.execute(
            select(func.count()).select_from(
                base_profile.where(
                    NotificationEvent.status == NotificationStatus.missed_catchup.value
                ).subquery()
            )
        )
    ).scalar_one_or_none() or 0

    query = base_profile
    if status_filter is not None:
        query = query.where(NotificationEvent.status == status_filter.value)
    if source_type is not None:
        query = query.where(NotificationEvent.source_type == source_type.value)
    if unread_only:
        query = query.where(NotificationEvent.status.in_(UNREAD_BACKLOG_STATUSES))

    rows, total = await _paginate_profile_query(
        db,
        query,
        NotificationEvent.triggered_at.desc(),
        skip,
        limit,
    )
    return NotificationListOut(
        items=[NotificationEventOut.model_validate(ev) for ev in rows],
        total=total,
        unread_count=unread_count,
        missed_count=missed_count,
    )


@router.post("/notifications/clear-all", response_model=NotificationClearResponse, summary="Clear Active Notifications")
async def clear_all_notifications(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NotificationClearResponse:
    now = datetime.now(timezone.utc)
    stmt = select(NotificationEvent).where(
        NotificationEvent.profile_id == session.profile_id,
        NotificationEvent.is_deleted.is_(False),
        NotificationEvent.status.in_(ACTIVE_NOTIFICATION_STATUSES),
    )
    rows = (await db.execute(stmt)).scalars().all()
    for ev in rows:
        ev.status = NotificationStatus.dismissed.value
        ev.read_at = ev.read_at or now
        ev.resolved_at = now
        ev.updated_at = now
    await validate_profile_session(db, session)
    await db.commit()
    return NotificationClearResponse(cleared_count=len(rows))


@router.post("/notifications/mark-all-read", response_model=NotificationMarkReadResponse, summary="Mark All Notifications Read")
async def mark_all_notifications_read(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NotificationMarkReadResponse:
    now = datetime.now(timezone.utc)
    stmt = select(NotificationEvent).where(
        NotificationEvent.profile_id == session.profile_id,
        NotificationEvent.is_deleted.is_(False),
        or_(
            NotificationEvent.status.in_(UNREAD_BACKLOG_STATUSES),
            NotificationEvent.read_at.is_(None),
        ),
    )
    rows = (await db.execute(stmt)).scalars().all()
    for ev in rows:
        ev.read_at = ev.read_at or now
        # Keep active ringing alarms in unread status so they remain prominent
        # until explicitly stopped, snoozed, or dismissed.
        if (
            ev.status in UNREAD_BACKLOG_STATUSES
            and ev.source_type != NotificationSourceType.alarm.value
        ):
            ev.status = NotificationStatus.read.value
        ev.updated_at = now
    await validate_profile_session(db, session)
    await db.commit()
    return NotificationMarkReadResponse(updated_count=len(rows))


@router.post("/notifications/{event_id}/read", response_model=NotificationEventOut, summary="Mark Notification Read")
async def mark_notification_read(
    event_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NotificationEventOut:
    ev = await _get_owned_entity(db, NotificationEvent, event_id, session.profile_id, "NotificationEvent")
    now = datetime.now(timezone.utc)
    ev.read_at = ev.read_at or now
    if ev.status in UNREAD_BACKLOG_STATUSES:
        ev.status = NotificationStatus.read.value
    ev.updated_at = now
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(ev)
    return NotificationEventOut.model_validate(ev)


@router.post("/notifications/{event_id}/acknowledge", response_model=NotificationEventOut, summary="Acknowledge Notification")
async def acknowledge_notification(
    event_id: str,
    payload: AcknowledgeRequest = Body(default_factory=AcknowledgeRequest),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NotificationEventOut:
    ev = await _get_owned_entity(db, NotificationEvent, event_id, session.profile_id, "NotificationEvent")
    now = datetime.now(timezone.utc)
    ev.status = NotificationStatus.acknowledged.value
    ev.read_at = ev.read_at or now
    ev.resolved_at = now
    ev.updated_at = now

    if ev.source_type == NotificationSourceType.reminder.value:
        rem_stmt = select(Reminder).where(
            Reminder.id == ev.source_id,
            Reminder.profile_id == session.profile_id,
            Reminder.is_deleted.is_(False),
        )
        rem = (await db.execute(rem_stmt)).scalar_one_or_none()
        if rem is not None:
            if rem.status in (ReminderStatus.scheduled.value, ReminderStatus.fired.value, ReminderStatus.snoozed.value, ReminderStatus.missed.value):
                _apply_reminder_resolution(rem, acknowledge=True, now=now)
            if payload.complete_task:
                await _complete_linked_task_if_active(db, session.profile_id, rem.task_id, now)
    elif ev.source_type == NotificationSourceType.alarm.value:
        alarm_stmt = select(Alarm).where(
            Alarm.id == ev.source_id,
            Alarm.profile_id == session.profile_id,
            Alarm.is_deleted.is_(False),
        )
        alarm = (await db.execute(alarm_stmt)).scalar_one_or_none()
        if alarm is not None and alarm.status in (AlarmStatus.armed.value, AlarmStatus.ringing.value, AlarmStatus.snoozed.value, AlarmStatus.missed.value):
            _apply_alarm_resolution(alarm, acknowledge=True, now=now)
    elif ev.source_type == NotificationSourceType.task_reminder.value and payload.complete_task:
        await _complete_linked_task_if_active(db, session.profile_id, ev.source_id, now)

    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(ev)
    return NotificationEventOut.model_validate(ev)


@router.post("/notifications/{event_id}/dismiss", response_model=NotificationEventOut, summary="Dismiss Notification")
async def dismiss_notification(
    event_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NotificationEventOut:
    ev = await _get_owned_entity(db, NotificationEvent, event_id, session.profile_id, "NotificationEvent")
    now = datetime.now(timezone.utc)
    ev.status = NotificationStatus.dismissed.value
    ev.read_at = ev.read_at or now
    ev.resolved_at = now
    ev.updated_at = now

    if ev.source_type == NotificationSourceType.reminder.value:
        rem_stmt = select(Reminder).where(
            Reminder.id == ev.source_id,
            Reminder.profile_id == session.profile_id,
            Reminder.is_deleted.is_(False),
        )
        rem = (await db.execute(rem_stmt)).scalar_one_or_none()
        if rem is not None and rem.status in (ReminderStatus.scheduled.value, ReminderStatus.fired.value, ReminderStatus.snoozed.value, ReminderStatus.missed.value):
            _apply_reminder_resolution(rem, acknowledge=False, now=now)
    elif ev.source_type == NotificationSourceType.alarm.value:
        alarm_stmt = select(Alarm).where(
            Alarm.id == ev.source_id,
            Alarm.profile_id == session.profile_id,
            Alarm.is_deleted.is_(False),
        )
        alarm = (await db.execute(alarm_stmt)).scalar_one_or_none()
        if alarm is not None and alarm.status in (AlarmStatus.armed.value, AlarmStatus.ringing.value, AlarmStatus.snoozed.value, AlarmStatus.missed.value):
            _apply_alarm_resolution(alarm, acknowledge=False, now=now)

    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(ev)
    return NotificationEventOut.model_validate(ev)


@router.post("/notifications/{event_id}/snooze", response_model=NotificationEventOut, summary="Snooze Notification")
async def snooze_notification(
    event_id: str,
    payload: SnoozeRequest = Body(default_factory=SnoozeRequest),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NotificationEventOut:
    ev = await _get_owned_entity(db, NotificationEvent, event_id, session.profile_id, "NotificationEvent")
    now = datetime.now(timezone.utc)
    target = _resolve_snooze_until(payload, now)
    ev.status = NotificationStatus.snoozed.value
    ev.read_at = ev.read_at or now
    ev.resolved_at = now
    ev.updated_at = now

    if ev.source_type == NotificationSourceType.reminder.value:
        rem_stmt = select(Reminder).where(
            Reminder.id == ev.source_id,
            Reminder.profile_id == session.profile_id,
            Reminder.is_deleted.is_(False),
        )
        rem = (await db.execute(rem_stmt)).scalar_one_or_none()
        if rem is not None:
            _apply_reminder_snooze(rem, target, now)
    elif ev.source_type == NotificationSourceType.alarm.value:
        alarm_stmt = select(Alarm).where(
            Alarm.id == ev.source_id,
            Alarm.profile_id == session.profile_id,
            Alarm.is_deleted.is_(False),
        )
        alarm = (await db.execute(alarm_stmt)).scalar_one_or_none()
        if alarm is not None:
            _apply_alarm_snooze(alarm, target, now)
    elif ev.source_type == NotificationSourceType.task_reminder.value:
        task_stmt = select(Task).where(
            Task.id == ev.source_id,
            Task.profile_id == session.profile_id,
            Task.is_deleted.is_(False),
        )
        task = (await db.execute(task_stmt)).scalar_one_or_none()
        if task is not None and task.status in ("pending", "in_progress"):
            task.reminder_at = target
            task.updated_at = now

    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(ev)
    return NotificationEventOut.model_validate(ev)
