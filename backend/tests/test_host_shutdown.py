"""Tests for Host Admin shutdown lifecycle, security barriers, quiescence, and admission control."""

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from httpx import ASGITransport, AsyncClient

from app.core.runtime_lifecycle import RuntimeLifecycleCoordinator, runtime_lifecycle
from app.main import app
from app.schemas.health import SystemShutdownRequest, SystemShutdownResponse
from app.services.llm.base import ProviderShutdownResult


@pytest.fixture(autouse=True)
def reset_lifecycle():
    """Reset runtime_lifecycle singleton before and after each test."""
    runtime_lifecycle.reset()
    yield
    runtime_lifecycle.reset()


@pytest.mark.asyncio
async def test_s1_valid_host_admin_shutdown(client: AsyncClient, host_admin_headers: dict):
    """S1: Valid loopback request with X-Host-Admin-Secret returns 202 Accepted."""
    response = await client.post(
        "/api/v1/system/shutdown",
        headers=host_admin_headers,
        json={"reason": "test_shutdown", "drain_timeout_seconds": 2.0},
    )
    assert response.status_code == 202
    data = response.json()
    assert data["status"] == "shutting_down"
    assert "pid" in data
    assert data["already_shutting_down"] is False


@pytest.mark.asyncio
async def test_s2_missing_or_invalid_secret(client: AsyncClient, host_admin_headers: dict):
    """S2: Missing, empty, or wrong X-Host-Admin-Secret returns 401/403."""
    # Missing secret
    res1 = await client.post("/api/v1/system/shutdown")
    assert res1.status_code in (401, 403)

    # Empty secret
    res2 = await client.post("/api/v1/system/shutdown", headers={"X-Host-Admin-Secret": ""})
    assert res2.status_code in (401, 403)

    # Invalid secret
    res3 = await client.post("/api/v1/system/shutdown", headers={"X-Host-Admin-Secret": "invalid_secret_token_1234567890"})
    assert res3.status_code in (401, 403)


@pytest.mark.asyncio
async def test_s3_profile_session_bearer_rejected(client: AsyncClient, auth_headers: dict):
    """S3: Profile Session bearer credential cannot elevate to Host Admin shutdown."""
    response = await client.post("/api/v1/system/shutdown", headers=auth_headers)
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_s4_paired_device_credentials_rejected(client: AsyncClient, pairing_headers: dict, api_key_headers: dict):
    """S4: Paired device credentials (Bearer companion_sec_ or X-API-Key) cannot elevate to shutdown."""
    res1 = await client.post("/api/v1/system/shutdown", headers=pairing_headers)
    assert res1.status_code in (401, 403)

    res2 = await client.post("/api/v1/system/shutdown", headers=api_key_headers)
    assert res2.status_code in (401, 403)


@pytest.mark.asyncio
async def test_s5_browser_headers_rejected(client: AsyncClient, host_admin_headers: dict):
    """S5: Requests with Origin or Sec-Fetch-Site are rejected even with valid secret."""
    # Origin header present
    headers_origin = {**host_admin_headers, "Origin": "http://localhost:3000"}
    res1 = await client.post("/api/v1/system/shutdown", headers=headers_origin)
    assert res1.status_code == 403

    # Sec-Fetch-Site header present
    headers_fetch = {**host_admin_headers, "Sec-Fetch-Site": "cross-site"}
    res2 = await client.post("/api/v1/system/shutdown", headers=headers_fetch)
    assert res2.status_code == 403


@pytest.mark.asyncio
async def test_s6_non_loopback_rejected(host_admin_headers: dict):
    """S6: Non-loopback transport or hostname is rejected."""
    # Non-loopback client IP
    transport = ASGITransport(app=app, client=("192.168.1.100", 54321))
    async with AsyncClient(transport=transport, base_url="http://127.0.0.1:8000") as remote_client:
        res = await remote_client.post("/api/v1/system/shutdown", headers=host_admin_headers)
        assert res.status_code == 403

    # Non-loopback Host header
    transport2 = ASGITransport(app=app, client=("127.0.0.1", 54321))
    async with AsyncClient(transport=transport2, base_url="http://evil.example.com") as evil_client:
        res2 = await evil_client.post("/api/v1/system/shutdown", headers=host_admin_headers)
        assert res2.status_code == 403


@pytest.mark.asyncio
async def test_s7_programmatic_server_registration_and_exit():
    """S7: Programmatic runtime_server registers uvicorn.Server and clean shutdown signals should_exit."""
    mock_server = MagicMock()
    mock_server.should_exit = False

    coord = RuntimeLifecycleCoordinator()
    coord.register_server(mock_server)
    assert coord._server is mock_server

    # Trigger clean shutdown sequence
    with patch("app.core.runtime_lifecycle.get_llm_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.signal_shutdown_immediately = MagicMock()
        mock_res = MagicMock()
        mock_res.completed_cleanly = True
        mock_res.lock_acquired = True
        mock_res.managed_llm_pid = None
        mock_res.managed_by_core = False
        mock_provider.shutdown = AsyncMock(return_value=mock_res)
        mock_get_provider.return_value = mock_provider

        await coord.initiate_shutdown(drain_timeout_seconds=0.5)
        # Await the background sequence
        if coord._shutdown_task:
            await coord._shutdown_task

        assert coord.shutdown_quiescence_status == "clean"
        assert mock_server.should_exit is True


@pytest.mark.asyncio
async def test_s8_repeat_shutdown_idempotent(client: AsyncClient, host_admin_headers: dict):
    """S8: Repeated / concurrent shutdown requests return 202 with already_shutting_down=True."""
    res1 = await client.post("/api/v1/system/shutdown", headers=host_admin_headers)
    assert res1.status_code == 202
    assert res1.json()["already_shutting_down"] is False

    res2 = await client.post("/api/v1/system/shutdown", headers=host_admin_headers)
    assert res2.status_code == 202
    assert res2.json()["already_shutting_down"] is True


@pytest.mark.asyncio
async def test_s9_asgi_mutation_admission_control(client: AsyncClient, host_admin_headers: dict, auth_headers: dict):
    """S9: Once is_shutting_down is True, mutating requests receive 503 RUNTIME_SHUTTING_DOWN."""
    # Initiate shutdown to put runtime in shutting_down mode
    await client.post("/api/v1/system/shutdown", headers=host_admin_headers)
    assert runtime_lifecycle.is_shutting_down is True

    # Mutating POST request should be rejected with 503
    resp = await client.post("/api/v1/conversations", headers=auth_headers, json={"title": "test"})
    assert resp.status_code == 503
    data = resp.json()
    assert data["error"]["code"] == "RUNTIME_SHUTTING_DOWN"

    # Public health check should also reflect 503
    health_resp = await client.get("/api/v1/health")
    assert health_resp.status_code == 503

    # System status check should remain accessible and report shutting_down
    status_resp = await client.get("/api/v1/system/status", headers=host_admin_headers)
    assert status_resp.status_code == 200
    status_data = status_resp.json()
    assert status_data["shutting_down"] is True


@pytest.mark.asyncio
async def test_s10_tracked_persistence_barrier():
    """S10: Tracked persistence task in _pending_persistence_tasks is awaited during quiescence."""
    coord = RuntimeLifecycleCoordinator()
    finished = False

    async def simulated_persistence():
        nonlocal finished
        await asyncio.sleep(0.1)
        finished = True

    task = coord.spawn_terminal_persistence_task(simulated_persistence())
    assert coord.has_active_database_work is True
    assert task in coord._pending_persistence_tasks

    quiescent = await coord.wait_for_database_quiescence(timeout=1.0)
    assert quiescent is True
    assert finished is True
    assert coord.has_active_database_work is False


@pytest.mark.asyncio
async def test_s11_persistence_drain_timeout_prevents_db_disposal():
    """S11: Incomplete persistence past deadline reports incomplete status and halts server exit."""
    coord = RuntimeLifecycleCoordinator()
    mock_server = MagicMock()
    mock_server.should_exit = False
    coord.register_server(mock_server)

    # Simulate task that never finishes within timeout
    async def infinite_persistence():
        await asyncio.sleep(10.0)

    task = coord.spawn_terminal_persistence_task(infinite_persistence())
    try:
        assert coord.has_active_database_work is True

        with patch("app.core.runtime_lifecycle.get_llm_provider") as mock_get_provider:
            mock_provider = MagicMock()
            mock_provider.signal_shutdown_immediately = MagicMock()
            mock_provider.shutdown = AsyncMock()
            mock_get_provider.return_value = mock_provider

            await coord.initiate_shutdown(drain_timeout_seconds=0.2)
            if coord._shutdown_task:
                await coord._shutdown_task

            # Status must be incomplete_db_quiescence_timeout
            assert coord.shutdown_quiescence_status == "incomplete_db_quiescence_timeout"
            # Server must NOT be signaled to exit
            assert mock_server.should_exit is False
            # Provider shutdown must NOT have been called while DB work remains
            mock_provider.shutdown.assert_not_called()
    finally:
        task.cancel()


@pytest.mark.anyio
async def test_streaming_response_maintains_admission_until_completion():
    """Verify that pure ASGI middleware maintains admission count for the full duration of a stream."""
    from app.main import RuntimeAdmissionASGIMiddleware
    from fastapi import FastAPI
    from fastapi.responses import StreamingResponse
    from app.core.runtime_lifecycle import runtime_lifecycle
    from httpx import AsyncClient, ASGITransport

    runtime_lifecycle.reset()
    stream_running = asyncio.Event()
    finish_stream = asyncio.Event()

    test_app = FastAPI()
    test_app.add_middleware(RuntimeAdmissionASGIMiddleware)

    @test_app.post("/test-stream")
    async def stream_endpoint():
        async def gen():
            stream_running.set()
            yield b"data: chunk\n\n"
            await finish_stream.wait()
            yield b"data: end\n\n"
        return StreamingResponse(gen(), media_type="text/event-stream")

    async with AsyncClient(transport=ASGITransport(app=test_app), base_url="http://test") as client:
        assert runtime_lifecycle._active_asgi_mutations == 0

        # Start request in background
        stream_task = asyncio.create_task(client.post("/test-stream"))

        # Wait until generator has started inside ASGI pipeline
        await asyncio.wait_for(stream_running.wait(), timeout=2.0)

        # While stream is running, admission MUST be active
        assert runtime_lifecycle._active_asgi_mutations == 1
        assert runtime_lifecycle.has_active_database_work is True

        # Signal stream to finish
        finish_stream.set()
        resp = await asyncio.wait_for(stream_task, timeout=2.0)
        assert resp.status_code == 200

        # Now admission is released
        assert runtime_lifecycle._active_asgi_mutations == 0


@pytest.mark.anyio
async def test_failed_terminal_persistence_prevents_clean_shutdown():
    """Verify that a failed SQLite terminal persistence commit prevents claiming clean shutdown."""
    coord = RuntimeLifecycleCoordinator()
    mock_server = MagicMock()
    mock_server.should_exit = False
    coord.register_server(mock_server)

    async def failing_persistence():
        await asyncio.sleep(0.05)
        return False  # Failed commit

    coord.spawn_terminal_persistence_task(failing_persistence(), context_info="test_failed_commit")

    with patch("app.core.runtime_lifecycle.get_llm_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.signal_shutdown_immediately = MagicMock()
        mock_provider.shutdown = AsyncMock()
        mock_get_provider.return_value = mock_provider

        await coord.initiate_shutdown(drain_timeout_seconds=0.5)
        if coord._shutdown_task:
            await coord._shutdown_task

        assert coord.has_persistence_failures is True
        assert coord.shutdown_quiescence_status == "incomplete_persistence_failure"
        assert mock_server.should_exit is False
        mock_provider.shutdown.assert_not_called()


@pytest.mark.anyio
async def test_retry_resumes_incomplete_shutdown():
    """Verify that after an incomplete shutdown, a retry safely resumes and completes shutdown."""
    coord = RuntimeLifecycleCoordinator()
    mock_server = MagicMock()
    mock_server.should_exit = False
    coord.register_server(mock_server)

    # 1. First attempt: persistence task blocks past 0.1s deadline
    blocker_event = asyncio.Event()

    async def blocking_persistence():
        await blocker_event.wait()
        return True

    task = coord.spawn_terminal_persistence_task(blocking_persistence(), context_info="retry_test_blocker")

    with patch("app.core.runtime_lifecycle.get_llm_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.signal_shutdown_immediately = MagicMock()
        mock_provider.shutdown = AsyncMock(return_value=ProviderShutdownResult(completed_cleanly=True, lock_acquired=True))
        mock_get_provider.return_value = mock_provider

        # Attempt 1
        already_shutting_down, msg = await coord.initiate_shutdown(drain_timeout_seconds=0.1)
        assert already_shutting_down is False
        assert msg == "shutdown_initiated"
        await coord._shutdown_task

        # Halts at incomplete_db_quiescence_timeout
        assert coord.shutdown_quiescence_status == "incomplete_db_quiescence_timeout"
        assert mock_server.should_exit is False

        # 2. Unblock the persistence task so it completes cleanly
        blocker_event.set()
        await task
        assert coord.has_active_database_work is False

        # 3. Retry shutdown!
        already_shutting_down, msg = await coord.initiate_shutdown(drain_timeout_seconds=0.5)
        assert already_shutting_down is False
        assert msg == "shutdown_retried"
        await coord._shutdown_task

        # Now achieves clean shutdown!
        assert coord.shutdown_quiescence_status == "clean"
        assert mock_server.should_exit is True
        mock_provider.shutdown.assert_called_once()


@pytest.mark.anyio
async def test_failed_persistence_preserved_across_shutdown_retries():
    """Verify that failed persistence records are preserved across retries and halt retried shutdowns."""
    coord = RuntimeLifecycleCoordinator()
    mock_server = MagicMock()
    mock_server.should_exit = False
    coord.register_server(mock_server)

    async def failing_persistence():
        await asyncio.sleep(0.01)
        return False  # Failed commit

    task = coord.spawn_terminal_persistence_task(failing_persistence(), context_info="test_failure")
    await task

    assert coord.has_persistence_failures is True
    assert len(coord._persistence_failures) == 1
    assert coord._persistence_failures[0]["status"] == "failed_commit"

    with patch("app.core.runtime_lifecycle.get_llm_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.signal_shutdown_immediately = MagicMock()
        mock_provider.shutdown = AsyncMock()
        mock_get_provider.return_value = mock_provider

        # Attempt 1: Should halt at incomplete_persistence_failure
        already_shutting_down, msg = await coord.initiate_shutdown(drain_timeout_seconds=0.5)
        assert already_shutting_down is False
        assert msg == "shutdown_initiated"
        await coord._shutdown_task

        assert coord.shutdown_quiescence_status == "incomplete_persistence_failure"
        assert mock_server.should_exit is False
        mock_provider.shutdown.assert_not_called()

        # Attempt 2 (Retry): Must NOT clear failures; must halt again at incomplete_persistence_failure
        already_shutting_down, msg = await coord.initiate_shutdown(drain_timeout_seconds=0.5)
        assert already_shutting_down is False
        assert msg == "shutdown_retried"
        await coord._shutdown_task

        assert coord.has_persistence_failures is True
        assert coord.shutdown_quiescence_status == "incomplete_persistence_failure"
        assert mock_server.should_exit is False
        mock_provider.shutdown.assert_not_called()


@pytest.mark.asyncio
async def test_system_status_polling_during_and_after_db_disposal(client: AsyncClient, host_admin_headers: dict):
    """Verify /system/status polls successfully during shutdown and after DB disposal without database dependency."""
    import app.db.session as session_module

    saved_engine = session_module._engine
    saved_factory = session_module._session_factory

    try:
        # Simulate database engine and factory disposal
        session_module._engine = None
        session_module._session_factory = None

        # Mark runtime as shutting down
        runtime_lifecycle._is_shutting_down = True
        runtime_lifecycle._shutdown_phase = "draining_work"

        resp = await client.get("/api/v1/system/status", headers=host_admin_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["shutting_down"] is True
        assert data["database_connected"] is False
        assert data["shutdown_phase"] == "draining_work"
        assert data["status"] == "degraded"
    finally:
        session_module._engine = saved_engine
        session_module._session_factory = saved_factory


@pytest.mark.asyncio
async def test_delayed_readonly_database_request_overlapping_shutdown(
    client: AsyncClient,
    auth_headers: dict,
    host_admin_headers: dict,
):
    """Directive 4: Delayed read-only DB request admitted before shutdown does not race with disposal,

    and new read-only DB requests arriving during shutdown are rejected with 503.
    """
    runtime_lifecycle.reset()
    read_started = asyncio.Event()
    read_can_finish = asyncio.Event()

    original_acquire = runtime_lifecycle.acquire_read_admission

    def delayed_acquire():
        res = original_acquire()
        read_started.set()
        return res

    # 1. Admit read-only request before shutdown
    with patch.object(runtime_lifecycle, "acquire_read_admission", side_effect=delayed_acquire):
        async def slow_read():
            await read_started.wait()
            # Wait until shutdown has started before letting read complete
            await read_can_finish.wait()

        slow_task = asyncio.create_task(slow_read())
        # Simulate active read in coordinator
        assert runtime_lifecycle.acquire_read_admission() is True
        assert runtime_lifecycle._active_asgi_reads == 1
        assert runtime_lifecycle.has_active_database_work is True

        # 2. Initiate shutdown while read is active
        mock_server = MagicMock()
        mock_server.should_exit = False
        runtime_lifecycle.register_server(mock_server)

        with patch("app.core.runtime_lifecycle.get_llm_provider") as mock_get_provider:
            mock_provider = MagicMock()
            mock_provider.signal_shutdown_immediately = MagicMock()
            mock_provider.shutdown = AsyncMock(
                return_value=ProviderShutdownResult(
                    completed_cleanly=True,
                    lock_acquired=True,
                    managed_llm_pid=None,
                    managed_by_core=False,
                )
            )
            mock_get_provider.return_value = mock_provider

            already, msg = await runtime_lifecycle.initiate_shutdown(drain_timeout_seconds=2.0)
            assert already is False
            assert runtime_lifecycle.is_shutting_down is True

            # 3. New read request arriving AFTER shutdown must be rejected
            resp_after = await client.get("/api/v1/conversations", headers=auth_headers)
            assert resp_after.status_code == 503
            assert resp_after.json()["error"]["code"] == "RUNTIME_SHUTTING_DOWN"

            # 4. Polling health and status endpoints during shutdown must succeed
            resp_health = await client.get("/api/v1/health")
            # health probe returns 503 during shutdown per spec, but does NOT touch DB
            assert resp_health.status_code == 503
            assert resp_health.json()["status"] == "shutting_down"

            resp_status = await client.get("/api/v1/system/status", headers=host_admin_headers)
            assert resp_status.status_code == 200
            assert resp_status.json()["shutting_down"] is True

            # 5. Let the in-flight read finish
            read_can_finish.set()
            await slow_task
            runtime_lifecycle.release_read_admission()
            assert runtime_lifecycle._active_asgi_reads == 0

            # 6. Shutdown completes cleanly
            await runtime_lifecycle._shutdown_task
            assert runtime_lifecycle.shutdown_quiescence_status == "clean"
            assert mock_server.should_exit is True


@pytest.mark.asyncio
async def test_inflight_authenticated_model_status_request_overlapping_shutdown(
    client: AsyncClient,
    auth_headers: dict,
    host_admin_headers: dict,
):
    """Correction 2: In-flight authenticated GET /api/v1/models holding psk_ session is tracked in

    read quiescence and does not race with database engine disposal.
    """
    runtime_lifecycle.reset()
    model_req_started = asyncio.Event()
    model_req_can_finish = asyncio.Event()

    from app.services.llm.manager import llm_manager
    provider = llm_manager.get_provider()
    real_get_status = provider.get_status

    async def slow_get_status():
        model_req_started.set()
        await model_req_can_finish.wait()
        return await real_get_status()

    with patch.object(provider, "get_status", side_effect=slow_get_status):
        # 1. Start authenticated model status request before shutdown
        model_task = asyncio.create_task(client.get("/api/v1/models", headers=auth_headers))
        await model_req_started.wait()

        # In-flight read must be actively tracked in coordinator
        assert runtime_lifecycle._active_asgi_reads == 1
        assert runtime_lifecycle.has_active_database_work is True

        # 2. Initiate shutdown while model status request is in flight
        mock_server = MagicMock()
        mock_server.should_exit = False
        runtime_lifecycle.register_server(mock_server)

        with patch("app.core.runtime_lifecycle.get_llm_provider") as mock_get_provider:
            mock_provider = MagicMock()
            mock_provider.signal_shutdown_immediately = MagicMock()
            mock_provider.shutdown = AsyncMock(
                return_value=ProviderShutdownResult(
                    completed_cleanly=True,
                    lock_acquired=True,
                    managed_llm_pid=None,
                    managed_by_core=False,
                )
            )
            mock_get_provider.return_value = mock_provider

            already, msg = await runtime_lifecycle.initiate_shutdown(drain_timeout_seconds=2.0)
            assert already is False
            assert runtime_lifecycle.is_shutting_down is True

            # 3. New request after gate closed is rejected
            resp_rejected = await client.get("/api/v1/models", headers=auth_headers)
            assert resp_rejected.status_code == 503
            assert resp_rejected.json()["error"]["code"] == "RUNTIME_SHUTTING_DOWN"

            # 4. Release in-flight model request
            model_req_can_finish.set()
            resp_model = await model_task
            assert resp_model.status_code == 200
            assert runtime_lifecycle._active_asgi_reads == 0

            # 5. Shutdown completes cleanly
            await runtime_lifecycle._shutdown_task
            assert runtime_lifecycle.shutdown_quiescence_status == "clean"
            assert mock_server.should_exit is True


@pytest.mark.asyncio
async def test_new_model_status_request_rejected_after_admission_gate_closes(
    client: AsyncClient,
    auth_headers: dict,
    host_admin_headers: dict,
):
    """Correction 2: Model status requests arriving after admission gate closes are rejected with 503

    while database-free health and system status polling remain functional.
    """
    runtime_lifecycle.reset()
    mock_server = MagicMock()
    mock_server.should_exit = False
    runtime_lifecycle.register_server(mock_server)

    with patch("app.core.runtime_lifecycle.get_llm_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.signal_shutdown_immediately = MagicMock()
        mock_provider.shutdown = AsyncMock(
            return_value=ProviderShutdownResult(
                completed_cleanly=True,
                lock_acquired=True,
                managed_llm_pid=None,
                managed_by_core=False,
            )
        )
        mock_get_provider.return_value = mock_provider

        already, msg = await runtime_lifecycle.initiate_shutdown(drain_timeout_seconds=1.0)
        assert already is False
        assert runtime_lifecycle.is_shutting_down is True

        # Model status request arrives AFTER admission gate closed -> 503 RUNTIME_SHUTTING_DOWN
        resp_models = await client.get("/api/v1/models", headers=auth_headers)
        assert resp_models.status_code == 503
        assert resp_models.json()["error"]["code"] == "RUNTIME_SHUTTING_DOWN"

        # Database-free health/status polling remains functional
        resp_health = await client.get("/api/v1/health")
        assert resp_health.status_code == 503
        assert resp_health.json()["status"] == "shutting_down"

        resp_status = await client.get("/api/v1/system/status", headers=host_admin_headers)
        assert resp_status.status_code == 200
        assert resp_status.json()["shutting_down"] is True

        await runtime_lifecycle._shutdown_task
        assert runtime_lifecycle.shutdown_quiescence_status == "clean"



