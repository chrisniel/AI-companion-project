"""Tests for Profile ORM entity with stable per-installation UUID identity (PC-IDENTITY-001)."""

import uuid

from app.models.profile import Profile


def test_profile_orm_attributes_and_defaults():
    """Verify Profile attributes and defaults."""
    profile = Profile(name="Default Profile", is_default=True)
    assert profile.name == "Default Profile"
    assert profile.is_default is True
    assert profile.status == "active"
    assert profile.pin_hash is None
    assert profile.avatar_url is None
    assert profile.deleted_at is None
    assert profile.purge_after is None
    assert profile.is_deleted is False


def test_profile_repr():
    """Verify Profile repr contains id and name."""
    profile_id = str(uuid.uuid4())
    profile = Profile(id=profile_id, name="Default Profile", is_default=True)
    repr_str = repr(profile)
    assert "Profile" in repr_str
    assert profile_id in repr_str
    assert "Default Profile" in repr_str
