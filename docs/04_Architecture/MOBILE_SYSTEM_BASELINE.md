# Mobile Companion — Canonical System Baseline

> **Document Role:** High-level normative system architecture, capability matrix, and cross-cutting boundaries for the Mobile Companion (Flutter).
> **Status:** Active Canonical — Mobile Architecture Batches A, B, and C Approved
> **Authority Precedence:** This document defines the Mobile ecosystem boundaries. Cross-cutting PC boundaries remain in `SYSTEM_BASELINE.md`. Detailed mobile architecture and cross-cutting boundaries have been finalized across approved Mobile Batches A, B, and C.

## 1. Justification & Canonical Ownership

This document serves as the dedicated Mobile baseline (`MOBILE_SYSTEM_BASELINE.md`). It is architecturally justified because the Mobile Companion requires its own cross-cutting definitions (offline capability, Flutter boundaries, mobile security) that extend beyond the PC-centric `SYSTEM_BASELINE.md`. The previous prototype-focused `01_Domains/android-companion.md` remains intact as the legacy reference boundary until all unique semantics are fully promoted and verified.

## 2. Shared Ecosystem & Authority Boundary

The Mobile Companion operates as a Satellite in the broader AI Companion ecosystem. The following authority boundaries are **[LOCKED]**:

- **Account / Profile / Device:** The PC Host is the Account Admin. A Mobile device is an enrolled Satellite Device.
- **Profile Binding (`D-PHONE-01B`):** One normal Mobile Satellite binds to exactly ONE Profile.
- **Admin Authority:** The PC remains the sole Account and Profile administration authority. Mobile cannot arbitrarily create, delete, or switch Profiles.
- **Standalone Mobile Operation (`D-PHONE-01A`):** Once enrolled, `STANDALONE_MOBILE` operation is an intended operating condition, not an application error or broken failure state. Mobile operates independently of the PC Host for local tasks, reminders, alarms, cached routines, and offline conversation turns where qualified.
- **Core Survivability (`D-PHONE-02`):** Core Mobile capabilities (Tasks, Reminders, Alarms, cached Routine views, local outbox/sync, settings, notifications) operate fully deterministically without requiring any local generative LLM.
- **Runtime Authority:** The Local AI Runtime remains the authoritative source for host-owned Runtime services, PC-hosted Profile state already defined as Runtime-owned, and model/tool/memory/scheduling truth where existing canonical specs assign that authority. Device-local secrets and future explicitly device-local Mobile state remain device-local. Per-domain replicated-state and synchronization authority is governed by [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md).
- **Request Payloads:** Request payloads cannot self-assert arbitrary Profile ownership. Ownership is determined strictly by the authenticated session/device token.
- **Mobile Independence:** Mobile implementation remains completely independent from PC V1 delivery.
- **Device-Local Secrets:** Raw provider API credentials remain device-local; they do not automatically synchronize between PC/Mobile/other Devices. A client-held device credential secret remains protected on the client, while the host maintains the corresponding Device/enrollment/credential validation record necessary to authenticate and revoke that Device.
- **Revocation:** Device credentials are independently revocable by the PC Host.

## 3. Flutter Shared-Code & Platform Boundary

To ensure development efficiency and cross-platform coherence while preventing mobile concerns from blocking or destabilizing PC V1, the following Flutter boundaries are established (**[LOCKED SHARED: D-SHARED-FLUTTER-01..08, D-PHONE-FLUTTER-01]**):

- **Workspace Topology (`D-SHARED-FLUTTER-01`):** Desktop and Mobile reside in a single shared Flutter workspace (monorepo), utilizing separate application targets (e.g., separate desktop and mobile application packages) to isolate platform compilation, dependencies, and packaging. Neither application target imports the other application target directly. Exact package names and paths remain open implementation details.
- **Shared Contracts over Universal Implementation (`D-SHARED-FLUTTER-02`):** Shared packages provide stable domain models, API DTOs, entity identity definitions, validation rules, repository/service interfaces, platform-neutral state/controller logic where appropriate, and machine-readable Golden test fixtures. The architecture does not mandate identical concrete implementations across platforms where OS lifecycles, persistence, background execution, or platform APIs differ.
- **Shared Typed Host Client (`D-SHARED-FLUTTER-03`):** A single shared client layer implements REST, SSE, and Voice WebSocket contracts, authentication token injection, typed error outcomes, and reconnection semantics. Desktop normally uses local/loopback Host transport; Mobile uses approved LAN / encrypted-overlay routes. REST / SSE / Voice WebSocket protocol semantics remain shared.
- **Shared Repository Contracts (`D-SHARED-FLUTTER-04`):** Repository and service interfaces are shared where semantically common, while concrete implementations remain capability-aware and platform-specific as needed.
- **Platform Adapter Isolation (`D-SHARED-FLUTTER-05`):** Shared packages MUST NOT directly import Android or Windows OS APIs. Platform contracts abstract platform capabilities (secure storage, native notifications, audio focus, camera, alarms, and background execution). Concrete platform adapters are isolated to their respective platform layers.
- **Shared Design Primitives, Platform-Specific Composition (`D-SHARED-FLUTTER-06`, `D-SHARED-FLUTTER-08`):** Typography roles, spacing scales, corner radii, semantic color tokens, accent color models, accessibility sizing, surface roles, animation curves, and icon semantics are shared. Desktop and Mobile compose these primitives into platform-appropriate layouts (e.g., desktop multi-pane layouts vs. mobile single-pane/adaptive navigation stacks). "One codebase" does NOT mean a monolithic screen layout congested with `if (isMobile)` conditional branches. Exact state management libraries remain open implementation choices.
- **Cross-Language Semantic Parity (`D-SHARED-FLUTTER-07`):** Where Host Python and Mobile Dart/native implement corresponding domain behavior (temporal intent parsing, entity UUIDs, sync conflict outcomes, conversation branches, tool structures), machine-readable Golden test vectors define authoritative semantic parity.
- **Kotlin Prototype as Reference Evidence Only (`D-PHONE-FLUTTER-01`):** The exploratory Kotlin/Compose codebase (`android/`) serves strictly as prototype/UX/research and migration evidence. Production Flutter architecture recovers approved product behavior and designs cleanly against canonical specifications rather than mechanically translating Kotlin code to Dart.

## 4. Mobile Identity, Enrollment & Transport

### 4.1 Device Identity & Enrollment (`D-PHONE-01B`)
- **Enrollment Prerequisite:** Normal Companion features require successful enrollment with an authorized PC Host. An unenrolled app exposes only setup, pairing, troubleshooting, and compatibility verification surfaces.
- **Single-Profile Binding:** A normal Mobile Satellite device binds to exactly ONE Profile on the PC Host.
- **Pairing & Credentials:** Device enrollment issues an independently revocable credential (Device Token) bound to that Profile. The UX direction uses a QR code or numeric pairing code displayed on the PC Host and scanned/entered on Mobile; underlying cryptographic handshakes and payload structures remain open implementation details.
- **Secret Storage:** Sensitive Mobile credentials (pairing tokens, device secrets, local provider API keys) MUST use platform-protected device-local storage backed by the **Android Keystore** (or a vetted Flutter secure storage abstraction backed by it). Plaintext storage (e.g., standard SharedPreferences) is strictly prohibited.
- **Third-Party Keys:** Cloud provider credentials or personal API keys configured on Mobile cannot substitute for PC Host enrollment.

### 4.2 Transport Security & Trust
- **Transport Constraints:** **[LOCKED]** Application authentication is mandatory regardless of network location.
- **Encrypted Transport:** Ordinary sensitive LAN traffic without an encrypted/protected transport path violates Decision D5. An approved encrypted overlay (such as Tailscale) provides transport protection even when the local application endpoint uses HTTP internally. Cloudflare Tunnel/Access remains the preferred remote-browser path.
- **Public Internet:** **[LOCKED]** Direct public router port forwarding remains strictly rejected.

### 4.3 Mobile Device Lifecycle (`D-PHONE-01B`)
- **Lifecycle States:** Mobile enrollment progresses through explicit conceptual states:
  - `UNENROLLED`: Device has no active Host binding; setup and pairing UX only.
  - `ENROLLED_ACTIVE`: Device is authenticated and bound to an active Profile; normal connected and standalone operations available.
  - `ENROLLED_REAUTH_REQUIRED`: Credential expired or re-authentication requested; synchronization paused, local profile data preserved pending re-auth.
  - `REVOKED`: Authoritative Host revocation; authenticated access halted, device credentials invalidated, and replicated profile domain data purged.
- **Credential Validation:** The Host authenticates the Device credential and validates the bound Profile from authoritative enrollment state. Mobile request payloads cannot override the authenticated Profile binding.
- **Credential Rotation:** An independently enrolled Device credential can be rotated without changing Profile identity (`mobile-capabilities-and-runtime.md` §5.3).
- **Profile Reassignment:** A normal Mobile Satellite cannot reassign itself to another Profile. Reassignment requires PC Account/Admin authority, requiring re-enrollment and credential replacement.
- **Lost / Stolen Device:** The PC Host can revoke a specific Device without resetting the Profile or other Devices.
- **App Reinstall / Credential Loss:** Reinstalling the app or clearing protected credential storage clears enrollment state and returns the client to `UNENROLLED`. Old authority is never silently recreated from local application artifacts.

## 5. Connected / Offline / Optional Cloud Capability Matrix

### 5.1 Three Orthogonal Availability Dimensions (`D-PHONE-01A`)

The Mobile Companion decouples host connection, internet access, and inference routing into three orthogonal state dimensions:

1. **Host Reachability:** `CONNECTED_TO_HOST` (LAN or encrypted overlay such as Tailscale) versus `DISCONNECTED_FROM_HOST`. When disconnected, the device operates in `STANDALONE_MOBILE` mode. Standalone operation is an intended operating condition, not an application failure or broken state.
2. **Internet Reachability:** `INTERNET_ONLINE` versus `INTERNET_OFFLINE`. Internet connectivity is evaluated independently of Host reachability. Direct internet access does NOT imply or require Cloud LLM usage; standalone read-only web tools (e.g. public search or weather lookups) may function while disconnected from the Host if internet is available.
3. **Inference Route:** Dynamic execution route chosen from:
   - `HOST_RUNTIME`: Delegated to PC Local AI Runtime when connected.
   - `MOBILE_LOCAL`: Executed via device-local SLM runtime on qualified tiers.
   - `CLOUD_PROVIDER`: Executed via direct user-configured Cloud LLM when explicitly authorized and internet is online.
   - `NONE / DETERMINISTIC`: Generative text unavailable; deterministic UI and companion capabilities remain operational.

### 5.2 Core Companion Survival Without Generative AI (`D-PHONE-02`)

The loss, unload, thermal suspension, battery throttling, or complete absence of a local generative model MUST NOT disable Mobile core functionality.

- **Deterministic Core Capabilities:** Tasks, Reminders, Alarms, cached Routine views, local mutation outbox, delta synchronization, device settings, model lifecycle management, connection status, and notifications operate fully deterministically without requiring a running local language model.
- **Conversational Scope:** Generative conversational turns require connectivity to the PC Host Runtime, a qualified and loaded device-local model, or an explicitly authorized Cloud LLM. When none are available, conversation view operates truthfully as a read-only historical cache.

### 5.3 Capability Matrix

The Mobile Companion decouples host connection, internet access, and inference routing into three orthogonal dimensions (§5.1). Rather than mutually exclusive top-level operational "modes", Mobile operates across distinct scenarios:
- **Standalone Mobile may still have internet:** Direct network reachability exists independently of Host connection.
- **Standalone Mobile inference flexibility:** A disconnected device may utilize qualified device-local SLM inference, explicitly authorized third-party Cloud LLM inference, or operate purely deterministically with no generative inference.
- **Internet availability does not imply Cloud AI authorization:** General network connectivity allows standalone tools (such as public web search or weather lookups) without implying or granting Cloud LLM permissions.
- **Host reachability does not define the inference route forever:** When connected, default execution routes to PC Host Runtime services, but local and cloud boundaries remain distinct capabilities.
- **Core deterministic features do not depend on an inference route:** Core companion functionality (Tasks, Reminders, Alarms, cached Routines, outbox sync, settings, notifications) functions deterministically regardless of inference route availability.

The following capability availability table defines behavior across these operational scenarios:

| Capability | Host-reachable behavior | Host-unreachable / Standalone behavior | Internet-dependent optional behavior | Degraded / unavailable behavior |
| :--- | :--- | :--- | :--- | :--- |
| **Tasks** | AVAILABLE | LOCAL/CACHED (locally created/modified Task state pending later reconciliation via client UUIDs; `D-SHARED-SCHED-01`) | Same as Standalone | LIMITED / CACHED — stale write rejection and conflict detection (`mobile-offline-and-sync.md` §3.1) |
| **Reminders** | AVAILABLE | LOCAL/CACHED (offline Mobile-origin create/edit/cancel/local delivery `D-PHONE-10`; Host-origin definitions read-only; duplicate suppression `D-SHARED-SCHED-02`) | Same as Standalone | LIMITED / CACHED — inexact background delivery when exact alarm permission missing |
| **Alarms** | AVAILABLE | LOCAL/CACHED (offline Mobile-origin create/edit/cancel/local delivery `D-PHONE-11`; Host-origin definitions read-only; reliability-first escalation `D-SHARED-SCHED-02`) | Same as Standalone | LIMITED / CACHED — degraded/unarmed locally if `canScheduleExactAlarms()` denied |
| **Routines** | AVAILABLE | LOCAL/CACHED (bounded Host-authorized future occurrences cached and presented `D-PHONE-12`; optional local presentation enrichment `D-PHONE-12A`; local suppression `D-PHONE-12C`; no autonomous recurrence extension) | Same as Standalone | UNAVAILABLE / Cached view only once bounded occurrences elapse |
| **Conversations / history** | AVAILABLE (delegates to PC) | QUALIFIED / CACHED (offline local text turns on evidence-qualified devices with approved local LLM installed; otherwise cached read-only history) | OPTIONAL-CLOUD (Cloud LLM text turns when explicitly authorized/configured and internet available; provider credentials remain device-local; turns persist durably while Host unavailable; later Host reconciliation uses Cloud-inference provenance) | LIMITED / CACHED — read-only when neither local LLM nor authorized Cloud LLM is available; disconnected turns import to Host with local-inference or cloud-inference provenance (see `mobile-offline-and-sync.md` §3.2.6) |
| **Assistant inference** | HOST-DEPENDENT (delegates to PC Runtime) | CAPABILITY-DEPENDENT / OPTIONAL-AUXILIARY: qualified local model artifacts on evidence-qualified Tier 2 / Tier 3 devices; core productivity functional offline without local LLM (`D-PHONE-02`) | OPTIONAL-CLOUD (requires local provider API credentials and explicit opt-in) | Degraded / Truthful offline notice when unsupported |
| **Voice** | HOST-DEPENDENT (full-duplex WebSocket to PC Runtime canonical STT/TTS/VAD providers; mandatory barge-in) | CAPABILITY-DEPENDENT: supports approved device-local TTS where qualifying provider installed; local STT and full offline conversational Voice independently gated; degrades truthfully to text mode when unsupported | OPTIONAL-CLOUD (requires explicit separate cloud voice consent and local API credentials) | Degraded / Truthful fallback to text mode or local TTS playback only |
| **Character / personality presentation** | AVAILABLE | LOCAL/CACHED | LOCAL/CACHED | LOCAL/CACHED |
| **Memory** | HOST-DEPENDENT (delegates canonical writes/reads to PC) | UNAVAILABLE / Cached view only | UNAVAILABLE | UNAVAILABLE / Cached view only |
| **Settings** | AVAILABLE | LOCAL/CACHED (device-local settings writable; profile settings read-only) | LOCAL/CACHED | LOCAL/CACHED |
| **Provider credentials** | AVAILABLE (device-local storage only) | AVAILABLE (device-local storage only) | AVAILABLE (device-local storage only) | AVAILABLE |
| **Local media / assets** | AVAILABLE | AVAILABLE | AVAILABLE | AVAILABLE |
| **Health / wearables** | [MOBILE LATER] (prototype mock UI sequestered; real sync deferred post-V1) | UNAVAILABLE | UNAVAILABLE | UNAVAILABLE |
| **Model management** | UNAVAILABLE (PC Host library admin) / LAN Host-to-Device transfer in V1; single resident model cap (`--models-max 1`) | Local mobile model lifecycle: single resident model cap; local load/unload/purge; engine-independent | Local mobile model management | Local mobile model management |
| **Device / Profile administration** | UNAVAILABLE (PC Admin only) | UNAVAILABLE | UNAVAILABLE | UNAVAILABLE |

### 5.4 Additional Constraint Notes
- **Stale Cache / Offline Productivity:** Stale state must be visibly distinguishable where material. Security-sensitive operations must fail safely. Exact stale-client write permission, reconciliation, re-baselining, and conflict behavior are defined in [`04_Infrastructure/mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md).
- **Voice & Capability Decoupling:** Device-local TTS, device-local STT, and local LLM inference are three independently evaluated capabilities. A device may support local TTS (e.g. to vocalize companion text/alarms) without supporting local STT or hosting a local LLM. When connected, Voice uses the PC Runtime's canonical STT/TTS/VAD providers over WebSocket. Offline Mobile may use an approved device-local TTS provider where supported (engine-independent). Full offline conversational Voice and local STT remain independently capability-gated. Cloud LLM, Cloud STT, and Cloud TTS permission boundaries remain distinct, optional, and independently revocable. Raw provider API credentials remain device-local. Specific Mobile Voice and cloud routing is governed by [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md).
- **Revoked Credentials:** The PC Host immediately rejects requests. Handling of cached data purge, offline lockout, and re-enrollment while disconnected is defined in [`04_Infrastructure/mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md).

---

## 6. Resolved Architecture Batches
- **[RESOLVED IN BATCH B]** Local persistence semantics, outbox design, per-domain synchronization, reconciliation algorithms, and Android background execution responsibilities (WorkManager, Doze, exact alarms) are defined in [`04_Infrastructure/mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md).
- **[RESOLVED IN BATCH C]** Local mobile inference, semantic hardware tiers, Voice streaming and audio focus, Health/Wearables release disposition (Mobile Later), threat model completion, thermal/battery governance, testing matrix, and Mobile Golden Acceptance architecture are defined in [`04_Infrastructure/mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md).

---

## 7. Approved Mobile Decision Ledger

This ledger summarizes approved Mobile Companion architectural decisions with direct cross-references to their authoritative canonical specifications. It serves as the primary orientation map for engineering agents and reviewers:

| Decision Domain | Status | Canonical Owner Specification | Key Architectural Invariant |
| :--- | :--- | :--- | :--- |
| **Foundation / Technology** | `[APPROVED A]` | [`MOBILE_SYSTEM_BASELINE.md`](./MOBILE_SYSTEM_BASELINE.md) §3, `ADR-0004` | Flutter is the cross-platform production mobile foundation in a shared monorepo; separate desktop and mobile app targets; `android/` Kotlin/Compose is prototype/reference evidence only (`D-SHARED-FLUTTER-01..08`, `D-PHONE-FLUTTER-01`). |
| **Availability Dimensions** | `[LOCKED V1]` | [`MOBILE_SYSTEM_BASELINE.md`](./MOBILE_SYSTEM_BASELINE.md) §5.1 | Host reachability, internet connectivity, and inference route are 3 orthogonal dimensions; `STANDALONE_MOBILE` is an intended operating condition (`D-PHONE-01A`). |
| **Profile & Device Authority** | `[LOCKED V1]` | [`profiles-and-devices.md`](./02_Data_and_Security/profiles-and-devices.md), `ADR-0018` | PC Host is sole Account/Profile Admin; Mobile Satellite binds to exactly 1 Profile; enrollment lifecycle: `UNENROLLED`, `ENROLLED_ACTIVE`, `ENROLLED_REAUTH_REQUIRED`, `REVOKED` (`D-PHONE-01B`). |
| **Core Survivability** | `[LOCKED V1]` | [`MOBILE_SYSTEM_BASELINE.md`](./MOBILE_SYSTEM_BASELINE.md) §5.2 | Core productivity (Tasks, Reminders, Alarms, cached Routines, sync, settings) operates deterministically without requiring a local generative LLM (`D-PHONE-02`). |
| **Authentication & Secrets** | `[LOCKED]` | [`authentication-and-secrets.md`](./02_Data_and_Security/authentication-and-secrets.md), `ADR-0005` | Mandatory application auth; independently revocable Device Token; Android Keystore storage; third-party provider credentials remain device-local. |
| **Transport Security** | `[LOCKED]` | [`MOBILE_SYSTEM_BASELINE.md`](./MOBILE_SYSTEM_BASELINE.md) §4.2, Decision D5 | Application authentication required regardless of network; approved encrypted overlay (Tailscale) or TLS; direct public router port forwarding strictly rejected. |
| **Offline Productivity & Tasks** | `[APPROVED B]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §2, §3 | Offline Task create, update, status (`SET_COMPLETION`), delete with durable local SQLite outbox; client-generated stable UUIDs (`D-SHARED-SCHED-01`). |
| **Sync & Concurrency** | `[APPROVED B]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §3, §4 | Asymmetric per-domain sync; monotonic revision checks; client-generated stable entity IDs (UUIDv4); client LWW rejected; typed `CONFLICT_DETECTED` and `STALE_CURSOR`. |
| **Offline Reminders & Alarms** | `[LOCKED V1]` | [`tasks-reminders-alarms-and-routines.md`](./01_Domains/tasks-reminders-alarms-and-routines.md), [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) | Mobile-created Reminders (`D-PHONE-10`) and Alarms (`D-PHONE-11`) authored and delivered locally offline; Host-origin definitions read-only while offline; occurrence dismiss/snooze supported. |
| **Alert Presentation Arbitration** | `[LOCKED SHARED]` | [`tasks-reminders-alarms-and-routines.md`](./01_Domains/tasks-reminders-alarms-and-routines.md) | Reminders favor duplicate suppression; Alarms favor reliability (primary rings, standby armed, escalation after grace, passive display != ack; `D-SHARED-SCHED-02`). |
| **Companion Alert Enrichment** | `[LOCKED SHARED]` | [`tasks-reminders-alarms-and-routines.md`](./01_Domains/tasks-reminders-alarms-and-routines.md) | Occurrence delivery is authoritative; character speech/TTS is optional enrichment; generation never delays, reschedules, or suppresses alerts; deterministic fallback mandatory (`D-SHARED-SCHED-03`). |
| **Replicated Routines** | `[LOCKED V1]` | [`tasks-reminders-alarms-and-routines.md`](./01_Domains/tasks-reminders-alarms-and-routines.md), [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) | Bounded Host-authorized occurrences presented offline (`D-PHONE-12`); local enrichment (`D-PHONE-12A`); connected authoring only (`D-PHONE-12B`); local suppression (`D-PHONE-12C`). |
| **Temporal Intent Resolution** | `[LOCKED SHARED]` | [`tasks-reminders-alarms-and-routines.md`](./01_Domains/tasks-reminders-alarms-and-routines.md) | LLM extracts typed intent; deterministic resolver parses; D9 policy evaluates; clarify material unresolved fields only (`D-SHARED-SCHED-04..04E`). |
| **Disconnected Conversation & Provenance** | `[APPROVED B/C]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §3.2.6 | Qualified Tier 2/3 devices support offline text turns; authorized Cloud LLM supported when disconnected; `client_message_id` idempotency; `MOBILE_LOCAL_INFERENCE` and `MOBILE_CLOUD_INFERENCE` provenance; no Host tool replay or PC LLM regeneration; read-only when unsupported. |
| **Scheduling, Reminders & Alarms Authority** | `[APPROVED B]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §5, §6, Decision D10, `ADR-0011` | PC Host / `SchedulerService` is canonical synchronized scheduler authority; Profile owns synchronized entities; Mobile maintains locally authoritative provisional state for Mobile-origin Reminders/Alarms within approved offline mutation authority; precomputed occurrences replicated; local delivery; exact alarm requires `SCHEDULE_EXACT_ALARM`; graceful degradation without exact alarm. |
| **Local LLM Inference** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §2 | Evidence-driven runtime qualification (Tiers 0–3); optional auxiliary capability in V1; core app works without local model; single resident model cap (`--models-max 1`). |
| **Local Text-to-Speech (TTS)** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §3.2 | Capability-dependent device-local TTS where approved provider installed; independent of local STT or local LLM; provider/engine-independent. |
| **Local Speech-to-Text (STT)** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §3.2 | Independently capability-gated; continuous heavy local STT deferred in V1; degrades truthfully to typed text when unavailable. |
| **Connected Voice Streaming** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §3, `ADR-0019` | Mobile owns capture/playback/audio focus; PC Runtime owns canonical STT/TTS/VAD/turn authority; full-duplex WebSocket; mandatory immediate barge-in. |
| **Optional Cloud Providers** | `[LOCKED]` | [`MOBILE_SYSTEM_BASELINE.md`](./MOBILE_SYSTEM_BASELINE.md) §5.1, `mobile-capabilities-and-runtime.md` §3.2 | Explicit opt-in only; personal API keys in Keystore; Cloud LLM, Cloud STT, and Cloud TTS are 3 independently revocable permissions; no silent cloud fallback. |
| **Model Lifecycle & Acquisition** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §2.3 | LAN Host-to-Device transfer in V1; single resident model cap; SHA-256 preflight; curated online bundle download is optional post-V1; container/engine format remains implementation-open. |
| **Platform Security & Sandboxing** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §5 | OS private application sandbox baseline; Android backup/data-extraction rules (`dataExtractionRules` / `backup_rules.xml`) explicitly exclude device-bound credentials, replicated databases, outbox journals, models, and caches from cloud backups and device transfers as appropriate; database encryption (SQLCipher) optional/threat-model dependent. |
| **Testing & Golden Acceptance** | `[APPROVED C]` | [`mobile-capabilities-and-runtime.md`](./04_Infrastructure/mobile-capabilities-and-runtime.md) §7, §8 | 5-layer verification matrix (L1–L5); evidence-driven L3 emulator matrix; 12 Mobile Golden Acceptance Groups (MG1–MG12); zero changes to PC CI workflows. |
| **Health & Wearables** | `[MOBILE LATER]` | [`health-and-wearables.md`](./03_Integrations/health-and-wearables.md), `mobile-capabilities-and-runtime.md` §4 | Real Health Connect and wearable biometric sync excluded from Mobile V1; mock UI sequestered; no clinical claims. |
| **Autonomous Local Routines** | `[MOBILE LATER]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §3.1 | Autonomous local routine execution deferred post-V1; cached view only offline; PC Runtime owns canonical scheduling. |
| **Local Multimodal / Vision Input** | `[IMPLEMENTATION OPEN / POST-V1 CANDIDATE]` | [`mobile-offline-and-sync.md`](./04_Infrastructure/mobile-offline-and-sync.md) §3.1 | Local VLM inference excluded from Mobile V1; local media capture and upload to PC Host supported; future local vision inference remains unscheduled and requires a separate decision; turn attachment upload only. |
