# Backend Core Foundation & API Security Implementation Plan (Multi-Skill Enterprise Edition)

**Routing Framework:** [`skill-router-execution-planner`](file:///C:/Users/Admin/.gemini/config/skills/skill-router-execution-planner/SKILL.md)  
**Primary Execution Skill:** [`feature-implementation`](file:///C:/Users/Admin/.gemini/config/skills/feature-implementation/SKILL.md)  
**Domain & Security Skills:** [`api-endpoint-builder`](file:///C:/Users/Admin/.gemini/config/skills/api-endpoint-builder/SKILL.md), [`authentication-flow`](file:///C:/Users/Admin/.gemini/config/skills/authentication-flow/SKILL.md), [`security-audit`](file:///C:/Users/Admin/.gemini/config/skills/security-audit/SKILL.md), [`migration-safety-review`](file:///C:/Users/Admin/.gemini/config/skills/migration-safety-review/SKILL.md), [`api-contract-review`](file:///C:/Users/Admin/.gemini/config/skills/api-contract-review/SKILL.md)  
**Quality & Reliability Skills:** [`acceptance-criteria`](file:///C:/Users/Admin/.gemini/config/skills/acceptance-criteria/SKILL.md), [`error-handling`](file:///C:/Users/Admin/.gemini/config/skills/error-handling/SKILL.md), [`logging-and-observability`](file:///C:/Users/Admin/.gemini/config/skills/logging-and-observability/SKILL.md), [`test-creation`](file:///C:/Users/Admin/.gemini/config/skills/test-creation/SKILL.md), [`project-documentation`](file:///C:/Users/Admin/.gemini/config/skills/project-documentation/SKILL.md)

---

## 1. Skill Inventory Review & Routing Decision

Following our scan of `C:\Users\Admin\.gemini\config\skills\` (46 specialized skills discovered), we selected the optimal multi-skill sequence for bootstrapping the Local AI Core:

| Skill | Role in Backend Bootstrap | Key Contribution |
| :--- | :--- | :--- |
| **`feature-implementation`** | **Primary Skill** | Orchestrates the multi-layered scaffolding (`backend/` structure, virtualenv, dependencies, core services, lifespan). |
| **`api-endpoint-builder`** | Supporting (API) | Designs and implements clean, RESTful endpoints (`/health`, `/auth/verify`, `/tasks` CRUD) with scoped DB access. |
| **`authentication-flow`** | Supporting (Security) | Establishes zero-configuration 32-byte pairing token, constant-time validation (`compare_digest`), and header extraction. |
| **`security-audit`** | Supporting (Security) | Enforces OWASP API Top 10 defenses: BOLA owner-scoping, mass-assignment guards, CORS whitelisting, and secret redaction. |
| **`migration-safety-review`** | Supporting (Database) | Pre-screens Alembic migrations for backward compatibility, safe schema generation, and transactional rollbacks. |
| **`api-contract-review`** | Supporting (Integration)| Aligns Task and Connection response models with Android's `TasksRepository` and React Web's `types.ts`. |
| **`acceptance-criteria`** | Supporting (Requirements)| Formalizes observable, pass/fail acceptance criteria (AC-1 to AC-10) before writing code. |
| **`error-handling`** | Supporting (Resilience) | Standardizes the JSON error envelope (`error: { code, message, details, request_id }`) and status codes (400, 401, 403, 404, 422, 500). |
| **`logging-and-observability`** | Supporting (Telemetry) | Configures structured logging with unique `request_id` correlation, request duration timing, and token masking. |
| **`test-creation`** | Supporting (Verification)| Implements automated `pytest` suite testing auth rejection, schema validation, and database CRUD. |
| **`project-documentation`** | Supporting (Handoff) | Automatically exports verified OpenAPI contracts to `contracts/openapi/openapi.json` and documents setup. |

---

## 2. Observable Acceptance Criteria ([`acceptance-criteria`](file:///C:/Users/Admin/.gemini/config/skills/acceptance-criteria/SKILL.md))

- **AC-1 (Scaffolding & Environment):** The `backend/` directory initializes with Python 3.13 virtual environment (`backend/.venv`), pinned dependencies (`requirements.txt`), and structured application package.
- **AC-2 (Zero-Configuration Secure Pairing - `authentication-flow`):** On initial launch without a configured secret, the core generates a cryptographically secure 32-byte URL-safe pairing token (`secrets.token_urlsafe(32)`), logs it to the console, and writes it to `.env`.
- **AC-3 (Constant-Time Token Verification - `security-audit`):** All API routes under `/api/v1/`—except public `/api/v1/health` and dev `/docs`—require a valid pairing token via `Authorization: Bearer <token>` or `X-API-Key: <token>`. Validation uses constant-time string comparison (`secrets.compare_digest`). Missing or invalid tokens return HTTP 401 with standard error envelope.
- **AC-4 (Mass Assignment Guard - `security-audit` & `api-endpoint-builder`):** All incoming JSON bodies are validated using strict Pydantic v2 schemas configured with `model_config = ConfigDict(extra="forbid")`. Any request containing unregistered fields is rejected with HTTP 422.
- **AC-5 (CORS Security Misconfiguration - `security-audit`):** CORS middleware strictly allows only explicitly whitelisted origins (`http://localhost:5173`, `http://127.0.0.1:5173`, `http://localhost:3000`, and local network host IPs). Wildcard `*` with credentials is explicitly forbidden.
- **AC-6 (Standardized Error Envelope - `error-handling`):** All exceptions, client errors (4xx), and server errors (5xx) return a consistent JSON schema:
  ```json
  {
    "error": {
      "code": "AUTHENTICATION_REQUIRED",
      "message": "Valid pairing token is required.",
      "details": null,
      "request_id": "req_01j7..."
    }
  }
  ```
  Internal database errors or raw stack traces are never exposed to clients.
- **AC-7 (Structured Logging & Redaction - `logging-and-observability`):** Structured logs record `request_id`, method, path, status, and duration_ms. Tokens, passwords, and sensitive headers are strictly masked/redacted.
- **AC-8 (Async Database & Safe Migrations - `migration-safety-review`):** SQLite database engine operates asynchronously using `aiosqlite` and SQLAlchemy 2.0. Migrations are managed by Alembic in `backend/migrations/`. Applying migrations creates the initial `tasks` schema with timestamp and UUID mixins.
- **AC-9 (First Vertical Slice: Tasks CRUD - `api-endpoint-builder` & `api-contract-review`):** Full lifecycle of a Task (`create`, `read`, `list` with status filtering, `partial update`, `delete`) functions over async SQLAlchemy, enforcing `owner_id` scoping (OWASP API1) and matching Android/Web model contracts.
- **AC-10 (Automated Test Suite Pass - `test-creation`):** `pytest backend/tests` executes automatically against an in-memory SQLite fixture, validating 100% passing tests across health, auth rejection, schema validation, and Task CRUD.

---

## 3. Database Migration Safety Review ([`migration-safety-review`](file:///C:/Users/Admin/.gemini/config/skills/migration-safety-review/SKILL.md))

- **Migration Scope:** Initial schema creation (`001_initial_tasks_schema.py`) targeting `backend/data/companion.db`.
- **Destructive Change Check:** Zero destructive changes; additive table creation only (`tasks`).
- **Backward Compatibility:** Single-user owner boundary (`owner_id = 'local_user'`) included from day one, allowing seamless future transition to multi-profile companions without breaking schema.
- **SQLite Locking & Concurrency:** Configured with WAL mode (`PRAGMA journal_mode=WAL;`) and a busy timeout of 5000ms in `db/session.py` to prevent database locking during concurrent async reads/writes.
- **Rollback Verification:** Migration script contains a verified `downgrade()` function dropping the created table cleanly.

---

## 4. API Contract Alignment ([`api-contract-review`](file:///C:/Users/Admin/.gemini/config/skills/api-contract-review/SKILL.md))

### Field Alignment Matrix:

| Field Name | Backend Schema (`TaskResponse`) | Android Model (`TaskItem`) | React Web (`Task`) | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ID** | `id: str` (UUID) | `id: String` | `id: string` | ✅ Aligned |
| **Title** | `title: str` (1–255 chars) | `title: String` | `title: string` | ✅ Aligned |
| **Notes** | `notes: Optional[str]` | `notes: String?` | `notes?: string` | ✅ Aligned |
| **Status** | `status: TaskStatus` (`pending`, `in_progress`, `completed`, `cancelled`) | `status: TaskStatus` | `status: string` | ✅ Aligned |
| **Priority** | `priority: TaskPriority` (`low`, `medium`, `high`, `urgent`) | `priority: TaskPriority` | `priority?: string` | ✅ Aligned |
| **Due Date** | `due_date: Optional[datetime]` (ISO-8601 UTC) | `dueDate: String?` (ISO-8601) | `dueDate?: string` | ✅ Aligned |
| **Created At** | `created_at: datetime` (ISO-8601 UTC) | `createdAt: Long` / ISO | `createdAt?: string` | ✅ Aligned |

---

## 5. Security Audit Guardrails ([`security-audit`](file:///C:/Users/Admin/.gemini/config/skills/security-audit/SKILL.md) & [`authentication-flow`](file:///C:/Users/Admin/.gemini/config/skills/authentication-flow/SKILL.md))

1. **Secret Management:** `.env` is listed in `.gitignore`. `.env.example` provides placeholder values only (`COMPANION_API_KEY=your-32-byte-token-here`).
2. **Timing Attack Immunity:** `core/security.py` uses `hmac.compare_digest(provided_token, expected_token)` rather than string `==`.
3. **Mass-Assignment Immunity:** All input schemas enforce `extra = "forbid"` via Pydantic v2 `ConfigDict`.
4. **Header Obfuscation:** The `Server: uvicorn` response header is stripped by custom middleware.
5. **CORS Safeguard:** Wildcard origins are rejected when credentials (`allow_credentials=True`) are enabled.

---

## 6. Directory Layout & Layer Architecture

```text
backend/
├── app/
│   ├── api/
│   │   ├── v1/
│   │   │   ├── endpoints/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── health.py        # GET /api/v1/health (public), GET /api/v1/system/status (auth)
│   │   │   │   ├── auth.py          # POST /api/v1/auth/verify (auth)
│   │   │   │   └── tasks.py         # Full CRUD /api/v1/tasks (auth, api-endpoint-builder)
│   │   │   ├── __init__.py
│   │   │   └── router.py            # Aggregated v1 API router
│   │   ├── __init__.py
│   │   └── deps.py                  # Database session & security token dependencies
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py                # Pydantic v2 Settings (Host, Port, Token, CORS, DB)
│   │   ├── security.py              # secrets.compare_digest, token verification (authentication-flow)
│   │   ├── errors.py                # Standard error response envelope & custom exceptions (error-handling)
│   │   └── logging.py               # Structured logging with request_id tracking (logging-and-observability)
│   ├── db/
│   │   ├── __init__.py
│   │   ├── session.py               # Async engine (aiosqlite, WAL mode), async_sessionmaker, Base
│   │   └── base.py                  # Model aggregator for Alembic discovery
│   ├── models/
│   │   ├── __init__.py
│   │   ├── base.py                  # UUIDPrimaryKeyMixin, TimestampMixin
│   │   └── task.py                  # Task SQLAlchemy 2.0 ORM model
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── common.py                # ErrorResponse, SuccessEnvelope
│   │   ├── health.py                # HealthResponse, SystemStatusResponse
│   │   ├── auth.py                  # AuthVerifyResponse
│   │   └── task.py                  # TaskCreate, TaskUpdate, TaskResponse (extra="forbid")
│   ├── __init__.py
│   └── main.py                      # FastAPI factory, lifespan, CORS, error middleware
├── data/                            # Persistent SQLite database folder (.gitignore)
├── migrations/                      # Alembic migrations directory (migration-safety-review)
│   ├── versions/
│   ├── env.py
│   └── script.py.mako
├── tests/                           # Automated test suite (test-creation)
│   ├── __init__.py
│   ├── conftest.py                  # In-memory SQLite async engine, httpx.AsyncClient fixture
│   ├── test_health.py               # Health & system endpoint tests
│   ├── test_auth.py                 # Security: 401 rejection, 200 acceptance, constant-time check
│   └── test_tasks.py                # Task CRUD, filtering, 422 mass-assignment prevention
├── alembic.ini
├── pyproject.toml
└── requirements.txt
```

---

## 7. Automated Test Plan ([`test-creation`](file:///C:/Users/Admin/.gemini/config/skills/test-creation/SKILL.md))

### Verification Commands:
```pwsh
# Run the complete test suite
backend/.venv/Scripts/python -m pytest backend/tests -v --tb=short

# Run security and auth tests only
backend/.venv/Scripts/python -m pytest backend/tests/test_auth.py -v

# Run Task CRUD and database lifecycle tests only
backend/.venv/Scripts/python -m pytest backend/tests/test_tasks.py -v
```

### Coverage Goals:
- 100% route coverage across `/api/v1/health`, `/api/v1/system/status`, `/api/v1/auth/verify`, and `/api/v1/tasks`.
- 100% coverage on authentication error cases (missing header, malformed header, invalid token string).
- 100% coverage on schema extra-field rejection (OWASP API3 mass-assignment test).
