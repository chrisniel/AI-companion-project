"""Tests for ProfileMixin and backward-compatible OwnerMixin coexistence (PC-IDENTITY-001)."""

from sqlalchemy import select

from app.models.attachment import Attachment
from app.models.conversation import Conversation
from app.models.memory import Memory
from app.models.message import Message
from app.models.profile import Profile
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


async def test_new_records_via_session_get_this_databases_default_profile(test_session):
    """Records created without profile_id are never NULL and follow this database's default."""
    default = (await test_session.execute(select(Profile).where(Profile.is_default.is_(True)))).scalar_one()

    conv = Conversation(title="Test Chat")
    test_session.add(conv)
    await test_session.flush()
    task = Task(title="Test Task")
    mem = Memory(content="Test Memory")
    msg = Message(conversation_id=conv.id, sender="user", content="Hello", sequence_no=1)
    att = Attachment(
        conversation_id=conv.id,
        filename_display="img.png",
        storage_filename="img_1.png",
        storage_path="/path/img_1.png",
        mime_type="image/png",
        size_bytes=100,
    )
    test_session.add_all([task, mem, msg, att])
    await test_session.commit()

    for obj in (conv, task, mem, msg, att):
        assert obj.profile_id == default.id, type(obj).__name__
        assert obj.owner_id == "local_user"
