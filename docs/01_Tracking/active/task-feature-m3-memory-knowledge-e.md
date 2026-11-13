# Active Branch Execution Tracker — Milestone M3 Batch E Memory & Knowledge Architecture V2

- **Branch:** `feature/m3-memory-knowledge-e`
- **Base Integration Branch:** `develop` (`04e7bc0`)
- **Delivery Level:** Level B — Planned Autonomous (Core Architecture Feature Implementation under Approved Decision D7 & ADR-0018)
- **Work Breakdown Structure IDs:** `PC-MEM-002` (guardrails & TTL), `PC-MEM-006` (3-tier memory & keyword lorebook), `PC-CLIENT-009` (Memory Control Center 3-tier inner sub-menu UI)
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-memory-knowledge-e.md`](../../02_Planning/01_Plans/plan-m3-memory-knowledge-e.md)
- **Status:** **PHASE 1 COMPLETE / AWAITING HUMAN OWNER PLAN APPROVAL**

---

## Milestone M3 Sequence Context
- **Batch M3-A (MERGED):** Character Templates, Profile Instances & Neutral Fallback (`PC-CHAR-001`, `PC-CHAR-005`, PR #29).
- **Batch M3-B (MERGED):** Immersive Character Studio V1 & 8-Trait Modulator (`PC-CHAR-002`, `PC-CLIENT-007`, PR #30).
- **Batch M3-C1..C3 (MERGED):** Memory Foundation, Extraction, and Desktop Control Center UI (`PC-MEM-001`..`005`, `PC-CLIENT-009`, PRs #35, #36, #37).
- **Batch M3-D (MERGED):** Persistent Bounded Emotion & Mood Dynamics, Turn Appraisal, Grounding & Live Mood UI (`PC-CHAR-003`, `PC-CHAR-004`, PR #38).
- **Batch M3-E (ACTIVE ON `feature/m3-memory-knowledge-e`):** Memory & Knowledge Architecture V2 (3-Tier Separation: Fixed Knowledge & Profile, Long-Term & Episodic Memory, Short-Term Context; Migration 013 `trigger_keywords` + `recall_count`; 72h context TTL; Explicit `"Remember that..."` instant verification & importance boost; Reconciler Fixed Knowledge Protection; Stem/Prefix Keyword-Triggered Lorebooks & Recall Frequency Ranking; Multi-Section XML Prompt Context; Desktop UI revamp with Option 2A inner left sub-menu, context-aware `+ Add` CTA, & `Recalled N×` badge).

---

## Phase 1: Planning & Design Authorization (COMPLETED)

- [x] Verify clean `develop` integration baseline at `04e7bc0` (with test race condition resolved).
- [x] Create and switch to dedicated delivery branch `feature/m3-memory-knowledge-e`.
- [x] Author Phase 1 Implementation Plan: [`docs/02_Planning/01_Plans/plan-m3-memory-knowledge-e.md`](../../02_Planning/01_Plans/plan-m3-memory-knowledge-e.md) (including 3 Small Wins in Batch E and documenting Big Benefits in Section 1.5 & `BACKLOG.md`).
- [x] Author Active Branch Tracker: `docs/01_Tracking/active/task-feature-m3-memory-knowledge-e.md`.
- [x] Audit plan against Decision D7, ADR-0018, `D-SHARED-AI-01`..`03`, context budget invariants, and OpenAPI parity rules.
- [ ] Submit published plan commit for Human Owner evaluation and approval before beginning Phase 2 code implementation.

---

## Phase 2: Autonomous Implementation & Verification (PLANNED)

- [ ] **Step 1 — Alembic Migration 013 & Data Model (Backend TDD):**
  - [ ] Write `backend/tests/test_migration_013.py` (upgrade, trigger preservation, downgrade protection for `trigger_keywords` and `recall_count`).
  - [ ] Implement `backend/migrations/versions/013_memory_knowledge_and_triggers.py` (`trigger_keywords` + `recall_count` columns).
  - [ ] Update `backend/app/models/memory.py` and `HEAD_REVISION` in schema lifecycle tests.
- [ ] **Step 2 — Deterministic 72h TTL, Explicit Intent Boost, Fixed Knowledge Protection & Stem/Prefix Lorebook Retrieval (Backend TDD):**
  - [ ] Write `backend/tests/test_memory_knowledge_tiers.py`.
  - [ ] Update `backend/app/services/memory/extractor.py` (72h default for situational context; explicit `"Remember that..."` instant `user_verified = True` & `importance >= 1.5`).
  - [ ] Update `backend/app/services/memory/reconciler.py` (protect fixed knowledge, consolidate recurring short-term items).
  - [ ] Update `backend/app/services/memory/retriever.py` (stem/prefix keyword-triggered lorebook matching, FTS5 prefix queries, and `recall_count` tracking/ranking boost).
- [ ] **Step 3 — Multi-Section XML Prompt Context Assembly (Backend TDD):**
  - [ ] Update `backend/app/services/assistant/orchestrator.py` to partition memories into `<user_core_profile>`, `<triggered_knowledge_lore>`, `<episodic_and_long_term_memories>`, `<short_term_context>`.
  - [ ] Verify context budget tests pass within token caps.
- [ ] **Step 4 — OpenAPI Contract & Dart SDK Parity (Contract TDD):**
  - [ ] Regenerate `contracts/openapi/openapi.json`.
  - [ ] Update `frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart` (`triggerKeywords`, `recallCount`).
  - [ ] Verify `scripts/check_dart_openapi_parity.py --check` and `dart test`.
- [ ] **Step 5 — Desktop Option 2A Inner Sub-Menu & Lorebook UI (Flutter TDD):**
  - [ ] Update `desktop_memory_controller.dart`, `memory_screen.dart`, add `memory_tier_sidebar.dart`, and update `memory_filter_bar.dart` (context-aware `+ Add`), `memory_item_card.dart` (including `Recalled N×` badge & keyword pills), `memory_edit_dialog.dart`.
  - [ ] Add widget tests in `frontend/flutter/apps/desktop/test/memory_screen_test.dart`.
  - [ ] Verify `flutter analyze` and `flutter test`.

---

## Phase 3: Documentation, Closure & Draft PR (PLANNED)

- [ ] Update canonical domain spec `docs/04_Architecture/01_Domains/memory-and-personalization.md`.
- [ ] Record entry in `CHANGELOG.md`.
- [ ] Author delivery walkthrough in `docs/03_Walkthroughs/walkthrough-m3-batch-e-memory-knowledge-v2.md`.
- [ ] Archive active branch tracker into `docs/01_Tracking/archive/task-feature-m3-memory-knowledge-e.md`.
- [ ] Reconcile `docs/01_Tracking/task.md`, `docs/02_Planning/00_Master/DELIVERY_INDEX.md`, `WBS.md`, and `MASTER_CHECKLIST.md`.
- [ ] Push changes to `origin/feature/m3-memory-knowledge-e` and open Draft PR against `develop`.

---

## Phase 4: Combined Independent Review & Merge (PENDING HUMAN GATE)

- [ ] Independent review of diff, docs, tests, and CI.
- [ ] Human Owner squash merge into `develop`.
- [ ] Post-merge read-only verification on `develop`.
