# Historical Delivery Walkthroughs Index (`docs/03_Walkthroughs/`)

> **Directory Role:** Point-in-time technical walkthroughs, verification logs, and developer handovers documenting completed pull requests and milestone deliveries.  
> **Status:** Historical Evidence (Non-Normative)  
> **AI Default Context Rule:** **Ignored by default.** Do not read or scan historical walkthroughs into startup context. Consult only when investigating specific PR implementation history, regressions, or provenance.

---

## 1. Authority & Interpretation Rules

- **Non-Normative Historical Evidence:** Walkthroughs record the state of the repository, architecture, and verification at their exact point of delivery. They carry zero authority over active system architecture or future milestone scope.
- **Source Code Establishes Reality:** Current system behavior must be verified against active source code (`backend/`, `frontend/web/`, `android/`) and automated test suites.
- **Canonical Architecture:** Authoritative technical specifications reside exclusively in [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) and domain specifications.
- **Point-in-Time Status & Test Counts:** Delivery statuses (e.g. "Implemented & Verified") and test suite numbers (e.g. 110, 115, 122 tests) reflect the test suite at delivery date, not current active baselines.
- **Retired Terminology:** Walkthroughs may contain superseded terminology (e.g., "Local AI Core", "Core-owned PID", older master-plan references). These are preserved intentionally as immutable forensic evidence.

---

## 2. Walkthrough Catalog

### 2.1 Android Companion Family (`android/`)

Iterative deliveries of the native Jetpack Compose Android client, UI design system, and prototype backend connectivity:

| Walkthrough Document | Delivery Date | Scope & Verified Deliverables | Related Archived Plan |
| :--- | :--- | :--- | :--- |
| [`android/walkthrough-android-ui-v1.1-refinement.md`](./android/walkthrough-android-ui-v1.1-refinement.md) | 2026-09-11 | UI V1.1 visual calibration, component consolidation, and theme state. | [`plan-android-ui-v1.1-refinement.md`](../07_Archive/plans/android/plan-android-ui-v1.1-refinement.md) |
| [`android/walkthrough-android-v1.1-corrective-pass.md`](./android/walkthrough-android-v1.1-corrective-pass.md) | 2026-09-11 | Gitignore tracking repair, hex color safety, and mock neutralization. | [`plan-android-v1.1-corrective-pass.md`](../07_Archive/plans/android/plan-android-v1.1-corrective-pass.md) |
| [`android/walkthrough-android-v1.1b-ux-and-visual-refinement.md`](./android/walkthrough-android-v1.1b-ux-and-visual-refinement.md) | 2026-09-11 | UX refinement, design token alignment, physical device verification. | [`plan-android-v1.1b-ux-and-visual-refinement.md`](../07_Archive/plans/android/plan-android-v1.1b-ux-and-visual-refinement.md) |
| [`android/walkthrough-android-v1.2-fluid-transitions-and-soft-glass-parity.md`](./android/walkthrough-android-v1.2-fluid-transitions-and-soft-glass-parity.md) | 2026-09-11 | Direction-aware spring transitions, swipe navigation, SoftGlass parity. | [`plan-android-v1.2-fluid-transitions-and-pure-neumorphism.md`](../07_Archive/plans/android/plan-android-v1.2-fluid-transitions-and-pure-neumorphism.md) |
| [`android/walkthrough-2026-09-12-light-mode-and-momentum-bounce.md`](./android/walkthrough-2026-09-12-light-mode-and-momentum-bounce.md) | 2026-09-12 | 120Hz display calibration, light theme tuning, and momentum elastic overscroll. | [`plan-2026-09-12-android-light-theme-neumorphism-bounce.md`](../07_Archive/plans/android/plan-2026-09-12-android-light-theme-neumorphism-bounce.md) |
| [`android/walkthrough-2026-09-12-oled-battery-saver-and-hybrid-ai.md`](./android/walkthrough-2026-09-12-oled-battery-saver-and-hybrid-ai.md) | 2026-09-12 | OLED pitch-black theme, SharedPreferences persistence, hybrid edge UI controls. | [`plan-android-visual-effects-vault-and-transitions.md`](../07_Archive/plans/android/plan-android-visual-effects-vault-and-transitions.md) |
| [`android/walkthrough-android-scroll-fluidity-performance-and-oled.md`](./android/walkthrough-android-scroll-fluidity-performance-and-oled.md) | 2026-09-12 | Scroll performance, decoupled background layer, animated Vault popover. | [`plan-android-scroll-fluidity-and-performance.md`](../07_Archive/plans/android/plan-android-scroll-fluidity-and-performance.md) |
| [`android/walkthrough-android-backend-connection-and-tasks.md`](./android/walkthrough-android-backend-connection-and-tasks.md) | 2026-09-12 | Prototype OkHttp network client, connection configuration, and live Tasks API sync. | [`plan-android-backend-connection-and-tasks.md`](../07_Archive/plans/android/plan-android-backend-connection-and-tasks.md) |
| [`android/walkthrough-android-sync-resilience-and-task-controls.md`](./android/walkthrough-android-sync-resilience-and-task-controls.md) | 2026-09-12 | Sync state persistence, date/time pickers, bidirectional SQLite sync, pull-to-refresh. | [`plan-android-sync-resilience-and-task-controls.md`](../07_Archive/plans/android/plan-android-sync-resilience-and-task-controls.md) |

### 2.2 Backend & Core Services Family (`backend/`)

Deliveries establishing the FastAPI backend, persistence, security baseline, and memory orchestrator:

| Walkthrough Document | Delivery Date | Scope & Verified Deliverables | Related Archived Plan |
| :--- | :--- | :--- | :--- |
| [`backend/walkthrough-backend-core-and-security.md`](./backend/walkthrough-backend-core-and-security.md) | 2026-09-12 | FastAPI bootstrap, SQLite WAL + Alembic, Tasks CRUD, pairing token auth. | [`plan-backend-core-and-security.md`](../07_Archive/plans/backend/plan-backend-core-and-security.md) |
| [`backend/walkthrough-backend-llm-runtime-integration.md`](./backend/walkthrough-backend-llm-runtime-integration.md) | 2026-09-12 | `llama-server.exe` integration (Track B4), GGUF execution, RX 580 VRAM profiles. | [`plan-backend-llm-runtime-integration.md`](../07_Archive/plans/backend/plan-backend-llm-runtime-integration.md) |
| [`backend/walkthrough-backend-security-hardening.md`](./backend/walkthrough-backend-security-hardening.md) | 2026-09-12 | Request size limiter (HTTP 413), default-deny auth routing, secret log redaction. | [`plan-backend-security-hardening.md`](../07_Archive/plans/backend/plan-backend-security-hardening.md) |
| [`backend/walkthrough-backend-security-v1.1.1-corrective-pass.md`](./backend/walkthrough-backend-security-v1.1.1-corrective-pass.md) | 2026-09-12 | 7 security hygiene items, CORS tightening, auth route protection verification. | [`plan-backend-security-v1.1.1-corrective-pass.md`](../07_Archive/plans/backend/plan-backend-security-v1.1.1-corrective-pass.md) |
| [`backend/walkthrough-backend-tasks-reminders-and-soft-delete.md`](./backend/walkthrough-backend-tasks-reminders-and-soft-delete.md) | 2026-09-12 | Task categories, reminder offsets/timestamps, user-scoped soft-delete & purge. | [`plan-backend-tasks-reminders-and-soft-delete.md`](../07_Archive/plans/backend/plan-backend-tasks-reminders-and-soft-delete.md) |
| [`backend/walkthrough-assistant-orchestration-and-memory.md`](./backend/walkthrough-assistant-orchestration-and-memory.md) | 2026-09-13 | Multi-turn chat orchestrator, SQLite FTS5 memory search, context budgeting. | [`plan-assistant-orchestration-and-memory.md`](../07_Archive/plans/plan-assistant-orchestration-and-memory.md) |

### 2.3 Runtime & Model Management Family (`runtime/`)

Deliveries managing `llama.cpp` runtime binaries, ports, and Model Registry:

| Walkthrough Document | Delivery Date | Scope & Verified Deliverables | Related Archived Plan |
| :--- | :--- | :--- | :--- |
| [`runtime/walkthrough-llama-router-and-model-registry-fix.md`](./runtime/walkthrough-llama-router-and-model-registry-fix.md) | 2026-09-14 | Router port 8085 migration, model residency verification, cold boot status truth. | [`plan-llama-router-and-model-registry-fix.md`](../07_Archive/plans/plan-llama-router-and-model-registry-fix.md) |
| [`runtime/walkthrough-runtime-rename-and-model-registry.md`](./runtime/walkthrough-runtime-rename-and-model-registry.md) | 2026-09-13 | Runtime folder separation (`runtime/`), per-model subdirectories, Registry Schema v3. | [`plan-runtime-rename-and-model-registry.md`](../07_Archive/plans/plan-runtime-rename-and-model-registry.md) |

### 2.4 Standalone & Integration Walkthroughs (Root)

Cross-cutting system verification, Web dashboard, and process handovers:

| Walkthrough Document | Delivery Date | Scope & Verified Deliverables | Related Archived Plan |
| :--- | :--- | :--- | :--- |
| [`walkthrough-phase7-pc-integration-verification.md`](./walkthrough-phase7-pc-integration-verification.md) | 2026-09-14 | Phase 7 end-to-end PC integration, hardware benchmarks, full-stack test suite. | [`plan-pc-runtime-web-assistant-stabilization.md`](../07_Archive/plans/plan-pc-runtime-web-assistant-stabilization.md) |
| [`walkthrough-web-dashboard-and-admin-controls.md`](./walkthrough-web-dashboard-and-admin-controls.md) | 2026-09-13 | React Web admin controls, tactile VRAM controls, model registry dashboard (Track C2). | [`plan-web-dashboard-and-admin-controls.md`](../07_Archive/plans/plan-web-dashboard-and-admin-controls.md) |
| [`walkthrough-documentation-workflow-and-master-plan.md`](./walkthrough-documentation-workflow-and-master-plan.md) | 2026-09-10 | Documentation StarterKit adoption, 7-section walkthrough template baseline. | [`plan-master-plan-reconciliation.md`](../07_Archive/plans/plan-master-plan-reconciliation.md) |

### 2.5 Authoring Templates
- [`walkthrough-template.md`](./walkthrough-template.md): Official 7-section template for drafting new delivery walkthroughs upon PR completion.
