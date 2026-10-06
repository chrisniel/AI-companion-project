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

Notice: Update this plan in place during planning. After approval, switch live execution tracking to `docs/01_Tracking/active/task-mobile-v1-canonicalization.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### 1.1 Primary Objective

Promote the independently reviewed and approved MOBILE-ARCH Batch D decisions into the correct canonical architecture, design, planning, verification, and closure documents without creating parallel authority, overstating implementation status, or losing existing PC/shared architecture invariants.

The result will re-close MOBILE-ARCH truthfully, align canonical specifications with approved product decisions, expand the Mobile Work Breakdown Structure (WBS) and Mobile Golden verification criteria (MG1–MG18), clean trailing whitespace blocking Docs Integrity CI across the PR diff, and make Pull Request #21 ready for final independent Closure Gate review and merge.

### 1.2 Concrete Deliverables

1. **Batch D2 Canonical Architecture Promotion:** Update 5 foundational architectural files establishing orthogonal availability states, 1-device to 1-profile binding, PC Host Admin authority, offline-authorable Mobile Reminders and Alarms, protected Host definitions, Routine occurrence caching distinct from recurrence, shared temporal intent semantics, and Flutter shared-core vs. platform-presentation boundaries.
2. **Batch D3 AI Runtime & Context Canonical Promotion:** Update 8 runtime, conversation, memory, and tool specifications establishing the real local LLM V1 product path for qualified devices (with core surviving without it), max 1 resident generative model, progressive truthful Resource Governor, authoritative raw transcripts, derived-only summaries, preserved "NOT IMPLEMENTED" statuses, pending memory intents as outbox submissions to PC Host, causal conversation branching without Last-Write-Wins (LWW), and D9 Mobile Tool Gateway constraints.
3. **Batch D4 Voice, Health, Vision, Character & Mobile UX Promotion:** Update 9 domain/infrastructure specifications and author 1 new canonical design document (`docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`) establishing independent composable Voice routing with mandatory barge-in, conditional read-only Health Connect V1, conditional still-image Vision V1 with shared attachment pipeline, PC Character authority with local reactive Mood updates and emoji fallback, and the 5-tab companion shell with hybrid visual design tokens.
4. **Batch D5 Master Planning Spine, Golden Verification & PR Closure:**
   - Expand `MOBILE_WBS.md` to ~85–90 items using new stable IDs without overloading existing work items.
   - Expand `MOBILE_CHECKLIST.md` from MG1–MG12 to MG1–MG18 with formal qualification classes (`REQUIRED`, `CONDITIONAL`, `OPTIONAL`, `DEFERRED`).
   - Synchronize `MASTER_CHECKLIST.md`, `DECISION_REGISTER.md`, `SPRINT_ROADMAP.md`, `DELIVERY_INDEX.md`, `DECISION_DEBT.md`, and `DOCUMENTATION_MAP.md`.
   - Perform full-PR mechanical trailing-whitespace cleanup to restore green Docs Integrity CI.
   - Author point-in-time delivery walkthrough `docs/03_Walkthroughs/walkthrough-mobile-v1-batch-d-reconciliation.md` and update `CHANGELOG.md`.
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

### 2.2 Authority & Source Hierarchy

To prevent parallel authority and contradictory documentation, all edits during this delivery must strictly follow this normative hierarchy:

| Level | Source Artifact | Normative Role & Governance Rule |
| :--- | :--- | :--- |
| **Level 0** | **Source Code & Automated Tests** | Authoritative truth of what currently exists in the codebase. Never invent implemented reality from documentation. |
| **Level 1** | **Canonical Specifications (`docs/04_Architecture/`, `docs/05_Design/`)** | Normative truth for approved system baseline, domain contracts, and target architecture. |
| **Level 2** | **Master Planning Spine (`docs/02_Planning/00_Master/`)** | Work breakdown, delivery indexing, sprint roadmap, decision register, and golden verification checklists. |
| **Level 3** | **Approved Working Decision Source (`docs/00_Drafts/research/mobile/MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md`)** | Human-approved working decision source for Batch D reconciliation. Approved by Chris; provides the normative basis for canonical promotion. |
| **Level 4** | **Reconciliation Report (`docs/00_Drafts/research/mobile/MOBILE_ARCH_BATCH_D_RECONCILIATION_REPORT.md`)** | Audited inventory of gaps, conflicts, and alignments between the ledger and current canonical docs. |
| **Level 5** | **Benchmark Research (`docs/00_Drafts/research/mobile/benchmarks/MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md`)** | Non-canonical empirical evidence supporting hardware qualification. Never cited as normative requirement. |
| **Level 6** | **Android Prototype Code (`android/`)** | Reference evidence only. Deprecated legacy prototype, not production Flutter architecture. |

### 2.3 Reconciliation Audit Summary

The audited reconciliation report (`MOBILE_ARCH_BATCH_D_RECONCILIATION_REPORT.md`) establishes the exact scope of required canonical promotions:
- **AGREED (27 items):** Existing canonical architecture already satisfies the decision (e.g., PC Host authority, non-clinical health scope, no background eavesdropping, barge-in requirement).
- **CANONICAL_GAP (71 items):** Approved decisions that are omitted or understated in current canonical specifications and require promotion in Batches D2, D3, or D4.
- **CONTRADICTION (7 items):** Direct conflicts where current canonical docs state an outdated rule (e.g., local LLM forbidden on mobile, offline Alarms forbidden, 5-tab shell missing, etc.) that must be superseded.
- **IMPLEMENTATION_STATUS (1 item):** Context compaction rolling summary must preserve "NOT IMPLEMENTED" status.
- **STALE_PLANNING (2 items):** WBS and Mobile Checklist omit Batch D capabilities and require expansion in Batch D5.
- **PROTOTYPE_DIFF (1 item):** Android prototype differences remain reference evidence.
- **No Missing Approved Decisions:** All 109 Batch D decisions are resolved and ready for promotion.

---

## 3. Proposed File Changes & In-Place Logic

### 3.1 Batch D2 — Core Baseline, Identity, Offline Scheduling & Flutter Boundaries

**Goal:** Establish foundational Mobile operating-state semantics, enrollment lifecycle, offline scheduling authority, cross-device alert semantics, Routine occurrence behavior, temporal resolution, and stable Flutter/shared boundaries.

**Approved Decision Groups:**
`D-PHONE-01A`, `D-PHONE-01B`, `D-PHONE-02`, `D-SHARED-SCHED-01`, `D-PHONE-10`, `D-PHONE-11`, `D-SHARED-SCHED-02`, `D-SHARED-SCHED-03`, `D-SHARED-SCHED-04`, `D-SHARED-SCHED-04A` through `D-SHARED-SCHED-04E`, `D-PHONE-12`, `D-PHONE-12A` through `D-PHONE-12C`, `D-SHARED-FLUTTER-01` through `D-SHARED-FLUTTER-08`, `D-PHONE-FLUTTER-01`.

#### [MODIFY] `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
- **Primary Responsibility:** Normative baseline for Mobile client architecture, operational states, and ecosystem relationships.
- **Planned Changes:**
  - Update Section 1 & Section 3 to define the 3 orthogonal availability axes (`D-PHONE-01A`): PC Host Reachability (Local LAN / Encrypted Overlay / Unreachable), Internet Reachability (Available / Unavailable), and Inference Route (Local On-Device / PC Host / Cloud / None). Standalone Mobile is explicitly defined as an operational state, not an application failure.
  - Define Device Enrollment & Pairing Lifecycle (`D-PHONE-01B`): QR handshake, cryptographic key exchange, mutual authentication, and revocation semantics.
  - Formulate 1-Device to 1-Profile binding invariant (`D-PHONE-02`): In Mobile V1, an enrolled phone binds strictly to exactly one Profile. Mobile client cannot create, switch, or manage multi-profiles. Multi-phone support is explicitly deferred as Decision Debt (`DEBT-MOB-MULTI-DEVICE`).
  - Document Flutter client architecture baseline (`D-SHARED-FLUTTER-01` to `08`, `D-PHONE-FLUTTER-01`): Monorepo shared Dart packages (`core`, `models`, `client`, `contracts`) shared between Windows PC and Mobile, while UI presentation remains platform-specific. Explicitly note that `android/` Kotlin code is legacy prototype reference only.
- **Invariants to Preserve:** PC Host remains master administrator and root of trust; local data encryption at rest; Android Keystore for private keys.

#### [MODIFY] `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
- **Primary Responsibility:** Mobile offline mutation handling, synchronization protocols, and conflict resolution.
- **Planned Changes:**
  - Incorporate Mobile Outbox protocol for offline-created Reminders, Alarms, and pending intents (`D-PHONE-10`, `D-PHONE-11`).
  - Specify synchronization conflict resolution without Last-Write-Wins (LWW) resurrection (`D-SHARED-SCHED-04E`): Server mutation wins for shared entities; client offline mutations generate conflict records in the Activity Inbox rather than silent overwrites; tombstones prevent resurrection.
  - Define sync replay and idempotency guarantees across transport reconnection.
- **Invariants to Preserve:** Cryptographic payload verification; revision cursors; profile isolation during sync.

#### [MODIFY] `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`
- **Primary Responsibility:** Domain semantics for Tasks, Reminders, Alarms, and Routines.
- **Planned Changes:**
  - Authoritative Scheduling Ownership (`D-SHARED-SCHED-01`): PC Host owns recurring schedule definition, evaluation, and mutation.
  - Offline-Authorable Mobile Reminders (`D-PHONE-10`): Mobile user can author reminders offline; queued in local outbox with temporary UUID; synchronized upon reconnection.
  - Offline-Authorable Mobile Alarms (`D-PHONE-11`): Mobile user can set/edit device-local alarms offline; fired via native Android `AlarmManager` exact alarms.
  - Cross-Device Presentation Arbitration (`D-SHARED-SCHED-02`): Shared alert state semantics; dismissing on active device cancels ringing across devices via sync or local network broadcast; prevent duplicate ringing.
  - Protected Host Definitions (`D-SHARED-SCHED-03`): Complex PC-created automation and routine definitions remain read-only on mobile when offline; protected against unauthorized mobile mutation.
  - Routine Occurrence Caching vs. Autonomous Recurrence (`D-SHARED-SCHED-04`, `04A`): Mobile caches upcoming routine occurrences (next 24–48 hours) for presentation and execution; mobile does NOT run autonomous background recurrence evaluation.
  - Temporal Resolution & Parity (`D-SHARED-SCHED-04B` to `04D`): Parity with PC temporal parser for natural language inputs; timezone and clock change reconciliation (`D-SHARED-SCHED-04B`); missed occurrence handling after device sleep or power-off (`D-SHARED-SCHED-04C`); exact vs. fuzzy alarm window semantics (`D-SHARED-SCHED-04D`).
  - Clarify Quick Capture notes and audio memos (`D-PHONE-12`, `12A`, `12B`, `12C`): Standalone capture into local encrypted storage with offline search.
- **Invariants to Preserve:** Existing PC scheduler engine invariants; deterministic trigger evaluation; notification priority channel mappings.

#### [MODIFY] `docs/04_Architecture/01_Domains/android-companion.md`
- **Primary Responsibility:** Android platform specifics and native integration boundaries.
- **Planned Changes:**
  - Re-scope file as the Android Platform Adapter specification under Flutter (not standalone Kotlin production app).
  - Explicitly document native Android platform channels: `AlarmManager` for exact alarms (`SCHEDULE_EXACT_ALARM`), Foreground Services for persistent audio/voice, Health Connect adapter, Keystore secure storage wrapper.
  - State clearly that `android/` Jetpack Compose code is reference prototype evidence.
- **Invariants to Preserve:** Android permission requirements; battery optimization (Doze) compliance; foreground service notification requirements.

#### [MODIFY] `docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`
- **Primary Responsibility:** Profile boundaries, device enrollment, and credential management.
- **Planned Changes:**
  - Add Mobile Device Pairing & Profile Binding section (`D-PHONE-01B`, `D-PHONE-02`): 1 enrolled mobile device maps strictly to 1 Profile.
  - Enforce PC Host Account Authority: Revocation of device tokens occurs on PC; offline mobile client is disconnected upon next handshake when revoked.
  - Document offline cryptographic boundaries: Device-local secrets never leave the phone; profile data encrypted with device-derived key.
- **Invariants to Preserve:** PC multi-profile isolation; zero leakage between profiles; token rotation policies.

---

### 3.2 Batch D3 — AI Runtime, Conversations, Context, Memory & Tools

**Goal:** Establish production-capable local AI execution path, model/resource lifecycle, context budgeting and compaction, causal conversation behavior, selective Memory continuity, and Standalone Mobile Tool Gateway.

**Approved Decision Groups:**
`D-PHONE-01`, `D-PHONE-01C`, `D-PHONE-03`, `D-PHONE-05`, `D-PHONE-05A`, `D-SHARED-AI-01`, `D-SHARED-AI-02`, `D-SHARED-AI-03`, `D-PHONE-08`, `D-PHONE-08A`, `D-PHONE-09`, `D-SHARED-CONV-01`, `D-SHARED-CONV-02`, `D-SHARED-CONV-03`, `D-SHARED-CONV-03A`, `D-PHONE-13`, `D-PHONE-13A` through `D-PHONE-13F`, Gemma 3 1B cross-device research requirement.

#### [MODIFY] `docs/04_Architecture/SYSTEM_BASELINE.md`
- **Primary Responsibility:** System-wide architecture baseline and cross-client topology.
- **Planned Changes:**
  - Update Section 4 (Client Targets) to recognize Mobile V1 conditional local generative inference on qualified hardware alongside PC Host and Cloud routes (`D-PHONE-01`, `D-PHONE-03`).
  - Clarify tiering: Core companion capability operates without local LLM; local LLM is an enhancement path on qualified devices.
- **Invariants to Preserve:** PC Host is master runtime for complex orchestration and heavy local models (Qwen-2.5-7B, etc.).

#### [MODIFY] `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`
- **Primary Responsibility:** Model definitions, execution backends, and runtime management.
- **Planned Changes:**
  - Model/Runtime/Backend/Hardware Distinction (`D-PHONE-05`): Explicit separation between Model definition, Execution Runtime (e.g. llama.cpp, ExecuTorch), Backend accelerator (CPU, GPU/OpenCL, NPU), and Physical Hardware.
  - Model Lifecycle on Mobile (`D-PHONE-05A`): Single resident generative model maximum on phone; strict distinction between `unloaded` (removed from RAM/VRAM) and `deleted` (removed from disk); cold-load vs. warm-inference lifecycle.
  - Model Candidates as Replaceable Examples (`D-PHONE-03`): Mobile models (e.g., Gemma 3 1B, Gemma 2 2B, Qwen 2.5 1.5B) are replaceable candidate examples, not hard-coded architectural dependencies. Note Gemma 3 1B research qualification.
- **Invariants to Preserve:** Host model registry contracts; GGUF/quantization format standards; reproducible inference parameter validation.

#### [MODIFY] `docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`
- **Primary Responsibility:** Performance budgets, memory limits, and hardware governance.
- **Planned Changes:**
  - Progressive Resource Governor (`D-PHONE-05A`): Truthful progressive throttling across 4 tiers:
    - Tier 0 (Optimal): Full local inference enabled.
    - Tier 1 (Moderate Strain): Reduced context window, lower quantization, background model unload.
    - Tier 2 (Severe Thermal/Battery): Local LLM evicted; fallback to PC Host, Cloud, or rule-based templates.
    - Tier 3 (Critical Resource Emergency): All AI unloaded; core companion UI and offline alarms/notes only.
  - Thermal, battery, and memory thresholds for mobile hardware classes.
- **Invariants to Preserve:** PC resource governor rules; deterministic degradation paths; UI responsiveness priorities.

#### [MODIFY] `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`
- **Primary Responsibility:** Mobile hardware qualification, inference runtimes, and capability matrices.
- **Planned Changes:**
  - Update capability matrix: Standalone Mobile local LLM is a real production path for qualified devices (`D-PHONE-01`, `D-PHONE-03`).
  - Device Qualification Framework: Minimum 6GB RAM (8GB+ recommended), ARM64-v8a+, thermal stability under sustained inference.
  - Privacy Sanitization: Sanitize specific retail phone model names from canonical text into generic "Reference Android Device A (Snapdragon 8 Gen 2 / 8GB RAM / Adreno 740)" while preserving technical measurements.
  - Clarify candidate runtimes (llama.cpp Android, ExecuTorch) as non-binding implementation choices.
- **Invariants to Preserve:** Graceful degradation on unqualified devices; zero crashes on Out-of-Memory (OOM).

#### [MODIFY] `docs/04_Architecture/01_Domains/assistant-and-conversations.md`
- **Primary Responsibility:** Conversation turns, dialogue history, context assembly, and conversation branching.
- **Planned Changes:**
  - Conversation History Authority (`D-SHARED-CONV-02`): Raw conversation transcript remains authoritative truth. Rolling compaction and derived summaries are convenience views, never canonical source records.
  - Context Compaction Status: Explicitly preserve that rolling context compaction is "NOT IMPLEMENTED" in current codebase.
  - Causal Branching & Forking (`D-SHARED-CONV-01`): Forking/regenerating conversation turns uses causal DAG metadata (parent message pointer), never Last-Write-Wins.
  - Turn Coordination (`D-SHARED-CONV-03`, `03A`): Turn queueing, user interrupt/barge-in, and safe regeneration semantics.
- **Invariants to Preserve:** Conversation schema contracts; message ordering guarantees; SSE streaming protocols.

#### [MODIFY] `docs/04_Architecture/01_Domains/memory-and-personalization.md`
- **Primary Responsibility:** Memory storage, retrieval, personalization, and user profile modeling.
- **Planned Changes:**
  - Selective Memory Continuity (`D-PHONE-08`, `08A`): Mobile client caches relevant memory facts for offline context injection; mobile does NOT perform autonomous memory consolidation or write directly to canonical Memory DB.
  - Pending Memory Intent Outbox (`D-PHONE-09`): User-directed explicit memory requests on mobile are recorded as pending intents in the sync outbox, submitted to PC Host D7 Memory engine upon reconnection.
  - Provenance Tracking: All memories maintain strict origin and device provenance metadata.
- **Invariants to Preserve:** PC Host D7 Memory engine remains sole authoritative memory consolidator; episodic and semantic memory schema contracts.

#### [MODIFY] `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`
- **Primary Responsibility:** Tool definitions, execution gateway, permissions, and security guardrails.
- **Planned Changes:**
  - Standalone Mobile Tool Gateway (`D-PHONE-13`): Mobile client provides a local tool execution environment strictly adhering to Decision D9.
  - Safe Tool Scope (`D-PHONE-13A` to `13F`): Device-local tools allowed (alarms, reminders, device settings toggles, calendar integration, camera capture).
  - Explicit Tool Prohibitions: Strictly NO generic shell execution, NO unrestricted filesystem access, NO access to master credentials/secrets, and NO PC administration capabilities from mobile tool gateway.
  - Side Effect Invariants: Committed tool side effects are never silently replayed or rolled back during sync reconciliation.
- **Invariants to Preserve:** Tool confirmation UX policies; audit logging of all executed actions.

#### [MODIFY] `docs/04_Architecture/03_Integrations/web-current-information.md`
- **Primary Responsibility:** Web search, current information retrieval, and online tool routing.
- **Planned Changes:**
  - Internet Access != Cloud LLM Permission (`D-PHONE-01C`): Clear architectural distinction between accessing the public internet for web search/weather/APIs vs. sending user prompts/conversations to third-party cloud LLMs. Each requires independent user consent.
- **Invariants to Preserve:** Privacy-first search options; sanitized search query formatting.

---

### 3.3 Batch D4 — Voice, Health, Vision, Character/Presence & Mobile UX

**Goal:** Establish composable Voice, conditional Health Connect V1, conditional local still-image Vision, Character/Mood event behavior, future Presence boundaries, language extensibility, and the approved Mobile product UX.

**Approved Decision Groups:**
`D-PHONE-04`, `D-PHONE-14` through `D-PHONE-14G`, Voice shared invariants, `D-PHONE-15` through `D-PHONE-15E`, `D-SHARED-HEALTH-01` through `D-SHARED-HEALTH-04`, `D-PHONE-16` through `D-PHONE-16E`, `D-SHARED-VISION-01`, `D-PHONE-06`, Character authority rule, `D-PHONE-EMO-01`, `D-PHONE-12D`, `D-PHONE-12E`, `P-SHARED-PRESENCE-01`, `P-PHONE-AR-01`, `P-PHONE-AR-02`, `P-PRESENCE-02`, `D-PHONE-UX-01` through `D-PHONE-UX-10`, `D-SHARED-LANG-01`, `D-SHARED-LANG-02`.

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
  - Voice Invariants: Mandatory user barge-in (speech interrupt cancels ongoing TTS immediately); strictly NO background eavesdropping or ambient listening; local STT is conditional until qualified on hardware; whisper.cpp and sherpa-onnx are replaceable candidate examples.
  - Voice Foreground Service Lifecycle (`D-PHONE-14F`): Audio session managed via Android Foreground Service with persistent notification and microphone indicator.
- **Invariants to Preserve:** Privacy-respecting audio buffer zeroing; audio focus handling (ducking/pausing during calls).

#### [MODIFY] `docs/04_Architecture/03_Integrations/health-and-wearables.md`
- **Primary Responsibility:** Health metrics, wearable integration, and biometric context.
- **Planned Changes:**
  - Health Connect V1 Allocation (`D-PHONE-15`): Formally designated as CONDITIONAL Mobile V1 capability.
  - Read-Only Boundary (`D-PHONE-15A`): Mobile client only reads approved health data; never writes or modifies Health Connect records.
  - Granular Permissions & Consent (`D-PHONE-15B`): Granular permission per metric type (steps, sleep, heart rate); separate explicit consent for cloud transmission.
  - Non-Clinical Boundary (`D-PHONE-15C`): Strictly wellness and routine context; explicit medical disclaimer; Health data != Memory (never written directly into core personality memory).
  - Data Normalization & Freshness (`D-SHARED-HEALTH-01` to `04`): Shared PC/Mobile schema; unavailable or stale data is represented explicitly, never assumed to be zero.
- **Invariants to Preserve:** Data retention limits; encrypted storage of local health caches.

#### [MODIFY] `docs/04_Architecture/01_Domains/multimodal-and-media.md`
- **Primary Responsibility:** Vision, image handling, camera capture, and file attachments.
- **Planned Changes:**
  - Conditional Local Still-Image Vision V1 (`D-PHONE-16`, `D-SHARED-VISION-01`): Local VLM inference (e.g. SmolVLM, Moondream) is CONDITIONAL Mobile V1 on qualified hardware; fallback to PC Host or Cloud.
  - Shared Attachment Pipeline: Camera and gallery captures feed standard conversation attachment pipeline.
  - Vision Invariants: Strictly NO ambient or background camera processing in V1; user-initiated capture only; no silent cloud upload; Vision data != Memory.
- **Invariants to Preserve:** EXIF metadata stripping for privacy; local image compression budgets.

#### [MODIFY] `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`
- **Primary Responsibility:** Character definitions, personality traits, emotion state, and mood expressions.
- **Planned Changes:**
  - Character Authority (`D-PHONE-06`): PC Host owns canonical Character definition, persona configuration, and evolution.
  - Local Reactive Mood Updates (`D-PHONE-EMO-01`): Mobile maintains a local reactive mood/emotion state reflecting immediate conversational interaction; syncs state changes to Host.
  - Emoji Mood Fallback (`D-PHONE-12D`, `12E`): Guaranteed lightweight fallback using system emoji when rich 2D/3D assets or expressions are unavailable or low-power mode is active.
  - Presence Boundaries (`P-SHARED-PRESENCE-01`, `P-PHONE-AR-01`, `02`, `P-PRESENCE-02`): AR and spatial companion presence are formally categorized as Experimental / Post-V1 (Phase 9+).
  - Language Extensibility (`D-SHARED-LANG-01`, `02`): Companion language persona registry is extensible; Companion language persona is distinct from app UI localization.
- **Invariants to Preserve:** Persona consistency; ethical companion guardrails; emotion bounds (-1.0 to +1.0 valence/arousal).

#### [ADD] `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`
- **Primary Responsibility:** Canonical Mobile UI/UX specification, layout shell, design tokens, and interaction flows.
- **Planned Changes:** Create new design document adhering to `docs/05_Design/` flat numbering convention (`01_` through `07_` exist):
  - 5-Tab Companion Shell (`D-PHONE-UX-01`): Navigation structure: Home, Schedule, Companion, Activity, More.
  - Icon-First Navigation (`D-PHONE-UX-02`): Accessible icon-first navigation bar with explicit labels and screen-reader semantics.
  - Companion-Centered Home (`D-PHONE-UX-03`): Primary view features companion presence, active mood, quick status, and immediate conversation entry.
  - Unified Interaction Surface (`D-PHONE-UX-04`): Seamless transition between text chat, voice mode, and quick actions.
  - Unified Schedule Presentation (`D-PHONE-UX-05`): Combined view of Reminders, Alarms, Tasks, and Routine occurrences.
  - Activity & Reconciliation Inbox (`D-PHONE-UX-06`): Transparent inbox displaying sync status, conflict notices, and background task completions.
  - Truthful Capability Status (`D-PHONE-UX-07`): Transparent indicators showing current operational state (PC Connected / Standalone / Offline / Cloud) without presenting Standalone as an error.
  - Hybrid Visual Design Language (`D-PHONE-UX-08`, `09`): Minimalist foundational geometry, selective Neumorphic tactile depth, contextual Glass / Liquid Glass surfaces, pure OLED dark theme by default, full support for reduced motion and low-effects modes.
  - Localization & Personality Language (`D-PHONE-UX-10`, `D-SHARED-LANG-01`): UI localization decoupled from Companion persona language; emoji Mood fallback rendering.
- **Invariants to Preserve:** Compliance with repository design system; accessibility touch targets (min 48x48dp); high contrast ratios.

---

### 3.4 Batch D5 — Master Planning Spine, Golden Verification, Documentation Integration & PR Handoff

**Goal:** Synchronize the master planning spine, Work Breakdown Structure, Golden acceptance checklist, decision register, and documentation map; perform full-PR whitespace cleanup; author walkthrough; and prepare PR #21 for final closure.

#### [MODIFY] `docs/02_Planning/00_Master/MOBILE_WBS.md`
- **Primary Responsibility:** Mobile Work Breakdown Structure and task definitions.
- **Planned Changes:**
  - Expand WBS from ~50 items to ~85–90 detailed items reflecting all Batch D decisions.
  - Add new stable WBS task IDs without overloading existing IDs:
    - `MOB-VOICE-005` (Local TTS Qualification & Engine Adapter)
    - `MOB-VOICE-006` (Local STT Qualification & Engine Adapter)
    - `MOB-VOICE-007` (Cloud Voice Routing & Provider Gateway)
    - `MOB-VOICE-008` (Voice Pipeline Audio Session & Barge-in Coordination)
    - `MOB-HEALTH-001` through `MOB-HEALTH-005` (Health Connect V1 Read-Only Pipeline)
    - `MOB-VISION-001` through `MOB-VISION-004` (Still-Image VLM & Attachment Pipeline)
    - `MOB-UX-001` through `MOB-UX-010` (5-Tab Shell, Navigation, Design Tokens, Activity Inbox)
    - `MOB-SCHED-008` (Cross-Device Presentation Arbitration)
    - `MOB-SCHED-009` (Offline Reminder & Alarm Creation Flow)
    - `MOB-CONV-008` (Causal Conversation Branching & Forking Engine)
    - `MOB-TOOL-001` through `MOB-TOOL-004` (Mobile Standalone Tool Gateway)
  - Validate dependency graph: zero duplicate IDs, zero broken cross-references, zero dependency cycles.
- **Invariants to Preserve:** Existing task IDs and completed baseline milestones.

#### [MODIFY] `docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`
- **Primary Responsibility:** Mobile Golden verification criteria and capability qualification checklist.
- **Planned Changes:**
  - Expand Golden criteria from MG1–MG12 to MG1–MG18 with explicit qualification classes:
    - **MG1 (Offline Companion Core & Shell):** `REQUIRED` — Launch, 5-tab shell, encrypted storage, and offline alarm presentation without network.
    - **MG2 (Pairing & Profile Binding):** `REQUIRED` — Cryptographic QR handshake, Keystore token storage, 1-to-1 profile binding.
    - **MG3 (PC Host Connectivity & Sync):** `REQUIRED` — Mutual TLS/overlay transport, delta replication, tombstone handling, conflict inbox.
    - **MG4 (Offline Reminders & Alarms):** `REQUIRED` — Local authoring, Exact Alarm triggering across reboot/timezone, outbox sync.
    - **MG5 (Routine Occurrence Caching):** `REQUIRED` — Next 24h routine presentation, trigger display, no autonomous recurrence evaluation.
    - **MG6 (Conversation History & Causal Branching):** `REQUIRED` — Authoritative transcript, message DAG, fork/regenerate without LWW.
    - **MG7 (Context Assembly & Compaction Truth):** `REQUIRED` — Budgeted context window, rolling compaction marked "NOT IMPLEMENTED".
    - **MG8 (Memory Continuity & Intent Outbox):** `REQUIRED` — Cached memory injection, explicit memory intents queued to PC Host D7.
    - **MG9 (Standalone Tool Gateway):** `REQUIRED` — Local tool execution under D9, zero generic shell/filesystem access.
    - **MG10 (Internet Current Information):** `REQUIRED` — Web search permission decoupled from cloud LLM consent.
    - **MG11 (Character Persona & Local Mood):** `REQUIRED` — PC character authority, local reactive mood, emoji fallback.
    - **MG12 (Mobile Design System & Visual Tokens):** `REQUIRED` — Minimalist + Neumorphism + Glass tokens, OLED dark mode, reduced motion.
    - **MG13 (Composable Voice Pipeline):** `REQUIRED` — Independent STT/LLM/TTS routing, mandatory barge-in, foreground service lifecycle.
    - **MG14 (Resource Governor & Progressive Degradation):** `REQUIRED` — Truthful 4-tier throttling under memory/thermal/battery load.
    - **MG15 (Local Generative LLM Inference):** `CONDITIONAL` — On-device LLM on qualified hardware (6GB+ RAM, ARM64), 1 resident model max.
    - **MG16 (Health Connect V1 Read-Only):** `CONDITIONAL` — Granular permission read, non-clinical presentation, separate cloud sync consent.
    - **MG17 (Local Still-Image Vision V1):** `CONDITIONAL` — User-initiated camera/gallery VLM inference on qualified hardware.
    - **MG18 (Extensible Language Registry):** `OPTIONAL` — Multi-language companion persona registry decoupled from UI locale.
- **Invariants to Preserve:** Explicit evidence requirements for each verification gate.

#### [MODIFY] `docs/02_Planning/00_Master/MASTER_CHECKLIST.md`
- **Primary Responsibility:** Top-level project milestone delivery checklist.
- **Planned Changes:** Update Line 6 (Mobile Architecture Gate) to cross-reference the expanded MG1–MG18 criteria and link to `MOBILE_CHECKLIST.md`.
- **Invariants to Preserve:** Preserved status of PC V1 and Phase 8 checklist items.

#### [MODIFY] `docs/02_Planning/00_Master/DECISION_REGISTER.md`
- **Primary Responsibility:** Authoritative registry of architectural decisions.
- **Planned Changes:** Register approved Batch D decisions (`D-PHONE-01` through `D-PHONE-16`, `D-SHARED-SCHED-*`, `D-SHARED-AI-*`, `D-SHARED-CONV-*`, `D-SHARED-FLUTTER-*`, `D-SHARED-HEALTH-*`, `D-SHARED-VISION-*`, `D-PHONE-UX-*`, `D-SHARED-LANG-*`).
- **Invariants to Preserve:** Existing registered decisions ADR-0001 through ADR-0017.

#### [MODIFY] `docs/02_Planning/00_Master/DECISION_DEBT.md`
- **Primary Responsibility:** Catalog of deferred decisions, technical debt, and open architectural questions.
- **Planned Changes:** Index `DEBT-MOB-MULTI-DEVICE` (1 Profile to multiple mobile phones architecture deferred as open Decision Debt for post-V1).
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
- **Planned Changes:** Add a concise entry at the top of the changelog summarizing MOBILE-ARCH Batch D reconciliation and canonical promotion.
- **Invariants to Preserve:** Append-only rule (read top 15 lines only, append new section).

#### [MODIFY] Full PR Whitespace Mechanical Cleanup
- **Primary Responsibility:** Restore green CI for Docs Integrity workflow on GitHub Actions.
- **Planned Changes:** Run `git diff develop...HEAD --name-only` across all files in the PR branch. For any Markdown/text file with trailing whitespace flagged by `git diff --check`, perform mechanical in-place stripping of trailing spaces/tabs without altering semantics.
- **Invariants to Preserve:** Zero semantic changes; preserve valid Markdown formatting.

---

## 4. Step-by-Step Implementation Sequence

```
PLAN AUTHORING (Current Task)
  │
  ▼
STOP: Independent Chris & GPT Plan Review & Approval
  │
  ▼
[Post-Approval] Initialize Branch-Active Tracking:
  docs/01_Tracking/active/task-mobile-v1-canonicalization.md
  │
  ▼
BATCH D2: Core Baseline, Identity, Scheduling & Flutter Boundaries
  │  (MOBILE_SYSTEM_BASELINE.md, mobile-offline-and-sync.md,
  │   tasks-reminders-alarms-and-routines.md, android-companion.md,
  │   profiles-and-devices.md)
  ▼
VERIFY D2: Trailing whitespace, markdown links, git diff --check
  │
  ▼
STOP: Independent Chris & GPT Review of Batch D2
  │
  ▼
BATCH D3: AI Runtime, Conversations, Context, Memory & Tools
  │  (SYSTEM_BASELINE.md, runtime-and-models.md, performance-and-capacity.md,
  │   mobile-capabilities-and-runtime.md, assistant-and-conversations.md,
  │   memory-and-personalization.md, tool-permissions-and-actions.md,
  │   web-current-information.md)
  ▼
VERIFY D3: Trailing whitespace, markdown links, git diff --check
  │
  ▼
STOP: Independent Chris & GPT Review of Batch D3
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
VERIFY D4: Trailing whitespace, markdown links, git diff --check
  │
  ▼
STOP: Independent Chris & GPT Review of Batch D4
  │
  ▼
BATCH D5: Planning Spine, Golden Verification, Whitespace Cleanup & PR Handoff
  │  (MOBILE_WBS.md, MOBILE_CHECKLIST.md, MASTER_CHECKLIST.md,
  │   DECISION_REGISTER.md, SPRINT_ROADMAP.md, DELIVERY_INDEX.md,
  │   DECISION_DEBT.md, DOCUMENTATION_MAP.md, CHANGELOG.md,
  │   walkthrough-mobile-v1-batch-d-reconciliation.md,
  │   Full PR trailing-whitespace mechanical cleanup)
  ▼
VERIFY D5: Whole PR git diff --check, relative link check, repo verification
  │
  ▼
STOP: Independent Closure Gate Review (Chris & GPT)
  │
  ▼
Present PR #21 Description Update Proposal
  │
  ▼
Chris executes commit, push, PR update, triggers CI, and merges
```

### 4.1 Branch-Active Tracking Lifecycle

1. **Shared Task Integrity:** `docs/01_Tracking/task.md` remains the high-level milestone integration tracker on `develop`/`master`. It MUST NOT be modified during branch work to reflect transient branch heartbeats or PR states.
2. **Branch Active Tracker Creation:** Immediately after plan approval and before starting Batch D2, create `docs/01_Tracking/active/task-mobile-v1-canonicalization.md` using the standard active tracking template.
3. **In-Flight Tracking:** Maintain batch progress, completed edits, verification check outputs, and open stop conditions in `task-mobile-v1-canonicalization.md`.
4. **Closure Archiving:** Upon successful completion of Batch D5 and independent Closure Gate approval, move `task-mobile-v1-canonicalization.md` to `docs/01_Tracking/archive/task-2026-10-xx-mobile-v1-canonicalization.md` as part of the same delivery branch before final merge.

### 4.2 M1 Sequencing Rule

- **Governance Requirement:** Flutter Desktop M1 scaffolding and implementation is sequenced AFTER the reopened MOBILE-ARCH pass is fully re-closed and merged.
- **Clarification:** While Batch D is primarily architectural documentation and does not create an impassable code-level dependency blocking Flutter Desktop scaffolding, project governance dictates that target cross-platform boundaries, shared package topologies, and ecosystem contracts must be frozen and approved before desktop implementation begins.
- **Invariant:** M1 remains marked as PENDING / SEQUENCED; it will NOT be marked active during this plan.

### 4.3 Recommended Conventional Commit Checkpoints

Because Chris owns all Git mutations, the implementation agent will halt at the end of each batch, report verification results, and provide a single Conventional Commit suggestion for Chris to execute:
1. **Plan Authoring (Current):** `docs(mobile): plan Batch D canonical promotion`
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
- [ ] **Gate 0 (Plan Approval):** Chris and GPT review and approve this plan file before any canonical files are edited.
- [ ] **Gate 1 (Batch D2 Approval):** Chris and GPT review canonical diffs for `MOBILE_SYSTEM_BASELINE.md`, `mobile-offline-and-sync.md`, `tasks-reminders-alarms-and-routines.md`, `android-companion.md`, and `profiles-and-devices.md`.
- [ ] **Gate 2 (Batch D3 Approval):** Chris and GPT review canonical diffs for runtime, performance, assistant, memory, tool, and web specifications, including reference-device sanitization.
- [ ] **Gate 3 (Batch D4 Approval):** Chris and GPT review canonical diffs for voice, health, vision, character, and the new design specification `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`.
- [ ] **Gate 4 (Batch D5 Closure Gate):** Chris and GPT perform final closure review of the master planning spine, WBS, Golden checklist MG1–MG18, walkthrough, changelog, and PR #21 description update.

### 5.3 Batch-by-Batch Acceptance Criteria

#### Batch D2 Acceptance Criteria
- [ ] **Orthogonal Operating States:** Baseline clearly defines Host reachability, internet connectivity, and inference routing as 3 orthogonal axes. Standalone Mobile is documented as an operational state, not an error.
- [ ] **Profile Binding Invariant:** 1 enrolled phone binds strictly to exactly 1 Profile. Multi-phone support is documented as deferred Decision Debt (`DEBT-MOB-MULTI-DEVICE`).
- [ ] **Host Admin Authority:** PC Host retains exclusive authority over Account and Profile administration.
- [ ] **Offline Reminders & Alarms:** Mobile Reminders and Alarms created on the phone are offline-authorable and queued in the outbox.
- [ ] **Protected Host Definitions:** Host-created automation and complex routines remain read-only and tamper-proof while mobile is offline.
- [ ] **Routine Occurrence Presentation:** Routine occurrence caching (24–48h) is explicitly decoupled from autonomous recurrence evaluation.
- [ ] **Temporal Parity:** Mobile natural language scheduling semantics share PC temporal intent parser contracts; timezone/clock drift reconciliation is specified.
- [ ] **No LWW Resurrection:** Synchronization conflict policy explicitly forbids Last-Write-Wins resurrection of deleted entities.
- [ ] **Flutter Shared-Core Boundaries:** Workspace topology enforces shared Dart packages (`core`, `models`, `client`) with platform-specific presentation.
- [ ] **Prototype Demoted:** Android Jetpack Compose code in `android/` is unambiguously documented as historical reference evidence.

#### Batch D3 Acceptance Criteria
- [ ] **Local LLM Production Path:** Local generative LLM inference is established as a real V1 capability path on qualified mobile devices.
- [ ] **Non-Blocking Core:** Core mobile companion functionality survives completely on devices without local generative inference.
- [ ] **Component Separation:** Explicit separation between Model definition, Runtime engine, Backend accelerator, and Hardware.
- [ ] **Single Resident LLM:** Strict policy permitting a maximum of 1 resident generative LLM in mobile memory.
- [ ] **Lifecycle States:** Unloaded model state (`unloaded`) is clearly distinguished from deleted model state (`deleted`).
- [ ] **Truthful Resource Governor:** Progressive 4-tier throttling based on real thermal, battery, and memory metrics.
- [ ] **Transcript Authority:** Raw conversation transcript remains authoritative truth; derived summaries are not primary records.
- [ ] **Compaction Truth:** Context compaction rolling summary is truthfully documented as "NOT IMPLEMENTED" in current codebase.
- [ ] **Memory Intent Outbox:** Pending explicit memory items created offline are outbox intents submitted to PC Host D7 engine, not direct Mobile DB writes.
- [ ] **Host Memory Authority:** PC Host D7 Memory engine retains exclusive authority over canonical user memory.
- [ ] **Causal Branching:** Conversation turn forking and regeneration use DAG parent pointers, never LWW.
- [ ] **Turn Coordination:** Message queueing, interrupt handling, and safe turn regeneration semantics are specified.
- [ ] **Side Effect Invariant:** Committed tool actions are never silently replayed or rolled back during sync reconciliation.
- [ ] **Standalone Tool Gateway:** Mobile tool execution strictly follows Decision D9 with granular permissions.
- [ ] **Strict Tool Prohibitions:** Explicitly forbids generic shell, unrestricted filesystem, master secrets access, or PC administration.
- [ ] **Internet vs. Cloud LLM:** Internet access permission is strictly decoupled from third-party Cloud LLM transmission consent.
- [ ] **Benchmark Evidence Role:** Benchmark data is cited only as non-canonical qualification evidence; retail phone name is evaluated for generic sanitization in canonical docs.

#### Batch D4 Acceptance Criteria
- [ ] **Composable Voice Routing:** Local, Host, and Cloud routes for STT, reasoning, and TTS are independently composable.
- [ ] **Mandatory Barge-In:** User speech immediately interrupts and cancels active TTS playback.
- [ ] **No Eavesdropping:** Background listening and ambient audio capture are strictly prohibited.
- [ ] **Conditional Local STT:** On-device STT is conditional upon hardware qualification; whisper.cpp is documented as a candidate example.
- [ ] **Voice Foreground Service:** Persistent audio capture requires native foreground service with visible notification indicator.
- [ ] **Health Connect Conditional V1:** Health Connect is formally designated as CONDITIONAL Mobile V1 capability.
- [ ] **Read-Only Health Pipeline:** Mobile client only reads authorized Health Connect records; never writes.
- [ ] **Granular Health Consent:** Per-metric permissions and separate consent for cloud transmission.
- [ ] **Non-Clinical Boundary:** Clear medical disclaimer; health metrics are strictly context, never written directly to core Memory.
- [ ] **Health Data Normalization:** Shared PC/Mobile schema; unavailable/stale data is never represented as zero.
- [ ] **Conditional Local Vision V1:** Still-image VLM inference is CONDITIONAL Mobile V1 on qualified hardware.
- [ ] **Shared Attachment Pipeline:** Camera and gallery captures feed standard conversation attachment pipeline.
- [ ] **Vision Invariants:** No ambient/background camera processing in V1; no silent cloud upload; Vision data != Memory.
- [ ] **Character Authority:** PC Host retains canonical ownership over Character persona and definitions.
- [ ] **Local Reactive Mood:** Mobile maintains responsive local mood state reacting to dialogue and syncs to Host.
- [ ] **Emoji Mood Fallback:** Guaranteed system emoji expression fallback for low-power or unaccelerated environments.
- [ ] **Presence Boundaries:** AR and spatial presence are formally classified as Post-V1 (Phase 9+).
- [ ] **Extensible Language Registry:** Companion persona language is extensible and decoupled from UI localization.
- [ ] **5-Tab Companion Shell:** New design doc `08_Mobile_Companion_Shell_and_UX.md` specifies Home, Schedule, Companion, Activity, More tabs.
- [ ] **Truthful UX Status:** UI clearly displays current operational state without framing Standalone as an error.
- [ ] **Hybrid Visual Design Tokens:** Minimalist base, selective Neumorphism, contextual Glass surfaces, OLED dark mode default, reduced motion support.

#### Batch D5 Acceptance Criteria
- [ ] **WBS Expansion:** `MOBILE_WBS.md` expanded to ~85–90 items using new stable IDs without overloading existing IDs.
- [ ] **Graph Integrity:** Zero duplicate WBS IDs, zero dangling dependencies, zero dependency cycles.
- [ ] **Golden Criteria MG1–MG18:** `MOBILE_CHECKLIST.md` expanded to 18 criteria with explicit qualification classes (`REQUIRED`, `CONDITIONAL`, `OPTIONAL`, `DEFERRED`).
- [ ] **Master Checklist Alignment:** `MASTER_CHECKLIST.md` Line 6 updated with cross-references to expanded Golden criteria.
- [ ] **Planning Spine Synchronized:** `DECISION_REGISTER.md`, `SPRINT_ROADMAP.md`, `DELIVERY_INDEX.md`, and `DOCUMENTATION_MAP.md` aligned.
- [ ] **Decision Debt Updated:** `DEBT-MOB-MULTI-DEVICE` formally cataloged in `DECISION_DEBT.md`.
- [ ] **Docs Integrity Whitespace Clean:** Full PR diff against `develop` passes `git diff --check` with 0 trailing whitespace errors.
- [ ] **Walkthrough Authored:** Delivery walkthrough `walkthrough-mobile-v1-batch-d-reconciliation.md` authored.
- [ ] **Changelog Appended:** Top 15 lines of `CHANGELOG.md` inspected and new entry appended cleanly.
- [ ] **PR #21 Description Prepared:** Updated PR summary ready for posting upon Closure Gate approval.

---

## 6. Risks, Recovery & Rollback

### 6.1 Explicit Stop Conditions

The implementation agent MUST immediately halt execution and request guidance from Chris and GPT if any of the following conditions arise:
1. **True Conflict with Frozen PC/Shared Architecture:** A promoted decision contradicts an established PC V1 invariant (e.g., PC Host Account/Profile administration authority, Multi-Profile cryptographic boundaries).
2. **Missing Approved Decision:** Implementation requires a product decision that is not present in `MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md`.
3. **Incompatible ADR Behavior:** A promoted requirement conflicts with an accepted Architectural Decision Record (ADR-0001 through ADR-0017).
4. **Authority Ambiguity:** Unclear normative ownership between shared domain specifications and mobile-specific baseline files.
5. **Security / Privacy Regression:** A proposed change weakens local encryption at rest, exposes credentials, enables ambient listening/recording, or permits unconsented cloud uploads.
6. **Invention of Hard Hardware/Model Requirements:** An urge to mandate a specific retail device, proprietary runtime, or specific AI model as a permanent architecture constraint rather than a replaceable candidate.
7. **Implementation Behavior Invention:** An urge to modify source code, test suites, or invent false "implemented" statuses to make documentation appear complete.
8. **Hidden Cross-Domain Contradiction:** An inconsistency between two canonical domains (e.g., Voice vs. Background Execution, Health vs. Memory) not identified during reconciliation.
9. **Multi-Phone Necessity:** Discovery that 1 Profile to multiple phones is mandatory for Mobile V1 rather than deferrable as Decision Debt.
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
