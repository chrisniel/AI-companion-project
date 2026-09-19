# Documentation Authority Model & Repository Navigation Map

> **Document Role:** Canonical entry-point guide for all human contributors and AI agents.  
> **Status:** Active Canonical  
> **Last Updated:** 2026-09-20 (Reconciliation Pass R2)

---

## 1. Where to Start (New Contributors & AI Agents)

New contributors and AI agents must navigate the repository through this explicit entry hierarchy rather than reading historical drafts, superseded plans, or monolithic implementation logs:

```text
AGENTS.md
  │  (Process rules, token boundaries, git constraints)
  ▼
docs/06_Guides/DOCUMENTATION_MAP.md  [YOU ARE HERE]
  │  (Authority model, question-type routing, directory roles)
  ▼
docs/04_Architecture/SYSTEM_BASELINE.md
  │  (Product identity, V1 boundary, host topology, locked D1–D9 decisions)
  ▼
Domain Architecture / ADRs (as relevant to task)
  │  (docs/04_Architecture/LLAMA_CPP_*, VOICE_*, decisions/ADR-*)
  ▼
docs/01_Tracking/task.md  ──►  docs/02_Planning/plan-*.md
  (Current sprint & state)       (Task-specific implementation plan)
```

The reader does **not** need to consume giant historical master plans, retrospective audits, walkthroughs, or old drafts to understand current system architecture.

---

## 2. Documentation Authority Hierarchy

When seeking the authoritative answer to a question, consult documents in the following order of precedence:

### A. Process & Agent Behavior
1. **`AGENTS.md`** instructions and project profile constraints (Highest)
2. `CONTRIBUTING.md` / repository workflow rules
3. Approved task-specific implementation plan (`docs/02_Planning/plan-[feature].md`)

### B. Implemented Reality
1. **Source code** (`backend/`, `frontend/web/`, `android/`)
2. Generated contracts and schema configuration (`contracts/openapi/openapi.json`, Alembic versions)
3. Automated test suites (`pytest`, `vitest`, Android unit tests)
4. CI and runtime verification evidence

> [!IMPORTANT]
> **Implementation reality must never be invented from documentation.** If documentation describes a feature as working but source code or tests prove it is absent, the source code represents reality.

### C. Normative Architecture & Contracts
1. **Accepted ADRs** (`docs/04_Architecture/decisions/`)
2. **Canonical System Baseline** (`docs/04_Architecture/SYSTEM_BASELINE.md`)
3. Domain technical specifications (`docs/04_Architecture/*.md`)

### D. Product Intent & Scope
1. **Canonical System Baseline** (`docs/04_Architecture/SYSTEM_BASELINE.md` — defines locked V1 boundary)
2. Master reference plan (`docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`)
3. Approved roadmap / release definition

### E. Current Execution
1. **`docs/01_Tracking/task.md`** (Active sprint, immediate blockers, current state)
2. Active approved implementation plan (`docs/02_Planning/plan-[feature].md`)

### F. Historical Evidence (Non-Normative)
1. Delivery walkthroughs (`docs/03_Walkthroughs/`)
2. Completed and archived sprint tasks (`docs/01_Tracking/archive/`)
3. Archived historical drafts (`docs/07_Archive/`)

### G. Working & Unapproved Ideas (Non-Normative)
1. Scratchpads and brainstorms (`docs/00_Drafts/`) — Strictly ignored by default.

---

## 3. Conflict Reconciliation Principle

Historical documentation does not override normative architecture. However, when conflicts arise across layers, apply this nuanced rule:

> [!CAUTION]
> If historical evidence, implementation reality, and canonical architecture conflict, **do not blindly declare that "canonical architecture always wins."**  
> Such a conflict must trigger an explicit reconciliation step:
> - **Source code** establishes what is *currently implemented*.
> - **Canonical architecture** establishes the *intended normative design*.
> - **Historical evidence** explains *why divergence occurred* (e.g., intermediate refactoring, unmerged branches, temporary bridges).

When divergence is identified, the contributor or agent must report the mismatch and seek approval to reconcile code to architecture or update architecture to match intended changes.

---

## 4. Lifecycle Directories (Strict Numbered Hierarchy)

Per `AGENTS.md`, all documentation directories adhere to a zero-padded two-digit numbering scheme:

| Directory | Canonical Status | Role & Content | AI Default Context Rule |
| :--- | :--- | :--- | :--- |
| `docs/00_Drafts/` | **Non-Canonical** | Raw ideas, scratchpads, unreviewed notes, forensic audits. | **Strictly ignored** unless explicitly requested by user. |
| `docs/01_Tracking/` | **Canonical (Execution)** | Active `task.md` (target < 80 lines) and per-feature `archive/`. | Active `task.md` read on resume; `archive/` ignored. |
| `docs/02_Planning/` | **Canonical (Proposed)** | Feature-named plans (`plan-[feature].md`), TDDs, acceptance criteria. | Active plan read during planning; ignored during execution. |
| `docs/03_Walkthroughs/` | **Historical Evidence** | Verified delivery explanations and developer handoffs (7-section format). | Ignored unless investigating PR implementation history. |
| `docs/04_Architecture/` | **Canonical (Normative)** | System baseline, core contracts, API schemas, ADRs (`decisions/`). | Read on demand when relevant to active domain. |
| `docs/05_Design/` | **Canonical (Design)** | Product UI/UX, wireframes, character visual specs, narrative guides. | Read on demand when building frontend/mobile UI. |
| `docs/06_Guides/` | **Canonical (Guides)** | Contributor guides, setup instructions, documentation map, testing standards. | Read on demand for repository process guidance. |
| `docs/07_Archive/` | **Historical Reference** | Superseded drafts, old audits, deprecated documentation. | **Strictly ignored** unless performing a retrospective. |

### Permanent Exception
- `docs/ProjectWorkflowStarterKit/` is a user-owned permanent starter reference and is exempt from the numbered layout. It must never be moved, rewritten, deleted, or loaded into AI agent context.

---

## 5. Documents That Must NOT Be Treated as Authority

The following documents exist for historical, forensic, or template purposes and must **never** be treated as normative product or architectural authority:

1. **`docs/00_Drafts/09-16-2026-roadmap.md`**  
   An old user-authored working draft. It contains historical brainstorms and table status markers, but is non-normative and superseded by `docs/04_Architecture/SYSTEM_BASELINE.md`.
2. **`docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md`**  
   A forensic reconciliation audit document (Pass R0–R1). It records diagnostic evidence and reconciliation history, but the resulting decisions are codified in `SYSTEM_BASELINE.md`.
3. **Historical Walkthroughs (`docs/03_Walkthroughs/*`)**  
   Walkthroughs are point-in-time snapshots explaining specific past PR deliveries. They do not reflect subsequent refactors or active system architecture.
4. **Archived Task Files (`docs/01_Tracking/archive/*`)**  
   Completed sprint checklists preserved for tracking continuity only.
5. **Starter Reference (`docs/ProjectWorkflowStarterKit/*`)**  
   Reusable workflow templates, not active project documentation.
