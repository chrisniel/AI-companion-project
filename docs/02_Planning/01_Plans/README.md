# Feature Implementation Plans (`docs/02_Planning/01_Plans/`)

> **Directory Role:** Feature-specific implementation plans for substantial features, sensitive designs, refactors, and migrations.
> **Workflow Authority:** Governed by the Four-Phase Engineering Delivery Lifecycle in [`docs/06_Guides/DELIVERY_WORKFLOW.md`](../../06_Guides/DELIVERY_WORKFLOW.md) and [`AGENTS.md`](../../../AGENTS.md).

---

## 1. Plan Authoring & Approval Policy

Feature implementation plans are authored using [`docs/02_Planning/02_Templates/implementation-plan-template.md`](../02_Templates/implementation-plan-template.md). Plan requirements and approvals scale with change risk according to the four delivery levels:

- **Level A (Routine Autonomous):** Low-risk mechanical changes and straightforward implementation proceed under prompt authorization without a separate formal plan ceremony.
- **Levels B & C (Planned Autonomous & Sensitive Design):** Substantial features and high-impact designs require an authored implementation plan and explicit **Human Owner** plan approval before Phase 2 implementation begins.
- **Autonomous Continuation:** Once the applicable plan gate is satisfied, the Implementing Agent continues autonomously through implementation, testing, canonical documentation, and draft PR packaging without requiring micro-approvals for intermediate substeps or ordinary in-scope bug fixes.

---

## 2. Tracking & Execution Discipline

- **Branch Active Execution Tracker:** While a delivery is in flight on an authorized feature branch, transient execution state (sub-slices, passing tests, blockers, provisional evidence) is tracked in [`docs/01_Tracking/active/task-[branch-slug].md`](../../01_Tracking/active/README.md).
- **Shared Milestone Tracker:** [`docs/01_Tracking/task.md`](../../01_Tracking/task.md) is reserved strictly for shared milestone goals, integration direction, and delivered checkpoints on `develop`/`master`. It does not track temporary branch heartbeats or in-flight PR state.

---

## 3. Plan Retention & Document Stability

- **Stable Document Paths:** Implementation plans remain at stable paths under `docs/02_Planning/01_Plans/` (named by work ID or feature, e.g. `plan-m3-character-studio-personality-b.md`) to serve as durable technical references for delivered architecture.
- **Branch Task Archival:** Branch-owned execution records are archived to [`docs/01_Tracking/archive/task-[branch-slug].md`](../../01_Tracking/archive/) on the feature branch during Phase 3 closure preparation, ensuring stable historical records without creating churn in planning document paths.
