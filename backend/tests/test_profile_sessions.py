"""Real HTTP/SQLite tests for authority separation and proof-bound browser grants."""

import hashlib
import asyncio
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.models.profile import Profile

BROWSER = {"Origin": "http://localhost:5173", "X-Companion-Bootstrap": "1"}
CLAIM = "a" * 64
ADMIN = {"X-Host-Admin-Secret": "test-host-admin-independent-credential"}


@pytest.fixture
def host_authority(monkeypatch):
    from app.core import host_admin
    monkeypatch.setattr(host_admin, "read_host_admin_secret", lambda: ADMIN["X-Host-Admin-Secret"])
    return ADMIN


async def default_profile(db):
    return (await db.execute(select(Profile).where(Profile.is_default.is_(True)))).scalar_one()


async def pending(client):
    response = await client.post("/api/v1/auth/session/claim", headers=BROWSER,
                                 json={"claim_secret_hash": hashlib.sha256(CLAIM.encode()).hexdigest()})
    assert response.status_code == 201
    assert "token" not in response.json() and "ticket" not in response.json()
    return response.json()["request_id"]


@pytest.mark.asyncio
async def test_pairing_cannot_issue_sessions_or_enumerate_profiles(client, pairing_headers):
    for path, payload in [("/api/v1/auth/bootstrap/ticket", {"profile_id": "guess"}),
                          ("/api/v1/auth/session/exchange", {"ticket": "guess"})]:
        response = await client.post(path, headers=pairing_headers, json=payload)
        assert response.status_code in (401, 403)
    assert (await client.get("/api/v1/profiles", headers=pairing_headers)).status_code in (401, 403)


@pytest.mark.asyncio
@pytest.mark.parametrize("method,path,payload", [
    ("POST", "/api/v1/models/load", {}), ("POST", "/api/v1/models/select", {"model_name": "guess"}),
    ("POST", "/api/v1/models/unload", {}), ("PATCH", "/api/v1/models/profile", {"profile": "eco"}),
    ("GET", "/api/v1/system/status", None),
])
async def test_neither_pairing_nor_profile_session_elevates_to_host_admin(client, pairing_headers, auth_headers, method, path, payload):
    for headers in (pairing_headers, auth_headers):
        response = await client.request(method, path, headers=headers, **({"json": payload} if payload is not None else {}))
        assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_pairing_cannot_generate_and_profile_can_read_telemetry(client, pairing_headers, auth_headers):
    response = await client.post("/api/v1/chat/completions", headers=pairing_headers,
                                 json={"messages": [{"role": "user", "content": "private"}]})
    assert response.status_code == 401
    for headers in (pairing_headers, auth_headers):
        assert (await client.get("/api/v1/models", headers=headers)).status_code == 200


@pytest.mark.asyncio
async def test_browser_requires_explicit_approval_and_its_own_secret(client, test_session, host_authority):
    request_id = await pending(client)
    exchange = {"request_id": request_id, "claim_secret": CLAIM}
    assert (await client.post("/api/v1/auth/session/exchange", headers=BROWSER, json=exchange)).status_code == 409
    profile = await default_profile(test_session)
    approval = await client.post("/api/v1/auth/bootstrap/ticket", headers=host_authority,
                                 json={"profile_id": profile.id, "request_id": request_id})
    assert approval.status_code == 200
    assert "ticket" not in approval.json() and "token" not in approval.json()
    stolen = {**exchange, "claim_secret": "b" * 64}
    assert (await client.post("/api/v1/auth/session/exchange", headers=BROWSER, json=stolen)).status_code == 401
    response = await client.post("/api/v1/auth/session/exchange", headers=BROWSER, json=exchange)
    assert response.status_code == 200
    token = response.json()["token"]
    assert token.startswith("psk_") and response.json()["profile_id"] == profile.id
    assert (await client.post("/api/v1/auth/session/exchange", headers=BROWSER, json=exchange)).status_code == 401
    headers = {"Authorization": f"Bearer {token}"}
    assert (await client.get("/api/v1/profiles", headers=headers)).status_code in (401, 403)
    assert (await client.get(f"/api/v1/profiles/{profile.id}", headers=headers)).status_code == 200
    foreign = Profile(name="Other person")
    test_session.add(foreign)
    await test_session.commit()
    assert (await client.get(f"/api/v1/profiles/{foreign.id}", headers=headers)).status_code == 404
    assert (await client.get("/api/v1/auth/session/me", headers=headers)).status_code == 200
    assert (await client.post("/api/v1/auth/session/revoke", headers=headers)).status_code == 204
    assert (await client.get("/api/v1/auth/session/me", headers=headers)).status_code == 401


@pytest.mark.asyncio
@pytest.mark.parametrize("headers", [{}, {"Origin": "null", "X-Companion-Bootstrap": "1"},
                                    {"Origin": "https://evil.example", "X-Companion-Bootstrap": "1"},
                                    {"Origin": "http://localhost:5173"},
                                    {**BROWSER, "Sec-Fetch-Mode": "navigate"}])
async def test_browser_claim_rejects_bad_origin_or_csrf(client, headers):
    response = await client.post("/api/v1/auth/session/claim", headers=headers,
                                 json={"claim_secret_hash": "a" * 64})
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_admin_cannot_be_used_by_browser_and_pin_fails_closed(client, test_session, host_authority):
    profile = await default_profile(test_session)
    assert (await client.get("/api/v1/profiles", headers={**host_authority, **BROWSER})).status_code == 403
    profile.pin_hash = "protected-profile"
    await test_session.commit()
    response = await client.post("/api/v1/auth/bootstrap/ticket", headers=host_authority, json={"profile_id": profile.id})
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_expired_approved_request_and_session_fail_closed(client, test_session, host_authority):
    from app.models.session_ticket import SessionTicket
    from app.models.profile_session import ProfileSession
    profile = await default_profile(test_session)
    grant = await client.post("/api/v1/auth/bootstrap/ticket", headers=host_authority, json={"profile_id": profile.id})
    assert grant.status_code == 200
    exchange = await client.post("/api/v1/auth/session/exchange", json={"ticket": grant.json()["ticket"]})
    assert exchange.status_code == 200
    session = (await test_session.execute(select(ProfileSession))).scalar_one()
    assert session.token_hash != exchange.json()["token"]
    session.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    await test_session.commit()
    headers = {"Authorization": f"Bearer {exchange.json()['token']}"}
    assert (await client.get("/api/v1/auth/session/me", headers=headers)).status_code == 401
    request_id = await pending(client)
    ticket = await test_session.get(SessionTicket, request_id)
    ticket.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    await test_session.commit()
    assert (await client.post("/api/v1/auth/bootstrap/ticket", headers=host_authority,
                             json={"profile_id": profile.id, "request_id": request_id})).status_code == 401


@pytest.mark.asyncio
async def test_concurrent_exchange_burns_exactly_once_and_rolls_back_on_failure(tmp_path, host_authority, monkeypatch):
    """Separate connections exercise SQLite atomicity rather than one shared test session."""
    from httpx import ASGITransport, AsyncClient
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
    from app.api.deps import get_db
    from app.api.v1.endpoints import auth
    from app.db.base import Base
    from app.main import app
    from app.models.profile_session import ProfileSession
    from app.models.session_ticket import SessionTicket
    engine = create_async_engine(f"sqlite+aiosqlite:///{(tmp_path / 'sessions.db').as_posix()}")
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    async with factory() as db:
        profile_id = (await default_profile(db)).id

    async def isolated_db():
        async with factory() as db:
            try:
                yield db
            except BaseException:
                await db.rollback()
                raise
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = isolated_db
    if hasattr(app.state, "bootstrap_attempts"):
        app.state.bootstrap_attempts.clear()
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://127.0.0.1") as browser:
            response = await browser.post("/api/v1/auth/bootstrap/ticket", headers=host_authority, json={"profile_id": profile_id})
            assert response.status_code == 200
            ticket = response.json()["ticket"]
            responses = await asyncio.gather(*[browser.post("/api/v1/auth/session/exchange", json={"ticket": ticket}) for _ in range(2)])
            assert sorted(response.status_code for response in responses) == [200, 401]
            async with factory() as db:
                assert len((await db.execute(select(ProfileSession))).scalars().all()) == 1
            response = await browser.post("/api/v1/auth/bootstrap/ticket", headers=host_authority, json={"profile_id": profile_id})
            failure_ticket = response.json()["ticket"]
            original = auth.new_profile_session
            def fail_issuance(*args):
                raise RuntimeError("synthetic session insertion failure")
            monkeypatch.setattr(auth, "new_profile_session", fail_issuance)
            with pytest.raises(RuntimeError, match="synthetic session"):
                await browser.post("/api/v1/auth/session/exchange", json={"ticket": failure_ticket})
            async with factory() as db:
                grant = (await db.execute(select(SessionTicket).where(SessionTicket.ticket_hash == hashlib.sha256(failure_ticket.encode()).hexdigest()))).scalar_one()
                assert grant.redeemed_at is None
            monkeypatch.setattr(auth, "new_profile_session", original)
            assert (await browser.post("/api/v1/auth/session/exchange", json={"ticket": failure_ticket})).status_code == 200
    finally:
        if previous is None:
            app.dependency_overrides.pop(get_db, None)
        else:
            app.dependency_overrides[get_db] = previous
        await engine.dispose()


@pytest.mark.asyncio
async def test_admin_and_bootstrap_reject_network_peer_and_dns_rebinding(test_session, host_authority):
    from httpx import ASGITransport, AsyncClient
    from app.api.deps import get_db
    from app.main import app
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = lambda: test_session
    try:
        for peer, host in [("192.168.1.7", "127.0.0.1"), ("127.0.0.1", "evil.example")]:
            async with AsyncClient(transport=ASGITransport(app=app, client=(peer, 12345)), base_url=f"http://{host}") as browser:
                assert (await browser.get("/api/v1/profiles", headers=host_authority)).status_code == 403
                assert (await browser.post("/api/v1/auth/session/claim", headers=BROWSER, json={"claim_secret_hash": "a" * 64})).status_code == 403
    finally:
        if previous is None:
            app.dependency_overrides.pop(get_db, None)
        else:
            app.dependency_overrides[get_db] = previous


@pytest.mark.asyncio
async def test_revalidation_never_flushes_pending_data_before_checking_revocation(test_session, profile_session):
    from fastapi import HTTPException
    from app.core.profile_sessions import validate_profile_session
    from app.models.task import Task
    profile_session.revoked_at = datetime.now(timezone.utc)
    await test_session.commit()
    pending_task = Task(profile_id=profile_session.profile_id, title="must never be flushed")
    test_session.add(pending_task)
    with pytest.raises(HTTPException) as failure:
        await validate_profile_session(test_session, profile_session)
    assert failure.value.status_code == 401
    assert pending_task in test_session.new


@pytest.mark.asyncio
async def test_revocation_cancels_slow_synchronous_completion(client, auth_headers, default_mock_llm_provider, monkeypatch):
    started, cancelled = asyncio.Event(), asyncio.Event()
    async def slow_generate(*args, **kwargs):
        started.set()
        try:
            await asyncio.Event().wait()
            return "private result must never leave the provider"
        finally:
            cancelled.set()
    monkeypatch.setattr(default_mock_llm_provider, "generate", slow_generate)
    request = asyncio.create_task(client.post("/api/v1/chat/completions", headers=auth_headers,
                                  json={"messages": [{"role": "user", "content": "private"}]}))
    try:
        await asyncio.wait_for(started.wait(), 2)
        assert (await client.post("/api/v1/auth/session/revoke", headers=auth_headers)).status_code == 204
        response = await asyncio.wait_for(request, 1.5)
        assert response.status_code == 401
        assert cancelled.is_set()
        assert "private result" not in response.text
    finally:
        if not request.done():
            request.cancel()
            await asyncio.gather(request, return_exceptions=True)


@pytest.mark.asyncio
async def test_any_profile_deletion_marker_disables_sessions_and_new_grants(client, test_session, profile_session, auth_headers, host_authority):
    profile = await test_session.get(Profile, profile_session.profile_id)
    profile.deleted_at = datetime.now(timezone.utc)
    await test_session.commit()
    assert (await client.get("/api/v1/auth/session/me", headers=auth_headers)).status_code == 401
    assert (await client.post("/api/v1/auth/bootstrap/ticket", headers=host_authority,
                             json={"profile_id": profile.id})).status_code == 404
