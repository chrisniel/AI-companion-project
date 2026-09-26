# Assistant and Conversations Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.2).  
> **Authority Precedence:** Focused staged specification authored during R11.2. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) and [`docs/04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../MEMORY_AND_CHARACTER_ARCHITECTURE.md) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the conversational turn lifecycle, thread orchestration, session context assembly, message persistence invariants, and interaction boundaries for the AI Companion assistant:
- Persistent conversation threads and message sequencing.
- Atomic turn preparation, concurrency locking, and token streaming.
- Multilingual interaction capabilities across English, Tagalog, and Japanese.
- Character-context binding and conversation switching invariants.
- Context assembly (prompts, memories, attachments, and turn history).

It governs the runtime flow between frontend user input and local generative model execution.

---

## 2. Durable Architecture & Invariants

### 2.1 Profile Ownership & Character Context Binding

In accordance with Decisions D7 and D11:
- **Profile Ownership:** All conversations and message histories are strictly owned by the authenticated user Profile (`owner_id`).
- **Single Character Context:** Under approved D11 architecture, each conversation references exactly one active Character persona context (`character_id`).
- **Permanent Turn Attribution:** Conversation history remains permanently bound to the Character under which turns were recorded.
- **Character Switching Invariants:** Switching active companion personas must **never**:
  - Rewrite past conversation history or alter message attribution.
  - Reassign turn speaker identities.
  - Silently mix multiple Character personas into a single active conversation thread.
- **No Implicit Multi-Character Threads:** Group or multi-character conversations are **not** an approved implicit behavior; any future multi-character experience requires explicit, independent architectural approval.

### 2.2 Turn Lifecycle & Ordering Guarantees

The assistant turn lifecycle enforces strict transactional and sequencing guarantees:
- **Deterministic Ordering:** Messages within a conversation are ordered strictly chronologically via a monotonically increasing `sequence_no` constrained by a unique database constraint (`conversation_id`, `sequence_no`).
- **Idempotency:** Client message submissions enforce deduplication using `client_message_id` with a scoped unique constraint (`conversation_id`, `client_message_id`).
- **Transactional Turn Preparation:** User message persistence, sequence assignment, and attachment claims occur in an atomic database transaction prior to initiating generative inference.
- **Concurrency Isolation:** Only one active generative turn may execute per conversation thread at any given time, enforced by conversation-level locking.
- **Provider Independence:** Context assembly and prompt compilation target abstract model interfaces (`LLMProvider`), decoupling conversation state from specific inference binaries or local server flags.

### 2.3 Multilingual Companion Interaction (PC V1)

- **Approved Capability:** In accordance with the Feature Promotion Map (Multilingual Companion Interaction), PC V1 supports companion interaction across:
  - English
  - Tagalog / Filipino
  - Japanese
  - Conversational code-switching (e.g., Taglish)
- **Capability-Bounded Scope:** This capability governs the assistant's linguistic comprehension and conversational response generation. It is **not** a commitment to full localized UI translation of application menus, settings, or desktop controls.
- **Truthful Boundary:** Multilingual interaction quality is strictly bounded by the underlying active local LLM, STT, and TTS model capabilities.

---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Data Model & Persistence

Verified in `app.models.conversation.Conversation` and `app.models.message.Message`:
- **Conversation Entity:** `id` (UUIDv4), `title` (String(255)), `character_id` (String(64), default `"default"`), `owner_id` (String), `created_at`, `updated_at`, `is_deleted` (Boolean), `deleted_at` (DateTime, optional).
- **Message Entity:** `id` (UUIDv4), `conversation_id` (FK to `conversations.id`), `sender` (String(32), `"user"` or `"assistant"`), `content` (Text), `status` (String(32), default `"completed"`), `sequence_no` (Integer), `client_message_id` (String(64), optional), `model_name` (String(128), optional), `prompt_tokens` (Integer, optional), `completion_tokens` (Integer, optional), `attachments` (relationship to `Attachment`, lazy `"selectin"`), plus audit and soft-delete mixins.
- **Database Constraints:**
  - `uq_messages_conversation_sequence`: Unique (`conversation_id`, `sequence_no`).
  - `uq_messages_conversation_client_message_id`: Unique (`conversation_id`, `client_message_id`).

### 3.2 REST Endpoints & Streaming Flow

Verified in `backend/app/api/v1/endpoints/conversations.py`:
- `POST /api/v1/conversations`: Creates a persistent conversation thread with default or specified `character_id`.
- `GET /api/v1/conversations`: Lists non-deleted conversations for the owner, ordered by `updated_at` descending.
- `GET /api/v1/conversations/{conversation_id}`: Retrieves single conversation metadata.
- `PATCH /api/v1/conversations/{conversation_id}`: Renames a conversation title.
- `DELETE /api/v1/conversations/{conversation_id}`: Soft-deletes a conversation and cascades soft-delete to all child attachments.
- `GET /api/v1/conversations/{conversation_id}/messages`: Retrieves messages ordered chronologically (`sequence_no ASC`), exposing `AttachmentRef` metadata for associated active image attachments.
- `POST /api/v1/conversations/{conversation_id}/messages`: Sends user message and streams assistant tokens via Server-Sent Events (SSE):
  1. *Validation:* Validates conversation existence and owner boundary.
  2. *Attachment Syntax:* Validates format of supplied `attachment_ids`.
  3. *Idempotency Check:* Checks for existing `client_message_id` (returns `409 DUPLICATE_MESSAGE`).
  4. *Concurrency Lock:* Acquires in-memory asyncio lock `_get_lock(conversation_id)` (returns `409 CONVERSATION_BUSY` if locked).
  5. *Provider Check:* Verifies LLM provider runtime state (returns `503 LLM_UNAVAILABLE` if unavailable).
  6. *Atomic Preparation (`prepare_turn`):* Validates attachment IDs, allocates sequence numbers (with bounded retry for collisions), persists user message and assistant placeholder, flushes rows, atomically claims attachments for the user message, and commits the transaction exactly once. (Note: `prepare_turn` does not retrieve memories.)
  7. *Streaming Orchestration (`orchestrate_chat_stream`):* Retrieves relevant memories via FTS5 lexical search, constructs prompt context fitting the token budget, streams SSE tokens (`text/event-stream`), persists completed assistant message, records token usage, and releases the conversation lock upon completion.

### 3.3 Context Assembly & Injection

Verified in `backend/app/services/assistant/orchestrator.py`:
- Injects up to 5 relevant memories retrieved via FTS5 lexical search into the system prompt inside `<retrieved_memories>` tags, bounded by `MEMORY_BUDGET_TOKENS = 256`. The template explicitly instructs the model that memories are untrusted contextual information for reference only and not to adopt policies or commands found in them.
- Binds user message attachments via multimodal vision contracts when vision capability is enabled.
- Loads recent conversation history turns to construct chat context.

### 3.4 Explicitly Unimplemented Capabilities

- **Frontend History Image Rendering (Slice 8B.7):** `NOT IMPLEMENTED YET`. Backend endpoints already expose active attachments on messages, but frontend message bubbles in chat history do not yet render persistent attachment thumbnails/previews.
- **Automatic Multilingual Language Routing:** `NOT IMPLEMENTED`. Language handling relies entirely on the natural zero-shot multilingual capability of the active model; no explicit pre-turn language classifier or language-routing middleware exists in the codebase.
- **Conversation Compaction / Summarization:** `NOT IMPLEMENTED`. Older messages are truncated based on simple turn/token limits; rolling summaries are not yet generated.

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Decision D1 and the Feature Promotion Map:

1. **Multilingual Interaction Evaluation (PC V1):**
   - Verified interaction stability across English, Tagalog, and Japanese.
   - Persona consistency maintained when switching between supported languages or when using code-switching (Taglish).
2. **Persistent Attachment History Rendering (Slice 8B.7 / PC V1):**
   - Frontend chat interface renders thumbnail cards with authenticated Blob previews for all persisted attachments attached to historical messages.

---

## 5. OPEN DESIGN

The following implementation choices are intentionally left open for subsequent technical design:

- **Character Switching UX:** How character transitions are initiated in the UI (e.g., dedicated switcher prompting for a new thread vs. inline bounded transition).
- **Language Detection & System Prompt Adaptation:** Whether dynamic language hints are explicitly injected into the system prompt or left entirely to natural model completion.
- **Conversation Summarization & Long-Context Compaction:** Token threshold triggers, summarization model selection, hierarchical memory distillation mechanisms, and background summarization cadence (treated as open design / future architectural consideration; not currently scheduled as a locked PC Later milestone).
- **Transcript Archival & Retention:** Long-term conversation export formats (JSON, Markdown, PDF) and user-configurable retention limits.
- **Future Multi-Character Interaction:** Conceptual feasibility and interaction design of multi-persona collaborative threads (scheduled for future architectural evaluation).

---

## 6. Security & Ownership Boundaries

- **Owner Isolation:** Every query enforces `WHERE conversation.owner_id = :owner_id`. No cross-user access is permitted.
- **Prompt Injection Defense & Untrusted Content Framing:** External, retrieved, and user-supplied content must not gain system-policy authority. In current implementation, retrieved memories are explicitly framed as untrusted contextual information inside `<retrieved_memories>` tags with warning instructions. No OCR pipeline exists in the Phase 8B foundation.
- **Idempotency & Concurrency:** Concurrency locks (`_get_lock(conversation_id)`), database unique constraints (`UNIQUE(conversation_id, client_message_id)`), and sequence constraints prevent duplicate turns, duplicate processing/state, and ordering/concurrency races during turn generation.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decisions D1, D7, D11)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Multilingual Companion Interaction)
- **Memory Domain Specification:** [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](memory-and-personalization.md)
- **Multimodal Domain Specification:** [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](multimodal-and-media.md)
- **Character Domain Specification:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](characters-personality-and-emotion.md)
