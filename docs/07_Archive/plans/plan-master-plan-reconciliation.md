# Implementation Plan: Master Plan Reconciliation and Documentation Migration

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Complete
- Scope Mode: Documentation — reconcile existing plans and migrate only approved documents; no application implementation
- Target Files: Existing master plan, roadmap/runtime drafts, web static review, README documentation sections, and numbered documentation destinations

---

## 1. Request Understanding & Goals

- Primary Objective: Produce one accurate canonical master plan before Google AI Studio or another implementation tool creates additional application code.
- Concrete Deliverables:
  1. A canonical architecture document that distinguishes implemented, externally unverified, planned, and deferred work.
  2. A prioritized implementation roadmap and web-productionization plan derived from verified repository evidence.
  3. Updated README references and a lossless migration into the numbered documentation hierarchy.
- Explicit Out-of-Scope: Application code, dependencies, backend/Android scaffolding, model downloads, Git/LFS changes, external services, commits, and pushes.

## 2. Current Findings & Technical Root Cause

| Observation / Evidence | Verified Interpretation |
| --- | --- |
| Only `frontend/web/` contains tracked application source | The React control-center prototype is the only implementation verifiable in this repository. |
| README says Android is at Batch 10 while `android/` is empty and has no Git history | User confirmed the Android UI/UX prototype is externally in progress at Batch 12 in Google AI Studio and is not yet available in this repository. |
| The canonical plan and draft roadmap overlap but differ in status and detail | There is no single fully current planning source. |
| Roadmap v2 ends with an unorganized Batch 12.1 section | Multilingual work needs integration into the correct architecture, status, and roadmap sections. |
| Runtime documentation names a stale filesystem path and port 5173, while the web script uses port 3000 | Setup/runtime instructions drifted from the repository. |
| Static review says a lockfile is missing, but `package-lock.json` exists | The review contains both current findings and completed/outdated findings. |
| Architecture said weights should remain separate while active LFS rules route model formats to Hugging Face | User approved GitHub as the source/pointer repository with private Hugging Face storage for LFS objects; the decision is recorded as ADR-0001. |

## 3. Completed File Changes & In-Place Logic

### MODIFIED and MOVED `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`

- Primary Responsibility: Canonical product and system architecture.
- Completed Change: Merged verified, non-duplicative detail; added explicit status vocabulary, current-repository baseline, accepted storage decision, current tracks, and Google AI Studio boundaries.
- Invariants to Preserve: Local-first design, provider independence, character independence, backend authority, privacy boundaries, and V1 goals.

### PRESERVED `docs/00_Drafts/MASTER_IMPLEMENTATION_ROADMAP_v2.md`

- Primary Responsibility: Detailed roadmap source material.
- Completed Change: Integrated relevant Batch 12.1 and sequencing information into the canonical plan while retaining this outdated roadmap as non-canonical source material.

### PRESERVED `docs/00_Drafts/LOCAL_AI_RUNTIME_AND_WORKFLOW.md`

- Primary Responsibility: Runtime and development workflow explanation.
- Completed Change: Retained the original as non-canonical reference. Correct runtime facts are now owned by the canonical master plan and README instead of silently rewriting the historical draft.

### PRESERVED `docs/00_Drafts/WEB_FRONTEND_STATIC_REVIEW.md`

- Primary Responsibility: Evidence and backlog for web productionization.
- Completed Change: Preserved the original review and created the current `docs/02_Planning/plan-web-frontend-productionization.md` with resolved items and reverified priorities.

### MODIFIED `README.md`

- Primary Responsibility: Concise public repository overview and verified setup entry point.
- Completed Change: Corrected Android Batch 12 status, canonical-document paths, documentation layout, placeholder-directory wording, and LFS branch notation while preserving unrelated user edits.
- Invariants to Preserve: All unrelated uncommitted user edits and intentional LFS explanation unless the user changes that policy.

## 4. Step-by-Step Pseudocode & Implementation Sequence

1. Record the user-confirmed Android source/progress and accepted GitHub-pointer/Hugging Face-object storage policy.
2. Build a section-level mapping from the canonical plan, roadmap v2, runtime document, static review, README, and code evidence.
3. Label each claim Implemented, Verified, Planned, Deferred, or Unverified; reject unsupported prototype telemetry as real state.
4. Update the canonical master plan in place and present the diff for review before moving documents.
5. Derive focused implementation plans from remaining actionable material instead of keeping one monolithic execution checklist.
6. After approval, move documents to their numbered destinations and update every repository reference atomically.
7. Verify that no unique content was lost, all paths resolve, the README diff is preserved, and only documentation files changed.

## 5. Acceptance Criteria & Verification Plan

### Automated Repository Checks

- [x] `git diff --check` reports no whitespace errors.
- [x] Repository searches find no references to removed or nonexistent canonical document paths in active documentation.
- [x] Final scope inspection confirms no application-source or starter-kit changes; the user-owned `.gitignore` edit is preserved.

### Manual / User-Owned Checks

- [x] User confirms Android UI/UX Batch 12 is in progress in Google AI Studio and has not been exported to this repository.
- [x] User confirms GitHub remains the source/pointer repository and Hugging Face stores LFS objects.
- [x] User approves the reconciled master plan before application implementation continues.

## 6. Risks, Recovery & Rollback

- Risk: A migration could accidentally promote draft assumptions or overwrite the user's README work.
- Mitigation / Rollback: Keep source documents until the merged result is approved, make targeted in-place edits, review diffs before moves, and perform no Git history mutation.
- Risk: Google AI Studio may implement from stale or contradictory context.
- Mitigation / Rollback: Provide the canonical master plan plus the active phase and explicitly state that planned features are not implemented.
