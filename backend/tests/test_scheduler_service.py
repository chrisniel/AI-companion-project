"""Unit & integration tests for SchedulerService, Quiet Hours, Catch-Up & DEBT-V1-08."""

from datetime import datetime, timedelta, timezone
import uuid
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.alarm import Alarm
from app.models.memory import Memory
from app.models.notification_event import NotificationEvent
from app.models.profile import Profile
from app.models.reminder import Reminder
from app.models.routine import Routine
from app.models.task import Task
from app.services.profile_purge_service import ProfilePurgeService
from app.services.scheduler.service import (
    SchedulerService,
    compute_next_occurrence,
    is_within_quiet_hours,
    resolve_timezone,
    validate_timezone_name,
)


def test_resolve_timezone_zero_dependency_and_dst():
    assert resolve_timezone("UTC") == timezone.utc
    assert resolve_timezone("Etc/UTC") == timezone.utc
    assert resolve_timezone("+08:00").utcoffset(None) == timedelta(hours=8)
    assert resolve_timezone("UTC-05:30").utcoffset(None) == timedelta(hours=-5, minutes=-30)

    ny = resolve_timezone("America/New_York")
    winter_utc = datetime(2026, 1, 15, 15, 0, tzinfo=timezone.utc)
    summer_utc = datetime(2026, 7, 15, 15, 0, tzinfo=timezone.utc)
    assert winter_utc.astimezone(ny).utcoffset() == timedelta(hours=-5)
    assert summer_utc.astimezone(ny).utcoffset() == timedelta(hours=-4)

    manila = resolve_timezone("Asia/Manila")
    assert datetime(2026, 6, 1, 0, 0, tzinfo=timezone.utc).astimezone(manila).hour == 8

    assert validate_timezone_name("america/new_york") == "America/New_York"
    with pytest.raises(ValueError):
        validate_timezone_name("Mars/Olympus_Mons")


def test_quiet_hours_half_open_and_overnight_windows():
    profile = Profile(
        id=str(uuid.uuid4()),
        name="QH",
        quiet_hours_enabled=True,
        quiet_hours_start="22:00",
        quiet_hours_end="07:00",
        quiet_hours_timezone="Asia/Manila",  # UTC+8
    )

    # 21:59 Manila = 13:59 UTC -> not quiet
    assert is_within_quiet_hours(profile, datetime(2026, 11, 14, 13, 59, tzinfo=timezone.utc)) is False
    # 22:00 Manila = 14:00 UTC -> quiet
    assert is_within_quiet_hours(profile, datetime(2026, 11, 14, 14, 0, tzinfo=timezone.utc)) is True
    # 06:59 Manila = 22:59 UTC -> quiet
    assert is_within_quiet_hours(profile, datetime(2026, 11, 14, 22, 59, tzinfo=timezone.utc)) is True
    # 07:00 Manila = 23:00 UTC -> boundary end is OPEN ([start, end)) -> not quiet!
    assert is_within_quiet_hours(profile, datetime(2026, 11, 14, 23, 0, tzinfo=timezone.utc)) is False

    # Same-day window [13:00, 15:00) UTC
    day_profile = Profile(
        id=str(uuid.uuid4()),
        name="DayQH",
        quiet_hours_enabled=True,
        quiet_hours_start="13:00",
        quiet_hours_end="15:00",
        quiet_hours_timezone="UTC",
    )
    assert is_within_quiet_hours(day_profile, datetime(2026, 11, 14, 13, 0, tzinfo=timezone.utc)) is True
    assert is_within_quiet_hours(day_profile, datetime(2026, 11, 14, 15, 0, tzinfo=timezone.utc)) is False


def test_compute_next_occurrence_respects_weekdays_and_timezone():
    # 2026-11-16 is a Monday (weekday=0)
    after = datetime(2026, 11, 16, 10, 0, tzinfo=timezone.utc)
    # Every Wednesday (2) & Friday (4) at 08:00 Asia/Manila (UTC+8 => 00:00 UTC)
    next_dt = compute_next_occurrence("08:00", [2, 4], "Asia/Manila", after)
    assert next_dt == datetime(2026, 11, 18, 0, 0, tzinfo=timezone.utc)


async def test_scheduler_quiet_hours_suppression_vs_alarm_bypass(test_session: AsyncSession, profile_id: str):
    profile = await test_session.get(Profile, profile_id)
    assert profile is not None
    profile.quiet_hours_enabled = True
    profile.quiet_hours_start = "22:00"
    profile.quiet_hours_end = "07:00"
    profile.quiet_hours_timezone = "UTC"

    now = datetime(2026, 11, 14, 23, 30, tzinfo=timezone.utc)  # Inside quiet hours

    quiet_rem = Reminder(
        profile_id=profile_id,
        title="Hydrate",
        scheduled_at=now - timedelta(seconds=30),
        bypass_quiet_hours=False,
    )
    urgent_rem = Reminder(
        profile_id=profile_id,
        title="Medication",
        scheduled_at=now - timedelta(seconds=20),
        bypass_quiet_hours=True,
    )
    alarm = Alarm(
        profile_id=profile_id,
        label="Wake up",
        scheduled_at=now - timedelta(seconds=10),
        bypass_quiet_hours=True,
    )
    routine = Routine(
        profile_id=profile_id,
        title="Evening Reflection",
        fallback_message="How did your day go?",
        time_of_day="23:29",
        timezone="UTC",
        enabled=True,
        bypass_quiet_hours=False,
        next_run_at=now - timedelta(seconds=60),
    )
    test_session.add_all([quiet_rem, urgent_rem, alarm, routine])
    await test_session.commit()

    svc = SchedulerService(test_session)
    events = await svc.run_tick(now=now, grace_seconds=300)
    assert len(events) == 4

    by_source = {(e.source_type, e.source_id): e for e in events}
    assert by_source[("reminder", quiet_rem.id)].status == "suppressed_quiet_hours"
    assert by_source[("reminder", quiet_rem.id)].delivery_policy == "quiet_hours_suppressed"

    assert by_source[("reminder", urgent_rem.id)].status == "unread"
    assert by_source[("reminder", urgent_rem.id)].delivery_policy == "immediate"

    assert by_source[("alarm", alarm.id)].status == "unread"
    assert by_source[("alarm", alarm.id)].urgency == "high"
    assert alarm.status == "ringing"

    assert by_source[("routine", routine.id)].status == "suppressed_quiet_hours"
    assert by_source[("routine", routine.id)].body == "How did your day go?"
    assert routine.last_status == "suppressed_quiet_hours"
    assert routine.next_run_at > now

    # Second tick immediately after must emit zero duplicates
    events_again = await svc.run_tick(now=now + timedelta(seconds=15), grace_seconds=300)
    assert events_again == []


async def test_missed_event_catchup_and_recurring_alarm_advance(test_session: AsyncSession, profile_id: str):
    now = datetime(2026, 11, 16, 12, 0, tzinfo=timezone.utc)  # Monday
    overdue = now - timedelta(hours=2)  # Well outside 300s grace window

    rem = Reminder(
        profile_id=profile_id,
        title="Missed standup",
        scheduled_at=overdue,
    )
    oneshot_alarm = Alarm(
        profile_id=profile_id,
        label="One-shot missed",
        scheduled_at=overdue,
        enabled=True,
    )
    recurring_alarm = Alarm(
        profile_id=profile_id,
        label="Weekday 08:00 Alarm",
        scheduled_at=overdue,
        time_of_day="08:00",
        recurrence_days="0,1,2,3,4",
        timezone="UTC",
        enabled=True,
    )
    routine = Routine(
        profile_id=profile_id,
        title="Morning Check-in",
        fallback_message="Good morning!",
        time_of_day="07:30",
        timezone="UTC",
        enabled=True,
        next_run_at=overdue,
    )
    test_session.add_all([rem, oneshot_alarm, recurring_alarm, routine])
    await test_session.commit()

    svc = SchedulerService(test_session)
    events = await svc.reconcile_missed_events(now=now, grace_seconds=300)
    assert len(events) == 4
    assert all(e.is_missed_catchup is True for e in events)
    assert all(e.delivery_policy == "missed_catchup" for e in events)
    assert rem.status == "missed"
    assert oneshot_alarm.status == "missed"
    assert oneshot_alarm.enabled is False
    assert recurring_alarm.status == "armed"
    assert recurring_alarm.enabled is True
    assert recurring_alarm.scheduled_at == datetime(2026, 11, 17, 8, 0, tzinfo=timezone.utc)
    assert routine.last_status == "missed_catchup"
    assert routine.next_run_at == datetime(2026, 11, 17, 7, 30, tzinfo=timezone.utc)


async def test_task_reminder_bridge_deduplication_and_debt_v1_08_sweep(test_session: AsyncSession, profile_id: str):
    now = datetime(2026, 11, 14, 15, 0, tzinfo=timezone.utc)
    rem_time = now - timedelta(seconds=30)

    active_task = Task(
        profile_id=profile_id,
        title="Submit report",
        notes="Before 4pm",
        status="pending",
        reminder_at=rem_time,
    )
    done_task = Task(
        profile_id=profile_id,
        title="Already finished",
        status="completed",
        reminder_at=rem_time,
    )
    expired_mem = Memory(
        profile_id=profile_id,
        category="context",
        content="Temporary meeting link",
        valid_from=now - timedelta(hours=80),
        expires_at=now - timedelta(hours=1),
        scope="profile",
    )
    fresh_mem = Memory(
        profile_id=profile_id,
        category="context",
        content="Still active today",
        valid_from=now - timedelta(hours=1),
        expires_at=now + timedelta(hours=24),
        scope="profile",
    )
    test_session.add_all([active_task, done_task, expired_mem, fresh_mem])
    await test_session.commit()

    svc = SchedulerService(test_session)
    events = await svc.run_tick(now=now, grace_seconds=300)
    assert len(events) == 1
    assert events[0].source_type == "task_reminder"
    assert events[0].source_id == active_task.id

    await test_session.refresh(expired_mem)
    await test_session.refresh(fresh_mem)
    assert expired_mem.is_deleted is True
    assert expired_mem.deleted_at is not None
    assert fresh_mem.is_deleted is False

    # Running another tick at later wall-clock time must NOT duplicate the same task reminder_at
    events2 = await svc.run_tick(now=now + timedelta(seconds=45), grace_seconds=300)
    assert events2 == []

    # Updating Task.reminder_at to a new future time fires once when that new time arrives
    new_rem = now + timedelta(minutes=10)
    active_task.reminder_at = new_rem
    await test_session.commit()
    events3 = await svc.run_tick(now=new_rem + timedelta(seconds=5), grace_seconds=300)
    assert len(events3) == 1
    assert events3[0].source_id == active_task.id

    # ProfilePurgeService maintenance sweep also sweeps newly expired temporary memories
    real_now = datetime.now(timezone.utc)
    expired2 = Memory(
        profile_id=profile_id,
        category="context",
        content="Temp 2",
        valid_from=real_now - timedelta(hours=5),
        expires_at=real_now - timedelta(minutes=1),
        scope="profile",
    )
    test_session.add(expired2)
    await test_session.commit()
    purge_svc = ProfilePurgeService(test_session)
    await purge_svc.execute_maintenance_purge()
    await test_session.refresh(expired2)
    assert expired2.is_deleted is True
