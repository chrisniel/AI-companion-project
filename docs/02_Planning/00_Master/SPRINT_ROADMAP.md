# AI Companion — PC V1 Strategic Sprint Roadmap

> **Document Role:** High-level strategic milestone sequencing for the AI Companion PC V1 product delivery.  
> **Status:** Active Canonical Roadmap  
> **Authority Precedence:** Replaces and supersedes historical monolithic roadmaps. Active sprint execution is tracked in [`docs/01_Tracking/task.md`](../../01_Tracking/task.md). Detailed feature steps reside in active plans under [`docs/02_Planning/01_Plans/`](../01_Plans/).

---

## 1. Milestone Delivery Timeline

```text
┌─────────────────────────────────────────────────────────────┐
│ M0: Docs & Architecture Reset                               │ ◄── [ACTIVE]
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ M1: Flutter Desktop Client Foundation                       │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ M2: PC Companion Foundation (Host, Multi-Profile, D6 Model) │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ M3: Intelligence & Productivity (Personality, Memory, Sched)│
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ M4: Voice, Tools & Current Information (Barge-in, D9, Web)  │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ M5: Integration, Resilience & Hardening (Gaming, Backup)    │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ GATE-PC-V1: Integrated Golden PC V1 Acceptance Gate         │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
                     [PC V1 RELEASE TAG]
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ POST-V1: Dedicated Android / Mobile Architecture Pass       │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Milestone Objectives & Exit Criteria

### Milestone M0: Documentation & Architecture Reset (Current)
- **Primary Objective:** Execute the documentation canonicalization handoff, establish the master planning spine (`00_Master/`), update `SYSTEM_BASELINE.md` into a compact cross-cutting anchor, reconcile 18 focused domain specs, codify new ADRs (ADR-0017..0019), author `DELIVERY_WORKFLOW.md`, update setup/testing guides, and verify fresh-agent startup routing.
- **Exit Criteria:** All validation gates pass; zero stale React-primary or single-user contradictions; clean fresh-agent review report approved by Chris and GPT.

### Milestone M1: Flutter Desktop Client Foundation
- **Primary Objective:** Scaffold the production Flutter Windows Desktop client (`target Flutter path established during PC-CLIENT-001 scaffolding`), establish window lifecycle and system tray integration (minimize-to-tray, close-to-tray), build the SoftGlass design system with dark/light theme tokens, and integrate the OpenAPI-derived Dart API client and SSE token streaming consumer.
- **Exit Criteria:** Flutter Desktop client runs on Windows, communicates reliably with Local AI Runtime over localhost REST/SSE, displays live streaming text, and maintains visual parity with core desktop requirements. React Web remains fully operational as test oracle.

### Milestone M2: PC Companion Foundation (Host, Identity & Model Pipeline)
- **Primary Objective:** Implement Windows Task Scheduler autostart at user login, native Windows Action Center Toast presentation, storage roots manager (`APP_INSTALL`, `DATA`, `LIBRARY`), Account/Multi-Profile DB schema migration (`profile_id`), Profile isolation middleware, and the D6 manual scan / bundle model import service.
- **Exit Criteria:** Runtime launches at login without console window; Toast notifications alert closed-browser; D6 imports paired GGUF+mmproj models into relocatable library; multiple Profiles operate strictly isolated with PIN challenge.

### Milestone M3: Companion Intelligence & Productivity
- **Primary Objective:** Implement Character Studio and personality configuration with 8 continuous traits (0–100), persistent bounded mood simulation with time-based rebalancing, Profile/Character scoped memory with selective automatic extraction and temporary revalidation, and the `SchedulerService` engine with distinct Task, Reminder, Alarm, and Routine lifecycles.
- **Exit Criteria:** Personalities distinctively modulate conversational tone; mood persists across runtime restarts without altering functional correctness; memories automatically capture clear facts under deterministic policy; alarms and reminders trigger accurately with quiet hours support.

### Milestone M4: Voice, Tools & Current Information
- **Primary Objective:** Implement the conversational voice pipeline with native Flutter audio capture/playback, local STT (e.g., whisper.cpp) and TTS (e.g., Kokoro-82M) candidate adapters, duplex WebSocket transport, mandatory voice barge-in with immediate playback cancellation, the D9 deterministic 5-stage action policy engine, and read-only WebSearch/WebFetch/Weather integrations with strict SSRF containment.
- **Exit Criteria:** Consented spoken voice conversation functions with instant barge-in interruption; D9 policy engine intercepts model tool intents under DEFAULT DENY and requires explicit user confirmation for Risk 2; read-only web information successfully provides fresh context with clear source provenance.

### Milestone M5: Integration, Resilience & Hardening
- **Primary Objective:** Implement the host-level Low-Impact / Gaming resource controller with Option B configured app detection and compatible lightweight local text model (e.g., 1B-3B) substitution, coordinated DB+Profile asset backup with pre-migration hooks and verified staging restore, local admin Factory Reset, Tailscale / Cloudflare Tunnel connection hardening, and pre-release test suite stabilization.
- **Exit Criteria:** Gaming mode activates reliably on configured app focus, throttling background work and swapping to lightweight model without losing conversation continuity; backup produces verified recoverable archives; Factory Reset cleanly resets companion to first-run state; all Level 1 CI verification lanes pass cleanly.

### GATE-PC-V1: Golden PC V1 Acceptance Gate
- **Primary Objective:** Execute the comprehensive, 14-group end-to-end integrated release validation journey on the physical reference Windows workstation with live hardware, models, audio, and notification delivery.
- **Exit Criteria:** All 14 Golden acceptance checkpoint groups pass with documented verification evidence; zero unhandled crashes or data integrity violations; formal release evidence recorded.

### Post-PC-V1: Dedicated Android / Mobile Architecture Pass
- **Primary Objective:** Formally unfreeze and redesign mobile architecture for production Android Companion. The mobile architecture is DEFERRED to a separate architecture pass. Precommitments to Room/outbox, compact mobile LLMs, or Health Connect are removed from this roadmap.

**Preserved Mobile Inputs Only:**
- Package: com.cnl.aicompanion.
- Flutter is the intended production foundation.
- Android development does not block PC V1 delivery.
- One satellite device binds to exactly one Profile.
- Provider/API/device credentials remain device-local.
- Current Kotlin repository code serves strictly as prototype/reference evidence.
- **Exit Criteria:** Approved Mobile System Baseline and Mobile WBS ready for implementation. Does not block PC V1.
