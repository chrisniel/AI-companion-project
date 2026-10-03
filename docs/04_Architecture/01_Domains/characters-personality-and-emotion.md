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
   - **Character Template (App-Owned):** Shipped with the application or imported; defines base immutable persona lore, archetype backstory, default display name, and avatar artwork.
   - **Character Instance (Profile-Owned):**
     - is instantiated from a Character Template as an initial snapshot/configuration;
     - stores Profile-owned customizations and persistent Character state;
     - is NOT a live binding to the Template;
     - later Template updates MUST NOT silently mutate existing Character Instances.
3. **Conversation:**
   - Belongs to the user Profile.
   - References a specific Character persona; conversation history remains permanently bound to that Character as recorded.
4. **Personality Dimensions (8 Continuous Scales):**
   - **Eight Continuous Dimensions:** Exact frozen V1 dimensions are: Warmth, Teasing, Guardedness, Directness, Expressiveness, Affection, Formality, Verbosity. These are represented as 0-100 continuous values.
   - **Frozen Presets:** Custom, Warm Companion, Playful, Formal Advisor, Tsundere, Kuudere, Dandere, Yandere. Presets copy/initialize trait values and remain editable. Do not treat presets as rigid personality classes.
   - **Character Template:** App-owned/versioned initial template.
   - **Character Instance:** Profile-owned snapshot/configuration instantiated from a template. Future Template updates MUST NOT silently mutate existing Character instances. Do not describe Character instances as permanently or live "bound" to templates.
5. **Emotion & Mood Dynamics (Persistent & Bounded):**
   - **Persistent Simulated Mood:** Emotion/Mood is a persistent bounded simulated state across Runtime/Windows restart. It rebalances/decays based on elapsed time. Exact mathematical decay curve remains open. Do NOT mandate exponential decay in the durable architecture. Do NOT call PC V1 emotion state ephemeral.
   - **Mood Isolation:** Mood affects social presentation only. Never affects facts, permissions, tools, alarms, scheduler, privacy, queue priority or correctness.
6. **Neutral Assistant (Immutable Fallback):**
   - Immutable built-in fallback. Do not hardcode all sliders = 50 unless separately approved.
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

### 2.2 Character Switching Invariants

Switching active companion characters must **never**:
- Delete, alter, or hide user memories, profile attributes, or task records.
- Reattribute past conversation history or retroactively alter speaker attribution.
- Silently rewrite past turns or system messages.
- Implicitly mix multiple character personas into a single active conversation thread.

Conversations remain permanently bound to the `character_id` under which turns were recorded. Starting a session with a different character initiates a distinct conversation thread or explicitly bounded transition.

---

- **Character Deletion:** Character deletion should prefer archive/disable before purge so historical conversation identity remains interpretable.

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
   - Persistent companion state tracking that subtly influences tone without state-locking the assistant or impairing tool utility.

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
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) (Decision D11), [`WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-CHAR-001`, `PC-CHAR-002`)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **UI Design Presentation:** [`docs/05_Design/03_Character_Studio_and_Personality.md`](../../05_Design/03_Character_Studio_and_Personality.md), [`04_Emotion_and_Visual_Presence.md`](../../05_Design/04_Emotion_and_Visual_Presence.md)
