# Active Task: MOBILE-ARCH Batch D Canonical Promotion

> **Branch:** `docs/mobile-v1-canonicalization`
> **Delivery:** MOBILE-ARCH Batch D Canonical Promotion
> **Status:** IMPLEMENTED / AUTHORED — AWAITING INDEPENDENT REVIEW (Batch D2)
> **Approved Plan:** `docs/02_Planning/01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md`
> **Gate 0 Approved Checkpoint:** `2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`
> **M1 Status:** NOT ACTIVE / Sequenced after MOBILE-ARCH Batch D re-closure

---

## 1. Governance & Delivery Sequence

- **Git Authority:** Strictly read-only for AI agents. Chris is the sole owner of all Git mutations.
- **Delivery Lifecycle Stage:** DOCUMENTATION GATE (Batch D2) — Authored canonical promotion awaiting independent review.
- **Known CI Blocker:** Historical PR-wide Markdown trailing whitespace; full-PR mechanical cleanup scheduled for Batch D5.

### Delivery Stages & Batch Sequence

| Batch / Stage | Scope | Status | Independent Gate |
| :--- | :--- | :--- | :--- |
| **D1 Research** | Approved Decision Ledger, Reconciliation Report, Benchmark Evidence | COMPLETED | Gate 0 Passed |
| **Plan Authoring** | Batch D Canonical Promotion Plan | APPROVED | Gate 0 Passed (`2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`) |
| **Batch D2** | Core Baseline, Identity, Scheduling & Flutter Boundaries | **AUTHORED** | Gate 1 Awaiting Independent Review |
| **Batch D3** | AI Runtime, Conversations, Context, Memory & Tools | PENDING | Gate 2 Pending |
| **Batch D4** | Voice, Health, Vision, Character/Presence & Mobile UX | PENDING | Gate 3 Pending |
| **Batch D5** | Master Planning Spine, Golden Verification, CI & PR Handoff | PENDING | Gate 4 Closure Gate Pending |

---

## 2. D1 Completed Research Evidence Baseline

- [x] **Approved Working Decision Ledger:** `docs/00_Drafts/research/mobile/MOBILE_ARCH_BATCH_D_APPROVED_DECISION_LEDGER.md` (Authoritative approved working decision source for Batch D reconciliation).
- [x] **Audited Reconciliation Report:** `docs/00_Drafts/research/mobile/MOBILE_ARCH_BATCH_D_RECONCILIATION_REPORT.md` (Detailed mapping against repository canonical truth; 71 gaps, 7 conflicts resolved).
- [x] **Sanitized Benchmark Evidence:** `docs/00_Drafts/research/mobile/benchmarks/MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md` (Non-canonical empirical qualification research).
- [x] **Approved Implementation Plan:** `docs/02_Planning/01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md` (Status: `Approved` at checkpoint `2b0fdbb8f21d6aaeec3e6d3dfdf9ca990d50f53f`).

---

## 3. Active Work: Batch D2 Canonical Promotion

**Objective:** Promote foundational Mobile operating-state semantics, enrollment lifecycle, one-device-to-one-profile binding, core companion survival without generative AI, synchronized scheduling authority (stable UUIDs, offline authoring, Host definition protection), Companion Alert Enrichment, bounded Routine occurrence presentation, temporal intent resolution, and Flutter shared-core boundaries.

### Targeted Canonical Files & Responsibilities

- [x] `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`: 3 orthogonal availability axes, enrollment lifecycle, 1-device to 1-profile binding, core survival without generative AI, Flutter shared workspace boundaries.
- [x] `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`: Stable client UUIDs, base-revision optimistic concurrency, typed `CONFLICT_DETECTED`, no universal server-wins, no timestamp LWW.
- [x] `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`: Synchronized scheduling authority, offline Mobile Reminders/Alarms, protected Host definitions, Companion Alert Enrichment (`D-SHARED-SCHED-03`), cross-device alert arbitration (`D-SHARED-SCHED-02`), bounded Routine occurrence caching (`D-PHONE-12` to `12C`), temporal intent resolution (`D-SHARED-SCHED-04` to `04E`).
- [x] `docs/04_Architecture/01_Domains/android-companion.md`: Android platform adapter boundary under Flutter (exact-alarm capability/permission lifecycle, Keystore, lifecycle, Doze); demoting `android/` Kotlin code to reference prototype evidence only.
- [x] `docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`: 1-device to 1-profile binding, PC Host Admin ownership, One Profile → Multiple Phones as OPEN / DECISION DEBT, platform credential protection.

### Verification Checklist for Batch D2

- [x] File Purity: Only the 7 approved files modified/created.
- [x] Whole-file trailing whitespace scan returns 0 matches across all modified files.
- [x] Scoped `git diff --check` passes with exit code 0.
- [x] Markdown relative links valid across all updated files.
- [x] No premature promotion of D3/D4/D5 features.
- [x] Implemented reality truth preserved (no claim of current Flutter Mobile implementation).
- [x] Stale contradiction scan clean.
- [ ] Stop for independent Gate 1 review (Chris & GPT).
