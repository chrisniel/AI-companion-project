"""Memory management CRUD endpoints — Master Plan §18, §34 (Track B5), Milestone M3 Batch C1."""

from datetime import datetime, timezone
import logging
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db
from app.core.profile_sessions import validate_profile_session
from app.models.character_instance import CharacterInstance
from app.models.memory import Memory
from app.models.profile_session import ProfileSession
from app.schemas.memory import MemoryCreate, MemoryListOut, MemoryOut, MemoryUpdate

logger = logging.getLogger("app.api.v1.endpoints.memories")

router = APIRouter()


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
    include_expired: bool = Query(False, description="Whether to include expired temporary memories"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> MemoryListOut:
    """List active memories owned by the user, optionally filtered by category, scope, and expiry."""
    now = datetime.now(timezone.utc)
    query = select(Memory).where(
        Memory.profile_id == session.profile_id,
        Memory.deleted_at.is_(None),
    )
    if category:
        query = query.where(Memory.category == category)
    if scope:
        query = query.where(Memory.scope == scope)
    if character_instance_id:
        query = query.where(Memory.character_instance_id == character_instance_id)
    if is_core is not None:
        query = query.where(Memory.is_core.is_(is_core))
    if not include_expired:
        query = query.where(or_(Memory.expires_at.is_(None), Memory.expires_at > now))

    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar_one_or_none() or 0

    items_query = query.order_by(Memory.is_core.desc(), Memory.created_at.desc()).offset(skip).limit(limit)
    items = list((await db.execute(items_query)).scalars().all())

    page = (skip // limit) + 1
    return MemoryListOut(items=items, total=total, page=page, page_size=limit)


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
        source_type="manual",
        user_verified=True,
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
