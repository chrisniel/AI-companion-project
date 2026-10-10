# AI Companion — PC V1 Strategic Sprint Roadmap

> **Document Role:** High-level strategic milestone sequencing for the AI Companion PC V1 product delivery.
> **Status:** Active Canonical Roadmap
> **Authority Precedence:** Replaces and supersedes historical monolithic roadmaps. Active sprint execution is tracked in [`docs/01_Tracking/task.md`](../../01_Tracking/task.md). Detailed feature steps reside in active plans under [`docs/02_Planning/01_Plans/`](../01_Plans/).

---

## 1. Milestone Delivery Timeline

```text
┌─────────────────────────────────────────────────────────────┐
│ M0: Docs & Architecture Reset                               │ ◄── [COMPLETE / VERIFIED]
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ MOBILE-ARCH: Phone/Mobile V1 Canonical Architecture Pass    │ ◄── [COMPLETE / VERIFIED]
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ M1: Flutter Desktop Client Foundation                       │ ◄── [COMPLETE / SQUASH-MERGED (PR #23)]
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ M2: PC Companion Foundation (Host, Multi-Profile, D6 Model) │ ◄── [IN PROGRESS / PLANNING — M2-H1]
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
```

---

## 2. Milestone Objectives & Exit Criteria

### Milestone M0: Documentation & Architecture Reset (COMPLETE / VERIFIED)
- **Primary Objective:** Execute the documentation canonicalization handoff, establish the master planning spine (`00_Master/`), update `SYSTEM_BASELINE.md` into a compact cross-cutting anchor, reconcile 18 focused domain specs, codify new ADRs (ADR-0017..0019), author `DELIVERY_WORKFLOW.md`, update setup/testing guides, and verify fresh-agent startup routing.
- **Exit Criteria:** All validation gates pass; zero stale React-primary or single-user contradictions; clean fresh-agent review report approved by Chris and GPT.

### MOBILE-ARCH: Phone/Mobile V1 Canonical Architecture Pass (COMPLETE / VERIFIED)
- **Primary Objective:** Canonicalize production Phone/Mobile architecture across Batches A–D by inheriting shared ecosystem rules and resolving mobile-specific constraints, responsibilities, resource limits, runtime behavior, sync/offline behavior, local inference, voice, health, vision, and Flutter sharing boundaries. Active promotion plan: [`plan-mobile-v1-batch-d-canonical-promotion.md`](../01_Plans/plan-mobile-v1-batch-d-canonical-promotion.md).

**Approved Mobile Architecture Summary:**
- **Shared Workspace Topology:** Shared Dart/Flutter monorepo with separate Desktop and Mobile application targets (`MOBILE_SYSTEM_BASELINE.md` §3, `ADR-0004`, `ADR-0017`, `D-SHARED-FLUTTER-01..08`).
- **Production Package Identity:** Locked `com.cnl.aicompanion`. The Kotlin Android prototype (`android/`) remains non-production reference evidence only (`D-PHONE-FLUTTER-01`).
- **Satellite Identity & Authority:** Mobile satellite binds to exactly one Profile; PC Host is sole Account/Profile Admin; Device Token and user API keys stored in Android Keystore (`ADR-0005`, `ADR-0018`, `D-PHONE-01B`).
- **Offline Persistence & Sync:** Relational SQLite local store with durable transactional outbox journal; client-generated stable entity IDs (UUIDv4); monotonic revision checks with typed `CONFLICT_DETECTED`; host-issued change cursor delta sync with `STALE_CURSOR` re-baseline (`mobile-offline-and-sync.md`).
- **Disconnected Conversation Reconciliation:** Qualified devices support offline local text turns; devices with authorized Cloud LLM support disconnected cloud turns; turns synchronized as atomic whole-turn units with execution-origin provenance (`MOBILE_LOCAL_INFERENCE` / `MOBILE_CLOUD_INFERENCE`) and `client_message_id` deduplication without Host LLM replay or tool replay (`mobile-offline-and-sync.md` §3.2.6, `D-SHARED-CONV-01..03A`).
- **Native Scheduling & Alarms:** Distinct Task, Reminder, Alarm, and Routine lifecycles; Mobile-created Reminders and Alarms authored offline (`D-PHONE-10`, `D-PHONE-11`); Host-created definitions read-only offline; cross-device presentation arbitration (`D-SHARED-SCHED-02`); bounded Routine occurrences presented offline (`D-PHONE-12..12E`); local `AlarmManager` exact alarms with `canScheduleExactAlarms()` degradation handling (`mobile-offline-and-sync.md` §6).
- **Capability-Dependent Local Inference:** Evidence-driven Tiers 0–3 runtime qualification; required production-capable local LLM execution path for qualified devices (`D-PHONE-01`); core app survives without local model (`D-PHONE-02`); single resident model cap (`--models-max 1`); LAN Host-to-Device transfer (`mobile-capabilities-and-runtime.md` §2).
- **Decoupled Voice & Barge-In:** Connected full-duplex Voice streaming to PC Runtime over WebSocket with mandatory immediate barge-in; local TTS decoupled from local STT and local LLM; cloud voice permissions separate (`mobile-capabilities-and-runtime.md` §3, `ADR-0019`, `D-PHONE-14..14G`).
- **Conditional Health & Vision:** Health Connect supported as `CONDITIONAL V1` read-only integration (`D-PHONE-15..15E`, `D-SHARED-HEALTH-01..04`); local still-image Vision supported as `CONDITIONAL V1` on qualified hardware (`D-PHONE-16..16E`, `D-SHARED-VISION-01`).
- **Deferred Non-Goals:** Autonomous Mobile Routine recurrence extension (`D-PHONE-12`) is excluded from V1; Health Connect is preferred (`D-PHONE-15E`) where direct vendor wearable integration is not normally V1-required but remains possible if Health Connect cannot supply an important approved source; continuous ambient camera streaming is excluded (`D-PHONE-16E`); background microphone eavesdropping / ambient listening is strictly prohibited (`D-PHONE-14F` / Voice privacy invariant); always-on wake word is deferred separately; AR Presence is deferred (`P-PHONE-AR-01`, `P-PHONE-AR-02`); and phone-to-phone canonical sync authority is not currently established (multi-phone topology remains OPEN DEBT).
- **Exit Criteria:** All validation gates pass; D2–D5 independently reviewed; Gate 4 Closure Gate PASSED at checkpoint `282f3607c6663cb72b34ad8f3596651aaf5ac18f`; PR #21 CI Run #84 green; PR #21 merged to develop (commit `28c4332`); active tracker archived; M1 unblocked.
- **Dependency Note:** Mobile production implementation is cataloged in [`MOBILE_WBS.md`](MOBILE_WBS.md) as an independent follow-on track that does NOT block PC V1. M1 Flutter Desktop foundation unblocked following merge of PR #21.

### Milestone M1: Flutter Desktop Client Foundation (COMPLETE / SQUASH-MERGED)
- **Primary Objective:** Scaffold the production Flutter Windows Desktop client monorepo pub workspace under `frontend/flutter/` (`companion_core`, `companion_api`, `companion_design`, and `apps/desktop`), establish native window lifecycle and system tray integration (minimize-to-tray, close-to-tray, tray restore/exit), build the SoftGlass / Neumorphic design system with dark/light theme tokens, integrate OpenAPI-derived Dart models and fail-closed authentication, implement chat conversation drawer with draft reuse, GFM Markdown tables, attachment placeholders, and post-turn AI title generation parity.
- **Exit Criteria:** Flutter Desktop client runs on Windows, communicates reliably with Local AI Runtime over localhost REST/SSE, displays live streaming text with Markdown rendering, handles fail-closed auth and model unreadiness, and passes all 193 workspace tests and native Win32 lifecycle checks. Delivered via PR #23 (commit `7c1d1a2ddb5c57ddaae9bbacbcab2e25f9938fe1`); Closure Gate passed with documented post-merge archival exception. React Web remains fully operational as test oracle.

### Milestone M2: PC Companion Foundation (Host, Identity & Model Pipeline)
- **Primary Objective:** Implement Windows Runtime launch & supervision (Batch M2-H1 / `PC-HOST-001` in active planning), followed by Windows Task Scheduler autostart at user login, native Windows Action Center Toast presentation, storage roots manager (`APP_INSTALL`, `DATA`, `LIBRARY`), Account/Multi-Profile DB schema migration (`profile_id`), Profile isolation middleware, and the D6 manual scan / bundle model import service.
- **Exit Criteria:** Runtime launches reliably and supervised as a detached background process with authenticated identification and safe termination; autostart configured at login without console window; Toast notifications alert closed-browser; D6 imports paired GGUF+mmproj models into relocatable library; multiple Profiles operate strictly isolated with PIN challenge.

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
