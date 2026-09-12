"""Tests for Tasks CRUD endpoints, categories, reminders, soft deletion, and retention purge."""

from datetime import datetime, timedelta, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.task import Task
from app.services.retention import purge_expired_trash


@pytest.mark.asyncio
async def test_tasks_require_authentication(client: AsyncClient):
    """AC-3 / Security: Tasks endpoints must require authentication."""
    response = await client.get("/api/v1/tasks")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_task_succeeds(client: AsyncClient, auth_headers: dict):
    """AC-8 / Tasks CRUD: Create a task and confirm generated metadata."""
    payload = {
        "title": "Configure Kokoro TTS Model",
        "notes": "Ensure 24kHz Kokoro-82M ONNX runs under 0.3x RTF.",
        "priority": "high",
        "category": "dev",
    }
    response = await client.post("/api/v1/tasks", json=payload, headers=auth_headers)
    assert response.status_code == 201

    data = response.json()
    assert data["title"] == payload["title"]
    assert data["notes"] == payload["notes"]
    assert data["category"] == "dev"
    assert data["priority"] == "high"
    assert data["status"] == "pending"
    assert data["owner_id"] == "local_user"
    assert data["is_deleted"] is False
    assert data["deleted_at"] is None
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


@pytest.mark.asyncio
async def test_create_task_extra_fields_rejected_422(client: AsyncClient, auth_headers: dict):
    """AC-4 / OWASP API3: Reject unexpected payload fields to prevent mass assignment."""
    payload = {
        "title": "Clean Task Title",
        "is_admin": True,  # Unregistered forbidden field
        "unauthorized_role": "superuser",
    }
    response = await client.post("/api/v1/tasks", json=payload, headers=auth_headers)
    assert response.status_code == 422

    error_data = response.json()
    assert "error" in error_data
    assert error_data["error"]["code"] == "VALIDATION_FAILED"


@pytest.mark.asyncio
async def test_list_tasks_and_filtering(client: AsyncClient, auth_headers: dict):
    """AC-8 / Tasks CRUD: List tasks and filter by status, priority, and category."""
    # Create tasks with distinct categories and priorities
    task1 = await client.post(
        "/api/v1/tasks",
        json={"title": "Work Task", "priority": "low", "category": "work"},
        headers=auth_headers,
    )
    task2 = await client.post(
        "/api/v1/tasks",
        json={"title": "Dev Task", "priority": "urgent", "category": "dev"},
        headers=auth_headers,
    )
    task2_id = task2.json()["id"]

    # Mark task2 as completed
    await client.patch(
        f"/api/v1/tasks/{task2_id}",
        json={"status": "completed"},
        headers=auth_headers,
    )

    # List all active
    all_resp = await client.get("/api/v1/tasks", headers=auth_headers)
    assert all_resp.status_code == 200
    assert all_resp.json()["total"] >= 2

    # Filter completed
    completed_resp = await client.get("/api/v1/tasks?status=completed", headers=auth_headers)
    assert completed_resp.status_code == 200
    items = completed_resp.json()["items"]
    assert all(item["status"] == "completed" for item in items)

    # Filter by priority
    urgent_resp = await client.get("/api/v1/tasks?priority=urgent", headers=auth_headers)
    assert urgent_resp.status_code == 200
    urgent_items = urgent_resp.json()["items"]
    assert any(item["id"] == task2_id for item in urgent_items)

    # Filter by category
    work_resp = await client.get("/api/v1/tasks?category=work", headers=auth_headers)
    assert work_resp.status_code == 200
    work_items = work_resp.json()["items"]
    assert all(item["category"] == "work" for item in work_items)


@pytest.mark.asyncio
async def test_get_and_update_task_lifecycle(client: AsyncClient, auth_headers: dict):
    """AC-8 / Tasks CRUD: Full get, partial update, and soft-delete lifecycle."""
    # 1. Create
    create_resp = await client.post(
        "/api/v1/tasks",
        json={"title": "Temporary Task", "priority": "medium"},
        headers=auth_headers,
    )
    task_id = create_resp.json()["id"]

    # 2. Get by ID
    get_resp = await client.get(f"/api/v1/tasks/{task_id}", headers=auth_headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == task_id

    # 3. Partial Update
    patch_resp = await client.patch(
        f"/api/v1/tasks/{task_id}",
        json={"title": "Updated Task Title", "notes": "New note added.", "category": "personal"},
        headers=auth_headers,
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["title"] == "Updated Task Title"
    assert patch_resp.json()["notes"] == "New note added."
    assert patch_resp.json()["category"] == "personal"

    # 4. Soft Delete
    delete_resp = await client.delete(f"/api/v1/tasks/{task_id}", headers=auth_headers)
    assert delete_resp.status_code == 204

    # 5. Verify deleted returns 404 from active endpoint
    get_again = await client.get(f"/api/v1/tasks/{task_id}", headers=auth_headers)
    assert get_again.status_code == 404
    assert get_again.json()["error"]["code"] == "RESOURCE_NOT_FOUND"


@pytest.mark.asyncio
async def test_task_category_and_auto_reminder_calculation(client: AsyncClient, auth_headers: dict):
    """Track B6: Test category persistence and auto reminder_at computation from due_date and minutes before."""
    due = datetime.now(timezone.utc) + timedelta(days=2)
    due_iso = due.isoformat()

    payload = {
        "title": "Hospital Appointment Reminder",
        "category": "health",
        "due_date": due_iso,
        "reminder_minutes_before": 30,
    }
    response = await client.post("/api/v1/tasks", json=payload, headers=auth_headers)
    assert response.status_code == 201

    data = response.json()
    assert data["category"] == "health"
    assert data["reminder_minutes_before"] == 30
    assert data["reminder_at"] is not None

    expected_reminder = due - timedelta(minutes=30)
    parsed_reminder = datetime.fromisoformat(data["reminder_at"])
    if parsed_reminder.tzinfo is None:
        parsed_reminder = parsed_reminder.replace(tzinfo=timezone.utc)
    # Allow 1-second precision tolerance across serialization
    assert abs((parsed_reminder - expected_reminder).total_seconds()) < 2


@pytest.mark.asyncio
async def test_soft_delete_and_recycle_bin_lifecycle(client: AsyncClient, auth_headers: dict):
    """Section 16.1: Test soft-delete, trash listing with expiry days, restoration, and permanent purge."""
    # 1. Create a task
    create_resp = await client.post(
        "/api/v1/tasks",
        json={"title": "Task destined for trash", "category": "shopping"},
        headers=auth_headers,
    )
    task_id = create_resp.json()["id"]

    # 2. Soft-delete the task
    del_resp = await client.delete(f"/api/v1/tasks/{task_id}", headers=auth_headers)
    assert del_resp.status_code == 204

    # 3. Verify it is absent from active task list
    active_resp = await client.get("/api/v1/tasks", headers=auth_headers)
    assert not any(t["id"] == task_id for t in active_resp.json()["items"])

    # 4. Verify it is present in Trash (Recycle Bin)
    trash_resp = await client.get("/api/v1/tasks/trash", headers=auth_headers)
    assert trash_resp.status_code == 200
    trash_items = trash_resp.json()["items"]
    matching = next((t for t in trash_items if t["id"] == task_id), None)
    assert matching is not None
    assert matching["is_deleted"] is True
    assert matching["deleted_at"] is not None
    assert matching["expires_in_days"] >= 29  # Default 30-day retention

    # 5. Restore the task
    restore_resp = await client.post(f"/api/v1/tasks/{task_id}/restore", headers=auth_headers)
    assert restore_resp.status_code == 200
    restored_data = restore_resp.json()
    assert restored_data["id"] == task_id
    assert restored_data["is_deleted"] is False
    assert restored_data["deleted_at"] is None

    # 6. Verify it is restored in active list and gone from trash
    active_after_restore = await client.get("/api/v1/tasks", headers=auth_headers)
    assert any(t["id"] == task_id for t in active_after_restore.json()["items"])

    trash_after_restore = await client.get("/api/v1/tasks/trash", headers=auth_headers)
    assert not any(t["id"] == task_id for t in trash_after_restore.json()["items"])

    # 7. Soft delete again, then permanently delete from trash
    await client.delete(f"/api/v1/tasks/{task_id}", headers=auth_headers)
    perm_resp = await client.delete(f"/api/v1/tasks/{task_id}/permanent", headers=auth_headers)
    assert perm_resp.status_code == 204

    # 8. Confirm task is completely purged from trash
    trash_after_perm = await client.get("/api/v1/tasks/trash", headers=auth_headers)
    assert not any(t["id"] == task_id for t in trash_after_perm.json()["items"])


@pytest.mark.asyncio
async def test_cannot_permanently_delete_active_task(client: AsyncClient, auth_headers: dict):
    """Section 16.1: Permanent delete is only permissible on tasks residing in trash."""
    create_resp = await client.post(
        "/api/v1/tasks",
        json={"title": "Active Task Not In Trash"},
        headers=auth_headers,
    )
    task_id = create_resp.json()["id"]

    perm_resp = await client.delete(f"/api/v1/tasks/{task_id}/permanent", headers=auth_headers)
    assert perm_resp.status_code == 404
    assert perm_resp.json()["error"]["code"] == "RESOURCE_NOT_FOUND"


@pytest.mark.asyncio
async def test_retention_purge_service(test_session: AsyncSession):
    """Section 16.1: Test purge_expired_trash service permanently deletes records exceeding retention cutoff."""
    now = datetime.now(timezone.utc)
    old_deleted_at = now - timedelta(days=35)
    recent_deleted_at = now - timedelta(days=5)

    # Insert old soft-deleted task
    old_task = Task(
        title="Old Deleted Task (35 days)",
        category="general",
        priority="low",
        status="pending",
        is_deleted=True,
        deleted_at=old_deleted_at,
        owner_id="local_user",
    )
    # Insert recent soft-deleted task
    recent_task = Task(
        title="Recent Deleted Task (5 days)",
        category="work",
        priority="medium",
        status="pending",
        is_deleted=True,
        deleted_at=recent_deleted_at,
        owner_id="local_user",
    )
    test_session.add_all([old_task, recent_task])
    await test_session.commit()

    # Run purge with 30-day retention
    purged_count = await purge_expired_trash(test_session, retention_days=30)
    assert purged_count == 1

    # Verify old task is gone and recent task remains
    result_old = await test_session.execute(select(Task).where(Task.id == old_task.id))
    assert result_old.scalar_one_or_none() is None

    result_recent = await test_session.execute(select(Task).where(Task.id == recent_task.id))
    assert result_recent.scalar_one_or_none() is not None
