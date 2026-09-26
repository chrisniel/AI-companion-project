# Characters, Personality, and Emotion Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.1).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** This document is authored as part of the staged documentation reconciliation. Primary canonical authority remains in [`docs/04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../MEMORY_AND_CHARACTER_ARCHITECTURE.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

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

### 2.1 The Five-Way Entity Decoupling (Decision D11)

In accordance with Decision D11, companion character systems enforce strict conceptual and architectural separation across five distinct layers:

1. **Profile (User Root Authority):**
   - Owns user identity, credentials, personal preferences, tasks, schedules, and memories.
   - Remains immutable across character changes. A Character never owns Profile data.
2. **Character (Lore & Identity Persona):**
   - Defines persona identity, backstory lore, display name, visual avatar/portrait assets, and system prompt framing.
   - May reference a preferred Personality style and preferred Voice configuration.
   - Characters do not own conversations; conversations reference characters.
3. **Personality (Behavioral Style & Traits):**
   - Distinct from lore or visual assets; governs behavioral mannerisms, verbosity, humor, formality, and communication traits.
   - Configurable independently from the character's backstory (e.g., the same character lore can operate with varying formality levels).
4. **Emotion (Transient Companion Tone Modulation):**
   - Lightweight, transient, conceptual companion state (e.g., cheerful, focused, reflective).
   - Serves solely to modulate conversational tone, phrasing nuance, or non-blocking UI expressions.
   - Strictly non-clinical: makes zero psychological, therapeutic, or sentient claims.
   - Operates without blocking assistant execution or tool invocation.
5. **Voice (Acoustic & Prosodic Configuration):**
   - Decoupled speech synthesis configuration (e.g., target voice identifier, speed, pitch, prosody).
   - Interchangeable across TTS providers without modifying character lore or personality schemas.

### 2.2 Relationship State Decoupling (PC Later)

- **Relationship State:** Represents long-term interaction continuity and familiarity depth.
- Formally decoupled from Personality and Emotion under Decision D11.
- Scheduled for **PC Later** (not a PC V1 milestone requirement).
- Strictly opt-in, disabled and hidden by default, and user-resettable at any time.

### 2.3 Character Switching Invariants

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
   - Host-backed storage for custom and predefined character profiles (name, avatar URI, lore, prompt injection templates).
2. **Decoupled Personality Configuration (PC V1):**
   - Structured style trait settings (e.g., verbosity scale, humor frequency, technical depth) evaluated during system prompt compilation.
3. **Lightweight Conceptual Emotion State (PC V1):**
   - Ephemeral companion state tracking that subtly influences tone without state-locking the assistant or impairing tool utility.
4. **Presence Readiness (PC V1):**
   - Bounded host contextual state (e.g., user active on desktop, idle, gaming mode active) providing non-intrusive awareness.

---

## 5. OPEN DESIGN

The following implementation choices remain intentionally open for architectural investigation:

- **Database Schemas:** Exact SQLite relational schema for characters, personality trait profiles, and voice mappings.
- **Personality Trait Taxonomy:** The exact dimensions and mathematical/categorical representation of personality sliders.
- **Emotion Dynamics & Decay:** The state space, trigger sensitivity, decay rate (e.g., returning to baseline mood over time), and prompt framing mechanics.
- **Presence Signals & Sensors:** Which host OS signals (window focus, input idle timers) feed presence without compromising user privacy.
- **Relationship State Mechanics (PC Later):** Progression algorithms, safety boundaries, and opt-in user controls.

---

## 6. Security & Ownership Boundaries

- **Profile Primacy:** Character profiles, personality configs, and emotion state are subordinate to the user Profile. A character has zero data authority over the user.
- **Privacy & Prompt Injection:** Character lore and system prompts must not override hard safety constraints or security policy gates established in `02_Data_and_Security/tool-permissions-and-actions.md`.
- **User Erasure:** Resetting or deleting a character persona never touches underlying user memories, tasks, or profile identity.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical Architecture Source:** [`docs/04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../MEMORY_AND_CHARACTER_ARCHITECTURE.md) (Retains primary authority until R11.4)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decision D11)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Rows 70, 71, 72, 73)
- **UI Design Presentation:** [`docs/05_Design/README.md`](../../05_Design/README.md) (Emotion presentation visual boundaries)
