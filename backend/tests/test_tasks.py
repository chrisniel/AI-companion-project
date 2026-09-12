"""Tests for Tasks CRUD endpoints, Pydantic mass-assignment guards, and filtering."""

import pytest
from httpx import AsyncClient


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
    }
    response = await client.post("/api/v1/tasks", json=payload, headers=auth_headers)
    assert response.status_code == 201

    data = response.json()
    assert data["title"] == payload["title"]
    assert data["notes"] == payload["notes"]
    assert data["priority"] == "high"
    assert data["status"] == "pending"
    assert data["owner_id"] == "local_user"
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
    """AC-8 / Tasks CRUD: List tasks and filter by status and priority."""
    # Create two tasks with distinct statuses
    task1 = await client.post(
        "/api/v1/tasks",
        json={"title": "Task 1", "priority": "low"},
        headers=auth_headers,
    )
    task2 = await client.post(
        "/api/v1/tasks",
        json={"title": "Task 2", "priority": "urgent"},
        headers=auth_headers,
    )
    task2_id = task2.json()["id"]

    # Mark task2 as completed
    await client.patch(
        f"/api/v1/tasks/{task2_id}",
        json={"status": "completed"},
        headers=auth_headers,
    )

    # List all
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


@pytest.mark.asyncio
async def test_get_and_update_task_lifecycle(client: AsyncClient, auth_headers: dict):
    """AC-8 / Tasks CRUD: Full get, partial update, and delete lifecycle."""
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
        json={"title": "Updated Task Title", "notes": "New note added."},
        headers=auth_headers,
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["title"] == "Updated Task Title"
    assert patch_resp.json()["notes"] == "New note added."

    # 4. Delete
    delete_resp = await client.delete(f"/api/v1/tasks/{task_id}", headers=auth_headers)
    assert delete_resp.status_code == 204

    # 5. Verify deleted returns 404
    get_again = await client.get(f"/api/v1/tasks/{task_id}", headers=auth_headers)
    assert get_again.status_code == 404
    assert get_again.json()["error"]["code"] == "RESOURCE_NOT_FOUND"
