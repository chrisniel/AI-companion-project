# Walkthrough: Task Reminders, Categories, and Soft Deletion

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Delivery of Task Categories, Reminder offsets/timestamps (Track B6), and Soft Deletion with user-scoping and 15–30 day automated retention purge (Section 16.1).
- Audience: Developer, maintainer, QA, mobile client integrators
- Status: Implemented & Verified
- Last Updated: 2026-09-12

---

## 1. What Was Delivered

- **Task Categories & Reminders (Track B6)**:
  - Supported categories: `general`, `work`, `personal`, `dev`, `shopping`, `health` (1:1 with Android's `TaskCategory`).
  - Reminder offsets (`reminder_minutes_before`) and timestamps (`reminder_at`). When creating or updating a task with `reminder_minutes_before` and `due_date`, the backend automatically computes `reminder_at = due_date - timedelta(minutes=reminder_minutes_before)`.
  - Category filtering: `GET /api/v1/tasks?category=work`.
  - **Android Client Synchronization**:
    - `RemoteTaskDto` updated with `category`, `reminderMinutesBefore`, `reminderAt`, and `isDeleted`.
    - `TaskDateTimeConverter` provides bidirectional mapping: `reminderToMinutes()` ("15m before" -> 15) and `minutesToReminder()` (15 -> "15m before").
    - `LocalAiRuntimeClient` serializes `category` and `reminder_minutes_before` over HTTP JSON payloads.
    - `HttpTasksRepository` transmits task category and reminder preferences upon creation/editing, and maps remote DTO responses back to mobile domain models.
- **Soft Deletion & User Scoping (Section 16.1)**:
  - `DELETE /api/v1/tasks/{id}` performs safe two-stage deletion by setting `is_deleted = True` and `deleted_at = utcnow()`.
  - Active listings (`GET /api/v1/tasks`) automatically exclude soft-deleted items.
  - Strict owner isolation: Users can only query, restore, or purge items belonging to their own `owner_id`.
- **Recycle Bin (Trash) APIs**:
  - `GET /api/v1/tasks/trash`: Lists soft-deleted tasks for the user, annotated with a dynamically computed `expires_in_days` retention countdown.
  - `POST /api/v1/tasks/{id}/restore`: Restores soft-deleted tasks back to active state (`is_deleted = False`, `deleted_at = None`).
  - `DELETE /api/v1/tasks/{id}/permanent`: Permanently deletes task row from SQLite; rejected with 404 if task is not in trash.
- **Automated Retention Policy**:
  - `DATA_RETENTION_DAYS = 30` setting in `backend/app/core/config.py`.
  - `purge_expired_trash()` service in `backend/app/services/retention.py` with standalone CLI execution (`python -m app.services.retention --days 30`).
- **Zero Data Loss Migration**:
  - Alembic migration `002_tasks_reminders_and_soft_delete.py` applied non-destructively to `companion.db` with safe server defaults.

## 2. Files Changed

- `backend/app/models/base.py` — Added `SoftDeleteMixin` (`is_deleted`, `deleted_at`).
- `backend/app/models/task.py` — Added `category`, `reminder_minutes_before`, `reminder_at`, and inherited `SoftDeleteMixin`.
- `backend/migrations/versions/002_tasks_reminders_and_soft_delete.py` — Alembic migration for columns and indexes.
- `backend/app/schemas/task.py` — Added `TaskCategory`, `TrashTaskResponse`, `TrashListResponse`, and updated task schemas.
- `backend/app/api/v1/endpoints/tasks.py` — Implemented soft deletion, category filtering, reminder calculation, trash listing, restore, and permanent purge.
- `backend/app/core/config.py` — Added `DATA_RETENTION_DAYS: int = 30` configuration.
- `backend/app/services/retention.py` — Created retention purge service, `calculate_remaining_days()`, and CLI runner.
- `backend/app/services/__init__.py` — Package initialization for services.
- `backend/tests/test_tasks.py` — Added comprehensive tests for categories, reminders, soft-delete lifecycle, and retention purge.
- `android/app/src/main/java/com/example/data/network/dto/NetworkDtos.kt` — Extended `RemoteTaskDto` with category, reminderMinutesBefore, reminderAt, and isDeleted.
- `android/app/src/main/java/com/example/data/util/TaskDateTimeConverter.kt` — Added `reminderToMinutes()` and `minutesToReminder()` conversions.
- `android/app/src/main/java/com/example/data/network/LocalAiRuntimeClient.kt` — Serialized category and reminder minutes before in task create/update calls and JSON parser.
- `android/app/src/main/java/com/example/data/repository/HttpTasksRepository.kt` — Integrated category and reminder payloads into `saveTask()` and mapped them in `toMobileTask()`.
- `android/app/src/test/java/com/example/TaskDateTimeConverterTest.kt` — Added unit tests verifying reminder string-to-minute conversions.
- `CHANGELOG.md` — Documented Pass 5 under `## Unreleased`.
- `docs/01_Tracking/task.md` — Updated active tracking state.

## 3. How the Logic Works

1. **Event trigger**: Client submits a task modification, deletion, or trash action.
2. **Validation**:
   - `category` is validated against `TaskCategory` enum.
   - For soft delete, task must exist, be active (`is_deleted == False`), and belong to the authenticated `owner_id`.
   - For restore and permanent delete, task must exist in trash (`is_deleted == True`) and belong to `owner_id`.
3. **Core processing**:
   - **Creation/Update**: If `reminder_minutes_before` is provided with `due_date`, `reminder_at` is auto-computed as `due_date - timedelta(minutes=offset)`.
   - **Deletion**: Instead of issuing an SQL `DELETE`, the handler updates `is_deleted = True` and sets `deleted_at = datetime.now(timezone.utc)`.
   - **Trash Listing**: Soft-deleted tasks are retrieved and annotated with `expires_in_days = max(0, retention_days - elapsed_days)`.
   - **Retention Purge**: Sweeps records where `is_deleted = True AND deleted_at <= now - retention_days`.
4. **Completion**: Active endpoints return standard `TaskResponse`, trash returns `TrashListResponse`, and deletes return HTTP 204.
5. **Recovery/cancellation**: If an active task was accidentally deleted, calling `POST /api/v1/tasks/{id}/restore` resets `is_deleted = False` and `deleted_at = None`, restoring it to the active list.

## 4. Key Concepts

- **Soft Deletion**: Marking records as logically inactive with a timestamp instead of dropping rows immediately from the database. Prevents accidental client-side data loss and powers Recycle Bin / Undo patterns.
- **User Scoping (BOLA Prevention)**: Enforcing that all queries for active, trash, restore, or purge actions include `WHERE owner_id == current_user`, ensuring users can never inspect or restore another account's deleted items.
- **Retention Window**: A time-bounded buffer (e.g. 30 days) during which soft-deleted items remain restorable. Once the retention period lapses, a scheduled background purge permanently removes the records to conserve storage.

## 5. Verification Steps

### Automated Checks

- [x] Backend Pytest Suite: `.\.venv\Scripts\python -m pytest` in `backend/` — 26/26 passed in 0.53s.
- [x] Android Unit Test Suite: `.\gradlew.bat testDebugUnitTest` in `android/` — 122/122 passed in 1s.
- [x] Alembic Migration: `.\.venv\Scripts\alembic upgrade head` — successfully applied `002_tasks_reminders_and_soft_delete`.
- [x] SQLite PRAGMA Inspection: Confirmed columns `category`, `reminder_minutes_before`, `reminder_at`, `is_deleted`, `deleted_at` exist in `companion.db`.

### Manual / User-Owned Checks

- [ ] Step 1: Start Uvicorn backend (`.\.venv\Scripts\python -m uvicorn app.main:app --port 8000`).
- [ ] Step 2: In Android, create a task with category `Work` and reminder `15 mins before`.
- [ ] Step 3: Delete the task in Android; verify the task row still exists in SQLite `companion.db` with `is_deleted = 1`.
- [ ] Step 4: Query `GET /api/v1/tasks/trash` via curl/Postman to see the deleted task and its `expires_in_days`.

## 6. Safe Customization & Invariants

- **Tunable parameters**:
  - `DATA_RETENTION_DAYS`: Configured in `backend/app/core/config.py` or `.env` (default: 30 days; safe range: 15–90 days).
- **Invariants**:
  - `is_deleted == False` must always be enforced on default task queries to prevent showing deleted tasks to users.
  - Soft-deleted items must remain strictly partitioned by `owner_id`.
  - Permanent delete is strictly prohibited unless an item already resides in the Trash (`is_deleted == True`).

## 7. Troubleshooting

- **Symptom**: Task is deleted on Android but still present in SQLite database.
  - **Likely cause**: This is expected behavior under Section 16.1 Soft Deletion.
  - **Resolution**: Check `is_deleted` column. If `1`, it is in the Recycle Bin and will be purged automatically after 30 days.
- **Symptom**: `POST /api/v1/tasks/{id}/restore` returns 404.
  - **Likely cause**: The task does not exist, belongs to another user, or was already permanently purged.
  - **Resolution**: Verify task ID in `GET /api/v1/tasks/trash`.
