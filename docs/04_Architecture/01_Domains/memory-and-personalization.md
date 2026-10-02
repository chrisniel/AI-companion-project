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

It governs the boundary between ephemeral conversation turns and durable companion knowledge.

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

### 2.3 Local-Only Extraction & Temporary Validity


- **Temporary Memory Validity & Revalidation:** Ephemeral statements (e.g., "I'm sick today", "I'm staying at a hotel this week") must carry expiration metadata or require revalidation before durable long-term persistence. Ambiguous statements or emotional vents must never silently become permanent profile facts.

### 2.4 Retrieval Technology Independence

- The durable architectural requirement is **persistent, queryable memory retrieval under profile authority**.
- Specific search mechanisms (e.g., SQLite FTS5 full-text search, BM25 ranking, or vector embeddings) are implementation strategies, **not** immutable architectural invariants.

---

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
- **Lifecycle & Expiry:** Memories support temporary validity, expiry, and revalidation. Expired Memory is excluded immediately.
- **Forget Semantics:** "Forget" removes the memory from retrieval and context immediately; physical purge may follow later. Tombstones prevent known resurrection from restore.
- **Data Partitions:** Conversation History, Memory, and Emotion remain distinct architectural concepts.
- **Open Design:** Exact schema names remain open.


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
