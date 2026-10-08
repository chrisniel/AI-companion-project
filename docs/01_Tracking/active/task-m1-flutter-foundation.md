# Branch Task: M1 Flutter Desktop Client Foundation

- **Branch:** `feature/m1-flutter-foundation` (human-prepared).
- **Starting Baseline:** `55c6f621a4a931dbac32ecc7f919f608ad2bb669`.
- **Milestone:** M1 — Flutter Desktop Client Foundation.
- **Active Work Item:** `PC-CLIENT-001` (Flutter Windows Desktop Project Scaffolding).
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m1-flutter-desktop-client-foundation.md`](../../02_Planning/01_Plans/plan-m1-flutter-desktop-client-foundation.md).
- **Current Stage:** Batch 1 Implementation & Verification.

---

## Batch Execution State

| Batch | Work Item | Status | Verification & Deliverables |
| :--- | :--- | :--- | :--- |
| **B1** | `PC-CLIENT-001` | **VERIFIED / AWAITING REVIEW** | Pub Workspace (`frontend/flutter/`), `companion_core`, `companion_api`, `companion_design`, `apps/desktop` Windows runner, CI policy and workflow integration. |
| **B2** | `PC-CLIENT-002` | `PLANNED` | Window framing (1280×800 / 1024×640), close-to-tray lifecycle, native tray menu, clean shutdown. |
| **B3** | `PC-CLIENT-003` | `PLANNED` | SoftGlass tokens, dark/light theme presets, desktop shell rail, read-only storage root diagnostics. |
| **B4** | `PC-CLIENT-004` | `PLANNED` | Typed REST client, real-world SSE parser, live conversation UI, contract parity tests, React Web parity. |

---

## Batch 1 Checkpoints & Boundaries

- [x] Preflight checks verified (`feature/m1-flutter-foundation`, clean working tree).
- [x] Authoritative implementation plan persisted.
- [x] Create `frontend/flutter/pubspec.yaml` (root workspace) & `analysis_options.yaml`.
- [x] Create member packages: `companion_core`, `companion_api`, `companion_design`.
- [x] Scaffold `apps/desktop` via `flutter create --platforms=windows`.
- [x] Implement initial smoke-test application in `apps/desktop/lib/main.dart`.
- [x] Verify `dart pub get`, `dart pub workspace list`, `dart analyze`, and member tests.
- [x] Verify native Windows debug build: `flutter build windows --debug`.
- [x] Update `scripts/ci_policy.py`, `scripts/tests/test_ci_policy.py`, and `.github/workflows/ci.yml`.
- [x] Verify CI policy regression test suite.
- [x] Batch 1 independent review handoff.
