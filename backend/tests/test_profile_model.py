"""Tests for Profile ORM entity with stable UUID identity (PC-IDENTITY-001)."""

from app.models.profile import Profile, DEFAULT_PROFILE_ID


def test_profile_orm_attributes_and_defaults():
    """Verify Profile attributes, defaults, and stable DEFAULT_PROFILE_ID."""
    assert DEFAULT_PROFILE_ID == "00000000-0000-4000-8000-000000000001"

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
    profile = Profile(id=DEFAULT_PROFILE_ID, name="Default Profile", is_default=True)
    repr_str = repr(profile)
    assert "Profile" in repr_str
    assert DEFAULT_PROFILE_ID in repr_str
    assert "Default Profile" in repr_str
