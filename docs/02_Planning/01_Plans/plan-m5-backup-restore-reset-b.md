# Implementation Plan: Milestone M5 Batch B — Coordinated Backup, Quiesced Staged Restore & Local Admin Factory Reset

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Draft — Pending Phase 1 Independent Plan Review & Human Plan Approval
- **Delivery Level:** Level C — Sensitive Design
- **Scope Mode:** New Feature + Lifecycle Resilience — Coordinated `.zip` Backup (`PC-RESILIENCE-001`), Host-Level Maintenance Quiescence & Live Staged Restore (`PC-RESILIENCE-003`, `DEBT-V1-10`), Local Admin Factory Reset (`PC-RESILIENCE-004`), OpenAPI/`companion_api` Parity (`PC-API-001`), and Desktop Settings Backup / Restore / Reset UI (`PC-CLIENT-011`)
- **Target Files:**
  - `backend/app/core/` (`config.py`, `runtime_lifecycle.py`, `storage.py`)
  - `backend/app/main.py`
  - `backend/app/db/backup.py` *(verify reuse / minor helper exports if needed)*
  - `backend/app/services/` (`backup_service.py` [ADD], `profile_purge_service.py`, `scheduler/service.py`, `voice/manager.py`, `resource_governor.py`)
  - `backend/app/schemas/` (`backup.py` [ADD])
  - `backend/app/api/v1/endpoints/` (`health.py` or `system_resilience.py` [ADD] + `voice.py` maintenance check)
  - `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`
  - `frontend/flutter/packages/companion_api/` (`lib/companion_api.dart`, `lib/dto/backup_dto.dart` [ADD], `lib/client/companion_client.dart`, `test/m5_backup_restore_reset_dto_test.dart` [ADD])
  - `frontend/flutter/apps/desktop/windows/runner/windows_shell_channel.cpp`
  - `frontend/flutter/apps/desktop/lib/platform/windows_shell_adapter.dart`
  - `frontend/flutter/apps/desktop/lib/features/profiles/desktop_profile_controller.dart`
  - `frontend/flutter/apps/desktop/lib/features/settings/` (`settings_section.dart`, `sections/settings_storage_section.dart`)
  - `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart`, `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart`
  - `backend/tests/` (`test_runtime_maintenance_quiescence.py` [ADD], `test_coordinated_backup_restore_reset.py` [ADD])
  - `frontend/flutter/apps/desktop/test/` (`desktop_m2_models_storage_autostart_test.dart`, `desktop_m5_backup_restore_reset_test.dart` [ADD])
  - Phase 3 docs: canonical specs (`backup-recovery-and-diagnostics.md`, `storage-and-assets.md`), Master spine (`DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md`), `task.md`, `CHANGELOG.md`, `walkthrough-m5-backup-restore-reset-b.md`, archived branch tracker
- **Branch:** `feature/m5-backup-restore-reset-b`
- **Active Branch Tracker:** [`task-feature-m5-backup-restore-reset-b.md`](../../01_Tracking/active/task-feature-m5-backup-restore-reset-b.md)

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m5-backup-restore-reset-b.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:**
  1. **Resolve `DEBT-V1-10` with Host-Level Maintenance Quiescence (`RuntimeLifecycleCoordinator`):** Provide a reusable, fail-closed `enter_maintenance_quiescence()` barrier that drains active HTTP reads/mutations, background purge/scheduler workers, active SSE streams, and WebSocket voice sessions, and cleanly disposes and re-initializes the SQLAlchemy async engine (`_engine` / `_session_factory`) without shutting down the Local AI Runtime process or deadlocking maintenance control endpoints.
  2. **Coordinated Database + Profile-Asset Backup (`PC-RESILIENCE-001`):** Package a WAL-consistent, integrity-verified copy of `companion.db` (with live session/ticket/confirmation rows scrubbed) plus referenced `ATTACHMENT_DIR` and `CHARACTER_DIR` asset trees into collision-proof `.zip` bundles under `BACKUP_DIR` with a SHA-256 `manifest.json`, while strictly excluding binaries, models, voices, cache, logs, `.env`, `bootstrap.json`, `host_config.json`, and secrets.
  3. **Staged Verification & Quiesced Live Restore (`PC-RESILIENCE-003`):** Inspect and verify internal or external `.zip` backups non-destructively (Zip-Slip/symlink/bomb rejection, strict path allowlist, SHA-256 manifest verification, SQLite integrity & FK check, Alembic revision compatibility, and attachment coherence reporting), then perform live restoration with explicit confirmation (`"RESTORE"`), **Reactivation Guard** & **Replay Guard** applied to the staged DB before quiescence, automatic `pre_restore_*.db` snapshot & sibling asset rollback directories, and full dual rollback if activation fails.
  4. **Local Admin Factory Reset (`PC-RESILIENCE-004`):** Implement a Host-Admin Risk 2 Factory Reset returning the Local AI Runtime database, profile attachments/characters/memories, `host_config.json`, `web_search_api.secret`, and `COMPANION_API_KEY` pairing credential to first-run state with a freshly seeded unique Default Profile UUID while keeping `APP_INSTALL_ROOT`, `desktop_admin.secret`, and (by default) Model/Voice Library and Backup Archives intact unless explicitly opted in with secondary confirmation for backup deletion.
  5. **Contracts & Consumer Desktop UI (`PC-API-001`, `PC-CLIENT-011`):** Expose 6 Host-Admin REST endpoints (`GET/POST /api/v1/system/backups`, `DELETE /api/v1/system/backups/{backup_id}`, `POST /api/v1/system/backups/verify`, `POST /api/v1/system/restore`, `POST /api/v1/system/factory-reset`), regenerate OpenAPI 3.1 & `companion_api` DTO parity, add Win32 `.zip` file selection, build **Backup & Restore** and **Factory Reset** cards under Desktop `Settings -> Storage`, and reset stale client Profile/Voice state cleanly after host data mutation.

- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) — Practical Backup & Recovery (PC V1), Factory Reset, Five Storage Roots, Decisions D6 & D10.
  - [`docs/04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md`](../../04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md) — §2.2 Normal Backup Scope & Asset Referential Coherence, §2.3 Restore Pipeline, Reactivation Guard, Replay Guard & Point-in-Time Snapshot Semantics, §2.4 Local Admin Factory Reset, §4 Approved Target Architecture, §6 Security & Ownership Boundaries.
  - [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](../../04_Architecture/04_Infrastructure/storage-and-assets.md) — Five storage roots, strict path containment, atomic writers.
  - [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../../04_Architecture/02_Data_and_Security/profiles-and-devices.md) — Multi-profile ownership and session revocation.
  - [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../00_Master/DECISION_DEBT.md) (`DEBT-V1-10`) & [`docs/02_Planning/00_Master/WBS.md`](../00_Master/WBS.md) (`PC-RESILIENCE-001`, `003`, `004`, `PC-API-001`, `PC-CLIENT-011`).

- **Concrete Deliverables:**
  1. **Slice B1 — Maintenance Quiescence Barrier:** `RuntimeLifecycleCoordinator.enter_maintenance_quiescence()`, background worker tracking across `profile_purge_service.py` & `scheduler/service.py`, `RuntimeAdmissionASGIMiddleware` `MAINTENANCE_CONTROL_PATHS` + `NON_DB_GET_PATHS`, `/api/v1/health` & `/api/v1/system/status` maintenance truth, and `VoiceManager.terminate_all_sessions()`.
  2. **Slice B2 — Coordinated Backup Engine:** `backend/app/services/backup_service.py` (`create_coordinated_backup()`, `list_backups()`, `delete_backup()`).
  3. **Slice B3 — Staged Restore Verification & Execution:** `verify_backup_archive()` (by `backup_id` or external `archive_path`) and `execute_staged_restore()` with Reactivation Guard, Replay Guard, staged schema upgrade if older linear revision, `restore_database_from_backup()`, and sibling asset rollback.
  4. **Slice B4 — Local Admin Factory Reset:** `execute_factory_reset()` + `Settings.rotate_pairing_token()` + `ResourceGovernor.reset_runtime_state()`.
  5. **Slice B5 — OpenAPI/Dart Parity, Win32 Picker & Desktop UI:** 6 Host-Admin routes, 11 flat DTOs, `contracts/openapi/openapi.json` (`92` paths / `125` routes / `158` schemas), `companion_api` DTOs/methods + parity test update (`119` native routes / `113` mapped DTOs), Win32 `filterPreset == "backups"`, `SettingsStorageSection` Backup & Reset cards, and `DesktopProfileController.resetSessionAfterHostDataChange()`.

- **Explicit Out-of-Scope:**
  - Optional passphrase AES-256 backup archive encryption *(tracked in `DECISION_DEBT.md` / `backup-recovery-and-diagnostics.md` §5 as open detail)*.
  - Automated scheduled backup cadence and automatic backup rotation caps *(deferred open detail)*.
  - Continuous remote/cloud database sync (`PC Later`).
  - Optional Cloud Fallback (`PC-CLOUD-*`) & Durable FIFO Conversation Queues (`PC-API-004`) *(scheduled in M5 Batch C)*.
  - Full Diagnostics Center / log viewer UI (`backup-recovery-and-diagnostics.md` §3.2).
  - SQLite / Alembic schema changes *(zero new migrations; restores/resets operate over the existing `018_voice_settings_and_character_voice` schema)*.
  - React Web UI (`frontend/web/`) and Android (`android/`) changes.

---

## 2. Architecture & Technical Approach

### Current Findings & Technical Baseline

| Observation / Evidence | Verified Interpretation |
| --- | --- |
| [`backend/app/db/backup.py:164-279`](../../../backend/app/db/backup.py#L164-L279) already implements `_assert_writers_quiesced()` (`BEGIN EXCLUSIVE`), collision-proof `pre_restore_<ts>_<suffix>.db` snapshots, online `sqlite3.Connection.backup()`, integrity re-check, and automatic rollback, but had no host-level writer drain (`DEBT-V1-10`). | Reuse `restore_database_from_backup()` directly inside Slice B3 after disposing SQLAlchemy's async connection pool and draining background workers under `RuntimeLifecycleCoordinator.enter_maintenance_quiescence()`, preserving all WAL/SHM files without unlinking them during active connections. |
| [`backend/app/core/runtime_lifecycle.py:23-314`](../../../backend/app/core/runtime_lifecycle.py#L23-L314) & [`backend/app/main.py:132-220,266-358`](../../../backend/app/main.py#L132-L220) track `_active_asgi_reads`/`_active_asgi_mutations`, `_active_stream_tasks`, and `_pending_persistence_tasks` only for shutdown. Periodic loops in `profile_purge_service.py` and `scheduler/service.py` open `_session_factory()` directly. | Extend `RuntimeLifecycleCoordinator` with `_is_in_maintenance`, `_maintenance_lock`, and `_active_background_db_workers` (`try_acquire_background_db_work()` / `release_background_db_work()`). Place `/api/v1/system/restore` and `/api/v1/system/factory-reset` in `MAINTENANCE_CONTROL_PATHS` in `RuntimeAdmissionASGIMiddleware` so calling them increments neither `_active_asgi_mutations` (no self-deadlock on quiescence) nor lets a second maintenance request run concurrently (HTTP `409 Conflict` via `is_in_maintenance`). |
| [`backend/app/db/session.py:22-93`](../../../backend/app/db/session.py#L22-L93) exposes `initialize_database_runtime(database_url, debug)` and `dispose_database_runtime()`. Note that in FastAPI TestClient/async fixtures, `companion.db` URL may differ from `settings.DATABASE_URL` when tests override the engine URL. | Capture `_engine.url.render_as_string(hide_password=False)` before `dispose_database_runtime()` during maintenance quiescence and pass that exact URL (falling back to `settings.DATABASE_URL` when `_engine is None`) into `initialize_database_runtime(...)` on exit. On Windows, closing SQLite pooled connections frees file handles before DB/asset manipulation. |
| [`backend/app/services/voice/manager.py:90-136`](../../../backend/app/services/voice/manager.py#L90-L136) tracks active WebSocket sessions in `_active_sessions` and can close per-profile sessions via `terminate_sessions_for_profile()`. | Add `terminate_all_sessions(code=1012, reason="runtime_maintenance")` and reject new WS handshakes in `voice.py` while `runtime_lifecycle.is_blocking_admission` is `True`. |
| [`backend/app/models/{profile_session,session_ticket,tool_confirmation,notification_event,routine,reminder,alarm,tool_runtime_config}.py`](../../../backend/app/models/), [`web_secret_store.py:16-74`](../../../backend/app/services/tools/web_secret_store.py#L16-L74), [`config.py:270-298`](../../../backend/app/core/config.py#L270-L298), & [`host_admin.py:14-80`](../../../backend/app/core/host_admin.py#L14-L80) define exact session/credential/scheduler tables and secret paths. | Backup scrubs `profile_sessions`, `session_tickets`, and `tool_confirmations` in the staged copy and excludes `.env` + all secrets (`desktop_admin.secret`, `web_search_api.secret`) + `host_config.json` + `bootstrap.json`. Restore applies Reactivation & Replay Guards in staging before swap. Factory Reset clears `web_search_api.secret` and rotates `COMPANION_API_KEY` (`rotate_pairing_token()`) while keeping `desktop_admin.secret` intact so the Desktop Host-Admin UI remains paired and does not brick itself. |
| [`prepare_database_schema()` (`storage.py:974-1030`)](../../../backend/app/core/storage.py#L974-L1030) and [`007_profiles_and_owner_id_migration.py:57-100`](../../../backend/migrations/versions/007_profiles_and_owner_id_migration.py#L57-L100) cleanly initialize a fresh SQLite DB to Alembic head with a newly generated unique `Default Profile` UUID and starter `CharacterTemplate` seeds. | After Factory Reset removes `companion.db` (`-wal`/`-shm`), calling `prepare_database_schema(canonical_db_path=settings.DATABASE_PATH)` deterministically produces a brand-new verified head database with a fresh Default Profile identity. |
| [`windows_shell_channel.cpp:613-630`](../../../frontend/flutter/apps/desktop/windows/runner/windows_shell_channel.cpp#L613-L630), [`windows_shell_adapter.dart:6-91`](../../../frontend/flutter/apps/desktop/lib/platform/windows_shell_adapter.dart#L6-L91), and `_FakeDesktopShellAdapter` in [`desktop_m2_models_storage_autostart_test.dart:1034`](../../../frontend/flutter/apps/desktop/test/desktop_m2_models_storage_autostart_test.dart#L1034) handle native pickers via `filterPreset`. | Add `filterPreset == "backups"` (`*.zip`) in `windows_shell_channel.cpp`, add `pickBackupArchive()` to `DesktopShellAdapter` & `WindowsShellAdapter`, and update `_FakeDesktopShellAdapter` + any other test fakes in sync. |
| [`settings_storage_section.dart:55-66`](../../../frontend/flutter/apps/desktop/lib/features/settings/sections/settings_storage_section.dart#L55-L66), [`desktop_profile_controller.dart:65-242`](../../../frontend/flutter/apps/desktop/lib/features/profiles/desktop_profile_controller.dart#L65-L242), & [`desktop_shell.dart:1035-1051`](../../../frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart#L1035-L1051) guard `FLUTTER_TEST` offline builds and manage profile session bootstrap. | Gate live backup loading identically (`widget.client != null || !Platform.environment.containsKey('FLUTTER_TEST')`), add fallback `listBackups()` stub on `FakeM2DesktopClient`, add `DesktopProfileController.resetSessionAfterHostDataChange()` to clear revoked local tokens and re-authorize Default Profile after Restore/Reset, and call it from `DesktopShell`. |
| [`contracts/openapi/openapi.json`](../../../contracts/openapi/openapi.json) currently has **`87` paths**, **`119` total routes**, **`147` OpenAPI schemas** (`102` mapped Dart DTOs, `113` native routes; [`test_check_dart_openapi_parity.py:84`](../../../scripts/tests/test_check_dart_openapi_parity.py#L84)). | Adding 6 Host-Admin resilience routes across 5 paths and 11 flat Pydantic schemas yields **`92` paths**, **`125` total routes** (`119` native routes), and **`158` OpenAPI schemas** (`113` mapped Dart DTO schemas). |

---

### Slice-by-Slice Detailed Architecture

#### Slice B1 — Host-Level Maintenance Quiescence Barrier (`DEBT-V1-10`)
- **`backend/app/core/runtime_lifecycle.py`:**
  - Add state fields in `RuntimeLifecycleCoordinator`: `_is_in_maintenance: bool = False`, `_maintenance_reason: Optional[str] = None`, `_active_background_db_workers: int = 0`, `_maintenance_lock: asyncio.Lock` *(reset cleanly in `reset()`)*.
  - Properties: `is_in_maintenance`, `maintenance_reason`, `is_blocking_admission` (`_is_shutting_down or _is_in_maintenance`), and updated `has_active_database_work` (`self._active_asgi_mutations > 0 or self._active_asgi_reads > 0 or self._active_background_db_workers > 0 or active_tasks`).
  - Methods: `try_acquire_background_db_work() -> bool` (returns `False` if `is_blocking_admission`, else increments `_active_background_db_workers`) and `release_background_db_work() -> None`.
  - Async context manager `enter_maintenance_quiescence(reason: str, drain_timeout_seconds: float = 8.0)`:
    1. Reject non-reentrant concurrent entry fail-closed (`RuntimeError` / translated to HTTP `409 Conflict` in endpoints).
    2. Set `_is_in_maintenance = True`, `_maintenance_reason = reason` (only after verifying `_is_shutting_down` is `False`).
    3. Cancel active stream tasks (`_active_stream_tasks`), terminate active Voice WS sessions via `get_voice_manager().terminate_all_sessions(code=1012, reason="runtime_maintenance")`, and wait via `wait_for_database_quiescence(timeout=drain_timeout_seconds)`.
    4. If quiescence times out or persistence tasks failed, restore `_is_in_maintenance = False`, `_maintenance_reason = None` and raise `MaintenanceQuiescenceTimeoutError` (`HTTP 409/503`) before touching SQLite or files.
    5. Capture `active_db_url = engine.url.render_as_string(hide_password=False)` if initialized (else `settings.DATABASE_URL`), call `await dispose_database_runtime()`, yield to caller's critical section, and in `finally:` re-initialize DB runtime (`initialize_database_runtime(database_url=active_db_url, debug=settings.DEBUG)` if previously initialized or cleanly re-created by restore/reset) and clear `_is_in_maintenance` / `_maintenance_reason`.
- **`backend/app/services/{profile_purge_service.py, scheduler/service.py}` & `backend/app/main.py`:**
  - Guard background DB ticks/startup sweeps in `main.py` (`_run_purge_with_startup_sweep`, `_run_scheduler_with_startup_reconcile`), `run_periodic_profile_purge()`, and `run_periodic_scheduler()` with `try_acquire_background_db_work()` / `try ... finally: release_background_db_work()` so maintenance never collides with background sweeps.
  - Update `RuntimeAdmissionASGIMiddleware`:
    - Check `runtime_lifecycle.is_blocking_admission` on normal admission paths (`503` with `code="RUNTIME_IN_MAINTENANCE"` when `_is_in_maintenance`, `"RUNTIME_SHUTTING_DOWN"` when shutting down).
    - Define `MAINTENANCE_CONTROL_PATHS = {"/api/v1/system/restore", "/api/v1/system/factory-reset"}`: bypass read/mutation counters so maintenance requests never deadlock on `_active_asgi_mutations == 1`, while still failing closed with `503 RUNTIME_SHUTTING_DOWN` during shutdown or `409 MAINTENANCE_IN_PROGRESS` if `_is_in_maintenance` is already set.
    - Add `"/api/v1/system/backups"` to `NON_DB_GET_PATHS` (reads `.zip` manifests without opening SQLite).
  - Update `GET /api/v1/health` (returns `503 {"status": "maintenance"}` during maintenance) and `GET /api/v1/system/status` (returns `"degraded"` with `database_connected=False` without touching DB during maintenance), plus Voice WS handshake rejection when `is_blocking_admission`.

#### Slice B2 — Coordinated Database & Profile-Asset Backup Engine (`PC-RESILIENCE-001`)
- **`backend/app/services/backup_service.py` [ADD]:**
  - Canonical backup directory: `settings.BACKUP_DIR` (`<DATA_ROOT>/backups`).
  - Archive naming: `companion_backup_<YYYYMMDD_HHMMSS_ffffff>_<12hex>.zip`; `backup_id` = strict filename stem / basename validated against `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.zip$` (no `/` or `\` or `..`).
  - `create_coordinated_backup(note: Optional[str] = None) -> BackupMetadataOut`:
    1. Validate `settings.DATABASE_PATH` exists and `stat().st_size > 0`.
    2. Use private staging temp dir under `BACKUP_DIR / f".staging_backup_{uuid4().hex[:12]}"` (`try ... finally: shutil.rmtree(..., ignore_errors=True)`).
    3. Copy live SQLite DB via `_copy_via_backup_api(settings.DATABASE_PATH, staged_db)` (WAL-consistent snapshot — captures committed uncheckpointed WAL pages without blocking readers).
    4. **Credential/Transient Scrub on Staged Copy Only:** Open `staged_db`, verify `alembic_version`, run `DELETE FROM profile_sessions; DELETE FROM session_tickets; DELETE FROM tool_confirmations;`, reset `tool_runtime_config.web_search_provider`? *(Wait: backup retains user's non-secret provider selection cleanly while excluding `web_search_api.secret`; Restore applies the Reactivation Guard if the secret is absent on the destination host)*. Run `verify_sqlite_integrity(staged_db)` and collect entity counts (`profiles`, `conversations`, `messages`, `memories`, `character_instances`, `tasks`, `reminders`, `alarms`, `routines`) from `staged_db`.
    5. Collect regular non-symlink, non-reparse files strictly under `settings.ATTACHMENT_DIR` (`attachments/...`) and `settings.CHARACTER_DIR` (`characters/...`) using resolved containment checks (`is_relative_to()`), rejecting or skipping symlinks/reparse points safely.
    6. Compute SHA-256 checksum for `database/companion.db` and every asset entry; write `manifest.json` (`format_version: 1`, `app_version`, `alembic_revision`, `created_at`, `note`, `db_sha256`, `db_size_bytes`, `entity_counts`, `assets: [{archive_path, sha256, size_bytes}]`, `excluded_categories: ["models", "voices", "binaries", "cache", "logs", "backups", "secrets", "host_config", "bootstrap", "sessions", "tickets", "confirmations"]`).
    7. Write `.partial` zip archive (`zipfile.ZIP_DEFLATED`), flush/close, verify readable, then atomically publish via `_publish_without_overwrite(partial_zip, final_zip)`.
  - `list_backups() -> List[BackupMetadataOut]`: enumerate `*.zip` in `BACKUP_DIR` sorted newest-first, reading `manifest.json` safely with corrupt/unreadable marker metadata instead of crashing listing if a partial/corrupt `.zip` exists. Ignores `.partial`, `.staged`, and legacy `pre_migration_*.db` / `pre_restore_*.db` snapshots.
  - `delete_backup(backup_id: str) -> None`: validate `backup_id` strictly, ensure resolved target is strictly inside `BACKUP_DIR.resolve()` and non-reparse `.zip`, remove safely (`404` if missing).

#### Slice B3 — Staged Restore Verification & Quiesced Live Restore (`PC-RESILIENCE-003`, `DEBT-V1-10`)
- **Verification (`verify_backup_archive(backup_id: Optional[str] = None, archive_path: Optional[str] = None) -> BackupVerifyOut`):**
  1. Resolve source archive fail-closed: exactly one of `backup_id` or `archive_path` (validated existing `.zip` regular file, non-symlink/non-reparse, `<= MAX_BACKUP_ARCHIVE_BYTES` / uncompressed total `<= 2 GiB`, entry count `<= 10,000`).
  2. Inspect every `ZipInfo`: reject `..`, drive letters, leading slashes, backslashes normalizing to traversal, Windows reserved chars, Unix symlink external attributes (`S_ISLNK(info.external_attr >> 16)`), and any path outside strict allowlist (`manifest.json`, `database/companion.db`, `attachments/...`, `characters/...`).
  3. Extract to private staging directory cleanly, parse `manifest.json` (`format_version == 1`), verify every listed SHA-256 digest (`database/companion.db` + all `assets`) and verify **no unmanifested extra files** exist in `attachments/` or `characters/`.
  4. Verify `staged_db` with `verify_sqlite_integrity(staged_db)` (integrity + foreign keys).
  5. Inspect `alembic_version` of `staged_db` against the runtime's linear revision chain:
     - Unknown revision or ahead of runtime head -> `compatible = False`, `issues` populated (never touches live DB!).
     - Valid older revision in runtime lineage -> `compatible = True`, `needs_schema_upgrade = True`.
     - Matches runtime head -> `compatible = True`, `needs_schema_upgrade = False`.
  6. Compute attachment referential coherence on `staged_db`: count rows in `attachments` whose referenced relative storage path is missing from staged `attachments/` (`missing_attachment_files: int`, surfaced as advisory warning).
- **Execution (`execute_staged_restore(request: RestoreExecuteRequest) -> RestoreExecuteOut`):**
  1. Enforce `confirm_restore is True` and `confirmation_phrase.strip().upper() == "RESTORE"` (else `HTTP 422`).
  2. Run full staged verification + extract into staging dir BEFORE acquiring maintenance quiescence. Refuse immediately (`HTTP 400`/`422`) if `!valid` or `!compatible`.
  3. If `needs_schema_upgrade`: run `prepare_database_schema(canonical_db_path=staged_db, backup_dir=staging_dir / "upgrade_bak")` on the **staged** DB only; abort if upgrade fails (live DB completely untouched).
  4. Apply **Reactivation Guard & Replay Guard** to `staged_db` BEFORE quiescence (`_apply_restore_safety_guards(staged_db)`):
     - Delete all rows from `profile_sessions`, `session_tickets`, `tool_confirmations`.
     - If `tool_runtime_config.web_search_provider` is `'tavily'` or `'brave'` and `not has_web_search_api_key()`, reset `web_search_provider = 'public_search'`.
     - Mark unread `notification_events` (`status = 'unread'`) as `status = 'read'`, `read_at = COALESCE(read_at, :now_iso)`, `updated_at = :now_iso` so stale backlog toasts do not blast on restore.
     - Advance enabled past-due `routines.next_run_at <= :now` to the next future occurrence using `compute_next_occurrence(...)` (`last_status = 'deferred_restore'`).
     - Advance repeating past-due `alarms` (`next_trigger_at <= :now`) via `compute_next_occurrence(...)`, and disable non-repeating past-due alarms (`enabled = 0, snoozed_until = NULL`).
     - Mark past-due active `reminders` (`status IN ('scheduled', 'snoozed')` where `COALESCE(snoozed_until, scheduled_at) <= :now`) as `status = 'dismissed', acknowledged_at = :now_iso, snoozed_until = NULL` (while leaving all future scheduled/snoozed reminders untouched).
     - Re-run `verify_sqlite_integrity(staged_db)`.
  5. Enter `async with runtime_lifecycle.enter_maintenance_quiescence("backup_restore"):`:
     - Shut down active LLM provider cleanly *only if* loaded/active? Actually keep LLM unloaded or call `llm_manager.get_provider().unload()`? Checking `backup-recovery-and-diagnostics.md`: shutting down active LLM provider ensures no stale conversation context/KV cache outlives DB replacement, and `llama_cpp` lazily restarts on the next turn!
     - Restore database via `safety_snapshot = restore_database_from_backup(staged_db, settings.DATABASE_PATH, safety_dir=settings.BACKUP_DIR)` (double-checks `BEGIN EXCLUSIVE`, takes `pre_restore_*.db`, applies SQLite online backup API, verifies integrity, rolls back DB automatically on DB failure).
     - Atomically swap staged `attachments/` and `characters/` into `settings.ATTACHMENT_DIR` and `settings.CHARACTER_DIR` with sibling backup dirs (`.rollback_attachments_*` / `.rollback_characters_*`): move current aside -> copy/move staged in -> verify integrity -> on any `OSError`, restore both asset dirs from rollback dirs AND roll back `settings.DATABASE_PATH` from `safety_snapshot` via `restore_database_from_backup(...)`! On success, clean up rollback dirs.
     - Ensure `ResourceGovernor` re-reads config/re-evaluates after exit if needed.
  6. Return `RestoreExecuteOut` (`restored=True`, `pre_restore_snapshot_path`, `upgraded_from_revision`, `missing_attachment_files`, `reactivation_guard_applied=True`, `replay_guard_applied=True`, `message`).

#### Slice B4 — Local Admin Factory Reset Engine (`PC-RESILIENCE-004`)
- **`backend/app/core/config.py`:** Add `rotate_pairing_token(self) -> str` generating a new `companion_sec_<token_urlsafe(32)>`, updating `self.COMPANION_API_KEY`, and updating `.env` cleanly via `_persist_key_to_env()`.
- **`backend/app/services/resource_governor.py`:** Add `reset_runtime_state() -> None` clearing cached cooldown/active-game state so first-run defaults take effect immediately after `host_config.json` removal.
- **`backend/app/services/backup_service.py`:** `execute_factory_reset(request: FactoryResetRequest) -> FactoryResetOut`:
  1. Require `confirm_factory_reset is True` and `confirmation_phrase.strip().upper() == "FACTORY RESET"`. If `delete_backups is True` and `confirm_delete_backups is not True`, reject with `HTTP 422`.
  2. Enter `async with runtime_lifecycle.enter_maintenance_quiescence("factory_reset"):`:
     - Call `await reset_voice_manager()` and `await llm_manager.get_provider().shutdown()` cleanly before deleting any files.
     - Clear `web_search_api.secret` (`clear_web_search_api_key()`) and rotate `COMPANION_API_KEY` (`settings.rotate_pairing_token()`). **Strictly preserve `desktop_admin.secret` (`host_admin.py`) and `APP_INSTALL_ROOT`.**
     - Remove `settings.DATABASE_PATH` plus `-wal` and `-shm` sidecars; clear `ATTACHMENT_DIR`, `CHARACTER_DIR`, `MEMORY_DIR`, `CACHE_ROOT`, and `host_config.json` (plus stale `.tmp.*` files).
     - ONLY if `delete_models is True`: clear `MODEL_LIBRARY_DIR`, `VOICE_LIBRARY_DIR`, `INSTALLED_REGISTRY_PATH`, `IMPORT_INBOX_DIR`, `IMPORT_STAGING_DIR` (if `COMPANION_LIBRARY_ROOT` points outside `DATA_ROOT`, remove contents cleanly without deleting root folder itself or breaking `bootstrap.json` unless reset safely; keeping `models` untouched when `delete_models is False` is the default).
     - ONLY if `delete_backups is True and confirm_delete_backups is True`: clear `settings.BACKUP_DIR` contents (preserving default `False`).
     - Recreate `DATABASE_DIR`, run `prepare_database_schema(canonical_db_path=settings.DATABASE_PATH)` synchronously/in-thread, query the newly created `Default Profile` ID via short `sqlite3` check, call `resource_governor.reset_runtime_state()`, and let quiescence exit re-initialize the SQLAlchemy async engine on the fresh database!
  3. Return `FactoryResetOut` (`reset_completed=True`, `fresh_default_profile_id`, `models_deleted`, `backups_deleted`, `pairing_token_rotated=True`, `message`).

#### Slice B5 — OpenAPI 3.1, `companion_api` Parity, Win32 Picker & Desktop UI (`PC-API-001`, `PC-CLIENT-011`)
- **Backend Schemas (`backend/app/schemas/backup.py` [ADD]):**
  Define 11 flat Pydantic schemas:
  1. `BackupEntityCountsOut` (`profiles`, `conversations`, `messages`, `memories`, `character_instances`, `tasks`, `reminders`, `alarms`, `routines`)
  2. `BackupMetadataOut` (`backup_id`, `filename`, `archive_path`, `created_at`, `app_version`, `alembic_revision`, `size_bytes`, `db_sha256`, `asset_count`, `valid`, `error`, `note`, `entity_counts`, `excluded_categories`)
  3. `BackupListOut` (`backup_dir`, `backups`)
  4. `BackupCreateRequest` (`note: Optional[str] = Field(default=None, max_length=200)`)
  5. `BackupVerifyRequest` (`backup_id: Optional[str] = None`, `archive_path: Optional[str] = None`)
  6. `BackupVerifyOut` (`valid`, `compatible`, `needs_schema_upgrade`, `source_path`, `alembic_revision`, `current_head_revision`, `db_sha256`, `verified_asset_count`, `missing_attachment_files`, `entity_counts`, `warnings`, `errors`)
  7. `RestoreExecuteRequest` (`backup_id: Optional[str] = None`, `archive_path: Optional[str] = None`, `confirm_restore: bool = False`, `confirmation_phrase: str = ""`)
  8. `RestoreExecuteOut` (`restored`, `pre_restore_snapshot_path`, `upgraded_from_revision`, `restored_asset_count`, `missing_attachment_files`, `reactivation_guard_applied`, `replay_guard_applied`, `message`)
  9. `FactoryResetRequest` (`confirm_factory_reset: bool = False`, `confirmation_phrase: str = ""`, `delete_models: bool = False`, `delete_backups: bool = False`, `confirm_delete_backups: bool = False`)
  10. `FactoryResetOut` (`reset_completed`, `fresh_default_profile_id`, `models_deleted`, `backups_deleted`, `pairing_token_rotated`, `message`)
  11. `BackupDeleteOut` (`deleted`, `backup_id`, `message`) *(if keeping DELETE cleanly typed alongside other delete endpoints; double-check exact count matches `11` schemas and `6` routes!)*
- **Host-Admin REST Endpoints (`backend/app/api/v1/endpoints/system_resilience.py` [ADD] included in `system_router` with `require_host_admin`):**
  - `GET /api/v1/system/backups` -> `listBackups()` (`BackupListOut`)
  - `POST /api/v1/system/backups` (`201 Created`) -> `createBackup()` (`BackupMetadataOut`)
  - `DELETE /api/v1/system/backups/{backup_id}` -> `deleteBackup()` (`BackupDeleteOut`)
  - `POST /api/v1/system/backups/verify` -> `verifyBackup()` (`BackupVerifyOut`)
  - `POST /api/v1/system/restore` -> `restoreBackup()` (`RestoreExecuteOut`)
  - `POST /api/v1/system/factory-reset` -> `factoryReset()` (`FactoryResetOut`)
- **Contract & Parity (`contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`):**
  - Regenerate `contracts/openapi/openapi.json` (`87` -> `92` paths, `119` -> `125` total routes, `147` -> `158` schemas).
  - Add `frontend/flutter/packages/companion_api/lib/dto/backup_dto.dart`, export in `companion_api.dart`, add 6 methods to `CompanionClient`, register all 11 schemas (`102` -> `113`) & 6 native routes (`113` -> `119`) in `check_dart_openapi_parity.py`, update `test_check_dart_openapi_parity.py:84` (`113` -> `119`).
- **Desktop Win32 Channel & UI (`windows_shell_channel.cpp`, `windows_shell_adapter.dart`, `desktop_profile_controller.dart`, `settings_*`, `desktop_shell.dart`):**
  - Extend `pickFiles` in `windows_shell_channel.cpp` with `filterPreset == "backups"` (`*.zip`), add `pickBackupArchive()` to `DesktopShellAdapter` / `WindowsShellAdapter`, update test fakes (`_FakeDesktopShellAdapter`).
  - Add `DesktopProfileController.resetSessionAfterHostDataChange()`: clears saved session token/expiry/`explicitlyLocked`/selectedProfileId in `DesktopClientSettings` & `sessionStore`, resets `chat` session cleanly via `chat.clearSession()` or `chat.selectProfile(...)`, calls `refresh(initializeDefault: true)` so the freshly restored or newly seeded Default Profile activates smoothly without requiring a manual restart.
  - Enhance `SettingsStorageSection` with two clean SoftGlass panels above **Advanced Storage & Developer Diagnostics**:
    1. **Backup & Restore Card:** **Create Backup** button (with optional note field), **Refresh**, **Open Backups Folder**, **Import / Verify `.zip`...** (calls `_shell.pickBackupArchive()`), list of available backup bundles (`createdAt`, size, entity counts, integrity badge, **Verify & Restore** button, **Delete** button with confirmation), and a two-step **Staged Restore Preview & Confirm** dialog showing manifest counts, schema compatibility / missing-attachment warnings, reactivation/replay guard notice, and typed `"RESTORE"` confirmation input.
    2. **Factory Reset Card (Danger Zone):** Clear Risk 2 explanation, OFF-by-default switch `Delete downloaded/imported AI models & voices`, OFF-by-default switch `Delete saved backup archives` + secondary irreversible acknowledgment checkbox (enabled only when `delete_backups` is ON), and two-step **Confirm Factory Reset** dialog requiring typed `"FACTORY RESET"` confirmation.
  - Wire `onHostDataChanged` from `SettingsStorageSection` -> `SettingsScreen` -> `DesktopShell`, resetting `DesktopProfileController`, resetting/reloading schedule & memory & voice state safely (`_scheduleController`, `_memoryController`, `_voiceController`), and calling `controller.notifyStorageChanged()`.

---

## 3. Proposed File Changes & In-Place Logic

### [MODIFY] `backend/app/core/runtime_lifecycle.py`, `backend/app/main.py`, `backend/app/services/{profile_purge_service.py, scheduler/service.py, voice/manager.py}`, `backend/app/api/v1/endpoints/voice.py`
- **Primary Responsibility:** Host-level maintenance quiescence barrier (`DEBT-V1-10`).
- **Planned Change:** Add `enter_maintenance_quiescence()`, background DB worker tracking, `MAINTENANCE_CONTROL_PATHS`, `GET /api/v1/system/backups` in `NON_DB_GET_PATHS`, `/api/v1/health` `503 maintenance` status, and `VoiceManager.terminate_all_sessions()`.
- **Invariants to Preserve:** Shutdown quiescence (`test_runtime_boundary_regressions.py`, `test_d9_tools_and_policy.py`) remains completely intact; self-deadlock on `/system/restore` and `/system/factory-reset` is structurally impossible.

### [ADD] `backend/app/services/backup_service.py` & `backend/app/schemas/backup.py` + [MODIFY] `backend/app/core/config.py`, `backend/app/services/resource_governor.py`
- **Primary Responsibility:** Coordinated `.zip` backup creation/listing/deletion, staged Zip-Slip/SHA-256/integrity/compatibility verification, Reactivation/Replay-guarded live quiesced restore with dual rollback, and Host-Admin Factory Reset (`PC-RESILIENCE-001`, `003`, `004`).
- **Planned Change:** Implement atomic `.partial` -> `os.link` archive creation, credential scrubbing, `verify_backup_archive()`, `execute_staged_restore()`, `execute_factory_reset()`, `Settings.rotate_pairing_token()`, and `ResourceGovernor.reset_runtime_state()`.
- **Invariants to Preserve:** Never package secrets/`.env`/`models`/`voices`/`binaries`; never modify live DB/assets on verification failure; always roll back both DB (`pre_restore_*.db`) and assets on swap failure; never remove `desktop_admin.secret`.

### [MODIFY] `backend/app/api/v1/endpoints/health.py` (or [ADD] `system_resilience.py`), `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`, `frontend/flutter/packages/companion_api/*`
- **Primary Responsibility:** Expose 6 Host-Admin REST endpoints and maintain 1:1 OpenAPI <-> Dart parity (`PC-API-001`).
- **Planned Change:** Add 6 endpoints, regenerate `openapi.json`, create `backup_dto.dart`, add 6 `CompanionClient` methods, and extend parity registry (`119` routes, `113` DTO schemas).
- **Invariants to Preserve:** Fail-closed `require_host_admin` isolation on all 6 endpoints; strict non-nullable/nullable field parity.

### [MODIFY] `windows_shell_channel.cpp`, `windows_shell_adapter.dart`, `desktop_profile_controller.dart`, `settings_section.dart`, `settings_storage_section.dart`, `settings_screen.dart`, `desktop_shell.dart`
- **Primary Responsibility:** Native `.zip` picker, consumer **Backup & Restore** + **Factory Reset** UI, and clean post-Restore/Reset Desktop Profile/Voice re-bootstrap (`PC-CLIENT-011`).
- **Planned Change:** Add `"backups"` `pickFiles` filter preset and `pickBackupArchive()`, build Backup & Factory Reset cards with preview & typed confirmations, and wire `resetSessionAfterHostDataChange()`.
- **Invariants to Preserve:** `FLUTTER_TEST` offline guards when `client == null`; existing M2 Storage relocation & collapsible Advanced Diagnostics tests stay green.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Slice B1 (Maintenance Quiescence):** Write failing concurrency/quiescence/Voice-WS/background-worker tests (`test_runtime_maintenance_quiescence.py`) -> implement `RuntimeLifecycleCoordinator.enter_maintenance_quiescence()`, worker tracking, middleware updates, `/health` maintenance response, and `VoiceManager.terminate_all_sessions()` -> GREEN.
2. **Slice B2 & B3 (Coordinated Backup & Staged Quiesced Restore):** Write failing tests for `.zip` bundling, secret exclusion, session scrubbing, Zip-Slip/symlink/checksum-tamper/forward-revision rejection, attachment coherence warning, older-revision staged upgrade, Reactivation & Replay Guards, and failed-asset-swap dual rollback (`test_coordinated_backup_restore_reset.py`) -> implement `backup_service.py` -> GREEN.
3. **Slice B4 (Local Admin Factory Reset):** Write failing tests for Risk 2 confirmation guards (`"FACTORY RESET"`, `delete_backups` double-opt-in), default preservation of models/voices/backups/`desktop_admin.secret`, token rotation, and fresh Default Profile seeding -> implement `execute_factory_reset()` + `rotate_pairing_token()` -> GREEN.
4. **Slice B5 (Endpoints, OpenAPI/Dart Parity, Win32 Picker & Desktop UI):** Expose Host-Admin REST endpoints, regenerate `openapi.json`, implement `backup_dto.dart` + `CompanionClient` methods + DTO tests, update `check_dart_openapi_parity.py`, add Win32 `"backups"` picker, update `SettingsStorageSection` + `DesktopProfileController` + `DesktopShell`, write `desktop_m5_backup_restore_reset_test.dart`, and verify Windows Debug build.
5. **Phase 3 Documentation & Closure:** Update `backup-recovery-and-diagnostics.md`, `storage-and-assets.md`, `DECISION_DEBT.md` (`DEBT-V1-10` resolved), `WBS.md`, `MASTER_CHECKLIST.md`, `DELIVERY_INDEX.md`, `task.md`, `CHANGELOG.md`, `docs/03_Walkthroughs/walkthrough-m5-backup-restore-reset-b.md`, archive `task-feature-m5-backup-restore-reset-b.md`, commit, push, and open Draft PR against `develop`.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Full backend suite: `backend\.venv\Scripts\python.exe -m pytest backend\tests -q -p no:cacheprovider -o log_file=NUL`
- [ ] Isolation & lockfile: `$env:PYTHONPATH="backend;."; backend\.venv\Scripts\python.exe -m unittest backend.tests.test_import_isolation scripts.tests.test_python_dependency_lock -v`
- [ ] OpenAPI & Dart parity: `backend\.venv\Scripts\python.exe scripts\check_openapi_contract.py --check`, `backend\.venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check`, and `backend\.venv\Scripts\python.exe -m unittest scripts\tests\test_check_dart_openapi_parity.py -v`
- [ ] Dart analysis & SDK tests: `cd frontend\flutter && dart analyze .`, `companion_core` & `companion_api` `dart test`
- [ ] Desktop suite & Windows MSVC `/W4 /WX` build: `cd frontend\flutter\apps\desktop && flutter test --no-pub --concurrency=1 test` and `flutter build windows --debug --no-pub`
- [ ] Diff hygiene: `git diff --check develop`

### Manual Windows Host QA Checklist (Required — UI Modified)
- [ ] In Desktop `Settings -> Storage, Backup & Reset`, click **Create Backup** and confirm the new `.zip` bundle appears with accurate entity counts and `manifest.json` (`database/`, `attachments/`, `characters/` — zero models, voices, secrets, or `host_config.json`).
- [ ] Delete/alter a conversation, attachment, or secondary Profile, then click **Verify & Restore** on the backup bundle (and also test **Import / Verify `.zip`...** via native Win32 Explorer picker), confirm the preview summary renders cleanly, type `RESTORE`, and verify the restored state reappears in Chat / Profiles with prior active sessions revoked and no past-due notification replay storm.
- [ ] Trigger **Factory Reset** with default switches OFF (typing `FACTORY RESET`), verify Chat/Memories/Profiles return to a fresh **Default Profile** with a new UUID while saved GGUF models, voices, and previous backup `.zip` bundles remain intact on disk.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *Self-deadlock inside maintenance endpoints:* Placing `/api/v1/system/restore` and `/api/v1/system/factory-reset` in `MAINTENANCE_CONTROL_PATHS` ensures middleware does not count them inside `_active_asgi_mutations`, while `_maintenance_lock` serializes maintenance operations cleanly.
  - *Windows SQLite file lock (`EBUSY` / `PermissionError`):* Disposing `_engine` via `dispose_database_runtime()` after draining active ASGI reads/mutations and background workers releases pooled connections before `restore_database_from_backup()` / unlink runs.
  - *Partial restore corruption if DB succeeds and asset copy fails:* Keeping `safety_snapshot` (`pre_restore_*.db`) AND sibling asset rollback directories inside quiescence allows atomic dual rollback of both DB and assets if anything throws before completion.
  - *Locking out Desktop Host-Admin after Factory Reset:* `execute_factory_reset()` rotates `COMPANION_API_KEY` pairing token and clears `web_search_api.secret` while strictly leaving `desktop_admin.secret` (`host_admin.py`) intact, and Desktop calls `DesktopProfileController.resetSessionAfterHostDataChange()`.
  - *Zip-Slip / Zip-Bomb / symlink traversal:* `verify_backup_archive()` inspects every `ZipInfo` entry before extraction, rejects traversal/symlinks/disallowed prefixes/unmanifested assets, and bounds total entry count & uncompressed byte size.
- **Required Permissions:** Task-bounded branch creation, commits, push, and Phase 3 Draft PR on `feature/m5-backup-restore-reset-b` (once Phase 1 plan approval is granted).
- **Genuine Stop Conditions:** Any unexpected Alembic migration requirement, Windows file-lock failure during quiesced engine disposal that cannot be resolved without process restart, security conflict, or unresolvable test failure.
