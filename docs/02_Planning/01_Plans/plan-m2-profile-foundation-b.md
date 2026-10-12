# Implementation Plan: Milestone M2 Batch B — Profile Authorization, Sessions & Cross-Profile Isolation

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Draft (Awaiting Independent Plan Review)
- Scope Mode: New Feature & Authorization Hardening — `PC-IDENTITY-002` Profile Authorization & Isolation
- Target Files:
  - `backend/migrations/versions/008_profile_sessions_and_tickets.py`
  - `backend/app/models/profile_session.py`
  - `backend/app/models/session_ticket.py`
  - `backend/app/models/__init__.py`
  - `backend/app/core/security.py`
  - `backend/app/core/host_admin.py`
  - `backend/app/core/windows_security.py`
  - `backend/app/api/deps.py`
  - `backend/app/routers/auth.py`
  - `backend/app/routers/profiles.py`
  - `backend/app/routers/conversations.py`
  - `backend/app/routers/tasks.py`
  - `backend/app/routers/memories.py`
  - `backend/app/services/memory/service.py`
  - `backend/tests/test_profile_sessions.py`
  - `backend/tests/test_profile_authorization.py`
  - `backend/tests/test_windows_security.py`
  - `frontend/flutter/packages/companion_api/lib/src/companion_api_client.dart`
  - `frontend/web/src/context/BackendContext.tsx`
  - `frontend/web/src/services/api/index.ts`

Notice: Update this plan in place during planning. After approval, switch live execution tracking to `docs/01_Tracking/task.md` (or branch-active tracker) and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### 1.1 Primary Objective
Deliver `PC-IDENTITY-002` (Milestone M2 Batch B) to establish cryptographically enforced multi-profile session management, strict cross-profile personal-data isolation, desktop-approved browser session bootstrapping, and fail-closed host administrator boundaries on the Windows desktop, building directly on the Batch A schema foundation (`ADR-0018`, Migration 007).

### 1.2 Concrete Deliverables
1. **Database Migration 008 (`profile_sessions` & `session_tickets`):**
   - Introduces the `profile_sessions` table for revocable, TTL-bounded session tokens bound to a verified `profile_id`.
   - Introduces the `session_tickets` table for single-use, high-entropy, short-lived bootstrap exchange tickets.
   - Clean Alembic downgrade capability preserving `profiles` and all existing personal records.
2. **Four Discrete Authority Realms (`SYSTEM_BASELINE.md` & `ADR-0018`):**
   - **Local Host Administrator:** Authenticated solely via protected `desktop_admin.secret` (never shared with browsers or satellite devices; independent from `COMPANION_API_KEY`).
   - **Profile Session (`ProfileSession`):** Scoped bearer token (`psk_...`) issued upon verified desktop bootstrap or session exchange; strictly bounds all queries and mutations to `session.profile_id`.
   - **Legacy Pairing Credential (`COMPANION_API_KEY`):** Strictly restricted to host-level telemetry, router health, and model lifecycle (`/health`, `/api/v1/model/*`); statically disallowed from accessing personal data.
   - **Future Profile-Bound Device Credentials:** Reserved architectural realm for satellite companions bound to a single profile without host administrative privileges.
3. **Desktop-Approved Browser Session Bootstrap:**
   - Flutter Desktop mints high-entropy single-use bootstrap ticket (`ptk_...`) bound to the selected Profile via Host Admin IPC.
   - Browser exchanges ticket via `POST /api/v1/auth/session/exchange` for an ephemeral Profile Session token stored in React memory context, retiring `localStorage` pairing-key storage.
   - Windows user SID and ACL verification (`Win32 API` / `icacls`) ensuring secret files are restricted strictly to the Current User SID (`S-1-5-21-...`) and `SYSTEM`, failing closed on multi-user or insecure permissions.
4. **Personal-Data Route Isolation Without Legacy Bypass:**
   - Immediate removal of legacy fallback on 4 critical personal-data routes: `GET /tasks`, `POST /tasks`, `GET /memories/search`, and `POST /memories`.
   - Unauthenticated, expired, or invalid session requests fail closed with `401 Unauthorized` / `403 Forbidden`.
5. **FastAPI Route Decorator Matrix Alignment:**
   - Real FastAPI decorator paths reconciled:
     - `POST /conversations/{id}/generate-title`
     - `POST /conversations/{id}/messages` (SSE streaming turn)
     - `GET /conversations/{id}/attachments/{aid}/preview`
     - `DELETE /tasks/{id}/permanent`
   - Explicitly pruned non-existent routes (`GET /memories/{id}`, standalone attachment listing/deletion).
6. **Minimal Profile CRUD Scope (4 Endpoints):**
   - `GET /api/v1/profiles` (Host Admin enumerates all; active Profile Session retrieves own profile).
   - `POST /api/v1/profiles` (Host Admin or desktop bootstrap creates profile).
   - `GET /api/v1/profiles/{id}` (Host Admin or session matching `{id}`).
   - `PATCH /api/v1/profiles/{id}` (Host Admin or session matching `{id}`).
   - Profile deletion (`DELETE /api/v1/profiles/{id}`) is explicitly **DEFERRED**.
7. **Comprehensive Security Test Suite:**
   - Adversarial cross-profile leakage tests, ticket replay tests, ACL violation fail-closed tests, and FTS5 memory boundary isolation tests.

### 1.3 Explicit Out-of-Scope (Deferred to Subsequent Work Items)
- **Profile Deletion Lifecycle (`DELETE /api/v1/profiles/{id}`):** Requires 7-day soft-delete grace period, cascade purge workflows, and WAL writer quiescence; deferred to follow-on admin milestone.
- **PIN / Windows Hello Hardware Security (`PC-IDENTITY-003`):** Salted Argon2id PIN hashing, Windows Hello biometric integration, and UI PIN lock screens.
- **Multi-Profile Client Switching UI:** Flutter and React profile-switcher UI components (belongs to UI implementation passes).
- **Character Templates & Emotional Mood Models (`PC-CHAR-001` / Decision D11):** Persona instances, trait vectors, and mood states.
- **Satellite Mobile Enrollment (`D-PHONE-01B` / `ADR-0005`):** Android enrollment flows and device keypair negotiation.

---

## 2. Current Findings & Technical Root Cause

| Observation / Evidence | Verified Interpretation |
| --- | --- |
| Batch A (`007_profiles_and_owner_id_migration.py`) created `profiles` table with unique per-install Default Profile, but ORM `ProfileMixin` still resolves `default_profile_id` dynamically on flush. | Write operations will silently assign all new records to the Default Profile if an explicit session context is not strictly enforced. |
| `app/core/security.py` relies on `verify_token` matching `COMPANION_API_KEY` across all protected routes. | The shared pairing key grants ambient authority to all endpoints, conflating host administration with personal data access and allowing cross-profile data visibility. |
| React web client stores `COMPANION_API_KEY` in browser `localStorage`. | Browser script execution or malicious tabs on the host can access the master pairing key and enumerate all runtime APIs. |
| Personal-data routes (`tasks.py`, `memories.py`, `conversations.py`) filter queries by `owner_id = 'local_user'`. | Queries do not filter by `profile_id`, permitting total data conflation if multiple profiles exist in the database. |
| Non-existent routes (`GET /memories/{id}`, attachment deletion) were previously drafted in generic API matrices. | The specification must strictly reflect implemented FastAPI decorators to prevent phantom contract regressions. |

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/migrations/versions/008_profile_sessions_and_tickets.py`
- Primary Responsibility: Alembic migration for session management.
- Schema Definition:
  - Table `profile_sessions`:
    - `id`: VARCHAR(36) PRIMARY KEY (UUID).
    - `profile_id`: VARCHAR(36) FOREIGN KEY REFERENCES `profiles(id)` ON DELETE CASCADE, NOT NULL, INDEX.
    - `token_hash`: VARCHAR(64) NOT NULL UNIQUE, INDEX (SHA-256 of bearer token `psk_...`).
    - `client_type`: VARCHAR(32) NOT NULL (`desktop`, `web_browser`, `satellite_device`).
    - `client_identifier`: VARCHAR(128) NULL (e.g. host user agent or machine name).
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
- Invariants: Pre-migration WAL backup hook must execute before schema modification. Downgrade drops both tables cleanly without affecting `profiles` or entity data.

### [ADD] `backend/app/models/profile_session.py` & `backend/app/models/session_ticket.py`
- Primary Responsibility: SQLAlchemy 2.0 ORM declarations for `ProfileSession` and `SessionTicket`.
- Planned Logic: Declarative mapping with indexed fields and relationship back to `Profile`.

### [ADD] `backend/app/core/windows_security.py`
- Primary Responsibility: Enforce Windows filesystem ACL security on sensitive credentials.
- Planned Logic:
  - Inspect file security descriptor on Windows using `advapi32.dll` (`GetFileSecurityW` / `GetSecurityDescriptorDacl`) or deterministic `icacls` audit.
  - Verify access is granted EXCLUSIVELY to Current User SID (`S-1-5-21-...`) and `SYSTEM`.
  - Disallow inheritance from parent directories and reject any access granted to `Users`, `Everyone`, or secondary accounts.
  - Fail closed on non-Windows platforms unless configured for development mode.

### [ADD] `backend/app/core/host_admin.py`
- Primary Responsibility: Host Administrator credential lifecycle and verification.
- Planned Logic:
  - Generate and persist `desktop_admin.secret` in `%LOCALAPPDATA%\AICompanion\secrets\`.
  - Enforce Windows ACL verification prior to loading.
  - Issue single-use bootstrap tickets (`ptk_...`) bound to specified `profile_id` with 60-second TTL.
  - Completely isolated from `COMPANION_API_KEY`.

### [MODIFY] `backend/app/core/security.py` & `backend/app/api/deps.py`
- Primary Responsibility: Authentication dependencies and context resolution.
- Planned Logic:
  - Add `get_current_profile_session(credentials: HTTPAuthorizationCredentials) -> ProfileSession`:
    - Hashes token via SHA-256 and queries `profile_sessions`.
    - Validates `revoked_at is None` and `expires_at > utcnow()`.
    - Updates `last_active_at` asynchronously or throttled.
    - Returns session object containing verified `profile_id`.
  - Add `require_host_admin(credentials: HTTPAuthorizationCredentials) -> bool`:
    - Validates against `desktop_admin.secret`.
    - Constant-time comparison (`secrets.compare_digest`).
  - Modify `verify_token`:
    - Retain for host-level infrastructure routes (`/health`, `/api/v1/model/*`).
    - Statically disallowed on personal-data routes.

### [ADD] `backend/app/routers/auth.py`
- Primary Responsibility: Ticket issuance and exchange endpoints.
- Planned Logic:
  - `POST /api/v1/auth/session/exchange`:
    - Public / loopback endpoint.
    - Accepts `{"ticket": "ptk_..."}`.
    - Atomically verifies and marks `redeemed_at = utcnow()`.
    - Mints `ProfileSession`, stores hash, and returns `{"token": "psk_...", "profile_id": "...", "expires_at": "..."}`.
  - `POST /api/v1/auth/session/revoke`:
    - Revokes current `ProfileSession`.
  - `POST /api/v1/auth/bootstrap/ticket`:
    - Requires Host Admin authority.
    - Mints single-use ticket bound to requested `profile_id`.

### [ADD] `backend/app/routers/profiles.py`
- Primary Responsibility: Minimal Profile CRUD.
- Planned Logic:
  - `GET /api/v1/profiles`: Host Admin returns all profiles; Profile Session returns `[current_profile]`.
  - `POST /api/v1/profiles`: Requires Host Admin. Creates new profile with generated UUID.
  - `GET /api/v1/profiles/{id}`: Requires Host Admin OR `session.profile_id == id`.
  - `PATCH /api/v1/profiles/{id}`: Requires Host Admin OR `session.profile_id == id`. Updates metadata (`display_name`, `avatar`, `theme`).
  - `DELETE /api/v1/profiles/{id}`: Returns `501 Not Implemented` with detail `Profile deletion lifecycle is deferred to administrative release`.

### [MODIFY] `backend/app/routers/tasks.py`
- Primary Responsibility: Isolate tasks to authenticated Profile Session.
- Planned Logic:
  - Replace `dependencies=[Depends(verify_token)]` with `session: ProfileSession = Depends(get_current_profile_session)`.
  - Drop all fallback to `owner_id == 'local_user'`.
  - Enforce `task.profile_id == session.profile_id` on all queries (`GET /tasks`), mutations (`POST /tasks`, `PATCH /tasks/{id}`), and deletion (`DELETE /tasks/{id}`, `DELETE /tasks/{id}/permanent`).

### [MODIFY] `backend/app/routers/memories.py` & `backend/app/services/memory/service.py`
- Primary Responsibility: Isolate long-term memory queries and FTS5 search to authenticated Profile Session.
- Planned Logic:
  - Require `ProfileSession` on `GET /memories/search` and `POST /memories`.
  - Scope FTS5 full-text queries strictly by `WHERE profile_id = :session_profile_id`.
  - Ensure memory creation explicitly records `profile_id = session.profile_id`.

### [MODIFY] `backend/app/routers/conversations.py`
- Primary Responsibility: Isolate conversation history, SSE streaming turns, and title generation.
- Planned Logic:
  - Require `ProfileSession` across:
    - `GET /conversations`
    - `POST /conversations`
    - `GET /conversations/{id}`
    - `PATCH /conversations/{id}`
    - `DELETE /conversations/{id}`
    - `POST /conversations/{id}/generate-title`
    - `POST /conversations/{id}/messages` (SSE streaming turn)
    - `GET /conversations/{id}/attachments/{aid}/preview`
  - Reject access with `404 Not Found` (fail-closed ID obfuscation) if conversation belongs to another profile.

### [MODIFY] `frontend/web/src/context/BackendContext.tsx` & `frontend/web/src/services/api/index.ts`
- Primary Responsibility: React client Profile Session integration and credential retirement.
- Planned Logic:
  - Support URL query param bootstrap `?ticket=ptk_...` on startup.
  - Execute exchange via `POST /api/v1/auth/session/exchange`.
  - Store `sessionToken` exclusively in memory React state (not in `localStorage`).
  - Safely retire legacy pairing key from `localStorage` once session is established.

### [MODIFY] `frontend/flutter/packages/companion_api/lib/src/companion_api_client.dart`
- Primary Responsibility: Flutter desktop API client profile session awareness.
- Planned Logic:
  - Pass `Authorization: Bearer psk_...` on profile-scoped endpoints.
  - Retain Host Admin authorization for desktop management calls.

---

## 4. Step-by-Step Pseudocode & Implementation Sequence

### Phase B.1: Schema Migration 008 & ORM Models
1. Author `migrations/versions/008_profile_sessions_and_tickets.py` creating `profile_sessions` and `session_tickets`.
2. Connect pre-migration safety backup hook to ensure automated snapshotting prior to upgrade.
3. Implement `ProfileSession` and `SessionTicket` models in `backend/app/models/`.
4. Verify migration up and down with SQLite in isolation:
   ```bash
   alembic upgrade head
   alembic downgrade -1
   ```

### Phase B.2: Host Admin Authority & Windows ACL Security
1. Implement `backend/app/core/windows_security.py` validating that secret files have ACL restricted exclusively to Current User SID and `SYSTEM`.
2. Implement `backend/app/core/host_admin.py` managing `desktop_admin.secret` and bootstrap ticket minting.
3. Add unit tests for SID extraction, ACL verification, and fail-closed behavior on multi-user permissions.

### Phase B.3: Session Token Exchange & Auth Endpoints
1. Implement `POST /api/v1/auth/bootstrap/ticket` requiring Host Admin.
2. Implement `POST /api/v1/auth/session/exchange`:
   - Validates `ptk_...` hash.
   - Atomically consumes ticket (`redeemed_at = utcnow()`).
   - Mints `psk_...` and stores hash in `profile_sessions`.
3. Implement `POST /api/v1/auth/session/revoke` invalidating active session.

### Phase B.4: Authentication Dependencies & Removal of Implicit Defaults
1. Create `get_current_profile_session` dependency in `backend/app/api/deps.py`.
2. Remove implicit fallback to Default Profile ID in write operations (`ProfileMixin` requires explicit profile attribution on session-guarded writes).
3. Enforce fail-closed `401 Unauthorized` / `403 Forbidden` on requests lacking a valid session token.

### Phase B.5: Personal-Data Route Isolation & Matrix Reconciliation
1. Refactor `tasks.py`:
   - Drop legacy pairing fallback on `GET /tasks` and `POST /tasks`.
   - Update `DELETE /tasks/{id}/permanent` to enforce `task.profile_id == session.profile_id`.
2. Refactor `memories.py` and `service.py`:
   - Drop legacy fallback on `GET /memories/search` and `POST /memories`.
   - Enforce FTS5 search query filtering by `profile_id`.
3. Refactor `conversations.py`:
   - Require `ProfileSession` on `POST /conversations/{id}/generate-title`, `POST /conversations/{id}/messages` (SSE), and `GET /conversations/{id}/attachments/{aid}/preview`.
   - Verify non-existent routes (`GET /memories/{id}`, loose attachment listing/deletion) remain absent.

### Phase B.6: Minimal Profile CRUD
1. Implement `GET /api/v1/profiles`, `POST /api/v1/profiles`, `GET /api/v1/profiles/{id}`, and `PATCH /api/v1/profiles/{id}`.
2. Explicitly stub `DELETE /api/v1/profiles/{id}` returning `501 Not Implemented`.

### Phase B.7: Client Compatibility & Memory-Only Storage
1. Update `frontend/web/src/context/BackendContext.tsx` to handle bootstrap ticket exchange on load.
2. Store session token strictly in React state; remove `localStorage.setItem('apiKey', ...)`.
3. Update Flutter `companion_api` client to support bearer session tokens.

### Phase B.8: Security Regression & Verification Suite
1. Implement adversarial tests in `backend/tests/test_profile_authorization.py`:
   - Session A attempting to read/write/delete Session B's conversations, messages, tasks, and memories.
   - Single-use ticket replay attack rejection.
   - Expired ticket and expired session rejection.
   - Pairing key (`COMPANION_API_KEY`) rejected on all personal-data routes.
2. Run full backend, flutter analyze, and web test suites.

---

## 5. Acceptance Criteria & Verification Plan

### Automated Repository Checks
- [ ] `pytest backend/tests/test_migration_008.py` passes up and down without data loss.
- [ ] `pytest backend/tests/test_profile_authorization.py` verifies 100% fail-closed isolation across personal-data routes.
- [ ] `pytest backend/tests/test_profile_sessions.py` verifies ticket generation, single-use burning, TTL expiry, and revocation.
- [ ] `pytest backend/tests/test_windows_security.py` confirms Windows SID/ACL enforcement and fail-closed behavior on loose permissions.
- [ ] Full backend test suite passes with zero regressions (`pytest backend/tests`).
- [ ] `flutter analyze` passes across all Flutter monorepo packages.
- [ ] `npm test` and `npm run lint` pass across `frontend/web`.

### Manual / User-Owned Checks
- [ ] Inspect `%LOCALAPPDATA%\AICompanion\secrets\desktop_admin.secret` using `icacls` to confirm read/write rights belong strictly to Current User SID.
- [ ] Launch Web client with bootstrap ticket; confirm session exchanges successfully and `localStorage` contains no persistent API keys.
- [ ] Verify that attempting to access `/api/v1/tasks` with only `COMPANION_API_KEY` returns HTTP 401/403.

---

## 6. Risks, Recovery & Rollback

- **Risk: Accidental Lockout of Legacy Single-User Clients.**
  - *Mitigation:* The local desktop client maintains Host Admin authority and automatically mints an active Default Profile session upon launch, ensuring uninterrupted operation for single-user desktop users.
- **Risk: Browser Refresh Session Loss.**
  - *Mitigation:* While long-term storage is in-memory for maximum security, browser sessions can exchange an encrypted, short-lived session cookie (`SameSite=Strict`, `HttpOnly`) or request silent desktop re-authorization via local loopback IPC.
- **Risk: Database Corruption During Migration 008.**
  - *Mitigation:* Pre-migration WAL-safe backup snapshot hook automatically executes before Alembic 008 DDL runs, creating an atomically verified restore point.
- **Rollback Procedure:**
  - Execute `alembic downgrade -1` to drop `session_tickets` and `profile_sessions`.
  - Revert route dependencies to legacy single-user mode. No personal user data or profile entities are deleted or modified during rollback.
