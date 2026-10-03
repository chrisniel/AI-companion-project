# Implementation Plan: Mobile V1 Canonicalization

**Task Branch:** `docs/mobile-v1-canonicalization`
**Status:** PLANNING (Revised Draft)
**Owner:** Antigravity

## 1. Objective

Define the canonical Mobile V1 architecture for the AI Companion project, elevating the mobile domain from a legacy Kotlin prototype into a formally specified, production-ready Flutter target. This architecture must solve the complexities of offline behavior, per-domain synchronization, credential security, background execution, and device resource constraints while strictly adhering to the established Multi-Profile PC V1 ownership model and existing system invariants.

## 2. Contradiction Inventory & Context Gaps

Inspection of the PC V1 architecture and Android prototype source code has surfaced the following discrepancies that this architecture pass must resolve:

- **Client Technology:** Kotlin-production wording and existing prototype code (Jetpack Compose) conflict with the accepted decision that Flutter is the intended production foundation (as validated in `ADR-0017` for Windows and intended for cross-platform sharing).
- **Package Identity:** The current Android project package is `com.example`, whereas D3 explicitly dictates `com.cnl.aicompanion`.
- **Inference Reality:** The offline capability matrix states local model execution is unavailable on mobile, yet `ModelsScreen.kt` advertises an "OnDeviceHybridFailoverCard" using a quantized edge LLM (Gemma-2-2B) and local TTS (Kokoro-82M).
- **Security & Storage:** `SharedPreferencesConnectionRepository.kt` stores the pairing token in cleartext `Context.MODE_PRIVATE` Android SharedPreferences, violating the protected production credential boundary. 
- **Transport Security:** `LocalAiRuntimeClient.kt` uses unencrypted HTTP configs that conflict with the protected production transport (Tailscale/Cloudflare) mandated by D5.
- **Synchronization Mechanics:** `HttpTasksRepository.kt` performs optimistic in-memory task updates (`_tasks.update`) via `MutableStateFlow` without a durable outbox, violating robust offline synchronization requirements.
- **Health Connect:** `MockHealthDataProvider.kt` is a fully synthetic mock pipeline with no actual `androidx.health.connect` implementation.

## 3. Decision Dependency Order

The architecture implementation will proceed in the following logically dependent order. This order ensures foundational boundaries (identity, capability, and storage) are locked before attempting to design complex synchronization, background execution, and hardware-specific behaviors.

1. **Shared Ecosystem & PC/Mobile Boundary:** Define the fundamental relationship between the PC Host (Runtime/Account Admin) and Mobile Satellite, establishing authoritative ownership.
2. **Flutter Shared-Code & Platform Boundary:** Define the workspace topology, isolating shared Dart logic from mobile-specific platform channels/adapters.
3. **Identity, Enrollment & Security:** Establish secure device pairing, credential storage (Android Keystore integration), and transport security before any data flows.
4. **Connected / Offline / Cloud Capability Matrix:** Define what the mobile client can and cannot do in online, offline, and remote-cloud states.
5. **Local Storage & Offline Persistence:** Define the robust local database schema and outbox semantics required to support the offline capability matrix.
6. **Per-Domain Synchronization & Reconciliation:** Design the conflict resolution and replication logic (see Section 4) building upon the persistence layer.
7. **Background Execution, Alarms & Notifications:** Map domain semantics (Tasks/Reminders/Alarms) to mobile constraints (Doze, WorkManager, exact alarms).
8. **Local Mobile Inference & Resource Policy:** Settle the contradiction on local edge inference (mandatory vs. deferred) and define the resource budget.
9. **Voice/Audio:** Define mobile audio lifecycle, STT/TTS routing, and audio focus.
10. **Health/Wearables:** Define the actual Health Connect data pipeline and permission boundary.
11. **Threat & Privacy Review:** Conduct a security review over the complete mobile flow.
12. **Performance, Battery & Thermal Policy:** Establish budgets preventing battery drain and thermal throttling.
13. **Testing, CI & Golden Acceptance:** Define the automated testing boundary and Mobile Golden acceptance criteria to prove the architecture.

## 4. Synchronization & Offline Reconciliation Requirements

The architecture must define per-domain synchronization rules covering:
- **Canonical Authority:** Which device wins (or is the ultimate source of truth).
- **Entity Identity & Revision:** UUIDs and logical clock/versioning mechanisms.
- **Operation ID & Idempotency:** Deduplication of mutating events.
- **Offline Mutation Representation:** Durable outbox vs. state-based diffs.
- **Retry Logic:** Exponential backoff after unknown outcomes.
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
- Secure credential storage (Android Keystore System).
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

The architecture will halt for explicit human approval on:
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

Instead of creating files immediately, the architecture will be mapped into the following canonical structure, preserving `docs/04_Architecture/01_Domains/android-companion.md` as the root until unique semantics are individually promoted and verified:
- **Mobile Baseline & Capability Matrix:** `android-companion.md`
- **Flutter Client Topology & Lifecycle:** Promoted to a shared/client specification or integrated into a generalized frontend baseline.
- **Offline Storage & Sync:** New or updated storage specification.
- **Background Work, Alarms & Notifications:** Promoted to `tasks-reminders-alarms-and-routines.md` (mobile section).
- **Mobile Security & Privacy:** Integrated into `authentication-and-secrets.md` and `profiles-and-devices.md`.
- **Local Inference / Resources:** Integrated into `runtime-and-models.md` and `performance-and-capacity.md`.
- **Mobile Voice / Audio:** Integrated into `voice-and-audio.md`.

## 9. Delivery Lifecycle & Verification

Implementation will strictly follow:
1. **ARCHITECTURE IMPLEMENTATION** → independent architecture review → corrections / approval
2. **DOCUMENTATION + PLANNING INTEGRATION** (updating `MOBILE_WBS.md`, `DELIVERY_INDEX`, `SPRINT_ROADMAP`, `BACKLOG`, `MASTER_CHECKLIST`, `DECISION_REGISTER`, `DOCUMENTATION_MAP`) → independent documentation review → corrections / approval
3. **CLOSURE** → independent closure review
4. **PR** → scoped CI → squash merge → read-only post-merge verification

## 10. Acceptance Criteria & Fresh-Agent Validation

**MOBILE-ARCH Acceptance Criteria:**
- Exhaustive matrix of Mobile capability modes (online, offline, cloud).
- Explicit per-domain sync authority, idempotency, retry, and deduplication rules.
- Explicit conflict and tombstone resolution behavior.
- Resiliency against process death, reboot, and timezone changes.
- Defined offline alarm/reminder behavior.
- Formal release disposition for local inference, Voice, and Health Connect.
- Defined credential and transport model, including Android Keystore.
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
