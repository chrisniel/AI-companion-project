# Assistant and Conversations Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0018, ADR-0019)
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for the assistant turn and conversation domain.

---

## 1. Purpose & Scope

This specification defines the conversational turn lifecycle, thread orchestration, session context assembly, message persistence invariants, and interaction boundaries for the AI Companion assistant:
- Persistent conversation threads and message sequencing.
- Atomic turn preparation, concurrency locking, and token streaming.
- Multilingual interaction capabilities across English, Tagalog, and Japanese.
- Character-context binding and conversation switching invariants.
- Shared Context / Generation / Reasoning Budget Manager (`D-SHARED-AI-01`).
- Canonical raw conversation transcript authority and compaction reality (`D-SHARED-AI-02`).
- Host-mediated live turn streaming transport (`D-SHARED-CONV-02`).
- Causal conversation identity, branching, and forking (`D-SHARED-CONV-01`).
- Active turn control (`QUEUE`, `INTERRUPT_AND_SEND`, `FORK_FROM_HERE`) (`D-SHARED-CONV-03`).
- Safe turn regeneration semantics without automatic tool replay (`D-SHARED-CONV-03A`).

It governs the runtime flow between frontend user input and local generative model execution across PC Desktop, Web, and Mobile Companion clients.

---

## 2. Durable Architecture & Invariants

### 2.1 Profile Ownership & Character Context Binding

In accordance with Decision D7, ADR-0018, and D11 (`ADR-0008`, `ADR-0018`, `ADR-0012`):
- **Profile Ownership:** All conversations and message histories are strictly partitioned by the active user Profile (`profile_id`, migrated from legacy `owner_id` per `ADR-0018`). A single Account can host multiple Profiles, but conversations belong strictly to one Profile.
- **Single Character Context:** Under approved D11 architecture, each conversation references exactly one active Character persona context (`character_id`).
- **Permanent Turn Attribution:** Conversation history remains permanently bound to the Character under which turns were recorded.
- **Character Switching Invariants:** Switching active companion personas must **never**:
  - Rewrite past conversation history or alter message attribution.
  - Reassign turn speaker identities.
  - Silently mix multiple Character personas into a single active conversation thread.
- **No Implicit Multi-Character Threads:** Group or multi-character conversations are **not** an approved implicit behavior; any future multi-character experience requires explicit, independent architectural approval.

### 2.2 Client-Runtime Contract & Durable Turn Queue (ADR-0019)

Per `ADR-0019`, communication between client applications (Flutter Desktop, React Web, Android Companion) and the Local AI Runtime is governed by strict protocol and persistence boundaries:
- **Transport Separation:**
  - **REST / JSON:** Used for commands, queries, configuration updates, and turn submissions.
  - **Server-Sent Events (SSE):** Used for token completions and typed turn events (`token`, `tool_call`, `error`, `done`).
  - **WebSocket:** Dedicated to full-duplex conversational voice streaming (audio frames, barge-in, STT/TTS control).
- **Durable FIFO Turn Queue:**
  - The Local AI Runtime manages a durable FIFO turn queue per conversation.
  - **Client Disconnect Resilience:** If a client disconnects during SSE generation (e.g. browser tab closed, network drop), generative turn execution continues to completion in the background and is committed to SQLite.
  - **Reconnect Catch-Up:** Upon client reconnection, the client queries conversation history to retrieve the finalized turn without data loss or duplicate execution.
- **Deterministic Ordering:** Messages within a conversation are ordered strictly chronologically via a monotonically increasing `sequence_no` constrained by a unique database constraint (`conversation_id`, `sequence_no`).
- **Idempotency:** Client message submissions enforce deduplication using `client_message_id` with a scoped unique constraint (`conversation_id`, `client_message_id`).
- **Transactional Turn Preparation:** User message persistence, sequence assignment, and attachment claims occur in an atomic database transaction prior to initiating generative inference.
- **Concurrency Isolation:** Only one active generative turn may execute per conversation thread at any given time, enforced by conversation-level locking.
- **Provider Independence:** Context assembly and prompt compilation target abstract model interfaces (`LLMProvider`), decoupling conversation state from specific inference binaries or local server flags.

### 2.3 Multilingual Companion Interaction (PC V1)

- **Approved Capability:** In accordance with the Master Decision Register, PC V1 supports companion interaction across:
  - English
  - Tagalog / Filipino
  - Japanese
  - Conversational code-switching (e.g., Taglish)
- **Capability-Bounded Scope:** This capability governs the assistant's linguistic comprehension and conversational response generation. It is **not** a commitment to full localized UI translation of application menus, settings, or desktop controls.
- **Truthful Boundary:** Multilingual interaction quality is strictly bounded by the underlying active local LLM, STT, and TTS model capabilities.

### 2.4 Shared Context / Generation / Reasoning Budget Manager (D-SHARED-AI-01)

To prevent context overflow, model degradation, and runaway memory usage, all prompt construction is governed by an explicit Context Budget Manager:
- **Three Context Concepts:**
  1. *Native Model/Runtime Context Maximum:* The intrinsic architectural context limit supported by the model weights, tokenizer, and underlying runtime engine.
  2. *Configured Runtime Context:* The user-, profile-, or environment-configured baseline context limit allocated for execution.
  3. *Effective Safe Context:* The dynamic, safe operating context ceiling evaluated at runtime after accounting for host memory headroom, VRAM limits, and thermal/resource governor pressure (`D-PHONE-05A`). Hardware or resource pressure dynamically constrains the effective safe context; it does not redefine or alter the model's intrinsic/native maximum context.
- **Explicit Bounded Budget Allocations:** The context window is partitioned into explicit bounded categories (without freezing rigid permanent token allocations):
  - *System & Security Directives:* Fixed reserve for safety framing, untrusted content delimiters, and output format constraints.
  - *Character / Personality & Mood:* Persona prompt, core behavioral traits, and active bounded mood expression (`D11`).
  - *Retrieved Memory:* Bounded memory facts from canonical Memory and pending memory overlays (`D7`, `D-PHONE-08A`).
  - *Recent Conversation Turns:* Verbatim historical turns kept for conversational immediacy.
  - *Summaries & Retrieved Excerpts:* Rolling conversation summaries and relevant historical raw turn excerpts (`D-SHARED-AI-02`).
  - *Tool Schemas & Action Results:* Active typed tool definitions and confirmed adapter results (`D9`).
  - *Reasoning Allowance:* Bounded reasoning headroom where supported by the active model/runtime. Dedicated token headroom is budgeted for models that perform intermediate reasoning; the architecture does not require internal or hidden reasoning tokens to be exposed, persisted, or made user-visible.
  - *Response Generation Reserve:* Reserve sufficient configured output headroom to reduce avoidable truncation and support the requested response budget, without promising arbitrary response completion.
- **Budget Invariants:**
  - Recent history and reasoning tokens must **never** consume the entire context window at the expense of system rules or memory recall.
  - Tool-intent extraction operates under a tight, dedicated structured budget.
  - Active conversation state is persisted durably before any model unload occurs.
  - UI observability truthfully displays configured vs. effective safe context and the reason for any degradation. Unsafe developer knobs cannot bypass security boundaries.

### 2.5 Conversation History Authority, Compaction & Recall (D-SHARED-AI-02)

- **Raw Transcript Authority:** The full raw conversation transcript remains the authoritative, permanent record of conversation history. Context compaction never deletes, modifies, or truncates raw historical turns in persistent storage.
- **Derived Conversation Records:** Summaries are persisted **derived conversation records**, NOT canonical Memory. Summaries do not automatically promote into Memory (`D7`).
- **Rebuildable & Invalidation-Aware:** Summaries carry explicit provenance (conversation ID, branch ID, source turn range, schema revision, model ID, and summarization policy). If an upstream turn is edited or branched, invalidated summaries can be rebuilt on demand.
- **Compaction Mechanics:**
  - Automatic compaction triggers before context exhaustion based on the effective safe budget.
  - Explicit user-initiated compaction (`Compact context`) is supported.
  - Recent conversation turns are retained verbatim where practical; older context is represented via structured rolling summaries plus relevant retrieved raw excerpts.
  - Conversation search retrieves across summaries, raw turns, and metadata excerpts.
- **Host Authority & Mobile Sync:**
  - The PC Host owns canonical raw history and canonical derived summaries.
  - Disconnected Standalone Mobile may generate provisional local summaries for offline branches.
  - Mobile always synchronizes raw authoritative turns back to the Host upon reconnection; the Host reconciles raw turns and may accept, rebuild, or re-derive summaries.

### 2.6 Causal Conversation Identity, Branching & Transport (D-SHARED-CONV-01, D-SHARED-CONV-02)

- **Stable Identity & Causal Parentage (`D-SHARED-CONV-01`):**
  - Conversations maintain stable UUIDs; messages maintain stable client and runtime turn identifiers.
  - Turns preserve explicit causal DAG parentage: conceptual metadata includes `parent_turn_id`, `branch_id`, `fork_from_turn_id`, and `source_device_id`.
  - Sequential continuations append chronologically as normal sequential turns.
  - True concurrent continuations from the same earlier head turn (e.g. PC and Mobile operating simultaneously while disconnected) form explicit causal branches.
  - **No Timestamp Last-Write-Wins (LWW):** Branches must **never** be interleaved or overwritten based on wall-clock timestamps. Branch topologies are preserved; raw turns remain authoritative.
  - Disconnected Mobile branches persist locally in SQLite before synchronization.
  - The PC Host is the canonical reconciliation authority; the Host does not regenerate imported Mobile responses.
  - Branch UX presents user-friendly non-destructive resolution: notifying the user that conversation continued in two places, displaying branch turn counts, allowing continuation of the PC branch or Phone branch, and providing non-destructive branch comparison.
  - One Device to One Profile remains locked (`D-PHONE-01B`); One Profile to Multiple Mobile Phones remains **OPEN / DECISION DEBT**. No phone-to-phone canonical authority exists.
- **Host-Mediated Live Turn Streaming (`D-SHARED-CONV-02`):**
  - Connected Mobile chat uses authenticated REST turn submission + Server-Sent Events (SSE) live generation streaming. `GET /history` serves catch-up and reconnect recovery. WebSocket remains dedicated to full-duplex voice.
  - The PC Host owns active connected turn generation and continues execution across client disconnect.
  - Multiple authorized clients can observe a single in-flight Host generation stream without duplicate model execution.

### 2.7 Active Turn Control & Safe Regeneration (D-SHARED-CONV-03, D-SHARED-CONV-03A)

- **Active Turn Control Modes (`D-SHARED-CONV-03`):**
  - `QUEUE`: Active generation finishes first; the accepted queued user message is durably recorded and becomes the next turn. The queued message may be edited or removed until execution begins.
  - `INTERRUPT_AND_SEND`: Cancels active generative inference; persists visible partial response tagged as `INTERRUPTED`; immediately submits a new user turn with distinct causal identities. Stale discarded output is not resurrected. Interrupted content remains marked in context.
  - `FORK_FROM_HERE`: Explicit user branch from an earlier turn; not the default follow-up path.
  - *Side Effect Invariant:* Committed tool side effects (e.g., tasks created, alarms set) are **never** silently rolled back by prose interruption.
- **Safe Regeneration Semantics (`D-SHARED-CONV-03A`):**
  - Regeneration creates an alternative assistant response for the *same* user turn; it does not duplicate the user message.
  - Causal divergence occurs only when subsequent user turns continue from a chosen response alternative.
  - **No Automatic Replay of State-Changing Tools:** Regeneration must **never** automatically re-execute previously committed state-changing tool actions (Risk 1 or Risk 2). Existing action receipts are supplied to the regenerating model as context; executing a state-changing action again requires explicit new user intent.
  - `Edit & resend` creates an explicit new branch from edited user content. Exact database schema representation remains implementation-open.

### 2.8 Unified Interaction Surface & Extensible Language Registry (`D-PHONE-UX-03`, `D-PHONE-UX-09`, `D-SHARED-LANG-01`, `D-SHARED-LANG-02`)

- **Unified Companion Interaction Surface (`D-PHONE-UX-03`):**
  - Text messaging, Voice capture, camera still images, and file attachments converge on the same Character-bound conversation experience.
  - Modality transitions (e.g. speaking a prompt then reading a response, or attaching a photo then typing a query) occur seamlessly within the active conversation thread without fragmenting context across separate subsystem screens.
- **Extensible Language Registry (`D-SHARED-LANG-01`):**
  - Languages are managed through an extensible capability registry using standard identifiers (e.g. BCP-47 / ISO-639 where practical) rather than rigid closed enums; exact registry data structures and storage representations remain implementation-open.
  - Initial active targets include English (`en`), Tagalog/Filipino (`fil`), Japanese (`ja`), and natural conversational code-switching (e.g. Taglish).
  - Adding future language targets (e.g. Cebuano/Bisaya, Korean, German) expands registry capabilities without requiring architectural redesign.
- **Modality-Aware Language Qualification (`D-SHARED-LANG-02`):**
  - Language capability is advertised truthfully according to the specific, relevant components required for the active modality:
    - Text conversational capability requires qualified LLM comprehension and generation in that language; it does not require STT or TTS qualification.
    - Speech input capability requires a qualified STT engine for that language.
    - Spoken output synthesis requires a qualified TTS engine for that language.
    - Full local voice interaction requires concurrent qualification across all three constituent components (STT + LLM + TTS).
  - `Auto` detection mode may support bilingual interaction and code-switching where active constituent models qualify, without promising universal or unverified automatic code-switching across all components.
- **Conversational Language vs UI Localization Decoupling (`D-PHONE-UX-09`):**
  - Companion conversational understanding and speech generation are architecturally distinct from application UI string localization.
  - A user may converse with the companion in Tagalog or Japanese even when the client application UI menus and settings operate in English. Application UI localization requires translated resource bundles and is evaluated independently.

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

The following target capabilities are approved under Decision D1 and the Master Decision Register:

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

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, Decisions D1, D7, ADR-0018, D11)
- **Client-Runtime Contract ADR:** [`docs/04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md`](../decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **Work Breakdown Structure:** [`docs/02_Planning/00_Master/WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-API-001`, `PC-CLIENT-002`)
- **Memory Domain Specification:** [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](memory-and-personalization.md)
- **Multimodal Domain Specification:** [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](multimodal-and-media.md)
- **Character Domain Specification:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](characters-personality-and-emotion.md)
- **Tool Permissions & Actions Spec:** [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../02_Data_and_Security/tool-permissions-and-actions.md)
- **Mobile Capabilities & Runtime Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md)
- **Mobile Companion Shell & UX:** [`docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`](../../05_Design/08_Mobile_Companion_Shell_and_UX.md)
