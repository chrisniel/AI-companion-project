# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Current State: Canonical Feature Reconciliation — Pass R12 Roadmap / Planning / CI Alignment = **IN PROGRESS** (Sub-slice R12.1 = **COMPLETE / VERIFIED**; Sub-slice R12.2 = **COMPLETE / VERIFIED**; Sub-slice R12.3 = **NEXT / UNBLOCKED**)
  - Sub-slices:
    - `R12.1 — Release Boundary & Roadmap Taxonomy` (`COMPLETE / VERIFIED`)
    - `R12.2 — Delivery Sequencing & Planning Alignment` (`COMPLETE / VERIFIED`)
    - `R12.3 — Golden PC V1 Acceptance Journey` (`NEXT / UNBLOCKED`)
    - `R12.4 — CI Governance Target Alignment` (`PLANNED`)
    - `R12.5 — Final Consistency Review & R12 Closure` (`PLANNED`)
- Current Branch: `docs/canonical-feature-reconciliation`
- Base Lineage: `4b2f5fe3aa2a302b825408073d1b135bf2ff92e1` (merged PR #13 / CI Run #23 verified)
- Phase 8 Delivery State:
  - Slices 8B.0–8B.6: `COMPLETE / VERIFIED`
  - Slice 8B.7 (Persistent Message Attachment Rendering): `NEXT / UNBLOCKED` (paused for R9–R13 reconciliation)
  - Slice 8B.8 (Full Integration & Phase Closure): `PLANNED`
  - Phase 8C (Integration & Polish): `PLANNED / BLOCKED` until Phase 8B completes
- Commit Owner: Chris manually reviews, commits, merges, and branches all changes.

---

## Reconciliation Sequence (R9–R13)

| Pass | Focus Area | Status | Primary Scope |
| :--- | :--- | :--- | :--- |
| **R9** | **Implemented Reality Refresh** | `COMPLETE / VERIFIED` | Refreshed factual baseline, migration 006, 8B.0–8B.6 foundation, CI #23 test counts across canonical docs. |
| **R10** | **Product Boundary & Decision Relock** | `COMPLETE / VERIFIED` | Relocked D1–D11; established PC V1 and Android V1 boundaries; created `FEATURE_PROMOTION_MAP.md`. |
| **R11** | **Domain Architecture Alignment** | `COMPLETE / VERIFIED` | Staged domain architecture extraction and authority transfer (R11.0–R11.4 COMPLETE / VERIFIED). |
| **R12** | **Roadmap / Planning / CI Alignment** | `IN PROGRESS` | Roadmap and planning alignment, including target CI governance and Golden Journey alignment (R12.1–R12.2 COMPLETE / VERIFIED; R12.3 NEXT / UNBLOCKED; R12.4–R12.5 PLANNED). |
| **R13** | **Documentation Map, Cross-links & Closure** | `PLANNED` | Documentation map/routing/cross-links, task closure, consistency sweep, and reconciliation closure. |

---

## Invariants & Boundaries for Reconciliation

1. **User-Owned Git Operations:** AI agents must never execute git commit, push, merge, checkout, or branch creation.
2. **Documentation-Only Scope:** Do not modify application source code, tests, contracts, or `.github/workflows/ci.yml`.
3. **Factual Implemented Reality:** Document only verified repository reality; distinguish repository migration head (006) from individual workstation state.
4. **Staged Domain Strategy:** Pass R10 established platform release vocabulary (PC V1 vs. Android V1), relocked decisions D1–D11, and created the `FEATURE_PROMOTION_MAP.md` control manifest. Pass R11 executed sub-slice by sub-slice (R11.0–R11.4 COMPLETE / VERIFIED), transferring canonical domain authority to 18 focused domain specifications. Pass R12 Roadmap / Planning / CI Alignment is IN PROGRESS (R12.1–R12.2 COMPLETE / VERIFIED; R12.3 NEXT / UNBLOCKED; R12.4–R12.5 PLANNED); documentation routing and task closure occur in Pass R13 (PLANNED).

---

## Authoritative Reference Pointers

- **Architecture Navigation & Authoring Guide:** [`docs/04_Architecture/README.md`](../04_Architecture/README.md)
- **Core Experience Domains (R11 Focused Canonical Domain Specifications):**
  - [`tasks-reminders-alarms-and-routines.md`](../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md)
  - [`characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md)
  - [`memory-and-personalization.md`](../04_Architecture/01_Domains/memory-and-personalization.md)
  - [`voice-and-audio.md`](../04_Architecture/01_Domains/voice-and-audio.md)
- **Integrations, Host Runtime & Client Domains (R11 Focused Canonical Domain Specifications):**
  - [`assistant-and-conversations.md`](../04_Architecture/01_Domains/assistant-and-conversations.md)
  - [`multimodal-and-media.md`](../04_Architecture/01_Domains/multimodal-and-media.md)
  - [`android-companion.md`](../04_Architecture/01_Domains/android-companion.md)
  - [`web-current-information.md`](../04_Architecture/03_Integrations/web-current-information.md)
  - [`windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md)
- **Security, Data & Infrastructure Domains (R11 Focused Canonical Domain Specifications):**
  - [`profiles-and-devices.md`](../04_Architecture/02_Data_and_Security/profiles-and-devices.md)
  - [`authentication-and-secrets.md`](../04_Architecture/02_Data_and_Security/authentication-and-secrets.md)
  - [`tool-permissions-and-actions.md`](../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md)
  - [`privacy-retention-and-audit.md`](../04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md)
  - [`health-and-wearables.md`](../04_Architecture/03_Integrations/health-and-wearables.md)
  - [`runtime-and-models.md`](../04_Architecture/04_Infrastructure/runtime-and-models.md)
  - [`storage-and-assets.md`](../04_Architecture/04_Infrastructure/storage-and-assets.md)
  - [`backup-recovery-and-diagnostics.md`](../04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md)
  - [`performance-and-capacity.md`](../04_Architecture/04_Infrastructure/performance-and-capacity.md)
- **Design Hub & Architectural Boundaries:** [`docs/05_Design/README.md`](../05_Design/README.md)
- **Feature Promotion Map:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../02_Planning/FEATURE_PROMOTION_MAP.md)
- **Documentation Map:** [`docs/06_Guides/DOCUMENTATION_MAP.md`](../06_Guides/DOCUMENTATION_MAP.md)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md)
- **Canonical Product Roadmap:** [`docs/02_Planning/ROADMAP.md`](../02_Planning/ROADMAP.md)
- **Testing Standards & CI Guide:** [`docs/06_Guides/TESTING_AND_CI.md`](../06_Guides/TESTING_AND_CI.md)
- **Active Feature Plan:** [`docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md`](../02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md)
