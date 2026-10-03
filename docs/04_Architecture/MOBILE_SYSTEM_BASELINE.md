# Mobile Companion — Canonical System Baseline

> **Document Role:** High-level normative system architecture, capability matrix, and cross-cutting boundaries for the Mobile Companion (Flutter).
> **Status:** Active Canonical — Mobile Architecture Batches A, B, and C Approved
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
- **Credential Rotation:** An independently enrolled Device credential can be rotated/reissued without changing Profile identity. Architecture semantics (independent rotation, non-destructive expiration on `CREDENTIAL_EXPIRED` / `ROTATION_REQUIRED`) are **[RESOLVED IN BATCH C]** (see `04_Infrastructure/mobile-capabilities-and-runtime.md` §5.3); exact expiry periods, token format, overlap/grace windows, and automated refresh remain open implementation design.
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
| **Routines** | AVAILABLE | **[RESOLVED IN BATCH C]** (governed by PC Runtime scheduling; cached view offline; autonomous execution deferred post-V1) | **[RESOLVED IN BATCH C]** | UNAVAILABLE / Cached view only |
| **Conversations / history** | AVAILABLE (delegates to PC) | QUALIFIED / CACHED (offline local text turns on qualified devices with approved local LLM; read-only replica when unsupported) | Same as Offline | LIMITED / CACHED — read-only when local LLM unavailable; local turns import to Host with local-inference provenance (see `mobile-offline-and-sync.md` §3.2.6) |
| **Assistant inference** | HOST-DEPENDENT (delegates to PC Runtime) | **[RESOLVED IN BATCH C]** (CAPABILITY-DEPENDENT / OPTIONAL-AUXILIARY: qualified local model artifacts on evidence-qualified Tier 2 / Tier 3 devices; core productivity functional offline without local LLM) | OPTIONAL-CLOUD (requires local provider API credentials) | Degraded / Truthful offline notice when unsupported |
| **Voice** | HOST-DEPENDENT (full-duplex WebSocket to PC Runtime canonical STT/TTS/VAD providers; mandatory barge-in) | **[RESOLVED IN BATCH C]** (CAPABILITY-DEPENDENT: supports approved device-local TTS where qualifying provider installed; local STT and full offline conversational Voice independently gated; degrades truthfully to text mode when unsupported) | OPTIONAL-CLOUD (requires explicit separate cloud voice consent and local API credentials) | Degraded / Truthful fallback to text mode or local TTS playback only |
| **Character / personality presentation** | AVAILABLE | LOCAL/CACHED | LOCAL/CACHED | LOCAL/CACHED |
| **Memory** | HOST-DEPENDENT (delegates canonical writes/reads to PC) | UNAVAILABLE / Cached view only | UNAVAILABLE | UNAVAILABLE / Cached view only |
| **Settings** | AVAILABLE | LOCAL/CACHED | LOCAL/CACHED | LOCAL/CACHED |
| **Provider credentials** | AVAILABLE (device-local storage only) | AVAILABLE (device-local storage only) | AVAILABLE (device-local storage only) | AVAILABLE |
| **Local media / assets** | AVAILABLE | AVAILABLE | AVAILABLE | AVAILABLE |
| **Health / wearables** | **[RESOLVED IN BATCH C]** (MOBILE LATER / DEFERRED POST-V1; prototype mock UI sequestered; no clinical claims) | UNAVAILABLE | UNAVAILABLE | UNAVAILABLE |
| **Model management** | UNAVAILABLE (PC Host library admin) / **[RESOLVED IN BATCH C]** (Mobile D6 adaptation: LAN Host-to-Device transfer in V1; curated online bundle download optional post-V1; single resident model cap; engine-independent) | UNAVAILABLE (PC Host library admin) / **[RESOLVED IN BATCH C]** (Local mobile model lifecycle: single resident model cap; local load/unload/purge; engine-independent) | UNAVAILABLE (PC Host library admin) / **[RESOLVED IN BATCH C]** (Local mobile model management) | UNAVAILABLE (PC Host library admin) / **[RESOLVED IN BATCH C]** (Local mobile model management) |
| **Device / Profile administration** | UNAVAILABLE (PC Admin only) | UNAVAILABLE | UNAVAILABLE | UNAVAILABLE |

### 5.1 Additional Constraint Notes
- **Stale Cache / Offline Productivity:** Stale state must be visibly distinguishable where material. Security-sensitive operations must fail safely. Exact stale-client write permission, reconciliation, re-baselining, and conflict behavior are **[RESOLVED IN BATCH B]** (see `04_Infrastructure/mobile-offline-and-sync.md`).
- **Voice & Capability Decoupling:** Device-local TTS, device-local STT, and local LLM inference are three independently evaluated capabilities. A device may support local TTS (e.g. to vocalize companion text/alarms) without supporting local STT or hosting a local LLM. When connected, Voice uses the PC Runtime's canonical STT/TTS/VAD providers over WebSocket. Offline Mobile may use an approved device-local TTS provider where supported (engine-independent; candidate references such as Kokoro or platform engines are non-exclusive). Full offline conversational Voice and local STT remain independently capability-gated. Cloud LLM, Cloud STT, and Cloud TTS permission boundaries remain distinct, optional, and independently revocable. Raw provider API credentials remain device-local. Specific Mobile Voice and cloud routing is **[RESOLVED IN BATCH C]** (see `04_Infrastructure/mobile-capabilities-and-runtime.md`).
- **Revoked Credentials:** The PC Host immediately rejects requests. Handling of cached data purge, offline lockout, and re-enrollment while disconnected is **[RESOLVED IN BATCH B]** (see `04_Infrastructure/mobile-offline-and-sync.md`).

---

## 6. Resolved Architecture Batches
- **[RESOLVED IN BATCH B]** Local persistence semantics, outbox design, per-domain synchronization, reconciliation algorithms, and Android background execution responsibilities (WorkManager, Doze, exact alarms) are defined in [`04_Infrastructure/mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md).
- **[RESOLVED IN BATCH C]** Local mobile inference, semantic hardware tiers, Voice streaming and audio focus, Health/Wearables release disposition (Mobile Later), threat model completion, thermal/battery governance, testing matrix, and Mobile Golden Acceptance architecture are defined in [`04_Infrastructure/mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md).

---

## 7. Approved Mobile Decision Ledger

This ledger summarizes all approved Mobile Companion architectural decisions across Batches A, B, and C with direct cross-references to their authoritative canonical specifications. It serves as the primary orientation map for engineering agents and reviewers:

| Decision Domain | Status | Canonical Owner Specification | Key Architectural Invariant |
| :--- | :--- | :--- | :--- |
| **Foundation / Technology** | `[APPROVED A]` | [`MOBILE_SYSTEM_BASELINE.md`](./MOBILE_SYSTEM_BASELINE.md) §3, `ADR-0004` | Flutter is the cross-platform production mobile foundation in a shared monorepo; `android/` Kotlin/Compose is prototype/reference evidence only. |
| **Profile & Device Authority** | `[LOCKED]` | [`profiles-and-devices.md`](./02_Data_and_Security/profiles-and-devices.md), `ADR-0018` | PC Host is sole Account/Profile Admin; Mobile Satellite binds to exactly 1 Profile; cannot switch profiles or self-assert profile IDs in payloads. |
| **Authentication & Secrets** | `[LOCKED]` | [`authentication-and-secrets.md`](./02_Data_and_Security/authentication-and-secrets.md), `ADR-0005` | Mandatory application auth; independently revocable Device Token; Android Keystore storage; third-party provider credentials remain device-local. |
| **Transport Security** | `[LOCKED]` | [`MOBILE_SYSTEM_BASELINE.md`](./MOBILE_SYSTEM_BASELINE.md) §4.2, Decision D5 | Application authentication required regardless of network; approved encrypted overlay (Tailscale) or TLS; direct public router port forwarding strictly rejected. |
| **Offline Productivity & Tasks** | `[APPROVED B]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §2, §3 | Offline Task create, update, status (`SET_COMPLETION`), delete with durable local SQLite outbox; survives reboot/process death. |
| **Sync & Concurrency** | `[APPROVED B]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §3, §4 | Asymmetric per-domain sync; monotonic revision checks; client-generated stable entity IDs (UUIDv4); client LWW rejected; typed `CONFLICT_DETECTED` and `STALE_CURSOR`. |
| **Offline Conversation & Provenance** | `[APPROVED B/C]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §3.2.6 | Qualified Tier 2/3 devices support offline text turns; `client_message_id` idempotency; `MOBILE_LOCAL_INFERENCE` provenance; no Host tool replay or PC LLM regeneration; read-only when unsupported. |
| **Scheduling, Reminders & Alarms** | `[APPROVED B]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §5, §6, Decision D10, `ADR-0011` | PC `SchedulerService` is canonical scheduler truth; precomputed occurrences replicated; local delivery; exact alarm requires `SCHEDULE_EXACT_ALARM`; graceful degradation without exact alarm. |
| **Local LLM Inference** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §2 | Evidence-driven runtime qualification (Tiers 0–3); optional auxiliary capability in V1; core app works without local model; single resident model cap (`--models-max 1`). |
| **Local Text-to-Speech (TTS)** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §3.2 | Capability-dependent device-local TTS where approved provider installed; independent of local STT or local LLM; provider/engine-independent. |
| **Local Speech-to-Text (STT)** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §3.2 | Independently capability-gated; continuous heavy local STT deferred in V1; degrades truthfully to typed text when unavailable. |
| **Connected Voice Streaming** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §3, `ADR-0019` | Mobile owns capture/playback/audio focus; PC Runtime owns canonical STT/TTS/VAD/turn authority; full-duplex WebSocket; mandatory immediate barge-in. |
| **Optional Cloud Providers** | `[LOCKED]` | [`MOBILE_SYSTEM_BASELINE.md`](./MOBILE_SYSTEM_BASELINE.md) §5.1, `mobile-capabilities-and-runtime.md` §3.2 | Explicit opt-in only; personal API keys in Keystore; Cloud LLM, Cloud STT, and Cloud TTS are 3 independently revocable permissions; no silent cloud fallback. |
| **Model Lifecycle & Acquisition** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §2.3 | LAN Host-to-Device transfer in V1; single resident model cap; SHA-256 preflight; curated online bundle download is optional post-V1; container/engine format remains implementation-open. |
| **Platform Security & Sandboxing** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §5 | OS private application sandbox baseline; backup exclusion (`android:allowBackup="false"`); database encryption (SQLCipher) optional/threat-model dependent. |
| **Testing & Golden Acceptance** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §7, §8 | 5-layer verification matrix (L1–L5); evidence-driven L3 emulator matrix; 12 Mobile Golden Acceptance Groups (MG1–MG12); zero changes to PC CI workflows. |
| **Health & Wearables** | `[MOBILE LATER]` | [`health-and-wearables.md`](./03_Integrations/health-and-wearables.md), `mobile-capabilities-and-runtime.md` §4 | Real Health Connect and wearable biometric sync excluded from Mobile V1; mock UI sequestered; no clinical claims. |
| **Autonomous Local Routines** | `[MOBILE LATER]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §3.1 | Autonomous local routine execution deferred post-V1; cached view only offline; PC Runtime owns canonical scheduling. |
| **Local Multimodal / Vision Input** | `[MOBILE LATER]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §3.1 | Local VLM inference excluded from Mobile V1; future mobile vision architecture is implementation-open / post-V1; turn attachment upload only. |
