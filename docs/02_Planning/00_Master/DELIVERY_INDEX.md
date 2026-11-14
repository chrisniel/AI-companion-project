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
| **M2** | **PC Companion Foundation** | Windows Runtime launch, attach & supervision delivered in PR #24 (`d0f96fc`); Batch A Profile schema delivered in PR #25 (`369d787`); Batch B Profile Sessions, authorization and cross-Profile isolation delivered in PR #27 (`5cb2fe6`, stabilized in PR #28 `0bb0894`); `PC-HOST-005` Secure Host Lifecycle delivered in PR #32; Batch C Local Profile Administration & Persistent Selection delivered in PR #33 (`2104d5c`); Batch D Recoverable Profile Deletion & Safe Purge delivered in PR #34 (`f3752a3`). Full Profile PIN/device enrollment, `PC-HOST-002` autostart, `PC-HOST-003` notifications, storage roots and D6 import remain outstanding. | **IN PROGRESS** |
| **M3** | **Intelligence & Productivity** | Batch A Character Templates, Profile Instances & Neutral Fallback delivered in PR #29 (`d22dd7e`); Batch B Immersive Character Studio V1 & 8-Trait Personality Prompt Modulator (`PC-CHAR-002`, `PC-CLIENT-007`) delivered in PR #30 (`319ab66`); Batch C1 Memory Foundation, Scoping & Context Assembly delivered in PR #35 (`b3d31d7`); Batch C2 Selective Automatic Memory Extraction & Slot Reconciliation delivered via PR #36 (`f7de198`); Batch C3 Desktop Memory Control Center UI (`PC-CLIENT-009`), Migration 011 and conflict resolution delivered via PR #37 (`64ac521`); Batch D Persistent Bounded Emotion & Mood Engine, Pre-Generation Turn Appraisal, Natural Companion Grounding & Live Mood UI delivered in PR #38 (`fde6341`); Batch E Memory & Knowledge Architecture V2 (`PC-MEM-001`..`005`, `PC-CLIENT-009`, Migration 013) delivered via PR #39 (`ea4441c`); Batch F Pre-Limit Context Compaction, Rolling Conversation Summaries (`conversation_summaries` Migration 014), Emotion-Weighted Importance, Temporal Evolution, 1-Click Chat Bookmarking, `clear_expires_at` Promote Hardening & Batch E Review Fixes (`PC-MEM-001`..`005`, `PC-CLIENT-006`, `PC-CLIENT-009`) implemented and verified on `feature/m3-context-compaction-memory-f`. Task/Reminder/Alarm scheduling (`PC-SCHED-001`..`005`) remains planned. | **ACTIVE / IN PROGRESS** |
| **M4** | **Voice, Tools & Information** | Conversational voice pipeline with mandatory barge-in, WebSocket audio transport, D9 deterministic tool policy engine, and read-only public web/current info. | **PLANNED** |
| **M5** | **Integration, Hardening & Resilience** | Low-Impact/Gaming mode with model substitution, coordinated backup & restore verification, Factory Reset, Tailscale/Cloudflare hardening, and release preflight. | **PLANNED** |
| **GATE-PC-V1** | **Golden PC V1 Acceptance Gate** | 14-group end-to-end integrated release verification on physical Windows host environment. Prerequisite for cutting PC V1 release tag. | **RELEASE GATE** |

---

## 3. Active & Archived Implementation Plans

### Active Feature Plans (`docs/02_Planning/01_Plans/`)
- [`plan-m3-context-compaction-memory-f.md`](../01_Plans/plan-m3-context-compaction-memory-f.md) — **Implemented & Verified on `feature/m3-context-compaction-memory-f` (Phase 3 Closure Complete — Draft PR Ready for Phase 4 Review)** for Milestone M3 Batch F: Pre-Limit Context Compaction, Rolling Conversation Summaries (Migration `014`), Emotion-Weighted Memory Importance, Temporal Fact Evolution, 1-Click Chat Bubble Bookmark & Manual Compaction UI, `clear_expires_at` Promote Hardening, and Batch E Review Fixes (archived tracker: [`task-feature-m3-context-compaction-memory-f.md`](../../01_Tracking/archive/task-feature-m3-context-compaction-memory-f.md)).
- [`plan-m3-memory-knowledge-e.md`](../01_Plans/plan-m3-memory-knowledge-e.md) — Delivered implementation plan for Milestone M3 Batch E: Memory & Knowledge Architecture V2 (3-Tier Separation, Migration 013 `trigger_keywords` & `recall_count`, 72h context TTL, explicit intent boost, Fixed Knowledge protection, stem/prefix keyword lorebooks, 4-section XML prompt context, Option 2A Desktop UI; delivered via PR #39, commit `ea4441c`).
- [`plan-m3-emotion-mood-engine-d.md`](../01_Plans/plan-m3-emotion-mood-engine-d.md) — Delivered implementation plan for Milestone M3 Batch D: Persistent Bounded Emotion & Mood Engine, Pre-Generation Turn Appraisal, Natural Companion Grounding, and Live Mood UI (`PC-CHAR-003`, `PC-CHAR-004`, `PC-CLIENT-006`, `PC-CLIENT-007`; delivered via PR #38, commit `fde6341`).
- [`plan-m3-memory-ui-c3.md`](../01_Plans/plan-m3-memory-ui-c3.md) — Delivered implementation plan for Milestone M3 Batch C3: Desktop Memory Control Center UI, Migration 011 Per-Profile Extraction Toggle, and Conflict Resolution (`PC-CLIENT-009`; delivered via PR #37, commit `64ac521`).
- [`plan-m3-memory-extraction-c2.md`](../01_Plans/plan-m3-memory-extraction-c2.md) — Delivered implementation plan for Milestone M3 Batch C2: Selective Automatic Memory Extraction & Deterministic Slot Reconciliation (`PC-MEM-002`; delivered via PR #36, commit `f7de198`).
- [`plan-m3-memory-foundation-c1.md`](../01_Plans/plan-m3-memory-foundation-c1.md) — Delivered implementation plan for Milestone M3 Batch C1: Memory Foundation, Scoping & Context Assembly (`PC-MEM-001`, `PC-MEM-003`, `PC-MEM-005`, `PC-API-001`; delivered via PR #35, commit `b3d31d7`).
- [`plan-m2-profile-deletion-recovery-d.md`](../01_Plans/plan-m2-profile-deletion-recovery-d.md) — Delivered implementation plan for Milestone M2 Batch D: Recoverable Profile Deletion & Safe Purge (`PC-IDENTITY-005`, `PC-CLIENT-005`; delivered via PR #34, commit `f3752a3`).
- [`plan-m2-profile-admin-c.md`](../01_Plans/plan-m2-profile-admin-c.md) — Delivered implementation plan for Milestone M2 Batch C: Local Profile Administration & Persistent Selection (`PC-IDENTITY-004`, `PC-CLIENT-005`; delivered via PR #33, commit `2104d5c`).
- [`plan-m3-character-studio-personality-b.md`](../01_Plans/plan-m3-character-studio-personality-b.md) — Implementation plan for Milestone M3 Batch B: Immersive Character Studio V1 & 8-Trait Personality Prompt Modulator (`PC-CHAR-002`, `PC-CLIENT-007`; Implementation Gate passed, human Windows acceptance passed, Stage 5 provisional closure authorized on `feature/m3-character-studio-personality-b`, not yet merged into develop).
- [`plan-m3-character-foundation-a.md`](../01_Plans/plan-m3-character-foundation-a.md) — Delivered implementation plan for Milestone M3 Batch A: Character Templates, Profile Instances & Neutral Fallback (`PC-CHAR-001`, `PC-CHAR-005`; delivered via PR #29, commit `d22dd7e`).
- [`plan-m2-profile-foundation-b.md`](../01_Plans/plan-m2-profile-foundation-b.md) — Delivered implementation plan for Batch B Profile Sessions, authorization and cross-Profile isolation (`PC-IDENTITY-002`; delivered via PR #27, commit `5cb2fe6`, stabilized in PR #28, commit `0bb0894`).
- [`plan-m2-profile-foundation-a.md`](../01_Plans/plan-m2-profile-foundation-a.md) — Delivered implementation plan for Milestone M2 Batch A: Profile Foundation & Migration 007 (`PC-IDENTITY-001`, `PC-RESILIENCE-002`; delivered via PR #25, commit `369d787`).
- [`plan-m2-h1-windows-runtime-supervision.md`](../01_Plans/plan-m2-h1-windows-runtime-supervision.md) — Delivered implementation plan for M2-H1 / PC-HOST-001: Windows Runtime Launch, Attach & Supervision (Delivered via PR #24, commit `d0f96fc`).
- [`plan-desktop-chat-quality-followup.md`](../01_Plans/plan-desktop-chat-quality-followup.md) — Delivered quality follow-up implementation plan for PC-CLIENT-006 / PC-CLIENT-010: Desktop Chat Quality (Delivered via PR #24, commit `d0f96fc`).
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
