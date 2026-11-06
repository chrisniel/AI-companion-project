# Walkthrough: M3 Memory Extraction & Slot Reconciliation — Batch C2 (PC-MEM-002)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Document the architectural implementation, fast skip gate heuristics, structured candidate extraction, deterministic slot reconciliation, background orchestration lifecycle, and automated verification evidence for Milestone M3 Batch C2 (`PC-MEM-002`).
- **Audience:** Core maintainers, client engineers (Flutter Desktop & Web), independent reviewers, and security auditors.
- **Status:** Implemented & Verified (Phases 1–3 complete on `feature/m3-memory-extraction-c2`; ready for Phase 4 Independent Review & Human Owner squash merge).
- **Branch:** `feature/m3-memory-extraction-c2`
- **Delivery Level:** Level B — Planned Autonomous (Core Feature Implementation under Approved Architecture D7/ADR-0018)

---

## 1. Executive Summary & Scope

Milestone M3 Batch C2 delivers the complete backend selective automatic memory extraction and deterministic slot reconciliation pipeline:
- **Disclosure-Aware Skip Gate:** Post-turn heuristic in `app.services.memory.extractor` evaluates completed user turns. It skips trivial conversational acknowledgments, fillers, emojis, code blocks, and generic questions without first-person disclosures, while strictly protecting first-person disclosure markers (`I am`, `I'm`, `my`, `I like`, `I love`, etc.), ensuring personal disclosures (e.g., *"I'm vegetarian"*, *"I have celiac"*) are never dropped. Explicit *"Remember..."* commands bypass the gate unconditionally.
- **Structured LLM Candidate Extraction:** Prompts the active local LLM provider with a rigid JSON array schema. Enforces secrets filtering (passwords, API keys, tokens, credit cards), token budgeting (256 tokens), low temperature (0.1), and model readiness pre-flight (`provider.is_loaded()`) to avoid background model activation during standby.
- **Deterministic Slot Reconciliation Engine:** Implements `reconcile_candidate` in `app.services.memory.reconciler` applying 5 deterministic slot transitions:
  1. `DUPLICATE`: Touches existing memory (`last_verified_at = now()`) without creating redundant database rows.
  2. `NEW`: Persists a new memory record (`source_type = "extracted"`, `user_verified = False`, or explicit intent flags).
  3. `MERGE`: Enriches existing memory with additive details, updating `last_verified_at = now()`.
  4. `UPDATE`: Updates existing memory when candidate indicates change or attribute supersession (e.g. moved to a new city).
  5. `CONFLICT`: Preserves existing memory intact and inserts candidate with `source_type = "conflict"` and `user_verified = False`, eliminating silent overwriting and preparing records for C3 UI resolution and conversational clarification.
- **Zero-Latency Background Orchestration:** Extraction executes strictly in the background after the assistant turn message is committed and `data: [DONE]\n\n` is delivered to the client (0ms streaming overhead). Background transactions run in an isolated `AsyncSession` spawned via `get_session_factory()` with explicit rollback on error, guarded by a per-profile async lock (`_profile_extraction_locks`) to eliminate concurrent inference contention.
- **Safe Dormant Default:** Governed by `settings.MEMORY_EXTRACTION_ENABLED = False`, remaining dormant until explicitly enabled in test fixtures or until the Desktop UI ships in Batch C3. Zero database migrations were required (built on the Migration 010 foundation from Batch C1).

---

## 2. Key Architectural Decisions & Safeguards

### 2.1 Decoupling Live Chat from Background Extraction
Live conversational chat and long-term memory extraction operate independently:
1. The user's message is processed immediately by the assistant with full persona and history context, streaming emotional and character responses in real-time.
2. Background memory extraction only executes *after* the turn is completed and `[DONE]` is delivered.
3. The skip gate asks: *"Did the user disclose a permanent personal fact in that turn that should be stored forever?"*
4. Filtering trivial turns prevents unnecessary GPU/CPU workload, fan spin, battery drain, and avoids hallucinating bizarre "facts" from banter (e.g., storing *"User said cool"*).

### 2.2 First-Person Disclosure Protection & Explicit Fast-Track
To prevent under-engineering, the skip gate does not rely on a blunt word-count threshold:
```python
DISCLOSURE_PATTERN = re.compile(
    r"(?i)\b(i am|i'm|my|i have|i've|i like|i love|i hate|i dislike|i prefer|"
    r"i live|i work|i play|call me|i go|i run|i eat|i drink|i study|i speak|i use)\b"
)
```
- Short user disclosures like *"I'm vegetarian"* (2 words) or *"I have celiac"* (3 words) match `DISCLOSURE_PATTERN` and are **never** skipped.
- Explicit cues (`Remember...`, `Don't forget...`) bypass the skip gate, auto-save with `confidence = 1.0`, and mark `source_type = "user_explicit"`, `user_verified = True`.
- Non-explicit extractions are saved with `source_type = "extracted"` and `user_verified = False` for user inspection.

### 2.3 Non-Destructive Conflict Preservation (Decision D7)
In accordance with Decision D7, long-term memory forbids silent overwriting:
- When a candidate directly contradicts an existing memory (e.g. past memory is *"User loves dark roast coffee"*, candidate is *"User hates coffee and dislikes the taste"*):
  1. The existing established memory remains completely untouched.
  2. The candidate is inserted as a distinct record with `source_type = "conflict"` and `user_verified = False`.
  3. Both records are safely preserved in SQLite without schema changes, ready for manual resolution in the Batch C3 Desktop UI and natural companion-toned clarification in future chat turns.

### 2.4 Scoping Constraint Safety
Migration 010 enforces check constraint `ck_memories_character_scope`:
```sql
(scope = 'profile' AND character_instance_id IS NULL) OR (scope = 'character' AND character_instance_id IS NOT NULL)
```
- If the extraction prompt produces `scope = "character"` during a conversation with the Neutral Assistant (`character_instance_id is None`), the reconciler automatically coerces `scope = "profile"` before persistence, guaranteeing database invariant integrity.

### 2.5 Single-Flight Inference Concurrency & Session Isolation
On local hardware, running extraction concurrently with user chat would contend for LLM inference leases in `LlamaCppProvider`:
1. `_profile_extraction_locks: dict[str, asyncio.Lock]` serializes extraction passes per profile.
2. `provider.is_loaded()` pre-flight ensures extraction does not wake up or load an unloaded model during standby.
3. Post-stream task creates its own `AsyncSession` from `get_session_factory()` with explicit `try / except: await db.rollback()`, ensuring clean connection disposal and preventing pool handle leaks.

---

## 3. Files Modified and Added

| File | Change Type | Purpose |
|---|---|---|
| `backend/app/core/config.py` | Modified | Added extraction settings (`MEMORY_EXTRACTION_ENABLED`, thresholds, token limits) |
| `backend/app/services/memory/extractor.py` | Added | Fast skip gate, disclosure protection, prompt assembly, JSON parsing, and secret filtering |
| `backend/app/services/memory/reconciler.py` | Added | Deterministic slot reconciliation engine (`DUPLICATE`, `NEW`, `MERGE`, `UPDATE`, `CONFLICT`) |
| `backend/app/services/assistant/orchestrator.py` | Modified | Wired post-turn background extraction, single-flight profile lock, and session isolation |
| `backend/tests/test_memory_extraction_skip_gate.py` | Added | 7 unit tests covering trivial words, code blocks, disclosures, and explicit intent bypass |
| `backend/tests/test_memory_extraction_prompt.py` | Added | 7 unit tests covering JSON parsing, code fence stripping, secrets filtering, and model pre-flight |
| `backend/tests/test_memory_reconciliation.py` | Added | 8 unit tests covering slot transitions (`DUPLICATE`, `NEW`, `MERGE`, `UPDATE`, `CONFLICT`) |
| `backend/tests/test_memory_extraction_pipeline.py` | Added | 5 integration tests covering background execution, toggle dormancy, explicit intent, and locks |
| `docs/04_Architecture/01_Domains/memory-and-personalization.md` | Modified | Updated §3 baseline with verified extraction and reconciliation architecture |
| `CHANGELOG.md` | Modified | Added M3 Batch C2 unreleased changelog entry |
| `docs/01_Tracking/active/task-feature-m3-memory-extraction-c2.md` | Modified | Updated active execution tracker with completed Phase 2 and 3 evidence |
| `docs/01_Tracking/archive/task-feature-m3-memory-extraction-c2.md` | Added | Archived execution tracker for same-branch closure |

---

## 4. Verification Evidence

### Automated Test Suite Execution

1. **Memory Extraction & Reconciliation Unit/Integration Tests (27/27 PASSED):**
   ```powershell
   pytest backend/tests/test_memory_extraction_skip_gate.py backend/tests/test_memory_extraction_prompt.py backend/tests/test_memory_reconciliation.py backend/tests/test_memory_extraction_pipeline.py
   ```
   *Result:* 27 passed in 1.32s.

2. **Full Repository Backend Regression Suite (755/755 PASSED):**
   ```powershell
   pytest backend/tests
   ```
   *Result:* 755 passed, 0 failures in 270.55s (0:04:30).

3. **Dart Contract & Route Parity (100% PASSED):**
   ```powershell
   python scripts/check_dart_openapi_parity.py
   pytest scripts/tests/test_check_dart_openapi_parity.py
   ```
   *Result:* 32/32 DTO schemas verified, 42/26 routes covered, 8/8 parity tests passed.
