# Implementation Planning Directory (`docs/02_Planning/`)

> **Directory Role:** Implementation planning hub for the AI Companion project. Houses the canonical Master Planning Spine, active feature implementation plans, standard planning templates, and historical planning archives.  
> **Status:** Active Canonical  
> **Authority Precedence:**
> 1. **System Architecture:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) and canonical domain specifications.
> 2. **Master Planning Spine:** [`docs/02_Planning/00_Master/`](./00_Master/) owns release milestones, work breakdown, backlog, and decision tracking.
> 3. **Active Sprint Execution State:** [`docs/01_Tracking/task.md`](../01_Tracking/task.md) owns the immediate in-flight task tracking.
> 4. **Feature Implementation Plans:** Specific feature plans in `01_Plans/` control step-by-step logic during approved implementation passes.

---

## 1. Master Planning Spine (`00_Master/`)

The Master Planning Spine is the single operational authority for release delivery, work breakdown, and decision traceability for PC V1 and beyond:

| Document | Primary Function |
| :--- | :--- |
| [`00_Master/DELIVERY_INDEX.md`](./00_Master/DELIVERY_INDEX.md) | Central delivery navigation hub linking milestones, active plans, WBS, and release gates. |
| [`00_Master/SPRINT_ROADMAP.md`](./00_Master/SPRINT_ROADMAP.md) | Release milestone roadmap (M0 Setup through M5 Golden Gate + Mobile Follow-On). |
| [`00_Master/WBS.md`](./00_Master/WBS.md) | Granular Work Breakdown Structure with stable tracking IDs (`PC-CLIENT`, `PC-HOST`, etc.). |
| [`00_Master/DECISION_REGISTER.md`](./00_Master/DECISION_REGISTER.md) | Master register mapping approved architectural decisions (D1–D16) to canonical owners. |
| [`00_Master/BACKLOG.md`](./00_Master/BACKLOG.md) | Partitioned backlog (`PC V1 Committed`, `PC Later`, `Experimental`, `Mobile Follow-On`, `Rejected`). |
| [`00_Master/MASTER_CHECKLIST.md`](./00_Master/MASTER_CHECKLIST.md) | Cross-layer capability readiness audit (spec, source, CI, Golden Gate verification). |
| [`00_Master/DECISION_DEBT.md`](./00_Master/DECISION_DEBT.md) | Explicit log of implementation-open details, required experiments, and bounded trade-offs. |

---

## 2. Directory Structure

```text
docs/02_Planning/
├── 00_Master/              # Canonical Master Planning Spine (active authority)
├── 01_Plans/               # Active feature implementation plans (per-feature execution)
├── 02_Templates/           # Standard implementation plan and RFC templates
├── 03_Archive/             # Completed feature plans and historical planning records
├── phase-08/               # Completed Phase 8 planning hub and delivery records (reference)
├── post-v1/                # Historical post-V1 design notes (superseded by 00_Master/BACKLOG.md)
├── ROADMAP.md              # Historical milestone roadmap (superseded by 00_Master/SPRINT_ROADMAP.md)
└── FEATURE_PROMOTION_MAP.md# Historical promotion tracker (superseded by 00_Master/WBS.md)
```

---

## 3. Active Plans (`01_Plans/`)

Active, approved implementation plans reside in [`01_Plans/`](./01_Plans/). Each plan is scoped to a specific subsystem or cohesive feature batch, following the standard template in [`02_Templates/implementation-plan-template.md`](./02_Templates/implementation-plan-template.md).

*(Note: Execution is currently paused after Phase 8 verification while the documentation and delivery workflow canonicalization completes; no active feature plan is in flight.)*

---

## 4. Templates (`02_Templates/`)

- [`02_Templates/implementation-plan-template.md`](./02_Templates/implementation-plan-template.md): Required 6-section template for drafting new feature implementation plans.

---

## 5. Archiving & Historical Plans

- Completed feature plans from historical sprints and phases reside in [`03_Archive/`](./03_Archive/) and [`docs/07_Archive/plans/`](../07_Archive/plans/).
- Historical Phase 8 plans remain in [`phase-08/`](./phase-08/) as authoritative delivery records for completed frontend, multimodal, and integration work.
- [`ROADMAP.md`](./ROADMAP.md) and [`FEATURE_PROMOTION_MAP.md`](./FEATURE_PROMOTION_MAP.md) are retained for historical auditability and are superseded by the Master Planning Spine.
