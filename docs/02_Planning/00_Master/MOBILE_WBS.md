# AI Companion — Mobile V1 Work Breakdown Structure (WBS)

> **Document Role:** Canonical granular work breakdown structure cataloging stable work IDs across all Mobile V1 implementation streams.  
> **Status:** Active Canonical Planning Baseline  
> **Authority Precedence:** Normative Mobile architecture is owned by [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md), [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md), and [`mobile-capabilities-and-runtime.md`](../../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md). PC V1 implementation is tracked separately in [`WBS.md`](WBS.md). Active sprint tracking resides in [`docs/01_Tracking/task.md`](../../01_Tracking/task.md).
> **Batching Principle:** Use the largest tightly related task or batch that preserves reliable first-pass accuracy, reviewability, and bounded correction cost. Do not enforce arbitrary LOC or file quotas.

---

## 1. Stream Index

| Stream Prefix | Domain Scope | Primary Responsibility |
| :--- | :--- | :--- |
| **`MOB-FOUNDATION`** | Flutter Mobile Foundation | Shared Dart/Flutter monorepo setup, package identity, platform adapters, lifecycle. |
| **`MOB-CONTRACT`**   | Host Contract Prerequisites | Host write idempotency, client Task/Conversation IDs, revisions, cursor sync, turn import. |
| **`MOB-IDENTITY`**   | Identity, Enrollment & Transport | Device pairing, 1-Profile binding, Keystore secrets, rotation, D5 transport. |
| **`MOB-DATA`**       | Local Persistence & Outbox | Relational SQLite store (Drift), transactional outbox journal, offline working state, durability. |
| **`MOB-SYNC`**       | Sync & Reconciliation Engine | Asymmetric sync, desired-state ops, conflict resolution, re-baseline, whole-turn reconciliation. |
| **`MOB-SCHED`**      | Scheduling, Reminders & Alarms | Replicated occurrences, AlarmManager exact alarms, permissions, Doze/reboot restoration. |
| **`MOB-CONV`**       | Conversations & Offline Dialogue | Connected SSE streaming, qualified offline text turns, cached context, multimodal upload. |
| **`MOB-INFER`**      | Local Inference & Tiers | Evidence-driven Tiers 0–3, LAN model transfer, single resident model cap, thermal/battery rules. |
| **`MOB-VOICE`**      | Mobile Voice & Audio Pipeline | Connected WebSocket voice, audio focus, mandatory barge-in, FGS lifecycle, local TTS adapter. |
| **`MOB-SECURITY`**   | Security, Privacy & Sandboxing | Keystore keys, backup/data-extraction exclusions, sandbox isolation, screen/clipboard privacy. |
| **`MOB-VERIFY`**     | Verification & Golden Gate | 5-layer test matrix (L1–L5), emulator test matrix, 12 Mobile Golden Groups (MG1–MG12). |

---

## 2. Granular Work Item Catalog

### Stream: `MOB-FOUNDATION` — Flutter Mobile Foundation

- **`MOB-FOUNDATION-001`**: Shared Dart/Flutter Workspace Topology Setup
  - *Scope:* Configure shared repository workspace topology with separate desktop and mobile application targets to isolate platform compilation while sharing core packages.
  - *Responsibility:* Both (Flutter Monorepo)
  - *Architectural Owner:* [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §3, [`ADR-0004`](../../04_Architecture/decisions/ADR-0004-d3-android-application-identity.md)
  - *Principal Dependencies:* `PC-CLIENT-001` (Desktop Scaffolding)
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-FOUNDATION-002`**: Production Mobile Application Target Scaffolding
  - *Scope:* Scaffold production Flutter Android application target using locked package namespace `com.cnl.aicompanion`, build scripts, and baseline manifest.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §3, [`ADR-0004`](../../04_Architecture/decisions/ADR-0004-d3-android-application-identity.md)
  - *Principal Dependencies:* `MOB-FOUNDATION-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED` *(Note: Kotlin prototype `android/` is reference evidence only)*

- **`MOB-FOUNDATION-003`**: Shared Contracts & Design Primitives Package Integration
  - *Scope:* Integrate shared packages for domain contracts, OpenAPI-derived models, theme tokens (SoftGlass), and authentication abstractions.
  - *Responsibility:* Both (Shared Packages)
  - *Architectural Owner:* [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §3
  - *Principal Dependencies:* `MOB-FOUNDATION-001`, `PC-API-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-FOUNDATION-004`**: Platform Service Adapter Interface & Android Injections
  - *Scope:* Define platform-neutral service interfaces and inject Android-specific platform adapters (WorkManager, Keystore, AlarmManager, Audio).
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §3
  - *Principal Dependencies:* `MOB-FOUNDATION-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-FOUNDATION-005`**: Mobile Navigation Shell & Lifecycle Coordinator
  - *Scope:* Build mobile UI shell, navigation stack, app foreground/background lifecycle observers, and Flutter state restoration.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §2.1, [`mobile-capabilities-and-runtime.md`](../../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) §6.1
  - *Principal Dependencies:* `MOB-FOUNDATION-002`, `MOB-FOUNDATION-003`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-CONTRACT` — Host Contract Prerequisites for Mobile

- **`MOB-CONTRACT-001`**: Client-Generated Stable Task Identity Acceptance
  - *Scope:* Update PC Runtime `TaskCreate` endpoint to accept client-generated UUIDv4 `entity_id` and preserve identity across creation.
  - *Responsibility:* Host Runtime (PC Backend)
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.1
  - *Principal Dependencies:* `PC-SCHED-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONTRACT-002`**: Transactional `mutation_id` Deduplication
  - *Scope:* Implement Host write endpoint idempotency keys (`mutation_id`), recording and deduplicating mutation attempts within a DB transaction.
  - *Responsibility:* Host Runtime (PC Backend)
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.4
  - *Principal Dependencies:* `PC-API-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONTRACT-003`**: Host Entity Revisions & Optimistic Concurrency Control
  - *Scope:* Add host-issued monotonic entity revisions (`revision: int`), base revision checks on mutation endpoints, and typed `CONFLICT_DETECTED` responses.
  - *Responsibility:* Host Runtime (PC Backend)
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.2, §3.2.3
  - *Principal Dependencies:* `MOB-CONTRACT-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONTRACT-004`**: Host-Issued Sync Cursor & Delta Synchronization Protocol
  - *Scope:* Build Host delta sync endpoint returning entity changes occurring after a client-provided monotonic sync cursor, with bounded history retention and `STALE_CURSOR` typed outcome.
  - *Responsibility:* Host Runtime (PC Backend)
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.5
  - *Principal Dependencies:* `MOB-CONTRACT-003`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONTRACT-005`**: Satellite Device Lifecycle Outcomes Protocol
  - *Scope:* Implement typed response outcomes for device authorization lifecycle: `DEVICE_REVOKED`, `PROFILE_INACTIVE` (7-day recovery), `PROFILE_PURGED`, and `CREDENTIAL_EXPIRED`.
  - *Responsibility:* Host Runtime (PC Backend)
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §7, [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §4.3
  - *Principal Dependencies:* `PC-IDENTITY-003`, `PC-IDENTITY-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONTRACT-006`**: Client-Generated Conversation Identity & Batch Turn Import Endpoint
  - *Scope:* Implement Host batch turn sync endpoint accepting client UUID `conversation_id`, validating `client_message_id` uniqueness, and importing atomic whole-turn units.
  - *Responsibility:* Host Runtime (PC Backend)
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.6
  - *Principal Dependencies:* `PC-API-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED` *(Note: `client_message_id` DB uniqueness exists; batch endpoint and client conversation ID acceptance are target requirements)*

- **`MOB-CONTRACT-007`**: Assistant Local Inference Provenance & Dialogue Branch Metadata
  - *Scope:* Extend Host message schema/DTOs to store assistant provenance (`MOBILE_LOCAL_INFERENCE`, `device_id`, `model_tag`) and represent branched offline conversation segments without PC LLM regeneration.
  - *Responsibility:* Host Runtime (PC Backend)
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.6
  - *Principal Dependencies:* `MOB-CONTRACT-006`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONTRACT-008`**: Profile & Character Ownership Enforcement on Satellite Ingestion
  - *Scope:* Enforce strict server-side validation ensuring imported turns and mutations match the enrolled Device's bound Profile and target a single explicit `character_id`.
  - *Responsibility:* Host Runtime (PC Backend)
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.2.6, [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §2
  - *Principal Dependencies:* `PC-IDENTITY-002`, `MOB-CONTRACT-006`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-IDENTITY` — Mobile Identity, Enrollment & Transport

- **`MOB-IDENTITY-001`**: Satellite Device Pairing Handshake & Credential Exchange
  - *Scope:* Implement QR code or LAN pairing flow between PC Host Admin and Mobile Companion, issuing an independently revocable Device Token bound to exactly one Profile.
  - *Responsibility:* Both
  - *Architectural Owner:* [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §4.1, [`profiles-and-devices.md`](../../04_Architecture/02_Data_and_Security/profiles-and-devices.md)
  - *Principal Dependencies:* `PC-IDENTITY-003`, `MOB-FOUNDATION-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-IDENTITY-002`**: Android Keystore Platform-Protected Secure Credential Storage
  - *Scope:* Implement secure storage adapter backed by the Android Keystore system for Device Tokens and third-party API keys (plaintext SharedPreferences strictly prohibited).
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §4.1, [`mobile-capabilities-and-runtime.md`](../../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) §5.1
  - *Principal Dependencies:* `MOB-FOUNDATION-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-IDENTITY-003`**: Credential Expiry & Non-Destructive Rotation Handshake
  - *Scope:* Implement Mobile handling for `CREDENTIAL_EXPIRED` / `ROTATION_REQUIRED` typed outcomes, prompting user re-authentication without destructive data wipe.
  - *Responsibility:* Both
  - *Architectural Owner:* [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §4.3, [`mobile-capabilities-and-runtime.md`](../../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) §5.3
  - *Principal Dependencies:* `MOB-IDENTITY-001`, `MOB-CONTRACT-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-IDENTITY-004`**: Revocation Cleanup & Profile Soft-Delete Quarantine
  - *Scope:* Implement local data erasure upon `DEVICE_REVOKED` / `PROFILE_PURGED`, and read-only quarantine upon `PROFILE_INACTIVE` (preserving 3rd-party user keys).
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §7
  - *Principal Dependencies:* `MOB-IDENTITY-002`, `MOB-CONTRACT-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-IDENTITY-005`**: Decision D5 Protected Transport Client
  - *Scope:* Implement Mobile network client requiring application authentication and TLS / Tailscale encrypted overlay for non-loopback connections (direct port forwarding blocked).
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §4.2, [`authentication-and-secrets.md`](../../04_Architecture/02_Data_and_Security/authentication-and-secrets.md)
  - *Principal Dependencies:* `MOB-FOUNDATION-003`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-DATA` — Mobile Local Persistence & Outbox Journal

- **`MOB-DATA-001`**: Relational Local Database Scaffolding (Drift / SQLite)
  - *Scope:* Scaffold relational local SQLite database using Drift with schema migrations, ACID transactions, and private sandbox storage.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §2.2
  - *Principal Dependencies:* `MOB-FOUNDATION-003`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-DATA-002`**: Transactional Mutation Journal (Outbox) Implementation
  - *Scope:* Build durable SQLite outbox journal storing pending mutations with UUID `mutation_id`, entity ID, and base revision; surviving process death and reboot.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §2.2, §3.2.1
  - *Principal Dependencies:* `MOB-DATA-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-DATA-003`**: Replicated Domain Entity Storage & Cache Partitioning
  - *Scope:* Create database tables for replicated domain entities (Tasks, Reminders, Alarms) and evictable cache partitions for read-only history, memories, and character profiles.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §2.1
  - *Principal Dependencies:* `MOB-DATA-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-DATA-004`**: Durable Offline Conversation Working State Store
  - *Scope:* Create local SQLite tables for durable offline user turns, generated assistant responses, and provenance metadata, surviving reboot until synced.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §2.1, §3.2.6
  - *Principal Dependencies:* `MOB-DATA-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-DATA-005`**: Synchronization Metadata & Monotonic Cursor Persistence
  - *Scope:* Create local tables for sync cursors, entity revision vectors, and last-sync timestamps.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §2.1, §3.2.5
  - *Principal Dependencies:* `MOB-DATA-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-SYNC` — Synchronization & Reconciliation Engine

- **`MOB-SYNC-001`**: Outbox Worker & Network Dispatcher
  - *Scope:* Build background synchronization worker integrated with Android WorkManager and network connectivity constraints to drain outbox mutations.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §5.1, [`mobile-capabilities-and-runtime.md`](../../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) §6.1
  - *Principal Dependencies:* `MOB-DATA-002`, `MOB-IDENTITY-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SYNC-002`**: Offline Task Mutations & Causal Dependency Ordering
  - *Scope:* Implement offline Task create, update, and delete mutations; preserve causal ordering via mutation coalescing or explicit per-entity dependency tracking.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.2.1
  - *Principal Dependencies:* `MOB-DATA-002`, `MOB-CONTRACT-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SYNC-003`**: Idempotent Desired-State Semantic Operations
  - *Scope:* Implement semantic desired-state mutations (`SET_COMPLETION(completed=bool)`) to prevent non-idempotent toggle divergence under network retries.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.3
  - *Principal Dependencies:* `MOB-SYNC-002`, `MOB-CONTRACT-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SYNC-004`**: Optimistic Concurrency & Revision Conflict Handler
  - *Scope:* Handle `CONFLICT_DETECTED` responses from Host; retain uncommitted local edits in a draft/conflict state and prompt user resolution.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.3, §4
  - *Principal Dependencies:* `MOB-SYNC-002`, `MOB-CONTRACT-003`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SYNC-005`**: Monotonic Cursor Delta Sync & Stale-Cursor Re-Baseline Flow
  - *Scope:* Implement delta synchronization using Host change cursors; execute full local re-baseline flow upon receiving `STALE_CURSOR`.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §3.2.5, §4
  - *Principal Dependencies:* `MOB-DATA-005`, `MOB-CONTRACT-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SYNC-006`**: Tombstone Propagation & Soft-Delete Cascading
  - *Scope:* Synchronize soft-deleted entities and tombstone records, purging tombstones after authoritative synchronization intervals.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.1, §3.2.5
  - *Principal Dependencies:* `MOB-SYNC-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SYNC-007`**: Offline Conversation Turn Reconciliation & Import Dispatcher
  - *Scope:* Dispatch batch offline conversation turns upon reconnection; handle `client_message_id` deduplication and causal branch attribution without PC LLM regeneration.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.2.6
  - *Principal Dependencies:* `MOB-DATA-004`, `MOB-CONTRACT-006`, `MOB-CONTRACT-007`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-SCHED` — Scheduling, Reminders & Alarm Delivery

- **`MOB-SCHED-001`**: Replicated Occurrence Ingestion & Local Persistence
  - *Scope:* Ingest precomputed Reminder and Alarm occurrences generated by PC `SchedulerService`, storing them with UTC trigger times and floating-time recurrence rules.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §6.1, [`tasks-reminders-alarms-and-routines.md`](../../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md)
  - *Principal Dependencies:* `MOB-DATA-003`, `PC-SCHED-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SCHED-002`**: Android Exact Alarm Scheduling Integration
  - *Scope:* Integrate Android `AlarmManager.setExactAndAllowWhileIdle()` for active alarm occurrences with `SCHEDULE_EXACT_ALARM` permissions.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §6.2
  - *Principal Dependencies:* `MOB-SCHED-001`, `MOB-FOUNDATION-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SCHED-003`**: Exact Alarm Permission Lifecycle & Degradation Handling
  - *Scope:* Implement active verification via `AlarmManager.canScheduleExactAlarms()`; truthfully mark alarms as UNARMED / DEGRADED when permission is missing or revoked.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §6.2
  - *Principal Dependencies:* `MOB-SCHED-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SCHED-004`**: Notification Channel Setup & `POST_NOTIFICATIONS` Handling
  - *Scope:* Configure Android notification channels for Alarms and Reminders; handle Android 13+ `POST_NOTIFICATIONS` runtime permission and graceful suppression warnings.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §6.2
  - *Principal Dependencies:* `MOB-SCHED-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SCHED-005`**: System Lifecycle Handlers (Reboot, Timezone, Clock Changes)
  - *Scope:* Implement BroadcastReceivers for `ACTION_BOOT_COMPLETED`, `ACTION_TIMEZONE_CHANGED`, and `ACTION_TIME_CHANGED` to re-arm alarms and re-evaluate floating occurrences.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §6.4
  - *Principal Dependencies:* `MOB-SCHED-002`, `MOB-SCHED-003`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SCHED-006`**: Idempotent Occurrence State Machine & Snooze
  - *Scope:* Build local occurrence state machine (`SCHEDULED`, `TRIGGERED`, `ACKNOWLEDGED`, `SNOOZED`, `CANCELED`, `MISSED`); handle snooze calculation without duplicating parent entities.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §6.3.1
  - *Principal Dependencies:* `MOB-SCHED-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SCHED-007`**: Cross-Device Dismissal Semantics & Duplicate Prevention
  - *Scope:* Prevent passive PC toast notifications from cancelling phone alarms; sync explicit user dismiss/snooze mutations across devices.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §6.3.2
  - *Principal Dependencies:* `MOB-SCHED-006`, `MOB-SYNC-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-CONV` — Mobile Conversations & Offline Dialogue

- **`MOB-CONV-001`**: Connected Conversation Client & SSE Token Streaming
  - *Scope:* Build Mobile conversation view consuming Host REST endpoints and Server-Sent Events (SSE) token stream with Markdown rendering and turn retry.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.1, [`assistant-and-conversations.md`](../../04_Architecture/01_Domains/assistant-and-conversations.md)
  - *Principal Dependencies:* `MOB-FOUNDATION-003`, `PC-API-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONV-002`**: Offline Local Text Dialogue Coordinator
  - *Scope:* Coordinate offline text conversational turns on qualified Tier 2/3 devices, committing turns and provenance metadata to local SQLite storage before presentation.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.2.6
  - *Principal Dependencies:* `MOB-DATA-004`, `MOB-INFER-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONV-003`**: Tier 0/1 Read-Only Dialogue Fallback & Input Locking
  - *Scope:* Lock turn submission when offline on Tier 0/1 devices (or when local LLM is uninstalled), displaying truthful degraded notice while keeping history readable.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.2.6, [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §2.1
  - *Principal Dependencies:* `MOB-CONV-001`, `MOB-INFER-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONV-004`**: Cached Memory & Context Assembly for Offline Turns
  - *Scope:* Assemble local prompt context from cached recent thread turns, character persona definition, and replicated read-only memories (no local memory database writes).
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.2.6
  - *Principal Dependencies:* `MOB-DATA-003`, `MOB-CONV-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-CONV-005`**: Multimodal Attachment Capture & Upload Coordinator
  - *Scope:* Implement camera/gallery attachment capture on Mobile and queue files for upload to PC Host upon reconnection (local VLM inference excluded from V1).
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-offline-and-sync.md`](../../04_Infrastructure/mobile-offline-and-sync.md) §3.1, [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §7
  - *Principal Dependencies:* `MOB-CONV-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-INFER` — Mobile Local Inference & Hardware Tiers

- **`MOB-INFER-001`**: Evidence-Driven Hardware Qualification Matrix Engine
  - *Scope:* Evaluate device specs at runtime across RAM, SoC, and thermal headroom to classify into Tiers 0–3, gating local LLM inference eligibility.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §2.1, §2.2
  - *Principal Dependencies:* `MOB-FOUNDATION-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-INFER-002`**: LAN Host-to-Device Model Transfer Protocol
  - *Scope:* Build local Wi-Fi transfer client to copy approved compact model bundles from PC Library to Mobile private storage with SHA-256 integrity preflight.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §2.3
  - *Principal Dependencies:* `PC-MODEL-001`, `MOB-IDENTITY-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-INFER-003`**: Single Resident Model Lifecycle Controller
  - *Scope:* Enforce single resident model cap (`--models-max 1`) on mobile, handling explicit load, unload, purge, and pre-allocation memory checks.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §2.3, §6.2
  - *Principal Dependencies:* `MOB-INFER-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-INFER-004`**: Engine-Independent Local Inference Adapter
  - *Scope:* Build pluggable inference runtime abstraction for candidate mobile engines (e.g., llama.cpp Android / ExecuTorch), enforcing prompt evaluation timeouts.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §2.2
  - *Principal Dependencies:* `MOB-INFER-003`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-INFER-005`**: Battery-Saver & Thermal Throttling Coordinator
  - *Scope:* Integrate `PowerManager.isPowerSaveMode()` and Android thermal status listeners to disable model pre-loading and throttle inference under thermal pressure.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §6.1, §6.3
  - *Principal Dependencies:* `MOB-INFER-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-VOICE` — Mobile Voice & Audio Pipeline

- **`MOB-VOICE-001`**: Connected Voice Streaming Client over WebSocket
  - *Scope:* Build full-duplex WebSocket audio client connecting to PC Runtime canonical STT/TTS/VAD providers with binary PCM streaming.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §3.1, [`voice-and-audio.md`](../../04_Architecture/01_Domains/voice-and-audio.md)
  - *Principal Dependencies:* `MOB-IDENTITY-005`, `PC-VOICE-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VOICE-002`**: Android Audio Hardware & Focus Platform Adapter
  - *Scope:* Build Flutter audio capture/playback adapter integrating Android `AudioManager` and `AudioFocusRequest` with transient ducking handling.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §3.3
  - *Principal Dependencies:* `MOB-FOUNDATION-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VOICE-003`**: Mandatory Voice Barge-In State Machine
  - *Scope:* Implement instant playback cancellation, audio buffer flush, and stale audio chunk invalidation upon user speech detection.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §3.1
  - *Principal Dependencies:* `MOB-VOICE-001`, `MOB-VOICE-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VOICE-004`**: Voice Foreground Service Lifecycle Management
  - *Scope:* Implement Android Foreground Service with `foregroundServiceType="microphone"`, `RECORD_AUDIO`, visible user notification, and strict user-initiated lifecycle.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §3.4
  - *Principal Dependencies:* `MOB-VOICE-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VOICE-005`**: Device-Local TTS Provider Adapter
  - *Scope:* Implement capability-dependent device-local TTS adapter (engine-independent) for vocalizing alarms and text when an approved local TTS provider is installed.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §3.2, [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §5.1
  - *Principal Dependencies:* `MOB-VOICE-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VOICE-006`**: Independently Capability-Gated Local STT Adapter
  - *Scope:* Implement independent gating for device-local STT; truthfully degrade to typed text input when heavy local STT is unsupported.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §3.2
  - *Principal Dependencies:* `MOB-VOICE-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VOICE-007`**: Optional Cloud Voice Provider Routing
  - *Scope:* Provide separate, opt-in cloud STT and cloud TTS routing using Keystore-stored user API keys; strictly no silent cloud fallback.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §3.2, [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §5.1
  - *Principal Dependencies:* `MOB-IDENTITY-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-SECURITY` — Platform Security, Privacy & Sandboxing

- **`MOB-SECURITY-001`**: Android Backup & Data-Extraction Exclusions
  - *Scope:* Configure `dataExtractionRules` and `backup_rules.xml` to explicitly exclude credentials, database files, journals, models, and caches from cloud backups and device transfers.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §5.1, [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) §7
  - *Principal Dependencies:* `MOB-FOUNDATION-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SECURITY-002`**: OS Private Sandbox Baseline & Deep Link Hardening
  - *Scope:* Set `android:exported="false"` on internal Activities, Services, and Receivers; enforce signature permissions or strict input validation on external deep links.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §5.1
  - *Principal Dependencies:* `MOB-FOUNDATION-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SECURITY-003`**: Screen & Clipboard Privacy Controls
  - *Scope:* Apply `FLAG_SECURE` to sensitive chat and settings screens where configured; set `EXTRA_IS_SENSITIVE` on copied credentials; forbid auto-clipboard copying.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §5.1
  - *Principal Dependencies:* `MOB-FOUNDATION-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-SECURITY-004`**: Memory Pressure & Storage Eviction Handlers
  - *Scope:* Implement `ComponentCallbacks2.onTrimMemory()` handler (`TRIM_MEMORY_UI_HIDDEN`, background trim) and cache eviction to release volatile buffers before OS termination.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §6.2
  - *Principal Dependencies:* `MOB-DATA-001`, `MOB-INFER-003`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

### Stream: `MOB-VERIFY` — Mobile Verification & Golden Acceptance

- **`MOB-VERIFY-001`**: L1 Headless Unit & Contract Test Suite
  - *Scope:* Author Dart unit tests for state machine models, outbox journal transactions, and serialized DTO compatibility running in headless CI without emulator overhead.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §7.1
  - *Principal Dependencies:* `MOB-FOUNDATION-003`, `MOB-DATA-002`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VERIFY-002`**: L2 Local Integration & Database Durability Tests
  - *Scope:* Implement integration tests verifying process-death survival, SQLite transaction rollback, and reboot receiver restoration.
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §7.1
  - *Principal Dependencies:* `MOB-DATA-001`, `MOB-SCHED-005`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VERIFY-003`**: L3 Android Emulator Matrix Verification
  - *Scope:* Configure automated emulator test matrix across API 29 (baseline), API 33 (notifications), and API 34 (exact alarms, Doze testing).
  - *Responsibility:* Mobile
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §7.1
  - *Principal Dependencies:* `MOB-SCHED-003`, `MOB-SYNC-001`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VERIFY-004`**: L4 Host ↔ Mobile Network & Sync Integration Suite
  - *Scope:* Implement end-to-end integration tests between Mobile Companion and live PC Runtime verifying pairing, delta sync, conflict detection, and revocation.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §7.1, [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) §4
  - *Principal Dependencies:* `MOB-SYNC-005`, `MOB-CONTRACT-004`
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

- **`MOB-VERIFY-005`**: L5 Physical Device Mobile Golden Acceptance Journey (MG1–MG12)
  - *Scope:* Execute the full 12-group Mobile Golden Acceptance journey on physical reference Android devices, recording formal verification evidence.
  - *Responsibility:* Both
  - *Architectural Owner:* [`mobile-capabilities-and-runtime.md`](../../04_Infrastructure/mobile-capabilities-and-runtime.md) §8
  - *Principal Dependencies:* All MOB streams
  - *Implementation State:* `APPROVED TARGET / NOT STARTED`

---

## 3. Explicit Mobile V1 Non-Goals (Deferred / Post-V1)

The following capabilities are explicitly **excluded** from Mobile V1 WBS deliverables:
1. **Health Connect & Wearables (`Mobile Later`):** Real Health Connect integration (`androidx.health.connect`) and biometric synchronization are deferred post-V1. Prototype mock UI is sequestered.
2. **Autonomous Local Routines (`Mobile Later`):** Autonomous local routine execution is deferred post-V1; cached read-only view offline only.
3. **Local On-Device VLM / Vision Inference (`Post-V1 Candidate`):** Local vision inference is excluded from Mobile V1. Turn attachment capture and upload to PC Host is supported; local vision execution requires a future architectural decision.
4. **Always-On Wake Word Detection (`Mobile Later`):** Continuous background wake-word listening is prohibited on mobile in V1.
5. **In-App Public Model Hub / Catalog Downloads (`Post-V1 Candidate`):** In-app browsing and downloading from online model hubs is deferred; V1 uses LAN Host-to-Device model transfer.
6. **Shared Master Database Secrets (`Permanently Rejected`):** Distributing master database encryption keys or master API secrets to mobile satellite endpoints is permanently rejected.
