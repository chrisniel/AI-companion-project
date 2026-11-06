# Active Branch Execution Tracker — Milestone M3 Memory Foundation Batch C1

- **Branch:** `feature/m3-memory-foundation-c1`
- **Base Integration Branch:** `develop` (`f3752a3a0e4bbfe0640f10ccebe6143419dfa435`)
- **Delivery Level:** Level C — Sensitive Design (Database Schema Migration & Personal Data Retention Boundary)
- **Work Breakdown Structure IDs:** `PC-MEM-001`, `PC-MEM-003`, `PC-MEM-005`, `PC-API-001`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-memory-foundation-c1.md`](../../02_Planning/01_Plans/plan-m3-memory-foundation-c1.md)
- **Status:** **PHASE 1 PLANNING REVISED / AWAITING HUMAN OWNER APPROVAL**

---

## Milestone M3 Memory Sequence
- **Batch M3-C1 (Current Branch):** Memory Foundation, Schema Migration 010, Scoping, Bound Expiry, Core-Fact Context Assembly & Dart Client Parity.
- **Batch M3-C2 (Follow-On):** Selective Automatic Extraction & Deterministic Slot Reconciliation (NEW, MERGE, UPDATE, CONFLICT; default OFF until UI).
- **Batch M3-C3 (Follow-On):** Desktop Memory Control Center UI, flip extraction ON with per-profile toggle, resolve endpoint & "ask once" clarification hint.

---

## Phase 1: Planning & Design Authorization (AWAITING APPROVAL)

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
- [ ] Publish revised planning commit to `feature/m3-memory-foundation-c1` on remote and present for Human Owner review.

---

## Phase 2: Autonomous Implementation & Verification (NOT STARTED)

- [ ] **Step 1 — TDD Test Suite First:**
  - [ ] Create `backend/tests/test_migration_010.py` for migration evolution and FTS trigger cycling.
  - [ ] Create `backend/tests/test_memory_foundation.py` covering scoping, bound-time expiry, core facts, and API validation.
  - [ ] Confirm tests fail against baseline (RED).
- [ ] **Step 2 — Migration 010 & Data Models:**
  - [ ] Implement `backend/migrations/versions/010_memory_scoping_and_lifecycle.py` with trigger cycling and rebuild.
  - [ ] Update `backend/app/models/memory.py` and `backend/app/schemas/memory.py`.
  - [ ] Verify migration tests pass (GREEN).
- [ ] **Step 3 — Scoped Retrieval & Temporal Filtering:**
  - [ ] Update `backend/app/services/memory/retriever.py` with bound `:now` parameter, scoping, and core facts.
  - [ ] Update `backend/app/services/assistant/orchestrator.py` to pass conversation `character_instance_id`.
  - [ ] Verify retrieval and scoping tests pass (GREEN).
- [ ] **Step 4 — REST API Hardening & Retention Purge:**
  - [ ] Update `backend/app/api/v1/endpoints/memories.py` (add `GET /api/v1/memories/{id}`, filters, nulling PATCH, foreign instance checks).
  - [ ] Update `backend/app/services/profile_purge_service.py` to include soft-deleted memory retention purge.
  - [ ] Verify API and retention tests pass (GREEN).
- [ ] **Step 5 — Dart Client Implementation & Parity Checks:**
  - [ ] Author `frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart`.
  - [ ] Implement client methods in `companion_client.dart`.
  - [ ] Add client unit tests in `companion_api/test/companion_client_test.dart`.
  - [ ] Update `scripts/check_dart_openapi_parity.py` and regenerate `openapi.json`.
  - [ ] Verify `scripts/tests/test_check_dart_openapi_parity.py` passes.
- [ ] **Step 6 — Full Automated Verification Suite:**
  - [ ] Run backend unit & integration tests (`pytest`).
  - [ ] Run contract parity checks.
  - [ ] Run Flutter workspace tests (`flutter test`).

---

## Phase 3: Documentation, Closure & Draft PR (NOT STARTED)

- [ ] Reconcile canonical domain documentation (`memory-and-personalization.md`, `DECISION_DEBT.md`, `task.md`, `DELIVERY_INDEX.md`).
- [ ] Record verification evidence and changelog entries.
- [ ] Prepare delivery walkthrough.
- [ ] Push implementation commits and open draft pull request against `develop`.

---

## Phase 4: Review & Squash Merge (NOT STARTED)

- [ ] Independent code review.
- [ ] Hosted CI verification.
- [ ] Human Owner squash merge into `develop`.
