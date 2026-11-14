# Active Execution Tracker — `feature/m3-schedule-ui-windows-toasts-g2`

> **Delivery Branch:** `feature/m3-schedule-ui-windows-toasts-g2`
> **Implementation Plan:** [`plan-m3-schedule-ui-windows-toasts-g2.md`](../../02_Planning/01_Plans/plan-m3-schedule-ui-windows-toasts-g2.md)
> **Delivery Level:** Level B — Planned Autonomous
> **Status:** Phase 1 Plan Revised & Published — Awaiting Human Owner Approval

---

## Phase 1: Plan & Authorization
- [x] Verify clean `develop` baseline (`fe1526e`) and create dedicated feature branch `feature/m3-schedule-ui-windows-toasts-g2`.
- [x] Author initial implementation plan (`plan-m3-schedule-ui-windows-toasts-g2.md`) and active tracker.
- [x] Run Independent Phase 1 Plan Review (`research` subagent `2b52b266-2a04-46aa-b17b-171ddb873097`) and incorporate all 13 findings (`1 CRITICAL`, `4 HIGH`, `3 MEDIUM`, `2 LOW`, `3 NIT`) into the plan.
- [ ] Publish Phase 1 planning commit to `origin/feature/m3-schedule-ui-windows-toasts-g2` and receive Human Owner Plan Approval before touching any production code or opening a PR.
- [ ] **STOP GATE:** Wait for explicit Human Owner Plan Approval (`feature/m3-schedule-ui-windows-toasts-g2`).

## Phase 2: Autonomous Implementation & Verification *(Locked until Human Approval)*
- [ ] Step 1: Fold in Batch G1 review finding `NIT-01` in `backend/app/api/v1/endpoints/scheduling.py` (`update_alarm`) with regression test in `backend/tests/test_scheduling_api.py`.
- [ ] Step 2: Implement dependency-free `DesktopToastAdapter` & `WindowsWinRtToastAdapter` (`windows_toast_adapter.dart`) with unit tests (`windows_toast_adapter_test.dart`).
- [ ] Step 3: Implement profile-scoped `DesktopScheduleController` (`desktop_schedule_controller.dart`) with polling/catch-up/dedup unit tests (`desktop_schedule_controller_test.dart`).
- [ ] Step 4: Implement `ScheduleScreen` Option 2A workspace, `ScheduleSidebar`, `ScheduleEditDialogs`, `NotificationBacklogDrawer`, `DesktopShell` header bell & alert banner, Settings Quiet Hours card, remove `'M3'` planned badge on `schedule`, and add widget/responsive tests.
- [ ] Step 5: Run full Phase 2 Verification Gate (`check_openapi_contract.py --check`, `check_dart_openapi_parity.py --check`, `pytest backend/tests`, `dart test`, `flutter analyze`, `flutter test`, `frontend/web` lint/test/build).

## Phase 3: Documentation, Closure & Draft PR *(Locked until Phase 2 Passes)*
- [ ] Sync canonical docs (`tasks-reminders-alarms-and-routines.md` including `NIT-02`, `windows-host-and-notifications.md`), master planning (`WBS.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md`, `DELIVERY_INDEX.md`), `docs/01_Tracking/task.md`, and `CHANGELOG.md`.
- [ ] Author walkthrough (`docs/03_Walkthroughs/walkthrough-m3-batch-g2-schedule-ui-windows-toasts.md`) and archive this tracker on the same branch.
- [ ] Commit, push, and open Draft PR against `develop` (plus manual UI testing checklist & plain-text squash summary).

## Phase 4: Independent Review & Human Merge *(Locked until Phase 3 Completes)*
- [ ] Run Independent Review (diff, docs, tests, CI), apply any required fixes on `feature/m3-schedule-ui-windows-toasts-g2`, confirm UI manual checklist / plain-text squash commit title & body, and **STOP** for Human Owner merge.
