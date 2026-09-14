# Phase 8 Planning Hub — PC Frontend Architecture, Runtime Config, Multimodal & Polish

This directory contains the authoritative implementation planning and navigation for **Phase 8**, the active milestone dedicated to solidifying the local PC desktop runtime and web application before multi-device synchronization.

## Phase 8 Execution Sequence

| Sub-Phase | Focus Area | Branch | Status |
|-----------|------------|--------|--------|
| **8A** | Frontend Architecture & UX Harmonization | `feature/phase8-ui-foundation` | **Completed / Verified** (Mock removal, decomposition, truthfulness sweep, deprecation annotations) |
| **8P** | Runtime Configuration & Persistent Asset Foundation | `feature/phase8-runtime-config` | **Next Sprint** (Terminology reconciliation, `COMPANION_DATA_ROOT`, bootstrap locator, Model Registry Schema v3) |
| **8B** | Multimodal Image Attachment Foundation | `feature/multimodal-image-attachments` | **Planned** (Attachment ORM, validation, secure preview endpoints, vision gate) |
| **8C** | Integration, Accessibility & Polish | `feature/phase8-ui-integration-polish` | **Planned** (Dead mock deletion, bundle code-splitting, a11y, regression verification) |

---

## Authoritative Documentation & References

### Implementation Plan
- [`plan-phase8-pc-frontend-architecture-ux.md`](./plan-phase8-pc-frontend-architecture-ux.md) — The single authoritative implementation plan covering all Phase 8 sub-phases (8A, 8P, 8B, 8C), test targets, and scope guards.

### Canonical Architecture References
- [`docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`](../../04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md) — Master implementation plan and system-wide milestones.
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../../04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Durable architecture for `COMPANION_DATA_ROOT`, bootstrap resolution (OD1, OD2, OD3), and Model Registry schema.
- [`docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../../04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md) — Local LLM runtime architecture, hardware offloading profiles, and port allocations.

### Active Sprint Tracking
- [`docs/01_Tracking/task.md`](../../01_Tracking/task.md) — Active execution state, checklists, and blockers.
