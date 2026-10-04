# AI Companion — Mobile V1 Master Readiness Checklist

> **Document Role:** Canonical tracking checklist auditing readiness across Mobile architecture, implementation, automated testing, documentation, and Mobile Golden Acceptance evidence (MG1–MG12).  
> **Status:** Active Canonical Tracking Matrix  
> **Authority Precedence:** This document audits Mobile Companion readiness. PC V1 release readiness is audited separately in [`MASTER_CHECKLIST.md`](MASTER_CHECKLIST.md). Canonical Mobile architecture is owned by [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md), [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md), and [`mobile-capabilities-and-runtime.md`](../../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md). Work breakdown is cataloged in [`MOBILE_WBS.md`](MOBILE_WBS.md).  
> **Governance Invariant:** Never claim target architecture is implemented. State categories: `IMPLEMENTED / VERIFIED`, `IN PROGRESS`, `APPROVED TARGET (NOT STARTED)`, `LATER / DEFERRED`.

---

## 1. Readiness Audit Matrix

| Domain Area | Target Capability | Architecture Spec | Implemented Source / Tests | Automated Verification Gate | Golden Release Gate | Overall Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Governance** | Mobile Architecture Canonicalization | `MOBILE_SYSTEM_BASELINE.md` | Batches A, B, C approved; cross-batch reconciliation approved | Script tests / Contract check | Human review | **APPROVED** |
| **Governance** | Human-Only Git Write Authority | `AGENTS.md`, `DELIVERY_WORKFLOW.md` | Process rules | N/A | Human review | **VERIFIED** |
| **Foundation** | Flutter Monorepo Workspace Integration | `MOBILE_SYSTEM_BASELINE.md` §3 | Pending Flutter workspace setup | Flutter CI lane | MG1 | **APPROVED TARGET (NOT STARTED)** |
| **Foundation** | Production Package `com.cnl.aicompanion` | `MOBILE_SYSTEM_BASELINE.md` §3 | Kotlin prototype uses interim package (`android/`) | Build scripts | MG1 | **APPROVED TARGET (NOT STARTED)** *(Kotlin prototype is reference only)* |
| **Contracts** | Host Task Client UUID Acceptance | `mobile-offline-and-sync.md` §3.2.1 | Host `TaskCreate` does not accept client ID | Contract test | MG4, MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Transactional `mutation_id` Dedup | `mobile-offline-and-sync.md` §3.2.4 | Pending Host idempotency engine | API unit test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Entity Revisions & Optimistic Concurrency | `mobile-offline-and-sync.md` §3.2.2 | Pending Host revision columns & checks | Concurrency test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Change Cursor & Delta Sync Endpoint | `mobile-offline-and-sync.md` §3.2.5 | Pending Host cursor sync service | Delta sync test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Lifecycle Outcomes (`DEVICE_REVOKED`, etc.) | `mobile-offline-and-sync.md` §7 | Pending Host typed outcome handlers | Lifecycle test | MG11 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Batch Turn Sync & Client `conversation_id` | `mobile-offline-and-sync.md` §3.2.6 | Message `client_message_id` unique exists; batch endpoint pending | Turn import test | MG4, MG5 | **PARTIAL (MESSAGE CONSTRAINT ONLY)** |
| **Contracts** | Assistant Provenance & Dialogue Branch Metadata | `mobile-offline-and-sync.md` §3.2.6 | Pending Host message schema extensions | Branch import test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | Single-Profile Pairing & Revocable Token | `MOBILE_SYSTEM_BASELINE.md` §4.1 | Prototype uses unencrypted SharedPreferences | Auth test | MG1 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | Android Keystore Protected Storage | `MOBILE_SYSTEM_BASELINE.md` §4.1 | Prototype uses unencrypted storage (anti-pattern) | Keystore test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | Credential Expiry & Non-Destructive Rotation | `mobile-capabilities-and-runtime.md` §5.3 | Pending rotation handshake | Rotation test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | Revocation Data Erasure & Quarantine | `mobile-offline-and-sync.md` §7 | Pending cleanup coordinator | Erasure test | MG11 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | D5 Transport Protection (Tailscale / TLS) | `MOBILE_SYSTEM_BASELINE.md` §4.2 | Prototype uses plain HTTP | Network test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Data** | Relational Local Store (SQLite-backed, Drift preferred) | `mobile-offline-and-sync.md` §2.2 | Prototype uses in-memory MutableStateFlow | SQLite persistence/schema test using selected Flutter adapter | MG4 | **APPROVED TARGET (NOT STARTED)** |
| **Data** | Durable Transactional Outbox Journal | `mobile-offline-and-sync.md` §2.2 | Prototype lacks outbox (violates durability) | Outbox durability test | MG4 | **APPROVED TARGET (NOT STARTED)** |
| **Data** | Durable Disconnected Conversation Working State | `mobile-offline-and-sync.md` §2.1 | Pending SQLite conversation store | Durability test | MG4, MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Sync** | Offline Task Create, Update, Delete & Coalesce | `mobile-offline-and-sync.md` §3.2.1 | Prototype has un-journaled optimistic tasks | Outbox sync test | MG4, MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Sync** | Idempotent Desired-State `SET_COMPLETION` | `mobile-offline-and-sync.md` §3.2.3 | Pending desired-state mutation handler | Idempotency test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Sync** | Optimistic Concurrency Conflict Resolution | `mobile-offline-and-sync.md` §3.2.3 | Pending conflict draft UI | Conflict test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Sync** | Monotonic Cursor Sync & Stale Re-baseline | `mobile-offline-and-sync.md` §3.2.5 | Pending re-baseline engine | Re-baseline test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Replicated Reminder/Alarm Occurrence Ingestion | `mobile-offline-and-sync.md` §6.1 | Pending occurrence replica store | Sched replica test | MG6 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Android `AlarmManager` Exact Alarm Scheduling | `mobile-offline-and-sync.md` §6.2 | Prototype lacks exact alarm integration | Alarm trigger test | MG6 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | `canScheduleExactAlarms()` & Degradation | `mobile-offline-and-sync.md` §6.2 | Pending permission lifecycle monitor | Permission test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Notification Channels & `POST_NOTIFICATIONS` | `mobile-offline-and-sync.md` §6.2 | Pending notification channel setup | Notification test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Reboot (`BOOT_COMPLETED`) & Timezone Handlers | `mobile-offline-and-sync.md` §6.4 | Pending broadcast receivers | Reboot receiver test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Cross-Device Dismissal & Duplicate Prevention | `mobile-offline-and-sync.md` §6.3.2 | Pending alert state machine | Cross-device test | MG12 | **APPROVED TARGET (NOT STARTED)** |
| **Dialogue** | Connected Conversation Streaming (SSE) | `mobile-offline-and-sync.md` §3.1 | Prototype has basic streaming chat | Streaming test | MG3 | **PARTIAL (PROTOTYPE REFERENCE)** |
| **Dialogue** | Qualified Offline Text Turn Coordination | `mobile-offline-and-sync.md` §3.2.6 | Pending offline dialogue coordinator | Offline turn test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Dialogue** | Tier 0/1 Truthful Input Guard (Host/Cloud Unavailable) | `mobile-offline-and-sync.md` §3.2.6 | Pending capability input guard | Degradation test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Dialogue** | Optional Cloud LLM Conversation Routing & Permissions | `MOBILE_SYSTEM_BASELINE.md` §5.1, `mobile-capabilities-and-runtime.md` §3.2, `mobile-offline-and-sync.md` §3.2.6 | Pending Cloud LLM router & Keystore adapter | Cloud router test | MG2, MG3, MG11 | **APPROVED TARGET (NOT STARTED)** |
| **Dialogue** | Multimodal Attachment Upload to Host | `mobile-offline-and-sync.md` §3.1 | Prototype lacks attachment queue | Attachment test | MG3 | **APPROVED TARGET (NOT STARTED)** |
| **Inference** | Runtime Hardware Qualification (Tiers 0–3) | `mobile-capabilities-and-runtime.md` §2.1 | Pending hardware benchmark classifier | Tier detection test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Inference** | LAN Host-to-Device Model Transfer | `mobile-capabilities-and-runtime.md` §2.3 | Pending authenticated LAN/Tailscale model transfer client | Transfer test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Inference** | Single Resident Model Cap (`--models-max 1`) | `mobile-capabilities-and-runtime.md` §2.3 | Pending model lifecycle manager | Lifecycle test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Inference** | Local Inference Runtime Adapter | `mobile-capabilities-and-runtime.md` §2.2 | Pending engine adapter (e.g. llama.cpp / ExecuTorch) | Inference test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Connected WebSocket Audio Streaming to PC | `mobile-capabilities-and-runtime.md` §3.1 | Pending WebSocket audio transport | WS audio test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Android Audio Hardware & Focus Adapter | `mobile-capabilities-and-runtime.md` §3.3 | Pending audio focus controller | Audio focus test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Mandatory Immediate Voice Barge-In | `mobile-capabilities-and-runtime.md` §3.1 | Pending barge-in cancellation engine | Barge-in test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Voice Foreground Service Lifecycle (FGS) | `mobile-capabilities-and-runtime.md` §3.4 | Pending microphone FGS implementation | FGS test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Capability-Dependent Device-Local TTS | `mobile-capabilities-and-runtime.md` §3.2 | Pending local TTS provider adapter | Local TTS test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Independently Gated Local STT & Degradation | `mobile-capabilities-and-runtime.md` §3.2 | Pending local STT evaluation | Local STT test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Separate Optional Cloud Voice Permissions | `mobile-capabilities-and-runtime.md` §3.2 | Pending independent voice settings | Cloud voice test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Security** | Android Backup Exclusions (`dataExtractionRules`) | `mobile-capabilities-and-runtime.md` §5.1 | Pending backup XML configuration | Backup dump test | MG11 | **APPROVED TARGET (NOT STARTED)** |
| **Security** | Component Hardening (`exported="false"`) | `mobile-capabilities-and-runtime.md` §5.1 | Pending manifest hardening | Intent security test | MG11 | **APPROVED TARGET (NOT STARTED)** |
| **Security** | Privacy Controls (`FLAG_SECURE`, Clipboard) | `mobile-capabilities-and-runtime.md` §5.1 | Pending window/clipboard flags | Privacy audit test | MG11 | **APPROVED TARGET (NOT STARTED)** |
| **Resource** | Battery-Saver & Thermal Throttling | `mobile-capabilities-and-runtime.md` §6.1 | Pending OS listener integration | Thermal test | MG10 | **APPROVED TARGET (NOT STARTED)** |
| **Resource** | Memory Pressure Trimming (`onTrimMemory`) | `mobile-capabilities-and-runtime.md` §6.2 | Pending trim memory handler | Trim memory test | MG10 | **APPROVED TARGET (NOT STARTED)** |
| **Deferred** | Health Connect & Wearable Biometrics | `health-and-wearables.md` | Prototype mock UI exists (`android/`) | Mock unit tests | Post-V1 | **LATER / DEFERRED (POST-V1)** |
| **Deferred** | Autonomous Local Routines | `mobile-offline-and-sync.md` §3.1 | Pending scheduling engine | N/A | Post-V1 | **LATER / DEFERRED (POST-V1)** |
| **Candidate** | Local On-Device VLM / Vision Inference | `mobile-offline-and-sync.md` §3.1 | Local VLM excluded from V1; attachment upload supported | N/A | Post-V1 | **IMPLEMENTATION OPEN / POST-V1 CANDIDATE** |
| **Deferred** | Always-On Wake Word Detection | `mobile-capabilities-and-runtime.md` §3.1 | Continuous wake word prohibited in V1 | N/A | Post-V1 | **LATER / DEFERRED (POST-V1)** |
| **Golden** | 12 Mobile Golden Acceptance Groups (MG1–MG12) | `mobile-capabilities-and-runtime.md` §8 | Pending implementation across L1–L5 layers | Verification guide | MG1–MG12 | **APPROVED TARGET (NOT STARTED)** |

---

## 2. Mobile Golden Acceptance Groups Audit (MG1–MG12)

The Mobile Golden Acceptance journey consists of 12 required verification groups aggregating verified evidence across L1–L5 verification layers, with mandatory physical reference Android hardware execution for hardware-dependent, audio, and thermal behaviors:

| Group ID | Verification Title & Scope | Verification Requirement | Current Status |
| :--- | :--- | :--- | :--- |
| **MG1** | **Enrollment & Identity** | Device pairing flow, revocable device token issuance, single-Profile binding enforcement, rejection of arbitrary profile assertions in request payloads. | **NOT STARTED** |
| **MG2** | **Platform Secure Storage & Transport** | Android Keystore protection for device token and provider API keys, zero plaintext storage, protected transport via TLS/HTTPS or approved encrypted overlay (Tailscale), rejection of direct port forwarding. | **NOT STARTED** |
| **MG3** | **Connected Host Operation** | Bidirectional communication with PC Local AI Runtime, REST turn submission, SSE token streaming, turn queue completion across transient client disconnects. | **NOT STARTED** |
| **MG4** | **Offline Durability & Outbox** | Fully functional offline Task creation, modification, and completion (`SET_COMPLETION`); durable outbox persistence surviving process death and OS reboot. | **NOT STARTED** |
| **MG5** | **Synchronization & Conflict Reconciliation** | Delta cursor synchronization, typed `CONFLICT_DETECTED` handling with user conflict presentation, typed `STALE_CURSOR` full re-baseline, retry idempotency deduplication (`mutation_id`). | **NOT STARTED** |
| **MG6** | **Punctual Offline Alarms & Reminders** | Alarm scheduling via `AlarmManager.setAlarmClock()`, precise ringing while device is in deep Doze conditional on exact-alarm capability/access, floating timezone recalculation, single-device duplicate firing suppression, and graceful degraded indication when exact alarm access is unavailable. | **NOT STARTED** |
| **MG7** | **System Lifecycle & Permission Resilience** | Alarm re-registration following `ACTION_BOOT_COMPLETED`, recovery when `SCHEDULE_EXACT_ALARM` or `POST_NOTIFICATIONS` is revoked, graceful degradation warnings. | **NOT STARTED** |
| **MG8** | **Voice Streaming & Audio Lifecycle** | Native mic capture, full-duplex WebSocket audio streaming to PC Host, immediate local barge-in playback muting, immediate muting on competing audio focus loss (`AUDIOFOCUS_LOSS`), pausing on unsafe route changes (`ACTION_AUDIO_BECOMING_NOISY`), device-local TTS vocalization when offline on qualifying devices, and graceful truthful degradation to text mode when unsupported. | **NOT STARTED** |
| **MG9** | **Mobile Inference & Hardware Tiers** | Capability detection across Tiers 0–3 based on runtime preflight evidence, clean UI degradation when unsupported, resident model memory budget enforcement, D6 mobile lifecycle integrity. | **NOT STARTED** |
| **MG10** | **Thermal, Battery & Power Governance** | WorkManager compliance with Doze maintenance windows, thermal throttling backoff under severe thermal state, graceful model unloading under modern `onTrimMemory` and memory pressure signals without process crash. | **NOT STARTED** |
| **MG11** | **Security, Revocation & Privacy** | Authoritative discovery of `DEVICE_REVOKED` triggering local revocation cleanup, preservation of third-party user keys, backup exclusion verification, quarantine on `PROFILE_INACTIVE`, permanent wipe on `PROFILE_PURGED`. | **NOT STARTED** |
| **MG12** | **Cross-Device Consistency** | Independent device alarm ringing without premature cancellation by passive PC notifications; cross-device alarm dismissal synchronization upon explicit user dismissal. | **NOT STARTED** |

---

## 3. Mobile V1 Release Blocker Audit

- [x] **MOBILE-ARCH Canonical Architecture Pass:** Batches A, B, C, and Cross-Batch Reconciliation approved by Chris and independently reviewed by GPT.
- [ ] **Mobile Foundation & Shared Workspace (`MOB-FOUNDATION`):** Flutter workspace configured and mobile package scaffolded.
- [ ] **Host Contract Prerequisites (`MOB-CONTRACT`):** Host endpoints accept client entity IDs, deduplicate `mutation_id`, track revisions, and support whole-turn batch sync.
- [ ] **Identity & Secure Storage (`MOB-IDENTITY`):** Android Keystore credential storage implemented; plaintext storage eliminated.
- [ ] **Durable Local Persistence & Outbox (`MOB-DATA`):** Relational SQLite database (Drift preferred candidate) and transactional outbox survive process death and reboot.
- [ ] **Synchronization & Concurrency (`MOB-SYNC`):** Delta sync, optimistic revision checks, and conflict handling verified.
- [ ] **Native Scheduling & Alarms (`MOB-SCHED`):** AlarmManager exact alarm delivery and permission lifecycle verified.
- [ ] **Connected Voice & Barge-In (`MOB-VOICE`):** Full-duplex WebSocket voice streaming with immediate barge-in verified.
- [ ] **Local Inference & Tiers (`MOB-INFER`):** Hardware qualification and model lifecycle controller verified.
- [ ] **Security & Sandboxing (`MOB-SECURITY`):** Backup exclusions and component hardening verified.
- [ ] **GATE-MOB-V1 Golden Acceptance Gate:** All 12 Mobile Golden Acceptance Groups (MG1–MG12) verified across L1–L5 verification layers with required physical hardware evidence and formal records.
