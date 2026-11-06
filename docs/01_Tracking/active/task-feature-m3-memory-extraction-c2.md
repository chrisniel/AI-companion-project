# Active Branch Execution Tracker — Milestone M3 Memory Extraction Batch C2

- **Branch:** `feature/m3-memory-extraction-c2`
- **Base Integration Branch:** `develop` (`b3d31d79860b73b22cf34d8ef8ad65a0445d4706`)
- **Delivery Level:** Level B — Planned Autonomous (Core Feature Implementation under Approved Architecture D7/ADR-0018)
- **Work Breakdown Structure IDs:** `PC-MEM-002`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-memory-extraction-c2.md`](../../02_Planning/01_Plans/plan-m3-memory-extraction-c2.md)
- **Status:** **PHASE 2 IN PROGRESS (AUTONOMOUS IMPLEMENTATION & VERIFICATION)**

---

## Milestone M3 Memory Sequence
- **Batch M3-C1 (CLOSED & MERGED):** Memory Foundation, Schema Migration 010, Scoping, Bound Expiry, Core-Fact Context Assembly & Dart Client Parity.
- **Batch M3-C2 (Current Branch):** Selective Automatic Extraction & Deterministic Slot Reconciliation (`PC-MEM-002`; NEW, MERGE, UPDATE, CONFLICT, DUPLICATE; default OFF until UI).
- **Batch M3-C3 (Follow-On):** Desktop Memory Control Center UI (`PC-CLIENT-009`), flip extraction ON with per-profile toggle, resolve endpoint & "ask once" clarification hint.

---

## Phase 1: Planning & Design Authorization (COMPLETED)

- [x] Verify clean `develop` baseline at `b3d31d79860b73b22cf34d8ef8ad65a0445d4706`.
- [x] Create and switch to dedicated delivery branch `feature/m3-memory-extraction-c2`.
- [x] Complete pre-planning codebase and architectural check for gaps and edge cases:
  - **E1 (Session Isolation & Rollback):** Post-stream background task instantiates fresh `AsyncSession` via `get_session_factory()` with explicit `try / except: await db.rollback()`.
  - **E2 (Concurrency Guard & Pre-Flight):** Single-flight per-profile lock (`_profile_extraction_locks`) and `provider.is_loaded()` check prevent GPU contention and standby load attempts.
  - **E3 (Disclosure-Aware Skip Gate):** Evaluates triviality but explicitly protects first-person disclosure markers (`I am`, `I'm`, `my`, `I like`, etc.); explicit "remember" cues bypass skip filter and set `confidence = 1.0`, `source_type = "user_explicit"`, `user_verified = True`.
  - **E4 (Scoping Normalization):** Reconciler coerces `scope = "character"` to `"profile"` if active conversation has `character_instance_id is None`, preserving check constraint `ck_memories_character_scope`.
  - **E5 (Conflict & Duplicate Handling):** `CONFLICT` preserves existing memory intact and inserts candidate with `source_type = "conflict"`, `user_verified = False` (no silent overwriting); `DUPLICATE` touches existing `last_verified_at = now()`.
  - **E6 (Default Off & Zero Migrations):** `MEMORY_EXTRACTION_ENABLED = False` ensures extraction pipeline remains dormant by default until C3 UI ships; zero database migrations required.
- [x] Author Phase 1 Implementation Plan: [`docs/02_Planning/01_Plans/plan-m3-memory-extraction-c2.md`](../../02_Planning/01_Plans/plan-m3-memory-extraction-c2.md).
- [x] Author Active Branch Tracker: `docs/01_Tracking/active/task-feature-m3-memory-extraction-c2.md`.
- [x] Independent plan review completed; 5 surgical refinements integrated.
- [x] Human Owner plan approval gate granted.

---

## Phase 2: Autonomous Implementation & Verification (IN PROGRESS)

- [ ] **Step 1 — Settings & Skip Gate (TDD):**
  - [ ] Create `backend/tests/test_memory_extraction_skip_gate.py`.
  - [ ] Add extraction configuration settings in `backend/app/core/config.py`.
  - [ ] Implement `should_skip_extraction` and `is_explicit_intent` in `backend/app/services/memory/extractor.py`.
  - [ ] Verify skip gate tests pass cleanly.
- [ ] **Step 2 — Extraction Prompt, Parser & Candidate Schema (TDD):**
  - [ ] Create `backend/tests/test_memory_extraction_prompt.py`.
  - [ ] Implement `MemoryCandidate` schema, prompt template, LLM generation, JSON parser, secret sanitizer, and model ready pre-flight in `extractor.py`.
  - [ ] Verify prompt and parser tests pass cleanly.
- [ ] **Step 3 — Slot Reconciler Engine (TDD):**
  - [ ] Create `backend/tests/test_memory_reconciliation.py`.
  - [ ] Implement `reconcile_candidate` in `backend/app/services/memory/reconciler.py` with `DUPLICATE`, `NEW`, `MERGE`, `UPDATE`, `CONFLICT` slots.
  - [ ] Enforce character scoping normalization and auto-save threshold.
  - [ ] Verify reconciliation tests pass cleanly.
- [ ] **Step 4 — Background Post-Stream Wiring & Concurrency Lock:**
  - [ ] Create `backend/tests/test_memory_extraction_pipeline.py`.
  - [ ] Wire background extraction into `backend/app/services/assistant/orchestrator.py` after `[DONE]`.
  - [ ] Implement session isolation (`get_session_factory()`), rollback protection, and per-profile single-flight lock.
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
