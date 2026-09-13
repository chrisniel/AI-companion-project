"""Memory management CRUD endpoints — Master Plan §18, §34 (Track B5)."""

from datetime import datetime, timezone
import logging
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_owner, get_db
from app.models.memory import Memory
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
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> MemoryListOut:
    """List active memories owned by the user, optionally filtered by category."""
    query = select(Memory).where(
        Memory.owner_id == owner_id,
        Memory.deleted_at.is_(None),
    )
    if category:
        query = query.where(Memory.category == category)

    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar_one_or_none() or 0

    items_query = query.order_by(Memory.created_at.desc()).offset(skip).limit(limit)
    items = list((await db.execute(items_query)).scalars().all())

    page = (skip // limit) + 1
    return MemoryListOut(items=items, total=total, page=page, page_size=limit)


@router.post(
    "",
    response_model=MemoryOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create Memory",
)
async def create_memory(
    payload: MemoryCreate,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> MemoryOut:
    """Create a new manual memory record (synced automatically to FTS5)."""
    memory = Memory(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        category=payload.category,
        content=payload.content,
        importance=payload.importance,
        source_type="manual",
        user_verified=True,
    )
    db.add(memory)
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
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> MemoryOut:
    """Update memory content, category, or importance."""
    query = select(Memory).where(
        Memory.id == memory_id,
        Memory.owner_id == owner_id,
        Memory.deleted_at.is_(None),
    )
    memory = (await db.execute(query)).scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="Memory not found")

    if payload.content is not None:
        memory.content = payload.content
    if payload.category is not None:
        memory.category = payload.category
    if payload.importance is not None:
        memory.importance = payload.importance

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
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Soft-delete memory (FTS5 triggers remove it from index)."""
    query = select(Memory).where(
        Memory.id == memory_id,
        Memory.owner_id == owner_id,
        Memory.deleted_at.is_(None),
    )
    memory = (await db.execute(query)).scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=404, detail="Memory not found")

    memory.deleted_at = datetime.now(timezone.utc)
    await db.commit()
