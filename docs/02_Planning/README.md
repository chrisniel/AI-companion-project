# Implementation Planning Index (`docs/02_Planning/`)

This directory houses feature-named implementation plans, Technical Design Documents (TDDs), and acceptance criteria for software deliverables.

## Core Rules & Context Boundaries

- **Implementation vs. Architecture:** Planning documents describe bounded implementation work and feature execution. Durable technical contracts, system boundaries, and API schemas belong in [`docs/04_Architecture/`](../04_Architecture/).
- **Active Execution State:** Current sprint goals, checklists, and blockers belong in [`docs/01_Tracking/task.md`](../01_Tracking/task.md).
- **Historical Plans:** Completed plans remain in this directory for historical context and architectural provenance. Moving a plan into a subdirectory organizes navigation without modifying its technical status or authority.

---

## Directory Organization

### 1. Phase 8 (PC Frontend, Runtime Config, Multimodal & Polish)
- **Hub:** [`phase-08/README.md`](./phase-08/README.md)
- **Active Implementation Plan:** [`phase-08/plan-phase8-pc-frontend-architecture-ux.md`](./phase-08/plan-phase8-pc-frontend-architecture-ux.md) — Single authoritative plan for Phase 8 (8A, 8P, 8B, 8C).

### 2. Android (`android/`)
Historical and active client implementation plans for the Android companion application:
- [`android/plan-2026-09-12-android-light-theme-neumorphism-bounce.md`](./android/plan-2026-09-12-android-light-theme-neumorphism-bounce.md) — Light theme neumorphic styling and bounce physics.
- [`android/plan-android-backend-connection-and-tasks.md`](./android/plan-android-backend-connection-and-tasks.md) — Android-to-FastAPI backend connectivity and task sync.
- [`android/plan-android-scroll-fluidity-and-performance.md`](./android/plan-android-scroll-fluidity-and-performance.md) — Jetpack Compose scroll performance and frame-pacing optimization.
- [`android/plan-android-sync-resilience-and-task-controls.md`](./android/plan-android-sync-resilience-and-task-controls.md) — Sync retry resilience, error handling, and task control UI.
- [`android/plan-android-ui-v1.1-refinement.md`](./android/plan-android-ui-v1.1-refinement.md) — UI v1.1 components and layout refinement.
- [`android/plan-android-v1.1-corrective-pass.md`](./android/plan-android-v1.1-corrective-pass.md) — Corrective styling and spacing pass for Android v1.1.
- [`android/plan-android-v1.1b-ux-and-visual-refinement.md`](./android/plan-android-v1.1b-ux-and-visual-refinement.md) — UX polish, micro-animations, and visual tokens.
- [`android/plan-android-v1.2-fluid-transitions-and-pure-neumorphism.md`](./android/plan-android-v1.2-fluid-transitions-and-pure-neumorphism.md) — Fluid screen transitions and pure neumorphic component rendering.
- [`android/plan-android-v1.3-assistant-input-and-bouncy-transitions.md`](./android/plan-android-v1.3-assistant-input-and-bouncy-transitions.md) — Assistant voice/text input bar and physics-based transitions.
- [`android/plan-android-v1.4-neumorphic-engine-and-ui-parity.md`](./android/plan-android-v1.4-neumorphic-engine-and-ui-parity.md) — Neumorphic engine harmonization and component parity.
- [`android/plan-android-visual-effects-vault-and-transitions.md`](./android/plan-android-visual-effects-vault-and-transitions.md) — Visual effects shaders, elevation tokens, and vault screen transitions.

### 3. Backend (`backend/`)
Historical backend infrastructure, LLM runtime, tasks, and security hardening plans:
- [`backend/plan-backend-core-and-security.md`](./backend/plan-backend-core-and-security.md) — Core FastAPI architecture, authentication flow, and initial security controls.
- [`backend/plan-backend-llm-runtime-integration.md`](./backend/plan-backend-llm-runtime-integration.md) — Local llama.cpp runtime subprocess integration (Track B4).
- [`backend/plan-backend-security-hardening.md`](./backend/plan-backend-security-hardening.md) — Security audit remediation and endpoint validation hardening.
- [`backend/plan-backend-security-v1.1.1-corrective-pass.md`](./backend/plan-backend-security-v1.1.1-corrective-pass.md) — Security audit corrective pass and phased roadmap.
- [`backend/plan-backend-tasks-reminders-and-soft-delete.md`](./backend/plan-backend-tasks-reminders-and-soft-delete.md) — Task reminders, soft deletion, and category schema (Track B6).

### 4. Templates (`templates/`)
- [`templates/implementation-plan-template.md`](./templates/implementation-plan-template.md) — Official starter template for new feature implementation plans.

### 5. Cross-Cutting & Web Integration Plans (Planning Root)
General, cross-cutting, and web integration plans retained at the root of `docs/02_Planning/`:
- [`plan-assistant-orchestration-and-memory.md`](./plan-assistant-orchestration-and-memory.md) — Multi-turn assistant orchestration, conversation persistence, and SQLite FTS5 memory store (Track B5).
- [`plan-llama-router-and-model-registry-fix.md`](./plan-llama-router-and-model-registry-fix.md) — llama.cpp router model discovery, provider detection, and live status synchronization.
- [`plan-master-plan-reconciliation.md`](./plan-master-plan-reconciliation.md) — Documentation migration and master plan reconciliation audit.
- [`plan-pc-runtime-web-assistant-stabilization.md`](./plan-pc-runtime-web-assistant-stabilization.md) — PC runtime stabilization, Models UI reconciliation, and SSE streaming reliability.
- [`plan-runtime-rename-and-model-registry.md`](./plan-runtime-rename-and-model-registry.md) — Initial runtime directory rename (`provider/` → `runtime/`) and model registry foundation.
- [`plan-task-datetime-and-reminder-database-sync.md`](./plan-task-datetime-and-reminder-database-sync.md) — Task due date calculation, ISO-8601 UTC normalization, and SQLite persistence.
- [`plan-web-dashboard-and-admin-controls.md`](./plan-web-dashboard-and-admin-controls.md) — React web dashboard connection to FastAPI and local AI admin controls (Track C2).
- [`plan-web-frontend-productionization.md`](./plan-web-frontend-productionization.md) — Web frontend refactoring and preparation for backend integration.
