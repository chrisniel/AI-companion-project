# Archived Task: MOBILE-ARCH Batch D Canonical Promotion

> **Branch:** `docs/mobile-v1-canonicalization`
> **Delivery:** MOBILE-ARCH Batch D Canonical Promotion
> **Status:** CLOSED / VERIFIED (Independent Closure Gate Passed)
> **Archival Date:** 2026-10-07
> **Approved Plan:** `docs/02_Planning/01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md`
> **Gate 0 Approved Checkpoint:** `2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`
> **Gate 1 Passed Checkpoint:** `19116d9965e369e2869fbdf1a4d0702ccd730077`
> **Gate 2 Passed Checkpoint:** `5d860625510ffae0437cc9c58662dfe087c3fad9`
> **Gate 3 Passed Checkpoint:** `ed1c71b7245324072c4b48dc7a9596c71d717e11`
> **Gate 4 Closure Gate Passed Checkpoint:** `282f3607c6663cb72b34ad8f3596651aaf5ac18f`
> **Closure CI:** PR #21 CI Run #84 — SUCCESS
> **PR Handoff:** PR #21 — merge pending at archival checkpoint
> **M1 Status:** PENDING / SEQUENCED AFTER MERGE

---

## 1. Governance & Delivery Sequence

- **Git Authority:** Strictly read-only for AI agents. Chris is the sole owner of all Git mutations.
- **Delivery Lifecycle Stage:** CLOSURE GATE PASSED — Final closure bookkeeping complete and active tracker archived.
- **Historical CI Blocker (Resolved):** PR-wide Markdown trailing whitespace was mechanically cleaned in commit `6ece11c8` and verified clean in PR #21 CI (Run #84 green docs-integrity check; `git diff --check` passes with exit code 0).

### Delivery Stages & Batch Sequence

| Batch / Stage | Scope | Status | Independent Gate |
| :--- | :--- | :--- | :--- |
| **D1 Research** | Approved Decision Ledger, Reconciliation Report, Benchmark Evidence | COMPLETED | Gate 0 Passed |
| **Plan Authoring** | Batch D Canonical Promotion Plan | APPROVED | Gate 0 Passed (`2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`) |
| **Batch D2** | Core Baseline, Identity, Scheduling & Flutter Boundaries | **APPROVED** | Gate 1 Passed (`19116d9965e369e2869fbdf1a4d0702ccd730077`) |
| **Batch D3** | AI Runtime, Conversations, Context, Memory & Tools | **APPROVED** | Gate 2 Passed (`5d860625510ffae0437cc9c58662dfe087c3fad9`) |
| **Batch D4** | Voice, Health, Vision, Character/Presence & Mobile UX | **APPROVED** | Gate 3 Passed (`ed1c71b7245324072c4b48dc7a9596c71d717e11`) |
| **Batch D5** | Master Planning Spine, Golden Verification, CI & PR Handoff | **APPROVED** | Gate 4 Closure Gate Passed (`282f3607c6663cb72b34ad8f3596651aaf5ac18f`) |
| **Closure & Archival** | Final closure bookkeeping, active tracker archival, and PR #21 handoff | **CLOSED / VERIFIED** | Closure Gate Passed |

---

## 2. D1 Completed Research Evidence Baseline

- [x] **Approved Working Decision Ledger:** `docs/00_Drafts/research/mobile/MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md` (Authoritative approved working decision source for Batch D reconciliation).
- [x] **Audited Reconciliation Report:** `docs/00_Drafts/research/mobile/MOBILE_ARCH_BATCH_D_RECONCILIATION_REPORT.md` (Detailed mapping against repository canonical truth; 71 canonical gaps and 7 canonical conflicts identified/mapped).
- [x] **Sanitized Benchmark Evidence:** `docs/00_Drafts/research/mobile/benchmarks/MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md` (Non-canonical empirical qualification research).
- [x] **Approved Implementation Plan:** `docs/02_Planning/01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md` (Status: `Approved` at checkpoint `2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`).

---

## 3. Completed Work: Batch D2 Core Baseline, Identity & Scheduling

- [x] `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`: 3 orthogonal availability axes (`D-PHONE-01A`), enrollment lifecycle (`D-PHONE-01B`), 1-device to 1-profile binding (`D-PHONE-01B`), core survival without generative AI (`D-PHONE-02`), Flutter shared workspace boundaries (`D-SHARED-FLUTTER-01` to `08`, `D-PHONE-FLUTTER-01`).
- [x] `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`: Stable client UUIDs, base-revision optimistic concurrency, typed `CONFLICT_DETECTED`, no universal server-wins, no timestamp LWW.
- [x] `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`: Synchronized scheduling authority, offline Mobile Reminders/Alarms, protected Host definitions (`D-PHONE-10`, `11`), Companion Alert Enrichment (`D-SHARED-SCHED-03`), cross-device alert arbitration (`D-SHARED-SCHED-02`), bounded Routine occurrence caching and local suppression/disable mutation (`D-PHONE-12` to `12C`), temporal intent resolution (`D-SHARED-SCHED-04` to `04E`).
- [x] `docs/04_Architecture/01_Domains/android-companion.md`: Android platform adapter boundary under Flutter (exact-alarm capability/permission lifecycle including `canScheduleExactAlarms()`, Keystore, lifecycle, Doze); demoting `android/` Kotlin code to reference prototype evidence only.
- [x] `docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`: 1-device to 1-profile binding, PC Host Admin ownership, One Profile → Multiple Phones as OPEN / DECISION DEBT, platform credential protection.

---

## 4. Completed Work: Batch D3 AI Runtime, Conversations, Context, Memory & Tools

**Objective:** Promote device-local generative LLM production path for qualified devices, replaceable local model architecture, model and resource lifecycle states, progressive resource governance, evidence-driven qualification, shared context budget management, transcript authority and compaction reality, unified context retrieval, offline memory intent outbox, pending memory overlay, causal conversation branching, turn control, safe regeneration, and the Standalone Mobile Tool Gateway with deterministic confirmation.

### Targeted Canonical Files & Responsibilities

- [x] `docs/04_Architecture/SYSTEM_BASELINE.md`: Production-capable device-local LLM path on qualified devices (`D-PHONE-01`, `D-PHONE-03`), core companion survival without generative AI (`D-PHONE-02`), PC Host master runtime authority.
- [x] `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`: Four-way component separation (`D-PHONE-03`), mobile model lifecycle states (`installed`, `loaded / resident`, `active`, `unloaded`, `removed`) with max 1 resident generative LLM cap (`D-PHONE-05`), replaceable local model architecture (`D-PHONE-01C`), vendor-neutral execution with CPU broad fallback (`D-PHONE-03`), non-binding research candidates (Gemma 3 1B).
- [x] `docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`: Progressive Resource Governor (`D-PHONE-05A`), evidence-driven qualification without fixed RAM floor, truthful OOM and process death architecture.
- [x] `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`: Updated capability matrix reflecting local LLM production path (`D-PHONE-01`, `D-PHONE-03`), reference device sanitization ("Reference Android Device A: Android 13, ARM64, 8 GB physical RAM, mid-range mobile SoC class"), empirical research role of benchmark data.
- [x] `docs/04_Architecture/01_Domains/assistant-and-conversations.md`: Shared Context / Generation / Reasoning Budget Manager (`D-SHARED-AI-01`), raw conversation transcript authority and compaction truth (`D-SHARED-AI-02`), Host-mediated live turn streaming (`D-SHARED-CONV-02`), causal conversation branching without timestamp LWW (`D-SHARED-CONV-01`), active turn control (`D-SHARED-CONV-03`), safe regeneration without tool replay (`D-SHARED-CONV-03A`).
- [x] `docs/04_Architecture/01_Domains/memory-and-personalization.md`: Unified Context Retrieval across distinct sources (`D-SHARED-AI-03`), selective offline Memory replica (`D-PHONE-09`), offline explicit Memory intent outbox (`D-PHONE-08`), pending Memory overlay (`D-PHONE-08A`), PC Host D7 Memory engine authority.
- [x] `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`: Standalone Mobile Tool Gateway under Decision D9 (`D-PHONE-13`), approved tool scope (`D-PHONE-13A`, `13B`, `13D`), explicitly prohibited tools (`D-PHONE-13E`), tool capability qualification and deterministic confirmation (`D-PHONE-13F`), committed side-effect replay prohibition.
- [x] `docs/04_Architecture/03_Integrations/web-current-information.md`: Internet access decoupled from Cloud LLM authorization (`D-PHONE-13C`, `D-PHONE-01A`), platform-neutral device-local provider credential isolation.

### Verification Checklist for Batch D3

- [x] File Purity: Only the 9 approved canonical and tracking files modified; plan file remains frozen.
- [x] Whole-file trailing whitespace scan returns 0 matches across all modified files.
- [x] Scoped `git diff --check` passes with exit code 0.
- [x] Markdown relative links valid across all updated files.
- [x] Premature promotion of D4/D5 features avoided.
- [x] Implemented reality truth preserved (rolling compaction truthfully recorded as NOT IMPLEMENTED).
- [x] Reference device sanitized to generic description in canonical docs.
- [x] Stop for independent Gate 2 review (Chris & GPT).

---

## 5. Completed Work: Batch D4 Voice, Health, Vision, Character/Presence & Mobile UX

**Objective:** Promote Composable Voice architecture (`D-PHONE-04`, `D-PHONE-14` through `14G`), Health Connect integration as Conditional Mobile V1 (`D-PHONE-15` through `15E`, `D-SHARED-HEALTH-01` through `04`), Multimodal Vision architecture (`D-PHONE-16` through `16E`, `D-SHARED-VISION-01`), Character, Emotion & Presence boundaries (`D-PHONE-06`, `D-PHONE-EMO-01`, `D-PHONE-12D`, `12E`, `D-PHONE-UX-10`, `P-SHARED-PRESENCE-01`, `P-PHONE-AR-01..02`, `P-PRESENCE-02`), bounded Location Context direction (`P-PHONE-LOC-01`), and canonical Mobile Companion Shell and UX design specification (`D-PHONE-UX-01` through `10`, `D-SHARED-LANG-01`, `02`).

### Targeted Canonical Files & Responsibilities

- [x] `docs/04_Architecture/03_Integrations/health-and-wearables.md`: Promoted Health Connect to Conditional Mobile V1 (`D-PHONE-15`), granular metric authorizations (`D-PHONE-15A`), read-only ingestion (`D-PHONE-15B`), health vs D7 memory decoupling (`D-PHONE-15C`), shared normalized context schema (`D-PHONE-15D`, `D-SHARED-HEALTH-01`), Health Connect platform aggregation boundary (`D-PHONE-15E`), non-clinical wellness boundary (`D-SHARED-HEALTH-02`), health-aware check-ins (`D-SHARED-HEALTH-03`), health cloud egress isolation (`D-SHARED-HEALTH-04`), policy-open sync (bounded useful normalized context; exact aggregation, retention, and transport implementation-open), sandbox baseline with optional full DB encryption, and explicit implementation truth (not implemented in code).
- [x] `docs/04_Architecture/01_Domains/multimodal-and-media.md`: Promoted Mobile V1 Multimodal Architecture (`D-PHONE-16`), camera still-capture & image attachments (`D-PHONE-16A`), multimodal route selection among approved route set with implementation-open priority (`D-PHONE-16B`), empirical vision qualification (`D-PHONE-16C`), offline persistence without Host regeneration (`D-PHONE-16D`), explicit user-initiated capture boundary (`D-PHONE-16E`), vision vs memory decoupling (`D-SHARED-VISION-01`), removal of unapproved model/quantization candidates, model/runtime neutrality, and implementation truth (not implemented).
- [x] `docs/04_Architecture/01_Domains/voice-and-audio.md`: Promoted Composable Mobile Voice Architecture (`D-PHONE-04`, `D-PHONE-14`), Connected Mobile Voice (`D-PHONE-14A`), Local TTS (`D-PHONE-14B`), Local STT (`D-PHONE-14C`), Full Offline Voice (`D-PHONE-14D`), Voice route selection (`D-PHONE-14E`), explicit Voice session lifecycle (`D-PHONE-14F`), whisper.cpp first Mobile STT research candidate / qualification direction (`D-PHONE-14G`), transient audio buffer release policy, and explicit implementation truth (not implemented).
- [x] `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`: Promoted Mobile Character, Emotion & Presence Boundaries (`D-PHONE-06`), character definition synchronization, offline emotion event capture (`D-PHONE-EMO-01`), check-in cadence and non-coercive companion tone (`D-PHONE-12D`, `12E`), lightweight mood presence with emoji fallback (`D-PHONE-UX-10`), decoupled presence from Character identity, Personality, Mood, and Voice (`P-SHARED-PRESENCE-01`, `P-PHONE-AR-01..02`, `P-PRESENCE-02`), non-canonical status of offline drafts, and implementation truth (not implemented).
- [x] `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`: Added Section 2.4 Mobile Multimodal & Local Vision (`D-PHONE-16` through `16E`, `D-SHARED-VISION-01`), updated Section 3.2 Composable Voice model (`D-PHONE-14` through `14G`), updated Section 4 Health & Wearables to Conditional Mobile V1 (`D-PHONE-15` through `15E`, `D-SHARED-HEALTH-01` through `04`), added Section 4.2 Bounded Opt-in Location Context (`P-PHONE-LOC-01`) as Mobile Later / Approved Future Direction with no V1 implementation tasks, and Section 4.3 Future Embodied Presence & AR Directions (`P-SHARED-PRESENCE-01`, `P-PHONE-AR-01..02`, `P-PRESENCE-02`).
- [x] `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`: Replaced self-certifying batch labels with durable Section 6 Architecture Specification Mapping; reconciled local LLM baseline row for qualified devices (`D-PHONE-01`, `02`, `03`); added Location context row (`P-PHONE-LOC-01`); separated V1 Character/Emotion from Future Presence/AR; reconciled Health cloud behavior to separately authorized / default deny; updated Section 7 Decision Ledger rows.
- [x] `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`: Updated Section 3.1 sync matrix for Health context (bounded useful normalized context; open conflict/merge mechanics); updated Section 3.2.7 Offline Emotion Event Synchronization Pipeline (`D-PHONE-EMO-01`) to preserve event outbox architecture invariant while leaving schema, taxonomy, decay, and math implementation-open; updated Section 3.2.8 Offline Multimodal Persistence (`D-PHONE-16D`) and Section 3.2.9 Activity & Reconciliation Inbox (`D-PHONE-UX-05`).
- [x] `docs/04_Architecture/01_Domains/memory-and-personalization.md`: Verified Section 2.7 External Domain Boundaries establishing that raw health metrics are NOT D7 Memory (`D-PHONE-15C`) and raw images/multimodal attachments are NOT D7 Memory (`D-SHARED-VISION-01`), with explicit cross-links to health and multimodal specs.
- [x] `docs/04_Architecture/01_Domains/assistant-and-conversations.md`: Added Section 2.8 Unified Interaction Surface & Extensible Language Registry (`D-PHONE-UX-03`, `D-PHONE-UX-09`, `D-SHARED-LANG-01`, `D-SHARED-LANG-02`), documenting conversation surface unification and modality-aware language qualification.
- [x] `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`: Authored canonical design specification covering 5-tab shell (`D-PHONE-UX-01`), icon-first navigation (`D-PHONE-UX-01A`), contextual Home (`D-PHONE-UX-02`), unified interaction surface (`D-PHONE-UX-03`), unified schedule experience with cross-device alert arbitration (`D-PHONE-UX-04`, `D-SHARED-SCHED-02`), activity inbox (`D-PHONE-UX-05`), compact capability status with illustrative placeholders (`D-PHONE-UX-06`), graceful standalone UX with truthful offline boundaries (`D-PHONE-UX-07`), hybrid visual language without locked design constants or platform classes (`D-PHONE-UX-08`), appearance modes (OLED default, Dark, Light, System), language decoupling and modality-aware qualification (`D-PHONE-UX-09`, `D-SHARED-LANG-01`, `02`), lightweight mood presence (`D-PHONE-UX-10`), check-in tone and approved V1 home-screen widget target (`D-PHONE-12D`, `12E`), bounded location context (`P-PHONE-LOC-01`), vision multi-route indicator (`D-PHONE-16B`), health egress notice (`D-SHARED-HEALTH-04`), and explicit implementation truth (not implemented in code).

### Verification Checklist for Batch D4

- [x] File Purity: Exactly 10 canonical/design files and 1 active tracking file modified/added; plan file remains frozen; planning spine untouched (reserved for D5).
- [x] Whole-file trailing whitespace scan returns 0 matches across all 11 modified/added files.
- [x] Scoped `git diff --check` passes with exit code 0 across all changes.
- [x] Relative Markdown links valid across all touched files.
- [x] Zero unapproved D5 IDs (`D-MOBILE-VERIFY-`, `D-CI-`, `MG13` through `MG18` in new/modified sections).
- [x] Zero forbidden self-certification claims (`Batch D Aligned`, `Gate 3 Passed`, `D4 Approved`, `D4 Verified`, `[RESOLVED IN BATCH D]`) in canonical documentation.
- [x] Correct exact Voice (`D-PHONE-14` through `14G`) and Vision (`D-PHONE-16` through `16E`, `D-SHARED-VISION-01`) decision IDs ledgered and tracked.
- [x] Location Context (`P-PHONE-LOC-01`) canonicalized in both `MOBILE_SYSTEM_BASELINE.md` and `mobile-capabilities-and-runtime.md`.
- [x] Implemented reality truth preserved: Flutter mobile UI, screens, voice, health, and vision recorded truthfully as NOT IMPLEMENTED in current repository code.
- [x] Gate 3 review result: PASSED / D5 UNBLOCKED (`ed1c71b7245324072c4b48dc7a9596c71d717e11`).

---

## 6. Completed Work: Batch D5 / D5.5 Final Six Traceability Corrections

**Objective:** Execute narrow Closure Gate traceability corrections following D5.4 independent re-review across six targeted defects: correct `MOB-INFER-004` architectural owner to `mobile-capabilities-and-runtime.md §2.3` (Container & Engine Independence rule); correct bare "Section 17" in `MOBILE_CHECKLIST.md` MG14.3 to explicit named reference `Decision Register: Gemma 3 1B cross-device qualification` and `§2.2`; correct Standalone Mobile Tool Gateway top-level readiness row to `tool-permissions-and-actions.md §2.8, §2.7`; correct MG6.3 Direct Cloud LLM Turns authority from local `D-PHONE-01` to orthogonal/cloud routing authority `D-PHONE-01A`, `MOBILE_SYSTEM_BASELINE.md §5.1, §5.3`, and `mobile-offline-and-sync.md §3.2.6`; correct stale pre-D4 Mobile Health foundation row in `DECISION_REGISTER.md` to `health-and-wearables.md §2.1–§2.6` and `mobile-capabilities-and-runtime.md §4, §4.1` with full approved CONDITIONAL V1 principles; correct Batch D2 scheduling citations in `walkthrough-mobile-v1-batch-d-reconciliation.md` from `(§5, §6)` to `(§2.6, §2.7, §2.9)`; verify zero trailing whitespace and valid WBS DAG; and prepare for independent Closure Gate re-review.

### Targeted Files & Promoted Responsibilities

- [x] `docs/02_Planning/00_Master/MOBILE_WBS.md`: Corrected `MOB-INFER-004` architectural owner to `mobile-capabilities-and-runtime.md §2.3` (Container & Engine Independence); confirmed 88 items with zero cyclic dependencies.
- [x] `docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`: Corrected MG14.3 authority from bare "Section 17" to `D-PHONE-01`, `D-PHONE-01C`, `Decision Register: Gemma 3 1B cross-device qualification`, `mobile-capabilities-and-runtime.md §2.2`; corrected Standalone Mobile Tool Gateway readiness row Architecture Spec to `tool-permissions-and-actions.md §2.8, §2.7`; corrected MG6.3 authority to `D-PHONE-01A`, `MOBILE_SYSTEM_BASELINE.md §5.1, §5.3`, and `mobile-offline-and-sync.md §3.2.6`.
- [x] `docs/02_Planning/00_Master/DECISION_REGISTER.md`: Corrected Section 2 Mobile Health & Wearables Disposition row canonical owner to `health-and-wearables.md §2.1–§2.6` and `mobile-capabilities-and-runtime.md §4, §4.1`, updating notes to reflect full approved CONDITIONAL V1 principles across all 8 metric categories, provenance, and egress isolation.
- [x] `docs/03_Walkthroughs/walkthrough-mobile-v1-batch-d-reconciliation.md`: Corrected Batch D2 scheduling section citations to `(§2.6, §2.7, §2.9)` for cross-device arbitration, alert enrichment, and temporal parity; updated status and batch tags to D5.5.
- [x] Mechanical Whitespace Verification: Verified `git diff --check d92b6e4b9b19e957dd419b9968c7ad3ad4cee031` and working tree diff pass with exit code 0.

### Verification Checklist for Batch D5.5

- [x] `git diff --check d92b6e4b9b19e957dd419b9968c7ad3ad4cee031` passes with exit code 0 and zero warnings.
- [x] WBS DAG validation confirms exactly 88 items, 0 duplicate IDs, 0 dangling dependencies, 0 cycles (topological sort valid), and all 65 pre-D5 IDs preserved.
- [x] All 6 targeted traceability defects corrected and verified against normative section contents.
- [x] Mobile Golden validation confirms exact 18 MG groups with MG6.3 and MG14.3 canonically corrected.
- [x] Master Decision Register Section 2 Health row accurately reflects approved CONDITIONAL V1 truth.
- [x] Walkthrough D2 citations point to normative sections §2.6, §2.7, §2.9.
- [x] Markdown relative links verified across all touched files (0 broken links).
- [x] Strictly zero Git mutations performed by AI agent.
- [x] Zero production code, test, or CI workflow changes.
- [x] Gate 4 Closure Gate re-review: PASSED (`282f3607c6663cb72b34ad8f3596651aaf5ac18f`).

---

## 7. Final Closure Bookkeeping & PR #21 Handoff

**Objective:** Complete final delivery closure bookkeeping following independent human (Chris) and GPT Closure Gate approval: update SPRINT_ROADMAP.md and DELIVERY_INDEX.md to mark MOBILE-ARCH complete and verified, update the delivery walkthrough, archive the active tracking task, and prepare PR #21 for human handoff and merge.

### Closure Invariants & Lifecycle Truth

- [x] **Gate 4 Closure Gate PASSED:** Independent human (Chris) and GPT review passed at checkpoint `282f3607c6663cb72b34ad8f3596651aaf5ac18f`.
- [x] **PR #21 Hosted CI Green:** Hosted PR candidate CI Run #84 completed successfully (`SUCCESS`).
- [x] **Delivery Closed:** MOBILE-ARCH Batch D Canonical Promotion is complete and verified.
- [x] **Implementation Truth:** Production Flutter Mobile implementation remains NOT IMPLEMENTED in current repository code. The Kotlin Android code (`android/`) is retained as reference prototype evidence only.
- [x] **Decision Debt Boundary:** `DEBT-MOB-10: One Profile → Multiple Mobile Phones Topology & Concurrency` remains OPEN in `docs/02_Planning/00_Master/DECISION_DEBT.md`.
- [x] **Golden Gate Status:** Mobile Golden qualification (`MOBILE_CHECKLIST.md` MG1–MG18) is future implementation and release work.
- [x] **PR State:** PR #21 merge is pending at archival checkpoint; post-merge verification has not yet been performed.
- [x] **M1 Sequencing:** Milestone M1 (Flutter Desktop Client Foundation) remains PENDING and strictly sequenced after merge of PR #21.
- [x] **Tracker Archival:** Active tracker archived to `docs/01_Tracking/archive/task-2026-10-07-mobile-v1-batch-d-canonical-promotion.md` and removed from `docs/01_Tracking/active/`.
