# AI Companion — Canonical Product & Milestone Delivery Roadmap

> **Document Role:** Canonical product and milestone delivery roadmap for the AI Companion ecosystem.
> **Status:** Active Canonical (Decisions D1–D11 aligned through R10/R11 reconciliation)
> **Last Updated:** 2026-09-29 (Reconciliation Closure / R13.2)
> **Authority Precedence:** Normative architecture is owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) and focused domain specifications under [`docs/04_Architecture/`](../04_Architecture/). Active sprint state is tracked in [`docs/01_Tracking/task.md`](../01_Tracking/task.md). Detailed feature implementation steps reside in active plans under [`docs/02_Planning/`](./).

---

## 1. Roadmap Status Taxonomy

Roadmap tracking separates **Release Allocation** (which product milestone owns a capability), **Delivery Status** (current engineering state), and **Intent Status & Disposition** (architectural commitment):

### 1.1 Release Allocation
| Release Target | Canonical Meaning |
| :--- | :--- |
| **`PC V1`** | Mandatory delivery milestone required for the initial PC-hosted ecosystem release. AI Companion V1 (unqualified) refers strictly to PC V1. |
| **`PC LATER`** | Approved PC capability scheduled for post-PC-V1 delivery tracks. |
| **`ANDROID V1`** | Mandatory delivery milestone for the follow-on production mobile companion release (`com.cnl.aicompanion`). Independent milestone; does not block PC V1. |
| **`ANDROID LATER`** | Approved Android capability scheduled after Android V1. |
| **`FUTURE / UNSCHEDULED`** | Evaluated or experimental capability without committed release scheduling. |
| **`N/A`** | Applied to rejected capabilities or non-feature governance items. |

### 1.2 Delivery Status
| Status Label | Canonical Meaning |
| :--- | :--- |
| **`COMPLETE / VERIFIED`** | Fully implemented, tested, and verified against repository test suites. |
| **`IN PROGRESS`** | Actively under implementation on a dedicated branch. |
| **`NEXT`** | Immediate next delivery milestone to commence upon clearing prerequisites. |
| **`BLOCKED`** | Delivery milestone blocked pending prerequisite milestone completion. |
| **`PLANNED`** | Scheduled for implementation with active or prerequisite planning in progress. |
| **`NOT STARTED`** | Approved or planned capability with zero codebase implementation. |

### 1.3 Intent Status & Disposition
| Intent / Disposition | Canonical Meaning |
| :--- | :--- |
| **`LOCKED`** | Immutable architectural invariant; changes require formal architecture review and ADR. |
| **`APPROVED`** | Confirmed product capability; implementation design may evolve. |
| **`OPEN DESIGN`** | Approved functional requirement whose exact technical mechanism remains deliberately open. |
| **`EXPERIMENTAL`** | Exploratory research or prototyping effort; not committed release scope. |
| **`PROVISIONAL`** | Current direction, explicitly designated for near-term re-evaluation. |
| **`DEFERRED`** | Valid capability intentionally postponed beyond near-term milestones. |
| **`REJECTED`** | Explicitly excluded from ordinary assistant capability or supported trust model. |

---

## 2. Active Delivery Sequence (Current Milestone Path)

```text
[Phase 8A: UI Foundation] ─────────► COMPLETE / VERIFIED
              │
[Phase 8P: Runtime Config] ────────► COMPLETE / VERIFIED
              │
[Reconciliation Passes R0–R13] ────► COMPLETE / VERIFIED
              │
[Phase 8B: Multimodal Vision] ─────► IN PROGRESS (8B.0–8B.6 VERIFIED; 8B.7 NEXT)
              │
[Phase 8C: Integration & Polish] ──► PC V1 (BLOCKED BY 8B)
              │
┌─────────────┴────────────────────────────────────────────────┐
│ FOUNDATION BAND (Parallel Lanes)                             │
│ ┌──────────────────────────┐    ┌──────────────────────────┐ │
│ │ Lane A: Host & Runtime   │    │ Lane B: Companion/Policy │ │
│ └──────────────────────────┘    └──────────────────────────┘ │
└─────────────┬────────────────────────────────────────────────┘
              │
[CAPABILITY BAND] ─────────────────► PC V1 (Scheduling, Public Info, Voice, Multilingual, Cloud, Health)
              │
[RESILIENCE & HARDENING BAND] ─────► PC V1 (Backup/Restore, Migration Preflight, Security Hardening)
              │
[GOLDEN PC V1 ACCEPTANCE GATE] ────► PC V1 FINAL GATE (End-to-End Integrated Acceptance Journey)
              │
[AI COMPANION V1 RELEASE] ─────────► PC V1 MILESTONE (PC-HOSTED RELEASE)
```

### 2.1 Completed Milestones
- **Phase 8A — Frontend Architecture & UX Harmonization (`COMPLETE / VERIFIED`):** Decomposed Assistant views into focused components, removed stale mock conversations, implemented time-derived home greetings, added truthful system states, annotated mock files as `@deprecated`.
- **Phase 8P — Runtime Configuration & Persistent Asset Foundation (`COMPLETE / VERIFIED`):** Unified subsystem terminology to *Local AI Runtime*, resolved `COMPANION_DATA_ROOT` precedence and bootstrap locator, derived atomic storage layout, implemented Model Registry Schema v3, and verified migration safety.
- **Repository Documentation Reconciliation Passes R0–R13 (`COMPLETE / VERIFIED`):** Conducted full repository forensic audit, locked architectural decisions D1–D11, established canonical documentation routing, purged obsolete terminology, validated Android cleartext/network boundaries, audited and cleaned local legacy database data, verified automated test suites (175 backend pytest, 147 frontend vitest, 124 Android unit/Robolectric), confirmed OpenAPI schema synchronization, reconciled durable domain architecture specifications, executed R13.1 physical architecture cleanup/ADR codification, applied R13.2 boundary/hardening policy, and locked the fresh verified baseline.
- **Phase 8B Foundation (Slices 8B.0–8B.6) (`COMPLETE / VERIFIED`):** Delivered multimodal attachment foundation via PR #13: database migration `006_add_attachments`, Attachment ORM model with 4 mixins, Pillow image validation (MIME, dimension, megapixel, bomb guards), route-specific upload limit (12 MiB envelope, 10 MiB payload), authenticated Blob preview/delete endpoints, transactional pre-stream turn binding, media resolver, llama.cpp image translation, and Web composer staging with Blob previews. Verified by CI Run #23 on merged `develop` SHA `4b2f5fe` (321 backend pytest, 185 frontend vitest across 9 files, 22-route OpenAPI parity with zero drift).

### 2.2 Immediate Next Milestone
- **Phase 8B — Multimodal Image Attachment Foundation (`IN PROGRESS`):**
  - *Current Status:* Slices 8B.0–8B.6 are COMPLETE and VERIFIED. Slice 8B.7 (Persistent Message Attachment Rendering) is NEXT / UNBLOCKED (R9–R13 reconciliation is complete; 8B.7 remains the immediate next engineering slice after branch integration). Slice 8B.8 (Full Integration & Phase Closure) is PLANNED. Phase 8B as a whole is NOT yet complete.
  - *Next Slice Scope (8B.7):* Add `AttachmentRef` to frontend types and `AssistantMessage`, extend `ConversationMessageItem` with authenticated Blob preview fetching and `URL.revokeObjectURL()` cleanup, connect message history loading in `AssistantView`, and verify persistence across reload.
  - *Authoritative Feature Plan:* [`phase-08/plan-phase8-pc-frontend-architecture-ux.md`](./phase-08/plan-phase8-pc-frontend-architecture-ux.md).

### 2.3 Remaining PC V1 Delivery Milestones

#### 2.3.1 In-Flight Completion & Frontend Hardening
- **Phase 8C — Integration, Accessibility & Polish (`PC V1` / `BLOCKED BY 8B`):**
  - *Dependency:* HARD DEPENDENCY on Phase 8B completion (8B.7 and 8B.8). Phase 8C completion is a FINAL ACCEPTANCE DEPENDENCY for PC V1.
  - *Scope:* Elimination of deprecated mock files, bundle analysis and code-splitting, comprehensive keyboard navigation and ARIA accessibility, responsive layout hardening across desktop viewports, end-to-end multimodal regression testing.
  - *Implementation Reality:* Existing React Web client baseline is verified; Phase 8C delivers remaining UI polish, accessibility, responsive hardening, bundle optimization, and multimodal regression / integration verification (persistent message attachment rendering remains owned by Phase 8B.7).
  - *Authoritative Feature Plan:* [`phase-08/plan-phase8-pc-frontend-architecture-ux.md`](./phase-08/plan-phase8-pc-frontend-architecture-ux.md).

#### 2.3.2 Foundation Band (`PC V1`)
The Foundation Band comprises two parallel lanes that proceed concurrently without artificial prerequisite serialization between them:

- **Lane A: Host & Runtime Infrastructure (`PC V1`):**
  - *Parallelism:* PARALLELIZABLE with Lane B (Companion & Policy Foundation).
  - *Controlled Local Model Import Service (Decision D6 Execution Gap):* Completing the execution service for the controlled local import flow (`inbox` → `preflight` → `staging` → `atomic install` → `library` → `registry`). Supported model artifact formats and exact import execution mechanisms remain OPEN DESIGN.
  - *Windows Host Autostart at Login (Decision D2):* Local AI Runtime configured to start automatically on Windows user login. Specific Windows launch mechanism remains OPEN DESIGN.
  - *Native Windows Notification Delivery (Decisions D2, D10):* Direct OS notification delivery decoupled from open browser tabs. Exact notification adapter remains OPEN DESIGN. *Dependency Edge:* INTEGRATION DEPENDENCY for closed-browser delivery of scheduled reminders, alarms, and routines.
  - *Gaming / Low-Impact Resource Policy:* Ability to enter a lower-impact resource policy during heavy foreground workloads while preserving required companion behavior and notification integrity. Exact detection, throttling, pausing, GPU offload layer adjustments, and CPU thread limits remain OPEN DESIGN.
  - *Canonical Architecture Owners:* [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](../04_Architecture/04_Infrastructure/runtime-and-models.md), [`windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md), [`storage-and-assets.md`](../04_Architecture/04_Infrastructure/storage-and-assets.md), and [`performance-and-capacity.md`](../04_Architecture/04_Infrastructure/performance-and-capacity.md).

- **Lane B: Companion & Policy Foundation (`PC V1`):**
  - *Parallelism:* PARALLELIZABLE with Lane A (Host & Runtime Infrastructure).
  - *Persistent Character & Personality Configuration (Decision D11):* Conversations already persist `character_id` in the verified database baseline; this milestone delivers persistent storage, schema, and runtime prompt resolution for distinct Character lore/identity and decoupled Personality behavioral traits. Specific storage schemas remain OPEN DESIGN.
  - *Lightweight Conceptual Emotion State (Decision D11):* Transient, non-clinical conceptual mood modulation reflecting recent interactions. State dimensions, decay behavior, and transition dynamics remain OPEN DESIGN / later work.
  - *Memory Scoping & Selective Automatic Memory (Decision D7):* Profile-first persistence and manual memory baseline already exist; this milestone delivers explicit memory scoping and deterministic, user-visible selective automatic capture policies. Extraction models, confidence heuristics, and schema remain OPEN DESIGN.
  - *Safe Typed Conversational Actions (Decision D9):* 5-stage deterministic policy pipeline (Model → Typed Request → Deterministic Policy → Narrow Adapter → Capability; where Model emits intent, Typed Request validates schema/bounds, Deterministic Policy evaluates permissions/risk/consent, Narrow Adapter performs least-privilege typed operations, and Capability is the bounded resource) operating under DEFAULT DENY with 4-tier risk matrix (Risk 0–3; resolving ALLOW / CONFIRM / DENY). *Dependency Edge:* Deterministic action pipeline is a HARD DEPENDENCY only for exposing tool/action execution to generative/model invocation; it does not block independent implementation of underlying scheduler engines, storage schemas, or read-only provider adapters. Confirmation dialogs, token limits, and audit log persistence remain OPEN DESIGN. Arbitrary command shell / PowerShell is permanently REJECTED.
  - *Canonical Architecture Owners:* [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md), [`memory-and-personalization.md`](../04_Architecture/01_Domains/memory-and-personalization.md), and [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md).

#### 2.3.3 Capability Band (`PC V1`)
Contains domain capabilities that are internally parallelizable and progress subject only to their explicit dependency edges:

- **Scheduled Reminders, Alarms & Bounded Routines (Decision D10):**
  - *Scope:* Scheduled reminder execution with catch-up logic, time-critical alarm alerts with best-effort wake and quiet hours with per-item overrides (without universal automatic all-alarm bypass; exact default Alarm urgency behavior remains OPEN DESIGN), and bounded companion routines under deterministic scheduler proactivity. Existing Task CRUD/retention baseline is verified.
  - *Dependencies:* Scheduler engine, persistence, and evaluation logic are PARALLELIZABLE. Closed-browser alerting has an INTEGRATION DEPENDENCY on Native Windows Notification Delivery. Exposing task/reminder creation or management to conversational model turns has a HARD DEPENDENCY on Safe Typed Conversational Actions (D9). Character-specific routine phrasing integrates with Character & Personality configuration.
  - *Canonical Architecture Owner:* [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md).

- **Read-Only Public Current Information (WebSearch, Fetch, Weather):**
  - *Scope:* Provider-independent `WebSearch`, `Fetch`, and weather/public-information capabilities with SSRF/network containment, untrusted external content handling, privacy minimization, source provenance, and credential isolation from client/prompt context. Specific services (e.g., Tavily, Open-Meteo) remain candidate adapters. Interactive browser automation is decoupled and scheduled for PC Later.
  - *Dependencies:* Provider adapters and fetch pipelines are PARALLELIZABLE. Exposing external information tools to generative conversational turns has a HARD DEPENDENCY on Safe Typed Conversational Actions (D9).
  - *Canonical Architecture Owner:* [`docs/04_Architecture/03_Integrations/web-current-information.md`](../04_Architecture/03_Integrations/web-current-information.md).

- **Conversational Voice (without Wake Word):**
  - *Scope:* Local audio capture, provider-independent speech-to-text (STT), provider-independent text-to-speech (TTS), and voice activity detection (VAD) / turn detection where required. User can conduct an explicitly initiated, consented bidirectional spoken conversation without wake word. Universal default TTS engine, STT adapter, and exact initiation UX remain OPEN DESIGN. Wake word detection is decoupled and scheduled for PC Later.
  - *Dependencies:* Speech audio pipeline is PARALLELIZABLE with scheduling/web streams. Conversational execution depends on the existing conversation/orchestrator baseline. Preferred Character Voice binding has an INTEGRATION DEPENDENCY on Character Configuration.
  - *Canonical Architecture Owner:* [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../04_Architecture/01_Domains/voice-and-audio.md).

- **Multilingual Companion Interaction:**
  - *Scope:* Interaction support across English, Tagalog, Japanese, and conversational code-switching (truthfully bounded by underlying model and speech capabilities; not a promise of full UI localization; language detection/switching logic remains OPEN DESIGN).
  - *Dependencies:* Depends on Local Text LLM inference baseline and voice pipeline where spoken.
  - *Canonical Architecture Owner:* [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../04_Architecture/01_Domains/assistant-and-conversations.md).

- **Optional Opt-In Cloud LLM Fallback:**
  - *Scope:* Strictly opt-in fallback with explicit user credentials, egress transparency, and local-first default. Automatic fallback triggers and routing remain OPEN DESIGN.
  - *Dependencies:* Depends on existing conversation orchestrator baseline; PARALLELIZABLE with other capability streams.
  - *Canonical Architecture Owner:* [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](../04_Architecture/04_Infrastructure/runtime-and-models.md).

- **PC Health-Context Readiness:**
  - *Scope:* Conceptual data contracts and storage readiness for health and wearable context within the Local AI Runtime; physical Health Connect integration belongs to Android V1; metric models and schema remain OPEN DESIGN.
  - *Dependencies:* Data contracts and storage readiness are PARALLELIZABLE.
  - *Canonical Architecture Owner:* [`docs/04_Architecture/03_Integrations/health-and-wearables.md`](../04_Architecture/03_Integrations/health-and-wearables.md).

#### 2.3.4 Resilience & Release Hardening Band (`PC V1`)
Focuses on operational reliability, data safety, and configuration boundaries:

- **Practical Backup & Recovery (`PC V1`):**
  - *Scope:* Practical backup and recovery that captures persistent database state and required referenced assets as a coordinated recoverable backup with verified restore integrity. Exact snapshot mechanism, archive format, compression, manifest schema, scheduling, and restore implementation remain OPEN DESIGN.
  - *Dependency Distinction:* Implementation of the backup and recovery mechanism MAY begin before every PC V1 persistent schema is finalized; however, final backup/restore compatibility, referential coherence, and integrity verification is a FINAL ACCEPTANCE DEPENDENCY against the complete PC V1 persistent data and referenced asset model.
  - *Implementation Reality:* Existing limited migration-backup foundation exists; full user-facing and general recovery capability is the remaining PC V1 deliverable.
  - *Canonical Architecture Owners:* [`docs/04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md`](../04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md) (primary) and [`storage-and-assets.md`](../04_Architecture/04_Infrastructure/storage-and-assets.md) (related storage layout & migrations).

- **Safe Restore Verification (`PC V1`):** Preflight validation of backup integrity, target environment checks, and referential validation before applying restored state.
- **Database Migration Safety Preflight (`PC V1`):** Preflight verification that validates migration compatibility and blocks unsafe, destructive, or unrecoverable migration conditions on existing user databases.
- **Secure Configuration & Authentication Boundary Hardening (`PC V1`):** Enforcing secure local credential handling, supported localhost / trusted LAN / Tailscale trust boundaries, and secure defaults.
- **Final Integrated Regression & Release Verification (`PC V1`):** Full-suite verification across backend, frontend, runtime, and integration tests prior to Golden Acceptance Gate entry.
- *(Governance Guardrail: Pre-Upgrade Database Snapshot remains in Section 6 as `RECOMMENDED PRE-V1 HARDENING — NOT YET SCHEDULED`; Diagnostics & Recovery Center remains `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED`. Target CI branch/event governance and failure-aggregation semantics are reconciled under Pass R12.4 in `docs/06_Guides/TESTING_AND_CI.md`; workflow YAML implementation remains a dedicated infrastructure task.)*
- *Canonical Architecture Owner:* [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md).

#### 2.3.5 Golden PC V1 Acceptance Gate (`PC V1 FINAL GATE`)
- **Integrated Golden PC V1 Acceptance Journey (`PC V1 FINAL GATE`):**
  - *Scope:* The comprehensive, end-to-end acceptance gate proving integrated companion behavior across 17 integrated Golden acceptance checkpoint groups covering all mandatory PC V1 capabilities (Startup/Host lifecycle, Controlled Local Model import, Character/Personality separation, Multilingual interaction, Selective Automatic Memory, Multimodal vision, Conversational Personal Actions under D9, Closed-browser native notifications, Time-critical Alarms, Bounded Routines, Conversational Voice with barge-in, Read-only public current info, Gaming/Low-Impact mode, PC Health-Context readiness, Restart persistence, Practical Backup & real restore integrity, and Local-Only core with optional cloud fallback).
  - *Prerequisites & Governance:* All mandatory PC V1 capability groups across Foundation, Capability, and Resilience bands must be complete and verified before gate entry. Canonical acceptance checkpoints, portability invariants, and pass/fail semantics are defined in [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) §8. Successful completion of this gate is the mandatory final acceptance prerequisite for cutting the PC V1 release tag.
  - *Canonical Architecture Owner:* [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) §8.

---

## 3. AI Companion V1 Scope Boundary (Decision D1)

AI Companion **V1** (unqualified) is strictly defined as the first complete, stable **PC-hosted release**. Follow-on mobile capabilities (Android V1) and later enhancements (PC Later) are independent releases and do **not** block PC V1.

### 3.1 In Scope for PC V1 (Capability-Level)
1. **Local AI Runtime:** Independent long-running Windows host process operating locally (Decision D2). The runtime architecture is provider- and hardware-portable; the current `llama.cpp` Vulkan GPU offload on AMD RX 580 represents the verified reference baseline implementation, not an eternal hardware lock.
   - *Implementation Status:* Implemented Baseline + Foundation Host/Runtime extensions.
   - *Delivery Band:* Foundation Band (Host & Runtime Lane).
2. **React Web Primary Client:** Primary desktop control center, runtime configuration, model controls, and streaming chat interface.
   - *Implementation Status:* Existing Baseline + remaining Phase 8C work.
   - *Delivery Band:* Phase 8C Integration & Polish.
3. **Local Text LLM Inference:** Provider- and hardware-portable local text generation through the Local AI Runtime (`llama.cpp` Vulkan on AMD RX 580 represents the verified baseline implementation).
   - *Implementation Status:* Implemented / Verified Baseline.
   - *Delivery Band:* Implemented Baseline.
4. **Conversations & Memory:**
   - Multi-turn conversation management with live SSE token streaming and transactional pre-stream turn binding.
   - Profile-first persistent and retrievable memory under canonical user ownership (Decision D7). SQLite persistence with FTS5 lexical keyword retrieval represents the verified implementation baseline, not an eternal architectural constraint.
   - Selective automatic and assistant-proposed memory capture under deterministic policy with user visibility, inspection, correction, and deletion controls (sensitive, ambiguous, or transient statements must not silently become permanent facts; extraction model, confidence logic, cadence, and schema remain OPEN DESIGN).
   - *Implementation Status:* Implemented Baseline + Foundation gaps for Memory scoping and selective automatic memory.
   - *Delivery Band:* Foundation Band (Companion & Policy Lane).
5. **Tasks, Reminders, Alarms & Bounded Routines:** Distinct entity semantics under Decision D10.
   - Task CRUD, soft-delete, and retention thresholds are implemented and verified in the baseline.
   - Scheduled reminder execution with catch-up logic, time-critical alarm alerts with best-effort wake, quiet hours with per-item overrides (without universal automatic all-alarm bypass; exact default Alarm urgency behavior remains OPEN DESIGN), and bounded companion routines under deterministic scheduler proactivity (character layer controls phrasing; scheduler engine and schemas remain OPEN DESIGN).
   - *Implementation Status:* Implemented Task CRUD/retention baseline + remaining scheduling, alerting, and routine delivery gaps.
   - *Delivery Band:* Capability Band (Scheduling & Routines).
6. **Model Library & Runtime Management:** Schema v3 registry, GGUF binary header parsing, runtime offload profiles (Eco/Balanced/Maximum), logical model vs. artifact separation.
   - *Implementation Status:* Implemented Baseline; D6 import execution gap handled separately.
   - *Delivery Band:* Implemented Baseline (Host & Runtime Lane for D6 import gap).
7. **Controlled Local Model Import Pipeline:** Deterministic import flow: `inbox` → `preflight` → `staging` → `atomic install` → `library` → `registry` (Decision D6). Completing the execution service is an approved PC V1 implementation gap. Supported model artifact formats and exact import execution mechanisms remain OPEN DESIGN.
   - *Implementation Status:* Schema v3 registry and model metadata baseline verified; import execution service is an approved PC V1 gap.
   - *Delivery Band:* Foundation Band (Host & Runtime Lane).
8. **Multimodal Vision Understanding:** Phase 8B image attachment API, upload validation guards (MIME, dimension, megapixel, bomb guards), and vision-model inference.
   - *Implementation Status:* Current In-Flight Phase 8B (8B.0–8B.6 verified, 8B.7 next, 8B.8 planned); completion is a Final Acceptance Dependency for PC V1.
   - *Delivery Band:* Current In-Flight Phase 8B.
9. **Phase 8C Integration, Accessibility & Polish:** Comprehensive keyboard navigation, ARIA accessibility, bundle optimization, UI consistency, elimination of deprecated mock files, and responsive desktop web cleanup.
   - *Implementation Status:* Planned / hard-depends on Phase 8B; completion is a Final Acceptance Dependency for PC V1.
   - *Delivery Band:* Phase 8C Integration & Polish.
10. **Conversational Voice (without Wake Word):** Local audio capture, provider-independent speech-to-text (STT), provider-independent text-to-speech (TTS), and voice activity detection (VAD) / turn detection where required. User can conduct an explicitly initiated, consented bidirectional spoken conversation without wake word. Universal default TTS engine, STT adapter, and exact initiation UX remain OPEN DESIGN. Wake word detection is decoupled and scheduled for PC Later.
    - *Implementation Status:* Not Started.
    - *Delivery Band:* Capability Band (Voice).
11. **Character Persistence, Personality & Lightweight Conceptual Emotion:**
    - Persistent Character configuration target under PC host authority (conversations already persist `character_id`; persistent Character config schema and runtime prompt resolution remain the PC V1 gap; schema remains OPEN DESIGN; Decision D11).
    - Separate Personality configuration for behavioral style and communication traits decoupled from character lore (Decision D11).
    - Lightweight conceptual Emotion state providing transient mood modulation without clinical or psychological claims (state dimensions, decay behavior, and transition dynamics remain OPEN DESIGN / later work; Decision D11).
    - *Implementation Status:* Existing conversation character binding baseline + remaining persistent config and runtime-resolution capability.
    - *Delivery Band:* Foundation Band (Companion & Policy Lane).
12. **Multilingual Companion Interaction:** Interaction support across English, Tagalog, Japanese, and conversational code-switching (truthfully bounded by underlying model and speech capabilities; not a promise of full UI localization; language detection/switching logic remains OPEN DESIGN).
    - *Implementation Status:* Model-native multilingual interaction exists as baseline behavior; explicit multilingual routing/evaluation and PC V1 verification remain target work.
    - *Delivery Band:* Capability Band (Multilingual).
13. **Safe Typed Conversational Actions:**
    - Deterministic DEFAULT DENY action execution engine under the canonical 5-stage pipeline: Model → Typed Request → Deterministic Policy → Narrow Adapter → Capability (Decision D9).
    - Four-tier risk matrix (Risk 0–3): Risk 0 and approved Risk 1 actions (e.g., personal reads, creating personal tasks/reminders) may auto-execute only when policy resolves ALLOW. Retains deterministic ALLOW / CONFIRM / DENY outcomes. Deterministic 5-stage policy pipeline is a HARD DEPENDENCY only for exposing tool/action execution to generative/model invocation; underlying scheduler, persistence, and read-only provider adapters can be developed independently. Confirmation dialogs, token limits, and audit log persistence remain OPEN DESIGN. Arbitrary command shell / PowerShell is permanently REJECTED.
    - *Implementation Status:* Architecture and policy pipeline locked; engine implementation pending.
    - *Delivery Band:* Foundation Band (Companion & Policy Lane).
14. **Read-Only Public Current Information:** Provider-independent `WebSearch`, `Fetch`, and weather/public-information capabilities with SSRF/network containment, untrusted external content handling, privacy minimization, source provenance, and credential isolation from client/prompt context. Specific services (e.g., Tavily, Open-Meteo) remain candidate adapters. Model invocation requires Decision D9 policy. Interactive browser automation is decoupled and scheduled for PC Later.
    - *Implementation Status:* Not Started.
    - *Delivery Band:* Capability Band (Public Information).
15. **Optional Cloud LLM Fallback:** Strictly opt-in fallback with explicit user credentials and egress transparency; local inference remains default and primary, and full local-only operation remains fully supported. Automatic fallback triggers and routing remain OPEN DESIGN.
    - *Implementation Status:* Architecture locked; implementation pending.
    - *Delivery Band:* Capability Band (Cloud Fallback).
16. **Windows Host Autostart at Login:** Local AI Runtime configured to start automatically on Windows user login (Decision D2; exact Windows launch mechanism remains OPEN DESIGN).
    - *Implementation Status:* Not Started.
    - *Delivery Band:* Foundation Band (Host & Runtime Lane).
17. **Native Windows Notification Delivery:** Direct OS notification delivery decoupled from open browser tabs (Decisions D2 and D10; ensures reminders, alarms, and routines alert the user even when the browser client is closed; integration dependency for closed-browser alerting; exact notification adapter remains OPEN DESIGN).
    - *Implementation Status:* Not Started.
    - *Delivery Band:* Foundation Band (Host & Runtime Lane).
18. **Gaming / Low-Impact Resource Policy:** Ability to enter a lower-impact resource policy during heavy foreground workloads while preserving required companion behavior and notification integrity (exact detection, throttling, pausing, GPU offload layer adjustments, CPU thread limits, and automatic versus manual activation remain OPEN DESIGN).
    - *Implementation Status:* Existing model/profile foundations + remaining workstation resource-policy capability where supported by current source truth.
    - *Delivery Band:* Foundation Band (Host & Runtime Lane).
19. **Practical Backup & Recovery:** Practical backup and recovery that captures persistent database state and required referenced assets as a coordinated recoverable backup with verified restore integrity. Implementation may begin before the complete PC V1 schema is finalized; final backup/restore compatibility, referential coherence, and integrity verification is a FINAL ACCEPTANCE DEPENDENCY against the complete PC V1 persistent data and referenced asset model. Exact snapshot mechanism, archive format, compression, manifest schema, scheduling, and restore implementation remain OPEN DESIGN; Diagnostics & Recovery Center remains an audit recommendation requiring separate approval, not an automatic PC V1 requirement.
    - *Implementation Status:* Existing limited migration-backup foundation + remaining user-facing/general recovery capability.
    - *Delivery Band:* Resilience & Release Hardening Band.
20. **PC Health-Context Readiness:** Conceptual data contracts and storage readiness for health and wearable context within the Local AI Runtime; physical Health Connect integration belongs to Android V1; metric models and schema remain OPEN DESIGN.
    - *Implementation Status:* Architecture locked; implementation pending.
    - *Delivery Band:* Capability Band (Health Readiness).
21. **Release Hardening & Verification:** Secure configuration defaults, migration safety preflight, and CI pipeline stability verified before release.
    - *Implementation Status:* Preflight baseline exists; release hardening pending.
    - *Delivery Band:* Resilience & Release Hardening Band.
22. **Integrated Golden PC V1 Acceptance Journey:** End-to-end companion verification path proving seamless operation across 17 integrated Golden acceptance checkpoint groups covering all mandatory PC V1 capabilities. Mandatory release gate; normative requirements and pass/fail semantics codified in [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) §8.
    - *Implementation Status:* Mandatory PC V1 release gate; normative specification codified in `SYSTEM_BASELINE.md` §8 (delivery status remains `APPROVED` / `NOT STARTED` pending implementation and release execution).
    - *Delivery Band:* Golden PC V1 Acceptance Gate.

> [!NOTE]
> Follow-on release scopes (Android V1, PC Later, Future / Unscheduled) and rejected capabilities are detailed in Section 4.

---

## 4. Follow-On & Later Release Tracks

### 4.1 Follow-On Mobile Release: Android V1
Android V1 is the follow-on production mobile companion release (`com.cnl.aicompanion`; Decision D3). It is an independent milestone and does **not** block PC V1.
- **Production Application Identity:** Package namespace and application ID: `com.cnl.aicompanion` (Decision D3).
- **Trusted Device Credentials:** Secure Android Keystore storage and per-device revocable credentials (Decision D4).
- **Authenticated Connected Synchronization:** Two-way sync with PC Local AI Runtime as the canonical persistent authority over trusted LAN / Tailscale.
- **Durable Mobile Persistence:** Local Room database with offline outbox queuing.
- **Practical Compact Offline Local LLM:** Roaming local text inference via a practical compact model. Model family, format (GGUF or alternative runtime), parameter size, and quantization remain **OPEN DESIGN**; reference hardware benchmarks are evidence only.
- **Mobile Scheduling:** Local Tasks, Reminders, and platform-appropriate notifications and alarms.
- **Character & Personality Continuity:** Synchronized from the PC host (Decision D11).
- **Android Health Connect Integration:** Android Health Connect integration for wearable and biometric context summaries.
- **Reconnection & State Reconciliation:** Deterministic state reconciliation against PC host database upon reconnecting (exact sync conflict algorithm remains **OPEN DESIGN**).
- *Canonical Architecture Owners:* [`docs/04_Architecture/01_Domains/android-companion.md`](../04_Architecture/01_Domains/android-companion.md), [`health-and-wearables.md`](../04_Architecture/03_Integrations/health-and-wearables.md).

### 4.2 Post-PC-V1 Tracks: PC Later
The capability tracks below represent approved PC Later features scheduled for milestones following PC V1. Explicitly labeled conditional security or design boundaries in this section are guidance only and do not constitute committed delivery milestones. Execution ordering among committed tracks is not locked and will be sequenced in subsequent planning:
- **Wake Word Detection:** Background wake phrase listening (`WakeWordProvider`, candidate openWakeWord); decoupled from PC V1 conversational voice.
  - *Canonical Owner:* [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../04_Architecture/01_Domains/voice-and-audio.md).
- **Relationship State:** Separate, opt-in, and hidden by default; strictly decoupled from Emotion and Personality (Decision D11).
  - *Canonical Owner:* [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md).
- **Richer Emotion Models:** Advanced multi-dimensional emotional state dynamics.
  - *Canonical Owner:* [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md).
- **Advanced Presence:** Live2D / VRM / contextual presentation state.
  - *Canonical Owner:* [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md).
- **Interactive Browser Automation:** Automated form filling, authenticated navigation, and web interaction (e.g., local Playwright provider); decoupled from PC V1 read-only current information.
  - *Canonical Owner:* [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md).
- **Native Desktop Shell:** Dedicated container packaging (e.g., Tauri, Electron) and system tray minification.
  - *Canonical Owner:* [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md).
- **Semantic / Vector Memory:** Vector embeddings, semantic similarity search, hybrid FTS5 + vector retrieval, and long-term memory consolidation (FTS5 remains the verified PC V1 baseline).
  - *Canonical Owner:* [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](../04_Architecture/01_Domains/memory-and-personalization.md).
- **Managed Online Model Downloading:** In-app browsing and background downloading from public model hubs (e.g., Hugging Face); exact downloader and hub integration remain open design.
  - *Canonical Owner:* [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](../04_Architecture/04_Infrastructure/runtime-and-models.md).
- **Narrow, Typed Privileged Actions (Conditional Security Boundary — NOT A COMMITTED DELIVERY MILESTONE):** If future elevated actions are ever separately evaluated and approved, they must be strictly narrow, typed, bounded, explicitly authorized, and auditable. Generic arbitrary shell / PowerShell / unrestricted OS administration remains permanently REJECTED. Speculative privileged tools are not a scheduled release milestone.
  - *Canonical Owner:* [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md).

### 4.3 Evaluated / Experimental: Future / Unscheduled
Capabilities in this category are evaluated or experimental without committed release scheduling. They must not be promoted to committed release milestones without formal review:
- **Stable Diffusion Presence Renderer:** Intent: `EXPERIMENTAL`; Delivery: `NOT STARTED`; Release: `FUTURE / UNSCHEDULED`. Evaluated as an exploratory generative visual option; distinct from advanced Presence.
  - *Canonical Owner:* [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../04_Architecture/01_Domains/multimodal-and-media.md).
- **Multi-Profile Architecture:** Intent: `PROVISIONAL`; Delivery: `NOT STARTED`; Release: `FUTURE / UNSCHEDULED`. The ecosystem operates as a single-primary-user system (`owner_id` preserves the Profile boundary; Decision D8); multi-profile support remains a possible future architectural consideration without an approved delivery commitment.
  - *Canonical Owner:* [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../04_Architecture/02_Data_and_Security/profiles-and-devices.md).
- **Android Device-Local TTS:** Intent: `EXPERIMENTAL`; Delivery: `NOT STARTED`; Release: `FUTURE / UNSCHEDULED`. Historical optional idea only ("where feasible"). Not an Android V1 requirement, and not currently committed to Android Later.
  - *Canonical Owner:* [`docs/04_Architecture/01_Domains/android-companion.md`](../04_Architecture/01_Domains/android-companion.md).

### 4.4 Rejected / Outside Supported Trust Model
The following capabilities are explicitly excluded from ordinary assistant capability or supported trust model:
- **Generic Command Shell / OS Administration:** Arbitrary command shell / PowerShell / unrestricted filesystem or operating system administration is **PROHIBITED** as a generic assistant tool under Risk Tier 3 (DEFAULT DENY) and is permanently **REJECTED** as an ordinary capability (Decision D9).
- **Direct Public Internet Exposure / Port Forwarding:** Direct public exposure and router port forwarding are outside the supported trust model (Decision D5). Network access is strictly bounded to Localhost, trusted LAN, and Tailscale mesh.
- **Unbounded Autonomous Looping:** Unconstrained recursive agent execution without human intervention is prohibited.

---

## 5. Open Technical Designs & Decisions

The following architectural directions are approved, while their specific technical designs remain deliberately open for future milestone planning:

1. **Android Sync Conflict Algorithm (`OPEN DESIGN`):** PC host remains canonical persistent authority per the Android / profile / runtime architecture; exact conflict resolution algorithm (last-write-wins vs. field-level merge vs. user prompt) remains open.
2. **Device Pairing Protocol (`OPEN DESIGN`):** Per-device revocable credentials locked (Decision D4); exact enrollment UX (QR code, numeric phrase, LAN discovery) and cryptographic handshake remain open.
3. **Windows Host Process Launcher (`OPEN DESIGN`):** Decoupled background runtime locked (Decision D2); exact mechanism (Windows Service, scheduled task, startup shortcut, or native launcher) remains open.
4. **Mobile Model Selection (`OPEN DESIGN`):** Tested envelope (~0.27B–1.24B) demonstrated viable; permanent model candidate, quantization format, and minimum hardware tier remain open.
5. **TTS Provider & Default Selection (`OPEN DESIGN`):** Provider abstraction locked. PC conversational voice provider and default engine selection remain OPEN DESIGN pending formal voice benchmarking. Android device-local TTS remains EXPERIMENTAL / FUTURE / UNSCHEDULED; any on-device mobile TTS provider selection becomes relevant only if that capability is separately evaluated, approved, and scheduled.
6. **Tool Permission Schema & Confirmation UI (`OPEN DESIGN`):** 4-tier risk matrix locked (Decision D9); exact confirmation UI dialogs, token limits, and audit log persistence schema remain open.
7. **Llama-Server Crash Recovery Policy (`OPEN DESIGN`):** Need for crash recovery recognized; exact retry limits, exponential backoff, and driver-hang timeouts remain open.

---

## 6. Technical Hardening Recommendations (Audit Findings)

The following items from the technical reconciliation audit represent valuable operational improvements. They are classified accurately to avoid premature scope lock:

| Recommendation | Classification | Prerequisite / Governance Notes |
| :--- | :--- | :--- |
| **CI Gate Failure Aggregation** | `APPROVED PRE-V1 GOVERNANCE TARGET (P25)` | Target governance and failure-aggregation semantics codified in Pass R12.4 ([`docs/06_Guides/TESTING_AND_CI.md`](../06_Guides/TESTING_AND_CI.md)). Workflow YAML implementation remains a dedicated infrastructure task; documented target governance $\ne$ workflow implemented/verified. Must precede enabling CI Gate as a required status check on GitHub. |
| **Pre-Upgrade Database Snapshot** | `RECOMMENDED PRE-V1 HARDENING — NOT YET SCHEDULED` | Automatic snapshot of `companion.db` prior to running pending Alembic migrations. |
| **Backup & Restore UI** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Web settings interface to trigger manual snapshots and inspect backup health. |
| **Diagnostics & Recovery Center** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Web UI panel displaying runtime health, router logs, and crash diagnostic dumps. Evaluated as an exploratory diagnostic aid; not an automatic PC V1 requirement. |
| **Disk Capacity & Quota Guards** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Pre-import free disk space checks to prevent model download/import exhaustion. |
| **Dependency Lock Workflow** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Formalized pip-compile / poetry lockfile governance for backend dependencies. |
| **API Rate Limiting & Throttling** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Protection against high-frequency local request loops on protected endpoints. |
