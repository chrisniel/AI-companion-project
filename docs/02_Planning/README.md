# Implementation Planning Directory (`docs/02_Planning/`)

> **Directory Role:** Implementation planning hub for the AI Companion project. Houses the canonical Master Planning Spine, feature implementation plans, standard planning templates, and historical planning archives.
> **Status:** Active Canonical
> **Workflow Authority:** Governed by the Four-Phase Engineering Delivery Lifecycle in [`docs/06_Guides/DELIVERY_WORKFLOW.md`](../06_Guides/DELIVERY_WORKFLOW.md) and [`AGENTS.md`](../../AGENTS.md).
> **Authority Precedence:**
> 1. **System Architecture:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) and canonical domain specifications.
> 2. **Master Planning Spine:** [`docs/02_Planning/00_Master/`](./00_Master/) owns release milestones, work breakdown, backlog, and decision tracking.
> 3. **Shared Milestone State:** [`docs/01_Tracking/task.md`](../01_Tracking/task.md) owns shared milestone and integration state on `develop`/`master`.
> 4. **Branch Execution State:** Dedicated branch tasks in [`docs/01_Tracking/active/`](../01_Tracking/active/README.md) own in-flight branch execution state.
> 5. **Feature Implementation Plans:** Specific feature plans in [`01_Plans/`](./01_Plans/README.md) control step-by-step logic during approved implementation passes.

---

## 1. Master Planning Spine (`00_Master/`)

The Master Planning Spine is the single operational authority for release delivery, work breakdown, and decision traceability for PC V1 and beyond:

| Document | Primary Function |
| :--- | :--- |
| [`00_Master/DELIVERY_INDEX.md`](./00_Master/DELIVERY_INDEX.md) | Central delivery navigation hub linking milestones, active plans, WBS, and release gates. |
| [`00_Master/SPRINT_ROADMAP.md`](./00_Master/SPRINT_ROADMAP.md) | Release milestone roadmap (M0 Setup through M5 Golden Gate + Mobile Follow-On). |
| [`00_Master/WBS.md`](./00_Master/WBS.md) | Granular Work Breakdown Structure with stable tracking IDs (`PC-CLIENT`, `PC-HOST`, etc.). |
| [`00_Master/DECISION_REGISTER.md`](./00_Master/DECISION_REGISTER.md) | Master register mapping approved architectural decisions (D1-D11) to canonical owners. |
| [`00_Master/BACKLOG.md`](./00_Master/BACKLOG.md) | Partitioned backlog (`PC V1 Committed`, `PC Later`, `Experimental`, `Mobile Follow-On`, `Rejected`). |
| [`00_Master/MASTER_CHECKLIST.md`](./00_Master/MASTER_CHECKLIST.md) | Cross-layer capability readiness audit (spec, source, CI, Golden Gate verification). |
| [`00_Master/DECISION_DEBT.md`](./00_Master/DECISION_DEBT.md) | Explicit log of implementation-open details, required experiments, and bounded trade-offs. |

---

## 2. Directory Structure

```text
docs/02_Planning/
├── 00_Master/              # Canonical Master Planning Spine (active authority)
├── 01_Plans/               # Feature implementation plans (per-feature execution)
├── 02_Templates/           # Standard implementation plan and RFC templates
├── 03_Archive/             # Completed historical planning records
├── phase-08/               # Completed Phase 8 planning hub and delivery records (reference)
├── post-v1/                # Historical post-V1 design notes (superseded by 00_Master/BACKLOG.md)
├── ROADMAP.md              # Historical milestone roadmap (superseded by 00_Master/SPRINT_ROADMAP.md)
└── FEATURE_PROMOTION_MAP.md# Historical promotion tracker (superseded by 00_Master/WBS.md)
```

---

## 3. Feature Plans (`01_Plans/`)

Implementation plans reside in [`01_Plans/`](./01_Plans/README.md). Each plan is scoped to a specific subsystem or cohesive feature batch, following the standard template in [`02_Templates/implementation-plan-template.md`](./02_Templates/implementation-plan-template.md) and the four-phase workflow in [`docs/06_Guides/DELIVERY_WORKFLOW.md`](../06_Guides/DELIVERY_WORKFLOW.md).

---

## 4. Templates (`02_Templates/`)

- [`02_Templates/implementation-plan-template.md`](./02_Templates/implementation-plan-template.md): Standard template for authoring feature implementation plans under Phase 1.

---

## 5. Archiving & Historical Plans

- Completed feature plans from historical sprints and phases reside in [`03_Archive/`](./03_Archive/) and [`docs/07_Archive/plans/`](../07_Archive/plans/).
- Historical Phase 8 plans remain in [`phase-08/`](./phase-08/) as authoritative delivery records for completed frontend, multimodal, and integration work.
- [`ROADMAP.md`](./ROADMAP.md) and [`FEATURE_PROMOTION_MAP.md`](./FEATURE_PROMOTION_MAP.md) are retained for historical auditability and are superseded by the Master Planning Spine.
