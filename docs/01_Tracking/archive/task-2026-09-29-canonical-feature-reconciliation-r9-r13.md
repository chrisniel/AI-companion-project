# Task Archive: Canonical Feature Reconciliation (Passes R9–R13.2)

- **Archive Date**: 2026-09-29
- **Branch**: `docs/canonical-feature-reconciliation`
- **Base Lineage**: `4b2f5fe3aa2a302b825408073d1b135bf2ff92e1` (merged PR #13 / CI Run #23 verified baseline)
- **Final Independently Verified Branch Head**: `199606baac5977f5dab38b8c717b5db549c48e29`
- **Status**: COMPLETE / VERIFIED

**Note:** The final PR and merge into the `develop` branch is still pending and remains Chris-owned. This reconciliation branch is not yet merged.

## Completed Scope Summary

### R9 — Implemented Reality Refresh
**Status**: COMPLETE / VERIFIED

### R10 — Product Boundary & Decision Relock
**Status**: COMPLETE / VERIFIED
- D1–D11 locked/relocked.
- `FEATURE_PROMOTION_MAP` established.

### R11 — Domain Architecture Alignment
**Status**: COMPLETE / VERIFIED
- 18 focused canonical domain specifications established.
- Canonical authority transferred from legacy monoliths.

### R12 — Roadmap / Planning / CI Alignment
**Status**: COMPLETE / VERIFIED
- **R12.1 Release Boundary & Roadmap Taxonomy**: COMPLETE / VERIFIED
- **R12.2 Delivery Sequencing & Planning Alignment**: COMPLETE / VERIFIED
- **R12.3 Golden PC V1 Acceptance Journey**: COMPLETE / VERIFIED
- **R12.4 CI Governance Target Alignment**: COMPLETE / VERIFIED
- **R12.5 Final Consistency Review & R12 Closure**: COMPLETE / VERIFIED

### R13 — Documentation Governance, Routing & Closure
**Status**: COMPLETE / VERIFIED

#### R13.1 — Physical Architecture Cleanup & ADR Codification
**Status**: COMPLETE / VERIFIED
- Six legacy architecture monoliths moved to `docs/07_Archive/reference/architecture-legacy/`.
- Active architecture root contains only focused architecture, `decisions/`, `README.md`, and `SYSTEM_BASELINE.md`.
- `ADR-0002` through `ADR-0012` codify D1–D11.
- `decisions/README.md` indexes `ADR-0001` through `ADR-0012`.
- Active routing no longer treats legacy monoliths as normative.
- Legacy monoliths retained only as subordinate historical / technical / implementation references.
- Markdown/link/encoding/table integrity independently reviewed.
- D6 controlled import remains: `inbox → preflight → staging → atomic install → library → registry`.

#### R13.2 — Repository Boundary & Git/LFS Policy Audit
**Status**: COMPLETE / VERIFIED
- GitHub remains canonical Git source/history repository.
- Approved LFS object endpoint remains private Hugging Face dataset.
- `.gitignore` now ignores all current LFS-model formats by default.
- `.gitattributes` active LFS format set remains: `gguf`, `ggml`, `safetensors`, `onnx`, `pt`, `pth`, `ckpt`.
- `*.bin` remains ignored but NOT LFS tracked.
- No tracked model weights/LFS pointers existed at R13.2 audit.
- Only `models/registry.template.json` was tracked under `models/`.
- `.lfsconfig` contained no credential.
- `.aiignore` and `.cursorignore` remain aligned.
- `.clineignore` remains intentionally absent.
- `ADR-0001` evidence synchronized without changing accepted topology.

## Key Verified Commit Endpoints

- **R9 final factual refresh**: `e3324e7dc6476ac7574b6042f8d14d0c306e8ec4`
- **R10 final relock**: `2521bd8342fc2801e69d2ccb2dd23e76d6141fac`
- **R11 final domain-architecture closure**: `df2d2d8dca5193993adb43f5334478b0eb5f6b80`
- **R12 final Golden/CI review closure**: `4a451eebb7a1b0e1c8637bb0ba605f0c6448b7ae`
- **R13 governance/routing final**: `4f3d602306dd9d1a850bb98dbe2317b689de53a4`
- **R13.1 physical cleanup / ADR codification began**: `2b32889a65cfc575c29c7c9e550f97422651deee`
- **R13.1 final system-baseline integrity**: `987543501882d2f415584ca3e4370801224ed4ed`
- **R13.2 final repository-boundary policy**: `199606baac5977f5dab38b8c717b5db549c48e29`

## Known Non-Blocking Follow-up
Four source/test comments/docstrings still historically reference `LLAMA_CPP_RUNTIME_ARCHITECTURE.md`:
- `backend/app/core/config.py`
- `backend/app/services/llm/llama_cpp.py`
- `backend/app/services/llm/runtime_state.py`
- `backend/tests/test_llm_router_lifecycle.py`

They are non-normative implementation comments only.
Canonical runtime architecture is: `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`
Their optional comment-only cleanup may occur during future maintenance or when those files are next touched. (NON-BLOCKING MAINTENANCE).

## Handoff State

- **Phase 8B.0–8B.6**: COMPLETE / VERIFIED
- **Phase 8B.7 — Persistent Message Attachment Rendering**: NEXT / UNBLOCKED
- **Phase 8B.8**: PLANNED
- **Phase 8C**: PLANNED / BLOCKED until Phase 8B completes

The documentation reconciliation no longer blocks Phase 8B.7. However, user-owned PR/merge of `docs/canonical-feature-reconciliation` must complete before normal implementation resumes from the integrated develop baseline.
