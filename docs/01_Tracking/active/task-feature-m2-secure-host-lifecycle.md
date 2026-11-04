# Active Branch Task Tracker: M2 Secure Host Lifecycle (`PC-HOST-005`)

- **Branch:** `feature/m2-secure-host-lifecycle`
- **Target Integration Branch:** `develop`
- **Verified Base SHA:** `261d4b43930d3dcdad2dbd913d4dd4d60c8a4887`
- **Milestone / Work Item:** `M2 — PC Companion Foundation` / `PC-HOST-005`
- **Risk Classification:** `Level C — Sensitive Design`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md`](../../02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md)
- **Current Lifecycle Phase:** `PHASE 1 — PLAN AND AUTHORIZATION (AWAITING HUMAN / INDEPENDENT PLAN REVIEW)`

---

## Phase 1: Architecture Investigation, Planning Publication & Governance Clarification
- [x] Verify clean `develop` baseline (`261d4b43930d3dcdad2dbd913d4dd4d60c8a4887`) and create dedicated branch `feature/m2-secure-host-lifecycle`.
- [x] Inspect canonical architecture specs (`SYSTEM_BASELINE.md`, `windows-host-and-notifications.md`, `profiles-and-devices.md`, `authentication-and-secrets.md`, `runtime-and-models.md`, `01_PC_Desktop_Shell_and_Tray.md`, `ADR-0003`) and current backend/Flutter source code.
- [x] Identify existing Host Admin secret mechanisms, runtime supervision flow, and two existing defects (`LlamaCppProvider.shutdown()` leaving `llama-server.exe` alive after router API unload/timeout, and `settings_screen.dart` `Exit Companion` button invoking unconfirmed UI-only exit).
- [x] Apply narrow Phase 1 Planning Git Authorization clarifications to [`AGENTS.md`](../../../AGENTS.md) and [`docs/06_Guides/DELIVERY_WORKFLOW.md`](../../06_Guides/DELIVERY_WORKFLOW.md).
- [x] Author comprehensive Level C implementation plan at [`docs/02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md`](../../02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md) marked `AWAITING HUMAN / INDEPENDENT PLAN REVIEW`.
- [x] Commit and push Phase 1 planning and governance files to `origin/feature/m2-secure-host-lifecycle` and halt for Human Owner and Independent Reviewer approval.

---

## Phase 2: Autonomous Implementation and Verification (Blocked Pending Phase 1 Approval)
- [ ] Fix `LlamaCppProvider.shutdown()` to cancel active generation streams, bound drain wait, and unconditionally terminate Core-managed `llama-server.exe` (`_server_process`).
- [ ] Implement `POST /api/v1/system/shutdown` protected by `require_host_admin`, shutdown admission control, and isolated secret-file path override support for hermetic tests.
- [ ] Regenerate `contracts/openapi/openapi.json` and add `CompanionClient.shutdownSystem()` in `companion_api`.
- [ ] Implement 4-factor provenance-verified `terminateVerifiedRuntimeProcess()` in `WindowsRuntimeProcessSupervisor` and `shutdownLocalRuntime()` in `DesktopRuntimeCoordinator`.
- [ ] Enable System Tray `Exit Companion`, fix Settings `Exit Companion` button, and add mandatory confirmation, progress, and failure recovery dialogs.
- [ ] Run backend `pytest`, Flutter unit/widget/acceptance tests, `dart analyze`, and `scripts/check_openapi_contract.py --check`.

---

## Phase 3: Documentation, Closure, and Draft PR (Blocked Pending Phase 2 Completion)
- [ ] Reconcile canonical documentation (`windows-host-and-notifications.md`, `authentication-and-secrets.md`, `SYSTEM_BASELINE.md`, `DELIVERY_INDEX.md`, `WBS.md`, `CHANGELOG.md`).
- [ ] Author technical walkthrough (`docs/03_Walkthroughs/walkthrough-m2-secure-host-lifecycle.md`).
- [ ] Archive this branch tracker to `docs/01_Tracking/archive/task-feature-m2-secure-host-lifecycle.md`, push verified commits, and open draft PR against `develop`.

---

## Phase 4: Combined Independent Review and Human Merge (Blocked Pending Phase 3)
- [ ] Independent review evaluation and any bounded same-branch corrections.
- [ ] Human Owner squash merge into `develop` and read-only post-merge verification.
