"""SchedulerService, Quiet Hours Policy Engine & Expired Memory Sweep (D10 / PC-SCHED-001..005 / DEBT-V1-08)."""

import asyncio
from datetime import date, datetime, time as dt_time, timedelta, timezone, tzinfo
import logging
import re
from typing import Dict, Iterable, List, Optional, Tuple
import zoneinfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.alarm import Alarm
from app.models.base import parse_recurrence_days_string
from app.models.memory import Memory
from app.models.notification_event import NotificationEvent
from app.models.profile import Profile
from app.models.reminder import Reminder
from app.models.routine import Routine
from app.models.task import Task

logger = logging.getLogger(__name__)

HHMM_PATTERN = re.compile(r"^([01]\d|2[0-3]):([0-5]\d)$")
FIXED_OFFSET_PATTERN = re.compile(r"^(?:UTC|GMT)?([+-])(\d{1,2})(?::?(\d{2}))?$", re.IGNORECASE)


def as_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """Normalize naive or aware datetime objects to UTC."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def parse_hhmm(value: str) -> Tuple[int, int]:
    """Validate and parse a 24-hour 'HH:MM' string into (hour, minute)."""
    if not isinstance(value, str):
        raise ValueError("Time must be a 'HH:MM' string")
    match = HHMM_PATTERN.match(value.strip())
    if not match:
        raise ValueError(f"Invalid 24-hour time format '{value}'; expected 'HH:MM'")
    return int(match.group(1)), int(match.group(2))


def parse_recurrence_days(raw: Optional[Iterable[int] | str]) -> List[int]:
    """Normalize weekday list/string ('0..6', Monday=0..Sunday=6) into sorted unique integers."""
    if raw is None:
        return []
    if isinstance(raw, str):
        return parse_recurrence_days_string(raw)
    result: List[int] = []
    for item in raw:
        day = int(item)
        if day < 0 or day > 6:
            raise ValueError(f"Weekday index out of range (0..6): {day}")
        if day not in result:
            result.append(day)
    return sorted(result)


def format_recurrence_days(days: Optional[List[int]]) -> Optional[str]:
    """Format validated weekday list into storage string, or None if empty."""
    if not days:
        return None
    normalized = parse_recurrence_days(days)
    return ",".join(str(d) for d in normalized) if normalized else None


def _nth_weekday_of_month(year: int, month: int, weekday: int, nth: int) -> date:
    """Return the nth (1-based) or last (-1) weekday (0=Mon..6=Sun) of month."""
    if nth > 0:
        first_day = date(year, month, 1)
        offset = (weekday - first_day.weekday()) % 7
        return first_day + timedelta(days=offset + (nth - 1) * 7)
    next_month = date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)
    last_day = next_month - timedelta(days=1)
    offset = (last_day.weekday() - weekday) % 7
    return last_day - timedelta(days=offset)


class _RuleBasedTzInfo(tzinfo):
    """Zero-dependency IANA/DST tzinfo fallback for Windows environments without tzdata."""

    def __init__(self, key: str, std_minutes: int, dst_rule: Optional[str] = None):
        self.key = key
        self._std = timedelta(minutes=std_minutes)
        self._dst_rule = dst_rule
        self._dst_offset = timedelta(hours=1) if dst_rule else timedelta(0)

    def _is_dst_utc(self, dt_utc_naive: datetime) -> bool:
        if not self._dst_rule:
            return False
        year = dt_utc_naive.year
        if self._dst_rule == "US":
            # 2nd Sunday of March 02:00 standard -> 1st Sunday of November 02:00 DST
            start_local = datetime.combine(_nth_weekday_of_month(year, 3, 6, 2), dt_time(2, 0))
            end_local = datetime.combine(_nth_weekday_of_month(year, 11, 6, 1), dt_time(2, 0))
            start_utc = start_local - self._std
            end_utc = end_local - (self._std + self._dst_offset)
            return start_utc <= dt_utc_naive < end_utc
        if self._dst_rule == "EU":
            # Last Sunday of March 01:00 UTC -> Last Sunday of October 01:00 UTC
            start_utc = datetime.combine(_nth_weekday_of_month(year, 3, 6, -1), dt_time(1, 0))
            end_utc = datetime.combine(_nth_weekday_of_month(year, 10, 6, -1), dt_time(1, 0))
            return start_utc <= dt_utc_naive < end_utc
        if self._dst_rule == "AU":
            # Southern hemisphere: DST active Jan..1st Sun Apr 03:00 DST and 1st Sun Oct 02:00 std..Dec
            end_dst_utc = datetime.combine(_nth_weekday_of_month(year, 4, 6, 1), dt_time(3, 0)) - (self._std + self._dst_offset)
            start_dst_utc = datetime.combine(_nth_weekday_of_month(year, 10, 6, 1), dt_time(2, 0)) - self._std
            return dt_utc_naive < end_dst_utc or dt_utc_naive >= start_dst_utc
        if self._dst_rule == "NZ":
            # 1st Sun Apr 03:00 DST and Last Sun Sep 02:00 std
            end_dst_utc = datetime.combine(_nth_weekday_of_month(year, 4, 6, 1), dt_time(3, 0)) - (self._std + self._dst_offset)
            start_dst_utc = datetime.combine(_nth_weekday_of_month(year, 9, 6, -1), dt_time(2, 0)) - self._std
            return dt_utc_naive < end_dst_utc or dt_utc_naive >= start_dst_utc
        return False

    def _is_dst_local(self, dt_local_naive: datetime) -> bool:
        if not self._dst_rule:
            return False
        year = dt_local_naive.year
        if self._dst_rule == "US":
            start = datetime.combine(_nth_weekday_of_month(year, 3, 6, 2), dt_time(2, 0))
            end = datetime.combine(_nth_weekday_of_month(year, 11, 6, 1), dt_time(2, 0))
            return start <= dt_local_naive < end
        if self._dst_rule == "EU":
            start = datetime.combine(_nth_weekday_of_month(year, 3, 6, -1), dt_time(1, 0)) + self._std
            end = datetime.combine(_nth_weekday_of_month(year, 10, 6, -1), dt_time(1, 0)) + self._std + self._dst_offset
            return start <= dt_local_naive < end
        if self._dst_rule == "AU":
            end_dst = datetime.combine(_nth_weekday_of_month(year, 4, 6, 1), dt_time(3, 0))
            start_dst = datetime.combine(_nth_weekday_of_month(year, 10, 6, 1), dt_time(2, 0))
            return dt_local_naive < end_dst or dt_local_naive >= start_dst
        if self._dst_rule == "NZ":
            end_dst = datetime.combine(_nth_weekday_of_month(year, 4, 6, 1), dt_time(3, 0))
            start_dst = datetime.combine(_nth_weekday_of_month(year, 9, 6, -1), dt_time(2, 0))
            return dt_local_naive < end_dst or dt_local_naive >= start_dst
        return False

    def fromutc(self, dt: datetime) -> datetime:
        if dt.tzinfo is not self:
            raise ValueError("fromutc: requires dt.tzinfo is self")
        utc_naive = dt.replace(tzinfo=None)
        offset = self._std + (self._dst_offset if self._is_dst_utc(utc_naive) else timedelta(0))
        return (dt + offset)

    def utcoffset(self, dt: Optional[datetime]) -> timedelta:
        if dt is None:
            return self._std
        naive = dt.replace(tzinfo=None)
        return self._std + (self._dst_offset if self._is_dst_local(naive) else timedelta(0))

    def dst(self, dt: Optional[datetime]) -> timedelta:
        if dt is None or not self._dst_rule:
            return timedelta(0)
        return self._dst_offset if self._is_dst_local(dt.replace(tzinfo=None)) else timedelta(0)

    def tzname(self, dt: Optional[datetime]) -> str:
        return self.key


_BUILTIN_IANA_ZONES: Dict[str, Tuple[int, Optional[str]]] = {
    "America/New_York": (-300, "US"),
    "America/Detroit": (-300, "US"),
    "America/Toronto": (-300, "US"),
    "America/Montreal": (-300, "US"),
    "America/Chicago": (-360, "US"),
    "America/Winnipeg": (-360, "US"),
    "America/Denver": (-420, "US"),
    "America/Edmonton": (-420, "US"),
    "America/Phoenix": (-420, None),
    "America/Los_Angeles": (-480, "US"),
    "America/Vancouver": (-480, "US"),
    "America/Anchorage": (-540, "US"),
    "America/Halifax": (-240, "US"),
    "America/St_Johns": (-210, "US"),
    "America/Mexico_City": (-360, None),
    "America/Bogota": (-300, None),
    "America/Lima": (-300, None),
    "America/Sao_Paulo": (-180, None),
    "America/Argentina/Buenos_Aires": (-180, None),
    "Pacific/Honolulu": (-600, None),
    "Europe/London": (0, "EU"),
    "Europe/Dublin": (0, "EU"),
    "Europe/Lisbon": (0, "EU"),
    "Europe/Paris": (60, "EU"),
    "Europe/Berlin": (60, "EU"),
    "Europe/Madrid": (60, "EU"),
    "Europe/Rome": (60, "EU"),
    "Europe/Amsterdam": (60, "EU"),
    "Europe/Brussels": (60, "EU"),
    "Europe/Zurich": (60, "EU"),
    "Europe/Vienna": (60, "EU"),
    "Europe/Prague": (60, "EU"),
    "Europe/Warsaw": (60, "EU"),
    "Europe/Stockholm": (60, "EU"),
    "Europe/Oslo": (60, "EU"),
    "Europe/Copenhagen": (60, "EU"),
    "Europe/Athens": (120, "EU"),
    "Europe/Helsinki": (120, "EU"),
    "Europe/Bucharest": (120, "EU"),
    "Europe/Istanbul": (180, None),
    "Europe/Moscow": (180, None),
    "Africa/Cairo": (120, None),
    "Africa/Johannesburg": (120, None),
    "Africa/Lagos": (60, None),
    "Africa/Nairobi": (180, None),
    "Asia/Dubai": (240, None),
    "Asia/Riyadh": (180, None),
    "Asia/Jerusalem": (120, None),
    "Asia/Karachi": (300, None),
    "Asia/Kolkata": (330, None),
    "Asia/Calcutta": (330, None),
    "Asia/Kathmandu": (345, None),
    "Asia/Dhaka": (360, None),
    "Asia/Bangkok": (420, None),
    "Asia/Ho_Chi_Minh": (420, None),
    "Asia/Jakarta": (420, None),
    "Asia/Singapore": (480, None),
    "Asia/Kuala_Lumpur": (480, None),
    "Asia/Manila": (480, None),
    "Asia/Hong_Kong": (480, None),
    "Asia/Shanghai": (480, None),
    "Asia/Taipei": (480, None),
    "Asia/Seoul": (540, None),
    "Asia/Tokyo": (540, None),
    "Australia/Perth": (480, None),
    "Australia/Adelaide": (570, "AU"),
    "Australia/Brisbane": (600, None),
    "Australia/Sydney": (600, "AU"),
    "Australia/Melbourne": (600, "AU"),
    "Pacific/Auckland": (720, "NZ"),
}
_BUILTIN_IANA_CI = {k.lower(): k for k in _BUILTIN_IANA_ZONES}


def resolve_timezone(tz_name: str, *, allow_fallback_utc: bool = False) -> tzinfo:
    """Resolve an IANA name or fixed offset into a tzinfo without requiring external tzdata."""
    raw = (tz_name or "").strip()
    if not raw:
        if allow_fallback_utc:
            return timezone.utc
        raise ValueError("Timezone cannot be empty")

    upper = raw.upper()
    if upper in {"UTC", "ETC/UTC", "GMT", "ETC/GMT", "Z"}:
        return timezone.utc

    offset_match = FIXED_OFFSET_PATTERN.match(raw)
    if offset_match:
        sign = 1 if offset_match.group(1) == "+" else -1
        hours = int(offset_match.group(2))
        minutes = int(offset_match.group(3) or "0")
        total_minutes = sign * (hours * 60 + minutes)
        if abs(total_minutes) > 14 * 60 or minutes >= 60:
            if allow_fallback_utc:
                return timezone.utc
            raise ValueError(f"UTC offset out of range: '{tz_name}'")
        return timezone(timedelta(minutes=total_minutes))

    try:
        return zoneinfo.ZoneInfo(raw)
    except (zoneinfo.ZoneInfoNotFoundError, KeyError, ValueError):
        pass

    canonical = _BUILTIN_IANA_CI.get(raw.lower())
    if canonical is not None:
        std_minutes, dst_rule = _BUILTIN_IANA_ZONES[canonical]
        return _RuleBasedTzInfo(canonical, std_minutes, dst_rule)

    if allow_fallback_utc:
        logger.warning("Unknown timezone '%s' in stored row; falling back to UTC", tz_name)
        return timezone.utc
    raise ValueError(f"Unsupported or unknown timezone '{tz_name}'")


def validate_timezone_name(tz_name: str) -> str:
    """Validate and canonicalize an IANA/fixed-offset timezone string."""
    raw = (tz_name or "").strip()
    resolve_timezone(raw, allow_fallback_utc=False)
    if raw.upper() in {"UTC", "ETC/UTC", "GMT", "ETC/GMT", "Z"}:
        return "UTC"
    canonical = _BUILTIN_IANA_CI.get(raw.lower())
    return canonical or raw


def is_within_quiet_hours(profile: Profile, now_utc: datetime) -> bool:
    """Evaluate Quiet Hours as a half-open [start, end) local-time interval."""
    if not getattr(profile, "quiet_hours_enabled", False):
        return False

    tz = resolve_timezone(
        getattr(profile, "quiet_hours_timezone", "UTC") or "UTC",
        allow_fallback_utc=True,
    )
    utc_dt = as_utc(now_utc) or datetime.now(timezone.utc)
    local_dt = utc_dt.astimezone(tz)

    start_h, start_m = parse_hhmm(getattr(profile, "quiet_hours_start", "22:00"))
    end_h, end_m = parse_hhmm(getattr(profile, "quiet_hours_end", "07:00"))
    start_min = start_h * 60 + start_m
    end_min = end_h * 60 + end_m

    if start_min == end_min:
        return False

    cur_min = local_dt.hour * 60 + local_dt.minute
    if start_min < end_min:
        return start_min <= cur_min < end_min
    return cur_min >= start_min or cur_min < end_min


def compute_next_occurrence(
    time_of_day: str,
    recurrence_days: Optional[List[int]],
    tz_name: str,
    after_utc: datetime,
) -> datetime:
    """Compute the earliest UTC timestamp strictly > after_utc matching time_of_day and weekdays."""
    hour, minute = parse_hhmm(time_of_day)
    days = parse_recurrence_days(recurrence_days)
    tz = resolve_timezone(tz_name or "UTC", allow_fallback_utc=True)
    ref_utc = as_utc(after_utc) or datetime.now(timezone.utc)
    ref_local = ref_utc.astimezone(tz)

    for offset in range(0, 9):
        local_date = (ref_local + timedelta(days=offset)).date()
        if days and local_date.weekday() not in days:
            continue
        candidate_local = datetime(
            local_date.year,
            local_date.month,
            local_date.day,
            hour,
            minute,
            0,
            tzinfo=tz,
        )
        candidate_utc = candidate_local.astimezone(timezone.utc)
        if candidate_utc > ref_utc:
            return candidate_utc

    # Fallback (unreachable for valid weekday list 0..6, guards static analyzers)
    return ref_utc + timedelta(days=1)


class SchedulerService:
    """Deterministic runtime scheduler, Quiet Hours policy engine & memory expiration sweeper."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def sweep_expired_memories(
        self,
        now: Optional[datetime] = None,
        *,
        commit: bool = True,
    ) -> int:
        """Soft-delete expired active short-term memories (DEBT-V1-08)."""
        now_utc = as_utc(now) or datetime.now(timezone.utc)
        stmt = select(Memory).where(
            Memory.is_deleted.is_(False),
            Memory.deleted_at.is_(None),
            Memory.expires_at.is_not(None),
        )
        candidates = (await self.db.execute(stmt)).scalars().all()
        swept = 0
        for mem in candidates:
            exp = as_utc(mem.expires_at)
            if exp is not None and exp <= now_utc:
                mem.is_deleted = True
                mem.deleted_at = now_utc
                mem.updated_at = now_utc
                swept += 1
        if commit:
            await self.db.commit()
        return swept

    async def _load_active_profiles_map(self) -> Dict[str, Profile]:
        stmt = select(Profile).where(
            Profile.is_deleted.is_(False),
            Profile.deleted_at.is_(None),
            Profile.status == "active",
        )
        rows = (await self.db.execute(stmt)).scalars().all()
        return {row.id: row for row in rows}

    async def _notification_exists(
        self,
        profile_id: str,
        source_type: str,
        source_id: str,
        triggered_at: datetime,
    ) -> bool:
        norm_triggered = as_utc(triggered_at) or triggered_at
        stmt = select(NotificationEvent.triggered_at).where(
            NotificationEvent.profile_id == profile_id,
            NotificationEvent.source_type == source_type,
            NotificationEvent.source_id == source_id,
            NotificationEvent.is_deleted.is_(False),
        )
        existing_times = (await self.db.execute(stmt)).scalars().all()
        return any(as_utc(ts) == norm_triggered for ts in existing_times)

    async def _emit_notification_once(
        self,
        *,
        profile_id: str,
        source_type: str,
        source_id: str,
        urgency: str,
        title: str,
        body: Optional[str],
        status: str,
        delivery_policy: str,
        is_missed_catchup: bool,
        triggered_at: datetime,
    ) -> Optional[NotificationEvent]:
        norm_triggered = as_utc(triggered_at) or datetime.now(timezone.utc)
        if await self._notification_exists(profile_id, source_type, source_id, norm_triggered):
            return None
        event = NotificationEvent(
            profile_id=profile_id,
            source_type=source_type,
            source_id=source_id,
            urgency=urgency,
            title=title,
            body=body,
            status=status,
            delivery_policy=delivery_policy,
            is_missed_catchup=is_missed_catchup,
            triggered_at=norm_triggered,
            is_deleted=False,
            deleted_at=None,
        )
        self.db.add(event)
        return event

    async def _process_due_window(
        self,
        *,
        now_utc: datetime,
        cutoff_utc: Optional[datetime],
        missed_only: bool,
        defer_non_bypass_routines: bool = False,
    ) -> List[NotificationEvent]:
        """Shared evaluation helper for live due triggers and missed-event catch-up."""
        profiles = await self._load_active_profiles_map()
        if not profiles:
            return []

        active_profile_ids = list(profiles.keys())
        emitted: List[NotificationEvent] = []

        # 1. Reminders
        rem_stmt = select(Reminder).where(
            Reminder.profile_id.in_(active_profile_ids),
            Reminder.is_deleted.is_(False),
            Reminder.status.in_(("scheduled", "snoozed")),
        )
        for reminder in (await self.db.execute(rem_stmt)).scalars().all():
            target = as_utc(reminder.snoozed_until) if reminder.status == "snoozed" and reminder.snoozed_until else as_utc(reminder.scheduled_at)
            if target is None or target > now_utc:
                continue
            is_missed = cutoff_utc is not None and target < cutoff_utc
            if missed_only and not is_missed:
                continue
            profile = profiles[reminder.profile_id]
            quiet = is_within_quiet_hours(profile, now_utc) and not reminder.bypass_quiet_hours

            reminder.snoozed_until = None
            reminder.fired_at = now_utc
            reminder.updated_at = now_utc
            if is_missed:
                reminder.status = "missed"
                ev_status = "missed_catchup"
                policy = "missed_catchup"
            else:
                reminder.status = "fired"
                ev_status = "suppressed_quiet_hours" if quiet else "unread"
                policy = "quiet_hours_suppressed" if quiet else "immediate"

            ev = await self._emit_notification_once(
                profile_id=reminder.profile_id,
                source_type="reminder",
                source_id=reminder.id,
                urgency="high" if getattr(reminder, "center_popup", True) else "standard",
                title=reminder.title,
                body=reminder.notes,
                status=ev_status,
                delivery_policy=policy,
                is_missed_catchup=is_missed,
                triggered_at=now_utc,
            )
            if ev is not None:
                emitted.append(ev)

        # 2. Alarms
        alarm_stmt = select(Alarm).where(
            Alarm.profile_id.in_(active_profile_ids),
            Alarm.is_deleted.is_(False),
            Alarm.enabled.is_(True),
            Alarm.status.in_(("armed", "snoozed")),
        )
        for alarm in (await self.db.execute(alarm_stmt)).scalars().all():
            target = as_utc(alarm.snoozed_until) if alarm.status == "snoozed" and alarm.snoozed_until else as_utc(alarm.scheduled_at)
            if target is None or target > now_utc:
                continue
            is_missed = cutoff_utc is not None and target < cutoff_utc
            if missed_only and not is_missed:
                continue
            profile = profiles[alarm.profile_id]
            quiet = is_within_quiet_hours(profile, now_utc) and not alarm.bypass_quiet_hours

            alarm.snoozed_until = None
            alarm.last_fired_at = now_utc
            alarm.updated_at = now_utc
            days = alarm.recurrence_days_list
            if is_missed:
                if days and alarm.time_of_day:
                    alarm.scheduled_at = compute_next_occurrence(
                        alarm.time_of_day,
                        days,
                        alarm.timezone,
                        now_utc,
                    )
                    alarm.status = "armed"
                else:
                    alarm.status = "missed"
                    alarm.enabled = False
                ev_status = "missed_catchup"
                policy = "missed_catchup"
            else:
                alarm.status = "ringing"
                ev_status = "suppressed_quiet_hours" if quiet else "unread"
                policy = "quiet_hours_suppressed" if quiet else "immediate"

            ev = await self._emit_notification_once(
                profile_id=alarm.profile_id,
                source_type="alarm",
                source_id=alarm.id,
                urgency="high",
                title=alarm.label,
                body=None,
                status=ev_status,
                delivery_policy=policy,
                is_missed_catchup=is_missed,
                triggered_at=now_utc,
            )
            if ev is not None:
                emitted.append(ev)

        # 3. Routines (deterministic fallback_message, zero LLM latency per D-SHARED-SCHED-03)
        routine_stmt = select(Routine).where(
            Routine.profile_id.in_(active_profile_ids),
            Routine.is_deleted.is_(False),
            Routine.enabled.is_(True),
            Routine.next_run_at.is_not(None),
        )
        for routine in (await self.db.execute(routine_stmt)).scalars().all():
            target = as_utc(routine.next_run_at)
            if target is None or target > now_utc:
                continue
            if defer_non_bypass_routines and not routine.bypass_quiet_hours:
                continue
            is_missed = cutoff_utc is not None and target < cutoff_utc
            if missed_only and not is_missed:
                continue
            profile = profiles[routine.profile_id]
            quiet = is_within_quiet_hours(profile, now_utc) and not routine.bypass_quiet_hours

            days = routine.recurrence_days_list
            routine.last_run_at = now_utc
            routine.next_run_at = compute_next_occurrence(
                routine.time_of_day,
                days,
                routine.timezone,
                now_utc,
            )
            routine.updated_at = now_utc
            if is_missed:
                routine.last_status = "missed_catchup"
                ev_status = "missed_catchup"
                policy = "missed_catchup"
            elif quiet:
                routine.last_status = "suppressed_quiet_hours"
                ev_status = "suppressed_quiet_hours"
                policy = "quiet_hours_suppressed"
            else:
                routine.last_status = "completed"
                ev_status = "unread"
                policy = "immediate"

            ev = await self._emit_notification_once(
                profile_id=routine.profile_id,
                source_type="routine",
                source_id=routine.id,
                urgency="informational",
                title=routine.title,
                body=routine.fallback_message,
                status=ev_status,
                delivery_policy=policy,
                is_missed_catchup=is_missed,
                triggered_at=now_utc,
            )
            if ev is not None:
                emitted.append(ev)

        # 4. Task due-reminder bridge (deduplicated per normalized task.reminder_at)
        task_stmt = select(Task).where(
            Task.profile_id.in_(active_profile_ids),
            Task.is_deleted.is_(False),
            Task.status.in_(("pending", "in_progress")),
            Task.reminder_at.is_not(None),
        )
        for task in (await self.db.execute(task_stmt)).scalars().all():
            target = as_utc(task.reminder_at)
            if target is None or target > now_utc:
                continue
            is_missed = cutoff_utc is not None and target < cutoff_utc
            if missed_only and not is_missed:
                continue
            profile = profiles[task.profile_id]
            quiet = is_within_quiet_hours(profile, now_utc)

            if is_missed:
                ev_status = "missed_catchup"
                policy = "missed_catchup"
            elif quiet:
                ev_status = "suppressed_quiet_hours"
                policy = "quiet_hours_suppressed"
            else:
                ev_status = "unread"
                policy = "immediate"

            ev = await self._emit_notification_once(
                profile_id=task.profile_id,
                source_type="task_reminder",
                source_id=task.id,
                urgency="high" if getattr(task, "reminder_center_popup", True) else "standard",
                title=f"Task Reminder: {task.title}",
                body=task.notes,
                status=ev_status,
                delivery_policy=policy,
                is_missed_catchup=is_missed,
                triggered_at=target,
            )
            if ev is not None:
                emitted.append(ev)

        return emitted

    async def reconcile_missed_events(
        self,
        now: Optional[datetime] = None,
        grace_seconds: Optional[int] = None,
        *,
        commit: bool = True,
    ) -> List[NotificationEvent]:
        """Catch up overdue reminders, alarms, routines, and task alerts outside grace_window."""
        now_utc = as_utc(now) or datetime.now(timezone.utc)
        grace = settings.SCHEDULER_MISSED_GRACE_SECONDS if grace_seconds is None else grace_seconds
        cutoff_utc = now_utc - timedelta(seconds=max(0, grace))

        emitted = await self._process_due_window(
            now_utc=now_utc,
            cutoff_utc=cutoff_utc,
            missed_only=True,
        )
        if commit:
            await self.db.commit()
        return emitted

    async def run_tick(
        self,
        now: Optional[datetime] = None,
        grace_seconds: Optional[int] = None,
        *,
        sweep_memories: bool = True,
        defer_non_bypass_routines: bool = False,
        commit: bool = True,
    ) -> List[NotificationEvent]:
        """Run one deterministic scheduler pass (missed catch-up + live due + optional memory sweep)."""
        now_utc = as_utc(now) or datetime.now(timezone.utc)
        grace = settings.SCHEDULER_MISSED_GRACE_SECONDS if grace_seconds is None else grace_seconds
        cutoff_utc = now_utc - timedelta(seconds=max(0, grace))

        emitted = await self._process_due_window(
            now_utc=now_utc,
            cutoff_utc=cutoff_utc,
            missed_only=False,
            defer_non_bypass_routines=defer_non_bypass_routines,
        )
        if sweep_memories:
            await self.sweep_expired_memories(now=now_utc, commit=False)
        if commit:
            await self.db.commit()
        return emitted

    async def trigger_routine_now(
        self,
        routine: Routine,
        now: Optional[datetime] = None,
        *,
        commit: bool = True,
    ) -> NotificationEvent:
        """Manually execute a routine immediately using its deterministic fallback_message."""
        now_utc = as_utc(now) or datetime.now(timezone.utc)
        routine.last_run_at = now_utc
        routine.last_status = "completed"
        routine.updated_at = now_utc

        event = NotificationEvent(
            profile_id=routine.profile_id,
            source_type="routine",
            source_id=routine.id,
            urgency="informational",
            title=routine.title,
            body=routine.fallback_message,
            status="unread",
            delivery_policy="immediate",
            is_missed_catchup=False,
            triggered_at=now_utc,
            is_deleted=False,
            deleted_at=None,
        )
        self.db.add(event)
        if commit:
            await self.db.commit()
            await self.db.refresh(event)
        return event


async def run_periodic_scheduler(
    session_factory,
    interval_seconds: float = 15.0,
    memory_sweep_interval_seconds: float = 300.0,
    *,
    loop_once_for_test: bool = False,
) -> int:
    """Periodic background worker ticking SchedulerService inside FastAPI lifespan."""
    if loop_once_for_test:
        async with session_factory() as session:
            svc = SchedulerService(session)
            emitted = await svc.run_tick(sweep_memories=True)
            return len(emitted)

    elapsed_since_memory_sweep = 0.0
    while True:
        try:
            await asyncio.sleep(interval_seconds)
            from app.services.resource_governor import resource_governor

            defer_bg = resource_governor.should_defer_background_work
            elapsed_since_memory_sweep += interval_seconds
            should_sweep_memories = (
                not defer_bg and elapsed_since_memory_sweep >= memory_sweep_interval_seconds
            )
            if should_sweep_memories:
                elapsed_since_memory_sweep = 0.0
            async with session_factory() as session:
                svc = SchedulerService(session)
                await svc.run_tick(
                    sweep_memories=should_sweep_memories,
                    defer_non_bypass_routines=defer_bg,
                )
        except asyncio.CancelledError:
            break
        except Exception as exc:
            logger.error("Error in periodic scheduler tick: %s", exc, exc_info=True)
    return 0
