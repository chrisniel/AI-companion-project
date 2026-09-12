# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: In Progress
- Current Sprint: Backend Security V1.1.1 Corrective Pass
- Target: Close 7 security hygiene items in the Local AI Core backend: minimal public /health response, fail-closed router separation, streaming payload size guard, strict CORS origin validation, request ID sanitization, negative security tests, and documentation claim calibration.
- Scope Guard: `backend/`, `docs/`. Preserve Android connectivity (`HealthDto`) and all existing 18 backend tests.

## [CURRENT EXECUTION STATE - IN PROGRESS]

- Active Files:
  - `backend/app/api/v1/endpoints/health.py`
  - `backend/app/api/v1/router.py`
  - `backend/app/core/middleware.py`
  - `backend/app/core/config.py`
  - `backend/tests/test_security_hardening.py`
  - `backend/tests/test_health.py`
  - `docs/02_Planning/plan-backend-security-v1.1.1-corrective-pass.md`
- Current Status: Task file initialized. Ready to apply security hardening updates.
- Next Action: Implement minimal `/health` response and verify Android `HealthDto` compatibility.

## Active Checklist

### 1. Minimal Public `/health` Response & Diagnostics Boundary
- [ ] Reduce public `GET /api/v1/health` response to `{"status": "healthy"}`
- [ ] Keep detailed telemetry (`database_connected`, `version`, `timestamp`, etc.) strictly under authenticated `GET /api/v1/system/status`
- [ ] Verify Android `HealthDto` parses minimal payload without error

### 2. Fail-Closed Router Architecture
- [ ] Refactor `backend/app/api/v1/router.py` into explicit `public_router` and `protected_router`
- [ ] Enforce `dependencies=[Depends(verify_token)]` on `protected_router` so all future routes fail closed by default

### 3. Streaming Request-Body Size Enforcement
- [ ] Update `PayloadLimitMiddleware` in `backend/app/core/middleware.py` to count actual stream bytes
- [ ] Immediately reject streaming/chunked requests exceeding 2 MB with HTTP 413, even without `Content-Length` header

### 4. CORS Wildcard Rejection & Scheme Validation
- [ ] Add Pydantic validator to `Settings.CORS_ORIGINS` in `backend/app/core/config.py`
- [ ] Reject `*` wildcards and reject origins without valid `http://` or `https://` schemes on application startup

### 5. Request ID Sanitization
- [ ] Sanitize incoming `X-Request-ID` header against `^[a-zA-Z0-9_-]{1,64}$` in `backend/app/core/middleware.py`
- [ ] Discard invalid IDs and generate clean fallback `req_<uuid4_hex>`

### 6. Negative Security Tests & Claim Calibration
- [ ] Add tests in `backend/tests/test_security_hardening.py` for chunked 413 rejection, wildcard CORS failure, and request ID sanitization
- [ ] Update `backend/tests/test_health.py` for minimal public payload
- [ ] Run full backend pytest suite and confirm all tests pass
- [ ] Calibrate documentation claims in `BACKEND_SECURITY_REVIEW_AND_ROADMAP.md`
