# Implementation Plan: M2 Batch E — Five Storage Roots, Relocatable Library, D6 Controlled Model Import, Desktop Model Management UI & Windows Login Autostart

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Awaiting Approval (Phase 1 Plan Gate — Revised for Independent Review Findings)
- **Delivery Level:** Level C — Sensitive Design
- **Scope Mode:** New Feature — M2 Batch E Host Storage Roots & Relocatable Library (`PC-HOST-004`), Decision D6 Controlled Local Model Import, GGUF Header Fix & Schema v3 Registry Writer (`PC-MODEL-001`..`006`), `LlamaCppProvider` Multi-Root Support, Desktop Model Management & Hardware Profile UI (`PC-CLIENT-010`), and Windows Task Scheduler Login Autostart (`PC-HOST-002`). *(Profile PIN lock and Satellite Device Enrollment `PC-IDENTITY-003` remain explicitly deferred per Human Owner direction.)*
- **Target Files:**
  - `backend/app/core/` (`storage.py`, `config.py`)
  - `backend/app/main.py` (`RuntimeAdmissionASGIMiddleware.NON_DB_PATHS`)
  - `backend/app/schemas/` (`health.py`, `model_registry.py`)
  - `backend/app/services/` (`model_registry.py`, `model_import.py` [ADD], `autostart.py` [ADD], `host_config.py`, `llm/manager.py`, `llm/llama_cpp.py`)
  - `backend/app/api/v1/endpoints/` (`health.py`, `llm.py`)
  - `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, & `scripts/tests/test_check_dart_openapi_parity.py`
  - `frontend/flutter/packages/companion_core/lib/storage/storage_diagnostic.dart`
  - `frontend/flutter/packages/companion_api/lib/` (`dto/model_registry_dto.dart`, `dto/system_status_dto.dart`, `client/companion_client.dart`)
  - `frontend/flutter/apps/desktop/windows/runner/` (`main.cpp`, `flutter_window.h`, `flutter_window.cpp`)
  - `frontend/flutter/apps/desktop/lib/` (`main.dart`, `lifecycle/desktop_lifecycle_coordinator.dart`, `coordinator/desktop_runtime_coordinator.dart`, `screens/settings_screen.dart`, `features/settings/sections/settings_runtime_section.dart`, `features/settings/sections/settings_storage_section.dart`, `features/settings/sections/settings_general_section.dart`)
  - `backend/tests/` (`test_bootstrap.py`, `test_storage_engine_lifecycle.py`, `test_model_registry.py`, `test_d6_model_import_and_autostart.py` [ADD])
  - `frontend/flutter/packages/companion_api/test/` (`m2_models_storage_autostart_dto_test.dart` [ADD])
  - `frontend/flutter/apps/desktop/test/` (`desktop_m2_models_storage_autostart_test.dart` [ADD], updates to `desktop_settings_revamp_test.dart` / `desktop_lifecycle_test.dart` as needed)
  - Phase 3 docs: canonical specs (`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`, `runtime-and-models.md`, `windows-host-and-notifications.md`), `docs/02_Planning/00_Master/` (`DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `SPRINT_ROADMAP.md`), `CHANGELOG.md`, walkthrough (`docs/03_Walkthroughs/walkthrough-m2-models-storage-autostart-e.md`), and archived branch tracker.
- **Branch:** `feature/m2-models-storage-autostart-e`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m2-models-storage-autostart-e.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m2-models-storage-autostart-e.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:** Complete the remaining Milestone M2 host, storage, and local model management foundation for PC V1 (with Profile PIN lock and Satellite Device Enrollment `PC-IDENTITY-003` explicitly deferred):
  1. **Five Storage Roots & Relocatable `LIBRARY_ROOT` (`PC-HOST-004`):** Extend `backend/app/core/storage.py` and `config.py` so `CanonicalPaths` resolves all 5 canonical roots (`APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`), supports an optional `library_root` pointer inside `%LOCALAPPDATA%\AI Companion\bootstrap.json` plus `COMPANION_LIBRARY_ROOT` override (without leaking env-overridden test `COMPANION_DATA_ROOT` into global `bootstrap.json`), aligns `IMPORT_INBOX_DIR` (`<LIBRARY_ROOT>/imports/inbox`) and `IMPORT_STAGING_DIR` (`<LIBRARY_ROOT>/imports/staging`) directly under `LIBRARY_ROOT` (resolving `storage-and-assets.md` §3.4 technical debt and keeping staging on the same volume for atomic `os.replace`), and exposes Host-Admin inspection and library relocation endpoints (`GET /api/v1/system/storage`, `PUT /api/v1/system/storage/library-root`).
  2. **Decision D6 Controlled Local Model Import, Real GGUF Parser Fix & Schema v3 Registry (`PC-MODEL-001`..`006`):** Fix `read_gguf_metadata()` so real-world GGUF models (e.g., `Qwen3-VL-2B-Instruct`, `Gemma-3-4B`) with oversized `tokenizer.ggml.*` arrays (`151k–262k` tokens) and `tokenizer.chat_template` strings (`1.5–5.3 KB`) are safely skipped/flagged instead of aborting before `general.file_type`, and implement the executable D6 pipeline (`inbox -> manual scan -> GGUF metadata & capability inspection -> preflight hardware/VRAM suitability -> user confirmation -> staging -> SHA-256 & header verification -> atomic os.replace install -> Library -> Schema v3 models.json Registry`) plus `DELETE /api/v1/models/registry/{model_id}` and multi-root `LlamaCppProvider` / `LLMManager` execution support for user-installed models.
  3. **Desktop Model Management & Storage UI (`PC-CLIENT-010`):** Upgrade `Settings -> AI Runtime & Models` with an interactive Hardware Performance Profile selector (`eco` / `balanced` / `maximum` wired to `PATCH /api/v1/models/profile`), rich GGUF metadata + advisory VRAM suitability badges + uninstall action on user-imported model cards, and an interactive **D6 Model Import Inbox** card (inbox folder path copy, **Scan Inbox**, `.gguf` + `mmproj` candidate bundle preview with editable display name, and **Install Bundle** confirmation). Upgrade `Settings -> Storage & Diagnostics` with live Host-Admin backend telemetry across all 5 storage roots and interactive `LIBRARY_ROOT` relocation controls (preserving standalone fail-closed offline diagnostics when disconnected).
  4. **Windows Task Scheduler Login Autostart (`PC-HOST-002`):** Implement standard-user Windows Task Scheduler registration via XML (`At log on` of current user, `<RunLevel>LeastPrivilege</RunLevel>`, zero UAC elevation, explicit `<WorkingDirectory>`, unlimited execution time, battery allowed, intentional-exit suppression), expose `GET /api/v1/system/autostart` and `PUT /api/v1/system/autostart` under `require_host_admin`, prevent first-frame Win32 window flash when `--minimized-to-tray` / `--autostart` is passed (`main.cpp` + `flutter_window.h/.cpp` + `main.dart` + `desktop_lifecycle_coordinator.dart`), expand `DesktopRuntimeCoordinator` parent-directory walk for deep runner build paths, and replace the static `PLANNED (PC-HOST-002)` banner in `Settings -> General & Lifecycle` with a live autostart switch.
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
  2. Real-GGUF-compatible `read_gguf_metadata()` in `model_registry.py`, `backend/app/services/model_import.py`, and multi-root `LlamaCppProvider` + `LLMManager` execution support for D6-installed models.
  3. `backend/app/services/autostart.py` + `host_config.py` persistence managing standard-user Windows Task Scheduler XML registration (`AICompanionAutostart`, `ONLOGON`), paired with flash-free `--minimized-to-tray` startup across Win32 C++ (`main.cpp`/`flutter_window.*`), `main.dart`, `DesktopLifecycleCoordinator`, and `DesktopRuntimeCoordinator`.
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
  | `backend/app/core/storage.py` resolves only `COMPANION_DATA_ROOT`, places `IMPORT_*` under `DATA_ROOT/imports/` (`storage-and-assets.md` §3.4 debt), and omits `APP_INSTALL_ROOT`/`CACHE_ROOT`/`LOG_ROOT`. `test_bootstrap.py:96-108` asserts exact keys `{"schema_version", "data_root"}` on `write_bootstrap(data_root=..., schema_version=1)`, while `test_storage_engine_lifecycle.py:28-29` asserts default `IMPORT_*` paths. | Keep `write_bootstrap()` backward-compatible by omitting `library_root` unless explicitly provided, validate any optional `library_root` as an absolute path fail-closed, guard `resolve_library_root()` so an env-overridden `COMPANION_DATA_ROOT` never mixes with an unrelated global `%LOCALAPPDATA%\AI Companion\bootstrap.json` `library_root` unless `bootstrap_path` is explicitly supplied, move `IMPORT_*` under `LIBRARY_DIR / "imports"`, add all 5 roots to `CanonicalPaths`, and update `test_storage_engine_lifecycle.py` in sync. |
  | `backend/app/api/v1/router.py:37` mounts `system_router` with `dependencies=[Depends(require_host_admin)]`. In `CompanionClient` (`companion_client.dart:69-88`), `admin` (`X-Host-Admin-Secret`) and `telemetry` (`Authorization: Bearer`) are mutually exclusive; putting `Depends(verify_telemetry)` on routes inside `system_router` would enforce *both* simultaneously and make requests fail. | All `/api/v1/system/*` endpoints added to `system_router` (`GET /system/storage`, `PUT /system/storage/library-root`, `GET /system/autostart`, `PUT /system/autostart`) must use `require_host_admin` consistently (matching `GET /system/status`), invoked via `CompanionClient._adminRequest()`, with read paths added to `RuntimeAdmissionASGIMiddleware.NON_DB_PATHS` in `backend/app/main.py:143-151`. |
  | `backend/app/services/model_registry.py:41-42` sets `MAX_STRING_LENGTH = 1024` and `MAX_ARRAY_LENGTH = 64`. Running `read_gguf_metadata()` on repo GGUFs (`Qwen_Qwen3-VL-2B-Instruct-Q4_K_M.gguf`, `gemma-3-4b-it-Q4_K_M.gguf`, `mmproj-Qwen_Qwen3-VL-2B-Instruct-f16.gguf`) returns **empty** metadata because real GGUFs contain huge `tokenizer.ggml.*` arrays (`151k–262k`) and `tokenizer.chat_template` strings (`1.5–5.3 KB`) before `general.file_type`! Meanwhile `test_model_registry.py:541-569` requires rejecting key strings > 1024 and generic arrays like `"tokenizer.tokens"` > 64. | Safely skip/seek known bulk tokenizer arrays (`key.startswith("tokenizer.ggml.")`) bounded by file size and `MAX_TOKENIZER_ARRAY_LENGTH`, and read/skip `tokenizer.chat_template` up to `MAX_CHAT_TEMPLATE_LENGTH = 65_536` (recording `has_chat_template = True`), while strictly preserving `MAX_STRING_LENGTH = 1024` on all keys/other strings and `MAX_ARRAY_LENGTH = 64` on generic arrays so all bounds tests stay green. |
  | `backend/app/services/llm/llama_cpp.py:482-499, 637-652, 700-722, 1097-1109` passes one `--models-dir` (`settings.LLAMA_MODELS_DIR`), checks `LLAMA_MODELS_DIR.exists()`, reuses an active Core-managed router without checking its models directory, and scans only `MODELS_DIR` in `_resolve_model_path()` / `get_status()`. Furthermore `backend/app/services/llm/manager.py:27-55` scans only `MODELS_DIR` and permanently caches `MockLLMProvider` if no GGUF >100MB existed at boot. | Track active router root/preset in `LlamaCppProvider` so `installed` models resolve cleanly under `MODEL_LIBRARY_DIR` (respawning Core-managed router when switching between `factory` and `installed` roots, and supporting `--models-dir` per target root or `--models-preset` INI cleanly; stopping any idle Core-managed router before `LIBRARY_ROOT` relocation), expose both `MODELS_DIR` and `MODEL_LIBRARY_DIR` in `_resolve_model_path()` / `get_status()`, and add `LLMManager.refresh_auto_provider_if_idle()` triggered on D6 install when `LLM_PROVIDER == "auto"`. |
  | `frontend/flutter/apps/desktop/windows/runner/flutter_window.cpp:34-36` unconditionally calls `this->Show()` in `SetNextFrameCallback`, `main.dart:99-106` runs `runApp()` before awaiting `coordinatorInit`, `desktop_lifecycle_coordinator.dart:97-102` never hides when `showImmediately == false`, and `desktop_runtime_coordinator.dart:227, 268` walks only 5 ancestor levels from `Platform.resolvedExecutable` (`ai_companion_desktop.exe` sits 9 levels deep under `build/windows/x64/runner/{Debug,Release}/`), causing Task Scheduler launches (`C:\Windows\System32` CWD) to fail. | Check `--minimized-to-tray` / `--autostart` in `main.cpp` + `FlutterWindow` to suppress first-frame `this->Show()`, await `coordinator.initialize(showImmediately: false, ...)` in `main.dart` before `runApp` (hiding window cleanly when tray succeeds, falling back to `restoreAndFocusWindow()` if tray init fails), expand `DesktopRuntimeCoordinator` walk to 10 ancestor levels (+ `COMPANION_APP_INSTALL_ROOT`), and register Task Scheduler via XML with explicit `<WorkingDirectory>`, `<RunLevel>LeastPrivilege</RunLevel>`, `<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>`, and battery start allowed. |
  | `scripts/check_dart_openapi_parity.py:345-420` requires every class mapped in `SCHEMA_TO_DART_CLASS` to match every OpenAPI property via `snake_to_camel()` with zero extra unmapped `final` fields (`companion_core`'s `evaluateBootstrapLocatorContent` currently inspects only `data_root`, and `windows_storage_diagnostic_reader_test.dart:142-144` checks offline `"Not reported by backend"`). | Design all **new** API DTOs (`StorageRootOut`, `StorageRootsResponse`, `LibraryRootUpdateRequest`, `AutostartStatusOut`, `AutostartUpdateRequest`, `PreflightAssessmentOut`, `ModelImportCandidateOut`, `ModelImportScanOut`, `ModelImportInstallRequest`, `ModelImportInstallOut`, `ModelDeleteOut`) with 1:1 `snake_case` <-> `camelCase` field parity; preserve offline `SettingsStorageSection` & `WindowsStorageDiagnosticReader` test contracts when `client == null` while validating optional `library_root` fail-closed in `evaluateBootstrapLocatorContent`! |

- **Architectural Approach:**
  1. **Slice 1 — Five Storage Roots & Relocatable `LIBRARY_ROOT` (`PC-HOST-004`):**
     - **Pure Resolvers (`backend/app/core/storage.py`, `config.py`):**
       - `resolve_library_root(data_root, env_override=None, bootstrap_path=None, data_root_env_override=None) -> Path`: precedence `COMPANION_LIBRARY_ROOT` -> `bootstrap.json['library_root']` (only when `bootstrap_path` is explicitly given OR `COMPANION_DATA_ROOT` env override is NOT redirecting away from configured bootstrap, failing closed with `BootstrapCorruptError` / `StorageError` if `library_root` is malformed/empty/relative) -> `(data_root / "library").resolve()`.
       - `resolve_cache_root(env_override=None) -> Path`, `resolve_log_root(env_override=None) -> Path`, `resolve_app_install_root(env_override=None) -> Path`.
       - Update `write_bootstrap(data_root, bootstrap_path=None, schema_version=1, library_root=None)`: omits `"library_root"` when `None` (`test_bootstrap.py:107`), atomically persists `"library_root"` when supplied, rejects relative paths with `StorageError`.
       - Update `CanonicalPaths` / `get_canonical_paths(...)`: add `APP_INSTALL_ROOT`, `CACHE_ROOT`, `LOG_ROOT`; place `IMPORT_INBOX_DIR = library_dir / "imports" / "inbox"` and `IMPORT_STAGING_DIR = library_dir / "imports" / "staging"`.
     - **Host-Admin Storage Telemetry & Relocation (`health.py`, `main.py`):**
       - `GET /api/v1/system/storage` (`require_host_admin`, also in `NON_DB_PATHS`) -> `StorageRootsResponse`.
       - `PUT /api/v1/system/storage/library-root` (`require_host_admin`):
         - Reject with `409 Conflict` if `COMPANION_LIBRARY_ROOT` env override is set (cannot permanently persist override while env locks it) or if an LLM model is currently loaded, loading, or generating; cleanly stop any idle (`MODEL_UNLOADED`) Core-managed `llama-server.exe` process before moving files.
         - Validate `new_library_root` is absolute, resolved symlink-safe, and NOT equal to or nested (parent or child) inside current `LIBRARY_ROOT`, `DATA_ROOT/database`, or `APP_INSTALL_ROOT` (preventing recursive `copytree` loops and DB corruption).
         - Preserve existing `bootstrap.json['data_root']` if present (falling back to current non-env canonical `data_root`), reject persisting temporary `COMPANION_DATA_ROOT` env paths into global `%LOCALAPPDATA%\AI Companion\bootstrap.json` unless explicit test bootstrap is active, copy/verify assets into `<new_library_root>` if `migrate_existing_assets=True`, atomically update `bootstrap.json`, and return updated `StorageRootsResponse`.

  2. **Slice 2 — Decision D6 Import, Real GGUF Parser Fix & Multi-Root Runtime (`PC-MODEL-001`..`006`):**
     - **GGUF Parser Fix & Metadata (`model_registry.py`):**
       - Preserve `MAX_STRING_LENGTH = 1024` for key strings and general string metadata and `MAX_ARRAY_LENGTH = 64` for generic arrays.
       - For known tokenizer bulk array keys (`tokenizer.ggml.tokens`, `tokenizer.ggml.token_type`, `tokenizer.ggml.merges`, `tokenizer.ggml.scores`), implement `_skip_gguf_value()` using exact typed byte strides + file-size bounded `f.seek()` (`MAX_SKIP_ARRAY_LENGTH = 1_000_000`) so real `Qwen3-VL` / `Gemma-3` headers parse cleanly through trailing keys (`general.file_type`, `general.quantization_version`) without allocating megabytes of arrays.
       - For `tokenizer.chat_template` (`key == "tokenizer.chat_template"`), allow reading/bounding up to `MAX_CHAT_TEMPLATE_LENGTH = 65_536` (setting `has_chat_template = True` and safely seeking past longer templates if bounded by file size), extracting `general.type`, `general.name`, `general.size_label`, `general.license`, `clip.has_vision_encoder`.
       - Add pure `assess_hardware_suitability(file_size_bytes: int, architecture: str) -> PreflightAssessmentOut`: evaluates estimated VRAM (`round(size_gb * 1.2 + 0.5, 2)`) against `settings.HOST_DEDICATED_VRAM_GB` (`8.0` default): `<= 50%` -> `"recommended"`, `<= 85%` -> `"supported_with_warning"`, `> 85%` -> `"not_recommended"` (advisory only per `runtime-and-models.md` §2.8; corrupt/truncated/wrong-magic GGUF fails `artifact_valid=False`).
       - Preserve persisted `capability_provenance` on Schema v3 `"installed"` entries in `_parse_registry_entry_dict` / `_validate_entry` without modifying `_scan_directory_for_ggufs` or breaking `test_truthful_unregistered_scanner`.
     - **D6 Import Service (`backend/app/services/model_import.py`) & Routes (`endpoints/llm.py`):**
       - `scan_import_inbox()` (`POST /api/v1/models/import/scan`): creates `IMPORT_INBOX_DIR` lazily on demand, scans strictly contained non-symlink-escaping `.gguf` files regardless of size (flagging `artifact_valid=False` on truncated/corrupt files), identifies companion projectors (`general.type == "mmproj"`, `general.architecture == "clip"`, or `mmproj` prefix), pairs projectors with matching primary GGUFs in the same subfolder/stem, and returns `ModelImportScanOut` with preflight suitability, detected metadata, and `capability_provenance`.
       - `install_inbox_candidate()` (`POST /api/v1/models/import/install`): validates contained relative path, sanitizes `model_id` (`^[a-z0-9][a-z0-9._-]{1,63}$`), guards factory/duplicate collisions, validates GGUF v2/v3 header (`400 Bad Request` on invalid GGUF), stages in `IMPORT_STAGING_DIR/<model_id>-<uuid>/`, computes SHA-256 digests, atomically `os.replace` installs into `MODEL_LIBRARY_DIR/<model_id>/`, atomically updates `INSTALLED_REGISTRY_PATH` (`models.json` Schema v3) honoring user overrides (`display_name`, `variant`, `family`, `license`) without falsifying intrinsic header facts (`architecture`, `quantization`, `sha256_primary`), calls `llm_manager.refresh_auto_provider_if_idle()`, and returns `ModelImportInstallOut` (`entry: ModelRegistryEntry` + `installed_id` + `sha256_primary`).
       - `delete_installed_model(model_id)` (`DELETE /api/v1/models/registry/{model_id}`): blocks factory entries (`400`) and currently loaded/active/selected-while-loaded models (`409`), removes directory inside `MODEL_LIBRARY_DIR` safely, updates `INSTALLED_REGISTRY_PATH` atomically, clears stale `host_config.json` `selected_model` if matching, and returns `ModelDeleteOut`.
     - **Multi-Root `LlamaCppProvider` & `LLMManager` (`llama_cpp.py`, `manager.py`):**
       - `LlamaCppProvider` resolves `target_models_dir` per `registry_entry.registry_source` (`settings.MODEL_LIBRARY_DIR` for `"installed"` vs `settings.LLAMA_MODELS_DIR` for `"factory"`), tracks `self._active_models_dir`, restarts Core-managed `llama-server.exe` cleanly if switching roots between `"factory"` and `"installed"`, updates `_resolve_model_path()` and `get_status()` `available_models` across both roots, and checks `target_models_dir.exists()`. `LLMManager` checks both `MODELS_DIR` and `MODEL_LIBRARY_DIR` and refreshes idle `MockLLMProvider` after D6 install.

  3. **Slice 3 — Windows Task Scheduler Dual Autostart at Login (`PC-HOST-002`):**
     - **Backend Autostart Service (`backend/app/services/autostart.py`, `host_config.py`, `health.py`):**
       - `WindowsAutostartService` generates a valid Task Scheduler XML defining `<LogonTrigger>`, `<Principal><RunLevel>LeastPrivilege</RunLevel></Principal>` (zero UAC), `<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>`, `<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>`, `<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>`, and `<Exec><Command>...</Command><Arguments>--minimized-to-tray</Arguments><WorkingDirectory>...</WorkingDirectory></Exec>`, invoking `schtasks.exe /Create /TN "AICompanionAutostart" /XML <temp_xml> /F` (gating `creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)` on `sys.platform == "win32"`).
       - Note: No watchdog `/RI` restart interval -> honors intentional full exit via `Exit Companion` (`windows-host-and-notifications.md` §2.2).
       - `GET /api/v1/system/autostart` and `PUT /api/v1/system/autostart` (`require_host_admin`, `NON_DB_PATHS`).
     - **Flash-Free `--minimized-to-tray` & Ancestor Path Fix (`main.cpp`, `flutter_window.*`, `main.dart`, `desktop_lifecycle_coordinator.dart`, `desktop_runtime_coordinator.dart`):**
       - `main.cpp` checks `command_line_arguments` for `"--minimized-to-tray"` or `"--autostart"` and passes `start_hidden` to `FlutterWindow`; `FlutterWindow::OnCreate()` skips `this->Show()` inside `SetNextFrameCallback` when `start_hidden` is true.
       - `main.dart` awaits `coordinator.initialize(showImmediately: !startMinimizedToTray, ...)` before `runApp(...)`; inside `DesktopLifecycleCoordinator.initialize()`, when `showImmediately == false`, if `_isTrayAvailable` is true it hides the window cleanly (`await windowAdapter.hide()`); if tray initialization fails (`!_isTrayAvailable`), it falls back to `await restoreAndFocusWindow()` so the user never loses UI access.
       - `DesktopRuntimeCoordinator` (`_resolvePythonExecutable`, `_resolveWorkingDirectory`) expands parent walk to `10` levels + `COMPANION_APP_INSTALL_ROOT` fallback so 9-level-deep `ai_companion_desktop.exe` works cleanly even when launched from `C:\Windows\System32` CWD.

  4. **Slice 4 — Contracts, Parity & Desktop Settings UI (`PC-CLIENT-010`, `PC-API-001`):**
     - Regenerate `contracts/openapi/openapi.json` (`check_openapi_contract.py --write`).
     - Add 1:1 OpenAPI-matching Dart DTOs (`system_status_dto.dart`, `model_registry_dto.dart`) + `CompanionClient` methods (`updateModelProfile` + the 7 new endpoints, all 4 `/system/*` routes using `_adminRequest`), extend `evaluateBootstrapLocatorContent` in `companion_core` to validate optional `library_root` fail-closed, update `check_dart_openapi_parity.py` (promoting all M2 model/storage/autostart routes cleanly out of `UNMAPPED_FUTURE_ROUTES`) & `test_check_dart_openapi_parity.py`.
     - Update Desktop Settings UI (`settings_screen.dart`, `settings_runtime_section.dart`, `settings_storage_section.dart`, `settings_general_section.dart`), wiring `hostAdminStore: HostAdminSecretStore()` in `SettingsRuntimeSection._resolveClient()` fallback and preserving standalone offline tests when `client == null`.

- **Contract & Schema Impact:**
  - **Database Migrations:** Zero SQLite schema changes required (`bootstrap.json`, Schema v3 `models.json`, and `host_config.json` own host-level storage, model library, and autostart state per `storage-and-assets.md` §2.4 & `runtime-and-models.md` §2.8).
  - **New OpenAPI Routes (+7 HTTP routes):**
    1. `GET /api/v1/system/storage` (`require_host_admin`)
    2. `PUT /api/v1/system/storage/library-root` (`require_host_admin`)
    3. `GET /api/v1/system/autostart` (`require_host_admin`)
    4. `PUT /api/v1/system/autostart` (`require_host_admin`)
    5. `POST /api/v1/models/import/scan` (`require_host_admin`)
    6. `POST /api/v1/models/import/install` (`require_host_admin`)
    7. `DELETE /api/v1/models/registry/{model_id}` (`require_host_admin`)
  - **OpenAPI & Dart Parity:** All new schemas registered in `SCHEMA_TO_DART_CLASS`, all new & promoted M2 routes mapped in `M2_ROUTE_DART_METHODS`, verified with `scripts/check_openapi_contract.py --check`, `scripts/check_dart_openapi_parity.py --check`, and `scripts/tests/test_check_dart_openapi_parity.py`.

---

## 3. Proposed File Changes & In-Place Logic

### [MODIFY] `backend/app/core/storage.py` & `backend/app/core/config.py`
- **Primary Responsibility:** Five canonical storage roots resolution (`APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`), optional `library_root` pointer in `bootstrap.json`, and canonical `LIBRARY_ROOT/imports/{inbox,staging}` placement.
- **Planned Change:** Add pure resolvers (`get_default_cache_root`, `get_default_log_root`, `resolve_library_root`, `resolve_cache_root`, `resolve_log_root`, `resolve_app_install_root`), guard `resolve_library_root()` against mixing env `COMPANION_DATA_ROOT` with unrelated global `bootstrap.json['library_root']`, extend `write_bootstrap()` cleanly with `library_root: Optional[Path] = None` (backward-compatible 2-key default), extend `CanonicalPaths` with `APP_INSTALL_ROOT`/`CACHE_ROOT`/`LOG_ROOT`, move `IMPORT_*` under `LIBRARY_DIR / "imports"`, and expose properties + `HOST_DEDICATED_VRAM_GB` on `Settings`.
- **Invariants to Preserve:** Zero directory creation on `resolve_*`/`get_canonical_paths()`; fail-closed `BootstrapCorruptError`/`StorageError` on malformed/relative paths.

### [MODIFY] `backend/app/main.py`
- **Primary Responsibility:** Exempt read-only host storage/autostart telemetry paths during shutdown admission control (`NON_DB_PATHS`).
- **Planned Change:** Add `"/api/v1/system/storage"` and `"/api/v1/system/autostart"` to `RuntimeAdmissionASGIMiddleware.NON_DB_PATHS`.

### [MODIFY] `backend/app/schemas/health.py`, `backend/app/schemas/model_registry.py` & `backend/app/services/host_config.py`
- **Primary Responsibility:** Typed Pydantic v2 request/response contracts (1:1 aligned for Dart parity) and `host_config.json` autostart preference helpers.
- **Planned Change:** Add `StorageRootOut`, `StorageRootsResponse`, `LibraryRootUpdateRequest`, `AutostartStatusOut`, `AutostartUpdateRequest` to `health.py`; add `PreflightAssessmentOut`, `ModelImportCandidateOut`, `ModelImportScanOut`, `ModelImportInstallRequest`, `ModelImportInstallOut`, `ModelDeleteOut` to `model_registry.py` (using a clean flat DTO contract on `ModelImportInstallOut` alongside `ModelRegistryEntry` or clean schema fields compatible with `check_dart_openapi_parity.py`); add `get_autostart_preferences()` / `save_autostart_preferences()` to `host_config.py`.

### [ADD] `backend/app/services/model_import.py` & [MODIFY] `backend/app/services/model_registry.py`, `backend/app/services/llm/llama_cpp.py`, `backend/app/services/llm/manager.py`
- **Primary Responsibility:** Fix real GGUF header parsing, execute D6 inbox scan/staging/atomic install/delete, and enable `LlamaCppProvider` & `LLMManager` to run D6-installed models across relocated/default `MODEL_LIBRARY_DIR`.
- **Planned Change:** Update `read_gguf_metadata()` with size/stream-bounded skipping of `tokenizer.ggml.*` arrays & oversized `tokenizer.chat_template` while preserving `MAX_STRING_LENGTH`/`MAX_ARRAY_LENGTH` bounds tests; add `scan_import_inbox()`, `install_inbox_candidate()`, `delete_installed_model()` in `model_import.py`; update `LlamaCppProvider` root resolution (`_active_models_dir`, router respawn on `factory` <-> `installed` root switch, `_resolve_model_path()`, `get_status()`) and `LLMManager.refresh_auto_provider_if_idle()`.

### [ADD] `backend/app/services/autostart.py`
- **Primary Responsibility:** Standard-user Windows Task Scheduler XML registration & query (`PC-HOST-002`).
- **Planned Change:** Implement `WindowsAutostartService` generating Task Scheduler XML (`ONLOGON`, `LeastPrivilege`, explicit `WorkingDirectory`, `--minimized-to-tray`, `PT0S` execution limit, battery enabled), invoking `schtasks.exe` cleanly with platform-gated `CREATE_NO_WINDOW` (`if sys.platform == "win32":`) and zero import-time side effects.

### [MODIFY] `backend/app/api/v1/endpoints/health.py` & `backend/app/api/v1/endpoints/llm.py`
- **Primary Responsibility:** Host-Admin storage, autostart, D6 import scan/install, and installed-model removal endpoints.
- **Planned Change:** Mount `GET /system/storage`, `PUT /system/storage/library-root`, `GET /system/autostart`, `PUT /system/autostart` on `system_router` (all enforcing `require_host_admin` consistently, plus idle-router stop and self/nesting/env guards on relocation); add `POST /models/import/scan`, `POST /models/import/install`, `DELETE /models/registry/{model_id}` in `llm.py`.

### [MODIFY] `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`, `frontend/flutter/packages/companion_core/`, & `frontend/flutter/packages/companion_api/`
- **Primary Responsibility:** OpenAPI 3.1 contract regeneration, Dart DTO + `CompanionClient` parity, and `companion_core` optional `library_root` locator validation.
- **Planned Change:** Regenerate `openapi.json`, extend `evaluateBootstrapLocatorContent()` for optional `library_root`, add mapped DTOs + `_adminRequest`/`CompanionClient` methods, promote M2 routes in `check_dart_openapi_parity.py`, and update route count expectation in `test_check_dart_openapi_parity.py`.

### [MODIFY] `frontend/flutter/apps/desktop/` (`windows/runner/main.cpp`, `windows/runner/flutter_window.h/.cpp`, `lib/main.dart`, `lib/lifecycle/desktop_lifecycle_coordinator.dart`, `lib/coordinator/desktop_runtime_coordinator.dart`, `lib/screens/settings_screen.dart`, `lib/features/settings/sections/{settings_runtime_section.dart,settings_storage_section.dart,settings_general_section.dart}`)
- **Primary Responsibility:** Flash-free `--minimized-to-tray` startup, 10-level ancestor runtime path discovery, and Settings UI for `PC-CLIENT-010`, `PC-HOST-004`, and `PC-HOST-002`.
- **Planned Change:** Skip initial Win32 `Show()` + hide/await coordinator init cleanly in `main.cpp`/`flutter_window.*`/`main.dart`/`desktop_lifecycle_coordinator.dart` (with fallback show when tray unavailable); walk 10 ancestors (+ `COMPANION_APP_INSTALL_ROOT`) in `desktop_runtime_coordinator.dart`; pass `client` from `SettingsScreen` into Storage & General sections; wire `HostAdminSecretStore()` in `SettingsRuntimeSection._resolveClient()` fallback; build interactive Hardware Profile selector, D6 Import Inbox, 5-root Storage relocation, and Windows Autostart toggle while preserving standalone test mode (`client == null`).

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Slice 1 (`PC-HOST-004` Five Storage Roots & Relocatable `LIBRARY_ROOT`):**
   - **RED:** Expand `test_bootstrap.py` & `test_storage_engine_lifecycle.py` for 5-root resolution, `library_root` relocation, env-override isolation, `IMPORT_*` under `LIBRARY_ROOT`, self/nesting/env relocation rejections, and `GET`/`PUT /system/storage*` (`require_host_admin`, `409 Conflict` when model loaded).
   - **GREEN:** Update `storage.py`, `config.py`, `main.py`, `schemas/health.py`, and `endpoints/health.py`.
   - **REFACTOR:** Keep resolver and validation helpers concise and pure.

2. **Slice 2 (`PC-MODEL-001`..`006` D6 Import, Real GGUF Fix & Multi-Root Runtime):**
   - **RED:** Add tests in `test_model_registry.py` and `test_d6_model_import_and_autostart.py` for real-world GGUF headers with large `tokenizer.ggml.*` arrays & `tokenizer.chat_template` strings before `general.file_type`, preserving existing bounds tests (`tokenizer.tokens` > 64), inbox symlink containment, `mmproj` pairing, preflight thresholds, SHA-256 verification, atomic `os.replace`, Schema v3 `models.json` persistence, `DELETE /models/registry/{id}`, `LlamaCppProvider` installed root switching, and `LLMManager.refresh_auto_provider_if_idle()`.
   - **GREEN:** Update `model_registry.py`, `llama_cpp.py`, `manager.py`, `llm.py`, and create `model_import.py`.
   - **REFACTOR:** Deduplicate path containment checks cleanly across import/delete/relocation helpers.

3. **Slice 3 (`PC-HOST-002` Windows Task Scheduler XML Autostart & Flash-Free `--minimized-to-tray`):**
   - **RED:** Add backend tests in `test_d6_model_import_and_autostart.py` for `WindowsAutostartService` XML generation (`LeastPrivilege`, `WorkingDirectory`, `--minimized-to-tray`, `PT0S`, battery allowed, `sys.platform == "win32"` `CREATE_NO_WINDOW` guard, `GET`/`PUT /system/autostart`, `test_import_isolation.py` zero import-time side effects) + Flutter unit tests for `--minimized-to-tray` (`showImmediately: false` hides window when tray available, restores when unavailable) and 10-level ancestor runtime discovery.
   - **GREEN:** Create `autostart.py`, extend `host_config.py` + `endpoints/health.py`, and update `main.cpp`, `flutter_window.h/.cpp`, `main.dart`, `desktop_lifecycle_coordinator.dart`, and `desktop_runtime_coordinator.dart`.

4. **Slice 4 (`PC-CLIENT-010`, OpenAPI & Dart Parity, Desktop Settings UI):**
   - Regenerate `contracts/openapi/openapi.json` (`check_openapi_contract.py --write`), update `storage_diagnostic.dart`, `companion_api` DTOs & `CompanionClient`, `check_dart_openapi_parity.py`, & `test_check_dart_openapi_parity.py`, and add `m2_models_storage_autostart_dto_test.dart`.
   - **RED:** Add failing Desktop tests in `desktop_m2_models_storage_autostart_test.dart` for Hardware Profile switching, D6 Scan & Install UI, Installed Model deletion, live 5-root Storage relocation UI, and General Autostart toggle (preserving offline `SettingsStorageSection` & `SettingsGeneralSection` tests).
   - **GREEN:** Implement UI updates across `settings_screen.dart`, `settings_runtime_section.dart`, `settings_storage_section.dart`, and `settings_general_section.dart`.
   - **REFACTOR:** Extract clean subwidgets/helpers while preserving design system tokens (`SoftGlassPanel`, `NeumorphicSurface`).

5. **Phase 3 Documentation, Packaging & Draft PR:**
   - Reconcile canonical specs (`storage-and-assets.md`, `runtime-and-models.md`, `windows-host-and-notifications.md`), `WBS.md`, `MASTER_CHECKLIST.md`, `DELIVERY_INDEX.md`, `SPRINT_ROADMAP.md`, `task.md`, `CHANGELOG.md`, walkthrough (`walkthrough-m2-models-storage-autostart-e.md`), archive branch tracker, push, and open a Draft PR against `develop`.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Backend test suite: `backend\.venv\Scripts\python.exe -m pytest backend\tests -q -p no:cacheprovider -o log_file=NUL`
- [ ] Import isolation & dependency lock check: `backend\.venv\Scripts\python.exe -m pytest backend\tests\test_import_isolation.py scripts\tests\test_python_dependency_lock.py -q -p no:cacheprovider -o log_file=NUL`
- [ ] OpenAPI contract drift check: `backend\.venv\Scripts\python.exe scripts\check_openapi_contract.py --check`
- [ ] OpenAPI & Dart contract parity: `backend\.venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check` and `backend\.venv\Scripts\python.exe -m unittest scripts\tests\test_check_dart_openapi_parity.py -v`
- [ ] Dart static analysis & SDK tests: `cd frontend\flutter && dart analyze .` and `cd frontend\flutter\packages\companion_core && dart test` and `cd frontend\flutter\packages\companion_api && dart test`
- [ ] Flutter Desktop test suite & Windows MSVC build: `cd frontend\flutter\apps\desktop && flutter test --no-pub --concurrency=1 test` and `flutter build windows --debug --no-pub`
- [ ] Diff hygiene: `git diff --check develop`

### Manual & Host-Level Checks (Windows Desktop)
- [ ] Inspect `Settings -> Storage & Diagnostics`: verify all 5 roots report live backend telemetry + free disk space, and relocate `LIBRARY_ROOT` to a secondary directory verifying `bootstrap.json` updates and `IMPORT_INBOX_DIR` moves cleanly.
- [ ] Inspect `Settings -> AI Runtime & Models`: drop a test `.gguf` (+ optional `mmproj-*.gguf`) into `IMPORT_INBOX_DIR`, click **Scan Inbox**, review metadata & VRAM suitability badge, click **Install Bundle**, select/load a D6-installed model + switch profile (`Eco` / `Balanced` / `Maximum`), and remove a user-installed entry.
- [ ] Inspect `Settings -> General & Lifecycle`: toggle **Launch at Windows Login (Minimized to Tray)** on/off, verify `schtasks /Query /TN AICompanionAutostart /XML` shows standard-user `LeastPrivilege` `LogonTrigger` + `<WorkingDirectory>` + `--minimized-to-tray` without UAC prompts, and launch `ai_companion_desktop.exe --minimized-to-tray` to confirm flash-free hidden startup in system tray (plus restore from tray and intentional `Exit Companion` remaining stopped).

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Cross-Volume Atomic Install (`EXDEV`):** Placing `IMPORT_STAGING_DIR` directly under `<LIBRARY_ROOT>/imports/staging` guarantees staging and `MODEL_LIBRARY_DIR` live on the same volume so `os.replace` is atomic even when `LIBRARY_ROOT` is relocated to `D:\` or `E:\`. Relocating `LIBRARY_ROOT` across volumes uses verified copy + SHA-256/size verification rather than raw cross-volume rename.
- **Path Traversal & Symlink Containment:** Both D6 inbox scanning/install and `LIBRARY_ROOT` model deletion resolve `.resolve(strict=...)` against resolved base directories (`is_relative_to`) and reject symlinks escaping `IMPORT_INBOX_DIR` or `MODEL_LIBRARY_DIR`. Relocation validates against self, parent/child nesting, `DATA_ROOT/database`, and `APP_INSTALL_ROOT`.
- **Active Model & Idle Router Mutation Guard:** `PUT /api/v1/system/storage/library-root` and `DELETE /api/v1/models/registry/{model_id}` fail closed with `409 Conflict` while a model is loaded/loading/generating, and relocation stops any idle (`MODEL_UNLOADED`) Core-managed `llama-server.exe` process cleanly beforehand.
- **No Unapproved Scope Creep (`test_import_isolation.py`):** Autostart XML commands, filesystem directory creation, and GGUF inspection execute lazily upon request, preserving zero import-time side effects.
- **Required Permissions:** Task-bounded branch creation, commits, push on `feature/m2-models-storage-autostart-e`, and Phase 3 Draft PR against `develop` (Human Owner performs final squash merge).
- **Genuine Stop Conditions:** Material scope expansion into Profile PIN / Device Enrollment / M5 features, unapproved SQLite schema migration, security boundary conflict, or unresolvable test/build failure requires halting and escalating to the Human Owner.
