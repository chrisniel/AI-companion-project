# M3 Batch A — Character Templates, Profile-Owned Instances & Neutral Assistant Fallback

> **Status:** IMPLEMENTED / LOCALLY VERIFIED — provisional closure prepared; independent combined review pending.  
> **Branch:** `feature/m3-character-foundation-a`  
> **Owner / Authorization:** Chris; implementation authorized 2026-11-02; corrections authorized 2026-11-02; documentation, provisional closure, and draft PR authorized 2026-11-02. No merge or protected-branch mutation.  
> **Plan:** [M3 Character Foundation Batch A Plan](../../02_Planning/01_Plans/plan-m3-character-foundation-a.md)  
> **Milestone:** Wider M3 remains **IN PROGRESS**.

---

## 1. Delivery and Review Checkpoints

- **Plan Approval Checkpoint:** Plan Rev 2 approved by Chris at commit `065323f5a997ca8d072cb42e68e877d0ed71c610`.
- **Initial Implementation Checkpoint:** `bca34446f674c6fc5ee3a9725c3e89b6d45b476d`.
- **Implementation Gate Review:** Independent review issued verdict `CHANGES REQUIRED` citing preset trait initialization precedence, downgrade template comparison depth, and legacy instance listing API.
- **Implementation Correction Checkpoint:** `6c38b61f2a615d0e6d0c0df09a9305f9e7ada2d0`.
- **Implementation Gate Decision:** Independently approved to proceed into documentation, provisional closure, and draft PR on 2026-11-02.
- **Current Stage:** Documentation reconciled, technical walkthrough authored, provisional closure tracking prepared, and draft PR opened awaiting combined review.

---

## 2. Implemented Batch Boundary

- [x] **Migration 009:** Schema tables (`character_templates`, `character_instances`, `profile_active_characters`), indices, SQLite CHECK constraints, legacy triggers, and pre-migration backup hook via `prepare_database_schema()`.
- [x] **Immutable Neutral Assistant Fallback:** Seeded template with `is_neutral_fallback = True` and NULL traits; non-editable, non-deletable, accessible via `GET /api/v1/characters/neutral`, activatable via `PUT /api/v1/characters/active` or `POST /api/v1/characters/active/reset-neutral`.
- [x] **Personality Preset Catalog & Precedence:** 8 continuous trait dimensions (`warmth`, `humor`, `empathy`, `formality`, `curiosity`, `energy`, `assertiveness`, `rebelliousness`) and 8 approved presets; enforced precedence: explicit non-custom preset baseline $\to$ custom/omitted template baseline $\to$ explicit trait overrides.
- [x] **Permanent Conversation Identity & Legacy Preservation:** Conversations permanently bind to `character_id`; deterministic length-prefixed UUIDv5 legacy placeholder mapping (`f"legacy-{uuid.uuid5(LEGACY_CHARACTER_NAMESPACE, canonical)}"`); SQLite triggers and service guards preventing editing, deletion, activation, or new conversation creation with legacy placeholders.
- [x] **Profile-Isolated Character REST API:** 11 endpoints under `/api/v1/characters`, including `include_legacy` query parameter on `GET /instances` (default false).
- [x] **Loss-Aware Fail-Closed Downgrade Guard:** `downgrade()` in Migration 009 queries substantive template attributes and verifies equality against `SEED_TEMPLATES` (excluding incidental timestamp metadata); refuses downgrade on modified templates or existing user instances, preserving all user data and schema intact.
- [x] **Runtime Persona Resolution:** Orchestrator dynamically resolves bound character context and structures system prompt with identity and lore; backend authentication, foreign keys, triggers, and deterministic Python policies enforce boundaries.
- [x] **Client Contracts & Parity:** Synchronized OpenAPI 3.1 specification; Dart DTOs and `CompanionClient` character methods in `frontend/flutter/packages/companion_api` with verified parity; updated React Web client `conversationApi.ts` for optional `character_id`.
- [x] **Documentation & Walkthrough:** Reconciled `characters-personality-and-emotion.md`, `03_Character_Studio_and_Personality.md`, `DELIVERY_WORKFLOW.md`, `AGENTS.md`, `CHANGELOG.md`, and created 7-section walkthrough `docs/03_Walkthroughs/walkthrough-m3-character-foundation-a.md`.
- [x] **Implementation Gate Independently Approved.**
- [x] **Draft PR Created:** Targeting `develop` awaiting combined independent review.
- [ ] **Independent Documentation Gate Approval.**
- [ ] **Independent Closure Gate Approval.**
- [ ] **Final Pre-Merge Closure Reconciliation:** Archive active task to `docs/01_Tracking/archive/`.
- [ ] **Human Squash Merge into `develop`.**

---

## 3. Local Verification Receipt — 2026-11-02

All data-bearing verification checks used synthetic test profiles and disposable databases. No production credentials or user data were used.

| Working Directory | Command | Confirmed Result |
| :--- | :--- | :--- |
| Repository root | `.\venv\Scripts\python.exe -m pytest backend/tests -q` | **624 passed, 1 existing deprecation warning** in 137.24s (exit 0) |
| Repository root | `.\venv\Scripts\python.exe -m pytest backend/tests/test_character_foundation.py backend/tests/test_character_authorization.py backend/tests/test_migration_009.py backend/tests/test_conversations.py -q` | **35 passed** in 19.87s (exit 0) |
| `frontend/flutter/packages/companion_api` | `flutter test` | **79 passed** in 2.0s (exit 0) |
| `frontend/flutter/apps/desktop` | `flutter test` | **231 passed** in 52.0s (exit 0) |
| `frontend/web` | `npm test` | **248 passed across 16 files** in 11.09s (exit 0) |
| Repository root | `.\venv\Scripts\python.exe scripts/check_openapi_contract.py` | Exact generated match, **39 routes up to date** (exit 0) |
| Repository root | `.\venv\Scripts\python.exe scripts/check_dart_openapi_parity.py` | **22/22 DTOs, 29/18 covered route methods verified** (exit 0) |
| Repository root | `git diff --check` | **Passed**; Git line-ending advisories only |

---

## 4. Independent Review and Outstanding Acceptance

| Evidence / Gate | State |
| :--- | :--- |
| Implementation Gate | **INDEPENDENTLY APPROVED** (2026-11-02) |
| Documentation Gate | **PENDING INDEPENDENT REVIEW** (No self-approval) |
| Closure Gate / PR-Ready | **PROVISIONAL** (Awaiting combined independent review) |
| Hosted Candidate PR CI | **INSPECTED / REPORTED** upon draft PR creation |
| Post-Merge Integration CI | **NOT APPLICABLE** (No merge performed) |
| Wider M3 | **IN PROGRESS** |

Full Character Studio interactive UI (`PC-CHAR-002`, `PC-CHAR-003`), dynamic personality engine (trait drift/sliders), persistent mood dynamics, relationship continuity, and voice synthesis integration remain deferred to subsequent M3 batches.

---

## 5. Prepared PR Handoff — Summary Only

**Title:** `feat(characters): implement M3 character templates, profile instances, and neutral assistant foundation`

**Extended Description:**

Delivers the foundational persistence, domain service, API endpoints, and client SDK parity for AI Companion's Character Foundation (`PC-CHAR-001` and `PC-CHAR-005`).

Alembic Migration 009 establishes application-owned Character Templates (`character_templates`), Profile-owned Character Instances (`character_instances`), and Profile active character tracking (`profile_active_characters`). Migration safety includes pre-migration SQLite WAL backup and dynamic Alembic head discovery via `backend/app/core/storage.py`. A loss-aware fail-closed downgrade guard verifies substantive equality of seeded templates against `SEED_TEMPLATES` (excluding incidental timestamps) and checks for user instances, refusing destructive downgrade on modified data.

The Neutral Assistant provides an immutable built-in fallback with strictly NULL personality traits enforced by SQLite CHECK constraints. It is accessible via `GET /api/v1/characters/neutral` and can be selected via `PUT /api/v1/characters/active` or `POST /api/v1/characters/active/reset-neutral`.

Personality presets introduce 8 continuous dimensions (`warmth`, `humor`, `empathy`, `formality`, `curiosity`, `energy`, `assertiveness`, `rebelliousness`) across 8 approved presets (`warm`, `playful`, `formal`, `creative`, `analytical`, `empathetic`, `stoic`, `unhinged`, plus `custom`). Instance initialization follows the approved precedence: non-custom preset baseline $\to$ custom/omitted template baseline $\to$ explicit trait overrides.

Historical conversation identity is preserved by maintaining existing `character_id` values and deterministically generating collision-resistant legacy placeholder instances via UUIDv5 with length-prefixed encoding. Legacy placeholders are excluded from instance listings by default (`include_legacy=False`) and protected against modification, deletion, activation, or new conversation creation via service guards and SQLite database triggers.

The client layer includes synchronized OpenAPI 3.1 contracts, complete Dart DTOs and `CompanionClient` methods with 100% route and schema parity, and React Web conversation creation compatibility.

Verification passed across all suites: full backend pytest (624 tests passed), focused character domain (35 tests passed), Flutter companion API (79 tests passed), Flutter desktop (231 tests passed), React web (248 tests passed), OpenAPI contract check (39 routes up to date), and Dart contract parity (22 DTOs, 29 routes covered).

**Proposed Conventional Commit Squash Message:**

```text
feat(characters): implement M3 character templates, profile instances, and neutral assistant foundation

- Add Alembic migration 009 creating character_templates, character_instances, profile_active_characters, triggers, and indices with pre-migration WAL backup hook
- Implement immutable Neutral Assistant fallback with strictly NULL traits, non-editable constraints, and active reset endpoints
- Add 8-dimension personality preset catalog with precedence: non-custom preset baseline -> custom/omitted template baseline -> explicit trait overrides
- Preserve historical conversation identity via deterministic length-prefixed UUIDv5 legacy placeholders, default listing exclusion, and database immutability triggers
- Implement loss-aware fail-closed downgrade guard verifying substantive seeded template fields and refusing downgrade on user data
- Provide 11 profile-isolated REST endpoints, synchronized OpenAPI 3.1 contract, Dart companion_api SDK parity, and React Web compatibility
- Add comprehensive backend, migration, authorization, Flutter, and Web regression test suites (624 backend, 79 Dart API, 231 desktop, 248 web tests passed)
```
