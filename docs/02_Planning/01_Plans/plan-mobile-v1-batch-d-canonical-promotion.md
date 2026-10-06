# Implementation Plan: Mobile V1 Batch D Canonical Promotion

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Awaiting Approval
- Scope Mode: Documentation / Canonical Architecture Promotion — Systematic staged promotion of approved MOBILE-ARCH Batch D product and architecture decisions into canonical architecture, design specifications, and master planning spine.
- Target Files:
  - Batch D2:
    - `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
    - `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
    - `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`
    - `docs/04_Architecture/01_Domains/android-companion.md`
    - `docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`
  - Batch D3:
    - `docs/04_Architecture/SYSTEM_BASELINE.md`
    - `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`
    - `docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`
    - `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`
    - `docs/04_Architecture/01_Domains/assistant-and-conversations.md`
    - `docs/04_Architecture/01_Domains/memory-and-personalization.md`
    - `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`
    - `docs/04_Architecture/03_Integrations/web-current-information.md`
  - Batch D4:
    - `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
    - `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`
    - `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
    - `docs/04_Architecture/01_Domains/memory-and-personalization.md`
    - `docs/04_Architecture/01_Domains/assistant-and-conversations.md`
    - `docs/04_Architecture/01_Domains/voice-and-audio.md`
    - `docs/04_Architecture/03_Integrations/health-and-wearables.md`
    - `docs/04_Architecture/01_Domains/multimodal-and-media.md`
    - `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`
    - `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md` (New proposed design specification)
  - Batch D5:
    - `docs/02_Planning/00_Master/MOBILE_WBS.md`
    - `docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`
    - `docs/02_Planning/00_Master/MASTER_CHECKLIST.md`
    - `docs/02_Planning/00_Master/DECISION_REGISTER.md`
    - `docs/02_Planning/00_Master/SPRINT_ROADMAP.md`
    - `docs/02_Planning/00_Master/DELIVERY_INDEX.md`
    - `docs/02_Planning/00_Master/DECISION_DEBT.md`
    - `docs/06_Guides/DOCUMENTATION_MAP.md`
    - `docs/03_Walkthroughs/walkthrough-mobile-v1-batch-d-reconciliation.md` (New delivery walkthrough)
    - `CHANGELOG.md`
    - Full PR trailing-whitespace mechanical cleanup across all modified PR files blocking Docs Integrity.

Notice: Update this plan in place during planning. After plan approval by Chris and GPT, live execution tracking switches to `docs/01_Tracking/active/task-docs-mobile-v1-canonicalization.md` and this plan is reopened only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### 1.1 Primary Objective

Promote the independently reviewed and approved MOBILE-ARCH Batch D decisions into the correct canonical architecture, design, planning, verification, and closure documents without creating parallel authority, overstating implementation status, or losing existing PC/shared architecture invariants.

The result will re-close MOBILE-ARCH truthfully, align canonical specifications with approved product decisions, expand the Mobile Work Breakdown Structure (WBS) and Mobile Golden verification criteria (MG1–MG18), clean trailing whitespace blocking Docs Integrity CI across the PR diff, and make Pull Request #21 ready for final independent Closure Gate review and merge.

### 1.2 Concrete Deliverables

1. **Batch D2 Canonical Architecture Promotion:** Update 5 foundational architectural files establishing orthogonal availability states, device enrollment and one-device-to-one-profile lifecycle, core survival without generative AI, PC Host Admin authority, offline-authorable Mobile Reminders and Alarms, protected Host definitions, bounded Routine occurrence presentation without autonomous recurrence, shared temporal intent semantics, and Flutter shared-core workspace boundaries without freezing exact package names.
2. **Batch D3 AI Runtime & Context Canonical Promotion:** Update 8 runtime, conversation, memory, and tool specifications establishing the real local LLM V1 product path for qualified devices (with core surviving without it), max 1 resident generative model, progressive truthful Resource Governor without invented fixed tiers or RAM floors, authoritative raw transcripts, derived-only summaries, preserved "NOT IMPLEMENTED" statuses, pending memory intents as outbox submissions to PC Host, causal conversation branching without Last-Write-Wins (LWW), and D9 Mobile Standalone Tool Gateway boundaries.
3. **Batch D4 Voice, Health, Vision, Character & Mobile UX Promotion:** Update 9 domain/infrastructure specifications and author 1 new canonical design document (`docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`) establishing independent composable Voice routing with mandatory barge-in, conditional read-only Health Connect V1, conditional still-image Vision V1 with shared attachment pipeline, PC Character authority with Emotion Event sync to Host and emoji fallback, and the 5-tab companion shell with hybrid visual design tokens.
4. **Batch D5 Master Planning Spine, Golden Verification & PR Closure:**
   - Expand `MOBILE_WBS.md` from its current 65 items as required by promoted architecture, deriving exact task counts and new stable IDs during D5 while preserving existing stable IDs.
   - Expand `MOBILE_CHECKLIST.md` to the exact locked MG1–MG18 structure with explicit qualification classes (`REQUIRED`, `CONDITIONAL`, `OPTIONAL`, `DEFERRED`).
   - Synchronize `MASTER_CHECKLIST.md`, `DECISION_REGISTER.md` (preserving accepted ADRs ADR-0001 through ADR-0012, ADR-0017, ADR-0018, ADR-0019), `SPRINT_ROADMAP.md`, `DELIVERY_INDEX.md`, `DECISION_DEBT.md` (indexing `DEBT-MOB-MULTI-DEVICE` as OPEN / DECISION DEBT), and `DOCUMENTATION_MAP.md`.
   - Perform full-PR mechanical trailing-whitespace cleanup across all PR-modified files against `develop` to restore green Docs Integrity CI.
   - Author point-in-time delivery walkthrough `docs/03_Walkthroughs/walkthrough-mobile-v1-batch-d-reconciliation.md` and append changelog entry to `CHANGELOG.md`.
   - Present final PR #21 description update proposal upon independent Closure Gate approval.

### 1.3 Explicit Non-Goals & Scope Guardrails

This implementation plan strictly enforces the following project guardrails:
- **No Git Mutations by AI Agents:** Chris remains the sole owner of all Git mutations (`add`, `commit`, `push`, `branch`, `merge`, `rebase`, `reset`, `stash`, `tag`, and PR creation/updates). The agent inspects, edits files, runs checks, and proposes commit messages only.
- **No Production Code Implementation:** This is a documentation, architecture, and planning delivery only. It does NOT implement Flutter Desktop, Flutter Mobile, Android Kotlin production code, backend FastAPI code, database migrations, or CI workflow changes.
- **No Premature M1 Execution:** Flutter Desktop M1 scaffolding and implementation MUST NOT begin until MOBILE-ARCH Batch D is independently approved and re-closed.
- **No Invention of Unapproved Architecture:** Every canonical edit must trace directly to an approved decision in `MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md` or an existing canonical invariant.
- **No Erasure of Implementation Truth:** Documentation must truthfully distinguish implemented reality from target architecture. Implemented code in `frontend/web/` and `src/` retains its current state; "NOT IMPLEMENTED" statuses remain explicit; the Kotlin Android app in `android/` remains prototype/reference evidence only.
- **No Benchmark Data Promotion as Architecture:** Benchmark data in `MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md` serves as non-canonical empirical qualification evidence only and must not turn specific benchmark numbers or retail phone models into permanent architecture requirements.

---

## 2. Current Findings & Technical Root Cause

### 2.1 Verified Starting State

- **Repository:** `chrisniel/AI-companion-project`
- **Active Branch:** `docs/mobile-v1-canonicalization`
- **Current HEAD SHA:** `5ce5633a088d132deb4c72792fb12dc5a9764ced`
- **Working Tree State:** Clean (no uncommitted or untracked changes).
- **PR #21 Status:** Open in Draft status, pointing to branch `docs/mobile-v1-canonicalization`.

### 2.2 Authority & Change-Control Hierarchy

During this reconciliation, whose explicit purpose is to supersede and refine stale Mobile canonical text, all edits must strictly adhere to the following normative change-control hierarchy:

| Level | Source Artifact | Normative Role & Governance Rule |
| :--- | :--- | :--- |
| **Level A** | **Source Code / Generated Contracts / Automated Tests** | Authority for **CURRENT IMPLEMENTED REALITY** only. Never invent implemented reality from documentation. |
| **Level B** | **Accepted Shared/PC Canonical Architecture & Accepted ADRs** | Durable shared normative authority unless explicitly reopened. Includes accepted ADRs: ADR-0001 through ADR-0012, ADR-0017, ADR-0018, ADR-0019 (ADR-0013 through ADR-0016 remain historical/unaccepted). |
| **Level C** | **Approved Batch D Decision Ledger (`MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md`)** | **Authoritative approved working source** for the intended Mobile and shared changes within the reopened MOBILE-ARCH scope. Stale Mobile canonical text cannot override this approved working source. |
| **Level D** | **Existing Mobile Batch A–C Canonical Docs** | Remain valid wherever not explicitly superseded or refined by approved Batch D decisions. |
| **Level E** | **Reconciliation Report (`MOBILE_ARCH_BATCH_D_RECONCILIATION_REPORT.md`)** | Audited mapping and evidence inventory; not an independent normative authority. |
| **Level F** | **Benchmark Evidence (`MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md`) & Kotlin Prototype (`android/`)** | Research and reference evidence only. Never cited as normative architectural requirements. |

### 2.3 Reconciliation Audit Summary

The audited reconciliation report (`MOBILE_ARCH_BATCH_D_RECONCILIATION_REPORT.md`) establishes the exact scope of required canonical promotions:
- **Prior Canonical State vs. Batch D Commitment:** The older Batches A–C architecture classified Mobile local inference as `OPTIONAL-AUXILIARY` (it did not strictly "forbid" local LLM, but treated it as an uncommitted auxiliary option). Batch D changes this product commitment:
  1. Mobile V1 **MUST** include a production-capable local LLM path for qualified devices.
  2. Individual supported phones do **NOT** all need to qualify.
  3. Core Mobile still works without local generative AI (`D-PHONE-02`).
- **Audit Findings:** 27 items agreed, 71 canonical gaps to promote, 7 direct contradictions to supersede, 1 implementation status to preserve ("NOT IMPLEMENTED" rolling compaction), 2 stale planning items to expand, and 1 prototype difference retained as reference evidence.
- **No Missing Approved Decisions:** All 109 Batch D decisions are resolved and ready for systematic promotion.

---

## 3. Proposed File Changes & In-Place Logic

### 3.1 Batch D2 — Core Baseline, Identity, Offline Scheduling & Flutter Boundaries

**Goal:** Establish foundational Mobile operating-state semantics, enrollment lifecycle, one-device-to-one-profile binding, core survival without generative AI, offline scheduling authority, cross-device alert arbitration, Routine occurrence behavior, temporal intent resolution, and stable Flutter/shared boundaries.

**Approved Decision Groups:**
`D-PHONE-01A`, `D-PHONE-01B`, `D-PHONE-02`, `D-SHARED-SCHED-01`, `D-PHONE-10`, `D-PHONE-11`, `D-SHARED-SCHED-02`, `D-SHARED-SCHED-03`, `D-SHARED-SCHED-04`, `D-SHARED-SCHED-04A` through `D-SHARED-SCHED-04E`, `D-PHONE-12`, `D-PHONE-12A` through `D-PHONE-12C`, `D-SHARED-FLUTTER-01` through `D-SHARED-FLUTTER-08`, `D-PHONE-FLUTTER-01`.

#### [MODIFY] `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
- **Primary Responsibility:** Normative baseline for Mobile client architecture, operational states, and ecosystem relationships.
- **Planned Changes:**
  - Update Section 1 & Section 3 to define the 3 orthogonal availability axes (`D-PHONE-01A`): PC Host Reachability (Local LAN / Encrypted Overlay / Unreachable), Internet Reachability (Available / Unavailable), and Inference Route (Local On-Device / PC Host / Cloud / None). Standalone Mobile is explicitly defined as an operational state, not an application failure.
  - Define Device Enrollment & One-Device-to-One-Profile Lifecycle (`D-PHONE-01B`): Enrolled mobile device binds strictly to exactly 1 Profile. Mobile client cannot create, switch, or manage multi-profiles. Pairing direction establishes explicit authorized Host enrollment and QR/code UX direction, while exact cryptographic handshake payloads remain implementation-open.
  - Document that One Profile → Multiple Phones remains **OPEN / DECISION DEBT** (it is NOT approved as deferred or post-V1).
  - Define Core Companion Survival (`D-PHONE-02`): Core Mobile companion functionality (alarms, reminders, schedules, cached notes, companion presence shell) survives completely without local generative AI.
  - Document Flutter client architecture baseline (`D-SHARED-FLUTTER-01` to `08`, `D-PHONE-FLUTTER-01`): Monorepo shared workspace with separate Desktop and Mobile app targets; shared stable domain, contracts, controller, and design primitives where appropriate; platform adapters strictly isolated; platform-specific screen composition allowed. Exact package names and count remain implementation-open (no pre-freezing unapproved package names). Explicitly note that `android/` Kotlin code is legacy prototype reference only.
- **Invariants to Preserve:** PC Host remains master administrator and root of trust; Android platform protection; Android Keystore for private keys.

#### [MODIFY] `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
- **Primary Responsibility:** Mobile offline mutation handling, synchronization protocols, and conflict resolution.
- **Planned Changes:**
  - Incorporate Mobile Outbox protocol for offline-created Reminders, Alarms, and pending intents (`D-PHONE-10`, `D-PHONE-11`).
  - Document Synchronization Conflict Semantics without universal "server-wins" rule:
    - Host-issued entity revisions and base-revision optimistic concurrency checks.
    - Explicit typed `CONFLICT_DETECTED` status when concurrent conflicting mutations occur.
    - Local unsynced work is retained for user-visible resolution in the Activity Inbox rather than silently overwritten.
    - Desired-state idempotency where approved by domain contracts.
    - Tombstones prevent resurrection of deleted entities.
    - Explicitly forbid timestamp-based Last-Write-Wins (LWW) reconciliation.
  - Define sync replay and idempotency guarantees across transport reconnection.
- **Invariants to Preserve:** Cryptographic payload verification; revision cursors; profile isolation during sync.

#### [MODIFY] `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`
- **Primary Responsibility:** Domain semantics for Tasks, Reminders, Alarms, and Routines.
- **Planned Changes:**
  - Authoritative Scheduling Ownership (`D-SHARED-SCHED-01`): PC Host owns recurring schedule definition, evaluation, and mutation.
  - Offline-Authorable Mobile Reminders (`D-PHONE-10`): Mobile user can author reminders offline; queued in local outbox with temporary client UUID; synchronized upon reconnection.
  - Offline-Authorable Mobile Alarms (`D-PHONE-11`): Mobile user can set/edit device-local alarms offline; fired via native Android `AlarmManager` exact alarms.
  - Protected Host Definitions (`D-SHARED-SCHED-03`): Complex PC-created automation, reminders, and alarm definitions remain read-only on mobile when offline; protected against unauthorized mobile mutation.
  - Cross-Device Alert Arbitration (`D-SHARED-SCHED-02`):
    - Reminders: favor duplicate suppression across devices.
    - Alarms: favor reliability; primary presentation rings first; standby device remains armed; explicit dismiss/snooze/acknowledgement propagates across devices; passive display does NOT equal acknowledgement; bounded standby escalation may occur; when disconnected, duplicate Alarm ringing is strictly preferable to a missed Alarm. Exact grace period and transport mechanics remain implementation-open.
  - Routine Occurrence Caching & Presentation (`D-PHONE-12`, `12A`, `12C`, `D-SHARED-SCHED-04`, `04A`): Mobile replicates and caches bounded upcoming Host-authorized routine occurrences for presentation and execution; mobile does NOT run autonomous background recurrence extension. Replicated occurrence horizon remains bounded, with exact horizon open. Routine notification and occurrence dismissal semantics (`D-PHONE-12C`).
  - Routine Canonical Authoring (`D-PHONE-12B`): Canonical Routine authoring and modification remains Host-mediated; mobile authoring while connected uses Host APIs under Decision D9.
  - Temporal Intent Resolution (`D-SHARED-SCHED-04` through `04E`):
    - `D-SHARED-SCHED-04`: Temporal Intent Resolution.
    - `D-SHARED-SCHED-04A`: Field-level ambiguity and clarification rules.
    - `D-SHARED-SCHED-04B`: Recurrence classification across one-shot, floating-local, and fixed-timezone recurrence.
    - `D-SHARED-SCHED-04C`: Stricter Alarm temporal specificity requirements.
    - `D-SHARED-SCHED-04D`: PC and Mobile semantic parity enforced using shared Golden test vectors (does not require identical parser code).
    - `D-SHARED-SCHED-04E`: Context, preference, and history clarification priority.
  - Scope Guardrail: Do NOT introduce unapproved Quick Capture notes or audio memos under these Routine decisions.
- **Invariants to Preserve:** Existing PC scheduler engine invariants; deterministic trigger evaluation; notification priority channel mappings.

#### [MODIFY] `docs/04_Architecture/01_Domains/android-companion.md`
- **Primary Responsibility:** Android platform specifics and native integration boundaries.
- **Planned Changes:**
  - Re-scope file as the Android Platform Adapter specification under Flutter (not standalone Kotlin production app).
  - Document generic Android platform adapter boundaries required for Batch D2: `AlarmManager` exact alarms (`SCHEDULE_EXACT_ALARM`), Keystore secure storage wrapper, process death recovery, and Doze lifecycle handling.
  - Keep Batch D2 and Batch D4 boundaries clean: Do NOT promote D4 Health Connect or Voice-specific architecture in this D2 pass.
  - State clearly that `android/` Jetpack Compose code is reference prototype evidence only.
- **Invariants to Preserve:** Android permission requirements; battery optimization (Doze) compliance; native foreground service notification requirements.

#### [MODIFY] `docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`
- **Primary Responsibility:** Profile boundaries, device enrollment, and credential management.
- **Planned Changes:**
  - Add Mobile Device Pairing & Profile Binding section (`D-PHONE-01B`): 1 enrolled mobile device maps strictly to 1 Profile.
  - Enforce PC Host Account Authority: Host is sole administrator; device revocation occurs on PC; offline mobile client is disconnected upon next handshake when revoked.
  - Multi-Phone Status: Document that One Profile → Multiple Phones remains **OPEN / DECISION DEBT**.
  - Pairing Direction: Explicit authorized Host enrollment and QR/code UX direction; exact cryptographic handshake and transport payload remain implementation-open.
  - Platform Protection: Preserve Android platform protection, Keystore-protected credentials/secrets, application sandbox rules, and backup exclusions. Do not freeze unapproved local database encryption mechanisms (governed by existing architecture/implementation debt).
- **Invariants to Preserve:** PC multi-profile isolation; zero leakage between profiles; token rotation policies.

---

### 3.2 Batch D3 — AI Runtime, Conversations, Context, Memory & Tools

**Goal:** Establish production-capable local AI execution path for qualified devices, model/resource lifecycle, context budgeting and compaction truth, causal conversation behavior, selective Memory continuity, and Standalone Mobile Tool Gateway.

**Approved Decision Groups:**
`D-PHONE-01`, `D-PHONE-01C`, `D-PHONE-03`, `D-PHONE-05`, `D-PHONE-05A`, `D-SHARED-AI-01`, `D-SHARED-AI-02`, `D-SHARED-AI-03`, `D-PHONE-08`, `D-PHONE-08A`, `D-PHONE-09`, `D-SHARED-CONV-01`, `D-SHARED-CONV-02`, `D-SHARED-CONV-03`, `D-SHARED-CONV-03A`, `D-PHONE-13`, `D-PHONE-13A` through `D-PHONE-13F`, `D-PHONE-13C`, Gemma 3 1B cross-device qualification research requirement.

#### [MODIFY] `docs/04_Architecture/SYSTEM_BASELINE.md`
- **Primary Responsibility:** System-wide architecture baseline and cross-client topology.
- **Planned Changes:**
  - Update Section 4 (Client Targets) to establish that Mobile V1 **MUST** include a production-capable local LLM path for qualified devices (`D-PHONE-01`, `D-PHONE-03`).
  - Clarify tiering: Individual supported phones do NOT all need to qualify; core Mobile companion capability survives without local generative AI (`D-PHONE-02`).
- **Invariants to Preserve:** PC Host is master runtime for complex orchestration and heavy local models (Qwen-2.5-7B, etc.).

#### [MODIFY] `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`
- **Primary Responsibility:** Model definitions, execution backends, and runtime management.
- **Planned Changes:**
  - Component Distinction (`D-PHONE-05`): Maintain strict architectural distinction between:
    1. **Model Artifact / Model:** Weights and configuration.
    2. **Runtime / Provider:** Engine executing inference (e.g., llama.cpp).
    3. **Execution Backend:** Hardware accelerator interface (CPU, OpenCL, Vulkan, NPU).
    4. **Physical Hardware:** Host system resources.
  - Model Lifecycle on Mobile (`D-PHONE-05A`): Single resident generative model maximum on phone. Use approved lifecycle states: `installed`, `loaded/resident`, `active`, `unloaded`, `removed`. Note that `unloaded` (evicted from memory) does not equal `removed` (deleted from disk).
  - Model Candidates as Research Examples (`D-PHONE-03`): Mobile models (e.g., Gemma 3 1B) are replaceable research candidates, not hard-coded architectural dependencies. Do NOT introduce unapproved candidates such as Gemma 2 2B or Qwen 2.5 1.5B into canonical architecture.
- **Invariants to Preserve:** Host model registry contracts; reproducible inference parameter validation.

#### [MODIFY] `docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`
- **Primary Responsibility:** Performance budgets, memory limits, and hardware governance.
- **Planned Changes:**
  - Progressive Resource Governor (`D-PHONE-05A`): Progressive visible intervention driven by real thermal, battery, and memory metrics:
    - Warn and mitigate under non-critical pressure.
    - Defer background tasks first.
    - Allow active foreground inference to complete where safe.
    - Severe pressure may pause or stop inference.
    - Critical pressure may force cancellation and model unload after saving durable state.
    - Truthful reporting of resource, backend, and residency reasons.
    - Presentation labels such as `NORMAL`, `CONSTRAINED`, `HIGH_PRESSURE`, `CRITICAL` are friendly display labels, not replacements for Android thermal states.
    - Do NOT invent "lower quantization" as an automatic runtime transition. Exact thresholds remain implementation-open.
  - Evidence-Driven Qualification: Mobile local LLM qualification is evidence-driven (ABI compatibility, memory headroom preflight, thermal stability, load/warmup success, sustained responsiveness, storage reserve). Do NOT freeze fixed RAM floors such as "Minimum 6GB RAM".
- **Invariants to Preserve:** PC resource governor rules; deterministic degradation paths; UI responsiveness priorities.

#### [MODIFY] `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`
- **Primary Responsibility:** Mobile hardware qualification, inference runtimes, and capability matrices.
- **Planned Changes:**
  - Update capability matrix: Standalone Mobile local LLM is a real production path for qualified devices (`D-PHONE-01`, `D-PHONE-03`).
  - Privacy Sanitization of Reference Device: Sanitize specific retail phone model names in canonical research context to generic wording: "Reference Android Device A: Android 13, ARM64, 8 GB physical RAM, mid-range mobile SoC class" or link to non-canonical benchmark evidence. Do NOT invent fabricated replacement hardware (no Snapdragon 8 Gen 2 / Adreno 740).
  - Benchmark Data Role: Benchmark measurements in `MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md` remain non-canonical empirical research; do not copy raw tables into canonical architecture.
- **Invariants to Preserve:** Graceful degradation on unqualified devices; zero crashes on Out-of-Memory (OOM).

#### [MODIFY] `docs/04_Architecture/01_Domains/assistant-and-conversations.md`
- **Primary Responsibility:** Conversation turns, dialogue history, context assembly, and conversation branching.
- **Planned Changes:**
  - Conversation History Authority (`D-SHARED-CONV-02`): Raw conversation transcript remains authoritative truth. Rolling compaction and derived summaries are convenience views, never canonical source records.
  - Context Compaction Status: Explicitly preserve that rolling context compaction is **NOT IMPLEMENTED** in current codebase.
  - Causal Branching & Forking (`D-SHARED-CONV-01`): Forking and regenerating conversation turns preserves causal parent, branch, and fork semantics without Last-Write-Wins. Exact database or DAG graph representation remains implementation-open.
  - Turn Coordination (`D-SHARED-CONV-03`, `03A`): Turn queueing, user interrupt/barge-in, and safe regeneration semantics.
- **Invariants to Preserve:** Conversation schema contracts; message ordering guarantees; SSE streaming protocols.

#### [MODIFY] `docs/04_Architecture/01_Domains/memory-and-personalization.md`
- **Primary Responsibility:** Memory storage, retrieval, personalization, and user profile modeling.
- **Planned Changes:**
  - Selective Memory Replica (`D-PHONE-09`): Mobile maintains a selective durable offline replica of canonical Memory facts for context injection.
  - Pending Memory Intent Outbox (`D-PHONE-08`): Explicit offline memory creation requests enter `PENDING_SYNC` status in the outbox, submitted to PC Host D7 Memory engine for canonical reconciliation upon reconnection. Mobile does NOT directly write canonical Memory while disconnected.
  - Pending Memory Overlay (`D-PHONE-08A`): Mobile maintains a local pending memory overlay to provide conversational continuity before Host reconciliation completes.
  - Host Authority: PC Host D7 Memory engine remains sole authoritative memory consolidator.
- **Invariants to Preserve:** PC Host D7 Memory engine authority; episodic and semantic memory schema contracts.

#### [MODIFY] `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`
- **Primary Responsibility:** Tool definitions, execution gateway, permissions, and security guardrails.
- **Planned Changes:**
  - Standalone Mobile Tool Gateway (`D-PHONE-13`): Mobile client provides a local tool execution environment strictly adhering to Decision D9.
  - Approved Standalone Mobile Tool Scope:
    - **Productivity:** Tasks within approved authority, Mobile-created Reminders, Mobile-created Alarms, dismiss/snooze occurrences, Schedule read access.
    - **Read-Only Current Information:** Web Search, public webpage fetch/read, Weather.
    - **Local Companion Reads:** Cached Memory, pending Memory intents, local/cached history, Character info, device/model/sync/resource status.
  - Explicit Tool Prohibitions: Strictly NO generic shell execution, NO unrestricted filesystem access, NO access to master credentials/secrets, NO PC or Profile administration, NO device reassignment, NO security or network reconfiguration, and NO unrestricted browser automation.
  - Side Effect Invariants: Committed tool side effects are never silently replayed or rolled back during sync reconciliation.
- **Invariants to Preserve:** Tool confirmation UX policies; audit logging of all executed actions.

#### [MODIFY] `docs/04_Architecture/03_Integrations/web-current-information.md`
- **Primary Responsibility:** Web search, current information retrieval, and online tool routing.
- **Planned Changes:**
  - Internet Access != Cloud LLM Permission (`D-PHONE-13C`, supported by `D-PHONE-01A`): Internet availability and public web access do NOT imply authorization to transmit user prompts to third-party Cloud LLMs. Public search/weather access is decoupled from cloud AI consent.
- **Invariants to Preserve:** Privacy-first search options; sanitized search query formatting.

---

### 3.3 Batch D4 — Voice, Health, Vision, Character/Presence & Mobile UX

**Goal:** Establish composable Voice, conditional Health Connect V1, conditional local still-image Vision, Character/Mood Emotion Event sync behavior, future Presence boundaries, language extensibility, and the approved Mobile product UX.

**Approved Decision Groups:**
`D-PHONE-04`, `D-PHONE-14` through `D-PHONE-14G`, Voice shared invariants, `D-PHONE-15` through `D-PHONE-15E`, `D-SHARED-HEALTH-01` through `D-SHARED-HEALTH-04`, `D-PHONE-16` through `D-PHONE-16E`, `D-SHARED-VISION-01`, `D-PHONE-06`, Character authority rule, `D-PHONE-EMO-01`, `D-PHONE-12D`, `12E`, `P-SHARED-PRESENCE-01`, `P-PHONE-AR-01`, `P-PHONE-AR-02`, `P-PRESENCE-02`, `D-PHONE-UX-01` through `D-PHONE-UX-10`, `D-SHARED-LANG-01`, `D-SHARED-LANG-02`.

#### [MODIFY] `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
- **Primary Responsibility:** Mobile baseline subsystem registration.
- **Planned Changes:**
  - Add Voice subsystem registration (`D-PHONE-14`): Composable STT/LLM/TTS pipeline, foreground service lifecycle, barge-in mandatory.
  - Add Health Connect subsystem registration (`D-PHONE-15`): Conditional Mobile V1, read-only, non-clinical.
  - Add Vision subsystem registration (`D-PHONE-16`): Conditional Mobile V1, still-image VLM, shared attachment pipeline.
  - Add Companion Shell & Navigation registration (`D-PHONE-UX-01` to `10`): 5-tab navigation, companion-centered home, truthful capability presentation.
- **Invariants to Preserve:** Subsystem lifecycle isolation; zero cross-subsystem crashes.

#### [MODIFY] `docs/04_Architecture/01_Domains/voice-and-audio.md`
- **Primary Responsibility:** Audio capture, STT, TTS, voice activity detection, and audio focus.
- **Planned Changes:**
  - Composable Voice Routing (`D-PHONE-04`, `D-PHONE-14`): STT, reasoning, and TTS are independently routable across 3 execution locations (Local Mobile / PC Host / Cloud Provider). E.g., Local STT -> Host LLM -> Local TTS.
  - Voice Invariants: Mandatory user barge-in (speech interrupt cancels ongoing TTS immediately); strictly NO background eavesdropping or ambient listening; local STT is conditional until qualified on hardware.
  - Candidate Engine Research: Whisper.cpp is the first approved Mobile STT research candidate (candidate only, not permanent engine; do not add unapproved engines such as sherpa-onnx).
  - Voice Foreground Service Lifecycle (`D-PHONE-14F`): Audio session managed via Android Foreground Service with persistent notification and microphone indicator.
- **Invariants to Preserve:** Privacy-respecting audio buffer zeroing; audio focus handling (ducking/pausing during calls).

#### [MODIFY] `docs/04_Architecture/03_Integrations/health-and-wearables.md`
- **Primary Responsibility:** Health metrics, wearable integration, and biometric context.
- **Planned Changes:**
  - Health Connect Allocation (`D-PHONE-15`): Formally designated as **CONDITIONAL Mobile V1** capability.
  - Granular Consent (`D-PHONE-15A`): User consent per metric and category type.
  - Read-Only Ingestion (`D-PHONE-15B`): Mobile client only reads approved Health Connect records; never writes.
  - Health Context Separate from D7 Memory (`D-PHONE-15C`): Health metrics provide ephemeral/operational context and are strictly separate from canonical D7 Memory.
  - PC Synchronization (`D-PHONE-15D`): Approved normalized health context may synchronize to PC Host.
  - Aggregation Boundary (`D-PHONE-15E`): Health Connect is the preferred aggregation boundary over vendor-specific wearable SDKs.
  - Unified Contract (`D-SHARED-HEALTH-01`): Shared normalized PC/Mobile Health Context contract (unavailable/stale data != zero).
  - Non-Clinical Guardrails (`D-SHARED-HEALTH-02`): Strictly non-clinical wellness awareness (no invented mandatory medical disclaimer).
  - Check-Ins & Egress (`D-SHARED-HEALTH-03`, `04`): Health-aware companion check-ins; separate explicit user authorization required for Health-to-cloud transmission. Exact retention cadence and window remain implementation-open.
- **Invariants to Preserve:** Granular permissions; local health cache privacy.

#### [MODIFY] `docs/04_Architecture/01_Domains/multimodal-and-media.md`
- **Primary Responsibility:** Vision, image handling, camera capture, and file attachments.
- **Planned Changes:**
  - Conditional Local Still-Image Vision V1 (`D-PHONE-16`, `D-SHARED-VISION-01`): Local VLM inference is **CONDITIONAL Mobile V1** on qualified hardware; fallback to PC Host or Cloud.
  - Provider-Neutral Architecture: Canonical architecture remains provider and model neutral; tested Qwen candidate remains research evidence only (do not introduce unapproved candidates such as SmolVLM or Moondream).
  - Shared Attachment Pipeline: Camera and gallery captures feed standard conversation attachment pipeline.
  - Vision Invariants: Strictly NO ambient or background camera processing in V1; user-initiated capture only; no silent cloud upload; Vision data != Memory. Preserve existing attachment validation and privacy invariants (do not introduce new EXIF-stripping requirements unless already required by canonical security specs).
- **Invariants to Preserve:** Local storage quotas; attachment lifecycle.

#### [MODIFY] `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`
- **Primary Responsibility:** Character definitions, personality traits, emotion state, and mood expressions.
- **Planned Changes:**
  - Character Authority (`D-PHONE-06`): PC Host owns canonical Character definition, persona configuration, and evolution.
  - Emotion Event Sync Model (`D-PHONE-EMO-01`): Offline interaction generates typed bounded emotion events queued in the durable outbox; optional provisional local presentation; Host reconciles events using shared Decision D11 policy into canonical Mood. Mobile does NOT directly synchronize or overwrite canonical Mood values. Exact mathematical representation remains open (do not freeze -1.0 to +1.0 ranges).
  - Lightweight Mood Presence & Emoji Fallback (`D-PHONE-UX-10`, `D-PHONE-12D`, `12E`): Guaranteed lightweight fallback using system emoji when rich expressions are unavailable or low-power mode is active.
  - Future Presence Boundaries (`P-SHARED-PRESENCE-01`, `P-PHONE-AR-01`, `02`, `P-PRESENCE-02`): AR and spatial companion presence are formally classified as **FUTURE / MOBILE LATER** (do not invent "Phase 9+").
  - Extensible Language Registry (`D-SHARED-LANG-01`) & Qualified Capabilities (`02`): Companion language persona registry is extensible; Companion language persona is distinct from app UI localization (`D-PHONE-UX-09`).
- **Invariants to Preserve:** Persona consistency; ethical companion guardrails.

#### [ADD] `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`
- **Primary Responsibility:** Canonical Mobile UI/UX specification, layout shell, design tokens, and interaction flows.
- **Planned Changes:** Create new design document adhering to `docs/05_Design/` flat numbering convention (`01_` through `07_` exist) using exact approved UX decision mappings:
  - `D-PHONE-UX-01`: 5-Tab Companion Shell (Home, Schedule, Companion, Activity, More).
  - `D-PHONE-UX-01A`: Icon-first navigation with accessibility semantics.
  - `D-PHONE-UX-02`: Contextual Companion Home featuring companion presence, active mood, quick status, and immediate conversation entry.
  - `D-PHONE-UX-03`: Unified Companion interaction surface seamlessly integrating text, voice, and quick actions.
  - `D-PHONE-UX-04`: Unified Schedule experience combining Reminders, Alarms, Tasks, and Routine occurrences.
  - `D-PHONE-UX-05`: Activity & reconciliation inbox displaying sync status, conflict notices, and background task completions.
  - `D-PHONE-UX-06`: Truthful compact capability status showing operational states (PC Connected / Standalone / Offline / Cloud).
  - `D-PHONE-UX-07`: Graceful Standalone Mobile UX framing standalone as a capability transition, not an application error.
  - `D-PHONE-UX-08`: Hybrid visual design language combining Minimalist foundational geometry, selective Neumorphic tactile depth, contextual Glass / Liquid Glass surfaces, pure OLED dark theme by default, and support for reduced motion and low-effects modes.
  - `D-PHONE-UX-09`: Companion interaction language decoupled from UI localization.
  - `D-PHONE-UX-10`: Lightweight Mood Presence with guaranteed emoji fallback.
  - `D-SHARED-LANG-01`, `02`: Extensible language registry and code-switching capabilities.
  - Accessibility: Accessible touch targets conforming to repository accessibility conventions (do not freeze unapproved 48x48dp values).
- **Invariants to Preserve:** Compliance with repository design system; contrast standards.

---

### 3.4 Batch D5 — Master Planning Spine, Golden Verification, Documentation Integration & PR Handoff

**Goal:** Synchronize the master planning spine, expand the WBS and Golden verification checklist, clean trailing whitespace blocking Docs Integrity CI across the full PR diff, author the delivery walkthrough, and prepare PR #21 for closure.

#### [MODIFY] `docs/02_Planning/00_Master/MOBILE_WBS.md`
- **Primary Responsibility:** Mobile Work Breakdown Structure and task definitions.
- **Planned Changes:**
  - Current WBS contains 65 items. Expand WBS as required by promoted architecture, with exact final count derived during D5 (do not freeze an arbitrary count).
  - Preserve existing stable IDs (`MOB-VOICE-005` Local TTS, `MOB-VOICE-006` Local STT, `MOB-VOICE-007` Cloud Voice Routing already exist; do not present them as new).
  - Expand existing work items where semantically appropriate; add new stable IDs only where no existing work item fits.
  - Propose work streams for new Batch D capabilities (e.g. Health, Vision, UX, Tool Gateway, Causal Branching) subject to D5 derivation.
  - Validate dependency graph: zero duplicate IDs, zero dangling dependencies, zero dependency cycles.
- **Invariants to Preserve:** Existing task IDs and completed baseline milestones.

#### [MODIFY] `docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`
- **Primary Responsibility:** Mobile Golden verification criteria and capability qualification checklist.
- **Planned Changes:**
  - Replace current checklist with the exact approved, locked MG1–MG18 structure:
    - **MG1 — Enrollment, Identity & Profile Isolation**
    - **MG2 — Security, Secrets & Protected Transport**
    - **MG3 — Connected Companion Operation**
    - **MG4 — Standalone Mobile Core**
    - **MG5 — Durable Offline State & Synchronization**
    - **MG6 — Conversations, Branches & Turn Control**
    - **MG7 — Context, Memory & Historical Recall**
    - **MG8 — Character, Mood & Companion Continuity**
    - **MG9 — Tasks, Reminders, Alarms & Temporal Semantics**
    - **MG10 — Cross-Device Alert Arbitration**
    - **MG11 — Routines, Check-ins & Companion Surfaces**
    - **MG12 — Local Tools & Current Information**
    - **MG13 — Voice & Speech Composition**
    - **MG14 — Local Models, Resources & Capability Qualification**
    - **MG15 — Health-Aware Companion**
    - **MG16 — Multimodal Vision**
    - **MG17 — Mobile UX, Accessibility & Personalization**
    - **MG18 — Full Companion Journey** (must remain the integrated final journey)
  - Apply granular qualification classes (`REQUIRED`, `CONDITIONAL`, `OPTIONAL`, `DEFERRED`) to sub-capabilities within groups rather than simplistic one-word classifications for whole groups.
- **Invariants to Preserve:** Explicit verification evidence requirements for each checklist item.

#### [MODIFY] `docs/02_Planning/00_Master/MASTER_CHECKLIST.md`
- **Primary Responsibility:** Top-level project milestone delivery checklist.
- **Planned Changes:** Update Line 6 (Mobile Architecture Gate) to cross-reference the locked MG1–MG18 criteria and link to `MOBILE_CHECKLIST.md`.
- **Invariants to Preserve:** Preserved status of PC V1 and Phase 8 checklist items.

#### [MODIFY] `docs/02_Planning/00_Master/DECISION_REGISTER.md`
- **Primary Responsibility:** Authoritative registry of architectural decisions.
- **Planned Changes:** Register approved Batch D decisions (`D-PHONE-01` through `D-PHONE-16`, `D-SHARED-SCHED-*`, `D-SHARED-AI-*`, `D-SHARED-CONV-*`, `D-SHARED-FLUTTER-*`, `D-SHARED-HEALTH-*`, `D-SHARED-VISION-*`, `D-PHONE-UX-*`, `D-SHARED-LANG-*`). Preserve accepted ADR authority: ADR-0001 through ADR-0012, ADR-0017, ADR-0018, ADR-0019 (ADR-0013 through ADR-0016 remain historical/unaccepted).
- **Invariants to Preserve:** Accepted ADR authority.

#### [MODIFY] `docs/02_Planning/00_Master/DECISION_DEBT.md`
- **Primary Responsibility:** Catalog of deferred decisions, technical debt, and open architectural questions.
- **Planned Changes:** Index `DEBT-MOB-MULTI-DEVICE` (One Profile → Multiple Mobile Phones architecture remains **OPEN / DECISION DEBT**; not deferred post-V1).
- **Invariants to Preserve:** Existing recorded debt items.

#### [MODIFY] `docs/02_Planning/00_Master/SPRINT_ROADMAP.md` & `DELIVERY_INDEX.md`
- **Primary Responsibility:** Sprint sequencing and work item tracking.
- **Planned Changes:** Update MOBILE-ARCH status to reflect Batch D completion upon final approval; preserve M1 sequencing.
- **Invariants to Preserve:** Milestone definitions and branch naming rules.

#### [MODIFY] `docs/06_Guides/DOCUMENTATION_MAP.md`
- **Primary Responsibility:** Repository documentation index and reading guide.
- **Planned Changes:** Add entries for `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md` and `docs/03_Walkthroughs/walkthrough-mobile-v1-batch-d-reconciliation.md`.
- **Invariants to Preserve:** Existing documentation map structure.

#### [ADD] `docs/03_Walkthroughs/walkthrough-mobile-v1-batch-d-reconciliation.md`
- **Primary Responsibility:** Point-in-time delivery walkthrough documenting the Batch D reconciliation.
- **Planned Changes:** Detail the reconciliation audit, canonical changes across D2–D5, WBS expansion, Golden criteria expansion, and verification results.
- **Invariants to Preserve:** Walkthrough format standards.

#### [MODIFY] `CHANGELOG.md`
- **Primary Responsibility:** Append-only project changelog.
- **Planned Changes:** Inspect top 15 lines and append a concise entry summarizing MOBILE-ARCH Batch D reconciliation and canonical promotion.
- **Invariants to Preserve:** Append-only rule (read top 15 lines only, append new section).

#### [MODIFY] Full PR Whitespace Mechanical Cleanup
- **Primary Responsibility:** Restore green CI for Docs Integrity workflow on GitHub Actions.
- **Planned Changes:** Run `git diff --check develop...HEAD` across all files in the PR branch. For any Markdown/text file with trailing whitespace flagged, perform mechanical in-place stripping of trailing spaces/tabs without altering semantics.
- **Invariants to Preserve:** Zero semantic changes; preserve valid Markdown formatting.

---

## 4. Step-by-Step Implementation Sequence

```
PLAN CORRECTED (Current Task)
  │
  ▼
STOP: Independent Chris & GPT Plan Review & Approval
  │
  ▼
Chris executes commit & push of approved plan:
  docs(mobile): plan Batch D canonical promotion
  │
  ▼
Create branch-active tracking:
  docs/01_Tracking/active/task-docs-mobile-v1-canonicalization.md
  (Record D1 research + approved plan baseline; mark Batch D2 ACTIVE)
  │
  ▼
BATCH D2: Core Baseline, Identity, Scheduling & Flutter Boundaries
  │  (MOBILE_SYSTEM_BASELINE.md, mobile-offline-and-sync.md,
  │   tasks-reminders-alarms-and-routines.md, android-companion.md,
  │   profiles-and-devices.md)
  ▼
VERIFY D2: Whole-file whitespace scan, markdown links, git diff --check
  │
  ▼
STOP: Independent Chris & GPT Review of Batch D2
  │
  ▼
Chris executes commit & push of Batch D2 checkpoint
  │
  ▼
BATCH D3: AI Runtime, Conversations, Context, Memory & Tools
  │  (SYSTEM_BASELINE.md, runtime-and-models.md, performance-and-capacity.md,
  │   mobile-capabilities-and-runtime.md, assistant-and-conversations.md,
  │   memory-and-personalization.md, tool-permissions-and-actions.md,
  │   web-current-information.md)
  ▼
VERIFY D3: Whole-file whitespace scan, markdown links, git diff --check
  │
  ▼
STOP: Independent Chris & GPT Review of Batch D3
  │
  ▼
Chris executes commit & push of Batch D3 checkpoint
  │
  ▼
BATCH D4: Voice, Health, Vision, Character/Presence & Mobile UX
  │  (MOBILE_SYSTEM_BASELINE.md, mobile-capabilities-and-runtime.md,
  │   mobile-offline-and-sync.md, memory-and-personalization.md,
  │   assistant-and-conversations.md, voice-and-audio.md,
  │   health-and-wearables.md, multimodal-and-media.md,
  │   characters-personality-and-emotion.md,
  │   docs/05_Design/08_Mobile_Companion_Shell_and_UX.md)
  ▼
VERIFY D4: Whole-file whitespace scan, markdown links, git diff --check
  │
  ▼
STOP: Independent Chris & GPT Review of Batch D4
  │
  ▼
Chris executes commit & push of Batch D4 checkpoint
  │
  ▼
BATCH D5: Planning Spine, Golden Verification, Whitespace Cleanup & PR Handoff
  │  (MOBILE_WBS.md, MOBILE_CHECKLIST.md, MASTER_CHECKLIST.md,
  │   DECISION_REGISTER.md, SPRINT_ROADMAP.md, DELIVERY_INDEX.md,
  │   DECISION_DEBT.md, DOCUMENTATION_MAP.md, CHANGELOG.md,
  │   walkthrough-mobile-v1-batch-d-reconciliation.md,
  │   Full PR trailing-whitespace mechanical cleanup)
  ▼
VERIFY D5: Whole PR git diff --check develop...HEAD, link check, repo verification
  │
  ▼
STOP: Independent Closure Gate Review (Chris & GPT)
  │
  ▼
Chris executes commit & push of Batch D5 checkpoint
  │
  ▼
Archive active tracker:
  docs/01_Tracking/archive/task-2026-10-xx-mobile-v1-canonicalization.md
  │
  ▼
Present PR #21 Description Update Proposal
  │
  ▼
Chris triggers fresh CI, verifies green Docs Integrity, and executes squash merge
```

### 4.1 Branch-Active Tracking Lifecycle

1. **Shared Task Integrity:** `docs/01_Tracking/task.md` remains the high-level milestone integration tracker on `develop`/`master`. It MUST NOT be modified during branch work to reflect transient branch heartbeats or PR states.
2. **Branch Active Tracker Creation:** Immediately after plan approval and before starting Batch D2 canonical edits, create `docs/01_Tracking/active/task-docs-mobile-v1-canonicalization.md` (derived using the documented branch-slug convention replacing `/` with `-`). Do NOT create this file before the plan is approved.
3. **In-Flight Tracking:** Maintain batch progress, completed edits, verification check outputs, and open stop conditions in `task-docs-mobile-v1-canonicalization.md`.
4. **Closure Archiving:** Upon successful completion of Batch D5 and independent Closure Gate approval, move `task-docs-mobile-v1-canonicalization.md` to `docs/01_Tracking/archive/task-2026-10-xx-mobile-v1-canonicalization.md` as part of the same delivery branch prior to merge.

### 4.2 M1 Sequencing Rule

- **Governance Requirement:** Flutter Desktop M1 scaffolding and implementation is sequenced AFTER the reopened MOBILE-ARCH pass is fully re-closed and merged.
- **Clarification:** While Batch D is primarily architectural documentation and does not create an impassable code-level dependency blocking Flutter Desktop scaffolding, project governance dictates that target cross-platform boundaries, shared package topologies, and ecosystem contracts must be frozen and approved before desktop implementation begins.
- **Invariant:** M1 remains marked as PENDING / SEQUENCED; it will NOT be marked active during this plan.

### 4.3 Recommended Conventional Commit Checkpoints

Because Chris owns all Git mutations, the implementation agent will halt at the end of each batch, report verification results, and provide a single Conventional Commit suggestion for Chris to execute:
1. **Plan Correction (Current):** `docs(mobile): correct Batch D promotion plan`
2. **Batch D2 Checkpoint:** `docs(mobile): promote Batch D2 core baseline, identity, scheduling and flutter boundaries`
3. **Batch D3 Checkpoint:** `docs(mobile): promote Batch D3 ai runtime, context, memory and tools`
4. **Batch D4 Checkpoint:** `docs(mobile): promote Batch D4 voice, health, vision, character and ux`
5. **Batch D5 & Closure Checkpoint:** `docs(mobile): reconcile planning spine, golden checklist, and clean pr whitespace`

---

## 5. Acceptance Criteria & Verification Plan

### 5.1 Automated Repository Checks

Every batch must pass automated checks before stopping for independent review:

| Check Type | Command / Script | Expected Result |
| :--- | :--- | :--- |
| **Trailing Whitespace (Whole File)** | `Select-String -Path "<file>" -Pattern '[ \t]+$'` | 0 matches found |
| **Scoped Git Diff Check** | `git diff --check <file>` | Clean (exit code 0, no output) |
| **Relative Markdown Links** | PowerShell verification script validating all relative `[text](path)` links against filesystem | 0 broken links |
| **Git Status Purity** | `git status --short` | Only approved batch files modified/added |
| **Docs Integrity CI Simulation (D5)** | `git diff --check develop...HEAD` across all PR files | Clean (exit code 0, zero trailing whitespace across PR) |

### 5.2 Manual / User-Owned Independent Review Gates

Execution strictly halts at four intermediate review gates and one final closure gate:
- [ ] **Gate 0 (Plan Approval):** Chris and GPT review and approve this corrected plan file before any canonical files are edited or the active tracker is created.
- [ ] **Gate 1 (Batch D2 Approval):** Chris and GPT review canonical diffs for `MOBILE_SYSTEM_BASELINE.md`, `mobile-offline-and-sync.md`, `tasks-reminders-alarms-and-routines.md`, `android-companion.md`, and `profiles-and-devices.md`.
- [ ] **Gate 2 (Batch D3 Approval):** Chris and GPT review canonical diffs for runtime, performance, assistant, memory, tool, and web specifications, including reference-device sanitization.
- [ ] **Gate 3 (Batch D4 Approval):** Chris and GPT review canonical diffs for voice, health, vision, character, and the new design specification `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`.
- [ ] **Gate 4 (Batch D5 Closure Gate):** Chris and GPT perform final closure review of the master planning spine, WBS, Golden checklist MG1–MG18, walkthrough, changelog, and PR #21 description update.

### 5.3 Batch-by-Batch Acceptance Criteria

#### Batch D2 Acceptance Criteria
- [ ] **Orthogonal Operating States:** Baseline clearly defines Host reachability, internet connectivity, and inference routing as 3 orthogonal axes (`D-PHONE-01A`). Standalone Mobile is documented as an operational state, not an error.
- [ ] **Profile Binding Invariant:** 1 enrolled phone binds strictly to exactly 1 Profile (`D-PHONE-01B`). One Profile → multiple phones is documented as **OPEN / DECISION DEBT** (not deferred).
- [ ] **Host Admin Authority:** PC Host retains exclusive authority over Account and Profile administration.
- [ ] **Core Companion Survival:** Core companion survives completely without generative AI (`D-PHONE-02`).
- [ ] **Offline Reminders & Alarms:** Mobile Reminders (`D-PHONE-10`) and Alarms (`D-PHONE-11`) created on the phone are offline-authorable and queued in the outbox.
- [ ] **Protected Host Definitions:** Host-created automation, reminders, and alarm definitions remain read-only and tamper-proof while mobile is offline (`D-SHARED-SCHED-03`).
- [ ] **Cross-Device Alert Arbitration:** Reminders favor duplicate suppression; Alarms prioritize reliability over duplicate suppression (primary presentation first, standby armed, explicit ack propagates, passive display != ack, bounded standby escalation, disconnected duplicate preferable to missed alarm) (`D-SHARED-SCHED-02`).
- [ ] **Routine Occurrence Presentation:** Routine occurrence caching is decoupled from autonomous recurrence evaluation; bounded Host-authorized future occurrences cached with exact horizon open (`D-PHONE-12`, `12A`, `12C`, `D-SHARED-SCHED-04`, `04A`).
- [ ] **Routine Canonical Authoring:** Routine authoring remains Host-mediated; mobile authoring uses Host APIs/D9 (`D-PHONE-12B`).
- [ ] **Temporal Parity:** Mobile natural language scheduling semantics share PC temporal intent parser behavioral semantics and Golden vectors (`D-SHARED-SCHED-04` through `04E`); parser code implementations remain independent.
- [ ] **No Universal Server Wins / No LWW Resurrection:** Conflict policy uses base-revision concurrency, typed `CONFLICT_DETECTED`, local unsynced work retention, and tombstones without timestamp LWW reconciliation.
- [ ] **Flutter Shared-Core Boundaries:** Workspace topology enforces shared domain/contracts/primitives with platform-specific presentation; exact package names and count remain implementation-open.
- [ ] **Clean D2/D4 Platform Boundary:** Android adapter specification in D2 covers generic adapter boundaries only (AlarmManager, Keystore, lifecycle); no premature D4 Health/Voice promotion.
- [ ] **Prototype Demoted:** Android Jetpack Compose code in `android/` is unambiguously documented as historical reference evidence.

#### Batch D3 Acceptance Criteria
- [ ] **Local LLM Production Path:** Local generative LLM inference is established as a required V1 capability path on qualified mobile devices (`D-PHONE-01`, `D-PHONE-03`).
- [ ] **Non-Blocking Core:** Core mobile companion functionality survives completely on devices without local generative inference (`D-PHONE-02`).
- [ ] **Component Separation:** Explicit separation between Model artifact, Runtime engine, Backend accelerator, and Physical Hardware (`D-PHONE-05`).
- [ ] **Single Resident LLM:** Strict policy permitting a maximum of 1 resident generative LLM in mobile memory.
- [ ] **Approved Lifecycle Terms:** Uses lifecycle terms `installed`, `loaded/resident`, `active`, `unloaded`, `removed`. Uses "removed", not "deleted".
- [ ] **Progressive Resource Governor:** Progressive visible intervention without invented fixed tiers or RAM floors; warn/mitigate under non-critical pressure, defer background work first, let foreground finish where safe, severe pressure may pause/stop, critical pressure may cancel/unload; truthful resource/backend/residency reporting (`D-PHONE-05A`). No "lower quantization" runtime transition.
- [ ] **Evidence-Driven Qualification:** Qualification based on ABI compatibility, memory headroom preflight, thermal stability, load/warmup, and sustained responsiveness; no fixed RAM thresholds.
- [ ] **Transcript Authority:** Raw conversation transcript remains authoritative truth; derived summaries are not primary records (`D-SHARED-CONV-02`).
- [ ] **Compaction Truth:** Context compaction rolling summary is truthfully documented as "NOT IMPLEMENTED" in current codebase.
- [ ] **Memory Intent Outbox:** Pending explicit memory items created offline enter `PENDING_SYNC` in the outbox for PC Host D7 reconciliation (`D-PHONE-08`); local pending memory overlay provides continuity (`D-PHONE-08A`); selective durable offline replica of canonical memory (`D-PHONE-09`); mobile does not directly write canonical memory while disconnected.
- [ ] **Host Memory Authority:** PC Host D7 Memory engine retains exclusive authority over canonical user memory.
- [ ] **Causal Branching:** Conversation turn forking and regeneration preserve causal DAG parent pointers without LWW (`D-SHARED-CONV-01`); exact DB schema implementation-open.
- [ ] **Turn Coordination:** Message queueing, interrupt handling, and safe turn regeneration semantics are specified (`D-SHARED-CONV-03`, `03A`).
- [ ] **Side Effect Invariant:** Committed tool actions are never silently replayed or rolled back during sync reconciliation.
- [ ] **Standalone Tool Gateway:** Mobile tool execution strictly follows Decision D9 with approved scope (Productivity, Read-only current info, Local companion reads); strictly excludes shell, raw filesystem, master credentials, PC/Profile admin, device reassignment, or network reconfiguration (`D-PHONE-13`, `13A` to `13F`).
- [ ] **Internet vs. Cloud LLM:** Internet access permission does NOT imply Cloud LLM authorization (`D-PHONE-13C`). Ordinary web search does not require Cloud LLM consent.
- [ ] **Benchmark Evidence Role & Privacy Sanitization:** Benchmark data is cited only as non-canonical research evidence; specific retail phone model name is sanitized to generic reference description ("Reference Android Device A: Android 13, ARM64, 8 GB physical RAM, mid-range mobile SoC class"); no fabricated hardware replacement.

#### Batch D4 Acceptance Criteria
- [ ] **Composable Voice Routing:** Local, Host, and Cloud routes for STT, reasoning, and TTS are independently composable (`D-PHONE-04`, `D-PHONE-14`).
- [ ] **Mandatory Barge-In:** User speech immediately interrupts and cancels active TTS playback.
- [ ] **No Eavesdropping:** Background listening and ambient audio capture are strictly prohibited.
- [ ] **Conditional Local STT:** On-device STT is conditional upon hardware qualification; whisper.cpp is documented as first approved research candidate (candidate only, not permanent engine; no sherpa-onnx).
- [ ] **Voice Foreground Service:** Persistent audio capture requires native foreground service with visible notification indicator (`D-PHONE-14F`).
- [ ] **Health Connect Conditional V1:** Health Connect is formally designated as **CONDITIONAL Mobile V1** capability (`D-PHONE-15`).
- [ ] **Granular Health Consent & Read-Only Ingestion:** User consent per metric/category (`15A`); strictly read-only ingestion (`15B`).
- [ ] **Health Separate from Memory:** Health context is operational/ephemeral context, strictly separate from D7 Memory (`15C`).
- [ ] **Normalized Sync & Aggregation Boundary:** Approved normalized context syncs to PC (`15D`); Health Connect preferred aggregation boundary (`15E`); shared contract (`D-SHARED-HEALTH-01`); non-clinical awareness (`02`); health-aware check-ins (`03`); separate cloud egress authorization (`04`). No invented mandatory medical disclaimer.
- [ ] **Conditional Local Vision V1:** Still-image VLM inference is **CONDITIONAL Mobile V1** on qualified hardware (`D-PHONE-16`, `D-SHARED-VISION-01`).
- [ ] **Provider-Neutral Vision:** Tested Qwen candidate remains research evidence; canonical architecture remains model/provider neutral; no unapproved candidates (no SmolVLM/Moondream).
- [ ] **Shared Attachment Pipeline:** Camera and gallery captures feed standard conversation attachment pipeline.
- [ ] **Vision Invariants:** No ambient/background camera processing in V1; user-initiated only; no silent cloud upload; Vision data != Memory. Preserve existing attachment validation/privacy invariants (no new EXIF requirements).
- [ ] **Character Authority:** PC Host retains canonical ownership over Character persona and definitions (`D-PHONE-06`).
- [ ] **Emotion Event Sync Model:** Offline interaction generates typed bounded emotion events in durable outbox; provisional local presentation; Host reconciles events into canonical Mood (`D-PHONE-EMO-01`). Mobile does not directly synchronize/overwrite canonical Mood. Exact mathematical representation open.
- [ ] **Lightweight Mood Presence & Emoji Fallback:** Guaranteed system emoji expression fallback for low-power environments (`D-PHONE-UX-10`, `D-PHONE-12D`, `12E`).
- [ ] **Presence Boundaries:** AR and spatial presence are formally classified as **FUTURE / MOBILE LATER** (no "Phase 9+").
- [ ] **Extensible Language Registry:** Companion persona language is extensible (`D-SHARED-LANG-01`) and supports qualified code-switching (`02`); Companion language is decoupled from UI localization (`D-PHONE-UX-09`).
- [ ] **5-Tab Companion Shell:** New design doc `08_Mobile_Companion_Shell_and_UX.md` specifies Home, Schedule, Companion, Activity, More tabs (`D-PHONE-UX-01`).
- [ ] **UX Decision Alignment:** Conforms to `D-PHONE-UX-01` through `10`, including icon-first accessible navigation (`01A`), contextual Home (`02`), unified surface (`03`), unified Schedule (`04`), Activity inbox (`05`), truthful compact status (`06`), graceful Standalone UX (`07`), hybrid visual tokens (`08`), language decoupling (`09`), and emoji Mood fallback (`10`).
- [ ] **Accessible Design Tokens:** Accessible touch targets conforming to repository accessibility conventions (no invented 48x48dp freeze).

#### Batch D5 Acceptance Criteria
- [ ] **WBS Expansion:** `MOBILE_WBS.md` expanded as required by promoted architecture from current 65 items, with exact final count derived during D5.
- [ ] **WBS Integrity:** Zero duplicate IDs, zero dangling dependencies, zero dependency cycles; no overloaded unrelated existing IDs; existing IDs (`MOB-VOICE-005`, `006`, `007`) preserved.
- [ ] **Locked Golden Structure MG1–MG18:** `MOBILE_CHECKLIST.md` follows the exact locked structure (MG1 Enrollment/Identity/Profile, MG2 Security/Secrets/Transport, MG3 Connected Companion, MG4 Standalone Mobile Core, MG5 Durable Offline State/Sync, MG6 Conversations/Branches/Turns, MG7 Context/Memory/Recall, MG8 Character/Mood/Continuity, MG9 Tasks/Reminders/Alarms/Temporal, MG10 Cross-Device Alert Arbitration, MG11 Routines/Check-ins/Surfaces, MG12 Local Tools/Current Info, MG13 Voice/Speech Composition, MG14 Local Models/Resources/Qualification, MG15 Health-Aware Companion, MG16 Multimodal Vision, MG17 Mobile UX/A11y/Personalization, MG18 Full Companion Journey).
- [ ] **Granular Qualification Classes:** Applies `REQUIRED`, `CONDITIONAL`, `OPTIONAL`, `DEFERRED` to sub-capabilities within Golden groups rather than simplistic one-word classifications for entire groups.
- [ ] **Master Checklist Alignment:** `MASTER_CHECKLIST.md` Line 6 updated with cross-references to expanded Golden criteria.
- [ ] **Planning Spine Synchronized:** `DECISION_REGISTER.md`, `SPRINT_ROADMAP.md`, `DELIVERY_INDEX.md`, and `DOCUMENTATION_MAP.md` aligned. Accepted ADR authority preserved (ADR-0001 through ADR-0012, ADR-0017, ADR-0018, ADR-0019; ADR-0013 to ADR-0016 remain historical/unaccepted).
- [ ] **Decision Debt Updated:** `DEBT-MOB-MULTI-DEVICE` formally cataloged as **OPEN / DECISION DEBT** in `DECISION_DEBT.md`.
- [ ] **Docs Integrity Whitespace Clean:** Full PR diff against `develop` passes `git diff --check` with 0 trailing whitespace errors across all PR-modified files.
- [ ] **Walkthrough Authored:** Delivery walkthrough `walkthrough-mobile-v1-batch-d-reconciliation.md` authored.
- [ ] **Changelog Appended:** Top 15 lines of `CHANGELOG.md` inspected and new entry appended cleanly.
- [ ] **PR #21 Description Prepared:** Updated PR summary ready for posting upon Closure Gate approval.

---

## 6. Risks, Recovery & Rollback

### 6.1 Explicit Stop Conditions

The implementation agent MUST immediately halt execution and request guidance from Chris and GPT if any of the following conditions arise:
1. **True Conflict with Frozen PC/Shared Architecture:** A promoted decision contradicts an established PC V1 invariant (e.g., PC Host Account/Profile administration authority, Multi-Profile cryptographic boundaries).
2. **Missing Approved Decision:** Implementation requires a product decision that is not present in `MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md`.
3. **Incompatible ADR Behavior:** A promoted requirement conflicts with an accepted Architectural Decision Record (ADR-0001 through ADR-0012, ADR-0017, ADR-0018, ADR-0019).
4. **Authority Ambiguity:** Unclear normative ownership between shared domain specifications and mobile-specific baseline files.
5. **Security / Privacy Regression:** A proposed change weakens local encryption at rest, exposes credentials, enables ambient listening/recording, or permits unconsented cloud uploads.
6. **Invention of Hard Hardware/Model Requirements:** An urge to mandate a specific retail device, proprietary runtime, fixed RAM floor, or specific AI model as a permanent architecture constraint rather than a replaceable candidate.
7. **Implementation Behavior Invention:** An urge to modify source code, test suites, or invent false "implemented" statuses to make documentation appear complete.
8. **Hidden Cross-Domain Contradiction:** An inconsistency between two canonical domains (e.g., Voice vs. Background Execution, Health vs. Memory) not identified during reconciliation.
9. **Multi-Phone Necessity:** Discovery that 1 Profile to multiple phones is mandatory for Mobile V1 rather than remaining OPEN / DECISION DEBT.
10. **Scope Creep:** Any requirement or edit exceeding the approved MOBILE-ARCH Batch D reconciliation boundary.

### 6.2 Risks & Mitigations

| Risk | Impact | Mitigation Strategy |
| :--- | :--- | :--- |
| **Documentation Bloat & Duplication** | Multiple files repeating identical ledger text, creating synchronization debt. | Enforce single normative ownership per concept. Use concise cross-references to primary domain documents. |
| **Premature Implementation Claims** | Documentation implies Flutter Mobile or Health Connect is implemented today. | Strictly maintain "NOT IMPLEMENTED" statuses and explicitly label target architecture vs. current reality. |
| **Docs Integrity CI Failure** | Trailing whitespace in modified files breaks automated GitHub Actions linting. | Execute automated whole-file regex scanning (`Select-String`) and `git diff --check` before completing each batch. Perform PR-wide cleanup in D5. |
| **Broken Cross-References** | Renamed sections or new files cause broken Markdown links. | Run an automated relative link validation script across all modified documentation. |
| **M1 Boundary Confusion** | Agents attempt to scaffold Flutter Desktop before Mobile architecture is closed. | Explicitly forbid M1 execution in all prompts until MOBILE-ARCH Batch D reaches Closure Gate approval. |

### 6.3 Rollback Procedure

Because all changes are strictly documentation and planning files on the short-lived branch `docs/mobile-v1-canonicalization`:
1. If an individual batch fails review or introduces unintended contradictions, Chris can discard the batch's unstaged working files or revert the specific batch checkpoint commit without affecting other branches.
2. The working branch can be restored to the clean starting HEAD (`5ce5633a088d132deb4c72792fb12dc5a9764ced`) at any time if a fundamental reset is required.
3. The approved working decision ledger (`MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md`) and reconciliation report (`MOBILE_ARCH_BATCH_D_RECONCILIATION_REPORT.md`) remain untouched and safe in `docs/00_Drafts/research/mobile/` as durable reference baselines.
