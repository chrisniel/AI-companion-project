# Walkthrough: M3 Memory Foundation — Batch C1 (Scoping, Temporal Lifecycle & Context Assembly)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Document the architectural implementation, database migration, API contracts, scoped retrieval engine, client SDK parity, and automated verification evidence for Milestone M3 Batch C1 Memory Foundation (`PC-MEM-001`, `PC-MEM-003`, `PC-MEM-005`, `PC-API-001`).
- **Audience:** Core maintainers, client engineers (Flutter Desktop & Web), independent reviewers, and security auditors.
- **Status:** Implemented & Verified (Phases 1–3 complete on `feature/m3-memory-foundation-c1`; ready for Phase 4 Independent Review & Human Owner squash merge).
- **Branch:** `feature/m3-memory-foundation-c1`
- **Delivery Level:** Level C — Sensitive Design (Schema Migration & Personal Data Retention Boundary)

---

## 1. Executive Summary & Scope

Milestone M3 Batch C1 delivers the non-LLM memory foundation and client contracts:
- **Database Schema Migration 010:** Adds semantic scoping (`scope`), character instance binding (`character_instance_id`), temporal validity (`valid_from`, `expires_at`), re-verification tracking (`last_verified_at`), and permanent anchor flags (`is_core`) with strict SQLite check constraints and safe FTS5 trigger cycling + index rebuild.
- **Scoped FTS5 & Temporal Retrieval:** Isolates memories so Profile-level memories are globally shared, while character memories are strictly scoped to the active conversation character instance (foreign character memories are excluded, and Neutral Assistant conversations retrieve only Profile-scoped memories). Temporary memories past their expiration date are excluded via bound `:now` timestamp parameter.
- **Core Fact Context Assembly:** Introduces `get_core_memories` to retrieve up to 5 non-temporary, profile-scoped permanent facts (`is_core = True` or `importance >= 1.5`, `expires_at IS NULL`), injected into orchestrator prompt assembly under a 100-token budget and deduplicated against search hits.
- **REST Endpoints & Relational Purge:** Implements dedicated `GET /api/v1/memories/{memory_id}`, list query filters (`scope`, `character_instance_id`, `is_core`, `include_expired`), nulling expiration `PATCH`, foreign instance authorization checks, and hardens `ProfilePurgeService` to delete memories before character instances to satisfy `RESTRICT` foreign key integrity.
- **OpenAPI & Dart Client Parity:** Generates `contracts/openapi/openapi.json` parity, implements `MemoryCreate`, `MemoryUpdate`, `MemoryOut`, and `MemoryListOut` in `companion_api`, exposes typed client CRUD methods in `CompanionClient`, and passes fail-closed parity assertions across 42 verified routes.

---

## 2. Key Architectural Decisions & Safeguards

### 2.1 Explicit Semantic Scoping & SQLite Check Constraints
The `memories` table enforces scoping at both the database and service layers:
```sql
CONSTRAINT ck_memories_scope CHECK (scope IN ('profile', 'character')),
CONSTRAINT ck_memories_character_scope CHECK (
    (scope = 'profile' AND character_instance_id IS NULL) OR
    (scope = 'character' AND character_instance_id IS NOT NULL)
),
CONSTRAINT ck_memories_validity CHECK (
    expires_at IS NULL OR expires_at >= valid_from
)
```
- `scope = 'profile'`: Applies globally across all characters for the authenticated Profile (`character_instance_id` must be `NULL`).
- `scope = 'character'`: Tied to a specific `CharacterInstance` owned by the Profile (`character_instance_id` cannot be `NULL`).
- Foreign instances from other profiles are rejected with HTTP 404 during creation and updates.

### 2.2 FTS5 Trigger Cycling and Batch Migration Safety
In SQLite, adding columns or altering tables requires recreating triggers or cycling batch tables:
1. Migration 010 drops existing FTS5 synchronization triggers (`memories_fts_insert`, `memories_fts_update`, `memories_fts_delete`).
2. Applies `batch_alter_table` on `memories` to add new columns, indexes, and check constraints.
3. Recreates the FTS triggers with exact column alignments.
4. Executes `INSERT INTO memories_fts(memories_fts) VALUES('rebuild')` ensuring lexical search consistency across existing rows.
5. Backfills existing legacy memories with `valid_from = created_at`, `scope = 'profile'`, `is_core = 0`.

### 2.3 Scoped Retrieval & Neutral Assistant Exclusions
When building context for a user turn:
- **Active Character Turn:** Retrieves Profile memories (`scope = 'profile'`) + Character memories where `character_instance_id == active_character_id`. Memories for other characters are excluded.
- **Neutral Assistant Turn:** `conversation.character_instance_id` is `None`. Retrieval logic retrieves Profile memories only, ensuring no character-specific persona memories leak into neutral conversations.
- **Temporal Validity:** Excludes expired temporary memories at query time using a bound UTC parameter:
  ```python
  or_(Memory.expires_at.is_(None), Memory.expires_at > current_now)
  ```

### 2.4 Core Fact Injection & Budgeting
Permanent core facts provide persistent personalization anchors (e.g., name, core preferences, language):
- `get_core_memories` retrieves up to 5 non-temporary, profile-scoped core facts (`is_core = True` or `importance >= 1.5`, `expires_at IS NULL`).
- Injected into the orchestrator prompt assembly under a dedicated budget (`MEMORY_CORE_FACTS_BUDGET_TOKENS = 100`).
- Any search hits already present in core facts are deduplicated to preserve token efficiency.

### 2.5 Relational Purge Order with RESTRICT Foreign Key
`Memory.character_instance_id` references `character_instances.id` with `ondelete="RESTRICT"`. During permanent Profile purge:
- `ProfilePurgeService` purges `Memory` rows before deleting `CharacterInstance` rows.
- Prevents SQLite foreign key violation errors (`RESTRICT` failure) during multi-profile hard purge.
- Soft-deleted memories are also included in the 30-day retention purge.

---

## 3. Files Modified and Added

| File | Change Type | Purpose |
|---|---|---|
| `backend/migrations/versions/010_memory_scoping_and_lifecycle.py` | Added | Alembic migration 010 adding scoping, lifecycle columns, check constraints, and FTS5 rebuild |
| `backend/app/models/memory.py` | Modified | Updated `Memory` ORM model with new fields, check constraints, and compound indexes |
| `backend/app/schemas/memory.py` | Modified | Updated Pydantic schemas: `MemoryCreate`, `MemoryUpdate`, `MemoryOut`, `MemoryListOut` |
| `backend/app/core/config.py` | Modified | Added core fact configuration flags (`MEMORY_CORE_FACTS_ENABLED`, `MEMORY_CORE_FACTS_LIMIT`, `MEMORY_CORE_FACTS_BUDGET_TOKENS`) |
| `backend/app/services/memory/retriever.py` | Modified | Added scoped FTS5 filtering, bound `:now` temporal exclusion, and `get_core_memories` |
| `backend/app/services/assistant/orchestrator.py` | Modified | Added conversation character instance resolution, core-fact retrieval, and deduplicated context assembly |
| `backend/app/api/v1/endpoints/memories.py` | Modified | Added `GET /{id}`, list query filters, nulling expiration `PATCH`, and foreign character validation |
| `backend/app/services/profile_purge_service.py` | Modified | Ordered memory deletion before character instance deletion to satisfy `RESTRICT` FK |
| `backend/tests/test_migration_010.py` | Added | Migration test suite verifying upgrade, backfill, check constraints, FTS rebuild, and downgrade |
| `backend/tests/test_memory_foundation.py` | Added | 8 end-to-end integration tests covering scoping, single-item fetch, FTS isolation, temporal expiry, core facts, foreign instance rejection, nulling patch, and profile purge |
| `contracts/openapi/openapi.json` | Modified | Regenerated OpenAPI specification with updated memory schemas and routes |
| `frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart` | Added | Dart DTOs (`MemoryCreate`, `MemoryUpdate`, `MemoryOut`, `MemoryListOut`) |
| `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` | Modified | Implemented typed client methods: `listMemories`, `getMemory`, `createMemory`, `updateMemory`, `deleteMemory` |
| `frontend/flutter/packages/companion_api/lib/companion_api.dart` | Modified | Exported `dto/memory_dto.dart` |
| `frontend/flutter/packages/companion_api/test/companion_client_test.dart` | Modified | Added unit tests for all memory client methods |
| `scripts/check_dart_openapi_parity.py` | Modified | Added 5 memory routes and 4 memory schemas to Dart parity verification |
| `scripts/tests/test_check_dart_openapi_parity.py` | Modified | Updated route count assertion to 42 verified routes |
| `docs/04_Architecture/01_Domains/memory-and-personalization.md` | Modified | Updated §3 Current Verified Implementation baseline |
| `docs/02_Planning/00_Master/DECISION_DEBT.md` | Modified | Recorded C1 resolution for `DEBT-V1-08` and C2 follow-up for `DEBT-V1-06` |
| `docs/02_Planning/00_Master/DELIVERY_INDEX.md` | Modified | Added `plan-m3-memory-foundation-c1.md` to Active Feature Plans |
| `docs/01_Tracking/task.md` | Modified | Recorded M3 Batch C1 delivery status under Current Delivery State |
| `docs/01_Tracking/active/task-feature-m3-memory-foundation-c1.md` | Modified | Reconciled execution tracker |
| `docs/01_Tracking/archive/task-feature-m3-memory-foundation-c1.md` | Added | Archived branch execution tracker |
| `CHANGELOG.md` | Modified | Added M3 Batch C1 unreleased changelog entry |

---

## 4. Verification Evidence

### 4.1 Migration Test Suite (`backend/tests/test_migration_010.py`)
```text
backend\tests\test_migration_010.py::test_upgrade_adds_scoping_and_lifecycle_columns PASSED
backend\tests\test_migration_010.py::test_migration_backfills_valid_from_and_preserves_fts PASSED
backend\tests\test_migration_010.py::test_sqlite_check_constraints_enforced PASSED
backend\tests\test_migration_010.py::test_downgrade_and_reupgrade PASSED
4 passed in 3.99s
```

### 4.2 Memory Foundation Test Suite (`backend/tests/test_memory_foundation.py`)
```text
backend\tests\test_memory_foundation.py::test_memory_scoping_crud PASSED
backend\tests\test_memory_foundation.py::test_get_single_memory_and_isolation PASSED
backend\tests\test_memory_foundation.py::test_scoped_retrieval_isolation PASSED
backend\tests\test_memory_foundation.py::test_temporal_expiration_retrieval PASSED
backend\tests\test_memory_foundation.py::test_core_fact_injection_and_deduplication PASSED
backend\tests\test_memory_foundation.py::test_foreign_character_instance_rejected PASSED
backend\tests\test_memory_foundation.py::test_patch_clearing_expiration PASSED
backend\tests\test_memory_foundation.py::test_profile_hard_purge_with_memories PASSED
8 passed in 0.95s
```

### 4.3 Full Backend Regression Suite (63 tests)
```text
backend\tests\test_migration_010.py (4 tests) PASSED
backend\tests\test_memory_foundation.py (8 tests) PASSED
backend\tests\test_memory_fts.py (3 tests) PASSED
backend\tests\test_conversations.py (13 tests) PASSED
backend\tests\test_profile_deletion.py (18 tests) PASSED
backend\tests\test_assistant_orchestrator.py (17 tests) PASSED
====================== 63 passed, 36 warnings in 17.13s =======================
```

### 4.4 Contract Parity Verification (`scripts/check_dart_openapi_parity.py`)
```text
[Verified DTO Schemas: 32/32]
  [OK] MemoryCreate <-> MemoryCreate (memory_dto.dart)
  [OK] MemoryUpdate <-> MemoryUpdate (memory_dto.dart)
  [OK] MemoryOut <-> MemoryOut (memory_dto.dart)
  [OK] MemoryListOut <-> MemoryListOut (memory_dto.dart)

[Verified CompanionClient Route Methods: 42/26]
  [OK] GET    /api/v1/memories           -> listMemories()
  [OK] POST   /api/v1/memories           -> createMemory()
  [OK] GET    /api/v1/memories/{memory_id} -> getMemory()
  [OK] PATCH  /api/v1/memories/{memory_id} -> updateMemory()
  [OK] DELETE /api/v1/memories/{memory_id} -> deleteMemory()
RESULT: ALL CONTRACT PARITY AND ROUTE COVERAGE CHECKS PASSED.
```
Python parity test suite: 38/38 unit tests passed in 0.874s.

### 4.5 Flutter Workspace Verification
```text
dart analyze (frontend/flutter): No issues found!
flutter test packages/companion_api/test: 95 passed! All tests passed!
```

---

## 5. Next Steps (Follow-On Batches)

1. **Milestone M3 Batch C2:**
   - LLM extraction pipeline: evaluate conversation turns for stable facts, personal preferences, and explicit corrections.
   - Slot-based deterministic reconciliation: `NEW`, `MERGE`, `UPDATE`, and `CONFLICT`.
   - Extraction default `OFF` with per-profile toggle until UI ships in Batch C3.
2. **Milestone M3 Batch C3:**
   - Desktop Memory Control Center UI (`PC-CLIENT-009`): memory browser, search, editing, pinning core facts, and setting temporal expiration.
   - Flip extraction default `ON` with per-profile toggle, resolve conflict endpoints, and provide "ask once" clarification hints.
