# Phase 8 Planning Hub — PC Frontend Architecture, Runtime Config, Multimodal & Polish

This directory contains the authoritative implementation planning and navigation for **Phase 8**, the active milestone dedicated to solidifying the local PC desktop runtime and web application before multi-device synchronization.

## Phase 8 Execution Sequence

| Sub-Phase | Focus Area | Branch / Gate | Status |
|---|---|---|---|
| **8A** | Frontend Architecture & UX Harmonization | `feature/phase8-ui-foundation` | **COMPLETE / VERIFIED** (Mock removal, decomposition, truthfulness sweep, deprecation annotations) |
| **8P** | Runtime Configuration & Persistent Asset Foundation | `feature/phase8-runtime-config` | **COMPLETE / VERIFIED** (Terminology reconciliation, `COMPANION_DATA_ROOT`, bootstrap locator, Model Registry Schema v3, atomic migrations) |
| **R0–R8** | Repository Documentation Reconciliation | `chore/repository-documentation-reconciliation` | **COMPLETE / VERIFIED** (Full audit, baseline lock, documentation routing, verified test suites) |
| **8B** | Multimodal Image Attachment Foundation | `feature/multimodal-image-attachments` | **NEXT / UNBLOCKED / NOT STARTED** (Attachment ORM, validation, secure preview endpoints, vision gate; starts upon branch cut) |
| **8C** | Integration, Accessibility & Polish | `feature/phase8-ui-integration-polish` | **PLANNED AFTER 8B** (Dead mock deletion, bundle code-splitting, a11y, regression verification) |

---

## Authoritative Documentation & References

### Implementation Plan
- [`plan-phase8-pc-frontend-architecture-ux.md`](./plan-phase8-pc-frontend-architecture-ux.md) — The single authoritative feature implementation plan covering all Phase 8 sub-phases (8A, 8P, 8B, 8C), test targets, and scope guards.

### Canonical Roadmap & Architecture References
- [`docs/02_Planning/ROADMAP.md`](../ROADMAP.md) — Canonical product and milestone delivery roadmap.
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) — Canonical system baseline, release boundary, and locked decisions D1–D9.
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../../04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Durable architecture for `COMPANION_DATA_ROOT`, bootstrap resolution, and Model Registry schema.
- [`docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../../04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md) — Local LLM runtime architecture, hardware offloading profiles, and port allocations.

### Active Sprint Tracking
- [`docs/01_Tracking/task.md`](../../01_Tracking/task.md) — Active execution state, checklists, and immediate blockers.
