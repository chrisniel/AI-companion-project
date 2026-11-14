# Implementation Plan: Milestone M3 Batch G1 — Backend SchedulerService, Reminders/Alarms/Routines, Quiet Hours, Notification Backlog & OpenAPI/Dart SDK Parity

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Plan ID:** `PLAN-M3-SCHEDULER-NOTIFICATIONS-G1`
- **Status:** Phase 1 Plan Published — Awaiting Human Owner Approval
- **Delivery Level:** Level B — Planned Autonomous (with Level C database schema migration `015_scheduler_notifications_and_routines`)
- **Target Milestone:** M3 — Intelligence & Productivity & M2 — Native Host & Multi-Profile (`PC-SCHED-001`..`005`, `PC-HOST-003`, `PC-API-001`, `DEBT-V1-08`)
- **Work Breakdown Structure IDs:** `PC-SCHED-001` (`SchedulerService` in-process asyncio tick & lifecycle), `PC-SCHED-002` (Reminders & Alarms distinct entities & CRUD), `PC-SCHED-003` (Quiet Hours Policy Engine), `PC-SCHED-004` (Missed-Event Reconciliation & Snooze/Acknowledge/Dismiss Semantics), `PC-SCHED-005` (Routines & Check-Ins with deterministic fallback & zero trigger delay), `PC-HOST-003` (Runtime-owned durable Notification Backlog & lifecycle APIs), `PC-API-001` (OpenAPI 3.1 + `companion_api` Dart SDK parity for Tasks, Reminders, Alarms, Routines, Notifications & Quiet Hours), `DEBT-V1-08` (Periodic sweep of expired short-term memories in `SchedulerService` / maintenance worker)
- **Scope Mode:** New Feature & Schema Extension — Adds Migration `015_scheduler_notifications_and_routines` (`reminders`, `alarms`, `routines`, `notification_events`, and per-Profile Quiet Hours columns on `profiles`), `SchedulerService` asyncio runtime worker, Quiet Hours policy engine, missed-event catch-up reconciliation, expired short-term memory sweep (`DEBT-V1-08`), REST APIs, `ProfilePurgeService` cascade, and OpenAPI 3.1 + `companion_api` Dart SDK parity (promoting `/api/v1/tasks` from `UNMAPPED_FUTURE_ROUTES` alongside new scheduling routes).
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
  - `backend/tests/test_profile_purge_service.py`
  - `frontend/flutter/packages/companion_api/test/companion_client_test.dart`
  - Canonical docs & tracking synced in Phase 3 (`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`, `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`, `docs/02_Planning/00_Master/`, `docs/01_Tracking/`, `CHANGELOG.md`, `docs/03_Walkthroughs/`)
- **Branch:** `feature/m3-scheduler-notifications-g1`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m3-scheduler-notifications-g1.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m3-scheduler-notifications-g1.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:**
  Deliver **Batch G1** of the Human-approved two-batch split (Approach B) for Milestone M3 Scheduling and M2 Native Host Notification Backlog: establish the backend `SchedulerService`, persistent SQLite/SQLAlchemy models and REST APIs for distinct **Reminders**, **Alarms**, and **Routines**, **per-Profile Quiet Hours** enforcement, **missed-event catch-up reconciliation**, a runtime-owned **durable Notification Backlog** (`PC-HOST-003`), periodic expiration sweep of short-term memories (`DEBT-V1-08`), and 100% **OpenAPI 3.1 + `companion_api` Dart SDK parity** so **Batch G2** can build the Desktop Schedule & Tasks UI and Native Windows Toast adapter immediately on top of verified contracts.

- **Two-Batch Split Context (Approach B):**
  - **Batch G1 (`feature/m3-scheduler-notifications-g1`, This Delivery):** Backend runtime scheduler, schema Migration `015`, REST APIs, Quiet Hours, missed-event catch-up, notification backlog, `DEBT-V1-08` expired memory sweep, OpenAPI contract, and `companion_api` Dart SDK (including promoting existing `/api/v1/tasks` routes out of `UNMAPPED_FUTURE_ROUTES` into `CompanionClient`).
  - **Batch G2 (Next Delivery After G1 Merge):** Flutter Desktop **Schedule & Tasks** workspace screen (`PC-CLIENT-008`), Native Windows Toast Notification adapter (`PC-CLIENT-012`, `DEBT-V1-02`), and Desktop Backlog Activity / Notification Center UI (`docs/05_Design/06_Notifications_and_Backlog_Activity.md`).

- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md) — Normative D10 domain specification (`D-SHARED-SCHED-01`, `D-SHARED-SCHED-02`, `D-SHARED-SCHED-03`), entity separation (Tasks, Reminders, Alarms, Routines), Quiet Hours policy, Missed-Event catch-up, Snooze/Acknowledge/Dismiss semantics, and Profile isolation.
  - [`docs/04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md`](../../04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md) — D10 ADR establishing best-effort wake guarantees and domain invariants.
  - [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md) — `PC-HOST-003` runtime-owned durable notification backlog vs Flutter-owned presentation boundary.
  - [`docs/05_Design/06_Notifications_and_Backlog_Activity.md`](../../05_Design/06_Notifications_and_Backlog_Activity.md) — Urgency hierarchy (Alarms bypass quiet hours, Reminders respect quiet hours unless overridden, Routines suppressed in quiet hours), default Quiet Hours range (`22:00` to `07:00`), Backlog Activity semantics (`unread`, `missed`, `suppressed`, `Clear All`).
  - [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md) — `DEBT-V1-08` periodic sweep of expired temporary/short-term memories.

- **Concrete Deliverables:**
  1. Alembic Migration `015_scheduler_notifications_and_routines` creating `reminders`, `alarms`, `routines`, and `notification_events` tables plus Quiet Hours columns on `profiles`, with `PRAGMA foreign_key_check` guards and clean `downgrade()`.
  2. SQLAlchemy ORM models (`Reminder`, `Alarm`, `Routine`, `NotificationEvent`, and `Profile` quiet-hours fields) wired into `app/models/__init__.py`, `app/db/base.py`, and `ProfilePurgeService`.
  3. `SchedulerService` (`backend/app/services/scheduler/service.py`) integrated into FastAPI `lifespan` (`backend/app/main.py`) with startup missed-event reconciliation, periodic due evaluation, Quiet Hours evaluation (`zoneinfo.ZoneInfo`), deterministic Routine emission using `fallback_message` (zero LLM trigger wait), Task due-reminder bridging into `notification_events`, and `DEBT-V1-08` expired short-term memory sweep.
  4. Fail-closed Profile-scoped REST endpoints for Reminders, Alarms, Routines, Notification Backlog, and `/api/v1/profiles/me/quiet-hours`.
  5. Updated `contracts/openapi/openapi.json`, `Task` + `Scheduling` DTOs and methods in `companion_api`, updated `scripts/check_dart_openapi_parity.py`, and comprehensive backend + Dart unit/integration test suites.

- **Explicit Out-of-Scope:**
  - Flutter Desktop UI screens/widgets, Backlog Activity drawer UI, and Native Windows Toast Notification OS integration (`PC-CLIENT-008`, `PC-CLIENT-012`, `DEBT-V1-02` — deferred to Batch G2).
  - LLM autonomous tool-calling / D9 5-stage deterministic policy pipeline (`PC-POLICY-001`..`005` — deferred to dedicated M3 Policy & Tooling batch).
  - Mobile Android (`android/`) WorkManager / AlarmManager client work (follow-on).

---

## 2. Architecture & Technical Approach

### Current Findings & Technical Baseline

| Observation / Evidence | Verified Interpretation |
| --- | --- |
| `backend/app/models/task.py` & `backend/app/api/v1/endpoints/tasks.py` already implement soft-deletable profile-scoped `Task` CRUD with `due_date`, `reminder_minutes_before`, and `reminder_at`. | `Task` exists cleanly, but there is no background worker firing `reminder_at`, no separate `Reminder`, `Alarm`, `Routine`, or `NotificationEvent` tables, and `/api/v1/tasks` is currently in `UNMAPPED_FUTURE_ROUTES` in `scripts/check_dart_openapi_parity.py`. |
| `backend/app/main.py` lines 255–279 already spawn a cancellable `asyncio.create_task` maintenance loop in `lifespan` after `prepare_database_schema` and `initialize_database_runtime`. | `SchedulerService` can follow the exact same safe `lifespan` background-task lifecycle pattern (startup catch-up sweep + periodic asyncio tick + clean cancellation before DB disposal). |
| `backend/app/api/v1/endpoints/profiles.py` registers `@router.get("/deleted")` *before* dynamic `@router.get("/{profile_id}")`, and `PATCH /profiles/{profile_id}` requires `require_host_admin`. | Session-scoped Profile Quiet Hours routes (`GET /api/v1/profiles/me/quiet-hours`, `PATCH /api/v1/profiles/me/quiet-hours`) MUST be registered before `{profile_id}` in `profiles.py` and use `Depends(get_current_profile_session)` so active desktop/mobile sessions can manage their own Quiet Hours without host-admin secret. |
| `backend/migrations/versions/014_conversation_summaries_and_compaction.py` is the current Alembic head (`014_conversation_summaries_and_compaction`). | Migration `015_scheduler_notifications_and_routines` sets `down_revision = "014_conversation_summaries_and_compaction"` and follows the `PRAGMA foreign_key_check` safety guard convention. |
| `backend/app/services/profile_purge_service.py` explicitly deletes profile-owned rows in `purge_profile()` and runs `execute_maintenance_purge()`. | `purge_profile()` must also delete `NotificationEvent`, `Reminder`, `Alarm`, and `Routine` rows for the purged `profile_id`, and `execute_maintenance_purge()` can share expired temporary memory sweep helpers (`DEBT-V1-08`). |

### Architectural Approach

1. **Four Distinct Entities + Unified Durable Notification Backlog (`D10`, `PC-HOST-003`):**
   - `Task` remains an action item (`pending`, `in_progress`, `completed`, `cancelled`), optionally carrying `reminder_at`. When `Task.reminder_at <= now`, `SchedulerService` bridges it into `notification_events` with `source_type="task_reminder"`.
   - `Reminder` is a first-class scheduled prompt/notification (`scheduled`, `fired`, `snoozed`, `acknowledged`, `dismissed`, `missed`, `cancelled`), standalone or optionally linked via nullable `task_id` FK (`ON DELETE SET NULL`), with default `bypass_quiet_hours=False` (`urgency="standard"`).
   - `Alarm` is a high-urgency interrupt (`armed`, `ringing`, `snoozed`, `acknowledged`, `dismissed`, `missed`) supporting one-shot `scheduled_at` or recurring `time_of_day` + `recurrence_days` (`0..6` ISO weekday ints), with default `bypass_quiet_hours=True` (`urgency="high"` per D10 §2.3 & `06_Notifications_and_Backlog_Activity.md`).
   - `Routine` is a bounded recurring check-in (`time_of_day`, `recurrence_days`, `timezone`, required `fallback_message`, optional `prompt_template`), `enabled` flag, default `bypass_quiet_hours=False` (`urgency="informational"`), and deterministic `next_run_at`.
   - `NotificationEvent` (`notification_events`) is the **runtime-owned durable Notification Backlog** (`PC-HOST-003`), recording every fired, quiet-hours-suppressed, and missed-catchup event so Desktop/Mobile clients poll and synchronize state reliably even if the client UI was closed or offline.

2. **Quiet Hours Policy Engine (`PC-SCHED-003`):**
   - Stored per `Profile` (`quiet_hours_enabled: bool = False`, `quiet_hours_start: str = "22:00"`, `quiet_hours_end: str = "07:00"`, `quiet_hours_timezone: str = "UTC"`).
   - Evaluated via `zoneinfo.ZoneInfo(profile.quiet_hours_timezone)` (validated IANA timezone name on update; safe `UTC` fallback if corrupted). Handles both same-day windows (e.g., `13:00`–`15:00`) and overnight wrap windows (e.g., `22:00`–`07:00`). Equal start & end (`22:00` == `22:00`) treats quiet window as inactive/zero-width when validated or rejects identical bounds if misconfigured.
   - Policy outcomes when `is_within_quiet_hours(profile, now)` is `True`:
     - **Alarms** (or any Reminder/Routine with explicit `bypass_quiet_hours=True`): emit immediately (`status="unread"`, `delivery_policy="immediate"`).
     - **Reminders** (`bypass_quiet_hours=False`): create `NotificationEvent(status="suppressed_quiet_hours", delivery_policy="quiet_hours_suppressed")`, mark Reminder `status="fired"` with `fired_at=now` so it does not re-fire repeatedly, and surface quietly in the Backlog Activity Drawer without intrusive toast interruption.
     - **Routines** (`bypass_quiet_hours=False`): suppress execution during quiet hours, advance `next_run_at` to the next scheduled occurrence, set `last_status="suppressed_quiet_hours"`, and record a quiet backlog entry `NotificationEvent(status="suppressed_quiet_hours", delivery_policy="quiet_hours_suppressed")` so the user can inspect skipped check-ins without waking an asleep device or user.

3. **Missed-Event Catch-Up Reconciliation & Grace Window (`PC-SCHED-004`):**
   - Configurable `SCHEDULER_MISSED_GRACE_SECONDS` (default `300` seconds / 5 minutes) and `SCHEDULER_POLL_INTERVAL_SECONDS` (default `15.0` seconds).
   - **Startup Sweep & Periodic Tick Distinction:**
     - During startup reconciliation (when host/runtime was offline past due timestamps beyond `now - grace_window`):
       - Overdue `scheduled` or `snoozed` Reminders with target time `< now - grace_window` transition to `status="missed"` and emit a single `NotificationEvent(status="missed_catchup", delivery_policy="missed_catchup", is_missed_catchup=True)` rather than blasting stale alarms.
       - Overdue `armed` or `snoozed` Alarms past `now - grace_window` transition to `status="missed"` (for one-shot) or advance to next future `scheduled_at` while emitting `NotificationEvent(status="missed_catchup", delivery_policy="missed_catchup", is_missed_catchup=True)`.
       - Overdue enabled Routines past `now - grace_window` record `last_status="missed_catchup"`, emit a catch-up notification event (`is_missed_catchup=True`), and advance `next_run_at` strictly into the future (> `now`) so no infinite catch-up storm occurs.
     - During live operation (`now - grace_window <= target <= now`), due events trigger immediately according to Quiet Hours rules.

4. **Snooze / Acknowledge / Dismiss Lifecycle Consistency (`PC-SCHED-004`):**
   - `POST /api/v1/reminders/{id}/snooze` (`minutes` / `until`): validates bounds (`1..1440` minutes or future UTC timestamp), updates Reminder `status="snoozed"`, sets `snoozed_until`, and resolves active `NotificationEvent` items for that reminder as `status="snoozed"`. When `snoozed_until <= now`, `SchedulerService` re-evaluates and fires once.
   - `POST /api/v1/alarms/{id}/snooze`: same snooze lifecycle for Alarms (`status="snoozed"`, `snoozed_until`, re-triggers as `ringing` at `snoozed_until`).
   - `acknowledge` & `dismiss` endpoints exist symmetrically on **Reminders**, **Alarms**, and **NotificationEvents**: acting on a `NotificationEvent` (`acknowledge`, `dismiss`, `snooze`) idempotently synchronizes the underlying `Reminder`/`Alarm` state when still in an active/ringing/fired/snoozed state, preventing client split-brain between the Toast / Backlog Drawer and Schedule list.
   - **Zero Trigger Delay (`D-SHARED-SCHED-03`):** `SchedulerService` NEVER awaits LLM inference inside its scheduling tick. Routine notifications emit deterministically using `routine.fallback_message` immediately.
   - **Temporary Memory Expiration Sweep (`DEBT-V1-08`):** `SchedulerService` executes an expired temporary-memory cleanup pass (`Memory.deleted_at.is_(None)` and `Memory.expires_at.is_not(None)` and `Memory.expires_at <= now`) on startup and periodic cadence, soft-deleting expired temporary memories (`is_deleted=True`, `deleted_at=now`) so `ProfilePurgeService` hard-purges them after retention without blocking retrieval queries.

### Contract & Schema Impact

- **Database Schema (Migration `015_scheduler_notifications_and_routines`):**
  - Altered table: `profiles` (+4 columns: `quiet_hours_enabled`, `quiet_hours_start`, `quiet_hours_end`, `quiet_hours_timezone`).
  - New tables: `reminders`, `alarms`, `routines`, `notification_events` (all profile-scoped with `profile_id` FK -> `profiles.id` ON DELETE CASCADE + indexes matching `Task` and `Memory` conventions).
- **OpenAPI 3.1 Contract (`contracts/openapi/openapi.json`):**
  - Adds ~26 new routes across Reminders, Alarms, Routines, Notification Backlog, and Profile Quiet Hours, and updates `ProfileMetadata` (or keeps `ProfileMetadata` unchanged with dedicated `QuietHoursConfig` / `QuietHoursUpdate` schema to preserve existing M2 tests). Keeping Quiet Hours in dedicated `QuietHoursOut` / `QuietHoursUpdate` endpoints (`/api/v1/profiles/me/quiet-hours`) avoids unexpected breaking field additions to `ProfileMetadata` while remaining 100% clean in `companion_api`.
  - Promotes the 8 `/api/v1/tasks*` routes out of `UNMAPPED_FUTURE_ROUTES` into `CompanionClient` in `check_dart_openapi_parity.py`.

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/app/models/reminder.py`, `alarm.py`, `routine.py`, `notification_event.py` & [MODIFY] `profile.py`, `models/__init__.py`, `db/base.py`
- **Primary Responsibility:** Define SQLAlchemy 2 ORM models for `Reminder`, `Alarm`, `Routine`, `NotificationEvent`, and per-Profile Quiet Hours fields.
- **Planned Change:**
  - `Profile`: add `quiet_hours_enabled`, `quiet_hours_start` (`"22:00"`), `quiet_hours_end` (`"07:00"`), `quiet_hours_timezone` (`"UTC"`).
  - `Reminder`: `UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin` + `task_id` nullable FK (`tasks.id`, `ondelete="SET NULL"`), `title`, `notes`, `scheduled_at`, `timezone`, `status`, `snoozed_until`, `bypass_quiet_hours`, `origin`, `fired_at`, `acknowledged_at`.
  - `Alarm`: `UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin` + `label`, `scheduled_at`, `time_of_day`, `recurrence_days`, `timezone`, `enabled`, `status`, `snoozed_until`, `bypass_quiet_hours` (default `True`), `origin`, `last_fired_at`, `acknowledged_at`.
  - `Routine`: `UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin` + `title`, `prompt_template`, `fallback_message`, `time_of_day`, `recurrence_days`, `timezone`, `enabled`, `bypass_quiet_hours` (default `False`), `next_run_at`, `last_run_at`, `last_status`.
  - `NotificationEvent`: `UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin` + `source_type`, `source_id`, `urgency`, `title`, `body`, `status`, `delivery_policy`, `is_missed_catchup`, `triggered_at`, `read_at`, `resolved_at`, plus deduplication helper index `(profile_id, source_type, source_id, triggered_at)`.
- **Invariants to Preserve:** Strict `profile_id` isolation on every query; soft-delete consistency; UTC timezone-aware timestamps normalized across SQLite naive/aware round-trips.

### [ADD] `backend/migrations/versions/015_scheduler_notifications_and_routines.py`
- **Primary Responsibility:** Forward and backward SQLite schema migration from `014_conversation_summaries_and_compaction`.
- **Planned Change:** `PRAGMA foreign_key_check` preflight, add columns to `profiles`, create `reminders`, `alarms`, `routines`, `notification_events` with explicit indexes & foreign keys, verify `PRAGMA foreign_key_check`, and implement complete `downgrade()`.
- **Invariants to Preserve:** Zero data loss on existing `profiles` and `tasks`; safe offline SQLite migration when `prepare_database_schema()` upgrades older canonical DBs.

### [ADD] `backend/app/services/scheduler/service.py` & [MODIFY] `backend/app/services/profile_purge_service.py`, `backend/app/main.py`, `backend/app/core/config.py`
- **Primary Responsibility:** Deterministic background scheduling engine, Quiet Hours evaluator, missed-event reconciliation, Task reminder bridge, expired temporary memory sweep (`DEBT-V1-08`), and Profile purge cascade.
- **Planned Change:**
  - Add `SCHEDULER_ENABLED: bool = True`, `SCHEDULER_POLL_INTERVAL_SECONDS: float = 15.0`, `SCHEDULER_MISSED_GRACE_SECONDS: int = 300`, `MEMORY_EXPIRATION_SWEEP_INTERVAL_SECONDS: int = 300` to `Settings`.
  - Implement `SchedulerService` with deterministic testable methods (`run_startup_reconciliation(db, now)`, `run_tick(db, now)`, `sweep_expired_memories(db, now)`, `is_within_quiet_hours(profile, now)`, `compute_next_occurrence(...)`, `trigger_routine_now(db, profile, routine, now)`), plus `run_periodic_scheduler(session_factory, interval_seconds)`.
  - Wire startup reconciliation + periodic task into `backend/app/main.py` `lifespan` (and cancel cleanly before DB disposal).
  - Add `delete(NotificationEvent)`, `delete(Reminder)`, `delete(Alarm)`, `delete(Routine)` scoped by `profile_id` into `ProfilePurgeService.purge_profile()`.
- **Invariants to Preserve:** Best-effort wake invariant (never crash lifespan if scheduler tick hits transient error); zero LLM calls/awaits in scheduler tick; idempotent notification creation so duplicate ticks never spawn duplicate notifications for the same firing instant.

### [ADD] `backend/app/schemas/scheduling.py`, `backend/app/api/v1/endpoints/scheduling.py` & [MODIFY] `profiles.py`, `router.py`
- **Primary Responsibility:** Strictly typed Pydantic v2 schemas and Profile-scoped REST endpoints for Reminders, Alarms, Routines, Notification Backlog, and Quiet Hours.
- **Planned Change:**
  - Validate IANA timezones (`ZoneInfo`), `HH:MM` 24-hour times, weekday recurrence arrays (`0..6`), and snooze durations (`1..1440` minutes or explicit future UTC timestamp).
  - Register `scheduling.router` under `protected_router` in `api/v1/router.py` (inheriting `Depends(get_current_profile_session)` fail-closed auth).
  - Register `GET /api/v1/profiles/me/quiet-hours` and `PATCH /api/v1/profiles/me/quiet-hours` in `profiles.py` *above* `@router.get("/{profile_id}")` with `Depends(get_current_profile_session)`.
- **Invariants to Preserve:** Profile ownership checks on every single resource lookup (returning `404` on cross-profile access); `validate_profile_session(db, session)` before commit on mutations; explicit Pydantic `extra="forbid"` where appropriate and OpenAPI clean types (`Enum` + `BaseSchema`).

### [MODIFY] `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py` & `frontend/flutter/packages/companion_api/**`
- **Primary Responsibility:** Authoritative API contract export and full `companion_api` Dart SDK coverage for Tasks & Scheduling.
- **Planned Change:**
  - Regenerate `contracts/openapi/openapi.json`.
  - Add `task_dto.dart` and `scheduling_dto.dart`, export in `companion_api.dart`, implement all Task, Reminder, Alarm, Routine, Notification, and Quiet Hours methods in `CompanionClient`, update `M3_ROUTE_DART_METHODS` + `SCHEMA_TO_DART_CLASS` in `check_dart_openapi_parity.py` (removing `/api/v1/tasks*` from `UNMAPPED_FUTURE_ROUTES`), and expand `companion_client_test.dart` + `test_check_dart_openapi_parity.py`.
- **Invariants to Preserve:** Zero schema or route parity drift (`check_openapi_contract.py --check` and `check_dart_openapi_parity.py --check` exit `0`).

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Phase 2 Implementation Steps:**
   - **Step 1 (Schema & Models):** Write failing schema lifecycle/migration tests for Migration `015` (RED) -> implement ORM models (`Reminder`, `Alarm`, `Routine`, `NotificationEvent`, `Profile` quiet hours), Migration `015`, and `ProfilePurgeService` cascade (GREEN).
   - **Step 2 (`SchedulerService` & `DEBT-V1-08`):** Write failing unit tests covering Quiet Hours (overnight wrap, alarm bypass, reminder suppression, routine suppression), missed-event catch-up vs live due triggers, snooze re-triggering, recurrence advancement, deterministic routine `fallback_message` emission, task reminder bridging, and expired temporary memory sweep (RED) -> implement `SchedulerService` and `main.py` lifespan integration (GREEN).
   - **Step 3 (REST APIs):** Write failing API tests covering Profile isolation (cross-profile `404`), Reminders CRUD + snooze/acknowledge/dismiss, Alarms CRUD + snooze/acknowledge/dismiss, Routines CRUD + manual `run`, Notification Backlog filters/counts/actions/`clear-all`, and `profiles/me/quiet-hours` (RED) -> implement `schemas/scheduling.py`, `endpoints/scheduling.py`, `endpoints/profiles.py`, and `router.py` wiring (GREEN).
   - **Step 4 (OpenAPI & `companion_api` Dart SDK):** Regenerate `contracts/openapi/openapi.json`, author `task_dto.dart` & `scheduling_dto.dart`, extend `CompanionClient`, update `check_dart_openapi_parity.py`, and write comprehensive `companion_client_test.dart` tests (RED -> GREEN).
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
  - *SQLite datetime timezone mismatch:* SQLite often strips `tzinfo` on read; normalize timestamps with an `_as_utc()` helper consistently across `SchedulerService` and endpoints.
  - *Duplicate triggers across restarts or overlapping ticks:* Guard notification emission with deterministic idempotency checks (existing unresolved or matching `triggered_at` / `fired_at` timestamps) inside DB transactions.
  - *FastAPI route ordering in `profiles.py`:* Place `/me/quiet-hours` before `/{profile_id}` and cover with HTTP integration tests.
  - *Offline test flakiness from wall-clock time:* `SchedulerService` methods accept explicit `now: Optional[datetime]` injection so tests are 100% deterministic without `sleep()`.
- **Dependencies & Assumptions:** Python 3.11+ `zoneinfo` stdlib (already available on Python 3.11; Windows `tzdata` handled with safe `UTC` fallback or `tzdata` check during Phase 2—verify `ZoneInfo("America/New_York")` works in `backend\.venv`!).
- **Required Permissions:** Task-bounded feature branch creation (`feature/m3-scheduler-notifications-g1`), authorized commits, pushes, and Phase 3 Draft PR against `develop`.
- **Genuine Stop Conditions:** Halt and escalate if Windows Python `backend\.venv` lacks `tzdata` requiring a new dependency outside plan (`pyproject.toml`), if schema changes conflict with unapproved protected boundaries, or if automated checks fail after two resolution attempts.
