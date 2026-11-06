# Implementation Plan: Milestone M3 Batch C3 — Desktop Memory Control Center UI, Conflict Resolution & Auto-Extraction Enablement

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Completed & Verified (Phases 1–3 Complete; Ready for Phase 4 Review & Merge)
- **Delivery Level:** Level B — Planned Autonomous (Core Feature Implementation under Approved Architecture D7/ADR-0018)
- **Scope Mode:** New Feature — Desktop Memory Control Center UI (`PC-CLIENT-009`), Alembic Migration 011 (`profiles.memory_extraction_enabled`), Backend Memory Query & Update Filters (`q`, `user_verified`, `source_type`), Dart OpenAPI Client Parity, Conversational Memory Conflict Hinting, and System Default ON Extraction Toggle
- **Target Files:**
  - `backend/migrations/versions/011_profile_memory_extraction_toggle.py`
  - `backend/app/models/profile.py`
  - `backend/app/api/v1/endpoints/profiles.py`
  - `backend/app/schemas/memory.py`
  - `backend/app/api/v1/endpoints/memories.py`
  - `backend/app/core/config.py`
  - `backend/app/services/assistant/orchestrator.py`
  - `frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart`
  - `frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart`
  - `frontend/flutter/packages/companion_api/lib/client/companion_client.dart`
  - `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/desktop_memory_controller.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/memory_conflict_banner.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/memory_item_card.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/memory_filter_bar.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/memory_edit_dialog.dart`
  - `frontend/flutter/apps/desktop/lib/screens/memory_screen.dart`
  - `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart`
  - `backend/tests/test_migration_011.py`
  - `backend/tests/test_memories_api_filters.py`
  - `backend/tests/test_profile_memory_toggle.py`
  - `frontend/flutter/packages/companion_api/test/memory_dto_test.dart`
  - `frontend/flutter/apps/desktop/test/desktop_memory_controller_test.dart`
  - `frontend/flutter/apps/desktop/test/memory_screen_test.dart`
- **Branch:** `feature/m3-memory-ui-c3`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m3-memory-ui-c3.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m3-memory-ui-c3.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### Primary Objective
Deliver the complete **Desktop Memory Control Center UI** (`PC-CLIENT-009`) in Flutter Desktop (`frontend/flutter/apps/desktop`), enable automatic background memory extraction by default (`MEMORY_EXTRACTION_ENABLED = True`) with per-profile toggle control (`profiles.memory_extraction_enabled` via Migration 011), implement interactive conflict resolution workflows, and inject companion-toned conversational conflict hints into chat context.

### Milestone M3 Memory Batching Roadmap
1. **Batch M3-C1 (MERGED — PR #35, commit `b3d31d7`):** Memory Foundation, Schema Migration 010, Scoping, Bound Expiry, Core-Fact Context Assembly & Dart Client Parity.
2. **Batch M3-C2 (MERGED — PR #36, commit `f7de198`):** Selective Automatic Turn Extraction & Deterministic Slot Reconciliation (`PC-MEM-002`). Pure backend extraction pipeline, disclosure-aware skip filter, structured LLM extraction prompt, slot reconciliation (`NEW`, `MERGE`, `UPDATE`, `CONFLICT`), zero-latency background execution, and per-profile toggle dormant default OFF.
3. **Batch M3-C3 (Current Delivery):** Desktop Memory Control Center UI (`PC-CLIENT-009`), Conflict Resolution UI & Chat Context Hinting, Migration 011 Per-Profile Extraction Toggle, and Flip Extraction to Default ON.

### Relevant Canonical Requirements
- **Canonical Architecture:** [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](../../04_Architecture/01_Domains/memory-and-personalization.md) (Decision D7, ADR-0008, ADR-0018, §2.3 Frozen Memory Extraction & Management Policy).
- **Cross-Cutting Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, D7, D11).
- **Desktop Shell & Tray Spec:** [`docs/05_Design/01_PC_Desktop_Shell_and_Tray.md`](../../05_Design/01_PC_Desktop_Shell_and_Tray.md) (§2.2 Navigation Rail Item 4: Memory).
- **Conversation Architecture:** [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../../04_Architecture/01_Domains/assistant-and-conversations.md) (§3.3 Bounded Memory Context Assembly & Injection).
- **WBS Item:** `PC-CLIENT-009`: Memory Inspection, Correction & Deletion Control Center.

### Concrete Deliverables
1. **Alembic Migration 011 & Profile Model (`backend/migrations/versions/011_profile_memory_extraction_toggle.py`):**
   - Adds `memory_extraction_enabled: Boolean = True` (`server_default="1"`, nullable=False) to `profiles` table.
   - Updates `backend/app/models/profile.py` with `memory_extraction_enabled: Mapped[bool]`.
   - Updates `ProfileMetadata` and `ProfileUpdateRequest` in `backend/app/api/v1/endpoints/profiles.py`.
2. **System Config Default ON Flip (`backend/app/core/config.py`):**
   - Set `MEMORY_EXTRACTION_ENABLED: bool = True` (Default ON across runtime; guarded per profile by `profile.memory_extraction_enabled`).
   - In `orchestrator.py`: Check `settings.MEMORY_EXTRACTION_ENABLED and profile.memory_extraction_enabled` before post-turn background dispatch.
3. **Memory API Endpoint Query & Update Enhancements (`backend/app/api/v1/endpoints/memories.py`):**
   - `GET /api/v1/memories`: Add query filters `q: Optional[str] = None` (substring content match), `user_verified: Optional[bool] = None`, and `source_type: Optional[str] = None`.
   - `PATCH /api/v1/memories/{memory_id}`: Accept `user_verified: Optional[bool] = None` and `source_type: Optional[str] = None`. When `user_verified = True`, auto-update `last_verified_at = now_utc`.
4. **Conversational Conflict Prompt Hinting (`backend/app/services/assistant/orchestrator.py`):**
   - When active unresolved conflicts exist for the profile (`source_type = "conflict"`, `user_verified = False`), inject `<memory_conflicts>` into the orchestrator prompt context with polite, companion-toned clarification instructions.
5. **Dart API Client Parity (`frontend/flutter/packages/companion_api`):**
   - Update `memory_dto.dart` (`MemoryUpdate.userVerified`, `MemoryUpdate.sourceType`).
   - Update `profile_dto.dart` (`ProfileMetadata.memoryExtractionEnabled`, `ProfileUpdateRequest.memoryExtractionEnabled`).
   - Update `companion_client.dart` (`listMemories` with `q`, `userVerified`, `sourceType`).
   - Verify 100% contract parity with `scripts/check_dart_openapi_parity.py`.
6. **Flutter Desktop Memory Control Center UI (`frontend/flutter/apps/desktop`):**
   - `lib/controllers/desktop_settings_controller.dart`: Remove `'M3'` planned badge from `DesktopNavDestination.memory`.
   - `lib/features/memory/desktop_memory_controller.dart`: Complete state management for list, filters, search, conflict queue, manual creation, verification approval, and conflict resolution.
   - `lib/features/memory/memory_conflict_banner.dart`: Prominent top banner with side-by-side / card diff and one-click actions: "Keep New", "Keep Old", "Edit & Merge".
   - `lib/features/memory/memory_filter_bar.dart`: Search input, Scope pills (`All`, `Profile`, `Character`), Category pills (`All`, `Fact`, `Preference`, `Context`), Status pills (`All`, `Verified`, `Pending Review`, `Conflicts`), and "Add Memory" button.
   - `lib/features/memory/memory_item_card.dart`: Neumorphic card with chips (category, scope, status, core, expiry), content text, and action buttons.
   - `lib/features/memory/memory_edit_dialog.dart`: Dialog for editing or manually inserting memory records.
   - `lib/screens/memory_screen.dart`: Complete Desktop Control Center view replacing the M3 placeholder.
   - `lib/shell/desktop_shell.dart`: Instantiation, profile lifecycle synchronization, and navigation wiring.

### Explicit Out-of-Scope
- Cloud memory synchronization or multi-tenant remote sync (deferred to post-PC-V1).
- Semantic / Vector embedding search (sqlite-vec / Chroma) (deferred to post-PC-V1; FTS5 lexical search and substring filtering own PC V1 truth).
- Scheduling / Reminders / Alarms UI (scoped to Track B6 / `PC-CLIENT-006`).

---

## 2. Architecture & Technical Approach

### Current Findings & Technical Baseline
| Observation / Evidence | Verified Interpretation |
| --- | --- |
| Alembic Migration 010 is current HEAD (`backend/migrations/versions/010_memory_scoping_and_lifecycle.py`) | Migration 011 is the next sequential revision, depending on `010_memory_scoping_and_lifecycle`. |
| `MemoryScreen` is a static placeholder with `'PLANNED MILESTONE M3'` | Desktop shell already has the navigation destination wired; removing the badge and replacing the screen delivers `PC-CLIENT-009`. |
| `MemoryUpdate` lacks `user_verified` and `source_type` | Frontend cannot approve unverified memories or mark conflicts resolved via standard PATCH without adding these fields to schema and endpoint. |
| `MEMORY_EXTRACTION_ENABLED = False` in `config.py` | Extraction was dormant in Batch C2; flipping to `True` enables autonomous background extraction for profiles with toggle enabled. |
| `Profile` table has no extraction preference column | Migration 011 adds `memory_extraction_enabled` ensuring persistent profile-scoped ownership (Decision D7). |

### Conflict Resolution Architecture
When contradictory user statements occur (e.g. User said *"I am vegetarian"*, but previously recorded *"favorite meal is steak"*), Batch C2 records the new fact with `source_type = "conflict"` and `user_verified = False`.

In Batch C3, resolution is handled along two complementary surfaces:
1. **Desktop Control Center UI:**
   - **Keep New:** Marks conflict record as `user_verified = True`, `source_type = "manual"`, and deletes the older contradicting memory.
   - **Keep Old:** Soft-deletes the new conflict record (`deleteMemory`).
   - **Edit & Merge:** Updates the older memory with combined/clarified text, marks it verified, and soft-deletes the conflict candidate.
2. **Conversational Prompt Hinting:**
   - Active conflicts are formatted under `<memory_conflicts>` in the model prompt context.
   - System instruction: *"The user has conflicting memories on record. If the topic arises naturally, casually clarify which is correct in a warm, companion tone. Never interrogate or accuse."*

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/migrations/versions/011_profile_memory_extraction_toggle.py`
- **Primary Responsibility:** Add `memory_extraction_enabled` column to `profiles` table.
- **Planned Change:** Use `op.batch_alter_table("profiles")` to add `sa.Column("memory_extraction_enabled", sa.Boolean(), nullable=False, server_default=sa.text("1"))`. Downgrade drops column.
- **Invariants to Preserve:** Non-destructive batch alteration; existing profiles receive default `True`.

### [MODIFY] `backend/app/models/profile.py`
- **Primary Responsibility:** ORM mapping for `Profile`.
- **Planned Change:** Add `memory_extraction_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="1")`. Include in `__init__`.

### [MODIFY] `backend/app/api/v1/endpoints/profiles.py`
- **Primary Responsibility:** Profile administration and catalog endpoints.
- **Planned Change:** Add `memory_extraction_enabled: bool = True` to `ProfileMetadata`. Add `memory_extraction_enabled: Optional[bool] = None` to `ProfileUpdateRequest`. Update `PATCH /api/v1/profiles/{profile_id}` to set `profile.memory_extraction_enabled` when present.

### [MODIFY] `backend/app/schemas/memory.py`
- **Primary Responsibility:** Pydantic schemas for memories.
- **Planned Change:** Add `user_verified: Optional[bool] = None` and `source_type: Optional[str] = None` to `MemoryUpdate`.

### [MODIFY] `backend/app/api/v1/endpoints/memories.py`
- **Primary Responsibility:** Memory CRUD REST endpoints.
- **Planned Change:**
  - `list_memories`: Add query params `q: Optional[str] = None`, `user_verified: Optional[bool] = None`, `source_type: Optional[str] = None`. Apply SQL filters when passed.
  - `update_memory`: Handle `user_verified` (setting `last_verified_at = now_utc` if `True`) and `source_type`.

### [MODIFY] `backend/app/core/config.py`
- **Primary Responsibility:** Runtime settings.
- **Planned Change:** Change `MEMORY_EXTRACTION_ENABLED: bool = True` (default ON).

### [MODIFY] `backend/app/services/assistant/orchestrator.py`
- **Primary Responsibility:** Chat streaming orchestration, context assembly, and background extraction trigger.
- **Planned Change:**
  - In `orchestrate_chat_stream`: Check `settings.MEMORY_EXTRACTION_ENABLED and getattr(profile, "memory_extraction_enabled", True)` before spawning extraction task.
  - In context assembly: Query unresolved conflicts for `session.profile_id` and format into `<memory_conflicts>` section when present.

### [MODIFY] `frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart` & `profile_dto.dart` & `companion_client.dart`
- **Primary Responsibility:** Dart OpenAPI client contract.
- **Planned Change:** Add `userVerified` and `sourceType` to `MemoryUpdate`. Add `memoryExtractionEnabled` to `ProfileMetadata` and `ProfileUpdateRequest`. Add `q`, `userVerified`, `sourceType` to `listMemories`. Maintain strict parity.

### [MODIFY] `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`
- **Primary Responsibility:** Desktop navigation destination registry.
- **Planned Change:** Remove `badge: 'M3'` from `DesktopNavDestination.memory`.

### [ADD] `frontend/flutter/apps/desktop/lib/features/memory/desktop_memory_controller.dart`
- **Primary Responsibility:** State management for Memory Control Center.
- **Planned Change:** Handle list loading, pagination, search text, scope filter, category filter, status filter, conflict resolution actions, approval, editing, deletion, creation, and profile extraction toggle.

### [ADD] `frontend/flutter/apps/desktop/lib/features/memory/memory_conflict_banner.dart`
- **Primary Responsibility:** UI presentation of detected conflicts.
- **Planned Change:** Prominent warning banner displaying old vs new facts with "Keep New", "Keep Old", and "Edit & Merge" buttons.

### [ADD] `frontend/flutter/apps/desktop/lib/features/memory/memory_item_card.dart`
- **Primary Responsibility:** Memory item display card.
- **Planned Change:** Neumorphic card with status chips, category chips, scope chips, core star, expiry timestamp, and action buttons.

### [ADD] `frontend/flutter/apps/desktop/lib/features/memory/memory_filter_bar.dart`
- **Primary Responsibility:** Filtering and search controls.
- **Planned Change:** Search input with clear button, filter segmented buttons/chips, and "+ Add Memory" button.

### [ADD] `frontend/flutter/apps/desktop/lib/features/memory/memory_edit_dialog.dart`
- **Primary Responsibility:** Manual memory creation and editing modal.
- **Planned Change:** Accessible form with content field, category selector, scope selector, core toggle, and optional expiry date.

### [MODIFY] `frontend/flutter/apps/desktop/lib/screens/memory_screen.dart`
- **Primary Responsibility:** Desktop Memory Control Center main view.
- **Planned Change:** Replace M3 placeholder with full Control Center view wired to `DesktopMemoryController`.

### [MODIFY] `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart`
- **Primary Responsibility:** Desktop shell coordinator.
- **Planned Change:** Instantiate and manage `DesktopMemoryController` lifecycle; wire into `MemoryScreen`.

---

## 4. Step-by-Step Implementation Sequence (TDD)

### Step 1: Database Migration 011 & Profile Model (Backend TDD)
- Author `backend/tests/test_migration_011.py` checking upgrade and downgrade of `profiles.memory_extraction_enabled`.
- Implement `backend/migrations/versions/011_profile_memory_extraction_toggle.py`.
- Update `backend/app/models/profile.py` and `backend/app/api/v1/endpoints/profiles.py`.
- Run pytest to verify clean migration and profile endpoint tests.

### Step 2: Memory API Filters & Approval Updates (Backend TDD)
- Author `backend/tests/test_memories_api_filters.py` verifying `q`, `user_verified`, and `source_type` filters, as well as `PATCH` updating `user_verified` and setting `last_verified_at`.
- Update `backend/app/schemas/memory.py` and `backend/app/api/v1/endpoints/memories.py`.
- Verify all memory tests pass.

### Step 3: Default ON Toggle & Orchestrator Conversational Hinting (Backend TDD)
- Update `backend/app/core/config.py` (`MEMORY_EXTRACTION_ENABLED = True`).
- Update `backend/app/services/assistant/orchestrator.py` to check `profile.memory_extraction_enabled` and assemble `<memory_conflicts>`.
- Author/update tests in `backend/tests/test_memory_extraction_pipeline.py`.
- Run full backend regression suite (755+ tests).

### Step 4: Dart OpenAPI Parity Updates (Dart TDD)
- Update `companion_api` DTOs and client methods.
- Update `frontend/flutter/packages/companion_api/test/memory_dto_test.dart`.
- Run `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py` to verify 100% contract parity.

### Step 5: Flutter Desktop Memory Controller & Widgets (Flutter TDD)
- Author unit tests for `DesktopMemoryController` in `frontend/flutter/apps/desktop/test/desktop_memory_controller_test.dart`.
- Implement `desktop_memory_controller.dart`, `memory_conflict_banner.dart`, `memory_item_card.dart`, `memory_filter_bar.dart`, and `memory_edit_dialog.dart`.
- Implement `MemoryScreen` in `frontend/flutter/apps/desktop/lib/screens/memory_screen.dart`.
- Update `desktop_settings_controller.dart` to remove planned badge from memory destination.
- Wire into `desktop_shell.dart`.
- Run `flutter test` across desktop app tests.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [x] Backend Migration 011 test: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_migration_011.py -v` (3/3 PASSED)
- [x] Backend Memory API filter tests: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_memories_api_filters.py -v` (5/5 PASSED)
- [x] Backend Extraction & Orchestrator tests: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_memory_extraction_pipeline.py -v` (7/7 PASSED)
- [x] Backend Full Regression Suite: `backend/.venv/Scripts/python.exe -m pytest backend/tests` (767/767 tests passing, 0 failures)
- [x] Dart OpenAPI Parity: `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py` (32/32 schemas, 42/26 routes passing)
- [x] Dart API tests: `dart test` inside `frontend/flutter/packages/companion_api` (95/95 PASSED)
- [x] Flutter Desktop tests: `flutter test` inside `frontend/flutter/apps/desktop` (All unit, widget & shell tests PASSED)
- [x] Flutter Static Analysis: `flutter analyze` inside `frontend/flutter/apps/desktop` (No issues found)

### Manual & Host-Level Checks (Where Applicable)
- [ ] Open Desktop App, navigate to Memory Control Center via rail.
- [ ] Verify search by keyword, filter by scope, category, and status.
- [ ] Verify approving unverified memory updates UI to verified status.
- [ ] Verify conflict resolution banner displays when conflict memory exists and "Keep New" / "Keep Old" / "Edit" resolves it.
- [ ] Verify per-profile auto-extraction toggle switches and persists state.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *Risk:* FTS5 index desynchronization during memory updates.
  - *Safeguard:* Migration 010 SQLite triggers already maintain `memories_fts` consistency on update and soft-delete; tested and verified.
  - *Risk:* Profile session token invalidation when updating profile.
  - *Safeguard:* `PATCH /api/v1/profiles/{profile_id}` calls `validate_profile_session(db, session)` to maintain session validity.
- **Dependencies & Assumptions:**
  - Dart and Flutter SDK installed in host environment.
  - Existing Alembic migration chain 001..010 intact.
- **Required Permissions:**
  - Task-bounded feature branch commits and push on `feature/m3-memory-ui-c3`.
- **Genuine Stop Conditions:**
  - Unresolvable test regressions in existing 755 backend tests or Flutter desktop tests.
  - Breaking schema changes to existing immutable columns.
