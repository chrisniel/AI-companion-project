"""Authentication, authorization, and adversarial cross-profile isolation tests for Characters API (PC-CHAR-001, PC-CHAR-005)."""

import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.profile_sessions import new_profile_session
from app.models.profile import Profile
from app.models.character_instance import CharacterInstance


@pytest.fixture
async def two_profiles_with_sessions(test_session: AsyncSession):
    """Fixture providing two distinct profiles and their authenticated session headers."""
    # Profile A
    prof_a = Profile(id="profile-alpha-001", name="Alpha User", is_default=False)
    test_session.add(prof_a)
    token_a, session_a = new_profile_session(prof_a.id, "desktop")
    test_session.add(session_a)

    # Profile B
    prof_b = Profile(id="profile-beta-002", name="Beta User", is_default=False)
    test_session.add(prof_b)
    token_b, session_b = new_profile_session(prof_b.id, "desktop")
    test_session.add(session_b)

    await test_session.commit()

    return {
        "profile_a": prof_a,
        "token_a": token_a,
        "headers_a": {"Authorization": f"Bearer {token_a}"},
        "profile_b": prof_b,
        "token_b": token_b,
        "headers_b": {"Authorization": f"Bearer {token_b}"},
    }


@pytest.mark.asyncio
async def test_character_endpoints_require_authentication(client: AsyncClient):
    """All /characters/* endpoints must reject requests without valid Profile Session with 401."""
    endpoints = [
        ("GET", "/api/v1/characters/templates"),
        ("GET", "/api/v1/characters/presets"),
        ("GET", "/api/v1/characters/neutral"),
        ("GET", "/api/v1/characters/active"),
        ("PUT", "/api/v1/characters/active"),
        ("POST", "/api/v1/characters/active/reset-neutral"),
        ("GET", "/api/v1/characters/instances"),
        ("POST", "/api/v1/characters/instances"),
        ("GET", "/api/v1/characters/instances/dummy-inst-1"),
        ("PATCH", "/api/v1/characters/instances/dummy-inst-1"),
        ("DELETE", "/api/v1/characters/instances/dummy-inst-1"),
    ]

    for method, path in endpoints:
        if method == "GET":
            resp = await client.get(path)
        elif method == "POST":
            resp = await client.post(path, json={})
        elif method == "PUT":
            resp = await client.put(path, json={"character_id": "dummy"})
        elif method == "PATCH":
            resp = await client.patch(path, json={"name": "dummy"})
        elif method == "DELETE":
            resp = await client.delete(path)
        assert resp.status_code == 401, f"Expected 401 for {method} {path}, got {resp.status_code}"


@pytest.mark.asyncio
async def test_character_crud_and_active_switching_flow(
    client: AsyncClient,
    two_profiles_with_sessions: dict,
):
    headers = two_profiles_with_sessions["headers_a"]

    # 1. Templates & Presets catalog
    resp = await client.get("/api/v1/characters/templates", headers=headers)
    assert resp.status_code == 200
    templates = resp.json()
    assert len(templates) >= 4
    template_ids = {t["id"] for t in templates}
    assert "neutral-assistant" in template_ids
    assert "warm-companion" in template_ids

    resp = await client.get("/api/v1/characters/presets", headers=headers)
    assert resp.status_code == 200
    presets = resp.json()
    assert len(presets) == 8

    # 2. Neutral Assistant fallback definition
    resp = await client.get("/api/v1/characters/neutral", headers=headers)
    assert resp.status_code == 200
    neutral = resp.json()
    assert neutral["id"] == "neutral-assistant"
    assert neutral["is_neutral_fallback"] is True
    assert neutral["traits"] is None

    # 3. Initial active state is Neutral
    resp = await client.get("/api/v1/characters/active", headers=headers)
    assert resp.status_code == 200
    active_init = resp.json()
    assert active_init["is_neutral_fallback"] is True
    assert active_init["active_character_id"] == "neutral-assistant"
    assert active_init["active_character_instance_id"] is None

    # 4. Create instance from warm-companion
    create_payload = {
        "template_id": "warm-companion",
        "name": "Alpha Companion",
        "preset_id": "warm_companion",
    }
    resp = await client.post("/api/v1/characters/instances", json=create_payload, headers=headers)
    assert resp.status_code == 201
    created_inst = resp.json()
    inst_id = created_inst["id"]
    assert created_inst["name"] == "Alpha Companion"
    assert created_inst["template_id"] == "warm-companion"
    assert created_inst["traits"]["warmth"] == 85

    # 5. List instances
    resp = await client.get("/api/v1/characters/instances", headers=headers)
    assert resp.status_code == 200
    instances = resp.json()
    assert len(instances) == 1
    assert instances[0]["id"] == inst_id

    # 6. Select instance as active
    resp = await client.put("/api/v1/characters/active", json={"character_id": inst_id}, headers=headers)
    assert resp.status_code == 200
    active_updated = resp.json()
    assert active_updated["is_neutral_fallback"] is False
    assert active_updated["active_character_id"] == inst_id
    assert active_updated["active_character_instance_id"] == inst_id

    # 7. Update instance
    resp = await client.patch(f"/api/v1/characters/instances/{inst_id}", json={"name": "Updated Alpha Companion"}, headers=headers)
    assert resp.status_code == 200
    updated = resp.json()
    assert updated["name"] == "Updated Alpha Companion"
    assert updated["traits"]["warmth"] == 85  # unchanged

    # 8. Reset to Neutral
    resp = await client.post("/api/v1/characters/active/reset-neutral", headers=headers)
    assert resp.status_code == 200
    reset_state = resp.json()
    assert reset_state["is_neutral_fallback"] is True
    assert reset_state["active_character_id"] == "neutral-assistant"

    # 9. Delete instance (soft-delete)
    resp = await client.delete(f"/api/v1/characters/instances/{inst_id}", headers=headers)
    assert resp.status_code == 204

    # Instance is now soft-deleted -> 404 on subsequent get
    resp = await client.get(f"/api/v1/characters/instances/{inst_id}", headers=headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_condition_a_explicit_null_rejection_at_api_boundary(
    client: AsyncClient,
    two_profiles_with_sessions: dict,
):
    """Mandatory Acceptance Condition A: Explicit-null fields in PATCH return 422 and leave state unchanged."""
    headers = two_profiles_with_sessions["headers_a"]

    # Create instance
    create_payload = {
        "template_id": "warm-companion",
        "name": "Immutable Name Test",
    }
    resp = await client.post("/api/v1/characters/instances", json=create_payload, headers=headers)
    assert resp.status_code == 201
    inst_id = resp.json()["id"]

    # Explicit null on non-nullable fields must return 422
    for field in ["name", "preset_id", "status", "traits", "system_prompt", "avatar_asset"]:
        resp = await client.patch(
            f"/api/v1/characters/instances/{inst_id}",
            json={field: None},
            headers=headers,
        )
        assert resp.status_code == 422, f"Expected 422 for {field}=None, got {resp.status_code}: {resp.text}"

    # Verify state was not modified
    resp = await client.get(f"/api/v1/characters/instances/{inst_id}", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["name"] == "Immutable Name Test"


@pytest.mark.asyncio
async def test_adversarial_cross_profile_isolation(
    client: AsyncClient,
    two_profiles_with_sessions: dict,
):
    """Adversarial Isolation: Profile B cannot read, update, delete, activate, or bind Profile A's instance."""
    headers_a = two_profiles_with_sessions["headers_a"]
    headers_b = two_profiles_with_sessions["headers_b"]

    # Profile A creates instance
    resp = await client.post(
        "/api/v1/characters/instances",
        json={"template_id": "warm-companion", "name": "Alpha Private Companion"},
        headers=headers_a,
    )
    assert resp.status_code == 201
    inst_a_id = resp.json()["id"]

    # Profile B attempts to GET Profile A's instance -> 404
    resp = await client.get(f"/api/v1/characters/instances/{inst_a_id}", headers=headers_b)
    assert resp.status_code == 404

    # Profile B attempts to PATCH Profile A's instance -> 404
    resp = await client.patch(
        f"/api/v1/characters/instances/{inst_a_id}",
        json={"name": "Hacked by Beta"},
        headers=headers_b,
    )
    assert resp.status_code == 404

    # Profile B attempts to DELETE Profile A's instance -> 404
    resp = await client.delete(f"/api/v1/characters/instances/{inst_a_id}", headers=headers_b)
    assert resp.status_code == 404

    # Profile B attempts to activate Profile A's instance -> 404
    resp = await client.put(
        "/api/v1/characters/active",
        json={"character_id": inst_a_id},
        headers=headers_b,
    )
    assert resp.status_code == 404

    # Profile B attempts to create a conversation with Profile A's instance -> 404
    resp = await client.post(
        "/api/v1/conversations",
        json={"title": "Beta Intrusion", "character_id": inst_a_id},
        headers=headers_b,
    )
    assert resp.status_code == 404

    # Profile B's instance list must remain empty
    resp = await client.get("/api/v1/characters/instances", headers=headers_b)
    assert resp.status_code == 200
    assert resp.json() == []

    # Verify Profile A's instance was never modified or compromised
    resp = await client.get(f"/api/v1/characters/instances/{inst_a_id}", headers=headers_a)
    assert resp.status_code == 200
    assert resp.json()["name"] == "Alpha Private Companion"
    assert resp.json()["status"] == "active"


@pytest.mark.asyncio
async def test_conversation_character_resolution_modes(
    client: AsyncClient,
    two_profiles_with_sessions: dict,
):
    """Test conversation creation with omitted, explicit neutral, and active instance selection."""
    headers = two_profiles_with_sessions["headers_a"]

    # 1. When neutral is active, omitted character_id resolves to 'default' and null instance
    resp = await client.post("/api/v1/conversations", json={"title": "Omitted Neutral Chat"}, headers=headers)
    assert resp.status_code == 201
    c1 = resp.json()
    assert c1["character_id"] == "default"
    assert c1["character_instance_id"] is None

    # 2. Create and activate an instance
    resp = await client.post(
        "/api/v1/characters/instances",
        json={"template_id": "warm-companion", "name": "Active Warm"},
        headers=headers,
    )
    assert resp.status_code == 201
    inst_id = resp.json()["id"]
    await client.put("/api/v1/characters/active", json={"character_id": inst_id}, headers=headers)

    # 3. Now omitted character_id binds to active instance
    resp = await client.post("/api/v1/conversations", json={"title": "Omitted Active Instance Chat"}, headers=headers)
    assert resp.status_code == 201
    c2 = resp.json()
    assert c2["character_id"] == inst_id
    assert c2["character_instance_id"] == inst_id

    # 4. Explicit 'default' still selects Neutral Assistant even when instance is active
    resp = await client.post(
        "/api/v1/conversations",
        json={"title": "Explicit Default Chat", "character_id": "default"},
        headers=headers,
    )
    assert resp.status_code == 201
    c3 = resp.json()
    assert c3["character_id"] == "default"
    assert c3["character_instance_id"] is None

    # 5. Explicit 'neutral-assistant' selects Neutral Assistant
    resp = await client.post(
        "/api/v1/conversations",
        json={"title": "Explicit Neutral Chat", "character_id": "neutral-assistant"},
        headers=headers,
    )
    assert resp.status_code == 201
    c4 = resp.json()
    assert c4["character_id"] == "neutral-assistant"
    assert c4["character_instance_id"] is None

    # 6. Explicit instance ID binds instance directly
    resp = await client.post(
        "/api/v1/conversations",
        json={"title": "Explicit Instance Chat", "character_id": inst_id},
        headers=headers,
    )
    assert resp.status_code == 201
    c5 = resp.json()
    assert c5["character_id"] == inst_id
    assert c5["character_instance_id"] == inst_id


@pytest.mark.asyncio
async def test_legacy_placeholder_listing_and_protection(
    client: AsyncClient,
    two_profiles_with_sessions: dict,
    test_session: AsyncSession,
):
    """Test Correction 3: Legacy placeholder listing API, cross-profile isolation, and immutability guards."""
    headers_a = two_profiles_with_sessions["headers_a"]
    headers_b = two_profiles_with_sessions["headers_b"]
    prof_a_id = two_profiles_with_sessions["profile_a"].id
    prof_b_id = two_profiles_with_sessions["profile_b"].id

    # 1. Seed legacy placeholder instances directly into DB for Profile A and Profile B
    legacy_a_id = f"legacy-placeholder-a-{uuid.uuid4().hex[:8]}"
    legacy_b_id = f"legacy-placeholder-b-{uuid.uuid4().hex[:8]}"

    inst_a = CharacterInstance(
        id=legacy_a_id,
        profile_id=prof_a_id,
        is_legacy_placeholder=True,
        legacy_character_id="legacy-char-a",
        template_id=None,
        source_template_version=None,
        name="legacy-char-a",
        summary="Legacy conversation character placeholder",
        lore="",
        system_prompt="",
        avatar_asset="default_avatar",
        preset_id=None,
        status="archived",
        is_deleted=False,
    )
    inst_b = CharacterInstance(
        id=legacy_b_id,
        profile_id=prof_b_id,
        is_legacy_placeholder=True,
        legacy_character_id="legacy-char-b",
        template_id=None,
        source_template_version=None,
        name="legacy-char-b",
        summary="Legacy conversation character placeholder",
        lore="",
        system_prompt="",
        avatar_asset="default_avatar",
        preset_id=None,
        status="archived",
        is_deleted=False,
    )
    test_session.add_all([inst_a, inst_b])
    await test_session.commit()

    # 2. Default GET /instances excludes legacy placeholders
    resp = await client.get("/api/v1/characters/instances", headers=headers_a)
    assert resp.status_code == 200
    ids = [i["id"] for i in resp.json()]
    assert legacy_a_id not in ids

    # 3. Explicit include_legacy=true includes Profile A's legacy placeholder
    resp = await client.get("/api/v1/characters/instances?include_legacy=true", headers=headers_a)
    assert resp.status_code == 200
    ids_a = [i["id"] for i in resp.json()]
    assert legacy_a_id in ids_a
    # Cross-Profile records remain strictly inaccessible
    assert legacy_b_id not in ids_a

    # Profile B with include_legacy=true only sees Profile B's legacy placeholder
    resp = await client.get("/api/v1/characters/instances?include_legacy=true", headers=headers_b)
    assert resp.status_code == 200
    ids_b = [i["id"] for i in resp.json()]
    assert legacy_b_id in ids_b
    assert legacy_a_id not in ids_b

    # 4. Legacy placeholders remain non-editable (PATCH returns 400)
    resp = await client.patch(
        f"/api/v1/characters/instances/{legacy_a_id}",
        json={"name": "Attempted Edit"},
        headers=headers_a,
    )
    assert resp.status_code == 400
    assert "Cannot modify a legacy conversation placeholder" in resp.text

    # 5. Legacy placeholders cannot become active Characters (PUT /active returns 400)
    resp = await client.put(
        "/api/v1/characters/active",
        json={"character_id": legacy_a_id},
        headers=headers_a,
    )
    assert resp.status_code == 400
    assert "Cannot select a legacy conversation placeholder as active character" in resp.text

    # 6. Legacy placeholders cannot be deleted via DELETE /instances/{id} (returns 400)
    resp = await client.delete(
        f"/api/v1/characters/instances/{legacy_a_id}",
        headers=headers_a,
    )
    assert resp.status_code == 400
    assert "Cannot delete a legacy conversation placeholder" in resp.text

    # 7. Legacy placeholders cannot start new conversations (returns 400)
    resp = await client.post(
        "/api/v1/conversations",
        json={"title": "New Chat", "character_id": legacy_a_id},
        headers=headers_a,
    )
    assert resp.status_code == 400
    assert "Cannot start a new conversation with a legacy conversation placeholder" in resp.text
