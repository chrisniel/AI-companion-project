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
     - *Note on Cascade vs. Purge:* `CharacterInstance.profile_id` uses `ON DELETE CASCADE`, whereas `conversations.character_instance_id` uses `ON DELETE RESTRICT`. Because of the restrict constraint on conversation references, direct SQL deletion of a Profile row with conversations bound to character instances will be rejected by SQLite foreign key enforcement unless conversations are deleted first. Therefore, future Profile hard-purge operations must strictly adhere to an ordered purge dependency (purging conversations prior to deleting character instances).
3. **Conversation:**
   - Belongs to the user Profile.
   - References a specific Character persona; conversation history remains permanently bound to that Character as recorded in `conversations.character_id` and `conversations.character_instance_id`.
   - New conversations select the Profile's active character instance when `character_id` is omitted, or Neutral Assistant when `"default"` or `"neutral-assistant"` is supplied.
4. **Personality Dimensions (8 Continuous Scales):**
   - **Eight Continuous Dimensions:** Exact frozen V1 dimensions from source are: `warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`. These are represented as 0–100 integer values.
   - **Approved Presets:** `custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`. Presets copy/initialize baseline trait values and remain editable. Preset values are provisional numeric baselines, not rigid or immutable architectural constants.
   - **Initialization Precedence:**
     - Explicit non-custom preset: initializes trait vector from the selected preset's baseline values.
     - Custom or omitted preset: initializes trait vector from the source template's baseline values.
     - Explicit trait vector: caller supplies a complete 8-dimensional `CharacterTraitVector` overriding baseline values (partial vectors are rejected by Pydantic schema validation).
5. **Emotion & Mood Dynamics (Persistent & Bounded):**
   - **Persistent Simulated Mood:** Emotion/Mood is a persistent bounded simulated state across Runtime/Windows restart. It rebalances/decays based on elapsed time. Exact mathematical decay curve remains open. Do NOT mandate exponential decay in the durable architecture. Do NOT call PC V1 emotion state ephemeral.
   - **Mood Isolation:** Mood affects social presentation only. Never affects facts, permissions, tools, alarms, scheduler, privacy, queue priority or correctness.
6. **Neutral Assistant (Immutable Fallback):**
   - Immutable built-in fallback with `is_neutral_fallback = True`.
   - Traits are strictly `NULL` in the database, enforced by SQLite CHECK constraints.
   - Non-editable, non-deletable, non-archivable.
   - Accessible via `GET /api/v1/characters/neutral`.
   - Active character can be set to Neutral Assistant via `PUT /api/v1/characters/active` (using request payload `{"character_id": "default"}` or `"neutral-assistant"`) or `POST /api/v1/characters/active/reset-neutral`. Resetting or switching active character updates `profiles.active_character_instance_id`. Future conversations inherit that selection; existing conversations retain their original Character association (`conversations.character_instance_id` / `conversations.character_id`), and no retroactive conversation reassignment occurs.
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
     ```python
     canonical = f"{len(profile_id)}:{profile_id}|{len(legacy_character_id)}:{legacy_character_id}"
     instance_id = f"legacy-{uuid.uuid5(LEGACY_CHARACTER_NAMESPACE, canonical)}"
     ```
   - Legacy placeholders have `is_legacy_placeholder = True`.
   - Protections:
     - `GET /api/v1/characters/instances` accepts `include_legacy: bool = False` (defaults to excluding legacy placeholders). Explicit `include_legacy=True` includes them for the authenticated profile only.
     - Legacy placeholders cannot be modified (`PATCH`), deleted (`DELETE`), activated (`PUT /active`), or directly assigned to new conversations (`POST /conversations`), failing with HTTP 400.
     - Database safeguards: SQLite CHECK constraint `ck_character_instances_legacy_or_standard` (requires `status='archived'`, `lore=''`, `system_prompt=''`, `template_id IS NULL`, `preset_id IS NULL`, all 8 traits `NULL`), SQLite trigger `trg_character_instances_immutable_provenance` (prevents altering `is_legacy_placeholder`, `profile_id`, `legacy_character_id`, `template_id`, `source_template_version`), triggers `trg_profiles_active_character_owner_insert/update` (require `is_legacy_placeholder = 0`), and Python service layer mutation guards. Referenced placeholders are protected against raw SQL deletion by foreign key `conversations.character_instance_id` (`ON DELETE RESTRICT`). There is no blanket SQLite trigger specifically blocking raw SQL `DELETE` on unreferenced legacy placeholders; protection against mutation or deletion via the API is enforced by service-layer guards.

### 2.2 Character Switching Invariants

Switching active companion characters must **never**:
- Delete, alter, or hide user memories, profile attributes, or task records.
- Reattribute past conversation history or retroactively alter speaker attribution.
- Silently rewrite past turns or system messages.
- Implicitly mix multiple character personas into a single active conversation thread.

Conversations remain permanently bound to the `character_id` and `character_instance_id` under which turns were recorded. Starting a session with a different character initiates a distinct conversation thread or explicitly bounded transition.

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
  1. `neutral-assistant` (Immutable fallback; `is_neutral_fallback = True`, all traits `NULL`, default preset `NULL`)
  2. `warm-companion` (Default preset: `warm_companion`)
  3. `playful-companion` (Default preset: `playful`)
  4. `formal-advisor` (Default preset: `formal_advisor`)
- **Character Instances Table (`character_instances`):** Profile-owned mutable snapshots (`id` String(64), `profile_id` FK referencing `profiles.id` with `ON DELETE CASCADE`, `template_id` FK referencing `character_templates.id` with `ON DELETE RESTRICT` [nullable for legacy placeholders], `source_template_version`, `name`, `summary`, `lore`, `system_prompt`, `avatar_asset`, `preset_id`, 8 personality traits, `is_legacy_placeholder`, `legacy_character_id`, `status` (`active` or `archived`), `is_deleted`, `deleted_at`).
- **Profile & Conversation Association Columns:**
  - `profiles.active_character_instance_id` (`String(64), nullable=True, ForeignKey("character_instances.id", ondelete="SET NULL")`): Tracks active character instance selection per Profile; `NULL` represents the immutable Neutral Assistant fallback. (There is no `profile_active_characters` table).
  - `conversations.character_instance_id` (`String(64), nullable=True, ForeignKey("character_instances.id", ondelete="RESTRICT")`): Explicit foreign key binding conversation history to its character instance while preserving historical `conversations.character_id`.
- **SQLite CHECK Constraints:** Enforce non-null preset and trait dimensions (0–100) for non-Neutral templates, while requiring strictly `NULL` traits and default preset for the Neutral Assistant fallback. Legacy placeholders are constrained to `status = 'archived'`, empty lore/prompt, and `NULL` traits.
- **Database Triggers:** Eight defense-in-depth SQLite triggers enforce invariants at the storage layer:
  1. `trg_character_templates_protect_neutral_update`: Blocks modifications to `neutral-assistant`.
  2. `trg_character_templates_protect_neutral_delete`: Blocks deletion of `neutral-assistant`.
  3. `trg_character_instances_immutable_provenance`: Enforces immutability of `(profile_id, is_legacy_placeholder, legacy_character_id, template_id, source_template_version)` on character instances.
  4. `trg_profiles_active_character_owner_insert`: Verifies `active_character_instance_id` belongs to the same Profile and is active, non-deleted, and non-legacy.
  5. `trg_profiles_active_character_owner_update`: Same verification on profile active character updates.
  6. `trg_character_instances_deactivate_clear_profile`: Automatically clears `active_character_instance_id` to `NULL` if the active instance is archived or soft-deleted.
  7. `trg_conversations_character_owner_insert`: Enforces same-Profile ownership and identity matching between `conversations` and `character_instances`.
  8. `trg_conversations_character_immutable_update`: Enforces permanent immutability of `(profile_id, character_id, character_instance_id)` on conversations.
- **Pre-Migration Safety & Dynamic Head Discovery:** Pre-migration SQLite WAL backup hook in `backend/app/core/storage.py::prepare_database_schema()` dynamically discovers the Alembic head and creates a verified pre-migration backup before upgrading existing databases.
- **Loss-Aware Fail-Closed Downgrade:** Migration 009 `downgrade()` deterministically compares substantive attributes of `character_templates` against `SEED_TEMPLATES` (excluding incidental timestamp metadata) and checks for user-created instances or active selections; refuses downgrade with `RuntimeError` on modified templates, active selections, or existing instances, preserving all user data and schema intact.

### 3.2 Models, Schemas & Personality Presets

- **Models:** Defined in `backend/app/models/character_template.py` (`CharacterTemplate`) and `backend/app/models/character_instance.py` (`CharacterInstance`), exported via `backend/app/models/__init__.py`, and integrated with `backend/app/models/profile.py` and `backend/app/models/conversation.py`.
- **Eight Continuous Trait Dimensions:**
  - `warmth` (0–100 integer): Empathy, friendliness, and emotional warmth.
  - `teasing` (0–100 integer): Playfulness, banter, and lighthearted sarcasm.
  - `guardedness` (0–100 integer): Emotional reserve and boundary maintenance.
  - `directness` (0–100 integer): Candor, frankness, and communication directness.
  - `expressiveness` (0–100 integer): Emotional and linguistic expressiveness.
  - `affection` (0–100 integer): Affectionate phrasing and emotional closeness.
  - `formality` (0–100 integer): Grammatical and stylistic formality.
  - `verbosity` (0–100 integer): Sentence length and elaboration depth.
- **Approved Presets:** `custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`. Presets provide initial baseline traits. Selecting a preset initializes the instance traits from preset baseline values.
- **Precedence Order:** Non-custom preset selects preset baseline; custom or omitted preset selects template baseline; explicit trait vector overrides baseline values (requires complete 8-dimensional `CharacterTraitVector`; partial vectors are rejected by Pydantic validation).

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
- `GET /api/v1/characters/active` — Get active character state (`ActiveCharacterStateOut` containing `is_neutral_fallback: bool`) for authenticated Profile.
- `PUT /api/v1/characters/active` — Select active character instance for Profile using request body `{"character_id": "<instance_id> | 'default' | 'neutral-assistant'"}`.
- `POST /api/v1/characters/active/reset-neutral` — Explicitly reset Profile's active character to Neutral Assistant.

### 3.4 Runtime Persona Resolution & Security Boundaries

- **Runtime Persona Resolution:** The orchestrator and service layer (`backend/app/services/character_service.py::resolve_turn_persona_prompt()`) resolve the bound character identity for the conversation:
  - If bound to Neutral Assistant or a legacy placeholder: returns `DEFAULT_PERSONA` directly without custom persona framing.
  - If bound to an active Character Instance: composes the system prompt with trusted `DEFAULT_PERSONA` top-level instructions, followed by a bounded `<character_persona>` block containing sanitized instance metadata (`name`, `summary`, `system_prompt`, `lore`).
- **Trust Boundaries & Enforcement:** Profile isolation and security boundaries are enforced deterministically by backend bearer-token authentication, SQLite Foreign Keys, and database triggers. User-editable Character persona text is treated strictly as lower-trust configuration data; delimiter tag escaping (`</character_persona>`, `<character_persona>`, `</retrieved_memories>`, `<retrieved_memories>`) provides defense-in-depth against structural breakouts, but delimiter escaping alone does not constitute complete prompt-injection security. The system prompt explicitly instructs the LLM that the persona block cannot override safety rules, claim system authority, or cross Profile boundaries.

### 3.5 Client Contract & SDK Parity

- **OpenAPI 3.1 Specification:** All 11 character routes and DTOs synchronized in `contracts/openapi/openapi.json`.
- **Flutter Companion API SDK:** Complete Dart DTO schemas and `CompanionClient` character methods implemented in `frontend/flutter/packages/companion_api` with verified contract parity (`scripts/check_dart_openapi_parity.py`).
- **Flutter Desktop Integration:** Windows host administration authority in `HostAdminSecretStore` uses direct .NET CLR access control (`[System.IO.Directory]::GetAccessControl`, `[System.IO.File]::GetAccessControl`) for robust ACL inspection without PowerShell module-loading dependencies.
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
6. **Multimodal Attachments Status:**
   - Image attachment backend: implemented.
   - React Web image-attachment interface: implemented.
   - Flutter Desktop image-upload button: disabled/planned.
   - Vision processing: dependent on a compatible vision-enabled model.

---

## 5. Implementation-Open Details (Decision Debt)

The normative architecture for D11 is frozen. The following implementation-level details are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

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
