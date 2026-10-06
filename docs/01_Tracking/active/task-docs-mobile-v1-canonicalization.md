# Active Task: MOBILE-ARCH Batch D Canonical Promotion

> **Branch:** `docs/mobile-v1-canonicalization`
> **Delivery:** MOBILE-ARCH Batch D Canonical Promotion
> **Status:** D3 AUTHORED — AWAITING INDEPENDENT GATE 2 REVIEW
> **Approved Plan:** `docs/02_Planning/01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md`
> **Gate 0 Approved Checkpoint:** `2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`
> **Gate 1 Passed Checkpoint:** `19116d9965e369e2869fbdf1a4d0702ccd730077`
> **M1 Status:** NOT ACTIVE / Sequenced after MOBILE-ARCH Batch D re-closure

---

## 1. Governance & Delivery Sequence

- **Git Authority:** Strictly read-only for AI agents. Chris is the sole owner of all Git mutations.
- **Delivery Lifecycle Stage:** DOCUMENTATION GATE (Batch D3) — Canonical authoring completed; awaiting independent Gate 2 review.
- **Known CI Blocker:** Historical PR-wide Markdown trailing whitespace; full-PR mechanical cleanup scheduled for Batch D5.

### Delivery Stages & Batch Sequence

| Batch / Stage | Scope | Status | Independent Gate |
| :--- | :--- | :--- | :--- |
| **D1 Research** | Approved Decision Ledger, Reconciliation Report, Benchmark Evidence | COMPLETED | Gate 0 Passed |
| **Plan Authoring** | Batch D Canonical Promotion Plan | APPROVED | Gate 0 Passed (`2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`) |
| **Batch D2** | Core Baseline, Identity, Scheduling & Flutter Boundaries | **APPROVED** | Gate 1 Passed (`19116d9965e369e2869fbdf1a4d0702ccd730077`) |
| **Batch D3** | AI Runtime, Conversations, Context, Memory & Tools | **D3 AUTHORED** | Awaiting Independent Gate 2 Review |
| **Batch D4** | Voice, Health, Vision, Character/Presence & Mobile UX | PENDING | Gate 3 Pending |
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

## 4. Active Work: Batch D3 AI Runtime, Conversations, Context, Memory & Tools

**Objective:** Promote device-local generative LLM production path for qualified devices, replaceable local model architecture, model and resource lifecycle states, progressive resource governance, evidence-driven qualification, shared context budget management, transcript authority and compaction reality, unified context retrieval, offline memory intent outbox, pending memory overlay, causal conversation branching, turn control, safe regeneration, and the Standalone Mobile Tool Gateway with deterministic confirmation.

### Targeted Canonical Files & Responsibilities

- [x] `docs/04_Architecture/SYSTEM_BASELINE.md`: Production-capable device-local LLM path on qualified devices (`D-PHONE-01`, `D-PHONE-03`), core companion survival without generative AI (`D-PHONE-02`), PC Host master runtime authority.
- [x] `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`: Four-way component separation (`D-PHONE-05`), mobile model lifecycle states (`installed`, `loaded / resident`, `active`, `unloaded`, `removed`) with max 1 resident generative LLM cap (`D-PHONE-05`), replaceable local model architecture (`D-PHONE-01C`), vendor-neutral execution with CPU broad fallback (`D-PHONE-03`), non-binding research candidates (Gemma 3 1B).
- [x] `docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`: Progressive Resource Governor (`D-PHONE-05A`), evidence-driven qualification without fixed RAM floor, truthful OOM and process death architecture.
- [x] `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`: Updated capability matrix reflecting local LLM production path (`D-PHONE-01`, `D-PHONE-03`), reference device sanitization ("Reference Android Device A: Android 13, ARM64, 8 GB physical RAM, mid-range mobile SoC class"), empirical research role of benchmark data.
- [x] `docs/04_Architecture/01_Domains/assistant-and-conversations.md`: Shared Context / Generation / Reasoning Budget Manager (`D-SHARED-AI-01`), raw conversation transcript authority and compaction truth (`D-SHARED-AI-02`), Host-mediated live turn streaming (`D-SHARED-CONV-02`), causal conversation branching without timestamp LWW (`D-SHARED-CONV-01`), active turn control (`D-SHARED-CONV-03`), safe regeneration without tool replay (`D-SHARED-CONV-03A`).
- [x] `docs/04_Architecture/01_Domains/memory-and-personalization.md`: Unified Context Retrieval across distinct sources (`D-SHARED-AI-03`), selective offline Memory replica (`D-PHONE-09`), offline explicit Memory intent outbox (`D-PHONE-08`), pending Memory overlay (`D-PHONE-08A`), PC Host D7 Memory engine authority.
- [x] `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`: Standalone Mobile Tool Gateway under Decision D9 (`D-PHONE-13`), approved tool scope (`D-PHONE-13A`, `13B`, `13D`), explicitly prohibited tools (`D-PHONE-13E`), tool capability qualification and deterministic confirmation (`D-PHONE-13F`), committed side-effect replay prohibition.
- [x] `docs/04_Architecture/03_Integrations/web-current-information.md`: Internet access decoupled from Cloud LLM authorization (`D-PHONE-13C`, `D-PHONE-01A`).

### Verification Checklist for Batch D3

- [x] File Purity: Only the 9 approved canonical and tracking files modified; plan file remains frozen.
- [x] Whole-file trailing whitespace scan returns 0 matches across all modified files.
- [x] Scoped `git diff --check` passes with exit code 0.
- [x] Markdown relative links valid across all updated files.
- [x] Premature promotion of D4/D5 features avoided.
- [x] Implemented reality truth preserved (rolling compaction truthfully recorded as NOT IMPLEMENTED).
- [x] Reference device sanitized to generic description in canonical docs.
- [x] Stop for independent Gate 2 review (Chris & GPT).
