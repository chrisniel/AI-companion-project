# Local AI Runtime Backend

> **Document Role:** Operational quickstart and subsystem orientation for the FastAPI Local AI Runtime.
> **Status:** Active Operational Quickstart
> **Normative Architecture:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../docs/04_Architecture/SYSTEM_BASELINE.md), [`docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md`](../docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md), and [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md).
> **Canonical Setup Guide:** [`docs/06_Guides/DEVELOPMENT_SETUP.md`](../docs/06_Guides/DEVELOPMENT_SETUP.md).
> **Canonical Verification Guide:** [`docs/06_Guides/TESTING_AND_CI.md`](../docs/06_Guides/TESTING_AND_CI.md).

The central host runtime of the **AI Companion Project**, built with **Python 3.11, FastAPI, SQLAlchemy 2 (asyncio + aiosqlite), Alembic, and SQLite with FTS5**.

---

## Features & Implemented Controls

- **Asynchronous Architecture:** High-throughput async I/O powered by FastAPI and `aiosqlite`.
- **Fail-Closed API Authentication:** Single-shared pairing token (`COMPANION_API_KEY`) verified via constant-time comparison (`secrets.compare_digest`) on protected routes. Automatically generates a 32-byte pairing token on initial startup if unset. Only `/api/v1/health` is unauthenticated.
- **Payload & Injection Defenses:** Enforces maximum request body size (2 MB body limit) on headers and chunks, strict Pydantic payload validation (`extra = "forbid"`), and sanitized request IDs (`X-Request-ID`).
- **Owner-Scoped Data Boundaries:** Records are explicitly scoped by `owner_id` (representing the single user Profile boundary in V1, Decision D8).
- **Environment-Gated Documentation:** Interactive Swagger UI (`/docs`) and OpenAPI spec (`/openapi.json`) are mounted only when `ENVIRONMENT == "development"`.
- **Development CORS Whitelist:** Bounded origin controls for development ports (`localhost:5173`, `localhost:3000`, `127.0.0.1`).
- **Persistent Storage & Schema Preparation:** Canonical database resolves dynamically to `<COMPANION_DATA_ROOT>/database/companion.db` (defaulting on Windows to `%LOCALAPPDATA%\AI Companion\Data\database\companion.db`). On startup, the FastAPI lifespan automatically performs storage preflight and executes schema preparation to Alembic head.
- **Local LLM Process Management:** Manages an independent `llama-server.exe` router daemon on port 8085 with Vulkan GPU offload on AMD RX 580.

For comprehensive security contracts and the 4-tier tool risk matrix, see [`docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md`](../docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md).

---

## Quickstart (Windows PowerShell)

For complete environment setup, prerequisites, and configuration options, consult [`docs/06_Guides/DEVELOPMENT_SETUP.md`](../docs/06_Guides/DEVELOPMENT_SETUP.md).

### 1. Virtual Environment & Dependencies
```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### 2. Start the Server
```powershell
.\.venv\Scripts\python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
- **Public Health Probe:** `http://127.0.0.1:8000/api/v1/health`
- **Swagger Documentation:** `http://127.0.0.1:8000/docs` (available in development mode)

> [!NOTE]
> Server startup automatically prepares the database schema at the canonical storage location. Running `alembic upgrade head` manually is an explicit developer operation used when authoring or verifying new schema revisions.

### 3. Run Automated Tests
```powershell
python -m pytest tests -v
```

For testing standards and OpenAPI drift verification commands, see [`docs/06_Guides/TESTING_AND_CI.md`](../docs/06_Guides/TESTING_AND_CI.md).
