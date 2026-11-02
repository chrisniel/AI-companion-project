# Walkthrough: M3 Character Foundation — Batch A (Templates, Profile Instances & Neutral Assistant Fallback)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Document the implementation, architectural mechanisms, data models, API endpoints, client contracts, and verification evidence for AI Companion's Character Foundation (`PC-CHAR-001` and `PC-CHAR-005`).
- **Audience:** Core developers, client application engineers (Flutter Desktop & React Web), security auditors, and system maintainers.
- **Status:** Implemented & Verified (Implementation Gate independently approved; Windows Desktop Profile access manually confirmed; hosted CI Run #114 passed 100% on commit `6b4f55e`; closure reconciled; PR #29 ready for final verification).
- **Last Updated:** 2026-11-02

---

## 1. What Was Delivered

- **Application-Owned Character Templates:** Immutable, versioned (`template_version >= 1`) definitions seeded in Alembic Migration 009 (`character_templates` table). Seeded templates: `neutral-assistant`, `warm-companion`, `playful-companion`, and `formal-advisor`.
- **Profile-Owned Character Instances:** Snapshot configurations instantiated from templates (`character_instances` table), tied to an authenticated `profile_id` with `ON DELETE CASCADE`. Instances store custom persona names, summaries, lore, system prompts, avatar assets, preset references, and 8 continuous personality trait values. Updating or versioning a template never mutates existing instances.
- **Immutable Neutral Assistant Fallback:** Built-in unalterable fallback (`is_neutral_fallback = True`, all traits strictly `NULL` via SQLite CHECK constraints). Accessible via `GET /api/v1/characters/neutral`, and activated via `PUT /api/v1/characters/active` (`character_id = "default"` or `"neutral-assistant"`) or `POST /api/v1/characters/active/reset-neutral`.
- **Personality Presets & Initialization Precedence:** Catalog of 8 approved presets (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`). In `create_character_instance`:
  1. Explicit non-custom preset initializes traits from preset baseline.
  2. Custom or omitted preset initializes traits from template baseline.
  3. Explicit trait vector overrides baseline values (requires a complete 8-dimensional `CharacterTraitVector`; partial trait vectors are rejected by Pydantic validation).
- **Eight Continuous Personality Dimensions:** Persisted as integers from 0 to 100: `warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`.
- **Permanent Conversation Identity & Legacy Preservation:**
  - Conversations permanently bind to `character_id` and `character_instance_id`.
  - Creating a conversation without specifying `character_id` defaults to the Profile's active character instance (or `"default"` with `character_instance_id = NULL` when no character is active).
  - Explicit `"default"` or `"neutral-assistant"` selects Neutral Assistant (`character_instance_id = NULL`) while preserving the explicitly supplied `character_id` string.
  - Historical conversations with pre-existing `character_id` values (from migrations 001–008) are preserved without inventing speculative personalities.
  - Deterministic legacy placeholder instances are derived via collision-resistant UUIDv5 with pipe-delimited length prefixing:
    ```python
    canonical = f"{len(profile_id)}:{profile_id}|{len(legacy_character_id)}:{legacy_character_id}"
    instance_id = f"legacy-{uuid.uuid5(LEGACY_CHARACTER_NAMESPACE, canonical)}"
    ```
- **Legacy Placeholder Security & Database Protections:**
  - `GET /api/v1/characters/instances` defaults to excluding legacy placeholders (`include_legacy=False`). Explicit `include_legacy=True` includes them for the owning Profile only.
  - Legacy placeholders are rejected with HTTP 400 on `PATCH` (`"Cannot modify a legacy conversation placeholder"`), `DELETE` (`"Cannot delete a legacy conversation placeholder"`), `PUT /active` (`"Cannot activate a legacy conversation placeholder"`), and `POST /conversations` (`"Cannot start a new conversation with a legacy conversation placeholder"`).
  - SQLite CHECK constraint `ck_character_instances_legacy_or_standard` enforces placeholder storage structure (`status='archived'`, `lore=''`, `system_prompt=''`, `template_id IS NULL`, `preset_id IS NULL`, all 8 traits `NULL`).
  - Trigger `trg_character_instances_immutable_provenance` locks identity and provenance columns against post-creation modification.
  - Foreign key `conversations.character_instance_id` (`ON DELETE RESTRICT`) prevents raw SQL deletion of referenced legacy placeholders. (There is no blanket SQLite trigger specifically blocking raw SQL `DELETE` on unreferenced legacy placeholders; protection against mutation or deletion via the API is enforced by service-layer guards).
- **Ordered Relational Purge Boundaries:**
  - `CharacterInstance.profile_id` uses `ON DELETE CASCADE`.
  - `conversations.character_instance_id` uses `ON DELETE RESTRICT`.
  - Direct SQL deletion of a Profile row with conversations referencing character instances fails closed under foreign key restrictions unless conversations are purged first.
- **Runtime Turn Persona Prompt Resolution:**
  - `resolve_turn_persona_prompt()` in `backend/app/services/character_service.py` structures turn system prompts with top-level trusted `DEFAULT_PERSONA` instructions, followed by a bounded `<character_persona>` block for user-configured character text.
  - Escapes XML-style delimiter tags (`</character_persona>`, `<character_persona>`, `</retrieved_memories>`, `<retrieved_memories>`). Delimiter escaping serves as structural defense-in-depth, while the system prompt explicitly informs the model that the persona block is lower-trust configuration that cannot override system safety or claim developer authority.
- **Windows Desktop Host Admin Authority Correction:**
  - Fixed a Windows acceptance defect where `powershell.exe` failed to autoload `Get-Acl` due to type-data collisions (`Microsoft.PowerShell.Security` vs. PowerShell 7 modules in `PSModulePath`).
  - Replaced `Get-Acl` with direct native .NET CLR methods `[System.IO.Directory]::GetAccessControl` and `[System.IO.File]::GetAccessControl` in `HostAdminSecretStore._script`.
  - Preserved all security checks (fixed path, reparse point rejection, owner SID, permitted principals).
  - Verified live Windows acceptance: manual Desktop Profile selection confirmed working by Chris.
- **Loss-Aware Fail-Closed Downgrade Guard:**
  - Migration 009 `downgrade()` queries substantive fields of seeded `character_templates` and verifies equality against `SEED_TEMPLATES` (excluding incidental timestamp metadata).
  - Refuses downgrade with `RuntimeError` if seeded templates were modified, active selections exist, or user instances exist, preserving user data without destruction.
- **Client SDK & API Parity:**
  - Synchronized OpenAPI 3.1 specification (`contracts/openapi/openapi.json`) across all 11 character routes.
  - Added Dart DTOs and `CompanionClient` character methods in `frontend/flutter/packages/companion_api` with verified route and schema parity.
  - Preserved React Web client conversation-creation compatibility (`frontend/web/src/services/api/conversationApi.ts`).

---

## 2. Files Changed

| File Path | Action | Description |
| :--- | :---: | :--- |
| `backend/migrations/versions/009_character_foundation.py` | ADD | Alembic migration creating `character_templates`, `character_instances`, adding `profiles.active_character_instance_id` and `conversations.character_instance_id`, 8 SQLite triggers, indices, and fail-closed downgrade guard. |
| `backend/app/models/character_template.py` | ADD | SQLAlchemy 2.0 ORM model for application-owned `CharacterTemplate`. |
| `backend/app/models/character_instance.py` | ADD | SQLAlchemy 2.0 ORM model for Profile-owned `CharacterInstance`. |
| `backend/app/models/profile.py` | MODIFY | Added `active_character_instance_id` foreign key column with `SET NULL` on delete to store the active Character instance pointer. |
| `backend/app/models/conversation.py` | MODIFY | Added `character_instance_id` foreign key column with `RESTRICT` on delete to bind each conversation thread to a Character instance. |
| `backend/app/models/__init__.py` | MODIFY | Exported character models. |
| `backend/app/schemas/character.py` | ADD | Pydantic v2 schemas: `CharacterTraitVector`, `CharacterPresetOut`, `CharacterTemplateOut`, `CharacterInstanceCreate`, `CharacterInstanceUpdate`, `CharacterInstanceOut`, `ActiveCharacterStateOut`, `ActiveCharacterSelectRequest`. |
| `backend/app/schemas/conversation.py` | MODIFY | Made `character_id` optional in `ConversationCreate` (defaults to active character). |
| `backend/app/services/character_service.py` | ADD | Core domain service for template querying, instance CRUD, active character state, preset resolution, legacy placeholder protection, and `resolve_turn_persona_prompt()`. |
| `backend/app/services/assistant/orchestrator.py` | MODIFY | Integrated runtime persona resolution into conversation turn generation (`resolve_turn_persona_prompt`). |
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
| `frontend/flutter/apps/desktop/lib/platform/host_admin_secret_store.dart` | MODIFY | Replaced PowerShell `Get-Acl` with native CLR `[System.IO.Directory]::GetAccessControl` and `[System.IO.File]::GetAccessControl`, with sanitized debug logging. |
| `frontend/flutter/apps/desktop/lib/features/profiles/desktop_profile_controller.dart` | MODIFY | Added sanitized debug logging to `refresh()` exception handling. |
| `frontend/flutter/apps/desktop/test/host_admin_secret_store_test.dart` | MODIFY | Added CLR access-control script assertions and live Windows execution tests. |
| `frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart` | MODIFY | Added `discoverRuntimeProcesses` override to `FakeSupervisor` to isolate supervisor tests from host processes on port 8000. |
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
2. **Validation & Authorization:** Authenticated `ProfileSession` is validated from the bearer token. The service verifies the `template_id` exists. If `template_id in ("neutral-assistant", "default")`, the request is rejected (Neutral Assistant cannot be instantiated).
3. **Core Processing:**
   - Evaluates preset baseline precedence:
     - If explicit non-custom preset: pulls trait baseline from `PRESET_REGISTRY[preset_id]["traits"]`.
     - If custom or omitted: pulls trait baseline from `template` traits.
     - If explicit `traits` vector provided: caller supplies a complete 8-dimensional `CharacterTraitVector` that overrides the baseline values (partial trait vectors are rejected by Pydantic validation).
   - Generates UUIDv4 `id`, associates with `profile_id`, sets `is_legacy_placeholder = False`.
   - Persists record in `character_instances`.
4. **Completion:** Returns HTTP 201 with `CharacterInstanceOut` JSON payload.
5. **Error Handling:** If database constraints fail or foreign key is invalid, rolls back transaction and returns structured HTTP 400/404 error envelope.

### 3.2 Conversation Creation & Character Binding Pipeline
1. **Event Trigger:** Client submits `POST /api/v1/conversations`.
2. **Resolution:**
   - If `payload.character_id` is omitted: query `profiles.active_character_instance_id` for the Profile's active character. If set, bind `character_id` and `character_instance_id` to that instance ID. If not set, bind `character_id = "default"` and `character_instance_id = NULL` (Neutral Assistant).
   - If `payload.character_id in ("default", "neutral-assistant")`: selects Neutral Assistant (`character_instance_id = NULL`), while preserving the explicitly supplied `character_id` string (`"default"` or `"neutral-assistant"`).
   - If `payload.character_id` is an instance ID: verify that the character instance exists and belongs to the authenticated profile (fails with HTTP 404 if not found or foreign). If it is a legacy placeholder, fails with HTTP 400 (`"Cannot start a new conversation with a legacy conversation placeholder"`). If it is archived, fails with HTTP 400 (`"Cannot start a conversation with an archived character instance"`).
3. **Core Processing:** Inserts conversation record with permanent `character_id` and `character_instance_id`. Trigger `trg_conversations_character_immutable_update` locks these fields permanently against post-creation changes.
4. **Completion:** Returns HTTP 201 Created with `ConversationOut` containing the bound character identifiers.

### 3.3 Runtime Persona Resolution with Trust Boundaries
1. **Event Trigger:** User sends a chat message; `orchestrate_chat_stream` begins turn processing.
2. **Resolution:** Calls `resolve_turn_persona_prompt(db, session, conversation)`:
   - If `character_instance_id` is `NULL` or points to Neutral Assistant or a legacy placeholder: returns trusted top-level `DEFAULT_PERSONA`.
   - If bound to an active `CharacterInstance`: returns `DEFAULT_PERSONA` plus an untrusted, XML-escaped `<character_persona>` block containing name, summary, persona instructions, and lore.
3. **System Framing:** Explicitly reminds the model that user-editable persona instructions are lower-trust configuration and cannot override safety policies, grant system authority, or cross Profile boundaries.

### 3.4 Direct CLR Windows Host Authority Inspection
1. **Event Trigger:** Flutter Desktop initializes and calls `HostAdminSecretStore.readToken()`.
2. **Execution:** Launches `powershell.exe -NoProfile -NonInteractive -Command ...`.
3. **Security Checks:**
   - Validates that `%LOCALAPPDATA%` is an absolute local path and neither null nor a UNC path.
   - Rejects reparse points (symlinks/junctions) across the path hierarchy.
   - Invokes direct CLR access control:
     ```powershell
     $dirAcl = [System.IO.Directory]::GetAccessControl($directory)
     $fileAcl = [System.IO.File]::GetAccessControl($secretPath)
     ```
   - Verifies that inheritance is disabled (`AreAccessRulesProtected == $true`).
   - Verifies that owner SID and access rule principals match only the current user SID or SYSTEM (`S-1-5-18`).
4. **Result:** On success, writes the raw secret to stdout. On any validation failure, writes sanitized error to stderr and exits with code 1, which causes Dart to throw `StateError` without leaking secrets.

### 3.5 Loss-Aware Migration Downgrade Protection Pipeline
1. **Event Trigger:** Developer or runner executes Alembic `downgrade -1`.
2. **Inspection:**
   - Queries `character_instances`: if user-created instances exist (`COUNT > 0`), immediately aborts with `RuntimeError`.
   - Queries `profiles`: if any profile has an active character selection, aborts with `RuntimeError`.
   - Queries `character_templates`: compares substantive attributes (`template_version`, `name`, `summary`, `lore`, `system_prompt`, `avatar_asset`, `default_preset_id`, `is_neutral_fallback`, and all 8 traits) against `SEED_TEMPLATES`.
3. **Decision Gate:** If any seeded template was altered, added, or deleted, downgrade refuses with `RuntimeError` and aborts.
4. **Completion:** If all seeded templates are pristine and zero user instances or active selections exist, drops tables, triggers, and indices safely.

---

## 4. Key Concepts

### Concept 1: Character Template vs. Instance Snapshot Isolation
A **Character Template** is an application-owned, versioned blueprint shipped with the software. A **Character Instance** is a personal snapshot owned by a specific User Profile. The instance captures lore and personality traits at the moment of creation. Subsequent updates to application templates never modify existing character instances.

### Concept 2: Immutable Neutral Assistant Fallback
The **Neutral Assistant** is a dependable, non-roleplay system assistant. Unlike ordinary companion personas, it has strictly `NULL` personality traits enforced by SQLite CHECK constraints. It cannot be edited, deleted, or instantiated into mutable snapshots. It provides a guaranteed baseline fallback if persona tuning becomes repetitive, confusing, or unwanted.

### Concept 3: Deterministic Collision-Resistant Legacy Identity
To preserve historical conversations from prior schema versions without inventing speculative personalities, the system deterministically derives a **Legacy Placeholder Instance** using UUIDv5 with pipe-delimited length prefixing (`canonical = f"{len(profile_id)}:{profile_id}|{len(legacy_character_id)}:{legacy_character_id}"`). This eliminates cross-profile ID collisions and allows old conversations to display their historical persona name while preventing placeholders from being edited, deleted, or selected for new chats.

### Concept 4: Direct CLR Access Control vs. Cmdlet Module Autoloading
PowerShell cmdlets such as `Get-Acl` reside in binary modules (`Microsoft.PowerShell.Security`) that are autoloaded on demand. In environments where modern PowerShell versions (e.g. PowerShell 7) add module directories to `PSModulePath`, Windows PowerShell 5.1 can experience extended type-data collisions during module import. Utilizing direct .NET Framework CLR methods (`System.IO.Directory::GetAccessControl` and `System.IO.File::GetAccessControl`) circumvents PowerShell module loading entirely while executing against identical Win32 security APIs.

---

## 5. Verification Steps

### Automated Checks

All automated verification suites pass with 100% green results:

- **Backend Pytest Suite:**
  ```powershell
  .\venv\Scripts\python.exe -m pytest backend/tests -q
  ```
  *Observed Result:* `624 passed, 1 existing deprecation warning in 151.76s (exit 0)`
- **Focused Character Foundation Domain Tests:**
  ```powershell
  .\venv\Scripts\python.exe -m pytest backend/tests/test_character_foundation.py backend/tests/test_character_authorization.py backend/tests/test_migration_009.py backend/tests/test_conversations.py -q
  ```
  *Observed Result:* `35 passed in 19.87s (exit 0)`
- **Flutter Companion API SDK Tests:**
  ```powershell
  cd frontend/flutter/packages/companion_api; flutter test
  ```
  *Observed Result:* `79 passed, 0 failed in 2.0s (exit 0)`
- **Flutter Desktop Application Tests:**
  ```powershell
  cd frontend/flutter/apps/desktop; flutter test
  ```
  *Observed Result:* `232 passed, 0 failed in 52.0s (exit 0)`
- **Flutter Workspace Static Analysis:**
  ```powershell
  cd frontend/flutter; dart analyze .
  ```
  *Observed Result:* `No issues found! (exit 0)`
- **React Web Client Vitest Suite:**
  ```powershell
  cd frontend/web; npm test
  ```
  *Observed Result:* `248 passed across 16 test files in 11.09s (exit 0)`
- **OpenAPI Contract Check:**
  ```powershell
  .\venv\Scripts\python.exe scripts/check_openapi_contract.py
  ```
  *Observed Result:* `OpenAPI contract is up-to-date (exit 0)`
- **Dart OpenAPI Parity Check:**
  ```powershell
  .\venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check
  ```
  *Observed Result:* `22/22 DTOs verified, 29/18 covered route methods verified, all semantic checks passed (exit 0).`
- **Git Formatting and Whitespace:**
  ```powershell
  git diff --check
  ```
  *Observed Result:* `Clean; 0 errors (exit 0).`
- **Hosted GitHub Actions CI (PR #29, Run #114 on commit `6b4f55e`; historical Run #113 on commit `9c9bd05`):**
  *Observed Result:* `7 / 7 jobs succeeded on both runs (Path Classification, Flutter Desktop, Contract, Backend, Frontend, Docs Integrity, CI Gate: all green). Note: CI Docs Integrity step specifically executes git diff --check on Markdown files and verifies presence of canonical files (SYSTEM_BASELINE.md, AGENTS.md, DOCUMENTATION_MAP.md); it does not run markdownlint, frontmatter parsing, or link crawlers.`

### Manual / User-Owned Checks

1. **Active Character Selection via API:**
   - Execute `PUT /api/v1/characters/active` with `{"character_id": "neutral-assistant"}`.
   - Verify response returns `is_neutral_fallback = true` and `active_instance = null`.
2. **Conversation Persona Inheritance:**
   - Start a new chat via `POST /api/v1/conversations` with `{ "title": "Test Chat" }` (omitting `character_id`).
   - Verify returned conversation has `character_id = "default"` and `character_instance_id = null`.
3. **Legacy Listing Boundary:**
   - Call `GET /api/v1/characters/instances`.
   - Verify that legacy placeholders are excluded by default, but returned when passing `?include_legacy=true`.
4. **Windows Desktop Profile Access Acceptance:**
   - Launch Windows Flutter Desktop application alongside local Python runtime.
   - Navigate to Settings → Profile Access.
   - Verify that Default Profile appears in the selector and `"Use Profile"` activates successfully.
   - Verified manually by Chris on 2026-11-02.

---

## 6. Safe Customization & Invariants

- **Eight Trait Continuous Scales:** All 8 personality traits (`warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`) must be integers in the range `0` to `100`.
- **Neutral Assistant Immutability:** `is_neutral_fallback = True` records must always maintain `NULL` traits. SQLite CHECK constraint `ck_character_templates_neutral_invariants` enforces this at the storage level, and triggers `trg_character_templates_protect_neutral_update` and `trg_character_templates_protect_neutral_delete` reject mutations.
- **Legacy Placeholder Database Protections & Immutability:** Instances with `is_legacy_placeholder = True` cannot be updated, deleted, activated, or assigned to new conversations via the API (enforced by service-layer guards). In the database, SQLite CHECK constraint `ck_character_instances_legacy_or_standard` constrains placeholder rows to `status='archived'`, `lore=''`, `system_prompt=''`, `template_id IS NULL`, `preset_id IS NULL`, and all 8 traits `NULL`. Trigger `trg_character_instances_immutable_provenance` locks identity and provenance columns against post-creation changes. Referenced placeholders are protected against raw SQL deletion by foreign key `conversations.character_instance_id` (`ON DELETE RESTRICT`). There is no blanket SQLite trigger specifically blocking raw SQL `DELETE` on unreferenced legacy placeholders.
- **Profile Data Cascade vs. Hard Purge:** When a profile is deleted, SQLite cascade deletion automatically purges child character instances. However, because `conversations.character_instance_id` uses `ON DELETE RESTRICT`, direct deletion of a profile with bound conversations is blocked by foreign key constraints. Application-level hard-purge routines must purge conversations before deleting character instances.
- **Multimodal Attachments Status:** Image attachment backend and React Web interfaces are implemented; Flutter Desktop image-upload button remains disabled/planned, and vision processing depends on a compatible vision-enabled model.

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
| :--- | :--- | :--- |
| `HTTP 422: Neutral Assistant fallback is immutable and cannot be instantiated as an editable instance.` | Client sent `POST /api/v1/characters/instances` with `template_id="neutral-assistant"` or `"default"`. | Neutral Assistant is an immutable built-in fallback. Select it via `PUT /api/v1/characters/active` instead of attempting to instantiate it. |
| `HTTP 400: Cannot modify a legacy conversation placeholder.` / `Cannot delete a legacy conversation placeholder.` | Client attempted `PATCH` or `DELETE` on a legacy placeholder instance ID. | Legacy placeholders exist exclusively to anchor historical conversations. They cannot be edited or deleted via the API. |
| `RuntimeError: Cannot safely downgrade migration 009: one or more seeded character templates have been substantively modified.` | Downgrade aborted because seeded template names, versions, prompts, or traits were altered in the database. | Restore original seeded template attributes or export user configurations before running downgrade. |
| `HTTP 404: Character instance not found.` | Client attempted to access a character instance belonging to a different Profile. | Character instances are strictly Profile-isolated. Ensure request carries the correct bearer token for the owning profile. |
| `"Local Profile authority is unavailable. Check the trusted Windows host runtime."` | Desktop `HostAdminSecretStore` failed ACL inspection or could not find `desktop_admin.secret`. | Ensure runtime is operational, `%LOCALAPPDATA%\AICompanion\secrets\desktop_admin.secret` exists with inheritance disabled, and owner matches the active user SID or SYSTEM. |
