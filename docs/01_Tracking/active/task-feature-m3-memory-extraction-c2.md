# Active Branch Execution Tracker — Milestone M3 Memory Extraction Batch C2

- **Branch:** `feature/m3-memory-extraction-c2`
- **Base Integration Branch:** `develop` (`b3d31d79860b73b22cf34d8ef8ad65a0445d4706`)
- **Delivery Level:** Level B — Planned Autonomous (Core Feature Implementation under Approved Architecture D7/ADR-0018)
- **Work Breakdown Structure IDs:** `PC-MEM-002`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-memory-extraction-c2.md`](../../02_Planning/01_Plans/plan-m3-memory-extraction-c2.md)
- **Status:** **PHASE 1 PLAN PUBLISHED / AWAITING HUMAN APPROVAL GATE**

---

## Milestone M3 Memory Sequence
- **Batch M3-C1 (CLOSED & MERGED):** Memory Foundation, Schema Migration 010, Scoping, Bound Expiry, Core-Fact Context Assembly & Dart Client Parity.
- **Batch M3-C2 (Current Branch):** Selective Automatic Extraction & Deterministic Slot Reconciliation (`PC-MEM-002`; NEW, MERGE, UPDATE, CONFLICT; default OFF until UI).
- **Batch M3-C3 (Follow-On):** Desktop Memory Control Center UI (`PC-CLIENT-009`), flip extraction ON with per-profile toggle, resolve endpoint & "ask once" clarification hint.

---

## Phase 1: Planning & Design Authorization (IN PROGRESS)

- [x] Verify clean `develop` baseline at `b3d31d79860b73b22cf34d8ef8ad65a0445d4706`.
- [x] Create and switch to dedicated delivery branch `feature/m3-memory-extraction-c2`.
- [x] Complete pre-planning codebase and architectural check for gaps and edge cases:
  - **E1 (Session Isolation):** Post-stream background task instantiates fresh `AsyncSession` via `get_session_factory()` rather than reusing closed request session.
  - **E2 (Concurrency Guard):** Single-flight per-profile lock (`_profile_extraction_locks`) ensures extraction does not contend with interactive chat generation leases.
  - **E3 (Skip Gate & Explicit Bypass):** Fast heuristic skips turns < 4 words, code blocks, greetings; explicit "remember" cues bypass skip filter and set `confidence = 1.0`, `source_type = "user_explicit"`, `user_verified = True`.
  - **E4 (Scoping Normalization):** Reconciler coerces `scope = "character"` to `"profile"` if active conversation has `character_instance_id is None`, preserving check constraint `ck_memories_character_scope`.
  - **E5 (Conflict Handling):** `CONFLICT` preserves existing memory intact and inserts candidate with `user_verified = False` and conflict metadata/tag (no silent overwriting).
  - **E6 (Default Off):** `MEMORY_EXTRACTION_ENABLED = False` ensures extraction pipeline remains dormant by default until C3 UI ships.
- [x] Author Phase 1 Implementation Plan: [`docs/02_Planning/01_Plans/plan-m3-memory-extraction-c2.md`](../../02_Planning/01_Plans/plan-m3-memory-extraction-c2.md).
- [x] Author Active Branch Tracker: `docs/01_Tracking/active/task-feature-m3-memory-extraction-c2.md`.
- [ ] Publish planning commit to `feature/m3-memory-extraction-c2` on remote.
- [ ] Present published plan for Human Owner Plan Approval Gate before Phase 2 execution.

---

## Phase 2: Autonomous Implementation & Verification (PENDING APPROVAL)

- [ ] **Step 1 — Settings & Skip Gate (TDD):**
  - [ ] Create `backend/tests/test_memory_extraction_skip_gate.py`.
  - [ ] Add extraction configuration settings in `backend/app/core/config.py`.
  - [ ] Implement `should_skip_extraction` and `is_explicit_intent` in `backend/app/services/memory/extractor.py`.
  - [ ] Verify skip gate tests pass cleanly.
- [ ] **Step 2 — Extraction Prompt, Parser & Candidate Schema (TDD):**
  - [ ] Create `backend/tests/test_memory_extraction_prompt.py`.
  - [ ] Implement `MemoryCandidate` schema, prompt template, LLM generation, JSON parser, and secret sanitizer in `extractor.py`.
  - [ ] Verify prompt and parser tests pass cleanly.
- [ ] **Step 3 — Slot Reconciler Engine (TDD):**
  - [ ] Create `backend/tests/test_memory_reconciliation.py`.
  - [ ] Implement `reconcile_candidate` in `backend/app/services/memory/reconciler.py` with `NEW`, `MERGE`, `UPDATE`, `CONFLICT` slots.
  - [ ] Enforce character scoping normalization and auto-save threshold.
  - [ ] Verify reconciliation tests pass cleanly.
- [ ] **Step 4 — Background Post-Stream Wiring & Concurrency Lock:**
  - [ ] Create `backend/tests/test_memory_extraction_pipeline.py`.
  - [ ] Wire background extraction into `backend/app/services/assistant/orchestrator.py` after `[DONE]`.
  - [ ] Implement session isolation (`get_session_factory()`) and per-profile single-flight lock.
  - [ ] Verify pipeline integration tests pass cleanly.
- [ ] **Step 5 — Full Regression & Parity Checks:**
  - [ ] Run backend test suite: `pytest backend/tests`.
  - [ ] Run Dart contract parity: `python scripts/check_dart_openapi_parity.py`.
  - [ ] Verify 0 regressions across existing chat and memory tests.

---

## Phase 3: Documentation, Closure & Draft PR (PENDING PHASE 2)

- [ ] Update canonical domain documentation (`memory-and-personalization.md`, `task.md`, `DELIVERY_INDEX.md`).
- [ ] Add unreleased entry to `CHANGELOG.md`.
- [ ] Archive active branch execution tracker to `docs/01_Tracking/archive/task-feature-m3-memory-extraction-c2.md`.
- [ ] Stage and commit all Phase 2–3 deliverables using Conventional Commits.
- [ ] Push commits to remote branch `origin/feature/m3-memory-extraction-c2`.
- [ ] Open Draft Pull Request against `develop`.
- [ ] Monitor GitHub Actions CI until passing.

---

## Phase 4: Combined Independent Review & Human Merge (PENDING PHASE 3)

- [ ] Present diff, verification evidence, and CI status to Human Owner.
- [ ] Human Owner performs squash merge into `develop`.
- [ ] Post-merge read-only verification on `develop`.
