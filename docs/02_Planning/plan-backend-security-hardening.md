# Implementation Plan: Backend Security Hardening V1.1

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Primary Skill: `security-audit`
Supporting Skills: `api-contract-review`, `error-handling`, `test-creation`

---

## 1. Executive Summary & Problem Context

Following the architectural review in `LOCAL_AI_CORE_BACKEND_SECURITY_OVERVIEW.md`, the Local AI Runtime foundation is confirmed as the correct architecture. However, before exposing the runtime to local network clients (Android Companion) or remote nodes, a focused Security Hardening pass is required to address:
1. Secret leakage: The raw pairing token was logged to stdout on startup (`main.py`).
2. Route exposure risk: Authentication was attached to individual routes rather than enforced as default-deny across the API.
3. Overly broad CORS: Allowed methods and headers were wildcards (`*`).
4. Ungated documentation: Swagger UI (`/docs`) and OpenAPI spec were unconditionally public.
5. Unbounded request bodies: No size limit existed on incoming HTTP payloads.
6. Public health information leakage: `/api/v1/health` exposed database connection state and internal timestamps.

---

## 2. Proposed Changes & Implementation Strategy

### 2.1 Secret & Logging Hygiene
- In `backend/app/main.py`:
  - Eliminate `logger.info(f"Pairing Token (keep secret): {token}")`.
  - Log only:
    ```text
    Pairing credential verified successfully.
    Credential stored in backend/.env.
    ```

### 2.2 Default-Deny Route Security
- In `backend/app/api/v1/router.py`:
  - Mount public endpoints (`/health`) without auth dependencies.
  - Mount all other sub-routers (`/system`, `/auth`, `/tasks`, and any future routes) with `dependencies=[Depends(verify_token)]` at the sub-router inclusion level.
  - This ensures any new route added to `/tasks` or new feature routers is protected by default.

### 2.3 CORS Hardening
- In `backend/app/main.py`:
  - `allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"]`
  - `allow_headers=["Authorization", "Content-Type", "X-API-Key", "X-Request-ID"]`
  - `allow_credentials=True` with explicit origins only (no wildcards).

### 2.4 Environment Gated Documentation
- In `backend/app/core/config.py`:
  - Add `ENVIRONMENT: str = "development"`.
- In `backend/app/main.py`:
  - `docs_url="/docs" if settings.ENVIRONMENT == "development" else None`
  - `redoc_url=None`
  - `openapi_url="/openapi.json" if settings.ENVIRONMENT == "development" else None`

### 2.5 Request Body Size Limiting Middleware
- In `backend/app/main.py`:
  - Add `PayloadLimitMiddleware`: checks `Content-Length` header. If `Content-Length > 2 * 1024 * 1024` (2 MB), immediately returns HTTP `413 Request Entity Too Large` using standard error envelope.

### 2.6 Minimal Public Health Endpoint
- In `backend/app/schemas/health.py` and `backend/app/api/v1/endpoints/health.py`:
  - Return `{ "status": "healthy" }` (or `"degraded"` if DB check fails) without leaking internal Python/DB details to unauthenticated probes.

---

## 3. Verification Plan

### Automated Pytest Suite
- Run `pytest -v` in `backend/`:
  - Test payload limit middleware (>2 MB payload rejected with 413).
  - Test default-deny: unauthenticated call to `/api/v1/tasks` returns 401.
  - Test public health check returns 200 with `{ "status": "healthy" }`.
  - Test CORS headers only allow permitted methods.
  - Test all 12 existing tests continue to pass.
