# Memory and Personalization Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0008, ADR-0018)
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for the memory and personalization domain.

---

## 1. Purpose & Scope

This specification defines the storage, retrieval, lifecycle, and privacy boundaries for long-term companion memory and personalization:
- Persistent storage of user facts, preferences, and biographical context.
- Lexical and semantic retrieval mechanisms for context injection.
- Selective automatic memory capture policies under deterministic security governance.
- Conceptual scoping between global user profile memories and character-specific interaction memories.
- User transparency, verification, correction, and forgetting rights.
- Unified Context Retrieval across distinct context sources (`D-SHARED-AI-03`).
- Selective offline canonical Memory replica on Mobile (`D-PHONE-09`).
- Offline explicit Memory intent outbox and Host D7 reconciliation (`D-PHONE-08`).
- Local pending Memory overlay for conversational continuity (`D-PHONE-08A`).

It governs the boundary between ephemeral conversation turns and durable companion knowledge across PC Desktop, Web, and Mobile Companion clients.

---

## 2. Durable Architecture & Invariants

### 2.1 Profile Ownership of All Memories (Decision D7 & ADR-0018)

- **Root Authority:** In accordance with Decision D7 and ADR-0018 (superseding historical D8 / ADR-0009), all memories are strictly partitioned and owned by the user Profile (`profile_id`, migrated from legacy `owner_id`).
- **Conceptual Scoping:** Architecture recognizes two visibility scopes:
  1. **`PROFILE` Scope (Global to Profile):** Facts, preferences, and biographical details applicable across all companion personas for this profile (e.g., user's timezone, dietary preferences, occupation).
  2. **`CHARACTER` Scope (Persona-Bound):** Context, shared experiences, or relationship notes relevant specifically to interactions with a designated character persona.
- **Subordination:** Character-scoped memories remain completely owned by the Profile and managed by the user. Characters never possess independent, un-deletable, or hidden memory stores.

### 2.2 User Agency, Transparency & Forgetting

- **Transparency:** All stored memories must be inspectable and reviewable by the user through dedicated management interfaces.
- **User Control & Deletion:** The user can inspect, correct, delete/forget, and control stored memories. Deletion takes immediate effect across retrieval indices.
- **Context Injection Security:** Retrieved memories are injected into LLM context as untrusted user-supplied facts inside `<retrieved_memories>` tags. Memories must never override core system prompts, character invariants, or safety policies.
- **Bounded Context Recall:** Injected memories are strictly bounded by token budgets (`MEMORY_BUDGET_TOKENS`), prioritizing high-relevance matches.

### 2.3 Frozen Memory Extraction & Management Policy

The following behavioral invariants dictate how the runtime processes memories:

- **Cloud Permission Boundary:** Cloud conversational inference permission != Cloud automatic Memory processing permission.
- **Local-Only Extraction:** Automatic Memory extraction remains local-only by default even when cloud chat is enabled.
- **Future Cloud Processing:** Future cloud Memory processing requires separate explicit permission + visible egress.
- **Explicit Triggers:** Explicit "remember this" commands are first-class and bypass automatic heuristics.
- **Extraction Pipeline:** Completed turn → candidate extraction → structured candidate → deterministic Memory policy.
- **Policy Outcomes:** Candidates result in AUTO-SAVE, PROPOSE, or IGNORE.
- **Secrets Boundary:** Secrets are never processed as ordinary Memory.
- **Provenance & Confidence:** Provenance is conceptually mandatory. Confidence represents extraction confidence, not objective truth probability.
- **Reconciliation:** Related memories must reconcile as NEW, MERGE, UPDATE, or CONFLICT.
- **Correction Authority:** Explicit user correction has high authority.
- **Lifecycle & Expiry:** Memories support temporary validity, expiry, and revalidation. Ephemeral statements (e.g., "I'm sick today") must carry expiration metadata or require revalidation. Ambiguous statements or emotional vents must never silently become permanent profile facts. Expired Memory is excluded immediately.
- **Forget Semantics:** "Forget" removes the memory from retrieval and context immediately; physical purge may follow later. Tombstones prevent known resurrection from restore.
- **Data Partitions:** Conversation History, Memory, and Emotion remain distinct architectural concepts.
- **Open Design:** Exact schema names remain open.

### 2.4 Retrieval Technology Independence

- The durable architectural requirement is **persistent, queryable memory retrieval under profile authority**.
- Specific search mechanisms (e.g., SQLite FTS5 full-text search, BM25 ranking, or vector embeddings) are implementation strategies, **not** immutable architectural invariants.

### 2.5 Unified Context Retrieval Across Distinct Sources (D-SHARED-AI-03)

In accordance with Decision `D-SHARED-AI-03`, prompt context retrieval spans four distinct, separately searchable information sources:
1. *Canonical Memory:* Durable, verified profile- and character-scoped memory facts stored in the canonical Memory store (`D7`).
2. *Conversation Summaries:* Persisted derived conversation records summarizing older conversation turns (`D-SHARED-AI-02`).
3. *Raw Historical Conversation Excerpts:* Verbatim historical turns retrieved from the authoritative raw conversation transcript.
4. *Pending Local Context:* Transient local context including pending explicit memory intents (`D-PHONE-08`) and unsynced local branch turns.

- **Do NOT Collapse Into One Store:** The architecture strictly prohibits collapsing or flattening these distinct context sources into a single generic "Memory" database. Each source preserves its distinct lifecycle, provenance, verification status, and invalidation rules.
- **Retrieval Invariants:**
  - Strict Profile and Character isolation: retrieval queries never leak across profile boundaries or unauthorized character boundaries.
  - Bounded retrieval governed by the Context Budget Manager (`D-SHARED-AI-01`).
  - Retrieval technology remains replaceable (lexical FTS5, BM25, embeddings/vector).

### 2.6 Mobile Offline Memory Replica & Pending Intent Outbox (D-PHONE-08, D-PHONE-08A, D-PHONE-09)

In accordance with Decisions `D-PHONE-08`, `D-PHONE-08A`, and `D-PHONE-09`:

- **Selective Offline Memory Replica (`D-PHONE-09`):**
  - Mobile maintains a bounded, durable subset of canonical Memory locally for offline context injection.
  - Replica contents may include: explicitly pinned memories (`Always available on this phone`), bounded Profile continuity set, Character memories for cached personas, and recently fetched relevant memories.
  - Pinned memories survive ordinary local cache eviction.
  - *Read-Only Invariant:* The cached canonical Memory replica on Mobile is strictly **read-only** while offline. Disconnected Mobile cannot directly write, mutate, or delete canonical Memory records.
  - *Revocation & Invalidation Authority:* Host-side revocation, purge, deletion, or forget state becomes authoritative immediately on the PC Host. A Mobile replica invalidates or purges affected cached state when it receives or observes the authoritative revocation, purge, or tombstone state according to the approved disconnected/reconnection security lifecycle.
- **Offline Explicit Memory Intent Outbox (`D-PHONE-08`):**
  - When the user explicitly requests memory creation while offline (e.g. "Remember that my car keys are in the desk drawer"), Mobile does **not** write directly to canonical Memory.
  - Instead, the request creates a durable, typed Memory Intent record with `PENDING_SYNC` status in the Mobile Outbox.
  - Upon reconnection to the PC Host, pending intents are submitted to the PC Host D7 Memory engine for canonical reconciliation (`NEW`, `MERGE`, `UPDATE`, `CONFLICT`, or `REJECT`).
  - *No Autonomous Offline Memory Extraction:* Ordinary offline conversations do **not** autonomously extract or generate canonical memories. Automatic memory extraction remains governed by the PC Host D7 pipeline.
- **Pending Memory Overlay (`D-PHONE-08A`):**
  - To maintain conversational naturalness and continuity during standalone mobile sessions, pending explicit Memory intents are exposed immediately to the local assistant as a **local pending memory overlay**.
  - Overlay items carry explicit provenance tags distinguishing them from verified canonical Memory.
  - Upon reconnection and successful Host reconciliation, accepted canonical memories replace the local overlay.

### 2.7 External Domain Boundaries: Health and Vision Decoupling (`D-PHONE-15C`, `D-SHARED-VISION-01`)

- **Health Context is NOT Memory (`D-PHONE-15C`):** Biometric sensor readings, wearable statistics (steps, sleep, heart rate), trends, and time-window summaries belong strictly to the Health Context domain ([`health-and-wearables.md`](../03_Integrations/health-and-wearables.md)). Biometric data is never automatically promoted into canonical D7 Memory records. Only explicit user declarations regarding health (e.g. *"Remember that I am training for a half-marathon"*) may become canonical Profile Memory.
- **Vision Observations Do NOT Automatically Create Memory (`D-SHARED-VISION-01`):** Image turn contents, visual descriptions, and camera observations remain scoped to conversation turn history and media attachments ([`multimodal-and-media.md`](multimodal-and-media.md)). Visual perception must never autonomously persist permanent D7 Memory records without explicit user intent and D7 policy evaluation.

---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Implemented Data Model & Storage

Memories are persisted in SQLite via SQLAlchemy ORM (`app.models.memory.Memory`) and indexed via an FTS5 virtual table:
- **Core Entity Fields:** `id` (UUIDv4), `owner_id` (String), `category` (String(32), default `"fact"`), `content` (Text), `importance` (Float, default `1.0`), `source_type` (String(32), default `"manual"`), `source_message_id` (String(36), optional), `user_verified` (Boolean, default `True`).
- **Audit & Soft-Delete Mixins:** `created_at`, `updated_at`, `is_deleted` (Boolean), `deleted_at` (DateTime, optional).
- **Scope Fields State:** `NOT IMPLEMENTED IN SCHEMA`. The current database schema does **not** yet contain explicit `scope` or `character_id` columns; all current memories function at the profile level.

### 3.2 Implemented Retrieval & Prompt Assembly

Verified in `app.services.memory.retriever`:
- **FTS5 Lexical Search:** Uses a SQLite `memories_fts` virtual table joined on `id` against non-deleted memories.
- **Multilingual Token Sanitation:** The query sanitizer extracts safe alphanumeric, Latin-extended, CJK, and Hangul word tokens, explicitly filtering FTS5 operators (`AND`, `OR`, `NOT`).
- **Prompt Injection Budget:** Implemented in `app.services.assistant.orchestrator`, which retrieves up to 5 matching memories constrained by the configuration constant:
  ```python
  MEMORY_BUDGET_TOKENS: int = 256  # app.core.config.Settings (Current Implementation Constant)
  ```
- **Implemented API Endpoints:** Verified in `backend/app/api/v1/endpoints/memories.py`:
  - `GET /api/v1/memories`: Lists active memories owned by the authenticated user, optionally filtered by category.
  - `POST /api/v1/memories`: Creates a new manual memory record (synced automatically to FTS5).
  - `PATCH /api/v1/memories/{memory_id}`: Updates memory content, category, or importance.
  - `DELETE /api/v1/memories/{memory_id}`: Soft-deletes a memory (`is_deleted = True`, `deleted_at = now()`; triggers remove it from FTS5 index).
  *(Note: A dedicated single-item `GET /api/v1/memories/{memory_id}` endpoint is NOT implemented in current source.)*

### 3.3 Explicitly Unimplemented Capabilities

- **Selective Automatic Memory:** `NOT IMPLEMENTED / NOT STARTED` (all current memories originate via manual API calls or manual user input).
- **Semantic / Vector Memory:** `NOT IMPLEMENTED / NOT STARTED`.
- **Character-Scoped Memory Separation:** `NOT IMPLEMENTED` in schema or retrieval logic.

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Decision D7 and the Master Decision Register:

1. **Selective Automatic / Assistant-Proposed Memory (PC V1):**
   - The assistant evaluates conversation turns for clear, stable facts, personal preferences, or explicit corrections.
   - **Quality Guardrails:** Sensitive personal data, ambiguous statements, transient emotional vents, or fleeting topics must **never** be silently persisted as permanent facts.
   - Automatically proposed/captured memories retain provenance identifying their origin and verification state, remaining visible for user confirmation, modification, or dismissal. Exact field names, enum values, and schema remain OPEN DESIGN.
2. **Semantic Scoping Support (PC V1):**
   - PC V1 persistence must support the approved `PROFILE` / `CHARACTER` semantic scoping model. Exact persistence representation remains OPEN DESIGN.
3. **Semantic / Vector Memory (PC Later):**
   - Post-PC-V1 enhancement adding dense vector embeddings and similarity retrieval alongside lexical search for improved conceptual recall. Exact vector index, embedding model, and hybrid retrieval algorithms remain OPEN DESIGN.

---

## 5. Implementation-Open Details (Decision Debt)

The normative architecture for D7 and ADR-0018 is frozen. The following implementation-level details are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Extraction Model & Prompting:** Whether memory extraction runs inline within the primary chat model turn or asynchronously via a specialized local background task (`DEBT-V1-008`).
- **Extraction Cadence & Thresholds:** Trigger frequency, confidence scoring models, and user verification notification thresholds.
- **Persistence Representation:** Exact database schema for supporting `PROFILE` and `CHARACTER` scopes (`scope` column vs. join table).
- **Vector Embedding Provider & Index (PC Later):** Embedding model family, execution runtime, and vector search algorithms.
- **Hybrid Retrieval Balancing (PC Later):** Mathematical weighting between lexical FTS5 scores and semantic vector similarity.

---

## 6. Security & Ownership Boundaries

- **Strict Owner Isolation:** Every memory query mandates `WHERE m.profile_id = :profile_id` (migrated from `owner_id`). No cross-profile or unauthenticated memory access is permitted.
- **Untrusted Prompt Framing:** Memories are injected inside `<retrieved_memories>` XML tags. The orchestrator instructs the model that memory content represents historical user statements and must not execute instructions contained within them.
- **Deletion Integrity:** Soft-deleted memories are immediately excluded from FTS5 index searches via trigger logic and SQL defensive filters (`m.deleted_at IS NULL`).

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, Decision D7, ADR-0018)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) (Decision D7, ADR-0018), [`WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-MEM-001`, `PC-MEM-002`)
- **Memory ADR:** [`docs/04_Architecture/decisions/ADR-0008-d7-profile-first-memory-ownership.md`](../decisions/ADR-0008-d7-profile-first-memory-ownership.md)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **Character Domain Specification:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](characters-personality-and-emotion.md)
- **Assistant & Conversations Spec:** [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](assistant-and-conversations.md)
- **Health & Wearables Integration Spec:** [`docs/04_Architecture/03_Integrations/health-and-wearables.md`](../03_Integrations/health-and-wearables.md)
- **Multimodal & Media Architecture:** [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](multimodal-and-media.md)
- **Mobile Capabilities & Runtime Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md)
