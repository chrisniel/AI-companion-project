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
| **Contracts** | Host Task Client UUID Acceptance | `mobile-offline-and-sync.md` §3.2.1 | Host `TaskCreate` does not accept client ID | Contract test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Transactional `mutation_id` Dedup | `mobile-offline-and-sync.md` §3.2.4 | Pending Host idempotency engine | API unit test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Entity Revisions & Optimistic Concurrency | `mobile-offline-and-sync.md` §3.2.2 | Pending Host revision columns & checks | Concurrency test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Change Cursor & Delta Sync Endpoint | `mobile-offline-and-sync.md` §3.2.5 | Pending Host cursor sync service | Delta sync test | MG10 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Lifecycle Outcomes (`DEVICE_REVOKED`, etc.) | `mobile-offline-and-sync.md` §7 | Pending Host typed outcome handlers | Lifecycle test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Contracts** | Host Batch Turn Sync & Client `conversation_id` | `mobile-offline-and-sync.md` §3.2.6 | Message `client_message_id` unique exists; batch endpoint pending | Turn import test | MG8 | **PARTIAL (MESSAGE CONSTRAINT ONLY)** |
| **Contracts** | Assistant Provenance & Dialogue Branch Metadata | `mobile-offline-and-sync.md` §3.2.6 | Pending Host message schema extensions | Branch import test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | Single-Profile Pairing & Revocable Token | `MOBILE_SYSTEM_BASELINE.md` §4.1 | Prototype uses unencrypted SharedPreferences | Auth test | MG1 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | Android Keystore Protected Storage | `MOBILE_SYSTEM_BASELINE.md` §4.1 | Prototype uses unencrypted storage (anti-pattern) | Keystore test | MG1 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | Credential Expiry & Non-Destructive Rotation | `mobile-capabilities-and-runtime.md` §5.3 | Pending rotation handshake | Rotation test | MG1 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | Revocation Data Erasure & Quarantine | `mobile-offline-and-sync.md` §7 | Pending cleanup coordinator | Erasure test | MG9 | **APPROVED TARGET (NOT STARTED)** |
| **Identity** | D5 Transport Protection (Tailscale / TLS) | `MOBILE_SYSTEM_BASELINE.md` §4.2 | Prototype uses plain HTTP | Network test | MG1 | **APPROVED TARGET (NOT STARTED)** |
| **Data** | Relational Local Store (SQLite / Drift) | `mobile-offline-and-sync.md` §2.2 | Prototype uses in-memory MutableStateFlow | Drift schema test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Data** | Durable Transactional Outbox Journal | `mobile-offline-and-sync.md` §2.2 | Prototype lacks outbox (violates durability) | Outbox durability test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Data** | Durable Offline Conversation Working State | `mobile-offline-and-sync.md` §2.1 | Pending SQLite conversation store | Durability test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Sync** | Offline Task Create, Update, Delete & Coalesce | `mobile-offline-and-sync.md` §3.2.1 | Prototype has un-journaled optimistic tasks | Outbox sync test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Sync** | Idempotent Desired-State `SET_COMPLETION` | `mobile-offline-and-sync.md` §3.2.3 | Pending desired-state mutation handler | Idempotency test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Sync** | Optimistic Concurrency Conflict Resolution | `mobile-offline-and-sync.md` §3.2.3 | Pending conflict draft UI | Conflict test | MG2 | **APPROVED TARGET (NOT STARTED)** |
| **Sync** | Monotonic Cursor Sync & Stale Re-baseline | `mobile-offline-and-sync.md` §3.2.5 | Pending re-baseline engine | Re-baseline test | MG10 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Replicated Reminder/Alarm Occurrence Ingestion | `mobile-offline-and-sync.md` §6.1 | Pending occurrence replica store | Sched replica test | MG3 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Android `AlarmManager` Exact Alarm Scheduling | `mobile-offline-and-sync.md` §6.2 | Prototype lacks exact alarm integration | Alarm trigger test | MG3 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | `canScheduleExactAlarms()` & Degradation | `mobile-offline-and-sync.md` §6.2 | Pending permission lifecycle monitor | Permission test | MG3 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Notification Channels & `POST_NOTIFICATIONS` | `mobile-offline-and-sync.md` §6.2 | Pending notification channel setup | Notification test | MG3 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Reboot (`BOOT_COMPLETED`) & Timezone Handlers | `mobile-offline-and-sync.md` §6.4 | Pending broadcast receivers | Reboot receiver test | MG4 | **APPROVED TARGET (NOT STARTED)** |
| **Schedule** | Cross-Device Dismissal & Duplicate Prevention | `mobile-offline-and-sync.md` §6.3.2 | Pending alert state machine | Cross-device test | MG3 | **APPROVED TARGET (NOT STARTED)** |
| **Dialogue** | Connected Conversation Streaming (SSE) | `mobile-offline-and-sync.md` §3.1 | Prototype has basic streaming chat | Streaming test | MG5 | **PARTIAL (PROTOTYPE REFERENCE)** |
| **Dialogue** | Qualified Offline Text Turn Coordination | `mobile-offline-and-sync.md` §3.2.6 | Pending offline dialogue coordinator | Offline turn test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Dialogue** | Tier 0/1 Truthful Read-Only Input Locking | `mobile-offline-and-sync.md` §3.2.6 | Pending capability input guard | Degradation test | MG8 | **APPROVED TARGET (NOT STARTED)** |
| **Dialogue** | Multimodal Attachment Upload to Host | `mobile-offline-and-sync.md` §3.1 | Prototype lacks attachment queue | Attachment test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Inference** | Runtime Hardware Qualification (Tiers 0–3) | `mobile-capabilities-and-runtime.md` §2.1 | Pending hardware benchmark classifier | Tier detection test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Inference** | LAN Host-to-Device Model Transfer | `mobile-capabilities-and-runtime.md` §2.3 | Pending Wi-Fi model transfer client | Transfer test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Inference** | Single Resident Model Cap (`--models-max 1`) | `mobile-capabilities-and-runtime.md` §2.3 | Pending model lifecycle manager | Lifecycle test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Inference** | Local Inference Runtime Adapter | `mobile-capabilities-and-runtime.md` §2.2 | Pending engine adapter (e.g. llama.cpp / ExecuTorch) | Inference test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Connected WebSocket Audio Streaming to PC | `mobile-capabilities-and-runtime.md` §3.1 | Pending WebSocket audio transport | WS audio test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Android Audio Hardware & Focus Adapter | `mobile-capabilities-and-runtime.md` §3.3 | Pending audio focus controller | Audio focus test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Mandatory Immediate Voice Barge-In | `mobile-capabilities-and-runtime.md` §3.1 | Pending barge-in cancellation engine | Barge-in test | MG6 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Voice Foreground Service Lifecycle (FGS) | `mobile-capabilities-and-runtime.md` §3.4 | Pending microphone FGS implementation | FGS test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Capability-Dependent Device-Local TTS | `mobile-capabilities-and-runtime.md` §3.2 | Pending local TTS provider adapter | Local TTS test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Independently Gated Local STT & Degradation | `mobile-capabilities-and-runtime.md` §3.2 | Pending local STT evaluation | Local STT test | MG7 | **APPROVED TARGET (NOT STARTED)** |
| **Voice** | Separate Optional Cloud Voice Permissions | `mobile-capabilities-and-runtime.md` §3.2 | Pending independent voice settings | Cloud voice test | MG5 | **APPROVED TARGET (NOT STARTED)** |
| **Security** | Android Backup Exclusions (`dataExtractionRules`) | `mobile-capabilities-and-runtime.md` §5.1 | Pending backup XML configuration | Backup dump test | MG12 | **APPROVED TARGET (NOT STARTED)** |
| **Security** | Component Hardening (`exported="false"`) | `mobile-capabilities-and-runtime.md` §5.1 | Pending manifest hardening | Intent security test | MG12 | **APPROVED TARGET (NOT STARTED)** |
| **Security** | Privacy Controls (`FLAG_SECURE`, Clipboard) | `mobile-capabilities-and-runtime.md` §5.1 | Pending window/clipboard flags | Privacy audit test | MG12 | **APPROVED TARGET (NOT STARTED)** |
| **Resource** | Battery-Saver & Thermal Throttling | `mobile-capabilities-and-runtime.md` §6.1 | Pending OS listener integration | Thermal test | MG11 | **APPROVED TARGET (NOT STARTED)** |
| **Resource** | Memory Pressure Trimming (`onTrimMemory`) | `mobile-capabilities-and-runtime.md` §6.2 | Pending trim memory handler | Trim memory test | MG11 | **APPROVED TARGET (NOT STARTED)** |
| **Deferred** | Health Connect & Wearable Biometrics | `health-and-wearables.md` | Prototype mock UI exists (`android/`) | Mock unit tests | Post-V1 | **LATER / DEFERRED (POST-V1)** |
| **Deferred** | Autonomous Local Routines | `mobile-offline-and-sync.md` §3.1 | Pending scheduling engine | N/A | Post-V1 | **LATER / DEFERRED (POST-V1)** |
| **Deferred** | Local On-Device VLM / Vision Inference | `mobile-offline-and-sync.md` §3.1 | Local VLM excluded from V1 | N/A | Post-V1 | **LATER / DEFERRED (POST-V1)** |
| **Deferred** | Always-On Wake Word Detection | `mobile-capabilities-and-runtime.md` §3.1 | Continuous wake word prohibited in V1 | N/A | Post-V1 | **LATER / DEFERRED (POST-V1)** |
| **Golden** | 12 Mobile Golden Acceptance Groups (MG1–MG12) | `mobile-capabilities-and-runtime.md` §8 | Pending implementation & physical hardware run | Verification guide | MG1–MG12 | **APPROVED TARGET (NOT STARTED)** |

---

## 2. Mobile Golden Acceptance Groups Audit (MG1–MG12)

The Mobile Golden Acceptance journey consists of 12 required verification groups executed on physical reference Android devices:

| Group ID | Verification Title & Scope | Verification Requirement | Current Status |
| :--- | :--- | :--- | :--- |
| **MG1** | **Pairing & Secure Credential Storage** | Device pairs with PC Host via QR/LAN; token stored in Android Keystore; single-Profile binding verified. | **NOT STARTED** |
| **MG2** | **Offline Task Mutations & Conflict Handling** | Create, edit, and complete tasks while disconnected; verify SQLite outbox persistence; reconnect and verify conflict detection. | **NOT STARTED** |
| **MG3** | **Replicated Reminder & Alarm Delivery** | Replicated alarm triggers exactly via `AlarmManager`; exact alarm permission lifecycle verified; heads-up notification shown. | **NOT STARTED** |
| **MG4** | **System Lifecycle & Reboot Resilience** | Device reboot executed; `ACTION_BOOT_COMPLETED` re-registers alarms; timezone shift recalculates floating alarms accurately. | **NOT STARTED** |
| **MG5** | **Connected Conversation & Voice Streaming** | Full-duplex WebSocket voice streaming to PC Runtime; audio focus acquired; token streaming rendered cleanly. | **NOT STARTED** |
| **MG6** | **Immediate Voice Barge-In** | Spoken user interruption instantly stops mobile audio playback, clears audio buffers, and cancels in-flight TTS chunks. | **NOT STARTED** |
| **MG7** | **Capability-Dependent Local Inference & Model Lifecycle** | Hardware qualification classifies device tier; LAN model transfer preflight succeeds; single resident model cap enforced. | **NOT STARTED** |
| **MG8** | **Offline Conversation Working State & Reconciliation** | Qualified offline dialogue generates local assistant turn with provenance; reconnects and imports as whole turn unit to PC Host. | **NOT STARTED** |
| **MG9** | **Satellite Device Revocation & Profile Quarantine** | Host admin revokes device; mobile executes local erasure on reconnection; soft-delete enters 7-day quarantine without wipe. | **NOT STARTED** |
| **MG10** | **Network Reconnection & Stale Cursor Re-Baseline** | Mobile reconnects after prolonged absence; Host detects stale cursor; mobile cleanly purges replica and downloads fresh snapshot. | **NOT STARTED** |
| **MG11** | **Thermal, Battery Saver & Memory Governance** | Battery-saver mode defers background work; thermal pressure throttles inference; OS memory pressure trims cache safely. | **NOT STARTED** |
| **MG12** | **Security Boundaries & Backup Exclusions** | Android cloud backup inspection confirms credentials and databases excluded; internal components non-exported; `FLAG_SECURE` active. | **NOT STARTED** |

---

## 3. Mobile V1 Release Blocker Audit

- [x] **MOBILE-ARCH Canonical Architecture Pass:** Batches A, B, C, and Cross-Batch Reconciliation approved by Chris and independently reviewed by GPT.
- [ ] **Mobile Foundation & Shared Workspace (`MOB-FOUNDATION`):** Flutter workspace configured and mobile package scaffolded.
- [ ] **Host Contract Prerequisites (`MOB-CONTRACT`):** Host endpoints accept client entity IDs, deduplicate `mutation_id`, track revisions, and support whole-turn batch sync.
- [ ] **Identity & Secure Storage (`MOB-IDENTITY`):** Android Keystore credential storage implemented; plaintext storage eliminated.
- [ ] **Durable Local Persistence & Outbox (`MOB-DATA`):** SQLite/Drift database and transactional outbox survive process death and reboot.
- [ ] **Synchronization & Concurrency (`MOB-SYNC`):** Delta sync, optimistic revision checks, and conflict handling verified.
- [ ] **Native Scheduling & Alarms (`MOB-SCHED`):** AlarmManager exact alarm delivery and permission lifecycle verified.
- [ ] **Connected Voice & Barge-In (`MOB-VOICE`):** Full-duplex WebSocket voice streaming with immediate barge-in verified.
- [ ] **Local Inference & Tiers (`MOB-INFER`):** Hardware qualification and model lifecycle controller verified.
- [ ] **Security & Sandboxing (`MOB-SECURITY`):** Backup exclusions and component hardening verified.
- [ ] **GATE-MOB-V1 Golden Acceptance Gate:** All 12 Mobile Golden Acceptance Groups (MG1–MG12) verified on physical Android hardware with formal evidence recorded.
