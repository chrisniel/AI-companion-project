"""Tests for ProfileMixin and backward-compatible OwnerMixin coexistence (PC-IDENTITY-001)."""

from app.models.attachment import Attachment
from app.models.base import DEFAULT_PROFILE_ID
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


def test_instantiated_models_default_to_default_profile():
    """Verify new model instances default to DEFAULT_PROFILE_ID and 'local_user' without NULLs."""
    conv = Conversation(title="Test Chat")
    assert conv.owner_id == "local_user"
    assert conv.profile_id == DEFAULT_PROFILE_ID

    task = Task(title="Test Task")
    assert task.owner_id == "local_user"
    assert task.profile_id == DEFAULT_PROFILE_ID

    mem = Memory(content="Test Memory")
    assert mem.owner_id == "local_user"
    assert mem.profile_id == DEFAULT_PROFILE_ID

    msg = Message(conversation_id="conv_1", sender="user", content="Hello", sequence_no=1)
    assert msg.owner_id == "local_user"
    assert msg.profile_id == DEFAULT_PROFILE_ID

    att = Attachment(
        conversation_id="conv_1",
        filename_display="img.png",
        storage_filename="img_1.png",
        storage_path="/path/img_1.png",
        mime_type="image/png",
        size_bytes=100,
    )
    assert att.owner_id == "local_user"
    assert att.profile_id == DEFAULT_PROFILE_ID
