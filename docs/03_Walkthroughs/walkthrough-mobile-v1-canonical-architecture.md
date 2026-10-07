# Walkthrough: Mobile V1 Canonical Architecture & Delivery Planning

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Comprehensive technical walkthrough and developer handover for the MOBILE-ARCH canonical architecture pass, establishing Mobile cross-cutting ecosystem boundaries, offline persistence and synchronization, native Android reliability, local/cloud inference capabilities, and 65-item execution planning.
- **Audience:** Developers, maintainers, architecture reviewers, and future implementation agents.
- **Status:** Verified — Closure Gate Passed
- **Last Updated:** 2026-10-04

---

## 1. What Was Delivered

The MOBILE-ARCH delivery establishes the complete canonical architecture, synchronization protocols, hardware qualification tiers, native platform policies, and master engineering plans for the Mobile Companion (V1 target).

### Scope Summary
- **Mobile Canonical System Baseline ([`MOBILE_SYSTEM_BASELINE.md`](../04_Architecture/MOBILE_SYSTEM_BASELINE.md)):** Established the Satellite Device ecosystem boundary, single-Profile binding, three operating execution modes, and the Approved Mobile Decision Ledger covering 19 decision domains (§7).
- **Batch A Foundation:** Aligned the Mobile foundation with existing accepted architecture decisions: used [`ADR-0004`](../04_Architecture/decisions/ADR-0004-d3-android-application-identity.md) for Android package identity (`com.cnl.aicompanion`), inherited Profile/Device authority boundaries from [`ADR-0005`](../04_Architecture/decisions/ADR-0005-d4-profile-device-credential-boundary.md) and [`ADR-0018`](../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md), inherited client/runtime transport boundaries from [`ADR-0019`](../04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md), added Mobile-specific Flutter workspace topology rules in [`MOBILE_SYSTEM_BASELINE.md` §3](../04_Architecture/MOBILE_SYSTEM_BASELINE.md), and updated navigation across all 20 canonical specifications.
- **Batch B Offline & Native Reliability ([`mobile-offline-and-sync.md`](../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md)):** Defined local relational SQLite persistence, durable transactional outbox journal, per-domain sync protocols, deterministic conflict handling (no client last-write-wins), monotonic change cursors, tombstone retention, and revocation cleanup.
- **Batch C Capabilities & Verification ([`mobile-capabilities-and-runtime.md`](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) & [`health-and-wearables.md`](../04_Architecture/03_Integrations/health-and-wearables.md)):** Defined evidence-driven hardware qualification tiers (Tiers 0–3), single-model memory cap (`--models-max 1`), decoupled local/cloud inference, independent local TTS/STT capabilities, WebSocket audio streaming to PC, Android foreground service/lifecycle policies, exact `AlarmManager.setAlarmClock()` delivery (conditional on exact-alarm capability/access), and sequestered Health Connect to Mobile Later (Post-V1).
- **Cross-Batch Architecture Reconciliation:** Harmonized decisions across all three batches, eliminating stale terminology, establishing clean capability-mode separation, and normalizing contract naming.
- **Phase 4 Planning Integration ([`MOBILE_WBS.md`](../02_Planning/00_Master/MOBILE_WBS.md) & [`MOBILE_CHECKLIST.md`](../02_Planning/00_Master/MOBILE_CHECKLIST.md)):** Built a complete 65-item Work Breakdown Structure across 11 streams, linked with the master planning spine, alongside the Mobile readiness audit mapped to MG1–MG12 and verification layers L1–L5 (55 readiness rows).

> [!IMPORTANT]
> **NO PRODUCTION MOBILE IMPLEMENTATION IS DELIVERED BY MOBILE-ARCH.**
> This delivery consists strictly of canonical architecture, documentation, and engineering master planning.
> - The existing Kotlin/Jetpack Compose codebase under `android/` remains an exploratory prototype and reference evidence only.
> - Production Flutter Mobile implementation is classified as `APPROVED TARGET / NOT STARTED`.
> - Host contract prerequisites are target designs and not yet implemented in backend code.
> - The immediate engineering priority on the shared milestone roadmap remains **M1 Flutter Client Foundation** (Desktop).
> - Mobile Companion implementation will proceed as an independent follow-on track per `MOBILE_WBS.md` without blocking M1.

---

## 2. Files / Authority Map

The table below details the canonical authorities established and maintained by this delivery:

| Canonical Document | Architectural Role & Ownership |
| :--- | :--- |
| [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../04_Architecture/MOBILE_SYSTEM_BASELINE.md) | **Primary Mobile System Baseline:** Defines Satellite Device boundary, single-Profile binding, execution modes, PC vs Mobile authority division, shared Flutter workspace (§3), Mobile Keystore policy (§4.1), and the Approved Mobile Decision Ledger covering 19 decision domains (§7). |
| [`docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`](../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) | **Offline Persistence & Synchronization:** Owns local relational SQLite store, durable transactional outbox, entity sync protocols, Host revision checks, conflict resolution, change cursors, tombstones, and quarantine/revocation erasure. |
| [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) | **Runtime Capabilities & Native Reliability:** Owns hardware tiers 0–3, model residency, decoupled local/cloud inference, independent TTS/STT, WebSocket audio streaming, Android foreground services, lifecycle management, Keystore platform security (§5), L1–L5 verification matrix (§7.1), and Golden acceptance groups MG1–MG12 (§8). |
| [`docs/04_Architecture/03_Integrations/health-and-wearables.md`](../04_Architecture/03_Integrations/health-and-wearables.md) | **Wearables & Biometrics Boundary:** Defines health data handling policies, security/privacy boundaries, and explicitly defers Health Connect to Mobile Later (Post-V1). |
| [`docs/04_Architecture/01_Domains/android-companion.md`](../04_Architecture/01_Domains/android-companion.md) | **Prototype Boundary Specification:** Documents the role, limits, and preserved reference evidence of the exploratory Kotlin/Compose codebase (`android/`). |
| [`docs/04_Architecture/decisions/ADR-0004`](../04_Architecture/decisions/ADR-0004-d3-android-application-identity.md) | **ADR D3 (Pre-existing accepted decision):** Locks package identity as `com.cnl.aicompanion` (shared Flutter workspace defined in `MOBILE_SYSTEM_BASELINE.md §3`). |
| [`docs/04_Architecture/decisions/ADR-0005`](../04_Architecture/decisions/ADR-0005-d4-profile-device-credential-boundary.md) | **ADR D4 (Pre-existing accepted decision):** Defines Profile vs Device and independently revocable Device credential boundary (Android Keystore policy defined in `MOBILE_SYSTEM_BASELINE.md §4.1` and `mobile-capabilities-and-runtime.md §5`). |
| [`docs/04_Architecture/decisions/ADR-0018`](../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md) | **ADR D7 (Pre-existing accepted decision):** Defines 1 Account / multiple isolated Profiles and single-Profile satellite binding. |
| [`docs/04_Architecture/decisions/ADR-0019`](../04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md) | **ADR (Pre-existing accepted decision):** Defines REST / SSE / WebSocket client-runtime responsibilities. |
| [`docs/02_Planning/00_Master/MOBILE_WBS.md`](../02_Planning/00_Master/MOBILE_WBS.md) | **Mobile Engineering WBS:** Canonical catalog of 65 work items across 11 streams (`MOB-FOUNDATION` through `MOB-VERIFY`) with dependencies and implementation states. |
| [`docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`](../02_Planning/00_Master/MOBILE_CHECKLIST.md) | **Mobile Readiness Checklist:** Readiness audit mapped to Golden groups MG1–MG12 (55 readiness rows) tracking prototype gaps, verification criteria, and implementation states. |
| [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](../02_Planning/00_Master/DELIVERY_INDEX.md) & Spine | **Master Planning Spine:** Reconciled milestone sequencing, cross-platform dependencies, and delivery indexes across all planning documents. |

---

## 3. How the Architecture Works

### 3.1 Operating Execution Modes

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        MOBILE EXECUTION MODES                          │
├─────────────────────┬───────────────────────────┬──────────────────────┤
│   CONNECTED_TO_PC   │       OFFLINE_LOCAL       │    OPTIONAL_CLOUD    │
├─────────────────────┼───────────────────────────┼──────────────────────┤
│ • Host PC LLM       │ • Local SQLite Tasks      │ • Explicit user opt-in│
│ • Host FTS5 Memory  │ • Punctual exact alarms   │ • Device Keystore key│
│ • Host typed tools  │   (conditional on exact-  │ • No Host tool access│
│   (Decision D9)     │   alarm access) &         │ • Disconnected turn  │
│ • Low-Latency Audio │   tolerant Reminders      │   import via outbox  │
│   over WebSocket    │ • Qualified Local LLM*    │ • No silent fallback │
│ • REST / SSE sync   │ • Independent Local TTS** │ • Provider-neutral   │
│                     │ • Cached Context Replica  │                      │
│                     │ • Zero Host tool access   │                      │
│                     │ • No auto Memory writes   │                      │
└─────────────────────┴───────────────────────────┴──────────────────────┘
* Tier 2/3 devices with installed model only; otherwise cached/read-only conversation.
** Independent of local LLM; requires installed on-device TTS engine.
```

#### 1. CONNECTED_TO_PC (Primary Mode)
- **Authority:** Host PC Runtime is the primary intelligence source.
- **Communication:** Encrypted transport (TLS on LAN or Tailscale overlay, Decision D5); direct router port forwarding strictly rejected.
- **Capabilities:** REST APIs for CRUD operations; SSE for token streaming; low-latency bidirectional WebSocket for Voice (audio streaming, barge-in detection, speech-to-text, text-to-speech processed on PC); Host-governed typed tools under Decision D9.
- **Mobile Responsibilities:** UI/client presentation, local platform service adapters, audio capture/playback/routing with focus management, local notification/alarm presentation, and local persistence/sync client responsibilities.

#### 2. OFFLINE_LOCAL (Reliable Edge Mode)
- **Tasks:** Fully operable offline. Creates, updates, status changes (`SET_COMPLETION(completed=bool)`), and deletes are executed against local SQLite and logged to the durable transactional outbox journal.
- **Replicated Reminder/Alarm Occurrences:** Punctual exact alarms use `AlarmManager.setAlarmClock()` when exact-alarm capability/access exists; if unavailable, state truthfully becomes degraded/unarmed. Reminders use best-effort/tolerant/inexact scheduling (may be delayed/batched by Android/Doze). Full-screen alarm presentation is conditional and not guaranteed on modern Android. Local dismiss/snooze controls operate disconnected and journal outbox events for sync upon reconnection.
- **Conversational Intelligence:** Capability-gated.
  - *Qualified Tier 2/3 hardware with approved model installed:* Supports offline local conversational text generation.
  - *Unqualified or model-less devices:* Maintains cached, read-only conversation history; dialogue prompts inform user that PC connection is required.
- **Voice Independence:** A device with an approved on-device TTS provider can speak offline text responses without requiring a local LLM or local STT.
- **Boundaries:** Zero autonomous writes to canonical Host Memory; no Host tool execution.

#### 3. OPTIONAL_CLOUD (Auxiliary Independent Mode)
- **Explicit Permissions:** Strictly opt-in per provider (provider-neutral, e.g., third-party LLM, STT, or TTS APIs).
- **Secret Isolation:** Provider API keys are stored exclusively in the mobile Android Keystore and are never transmitted to or managed by the PC Host.
- **Fail-Closed Policy:** Transparent or silent cloud fallback is strictly forbidden. If PC is offline and local LLM is absent, the client does not fall back to cloud unless explicitly authorized and initiated by user action.
- **Disconnected Reconciliation:** Turns generated via Cloud while disconnected from PC are captured as complete whole-turn units with `MOBILE_CLOUD_INFERENCE` provenance in local storage, journaled to the outbox (`MOB-CONV-006` -> `MOB-DATA-004`), and imported into Host conversation history upon reconnection without Host LLM regeneration.
- **Boundaries:** Cloud models possess zero execution authority over PC Host tools or Host system state.

### 3.2 Data Synchronization & Conflict Resolution

```text
  MOBILE CLIENT                                          HOST RUNTIME (PC)
┌─────────────────┐                                    ┌─────────────────┐
│ Local SQLite DB │                                    │ Canonical DB    │
│                 │                                    │                 │
│ ┌─────────────┐ │                                    │                 │
│ │Outbox Store │ │                                    │                 │
│ └──────┬──────┘ │                                    │                 │
└────────┼────────┘                                    └────────┬────────┘
         │ 1. Push pending mutations:                           │
         │    [mutation_id, entity_id, base_revision, payload]  │
         ├─────────────────────────────────────────────────────►│
         │                                                      │ 2. Validate base_rev:
         │                                                      │    If match -> Apply,
         │                                                      │    rev++, return OK.
         │ 3. Response: typed success / CONFLICT_DETECTED       │    If mismatch ->
         │◄─────────────────────────────────────────────────────┤    CONFLICT_DETECTED
         │                                                      │
         │ 4. Pull changes: request changes after cursor        │
         ├─────────────────────────────────────────────────────►│
         │                                                      │ 5. Query changes > cursor:
         │ 6. Response: [delta entities + tombstones, new cursor│    Return deltas or
         │    or typed STALE_CURSOR]                            │    STALE_CURSOR.
         │◄─────────────────────────────────────────────────────┤
```
*Note: The sequence above illustrates conceptual synchronization flow. Exact HTTP paths, DTO schemas, and wire status codes remain implementation-open.*

- **Entity Identity:** Stable client-generated UUIDv4 entity IDs for offline-creatable entities, preserved identically across Mobile and PC.
- **Durable Outbox Journal:** Every local mutation is committed to the SQLite outbox with a unique `mutation_id`, target entity ID, mutation type, payload, and the `base_revision` observed locally.
- **Outbox Ordering:** Mutations are durable; causal ordering must be preserved; pending CREATE dependencies use either safe coalescing or explicit per-entity dependency/order. Conversation turns preserve their own causal ordering.
- **Deterministic Conflict Handling:** Host checks `base_revision` against current entity revision.
  - *Match:* Mutation applied, Host increments entity revision, returns typed success.
  - *Mismatch:* Host rejects with typed `CONFLICT_DETECTED`, returning current server entity state.
  - *No Client LWW:* Client Last-Write-Wins is strictly prohibited. Stale edits result in `CONFLICT_DETECTED` unless an explicitly safe/idempotent domain rule applies (such as desired-state task completion `SET_COMPLETION(completed=bool)`).
- **Incremental Replication:** Mobile tracks incremental updates via a monotonic Host change cursor.
- **Stale Cursor Recovery:** If Host reports `STALE_CURSOR` (cursor older than tombstone retention horizon), Mobile performs a baseline state reset for that domain.
- **Tombstones:** Propagated deletions preserve tombstone records with `deleted_at` timestamps for a bounded retention window; exact retention horizon remains implementation-open under `DEBT-MOB-02`.
- **Disconnected Conversation Replay:** Offline turns (local or cloud) are imported as immutable conversation blocks into the Host database as branched conversation segments, preserving exact user prompts and assistant outputs without PC LLM regeneration or tool replay.

---

## 4. Key Concepts

- **Satellite Device ([`ADR-0018`](../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)):** A mobile client is an auxiliary satellite bound to exactly one profile on a specific PC Host. It does not perform multi-profile administration or global user management.
- **Host vs Local Authority:** PC `SchedulerService` remains canonical scheduling truth. The PC Host owns Profiles, reconciled conversation history, Memory, canonical Task/Reminder/Alarm/Routine entities, and runtime/tool authority. The Mobile device owns local device settings, device-local third-party provider credentials, local replica/outbox state, and local occurrence delivery state / Android scheduling adapters.
- **Durable Disconnected Working State:** SQLite outbox journal and local data stores survive process termination and device reboot, preventing data loss during offline usage.
- **Capability-Dependent Local Inference:** On-device LLM execution is an optional hardware-dependent enhancement, not a baseline requirement for application functionality.
- **Independent Audio/Voice Subsystems:** Local TTS, local STT, and local LLM inference are decoupled capabilities. A mobile device may execute local TTS without possessing local STT or an LLM.
- **Decision D5 Protected Transport:** All network communication outside local loopback requires application authentication and TLS encryption on LAN, or a secure Tailscale overlay network. Direct WAN router port forwarding is blocked.
- **Decision D9 Tool Boundary:** Mobile clients can only execute approved on-device capabilities (camera, flashlight, local notifications). Host tools are executed exclusively by the PC runtime. Cloud LLMs receive zero tool authority.
- **Mobile Golden Requirements (MG1–MG12):** The 12 end-to-end integration standards governing Mobile Companion delivery ([`mobile-capabilities-and-runtime.md` §8](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md)):
  - `MG1 — Enrollment & Identity`: Device pairing flow, revocable device token issuance, single-Profile binding enforcement, rejection of arbitrary profile assertions in request payloads.
  - `MG2 — Platform Secure Storage & Transport`: Android Keystore protection for device token and provider API keys, zero plaintext storage, protected transport via TLS/HTTPS or approved encrypted overlay (Tailscale), rejection of direct port forwarding.
  - `MG3 — Connected Host Operation`: Bidirectional communication with PC Local AI Runtime, REST turn submission, SSE token streaming, turn queue completion across transient client disconnects.
  - `MG4 — Offline Durability & Outbox`: Fully functional offline Task creation, modification, and completion (`SET_COMPLETION`); durable outbox persistence surviving process death and OS reboot.
  - `MG5 — Synchronization & Conflict Reconciliation`: Delta cursor synchronization, typed `CONFLICT_DETECTED` handling with user conflict presentation, typed `STALE_CURSOR` full re-baseline, retry idempotency deduplication (`mutation_id`).
  - `MG6 — Punctual Offline Alarms & Reminders`: Alarm scheduling via `AlarmManager.setAlarmClock()`, precise ringing while device is in deep Doze conditional on exact-alarm capability/access, floating timezone recalculation, single-device duplicate firing suppression, and graceful degraded indication when exact alarm access is unavailable.
  - `MG7 — System Lifecycle & Permission Resilience`: Alarm re-registration following `ACTION_BOOT_COMPLETED`, recovery when `SCHEDULE_EXACT_ALARM` or `POST_NOTIFICATIONS` is revoked, graceful degradation warnings.
  - `MG8 — Voice Streaming & Audio Lifecycle`: Native mic capture, full-duplex WebSocket audio streaming to PC Host, immediate local barge-in playback muting, immediate muting on competing audio focus loss (`AUDIOFOCUS_LOSS`), pausing on unsafe route changes (`ACTION_AUDIO_BECOMING_NOISY`), device-local TTS vocalization when offline on qualifying devices, and graceful truthful degradation to text mode when unsupported.
  - `MG9 — Mobile Inference & Hardware Tiers`: Capability detection across Tiers 0–3 based on runtime preflight evidence, clean UI degradation when unsupported, resident model memory budget enforcement, D6 mobile lifecycle integrity.
  - `MG10 — Thermal, Battery & Power Governance`: WorkManager compliance with Doze maintenance windows, thermal throttling backoff under severe thermal state, graceful model unloading under modern `onTrimMemory` and memory pressure signals without process crash.
  - `MG11 — Security, Revocation & Privacy`: Authoritative discovery of `DEVICE_REVOKED` triggering local revocation cleanup, preservation of third-party user keys, backup exclusion verification, quarantine on `PROFILE_INACTIVE`, permanent wipe on `PROFILE_PURGED`.
  - `MG12 — Cross-Device Consistency`: Independent device alarm ringing without premature cancellation by passive PC notifications; cross-device alarm dismissal synchronization upon explicit user dismissal.
- **Verification Layers (L1–L5):** Progressive testing pyramid ([`mobile-capabilities-and-runtime.md` §7.1](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md)):
  - `L1 — Unit & Domain Tests`: Host JVM / Dart VM (Headless).
  - `L2 — Storage & Outbox Tests`: Headless / Robolectric / SQLite.
  - `L3 — Platform Lifecycle Tests`: Android Emulator Matrix.
  - `L4 — Hardware & Audio Tests`: Physical Android Hardware.
  - `L5 — Host Integration Tests`: Multi-Process / Local Network.
  *Note: Golden MG1–MG12 release qualification aggregates evidence across L1–L5.*

---

## 5. Verification Steps

### Automated & Mechanical Checks Completed

The following mechanical verification checks have been executed and confirmed clean:

```bash
# 1. OpenAPI Contract Verification
backend\.venv\Scripts\python.exe scripts/check_openapi_contract.py
# Result: OpenAPI contract is up-to-date (23 routes, all required model routes present).

# 2. CI Policy & Repository Deterministic Test Suite
backend\.venv\Scripts\python.exe -m unittest discover scripts/tests
# Result: Ran 15 tests in 0.068s -> OK

# 3. WBS Catalog Item Count & Integrity
# Verified via inline Python analysis on docs/02_Planning/00_Master/MOBILE_WBS.md:
# Result: Exactly 65 unique work items across 11 streams (MOB-FOUNDATION through MOB-VERIFY).
# Duplicates: 0. Missing MOB dependencies: 0. Cycles: 0.
# Valid PC dependencies bridged: 11 (PC-API-001, PC-API-002, PC-API-004, PC-CLIENT-001,
# PC-IDENTITY-002, PC-IDENTITY-003, PC-IDENTITY-005, PC-MODEL-001, PC-SCHED-001, PC-SCHED-002, PC-VOICE-005).

# 4. Forbidden Stale Terminology & Link Integrity Scan
# Result: Zero vector clocks (confirmed negative constraint only), zero positive LWW semantics,
# zero deprecated storage targets, package namespace locked to com.cnl.aicompanion.
# Link verification: Exactly 0 broken relative markdown links in walkthrough.
```

### Point-in-Time Verification Truth
- **PR Candidate CI:** `NOT RUN` (No GitHub Actions runs are currently present for this branch; CI evaluates upon PR branch creation/push under human Git authority).
- **Physical Device & Audio Tests (L4) / Host Integration Tests (L5):** `NOT STARTED` (Pertains to future implementation code; Golden MG1–MG12 aggregates evidence across L1–L5).
- **Production Code Implementation Verification:** `NOT APPLICABLE` (No production code was introduced or modified).

---

## 6. Safe Customization & Invariants

Future implementation of the Mobile Companion must strictly respect the following architectural invariants:

1. **Package Identity:** Production Android package name is locked as `com.cnl.aicompanion` ([`ADR-0004`](../04_Architecture/decisions/ADR-0004-d3-android-application-identity.md)).
2. **Workspace Topology:** Monorepo Flutter application target sharing core contract and theme packages ([`MOBILE_SYSTEM_BASELINE.md` §3](../04_Architecture/MOBILE_SYSTEM_BASELINE.md)).
3. **Satellite Binding:** Exactly one active profile binding per device ([`ADR-0018`](../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)). Multi-profile switching on mobile is prohibited.
4. **Account Administration:** Account creation, profile management, and device pairing authorization are strictly PC-only operations.
5. **Secret Storage:** All private device keys and third-party cloud API credentials reside exclusively in the Android Keystore ([`MOBILE_SYSTEM_BASELINE.md` §4.1](../04_Architecture/MOBILE_SYSTEM_BASELINE.md), [`mobile-capabilities-and-runtime.md` §5](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md)). Third-party credentials must never be synchronized to or read by the PC Host.
6. **Network Transport:** Transport must satisfy Decision D5 (authenticated TLS on LAN or Tailscale encrypted overlay). Direct WAN router port forwarding is forbidden.
7. **Local Persistence:** Local store must be relational SQLite with ACID transactions and a durable outbox journal surviving process death and reboot.
8. **Conflict Handling:** Host-issued revisions with deterministic conflict resolution. Client Last-Write-Wins (LWW) is strictly forbidden.
9. **Inference Independence:** Local TTS, local STT, and local LLM inference are completely decoupled capabilities. Local LLM residency is capped at 1 model (`--models-max 1`).
10. **Cloud Policy:** Cloud providers require explicit opt-in permissions. Transparent/silent cloud fallback is forbidden. Disconnected cloud turns sync via whole-turn outbox units.
11. **Voice Barge-In:** Real-time microphone audio capture must support user interruption/barge-in with client-side audio frame suppression.
12. **Lifecycle Policies:** Alarms must utilize `AlarmManager.setAlarmClock()` conditional on exact-alarm capability/access (`canScheduleExactAlarms()`). Reminders use tolerant scheduling. Health Connect and local Routines are deferred to Mobile Later (Post-V1). Always-on wake word is excluded from Mobile V1.

---

## 7. Troubleshooting / Future Agent Guidance

### Common Traps to Avoid
1. **Treating Kotlin Prototype as Production:** The code under `android/` is an exploratory prototype. Do not build upon it or attempt to fix its architectural violations; production Mobile will be built in Flutter.
2. **Treating Architectural Targets as Implemented:** Documents under `docs/04_Architecture/` specify the normative target. Do not assert that contracts or endpoints exist in `backend/` or `frontend/` unless confirmed in active source code.
3. **Conflating OFFLINE_LOCAL with OPTIONAL_CLOUD:** `OFFLINE_LOCAL` applies to device-local computation and persistence without internet. `OPTIONAL_CLOUD` applies to third-party cloud APIs over internet without PC connectivity. They have separate security, storage, and reconciliation paths.
4. **Assuming Local LLM is Mandatory:** Mobile V1 must function fully on Tier 0/1 devices lacking local LLM hardware capabilities.
5. **Hardcoding Candidates as Mandates:** Drift, Kokoro, Whisper, and specific audio codecs are preferred candidates and reference benchmarks, not permanent locked architectural requirements (`DEBT-MOB-08`).
6. **Renumbering WBS or Golden IDs:** Do not alter the 65 item IDs in `MOBILE_WBS.md` or the MG1–MG12 numbering in `MOBILE_CHECKLIST.md`.
7. **Confusing L1–L5 with Golden Acceptance Groups:** Golden groups MG1–MG12 are release qualification requirements that aggregate test evidence across execution layers L1–L5. L4 is physical hardware, while L5 is multi-process Host integration.

---

## 8. Fresh-Agent Semantic Validation (Closure Evidence)

To ensure that future developers and agents can navigate the Mobile architecture without ambiguity, the 12 semantic questions from the canonical plan are answered below using verified repository truth:

1. **What works when Mobile is offline?**
   Tasks (create, update, status `SET_COMPLETION`, delete with durable outbox logging); replicated Reminder/Alarm occurrences (exact alarms via `AlarmManager.setAlarmClock()` conditional on exact-alarm capability/access, tolerant Reminders); local notification/alarm presentation, snooze, and dismiss; cached history/context viewing; device-local settings; and on qualified Tier 2/3 devices with installed model: local conversational text turns; device-local TTS playback where approved engine installed. What does NOT work offline: Host LLM inference, Host tools, Host memory writes, WebSocket voice streaming to PC, PC-side model management, profile switching.
2. **What data is authoritative on PC vs Mobile?**
   PC Host is authoritative for: Account/Profile configuration, master conversation history after reconciliation, Memory (FTS5 search index), Task/Reminder/Alarm/Routine canonical entities, PC `SchedulerService` canonical scheduling truth, global entity revisions, and model/tool/runtime authority where assigned by canonical specs. Mobile is authoritative for: device-local settings, device-local third-party provider credentials, local replica/outbox state, and local occurrence delivery state / Android scheduling adapters.
3. **How are offline writes reconciled?**
   Offline mutations are written to a durable SQLite transactional outbox with UUID `mutation_id` and the entity's `base_revision`. Causal ordering is preserved; pending CREATE dependencies use safe coalescing or explicit ordering. When connection to Host resumes, outbox entries are dispatched. Host checks `base_revision`: if matching current revision, mutation is applied and revision incremented. If mismatch, Host returns typed `CONFLICT_DETECTED` with current entity state. Generic stale edits result in `CONFLICT_DETECTED` unless an explicitly safe/idempotent domain rule applies (such as desired-state task completion `SET_COMPLETION(completed=bool)`). No client Last-Write-Wins. Disconnected conversation turns (local or cloud) import as immutable whole-turn blocks with provenance tags without Host re-generation or tool replay.
4. **Can Mobile switch Profiles itself?**
   No. A satellite device binds strictly to one Profile ([`ADR-0018`](../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)). Profile administration is exclusively performed on the PC Host.
5. **How is revocation handled while disconnected?**
   While fully offline, Mobile cannot know that PC Admin revoked it and may continue operating against cached/local state. On next network contact, authoritative `DEVICE_REVOKED` causes: device credential invalidation/removal, replicated Profile DB/cache erasure, pending Profile outbox cancellation/clearing, and re-enrollment requirement. Third-party user/provider API keys remain preserved. In contrast, `CREDENTIAL_EXPIRED` / `ROTATION_REQUIRED` are non-destructive: pause sync, require re-authentication/token rotation, and preserve Profile data. `PROFILE_INACTIVE` causes quarantine/disabled access, not destructive wipe. `PROFILE_PURGED` causes permanent Profile replica removal.
6. **Is local inference required for the app?**
   No. Local Mobile inference is strictly capability-dependent and optional-auxiliary. The app functions completely without local models.
7. **Is Health Connect in Mobile V1?**
   No. Real Health Connect integration and biometric sync are classified as Mobile Later (Post-V1) in [`health-and-wearables.md`](../04_Architecture/03_Integrations/health-and-wearables.md). The mock health UI in the Kotlin prototype is sequestered and non-normative.
8. **What happens to Alarms after reboot/process death?**
   Android OS alarms survive application process death when already registered. Device reboot clears OS alarm registrations. Upon system boot, `ACTION_BOOT_COMPLETED` handling ([`MOB-SCHED-005`](../02_Planning/00_Master/MOBILE_WBS.md)) reloads active occurrence data from durable local SQLite storage, checks `canScheduleExactAlarms()`, and re-registers alarms as permitted.
9. **Which Reminder/Alarm behavior works disconnected?**
   Alarms: local ringing, dismiss, and snooze operate disconnected. Punctual exact delivery is conditional on exact-alarm capability/access (`canScheduleExactAlarms()`); if unavailable, state must truthfully become degraded/unarmed. Reminders: use best-effort/inexact/tolerant scheduling and may be delayed or batched by Android/Doze. Full-screen intent presentation is conditional, restricted on modern Android, and cannot be guaranteed.
10. **Which credentials remain permanently device-local?**
    Third-party provider API credentials (e.g. cloud LLM, STT, or TTS keys) are permanently device-local, stored in Android Keystore, and never automatically synced to PC or other devices. Device credentials / tokens are protected locally in Keystore and used to authenticate to the Host; the Host maintains corresponding Device enrollment and validation data.
11. **What Flutter boundaries are shared vs platform-specific?**
    Shared boundary: stable domain contracts, generated/shared API contracts, reusable design primitives, authentication abstractions, and suitable platform-neutral repository/service interfaces. Platform-specific implementations: Android Keystore, WorkManager, AlarmManager, Android audio/focus HAL, lifecycle/background adapters, and Windows tray/host integrations. The architecture explicitly does NOT mandate identical business/state implementation where platform constraints differ.
12. **What is implemented today vs approved target?**
    CURRENT / IMPLEMENTED TODAY includes: existing FastAPI backend, React Web supported client/dev harness, exploratory Kotlin/Compose Android prototype (`android/`), legacy `owner_id`, shared `COMPANION_API_KEY`, and existing `client_message_id` uniqueness. TARGET / NOT IMPLEMENTED includes: production Flutter Mobile application, Profile/Device schema and per-device credentials, client-generated Task identity acceptance, mutation-id dedup, Host entity revisions, cursor/delta sync, disconnected whole-turn import, Mobile local inference production runtime, and Mobile Golden implementation evidence (MG1–MG12 / L1–L5).
