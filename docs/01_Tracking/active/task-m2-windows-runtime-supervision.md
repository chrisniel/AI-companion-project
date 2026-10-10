# Branch Task: M2 Windows Runtime Launch & Supervision (Batch H1)

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
  1. Reliable single-instance startup with atomic lockfile (`%LOCALAPPDATA%\AI Companion\runtime.lock`).
  2. Authenticated runtime identification (`POST /api/v1/auth/verify` with DPAPI pairing token).
  3. Detached background lifecycle ("Quit UI != Stop Runtime").
  4. Bounded readiness checks (polling `GET /api/v1/health` with backoff up to 30s).
  5. Safe runtime termination ("Stop Runtime" tray & settings action, `POST /api/v1/system/shutdown`, fallback forceful kill).
- **Strictly Out of Scope:**
  - Windows Task Scheduler autostart (`PC-HOST-002`).
  - Native Windows Action Center Toasts (`PC-HOST-003`, `PC-CLIENT-012`).
  - Multi-Profile database schema migration (`PC-IDENTITY-001`).
  - D6 model import service (`PC-MODEL-002`).
  - Model weights or execution pipeline modifications.
  - Unrelated UI redesign or restyling.

---

## Checkpoints & Gates

- [x] Preflight checks verified (clean develop baseline `7c1d1a2`, all 193 workspace tests and 30 backend tests passing).
- [x] Branch initialized: `feature/m2-windows-runtime-supervision` (human-authorized).
- [x] M1 Closure Gate reconciliation completed (M1 active tracker archived with post-merge archival exception note; shared tracking and delivery index updated).
- [x] M2-H1 implementation plan authored under `docs/02_Planning/01_Plans/plan-m2-h1-windows-runtime-supervision.md`.
- [x] M2-H1 active tracker authored under `docs/01_Tracking/active/task-m2-windows-runtime-supervision.md`.
- [ ] **HUMAN PLAN APPROVAL GATE (STOP HERE):** Chris reviews and confirms M2-H1 implementation plan before product code implementation begins.
- [ ] **Task 1:** Backend authenticated shutdown endpoint (`POST /api/v1/system/shutdown`), OpenAPI contract update, and tests.
- [ ] **Task 2:** Runtime process state machine (`RuntimeProcessState`) and lockfile models (`RuntimeLockfileData`) in `companion_core`.
- [ ] **Task 3:** Native Windows runtime process supervisor (`WindowsRuntimeProcessSupervisor`) in `apps/desktop/lib/platform/`.
- [ ] **Task 4:** Desktop runtime coordinator (`DesktopRuntimeCoordinator`) with readiness polling and auth verification in `apps/desktop/lib/coordinator/`.
- [ ] **Task 5:** Lifecycle & UI wiring (System tray "Stop Runtime" action, dynamic status, and Settings supervision controls).
- [ ] **Task 6:** Parity check, static analysis, test matrix verification, and mechanical docs checks.
- [ ] **Implementation Gate:** Independent code & test review.
- [ ] **Documentation Gate:** Canonical architecture spec updates (`windows-host-and-notifications.md`).
- [ ] **Closure Gate:** M2-H1 delivery verification and handoff.
