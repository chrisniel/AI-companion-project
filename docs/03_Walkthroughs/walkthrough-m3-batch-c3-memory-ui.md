# Walkthrough: M3 Memory Control Center UI, Migration 011 Per-Profile Extraction Toggle, and Conflict Resolution — Batch C3 (PC-CLIENT-009)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Document the architectural implementation, UI components, per-profile auto-extraction database migration and toggle, conflict resolution workflows, conversational contradiction prompting, and verification evidence for Milestone M3 Batch C3 (`PC-CLIENT-009`).
- **Audience:** Core maintainers, client engineers (Flutter Desktop & Web), independent reviewers, and security auditors.
- **Status:** Implemented & Verified (Phases 1–3 complete on `feature/m3-memory-ui-c3`; ready for Phase 4 Independent Review & Human Owner squash merge).
- **Branch:** `feature/m3-memory-ui-c3`
- **Delivery Level:** Level B — Planned Autonomous (Core Feature Implementation under Approved Architecture D7/ADR-0018)

---

## 1. Executive Summary & Scope

Milestone M3 Batch C3 delivers the complete user-facing Memory Control Center UI and per-profile governance layer, completing Milestone M3's memory capabilities:
- **Desktop Memory Control Center (`PC-CLIENT-009`):** Replaced the placeholder screen with an interactive memory management hub in Flutter Desktop (`frontend/flutter/apps/desktop`):
  - `DesktopMemoryController`: Reactive state management controller interfacing with `CompanionClient`, handling live search, filtering, auto-extraction toggling, inline editing, manual creation, deletion, and 1-click conflict resolution.
  - `MemoryScreen`: Top screen layout featuring header controls, per-profile auto-extraction switch, prominent conflict banner, search and filter chips, and list of memory cards.
  - `MemoryConflictBanner`: Prominent amber warning banner alerting users when contradictory beliefs exist (`source_type="conflict"`, `user_verified=False`), displaying side-by-side diff comparison and 1-click resolution actions: *Keep New*, *Keep Old (Discard New)*, and *Edit & Merge*.
  - `MemoryFilterBar`: Real-time substring query filter (`q`), scope chips (`all`, `profile`, `character`), category chips (`all`, `fact`, `preference`, `context`), and status chips (`all`, `verified`, `pending`, `conflicts`).
  - `MemoryItemCard`: Individual memory cards displaying category badges, scope indicators, status badges (`VERIFIED`, `PENDING REVIEW`, `CONFLICT`), core fact pin/unpin star, inline approval, edit modal trigger, and confirmation-gated deletion.
  - `MemoryEditDialog`: Form dialog enabling creation of manual memories or editing content, category, scope, and core fact pin status.
  - `DesktopShell` Integration: Wired into `DesktopShell` with active profile synchronization and navigation rail badge removal (Memory is now active; planned `'M3'` badge removed).
- **Per-Profile Auto-Extraction Toggle & Alembic Migration 011:**
  - Authored Migration `011_profile_memory_extraction_toggle.py` adding `profiles.memory_extraction_enabled` (Boolean, default `True`, `server_default="1"`, NOT NULL) with SQLite trigger cycle handling.
  - Updated `Profile` ORM model, `ProfileMetadata`, and `ProfileUpdateRequest` to expose and manage `memory_extraction_enabled`.
  - Turned default extraction setting to `MEMORY_EXTRACTION_ENABLED = True` in `config.py`, dynamically guarded by the active profile's `memory_extraction_enabled` state.
- **Memory API Query Filters & Approval Updates:**
  - Extended `GET /api/v1/memories` with query parameters: `q` (case-insensitive substring filter), `user_verified` (Boolean filter), and `source_type` (String filter).
  - Extended `PATCH /api/v1/memories/{memory_id}` with `user_verified` (which sets `last_verified_at = now()`) and `source_type`.
  - Injected `<memory_conflicts>` into `ChatOrchestrator` context assembly with companion-toned clarification instructions when unresolved conflicts exist.
- **Client Contract Parity:**
  - Updated `companion_api` Dart client and DTOs (`MemoryUpdate`, `ProfileMetadata`, `ProfileUpdateRequest`, and `CompanionClient.listMemories`) maintaining 100% contract parity with OpenAPI specification.

---

## 2. Key Architectural Decisions & Safeguards

### 2.1 Per-Profile Extraction Governance vs Global Switch
Automatic memory extraction is a personal privacy and resource preference. Rather than leaving extraction as a rigid global backend flag, Migration 011 stores `profiles.memory_extraction_enabled` directly on the profile entity:
1. Each profile independently controls whether post-stream conversations auto-extract enduring facts.
2. The runtime config `settings.MEMORY_EXTRACTION_ENABLED` defaults to `True`, but the background worker queries the active profile before invoking the LLM extraction provider.
3. Users toggle auto-extraction directly from the Memory Control Center header switch with immediate profile persistence.

### 2.2 Conflict Resolution Model: Agency & Transparency
When a new turn contradicts an established belief (e.g. user previously said they dislike spicy food, but now ordered spicy ramen), the reconciler marks the new candidate as `source_type="conflict"` with `user_verified=False` without overwriting the established truth:
1. **Desktop UI Conflict Banner:** The top of the Memory Control Center alerts the user with an amber banner and diff view showing both statements.
2. **1-Click Resolution Actions:**
   - *Keep New:* Approves the new statement (`user_verified=True`, `source_type="manual"`) and deletes or supersedes the old record.
   - *Keep Old (Discard New):* Deletes the conflict candidate record, preserving the established belief.
   - *Edit & Merge:* Opens a merge dialog allowing the user to compose a synthesized fact (e.g. *"Enjoys spicy ramen occasionally, but dislikes spicy curry"*).
3. **Conversational Clarification:** `ChatOrchestrator` injects active profile conflicts into the context assembly under `<memory_conflicts>` with polite companion guidance:
   ```xml
   <memory_conflicts>
   - Unresolved contradiction detected: 'User loves coffee' vs 'User prefers tea'.
   Note: If conversationally natural, gently ask the user to clarify this preference like a thoughtful companion, without acting like an administrative system alert.
   </memory_conflicts>
   ```

### 2.3 SQLite Trigger Drop/Recreate during Migration 011
Alembic `batch_alter_table("profiles")` renames the table to `_alembic_tmp_profiles` during column addition. SQLite raises `OperationalError: error in trigger trg_character_instances_deactivate_clear_profile: no such table: main.profiles` because the existing trigger references `profiles`.
Migration 011 solves this cleanly by dropping the trigger prior to the batch alter and recreating it immediately after, ensuring zero schema corruption.

---

## 3. Verification & Evidence Summary

All quality gates passed cleanly with zero regressions:

| Component | Target / Suite | Result | Evidence |
| :--- | :--- | :--- | :--- |
| **Backend Migration 011** | `test_migration_011.py` | **PASSED** (3/3) | Upgrade, downgrade, trigger preservation |
| **Profile Memory Toggle** | `test_profile_memory_toggle.py` | **PASSED** (2/2) | Profile model default, API patch persistence |
| **Memory API Query Filters** | `test_memories_api_filters.py` | **PASSED** (5/5) | `q`, `user_verified`, `source_type` filters |
| **Memory Extraction Pipeline** | `test_memory_extraction_pipeline.py` | **PASSED** (7/7) | Profile toggle gating, slot reconciliation |
| **Memory & Orchestrator Suite** | 10 memory & orchestrator suites | **PASSED** (67/67) | 23.75s clean execution |
| **Full Backend Regression** | `backend/tests/` (all 767 items) | **PASSED** (767/767) | 0 failures, 761 passed + 11 schema tests |
| **Dart OpenAPI Parity** | `check_dart_openapi_parity.py` | **PASSED** | 32/32 schemas, 42/26 routes |
| **Dart API Client Package** | `companion_api` (`dart test`) | **PASSED** (95/95) | DTO serialization, REST client methods |
| **Desktop Memory Unit Tests** | `desktop_memory_controller_test.dart` | **PASSED** (9/9) | Loading, filtering, CRUD, conflict resolution |
| **Desktop Memory Screen Tests** | `memory_screen_test.dart` | **PASSED** (8/8) | Header switch, banner, cards, dialogs |
| **Desktop Shell Integration** | `desktop_shell_test.dart` | **PASSED** (4/4) | Navigation, badge removal, lifecycle |
| **Flutter Static Analysis** | `flutter analyze` (desktop) | **PASSED** | "No issues found! (ran in 9.2s)" |

---

## 4. Modified & Created Artifacts

### Backend Core & API
- [`backend/migrations/versions/011_profile_memory_extraction_toggle.py`](file:///d:/OtherProjects/AI-companion-project/backend/migrations/versions/011_profile_memory_extraction_toggle.py): Alembic migration adding `profiles.memory_extraction_enabled`.
- [`backend/app/models/profile.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/models/profile.py): Added `memory_extraction_enabled` column to `Profile` model.
- [`backend/app/api/v1/endpoints/profiles.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/api/v1/endpoints/profiles.py): Added `memory_extraction_enabled` to `ProfileMetadata` and `ProfileUpdateRequest`.
- [`backend/app/core/config.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/core/config.py): Set `MEMORY_EXTRACTION_ENABLED = True`.
- [`backend/app/schemas/memory.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/schemas/memory.py): Added `user_verified` and `source_type` to `MemoryUpdate`.
- [`backend/app/api/v1/endpoints/memories.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/api/v1/endpoints/memories.py): Extended `list_memories` with `q`, `user_verified`, and `source_type` filters; extended `update_memory` with verification timestamp logic.
- [`backend/app/services/assistant/orchestrator.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/services/assistant/orchestrator.py): Gated extraction on `profile.memory_extraction_enabled`; injected `<memory_conflicts>` in prompt context.

### Contracts & Client Packages
- [`contracts/openapi/openapi.json`](file:///d:/OtherProjects/AI-companion-project/contracts/openapi/openapi.json): Regenerated OpenAPI contract.
- [`frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart): Added `memoryExtractionEnabled` to DTOs.
- [`frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart): Added `userVerified` and `sourceType` to `MemoryUpdate`.
- [`frontend/flutter/packages/companion_api/lib/client/companion_client.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/packages/companion_api/lib/client/companion_client.dart): Extended `listMemories` with `q`, `userVerified`, `sourceType`.

### Flutter Desktop App
- [`frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart): Removed planned `'M3'` badge from `DesktopNavDestination.memory`.
- [`frontend/flutter/apps/desktop/lib/features/memory/desktop_memory_controller.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/memory/desktop_memory_controller.dart): State manager for memory operations.
- [`frontend/flutter/apps/desktop/lib/features/memory/memory_conflict_banner.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/memory/memory_conflict_banner.dart): Conflict warning banner with diff view and actions.
- [`frontend/flutter/apps/desktop/lib/features/memory/memory_filter_bar.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/memory/memory_filter_bar.dart): Search input and filter chips.
- [`frontend/flutter/apps/desktop/lib/features/memory/memory_item_card.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/memory/memory_item_card.dart): Individual memory card with badges, core star, edit/delete actions.
- [`frontend/flutter/apps/desktop/lib/features/memory/memory_edit_dialog.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/memory/memory_edit_dialog.dart): Manual memory creation and edit dialog.
- [`frontend/flutter/apps/desktop/lib/screens/memory_screen.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/screens/memory_screen.dart): Full memory control center screen.
- [`frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart): Wired `DesktopMemoryController` and profile listeners.

### Documentation & Tracking
- [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](file:///d:/OtherProjects/AI-companion-project/docs/04_Architecture/01_Domains/memory-and-personalization.md): Canonical specification updated for M3 Batch C3 baseline reality.
- [`CHANGELOG.md`](file:///d:/OtherProjects/AI-companion-project/CHANGELOG.md): Appended Milestone M3 Batch C3 entry.
- [`docs/03_Walkthroughs/walkthrough-m3-batch-c3-memory-ui.md`](file:///d:/OtherProjects/AI-companion-project/docs/03_Walkthroughs/walkthrough-m3-batch-c3-memory-ui.md): Authored this walkthrough.
