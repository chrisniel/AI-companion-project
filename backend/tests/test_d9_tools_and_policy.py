"""Security, policy, confirmation, audit, and API tests for Decision D9 tools (M4 Batch A)."""

import asyncio
from datetime import datetime, timedelta, timezone
import json
import uuid

from httpx import AsyncClient
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.profile_sessions import new_profile_session
from app.models.conversation import Conversation
from app.models.profile import Profile
from app.models.task import Task
from app.models.tool_audit_log import ToolAuditLog
from app.models.tool_confirmation import ToolConfirmation
from app.services.profile_purge_service import ProfilePurgeService
from app.services.tools.executor import (
    ToolExecutionOutcome,
    execute_tool_intent,
    resolve_confirmation_atomic,
)
from app.services.tools.policy import compute_confirmation_fingerprint


async def _create_secondary_profile(db: AsyncSession, name: str = "Secondary"):
    p2 = Profile(id=str(uuid.uuid4()), name=name, status="active", is_default=False)
    db.add(p2)
    await db.commit()
    token, session = new_profile_session(p2.id, "desktop")
    db.add(session)
    await db.commit()
    return p2, session, {"Authorization": f"Bearer {token}"}


async def _make_conversation(db: AsyncSession, profile_id: str) -> Conversation:
    conv = Conversation(id=str(uuid.uuid4()), profile_id=profile_id, title="Tools Test")
    db.add(conv)
    await db.commit()
    return conv


async def test_tools_endpoints_fail_closed_without_auth(client: AsyncClient):
    for method, path in (
        ("GET", "/api/v1/tools/catalog"),
        ("GET", "/api/v1/tools/policy"),
        ("PATCH", "/api/v1/tools/policy"),
        ("GET", "/api/v1/tools/kill-switch"),
        ("POST", "/api/v1/tools/kill-switch"),
        ("GET", "/api/v1/tools/audit"),
        ("GET", "/api/v1/tools/confirmations"),
    ):
        resp = await client.request(method, path)
        assert resp.status_code == 401, (method, path, resp.status_code)

    web_cfg = await client.put("/api/v1/tools/web-config", json={"weather_provider": "disabled"})
    assert web_cfg.status_code == 401


@pytest.mark.asyncio
async def test_d9_default_deny_risk3_prohibition_and_external_content_guard(
    test_session: AsyncSession, profile_id: str, profile_session
):
    conv = await _make_conversation(test_session, profile_id)

    # Risk 3 / unknown / extra args are unconditionally DENIED
    for bad_name in ("run_shell", "powershell", "cmd_exec", "nonexistent_tool"):
        outcome = await execute_tool_intent(
            db=test_session,
            profile_session=profile_session,
            conversation_id=conv.id,
            tool_name=bad_name,
            arguments={"command": "dir"},
            provenance="EXPLICIT_USER",
        )
        assert outcome.decision == "DENY"
        assert outcome.executed is False

    # Unexpected extra parameters fail Pydantic schema validation
    extra_outcome = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="list_tasks",
        arguments={"unexpected_arg": "oops"},
        provenance="EXPLICIT_USER",
    )
    assert extra_outcome.decision == "DENY"
    assert extra_outcome.error_code == "INVALID_ARGUMENTS"

    # EXTERNAL_CONTENT has zero authorization authority even for Risk 0 tools
    ext_outcome = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="list_tasks",
        arguments={},
        provenance="EXTERNAL_CONTENT",
    )
    assert ext_outcome.decision == "DENY"
    assert ext_outcome.error_code == "EXTERNAL_CONTENT_FORBIDDEN"


@pytest.mark.asyncio
async def test_d9_risk1_provenance_and_quiet_hours_deterministic_gate(
    test_session: AsyncSession, profile_id: str, profile_session
):
    conv = await _make_conversation(test_session, profile_id)

    # EXPLICIT_USER Risk 1 create_task auto-executes under default policy
    explicit_res = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="create_task",
        arguments={"title": "Buy milk"},
        provenance="EXPLICIT_USER",
    )
    assert explicit_res.decision == "ALLOW"
    assert explicit_res.executed is True

    # COMPANION_SUGGESTED Risk 1 requires explicit CONFIRM by default
    suggested_res = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="create_task",
        arguments={"title": "Suggested chore"},
        provenance="COMPANION_SUGGESTED",
    )
    assert suggested_res.decision == "CONFIRM"
    assert suggested_res.confirmation is not None

    # Enable quiet hours 00:00..23:59 (always inside window) on Profile
    profile = await test_session.get(Profile, profile_id)
    assert profile is not None
    profile.quiet_hours_enabled = True
    profile.quiet_hours_start = "00:00"
    profile.quiet_hours_end = "23:59"
    profile.quiet_hours_timezone = "UTC"
    await test_session.commit()

    soon = (datetime.now(timezone.utc) + timedelta(minutes=2)).isoformat()
    # Companion-proposed reminder bypassing quiet hours inside active quiet window forces CONFIRM
    qh_res = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="create_reminder",
        arguments={"title": "Ping during quiet", "scheduled_at": soon, "bypass_quiet_hours": True},
        provenance="EXPLICIT_USER",
    )
    assert qh_res.decision == "CONFIRM"


@pytest.mark.asyncio
async def test_kill_switch_persistence_and_host_admin_authority(
    client: AsyncClient, auth_headers: dict, host_admin_headers: dict, test_session: AsyncSession
):
    # Profile session can engage emergency Kill Switch
    on_resp = await client.post(
        "/api/v1/tools/kill-switch",
        headers=auth_headers,
        json={"enabled": True, "reason": "user_emergency"},
    )
    assert on_resp.status_code == 200
    assert on_resp.json()["global_kill_switch"] is True

    # Verify persistence across API read
    ks_get = await client.get("/api/v1/tools/kill-switch", headers=auth_headers)
    assert ks_get.status_code == 200
    assert ks_get.json()["global_kill_switch"] is True
    assert ks_get.json()["kill_switch_reason"] == "user_emergency"

    # Disabling Kill Switch without Host Admin fails closed (403)
    bad_off = await client.post(
        "/api/v1/tools/kill-switch",
        headers=auth_headers,
        json={"enabled": False},
    )
    assert bad_off.status_code == 403

    # Host Admin with browser Origin header also blocked
    origin_off = await client.post(
        "/api/v1/tools/kill-switch",
        headers={**auth_headers, **host_admin_headers, "Origin": "http://localhost:5173"},
        json={"enabled": False},
    )
    assert origin_off.status_code == 403

    # Native Host Admin cleanly disengages Kill Switch
    ok_off = await client.post(
        "/api/v1/tools/kill-switch",
        headers=host_admin_headers,
        json={"enabled": False, "reason": "cleared_by_admin"},
    )
    assert ok_off.status_code == 200
    assert ok_off.json()["global_kill_switch"] is False


@pytest.mark.asyncio
async def test_confirmation_fingerprint_bola_expiry_and_atomic_single_winner(
    client: AsyncClient,
    auth_headers: dict,
    host_admin_headers: dict,
    test_session: AsyncSession,
    profile_id: str,
    profile_session,
):
    conv = await _make_conversation(test_session, profile_id)
    task = Task(id=str(uuid.uuid4()), profile_id=profile_id, title="Old grocery list", status="pending")
    test_session.add(task)
    await test_session.commit()

    # Risk 2 delete_task issues a pending confirmation
    outcome = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="delete_task",
        arguments={"task_id": task.id},
        provenance="EXPLICIT_USER",
    )
    assert outcome.decision == "CONFIRM"
    conf = outcome.confirmation
    assert conf is not None

    # Secondary profile cannot resolve primary profile's confirmation (BOLA isolation)
    _, s2, p2_headers = await _create_secondary_profile(test_session, "Other")
    bola_resp = await client.post(
        f"/api/v1/tools/confirmations/{conf.id}/resolve",
        headers=p2_headers,
        json={"decision": "approve"},
    )
    assert bola_resp.status_code == 404

    # Different session on same profile cannot resolve confirmation bound to ProfileSession.id
    other_tok, other_sess = new_profile_session(profile_id, "desktop")
    test_session.add(other_sess)
    await test_session.commit()
    sess_mismatch = await client.post(
        f"/api/v1/tools/confirmations/{conf.id}/resolve",
        headers={"Authorization": f"Bearer {other_tok}"},
        json={"decision": "approve"},
    )
    assert sess_mismatch.status_code == 403

    # Atomic single-winner replay/double-submit guard: first claim executes; second returns already_resolved
    first_resp = await client.post(
        f"/api/v1/tools/confirmations/{conf.id}/resolve",
        headers=auth_headers,
        json={"decision": "approve"},
    )
    second_resp = await client.post(
        f"/api/v1/tools/confirmations/{conf.id}/resolve",
        headers=auth_headers,
        json={"decision": "approve"},
    )
    assert first_resp.status_code == 200 and second_resp.status_code == 200
    assert first_resp.json()["executed"] is True
    assert first_resp.json()["outcome_status"] == "confirmed_executed"
    assert second_resp.json()["executed"] is False
    assert second_resp.json()["outcome_status"] == "already_resolved"

    await test_session.refresh(task)
    assert task.is_deleted is True


@pytest.mark.asyncio
async def test_web_config_secret_isolation_and_profile_purge_cascade(
    client: AsyncClient,
    auth_headers: dict,
    host_admin_headers: dict,
    test_session: AsyncSession,
    tmp_path,
    monkeypatch,
):
    secret_file = tmp_path / "secrets" / "web_search_api.secret"
    monkeypatch.setenv("COMPANION_WEB_SEARCH_SECRET_FILE", str(secret_file))

    upd = await client.put(
        "/api/v1/tools/web-config",
        headers=host_admin_headers,
        json={
            "weather_provider": "open_meteo",
            "web_search_provider": "tavily",
            "search_api_key": "tvly-super-secret-value-1234",
        },
    )
    assert upd.status_code == 200
    assert upd.json()["search_api_key_configured"] is True
    assert "tvly-super-secret-value-1234" not in upd.text

    policy_get = await client.get("/api/v1/tools/policy", headers=auth_headers)
    assert policy_get.status_code == 200
    assert policy_get.json()["search_api_key_configured"] is True
    assert "tvly-super-secret-value-1234" not in policy_get.text

    # Audit log redaction & ProfilePurgeService cascade
    p2, s2, _ = await _create_secondary_profile(test_session, "PurgeTarget")
    conv2 = await _make_conversation(test_session, p2.id)
    await execute_tool_intent(
        db=test_session,
        profile_session=s2,
        conversation_id=conv2.id,
        tool_name="create_task",
        arguments={"title": "Private secret note xyz"},
        provenance="EXPLICIT_USER",
    )

    logs = (
        await test_session.execute(select(ToolAuditLog).where(ToolAuditLog.profile_id == p2.id))
    ).scalars().all()
    assert len(logs) == 1
    assert "Private secret note xyz" not in json.dumps(
        {
            "tool": logs[0].tool_name,
            "decision": logs[0].decision,
            "domains": logs[0].source_domains_json,
            "error": logs[0].error_code,
        }
    )

    purge_svc = ProfilePurgeService(test_session)
    await purge_svc.soft_delete_profile(p2.id)
    await purge_svc.purge_profile(p2.id, allow_unexpired=True)
    assert await test_session.get(Profile, p2.id) is None
    assert (
        await test_session.execute(
            select(ToolConfirmation).where(ToolConfirmation.profile_id == p2.id)
        )
    ).scalars().all() == []


@pytest.mark.asyncio
async def test_productivity_adapters_localize_timestamps_and_preserve_iso_keys(
    test_session: AsyncSession, profile_id: str, profile_session
):
    profile = await test_session.get(Profile, profile_id)
    assert profile is not None
    profile.quiet_hours_timezone = "Asia/Manila"
    await test_session.commit()

    conv = await _make_conversation(test_session, profile_id)

    create_rem = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="create_reminder",
        arguments={"title": "Take vitamins", "scheduled_at": "2026-12-08T01:30:00+00:00"},
        provenance="EXPLICIT_USER",
    )
    assert create_rem.executed is True
    assert "December 8, 2026 at 9:30 AM" in create_rem.summary
    assert "T01:30" not in create_rem.summary
    assert create_rem.payload["reminder"]["scheduled_at_local"] == "December 8, 2026 at 9:30 AM"
    assert create_rem.payload["reminder"]["scheduled_at"].startswith("2026-12-08T01:30:00")

    list_rem = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="list_reminders",
        arguments={},
        provenance="EXPLICIT_USER",
    )
    assert list_rem.executed is True
    assert "December 8, 2026 at 9:30 AM" in list_rem.summary
    assert list_rem.payload["items"][0]["scheduled_at_local"] == "December 8, 2026 at 9:30 AM"
    assert list_rem.payload["items"][0]["scheduled_at"].startswith("2026-12-08T01:30:00")

    create_task = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="create_task",
        arguments={"title": "Buy ring", "due_at": "2026-12-08T01:30:00+00:00"},
        provenance="EXPLICIT_USER",
    )
    assert create_task.executed is True
    assert "December 8, 2026 at 9:30 AM" in create_task.summary
    assert create_task.payload["task"]["due_at_local"] == "December 8, 2026 at 9:30 AM"

    list_tasks = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="list_tasks",
        arguments={},
        provenance="EXPLICIT_USER",
    )
    assert list_tasks.executed is True
    assert "December 8, 2026 at 9:30 AM" in list_tasks.summary
    assert list_tasks.payload["items"][0]["due_at_local"] == "December 8, 2026 at 9:30 AM"

    create_alarm = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="create_alarm",
        arguments={"label": "Standup", "time_of_day": "08:00"},
        provenance="EXPLICIT_USER",
    )
    assert create_alarm.executed is True
    assert create_alarm.payload["alarm"]["scheduled_at_local"]

    list_alarms = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="list_alarms",
        arguments={},
        provenance="EXPLICIT_USER",
    )
    assert list_alarms.executed is True
    assert list_alarms.payload["items"][0]["scheduled_at_local"]
    assert "Standup" in list_alarms.summary

    # Default list_reminders returns scheduled + snoozed items only, omitting old fired/dismissed rows
    from datetime import datetime, timezone
    from app.models.reminder import Reminder
    from app.models.task import Task

    snoozed_rem = Reminder(
        profile_id=profile_session.profile_id,
        title="Snoozed flight check-in",
        scheduled_at=datetime(2026, 12, 9, 6, 0, tzinfo=timezone.utc),
        timezone="Asia/Manila",
        status="snoozed",
    )
    fired_rem = Reminder(
        profile_id=profile_session.profile_id,
        title="Old fired reminder",
        scheduled_at=datetime(2026, 10, 1, 8, 0, tzinfo=timezone.utc),
        timezone="Asia/Manila",
        status="fired",
    )
    completed_task = Task(
        profile_id=profile_session.profile_id,
        title="Done ancient task",
        status="completed",
    )
    test_session.add_all([snoozed_rem, fired_rem, completed_task])
    await test_session.commit()

    active_rems = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="list_reminders",
        arguments={},
        provenance="EXPLICIT_USER",
    )
    assert active_rems.executed is True
    rem_titles = {it["title"] for it in active_rems.payload["items"]}
    assert "Take vitamins" in rem_titles
    assert "Snoozed flight check-in" in rem_titles
    assert "Old fired reminder" not in rem_titles

    explicit_fired = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="list_reminders",
        arguments={"status": "fired"},
        provenance="EXPLICIT_USER",
    )
    assert explicit_fired.executed is True
    assert {it["title"] for it in explicit_fired.payload["items"]} == {"Old fired reminder"}

    active_tasks = await execute_tool_intent(
        db=test_session,
        profile_session=profile_session,
        conversation_id=conv.id,
        tool_name="list_tasks",
        arguments={},
        provenance="EXPLICIT_USER",
    )
    assert active_tasks.executed is True
    task_titles = {it["title"] for it in active_tasks.payload["items"]}
    assert "Buy ring" in task_titles
    assert "Done ancient task" not in task_titles
