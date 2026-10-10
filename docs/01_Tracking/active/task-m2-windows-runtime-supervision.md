# Branch Task: M2 Windows Runtime Launch, Attach & Supervision (Batch H1)

- **Branch:** `feature/m2-windows-runtime-supervision` (human-authorized).
- **Starting Baseline:** `7c1d1a2ddb5c57ddaae9bbacbcab2e25f9938fe1` (PR #23 squash merge to develop).
- **Milestone:** M2 — PC Companion Foundation.
- **Active Work Item:** `PC-HOST-001` (Local AI Runtime Process Supervision & Launch Coordinator).
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-h1-windows-runtime-supervision.md`](../../02_Planning/01_Plans/plan-m2-h1-windows-runtime-supervision.md).
- **Current Stage:** Stage 1: PLAN (Awaiting Human Plan Approval Gate; Zero Product Code Written).

---

## Batch H1 Checkpoints & Boundaries

### Scope Boundaries
- **In Scope:**
  1. Reliable single-instance startup with atomic kernel-locked lockfile (`%LOCALAPPDATA%\AI Companion\runtime.lock` via `FileMode.append` and `RandomAccessFile.lock(FileLock.exclusive)`, writing strictly through the locked handle to prevent truncation races).
  2. Double-checked locking under guard: rechecking port responsiveness and process status immediately after acquiring lock to prevent duplicate spawns.
  3. Authenticated runtime identification (`POST /api/v1/auth/verify` with DPAPI pairing token decoupled from `GET /api/v1/health` reachability).
  4. Orthogonal supervision modeling (`SupervisionMode.localLoopback` vs `SupervisionMode.remoteHost` decoupled from `RuntimeStatus`).
  5. Detached background lifecycle ("Quit UI != Stop Runtime" with durable internal rotating file logging via `COMPANION_LOG_FILE`, avoiding shell wrappers or command-line secrets).
  6. Process safety & untrusted PID invariant (never kill unknown or unverified PIDs; safe stale lock recovery; alien port conflict fail-closed; surviving unresponsive process detection).
  7. Informational system tray status and Settings supervision diagnostic card (host termination strictly deferred).
  8. External PowerShell acceptance harness (`scripts/verify_windows_runtime_supervision.ps1`) using disposable test roots, ports, and tokens without touching user data or live port 8000.
- **Strictly Out of Scope:**
  - Host termination / shutdown / restart (`POST /api/v1/system/shutdown` deferred to dedicated local host administration control).
  - Windows Task Scheduler autostart (`PC-HOST-002`).
  - Native Windows Action Center Toasts (`PC-HOST-003`, `PC-CLIENT-012`).
  - Multi-Profile database schema migration (`PC-IDENTITY-001`).
  - D6 model import service (`PC-MODEL-002`).
  - Model weights or execution pipeline modifications.
  - Unrelated UI redesign or restyling.

---

## Checkpoints & Gates

- [x] Preflight checks verified (clean develop baseline `7c1d1a2`, workspace tests passing).
- [x] Branch initialized: `feature/m2-windows-runtime-supervision` (human-authorized).
- [x] M1 Closure Gate reconciliation completed (M1 active tracker archived with post-merge archival exception note; historical PR CI / closure checkboxes marked; shared tracking and delivery index updated).
- [x] M2-H1 implementation plan authored under `docs/02_Planning/01_Plans/plan-m2-h1-windows-runtime-supervision.md` (revised per independent review: right-sized 5-task scope, lock safety, double-checked recheck, detached logging, process provenance, auth separation, cross-process concurrency testing, isolated harness).
- [x] M2-H1 active tracker authored under `docs/01_Tracking/active/task-m2-windows-runtime-supervision.md`.
- [ ] **HUMAN PLAN APPROVAL GATE (STOP HERE):** Chris reviews and confirms M2-H1 implementation plan before product code implementation begins.
- [ ] **Task 1:** Runtime process state model (`RuntimeProcessState`, `SupervisionMode`, `RuntimeStatus`) and lockfile descriptor models (`RuntimeLockfileData`) in `companion_core`.
- [ ] **Task 2:** Native Windows runtime process supervisor (`WindowsRuntimeProcessSupervisor`) with kernel-enforced locking (`FileMode.append`), handle write-through, and detached rotating logging in `apps/desktop/lib/platform/`.
- [ ] **Task 3:** Desktop runtime coordinator (`DesktopRuntimeCoordinator`) with double-checked locking, readiness polling, and auth separation in `apps/desktop/lib/coordinator/`.
- [ ] **Task 4:** UI & lifecycle integration ("Quit UI != Stop Runtime", informational tray status, and Settings supervision diagnostics).
- [ ] **Task 5:** External PowerShell Windows acceptance harness (`scripts/verify_windows_runtime_supervision.ps1`) with disposable test environments and full test matrix verification.
- [ ] **Implementation Gate:** Independent code & test review.
- [ ] **Documentation Gate:** Canonical architecture spec updates (`windows-host-and-notifications.md`).
- [ ] **Closure Gate:** M2-H1 delivery verification and handoff.
