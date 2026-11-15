"""API integration tests for Reminders, Alarms, Routines, Notification Backlog & Quiet Hours."""

from datetime import datetime, timedelta, timezone
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.profile_sessions import new_profile_session
from app.models.profile import Profile
from app.services.scheduler.service import SchedulerService


async def _make_secondary_profile_headers(db: AsyncSession, name: str = "Secondary") -> dict:
    p2 = Profile(id=str(uuid.uuid4()), name=name, status="active", is_default=False)
    db.add(p2)
    await db.commit()
    token, session = new_profile_session(p2.id, "desktop")
    db.add(session)
    await db.commit()
    return {"Authorization": f"Bearer {token}"}, p2


async def test_scheduling_endpoints_fail_closed_without_auth(client: AsyncClient):
    for method, path in (
        ("GET", "/api/v1/reminders"),
        ("GET", "/api/v1/alarms"),
        ("GET", "/api/v1/routines"),
        ("GET", "/api/v1/notifications"),
        ("GET", "/api/v1/profiles/me/quiet-hours"),
    ):
        resp = await client.request(method, path)
        assert resp.status_code == 401


async def test_quiet_hours_endpoints_validation_and_persistence(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/profiles/me/quiet-hours", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json() == {
        "quiet_hours_enabled": False,
        "quiet_hours_start": "22:00",
        "quiet_hours_end": "07:00",
        "quiet_hours_timezone": "UTC",
    }

    bad_tz = await client.patch(
        "/api/v1/profiles/me/quiet-hours",
        headers=auth_headers,
        json={"quiet_hours_timezone": "Invalid/Zone"},
    )
    assert bad_tz.status_code == 422

    same_bounds = await client.patch(
        "/api/v1/profiles/me/quiet-hours",
        headers=auth_headers,
        json={"quiet_hours_enabled": True, "quiet_hours_start": "22:00", "quiet_hours_end": "22:00"},
    )
    assert same_bounds.status_code == 422

    ok = await client.patch(
        "/api/v1/profiles/me/quiet-hours",
        headers=auth_headers,
        json={
            "quiet_hours_enabled": True,
            "quiet_hours_start": "23:00",
            "quiet_hours_end": "06:30",
            "quiet_hours_timezone": "Asia/Manila",
        },
    )
    assert ok.status_code == 200
    assert ok.json() == {
        "quiet_hours_enabled": True,
        "quiet_hours_start": "23:00",
        "quiet_hours_end": "06:30",
        "quiet_hours_timezone": "Asia/Manila",
    }


async def test_reminders_uuidv4_task_sync_and_cross_profile_isolation(
    client: AsyncClient,
    test_session: AsyncSession,
    auth_headers: dict,
):
    other_headers, _ = await _make_secondary_profile_headers(test_session, "ProfileTwo")

    # Create task in profile 1
    task_resp = await client.post(
        "/api/v1/tasks",
        headers=auth_headers,
        json={"title": "Buy groceries"},
    )
    assert task_resp.status_code == 201
    task_id = task_resp.json()["id"]

    client_uuid = str(uuid.uuid4())
    sched_time = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()

    # Cross-profile task linking is rejected with 404
    cross_link = await client.post(
        "/api/v1/reminders",
        headers=other_headers,
        json={"title": "Steal", "task_id": task_id, "scheduled_at": sched_time},
    )
    assert cross_link.status_code == 404

    # Create reminder with explicit UUIDv4 & origin mobile
    rem_resp = await client.post(
        "/api/v1/reminders",
        headers=auth_headers,
        json={
            "id": client_uuid,
            "task_id": task_id,
            "title": "Grocery trip",
            "scheduled_at": sched_time,
            "timezone": "Asia/Manila",
            "origin": "mobile",
        },
    )
    assert rem_resp.status_code == 201
    assert rem_resp.json()["id"] == client_uuid
    assert rem_resp.json()["origin"] == "mobile"

    # Duplicate UUIDv4 returns 409 Conflict
    dup_resp = await client.post(
        "/api/v1/reminders",
        headers=auth_headers,
        json={"id": client_uuid, "title": "Dup", "scheduled_at": sched_time},
    )
    assert dup_resp.status_code == 409

    # Profile 2 cannot read or snooze Profile 1's reminder
    assert (await client.get(f"/api/v1/reminders/{client_uuid}", headers=other_headers)).status_code == 404
    assert (await client.post(f"/api/v1/reminders/{client_uuid}/dismiss", headers=other_headers)).status_code == 404

    # Snooze reminder (past timestamp rejected with 422; valid minutes succeeds)
    past = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    assert (
        await client.post(f"/api/v1/reminders/{client_uuid}/snooze", headers=auth_headers, json={"until": past})
    ).status_code == 422

    snoozed = await client.post(
        f"/api/v1/reminders/{client_uuid}/snooze",
        headers=auth_headers,
        json={"minutes": 15},
    )
    assert snoozed.status_code == 200
    assert snoozed.json()["status"] == "snoozed"
    assert snoozed.json()["snoozed_until"] is not None

    # Acknowledge reminder with complete_task=True completes the linked task
    ack = await client.post(
        f"/api/v1/reminders/{client_uuid}/acknowledge",
        headers=auth_headers,
        json={"complete_task": True},
    )
    assert ack.status_code == 200
    assert ack.json()["status"] == "acknowledged"
    fetched_task = await client.get(f"/api/v1/tasks/{task_id}", headers=auth_headers)
    assert fetched_task.json()["status"] == "completed"

    # Completing another task automatically cancels its pending linked reminder
    t2_id = (await client.post("/api/v1/tasks", headers=auth_headers, json={"title": "Pay bill"})).json()["id"]
    r2_id = (
        await client.post(
            "/api/v1/reminders",
            headers=auth_headers,
            json={"task_id": t2_id, "title": "Bill alert", "scheduled_at": sched_time},
        )
    ).json()["id"]
    await client.patch(f"/api/v1/tasks/{t2_id}", headers=auth_headers, json={"status": "completed"})
    r2_after = await client.get(f"/api/v1/reminders/{r2_id}", headers=auth_headers)
    assert r2_after.json()["status"] == "cancelled"


async def test_alarms_recurring_rearm_vs_oneshot_disable(client: AsyncClient, auth_headers: dict):
    # Recurring alarm computes initial scheduled_at automatically when omitted
    rec_resp = await client.post(
        "/api/v1/alarms",
        headers=auth_headers,
        json={
            "label": "Daily standup",
            "time_of_day": "09:30",
            "recurrence_days": [0, 1, 2, 3, 4],
            "timezone": "UTC",
        },
    )
    assert rec_resp.status_code == 201
    rec = rec_resp.json()
    assert rec["status"] == "armed"
    assert rec["bypass_quiet_hours"] is True
    assert rec["recurrence_days"] == [0, 1, 2, 3, 4]

    # Acknowledge recurring alarm -> stays enabled & re-arms for next occurrence
    ack_rec = await client.post(f"/api/v1/alarms/{rec['id']}/acknowledge", headers=auth_headers)
    assert ack_rec.status_code == 200
    assert ack_rec.json()["enabled"] is True
    assert ack_rec.json()["status"] == "armed"

    # One-shot alarm transitions to disabled acknowledged/dismissed
    oneshot_at = (datetime.now(timezone.utc) + timedelta(hours=2)).isoformat()
    one_resp = await client.post(
        "/api/v1/alarms",
        headers=auth_headers,
        json={"label": "Laundry done", "scheduled_at": oneshot_at},
    )
    assert one_resp.status_code == 201
    one_id = one_resp.json()["id"]
    dismiss_one = await client.post(f"/api/v1/alarms/{one_id}/dismiss", headers=auth_headers)
    assert dismiss_one.status_code == 200
    assert dismiss_one.json()["status"] == "dismissed"
    assert dismiss_one.json()["enabled"] is False


async def test_routines_and_notification_backlog_lifecycle(
    client: AsyncClient,
    test_session: AsyncSession,
    auth_headers: dict,
):
    # Create routine and run manually with deterministic fallback_message
    routine_resp = await client.post(
        "/api/v1/routines",
        headers=auth_headers,
        json={
            "title": "Evening Check-in",
            "fallback_message": "Ready to wrap up for today?",
            "time_of_day": "20:00",
            "recurrence_days": [0, 1, 2, 3, 4, 5, 6],
            "timezone": "Asia/Manila",
        },
    )
    assert routine_resp.status_code == 201
    routine_id = routine_resp.json()["id"]

    run_resp = await client.post(f"/api/v1/routines/{routine_id}/run", headers=auth_headers)
    assert run_resp.status_code == 200
    ev_routine = run_resp.json()
    assert ev_routine["source_type"] == "routine"
    assert ev_routine["body"] == "Ready to wrap up for today?"
    assert ev_routine["status"] == "unread"

    # Also create a task with a past due reminder_at and trigger SchedulerService once
    past_due = (datetime.now(timezone.utc) - timedelta(seconds=30)).isoformat()
    task_resp = await client.post(
        "/api/v1/tasks",
        headers=auth_headers,
        json={"title": "Review PR", "reminder_at": past_due},
    )
    assert task_resp.status_code == 201
    task_id = task_resp.json()["id"]

    await SchedulerService(test_session).run_tick(now=datetime.now(timezone.utc), grace_seconds=300)

    backlog = await client.get("/api/v1/notifications", headers=auth_headers)
    assert backlog.status_code == 200
    data = backlog.json()
    assert data["total"] == 2
    assert data["unread_count"] == 2
    task_ev = next(i for i in data["items"] if i["source_type"] == "task_reminder")

    # Mark routine notification read -> unread_count drops to 1
    read_resp = await client.post(f"/api/v1/notifications/{ev_routine['id']}/read", headers=auth_headers)
    assert read_resp.status_code == 200
    assert read_resp.json()["status"] == "read"
    backlog2 = (await client.get("/api/v1/notifications", headers=auth_headers)).json()
    assert backlog2["unread_count"] == 1

    # Acknowledge task_reminder notification -> completes associated Task
    ack_task_ev = await client.post(
        f"/api/v1/notifications/{task_ev['id']}/acknowledge",
        headers=auth_headers,
        json={"complete_task": True},
    )
    assert ack_task_ev.status_code == 200
    assert ack_task_ev.json()["status"] == "acknowledged"
    task_after = (await client.get(f"/api/v1/tasks/{task_id}", headers=auth_headers)).json()
    assert task_after["status"] == "completed"

    # Clear all active notifications
    cleared = await client.post("/api/v1/notifications/clear-all", headers=auth_headers)
    assert cleared.status_code == 200
    assert cleared.json()["cleared_count"] == 1
    assert (await client.get("/api/v1/notifications?unread_only=true", headers=auth_headers)).json()["total"] == 0


async def test_alarm_update_recomputes_schedule_and_guards_recurrence(
    client: AsyncClient,
    auth_headers: dict,
):
    # 1. Create an enabled recurring alarm -> PATCH time_of_day without scheduled_at recomputes scheduled_at
    rec_resp = await client.post(
        "/api/v1/alarms",
        headers=auth_headers,
        json={
            "label": "Morning Workout",
            "time_of_day": "09:30",
            "recurrence_days": [0, 1, 2, 3, 4, 5, 6],
            "timezone": "UTC",
        },
    )
    assert rec_resp.status_code == 201
    rec = rec_resp.json()
    orig_dt = datetime.fromisoformat(rec["scheduled_at"].replace("Z", "+00:00"))
    assert orig_dt.hour == 9 and orig_dt.minute == 30

    patch_resp = await client.patch(
        f"/api/v1/alarms/{rec['id']}",
        headers=auth_headers,
        json={"time_of_day": "11:45"},
    )
    assert patch_resp.status_code == 200
    patched = patch_resp.json()
    patched_dt = datetime.fromisoformat(patched["scheduled_at"].replace("Z", "+00:00"))
    assert patched["time_of_day"] == "11:45"
    assert patched_dt.hour == 11 and patched_dt.minute == 45

    # 2. Disabling -> re-enabling a future non-recurring alarm preserves its future scheduled_at
    future_at = (datetime.now(timezone.utc) + timedelta(hours=6)).replace(microsecond=0)
    one_resp = await client.post(
        "/api/v1/alarms",
        headers=auth_headers,
        json={
            "label": "Airport Pickup",
            "scheduled_at": future_at.isoformat(),
            "time_of_day": "10:00",
            "timezone": "UTC",
        },
    )
    assert one_resp.status_code == 201
    one_id = one_resp.json()["id"]
    orig_one_at = one_resp.json()["scheduled_at"]

    assert (await client.patch(f"/api/v1/alarms/{one_id}", headers=auth_headers, json={"enabled": False})).status_code == 200
    re_enabled = await client.patch(f"/api/v1/alarms/{one_id}", headers=auth_headers, json={"enabled": True})
    assert re_enabled.status_code == 200
    assert re_enabled.json()["scheduled_at"] == orig_one_at

    # 3. Clearing time_of_day while recurrence_days remains non-empty must fail with 422
    invalid_clear = await client.patch(
        f"/api/v1/alarms/{rec['id']}",
        headers=auth_headers,
        json={"clear_time_of_day": True},
    )
    assert invalid_clear.status_code == 422
    assert patched["scheduled_at"].endswith("Z") or patched["scheduled_at"].endswith("+00:00")
    assert patched["created_at"].endswith("Z") or patched["created_at"].endswith("+00:00")


async def test_reminder_center_popup_and_mark_all_notifications_read(
    client: AsyncClient,
    auth_headers: dict,
    test_session: AsyncSession,
):
    """Per-reminder center_popup defaults True, supports PATCH false, and mark-all-read zeroes unread while preserving alarms & history."""
    future = (datetime.now(timezone.utc) + timedelta(hours=2)).replace(microsecond=0).isoformat()
    create_default = await client.post(
        "/api/v1/reminders",
        headers=auth_headers,
        json={"title": "Center By Default", "scheduled_at": future, "timezone": "UTC"},
    )
    assert create_default.status_code == 201
    assert create_default.json()["center_popup"] is True

    patched = await client.patch(
        f"/api/v1/reminders/{create_default.json()['id']}",
        headers=auth_headers,
        json={"center_popup": False},
    )
    assert patched.status_code == 200
    assert patched.json()["center_popup"] is False

    # Seed an active unread reminder, a missed catch-up reminder, and an active ringing alarm
    from app.models.notification_event import NotificationEvent
    from app.models.profile import Profile

    profile_id = (await test_session.execute(select(Profile.id).where(Profile.is_default.is_(True)))).scalar_one()
    now = datetime.now(timezone.utc)
    rem_ev = NotificationEvent(
        profile_id=profile_id,
        source_type="reminder",
        source_id=create_default.json()["id"],
        urgency="standard",
        title="Unread Reminder",
        status="unread",
        delivery_policy="immediate",
        triggered_at=now - timedelta(seconds=10),
    )
    catchup_ev = NotificationEvent(
        profile_id=profile_id,
        source_type="routine",
        source_id=str(uuid.uuid4()),
        urgency="standard",
        title="Catchup Routine",
        status="missed_catchup",
        delivery_policy="missed_catchup",
        is_missed_catchup=True,
        triggered_at=now - timedelta(minutes=20),
    )
    alarm_ev = NotificationEvent(
        profile_id=profile_id,
        source_type="alarm",
        source_id=str(uuid.uuid4()),
        urgency="high",
        title="Ringing Alarm",
        status="unread",
        delivery_policy="immediate",
        triggered_at=now - timedelta(seconds=5),
    )
    test_session.add_all([rem_ev, catchup_ev, alarm_ev])
    await test_session.commit()

    before = (await client.get("/api/v1/notifications", headers=auth_headers)).json()
    assert before["unread_count"] == 3
    assert before["missed_count"] == 1

    marked = await client.post("/api/v1/notifications/mark-all-read", headers=auth_headers)
    assert marked.status_code == 200
    assert marked.json()["updated_count"] == 3

    after = (await client.get("/api/v1/notifications", headers=auth_headers)).json()
    assert after["unread_count"] == 0
    assert after["missed_count"] == 0
    assert after["total"] == 3
    statuses = {item["title"]: item["status"] for item in after["items"]}
    assert statuses["Unread Reminder"] == "read"
    assert statuses["Catchup Routine"] == "read"
    # Active ringing alarm remains unread until explicitly Stopped/Snoozed/Dismissed
    assert statuses["Ringing Alarm"] == "unread"
