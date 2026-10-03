# Mobile Offline, Sync, and Background Architecture

> **Document Role:** Canonical infrastructure and behavior specification for Mobile Companion offline capabilities, synchronization, and Android background delivery.
> **Status:** Active Canonical (Batch B)
> **Authority Precedence:** This document governs Mobile synchronization, offline behavior, and background execution limits. It operates under the cross-cutting boundaries defined in MOBILE_SYSTEM_BASELINE.md. Schema and domain truth remain owned by the shared domain specifications (e.g., 	asks-reminders-alarms-and-routines.md).

## 1. Justification

This dedicated specification is required because offline state replication, conflict reconciliation, Android background lifecycle rules, and credential revocation handling are cross-cutting Mobile concerns. Injecting them into the existing shared domain owners (e.g., Tasks, Profile) would fragment the synchronization model, dilute shared architecture with Android-specific execution guarantees, and fail to address complex multi-domain failure cases cohesively.

## 2. B1: Local Persistence Semantics

Mobile MUST durably persist state to function offline. 
State is classified and governed as follows:

- **Authoritative local Device state (e.g., Device Credentials):** MUST survive process death, restart, and device reboot. MUST be stored in platform-protected secure storage (e.g., Android Keystore).
- **Replicated Profile/Domain state (e.g., Tasks, Reminders, Alarms):** MUST survive process death and reboot. Provides offline working state.
- **Pending local mutations (Outbox):** MUST survive process death and reboot. Represents user intent that must reach the PC Host.
- **Cached/Read-only state (e.g., Conversations, Character state):** Survives process death to save bandwidth and improve load times, but MAY be safely discarded/evicted without data loss.
- **Transient UI state:** Safely discarded on process death (unless preserved by Flutter state restoration).
- **Synchronization metadata (e.g., cursors, high-water marks):** MUST survive process death and reboot to prevent expensive full-resyncs.

**[BATCH-B DECISION]** *Architectural Recommendation:* A local relational store (e.g., Drift/SQLite) is recommended for replicated domain state and outbox queuing, while the platform keystore is required for credentials. Exact technology implementation is not locked, but the durability semantics are.

## 3. B2: Per-Domain Synchronization & Reconciliation

The PC Host is the canonical authority. Mobile is a Satellite replica.

### 3.1 Domain Matrix

| Domain | Authority & Concurrency | Deletes & Conflicts |
| :--- | :--- | :--- |
| **Tasks, Reminders, Alarms** | **PC Canonical.** Mobile offline writes ALLOWED. Idempotent operations via UUIDs. Last-Write-Wins (LWW) by timestamp with PC tie-breaker. | Soft-deletes (tombstones) required for propagation. Offline delete beats remote edit. |
| **Routines** | **PC Canonical.** Read-only cache on Mobile. | No offline creation/edits. |
| **Conversations / History** | **PC Canonical.** Read-only cache on Mobile. | No offline edits. |
| **Character / Personality** | **PC Canonical.** Read-only cache on Mobile. | Managed on PC. |
| **Settings (Replicated)** | **PC Canonical.** Read-only cache on Mobile. | Managed on PC. |

### 3.2 Synchronization Mechanics

- **Identity:** All synchronizable entities MUST use stable, client-generatable identities (e.g., UUIDv4) to allow offline creation.
- **Change Discovery:** Architecture requires a cursor-based delta synchronization (high-water mark/logical clock or sequence ID) to fetch only changes since the last sync.
- **Mutation Identity:** Outbox mutations MUST include a unique Idempotency Key (or Mutation UUID) to prevent duplicate operations on network retries.
- **Stale Devices (Re-baseline):** If a Device reconnects after the PC Host has purged tombstones (e.g., weeks offline), the delta-sync cannot safely resolve. The Host MUST reject the sync cursor, forcing the Mobile to perform a full re-baseline (wipe local replica and full resync).

## 4. Mandatory Synchronization Failure Cases

The architecture guarantees the following resolutions **[BATCH-B DECISION]**:

1. **Host commits mutation but Mobile loses HTTP response:** The Mobile outbox retries. The PC Host detects the reused Idempotency Key, ignores the duplicate mutation, and returns success.
2. **Mobile and PC modify the same Task offline:** LWW reconciliation based on mutation timestamp. If timestamps are identical, the PC's state wins.
3. **Mobile deletes an item offline while PC modifies it:** Deletion is final. The Mobile tombstone syncs to the PC, and the PC drops the modification and applies the tombstone.
4. **Device reconnects after several weeks:** Host cursor expiration triggers a mandatory full re-baseline on the Mobile client.
5. **PC revokes the Device while offline:** Offline operations continue locally. Upon reconnect, Host returns 401/403. Mobile MUST immediately purge all local replicated Profile state, secrets, and pending outbox mutations (Local Data Erasure).
6. **Bound Profile soft-deleted offline:** Handled identically to Case 5 upon reconnect.
7. **Profile reaches hard purge while offline:** Handled identically to Case 5 upon reconnect.
8. **Mobile reinstalls app, loses sync metadata:** Device loses local credentials. Re-enrollment creates a NEW Device credential. The old credential remains orphaned until PC admin revokes it. A full resync occurs for the new Device.
9. **Two retries arrive after a timeout:** Host database transactions and Idempotency Keys ensure only the first processed request mutates state.
10. **Mobile local clock is wrong:** PC Host acts as the authoritative clock for transaction times. Mobile timestamps are accepted for LWW resolution but clamped to reasonable drift bounds by the Host, or Host dictates logical sequence.

## 5. B3: Android Background Execution Responsibilities

Mobile background work MUST map to Android platform guarantees:

- **Synchronization & Outbox processing:** Opportunistic. Subject to Doze and App Standby. Uses WorkManager (Constraint: Network Connected).
- **Scheduled Local Alert Delivery:** Guaranteed-at-a-time. Uses Android AlarmManager exact alarms. Subject to SCHEDULE_EXACT_ALARM permissions and battery quota limitations.
- **User-visible Continuous Execution:** NOT required for Sync. Foreground Services are explicitly rejected for background synchronization to preserve battery.

**[BATCH-B DECISION]** Architecture only requires WorkManager for opportunistic sync and AlarmManager for alert triggers. No custom bound services or foreground services are permitted for sync.

## 6. B4: Reminders, Alarms, and Notifications

Mobile delivery architecture operates under D10 / ADR-0011 semantics:
- **Replicated occurrence state:** Mobile syncs pre-calculated occurrences (UTC) from the PC SchedulerService. Mobile does NOT independently calculate complex recurrence rules offline.
- **Offline delivery:** Mobile fires EXACT alarms for locally cached occurrences. Only previously synchronized occurrences fire offline.
- **Platform Limitations:** Exact alarms rely on Android permissions. If SCHEDULE_EXACT_ALARM is denied, Mobile gracefully degrades to opportunistic Delivery (WorkManager) or PC-only push notifications.
- **Duplicate Prevention:** Occurrences contain unique IDs. Mobile must track locally fired occurrence IDs to suppress duplicate PC push notifications for the same event, or PC must not push if Mobile confirms receipt.
- **Snooze:** Snooze operates on the specific occurrence ID. It creates a local pending delivery state and queues an outbox mutation; it does NOT duplicate the root Task/Alarm entity.
- **Reboot:** Mobile MUST listen to ACTION_BOOT_COMPLETED to reload and re-register pending exact alarms from the local database into the OS AlarmManager.
- **Timezone/Clock Changes:** Mobile MUST listen to ACTION_TIMEZONE_CHANGED to re-evaluate wall-clock alignments for alarms if local display time differs, though underlying UTC occurrences remain stable.
- **Missed Events:** Upon waking from deep Doze or offline catch-up, stale Alarms are presented as "Missed", and Reminders are delivered in a bundled catch-up notification.

## 7. Revocation vs. Erasure

- **Remote Authorization Revocation:** The PC Host denies access (401/403). This is a server-side state change.
- **Local Data Erasure:** The physical deletion of the Mobile replica. This occurs ONLY when the Mobile client discovers it has been revoked (via network rejection), or via explicit user app-data clearance. 
- **[LOCKED]** Architecture cannot guarantee remote wipe for an offline device. Sensitive data remains locally encrypted on the offline device until the device connects and learns of its revocation.
