# Implementation Plan: Milestone M3 Batch C2 — Selective Automatic Memory Extraction & Deterministic Slot Reconciliation

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Approved (Human Owner Plan Approval Gate Passed)
- **Delivery Level:** Level B — Planned Autonomous (Core Feature Implementation under Approved Architecture D7/ADR-0018)
- **Scope Mode:** New Feature — Backend LLM-Powered Turn Extraction Pipeline, Disclosure-Aware Skip Heuristic Filter, Candidate Schema, Slot Reconciliation (`NEW`, `MERGE`, `UPDATE`, `CONFLICT`, `DUPLICATE`), Single-Flight Concurrency, and Post-Stream Lifecycle Management
- **Target Files:**
  - `backend/app/core/config.py`
  - `backend/app/services/memory/extractor.py`
  - `backend/app/services/memory/reconciler.py`
  - `backend/app/services/assistant/orchestrator.py`
  - `backend/tests/test_memory_extraction_skip_gate.py`
  - `backend/tests/test_memory_extraction_prompt.py`
  - `backend/tests/test_memory_reconciliation.py`
  - `backend/tests/test_memory_extraction_pipeline.py`
- **Branch:** `feature/m3-memory-extraction-c2`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m3-memory-extraction-c2.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m3-memory-extraction-c2.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### Primary Objective
Deliver the complete backend selective automatic memory extraction and deterministic slot reconciliation pipeline for **Milestone M3 Memory & Personalization** (`PC-MEM-002`). This equips the local companion runtime with the capability to analyze completed conversation turns asynchronously, filter trivial turns via an intelligent disclosure-aware heuristic gate, extract structured candidate facts/preferences via a concise local LLM prompt, and reconcile candidates against existing memories using deterministic slot logic (`NEW`, `MERGE`, `UPDATE`, `CONFLICT`, and touch deduplication), while remaining default `OFF` (`MEMORY_EXTRACTION_ENABLED = False`) until the Desktop UI ships in Batch C3.

### Milestone M3 Memory Batching Roadmap
1. **Batch M3-C1 (CLOSED & MERGED — PR #35, commit `b3d31d7`):** Memory Foundation, Schema Migration 010, Scoping, Bound Expiry, Core-Fact Context Assembly & Dart Client Parity.
2. **Batch M3-C2 (Current Delivery):** Selective Automatic Extraction & Deterministic Slot Reconciliation (`PC-MEM-002`). Pure backend extraction pipeline, disclosure-aware skip filter, structured LLM extraction prompt, slot reconciliation (`NEW`, `MERGE`, `UPDATE`, `CONFLICT`), and per-profile toggle default `OFF` (`MEMORY_EXTRACTION_ENABLED = False`). Zero database migrations required.
3. **Batch M3-C3 (Follow-On):** Desktop Memory Control Center UI (`PC-CLIENT-009`). Full Flutter management screen, flip extraction to default ON with per-profile toggle, conflict resolution UI, and clarification prompts.

### Relevant Canonical Requirements
- **Canonical Architecture:** [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](../../04_Architecture/01_Domains/memory-and-personalization.md) (Decision D7, ADR-0008, ADR-0018, §2.3 Frozen Memory Extraction & Management Policy).
- **Cross-Cutting Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, D7, D11).
- **Conversation Architecture:** [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../../04_Architecture/01_Domains/assistant-and-conversations.md) (§3.3 Bounded Memory Context Assembly & Injection).
- **Data & Security Architecture:** [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../../04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md) (§3.2 Personal Data Retention & Purge Ordering).
- **WBS Item:** `PC-MEM-002`: Automated Fact Extraction & Slot Reconciliation Engine.

### Concrete Deliverables
1. **Extraction Configuration (`backend/app/core/config.py`):**
   - `MEMORY_EXTRACTION_ENABLED: bool = False` (Default OFF; dormant until C3 UI ships or explicitly enabled).
   - `MEMORY_EXTRACTION_CONFIDENCE_THRESHOLD: float = 0.8` (Auto-save confidence gate).
   - `MEMORY_EXTRACTION_MAX_CANDIDATES: int = 3` (Safety cap on extracted facts per turn).
   - `MEMORY_EXTRACTION_TEMPERATURE: float = 0.1` (Low temperature for rigid JSON output).
   - `MEMORY_EXTRACTION_MAX_TOKENS: int = 256` (Capped token budget for extraction inference).

2. **Disclosure-Aware Skip Gate & Explicit Intent Filter (`backend/app/services/memory/extractor.py`):**
   - Live Conversation Decoupling Invariant: The skip gate runs strictly in the background *after* the live chat turn has completed; it has 0ms overhead on token streaming and zero impact on chat personality, emotion, or conversation history.
   - `should_skip_extraction(user_text: str) -> bool`:
     - Explicit Intent Check: Matches explicit memory cues (regex `r"(?i)\b(remember|please remember|don't forget|keep in mind)\b"`). If matched, bypasses skip filter immediately (`False`).
     - Disclosure Marker Check: Matches first-person disclosure markers (`I am`, `I'm`, `my`, `I have`, `I like`, `I love`, `I hate`, `I live`, `I work`, `I prefer`, `call me`). If present, **never skips**, even if the turn is short (protects facts like *"I'm vegetarian"*, *"I have celiac"*, *"I like tea"*).
     - Triviality Filter: Skips pure conversational acknowledgments/fillers (`ok`, `yes`, `no`, `sure`, `thanks`, `cool`, `bye`, `lol`, `haha`), standalone emojis, pure code blocks (fenced with ```), and text with no disclosure markers.
     - Returns `True` to bypass expensive LLM inference when no enduring user facts are present.
   - `is_explicit_intent(user_text: str) -> bool`:
     - Identifies explicit user commands to set `confidence = 1.0`, `source_type = "user_explicit"`, and `user_verified = True`.

3. **Structured Extraction Prompt & Robust JSON Parser (`backend/app/services/memory/extractor.py`):**
   - Model Readiness Pre-Flight: Checks `if not provider.is_loaded(): return []` before calling inference, avoiding unexpected background loads when the local runtime is in standby.
   - Prompts the active LLM provider (`llm.generate()`) with a rigid system prompt demanding a strict JSON array of candidate memories.
   - Defines candidate model `MemoryCandidate`:
     - `content: str` (Clear, third-person factual statement about the user, e.g., "User prefers oat milk over dairy").
     - `category: Literal["fact", "preference", "context"]`.
     - `scope: Literal["profile", "character"]`.
     - `is_core: bool` (default `False`).
     - `expires_at: Optional[datetime]` (ISO 8601 string or null).
     - `confidence: float` (0.0 to 1.0).
   - Secrets & Transient Rejection: Instructs LLM and validates via regex/heuristics to ignore secrets (passwords, API keys, tokens), transient states ("I'm tired today"), and assistant roleplay claims.
   - Robust Parser: Strips markdown code blocks (````json ... ````), normalizes field types, logs malformed LLM responses without throwing, and falls back cleanly to an empty list.

4. **Deterministic Slot Reconciliation Engine (`backend/app/services/memory/reconciler.py`):**
   - Scoping Normalization: If candidate declares `scope == "character"` but active conversation has `character_instance_id is None`, forces `scope = "profile"` to prevent SQLite constraint failures (`ck_memories_character_scope`).
   - Lexical Search & Match: Queries existing active memories for the profile using FTS5 keywords derived from the candidate statement.
   - Deterministic Slot Classification:
     - `DUPLICATE`: Candidate matches an existing active memory in content/entity $\rightarrow$ touches existing record (`last_verified_at = now()`), avoiding redundant rows.
     - `NEW`: No related active memory found above lexical threshold $\rightarrow$ persists new `Memory` row (`source_type = "extracted"`, `user_verified = False`, or `source_type = "user_explicit"`, `user_verified = True`).
     - `MERGE`: Existing memory shares entity/topic and candidate provides non-contradictory additive detail $\rightarrow$ updates content, sets `last_verified_at = now()`.
     - `UPDATE`: Existing memory is directly updated or superseded by candidate $\rightarrow$ updates content, sets `last_verified_at = now()`.
     - `CONFLICT`: Candidate directly contradicts an existing memory $\rightarrow$ does NOT overwrite existing memory; persists candidate with `source_type = "conflict"`, `user_verified = False`, and `source_message_id = turn.user_message.id`. Preserves both records safely for manual resolution in C3 UI and companion-toned conversational clarification.
   - Auto-Save Threshold: Persists memories only if `confidence >= settings.MEMORY_EXTRACTION_CONFIDENCE_THRESHOLD` or `is_explicit is True`.

5. **Post-Stream Orchestration Wiring & Session Isolation (`backend/app/services/assistant/orchestrator.py`):**
   - Zero Latency Overhead: Background extraction executes strictly *after* `data: [DONE]\n\n` is yielded and the assistant message is committed.
   - Session Isolation & Rollback Protection: Background task creates an independent `AsyncSession` via `get_session_factory()`, wrapping all work in `try / except Exception: await db.rollback()` to prevent unclosed connection handles.
   - Concurrency Serialization: Per-profile async lock ensures only 1 extraction runs at a time per profile, preventing local LLM lease starvation during rapid user typing.
   - Exception Shielding: Failures in extraction are caught, logged, and never contaminate conversation status or HTTP streaming responses.

6. **Comprehensive Automated Verification Suite:**
   - `backend/tests/test_memory_extraction_skip_gate.py`: Skip filter heuristics, disclosure marker preservation (e.g. "I'm vegetarian"), and explicit remember bypass tests.
   - `backend/tests/test_memory_extraction_prompt.py`: Candidate prompt assembly, JSON parsing, fence stripping, secret rejection, model readiness pre-flight, and error recovery.
   - `backend/tests/test_memory_reconciliation.py`: Unit tests for `DUPLICATE` (touch), `NEW`, `MERGE`, `UPDATE`, `CONFLICT` slot transitions, character scope fallback, and `source_type = "conflict"` preservation.
   - `backend/tests/test_memory_extraction_pipeline.py`: Integration tests for post-turn background dispatch, disabled toggle verification, DB session rollback on failure, and single-flight lock serialization.

### Explicit Out-of-Scope (Deferred to Follow-On Deliverables)

| Deferred Capability | Justification & Architectural Owner | Planned Delivery Point |
| :--- | :--- | :--- |
| **Desktop Memory Control Center UI** | Visual inspection, search/filter, and conflict management screen. Owned by `PC-CLIENT-009`. | **Milestone M3 Batch C3** |
| **Database Schema Migration (e.g., `conflict_with_id`)** | Existing schema with `source_type = "conflict"` and `user_verified = False` is 100% sufficient for C2. Any UI-specific link columns will be evaluated in C3. | **Milestone M3 Batch C3 (if needed)** |
| **Interactive Conflict Dialogue Clarification** | Prompting user conversational questions ("Did you move to London?") requires interactive dialog flow; C3 delivers deterministic UI resolution buttons first. | Milestone M3 follow-up |
| **Proactive Memory Check-Ins ("Are you still sick?")** | Requires `SchedulerService` (`PC-SCHED`), Windows Native Toasts (`PC-HOST-003`), quiet-hours policy, and presence arbitration (`D-SHARED-SCHED-02`). | Milestone M3 Scheduler follow-up |
| **Dense Vector Embeddings & Hybrid Search** | PC V1 relies on lexical FTS5; vector embeddings are explicitly classified as PC Later in `BACKLOG.md`. | Post-PC-V1 (`PC LATER`) |
| **Web Test Runner Verification** | Per human direction, Web harness test runner is skipped; backend remains strictly backward-compatible. | Web harness follow-up |

---

## 2. Architecture & Technical Approach

### Current Findings & Technical Baseline

| Component / File | Current Implementation Reality | Required Evolution for Batch C2 |
| :--- | :--- | :--- |
| [`config.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/core/config.py) | Contains `MEMORY_SEARCH_LIMIT`, `MEMORY_BUDGET_TOKENS`, and core fact settings. | Add `MEMORY_EXTRACTION_ENABLED = False`, confidence threshold (`0.8`), and token/candidate limits. |
| [`models/memory.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/models/memory.py) | Full schema from Migration 010 with `scope`, `character_instance_id`, `valid_from`, `expires_at`, `last_verified_at`, `is_core`, `source_type`, and `user_verified`. | Zero schema migration required; model already supports `source_type="extracted"`, `source_type="conflict"`, `user_verified=False`, and all necessary lifecycle fields. |
| [`orchestrator.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/services/assistant/orchestrator.py) | Streams tokens, commits assistant message, and yields `[DONE]`. Request `db` session is closed immediately upon stream exit. | Dispatch background extraction after `[DONE]` using a fresh session from `get_session_factory()`, explicit rollback, and single-flight profile lock. |
| [`llama_cpp.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/services/llm/llama_cpp.py) | Provides `generate()` and `generate_stream()` guarded by `_acquire_generation()` lease. | Single-flight per-profile lock prevents background extraction from contending with active streaming. Pre-flight checks `provider.is_loaded()`. |
| [`retriever.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/services/memory/retriever.py) | FTS5 search with bound `:now` temporal exclusion and character scoping. | Reused by reconciler to locate candidate match targets across active profile memories. |

### Architectural Component Diagram

```text
User Turn Completed (orchestrate_chat_stream)
  │
  ├─► SSE Stream yields [DONE] (0ms latency impact on user)
  │
  └─► Background Task (spawned if MEMORY_EXTRACTION_ENABLED is True)
        │
        ▼
      Fast Skip Gate (should_skip_extraction)
        ├─► Trivial fillers/greetings without disclosure ──► STOP (No LLM call)
        │
        └─► Disclosures ("I am...", "I like...") or Explicit Intent ("Remember...")
              │
              ▼
            Model Ready Check (provider.is_loaded() is True)
              │
              ▼
            Single-Flight Profile Lock (prevents concurrent LLM contention)
              │
              ▼
            LLM Extraction Prompt (llm.generate with rigid JSON schema)
              │
              ▼
            Candidate Sanitizer & Parser (strip code fences, validate fields, ignore secrets)
              │
              ▼
            Slot Reconciler (reconcile_candidate)
              │
              ├─► FTS5 Lexical Search for similar memories
              │
              ├─► DUPLICATE ──► Refresh existing record (last_verified_at = now())
              ├─► NEW       ──► Insert Memory (source_type="extracted", user_verified=False)
              ├─► MERGE     ──► Update existing content, set last_verified_at = now()
              ├─► UPDATE    ──► Update existing content, set last_verified_at = now()
              └─► CONFLICT  ──► Insert candidate with source_type="conflict", user_verified=False (keep both)
```

---

## 3. Proposed File Changes & In-Place Logic

### [MODIFY] `backend/app/core/config.py`
- **Primary Responsibility:** Runtime settings configuration.
- **Planned Change:**
  Add memory extraction settings:
  ```python
  MEMORY_EXTRACTION_ENABLED: bool = False
  MEMORY_EXTRACTION_CONFIDENCE_THRESHOLD: float = 0.8
  MEMORY_EXTRACTION_MAX_CANDIDATES: int = 3
  MEMORY_EXTRACTION_TEMPERATURE: float = 0.1
  MEMORY_EXTRACTION_MAX_TOKENS: int = 256
  ```
- **Invariants to Preserve:** Existing memory budget and core facts settings remain untouched.

### [ADD] `backend/app/services/memory/extractor.py`
- **Primary Responsibility:** Turn triviality filtering, prompt assembly, LLM execution, candidate parsing, and sanitization.
- **Planned Logic:**
  - `EXPLICIT_INTENT_PATTERN = re.compile(r"(?i)\b(remember|please remember|don't forget|keep in mind)\b")`
  - `DISCLOSURE_PATTERN = re.compile(r"(?i)\b(i am|i'm|my|i have|i've|i like|i love|i hate|i dislike|i prefer|i live|i work|i play|call me)\b")`
  - `SECRET_PATTERNS`: Regexes for API keys, passwords, bearer tokens, credit cards.
  - `should_skip_extraction(user_text: str) -> bool`: Evaluates explicit cues, disclosure markers, acknowledgments, code fences.
  - `is_explicit_intent(user_text: str) -> bool`: Returns True if explicit pattern matches.
  - `MemoryCandidate(BaseModel)`: Pydantic candidate schema with content, category, scope, is_core, expires_at, confidence.
  - `extract_memory_candidates(user_text: str, assistant_text: Optional[str] = None, provider: Optional[BaseLLMProvider] = None) -> List[MemoryCandidate]`:
    - Checks `if provider and not provider.is_loaded(): return []`.
    - Constructs extraction prompt with strict instructions.
    - Calls `provider.generate(...)` with capped max tokens (256) and low temperature (0.1).
    - Robustly parses JSON response, stripping markdown blocks.
    - Filters out candidate facts matching secret patterns or empty content.
- **Invariants to Preserve:** Pure function / stateless design; graceful fallback to `[]` on any provider or JSON parsing failure.

### [ADD] `backend/app/services/memory/reconciler.py`
- **Primary Responsibility:** Deterministic slot resolution and database persistence for extracted candidates.
- **Planned Logic:**
  - `reconcile_candidate(db: AsyncSession, profile_id: str, candidate: MemoryCandidate, source_message_id: Optional[str] = None, active_character_instance_id: Optional[str] = None) -> Optional[Memory]`:
    - Scoping check: If `candidate.scope == "character"` but `active_character_instance_id is None`, normalize to `scope = "profile"`.
    - Character validation: If `candidate.scope == "character"`, assign `character_instance_id = active_character_instance_id`.
    - Matching: Run lexical query via FTS5 against active non-deleted memories for `profile_id`.
    - Classification:
      - If exact/near-identical content found $\rightarrow$ `DUPLICATE`: update `last_verified_at = now()` on existing record.
      - If no related memory found $\rightarrow$ `NEW`.
      - If related memory found with complementary information $\rightarrow$ `MERGE`.
      - If related memory found and candidate explicitly supersedes it $\rightarrow$ `UPDATE`.
      - If candidate directly contradicts existing memory $\rightarrow$ `CONFLICT` (retain existing, insert candidate with `source_type="conflict"`, `user_verified=False`, `source_message_id=source_message_id`).
    - Confidence gate: Persist only if `candidate.confidence >= settings.MEMORY_EXTRACTION_CONFIDENCE_THRESHOLD` or explicit intent.
- **Invariants to Preserve:** Adhere strictly to check constraint `ck_memories_character_scope` and Decision D7 profile ownership.

### [MODIFY] `backend/app/services/assistant/orchestrator.py`
- **Primary Responsibility:** Chat turn orchestration and streaming.
- **Planned Change:**
  - Add `_profile_extraction_locks: dict[str, asyncio.Lock] = {}` for single-flight concurrency.
  - In `orchestrate_chat_stream`, after committing `asst_msg` and yielding `data: [DONE]\n\n`:
    - Check `if settings.MEMORY_EXTRACTION_ENABLED and asst_msg.status == "completed":`
    - Schedule background extraction coroutine via `asyncio.create_task`.
    - Background coroutine uses `get_session_factory()` to open a fresh session with explicit `try / except Exception: await db.rollback()`.
    - Acquires profile extraction lock, evaluates `should_skip_extraction`, checks `provider.is_loaded()`, runs extraction and reconciliation, and commits.
- **Invariants to Preserve:** Response streaming latency is completely unaffected (0ms overhead); client never waits for extraction.

### [ADD] `backend/tests/test_memory_extraction_skip_gate.py`
- **Primary Responsibility:** Unit test suite for skip gate heuristics.
- **Planned Tests:**
  - Trivial words ("ok", "thanks", "lol", "sure", "bye") $\rightarrow$ skipped (`True`).
  - Short greetings without disclosures $\rightarrow$ skipped (`True`).
  - Code blocks (` ```python\ndef foo(): pass\n``` `) $\rightarrow$ skipped (`True`).
  - Short disclosures ("I'm vegetarian", "I like tea", "I have celiac") $\rightarrow$ **not skipped** (`False`).
  - Short explicit intent ("Remember: I'm vegan") $\rightarrow$ not skipped (`False`), identified as explicit intent.

### [ADD] `backend/tests/test_memory_extraction_prompt.py`
- **Primary Responsibility:** Unit tests for candidate extraction prompt, JSON parsing, and secret filtering.
- **Planned Tests:**
  - Clean JSON array parsing into `MemoryCandidate` list.
  - Markdown fence stripping (````json ... ````).
  - Malformed / conversational LLM response fallback to `[]`.
  - Secrets filtering: ignores candidate containing API key or password pattern.
  - Model unloaded pre-flight returns `[]`.

### [ADD] `backend/tests/test_memory_reconciliation.py`
- **Primary Responsibility:** Unit tests for deterministic slot resolution against SQLite DB.
- **Planned Tests:**
  - `DUPLICATE` slot: Touch existing memory's `last_verified_at`, verify no duplicate row created.
  - `NEW` slot: Insert completely new candidate fact.
  - `MERGE` slot: Enrich existing fact, verify `last_verified_at` updated.
  - `UPDATE` slot: Supersede existing fact, verify content updated and `last_verified_at` set.
  - `CONFLICT` slot: Contradictory candidate preserves existing memory and creates record with `source_type="conflict"` and `user_verified=False`.
  - Character scoping normalization: Coerces character scope to profile when `character_instance_id` is None.
  - Confidence threshold gating: Rejects candidates below 0.8 unless explicit.

### [ADD] `backend/tests/test_memory_extraction_pipeline.py`
- **Primary Responsibility:** End-to-end integration tests for orchestrator background extraction.
- **Planned Tests:**
  - When `MEMORY_EXTRACTION_ENABLED = False`, no extraction runs after chat turn.
  - When `MEMORY_EXTRACTION_ENABLED = True`, background extraction runs after turn completion with fresh DB session.
  - Explicit "Remember that..." creates auto-verified memory (`source_type="user_explicit"`, `user_verified=True`).
  - Profile extraction lock prevents concurrent extraction passes during back-to-back turns.
  - DB session rolls back cleanly if extraction worker encounters an exception.

---

## 4. Step-by-Step Implementation Sequence (TDD)

### Step 1: Settings & Skip Gate (TDD)
1. Write failing tests in `backend/tests/test_memory_extraction_skip_gate.py`.
2. Add settings in `backend/app/core/config.py`.
3. Implement `should_skip_extraction` (with disclosure-marker protection) and `is_explicit_intent` in `backend/app/services/memory/extractor.py`.
4. Run tests until all pass cleanly (GREEN).

### Step 2: Extraction Prompt, Parser & Candidate Schema (TDD)
1. Write failing tests in `backend/tests/test_memory_extraction_prompt.py`.
2. Implement `MemoryCandidate` schema, extraction prompt template, LLM generation caller, JSON parser, secret sanitizer, and model ready pre-flight in `extractor.py`.
3. Run tests until all pass cleanly (GREEN).

### Step 3: Slot Reconciler (TDD)
1. Write failing tests in `backend/tests/test_memory_reconciliation.py`.
2. Implement `reconcile_candidate` in `backend/app/services/memory/reconciler.py` with `DUPLICATE`, `NEW`, `MERGE`, `UPDATE`, `CONFLICT` logic and check constraint normalization.
3. Run tests until all pass cleanly (GREEN).

### Step 4: Background Post-Stream Wiring & Concurrency Lock
1. Write failing tests in `backend/tests/test_memory_extraction_pipeline.py`.
2. Wire post-stream background task into `backend/app/services/assistant/orchestrator.py` with independent session factory, rollback protection, and per-profile lock.
3. Run integration tests until all pass cleanly (GREEN).

### Step 5: Full Regression & Contract Verification
1. Run complete backend test suite: `pytest backend/tests`.
2. Run Dart OpenAPI parity script: `python scripts/check_dart_openapi_parity.py`.
3. Verify zero database schema drift or regressions.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Skip gate unit tests: `pytest backend/tests/test_memory_extraction_skip_gate.py`
- [ ] Extraction parser unit tests: `pytest backend/tests/test_memory_extraction_prompt.py`
- [ ] Reconciliation unit tests: `pytest backend/tests/test_memory_reconciliation.py`
- [ ] Pipeline integration tests: `pytest backend/tests/test_memory_extraction_pipeline.py`
- [ ] Full backend regression suite: `pytest backend/tests`
- [ ] Dart OpenAPI contract parity: `python scripts/check_dart_openapi_parity.py`

### Manual & Host-Level Checks
- [ ] Turn latency verification: Verify chat response stream delivers tokens and terminates with `[DONE]` without waiting for extraction completion.
- [ ] Default toggle check: Verify `MEMORY_EXTRACTION_ENABLED = False` keeps extraction completely dormant in default configuration.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risk: DB Session Reuse Failure & Pool Leaks:**
  - *Mitigation:* Background task strictly uses `get_session_factory()` with explicit rollback on error, preventing connection pool leaks and `Session is closed` errors.
- **Risk: Local LLM GPU Contention:**
  - *Mitigation:* Interactive chat always takes precedence. A per-profile lock serializes extraction tasks, and `provider.is_loaded()` prevents extraction when the model is in standby.
- **Risk: Short Fact Loss:**
  - *Mitigation:* The skip gate specifically protects first-person disclosure markers (`I am`, `I'm`, `my`, `I like`, etc.), ensuring short facts like *"I'm vegetarian"* are never skipped.
- **Risk: Silent Overwrite of User Facts:**
  - *Mitigation:* In accordance with Decision D7, `CONFLICT` slot never overwrites existing memories. Both memories are preserved (`source_type = "conflict"`, `user_verified = False`) for C3 UI resolution and conversational clarification.
- **Genuine Stop Conditions:**
  - Material scope expansion beyond pure backend extraction pipeline.
  - Database schema changes (Batch C2 requires zero new schema migrations; existing Migration 010 schema is 100% sufficient).
  - Unresolvable test regressions across existing chat streaming or memory retrieval suites.
