"""Adversarial personal-data authorization tests with synthetic Profiles only."""

from datetime import timedelta
import asyncio
import hashlib
import uuid

import pytest
from fastapi import HTTPException
from sqlalchemy import select, update

from app.models.base import utc_now
from app.models.profile import Profile
from app.models.conversation import Conversation
from app.models.message import Message
from app.models.attachment import Attachment
from app.models.memory import Memory
from app.models.task import Task


@pytest.mark.anyio
@pytest.mark.parametrize("header", ["Authorization", "X-API-Key"])
@pytest.mark.parametrize("method,path", [
    ("GET", "conversations"), ("POST", "conversations"),
    ("GET", "conversations/guessed"), ("PATCH", "conversations/guessed"),
    ("DELETE", "conversations/guessed"), ("GET", "conversations/guessed/messages"),
    ("POST", "conversations/guessed/messages"), ("POST", "conversations/guessed/generate-title"),
    ("POST", "conversations/guessed/attachments"),
    ("GET", "conversations/guessed/attachments/guessed/preview"),
    ("DELETE", "conversations/guessed/attachments/guessed"),
    ("GET", "tasks"), ("POST", "tasks"), ("GET", "tasks/trash"),
    ("GET", "tasks/guessed"), ("PATCH", "tasks/guessed"), ("DELETE", "tasks/guessed"),
    ("POST", "tasks/guessed/restore"), ("DELETE", "tasks/guessed/permanent"),
    ("GET", "memories"), ("POST", "memories"),
    ("PATCH", "memories/guessed"), ("DELETE", "memories/guessed"),
])
async def test_pairing_key_has_no_personal_data_authority(client, test_token, method, path, header):
    credential = f"Bearer {test_token}" if header == "Authorization" else test_token
    response = await client.request(
        method, f"/api/v1/{path}", headers={header: credential},
    )
    assert response.status_code in (401, 403)


async def make_session(db, profile_id):
    from app.models.profile_session import ProfileSession

    profile = Profile(id=profile_id, name=profile_id)
    db.add(profile)
    session = ProfileSession(
        id=str(uuid.uuid4()), profile_id=profile_id,
        token_hash=hashlib.sha256(uuid.uuid4().bytes).hexdigest(),
        client_type="desktop", expires_at=utc_now() + timedelta(hours=1),
        last_active_at=utc_now(),
    )
    db.add(session)
    await db.commit()
    return session


@pytest.mark.anyio
async def test_foreign_profile_records_hidden_even_with_same_legacy_owner(client, test_session):
    from app.api.deps import get_current_profile_session
    from app.main import app

    a = await make_session(test_session, "profile-a")
    await make_session(test_session, "profile-b")
    app.dependency_overrides[get_current_profile_session] = lambda: a
    conv = Conversation(id="foreign-conv", profile_id="profile-b", title="Private B")
    task = Task(id="foreign-task", profile_id="profile-b", title="Private B")
    memory = Memory(id="foreign-memory", profile_id="profile-b", content="Private B", category="fact")
    test_session.add_all([conv, task, memory])
    await test_session.commit()
    for path in ("conversations", "tasks", "memories"):
        response = await client.get(f"/api/v1/{path}")
        assert response.status_code == 200
        assert response.json()["items"] == []
    for method, path, body in (
        ("GET", "conversations/foreign-conv", None),
        ("PATCH", "conversations/foreign-conv", {"title": "attack"}),
        ("DELETE", "conversations/foreign-conv", None),
        ("GET", "conversations/foreign-conv/messages", None),
        ("POST", "conversations/foreign-conv/messages", {"user_text": "attack"}),
        ("POST", "conversations/foreign-conv/generate-title", {}),
        ("GET", "tasks/foreign-task", None),
        ("PATCH", "tasks/foreign-task", {"title": "attack"}),
        ("DELETE", "tasks/foreign-task", None),
        ("POST", "tasks/foreign-task/restore", None),
        ("DELETE", "tasks/foreign-task/permanent", None),
        ("PATCH", "memories/foreign-memory", {"content": "attack"}),
        ("DELETE", "memories/foreign-memory", None),
    ):
        response = await client.request(method, f"/api/v1/{path}", json=body)
        assert response.status_code == 404, (method, path, response.text)
    await test_session.refresh(conv)
    await test_session.refresh(task)
    await test_session.refresh(memory)
    assert conv.title == task.title == memory.content == "Private B"
    assert not conv.is_deleted and not task.is_deleted and not memory.is_deleted


@pytest.mark.anyio
async def test_turn_service_rejects_foreign_parent(test_session):
    from app.services.assistant.orchestrator import prepare_turn

    a = await make_session(test_session, "profile-a")
    await make_session(test_session, "profile-b")
    test_session.add(Conversation(id="foreign-conv", profile_id="profile-b", title="Private"))
    await test_session.commit()
    with pytest.raises(HTTPException) as exc:
        await prepare_turn(test_session, conversation_id="foreign-conv", profile_session=a, user_text="attack")
    assert exc.value.status_code == 404
    assert list((await test_session.execute(select(Message))).scalars()) == []


@pytest.mark.anyio
async def test_fts_search_is_scoped_by_profile_and_rejects_revoked_context(test_session):
    from app.services.memory.retriever import search_relevant_memories
    from app.models.profile_session import ProfileSession

    a = await make_session(test_session, "profile-a")
    await make_session(test_session, "profile-b")
    test_session.add_all([
        Memory(id="a-mem", profile_id="profile-a", content="Unique mango recipe", category="fact"),
        Memory(id="b-mem", profile_id="profile-b", content="Unique mango secret", category="fact"),
    ])
    await test_session.commit()
    result = await search_relevant_memories(test_session, "mango OR secret", profile_session=a)
    assert [m.id for m in result] == ["a-mem"]
    await test_session.execute(update(ProfileSession).where(ProfileSession.id == a.id).values(revoked_at=utc_now()))
    await test_session.commit()
    with pytest.raises(HTTPException) as exc:
        await search_relevant_memories(test_session, "mango", profile_session=a)
    assert exc.value.status_code == 401


@pytest.mark.anyio
async def test_retention_requires_authority_and_cannot_purge_foreign_profile(test_session):
    from app.services.retention import purge_expired_trash

    a = await make_session(test_session, "profile-a")
    await make_session(test_session, "profile-b")
    test_session.add_all([
        Task(id="a-trash", profile_id="profile-a", title="A", is_deleted=True, deleted_at=utc_now()-timedelta(days=40)),
        Task(id="b-trash", profile_id="profile-b", title="B", is_deleted=True, deleted_at=utc_now()-timedelta(days=40)),
    ])
    await test_session.commit()
    with pytest.raises((TypeError, HTTPException)):
        await purge_expired_trash(test_session, authority="profile-b")
    with pytest.raises(TypeError):
        await purge_expired_trash(test_session)
    assert await purge_expired_trash(test_session, authority=a) == 1
    assert [t.id for t in (await test_session.execute(select(Task))).scalars()] == ["b-trash"]


@pytest.mark.anyio
@pytest.mark.parametrize("lifecycle", ["revoked", "expired", "inactive", "deleted"])
async def test_stream_stops_while_model_is_idle_and_never_saves_after_loss_of_authority(
    test_session, monkeypatch, lifecycle,
):
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from app.models.profile_session import ProfileSession
    from app.services.assistant.orchestrator import prepare_turn, orchestrate_chat_stream
    from app.services.llm.manager import get_llm_provider

    authority = await make_session(test_session, "stream-profile")
    test_session.add(Conversation(id="stream-conv", profile_id=authority.profile_id, title="Private"))
    await test_session.commit()
    prepared = await prepare_turn(test_session, conversation_id="stream-conv", profile_session=authority, user_text="Private request")
    assistant_id = prepared.assistant_message.id
    authority_id = authority.id
    profile_id = authority.profile_id
    entered = asyncio.Event()
    closed = asyncio.Event()

    async def slow_stream(*args, **kwargs):
        try:
            entered.set()
            await asyncio.sleep(10)
            yield "must never escape"
        finally:
            closed.set()

    monkeypatch.setattr(get_llm_provider(), "generate_stream", slow_stream)
    lock = asyncio.Lock()
    await lock.acquire()

    async def collect():
        return [chunk async for chunk in orchestrate_chat_stream(
            test_session, "stream-conv", "Private request", authority, prepared, lock,
        )]

    collecting = asyncio.create_task(collect())
    await asyncio.wait_for(entered.wait(), 2)
    factory = async_sessionmaker(test_session.bind, expire_on_commit=False)
    async with factory() as revoker:
        if lifecycle == "revoked":
            await revoker.execute(update(ProfileSession).where(ProfileSession.id == authority_id).values(revoked_at=utc_now()))
        elif lifecycle == "expired":
            await revoker.execute(update(ProfileSession).where(ProfileSession.id == authority_id).values(expires_at=utc_now()-timedelta(seconds=1)))
        elif lifecycle == "inactive":
            await revoker.execute(update(Profile).where(Profile.id == profile_id).values(status="inactive"))
        else:
            await revoker.execute(update(Profile).where(Profile.id == profile_id).values(is_deleted=True, deleted_at=utc_now()))
        await revoker.commit()
    assert await asyncio.wait_for(collecting, 2) == []
    assert closed.is_set() and not lock.locked()
    async with factory() as reader:
        assistant = await reader.get(Message, assistant_id)
        assert assistant.content == ""
        assert assistant.status == "streaming"


@pytest.mark.anyio
async def test_child_profile_must_match_parent_for_listing_and_claim(test_session, client):
    from app.api.deps import get_current_profile_session
    from app.main import app
    from app.services.attachment_service import claim_attachments_for_message

    a = await make_session(test_session, "profile-a")
    await make_session(test_session, "profile-b")
    app.dependency_overrides[get_current_profile_session] = lambda: a
    test_session.add_all([
        Conversation(id="a-parent", profile_id="profile-a", title="A"),
        Message(id="a-message", conversation_id="a-parent", profile_id="profile-a", sender="user", content="A", sequence_no=1),
        Message(id="b-child", conversation_id="a-parent", profile_id="profile-b", sender="user", content="secret", sequence_no=2),
        Attachment(id="b-attachment", profile_id="profile-b", conversation_id="a-parent", message_id="a-message", filename_display="private.png", storage_filename="private.png", storage_path="attachments/private.png", mime_type="image/png", size_bytes=10),
    ])
    await test_session.commit()
    result = await client.get("/api/v1/conversations/a-parent/messages")
    assert result.status_code == 200
    assert [m["id"] for m in result.json()["items"]] == ["a-message"]
    assert result.json()["items"][0]["attachments"] == []
    result = await client.get("/api/v1/conversations/a-parent")
    assert result.json()["message_count"] == 1
    for method, path in (("GET", "preview"), ("DELETE", "")):
        result = await client.request(method, f"/api/v1/conversations/a-parent/attachments/b-attachment" + ("/"+path if path else ""))
        assert result.status_code == 404
    with pytest.raises(HTTPException) as exc:
        await claim_attachments_for_message(test_session, ["b-attachment"], message_id="a-message", conversation_id="a-parent", profile_session=a)
    assert exc.value.status_code in (403, 404)


@pytest.mark.anyio
async def test_attachment_bound_to_foreign_message_is_hidden(test_session, client):
    from app.api.deps import get_current_profile_session
    from app.main import app

    a = await make_session(test_session, "profile-a")
    await make_session(test_session, "profile-b")
    app.dependency_overrides[get_current_profile_session] = lambda: a
    test_session.add_all([
        Conversation(id="a-parent", profile_id="profile-a", title="A"),
        Message(id="b-message", profile_id="profile-b", conversation_id="a-parent", sender="user", content="Private B", sequence_no=1),
        Attachment(id="own-attachment", profile_id="profile-a", conversation_id="a-parent", message_id="b-message", filename_display="private.png", storage_filename="private.png", storage_path="attachments/private.png", mime_type="image/png", size_bytes=10),
    ])
    await test_session.commit()
    response = await client.delete("/api/v1/conversations/a-parent/attachments/own-attachment")
    assert response.status_code == 404
    attachment = await test_session.get(Attachment, "own-attachment")
    assert not attachment.is_deleted


@pytest.mark.anyio
async def test_cancellation_after_revocation_does_not_save_previously_streamed_content(test_session, monkeypatch):
    from app.models.profile_session import ProfileSession
    from app.services.assistant.orchestrator import prepare_turn, orchestrate_chat_stream
    from app.services.llm.manager import get_llm_provider

    authority = await make_session(test_session, "stream-profile")
    test_session.add(Conversation(id="stream-conv", profile_id=authority.profile_id, title="Private"))
    await test_session.commit()
    prepared = await prepare_turn(test_session, conversation_id="stream-conv", profile_session=authority, user_text="Private request")
    assistant_id = prepared.assistant_message.id
    authority_id = authority.id

    async def partial(*args, **kwargs):
        yield "Previously authorized output"
        await asyncio.sleep(10)

    monkeypatch.setattr(get_llm_provider(), "generate_stream", partial)
    lock = asyncio.Lock()
    await lock.acquire()
    stream = orchestrate_chat_stream(test_session, "stream-conv", "Private request", authority, prepared, lock)
    assert "Previously authorized output" in await anext(stream)
    await test_session.execute(update(ProfileSession).where(ProfileSession.id == authority_id).values(revoked_at=utc_now()))
    await test_session.commit()
    await stream.aclose()
    assert not lock.locked()
    assistant = await test_session.get(Message, assistant_id, populate_existing=True)
    assert assistant.content == ""
    assert assistant.status == "streaming"


async def prepare_download(test_session):
    from app.api.v1.endpoints.attachments import preview_attachment
    from app.core.config import settings
    authority = await make_session(test_session, "download-profile")
    profile_id = authority.profile_id
    test_session.add(Conversation(id="download-conv", profile_id=profile_id, title="Private"))
    file_path = settings.ATTACHMENT_DIR / profile_id / "download-conv" / "private.png"
    file_path.parent.mkdir(parents=True, exist_ok=True)
    first_chunk = b"A" * 65536
    file_path.write_bytes(first_chunk + b"B" * 65536 + b"C" * 65536)
    test_session.add(Attachment(
        id="download-attachment", profile_id=profile_id, conversation_id="download-conv",
        filename_display="private image.png", storage_filename="private.png",
        storage_path=f"attachments/{profile_id}/download-conv/private.png",
        mime_type="image/png", size_bytes=196608,
    ))
    await test_session.commit()
    response = await preview_attachment("download-conv", "download-attachment", authority, test_session)
    assert response.headers["content-type"] == "image/png"
    assert response.headers["content-disposition"] == "attachment; filename*=utf-8''private%20image.png"
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["x-content-type-options"] == "nosniff"
    return authority, file_path, first_chunk, response


@pytest.mark.anyio
@pytest.mark.parametrize("lifecycle", ["revoked", "expired", "inactive", "deleted"])
async def test_paused_attachment_download_stops_after_authority_loss(test_session, lifecycle):
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from app.models.profile_session import ProfileSession

    authority, file_path, first_chunk, response = await prepare_download(test_session)
    authority_id, profile_id = authority.id, authority.profile_id
    paused = asyncio.Event()
    resume = asyncio.Event()
    emitted = []

    async def send(message):
        if message["type"] == "http.response.body" and message.get("body"):
            emitted.append(message["body"])
            if len(emitted) == 1:
                paused.set()
                await resume.wait()

    async def receive():
        return {"type": "http.disconnect"}

    scope = {"type": "http", "method": "GET", "path": "/preview", "headers": [], "asgi": {"spec_version": "2.4"}}
    downloading = asyncio.create_task(response(scope, receive, send))
    await asyncio.wait_for(paused.wait(), 2)
    factory = async_sessionmaker(test_session.bind, expire_on_commit=False)
    async with factory() as revoker:
        if lifecycle == "revoked":
            await revoker.execute(update(ProfileSession).where(ProfileSession.id == authority_id).values(revoked_at=utc_now()))
        elif lifecycle == "expired":
            await revoker.execute(update(ProfileSession).where(ProfileSession.id == authority_id).values(expires_at=utc_now()-timedelta(seconds=1)))
        elif lifecycle == "inactive":
            await revoker.execute(update(Profile).where(Profile.id == profile_id).values(status="inactive"))
        else:
            await revoker.execute(update(Profile).where(Profile.id == profile_id).values(is_deleted=True, deleted_at=utc_now()))
        await revoker.commit()
    resume.set()
    await asyncio.wait_for(downloading, 2)
    assert b"".join(emitted) == first_chunk
    # On Windows this also proves the response released its real download handle.
    file_path.unlink()


@pytest.mark.anyio
async def test_attachment_download_cancellation_closes_real_file(test_session):
    _, file_path, _, response = await prepare_download(test_session)
    paused = asyncio.Event()

    async def send(message):
        if message["type"] == "http.response.body" and message.get("body"):
            paused.set()
            await asyncio.Event().wait()

    async def receive():
        return {"type": "http.disconnect"}

    scope = {"type": "http", "method": "GET", "path": "/preview", "headers": [], "asgi": {"spec_version": "2.4"}}
    downloading = asyncio.create_task(response(scope, receive, send))
    await asyncio.wait_for(paused.wait(), 2)
    downloading.cancel()
    with pytest.raises(asyncio.CancelledError):
        await downloading
    file_path.unlink()
    assert await test_session.scalar(select(Attachment.id).where(Attachment.id == "download-attachment")) == "download-attachment"


@pytest.mark.anyio
async def test_attachment_download_checks_lifecycle_while_real_read_is_paused(test_session, monkeypatch):
    from pathlib import Path
    import threading
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from app.models.profile_session import ProfileSession

    authority, file_path, _, response = await prepare_download(test_session)
    authority_id = authority.id
    started, release = threading.Event(), threading.Event()
    real_open = Path.open
    opened_files = []

    class PausedFile:
        def __init__(self, handle):
            self.handle = handle

        def __enter__(self):
            return self

        def __exit__(self, *args):
            self.handle.close()

        def read(self, size):
            started.set()
            if not release.wait(5):
                raise TimeoutError("Synthetic read was not released")
            return self.handle.read(size)

    def open_file(path, *args, **kwargs):
        handle = real_open(path, *args, **kwargs)
        if path == file_path:
            opened_files.append(handle)
            return PausedFile(handle)
        return handle

    monkeypatch.setattr(Path, "open", open_file)
    emitted = []

    async def send(message):
        if message["type"] == "http.response.body" and message.get("body"):
            emitted.append(message["body"])

    async def receive():
        return {"type": "http.disconnect"}

    scope = {"type": "http", "method": "GET", "path": "/preview", "headers": [], "asgi": {"spec_version": "2.4"}}
    downloading = asyncio.create_task(response(scope, receive, send))
    try:
        assert await asyncio.to_thread(started.wait, 2)
        factory = async_sessionmaker(test_session.bind, expire_on_commit=False)
        async with factory() as revoker:
            await revoker.execute(update(ProfileSession).where(ProfileSession.id == authority_id).values(revoked_at=utc_now()))
            await revoker.commit()
        # Restore before releasing the read: only a check during the idle read
        # can observe the temporary loss of authority and terminate this stream.
        await asyncio.sleep(0.75)
        async with factory() as restorer:
            await restorer.execute(update(ProfileSession).where(ProfileSession.id == authority_id).values(revoked_at=None))
            await restorer.commit()
    finally:
        release.set()
        await asyncio.wait_for(downloading, 2)
    assert emitted == []
    assert opened_files and all(handle.closed for handle in opened_files)
    file_path.unlink()
