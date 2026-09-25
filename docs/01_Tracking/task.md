# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Current State: Phase 8B — Multimodal Image Attachment Foundation = **IN PROGRESS**
- Current Branch: `feature/multimodal-image-attachments`
- Current Slice: **8B.6 — Web Attachment Composer** (`COMPLETE / VERIFIED`)
- Next Slice: **8B.7 — History Image Rendering** (`NEXT / UNBLOCKED`)
- Commit Owner: Chris manually reviews, commits, merges, and branches all changes.

---

## Current Execution State

| Milestone / Slice | Status | Primary Focus |
| :--- | :--- | :--- |
| **8B.0: Readiness Reconciliation** | `COMPLETE / VERIFIED` | Source & plan verification, four questions resolved, slice map locked. |
| **8B.1: Persistence Foundation** | `COMPLETE / VERIFIED` | Migration 006, Attachment ORM, db/base.py metadata registration, parity tests. |
| **8B.2: Contracts & Validation** | `COMPLETE / VERIFIED` | Attachment schemas, multimodal types, Pillow validator, validation tests, OpenAPI contract sync. |
| **8B.3: Secure Attachment API** | `COMPLETE / VERIFIED` | Route-specific upload limit, upload endpoint, exclusive temp creation, collision no-clobber, preview, soft-delete, BOLA. |
| **8B.4: Message Binding & Lifecycle** | `COMPLETE / VERIFIED` | Pre-stream turn preparation transaction, atomic conditional update claim, cascade soft-delete on conversation delete, truthful SQLite concurrency verification. |
| **8B.5: Vision Provider Integration** | `COMPLETE / VERIFIED` | Media resolver, available_capabilities vision gate, wire translation, fail-closed lifecycle. |
| **8B.6: Web Attachment Composer** | `COMPLETE / VERIFIED` | Exact backend schema, canonical limits, preview rollback, explicit removal semantics, transition lock, effect loop fix, unmount URL revocation. |
| **8B.7: History Image Rendering** | `NEXT / UNBLOCKED` | History attachments, Blob fetch, reload persistence, URL cleanup. |
| **8B.8: Full Integration & Closure** | `PLANNED` | Full test suites, typecheck, build, openapi drift check, report. |
| **Phase 8C: Integration & Polish** | `PLANNED / BLOCKED` | Blocked by completion and merge of Phase 8B. |

---

## Invariants & Boundaries for Upcoming Work

1. **User-Owned Git Operations:** AI agents must never execute git commit, push, merge, checkout, or branch creation.
2. **Data Safety:** Never execute tests or mutations against `%LOCALAPPDATA%\AI Companion\Data`. Use isolated ephemeral roots.
3. **Surgical Implementation:** Implement one approved slice at a time; do not jump ahead to subsequent slices.

---

## Authoritative Reference Pointers

- **Documentation Map:** [`docs/06_Guides/DOCUMENTATION_MAP.md`](../06_Guides/DOCUMENTATION_MAP.md)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md)
- **Canonical Product Roadmap:** [`docs/02_Planning/ROADMAP.md`](../02_Planning/ROADMAP.md)
- **Active Feature Plan:** [`docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md`](../02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md)
- **Testing Standards & CI Guide:** [`docs/06_Guides/TESTING_AND_CI.md`](../06_Guides/TESTING_AND_CI.md)
