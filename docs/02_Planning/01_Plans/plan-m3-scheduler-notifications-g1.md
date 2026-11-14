# Implementation Plan: Milestone M3 Batch G1 — Backend SchedulerService, Reminders/Alarms/Routines, Quiet Hours, Notification Backlog & OpenAPI/Dart SDK Parity

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Plan ID:** `PLAN-M3-SCHEDULER-NOTIFICATIONS-G1`
- **Status:** Phase 2 Implemented & Verified; Phase 3 Closure Prepared (`feature/m3-scheduler-notifications-g1` — Ready for Phase 4 Review)
- **Delivery Level:** Level B — Planned Autonomous (with Level C database schema migration `015_scheduler_notifications_and_routines`)
- **Target Milestone:** M3 — Intelligence & Productivity & M2 — Native Host & Multi-Profile (`PC-SCHED-001`..`005`, `PC-HOST-003`, `PC-API-001`, `DEBT-V1-08`)
- **Work Breakdown Structure IDs:** `PC-SCHED-001` (`SchedulerService` in-process asyncio tick & lifecycle), `PC-SCHED-002` (Reminders & Alarms distinct entities & CRUD), `PC-SCHED-003` (Quiet Hours Policy Engine), `PC-SCHED-004` (Missed-Event Reconciliation & Snooze/Acknowledge/Dismiss Semantics), `PC-SCHED-005` (Routines & Check-Ins with deterministic fallback & zero trigger delay), `PC-HOST-003` (Runtime-owned durable Notification Backlog & lifecycle APIs), `PC-API-001` (OpenAPI 3.1 + `companion_api` Dart SDK parity for Tasks, Reminders, Alarms, Routines, Notifications & Quiet Hours), `DEBT-V1-08` (Periodic sweep of expired short-term memories in `SchedulerService` / maintenance worker)
- **Scope Mode:** New Feature & Schema Extension — Adds Migration `015_scheduler_notifications_and_routines` (`reminders`, `alarms`, `routines`, `notification_events`, and per-Profile Quiet Hours columns on `profiles`), `SchedulerService` asyncio runtime worker with zero-dependency timezone resolution, Quiet Hours policy engine, missed-event catch-up reconciliation, expired short-term memory sweep (`DEBT-V1-08`), REST APIs, `ProfilePurgeService` cascade, and OpenAPI 3.1 + `companion_api` Dart SDK parity (promoting `/api/v1/tasks*` from `UNMAPPED_FUTURE_ROUTES` alongside the 30 new scheduling/notification/quiet-hours routes).
- **Target Files (Phase 2 Execution Scope — NOT modified during Phase 1):**
  - `backend/app/models/profile.py`
  - `backend/app/models/reminder.py` (new)
  - `backend/app/models/alarm.py` (new)
  - `backend/app/models/routine.py` (new)
  - `backend/app/models/notification_event.py` (new)
  - `backend/app/models/__init__.py`
  - `backend/app/db/base.py`
  - `backend/migrations/versions/015_scheduler_notifications_and_routines.py` (new)
  - `backend/app/core/config.py`
  - `backend/app/schemas/scheduling.py` (new)
  - `backend/app/services/scheduler/__init__.py` (new)
  - `backend/app/services/scheduler/service.py` (new)
  - `backend/app/services/profile_purge_service.py`
  - `backend/app/api/v1/endpoints/profiles.py`
  - `backend/app/api/v1/endpoints/tasks.py`
  - `backend/app/api/v1/endpoints/scheduling.py` (new)
  - `backend/app/api/v1/router.py`
  - `backend/app/main.py`
  - `contracts/openapi/openapi.json`
  - `scripts/check_dart_openapi_parity.py`
  - `scripts/tests/test_check_dart_openapi_parity.py`
  - `frontend/flutter/packages/companion_api/lib/companion_api.dart`
  - `frontend/flutter/packages/companion_api/lib/dto/task_dto.dart` (new)
  - `frontend/flutter/packages/companion_api/lib/dto/scheduling_dto.dart` (new)
  - `frontend/flutter/packages/companion_api/lib/client/companion_client.dart`
  - `backend/tests/test_scheduler_service.py` (new)
  - `backend/tests/test_scheduling_api.py` (new)
  - `backend/tests/test_schema_lifecycle.py`
  - `backend/tests/test_prepare_database_schema_backup.py`
  - `backend/tests/test_profile_deletion.py`
  - `frontend/flutter/packages/companion_api/test/companion_client_test.dart`
  - Canonical docs & tracking synced in Phase 3 (`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`, `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`, `docs/02_Planning/00_Master/`, `docs/01_Tracking/`, `CHANGELOG.md`, `docs/03_Walkthroughs/`)
- **Branch:** `feature/m3-scheduler-notifications-g1`
- **Archived Branch Tracker:** `docs/01_Tracking/archive/task-feature-m3-scheduler-notifications-g1.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m3-scheduler-notifications-g1.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:**
  Deliver **Batch G1** of the Human-approved two-batch split (Approach B) for Milestone M3 Scheduling and M2 Native Host Notification Backlog: establish the backend `SchedulerService`, persistent SQLite/SQLAlchemy models and REST APIs for distinct **Reminders**, **Alarms**, and **Routines**, **per-Profile Quiet Hours** enforcement, **missed-event catch-up reconciliation**, a runtime-owned **durable Notification Backlog** (`PC-HOST-003`), periodic expiration sweep of short-term memories (`DEBT-V1-08`), and 100% **OpenAPI 3.1 + `companion_api` Dart SDK parity** so **Batch G2** can build the Desktop Schedule & Tasks UI and Native Windows Toast adapter directly on top of verified contracts.

- **Two-Batch Split Context (Approach B):**
  - **Batch G1 (`feature/m3-scheduler-notifications-g1`, This Delivery):** Backend runtime scheduler, schema Migration `015`, REST APIs, Quiet Hours, missed-event catch-up, notification backlog, `DEBT-V1-08` expired memory sweep, OpenAPI contract, and `companion_api` Dart SDK (promoting all 8 existing `/api/v1/tasks*` routes out of `UNMAPPED_FUTURE_ROUTES` into `CompanionClient` alongside the 30 new scheduling/notification/quiet-hours routes).
  - **Batch G2 (Next Delivery After G1 Merge):** Flutter Desktop **Schedule & Tasks** workspace screen (`PC-CLIENT-008`), Native Windows Toast Notification adapter (`PC-CLIENT-012`, `DEBT-V1-02`), and Desktop Backlog Activity / Notification Center UI (`docs/05_Design/06_Notifications_and_Backlog_Activity.md`).

- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md) — Normative D10 domain specification (`D-SHARED-SCHED-01`, `D-SHARED-SCHED-02`, `D-SHARED-SCHED-03`), entity separation (Tasks, Reminders, Alarms, Routines), Quiet Hours policy, Missed-Event catch-up, Snooze/Acknowledge/Dismiss semantics, and Profile isolation.
  - [`docs/04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md`](../../04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md) — D10 ADR establishing best-effort wake guarantees and domain invariants.
  - [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md) — `PC-HOST-003` runtime-owned durable notification backlog vs Flutter-owned presentation boundary.
  - [`docs/05_Design/06_Notifications_and_Backlog_Activity.md`](../../05_Design/06_Notifications_and_Backlog_Activity.md) — Urgency hierarchy (Alarms bypass quiet hours, Reminders respect quiet hours unless overridden, Routines suppressed in quiet hours), default Quiet Hours range (`22:00` to `07:00`), Backlog Activity semantics (`unread`, `missed`, `suppressed`, `Clear All`, `[ Mark Done ]` completing linked Tasks).
  - [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md) — `DEBT-V1-08` periodic sweep of expired temporary/short-term memories.

- **Concrete Deliverables:**
  1. Alembic Migration `015_scheduler_notifications_and_routines` creating `reminders`, `alarms`, `routines`, and `notification_events` tables plus Quiet Hours columns on `profiles`, with `PRAGMA foreign_key_check` guards, explicit SQLite trigger cycling around `profiles` alteration, and fail-closed `downgrade()`.
  2. SQLAlchemy ORM models (`Reminder`, `Alarm`, `Routine`, `NotificationEvent`, and `Profile` quiet-hours fields + `__init__` defaults) wired into `app/models/__init__.py`, `app/db/base.py`, and `ProfilePurgeService`.
  3. `SchedulerService` (`backend/app/services/scheduler/service.py`) integrated into FastAPI `lifespan` (`backend/app/main.py`) with zero-dependency `resolve_timezone()` helper, startup missed-event reconciliation, periodic due evaluation, Quiet Hours evaluation (`[start, end)` half-open interval), recurring Alarm re-arm semantics, deterministic Routine emission using `fallback_message` (zero LLM trigger wait), Task due-reminder bridging + `[ Mark Done ]` synchronization, and `DEBT-V1-08` expired short-term memory sweep.
  4. Fail-closed Profile-scoped REST endpoints across all 30 new routes (`Reminders`, `Alarms`, `Routines`, `Notifications`, and `/api/v1/profiles/me/quiet-hours`).
  5. Updated `contracts/openapi/openapi.json`, flat `Task` + `Scheduling` DTOs (with explicit `TrashTaskResponse` fields and `clear_*` update semantics) and all 38 route methods (`8` Tasks + `30` Scheduling/Notifications/Quiet Hours) in `CompanionClient`, updated `scripts/check_dart_openapi_parity.py`, and comprehensive backend + Dart unit/integration test suites.

- **Explicit Out-of-Scope:**
  - Flutter Desktop UI screens/widgets, Backlog Activity drawer UI, and Native Windows Toast Notification OS integration (`PC-CLIENT-008`, `PC-CLIENT-012`, `DEBT-V1-02` — deferred to Batch G2).
  - Modifying `backend/requirements.txt`, `backend/requirements.lock`, or `pyproject.toml` (Python dependencies remain frozen; timezone resolution is self-contained with zero new packages).
  - LLM autonomous tool-calling / D9 5-stage deterministic policy pipeline (`PC-POLICY-001`..`005` — deferred to dedicated M3 Policy & Tooling batch).
  - Mobile Android (`android/`) WorkManager / AlarmManager client work (follow-on).

---

## 2. Architecture & Technical Approach

### Current Findings & Technical Baseline

| Observation / Evidence | Verified Interpretation |
| --- | --- |
| `backend/app/models/task.py` & `backend/app/api/v1/endpoints/tasks.py` already implement soft-deletable profile-scoped `Task` CRUD with `due_date`, `reminder_minutes_before`, and `reminder_at`. | `Task` exists cleanly, but no background worker fires `reminder_at`, no separate `Reminder`, `Alarm`, `Routine`, or `NotificationEvent` tables exist, completing/deleting a task does not resolve pending notifications, and `/api/v1/tasks*` routes reside in `UNMAPPED_FUTURE_ROUTES`. |
| Windows `backend\.venv\Scripts\python.exe` raises `ZoneInfoNotFoundError` even for `ZoneInfo("UTC")` because `tzdata` is absent from `backend/requirements.txt` and `backend/requirements.lock` (`--require-hashes`, CI-verified by `scripts/python_dependency_lock.py`). | `SchedulerService` MUST provide a self-contained zero-dependency `resolve_timezone(tz_name)` helper (`UTC`/fixed-offset/`zoneinfo` attempt + built-in deterministic IANA/DST table fallback) without adding `tzdata` to `requirements.lock`. |
| At Alembic revision `014`, `profiles` has `trg_profiles_active_character_owner_insert`, `trg_profiles_active_character_owner_update`, `trg_character_instances_deactivate_clear_profile` (referencing `profiles`), `uq_profiles_single_default`, and `Profile.__init__` explicitly sets defaults in Python. | Migration `015` MUST drop and recreate those three triggers around any `op.batch_alter_table("profiles")` call (following `012_character_mood_and_emotion.py`), enforce a fail-closed data-loss check in `downgrade()`, and initialize quiet-hours defaults in `Profile.__init__`. |
| `scripts/check_dart_openapi_parity.py` (`parse_dart_class`) scans only `final` fields and `json['...']` keys inside each target class body (no Dart inheritance traversal, fails on extra `final` fields), and `TaskUpdate` marks `title`/`category`/`status`/`priority` omittable-only (not nullable). | `TrashTaskResponse` in `task_dto.dart` MUST declare all 15 `final` fields directly inside its class body; `TaskUpdate.toJson()` MUST omit non-nullable fields when `null` and use optional `toJson({bool clearNotes = false, ...})` parameters for nullable clearing. |
| `backend/app/api/v1/endpoints/profiles.py` defines `@router.get("/{profile_id}")` after `@router.get("/deleted")`, and `PATCH /profiles/{profile_id}` uses `require_host_admin`. | Session-scoped Quiet Hours routes (`GET /api/v1/profiles/me/quiet-hours`, `PATCH /api/v1/profiles/me/quiet-hours`) MUST be registered before `{profile_id}` in `profiles.py` using `Depends(get_current_profile_session)`. |
| `backend/app/main.py` lines 255–279 spawn a cancellable `asyncio.create_task` loop in `lifespan` after DB init, and `ProfilePurgeService` hard-deletes child tables in `purge_profile()` plus retention sweeps in `execute_maintenance_purge()`. | `SchedulerService` follows the exact same `lifespan` background-task pattern, and `ProfilePurgeService` deletes `NotificationEvent`, `Reminder`, `Alarm`, and `Routine` before `Task` in `purge_profile()` and includes them + expired temporary memories (`DEBT-V1-08`) in maintenance sweeps. |

### Architectural Approach

1. **Zero-Dependency Timezone Resolution (`P1-1`):**
   - Implement `resolve_timezone(tz_name: str) -> tzinfo` in `backend/app/services/scheduler/service.py` with zero external package dependencies (`tzdata` NOT required):
     1. Map `"UTC"`, `"Etc/UTC"`, `"GMT"`, `"Z"` directly to `datetime.timezone.utc`.
     2. Parse explicit fixed offsets (`+HH:MM`, `-HH:MM`, `UTC+HH:MM`, `UTC-HH:MM`) via `datetime.timezone(timedelta(...))`.
     3. Attempt `zoneinfo.ZoneInfo(tz_name)` first (succeeds automatically on Linux hosts/containers or any system with OS tzdb).
     4. On `ZoneInfoNotFoundError` (standard on Windows without `tzdata`), fall back to a deterministic built-in `tzinfo` catalog supporting fixed-offset and DST rules for common IANA zones (`America/New_York`, `America/Chicago`, `America/Denver`, `America/Los_Angeles`, `America/Phoenix`, `America/Anchorage`, `Pacific/Honolulu`, `Europe/London`, `Europe/Paris`, `Europe/Berlin`, `Asia/Tokyo`, `Asia/Shanghai`, `Asia/Singapore`, `Asia/Manila`, `Asia/Kolkata`, `Australia/Sydney`, etc.).
     5. API Pydantic validators call `validate_timezone_name(value)` raising `ValueError` (HTTP `422`) on unrecognized strings; DB read paths fall back safely to `datetime.timezone.utc` if a historical value cannot be resolved.

2. **Four Distinct Entities + Unified Durable Notification Backlog (`D10`, `PC-HOST-003`, `D-SHARED-SCHED-01`):**
   - **`Task`** remains an action item (`pending`, `in_progress`, `completed`, `cancelled`), optionally carrying `reminder_at`.
   - **`Reminder`** (`reminders`): scheduled alert (`scheduled`, `fired`, `snoozed`, `acknowledged`, `dismissed`, `missed`, `cancelled`), standalone or linked via nullable `task_id` FK (`tasks.id`, `ON DELETE SET NULL`), default `bypass_quiet_hours=False` (`urgency="standard"`), optional caller-supplied validated UUIDv4 `id` and `origin` (`"host" | "mobile"`, returning `409 Conflict` on duplicate ID per `D-SHARED-SCHED-01`).
   - **`Alarm`** (`alarms`): high-urgency interrupt (`armed`, `ringing`, `snoozed`, `acknowledged`, `dismissed`, `missed`) supporting one-shot `scheduled_at` or recurring `time_of_day` (`"HH:MM"`) + `recurrence_days` (`0..6`, `0 = Monday .. 6 = Sunday`), default `bypass_quiet_hours=True` (`urgency="high"`), optional caller-supplied validated UUIDv4 `id` and `origin` (`409` on duplicate).
   - **`Routine`** (`routines`): bounded companion check-in (`time_of_day`, `recurrence_days` `0..6`, `timezone`, required `fallback_message`, optional `prompt_template`), `enabled` flag, default `bypass_quiet_hours=False` (`urgency="informational"`), and computed `next_run_at`.
   - **`NotificationEvent`** (`notification_events`): **runtime-owned durable Notification Backlog** (`PC-HOST-003`) recording emitted, quiet-hours-suppressed, and missed-catchup items across `reminder`, `alarm`, `routine`, and `task_reminder`.

3. **Quiet Hours Policy Engine (`PC-SCHED-003`):**
   - Stored per `Profile` (`quiet_hours_enabled: bool = False`, `quiet_hours_start: str = "22:00"`, `quiet_hours_end: str = "07:00"`, `quiet_hours_timezone: str = "UTC"`).
   - `is_within_quiet_hours(profile, now_utc)` converts `now_utc` via `resolve_timezone(profile.quiet_hours_timezone)` and checks a **half-open local-time interval `[start, end)`**:
     - If `start < end` (same-day window): `start <= local_time < end`.
     - If `start > end` (overnight wrap, e.g., `22:00`–`07:00`): `local_time >= start or local_time < end`. Thus `07:00:00` is strictly *outside* `22:00`–`07:00` so morning routines/reminders at `07:00` are not suppressed.
     - Validation on `QuietHoursUpdate` rejects identical `start == end` when enabling quiet hours (or treats zero-width window as inactive).
   - Policy outcomes when `is_within_quiet_hours` is `True`:
     - **Alarms** (or any entity with explicit `bypass_quiet_hours=True`): fire immediately (`NotificationEvent.status="unread"`, `delivery_policy="immediate"`).
     - **Reminders** (`bypass_quiet_hours=False`): transition Reminder `status="fired"`, `fired_at=now`, and emit `NotificationEvent(status="suppressed_quiet_hours", delivery_policy="quiet_hours_suppressed")` for quiet Backlog visibility without intrusive toast alarm.
     - **Routines** (`bypass_quiet_hours=False`): suppress active check-in toast, advance `next_run_at` to the next future occurrence (`> now`), set `last_status="suppressed_quiet_hours"`, and emit `NotificationEvent(status="suppressed_quiet_hours", delivery_policy="quiet_hours_suppressed")`.

4. **Missed-Event Catch-Up Reconciliation, Recurring Alarm Re-Arm, Task Bridge & Snooze/Acknowledge/Dismiss (`PC-SCHED-004`, `P2-2`, `P2-3`):**
   - Configurable `SCHEDULER_MISSED_GRACE_SECONDS` (default `300` seconds) and `SCHEDULER_POLL_INTERVAL_SECONDS` (default `15.0` seconds).
   - **Missed vs Live Evaluation:** Items whose active target time is strictly older than `now - grace_window` transition/record as missed catch-up (`status="missed"`, `NotificationEvent(status="missed_catchup", delivery_policy="missed_catchup", is_missed_catchup=True)`) without replaying stale loud ring storms; recurring Alarms and Routines advance `scheduled_at` / `next_run_at` strictly past `now` so they never loop.
   - **Recurring `Alarm` Creation & Re-Arm (`P2-2`):**
     - Creating or updating an enabled recurring `Alarm` (`recurrence_days` non-empty and `time_of_day` set) auto-computes `scheduled_at = compute_next_occurrence(time_of_day, recurrence_days, timezone, after=now)` whenever `scheduled_at` is omitted or `<= now`.
     - Acknowledging or dismissing an enabled **recurring** `Alarm` (directly or via its `NotificationEvent`) sets `acknowledged_at = now` (on acknowledge), clears `snoozed_until = None`, advances `scheduled_at = compute_next_occurrence(..., after=now)`, and re-arms `status = "armed"`. One-shot alarms transition to terminal `status = "acknowledged"` / `"dismissed"` with `enabled = False`.
   - **`Task.reminder_at` Bridging & `[ Mark Done ]` Completion Synchronization (`P2-3`):**
     - `SchedulerService` evaluates active `Task` rows where `Task.is_deleted.is_(False)` and `Task.status.in_(("pending", "in_progress"))` and `Task.reminder_at <= now`.
     - Emitted `NotificationEvent` sets `triggered_at = _as_utc(task.reminder_at)` and deduplicates against existing non-deleted `NotificationEvent` rows matching `(profile_id, source_type="task_reminder", source_id=task.id, triggered_at=_as_utc(task.reminder_at))`, so the same timestamp never fires twice while editing `Task.reminder_at` to a new timestamp fires cleanly once due.
     - Acting on a `NotificationEvent` propagates cleanly to its backing entity: `snooze` updates `Reminder`/`Alarm` `snoozed_until` or `Task.reminder_at`; `acknowledge` on a `task_reminder` (or on a task-linked `Reminder` when `complete_task=True`, default `True`) marks the active linked `Task.status = "completed"`; `dismiss` resolves the notification and dismisses/re-arms the active `Reminder`/`Alarm` (or leaves `Task` active).
     - Completing, cancelling, or soft-deleting a `Task` in `backend/app/api/v1/endpoints/tasks.py` cancels linked `scheduled`/`snoozed` `Reminder` rows and marks active `task_reminder` notifications `dismissed`.
   - **Zero Trigger Delay (`D-SHARED-SCHED-03`):** `SchedulerService` never awaits LLM inference in its scheduler loop; Routine notifications emit immediately with `routine.fallback_message`.
   - **Expired Temporary Memory Sweep (`DEBT-V1-08`):** `SchedulerService` runs `sweep_expired_memories(db, now)` on startup and periodic cadence, soft-deleting memories with `Memory.deleted_at.is_(None)`, `Memory.expires_at.is_not(None)`, and `Memory.expires_at <= now` (`is_deleted=True`, `deleted_at=now`) so `ProfilePurgeService` permanently purges them after retention.

### Exact API Contract & Dart SDK Parity Map (`P2-1`, `PC-API-001`)

All 38 routes below (8 promoted existing Task routes + 30 new Batch G1 routes) will be present in `contracts/openapi/openapi.json`, implemented in `CompanionClient` (`frontend/flutter/packages/companion_api/lib/client/companion_client.dart`), and enforced by `scripts/check_dart_openapi_parity.py`:

| Domain | Method & Path | OpenAPI Schemas | `CompanionClient` Method |
| --- | --- | --- | --- |
| Tasks (Promoted) | `GET /api/v1/tasks` | `TaskListResponse` | `listTasks` |
| Tasks (Promoted) | `POST /api/v1/tasks` | `TaskCreate`, `TaskResponse` | `createTask` |
| Tasks (Promoted) | `GET /api/v1/tasks/trash` | `TrashListResponse` | `listTrashTasks` |
| Tasks (Promoted) | `GET /api/v1/tasks/{task_id}` | `TaskResponse` | `getTask` |
| Tasks (Promoted) | `PATCH /api/v1/tasks/{task_id}` | `TaskUpdate`, `TaskResponse` | `updateTask` |
| Tasks (Promoted) | `DELETE /api/v1/tasks/{task_id}` | `204 No Content` | `deleteTask` |
| Tasks (Promoted) | `POST /api/v1/tasks/{task_id}/restore` | `TaskResponse` | `restoreTask` |
| Tasks (Promoted) | `DELETE /api/v1/tasks/{task_id}/permanent` | `204 No Content` | `permanentlyDeleteTask` |
| Quiet Hours | `GET /api/v1/profiles/me/quiet-hours` | `QuietHoursOut` | `getQuietHours` |
| Quiet Hours | `PATCH /api/v1/profiles/me/quiet-hours` | `QuietHoursUpdate`, `QuietHoursOut` | `updateQuietHours` |
| Reminders | `GET /api/v1/reminders` | `ReminderListOut` | `listReminders` |
| Reminders | `POST /api/v1/reminders` | `ReminderCreate`, `ReminderOut` | `createReminder` |
| Reminders | `GET /api/v1/reminders/{reminder_id}` | `ReminderOut` | `getReminder` |
| Reminders | `PATCH /api/v1/reminders/{reminder_id}` | `ReminderUpdate`, `ReminderOut` | `updateReminder` |
| Reminders | `DELETE /api/v1/reminders/{reminder_id}` | `204 No Content` | `deleteReminder` |
| Reminders | `POST /api/v1/reminders/{reminder_id}/snooze` | `SnoozeRequest`, `ReminderOut` | `snoozeReminder` |
| Reminders | `POST /api/v1/reminders/{reminder_id}/acknowledge` | `AcknowledgeRequest`, `ReminderOut` | `acknowledgeReminder` |
| Reminders | `POST /api/v1/reminders/{reminder_id}/dismiss` | `ReminderOut` | `dismissReminder` |
| Alarms | `GET /api/v1/alarms` | `AlarmListOut` | `listAlarms` |
| Alarms | `POST /api/v1/alarms` | `AlarmCreate`, `AlarmOut` | `createAlarm` |
| Alarms | `GET /api/v1/alarms/{alarm_id}` | `AlarmOut` | `getAlarm` |
| Alarms | `PATCH /api/v1/alarms/{alarm_id}` | `AlarmUpdate`, `AlarmOut` | `updateAlarm` |
| Alarms | `DELETE /api/v1/alarms/{alarm_id}` | `204 No Content` | `deleteAlarm` |
| Alarms | `POST /api/v1/alarms/{alarm_id}/snooze` | `SnoozeRequest`, `AlarmOut` | `snoozeAlarm` |
| Alarms | `POST /api/v1/alarms/{alarm_id}/acknowledge` | `AlarmOut` | `acknowledgeAlarm` |
| Alarms | `POST /api/v1/alarms/{alarm_id}/dismiss` | `AlarmOut` | `dismissAlarm` |
| Routines | `GET /api/v1/routines` | `RoutineListOut` | `listRoutines` |
| Routines | `POST /api/v1/routines` | `RoutineCreate`, `RoutineOut` | `createRoutine` |
| Routines | `GET /api/v1/routines/{routine_id}` | `RoutineOut` | `getRoutine` |
| Routines | `PATCH /api/v1/routines/{routine_id}` | `RoutineUpdate`, `RoutineOut` | `updateRoutine` |
| Routines | `DELETE /api/v1/routines/{routine_id}` | `204 No Content` | `deleteRoutine` |
| Routines | `POST /api/v1/routines/{routine_id}/run` | `NotificationEventOut` | `runRoutineNow` |
| Notifications | `GET /api/v1/notifications` | `NotificationListOut` | `listNotifications` |
| Notifications | `POST /api/v1/notifications/clear-all` | `NotificationClearResponse` | `clearAllNotifications` |
| Notifications | `POST /api/v1/notifications/{event_id}/read` | `NotificationEventOut` | `markNotificationRead` |
| Notifications | `POST /api/v1/notifications/{event_id}/acknowledge` | `AcknowledgeRequest`, `NotificationEventOut` | `acknowledgeNotification` |
| Notifications | `POST /api/v1/notifications/{event_id}/dismiss` | `NotificationEventOut` | `dismissNotification` |
| Notifications | `POST /api/v1/notifications/{event_id}/snooze` | `SnoozeRequest`, `NotificationEventOut` | `snoozeNotification` |

*(Plus `QuietHoursUpdate`, `ReminderUpdate`, `AlarmUpdate`, and `RoutineUpdate` support explicit boolean `clear_*` flags where nullable fields can be cleared, matching `MemoryUpdate.clear_expires_at`.)*

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/app/models/reminder.py`, `alarm.py`, `routine.py`, `notification_event.py` & [MODIFY] `profile.py`, `models/__init__.py`, `db/base.py`
- **Primary Responsibility:** Define SQLAlchemy 2 ORM models for `Reminder`, `Alarm`, `Routine`, `NotificationEvent`, and per-Profile Quiet Hours fields.
- **Planned Change:**
  - `Profile` (`profile.py`): add `quiet_hours_enabled` (`Boolean`, default `False`, server_default `"0"`), `quiet_hours_start` (`String(5)`, default `"22:00"`, server_default `"22:00"`), `quiet_hours_end` (`String(5)`, default `"07:00"`, server_default `"07:00"`), `quiet_hours_timezone` (`String(64)`, default `"UTC"`, server_default `"UTC"`), **and** assign all four defaults in `Profile.__init__` so newly instantiated `Profile()` objects have non-`None` values before flush.
  - `Reminder`: `UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin` + `task_id` nullable FK (`tasks.id`, `ondelete="SET NULL"`), `title`, `notes`, `scheduled_at`, `timezone`, `status`, `snoozed_until`, `bypass_quiet_hours` (`False`), `origin` (`"host"`), `fired_at`, `acknowledged_at`.
  - `Alarm`: `UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin` + `label`, `scheduled_at`, `time_of_day`, `recurrence_days`, `timezone`, `enabled`, `status`, `snoozed_until`, `bypass_quiet_hours` (`True`), `origin` (`"host"`), `last_fired_at`, `acknowledged_at`.
  - `Routine`: `UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin` + `title`, `prompt_template`, `fallback_message`, `time_of_day`, `recurrence_days`, `timezone`, `enabled`, `bypass_quiet_hours` (`False`), `next_run_at`, `last_run_at`, `last_status`.
  - `NotificationEvent`: `UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin` + `source_type`, `source_id`, `urgency`, `title`, `body`, `status`, `delivery_policy`, `is_missed_catchup`, `triggered_at`, `read_at`, `resolved_at`, plus index `(profile_id, source_type, source_id, triggered_at)`.
- **Invariants to Preserve:** Strict `profile_id` isolation on every query; soft-delete consistency; UTC normalization across SQLite naive/aware datetimes.

### [ADD] `backend/migrations/versions/015_scheduler_notifications_and_routines.py`
- **Primary Responsibility:** Forward and backward SQLite schema migration from `014_conversation_summaries_and_compaction`.
- **Planned Change:**
  - `PRAGMA foreign_key_check` preflight and postflight checks.
  - Drop and recreate `trg_character_instances_deactivate_clear_profile`, `trg_profiles_active_character_owner_insert`, and `trg_profiles_active_character_owner_update` around any `op.batch_alter_table("profiles")` operation in both `upgrade()` and `downgrade()` (matching `012_character_mood_and_emotion.py`).
  - Add the 4 `quiet_hours_*` columns to `profiles` and create `reminders`, `alarms`, `routines`, and `notification_events` with explicit indexes and foreign keys.
  - Implement fail-closed `downgrade()` raising `RuntimeError` if rows exist in `reminders`, `alarms`, `routines`, or `notification_events` or if any `profiles` row has non-default quiet-hours values.
- **Invariants to Preserve:** Zero trigger corruption on `profiles`; zero data loss on existing rows; clean upgrade from revision `004` through `015`.

### [ADD] `backend/app/services/scheduler/service.py` & [MODIFY] `backend/app/services/profile_purge_service.py`, `backend/app/main.py`, `backend/app/core/config.py`, `backend/app/api/v1/endpoints/tasks.py`
- **Primary Responsibility:** Zero-dependency timezone helper, deterministic background scheduling engine, Quiet Hours evaluator, missed-event reconciliation, recurring alarm re-arming, Task reminder bridge & completion sync, expired temporary memory sweep (`DEBT-V1-08`), and Profile purge cascade.
- **Planned Change:**
  - Add `SCHEDULER_ENABLED: bool = True`, `SCHEDULER_POLL_INTERVAL_SECONDS: float = 15.0`, `SCHEDULER_MISSED_GRACE_SECONDS: int = 300`, `MEMORY_EXPIRATION_SWEEP_INTERVAL_SECONDS: int = 300` to `Settings`.
  - Implement `SchedulerService` with deterministic testable methods (`resolve_timezone`, `validate_timezone_name`, `is_within_quiet_hours`, `compute_next_occurrence`, `run_startup_reconciliation`, `run_tick`, `sweep_expired_memories`, `trigger_routine_now`) plus `run_periodic_scheduler(session_factory, interval_seconds)`.
  - Wire startup reconciliation (`run_startup_reconciliation` + initial `sweep_expired_memories`) and periodic task into `backend/app/main.py` `lifespan` (and cancel cleanly before DB disposal).
  - In `tasks.py`, when a `Task` transitions to `completed`/`cancelled` or is soft-deleted, cancel linked active `Reminder` rows and resolve unread `task_reminder` `NotificationEvent` rows.
  - In `ProfilePurgeService.purge_profile()`, delete `NotificationEvent`, `Reminder`, `Alarm`, and `Routine` rows for `profile_id` **before** `delete(Task)`; in `execute_maintenance_purge()`, also hard-delete expired soft-deleted rows across all four scheduling/notification tables past `DATA_RETENTION_DAYS` and invoke expired temporary memory sweep.
- **Invariants to Preserve:** Best-effort wake invariant; zero LLM awaits in scheduler tick; idempotent notification emission per firing instant; `tasks.py` existing HTTP response status/fields unchanged.

### [ADD] `backend/app/schemas/scheduling.py`, `backend/app/api/v1/endpoints/scheduling.py` & [MODIFY] `profiles.py`, `router.py`
- **Primary Responsibility:** Strictly typed Pydantic v2 schemas and Profile-scoped REST endpoints for Reminders, Alarms, Routines, Notification Backlog, and Quiet Hours.
- **Planned Change:**
  - Validate timezones via `validate_timezone_name`, `HH:MM` 24-hour times, weekday recurrence arrays (`0..6` sorted unique), optional UUIDv4 `id` on `ReminderCreate`/`AlarmCreate`, and snooze durations (`1..1440` minutes or explicit future UTC timestamp).
  - Register `scheduling.router` under `protected_router` in `api/v1/router.py` (fail-closed `Depends(get_current_profile_session)`).
  - Register `GET /api/v1/profiles/me/quiet-hours` and `PATCH /api/v1/profiles/me/quiet-hours` in `profiles.py` **above** `@router.patch("/{profile_id}")` / `@router.get("/{profile_id}")` with `Depends(get_current_profile_session)`.
- **Invariants to Preserve:** Cross-profile access returns `404`; `validate_profile_session(db, session)` runs before commit on mutations; clean OpenAPI schemas (`Enum` + `BaseSchema`).

### [MODIFY] `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py` & `frontend/flutter/packages/companion_api/**`
- **Primary Responsibility:** Authoritative API contract export and full `companion_api` Dart SDK coverage for Tasks & Scheduling.
- **Planned Change:**
  - Regenerate `contracts/openapi/openapi.json`.
  - Add `task_dto.dart` and `scheduling_dto.dart` with every schema class declaring all fields directly in its own class body (including all 15 `final` fields in `TrashTaskResponse` and zero extra `final` fields outside OpenAPI). In `TaskUpdate.toJson()`, omit non-nullable fields (`title`, `category`, `status`, `priority`) when `null` and support optional `toJson({bool clearNotes = false, bool clearDueDate = false, bool clearReminderMinutesBefore = false, bool clearReminderAt = false})` method parameters.
  - Export DTOs in `companion_api.dart`, implement all 38 Task/Scheduling/Notification/Quiet-Hours methods in `CompanionClient`, update `M3_ROUTE_DART_METHODS`, `SCHEMA_TO_DART_CLASS`, `UNMAPPED_FUTURE_ROUTES`, and report denominators (lines 503, 517) in `scripts/check_dart_openapi_parity.py`, and update route counts in `scripts/tests/test_check_dart_openapi_parity.py` + `companion_client_test.dart`.
- **Invariants to Preserve:** Zero schema or route parity drift (`check_openapi_contract.py --check` and `check_dart_openapi_parity.py --check` exit `0`).

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Phase 2 Implementation Steps:**
   - **Step 1 (Schema & Models):** Write failing schema lifecycle/migration & trigger preservation tests for Migration `015` (RED) -> implement ORM models (`Reminder`, `Alarm`, `Routine`, `NotificationEvent`, `Profile` quiet hours + `__init__`), Migration `015` (with trigger cycling and fail-closed `downgrade()`), and `ProfilePurgeService` cascade/retention (GREEN).
   - **Step 2 (`SchedulerService` & `DEBT-V1-08`):** Write failing unit tests covering `resolve_timezone` on Windows without `tzdata`, Quiet Hours (`[start, end)` half-open & overnight wrap, alarm bypass, reminder/routine suppression), missed-event catch-up vs live triggers, recurring alarm auto-arm/re-arm, snooze re-triggering, deterministic routine `fallback_message` emission, task reminder bridging + deduplication, and `DEBT-V1-08` expired temporary memory sweep (RED) -> implement `SchedulerService` and `main.py` lifespan integration (GREEN).
   - **Step 3 (REST APIs & Sync):** Write failing API tests covering Profile isolation (`404`), client UUIDv4 conflict (`409`), Reminders CRUD + snooze/acknowledge/dismiss, Alarms CRUD + recurring re-arm, Routines CRUD + manual `run`, Notification Backlog filters/counts/action propagation/`clear-all`, Task completion/deletion cancelling linked reminders, and `/profiles/me/quiet-hours` (RED) -> implement `schemas/scheduling.py`, `endpoints/scheduling.py`, `endpoints/profiles.py`, `endpoints/tasks.py` sync, and `router.py` wiring (GREEN).
   - **Step 4 (OpenAPI & `companion_api` Dart SDK):** Regenerate `contracts/openapi/openapi.json`, author flat `task_dto.dart` (verifying `TaskUpdate` non-nullable omissions & `TrashTaskResponse` 15 fields) + `scheduling_dto.dart`, extend `CompanionClient` with all 38 methods, update `check_dart_openapi_parity.py`, and expand `companion_client_test.dart` + `test_check_dart_openapi_parity.py` (RED -> GREEN).
   - **Step 5 (Refactor & Full Regression Gate):** Refactor shared helper logic cleanly and run the entire repository verification suite.

2. **Phase 3 Documentation & Packaging (After All Phase 2 Checks Pass):**
   - Sync canonical specs (`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`, `windows-host-and-notifications.md`), master planning (`WBS.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md`, `DELIVERY_INDEX.md`), shared tracking (`docs/01_Tracking/task.md`), `CHANGELOG.md`, and walkthrough (`docs/03_Walkthroughs/walkthrough-m3-batch-g1-scheduler-notifications.md`).
   - Archive branch tracker to `docs/01_Tracking/archive/` and open one **Draft PR** against `develop`.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- Backend full pytest suite: `backend\.venv\Scripts\python.exe -m pytest backend/tests -q`
- OpenAPI contract drift check: `backend\.venv\Scripts\python.exe scripts/check_openapi_contract.py --check`
- OpenAPI-to-Dart parity check: `backend\.venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check`
- Parity checker unit tests: `backend\.venv\Scripts\python.exe -B -m unittest scripts/tests/test_check_dart_openapi_parity.py`
- Dart SDK tests: `dart test` (in `frontend/flutter/packages/companion_api`)
- Flutter static analysis: `flutter analyze` (in `frontend/flutter`)
- Flutter Desktop regression tests: `flutter test` (in `frontend/flutter/apps/desktop`)
- Web harness regression checks: `npm --prefix frontend/web run lint`, `npm --prefix frontend/web test -- --run`, `npm --prefix frontend/web run build`

### Manual & Host-Level Checks (Deferred to Batch G2 UI Delivery)
- Native Windows Toast interactive actions & Schedule & Tasks desktop screen verification will follow in **Batch G2** once UI & toast adapter are built on top of G1.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *Windows Python lacking `tzdata` for `zoneinfo.ZoneInfo`:* Mitigated completely via zero-dependency `resolve_timezone()` fallback table; `backend/requirements.txt` and `backend/requirements.lock` remain untouched.
  - *SQLite trigger breakage during `profiles` alteration in Migration `015`:* Mitigated by explicitly dropping and recreating all three `profiles`/`character_instances` triggers around `batch_alter_table("profiles")`.
  - *SQLite datetime timezone stripping:* Normalize every loaded datetime via `_as_utc()` consistently across `SchedulerService` and API endpoints.
  - *Duplicate triggers across restarts or overlapping ticks:* Deduplicate `task_reminder` notifications on `(profile_id, source_type, source_id, triggered_at)` and enforce single-transition state guards for Reminders/Alarms/Routines.
  - *Offline test flakiness:* `SchedulerService` methods accept explicit `now: Optional[datetime]` injection so tests run deterministically without `sleep()`.
- **Dependencies & Assumptions:** Uses Python 3.11+ stdlib (`datetime`, `zoneinfo`, `asyncio`, `uuid`); zero third-party dependency additions required.
- **Required Permissions:** Task-bounded feature branch (`feature/m3-scheduler-notifications-g1`), authorized commits, pushes, and Phase 3 Draft PR against `develop`.
- **Genuine Stop Conditions:** Halt and escalate if schema migration reveals unexpected unresolvable constraint corruption, if a new third-party package dependency becomes unavoidable, or if automated checks fail after two resolution attempts.
