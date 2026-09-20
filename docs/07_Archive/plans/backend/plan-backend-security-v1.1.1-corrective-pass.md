# Implementation Plan: Backend Security V1.1.1 Corrective Pass & Phased Security Roadmap

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Branch: Planned for `fix/backend-security-v1.1.1-corrective-pass` (or bundled into next sprint)
Reference Architecture: `docs/04_Architecture/BACKEND_SECURITY_REVIEW_AND_ROADMAP.md`

---

## 1. Executive Summary & Goals

This plan operationalizes the **V1.1.1 Corrective Pass (Phase 1.1)** from the team's security review and roadmap. It finishes the remaining API-level security hygiene items for the Local AI Core backend before broader feature development.

The goal is to close 7 focused security items without altering the operational foundation or breaking Android connectivity, freeze the baseline API security, and establish clear roadmap checkpoints for Phases 2 through 6.

---

## 2. Scope & Acceptance Criteria (Phase 1.1 / V1.1.1)

### Item 1: Minimal Public `/health` Response
- **Current State**: `/health` returns `status`, `version`, `database_connected`, `timestamp`, and performs an active SQLite ping.
- **Target**: Public `GET /api/v1/health` returns only `{"status": "healthy"}`.
- **Preserve Diagnostics**: Detailed diagnostics (`database_connected`, `version`, `timestamp`, `rx580_status`) remain exclusively under authenticated `GET /api/v1/system/status`.
- **Android Compatibility**: Android's `HealthDto` already parses `status: String`, so changing the JSON body preserves 100% compatibility.

### Item 2: True Fail-Closed Public / Protected Router Separation
- **Current State**: Router mounts sub-routers with individual `dependencies=[Depends(verify_token)]` on `/auth` and `/tasks`.
- **Target**: Create explicit `public_router` and `protected_router`:
  ```python
  public_router = APIRouter()
  protected_router = APIRouter(dependencies=[Depends(verify_token)])
  ```
  Future routers (`/memory`, `/assistant`, `/alarms`, `/schedule`) are included into `protected_router` by default, making the entire API fail-closed by construction.

### Item 3: Actual Received Bytes Request-Body Limit
- **Current State**: `PayloadLimitMiddleware` checks only the `Content-Length` header.
- **Target**: Add an ASGI stream byte counter that tracks incoming bytes across chunked requests or missing `Content-Length`. If accumulated bytes exceed `MAX_REQUEST_BODY_SIZE` (2 MB), immediately terminate and return HTTP 413.

### Item 4: Wildcard CORS Configuration Rejection
- **Current State**: Default origins are explicit, but setting `CORS_ORIGINS=*` in `.env` is parsed without validation.
- **Target**: Add startup validation in `Settings` or `main.py` that raises a fatal configuration error if `*` is supplied for origins or if origins lack proper `http://` / `https://` schemes.

### Item 5: Request ID Sanitization
- **Current State**: Callers can supply arbitrary `X-Request-ID` strings that are reflected in logs and response headers.
- **Target**: Validate caller-provided IDs against `^[a-zA-Z0-9_-]{1,64}$`. If invalid or missing, safely generate a server-side `req_<uuid4_hex>` identifier.

### Item 6: Expanded Negative Security Test Suite
- **Current State**: 6 tests verifying basic happy-path hardening.
- **Target**: Add negative test cases in `test_security_hardening.py`:
  - Request with unapproved CORS origin is denied.
  - Chunked request exceeding 2 MB without `Content-Length` returns HTTP 413.
  - Public `/health` response schema contains strictly `status`.
  - Malformed `X-Request-ID` (e.g. control chars, 500-char string) is replaced with safe server ID.
  - Wildcard CORS config validation fails.

### Item 7: Accurate Documentation Matching
- **Target**: Review all docs to ensure no exaggerated claims (e.g. replace "fully OWASP hardened" with accurate descriptions of local development and personal LAN threat boundaries).

---

## 3. Future Phased Security Roadmap Mapping

These subsequent phases are triggered as corresponding project capabilities are developed:

| Phase | Focus Area | Capability Trigger | Key Requirements |
| :--- | :--- | :--- | :--- |
| **Phase 2** | Client Pairing & Remote Network | Multi-device / Tailscale integration | Per-device credentials, device display names, credential revocation, Keystore / DPAPI storage. |
| **Phase 3** | Abuse Protection & Throttling | LAN exposure to multiple clients | Progressive failed-auth delay, endpoint rate limits, concurrent streaming connection caps. |
| **Phase 4** | AI Tool Policy Engine | Local LLM tool calling (llama.cpp) | Explicit tool schemas, Risk Levels 0–3, external authorization, high-risk user confirmation, execution audit log. |
| **Phase 5** | Sensitive Data Security | FTS5 Memory & Health Connect | Owner isolation, memory as context (not instruction authority), private health metrics, local backup/recovery. |
| **Phase 6** | Release Hardening | Pre-production / packaging | Locked dependencies, vulnerability scanning, release signing, production diagnostics policy. |

---

## 4. Verification Plan

### Automated Checks
1. Run backend security test suite:
   ```powershell
   cd backend
   .\.venv\Scripts\pytest -v
   ```
2. Verify all Android tests remain unaffected:
   ```powershell
   cd android
   .\gradlew.bat testDebugUnitTest
   ```

### Manual Verification
- Verify reachability probe on phone still returns "Local LAN" with minimal `/health` response.
