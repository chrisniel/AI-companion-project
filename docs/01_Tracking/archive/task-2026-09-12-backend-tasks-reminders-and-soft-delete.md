# Archived Task: Task Reminders, Categories, and Soft Deletion (Track B6 & Section 16.1)

- Completed Date: 2026-09-12
- Target: Implement Task Category, Reminder offsets/timestamps, Soft Deletion with user scoping, Recycle Bin (Trash) endpoints, and 15-30 day retention purge policy.
- Verification: 26/26 backend pytest tests passing; 122/122 Android unit tests passing.

## Completed Checklist

### 1. Database Model & Migration (`migration-safety-review`)
- [x] Add `SoftDeleteMixin` (`is_deleted`, `deleted_at`) in `backend/app/models/base.py`
- [x] Add `category`, `reminder_minutes_before`, `reminder_at`, and inherit `SoftDeleteMixin` in `backend/app/models/task.py`
- [x] Author and apply Alembic migration `002_tasks_reminders_and_soft_delete.py`

### 2. Pydantic Schemas (`api-contract-review`)
- [x] Define `TaskCategory` enum (`general`, `work`, `personal`, `dev`, `shopping`, `health`)
- [x] Update `TaskCreate`, `TaskUpdate`, and `TaskResponse` with category and reminder fields
- [x] Add `TrashTaskResponse` (with `expires_in_days`) and `TrashListResponse`

### 3. API Endpoints & Soft Deletion (`feature-implementation`)
- [x] Update `GET /api/v1/tasks` to filter out soft-deleted items by default and support `category` query param
- [x] Update `POST /api/v1/tasks` and `PATCH /api/v1/tasks/{id}` with automatic `reminder_at` calculation
- [x] Convert `DELETE /api/v1/tasks/{id}` to soft delete (`is_deleted=True`, `deleted_at=now()`)
- [x] Implement `GET /api/v1/tasks/trash` (user-scoped Recycle Bin listing)
- [x] Implement `POST /api/v1/tasks/{id}/restore` (recover soft-deleted task)
- [x] Implement `DELETE /api/v1/tasks/{id}/permanent` (hard delete from trash)

### 4. Retention Policy & Automated Purge (`Section 16.1`)
- [x] Add `DATA_RETENTION_DAYS: int = 30` setting in `backend/app/core/config.py`
- [x] Create `purge_expired_trash` service and CLI helper in `backend/app/services/retention.py`

### 5. Verification & Testing (`test-creation`)
- [x] Add tests in `backend/tests/test_tasks.py` for categories, reminders, soft deletion, trash listing, restoration, permanent delete, retention purge, and owner isolation
- [x] Run full pytest suite and confirm all 26 backend tests pass

### 6. Android Client Sync (`HttpTasksRepository.kt`, `NetworkDtos.kt`, `TaskDateTimeConverter.kt`)
- [x] Extend `RemoteTaskDto` with `category`, `reminderMinutesBefore`, `reminderAt`, and `isDeleted`
- [x] Implement bidirectional reminder string-to-minute conversions in `TaskDateTimeConverter`
- [x] Update `LocalAiRuntimeClient` and `HttpTasksRepository` to transmit and deserialize category/reminders
- [x] Add unit tests in `TaskDateTimeConverterTest.kt` (124/124 Android tests passing)
- [x] Assemble fresh debug APK (`app-debug.apk`)

