# Walkthrough: M2 Batch E — Five Storage Roots, Relocatable Library, D6 Model Import, Desktop Model UI & Windows Login Autostart

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Documents the implementation and local verification of M2 Batch E (`PC-HOST-004`, `PC-MODEL-001`..`006`, `PC-HOST-002`, `PC-CLIENT-010`, `PC-API-001`): five canonical storage roots with relocatable `LIBRARY_ROOT`, real GGUF header parsing & caching, executable Decision D6 controlled local model import/delete + multi-root `LlamaCppProvider`, standard-user Windows Task Scheduler login autostart with flash-free `--minimized-to-tray` startup, OpenAPI/Dart contract parity, and Desktop Settings UI.
- Audience: Human Owner, Independent Reviewers, Developers, and Windows Desktop QA.
- Status: Implemented & Automated-Verified Locally — Manual Windows Host QA Remaining
- Last Updated: 2026-11-22

---

## 1. What Was Delivered

- **Five Storage Roots & Relocatable `LIBRARY_ROOT` (`PC-HOST-004`):**
  - Extended `backend/app/core/storage.py` and `config.py` so `CanonicalPaths` resolves `APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, and `LOG_ROOT` without eager directory creation on lookup.
  - Added optional fail-closed `library_root` support in `bootstrap.json` (`write_bootstrap()` omits `library_root` unless supplied so legacy 2-key locators remain intact) and `COMPANION_LIBRARY_ROOT` env overrides with isolation preventing test `COMPANION_DATA_ROOT` overrides from colliding with `%LOCALAPPDATA%\AI Companion\bootstrap.json`.
  - Moved `IMPORT_INBOX_DIR` (`<LIBRARY_ROOT>/imports/inbox`) and `IMPORT_STAGING_DIR` (`<LIBRARY_ROOT>/imports/staging`) directly under `LIBRARY_ROOT`, resolving `storage-and-assets.md` §3.4 technical debt and keeping D6 staging on the same volume as `MODEL_LIBRARY_DIR`.
  - Exposed Host-Admin `GET /api/v1/system/storage` and `PUT /api/v1/system/storage/library-root` (guarding self, parent/child nesting, DB/install paths, `COMPANION_LIBRARY_ROOT` lock, and loaded/loading/generating model conflicts, while cleanly stopping idle Core-managed `llama-server.exe`).
- **Real GGUF Parser Fix, D6 Manual Import & Multi-Root Runtime (`PC-MODEL-001`..`006`):**
  - Fixed `read_gguf_metadata()` in `backend/app/services/model_registry.py` with buffered skipping (`_skip_gguf_array`) for `tokenizer.ggml.*` arrays (`MAX_SKIP_ARRAY_LENGTH = 1_000_000`) and bounded `tokenizer.chat_template` skipping (`MAX_CHAT_TEMPLATE_LENGTH = 65_536`), backed by size/mtime metadata caching (`_GGUF_METADATA_CACHE`) for real `.gguf` files `>= 64 KB` so trailing `general.*` keys extract cleanly without blocking `orchestrate_chat_stream()`.
  - Added pure `assess_hardware_suitability()` advisory VRAM preflight against `HOST_DEDICATED_VRAM_GB` (`8.0` default).
  - Implemented `backend/app/services/model_import.py` (`scan_import_inbox()`, `install_inbox_candidate()` with symlink containment, `.gguf` + `mmproj` pairing into `MODEL_LIBRARY_DIR/<model_id>/`, SHA-256 verification, atomic `os.replace`, Schema v3 `models.json` persistence, and `LLMManager.refresh_auto_provider_if_idle()` promotion, plus `delete_installed_model()`), mounted at `POST /api/v1/models/import/scan`, `POST /api/v1/models/import/install`, and `DELETE /api/v1/models/registry/{model_id}`.
  - Updated `LlamaCppProvider` + `host_config.json` to persist `hardware_profile`, reset router state cleanly (`SERVER_STOPPED`) when `set_profile()` stops an active Core-managed router, and switch `--models-dir` cleanly between factory (`LLAMA_MODELS_DIR`) and installed (`MODEL_LIBRARY_DIR`) roots via strict `registry_source == "installed"` checks.
- **Windows Task Scheduler Autostart & Flash-Free Tray Startup (`PC-HOST-002`):**
  - Created `backend/app/services/autostart.py` (`WindowsAutostartService`) generating Task Scheduler v1.2 XML (`AICompanionAutostart`, `LogonTrigger`, `<RunLevel>LeastPrivilege</RunLevel>`, explicit `<WorkingDirectory>`, `--minimized-to-tray`, `PT0S`, battery allowed, `xml.sax.saxutils.escape`-sanitized paths, and no `/RI` watchdog restart so intentional `Exit Companion` remains honored), exposed via `GET`/`PUT /api/v1/system/autostart`.
  - Updated `main.cpp`, `flutter_window.h/.cpp`, `main.dart`, and `DesktopLifecycleCoordinator.initialize(showImmediately: ...)` so `--minimized-to-tray` / `--autostart` suppresses first-frame `Show()` and hides cleanly when tray initialization succeeds (falling back to visible focus if tray fails), and expanded `DesktopRuntimeCoordinator` parent discovery to `10` ancestor levels (`+ COMPANION_APP_INSTALL_ROOT`).
- **OpenAPI, `companion_api` Parity & Desktop Settings UI (`PC-CLIENT-010`, `PC-API-001`):**
  - Regenerated `contracts/openapi/openapi.json` (`86` routes), extended `companion_core` fail-closed `library_root` validation, added `11` new DTO classes + enriched `const`-safe `ModelRegistryEntry` + `8` methods in `companion_api`, updated `check_dart_openapi_parity.py` (`98/98` schemas, `111` native routes), and upgraded `SettingsRuntimeSection`, `SettingsStorageSection`, and `SettingsGeneralSection` while preserving standalone `client == null` offline behavior.
- **Explicit Out-of-Scope / Deferred:**
  - Profile PIN lock / Windows Hello, Satellite Device Enrollment (`PC-IDENTITY-003`), M5 Gaming/Cloud/Backup-Reset, React Web, Android, and optional SSE multi-GB copy progress (`DEBT-V1-05`) remain deferred.

## 2. Files Changed

- `backend/app/core/storage.py`, `backend/app/core/config.py`, `backend/app/main.py` — 5 storage roots, `library_root` relocation, `LIBRARY_ROOT/imports/{inbox,staging}`, and `NON_DB_PATHS`.
- `backend/app/schemas/health.py`, `backend/app/schemas/model_registry.py` — Storage, autostart, preflight, D6 scan/install/delete contracts.
- `backend/app/services/host_config.py`, `backend/app/services/autostart.py` [NEW], `backend/app/services/model_registry.py`, `backend/app/services/model_import.py` [NEW] — Host config persistence, Windows Task Scheduler XML service, GGUF parser/cache/preflight, D6 scan/install/delete service.
- `backend/app/services/llm/llama_cpp.py`, `backend/app/services/llm/manager.py` — Multi-root `LlamaCppProvider`, `hardware_profile` persistence/reset, `refresh_auto_provider_if_idle()`.
- `backend/app/api/v1/endpoints/health.py`, `backend/app/api/v1/endpoints/llm.py` — 7 new Host-Admin storage, autostart, and D6 model endpoints.
- `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py` — Regenerated contract & parity verification.
- `frontend/flutter/packages/companion_core/lib/storage/storage_diagnostic.dart`, `frontend/flutter/packages/companion_api/lib/{dto/system_status_dto.dart,dto/model_registry_dto.dart,client/companion_client.dart}` — Fail-closed `library_root` locator validation, 11 new DTOs, enriched `ModelRegistryEntry`, 8 client methods.
- `frontend/flutter/apps/desktop/windows/runner/{main.cpp,flutter_window.h,flutter_window.cpp}`, `frontend/flutter/apps/desktop/lib/{main.dart,lifecycle/desktop_lifecycle_coordinator.dart,coordinator/desktop_runtime_coordinator.dart,screens/settings_screen.dart,features/settings/sections/{settings_runtime_section.dart,settings_storage_section.dart,settings_general_section.dart}}` — Flash-free tray launch, 10-level ancestor runtime discovery, and Settings Runtime/Storage/General UI.
- Tests: `backend/tests/{test_bootstrap.py,test_storage_engine_lifecycle.py,test_model_registry.py,test_d6_model_import_and_autostart.py}`, `frontend/flutter/packages/companion_core/test/storage_diagnostic_test.dart`, `frontend/flutter/packages/companion_api/test/m2_models_storage_autostart_dto_test.dart`, `frontend/flutter/apps/desktop/test/{desktop_lifecycle_test.dart,desktop_m2_models_storage_autostart_test.dart}`.
- Documentation: `storage-and-assets.md`, `runtime-and-models.md`, `windows-host-and-notifications.md`, `DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `SPRINT_ROADMAP.md`, `DECISION_DEBT.md`, `task.md`, `CHANGELOG.md`, `plan-m2-models-storage-autostart-e.md`, archived `task-feature-m2-models-storage-autostart-e.md`.

## 3. How the Logic Works

1. **Five Storage Roots & Relocation:** `get_canonical_paths()` derives `APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, and `LOG_ROOT` purely from env overrides and `bootstrap.json` (ignoring global `bootstrap.json` `library_root` when `COMPANION_DATA_ROOT` env isolates a test run). `PUT /api/v1/system/storage/library-root` stops any idle router, verifies path safety, copies/verifies assets when requested, atomically updates `bootstrap.json`, and returns updated `StorageRootsResponse`.
2. **D6 Controlled Model Import:** User places `.gguf` (+ optional `mmproj-*.gguf`) into `IMPORT_INBOX_DIR` (`<LIBRARY_ROOT>/imports/inbox`) and clicks **Scan Inbox** (`POST /models/import/scan`), which inspects GGUF headers (using buffered `_skip_gguf_array` + `_GGUF_METADATA_CACHE`) and computes `assess_hardware_suitability()`. On **Install Bundle** (`POST /models/import/install`), files stage into a unique `IMPORT_STAGING_DIR` subdir, verify SHA-256 + GGUF validity, move atomically (`os.replace`) into `<MODEL_LIBRARY_DIR>/<model_id>/`, persist Schema v3 `models.json`, and promote idle `MockLLMProvider` in `auto` mode.
3. **Windows Login Autostart & Flash-Free Tray Launch:** Toggling **Launch at Windows Login** (`PUT /system/autostart`) builds escaped Task Scheduler XML (`AICompanionAutostart`, `LeastPrivilege`, explicit `WorkingDirectory`, `--minimized-to-tray`) via `WindowsAutostartService`. On Windows boot, `main.cpp` forwards `--minimized-to-tray` -> `FlutterWindow` skips first-frame `Show()` -> `main.dart` awaits `DesktopLifecycleCoordinator.initialize(showImmediately: false)` to minimize cleanly into the tray while `DesktopRuntimeCoordinator` resolves the backend executable up to `10` ancestor directories deep.

## 4. Key Concepts

- **`LIBRARY_ROOT` Isolation & Same-Volume Staging:** Placing `imports/inbox` and `imports/staging` inside `LIBRARY_ROOT` keeps large GGUF staging atomic (`os.replace`) even when `LIBRARY_ROOT` moves to `D:\` or `E:\`.
- **Advisory VRAM Preflight:** `assess_hardware_suitability()` guides users toward `recommended`, `supported_with_warning`, or `not_recommended` profiles against `HOST_DEDICATED_VRAM_GB` without locking out manual model selection.
- **No Watchdog `/RI` Autostart:** Registering `LogonTrigger` cleanly without periodic restart intervals ensures `Exit Companion` stops the app intentionally as required by D2.

## 5. Verification Steps

### Automated Checks

- [x] Full backend test suite, import isolation & dependency lock check: `backend\.venv\Scripts\python.exe -m pytest backend\tests backend\tests\test_import_isolation.py scripts\tests\test_python_dependency_lock.py -q -p no:cacheprovider -o log_file=NUL` — **`922 passed, 4 subtests passed` in `447.72s`** (exit `0`).
- [x] OpenAPI contract drift check: `backend\.venv\Scripts\python.exe scripts\check_openapi_contract.py --check` — **`86 routes`** (exit `0`).
- [x] Dart-OpenAPI contract parity & unit tests: `backend\.venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check` (**`98/98` schemas, `111` native routes**, exit `0`) and `python.exe -m unittest scripts\tests\test_check_dart_openapi_parity.py -v` (**`8/8 OK`**, exit `0`).
- [x] Flutter workspace static analysis & SDK tests: `cd frontend\flutter && dart analyze .` (**`No issues found!`**), `companion_core` `dart test` (**`24/24` passed**), `companion_api` `dart test` (**`114/114` passed**).
- [x] Flutter Desktop test suite & Windows MSVC build: `cd frontend\flutter\apps\desktop && flutter test --no-pub --concurrency=1 test && flutter build windows --debug --no-pub` — **`433/433` passed**, built `build\windows\x64\runner\Debug\ai_companion_desktop.exe` in `47.9s` (exit `0`).
- [ ] Diff hygiene check (`git diff --check develop`) — executed prior to staging/commit.

### Manual / User-Owned Checks (Windows Desktop)

- [ ] **Storage Relocation (`Settings -> Storage & Diagnostics`):** Inspect live telemetry across all 5 storage roots (`APP_INSTALL`, `DATA`, `LIBRARY`, `CACHE`, `LOG`) + **Copy Path** / **Open in Explorer**, relocate `LIBRARY_ROOT` to a secondary directory, and confirm `bootstrap.json` & `IMPORT_INBOX_DIR` relocate cleanly.
- [ ] **D6 Real Bundle & Profile UI (`Settings -> AI Runtime & Models`):** Drop a real `.gguf` (+ optional `mmproj-*.gguf`) into `IMPORT_INBOX_DIR`, click **Scan Inbox**, review VRAM preflight badges + 1-click **Apply Recommended Profile**, click **Install Bundle**, load the installed model, switch `Eco` / `Balanced` / `Maximum` verifying parameter readout & restart persistence, and test user-installed Uninstall.
- [ ] **Windows Autostart & Flash-Free Tray (`Settings -> General & Lifecycle`):** Toggle **Launch at Windows Login (Minimized to Tray)** on/off, verify `schtasks /Query /TN AICompanionAutostart /XML` reflects standard-user `LeastPrivilege` `LogonTrigger` + `<WorkingDirectory>` + `--minimized-to-tray` without UAC prompts, launch `ai_companion_desktop.exe --minimized-to-tray` to confirm flash-free hidden tray startup, restore from tray, and verify `Exit Companion` remains stopped.

## 6. Safe Customization & Invariants

- **`HOST_DEDICATED_VRAM_GB`:** Tunable host VRAM budget (`8.0` default) used by advisory `assess_hardware_suitability()` heuristics.
- **Preserved Invariants:** Zero directory creation on `resolve_*`/`get_canonical_paths()`, fail-closed `library_root` validation, strict GGUF key/generic-array bounds (`MAX_STRING_LENGTH = 1024`, `MAX_ARRAY_LENGTH = 64`), no background inbox polling watcher, offline standalone `SettingsStorageSection` (`client == null`) test invariants preserved.

## 7. Troubleshooting

- **Symptom:** Async chat streaming tests timed out (`2.0s`) during `build_model_list()`.
  - **Likely cause:** Calling `f.seek()` on every small string element in `tokenizer.ggml.tokens`/`merges` flushed Python's `BufferedReader` ~300k times per `.gguf` file.
  - **Resolution:** Sequential buffered reads (`<= 65536` bytes) in `_skip_gguf_array()` + size/mtime `_GGUF_METADATA_CACHE` (`>= 64 KB`) in `model_registry.py` cut `build_model_list()` latency from `2.803s` down to fast cached lookups and restored `test_attachment_binding.py` + `test_model_registry.py` to `84 passed in 18.63s`.
