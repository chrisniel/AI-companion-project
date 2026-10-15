# Implementation Plan: Milestone M2 Batch B — Profile Authorization, Sessions & Cross-Profile Isolation

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: IMPLEMENTED / LOCALLY VERIFIED — final independent PR-ready review pending (current authorization and evidence in §8)
- Scope Mode: Authorization Hardening & Session Security — `PC-IDENTITY-002` Profile Authorization & Isolation
- Target Files:
  - `backend/migrations/versions/008_profile_sessions_and_tickets.py`
  - `backend/app/models/profile_session.py`
  - `backend/app/models/session_ticket.py`
  - `backend/app/models/base.py`
  - `backend/app/models/__init__.py`
  - `backend/app/core/security.py`
  - `backend/app/core/host_admin.py`
  - `backend/app/core/windows_security.py`
  - `backend/app/api/deps.py`
  - `backend/app/api/v1/router.py`
  - `backend/app/api/v1/endpoints/auth.py`
  - `backend/app/api/v1/endpoints/profiles.py`
  - `backend/app/api/v1/endpoints/conversations.py`
  - `backend/app/api/v1/endpoints/attachments.py`
  - `backend/app/api/v1/endpoints/tasks.py`
  - `backend/app/api/v1/endpoints/memories.py`
  - `backend/app/api/v1/endpoints/llm.py`
  - `backend/app/api/v1/endpoints/health.py`
  - `backend/app/services/memory/retriever.py`
  - `backend/app/services/assistant/orchestrator.py`
  - `backend/app/services/attachment_service.py`
  - `backend/app/services/retention.py`
  - `backend/tests/test_migration_008.py`
  - `backend/tests/test_profile_sessions.py`
  - `backend/tests/test_profile_authorization.py`
  - `backend/tests/test_windows_security.py`
  - `frontend/flutter/packages/companion_api/lib/client/companion_client.dart`
  - `frontend/flutter/apps/desktop/lib/platform/windows_dpapi_credential_store.dart`
  - `frontend/web/src/context/BackendContext.tsx`
  - `frontend/web/src/services/api/index.ts`

Notice: Update this plan in place during planning. After approval, switch live execution tracking to `docs/01_Tracking/task.md` (or branch-active tracker) and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### 1.1 Primary Objective
Deliver `PC-IDENTITY-002` (Milestone M2 Batch B) to establish fail-closed multi-profile authorization, session token issuance, desktop-approved browser bootstrapping, and complete cross-profile isolation across all personal-data endpoints, memory retrieval, and streaming services, building on the database foundation established in Batch A (`ADR-0018`, Migration 007).

### 1.2 Concrete Deliverables
1. **Migration 008 (`008_profile_sessions_and_tickets.py`):**
   - Tables `profile_sessions` (token hash, profile reference, client type, TTL, revocation) and `session_tickets` (single-use exchange tickets).
   - Removal of SQLite `server_default` constraints on `profile_id` across all five personal-data tables (`conversations`, `messages`, `tasks`, `memories`, `attachments`).
   - Removal of SQLAlchemy implicit defaults (`resolve_default_profile_id` in `ProfileMixin`).
   - Raw SQL and ORM writes without `profile_id` must fail closed (`NOT NULL constraint failed`).
   - Preservation of existing records, foreign keys, unique indexes, FTS5 triggers, and `owner_id` as a non-authoritative legacy shadow column.
2. **Three Strict Authority Realms (`SYSTEM_BASELINE.md` & `ADR-0018`):**
   - **Local Host Administrator:** Authenticated solely via `desktop_admin.secret` (stored in `%LOCALAPPDATA%\AICompanion\secrets\` with Windows user SID ACL verification). Authorizes model selection, hardware profile changes, system diagnostics, and profile ticket issuance. Completely isolated from `COMPANION_API_KEY`.
   - **Profile Session (`ProfileSession`):** Scoped bearer token (`psk_...`) bound to `session.profile_id`. Required on **every** personal-data endpoint (conversations, messages, SSE turns, titles, attachments, tasks, memories, FTS5 retrieval).
   - **Legacy Pairing Credential (`COMPANION_API_KEY`):** Restricted solely to read-only host telemetry (`/health`, read-only `/models`, read-only `/models/registry`) and pairing validation (`/auth/verify`). Statically barred from all personal data, session minting, and model-loading mutations.
3. **Desktop-Approved Browser Session Bootstrap:**
   - Flutter desktop creates/approves a single-use ticket for a specific Profile.
   - High-entropy, short-lived (TTL $\le 60\text{ seconds}$), single-use ticket (`ptk_...`) exchanged via loopback POST without exposing bearer tickets in URL query parameters.
   - Origin/CSRF protections, single-use invalidation, and removal of browser `localStorage` pairing-key storage (token held in memory React context).
   - PIN-protected Profiles require challenge verification or fail closed (`403 Forbidden`).
4. **Complete Personal-Data Route Isolation:**
   - Every personal-data endpoint in `backend/app/api/v1/endpoints/` requires an active `ProfileSession`.
   - All queries and mutations strictly filtered by `profile_id == session.profile_id`.
   - FTS5 search in `app/services/memory/retriever.py` updated to filter strictly by `profile_id`.
5. **Exact FastAPI Decorator Alignment:**
   - Accurate source paths in `backend/app/api/v1/endpoints/` (`conversations.py`, `attachments.py`, `tasks.py`, `memories.py`, `llm.py`, `health.py`, `auth.py`).
   - No phantom endpoints (pruned non-existent `GET /memories/search` and `GET /memories/{id}`).
6. **Minimal Read-Only Profile Catalog (No General CRUD in Batch B):**
   - In-scope: Host Admin-only catalog (`GET /api/v1/profiles`) and Host Admin or own-Profile lookup (`GET /api/v1/profiles/{id}`). A Profile Session cannot enumerate other Profiles.
   - Explicitly excluded: General `POST /api/v1/profiles`, `PATCH /api/v1/profiles/{id}`, and `DELETE` stubs.
   - Future roadmap alignment:
     - `PC-IDENTITY-003`: Device Enrollment & satellite keypairs.
     - `PC-IDENTITY-004`: Profile Administration & PIN UX.
     - `PC-IDENTITY-005`: Profile Deletion Lifecycle & 7-day soft purge.

### 1.3 Explicit Out-of-Scope (Deferred)
- **Profile Management & Deletion (`PC-IDENTITY-004` & `PC-IDENTITY-005`):** Creating, updating, or deleting profiles via API; PIN enrollment UX; Argon2id salt generation.
- **Device Keypair Enrollment (`PC-IDENTITY-003` / `D-PHONE-01B`):** Satellite mobile public key enrollment.
- **Character Templates & Emotional Mood Models (`PC-CHAR-001` / Decision D11):** Persona instances, trait vectors, and active mood states.

---

## 2. Current Findings & Technical Root Cause

| Observation / Evidence | Verified Interpretation |
| --- | --- |
| Migration 007 added `profile_id` with `server_default=default_profile_id` to 5 tables. | Raw SQL inserts omitting `profile_id` silently succeed and associate records with the Default Profile instead of failing closed. |
| `ProfileMixin` in `backend/app/models/base.py` automatically resolves `default_profile_id` during flush. | ORM writes silently fallback to Default Profile if an authenticated profile context is missing. |
| `protected_router` in `backend/app/api/v1/router.py` applies `Depends(verify_token)` globally. | Conflates host administration with personal data access; pairing key grants ambient authority to all routes. |
| Endpoints in `conversations.py`, `tasks.py`, and `memories.py` filter by `owner_id = Depends(get_current_owner)`. | Entities are partitioned by legacy `local_user` rather than verified `session.profile_id`, allowing cross-profile data leakage. |
| `backend/app/services/memory/retriever.py` queries `memories_fts` with `WHERE m.owner_id = :owner_id`. | Long-term memory context injection across chat turns leaks memories across profiles. |
| Web frontend stores `COMPANION_API_KEY` in `localStorage`. | Browser pairing key can be exfiltrated or abused to query host runtime endpoints. |

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/migrations/versions/008_profile_sessions_and_tickets.py`
- Primary Responsibility: Alembic migration for session management and removal of default constraints.
- Schema Definition:
  - Table `profile_sessions`:
    - `id`: VARCHAR(36) PRIMARY KEY (UUID).
    - `profile_id`: VARCHAR(36) FOREIGN KEY REFERENCES `profiles(id)` ON DELETE CASCADE, NOT NULL, INDEX.
    - `token_hash`: VARCHAR(64) NOT NULL UNIQUE, INDEX (SHA-256 of bearer token `psk_...`).
    - `client_type`: VARCHAR(32) NOT NULL (`desktop`, `web_browser`, `satellite_device`).
    - `client_identifier`: VARCHAR(128) NULL.
    - `created_at`: DATETIME NOT NULL.
    - `expires_at`: DATETIME NOT NULL, INDEX.
    - `revoked_at`: DATETIME NULL.
    - `last_active_at`: DATETIME NOT NULL.
  - Table `session_tickets`:
    - `id`: VARCHAR(36) PRIMARY KEY (UUID).
    - `ticket_hash`: VARCHAR(64) NOT NULL UNIQUE, INDEX (SHA-256 of ticket `ptk_...`).
    - `profile_id`: VARCHAR(36) FOREIGN KEY REFERENCES `profiles(id)` ON DELETE CASCADE, NOT NULL.
    - `created_at`: DATETIME NOT NULL.
    - `expires_at`: DATETIME NOT NULL (TTL $\le 60\text{ seconds}$).
    - `redeemed_at`: DATETIME NULL.
  - Batch Alter on 5 Personal-Data Tables (`conversations`, `messages`, `tasks`, `memories`, `attachments`):
    - Remove `server_default` on `profile_id` via `batch_op.alter_column('profile_id', server_default=None, nullable=False)`.
    - Preserve existing foreign keys, unique indices, and non-authoritative `owner_id` shadow column.
- Invariants: Pre-migration WAL safety backup hook executes before schema modifications. Downgrade drops session tables but preserves explicit ownership requirements; it never restores implicit defaults or legacy pairing-key personal-data authority. Recovery requires authorized host-quiesced maintenance.

### [MODIFY] `backend/app/models/base.py` & [ADD] `profile_session.py`, `session_ticket.py`
- Primary Responsibility: Remove implicit ORM profile resolution and declare session models.
- Planned Logic:
  - Remove `resolve_default_profile_id` hook from `ProfileMixin`; require explicit `profile_id` on all model initializations.
  - Declare `ProfileSession` and `SessionTicket` SQLAlchemy 2.0 ORM models.

### [ADD] `backend/app/core/windows_security.py`
- Primary Responsibility: Windows filesystem ACL security enforcement.
- Planned Logic:
  - Inspect file security descriptor on Windows using Win32 API (`advapi32.dll` / `GetFileSecurityW`) or deterministic `icacls`.
  - Validate that access is granted EXCLUSIVELY to Current User SID (`S-1-5-21-...`) and `SYSTEM`.
  - Fail closed on multi-user or insecure ACLs on startup.

### [ADD] `backend/app/core/host_admin.py`
- Primary Responsibility: Desktop Host Administrator credential lifecycle.
- Planned Logic:
  - Manage `desktop_admin.secret` in `%LOCALAPPDATA%\AICompanion\secrets\`.
  - Provide `require_host_admin` dependency validating against the desktop secret using constant-time comparison.
  - Issue single-use, 60s TTL tickets (`ptk_...`) bound to specified `profile_id`.
  - If target Profile has `pin_hash is not None`, reject ticket issuance with `403 Forbidden` (fail-closed until `PC-IDENTITY-004` challenge flow is delivered).

### [MODIFY] `backend/app/api/deps.py` & `backend/app/core/security.py`
- Primary Responsibility: Authentication dependencies.
- Planned Logic:
  - `get_current_profile_session`: Validates `Authorization: Bearer psk_...`, checks SHA-256 hash against `profile_sessions`, verifies `revoked_at is None` and `expires_at > utcnow()`. Returns active `ProfileSession`.
  - `require_host_admin`: Validates `X-Host-Admin-Secret` or `Authorization: Bearer <admin_secret>`.
  - `verify_token`: Retained ONLY for read-only telemetry (`/models`, `/models/registry`) and pairing checks (`/auth/verify`). Statically barred from personal-data endpoints.

### [MODIFY] `backend/app/api/v1/router.py`
- Primary Responsibility: Router tree segregation.
- Planned Logic:
  - `public_router`: `GET /health`.
  - `host_admin_router`: `POST /models/load`, `POST /models/select`, `POST /models/unload`, `PATCH /models/profile`, `GET /system/status`, `POST /auth/bootstrap/ticket`.
  - `profile_session_router`: All conversation, attachment, task, memory, and chat completion endpoints.
  - `telemetry_router`: Read-only `/models`, `/models/registry`, and `/auth/verify` (guarded by pairing token or session).

### [MODIFY] `backend/app/api/v1/endpoints/auth.py`
- Primary Responsibility: Session exchange and ticket claim.
- Planned Logic:
  - `POST /api/v1/auth/bootstrap/ticket`: (Host Admin) Mints single-use ticket `ptk_...` for a specified profile.
  - `POST /api/v1/auth/session/exchange`: (Loopback POST) Accepts `{"ticket": "ptk_..."}`, verifies SHA-256 hash, atomically sets `redeemed_at = utcnow()`, mints `ProfileSession`, and returns `{"token": "psk_...", "profile_id": "...", "expires_at": "..."}`.
  - `POST /api/v1/auth/session/claim`: (Loopback Browser Handoff) Allows browser at `http://localhost:5173` to exchange an ephemeral desktop-primed grant without putting tickets in URL query parameters.
  - `POST /api/v1/auth/session/revoke`: (Profile Session) Revokes active session.
  - `GET /api/v1/auth/session/me`: (Profile Session) Returns active session profile metadata.

### [ADD] `backend/app/api/v1/endpoints/profiles.py`
- Primary Responsibility: Minimal read-only Profile lookup.
- Planned Logic:
  - `GET /api/v1/profiles`: (Host Admin only) Returns existing profiles (id, name, is_default, status) for desktop selection/catalog. Profile Sessions cannot enumerate the catalog.
  - `GET /api/v1/profiles/{profile_id}`: (Host Admin or matching Profile Session) Returns profile details.
  - No `POST`, `PATCH`, or `DELETE` endpoints in Batch B.

### [MODIFY] `backend/app/api/v1/endpoints/conversations.py`
- Primary Responsibility: Isolate all 8 conversation endpoints to authenticated Profile Session.
- Planned Logic:
  - Require `session: ProfileSession = Depends(get_current_profile_session)`.
  - Endpoints:
    - `POST /conversations`: Sets `profile_id = session.profile_id`.
    - `GET /conversations`: Filters `Conversation.profile_id == session.profile_id`.
    - `GET /conversations/{id}`: Validates `conv.profile_id == session.profile_id` (404 on mismatch).
    - `PATCH /conversations/{id}`: Validates `conv.profile_id == session.profile_id`.
    - `DELETE /conversations/{id}`: Validates `conv.profile_id == session.profile_id`.
    - `POST /conversations/{id}/messages`: Validates `conv.profile_id == session.profile_id`; SSE stream and memory extraction bound to `session.profile_id`.
    - `GET /conversations/{id}/messages`: Validates `conv.profile_id == session.profile_id`.
    - `POST /conversations/{id}/generate-title`: Validates `conv.profile_id == session.profile_id`.

### [MODIFY] `backend/app/api/v1/endpoints/attachments.py`
- Primary Responsibility: Isolate all 3 attachment endpoints to authenticated Profile Session.
- Planned Logic:
  - `POST /conversations/{id}/attachments`: Validates conversation belongs to `session.profile_id`; sets `attachment.profile_id = session.profile_id`.
  - `GET /conversations/{id}/attachments/{aid}/preview`: Validates attachment and parent conversation belong to `session.profile_id`.
  - `DELETE /conversations/{id}/attachments/{aid}`: Validates attachment belongs to `session.profile_id`.

### [MODIFY] `backend/app/api/v1/endpoints/tasks.py`
- Primary Responsibility: Isolate all 8 task endpoints to authenticated Profile Session.
- Planned Logic:
  - Require `session: ProfileSession = Depends(get_current_profile_session)`.
  - Endpoints:
    - `GET /tasks`: Filters `Task.profile_id == session.profile_id`.
    - `POST /tasks`: Sets `task.profile_id = session.profile_id`.
    - `GET /tasks/trash`: Filters `Task.profile_id == session.profile_id`.
    - `GET /tasks/{id}`: Validates `task.profile_id == session.profile_id`.
    - `PATCH /tasks/{id}`: Validates `task.profile_id == session.profile_id`.
    - `DELETE /tasks/{id}`: Validates `task.profile_id == session.profile_id`.
    - `POST /tasks/{id}/restore`: Validates `task.profile_id == session.profile_id`.
    - `DELETE /tasks/{id}/permanent`: Validates `task.profile_id == session.profile_id`.

### [MODIFY] `backend/app/api/v1/endpoints/memories.py` & `backend/app/services/memory/retriever.py`
- Primary Responsibility: Isolate all 4 memory endpoints and FTS5 search to authenticated Profile Session.
- Planned Logic:
  - `GET /memories`: Filters `Memory.profile_id == session.profile_id`.
  - `POST /memories`: Sets `memory.profile_id = session.profile_id`.
  - `PATCH /memories/{id}`: Validates `memory.profile_id == session.profile_id`.
  - `DELETE /memories/{id}`: Validates `memory.profile_id == session.profile_id`.
  - `retriever.py` (`search_relevant_memories`):
    - Update SQL query: replace `AND m.owner_id = :owner_id` with `AND m.profile_id = :profile_id`.

### [MODIFY] `backend/app/api/v1/endpoints/llm.py` & `health.py`
- Primary Responsibility: Host Admin vs Profile Session routing.
- Planned Logic:
  - Host Admin required: `POST /models/load`, `POST /models/select`, `POST /models/unload`, `PATCH /models/profile`, `GET /system/status`.
  - Profile Session required: `POST /chat/completions`.
  - Telemetry (pairing token or session): `GET /models`, `GET /models/registry`.

### [MODIFY] `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` & `windows_dpapi_credential_store.dart`
- Primary Responsibility: Flutter desktop client session awareness and DPAPI storage.
- Planned Logic:
  - Add session token management to `CompanionClient`; pass `Authorization: Bearer psk_...` on personal-data calls.
  - Store Host Admin secret and active Profile Session token via `WindowsDpapiCredentialStore`.

### [MODIFY] `frontend/web/src/context/BackendContext.tsx` & `frontend/web/src/services/api/index.ts`
- Primary Responsibility: React web client in-memory session handling.
- Planned Logic:
  - Claim bootstrap ticket via loopback POST handoff (no tokens in URL query string).
  - Store `sessionToken` exclusively in memory React state.
  - Purge legacy `COMPANION_API_KEY` from browser `localStorage`.

---

## 4. Step-by-Step Pseudocode & Implementation Sequence

### Phase B.1: Migration 008 & Model Hardening
1. Implement `backend/migrations/versions/008_profile_sessions_and_tickets.py`:
   - Create `profile_sessions` and `session_tickets` tables.
   - Batch alter `conversations`, `messages`, `tasks`, `memories`, and `attachments` to drop `server_default` on `profile_id`.
   - Maintain `nullable=False`, foreign keys, and shadow `owner_id`.
2. Connect pre-migration safety backup hook to trigger verified backup prior to DDL execution.
3. Update `backend/app/models/base.py`:
   - Remove `resolve_default_profile_id` from `ProfileMixin`.
4. Add models `ProfileSession` and `SessionTicket` in `backend/app/models/`.
5. Automated Test: Verify raw SQL `INSERT` without `profile_id` fails closed on all 5 tables (`sqlite3.IntegrityError: NOT NULL constraint failed`).

### Phase B.2: Windows ACL Security & Host Admin Authority
1. Implement `backend/app/core/windows_security.py`:
   - Verify filesystem permissions on `%LOCALAPPDATA%\AICompanion\secrets\desktop_admin.secret`.
   - Confirm ACL contains only Current User SID (`S-1-5-21-...`) and `SYSTEM`.
   - Fail closed on multi-user environments or loose ACLs.
2. Implement `backend/app/core/host_admin.py`:
   - Initialize and protect `desktop_admin.secret`.
   - Implement `require_host_admin` dependency using `secrets.compare_digest`.
   - Mint single-use, 60s TTL tickets `ptk_...` bound to specified Profile.
   - Fail closed (`403 Forbidden`) if target Profile has `pin_hash is not None`.

### Phase B.3: Session Exchange & Secure Browser Bootstrap Handoff
1. Implement `backend/app/api/v1/endpoints/auth.py`:
   - `POST /api/v1/auth/bootstrap/ticket` (Host Admin only).
   - `POST /api/v1/auth/session/exchange` (Loopback POST, burns ticket atomically, issues bearer token `psk_...`).
   - `POST /api/v1/auth/session/claim` (Loopback browser handoff without query string tokens).
   - `POST /api/v1/auth/session/revoke` (Invalidates session).
   - `GET /api/v1/auth/session/me` (Inspects active session profile metadata).
2. Automated Test: Verify single-use burning, concurrent replay rejection, and 60-second TTL expiration.

### Phase B.4: Router Segregation & Authentication Dependencies
1. Implement `get_current_profile_session` dependency in `backend/app/api/deps.py`.
2. Restructure `backend/app/api/v1/router.py`:
   - Isolate public, host admin, telemetry, and profile session route groups.
   - Statically bar `verify_token` pairing key from all personal-data endpoints.

### Phase B.5: Complete Personal-Data Endpoint Isolation & Memory Retrieval
1. Refactor `conversations.py`:
   - Enforce `ProfileSession` on all 8 endpoints (`GET /conversations`, `POST /conversations`, `GET /conversations/{id}`, `PATCH /conversations/{id}`, `DELETE /conversations/{id}`, `POST /conversations/{id}/messages` SSE, `GET /conversations/{id}/messages`, `POST /conversations/{id}/generate-title`).
2. Refactor `attachments.py`:
   - Enforce `ProfileSession` on all 3 endpoints (upload, preview, delete).
3. Refactor `tasks.py`:
   - Enforce `ProfileSession` on all 8 endpoints (list, create, trash, get, update, soft-delete, restore, permanent delete).
4. Refactor `memories.py`:
   - Enforce `ProfileSession` on all 4 endpoints (list, create, update, delete).
5. Refactor `retriever.py` in `backend/app/services/memory/retriever.py`:
   - Scope FTS5 search query strictly by `m.profile_id = :profile_id`.
6. Refactor `llm.py` and `health.py`:
   - Restrict model mutation endpoints to `HostAdmin`.
   - Restrict `GET /system/status` to `HostAdmin`.

### Phase B.6: Minimal Read-Only Profile Catalog
1. Implement `backend/app/api/v1/endpoints/profiles.py`:
   - `GET /api/v1/profiles`: (Host Admin or Profile Session) Returns list of profiles for catalog/selection.
   - `GET /api/v1/profiles/{id}`: Returns profile metadata.
   - Explicitly omit `POST`, `PATCH`, and `DELETE` endpoints.

### Phase B.7: Client Adapters & Storage Retirement
1. Update `frontend/flutter/packages/companion_api/lib/client/companion_client.dart`:
   - Pass `Authorization: Bearer psk_...` on personal-data calls.
   - Integrate `WindowsDpapiCredentialStore` for persistent credentials.
2. Update `frontend/web/src/context/BackendContext.tsx` & `src/services/api/index.ts`:
   - Integrate loopback bootstrap handoff.
   - Store `sessionToken` exclusively in memory React context.
   - Purge `COMPANION_API_KEY` from `localStorage`.

### Phase B.8: Comprehensive Security Regression Suite
1. Build `backend/tests/test_profile_authorization.py`:
   - Cross-profile leakage attempts across conversations, messages, attachments, tasks, memories, and SSE.
   - Memory injection cross-profile isolation in FTS5 retriever.
   - Legacy pairing key rejected on all personal-data routes (`401`/`403`).
   - Admin privilege escalation attempts rejected.
   - Raw SQL and ORM missing-profile write rejection.
   - PIN-protected profile ticket issuance fails closed.
2. Run full backend, Flutter analyze, and React test suites.

---

## 5. Acceptance Criteria & Verification Plan

### Automated Repository Checks

Completed checks below record local automated evidence from §8, not independent gate approval.

- [x] `pytest backend/tests/test_migration_008.py`: Upgrade/downgrade preserves pre-existing personal data. Downgrade retires sessions/grants without restoring implicit ownership defaults.
- [x] `pytest backend/tests/test_profile_authorization.py`:
  - Profile A cannot access Profile B's conversations, messages, attachments, tasks, or memories (100% fail-closed 404/403).
  - Pairing key `COMPANION_API_KEY` receives 401/403 on all personal-data endpoints.
  - Raw SQL inserts and ORM writes without `profile_id` raise `IntegrityError` (NOT NULL constraint).
  - Memory FTS5 retrieval for Profile A never returns Profile B's records.
  - SSE turns in Profile A never stream to or leak data from Profile B.
- [x] `pytest backend/tests/test_profile_sessions.py`:
  - Bootstrap ticket cannot be redeemed more than once (atomic burn).
  - Concurrent ticket replay fails with 401/409.
  - Expired tickets ($\gt 60\text{s}$) and expired sessions fail with 401.
  - Revoked sessions fail immediately with 401.
  - PIN-protected profile ticket request fails closed (403).
- [x] `pytest backend/tests/test_windows_security.py`:
  - Secret file with permissions granting access to `Everyone` or other users fails closed on startup.
  - Secret file restricted to Current User SID and `SYSTEM` passes.
- [x] Full backend test suite passes (`pytest backend/tests`).
- [x] `flutter analyze` passes across all monorepo packages.
- [x] `npm test` and `npm run lint` pass in `frontend/web`.

### Manual / User-Owned Checks
- [ ] Confirm `%LOCALAPPDATA%\AICompanion\secrets\desktop_admin.secret` permissions via `icacls` are restricted to Current User SID.
- [ ] Open Web UI via desktop bootstrap handoff; verify valid session established without `?ticket=` in browser URL bar and no API keys in `localStorage`.
- [ ] Verify curl request to `/api/v1/conversations` with pairing key returns 401/403.

---

## 6. Risks, Recovery & Rollback

- **Risk: Accidental Breakage of Single-User Experience.**
  - *Mitigation:* Startup restores a saved Profile Session only after authenticated introspection, preserving its Profile identity and absolute server expiry. Only an installation without prior session authority may bootstrap Default through independent Host Admin authorization. Invalid saved authority requires explicit authorization; explicit switching revokes the old session and clears private state.
- **Risk: Browser Refresh Session State Loss.**
  - *Mitigation:* Browser context retains session in memory; refresh starts a new authorization request requiring explicit trusted Desktop approval. Loopback proximity does not authorize a session.
- **Risk: Migration 008 Failure.**
  - *Mitigation:* Pre-migration WAL safety snapshot executes and is verified before Migration 008 runs. Failure aborts startup, retains the verified snapshot and reports diagnostics. Startup never automatically restores a live database.
- **Rollback Procedure:**
  - Recovery or rollback requires separately authorized host-quiesced maintenance; retain and verify the snapshot before any restoration. Do not automatically restore a running/live database. Downgrade must preserve explicit ownership requirements.
  - Fail closed if corrupt database or version mismatch is encountered.
  - **Security Invariant:** Ambient pairing-key access to personal data will NEVER be restored as a rollback mechanism.

## 7. Binding Plan Gate Addendum (Chris handoff, 2026-10-13)

This addendum binds implementation and supersedes less restrictive pseudocode above. It records the conditions of the human-approved handoff; it does not claim an independently passed Implementation, Documentation or Closure Gate.

### A. Browser request, Desktop approval and proof of possession

- The browser generates its own high-entropy claim secret, keeps it in memory and initiates a short-lived authorization request bound to its hash and exact allowed Origin. It receives only a non-bearer request identifier and expiry.
- Host Admin-only pending-request lookup exposes the request identifier, Origin and expiry for trusted Flutter Desktop review. Flutter explicitly approves one request for one selected active Profile using independent Host Admin authority. No browser receives the administrator secret.
- Claim/exchange requires the requesting browser's secret, the matching Origin, explicit approval, an active unprotected Profile and an unexpired request. Consume the grant atomically with session issuance in one transaction; concurrent redemption and replay fail closed. TTL is at most 60 seconds. A desktop-only direct ticket uses independent Host Admin authorization and cannot bypass browser Origin/claim binding.
- Browser POSTs require an exact configured Origin and JSON/custom-header CSRF protection; reject missing/untrusted/null Origin, inappropriate browser fetch metadata and non-loopback bootstrap transport. Localhost, pairing credentials and pending requests grant no personal-data authority.
- Never transport bearer tickets or sessions in URL queries, fragments or browser history. Browser tokens remain in memory; remove legacy persisted pairing keys. Refresh requires fresh explicit approval. PIN-protected Profiles fail closed until an authorized challenge exists.

### B. Catalog privacy

- Only Host Admin enumerates all Profiles. A Profile Session retrieves only its own Profile metadata, including through `/auth/session/me`; guessed foreign Profile identifiers fail closed without disclosure.
- General Profile CRUD, PIN enrollment and device enrollment remain out of scope.

### C. Complete service ownership and session lifecycle

- Explicitly include `backend/app/services/assistant/orchestrator.py`, `backend/app/services/attachment_service.py`, `backend/app/services/memory/retriever.py` and `backend/app/services/retention.py` alongside all personal-data routes.
- Derive personal-data ownership from a validated Profile Session or explicitly trusted maintenance authority. Require explicit ownership in service calls and writes; no default Profile or `owner_id` fallback.
- Protect conversations, messages, attachment upload/binding/preview/delete, memory/FTS5 retrieval, SSE output, turn persistence and task/retention operations against cross-Profile access. Validate both child and parent ownership where applicable.
- Revalidate session expiration/revocation and Profile availability during ongoing streaming and before persistence, including while awaiting slow model output. Stop unauthorized output and writes. Cancel/close model iteration safely.
- Retention requires an explicit trusted maintenance context; arbitrary profile identifiers alone do not grant maintenance authority.

### D. Migration recovery and verification

- Migration 008 removes all SQLite and ORM implicit `profile_id` defaults across the five personal-data tables; raw SQL and ORM writes without ownership fail closed.
- Preserve data, foreign keys, indexes, FTS5 triggers/search and verified pre-migration backups. Test upgrade and downgrade using synthetic databases, including existing rows and FTS5 behavior.
- Migration failure aborts startup, retains the verified snapshot and emits diagnostics. Never automatically restore a live database. Recovery requires authorized host-quiesced maintenance. Never restore pairing-key authority over personal data during rollback.

### Execution and review boundary

- Commit this in-place correction on `feature/m2-profile-foundation-b`, then execute B.1–B.8 using failing tests first. Related runtime startup, client wiring/UI, fixtures and generated OpenAPI contract changes necessary for the cutover are included; no unrelated infrastructure or dependency changes.
- Verify focused and full relevant backend, React and Flutter checks, keeping pre-existing failures distinct from candidate results. Commit and HTTPS-push the implementation on this same branch, verify remote HEAD equals local HEAD, then STOP for independent Implementation Gate review. Do not create a PR, merge, begin canonical documentation/closure or self-approve any gate.

## 8. Final Correction and Documentation/Closure Preparation (Chris authorization, 2026-10-15)

Chris confirmed that independent review of `92225c86f7deb5f25b077e60f207f047eb8ab512` found the original saved-Profile restart defect corrected. The remaining correction adds the validated persisted session `expires_at` to `/auth/session/me`, preserves existing Profile metadata and schedules Flutter cleanup at that absolute deadline. Introspection and restart never renew server expiry. Regressions cover repeated restoration, expiration, switching, private cache/error clearing, retained subscriptions and late asynchronous completions.

For this final task, Chris explicitly authorized the scoped correction, local verification, canonical documentation reconciliation and closure preparation on the same branch, ordinary commits and HTTPS push. This supersedes the earlier §7 no-documentation stop boundary for this task only; it preserves the historical approval record. No new plan/branch, force-push, PR creation or merge is authorized.

Local verification passed: backend **600 tests** (one existing Starlette deprecation warning), focused backend **90**; Flutter **334** (API 63, core 22, design 18, Desktop 231), focused Desktop **86**; Flutter analysis **no issues**; React **242**, lint/typecheck/build passed; script tests **38 plus 49 subtests**; OpenAPI drift check **32 paths** and Dart parity **13 DTOs / 18 routes** passed. Backend used the existing Python **3.13.14** environment; Python 3.11 qualification remains unverified. Commands, evidence locations and prepared PR title/extended summary/squash message are owned by the [branch task](../../01_Tracking/active/task-feature-m2-profile-foundation-b.md).

Batch B is implemented and locally verified. Canonical documentation and closure records are prepared for independent review; no authoring agent certifies the Implementation, Documentation or Closure Gate. Hosted PR CI has not run, branch CI is not verified, and Windows/Desktop/browser manual acceptance remains pending. Full Profile CRUD, PIN enrollment, device enrollment and Character Studio remain future work. Wider M2 remains **IN PROGRESS**. Stop for final independent PR-ready review; archive the branch task only after independently approved closure.
