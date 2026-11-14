# Delivery Walkthrough — M3 Batch G1: Scheduler Runtime, Notifications Backlog & Dart Contract Parity

- **Branch:** `feature/m3-scheduler-notifications-g1` (branched from `develop` at `280922b`)
- **Implementation Plan:** [plan-m3-scheduler-notifications-g1.md](../02_Planning/01_Plans/plan-m3-scheduler-notifications-g1.md)
- **Archived Task Tracker:** [task-feature-m3-scheduler-notifications-g1.md](../01_Tracking/archive/task-feature-m3-scheduler-notifications-g1.md)
- **WBS Scope:** `PC-HOST-003` (backend notification backlog foundation), `PC-SCHED-001`..`005`, `PC-API-001`, `DEBT-V1-08`
- **Status:** Phase 2 Implemented & Verified; Phase 3 Closure Prepared (Ready for Phase 4 Review)

---

## 1. Executive Summary

M3 Batch G1 delivers the local-first scheduling and notification backend runtime together with full OpenAPI and Flutter `companion_api` Dart SDK contract parity:

- Persistent ORM models and SQLite schema via Alembic Migration `015_scheduler_notifications_and_routines` (`reminders`, `alarms`, `routines`, `notification_events`, and `profiles` quiet-hours columns).
- Profile-scoped `SchedulerService` lifecycle integrated into FastAPI application startup/shutdown with zero-dependency timezone resolution (`resolve_timezone()` / `_RuleBasedTzInfo`), half-open `[start, end)` Quiet Hours enforcement, missed-event catch-up reconciliation, recurring alarm re-arming, bounded deterministic `fallback_message` routine execution, Task due-reminder bridging with deduplication, and automatic `DEBT-V1-08` expired temporary memory cleanup.
- Full REST surface under `/api/v1/reminders/*`, `/api/v1/alarms/*`, `/api/v1/routines/*`, `/api/v1/notifications/*`, and `/api/v1/profiles/me/quiet-hours`, alongside Task completion/deletion reminder cancellation hooks and `ProfilePurgeService` cascade cleanup.
- Regenerated `contracts/openapi/openapi.json` (`66` routes) and complete `companion_api` Dart SDK parity (`60/60` DTO schemas, `82/82` covered routes and `CompanionClient` methods).

Native Windows WinRT Action Center toasts (`PC-CLIENT-012` / `DEBT-V1-02`) and Flutter Desktop Schedule UI (`PC-CLIENT-008`) remain explicitly out of scope for follow-on **Batch G2**. `backend/requirements.txt` and `requirements.lock` were left untouched, and D9 LLM tool-calling remains out of scope.

---

## 2. Delivered Architecture & Code Changes

### 2.1 Data Model, Migration 015 & Purge Safety
- `backend/app/models/base.py`: added `parse_recurrence_days_string` helper.
- `backend/app/models/reminder.py`, `alarm.py`, `routine.py`, `notification_event.py`: implemented `Reminder`, `Alarm`, `Routine`, and `NotificationEvent` ORM models, registered in `backend/app/models/__init__.py` and `backend/app/db/base.py`.
- `Profile` model (`profiles`): added quiet-hours columns and `__init__` defaults.
- Alembic Migration `015_scheduler_notifications_and_routines`: creates scheduling and notification tables, extends `profiles`, cycles triggers/indexes cleanly, and implements fail-closed `downgrade()`.
- `ProfilePurgeService`: wired FK cascade/retention cleanup and expired-memory delegation, covered by `test_purge_profile_deletes_scheduling_and_notification_entities` in `backend/tests/test_profile_deletion.py` (`53 passed in 8.94s`), plus schema and backup verification in `test_schema_lifecycle.py` and `test_prepare_database_schema_backup.py`.

### 2.2 `SchedulerService` Runtime Engine
- `backend/app/services/scheduler/__init__.py` and `backend/app/services/scheduler/service.py`:
  - Zero-dependency `resolve_timezone()` and `_RuleBasedTzInfo` for local IANA/offset resolution without new Python dependencies.
  - Half-open `[start, end)` Quiet Hours window checks suppressing non-urgent dispatches while preserving alarm/alert semantics as designed.
  - Missed-event catch-up reconciliation and recurring alarm re-arm logic.
  - Bounded deterministic `fallback_message` routine emission without invoking live LLM inference.
  - Task due-reminder bridging and deduplication.
  - `DEBT-V1-08` periodic expired temporary memory cleanup sweeps.
- `backend/app/core/config.py` and `backend/app/main.py`: scheduler configuration settings and FastAPI lifespan startup/shutdown integration.
- Covered by `backend/tests/test_scheduler_service.py`.

### 2.3 REST Endpoints & Hooks
- `backend/app/schemas/scheduling.py`: Pydantic request/response contracts for reminders, alarms, routines, notifications, and quiet hours.
- `backend/app/api/v1/endpoints/scheduling.py` & `backend/app/api/v1/router.py`: REST endpoints mounted on the protected V1 router under `/api/v1/reminders/*`, `/api/v1/alarms/*`, `/api/v1/routines/*`, and `/api/v1/notifications/*`.
- `backend/app/api/v1/endpoints/profiles.py`: added `/me/quiet-hours` preference endpoints.
- `backend/app/api/v1/endpoints/tasks.py`: hooked task completion and deletion to cancel pending bridged due reminders.
- Covered by `backend/tests/test_scheduling_api.py`.

### 2.4 OpenAPI Contract & `companion_api` Dart SDK Parity
- Regenerated `contracts/openapi/openapi.json` (`66` total OpenAPI routes).
- Created `frontend/flutter/packages/companion_api/lib/dto/task_dto.dart` (`6` DTOs, including flat `TrashTaskResponse` with all `15` `final` fields directly inside the class body, and `TaskUpdate` non-null omission with optional `clear*` named flags on `toJson()`).
- Created `frontend/flutter/packages/companion_api/lib/dto/scheduling_dto.dart` (`19` DTOs).
- Exported both DTO modules in `frontend/flutter/packages/companion_api/lib/companion_api.dart` and added `38` strongly-typed methods to `CompanionClient` in `frontend/flutter/packages/companion_api/lib/client/companion_client.dart`.
- Updated `scripts/check_dart_openapi_parity.py`: merged all `38` Task, Quiet Hours, Reminder, Alarm, Routine, and Notification routes into `M3_ROUTE_DART_METHODS` (`82` total native covered routes), removed the `8` `/api/v1/tasks*` entries from `UNMAPPED_FUTURE_ROUTES`, added `25` DTO classes to `SCHEMA_TO_DART_CLASS` (`60` tracked DTO schemas), and updated `scripts/tests/test_check_dart_openapi_parity.py` (`8` tests).
- Added M3 Batch G1 DTO serialization and `CompanionClient` tests in `frontend/flutter/packages/companion_api/test/companion_client_test.dart`.

---

## 3. Verification Evidence

All verification gates ran locally after all code edits and passed with exit code `0`:

- **OpenAPI Contract Check:** `.\backend\.venv\Scripts\python.exe scripts/check_openapi_contract.py --check` -> `OpenAPI contract is up-to-date (66 routes, all required model routes present).` (exit `0`)
- **Dart–OpenAPI Parity Check:** `.\backend\.venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check` -> `RESULT: ALL CONTRACT PARITY AND ROUTE COVERAGE CHECKS PASSED.` (`60/60` DTO schemas, `82/82` covered routes, `82/82` `CompanionClient` methods) (exit `0`)
- **Parity Checker Unit Tests:** `.\backend\.venv\Scripts\python.exe -B -m unittest scripts/tests/test_check_dart_openapi_parity.py` -> `Ran 8 tests in 0.180s — OK` (exit `0`)
- **Flutter `companion_api` Package Tests:** `dart test` in `frontend/flutter/packages/companion_api` -> `+103: All tests passed!` (exit `0`)
- **Flutter Static Analysis:** `flutter analyze` in `frontend/flutter` -> `No issues found! (ran in 6.6s)` (exit `0`)
- **Flutter Desktop Test Suite:** `flutter test` in `frontend/flutter/apps/desktop` -> `01:42 +356: All tests passed!` (exit `0`)
- **Backend Full Test Suite:** `.\backend\.venv\Scripts\python.exe -m pytest backend/tests -q` -> `812 passed, 80 warnings in 367.85s (0:06:07)` (exit `0`; targeted `backend/tests/test_profile_deletion.py` also passed `53 passed in 8.94s`)
- **Web Frontend Lint, Tests & Build:** `npm --prefix frontend/web run lint` && `npm --prefix frontend/web test -- --run` && `npm --prefix frontend/web run build` -> `tsc --noEmit` 0 errors, `Test Files 16 passed (16), Tests 248 passed (248)`, `vite build` succeeded (`6.63s`, `1737` modules) (exit `0`)

---

## 4. Documentation & Tracking Sync

- Updated canonical domain and infrastructure specs:
  - `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`
  - `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`
- Synchronized master planning and tracking records:
  - `docs/02_Planning/01_Plans/plan-m3-scheduler-notifications-g1.md`
  - `docs/02_Planning/00_Master/WBS.md`
  - `docs/02_Planning/00_Master/MASTER_CHECKLIST.md`
  - `docs/02_Planning/00_Master/DECISION_DEBT.md` (`DEBT-V1-08` resolved)
  - `docs/02_Planning/00_Master/DELIVERY_INDEX.md`
  - `docs/01_Tracking/task.md`
  - `CHANGELOG.md`
- Archived branch execution tracker on the same branch to `docs/01_Tracking/archive/task-feature-m3-scheduler-notifications-g1.md`.
