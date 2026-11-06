# Active Branch Execution Tracker — Milestone M3 Memory Control Center UI Batch C3

- **Branch:** `feature/m3-memory-ui-c3`
- **Base Integration Branch:** `develop` (`f7de198`)
- **Delivery Level:** Level B — Planned Autonomous (Core Feature Implementation under Approved Architecture D7/ADR-0018)
- **Work Breakdown Structure IDs:** `PC-CLIENT-009`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-memory-ui-c3.md`](../../02_Planning/01_Plans/plan-m3-memory-ui-c3.md)
- **Status:** **PHASE 1 PLANNING PUBLISHED / AWAITING HUMAN OWNER PLAN APPROVAL GATE**

---

## Milestone M3 Memory Sequence
- **Batch M3-C1 (CLOSED & MERGED):** Memory Foundation, Schema Migration 010, Scoping, Bound Expiry, Core-Fact Context Assembly & Dart Client Parity.
- **Batch M3-C2 (CLOSED & MERGED):** Selective Automatic Extraction & Deterministic Slot Reconciliation (`PC-MEM-002`; NEW, MERGE, UPDATE, CONFLICT, DUPLICATE; zero-latency background execution).
- **Batch M3-C3 (Current Branch):** Desktop Memory Control Center UI (`PC-CLIENT-009`), Migration 011 Per-Profile Extraction Toggle, Flip Extraction to Default ON, Conflict Resolution Banner, and Conversational Conflict Hinting.

---

## Phase 1: Planning & Design Authorization (CURRENT)

- [x] Verify clean `develop` baseline at `f7de198`.
- [x] Create and switch to dedicated delivery branch `feature/m3-memory-ui-c3`.
- [x] Complete pre-planning examination and architectural consensus with Human Owner:
  - **Decision 1 (Per-Profile Extraction Toggle):** Stored in `profiles.memory_extraction_enabled` via Alembic Migration 011.
  - **Decision 2 (Conflict Presentation in UI):** Prominent Conflict Action Banner at the top of the Desktop Memory Control Center + a "Conflicts" filter chip.
  - **Decision 3 (Conversational Conflict Clarification):** Inject `<memory_conflicts>` into the orchestrator prompt context with polite, companion-toned clarification instructions.
- [x] Author Phase 1 Implementation Plan: [`docs/02_Planning/01_Plans/plan-m3-memory-ui-c3.md`](../../02_Planning/01_Plans/plan-m3-memory-ui-c3.md).
- [x] Author Active Branch Tracker: `docs/01_Tracking/active/task-feature-m3-memory-ui-c3.md`.
- [ ] Submit published plan for Human Owner and Independent Reviewer plan evaluation.
- [ ] Human Owner plan approval gate granted.

---

## Phase 2: Autonomous Implementation & Verification (PENDING GATE)

- [ ] **Step 1 — Alembic Migration 011 & Profile Model (Backend TDD):**
  - [ ] Create `backend/tests/test_migration_011.py`.
  - [ ] Implement `backend/migrations/versions/011_profile_memory_extraction_toggle.py`.
  - [ ] Update `backend/app/models/profile.py` and `backend/app/api/v1/endpoints/profiles.py`.
  - [ ] Verify migration upgrade/downgrade and profile update tests.
- [ ] **Step 2 — Memory API Filters & Approval Updates (Backend TDD):**
  - [ ] Create `backend/tests/test_memories_api_filters.py`.
  - [ ] Add `q`, `user_verified`, and `source_type` query filters to `GET /api/v1/memories`.
  - [ ] Add `user_verified` and `source_type` to `MemoryUpdate` and update `PATCH /api/v1/memories/{memory_id}`.
  - [ ] Verify memory API tests.
- [ ] **Step 3 — Default ON Toggle & Conversational Conflict Hinting (Backend TDD):**
  - [ ] Set `MEMORY_EXTRACTION_ENABLED = True` in `backend/app/core/config.py`.
  - [ ] Wire per-profile check and `<memory_conflicts>` context in `backend/app/services/assistant/orchestrator.py`.
  - [ ] Verify extraction pipeline and full backend regression suite (755+ tests).
- [ ] **Step 4 — Dart OpenAPI Parity Updates (Dart TDD):**
  - [ ] Update `memory_dto.dart`, `profile_dto.dart`, and `companion_client.dart`.
  - [ ] Verify 100% Dart contract parity with `scripts/check_dart_openapi_parity.py`.
- [ ] **Step 5 — Flutter Desktop Memory Control Center UI (Flutter TDD):**
  - [ ] Remove `'M3'` planned badge from `DesktopNavDestination.memory`.
  - [ ] Implement `DesktopMemoryController` and unit tests in `frontend/flutter/apps/desktop/test/desktop_memory_controller_test.dart`.
  - [ ] Implement `MemoryConflictBanner`, `MemoryItemCard`, `MemoryFilterBar`, and `MemoryEditDialog`.
  - [ ] Implement `MemoryScreen` replacing placeholder.
  - [ ] Wire into `DesktopShell`.
  - [ ] Verify with `flutter test`.

---

## Phase 3: Documentation, Closure & Draft PR (PENDING PHASE 2)

- [ ] Update canonical domain spec `docs/04_Architecture/01_Domains/memory-and-personalization.md`.
- [ ] Record entry in `CHANGELOG.md`.
- [ ] Authored delivery walkthrough in `docs/03_Walkthroughs/`.
- [ ] Archive active branch execution tracker into `docs/01_Tracking/archive/`.
- [ ] Reconcile `docs/01_Tracking/task.md` and `docs/02_Planning/00_Master/DELIVERY_INDEX.md`.
- [ ] Stage, commit, and push Phase 2 & 3 changes to `feature/m3-memory-ui-c3`.
- [ ] Open Draft PR against `develop`.

---

## Phase 4: Combined Independent Review & Merge (HUMAN GATE)

- [ ] Independent code, doc, test, and CI verification.
- [ ] Human Owner squash-merge into `develop`.
- [ ] Post-merge read-only verification on `develop`.
