# AI Companion — MOBILE-ARCH Batch D Reconciliation Report

> **Document Role:** Comprehensive Mismatch Analysis, Shared-PC Compatibility Audit, and Canonical Promotion Strategy for MOBILE-ARCH Batch D.
> **Status:** Working Research Artifact — Independent Review Checkpoint (R1 / Batch D1.2 Final Accuracy Pass).
> **Human Approver / Git Mutation Owner:** Chris.
> **Working Branch:** `docs/mobile-v1-canonicalization`.
> **Starting HEAD SHA:** `c32711aa0fdbe4462f1ee5d0b85b2d9aaab06705`.
> **Authority Precedence:** This report is an analytical research draft under `docs/00_Drafts/research/mobile/`. It does **not** alter canonical architecture, planning spine documents, or code. Canonical promotion requires Chris/GPT independent review and approved domain batching.

---

## A. Repository Starting State

1. **Active Branch:** `docs/mobile-v1-canonicalization`
2. **Exact Starting HEAD SHA:** `c32711aa0fdbe4462f1ee5d0b85b2d9aaab06705` (incorporating Batch D1 research draft commits).
3. **Working Tree Status Before Edits:** Clean (`git status --short` returned 0 modified, 0 staged, 0 untracked files).
4. **Git Mutation Governance:** Strictly respected. Zero branches created or switched; zero commits, tags, merges, rebases, stashes, resets, or PR mutations performed.
5. **PR #21 Status:** PR #21 remains open and is currently Draft. MOBILE-ARCH closure was reopened for Batch D product reconciliation. The current PR #21 description reflects the historical Batches A–C closure (`889bae5d2a0eb6afdc3d7a8dc19592c9304114db` / `cef9baee3d61a90c884e1915b49ff4978d583da7`), which claims MOBILE-ARCH is complete and lists Health Connect, local VLM, and autonomous routines as deferred non-goals. PR #21 must remain unmerged until Batch D reconciliation, canonical promotion, independent review, closure, and fresh PR CI are completed.

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
- [`docs/02_Planning/00_Master/MASTER_CHECKLIST.md`](../../../02_Planning/00_Master/MASTER_CHECKLIST.md)
- [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../../02_Planning/00_Master/DECISION_REGISTER.md)
- [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../../../02_Planning/00_Master/SPRINT_ROADMAP.md)
- [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](../../../02_Planning/00_Master/DELIVERY_INDEX.md)
- [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../../02_Planning/00_Master/DECISION_DEBT.md)

### 5. Input Working Decision Source
- [`docs/00_Drafts/research/mobile/MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md`](MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md)

---

## C. Decision-by-Decision Reconciliation Matrix

Every approved decision, direction, and boundary in `MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md` is evaluated below without sampling.

### Mismatch Classification Taxonomy
To ensure rigorous distinction between actual normative conflicts and other forms of divergence, each row is assigned one of the following explicit mismatch classes:
- **`CANONICAL_CONFLICT`:** Two canonical normative requirements cannot both remain true. Requires superseding/reconciling canonical documentation.
- **`CANONICAL_GAP`:** Target architecture is absent or unformalized in current canonical docs, but not prohibited by a conflicting rule.
- **`IMPLEMENTATION_STATUS`:** Current documentation truthfully records implemented code status (e.g., "NOT IMPLEMENTED"), while Batch D approves the target architecture.
- **`PLANNING_STALE`:** Master planning documents (WBS, Checklist, Roadmap, Delivery Index, Decision Debt, Map) contain outdated wording from Batches A–C closure.
- **`PROTOTYPE_DIFFERENCE`:** Differences from exploratory Kotlin prototype implementation.
- **`NONE`:** Current canonical documentation already agrees with the approved decision.

Allowed Dispositions: `PRESERVE`, `REFINE`, `SUPERSEDE`, `PROMOTE`, `KEEP OPEN`, `DEFER`, `WITHDRAWN`.

| Decision ID | Decision Title | Ledger Status | Existing Canonical Owner | Current Repository Wording / State | Mismatch Class | Disposition | Target Canonical Destination | Planning / WBS Impact | Golden Impact | Implementation-Open Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **D-PHONE-01** | Production-capable local LLM path | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Stated as "optional-auxiliary capability in V1" and "NOT mandatory to run or use the Mobile Companion." | **CANONICAL_CONFLICT** (normative capability framing: ledger mandates a real production-capable execution path for qualified devices; current docs understate it as mere optional auxiliary) | **SUPERSEDE** | `mobile-capabilities-and-runtime.md` §2, `MOBILE_SYSTEM_BASELINE.md` §5, §7 | Revise `MOB-INFER-001`, `MOB-INFER-002`; clarify production status | MG14, MG4 | Exact model family, runtime, backend, quantization, minimum hardware remain open |
| **D-PHONE-01A** | Orthogonal availability dimensions | LOCKED V1 | `MOBILE_SYSTEM_BASELINE.md` §5, `mobile-offline-and-sync.md` §3.2.6 | Table groups capabilities under coupled monolithic modes: `CONNECTED_TO_PC`, `OFFLINE_LOCAL`, `OPTIONAL_CLOUD`. | **CANONICAL_CONFLICT** (normative mode model: ledger establishes host reachability, internet, and inference routing as 3 orthogonal dimensions rather than coupled modes) | **REFINE** | `MOBILE_SYSTEM_BASELINE.md` §5, `mobile-offline-and-sync.md` §3.2.6 | Add clear orthogonal state matrix to `MOB-FOUNDATION-005` | MG4, MG6 | UI display indicators and state machine mechanics remain open |
| **D-PHONE-01B** | Enrollment before normal Companion use | LOCKED V1 | `MOBILE_SYSTEM_BASELINE.md` §4.1, §4.3, `profiles-and-devices.md` §3.2 | Agrees that Mobile satellite binds to 1 Profile and requires enrollment; lacks explicit lifecycle states (`UNENROLLED`, `ENROLLED_ACTIVE`, etc.). | **CANONICAL_GAP** (normative agreement; lifecycle states unformalized) | **PROMOTE** | `MOBILE_SYSTEM_BASELINE.md` §4.1, `profiles-and-devices.md` §5 | Map lifecycle states across MOB-IDENTITY-001 (Pairing), MOB-IDENTITY-003 (Expiry/Rotation), MOB-IDENTITY-004 (Revocation), and MOB-CONTRACT-005 (Lifecycle Outcomes Protocol) | MG1 | Pairing UX (QR vs PIN code) and crypto payload remain open |
| **D-PHONE-01C** | Replaceable local models | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.3 | Mentions single resident model cap and engine independence, but lacks user-facing model switching / qualification disabling semantics. | **CANONICAL_GAP** (partially agrees; model switcher and qualification gate unformalized) | **REFINE** | `mobile-capabilities-and-runtime.md` §2.3, `runtime-and-models.md` §2.5 | Add model switcher and qualification gate to `MOB-INFER-003` | MG14 | UI controls, download manager, and storage paths remain open |
| **D-PHONE-02** | Core survives without generative AI | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.1.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Fully agrees: Tasks, Reminders, Alarms, cached history, settings function 100% offline without local LLM. | **NONE** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §2.1.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Retain `MOB-DATA`, `MOB-SCHED` independence from `MOB-INFER` | MG4 | None |
| **D-PHONE-03** | Vendor-neutral Mobile execution | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.2, §2.3.5 | Agrees on engine independence (GGUF, ONNX, ExecuTorch); lacks explicit CPU fallback mandate and truthful backend reporting requirement. | **CANONICAL_GAP** (partially agrees; CPU fallback and truthful reporting unformalized) | **REFINE** | `mobile-capabilities-and-runtime.md` §2.2, §2.3 | Expand `MOB-INFER-001` with backend detection & CPU fallback | MG14 | Native JNI/C++ adapter bindings remain open |
| **D-PHONE-04** | Replaceable speech providers | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.2 | Agrees local TTS and STT are independent; lacks explicit Auto vs Advanced selection and Kokoro/Kitten trade-off notes. | **CANONICAL_GAP** (partially agrees; Auto vs Advanced provider selection unformalized) | **REFINE** | `mobile-capabilities-and-runtime.md` §3.2, `voice-and-audio.md` §2.8 | Map across MOB-VOICE-005 (local TTS), MOB-VOICE-006 (local STT), MOB-VOICE-007 (cloud voice routing), or add dedicated speech-provider selection item during D5 | MG13 | Exact local TTS/STT binaries and models remain open |
| **D-PHONE-05** | Mobile model lifecycle | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.3 | Distinguishes resident vs unloaded; lacks explicit 5-state lifecycle (`installed`, `loaded/resident`, `active`, `unloaded`, `removed`). | **CANONICAL_GAP** (partially agrees; 5-state lifecycle unformalized) | **REFINE** | `mobile-capabilities-and-runtime.md` §2.3 | Update `MOB-INFER-003` with formal 5-state lifecycle | MG14 | Cache eviction rules and storage layout remain open |
| **D-PHONE-05A** | Resource Governor + truthful UI | LOCKED V1 | `mobile-capabilities-and-runtime.md` §6.2, §6.3 | Monitors thermals/memory; lacks progressive user-actionable interventions (Continue, Reduce, Finish then cool, Stop & unload) and truthful status UI. | **CANONICAL_GAP** (partially agrees; progressive interventions and status UI unformalized) | **REFINE** | `mobile-capabilities-and-runtime.md` §6.2, §6.3, `performance-and-capacity.md` §2.3 | Add Resource Governor stream or task (`MOB-INFER-005` revision) | MG14, MG17 | Exact thermal/battery numerical thresholds remain open |
| **D-SHARED-AI-01** | Context / generation / reasoning budget manager | LOCKED SHARED | `assistant-and-conversations.md` §3.3, `SYSTEM_BASELINE.md` §3 | Only specifies static `MEMORY_BUDGET_TOKENS = 256` and simple turn truncation; lacks dynamic budget manager and safe context reduction. | **CANONICAL_GAP** (partially agrees; dynamic budget manager unformalized in shared architecture) | **PROMOTE** | `assistant-and-conversations.md` §2.2, `SYSTEM_BASELINE.md` §3 | Update `PC-AI` and add shared budget manager in `MOB-CONV` | MG6, MG7 | Token estimation ratios and buffer sizes remain open |
| **D-SHARED-AI-02** | Conversation compaction & historical recall | LOCKED SHARED | `assistant-and-conversations.md` §3.4 | Explicitly states: "Conversation Compaction / Summarization: NOT IMPLEMENTED. Rolling summaries are not yet generated." | **IMPLEMENTATION_STATUS** (current doc truthfully records implementation status; Batch D approves rolling compaction and historical recall as target architecture; implementation truth is preserved while target architecture is promoted separately) | **PROMOTE** | `assistant-and-conversations.md` §2.2, §4, `mobile-offline-and-sync.md` §3.2.6 | Add Host summarization contract & Mobile provisional summary task | MG6, MG7 | Exact prompt template, summary schema, and trigger threshold remain open |
| **D-SHARED-AI-03** | Unified context retrieval | LOCKED SHARED | `memory-and-personalization.md` §2.4, `assistant-and-conversations.md` §3.3 | Memories retrieved via FTS5; conversation summaries and pending local context are not integrated into unified retrieval. | **CANONICAL_GAP** (partially agrees; unified retrieval waterfall across summaries, memories, and pending context unformalized) | **REFINE** | `memory-and-personalization.md` §2.4, `assistant-and-conversations.md` §2.2 | Add unified context assembler task to shared planning | MG7 | Ranking algorithm (lexical vs embedding vs hybrid) remains open |
| **D-PHONE-09** | Selective offline Memory replica | LOCKED V1 | `mobile-offline-and-sync.md` §2.1, §3.1, `MOBILE_SYSTEM_BASELINE.md` §5 | States Memory is "UNAVAILABLE / Cached view only" offline; no pinning or selective continuity replica defined. | **CANONICAL_GAP** (refines existing read-only offline cache model with selective pinning and continuity replica; not a prohibition conflict because local writes remain disallowed) | **REFINE / PROMOTE** | `mobile-offline-and-sync.md` §2.1, §3.1, `memory-and-personalization.md` §2.1 | Add Memory replica and pinning task to `MOB-DATA` | MG7 | Exact replica selection algorithm and cache eviction limits remain open |
| **D-SHARED-CONV-01** | Causal conversation identity & branching | LOCKED SHARED | `mobile-offline-and-sync.md` §3.2.6, `assistant-and-conversations.md` §2.2 | Acknowledges non-destructive branch import on concurrent edit; lacks causal parentage IDs (`parent_turn_id`, `branch_id`), Compare UX, and single-phone boundary lock. | **CANONICAL_GAP** (partially agrees; causal parentage schema and branching UX unformalized) | **REFINE** | `assistant-and-conversations.md` §2.2, `mobile-offline-and-sync.md` §3.2.6 | Update `MOB-CONTRACT-007` (provenance/branch metadata); add new/revised branching coordination and UX work item to `MOB-CONV` during D5 (`MOB-CONV-003` is Tier 0/1 fallback guard) | MG6 | Exact DB representation and multi-phone-per-profile resolution remain open |
| **D-SHARED-CONV-02** | Host-mediated live turn streaming | LOCKED SHARED | `assistant-and-conversations.md` §2.2, `mobile-capabilities-and-runtime.md` §8 (MG3) | Fully agrees: REST submission + SSE token streaming; active turn continues across disconnect; GET history catch-up. | **NONE** (fully agrees) | **PRESERVE** | `assistant-and-conversations.md` §2.2, `mobile-offline-and-sync.md` §3.2.6 | Retain `MOB-CONV-001` | MG3, MG6 | None |
| **D-SHARED-CONV-03** | Active turn control (Queue, Interrupt, Fork) | LOCKED SHARED | `assistant-and-conversations.md` §2.2 | Mentions FIFO queue and cancellation; lacks explicit 3-way turn control primitives (`QUEUE`, `INTERRUPT_AND_SEND`, `FORK_FROM_HERE`). | **CANONICAL_GAP** (partially agrees; explicit 3-way turn control primitives unformalized) | **PROMOTE** | `assistant-and-conversations.md` §2.2, `mobile-offline-and-sync.md` §3.2.6 | Add turn control protocol to `MOB-CONTRACT` and `MOB-CONV` | MG6 | UI gesture/button mapping and payload schemas remain open |
| **D-SHARED-CONV-03A** | Safe regeneration | LOCKED SHARED | `assistant-and-conversations.md` §2.2 | Does not specify regeneration semantics or side-effect re-execution guardrails. | **CANONICAL_GAP** (unspecified; safe regeneration contract unformalized) | **PROMOTE** | `assistant-and-conversations.md` §2.2, `tool-permissions-and-actions.md` §2.1 | Add safe regenerate contract to `MOB-CONTRACT` | MG6 | DB storage of alternative responses remains open |
| **D-PHONE-06** | Character selection inherits D11 | LOCKED V1 | `characters-personality-and-emotion.md` §2.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Agrees: Character switching never alters Profile data, security policy, or Tasks. Mobile selects cached Character. | **NONE** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §5, `characters-personality-and-emotion.md` §2.1 | Retain `MOB-FOUNDATION` Character binding | MG8 | None |
| **Char Authority** | Connected edit ok; no offline canonical create | LOCKED V1 dir | `characters-personality-and-emotion.md` §2.1, `mobile-offline-and-sync.md` §3.1 | Agrees: Character templates/instances are PC-managed; cached view offline. Connected Mobile editing not explicitly documented. | **CANONICAL_GAP** (partially agrees; connected editing via Host API unformalized) | **REFINE** | `characters-personality-and-emotion.md` §2.1, `mobile-offline-and-sync.md` §3.1 | Add connected Character Studio client note to WBS | MG8 | Exact Character Studio mobile UI layout remains open |
| **D-PHONE-EMO-01** | Offline Emotion Event Synchronization | LOCKED V1 dir | `characters-personality-and-emotion.md` §2.1.5, `mobile-offline-and-sync.md` §3.1 | States Character/Persona is read-only cached view offline; zero event-sync mechanism defined. | **CANONICAL_GAP** (current doc defines read-only offline Character view; ledger defines an Emotion Event outbox syncing typed events to Host without directly mutating canonical Mood numeric state, preserving D11 Host authority) | **PROMOTE** | `mobile-offline-and-sync.md` §3.1, `characters-personality-and-emotion.md` §2.1 | Add Emotion Event outbox and sync to `MOB-DATA` / `MOB-SYNC` | MG8 | Exact emotion taxonomy, decay curves, and confidence remain open |
| **D-PHONE-08** | Offline explicit Memory intent | LOCKED V1 | `mobile-offline-and-sync.md` §3.2.6 (item 8) | Explicitly states: "No Autonomous Local Memory Extraction... memory database writes are DISABLED on Mobile in V1." | **CANONICAL_GAP** (current doc prohibits direct offline DB writes; pending explicit Memory intent is an outbox/intent path submitted to Host D7 reconciliation, NOT a direct canonical DB write on Mobile; Host authority is preserved) | **PROMOTE** | `mobile-offline-and-sync.md` §3.2.6, `memory-and-personalization.md` §2.3 | Add `PENDING_SYNC` Memory Intent outbox to `MOB-DATA` / `MOB-SYNC` | MG7 | Exact schema and conflict payload format remain open |
| **D-PHONE-08A** | Pending Memory overlay | LOCKED V1 | `memory-and-personalization.md` §3.3, `mobile-offline-and-sync.md` §3.2.6 | No local memory overlay mechanism exists or is documented. | **CANONICAL_GAP** (local provisional memory overlay for conversational continuity is absent in canonical specs; does not conflict with Host authority) | **PROMOTE** | `mobile-offline-and-sync.md` §3.2.6, `memory-and-personalization.md` §2.3 | Add pending memory context injector to `MOB-CONV` | MG7 | Provenance tagging and UI distinction styling remain open |
| **D-SHARED-SCHED-01** | Stable scheduling identity | LOCKED SHARED | `mobile-offline-and-sync.md` §3.2.1, `tasks-reminders-alarms-and-routines.md` §3.1 | Agrees on client UUIDv4 for offline entities; specifies Tasks; needs explicit coverage for Reminders, Alarms, Routines, and mutations. | **CANONICAL_GAP** (partially agrees; needs explicit coverage across all scheduling primitives) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.1, `mobile-offline-and-sync.md` §3.2.1 | Expand `MOB-CONTRACT-001` across all scheduling primitives | MG9 | None |
| **D-PHONE-10** | Offline Reminder authoring | LOCKED V1 | `mobile-offline-and-sync.md` §3.1 (table row 2) | Explicitly states: Reminders offline writable: "LIMITED (Ack / Dismiss / Snooze only; no canonical entity creation)." | **CANONICAL_CONFLICT** (normative conflict: canonical doc prohibits offline creation; ledger approves full offline CRUD for Mobile-created Reminders) | **SUPERSEDE** | `mobile-offline-and-sync.md` §3.1, §5, `MOBILE_SYSTEM_BASELINE.md` §5 | Update `MOB-SCHED-001` and `MOB-DATA-002` for full Reminder CRUD | MG9 | UI presentation and duplicate prevention heuristics remain open |
| **D-PHONE-11** | Offline Alarm authoring | LOCKED V1 | `mobile-offline-and-sync.md` §3.1 (table row 3) | Explicitly states: Alarms offline writable: "LIMITED (Dismiss / Snooze only; canonical recurring alarm config is PC-owned)." | **CANONICAL_CONFLICT** (normative conflict: canonical doc restricts alarm config to PC-owned; ledger approves full offline CRUD for Mobile-created Alarms) | **SUPERSEDE** | `mobile-offline-and-sync.md` §3.1, §6, `MOBILE_SYSTEM_BASELINE.md` §5 | Update `MOB-SCHED-002` and `MOB-DATA-003` for full Alarm CRUD | MG9 | Alarm sound assets, snooze limits, and ring screen remain open |
| **D-SHARED-SCHED-02** | Cross-device presentation arbitration | LOCKED SHARED | `mobile-capabilities-and-runtime.md` §8 (MG12), `mobile-offline-and-sync.md` §6 | Mentions independent ringing and dismissal sync; lacks primary/standby escalation, preference options, and passive-display rule. | **CANONICAL_GAP** (partially agrees; arbitration protocol and passive-display rule unformalized) | **PROMOTE** | `tasks-reminders-alarms-and-routines.md` §2.4, `mobile-offline-and-sync.md` §6 | Expand `MOB-SCHED-007` (Cross-Device Dismissal Semantics & Duplicate Prevention) or add dedicated presentation arbitration item during D5 | MG10 | Exact escalation grace period and reachability ping remain open |
| **D-SHARED-SCHED-03** | Companion alert enrichment | LOCKED SHARED | `tasks-reminders-alarms-and-routines.md` §2.7 | Agrees: LLM provides enrichment/presentation, not schedule authority. Needs explicit Mobile/TTS alert enrichment semantics. | **CANONICAL_GAP** (partially agrees; mobile spoken alert enrichment semantics unformalized) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.7, `mobile-capabilities-and-runtime.md` §3.2 | Add companion spoken alert task to `MOB-SCHED` | MG9, MG13 | Exact phrase templates and character prompt injections remain open |
| **D-SHARED-SCHED-04** | Temporal Intent Resolution | LOCKED SHARED | `tasks-reminders-alarms-and-routines.md` §2.5 | Mentions natural-language schedule input; lacks formal typed intent taxonomy and deterministic resolution pipeline. | **CANONICAL_GAP** (partially agrees; typed intent taxonomy and deterministic pipeline unformalized) | **PROMOTE** | `tasks-reminders-alarms-and-routines.md` §2.5 | Add temporal intent resolver task to shared scheduling | MG9 | Exact parsing library and regex/grammar rules remain open |
| **D-SHARED-SCHED-04A** | Field-level ambiguity & clarification | LOCKED SHARED | `tool-permissions-and-actions.md` §2.7, `tasks-reminders-alarms-and-routines.md` §2.5 | Notes low-confidence action fields require clarification; lacks specific scheduling field-level ambiguity rules. | **CANONICAL_GAP** (partially agrees; specific scheduling ambiguity dialog rules unformalized) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.5, `tool-permissions-and-actions.md` §2.7 | Add clarification dialogue test vectors to `MOB-SCHED` | MG9 | Clarification prompt templates remain open |
| **D-SHARED-SCHED-04B** | Timezone & recurrence semantics | LOCKED SHARED | `tasks-reminders-alarms-and-routines.md` §2.5 | Fully agrees: floating local vs fixed-timezone recurrence are distinct concepts; clock/timezone changes reconcile deterministically. | **NONE** (fully agrees) | **PRESERVE** | `tasks-reminders-alarms-and-routines.md` §2.5, `mobile-offline-and-sync.md` §6.2 | Retain MOB-SCHED-005 (System Lifecycle Handlers: Reboot, Timezone, Clock Changes) | MG9 | Specific Olson timezone mapping libraries remain open |
| **D-SHARED-SCHED-04C** | Alarm strictness | LOCKED SHARED | `tasks-reminders-alarms-and-routines.md` §2.1.3 | Agrees Alarms have stronger delivery semantics; lacks explicit requirement that AM/PM/date ambiguity MUST be resolved prior to arming. | **CANONICAL_GAP** (partially agrees; mandatory pre-arm ambiguity resolution unformalized) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.1.3 | Add strict validation gate to `MOB-SCHED-002` | MG9 | Exact prompt dialogue for AM/PM check remains open |
| **D-SHARED-SCHED-04D** | Cross-platform temporal parity | LOCKED SHARED | `MOBILE_WBS.md` Stream `MOB-VERIFY` | Parity is an overall objective; lacks explicit shared machine-readable Golden temporal test vectors. | **CANONICAL_GAP** (partially agrees; machine-readable Golden temporal test vectors unformalized) | **PROMOTE** | `tasks-reminders-alarms-and-routines.md` §2.5, `mobile-capabilities-and-runtime.md` §7 | Add temporal Golden vector suite to `MOB-VERIFY-001` | MG9 | Golden phrase dataset composition remains open |
| **D-SHARED-SCHED-04E** | Preference/history-informed temporal clarification | LOCKED SHARED | `memory-and-personalization.md` §2.1, `tasks-reminders-alarms-and-routines.md` §2.5 | Not currently articulated as an explicit context priority waterfall (instruction > conv > prefs > Memory > patterns > summaries > clarify). | **CANONICAL_GAP** (unspecified; context priority waterfall unformalized) | **PROMOTE** | `tasks-reminders-alarms-and-routines.md` §2.5, `memory-and-personalization.md` §2.3 | Add priority resolution logic to scheduler integration | MG9 | Historical pattern detection algorithm remains open |
| **P-PHONE-LOC-01** | Opt-in Location Context | MOBILE LATER | None | Not documented in current canonical Mobile architecture. | **CANONICAL_GAP** (future capability; documented as approved non-goal / deferred boundary) | **DEFER** | `mobile-capabilities-and-runtime.md` §4, `MOBILE_SYSTEM_BASELINE.md` §5 | Document as approved future boundary in `MOBILE_WBS` | Deferred | Sensor APIs, geofence radius, and battery budgets remain open |
| **D-PHONE-12** | Replicated Routine occurrences | LOCKED V1 | `mobile-offline-and-sync.md` §3.1 (table row 4), `MOBILE_SYSTEM_BASELINE.md` §5 | States Routines are "cached view only offline; autonomous execution deferred post-V1." | **CANONICAL_GAP** (presenting precomputed cached routine occurrences is authorized; autonomous local recurrence extension remains deferred; does not conflict with Host authority) | **REFINE / PROMOTE** | `mobile-offline-and-sync.md` §3.1, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add Routine occurrence replication task to `MOB-SCHED` | MG11 | Max cached occurrences count remains open |
| **D-PHONE-12A** | Routine presentation enrichment | LOCKED V1 | `tasks-reminders-alarms-and-routines.md` §2.7 | Notes LLM enrichment on PC; lacks Mobile local AI / TTS personalization and mandatory deterministic fallback. | **CANONICAL_GAP** (partially agrees; mobile local AI/TTS enrichment and fallback unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §3.2, `tasks-reminders-alarms-and-routines.md` §2.7 | Add Routine enrichment adapter to `MOB-SCHED` | MG11 | Template strings and fallback phrases remain open |
| **D-PHONE-12B** | Routine authoring authority | LOCKED V1 | `tasks-reminders-alarms-and-routines.md` §2.7, `mobile-offline-and-sync.md` §3.1 | Agrees Routine authoring is Risk 2 and PC-managed; connected Mobile management via Host APIs not explicitly specified. | **CANONICAL_GAP** (partially agrees; connected management via Host APIs unformalized) | **REFINE** | `tasks-reminders-alarms-and-routines.md` §2.7, `MOBILE_SYSTEM_BASELINE.md` §5 | Add connected Routine management note to `MOB-SCHED` | MG11 | Mobile Routine configuration UI remains open |
| **D-PHONE-12C** | Local Routine suppression | LOCKED V1 | None | Not documented in current Mobile architecture. | **CANONICAL_GAP** (new capability; local suppression toggle unformalized) | **PROMOTE** | `mobile-offline-and-sync.md` §3.1, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add local suppression toggle to `MOB-SCHED` | MG11 | Storage format of suppression state remains open |
| **D-PHONE-12D** | Companion check-in surfaces | LOCKED V1 | None (only prototype `HealthScreen`/`Dashboard` exists) | No canonical check-in surfaces, widget priority waterfall, or Android home-screen widget architecture documented. | **CANONICAL_GAP** (new capability; check-in cards and widget waterfall unformalized) | **PROMOTE** | `MOBILE_SYSTEM_BASELINE.md` §5, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add check-in cards and widget stream to `MOB-FOUNDATION` | MG11 | Android Glance / AppWidget implementation details remain open |
| **D-PHONE-12E** | Character-aware check-in tone | LOCKED V1 | `characters-personality-and-emotion.md` §2.1.4, §2.1.5 | Presets defined (Tsundere, Yandere, etc.); lacks explicit rule that strong presets like Yandere remain socially expressive without altering facts or truth. | **CANONICAL_GAP** (partially agrees; social expressiveness vs factual truth guardrail unformalized) | **REFINE** | `characters-personality-and-emotion.md` §2.1.4, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add persona safety guardrails to check-in prompts | MG8, MG11 | Specific check-in dialogue templates remain open |
| **D-PHONE-13** | Standalone Mobile Tool Gateway | LOCKED V1 | `tool-permissions-and-actions.md` §2.1, `MOBILE_SYSTEM_BASELINE.md` §2 | PC has D9 tool pipeline; Mobile has no standalone Tool Gateway documented for offline/local model execution. | **CANONICAL_GAP** (standalone Mobile Tool Gateway for local models is absent in current mobile specs; not explicitly prohibited) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2, `tool-permissions-and-actions.md` §2.1 | Add Mobile Tool Gateway stream or work items to `MOB-INFER` | MG12 | Tool dispatcher plumbing and JSON schema parsers remain open |
| **D-PHONE-13A** | Local productivity tools | LOCKED V1 | `tool-permissions-and-actions.md` §2.3 | PC defines Risk 1 productivity actions; Mobile lacks local typed tool adapters for local model invocation. | **CANONICAL_GAP** (new mobile adapter; local typed tool adapters unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2, `tool-permissions-and-actions.md` §2.3 | Add local tool adapters (Tasks, Reminders, Alarms) | MG12 | Dart method channel signatures remain open |
| **D-PHONE-13B** | Read-only internet tools | LOCKED V1 | `web-current-information.md` §2.1, §2.2 | PC defines WebSearch, WebFetch, Weather; Mobile offline/sync specs do not grant standalone Mobile access to these adapters. | **CANONICAL_GAP** (partially agrees; mobile standalone read-only web adapters unformalized) | **PROMOTE** | `web-current-information.md` §2.1, `mobile-capabilities-and-runtime.md` §2 | Add mobile read-only web adapters to `MOB-INFER` / `MOB-DATA` | MG12 | Mobile HTTP client and SSRF guardrails on device remain open |
| **D-PHONE-13C** | Internet is not Cloud AI | LOCKED V1 | `MOBILE_SYSTEM_BASELINE.md` §5.1, `mobile-capabilities-and-runtime.md` §2.1 | Partially noted, but internet presence is frequently conflated with cloud mode. | **CANONICAL_GAP** (partially agrees; architectural decoupling of internet vs cloud AI unformalized) | **REFINE** | `MOBILE_SYSTEM_BASELINE.md` §5.1, `mobile-capabilities-and-runtime.md` §2.1 | Clarify in network state machine | MG4, MG12 | None |
| **D-PHONE-13D** | Local Companion read tools | LOCKED V1 | `tool-permissions-and-actions.md` §2.3 | PC defines Risk 0 reads; Mobile lacks local adapters for cached Memory, history, Character, device status. | **CANONICAL_GAP** (new mobile adapter; local read adapters unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2, `tool-permissions-and-actions.md` §2.3 | Add local read tool adapters to `MOB-INFER` | MG12 | Local read API schemas remain open |
| **D-PHONE-13E** | Explicitly excluded authority | LOCKED V1 / REJ | `tool-permissions-and-actions.md` §2.4, `MOBILE_SYSTEM_BASELINE.md` §2 | Fully agrees: arbitrary shell, raw filesystem, credential access, PC admin, network reconfiguration are strictly REJECTED. | **NONE** (fully agrees) | **PRESERVE** | `tool-permissions-and-actions.md` §2.4, `MOBILE_SYSTEM_BASELINE.md` §2 | Retain non-goal in `MOB-SECURITY` | MG2, MG12 | None |
| **D-PHONE-13F** | Tool capability qualification | LOCKED V1 | `tool-permissions-and-actions.md` §2.7 | Agrees: success is claimed only after confirmed execution. Needs explicit qualification for mobile models attempting tool calls. | **CANONICAL_GAP** (partially agrees; evidence qualification for mobile tool models unformalized) | **REFINE** | `tool-permissions-and-actions.md` §2.7, `mobile-capabilities-and-runtime.md` §2.2 | Add tool qualification criteria to model evaluation | MG12, MG14 | Benchmark test suite for tool JSON syntax remains open |
| **D-PHONE-14** | Composable Mobile Voice | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.2 | Agrees: STT, LLM, TTS are 3 independent routes (Local, Host, Cloud). | **NONE** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §3.2, `voice-and-audio.md` §2.1 | Retain decoupled voice stream `MOB-VOICE` | MG13 | Audio routing state machine remains open |
| **D-PHONE-14A** | Connected Mobile Voice | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.1, §3.2.2 | Fully agrees: Phone owns mic, playback, audio focus; PC owns STT/LLM/TTS/VAD over WebSocket; barge-in mandatory. | **NONE** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §3.1, §3.2.2 | Retain `MOB-VOICE-001`, `MOB-VOICE-002`, `MOB-VOICE-003` | MG13 | WebSocket binary frame format remains open |
| **D-PHONE-14B** | Local TTS | CONDITIONAL V1 | `mobile-capabilities-and-runtime.md` §3.2.3 | Fully agrees: device-local TTS operates independently of STT/LLM; vocalizes alerts/check-ins; engine-independent. | **NONE** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §3.2.3 | Retain MOB-VOICE-005 (device-local TTS adapter) | MG13 | Candidate selection (Kokoro vs Kitten vs native) remains open |
| **D-PHONE-14C** | Local STT | CONDITIONAL V1 | `mobile-capabilities-and-runtime.md` §3.2.3 | Current doc states: "continuous heavy local STT deferred in V1." Ledger clarifies: local STT is supported if qualification passes for PTT/tap-to-speak. | **CANONICAL_GAP** (partially agrees; clarifies conditional PTT/tap-to-speak scope) | **REFINE** | `mobile-capabilities-and-runtime.md` §3.2.3, `voice-and-audio.md` §2.1 | Update MOB-VOICE-006 (device-local STT adapter) to include conditional local STT (PTT/tap-to-speak) | MG13 | Exact STT engine and vocabulary model remain open |
| **D-PHONE-14D** | Full offline Voice | CONDITIONAL V1 | `mobile-capabilities-and-runtime.md` §3.2.3 | Notes full offline conversational voice is independently gated; ledger explicitly defines conditional V1 status when all 3 qualify. | **CANONICAL_GAP** (partially agrees; conditional V1 status when all 3 routes qualify unformalized) | **REFINE** | `mobile-capabilities-and-runtime.md` §3.2.3 | Add full offline voice integration task to `MOB-VOICE` | MG13 | Thermal and battery limits for concurrent audio+LLM remain open |
| **D-PHONE-14E** | Voice route selection | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.2 | Agrees on routes; lacks explicit `Auto` route selection logic and visible route indicator. | **CANONICAL_GAP** (partially agrees; Auto route selection logic and visible indicator unformalized) | **REFINE** | `mobile-capabilities-and-runtime.md` §3.2 | Add route selection logic to `MOB-VOICE` | MG13 | Route switching hysteresis remains open |
| **D-PHONE-14F** | Explicit Voice session lifecycle | LOCKED V1 | `mobile-capabilities-and-runtime.md` §3.4 | Fully agrees: no background eavesdropping; starts via visible UI; active session may continue under FGS across screen-lock with notification. | **NONE** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §3.4 | Retain MOB-VOICE-004 (Voice Foreground Service lifecycle) | MG13 | Notification channel and action layout remain open |
| **D-PHONE-14G** | Shared STT candidate qualification (Whisper.cpp) | RESEARCH / DIR | `voice-and-audio.md` §2.1, `mobile-capabilities-and-runtime.md` §3.2 | `whisper.cpp` is PC candidate; not previously mandated as first Mobile STT research candidate. | **CANONICAL_GAP** (research addition; whisper.cpp candidate evaluation unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §3.2, `voice-and-audio.md` §2.8 | Add Whisper.cpp mobile benchmark task | MG13 | Exact quantization and multilingual models remain open |
| **Voice Invariants** | Barge-in, D9 parity, ephemeral audio | LOCKED SHARED | `voice-and-audio.md` §2.3, §2.5, §2.7, `mobile-capabilities-and-runtime.md` §3.3, §3.5 | Fully agrees: mandatory barge-in, D9 parity, transient raw audio, voice != authentication, separate cloud permissions, no wake word in V1. | **NONE** (fully agrees) | **PRESERVE** | `voice-and-audio.md` §2, `mobile-capabilities-and-runtime.md` §3 | Retain throughout `MOB-VOICE` | MG13 | None |
| **D-PHONE-15** | Health Connect conditional Mobile V1 | CONDITIONAL V1 | `health-and-wearables.md` §2.1, `mobile-capabilities-and-runtime.md` §4.1, `MOBILE_SYSTEM_BASELINE.md` §5 | Explicitly states: "Health & Wearables: [MOBILE LATER] (Deferred Post-V1); Real Health Connect excluded from Mobile V1." | **CANONICAL_CONFLICT** (normative conflict: canonical doc marks Health Connect as deferred post-V1; ledger restores Health Connect to conditional read-only Mobile V1) | **SUPERSEDE** | `health-and-wearables.md` §2, `mobile-capabilities-and-runtime.md` §4, `MOBILE_SYSTEM_BASELINE.md` §5 | Add dedicated `MOB-HEALTH` stream to `MOBILE_WBS` (was excluded) | MG15 (new) | Ingestion frequency, retention period, baseline algorithm remain open |
| **D-PHONE-15A** | Granular metric authorization | LOCKED V1 | `health-and-wearables.md` §2.2 | Mentions candidate granular consent; now promoted to locked V1 requirement with candidate metric categories. | **CANONICAL_GAP** (promoted from candidate; granular metric permission categories unformalized) | **PROMOTE** | `health-and-wearables.md` §2.2 | Add granular health permission UI to `MOB-HEALTH` | MG15 | Exact Android Health Connect permission strings remain open |
| **D-PHONE-15B** | Read-only Health ingestion | LOCKED V1 | `health-and-wearables.md` §3.2 | Current doc notes zero real code; ledger locks V1 scope as strictly read-only ingestion (no write-back). | **CANONICAL_GAP** (scope clarification; read-only boundary unformalized) | **PROMOTE** | `health-and-wearables.md` §2.1 | Add read-only ingestion adapter to `MOB-HEALTH` | MG15 | Health record reading queries remain open |
| **D-PHONE-15C** | Health is separate from Memory | LOCKED SHARED | None (conceptually new boundary) | Current docs do not explicitly state that Health context is distinct from D7 Memory. | **CANONICAL_GAP** (new architectural boundary rule) | **PROMOTE** | `health-and-wearables.md` §2.2, `memory-and-personalization.md` §2.3 | Add health context boundary check to memory extractor | MG15, MG7 | None |
| **D-PHONE-15D** | Shared PC/Mobile Health context | LOCKED V1 dir | `health-and-wearables.md` §6 | Mentioned as candidate; ledger locks shared normalized contract between PC and Mobile. | **CANONICAL_GAP** (promoted from candidate; normalized DTO contract unformalized) | **PROMOTE** | `health-and-wearables.md` §2, `MOBILE_SYSTEM_BASELINE.md` §3 | Add shared Health DTOs to shared Flutter contracts | MG15 | Exact JSON schema and protobuf/drift types remain open |
| **D-PHONE-15E** | Health Connect aggregation boundary | LOCKED V1 | None | Does not address Health Connect vs direct vendor wearable adapters. Ledger establishes Health Connect as preferred boundary. | **CANONICAL_GAP** (new architectural policy) | **PROMOTE** | `health-and-wearables.md` §2 | Set vendor SDKs as non-goals in `MOB-HEALTH` | MG15 | None |
| **D-SHARED-HEALTH-01** | Unified Health Context | LOCKED SHARED | `health-and-wearables.md` §5 | Previously OPEN DESIGN; now locked: preserves source, measurement time, freshness, provenance; sync bounded useful data. | **CANONICAL_GAP** (promoted from open design; unified sync contract unformalized) | **PROMOTE** | `health-and-wearables.md` §2 | Add Health sync protocol to `MOB-SYNC` | MG15 | Sync cadence and maximum historical window remain open |
| **D-SHARED-HEALTH-02** | Non-clinical wellness awareness | LOCKED SHARED | `health-and-wearables.md` §2.2, `mobile-capabilities-and-runtime.md` §4.1.2 | Fully agrees: absolute non-clinical boundary; no diagnosis, prescription, medical certainty, or emergency detection. | **NONE** (fully agrees) | **PRESERVE** | `health-and-wearables.md` §2.2, `mobile-capabilities-and-runtime.md` §4.1.2 | Retain non-clinical guardrails across prompts | MG15 | Conversational wellness prompts remain open |
| **D-SHARED-HEALTH-03** | Health-aware check-ins | LOCKED SHARED | None | Check-ins currently do not reference health context. | **CANONICAL_GAP** (new capability; health context injection into check-ins unformalized) | **PROMOTE** | `health-and-wearables.md` §2, `tasks-reminders-alarms-and-routines.md` §2.1.4 | Add health context injection to Routine check-ins | MG11, MG15 | Prompt injection format remains open |
| **D-SHARED-HEALTH-04** | Health egress isolation | LOCKED SHARED | `health-and-wearables.md` §6 | Fully agrees: Cloud LLM permission does NOT authorize Health egress; separate explicit authorization required. | **NONE** (fully agrees) | **PRESERVE** | `health-and-wearables.md` §6 | Add health redaction filter to cloud LLM client | MG15 | Redaction policy and warning modal remain open |
| **D-PHONE-16** | Conditional local Vision in Mobile V1 | CONDITIONAL V1 | `mobile-offline-and-sync.md` §3.1 (row 10), `mobile-capabilities-and-runtime.md` §9, `MOBILE_SYSTEM_BASELINE.md` §7 | Explicitly states: "Local VLM inference excluded from Mobile V1... future local vision inference remains unscheduled post-V1 candidate." | **CANONICAL_CONFLICT** (normative conflict: canonical doc marks local VLM as unscheduled post-V1 candidate; ledger promotes qualified local still-image Vision to conditional Mobile V1) | **SUPERSEDE** | `mobile-capabilities-and-runtime.md` §2, `multimodal-and-media.md` §2.2, `MOBILE_SYSTEM_BASELINE.md` §5 | Add dedicated `MOB-VISION` stream or expand `MOB-INFER` in WBS | MG16 (new) | Minimum VLM RAM headroom and quantization format remain open |
| **D-PHONE-16A** | Camera-to-attachment | LOCKED V1 | `multimodal-and-media.md` §2.3, §3.1 | PC has attachment pipeline; Mobile camera capture is an input adapter feeding that exact shared attachment contract. | **CANONICAL_GAP** (partially agrees; mobile camera adapter feeding attachment pipeline unformalized) | **PROMOTE** | `multimodal-and-media.md` §2.3, `mobile-capabilities-and-runtime.md` §2 | Add camera/gallery capture adapter to `MOB-CONV` | MG16 | Native camera plugin (image_picker / camera) remains open |
| **D-PHONE-16B** | Multimodal route selection | LOCKED V1 | `multimodal-and-media.md` §3.3 | Describes PC local vs cloud; ledger establishes Mobile routing: Host local, Mobile local VLM, authorized Cloud, or unavailable. | **CANONICAL_GAP** (partially agrees; mobile vision routing waterfall unformalized) | **PROMOTE** | `multimodal-and-media.md` §2.3, `mobile-capabilities-and-runtime.md` §2 | Add vision routing logic to `MOB-CONV` / `MOB-INFER` | MG16 | Route selection fallback delays remain open |
| **D-PHONE-16C** | Vision qualification | LOCKED V1 | `runtime-and-models.md` §2.5 | General capability checks mentioned; ledger mandates evidence qualification for vision, noting hallucination risks from 0.8B tests. | **CANONICAL_GAP** (partially agrees; evidence qualification for mobile vision unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2.2, `multimodal-and-media.md` §2.2 | Add vision qualification test suite to `MOB-VERIFY` | MG16 | Benchmark vision dataset remains open |
| **D-PHONE-16D** | Offline multimodal persistence | LOCKED V1 | `mobile-offline-and-sync.md` §2.1, §3.2.6 | Mentions media upload on turn; ledger mandates offline image turns, attachments, and local responses persist durably and sync without Host LLM regeneration. | **CANONICAL_GAP** (partially agrees; offline image outbox persistence without regeneration unformalized) | **REFINE** | `mobile-offline-and-sync.md` §2.1, §3.2.6 | Ensure image attachments in local outbox sync cleanly | MG16 | Attachment binary cache pruning limits remain open |
| **D-PHONE-16E** | Explicit-capture V1 boundary | LOCKED V1 | `multimodal-and-media.md` §2.2 | Fully agrees: V1 is bounded user-initiated still capture. Continuous background camera, ambient sensing, surveillance, live AR camera excluded. | **NONE** (fully agrees) | **PRESERVE** | `multimodal-and-media.md` §2.2, `mobile-capabilities-and-runtime.md` §5 | Retain explicit camera non-goals in WBS | MG16 | None |
| **D-SHARED-VISION-01** | Vision does not automatically create Memory | LOCKED SHARED | None (conceptually new boundary) | Not explicitly stated in current vision or memory specs. | **CANONICAL_GAP** (new architectural boundary rule) | **PROMOTE** | `multimodal-and-media.md` §2.3, `memory-and-personalization.md` §2.3 | Add rule to vision and memory orchestrators | MG16, MG7 | None |
| **P-SHARED-PRESENCE-01** | Embodied Companion Presence | FUTURE / DIR | `characters-personality-and-emotion.md` §2.1.8 | Agrees: Advanced Presence (Live2D, VRM, 3D, sensors) is PC Later / Future. | **NONE** (fully agrees) | **PRESERVE** | `characters-personality-and-emotion.md` §2.1.8 | Retain as future non-goal in `MOBILE_WBS` | Deferred | Render engine and asset formats remain open |
| **P-PHONE-AR-01** | Mobile AR Companion Presence | FUTURE / DIR | None | AR presence not mentioned in current canonical mobile docs. | **CANONICAL_GAP** (future capability; documented as approved future boundary) | **DEFER** | `mobile-capabilities-and-runtime.md` §4, `MOBILE_SYSTEM_BASELINE.md` §5 | Document as approved future boundary in `MOBILE_WBS` | Deferred | ARCore SDK evaluation remains open |
| **P-PHONE-AR-02** | Bounded scene awareness | FUTURE / DIR | None | AR scene understanding not mentioned in current docs. | **CANONICAL_GAP** (future capability; documented as approved future boundary) | **DEFER** | `mobile-capabilities-and-runtime.md` §4 | Document as approved future boundary in `MOBILE_WBS` | Deferred | Scene understanding pipeline remains open |
| **P-PRESENCE-02** | Remote expression asset discovery | EXPERIMENTAL LATER | None | Not mentioned in current docs. Guaranteed V1 fallback is emoji. | **CANONICAL_GAP** (experimental later; documented as deferred non-goal) | **DEFER** | `characters-personality-and-emotion.md` §2.1.8 | Retain emoji fallback in V1 | Deferred | Search API and media sanitizer remain open |
| **D-PHONE-UX-01** | Companion-centered Mobile shell | LOCKED V1 | `android-companion.md` §1.1 | Prototype currently uses `Home / Tasks / Assistant / Health / More`. Ledger locks: `Home / Schedule / COMPANION / Activity / More`. | **PROTOTYPE_DIFFERENCE** (exploratory Kotlin prototype navigation differs; canonical specs lacked explicit mobile nav shell) | **PROMOTE** | `MOBILE_SYSTEM_BASELINE.md` §3, `docs/05_Design/<Mobile design specification path TBD during D4>` | Update `MOB-FOUNDATION-005` with locked 5-tab structure | MG17 (new) | Exact tab bar styling and animation remain open |
| **D-PHONE-UX-01A** | Icon-first navigation | LOCKED V1 | None | Not documented in canonical specs. Requires accessibility semantics. | **CANONICAL_GAP** (new design specification) | **PROMOTE** | `docs/05_Design/<Mobile design specification path TBD during D4>` | Add icon-first nav with a11y labels to `MOB-FOUNDATION-005` | MG17 | Icon SVG assets remain open |
| **D-PHONE-UX-02** | Contextual Companion Home | LOCKED V1 | None | Home dashboard is currently an enterprise/prototype list. Ledger defines contextual prioritized companion surface. | **CANONICAL_GAP** (new design specification) | **PROMOTE** | `docs/05_Design/<Mobile design specification path TBD during D4>` | Add contextual Home screen to `MOB-FOUNDATION-005` | MG17 | Home card layout and prioritization logic remain open |
| **D-PHONE-UX-03** | Unified Companion interaction surface | LOCKED V1 | None | Text, voice, and media currently exist across separate screens in prototype. Ledger unifies them into single surface. | **CANONICAL_GAP** (new design specification) | **PROMOTE** | `docs/05_Design/<Mobile design specification path TBD during D4>`, `assistant-and-conversations.md` §2 | Add unified conversation view to `MOB-CONV` | MG6, MG17 | Unified composer layout remains open |
| **D-PHONE-UX-04** | Unified Schedule experience | LOCKED V1 | None | Tasks and Reminders/Alarms currently separate. Ledger unifies Tasks, Reminders, Alarms, Routines under Schedule. | **CANONICAL_GAP** (new design specification) | **PROMOTE** | `docs/05_Design/<Mobile design specification path TBD during D4>`, `tasks-reminders-alarms-and-routines.md` §2 | Add unified Schedule screen to `MOB-SCHED` | MG9, MG17 | Calendar vs list view switching remains open |
| **D-PHONE-UX-05** | Activity & reconciliation inbox | LOCKED V1 | None | No activity/reconciliation inbox exists in prototype or canonical specs. | **CANONICAL_GAP** (new design specification) | **PROMOTE** | `docs/05_Design/<Mobile design specification path TBD during D4>`, `mobile-offline-and-sync.md` §3 | Add Activity screen to `MOB-SYNC` / `MOB-FOUNDATION` | MG5, MG17 | Item retention and dismissal gestures remain open |
| **D-PHONE-UX-06** | Truthful capability status | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.1.1 (truthful degradation) | General principle stated; lacks compact normal-state indicator with drill-down sheet. | **CANONICAL_GAP** (partially agrees; compact indicator and drill-down sheet unformalized) | **PROMOTE** | `docs/05_Design/<Mobile design specification path TBD during D4>`, `mobile-capabilities-and-runtime.md` §2.1.1 | Add status indicator and drill-down sheet to UI shell | MG17 | Indicator iconography and badge layout remain open |
| **D-PHONE-UX-07** | Graceful standalone UX | LOCKED V1 | `mobile-capabilities-and-runtime.md` §2.1.1 | Agrees Host loss is a capability transition, not app failure; UI must reflect this gracefully. | **CANONICAL_GAP** (partially agrees; standalone UI interaction guidelines unformalized) | **REFINE** | `mobile-capabilities-and-runtime.md` §2.1.1 | Ensure offline banner does not lock standalone UI | MG4, MG17 | Visual transition animations remain open |
| **D-PHONE-UX-08** | Hybrid Mobile visual language | LOCKED V1 | `MOBILE_WBS.md` `MOB-FOUNDATION-003` | WBS mentions "theme tokens (SoftGlass)". Ledger locks: Minimalist foundation + selective Neumorphism + Glass/Liquid Glass + OLED default. | **PLANNING_STALE** (stale WBS theme token wording; ledger locks hybrid visual language across minimalist, neumorphism, and glass) | **REFINE / SUPERSEDE** | `docs/05_Design/<Mobile design specification path TBD during D4>`, `MOBILE_WBS.md` | Update design tokens in `MOB-FOUNDATION-003` | MG17 | Exact blur radiuses, shadow offsets, and palette remain open |
| **D-PHONE-UX-09** | Companion language vs UI language | LOCKED V1 | `assistant-and-conversations.md` §2.3 | Agrees: conversational language capability is separate from full app UI localization. | **NONE** (fully agrees) | **PRESERVE** | `assistant-and-conversations.md` §2.3, `docs/05_Design/<Mobile design specification path TBD during D4>` | Retain separation in settings UI | MG17 | Flutter `flutter_localizations` setup remains open |
| **D-PHONE-UX-10** | Lightweight Mood Presence | LOCKED V1 | `characters-personality-and-emotion.md` §2.1.8 | Notes presence is future; ledger establishes emoji as guaranteed lightweight V1 Mood/Presence fallback. | **CANONICAL_GAP** (promoted lightweight V1; emoji mood renderer unformalized) | **PROMOTE** | `characters-personality-and-emotion.md` §2.1.5, `docs/05_Design/<Mobile design specification path TBD during D4>` | Add emoji mood glyph renderer to `MOB-FOUNDATION` | MG8, MG17 | Emoji set mapping and animation curves remain open |
| **D-SHARED-LANG-01** | Extensible language registry | LOCKED SHARED | `assistant-and-conversations.md` §2.3 | Prototype used fixed enum (`Language.kt`); canonical text references English, Tagalog, Japanese. Ledger requires extensible registry. | **CANONICAL_GAP** (partially agrees; extensible registry architecture unformalized) | **PROMOTE** | `assistant-and-conversations.md` §2.3, `SYSTEM_BASELINE.md` §3 | Add extensible language registry to shared packages | MG17 | ISO language/locale code structures remain open |
| **D-SHARED-LANG-02** | Qualified language capability | LOCKED SHARED | `assistant-and-conversations.md` §2.3 | Agrees: language support bounded by model capabilities; Auto supports natural code-switching where qualified. | **NONE** (fully agrees) | **PRESERVE** | `assistant-and-conversations.md` §2.3 | Retain model qualification criteria for multilingual | MG17 | Code-switching detection benchmarks remain open |
| **D-SHARED-FLUTTER-01** | Shared workspace, separate apps | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0004` | Fully agrees: single shared Flutter monorepo with separate desktop and mobile app targets. | **NONE** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0004` | Retain `MOB-FOUNDATION-001`, `MOB-FOUNDATION-002` | None | Exact folder names remain open |
| **D-SHARED-FLUTTER-02** | Share contracts, not every implementation | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Fully agrees: share stable domain models, DTOs, IDs, validation, interfaces; do not force identical implementations. | **NONE** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3 | Retain `MOB-FOUNDATION-003` | None | Package boundary partitioning remains open |
| **D-SHARED-FLUTTER-03** | Shared typed Host client | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0019` | Implied by shared contracts; ledger locks a shared typed client layer implementing REST, SSE, WS contracts. | **CANONICAL_GAP** (promoted from general principle; typed client layer unformalized) | **PROMOTE** | `MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0019` | Add shared API client package to `MOB-FOUNDATION` | MG3 | HTTP package (dio vs http) remains open |
| **D-SHARED-FLUTTER-04** | Shared repository contracts | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Fully agrees: share abstract repository contracts; implementations remain platform-specific as needed. | **NONE** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3 | Retain `MOB-FOUNDATION-004` | None | Interface signatures remain open |
| **D-SHARED-FLUTTER-05** | Platform adapter isolation | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Fully agrees: shared packages do not import Android/Windows native APIs; platform adapters isolated behind interfaces. | **NONE** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3 | Retain `MOB-FOUNDATION-004` | None | Platform channel method names remain open |
| **D-SHARED-FLUTTER-06** | Shared design primitives, platform composition | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Agrees on shared design primitives; ledger revises WBS "SoftGlass-only" wording to shared primitives with platform composition. | **PLANNING_STALE** (WBS wording refinement from SoftGlass-only to shared primitives with platform composition) | **REFINE** | `MOBILE_SYSTEM_BASELINE.md` §3, `MOBILE_WBS.md` | Revise `MOB-FOUNDATION-003` | MG17 | Design token constants remain open |
| **D-SHARED-FLUTTER-07** | Cross-language semantic parity | LOCKED SHARED | None (conceptually new engineering policy) | Shared tests implied; ledger explicitly mandates machine-readable Golden fixtures/test vectors for PC/Mobile parity. | **CANONICAL_GAP** (new verification policy; machine-readable Golden fixtures unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §7, `tasks-reminders-alarms-and-routines.md` §2.5 | Add Golden fixture generator to `MOB-CONTRACT` / `MOB-VERIFY` | MG9, MG18 | JSON fixture directory structure remains open |
| **D-SHARED-FLUTTER-08** | Shared feature core, platform presentation | LOCKED SHARED | `MOBILE_SYSTEM_BASELINE.md` §3 | Fully agrees: "One codebase" does NOT mean one giant responsive screen full of `if (isMobile)` branches. | **NONE** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md` §3 | Retain architectural guideline | None | View composition architecture remains open |
| **D-PHONE-FLUTTER-01** | Kotlin prototype as evidence only | LOCKED V1 | `android-companion.md` §1, `MOBILE_SYSTEM_BASELINE.md` §1 | Fully agrees: Kotlin/Compose `android/` is non-normative reference/migration evidence; production is Flutter. | **NONE** (fully agrees) | **PRESERVE** | `android-companion.md` §1, `MOBILE_SYSTEM_BASELINE.md` §1 | Retain legacy boundary | None | None |
| **D-MOBILE-VERIFY-01** | Product-centered Golden Gate (MG1–MG18) | LOCKED V1 | `mobile-capabilities-and-runtime.md` §8, `MOBILE_CHECKLIST.md` | Currently specifies 12 groups (MG1–MG12). Ledger expands to 18 product-centered groups (MG1–MG18). | **CANONICAL_CONFLICT** (normative conflict: current docs enforce 12 groups MG1–MG12; ledger expands to 18 groups MG1–MG18) | **SUPERSEDE** | `mobile-capabilities-and-runtime.md` §8, `MOBILE_CHECKLIST.md`, `MOBILE_WBS.md` | Expand `MOB-VERIFY-006` and add MG13–MG18 checklist rows | MG1–MG18 | Exact pass/fail assertion counts remain open |
| **D-MOBILE-VERIFY-02** | Required vs Conditional qualification | LOCKED V1 | `mobile-capabilities-and-runtime.md` §8 | Previous MG groups treated all items uniformly; ledger introduces REQUIRED, CONDITIONAL, OPTIONAL, DEFERRED classes. | **CANONICAL_GAP** (refinement; qualification categorization unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §8 | Update checklist evaluation schema | MG1–MG18 | Exact qualification test harness remains open |
| **D-MOBILE-VERIFY-03** | Integrated Companion journey | LOCKED V1 | `mobile-capabilities-and-runtime.md` §8 | Release gates tested isolated subsystems; ledger mandates MG18 full end-to-end user companion journey. | **CANONICAL_GAP** (new release gate; MG18 integrated journey unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §8 | Add MG18 integration test to `MOB-VERIFY-006` | MG18 | Scripted journey test runner remains open |
| **D-CI-01** | Flutter path-scoped verification | LOCKED DIR | `mobile-capabilities-and-runtime.md` §7.2 | Current doc states "zero changes to PC CI". Ledger defines future path-scoped classifier lanes without modifying CI yet. | **NONE** (future direction aligned) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §7.2 | Document future CI architecture | None | Path filter globs remain open |
| **D-CI-02** | Shared-package fan-out | LOCKED DIR | None | Not documented in current CI policy. | **CANONICAL_GAP** (future architecture; shared-package fan-out unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §7.2 | Document fan-out rules for shared Flutter packages | None | GitHub Actions matrix definitions remain open |
| **D-CI-03** | Tiered Mobile verification | LOCKED DIR | `mobile-capabilities-and-runtime.md` §7.1 | Fully agrees: L1 unit/domain, L2 storage/outbox, L3 emulator matrix, L4 hardware, L5 host integration. | **NONE** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §7.1 | Retain `MOB-VERIFY-001` through `MOB-VERIFY-005` | L1–L5 | Runner hardware specifications remain open |
| **D-CI-04** | Do not implement Flutter CI before Flutter exists | LOCKED DIR | `mobile-capabilities-and-runtime.md` §7.2 | Fully agrees: Batch D documents future routing; zero changes to `.github/workflows/ci.yml` until M1 creates workspace. | **NONE** (fully agrees) | **PRESERVE** | `mobile-capabilities-and-runtime.md` §7.2 | Zero edits to `.github/workflows/` enforced | None | None |
| **Gemma 3 1B** | Cross-device qualification requirement | RESEARCH | `mobile-capabilities-and-runtime.md` §2.2.2 | Mentioned as exploratory research on Infinix; ledger establishes formal qualification requirement across PC & Mobile. | **CANONICAL_GAP** (promoted research requirement; cross-device benchmark unformalized) | **PROMOTE** | `mobile-capabilities-and-runtime.md` §2.2, `runtime-and-models.md` §2.5 | Add cross-platform qualification benchmark task | MG14 | Qualification record JSON schema remains open |
| **Sec 18 (1-12)** | Explicit future/deferred boundaries | DEFERRED | Various specs | Fully agrees: wake word, ambient mic, continuous camera, AR, Live2D/VRM, remote expression scraping, direct wearable SDKs, shell, etc. are deferred/rejected. | **NONE** (fully agrees) | **PRESERVE** | `MOBILE_SYSTEM_BASELINE.md`, `MOBILE_WBS.md` | Maintain non-goal boundaries | All | None |
| **Sec 19 (1-26)** | Implementation-open items | KEEP OPEN | `DECISION_DEBT.md` | Fully agrees: exact libraries, thresholds, schemas, models, UI timings MUST remain open and not be invented prematurely. | **NONE** (fully agrees) | **KEEP OPEN** | `DECISION_DEBT.md` | Index newly identified implementation debt items | None | None |

---

## D. Explicit Canonical Contradictions (Normative Conflicts)

A strict canonical contradiction occurs only when two normative requirements cannot both remain true.
The reconciliation audit confirms **7 true canonical conflicts** between current canonical architecture and the approved Batch D decision ledger:

1. **Local LLM Framing (`D-PHONE-01`):**
   - *Current Canonical:* `MOBILE_SYSTEM_BASELINE.md` §5 & `mobile-capabilities-and-runtime.md` §2.1 classify local Mobile inference as an "optional-auxiliary capability in V1" and "NOT mandatory to run or use the Mobile Companion."
   - *Batch D Approved:* `D-PHONE-01` establishes that Mobile V1 product implementation **must include a real production-capable device-local LLM execution path for qualified devices**. While the core companion survives without local generative AI (`D-PHONE-02`), local LLM is a required production engineering path, not a mere speculative auxiliary.

2. **Coupled Operating Modes vs. Orthogonal Dimensions (`D-PHONE-01A`):**
   - *Current Canonical:* `MOBILE_SYSTEM_BASELINE.md` §5 and `mobile-offline-and-sync.md` structure capability tables around monolithic coupled modes (`CONNECTED_TO_PC`, `OFFLINE_LOCAL`, `OPTIONAL_CLOUD`), implying internet and cloud AI permissions are inextricably bound.
   - *Batch D Approved:* `D-PHONE-01A` mandates that Host reachability, internet availability, and inference routing must be modeled as **three strictly orthogonal state dimensions**. Internet availability does not imply Cloud LLM permission, and read-only internet tools can operate alongside local models while disconnected from the PC.

3. **Offline Reminder Authoring (`D-PHONE-10`):**
   - *Current Canonical:* `mobile-offline-and-sync.md` §3.1 (table row 2) restricts offline Reminders to `"LIMITED (Ack / Dismiss / Snooze only; no canonical entity creation)"`.
   - *Batch D Approved:* `D-PHONE-10` authorizes **full offline CRUD for Mobile-created Reminders** (create, edit, cancel/delete, dismiss/snooze, local scheduling/delivery), while Host-created definitions remain read-only offline.

4. **Offline Alarm Authoring (`D-PHONE-11`):**
   - *Current Canonical:* `mobile-offline-and-sync.md` §3.1 (table row 3) restricts offline Alarms to `"LIMITED (Dismiss / Snooze only; canonical recurring alarm config is PC-owned)"`.
   - *Batch D Approved:* `D-PHONE-11` authorizes **full offline creation, editing, and arming of Mobile-created Alarms**, while Host-created definitions remain read-only offline.

5. **Health Connect Release Disposition (`D-PHONE-15`):**
   - *Current Canonical:* `health-and-wearables.md` §2.1, `mobile-capabilities-and-runtime.md` §4.1, and `MOBILE_SYSTEM_BASELINE.md` §5 state Health Connect is `"Mobile Later (Deferred Post-V1)"` and completely excluded from Mobile V1.
   - *Batch D Approved:* `D-PHONE-15` **restores Health Connect to conditional, read-only, non-clinical Mobile V1**.

6. **Local Vision / VLM Release Disposition (`D-PHONE-16`):**
   - *Current Canonical:* `mobile-capabilities-and-runtime.md` §9, `mobile-offline-and-sync.md` §3.1, and `MOBILE_SYSTEM_BASELINE.md` §7 state local VLM inference is excluded from Mobile V1 and is an unscheduled `"Post-V1 Candidate"`.
   - *Batch D Approved:* `D-PHONE-16` **promotes qualified local still-image Vision to conditional Mobile V1**.

7. **Golden Acceptance Gate Structure (`D-MOBILE-VERIFY-01`):**
   - *Current Canonical:* `mobile-capabilities-and-runtime.md` §8 and `MOBILE_CHECKLIST.md` define **12 Mobile Golden Acceptance Groups (MG1–MG12)**.
   - *Batch D Approved:* `D-MOBILE-VERIFY-01` **expands the gate to 18 groups (MG1–MG18)**, covering Voice composition, model qualification, Health, Vision, Mobile UX, and the full integrated Companion journey.

### Summary Breakdown by Mismatch Classification

| Mismatch Class | Count | Description / Rationale |
| :--- | :---: | :--- |
| **`CANONICAL_CONFLICT`** | **7** | True normative contradictions between existing canonical requirements and approved Batch D decisions (`D-PHONE-01`, `01A`, `10`, `11`, `15`, `16`, `D-MOBILE-VERIFY-01`). |
| **`CANONICAL_GAP`** | **71** | Target capabilities or architectural contracts absent or unformalized in current canonical documentation, but not prohibited by a conflicting rule (e.g., standalone tool gateway, emotion outbox, memory intent outbox, pending memory overlay, routine occurrence replication, context budget manager, speech candidate evaluation). |
| **`IMPLEMENTATION_STATUS`** | **1** | Current documentation truthfully records implemented code status (`D-SHARED-AI-02`: "Conversation Compaction / Summarization: NOT IMPLEMENTED"). Target architecture is approved in Batch D to be promoted separately while preserving implementation truth. |
| **`PLANNING_STALE`** | **2** | Stale planning text in WBS/roadmaps from Batches A–C closure (`D-PHONE-UX-08` SoftGlass-only token wording, `D-SHARED-FLUTTER-06` shared token wording refinement). |
| **`PROTOTYPE_DIFFERENCE`** | **1** | Non-normative differences from exploratory Kotlin prototype (`D-PHONE-UX-01`: 5-tab shell structure). |
| **`NONE`** | **27** | Current canonical documentation already agrees with the approved decision (e.g., core survives without AI, single resident model cap, barge-in, non-clinical boundary, explicit capture only, shell non-goals, deferred presence, decision debt index). |
| **TOTAL AUDITED** | **109** | **Complete reconciliation matrix covering every ledger item without sampling.** |

### Detailed Reclassification Rationale for Formerly Flagged Items
In earlier preliminary analyses, several items were loosely described as contradictions. A rigorous audit against canonical rules confirms they are **gaps, implementation statuses, or planning drift**, not normative conflicts:
- **`D-SHARED-AI-02` (Conversation Compaction):** The statement `"Conversation Compaction / Summarization: NOT IMPLEMENTED"` in `assistant-and-conversations.md` is an accurate reflection of current code reality. Approving compaction as target architecture does not contradict this implementation fact. The target architecture will be promoted to the specification while preserving the implementation status truth.
- **`D-PHONE-08` (Offline Memory Intent):** Existing specs state `"memory database writes are DISABLED on Mobile in V1"`. Pending explicit Memory intent (`D-PHONE-08`) is an outbox/intent path (`PENDING_SYNC`) submitted to Host D7 reconciliation—it is **not** a direct canonical Memory DB write on Mobile. D7 Host authority is preserved. This is a `CANONICAL_GAP`.
- **`D-PHONE-08A` (Pending Memory Overlay):** The absence of a local pending Memory overlay in canonical specs is a `CANONICAL_GAP`, not a contradiction.
- **`D-PHONE-EMO-01` (Emotion Event Sync):** Current specs state Character is a read-only cached view offline. The Emotion Event outbox submits typed transient interaction events to the Host rather than directly mutating canonical Mood numeric state. D11 Host authority is preserved. This is a `CANONICAL_GAP`.
- **`D-PHONE-13` (Standalone Tool Gateway):** PC architecture owns a D9 tool pipeline. Mobile lacks a standalone Tool Gateway for local models; no normative rule explicitly prohibited creating one. This is a `CANONICAL_GAP`.
- **`D-PHONE-09` (Selective Offline Memory Replica):** Refines the existing read-only offline cache model with selective pinning and continuity replicas without authorizing offline canonical DB mutations. This is a `CANONICAL_GAP`.
- **`D-PHONE-12` (Replicated Routine Occurrences):** Presenting precomputed cached routine occurrences is authorized; autonomous local recurrence extension remains deferred post-V1. Conflating them is avoided. This is a `CANONICAL_GAP`.
- **`D-PHONE-UX-01` (5-Tab Shell):** Differences from the exploratory Kotlin prototype navigation represent a `PROTOTYPE_DIFFERENCE`, not a canonical contradiction.
- **`D-PHONE-UX-08` & `D-SHARED-FLUTTER-06`:** Outdated "SoftGlass-only" wording in `MOBILE_WBS.md` is `PLANNING_STALE` drift, not an architectural conflict.

---

## E. Shared-PC Compatibility Review

Batch D was audited against all frozen PC architecture rules. The "INHERIT FIRST" principle was upheld across every domain:

1. **Alignment with D7 (Profile-First Memory):**
   - *Verification:* Mobile explicit memory intent (`D-PHONE-08`) submits to D7 Host reconciliation (`NEW` / `MERGE` / `UPDATE` / `CONFLICT` / `REJECT`). Autonomous offline extraction remains disabled. Pinned offline memories (`D-PHONE-09`) are read-only replicas of D7 memories. Health context is strictly isolated from D7 Memory (`D-PHONE-15C`). Vision does not automatically create Memory (`D-SHARED-VISION-01`).
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

3. **`docs/02_Planning/00_Master/MASTER_CHECKLIST.md`:**
   - Line 6 references Mobile readiness across "acceptance groups MG1–MG12". Must be updated to MG1–MG18 during planning spine reconciliation.

4. **`docs/02_Planning/00_Master/DECISION_REGISTER.md`:**
   - Status header claims "Mobile Architecture Pass APPROVED (2026-10-04)."
   - Row 50 states local LLM is an "optional auxiliary capability in V1."
   - Row 53 states Health Connect is "Mobile Later."

5. **`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`:**
   - Lines 17, 55, 68 mark MOBILE-ARCH as `[COMPLETE / APPROVED]`.
   - Line 67 lists Health Connect, Routines, and local VLM as deferred non-goals.

6. **`docs/02_Planning/00_Master/DELIVERY_INDEX.md`:**
   - Line 38 lists MOBILE-ARCH status as `COMPLETE / APPROVED`.

7. **`docs/02_Planning/00_Master/DECISION_DEBT.md`:**
   - Lists only 10 mobile decision debt items. Needs expansion with the 26 implementation-open items from Batch D §19.

8. **`docs/06_Guides/DOCUMENTATION_MAP.md`:**
   - References the 65-item WBS and MG1–MG12.

9. **Pull Request #21 Title and Description:**
   - PR #21 remains open and is currently Draft. MOBILE-ARCH closure was reopened for Batch D product reconciliation. The PR description currently reflects Batches A–C closure and must be updated upon completion of Batch D to summarize the reconciled product architecture.

---

## G. Missing Decisions & Ambiguity Review

A rigorous audit of the supplied Batch D ledger against actual repository requirements reveals:

1. **One Profile to Multiple Mobile Devices:**
   - *Status:* Explicitly **OPEN / DECISION DEBT** (`DEBT-MOB-MULTI-DEVICE`).
   - *Details:* `D-SHARED-CONV-01` notes "One Profile -> multiple phones remains OPEN" and `D-PHONE-EMO-01` notes "multi-device ordering remains open". Mobile V1 locks the baseline at 1 Device -> 1 Profile. Multi-phone synchronization against the same Profile is an open question / decision debt to be resolved in a future architecture pass.

2. **No Missing Approved Decisions / No Additional Blocking Human Decisions:**
   - No hidden, unapproved architectural decisions were detected.
   - The ledger cleanly addresses all 98 mandatory reconciliation targets without requiring invention by the agent.

---

## H. Proposed Canonical Promotion Batches

To ensure reliable, reviewable, and non-destructive documentation promotion, the changes are partitioned into **4 coherent promotion batches**:

```text
Batch D2: Core Baseline, Governance & Scheduling
  │ (MOBILE_SYSTEM_BASELINE.md, mobile-offline-and-sync.md, tasks-reminders-alarms-and-routines.md,
  │  android-companion.md, profiles-and-devices.md)
  ▼
Batch D3: Intelligence, AI Runtime, Memory & Tools
  │ (SYSTEM_BASELINE.md, runtime-and-models.md, performance-and-capacity.md,
  │  mobile-capabilities-and-runtime.md, assistant-and-conversations.md,
  │  memory-and-personalization.md, tool-permissions-and-actions.md, web-current-information.md)
  ▼
Batch D4: Voice, Health, Vision & UX/Design
  │ (MOBILE_SYSTEM_BASELINE.md, mobile-capabilities-and-runtime.md, mobile-offline-and-sync.md,
  │  memory-and-personalization.md, assistant-and-conversations.md, voice-and-audio.md,
  │  health-and-wearables.md, multimodal-and-media.md, characters-personality-and-emotion.md,
  │  docs/05_Design/<Mobile design specification path TBD during D4>)
  ▼
Batch D5: Master Planning Spine, Golden Verification & PR #21 Handoff
    (MOBILE_WBS.md, MOBILE_CHECKLIST.md, MASTER_CHECKLIST.md, DECISION_REGISTER.md,
     SPRINT_ROADMAP.md, DELIVERY_INDEX.md, DECISION_DEBT.md, DOCUMENTATION_MAP.md,
     walkthrough-mobile-v1-batch-d-reconciliation.md, CHANGELOG.md)
```

### Batch D2 — Core Baseline, Governance & Scheduling
- **Purpose:** Update the foundational ecosystem authority, orthogonal execution states, profile/device binding lifecycle, and full offline scheduling (Tasks, Reminders, Alarms, Routines).
- **Decisions Covered:** `D-PHONE-01A`, `D-PHONE-01B`, `D-PHONE-02`, `D-SHARED-SCHED-01`, `D-PHONE-10`, `D-PHONE-11`, `D-SHARED-SCHED-02`, `D-SHARED-SCHED-03`, `D-SHARED-SCHED-04` (A–E), `D-PHONE-12` (A–C), `D-SHARED-FLUTTER-01`–`08`, `D-PHONE-FLUTTER-01`.
- **Target Files:**
  - `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
  - `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
  - `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`
  - `docs/04_Architecture/01_Domains/android-companion.md`
  - `docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`
- **Dependencies:** None (first batch).
- **Checkpoint:** Independent review of offline scheduling and sync contracts.

### Batch D3 — Intelligence, AI Runtime, Memory & Tools
- **Purpose:** Reconcile local LLM production capability, single-resident model lifecycle, Resource Governor, Context Budget Manager, compaction/branching, selective Memory replica, explicit Memory intent outbox, and Standalone Tool Gateway.
- **Decisions Covered:** `D-PHONE-01`, `D-PHONE-01C`, `D-PHONE-03`, `D-PHONE-05`, `D-PHONE-05A`, `D-SHARED-AI-01`, `D-SHARED-AI-02`, `D-SHARED-AI-03`, `D-PHONE-08`, `D-PHONE-08A`, `D-PHONE-09`, `D-SHARED-CONV-01`, `D-SHARED-CONV-02`, `D-SHARED-CONV-03`, `D-SHARED-CONV-03A`, `D-PHONE-13` (A–F), `Gemma 3 1B`.
- **Target Files:**
  - `docs/04_Architecture/SYSTEM_BASELINE.md`
  - `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`
  - `docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`
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
  - `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
  - `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`
  - `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
  - `docs/04_Architecture/01_Domains/memory-and-personalization.md`
  - `docs/04_Architecture/01_Domains/assistant-and-conversations.md`
  - `docs/04_Architecture/01_Domains/voice-and-audio.md`
  - `docs/04_Architecture/03_Integrations/health-and-wearables.md`
  - `docs/04_Architecture/01_Domains/multimodal-and-media.md`
  - `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`
  - `docs/05_Design/<Mobile design specification path TBD during D4>`
- **Dependencies:** Batch D3.
- **Checkpoint:** Independent review of Health Connect boundaries, local VLM qualification, and visual language.

### Batch D5 — Master Planning Spine, Golden Verification & PR #21 Handoff
- **Purpose:** Expand WBS (from 65 to ~85+ items), update Readiness Checklist to MG1–MG18, update Master Readiness Checklist, update Decision Register, Roadmap, Delivery Index, Decision Debt, Documentation Map, author delivery walkthrough, and prepare PR #21 handoff.
- **Decisions Covered:** `D-MOBILE-VERIFY-01`–`03`, `D-CI-01`–`04`, Sec 18 (Deferred non-goals), Sec 19 (Decision debt), Sec 20 (Contradictions resolved).
- **Target Files:**
  - `docs/02_Planning/00_Master/MOBILE_WBS.md`
  - `docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`
  - `docs/02_Planning/00_Master/MASTER_CHECKLIST.md`
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

1. **Checkpoint 1 (Batch D1.2 Final Corrections):**
   ```text
   docs(mobile): finalize Batch D reconciliation corrections
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

1. **Conflicts Found:** 7 true canonical conflicts (normative contradictions) identified between existing canonical architecture and the approved Batch D decision ledger (see Section D). 71 items classified as canonical gaps, 1 as implementation status, 2 as stale planning wording, 1 as prototype difference, and 27 as agreed.
2. **Unresolved Human Decisions:** Zero blocking architecture ambiguities found. The one-profile-to-multiple-phones question is cleanly categorized as open decision debt (`DEBT-MOB-MULTI-DEVICE`), preserving the locked V1 1-Device -> 1-Profile boundary.
3. **Safe-to-Promote Areas:** All 4 promotion batches are fully mapped, decoupled, and internally consistent with shared PC architecture.
4. **Blocked Areas:** None. No production source, test, or CI changes are required for this Batch D documentation-promotion pass. Actual implementation work remains future work under the revised WBS.
5. **Formatting & Whitespace Verification History:** The original Batch D1 local `git diff --check` did not inspect the then-untracked new report files. GitHub CI Run #67 subsequently exposed report-local trailing whitespace. Batch D1.1 removed all report-local whitespace, and whole-file trailing-whitespace scanning (`Select-String -Pattern '[ \t]+$'`) now returns zero matches across the entire file alongside clean scoped `git diff --check`. Pre-existing PR-wide Markdown whitespace defects across older canonical files remain isolated for later controlled closure cleanup (CI #67 is not claimed as passing).
6. **Exact Next Recommended Batch:** **Batch D2 — Core Baseline, Governance & Scheduling** (`MOBILE_SYSTEM_BASELINE.md`, `mobile-offline-and-sync.md`, `tasks-reminders-alarms-and-routines.md`, `android-companion.md`, `profiles-and-devices.md`), pending Chris/GPT independent review of this corrected reconciliation report.
