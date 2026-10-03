# Mobile Companion — Canonical System Baseline

> **Document Role:** High-level normative system architecture, capability matrix, and cross-cutting boundaries for the Mobile Companion (Flutter).
> **Status:** Active Canonical — Mobile Architecture Batch A/B Approved; Batch C Pending
> **Authority Precedence:** This document defines the Mobile ecosystem boundaries. Cross-cutting PC boundaries remain in `SYSTEM_BASELINE.md`. Detailed mobile implementation logic remains subject to future Mobile batches.

## 1. Justification & Canonical Ownership

This document serves as the dedicated Mobile baseline (`MOBILE_SYSTEM_BASELINE.md`). It is architecturally justified because the Mobile Companion requires its own cross-cutting definitions (offline capability, Flutter boundaries, mobile security) that extend beyond the PC-centric `SYSTEM_BASELINE.md`. The previous prototype-focused `01_Domains/android-companion.md` remains intact as the legacy reference boundary until all unique semantics are fully promoted and verified. 

## 2. Shared Ecosystem & Authority Boundary (Batch A)

The Mobile Companion operates as a Satellite in the broader AI Companion ecosystem. The following authority boundaries are **[LOCKED]**:

- **Account / Profile / Device:** The PC Host is the Account Admin. A Mobile device is an enrolled Satellite Device.
- **Profile Binding:** One normal Mobile Satellite binds to exactly ONE Profile.
- **Admin Authority:** The PC remains the sole Account and Profile administration authority. Mobile cannot arbitrarily create, delete, or switch Profiles.
- **Runtime Authority:** The Local AI Runtime remains the authoritative source for host-owned Runtime services, PC-hosted Profile state already defined as Runtime-owned, and model/tool/memory/scheduling truth where existing canonical specs assign that authority. Device-local secrets and future explicitly device-local Mobile state remain device-local. Per-domain replicated-state and synchronization authority is **[RESOLVED IN BATCH B]** (see `04_Infrastructure/mobile-offline-and-sync.md`).
- **Request Payloads:** Request payloads cannot self-assert arbitrary Profile ownership. Ownership is determined strictly by the authenticated session/device token.
- **Mobile Independence:** Mobile implementation remains completely independent from PC V1 delivery.
- **Device-Local Secrets:** Raw provider API credentials remain device-local; they do not automatically synchronize between PC/Mobile/other Devices. A client-held device credential secret remains protected on the client, while the host maintains the corresponding Device/enrollment/credential validation record necessary to authenticate and revoke that Device.
- **Revocation:** Device credentials are independently revocable by the PC Host.

## 3. Flutter Shared-Code & Platform Boundary (Batch A)

To prevent M1 Flutter Desktop and future Flutter Mobile from diverging unnecessarily while keeping Mobile concerns from contaminating PC V1, the following boundary is established (**[BATCH-A DECISION]**):

- **Workspace Topology:** Desktop and Mobile should reside in a single shared Flutter workspace (monorepo), utilizing separate application targets (e.g., separate desktop and mobile application packages) to isolate platform compilation.
- **Shared Packages:** Stable domain contracts, generated/shared API contracts, reusable design primitives, and authentication abstractions MUST be shared packages.
- **State Management & Repositories:** Suitable platform-neutral repository and service interfaces MUST be shared. This does not mandate identical business logic across platforms; platform-specific implementations are permitted where lifecycle, persistence, background execution, security, or OS APIs differ.
- **Platform Adapters:** Any functionality interacting directly with OS hardware, lifecycle, or platform APIs (e.g., Android WorkManager, Windows System Tray, native secure storage) MUST remain completely platform-specific and be injected via explicit platform-service interfaces. 
- **Maximum Sharing is Not the Goal:** The architecture prefers sharing stable domain contracts and isolating platform behavior over forcing unified implementations where platforms fundamentally differ.

## 4. Mobile Identity, Enrollment & Transport (Batch A)

### 4.1 Device Identity & Enrollment
- **Pairing & Credentials:** Device enrollment issues an independently revocable credential (Device Token) bound to one Profile.
- **Secret Storage:** **[BATCH-A DECISION]** Sensitive Mobile credentials (pairing tokens, local secrets) MUST use approved platform-protected device-local storage. Android Keystore (or a vetted Flutter abstraction backed by it) is the primary target for Android deployments. Plaintext storage (e.g., standard SharedPreferences) is strictly prohibited.

### 4.2 Transport Security & Trust
- **Transport Constraints:** **[LOCKED]** Application authentication is mandatory regardless of network location. 
- **Encrypted Transport:** **[BATCH-A DECISION]** Ordinary sensitive LAN traffic without an encrypted/protected transport path violates D5. An approved encrypted overlay (such as Tailscale) provides transport protection even when the local application endpoint uses HTTP internally. Cloudflare Tunnel/Access remains the preferred remote-browser path. 
- **Public Internet:** **[LOCKED]** Direct public router port forwarding remains strictly rejected.

### 4.3 Mobile Device Lifecycle
- **Credential Validation:** The Host must authenticate the Device credential and derive/validate the Device's bound Profile from authoritative enrollment/session state. Mobile request payloads cannot override the authenticated Profile binding.
- **Credential Rotation:** An independently enrolled Device credential can be rotated/reissued without changing Profile identity. Exact expiry periods, token format, overlap/grace windows, and rotation automation remain **[OPEN FOR BATCH C]**.
- **Profile Reassignment:** A normal Mobile Satellite cannot reassign itself to another Profile. Reassignment requires PC Account/Admin authority. Reassignment semantically requires re-enrollment / credential replacement or another explicit host-authorized transition. The old Profile's authorization must not survive reassignment.
- **Lost / Stolen Device:** The PC Host must be able to revoke that specific Device without resetting the Profile or other Devices. Host access using the revoked credential must fail. Offline local-data handling remains subject to later security policy (**[RESOLVED IN BATCH B]** - see `04_Infrastructure/mobile-offline-and-sync.md`).
- **App Reinstall / Credential Loss:** A reinstall or loss of protected local enrollment credentials must not silently recreate authenticated Device authority from arbitrary local data. The architectural recovery direction requires explicit re-enrollment or another host-authorized recovery flow.

## 5. Connected / Offline / Optional Cloud Capability Matrix (Batch A)

The Mobile Companion operates across distinct modes. This matrix defines **what should work** (the *how* is deferred to Batch B and C). Connected Mobile remains subject to Mobile authority boundaries and release scope.

| Capability | `CONNECTED_TO_PC` | `OFFLINE_LOCAL` | `OPTIONAL_CLOUD` | `DEGRADED / PARTIALLY_AVAILABLE` |
| :--- | :--- | :--- | :--- | :--- |
| **Tasks** | AVAILABLE | LOCAL/CACHED (locally created/modified Task state pending later reconciliation) | Same as Offline | LIMITED / CACHED — exact stale write permission and reconciliation **[RESOLVED IN BATCH B]** |
| **Reminders** | AVAILABLE | LOCAL/CACHED (replicated occurrence state/duplicate suppression is **[RESOLVED IN BATCH B]**) | Same as Offline | LIMITED / CACHED — exact stale write permission and reconciliation **[RESOLVED IN BATCH B]** |
| **Alarms** | AVAILABLE | LOCAL/CACHED (exact offline behavior is **[RESOLVED IN BATCH B]**) | Same as Offline | LIMITED / CACHED — exact stale write permission and reconciliation **[RESOLVED IN BATCH B]** |
| **Routines** | AVAILABLE | **[OPEN FOR BATCH C]** (governed by canonical Runtime scheduling, execution may require Batch C resolution) | **[OPEN FOR BATCH C]** | UNAVAILABLE / Cached view only |
| **Conversations / history** | AVAILABLE (delegates to PC) | LOCAL/CACHED (viewing cached history) | Same as Offline | LIMITED / CACHED — exact stale write permission and reconciliation **[RESOLVED IN BATCH B]** |
| **Assistant inference** | HOST-DEPENDENT | **[OPEN FOR BATCH C]** (local mobile LLM disposition deferred) | OPTIONAL-CLOUD (requires local provider API credentials) | Degraded / Unavailable |
| **Voice** | HOST-DEPENDENT (approved PC Runtime services available; STT/TTS/VAD routing is **[OPEN FOR BATCH C]**) | **[OPEN FOR BATCH C]** | OPTIONAL-CLOUD (requires local provider API credentials) | Degraded / Unavailable |
| **Character / personality presentation** | AVAILABLE | LOCAL/CACHED | LOCAL/CACHED | LOCAL/CACHED |
| **Memory** | HOST-DEPENDENT (delegates canonical writes/reads to PC) | UNAVAILABLE / Cached view only | UNAVAILABLE | UNAVAILABLE / Cached view only |
| **Settings** | AVAILABLE | LOCAL/CACHED | LOCAL/CACHED | LOCAL/CACHED |
| **Provider credentials** | AVAILABLE (device-local storage only) | AVAILABLE (device-local storage only) | AVAILABLE (device-local storage only) | AVAILABLE |
| **Local media / assets** | AVAILABLE | AVAILABLE | AVAILABLE | AVAILABLE |
| **Health / wearables** | **[OPEN FOR BATCH C]** | **[OPEN FOR BATCH C]** | **[OPEN FOR BATCH C]** | **[OPEN FOR BATCH C]** |
| **Model management** | UNAVAILABLE (PC Host library admin) / **[OPEN FOR BATCH C]** (Mobile-local inference lifecycle) | UNAVAILABLE (PC Host library admin) / **[OPEN FOR BATCH C]** (Mobile-local inference lifecycle) | UNAVAILABLE (PC Host library admin) / **[OPEN FOR BATCH C]** (Mobile-local inference lifecycle) | UNAVAILABLE (PC Host library admin) / **[OPEN FOR BATCH C]** (Mobile-local inference lifecycle) |
| **Device / Profile administration** | UNAVAILABLE (PC Admin only) | UNAVAILABLE | UNAVAILABLE | UNAVAILABLE |

### 5.1 Additional Constraint Notes
- **Stale Cache / Offline Productivity:** Stale state must be visibly distinguishable where material. Security-sensitive operations must fail safely. Exact stale-client write permission, reconciliation, re-baselining, and conflict behavior are **[RESOLVED IN BATCH B]** (see `04_Infrastructure/mobile-offline-and-sync.md`).
- **Cloud Separation:** Cloud is optional and requires explicit opt-in. Cloud LLM, Cloud STT, and Cloud TTS permission boundaries remain distinct. Raw provider API credentials remain device-local. Specific Mobile Voice/cloud routing remains **[OPEN FOR BATCH C]**.
- **Revoked Credentials:** The PC Host immediately rejects requests. Handling of cached data purge, offline lockout, and re-enrollment while disconnected is **[RESOLVED IN BATCH B]** (see `04_Infrastructure/mobile-offline-and-sync.md`).

---

## 6. Open Architecture Decisions
The following areas are explicitly deferred and must not be implemented during Batch A:
- **[RESOLVED IN BATCH B]** Local persistence semantics, outbox design, per-domain synchronization, reconciliation algorithms, and Android background execution responsibilities (WorkManager, Doze, exact alarms) are defined in `04_Infrastructure/mobile-offline-and-sync.md`.
- **[OPEN FOR BATCH C]** Local mobile inference, exact Voice/audio architecture, Health/Wearables release disposition, threat model completion, and performance/thermal policies.
