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
   - Owns user identity, user data, personal preferences, tasks, schedules, and memories.
   - In accordance with Decision D4, device authentication credentials remain separated from profile-owned personal data (Profile does not own client device credentials).
   - Character switching must never mutate or reassign Profile ownership or Profile-owned personal data. A Character never owns Profile data.
2. **Conversation:**
   - Belongs to the user Profile.
   - References a specific Character persona; conversation history remains permanently bound to that Character as recorded.
3. **Character (Lore & Identity Persona):**
   - Defines persona identity, backstory lore, display name, visual avatar/portrait assets, and persona/system-prompt composition.
   - May reference a preferred Personality style and preferred Voice configuration.
   - Characters do not own conversations; conversations reference characters.
4. **Personality (Behavioral Style & Traits):**
   - Distinct from lore or visual assets; governs behavioral mannerisms, verbosity, humor, formality, and communication traits.
   - Configurable independently from character backstory (e.g., the same character lore can operate with varying formality levels).
5. **Emotion (Transient Companion Tone Modulation):**
   - Lightweight, transient, conceptual companion state (e.g., cheerful, focused, reflective).
   - Serves solely to modulate conversational tone, phrasing nuance, or non-blocking UI expressions.
   - Strictly non-clinical: makes zero psychological, therapeutic, or sentient claims.
   - Operates without blocking assistant execution or tool invocation.
6. **Voice (Acoustic & Prosodic Configuration):**
   - Decoupled speech synthesis configuration (e.g., target voice identifier, speed, pitch, prosody).
   - Interchangeable across TTS providers without modifying character lore or personality schemas.
7. **Presence (Contextual & Presentation State):**
   - Distinct, bounded contextual and presentation concept reflecting companion and environment awareness.
   - Advanced Presence remains scheduled for **PC Later**; exact signals, sensor integrations, persistence models, and privacy boundaries remain OPEN DESIGN.
   - Existing PC V1 capabilities (such as Gaming / Low-Impact Resource Mode) may expose contextual host signals without implying a full Presence subsystem is implemented.
8. **Relationship State (Interaction Continuity — PC Later):**
   - Represents long-term interaction continuity and familiarity depth.
   - Formally decoupled from Personality and Emotion under Decision D11.
   - Scheduled for **PC Later** (not a PC V1 milestone requirement).
   - Strictly opt-in and hidden by default; user controls are required, while the exact reset lifecycle remains OPEN DESIGN.

### 2.2 Character Switching Invariants

Switching active companion characters must **never**:
- Delete, alter, or hide user memories, profile attributes, or task records.
- Reattribute past conversation history or retroactively alter speaker attribution.
- Silently rewrite past turns or system messages.
- Implicitly mix multiple character personas into a single active conversation thread.

Conversations remain permanently bound to the `character_id` under which turns were recorded. Starting a session with a different character initiates a distinct conversation thread or explicitly bounded transition.

---

## 3. Current Verified Implementation

Repository source code and frontend truthfulness test suites verify the following baseline reality:

### 3.1 Backend Data Model & Endpoints

- **Conversation Association:** In `app.models.conversation.Conversation`, conversations maintain a single string identifier:
  ```python
  character_id: Mapped[str] = mapped_column(String(64), nullable=False, default="default")
  ```
- **Backend Character Catalog:** `NOT IMPLEMENTED`. There is no `characters`, `personas`, `personalities`, or `emotions` table or ORM model in the backend SQLite schema.
- **Runtime Personality & Emotion Engines:** `NOT IMPLEMENTED`. The backend orchestrator operates with static prompt templates without dynamic trait weighting or emotional state tracking.

### 3.2 Frontend Implementation & Truthfulness Guards

- **Preview Component:** The frontend provides a `CharactersView` component in `frontend/web/src/components/workspace/CharactersView.tsx`.
- **Truthfulness Contract:** Verified by `frontend/web/src/test/phase8b3Truthfulness.test.tsx`:
  - Renders as an interactive visual *Preview* with Neutral Assistant fallback.
  - Does **not** import mock character persistence fixtures in production builds.
  - Does **not** maintain fake `activeCharacterId` persistence state or claim backend synchronization.
  - Does **not** bind unapproved voice synthesis engines.

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Decision D11:

1. **Persistent Character Configuration (PC V1):**
   - Host-backed storage for custom and predefined character profiles (e.g., name, avatar reference, lore, persona/system-prompt composition, personality and voice references). Exact schema remains OPEN DESIGN.
2. **Decoupled Personality Configuration (PC V1):**
   - Structured style trait settings (e.g., verbosity scale, humor frequency, technical depth) evaluated during persona/system-prompt composition.
3. **Lightweight Conceptual Emotion State (PC V1):**
   - Ephemeral companion state tracking that subtly influences tone without state-locking the assistant or impairing tool utility.

---

## 5. OPEN DESIGN

The following implementation choices remain intentionally open for architectural investigation:

- **Database Schemas:** Exact SQLite relational schema, column definitions, and foreign keys for character profiles, personality traits, and voice associations.
- **Personality Trait Taxonomy:** The exact dimensions and mathematical/categorical representation of personality sliders.
- **Emotion Dynamics & Decay:** The state space, trigger sensitivity, decay rate (e.g., returning to baseline mood over time), and prompt framing mechanics.
- **Presence Architecture:** Signals, host sensors, privacy controls, and presentation models for PC Later.
- **Relationship State Mechanics (PC Later):** Progression algorithms, safety boundaries, user controls, and lifecycle.
- **Character Deletion Handling:** Deleting or resetting a Character must never delete Profile-owned data; exact handling of Character-scoped memories during Character deletion remains user-controlled and open design.

---

## 6. Security & Ownership Boundaries

- **Profile Primacy:** Character profiles, personality configs, and emotion state are subordinate to the user Profile. A character has zero data authority over the user.
- **Privacy & Prompt Injection:** Character lore and persona prompts must not override hard safety constraints or security policy gates established in `02_Data_and_Security/tool-permissions-and-actions.md`.
- **User Erasure:** Resetting or deleting a character persona never touches underlying user memories, tasks, or profile identity.

---

## 7. Canonical Relationships & Cross-Links

- **Legacy Technical Reference:** [`docs/04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../MEMORY_AND_CHARACTER_ARCHITECTURE.md) (Subordinate memory and character scoping reference)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§4 / §7, Decision D11)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Character Configuration Persistence, Separate Personality Configuration, Lightweight Conceptual Emotion, Relationship State)
- **UI Design Presentation:** [`docs/05_Design/README.md`](../../05_Design/README.md) (Emotion presentation visual boundaries)
