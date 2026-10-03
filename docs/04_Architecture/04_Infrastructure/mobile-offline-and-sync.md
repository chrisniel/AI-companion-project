# Mobile Offline, Synchronization, and Android Background Architecture

> **Document Role:** Canonical infrastructure and behavior specification for Mobile Companion offline capabilities, synchronization, and Android background delivery.  
> **Status:** Active Canonical — Mobile Architecture Batch B Approved  
> **Authority Precedence:** This specification governs Mobile synchronization, offline persistence semantics, and platform background execution limits. It operates under the cross-cutting boundaries defined in [`MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md). Entity schemas and domain truth remain owned by the shared domain specifications (such as [`tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md) and [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md)).

---

## 1. Justification & Boundary

This focused specification defines the offline behavior, local persistence semantics, replication protocols, conflict reconciliation rules, and Android platform execution boundaries for the Mobile Companion.

A dedicated specification is architecturally justified because:
1. **Cross-Cutting Scope:** Synchronization protocols, offline mutation durability, and conflict classes span multiple domains (Tasks, Reminders, Alarms, Conversations, Memory, Settings). Distributing these rules across six separate domain specs would fragment the replication model.
2. **Platform Realities:** Background execution guarantees, exact alarm permissions, Doze modes, and OS notification behavior are Android-specific execution realities. Embedding them in PC-centric domain architecture would pollute shared domain specifications.
3. **Reference Integrity:** This document provides a single normative authority for all mobile offline failure modes while cross-referencing domain truth in canonical owners.

---

## 2. B1: Local Persistence Semantics & State Classification

Mobile local state is partitioned into strict durability, security, and lifecycle classes:

### 2.1 State Classification Matrix

| State Category | Examples | Durability Requirement | Protection / Storage Boundary | Revocation Lifecycle | Offline Availability |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Authoritative Local Device State** | Enrolled Device ID, device pairing token, device credential material | Survives process death, app restart, and device reboot | **Platform-Protected Secure Storage** (Android Keystore-backed storage) | **Invalidated immediately** upon authoritative `DEVICE_REVOKED` outcome | Available locally (identifies endpoint) |
| **Device-Local Settings** | Local UI theme, local notification sounds, local vibration toggles | Survives process death, app restart, and device reboot | Private application sandbox | **Preserved** across revocation (device-specific preference) | Available & writable offline |
| **Device-Local Third-Party Secrets** | User-configured OpenAI/Anthropic API keys configured on device | Survives process death, app restart, and device reboot | **Platform-Protected Secure Storage** (Android Keystore-backed storage) | **Preserved** (Host device revocation MUST NOT erase unrelated 3rd-party user keys) | Available locally |
| **Replicated Domain Replica** | Synced Tasks, active Reminders, scheduled Alarms | Survives process death, app restart, and device reboot | Private application sandbox (Relational store) | **Quarantined** on `PROFILE_INACTIVE`; **Erased** on `DEVICE_REVOKED` or `PROFILE_PURGED` | Available offline (domain-specific write permissions apply) |
| **Pending Mutation Journal (Outbox)** | Queued task creations, task completion updates (`SET_COMPLETION`), alarm dismissals | Survives process death, app restart, and device reboot | Private application sandbox (Transactional journal) | **Discarded** upon authoritative `DEVICE_REVOKED` outcome | Durable until host acknowledgment |
| **Disconnected Conversation Working State** | Disconnected user turns, generated assistant responses (`MOBILE_LOCAL_INFERENCE` or `MOBILE_CLOUD_INFERENCE`), turn provenance metadata | Survives process death, app restart, and device reboot (committed in local SQLite store until synced or resolved) | Private application sandbox (Relational store / Outbox) | **Discarded / Erased** upon `DEVICE_REVOKED` or `PROFILE_PURGED` | Locally writable on qualified devices with approved local LLM or authorized Cloud LLM (pending Host reconciliation per §3.2.6); read-only fallback when neither is available |
| **Synchronization Metadata** | Monotonic change cursor, entity revision vectors, last-sync time | Survives process death, app restart, and device reboot | Private application sandbox | **Reset / Cleared** upon `DEVICE_REVOKED` or full re-baseline | Internal engine state |
| **Cached / Read-Only History** | Host-synchronized conversation history, retrieved memories, character profiles | Survives process death and restart; safely evictable on storage pressure | Private application sandbox (Cache store) | **Evicted / Erased** upon `DEVICE_REVOKED` or `PROFILE_PURGED` | Read-only replica offline (or when disconnected without local/cloud inference) |
| **Transient UI State** | Active text input, scroll offsets, navigation stack | Discarded on process death (unless saved via Flutter state restoration) | Volatile memory | Discarded | UI-only |

### 2.2 Storage Architecture & Recommendations

- **Architectural Requirement:** Pending offline mutations and replicated domain state MUST survive OS process death and device reboot. Storing pending mutations solely in in-memory state flows (as found in the mobile prototype) violates durability invariants.
- **Implementation Pattern:** A **transactional mutation journal (outbox)** pattern is required. Local optimistic mutations MUST be committed atomically with local replica updates in a durable local store before dispatching over the network.
- **Storage Technology Recommendation:** A relational SQLite-backed abstraction (such as Drift for Flutter) is recommended for replicated domain entities, outbox mutations, and sync metadata due to transaction support and structured query capabilities. Plaintext `SharedPreferences` for tokens or task state is strictly prohibited.
- **Security Boundary Truth:** Platform-protected secure storage backed by the **Android Keystore** is required for device credentials and third-party API secrets. The deprecated AndroidX `EncryptedSharedPreferences` library is not recommended. Replicated domain state resides within the private OS application sandbox, which provides the platform-enforced isolation baseline (`mobile-capabilities-and-runtime.md` §5.2). Full-database encryption (e.g., SQLCipher) remains optional and threat-model dependent (e.g., for rooted devices or heightened enterprise compliance) rather than an unconditional baseline mandate for standard non-rooted devices.

---

## 3. B2: Per-Domain Synchronization & Reconciliation Architecture

The PC Local AI Runtime remains canonical domain authority. Mobile acts as an enrolled Satellite replica. Synchronization is asymmetric and defined per domain.

### 3.1 Complete Per-Domain Synchronization Matrix

| Domain | Canonical Authority | Offline Readable? | Offline Writable? | Durable Locally? | Sync Direction | Deletion Policy | Conflict Class | Cross-Batch Lifecycle / Final Disposition |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Tasks** | PC Runtime | YES | YES (create, update, set completion status, delete) | YES (DB + Outbox) | Bidirectional | Host soft-delete; Tombstones propagated | Host-mediated revision check; reject stale base revision by default; semantic desired-state updates (`SET_COMPLETION`) handled | None |
| **Reminders** | PC Runtime | YES (synced occurrences) | LIMITED (Ack / Dismiss / Snooze only; no canonical entity creation) | YES (DB + Outbox) | Asymmetric (PC pushes schedule; Mobile reports delivery/snooze) | Host manages lifecycle; Mobile dismiss marks local state | State-machine transition; Host tie-breaker | None |
| **Alarms** | PC Runtime | YES (synced occurrences) | LIMITED (Dismiss / Snooze only; canonical recurring alarm config is PC-owned) | YES (DB + Outbox) | Asymmetric (PC pushes schedule; Mobile reports delivery/snooze) | Host manages lifecycle; Mobile dismiss marks local state | State-machine transition; local user dismiss always accepted | None |
| **Routines** | PC Runtime | YES (cached view) | NO (read-only view; no offline creation/edits) | YES (Cache) | Host to Mobile | PC-managed | None (PC exclusive authority) | [RESOLVED] Autonomous local execution deferred post-V1 (Mobile Later); cached view only offline |
| **Conversations / History** | PC Runtime (Host) / Mobile (Disconnected Turns) | YES (cached turns) | QUALIFIED (offline local text turns on qualified devices with approved local LLM, or optional cloud text turns when explicitly authorized/configured; read-only replica when neither is available) | YES (DB + Outbox) | Bidirectional (disconnected turns import to Host with local or cloud inference provenance) | PC-managed; soft-delete cascade | Causal turn append (preserves turn order; no Host tool replay or PC LLM regeneration) | [RESOLVED] Qualified devices support offline local text turns; optional cloud turns supported when authorized; cached view remains read-only when neither is available (see §3.2.6) |
| **Memory** | PC Runtime | YES (cached view) | NO (read-only view; memory extraction is PC policy-driven) | YES (Cache) | Host to Mobile | PC-managed; forget tombstones | None (read-only replica) | None |
| **Character / Persona** | PC Runtime | YES (cached instance) | NO (templates and instances are PC-managed) | YES (Cache) | Host to Mobile | PC-managed | None (read-only replica) | None |
| **Profile Settings** | PC Runtime | YES (cached view) | NO (Profile admin is PC-only) | YES (Cache) | Host to Mobile | PC-managed | None (read-only replica) | None |
| **Device-Local Settings** | Mobile Endpoint | YES | YES (all device preferences) | YES (Local prefs) | None (Device-local only) | Local reset | None (device-authoritative) | None |
| **Media & Attachments** | PC Runtime | YES (cached files) | LIMITED (captured local media held pending turn upload) | YES (Sandbox files) | Asymmetric (fetch on demand; upload on turn) | PC-managed; file cleanup | None | [RESOLVED] [IMPLEMENTATION OPEN / POST-V1 CANDIDATE] (local VLM inference excluded from Mobile V1; local media capture and upload to PC Host supported; future local vision inference remains unscheduled and requires a separate decision; turn attachment upload only) |

### 3.2 Concurrency, Entity Identity & Revision Architecture

Universal client-timestamp Last-Write-Wins (LWW) is **rejected**. Mobile wall clocks are untrusted, user-manipulable, and susceptible to skew, timezone shifts, and clock resets.

#### 3.2.1 Stable Offline Entity Identity & Dependency Strategy
To ensure that an offline-created entity (such as a Task) can be subsequently edited, updated, or deleted offline before the Host ever acknowledges creation:
- **Strategy Choice (Approach A):** **Client-generated stable entity IDs (UUIDv4)** accepted by the Host for offline-creatable entities.
- **Contract Boundary & Target Requirement:** Current backend `TaskCreate` does NOT accept a client-provided Task ID. Accepting a client-generated stable identity is therefore an **explicit target contract requirement**, not implemented reality.
- **Creation Semantics:** Offline CREATE uses the client-generated permanent `entity_id`. Because a CREATE operation has no pre-existing Host revision, its base revision is conceptually represented as `NONE` / `NOT_YET_CREATED` rather than inventing an artificial integer revision.
- **Causal Ordering & Dependency Resolution:** While a stable `entity_id` establishes uniform entity identity across offline operations, mutations against an entity whose CREATE has not yet been acknowledged by the Host MUST preserve causal ordering. The local mutation journal must either:
  1. *Coalesce* subsequent local edits into the pending CREATE mutation record where safe; or
  2. Preserve an *explicit per-entity dependency/order* ensuring the CREATE mutation reaches and commits on the Host before any dependent UPDATE or DELETE operations are processed.
- **Retry Idempotency:** Retrying a CREATE operation over the network uses the identical `entity_id` and `mutation_id`, preventing duplicate entity creation on the Host.
- **Separation of Concerns:** `entity_id` uniquely identifies the domain entity throughout its lifetime. `mutation_id` (Idempotency Key) uniquely identifies each individual operational mutation attempt in the mutation journal.

#### 3.2.2 Host-Issued Entity Revisions & Optimistic Concurrency Control
1. **Host-Issued Entity Revisions:** Every synchronizable entity on the PC Host maintains a monotonic integer revision (`revision: int`) or host-issued monotonic revision token. The revision increments on every committed update on the Host.
2. **Base Revision Tracking:** When Mobile replicates an entity, it stores the current `server_revision`. When Mobile enqueues a mutation against an existing entity, the outbox record records `base_revision = server_revision`.
3. **Optimistic Concurrency Control:** When Mobile submits an update or delete mutation to the Host:
   - If Host `current_revision == mutation.base_revision`: Mutation commits cleanly; Host increments `revision = current_revision + 1`.
   - If Host `current_revision > mutation.base_revision`: Host detects a concurrent modification.

#### 3.2.3 Deterministic Conflict Policy (No Unproven Field Merging)
For Mobile V1, generic automatic field-level merging is **rejected** because a stale `base_revision` alone does not convey sufficient baseline change evidence to guarantee disjoint updates without silent data loss.
- **Default Rule:** Any update mutation submitted against a stale `base_revision` (`current_revision > base_revision`) results in a **Conflict Outcome** (`CONFLICT_DETECTED`).
- **Conflict Handling:** The Host rejects the stale mutation and returns the current authoritative entity state. Mobile retains the user's uncommitted edit in a local conflict/draft state, prompting user resolution (e.g. keep server version or overwrite with new revision).
- **Idempotent Desired-State Semantic Operations:** A toggle operation is not inherently idempotent. The architecture requires explicit desired-state semantic operations, such as:
  - `SET_COMPLETION(completed=true|false)`
  - or conceptually equivalent `SET_TASK_STATUS(desired_status)`
  Repeated execution of the same semantic desired-state mutation produces the identical result. If an update only asserts a desired status or completion state, the Host may apply that state idempotently if the entity still exists and is not soft-deleted.
- **Offline Deletes:** If Mobile submits a delete referencing a stale `base_revision` where substantive content was modified on the Host, the delete is rejected as a conflict, presenting the modified entity to the user.

#### 3.2.4 Mutation Identity & Target Idempotency
- Every mutation in the Mobile mutation journal MUST carry a unique UUID `mutation_id` (Idempotency Key).
- *Target Contract Requirement:* Host write endpoints must accept and deduplicate `mutation_id` within a database transaction. On retry with an identical `mutation_id`, Host detects prior commitment and returns the committed result without re-executing.
- *Current Implementation Reality:* Conversation turns currently implement `client_message_id` with database unique constraints (`uq_messages_conversation_client_message_id`). Backend Task endpoints currently lack idempotency keys; this is an architectural target requirement, not implemented reality.

#### 3.2.5 Change Discovery & Re-Baseline
- **Monotonic Sync Cursor:** Delta synchronization relies on a Host-issued monotonic change cursor (sequence token or change tracking log) provided by the Host during sync. Mobile requests changes occurring after that cursor.
- **Bounded Change-History Retention:** The Host maintains a bounded synchronization/change-history retention policy sufficient for delta sync and deletion-resurrection prevention.
- **Decoupling from Trash Retention:** The synchronization change-history retention horizon is architecturally **distinct from user-facing recycle-bin retention** (e.g. `DATA_RETENTION_DAYS = 30` in the current Task model is domain-specific implementation evidence only, not a universal synchronization retention rule). The exact duration of synchronization history retention remains policy/implementation open until Mobile planning.
- **Stale Cursor Re-Baseline:** If a Mobile client presents a cursor that falls outside the retained authoritative synchronization history, the Host returns the typed semantic outcome `STALE_CURSOR`. Mobile MUST perform the approved full re-baseline flow: clear the local replicated domain database, reset sync metadata, and fetch a complete snapshot from the Host.

#### 3.2.6 Disconnected & Offline Conversation Persistence and Reconciliation Architecture
To resolve the boundary between disconnected conversational assistance (device-local inference or direct optional cloud inference per `mobile-capabilities-and-runtime.md` §2.1, §3.2) and Host-authoritative conversation history (`assistant-and-conversations.md` §2.2):

1. **Execution Modes & Input Gating (`OFFLINE_LOCAL` vs `OPTIONAL_CLOUD` vs Read-Only Fallback):**
   - **Offline Local Inference (`OFFLINE_LOCAL`):** On evidence-qualified Tier 2 and Tier 3 devices with an approved mobile model artifact installed, Mobile supports offline local text conversational assistance.
   - **Optional Cloud Inference (`OPTIONAL_CLOUD`):** On any device tier (including Tier 0 and Tier 1 devices), when the PC Host is unavailable but internet connectivity is active, Mobile supports direct Cloud LLM conversational assistance if Cloud LLM permission is explicitly enabled by the user and provider API credentials are configured locally in Android Keystore.
   - **Truthful Read-Only Fallback & Input Guard:** When neither the PC Host, a qualified local LLM (`OFFLINE_LOCAL`), nor an authorized Cloud LLM (`OPTIONAL_CLOUD`) is available, conversation history operates strictly as a **durable read-only cache**. Turn submission is locked until connectivity to the PC Runtime, local inference capability, or authorized Cloud provider is established. Conversation input is NOT locked merely because the device is disconnected from the PC Host if an authorized Cloud LLM path is available.
2. **Stable Disconnected Conversation Identity:**
   - Conversations created by Mobile while disconnected from the Host generate a stable client-side UUID `conversation_id`.
   - *Target Contract Requirement (Not Implemented):* Host conversation creation endpoints currently do not accept a client-generated `conversation_id`. Accepting and registering client-generated conversation identities upon sync is an explicit **TARGET CONTRACT REQUIREMENT (NOT IMPLEMENTED)**.
3. **Turn Identity & Idempotency:**
   - Every user message submitted generates a client UUID `client_message_id`.
   - *Implemented Reality Evidence:* The current PC backend already enforces `client_message_id` uniqueness on the `messages` table within conversation scope (`uq_messages_conversation_client_message_id`), preventing duplicate message insertion.
   - *Target Contract Requirement (Not Implemented):* A dedicated batch turn sync/import endpoint on the Host (accepting a sequence of disconnected turns in a single transactional request) is an explicit **TARGET CONTRACT REQUIREMENT (NOT IMPLEMENTED)**.
4. **Assistant Response Provenance (Local & Cloud Inference):**
   - Assistant responses generated while the PC Host is unavailable are committed locally with explicit provenance metadata distinguishing execution origin:
     - `MOBILE_LOCAL_INFERENCE`: Generated via device-local SLM runtime (metadata includes `device_id: UUID`, `model_tag: string`, generation metrics).
     - `MOBILE_CLOUD_INFERENCE`: Generated via direct Mobile-to-Cloud provider API call (metadata includes `device_id: UUID`, `provider: string`, `model: string` without any API keys or provider secrets).
   - *Target Contract Requirement (Not Implemented):* Storing assistant turn provenance fields (`source: MOBILE_LOCAL_INFERENCE | MOBILE_CLOUD_INFERENCE`, `device_id: UUID`, `provider_tag: string`, `model_tag: string`, generation metrics) on the Host `messages` schema is an explicit **TARGET CONTRACT REQUIREMENT (NOT IMPLEMENTED)**; current schema stores standard message records without client provenance metadata.
   - On synchronization, the Host imports and stores the dialogue turn as an authoritative historical record.
   - **No Host LLM Regeneration:** The Host MUST NOT replay or re-generate synchronized assistant responses through the PC language model upon import.
   - **No Provider Secrets in Provenance:** Provenance metadata MUST NOT expose raw API keys, tokens, or credentials.
5. **Tool Side Effects & Safety Isolation (Decision D9 Cloud Boundary):**
   - Disconnected conversational generation (whether `MOBILE_LOCAL_INFERENCE` or `MOBILE_CLOUD_INFERENCE`) MUST NOT fabricate or execute Host desktop tools.
   - **Cloud Tool Safety Boundary:** In accordance with Decision D9, Cloud inference permission is strictly conversational and does NOT grant Host desktop tool authority or generic cloud-agent execution authority.
   - Disconnected conversational turns synchronize strictly as textual dialogue history. No PC tool invocations, system actions, or side effects are triggered or replayed on the Host merely because an offline or cloud-generated conversation turn is imported.
   - Any independently approved local Mobile action (such as creating a Task via local UI) goes through its own deterministic capability path, is committed to the local Task outbox independently, and follows the Task synchronization pipeline (§3.1).
6. **Causal Ordering & Concurrent Turn Reconciliation:**
   - Turns within a disconnected session maintain strict local causal ordering.
   - *Non-Conflicting Append:* If the thread was not modified on the Host while Mobile was disconnected, turns append sequentially, receiving monotonic Host `sequence_no` assignments.
   - *Concurrent Thread Append Reconciliation:* If both the Host and Mobile concurrently appended turns to the same conversation thread while disconnected, **Mobile wall-clock Last-Write-Wins (LWW) is strictly REJECTED**. Arbitrary timestamp interleaving risks corrupting multi-turn dialogue context.
   - Instead, the Host preserves its authoritative thread sequence while importing Mobile's disconnected turns as a distinct, causally branched dialogue segment or session, surfacing a clear thread indicator to the user. User-level branch inspection or thread merge decisions belong to future application UI design.
   - *Target Contract Requirement (Not Implemented):* Explicit conversation branch/segment metadata and non-destructive dialogue branch representations on the Host are **TARGET CONTRACT REQUIREMENTS (NOT IMPLEMENTED)**.
7. **Durable Local Persistence:**
   - All disconnected user turns and generated assistant responses (`MOBILE_LOCAL_INFERENCE` or `MOBILE_CLOUD_INFERENCE`) MUST be committed atomically to local SQLite storage before presentation or network queuing. Volatile in-memory holding is prohibited.
8. **Memory & Context Consumption Invariant:**
   - Mobile inference (local or cloud) may consume:
     - cached recent conversation context in the active thread;
     - cached Character/persona definitions;
     - cached read-only Profile and Character memories replicated from the Host.
   - **No Autonomous Local Memory Extraction:** Local Memory candidate extraction, autonomous memory creation, and memory database writes are **DISABLED** on Mobile in V1. Memory ownership and automatic extraction policies remain strictly Host-governed (`memory-and-personalization.md`). Reconnected conversation turns may be evaluated for memory extraction on the PC Host under canonical Host policies after synchronization.
9. **Canonical Ownership & Atomic Turn Invariants:**
   - *Active Profile Binding:* All client-imported conversation turns MUST belong to the active Profile bound to the pairing/enrolled Device credential. Request payloads cannot self-assert or override Profile ownership.
   - *Single Character Binding:* Disconnected conversation turns MUST belong to a single explicit `character_id`. Multi-character or unassigned offline persona dialogue is prohibited.
   - *Atomic Whole-Turn Unit Import:* Conversational history reconciliation is imported as a **whole turn unit** (user prompt + assistant response + timing/model provenance metadata) or rejected atomically. Partial turn imports (e.g. storing a user prompt while dropping the assistant answer, or importing an assistant response without its triggering prompt) are strictly rejected to prevent orphaned assistant answers or desynchronized dialogue contexts.

---

## 4. Resolution of the 10 Mandatory Synchronization Failure Cases

The architecture explicitly resolves all mandatory failure scenarios via typed outcomes:

### Case 1: Host commits mutation but Mobile loses response
- **Mechanism:** Mobile mutation remains in the durable outbox. When connectivity is restored, Mobile retries the request with the identical `mutation_id`.
- **Resolution:** Host detects that `mutation_id` was already applied, bypasses re-execution, and returns the committed entity state. Mobile marks the outbox item completed and purges it.

### Case 2: Mobile and PC modify the same Task while Mobile is offline
- **Mechanism:** Mobile submits an update with `base_revision = N`. PC has already committed an update bumping Host revision to `N + 1`.
- **Resolution:** Host detects `current_revision > base_revision` and returns a typed `CONFLICT_DETECTED` outcome with the current Host entity. Mobile preserves the user's local edit in a draft/conflict state and prompts user resolution. (If the Mobile mutation was an explicit idempotent desired-state update like `SET_COMPLETION(completed=true)` and non-conflicting, Host applies the state idempotently).

### Case 3: Mobile deletes an item offline while PC modifies it
- **Mechanism:** Mobile enqueues a `DELETE` mutation referencing `base_revision = N`. PC modified the item while Mobile was offline (`revision = N + 1`).
- **Resolution:** Because substantive content changed on PC, Host rejects the delete with `CONFLICT_DETECTED` and returns the updated task. The task is restored/shown on Mobile with a notice ("Item was modified on PC before deletion"). If the user confirms deletion, a fresh delete referencing the new revision is submitted.

### Case 4: A Device reconnects after several weeks
- **Mechanism:** Mobile presents a sync cursor older than the Host's retained authoritative synchronization history horizon.
- **Resolution:** Host returns a typed `STALE_CURSOR` outcome. Mobile initiates the approved full re-baseline: local replicated domain tables are cleared and repopulated via full snapshot download. Unflushed outbox items with expired base revisions are quarantined for user review.

### Case 5: PC revokes the Device while it is offline
- **Mechanism:** PC Admin revokes the Device on the host. Mobile remains offline, continuing local read/write operations against cached data.
- **Resolution:** Upon reconnection, the Host returns a typed `DEVICE_REVOKED` outcome. Mobile executes authoritative revocation cleanup:
  1. Authenticated host operations halt immediately.
  2. The local Device credential material is invalidated and cleared.
  3. Pending outbox mutations are cancelled and cleared.
  4. Replicated Profile domain data is purged (Local Data Erasure).
  5. Unrelated device-local third-party API keys (e.g. user-entered OpenAI keys) are **preserved**.
  6. Mobile transitions to an un-enrolled setup state.

### Case 6: Bound Profile is soft-deleted while Device is offline
- **Mechanism:** PC Admin initiates Profile soft-delete (entering the 7-day recovery window). Mobile reconnects.
- **Resolution:** Host returns a typed `PROFILE_INACTIVE` outcome. Mobile does NOT execute destructive local erasure. Instead, Mobile enters a **quarantined/disabled mode**: UI displays "Profile Inactive / Soft-Deleted", local mutations are paused, and access is locked. If PC Admin restores the Profile within 7 days, subsequent authentication succeeds and normal sync resumes.

### Case 7: Bound Profile reaches hard purge while Device is offline
- **Mechanism:** The 7-day recovery window expires and the Host permanently purges the Profile. Mobile reconnects.
- **Resolution:** Host returns a typed `PROFILE_PURGED` outcome. Mobile treats this as permanent destruction: all local replicated Profile records, caches, and pending mutations are permanently deleted. The device resets to fresh enrollment.

### Case 8: Mobile app is reinstalled and loses local synchronization metadata
- **Mechanism:** User uninstalls and reinstalls the app. Local database, secure keystore entries, and outbox are wiped by the OS.
- **Resolution:** The reinstalled app has no credentials or sync metadata. It cannot silently assert old device authority. Mobile must undergo fresh pairing and enrollment. The PC Host issues a new Device record with new independent credential material. The previous device record remains orphaned on the Host until PC Admin revokes it. The new device performs a full initial sync.

### Case 9: Two retries arrive after a network timeout
- **Mechanism:** Request 1 times out from Mobile's perspective but reaches the server. Request 2 is dispatched. Both arrive concurrently at the Host.
- **Resolution:** Both requests carry the identical `mutation_id`. The Host wraps mutation processing in a database transaction with a unique constraint on `mutation_id`. The first transaction commits; the second detects the existing `mutation_id`, skips duplicate execution, and returns the committed response.

### Case 10: Mobile local clock is wrong
- **Mechanism:** Mobile system time is manually set into the past or future, or has skewed significantly.
- **Resolution:** Host does NOT use Mobile timestamps for revision ordering, conflict resolution, or database `updated_at` timestamps. The Host uses its own authoritative UTC clock for commit times and monotonic integer revisions for concurrency. Mobile timestamps are treated solely as client advisory metadata.

---

## 5. B3: Android Background Execution Responsibilities

Android enforces strict background execution limits, process death, Doze modes, and App Standby buckets. Mobile architecture partitions responsibilities strictly against platform guarantees:

### 5.1 Responsibility Mapping

| Function | Execution Class | Android Platform Mechanism | Platform Guarantees & Limits |
| :--- | :--- | :--- | :--- |
| **Outbox Mutation Flush** | Opportunistic / Deferrable | `WorkManager` (Constraint: `NetworkType.CONNECTED`) | Guaranteed eventual execution across process death and reboots. Batched by OS; subject to Doze maintenance windows. NOT exact-time. |
| **Periodic Background Delta Sync** | Opportunistic / Periodic | `WorkManager` (PeriodicWorkRequest, min 15m) | Runs periodically when device conditions permit. Defers during deep Doze. |
| **Scheduled Alarm Delivery** | Exact Time / Time-Critical | `AlarmManager.setAlarmClock()` | Fires at precise wall-clock time even in deep Doze. Requires explicit permission. |
| **Scheduled Reminder Delivery** | Inexact / Tolerant | `AlarmManager.setAndAllowWhileIdle()` or inexact `set()` | Fires near scheduled time; OS may batch within Doze windows. Gracefully degrades. |
| **User-Visible Long-Running Work** | Continuous Long-Running | Foreground Service (FGS) where permitted by Android | User-visible notification required. Permitted only during active, user-visible operations. Voice foreground service lifecycle, type declaration (`FOREGROUND_SERVICE_MICROPHONE`), while-in-use constraints, and permission requirements are resolved in [`mobile-capabilities-and-runtime.md`](./mobile-capabilities-and-runtime.md) §3.4. |

### 5.2 Foreground Service Boundaries

- **Background Sync Restriction:** Continuous Foreground Services (FGS) for ordinary background synchronization or outbox processing are **STRICTLY PROHIBITED**. Using persistent foreground notifications to keep sync sockets alive violates mobile battery guidelines and Android platform expectations.
- **User-Visible Continuous Operations:** User-visible continuous operations may require Android foreground execution depending on the approved feature. Voice foreground-service type, microphone lifecycle, while-in-use restrictions, and permission requirements are resolved in [`mobile-capabilities-and-runtime.md`](./mobile-capabilities-and-runtime.md) §3.4 (requiring base `FOREGROUND_SERVICE`, type-specific `FOREGROUND_SERVICE_MICROPHONE`, runtime `RECORD_AUDIO`, and visible foreground UI initiation).

---

## 6. B4: Reminders, Alarms, and Notification Delivery Architecture

Preserving Decision D10 and `ADR-0011`, the PC Local AI Runtime `SchedulerService` remains canonical scheduler truth. Mobile functions as a local presentation and delivery client.

### 6.1 Replicated Occurrence State & Recurrence

- **Precomputed Occurrences:** The PC Runtime computes scheduled occurrence events and replicates them to Mobile as concrete occurrence instances (`occurrence_id: UUID`, `entity_id: UUID`, `trigger_time_utc: datetime`, `type: ALARM | REMINDER`, `metadata: dict`).
- **Autonomous Recurrence Metadata (Floating Time):**
  - *Fixed-Instant Events:* Stored as invariant UTC timestamps.
  - *Floating Local-Time Recurrence (e.g. "9 AM wherever I am"):* Mobile receives bounded recurrence rule metadata (e.g. `local_time: 09:00`, active days) for active alarms. If Mobile changes timezones while disconnected, it recalculates the trigger time in the new local timezone locally.

### 6.2 Android Alarm Platform Lifecycle & Permissions

Exact alarm scheduling on Android is strictly conditional and NOT an unconditional guarantee:

1. **Permission Separation:**
   - `SCHEDULE_EXACT_ALARM`: User-revocable special app access (Android 12+, API 31+). Default denied on Android 13/14+ for newly installed general applications.
   - `USE_EXACT_ALARM`: Restricted permission limited by Google Play policy to core clock/timer apps. The Companion app CANNOT assume Google Play approval for `USE_EXACT_ALARM` and must support `SCHEDULE_EXACT_ALARM`.
2. **Permission Lifecycle & Active Verification:**
   - `SCHEDULE_EXACT_ALARM` may be granted or revoked by the user/system at any time. When revoked, Android automatically cancels all future exact alarms and may terminate the app process.
   - **No Revocation Broadcast Dependency:** Architecture must NOT depend on receiving a revocation broadcast. Broadcast `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` is delivered when permission is granted.
   - **Active Verification:** Mobile MUST explicitly check `AlarmManager.canScheduleExactAlarms()` before scheduling/re-arming exact alarms and when entering relevant lifecycle states (app foregrounding, boot completion, work execution).
   - When access becomes available again, Mobile reschedules still-valid occurrences from durable local state.
3. **Notification Runtime Permission (`POST_NOTIFICATIONS`):**
   - Required on Android 13+ (API 33+).
   - If denied, OS suppresses status bar notifications and alert heads-up displays.
4. **Full-Screen Intent Restrictions (`USE_FULL_SCREEN_INTENT`):**
   - On Android 14+, `USE_FULL_SCREEN_INTENT` is restricted; Google Play policy limits default eligibility primarily to calling and alarm apps.
   - Full-Screen Intent is NOT a reliable bypass for missing notification permissions.
5. **Truthful Degraded Capability States:**
   - If exact alarm permission is missing (`!canScheduleExactAlarms()`): Alarms are marked **DEGRADED / UNARMED LOCALLY**; WorkManager is NOT claimed to provide alarm fidelity.
   - If notification permission is missing (`POST_NOTIFICATIONS` denied): Visual heads-up and status bar notifications are **SUPPRESSED**; UI must display an explicit permission warning.
   - If full-screen intent is denied: Companion CANNOT guarantee wake-over-lockscreen presentation.
   - Reminders degrade gracefully to inexact alarms or WorkManager notifications.

### 6.3 Idempotent Occurrence State Machine & Cross-Device Presentation

#### 6.3.1 Idempotent Occurrence State Machine
Alert occurrences are governed by an idempotent, revision-aware state machine rather than an irreversible monotonic sequence:
- **States:**
  - `SCHEDULED` (Pending initial trigger)
  - `TRIGGERED` (Local alarm actively firing/ringing)
  - `ACKNOWLEDGED` / `DISMISSED` (User explicitly dismissed the alert)
  - `SNOOZED` / `RE_ARMED` (User snoozed; re-armed with updated `snooze_until_utc`)
  - `CANCELED` (Parent task/alarm deleted or disabled)
  - `MISSED` (Trigger time elapsed while device was off or in un-alarmed state)
- **Snooze Semantics:** Snoozing mutates the active occurrence state to `SNOOZED`, computes a new `snooze_until_utc`, and re-arms a one-shot exact alarm. It does NOT duplicate the parent entity.
- **Idempotency:** Repeated duplicate dismiss or acknowledgment operations from retries or concurrent taps are safe and no-op.

#### 6.3.2 Cross-Device Presentation Semantics
- **Single-Device Duplicate Prevention:** An occurrence is presented at most once on a given device. Once triggered locally, local state transitions to `TRIGGERED` to prevent repeated local firing.
- **No Unsafe First-Delivery-Wins:** The architecture does NOT permit passive alert display on one device (e.g. PC displaying a toast notification) to silently cancel or disarm an active alarm on Mobile. (An unattended PC displaying a toast must not silence a user's phone alarm).
- **Cross-Device Dismissal:** Cross-device suppression occurs ONLY when:
  1. The user explicitly dismisses or snoozes the occurrence on one device, committing an acknowledgment mutation that syncs to other devices; or
  2. The Host explicitly assigns exclusive presentation targeting to a specific device.

### 6.4 System Lifecycle Events

- **Device Reboot (`ACTION_BOOT_COMPLETED`):** The OS clears all scheduled alarms on reboot. Mobile registers a broadcast receiver to read active alarms from the local database, verify `canScheduleExactAlarms()`, and re-register them with `AlarmManager`.
- **Timezone Change (`ACTION_TIMEZONE_CHANGED`):** Mobile recalculates floating-time alarms and reschedules `AlarmManager` intents.
- **Manual Clock Change (`ACTION_TIME_CHANGED`):** Mobile re-evaluates all pending alarms against current system time.
- **Missed Events:** Occurrences whose trigger time passed while the device was powered off are classified as `MISSED` on startup. Alarms show an explicit "Missed Alarm" banner; Reminders bundle into a catch-up notification summary.

---

## 7. Device Revocation, Profile Soft-Delete, and Hard-Purge

Authorization revocation and data erasure are strictly distinct architectural events governed by typed outcomes:

```
+-----------------------------------------------------------------------------------+
| TYPED OUTCOME        | HOST ACTION             | MOBILE DISCOVERY ACTION          |
+-----------------------------------------------------------------------------------+
| DEVICE_REVOKED       | Invalidate device token | Wipe device token & replica DB;  |
|                      | Reject mutations        | PRESERVE 3rd-party user API keys |
+-----------------------------------------------------------------------------------+
| PROFILE_INACTIVE     | Disable profile access  | Quarantine local replica;        |
| (7-day recovery)     | Reject mutations        | Lock UI; preserve for recovery   |
+-----------------------------------------------------------------------------------+
| PROFILE_PURGED       | Destroy profile data    | Permanent Local Data Erasure;    |
| (Permanent)          | Reject authentication   | Full client reset                |
+-----------------------------------------------------------------------------------+
| STALE_CURSOR         | Reject delta cursor     | Full re-baseline of domain store;|
|                      | Keep enrollment         | Keep device credentials valid    |
+-----------------------------------------------------------------------------------+
| CREDENTIAL_EXPIRED / | Require re-auth / token | Pause sync; prompt re-auth;      |
| ROTATION_REQUIRED    | rotation; preserve data | DO NOT erase local Profile data  |
+-----------------------------------------------------------------------------------+
```

- **Typed Trigger Rule:** Destructive local data erasure MUST NOT trigger on generic HTTP error codes (`401`, `403`, `404`, `410`). It requires an explicit, typed authoritative outcome (`DEVICE_REVOKED`, `PROFILE_PURGED`).
- **Remote Revocation:** Server-side revocation is instant on the Host. An offline Mobile device cannot know it is revoked until it establishes network contact.
- **Storage Sandbox Truth:** Android filesystem deletion removes database and cache files within the app sandbox. Cryptographic zeroization of flash storage is not an Android OS guarantee and must not be falsely claimed.
