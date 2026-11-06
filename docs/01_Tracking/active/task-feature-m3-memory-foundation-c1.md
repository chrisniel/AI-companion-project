# Active Branch Execution Tracker — Milestone M3 Memory Foundation Batch C1

- **Branch:** `feature/m3-memory-foundation-c1`
- **Base Integration Branch:** `develop` (`f3752a3a0e4bbfe0640f10ccebe6143419dfa435`)
- **Delivery Level:** Level B — Planned Autonomous (with Migration Safety Gate)
- **Work Breakdown Structure IDs:** `PC-MEM-001`, `PC-MEM-002`, `PC-MEM-003`, `PC-MEM-005`, `PC-API-001`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-memory-foundation-c1.md`](../../02_Planning/01_Plans/plan-m3-memory-foundation-c1.md)
- **Status:** **PHASE 1 PLANNING PUBLISHED / AWAITING HUMAN APPROVAL**

---

## Phase 1: Planning & Design Authorization (AWAITING APPROVAL)

- [x] Verify clean `develop` baseline at `f3752a3a0e4bbfe0640f10ccebe6143419dfa435`.
- [x] Create and switch to dedicated delivery branch `feature/m3-memory-foundation-c1`.
- [x] Discuss open decisions with Human Owner:
  - **D1 (Extraction Execution):** Fast skip gate + asynchronous post-turn local LLM extraction (0ms impact on chat streaming, ~1.5s background compute).
  - **D2 (Auto-Save):** Silent auto-save with full transparency & inspection in the Desktop Memory screen.
  - **D4 (Temporal Validity & Revalidation):** Schema support for `valid_from`, `expires_at`, `last_verified_at`, and `revalidation_state` with conversational revalidation.
  - **D5 (Batching):** 2-batch sequence (Batch M3-C1 Backend Foundation & Extraction $\rightarrow$ Batch M3-C2 Desktop UI & End-to-End Recall).
- [x] Author Phase 1 Implementation Plan: `docs/02_Planning/01_Plans/plan-m3-memory-foundation-c1.md`.
- [x] Author Active Branch Tracker: `docs/01_Tracking/active/task-feature-m3-memory-foundation-c1.md`.
- [ ] Publish planning commit to `feature/m3-memory-foundation-c1` on remote and present for Human Owner review.

---

## Phase 2: Autonomous Implementation & Verification (NOT STARTED)

- [ ] **Step 1 — TDD Test Suite First:**
  - [ ] Create `backend/tests/test_memory_foundation.py` covering test cases `MEM-01` through `MEM-08`.
  - [ ] Confirm tests fail against baseline (RED).
- [ ] **Step 2 — Migration 010 & Data Models:**
  - [ ] Implement `backend/migrations/versions/010_memory_scoping_and_lifecycle.py`.
  - [ ] Update `backend/app/models/memory.py` and `backend/app/schemas/memory.py`.
  - [ ] Verify `MEM-01` and `MEM-02` pass (GREEN).
- [ ] **Step 3 — Scoped Retrieval & Temporal Filtering:**
  - [ ] Update `backend/app/services/memory/retriever.py` with scoping and expiry filters.
  - [ ] Update `backend/app/services/assistant/orchestrator.py` to pass active `character_instance_id`.
  - [ ] Verify `MEM-03` and `MEM-04` pass (GREEN).
- [ ] **Step 4 — Automatic Extraction Engine:**
  - [ ] Implement `backend/app/services/memory/extractor.py`.
  - [ ] Wire asynchronous post-turn hook into `orchestrator.py`.
  - [ ] Verify `MEM-05` and `MEM-06` pass (GREEN).
- [ ] **Step 5 — REST API Hardening & Single-Item Endpoint:**
  - [ ] Update `backend/app/api/v1/endpoints/memories.py` (add `GET /api/v1/memories/{id}`, support scope/expiry query filters).
  - [ ] Verify `MEM-07` and `MEM-08` pass (GREEN).
- [ ] **Step 6 — OpenAPI Parity & Dart Client:**
  - [ ] Regenerate `contracts/openapi/openapi.json`.
  - [ ] Update `companion_api` DTOs and client methods.
  - [ ] Verify contract parity checks and Dart client unit tests.
- [ ] **Step 7 — Full Automated Verification Suite:**
  - [ ] Run backend unit & integration tests (`pytest`).
  - [ ] Run contract parity checks.
  - [ ] Run Flutter workspace tests (`flutter test`).

---

## Phase 3: Documentation, Closure & Draft PR (NOT STARTED)

- [ ] Reconcile canonical domain documentation (`memory-and-personalization.md`, `DELIVERY_INDEX.md`, `task.md`).
- [ ] Record verification evidence and changelog entries.
- [ ] Prepare delivery walkthrough.
- [ ] Push implementation commits and open draft pull request against `develop`.

---

## Phase 4: Review & Squash Merge (NOT STARTED)

- [ ] Independent code review.
- [ ] Hosted CI verification.
- [ ] Human Owner squash merge into `develop`.
