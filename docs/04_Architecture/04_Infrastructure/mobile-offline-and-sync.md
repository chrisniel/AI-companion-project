# Mobile Offline, Synchronization, and Android Background Architecture

> **Document Role:** Canonical infrastructure and behavior specification for Mobile Companion offline capabilities, synchronization, and Android background delivery.  
> **Status:** Proposed Canonical — Mobile Architecture Batch B / Review Pending  
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
| **Authoritative Local Device State** | Enrolled Device ID, device pairing token, device private key | Survives process death, app restart, and device reboot | **Platform-Protected Secure Storage** (Android Keystore / EncryptedSharedPreferences) | **Invalidated immediately** upon discovered revocation | Available locally (identifies endpoint) |
| **Device-Local Settings** | Local UI theme, local notification sounds, local vibration toggles | Survives process death, app restart, and device reboot | Private application sandbox | **Preserved** across revocation (device-specific preference) | Available & writable offline |
| **Device-Local Third-Party Secrets** | User-configured OpenAI/Anthropic API keys configured on device | Survives process death, app restart, and device reboot | **Platform-Protected Secure Storage** | **Preserved** (Host device revocation MUST NOT erase unrelated 3rd-party user keys) | Available locally |
| **Replicated Domain Replica** | Synced Tasks, active Reminders, scheduled Alarms | Survives process death, app restart, and device reboot | Private application sandbox (Relational database) | **Quarantined / Erased** upon discovered revocation or hard-purge | Available offline (domain-specific write permissions apply) |
| **Pending Mutation Journal (Outbox)** | Queued task creations, task completion toggles, alarm dismissals | Survives process death, app restart, and device reboot | Private application sandbox (Transactional journal) | **Discarded** upon discovered revocation (cannot replay under revoked device) | Durable until host acknowledgment |
| **Synchronization Metadata** | High-water mark cursor, entity revision vectors, last-sync time | Survives process death, app restart, and device reboot | Private application sandbox | **Reset / Cleared** upon discovered revocation or full re-baseline | Internal engine state |
| **Cached / Read-Only History** | Recent conversation turns, retrieved memories, character profiles | Survives process death and restart; safely evictable on storage pressure | Private application sandbox (Cache store) | **Evicted / Erased** upon discovered revocation | Read-only view offline |
| **Transient UI State** | Active text input, scroll offsets, navigation stack | Discarded on process death (unless saved via Flutter state restoration) | Volatile memory | Discarded | UI-only |

### 2.2 Storage Architecture & Recommendations

- **Architectural Requirement:** Pending offline mutations and replicated domain state MUST survive OS process death and device reboot. Storing pending mutations solely in in-memory state flows (as found in the mobile prototype) violates durability invariants.
- **Implementation Pattern:** A **transactional mutation journal (outbox)** pattern is required. Local optimistic mutations MUST be committed atomically with local replica updates in a durable local store before dispatching over the network.
- **Storage Technology Recommendation:** A relational SQLite-backed abstraction (such as Drift for Flutter) is recommended for replicated domain entities, outbox mutations, and sync metadata due to transaction support and structured query capabilities. Plaintext `SharedPreferences` for tokens or task state is strictly prohibited.
- **Security Boundary Truth:** Platform-protected secure storage (Android Keystore) is required for device credentials and third-party API secrets. Replicated domain state resides within the private OS application sandbox; full-database encryption (e.g., SQLCipher) is not mandated in Batch B and is deferred to the Batch C security and threat-model review.

---

## 3. B2: Per-Domain Synchronization & Reconciliation Architecture

The PC Local AI Runtime remains canonical domain authority. Mobile acts as an enrolled Satellite replica. Synchronization is asymmetric and defined per domain.

### 3.1 Complete Per-Domain Synchronization Matrix

| Domain | Canonical Authority | Offline Readable? | Offline Writable? | Durable Locally? | Sync Direction | Deletion Policy | Conflict Class | Batch C Dependency |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Tasks** | PC Runtime | YES | YES (create, update, toggle complete, delete) | YES (DB + Outbox) | Bidirectional | Soft-delete on host (30-day trash); Tombstones propagated | Host-mediated revision conflict; deterministic field merge or reject stale base | None |
| **Reminders** | PC Runtime | YES (synced occurrences) | LIMITED (Ack / Dismiss / Snooze only; no arbitrary canonical creation) | YES (DB + Outbox) | Asymmetric (PC pushes schedule; Mobile reports delivery/snooze) | Host manages lifecycle; Mobile dismiss marks local state | Occurrence state monotonic transition; PC tie-breaker | None |
| **Alarms** | PC Runtime | YES (synced occurrences) | LIMITED (Dismiss / Snooze only; canonical recurring alarm config is PC-owned) | YES (DB + Outbox) | Asymmetric (PC pushes schedule; Mobile reports delivery/snooze) | Host manages lifecycle; Mobile dismiss marks local state | Monotonic state transition; local user dismiss always accepted | None |
| **Routines** | PC Runtime | YES (cached view) | NO (read-only view; no offline creation/edits) | YES (Cache) | Host to Mobile | PC-managed | None (PC exclusive authority) | OPEN FOR BATCH C (local execution disposition) |
| **Conversations / History** | PC Runtime | YES (cached turns) | NO (submitting turns offline is not supported in Batch B) | YES (Cache) | Host to Mobile | PC-managed; soft-delete cascade | None (read-only replica) | OPEN FOR BATCH C (local inference turns) |
| **Memory** | PC Runtime | YES (cached view) | NO (read-only view; memory extraction is PC policy-driven) | YES (Cache) | Host to Mobile | PC-managed; forget tombstones | None (read-only replica) | None |
| **Character / Persona** | PC Runtime | YES (cached instance) | NO (templates and instances are PC-managed) | YES (Cache) | Host to Mobile | PC-managed | None (read-only replica) | None |
| **Profile Settings** | PC Runtime | YES (cached view) | NO (Profile admin is PC-only) | YES (Cache) | Host to Mobile | PC-managed | None (read-only replica) | None |
| **Device-Local Settings** | Mobile Endpoint | YES | YES (all device preferences) | YES (Local prefs) | None (Device-local only) | Local reset | None (device-authoritative) | None |
| **Media & Attachments** | PC Runtime | YES (cached files) | LIMITED (captured local media held pending turn upload) | YES (Sandbox files) | Asymmetric (fetch on demand; upload on turn) | PC-managed; file cleanup | None | OPEN FOR BATCH C (vision input routing) |

### 3.2 Concurrency & Revision Architecture

Universal client-timestamp Last-Write-Wins (LWW) is **rejected**. Mobile wall clocks are untrusted, user-manipulable, and susceptible to skew, timezone shifts, and clock resets.

The synchronization concurrency model enforces:
1. **Host-Issued Entity Revisions:** Every synchronizable entity on the PC Host maintains a monotonic integer revision (`revision: int`) or host-issued monotonic revision token. The revision increments on every committed update on the Host.
2. **Base Revision Tracking:** When Mobile replicates an entity, it stores the current `server_revision`. When Mobile enqueues a mutation, the outbox record records `base_revision = server_revision`.
3. **Optimistic Concurrency Control:** When Mobile submits an update or delete mutation to the Host:
   - If Host `current_revision == mutation.base_revision`: Mutation is committed cleanly; Host bumps `revision = current_revision + 1`.
   - If Host `current_revision > mutation.base_revision`: Host detects a concurrent modification.
4. **Deterministic Conflict Resolution:**
   - **Tasks:**
     - *Status/Completion:* Monotonic transition (e.g. marked `completed` locally while edited on PC: Host applies completion state and merges non-overlapping edits).
     - *Conflicting Content Edits:* If title or notes were concurrently modified on Host while modified on Mobile, Host rejects the mutation with `409 CONFLICT` containing the current Host entity. Mobile preserves the user's local edit in a draft/conflict state and prompts user resolution, or performs deterministic field-level merging if edits touched non-overlapping fields.
   - **Reminders & Alarms (Occurrences):**
     - Occurrence delivery state transitions are monotonic (`PENDING` -> `TRIGGERED` -> `DISMISSED` / `SNOOZED`). Dismissal and acknowledgment operations always succeed deterministically; the Host accepts user dismissal regardless of base revision.
5. **Mutation Identity & Target Idempotency:**
   - Every mutation generated by Mobile MUST carry a client-generated UUID `mutation_id` (Idempotency Key).
   - *Current Implementation Truth:* Conversation turns currently implement `client_message_id` with database unique constraints (`uq_messages_conversation_client_message_id`). Backend Task endpoints currently lack idempotency keys. Batch B specifies a **target contract requirement** that Host write endpoints accept and deduplicate `mutation_id`.
   - On retry with an identical `mutation_id`, Host detects prior commitment and returns HTTP `200 OK` with the existing committed result without executing duplicate mutations.
6. **Change Discovery (Delta Synchronization):**
   - Delta synchronization relies on a **Host-issued monotonic synchronization cursor** (sequence token or change tracking log) provided by the Host during sync.
   - Mobile requests changes using `GET /api/v1/sync?cursor={cursor}`. Host returns all changes occurring after that cursor along with an updated `next_cursor`.
   - High-water mark, logical clocks, and sequence IDs are not interchangeable synonyms: the system requires a Host-managed monotonic change sequence.
7. **Stale Device Re-Baseline:**
   - The Host maintains tombstone records for a bounded retention window (aligned with `DATA_RETENTION_DAYS = 30`).
   - If a Mobile client presents a cursor older than the Host's tombstone retention horizon, the Host returns HTTP `410 GONE` (`STALE_CURSOR`).
   - Mobile MUST perform a **full re-baseline**: clear the local replicated domain database, reset sync metadata, and fetch a complete snapshot from the Host.

---

## 4. Resolution of the 10 Mandatory Synchronization Failure Cases

The architecture explicitly resolves all mandatory failure scenarios:

### Case 1: Host commits mutation but Mobile loses HTTP response
- **Mechanism:** Mobile mutation remains in the durable outbox. When connectivity is restored, Mobile retries the request with the identical `mutation_id`.
- **Resolution:** Host checks its idempotency journal, detects that `mutation_id` was already applied, bypasses re-execution, and returns the previously committed entity state with HTTP `200 OK`. Mobile marks the outbox item completed and purges it.

### Case 2: Mobile and PC modify the same Task while Mobile is offline
- **Mechanism:** Mobile submits an update with `base_revision = N`. PC has already committed an update bumping Host revision to `N + 1`.
- **Resolution:** Host detects `current_revision > base_revision`. If the changes affect disjoint fields (e.g. Mobile toggled completion status while PC edited category), Host deterministically merges the fields and increments to `N + 2`. If conflicting fields were modified (e.g. both modified title), Host rejects with `409 CONFLICT`; Mobile surfaces a conflict indicator and allows the user to overwrite or keep local changes.

### Case 3: Mobile deletes an item offline while PC modifies it
- **Mechanism:** Mobile enqueues a `DELETE` mutation referencing `base_revision = N`. PC modified the item while Mobile was offline (`revision = N + 1`).
- **Resolution:** The Host does NOT apply an unconditional "delete always wins" rule. Because substantive content changed on PC, Host rejects the delete with `409 CONFLICT` and returns the updated task. The task is presented to the mobile user with a notice ("Item was modified on PC before deletion"). If the user confirms deletion, a fresh delete referencing the new revision is submitted.

### Case 4: A Device reconnects after several weeks
- **Mechanism:** Mobile presents a sync cursor older than the Host's 30-day tombstone retention horizon.
- **Resolution:** Host rejects the request with HTTP `410 GONE` (`CURSOR_EXPIRED`). Mobile initiates a full re-baseline: local replicated domain tables are cleared and repopulated via full snapshot download. Unflushed outbox items with expired base revisions are quarantined for review.

### Case 5: PC revokes the Device while it is offline
- **Mechanism:** PC Admin revokes the Device on the host. Mobile remains offline, continuing local read/write operations against cached data.
- **Resolution:** Upon reconnection, the first authenticated request fails with HTTP `401 UNAUTHORIZED` / `403 FORBIDDEN` (`DEVICE_REVOKED`). Mobile immediately discovers revocation:
  1. Authenticated host operations halt.
  2. The local Device token is invalidated.
  3. Pending outbox mutations are cancelled and cleared.
  4. Replicated Profile domain data is purged (Local Data Erasure).
  5. Unrelated device-local provider API keys (e.g. user-entered OpenAI keys) are preserved.
  6. Mobile transitions to an un-enrolled initial setup state.

### Case 6: Bound Profile is soft-deleted while Device is offline
- **Mechanism:** PC Admin initiates Profile soft-delete (entering the 7-day recovery window). Mobile reconnects.
- **Resolution:** Host rejects sync requests with HTTP `403 FORBIDDEN` (`PROFILE_INACTIVE`). Mobile does NOT execute permanent local erasure. Instead, Mobile enters a **quarantined/disabled mode**: UI displays "Profile Inactive / Soft-Deleted", local mutations are paused, and access is locked. If PC Admin restores the Profile within 7 days, subsequent authentication succeeds and normal sync resumes.

### Case 7: Bound Profile reaches hard purge while Device is offline
- **Mechanism:** The 7-day recovery window expires and the Host permanently purges the Profile. Mobile reconnects.
- **Resolution:** Host returns HTTP `404 NOT_FOUND` or `410 GONE` (`PROFILE_PURGED`). Mobile treats this as permanent destruction: all local replicated Profile records, caches, and pending mutations are permanently deleted. The device is reset to fresh enrollment.

### Case 8: Mobile app is reinstalled and loses local synchronization metadata
- **Mechanism:** User uninstalls and reinstalls the app. Local database, secure keystore entries, and outbox are wiped by the OS.
- **Resolution:** The reinstalled app has no credentials or sync metadata. It cannot silently reuse old device authority. Mobile must undergo fresh pairing and enrollment. The PC Host issues a new Device record with a new independent credential. The previous device record remains orphaned on the Host until PC Admin revokes it. The new device performs a full initial sync.

### Case 9: Two retries arrive after a network timeout
- **Mechanism:** Request 1 times out from Mobile's perspective but reaches the server. Request 2 is dispatched. Both arrive concurrently at the Host.
- **Resolution:** Both requests carry the identical `mutation_id`. The Host wraps mutation processing in a database transaction with a unique constraint on `mutation_id`. The first transaction commits; the second detects the existing `mutation_id`, skips execution, and returns the committed response.

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
| **Active Voice / Audio Session** | Continuous Long-Running | Foreground Service (`FOREGROUND_SERVICE_TYPE_MICROPHONE`) | User-visible notification required. Allowed ONLY during active interaction. |

### 5.2 Foreground Service Boundaries

- **Background Sync Restriction:** Continuous Foreground Services (FGS) for ordinary background synchronization or outbox processing are **STRICTLY PROHIBITED**. Using persistent foreground notifications to keep sync sockets alive violates mobile battery guidelines and Android platform expectations.
- **Approved FGS Use Cases:** Foreground Services are reserved strictly for user-initiated, ongoing, real-time operations, specifically active Voice interaction sessions or active media streaming (evaluated in Batch C).

---

## 6. B4: Reminders, Alarms, and Notification Delivery Architecture

Preserving Decision D10 and `ADR-0011`, the PC Local AI Runtime `SchedulerService` remains canonical scheduler truth. Mobile functions as a local presentation and delivery client.

### 6.1 Replicated Occurrence State

- **Precomputed Occurrences:** The PC Runtime computes scheduled occurrence events and replicates them to Mobile as concrete occurrence instances (`occurrence_id: UUID`, `entity_id: UUID`, `trigger_time_utc: datetime`, `type: ALARM | REMINDER`, `metadata: dict`).
- **Autonomous Recurrence Metadata (Floating Time):**
  - *Fixed-Instant Events:* Stored as invariant UTC timestamps.
  - *Floating Local-Time Recurrence (e.g. "9 AM wherever I am"):* Mobile receives bounded recurrence rule metadata (e.g. `local_time: 09:00`, days of week) for active alarms. If Mobile changes timezones while disconnected, it recalculates the trigger time in the new local timezone locally.

### 6.2 Android Alarm Platform Lifecycle & Permissions

Exact alarm scheduling on Android is strictly conditional and NOT an unconditional guarantee:
1. **Permission Separation:**
   - `SCHEDULE_EXACT_ALARM`: User-revocable special app access (Android 12+, API 31+). Default denied on Android 13/14+ for newly installed general applications.
   - `USE_EXACT_ALARM`: Restricted permission limited by Google Play policy to core clock/timer apps. The Companion app CANNOT assume Google Play approval for `USE_EXACT_ALARM` and must support `SCHEDULE_EXACT_ALARM`.
2. **Permission Revocation Lifecycle:**
   - If the user revokes exact alarm access in Android settings, the OS automatically clears all scheduled exact alarms.
   - Mobile MUST register for `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` to detect revocation, update internal capability state, and warn the user.
3. **Notification Runtime Permission (`POST_NOTIFICATIONS`):**
   - Required on Android 13+ (API 33+).
   - If denied, OS suppresses status bar notifications and alert heads-up displays.
   - *Alarm Behavior on Denial:* Full-screen alarm activity (`USE_FULL_SCREEN_INTENT`) can still launch over lockscreen for critical alarms if permitted, but background notification channels are blocked. UI must explicitly surface "Notification Permission Required" warnings.
4. **Degraded Delivery Fallback:**
   - **Alarms:** If exact alarm capability is unavailable, Alarms are marked **DEGRADED / UNARMED LOCALLY**. The app MUST NOT claim WorkManager provides alarm fidelity.
   - **Reminders:** Reminders degrade gracefully to inexact alarms or WorkManager notifications.

### 6.3 Deterministic Duplicate Suppression Protocol

To prevent double-alerting (e.g. PC toast + Mobile ring for the same alarm), the architecture enforces:
1. **Stable Occurrence Identity:** Every alert occurrence has a stable unique ID (`occurrence_id`).
2. **Monotonic Local State:** Mobile tracks local delivery status in its persistent store (`PENDING`, `TRIGGERED`, `DISMISSED`, `SNOOZED`, `REMOTE_DELIVERED`).
3. **Local Trigger Suppression:** When an alert fires locally, Mobile sets status to `TRIGGERED` and enqueues an acknowledgment mutation to Host. If a remote push arrives later for that `occurrence_id`, Mobile inspects local state and suppresses duplicate alerts.
4. **Remote Delivery Suppression:** If PC delivers an alert while Mobile is connected, Host pushes a dismissal/delivery event. Mobile updates local status to `REMOTE_DELIVERED` and cancels the scheduled local OS alarm.

### 6.4 System Lifecycle Events

- **Device Reboot (`ACTION_BOOT_COMPLETED`):** The OS clears all scheduled alarms on reboot. Mobile registers a broadcast receiver to read active alarms from the local database and re-register them with `AlarmManager`.
- **Timezone Change (`ACTION_TIMEZONE_CHANGED`):** Mobile recalculates floating-time alarms and reschedules `AlarmManager` intents.
- **Manual Clock Change (`ACTION_TIME_CHANGED`):** Mobile re-evaluates all pending alarms against current system time.
- **Missed Events:** Occurrences whose trigger time passed while the device was powered off are classified as `MISSED` on startup. Alarms show an explicit "Missed Alarm" banner; Reminders bundle into a catch-up notification summary.
- **Snooze Semantics:** Snoozing an occurrence does NOT create a duplicate entity. It mutates the active occurrence record with a new `snooze_until_utc` timestamp and reschedules a one-shot exact alarm.

---

## 7. Device Revocation, Profile Soft-Delete, and Hard-Purge

Authorization revocation and data erasure are strictly distinct architectural events:

```
+-----------------------------------------------------------------------------------+
| EVENT                | HOST ACTION             | MOBILE DISCOVERY ACTION          |
+-----------------------------------------------------------------------------------+
| Device Revocation    | Invalidate device token | Wipe device token & replica DB;  |
|                      | Reject mutations        | PRESERVE 3rd-party user API keys |
+-----------------------------------------------------------------------------------+
| Profile Soft-Delete  | Disable profile access  | Quarantine local replica;        |
| (7-day recovery)     | Reject mutations        | Lock UI; preserve for recovery   |
+-----------------------------------------------------------------------------------+
| Profile Hard-Purge   | Destroy profile data    | Permanent Local Data Erasure;    |
| (Permanent)          | Reject authentication   | Full client reset                |
+-----------------------------------------------------------------------------------+
```

- **Remote Revocation:** Server-side revocation is instant on the Host. An offline Mobile device cannot know it is revoked until it establishes network contact.
- **Local Data Erasure:** Physical deletion of replicated records occurs upon receiving an authoritative rejection (`401`/`403`/`410`).
- **Storage Sandbox Truth:** Android filesystem deletion removes database and cache files within the app sandbox. Cryptographic zeroization of flash storage is not an Android OS guarantee and must not be falsely claimed.
