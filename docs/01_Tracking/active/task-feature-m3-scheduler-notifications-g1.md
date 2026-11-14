# Active Execution Tracker — `feature/m3-scheduler-notifications-g1`

> **Delivery Branch:** `feature/m3-scheduler-notifications-g1`
> **Implementation Plan:** [`plan-m3-scheduler-notifications-g1.md`](../../02_Planning/01_Plans/plan-m3-scheduler-notifications-g1.md)
> **Delivery Level:** Level B — Planned Autonomous (with Level C Schema Migration `015_scheduler_notifications_and_routines`)
> **Status:** Phase 1 Plan Published — Awaiting Human Owner Approval

---

## Phase 1: Plan & Authorization
- [x] Verify clean `develop` baseline (`280922b`) and create dedicated feature branch `feature/m3-scheduler-notifications-g1`.
- [x] Author implementation plan (`plan-m3-scheduler-notifications-g1.md`) for Batch G1 (Migration `015`, `SchedulerService`, Reminders/Alarms/Routines, Quiet Hours, Missed-Event Catch-Up, Durable Notification Backlog, `DEBT-V1-08` expired memory sweep, OpenAPI + `companion_api` Dart SDK parity).
- [x] Publish Phase 1 planning commit to `origin/feature/m3-scheduler-notifications-g1`.
- [ ] **STOP GATE:** Receive Human Owner Plan Approval before touching any production code, migrations, or opening a PR.

## Phase 2: Autonomous Implementation & Verification *(Locked until Human Approval)*
- [ ] Step 1: Add ORM models (`Reminder`, `Alarm`, `Routine`, `NotificationEvent`, `Profile` quiet hours), Alembic Migration `015_scheduler_notifications_and_routines`, and `ProfilePurgeService` cascade.
- [ ] Step 2: Implement `SchedulerService` (Quiet Hours engine, missed-event reconciliation, snooze re-trigger, deterministic Routine emission, Task due-reminder bridge, `DEBT-V1-08` temporary memory sweep) and wire into FastAPI `lifespan`.
- [ ] Step 3: Implement Profile-scoped REST endpoints & schemas (`reminders`, `alarms`, `routines`, `notifications`, `/profiles/me/quiet-hours`) and fail-closed router wiring.
- [ ] Step 4: Regenerate `contracts/openapi/openapi.json`, add `task_dto.dart` + `scheduling_dto.dart` + `CompanionClient` methods, and update `scripts/check_dart_openapi_parity.py` + `companion_client_test.dart`.
- [ ] Step 5: Run full Phase 2 Verification Gate (`pytest backend/tests`, `check_openapi_contract.py --check`, `check_dart_openapi_parity.py --check`, `test_check_dart_openapi_parity.py`, `dart test`, `flutter analyze`, `flutter test`, `frontend/web` checks).

## Phase 3: Documentation, Closure & Draft PR *(Locked until Phase 2 Passes)*
- [ ] Sync canonical docs (`tasks-reminders-alarms-and-routines.md`, `windows-host-and-notifications.md`), master planning (`WBS.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md`, `DELIVERY_INDEX.md`), `docs/01_Tracking/task.md`, and `CHANGELOG.md`.
- [ ] Author walkthrough (`docs/03_Walkthroughs/walkthrough-m3-batch-g1-scheduler-notifications.md`) and archive this tracker.
- [ ] Commit, push, and open Draft PR against `develop`.

## Phase 4: Independent Review & Human Merge *(Locked until Phase 3 Completes)*
- [ ] Run Independent Review (diff, docs, tests, CI), apply any required fixes on `feature/m3-scheduler-notifications-g1`, present plain-text squash commit title & body, and **STOP** for Human Owner merge.
