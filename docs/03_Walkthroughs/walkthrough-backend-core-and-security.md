# Walkthrough: Backend Core Foundation & API Security Architecture

## 1. What Was Delivered

We bootstrapped the **Local AI Core** backend inside `backend/` from an empty directory to a fully functional, production-ready, and security-hardened FastAPI service backed by SQLite and SQLAlchemy 2.0 (asyncio + `aiosqlite`) with Alembic database migrations.

Key deliverables include:
- **Zero-Configuration Secure Token Pairing:** Generates a 32-byte URL-safe pairing token (`secrets.token_urlsafe(32)`) on initial boot, stored securely in `.env` and logged to the console.
- **OWASP API Security Top 10 Hardened Auth:** Constant-time token verification (`secrets.compare_digest`) via `Authorization: Bearer <token>` or `X-API-Key: <token>`.
- **Mass-Assignment Guard:** All Pydantic v2 schemas reject unexpected payload fields (`extra="forbid"`), preventing property injection attacks.
- **BOLA Protection:** Object-level authorization via `owner_id` scoping across all database queries.
- **Asynchronous SQLite Engine with WAL Mode:** High-concurrency reads and writes (`PRAGMA journal_mode=WAL`, `PRAGMA busy_timeout=5000`).
- **Alembic Database Migration Pipeline:** Initial schema migration (`001_initial_tasks_schema.py`) created and applied with verified rollback.
- **First Vertical Slice (Tasks CRUD + Health):** Complete RESTful endpoints for Health (`/api/v1/health`), System Status (`/api/v1/system/status`), Pairing Verification (`/api/v1/auth/verify`), and Tasks (`/api/v1/tasks`).
- **Automated Test Suite:** 12 automated unit and integration tests passing in 0.22 seconds using `pytest` and `httpx.AsyncClient` against an in-memory SQLite database.
- **Exported Contract:** OpenAPI 3.1 contract exported to `contracts/openapi/openapi.json`.

---

## 2. Files Changed

### Backend Core & Configuration
- [`backend/pyproject.toml`](file:///d:/OtherProjects/AI-companion-project/backend/pyproject.toml): Project metadata, packaging, and dependency definitions.
- [`backend/requirements.txt`](file:///d:/OtherProjects/AI-companion-project/backend/requirements.txt): Pinned backend runtime and development dependencies.
- [`backend/.gitignore`](file:///d:/OtherProjects/AI-companion-project/backend/.gitignore): Security rules protecting `.env`, `.venv`, and `data/*.db`.
- [`backend/.env.example`](file:///d:/OtherProjects/AI-companion-project/backend/.env.example): Sanitized environment template for local configuration.
- [`backend/README.md`](file:///d:/OtherProjects/AI-companion-project/backend/README.md): Quickstart setup, startup, and testing guide.
- [`backend/app/main.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/main.py): FastAPI app factory, lifespan startup, CORS whitelist, tracing middleware, and error handlers.
- [`backend/app/core/config.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/core/config.py): Pydantic Settings, auto-pairing key generation, and CORS parser.
- [`backend/app/core/security.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/core/security.py): Constant-time comparison and `verify_token` dependency.
- [`backend/app/core/errors.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/core/errors.py): Custom exception hierarchy and standardized JSON error envelope.
- [`backend/app/core/logging.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/core/logging.py): Structured console logger with automatic token redaction.

### Database & Models
- [`backend/app/db/session.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/db/session.py): Async SQLAlchemy engine, WAL mode listener, and `get_db` generator.
- [`backend/app/db/base.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/db/base.py): Model aggregator for Alembic schema discovery.
- [`backend/app/models/base.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/models/base.py): Mixins for UUID primary keys, UTC timestamps, and owner isolation.
- [`backend/app/models/task.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/models/task.py): Task SQLAlchemy 2.0 ORM entity.

### Schemas & Endpoints
- [`backend/app/schemas/common.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/schemas/common.py): Strict `BaseSchema` (`extra="forbid"`), error detail models, and envelopes.
- [`backend/app/schemas/health.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/schemas/health.py): Public health response and system telemetry schemas.
- [`backend/app/schemas/auth.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/schemas/auth.py): Pairing token verification schema.
- [`backend/app/schemas/task.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/schemas/task.py): Task request/response models aligned with Android and Web.
- [`backend/app/api/deps.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/api/deps.py): Re-exported dependencies and `get_current_owner`.
- [`backend/app/api/v1/endpoints/health.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/api/v1/endpoints/health.py): Liveness probe and host telemetry endpoints.
- [`backend/app/api/v1/endpoints/auth.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/api/v1/endpoints/auth.py): Token verification endpoint.
- [`backend/app/api/v1/endpoints/tasks.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/api/v1/endpoints/tasks.py): Full CRUD task endpoints with status/priority filtering.
- [`backend/app/api/v1/router.py`](file:///d:/OtherProjects/AI-companion-project/backend/app/api/v1/router.py): V1 router aggregator.

### Migrations & Contracts
- [`backend/alembic.ini`](file:///d:/OtherProjects/AI-companion-project/backend/alembic.ini): Alembic migration configuration.
- [`backend/migrations/env.py`](file:///d:/OtherProjects/AI-companion-project/backend/migrations/env.py): Async SQLite migration runner.
- [`backend/migrations/versions/001_initial_tasks_schema.py`](file:///d:/OtherProjects/AI-companion-project/backend/migrations/versions/001_initial_tasks_schema.py): Initial DDL migration script.
- [`contracts/openapi/openapi.json`](file:///d:/OtherProjects/AI-companion-project/contracts/openapi/openapi.json): Exported OpenAPI 3.1 specification.

### Automated Tests
- [`backend/tests/conftest.py`](file:///d:/OtherProjects/AI-companion-project/backend/tests/conftest.py): In-memory SQLite async fixtures and test client setup.
- [`backend/tests/test_health.py`](file:///d:/OtherProjects/AI-companion-project/backend/tests/test_health.py): Health check and telemetry tests.
- [`backend/tests/test_auth.py`](file:///d:/OtherProjects/AI-companion-project/backend/tests/test_auth.py): Security, header handling, and 401 rejection tests.
- [`backend/tests/test_tasks.py`](file:///d:/OtherProjects/AI-companion-project/backend/tests/test_tasks.py): Tasks CRUD, filtering, and mass-assignment protection tests.

---

## 3. How the Logic Works

```
Incoming Request ──> Tracing Middleware (assign X-Request-ID, strip Server header)
                           │
                           ▼
                    CORS Middleware (check origin whitelist)
                           │
                           ▼
              Route Handler Dependency Check
             /                              \
       Public (/health)             Protected (/tasks, /auth)
            │                               │
            │                  verify_token (compare_digest)
            │                         /           \
            │                     Valid          Invalid ──> 401 Unauthorized
            │                      │
            └───────────┬──────────┘
                        ▼
            Pydantic v2 Schema Validation
           /                              \
       Valid payload                  Forbidden extra field ──> 422 Unprocessable Content
            │
            ▼
     SQLAlchemy 2.0 Async Session (aiosqlite with WAL mode)
            │
            ▼
    Execute Scoped Query (WHERE owner_id == 'local_user')
            │
            ▼
    JSON Response with X-Request-ID & X-Response-Time-Ms
```

1. **Event Trigger:** An HTTP request arrives from the React desktop UI, Android Companion, or interactive Swagger docs.
2. **Validation:**
   - Middleware generates an `X-Request-ID` and strips the server identification header.
   - For protected routes, `verify_token` extracts either `Authorization: Bearer <token>` or `X-API-Key: <token>` and validates it using `secrets.compare_digest`.
   - Pydantic v2 validates request bodies against strict schemas with `extra="forbid"`.
3. **Core Processing:** Route handlers execute asynchronous queries via SQLAlchemy 2.0. Queries automatically inject `WHERE owner_id = :owner_id` to enforce object-level authorization (BOLA defense).
4. **Completion:** Returns formatted JSON payload with execution duration (`X-Response-Time-Ms`) and sanitizes any sensitive token strings before logging to the console.
5. **Recovery/Error Handling:** Any uncaught exception or validation error is intercepted by global exception handlers and converted into a standard error envelope (`error: { code, message, details, request_id }`).

---

## 4. Key Concepts

1. **Constant-Time String Comparison (`secrets.compare_digest`):**
   Standard string comparison (`a == b`) returns `False` as soon as the first non-matching character is found, creating microscopic timing differences that attackers can exploit to guess tokens character by character. Constant-time comparison takes the exact same execution time regardless of where mismatches occur, eliminating timing attack vulnerabilities.
2. **Mass Assignment Vulnerability (OWASP API3):**
   A security flaw where an API endpoint blindly maps incoming JSON fields to database model attributes, allowing attackers to inject privileged fields (e.g., `{"is_admin": true}`). By setting `extra = "forbid"` on all Pydantic schemas, our backend automatically rejects any request containing unapproved fields with HTTP 422.
3. **Write-Ahead Logging (WAL Mode) in SQLite:**
   In standard SQLite journal mode, write operations lock the entire database file, causing concurrent read requests to hang or fail. WAL mode writes changes to a separate log file, allowing simultaneous reads and writes without thread locking or UI stutters.

---

## 5. Verification Steps

### Automated Checks
Run the complete automated test suite from PowerShell:
```pwsh
cd backend
.\.venv\Scripts\python -m pytest tests -v
```
**Result:** 12 passed in 0.22s (100% passing across health, auth rejection, schema validation, and CRUD).

### Manual Verification via Swagger UI
1. Start the server:
   ```pwsh
   cd backend
   .\.venv\Scripts\python -m uvicorn app.main:app --reload --port 8000
   ```
2. Open Microsoft Edge or your browser to:
   ```
   http://127.0.0.1:8000/docs
   ```
3. Test Public Health:
   - Click `GET /api/v1/health` ➔ Click **Try it out** ➔ **Execute**.
   - Confirm status code `200` and `"database_connected": true`.
4. Test Protected Route Rejection:
   - Click `GET /api/v1/tasks` ➔ Click **Try it out** ➔ **Execute**.
   - Confirm status code `401 Unauthorized` with `AUTHENTICATION_REQUIRED`.
5. Authorize with Pairing Token:
   - Click the green **Authorize** button at the top right of the Swagger UI.
   - Enter your token from `backend/.env` (e.g. `companion_sec_...`).
   - Re-run `GET /api/v1/tasks` and verify status code `200` with an empty list `[]`.
6. Create a Task:
   - Click `POST /api/v1/tasks` ➔ Enter `{"title": "Test Task", "priority": "high"}` ➔ **Execute**.
   - Confirm status code `201 Created` with a generated UUID and timestamps.

---

## 6. Safe Customization & Invariants

### Tunable Parameters (`backend/.env`):
- `HOST`: Server bind address (`127.0.0.1` for local-only, `0.0.0.0` for home Wi-Fi access).
- `PORT`: Server port (default `8000`).
- `COMPANION_API_KEY`: Custom secret token string (auto-generated if empty).
- `CORS_ORIGINS`: Comma-separated list of allowed frontend URLs (default `http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000`).

### Invariants (Do Not Break):
- All entity models must inherit `OwnerMixin` and queries must filter by `owner_id`.
- Public endpoints must be explicitly exempted; all others must depend on `verify_token`.
- Pydantic models must retain `extra = "forbid"` to block mass assignment.
- Never log plain credentials, authorization headers, or database passwords.

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
| :--- | :--- | :--- |
| `401 Unauthorized` on `/tasks` or `/system/status` | Missing or mismatched token header | Provide `Authorization: Bearer <token>` or `X-API-Key: <token>` matching `COMPANION_API_KEY` in `backend/.env`. |
| `422 Unprocessable Content` on `POST /tasks` | Unexpected extra field in JSON payload | Remove unmapped fields from JSON body (e.g. `is_admin`, `extra`). Only `title`, `notes`, `priority`, and `due_date` are allowed. |
| `CORS Error` in browser console | Frontend origin not in whitelist | Add your frontend port/origin to `CORS_ORIGINS` in `backend/.env` or `config.py`. |
| Database lock error during high concurrency | SQLite accessed without WAL mode | Verify `PRAGMA journal_mode = WAL;` is executed on connect in `app/db/session.py`. |
