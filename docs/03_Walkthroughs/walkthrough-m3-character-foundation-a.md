# Walkthrough: M3 Character Foundation — Batch A (Templates, Profile Instances & Neutral Assistant Fallback)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Document the implementation, architectural mechanisms, data models, API endpoints, client contracts, and verification evidence for AI Companion's Character Foundation (`PC-CHAR-001` and `PC-CHAR-005`).
- **Audience:** Core developers, client application engineers (Flutter Desktop & React Web), security auditors, and system maintainers.
- **Status:** Implemented & Locally Verified (Implementation Gate independently approved; combined documentation/closure review pending).
- **Last Updated:** 2026-11-02

---

## 1. What Was Delivered

- **Application-Owned Character Templates:** Immutable, versioned (`template_version >= 1`) definitions seeded in Alembic Migration 009 (`character_templates` table). Seeded templates: `warm-companion`, `playful-friend`, `stoic-mentor`, and `neutral-assistant`.
- **Profile-Owned Character Instances:** Snapshot configurations instantiated from templates (`character_instances` table), tied to an authenticated `profile_id` with `ON DELETE CASCADE`. Instances store custom persona names, system prompts, avatar assets, preset references, and 8 continuous personality trait values. Updating a template never mutates existing instances.
- **Immutable Neutral Assistant Fallback:** Built-in unalterable fallback (`is_neutral_fallback = True`, all traits strictly `NULL` via SQLite CHECK constraints). Accessible via `GET /api/v1/characters/neutral`, and activated via `PUT /api/v1/characters/active` (`character_instance_id="default"` or `"neutral-assistant"`) or `POST /api/v1/characters/active/reset-neutral`.
- **Personality Presets & Initialization Precedence:** Catalog of 8 approved presets (`warm`, `playful`, `formal`, `creative`, `analytical`, `empathetic`, `stoic`, `unhinged`, plus `custom`). In `create_character_instance`:
  1. Explicit non-custom preset initializes traits from preset baseline.
  2. Custom or omitted preset initializes traits from template baseline.
  3. Explicit trait vector overrides baseline values.
- **Permanent Conversation Identity & Legacy Preservation:**
  - Conversations permanently bind to `character_id`.
  - Creating a conversation without specifying `character_id` defaults to the Profile's active character instance (or Neutral Assistant if none active).
  - Explicit `"default"` or `"neutral-assistant"` selects Neutral Assistant.
  - Historical conversations with pre-existing `character_id` values (from migrations 001–008) are preserved without inventing speculative personalities.
  - Deterministic legacy placeholder instances are derived via collision-resistant UUIDv5:
    `f"legacy-{uuid.uuid5(LEGACY_CHARACTER_NAMESPACE, f'{len(profile_id)}:{profile_id}:{len(legacy_character_id)}:{legacy_character_id}')}"`
- **Legacy Placeholder Security & API Listing:**
  - `GET /api/v1/characters/instances` defaults to excluding legacy placeholders (`include_legacy=False`). Explicit `include_legacy=True` includes them for the owning Profile only.
  - Legacy placeholders are rejected with HTTP 400 on `PATCH` (updates), `DELETE` (deletion), `PUT /active` (activation), and `POST /conversations` (new conversation creation).
  - SQLite database triggers `trg_character_instances_prevent_legacy_update` and `trg_character_instances_prevent_legacy_delete` enforce database-level immutability.
- **Loss-Aware Fail-Closed Downgrade Guard:**
  - Migration 009 `downgrade()` queries substantive fields of seeded `character_templates` and verifies equality against `SEED_TEMPLATES` (excluding incidental timestamp metadata).
  - Refuses downgrade with `RuntimeError` if seeded templates were modified or user instances exist, preserving user data without destruction.
- **Client SDK & API Parity:**
  - Synchronized OpenAPI 3.1 specification (`contracts/openapi/openapi.json`) across all 11 character routes.
  - Added Dart DTOs and `CompanionClient` character methods in `frontend/flutter/packages/companion_api` with verified route and schema parity.
  - Preserved React Web client conversation-creation compatibility (`frontend/web/src/services/api/conversationApi.ts`).

---

## 2. Files Changed

| File Path | Action | Description |
| :--- | :---: | :--- |
| `backend/migrations/versions/009_character_foundation.py` | ADD | Alembic migration creating `character_templates`, `character_instances`, `profile_active_characters`, triggers, indices, and fail-closed downgrade guard. |
| `backend/app/models/character.py` | ADD | SQLAlchemy 2.0 ORM models for `CharacterTemplate`, `CharacterInstance`, and `ProfileActiveCharacter`. |
| `backend/app/models/profile.py` | MODIFY | Added ORM relationships for character instances and active character mapping with cascade deletion. |
| `backend/app/models/conversation.py` | MODIFY | Integrated `character_id` foreign key relationship with `CharacterInstance`. |
| `backend/app/models/__init__.py` | MODIFY | Exported character models. |
| `backend/app/schemas/character.py` | ADD | Pydantic v2 schemas: `CharacterTraitVector`, `CharacterPresetOut`, `CharacterTemplateOut`, `CharacterInstanceCreate`, `CharacterInstanceUpdate`, `CharacterInstanceOut`, `ActiveCharacterStateOut`, `ActiveCharacterSelectRequest`. |
| `backend/app/schemas/conversation.py` | MODIFY | Made `character_id` optional in `ConversationCreate` (defaults to active character). |
| `backend/app/services/character_service.py` | ADD | Core domain service for template querying, instance CRUD, active character state, preset resolution, and legacy placeholder protection. |
| `backend/app/services/assistant/orchestrator.py` | MODIFY | Integrated runtime persona resolution into conversation turn generation (`_resolve_character_context`). |
| `backend/app/api/v1/endpoints/characters.py` | ADD | 11 REST endpoints for templates, presets, neutral fallback, instances, and active character state. |
| `backend/app/api/v1/endpoints/conversations.py` | MODIFY | Updated conversation creation to resolve active character when `character_id` is omitted. |
| `backend/app/api/v1/router.py` | MODIFY | Mounted `/characters` router under `/api/v1`. |
| `contracts/openapi/openapi.json` | MODIFY | Generated OpenAPI 3.1 specification for all 11 character endpoints and schemas. |
| `frontend/flutter/packages/companion_api/lib/dto/character_dto.dart` | ADD | Dart DTO models for character templates, presets, instances, trait vectors, and active state. |
| `frontend/flutter/packages/companion_api/lib/dto/conversation_dto.dart` | MODIFY | Made `character_id` optional in `ConversationCreate`. |
| `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` | MODIFY | Implemented 11 character REST methods with Bearer token authentication and query parameter serialization. |
| `frontend/flutter/packages/companion_api/lib/companion_api.dart` | MODIFY | Exported character DTOs. |
| `frontend/flutter/packages/companion_api/test/character_client_test.dart` | ADD | Unit tests for Dart `CompanionClient` character methods and query parameters. |
| `frontend/flutter/packages/companion_api/test/dto_test.dart` | MODIFY | Added JSON serialization/deserialization tests for character DTOs. |
| `frontend/web/src/services/api/conversationApi.ts` | MODIFY | Updated `createConversation` to support optional `characterId`. |
| `frontend/web/src/test/conversationApi.test.ts` | ADD | Vitest unit tests verifying `character_id` omission and explicit passing. |
| `scripts/check_dart_openapi_parity.py` | MODIFY | Updated route coverage assertions to verify all 11 character endpoints. |
| `backend/tests/test_character_foundation.py` | ADD | Comprehensive unit and integration tests for template querying, instance CRUD, preset precedence, and Neutral Assistant. |
| `backend/tests/test_character_authorization.py` | ADD | Cross-profile security, adversarial isolation, and legacy placeholder protection tests. |
| `backend/tests/test_migration_009.py` | ADD | Database migration tests covering schema creation, seed population, SQLite CHECK constraints, legacy triggers, and loss-aware downgrade safety. |
| `backend/tests/test_conversations.py` | MODIFY | Regression tests for active character inheritance, explicit Neutral Assistant selection, and legacy conversation compatibility. |

---

## 3. How the Logic Works

### 3.1 Character Instance Creation Pipeline
1. **Event Trigger:** Client submits `POST /api/v1/characters/instances` with `template_id`, optional `name`, `preset_id`, and `traits`.
2. **Validation & Authorization:** Authenticated `ProfileSession` is extracted from bearer token. The service verifies the `template_id` exists. If `template_id == "neutral-assistant"`, the request is rejected (Neutral Assistant cannot be instantiated).
3. **Core Processing:**
   - Evaluates preset baseline precedence:
     - If explicit non-custom preset: pulls trait baseline from `PRESET_REGISTRY[preset_id]["traits"]`.
     - If custom or omitted: pulls trait baseline from `template` traits.
     - If explicit `traits` vector provided: overrides baseline values on a per-dimension basis.
   - Generates UUIDv4 `id`, associates with `profile_id`, sets `is_legacy_placeholder = False`.
   - Persists record in `character_instances`.
4. **Completion:** Returns HTTP 201 with `CharacterInstanceOut` JSON payload.
5. **Error Handling:** If database constraints fail or foreign key is invalid, rolls back transaction and returns structured HTTP 400/404 error envelope.

### 3.2 Conversation Creation & Character Binding Pipeline
1. **Event Trigger:** Client submits `POST /api/v1/conversations`.
2. **Resolution:**
   - If `payload.character_id` is omitted: query `profile_active_characters` for the Profile's active character. If set, bind to that instance ID. If not set, bind to `"default"` (Neutral Assistant).
   - If `payload.character_id in ("default", "neutral-assistant")`: bind to `"default"` (Neutral Assistant).
   - If `payload.character_id` is a UUID: verify that the character instance exists and belongs to the authenticated profile (and is NOT a legacy placeholder).
3. **Core Processing:** Inserts conversation record with permanent `character_id`.
4. **Completion:** Returns HTTP 200 with `ConversationOut` containing the bound `character_id`.

### 3.3 Loss-Aware Migration Downgrade Protection Pipeline
1. **Event Trigger:** Developer or runner executes Alembic `downgrade -1`.
2. **Inspection:**
   - Queries `character_instances`: if user-created instances exist (`COUNT > 0`), immediately aborts with `RuntimeError`.
   - Queries `character_templates`: compares substantive attributes (`template_version`, `name`, `summary`, `lore`, `system_prompt`, `avatar_asset`, `default_preset_id`, `is_neutral_fallback`, and all 8 traits) against `SEED_TEMPLATES`.
3. **Decision Gate:** If any seeded template was altered, added, or deleted, downgrade refuses with `RuntimeError` and aborts.
4. **Completion:** If all seeded templates are pristine and zero user instances exist, drops tables, triggers, and indices safely.

---

## 4. Key Concepts

### Concept 1: Character Template vs. Instance Snapshot Isolation
A **Character Template** is an application-owned, versioned blueprint shipped with the software. A **Character Instance** is a personal snapshot owned by a specific User Profile. The instance captures lore and personality traits at the moment of creation. Subsequent updates to application templates never modify existing character instances.

### Concept 2: Immutable Neutral Assistant Fallback
The **Neutral Assistant** is a dependable, non-roleplay system assistant. Unlike ordinary companion personas, it has strictly `NULL` personality traits enforced by SQLite CHECK constraints. It cannot be edited, deleted, or instantiated into mutable snapshots. It provides a guaranteed baseline fallback if persona tuning becomes repetitive, confusing, or unwanted.

### Concept 3: Deterministic Collision-Resistant Legacy Identity
To preserve historical conversations from prior schema versions without inventing speculative personalities, the system deterministically derives a **Legacy Placeholder Instance** using UUIDv5 with length-prefixed canonical encoding (`{len(profile_id)}:{profile_id}:{len(legacy_id)}:{legacy_id}`). This eliminates cross-profile ID collisions and allows old conversations to display their historical persona name while preventing placeholders from being edited, deleted, or selected for new chats.

---

## 5. Verification Steps

### Automated Checks

All automated verification suites pass with 100% green results:

- **Backend Pytest Suite:**
  ```powershell
  .\venv\Scripts\python.exe -m pytest backend/tests -q
  ```
  *Observed Result:* `624 passed, 1 warning in 137.24s (0:02:17)`
- **Focused Character Foundation Domain Tests:**
  ```powershell
  .\venv\Scripts\python.exe -m pytest backend/tests/test_character_foundation.py backend/tests/test_character_authorization.py backend/tests/test_migration_009.py backend/tests/test_conversations.py -q
  ```
  *Observed Result:* `35 passed in 19.87s`
- **Flutter Companion API SDK Tests:**
  ```powershell
  cd frontend/flutter/packages/companion_api; flutter test
  ```
  *Observed Result:* `79 passed, 0 failed in 2.0s`
- **Flutter Desktop Application Tests:**
  ```powershell
  cd frontend/flutter/apps/desktop; flutter test
  ```
  *Observed Result:* `231 passed, 0 failed in 52.0s`
- **React Web Client Vitest Suite:**
  ```powershell
  cd frontend/web; npm test
  ```
  *Observed Result:* `248 passed across 16 test files in 11.09s`
- **OpenAPI Contract Parity:**
  ```powershell
  .\venv\Scripts\python.exe scripts/check_openapi_contract.py
  ```
  *Observed Result:* `OpenAPI contract is up-to-date (39 routes, all required model routes present).`
- **Dart OpenAPI Parity:**
  ```powershell
  .\venv\Scripts\python.exe scripts/check_dart_openapi_parity.py
  ```
  *Observed Result:* `22/22 DTOs verified, 29/18 covered routes verified, all semantic checks passed.`

### Manual / User-Owned Checks

1. **Active Character Selection via API:**
   - Execute `PUT /api/v1/characters/active` with `character_instance_id="neutral-assistant"`.
   - Verify response returns `is_neutral_active=True` and `active_instance=null`.
2. **Conversation Persona Inheritance:**
   - Start a new chat via `POST /api/v1/conversations` with `{ "title": "Test Chat" }` (omitting `character_id`).
   - Verify returned conversation has `character_id="default"`.
3. **Legacy Listing Boundary:**
   - Call `GET /api/v1/characters/instances`.
   - Verify that legacy placeholders are excluded by default, but returned when passing `?include_legacy=true`.

---

## 6. Safe Customization & Invariants

- **Eight Trait Continuous Scales:** All 8 personality traits (`warmth`, `humor`, `empathy`, `formality`, `curiosity`, `energy`, `assertiveness`, `rebelliousness`) must be integers in the range `0` to `100`.
- **Neutral Assistant Immutability:** `is_neutral_fallback = True` records must always maintain `NULL` traits. SQLite CHECK constraint `chk_character_templates_neutral_traits` enforces this at the storage level.
- **Legacy Placeholder Immutability:** Instances with `is_legacy_placeholder = True` cannot be updated or deleted. Enforced by SQLite triggers `trg_character_instances_prevent_legacy_update` and `trg_character_instances_prevent_legacy_delete`.
- **Profile Data Cascade vs. Hard Purge:** When a profile is deleted, SQLite cascade deletion automatically purges child character instances. This storage cascade is separate from application-level ordered retention purge routines.

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
| :--- | :--- | :--- |
| `HTTP 400: Cannot instantiate the Neutral Assistant as a custom instance.` | Client sent `POST /api/v1/characters/instances` with `template_id="neutral-assistant"`. | Neutral Assistant is an immutable built-in fallback. Select it via `PUT /api/v1/characters/active` instead of attempting to clone it. |
| `HTTP 400: Cannot modify a legacy character placeholder.` | Client attempted `PATCH` or `DELETE` on a legacy placeholder instance ID. | Legacy placeholders exist exclusively to anchor historical conversations. They cannot be edited or deleted. |
| `RuntimeError: Cannot safely downgrade migration 009: one or more seeded character templates have been substantively modified.` | Downgrade aborted because seeded template names, versions, prompts, or traits were altered in the database. | Restore original seeded template attributes or export user configurations before running downgrade. |
| `HTTP 404: Character instance not found.` | Client attempted to access a character instance belonging to a different Profile. | Character instances are strictly Profile-isolated. Ensure request carries the correct bearer token for the owning profile. |
