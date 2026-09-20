# AI Companion — Memory and Character Architecture Specification

> **Document Role:** Canonical architecture specification for profile-first memory, character scoping, and personal data ownership.  
> **Status:** Active Canonical (Decisions D7, D8 Locked)  
> **Last Updated:** 2026-09-20 (Reconciliation Pass R3)

---

## 1. Executive Summary & Ownership Invariants

AI Companion enforces a strict **Profile-First** data ownership model:

```text
Profile (User Identity)
  ├── Canonical Personal Data (Conversations, Tasks, Reminders, Profile Preferences)
  └── Memories (Persistent Facts)
        ├── Scope: PROFILE (Default — available across all characters/personas)
        └── Scope: CHARACTER (Optional — associated with character_id, retrieved only in context)

Character (Persona Configuration)
  ├── Persona Definition (System prompt, personality traits, background lore)
  ├── Presentation (Avatar image/GIF, Live2D/VRM configuration, theme cues)
  └── Voice Profile (TTS voice ID, speed, prosody, style hints)
```

> [!IMPORTANT]
> **Core Ownership Invariants (Decision D7):**
> 1. **User identity and personal data belong to the Profile.** Characters never own the user's canonical identity, conversation history, task items, or memory records.
> 2. **Profile memories remain available across characters by default.** The knowledge that the user loves coffee or works as an engineer is personal context, not character-specific lore.
> 3. **Character-scoped memories still belong to the Profile.** Even when a memory is tagged with a `character_id` (e.g., shared in-character roleplay lore), it remains under profile ownership and deletion control.
> 4. **Persona switching is purely presentational.** Switching the active character/persona alters the perspective, tone, avatar, and speaking style of the assistant, but **never** deletes, truncates, or resets the user's memories, conversation threads, or tasks.

---

## 2. Memory Scoping Model

The architecture defines two distinct scoping tiers for persistent memories:

### 2.1 Scope: `PROFILE` (Default)
- **Definition:** Factual information, user preferences, habits, biographical details, and general context about the human user.
- **Cross-Character Availability:** Injected into context across all active characters and personas.
- **Examples:**
  - *"User prefers concise technical explanations without conversational filler."*
  - *"User lives in UTC+8 time zone."*
  - *"User is allergic to peanuts."*

### 2.2 Scope: `CHARACTER` (Optional)
- **Definition:** Context, shared narratives, or interactions specific to a particular character persona.
- **Context Isolation:** Retrieved and assembled into the prompt context **only** when the conversation is active with that specific `character_id`.
- **Examples:**
  - *"User agreed to call Character A 'Sensei' during study sessions."*
  - *"Character B's ongoing sci-fi narrative campaign plot points."*

---

## 3. Persistent Entities & Ownership Relationships

```text
┌────────────────────────────────────────────────────────┐
│                        Profile                         │
│                    (User Identity)                     │
└───────┬──────────────┬───────────────┬──────────────┬──┘
        │ 1            │ 1             │ 1            │ 1
        │              │               │              │
        │ N            │ N             │ N            │ N
        ▼              ▼               ▼              ▼
┌──────────────┐┌──────────────┐┌──────────────┐┌──────────────┐
│ Conversation ││    Memory    ││     Task     ││   Reminder   │
│              ││              ││              ││              │
│ - id         ││ - id         ││ - id         ││ - id         │
│ - owner_id   ││ - owner_id   ││ - owner_id   ││ - owner_id   │
│ - character_id│ - content    ││ - title      ││ - task_id    │
│              ││ - category   ││ - status     ││ - due_at     │
│              ││ - scope*     ││              ││              │
└──────────────┘└──────────────┘└──────────────┘└──────────────┘
```

### 3.1 Conversations
- Conversations are owned by the Profile (`owner_id`).
- Each conversation thread records an associated `character_id` indicating the persona context in which the interaction took place.
- Multiple conversations can reference the same or different characters while remaining within the user's unified history.

### 3.2 Tasks & Reminders
- Tasks and reminders are owned exclusively by the Profile (`owner_id`).
- Characters may assist in scheduling, reviewing, or reminding the user about tasks, but tasks never belong to a character. Changing characters does not alter task deadlines or states.

### 3.3 Character Persona Boundaries
- A Character defines **how** the assistant communicates and presents itself:
  - **Persona Definition:** Base system prompt, personality style, communication traits, background lore.
  - **Presentation:** Visual avatar (static image, animated GIF, or future Live2D/VRM configuration), accent colors, UI theme cues.
  - **Voice Configuration:** TTS provider selection, voice ID, speaking rate, pitch, and prosody parameters.

---

## 4. Current Implementation Reality vs. Future Architecture

To ensure truthfulness between active code and design specifications:

### 4.1 Implemented Reality (SQLite + FTS5 Baseline)
The active repository implementation (`backend/app/models/memory.py`, `backend/app/models/conversation.py`, Alembic migration `005_scope_message_constraints`):
- **Memories Table:** Persists fields:
  - `id` (UUID primary key)
  - `owner_id` (owning profile identifier, Decision D8)
  - `category` (e.g., `"fact"`, `"preference"`)
  - `content` (text payload)
  - `importance` (float weighting)
  - `source_type` (e.g., `"manual"`, `"conversation"`)
  - `source_message_id` (optional origin message link)
  - `user_verified` (boolean verification flag)
  - `created_at`, `updated_at`, `is_deleted` (audit timestamps and soft-delete)
- **FTS5 Virtual Table:** Full-text lexical search index (`memories_fts`) enables keyword retrieval against memory content.
- **Conversations Table:** Persists `owner_id` and `character_id: String(64)`.

### 4.2 Non-Implemented Boundaries (Truthful Accounting)
1. **Memory Scope Column:** The `memories` table currently lacks a dedicated `scope` column or `character_id` foreign key. All active memories behave effectively as profile-scoped. The two-tier `PROFILE` vs `CHARACTER` scoping is an approved architectural invariant (Decision D7) that will be activated when character backend persistence is introduced.
2. **Character Backend Persistence:** Character persistence in the backend is **not currently implemented**.
   - No `characters` table or Alembic migration exists in `backend/app/models/` or `backend/alembic/`.
   - Characters currently exist solely as client-side configuration: TypeScript interfaces (`CharacterConfig`), React component state, and test fixtures (`frontend/web/src/mock/characterData.ts`).
   - The backend accepts incoming `character_id` strings on conversation endpoints, but does not yet validate them against a persistent backend character catalog.

---

## 5. Retrieval & Trust Framing

When injecting persistent memories into the LLM prompt context during conversation generation:
1. **Lexical Filtering:** Active conversation queries trigger FTS5 search against user memories.
2. **Context Budgeting:** The `AssistantOrchestrator` limits injected memories to a strict token budget (e.g., ~500 tokens) to prevent context exhaustion.
3. **Trust Framing (Prompt Isolation):**
   - Retrieved memories are wrapped in a dedicated system context block clearly demarcated as stored user facts.
   - Memories are treated as contextual data, not executable system instructions.
   - User prompt content cannot overwrite stored memories without passing through validated memory endpoints.
