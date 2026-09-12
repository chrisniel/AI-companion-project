# Walkthrough: Backend Security V1.1.1 Corrective Pass

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Delivery of the 7 security hygiene and hardening items completing the Phase 1.1 security baseline for the Local AI Core backend.
- Audience: Developer, maintainer, QA, pairing client integrators
- Status: Implemented & Verified
- Last Updated: 2026-09-12

---

## 1. What Was Delivered

- **Minimal Public `/health` Endpoint**: Public `GET /api/v1/health` now returns strictly `{"status": "healthy"}` without leaking internal telemetry, database connection checks, or backend versions. Detailed system diagnostics (`database_connected`, `version`, `timestamp`) are moved exclusively to the authenticated `GET /api/v1/system/status` endpoint. Android's `HealthDto` remains 100% compatible.
- **Fail-Closed Router Separation**: Partitioned `backend/app/api/v1/router.py` into distinct `public_router` and `protected_router`. The `protected_router` enforces `dependencies=[Depends(verify_token)]`, ensuring all future feature routes fail closed by default.
- **Dual-Layer Request Payload Size Protection (HTTP 413)**: Enhanced `PayloadLimitMiddleware` with an ASGI stream byte counter that intercepts and terminates streaming or chunked request payloads exceeding 2 MB (`settings.MAX_REQUEST_BODY_BYTES`) with HTTP 413 `PAYLOAD_TOO_LARGE`, even when the `Content-Length` header is absent.
- **CORS Wildcard Rejection & Scheme Validation**: Added Pydantic configuration validation in `backend/app/core/config.py` rejecting wildcard `*` origins and schemeless origins with `ValueError` at application startup.
- **Request ID Sanitization**: Hardened `SecurityAndTracingMiddleware` with regex validation (`^[a-zA-Z0-9_-]{1,64}$`), discarding malicious or oversized `X-Request-ID` headers and safely generating `req_<uuid4_hex>` server identifiers.
- **Expanded Negative Security Verification**: Added comprehensive negative security tests in `test_security_hardening.py` covering chunked 413 rejection, CORS origin validation, request ID sanitization, and fail-closed router inspection. All 22 backend tests and all 122 Android unit tests pass cleanly.
- **Calibrated Documentation**: Updated `BACKEND_SECURITY_REVIEW_AND_ROADMAP.md` reflecting completed V1.1.1 baseline freeze and accurate local threat boundaries.

## 2. Files Changed

- `backend/app/schemas/health.py` — Reduced `HealthResponse` schema to minimal `status: str = "healthy"`; introduced `SystemStatusResponse` for authenticated diagnostics.
- `backend/app/api/v1/endpoints/health.py` — Split into `public_health_router` (`/health`) and authenticated `system_router` (`/system/status`).
- `backend/app/api/v1/router.py` — Restructured into `public_router` and fail-closed `protected_router`.
- `backend/app/core/config.py` — Added `assemble_cors_origins` validator rejecting `*` and schemeless origins.
- `backend/app/core/errors.py` — Added `CompanionPayloadTooLargeError(status_code=413, code="PAYLOAD_TOO_LARGE")`.
- `backend/app/main.py` — Added request ID regex sanitization, ASGI stream byte counter in `PayloadLimitMiddleware`, and Starlette `HTTPException` handler mapping stream overflow to HTTP 413.
- `backend/tests/test_health.py` — Updated tests to verify minimal `/health` response and authenticated `/system/status`.
- `backend/tests/test_security_hardening.py` — Added negative security tests for streaming payload overflow, CORS wildcard rejection, request ID sanitization, and router isolation.
- `docs/04_Architecture/BACKEND_SECURITY_REVIEW_AND_ROADMAP.md` — Updated executive summary recording completion of V1.1.1 corrective pass.
- `CHANGELOG.md` — Appended Pass 4 entry documenting delivered security capabilities under `## Unreleased`.

## 3. How the Logic Works

1. **Event trigger**: An incoming HTTP request reaches the Uvicorn ASGI server.
2. **Validation (Security Middleware)**:
   - `SecurityAndTracingMiddleware` checks `X-Request-ID` against `^[a-zA-Z0-9_-]{1,64}$`. If invalid or absent, it assigns a safe `req_<hex>`.
   - `PayloadLimitMiddleware` checks `Content-Length`. If > 2 MB, it returns 413 immediately.
   - For chunked/streaming requests, `streaming_counter_receive` monitors ASGI `http.request` body chunks. If accumulated bytes exceed 2 MB, it flags `request.state.stream_bytes_exceeded = True` and terminates with `CompanionPayloadTooLargeError`.
3. **Core processing (Routing & Auth)**:
   - If the path is under `public_router` (`GET /api/v1/health`), it processes without authentication and returns `{"status": "healthy"}`.
   - If under `protected_router` (`/tasks`, `/system/status`, `/auth`), `Depends(verify_token)` validates the Bearer token or pairing secret against `COMPANION_API_KEY`.
4. **Completion**: Response is dispatched with sanitized `X-Request-ID` header, stripped server identifiers, and standard JSON envelope.
5. **Recovery/cancellation**: If an unhandled exception or payload overflow occurs, `@app.exception_handler` intercepts the event, logs without credential leakage, and emits a standard `format_error_response` with appropriate status code (413, 401, 404, or 500).

## 4. Key Concepts

- **Fail-Closed Architecture**: A security design principle where a system defaults to access denial unless explicitly permitted. New endpoints included in `protected_router` are automatically secured by default.
- **ASGI Stream Counting**: Measuring actual incoming payload bytes incrementally at the protocol layer rather than trusting client-reported headers (`Content-Length`), preventing denial-of-service via slow-loris or oversized chunked uploads.
- **Identifier Sanitization**: Enforcing strict alphanumeric whitelisting on user-controllable tracking headers (`X-Request-ID`) to block log injection, carriage-return header manipulation, and path traversal vectors.

## 5. Verification Steps

### Automated Checks

- [x] Backend Test Suite: `.\.venv\Scripts\python -m pytest` in `backend/` — 22/22 passed in 0.35s.
- [x] Android Unit Test Suite: `.\gradlew.bat testDebugUnitTest` in `android/` — 122/122 passed.
- [x] CORS Wildcard Startup Assertion: `Settings(CORS_ORIGINS="*")` raises `ValidationError`.
- [x] Streaming Byte Limit Assertion: Chunked upload exceeding 2 MB returns HTTP 413 `PAYLOAD_TOO_LARGE`.
- [x] Public Health Schema Assertion: `GET /api/v1/health` contains only `{"status": "healthy"}`.

### Manual / User-Owned Checks

- [ ] Step 1: Start Uvicorn backend (`.\.venv\Scripts\python -m uvicorn app.main:app --port 8000`).
- [ ] Step 2: Open Android app and tap "Save & Test Reachability" in Connection Settings.
- [ ] Step 3: Verify Android displays "Connected" state seamlessly.

## 6. Safe Customization & Invariants

- **Tunable parameters**:
  - `MAX_REQUEST_BODY_BYTES`: Configured in `Settings` (default: `2_097_152` bytes / 2 MB).
  - `CORS_ORIGINS`: Comma-separated list of allowed explicit origins (must include `http://` or `https://`, never `*`).
- **Invariants**:
  - `public_router` must strictly contain only public endpoints (currently only `/health`).
  - No secrets (passwords, tokens, pairing keys) may appear in standard log streams.
  - Public health response must never leak database ping results or environment metadata.

## 7. Troubleshooting

- **Symptom**: Startup failure with `ValidationError: CORS_ORIGINS must not contain wildcard '*'`.
  - **Likely cause**: `.env` has `CORS_ORIGINS=*`.
  - **Resolution**: Specify explicit origins in `backend/.env` (e.g. `CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000`).
- **Symptom**: Large payload upload rejected with HTTP 413 `PAYLOAD_TOO_LARGE`.
  - **Likely cause**: Uploaded payload exceeds 2 MB limit.
  - **Resolution**: Stream or compress data in chunks under 2 MB, or adjust `MAX_REQUEST_BODY_BYTES` if larger voice/document payloads are required in later phases.
