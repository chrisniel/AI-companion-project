# Documentation Authority Model & Global Navigation Map

> **Document Role:** Canonical entry-point guide and sole global authority map for all human contributors and AI agents.  
> **Status:** Active Canonical  
> **Last Updated:** 2026-10-02 (PC V1 Decision Pass Alignment)

---

## 1. Where to Start (Startup Routing Sequence)

All contributors and AI agents must navigate the repository through this explicit entry hierarchy rather than reading historical drafts, superseded plans, or legacy roadmaps:

```text
AGENTS.md
  │  (Process rules, token boundaries, human Git ownership, safety invariants)
  ▼
docs/06_Guides/DOCUMENTATION_MAP.md  [YOU ARE HERE]
  │  (Global authority model, question routing, directory catalog)
  ▼
docs/04_Architecture/SYSTEM_BASELINE.md
  │  (Product identity, PC V1 boundary, host topology, locked Decisions D1-D11, Golden Gate)
  ▼
docs/02_Planning/00_Master/DELIVERY_INDEX.md
  │  (Consulted when milestone sequencing, WBS ID, or backlog status matters)
  ▼
Relevant Focused Canonical Domain Specification & Accepted ADR(s)
  │  (Load ONLY the specific domain spec relevant to the active task)
  ▼
docs/01_Tracking/task.md
    │  (If on develop/master: shared milestone goals and integration state)
    ▼
[OR]

docs/01_Tracking/active/task-[branch-slug].md
    │  (If on short-lived task branch: transient branch execution state)
  ▼
Relevant Active Implementation Plan (in docs/02_Planning/01_Plans/)
```

> [!IMPORTANT]
> **Context & Reality Invariants:**
> - **Source Code, Automated Tests, and Generated Contracts** are authoritative for implemented reality. Implementation reality must never be inferred from documentation intent.
> - **Historical Context Discipline:** Walkthroughs (`docs/03_Walkthroughs/`), archives (`docs/07_Archive/`), completed task checklists (`docs/01_Tracking/archive/`), and working drafts (`docs/00_Drafts/`) are **NOT** normal startup context.
> - **Domain Focus:** Load only the specific focused domain specification relevant to your active task.

---

## 2. Documentation Authority Hierarchy

When seeking the authoritative answer to any question, consult documents and artifacts according to this explicit authority tier:

| Authority Tier | Canonical Artifact / Document | Authority Scope |
| :--- | :--- | :--- |
| **1. Implemented Reality** | **Source Code, Tests, OpenAPI & Migrations** (`backend/`, `frontend/web/`, `contracts/openapi/openapi.json`, Alembic migrations) | **Authoritative for what actually exists.** Code reality always supersedes documentation claims. |
| **2. System Architecture & Release Boundaries** | **System Baseline** ([`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md)) | **Authoritative for cross-cutting ecosystem architecture, platform release boundaries, locked Decisions D1-D11, and the 14-group Golden Gate.** |
| **3. Normative Domain Architecture** | **Focused Domain Specifications** ([`docs/04_Architecture/`](../04_Architecture/README.md): `01_Domains/`, `02_Data_and_Security/`, `03_Integrations/`, `04_Infrastructure/`) | **Primary normative authority for domain data models, business invariants, security policies, and technical capability specs.** |
| **4. Architectural Decisions** | **Accepted ADRs** ([`docs/04_Architecture/decisions/`](../04_Architecture/decisions/README.md)) | **Durable decision records containing context, trade-offs, and consequences. ADRs do not compete with domain specs.** |
| **5. Master Planning Spine** | **Master Planning Hub** ([`docs/02_Planning/00_Master/`](../02_Planning/00_Master/DELIVERY_INDEX.md)) | **Authoritative for milestone roadmaps, Work Breakdown Structure (WBS), backlog categorization, and decision indexing.** |
| **6. UX & Presentation** | **Design Specifications** ([`docs/05_Design/`](../05_Design/README.md)) | **Authoritative for interface layout, styling, interaction models, and visual language.** Subordinate to architecture contracts. |
| **7. Active Execution** | **Active Branch Task** (`docs/01_Tracking/active/task-[branch-slug].md`) | **Authoritative for current in-flight task execution, immediate sub-slices, and blockers.** Target under 80 lines. |
| **8. Approved Implementation Logic** | **Active Feature Plans** ([`docs/02_Planning/01_Plans/`](../02_Planning/01_Plans/README.md)) | **Authoritative for step-by-step logic, pseudocode, and TDD steps during an active feature delivery.** |
| **9. Contributor & Engineering Guides** | **Guides Directory** ([`docs/06_Guides/`](./DELIVERY_WORKFLOW.md)) | **Authoritative for delivery workflows, developer setup, testing standards, and PR protocols.** |
| **10. Historical Evidence (Non-Normative)** | **Walkthroughs, Archives & Legacy Notes** (`docs/03_Walkthroughs/`, `docs/01_Tracking/archive/`, `docs/07_Archive/`, `docs/02_Planning/ROADMAP.md`) | **Historical point-in-time delivery records and superseded roadmaps.** Strictly non-normative. |
| **11. Scratchpads (Non-Normative)** | **Drafts** (`docs/00_Drafts/`) | **Unreviewed brainstorms.** Strictly ignored by default. |

---

## 3. Question Routing Guide

Use this matrix to identify the single canonical owner for specific questions:

| If your question is about... | Consult this Canonical Document |
| :--- | :--- |
| System boundaries, PC V1 scope, or cross-cutting invariants | [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) |
| Architecture decisions, rationale, or ADR numbers | [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../02_Planning/00_Master/DECISION_REGISTER.md) & [`docs/04_Architecture/decisions/`](../04_Architecture/decisions/README.md) |
| Delivery milestones, release phases, or schedule | [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../02_Planning/00_Master/SPRINT_ROADMAP.md) |
| Work Breakdown Structure, task IDs, or milestone owners | [`docs/02_Planning/00_Master/WBS.md`](../02_Planning/00_Master/WBS.md) |
| Backlog categorization (Committed vs. Later vs. Rejected) | [`docs/02_Planning/00_Master/BACKLOG.md`](../02_Planning/00_Master/BACKLOG.md) |
| Readiness checklist across specs, code, and Golden Gate | [`docs/02_Planning/00_Master/MASTER_CHECKLIST.md`](../02_Planning/00_Master/MASTER_CHECKLIST.md) |
| Unresolved implementation details or technical debt | [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../02_Planning/00_Master/DECISION_DEBT.md) |
| Assistant turns, SSE stream, or conversation state | [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../04_Architecture/01_Domains/assistant-and-conversations.md) |
| Characters, continuous personality traits, or moods | [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md) |
| Memory extraction, lexical search, or memory scopes | [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](../04_Architecture/01_Domains/memory-and-personalization.md) |
| Tasks, Reminders, Alarms, or Routines | [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md) |
| Speech engines (STT/TTS), audio hardware, or WebSocket | [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../04_Architecture/01_Domains/voice-and-audio.md) |
| Multimodal vision attachments or media handling | [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../04_Architecture/01_Domains/multimodal-and-media.md) |
| Multi-profile ownership model or satellite device binding | [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../04_Architecture/02_Data_and_Security/profiles-and-devices.md) |
| Action execution, Default Deny policy, or risk levels | [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md) |
| Web Search, Fetch, Weather, or SSRF protection | [`docs/04_Architecture/03_Integrations/web-current-information.md`](../04_Architecture/03_Integrations/web-current-information.md) |
| Model execution, D6 scan import, or single resident model | [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](../04_Architecture/04_Infrastructure/runtime-and-models.md) |
| Storage roots (Install, Data, Library, Cache, Logs) | [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](../04_Architecture/04_Infrastructure/storage-and-assets.md) |
| Windows host autostart, tray minimization, notifications | [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md) |
| Backup, restore verification, or factory reset | [`docs/04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md`](../04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md) |
| Gaming mode, Low-Impact profile, or resource limits | [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](../04_Architecture/04_Infrastructure/performance-and-capacity.md) |
| Desktop UI shell, tray interactions, or visual styling | [`docs/05_Design/`](../05_Design/README.md) |
| Delivery gates, Git ownership, or walkthrough templates | [`docs/06_Guides/DELIVERY_WORKFLOW.md`](./DELIVERY_WORKFLOW.md) |
| Developer workstation setup, compilers, or venv | [`docs/06_Guides/DEVELOPMENT_SETUP.md`](./DEVELOPMENT_SETUP.md) |
| Test execution, CI pipeline design, or Golden Gate | [`docs/06_Guides/TESTING_AND_CI.md`](./TESTING_AND_CI.md) |
| Immediate active sprint tasks and blockers | `docs/01_Tracking/active/task-[branch-slug].md` |

---

## 4. Strict Numbered Directory Layout

| Directory | Canonical Status | Role & Content | AI Context Default |
| :--- | :--- | :--- | :--- |
| `docs/00_Drafts/` | Non-Canonical | Scratchpads, unreviewed brainstorms. | **Strictly ignored.** |
| `docs/01_Tracking/` | Canonical (Execution) | Shared `task.md`, active branch execution in `active/`, historical delivery in `archive/`. | `task.md` read on develop; `active/` on branch. |
| `docs/02_Planning/` | Canonical (Planning) | Master Planning Spine (`00_Master/`), active plans (`01_Plans/`), templates, and historical archives. | `DELIVERY_INDEX.md` consulted on startup; active plan during execution. |
| `docs/03_Walkthroughs/` | Historical Evidence | Point-in-time delivery records and handovers. | Ignored during normal startup. |
| `docs/04_Architecture/` | Canonical (Normative) | System Baseline, ADRs (`decisions/`), and 18 focused domain specifications. | Consulted on demand per active domain. |
| `docs/05_Design/` | Canonical (Design) | UI/UX design specifications and visual presence specs. | Consulted on demand when modifying UI. |
| `docs/06_Guides/` | Canonical (Guides) | Onboarding, workflow, setup, testing, and navigation guides. | Read on demand for process/setup guidance. |
| `docs/07_Archive/` | Historical Reference | Superseded legacy audits, deprecated drafts, and historical plans. | **Strictly ignored.** |

*Permanent StarterKit Exception:* `docs/ProjectWorkflowStarterKit/` is a user-owned reference and remains exempt from numbered hierarchy.

---

## 5. Superseded & Deprecated Documents Index

To prevent confusion, the following documents are officially superseded and must not be used as current authority:

| Legacy Document | Superseded By | Status |
| :--- | :--- | :--- |
| `docs/02_Planning/ROADMAP.md` | [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../02_Planning/00_Master/SPRINT_ROADMAP.md) | Superseded / Preserved for Phase 1–8 history |
| `docs/02_Planning/FEATURE_PROMOTION_MAP.md` | [`docs/02_Planning/00_Master/WBS.md`](../02_Planning/00_Master/WBS.md) | Superseded / Preserved for Phase 1–8 history |
| `docs/02_Planning/03_Archive/PROACTIVE_COMPANION_ROUTINES.md` | [`docs/02_Planning/00_Master/BACKLOG.md`](../02_Planning/00_Master/BACKLOG.md) (Routines promoted to PC V1) | Superseded / Historical design note |
| `docs/07_Archive/reference/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` | [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) & Master Spine | Superseded / Historical reference |
