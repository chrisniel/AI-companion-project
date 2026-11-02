# Characters, Personality, and Emotion Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the structural separation, lifecycle rules, behavioral models, and persistence boundaries for companion personas:
- Companion character lore, identity, and visual/audio presentation associations.
- Decoupled behavioral style and personality traits.
- Transient, non-clinical conceptual emotional states.
- Ambient presence and contextual responsiveness.
- Future relationship continuity states.

It governs the boundary between stable user profile data and interchangeable companion character configurations.

---

## 2. Durable Architecture & Invariants

### 2.1 The Complete D11 Entity Separation Model

In accordance with Decision D11, companion character systems enforce strict conceptual and architectural separation across distinct entities:

1. **Profile (User Root Authority):**
   - Owns user identity, user data, personal preferences, tasks, schedules, and memories (`ADR-0018`).
   - In accordance with Decision D4, device authentication credentials remain separated from profile-owned personal data (Profile does not own client device credentials).
   - Character switching must never mutate or reassign Profile ownership or Profile-owned personal data. A Character never owns Profile data.
2. **Character Template vs. Character Instance:**
   - **Character Template (App-Owned):** Shipped with the application or seeded via migrations; defines base immutable persona lore, archetype backstory, default display name, avatar artwork, and default preset (`character_templates` table; no `profile_id`).
   - **Character Instance (Profile-Owned):**
     - is instantiated from a Character Template as an initial snapshot/configuration;
     - stores Profile-owned customizations and persistent Character state (`character_instances` table; `profile_id` FK referencing `profiles.id` with `ON DELETE CASCADE`);
     - is NOT a live binding to the Template;
     - later Template updates MUST NOT silently mutate existing Character Instances.
     - *Note on Cascade vs. Purge:* The database `ON DELETE CASCADE` definition automatically cleans up child character instances upon raw profile row deletion, which is distinct from service-level ordered hard-purge requirements for user data retention.
3. **Conversation:**
   - Belongs to the user Profile.
   - References a specific Character persona; conversation history remains permanently bound to that Character as recorded in `conversations.character_id`.
   - New conversations select the Profile's active character instance when `character_id` is omitted, or Neutral Assistant when `"default"` or `"neutral-assistant"` is supplied.
4. **Personality Dimensions (8 Continuous Scales):**
   - **Eight Continuous Dimensions:** Exact frozen V1 dimensions from source are: `warmth`, `humor`, `empathy`, `formality`, `curiosity`, `energy`, `assertiveness`, `rebelliousness`. These are represented as 0–100 integer values.
   - **Approved Presets:** `warm`, `playful`, `formal`, `creative`, `analytical`, `empathetic`, `stoic`, `unhinged` (and `custom`). Presets copy/initialize baseline trait values and remain editable. Preset values are provisional numeric baselines, not rigid or immutable architectural constants.
   - **Initialization Precedence:**
     - Explicit non-custom preset: initializes trait vector from the selected preset's baseline values.
     - Custom or omitted preset: initializes trait vector from the source template's baseline values.
     - Explicit trait vector: overrides baseline trait values for any supplied dimensions.
5. **Emotion & Mood Dynamics (Persistent & Bounded):**
   - **Persistent Simulated Mood:** Emotion/Mood is a persistent bounded simulated state across Runtime/Windows restart. It rebalances/decays based on elapsed time. Exact mathematical decay curve remains open. Do NOT mandate exponential decay in the durable architecture. Do NOT call PC V1 emotion state ephemeral.
   - **Mood Isolation:** Mood affects social presentation only. Never affects facts, permissions, tools, alarms, scheduler, privacy, queue priority or correctness.
6. **Neutral Assistant (Immutable Fallback):**
   - Immutable built-in fallback with `is_neutral_fallback = True`.
   - Traits are strictly `NULL` in the database, enforced by SQLite CHECK constraints.
   - Non-editable, non-deletable, non-archivable.
   - Accessible via `GET /api/v1/characters/neutral`.
   - Active character can be set to Neutral Assistant via `PUT /api/v1/characters/active` (`character_instance_id="default"` or `"neutral-assistant"`) or `POST /api/v1/characters/active/reset-neutral`.
7. **Voice (Acoustic & Prosodic Configuration):**
   - Decoupled speech synthesis configuration (e.g., target voice identifier, speed, pitch, prosody).
   - Interchangeable across TTS providers without modifying character lore or personality schemas.
8. **Presence (Contextual & Presentation State):**
   - Distinct, bounded contextual and presentation concept reflecting companion and environment awareness.
   - Advanced Presence remains scheduled for **PC Later**; exact signals, sensor integrations, persistence models, and privacy boundaries remain OPEN DESIGN.
   - Existing PC V1 capabilities (such as Gaming / Low-Impact Resource Mode) may expose contextual host signals without implying a full Presence subsystem is implemented.
9. **Relationship State (Interaction Continuity — PC Later):**
   - Represents long-term interaction continuity and familiarity depth.
   - Formally decoupled from Personality and Emotion under Decision D11.
   - Scheduled for **PC Later** (not a PC V1 milestone requirement).
   - Strictly opt-in and hidden by default; user controls are required, while the exact reset lifecycle remains OPEN DESIGN.
10. **Historical Identity Preservation & Legacy Placeholders:**
   - Historical conversations containing legacy `character_id` values (from migrations 001–008) are preserved without inventing speculative personalities.
   - A legacy placeholder instance is derived deterministically via length-prefixed UUIDv5:
     `f"legacy-{uuid.uuid5(LEGACY_CHARACTER_NAMESPACE, f'{len(profile_id)}:{profile_id}:{len(legacy_character_id)}:{legacy_character_id}')}"`
   - Legacy placeholders have `is_legacy_placeholder = True`.
   - Protections:
     - `GET /api/v1/characters/instances` accepts `include_legacy: bool = False` (defaults to excluding legacy placeholders). Explicit `include_legacy=True` includes them for the authenticated profile only.
     - Legacy placeholders cannot be modified (`PATCH`), deleted (`DELETE`), activated (`PUT /active`), or directly assigned to new conversations (`POST /conversations`), failing with HTTP 400.
     - SQLite triggers `trg_character_instances_prevent_legacy_update` and `trg_character_instances_prevent_legacy_delete` enforce legacy immutability at the database level.

### 2.2 Character Switching Invariants

Switching active companion characters must **never**:
- Delete, alter, or hide user memories, profile attributes, or task records.
- Reattribute past conversation history or retroactively alter speaker attribution.
- Silently rewrite past turns or system messages.
- Implicitly mix multiple character personas into a single active conversation thread.

Conversations remain permanently bound to the `character_id` under which turns were recorded. Starting a session with a different character initiates a distinct conversation thread or explicitly bounded transition.

- **Character Deletion:** Character deletion should prefer archive/disable before purge so historical conversation identity remains interpretable.

### 2.3 Mobile Character, Emotion & Presence Boundaries (`D-PHONE-06`, `D-PHONE-EMO-01`, `D-PHONE-12D`, `D-PHONE-12E`, `D-PHONE-UX-10`, `P-SHARED-PRESENCE-01`, `P-PHONE-AR-01`, `P-PHONE-AR-02`, `P-PRESENCE-02`)

- **Inheritance of Shared D11 Architecture (`D-PHONE-06`):** Mobile companion clients strictly inherit the shared D11 Character, Personality, and Emotion architecture. There is no separate or competing mobile-only character schema.
- **Character Selection & Isolation:** Mobile clients may select among cached or synchronized Character Instances for the authenticated user Profile. Switching characters never mutates or reassigns Profile ownership, security or tool permissions, Task records, Health context, or Profile Memories. Conversations remain permanently bound to the Character under which they were initiated.
- **Character Studio & Authoring Authority:**
  - *Connected Mobile:* May expose Character Studio authoring and editing UI as a client to the PC Host canonical Character service, utilizing shared D11 traits, dimensions, presets, and validation rules.
  - *Offline Mobile V1:* Canonical Character creation and trait editing are **not** supported offline in Mobile V1; local Character creation or modification is NOT an approved offline canonical capability. Any potential client-side drafts are strictly non-canonical and do not alter companion identity until reconciled and accepted by the PC Host.
  - *Withdrawn Concepts:* Standalone mobile-local authoritative Character creation, independent mobile character variant forks, and separate mobile-only mood layers are explicitly superseded and rejected.
- **Offline Emotion Event Synchronization (`D-PHONE-EMO-01`):** Mobile does not directly mutate canonical persistent Mood numerical values while disconnected. Instead:
  $$\text{offline interaction} \to \text{typed bounded emotion event} \to \text{durable outbox} \to \text{optional provisional local expression} \to \text{Host reconciliation} \to \text{shared D11 Emotion policy} \to \text{canonical Mood}$$
  The mobile client synchronizes typed emotion events (e.g. conversational sentiment, interaction cues) rather than arbitrary numeric overrides.
- **Companion Check-In Surfaces & Tone (`D-PHONE-12D`, `D-PHONE-12E`):**
  - Check-ins, routines, and home widgets reflect the active Character's Personality traits and bounded Mood.
  - Character-aware check-in language remains optional presentation. Expressive persona presets may modulate stylistic framing provided factual companion information follows immediately, underlying facts are not distorted, and the interaction strictly avoids coercive threats, emotional manipulation, isolation pressure, punishment, or fabricated claims regarding missed interactions.
- **Lightweight Mood Presence & Emoji Fallback (`D-PHONE-UX-10`):**
  - Mobile V1 presents mood through available Character expression assets, lightweight static portraits, or local 2D assets.
  - Standard **Emoji / Mood-Glyphs** serve as the mandatory, guaranteed lightweight V1 fallback across all devices and low-resource states.
  - Visual expression is purely presentation; it is never the authoritative underlying Mood state.
- **Approved Future Direction: Embodied Presence & Mobile AR (`P-SHARED-PRESENCE-01`, `P-PHONE-AR-01`, `P-PHONE-AR-02`, `P-PRESENCE-02`):**
  - *Embodied Presence (`P-SHARED-PRESENCE-01`):* Approved future direction where Character instances may reference 2D expression bundles, Live2D rigs, or 3D/VRM models. Presence is strictly decoupled from Character identity, Personality, Mood, and Voice.
  - *Mobile AR Presence (`P-PHONE-AR-01`):* Approved future direction for explicit, user-started AR sessions rendering the companion into the physical environment.
  - *Bounded Scene Awareness (`P-PHONE-AR-02`):* AR rendering does not require continuous VLM inference; still-image cloud consent does not authorize live camera streaming.
  - *Remote Expression Assets (`P-PRESENCE-02`):* Future experimental search/import for user-directed expression assets. Automatic web GIF downloading upon mood changes is rejected.

---

## 3. Current Verified Implementation

Repository source code, database migrations, API contracts, and automated test suites verify the following implementation reality:

### 3.1 Backend Persistence & Alembic Migration 009

Alembic Migration 009 (`backend/migrations/versions/009_character_foundation.py`) establishes the character persistence foundation:
- **Character Templates Table (`character_templates`):** Application-owned definitions with `template_version >= 1`, `name`, `summary`, `lore`, `system_prompt`, `avatar_asset`, `default_preset_id`, `is_neutral_fallback`, and the eight personality dimensions.
- **Seeded Templates:** Four initial templates are seeded in Migration 009:
  1. `warm-companion` (Default preset: `warm`)
  2. `playful-friend` (Default preset: `playful`)
  3. `stoic-mentor` (Default preset: `stoic`)
  4. `neutral-assistant` (Immutable fallback; `is_neutral_fallback = True`, all traits `NULL`)
- **Character Instances Table (`character_instances`):** Profile-owned mutable snapshots (`id` UUIDv4, `profile_id` FK referencing `profiles.id` with `ON DELETE CASCADE`, `template_id` FK referencing `character_templates.id`, `name`, `system_prompt`, `avatar_asset`, `preset_id`, 8 personality traits, `is_legacy_placeholder`, `archived_at`).
- **Profile Active Character Table (`profile_active_characters`):** Stores 1-to-1 active character instance mapping per profile (`profile_id` PK/FK, `character_instance_id` FK).
- **SQLite CHECK Constraints:** Enforce non-null preset and trait dimensions for non-Neutral templates, while requiring strictly `NULL` traits for Neutral Assistant fallback.
- **Database Triggers:** SQLite triggers `trg_character_instances_prevent_legacy_update` and `trg_character_instances_prevent_legacy_delete` prevent updates and deletions of legacy placeholder instances.
- **Pre-Migration Safety & Dynamic Head Discovery:** Pre-migration SQLite WAL backup hook in `backend/app/core/storage.py::prepare_database_schema()` dynamically discovers the Alembic head and creates a verified pre-migration backup before upgrading existing databases.
- **Loss-Aware Fail-Closed Downgrade:** Migration 009 `downgrade()` deterministically compares substantive attributes of `character_templates` against `SEED_TEMPLATES` (excluding incidental timestamp metadata) and checks for user-created instances; refuses downgrade with `RuntimeError` on modified templates or existing instances, preserving all user data and schema intact.

### 3.2 Models, Schemas & Personality Presets

- **Models:** Defined in `backend/app/models/character.py` (`CharacterTemplate`, `CharacterInstance`, `ProfileActiveCharacter`) and integrated with `backend/app/models/profile.py` and `backend/app/models/conversation.py`.
- **Eight Continuous Trait Dimensions:**
  - `warmth` (0–100 integer)
  - `humor` (0–100 integer)
  - `empathy` (0–100 integer)
  - `formality` (0–100 integer)
  - `curiosity` (0–100 integer)
  - `energy` (0–100 integer)
  - `assertiveness` (0–100 integer)
  - `rebelliousness` (0–100 integer)
- **Approved Presets:** `warm`, `playful`, `formal`, `creative`, `analytical`, `empathetic`, `stoic`, `unhinged` (and `custom`). Presets provide initial baseline traits. Selecting a preset initializes the instance traits from preset baseline values.
- **Precedence Order:** Non-custom preset selects preset baseline; custom or omitted preset selects template baseline; explicit trait vector overrides baseline values.

### 3.3 Character Service & REST API

The `CharacterService` (`backend/app/services/character_service.py`) and FastAPI endpoints (`backend/app/api/v1/endpoints/characters.py`) provide:
- `GET /api/v1/characters/templates` — List installed Character Templates.
- `GET /api/v1/characters/presets` — List approved personality presets with baseline traits.
- `GET /api/v1/characters/neutral` — Get immutable Neutral Assistant fallback definition.
- `GET /api/v1/characters/instances` — List Profile-owned Character Instances (supports `include_archived: bool = True` and `include_legacy: bool = False`).
- `POST /api/v1/characters/instances` — Create a new Character Instance from a template snapshot.
- `GET /api/v1/characters/instances/{instance_id}` — Get single Character Instance.
- `PATCH /api/v1/characters/instances/{instance_id}` — Update instance lore, prompt, traits, preset, or archive state (legacy placeholders rejected with HTTP 400).
- `DELETE /api/v1/characters/instances/{instance_id}` — Hard-delete instance or soft-archive (legacy placeholders rejected with HTTP 400).
- `GET /api/v1/characters/active` — Get active character state for authenticated Profile.
- `PUT /api/v1/characters/active` — Select active character instance for Profile; supports selecting instance ID or `"default"` / `"neutral-assistant"` to reset to Neutral Assistant.
- `POST /api/v1/characters/active/reset-neutral` — Explicitly reset Profile's active character to Neutral Assistant.

### 3.4 Runtime Persona Resolution & Security Boundaries

- **Runtime Persona Resolution:** The orchestrator (`backend/app/services/assistant/orchestrator.py`) dynamically resolves the bound character identity for the conversation:
  - If bound to Neutral Assistant: injects immutable, objective assistant instructions without persona lore or traits.
  - If bound to a Character Instance: composes the system prompt with instance name, lore, and instructions.
- **Trust Boundaries & Enforcement:** Profile isolation and security boundaries are enforced deterministically by backend bearer-token authentication, SQLite Foreign Keys, and database triggers—not by XML delimiter tags alone. Prompt formatting employs structural framing as defense-in-depth against prompt injection, while core safety boundaries and tool permissions remain non-bypassable.

### 3.5 Client Contract & SDK Parity

- **OpenAPI 3.1 Specification:** All 11 character routes and DTOs synchronized in `contracts/openapi/openapi.json`.
- **Flutter Companion API SDK:** Complete Dart DTO schemas and `CompanionClient` character methods implemented in `frontend/flutter/packages/companion_api` with verified contract parity (`scripts/check_dart_openapi_parity.py`).
- **React Web Client:** `conversationApi.createConversation()` updated in `frontend/web/src/services/api/conversationApi.ts` to support optional `character_id` parameter, preserving backward compatibility.
- **Frontend Truthfulness Contract:** `frontend/web/src/test/phase8b3Truthfulness.test.tsx` confirms web character UI acts as a preview component without claiming unbacked persistence or unauthorized voice engines.

### 3.6 Mobile Implementation Reality

- **Mobile Character Studio:** `NOT IMPLEMENTED`. Flutter mobile character authoring and trait customization UI is not implemented in the repository.
- **Mobile Emotion Event Outbox & Sync:** `NOT IMPLEMENTED`. Offline emotion event recording, durable outbox queuing, and host reconciliation are not implemented.
- **Mobile AR / 3D / Live2D Presence:** `NOT IMPLEMENTED`. Augmented reality, Live2D, and VRM companion rendering runtimes are not implemented in repository code.

---

## 4. Approved Target Architecture / Deferred Capabilities

The following capabilities are approved under Decision D11 and scheduled for subsequent M3 batches:

1. **Full Character Studio UI (`PC-CHAR-002`, `PC-CHAR-003`):**
   - Three-panel desktop and web authoring UI (template browser, trait slider editor, live interactive conversation scratchpad).
2. **Dynamic Personality Engine (PC V1 Follow-on):**
   - Dynamic trait weighting, conversational drift within bounded limits, and real-time interaction feedback.
3. **Persistent Mood Dynamics (PC V1):**
   - Persistent simulated companion mood across restarts with time decay back to baseline.
4. **Relationship Continuity State (PC Later):**
   - Long-term interaction familiarity depth and opt-in relationship progression.
5. **Decoupled Voice Synthesis Integration (PC V1):**
   - TTS acoustic profiles and prosody mapping bound to character definitions.

---

## 5. Implementation-Open Details (Decision Debt)

The normative architecture for D11 is frozen. The following implementation-level details are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Database Schemas:** Exact SQLite column types, constraints, and foreign keys for character instances, presets, and mood persistence (`DEBT-V1-006`).
- **Mood Decay Half-Life Formula:** Mathematical formula for time decay back to baseline mood (`DEBT-V1-007`).
- **Presence Architecture (PC Later):** Host sensors, privacy controls, and presentation models for PC Later.
- **Relationship State Mechanics (PC Later):** Progression algorithms, safety boundaries, user controls, and lifecycle.

---

## 6. Security & Ownership Boundaries

- **Profile Primacy:** Character profiles, personality configs, and emotion state are subordinate to the user Profile. A character has zero data authority over the user.
- **Safety Invariant:** Mood dynamics must **never** influence security policy, tool confirmation gates, or safety boundaries. A character in a playful or grumpy mood must never execute an unauthorized tool or bypass confirmation.
- **Privacy & Prompt Injection:** Character lore and persona prompts must not override hard safety constraints or security policy gates established in `02_Data_and_Security/tool-permissions-and-actions.md`.
- **User Erasure:** Resetting or deleting a character persona never touches underlying user memories, tasks, or profile identity.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, ADR-0018, D11)
- **Mobile System Baseline:** [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md)
- **Mobile Capabilities & Runtime Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md)
- **Mobile Offline & Sync Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`](../04_Infrastructure/mobile-offline-and-sync.md)
- **Mobile Companion Shell & UX:** [`docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`](../../05_Design/08_Mobile_Companion_Shell_and_UX.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) (Decision D11), [`WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-CHAR-001`, `PC-CHAR-002`)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **UI Design Presentation:** [`docs/05_Design/03_Character_Studio_and_Personality.md`](../../05_Design/03_Character_Studio_and_Personality.md), [`04_Emotion_and_Visual_Presence.md`](../../05_Design/04_Emotion_and_Visual_Presence.md)
