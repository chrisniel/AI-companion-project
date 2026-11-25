# Walkthrough: M5 Batch A — Fast-Boot Startup Optimization, ISO-8601/TTS Polish & Host Resource Governance / Gaming Mode

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Documents the implementation and local automated verification of M5 Stage 1 Batch A (`PC-RESOURCE-001`..`004`, `DEBT-V1-07`): fast-boot Windows runtime startup optimization, ISO-8601 scheduler localization + Markdown/Kokoro TTS polish, host-wide Low-Impact / Gaming Mode (`Normal` / `Low-Impact` / `Auto`) with hysteresis cooldown and non-blocking provider adaptation, OpenAPI/Dart parity, and `Settings -> Performance & Gaming` + System Tray quick-mode synchronization.
- Audience: Human Owner, Independent Reviewers, Developers, and Windows Desktop QA.
- Status: Implemented & Automated-Verified Locally — Phase 4 Independent Review & Manual Windows Host QA Pending
- Last Updated: 2026-11-24

---

## 1. What Was Delivered

- **Slice A1 — Fast-Boot Startup Optimization:**
  - `WindowsShellChannel` (`windows_shell_channel.cpp`): Scoped `ScopedComInit` strictly to `pickFolder`/`pickFiles`, added `filterPreset: "executables"` inside `pickFiles`, and implemented read-only Win32 `isProcessAliveAndMatching` and `discoverCandidateProcesses` using RAII `ScopedHandle`, `CreateToolhelp32Snapshot`, `QueryFullProcessImageNameW`, `IsWow64Process`, `GetProcessTimes`, dynamic `NtQueryInformationProcess`, and x64 `PEB` `CommandLine` `ReadProcessMemory` with fail-closed `needsFallback: true` back to PowerShell CIM whenever `PROCESS_VM_READ`/WoW64 blocks inspection.
  - `DesktopProcessInspector` / `WindowsProcessInspector` & `WindowsRuntimeProcessSupervisor`: Wired fast Win32 process provenance under `DefaultProcessLauncherAdapter` on live Windows while keeping test fakes and fail-closed `needsFallback` PowerShell CIM fallback intact.
  - `DesktopRuntimeCoordinator`: Split loopback port probe timeout (`350ms` `initialProbeTimeout`) from full `/api/v1/health` verification (`2s`).
  - Backend `storage.py` & `main.py`: Added AST-based `_extract_migration_revision_info()` and `_resolve_single_alembic_head_fast()` in `prepare_database_schema()` after `st_size > 0` + `inspect_legacy_candidate()` validation to bypass redundant `ScriptDirectory` scans at head, and deferred startup maintenance purge / missed-event reconciliation inside cancellable post-yield background wrappers in `lifespan()` (removing duplicate `sweep_expired_memories()`).
- **Slice A2 — ISO-8601 Timestamp Localization, Bold+Em-Dash Markdown & Kokoro TTS Polish:**
  - Passed active `profile` into `run_list_tasks`, `run_list_reminders`, and `run_list_alarms` (`executor.py`, `adapters_productivity.py`), defaulted `run_list_reminders` to `scheduled`/`snoozed` (`run_list_tasks` to `pending`/`in_progress`, `limit=50`, preview `15`) so finished rows never crowd out upcoming schedules, formatted human-readable `*_local` strings across task/reminder/alarm summaries while preserving raw ISO fields (`scheduled_at`, `due_at`), and fixed `run_create_alarm` passing `tz_name=tz_name` to `compute_next_occurrence()`.
  - Added deterministic Round-0 pre-armed schedule list fallback (`list_reminders` / `list_tasks` / `list_alarms`) + expanded provenance patterns and no-fabrication / no-raw-ISO rules in `orchestrator.py` so Gemma 3 and other models query real DB schedules reliably.
  - Updated `preprocess_text_for_tts()` (`tts.py`) to strip bold/italic/strikethrough (`[*_~]+`), convert ISO-8601 datetimes (`YYYY-MM-DDTHH:MM...`), standalone dates (`YYYY-MM-DD`), and 12-hour clock times (`2:00 PM` -> `2 PM`, `9:05 PM` -> `9 oh 5 PM`, exact-hour preposition `at 2:00` -> `at 2 o'clock`) into natural spoken phrasing early in the pipeline, guard numeric colons in `_LazyEspeakPhonemizer`/`text_to_kokoro_ipa`, and spell `ISO`.
  - Hardened `AssistantMarkdownView` bold tokenization (`\*\*(?!\s)(?:[^*]|\*(?!\*))+?(?<!\s)\*\*`) so bold spans immediately followed by em-dashes or containing isolated asterisks render cleanly.
- **Slice A3 — Host Resource Governance & Gaming Mode Engine (`PC-RESOURCE-001`..`004`, `DEBT-V1-07`):**
  - Thread-safe `host_config.py` (`_HOST_CONFIG_LOCK = threading.RLock()` with `pid.tid.rand` atomic temp suffix) persisting normalized lowercase `.exe` lists (validated via Windows invalid-filename denylist allowing `notepad++.exe`, `(x64)`, `[DX11]` while strictly requiring `.exe`), mode, strategy, lightweight model ID, and cooldown (`5`–`300s`, default `45s`) under `"resource_policy"` in `host_config.json`.
  - `hardware_probe.py`: Added `None`-safe `probe_live_system_memory()` and `probe_live_gpu_telemetry()` returning truthful `None` (`Unavailable` in UI) when live GPU utilization/VRAM adapters are absent.
  - `BaseLLMProvider`, `LlamaCppProvider`, & `MockLLMProvider`: Added `has_active_generation`, non-blocking `apply_resource_policy()`, `get_resource_override_status()`, `_effective_profile_name()`, `_effective_model_name()`, `_unload_model_locked()`, `_stop_idle_managed_router_locked()`, `RESOURCE_LOW_IMPACT_IDLE_SECONDS = 60.0` idle unload, fail-closed `lightweight_model_missing`/`lightweight_model_unavailable` degradation to `cpu_eco`, lazy `Normal` exit without eager heavy-model reload, and explicit `is not None` `context_size`/`gpu_layers = 0` transitional snapshots.
  - `ResourceGovernor` (`resource_governor.py`), `orchestrator.py`, `scheduler/service.py`, `health.py`, & `main.py`: Standard-user Win32 `ctypes` `CreateToolhelp32Snapshot` watchlist monitoring (`5.0s` interval) with cooldown hysteresis & explicit reset, active-turn deferral (`deferred_active_turn`/`deferred_model_load`), D10-safe `should_defer_background_work` deferral (skipping non-explicit extraction and periodic sweeps/non-bypass Routines while strictly preserving Alarms, Reminders, Task due reminders, and explicit `"Remember that..."` turns), and Host-Admin `GET`/`PUT /api/v1/system/resources` (`NON_DB_GET_PATHS` read exemption & `503` write guard).
- **Slices A4 & A5 — OpenAPI/Dart Parity, `Settings -> Performance & Gaming` UI & System Tray Sync:**
  - Regenerated `contracts/openapi/openapi.json` (`87` paths / `119` routes / `147` schemas), added `ResourcePolicyStatusOut` / `ResourcePolicyUpdateRequest` + `getResourcePolicy()` / `updateResourcePolicy()` in `companion_api`, and registered `102/102` DTO schemas + `113/113` native routes in `check_dart_openapi_parity.py`.
  - Promoted `SettingsSectionId.health` to `Performance & Gaming` (`SettingsPerformanceSection` with focus/tab-aware silent real-time polling + `FocusNode`-guarded cooldown editing + transition status indicator), wired bidirectional `Performance Mode` System Tray submenu (`Normal` / `Low-Impact` / `Auto Gaming`) + menu-open refresh in `DesktopLifecycleCoordinator` and `DesktopShell`, added `pickExecutableFiles` in `DesktopShellAdapter` / `WindowsShellAdapter`, and preserved standalone `client == null` `FLUTTER_TEST` behavior.
- **Explicit Out-of-Scope / Deferred:**
  - Batch B (`PC-RESILIENCE-001`..`004` Backup/Restore/Factory Reset), Batch C (`PC-CLOUD-001`..`004` Optional Cloud Fallback), Rust Stage 2 migration, SQLite schema migrations, `DEBT-EXP-001` RX 580 empirical swap benchmark, and live Windows PDH/DXGI GPU utilization telemetry remain out of scope for Batch A.

---

## 2. Files Changed

- **Backend Config, Lifecycle & Storage:** `backend/app/core/{config.py,storage.py}`, `backend/app/main.py`
- **Backend Schemas & Endpoints:** `backend/app/schemas/health.py`, `backend/app/api/v1/endpoints/health.py`
- **Backend Services:** `backend/app/services/{host_config.py,hardware_probe.py,resource_governor.py}` [NEW `resource_governor.py`], `backend/app/services/llm/{base.py,llama_cpp.py,mock.py}`, `backend/app/services/assistant/orchestrator.py`, `backend/app/services/scheduler/service.py`, `backend/app/services/tools/{executor.py,adapters_productivity.py}`, `backend/app/services/voice/tts.py`
- **Contracts & Parity Tooling:** `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`
- **Dart SDK (`companion_api`):** `frontend/flutter/packages/companion_api/lib/{dto/system_status_dto.dart,client/companion_client.dart}`
- **Flutter Desktop (`Windows` C++ & Dart):** `frontend/flutter/apps/desktop/windows/runner/windows_shell_channel.cpp`, `frontend/flutter/apps/desktop/lib/{platform/desktop_process_inspector.dart,platform/windows_shell_adapter.dart,platform/windows_runtime_process_supervisor.dart,coordinator/desktop_runtime_coordinator.dart,features/chat/assistant_markdown_view.dart,features/settings/settings_section.dart,features/settings/sections/settings_performance_section.dart,screens/settings_screen.dart,lifecycle/desktop_lifecycle_coordinator.dart,shell/desktop_shell.dart}` [NEW `desktop_process_inspector.dart`, `settings_performance_section.dart`]
- **Tests:** `backend/tests/{test_schema_lifecycle.py,test_d9_tools_and_policy.py,test_voice_engines_and_barge_in.py,test_resource_governor.py}` [NEW `test_resource_governor.py`], `frontend/flutter/packages/companion_api/test/m5_resource_governance_dto_test.dart` [NEW], `frontend/flutter/apps/desktop/test/{assistant_markdown_view_test.dart,desktop_m2_models_storage_autostart_test.dart,desktop_m5_resource_governance_test.dart,desktop_runtime_coordinator_test.dart,desktop_settings_revamp_test.dart,windows_runtime_process_supervisor_test.dart}` [NEW `desktop_m5_resource_governance_test.dart`]
- **Documentation:** `docs/04_Architecture/04_Infrastructure/{performance-and-capacity.md,windows-host-and-notifications.md,runtime-and-models.md,storage-and-assets.md}`, `docs/04_Architecture/01_Domains/{voice-and-audio.md,tasks-reminders-alarms-and-routines.md}`, `docs/02_Planning/00_Master/{WBS.md,DECISION_DEBT.md,DECISION_REGISTER.md,MASTER_CHECKLIST.md,DELIVERY_INDEX.md,SPRINT_ROADMAP.md}`, `docs/02_Planning/01_Plans/plan-m5-resource-governance-a.md`, `docs/01_Tracking/task.md`, `docs/01_Tracking/archive/task-feature-m5-resource-governance-a.md` [ARCHIVED], `docs/03_Walkthroughs/{README.md,walkthrough-m5-resource-governance-a.md}` [NEW], `CHANGELOG.md`

---

## 3. How the Logic Works

1. **Fast-Boot Startup:** `WindowsRuntimeProcessSupervisor` queries `WindowsShellChannel` natively (`isProcessAliveAndMatching` / `discoverCandidateProcesses`) before falling back to PowerShell CIM only on `needsFallback: true` (e.g., WoW64/protected processes). `DesktopRuntimeCoordinator` checks loopback port reachability within `350ms` (`initialProbeTimeout`) before spawn, `prepare_database_schema()` skips full Alembic `ScriptDirectory` scanning when `_resolve_single_alembic_head_fast()` verifies head parity on an intact SQLite database, and FastAPI `lifespan()` launches initial purge/reconcile sweeps asynchronously post-`yield`.
2. **ISO-8601 Localization & TTS/Markdown Polish:** Productivity tool execution resolves active `profile` timezone formatting into `*_local` fields and natural summary strings while keeping raw ISO fields intact. `preprocess_text_for_tts()` strips Markdown emphasis characters and converts ISO-8601 datetimes/dates into spoken natural language before punctuation/range normalization, while `AssistantMarkdownView` parses `**...**` reliably next to em-dashes (`—`) and isolated inner asterisks.
3. **Resource Governance (`ResourceGovernor` -> LLM/Scheduler -> UI/Tray):** Every `5.0s` (or immediately on Host-Admin `PUT /api/v1/system/resources`), `ResourceGovernor` evaluates explicit `requested_mode` (`normal` / `low_impact` / `auto`), scans standard-user Win32 running process basenames against the saved `.exe` watchlist (`cooldown_seconds` hysteresis `5`–`300s`, cleared on explicit mode switch), calls `provider.apply_resource_policy()` without blocking active turns (`deferred_active_turn` / `deferred_model_load`), applies `cpu_eco` / `60s` idle unload / `lightweight_model` swap (or fail-closed `cpu_eco` fallback), performs lazy `Normal` exit without eagerly reloading the heavy model, defers discretionary extraction/routines/sweeps via `should_defer_background_work` while keeping D10 alarms and reminders punctual, and exposes synchronized state to both `Settings -> Performance & Gaming` and the Windows System Tray `Performance Mode` submenu.

---

## 4. Key Concepts

- **Host-Wide Governance (`host_config.json` `"resource_policy"`):** Performance policy applies globally across the Windows host machine rather than per user profile, persisting normalized `.exe` watchlists, strategy, lightweight model override, and cooldown (`DEBT-V1-07`).
- **Non-Blocking Transition & Lazy Exit:** Active generation turns are never interrupted mid-flight; exiting `Low-Impact` restores requested profile/model policy lazily on the next chat request instead of triggering an unrequested heavy VRAM reload.
- **Truthful Telemetry (`Unavailable` over Fabrication):** Missing GPU adapters report `null` / `Unavailable` alongside live Windows RAM probing rather than synthesizing placeholder metrics.

---

## 5. Verification Steps

### Automated Checks (All Re-Run After Final Code Edit)

- [x] Full backend pytest suite: `backend\.venv\Scripts\python.exe -m pytest backend\tests -q -p no:cacheprovider -o log_file=NUL` — **`936 passed, 101 warnings in 407.35s (0:06:47)`** (exit `0`).
- [x] Isolated import isolation & dependency lock check: `$env:PYTHONPATH="backend;."; backend\.venv\Scripts\python.exe -m unittest backend.tests.test_import_isolation scripts.tests.test_python_dependency_lock -v` — **`Ran 11 tests in 8.176s — OK` (`ISOLATED_COLLECTION_COUNT=936`)** (exit `0`).
- [x] OpenAPI drift check: `backend\.venv\Scripts\python.exe scripts\check_openapi_contract.py --check` — **`87 routes`** up-to-date (exit `0`).
- [x] Dart-OpenAPI contract parity & unittest: `backend\.venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check` (**`102/102` schemas, `113/113` native routes**, exit `0`) and `backend\.venv\Scripts\python.exe -m unittest scripts\tests\test_check_dart_openapi_parity.py -v` (**`Ran 8 tests in 0.397s — OK`**, exit `0`).
- [x] Dart workspace static analysis & SDK unit tests: `cd frontend\flutter && dart analyze .` (**`No issues found!`**), `companion_core` `dart test` (**`+24: All tests passed!`**), and `companion_api` `dart test` (**`+117: All tests passed!`**) (exit `0`).
- [x] Flutter Desktop test suite & MSVC `/W4 /WX` Debug build: `cd frontend\flutter\apps\desktop && flutter test --no-pub --concurrency=1 test` (**`03:39 +453: All tests passed!`**) and `flutter build windows --debug --no-pub` (`Built build\windows\x64\runner\Debug\ai_companion_desktop.exe` in `25.6s`, exit `0`).
- [x] Diff whitespace hygiene (`git diff --check develop`) — verified clean before and after documentation closure.

### Manual / User-Owned Checks (Windows Desktop)

- [ ] Launch `ai_companion_desktop.exe` from stopped state and confirm native Win32 process provenance + schema fast-path bring the local runtime `readyAndAuthenticated` cleanly without visible console windows.
- [ ] Create/list a reminder via Chat and verify localized date/time formatting (`**...**—`) renders without raw ISO-8601 clutter and Kokoro TTS reads dates/times naturally without `"T"` or `"+00:00"`.
- [ ] In `Settings -> Performance & Gaming` (Auto Gaming mode), add a sample heavy `.exe` (via typed entry and **Browse .exe...**), launch/exit it to verify automatic switch to `Low-Impact`, VRAM unload/lightweight swap, cooldown countdown, lazy `Normal` exit, bidirectional System Tray `Performance Mode` sync, and D10 alarm firing while `Low-Impact` is active.

---

## 6. Safe Customization & Invariants

- **Tunable Parameters:** `cooldown_seconds` (`5`–`300`, default `45`), `RESOURCE_POLL_INTERVAL_SECONDS = 5.0`, `RESOURCE_LOW_IMPACT_IDLE_SECONDS = 60.0`.
- **Preserved Invariants:** Zero cloud fallback triggered by resource pressure, zero eager heavy-model reloads on `Low-Impact` exit, fail-closed `Host-Admin` auth on `GET`/`PUT /api/v1/system/resources` (`401`/`403` without host admin secret, `503` on `PUT` during shutdown), strict D10 alarm/reminder preservation, and zero silent synthetic GPU telemetry.

---

## 7. Troubleshooting

- **Symptom:** `test_orchestrator_auto_compacts_near_limit_and_injects_digest_in_prompt` failed during initial full backend `pytest` run.
  - **Likely cause:** `MockLLMProvider.get_status()` temporarily pinned `_applied_profile` captured during `load_model()`, ignoring post-load `_active_profile = "eco"` test overrides.
  - **Resolution:** Updated `MockLLMProvider.get_status()` (`backend/app/services/llm/mock.py`) to compute `eff_profile = self._effective_profile_name()`, then re-verified `test_context_compaction.py` + `test_resource_governor.py` + `test_llm.py` (`29 passed`) and the full `935 passed` backend suite.
