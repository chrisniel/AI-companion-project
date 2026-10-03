# Implementation Plan: Mobile V1 Canonicalization

**Task Branch:** `docs/mobile-v1-canonicalization`
**Status:** PLANNING (Revised Draft)
**Git / Final Approval Owner:** Chris
**Implementation / Authoring Agent:** Antigravity
**Independent Reviewer:** GPT + Chris

## 1. Objective

Define the canonical Mobile V1 architecture for the AI Companion project, elevating the mobile domain from a legacy Kotlin prototype into a formally specified, production-ready Flutter target. This architecture must solve the complexities of offline behavior, per-domain synchronization, credential security, background execution, and device resource constraints while strictly adhering to the established Multi-Profile PC V1 ownership model and existing system invariants.

### 1.1 Scope Guardrails / Non-Goals

This MOBILE-ARCH architecture pass **DOES NOT IMPLEMENT**:
- Flutter Desktop or Flutter Mobile code;
- M1;
- Kotlin/Android production changes;
- backend/runtime behavior;
- migrations or OpenAPI changes;
- mobile persistence/database implementation;
- sync/outbox implementation;
- local mobile inference;
- Health Connect;
- Android background workers/services;
- notification/alarm implementation;
- Voice implementation;
- CI workflow changes.

The architecture pass may document approved target behavior only.

## 2. Contradiction Inventory & Context Gaps

Inspection of the PC V1 architecture and Android prototype source code has surfaced the following discrepancies that this architecture pass must resolve:

- **Client Technology:** Kotlin-production wording and existing prototype code (Jetpack Compose) conflict with the accepted decision that Flutter is the intended production foundation (as validated in `ADR-0017` for Windows and intended for cross-platform sharing).
- **Package Identity:** The current Android project package is `com.example`, whereas D3 explicitly dictates `com.cnl.aicompanion`.
- **Inference Reality:** The offline capability matrix states local model execution is unavailable on mobile, yet `ModelsScreen.kt` advertises an "OnDeviceHybridFailoverCard" using a quantized edge LLM (Gemma-2-2B) and local TTS (Kokoro-82M).
- **Security & Storage:** `SharedPreferencesConnectionRepository.kt` stores the pairing token in cleartext `Context.MODE_PRIVATE` Android SharedPreferences, violating the protected production credential boundary. Mobile credentials and sensitive device-local secrets MUST use approved platform-protected secure storage (Android Keystore is a primary candidate for research).
- **Transport Security:** The prototype globally permits cleartext transport and `LocalAiRuntimeClient.kt` does not itself guarantee protected non-loopback transport. Ordinary sensitive LAN traffic without an encrypted/protected transport path would violate D5. An approved encrypted overlay such as Tailscale may provide transport protection even when the local application endpoint uses HTTP internally. MOBILE-ARCH must define the supported production transport combinations explicitly. Application authentication remains mandatory regardless of network transport.
- **Synchronization Mechanics:** `HttpTasksRepository.kt` performs optimistic in-memory task updates (`_tasks.update`) via `MutableStateFlow` without robust offline mutation persistence, violating reliable offline synchronization requirements.
- **Health Connect:** `MockHealthDataProvider.kt` is a fully synthetic mock pipeline. It is classified as PROTOTYPE / REFERENCE EVIDENCE ONLY. Health Connect is an OPEN MOBILE ARCHITECTURE / RELEASE-ALLOCATION DECISION, and the prototype's state is not a violation since mobile health design was intentionally deferred.
- **CI Evidence Verification:**
  - PC-VERIFY-001 merged baseline: `d92b6e4b9b19e957dd419b9968c7ad3ad4cee031`
  - Post-merge CI Run #65 PASS: Externally/independently verified baseline evidence supplied by Chris/GPT.

## 3. Decision Dependency Order

The architecture implementation will proceed in the following logically dependent order (split into batches, see Section 9). This order ensures foundational boundaries (identity, capability, and storage) are locked before attempting to design complex synchronization, background execution, and hardware-specific behaviors.

1. **Shared Ecosystem & PC/Mobile Boundary:** Define the fundamental relationship between the PC Host (Runtime/Account Admin) and Mobile Satellite, establishing authoritative ownership.
2. **Flutter Shared-Code & Platform Boundary:** Define the workspace topology, isolating shared Dart logic from mobile-specific platform channels/adapters.
3. **Identity, Enrollment & Security:** Establish secure device pairing, credential storage architecture, and transport security before any data flows.
4. **Connected / Offline / Cloud Capability Matrix:** Define what the mobile client can and cannot do in online, offline, and remote-cloud states.
5. **Local Storage & Offline Persistence:** Define durable local persistence, offline working state, mutation persistence, cache boundaries, and recovery semantics required to support the offline capability matrix.
6. **Per-Domain Synchronization & Reconciliation:** Design the conflict resolution and replication logic building upon the persistence layer.
7. **Background Execution, Alarms & Notifications:** Map domain semantics (Tasks/Reminders/Alarms) to mobile constraints (Doze, WorkManager, exact alarms).
8. **Local Mobile Inference & Resource Policy:** Settle the contradiction on local edge inference (mandatory vs. deferred) and define the resource budget.
9. **Voice/Audio:** Define mobile audio lifecycle, STT/TTS routing, and audio focus.
10. **Health/Wearables:** Determine the release disposition and architecture for Health Connect data pipeline.
11. **Threat & Privacy Review:** Conduct a security review over the complete mobile flow.
12. **Performance, Battery & Thermal Policy:** Establish budgets preventing battery drain and thermal throttling.
13. **Testing, CI & Golden Acceptance:** Define the automated testing boundary and Mobile Golden acceptance criteria to prove the architecture.

## 4. Synchronization & Offline Reconciliation Requirements

The architecture must define per-domain synchronization rules covering:
- **Canonical Authority:** Which device wins (or is the ultimate source of truth).
- **Entity Identity & Revision:** Stable entity identity strategy and revision/concurrency strategy.
- **Operation Identity & Idempotency:** Operation identity/idempotency strategy.
- **Offline Mutation Representation:** How offline operations are stored and replayed.
- **Retry Logic:** Retry/backoff strategy after unknown outcomes.
- **Change Cursor/Replay:** Delta sync tracking.
- **Deletion/Tombstones:** Preventing silent resurrection of deleted entities.
- **Stale Clients:** Re-baselining clients that have been offline for extended periods.
- **Conflict Classification & Resolution:** Explicit rules for mergeable vs. unmergeable conflicts.
- **Profile Isolation & Device Revocation:** Cryptographic and logical boundary enforcement.

**Failure cases that must be explicitly solved:**
- The server commits a mutation but the HTTP response to the mobile client is lost.
- The phone and PC both edit the exact same entity while the phone is offline.
- The phone performs an offline delete while the PC performs a simultaneous update.
- A stale client reconnects after weeks offline.
- A mobile device's credentials are revoked while it is offline.
- The user's Profile is deleted on the PC while the phone is offline.

## 5. Explicit Research Requirements

During implementation, the agent must inspect and cite official primary documentation (e.g., developer.android.com, flutter.dev) for:
- Android lifecycle and Process Death.
- Doze Mode and App Standby Buckets.
- WorkManager capabilities and constraints.
- Foreground Services types and restrictions.
- Notification permissions and channels.
- Exact alarms (`SCHEDULE_EXACT_ALARM`) and background limits.
- System broadcasts (reboot, timezone, clock changes).
- Secure credential storage capabilities (Android Keystore System and alternatives).
- Health Connect API and read/write quotas.
- Android audio lifecycle and audio focus management.
- Flutter platform channel and Android integration mechanics.
- Candidate mobile inference runtimes (e.g., ExecuTorch, llama.cpp Android).

**Benchmark Requirements:** Hardware/inference research must include: RAM footprint, model size, load latency, context window limits, sustained throughput, battery impact, thermal behavior, storage costs, and cold/warm start behavior (not merely token rate).

## 6. ADR Candidates

Decisions will be elevated to ADRs only if they are cross-cutting, expensive to reverse, technically consequential, or likely to be disputed. Potential candidates include:
- Shared Flutter desktop/mobile workspace topology.
- Mobile synchronization and authority model.
- Mandatory vs. Optional Mobile local inference.
- Substantive refinement of the mobile device credential/security boundary.
*(Note: ADRs will not be numbered or approved during this planning phase).*

## 7. Human Decision Points

The architecture will halt for explicit human approval at defined batch boundaries (see Section 9) on decisions such as:
- Flutter workspace/package topology structure.
- Mobile local inference strategy (mandatory vs capability-dependent vs deferred).
- Per-domain synchronization and conflict policy.
- Local persistence implementation (once semantics are frozen).
- Alarm/background reliability target vs. battery cost.
- Health Connect release allocation.
- Secure secret-storage invariant.
- Independent mobile cloud behavior.
- Offline voice capability requirement.
- Device capability and support tiers.

## 8. Target Document Ownership

The architecture will be mapped into a canonical structure without creating new baseline files prematurely during PLAN.

- `android-companion.md` remains the current/interim canonical Mobile boundary.
- It must not be deleted or narrowed until its unique semantics are promoted and independently verified.
- **Batch A** will determine whether it should remain the Mobile baseline or whether a dedicated Mobile baseline such as `MOBILE_SYSTEM_BASELINE.md` is justified.
- Focused shared architecture should continue owning genuinely shared semantics.

The tentative structural mapping includes:
- **Mobile Baseline & Capability Matrix:** TBD by Batch A.
- **Flutter Client Topology & Lifecycle:** Promoted to a shared/client specification or integrated into a generalized frontend baseline.
- **Offline Storage & Sync:** New or updated storage specification.
- **Background Work, Alarms & Notifications:** Promoted to `tasks-reminders-alarms-and-routines.md` (mobile section).
- **Mobile Security & Privacy:** Integrated into `authentication-and-secrets.md` and `profiles-and-devices.md`.
- **Local Inference / Resources:** Integrated into `runtime-and-models.md` and `performance-and-capacity.md`.
- **Mobile Voice / Audio:** Integrated into `voice-and-audio.md`.

## 9. Delivery Lifecycle & Granulated Architecture Implementation

The architecture implementation will proceed in three bounded internal batches on this SAME branch.

### Batch A — Mobile Foundation
Resolve only:
1. Shared ecosystem / PC / Mobile responsibility and authority boundary.
2. Flutter shared-code and platform-adapter boundary.
3. Mobile identity, enrollment, authentication, credential and transport architecture.
4. Connected / Offline / Optional Cloud capability matrix.

**STOP after Batch A.** Return exact canonical diffs and evidence for independent GPT/Chris review. Do not begin Batch B without approval.

### Batch B — Offline & Native Reliability
After Batch A approval, resolve only:
1. Mobile local persistence semantics.
2. Per-domain synchronization and reconciliation.
3. Android background execution responsibilities.
4. Reminders / Alarms / Notifications, including offline behavior, duplicates, reboot, process death, timezone changes, Doze and permissions.

**STOP after Batch B.** Return exact canonical diffs and evidence for independent GPT/Chris review. Do not begin Batch C without approval.

### Batch C — Mobile Capabilities & Verification
After Batch B approval, resolve only:
1. Local mobile inference / hardware capability policy.
2. Mobile Voice/audio architecture.
3. Health/Wearables release disposition and architecture if approved.
4. Mobile security/privacy threat-model completion.
5. Performance, battery and thermal policy.
6. Testing/CI architecture boundary.
7. Mobile Golden acceptance architecture.
8. Cross-domain consistency review.

**STOP after Batch C** for independent architecture review.

### Documentation & Planning Integration
Do NOT update the full master planning spine during A/B/C except where absolutely necessary to keep canonical architecture internally navigable.
After Batches A+B+C are independently approved, proceed to DOCUMENTATION / PLANNING INTEGRATION:
- Update `MOBILE_WBS.md`
- Update `DELIVERY_INDEX.md`
- Update `SPRINT_ROADMAP.md`
- Update `BACKLOG.md`
- Checklist/readiness owner
- Update `DECISION_REGISTER.md`
- Update `DECISION_DEBT.md`
- Update `DOCUMENTATION_MAP.md`
- Create/supersede ADRs only where approved and genuinely warranted.

Following planning integration:
1. **Independent documentation review**
2. **Closure** → independent closure review
3. **PR** → scoped CI → squash merge → read-only post-merge verification

## 10. Acceptance Criteria & Fresh-Agent Validation

**MOBILE-ARCH Acceptance Criteria:**
- Exhaustive matrix of Mobile capability modes (online, offline, cloud).
- Explicit per-domain sync authority, idempotency, retry, and deduplication rules.
- Explicit conflict and tombstone resolution behavior.
- Resiliency against process death, reboot, and timezone changes.
- Defined offline alarm/reminder behavior.
- Formal release disposition for local inference, Voice, and Health Connect.
- Defined credential and transport model, including approved platform-protected secure storage.
- Privacy and security threat boundary definitions.
- Defined battery, thermal, and resource behaviors.
- Testing boundaries and Mobile Golden acceptance architecture.
- Shared Flutter workspace clarity sufficient to unblock M1 implementation.

**Fresh-Agent Validation Questions:**
To pass validation, a fresh agent must correctly answer:
- What exactly works when the mobile device is offline?
- What data is authoritative on the PC vs. the Mobile device?
- How are offline writes reconciled when conflicting with PC updates?
- Can a Mobile device switch Profiles on its own?
- How is device revocation handled while offline?
- Is local edge inference required to run the app?
- Is Health Connect part of the Android V1 release?
- What happens to alarms after process death or device reboot?
- Which reminders/alarms work without a connection to the PC?
- What credentials remain permanently device-local?
- Which Flutter packages are shared between PC and Mobile?
- What parts of this architecture are actually implemented today vs. planned?
