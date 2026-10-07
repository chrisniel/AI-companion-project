"""B2 regressions through actual providers, callers and lifecycle operations."""

import asyncio
import json
import threading

import httpx
import pytest
from sqlalchemy import event
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import settings
from app.models.conversation import Conversation
from app.models.message import Message
from app.schemas.llm import ChatMessage
from app.services.assistant.orchestrator import _get_lock, orchestrate_chat_stream, prepare_turn
from app.services.llm import llama_cpp
from app.services.llm.manager import llm_manager
from app.services.llm.runtime_state import LLMRuntimeState


TOKEN = 'data: {"choices":[{"delta":{"content":"Partial"},"finish_reason":null}]}\n\n'
STOP = 'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n'
DETAIL = "companion_sec_synthetic_provider_secret_1234567890 X:/synthetic-private/model"
ERROR = "event: error\ndata: " + json.dumps({"error": {"message": DETAIL}}) + "\n\n"
MESSAGES = [ChatMessage(role="user", content="Hello")]


@pytest.fixture
def server_provider(monkeypatch, tmp_path):
    """Mock only the external HTTP transport/model inventory, not provider logic."""
    real_client = httpx.AsyncClient
    provider = llama_cpp.LlamaCppProvider()
    provider._server_is_active = True
    provider._active_model_name = "synthetic-model"
    provider._runtime_state = LLMRuntimeState.MODEL_READY
    monkeypatch.setattr(settings, "MODELS_DIR", tmp_path / "models")
    monkeypatch.setattr(llama_cpp, "build_model_list", lambda: [])
    router = {"loaded": True, "completion": lambda request: httpx.Response(200, text=TOKEN + STOP)}

    def handle(request):
        if request.url.path.endswith("/chat/completions"):
            return router["completion"](request)
        if request.url.path == "/health":
            return httpx.Response(200, json={"status": "ok"})
        if request.url.path == "/models/unload":
            router["loaded"] = False
            return httpx.Response(200, json={})
        if request.url.path == "/models":
            return httpx.Response(200, json={"data": [{
                "id": "synthetic-model", "status": {"value": "loaded" if router["loaded"] else "unloaded"},
            }]})
        raise AssertionError("Unexpected external request")

    monkeypatch.setattr(llama_cpp.httpx, "AsyncClient", lambda **kw: real_client(
        **kw, transport=httpx.MockTransport(handle),
    ))
    llm_manager.set_provider(provider)
    return provider, router


CASES = [
    pytest.param(503, DETAIL, False, "", id="http-503"),
    pytest.param(200, ERROR, False, "", id="sse-error"),
    pytest.param(200, TOKEN + ERROR, False, "Partial", id="partial-then-error"),
    pytest.param(200, TOKEN + STOP, True, "Partial", id="success"),
    pytest.param(200, STOP, True, "", id="successful-empty"),
    pytest.param(200, 'data: {"choices": BROKEN}\n\n', False, "", id="malformed-json"),
    pytest.param(200, 'data: {"choices":[{"delta":{},"finish_reason":42}]}\n\n', False, "", id="malformed-terminal"),
    pytest.param(200, TOKEN, False, "Partial", id="truncated-stream"),
    pytest.param(200, 'data: {"error":{"message":"' + DETAIL + '"}}\n\n', False, "", id="data-error"),
]


@pytest.mark.asyncio
@pytest.mark.parametrize("http_status,body,success,partial", CASES)
async def test_adapter_to_assistant_terminal_and_persistence(server_provider, test_session, http_status, body, success, partial):
    provider, router = server_provider
    router["completion"] = lambda request: httpx.Response(http_status, text=body)
    conversation = Conversation(id="b2-conversation", owner_id="test-owner", title="Boundary")
    test_session.add(conversation)
    await test_session.commit()
    lock = _get_lock(conversation.id)
    await lock.acquire()
    prepared = await prepare_turn(db=test_session, conversation_id=conversation.id, owner_id="test-owner", user_text="Hello")
    assistant_id = prepared.assistant_message.id
    chunks = [chunk async for chunk in orchestrate_chat_stream(
        db=test_session, conversation_id=conversation.id, user_text="Hello", owner_id="test-owner",
        prepared_turn=prepared, conversation_lock=lock,
    )]
    wire = "".join(chunks)
    test_session.expire_all()
    message = await test_session.get(Message, assistant_id)
    assert message.status == ("completed" if success else "failed")
    assert message.content == partial
    assert ('"type": "done"' in wire) is success
    assert ("data: [DONE]" in wire) is success
    assert ('"type": "error"' in wire) is (not success)
    assert DETAIL not in wire and "synthetic_provider_secret" not in wire
    assert not lock.locked()
    assert not (await provider.get_status()).generation_active


@pytest.mark.asyncio
@pytest.mark.parametrize("http_status,body,success,partial", CASES)
async def test_adapter_to_direct_endpoint_terminal(server_provider, client, auth_headers, http_status, body, success, partial):
    _, router = server_provider
    router["completion"] = lambda request: httpx.Response(http_status, text=body)
    response = await client.post("/api/v1/chat/completions", headers=auth_headers, json={
        "messages": [{"role": "user", "content": "Hello"}], "stream": True,
    })
    assert response.status_code == 200
    wire = response.text
    frames = [json.loads(line[6:]) for line in wire.splitlines() if line.startswith("data: ") and line != "data: [DONE]"]
    stops = [frame for frame in frames if any(choice.get("finish_reason") == "stop" for choice in frame.get("choices", []))]
    assert bool(stops) is success
    assert ("data: [DONE]" in wire) is success
    assert any("error" in frame for frame in frames) is (not success)
    content = "".join(choice.get("delta", {}).get("content") or "" for frame in frames for choice in frame.get("choices", []))
    assert content == partial
    assert DETAIL not in wire and "synthetic_provider_secret" not in wire


@pytest.mark.asyncio
async def test_successful_inference_with_failed_commit_never_emits_done(server_provider, test_session):
    conversation = Conversation(id="b2-commit-failure", owner_id="test-owner", title="Boundary")
    test_session.add(conversation)
    await test_session.commit()
    lock = _get_lock(conversation.id)
    await lock.acquire()
    prepared = await prepare_turn(db=test_session, conversation_id=conversation.id, owner_id="test-owner", user_text="Hello")
    assistant_id = prepared.assistant_message.id

    def fail_completion_commit(session):
        raise SQLAlchemyError("Synthetic completion commit failure")

    # Fail the actual request-session commit; terminal recovery uses its real,
    # separate session. Do not replace the orchestrator or persistence function.
    event.listen(test_session.sync_session, "before_commit", fail_completion_commit)
    try:
        wire = "".join([chunk async for chunk in orchestrate_chat_stream(
            db=test_session, conversation_id=conversation.id, user_text="Hello", owner_id="test-owner",
            prepared_turn=prepared, conversation_lock=lock,
        )])
    finally:
        event.remove(test_session.sync_session, "before_commit", fail_completion_commit)
    test_session.expire_all()
    message = await test_session.get(Message, assistant_id)
    assert message.status == "failed" and message.content == "Partial"
    assert '"type": "error"' in wire
    assert '"type": "done"' not in wire and "data: [DONE]" not in wire
    assert not lock.locked()


class ControlledStream(httpx.AsyncByteStream):
    def __init__(self, fail=False):
        self.release = asyncio.Event()
        self.token_seen = asyncio.Event()
        self.fail = fail

    async def __aiter__(self):
        yield TOKEN.encode()
        await self.release.wait()
        yield (ERROR if self.fail else STOP).encode()


async def consume(provider, stream):
    tokens = []
    async for token in provider.generate_stream(MESSAGES):
        tokens.append(token)
        stream.token_seen.set()
    return tokens


@pytest.mark.asyncio
async def test_assistant_close_releases_only_its_provider_operation(server_provider, test_session):
    provider, router = server_provider
    streams = [ControlledStream(), ControlledStream()]
    responses = iter(streams)
    router["completion"] = lambda request: httpx.Response(200, stream=next(responses))
    conversation = Conversation(id="b2-close-overlap", owner_id="test-owner", title="Boundary")
    test_session.add(conversation)
    await test_session.commit()
    lock = _get_lock(conversation.id)
    await lock.acquire()
    prepared = await prepare_turn(db=test_session, conversation_id=conversation.id, owner_id="test-owner", user_text="Hello")
    assistant_id = prepared.assistant_message.id
    assistant = orchestrate_chat_stream(
        db=test_session, conversation_id=conversation.id, user_text="Hello", owner_id="test-owner",
        prepared_turn=prepared, conversation_lock=lock,
    )
    other = None
    try:
        assert "Partial" in await anext(assistant)
        other = asyncio.create_task(consume(provider, streams[1]))
        await asyncio.wait_for(streams[1].token_seen.wait(), 3)
        assert provider.active_generation_count == 2
        await assistant.aclose()
        assert provider.active_generation_count == 1
        assert await provider.unload_model() is False
        assert not lock.locked()
        test_session.expire_all()
        message = await test_session.get(Message, assistant_id)
        assert message.status == "cancelled" and message.content == "Partial"
        streams[1].release.set()
        await other
        assert provider.active_generation_count == 0
    finally:
        for stream in streams:
            stream.release.set()
        await assistant.aclose()
        if other is not None:
            await asyncio.gather(other, return_exceptions=True)


@pytest.mark.asyncio
@pytest.mark.parametrize("first_fails", [False, True])
async def test_overlap_retains_ownership_and_lifecycle_guard(server_provider, first_fails):
    provider, router = server_provider
    streams = [ControlledStream(fail=first_fails), ControlledStream()]
    responses = iter(streams)
    router["completion"] = lambda request: httpx.Response(200, stream=next(responses))
    tasks = [asyncio.create_task(consume(provider, stream)) for stream in streams]
    try:
        for stream in streams:
            await asyncio.wait_for(stream.token_seen.wait(), 3)
        assert (await provider.get_status()).generation_active
        streams[0].release.set()
        if first_fails:
            with pytest.raises(RuntimeError):
                await tasks[0]
        else:
            await tasks[0]
        assert (await provider.get_status()).generation_active
        assert await provider.unload_model() is False
        assert await provider.set_profile("eco") is False
        assert provider.active_generation_count == 1
        streams[1].release.set()
        await tasks[1]
        assert provider.active_generation_count == 0
        assert not (await provider.get_status()).generation_active
        assert await provider.unload_model() is True
    finally:
        for stream in streams:
            stream.release.set()
        await asyncio.gather(*tasks, return_exceptions=True)


@pytest.mark.asyncio
@pytest.mark.parametrize("streaming", [False, True])
async def test_cancelled_awaiter_retains_actual_native_worker_ownership(streaming, monkeypatch, tmp_path):
    provider = llama_cpp.LlamaCppProvider()
    loop = asyncio.get_running_loop()
    entered = asyncio.Event()
    finish = threading.Event()
    stopped = threading.Event()
    monkeypatch.setattr(settings, "MODELS_DIR", tmp_path / "models")
    monkeypatch.setattr(llama_cpp, "build_model_list", lambda: [])

    class NativeModel:
        def create_chat_completion(self, **kwargs):
            def infer():
                loop.call_soon_threadsafe(entered.set)
                try:
                    if not finish.wait(5):
                        raise RuntimeError("Test worker completion not signalled")
                    return {"choices": [{"message": {"content": "Complete"}}]}
                finally:
                    stopped.set()

            if kwargs["stream"]:
                def tokens():
                    infer()
                    yield {"choices": [{"delta": {"content": "Complete"}}]}
                return tokens()
            return infer()

    provider._llm = NativeModel()
    provider._active_model_name = "synthetic-model"

    async def operation():
        if streaming:
            return [token async for token in provider.generate_stream(MESSAGES)]
        return await provider.generate(MESSAGES)

    task = asyncio.create_task(operation())
    try:
        await asyncio.wait_for(entered.wait(), 3)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
        assert not stopped.is_set()
        assert (await provider.get_status()).generation_active
        assert await provider.unload_model() is False
        assert await provider.set_profile("eco") is False
        finish.set()
        await provider.shutdown()
        assert stopped.is_set()
        assert provider.active_generation_count == 0
        assert not provider.is_loaded()
        assert await provider.unload_model() is True
    finally:
        finish.set()
        await asyncio.gather(task, return_exceptions=True)


@pytest.mark.asyncio
async def test_shutdown_drains_active_stream_without_falsifying_idle(server_provider):
    provider, router = server_provider
    stream = ControlledStream()
    router["completion"] = lambda request: httpx.Response(200, stream=stream)
    generation = asyncio.create_task(consume(provider, stream))
    shutdown = None
    try:
        await asyncio.wait_for(stream.token_seen.wait(), 3)
        began = asyncio.Event()

        async def stop():
            began.set()
            await provider.shutdown()

        shutdown = asyncio.create_task(stop())
        await began.wait()
        assert (await provider.get_status()).generation_active
        assert not shutdown.done()
        with pytest.raises(RuntimeError):
            await anext(provider.generate_stream(MESSAGES))
        stream.release.set()
        await generation
        await asyncio.wait_for(shutdown, 3)
        assert provider.active_generation_count == 0
        assert not provider.is_loaded()
    finally:
        stream.release.set()
        await asyncio.gather(generation, *([shutdown] if shutdown else []), return_exceptions=True)


@pytest.mark.asyncio
async def test_shutdown_deadline_retains_busy_ownership(server_provider, monkeypatch):
    provider, router = server_provider
    stream = ControlledStream()
    router["completion"] = lambda request: httpx.Response(200, stream=stream)
    generation = asyncio.create_task(consume(provider, stream))
    try:
        await asyncio.wait_for(stream.token_seen.wait(), 3)
        monkeypatch.setattr(provider, "_shutdown_drain_timeout", 0, raising=False)
        await provider.shutdown()
        assert (await provider.get_status()).generation_active
        assert provider.is_loaded()
        assert await provider.unload_model() is False
        stream.release.set()
        await generation
        assert provider.active_generation_count == 0
        assert await provider.unload_model() is True
    finally:
        stream.release.set()
        await asyncio.gather(generation, return_exceptions=True)
