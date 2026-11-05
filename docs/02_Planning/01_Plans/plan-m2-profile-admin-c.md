# Implementation Plan: Milestone M2 Batch C — Persistent Personal Profile, Local Profile Administration & Frictionless Switching

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** PHASE 1 REVISED PLAN PUBLISHED — AWAITING HUMAN OWNER & INDEPENDENT REVIEWER APPROVAL
- **Delivery Level:** Level C — Sensitive Design
- **Scope Mode:** PLANNING (`PC-IDENTITY-004`, `PC-CLIENT-005`)
- **Authorized Branch:** `feature/m2-profile-admin-c`
- **Baseline Integration SHA (`develop`):** `a3b206767f813344a35b1e0663a9c4a93e333d1f`
- **Previous Plan Checkpoint SHA:** `2b2846299204ea15c286e08f5d2bb426c08dcba2`
- **Active Branch Tracker:** [`docs/01_Tracking/active/task-feature-m2-profile-admin-c.md`](../../01_Tracking/active/task-feature-m2-profile-admin-c.md)
- **Target Files (Phase 2 — Not Modified in Phase 1):**
  - `backend/app/api/v1/endpoints/profiles.py` `[MODIFY]`
  - `backend/tests/test_profile_admin.py` `[ADD]`
  - `backend/tests/test_profile_sessions.py` `[MODIFY]`
  - `contracts/openapi/openapi.json` `[MODIFY]`
  - `scripts/check_dart_openapi_parity.py` `[MODIFY]`
  - `scripts/tests/test_check_dart_openapi_parity.py` `[MODIFY]`
  - `frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart` `[ADD]`
  - `frontend/flutter/packages/companion_api/lib/companion_api.dart` `[MODIFY]`
  - `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` `[MODIFY]`
  - `frontend/flutter/packages/companion_api/test/companion_client_test.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/platform/desktop_client_settings.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/features/profiles/desktop_profile_controller.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/features/profiles/profile_access_card.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/features/profiles/profile_dialogs.dart` `[ADD]`
  - `frontend/flutter/apps/desktop/lib/features/profiles/profile_selector_header.dart` `[ADD]`
  - `frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/screens/chat_screen.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/main.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart` `[ADD]`
  - `frontend/flutter/apps/desktop/test/desktop_profile_session_test.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/test/desktop_profile_restore_test.dart` `[MODIFY]`

> **Phase 1 Revision Note:** Per Human Owner scope revision, optional Profile PIN implementation (PIN hashing, verification, lockout trackers, PIN endpoints, and PIN unlock dialogs) is deferred from Batch C to a future delivery. Batch C focuses on frictionless, persistent Personal/multi-Profile selection across Flutter and Windows restarts, local Host Admin Profile creation and renaming, safe acquire-before-teardown Profile switching, and strict preservation of existing Batch B session and cross-Profile isolation boundaries (including keeping any existing `pin_hash != None` Profiles fail-closed).

Notice: Update this plan in place during planning. After approval, switch live execution tracking to `docs/01_Tracking/active/task-feature-m2-profile-admin-c.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### 1.1 Primary Objective & UX Principle
Deliver **Milestone M2 Profile Administration Batch C** (`PC-IDENTITY-004`, `PC-CLIENT-005`) so that:
1. Local users can create and rename Profiles via trusted Desktop Host Admin authority.
2. The seeded default Profile serves as the user's initial **Personal Profile** on first launch without creating duplicate records or altering existing UUIDs.
3. Once a user selects a Profile, that selection persists across Flutter window closes, tray restores, Flutter process restarts, Local AI Runtime restarts, and Windows shutdowns/reboots (`%LOCALAPPDATA%\AI Companion\client_settings.json`).
4. Normal application startup opens the remembered Profile directly without forcing a recurring Profile picker, while strictly separating **Selected Profile preference** (a non-secret UUID) from **Authenticated Session authority** (a validated `psk_` token or bounded local Host Admin ticket exchange).
5. Switching between accessible Profiles is a single intentional user action that acquires destination authorization before clearing the previous Profile's state, preserving the current Profile if destination authorization fails.

### 1.2 Approved Batch C Scope
1. **Local Profile Creation (`POST /api/v1/profiles`):**
   - Local Host Admin authority (`Depends(require_host_admin)` over loopback, rejecting browser `Origin` and `Sec-Fetch-*` headers).
   - Server-generated UUIDv4 primary key (`Profile.id`), initial status `active`, `is_default=False` when an installation default Profile already exists (preserving `uq_profiles_single_default`), and `pin_hash=None`.
   - Bounded name validation (`1..32` characters after trimming leading/trailing whitespace, no ASCII control characters, case-insensitive uniqueness check against active non-deleted Profiles returning `409 Conflict`).
   - Automatic compatibility with Character Foundation (`PC-CHAR-001` / `PC-CHAR-005`): new Profiles start with `active_character_instance_id = None`, resolving deterministically to the immutable **Neutral Assistant** fallback and an empty personal data partition.
2. **Local Profile Renaming (`PATCH /api/v1/profiles/{profile_id}`):**
   - Local Host Admin authority (`Depends(require_host_admin)`).
   - Validates normalized display name (`1..32` chars, no control characters, no case-insensitive collision with another active Profile; permits case-only adjustments to the same Profile's name).
   - Updates `Profile.name` and `Profile.updated_at` in-place without changing `Profile.id` (UUID), `Profile.is_default`, or any associated `conversations`, `messages`, `memories`, `tasks`, `attachments`, `character_instances`, or active `profile_sessions`.
3. **Initial Personal Profile Context:**
   - Uses the already-seeded default Profile (`is_default = True`) as the initial Personal context on genuine first launch.
   - Preserves existing database records (`name = "Default Profile"` on existing or newly seeded databases remains untouched in storage unless renamed by the user via `PATCH /api/v1/profiles/{id}`).
   - Presents the default Profile in the Desktop UI with a clear `Personal / Default` badge and allows renaming its display name to `Personal` (or any valid name) without changing its UUID.
4. **Persistent Selected-Profile Preference Across Restarts:**
   - Persists the selected Profile's UUID (`selectedProfileId`), last verified session expiry (`selectedProfileSessionExpiry`), and explicit lock state (`profileExplicitlyLocked`) in `DesktopClientSettings` (`%LOCALAPPDATA%\AI Companion\client_settings.json`).
   - Distinguishes natural 12-hour TTL expiration across overnight/PC restarts (which permits a single bounded Host Admin ticket+exchange re-establishment for the remembered Profile) from explicit lock (`profileExplicitlyLocked == true`) or pre-expiry security revocation/rejection (which fails closed without auto-reauthorization).
5. **Simple, Safe Profile Switching:**
   - Acquires and exchanges the destination Profile's `SessionTicket` -> `ProfileSession` **before** clearing the current Profile's state or revoking the current session, so a failed switch preserves the active Profile and displays a clear error.
   - Once destination authorization succeeds, cancels active Chat SSE streams, increments `_configEpoch` and Studio `_sessionFenceId`, clears all in-memory personal caches/drafts, revokes the prior `ProfileSession`, activates the new session, loads the destination Profile's private state, and persists the new `selectedProfileId`.
   - Never restarts the Local AI Runtime or unloads resident LLM weights during a Profile switch.
6. **Flutter Desktop Profile Management & Selector UI:**
   - Compact **Header Profile Selector** in `DesktopNavigationRail` showing the active Profile name and offering one-click Profile switching, Create Profile, Rename Profile, and Lock Profile actions.
   - Upgraded `ProfileAccessCard` in `SettingsScreen` + reusable dialogs (`Create Profile`, `Rename Profile`) in `profile_dialogs.dart`.
   - Active Profile and Character context badges in `ChatScreen` header.

### 1.3 Explicit Exclusions (Deferred from Batch C)
- **Profile PIN Protection (Deferred):** No PIN hashing/verification (`profile_pin.py`), no PIN setup/change/remove endpoints, no PIN lockout trackers, no PIN unlock dialogs, no security questions, no recovery codes, and no Windows Hello integration in Batch C. Existing `profiles.pin_hash` column and fail-closed rejection (`403 "Profile unlock challenge is not available"` in `auth.py`) remain untouched so any pre-existing PIN-protected Profile stays protected and unavailable until a future unlock mechanism is delivered.
- **Profile Deletion & 7-Day Soft-Purge Lifecycle (`PC-IDENTITY-005`):** Belongs to Batch D.
- **Satellite / Mobile Device Enrollment (`PC-IDENTITY-003`):** Mobile satellites remain bound to one Profile (`ADR-0018`); device registry and revocation are out of scope.
- **Backup, Export & Import (`PC-RESILIENCE-*`):** Out of scope.
- **Unrelated Features:** Custom avatar uploads, per-Profile theme overrides, cloud accounts, Character Studio enhancements, Task Scheduler autostart, and Windows Toast notifications.

---

## 2. Current-State Technical Map & Root Cause Analysis

### 2.1 Subsystem Readiness Classification

| Area / Component | Current Repository Evidence | Classification | Batch C Action |
| :--- | :--- | :--- | :--- |
| **Database Schema (`profiles`, `profile_sessions`, `session_tickets`)** | `backend/migrations/versions/007_profiles_and_owner_id_migration.py`, `008_profile_sessions_and_tickets.py`, `backend/app/models/profile.py` | **Already Implemented** | `profiles` has `id VARCHAR(36)`, `name VARCHAR(32)`, `pin_hash VARCHAR(128)`, `is_default BOOLEAN` (`uq_profiles_single_default`), `status VARCHAR(16)`, `active_character_instance_id VARCHAR(64)`. **Zero database migrations required.** |
| **Host Admin & Session Bootstrap (`require_host_admin`, `/auth/bootstrap/ticket`, `/auth/session/exchange`)** | `backend/app/core/host_admin.py`, `backend/app/api/v1/endpoints/auth.py` | **Already Implemented (No Backend Changes Needed)** | `require_host_admin` verifies `X-Host-Admin-Secret` over loopback and rejects browser `Origin`/`Sec-Fetch-*`. `available_profile()` in `auth.py` already fails closed (`403`) when `profile.pin_hash is not None`. |
| **Profile Catalog & Admin Mutations (`profiles.py`)** | `backend/app/api/v1/endpoints/profiles.py` | **Reusable with Modifications** | `GET /api/v1/profiles` and `GET /api/v1/profiles/{id}` exist. Add deterministic catalog ordering (`is_default DESC, created_at ASC, id ASC`), `POST /api/v1/profiles` (create), and `PATCH /api/v1/profiles/{profile_id}` (rename). |
| **Non-Secret Desktop Preferences (`DesktopClientSettings`)** | `frontend/flutter/apps/desktop/lib/platform/desktop_client_settings.dart` | **Reusable with Modifications** | Persists `hostUrl`, `selectedModel`, and `chatZoomLevel` in `%LOCALAPPDATA%\AI Companion\client_settings.json`. Add `selectedProfileId`, `selectedProfileSessionExpiry`, and `profileExplicitlyLocked` persistence helpers. |
| **Encrypted Session Token Storage (`WindowsDpapiCredentialStore`)** | `frontend/flutter/apps/desktop/lib/platform/windows_dpapi_credential_store.dart` | **Already Implemented** | Persists DPAPI-encrypted `psk_` bearer token in `%LOCALAPPDATA%\AICompanion\profile_session.bin`. |
| **Desktop Chat & Studio Session Fencing (`DesktopChatController`, `DesktopStudioController`)** | `desktop_chat_controller.dart`, `desktop_studio_controller.dart` | **Reusable with Modifications** | `_clearPersonalState()` cancels active streams, increments `_configEpoch`, clears conversations/messages/drafts/characters, and fences Studio. Update `selectProfile()` to acquire destination session before tearing down the current Profile so failed switches preserve the current Profile. |
| **Desktop Profile Controller & UI (`DesktopProfileController`, `ProfileAccessCard`, `DesktopNavigationRail`)** | `desktop_profile_controller.dart`, `profile_access_card.dart`, `desktop_navigation_rail.dart` | **Reusable with Modifications** | Add persistent selected-Profile restoration, natural-expiry one-shot Host Admin re-bootstrap, `createProfile()`, `renameProfile()`, `lockActiveProfile()`, Navigation Rail `ProfileSelectorHeader`, and Create/Rename dialogs. |

### 2.2 Root Cause of Startup Friction & Switch Fragility in Batch B
1. **No Persistent Selected-Profile Preference Separate from the 12-Hour Session Token:**
   - In Batch B, `DesktopProfileController` only knew which Profile to restore if the 12-hour `psk_` token in `profile_session.bin` was still valid on `GET /api/v1/auth/session/me`.
   - Once the 12-hour TTL elapsed (e.g., the next day or after an overnight Windows shutdown), `/session/me` returned `401`. Because `savedToken != null`, `DesktopProfileController` set `_allowDefaultBootstrap = false` and dropped into an unauthenticated error state without remembering which Profile was selected or re-establishing a session via local Host Admin.
2. **Teardown-Before-Acquire on Profile Switch:**
   - In `DesktopChatController.selectProfile()` (`desktop_chat_controller.dart` lines 174–190), `_clearPersonalState()` and `revokeProfileSession()` were called **before** `establishProfileSession(profileId)`.
   - Consequently, if ticket issuance or exchange for the destination Profile failed (e.g., `403` on a PIN-protected Profile, `404` on an unavailable Profile, or `503` when Host Admin secret is missing), the user's previously active Profile session and in-memory chat state were already destroyed.

---

## 3. Profile Persistence, Startup Reauthorization & Switching Architecture

### 3.1 Separation of Selected Profile vs. Authenticated Session

| Concept | Storage Location | Security Classification | Lifespan & Meaning |
| :--- | :--- | :--- | :--- |
| **Selected Profile (`selectedProfileId`)** | `%LOCALAPPDATA%\AI Companion\client_settings.json` (`DesktopClientSettings`) | Non-secret user preference (UUIDv4) | Persists across Flutter restarts, runtime restarts, and Windows reboots until the user explicitly switches Profiles. Grants **zero** backend authority by itself. |
| **Session Expiry Checkpoint (`selectedProfileSessionExpiry`)** | `%LOCALAPPDATA%\AI Companion\client_settings.json` (`DesktopClientSettings`) | Non-secret UTC ISO-8601 timestamp | Records the server-issued `expires_at` of the active session for `selectedProfileId` so startup can distinguish natural 12h TTL expiration from pre-expiry server revocation. |
| **Explicit Lock Flag (`profileExplicitlyLocked`)** | `%LOCALAPPDATA%\AI Companion\client_settings.json` (`DesktopClientSettings`) | Non-secret boolean flag | Set to `true` when the user explicitly clicks **Lock Profile**, preventing startup auto-reauthorization until the user intentionally activates a Profile. |
| **Authenticated Session (`psk_...`)** | `%LOCALAPPDATA%\AICompanion\profile_session.bin` (`WindowsDpapiCredentialStore`) | Secret bearer credential (DPAPI-encrypted on disk, SHA-256 hashed in SQLite) | 12-hour TTL (`ProfileSession.expires_at`), validated on every personal-data request via `get_current_profile_session`. |

### 3.2 Startup Restoration & Bounded One-Shot Reauthorization Flow
When `DesktopProfileController.refresh(initializeDefault: true)` executes on startup / runtime attach:

```text
1. Read from DesktopClientSettings:
   - persistedProfileId = readSelectedProfileId()
   - persistedExpiry    = readSelectedProfileSessionExpiry()
   - explicitlyLocked   = readProfileExplicitlyLocked()
   Read from sessionStore:
   - savedToken         = sessionStore.readToken()

2. If explicitlyLocked == true:
   - Fetch catalog (GET /api/v1/profiles) if Host Admin is available.
   - Set selectedProfileId = persistedProfileId, activeProfileId = null.
   - Do NOT auto-authorize. Surface truthful locked status until user clicks Use/Switch Profile.

3. If savedToken != null:
   - Call chat.checkConnection(preserveSavedSessionOnFailure: true) -> probes GET /api/v1/auth/session/me.
   - Case 3A: /session/me returns 200 OK (valid, non-expired session):
       * If persistedProfileId == null || persistedProfileId == chat.authenticatedProfileId:
           - Restore directly! Set activeProfileId = selectedProfileId = chat.authenticatedProfileId.
           - Persist selectedProfileId and chat.authenticatedSessionExpiry in DesktopClientSettings.
           - Zero ticket/exchange/revoke calls.
       * If persistedProfileId != null && persistedProfileId != chat.authenticatedProfileId:
           - Attempt one-shot switch to persistedProfileId (if active and unprotected in catalog).
   - Case 3B: /session/me fails with 401/403 (savedToken is no longer valid):
       * Check if this is NATURAL TTL EXPIRY of a remembered Profile:
           isNaturalExpiry = (persistedProfileId != null) &&
                             (persistedExpiry != null) &&
                             !nowUtc.isBefore(persistedExpiry)
       * If isNaturalExpiry == true:
           - Fetch catalog (GET /api/v1/profiles).
           - Verify persistedProfileId exists in catalog with status == 'active' and pin_protected != true.
           - If eligible: execute AT MOST ONE Host Admin bootstrap (chat.selectProfile(persistedProfileId))
             using single-use POST /auth/bootstrap/ticket -> POST /auth/session/exchange.
           - If ineligible or bootstrap fails: keep selectedProfileId = persistedProfileId,
             activeProfileId = null, and show unauthenticated recovery message (never fall back to Default).
       * If isNaturalExpiry == false (session failed BEFORE its expiry timestamp, or no expiry checkpoint):
           - Treat as server revocation, foreign runtime, or deactivated Profile.
           - Fail closed: set activeProfileId = null, keep selectedProfileId = persistedProfileId,
             preserve savedToken in sessionStore so repeated restarts cannot bypass the rejection,
             and show unauthenticated recovery prompt.

4. If savedToken == null (and explicitlyLocked == false):
   - Fetch catalog (GET /api/v1/profiles).
   - Case 4A: persistedProfileId != null (remembered Profile preference exists):
       * If persistedProfileId is in catalog with status == 'active' and pin_protected != true:
           - Execute one-shot Host Admin bootstrap (chat.selectProfile(persistedProfileId)).
       * Otherwise (remembered Profile is missing, inactive, or PIN-protected):
           - Fail closed: keep selectedProfileId = persistedProfileId, activeProfileId = null,
             and show recovery error without silently switching to Default Profile.
   - Case 4B: persistedProfileId == null (genuine first launch on installation):
       * Select the seeded Personal/Default Profile (is_default == true && status == 'active' && pin_protected != true).
       * Execute one-shot Host Admin bootstrap (chat.selectProfile(defaultProfileId)) and persist
         selectedProfileId = defaultProfileId and sessionExpiresAt in DesktopClientSettings.
```

**Why this preserves all Batch B invariants:**
- No background token auto-renewal loops exist: in-session `_sessionExpiryTimer` expiry still immediately invalidates the active session and clears personal caches (`desktop_profile_expiry_test.dart`).
- Pre-expiry session rejections (`revoked`, `inactive`, `another runtime`, or missing `persistedExpiry`) still fail closed without issuing any `/ticket` or `/exchange` requests and without falling back to `Default Profile` (`desktop_profile_restore_test.dart`).
- Natural 12-hour TTL expiration across a Flutter/Windows restart seamlessly re-establishes a fresh session for the remembered `selectedProfileId` via the standard Host Admin single-use ticket + exchange pipeline.

### 3.3 Acquire-Before-Teardown Profile Switching Flow
When the user intentionally switches from Profile A to Profile B (`DesktopChatController.selectProfile(String profileId)`):

```text
1. UI sets DesktopProfileController.busy = true (disabling concurrent switch/create/rename actions).
2. Read priorToken = await _client.sessionStore.readToken() without deleting it yet.
3. Request destination authorization via Host Admin:
   - POST /api/v1/auth/bootstrap/ticket  (body: {'profile_id': profileId}, header: X-Host-Admin-Secret)
   - POST /api/v1/auth/session/exchange  (body: {'ticket': ticket})
4. If step 3 throws (e.g., 403 PIN-protected Profile, 404 unavailable, 503 Host Admin unavailable, network error):
   - Do NOT clear Profile A's state, do NOT cancel Profile A's stream, and do NOT revoke priorToken!
   - Profile A remains the active, connected Profile.
   - Surface a clear non-crashing error message in DesktopProfileController.error.
5. Once step 3 succeeds (newToken and newExpiresAt acquired for Profile B):
   - Cancel any active Profile A SSE stream (await cancelGeneration()) and clear all Profile A
     personal caches (_clearPersonalState()), incrementing _configEpoch and fencing Studio.
   - If priorToken != null && priorToken.isNotEmpty:
       * Call POST /api/v1/auth/session/revoke with Authorization: Bearer $priorToken
         (ignoring 401/403 if the old session already expired).
   - Write newToken to _client.sessionStore.writeToken(newToken).
   - Schedule _scheduleSessionExpiry(newExpiresAt).
   - Run await checkConnection() to verify the new session via /auth/session/me and load
     Profile B's active Character and conversation list.
   - If checkConnection() succeeds:
       * Persist selectedProfileId = profileId, selectedProfileSessionExpiry = newExpiresAt,
         and profileExplicitlyLocked = false in DesktopClientSettings.
   - If checkConnection() fails after Profile A was cleared:
       * Remain in truthful unauthorized state (activeProfileId = null) without exposing stale data.
```

---

## 4. Proposed File Changes & In-Place Logic

### 4.1 Backend Changes

#### `[MODIFY]` `backend/app/api/v1/endpoints/profiles.py`
- **Primary Responsibility:** Host Admin Profile catalog listing, Profile creation, and Profile renaming.
- **Schemas (`ConfigDict(extra="forbid")`):**
  - `ProfileMetadata`: `id: str`, `name: str`, `is_default: bool`, `status: str`, `pin_protected: bool`.
  - `ProfileCreateRequest`: `name: str = Field(min_length=1, max_length=64)`.
  - `ProfileUpdateRequest`: `name: str = Field(min_length=1, max_length=64)`.
- **Name Validation Helper (`_validate_and_normalize_name`):**
  - Trims leading/trailing whitespace (`normalized = raw_name.strip()`).
  - If `len(normalized) < 1` or `len(normalized) > 32`: raises `HTTPException(status_code=422, detail="Profile name must be between 1 and 32 characters")`.
  - If `any(ord(ch) < 32 or ord(ch) == 127 for ch in normalized)`: raises `HTTPException(status_code=422, detail="Profile name cannot contain control characters")`.
  - Queries active non-deleted Profiles for case-insensitive duplicate (`func.lower(Profile.name) == normalized.lower()`, `Profile.is_deleted.is_(False)`, `Profile.deleted_at.is_(None)`, excluding `Profile.id == exclude_profile_id` on rename). If a match exists, raises `HTTPException(status_code=409, detail="A Profile with this name already exists")`.
- **Endpoints:**
  1. `GET /api/v1/profiles` (`Depends(require_host_admin)`):
     - Returns active, non-deleted Profiles ordered deterministically by `Profile.is_default.desc(), Profile.created_at.asc(), Profile.id.asc()`.
  2. `POST /api/v1/profiles` (`Depends(require_host_admin)`, `status_code=201`, `response_model=ProfileMetadata`):
     - Normalizes and validates `payload.name`.
     - Checks if a default Profile already exists (`select(Profile.id).where(Profile.is_default.is_(True))`); sets `is_default = False` when one exists (preserving `uq_profiles_single_default`).
     - Creates `Profile(id=str(uuid.uuid4()), name=normalized_name, pin_hash=None, is_default=is_default, status="active")`, commits atomically, and returns `profile_metadata(profile)`.
  3. `PATCH /api/v1/profiles/{profile_id}` (`Depends(require_host_admin)`, `response_model=ProfileMetadata`):
     - Looks up active, non-deleted `Profile` by `profile_id` (`404 "Profile unavailable"` if missing/inactive/deleted).
     - Normalizes and validates `payload.name` (with `exclude_profile_id=profile_id` so case-only renames of the same Profile succeed).
     - Updates `profile.name = normalized_name` and `profile.updated_at = now_utc()`, commits atomically, and returns `profile_metadata(profile)`.

*(Note: `backend/app/api/v1/endpoints/auth.py` requires **zero modifications** in Batch C; `available_profile()` already enforces `if profile.pin_hash is not None: raise HTTPException(403, "Profile unlock challenge is not available")`.)*

---

### 4.2 Contract & Parity Tooling Changes

#### `[MODIFY]` `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`
- Export updated FastAPI OpenAPI schema with `POST /api/v1/profiles` and `PATCH /api/v1/profiles/{profile_id}` (`ProfileMetadata`, `ProfileCreateRequest`, `ProfileUpdateRequest`).
- Register the 2 new routes in `M2_ROUTE_DART_METHODS` in `scripts/check_dart_openapi_parity.py`:
  - `("POST", "/api/v1/profiles"): ("createProfile", "'profiles'")`
  - `("PATCH", "/api/v1/profiles/{profile_id}"): ("renameProfile", "'profiles/$profileId'")`
- Register `ProfileMetadata`, `ProfileCreateRequest`, and `ProfileUpdateRequest` in `SCHEMA_TO_DART_CLASS` (`profile_dto.dart`).
- Update `scripts/tests/test_check_dart_openapi_parity.py` expected verified client route count from `30` to `32`.

---

### 4.3 Flutter Package & Desktop Application Changes

#### `[ADD]` `frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart` & `[MODIFY]` `companion_client.dart`
- **DTOs (`profile_dto.dart`):**
  - `ProfileMetadata`: `id`, `name`, `isDefault`, `status`, `pinProtected`.
  - `ProfileCreateRequest`: `name`.
  - `ProfileUpdateRequest`: `name`.
- **`CompanionClient` (`companion_client.dart`):**
  - Extend `_sessionRequest` to support `method: 'GET' | 'POST' | 'PATCH'` alongside `post: bool`.
  - Add `createProfile(ProfileCreateRequest request) -> Future<ProfileMetadata>` (`POST /api/v1/profiles` via Host Admin).
  - Add `renameProfile(String profileId, ProfileUpdateRequest request) -> Future<ProfileMetadata>` (`PATCH /api/v1/profiles/$profileId` via Host Admin).
  - Add `mintAndExchangeProfileSession(String profileId) -> Future<Map<String, dynamic>>` (or update `establishProfileSession(String profileId, {bool writeToStore = true})`) and `revokeSessionToken(String token)` so `DesktopChatController.selectProfile()` can acquire the new session token **before** revoking the old token and overwriting `sessionStore`.

#### `[MODIFY]` `frontend/flutter/apps/desktop/lib/platform/desktop_client_settings.dart`
- Add non-secret Profile preference methods backed by `%LOCALAPPDATA%\AI Companion\client_settings.json`:
  - `Future<String?> readSelectedProfileId()` / `Future<void> writeSelectedProfileId(String? profileId)`
  - `Future<DateTime?> readSelectedProfileSessionExpiry()` / `Future<void> writeSelectedProfileSessionExpiry(DateTime? expiresAt)`
  - `Future<bool> readProfileExplicitlyLocked()` / `Future<void> writeProfileExplicitlyLocked(bool locked)`

#### `[MODIFY]` `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart`
- Track `String? _authenticatedProfileName` and `DateTime? _authenticatedSessionExpiry` from `GET /api/v1/auth/session/me` (cleared in `_clearPersonalState()`).
- Expose `String? get authenticatedProfileName => isConnected ? _authenticatedProfileName : null;` and `DateTime? get authenticatedSessionExpiry => isConnected ? _authenticatedSessionExpiry : null;`.
- Add `void updateAuthenticatedProfileName(String name)` so renaming the active Profile immediately updates `ChatScreen` without re-issuing a session.
- Update `selectProfile(String profileId)` to implement the **acquire-before-teardown** transition (§3.3):
  1. Read `priorToken = await _client.sessionStore.readToken()`.
  2. Call `_client.establishProfileSession(profileId, writeToStore: false)` to mint the ticket and exchange it for the new session token (`newToken`, `newExpires`). If this throws, Profile A's session, caches, and active streams remain untouched and the error rethrows to `DesktopProfileController`.
  3. Once `newToken` is obtained: call `_clearPersonalState()`, `await cancelGeneration()`, `notifyListeners()`.
  4. If `priorToken != null && priorToken.isNotEmpty`, revoke `priorToken` via `_client.revokeSessionToken(priorToken)` (catching `401`/`403` `CompanionApiException`).
  5. Write `newToken` to `_client.sessionStore.writeToken(newToken)`, schedule `_scheduleSessionExpiry(newExpires)`, and await `checkConnection()`.

#### `[MODIFY]` `frontend/flutter/apps/desktop/lib/features/profiles/desktop_profile_controller.dart`
- Accept optional `DesktopClientSettings? clientSettings` in constructor (`DesktopProfileController({required this.chat, this.clientSettings})`).
- Implement the startup restoration and bounded one-shot natural-expiry reauthorization flow (§3.2).
- Add helper getters:
  - `Map<String, dynamic>? get activeProfile`
  - `String? get activeProfileName`
  - `String formatProfileDisplayName(Map<String, dynamic> profile)` (displays stored `name`, e.g., `Default Profile` or `Personal`, and surfaces `Personal / Default` context when `is_default == true`).
- Add administrative & lifecycle actions:
  - `Future<bool> switchToProfile(String profileId)`: selects and switches to `profileId`, persisting `selectedProfileId`, `selectedProfileSessionExpiry`, and `profileExplicitlyLocked = false` in `clientSettings` on success, or preserving the current active Profile and setting `error` on failure.
  - `Future<ProfileMetadata?> createProfile({required String name, bool switchImmediately = true})`: creates Profile via `chat.client.createProfile`, refreshes catalog, and optionally switches to the newly created Profile.
  - `Future<ProfileMetadata?> renameProfile({required String profileId, required String newName})`: renames Profile via `chat.client.renameProfile`, refreshes catalog, and if `profileId == activeProfileId`, updates `chat.updateAuthenticatedProfileName(updated.name)`.
  - `Future<void> lockActiveProfile()`: sets `profileExplicitlyLocked = true` in `clientSettings`, revokes the active session on the backend, and clears personal caches via `chat.invalidateProfileSession(clearStoredToken: true)`.

#### `[ADD]` `frontend/flutter/apps/desktop/lib/features/profiles/profile_dialogs.dart`
- Clean SoftGlass/Neumorphic dialogs (with zero PIN fields):
  1. `showCreateProfileDialog(BuildContext context, DesktopProfileController controller)`:
     - Display Name field (`1..32` chars, live character count, trims whitespace, inline validation, Enter-to-submit).
     - `"Switch to this Profile immediately"` checkbox (default `true`).
  2. `showRenameProfileDialog(BuildContext context, DesktopProfileController controller, {required String profileId, required String currentName, bool isDefault = false})`:
     - Pre-filled Display Name input (`1..32` chars), helper hint on default Profile (`"Tip: You can rename Default Profile to Personal"`), inline validation and `409 Conflict` error display.

#### `[ADD]` `frontend/flutter/apps/desktop/lib/features/profiles/profile_selector_header.dart` & `[MODIFY]` `desktop_navigation_rail.dart`, `desktop_shell.dart`, `main.dart`
- Wire `clientSettings` into `DesktopProfileController` in `main.dart` and pass `profileController` to `DesktopNavigationRail` in `DesktopShell`.
- `ProfileSelectorHeader` in `DesktopNavigationRail` displays the active Profile's initials avatar and name (or `"Profile Locked"`), a quick-switch popup menu listing available Profiles (with `Personal / Default` badge on the default Profile and `(Locked - PIN)` disabled indicator on any legacy PIN-protected Profile), `"Create New Profile..."`, `"Rename Current Profile..."`, `"Lock Profile"`, and `"Manage Profiles in Settings..."`.

#### `[MODIFY]` `frontend/flutter/apps/desktop/lib/features/profiles/profile_access_card.dart` & `screens/chat_screen.dart`
- **`ProfileAccessCard` (`profile_access_card.dart`):**
  - Preserves `'Use Profile'`, `'Refresh requests'`, and `'Approve request'` buttons so existing widget tests in `desktop_profile_session_test.dart` continue to work.
  - Adds `'Create Profile'`, `'Rename Profile'`, and `'Lock Profile'` actions, displays the active Profile badge (`Personal / Default` when `is_default == true`), and surfaces clear transition/error/recovery states.
- **`ChatScreen` (`chat_screen.dart`):**
  - Displays a `Profile: <Active Profile Name>` badge in `_buildHeader` alongside `This Conversation: <Character>` and `New Conversations: <Active Character>`.

---

## 5. API Contracts, Security Boundaries & Threat Model

### 5.1 REST API Endpoint Specifications

| Method & Path | Authority Realm | Request Schema | Success Response | Error Statuses & Semantics |
| :--- | :--- | :--- | :--- | :--- |
| `GET /api/v1/profiles` | Host Admin (`require_host_admin`) | None | `200 OK` -> `list[ProfileMetadata]` (ordered `is_default DESC, created_at ASC, id ASC`) | `401/403` missing/invalid Host Admin secret or browser Origin/Sec-Fetch header; `503` secret store unavailable |
| `GET /api/v1/profiles/{profile_id}` | Host Admin OR matching `ProfileSession` | None | `200 OK` -> `ProfileMetadata` | `401` invalid session; `404` foreign or non-existent/inactive Profile |
| `POST /api/v1/profiles` | Host Admin (`require_host_admin`) | `ProfileCreateRequest` (`name: str`) | `201 Created` -> `ProfileMetadata` | `401/403` non-admin caller; `409` duplicate active Profile name (case-insensitive); `422` invalid name (`<1` or `>32` chars after trim, or control chars) |
| `PATCH /api/v1/profiles/{profile_id}` | Host Admin (`require_host_admin`) | `ProfileUpdateRequest` (`name: str`) | `200 OK` -> `ProfileMetadata` | `401/403` non-admin caller; `404` Profile unavailable; `409` name conflict with another active Profile; `422` invalid name |

### 5.2 Threat Model & Concurrency Safeguards

| Threat / Boundary | Concrete Mitigation & Enforcement |
| :--- | :--- |
| **1. Unauthorized Profile Creation or Rename** | `POST /api/v1/profiles` and `PATCH /api/v1/profiles/{id}` require `Depends(require_host_admin)`. Pairing tokens (`COMPANION_API_KEY`), `ProfileSession` bearer tokens (`psk_`), remote peers, DNS-rebinding `Host` headers, and browser `Origin`/`Sec-Fetch-*` requests are rejected (`401`/`403`). |
| **2. Saved Preference Treated as Authentication Authority** | `selectedProfileId` in `client_settings.json` is never accepted by the backend. Every personal-data request still requires an active, unrevoked, non-expired `ProfileSession` (`psk_...`). Startup restoration either validates the existing `psk_` token via `/auth/session/me` or (only on natural post-expiry startup when not explicitly locked) runs a full Host Admin `/auth/bootstrap/ticket` -> `/auth/session/exchange` handshake. |
| **3. Explicit Lock or Security Revocation Undone by Startup** | Explicit lock sets `profileExplicitlyLocked = true` in `client_settings.json`, blocking startup auto-reauthorization. Server-side session revocation or foreign-runtime rejection occurs before `selectedProfileSessionExpiry`, so `isNaturalExpiry` evaluates to `false` and startup fails closed without re-authorizing. |
| **4. Failed Switch Destroying Active Profile Context** | `DesktopChatController.selectProfile()` mints and exchanges the destination `SessionTicket` -> `ProfileSession` before clearing the current Profile's state or revoking the current token. If destination authorization fails (`403`, `404`, `503`), the current Profile's session, conversations, drafts, and stream remain intact. |
| **5. Cross-Profile Data Leakage or Late Stream Callbacks** | As soon as destination session exchange succeeds, `_clearPersonalState()` and `cancelGeneration()` increment `_configEpoch`, cancel active SSE subscriptions, clear conversation/message/draft/character caches, and fence `DesktopStudioController` before loading destination data. |
| **6. Pre-Existing PIN-Protected Profiles Bypassed** | `available_profile()` in `backend/app/api/v1/endpoints/auth.py` retains `if profile.pin_hash is not None: raise HTTPException(403, "Profile unlock challenge is not available")`. Neither startup auto-reauthorization nor manual switching can open a Profile with `pin_hash != None`. |
| **7. Duplicate Active Profile Names** | `_validate_and_normalize_name` enforces case-insensitive uniqueness among active non-deleted Profiles within the SQLite transaction, returning `409 Conflict` with a clear message. |

---

## 6. Dependency-Respecting Implementation Sequence & Verification Matrix

### 6.1 Step-by-Step TDD Implementation Order (Phase 2)

```text
Step 1: Backend Profile Creation & Rename Tests and Implementation (RED -> GREEN)
  ├── Add backend/tests/test_profile_admin.py covering:
  │     - POST /api/v1/profiles: UUID generation, name trimming (1..32 chars), control-char rejection (422),
  │       case-insensitive duplicate rejection (409), is_default=False preservation, Neutral Assistant compatibility,
  │       and rejection of pairing/ProfileSession/browser callers (401/403)
  │     - PATCH /api/v1/profiles/{id}: in-place rename preserving UUID, is_default, conversations, messages,
  │       memories, tasks, characters, and active ProfileSession; case-only self-rename allowed; conflict with
  │       other active Profile rejected (409); missing/deleted Profile rejected (404)
  │     - Existing PIN-protected Profile fail-closed check (403 on /auth/bootstrap/ticket)
  └── Implement changes in backend/app/api/v1/endpoints/profiles.py

Step 2: OpenAPI Contract Export & Dart Contract Parity (RED -> GREEN)
  ├── Regenerate contracts/openapi/openapi.json from FastAPI app
  ├── Add frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart and export in companion_api.dart
  ├── Add createProfile, renameProfile, and acquire-before-teardown session helpers in companion_client.dart
  ├── Update scripts/check_dart_openapi_parity.py and scripts/tests/test_check_dart_openapi_parity.py (32 routes)
  └── Add unit tests in frontend/flutter/packages/companion_api/test/companion_client_test.dart

Step 3: DesktopClientSettings & Controller Persistence/Switching Tests (RED -> GREEN)
  ├── Extend frontend/flutter/apps/desktop/lib/platform/desktop_client_settings.dart with
  │   selectedProfileId, selectedProfileSessionExpiry, and profileExplicitlyLocked
  ├── Update desktop_chat_controller.dart (acquire-before-teardown selectProfile, authenticatedProfileName,
  │   authenticatedSessionExpiry) and desktop_profile_controller.dart (persistent restoration, bounded
  │   natural-expiry re-bootstrap, createProfile, renameProfile, switchToProfile, lockActiveProfile)
  └── Add comprehensive tests in frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart
      and update ordering assertions in desktop_profile_session_test.dart and desktop_profile_restore_test.dart

Step 4: Flutter Desktop UI Components & Widget Tests (RED -> GREEN)
  ├── Implement profile_dialogs.dart (Create & Rename dialogs), profile_selector_header.dart,
  │   profile_access_card.dart, desktop_navigation_rail.dart, desktop_shell.dart, chat_screen.dart, and main.dart
  └── Add widget tests in frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart

Step 5: Full Regression Suite & Static Analysis Verification
  └── Run all backend pytest suites, contract parity checks, Dart/Flutter analyze, and Flutter test suites
```

### 6.2 Required 16-Item Acceptance & Verification Matrix

| # | Required Acceptance Criterion | Automated Verification Coverage | Manual Windows Acceptance |
| :--- | :--- | :--- | :--- |
| **1** | First launch selects the seeded initial Personal/default Profile. | `desktop_profile_restore_test.dart`, `desktop_profile_admin_test.dart` (`first launch selects default Personal Profile and persists UUID`) | Verify fresh `client_settings.json` opens `Default Profile` automatically. |
| **2** | Existing installations retain their original Profile UUID and data. | `test_profile_model.py`, `test_migration_007.py`, `test_profile_admin.py` | Verify existing local DB retains conversations and UUID. |
| **3** | Creating a new Profile works through local Host Admin authority. | `test_profile_admin.py` (`test_create_profile_host_admin_and_validation`) | Create `"Work"` Profile in Desktop UI; verify in selector. |
| **4** | Renaming preserves all Profile ownership. | `test_profile_admin.py` (`test_rename_profile_preserves_uuid_and_owned_data`) | Rename `"Default Profile"` to `"Personal"` and `"Work"` to `"Studio"`; verify history intact. |
| **5** | Switching changes both the selected Profile and the authorized Profile Session. | `desktop_profile_session_test.dart`, `desktop_profile_admin_test.dart` | Switch between `"Personal"` and `"Studio"`; verify isolated chat lists. |
| **6** | A successful switch persists the selected UUID. | `desktop_profile_admin_test.dart` (`test_successful_switch_persists_selected_uuid_in_client_settings`) | Inspect `%LOCALAPPDATA%\AI Companion\client_settings.json` after switch. |
| **7** | Flutter restart restores the last-selected Profile. | `desktop_profile_restore_test.dart`, `desktop_profile_admin_test.dart` (both valid-token and natural-expiry re-bootstrap across controller recreation) | Close Flutter app (Exit Companion), relaunch, verify `"Studio"` opens directly. |
| **8** | PC restart behavior is covered through persisted-state tests and later physical Windows acceptance. | Disposable temp-directory tests combining `DesktopClientSettings` + `WindowsDpapiCredentialStore` across simulated process restarts | Reboot physical Windows PC, launch AI Companion, verify `"Studio"` opens directly without picker. |
| **9** | Expired sessions never become valid merely because Profile selection was saved. | `test_profile_sessions.py`, `desktop_profile_expiry_test.dart`, `desktop_profile_admin_test.dart` | Verify expired `psk_` is rejected by `/session/me` and requires fresh Host Admin ticket exchange. |
| **10** | An explicitly revoked/locked session is not silently reauthorized. | `desktop_profile_restore_test.dart` (pre-expiry 401 rejection), `desktop_profile_admin_test.dart` (`profileExplicitlyLocked` test) | Click `Lock Profile`, restart Flutter app, verify app remains locked until user clicks `Use Profile`. |
| **11** | Failed switching preserves the previous authorized Profile where possible. | `desktop_profile_admin_test.dart` (`test_failed_switch_preserves_current_profile_session_and_caches`) | Attempt switch to a fail-closed/unavailable Profile; verify current Profile stays active. |
| **12** | Cross-Profile conversations, memories, Characters, drafts, and requests remain isolated. | `test_profile_authorization.py`, `desktop_profile_session_test.dart`, `desktop_profile_admin_test.dart` | Verify conversations, drafts, and active Character do not bleed across `"Personal"` and `"Studio"`. |
| **13** | The Runtime and resident model survive Profile switching. | `desktop_profile_admin_test.dart` (verifies zero `/system/shutdown` or `/models/unload` calls on switch) | Verify loaded model stays `MODEL_READY` with same runtime PID across Profile switches. |
| **14** | Existing Profile Session and Character Studio regression tests pass. | `test_profile_sessions.py`, `desktop_studio_controller_test.dart`, `studio_screen_test.dart` | Switch Profiles while Character Studio has a selected Character; verify clean Studio reload. |
| **15** | Existing PIN-protected Profiles remain fail-closed rather than becoming accessible without authentication. | `test_profile_sessions.py` (`test_admin_cannot_be_used_by_browser_and_pin_fails_closed`), `desktop_profile_admin_test.dart` | Verify a Profile with `pin_hash != None` returns `403` and cannot be opened. |
| **16** | OpenAPI/Dart parity and relevant Flutter tests pass. | `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py` (`32` routes) | Run parity checker and full `flutter analyze` + `flutter test`. |

### 6.3 Automated Verification Commands

```powershell
# 1. Backend Profile Admin, Session & Full Regression Suite
backend\.venv\Scripts\python.exe -m pytest backend/tests/test_profile_admin.py backend/tests/test_profile_sessions.py backend/tests/test_profile_authorization.py backend/tests/test_profile_model.py -v
backend\.venv\Scripts\python.exe -m pytest backend/tests -q

# 2. OpenAPI Contract Drift & Dart Parity Verification
backend\.venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check
backend\.venv\Scripts\python.exe -m unittest scripts/tests/test_check_dart_openapi_parity.py

# 3. Flutter Companion API Package Analysis & Tests
Set-Location frontend/flutter/packages/companion_api
flutter analyze
flutter test

# 4. Flutter Desktop App Analysis & Full Widget/Controller Test Suite
Set-Location frontend/flutter/apps/desktop
flutter analyze
flutter test
```

---

## 7. Risk Assessment, Rollback & Canonical Documentation Sync Plan

- **Risk Level:** **Level C — Sensitive Design** (modifies session transition ordering, startup session re-establishment rules, and Host Admin Profile mutations).
- **Rollback Plan:** Zero database migrations or external dependencies are introduced. Reverting the branch cleanly restores Batch B behavior without any schema downgrade or persisted database incompatibility.
- **Phase 3 Canonical Documentation Sync Plan:**
  - Update [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../../04_Architecture/02_Data_and_Security/profiles-and-devices.md) and [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](../../04_Architecture/02_Data_and_Security/authentication-and-secrets.md) to document implemented `POST /api/v1/profiles`, `PATCH /api/v1/profiles/{id}`, persistent selected-Profile UUID preference, bounded natural-expiry Host Admin startup re-establishment, and acquire-before-teardown Profile switching (while preserving target architecture notes for deferred optional PIN unlock and Batch D 7-day deletion).
  - Update [`docs/02_Planning/00_Master/WBS.md`](../../02_Planning/00_Master/WBS.md), [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](../../02_Planning/00_Master/DELIVERY_INDEX.md), [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../../02_Planning/00_Master/SPRINT_ROADMAP.md), [`docs/02_Planning/00_Master/MASTER_CHECKLIST.md`](../../02_Planning/00_Master/MASTER_CHECKLIST.md), [`docs/01_Tracking/task.md`](../../01_Tracking/task.md), and [`CHANGELOG.md`](../../../CHANGELOG.md).

---

## 8. Revised Material Decisions & Tradeoff Analysis

### Decision 1: Local Selected-Profile Persistence Mechanism (`DesktopClientSettings`)
- **Design:** Persist `selectedProfileId` (UUIDv4), `selectedProfileSessionExpiry` (UTC ISO-8601), and `profileExplicitlyLocked` (bool) in `%LOCALAPPDATA%\AI Companion\client_settings.json` via `DesktopClientSettings`, keeping the encrypted `psk_` session token isolated in `%LOCALAPPDATA%\AICompanion\profile_session.bin` (`WindowsDpapiCredentialStore`).
- **Rationale:** Reuses the existing non-secret preference file (`client_settings.json`), survives Flutter restarts and Windows reboots, and maintains strict separation between a non-secret UI selection preference and a DPAPI-protected bearer credential.
- **Policy Conflict:** None.

### Decision 2: Distinguishing Natural Session Expiry from Explicit Lock or Security Revocation
- **Design:**
  1. When a user explicitly clicks **Lock Profile**, `profileExplicitlyLocked = true` is persisted in `client_settings.json` and the server session is revoked. Startup sees `profileExplicitlyLocked == true` and does **not** auto-reauthorize.
  2. When a session is established or verified, its server-issued `expires_at` timestamp is recorded in `selectedProfileSessionExpiry`.
  3. On startup, if `GET /api/v1/auth/session/me` returns `401`, automatic Host Admin single-use ticket re-establishment (`POST /auth/bootstrap/ticket` -> `POST /auth/session/exchange`) is attempted **at most once**, and **only** when `profileExplicitlyLocked == false`, `selectedProfileId != null`, and `selectedProfileSessionExpiry != null && !nowUtc.isBefore(selectedProfileSessionExpiry)` (i.e. natural 12-hour TTL expiration).
  4. If a saved session is rejected **before** its `expires_at` timestamp (or has no recorded expiry checkpoint), startup treats it as a server-side revocation, database/runtime mismatch, or invalid credential and fails closed without auto-reauthorizing and without falling back to `Default Profile`.
- **Rationale:** Gives users frictionless continuity across overnight Windows reboots (when the 12-hour `ProfileSession` TTL naturally expires) while preserving 100% of Batch B's fail-closed guarantees for revoked tokens, foreign runtimes, and in-session expiry timers.
- **Policy Conflict:** None. All existing tests in `desktop_profile_restore_test.dart` and `desktop_profile_expiry_test.dart` remain valid.

### Decision 3: Acquire-Before-Teardown Profile Switch Ordering (Focused Adjustment to 2 Batch B Test Assertions)
- **Design:** During an explicit Profile switch (`DesktopChatController.selectProfile(destinationId)`), the client first requests `POST /api/v1/auth/bootstrap/ticket` and `POST /api/v1/auth/session/exchange` for the destination Profile before clearing the current Profile's caches or calling `POST /api/v1/auth/session/revoke` on the prior session token.
- **Rationale:** Directly satisfies the confirmed product requirement that **if destination authorization fails, the current Profile and its active session/state are preserved**. Once the destination session is acquired, the client immediately clears all prior personal caches, increments `_configEpoch` (dropping any late SSE tokens or in-flight reads from the old Profile), revokes the old `psk_` token on the server, and activates the new token.
- **Identified Test Adjustment Requiring Approval:**
  - Two existing Batch B unit tests (`desktop_profile_session_test.dart` line 56 and `desktop_profile_restore_test.dart` line 305) currently assert the HTTP mutation sequence `['/api/v1/auth/session/revoke', '/api/v1/auth/bootstrap/ticket', '/api/v1/auth/session/exchange']` because Batch B revoked the old session before requesting the new ticket.
  - With acquire-before-teardown switching, the HTTP mutation sequence on a successful switch is `['/api/v1/auth/bootstrap/ticket', '/api/v1/auth/session/exchange', '/api/v1/auth/session/revoke']` (where `/revoke` authenticates with the captured `psk_old` token while `psk_new` is stored in `sessionStore`). All isolation assertions (empty conversations, cleared drafts, rejected late loads) remain identical.
- **Approval Needed:** Confirm updating the mutation-order assertion in those two tests from `revoke -> ticket -> exchange` to `ticket -> exchange -> revoke` to support preserving the active Profile when a switch fails.

### Decision 4: Proportionate Profile Name Uniqueness & First-Run Personal Profile Label
- **Design:**
  - Enforce case-insensitive display name uniqueness among active non-deleted Profiles (`func.lower(Profile.name) == normalized.lower()`) inside `POST /api/v1/profiles` and `PATCH /api/v1/profiles/{id}` (`409 Conflict`), without adding a database migration or locking framework.
  - Preserve the seeded `Default Profile` database name and UUID for backward compatibility; annotate `is_default == true` Profiles with a `Personal / Default` badge in the Desktop UI and allow users to rename the Profile to `Personal` in-place via `PATCH /api/v1/profiles/{id}`.
- **Policy Conflict:** None.
