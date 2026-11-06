# Active Branch Execution Tracker — Milestone M3 Memory Foundation Batch C1 (Archived)

- **Branch:** `feature/m3-memory-foundation-c1`
- **Base Integration Branch:** `develop` (`f3752a3a0e4bbfe0640f10ccebe6143419dfa435`)
- **Delivery Level:** Level C — Sensitive Design (Database Schema Migration & Personal Data Retention Boundary)
- **Work Breakdown Structure IDs:** `PC-MEM-001`, `PC-MEM-003`, `PC-MEM-005`, `PC-API-001`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-memory-foundation-c1.md`](../../02_Planning/01_Plans/plan-m3-memory-foundation-c1.md)
- **Status:** **PHASE 3 COMPLETE / ARCHIVED CANDIDATE READY FOR PHASE 4 COMBINED REVIEW & MERGE**

---

## Milestone M3 Memory Sequence
- **Batch M3-C1 (Current Branch):** Memory Foundation, Schema Migration 010, Scoping, Bound Expiry, Core-Fact Context Assembly & Dart Client Parity.
- **Batch M3-C2 (Follow-On):** Selective Automatic Extraction & Deterministic Slot Reconciliation (NEW, MERGE, UPDATE, CONFLICT; default OFF until UI).
- **Batch M3-C3 (Follow-On):** Desktop Memory Control Center UI, flip extraction ON with per-profile toggle, resolve endpoint & "ask once" clarification hint.

---

## Phase 1: Planning & Design Authorization (COMPLETED)

- [x] Verify clean `develop` baseline at `f3752a3a0e4bbfe0640f10ccebe6143419dfa435`.
- [x] Create and switch to dedicated delivery branch `feature/m3-memory-foundation-c1`.
- [x] Complete comprehensive codebase and documentation audit for gaps and edge cases.
- [x] Human Owner review and alignment on core decisions:
  - **A1, A2, A4–A6:** Migration FTS safety with trigger cycling & rebuild; create `memory_dto.dart` and `CompanionClient` methods; accurate test commands (`test_memory_fts.py`, `unittest discover`); bound `:now` temporal comparison; Level C reclassification.
  - **A3:** Web test runner skipped; API responses remain additive and backward-compatible.
  - **D1 (Reclassification):** Level C — Sensitive Design (Schema migration & personal data retention).
  - **D3 (Conflict Handling):** Deterministic slot-based reconciliation planned for Batch C2.
  - **D4 (Core-Fact Injection):** Capped at 5 facts and 100 tokens, deduplicated against FTS hits, with `MEMORY_CORE_FACTS_ENABLED` flag.
  - **D5 (Revalidation & Proactive Check-Ins):** Reactive revalidation in C1/C3; proactive check-ins deferred to SchedulerService/Notification milestones.
  - **D6 (Extraction Toggle):** Extraction default OFF in C2 until UI ships in C3.
- [x] Revise Phase 1 Implementation Plan: `docs/02_Planning/01_Plans/plan-m3-memory-foundation-c1.md`.
- [x] Revise Active Branch Tracker: `docs/01_Tracking/active/task-feature-m3-memory-foundation-c1.md`.
- [x] Publish revised planning commit to `feature/m3-memory-foundation-c1` on remote and obtain Human Owner authorization for Phase 2–3 execution.

---

## Phase 2: Autonomous Implementation & Verification (COMPLETED)

- [x] **Step 1 — TDD Test Suite First:**
  - [x] Create `backend/tests/test_migration_010.py` for migration evolution and FTS trigger cycling.
  - [x] Create `backend/tests/test_memory_foundation.py` covering scoping, bound-time expiry, core facts, and API validation.
- [x] **Step 2 — Migration 010 & Data Models:**
  - [x] Implement `backend/migrations/versions/010_memory_scoping_and_lifecycle.py` with trigger cycling and rebuild.
  - [x] Update `backend/app/models/memory.py` and `backend/app/schemas/memory.py`.
  - [x] Verify migration tests pass: 4/4 passed in `test_migration_010.py`.
- [x] **Step 3 — Scoped Retrieval & Temporal Filtering:**
  - [x] Update `backend/app/services/memory/retriever.py` with bound `:now` parameter, scoping, and core facts.
  - [x] Update `backend/app/services/assistant/orchestrator.py` to pass conversation `character_instance_id`.
  - [x] Verify retrieval and scoping tests pass: 8/8 passed in `test_memory_foundation.py`.
- [x] **Step 4 — REST API Hardening & Retention Purge:**
  - [x] Update `backend/app/api/v1/endpoints/memories.py` (add `GET /api/v1/memories/{id}`, filters, nulling PATCH, foreign instance checks).
  - [x] Update `backend/app/services/profile_purge_service.py` (delete Memory before CharacterInstance, soft-delete retention purge).
  - [x] Verify API and retention tests pass.
- [x] **Step 5 — Dart Client Implementation & Parity Checks:**
  - [x] Author `frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart`.
  - [x] Implement client methods in `companion_client.dart` (`listMemories`, `getMemory`, `createMemory`, `updateMemory`, `deleteMemory`).
  - [x] Add client unit tests in `companion_api/test/companion_client_test.dart`.
  - [x] Update `scripts/check_dart_openapi_parity.py` and regenerate `openapi.json`.
  - [x] Verify `scripts/tests/test_check_dart_openapi_parity.py` passes (38/38 passed).
  - [x] Verify Flutter analyzer and tests pass (`dart analyze`: 0 issues; `flutter test packages/companion_api/test`: 95/95 passed).
- [x] **Step 6 — Full Automated Verification Suite:**
  - [x] Run backend unit & integration regression tests (`pytest`: 63/63 passed in 17.13s).
  - [x] Run contract parity checks (32/32 schemas, 42/42 client routes).
  - [x] Run Flutter workspace tests (95/95 passed).

---

## Phase 3: Documentation, Closure & Draft PR (COMPLETED)

- [x] Reconcile canonical domain documentation (`memory-and-personalization.md`, `DECISION_DEBT.md`, `task.md`, `DELIVERY_INDEX.md`).
- [x] Record verification evidence and changelog entries in `CHANGELOG.md`.
- [x] Author delivery walkthrough: `docs/03_Walkthroughs/walkthrough-m3-batch-c1-memory-foundation.md`.
- [x] Reconcile and archive active branch execution tracker to `docs/01_Tracking/archive/task-feature-m3-memory-foundation-c1.md`.
- [x] Stage and commit all Phase 2–3 deliverables using Conventional Commits.
- [x] Push commits to remote branch `origin/feature/m3-memory-foundation-c1`.
- [x] Open Draft Pull Request against `develop`.
- [x] Monitor GitHub Actions CI until passing.

---

## Phase 4: Review & Squash Merge (PENDING HUMAN OWNER)

- [ ] Combined Independent Reviewer audit.
- [ ] Human Owner squash merge into `develop`.
- [ ] Read-only post-merge baseline verification on `develop`.
