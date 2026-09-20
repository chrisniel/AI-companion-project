# Documentation Archive (`docs/07_Archive/`)

> **Directory Role:** Preserved historical evidence, superseded plans, forensic audits, and point-in-time review records.  
> **Status:** Non-Authoritative / Historical Archive  
> **AI Agent Default Rule:** **Strictly ignored by default.** Do not scan, load, or cite files in this directory during normal development, implementation, or testing tasks unless explicitly instructed by the user to perform an architectural retrospective or provenance audit.

---

## 1. Archive Authority & Lifecycle Rules

- **Historical Only:** All materials preserved in this directory are point-in-time historical records and carry zero normative architectural authority.
- **Implementation Reality:** Active source code (`backend/`, `frontend/web/`, `android/`) and verified test suites determine current system implementation reality.
- **Canonical Architecture:** Durable, authoritative technical specifications reside exclusively in [`docs/04_Architecture/`](../04_Architecture/).
- **Product Sequencing:** Authoritative release boundaries and milestone ordering reside exclusively in [`docs/02_Planning/ROADMAP.md`](../02_Planning/ROADMAP.md).
- **When to Consult:** Only reference these archives when investigating historical provenance, forensic audit details, regression causes, or past implementation rationales.

---

## 2. Archive Categories

| Subdirectory | Category Role | Representative Contents |
| :--- | :--- | :--- |
| [`plans/`](./plans/) | Completed Historical Plans | Implemented and verified feature plans from earlier phases (cross-cutting root plans, `backend/`, and `android/` UI prototype plans). |
| [`reference/`](./reference/) | Superseded Reference Specs | Decomposed monolithic reference documents (e.g., `AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`). |
| [`reviews/`](./reviews/) | Point-in-Time Reviews | Historical reviews and point-in-time hardening audits (e.g., `BACKEND_SECURITY_REVIEW_AND_ROADMAP.md`). |
| [`drafts/`](./drafts/) | Reconciled Early Drafts | Early feature inventories, runtime drafts, and exploratory notes reconciled in Pass R0–R4. |
| [`audits/`](./audits/) | Forensic Audits | Comprehensive reconciliation audits and diagnostic inventories (e.g., `REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md`). |
