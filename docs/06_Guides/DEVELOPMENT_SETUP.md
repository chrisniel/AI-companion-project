# Development Setup & Local Environment Guide

> **Document Role:** Canonical developer setup and environment configuration guide.  
> **Status:** Active Canonical Guide (PC V1 Frozen Baseline).  
> **Normative Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md), [`windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md), [`ADR-0017`](../04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md).

---

## 1. Prerequisites

Before developing locally, ensure the following prerequisites are installed and available on your system:

| Component | Minimum Version | Notes / Verification |
| :--- | :--- | :--- |
| **Operating System** | Windows 10/11 64-bit | Primary host platform for Local AI Runtime and hardware acceleration. |
| **Python** | 3.11.x 64-bit | Windows x64 CPython 3.11.9 is the qualified dependency target; verify the selected executable below before creating an environment. |
| **Flutter SDK** | Version will be officially pinned when scaffolded (PC-CLIENT-001) | Required for primary Windows Desktop client (`flutter --version`). |
| **Visual Studio Build Tools** | 2022 (with Desktop C++) | Required by Flutter for compiling native Windows C++/CMake executables. |
| **Node.js** | 22.x >= 22.22.2 or 24.x >= 24.15.0 (with npm) | Matches the committed web dependency engines. CI selects 22.22.2 (`node --version`, `npm --version`). |
| **Git & Git LFS** | Latest 64-bit | LFS pointers on GitHub; weights stored on private Hugging Face dataset. |
| **Android Studio** | Ladybug (2024.2+) or JDK 17+ | Required for Android mobile client reference prototype (`android/`). |
| **Vulkan Runtime** | Vulkan SDK / Driver | GPU offloading for AMD Radeon RX 580 (Polaris / gfx803). |

---

## 2. Directory & Architecture Overview

The repository is structured into distinct subsystem trees:

```text
AI-companion-project/
├── backend/            # FastAPI Local AI Runtime (Python 3.11, SQLAlchemy 2, Alembic)
├── frontend/web/       # React 19 Web Client (Supported developer harness and test oracle)
├── android/            # Android Mobile Companion Client (Prototype / reference client)
├── contracts/openapi/  # Canonical OpenAPI contract (openapi.json)
├── models/             # GGUF models & registry templates (Git-tracked templates only; dev sources)
├── runtime/llama.cpp/  # Local llama.cpp binaries (llama-server.exe, Vulkan DLLs; dev sources)
├── scripts/            # Diagnostic, build, and validation scripts
└── docs/               # Numbered documentation hierarchy (00_Drafts through 07_Archive)
```

---

## 3. The Five Storage Roots & Runtime Paths

In accordance with Phase 8P persistent storage architecture, repository directories (`runtime/`, `models/`) are **development sources only**. Active runtime data is partitioned into five canonical storage roots:

1. `APP_INSTALL_ROOT`: Read-only application distribution binaries, bundled engines, and static assets.
2. `DATA_ROOT`: Persistent, profile-isolated SQLite database (`companion.db`), user settings, character avatars, and personal attachments. Defaults to `%LOCALAPPDATA%\AI Companion\Data`.
3. `LIBRARY_ROOT`: Large, relocatable, host-shared assets (GGUF LLM weights, voice models, vision projectors). The target design supports independent relocation; the current bootstrap locator selects `DATA_ROOT` only.
4. `CACHE_ROOT`: Ephemeral working scratchpads, temporary audio buffers, and staging directories. Safe to purge on reboot.
5. `LOG_ROOT`: Structured application logs, crash diagnostics, and rotation archives.

### Resolution Precedence for `DATA_ROOT`
1. **Environment Variable Override:** `COMPANION_DATA_ROOT` (highest precedence, used in CI and isolated testing)
2. **Bootstrap Locator File:** `%LOCALAPPDATA%\AI Companion\bootstrap.json` containing `{"schema_version": 1, "data_root": "<absolute path>"}`
3. **Approved OS Default:** `%LOCALAPPDATA%\AI Companion\Data` on Windows, when the locator is absent on first installation

An existing invalid locator fails closed rather than selecting a different database. Malformed JSON, unsupported schema values, missing fields, and relative roots are rejected. A valid absolute target may not exist yet. An explicit `COMPANION_DATA_ROOT` override takes precedence, including over an invalid locator; no automatic locator repair is performed.

### Key Canonical Subpaths (under `DATA_ROOT` and `LIBRARY_ROOT`)
- `DATABASE_PATH`: `<DATA_ROOT>/database/companion.db` — SQLite persistent database (WAL mode, foreign keys enabled)
- `MODEL_LIBRARY_DIR`: `<LIBRARY_ROOT>/models/llm` — Installed persistent GGUF models
- `INSTALLED_REGISTRY_PATH`: `<LIBRARY_ROOT>/registry/models.json` — Authoritative Model Registry Schema v3
- `VOICE_LIBRARY_DIR`: `<LIBRARY_ROOT>/voices` — Voice models and synthesis profiles
- `ATTACHMENT_DIR`: `<DATA_ROOT>/attachments` — Multimodal image attachments
- `IMPORT_INBOX_DIR`: TARGET PC V1: `<LIBRARY_ROOT>/imports/inbox` (CURRENT implementation: `<DATA_ROOT>/imports/inbox`) — Model import drop inbox (Decision D6)
- `IMPORT_STAGING_DIR`: TARGET PC V1: `<LIBRARY_ROOT>/imports/staging` (CURRENT implementation: `<DATA_ROOT>/imports/staging`) — Preflight validation and quarantine staging (Decision D6)
- `CHARACTER_DIR`: `<DATA_ROOT>/characters` — Character cards and persona definitions
- `BACKUP_DIR`: `<DATA_ROOT>/backups` — Persistent database backup location

---

## 4. Backend Development Startup (FastAPI)

The backend provides the REST, SSE, and WebSocket endpoints for conversation, memory, tasks, models, and runtime orchestration.

### Setup & Startup
From repository root:

```powershell
# 1. Navigate to backend
cd backend

# 2. Locate and verify an already installed Windows x64 CPython 3.11
$pyLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
if (-not $pyLauncher) {
    throw "Python launcher unavailable. Supply an approved Python 3.11 x64 executable before continuing."
}
$python311 = & $pyLauncher.Source -3.11 -I -B -c 'import struct, sys; assert sys.implementation.name == "cpython" and sys.platform == "win32" and sys.version_info[:2] == (3, 11) and struct.calcsize("P") == 8, "Windows x64 CPython 3.11 required"; print(sys.executable)'
if ($LASTEXITCODE -ne 0 -or -not $python311) {
    throw "Windows x64 CPython 3.11 is unavailable. Obtain an approved installation/path; no environment was created."
}
$python311 = ([string]$python311).Trim()
if (-not (Test-Path -LiteralPath $python311 -PathType Leaf)) {
    throw "Selected Python 3.11 executable does not exist."
}

# 3. Create a uniquely owned temporary environment; never target backend/.venv
$qualificationRoot = Join-Path ([IO.Path]::GetTempPath()) ("ai-companion-qualification-" + [guid]::NewGuid().ToString("N"))
if (Test-Path -LiteralPath $qualificationRoot) { throw "Temporary path already exists; refusing reuse." }
New-Item -ItemType Directory -Path $qualificationRoot -ErrorAction Stop | Out-Null
$qualificationEnv = Join-Path $qualificationRoot "venv"
& $python311 -I -B -m venv $qualificationEnv
if ($LASTEXITCODE -ne 0) { throw "Temporary environment creation failed." }
$qualificationPython = Join-Path $qualificationEnv "Scripts/python.exe"
& $qualificationPython -I -B -VV
if ($LASTEXITCODE -ne 0) { throw "Temporary Python executable is unavailable." }

# 4. Remove only the NEW environment's bootstrap setuptools, then install the lock
# The lock includes pinned pip. Existing environments are never modified.
& $qualificationPython -I -B -m pip --isolated uninstall --yes setuptools
if ($LASTEXITCODE -ne 0) { throw "Temporary seed cleanup failed." }
& $qualificationPython -I -B -m pip --isolated install --require-hashes --only-binary=:all: --no-cache-dir --index-url https://pypi.org/simple -r requirements.lock
if ($LASTEXITCODE -ne 0) { throw "Dependency installation failed." }
& $qualificationPython -I -B ../scripts/python_dependency_lock.py verify
if ($LASTEXITCODE -ne 0) { throw "Installed dependency set differs from the qualified lock." }
& $qualificationPython -I -B -m pip check
if ($LASTEXITCODE -ne 0) { throw "Dependency integrity check failed." }

# 5. OPTIONAL normal development startup; this is not a qualification check
# Lifespan prepares the selected development database schema.
& $qualificationPython -B -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

The example preserves every existing `backend/.venv`, regardless of its interpreter, and does not require activation. Keep `$qualificationPython` for the explicit test/contract commands in [TESTING_AND_CI.md](TESTING_AND_CI.md). If the launcher cannot locate Python 3.11, stop and arrange an approved interpreter first; these instructions do not install system Python. An approved explicit executable can replace launcher discovery, but must pass the same version/platform/bitness check before environment creation.

The temporary environment can also support ordinary development during the session. Startup uses the selected development configuration/storage and remains separate from qualification against synthetic state. `backend/requirements.lock` pins the Windows x64 / CPython 3.11 runtime/test closure, requested extras and pip 26.1.2, with one compatible wheel SHA-256 per distribution. Its actual resolution target is CPython 3.11.9; it does not claim Linux, ARM, source-build, packaging/build-system or model-binary coverage. The declarations remain the inputs for deliberate re-resolution, not the normal installation input. Do not freeze existing Python 3.13 environments or infer Python 3.11 qualification from their tests.

If a separate interpreter is approved, the [Python Windows guide](https://docs.python.org/3.11/using/windows.html#the-nuget-org-packages) describes the PSF NuGet distribution suitable for isolated CI tooling. The qualification record used [PSF Python 3.11.9](https://www.nuget.org/packages/python/3.11.9), checked its published SHA-512 and the executable's valid PSF Authenticode signature, and extracted it under an owned temporary directory without registry/system installation. Existing developer interpreters and environments were preserved. Tool provisioning remains subject to the active task's installation authorization.

### Maintaining the Qualified Dependency Input

Use a fresh native Windows x64 CPython 3.11.9 resolver environment with pip 26.1.2 and an empty owned wheel directory. After approved package access, resolve with `pip --isolated download --only-binary=:all: --no-cache-dir --index-url https://pypi.org/simple --dest <wheel-directory> -r backend/requirements.txt`, then download `pip==26.1.2` into the same directory. From repository root run `scripts/python_dependency_lock.py generate --wheelhouse <wheel-directory>` using that resolver's explicit Python executable. The generator checks both declarations, compatible wheel metadata, transitive dependencies and recursive extras before recording artifact hashes. A missing compatible wheel or contradictory declaration is a failure, not permission for an unlocked/source-build fallback.

Review the resulting versions and verify hash-checked installation, exact installed closure and `pip check` in two fresh environments before accepting a lock update. Run guarded F09 isolation before application qualification, then the backend suite and unchanged OpenAPI equality. CI consumes the committed lock and repeats closure checks; a generated file alone is not qualification. See the [active corrective evidence record](../01_Tracking/active/task-fix-pre-m1-audit-corrections.md) for commands and results.

`COMPANION_ENV_FILE` selects an alternate local configuration file; otherwise configuration uses the backend `.env`. Importing configuration does not create or persist a pairing credential. Explicit application startup initializes missing credentials in the selected configuration. Tests and contract verification select disposable configuration and storage before importing the application; see [TESTING_AND_CI.md](TESTING_AND_CI.md).

- **Interactive API Documentation:** `http://127.0.0.1:8000/docs` (Swagger UI; available when `ENVIRONMENT=development`)
- **OpenAPI JSON Specification:** `http://127.0.0.1:8000/openapi.json`
- **Public Health Endpoint:** `http://127.0.0.1:8000/api/v1/health` (unauthenticated liveness probe)

### Standalone Retention

From `backend/`, `& $qualificationPython -B -m app.services.retention --days 30` purges expired soft-deleted Tasks in the selected storage. The CLI initializes and disposes its own database runtime and requires an already prepared, compatible schema. It does not migrate a database during purge. Session-based callers retain ownership of their sessions/runtime. Retention verification uses disposable synthetic databases; periodic scheduling remains future work.

---

## 5. Primary Client Development (Flutter Desktop)

The primary Windows production client is built with Flutter Desktop.

### Setup & Startup
In a separate terminal:

```powershell
# 1. Navigate to desktop client directory
cd [target_flutter_path] # FUTURE/TARGET: Path TBD during PC-CLIENT-001

# 2. Fetch Flutter packages
flutter pub get

# 3. Launch Windows desktop application in debug mode
flutter run -d windows
```

The Flutter desktop app connects to the running local backend at `http://127.0.0.1:8000`.

---

## 6. Supported Developer Harness (React Web)

The React Web client serves as a supported developer test harness and web reference interface.

### Setup & Startup
In a separate terminal:

```powershell
# 1. Navigate to frontend/web
cd frontend/web

# 2. Install dependencies
npm ci

# 3. Start Vite development server
npm run dev
```

- **Local Web UI:** `http://localhost:3000` (or `http://127.0.0.1:3000`)
- Connects to the backend at `http://127.0.0.1:8000`.

---

## 7. Engine Binaries & Hardware Reference

### Reference Hardware Baseline
- **Primary GPU:** AMD Radeon RX 580 (8 GB VRAM, Polaris / gfx803) with Vulkan acceleration.
- **Reference Engine:** `llama.cpp` b10936 Vulkan build.
- **Managed Engine Port:** `8085` (reserved for FastAPI backend router daemon; invoked via `runtime/llama.cpp/llama-server.exe`).
- **Standalone Diagnostic Probe:** Run `.\scripts\start-model.ps1 -GpuLayers 28 -ContextSize 4096` to test GPU layers on isolated port `8086`.

### Speech & Voice Engines (PC V1 Target)
- **Speech-to-Text (STT):** `whisper.cpp` candidate binary managed by runtime for local transcription.
- **Text-to-Speech (TTS):** `Kokoro-82M` candidate model executing on CPU/RAM.

---

## 8. Android Client Development (Prototype / Post-V1)

The Android companion client is maintained in `android/` as a reference prototype:

1. Open `android/` in Android Studio Ladybug or later.
2. Allow Gradle sync to complete using the bundled Gradle wrapper (`gradlew`).
3. Build and test from PowerShell:
   ```powershell
   cd android
   .\gradlew.bat :app:compileDebugKotlin
   .\gradlew.bat :app:testDebugUnitTest
   ```

---

## 9. Verification & Next Steps

After completing local setup, verify your environment using the commands documented in [`docs/06_Guides/TESTING_AND_CI.md`](TESTING_AND_CI.md).
