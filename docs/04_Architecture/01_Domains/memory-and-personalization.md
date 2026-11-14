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
- **Vision Observations Do NOT Automatically Create Memory (`D-SHARED-VISION-01`):** Image turn contents, visual descriptions, and camera observations remain scoped to conversation turn history and media attachments ([`multimodal-and-media.md`](multimodal-and-media.md)). Visual observations do not automatically become canonical D7 Memory. Any Memory derived from visual context must pass through the ordinary D7 Memory proposal, acceptance, and reconciliation policy.

---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Implemented Data Model & Storage

Memories are persisted in SQLite via SQLAlchemy ORM (`app.models.memory.Memory`), migrated via Alembic migration `010_memory_scoping_and_lifecycle.py`, and indexed via an FTS5 virtual table:
- **Core Entity Fields:** `id` (UUIDv4), `profile_id` (explicit, non-null UUID foreign key to `profiles.id`), `owner_id` (String, retained for compatibility), `category` (String(32), default `"fact"`), `content` (Text), `importance` (Float, default `1.0`), `source_type` (String(32), default `"manual"`), `source_message_id` (String(36), optional), `user_verified` (Boolean, default `True`). `owner_id` is not authorization authority; missing `profile_id` fails closed without an implicit default.
- **Audit & Soft-Delete Mixins:** `created_at`, `updated_at`, `is_deleted` (Boolean), `deleted_at` (DateTime, optional).
- **Scoping & Lifecycle Fields (M3 Batch C1 Baseline):**
  - `scope`: String(16), not null, default `"profile"`. Constrained to `('profile', 'character')`.
  - `character_instance_id`: String(36), optional foreign key referencing `character_instances.id` with `ondelete="RESTRICT"`. Check constraint enforces that `character_instance_id` is null when `scope = 'profile'` and non-null when `scope = 'character'`.
  - `valid_from`: DateTime(timezone=True), not null, default `func.now()`.
  - `expires_at`: DateTime(timezone=True), optional. Check constraint enforces `expires_at IS NULL OR expires_at >= valid_from`.
  - `last_verified_at`: DateTime(timezone=True), optional.
  - `is_core`: Boolean, not null, default `False`.
- **FTS5 Synchronization:** Triggers on `memories` table maintain `memories_fts` consistency, safely rebuilt and preserved during schema migrations.

### 3.2 Implemented Retrieval & Prompt Assembly

Verified in `app.services.memory.retriever` and `app.services.assistant.orchestrator`:
- **FTS5 Lexical Search with Scoping and Temporal Filtering:** Uses SQLite `memories_fts` joined against non-deleted memories, filtering by `profile_id` derived from the active Profile Session. When a Character Instance is active, retrieval returns Profile-scoped memories plus memories matching that specific `character_instance_id`; memories associated with other characters are excluded. When chatting with Neutral Assistant (`character_instance_id` is None), only Profile-scoped memories are retrieved. Temporary memories with `expires_at <= :now` are excluded.
- **Core Fact Injection:** `get_core_memories` retrieves up to 5 non-temporary, Profile-scoped core facts (`is_core = True` or `importance >= 1.5`, with `expires_at IS NULL`), injected into prompt assembly under a dedicated token budget (`MEMORY_CORE_FACTS_BUDGET_TOKENS = 100`) and deduplicated against search results.
- **Multilingual Token Sanitation:** The query sanitizer extracts safe alphanumeric, Latin-extended, CJK, and Hangul word tokens, explicitly filtering FTS5 operators (`AND`, `OR`, `NOT`).
- **Prompt Injection Budget:** Implemented in `app.services.assistant.orchestrator`, which retrieves matching memories constrained by configuration constants:
  ```python
  MEMORY_BUDGET_TOKENS: int = 256  # Relevant search memory budget
  MEMORY_CORE_FACTS_ENABLED: bool = True
  MEMORY_CORE_FACTS_LIMIT: int = 5
  MEMORY_CORE_FACTS_BUDGET_TOKENS: int = 100
  ```
- **Implemented API Endpoints:** Verified in `backend/app/api/v1/endpoints/memories.py`; each requires a validated Profile Session and derives read/write ownership from `session.profile_id`, with foreign Profile records failing closed:
  - `GET /api/v1/memories`: Lists active memories owned by the authenticated Profile, optionally filtered by `category`, `scope`, `character_instance_id`, `is_core`, and `include_expired`.
  - `GET /api/v1/memories/{memory_id}`: Retrieves a single memory record by ID for the active Profile.
  - `POST /api/v1/memories`: Creates a new manual memory record (validating character instance ownership and scoping rules).
  - `PATCH /api/v1/memories/{memory_id}`: Updates memory content, category, importance, `is_core`, and allows clearing `expires_at` to null via `exclude_unset=True`.
  - `DELETE /api/v1/memories/{memory_id}`: Soft-deletes a memory (`is_deleted = True`, `deleted_at = now()`; triggers remove it from FTS5 index).
- **Client Parity:** Flutter Dart client package `companion_api` provides typed models (`MemoryCreate`, `MemoryUpdate`, `MemoryOut`, `MemoryListOut`) and client methods (`listMemories`, `getMemory`, `createMemory`, `updateMemory`, `deleteMemory`) matching OpenAPI contracts.
- **Relational Purge Ordering:** `ProfilePurgeService` permanently purges `Memory` rows before `CharacterInstance` rows to satisfy the `RESTRICT` foreign key constraint without integrity failures.

### 3.3 Implemented Automatic Memory Extraction & Slot Reconciliation (M3 Batch C2 Baseline)

Verified in `app.services.memory.extractor`, `app.services.memory.reconciler`, and `app.services.assistant.orchestrator`:
- **Disclosure-Aware Skip Gate:** Post-turn background heuristic filters out trivial turn fillers, emojis, code snippets, and general questions without first-person disclosures, avoiding unnecessary inference load while protecting personal statements (e.g., *"I'm vegetarian"*, *"I like tea"*) and explicit memory commands.
- **Structured LLM Extraction:** Prompts active LLM provider with rigid JSON array schema, enforcing secrets sanitization, token budgeting (256 tokens), low temperature (0.1), and model readiness pre-flight (`provider.is_loaded()`).
- **Deterministic Slot Reconciliation:** Classifies extracted candidates against existing profile memories via token overlap and sentiment analysis into 5 deterministic slots: `DUPLICATE` (touch `last_verified_at = now()`), `NEW` (persist new record), `MERGE` (enrich existing content), `UPDATE` (supersede existing fact), and `CONFLICT` (retain existing fact intact, insert candidate with `source_type="conflict"` and `user_verified=False` for user resolution).
- **Post-Stream Background Orchestration:** Extraction executes in an isolated `AsyncSession` spawned via `get_session_factory()` with explicit rollback on error, guarded by a per-profile async lock (`_profile_extraction_locks`) to eliminate concurrent inference contention, with 0ms impact on user SSE streaming latency.
- **Opt-In Configuration:** Governed by `settings.MEMORY_EXTRACTION_ENABLED = False`, remaining dormant until explicitly enabled in test fixtures or until the Desktop UI ships in Batch C3.

### 3.4 Implemented Desktop Memory Control Center (M3 Batch C3 Baseline)

Verified in `frontend/flutter/apps/desktop`:
- **Desktop Memory Control Center UI (`PC-CLIENT-009`):** Full interactive memory management interface delivered in `frontend/flutter/apps/desktop/lib/screens/memory_screen.dart` and `frontend/flutter/apps/desktop/lib/features/memory/`:
  - `DesktopMemoryController`: Reactive state management controller interfacing with `CompanionClient` and profile scope changes, managing memory loading, filtering, auto-extraction toggling, approval, inline editing, deletion, and conflict resolution.
  - `MemoryScreen`: Replaces placeholder screen; provides screen header with per-profile auto-extraction switch, conflict alert banner, search/filter bar, and memory item cards.
  - `MemoryConflictBanner`: Prominent amber banner displayed when unresolved contradictory memories exist (`source_type="conflict"` and `user_verified=False`), providing diff visualization between existing memory and newly extracted statement, with 1-click resolution actions: *Keep New*, *Keep Old (Discard New)*, and *Edit & Merge*.
  - `MemoryFilterBar`: Real-time substring query filter (`q`), scope filter chips (`all`, `profile`, `character`), category chips (`all`, `fact`, `preference`, `context`), and status chips (`all`, `verified`, `pending`, `conflicts`).
  - `MemoryItemCard`: Individual memory cards displaying category badges, scope indicators, status badges (`VERIFIED`, `PENDING REVIEW`, `CONFLICT`), core fact pin/unpin star, and action buttons (`Approve`, `Edit`, `Delete`).
  - `MemoryEditDialog`: Form dialog enabling creation of manual memories or editing content, category, scope, and core fact pin status.
  - `DesktopShell` Integration: Wired into `DesktopShell` with active profile synchronization and navigation rail badge removal (Memory is now active; planned `'M3'` badge removed).
- **Per-Profile Auto-Extraction Governance:** Added `profiles.memory_extraction_enabled` column via Alembic Migration `011_profile_memory_extraction_toggle.py`, exposed on `ProfileMetadata` and `ProfileUpdateRequest`. Runtime extraction default flipped to `MEMORY_EXTRACTION_ENABLED = True` in `config.py`, dynamically gated per profile.
- **Conversational Conflict Clarification:** When active conflicts exist for the profile, `ChatOrchestrator` context assembly injects `<memory_conflicts>` with polite companion-toned clarification instructions.
- **API and Dart Parity:** `GET /api/v1/memories` extended with `q`, `user_verified`, and `source_type` query filters; `PATCH /api/v1/memories/{memory_id}` supports `user_verified` and `source_type`. OpenAPI schema and Dart DTOs in `companion_api` maintain 100% parity.

### 3.5 Implemented 3-Tier Memory & Knowledge Architecture V2 (M3 Batch E Baseline)

Verified across `backend/migrations/versions/013_memory_knowledge_and_triggers.py`, `app.models.memory`, `app.api.v1.endpoints.memories`, `app.services.memory.*`, `app.services.assistant.orchestrator`, `companion_api`, and `frontend/flutter/apps/desktop`:

- **Alembic Migration 013 (`013_memory_knowledge_and_triggers.py`):** Added `trigger_keywords` (`Text`, JSON array of lowercase trigger strings) and `recall_count` (`Integer`, not null, default `0`, CHECK constraint `ck_memories_recall_count` enforcing `recall_count >= 0`), preserving all `memories` table triggers and rebuilding `memories_fts` across `batch_alter_table`, with fail-closed downgrade protection when populated trigger keywords or recall counts exist.
- **Logical 3-Tier Partitioning Under Profile Authority (D7 & D-SHARED-AI-03):**
  - `knowledge` (**Fixed Knowledge & Profile**): Active non-expired entries that are `is_core=True`, `source_type="manual"`, or carry non-empty `trigger_keywords`.
  - `long_term` (**Long-Term & Episodic Memory**): Durable `user_verified` or `auto_extracted` facts/preferences without active `expires_at`.
  - `short_term` (**Short-Term Context**): Ephemeral situational records with active `expires_at` or `category="context"`.
- **Deterministic 72h Contextual TTL & Explicit Command Priority (`extractor.py`):** Situational context candidates (`category="context"` or temporal cues without an LLM-supplied `expires_at`) deterministically receive a 72-hour expiration (`DEFAULT_SHORT_TERM_TTL_HOURS = 72`). Explicit *"Remember that..."* turns bypass skip heuristics, immediately receive `user_verified=True`, and enforce an `importance >= 1.5` floor.
- **Fixed Knowledge Write-Protection & Cross-Session Consolidation (`reconciler.py`):** Background reconciliation (`reconcile_candidate`) protects `is_fixed_knowledge` records from silent automatic `UPDATE`/`MERGE` overwrites (retaining fixed knowledge intact and creating isolated `NEW` or `CONFLICT` candidates as appropriate). Recurring short-term situational disclosures separated by $\ge 12$ hours extend TTL and automatically promote to durable `fact` memories upon repeated cross-session occurrence.
- **Stem/Prefix Keyword Lorebooks, FTS5 Prefix Queries & Recall Tracking (`retriever.py`):** `get_triggered_knowledge` activates dormant lorebook entries via phrase matching and ASCII stem/prefix overlap ($\ge 3$ characters), while `get_core_memories` excludes keyword-gated lorebooks so dormant entries do not consume core prompt tokens until triggered. `search_relevant_memories` uses sanitized FTS5 prefix queries (`token*`), applies a bounded `recall_count` ranking boost, and atomically increments `recall_count` for memories injected into live turns.
- **Multi-Section XML Context Injection (`orchestrator.py`):** `_build_context` partitions `<retrieved_memories>` into semantically labeled XML sections with strict token caps: `<user_core_profile>` ($\le 120$), `<triggered_knowledge_lore>` ($\le 150$), `<episodic_and_long_term_memories>` ($\le 200$), and `<short_term_context>` ($\le 100$).
- **API, Contract Parity & Option 2A Desktop UI:** `GET /api/v1/memories` supports `?tier=knowledge|long_term|short_term`, searches across `trigger_keywords`, and returns profile-wide counts (`knowledge_count`, `long_term_count`, `short_term_count`). Desktop `MemoryScreen` implements Option 2A (`MemoryTierSidebar` inner left sub-menu with compact narrow fallback), context-aware `+ Add Knowledge`/`Add Memory`/`Add Context` creation defaults, trigger keyword pills (`#keyword`), `RECALLED N×` badges, remaining TTL indicators, and 1-click **Promote**.

### 3.6 M3 Batch F Follow-On Enhancements & Hardening (`2026-11`)

- **Emotion-Weighted Importance Scoring (`extractor.py`):** Extraction applies an importance adjustment (`+0.3`, clamped to `<= 2.0`) when significant emotional weight accompanies a user statement, prioritizing emotionally salient memories for long-term retention.
- **Temporal Fact Evolution Trail (`reconciler.py`):** When reconciling conflicting slot updates (preserving Fixed Knowledge write-protection), replaces the mutable memory value while appending a bounded single-step provenance suffix (`(previously: ... until YYYY-MM)`) without chaining stale history repeatedly.
- **Short-Term Promote & Edit Contract (`schemas/memory.py`, `endpoints/memories.py`, `desktop_memory_controller.dart`):** `MemoryUpdate` supports explicit `clear_expires_at: bool` so partial `PATCH` updates omitting `expires_at` preserve existing TTLs while Desktop 1-click **Promote** clears `expires_at` cleanly without serializing `null` fields unintentionally.
- **1-Click Chat Bubble Bookmarking (`chat_screen.dart`, `desktop_chat_controller.dart`):** Each user and assistant bubble exposes `bookmark_message_<id>` (`Save to Long-Term Memory` / `Pin to Fixed Knowledge`), persisting directly via `POST /api/v1/memories` as verified user-explicit records while keeping chat layout metrics unchanged.
- **Batch E Retrieval & Extraction Hardening (`retriever.py`, `extractor.py`, `reconciler.py`, `endpoints/memories.py`):** Applied pre-slice `exclude_ids` filtering before core-memory query caps, scoped `recall_count` increments strictly by `profile_id`, excluded keyword-gated lorebooks (`trigger_keywords IS NOT NULL`) from legacy short-term fallback queries, stripped non-core flags defensively during background updates, reserved the FTS5 `NEAR` operator during query sanitization, and hardened JSON parsing against `null` payload fields.

### 3.7 Explicitly Unimplemented Capabilities

- **Semantic / Vector Memory:** `NOT IMPLEMENTED / NOT STARTED` (post-PC-V1 enhancement).

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
- **Profile Deletion & Purge Cascade:** When a Profile is soft-deleted, all sessions are immediately revoked, preventing any memory retrieval or search for that profile. During permanent profile purge (Batch D `PC-IDENTITY-005`), all Profile memories are hard-deleted transactionally, and the SQLite `memories_fts` index entries are cleaned up atomically.

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
