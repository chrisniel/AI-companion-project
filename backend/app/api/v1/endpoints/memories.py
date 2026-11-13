"""Memory management CRUD endpoints — Master Plan §18, §34 (Track B5), Milestone M3 Batch C1."""

from datetime import datetime, timezone
import json
import logging
from typing import Literal, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, case, func, not_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db
from app.core.profile_sessions import validate_profile_session
from app.models.character_instance import CharacterInstance
from app.models.memory import Memory
from app.models.profile_session import ProfileSession
from app.schemas.memory import MemoryCreate, MemoryListOut, MemoryOut, MemoryUpdate

logger = logging.getLogger("app.api.v1.endpoints.memories")

router = APIRouter()


def _has_trigger_keywords_expr():
    return and_(
        Memory.trigger_keywords.is_not(None),
        Memory.trigger_keywords != "",
        Memory.trigger_keywords != "[]",
    )


def _short_term_expr():
    return or_(
        Memory.expires_at.is_not(None),
        and_(
            Memory.category == "context",
            Memory.is_core.is_(False),
            not_(_has_trigger_keywords_expr()),
        ),
    )


def _knowledge_expr():
    return and_(
        not_(_short_term_expr()),
        or_(
            Memory.is_core.is_(True),
            Memory.source_type == "manual",
            _has_trigger_keywords_expr(),
        ),
    )


def _long_term_expr():
    return and_(not_(_short_term_expr()), not_(_knowledge_expr()))


@router.get(
    "",
    response_model=MemoryListOut,
    summary="List Memories",
)
async def list_memories(
    category: Optional[str] = Query(None, description="Filter by category (fact, preference, context)"),
    scope: Optional[str] = Query(None, description="Filter by scope: 'profile' or 'character'"),
    character_instance_id: Optional[str] = Query(None, description="Filter by character instance id"),
    is_core: Optional[bool] = Query(None, description="Filter by is_core flag"),
    user_verified: Optional[bool] = Query(None, description="Filter by user verification state"),
    source_type: Optional[str] = Query(None, description="Filter by source type: manual, extracted, conflict, etc."),
    tier: Optional[Literal["knowledge", "long_term", "short_term"]] = Query(
        None,
        description="Filter by memory tier: knowledge, long_term, or short_term",
    ),
    q: Optional[str] = Query(None, description="Search memory content"),
    include_expired: bool = Query(False, description="Whether to include expired temporary memories"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> MemoryListOut:
    """List active memories owned by the user, optionally filtered by tier, category, scope, and expiry."""
    now = datetime.now(timezone.utc)
    base_query = select(Memory).where(
        Memory.profile_id == session.profile_id,
        Memory.deleted_at.is_(None),
    )
    if not include_expired:
        base_query = base_query.where(or_(Memory.expires_at.is_(None), Memory.expires_at > now))

    st_expr = _short_term_expr()
    know_expr = _knowledge_expr()
    lt_expr = _long_term_expr()

    # Profile-wide tier counts (respecting expiry boundary, independent of active tier tab)
    counts_stmt = select(
        func.coalesce(func.sum(case((know_expr, 1), else_=0)), 0),
        func.coalesce(func.sum(case((lt_expr, 1), else_=0)), 0),
        func.coalesce(func.sum(case((st_expr, 1), else_=0)), 0),
    ).where(
        Memory.profile_id == session.profile_id,
        Memory.deleted_at.is_(None),
    )
    if not include_expired:
        counts_stmt = counts_stmt.where(or_(Memory.expires_at.is_(None), Memory.expires_at > now))
    counts_row = (await db.execute(counts_stmt)).one()
    knowledge_count = int(counts_row[0] or 0)
    long_term_count = int(counts_row[1] or 0)
    short_term_count = int(counts_row[2] or 0)

    query = base_query
    if q and q.strip():
        needle = q.strip()
        query = query.where(or_(Memory.content.icontains(needle), Memory.trigger_keywords.icontains(needle)))
    if category:
        query = query.where(Memory.category == category)
    if scope:
        query = query.where(Memory.scope == scope)
    if character_instance_id:
        query = query.where(Memory.character_instance_id == character_instance_id)
    if is_core is not None:
        query = query.where(Memory.is_core.is_(is_core))
    if user_verified is not None:
        query = query.where(Memory.user_verified.is_(user_verified))
    if source_type:
        query = query.where(Memory.source_type == source_type)
    if tier == "knowledge":
        query = query.where(know_expr)
    elif tier == "long_term":
        query = query.where(lt_expr)
    elif tier == "short_term":
        query = query.where(st_expr)

    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar_one_or_none() or 0

    items_query = query.order_by(Memory.is_core.desc(), Memory.created_at.desc()).offset(skip).limit(limit)
    items = list((await db.execute(items_query)).scalars().all())

    page = (skip // limit) + 1
    return MemoryListOut(
        items=items,
        total=total,
        page=page,
        page_size=limit,
        knowledge_count=knowledge_count,
        long_term_count=long_term_count,
        short_term_count=short_term_count,
    )


@router.get(
    "/{memory_id}",
    response_model=MemoryOut,
    summary="Get Memory by ID",
)
async def get_memory(
    memory_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> MemoryOut:
    """Get a single memory record by ID for the authenticated profile."""
    query = select(Memory).where(
        Memory.id == memory_id,
        Memory.profile_id == session.profile_id,
        Memory.deleted_at.is_(None),
    )
    memory = (await db.execute(query)).scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="Memory not found")
    return memory


@router.post(
    "",
    response_model=MemoryOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create Memory",
)
async def create_memory(
    payload: MemoryCreate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> MemoryOut:
    """Create a new manual memory record (synced automatically to FTS5)."""
    # Foreign character instance check
    if payload.character_instance_id:
        char_query = select(CharacterInstance).where(
            CharacterInstance.id == payload.character_instance_id,
            CharacterInstance.profile_id == session.profile_id,
            CharacterInstance.deleted_at.is_(None),
        )
        char_exists = (await db.execute(char_query)).scalar_one_or_none()
        if not char_exists:
            raise HTTPException(status_code=404, detail="Character instance not found for this profile")

    memory = Memory(
        id=str(uuid.uuid4()),
        profile_id=session.profile_id,
        scope=payload.scope,
        character_instance_id=payload.character_instance_id,
        category=payload.category,
        content=payload.content,
        importance=payload.importance,
        valid_from=payload.valid_from or datetime.now(timezone.utc),
        expires_at=payload.expires_at,
        is_core=payload.is_core,
        source_type=payload.source_type,
        user_verified=True,
        trigger_keywords=json.dumps(payload.trigger_keywords) if payload.trigger_keywords else None,
        recall_count=0,
    )
    db.add(memory)
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(memory)
    return memory


@router.patch(
    "/{memory_id}",
    response_model=MemoryOut,
    summary="Update Memory",
)
async def update_memory(
    memory_id: str,
    payload: MemoryUpdate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> MemoryOut:
    """Update memory content, category, importance, expiry, or core flag."""
    query = select(Memory).where(
        Memory.id == memory_id,
        Memory.profile_id == session.profile_id,
        Memory.deleted_at.is_(None),
    )
    memory = (await db.execute(query)).scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="Memory not found")

    update_dict = payload.model_dump(exclude_unset=True)

    if "content" in update_dict and update_dict["content"] is not None:
        memory.content = update_dict["content"]
    if "category" in update_dict and update_dict["category"] is not None:
        memory.category = update_dict["category"]
    if "importance" in update_dict and update_dict["importance"] is not None:
        memory.importance = update_dict["importance"]
    if "is_core" in update_dict and update_dict["is_core"] is not None:
        memory.is_core = update_dict["is_core"]
    if "expires_at" in update_dict:
        # None explicitly passed clears expiry and updates last_verified_at
        memory.expires_at = update_dict["expires_at"]
        memory.last_verified_at = datetime.now(timezone.utc)
    if "user_verified" in update_dict and update_dict["user_verified"] is not None:
        memory.user_verified = update_dict["user_verified"]
        if update_dict["user_verified"] is True:
            memory.last_verified_at = datetime.now(timezone.utc)
    if "source_type" in update_dict and update_dict["source_type"] is not None:
        memory.source_type = update_dict["source_type"]
    if "trigger_keywords" in update_dict:
        kws = update_dict["trigger_keywords"]
        memory.trigger_keywords = json.dumps(kws) if kws else None

    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(memory)
    return memory


@router.delete(
    "/{memory_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete Memory",
)
async def delete_memory(
    memory_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Soft-delete memory (FTS5 triggers remove it from index)."""
    query = select(Memory).where(
        Memory.id == memory_id,
        Memory.profile_id == session.profile_id,
        Memory.deleted_at.is_(None),
    )
    memory = (await db.execute(query)).scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="Memory not found")

    memory.is_deleted = True
    memory.deleted_at = datetime.now(timezone.utc)
    await validate_profile_session(db, session)
    await db.commit()
