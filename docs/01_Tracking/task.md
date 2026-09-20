# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Current Sprint: Repository Documentation Reconciliation (Passes R0–R8)
- Current Branch: `chore/repository-documentation-reconciliation`
- Immediate Blocker: **Phase 8B (Multimodal Image Attachments) remains strictly BLOCKED** until reconciliation passes R0–R8 are complete.
- Target Scope: Resolve authority model, establish canonical roadmap, decompose master plan, slim active task tracker, create developer/testing guides, and archive historical materials without code or CI changes.
- Execution Mode: Read-only by default; inspect and report; zero source code, runtime, CI, or git mutation.
- Commit Owner: Chris manually reviews, commits, and pushes all changes.

---

## Current Execution State

| Milestone / Pass | Status | Primary Focus |
| :--- | :--- | :--- |
| **Pass R0: Forensic Audit** | `COMPLETE / VERIFIED` | Repository inventory & baseline diff audit (`3a5a8db`). |
| **Pass R1: Architectural Decisions** | `COMPLETE / VERIFIED` | Locked ecosystem architectural decisions D1–D9. |
| **Pass R2 / R2.1: Canonical Entry** | `COMPLETE / VERIFIED` | Authority model, documentation map, and system baseline (`6c5bf7a`, `597b77d`). |
| **Pass R3 / R3.1 / R3.2: Domain Architecture** | `COMPLETE / VERIFIED` | Domain specifications created, baseline slimmed, precision reconciled (`ecca717`, `361e6e9`, `3abd91a`). |
| **Pass R4 / R4.1 / R4.2: Planning & Guides** | `COMPLETE / VERIFIED` | Canonical ROADMAP, master plan decomposition, dev/test guides, and active-state truthfulness sweep (`7eabc5f`). |
| **Pass R5 / R5.1 / R5.2: Archival & Android Truth** | `COMPLETE / VERIFIED` | Archived historical plans, walkthrough indexing, Android connectivity & network source truth reconciled (`7832e9d`). |
| **Pass R6 / R6A / R6B: Data Audit & Cleanup** | `COMPLETE / VERIFIED` | Read-only storage audit, logical backups created, local legacy databases cleaned. |
| **Pass R7: Active Docs & Routing Finalization** | `COMPLETE / VERIFIED` | Authority routing, Git governance, component quickstarts, precision reconciled. |
| **Pass R8: Final Baseline Verification & Signoff** | `NEXT` | Full test execution (88/132/110), OpenAPI verification, Phase 8B unblocking. |
| **Phase 8B: Multimodal Vision** | `BLOCKED` | Next engineering milestone upon Pass R8 sign-off. |

---

## Active Checklist — Pass R7 (Active Documentation, Cross-Reference & Routing Finalization)

- [x] Deliverable 1: Align `AGENTS.md` and `CONTRIBUTING.md` with user-owned Git operations and canonical routing.
- [x] Deliverable 2: Reconcile `DOCUMENTATION_MAP.md` routing, 00_Drafts role, StarterKit rules, and component quickstarts.
- [x] Deliverable 3: Correct root `README.md` transport (`HTTP / SSE`) and refine Local AI Runtime ownership.
- [x] Deliverable 4: Reconcile `android/README.md` (retire Local AI Core, prototype vs post-V1 production truth).
- [x] Deliverable 5: Reconcile `backend/README.md` (Python 3.11, implemented controls, lifespan schema prep).
- [x] Deliverable 6: Rewrite `frontend/web/README.md` (purge AI Studio boilerplate, provide clean React Web quickstart).
- [x] Deliverable 7: Modernize `PROJECT_INPUTS_CHECKLIST.md` and prune resolved decisions.
- [x] Deliverable 8: Precision sweep on `SYSTEM_BASELINE.md` (D2), `SECURITY_AND_TRUST_ARCHITECTURE.md`, `AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md` (D6 inbox flow), and `VOICE_AND_AUDIO_ARCHITECTURE.md`.
- [x] Deliverable 9: Global cross-reference and repository-relative link validation (0 broken links in active docs).

---

## Execution Invariants & Non-Negotiable Boundaries

1. **Phase 8B strictly blocked:** No image attachment code, ORM migrations, or API changes until R0–R8 sign-off.
2. **Protected files:** `docs/00_Drafts/09-16-2026-roadmap.md` and `docs/ProjectWorkflowStarterKit/` remain strictly protected and untouched.
3. **Git governance:** The AI never executes git add, commit, push, or branch mutations. Ordinary filesystem moves performed per prompt mandate; Chris performs all Git operations manually.

---

## Authoritative Reference Pointers

- **Canonical Product Roadmap:** [`docs/02_Planning/ROADMAP.md`](../02_Planning/ROADMAP.md)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md)
- **Active Feature Plan:** [`docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md`](../02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md) (owns upcoming Phase 8B / 8C checklists)
- **Developer Onboarding Guide:** [`docs/06_Guides/DEVELOPMENT_SETUP.md`](../06_Guides/DEVELOPMENT_SETUP.md)
- **Testing & CI Standards:** [`docs/06_Guides/TESTING_AND_CI.md`](../06_Guides/TESTING_AND_CI.md)
