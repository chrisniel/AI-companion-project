# Authentication and Secrets Architecture

> **Document Role:** Canonical domain architecture specification.  
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0005, ADR-0006)  
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for authentication, secrets, and network trust boundaries.

---

## 1. Purpose & Scope

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
- **Fail-Closed by Construction:** All companion endpoints require explicit cryptographic authentication by default. Endpoints are protected unless explicitly assigned to a strictly bounded public whitelist (`GET /api/v1/health` only).
- **Proximity is Not Authentication:** Physical or network-layer proximity (sharing local Wi-Fi or subnet) does **not** grant implicit trust or bypass authentication. Network proximity never substitutes for application auth.


### 2.2 Supported Trust Topologies & Remote Access (ADR-0006)

The companion architecture supports three bounded network topologies under Decision D5 and `ADR-0006`:
1. **Authenticated Localhost Loopback (Default):** Local desktop clients (Flutter, React Web) and host processes communicating over `127.0.0.1` / `::1`.
2. **Explicitly Trusted LAN:** Satellite devices communicating across a private home network with explicit host pairing and application authentication.
3. **Encrypted Overlay Mesh (Tailscale Private Mesh — Preferred):** Remote satellite access routed through an authenticated, encrypted WireGuard-based private mesh network without exposing open router ports (`ADR-0006`). Alternatively, a managed **Cloudflare Tunnel** with Cloudflare Access authentication is supported for controlled web egress.

### 2.3 Direct Public Internet Port Forwarding Rejected

In accordance with Decision D5:
- **Status:** `PERMANENTLY REJECTED`.
- **Policy Invariant:** Direct port forwarding from the public internet (opening external router ports, dynamic DNS directly to companion port, unauthenticated public ingress) is **strictly excluded** from the supported trust model. The companion runtime is not a multi-tenant public web server and must never be exposed directly to unauthenticated public internet traffic.

### 2.4 Rate Limiting & DoS Protection

- All client-facing HTTP and WebSocket endpoints must enforce rate limiting to defend against brute-force token enumeration and local denial-of-service. Sensitive authentication routes enforce tighter request throttling.

---

### 2.5 Device-Local Provider Credentials

The handling of third-party provider credentials (e.g. OpenAI, Anthropic, Groq API keys) is governed by the following frozen constraints:

- **Device-Local Secrets:** Provider API credentials are device-local secrets.
- **No Automatic Sync:** Keys do NOT automatically sync between PC, mobile, or other devices. PC-configured keys stay on the PC.
- **Future Mobile Scope:** Future mobile companions may configure and store their own provider keys locally on the device.
- **Profile Policy, Not Secret Storage:** The Profile owns permission and routing policies, not the raw secret itself.
- **No Remote Exposure:** The Runtime/provider layer never exposes raw keys to remote browser clients.
- **Backup & Restore Exclusions:** Restore/backup processes do not restore device/provider credentials by default.


## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Authentication Pipeline & Router Protection

Verified in `backend/app/core/security.py`, `backend/app/api/deps.py`, and `backend/app/api/v1/router.py`:
- **Dual-Header Support:** `verify_token` accepts credentials via either `Authorization: Bearer <token>` or `X-API-Key: <token>`.
- **Timing-Attack Defense:** Tokens are compared using `constant_time_compare()`, which wraps `hmac.compare_digest` to prevent timing side-channel discovery.
- **Fail-Closed Router Assembly:**
  - `public_router`: Whitelists only `GET /api/v1/health` (`public_health_router`).
  - `protected_router`: Applies `dependencies=[Depends(verify_token)]` at the root router level across all other endpoints (`/system`, `/auth`, `/tasks`, `/llm`, `/conversations`, conversation attachment routes, and `/memories`).
- **CORS Configuration:** `settings.CORS_ORIGINS` in `backend/app/core/config.py` specifies four development localhost/loopback origins: `http://localhost:5173`, `http://127.0.0.1:5173`, `http://localhost:3000`, and `http://127.0.0.1:3000`. These represent current development localhost/loopback origins, not production origins, and are not promoted into durable architecture.
- **Current Token Schema:** Uses a single shared pairing key (`COMPANION_API_KEY`). On initial launch without a configured key, `ensure_pairing_token()` generates a URL-safe token from 32 random bytes of entropy and prefixes it with `companion_sec_` (`companion_sec_<token>`).

### 3.2 Secret Storage Reality

Verified in `backend/app/core/config.py`:
- **Current File Persistence:** Generated pairing tokens are persisted by writing directly into the `backend/.env` file.
- **Implementation Status:** Storing secrets in `backend/.env` is a **current development implementation reality**, not permanent secure secret-storage architecture.
- **Per-Device Credentials Status:** **NOT IMPLEMENTED**. The current codebase does not generate, validate, or store independent per-device credentials; all clients (web and Android) share the single `COMPANION_API_KEY`.

---

## 4. Approved Target Architecture / Not Yet Implemented

When implemented for target milestones:

1. **Independent Per-Device Revocable Credentials:** Transition from a single shared pairing key to per-device credentials (e.g., individual device tokens issued during authenticated pairing), allowing targeted revocation.
2. **Dedicated Platform Secret Storage:** Migration of sensitive credentials (pairing tokens, third-party provider keys) from plaintext `.env` files into platform-native credential storage.

---

## 5. Implementation-Open Details (Decision Debt)

The normative architecture for D4 and D5 is frozen. The following implementation-level details are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Rate Limiting Parameters:** Request rate thresholds, burst limits, and backoff windows per endpoint tier (`DEBT-V1-014`).
- **Host Secret Store Mechanism:** Specific host credential storage mechanism (Windows Credential Manager, DPAPI wrappers, or encrypted configuration files).
- **Client Secret Store Mechanism:** Mobile credential storage mechanism (Android Keystore, EncryptedSharedPreferences).
- **Token Rotation & Expiration:** Policies and automation for periodic credential rotation and inactivity timeouts.

---

## 6. Security & Ownership Boundaries

- **Constant-Time Verification:** All token comparisons must use constant-time operations to eliminate timing side-channels.
- **No Client Elevation:** Possession of a client token permits interaction with companion conversational APIs, but does not grant administrative authority to read host filesystem paths or manipulate host process lifecycles.
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
