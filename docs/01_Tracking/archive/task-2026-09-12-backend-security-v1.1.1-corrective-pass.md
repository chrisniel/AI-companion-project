# Archived Task: Backend Security V1.1.1 Corrective Pass

- Completed Date: 2026-09-12
- Target: Close 7 security hygiene items in the Local AI Core backend: minimal public /health response, fail-closed router separation, streaming payload size guard, strict CORS origin validation, request ID sanitization, negative security tests, and documentation claim calibration.
- Verification: 22/22 pytest tests passing; 122/122 Android unit tests passing.

## Completed Checklist

### 1. Minimal Public `/health` Response & Diagnostics Boundary
- [x] Reduce public `GET /api/v1/health` response to `{"status": "healthy"}`
- [x] Keep detailed telemetry (`database_connected`, `version`, `timestamp`, etc.) strictly under authenticated `GET /api/v1/system/status`
- [x] Verify Android `HealthDto` parses minimal payload without error

### 2. Fail-Closed Router Architecture
- [x] Refactor `backend/app/api/v1/router.py` into explicit `public_router` and `protected_router`
- [x] Enforce `dependencies=[Depends(verify_token)]` on `protected_router` so all future routes fail closed by default

### 3. Streaming Request-Body Size Enforcement
- [x] Update `PayloadLimitMiddleware` in `backend/app/main.py` to count actual stream bytes
- [x] Immediately reject streaming/chunked requests exceeding 2 MB with HTTP 413, even without `Content-Length` header

### 4. CORS Wildcard Rejection & Scheme Validation
- [x] Add Pydantic validator to `Settings.CORS_ORIGINS` in `backend/app/core/config.py`
- [x] Reject `*` wildcards and reject origins without valid `http://` or `https://` schemes on application startup

### 5. Request ID Sanitization
- [x] Sanitize incoming `X-Request-ID` header against `^[a-zA-Z0-9_-]{1,64}$` in `backend/app/main.py`
- [x] Discard invalid IDs and generate clean fallback `req_<uuid4_hex>`

### 6. Negative Security Tests & Claim Calibration
- [x] Add tests in `backend/tests/test_security_hardening.py` for chunked 413 rejection, wildcard CORS failure, and request ID sanitization
- [x] Update `backend/tests/test_health.py` for minimal public payload
- [x] Run full backend pytest suite and confirm all 22 tests pass
- [x] Calibrate documentation claims in `BACKEND_SECURITY_REVIEW_AND_ROADMAP.md`
