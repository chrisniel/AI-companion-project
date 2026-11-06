"""Tests for Memory API query filters (q, user_verified, source_type) and approval updates."""

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.memory import Memory


@pytest.mark.anyio
async def test_list_memories_with_q_filter(client: AsyncClient, auth_headers: dict):
    """Verify search filter q returns substring-matching memories."""
    # Create two memories
    await client.post(
        "/api/v1/memories",
        json={"content": "Loves drinking iced matcha latte every morning", "category": "preference"},
        headers=auth_headers,
    )
    await client.post(
        "/api/v1/memories",
        json={"content": "Works as a software architect at an aerospace firm", "category": "fact"},
        headers=auth_headers,
    )

    # Search for "matcha"
    res1 = await client.get("/api/v1/memories?q=matcha", headers=auth_headers)
    assert res1.status_code == 200
    items1 = res1.json()["items"]
    assert len(items1) == 1
    assert "matcha" in items1[0]["content"].lower()

    # Search for "aerospace"
    res2 = await client.get("/api/v1/memories?q=aerospace", headers=auth_headers)
    assert res2.status_code == 200
    items2 = res2.json()["items"]
    assert len(items2) == 1
    assert "aerospace" in items2[0]["content"].lower()

    # Search for non-existent keyword
    res3 = await client.get("/api/v1/memories?q=nonexistentkeywordxyz", headers=auth_headers)
    assert res3.status_code == 200
    assert len(res3.json()["items"]) == 0


@pytest.mark.anyio
async def test_list_memories_with_user_verified_filter(client: AsyncClient, auth_headers: dict, test_session, profile_id):
    """Verify filtering by user_verified=true and user_verified=false."""
    # Manual memory created via API is user_verified=True
    res_m = await client.post(
        "/api/v1/memories",
        json={"content": "Verified manual fact about user hobbies", "category": "fact"},
        headers=auth_headers,
    )
    assert res_m.status_code == 201

    # Insert an unverified memory directly to simulate background extraction
    import uuid
    unverified = Memory(
        id=str(uuid.uuid4()),
        profile_id=profile_id,
        content="Unverified extracted statement about favorite colors",
        category="preference",
        source_type="extracted",
        user_verified=False,
    )
    test_session.add(unverified)
    await test_session.commit()

    # Filter user_verified=false
    res_unv = await client.get("/api/v1/memories?user_verified=false", headers=auth_headers)
    assert res_unv.status_code == 200
    items_unv = res_unv.json()["items"]
    assert any(m["id"] == unverified.id for m in items_unv)
    assert all(m["user_verified"] is False for m in items_unv)

    # Filter user_verified=true
    res_ver = await client.get("/api/v1/memories?user_verified=true", headers=auth_headers)
    assert res_ver.status_code == 200
    items_ver = res_ver.json()["items"]
    assert all(m["user_verified"] is True for m in items_ver)
    assert not any(m["id"] == unverified.id for m in items_ver)


@pytest.mark.anyio
async def test_list_memories_with_source_type_filter(client: AsyncClient, auth_headers: dict, test_session, profile_id):
    """Verify filtering by source_type=conflict."""
    import uuid
    conflict = Memory(
        id=str(uuid.uuid4()),
        profile_id=profile_id,
        content="Conflicting fact: user states they hate tea",
        category="preference",
        source_type="conflict",
        user_verified=False,
    )
    test_session.add(conflict)
    await test_session.commit()

    res = await client.get("/api/v1/memories?source_type=conflict", headers=auth_headers)
    assert res.status_code == 200
    items = res.json()["items"]
    assert len(items) >= 1
    assert any(m["id"] == conflict.id for m in items)
    assert all(m["source_type"] == "conflict" for m in items)


@pytest.mark.anyio
async def test_patch_memory_approves_and_updates_last_verified_at(client: AsyncClient, auth_headers: dict, test_session, profile_id):
    """Verify PATCH /api/v1/memories/{id} with user_verified=True marks verified and sets last_verified_at."""
    import uuid
    extracted = Memory(
        id=str(uuid.uuid4()),
        profile_id=profile_id,
        content="Candidate fact pending user confirmation",
        category="fact",
        source_type="extracted",
        user_verified=False,
        last_verified_at=None,
    )
    test_session.add(extracted)
    await test_session.commit()

    patch_res = await client.patch(
        f"/api/v1/memories/{extracted.id}",
        json={"user_verified": True},
        headers=auth_headers,
    )
    assert patch_res.status_code == 200
    data = patch_res.json()
    assert data["user_verified"] is True
    assert data["last_verified_at"] is not None

    # Check DB
    await test_session.refresh(extracted)
    assert extracted.user_verified is True
    assert extracted.last_verified_at is not None


@pytest.mark.anyio
async def test_patch_memory_updates_source_type(client: AsyncClient, auth_headers: dict, test_session, profile_id):
    """Verify PATCH /api/v1/memories/{id} can update source_type (e.g. from conflict to manual upon resolution)."""
    import uuid
    conflict = Memory(
        id=str(uuid.uuid4()),
        profile_id=profile_id,
        content="Resolved conflict fact",
        category="preference",
        source_type="conflict",
        user_verified=False,
    )
    test_session.add(conflict)
    await test_session.commit()

    patch_res = await client.patch(
        f"/api/v1/memories/{conflict.id}",
        json={"source_type": "manual", "user_verified": True},
        headers=auth_headers,
    )
    assert patch_res.status_code == 200
    data = patch_res.json()
    assert data["source_type"] == "manual"
    assert data["user_verified"] is True
