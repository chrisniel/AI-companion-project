# Active Branch Execution Tracker — Milestone M3 Batch F Pre-Limit Context Compaction & Memory V2 Follow-On

- **Branch:** `feature/m3-context-compaction-memory-f`
- **Base Integration Branch:** `develop` (`ea4441c`)
- **Delivery Level:** Level B — Planned Autonomous (with Level C database schema migration `014_conversation_summaries_and_compaction`)
- **Work Breakdown Structure IDs:** `PC-MEM-005`, `PC-MEM-002`, `PC-MEM-003`, `PC-MEM-004`, `PC-CLIENT-006`, `PC-CLIENT-009`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m3-context-compaction-memory-f.md`](../../02_Planning/01_Plans/plan-m3-context-compaction-memory-f.md)
- **Status:** **PHASE 1 PLAN PUBLISHED — AWAITING HUMAN PLAN APPROVAL GATE**

---

## Milestone M3 Sequence Context
- **Batch M3-A (MERGED):** Character Templates, Profile Instances & Neutral Fallback (`PC-CHAR-001`, `PC-CHAR-005`, PR #29).
- **Batch M3-B (MERGED):** Immersive Character Studio V1 & 8-Trait Modulator (`PC-CHAR-002`, `PC-CLIENT-007`, PR #30).
- **Batch M3-C1..C3 (MERGED):** Memory Foundation, Extraction, and Desktop Control Center UI (`PC-MEM-001`..`005`, `PC-CLIENT-009`, PRs #35, #36, #37).
- **Batch M3-D (MERGED):** Persistent Bounded Emotion & Mood Dynamics, Turn Appraisal, Grounding & Live Mood UI (`PC-CHAR-003`, `PC-CHAR-004`, PR #38).
- **Batch M3-E (MERGED):** Memory & Knowledge Architecture V2 (`PC-MEM-001`..`005`, `PC-CLIENT-009`, Migration 013 `trigger_keywords` + `recall_count`, PR #39, commit `ea4441c`).
- **Batch M3-F (PHASE 1 PLANNING):** Pre-Limit Context Compaction, Rolling Conversation Summaries (Migration 014), Emotion-Weighted Memory Importance (`+0.3`), Temporal Fact Evolution (`previously: ... until YYYY-MM`), 1-Click Chat Bubble Bookmark & Manual Compaction UI, plus 6 Batch E independent review hardening fixes.

---

## Phase 1: Planning & Design Authorization (IN PROGRESS — AWAITING APPROVAL)

- [x] Verify clean `develop` integration baseline (`ea4441c`).
- [x] Create and switch to dedicated delivery branch `feature/m3-context-compaction-memory-f`.
- [x] Author Phase 1 Implementation Plan: [`docs/02_Planning/01_Plans/plan-m3-context-compaction-memory-f.md`](../../02_Planning/01_Plans/plan-m3-context-compaction-memory-f.md).
- [x] Author Active Branch Tracker: `docs/01_Tracking/active/task-feature-m3-context-compaction-memory-f.md`.
- [x] Register plan in [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](../../02_Planning/00_Master/DELIVERY_INDEX.md).
- [ ] Commit & push Phase 1 planning files to `origin/feature/m3-context-compaction-memory-f`.
- [ ] **GATE:** Human Owner review and explicit plan approval before Phase 2 implementation begins.

---

## Phase 2: Autonomous Implementation & Verification (LOCKED UNTIL PHASE 1 APPROVAL)

- [ ] **Step 1 — Migration 014 & ConversationSummary Cascades (Backend TDD)**
- [ ] **Step 2 — Pre-Limit Compaction Engine, Orchestrator `<recent_episode_digest>` & Conversation Endpoints (Backend TDD)**
- [ ] **Step 3 — Emotion-Weighted Importance, Temporal Fact Evolution & 6 Batch E Hardening Fixes (Backend TDD)**
- [ ] **Step 4 — OpenAPI, TypeScript, Parity Verifier & Dart SDK Sync (Contract TDD)**
- [ ] **Step 5 — Flutter Desktop UI (`DesktopMemoryController`, `DesktopChatController`, `ChatScreen`) (Flutter TDD)**
- [ ] Run full backend, contract parity, Web, and Flutter verification suites cleanly.

---

## Phase 3: Documentation, Closure & Draft PR (PENDING PHASE 2)

- [ ] Sync canonical domain docs (`assistant-and-conversations.md`, `memory-and-personalization.md`), master planning docs, changelog, and delivery walkthrough.
- [ ] Archive this branch tracker to `docs/01_Tracking/archive/task-feature-m3-context-compaction-memory-f.md`.
- [ ] Push implementation + closure commits and open one Draft PR against `develop`.

---

## Phase 4: Combined Independent Review & Merge (PENDING HUMAN GATE)

- [ ] Independent review of diff, docs, tests, CI, and manual Windows acceptance checklist.
- [ ] Human Owner squash merge into `develop` and read-only post-merge verification.
