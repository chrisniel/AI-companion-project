# Archived Branch Execution Tracker — Milestone M3 Memory Control Center UI Batch C3

- **Branch:** `feature/m3-memory-ui-c3`
- **Base Integration Branch:** `develop` (`f7de198`)
- **Delivery Level:** Level B — Planned Autonomous (Core Feature Implementation under Approved Architecture D7/ADR-0018)
- **Work Breakdown Structure IDs:** `PC-CLIENT-009`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-memory-ui-c3.md`](../../02_Planning/01_Plans/plan-m3-memory-ui-c3.md)
- **Status:** **PHASE 3 COMPLETE / READY FOR COMBINED INDEPENDENT REVIEW & MERGE (PHASE 4)**

---

## Milestone M3 Memory Sequence
- **Batch M3-C1 (CLOSED & MERGED):** Memory Foundation, Schema Migration 010, Scoping, Bound Expiry, Core-Fact Context Assembly & Dart Client Parity.
- **Batch M3-C2 (CLOSED & MERGED):** Selective Automatic Extraction & Deterministic Slot Reconciliation (`PC-MEM-002`; NEW, MERGE, UPDATE, CONFLICT, DUPLICATE; zero-latency background execution).
- **Batch M3-C3 (Delivered on `feature/m3-memory-ui-c3`):** Desktop Memory Control Center UI (`PC-CLIENT-009`), Migration 011 Per-Profile Extraction Toggle, Flip Extraction to Default ON, Conflict Resolution Banner, and Conversational Conflict Hinting.

---

## Phase 1: Planning & Design Authorization (COMPLETED)

- [x] Verify clean `develop` baseline at `f7de198`.
- [x] Create and switch to dedicated delivery branch `feature/m3-memory-ui-c3`.
- [x] Complete pre-planning examination and architectural consensus with Human Owner:
  - **Decision 1 (Per-Profile Extraction Toggle):** Stored in `profiles.memory_extraction_enabled` via Alembic Migration 011.
  - **Decision 2 (Conflict Presentation in UI):** Prominent Conflict Action Banner at the top of the Desktop Memory Control Center + a "Conflicts" filter chip.
  - **Decision 3 (Conversational Conflict Clarification):** Inject `<memory_conflicts>` into the orchestrator prompt context with polite, companion-toned clarification instructions.
- [x] Author Phase 1 Implementation Plan: [`docs/02_Planning/01_Plans/plan-m3-memory-ui-c3.md`](../../02_Planning/01_Plans/plan-m3-memory-ui-c3.md).
- [x] Author Active Branch Tracker: `docs/01_Tracking/active/task-feature-m3-memory-ui-c3.md`.
- [x] Submit published plan for Human Owner and Independent Reviewer plan evaluation.
- [x] Human Owner plan approval gate granted.

---

## Phase 2: Autonomous Implementation & Verification (COMPLETED)

- [x] **Step 1 — Alembic Migration 011 & Profile Model (Backend TDD):**
  - [x] Create `backend/tests/test_migration_011.py` (3/3 PASSED).
  - [x] Implement `backend/migrations/versions/011_profile_memory_extraction_toggle.py`.
  - [x] Update `backend/app/models/profile.py` and `backend/app/api/v1/endpoints/profiles.py`.
  - [x] Verify migration upgrade/downgrade and profile update tests (`test_profile_memory_toggle.py`, 2/2 PASSED).
- [x] **Step 2 — Memory API Filters & Approval Updates (Backend TDD):**
  - [x] Create `backend/tests/test_memories_api_filters.py` (5/5 PASSED).
  - [x] Add `q`, `user_verified`, and `source_type` query filters to `GET /api/v1/memories`.
  - [x] Add `user_verified` and `source_type` to `MemoryUpdate` and update `PATCH /api/v1/memories/{memory_id}`.
  - [x] Verify memory API tests.
- [x] **Step 3 — Default ON Toggle & Conversational Conflict Hinting (Backend TDD):**
  - [x] Set `MEMORY_EXTRACTION_ENABLED = True` in `backend/app/core/config.py`.
  - [x] Wire per-profile check and `<memory_conflicts>` context in `backend/app/services/assistant/orchestrator.py`.
  - [x] Verify extraction pipeline and full backend regression suite (767/767 passed).
- [x] **Step 4 — Dart OpenAPI Parity Updates (Dart TDD):**
  - [x] Update `memory_dto.dart`, `profile_dto.dart`, and `companion_client.dart`.
  - [x] Verify 100% Dart contract parity with `scripts/check_dart_openapi_parity.py` (32/32 schemas, 42/26 routes PASSED).
  - [x] Verify `companion_api` package tests (`dart test`, 95/95 PASSED).
- [x] **Step 5 — Flutter Desktop Memory Control Center UI (Flutter TDD):**
  - [x] Remove `'M3'` planned badge from `DesktopNavDestination.memory`.
  - [x] Implement `DesktopMemoryController` and unit tests in `frontend/flutter/apps/desktop/test/desktop_memory_controller_test.dart` (9/9 PASSED).
  - [x] Implement `MemoryConflictBanner`, `MemoryItemCard`, `MemoryFilterBar`, and `MemoryEditDialog`.
  - [x] Implement `MemoryScreen` replacing placeholder.
  - [x] Wire into `DesktopShell` and test with `memory_screen_test.dart` (8/8 PASSED) and `desktop_shell_test.dart` (4/4 PASSED).
  - [x] Verify clean `flutter analyze` ("No issues found!").
- [x] **Step 6 — Real-World Experience Refinements (Local Testing Follow-Up):**
  - [x] Step 6.1: Tighten extraction prompt against meta-conversational style analysis & ignore question turns ending in `?`.
  - [x] Step 6.2: Refine token overlap denominator in reconciler to `min(cand, mem)` and add recovery/update signals (`healed`, `no longer`, etc.).
  - [x] Step 6.3: Auto-refresh `_memoryController` upon navigating to `DesktopNavDestination.memory` in `DesktopShell`.
- [x] **Step 7 — Settings Navigation Sync & Anti-Repetition Sampling (Follow-Up):**
  - [x] Step 7.1: Add `repeat_penalty: 1.15`, `min_p: 0.05`, and explicit stop sequences in `backend/app/services/llm/llama_cpp.py`.
  - [x] Step 7.2: Auto-refresh model catalog/status on navigating to `DesktopNavDestination.settings` and await credential store safely in `settings_screen.dart`.
  - [x] Step 7.3: Partition stream circuit breaker, sentence-chunked streaming, and UI presets into `docs/02_Planning/00_Master/BACKLOG.md`.


---

## Phase 3: Documentation, Closure & Draft PR (COMPLETED)

- [x] Update canonical domain spec `docs/04_Architecture/01_Domains/memory-and-personalization.md`.
- [x] Record entry in `CHANGELOG.md`.
- [x] Author delivery walkthrough in `docs/03_Walkthroughs/walkthrough-m3-batch-c3-memory-ui.md`.
- [x] Archive active branch execution tracker into `docs/01_Tracking/archive/task-feature-m3-memory-ui-c3.md`.
- [x] Reconcile `docs/01_Tracking/task.md` and `docs/02_Planning/00_Master/DELIVERY_INDEX.md`.
- [ ] Stage, commit, and push Phase 2 & 3 changes to `feature/m3-memory-ui-c3`.
- [ ] Open Draft PR against `develop`.

---

## Phase 4: Combined Independent Review & Merge (PENDING HUMAN GATE)

- [ ] Independent code, doc, test, and CI verification.
- [ ] Human Owner squash-merge into `develop`.
- [ ] Post-merge read-only verification on `develop`.
