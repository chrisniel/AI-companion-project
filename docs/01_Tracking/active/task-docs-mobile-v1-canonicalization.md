# Active Task: MOBILE-ARCH Batch D Canonical Promotion

> **Branch:** `docs/mobile-v1-canonicalization`
> **Delivery:** MOBILE-ARCH Batch D Canonical Promotion
> **Status:** D4 AUTHORED — AWAITING INDEPENDENT GATE 3 REVIEW
> **Approved Plan:** `docs/02_Planning/01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md`
> **Gate 0 Approved Checkpoint:** `2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`
> **Gate 1 Passed Checkpoint:** `19116d9965e369e2869fbdf1a4d0702ccd730077`
> **Gate 2 Passed Checkpoint:** `5d860625510ffae0437cc9c58662dfe087c3fad9`
> **M1 Status:** NOT ACTIVE / Sequenced after MOBILE-ARCH Batch D re-closure

---

## 1. Governance & Delivery Sequence

- **Git Authority:** Strictly read-only for AI agents. Chris is the sole owner of all Git mutations.
- **Delivery Lifecycle Stage:** DOCUMENTATION GATE (Batch D4) — Canonical promotion of Voice, Health, Vision, Character/Emotion, and Mobile UX architecture.
- **Known CI Blocker:** Historical PR-wide Markdown trailing whitespace; full-PR mechanical cleanup scheduled for Batch D5.

### Delivery Stages & Batch Sequence

| Batch / Stage | Scope | Status | Independent Gate |
| :--- | :--- | :--- | :--- |
| **D1 Research** | Approved Decision Ledger, Reconciliation Report, Benchmark Evidence | COMPLETED | Gate 0 Passed |
| **Plan Authoring** | Batch D Canonical Promotion Plan | APPROVED | Gate 0 Passed (`2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`) |
| **Batch D2** | Core Baseline, Identity, Scheduling & Flutter Boundaries | **APPROVED** | Gate 1 Passed (`19116d9965e369e2869fbdf1a4d0702ccd730077`) |
| **Batch D3** | AI Runtime, Conversations, Context, Memory & Tools | **APPROVED** | Gate 2 Passed (`5d860625510ffae0437cc9c58662dfe087c3fad9`) |
| **Batch D4** | Voice, Health, Vision, Character/Presence & Mobile UX | **AUTHORED** | Gate 3 Pending (Awaiting Review) |
| **Batch D5** | Master Planning Spine, Golden Verification, CI & PR Handoff | PENDING | Gate 4 Closure Gate Pending |

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

- [x] `docs/04_Architecture/03_Integrations/health-and-wearables.md`: Promoted Health Connect to Conditional Mobile V1 (`D-PHONE-15`), granular metric authorizations (`D-PHONE-15A`), read-only ingestion (`D-PHONE-15B`), health vs D7 memory decoupling (`D-PHONE-15C`), shared normalized context schema (`D-PHONE-15D`, `D-SHARED-HEALTH-01`), Health Connect platform aggregation boundary (`D-PHONE-15E`), non-clinical wellness boundary (`D-SHARED-HEALTH-02`), health-aware check-ins (`D-SHARED-HEALTH-03`), health cloud egress isolation (`D-SHARED-HEALTH-04`), and explicit implementation truth (not implemented in code).
- [x] `docs/04_Architecture/01_Domains/multimodal-and-media.md`: Promoted Mobile V1 Multimodal Architecture (`D-PHONE-16`), camera still-capture & image attachments (`D-PHONE-16A`), attachment lifecycle (`media://` scheme, local cache, non-destructive sync; `D-PHONE-16D`), cloud VLM fallback route (`D-PHONE-16C`), local VLM qualification (`D-PHONE-16B`), multimodal context boundaries decoupled from D7 Memory (`D-PHONE-16E`, `D-SHARED-VISION-01`), implementation truth (not implemented), and open design boundaries.
- [x] `docs/04_Architecture/01_Domains/voice-and-audio.md`: Promoted Composable Mobile Voice Architecture (`D-PHONE-04`, `D-PHONE-14`), independent STT and TTS engine routing (`D-PHONE-14A`), local speech engine lifecycle (`D-PHONE-14B`), remote Host audio streaming over secure WebSocket (`D-PHONE-14C`), cloud speech route (`D-PHONE-14D`), platform TTS fallback (`D-PHONE-14E`), client-side Voice Barge-In (`D-PHONE-14F`), audio routing and focus management (`D-PHONE-14G`), and explicit implementation truth (not implemented).
- [x] `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`: Promoted Mobile Character, Emotion & Presence Boundaries (`D-PHONE-06`), character definition synchronization, offline emotion event capture (`D-PHONE-EMO-01`), check-in cadence and companion tone (`D-PHONE-12D`, `12E`), lightweight mood presence with emoji fallback (`D-PHONE-UX-10`), bounded presence research references (`P-SHARED-PRESENCE-01`, `P-PHONE-AR-01..02`, `P-PRESENCE-02`), and implementation truth (not implemented).
- [x] `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`: Added Section 2.4 Mobile Multimodal & Local Vision (`D-PHONE-16`), updated Section 3.2 Composable Voice model (`D-PHONE-14`), updated Section 4 Health & Wearables to Conditional Mobile V1 (`D-PHONE-15`), recorded Bounded Opt-in Location Context (`P-PHONE-LOC-01`) as Mobile Later / Approved Future Direction with no V1 implementation tasks, and bounded presence directions (`P-SHARED-PRESENCE-01`, `P-PHONE-AR-01..02`, `P-PRESENCE-02`).
- [x] `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`: Updated capability matrix (§5.3) for Voice, Character, Multimodal Vision, and Health Connect; added Section 6 Batch D resolution note; updated Section 7 Decision Ledger rows for Health, Vision, Voice, Character/Emotion, and UX.
- [x] `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`: Updated Section 3.1 sync matrix for Character profiles, Media attachments (`media://`), Emotion events, and Health context; added §3.2.7 Offline Emotion Event Synchronization Pipeline (`D-PHONE-EMO-01`), §3.2.8 Offline Multimodal Persistence (`D-PHONE-16D`), and §3.2.9 Activity & Reconciliation Inbox (`D-PHONE-UX-05`).
- [x] `docs/04_Architecture/01_Domains/memory-and-personalization.md`: Added Section 2.7 External Domain Boundaries establishing that raw health metrics are NOT D7 Memory (`D-PHONE-15C`) and raw images/multimodal attachments are NOT D7 Memory (`D-SHARED-VISION-01`), with explicit cross-links to health and multimodal specs.
- [x] `docs/04_Architecture/01_Domains/assistant-and-conversations.md`: Added Section 2.8 Unified Interaction Surface & Extensible Language Registry (`D-PHONE-UX-03`, `D-PHONE-UX-09`, `D-SHARED-LANG-01`, `D-SHARED-LANG-02`), documenting conversation surface unification and language registry decoupling.
- [x] `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md`: Authored new canonical design specification covering 5-tab shell (`D-PHONE-UX-01`), icon-first navigation with accessibility semantics (`D-PHONE-UX-01A`), contextual Companion Home (`D-PHONE-UX-02`), unified interaction surface (`D-PHONE-UX-03`), unified schedule experience (`D-PHONE-UX-04`), activity & reconciliation inbox (`D-PHONE-UX-05`), compact capability status + drill-down (`D-PHONE-UX-06`), graceful standalone UX (`D-PHONE-UX-07`), hybrid visual language (`D-PHONE-UX-08`), appearance modes (OLED default, Dark, Light, System), reduced motion/effects governor, language decoupling (`D-PHONE-UX-09`, `D-SHARED-LANG-01`, `02`), lightweight mood presence (`D-PHONE-UX-10`), check-in tone (`D-PHONE-12D`, `12E`), bounded location context (`P-PHONE-LOC-01`), and explicit implementation truth (not implemented in code).

### Verification Checklist for Batch D4

- [x] File Purity: Exactly 10 canonical/design files and 1 active tracking file modified/added; plan file remains frozen; planning spine untouched (reserved for D5).
- [x] Whole-file trailing whitespace scan returns 0 matches across all 11 modified/added files.
- [x] Scoped `git diff --check` passes with exit code 0 across all changes.
- [x] Relative Markdown links valid across all touched files.
- [x] Zero unapproved D5 IDs (`D-MOBILE-VERIFY-`, `D-CI-`, `MG13` through `MG18` in new/modified sections).
- [x] Zero forbidden self-certification claims (`Batch D Aligned`, `Gate 3 Passed`, `D4 Approved`, `D4 Verified`) in canonical documentation.
- [x] Implemented reality truth preserved: Flutter mobile UI, screens, voice, health, and vision recorded truthfully as NOT IMPLEMENTED in current repository code.
- [x] Stop for independent Gate 3 review (Chris & GPT).
