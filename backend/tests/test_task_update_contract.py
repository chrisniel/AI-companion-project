"""F05: actual Task PATCH validation, omission, derivation and ORM persistence."""

from datetime import datetime

import pytest
from pydantic import ValidationError
from sqlalchemy import select

from app.models.task import Task
from app.schemas.task import TaskUpdate


ORIGINAL = {
    "title": "Original", "notes": "Keep", "category": "work", "priority": "high",
    "due_date": "2030-06-01T12:00:00", "reminder_minutes_before": 30,
    "reminder_at": "2030-05-31T09:00:00",
}


async def create(client, auth_headers, **overrides):
    response = await client.post("/api/v1/tasks", headers=auth_headers, json={**ORIGINAL, **overrides})
    assert response.status_code == 201
    return response.json()


@pytest.mark.asyncio
@pytest.mark.parametrize("field", ["title", "category", "status", "priority"])
async def test_required_null_rejected_without_partial_write(client, auth_headers, test_session, field):
    original = await create(client, auth_headers)
    response = await client.patch(f"/api/v1/tasks/{original['id']}", headers=auth_headers,
                                  json={"notes": "Must not persist", field: None})
    assert response.status_code == 422
    stored = await client.get(f"/api/v1/tasks/{original['id']}", headers=auth_headers)
    assert stored.json() == original
    task = (await test_session.execute(select(Task).where(Task.id == original["id"]))).scalar_one()
    assert task.notes == "Keep" and task.title == "Original"


@pytest.mark.parametrize("field", ["title", "category", "status", "priority"])
def test_required_fields_are_omittable_but_not_nullable_in_validation_and_schema(field):
    assert TaskUpdate().model_dump(exclude_unset=True) == {}
    with pytest.raises(ValidationError):
        TaskUpdate(**{field: None})
    schema = TaskUpdate.model_json_schema()
    assert field not in schema.get("required", [])
    property_schema = schema["properties"][field]
    assert property_schema.get("type") != "null"
    assert not any(branch.get("type") == "null" for branch in property_schema.get("anyOf", []))
    assert "default" not in property_schema


@pytest.mark.asyncio
@pytest.mark.parametrize("patch", [{}, {"notes": "Changed"}, {"priority": "low"}, {"status": "completed"}])
async def test_omission_and_unrelated_updates_preserve_existing_reminder(client, auth_headers, patch):
    original = await create(client, auth_headers)
    response = await client.patch(f"/api/v1/tasks/{original['id']}", headers=auth_headers, json=patch)
    assert response.status_code == 200
    stored = (await client.get(f"/api/v1/tasks/{original['id']}", headers=auth_headers)).json()
    for field in ORIGINAL:
        assert stored[field] == patch.get(field, original[field])


@pytest.mark.asyncio
@pytest.mark.parametrize("field", ["notes", "due_date", "reminder_minutes_before", "reminder_at"])
async def test_nullable_fields_clear_and_impossible_derivation_clears_reminder(client, auth_headers, field):
    original = await create(client, auth_headers)
    response = await client.patch(f"/api/v1/tasks/{original['id']}", headers=auth_headers, json={field: None})
    assert response.status_code == 200
    stored = (await client.get(f"/api/v1/tasks/{original['id']}", headers=auth_headers)).json()
    assert stored[field] is None
    expected = original["reminder_at"] if field == "notes" else None
    assert stored["reminder_at"] == expected


@pytest.mark.asyncio
@pytest.mark.parametrize("patch,expected", [
    ({"due_date": "2031-06-01T12:00:00"}, datetime(2031, 6, 1, 11, 30)),
    ({"reminder_minutes_before": 5}, datetime(2030, 6, 1, 11, 55)),
    ({"due_date": None, "reminder_at": "2032-01-01T08:00:00"}, datetime(2032, 1, 1, 8)),
    ({"due_date": "2031-06-01T12:00:00", "reminder_minutes_before": 5, "reminder_at": None}, None),
])
async def test_reminder_derivation_and_explicit_timestamp_precedence(client, auth_headers, patch, expected):
    original = await create(client, auth_headers)
    response = await client.patch(f"/api/v1/tasks/{original['id']}", headers=auth_headers, json=patch)
    assert response.status_code == 200
    stored = (await client.get(f"/api/v1/tasks/{original['id']}", headers=auth_headers)).json()
    actual = datetime.fromisoformat(stored["reminder_at"]) if stored["reminder_at"] else None
    assert actual == expected
