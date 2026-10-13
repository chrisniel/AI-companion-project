"""Tests for explicit Profile ownership and legacy owner shadow metadata (PC-IDENTITY-002)."""

import pytest
from sqlalchemy.exc import IntegrityError

from app.models.attachment import Attachment
from app.models.conversation import Conversation
from app.models.memory import Memory
from app.models.message import Message
from app.models.task import Task


def test_models_have_both_owner_id_and_profile_id():
    """Verify all 5 personal entity models have both owner_id and profile_id."""
    models = [Conversation, Message, Memory, Task, Attachment]
    for model_cls in models:
        assert hasattr(model_cls, "owner_id"), f"{model_cls.__name__} missing owner_id"
        assert hasattr(model_cls, "profile_id"), f"{model_cls.__name__} missing profile_id"


def test_instantiated_models_default_owner_to_local_user():
    """owner_id stays populated at instantiation for legacy compatibility."""
    assert Conversation(title="Test Chat").owner_id == "local_user"
    assert Task(title="Test Task").owner_id == "local_user"
    assert Memory(content="Test Memory").owner_id == "local_user"


async def test_new_records_persist_explicit_profile_ownership(test_session, profile_id):
    """Explicit ownership persists on all five models while owner_id stays shadow metadata."""
    conv = Conversation(title="Test Chat", profile_id=profile_id)
    test_session.add(conv)
    await test_session.flush()
    task = Task(title="Test Task", profile_id=profile_id)
    mem = Memory(content="Test Memory", profile_id=profile_id)
    msg = Message(conversation_id=conv.id, sender="user", content="Hello", sequence_no=1, profile_id=profile_id)
    att = Attachment(
        conversation_id=conv.id,
        profile_id=profile_id,
        filename_display="img.png",
        storage_filename="img_1.png",
        storage_path="/path/img_1.png",
        mime_type="image/png",
        size_bytes=100,
    )
    test_session.add_all([task, mem, msg, att])
    await test_session.commit()

    for obj in (conv, task, mem, msg, att):
        await test_session.refresh(obj)
        assert obj.profile_id == profile_id, type(obj).__name__
        assert obj.owner_id == "local_user"


async def test_legacy_owner_metadata_cannot_supply_missing_profile(test_session, profile_id):
    """Even with a seeded Profile and legacy owner, omitted ownership fails closed."""
    test_session.add(Conversation(title="Unowned", owner_id="local_user"))
    with pytest.raises(IntegrityError, match="NOT NULL constraint failed: conversations.profile_id"):
        await test_session.flush()
    await test_session.rollback()
