# Implementation Plan: M2 Batch E — Five Storage Roots, Relocatable Library, D6 Controlled Model Import, Desktop Model Management UI & Windows Login Autostart

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Awaiting Approval (Phase 1 Plan Gate)
- **Delivery Level:** Level C — Sensitive Design
- **Scope Mode:** New Feature — M2 Batch E Host Storage Roots & Relocatable Library (`PC-HOST-004`), Decision D6 Controlled Local Model Import & Schema v3 Registry Writer (`PC-MODEL-001`..`006`), Desktop Model Management & Hardware Profile UI (`PC-CLIENT-010`), and Windows Task Scheduler Login Autostart (`PC-HOST-002`). *(Profile PIN lock and Satellite Device Enrollment `PC-IDENTITY-003` remain explicitly deferred per Human Owner direction.)*
- **Target Files:**
  - `backend/app/core/` (`storage.py`, `config.py`)
  - `backend/app/schemas/` (`health.py`, `model_registry.py`)
  - `backend/app/services/` (`model_registry.py`, `model_import.py` [ADD], `autostart.py` [ADD], `host_config.py`, `llm/manager.py`, `llm/llama_cpp.py`)
  - `backend/app/api/v1/endpoints/` (`health.py`, `llm.py`)
  - `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, & `scripts/tests/test_check_dart_openapi_parity.py`
  - `frontend/flutter/packages/companion_api/lib/` (`dto/model_registry_dto.dart`, `dto/system_status_dto.dart`, `client/companion_client.dart`)
  - `frontend/flutter/apps/desktop/lib/` (`main.dart`, `screens/settings_screen.dart`, `features/settings/sections/settings_runtime_section.dart`, `features/settings/sections/settings_storage_section.dart`, `features/settings/sections/settings_general_section.dart`)
  - `backend/tests/` (`test_bootstrap.py`, `test_storage_engine_lifecycle.py`, `test_model_registry.py`, `test_d6_model_import_and_autostart.py` [ADD])
  - `frontend/flutter/packages/companion_api/test/` (`m2_models_storage_autostart_dto_test.dart` [ADD])
  - `frontend/flutter/apps/desktop/test/` (`desktop_m2_models_storage_autostart_test.dart` [ADD], updates to `desktop_settings_revamp_test.dart` / `desktop_settings_test.dart` if assertions expand)
  - Phase 3 docs: canonical specs (`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`, `runtime-and-models.md`, `windows-host-and-notifications.md`), `docs/02_Planning/00_Master/` (`DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `SPRINT_ROADMAP.md`), `CHANGELOG.md`, walkthrough (`docs/03_Walkthroughs/walkthrough-m2-models-storage-autostart-e.md`), and archived branch tracker.
- **Branch:** `feature/m2-models-storage-autostart-e`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m2-models-storage-autostart-e.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m2-models-storage-autostart-e.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:** Complete the remaining Milestone M2 host, storage, and local model management foundation for PC V1 (with Profile PIN lock and Satellite Device Enrollment `PC-IDENTITY-003` explicitly deferred):
  1. **Five Storage Roots & Relocatable `LIBRARY_ROOT` (`PC-HOST-004`):** Extend `backend/app/core/storage.py` and `config.py` so `CanonicalPaths` resolves all 5 canonical roots (`APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`), supports an optional `library_root` pointer inside `%LOCALAPPDATA%\AI Companion\bootstrap.json` plus `COMPANION_LIBRARY_ROOT` override, aligns `IMPORT_INBOX_DIR` (`<LIBRARY_ROOT>/imports/inbox`) and `IMPORT_STAGING_DIR` (`<LIBRARY_ROOT>/imports/staging`) directly under `LIBRARY_ROOT` (resolving the discrepancy documented in `storage-and-assets.md` §3.4 and keeping staging on the same filesystem volume for atomic `os.replace`), and exposes Host-Admin inspection and library relocation endpoints (`GET /api/v1/system/storage`, `PUT /api/v1/system/storage/library-root`).
  2. **Decision D6 Controlled Local Model Import & Schema v3 Registry Writer (`PC-MODEL-001`..`006`):** Implement the executable D6 pipeline (`inbox -> manual scan -> GGUF metadata & capability inspection -> preflight hardware/VRAM suitability -> user confirmation -> staging -> SHA-256 & header verification -> atomic os.replace install -> Library -> Schema v3 models.json Registry`) without any automatic background filesystem watcher or unrestricted host path authority, plus user-installed model removal (`DELETE /api/v1/models/registry/{model_id}`).
  3. **Desktop Model Management & Storage UI (`PC-CLIENT-010`):** Upgrade `Settings -> AI Runtime & Models` with an interactive Hardware Performance Profile selector (`eco` / `balanced` / `maximum` wired to `PATCH /api/v1/models/profile`), rich GGUF metadata + advisory VRAM suitability badges + uninstall action on user-imported model cards, and an interactive **D6 Model Import Inbox** card (inbox folder path copy, **Scan Inbox**, `.gguf` + `mmproj` candidate bundle preview with editable display name, and **Install Bundle** confirmation). Upgrade `Settings -> Storage & Diagnostics` with live backend telemetry across all 5 storage roots and interactive `LIBRARY_ROOT` relocation controls.
  4. **Windows Task Scheduler Login Autostart (`PC-HOST-002`):** Implement standard-user Windows Task Scheduler registration (`At log on` of the current user, zero UAC elevation, launching AI Companion minimized to the system tray while respecting intentional-exit restart suppression), expose `GET /api/v1/system/autostart` and `PUT /api/v1/system/autostart`, add `--minimized-to-tray` / `--autostart` handling in `frontend/flutter/apps/desktop/lib/main.dart`, and replace the static `PLANNED (PC-HOST-002)` banner in `Settings -> General & Lifecycle` with a live autostart switch.
- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) — §3 Invariants #2 (D2 Host Lifecycle), #6 (Single Resident Model Default), #7 (Five Storage Roots), #9 (`ADR-0019`), and §5 Golden Groups G1 & G3.
  - [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](../../04_Architecture/04_Infrastructure/storage-and-assets.md) — §2.1 (Five Storage Roots & Relocatable `LIBRARY_ROOT`), §3.1–§3.4 (bootstrap locator, canonical taxonomy, D6 import path discrepancy), §4.1 (Relocatable `LIBRARY_ROOT` target), and §6 (path containment & atomic writes).
  - [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](../../04_Architecture/04_Infrastructure/runtime-and-models.md) — §2.1 (Single Resident Model), §2.2 (Frozen D6 Pipeline), §2.5 (Model Registry, Artifact & Capability Semantics), §2.8 (Dynamic Selection Precedence & Advisory Hardware-Aware Recommendation under `PC-CLIENT-010`), §3.3–§3.4 (GGUF Parser & D6 gap), and §6 (Safe Model Format Boundary).
  - [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md) — §2.1–§2.2 (Decoupled lifecycle, `PC-HOST-002` Task Scheduler dual autostart at login with standard privileges & intentional-exit suppression), §4.1, and §6 (Loopback & standard-user boundaries).
  - [`docs/04_Architecture/decisions/ADR-0003-d2-windows-host-model.md`](../../04_Architecture/decisions/ADR-0003-d2-windows-host-model.md) — D2 Windows host lifecycle & Task Scheduler autostart `At log on`.
  - [`docs/04_Architecture/decisions/ADR-0007-d6-controlled-model-acquisition.md`](../../04_Architecture/decisions/ADR-0007-d6-controlled-model-acquisition.md) — D6 manual inbox scan, multi-file `.gguf` + `mmproj` atomic bundle install, zero background watcher.
  - [`docs/02_Planning/00_Master/WBS.md`](../00_Master/WBS.md) — `PC-HOST-002`, `PC-HOST-004`, `PC-MODEL-001`..`006`, `PC-CLIENT-010`, `PC-API-001`.
- **Concrete Deliverables:**
  1. Updated `backend/app/core/storage.py` & `config.py` resolving all 5 storage roots (`APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`), optional `library_root` relocation in `bootstrap.json` + `COMPANION_LIBRARY_ROOT`, and `IMPORT_INBOX_DIR`/`IMPORT_STAGING_DIR` under `LIBRARY_ROOT`.
  2. `backend/app/services/model_import.py`, enhanced `model_registry.py`, and `llm/manager.py` (auto-detecting user-installed GGUFs under `MODEL_LIBRARY_DIR`) delivering D6 scan, GGUF + `mmproj` bundle pairing, preflight hardware/VRAM suitability, staging, atomic install to `<LIBRARY_ROOT>/models/llm/<model_id>/`, Schema v3 `models.json` registry persistence, and safe installed-model removal.
  3. `backend/app/services/autostart.py` + `host_config.py` persistence managing standard-user Windows Task Scheduler registration (`AICompanionAutostart`, `ONLOGON`), paired with `--minimized-to-tray` startup handling in `main.dart`.
  4. Seven new OpenAPI endpoints (`/api/v1/system/storage`, `/api/v1/system/storage/library-root`, `/api/v1/system/autostart` GET/PUT, `/api/v1/models/import/scan`, `/api/v1/models/import/install`, `/api/v1/models/registry/{model_id}` DELETE) plus regenerated `contracts/openapi/openapi.json`, strict `companion_api` DTO & `CompanionClient` parity, and upgraded `scripts/check_dart_openapi_parity.py`.
  5. Updated Flutter Desktop UI across `SettingsRuntimeSection` (`PC-CLIENT-010`), `SettingsStorageSection` (`PC-HOST-004`), and `SettingsGeneralSection` (`PC-HOST-002`), plus comprehensive pytest, Dart unit, and Flutter widget test suites.
- **Explicit Out-of-Scope:**
  - Profile PIN / Windows Hello protection (`PC-IDENTITY-004` PIN follow-up) — deferred by Human Owner.
  - Satellite Device Enrollment (`PC-IDENTITY-003`) — deferred to future Mobile pairing / M5 Network & Mesh work.
  - Managed online Hugging Face Hub downloading (`PC Later` per `runtime-and-models.md` §2.3).
  - Self-contained Windows installer packaging (`PC-HOST-006` / `DEBT-V1-09`, `OPEN DESIGN`).
  - Milestone M5 Low-Impact / Gaming Mode (`PC-RESOURCE-*`), Cloud Fallback (`PC-CLOUD-*`), and Backup / Factory Reset (`PC-RESILIENCE-*`).
  - React Web UI (`frontend/web/`) and Android (`android/`).

---

## 2. Architecture & Technical Approach

- **Current Findings & Technical Baseline:**

  | Observation / Evidence | Verified Interpretation |
  | --- | --- |
  | `backend/app/core/storage.py` (`resolve_data_root`, `write_bootstrap`, `get_canonical_paths`) resolves only `COMPANION_DATA_ROOT`, puts `IMPORT_INBOX_DIR` and `IMPORT_STAGING_DIR` directly under `DATA_ROOT/imports/` (noted as technical debt in `storage-and-assets.md` §3.4), and omits `APP_INSTALL_ROOT`, `CACHE_ROOT`, and `LOG_ROOT` from `CanonicalPaths`. `test_bootstrap.py:96-108` asserts exact keys `{"schema_version", "data_root"}` on `write_bootstrap(data_root=..., schema_version=1)`, and `test_storage_engine_lifecycle.py:28-29` asserts default `IMPORT_*` paths. | Keep `write_bootstrap()` backward-compatible by omitting `library_root` JSON key unless explicitly supplied (and validating any existing `library_root` inside `bootstrap.json` as an absolute path fail-closed). Move `IMPORT_INBOX_DIR` and `IMPORT_STAGING_DIR` under `LIBRARY_DIR` (`LIBRARY_DIR / "imports" / "inbox"` & `"staging"`), add `APP_INSTALL_ROOT`, `CACHE_ROOT`, and `LOG_ROOT` to `CanonicalPaths`, and update `test_storage_engine_lifecycle.py` in sync so staging and final library always share the same volume for atomic `os.replace`. |
  | `backend/app/services/model_registry.py` already parses GGUF v2/v3 headers (`read_gguf_metadata` reading `general.architecture`, `<arch>.context_length`, `general.file_type`, `general.quantization_version`), merges `models/registry.template.json` + `INSTALLED_REGISTRY_PATH`, and validates primary & companion artifacts cleanly, while `backend/app/services/llm/manager.py:40-50` only scans `settings.MODELS_DIR` (factory folder) in `auto` mode. | Reuse and extend `read_gguf_metadata()` (extracting `general.name`, parameter hints, vision tensor/modality hints, `tokenizer.chat_template` presence) rather than duplicating a GGUF parser. Add `model_import.py` to scan `IMPORT_INBOX_DIR`, pair `mmproj*.gguf` projectors, stage and SHA-256 verify bundles, and atomically install to `MODEL_LIBRARY_DIR` + write Schema v3 `INSTALLED_REGISTRY_PATH`. Also update `LLMManager.get_provider()` to check `settings.MODEL_LIBRARY_DIR` alongside `settings.MODELS_DIR`. |
  | `backend/app/api/v1/endpoints/llm.py` already defines `PATCH /api/v1/models/profile` (`ModelProfileUpdateRequest`), and `LlamaCppProvider` (`llama_cpp.py`) supports loading/unloading from both `FACTORY_MODEL_ROOT` and `MODEL_LIBRARY_DIR`, but `CompanionClient` does not yet wrap `PATCH /api/v1/models/profile` and `SettingsRuntimeSection` has no UI selector for `eco` / `balanced` / `maximum` nor D6 inbox import controls. | Expose `CompanionClient.updateModelProfile(profile)` alongside new `scanImportInbox()`, `installImportCandidate()`, `deleteInstalledModel()`, `getStorageRoots()`, `updateLibraryRoot()`, `getAutostartStatus()`, and `updateAutostartStatus()` methods, updating `check_dart_openapi_parity.py` to promote all M2 model/storage/autostart routes out of `UNMAPPED_FUTURE_ROUTES`. |
  | `scripts/check_dart_openapi_parity.py:345-420` strictly requires every class mapped in `SCHEMA_TO_DART_CLASS` to match every OpenAPI property via `snake_to_camel()` with zero extra unmapped `final` fields (`ModelRegistryEntry` currently uses nested `manifest`/`library_state`/`hints` in OpenAPI while flattening in Dart, so it is not listed in `SCHEMA_TO_DART_CLASS`). | Keep existing `ModelRegistryEntry` backward-compatible with UI callers (extending it safely only via non-breaking optional fields or JSON getters), and design all **new** API DTOs (`StorageRootOut`, `StorageRootsResponse`, `LibraryRootUpdateRequest`, `AutostartStatusOut`, `AutostartUpdateRequest`, `ModelImportCandidateOut`, `ModelImportScanOut`, `ModelImportInstallRequest`, `ModelImportInstallOut`, `ModelDeleteOut`, `CompanionArtifactHintOut`, `PreflightAssessmentOut`) with 1:1 flat `snake_case` <-> `camelCase` field parity so every new schema is strictly verified in `SCHEMA_TO_DART_CLASS`. |
  | `frontend/flutter/apps/desktop/lib/main.dart:68-71` calls `coordinator.initialize(initialWindowSize: initialSize, maximizeOnStart: ...)` which defaults to `showImmediately: true` (always showing the window at launch even when launched at login), while `DesktopLifecycleCoordinator` (`desktop_lifecycle_coordinator.dart:59-63`) already supports `showImmediately: false`! | Parse `--minimized-to-tray` (and `--autostart`) unconditionally in `main.dart` (not gated behind `kDebugMode`!), pass `showImmediately: !(hasMinimizedFlag && awaitTraySafe)` (or keep `showImmediately: false` when tray initializes cleanly, falling back to showing the window if tray initialization fails so the user is never stranded without UI!). |
  | `backend/tests/test_import_isolation.py` runs an audit hook during FastAPI app / module imports that raises `ForbiddenLocalState` on any import-time file write, `.db` open, socket connect, or `subprocess.Popen`. | Keep all storage path resolution, GGUF reading, and `schtasks.exe` inspection strictly lazy (inside service/endpoint calls), never at module import time. |

- **Architectural Approach:**
  1. **Slice 1 — Five Storage Roots & Relocatable `LIBRARY_ROOT` (`PC-HOST-004`):**
     - **Path Resolution (`backend/app/core/storage.py`, `config.py`):**
       - Add pure resolvers:
         - `resolve_library_root(data_root, env_override=None, bootstrap_path=None) -> Path`: precedence `COMPANION_LIBRARY_ROOT` -> `bootstrap.json['library_root']` (failing closed with `BootstrapCorruptError` / `StorageError` if invalid JSON, non-string, empty, or relative) -> `(data_root / "library").resolve()`. Also validate `library_root` inside `resolve_data_root()` only as pass-through when `bootstrap.json` is parsed (extending schema validation cleanly so optional `"library_root"` must be a non-empty absolute string if present).
         - `resolve_cache_root(env_override=None) -> Path`: `COMPANION_CACHE_ROOT` -> `%LOCALAPPDATA%\AI Companion\Cache` (or `~/.cache/AI Companion` fallback).
         - `resolve_log_root(env_override=None) -> Path`: `COMPANION_LOG_ROOT` -> `%LOCALAPPDATA%\AI Companion\Logs` (matching `windows-host-and-notifications.md` §3).
         - `resolve_app_install_root(env_override=None) -> Path`: `COMPANION_APP_INSTALL_ROOT` -> repository/executable install root (`settings.BASE_DIR.parent.resolve()`).
       - Update `write_bootstrap(data_root, bootstrap_path=None, schema_version=1, library_root=None)`: preserves exact `{"schema_version": 1, "data_root": ...}` output when `library_root is None` (preserving existing `test_bootstrap.py` assertions), and atomically writes optional `"library_root": str(library_root.resolve())` when provided; reject relative `library_root` with `StorageError`.
       - Update `get_canonical_paths(data_root, library_root=None, cache_root=None, log_root=None, app_install_root=None) -> CanonicalPaths`:
         - Include `APP_INSTALL_ROOT`, `CACHE_ROOT`, `LOG_ROOT` alongside existing fields.
         - Set `IMPORT_INBOX_DIR = library_dir / "imports" / "inbox"` and `IMPORT_STAGING_DIR = library_dir / "imports" / "staging"`.
       - Expose `APP_INSTALL_ROOT`, `CACHE_ROOT`, `LOG_ROOT`, and `LIBRARY_DIR` properties on `Settings` (`config.py`), updating `canonical_paths` property to pass `resolve_library_root(...)`.
     - **Storage Telemetry & Relocation Endpoints (`backend/app/schemas/health.py`, `backend/app/api/v1/endpoints/health.py`):**
       - `StorageRootOut`: `root_type` (`"app_install" | "data" | "library" | "cache" | "log"`), `path`, `exists`, `writable`, `free_bytes`, `total_bytes`, `is_relocated`, `source` (`"env_override" | "bootstrap" | "default"`).
       - `StorageRootsResponse`: `roots: List[StorageRootOut]`, `bootstrap_path: str`, `import_inbox_dir: str`, `import_staging_dir: str`, `model_library_dir: str`, `active_model_loaded: bool`.
       - `LibraryRootUpdateRequest`: `new_library_root: str`, `migrate_existing_assets: bool = True`.
       - `GET /api/v1/system/storage` (`verify_telemetry`): returns live telemetry (`shutil.disk_usage` on nearest existing ancestor when root directory doesn't exist yet) and directory writability checks.
       - `PUT /api/v1/system/storage/library-root` (`require_host_admin`): validates absolute path (rejects relative paths, symlinks escaping or nested inside `IMPORT_STAGING_DIR`, or `COMPANION_LIBRARY_ROOT` env override conflict), checks active LLM provider (`409 Conflict` `MODEL_ACTIVE_UNLOAD_REQUIRED` if loaded/busy), creates target `<new_library_root>/{models/llm,registry,voices,imports/inbox,imports/staging}`, optionally copies/verifies existing `LIBRARY_ROOT` contents (preserving source backup or cleaning safely after SHA-256/size verification), atomically updates `bootstrap.json` via `write_bootstrap()`, and returns updated `StorageRootsResponse`.

  2. **Slice 2 — Decision D6 Controlled Local Model Import & Schema v3 Registry (`PC-MODEL-001`..`006`):**
     - **GGUF Metadata & Hardware Preflight (`model_registry.py`):**
       - Extend `GGUFMetadata` with `model_name: str = ""`, `parameter_count_label: str = ""`, `has_chat_template: bool = False`, and `estimated_vram_gb: float = 0.0` (derived safely from primary file size + overhead factor `~1.2x` when header tensor metadata isn't explicitly itemized, clearly labeled as `inferred`).
       - Add pure helper `assess_hardware_suitability(file_size_bytes: int, architecture: str) -> PreflightAssessmentOut`: evaluates against `settings.HOST_DEDICATED_VRAM_GB` (configurable Host VRAM baseline, default `8.0` GB):
         - `estimated_vram_gb <= host_vram * 0.50` -> `suitability = "recommended"` (50% target per `runtime-and-models.md` §2.8)
         - `estimated_vram_gb <= host_vram * 0.85` -> `suitability = "supported_with_warning"`
         - `estimated_vram_gb > host_vram * 0.85` -> `suitability = "not_recommended"` (explicit warning, still overrideable per advisory-vs-enforced policy unless GGUF header itself is invalid/corrupt!)
       - Fix `model_registry.py` `_validate_entry` / `capability_provenance` / `size_gb` exposure cleanly without breaking existing `GET /api/v1/models/registry` contracts (`test_model_registry.py`).
     - **D6 Import Service (`backend/app/services/model_import.py`):**
       - **Manual Inbox Scan (`scan_import_inbox() -> ModelImportScanOut`):**
         - Ensures `IMPORT_INBOX_DIR` exists only on explicit scan invocation (never on app import).
         - Scans `IMPORT_INBOX_DIR` recursively with strict symlink/containment guard (`_resolve_contained_path(inbox_dir, p)`), rejecting any symlink pointing outside `IMPORT_INBOX_DIR`.
         - Identifies primary candidate `.gguf` files (excluding `mmproj*`, size `>= _MIN_GGUF_BYTES` default `1_048_576` in tests or `100 MiB` unless header is valid GGUF — better: validate GGUF v2/v3 magic `b"GGUF"` + `version in (2, 3)` + `kv_count` bounds directly, flagging corrupt/non-GGUF/truncated `.gguf` files as `artifact_valid=False` preflight failures rather than silently ignoring them!).
         - Pairs matching `mmproj*.gguf` projectors in the same inbox subfolder (or matching filename stem token if placed beside the primary file in inbox root) as companion `mmproj` artifacts, validating each `mmproj` GGUF magic header too.
         - Computes suggested slug `model_id`, `display_name`, detected `architecture`, `quantization`, `model_max_context`, `has_chat_template`, `capabilities` (`["chat"]` + `["vision"]` if `mmproj` paired), `capability_provenance` (`"detected"` / `"inferred"`), and `PreflightAssessmentOut` (distinguishing `artifact_valid`, `provider_compatible`, and `hardware_suitability`).
       - **Controlled Staging & Atomic Install (`install_inbox_candidate(req: ModelImportInstallRequest) -> ModelImportInstallOut`):**
         - Validates `req.candidate_relative_path` strictly inside `IMPORT_INBOX_DIR` via containment helper (rejecting `..`, absolute paths, symlinks escaping inbox).
         - Validates sanitized `model_id` (`^[a-z0-9][a-z0-9._-]{1,63}$`) and rejects duplicate IDs against existing installed models or factory IDs unless `overwrite=True` (and rejects `409 Conflict` if active/loaded).
         - Re-runs GGUF header validation (fail closed `400 Bad Request` on corrupt/non-GGUF) and copies/stages primary `.gguf` + paired `mmproj` inside a fresh staging folder `IMPORT_STAGING_DIR/<model_id>-<uuid>/`, computing SHA-256 digests (`sha256_primary`, companion `sha256`).
         - Moves staged files atomically via `os.replace` into `MODEL_LIBRARY_DIR/<model_id>/` (same `LIBRARY_ROOT` volume -> atomic POSIX/Windows rename semantics).
         - Updates `INSTALLED_REGISTRY_PATH` (`<LIBRARY_ROOT>/registry/models.json`, `_schema_version: "3"`) atomically via temp file + `os.replace` with validated metadata + optional user overrides (`display_name`, `variant`, `family`, `license`) without allowing user overrides to falsify intrinsic header facts (`architecture`, `quantization`, `sha256_primary`, `model_max_context` when header-detected).
         - Removes source files from `IMPORT_INBOX_DIR` upon verified atomic commit (unless `keep_inbox_copy=True`), cleaning staging directory unconditionally in `finally`.
       - **Remove Installed Model (`delete_installed_model(model_id: str) -> ModelDeleteOut`):**
         - Refuses removing factory template models (`400 Bad Request` `CANNOT_DELETE_FACTORY_MODEL`) or currently loaded/active/selected models while loaded (`409 Conflict` `MODEL_IN_USE`), removes the entry from `INSTALLED_REGISTRY_PATH` atomically, deletes files under `MODEL_LIBRARY_DIR/<model_id>/` inside strict path containment, and clears stale `host_config.json` `selected_model` if it matched `model_id`.
     - **Model Endpoints (`backend/app/api/v1/endpoints/llm.py`):**
       - `POST /api/v1/models/import/scan` (`require_host_admin`) -> `ModelImportScanOut`
       - `POST /api/v1/models/import/install` (`require_host_admin`) -> `ModelImportInstallOut`
       - `DELETE /api/v1/models/registry/{model_id}` (`require_host_admin`) -> `ModelDeleteOut`

  3. **Slice 3 — Windows Task Scheduler Dual Autostart at Login (`PC-HOST-002`):**
     - **Backend Autostart Service (`backend/app/services/autostart.py` + `host_config.py`):**
       - Uses injectable command runner (`subprocess.run` with `creationflags=subprocess.CREATE_NO_WINDOW`) targeting standard-user Task Scheduler (`schtasks.exe`) with task name `AICompanionAutostart`:
         - Register command uses standard user privilege (`/RL LIMITED`, `/SC ONLOGON`, `/F`, XML or `/TR` invoking resolved Flutter Desktop `ai_companion_desktop.exe --minimized-to-tray` when present or configured command override, **never** passing `/RL HIGHEST` or requiring UAC!).
         - Because launching AI Companion Flutter Desktop triggers `DesktopRuntimeCoordinator.ensureRuntimeReady()`, which spawns windowless `pythonw.exe` Local AI Runtime under `PC-HOST-001` kernel locking, the dual runtime+tray-UI startup runs cleanly with zero console windows and stops cleanly if the user triggers "Exit Companion" (intentional exit never restarts until next logon).
         - Persist user preference (`autostart_enabled`, `start_minimized_to_tray`, `executable_path`) in `host_config.json` and reconcile live query state (`schtasks.exe /Query /TN AICompanionAutostart /FO LIST`).
       - Host-Admin Endpoints (`backend/app/api/v1/endpoints/health.py`):
         - `GET /api/v1/system/autostart` (`verify_telemetry`) -> `AutostartStatusOut`
         - `PUT /api/v1/system/autostart` (`require_host_admin`) -> `AutostartStatusOut`
     - **Desktop Startup Flag (`frontend/flutter/apps/desktop/lib/main.dart`):**
       - Support `--minimized-to-tray` / `--autostart` in release & debug builds (`bool startMinimizedToTray = args.contains('--minimized-to-tray') || args.contains('--autostart')`), pass `startMinimizedToTray: startMinimizedToTray` cleanly into `coordinator.initialize(...)` so when tray initializes successfully the window stays hidden in the tray, and if tray is unavailable it shows the window safely (`!coordinator.isTrayAvailable`).

  4. **Slice 4 — Contracts, Parity & Desktop Settings UI (`PC-CLIENT-010`, `PC-API-001`):**
     - Regenerate `contracts/openapi/openapi.json` cleanly via FastAPI OpenAPI export.
     - Add typed DTOs in `companion_api` (`model_registry_dto.dart`, `system_status_dto.dart`) matching OpenAPI 1:1 and register all new schemas in `scripts/check_dart_openapi_parity.py`.
     - Add `CompanionClient` methods: `updateModelProfile`, `scanModelImportInbox`, `installImportedModel`, `deleteInstalledModel`, `getStorageRoots`, `updateLibraryRoot`, `getAutostartStatus`, `updateAutostart`, and promote all implemented M2 routes into `M2_ROUTE_DART_METHODS`.
     - Update Flutter Desktop Settings:
       - `SettingsRuntimeSection`: Hardware Profile segmented selector (`Eco` / `Balanced` / `Maximum`), rich registry cards (`sizeGb`, `estimatedVramGb`, `quantization`, `architecture`, `modelMaxContext`, advisory VRAM fit chip, **Delete** button for `registrySource == 'installed'`), and **D6 Model Import Inbox** card (`import_inbox_dir` + copy button, **Scan Inbox**, candidate `.gguf` + `mmproj` bundle cards with editable Display Name + **Install Bundle** button).
       - `SettingsStorageSection`: Replace "Backend storage telemetry is not available in M1 standalone mode" and placeholder relocation banner with live backend telemetry from `GET /api/v1/system/storage` (all 5 roots + free space) merged with local `WindowsStorageDiagnosticReader` fail-closed bootstrap inspection, plus interactive **Relocate Library Root** path field & apply confirmation (`PUT /api/v1/system/storage/library-root`).
       - `SettingsGeneralSection`: Replace `PLANNED (PC-HOST-002)` banner with live **Launch at Windows Login (Minimized to System Tray)** toggle backed by `GET`/`PUT /api/v1/system/autostart`.

- **Contract & Schema Impact:**
  - **Database Migrations:** Zero SQLite schema changes required (bootstrap locator JSON, Schema v3 `models.json` file, and `host_config.json` own host-level storage, model library, and autostart state per `storage-and-assets.md` §2.4 & `runtime-and-models.md` §2.8).
  - **New / Updated OpenAPI Routes (+7 HTTP routes):**
    1. `GET /api/v1/system/storage` (`verify_telemetry`)
    2. `PUT /api/v1/system/storage/library-root` (`require_host_admin`)
    3. `GET /api/v1/system/autostart` (`verify_telemetry`)
    4. `PUT /api/v1/system/autostart` (`require_host_admin`)
    5. `POST /api/v1/models/import/scan` (`require_host_admin`)
    6. `POST /api/v1/models/import/install` (`require_host_admin`)
    7. `DELETE /api/v1/models/registry/{model_id}` (`require_host_admin`)
  - **OpenAPI & Dart Parity:** All new schemas registered in `SCHEMA_TO_DART_CLASS`, all new & existing model/storage/autostart routes mapped in `M2_ROUTE_DART_METHODS`, verified cleanly with `scripts/check_dart_openapi_parity.py --check` and `scripts/tests/test_check_dart_openapi_parity.py`.

---

## 3. Proposed File Changes & In-Place Logic

### [MODIFY] `backend/app/core/storage.py` & `backend/app/core/config.py`
- **Primary Responsibility:** Five canonical storage roots resolution (`APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`), optional `library_root` pointer in `bootstrap.json`, and canonical `LIBRARY_ROOT/imports/{inbox,staging}` placement.
- **Planned Change:** Add `get_default_cache_root()`, `get_default_log_root()`, `resolve_library_root()`, `resolve_cache_root()`, `resolve_log_root()`, `resolve_app_install_root()`, extend `write_bootstrap()` with optional `library_root: Optional[Path] = None` (default `None` preserves exact legacy 2-key JSON), extend `CanonicalPaths` with `APP_INSTALL_ROOT`, `CACHE_ROOT`, `LOG_ROOT`, move `IMPORT_INBOX_DIR` and `IMPORT_STAGING_DIR` under `LIBRARY_DIR / "imports"`, and expose `APP_INSTALL_ROOT`, `CACHE_ROOT`, `LOG_ROOT`, `HOST_DEDICATED_VRAM_GB: float = 8.0` in `Settings`.
- **Invariants to Preserve:** Zero directory creation on `resolve_*` / `get_canonical_paths()` (`test_bootstrap.py`, `test_storage_engine_lifecycle.py`); fail-closed `BootstrapCorruptError` / `StorageError` on malformed or relative paths.

### [MODIFY] `backend/app/schemas/health.py`, `backend/app/schemas/model_registry.py` & `backend/app/services/host_config.py`
- **Primary Responsibility:** Typed Pydantic v2 request/response contracts for storage telemetry/relocation, Windows autostart status/toggle, D6 inbox scan/install/delete, and `host_config.json` autostart preference helpers.
- **Planned Change:** Add `StorageRootOut`, `StorageRootsResponse`, `LibraryRootUpdateRequest`, `AutostartStatusOut`, `AutostartUpdateRequest` to `health.py`; add `PreflightAssessmentOut`, `ModelImportCandidateOut`, `ModelImportScanOut`, `ModelImportInstallRequest`, `ModelImportInstallOut`, `ModelDeleteOut` to `model_registry.py`; add `get_autostart_preferences()` / `save_autostart_preferences()` to `host_config.py`.
- **Invariants to Preserve:** Strict `extra="forbid"` on mutation inputs where appropriate; zero changes breaking existing `ModelRegistryEntry` serializers used by `/models/registry`.

### [ADD] `backend/app/services/model_import.py` & [MODIFY] `backend/app/services/model_registry.py`, `backend/app/services/llm/manager.py`
- **Primary Responsibility:** D6 manual inbox scan, multi-file GGUF + `mmproj` bundle inspection, preflight hardware check, isolated staging with SHA-256 verification, atomic installation into `MODEL_LIBRARY_DIR`, Schema v3 `models.json` updates, and safe installed-model deletion.
- **Planned Change:** Enrich `GGUFMetadata` (`model_name`, `has_chat_template`, `estimated_vram_gb`, `assess_hardware_suitability()`) in `model_registry.py`; implement `scan_import_inbox()`, `install_inbox_candidate()`, `delete_installed_model()`, and strict symlink-safe `_resolve_contained_path()` in `model_import.py`; include `settings.MODEL_LIBRARY_DIR` in `LLMManager.get_provider()` auto-detection.
- **Invariants to Preserve:** Zero automatic filesystem watcher; zero arbitrary host path execution (inbox/library strictly contained); intrinsic GGUF facts cannot be falsified by user overrides; factory template models (`models/registry.template.json`) are never mutated or deleted.

### [ADD] `backend/app/services/autostart.py`
- **Primary Responsibility:** Standard-user Windows Task Scheduler registration and query for dual autostart at logon (`PC-HOST-002`).
- **Planned Change:** Implement `WindowsAutostartService` using `schtasks.exe` (`CREATE_NO_WINDOW`, `/SC ONLOGON /RL LIMITED /TN "AICompanionAutostart"`), resolving `ai_companion_desktop.exe` cleanly with `--minimized-to-tray`, supporting injectable runner for deterministic unit tests across Windows/Linux CI, and never importing or running subprocesses at module import time.
- **Invariants to Preserve:** Zero UAC elevation; zero intentional-exit restart loop (no `/RI` infinite watchdog loop); zero import-time side effects.

### [MODIFY] `backend/app/api/v1/endpoints/health.py` & `backend/app/api/v1/endpoints/llm.py`
- **Primary Responsibility:** Mount Host-Admin and telemetry API routes for storage, autostart, D6 import scan/install, and installed-model deletion.
- **Planned Change:** Add `GET /system/storage`, `PUT /system/storage/library-root`, `GET /system/autostart`, `PUT /system/autostart` in `health.py`; add `POST /models/import/scan`, `POST /models/import/install`, `DELETE /models/registry/{model_id}` in `llm.py` (with `409 Conflict` guard when active model is loaded/busy).
- **Invariants to Preserve:** All mutating host endpoints require `Depends(require_host_admin)` (`127.0.0.1` loopback + Host Admin secret); telemetry reads require `Depends(verify_telemetry)`.

### [MODIFY] `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py` & `frontend/flutter/packages/companion_api/lib/`
- **Primary Responsibility:** Authoritative OpenAPI 3.1 contract regeneration and `companion_api` Dart DTO + client parity.
- **Planned Change:** Regenerate `contracts/openapi/openapi.json`; add Dart DTOs in `system_status_dto.dart` and `model_registry_dto.dart` + methods in `companion_client.dart`; register all schemas and routes in `check_dart_openapi_parity.py` and update route count expectation in `test_check_dart_openapi_parity.py`.
- **Invariants to Preserve:** Zero breaking changes to existing `ModelRegistryEntry` getters/constructors consumed by existing Desktop UI tests.

### [MODIFY] `frontend/flutter/apps/desktop/lib/` (`main.dart`, `screens/settings_screen.dart`, `features/settings/sections/settings_runtime_section.dart`, `settings_storage_section.dart`, `settings_general_section.dart`)
- **Primary Responsibility:** Desktop startup minimized-to-tray handling (`--minimized-to-tray` / `--autostart`) and interactive Settings UI for `PC-CLIENT-010`, `PC-HOST-004`, and `PC-HOST-002`.
- **Planned Change:**
  - `main.dart`: parse `--minimized-to-tray` / `--autostart` cleanly and honor hidden tray startup when tray initializes.
  - `settings_screen.dart`: pass `client` (resolved via `widget.client ?? widget.chatController?.client`) into `SettingsStorageSection` and `SettingsGeneralSection`.
  - `settings_runtime_section.dart`: add Hardware Profile selector (`eco` / `balanced` / `maximum`), surface `quantization`/`sizeGb`/`estimatedVramGb`/`vramStatus`/`Delete` on model cards, and add interactive **D6 Model Import Inbox** card (`Scan Inbox` + candidate `.gguf` + `mmproj` cards + editable display name + `Install Bundle`).
  - `settings_storage_section.dart`: display backend telemetry across all 5 storage roots + interactive `LIBRARY_ROOT` relocation control (`PUT /api/v1/system/storage/library-root`), merging gracefully with `WindowsStorageDiagnosticReader` offline fallback.
  - `settings_general_section.dart`: replace static `PLANNED (PC-HOST-002)` card with live **Launch at Windows Login (Minimized to Tray)** toggle and status diagnostics.
- **Invariants to Preserve:** Safe isolated test behavior under `FLUTTER_TEST` when optional `client` is injected or null (no disk writes to user `%LOCALAPPDATA%`); graceful offline degradation when runtime is disconnected.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Slice 1 (`PC-HOST-004` Five Storage Roots & Relocatable `LIBRARY_ROOT`):**
   - **RED:** Expand `backend/tests/test_bootstrap.py` & `backend/tests/test_storage_engine_lifecycle.py` for 5-root resolution, `library_root` relocation in `bootstrap.json`, `IMPORT_*` under `LIBRARY_ROOT`, fail-closed invalid `library_root`, and `GET /system/storage` + `PUT /system/storage/library-root` (including `409 Conflict` when a model is loaded).
   - **GREEN:** Update `backend/app/core/storage.py`, `config.py`, `schemas/health.py`, and `endpoints/health.py`.
   - **REFACTOR:** Keep resolver helpers concise and pure with single-source path derivations.

2. **Slice 2 (`PC-MODEL-001`..`006` D6 Import Pipeline & Schema v3 Registry):**
   - **RED:** Create `backend/tests/test_d6_model_import_and_autostart.py` testing GGUF v2/v3 header extraction, symlink-escape rejection in `IMPORT_INBOX_DIR`, `mmproj` pairing, preflight hardware fit thresholds, SHA-256 verification, atomic `os.replace` staging -> library install, Schema v3 `models.json` persistence, duplicate/corrupt GGUF rejection, and `DELETE /models/registry/{id}` active-model/factory guards.
   - **GREEN:** Enhance `model_registry.py` + `llm/manager.py`, create `model_import.py`, and wire `/models/import/scan`, `/models/import/install`, and `DELETE /models/registry/{model_id}` in `endpoints/llm.py`.
   - **REFACTOR:** Deduplicate path containment checks cleanly across import/delete helpers.

3. **Slice 3 (`PC-HOST-002` Windows Task Scheduler Autostart at Login):**
   - **RED:** Add tests in `backend/tests/test_d6_model_import_and_autostart.py` for `WindowsAutostartService` (`schtasks.exe` `/SC ONLOGON /RL LIMITED /TN AICompanionAutostart`, `--minimized-to-tray` args, zero UAC, query parsing, error surfacing, `GET`/`PUT /system/autostart`, and `test_import_isolation.py` zero import-time subprocesses).
   - **GREEN:** Create `backend/app/services/autostart.py`, extend `host_config.py`, add `/system/autostart` routes in `endpoints/health.py`, and update `main.dart` `--minimized-to-tray` initialization.
   - **REFACTOR:** Keep runner injection crisp for unit tests vs Windows runtime execution.

4. **Slice 4 (`PC-CLIENT-010`, OpenAPI & Dart Parity, Desktop UI):**
   - Regenerate `contracts/openapi/openapi.json`, implement `companion_api` DTOs & `CompanionClient` methods, update `scripts/check_dart_openapi_parity.py` & `scripts/tests/test_check_dart_openapi_parity.py`, and add `m2_models_storage_autostart_dto_test.dart`.
   - **RED:** Add failing widget/unit tests in `frontend/flutter/apps/desktop/test/desktop_m2_models_storage_autostart_test.dart` for Hardware Profile switching, D6 Scan & Install inbox UI, Installed Model removal, live 5-root Storage relocation UI, General Autostart switch, and `--minimized-to-tray` lifecycle coordinator init (`showImmediately: false` when tray available, fallback `true` when unavailable).
   - **GREEN:** Implement UI updates across `settings_screen.dart`, `settings_runtime_section.dart`, `settings_storage_section.dart`, and `settings_general_section.dart`.
   - **REFACTOR:** Extract clean subwidgets/helpers if section methods grow long while preserving theme tokens (`SoftGlassPanel`, `NeumorphicSurface`).

5. **Phase 3 Documentation, Packaging & Draft PR:**
   - Reconcile canonical specs (`storage-and-assets.md`, `runtime-and-models.md`, `windows-host-and-notifications.md`), `WBS.md`, `MASTER_CHECKLIST.md`, `DELIVERY_INDEX.md`, `SPRINT_ROADMAP.md`, `task.md`, `CHANGELOG.md`, `walkthrough-m2-models-storage-autostart-e.md`, and archive branch tracker on `feature/m2-models-storage-autostart-e`, then push and open a Draft PR against `develop`.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Backend test suite: `backend\.venv\Scripts\python.exe -m pytest backend\tests -q -p no:cacheprovider -o log_file=NUL`
- [ ] Import isolation & dependency lock check: `backend\.venv\Scripts\python.exe -m pytest backend\tests\test_import_isolation.py scripts\tests\test_python_dependency_lock.py -q -p no:cacheprovider -o log_file=NUL`
- [ ] OpenAPI & Dart contract parity: `backend\.venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check` and `backend\.venv\Scripts\python.exe -m unittest scripts\tests\test_check_dart_openapi_parity.py -v`
- [ ] Dart static analysis & SDK tests: `cd frontend\flutter && dart analyze .` and `cd frontend\flutter\packages\companion_api && dart test`
- [ ] Flutter Desktop test suite & Windows MSVC build: `cd frontend\flutter\apps\desktop && flutter test --no-pub --concurrency=1 test` and `flutter build windows --debug --no-pub`
- [ ] Diff hygiene: `git diff --check develop`

### Manual & Host-Level Checks (Windows Desktop)
- [ ] Inspect `Settings -> Storage & Diagnostics`: verify all 5 roots report live backend telemetry + free disk space, and relocate `LIBRARY_ROOT` to a secondary directory verifying `bootstrap.json` updates and `MODEL_INBOX_DIR` moves cleanly.
- [ ] Inspect `Settings -> AI Runtime & Models`: drop a test `.gguf` (+ optional `mmproj-*.gguf`) into `IMPORT_INBOX_DIR`, click **Scan Inbox**, review metadata & VRAM suitability badge, click **Install Bundle**, select/load or switch profile (`Eco` / `Balanced` / `Maximum`), and remove a user-installed entry.
- [ ] Inspect `Settings -> General & Lifecycle`: toggle **Launch at Windows Login (Minimized to Tray)** on/off, verify `schtasks /Query /TN AICompanionAutostart` shows standard-user `ONLOGON` registration without UAC prompts, and test launching `ai_companion_desktop.exe --minimized-to-tray` starts minimized to system tray cleanly (or restore from tray without error).

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Cross-Volume Atomic Install (`EXDEV`):** Placing `IMPORT_STAGING_DIR` directly under `<LIBRARY_ROOT>/imports/staging` (instead of `DATA_ROOT/imports/staging`) guarantees staging and `MODEL_LIBRARY_DIR` live on the same volume so `os.replace` is atomic even when `LIBRARY_ROOT` is relocated to `D:\` or `E:\`. Relocation of `LIBRARY_ROOT` across volumes uses verified copy + size/SHA-256 check rather than raw cross-volume rename.
- **Path Traversal & Symlink Containment:** Both D6 inbox scanning/install and `LIBRARY_ROOT` model deletion resolve `.resolve(strict=...)` against resolved base directories (`is_relative_to`) and explicitly reject symlinks escaping `IMPORT_INBOX_DIR` or `MODEL_LIBRARY_DIR`.
- **Active Model Mutation Guard:** `PUT /api/v1/system/storage/library-root` and `DELETE /api/v1/models/registry/{model_id}` check active LLM provider status/locks and fail closed with `409 Conflict` if a model is currently loaded, loading, or generating.
- **No Unapproved Scope Creep (`test_import_isolation.py`):** Autostart Task Scheduler commands, filesystem directory creation, and GGUF inspection execute lazily upon request, preserving zero side effects on module import.
- **Required Permissions:** Task-bounded branch creation, commits, push on `feature/m2-models-storage-autostart-e`, and Phase 3 Draft PR against `develop` (Human Owner performs final squash merge).
- **Genuine Stop Conditions:** Material scope expansion into Profile PIN / Device Enrollment / M5 features, unapproved SQLite schema migration, security boundary conflict, or unresolvable test/build failure requires halting and escalating to the Human Owner.
