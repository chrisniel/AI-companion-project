"""Task management CRUD endpoints adhering to api-endpoint-builder and OWASP standards."""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_owner, get_db
from app.core.errors import CompanionNotFoundError
from app.models.task import Task
from app.schemas.task import (
    TaskCreate,
    TaskListResponse,
    TaskPriority,
    TaskResponse,
    TaskStatus,
    TaskUpdate,
)

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.get("", response_model=TaskListResponse, summary="List Tasks")
async def list_tasks(
    status_filter: Optional[TaskStatus] = Query(None, alias="status", description="Filter tasks by status."),
    priority_filter: Optional[TaskPriority] = Query(None, alias="priority", description="Filter tasks by priority."),
    skip: int = Query(0, ge=0, description="Offset for pagination."),
    limit: int = Query(50, ge=1, le=100, description="Page limit."),
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> TaskListResponse:
    """List all tasks owned by the authenticated profile with optional filtering."""
    query = select(Task).where(Task.owner_id == owner_id)

    if status_filter:
        query = query.where(Task.status == status_filter.value)
    if priority_filter:
        query = query.where(Task.priority == priority_filter.value)

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
    task = Task(
        owner_id=owner_id,
        title=payload.title,
        notes=payload.notes,
        priority=payload.priority.value,
        due_date=payload.due_date,
        status=TaskStatus.pending.value,
    )
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return TaskResponse.model_validate(task)


@router.get("/{task_id}", response_model=TaskResponse, summary="Get Task by ID")
async def get_task(
    task_id: str,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> TaskResponse:
    """Retrieve a single task by its unique UUID identifier."""
    query = select(Task).where(Task.id == task_id, Task.owner_id == owner_id)
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
    """Partially update specific fields on an existing task."""
    query = select(Task).where(Task.id == task_id, Task.owner_id == owner_id)
    result = await db.execute(query)
    task = result.scalar_one_or_none()

    if not task:
        raise CompanionNotFoundError(message=f"Task with ID {task_id!r} not found.")

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if hasattr(task, field):
            # Enum conversion handling if needed
            setattr(task, field, value.value if hasattr(value, "value") else value)

    await db.commit()
    await db.refresh(task)
    return TaskResponse.model_validate(task)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete Task")
async def delete_task(
    task_id: str,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Permanently delete a task by ID."""
    query = select(Task).where(Task.id == task_id, Task.owner_id == owner_id)
    result = await db.execute(query)
    task = result.scalar_one_or_none()

    if not task:
        raise CompanionNotFoundError(message=f"Task with ID {task_id!r} not found.")

    await db.delete(task)
    await db.commit()
