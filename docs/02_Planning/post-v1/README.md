# Post-V1 Planning Sources (`docs/02_Planning/post-v1/`)

> **Directory Role:** Repository for exploratory technical designs, feature plans, and integration documents that are explicitly outside the AI Companion V1 release boundary.  
> **Status:** Future Planning Sources (Non-Authoritative for V1)  
> **Authority Precedence:**
> 1. **Locked V1 Boundary:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) owns the release boundary (Decision D1).
> 2. **Milestone Sequencing:** [`docs/02_Planning/ROADMAP.md`](../ROADMAP.md) owns the authoritative delivery sequence.
> 3. **Normative Architecture:** Domain architecture documents in [`docs/04_Architecture/`](../../04_Architecture/) own technical standards.

---

## 1. Post-V1 Planning Principles

Documents in this directory represent future product planning inputs, **not** active V1 implementation plans and **not** historical archives:

- **Non-Authoritative for V1:** Nothing in this directory may be used to expand or alter the active V1 release scope or immediate sprint tasks.
- **Milestone Sequencing:** All work documented here is mapped to post-V1 roadmap tracks (e.g., Track M-Proactive, Track M-Android-Connected, Track M-Android-Offline).
- **Mandatory Revalidation:** Because these documents represent exploratory designs, they must be formally revalidated against current canonical architecture and active contracts before their respective milestones begin execution.
- **Completed Prototype Work:** Historical prototype plans for earlier Android connectivity work reside in [`docs/07_Archive/plans/android/`](../../07_Archive/plans/android/). Future connected/offline work will receive fresh implementation plans when Track M-Android-Connected / Offline begins.

---

## 2. Catalog of Post-V1 Planning Documents

| Document Path | Title / Domain | Roadmap Milestone | Scope Description |
| :--- | :--- | :--- | :--- |
| [`PROACTIVE_COMPANION_ROUTINES.md`](./PROACTIVE_COMPANION_ROUTINES.md) | Proactive Companion Routines | Track M-Proactive | Configurable recurring routines (hydration, sleep, check-ins) and companion-initiated messaging. |

---

## 3. Contributor & Agent Guidance

- **During V1 Work:** Do not read or load files from `docs/02_Planning/post-v1/` into context unless specifically tasked with future milestone roadmap refinement.
- **When Post-V1 Milestone Begins:** Promote the relevant document into an active feature plan under `docs/02_Planning/` and reconcile it against `SYSTEM_BASELINE.md` and domain architecture.
