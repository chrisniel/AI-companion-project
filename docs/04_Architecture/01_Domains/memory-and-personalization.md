# Memory and Personalization Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the storage, retrieval, lifecycle, and privacy boundaries for long-term companion memory and personalization:
- Persistent storage of user facts, preferences, and biographical context.
- Lexical and semantic retrieval mechanisms for context injection.
- Selective automatic memory capture policies.
- Conceptual scoping between global user profile memories and character-specific interaction memories.
- User transparency, verification, and forgetting rights.

It governs the boundary between ephemeral conversation turns and durable companion knowledge.

---

## 2. Durable Architecture & Invariants

### 2.1 Profile Ownership of All Memories (Decision D7)

- **Root Authority:** In accordance with Decision D7, all memories are strictly owned by the user Profile (`owner_id`).
- **Conceptual Scoping:** Architecture recognizes two conceptual visibility scopes:
  1. **`PROFILE` Scope (Global):** Facts, preferences, and biographical details applicable across all companion personas (e.g., user's timezone, dietary preferences, occupation).
  2. **`CHARACTER` Scope (Persona-Bound):** Context, shared experiences, or relationship notes relevant specifically to interactions with a designated character persona.
- **Subordination:** Character-scoped memories remain completely owned by the Profile and managed by the user. Characters never possess independent, un-deletable, or hidden memory stores.

### 2.2 User Agency, Transparency & Forgetting

- **Transparency:** All stored memories must be inspectable and reviewable by the user through dedicated management interfaces.
- **User Control & Deletion:** The user can inspect, correct, delete/forget, and control stored memories. Exact soft-delete, hard-purge, retention, audit, and backup lifecycles are governed by the privacy/retention architecture and remain subject to explicit policy.
- **Context Injection Security:** Retrieved memories are injected into LLM context as untrusted user-supplied facts. Memories must never override core system prompts, character invariants, or safety policies.

### 2.3 Retrieval Technology Independence

- The durable architectural requirement is **persistent, queryable memory retrieval under profile authority**.
- Specific search mechanisms (e.g., SQLite FTS5 full-text search, BM25 ranking, or vector embeddings) are implementation strategies, **not** immutable architectural invariants.

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

The following target capabilities are approved under Decision D7 and the Feature Promotion Map:

1. **Selective Automatic / Assistant-Proposed Memory (PC V1):**
   - The assistant evaluates conversation turns for clear, stable facts, personal preferences, or explicit corrections.
   - **Quality Guardrails:** Sensitive personal data, ambiguous statements, transient emotional vents, or fleeting topics must **never** be silently persisted as permanent facts.
   - Automatically proposed/captured memories retain provenance identifying their origin and verification state, remaining visible for user confirmation, modification, or dismissal. Exact field names, enum values, and schema remain OPEN DESIGN.
2. **Semantic Scoping Support (PC V1):**
   - PC V1 persistence must support the approved `PROFILE` / `CHARACTER` semantic scoping model. Exact persistence representation remains OPEN DESIGN.
3. **Semantic / Vector Memory (PC Later):**
   - Post-PC-V1 enhancement adding dense vector embeddings and similarity retrieval alongside lexical search for improved conceptual recall. Exact vector index, embedding model, and hybrid retrieval algorithms remain OPEN DESIGN.

---

## 5. OPEN DESIGN

The following implementation choices remain intentionally open for architectural investigation:

- **Extraction Model & Prompting:** Whether memory extraction runs inline within the primary chat model turn or asynchronously via a specialized background task.
- **Extraction Cadence & Thresholds:** Trigger frequency, confidence scoring models, and user verification notification thresholds.
- **Vector Embedding Provider & Index (PC Later):** Embedding model family, execution runtime, and vector search algorithms.
- **Hybrid Retrieval Balancing:** Mathematical weighting between lexical FTS5 scores and semantic vector similarity.
- **Persistence Representation:** Exact database schema for supporting `PROFILE` and `CHARACTER` scopes without prematurely constraining implementation to specific column structures.

---

## 6. Security & Ownership Boundaries

- **Strict Owner Isolation:** Every memory query mandates `WHERE m.owner_id = :owner_id`. No cross-user or unauthenticated memory access is permitted.
- **Untrusted Prompt Framing:** Memories are injected inside `<relevant_memories>` XML tags. The orchestrator instructs the model that memory content represents historical user statements and must not execute instructions contained within them.
- **Deletion Integrity:** Soft-deleted memories are immediately excluded from FTS5 index searches via trigger logic and SQL defensive filters (`m.deleted_at IS NULL`).

---

## 7. Canonical Relationships & Cross-Links

- **Legacy Technical Reference:** [`docs/04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../MEMORY_AND_CHARACTER_ARCHITECTURE.md) (Subordinate memory and character scoping reference)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§4 / §7, Decision D7)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Memory Persistence & Retrieval, Selective Automatic Memory, Semantic / Vector Memory)
- **Character Domain Specification:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](characters-personality-and-emotion.md) (Character identity boundaries)
