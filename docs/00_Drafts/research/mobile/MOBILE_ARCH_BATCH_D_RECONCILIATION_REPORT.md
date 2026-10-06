# AI Companion — MOBILE-ARCH Batch D Reconciliation Report

> **Document Role:** Comprehensive Contradiction Analysis, Shared-PC Compatibility Audit, and Canonical Promotion Strategy for MOBILE-ARCH Batch D.  
> **Status:** Working Research Artifact — Independent Review Checkpoint (R1 / Batch D1).  
> **Human Approver / Git Mutation Owner:** Chris.  
> **Working Branch:** `docs/mobile-v1-canonicalization`.  
> **Starting HEAD SHA:** `cef9baee3d61a90c884e1915b49ff4978d583da7`.  
> **Authority Precedence:** This report is an analytical research draft under `docs/00_Drafts/research/mobile/`. It does **not** alter canonical architecture, planning spine documents, or code. Canonical promotion requires Chris/GPT independent review and approved domain batching.

---

## A. Repository Starting State

1. **Active Branch:** `docs/mobile-v1-canonicalization`
2. **Exact Starting HEAD SHA:** `cef9baee3d61a90c884e1915b49ff4978d583da7`
3. **Working Tree Status Before Edits:** Clean (`git status --short` returned 0 modified, 0 staged, 0 untracked files prior to writing Batch D research draft files).
4. **Git Mutation Governance:** Strictly respected. Zero branches created or switched; zero commits, tags, merges, rebases, stashes, resets, or PR mutations performed.
5. **PR #21 Status:** Reopened by Chris for MOBILE-ARCH Batch D product reconciliation. The current PR #21 description reflects the historical Batches A–C closure (`889bae5d2a0eb6afdc3d7a8dc19592c9304114db` / `cef9baee3d61a90c884e1915b49ff4978d583da7`), which claims MOBILE-ARCH is complete and lists Health Connect, local VLM, and autonomous routines as deferred non-goals. PR #21 must remain unmerged until Batch D reconciliation, canonical promotion, independent review, closure, and fresh PR CI are completed.

---

## B. Files Inspected

Every file listed below was inspected directly in the working repository:

### 1. Governance & Project Rules
- [`AGENTS.md`](../../../../AGENTS.md)
- [`docs/06_Guides/DELIVERY_WORKFLOW.md`](../../../06_Guides/DELIVERY_WORKFLOW.md)
- [`docs/06_Guides/DOCUMENTATION_MAP.md`](../../../06_Guides/DOCUMENTATION_MAP.md)
- [`docs/01_Tracking/archive/task-2026-10-04-mobile-v1-canonicalization.md`](../../../01_Tracking/archive/task-2026-10-04-mobile-v1-canonicalization.md)
- [`docs/03_Walkthroughs/walkthrough-mobile-v1-canonical-architecture.md`](../../../03_Walkthroughs/walkthrough-mobile-v1-canonical-architecture.md)

### 2. Canonical Architecture & System Baselines
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../../04_Architecture/SYSTEM_BASELINE.md)
- [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../../../04_Architecture/MOBILE_SYSTEM_BASELINE.md)
- [`docs/04_Architecture/01_Domains/android-companion.md`](../../../04_Architecture/01_Domains/android-companion.md)
- [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../../../04_Architecture/01_Domains/assistant-and-conversations.md)
- [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../../../04_Architecture/01_Domains/characters-personality-and-emotion.md)
- [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](../../../04_Architecture/01_Domains/memory-and-personalization.md)
- [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../../../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md)
- [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../../../04_Architecture/01_Domains/voice-and-audio.md)
- [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../../../04_Architecture/01_Domains/multimodal-and-media.md)
- [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../../../04_Architecture/02_Data_and_Security/profiles-and-devices.md)
- [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](../../../04_Architecture/02_Data_and_Security/authentication-and-secrets.md)
- [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../../../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md)
- [`docs/04_Architecture/03_Integrations/health-and-wearables.md`](../../../04_Architecture/03_Integrations/health-and-wearables.md)
- [`docs/04_Architecture/03_Integrations/web-current-information.md`](../../../04_Architecture/03_Integrations/web-current-information.md)
- [`docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`](../../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md)
- [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../../../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md)
- [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](../../../04_Architecture/04_Infrastructure/runtime-and-models.md)
- [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](../../../04_Architecture/04_Infrastructure/performance-and-capacity.md)

### 3. Accepted Architectural Decision Records (ADRs)
- [`docs/04_Architecture/decisions/ADR-0004-d3-android-application-identity.md`](../../../04_Architecture/decisions/ADR-0004-d3-android-application-identity.md)
- [`docs/04_Architecture/decisions/ADR-0005-d4-profile-device-credential-boundary.md`](../../../04_Architecture/decisions/ADR-0005-d4-profile-device-credential-boundary.md)
- [`docs/04_Architecture/decisions/ADR-0006-d5-remote-access-trust-boundary.md`](../../../04_Architecture/decisions/ADR-0006-d5-remote-access-trust-boundary.md)
- [`docs/04_Architecture/decisions/ADR-0007-d6-controlled-model-acquisition.md`](../../../04_Architecture/decisions/ADR-0007-d6-controlled-model-acquisition.md)
- [`docs/04_Architecture/decisions/ADR-0008-d7-profile-first-memory-ownership.md`](../../../04_Architecture/decisions/ADR-0008-d7-profile-first-memory-ownership.md)
- [`docs/04_Architecture/decisions/ADR-0010-d9-typed-tool-security-policy.md`](../../../04_Architecture/decisions/ADR-0010-d9-typed-tool-security-policy.md)
- [`docs/04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md`](../../../04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md)
- [`docs/04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md`](../../../04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md)
- [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../../../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- [`docs/04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md`](../../../04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md)

### 4. Master Planning Spine
- [`docs/02_Planning/00_Master/MOBILE_WBS.md`](../../../02_Planning/00_Master/MOBILE_WBS.md)
- [`docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`](../../../02_Planning/00_Master/MOBILE_CHECKLIST.md)
- [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../../02_Planning/00_Master/DECISION_REGISTER.md)
- [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../../../02_Planning/00_Master/SPRINT_ROADMAP.md)
- [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](../../../02_Planning/00_Master/DELIVERY_INDEX.md)
- [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../../02_Planning/00_Master/DECISION_DEBT.md)

### 5. Input Working Decision Source
- [`docs/00_Drafts/research/mobile/MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md`](MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md)

---

## C. Decision-by-Decision Reconciliation Matrix

Every approved decision, direction, and boundary in `MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md` is evaluated below without sampling.

Allowed Dispositions: `PRESERVE`, `REFINE`, `SUPERSEDE`, `PROMOTE`, `KEEP OPEN`, `DEFER`, `WITHDRAWN`.

| Decision ID | Decision Title | Ledger Status | Existing Canonical Owner | Current Repository Wording / State | Contradiction? | Disposition | Target Canonical Destination | Planning / WBS Impact | Golden Impact | Implementation-Open Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **D-PHONE-01** | Production-capable local LLM path | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Stated as "optional-auxiliary capability in V1" and "NOT mandatory to run or use the Mobile Companion." | **YES** (tone & capability framing: ledger mandates a real production-capable execution path for qualified devices; current docs understate it as mere optional auxiliary) | **SUPERSEDE** | `mobile-capabilities-and-runtime.md` §2, `MOBILE_SYSTEM_BASELINE.md` §5, §7 | Revise `MOB-INFER-001`, `MOB-INFER-002`; clarify production status | MG14, MG4 | Exact model family, runtime, backend, quantization, minimum hardware remain open |
| **D-PHONE-01A** | Orthogonal availability dimensions | LOCKED V1 | `MOBILE_SYSTEM_BASELINE.md` §5, `mobile-offline-and-sync.md` §3.2.6 | Table groups capabilities under coupled modes: `CONNECTED_TO_PC`, `OFFLINE_LOCAL`, `OPTIONAL_CLOUD`. | **YES** (implies host connectivity and internet are bound) | **REFINE** | `MOBILE_SYSTEM_BASELINE.md` §5, `mobile-offline-and-sync.md` §3.2.6 | Add clear orthogonal state matrix to `MOB-FOUNDATION-005` | MG4, MG6 | UI display indicators and state machine mechanics remain open |
| **D-PHONE-01B** | Enrollment before normal Companion use | LOCKED V1 | `MOBILE_SYSTEM_BASELINE.md` §4.1, §4.3, `profiles-and-devices.md` §3.2 | Agrees that Mobile satellite binds to 1 Profile and requires enrollment; lacks explicit lifecycle states (`UNENROLLED`, `ENROLLED_ACTIVE`, etc.). | **NO** (agrees, but underspecified) | **PROMOTE** | `MOBILE_SYSTEM_BASELINE.md` §4.1, `profiles-and-devices.md` §5 | Expand `MOB-IDENTITY-001`, `MOB-IDENTITY-002` with lifecycle states | MG1 | Pairing UX (QR vs PIN code) and crypto payload remain open |
| **D-PHONE-01C** | Replaceable local models | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.3 | Mentions single resident model cap and engine independence, but lacks user-facing model switching / qualification disabling semantics. | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §2.3, `runtime-and-models.md` §2.5 | Add model switcher and qualification gate to `MOB-INFER-003` | MG14 | UI controls, download manager, and storage paths remain open |
| **D-PHONE-02** | Core survives without generative AI | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.1.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Fully agrees: Tasks, Reminders, Alarms, cached history, settings function 100% offline without local LLM. | **NO** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §2.1.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Retain `MOB-DATA`, `MOB-SCHED` independence from `MOB-INFER` | MG4 | None |
| **D-PHONE-03** | Vendor-neutral Mobile execution | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.2, §2.3.5 | Agrees on engine independence (GGUF, ONNX, ExecuTorch); lacks explicit CPU fallback mandate and truthful backend reporting requirement. | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §2.2, §2.3 | Expand `MOB-INFER-001` with backend detection & CPU fallback | MG14 | Native JNI/C++ adapter bindings remain open |
| **D-PHONE-04** | Replaceable speech providers | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.2 | Agrees local TTS and STT are independent; lacks explicit Auto vs Advanced selection and Kokoro/Kitten trade-off notes. | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §3.2, `voice-and-audio.md` §2.8 | Update `MOB-VOICE-004` to reflect replaceable speech providers | MG13 | Exact local TTS/STT binaries and models remain open |
| **D-PHONE-05** | Mobile model lifecycle | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.3 | Distinguishes resident vs unloaded; lacks explicit 5-state lifecycle (`installed`, `loaded/resident`, `active`, `unloaded`, `removed`). | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §2.3 | Update `MOB-INFER-003` with formal 5-state lifecycle | MG14 | Cache eviction rules and storage layout remain open |
| **D-PHONE-05A** | Resource Governor + truthful UI | LOCKED V1 | `mobile-capabilities-and-runtime.md` §6.2, §6.3 | Monitors thermals/memory; lacks progressive user-actionable interventions (Continue, Reduce, Finish then cool, Stop & unload) and truthful status UI. | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §6.2, §6.3, `performance-and-capacity.md` §2.3 | Add Resource Governor stream or task (`MOB-INFER-005` revision) | MG10, MG14 | Exact thermal/battery numerical thresholds remain open |
| **D-SHARED-AI-01** | Context / generation / reasoning budget manager | LOCKED SHARED | `assistant-and-conversations.md` §3.3, `SYSTEM_BASELINE.md` §3 | Only specifies static `MEMORY_BUDGET_TOKENS = 256` and simple turn truncation; lacks dynamic budget manager and safe context reduction. | **NO** (partially agrees, PC baseline gap) | **PROMOTE** | `assistant-and-conversations.md` §2.2, `SYSTEM_BASELINE.md` §3 | Update `PC-AI` and add shared budget manager in `MOB-CONV` | MG6, MG7 | Token estimation ratios and buffer sizes remain open |
| **D-SHARED-AI-02** | Conversation compaction & historical recall | LOCKED SHARED | `assistant-and-conversations.md` §3.4 | Explicitly states: "Conversation Compaction / Summarization: NOT IMPLEMENTED. Rolling summaries are not yet generated." | **YES** (current doc says not approved/implemented; ledger locks it as shared architecture) | **SUPERSEDE** | `assistant-and-conversations.md` §2.2, §4, `mobile-offline-and-sync.md` §3.2.6 | Add Host summarization contract & Mobile provisional summary task | MG6, MG7 | Exact prompt template, summary schema, and trigger threshold remain open |
| **D-SHARED-AI-03** | Unified context retrieval | LOCKED SHARED | `memory-and-personalization.md` §2.4, `assistant-and-conversations.md` §3.3 | Memories retrieved via FTS5; conversation summaries and pending local context are not integrated into unified retrieval. | **NO** (partially agrees) | **REFINE** | `memory-and-personalization.md` §2.4, `assistant-and-conversations.md` §2.2 | Add unified context assembler task to shared planning | MG7 | Ranking algorithm (lexical vs embedding vs hybrid) remains open |
| **D-PHONE-09** | Selective offline Memory replica | LOCKED V1 | `mobile-offline-and-sync.md` §2.1, §3.1, `MOBILE_SYSTEM_BASELINE.md` §5 | States Memory is "UNAVAILABLE / Cached view only" offline; no pinning or selective continuity replica defined. | **YES** (contradicts read-only cache-only boundary) | **SUPERSEDE** | `mobile-offline-and-sync.md` §2.1, §3.1, `memory-and-personalization.md` §2.1 | Add Memory replica and pinning task to `MOB-DATA` | MG7 | Exact replica selection algorithm and cache eviction limits remain open |
| **D-SHARED-CONV-01** | Causal conversation identity & branching | LOCKED SHARED | `mobile-offline-and-sync.md` §3.2.6, `assistant-and-conversations.md` §2.2 | Acknowledges non-destructive branch import on concurrent edit; lacks causal parentage IDs (`parent_turn_id`, `branch_id`), Compare UX, and single-phone boundary lock. | **NO** (partially agrees) | **REFINE** | `assistant-and-conversations.md` §2.2, `mobile-offline-and-sync.md` §3.2.6 | Update `MOB-CONTRACT-007` and `MOB-CONV-003` for branching | MG6 | Exact DB representation and multi-phone-per-profile resolution remain open |
| **D-SHARED-CONV-02** | Host-mediated live turn streaming | LOCKED SHARED | `assistant-and-conversations.md` §2.2, `mobile-capabilities-and-runtime.md` §8 (MG3) | Fully agrees: REST submission + SSE token streaming; active turn continues across disconnect; GET history catch-up. | **NO** (fully agrees) | **PRESERVE** | `assistant-and-conversations.md` §2.2, `mobile-offline-and-sync.md` §3.2.6 | Retain `MOB-CONV-001` | MG3, MG6 | None |
| **D-SHARED-CONV-03** | Active turn control (Queue, Interrupt, Fork) | LOCKED SHARED | `assistant-and-conversations.md` §2.2 | Mentions FIFO queue and cancellation; lacks explicit 3-way turn control primitives (`QUEUE`, `INTERRUPT_AND_SEND`, `FORK_FROM_HERE`). | **NO** (partially agrees) | **PROMOTE** | `assistant-and-conversations.md` §2.2, `mobile-offline-and-sync.md` §3.2.6 | Add turn control protocol to `MOB-CONTRACT` and `MOB-CONV` | MG6 | UI gesture/button mapping and payload schemas remain open |
| **D-SHARED-CONV-03A** | Safe regeneration | LOCKED SHARED | `assistant-and-conversations.md` §2.2 | Does not specify regeneration semantics or side-effect re-execution guardrails. | **NO** (unspecified) | **PROMOTE** | `assistant-and-conversations.md` §2.2, `tool-permissions-and-actions.md` §2.1 | Add safe regenerate contract to `MOB-CONTRACT` | MG6 | DB storage of alternative responses remains open |
| **D-PHONE-06** | Character selection inherits D11 | LOCKED V1 | `characters-personality-and-emotion.md` §2.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Agrees: Character switching never alters Profile data, security policy, or Tasks. Mobile selects cached Character. | **NO** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §5, `characters-personality-and-emotion.md` §2.1 | Retain `MOB-FOUNDATION` Character binding | MG8 | None |
| **Char Authority** | Connected edit ok; no offline canonical create | LOCKED V1 dir | `characters-personality-and-emotion.md` §2.1, `mobile-offline-and-sync.md` §3.1 | Agrees: Character templates/instances are PC-managed; cached view offline. Connected Mobile editing not explicitly documented. | **NO** (partially agrees) | **REFINE** | `characters-personality-and-emotion.md` §2.1, `mobile-offline-and-sync.md` §3.1 | Add connected Character Studio client note to WBS | MG8 | Exact Character Studio mobile UI layout remains open |
| **D-PHONE-EMO-01** | Offline Emotion Event Synchronization | LOCKED V1 dir | `characters-personality-and-emotion.md` §2.1.5, `mobile-offline-and-sync.md` §3.1 | States Character/Persona is read-only cached view offline; zero event-sync mechanism defined. | **YES** (contradicts read-only cache-only boundary) | **SUPERSEDE** | `mobile-offline-and-sync.md` §3.1, `characters-personality-and-emotion.md` §2.1 | Add Emotion Event outbox and sync to `MOB-DATA` / `MOB-SYNC` | MG8 | Exact emotion taxonomy, decay curves, and confidence remain open |
| **D-PHONE-08** | Offline explicit Memory intent | LOCKED V1 | `mobile-offline-and-sync.md` §3.2.6 (item 8) | Explicitly states: "No Autonomous Local Memory Extraction... memory database writes are DISABLED on Mobile in V1." | **YES** (does not distinguish explicit user intent from autonomous extraction) | **SUPERSEDE** | `mobile-offline-and-sync.md` §3.2.6, `memory-and-personalization.md` §2.3 | Add `PENDING_SYNC` Memory Intent outbox to `MOB-DATA` / `MOB-SYNC` | MG7 | Exact schema and conflict payload format remain open |
| **D-PHONE-08A** | Pending Memory overlay | LOCKED V1 | `memory-and-personalization.md` §3.3, `mobile-offline-and-sync.md` §3.2.6 | No local memory overlay mechanism exists or is documented. | **YES** (unsupported in canonical docs) | **PROMOTE** | `mobile-offline-and-sync.md` §3.2.6, `memory-and-personalization.md` §2.3 | Add pending memory context injector to `MOB-CONV` | MG7 | Provenance tagging and UI distinction styling remain open |
| **D-SHARED-SCHED-01** | Stable scheduling identity | LOCKED SHARED | `mobile-offline-and-sync.md` §3.2.1, `tasks-reminders-alarms-and-routines.md` §3.1 | Agrees on client UUIDv4 for offline entities; specifies Tasks; needs explicit coverage for Reminders, Alarms, Routines, and mutations. | **NO** (partially agrees) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.1, `mobile-offline-and-sync.md` §3.2.1 | Expand `MOB-CONTRACT-001` across all scheduling primitives | MG9 | None |
| **D-PHONE-10** | Offline Reminder authoring | LOCKED V1 | `mobile-offline-and-sync.md` §3.1 (table row 2) | Explicitly states: Reminders offline writable: "LIMITED (Ack / Dismiss / Snooze only; no canonical entity creation)." | **YES** (direct canonical conflict: ledger approves full offline CRUD for Mobile-created Reminders) | **SUPERSEDE** | `mobile-offline-and-sync.md` §3.1, §5, `MOBILE_SYSTEM_BASELINE.md` §5 | Update `MOB-SCHED-001` and `MOB-DATA-002` for full Reminder CRUD | MG9 | UI presentation and duplicate prevention heuristics remain open |
| **D-PHONE-11** | Offline Alarm authoring | LOCKED V1 | `mobile-offline-and-sync.md` §3.1 (table row 3) | Explicitly states: Alarms offline writable: "LIMITED (Dismiss / Snooze only; canonical recurring alarm config is PC-owned)." | **YES** (direct canonical conflict: ledger approves full offline CRUD for Mobile-created Alarms) | **SUPERSEDE** | `mobile-offline-and-sync.md` §3.1, §6, `MOBILE_SYSTEM_BASELINE.md` §5 | Update `MOB-SCHED-002` and `MOB-DATA-003` for full Alarm CRUD | MG9 | Alarm sound assets, snooze limits, and ring screen remain open |
| **D-SHARED-SCHED-02** | Cross-device presentation arbitration | LOCKED SHARED | `mobile-capabilities-and-runtime.md` §8 (MG12), `mobile-offline-and-sync.md` §6 | Mentions independent ringing and dismissal sync; lacks primary/standby escalation, preference options, and passive-display rule. | **NO** (partially agrees) | **PROMOTE** | `tasks-reminders-alarms-and-routines.md` §2.4, `mobile-offline-and-sync.md` §6 | Add arbitration protocol to `MOB-SCHED-004` | MG10 | Exact escalation grace period and reachability ping remain open |
| **D-SHARED-SCHED-03** | Companion alert enrichment | LOCKED SHARED | `tasks-reminders-alarms-and-routines.md` §2.7 | Agrees: LLM provides enrichment/presentation, not schedule authority. Needs explicit Mobile/TTS alert enrichment semantics. | **NO** (partially agrees) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.7, `mobile-capabilities-and-runtime.md` §3.2 | Add companion spoken alert task to `MOB-SCHED` | MG9, MG13 | Exact phrase templates and character prompt injections remain open |
| **D-SHARED-SCHED-04** | Temporal Intent Resolution | LOCKED SHARED | `tasks-reminders-alarms-and-routines.md` §2.5 | Mentions natural-language schedule input; lacks formal typed intent taxonomy and deterministic resolution pipeline. | **NO** (partially agrees) | **PROMOTE** | `tasks-reminders-alarms-and-routines.md` §2.5 | Add temporal intent resolver task to shared scheduling | MG9 | Exact parsing library and regex/grammar rules remain open |
| **D-SHARED-SCHED-04A** | Field-level ambiguity & clarification | LOCKED SHARED | `tool-permissions-and-actions.md` §2.7, `tasks-reminders-alarms-and-routines.md` §2.5 | Notes low-confidence action fields require clarification; lacks specific scheduling field-level ambiguity rules. | **NO** (partially agrees) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.5, `tool-permissions-and-actions.md` §2.7 | Add clarification dialogue test vectors to `MOB-SCHED` | MG9 | Clarification prompt templates remain open |
| **D-SHARED-SCHED-04B** | Timezone & recurrence semantics | LOCKED SHARED | `tasks-reminders-alarms-and-routines.md` §2.5 | Fully agrees: floating local vs fixed-timezone recurrence are distinct concepts; clock/timezone changes reconcile deterministically. | **NO** (fully agrees) | **PRESERVE** | `tasks-reminders-alarms-and-routines.md` §2.5, `mobile-offline-and-sync.md` §6.2 | Retain `MOB-SCHED-003` timezone reconciliation | MG9 | Specific Olson timezone mapping libraries remain open |
| **D-SHARED-SCHED-04C** | Alarm strictness | LOCKED SHARED | `tasks-reminders-alarms-and-routines.md` §2.1.3 | Agrees Alarms have stronger delivery semantics; lacks explicit requirement that AM/PM/date ambiguity MUST be resolved prior to arming. | **NO** (partially agrees) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.1.3 | Add strict validation gate to `MOB-SCHED-002` | MG9 | Exact prompt dialogue for AM/PM check remains open |
| **D-SHARED-SCHED-04D** | Cross-platform temporal parity | LOCKED SHARED | `MOBILE_WBS.md` Stream `MOB-VERIFY` | Parity is an overall objective; lacks explicit shared machine-readable Golden temporal test vectors. | **NO** (partially agrees) | **PROMOTE** | `tasks-reminders-alarms-and-routines.md` §2.5, `mobile-capabilities-and-runtime.md` §7 | Add temporal Golden vector suite to `MOB-VERIFY-001` | MG9 | Golden phrase dataset composition remains open |
| **D-SHARED-SCHED-04E** | Preference/history-informed temporal clarification | LOCKED SHARED | `memory-and-personalization.md` §2.1, `tasks-reminders-alarms-and-routines.md` §2.5 | Not currently articulated as an explicit context priority waterfall (instruction > conv > prefs > Memory > patterns > summaries > clarify). | **NO** (unspecified) | **PROMOTE** | `tasks-reminders-alarms-and-routines.md` §2.5, `memory-and-personalization.md` §2.3 | Add priority resolution logic to scheduler integration | MG9 | Historical pattern detection algorithm remains open |
| **P-PHONE-LOC-01** | Opt-in Location Context | MOBILE LATER | None | Not documented in current canonical Mobile architecture. | **NO** (future capability) | **DEFER** | `mobile-capabilities-and-runtime.md` §4, `MOBILE_SYSTEM_BASELINE.md` §5 | Document as approved future boundary in `MOBILE_WBS` | Deferred | Sensor APIs, geofence radius, and battery budgets remain open |
| **D-PHONE-12** | Replicated Routine occurrences | LOCKED V1 | `mobile-offline-and-sync.md` §3.1 (table row 4), `MOBILE_SYSTEM_BASELINE.md` §5 | States Routines are "cached view only offline; autonomous execution deferred post-V1." | **YES** (conflates autonomous recurrence extension with presenting precomputed occurrences) | **SUPERSEDE** | `mobile-offline-and-sync.md` §3.1, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add Routine occurrence replication task to `MOB-SCHED` | MG11 | Max cached occurrences count remains open |
| **D-PHONE-12A** | Routine presentation enrichment | LOCKED V1 | `tasks-reminders-alarms-and-routines.md` §2.7 | Notes LLM enrichment on PC; lacks Mobile local AI / TTS personalization and mandatory deterministic fallback. | **NO** (partially agrees) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §3.2, `tasks-reminders-alarms-and-routines.md` §2.7 | Add Routine enrichment adapter to `MOB-SCHED` | MG11 | Template strings and fallback phrases remain open |
| **D-PHONE-12B** | Routine authoring authority | LOCKED V1 | `tasks-reminders-alarms-and-routines.md` §2.7, `mobile-offline-and-sync.md` §3.1 | Agrees Routine authoring is Risk 2 and PC-managed; connected Mobile management via Host APIs not explicitly specified. | **NO** (partially agrees) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.7, `MOBILE_SYSTEM_BASELINE.md` §5 | Add connected Routine management note to `MOB-SCHED` | MG11 | Mobile Routine configuration UI remains open |
| **D-PHONE-12C** | Local Routine suppression | LOCKED V1 | None | Not documented in current Mobile architecture. | **NO** (new feature) | **PROMOTE** | `mobile-offline-and-sync.md` §3.1, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add local suppression toggle to `MOB-SCHED` | MG11 | Storage format of suppression state remains open |
| **D-PHONE-12D** | Companion check-in surfaces | LOCKED V1 | None (only prototype `HealthScreen`/`Dashboard` exists) | No canonical check-in surfaces, widget priority waterfall, or Android home-screen widget architecture documented. | **NO** (new capability) | **PROMOTE** | `MOBILE_SYSTEM_BASELINE.md` §5, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add check-in cards and widget stream to `MOB-FOUNDATION` | MG11 | Android Glance / AppWidget implementation details remain open |
| **D-PHONE-12E** | Character-aware check-in tone | LOCKED V1 | `characters-personality-and-emotion.md` §2.1.4, §2.1.5 | Presets defined (Tsundere, Yandere, etc.); lacks explicit rule that strong presets like Yandere remain socially expressive without altering facts or truth. | **NO** (partially agrees) | **REFINE** | `characters-personality-and-emotion.md` §2.1.4, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add persona safety guardrails to check-in prompts | MG8, MG11 | Specific check-in dialogue templates remain open |
| **D-PHONE-13** | Standalone Mobile Tool Gateway | LOCKED V1 | `tool-permissions-and-actions.md` §2.1, `MOBILE_SYSTEM_BASELINE.md` §2 | PC has D9 tool pipeline; Mobile has no standalone Tool Gateway documented for offline/local model execution. | **YES** (omitted in current mobile architecture) | **SUPERSEDE** | `mobile-capabilities-and-runtime.md` §2, `tool-permissions-and-actions.md` §2.1 | Add Mobile Tool Gateway stream or work items to `MOB-INFER` | MG12 | Tool dispatcher plumbing and JSON schema parsers remain open |
| **D-PHONE-13A** | Local productivity tools | LOCKED V1 | `tool-permissions-and-actions.md` §2.3 | PC defines Risk 1 productivity actions; Mobile lacks local typed tool adapters for local model invocation. | **NO** (new mobile adapter) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2, `tool-permissions-and-actions.md` §2.3 | Add local tool adapters (Tasks, Reminders, Alarms) | MG12 | Dart method channel signatures remain open |
| **D-PHONE-13B** | Read-only internet tools | LOCKED V1 | `web-current-information.md` §2.1, §2.2 | PC defines WebSearch, WebFetch, Weather; Mobile offline/sync specs do not grant standalone Mobile access to these adapters. | **NO** (partially agrees) | **PROMOTE** | `web-current-information.md` §2.1, `mobile-capabilities-and-runtime.md` §2 | Add mobile read-only web adapters to `MOB-INFER` / `MOB-DATA` | MG12 | Mobile HTTP client and SSRF guardrails on device remain open |
| **D-PHONE-13C** | Internet is not Cloud AI | LOCKED V1 | `MOBILE_SYSTEM_BASELINE.md` §5.1, `mobile-capabilities-and-runtime.md` §2.1 | Partially noted, but internet presence is frequently conflated with cloud mode. | **NO** (partially agrees) | **REFINE** | `MOBILE_SYSTEM_BASELINE.md` §5.1, `mobile-capabilities-and-runtime.md` §2.1 | Clarify in network state machine | MG4, MG12 | None |
| **D-PHONE-13D** | Local Companion read tools | LOCKED V1 | `tool-permissions-and-actions.md` §2.3 | PC defines Risk 0 reads; Mobile lacks local adapters for cached Memory, history, Character, device status. | **NO** (new mobile adapter) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2, `tool-permissions-and-actions.md` §2.3 | Add local read tool adapters to `MOB-INFER` | MG12 | Local read API schemas remain open |
| **D-PHONE-13E** | Explicitly excluded authority | LOCKED V1 / REJ | `tool-permissions-and-actions.md` §2.4, `MOBILE_SYSTEM_BASELINE.md` §2 | Fully agrees: arbitrary shell, raw filesystem, credential access, PC admin, network reconfiguration are strictly REJECTED. | **NO** (fully agrees) | **PRESERVE** | `tool-permissions-and-actions.md` §2.4, `MOBILE_SYSTEM_BASELINE.md` §2 | Retain non-goal in `MOB-SECURITY` | MG2, MG12 | None |
| **D-PHONE-13F** | Tool capability qualification | LOCKED V1 | `tool-permissions-and-actions.md` §2.7 | Agrees: success is claimed only after confirmed execution. Needs explicit qualification for mobile models attempting tool calls. | **NO** (partially agrees) | **REFINE** | `tool-permissions-and-actions.md` §2.7, `mobile-capabilities-and-runtime.md` §2.2 | Add tool qualification criteria to model evaluation | MG12, MG14 | Benchmark test suite for tool JSON syntax remains open |
| **D-PHONE-14** | Composable Mobile Voice | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.2 | Agrees: STT, LLM, TTS are 3 independent routes (Local, Host, Cloud). | **NO** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §3.2, `voice-and-audio.md` §2.1 | Retain decoupled voice stream `MOB-VOICE` | MG13 | Audio routing state machine remains open |
| **D-PHONE-14A** | Connected Mobile Voice | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.1, §3.2.2 | Fully agrees: Phone owns mic, playback, audio focus; PC owns STT/LLM/TTS/VAD over WebSocket; barge-in mandatory. | **NO** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §3.1, §3.2.2 | Retain `MOB-VOICE-001`, `MOB-VOICE-002`, `MOB-VOICE-003` | MG8 (MG13) | WebSocket binary frame format remains open |
| **D-PHONE-14B** | Local TTS | CONDITIONAL V1 | `mobile-capabilities-and-runtime.md` §3.2.3 | Fully agrees: device-local TTS operates independently of STT/LLM; vocalizes alerts/check-ins; engine-independent. | **NO** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §3.2.3 | Retain `MOB-VOICE-004` | MG13 | Candidate selection (Kokoro vs Kitten vs native) remains open |
| **D-PHONE-14C** | Local STT | CONDITIONAL V1 | `mobile-capabilities-and-runtime.md` §3.2.3 | Current doc states: "continuous heavy local STT deferred in V1." Ledger clarifies: local STT is supported if qualification passes for PTT/tap-to-speak. | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §3.2.3, `voice-and-audio.md` §2.1 | Update `MOB-VOICE-004` to include conditional local STT | MG13 | Exact STT engine and vocabulary model remain open |
| **D-PHONE-14D** | Full offline Voice | CONDITIONAL V1 | `mobile-capabilities-and-runtime.md` §3.2.3 | Notes full offline conversational voice is independently gated; ledger explicitly defines conditional V1 status when all 3 qualify. | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §3.2.3 | Add full offline voice integration task to `MOB-VOICE` | MG13 | Thermal and battery limits for concurrent audio+LLM remain open |
| **D-PHONE-14E** | Voice route selection | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.2 | Agrees on routes; lacks explicit `Auto` route selection logic and visible route indicator. | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §3.2 | Add route selection logic to `MOB-VOICE` | MG13 | Route switching hysteresis remains open |
| **D-PHONE-14F** | Explicit Voice session lifecycle | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.4 | Fully agrees: no background eavesdropping; starts via visible UI; active session may continue under FGS across screen-lock with notification. | **NO** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §3.4 | Retain `MOB-VOICE-005` | MG13 | Notification channel and action layout remain open |
| **D-PHONE-14G** | Shared STT candidate qualification (Whisper.cpp) | RESEARCH / DIR | `voice-and-audio.md` §2.1, `mobile-capabilities-and-runtime.md` §3.2 | `whisper.cpp` is PC candidate; not previously mandated as first Mobile STT research candidate. | **NO** (research addition) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §3.2, `voice-and-audio.md` §2.8 | Add Whisper.cpp mobile benchmark task | MG13 | Exact quantization and multilingual models remain open |
| **Voice Invariants** | Barge-in, D9 parity, ephemeral audio | LOCKED SHARED | `voice-and-audio.md` §2.3, §2.5, §2.7, `mobile-capabilities-and-runtime.md` §3.3, §3.5 | Fully agrees: mandatory barge-in, D9 parity, transient raw audio, voice != authentication, separate cloud permissions, no wake word in V1. | **NO** (fully agrees) | **PRESERVE** | `voice-and-audio.md` §2, `mobile-capabilities-and-runtime.md` §3 | Retain throughout `MOB-VOICE` | MG13 | None |
| **D-PHONE-15** | Health Connect conditional Mobile V1 | CONDITIONAL V1 | `health-and-wearables.md` §2.1, `mobile-capabilities-and-runtime.md` §4.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Explicitly states: "Health & Wearables: [MOBILE LATER] (Deferred Post-V1); Real Health Connect excluded from Mobile V1." | **YES** (direct canonical conflict: ledger restores Health Connect to conditional read-only Mobile V1) | **SUPERSEDE** | `health-and-wearables.md` §2, `mobile-capabilities-and-runtime.md` §4, `MOBILE_SYSTEM_BASELINE.md` §5 | Add dedicated `MOB-HEALTH` stream to `MOBILE_WBS` (was excluded) | MG15 (new) | Ingestion frequency, retention period, baseline algorithm remain open |
| **D-PHONE-15A** | Granular metric authorization | LOCKED V1 | `health-and-wearables.md` §2.2 | Mentions candidate granular consent; now promoted to locked V1 requirement with candidate metric categories. | **NO** (promoted from future) | **PROMOTE** | `health-and-wearables.md` §2.2 | Add granular health permission UI to `MOB-HEALTH` | MG15 | Exact Android Health Connect permission strings remain open |
| **D-PHONE-15B** | Read-only Health ingestion | LOCKED V1 | `health-and-wearables.md` §3.2 | Current doc notes zero real code; ledger locks V1 scope as strictly read-only ingestion (no write-back). | **NO** (scope clarification) | **PROMOTE** | `health-and-wearables.md` §2.1 | Add read-only ingestion adapter to `MOB-HEALTH` | MG15 | Health record reading queries remain open |
| **D-PHONE-15C** | Health is separate from Memory | LOCKED SHARED | None (conceptually new boundary) | Current docs do not explicitly state that Health context is distinct from D7 Memory. | **NO** (new architectural rule) | **PROMOTE** | `health-and-wearables.md` §2.2, `memory-and-personalization.md` §2.3 | Add health context boundary check to memory extractor | MG15, MG7 | None |
| **D-PHONE-15D** | Shared PC/Mobile Health context | LOCKED V1 dir | `health-and-wearables.md` §6 | Mentioned as candidate; ledger locks shared normalized contract between PC and Mobile. | **NO** (promoted from candidate) | **PROMOTE** | `health-and-wearables.md` §2, `MOBILE_SYSTEM_BASELINE.md` §3 | Add shared Health DTOs to shared Flutter contracts | MG15 | Exact JSON schema and protobuf/drift types remain open |
| **D-PHONE-15E** | Health Connect aggregation boundary | LOCKED V1 | None | Does not address Health Connect vs direct vendor wearable adapters. Ledger establishes Health Connect as preferred boundary. | **NO** (new architectural policy) | **PROMOTE** | `health-and-wearables.md` §2 | Set vendor SDKs as non-goals in `MOB-HEALTH` | MG15 | None |
| **D-SHARED-HEALTH-01** | Unified Health Context | LOCKED SHARED | `health-and-wearables.md` §5 | Previously OPEN DESIGN; now locked: preserves source, measurement time, freshness, provenance; sync bounded useful data. | **NO** (promoted from open) | **PROMOTE** | `health-and-wearables.md` §2 | Add Health sync protocol to `MOB-SYNC` | MG15 | Sync cadence and maximum historical window remain open |
| **D-SHARED-HEALTH-02** | Non-clinical wellness awareness | LOCKED SHARED | `health-and-wearables.md` §2.2, `mobile-capabilities-and-runtime.md` §4.1.2 | Fully agrees: absolute non-clinical boundary; no diagnosis, prescription, medical certainty, or emergency detection. | **NO** (fully agrees) | **PRESERVE** | `health-and-wearables.md` §2.2, `mobile-capabilities-and-runtime.md` §4.1.2 | Retain non-clinical guardrails across prompts | MG15 | Conversational wellness prompts remain open |
| **D-SHARED-HEALTH-03** | Health-aware check-ins | LOCKED SHARED | None | Check-ins currently do not reference health context. | **NO** (new capability) | **PROMOTE** | `health-and-wearables.md` §2, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add health context injection to Routine check-ins | MG11, MG15 | Prompt injection format remains open |
| **D-SHARED-HEALTH-04** | Health egress isolation | LOCKED SHARED | `health-and-wearables.md` §6 | Fully agrees: Cloud LLM permission does NOT authorize Health egress; separate explicit authorization required. | **NO** (fully agrees) | **PRESERVE** | `health-and-wearables.md` §6 | Add health redaction filter to cloud LLM client | MG15 | Redaction policy and warning modal remain open |
| **D-PHONE-16** | Conditional local Vision in Mobile V1 | CONDITIONAL V1 | `mobile-offline-and-sync.md` §3.1 (row 10), `mobile-capabilities-and-runtime.md` §9, `MOBILE_SYSTEM_BASELINE.md` §7 | Explicitly states: "Local VLM inference excluded from Mobile V1... future local vision inference remains unscheduled post-V1 candidate." | **YES** (direct canonical conflict: ledger promotes local still-image VLM to conditional Mobile V1) | **SUPERSEDE** | `mobile-capabilities-and-runtime.md` §2, `multimodal-and-media.md` §2.2, `MOBILE_SYSTEM_BASELINE.md` §5 | Add dedicated `MOB-VISION` stream or expand `MOB-INFER` in WBS | MG16 (new) | Minimum VLM RAM headroom and quantization format remain open |
| **D-PHONE-16A** | Camera-to-attachment | LOCKED V1 | `multimodal-and-media.md` §2.3, §3.1 | PC has attachment pipeline; Mobile camera capture is an input adapter feeding that exact shared attachment contract. | **NO** (partially agrees) | **PROMOTE** | `multimodal-and-media.md` §2.3, `mobile-capabilities-and-runtime.md` §2 | Add camera/gallery capture adapter to `MOB-CONV` | MG16 | Native camera plugin (image_picker / camera) remains open |
| **D-PHONE-16B** | Multimodal route selection | LOCKED V1 | `multimodal-and-media.md` §3.3 | Describes PC local vs cloud; ledger establishes Mobile routing: Host local, Mobile local VLM, authorized Cloud, or unavailable. | **NO** (partially agrees) | **PROMOTE** | `multimodal-and-media.md` §2.3, `mobile-capabilities-and-runtime.md` §2 | Add vision routing logic to `MOB-CONV` / `MOB-INFER` | MG16 | Route selection fallback delays remain open |
| **D-PHONE-16C** | Vision qualification | LOCKED V1 | `runtime-and-models.md` §2.5 | General capability checks mentioned; ledger mandates evidence qualification for vision, noting hallucination risks from 0.8B tests. | **NO** (refinement) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2.2, `multimodal-and-media.md` §2.2 | Add vision qualification test suite to `MOB-VERIFY` | MG16 | Benchmark vision dataset remains open |
| **D-PHONE-16D** | Offline multimodal persistence | LOCKED V1 | `mobile-offline-and-sync.md` §2.1, §3.2.6 | Mentions media upload on turn; ledger mandates offline image turns, attachments, and local responses persist durably and sync without Host LLM regeneration. | **NO** (partially agrees) | **REFINE** | `mobile-offline-and-sync.md` §2.1, §3.2.6 | Ensure image attachments in local outbox sync cleanly | MG16 | Attachment binary cache pruning limits remain open |
| **D-PHONE-16E** | Explicit-capture V1 boundary | LOCKED V1 | `multimodal-and-media.md` §2.2 | Fully agrees: V1 is bounded user-initiated still capture. Continuous background camera, ambient sensing, surveillance, live AR camera excluded. | **NO** (fully agrees) | **PRESERVE** | `multimodal-and-media.md` §2.2, `mobile-capabilities-and-runtime.md` §5 | Retain explicit camera non-goals in WBS | MG16 | None |
| **D-SHARED-VISION-01** | Vision does not automatically create Memory | LOCKED SHARED | None (conceptually new boundary) | Not explicitly stated in current vision or memory specs. | **NO** (new architectural rule) | **PROMOTE** | `multimodal-and-media.md` §2.3, `memory-and-personalization.md` §2.3 | Add rule to vision and memory orchestrators | MG16, MG7 | None |
| **P-SHARED-PRESENCE-01** | Embodied Companion Presence | FUTURE / DIR | `characters-personality-and-emotion.md` §2.1.8 | Agrees: Advanced Presence (Live2D, VRM, 3D, sensors) is PC Later / Future. | **NO** (fully agrees) | **PRESERVE** | `characters-personality-and-emotion.md` §2.1.8 | Retain as future non-goal in `MOBILE_WBS` | Deferred | Render engine and asset formats remain open |
| **P-PHONE-AR-01** | Mobile AR Companion Presence | FUTURE / DIR | None | AR presence not mentioned in current canonical mobile docs. | **NO** (future capability) | **DEFER** | `mobile-capabilities-and-runtime.md` §4, `MOBILE_SYSTEM_BASELINE.md` §5 | Document as approved future boundary in `MOBILE_WBS` | Deferred | ARCore SDK evaluation remains open |
| **P-PHONE-AR-02** | Bounded scene awareness | FUTURE / DIR | None | AR scene understanding not mentioned in current docs. | **NO** (future capability) | **DEFER** | `mobile-capabilities-and-runtime.md` §4 | Document as approved future boundary in `MOBILE_WBS` | Deferred | Scene understanding pipeline remains open |
| **P-PRESENCE-02** | Remote expression asset discovery | EXPERIMENTAL LATER | None | Not mentioned in current docs. Guaranteed V1 fallback is emoji. | **NO** (experimental later) | **DEFER** | `characters-personality-and-emotion.md` §2.1.8 | Retain emoji fallback in V1 | Deferred | Search API and media sanitizer remain open |
| **D-PHONE-UX-01** | Companion-centered Mobile shell | LOCKED V1 | `android-companion.md` §1.1 | Prototype currently uses `Home / Tasks / Assistant / Health / More`. Ledger locks: `Home / Schedule / COMPANION / Activity / More`. | **YES** (prototype navigation differs; canonical specs lacked explicit mobile nav shell) | **SUPERSEDE** | `MOBILE_SYSTEM_BASELINE.md` §3, `05_Design/` (new mobile spec) | Update `MOB-FOUNDATION-005` with locked 5-tab structure | MG17 (new) | Exact tab bar styling and animation remain open |
| **D-PHONE-UX-01A** | Icon-first navigation | LOCKED V1 | None | Not documented in canonical specs. Requires accessibility semantics. | **NO** (new design spec) | **PROMOTE** | `05_Design/` (new mobile spec) | Add icon-first nav with a11y labels to `MOB-FOUNDATION-005` | MG17 | Icon SVG assets remain open |
| **D-PHONE-UX-02** | Contextual Companion Home | LOCKED V1 | None | Home dashboard is currently an enterprise/prototype list. Ledger defines contextual prioritized companion surface. | **NO** (new design spec) | **PROMOTE** | `05_Design/` (new mobile spec) | Add contextual Home screen to `MOB-FOUNDATION-005` | MG17 | Home card layout and prioritization logic remain open |
| **D-PHONE-UX-03** | Unified Companion interaction surface | LOCKED V1 | None | Text, voice, and media currently exist across separate screens in prototype. Ledger unifies them into single surface. | **NO** (new design spec) | **PROMOTE** | `05_Design/` (new mobile spec), `assistant-and-conversations.md` §2 | Add unified conversation view to `MOB-CONV` | MG6, MG17 | Unified composer layout remains open |
| **D-PHONE-UX-04** | Unified Schedule experience | LOCKED V1 | None | Tasks and Reminders/Alarms currently separate. Ledger unifies Tasks, Reminders, Alarms, Routines under Schedule. | **NO** (new design spec) | **PROMOTE** | `05_Design/` (new mobile spec), `tasks-reminders-alarms-and-routines.md` §2 | Add unified Schedule screen to `MOB-SCHED` | MG9, MG17 | Calendar vs list view switching remains open |
| **D-PHONE-UX-05** | Activity & reconciliation inbox | LOCKED V1 | None | No activity/reconciliation inbox exists in prototype or canonical specs. | **NO** (new design spec) | **PROMOTE** | `05_Design/` (new mobile spec), `mobile-offline-and-sync.md` §3 | Add Activity screen to `MOB-SYNC` / `MOB-FOUNDATION` | MG5, MG17 | Item retention and dismissal gestures remain open |
| **D-PHONE-UX-06** | Truthful capability status | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.1.1 (truthful degradation) | General principle stated; lacks compact normal-state indicator with drill-down sheet. | **NO** (partially agrees) | **PROMOTE** | `05_Design/` (new mobile spec), `mobile-capabilities-and-runtime.md` §2.1.1 | Add status indicator and drill-down sheet to UI shell | MG17 | Indicator iconography and badge layout remain open |
| **D-PHONE-UX-07** | Graceful standalone UX | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.1.1 | Agrees Host loss is a capability transition, not app failure; UI must reflect this gracefully. | **NO** (partially agrees) | **REFINE** | `mobile-capabilities-and-runtime.md` §2.1.1 | Ensure offline banner does not lock standalone UI | MG4, MG17 | Visual transition animations remain open |
| **D-PHONE-UX-08** | Hybrid Mobile visual language | LOCKED V1 | `MOBILE_WBS.md` `MOB-FOUNDATION-003` | WBS mentions "theme tokens (SoftGlass)". Ledger locks: Minimalist foundation + selective Neumorphism + Glass/Liquid Glass + OLED default. | **YES** (SoftGlass-only wording is too narrow) | **SUPERSEDE** | `05_Design/` (new mobile spec), `MOBILE_WBS.md` | Update design tokens in `MOB-FOUNDATION-003` | MG17 | Exact blur radiuses, shadow offsets, and palette remain open |
| **D-PHONE-UX-09** | Companion language vs UI language | LOCKED V1 | `assistant-and-conversations.md` §2.3 | Agrees: conversational language capability is separate from full app UI localization. | **NO** (fully agrees) | **PRESERVE** | `assistant-and-conversations.md` §2.3, `05_Design/` | Retain separation in settings UI | MG17 | Flutter `flutter_localizations` setup remains open |
| **D-PHONE-UX-10** | Lightweight Mood Presence | LOCKED V1 | `characters-personality-and-emotion.md` §2.1.8 | Notes presence is future; ledger establishes emoji as guaranteed lightweight V1 Mood/Presence fallback. | **NO** (promoted lightweight V1) | **PROMOTE** | `characters-personality-and-emotion.md` §2.1.5, `05_Design/` | Add emoji mood glyph renderer to `MOB-FOUNDATION` | MG8, MG17 | Emoji set mapping and animation curves remain open |
| **D-SHARED-LANG-01** | Extensible language registry | LOCKED SHARED | `assistant-and-conversations.md` §2.3 | Prototype used fixed enum (`Language.kt`); canonical text references English, Tagalog, Japanese. Ledger requires extensible registry. | **NO** (partially agrees) | **PROMOTE** | `assistant-and-conversations.md` §2.3, `SYSTEM_BASELINE.md` §3 | Add extensible language registry to shared packages | MG17 | ISO language/locale code structures remain open |
| **D-SHARED-LANG-02** | Qualified language capability | LOCKED SHARED | `assistant-and-conversations.md` §2.3 | Agrees: language support bounded by model capabilities; Auto supports natural code-switching where qualified. | **NO** (fully agrees) | **PRESERVE** | `assistant-and-conversations.md` §2.3 | Retain model qualification criteria for multilingual | MG17 | Code-switching detection benchmarks remain open |
| **D-SHARED-FLUTTER-01** | Shared workspace, separate apps | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0004` | Fully agrees: single shared Flutter monorepo with separate desktop and mobile app targets. | **NO** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0004` | Retain `MOB-FOUNDATION-001`, `MOB-FOUNDATION-002` | None | Exact folder names remain open |
| **D-SHARED-FLUTTER-02** | Share contracts, not every implementation | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Fully agrees: share stable domain models, DTOs, IDs, validation, interfaces; do not force identical implementations. | **NO** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3 | Retain `MOB-FOUNDATION-003` | None | Package boundary partitioning remains open |
| **D-SHARED-FLUTTER-03** | Shared typed Host client | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0019` | Implied by shared contracts; ledger locks a shared typed client layer implementing REST, SSE, WS contracts. | **NO** (promoted from general principle) | **PROMOTE** | `MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0019` | Add shared API client package to `MOB-FOUNDATION` | MG3 | HTTP package (dio vs http) remains open |
| **D-SHARED-FLUTTER-04** | Shared repository contracts | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Fully agrees: share abstract repository contracts; implementations remain platform-specific as needed. | **NO** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3 | Retain `MOB-FOUNDATION-004` | None | Interface signatures remain open |
| **D-SHARED-FLUTTER-05** | Platform adapter isolation | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Fully agrees: shared packages do not import Android/Windows native APIs; platform adapters isolated behind interfaces. | **NO** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3 | Retain `MOB-FOUNDATION-004` | None | Platform channel method names remain open |
| **D-SHARED-FLUTTER-06** | Shared design primitives, platform composition | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Agrees on shared design primitives; ledger revises WBS "SoftGlass-only" wording to shared primitives with platform composition. | **YES** (minor WBS wording refinement) | **REFINE** | `MOBILE_SYSTEM_BASELINE.md` §3, `MOBILE_WBS.md` | Revise `MOB-FOUNDATION-003` | MG17 | Design token constants remain open |
| **D-SHARED-FLUTTER-07** | Cross-language semantic parity | LOCKED SHARED | None (conceptually new engineering policy) | Shared tests implied; ledger explicitly mandates machine-readable Golden fixtures/test vectors for PC/Mobile parity. | **NO** (new verification standard) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §7, `tasks-reminders-alarms-and-routines.md` §2.5 | Add Golden fixture generator to `MOB-CONTRACT` / `MOB-VERIFY` | MG9, MG18 | JSON fixture directory structure remains open |
| **D-SHARED-FLUTTER-08** | Shared feature core, platform presentation | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Fully agrees: "One codebase" does NOT mean one giant responsive screen full of `if (isMobile)` branches. | **NO** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3 | Retain architectural guideline | None | View composition architecture remains open |
| **D-PHONE-FLUTTER-01** | Kotlin prototype as evidence only | LOCKED V1 | `android-companion.md` §1, `MOBILE_SYSTEM_BASELINE.md` §1 | Fully agrees: Kotlin/Compose `android/` is non-normative reference/migration evidence; production is Flutter. | **NO** (fully agrees) | **PRESERVE** | `android-companion.md` §1, `MOBILE_SYSTEM_BASELINE.md` §1 | Retain legacy boundary | None | None |
| **D-MOBILE-VERIFY-01** | Product-centered Golden Gate (MG1–MG18) | LOCKED V1 | `mobile-capabilities-and-runtime.md` §8, `MOBILE_CHECKLIST.md` | Currently specifies 12 groups (MG1–MG12). Ledger expands to 18 product-centered groups (MG1–MG18). | **YES** (direct conflict: MG1–MG12 vs MG1–MG18) | **SUPERSEDE** | `mobile-capabilities-and-runtime.md` §8, `MOBILE_CHECKLIST.md`, `MOBILE_WBS.md` | Expand `MOB-VERIFY-006` and add MG13–MG18 checklist rows | MG1–MG18 | Exact pass/fail assertion counts remain open |
| **D-MOBILE-VERIFY-02** | Required vs Conditional qualification | LOCKED V1 | `mobile-capabilities-and-runtime.md` §8 | Previous MG groups treated all items uniformly; ledger introduces REQUIRED, CONDITIONAL, OPTIONAL, DEFERRED classes. | **NO** (refinement) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §8 | Update checklist evaluation schema | MG1–MG18 | Exact qualification test harness remains open |
| **D-MOBILE-VERIFY-03** | Integrated Companion journey | LOCKED V1 | `mobile-capabilities-and-runtime.md` §8 | Release gates tested isolated subsystems; ledger mandates MG18 full end-to-end user companion journey. | **NO** (new release gate) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §8 | Add MG18 integration test to `MOB-VERIFY-006` | MG18 | Scripted journey test runner remains open |
| **D-CI-01** | Flutter path-scoped verification | LOCKED DIR | `mobile-capabilities-and-runtime.md` §7.2 | Current doc states "zero changes to PC CI". Ledger defines future path-scoped classifier lanes without modifying CI yet. | **NO** (future direction aligned) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §7.2 | Document future CI architecture | None | Path filter globs remain open |
| **D-CI-02** | Shared-package fan-out | LOCKED DIR | None | Not documented in current CI policy. | **NO** (future direction) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §7.2 | Document fan-out rules for shared Flutter packages | None | GitHub Actions matrix definitions remain open |
| **D-CI-03** | Tiered Mobile verification | LOCKED DIR | `mobile-capabilities-and-runtime.md` §7.1 | Fully agrees: L1 unit/domain, L2 storage/outbox, L3 emulator matrix, L4 hardware, L5 host integration. | **NO** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §7.1 | Retain `MOB-VERIFY-001` through `MOB-VERIFY-005` | L1–L5 | Runner hardware specifications remain open |
| **D-CI-04** | Do not implement Flutter CI before Flutter exists | LOCKED DIR | `mobile-capabilities-and-runtime.md` §7.2 | Fully agrees: Batch D documents future routing; zero changes to `.github/workflows/ci.yml` until M1 creates workspace. | **NO** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §7.2 | Zero edits to `.github/workflows/` enforced | None | None |
| **Gemma 3 1B** | Cross-device qualification requirement | RESEARCH | `mobile-capabilities-and-runtime.md` §2.2.2 | Mentioned as exploratory research on Infinix; ledger establishes formal qualification requirement across PC & Mobile. | **NO** (promoted research requirement) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2.2, `runtime-and-models.md` §2.5 | Add cross-platform qualification benchmark task | MG14 | Qualification record JSON schema remains open |
| **Sec 18 (1-12)** | Explicit future/deferred boundaries | DEFERRED | Various specs | Fully agrees: wake word, ambient mic, continuous camera, AR, Live2D/VRM, remote expression scraping, direct wearable SDKs, shell, etc. are deferred/rejected. | **NO** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md`, `MOBILE_WBS.md` | Maintain non-goal boundaries | All | None |
| **Sec 19 (1-26)** | Implementation-open items | KEEP OPEN | `DECISION_DEBT.md` | Fully agrees: exact libraries, thresholds, schemas, models, UI timings MUST remain open and not be invented prematurely. | **NO** (fully agrees) | **KEEP OPEN** | `DECISION_DEBT.md` | Index newly identified implementation debt items | None | None |

---

## D. Explicit Canonical Contradictions

The reconciliation audit confirms **10 major structural contradictions** where current canonical documentation directly conflicts with the approved Batch D direction:

1. **Local LLM Framing:**
   - *Current Canonical:* `MOBILE_SYSTEM_BASELINE.md` §5 & `mobile-capabilities-and-runtime.md` §2.1 classify local Mobile inference as an "optional-auxiliary capability in V1" and "NOT mandatory to run or use the Mobile Companion."
   - *Batch D Approved:* `D-PHONE-01` establishes that Mobile V1 product implementation **must include a real production-capable device-local LLM execution path for qualified devices**. Core survives without it, but local LLM is an approved V1 product capability.

2. **Coupled Operating Modes vs. Orthogonal Dimensions:**
   - *Current Canonical:* `MOBILE_SYSTEM_BASELINE.md` §5 and `mobile-offline-and-sync.md` present capability matrices structured around coupled monolithic modes (`CONNECTED_TO_PC`, `OFFLINE_LOCAL`, `OPTIONAL_CLOUD`).
   - *Batch D Approved:* `D-PHONE-01A` requires Host reachability, internet availability, and inference routing to be treated as **three strictly orthogonal state dimensions**. Internet availability does not imply Cloud LLM permission, and read-only internet tools can run alongside local inference.

3. **Offline Reminder Authoring:**
   - *Current Canonical:* `mobile-offline-and-sync.md` §3.1 (table row 2) strictly restricts offline Reminders to `"LIMITED (Ack / Dismiss / Snooze only; no canonical entity creation)"`.
   - *Batch D Approved:* `D-PHONE-10` authorizes **full offline CRUD for Mobile-created Reminders** (create, edit, cancel/delete, dismiss/snooze, local scheduling/delivery), while Host-created definitions remain read-only offline.

4. **Offline Alarm Authoring:**
   - *Current Canonical:* `mobile-offline-and-sync.md` §3.1 (table row 3) strictly restricts offline Alarms to `"LIMITED (Dismiss / Snooze only; canonical recurring alarm config is PC-owned)"`.
   - *Batch D Approved:* `D-PHONE-11` authorizes **full offline creation, editing, and arming of Mobile-created Alarms**, while Host-created definitions remain read-only offline.

5. **Routine Offline Behavior:**
   - *Current Canonical:* `mobile-offline-and-sync.md` §3.1 (table row 4) and `MOBILE_SYSTEM_BASELINE.md` §5 state that Routines are `"cached view only offline; autonomous execution deferred post-V1"`.
   - *Batch D Approved:* `D-PHONE-12` clarifies that Mobile **may cache and present bounded Host-authorized Routine occurrences while disconnected**, with optional local AI/TTS enrichment (`D-PHONE-12A`) and local suppression (`D-PHONE-12C`).

6. **Offline Memory Capabilities:**
   - *Current Canonical:* `mobile-offline-and-sync.md` §3.1 & §3.2.6 state Memory is `"UNAVAILABLE / Cached view only"` and local memory writes are disabled.
   - *Batch D Approved:* `D-PHONE-08` establishes **durable offline explicit Memory intent** (`PENDING_SYNC`), `D-PHONE-08A` establishes a **pending Memory overlay** for local conversational continuity, and `D-PHONE-09` establishes a **selective offline Memory replica** (including pinned memories).

7. **Health Connect Release Disposition:**
   - *Current Canonical:* `health-and-wearables.md` §2.1, `mobile-capabilities-and-runtime.md` §4.1, and `MOBILE_SYSTEM_BASELINE.md` §5 state Health Connect is `"Mobile Later (Deferred Post-V1)"` and completely excluded from Mobile V1.
   - *Batch D Approved:* `D-PHONE-15` **restores Health Connect to conditional, read-only, non-clinical Mobile V1**.

8. **Local Vision / VLM Release Disposition:**
   - *Current Canonical:* `mobile-capabilities-and-runtime.md` §9, `mobile-offline-and-sync.md` §3.1, and `MOBILE_SYSTEM_BASELINE.md` §7 state local VLM inference is excluded from Mobile V1 and is a `"Post-V1 Candidate"`.
   - *Batch D Approved:* `D-PHONE-16` **promotes qualified local still-image Vision to conditional Mobile V1**.

9. **Golden Acceptance Gate Structure:**
   - *Current Canonical:* `mobile-capabilities-and-runtime.md` §8 and `MOBILE_CHECKLIST.md` define **12 Mobile Golden Acceptance Groups (MG1–MG12)**.
   - *Batch D Approved:* `D-MOBILE-VERIFY-01` **expands the gate to 18 groups (MG1–MG18)**, covering Voice composition, model qualification, Health, Vision, Mobile UX, and the full integrated Companion journey.

10. **Mobile Shell Navigation & Design Vocabulary:**
    - *Current Canonical:* Prototype uses `Home / Tasks / Assistant / Health / More`, and `MOBILE_WBS.md` refers solely to `SoftGlass` theme tokens.
    - *Batch D Approved:* `D-PHONE-UX-01` locks navigation as **`Home / Schedule / COMPANION / Activity / More`**, and `D-PHONE-UX-08` locks a **hybrid visual language** (Minimalist foundation + selective Neumorphism + Glassmorphism/Liquid Glass contextual surfaces + OLED default).

---

## E. Shared-PC Compatibility Review

Batch D was audited against all frozen PC architecture rules. The "INHERIT FIRST" principle was upheld across every domain:

1. **Alignment with D7 (Profile-First Memory):**
   - *Verification:* Mobile explicit memory intent (`D-PHONE-08`) submits to D7 Host reconciliation (NEW / MERGE / UPDATE / CONFLICT / REJECT). Autonomous offline extraction remains disabled. Pinned offline memories (`D-PHONE-09`) are read-only replicas of D7 memories. Health context is strictly isolated from D7 Memory (`D-PHONE-15C`). Vision does not automatically create Memory (`D-SHARED-VISION-01`).
   - *Conclusion:* **100% COMPATIBLE.** Zero erosion of D7 invariants.

2. **Alignment with D9 (Tool Security & Policy):**
   - *Verification:* The Standalone Mobile Tool Gateway (`D-PHONE-13`) enforces identical D9 deterministic policies (Risk 0/1/2 evaluation, confirmation gates, emergency controls). Generic shell, OS administration, and unrestricted filesystems remain strictly REJECTED (`D-PHONE-13E`). Internet access does not grant Cloud LLM permission (`D-PHONE-13C`). Tool intents have zero inherent authority (`D-PHONE-13F`).
   - *Conclusion:* **100% COMPATIBLE.** Perfectly mirrors D9.

3. **Alignment with D10 (Scheduling & Notifications):**
   - *Verification:* Stable UUID identity across PC and Mobile (`D-SHARED-SCHED-01`). Mobile-created Reminders (`D-PHONE-10`) and Alarms (`D-PHONE-11`) use local scheduling but synchronize under D10 semantics. Cross-device presentation arbitration (`D-SHARED-SCHED-02`) prevents duplicate reminders while ensuring alarm reliability (Alarm duplicate > missed Alarm). Passive display != acknowledgement (`D-SHARED-SCHED-02`). Temporal intent resolution (`D-SHARED-SCHED-04`) and ambiguity clarification (`D-SHARED-SCHED-04A`) enforce cross-platform temporal parity (`D-SHARED-SCHED-04D`).
   - *Conclusion:* **100% COMPATIBLE.** Strengthens D10 across multiple devices.

4. **Alignment with D11 (Character, Personality, Emotion):**
   - *Verification:* Mobile strictly inherits D11 Character templates and instances (`D-PHONE-06`). Mobile-local competing Character schemas are forbidden. Emotion Event synchronization (`D-PHONE-EMO-01`) sends typed bounded events to the Host rather than mutating persistent Mood numeric values directly. Strong presets (Yandere) remain socially expressive without altering facts or truth (`D-PHONE-12E`).
   - *Conclusion:* **100% COMPATIBLE.** Completely preserves D11 authority.

5. **Profile / Device Ownership & ADR-0018 / ADR-0005:**
   - *Verification:* Mobile Satellite binds to exactly 1 Profile. PC Host is the sole Account and Profile Administrator (`D-PHONE-01B`). Device enrollment tokens and user API keys remain device-local in Android Keystore. Revocation erases local replicated domain data while preserving user 3rd-party keys.
   - *Conclusion:* **100% COMPATIBLE.**

6. **Client/Runtime Contract & ADR-0019:**
   - *Verification:* Connected Mobile chat uses REST turn submission + SSE streaming (`D-SHARED-CONV-02`). Full-duplex WebSocket is preserved exclusively for connected Voice (`D-PHONE-14A`). Active turn queueing, interruption, and safe regeneration (`D-SHARED-CONV-03`, `03A`) operate under ADR-0019 contract boundaries.
   - *Conclusion:* **100% COMPATIBLE.**

7. **Voice Architecture (`voice-and-audio.md`):**
   - *Verification:* Phone owns native audio capture, playback, audio focus, and immediate barge-in muting. PC Runtime owns canonical connected STT/TTS/VAD. Local TTS (`D-PHONE-14B`) and STT (`D-PHONE-14C`) are decoupled and conditional. Raw audio remains strictly ephemeral (`D-PHONE-14G`).
   - *Conclusion:* **100% COMPATIBLE.**

8. **Runtime, Models & Performance Governance (`runtime-and-models.md`, `performance-and-capacity.md`):**
   - *Verification:* Single resident model policy (`--models-max 1`) is strictly preserved on Mobile (`D-PHONE-05`). Resource Governor (`D-PHONE-05A`) monitors thermals and memory without fabricating telemetry. Context Budget Manager (`D-SHARED-AI-01`) respects effective safe context bounds.
   - *Conclusion:* **100% COMPATIBLE.**

9. **Multimodal Architecture (`multimodal-and-media.md`):**
   - *Verification:* Camera capture feeds the shared attachment pipeline (`D-PHONE-16A`). Image turns persist durably offline (`D-PHONE-16D`). Still images only; ambient background camera surveillance remains strictly rejected (`D-PHONE-16E`).
   - *Conclusion:* **100% COMPATIBLE.**

10. **Security & Privacy:**
    - *Verification:* Fail-closed authentication, Tailscale/encrypted overlay for non-loopback traffic, no direct port forwarding, Android private sandbox storage baseline, Keystore protection for secrets.
    - *Conclusion:* **100% COMPATIBLE.**

---

## F. Stale Planning & PR Statements

The following specific documents and locations contain outdated wording reflecting the older Batches A–C closure that must be updated during planning spine integration:

1. **`docs/02_Planning/00_Master/MOBILE_WBS.md`:**
   - §3 lists Health Connect, autonomous Routines, and local VLM as "Explicit Mobile V1 Non-Goals." Must be revised to reflect conditional Mobile V1 inclusion.
   - `MOB-FOUNDATION-003` specifies "theme tokens (SoftGlass)" only. Must reflect the hybrid visual language.
   - `MOB-VERIFY-006` references only "MG1–MG12." Must expand to MG1–MG18.
   - Missing work streams/items for Standalone Tool Gateway, Health Connect ingestion, Local Vision, Context Budgeting, and Branching UX.

2. **`docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`:**
   - Structured around 12 Golden Groups (MG1–MG12). Must expand to 18 groups (MG1–MG18).
   - Contains rows marking Health Connect and Vision as "Mobile Later / Sequestered."

3. **`docs/02_Planning/00_Master/DECISION_REGISTER.md`:**
   - Status header claims "Mobile Architecture Pass APPROVED (2026-10-04)."
   - Row 50 states local LLM is an "optional auxiliary capability in V1."
   - Row 53 states Health Connect is "Mobile Later."

4. **`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`:**
   - Lines 17, 55, 68 mark MOBILE-ARCH as `[COMPLETE / APPROVED]`.
   - Line 67 lists Health Connect, Routines, and local VLM as deferred non-goals.

5. **`docs/02_Planning/00_Master/DELIVERY_INDEX.md`:**
   - Line 38 lists MOBILE-ARCH status as `COMPLETE / APPROVED`.

6. **`docs/02_Planning/00_Master/DECISION_DEBT.md`:**
   - Lists only 10 mobile decision debt items. Needs expansion with the 26 implementation-open items from Batch D §19.

7. **`docs/06_Guides/DOCUMENTATION_MAP.md`:**
   - References the 65-item WBS and MG1–MG12.

8. **Pull Request #21 Title and Description:**
   - Claims MOBILE-ARCH is complete and lists Batches A–C closure evidence. Must be updated upon Batch D completion to summarize the reconciled product architecture.

---

## G. Missing Decisions & Ambiguity Review

A rigorous audit of the supplied Batch D ledger against actual repository requirements reveals:

1. **One Profile to Multiple Mobile Devices:**
   - *Status:* Explicitly left **OPEN** in `D-SHARED-CONV-01` ("One Profile -> multiple phones remains OPEN") and `D-PHONE-EMO-01` ("multi-device ordering remains open").
   - *Recommendation:* Keep open as implementation debt (`DEBT-MOB-MULTI-DEVICE`). Mobile V1 baseline guarantees 1 Device -> 1 Profile. Multi-phone synchronization against the same Profile is deferred.

2. **No Unresolved Architecture Gaps:**
   - No hidden, unapproved architectural decisions were detected.
   - The ledger cleanly addresses all 98 mandatory reconciliation targets without requiring invention by the agent.

---

## H. Proposed Canonical Promotion Batches

To ensure reliable, reviewable, and non-destructive documentation promotion, the changes are partitioned into **4 coherent promotion batches**:

```text
Batch D2: Core Baseline, Governance & Scheduling
  │ (MOBILE_SYSTEM_BASELINE.md, mobile-offline-and-sync.md, tasks-reminders-alarms-and-routines.md)
  ▼
Batch D3: Intelligence, AI Runtime, Memory & Tools
  │ (mobile-capabilities-and-runtime.md, assistant-and-conversations.md, memory-and-personalization.md, tool-permissions-and-actions.md)
  ▼
Batch D4: Voice, Health, Vision & UX/Design
  │ (voice-and-audio.md, health-and-wearables.md, multimodal-and-media.md, characters-personality-and-emotion.md, new Mobile Design spec)
  ▼
Batch D5: Master Planning Spine, Golden Verification & PR #21 Handoff
    (MOBILE_WBS.md, MOBILE_CHECKLIST.md, DECISION_REGISTER.md, SPRINT_ROADMAP.md, DELIVERY_INDEX.md, DECISION_DEBT.md, DOCUMENTATION_MAP.md)
```

### Batch D2 — Core Baseline, Governance & Scheduling
- **Purpose:** Update the foundational ecosystem authority, orthogonal execution states, and full offline scheduling (Tasks, Reminders, Alarms, Routines).
- **Decisions Covered:** `D-PHONE-01A`, `D-PHONE-01B`, `D-PHONE-02`, `D-SHARED-SCHED-01`, `D-PHONE-10`, `D-PHONE-11`, `D-SHARED-SCHED-02`, `D-SHARED-SCHED-03`, `D-SHARED-SCHED-04` (A–E), `D-PHONE-12` (A–C), `D-SHARED-FLUTTER-01`–`08`, `D-PHONE-FLUTTER-01`.
- **Target Files:**
  - `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
  - `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
  - `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`
  - `docs/04_Architecture/01_Domains/android-companion.md`
- **Dependencies:** None (first batch).
- **Checkpoint:** Independent review of offline scheduling and sync contracts.

### Batch D3 — Intelligence, AI Runtime, Memory & Tools
- **Purpose:** Reconcile local LLM production capability, Resource Governor, Context Budget Manager, compaction/branching, selective Memory replica, explicit Memory intent, and Standalone Tool Gateway.
- **Decisions Covered:** `D-PHONE-01`, `D-PHONE-01C`, `D-PHONE-03`, `D-PHONE-05`, `D-PHONE-05A`, `D-SHARED-AI-01`, `D-SHARED-AI-02`, `D-SHARED-AI-03`, `D-PHONE-08`, `D-PHONE-08A`, `D-PHONE-09`, `D-SHARED-CONV-01`, `D-SHARED-CONV-02`, `D-SHARED-CONV-03`, `D-SHARED-CONV-03A`, `D-PHONE-13` (A–F), `Gemma 3 1B`.
- **Target Files:**
  - `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`
  - `docs/04_Architecture/01_Domains/assistant-and-conversations.md`
  - `docs/04_Architecture/01_Domains/memory-and-personalization.md`
  - `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`
  - `docs/04_Architecture/03_Integrations/web-current-information.md`
- **Dependencies:** Batch D2.
- **Checkpoint:** Independent review of conversation branching, memory overlays, and tool security.

### Batch D4 — Voice, Health, Vision & UX/Design
- **Purpose:** Reconcile composable Voice, restore Health Connect (conditional V1), promote local still-image Vision (conditional V1), D11 Emotion sync, and establish canonical Mobile UX / visual language.
- **Decisions Covered:** `D-PHONE-04`, `D-PHONE-14` (A–G), `D-PHONE-15` (A–E), `D-SHARED-HEALTH-01`–`04`, `D-PHONE-16` (A–E), `D-SHARED-VISION-01`, `D-PHONE-06`, `Char Authority`, `D-PHONE-EMO-01`, `D-PHONE-12D`, `D-PHONE-12E`, `P-SHARED-PRESENCE-01`, `P-PHONE-AR-01`–`02`, `P-PRESENCE-02`, `D-PHONE-UX-01`–`10`, `D-SHARED-LANG-01`–`02`.
- **Target Files:**
  - `docs/04_Architecture/01_Domains/voice-and-audio.md`
  - `docs/04_Architecture/03_Integrations/health-and-wearables.md`
  - `docs/04_Architecture/01_Domains/multimodal-and-media.md`
  - `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`
  - `docs/05_Design/02_Components/mobile-companion-ui.md` (or dedicated mobile design spec)
- **Dependencies:** Batch D3.
- **Checkpoint:** Independent review of Health Connect boundaries, local VLM qualification, and visual language.

### Batch D5 — Master Planning Spine, Golden Verification & PR #21 Handoff
- **Purpose:** Expand WBS (from 65 to ~85+ items), update Readiness Checklist to MG1–MG18, update Decision Register, Roadmap, Delivery Index, Decision Debt, Documentation Map, author delivery walkthrough, and prepare PR #21 handoff.
- **Decisions Covered:** `D-MOBILE-VERIFY-01`–`03`, `D-CI-01`–`04`, Sec 18 (Deferred non-goals), Sec 19 (Decision debt), Sec 20 (Contradictions resolved).
- **Target Files:**
  - `docs/02_Planning/00_Master/MOBILE_WBS.md`
  - `docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`
  - `docs/02_Planning/00_Master/DECISION_REGISTER.md`
  - `docs/02_Planning/00_Master/SPRINT_ROADMAP.md`
  - `docs/02_Planning/00_Master/DELIVERY_INDEX.md`
  - `docs/02_Planning/00_Master/DECISION_DEBT.md`
  - `docs/06_Guides/DOCUMENTATION_MAP.md`
  - `docs/03_Walkthroughs/walkthrough-mobile-v1-batch-d-reconciliation.md`
  - `CHANGELOG.md`
- **Dependencies:** Batch D4.
- **Checkpoint:** Independent Closure Gate, PR #21 description update, and closure review.

---

## I. Planning, WBS & Golden Impact Summary

1. **WBS Stream Expansion (`MOBILE_WBS.md`):**
   - The current 65-item WBS will expand to **~85–90 items**.
   - Add new stream `MOB-HEALTH` (Health Connect read-only adapter, metric permissions, normalized DTOs).
   - Add new stream `MOB-VISION` (or expand `MOB-INFER`: camera adapter, local VLM qualification, offline image turns).
   - Expand `MOB-SCHED` with offline Reminder/Alarm CRUD and Routine check-in presentation.
   - Expand `MOB-CONV` with causal branching, compare UX, turn queueing, and safe regeneration.
   - Expand `MOB-FOUNDATION` with the 5-tab Companion shell and hybrid visual tokens.

2. **Checklist & Golden Gate Expansion (`MOBILE_CHECKLIST.md`):**
   - Expand from MG1–MG12 (55 rows) to **MG1–MG18 (~75+ rows)**.
   - Introduce explicit qualification classification: `REQUIRED`, `CONDITIONAL`, `OPTIONAL`, `DEFERRED`.

3. **Roadmap & Delivery Index (`SPRINT_ROADMAP.md`, `DELIVERY_INDEX.md`):**
   - Mark MOBILE-ARCH as active/reopened for Batch D until Batch D5 passes Closure Gate.
   - Reconcile dependencies ensuring M1 Flutter Desktop remains unblocked while Mobile follow-on tracks have complete, truthful architecture.

---

## J. Recommended Commit Checkpoints

Chris is the sole Git mutation owner. The following sequential documentation commit checkpoints are recommended:

1. **Checkpoint 1 (Current Task D1):**
   ```text
   docs(mobile): add Batch D approved ledger and reconciliation report
   ```
2. **Checkpoint 2 (Batch D2 Promotion):**
   ```text
   docs(mobile): promote Batch D2 core baseline, governance, and scheduling
   ```
3. **Checkpoint 3 (Batch D3 Promotion):**
   ```text
   docs(mobile): promote Batch D3 intelligence, context, memory, and tool gateway
   ```
4. **Checkpoint 4 (Batch D4 Promotion):**
   ```text
   docs(mobile): promote Batch D4 voice, health, vision, and mobile UX design
   ```
5. **Checkpoint 5 (Batch D5 Planning & Closure):**
   ```text
   docs(mobile): reconcile Batch D5 master planning spine, MG1-MG18, and walkthrough
   ```

---

## K. Final Stop Report

1. **Conflicts Found:** 10 explicit structural contradictions identified between current canonical docs and the approved Batch D ledger (see Section D).
2. **Unresolved Human Decisions:** Zero blocking architecture ambiguities found. The one-profile-to-multiple-phones question is cleanly categorized as open decision debt.
3. **Safe-to-Promote Areas:** All 4 promotion batches are fully mapped, decoupled, and internally consistent with shared PC architecture.
4. **Blocked Areas:** None. Zero production code, test, or CI files require modification.
5. **Exact Next Recommended Batch:** **Batch D2 — Core Baseline, Governance & Scheduling** (`MOBILE_SYSTEM_BASELINE.md`, `mobile-offline-and-sync.md`, `tasks-reminders-alarms-and-routines.md`, `android-companion.md`), pending Chris/GPT independent review of this reconciliation report.
