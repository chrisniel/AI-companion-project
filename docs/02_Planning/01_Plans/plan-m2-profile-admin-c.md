# Implementation Plan: Milestone M2 Batch C — Profile Administration, PIN Protection & Desktop Profile Switching

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** PHASE 1 PLAN PUBLISHED — AWAITING HUMAN OWNER & INDEPENDENT REVIEWER APPROVAL
- **Delivery Level:** Level C — Sensitive Design
- **Scope Mode:** PLANNING (`PC-IDENTITY-004`, `PC-CLIENT-005`)
- **Authorized Branch:** `feature/m2-profile-admin-c`
- **Baseline Integration SHA (`develop`):** `a3b206767f813344a35b1e0663a9c4a93e333d1f`
- **Active Branch Tracker:** [`docs/01_Tracking/active/task-feature-m2-profile-admin-c.md`](../../01_Tracking/active/task-feature-m2-profile-admin-c.md)
- **Target Files (Phase 2 — Not Modified in Phase 1):**
  - `backend/app/core/profile_pin.py` `[ADD]`
  - `backend/app/api/v1/endpoints/profiles.py` `[MODIFY]`
  - `backend/app/api/v1/endpoints/auth.py` `[MODIFY]`
  - `backend/tests/test_profile_admin_and_pin.py` `[ADD]`
  - `backend/tests/test_profile_sessions.py` `[MODIFY]`
  - `contracts/openapi/openapi.json` `[MODIFY]`
  - `scripts/check_dart_openapi_parity.py` `[MODIFY]`
  - `scripts/tests/test_check_dart_openapi_parity.py` `[MODIFY]`
  - `frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart` `[ADD]`
  - `frontend/flutter/packages/companion_api/lib/companion_api.dart` `[MODIFY]`
  - `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` `[MODIFY]`
  - `frontend/flutter/packages/companion_api/test/companion_client_test.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/features/profiles/desktop_profile_controller.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/features/profiles/profile_access_card.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/features/profiles/profile_dialogs.dart` `[ADD]`
  - `frontend/flutter/apps/desktop/lib/features/profiles/profile_selector_header.dart` `[ADD]`
  - `frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/lib/screens/chat_screen.dart` `[MODIFY]`
  - `frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart` `[ADD]`
  - `frontend/flutter/apps/desktop/test/desktop_profile_session_test.dart` `[MODIFY]`

Notice: Update this plan in place during planning. After approval, switch live execution tracking to `docs/01_Tracking/active/task-feature-m2-profile-admin-c.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### 1.1 Primary Objective
Deliver **Milestone M2 Profile Administration Batch C** (`PC-IDENTITY-004` and `PC-CLIENT-005`) to enable local PC Host Administrators to create Profiles, rename existing Profiles while preserving identity and owned data, configure and verify optional numeric Profile PIN protection, and securely select and switch between unprotected and PIN-protected Profiles in the Flutter Desktop client with complete cross-Profile state isolation.

### 1.2 Approved Batch C Scope
1. **Create Profiles (`POST /api/v1/profiles`):**
   - Local Host Admin flow (`Depends(require_host_admin)` over loopback, rejecting browser `Origin` and `Sec-Fetch-*` headers).
   - Display name normalization and validation (`1..32` characters after trimming leading/trailing whitespace, no control characters, case-insensitive uniqueness check against active non-deleted Profiles).
   - Server-generated UUIDv4 identity (`Profile.id`), initial status `active`, `is_default=False` (preserving the single installation Default Profile invariant enforced by partial unique index `uq_profiles_single_default`), and optional initial numeric PIN (`4` or `6` digits) hashed atomically at creation.
   - Automatic compatibility with Character Foundation (`PC-CHAR-001` / `PC-CHAR-005`): new Profiles start with `active_character_instance_id = None`, which deterministically resolves to the immutable **Neutral Assistant** fallback and an isolated empty personal data partition.
2. **Rename Existing Profiles (`PATCH /api/v1/profiles/{profile_id}`):**
   - Authenticated local Host Admin rename flow (`Depends(require_host_admin)`).
   - Validates normalized name (`1..32` chars, no control characters, no case-insensitive collision with another active Profile; allows case-only adjustments to the same Profile's existing name).
   - Updates `Profile.name` and `Profile.updated_at` in-place without altering `Profile.id` (UUID) or invalidating owned `conversations`, `messages`, `memories`, `tasks`, `attachments`, `character_instances`, or active `profile_sessions`.
3. **Optional Profile PIN Protection (`PUT /api/v1/profiles/{profile_id}/pin` & `POST /api/v1/auth/bootstrap/ticket`):**
   - Supports setting a PIN during or after Profile creation, changing an existing PIN, or removing an existing PIN.
   - Replaces the Batch B fail-closed stub (`"Profile unlock challenge is not available"`) with a real cryptographic PIN verification challenge during ticket issuance (`POST /api/v1/auth/bootstrap/ticket`).
   - Uses Python 3.11 standard-library memory-hard `hashlib.scrypt` (`N=16384, r=8, p=1, dklen=32`) with a 16-byte CSPRNG salt (`secrets.token_bytes(16)`) and constant-time digest comparison (`secrets.compare_digest`). No new third-party dependencies or database schema migrations are required.
   - Enforces per-Profile failed-attempt throttling and cooldown lockout (`429 Too Many Requests` with `retry_after_seconds`) to mitigate local brute-force guessing.
   - Never logs, echoes, or persists plaintext PINs on backend or Flutter client.
4. **Secure Profile Selection & Switching:**
   - Supports switching to both unprotected Profiles and PIN-protected Profiles (via interactive PIN challenge).
   - Enforces strict transition hygiene: cancels any active Chat SSE generation stream, increments `_configEpoch` / `_sessionFenceId`, clears all in-memory personal caches (conversations, messages, drafts, scroll offsets, character cache, Studio draft state), revokes the previous `ProfileSession` (`POST /api/v1/auth/session/revoke`), and mints/exchanges a fresh `SessionTicket` -> `ProfileSession` for the target Profile.
   - Never reuses the previous Profile's session token as authority for the newly selected Profile.
   - Preserves Local AI Runtime and loaded model state across Profile switches (switching Profiles never restarts the runtime or unloads VRAM weights).
   - Preserves fail-closed session restoration on startup and runtime expiry: if a saved `psk_` session is expired, revoked, or rejected, the client clears personal state and prompts the user to select/unlock a Profile without silently falling back to the Default Profile.
5. **Flutter Desktop Profile Management & Switching Experience:**
   - Adds a compact **Header Profile Selector Chip** in `DesktopNavigationRail` for at-a-glance active Profile visibility and quick switching/locking from any screen.
   - Upgrades `ProfileAccessCard` in `SettingsScreen` and adds reusable SoftGlass/Neumorphic dialogs (`profile_dialogs.dart`) for **Create Profile**, **Rename Profile**, **Configure/Change/Remove PIN**, and **Unlock PIN-Protected Profile**.
   - Surfaces active Profile name alongside active Character context in `ChatScreen`.

### 1.3 Explicit Exclusions (Deferred to Batch D or Later)
- **Profile Deletion & Soft-Purge Lifecycle (`PC-IDENTITY-005`):** Soft-deleting Profiles, 7-day recoverable `pending_purge` state, Profile restoration, and permanent hard purge belong strictly to **Batch D**.
- **Satellite / Device Enrollment (`PC-IDENTITY-003`):** Mobile/satellite public-key enrollment, device registry, and per-device revocation.
- **Mobile Profile Management:** Production Android client implementation (`MOBILE_WBS.md`).
- **Backup, Export & Import (`PC-RESILIENCE-*`):** Profile archive export/import and staging restore.
- **Unrelated UI / Schema Features:** Custom avatar file uploads (`avatar_url` remains optional/null in Batch C; UI derives deterministic initials badges), per-Profile theme overrides, cloud identity/accounts, or new Character Studio features.

---

## 2. Current-State Technical Map & Root Cause Analysis

### 2.1 Subsystem Readiness Classification

| Area / Component | Current Repository Evidence | Classification | Notes & Batch C Action |
| :--- | :--- | :--- | :--- |
| **Database Schema (`profiles`, `profile_sessions`, `session_tickets`)** | `backend/migrations/versions/007_profiles_and_owner_id_migration.py`, `008_profile_sessions_and_tickets.py`, `backend/app/models/profile.py` | **Already Implemented** | `profiles` already has `id VARCHAR(36)`, `name VARCHAR(32)`, `pin_hash VARCHAR(128)`, `is_default BOOLEAN` with partial unique index `uq_profiles_single_default`, `status VARCHAR(16)`, `active_character_instance_id VARCHAR(64)`, and `TimestampMixin` / `SoftDeleteMixin`. **Zero new DB migrations required.** |
| **Host Admin Authority (`require_host_admin`)** | `backend/app/core/host_admin.py` | **Already Implemented** | Enforces loopback peer + Host header check, rejects browser `Origin` and `Sec-Fetch-Site` headers, and verifies `X-Host-Admin-Secret` against `%LOCALAPPDATA%\AICompanion\secrets\desktop_admin.secret` via `secrets.compare_digest`. |
| **Profile Catalog Read (`GET /api/v1/profiles`, `GET /api/v1/profiles/{id}`)** | `backend/app/api/v1/endpoints/profiles.py` | **Reusable with Modifications** | Returns `ProfileMetadata(id, name, is_default, status, pin_protected)`. Needs deterministic ordering (`is_default DESC, created_at ASC, id ASC`) and new `POST /profiles`, `PATCH /profiles/{id}`, and `PUT /profiles/{id}/pin` endpoints. |
| **Session Ticket Bootstrap & Exchange (`POST /auth/bootstrap/ticket`, `POST /auth/session/exchange`)** | `backend/app/api/v1/endpoints/auth.py` | **Reusable with Modifications** | Currently `available_profile()` raises `HTTPException(403, "Profile unlock challenge is not available")` whenever `profile.pin_hash is not None` in both `/bootstrap/ticket` and `/session/exchange`. Must be updated so `/bootstrap/ticket` verifies `payload.pin` (with throttling) when `pin_hash` is set, and `/session/exchange` redeems approved tickets for active non-deleted Profiles. |
| **PIN Hashing, Validation & Brute-Force Throttling** | None (`pin_hash` column exists but no KDF helper) | **Absent — Required for Batch C** | Add `backend/app/core/profile_pin.py` implementing `hashlib.scrypt` PIN derivation, constant-time verification, 4/6-digit numeric validation, and per-Profile failed-attempt cooldown lockout. |
| **Character & Personal State Isolation on New/Switched Profiles** | `backend/app/services/character_service.py`, `backend/app/core/profile_sessions.py` | **Already Implemented** | `get_active_character_state` automatically falls back to immutable `NeutralAssistantOut` when `profile.active_character_instance_id is None`. All personal-data routes enforce `session.profile_id`. |
| **Dart API Client (`CompanionClient`)** | `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` | **Reusable with Modifications** | Already implements `listProfiles()`, `establishProfileSession()`, `getOwnSession()`, `revokeProfileSession()`, and `approveBrowserRequest()`. Needs typed `ProfileMetadataDto` and methods for `createProfile()`, `renameProfile()`, `updateProfilePin()`, and optional `pin` parameter on `establishProfileSession()` / `approveBrowserRequest()`. |
| **Desktop Session & Cache Fencing (`DesktopChatController`, `DesktopStudioController`)** | `desktop_chat_controller.dart`, `desktop_studio_controller.dart` | **Reusable with Modifications** | `_clearPersonalState()` and `selectProfile()` already revoke prior session, cancel SSE streams, increment `_configEpoch`, clear conversation/message/draft/character caches, and fence `DesktopStudioController`. Needs optional `pin` support in `selectProfile()` and `authenticatedProfileName` exposure for UI headers. |
| **Desktop Profile Controller & UI (`DesktopProfileController`, `ProfileAccessCard`, `DesktopNavigationRail`)** | `desktop_profile_controller.dart`, `profile_access_card.dart`, `desktop_navigation_rail.dart` | **Reusable with Modifications** | Currently read-only selector that disables `pin_protected == true` Profiles and has no create/rename/PIN UI or rail header chip. Needs full CRUD/PIN/unlock actions, dialogs, and navigation rail Profile chip. |

### 2.2 Root Cause of Current PIN-Protected Profile Refusal
In `backend/app/api/v1/endpoints/auth.py` (lines 92–100), `available_profile(db, profile_id)` unconditionally rejects any Profile where `profile.pin_hash is not None`:
```python
if profile.pin_hash is not None:
    raise HTTPException(403, "Profile unlock challenge is not available")
```
Furthermore, `available_profile()` is invoked at **two** stages:
1. Line 135 inside `approve_profile` (`POST /api/v1/auth/bootstrap/ticket`).
2. Line 191 inside `exchange_session` (`POST /api/v1/auth/session/exchange`).

To resolve this safely in Batch C:
- `POST /api/v1/auth/bootstrap/ticket` (Host Admin) is the single ticket-issuance and approval gate. When `profile.pin_hash is not None`, `approve_profile` must enforce per-Profile lockout status and verify `payload.pin` against `profile.pin_hash` before issuing a native `ptk_` ticket or approving a browser `request_id`.
- `POST /api/v1/auth/session/exchange` redeems an already-approved single-use `SessionTicket` (`approved_at IS NOT NULL`, `redeemed_at IS NULL`, `expires_at > now`). At exchange time, the backend must verify that the target Profile is still active and non-deleted (`status == "active"`, `is_deleted == False`, `deleted_at is None`), and any PIN modification (`PUT /api/v1/profiles/{profile_id}/pin`) must atomically expire all unredeemed `SessionTicket` rows for that Profile so a ticket minted prior to a PIN change can never be redeemed afterward.

---

## 3. Proposed File Changes & Detailed Architecture

### 3.1 Backend Changes

#### `[ADD]` `backend/app/core/profile_pin.py`
- **Primary Responsibility:** Cryptographic PIN derivation, format validation, constant-time verification, and per-Profile brute-force lockout accounting.
- **PIN Format Validation (`validate_pin_format`):**
  - Accepts only ASCII digit strings of length **4 or 6** (`re.fullmatch(r"\d{4}|\d{6}", pin)` and `pin.isascii()`), matching `docs/05_Design/02_Profile_Selector_and_Privacy.md` §3.1 (*"4-digit or 6-digit numeric PIN"*).
  - Raises `HTTPException(status_code=422, detail="PIN must be a 4-digit or 6-digit numeric code")` on invalid format without logging the submitted value.
- **PIN Derivation (`hash_profile_pin`):**
  - Uses Python 3.11 stdlib `hashlib.scrypt(pin.encode("utf-8"), salt=salt, n=16384, r=8, p=1, maxmem=33_554_432, dklen=32)` with `salt = secrets.token_bytes(16)`.
  - Encodes salt and 32-byte digest with URL-safe Base64 (no padding) into an 83-character self-describing string:
    `scrypt$16384$8$1$<b64_salt>$<b64_digest>`
  - Fits well within `Profile.pin_hash` (`String(128)`).
- **Constant-Time Verification (`verify_profile_pin`):**
  - Parses `scrypt$<n>$<r>$<p>$<b64_salt>$<b64_digest>`.
  - If stored `pin_hash` is `None`, malformed, or uses unknown parameters (such as synthetic test strings like `"protected-profile"`), executes a dummy `hashlib.scrypt` calculation to equalize timing and returns `False` (fail-closed).
  - Recomputes `hashlib.scrypt` with the stored salt and parameters and compares digests via `secrets.compare_digest(actual_digest, expected_digest)`.
- **Per-Profile Failed-Attempt Throttling (`PinAttemptTracker`):**
  - Stored on `request.app.state.pin_attempt_tracker` (keyed by `profile_id`).
  - Policy:
    - Up to **5 consecutive failed PIN attempts** are permitted before lockout.
    - On the 5th consecutive failure, the Profile enters a **30-second cooldown lockout** (`locked_until = now_monotonic + 30.0`).
    - Subsequent failures after a cooldown expires before a successful unlock escalate the cooldown (`60s`, then capped at `300s`).
    - While `now_monotonic < locked_until`, any PIN verification or PIN modification attempt for that `profile_id` fails closed immediately with `HTTPException(status_code=429, detail={"code": "PIN_LOCKED_OUT", "message": f"Too many incorrect PIN attempts. Try again in {retry_after} seconds.", "retry_after_seconds": retry_after})`.
    - A successful PIN verification immediately resets the failure counter and lockout state for that `profile_id`.
    - Omitting `pin` (`pin is None`) on a PIN-protected Profile returns `HTTPException(status_code=403, detail={"code": "PIN_REQUIRED", "message": "Profile PIN required to unlock this Profile"})` without incrementing the wrong-PIN guess counter (unless the Profile is already locked out, in which case `429` takes precedence).

#### `[MODIFY]` `backend/app/api/v1/endpoints/profiles.py`
- **Primary Responsibility:** Host Admin Profile catalog listing, Profile creation, Profile rename, and Profile PIN configuration.
- **Schemas:**
  - `ProfileMetadata`: `id: str`, `name: str`, `is_default: bool`, `status: str`, `pin_protected: bool`.
  - `ProfileCreateRequest`: `model_config = ConfigDict(extra="forbid")`; `name: str = Field(min_length=1, max_length=64)` (validated to `1..32` chars after `.strip()`), `pin: str | None = Field(default=None, min_length=4, max_length=6)`.
  - `ProfileUpdateRequest`: `model_config = ConfigDict(extra="forbid")`; `name: str = Field(min_length=1, max_length=64)` (validated to `1..32` chars after `.strip()`).
  - `ProfilePinUpdateRequest`: `model_config = ConfigDict(extra="forbid")`; `current_pin: str | None = Field(default=None, min_length=4, max_length=6)`, `new_pin: str | None = Field(default=None, min_length=4, max_length=6)`.
- **Name Validation Helper (`validate_profile_name`):**
  - Strips leading/trailing whitespace.
  - Rejects empty string or length `> 32` characters (`422 Unprocessable Entity`).
  - Rejects control characters (`any(ord(ch) < 32 or ord(ch) == 127 for ch in normalized)` -> `422 Unprocessable Entity`).
  - Checks case-insensitive uniqueness among active non-deleted Profiles (`func.lower(Profile.name) == normalized.lower()`, `Profile.is_deleted.is_(False)`, `Profile.deleted_at.is_(None)`, excluding `Profile.id == current_profile_id` on rename). Raises `HTTPException(status_code=409, detail="A Profile with this name already exists")` on collision.
- **Endpoints:**
  1. `GET /api/v1/profiles` (`Depends(require_host_admin)`):
     - Lists active, non-deleted Profiles ordered deterministically by `Profile.is_default.desc(), Profile.created_at.asc(), Profile.id.asc()`.
  2. `POST /api/v1/profiles` (`Depends(require_host_admin)`, `status_code=201`, `response_model=ProfileMetadata`):
     - Validates `payload.name` and optional `payload.pin`.
     - Checks whether an active default Profile already exists (`select(Profile.id).where(Profile.is_default.is_(True))`); sets `is_default = False` when one exists (preserving `uq_profiles_single_default`).
     - Persists new `Profile(id=str(uuid.uuid4()), name=normalized_name, pin_hash=hash_profile_pin(payload.pin) if payload.pin else None, is_default=is_default, status="active")` atomically.
  3. `PATCH /api/v1/profiles/{profile_id}` (`Depends(require_host_admin)`, `response_model=ProfileMetadata`):
     - Fetches active, non-deleted Profile (`404 "Profile unavailable"` if missing/inactive/deleted).
     - Validates `payload.name` (checking conflicts against other active Profiles while allowing case-only updates to the same Profile).
     - Updates `profile.name = normalized_name` and `profile.updated_at = now_utc()`, commits atomically, and returns `ProfileMetadata`.
  4. `PUT /api/v1/profiles/{profile_id}/pin` (`Depends(require_host_admin)`, `response_model=ProfileMetadata`):
     - Fetches active, non-deleted Profile (`404 "Profile unavailable"` if missing).
     - Checks per-Profile PIN lockout (`429` if currently locked out).
     - **Case A — Enabling PIN on an unprotected Profile (`profile.pin_hash is None`):**
       - Requires `payload.new_pin is not None` (`422` if omitted) and `payload.current_pin is None` (`400` if supplied when no PIN is set).
       - Validates `payload.new_pin` format (`4` or `6` digits) and sets `profile.pin_hash = hash_profile_pin(payload.new_pin)`.
     - **Case B — Changing or Removing PIN on a protected Profile (`profile.pin_hash is not None`):**
       - Requires `payload.current_pin` (`403` `"Current Profile PIN required"` if omitted).
       - Verifies `payload.current_pin` against `profile.pin_hash` via `verify_profile_pin`. On mismatch, records a failed attempt in `PinAttemptTracker` and raises `403` `"Incorrect current Profile PIN"` (or `429` if the failure threshold is reached).
       - On match, resets `PinAttemptTracker` for `profile_id`.
       - If `payload.new_pin is not None`: validates format and sets `profile.pin_hash = hash_profile_pin(payload.new_pin)`.
       - If `payload.new_pin is None`: clears `profile.pin_hash = None` (removes PIN protection).
     - **Ticket & Session Hygiene on PIN Change:**
       - Atomically expires all unredeemed `SessionTicket` rows for `profile_id` (`expires_at = now_utc()`).
       - Revokes any active `ProfileSession` rows for `profile_id` except the caller's own active `ProfileSession` (if a valid `Authorization: Bearer psk_...` header for `profile_id` is included with the request), ensuring browser/secondary sessions cannot survive a PIN change while keeping the active Desktop session uninterrupted during Journey 3.

#### `[MODIFY]` `backend/app/api/v1/endpoints/auth.py`
- **Primary Responsibility:** PIN-aware `SessionTicket` issuance and exchange.
- **Changes:**
  - Extend `TicketRequest`:
    ```python
    class TicketRequest(BaseModel):
        model_config = ConfigDict(extra="forbid")
        profile_id: str = Field(min_length=1, max_length=36)
        request_id: str | None = Field(None, min_length=1, max_length=36)
        pin: str | None = Field(None, min_length=4, max_length=6)
    ```
  - Split `available_profile(db, profile_id)` into:
    1. `require_active_profile(db: AsyncSession, profile_id: str) -> Profile`: verifies `Profile.id == profile_id`, `Profile.status == "active"`, `Profile.is_deleted.is_(False)`, `Profile.deleted_at.is_(None)` (`404 "Profile unavailable"` otherwise). Used by `exchange_session` (`POST /api/v1/auth/session/exchange`).
    2. `authorize_profile_unlock(request: Request, db: AsyncSession, profile_id: str, pin: str | None) -> Profile`: calls `require_active_profile(db, profile_id)`, and if `profile.pin_hash is not None`:
       - Checks `PinAttemptTracker` for `profile_id` (`429` if in cooldown lockout).
       - If `pin is None`: raises `HTTPException(403, "Profile PIN required to unlock this Profile")`.
       - Validates `pin` against `profile.pin_hash` via `verify_profile_pin(pin, profile.pin_hash)`.
       - If invalid: records failed attempt (raising `429` if threshold reached, or `HTTPException(403, "Incorrect Profile PIN")`).
       - If valid: resets failed-attempt counter for `profile_id` and returns `profile`.

---

### 3.2 Contract & Parity Tooling Changes

#### `[MODIFY]` `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`
- Export updated FastAPI OpenAPI schema including `POST /api/v1/profiles`, `PATCH /api/v1/profiles/{profile_id}`, `PUT /api/v1/profiles/{profile_id}/pin`, and updated `TicketRequest` / `ProfileMetadata` schemas.
- Register the 3 new routes in `M2_ROUTE_DART_METHODS` in `scripts/check_dart_openapi_parity.py`:
  - `("POST", "/api/v1/profiles"): ("createProfile", "'profiles'")`
  - `("PATCH", "/api/v1/profiles/{profile_id}"): ("renameProfile", "'profiles/$profileId'")`
  - `("PUT", "/api/v1/profiles/{profile_id}/pin"): ("updateProfilePin", "'profiles/$profileId/pin'")`
- Register `ProfileMetadata`, `ProfileCreateRequest`, `ProfileUpdateRequest`, and `ProfilePinUpdateRequest` in `SCHEMA_TO_DART_CLASS` (`profile_dto.dart`).
- Update `scripts/tests/test_check_dart_openapi_parity.py` expected verified client route count from `30` to `33`.

---

### 3.3 Flutter Package & Desktop Application Changes

#### `[ADD]` `frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart` & `[MODIFY]` `companion_client.dart`
- **DTOs (`profile_dto.dart`):**
  - `ProfileMetadata`: `id`, `name`, `isDefault`, `status`, `pinProtected`.
  - `ProfileCreateRequest`: `name`, `pin` (optional).
  - `ProfileUpdateRequest`: `name`.
  - `ProfilePinUpdateRequest`: `currentPin` (optional), `newPin` (optional).
- **`CompanionClient` (`companion_client.dart`):**
  - Extend `_sessionRequest` to support `method: 'GET' | 'POST' | 'PATCH' | 'PUT'` and optional `includeSessionWithAdmin: bool = false` (so `PUT /api/v1/profiles/{id}/pin` can include the active `Authorization: Bearer psk_...` header alongside `X-Host-Admin-Secret` when preserving the caller's active Desktop session).
  - Add `createProfile(ProfileCreateRequest request) -> Future<ProfileMetadata>`.
  - Add `renameProfile(String profileId, ProfileUpdateRequest request) -> Future<ProfileMetadata>`.
  - Add `updateProfilePin(String profileId, ProfilePinUpdateRequest request) -> Future<ProfileMetadata>`.
  - Update `establishProfileSession(String profileId, {String? pin})` to pass `if (pin != null) 'pin': pin` in the `POST /api/v1/auth/bootstrap/ticket` body.
  - Update `approveBrowserRequest(String requestId, String profileId, {String? pin})` to pass `if (pin != null) 'pin': pin`.

#### `[MODIFY]` `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart`
- Track `String? _authenticatedProfileName` from `GET /api/v1/auth/session/me` (cleared in `_clearPersonalState()`).
- Add `String? get authenticatedProfileName => isConnected ? _authenticatedProfileName : null;`.
- Add `void updateAuthenticatedProfileName(String name)` so renaming the active Profile immediately updates the ChatScreen header without requiring a session re-exchange.
- Update `Future<void> selectProfile(String profileId, {String? pin})` to forward `pin: pin` to `_client.establishProfileSession(profileId, pin: pin)`.

#### `[MODIFY]` `frontend/flutter/apps/desktop/lib/features/profiles/desktop_profile_controller.dart`
- Upgrade `DesktopProfileController` while preserving all existing Batch B fields and methods (`profiles`, `requests`, `selectedProfileId`, `activeProfileId`, `error`, `busy`, `canUseSelected`, `select()`, `refresh()`, `useSelected()`, `approve()`) for 100% backward compatibility with existing tests:
  - Add `bool get canAttemptUseSelected => profiles.any((p) => p['id'] == selectedProfileId && p['status'] == 'active');`
  - Add `bool get isSelectedPinProtected => profiles.any((p) => p['id'] == selectedProfileId && p['pin_protected'] == true);`
  - Add `Map<String, dynamic>? get activeProfile => profiles.cast<Map<String, dynamic>?>().firstWhere((p) => p?['id'] == activeProfileId, orElse: () => null);`
  - Add `String? get activeProfileName => activeProfile?['name'] as String? ?? chat.authenticatedProfileName;`
  - Update `useSelected({String? pin})` and add `switchToProfile(String profileId, {String? pin}) -> Future<bool>`:
    - Calls `await chat.selectProfile(profileId, pin: pin)`.
    - Updates `activeProfileId = chat.authenticatedProfileId` and `selectedProfileId = activeProfileId`.
    - On `CompanionApiException` (`403` wrong PIN or `429` lockout), captures the specific server message in `error` and returns `false` without crashing.
  - Add `lockActiveProfile() -> Future<void>`:
    - Calls `await chat.client.revokeProfileSession()` and `await chat.invalidateProfileSession(clearStoredToken: true)`, sets `activeProfileId = null`, and notifies listeners.
  - Add `createProfile({required String name, String? pin, bool switchImmediately = false}) -> Future<ProfileMetadata?>`:
    - Calls `chat.client.createProfile(ProfileCreateRequest(name: name, pin: pin))`, refreshes the catalog, selects the new Profile, and if `switchImmediately` is true, calls `switchToProfile(created.id, pin: pin)`.
  - Add `renameProfile({required String profileId, required String newName}) -> Future<ProfileMetadata?>`:
    - Calls `chat.client.renameProfile(profileId, ProfileUpdateRequest(name: newName))`, refreshes the catalog, and if `profileId == activeProfileId`, calls `chat.updateAuthenticatedProfileName(updated.name)`.
  - Add `updatePin({required String profileId, String? currentPin, String? newPin}) -> Future<ProfileMetadata?>`:
    - Calls `chat.client.updateProfilePin(profileId, ProfilePinUpdateRequest(currentPin: currentPin, newPin: newPin))` and refreshes the catalog.
  - Detect mid-session expiry in `_onChatChanged()`: when `activeProfileId != null` and `chat.authenticatedProfileId == null` after an epoch change not initiated by a successful switch, set `activeProfileId = null` and surface a clear recovery prompt (`'Your Profile session has expired or was locked. Select a Profile to continue.'`).

#### `[ADD]` `frontend/flutter/apps/desktop/lib/features/profiles/profile_dialogs.dart`
- Reusable SoftGlass/Neumorphic dialogs with complete keyboard & validation support:
  1. `showCreateProfileDialog(BuildContext context, DesktopProfileController controller)`:
     - Display Name field (`1..32` chars, live character counter, inline validation).
     - Optional `"Protect with a numeric PIN"` toggle; when enabled, shows masked PIN (`4` or `6` digits, numeric input formatter) and Confirm PIN fields.
     - `"Switch to this Profile after creation"` checkbox (default true).
  2. `showRenameProfileDialog(BuildContext context, DesktopProfileController controller, {required String profileId, required String currentName})`:
     - Pre-filled Display Name input (`1..32` chars), inline validation and conflict error display.
  3. `showConfigurePinDialog(BuildContext context, DesktopProfileController controller, {required String profileId, required String profileName, required bool isCurrentlyProtected})`:
     - When `isCurrentlyProtected == false`: New PIN (`4` or `6` digits) + Confirm PIN -> enables PIN.
     - When `isCurrentlyProtected == true`: Mode selector (`Change PIN` vs `Remove PIN`), Current PIN field (required), and (if changing) New PIN + Confirm PIN fields. Displays inline error on wrong current PIN or cooldown lockout without closing the dialog.
  4. `showUnlockProfileDialog(BuildContext context, DesktopProfileController controller, {required String profileId, required String profileName}) -> Future<bool>`:
     - Masked numeric PIN entry (`4` or `6` digits), Enter-to-submit, inline error display on wrong PIN (`403`) or cooldown lockout (`429`), and immediate unlock & switch on success.

#### `[ADD]` `frontend/flutter/apps/desktop/lib/features/profiles/profile_selector_header.dart` & `[MODIFY]` `desktop_navigation_rail.dart`, `desktop_shell.dart`
- Adds `ProfileSelectorHeader` to `DesktopNavigationRail` right below the brand header (when `profileController != null`):
  - **Expanded Rail (`240px`):** Displays Profile avatar initials badge, active Profile display name (or `"Profile Locked"`), PIN lock icon badge if protected, and a popup menu / quick-switcher (`PopupMenuButton` or modal action) listing all active Profiles (with lock icons for PIN-protected Profiles and checkmark for active Profile), `"Create New Profile..."`, `"Lock Current Profile"`, and `"Manage Profiles in Settings..."`.
  - **Collapsed Rail (`72px`):** Displays compact circular avatar initials / lock status badge with tooltip and quick-switcher popup menu.

#### `[MODIFY]` `frontend/flutter/apps/desktop/lib/features/profiles/profile_access_card.dart` & `screens/chat_screen.dart`
- **`ProfileAccessCard` (`profile_access_card.dart`):**
  - Preserves existing `'Use Profile'`, `'Refresh requests'`, and `'Approve request'` controls so existing widget tests in `desktop_profile_session_test.dart` pass unchanged.
  - Enables selecting PIN-protected Profiles in the dropdown (`enabled: p['status'] == 'active'`); when a PIN-protected Profile is selected and `'Use Profile'` is tapped, opens `showUnlockProfileDialog` (or if called programmatically in unit tests without UI dialog, calls `useSelected()`).
  - Adds action buttons: `'Create Profile'`, `'Rename Profile'`, `'Configure PIN'` (or `'Change / Remove PIN'`), and `'Lock Profile'`.
  - Displays clear status badges (`Default`, `Active`, `PIN Protected`, `Unlocked` / `Locked`) and non-crashing error/recovery banners.
- **`ChatScreen` (`chat_screen.dart`):**
  - Displays a compact `Profile: <Active Profile Name>` pill in `_buildHeader` alongside `This Conversation: <Character>` when connected, fulfilling Journey 2 and Journey 8 visibility in Chat.

---

## 4. API Endpoint Contracts, Threat Model & Concurrency Safeguards

### 4.1 REST API Endpoint Specifications

| Method & Path | Authority Realm | Request Body Schema | Success Response | Error Statuses & Semantics |
| :--- | :--- | :--- | :--- | :--- |
| `GET /api/v1/profiles` | Host Admin (`require_host_admin`) | None | `200 OK` -> `list[ProfileMetadata]` | `401/403` missing/invalid Host Admin secret or browser Origin/Sec-Fetch header; `503` secret store unavailable |
| `GET /api/v1/profiles/{profile_id}` | Host Admin OR matching `ProfileSession` | None | `200 OK` -> `ProfileMetadata` | `401` invalid session; `404` foreign or non-existent/inactive Profile |
| `POST /api/v1/profiles` | Host Admin (`require_host_admin`) | `ProfileCreateRequest` (`name: str`, `pin?: str \| null`) | `201 Created` -> `ProfileMetadata` | `401/403` non-admin caller; `409` duplicate active Profile name (case-insensitive); `422` invalid name (`<1` or `>32` chars after trim, control chars) or invalid PIN format (not 4 or 6 ASCII digits) |
| `PATCH /api/v1/profiles/{profile_id}` | Host Admin (`require_host_admin`) | `ProfileUpdateRequest` (`name: str`) | `200 OK` -> `ProfileMetadata` | `401/403` non-admin caller; `404` Profile unavailable; `409` name conflict with another active Profile; `422` invalid name |
| `PUT /api/v1/profiles/{profile_id}/pin` | Host Admin (`require_host_admin`) + `current_pin` if already protected | `ProfilePinUpdateRequest` (`current_pin?: str \| null`, `new_pin?: str \| null`) | `200 OK` -> `ProfileMetadata` | `400` `current_pin` supplied when unprotected; `403` missing or wrong `current_pin`; `404` Profile unavailable; `422` invalid PIN format or both `current_pin` and `new_pin` null when unprotected; `429` Profile in failed-PIN cooldown lockout |
| `POST /api/v1/auth/bootstrap/ticket` | Host Admin (`require_host_admin`) + `pin` if target Profile is protected | `TicketRequest` (`profile_id: str`, `request_id?: str \| null`, `pin?: str \| null`) | `200 OK` -> `GrantResponse` (`ticket` or `request_id`, `expires_at`) | `401` expired/unavailable `request_id`; `403` missing or incorrect `pin` on PIN-protected Profile; `404` Profile unavailable; `429` PIN lockout cooldown |
| `POST /api/v1/auth/session/exchange` | Loopback + single-use `ticket` OR browser `request_id` + `claim_secret` | `ExchangeRequest` (`ticket?: str`, `request_id?: str`, `claim_secret?: str`) | `200 OK` -> `SessionResponse` (`token: "psk_..."`, `profile_id`, `expires_at`, `client_type`) | `401` expired/redeemed/invalid grant; `403` non-loopback or browser using native ticket; `404` Profile no longer active; `409` browser request awaiting approval; `429` bootstrap rate limit |

### 4.2 Concrete Threat Model & Concurrency Safeguards

| Threat / Race Condition | Concrete Mitigation & Enforcement Boundary | Verification Test |
| :--- | :--- | :--- |
| **1. Unauthorized Profile Mutation** | `POST /api/v1/profiles`, `PATCH /api/v1/profiles/{id}`, and `PUT /api/v1/profiles/{id}/pin` enforce `Depends(require_host_admin)`. Requests with `COMPANION_API_KEY`, `ProfileSession` (`psk_`) alone, non-loopback IP, DNS-rebinding `Host`, or browser `Origin` / `Sec-Fetch-*` headers fail closed (`401`/`403`). | `test_profile_crud_rejects_pairing_profile_session_and_browser_origins` |
| **2. Session Issuance Without PIN Verification** | `POST /api/v1/auth/bootstrap/ticket` calls `authorize_profile_unlock()`, which checks `profile.pin_hash is not None` and verifies `payload.pin` via constant-time `verify_profile_pin()` before minting any `SessionTicket` or approving any browser `request_id`. Updating a PIN via `PUT /profiles/{id}/pin` atomically expires all unredeemed `SessionTicket` rows for that Profile. | `test_pin_protected_profile_rejects_missing_or_wrong_pin_and_issues_session_on_valid_pin`, `test_pin_change_invalidates_unredeemed_tickets` |
| **3. Brute-Force PIN Guessing** | `PinAttemptTracker` tracks consecutive failed PIN verifications per `profile_id` across both `/auth/bootstrap/ticket` and `/profiles/{id}/pin`. After 5 consecutive failures, the Profile enters a 30s cooldown lockout (escalating to 60s / 300s on repeated lockouts), returning `429 Too Many Requests` with `retry_after_seconds` before evaluating further guesses. | `test_pin_brute_force_lockout_and_cooldown_recovery` |
| **4. Credential & PIN Leakage in Logs, Errors, or Storage** | Plaintext `pin`, `current_pin`, and `new_pin` are never persisted, echoed in error responses, or written to logs. Only salted `scrypt` hashes are stored in `profiles.pin_hash`. Flutter PIN text controllers are disposed immediately when dialogs close and use `obscureText: true`. | `test_pin_never_exposed_in_responses_or_database` |
| **5. Cross-Profile State Leakage After Switch** | `DesktopChatController.selectProfile()` calls `_clearPersonalState()` and `cancelGeneration()` before revoking the old session and establishing the new one. `_configEpoch` increments, invalidating all in-flight conversation/message/character reads and resetting `DesktopStudioController` via `_sessionFenceId`. | `desktop_profile_session_test.dart`, `desktop_profile_admin_test.dart` |
| **6. Stale Session Restoration Into Wrong or Deleted Profile** | Startup `refresh(initializeDefault: true)` validates saved `psk_` tokens via `GET /api/v1/auth/session/me`. If the session is expired, revoked, or belongs to an inactive/deleted Profile, `_allowDefaultBootstrap` is set to `false`, personal caches are cleared, and the app stays in the locked/unauthorized state without silently falling back to Default. | `desktop_profile_restore_test.dart` |
| **7. Concurrent Switch Requests & Active Streaming Cancellation** | `DesktopProfileController.busy` guards concurrent UI switch/create/rename/PIN operations. In `DesktopChatController`, `selectProfile()` cancels `_currentStreamSubscription` and `_profileSubscriptions` and increments `_configEpoch` so late SSE tokens from the prior Profile are dropped. On the backend, `guarded_tokens` in `profile_sessions.py` re-validates `session.revoked_at` every 250ms and aborts generation as soon as `/auth/session/revoke` commits. | `test_switch_during_active_stream_cancels_generation_and_drops_late_tokens` |
| **8. Partial State Writes During Profile Creation, Rename, or PIN Setup** | Each backend mutation (`POST /profiles`, `PATCH /profiles/{id}`, `PUT /profiles/{id}/pin`) executes in a single SQLAlchemy async transaction (`await db.commit()`), rolling back completely on validation or constraint failure (`uq_profiles_single_default` or duplicate name check). | `test_create_profile_with_invalid_pin_rolls_back_atomically` |

### 4.3 Required 8-Journey Flutter Desktop User Flow Coverage

| Journey # | User Journey | Planned UI Path & State Verification |
| :--- | :--- | :--- |
| **1** | **Create a new Profile** | User clicks `Create Profile` in Navigation Rail Profile popover or Settings `ProfileAccessCard` -> enters Display Name (`1..32` chars) -> submits -> `POST /api/v1/profiles` creates UUID Profile -> catalog refreshes and new Profile appears in selector. |
| **2** | **Rename the Profile and see updated name** | User clicks `Rename Profile` -> enters updated name -> `PATCH /api/v1/profiles/{id}` updates name preserving UUID -> updated name appears immediately in `ProfileSelectorHeader`, `ProfileAccessCard`, and `ChatScreen` header. |
| **3** | **Enable optional PIN protection** | User clicks `Configure PIN` -> enters 4- or 6-digit numeric PIN + confirmation -> `PUT /api/v1/profiles/{id}/pin` stores `scrypt` hash -> Profile displays lock badge (`pin_protected == true`) while keeping the current active Desktop session connected. |
| **4** | **Switch from current Profile to an unprotected Profile** | User selects an unprotected Profile (e.g., `Default Profile`) -> prior session is revoked, active streams/caches clear, new session is minted without a PIN prompt -> UI transitions cleanly to the target Profile's isolated conversations and Character. |
| **5** | **Switch to a PIN-protected Profile through the PIN prompt** | User selects the PIN-protected Profile -> `showUnlockProfileDialog` opens -> user enters valid PIN -> `POST /api/v1/auth/bootstrap/ticket` verifies PIN and issues ticket -> `POST /api/v1/auth/session/exchange` issues `psk_` session -> UI unlocks into the protected Profile. |
| **6** | **Encounter an incorrect PIN and see a clear non-crashing error state** | User enters wrong PIN in `showUnlockProfileDialog` -> backend returns `403 Incorrect Profile PIN` (or `429` after 5 failures) -> dialog remains stable, clears PIN input, and displays clear error message; no session is issued and no foreign data is shown. |
| **7** | **Recover gracefully when a stored session is expired or invalid** | Saved `psk_` token expires or returns `401` -> `DesktopChatController` clears personal state and transitions to `unauthorized`; `DesktopProfileController` clears `activeProfileId` without falling back to Default and displays recovery prompt allowing one-click re-selection/unlock. |
| **8** | **Return to Chat and see the correct Profile and Character context** | After switching/unlocking, user navigates to `ChatScreen` -> header displays `Profile: <Name>` and `This Conversation: <Character>` (defaulting to `Neutral Assistant` for a new Profile or the Profile's own selected `CharacterInstance`) with strictly isolated conversation history. |

---

## 5. Dependency-Respecting Implementation Sequence & Verification Strategy

### 5.1 Step-by-Step TDD Implementation Order (Phase 2)

```text
Step 1: Backend PIN Cryptography & Lockout Unit/Integration Tests (RED -> GREEN)
  ├── Add backend/tests/test_profile_admin_and_pin.py covering:
  │     - 4-digit and 6-digit PIN validation; rejection of 3-digit, 5-digit, 7-digit, alpha, whitespace
  │     - scrypt hashing & constant-time verification; rejection of malformed/legacy hashes
  │     - 5-attempt per-Profile brute-force lockout (429 + retry_after_seconds) and reset on success
  └── Implement backend/app/core/profile_pin.py

Step 2: Backend Profile Create, Rename, PIN Update & Ticket Unlock Endpoints (RED -> GREEN)
  ├── Extend backend/tests/test_profile_admin_and_pin.py and test_profile_sessions.py covering:
  │     - POST /api/v1/profiles (unprotected & with initial PIN, name trimming/validation, 409 duplicate name, uq_profiles_single_default preservation, non-admin 401/403 rejection)
  │     - PATCH /api/v1/profiles/{id} (rename preserving UUID, conversations, memories, tasks, characters, and active session; 409 conflict; 404 missing)
  │     - PUT /api/v1/profiles/{id}/pin (enable PIN, change PIN with current_pin, remove PIN with current_pin, wrong current_pin 403/429, unredeemed ticket invalidation, active Desktop session preservation vs secondary session revocation)
  │     - POST /api/v1/auth/bootstrap/ticket & /session/exchange with PIN-protected Profile (missing PIN 403, wrong PIN 403/429, valid PIN 200 -> session exchange 200)
  └── Implement changes in backend/app/api/v1/endpoints/profiles.py and backend/app/api/v1/endpoints/auth.py

Step 3: OpenAPI Contract Export & Dart Contract Parity Verification (RED -> GREEN)
  ├── Regenerate contracts/openapi/openapi.json from FastAPI app
  ├── Add frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart and export in companion_api.dart
  ├── Add createProfile, renameProfile, updateProfilePin, and pin parameter on establishProfileSession / approveBrowserRequest in companion_client.dart
  ├── Update scripts/check_dart_openapi_parity.py and scripts/tests/test_check_dart_openapi_parity.py (33 verified routes)
  └── Add unit tests in frontend/flutter/packages/companion_api/test/companion_client_test.dart

Step 4: Flutter Desktop Controller & State Isolation Tests (RED -> GREEN)
  ├── Add controller tests in frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart covering:
  │     - Create Profile (unprotected and PIN-protected, optional immediate switch)
  │     - Rename Profile (updates catalog and active ChatScreen Profile name)
  │     - Enable, change, and remove PIN
  │     - Switch between unprotected and PIN-protected Profiles; active SSE stream cancellation; Studio fence reset
  │     - Wrong PIN and 429 lockout error handling without crash
  │     - Expired/invalid session recovery without Default fallback
  └── Implement updates in desktop_chat_controller.dart and desktop_profile_controller.dart

Step 5: Flutter Desktop UI Components & 8-Journey Widget Tests (RED -> GREEN)
  ├── Add widget tests in frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart covering all 8 required user journeys across ProfileSelectorHeader, ProfileAccessCard, profile_dialogs.dart, and ChatScreen
  └── Implement profile_dialogs.dart, profile_selector_header.dart, profile_access_card.dart, desktop_navigation_rail.dart, desktop_shell.dart, and chat_screen.dart

Step 6: Full Regression Suite & Static Analysis Verification
  └── Run all backend pytest suites, contract parity checks, Dart/Flutter analyze, and Flutter test suites
```

### 5.2 Automated Verification Commands

```powershell
# 1. Backend Profile Admin, PIN, Session & Full Regression Suite
backend\.venv\Scripts\python.exe -m pytest backend/tests/test_profile_admin_and_pin.py backend/tests/test_profile_sessions.py backend/tests/test_profile_authorization.py backend/tests/test_profile_model.py -v
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

### 5.3 Physical Windows Manual Acceptance Criteria (Post-Implementation)
1. Launch Flutter Desktop on Windows with supervised Local AI Runtime.
2. Verify `Default Profile` is active in the Navigation Rail `ProfileSelectorHeader`, Settings `ProfileAccessCard`, and `ChatScreen` header (`Profile: Default Profile`, `This Conversation: Neutral Assistant`).
3. Create a new Profile `"Work"` (unprotected) and switch to it; verify Chat history is empty and isolated from `Default Profile`, and the local LLM runtime does **not** restart or unload.
4. Send a message in `"Work"` and select a custom Character in Character Studio; verify `"Work"` retains its conversation and Character.
5. Rename `"Work"` to `"Work Studio"`; verify the updated name immediately reflects in the Navigation Rail Profile chip, Settings card, and Chat header while preserving the conversation and Character.
6. Enable a 4-digit PIN (`1234`) on `"Work Studio"`; verify the lock badge appears and the current session stays connected.
7. Switch back to `Default Profile` (unprotected); verify `"Work Studio"` conversations and Character disappear and `Default Profile` history is restored.
8. Attempt to switch to `"Work Studio"` with an incorrect PIN (`0000`); verify a clear error message is shown, no crash occurs, and `"Work Studio"` data remains locked.
9. Unlock `"Work Studio"` with the correct PIN (`1234`); verify `"Work Studio"` conversations and active Character are restored in Chat.
10. Change the PIN on `"Work Studio"` to a 6-digit PIN (`654321`), then remove the PIN using `654321`; verify switching to `"Work Studio"` no longer prompts for a PIN.

---

## 6. Risk Assessment & Rollback Plan

- **Risk Level:** **Level C — Sensitive Design** (touches authentication bootstrap, Profile isolation boundaries, and credential verification).
- **Key Risks & Mitigations:**
  - *Breaking existing Batch B session/restore tests:* Mitigated by keeping `GET /api/v1/profiles`, `POST /api/v1/auth/bootstrap/ticket` (when `pin` is omitted on unprotected Profiles), `POST /api/v1/auth/session/exchange`, `DesktopProfileController` public properties, and `ProfileAccessCard` button labels backward-compatible.
  - *Plaintext PIN exposure:* Mitigated by strict `extra="forbid"` Pydantic models, no logging of request bodies on auth/PIN routes, immediate `scrypt` hashing with 16-byte random salt, and `obscureText: true` in Flutter inputs.
- **Rollback Plan:** Because Batch C requires **zero database schema migrations** (using the existing `profiles.pin_hash VARCHAR(128)` column from Migration 007), rolling back the branch cleanly reverts the API and UI to Batch B behavior without any database downgrade or data migration risk; any `scrypt$...` values stored in `profiles.pin_hash` simply fail closed (`403`) under Batch B code.

---

## 7. Canonical Documentation Sync Plan (Phase 3)

After Phase 2 implementation and all automated verification checks pass:
1. Update [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../../04_Architecture/02_Data_and_Security/profiles-and-devices.md) and [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](../../04_Architecture/02_Data_and_Security/authentication-and-secrets.md) to reflect implemented `POST /api/v1/profiles`, `PATCH /api/v1/profiles/{id}`, `PUT /api/v1/profiles/{id}/pin`, `scrypt` PIN derivation, per-Profile lockout throttling, and PIN-verified `POST /api/v1/auth/bootstrap/ticket` unlock.
2. Update [`docs/02_Planning/00_Master/WBS.md`](../../02_Planning/00_Master/WBS.md), [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](../../02_Planning/00_Master/DELIVERY_INDEX.md), [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../../02_Planning/00_Master/SPRINT_ROADMAP.md), [`docs/02_Planning/00_Master/MASTER_CHECKLIST.md`](../../02_Planning/00_Master/MASTER_CHECKLIST.md), and [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md) for `PC-IDENTITY-004` and `PC-CLIENT-005` (noting that `PC-IDENTITY-005` 7-day soft-delete lifecycle remains scoped to Batch D).
3. Update [`docs/01_Tracking/task.md`](../../01_Tracking/task.md), archive [`docs/01_Tracking/active/task-feature-m2-profile-admin-c.md`](../../01_Tracking/active/task-feature-m2-profile-admin-c.md) to `docs/01_Tracking/archive/` during Phase 3 closure, and append a summary entry to [`CHANGELOG.md`](../../../CHANGELOG.md).

---

## 8. Material Decisions & Tradeoff Analysis

### Decision 1: PIN Key-Derivation Function (`hashlib.scrypt` vs. `hashlib.pbkdf2_hmac` vs. `argon2-cffi`)
- **Candidate Alternatives:**
  1. **Option 1A (Recommended): Python 3.11 stdlib `hashlib.scrypt` (`N=16384, r=8, p=1, dklen=32`, 16-byte CSPRNG salt).**
  2. **Option 1B: Python 3.11 stdlib `hashlib.pbkdf2_hmac("sha256", iterations=600_000)`.**
  3. **Option 1C: Third-party `argon2-cffi` package.**
- **Rationale & Tradeoffs:**
  - `backend/requirements.txt` does not include `argon2-cffi`, and adding a new native CFFI dependency is prohibited in Batch C without explicit approval.
  - Python 3.11's standard library includes OpenSSL-backed `hashlib.scrypt` (RFC 7914), which provides true memory-hard key stretching (16 MiB per evaluation at `N=16384, r=8, p=1`), encodes cleanly in 83 ASCII characters inside the existing `profiles.pin_hash VARCHAR(128)` column, and requires zero external dependencies.
- **Approval Needed:** Confirm `hashlib.scrypt` (`scrypt$16384$8$1$<salt>$<digest>`) as the canonical stdlib KDF for Profile PINs.

### Decision 2: Supported Numeric PIN Length (`4-digit or 6-digit` vs. `4..8 digits`)
- **Candidate Alternatives:**
  1. **Option 2A (Recommended): Support both `4-digit` and `6-digit` ASCII numeric PINs (`^\d{4}(\d{2})?$`).**
  2. **Option 2B: Support only fixed 4-digit PINs (`^\d{4}$`).**
  3. **Option 2C: Support any 4-to-8 digit numeric PIN (`^\d{4,8}$`).**
- **Rationale & Tradeoffs:**
  - [`docs/05_Design/02_Profile_Selector_and_Privacy.md`](../../05_Design/02_Profile_Selector_and_Privacy.md) §3.1 explicitly specifies *"a 4-digit or 6-digit numeric PIN"*. Supporting both 4-digit and 6-digit numeric codes matches the canonical design specification while keeping the UI keypad/input validation crisp and predictable.
- **Approval Needed:** None (aligns directly with `02_Profile_Selector_and_Privacy.md` §3.1).

### Decision 3: Failed-Attempt Lockout Storage (`In-Memory Runtime State` vs. `New DB Migration 010`)
- **Candidate Alternatives:**
  1. **Option 3A (Recommended): In-memory per-Profile lockout tracker on `app.state.pin_attempt_tracker` (5 failed attempts -> 30s cooldown, escalating to 60s / 300s) with zero database schema migration.**
  2. **Option 3B: Add Alembic Migration `010_profile_pin_lockout.py` adding `pin_failed_attempts` and `pin_locked_until` columns to `profiles`.**
- **Rationale & Tradeoffs:**
  - Per `02_Profile_Selector_and_Privacy.md` §1, Profile PINs protect against casual household screen switching, not an OS user with raw filesystem write access to SQLite (who could clear `pin_hash` directly in SQLite regardless of DB lockout columns). Keeping failed-attempt cooldown state in runtime memory (`app.state`) blocks interactive and local loopback brute-force guessing across all endpoints (`/auth/bootstrap/ticket` and `/profiles/{id}/pin`) while avoiding any Alembic schema migration in Batch C.
- **Approval Needed:** Confirm Option 3A (in-memory runtime lockout tracker, zero DB migration).

### Decision 4: PIN Verification & Management Endpoint Topology
- **Candidate Alternatives:**
  1. **Option 4A (Recommended): Enhance existing `POST /api/v1/auth/bootstrap/ticket` to accept optional `pin` for ticket issuance/approval, and add `PUT /api/v1/profiles/{profile_id}/pin` (`current_pin`, `new_pin`) for enabling, changing, or removing a PIN.**
  2. **Option 4B: Keep `POST /api/v1/auth/bootstrap/ticket` for unprotected Profiles only and add a separate `POST /api/v1/profiles/{profile_id}/unlock` endpoint plus separate `POST` / `PATCH` / `DELETE` PIN routes.**
- **Rationale & Tradeoffs:**
  - Option 4A preserves the single canonical two-step session bootstrap architecture established in Batch B (`POST /auth/bootstrap/ticket` -> `POST /auth/session/exchange`) for both native Desktop and Desktop-approved browser sessions, while keeping Profile PIN management consolidated in a single idempotent `PUT /api/v1/profiles/{profile_id}/pin` route.
- **Approval Needed:** Confirm Option 4A endpoint topology.
