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
| **Python** | 3.11.x 64-bit | Required for FastAPI backend and migration tools (`python --version`). |
| **Flutter SDK** | Version will be officially pinned when scaffolded (PC-CLIENT-001) | Required for primary Windows Desktop client (`flutter --version`). |
| **Visual Studio Build Tools** | 2022 (with Desktop C++) | Required by Flutter for compiling native Windows C++/CMake executables. |
| **Node.js** | 22.x LTS (with npm) | Required for React Web developer harness (`node --version`, `npm --version`). |
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
3. `LIBRARY_ROOT`: Large, relocatable, host-shared assets (GGUF LLM weights, voice models, vision projectors). May be relocated to a secondary drive (e.g. `D:\AI-Models`) via `bootstrap.json`.
4. `CACHE_ROOT`: Ephemeral working scratchpads, temporary audio buffers, and staging directories. Safe to purge on reboot.
5. `LOG_ROOT`: Structured application logs, crash diagnostics, and rotation archives.

### Resolution Precedence for `DATA_ROOT`
1. **Environment Variable Override:** `COMPANION_DATA_ROOT` (highest precedence, used in CI and isolated testing)
2. **Bootstrap Locator File:** `%LOCALAPPDATA%\AI Companion\bootstrap.json` containing `{"data_root": "...", "library_root": "..."}`
3. **Approved OS Default:** `%LOCALAPPDATA%\AI Companion\Data` on Windows

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

# 2. Create and activate Python virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# 3. Upgrade pip and install dependencies
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

# 4. Start the FastAPI development server (lifespan automatically prepares database schema)
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- **Interactive API Documentation:** `http://127.0.0.1:8000/docs` (Swagger UI; available when `ENVIRONMENT=development`)
- **OpenAPI JSON Specification:** `http://127.0.0.1:8000/openapi.json`
- **Public Health Endpoint:** `http://127.0.0.1:8000/api/v1/health` (unauthenticated liveness probe)

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
npm install

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
