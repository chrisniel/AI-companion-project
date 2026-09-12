"""Task management CRUD endpoints adhering to api-endpoint-builder and OWASP standards."""

from datetime import datetime, timedelta, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_owner, get_db
from app.core.errors import CompanionNotFoundError
from app.models.task import Task
from app.schemas.task import (
    TaskCategory,
    TaskCreate,
    TaskListResponse,
    TaskPriority,
    TaskResponse,
    TaskStatus,
    TaskUpdate,
    TrashListResponse,
    TrashTaskResponse,
)
from app.services.retention import calculate_remaining_days

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.get("", response_model=TaskListResponse, summary="List Tasks")
async def list_tasks(
    status_filter: Optional[TaskStatus] = Query(None, alias="status", description="Filter tasks by status."),
    priority_filter: Optional[TaskPriority] = Query(None, alias="priority", description="Filter tasks by priority."),
    category_filter: Optional[TaskCategory] = Query(None, alias="category", description="Filter tasks by category."),
    skip: int = Query(0, ge=0, description="Offset for pagination."),
    limit: int = Query(50, ge=1, le=100, description="Page limit."),
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> TaskListResponse:
    """List active (non-deleted) tasks owned by the authenticated profile with optional filtering."""
    query = select(Task).where(
        Task.owner_id == owner_id,
        Task.is_deleted.is_(False),
    )

    if status_filter:
        query = query.where(Task.status == status_filter.value)
    if priority_filter:
        query = query.where(Task.priority == priority_filter.value)
    if category_filter:
        query = query.where(Task.category == category_filter.value)

    # Count total matching query
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar_one_or_none() or 0

    # Retrieve paginated items
    items_query = query.order_by(Task.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(items_query)
    tasks = result.scalars().all()

    return TaskListResponse(
        items=[TaskResponse.model_validate(task) for task in tasks],
        total=total,
    )


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED, summary="Create Task")
async def create_task(
    payload: TaskCreate,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> TaskResponse:
    """Create a new action item or reminder strictly scoped to the authenticated owner."""
    # Automatically compute reminder_at if reminder offset and due_date are supplied
    reminder_at = payload.reminder_at
    if reminder_at is None and payload.reminder_minutes_before is not None and payload.due_date is not None:
        reminder_at = payload.due_date - timedelta(minutes=payload.reminder_minutes_before)

    task = Task(
        owner_id=owner_id,
        title=payload.title,
        notes=payload.notes,
        category=payload.category.value,
        priority=payload.priority.value,
        due_date=payload.due_date,
        reminder_minutes_before=payload.reminder_minutes_before,
        reminder_at=reminder_at,
        status=TaskStatus.pending.value,
        is_deleted=False,
        deleted_at=None,
    )
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return TaskResponse.model_validate(task)


@router.get("/trash", response_model=TrashListResponse, summary="List Soft-Deleted Tasks (Recycle Bin)")
async def list_trash(
    skip: int = Query(0, ge=0, description="Offset for pagination."),
    limit: int = Query(50, ge=1, le=100, description="Page limit."),
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> TrashListResponse:
    """List soft-deleted tasks in the Recycle Bin for the authenticated profile with purge expiry countdown."""
    query = select(Task).where(
        Task.owner_id == owner_id,
        Task.is_deleted.is_(True),
    )

    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar_one_or_none() or 0

    items_query = query.order_by(Task.deleted_at.desc()).offset(skip).limit(limit)
    result = await db.execute(items_query)
    tasks = result.scalars().all()

    items: List[TrashTaskResponse] = []
    for task in tasks:
        task_data = TaskResponse.model_validate(task).model_dump()
        task_data["expires_in_days"] = calculate_remaining_days(task.deleted_at)
        items.append(TrashTaskResponse(**task_data))

    return TrashListResponse(items=items, total=total)


@router.get("/{task_id}", response_model=TaskResponse, summary="Get Task by ID")
async def get_task(
    task_id: str,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> TaskResponse:
    """Retrieve an active single task by its unique UUID identifier."""
    query = select(Task).where(
        Task.id == task_id,
        Task.owner_id == owner_id,
        Task.is_deleted.is_(False),
    )
    result = await db.execute(query)
    task = result.scalar_one_or_none()

    if not task:
        raise CompanionNotFoundError(message=f"Task with ID {task_id!r} not found.")

    return TaskResponse.model_validate(task)


@router.patch("/{task_id}", response_model=TaskResponse, summary="Partial Update Task")
async def update_task(
    task_id: str,
    payload: TaskUpdate,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> TaskResponse:
    """Partially update specific fields on an existing active task."""
    query = select(Task).where(
        Task.id == task_id,
        Task.owner_id == owner_id,
        Task.is_deleted.is_(False),
    )
    result = await db.execute(query)
    task = result.scalar_one_or_none()

    if not task:
        raise CompanionNotFoundError(message=f"Task with ID {task_id!r} not found.")

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if hasattr(task, field):
            setattr(task, field, value.value if hasattr(value, "value") else value)

    # Recompute reminder_at if reminder offset or due_date changed and reminder_at wasn't explicitly supplied
    if "reminder_at" not in update_data:
        if task.reminder_minutes_before is not None and task.due_date is not None:
            task.reminder_at = task.due_date - timedelta(minutes=task.reminder_minutes_before)
        elif task.reminder_minutes_before is None:
            task.reminder_at = None

    await db.commit()
    await db.refresh(task)
    return TaskResponse.model_validate(task)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Soft Delete Task")
async def delete_task(
    task_id: str,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Move a task to the Recycle Bin (soft delete, Section 16.1)."""
    query = select(Task).where(
        Task.id == task_id,
        Task.owner_id == owner_id,
        Task.is_deleted.is_(False),
    )
    result = await db.execute(query)
    task = result.scalar_one_or_none()

    if not task:
        raise CompanionNotFoundError(message=f"Task with ID {task_id!r} not found.")

    task.is_deleted = True
    task.deleted_at = datetime.now(timezone.utc)
    await db.commit()


@router.post("/{task_id}/restore", response_model=TaskResponse, summary="Restore Soft-Deleted Task")
async def restore_task(
    task_id: str,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> TaskResponse:
    """Restore a soft-deleted task from the Recycle Bin back to active status."""
    query = select(Task).where(
        Task.id == task_id,
        Task.owner_id == owner_id,
        Task.is_deleted.is_(True),
    )
    result = await db.execute(query)
    task = result.scalar_one_or_none()

    if not task:
        raise CompanionNotFoundError(message=f"Task with ID {task_id!r} not found in Trash.")

    task.is_deleted = False
    task.deleted_at = None
    await db.commit()
    await db.refresh(task)
    return TaskResponse.model_validate(task)


@router.delete("/{task_id}/permanent", status_code=status.HTTP_204_NO_CONTENT, summary="Permanently Delete Task")
async def permanent_delete_task(
    task_id: str,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Permanently delete a task row from the database (must currently reside in Trash)."""
    query = select(Task).where(
        Task.id == task_id,
        Task.owner_id == owner_id,
        Task.is_deleted.is_(True),
    )
    result = await db.execute(query)
    task = result.scalar_one_or_none()

    if not task:
        raise CompanionNotFoundError(message=f"Task with ID {task_id!r} not found in Trash.")

    await db.delete(task)
    await db.commit()
