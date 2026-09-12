# Local AI Runtime Backend

The central host runtime of the **AI Companion Project**, built with **Python 3.13, FastAPI, SQLAlchemy 2.0 (asyncio + aiosqlite), Alembic, and SQLite with FTS5**.

---

## Features

- **Asynchronous Architecture:** High-throughput async I/O powered by FastAPI and `aiosqlite`.
- **Zero-Config Token Pairing:** Automatically generates a cryptographically secure 32-byte pairing token on initial startup (`COMPANION_API_KEY`) and saves it to `.env`.
- **OWASP API Security Top 10 Hardened:**
  - **Constant-Time Verification:** Immune to timing attacks via `secrets.compare_digest`.
  - **Mass Assignment Immunity:** All schemas reject unauthorized or unmapped payload fields (`extra = "forbid"`).
  - **BOLA Protection:** All records are explicitly scoped by `owner_id`.
  - **Strict CORS:** Whitelisted development origins (`localhost:5173`, `localhost:3000`, local LAN).
- **SQLite with WAL Mode:** Fast non-blocking concurrent reads and writes with Alembic migration versioning.
- **Interactive Documentation:** Automatic Swagger UI at `http://127.0.0.1:8000/docs` with live request testing and Bearer authorization.
- **Standardized Error Envelopes:** Uniform JSON error responses across all 4xx and 5xx failures.

---

## Getting Started (Windows PowerShell)

### 1. Environment Setup
```pwsh
cd backend
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
```

### 2. Run Database Migrations
```pwsh
.\.venv\Scripts\alembic upgrade head
```

### 3. Start the Server
```pwsh
.\.venv\Scripts\python -m uvicorn app.main:app --reload --port 8000
```
- Open Swagger UI: `http://127.0.0.1:8000/docs`
- Public Health Check: `http://127.0.0.1:8000/api/v1/health`

### 4. Run Automated Tests
```pwsh
.\.venv\Scripts\python -m pytest tests -v
```
