# Development Setup & Local Environment Guide

> **Document Role:** Canonical developer setup and environment configuration guide.
> **Status:** Active Canonical Guide
> **Last Updated:** 2026-09-21 (Reconciliation Pass R4)

---

## 1. Prerequisites

Before developing locally, ensure the following prerequisites are installed and available on your system:

| Component | Minimum Version | Notes / Verification |
| :--- | :--- | :--- |
| **Operating System** | Windows 10/11 64-bit | Primary host platform for Local AI Runtime and hardware acceleration. |
| **Python** | 3.11.x 64-bit | Required for FastAPI backend and migration tools (`python --version`). |
| **Node.js** | 22.x LTS (with npm) | Required for React Web client (`node --version`, `npm --version`). |
| **Git & Git LFS** | Latest 64-bit | LFS pointers point to GitHub; weights stored on Hugging Face dataset. |
| **Android Studio** | Ladybug (2024.2+) or JDK 17+ | Required for Android mobile client development (`android/`). |
| **Vulkan Runtime** | Vulkan SDK / Driver | GPU offloading for AMD Radeon RX 580 (Polaris / gfx803). |

---

## 2. Directory & Architecture Overview

The repository is structured into distinct subsystem trees:

```text
AI-companion-project/
├── backend/            # FastAPI Local AI Runtime (Python 3.11, SQLAlchemy 2, Alembic)
├── frontend/web/       # React 19 Web Desktop Client (Vite 6, Tailwind CSS 4, Vitest)
├── android/            # Android Mobile Companion Client (Kotlin, Jetpack Compose)
├── contracts/openapi/  # Canonical OpenAPI contract (openapi.json)
├── models/             # GGUF models & registry templates (Git-tracked templates only)
├── runtime/llama.cpp/  # Local llama.cpp binaries (llama-server.exe, Vulkan DLLs)
├── scripts/            # Diagnostic & validation scripts
└── docs/               # Canonical architecture, roadmap, tracking, guides
```

For canonical system boundaries, host topology, and locked architectural decisions D1–D9, refer to [SYSTEM_BASELINE.md](../04_Architecture/SYSTEM_BASELINE.md).

---

## 3. Persistent Storage & Configuration

The Local AI Runtime separates repository code from mutable user data and model weights using a canonical storage root:

### Resolution Precedence
1. **Environment Variable Override:** `COMPANION_DATA_ROOT` (highest precedence, used in CI and isolated testing)
2. **Bootstrap Locator File:** `%LOCALAPPDATA%\AI Companion\bootstrap.json` on Windows (`~/.local/share/AI Companion/bootstrap.json` on Linux/macOS) containing `{"data_root": "..."}`
3. **Approved OS Default:** `%LOCALAPPDATA%\AI Companion\Data` on Windows (`~/.local/share/AI Companion/Data` on Linux/macOS)

### Canonical Storage Paths
All persistent asset paths derive deterministically from the resolved `COMPANION_DATA_ROOT` (directory creation is lazy where appropriate):
- `DATABASE_PATH`: `<COMPANION_DATA_ROOT>/database/companion.db` — SQLite persistent database (WAL mode, foreign keys enabled)
- `LIBRARY_DIR`: `<COMPANION_DATA_ROOT>/library` — Base user library directory
- `MODEL_LIBRARY_DIR`: `<COMPANION_DATA_ROOT>/library/models/llm` — Installed persistent GGUF models
- `INSTALLED_REGISTRY_PATH`: `<COMPANION_DATA_ROOT>/library/registry/models.json` — Authoritative Model Registry Schema v3
- `VOICE_LIBRARY_DIR`: `<COMPANION_DATA_ROOT>/library/voices` — Voice models and synthesis profiles (post-V1)
- `ATTACHMENT_DIR`: `<COMPANION_DATA_ROOT>/attachments` — Persisted multimodal image attachments (Phase 8B)
- `IMPORT_INBOX_DIR`: `<COMPANION_DATA_ROOT>/imports/inbox` — Model import drop inbox (Decision D6)
- `IMPORT_STAGING_DIR`: `<COMPANION_DATA_ROOT>/imports/staging` — Preflight validation and quarantine staging (Decision D6)
- `CHARACTER_DIR`: `<COMPANION_DATA_ROOT>/characters` — Character cards and persona definitions
- `MEMORY_DIR`: `<COMPANION_DATA_ROOT>/memory` — Profile and memory exports
- `BACKUP_DIR`: `<COMPANION_DATA_ROOT>/backups` — Persistent database backup location; currently used by verified legacy database migration backup flow

### Key Environment Variables
Create a `backend/.env` file or export environment variables as needed:

```bash
# Security: Master API key for administrative routes (fail-closed if unset in production)
COMPANION_API_KEY=your-local-dev-api-key

# Storage override (optional; defaults to %LOCALAPPDATA%\AI Companion\Data)
COMPANION_DATA_ROOT=D:\AICompanionData

# Hardware offload settings (defaults to vulkan on RX 580)
LLM_ENGINE=llama_cpp
LLM_ACCELERATION=vulkan
```

---

## 4. Backend Development Startup (FastAPI)

The backend provides the REST and SSE streaming endpoints for conversation, memory, tasks, models, and runtime orchestration.

### Setup & Startup
From the repository root:

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

> [!NOTE]
> **Automatic Schema Preparation:** The FastAPI application lifespan automatically runs storage preflight and executes schema preparation to ensure the canonical database is at the current Alembic revision head upon server startup. Explicitly running `alembic upgrade head` is an optional developer command useful when authoring or verifying new migrations.

- **Interactive API Documentation:** `http://127.0.0.1:8000/docs` (Swagger UI; available when `ENVIRONMENT=development`)
- **OpenAPI JSON Specification:** `http://127.0.0.1:8000/openapi.json`
- **Public Health Endpoint:** `http://127.0.0.1:8000/api/v1/health` (unauthenticated liveness probe)
- **Protected System Status:** `http://127.0.0.1:8000/api/v1/system/status` (requires `COMPANION_API_KEY`)

---

## 5. Frontend Development Startup (React Web)

The primary desktop client is a React 19 single-page application built with Vite 6 and Tailwind CSS 4.

### Setup & Startup
In a separate terminal:

```powershell
# 1. Navigate to frontend/web
cd frontend/web

# 2. Install dependencies (commit package-lock.json; never commit node_modules)
npm install

# 3. Start Vite development server
npm run dev
```

- **Local Web UI:** `http://localhost:3000` (or `http://127.0.0.1:3000`)
- The web application connects to the backend at `http://127.0.0.1:8000`.

---

## 6. Local AI Runtime & llama.cpp Relationship

### Production Runtime Daemon (Port 8085)
The backend manages an independent `llama-server.exe` instance in multi-model router mode on port **`8085`**:
- **Managed Port:** `8085` (reserved for FastAPI backend router daemon)
- **Binary Path:** `runtime/llama.cpp/llama-server.exe`
- **GPU Acceleration:** Vulkan offload on AMD Radeon RX 580
- **Profiles (Configured in `backend/app/core/config.py`):**
  - `eco`: context = 2048, GPU layers = 0, threads = 4, mmproj offload = false
  - `balanced`: context = 4096, GPU layers = 28, threads = 6, mmproj offload = true
  - `maximum`: context = 8192, GPU layers = 33, threads = 8, mmproj offload = true

For full runtime details, see [LLAMA_CPP_RUNTIME_ARCHITECTURE.md](../04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md).

### Standalone Diagnostic Router Probe (Port 8086)
For benchmarking or verifying GPU layers without starting the full FastAPI backend, run the diagnostic script:

```powershell
# Runs standalone llama-server on port 8086 (isolated from production port 8085)
.\scripts\start-model.ps1 -GpuLayers 28 -ContextSize 4096
```

---

## 7. Android Mobile Client Development (Post-V1)

The Android companion client is maintained in `android/`:

> [!NOTE]
> **Android Package Identity Reality:**
> The current mobile prototype code still uses legacy/template identifiers (`namespace = "com.example"`, `applicationId = "com.aistudio.localcore.swbjtu"` in `android/app/build.gradle.kts`).
> The locked production target under Decision D3 is `com.cnl.aicompanion`. This package rename refactor is planned and must occur before production Android data persistence, Keystore signing, Health Connect permissions, or app distribution depend on the package identity.

1. Open `android/` in Android Studio Ladybug or later.
2. Allow Gradle sync to complete using the bundled Gradle wrapper (`gradlew`).
3. Build and test from PowerShell:
   ```powershell
   cd android
   .\gradlew.bat :app:compileDebugKotlin
   .\gradlew.bat :app:testDebugUnitTest
   ```

> [!IMPORTANT]
> **Implementation vs. Target Reality:**
> - **Prototype Connection (Implemented):** The current Android app includes a functional prototype connection layer (`LocalAiRuntimeClient`) supporting health probes, token verification, and live two-way personal task synchronization (`HttpTasksRepository`) over local Wi-Fi or Tailscale.
> - **Production Synchronization (Post-V1):** Production-hardened multi-device sync, secure Keystore credentials (Decision D4), full state sync (conversations/memory/profile), and durable Room offline queuing are strategic post-V1 roadmap capabilities.
> - **Offline Mobile Inference (Post-V1):** Local on-device GGUF inference and autonomous offline routines are post-V1 capabilities. In V1, the primary client is the PC React Web application.

---

## 8. Verification & Next Steps

After completing local setup, verify your environment using the commands documented in [docs/06_Guides/TESTING_AND_CI.md](TESTING_AND_CI.md).
