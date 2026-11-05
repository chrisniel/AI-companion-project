"""Tests for M2 Batch C Profile Administration (POST/PATCH profiles and catalog)."""

import uuid
import pytest
from sqlalchemy import select

from app.models.profile import Profile
from app.models.conversation import Conversation
from app.models.message import Message
from app.models.memory import Memory
from app.models.task import Task

ADMIN = {"X-Host-Admin-Secret": "test-host-admin-independent-credential"}
BROWSER = {"Origin": "http://localhost:5173", "X-Companion-Bootstrap": "1"}


@pytest.fixture
def host_authority(monkeypatch):
    from app.core import host_admin
    monkeypatch.setattr(host_admin, "read_host_admin_secret", lambda: ADMIN["X-Host-Admin-Secret"])
    return ADMIN


async def default_profile(db):
    return (await db.execute(select(Profile).where(Profile.is_default.is_(True)))).scalar_one()


@pytest.mark.asyncio
async def test_create_profile_success(client, test_session, host_authority):
    response = await client.post(
        "/api/v1/profiles",
        headers=host_authority,
        json={"name": "Work Space"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Work Space"
    assert data["is_default"] is False
    assert data["status"] == "active"
    assert data["pin_protected"] is False
    assert uuid.UUID(data["id"])

    # Verify persisted in SQLite
    profile = await test_session.get(Profile, data["id"])
    assert profile is not None
    assert profile.name == "Work Space"
    assert profile.is_default is False
    assert profile.active_character_instance_id is None


@pytest.mark.asyncio
async def test_create_profile_trims_whitespace(client, host_authority):
    response = await client.post(
        "/api/v1/profiles",
        headers=host_authority,
        json={"name": "  Trimmed Name  "},
    )
    assert response.status_code == 201
    assert response.json()["name"] == "Trimmed Name"


@pytest.mark.asyncio
@pytest.mark.parametrize("invalid_name", [
    "",
    "   ",
    "A" * 33,
    "Line\nBreak",
    "Tab\tChar",
    "Null\x00Byte",
])
async def test_create_profile_name_validation(client, host_authority, invalid_name):
    response = await client.post(
        "/api/v1/profiles",
        headers=host_authority,
        json={"name": invalid_name},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_profile_rejects_duplicate_name_case_insensitive(client, host_authority):
    # Default Profile already exists in test DB
    response = await client.post(
        "/api/v1/profiles",
        headers=host_authority,
        json={"name": "default profile"},
    )
    assert response.status_code == 409
    error_msg = response.json().get("error", {}).get("message", "")
    assert "already exists" in error_msg

    # Create new profile, then attempt case variant
    r1 = await client.post(
        "/api/v1/profiles",
        headers=host_authority,
        json={"name": "Project Alpha"},
    )
    assert r1.status_code == 201

    r2 = await client.post(
        "/api/v1/profiles",
        headers=host_authority,
        json={"name": "PROJECT ALPHA"},
    )
    assert r2.status_code == 409


@pytest.mark.asyncio
async def test_create_profile_requires_host_admin(client, pairing_headers, auth_headers):
    payload = {"name": "Unauthorized"}
    # No headers
    assert (await client.post("/api/v1/profiles", json=payload)).status_code in (401, 403)
    # Pairing header
    assert (await client.post("/api/v1/profiles", headers=pairing_headers, json=payload)).status_code in (401, 403)
    # Profile session header
    assert (await client.post("/api/v1/profiles", headers=auth_headers, json=payload)).status_code in (401, 403)
    # Browser Origin
    assert (await client.post("/api/v1/profiles", headers={**ADMIN, **BROWSER}, json=payload)).status_code == 403


@pytest.mark.asyncio
async def test_rename_profile_success(client, test_session, host_authority):
    default = await default_profile(test_session)
    orig_id = default.id

    response = await client.patch(
        f"/api/v1/profiles/{orig_id}",
        headers=host_authority,
        json={"name": "Personal"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == orig_id
    assert data["name"] == "Personal"
    assert data["is_default"] is True

    # Verify persisted in SQLite
    await test_session.refresh(default)
    assert default.name == "Personal"
    assert default.id == orig_id


@pytest.mark.asyncio
async def test_rename_profile_case_only_self_rename(client, host_authority):
    r1 = await client.post("/api/v1/profiles", headers=host_authority, json={"name": "My Space"})
    assert r1.status_code == 201
    profile_id = r1.json()["id"]

    # Case-only rename of same profile should succeed (not 409)
    r2 = await client.patch(f"/api/v1/profiles/{profile_id}", headers=host_authority, json={"name": "my space"})
    assert r2.status_code == 200
    assert r2.json()["name"] == "my space"


@pytest.mark.asyncio
async def test_rename_profile_rejects_duplicate_active_name(client, host_authority):
    r1 = await client.post("/api/v1/profiles", headers=host_authority, json={"name": "Beta"})
    r2 = await client.post("/api/v1/profiles", headers=host_authority, json={"name": "Gamma"})
    assert r1.status_code == 201 and r2.status_code == 201

    # Attempting to rename Gamma to beta
    response = await client.patch(f"/api/v1/profiles/{r2.json()['id']}", headers=host_authority, json={"name": "BETA"})
    assert response.status_code == 409
    error_msg = response.json().get("error", {}).get("message", "")
    assert "already exists" in error_msg


@pytest.mark.asyncio
@pytest.mark.parametrize("invalid_name", ["", "   ", "X" * 33, "Hello\nWorld"])
async def test_rename_profile_name_validation(client, test_session, host_authority, invalid_name):
    default = await default_profile(test_session)
    response = await client.patch(
        f"/api/v1/profiles/{default.id}",
        headers=host_authority,
        json={"name": invalid_name},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_rename_profile_not_found(client, host_authority):
    fake_id = str(uuid.uuid4())
    response = await client.patch(
        f"/api/v1/profiles/{fake_id}",
        headers=host_authority,
        json={"name": "Ghost"},
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_rename_profile_requires_host_admin(client, test_session, pairing_headers, auth_headers):
    default = await default_profile(test_session)
    payload = {"name": "No Access"}
    assert (await client.patch(f"/api/v1/profiles/{default.id}", json=payload)).status_code in (401, 403)
    assert (await client.patch(f"/api/v1/profiles/{default.id}", headers=pairing_headers, json=payload)).status_code in (401, 403)
    assert (await client.patch(f"/api/v1/profiles/{default.id}", headers=auth_headers, json=payload)).status_code in (401, 403)
    assert (await client.patch(f"/api/v1/profiles/{default.id}", headers={**ADMIN, **BROWSER}, json=payload)).status_code == 403


@pytest.mark.asyncio
async def test_rename_preserves_associated_records_and_session(client, test_session, host_authority, auth_headers, profile_session):
    default = await default_profile(test_session)

    # Create conversation, message, memory, task belonging to this profile
    conv = Conversation(title="Active Chat", profile_id=default.id, character_id="default")
    test_session.add(conv)
    await test_session.flush()

    msg = Message(conversation_id=conv.id, profile_id=default.id, sender="user", content="Hello", sequence_no=1)
    mem = Memory(content="Remember this", profile_id=default.id, category="fact")
    task = Task(title="Important task", profile_id=default.id)
    test_session.add_all([msg, mem, task])
    await test_session.commit()

    # Rename profile
    rename_resp = await client.patch(
        f"/api/v1/profiles/{default.id}",
        headers=host_authority,
        json={"name": "Renamed Personal"},
    )
    assert rename_resp.status_code == 200

    # Verify session remains valid
    me_resp = await client.get("/api/v1/auth/session/me", headers=auth_headers)
    assert me_resp.status_code == 200
    assert me_resp.json()["name"] == "Renamed Personal"

    # Verify owned entities still resolve under this session
    conv_resp = await client.get("/api/v1/conversations", headers=auth_headers)
    assert conv_resp.status_code == 200
    items = conv_resp.json()["items"]
    assert any(c["id"] == conv.id for c in items)


@pytest.mark.asyncio
async def test_catalog_deterministic_ordering(client, host_authority):
    # Create multiple profiles
    await client.post("/api/v1/profiles", headers=host_authority, json={"name": "Zebra"})
    await client.post("/api/v1/profiles", headers=host_authority, json={"name": "Apple"})

    response = await client.get("/api/v1/profiles", headers=host_authority)
    assert response.status_code == 200
    catalog = response.json()
    assert len(catalog) >= 3
    # First is the default profile (is_default == True)
    assert catalog[0]["is_default"] is True
    # Subsequent are non-default ordered by created_at asc
    assert catalog[1]["name"] == "Zebra"
    assert catalog[2]["name"] == "Apple"


@pytest.mark.asyncio
async def test_pin_protected_profile_remains_fail_closed(client, test_session, host_authority):
    # Create profile and manually set pin_hash in DB to simulate pre-existing PIN
    default = await default_profile(test_session)
    default.pin_hash = "legacy_or_future_pin_hash"
    await test_session.commit()

    response = await client.post(
        "/api/v1/auth/bootstrap/ticket",
        headers=host_authority,
        json={"profile_id": default.id},
    )
    assert response.status_code == 403
    error_msg = response.json().get("error", {}).get("message", "")
    assert "Profile unlock challenge is not available" in error_msg
