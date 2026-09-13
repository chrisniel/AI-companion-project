"""Tests for Memory CRUD, FTS5 full-text indexing, token sanitization, and multilingual matching."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.services.memory.retriever import search_relevant_memories, _sanitize_fts_query


@pytest.mark.anyio
async def test_memory_crud_endpoints(client: AsyncClient, auth_headers: dict):
    """Test Memory REST endpoints."""
    # 1. Create memory
    res = await client.post(
        "/api/v1/memories",
        json={"content": "User lives in Manila and likes coding", "category": "fact", "importance": 1.5},
        headers=auth_headers,
    )
    assert res.status_code == 201
    mem = res.json()
    mem_id = mem["id"]
    assert mem["content"] == "User lives in Manila and likes coding"
    assert mem["category"] == "fact"

    # 2. List memories
    list_res = await client.get("/api/v1/memories?category=fact", headers=auth_headers)
    assert list_res.status_code == 200
    data = list_res.json()
    assert data["total"] >= 1
    assert any(m["id"] == mem_id for m in data["items"])

    # 3. Update memory
    patch_res = await client.patch(
        f"/api/v1/memories/{mem_id}",
        json={"content": "User lives in Taguig and likes coding"},
        headers=auth_headers,
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["content"] == "User lives in Taguig and likes coding"

    # 4. Soft-delete memory
    del_res = await client.delete(f"/api/v1/memories/{mem_id}", headers=auth_headers)
    assert del_res.status_code == 204


@pytest.mark.anyio
async def test_fts5_sync_and_search(test_session: AsyncSession, client: AsyncClient, auth_headers: dict):
    """Verify FTS5 trigger synchronization on insert, update, and delete."""
    # Create via API
    res = await client.post(
        "/api/v1/memories",
        json={"content": "Chris loves playing Steins;Gate on PC", "category": "preference"},
        headers=auth_headers,
    )
    mem = res.json()
    owner_id = mem["owner_id"]
    mem_id = mem["id"]

    # FTS5 search finds it
    results = await search_relevant_memories(test_session, "Steins Gate", owner_id)
    assert len(results) >= 1
    assert any("Steins" in r.content for r in results)

    # Update memory content
    await client.patch(
        f"/api/v1/memories/{mem_id}",
        json={"content": "Chris loves playing Cyberpunk on PC"},
        headers=auth_headers,
    )

    # Search old term -> empty
    old_res = await search_relevant_memories(test_session, "Steins", owner_id)
    assert len(old_res) == 0

    # Search new term -> found
    new_res = await search_relevant_memories(test_session, "Cyberpunk", owner_id)
    assert len(new_res) >= 1

    # Soft delete memory
    await client.delete(f"/api/v1/memories/{mem_id}", headers=auth_headers)

    # Search after delete -> empty
    del_search = await search_relevant_memories(test_session, "Cyberpunk", owner_id)
    assert len(del_search) == 0


@pytest.mark.anyio
async def test_fts5_sanitization_and_multilingual(test_session: AsyncSession, client: AsyncClient, auth_headers: dict):
    """Verify query sanitization prevents FTS5 syntax errors and supports EN/FIL/JA tokens."""
    # Malformed queries with special characters, quotes, logic operators
    assert _sanitize_fts_query("NOT (OR AND *^%$#@!)") == ""
    assert _sanitize_fts_query("Chris OR Manila") == "Chris OR Manila"
    assert _sanitize_fts_query("'''\"\"\"---***") == ""

    # Test that empty / punctuation queries do not crash search
    res = await search_relevant_memories(test_session, "!@#$%^&*()", "test-owner")
    assert res == []

    # Test multilingual insertion (Tagalog & Japanese)
    r1 = await client.post(
        "/api/v1/memories",
        json={"content": "Paborito ko ang halo-halo kapag tag-init", "category": "preference"},
        headers=auth_headers,
    )
    owner_id = r1.json()["owner_id"]

    r2 = await client.post(
        "/api/v1/memories",
        json={"content": "好きなアニメ: シュタインズ・ゲート", "category": "fact"},
        headers=auth_headers,
    )

    # Search Tagalog term
    fil_res = await search_relevant_memories(test_session, "halo-halo tag-init", owner_id)
    assert len(fil_res) >= 1

    # Search Japanese term
    ja_res = await search_relevant_memories(test_session, "シュタインズ", owner_id)
    assert len(ja_res) >= 1
