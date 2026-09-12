# Implementation Plan: Task Reminders, Categories, and Soft Deletion (Track B6 & Section 16.1)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Branch: `feature/backend-tasks-reminders-and-soft-delete`
Reference Architecture: `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` (Section 16.1 & Track B6)

---

## 1. Executive Summary & Goals

This plan executes the task schema extension and lifecycle safety requirements:
1. **Reminders & Categories (Track B6)**: Expand Task database model and API schemas with `category` and reminder offsets/timestamps matching Android's existing `TaskCategory` and reminder chips.
2. **Soft Deletion & User Scoping (Section 16.1)**: Introduce safe two-stage deletion (`is_deleted`, `deleted_at`, `owner_id`), a Recycle Bin (Trash) management API (list trash, restore, permanent purge), and a 15–30 day automated purge retention policy (`DATA_RETENTION_DAYS`).

---

## 2. Scope & Acceptance Criteria

### Category & Reminder Fields (Track B6)
- **Category Support**: Supported categories: `general`, `work`, `personal`, `dev`, `shopping`, `health` (matching Android's `TaskCategory`).
- **Reminder Offsets & Timestamps**:
  - `reminder_minutes_before: Optional[int]` (e.g., 0 for "at due time", 15 for "15 mins before", 60 for "1 hour before", 1440 for "1 day before").
  - `reminder_at: Optional[datetime]` (explicit or automatically computed as `due_date - timedelta(minutes=reminder_minutes_before)`).
- **Filtering**: `GET /api/v1/tasks?category=work` filters by category.

### Soft Deletion & Recycle Bin (Section 16.1)
- **Soft Delete Behavior**: `DELETE /api/v1/tasks/{id}` marks `is_deleted = True`, `deleted_at = utcnow()`. Row is preserved in database.
- **Active Filter Default**: `GET /api/v1/tasks` automatically excludes soft-deleted tasks (`is_deleted == False`).
- **User Scoping**: All operations strictly verify `owner_id`. A user can only list, restore, or purge their own soft-deleted tasks.
- **Trash Listing**: `GET /api/v1/tasks/trash` returns all soft-deleted tasks for the authenticated user, annotated with `expires_in_days` remaining before retention purge.
- **Task Restoration**: `POST /api/v1/tasks/{id}/restore` returns task to active state (`is_deleted = False`, `deleted_at = None`).
- **Permanent Purge**: `DELETE /api/v1/tasks/{id}/permanent` permanently deletes the task row from SQLite if it is currently in trash.
- **Retention Purge Policy**: `purge_expired_trash(retention_days=30)` permanently deletes soft-deleted records older than the configured retention period (`settings.DATA_RETENTION_DAYS`).

---

## 3. Step-by-Step Implementation Flow & Pseudocode

### Step 1: Database Mixin & Model Extension
```python
# backend/app/models/base.py
class SoftDeleteMixin:
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, server_default=func.false(), nullable=False, index=True)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True, default=None, index=True)

# backend/app/models/task.py
class Task(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
    title: Mapped[str]
    notes: Mapped[Optional[str]]
    category: Mapped[str] = mapped_column(String(32), default="general", server_default="general", nullable=False, index=True)
    status: Mapped[str]
    priority: Mapped[str]
    due_date: Mapped[Optional[datetime]]
    reminder_minutes_before: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    reminder_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
```

### Step 2: Database Migration (`002_tasks_reminders_and_soft_delete.py`)
- Non-destructive `op.add_column` calls with safe server defaults (`general`, `false`, and nullable fields).

### Step 3: Pydantic Schemas
- Add `TaskCategory(str, Enum)`.
- Update `TaskCreate`, `TaskUpdate`, `TaskResponse`.
- Add `TrashTaskResponse` with `expires_in_days: int`.
- Add `TrashListResponse`.

### Step 4: Endpoints Overhaul
- `list_tasks`: add `category` filter and `is_deleted.is_(False)` default.
- `create_task` / `update_task`: auto-calculate `reminder_at` if `reminder_minutes_before` and `due_date` are present.
- `delete_task`: set `task.is_deleted = True`, `task.deleted_at = datetime.now(timezone.utc)`.
- `list_trash`: select where `is_deleted.is_(True)` and `owner_id == owner_id`. Compute `expires_in_days`.
- `restore_task`: restore soft-deleted task.
- `permanent_delete_task`: execute hard `db.delete(task)`.

### Step 5: Automated Retention Service
- `backend/app/services/retention.py` with `purge_expired_trash(...)`.
- Add `DATA_RETENTION_DAYS: int = 30` to `backend/app/core/config.py`.

---

## 4. Affected Files

- `backend/app/models/base.py` — Add `SoftDeleteMixin`.
- `backend/app/models/task.py` — Add `category`, `reminder_minutes_before`, `reminder_at`, inherit `SoftDeleteMixin`.
- `backend/migrations/versions/002_tasks_reminders_and_soft_delete.py` — Alembic migration.
- `backend/app/schemas/task.py` — Update Pydantic schemas.
- `backend/app/api/v1/endpoints/tasks.py` — Implement soft delete, trash listing, restore, permanent delete, and reminder logic.
- `backend/app/core/config.py` — Add `DATA_RETENTION_DAYS` setting.
- `backend/app/services/retention.py` — Retention purge service & CLI helper.
- `backend/tests/test_tasks.py` — Negative & positive test coverage.
- `docs/01_Tracking/task.md` — Active task tracking.

---

## 5. Verification Plan

- [ ] Run Alembic migration `alembic upgrade head`.
- [ ] Run backend pytest suite verifying soft delete, trash, restore, retention, categories, and reminders.
- [ ] Verify Android compatibility (`.\gradlew.bat testDebugUnitTest`).
