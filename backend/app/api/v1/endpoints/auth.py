"""Separate pairing diagnostics, native approval and proof-bound session exchange."""

from collections import deque
from datetime import datetime, timedelta
import re
import secrets

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db, require_host_admin, verify_token
from app.core.config import settings
from app.core.host_admin import require_loopback
from app.core.profile_sessions import new_profile_session, now_utc, token_hash
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.models.session_ticket import SessionTicket
from app.schemas.auth import AuthVerifyResponse
from app.api.v1.endpoints.profiles import ProfileMetadata, profile_metadata

router = APIRouter(prefix="/auth", tags=["Authentication"])


class ClaimRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    claim_secret_hash: str = Field(pattern=r"^[0-9a-f]{64}$")


class TicketRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    profile_id: str = Field(min_length=1, max_length=36)
    request_id: str | None = Field(None, min_length=1, max_length=36)


class GrantResponse(BaseModel):
    request_id: str | None = None
    ticket: str | None = None
    expires_at: datetime


class PendingRequest(BaseModel):
    request_id: str
    origin: str
    expires_at: datetime


class ExchangeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    ticket: str | None = Field(None, max_length=256)
    request_id: str | None = Field(None, max_length=36)
    claim_secret: str | None = Field(None, min_length=43, max_length=256)


class SessionResponse(BaseModel):
    token: str
    profile_id: str
    expires_at: datetime
    client_type: str


class SessionMetadata(ProfileMetadata):
    expires_at: datetime = Field(description="Validated Profile Session expiry in UTC; introspection does not renew it.")


def browser_origin(request: Request) -> str:
    require_loopback(request)
    origin = request.headers.get("origin")
    if (origin not in settings.CORS_ORIGINS or origin == "null"
            or request.headers.get("x-companion-bootstrap") != "1"
            or request.headers.get("content-type", "").split(";", 1)[0].strip() != "application/json"
            or request.headers.get("sec-fetch-mode") in {"navigate", "no-cors"}
            or request.headers.get("sec-fetch-dest") not in {None, "empty"}):
        raise HTTPException(403, "Browser Origin and CSRF proof required")
    return origin


def bootstrap_rate_limit(request: Request) -> None:
    """Bound unauthenticated grants and polling before issuing any authority."""
    history = getattr(request.app.state, "bootstrap_attempts", None)
    if history is None:
        history = request.app.state.bootstrap_attempts = deque(maxlen=120)
    now = now_utc()
    while history and (now - history[0]).total_seconds() >= 60:
        history.popleft()
    if len(history) >= 120:
        raise HTTPException(429, "Authorization request rate exceeded")
    history.append(now)


async def available_profile(db: AsyncSession, profile_id: str) -> Profile:
    profile = (await db.execute(select(Profile).where(Profile.id == profile_id,
                                Profile.status == "active", Profile.is_deleted.is_(False), Profile.deleted_at.is_(None))
                                .execution_options(populate_existing=True))).scalar_one_or_none()
    if profile is None:
        raise HTTPException(404, "Profile unavailable")
    if profile.pin_hash is not None:
        raise HTTPException(403, "Profile unlock challenge is not available")
    return profile


@router.post("/verify", response_model=AuthVerifyResponse, dependencies=[Depends(verify_token)])
async def verify_credentials() -> AuthVerifyResponse:
    return AuthVerifyResponse(authenticated=True, token_type="Bearer", message="Pairing credential verified.")


@router.post("/session/claim", response_model=GrantResponse, response_model_exclude_none=True, status_code=201)
async def create_browser_request(payload: ClaimRequest, request: Request, db: AsyncSession = Depends(get_db)):
    origin = browser_origin(request)
    bootstrap_rate_limit(request)
    now = now_utc()
    count = (await db.execute(select(func.count()).select_from(SessionTicket)
                             .where(SessionTicket.expires_at > now, SessionTicket.redeemed_at.is_(None)))).scalar_one()
    if count >= 64:
        raise HTTPException(429, "Too many pending authorization requests")
    pending = SessionTicket(claim_secret_hash=payload.claim_secret_hash, origin=origin,
                            created_at=now, expires_at=now + timedelta(seconds=60))
    db.add(pending)
    await db.commit()
    return GrantResponse(request_id=pending.id, expires_at=pending.expires_at)


@router.get("/bootstrap/requests", response_model=list[PendingRequest], dependencies=[Depends(require_host_admin)])
async def pending_requests(db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(SessionTicket).where(SessionTicket.origin.is_not(None),
                           SessionTicket.approved_at.is_(None), SessionTicket.redeemed_at.is_(None),
                           SessionTicket.expires_at > now_utc()).order_by(SessionTicket.created_at))).scalars().all()
    return [PendingRequest(request_id=row.id, origin=row.origin, expires_at=row.expires_at) for row in rows]


@router.post("/bootstrap/ticket", response_model=GrantResponse, response_model_exclude_none=True,
             dependencies=[Depends(require_host_admin)])
async def approve_profile(payload: TicketRequest, db: AsyncSession = Depends(get_db)):
    await available_profile(db, payload.profile_id)
    now = now_utc()
    if payload.request_id:
        row = (await db.execute(update(SessionTicket).where(SessionTicket.id == payload.request_id,
                    SessionTicket.origin.is_not(None), SessionTicket.claim_secret_hash.is_not(None),
                    SessionTicket.approved_at.is_(None), SessionTicket.redeemed_at.is_(None),
                    SessionTicket.expires_at > now).values(profile_id=payload.profile_id, approved_at=now)
                    .returning(SessionTicket.expires_at))).first()
        if row is None:
            raise HTTPException(401, "Authorization request unavailable")
        await db.commit()
        return GrantResponse(request_id=payload.request_id, expires_at=row[0])
    ticket = "ptk_" + secrets.token_urlsafe(48)
    row = SessionTicket(ticket_hash=token_hash(ticket), profile_id=payload.profile_id,
                        created_at=now, approved_at=now, expires_at=now + timedelta(seconds=60))
    db.add(row)
    await db.commit()
    return GrantResponse(ticket=ticket, expires_at=row.expires_at)


@router.post("/session/exchange", response_model=SessionResponse)
async def exchange_session(payload: ExchangeRequest, request: Request, db: AsyncSession = Depends(get_db)):
    require_loopback(request)
    bootstrap_rate_limit(request)
    now = now_utc()
    conditions = [SessionTicket.expires_at > now, SessionTicket.redeemed_at.is_(None),
                  SessionTicket.approved_at.is_not(None), SessionTicket.profile_id.is_not(None)]
    if payload.ticket and not payload.request_id and not payload.claim_secret:
        if "origin" in request.headers or request.headers.get("sec-fetch-site") is not None:
            raise HTTPException(403, "Browser requests require proof-bound authorization")
        conditions += [SessionTicket.ticket_hash == token_hash(payload.ticket), SessionTicket.origin.is_(None),
                       SessionTicket.claim_secret_hash.is_(None)]
        client_type = "desktop"
    elif payload.request_id and payload.claim_secret and not payload.ticket:
        origin = browser_origin(request)
        if not re.fullmatch(r"[A-Za-z0-9_-]{43,256}", payload.claim_secret):
            raise HTTPException(401, "Invalid claim proof")
        claim_hash = token_hash(payload.claim_secret)
        pending = (await db.execute(select(SessionTicket.approved_at).where(
            SessionTicket.id == payload.request_id, SessionTicket.origin == origin,
            SessionTicket.claim_secret_hash == claim_hash, SessionTicket.expires_at > now,
            SessionTicket.redeemed_at.is_(None)))).first()
        if pending is None:
            raise HTTPException(401, "Authorization request unavailable")
        if pending[0] is None:
            raise HTTPException(409, "Awaiting explicit Desktop approval")
        conditions += [SessionTicket.id == payload.request_id, SessionTicket.origin == origin,
                       SessionTicket.claim_secret_hash == claim_hash]
        client_type = "web_browser"
    else:
        raise HTTPException(401, "Approved grant required")
    # Atomic grant burn and session creation commit together, never independently.
    redeemed = (await db.execute(update(SessionTicket).where(*conditions).values(redeemed_at=now)
                                .returning(SessionTicket.profile_id))).first()
    if redeemed is None:
        raise HTTPException(401, "Authorization grant expired or consumed")
    await available_profile(db, redeemed[0])
    token, session = new_profile_session(redeemed[0], client_type)
    db.add(session)
    await db.commit()
    return SessionResponse(token=token, profile_id=session.profile_id, expires_at=session.expires_at, client_type=client_type)


@router.post("/session/revoke", status_code=204)
async def revoke_session(session: ProfileSession = Depends(get_current_profile_session), db: AsyncSession = Depends(get_db)):
    await db.execute(update(ProfileSession).where(ProfileSession.id == session.id).values(revoked_at=now_utc()))
    await db.commit()


@router.get("/session/me", response_model=SessionMetadata)
async def session_me(session: ProfileSession = Depends(get_current_profile_session), db: AsyncSession = Depends(get_db)):
    profile = await db.get(Profile, session.profile_id)
    return SessionMetadata(**profile_metadata(profile).model_dump(), expires_at=session.expires_at)
