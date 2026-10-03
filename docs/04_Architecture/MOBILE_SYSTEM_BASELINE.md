# Mobile Companion — Canonical System Baseline

> **Document Role:** High-level normative system architecture, capability matrix, and cross-cutting boundaries for the Mobile Companion (Flutter).
> **Status:** Proposed Canonical — Mobile Architecture Batch A / Review Pending
> **Authority Precedence:** This document defines the Mobile ecosystem boundaries. Cross-cutting PC boundaries remain in `SYSTEM_BASELINE.md`. Detailed mobile implementation logic remains subject to future Mobile batches.

## 1. Justification & Canonical Ownership

This document serves as the dedicated Mobile baseline (`MOBILE_SYSTEM_BASELINE.md`). It is architecturally justified because the Mobile Companion requires its own cross-cutting definitions (offline capability, Flutter boundaries, mobile security) that extend beyond the PC-centric `SYSTEM_BASELINE.md`. The previous prototype-focused `01_Domains/android-companion.md` remains intact as the legacy reference boundary until all unique semantics are fully promoted and verified. 

## 2. Shared Ecosystem & Authority Boundary (Batch A)

The Mobile Companion operates as a Satellite in the broader AI Companion ecosystem. The following authority boundaries are **[LOCKED]**:

- **Account / Profile / Device:** The PC Host is the Account Admin. A Mobile device is an enrolled Satellite Device.
- **Profile Binding:** One normal Mobile Satellite binds to exactly ONE Profile.
- **Admin Authority:** The PC remains the sole Account and Profile administration authority. Mobile cannot arbitrarily create, delete, or switch Profiles.
- **Runtime Authority:** The Local AI Runtime remains the authoritative source for host-owned Runtime services, PC-hosted Profile state already defined as Runtime-owned, and model/tool/memory/scheduling truth where existing canonical specs assign that authority. Device-local secrets and future explicitly device-local Mobile state remain device-local. Per-domain replicated-state and synchronization authority remains **[OPEN FOR BATCH B]**.
- **Request Payloads:** Request payloads cannot self-assert arbitrary Profile ownership. Ownership is determined strictly by the authenticated session/device token.
- **Mobile Independence:** Mobile implementation remains completely independent from PC V1 delivery.
- **Device-Local Secrets:** Raw provider APIs and device-specific secrets remain device-local unless explicitly approved otherwise. A client-held device credential secret remains protected on the client, while the host maintains the corresponding Device/enrollment/credential validation record necessary to authenticate and revoke that Device.
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

## 5. Connected / Offline / Optional Cloud Capability Matrix (Batch A)

The Mobile Companion operates across distinct modes. This matrix defines **what should work** (the *how* is deferred to Batch B).

### 5.1 CONNECTED_TO_PC
- **State:** PC/Runtime reachable and authenticated.
- **Capabilities:** Full capability. Mobile delegates heavy inference, canonical memory writes, and history synchronization to the PC Runtime. When connected, approved PC Runtime services are available to Mobile. Exact Mobile STT/TTS/VAD/audio routing remains **[OPEN FOR BATCH C]**.

### 5.2 OFFLINE_LOCAL
- **State:** No PC and no usable network path.
- **Capabilities:** **[BATCH-A DECISION]** Mobile MUST remain usable for local capabilities. This includes locally created or modified Task state pending later reconciliation, triggering offline Reminders/Alarms/Routines, viewing cached conversation history, and accessing local media/assets. The Local AI Runtime `SchedulerService` remains canonical scheduling truth under D10/ADR-0011; Mobile may eventually maintain sufficient local replicated occurrence/delivery state for approved offline alert behavior. Exact replication, conflict handling, and reconciliation belong to **[OPEN FOR BATCH B]**.
- **Local Inference:** **[OPEN FOR BATCH C]** Disposition of local mobile LLM inference is deferred. If unavailable, Assistant and Voice capabilities are gracefully degraded or disabled offline.

### 5.3 OPTIONAL_CLOUD
- **State:** PC unavailable, but an explicitly configured cloud capability (e.g., a local API key for a cloud provider) exists and network is available.
- **Capabilities:** **[BATCH-A DECISION]** Cloud is NOT mandatory and requires explicit opt-in and device-local provider credentials. Existing shared architecture requires Cloud LLM, Cloud STT, and Cloud TTS permissions to remain distinct. Specific Mobile Voice/cloud routing and parsing tasks remain **[OPEN FOR BATCH C]**.

### 5.4 DEGRADED / PARTIALLY_AVAILABLE
- **Network Available, PC Unavailable:** Falls back to OFFLINE_LOCAL + OPTIONAL_CLOUD.
- **Credential Revoked:** The PC Host is the revocation authority. Once a Device credential is revoked, the Host immediately rejects subsequent requests using that credential. A disconnected/offline device cannot necessarily learn about remote revocation until it reaches an authoritative endpoint; host-backed and remote capabilities remain unavailable after revocation is discovered. Handling of cached local Profile data, local credential purge, offline lockout, re-enrollment, and Profile deletion while a device is offline remains **[OPEN FOR BATCH B]**.
- **Stale Local Cache:** Read-only access to cached domain data (Tasks, History) until sync is restored.

---

## 6. Open Architecture Decisions
The following areas are explicitly deferred and must not be implemented during Batch A:
- **[OPEN FOR BATCH B]** Local persistence semantics, outbox design, per-domain synchronization, reconciliation algorithms, and Android background execution responsibilities (WorkManager, Doze, exact alarms).
- **[OPEN FOR BATCH C]** Local mobile inference, exact Voice/audio architecture, Health/Wearables release disposition, threat model completion, and performance/thermal policies.
