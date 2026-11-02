# Implementation Plan: M3 Character Foundation — Batch A (Character Templates, Profile-Owned Instances & Neutral Assistant Fallback)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Awaiting Approval — Plan Gate Review Pending
- **Date:** 2026-11-02
- **Author:** AI Agent
- **Branch:** `feature/m3-character-foundation-a` (branched from `develop` @ `0bb0894998da32bfd5208f9df178683280a4e06e`)
- **WBS Mapping:** `PC-CHAR-001` (Character template vs. profile-owned character instance model) & `PC-CHAR-005` (Neutral Assistant fallback)
- **Scope Mode:** New Feature — Character Foundation Schema, Migration 009, Service/API Contracts, Conversation Persona Binding, Neutral Assistant Fallback & Cross-Profile Adversarial Isolation Tests
- **Target Files:**
  - `backend/migrations/versions/009_character_foundation.py` (`[ADD]`)
  - `backend/app/models/character_template.py` (`[ADD]`)
  - `backend/app/models/character_instance.py` (`[ADD]`)
  - `backend/app/models/profile.py` (`[MODIFY]`)
  - `backend/app/models/conversation.py` (`[MODIFY]`)
  - `backend/app/models/__init__.py` (`[MODIFY]`)
  - `backend/app/schemas/character.py` (`[ADD]`)
  - `backend/app/schemas/conversation.py` (`[MODIFY]`)
  - `backend/app/services/character_service.py` (`[ADD]`)
  - `backend/app/services/assistant/orchestrator.py` (`[MODIFY]`)
  - `backend/app/services/retention.py` (`[MODIFY]`)
  - `backend/app/api/v1/endpoints/characters.py` (`[ADD]`)
  - `backend/app/api/v1/endpoints/conversations.py` (`[MODIFY]`)
  - `backend/app/api/v1/router.py` (`[MODIFY]`)
  - `contracts/openapi/openapi.json` (`[MODIFY]`)
  - `scripts/check_dart_openapi_parity.py` (`[MODIFY]`)
  - `frontend/flutter/packages/companion_api/lib/companion_api.dart` (`[MODIFY]`)
  - `frontend/flutter/packages/companion_api/lib/dto/character_dto.dart` (`[ADD]`)
  - `frontend/flutter/packages/companion_api/lib/dto/conversation_dto.dart` (`[MODIFY]`)
  - `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` (`[MODIFY]`)
  - `frontend/flutter/packages/companion_api/test/dto_test.dart` (`[MODIFY]`)
  - `frontend/flutter/packages/companion_api/test/companion_client_test.dart` (`[MODIFY]`)
  - `backend/tests/test_migration_008.py` (`[MODIFY]`)
  - `backend/tests/test_migration_009.py` (`[ADD]`)
  - `backend/tests/test_character_foundation.py` (`[ADD]`)
  - `backend/tests/test_character_authorization.py` (`[ADD]`)
  - `backend/tests/test_conversations.py` (`[MODIFY]`)

---

## 1. Request Understanding & Goals

### Primary Objective

Establish the canonical **Character Foundation (`PC-CHAR-001` & `PC-CHAR-005`)** for AI Companion in alignment with [`ADR-0012`](../../04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md), [`ADR-0018`](../../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md), [`characters-personality-and-emotion.md`](../../04_Architecture/01_Domains/characters-personality-and-emotion.md), [`assistant-and-conversations.md`](../../04_Architecture/01_Domains/assistant-and-conversations.md), and [`03_Character_Studio_and_Personality.md`](../../05_Design/03_Character_Studio_and_Personality.md):

1. **Application-Owned Immutable/Versioned Character Templates (`CharacterTemplate`):**
   - Packaged, read-only definitions (`template_version >= 1`) owned by the application (`character_templates` table; no `profile_id`).
   - Includes the built-in immutable **Neutral Assistant** template (`id = "neutral-assistant"`, `is_neutral_fallback = True`) and starter companion templates seeded deterministically in Migration 009.
2. **Profile-Owned Mutable Character Instances (`CharacterInstance`):**
   - Explicitly owned by a single authenticated `Profile` (`profile_id NOT NULL`, `ForeignKey("profiles.id", ondelete="CASCADE")`, no implicit `"default"` `server_default` on `character_instances.profile_id`).
   - Initialized by copying a snapshot of fields from a `CharacterTemplate` (and optional preset baseline) at creation time (`template_id` and `source_template_version` recorded strictly as provenance metadata, never a live binding).
   - **Snapshot Isolation Guarantee:** Updating or bumping `template_version` on a `CharacterTemplate` **never** rewrites, mutates, or alters any existing `CharacterInstance`.
3. **Immutable Neutral Assistant Fallback (`PC-CHAR-005`):**
   - A dependable, immutable system fallback (`"neutral-assistant"`, with `"default"` preserved as the canonical compatibility alias on `conversations.character_id`), **not** an arbitrary editable user persona or mutable `CharacterInstance`.
   - Enforces [`characters-personality-and-emotion.md` §2.1.6](../../04_Architecture/01_Domains/characters-personality-and-emotion.md): Neutral Assistant does **not** hardcode all 8 personality traits to `50` (`NULL` trait columns enforced by SQLite `CHECK` constraint on `character_templates` when `is_neutral_fallback = 1`), strips custom roleplay lore cards (`lore = ""`), and resolves deterministically to the immutable objective system assistant prompt.
   - Provides a first-class **Reset to Neutral Assistant** operation (`POST /api/v1/characters/active/reset-neutral` and `PUT /api/v1/characters/active`) that safely switches the Profile's active persona selection to Neutral Assistant for future conversations without deleting or altering any `CharacterInstance` or existing `Conversation`.
4. **Permanent Conversation-to-Character Association & Safe Character Switching:**
   - Every `Conversation` remains permanently bound to its established Character identity (`character_id` and optional `character_instance_id`) from creation onward.
   - Switching a Profile's active character (or resetting to Neutral Assistant) affects **future** conversations only and **never** retroactively reattributes existing conversations or message history.
   - Archiving or soft-deleting a `CharacterInstance` clears `profiles.active_character_instance_id` back to Neutral Assistant (`NULL`) if that instance was active, while preserving the archived/soft-deleted instance row (`ON DELETE RESTRICT` on `conversations.character_instance_id`) so historical conversations retain valid persona provenance.
5. **Preserve the 8 Personality Traits & 8 Approved Presets Without Premature Engine Expansion:**
   - Persist and validate the eight continuous `0..100` integer trait columns (`warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`) and the eight frozen preset identifiers (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`) across schema, presets catalog, templates, instances, and API/Dart DTOs.
   - Do **not** implement the full dynamic 8-trait prompt-modulation engine (`PC-CHAR-002`) in this batch; `orchestrate_chat_stream` resolves either the immutable Neutral Assistant prompt or the bound `CharacterInstance`'s static snapshot persona (`system_prompt` + sanitized `lore`).

### Concrete Deliverables

1. **Alembic Migration `009_character_foundation.py` (`down_revision = "008_profile_sessions_and_tickets"`):**
   - Pre-flight `PRAGMA foreign_key_check` verification and pre-migration snapshot hook integration in `prepare_database_schema`.
   - `character_templates` table with composite `CHECK` constraints, partial unique index `uq_character_templates_single_neutral` ensuring at most one `is_neutral_fallback = 1` row (`id = 'neutral-assistant'`), SQLite triggers blocking `UPDATE`/`DELETE` of the immutable `neutral-assistant` row, and deterministic seed rows (`neutral-assistant`, `warm-companion`, `playful-companion`, `formal-advisor`).
   - `character_instances` table with mandatory `profile_id` (`NOT NULL`, no `server_default`), `template_id` (`ON DELETE RESTRICT`), `source_template_version`, 8 integer trait columns (`0..100` `CHECK` constraints), `preset_id` validation, `status` (`'active' | 'archived'`), `is_deleted`, `deleted_at`, `UNIQUE (id, profile_id)`, and `CHECK (id NOT IN ('default', 'neutral-assistant'))`.
   - Batch-alter `profiles` to add `active_character_instance_id` (`String(64), nullable=True, ForeignKey("character_instances.id", ondelete="SET NULL")`), where `NULL` represents the immutable Neutral Assistant fallback.
   - Batch-alter `conversations` to add `character_instance_id` (`String(64), nullable=True, ForeignKey("character_instances.id", ondelete="RESTRICT")`) while preserving existing `character_id` (`String(64), nullable=False, default="default"`), FTS5 indices/triggers, and all historical rows.
   - **Legacy Non-Default `character_id` Backfill:** During upgrade from `008`, any existing `conversations` row whose `character_id` is not `'default'` or `'neutral-assistant'` automatically materializes a deterministic Profile-owned legacy snapshot in `character_instances` (seeded from `warm-companion` v1 provenance with the legacy `character_id` preserved for its owning `profile_id`, or a deterministic per-profile instance ID if shared across multiple profiles) and links `conversations.character_instance_id` so 100% of historical conversations remain valid.
   - **Defense-in-Depth SQLite Triggers:**
     - Prevent cross-Profile assignment on `profiles.active_character_instance_id` and require the referenced `character_instances` row to be active and non-deleted.
     - Automatically reset `profiles.active_character_instance_id = NULL` when a `character_instances` row is archived (`status = 'archived'`) or soft-deleted (`is_deleted = 1`).
     - Enforce same-Profile ownership between `conversations.profile_id` and `conversations.character_instance_id`, and enforce immutability of `(character_id, character_instance_id, profile_id)` on `conversations` after `INSERT`.
2. **SQLAlchemy Models, Pydantic Schemas, Service Layer & FastAPI Endpoints:**
   - `CharacterTemplate` and `CharacterInstance` models registered in `backend/app/models/__init__.py`.
   - `backend/app/services/character_service.py` implementing template catalog queries, frozen 8-preset registry, snapshot creation from template/preset, instance mutation, safe archive/soft-delete, active character selection, reset-to-neutral fallback, conversation character binding resolution, and turn persona prompt resolution.
   - `backend/app/api/v1/endpoints/characters.py` mounted under `protected_router` (requiring `Depends(get_current_profile_session)` on every route).
   - Updated `POST /api/v1/conversations` and `orchestrate_chat_stream` to validate and permanently bind character ownership and resolve the conversation's bound persona prompt on every turn.
3. **OpenAPI & Dart `companion_api` Contract Parity:**
   - Updated `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `frontend/flutter/packages/companion_api/lib/dto/character_dto.dart`, `conversation_dto.dart`, and `companion_client.dart` with full unit test coverage.
4. **Comprehensive Migration, Functional & Adversarial Isolation Tests:**
   - `backend/tests/test_migration_009.py`, `backend/tests/test_character_foundation.py`, `backend/tests/test_character_authorization.py`, and updated `test_migration_008.py` / `test_conversations.py`.

### Explicit Out-of-Scope Boundaries (What Not To Touch)

- **No Full Dynamic Personality Trait Engine (`PC-CHAR-002`):** Trait sliders (`0..100`) and presets are stored, validated, and returned in schemas/DTOs, but dynamic per-trait prompt synthesis/modulation is deferred to `PC-CHAR-002`.
- **No Persistent Mood / Emotion Engine (`PC-CHAR-003` / `PC-CHAR-004`):** Do not add `mood_states` tables, decay schedulers, or emotional turn classifiers.
- **No Advanced Relationship State or Presence (`PC Later`):** Do not implement familiarity tiers, affinity scores, or proactive presence.
- **No Full Character Studio UI (`PC-CLIENT-007`):** Do not replace the truthful preview banner in `frontend/web/src/components/workspace/CharactersView.tsx` or build the full Flutter Character Studio UI screen (`studio_screen.dart`) in this batch; `phase8b3Truthfulness.test.tsx` must continue passing unchanged.
- **No Voice Integration (`PC-VOICE-*`):** Do not add voice synthesis or ASR bindings to characters.
- **No Unrelated M2 Host Work or Auth Changes:** Do not alter existing Profile ownership or `ProfileSession` authorization rules established in M2 Batches A and B.

---

## 2. Current Findings & Technical Root Cause

| File / Symbol | Verified Current State | Technical Finding / Requirement for Batch A |
| :--- | :--- | :--- |
| [`backend/app/models/conversation.py`](../../../backend/app/models/conversation.py#L31-L33) | `Conversation.character_id` is ` Mapped[str] = mapped_column(String(64), default="default", nullable=False, index=True)`. No `character_instance_id` FK exists. | Retain `character_id` (`default="default"`) for backward compatibility with M1/M2 clients and historical rows, and add nullable `character_instance_id` (`ForeignKey("character_instances.id", ondelete="RESTRICT")`). When `character_instance_id IS NULL`, `character_id` is `"default"` or `"neutral-assistant"` (the immutable Neutral Assistant fallback). |
| [`backend/app/models/profile.py`](../../../backend/app/models/profile.py#L14-L39) | `Profile` has `id`, `display_name`, `status`, `is_default`, `created_at`, `updated_at`, `archived_at`. | Add `active_character_instance_id: Mapped[Optional[str]] = mapped_column(String(64), ForeignKey("character_instances.id", ondelete="SET NULL"), nullable=True, index=True)`. `NULL` means the Profile's active persona is the immutable Neutral Assistant fallback. |
| [`backend/app/services/assistant/orchestrator.py`](../../../backend/app/services/assistant/orchestrator.py#L29-L36) | Hardcodes `DEFAULT_PERSONA` and passes `system_prompt=DEFAULT_PERSONA` into `build_chat_messages(...)` without inspecting `conversation.character_id` or `conversation.character_instance_id`. | Must resolve the conversation's permanently bound persona via `character_service.resolve_turn_persona_prompt(db, profile_session, conversation)` after `verify_active_profile_session`, returning the immutable Neutral Assistant prompt when bound to `"default"`/`"neutral-assistant"`, or the bound `CharacterInstance`'s snapshot prompt + sanitized lore while enforcing same-Profile ownership. |
| [`backend/app/api/v1/endpoints/conversations.py`](../../../backend/app/api/v1/endpoints/conversations.py#L32-L50) | `create_conversation` accepts arbitrary `payload.character_id` strings (`default="default"`) without checking whether the character exists or belongs to `session.profile_id`. | Must resolve `payload.character_id` through `character_service.resolve_conversation_character(db, session, payload.character_id)`:<ul><li>If `"default"` or `"neutral-assistant"`: bind to Neutral Assistant (`character_id="default"` or `"neutral-assistant"`, `character_instance_id=None`).</li><li>If omitted or empty: bind to the Profile's active character (`profile.active_character_instance_id` if set and active, else `"default"`).</li><li>If a non-neutral ID: verify an active, non-deleted `CharacterInstance` owned by `session.profile_id` exists (`character_id=instance.id`, `character_instance_id=instance.id`); otherwise fail closed with `404 Not Found`.</li></ul> |
| [`backend/tests/test_conversations.py`](../../../backend/tests/test_conversations.py#L36-L46) | `test_create_conversation` posts `{"title": "Test Chat", "character_id": "companion-1"}` without creating a `CharacterInstance` first. | Once `POST /api/v1/conversations` validates non-neutral `character_id` against Profile-owned `CharacterInstance` rows, `test_conversations.py` must instantiate an owned `CharacterInstance` for positive binding and add a negative test verifying unknown/foreign `character_id` returns `404`. |
| [`backend/tests/test_migration_008.py`](../../../backend/tests/test_migration_008.py#L51-L58) | Fixture `migrated` runs `command.upgrade(config(path), "head")` and `test_upgrade_creates_tables_and_columns` asserts `alembic_version == "008_profile_sessions_and_tickets"`. | Same pattern as `test_migration_007.py`: when Migration `009_character_foundation` becomes the new Alembic `head`, `test_migration_008.py` line 55 must target `REVISION` (`"008_profile_sessions_and_tickets"`) so `test_migration_008.py` tests migration 008 deterministically while `test_migration_009.py` tests `head` (`009_character_foundation`). |
| [`backend/app/db/session.py`](../../../backend/app/db/session.py#L97-L116) | `prepare_database_schema` triggers pre-migration WAL backup when upgrading pre-008 schemas (`current_rev != "008_profile_sessions_and_tickets"`). | Update `target_head_rev` in `prepare_database_schema` to `"009_character_foundation"` (with label `"pre_m3_009_upgrade"`) so any populated database upgrading to `009` automatically creates a timestamped backup before applying schema changes. |
| [`scripts/check_dart_openapi_parity.py`](../../../scripts/check_dart_openapi_parity.py#L39-L97) | Enforces that every path/method in `contracts/openapi/openapi.json` is mapped in `CompanionClient` and every DTO schema matches Dart field sets 1-to-1. | Register all `/api/v1/characters/*` routes and character DTO schemas in `check_dart_openapi_parity.py` and `frontend/flutter/packages/companion_api` so OpenAPI and Dart parity checks pass with zero drift. |

---

## 3. Proposed File Changes & In-Place Logic

### 3.1 Schema & Migration Design (`009_character_foundation.py`)

#### `[ADD]` [`backend/migrations/versions/009_character_foundation.py`](../../../backend/migrations/versions/009_character_foundation.py)

- **Revision Identifiers:**
  - `revision = "009_character_foundation"`
  - `down_revision = "008_profile_sessions_and_tickets"`
- **Eight Frozen Preset Identifiers (`ALLOWED_PRESETS`):**
  - `'custom'`, `'warm_companion'`, `'playful'`, `'formal_advisor'`, `'tsundere'`, `'kuudere'`, `'dandere'`, `'yandere'`
- **Table 1: `character_templates` (Application-Owned, Immutable/Versioned)**
  - `id`: `String(64)`, Primary Key (`'neutral-assistant'`, `'warm-companion'`, `'playful-companion'`, `'formal-advisor'`).
  - `template_version`: `Integer`, `NOT NULL`, `server_default="1"`, `CHECK (template_version >= 1)`.
  - `name`: `String(120)`, `NOT NULL`.
  - `summary`: `String(500)`, `NOT NULL`, `server_default=""`.
  - `lore`: `Text`, `NOT NULL`, `server_default=""`.
  - `system_prompt`: `Text`, `NOT NULL`.
  - `avatar_asset`: `String(255)`, ` nullable=False`, `server_default="default_avatar"`.
  - `default_preset_id`: `String(32)`, `nullable=True` (`NULL` for `neutral-assistant`; one of the 8 frozen preset IDs for standard templates).
  - `is_neutral_fallback`: `Boolean`, `NOT NULL`, `server_default=sa.text("0")`.
  - **Eight Personality Trait Columns (Nullable ONLY for `neutral-assistant`):**
    - `warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`: `Integer`, `nullable=True`.
  - `created_at`: `DateTime(timezone=True)`, `NOT NULL`.
  - `updated_at`: `DateTime(timezone=True)`, `NOT NULL`.
  - **Table Constraints & Indexes:**
    - `ck_character_templates_version_pos`: `template_version >= 1`
    - `ck_character_templates_neutral_invariants`:
      ```sql
      (
        is_neutral_fallback = 1
        AND id = 'neutral-assistant'
        AND lore = ''
        AND default_preset_id IS NULL
        AND warmth IS NULL AND teasing IS NULL AND guardedness IS NULL AND directness IS NULL
        AND expressiveness IS NULL AND affection IS NULL AND formality IS NULL AND verbosity IS NULL
      )
      OR (
        is_neutral_fallback = 0
        AND id NOT IN ('neutral-assistant', 'default')
        AND default_preset_id IN ('custom', 'warm_companion', 'playful', 'formal_advisor', 'tsundere', 'kuudere', 'dandere', 'yandere')
        AND warmth BETWEEN 0 AND 100
        AND teasing BETWEEN 0 AND 100
        AND guardedness BETWEEN 0 AND 100
        AND directness BETWEEN 0 AND 100
        AND expressiveness BETWEEN 0 AND 100
        AND affection BETWEEN 0 AND 100
        AND formality BETWEEN 0 AND 100
        AND verbosity BETWEEN 0 AND 100
      )
      ```
    - Partial unique index `uq_character_templates_single_neutral` on `character_templates(is_neutral_fallback) WHERE is_neutral_fallback = 1`.
    - SQLite triggers `trg_character_templates_protect_neutral_update` and `trg_character_templates_protect_neutral_delete` raising `ABORT` (`'immutable neutral-assistant fallback template cannot be modified or deleted'`) if any query attempts to mutate or delete `OLD.is_neutral_fallback = 1` or `OLD.id = 'neutral-assistant'`.
- **Table 2: `character_instances` (Profile-Owned Mutable Snapshots)**
  - `id`: `String(64)`, Primary Key (UUID4).
  - `profile_id`: `String(64)`, `ForeignKey("profiles.id", ondelete="CASCADE")`, `nullable=False`, indexed (**NO `server_default`** — enforces explicit Profile ownership per `ADR-0018`).
  - `template_id`: `String(64)`, `ForeignKey("character_templates.id", ondelete="RESTRICT")`, `nullable=False`, indexed.
  - `source_template_version`: `Integer`, `nullable=False`, `CHECK (source_template_version >= 1)`.
  - `name`: `String(120)`, `nullable=False`.
  - `summary`: `String(500)`, `nullable=False`, `server_default=""`.
  - `lore`: `Text`, `nullable=False`, `server_default=""`.
  - `system_prompt`: `Text`, `nullable=False`.
  - `avatar_asset`: `String(255)`, `nullable=False`, `server_default="default_avatar"`.
  - `preset_id`: `String(32)`, `nullable=False`, `server_default="custom"`.
  - **Eight Required Personality Trait Columns (`NOT NULL`, `0..100`):**
    - `warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`: `Integer`, `nullable=False`.
  - `status`: `String(32)`, `nullable=False`, `server_default="active"`.
  - `is_deleted`: `Boolean`, `nullable=False`, `server_default=sa.text("0")`, indexed.
  - `deleted_at`: `DateTime(timezone=True)`, `nullable=True`.
  - `created_at`: `DateTime(timezone=True)`, `nullable=False`.
  - `updated_at`: `DateTime(timezone=True)`, `nullable=False`.
  - **Table Constraints & Triggers:**
    - `uq_character_instances_id_profile`: `UniqueConstraint("id", "profile_id")`
    - `ck_character_instances_not_reserved_id`: `id NOT IN ('default', 'neutral-assistant') AND template_id != 'neutral-assistant'`
    - `ck_character_instances_status`: `status IN ('active', 'archived')`
    - `ck_character_instances_preset`: `preset_id IN ('custom', 'warm_companion', 'playful', 'formal_advisor', 'tsundere', 'kuudere', 'dandere', 'yandere')`
    - `ck_character_instances_traits_bounds`: each of the 8 traits `BETWEEN 0 AND 100`.
    - SQLite trigger `trg_character_instances_immutable_provenance`: prevents changing `profile_id`, `template_id`, or `source_template_version` after `INSERT`.
- **Table 3 Modification: `profiles` (`active_character_instance_id`)**
  - Add column `active_character_instance_id`: `String(64)`, `ForeignKey("character_instances.id", ondelete="SET NULL")`, `nullable=True`, indexed.
  - SQLite triggers `trg_profiles_active_character_owner_insert` and `trg_profiles_active_character_owner_update`: when `NEW.active_character_instance_id IS NOT NULL`, require `EXISTS (SELECT 1 FROM character_instances ci WHERE ci.id = NEW.active_character_instance_id AND ci.profile_id = NEW.id AND ci.status = 'active' AND ci.is_deleted = 0)`, else `RAISE(ABORT, 'active_character_instance_id must reference an active, non-deleted CharacterInstance owned by the same Profile')`.
  - SQLite trigger `trg_character_instances_deactivate_clear_profile`: `AFTER UPDATE ON character_instances WHEN NEW.status != 'active' OR NEW.is_deleted = 1` automatically executes `UPDATE profiles SET active_character_instance_id = NULL WHERE id = NEW.profile_id AND active_character_instance_id = NEW.id;`.
- **Table 4 Modification: `conversations` (`character_instance_id` & Historical Backfill)**
  - Add column `character_instance_id`: `String(64)`, `ForeignKey("character_instances.id", ondelete="RESTRICT")`, `nullable=True`, indexed.
  - **Legacy Historical Data Migration Strategy:**
    1. Existing conversations where `character_id IN ('default', 'neutral-assistant')` keep their `character_id` and have `character_instance_id = NULL` (bound to the immutable Neutral Assistant fallback).
    2. If any existing `conversations` row has a legacy non-neutral `character_id` (e.g., `"aura"`, `"companion-1"` from earlier development/migrations), Migration 009 inspects distinct `(profile_id, character_id)` pairs:
       - If a legacy `character_id` is used by a single `profile_id`, Migration 009 inserts a `character_instances` snapshot row with `id = character_id`, `profile_id = profile_id`, `template_id = 'warm-companion'`, `source_template_version = 1`, `name = character_id`, and sets `conversations.character_instance_id = character_id`.
       - If the same legacy `character_id` string was used across multiple profiles, the first profile keeps `id = character_id` and subsequent profiles receive a deterministic `id = f"{profile_id[:8]}-{character_id}"[:64]` with both `conversations.character_id` and `conversations.character_instance_id` updated to that Profile-owned snapshot ID so cross-Profile isolation and conversation validity are both 100% preserved.
  - **SQLite Triggers on `conversations`:**
    - `trg_conversations_character_owner_insert`: enforces that if `NEW.character_instance_id IS NOT NULL`, `NEW.character_id = NEW.character_instance_id` and `EXISTS (SELECT 1 FROM character_instances ci WHERE ci.id = NEW.character_instance_id AND ci.profile_id = NEW.profile_id)`; and if `NEW.character_instance_id IS NULL`, `NEW.character_id IN ('default', 'neutral-assistant')`.
    - `trg_conversations_character_immutable_update`: prevents any `UPDATE` on `conversations` from altering `profile_id`, `character_id`, or `character_instance_id` (`RAISE(ABORT, 'conversation character identity and profile ownership are permanently bound')`).

---

### 3.2 Eight Frozen Presets & Seeded Starter Templates

Per [`characters-personality-and-emotion.md` §2.1.6](../../04_Architecture/01_Domains/characters-personality-and-emotion.md) and [`03_Character_Studio_and_Personality.md` §3.1](../../05_Design/03_Character_Studio_and_Personality.md), the eight frozen presets are defined as initial trait baselines (never rigid classes):

| Preset ID | Display Label | `warmth` | `teasing` | `guardedness` | `directness` | `expressiveness` | `affection` | `formality` | `verbosity` |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `custom` | `Custom` | 50 | 30 | 30 | 60 | 50 | 40 | 45 | 50 |
| `warm_companion` | `Warm Companion` | 85 | 35 | 15 | 60 | 75 | 80 | 25 | 60 |
| `playful` | `Playful` | 75 | 80 | 20 | 55 | 85 | 65 | 15 | 55 |
| `formal_advisor` | `Formal Advisor` | 45 | 10 | 45 | 85 | 30 | 20 | 90 | 65 |
| `tsundere` | `Tsundere` | 60 | 75 | 80 | 70 | 75 | 65 | 35 | 50 |
| `kuudere` | `Kuudere` | 45 | 25 | 85 | 80 | 20 | 45 | 65 | 30 |
| `dandere` | `Dandere` | 75 | 15 | 75 | 35 | 40 | 70 | 45 | 35 |
| `yandere` | `Yandere` | 90 | 40 | 60 | 65 | 85 | 95 | 25 | 65 |

Seeded `character_templates` rows in Migration 009 (`template_version = 1`):
1. `neutral-assistant` (`is_neutral_fallback = True`, `default_preset_id = None`, `lore = ""`, all 8 traits = `None`, `system_prompt = NEUTRAL_ASSISTANT_SYSTEM_PROMPT`).
2. `warm-companion` (`is_neutral_fallback = False`, `default_preset_id = "warm_companion"`, traits matching `warm_companion`).
3. `playful-companion` (`is_neutral_fallback = False`, `default_preset_id = "playful"`, traits matching `playful`).
4. `formal-advisor` (`is_neutral_fallback = False`, `default_preset_id = "formal_advisor"`, traits matching `formal_advisor`).

---

### 3.3 ORM Models, Schemas, Service & API Endpoints

#### `[ADD]` [`backend/app/models/character_template.py`](../../../backend/app/models/character_template.py) & [`backend/app/models/character_instance.py`](../../../backend/app/models/character_instance.py)
- Define `CharacterTemplate` and `CharacterInstance` SQLAlchemy 2.0 `Mapped` classes matching the exact column, index, and constraint layout of Migration 009.
- Export both models from [`backend/app/models/__init__.py`](../../../backend/app/models/__init__.py).

#### `[MODIFY]` [`backend/app/models/profile.py`](../../../backend/app/models/profile.py) & [`backend/app/models/conversation.py`](../../../backend/app/models/conversation.py)
- Add `active_character_instance_id: Mapped[Optional[str]]` to `Profile`.
- Add `character_instance_id: Mapped[Optional[str]]` to `Conversation`.

#### `[ADD]` [`backend/app/schemas/character.py`](../../../backend/app/schemas/character.py)
- `CharacterTraitVector`: 8 integer fields (`warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`), each constrained `ge=0, le=100`.
- `CharacterPresetId`: `Literal["custom", "warm_companion", "playful", "formal_advisor", "tsundere", "kuudere", "dandere", "yandere"]`.
- `CharacterPresetOut`: `preset_id`, `label`, `description`, `traits: CharacterTraitVector`.
- `CharacterTemplateOut`: `id`, `template_version`, `name`, `summary`, `lore`, `system_prompt`, `avatar_asset`, `default_preset_id: Optional[CharacterPresetId]`, `is_neutral_fallback: bool`, `traits: Optional[CharacterTraitVector]`, `created_at`, `updated_at`.
- `NeutralAssistantOut`: `id` (`"neutral-assistant"`), `compatibility_alias` (`"default"`), `template_version`, `name`, `summary`, `system_prompt`, `avatar_asset`, `is_neutral_fallback` (`True`), `traits` (`None`), `lore` (`""`).
- `CharacterInstanceCreate`:
  - `template_id: str = Field(..., min_length=1, max_length=64)` (rejects `"neutral-assistant"` and `"default"` with `422`/`400` because Neutral Assistant is an immutable fallback, not an editable user persona).
  - `preset_id: Optional[CharacterPresetId] = None` (if provided, initializes the 8 traits from the chosen preset; if `"custom"` or omitted, initializes from the template's baseline traits, then applies any explicit `traits` overrides).
  - Optional snapshot overrides: `name`, `summary`, `lore`, `system_prompt`, `avatar_asset`, `traits: Optional[CharacterTraitVector] = None`.
- `CharacterInstanceUpdate`:
  - Optional mutable snapshot fields: `name`, `summary`, `lore`, `system_prompt`, `avatar_asset`, `preset_id`, `traits: Optional[CharacterTraitVector]`, `status: Optional[Literal["active", "archived"]]`.
- `CharacterInstanceOut`:
  - `id`, `profile_id`, `template_id`, `source_template_version`, `name`, `summary`, `lore`, `system_prompt`, `avatar_asset`, `preset_id`, `traits: CharacterTraitVector`, `status`, `is_active_for_profile: bool`, `created_at`, `updated_at`.
- `ActiveCharacterStateOut`:
  - `profile_id: str`
  - `is_neutral_fallback: bool`
  - `active_character_id: str` (`"neutral-assistant"` when fallback is active, else `CharacterInstance.id`)
  - `active_character_instance_id: Optional[str]` (`None` when fallback is active)
  - `neutral_fallback: NeutralAssistantOut`
  - `active_instance: Optional[CharacterInstanceOut]`
- `ActiveCharacterSelectRequest`:
  - `character_id: str = Field(..., min_length=1, max_length=64)` (accepts `"neutral-assistant"`, `"default"`, or an active `CharacterInstance.id` owned by the authenticated Profile).

#### `[MODIFY]` [`backend/app/schemas/conversation.py`](../../../backend/app/schemas/conversation.py)
- `ConversationCreate`:
  - `title: Optional[str] = Field(default=None, max_length=255)`
  - `character_id: Optional[str] = Field(default=None, min_length=1, max_length=64)` (when `None`, defaults to the Profile's currently active character or `"default"` if Neutral Assistant is active; when `"default"` or `"neutral-assistant"`, binds to Neutral Assistant; when a `CharacterInstance.id`, validates ownership and binds to that instance).
- `ConversationOut`:
  - Retains `character_id: str` and adds `character_instance_id: Optional[str] = None` (`None` when bound to Neutral Assistant).

#### `[ADD]` [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py)
- Centralizes all Character Foundation domain logic and authorization checks:
  - `list_character_templates(db) -> list[CharacterTemplate]`
  - `list_character_presets() -> list[CharacterPresetOut]`
  - `get_neutral_assistant_template(db) -> CharacterTemplate`
  - `get_active_character_state(db, session: AuthenticatedProfileSession) -> ActiveCharacterStateOut`
  - `select_active_character(db, session: AuthenticatedProfileSession, character_id: str) -> ActiveCharacterStateOut`
  - `reset_to_neutral_assistant(db, session: AuthenticatedProfileSession) -> ActiveCharacterStateOut`
  - `list_profile_character_instances(db, session: AuthenticatedProfileSession, include_archived: bool = False) -> list[CharacterInstance]`
  - `get_profile_character_instance(db, session: AuthenticatedProfileSession, instance_id: str) -> CharacterInstance` (scopes query by `CharacterInstance.id == instance_id`, `CharacterInstance.profile_id == session.profile_id`, `CharacterInstance.is_deleted.is_(False)`; raises `404` if not found or foreign-owned).
  - `create_character_instance(db, session: AuthenticatedProfileSession, payload: CharacterInstanceCreate) -> CharacterInstance` (copies snapshot from `CharacterTemplate` at `template.template_version`, applies preset/custom trait baseline, sets `profile_id = session.profile_id`).
  - `update_character_instance(db, session: AuthenticatedProfileSession, instance_id: str, payload: CharacterInstanceUpdate) -> CharacterInstance` (rejects `"neutral-assistant"`/`"default"` with `400`; scopes by `session.profile_id`; if `status` transitions to `"archived"`, clears `profile.active_character_instance_id = None`).
  - `delete_character_instance(db, session: AuthenticatedProfileSession, instance_id: str) -> None` (soft-deletes `is_deleted = True`, `status = "archived"`, `deleted_at = utc_now()`; clears `profile.active_character_instance_id = None` if active; preserves row in DB so historical `conversations` retain FK integrity).
  - `resolve_conversation_character(db, session: AuthenticatedProfileSession, requested_character_id: Optional[str]) -> tuple[str, Optional[str]]`:
    - Returns `(character_id, character_instance_id)` for `POST /api/v1/conversations`.
  - `resolve_turn_persona_prompt(db, session: AuthenticatedProfileSession, conversation: Conversation) -> str`:
    - Re-verifies `conversation.profile_id == session.profile_id`.
    - If `conversation.character_instance_id is None` or `conversation.character_id in ("default", "neutral-assistant")`: returns the immutable `NEUTRAL_ASSISTANT_SYSTEM_PROMPT` (`DEFAULT_PERSONA`).
    - Otherwise loads `CharacterInstance` scoped to `(conversation.character_instance_id, session.profile_id)` (including archived/soft-deleted instances so existing conversations continue working seamlessly) and composes the snapshot `system_prompt` + sanitized `lore` block (stripping role-spoofing prefixes per `memory-and-personalization.md` sanitization pattern).

#### `[ADD]` [`backend/app/api/v1/endpoints/characters.py`](../../../backend/app/api/v1/endpoints/characters.py) & `[MODIFY]` [`backend/app/api/v1/router.py`](../../../backend/app/api/v1/router.py)
- Mount `characters.router` under `protected_router` with prefix `/characters` and tag `"characters"` (all endpoints require `Depends(get_current_profile_session)`):
  - `GET /api/v1/characters/templates` -> `list[CharacterTemplateOut]`
  - `GET /api/v1/characters/presets` -> `list[CharacterPresetOut]`
  - `GET /api/v1/characters/neutral` -> `NeutralAssistantOut`
  - `GET /api/v1/characters/active` -> `ActiveCharacterStateOut`
  - `PUT /api/v1/characters/active` -> `ActiveCharacterStateOut`
  - `POST /api/v1/characters/active/reset-neutral` -> `ActiveCharacterStateOut`
  - `GET /api/v1/characters/instances` -> `list[CharacterInstanceOut]`
  - `POST /api/v1/characters/instances` (`201 Created`) -> `CharacterInstanceOut`
  - `GET /api/v1/characters/instances/{instance_id}` -> `CharacterInstanceOut`
  - `PATCH /api/v1/characters/instances/{instance_id}` -> `CharacterInstanceOut`
  - `DELETE /api/v1/characters/instances/{instance_id}` (`204 No Content`)

#### `[MODIFY]` [`backend/app/services/retention.py`](../../../backend/app/services/retention.py)
- In `purge_deleted_records`, ensure soft-deleted `CharacterInstance` rows that are still referenced by non-purged `Conversation` rows are retained until those conversations are purged, and once unreferenced by any `Conversation` row past the retention window, are cleanly hard-deleted scoped by `profile_id`.

---

### 3.4 Client Contract Parity (`openapi.json`, `check_dart_openapi_parity.py`, `companion_api`)

- Regenerate `contracts/openapi/openapi.json` from the FastAPI app.
- Add `frontend/flutter/packages/companion_api/lib/dto/character_dto.dart` with Dart DTO classes matching the OpenAPI schemas 1-to-1 (`CharacterTraitVectorDto`, `CharacterPresetDto`, `CharacterTemplateDto`, `NeutralAssistantDto`, `CharacterInstanceCreateRequest`, `CharacterInstanceUpdateRequest`, `CharacterInstanceDto`, `ActiveCharacterStateDto`, `ActiveCharacterSelectRequest`).
- Update `ConversationDto` in `frontend/flutter/packages/companion_api/lib/dto/conversation_dto.dart` to include `final String? characterInstanceId;` (`character_instance_id`) and allow optional `characterId` in `ConversationCreateRequest` (defaulting to `'default'` when not overridden so existing callers remain 100% compatible).
- Add the 11 `/api/v1/characters/*` client methods to `CompanionClient` in `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` and register `M3_CHARACTER_ROUTE_DART_METHODS` + DTO mappings in `scripts/check_dart_openapi_parity.py`.

---

## 4. Step-by-Step Pseudocode & Test-First Implementation Sequence

We follow a strict **Test-First (TDD)** sequence across six cohesive implementation phases on `feature/m3-character-foundation-a`.

### Phase A.1: Migration 009 & Schema Integrity (Test-First)

1. **Pin `test_migration_008.py` to `REVISION`:**
   - Update [`backend/tests/test_migration_008.py`](../../../backend/tests/test_migration_008.py#L55) from `command.upgrade(config(path), "head")` to `command.upgrade(config(path), REVISION)` so it continues testing revision `008` in isolation when `009` becomes head.
2. **Write `backend/tests/test_migration_009.py` (Red):**
   - Test 1 (`test_fresh_upgrade_to_009_creates_character_tables_and_seeds_templates`): upgrades empty DB to `head` (`009_character_foundation`), verifies `character_templates`, `character_instances`, `profiles.active_character_instance_id`, `conversations.character_instance_id`, seeded `neutral-assistant` (with `is_neutral_fallback=1`, `lore=""`, all 8 traits `NULL`), and starter templates (`warm-companion`, `playful-companion`, `formal-advisor` with `template_version=1`).
   - Test 2 (`test_neutral_assistant_template_is_immutable_in_sqlite`): verifies `UPDATE` or `DELETE` on `character_templates WHERE id = 'neutral-assistant'` and `INSERT` of a second `is_neutral_fallback = 1` row fail with ` sqlite3.IntegrityError`.
   - Test 3 (`test_populated_008_upgrade_preserves_default_and_legacy_custom_conversations`): populates an `008` database with two Profiles (`default` and `profile-b`), conversations with `character_id = "default"`, and conversations with legacy `character_id = "aura"` and shared `"companion-1"`, plus FTS5 memory items; upgrades to `009` and verifies zero data loss, valid `character_instance_id` backfills for legacy custom characters, `character_instance_id IS NULL` for `"default"`, and intact FTS5 search.
   - Test 4 (`test_triggers_enforce_same_profile_ownership_and_conversation_immutability`): verifies raw SQL cannot set `profiles.active_character_instance_id` to another Profile's instance, cannot bind a conversation to another Profile's `character_instance_id`, and cannot mutate `conversations.character_id` or `conversations.character_instance_id` after `INSERT`.
   - Test 5 (`test_downgrade_009_to_008_and_reupgrade`): verifies clean downgrade to `008` and re-upgrade to `009`.
3. **Implement `backend/migrations/versions/009_character_foundation.py` & ORM Models (Green):**
   - Create `009_character_foundation.py`, `character_template.py`, `character_instance.py`, and update `profile.py`, `conversation.py`, `models/__init__.py`, and `db/session.py`.
   - Run `pytest backend/tests/test_migration_008.py backend/tests/test_migration_009.py -v`.

### Phase A.2: Character Service, Snapshot Isolation & Neutral Assistant Fallback (Test-First)

1. **Write `backend/tests/test_character_foundation.py` (Red):**
   - `test_presets_catalog_returns_eight_frozen_presets_with_valid_trait_vectors`
   - `test_create_character_instance_copies_template_snapshot_and_provenance`
   - `test_template_version_update_never_mutates_existing_character_instances` (simulates an app upgrade bumping `warm-companion` `template_version` from `1` to `2` and changing template `system_prompt` / `warmth`; verifies existing `CharacterInstance` retains `source_template_version == 1` and its original snapshot fields).
   - `test_neutral_assistant_has_no_hardcoded_50_sliders_and_cannot_be_instantiated_or_edited`
   - `test_active_character_switching_and_reset_to_neutral_only_affect_future_conversations`
   - `test_archiving_or_deleting_active_instance_resets_profile_to_neutral_and_preserves_past_conversations`
2. **Implement `backend/app/schemas/character.py` & `backend/app/services/character_service.py` (Green):**
   - Implement preset registry, snapshot initialization, template isolation, active character state, reset-to-neutral, and persona prompt resolution.

### Phase A.3: FastAPI Endpoints, Conversation Binding & Turn Persona Resolution (Test-First)

1. **Write `backend/tests/test_character_authorization.py` & update `backend/tests/test_conversations.py` (Red):**
   - Verify all `/api/v1/characters/*` endpoints reject unauthenticated requests (`401`) and raw `COMPANION_API_KEY` pairing headers without `X-Profile-Session-Token` (`401`/`403`).
   - Verify Profile A cannot `GET`, `PATCH`, `DELETE`, activate (`PUT /api/v1/characters/active`), or start a conversation (`POST /api/v1/conversations`) with Profile B's `CharacterInstance` (all fail closed with `404`).
   - Verify `orchestrate_chat_stream` injects the bound `CharacterInstance`'s snapshot persona prompt on turns for instance-bound conversations and the immutable `NEUTRAL_ASSISTANT_SYSTEM_PROMPT` on turns for `"default"` / `"neutral-assistant"` conversations.
2. **Implement `backend/app/api/v1/endpoints/characters.py`, `router.py`, `conversations.py`, `orchestrator.py`, and `retention.py` (Green):**
   - Wire routes and conversation/orchestrator character resolution.
   - Run full backend pytest suite.

### Phase A.4: OpenAPI & Dart `companion_api` Parity (Test-First)

1. **Update `dto_test.dart` & `companion_client_test.dart` (Red):**
   - Add serialization round-trip tests for `CharacterTemplateDto`, `CharacterPresetDto`, `NeutralAssistantDto`, `CharacterInstanceDto`, `ActiveCharacterStateDto`, and `ConversationDto` (`characterInstanceId`), plus client contract tests for `/api/v1/characters/*`.
2. **Update `openapi.json`, `character_dto.dart`, `conversation_dto.dart`, `companion_client.dart`, and `check_dart_openapi_parity.py` (Green):**
   - Export updated `contracts/openapi/openapi.json`.
   - Run `python scripts/check_dart_openapi_parity.py` and `flutter test` in `frontend/flutter/packages/companion_api`.

### Phase A.5: Full Regression Verification Gate

- Run all backend, migration, OpenAPI parity, Dart package, Flutter desktop, and Web dev harness test suites to confirm zero regressions.

---

## 5. Acceptance Criteria & Verification Plan

### Acceptance Criteria Checklist

1. **Template vs. Instance Separation (`PC-CHAR-001`, `ADR-0012`):**
   - `character_templates` stores app-owned, versioned templates with no `profile_id`.
   - `character_instances` stores Profile-owned mutable snapshots (`profile_id NOT NULL`, no implicit default) with `template_id` and `source_template_version` provenance metadata.
   - Updating a `CharacterTemplate` row in `character_templates` never modifies any existing `CharacterInstance` row.
2. **Immutable Neutral Assistant Fallback (`PC-CHAR-005`):**
   - Built-in `neutral-assistant` template is immutable in SQLite and API layers, has `lore = ""` and `traits = NULL` (never hardcoded `50`s), and cannot be instantiated as an editable user persona or modified/deleted.
   - `POST /api/v1/characters/active/reset-neutral` and `PUT /api/v1/characters/active` (`{"character_id": "neutral-assistant"}`) deterministically reset the Profile's active persona to Neutral Assistant.
3. **Permanent Conversation Association & Safe Switching:**
   - Conversations bind permanently to their Character identity at creation time (`character_id` and `character_instance_id`).
   - Switching a Profile's active character or resetting to Neutral Assistant never reattributes existing conversations.
   - Archiving or soft-deleting a `CharacterInstance` resets the Profile's active character to Neutral Assistant (if it was active) without breaking or deleting historical conversations bound to that instance.
4. **Strict Profile Authorization & Cross-Profile Isolation (`ADR-0018`):**
   - Every `/api/v1/characters/*` endpoint requires a valid `ProfileSession`.
   - Cross-Profile access to another Profile's `CharacterInstance` (read, update, delete, activate, or conversation creation) fails closed with `404 Not Found`.
5. **Migration & Rollback Safety:**
   - Migration `009_character_foundation` upgrades cleanly from both empty databases and populated `008` databases (including legacy `"default"` and custom `character_id` conversations), preserves FTS5 tables/triggers, and supports clean downgrade to `008` and re-upgrade to `009`.

### Exact Verification Commands

```powershell
# 1. Backend Migration & Full Test Suite
python -m pytest backend/tests/test_migration_008.py backend/tests/test_migration_009.py -v
python -m pytest backend/tests/test_character_foundation.py backend/tests/test_character_authorization.py backend/tests/test_conversations.py -v
python -m pytest backend/tests -v

# 2. OpenAPI & Dart Parity Check
python scripts/check_dart_openapi_parity.py

# 3. Dart API Client & Flutter Desktop Tests
cd frontend/flutter/packages/companion_api; flutter test
cd frontend/flutter/apps/desktop; flutter test

# 4. Web Dev Harness Truthfulness & Regression Tests
cd frontend/web; npm test -- --run
```

---

## 6. Risks, Recovery, Rollback & Unresolved Decisions

### Risk & Mitigation Register

| Risk | Severity | Mitigation |
| :--- | :---: | :--- |
| Existing conversations in upgraded databases or tests contain custom non-default `character_id` values (`"aura"`, `"companion-1"`). | High | Migration 009 automatically materializes Profile-owned legacy snapshot rows in `character_instances` for any pre-existing non-neutral `conversations.character_id` values and links `conversations.character_instance_id`, ensuring 100% migration validity. |
| Deleting a `CharacterInstance` could orphan or cascade-delete historical `Conversation` rows. | High | `conversations.character_instance_id` uses `ON DELETE RESTRICT` and `DELETE /api/v1/characters/instances/{id}` performs a soft-delete + archive (`is_deleted = True`, `status = "archived"`), clearing `profiles.active_character_instance_id` while preserving historical conversation persona provenance. |
| Prompt injection via custom `CharacterInstance.lore` or `system_prompt` fields. | Medium | `resolve_turn_persona_prompt` sanitizes control characters and strips role-spoofing prefixes (`system:`, `assistant:`, `user:`, `developer:`) from `lore` blocks, and never grants tool/shell/cross-Profile authority to persona prompts. |
| `test_migration_008.py` fails when `009` becomes Alembic `head`. | Low | Pin `test_migration_008.py` `migrated` fixture to `REVISION` (`"008_profile_sessions_and_tickets"`), matching the established convention in `test_migration_007.py`. |

### Rollback Strategy

- **Database Rollback:** `alembic downgrade 008_profile_sessions_and_tickets` drops the `009` SQLite triggers, removes `conversations.character_instance_id` and `profiles.active_character_instance_id` via batch table rebuild (preserving all `conversations.character_id` strings and `profile_id` ownership), and drops `character_instances` and `character_templates`.
- **Pre-Migration Backup:** `prepare_database_schema` creates a timestamped SQLite backup (`pre_m3_009_upgrade`) before applying Migration `009` on any existing database.

### Unresolved Decisions / Blockers

- **None.** All architectural contracts (`ADR-0012`, `ADR-0018`, `characters-personality-and-emotion.md` §2.1.6, `03_Character_Studio_and_Personality.md` §2–§5) are resolved and frozen in the canonical repository documentation.
