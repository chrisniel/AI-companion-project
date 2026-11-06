"""Unit and integration tests for Milestone M3 Batch C1 Memory Foundation & Scoping."""

from datetime import datetime, timedelta, timezone
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.character_instance import CharacterInstance
from app.models.memory import Memory
from app.models.profile import Profile
from app.services.memory.retriever import get_core_memories, search_relevant_memories
from tests.profile_helpers import session_for_owner


@pytest.fixture
async def character_instances(client: AsyncClient, auth_headers: dict) -> tuple[str, str]:
    """Create two character instances for the active test profile."""
    res1 = await client.post(
        "/api/v1/characters/instances",
        json={"template_id": "warm-companion", "name": "Assistant Luna"},
        headers=auth_headers,
    )
    assert res1.status_code == 201
    char1_id = res1.json()["id"]

    res2 = await client.post(
        "/api/v1/characters/instances",
        json={"template_id": "warm-companion", "name": "Assistant Sol"},
        headers=auth_headers,
    )
    assert res2.status_code == 201
    char2_id = res2.json()["id"]
    return char1_id, char2_id


@pytest.mark.anyio
async def test_memory_scoping_crud(client: AsyncClient, auth_headers: dict, character_instances: tuple[str, str]):
    """MEM-01: Verify creating and listing memories with profile and character scoping."""
    char1_id, char2_id = character_instances

    # 1. Create Profile-scoped memory
    res_prof = await client.post(
        "/api/v1/memories",
        json={
            "content": "User prefers dark roast coffee",
            "category": "preference",
            "scope": "profile",
            "is_core": True,
        },
        headers=auth_headers,
    )
    assert res_prof.status_code == 201
    mem_prof = res_prof.json()
    assert mem_prof["scope"] == "profile"
    assert mem_prof["character_instance_id"] is None
    assert mem_prof["is_core"] is True
    assert mem_prof["valid_from"] is not None
    assert mem_prof["expires_at"] is None

    # 2. Create Character-scoped memory
    res_char = await client.post(
        "/api/v1/memories",
        json={
            "content": "Shared joke about space exploration with Luna",
            "category": "context",
            "scope": "character",
            "character_instance_id": char1_id,
            "is_core": False,
        },
        headers=auth_headers,
    )
    assert res_char.status_code == 201
    mem_char = res_char.json()
    assert mem_char["scope"] == "character"
    assert mem_char["character_instance_id"] == char1_id

    # 3. Filter list by scope
    list_prof = await client.get("/api/v1/memories?scope=profile", headers=auth_headers)
    assert list_prof.status_code == 200
    assert any(m["id"] == mem_prof["id"] for m in list_prof.json()["items"])
    assert not any(m["id"] == mem_char["id"] for m in list_prof.json()["items"])

    list_char1 = await client.get(f"/api/v1/memories?character_instance_id={char1_id}", headers=auth_headers)
    assert list_char1.status_code == 200
    assert any(m["id"] == mem_char["id"] for m in list_char1.json()["items"])


@pytest.mark.anyio
async def test_get_single_memory_and_isolation(client: AsyncClient, auth_headers: dict):
    """MEM-02: Verify GET /api/v1/memories/{id} returns memory and rejects unknown/foreign IDs."""
    create_res = await client.post(
        "/api/v1/memories",
        json={"content": "Single item test memory", "category": "fact"},
        headers=auth_headers,
    )
    assert create_res.status_code == 201
    mem_id = create_res.json()["id"]

    # Valid fetch
    get_res = await client.get(f"/api/v1/memories/{mem_id}", headers=auth_headers)
    assert get_res.status_code == 200
    assert get_res.json()["id"] == mem_id
    assert get_res.json()["content"] == "Single item test memory"

    # Unknown ID -> 404
    unknown_res = await client.get(f"/api/v1/memories/{uuid.uuid4()}", headers=auth_headers)
    assert unknown_res.status_code == 404


@pytest.mark.anyio
async def test_scoped_retrieval_isolation(
    test_session: AsyncSession,
    client: AsyncClient,
    auth_headers: dict,
    profile_session,
    character_instances: tuple[str, str],
):
    """MEM-03: FTS5 retrieval returns profile memories + active character memories, but excludes other characters."""
    char1_id, char2_id = character_instances

    # Insert 3 memories with the same keyword 'astronomy'
    # Profile global
    await client.post(
        "/api/v1/memories",
        json={"content": "User loves astronomy and telescopes", "scope": "profile"},
        headers=auth_headers,
    )
    # Char1 specific
    await client.post(
        "/api/v1/memories",
        json={"content": "Luna talked about astronomy galaxies", "scope": "character", "character_instance_id": char1_id},
        headers=auth_headers,
    )
    # Char2 specific
    await client.post(
        "/api/v1/memories",
        json={"content": "Sol talked about astronomy constellations", "scope": "character", "character_instance_id": char2_id},
        headers=auth_headers,
    )

    # 1. Search when active character is Luna (char1)
    results_char1 = await search_relevant_memories(
        db=test_session,
        query="astronomy",
        profile_session=profile_session,
        character_instance_id=char1_id,
    )
    texts_char1 = [m.content for m in results_char1]
    assert any("telescopes" in t for t in texts_char1)  # Profile memory included
    assert any("galaxies" in t for t in texts_char1)  # Luna memory included
    assert not any("constellations" in t for t in texts_char1)  # Sol memory EXCLUDED

    # 2. Search when active character is Sol (char2)
    results_char2 = await search_relevant_memories(
        db=test_session,
        query="astronomy",
        profile_session=profile_session,
        character_instance_id=char2_id,
    )
    texts_char2 = [m.content for m in results_char2]
    assert any("telescopes" in t for t in texts_char2)
    assert any("constellations" in t for t in texts_char2)
    assert not any("galaxies" in t for t in texts_char2)  # Luna memory EXCLUDED

    # 3. Search when active character is None (Neutral Assistant)
    results_neutral = await search_relevant_memories(
        db=test_session,
        query="astronomy",
        profile_session=profile_session,
        character_instance_id=None,
    )
    texts_neutral = [m.content for m in results_neutral]
    assert any("telescopes" in t for t in texts_neutral)
    assert not any("galaxies" in t for t in texts_neutral)
    assert not any("constellations" in t for t in texts_neutral)


@pytest.mark.anyio
async def test_temporal_expiration_retrieval(
    test_session: AsyncSession,
    client: AsyncClient,
    auth_headers: dict,
    profile_session,
):
    """MEM-04: Excluded expired temporary memories from retrieval using bound :now."""
    now = datetime.now(timezone.utc)
    valid_from_past = (now - timedelta(days=2)).isoformat()
    expired_time = (now - timedelta(hours=2)).isoformat()
    future_time = (now + timedelta(days=2)).isoformat()

    # Active temporary memory
    await client.post(
        "/api/v1/memories",
        json={"content": "Active migraine headache symptoms", "expires_at": future_time},
        headers=auth_headers,
    )
    # Expired temporary memory
    await client.post(
        "/api/v1/memories",
        json={
            "content": "Past migraine headache symptoms from yesterday",
            "valid_from": valid_from_past,
            "expires_at": expired_time,
        },
        headers=auth_headers,
    )

    results = await search_relevant_memories(
        db=test_session,
        query="migraine headache",
        profile_session=profile_session,
        now=now,
    )
    texts = [m.content for m in results]
    assert any("Active migraine" in t for t in texts)
    assert not any("Past migraine" in t for t in texts)


@pytest.mark.anyio
async def test_core_fact_injection_and_deduplication(
    test_session: AsyncSession,
    client: AsyncClient,
    auth_headers: dict,
    profile_session,
):
    """MEM-05: get_core_memories returns profile-level non-temporary core facts."""
    # Create core fact
    await client.post(
        "/api/v1/memories",
        json={"content": "User name is Alex and speaks English and Filipino", "is_core": True, "importance": 1.8},
        headers=auth_headers,
    )
    # Create temporary fact (should not be core even if is_core flag accidentally set)
    now = datetime.now(timezone.utc)
    await client.post(
        "/api/v1/memories",
        json={"content": "Temporary sick leave", "is_core": True, "expires_at": (now + timedelta(days=1)).isoformat()},
        headers=auth_headers,
    )

    core_facts = await get_core_memories(test_session, profile_session.profile_id, limit=5, now=now)
    core_texts = [m.content for m in core_facts]
    assert any("Alex" in t for t in core_texts)
    assert not any("sick leave" in t for t in core_texts)


@pytest.mark.anyio
async def test_foreign_character_instance_rejected(test_session: AsyncSession, client: AsyncClient, auth_headers: dict):
    """MEM-06: Attempting to associate memory with a character instance from another profile fails."""
    # Create another profile and character instance via session_for_owner
    foreign_session = await session_for_owner(test_session, owner="foreign_user")
    foreign_char = CharacterInstance(
        id=str(uuid.uuid4()),
        profile_id=foreign_session.profile_id,
        template_id="warm-companion",
        source_template_version=1,
        name="Foreign Companion",
        summary="Foreign companion",
        lore="Foreign",
        system_prompt="You are friendly",
        avatar_asset="default_avatar",
        preset_id="warm_companion",
        warmth=50,
        teasing=50,
        guardedness=50,
        directness=50,
        expressiveness=50,
        affection=50,
        formality=50,
        verbosity=50,
        status="active",
    )
    test_session.add(foreign_char)
    await test_session.commit()

    # Attempt to create memory bound to foreign_char.id
    res = await client.post(
        "/api/v1/memories",
        json={
            "content": "Malicious association",
            "scope": "character",
            "character_instance_id": foreign_char.id,
        },
        headers=auth_headers,
    )
    assert res.status_code in (403, 404)


@pytest.mark.anyio
async def test_patch_clearing_expiration(client: AsyncClient, auth_headers: dict):
    """MEM-07: PATCH with expires_at = null clears expiration and makes memory permanent."""
    now = datetime.now(timezone.utc)
    future_time = (now + timedelta(days=1)).isoformat()

    create_res = await client.post(
        "/api/v1/memories",
        json={"content": "User is studying for bar exam", "expires_at": future_time},
        headers=auth_headers,
    )
    assert create_res.status_code == 201
    mem_id = create_res.json()["id"]
    assert create_res.json()["expires_at"] is not None

    # Clear expiration
    patch_res = await client.patch(
        f"/api/v1/memories/{mem_id}",
        json={"expires_at": None, "is_core": True},
        headers=auth_headers,
    )
    assert patch_res.status_code == 200
    updated = patch_res.json()
    assert updated["expires_at"] is None
    assert updated["is_core"] is True
    assert updated["last_verified_at"] is not None


@pytest.mark.anyio
async def test_profile_hard_purge_with_memories(
    test_session: AsyncSession,
):
    """MEM-08: Deleting a profile permanently purges memories and character instances without FK violation."""
    from app.services.profile_purge_service import ProfilePurgeService

    # 1. Create a secondary profile and character instance
    sec_profile = Profile(
        id=str(uuid.uuid4()),
        name="Purge Target Profile",
        is_default=False,
        status="active",
    )
    test_session.add(sec_profile)

    char_inst = CharacterInstance(
        id=str(uuid.uuid4()),
        profile_id=sec_profile.id,
        template_id="warm-companion",
        source_template_version=1,
        name="Purgeable Companion",
        summary="A helpful companion",
        lore="Friendly",
        system_prompt="You are friendly",
        avatar_asset="default_avatar",
        preset_id="warm_companion",
        warmth=50,
        teasing=50,
        guardedness=50,
        directness=50,
        expressiveness=50,
        affection=50,
        formality=50,
        verbosity=50,
        status="active",
    )
    test_session.add(char_inst)

    # 2. Create character-scoped memory bound to char_inst.id
    mem = Memory(
        id=str(uuid.uuid4()),
        profile_id=sec_profile.id,
        scope="character",
        character_instance_id=char_inst.id,
        category="fact",
        content="Purgeable memory bound to character",
        importance=1.0,
        source_type="manual",
        user_verified=True,
    )
    test_session.add(mem)
    await test_session.commit()

    # 3. Soft-delete and then permanently purge secondary profile
    purge_svc = ProfilePurgeService(test_session)
    await purge_svc.soft_delete_profile(sec_profile.id)
    success = await purge_svc.purge_profile(sec_profile.id, allow_unexpired=True)
    assert success is True

    # 4. Confirm memories and character instances are wiped
    remaining_mem = await test_session.scalars(select(Memory).where(Memory.profile_id == sec_profile.id))
    assert list(remaining_mem.all()) == []
    remaining_char = await test_session.scalars(select(CharacterInstance).where(CharacterInstance.profile_id == sec_profile.id))
    assert list(remaining_char.all()) == []
