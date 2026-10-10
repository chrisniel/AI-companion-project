# AI Companion — PC V1 Master Delivery Index

> **Document Role:** Canonical delivery and planning index linking product milestones, work breakdown structure (WBS), active implementation plans, and release gates.
> **Status:** Active Canonical Planning Index
> **Authority Precedence:** This document coordinates delivery sequencing. Normative architecture is owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) and focused domain specifications. Active sprint tracking resides in [`docs/01_Tracking/task.md`](../../01_Tracking/task.md). Detailed feature steps reside in active plans under [`docs/02_Planning/01_Plans/`](../01_Plans/).

---

## 1. Planning Spine Navigation

The AI Companion PC V1 planning spine consists of dedicated master documents under `docs/02_Planning/00_Master/`:

```text
docs/02_Planning/00_Master/
├── DELIVERY_INDEX.md      ◄── [YOU ARE HERE] Delivery hub, milestones, release gates
├── DECISION_REGISTER.md   ◄── Frozen architectural decisions and owner mapping
├── WBS.md                 ◄── PC V1 granular work breakdown structure (work IDs)
├── MOBILE_WBS.md          ◄── Mobile V1 granular work breakdown structure (work IDs)
├── BACKLOG.md             ◄── Categorized backlog (PC V1, PC Later, Mobile, Rejected)
├── SPRINT_ROADMAP.md      ◄── Strategic milestone sequence (M0 through M5 + Golden)
├── MASTER_CHECKLIST.md    ◄── PC V1 implementation, verification, and Golden checklist
├── MOBILE_CHECKLIST.md    ◄── Mobile V1 readiness checklist and Golden MG1–MG18
└── DECISION_DEBT.md       ◄── Open implementation details and evidence-needed items
```

> **Mobile Architecture & Delivery Hub Links:**
> - System Architecture: [`MOBILE_SYSTEM_BASELINE.md`](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md) (especially §7 Approved Mobile Decision Ledger)
> - Implementation Breakdown: [`MOBILE_WBS.md`](MOBILE_WBS.md)
> - Readiness Checklist: [`MOBILE_CHECKLIST.md`](MOBILE_CHECKLIST.md)

---

## 2. PC V1 Milestone Sequence

| Milestone ID | Title & Scope | Primary Deliverables | Target Gate / Status |
| :--- | :--- | :--- | :--- |
| **M0** | **Docs & Architecture Reset** | Canonicalization handoff execution, master planning spine creation, system baseline update, ADR reconciliation, and CI guide alignment. | **COMPLETE / VERIFIED** |
| **MOBILE-ARCH** | **Mobile Architecture Pass** | Canonicalize production Mobile Companion architecture across Batches A–D (standalone core, local inference, offline sync, voice, health, vision, shell UX). Batch D canonical promotion complete; D2–D5 independently reviewed; Closure Gate passed; 88-item Mobile WBS; MG1–MG18; PR #21 merged to develop (commit 28c4332); production Mobile implementation remains future work. Implementation plan: [`plan-mobile-v1-batch-d-canonical-promotion.md`](../01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md). Mobile production implementation remains an independent follow-on track ([`MOBILE_WBS.md`](MOBILE_WBS.md)). | **COMPLETE / VERIFIED** |
| **M1** | **Flutter Client Foundation** | Production Flutter Desktop app scaffolding, monorepo pub workspace, native window/tray management, REST/SSE client, fail-closed auth, responsive navigation, conversation drawer/chat, GFM Markdown tables, post-turn AI title generation, and Windows lifecycle verification. Delivered via PR #23 (commit 7c1d1a2); Closure Gate reconciled post-merge with documented tracker archival exception. | **COMPLETE / VERIFIED** |
| **M2** | **PC Companion Foundation** | Windows Runtime launch, attach & supervision (M2-H1 / PC-HOST-001); followed promptly by Host Administration Separation & Secure Lifecycle Authority (PC-HOST-005: graceful full exit & model draining), Windows login autostart for runtime and Flutter (PC-HOST-002), native desktop notifications, D6 controlled model import service, and multi-Profile database migration. | **IN PROGRESS (M2-H1 IMPLEMENTATION)** |
| **M3** | **Intelligence & Productivity** | Character Studio & 8 continuous personality traits, persistent bounded emotion, profile-first selective memory with revalidation, and Task/Reminder/Alarm scheduling. | **PLANNED** |
| **M4** | **Voice, Tools & Information** | Conversational voice pipeline with mandatory barge-in, WebSocket audio transport, D9 deterministic tool policy engine, and read-only public web/current info. | **PLANNED** |
| **M5** | **Integration, Hardening & Resilience** | Low-Impact/Gaming mode with model substitution, coordinated backup & restore verification, Factory Reset, Tailscale/Cloudflare hardening, and release preflight. | **PLANNED** |
| **GATE-PC-V1** | **Golden PC V1 Acceptance Gate** | 14-group end-to-end integrated release verification on physical Windows host environment. Prerequisite for cutting PC V1 release tag. | **RELEASE GATE** |

---

## 3. Active & Archived Implementation Plans

### Active Feature Plans (`docs/02_Planning/01_Plans/`)
- [`plan-m2-h1-windows-runtime-supervision.md`](../01_Plans/plan-m2-h1-windows-runtime-supervision.md) — Active implementation plan for M2-H1 / PC-HOST-001: Windows Runtime Launch, Attach & Supervision.
- [`plan-m1-flutter-desktop-client-foundation.md`](../01_Plans/plan-m1-flutter-desktop-client-foundation.md) — Implemented, verified, and delivered Flutter Desktop client foundation (PR #23, commit `7c1d1a2`; Closure Gate reconciled post-merge with tracker archival exception).
- [`plan-mobile-v1-batch-d-canonical-promotion.md`](../01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md) — Completed and verified Mobile V1 canonicalization and Batch D promotion plan (Gate 4 Closure Gate passed; PR #21 merged to develop).
- *Additional feature plans will be created here per work stream as M2–M5 are unlocked.*

### Planning Templates (`docs/02_Planning/02_Templates/`)
- [`implementation-plan-template.md`](../02_Templates/implementation-plan-template.md) — Standard template for authoring non-trivial feature implementation plans.

### Archived Planning Artifacts (`docs/02_Planning/03_Archive/`)
- `ROADMAP.md` — Historical monolithic roadmap (superseded by `SPRINT_ROADMAP.md` and `DELIVERY_INDEX.md`).
- `FEATURE_PROMOTION_MAP.md` — Temporary reconciliation manifest from passes R10–R13 (reconciled and retired).
- `phase-08/` — Completed Phase 8 delivery plan and documentation.
- `post-v1/` — Superseded post-V1 drafts (valid routine semantics promoted to D10).

---

## 4. Key Cross-Subsystem Dependency Edges

1. **Storage Roots (APP_INSTALL / DATA / LIBRARY) → Everything:** Deriving relocatable library assets and multi-Profile state precedes full Flutter desktop and D6 import operation.
2. **OpenAPI Schema Contract → Flutter Client:** FastAPI OpenAPI contract generation is authoritative; Flutter Dart client code-generation or mechanical verification depends on it.
3. **Multi-Profile Migration (`owner_id` → `profile_id`) → Domain Entities:** Updating DB models to support multi-Profile isolation must occur before building Profile-scoped memory, character instances, or conversational queues.
4. **D9 Policy Engine → Tool Invocation:** The 5-stage deterministic pipeline ($\text{Model} \rightarrow \text{Typed Request} \rightarrow \text{Policy} \rightarrow \text{Adapter} \rightarrow \text{Capability}$) must be verified before allowing generative models to invoke tasks, memories, or web tools.
5. **SchedulerService & Native Notifications → Closed-Browser Delivery:** Runtime-owned scheduling logic must precede native Windows Toast presentation for alarms, reminders, and routines.
6. **Native Audio Device Handling (Flutter) ↔ Speech Orchestration (Runtime):** Flutter manages audio hardware devices and capture/playback; Local AI Runtime manages STT/TTS engine lifecycle over WebSocket.
