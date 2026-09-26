# Memory and Personalization Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.1).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** This document is authored as part of the staged documentation reconciliation. Primary canonical authority remains in [`docs/04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../MEMORY_AND_CHARACTER_ARCHITECTURE.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

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
- **Unrestricted Deletion:** The user retains an absolute right to edit, correct, or permanently delete ("forget") any memory item at any time.
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
- **CRUD Endpoints:** Implemented in `app.api.v1.endpoints.memories` (`GET /`, `POST /`, `GET /{id}`, `PATCH /{id}`, `DELETE /{id}`).

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
   - Captured items are marked with explicit provenance (`source_type="assistant_extracted"`) and remain visible for user confirmation, modification, or dismissal.
2. **Schema-Level Scope Support (PC V1):**
   - Migration introducing explicit `scope` (`PROFILE` vs. `CHARACTER`) and optional `character_id` foreign associations to the `memories` table.
3. **Semantic / Vector Memory (PC Later):**
   - Post-PC-V1 enhancement adding dense vector embeddings and approximate nearest neighbor (ANN) retrieval alongside lexical search for improved conceptual recall.

---

## 5. OPEN DESIGN

The following implementation choices remain intentionally open for architectural investigation:

- **Extraction Model & Prompting:** Whether memory extraction runs inline within the primary chat model turn or asynchronously via a specialized background task.
- **Extraction Cadence & Thresholds:** Trigger frequency, confidence scoring models, and user verification notification thresholds.
- **Vector Embedding Provider:** Embedding model family (e.g., local ONNX runtime embeddings vs. CPU-based embedding models) for PC Later.
- **Hybrid Retrieval Balancing:** Mathematical weighting between lexical FTS5 BM25 scores and vector cosine similarity.
- **Scope Representation:** Exact Alembic migration schema for supporting `PROFILE` and `CHARACTER` scopes.

---

## 6. Security & Ownership Boundaries

- **Strict Owner Isolation:** Every memory query mandates `WHERE m.owner_id = :owner_id`. No cross-user or unauthenticated memory access is permitted.
- **Untrusted Prompt Framing:** Memories are injected inside `<relevant_memories>` XML tags. The orchestrator instructs the model that memory content represents historical user statements and must not execute instructions contained within them.
- **Deletion Integrity:** Soft-deleted memories are immediately excluded from FTS5 index searches via trigger logic and SQL defensive filters (`m.deleted_at IS NULL`).

---

## 7. Canonical Relationships & Cross-Links

- **Canonical Architecture Source:** [`docs/04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../MEMORY_AND_CHARACTER_ARCHITECTURE.md) (Retains primary authority until R11.4)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decision D7)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Rows 56, 57, 74)
- **Character Domain Specification:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](characters-personality-and-emotion.md) (Character identity boundaries)
