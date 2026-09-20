# Implementation Planning Index (`docs/02_Planning/`)

> **Directory Role:** Canonical catalog for all feature-named implementation plans, Technical Design Documents (TDDs), and milestone roadmaps.  
> **Status:** Active Canonical (Reconciled in Pass R4)  
> **Authority Precedence:**
> 1. **System Architecture:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) and domain specifications.
> 2. **Product Delivery Roadmap:** [`docs/02_Planning/ROADMAP.md`](./ROADMAP.md).
> 3. **Active Sprint Execution State:** [`docs/01_Tracking/task.md`](../01_Tracking/task.md).
> 4. **Feature Implementation Plans:** Specific feature plans in this directory control execution steps during feature delivery.

---

## 1. Canonical Product Roadmap

- **[`ROADMAP.md`](./ROADMAP.md):** The single authoritative product and milestone delivery roadmap for the AI Companion ecosystem. Defines active delivery gates, V1 scope boundaries, post-V1 milestone tracks, and technical hardening recommendations.

---

## 2. Planning Document Classification & Status Catalog

All planning documents across `docs/02_Planning/` are classified below according to active implementation truth:

### 2.1 Active & Upcoming Feature Plans

| Document Path | Title / Focus Area | Current Classification | Evidence & Status | Canonical Authority | Proposed R5 Disposition |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [`phase-08/README.md`](./phase-08/README.md) | Phase 8 Planning Hub | **`ACTIVE / CURRENT`** | Active hub for Phase 8. 8A & 8P complete; R0–R8 current gate; 8B next; 8C planned. | Authoritative Phase 8 hub. | Retain in `docs/02_Planning/phase-08/`. |
| [`phase-08/plan-phase8-pc-frontend-architecture-ux.md`](./phase-08/plan-phase8-pc-frontend-architecture-ux.md) | Phase 8 Architecture & Multimodal Plan | **`ACTIVE / CURRENT`** | 8A and 8P verified; owns upcoming execution steps for 8B (Multimodal Vision) and 8C (Polish). | Authoritative feature plan for 8B and 8C. | Retain in `docs/02_Planning/phase-08/`. |

### 2.2 Planning Starter Templates

| Document Path | Title / Focus Area | Current Classification | Evidence & Status | Canonical Authority | Proposed R5 Disposition |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [`templates/implementation-plan-template.md`](./templates/implementation-plan-template.md) | Feature Implementation Plan Template | **`TEMPLATE`** | Official starter template for feature planning. | Authoritative template. | Retain in `docs/02_Planning/templates/`. |

### 2.3 Post-V1 Planning Sources (Android Backend & Sync)

> [!IMPORTANT]
> **Decision D1 Release Boundary:** Production Android backend synchronization and offline inference are strictly **POST-V1**. The documents below contain exploratory architectural planning but do **not** represent active V1 delivery scope.

| Document Path | Title / Focus Area | Current Classification | Evidence & Status | Canonical Authority | Proposed R5 Disposition |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [`android/plan-android-backend-connection-and-tasks.md`](./android/plan-android-backend-connection-and-tasks.md) | Android Backend Connection & Task Sync | **`POST-V1 PLANNING SOURCE`** | Android HTTP/SSE client and Task API integration. Deferred beyond V1 per Decision D1. | Non-authoritative for V1; reference for Track M-Android-Connected. | Move to `docs/02_Planning/post-v1/android/` in R5. |
| [`android/plan-android-sync-resilience-and-task-controls.md`](./android/plan-android-sync-resilience-and-task-controls.md) | Android Sync Resilience & Task Controls | **`POST-V1 PLANNING SOURCE`** | Offline queue and sync resilience. Deferred beyond V1 per Decision D1. | Non-authoritative for V1; reference for Track M-Android-Offline. | Move to `docs/02_Planning/post-v1/android/` in R5. |

### 2.4 Completed Historical Plans (Cross-Cutting & Backend)

The plans below represent completed engineering tracks whose implementations are merged and verified in the repository. They are retained for architectural provenance and point-in-time audit reference:

| Document Path | Title / Focus Area | Current Classification | Verification Evidence | Canonical Authority | Proposed R5 Disposition |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [`plan-assistant-orchestration-and-memory.md`](./plan-assistant-orchestration-and-memory.md) | Assistant Orchestration & SQLite Memory | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7 (`orchestrator.py`, SQLite FTS5). | Superseded by canonical architecture. | Move to `docs/07_Archive/plans/` in R5. |
| [`plan-llama-router-and-model-registry-fix.md`](./plan-llama-router-and-model-registry-fix.md) | Llama Router & Model Registry Fix | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7/8 (`llama_cpp.py`, port 8085). | Superseded by `LLAMA_CPP_...`. | Move to `docs/07_Archive/plans/` in R5. |
| [`plan-master-plan-reconciliation.md`](./plan-master-plan-reconciliation.md) | Master Plan Reconciliation Audit | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7 audit. | Historical audit plan. | Move to `docs/07_Archive/plans/` in R5. |
| [`plan-pc-runtime-web-assistant-stabilization.md`](./plan-pc-runtime-web-assistant-stabilization.md) | PC Runtime & Web Assistant Stabilization | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7/8A. | Superseded by canonical architecture. | Move to `docs/07_Archive/plans/` in R5. |
| [`plan-runtime-rename-and-model-registry.md`](./plan-runtime-rename-and-model-registry.md) | Runtime Rename & Model Registry | **`COMPLETED / HISTORICAL`** | Implemented in Phase 8P (Local AI Runtime rename). | Superseded by `AI_COMPANION_RUNTIME_...`. | Move to `docs/07_Archive/plans/` in R5. |
| [`plan-task-datetime-and-reminder-database-sync.md`](./plan-task-datetime-and-reminder-database-sync.md) | Task Datetime & SQLite Sync | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7 (ISO-8601 UTC tasks). | Superseded by canonical architecture. | Move to `docs/07_Archive/plans/` in R5. |
| [`plan-web-dashboard-and-admin-controls.md`](./plan-web-dashboard-and-admin-controls.md) | React Web Dashboard & Admin Controls | **`COMPLETED / HISTORICAL`** | Implemented in Phase 6/7. | Superseded by canonical architecture. | Move to `docs/07_Archive/plans/` in R5. |
| [`plan-web-frontend-productionization.md`](./plan-web-frontend-productionization.md) | Web Frontend Productionization | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7/8A. | Superseded by canonical architecture. | Move to `docs/07_Archive/plans/` in R5. |
| [`backend/plan-backend-core-and-security.md`](./backend/plan-backend-core-and-security.md) | Backend Core & Security Baseline | **`COMPLETED / HISTORICAL`** | Implemented in Phase 6/7 (`security.py`, auth token). | Superseded by `SECURITY_...`. | Move to `docs/07_Archive/plans/backend/` in R5. |
| [`backend/plan-backend-llm-runtime-integration.md`](./backend/plan-backend-llm-runtime-integration.md) | LLM Runtime Integration | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7 (`llama-server.exe` subprocess). | Superseded by `LLAMA_CPP_...`. | Move to `docs/07_Archive/plans/backend/` in R5. |
| [`backend/plan-backend-security-hardening.md`](./backend/plan-backend-security-hardening.md) | Backend Security Hardening | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7 (path traversal, body limits). | Superseded by `SECURITY_...`. | Move to `docs/07_Archive/plans/backend/` in R5. |
| [`backend/plan-backend-security-v1.1.1-corrective-pass.md`](./backend/plan-backend-security-v1.1.1-corrective-pass.md) | Security Audit Corrective Pass | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7. | Superseded by `SECURITY_...`. | Move to `docs/07_Archive/plans/backend/` in R5. |
| [`backend/plan-backend-tasks-reminders-and-soft-delete.md`](./backend/plan-backend-tasks-reminders-and-soft-delete.md) | Tasks, Reminders & Soft Delete | **`COMPLETED / HISTORICAL`** | Implemented in Phase 7 (`005_scope_message_constraints`). | Superseded by canonical architecture. | Move to `docs/07_Archive/plans/backend/` in R5. |

### 2.5 Completed Historical Plans (Android UI Prototype)

The plans below document the iterative creation and styling of the 17-screen Jetpack Compose Android prototype in `android/`. All 110 unit tests pass. These plans are fully delivered and non-authoritative for new work:

| Document Path | Title / Focus Area | Current Classification | Verification Evidence | Proposed R5 Disposition |
| :--- | :--- | :--- | :--- | :--- |
| [`android/plan-2026-09-12-android-light-theme-neumorphism-bounce.md`](./android/plan-2026-09-12-android-light-theme-neumorphism-bounce.md) | Light Theme Neumorphism & Bounce | **`COMPLETED / HISTORICAL`** | 17 screens verified in `android/`. | Move to `docs/07_Archive/plans/android/` in R5. |
| [`android/plan-android-scroll-fluidity-and-performance.md`](./android/plan-android-scroll-fluidity-and-performance.md) | Scroll Fluidity & Performance | **`COMPLETED / HISTORICAL`** | Compose overscroll physics verified. | Move to `docs/07_Archive/plans/android/` in R5. |
| [`android/plan-android-ui-v1.1-refinement.md`](./android/plan-android-ui-v1.1-refinement.md) | Android UI v1.1 Refinement | **`COMPLETED / HISTORICAL`** | UI components delivered in `android/`. | Move to `docs/07_Archive/plans/android/` in R5. |
| [`android/plan-android-v1.1-corrective-pass.md`](./android/plan-android-v1.1-corrective-pass.md) | UI v1.1 Corrective Pass | **`COMPLETED / HISTORICAL`** | Styling pass verified in `android/`. | Move to `docs/07_Archive/plans/android/` in R5. |
| [`android/plan-android-v1.1b-ux-and-visual-refinement.md`](./android/plan-android-v1.1b-ux-and-visual-refinement.md) | UI v1.1b UX & Visual Refinement | **`COMPLETED / HISTORICAL`** | Visual tokens verified in `android/`. | Move to `docs/07_Archive/plans/android/` in R5. |
| [`android/plan-android-v1.2-fluid-transitions-and-pure-neumorphism.md`](./android/plan-android-v1.2-fluid-transitions-and-pure-neumorphism.md) | Fluid Transitions & Pure Neumorphism | **`COMPLETED / HISTORICAL`** | Transition engine verified in `android/`. | Move to `docs/07_Archive/plans/android/` in R5. |
| [`android/plan-android-v1.3-assistant-input-and-bouncy-transitions.md`](./android/plan-android-v1.3-assistant-input-and-bouncy-transitions.md) | Assistant Input & Bouncy Transitions | **`COMPLETED / HISTORICAL`** | Input bar verified in `android/`. | Move to `docs/07_Archive/plans/android/` in R5. |
| [`android/plan-android-v1.4-neumorphic-engine-and-ui-parity.md`](./android/plan-android-v1.4-neumorphic-engine-and-ui-parity.md) | Neumorphic Engine & UI Parity | **`COMPLETED / HISTORICAL`** | Neumorphic engine verified in `android/`. | Move to `docs/07_Archive/plans/android/` in R5. |
| [`android/plan-android-visual-effects-vault-and-transitions.md`](./android/plan-android-visual-effects-vault-and-transitions.md) | Visual Effects & Transitions | **`COMPLETED / HISTORICAL`** | Shaders & vault verified in `android/`. | Move to `docs/07_Archive/plans/android/` in R5. |
