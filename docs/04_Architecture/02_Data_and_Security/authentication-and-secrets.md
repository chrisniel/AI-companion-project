# Authentication and Secrets Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.3).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** Focused staged specification authored during R11.3. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md`](../SECURITY_AND_TRUST_ARCHITECTURE.md) (§2, §3) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decisions D4, D5) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the cryptographic authentication mechanisms, secret storage policies, and transport trust models for the AI Companion:
- Fail-closed API authentication protecting companion endpoints.
- Separation of network proximity from identity authentication.
- Supported network trust topologies (localhost, trusted LAN, private overlay mesh).
- Explicit rejection of direct public internet port forwarding.
- Evolution path from current file-based secret storage to durable host secret stores.
- Token validation and timing-attack defense invariants.

---

## 2. Durable Architecture & Invariants

### 2.1 Fail-Closed Authentication & Network Boundaries (Decision D5)

In accordance with Decision D5:
- **Fail-Closed by Construction:** All companion endpoints require explicit cryptographic authentication by default. Endpoints are protected unless explicitly assigned to a strictly bounded public whitelist.
- **Proximity is Not Authentication:** Physical or network-layer proximity (such as sharing the same local Wi-Fi router or subnet) does **not** grant implicit trust or bypass authentication. Network proximity never substitutes for application auth. All protected companion API interactions require valid application authentication regardless of network proximity. Explicitly whitelisted, minimal public probes such as `GET /api/v1/health` remain bounded exceptions.
- **Master Secret Containment:** Master runtime administrative secrets and third-party API credentials are held strictly on the host runtime machine and are **never** transmitted to or stored on client endpoints. Database encryption passphrases do not currently exist and are not a required secret class unless encryption-at-rest is separately approved.

### 2.2 Supported Trust Topologies

The companion architecture supports three bounded network topologies under Decision D5:
1. **Authenticated Localhost Loopback:** Local browser and host processes communicating over `127.0.0.1` / `::1`.
2. **Explicitly Trusted LAN:** Satellite devices communicating across a private home network with explicit host pairing and application authentication.
3. **Encrypted Overlay Mesh (Tailscale / Private Mesh):** Remote satellite access routed through an authenticated, encrypted private mesh network without exposing open router ports.

### 2.3 Direct Public Internet Port Forwarding Rejected

In accordance with the Feature Promotion Map (**Direct Public Internet Port Forwarding**):
- **Classification:** `REJECTED / NOT STARTED / N/A`.
- **Policy Invariant:** Direct port forwarding from the public internet (opening external router ports, dynamic DNS directly to companion port, unauthenticated public ingress) is **strictly excluded** from the supported trust model. The companion runtime is not a multi-tenant public web server and must never be exposed directly to unauthenticated public internet traffic.

---

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
- **Current Token Schema:** Uses a single shared pairing key (`COMPANION_API_KEY`). On initial launch without a configured key, `ensure_pairing_token()` generates a 32-byte URL-safe string (`companion_sec_<token>`).

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

## 5. OPEN DESIGN

The following implementation choices remain open design for future technical specification:

- **Host Secret Store Mechanism:** Specific host credential storage mechanism (evaluating alternatives such as Windows Credential Manager, DPAPI wrappers, or encrypted configuration files).
- **Client Secret Store Mechanism:** Specific mobile credential storage mechanism (evaluating Android Keystore, EncryptedSharedPreferences, or secure hardware-backed storage).
- **Application-Layer TLS & Transport Encryption:** Application-layer TLS / certificate enrollment remains open design where applicable. Tailscale and private mesh networks may already provide encrypted transport. Exact TLS certificate source, local CA generation, Tailscale HTTPS, mutual TLS, and certificate enrollment remain open design and are not locked as an approved implementation requirement.
- **Enrollment & Handshake Protocol:** Cryptographic handshake for device pairing (e.g., SPAKE2, QR-encoded ephemeral bootstrap tokens, or mutual authentication protocols).
- **Token Rotation & Expiration:** Policies and automation for periodic credential rotation, inactivity timeouts, and re-authentication handshakes.

---

## 6. Security & Ownership Boundaries

- **Constant-Time Verification:** All token comparisons must use constant-time operations to eliminate timing side-channels.
- **No Client Elevation:** Possession of a client token permits interaction with companion conversational APIs, but does not grant administrative authority to read host filesystem paths or manipulate host process lifecycles.
- **CORS Containment:** CORS origins in `settings.CORS_ORIGINS` restrict cross-origin browser access to explicitly authorized development localhost/loopback origins (`http://localhost:5173`, `http://127.0.0.1:5173`, `http://localhost:3000`, `http://127.0.0.1:3000`). These are current development localhost/loopback origins, not production origins, and are not promoted into durable architecture.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Decisions D4 (Profile vs Device), D5 (Network trust tiers).
- [`docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md`](../SECURITY_AND_TRUST_ARCHITECTURE.md) — Threat model, network zones, credential classifications.

### Related Domain & Security Specifications
- [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](profiles-and-devices.md) — Device identity, enrollment state, and client lifecycle.
- [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](tool-permissions-and-actions.md) — Permission gates for tool execution.
- [`docs/04_Architecture/03_Integrations/web-current-information.md`](../03_Integrations/web-current-information.md) — SSRF protection and external egress boundaries.
