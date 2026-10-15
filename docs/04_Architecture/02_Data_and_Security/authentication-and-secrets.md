# Authentication and Secrets Architecture

> **Document Role:** Canonical domain architecture specification.  
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0005, ADR-0006)  
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for authentication, secrets, and network trust boundaries.

---

## 1. Purpose & Scope

- **Device-Local Credentials:** Provider API credentials remain device-local and never automatically synchronize.


This specification defines cryptographic authentication mechanisms, secret storage policies, rate limiting, and transport trust models for the AI Companion:
- Fail-closed API authentication protecting companion endpoints.
- Separation of network proximity from identity authentication.
- Supported network trust topologies (loopback default, trusted LAN, Tailscale private mesh, Cloudflare Tunnel).
- Explicit rejection of direct public internet port forwarding.
- Evolution path from current file-based secret storage to durable host secret stores.
- Token validation, timing-attack defense, and rate-limiting invariants.

---

## 2. Durable Architecture & Invariants

### 2.1 Fail-Closed Authentication & Network Boundaries (Decision D5)

In accordance with Decision D5:
- **Fail-Closed by Construction:** Protected companion operations require explicit cryptographic authority by default. `GET /api/v1/health` is the public telemetry whitelist. Bounded loopback authorization request/exchange operations are reachable before a Profile Session exists, but issue one only through independent Host Admin approval and valid single-use grant proof; reachability grants no personal-data authority.
- **Proximity is Not Authentication:** Physical or network-layer proximity (sharing local Wi-Fi or subnet) does **not** grant implicit trust or bypass authentication. Network proximity never substitutes for application auth.


### 2.2 Supported Trust Topologies & Remote Access (ADR-0006)

The companion architecture preserves the current localhost/Tailscale/Cloudflare architecture under Decision D5 and `ADR-0006`:
1. **Authenticated Localhost Loopback (Default):** Local desktop clients (Flutter, React Web) and host processes communicating over `127.0.0.1` / `::1`.
2. **Explicitly Trusted LAN:** Satellite devices communicating across a private home network with explicit host pairing and application authentication.
3. **Encrypted Overlay Mesh (Tailscale — Preferred):** Tailscale is the preferred private trusted-device transport.
4. **Cloudflare Tunnel + Access (Preferred Remote-Browser):** Cloudflare Tunnel + Access is the preferred controlled remote-browser internet path.
   - **Important:** Cloudflare Access identity does NOT replace AI Companion application authentication.
- **Encrypted Transport Rule:** Sensitive non-loopback traffic requires encrypted transport.

### 2.3 Direct Public Internet Port Forwarding Rejected


In accordance with Decision D5:
- **Status:** `PERMANENTLY REJECTED`.
- **Policy Invariant:** Direct port forwarding from the public internet (opening external router ports, dynamic DNS directly to companion port, unauthenticated public ingress) is **strictly excluded** from the supported trust model. The companion runtime is not a multi-tenant public web server and must never be exposed directly to unauthenticated public internet traffic.

### 2.4 Production Browser Authentication

- Never expose raw provider credentials to browser clients.
- Never store the root/master companion credential in browser `localStorage`.
- Prefer a secure server-session / `HttpOnly`-cookie-style browser session architecture.
- The production remote-browser mechanism remains **OPEN**. The implemented local browser approval flow in §3 does not establish production remote-browser readiness.

### 2.5 Rate Limiting & DoS Protection

- **Rate Limiting Scope:** Rate limiting protects: authentication, pairing/enrollment, session creation, turn/message submission, tool/action requests, imports/uploads, and remote APIs.
- **Streaming Exemption:** Rate limiting is NOT conceptually applied to every individual SSE token delta or audio frame.

### 2.6 Device-Local Provider Credentials

The handling of third-party provider credentials (e.g. OpenAI, Anthropic, Groq API keys) is governed by the following frozen constraints:

- **Device-Local Secrets:** Provider API credentials are device-local secrets.
- **No Automatic Sync:** Keys do NOT automatically sync between PC, mobile, or other devices. PC-configured keys stay on the PC.
- **Future Mobile Scope:** Future mobile companions may configure and store their own provider keys locally on the device.
- **Profile Policy, Not Secret Storage:** The Profile owns permission and routing policies, not the raw secret itself.
- **No Remote Exposure:** The Runtime/provider layer never exposes raw keys to remote browser clients.
- **Backup & Restore Exclusions:** Restore/backup processes do not restore device/provider credentials by default.


### 2.7 API Key Legacy Status

Current shared `COMPANION_API_KEY` remains legacy/development implementation only.

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Authentication Pipeline & Router Protection

Verified in `backend/app/core/security.py`, `backend/app/core/profile_sessions.py`, `backend/app/core/host_admin.py`, `backend/app/api/deps.py`, `backend/app/api/v1/router.py`, and `backend/app/api/v1/endpoints/auth.py`:
- **Legacy Pairing Authority:** `verify_token` accepts the pairing credential via `Authorization: Bearer <token>` or `X-API-Key: <token>` for `/auth/verify`. Read-only `/models` and `/models/registry` accept pairing credentials or a validated Profile Session. Pairing credentials cannot authorize personal data, model mutations, Profile enumeration or session issuance.
- **Timing-Attack Defense:** Tokens are compared using `constant_time_compare()`, which wraps `hmac.compare_digest` to prevent timing side-channel discovery.
- **Fail-Closed Router Assembly:**
  - `public_router`: Whitelists only `GET /api/v1/health` (`public_health_router`).
  - `protected_router`: Requires `get_current_profile_session` across tasks, conversations, messages, attachments and memories. `/chat/completions` also requires a Profile Session.
  - **Host Admin:** `/system/status`, model load/select/unload/hardware-profile mutation, Profile catalog enumeration and bootstrap approval require independent native Host Admin credentials over loopback. Browser Origin/fetch-metadata requests cannot use Host Admin authority.
  - **Mixed Authority:** Auth and Profile lookup operations declare their own authority checks. `GET /profiles/{profile_id}` permits Host Admin or the matching Profile Session only.
- **Profile Session Lifecycle:** High-entropy `psk_` bearer tokens are stored as SHA-256 hashes, bound to one Profile and issued with a twelve-hour absolute expiry. Validation freshly checks expiry, revocation and active/non-deleted Profile state. `GET /auth/session/me` returns own-Profile metadata and the validated UTC `expires_at`; it does not renew the session. `POST /auth/session/revoke` revokes the active session. Streaming generation, persistence and attachment downloads revalidate authority while work is in progress.
- **Browser Approval:** The browser retains a generated claim secret in memory and submits its hash through `POST /auth/session/claim`. Exact configured Origin, JSON/custom-header CSRF controls, loopback transport, bounded pending requests and rate limits constrain bootstrap. Native Desktop reviews the request identifier/Origin and approves a selected active unprotected Profile. `POST /auth/session/exchange` requires the matching secret, Origin, explicit approval and unexpired grant, consuming the grant atomically with session creation. Grants expire within sixty seconds; concurrent replay fails closed. Desktop direct tickets cannot bypass browser proof binding. PIN-protected Profiles fail closed until an authorized unlock challenge exists.
- **CORS Configuration:** `settings.CORS_ORIGINS` in `backend/app/core/config.py` specifies four development localhost/loopback origins: `http://localhost:5173`, `http://127.0.0.1:5173`, `http://localhost:3000`, and `http://127.0.0.1:3000`. These represent current development localhost/loopback origins, not production origins, and are not promoted into durable architecture.
- **Pairing Token Generation:** On initial launch without a configured pairing key, `ensure_pairing_token()` generates a URL-safe token from 32 random bytes of entropy and prefixes it with `companion_sec_`. This credential remains distinct from Host Admin and Profile Session authority.

### 3.2 Secret Storage Reality

Verified in `backend/app/core/config.py`, `backend/app/core/host_admin.py`, `backend/app/core/windows_security.py`, Flutter Desktop credential/session controllers, and React Web session handling:
- **Current File Persistence:** Generated pairing tokens are persisted by writing directly into the `backend/.env` file.
- **Implementation Status:** Storing secrets in `backend/.env` is a **current development implementation reality**, not permanent secure secret-storage architecture.
- **Host Admin Store:** `%LOCALAPPDATA%\AICompanion\secrets\desktop_admin.secret` contains independent native administrator authority. Windows SID ACL checks and reparse-path rejection fail closed on unsafe storage; the secret is never supplied to browsers.
- **Flutter Client Store & Restoration:** Flutter Desktop caches credentials through Windows DPAPI. Saved Profile Sessions are validated before personal-data use, and the returned absolute expiry restores the cleanup timer. Expiry clears Profile-scoped personal caches, errors and subscriptions; a failed saved-session restoration does not implicitly authorize the Default Profile. An expired saved credential can remain inert in protected storage pending explicit reauthorization.
- **Browser Store:** React holds Profile Session tokens and claim secrets in memory, removes legacy pairing-key entries from `localStorage`, and never places bearer grants or sessions in URLs/history. Refresh requires fresh Desktop approval. Expiry, invalidation and logout clear Profile-scoped client state.
- **Per-Device Credentials Status:** **NOT IMPLEMENTED**. Profile Sessions are temporary authenticated contexts, not enrolled Device identities. Independent satellite credentials, registry/enrollment and device revocation remain future work.

---

## 4. Approved Target Architecture / Not Yet Implemented

When implemented for target milestones:

1. **Independent Per-Device Revocable Credentials:** Transition from a single shared pairing key to per-device credentials (e.g., individual device tokens issued during authenticated pairing), allowing targeted revocation.
2. **Dedicated Platform Secret Storage:** Migration of sensitive credentials (pairing tokens, third-party provider keys) from plaintext `.env` files into platform-native credential storage.

---

## 5. Implementation-Open Details (Decision Debt)

The normative architecture for D4 and D5 is frozen. The following implementation-level details are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Rate Limiting Parameters:** Request rate thresholds, burst limits, and backoff windows per endpoint tier (`DEBT-V1-014`).
- **Remaining Host Secret Storage:** Host Admin uses verified Windows ACL storage and Flutter client caches use DPAPI. Platform storage for development pairing credentials and provider keys remains future work.
- **Client Secret Store Mechanism:** **[BATCH-A DECISION]** Sensitive Mobile credentials MUST use approved platform-protected device-local storage. For Android, Android Keystore (or a vetted abstraction backed by it) is the primary target. Plaintext storage is prohibited.
- **Token Rotation & Expiration:** Profile Session absolute expiry and revocation are implemented in §3. Policies and automation for periodic credential rotation and inactivity timeouts remain open.

---

## 6. Security & Ownership Boundaries

- **Constant-Time Verification:** All token comparisons must use constant-time operations to eliminate timing side-channels.
- **No Client Elevation:** A validated Profile Session permits Profile-scoped conversational APIs, without administrative authority to read host filesystem paths or manipulate host process lifecycles. A legacy pairing credential grants only its bounded diagnostic/telemetry authority.
- **CORS Containment:** CORS origins restrict cross-origin browser access to explicitly authorized development loopback origins.
- **Rate Limiting Enforced:** Fail-closed rate limiting on all public and protected routes.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, Decisions D4, D5)
- **Tailscale Remote Transport ADR:** [`docs/04_Architecture/decisions/ADR-0006-d5-remote-access-trust-boundary.md`](../decisions/ADR-0006-d5-remote-access-trust-boundary.md)
- **Device Authentication ADR:** [`docs/04_Architecture/decisions/ADR-0005-d4-profile-device-credential-boundary.md`](../decisions/ADR-0005-d4-profile-device-credential-boundary.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) (Decision D5), [`WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-API-002`)
- **Profiles & Devices Specification:** [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](profiles-and-devices.md)
- **Tool Permissions & Actions Spec:** [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](tool-permissions-and-actions.md)
