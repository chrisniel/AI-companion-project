# Walkthrough: Mobile V1 Canonical Architecture & Delivery Planning

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Comprehensive technical walkthrough and developer handover for the MOBILE-ARCH canonical architecture pass, establishing Mobile cross-cutting ecosystem boundaries, offline persistence and synchronization, native Android reliability, local/cloud inference capabilities, and 65-item execution planning.
- **Audience:** Developers, maintainers, architecture reviewers, and future implementation agents.
- **Status:** Closure Review Pending
- **Last Updated:** 2026-10-04

---

## 1. What Was Delivered

The MOBILE-ARCH delivery establishes the complete canonical architecture, synchronization protocols, hardware qualification tiers, native platform policies, and master engineering plans for the Mobile Companion (V1 target).

### Scope Summary
- **Mobile Canonical System Baseline ([`MOBILE_SYSTEM_BASELINE.md`](../04_Architecture/MOBILE_SYSTEM_BASELINE.md)):** Established the Satellite Device ecosystem boundary, single-Profile binding, three operating execution modes, and the 12-item Approved Mobile Decision Ledger (§7, Decisions D1–D12).
- **Batch A Foundation:** Created [`ADR-0004`](../04_Architecture/decisions/ADR-0004-d3-android-application-identity.md) (package `com.cnl.aicompanion` and Flutter shared workspace), [`ADR-0005`](../04_Architecture/decisions/ADR-0005-d4-credential-storage.md) (device-local Keystore secrets), and [`ADR-0018`](../04_Architecture/decisions/ADR-0018-d7-device-profile-binding.md) (one Profile per Satellite); updated navigation across all 20 canonical specifications.
- **Batch B Offline & Native Reliability ([`mobile-offline-and-sync.md`](../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md)):** Defined local relational SQLite persistence, durable transactional outbox journal, per-domain sync protocols, deterministic conflict handling (no client last-write-wins), monotonic change cursors, tombstone retention, and revocation cleanup.
- **Batch C Capabilities & Verification ([`mobile-capabilities-and-runtime.md`](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) & [`health-and-wearables.md`](../04_Architecture/04_Infrastructure/health-and-wearables.md)):** Defined evidence-driven hardware qualification tiers (Tiers 0–3), single-model memory cap (`--models-max 1`), decoupled local/cloud inference, independent local TTS/STT capabilities, WebSocket audio streaming to PC, Android foreground service/lifecycle policies, exact `AlarmManager.setAlarmClock()` delivery, and sequestered Health Connect to Mobile Later (Post-V1).
- **Cross-Batch Architecture Reconciliation:** Harmonized decisions across all three batches, eliminating stale terminology, establishing clean capability-mode separation, and normalizing contract naming.
- **Phase 4 Planning Integration ([`MOBILE_WBS.md`](../02_Planning/00_Master/MOBILE_WBS.md) & [`MOBILE_CHECKLIST.md`](../02_Planning/00_Master/MOBILE_CHECKLIST.md)):** Built a complete 65-item Work Breakdown Structure across 11 streams, linked with the master planning spine, alongside a 26-row readiness checklist mapped to Mobile Golden requirements MG1–MG12 and verification layers L1–L5.

> [!IMPORTANT]
> **NO PRODUCTION MOBILE IMPLEMENTATION IS DELIVERED BY MOBILE-ARCH.**  
> This delivery consists strictly of canonical architecture, ADRs, documentation, and engineering master planning.
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
| [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../04_Architecture/MOBILE_SYSTEM_BASELINE.md) | **Primary Mobile System Baseline:** Defines Satellite Device boundary, one-Profile binding, execution modes, PC vs Mobile authority division, and the 12-item Approved Mobile Decision Ledger (§7). |
| [`docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`](../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) | **Offline Persistence & Synchronization:** Owns local relational SQLite store, durable transactional outbox, entity sync protocols, Host revision checks, conflict resolution, change cursors, tombstones, and quarantine/revocation erasure. |
| [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) | **Runtime Capabilities & Native Reliability:** Owns hardware tiers 0–3, model residency, decoupled local/cloud inference, independent TTS/STT, WebSocket audio streaming, Android foreground services, lifecycle management, and Keystore secret storage. |
| [`docs/04_Architecture/04_Infrastructure/health-and-wearables.md`](../04_Architecture/04_Infrastructure/health-and-wearables.md) | **Wearables & Biometrics Boundary:** Defines health data handling policies, security/privacy boundaries, and explicitly defers Health Connect to Mobile Later (Post-V1). |
| [`docs/04_Architecture/01_Domains/android-companion.md`](../04_Architecture/01_Domains/android-companion.md) | **Prototype Boundary Specification:** Documents the role, limits, and preserved reference evidence of the exploratory Kotlin/Compose codebase (`android/`). |
| [`docs/04_Architecture/decisions/ADR-0004`](../04_Architecture/decisions/ADR-0004-d3-android-application-identity.md) | **ADR D3:** Locks application ID as `com.cnl.aicompanion` and selects shared Flutter workspace topology. |
| [`docs/04_Architecture/decisions/ADR-0005`](../04_Architecture/decisions/ADR-0005-d4-credential-storage.md) | **ADR D4:** Enforces device-local secret storage via Android Keystore; strictly forbids synchronizing provider keys to Host. |
| [`docs/04_Architecture/decisions/ADR-0018`](../04_Architecture/decisions/ADR-0018-d7-device-profile-binding.md) | **ADR D7:** Enforces single-Profile satellite binding; forbids multi-profile switching on device. |
| [`docs/02_Planning/00_Master/MOBILE_WBS.md`](../02_Planning/00_Master/MOBILE_WBS.md) | **Mobile Engineering WBS:** Canonical catalog of 65 work items across 11 streams (`MOB-FOUNDATION` through `MOB-VERIFY`) with dependencies and implementation states. |
| [`docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`](../02_Planning/00_Master/MOBILE_CHECKLIST.md) | **Mobile Readiness Checklist:** Matrix tracking 26 architectural capabilities, prototype gaps, verification criteria, and Golden group mappings (MG1–MG12). |
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
│ • Host FTS5 Memory  │ • AlarmManager Alarms     │ • Device Keystore key│
│ • Full Tool Exec    │ • Qualified Local LLM*    │ • No Host tool access│
│ • Low-Latency Audio │ • Independent Local TTS** │ • Disconnected turn  │
│   over WebSocket    │ • Cached Context Replica  │   import via outbox  │
│ • REST / SSE sync   │ • Zero Host tool access   │ • No silent fallback │
└─────────────────────┴───────────────────────────┴──────────────────────┘
* Tier 2/3 devices with installed model only; otherwise cached/read-only conversation.
** Independent of local LLM; requires installed on-device TTS engine.
```

#### 1. CONNECTED_TO_PC (Primary Mode)
- **Authority:** Host PC Runtime is the primary intelligence source.
- **Communication:** Encrypted transport (TLS on LAN or Tailscale overlay, Decision D5); no public router port forwarding.
- **Capabilities:** REST APIs for CRUD operations; SSE for token streaming; low-latency bidirectional WebSocket for Voice (audio streaming, barge-in detection, speech-to-text, text-to-speech processed on PC).
- **Mobile Responsibilities:** UI rendering, audio I/O capture/playback, sensor reading, and push notification display.

#### 2. OFFLINE_LOCAL (Reliable Edge Mode)
- **Tasks & Notes:** Fully operable offline. Creates, updates, and deletes are executed immediately against local SQLite and logged to the durable transactional outbox journal.
- **Alarms & Reminders:** Exact alarm firing governed by Android `AlarmManager.setAlarmClock()`. Alarms trigger offline foreground alert UI with local ringing, snooze, and dismiss controls. Actions are journaled for sync upon reconnection.
- **Conversational Intelligence:** Capability-gated.
  - *Qualified Tier 2/3 hardware with approved model installed:* Supports offline local conversational text generation.
  - *Unqualified or model-less devices:* Maintains cached, read-only conversation history; dialogue prompts inform user that PC connection is required.
- **Voice Independence:** A device with an approved on-device TTS provider can speak offline text responses without requiring a local LLM or local STT.
- **Boundaries:** Zero autonomous writes to canonical Host Memory; no Host tool execution.

#### 3. OPTIONAL_CLOUD (Auxiliary Independent Mode)
- **Explicit Permissions:** Strictly opt-in per provider (e.g., Anthropic, OpenAI, ElevenLabs).
- **Secret Isolation:** Provider API keys are stored exclusively in the mobile Android Keystore (`ADR-0005`) and are never transmitted to or managed by the PC Host.
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
         │ 1. POST /api/v1/sync/push (mutations)                │
         │    [mutation_id, entity_id, base_revision, payload]  │
         ├─────────────────────────────────────────────────────►│
         │                                                      │ 2. Validate base_rev:
         │                                                      │    If match -> Apply,
         │                                                      │    rev++, return OK.
         │ 3. Response: 200 OK / 409 CONFLICT_DETECTED          │    If mismatch -> 409
         │◄─────────────────────────────────────────────────────┤
         │                                                      │
         │ 4. GET /api/v1/sync/pull?cursor=xyz                  │
         ├─────────────────────────────────────────────────────►│
         │                                                      │ 5. Query changes > xyz:
         │ 6. Response: [entities, next_cursor]                 │    Return updates +
         │◄─────────────────────────────────────────────────────┤    tombstones.
```

- **Entity Identity:** UUIDv4 generated at entity creation time, preserved identically across Mobile and PC.
- **Durable Outbox Journal:** Every local mutation is atomically committed to SQLite outbox with a unique `mutation_id`, target entity ID, mutation type, payload, and the `base_revision` observed locally.
- **Optimistic UI:** Local UI reflects mutation immediately; outbox processor dispatches updates in FIFO sequence upon reconnection.
- **Deterministic Conflict Handling:** Host checks `base_revision` against current entity revision.
  - *Match:* Mutation applied, Host increments entity revision, returns success.
  - *Mismatch:* Host rejects with `CONFLICT_DETECTED` (HTTP 409), returning the current server entity state.
  - *No Client LWW:* Client Last-Write-Wins is strictly prohibited. Client prompts user or resolves according to deterministic domain rules (e.g., task completion status union).
- **Incremental Replication:** Mobile tracks incremental updates via a monotonic Host change cursor.
- **Stale Cursor Recovery:** If Host reports `STALE_CURSOR` (cursor older than tombstone retention window), Mobile performs a baseline state reset for that domain.
- **Tombstones:** Propagated deletions preserve tombstone records with `deleted_at` timestamps for a minimum retention window before permanent purge.
- **Disconnected Conversation Replay:** Offline turns (local or cloud) are imported as immutable conversation blocks into the Host database as branched conversation segments, preserving exact user prompts and assistant outputs without PC LLM regeneration or tool replay.

---

## 4. Key Concepts

- **Satellite Device (`ADR-0018`):** A mobile client is an auxiliary satellite bound to exactly one profile on a specific PC Host. It does not perform multi-profile administration or global user management.
- **Host vs Local Authority:** The PC Host runtime owns master conversation state, memory consolidation, and tool execution. The Mobile device owns local private keys, hardware sensors, alarm schedules, and local mutation queues.
- **Durable Disconnected Working State:** SQLite outbox journal and local data stores survive process termination and device reboot, preventing data loss during offline usage.
- **Capability-Dependent Local Inference:** On-device LLM execution is an optional hardware-dependent enhancement, not a baseline requirement for application functionality.
- **Independent Audio/Voice Subsystems:** Local TTS, local STT, and local LLM inference are decoupled capabilities. A mobile device may execute local TTS without possessing local STT or an LLM.
- **Decision D5 Protected Transport:** All network communication outside local loopback requires application authentication and TLS encryption on LAN, or a secure Tailscale overlay network. Direct WAN router port forwarding is blocked.
- **Decision D9 Tool Boundary:** Mobile clients can only execute approved on-device capabilities (camera, flashlight, local notifications). Host tools are executed exclusively by the PC runtime. Cloud LLMs receive zero tool authority.
- **Mobile Golden Requirements (MG1–MG12):** The 12 end-to-end integration standards governing Mobile Companion delivery:
  - `MG1`: Multi-profile isolation & single-profile binding.
  - `MG2`: Identity, pairing, and D5 transport security.
  - `MG3`: Local storage encryption & platform Keystore isolation.
  - `MG4`: Disconnected operation & transactional outbox durability.
  - `MG5`: Bidirectional synchronization & deterministic conflict resolution.
  - `MG6`: Task, Reminder, and Note CRUD parity.
  - `MG7`: AlarmManager exact delivery & reboot persistence.
  - `MG8`: Connected low-latency Voice streaming & barge-in.
  - `MG9`: Hardware qualification, residency caps, and decoupled inference.
  - `MG10`: Offline TTS fallback & cloud voice boundaries.
  - `MG11`: Profile quarantine, revocation data erasure, and secret disposal.
  - `MG12`: Android power, lifecycle, and memory pressure compliance.
- **Verification Layers (L1–L5):** Progressive testing pyramid:
  - `L1`: Unit & Domain Logic Tests (Dart/Flutter).
  - `L2`: Contract & Wire Serialization Tests (OpenAPI schema conformance).
  - `L3`: Local Integration Tests (SQLite outbox, Keystore mocks, lifecycle).
  - `L4`: Host Integration Tests (LAN/Tailscale sync against live FastAPI backend).
  - `L5`: Physical Device & Hardware Golden Tests (Real Android devices across tiers).

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
# Result: Ran 15 tests in 0.069s -> OK

# 3. WBS Catalog Item Count & Integrity
# Checked via check_wbs.py on docs/02_Planning/00_Master/MOBILE_WBS.md
# Result: Exactly 65 unique work items across 11 streams (MOB-FOUNDATION through MOB-VERIFY).
# Duplicates: 0. Missing MOB dependencies: 0. Cycles: 0.
# Valid PC dependencies bridged: 11 (PC-API-001, PC-API-002, PC-API-004, PC-CLIENT-001,
# PC-IDENTITY-002, PC-IDENTITY-003, PC-IDENTITY-005, PC-MODEL-001, PC-SCHED-001, PC-SCHED-002, PC-VOICE-005).

# 4. Forbidden Stale Terminology Scan
# Result: Zero vector clocks (confirmed negative constraint only), zero positive LWW semantics,
# zero deprecated EncryptedSharedPreferences targets, zero non-approved package IDs.
```

### Point-in-Time Verification Truth
- **PR Candidate CI:** `NOT RUN YET` (CI will trigger upon PR branch creation/push under human Git authority).
- **Physical Device Golden Verification (L5 / MG1–MG12):** `NOT STARTED` (Pertains to future implementation code; does not block this documentation delivery).
- **Production Code Implementation Verification:** `NOT APPLICABLE` (No production code was introduced or modified).

---

## 6. Safe Customization & Invariants

Future implementation of the Mobile Companion must strictly respect the following architectural invariants:

1. **Package Identity:** Production Android package name is locked as `com.cnl.aicompanion` (`ADR-0004`).
2. **Workspace Topology:** Monorepo Flutter application target sharing core contract and theme packages (`ADR-0004`).
3. **Satellite Binding:** Exactly one active profile binding per device (`ADR-0018`). Multi-profile switching on mobile is prohibited.
4. **Account Administration:** Account creation, profile management, and device pairing authorization are strictly PC-only operations.
5. **Secret Storage:** All private device keys and third-party cloud API credentials reside exclusively in the Android Keystore (`ADR-0005`). They must never be synchronized to or read by the PC Host.
6. **Network Transport:** Transport must satisfy Decision D5 (authenticated TLS on LAN or Tailscale encrypted overlay). Direct WAN router port forwarding is forbidden.
7. **Local Persistence:** Local store must be relational SQLite with ACID transactions and a durable outbox journal surviving process death and reboot.
8. **Conflict Handling:** Host-issued revisions with deterministic conflict resolution. Client Last-Write-Wins (LWW) is strictly forbidden.
9. **Inference Independence:** Local TTS, local STT, and local LLM inference are completely decoupled capabilities. Local LLM residency is capped at 1 model (`--models-max 1`).
10. **Cloud Policy:** Cloud providers require explicit opt-in permissions. Transparent/silent cloud fallback is forbidden. Disconnected cloud turns sync via whole-turn outbox units.
11. **Voice Barge-In:** Real-time microphone audio capture must support user interruption/barge-in with client-side audio frame suppression.
12. **Lifecycle Policies:** Alarms must utilize `AlarmManager.setAlarmClock()`. Health Connect and local Routines are deferred to Mobile Later (Post-V1). Always-on wake word is excluded from Mobile V1.

---

## 7. Troubleshooting / Future Agent Guidance

### Common Traps to Avoid
1. **Treating Kotlin Prototype as Production:** The code under `android/` is an exploratory prototype. Do not build upon it or attempt to fix its architectural violations; production Mobile will be built in Flutter.
2. **Treating Architectural Targets as Implemented:** Documents under `docs/04_Architecture/` specify the normative target. Do not assert that contracts or endpoints exist in `backend/` or `frontend/` unless confirmed in active source code.
3. **Conflating OFFLINE_LOCAL with OPTIONAL_CLOUD:** `OFFLINE_LOCAL` applies to device-local computation and persistence without internet. `OPTIONAL_CLOUD` applies to third-party cloud APIs over internet without PC connectivity. They have separate security, storage, and reconciliation paths.
4. **Assuming Local LLM is Mandatory:** Mobile V1 must function fully on Tier 0/1 devices lacking local LLM hardware capabilities.
5. **Hardcoding Candidates as Mandates:** Drift, Kokoro, Whisper, and specific audio codecs are preferred candidates and reference benchmarks, not permanent locked architectural requirements (`DEBT-MOB-08`).
6. **Renumbering WBS or Golden IDs:** Do not alter the 65 item IDs in `MOBILE_WBS.md` or the MG1–MG12 numbering in `MOBILE_CHECKLIST.md`.

---

## 8. Fresh-Agent Semantic Validation (Closure Evidence)

To ensure that future developers and agents can navigate the Mobile architecture without ambiguity, the 12 semantic questions from the canonical plan are answered below using verified repository truth:

1. **What works when Mobile is offline?**  
   Local Task/Note CRUD, AlarmManager exact alarms, local reminder notifications, cached conversation history viewing, and—on qualified Tier 2/3 devices—offline local LLM text generation and device-local TTS speech playback.
2. **What data is authoritative on PC vs Mobile?**  
   PC Host is authoritative for Account/Profile configuration, master conversation history, canonical Memory/FTS5 search index, and global entity revisions. Mobile Satellite is authoritative for device Keystore secrets, local hardware state, pending outbox mutations, and on-device alarm schedules.
3. **How are offline writes reconciled?**  
   Mutations committed to the SQLite outbox with a UUID `mutation_id` and `base_revision` are pushed to the Host upon reconnection. The Host checks `base_revision`; matches succeed with revision increment, while mismatches return `409 CONFLICT_DETECTED` for deterministic handling (no client LWW). Disconnected conversation turns import as immutable whole-turn blocks.
4. **Can Mobile switch Profiles itself?**  
   No. A satellite device binds strictly to one Profile (`ADR-0018`). Profile administration is exclusively performed on the PC Host.
5. **How is revocation handled while disconnected?**  
   Mobile tokens require non-destructive periodic rotation handshakes. If disconnected past expiry, the app transitions to quarantine. Upon reconnect, the Host issues `DEVICE_REVOKED`, triggering local Keystore credential disposal and cached data erasure.
6. **Is local inference required for the app?**  
   No. Local LLM execution is capability-dependent and optional-auxiliary. The app functions completely without local models.
7. **Is Health Connect in Mobile V1?**  
   No. Real Health Connect integration and biometric sync are classified as Mobile Later (Post-V1).
8. **What happens to Alarms after reboot/process death?**  
   Alarms persist in SQLite. Upon system reboot, a `BOOT_COMPLETED` receiver (`MOB-SCHED-002`) reschedules all pending alarms with `AlarmManager.setAlarmClock()`. Process death does not cancel active OS alarms.
9. **Which Reminder/Alarm behavior works disconnected?**  
   Exact firing, full-screen alarm ringing, local audio playback, Snooze, and Dismiss work completely disconnected.
10. **Which credentials remain permanently device-local?**  
    Satellite pairing keys, device authentication tokens, and third-party Cloud API keys reside exclusively in the Android Keystore (`ADR-0005`) and are never sent to the PC Host.
11. **What Flutter boundaries are shared vs platform-specific?**  
    Domain models, contracts, state logic, and theme tokens are shared. Keystore access, AlarmManager, WorkManager, low-latency audio HAL, and lifecycle receivers are injected via platform service adapters.
12. **What is implemented today vs approved target?**  
    Implemented today: PC FastAPI backend, Web admin harness, and exploratory Kotlin prototype (`android/`). Approved target: Production Flutter workspace, Flutter Android target (`com.cnl.aicompanion`), SQLite outbox sync, Mobile local inference runtime, and Golden test suites.
