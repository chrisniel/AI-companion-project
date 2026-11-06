"""Tests for profile memory extraction toggle."""

import pytest
from sqlalchemy import select

from app.models.profile import Profile


@pytest.mark.asyncio
async def test_profile_memory_extraction_toggle_default_and_patch(client, test_session, host_admin_headers):
    """Verify default is True and patch updates memory_extraction_enabled with host authority."""
    profile = (await test_session.execute(select(Profile).where(Profile.is_default == True))).scalar_one()
    assert profile.memory_extraction_enabled is True

    # Toggle to False with host authority
    res = await client.patch(
        f"/api/v1/profiles/{profile.id}",
        headers=host_admin_headers,
        json={"memory_extraction_enabled": False},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["memory_extraction_enabled"] is False

    # Verify DB updated
    await test_session.refresh(profile)
    assert profile.memory_extraction_enabled is False

    # Toggle back to True
    res2 = await client.patch(
        f"/api/v1/profiles/{profile.id}",
        headers=host_admin_headers,
        json={"memory_extraction_enabled": True},
    )
    assert res2.status_code == 200
    assert res2.json()["memory_extraction_enabled"] is True


@pytest.mark.asyncio
async def test_profile_memory_extraction_toggle_requires_host_admin(client, test_session, auth_headers):
    """Verify non-host-admin cannot update memory_extraction_enabled."""
    profile = (await test_session.execute(select(Profile).where(Profile.is_default == True))).scalar_one()
    res = await client.patch(
        f"/api/v1/profiles/{profile.id}",
        headers=auth_headers,
        json={"memory_extraction_enabled": False},
    )
    assert res.status_code in (401, 403)
