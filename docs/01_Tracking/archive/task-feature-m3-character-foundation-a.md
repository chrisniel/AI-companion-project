# M3 Batch A — Character Templates, Profile-Owned Instances & Neutral Assistant Fallback

> **Status:** ARCHIVED ON BRANCH — Independent implementation approved; Windows Profile-access fix accepted; documentation corrected; same-branch closure reconciled; candidate PR #29 ready for final review.
> **Branch:** `feature/m3-character-foundation-a`
> **Owner / Authorization:** Chris; implementation authorized 2026-11-02; corrections authorized 2026-11-02; documentation, provisional closure, and draft PR authorized 2026-11-02; final documentation corrections and pre-merge closure authorized 2026-11-02. No merge or protected-branch mutation.
> **Plan:** [M3 Character Foundation Batch A Plan](../../02_Planning/01_Plans/plan-m3-character-foundation-a.md)
> **Milestone:** Wider M3 remains **IN PROGRESS**.

---

## 1. Delivery and Review Checkpoints

- **Plan Approval Checkpoint:** Plan Rev 2 approved by Chris at commit `065323f5a997ca8d072cb42e68e877d0ed71c610`.
- **Initial Implementation Checkpoint:** `bca34446f674c6fc5ee3a9725c3e89b6d45b476d`.
- **Implementation Gate Review:** Independent review issued verdict `CHANGES REQUIRED` citing preset trait initialization precedence, downgrade template comparison depth, and legacy instance listing API.
- **Implementation Correction Checkpoint:** `6c38b61f2a615d0e6d0c0df09a9305f9e7ada2d0`.
- **Implementation Gate Decision:** Independently approved to proceed into documentation and provisional closure on 2026-11-02 (commit `1147e873b59e12adfc204a36331c2630e00fe905`).
- **Windows Acceptance Diagnosis & Correction:** Commit `9c9bd052861df6760e75e7b7f5c204cb7faeed19` resolved a Windows PowerShell `Get-Acl` autoloading conflict by using direct .NET CLR access control (`[System.IO.Directory]::GetAccessControl`, `[System.IO.File]::GetAccessControl`) in `HostAdminSecretStore._script`. Manual Desktop Profile access confirmed working by Chris. Hosted GitHub Actions CI Run #113 passed 100% across all 7 jobs.
- **Documentation & Provisional Closure Checkpoint:** Reconciled canonical documentation (`characters-personality-and-emotion.md`, `03_Character_Studio_and_Personality.md`), 7-section walkthrough, changelog, and PR #29 description at commit `6b4f55ef0f15e31b5d7dd691c894da878094bee0`. Hosted GitHub Actions CI Run #114 passed 100% across all 7 jobs.
- **Independent Combined Review Decision:** Independently reviewed on 2026-11-02 with verdict `APPROVED WITH MINOR CORRECTIONS` (character switching semantics, conversation API accuracy, legacy placeholder database protections, and CI verification evidence).
- **Final Documentation Corrections & Pre-Merge Closure:** Reconciled design spec, canonical architecture, walkthrough, changelog, master planning index, shared milestone task, and archived branch task.
- **Current Stage:** Same-branch closure reconciled; candidate PR #29 ready for final review. Awaiting final independent verification before human squash merge by Chris.

---

## 2. Implemented Batch Boundary

- [x] **Migration 009:** Schema tables (`character_templates`, `character_instances`), column additions (`profiles.active_character_instance_id`, `conversations.character_instance_id`), indices, SQLite CHECK constraints, 8 defense-in-depth triggers, and pre-migration backup hook via `prepare_database_schema()`.
- [x] **Immutable Neutral Assistant Fallback:** Seeded template (`id = "neutral-assistant"`) with `is_neutral_fallback = True` and NULL traits; non-editable, non-deletable, accessible via `GET /api/v1/characters/neutral`, activatable via `PUT /api/v1/characters/active` (`character_id = "default"` or `"neutral-assistant"`) or `POST /api/v1/characters/active/reset-neutral`.
- [x] **Personality Preset Catalog & Precedence:** 8 continuous trait dimensions (`warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity` as 0–100 integers) and 8 approved presets (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`); enforced precedence: explicit non-custom preset baseline $\to$ custom/omitted template baseline $\to$ explicit trait overrides (requires complete 8-dimensional `CharacterTraitVector`; partial vectors rejected by schema).
- [x] **Permanent Conversation Identity & Legacy Preservation:** Conversations permanently bind to `character_id` and `character_instance_id`; deterministic length-prefixed UUIDv5 legacy placeholder mapping (`canonical = f"{len(profile_id)}:{profile_id}|{len(legacy_character_id)}:{legacy_character_id}"`); API service mutation guards, SQLite CHECK constraints, trigger `trg_character_instances_immutable_provenance`, and `conversations.character_instance_id` foreign key `RESTRICT` preventing editing, deletion, activation, or new conversation creation with legacy placeholders.
- [x] **Ordered Relational Purge Invariants:** `CharacterInstance.profile_id` uses `ON DELETE CASCADE`, while `conversations.character_instance_id` uses `ON DELETE RESTRICT`. Future Profile hard-purge routines must purge conversations before deleting character instances.
- [x] **Profile-Isolated Character REST API:** 11 endpoints under `/api/v1/characters`, including `include_legacy` query parameter on `GET /instances` (default false).
- [x] **Loss-Aware Fail-Closed Downgrade Guard:** `downgrade()` in Migration 009 queries substantive template attributes and verifies equality against `SEED_TEMPLATES` (excluding incidental timestamp metadata); refuses downgrade on modified templates, active selections, or existing user instances, preserving all user data and schema intact.
- [x] **Runtime Persona Resolution:** `resolve_turn_persona_prompt()` in `character_service.py` dynamically resolves bound character context and structures system prompt with trusted `DEFAULT_PERSONA` instructions, followed by an XML-escaped `<character_persona>` block bounded as lower-trust configuration.
- [x] **Windows Desktop Profile Access Authority:** `HostAdminSecretStore` uses direct .NET CLR access control (`[System.IO.Directory]::GetAccessControl`, `[System.IO.File]::GetAccessControl`), verified against live Windows host runtime with manual acceptance confirmed.
- [x] **Client Contracts & Parity:** Synchronized OpenAPI 3.1 specification; Dart DTOs and `CompanionClient` character methods in `frontend/flutter/packages/companion_api` with verified parity; updated React Web client `conversationApi.ts` for optional `character_id`.
- [x] **Documentation & Walkthrough:** Reconciled `characters-personality-and-emotion.md`, `03_Character_Studio_and_Personality.md`, `CHANGELOG.md`, and created 7-section walkthrough `docs/03_Walkthroughs/walkthrough-m3-character-foundation-a.md`.
- [x] **Implementation Gate Independently Approved** (2026-11-02).
- [x] **Independent Documentation Gate Approval:** Approved with minor corrections (2026-11-02).
- [x] **Independent Closure Gate Approval:** Approved with minor corrections (2026-11-02).
- [x] **Final Pre-Merge Closure Reconciliation:** Reconciled same-branch closure records and archived task to `docs/01_Tracking/archive/task-feature-m3-character-foundation-a.md`.
- [ ] **Human Squash Merge into `develop`** (Exclusively executed by Chris).

---

## 3. Verification Receipt — 2026-11-02

All data-bearing verification checks used synthetic test profiles and disposable databases. No production credentials or user data were used.

| Working Directory | Command | Confirmed Result |
| :--- | :--- | :--- |
| Repository root | `.\venv\Scripts\python.exe -m pytest backend/tests -q` | **624 passed, 1 existing deprecation warning** in 151.76s (exit 0) |
| Repository root | `.\venv\Scripts\python.exe -m pytest backend/tests/test_character_foundation.py backend/tests/test_character_authorization.py backend/tests/test_migration_009.py backend/tests/test_conversations.py -q` | **35 passed** in 19.87s (exit 0) |
| `frontend/flutter/packages/companion_api` | `flutter test` | **79 passed** in 2.0s (exit 0) |
| `frontend/flutter/apps/desktop` | `flutter test` | **232 passed** in 52.0s (exit 0) |
| `frontend/flutter` | `dart analyze .` | **No issues found!** (exit 0) |
| `frontend/web` | `npm test` | **248 passed across 16 files** in 11.09s (exit 0) |
| Repository root | `.\venv\Scripts\python.exe scripts/check_openapi_contract.py` | Exact generated match, **39 routes up to date** (exit 0) |
| Repository root | `.\venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check` | **22/22 DTOs, 29/18 covered route methods verified** (exit 0) |
| Repository root | `git diff --check` | **Passed; 0 whitespace errors** (exit 0) |
| GitHub Actions Hosted CI | PR #29 Run #114 (commit `6b4f55e`) | **7 / 7 jobs succeeded (100% green)**; historical Run #113 (commit `9c9bd05`) also passed 100% |
| Windows Host Runtime | Manual acceptance by Chris | **Confirmed working** (Default Profile appears and activates) |

---

## 4. Independent Review and Outstanding Acceptance

| Evidence / Gate | State |
| :--- | :--- |
| Implementation Gate | **INDEPENDENTLY APPROVED** (2026-11-02) |
| Windows Acceptance | **MANUALLY CONFIRMED BY CHRIS** (2026-11-02) |
| Hosted Candidate PR CI | **PASSED (Run #114, 100% Green)** (2026-11-02) |
| Documentation Gate | **APPROVED WITH MINOR CORRECTIONS** (2026-11-02) |
| Closure Gate / PR-Ready | **ARCHIVED ON BRANCH / PR-READY** (2026-11-02) |
| Post-Merge Integration CI | **NOT APPLICABLE** (No merge performed) |
| Wider M3 | **IN PROGRESS** |

Full Character Studio interactive UI (`PC-CHAR-002`, `PC-CHAR-003`), dynamic personality engine (trait drift/sliders), persistent mood dynamics, relationship continuity, and voice synthesis integration remain deferred to subsequent M3 batches. Multimodal attachments retain their established status (backend and React Web implemented, Flutter Desktop upload button planned, vision processing model-dependent).

---

## 5. Prepared PR Handoff — Summary Only

**Title:** `feat(characters): implement M3 character templates, profile instances, and neutral assistant foundation`

**Extended Description:**

Delivers the foundational persistence, domain service, API endpoints, and client SDK parity for AI Companion's Character Foundation (`PC-CHAR-001` and `PC-CHAR-005`).

Alembic Migration 009 establishes application-owned Character Templates (`character_templates`), Profile-owned Character Instances (`character_instances`), and tracks active character selections via `profiles.active_character_instance_id` and conversation history via `conversations.character_instance_id`. Seeded templates comprise `neutral-assistant`, `warm-companion`, `playful-companion`, and `formal-advisor`. Migration safety includes pre-migration SQLite WAL backup and dynamic Alembic head discovery via `backend/app/core/storage.py`. A loss-aware fail-closed downgrade guard verifies substantive equality of seeded templates against `SEED_TEMPLATES` (excluding incidental timestamps) and checks for user instances or active selections, refusing destructive downgrade on modified data.

The Neutral Assistant provides an immutable built-in fallback with strictly NULL personality traits enforced by SQLite CHECK constraints. It is accessible via `GET /api/v1/characters/neutral` and can be selected via `PUT /api/v1/characters/active` (`character_id = "default"` or `"neutral-assistant"`) or `POST /api/v1/characters/active/reset-neutral`.

Personality presets introduce 8 continuous dimensions (`warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity` as 0–100 integers) across 8 approved presets (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`). Instance initialization follows the approved precedence: non-custom preset baseline $\to$ custom/omitted template baseline $\to$ explicit trait overrides (requiring complete 8-dimensional `CharacterTraitVector`).

Historical conversation identity is preserved by maintaining existing `character_id` values and deterministically generating collision-resistant legacy placeholder instances via UUIDv5 with pipe-delimited length prefixing (`f"{len(profile_id)}:{profile_id}|{len(legacy_character_id)}:{legacy_character_id}"`). Legacy placeholders are excluded from instance listings by default (`include_legacy=False`) and protected against modification, deletion, activation, or new conversation creation via service guards, SQLite CHECK constraints, trigger `trg_character_instances_immutable_provenance`, and `conversations.character_instance_id` foreign key `RESTRICT` constraints.

Runtime turn persona resolution (`resolve_turn_persona_prompt()`) structures prompt generation with top-level trusted `DEFAULT_PERSONA` instructions, followed by an XML-escaped `<character_persona>` block bounded as lower-trust configuration data that cannot override system rules or claim developer authority.

On the Windows desktop client, `HostAdminSecretStore` was corrected to use direct .NET CLR access control (`[System.IO.Directory]::GetAccessControl`, `[System.IO.File]::GetAccessControl`), resolving PowerShell 5.1 module-loading conflicts and restoring Profile selection authority on Windows.

Verification passed across all suites: full backend pytest (624 tests passed), focused character domain (35 tests passed), Flutter companion API (79 tests passed), Flutter desktop (232 tests passed), Flutter static analysis (`dart analyze .`, 0 issues), React web (248 tests passed), OpenAPI contract check (39 routes up to date), Dart contract parity (22 DTOs, 29 routes covered), manual Windows acceptance confirmed by Chris, and hosted GitHub Actions CI Run #114 passing 100% across all 7 jobs.

**Proposed Conventional Commit Squash Message:**

```text
feat(characters): implement M3 character templates, profile instances, and neutral assistant foundation

- Add Alembic migration 009 creating character_templates, character_instances, adding profile/conversation foreign keys, 8 triggers, and indices with pre-migration WAL backup hook
- Seed application-owned templates: neutral-assistant, warm-companion, playful-companion, and formal-advisor
- Implement immutable Neutral Assistant fallback with strictly NULL traits, non-editable constraints, and active reset endpoints
- Add 8-dimension personality preset catalog (warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity) with precedence: non-custom preset baseline -> custom/omitted template baseline -> explicit trait overrides
- Preserve historical conversation identity via deterministic length-prefixed UUIDv5 legacy placeholders, default listing exclusion, and database immutability triggers
- Enforce ordered relational purge boundaries between CharacterInstance cascade and conversation restrict constraints
- Implement runtime persona prompt resolution framing user character instructions inside a lower-trust, XML-escaped persona block
- Correct Windows Desktop HostAdminSecretStore to use direct .NET CLR access control, ensuring robust local Profile authority validation
- Implement loss-aware fail-closed downgrade guard verifying substantive seeded template fields and refusing downgrade on user data or active selections
- Provide 11 profile-isolated REST endpoints, synchronized OpenAPI 3.1 contract, Dart companion_api SDK parity, and React Web compatibility
- Add comprehensive backend, migration, authorization, Flutter, and Web regression test suites (624 backend, 79 Dart API, 232 desktop, 248 web tests passed)
```
