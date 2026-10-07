# AI Companion — Canonical System Baseline & Architecture Core

> **Document Role:** High-level normative system architecture, ecosystem topology, release boundaries, cross-cutting invariants, and decision index for the AI Companion project.
> **Status:** Active Canonical (Decisions D1-D11 Aligned)
> **Last Updated:** 2026-10-04 (Mobile V1 Planning & Documentation Integration)
> **Authority Precedence:** Normative cross-cutting anchor. Detailed technical domain standards are owned by the 20 focused specifications under [`docs/04_Architecture/`](./README.md). Milestone delivery tracking is owned by [`docs/02_Planning/00_Master/`](../02_Planning/00_Master/). Active sprint state is tracked in [`docs/01_Tracking/task.md`](../01_Tracking/task.md).

---

## 1. Product Identity & Ecosystem Topology

The AI Companion ecosystem is centered around an independent, persistent Windows host runtime serving desktop, web, and mobile companion clients:

```text
┌─────────────────────────────────────────────────────────────────┐
│                          Client Layer                           │
│                                                                 │
│   ┌───────────────────────────┐   ┌─────────────────────────┐   │
│   │   Flutter Desktop (Win)   │   │    React Web Client     │   │
│   │  • Primary PC V1 Target   │   │  • Dev / Test Harness   │   │
│   │  • System Tray & Shell    │   │  • Web Control Center   │   │
│   │  • Hardware Audio Owner   │   │  • Diagnostic Dashboard │   │
│   └─────────────┬─────────────┘   └────────────┬────────────┘   │
│                 │ REST / SSE / WS              │ REST / SSE     │
└─────────────────┼──────────────────────────────┼────────────────┘
                  │                              │
                  ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Local AI Runtime                         │
│             FastAPI • Python 3.11 • SQLite (WAL/FTS5)           │
│                                                                 │
│  ┌───────────┐  ┌─────────────┐  ┌─────────────┐ ┌───────────┐  │
│  │ D10 Sched │  │ D7 Memories │  │ D9 Policies │ │  Models   │  │
│  └───────────┘  └─────────────┘  └─────────────┘ └─────┬─────┘  │
└────────────────────────────────────────────────────────┼────────┘
                                                         │
                                                         ▼
                                       ┌──────────────────────────┐
                                       │ Local Inference Engine   │
                                       │ (e.g., llama.cpp/Vulkan) │
                                       └──────────────────────────┘
```

### Subsystem Summary
- **Local AI Runtime:** Persistent FastAPI background process (`backend/`). The single authority for state, multi-turn queue, SQLite+FTS5 persistence, model execution, deterministic action policies, and speech engines.
- **Flutter Desktop (Windows):** Primary production client for PC V1 (`ADR-0017`). Owns desktop window lifecycle, system tray integration, native Windows notifications, and physical audio capture/playback.
- **React Web Client:** Supported web client and development / regression harness (`frontend/web/`). Provides browser-based testing, debugging, and administration.
- **Android Companion:** CURRENT IMPLEMENTED PROTOTYPE: Kotlin/Compose under `android/` using interim package identifiers. TARGET MOBILE PRODUCTION IDENTITY: Flutter production mobile target using `com.cnl.aicompanion` (D3). Scheduled for production delivery in an independent follow-on milestone (`Android V1`). Mobile V1 includes a production-capable device-local LLM execution path for qualified devices (`D-PHONE-01`, `D-PHONE-03`). Individual supported phones do not all need to qualify; core non-generative companion features (alarms, reminders, schedules, and presence shell) survive completely without a local LLM (`D-PHONE-02`). The PC Host remains the master runtime for complex orchestration and heavy local models.

---

## 2. Release Vocabulary & Boundaries

- **`PC V1` (unqualified "AI Companion V1"):** Mandatory delivery milestone for the PC-hosted ecosystem release.
- **`PC LATER`:** Approved PC capabilities postponed beyond PC V1 (e.g., wake word, vector memory, Live2D/VRM, managed model downloader).
- **`ANDROID V1`:** Independent follow-on mobile companion release. Includes a production-capable device-local LLM execution path on qualified devices (`D-PHONE-01`, `D-PHONE-03`), while ensuring full core companion survival on non-qualifying devices (`D-PHONE-02`). Does **not** block PC V1.
- **`ANDROID LATER` / `FUTURE`:** Post-Android-V1 mobile features and exploratory research.
- **`REJECTED`:** Explicitly excluded capabilities (e.g., generic shell execution, direct router port forwarding).

---

## 3. Cross-Cutting Architectural Invariants

1. **Local-First Default:** All core intelligence runs locally on user hardware. Cloud LLM fallback is strictly opt-in, disabled by default, and transparent.
2. **Runtime Independence:** Closing the Flutter UI hides to the system tray. Closing the React browser tab simply disconnects. Neither action terminates the Local AI Runtime (`ADR-0003`). Quit UI != Stop Runtime.
3. **Multi-Profile PC V1 Identity:** Operates under a single installation Account with multiple isolated Profiles (`ADR-0018`). Normal satellite devices bind to a single profile; PC desktop admin can manage and switch profiles.
4. **Transparent, User-Controlled Memory:** Selective auto-extraction under deterministic policy (`ADR-0008`). Memories are scoped to `PROFILE` or `CHARACTER`, inspectable, and user-correctable.
5. **Deterministic Action Policy & DEFAULT DENY:** Model requests are typed intents evaluated against deterministic policy (`ADR-0010`). Risk 0/1/2 configurable; Risk 3 generic shell execution is permanently rejected (`REJECTED`). Emergency kill switch provided.
6. **Single Resident Model Default:** Runtime defaults to `--models-max 1` to preserve resources for concurrent desktop workloads. Multi-model concurrency is an approved advanced policy with capacity checks documented in `runtime-and-models.md`.
7. **Storage Layout:** Standardized across 5 discrete directory roots: `APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT` (relocatable), `CACHE_ROOT`, and `LOG_ROOT`.
8. **Network Boundary:** Loopback default + Tailscale private mesh + Cloudflare Tunnel/Access (`ADR-0006`). Direct port forwarding is outside the supported trust model.
9. **Clean Client-Runtime Contract:** REST for commands/queries, SSE for token streams and typed events, WebSocket for full-duplex voice (`ADR-0019`). Durable FIFO turn queue survives transient client disconnects.
10. **Native Voice Architecture:** Flutter desktop owns physical audio hardware; Local AI Runtime owns STT and TTS speech engines over WebSocket. Voice barge-in is mandatory.

---

## 4. Master Decision Register & ADR Index

The historical product decision spine is D1-D11. Additional accepted ADRs refine or supersede that spine where explicitly recorded.

| Decision | Topic | Canonical Policy & Chosen Architecture | Key Spec / ADR |
| :--- | :--- | :--- | :--- |
| **D1** | Scope Boundary | PC V1 mandatory milestone; Android V1 independent follow-on | `SYSTEM_BASELINE.md`, [ADR-0002](decisions/ADR-0002-d1-pc-v1-release-boundary.md) |
| **D2** | Host Lifecycle | Local AI Runtime independent background service; Task Scheduler at login | [`windows-host-and-notifications.md`](04_Infrastructure/windows-host-and-notifications.md), [ADR-0003](decisions/ADR-0003-d2-windows-host-model.md) |
| **D3** | Android Identity | Package com.cnl.aicompanion; Android V1 follow-on milestone | [`android-companion.md`](01_Domains/android-companion.md), [ADR-0004](decisions/ADR-0004-d3-android-application-identity.md) |
| **D4** | Device Auth | Profile/Device separation, profile-bound enrollment, revocable credentials, platform-protected local secret storage | [`profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md), [ADR-0005](decisions/ADR-0005-d4-profile-device-credential-boundary.md) |
| **D5** | Remote Access | Loopback default + Tailscale private mesh + Cloudflare Tunnel; no port forwarding | [`authentication-and-secrets.md`](02_Data_and_Security/authentication-and-secrets.md), [ADR-0006](decisions/ADR-0006-d5-remote-access-trust-boundary.md) |
| **D6** | Model Import | Controlled scan import: inbox → preflight → staging → atomic install → registry | [`runtime-and-models.md`](04_Infrastructure/runtime-and-models.md), [ADR-0007](decisions/ADR-0007-d6-controlled-model-acquisition.md) |
| **D7** | Memory Model | Profile-first, selective extraction, user-visible & correctable, FTS5 lexical baseline | [`memory-and-personalization.md`](01_Domains/memory-and-personalization.md), [ADR-0008](decisions/ADR-0008-d7-profile-first-memory-ownership.md) |
| **D8** | Single Primary User | (Historical / Superseded) SUPERSEDED by ADR-0018 | [`profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md), [ADR-0009](decisions/ADR-0009-d8-single-primary-user-baseline.md), [ADR-0018](decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md) |
| **D9** | Tool Security | Deterministic policy, DEFAULT DENY; Risk 0/1/2 configurable; Risk 3 shell rejected | [`tool-permissions-and-actions.md`](02_Data_and_Security/tool-permissions-and-actions.md), [ADR-0010](decisions/ADR-0010-d9-typed-tool-security-policy.md) |
| **D10** | Productivity | Distinct Task / Reminder / Alarm / Routine semantics; native Windows notifications | [`tasks-reminders-alarms-and-routines.md`](01_Domains/tasks-reminders-alarms-and-routines.md), [ADR-0011](decisions/ADR-0011-d10-scheduling-and-notification-semantics.md) |
| **D11** | Persona/Emotion | Character Template vs. Instance; 8 continuous traits; bounded mood survives restart | [`characters-personality-and-emotion.md`](01_Domains/characters-personality-and-emotion.md), [ADR-0012](decisions/ADR-0012-d11-persona-and-state-separation.md) |

---

## 5. Golden PC V1 Acceptance Gate (14 Verification Groups)

Full PC V1 release readiness requires end-to-end evidence across 14 verification groups:

- G1 Installation / startup / process lifecycle
- G2 Account / multi-Profile / privacy isolation
- G3 Runtime / models / D6
- G4 Conversation / durable queues / multimodal
- G5 Character / Personality / Emotion
- G6 Memory / historical continuity
- G7 Typed actions / D9 policy
- G8 Scheduler / native notifications
- G9 Voice / real barge-in
- G10 Current information / web security
- G11 Local-only + optional cloud
- G12 Low-Impact / Gaming
- G13 Backup / deletion / restore / Factory Reset
- G14 Remote client + final resilience

---

## 6. Cross-Cutting Mobile Baseline

- [`MOBILE_SYSTEM_BASELINE.md`](MOBILE_SYSTEM_BASELINE.md) (Mobile Ecosystem Boundary)

---

## 7. Canonical Domain Specifications Index

Detailed normative requirements are defined in the 20 focused specifications:

- **01 Domains:**
  - [`01_Domains/assistant-and-conversations.md`](01_Domains/assistant-and-conversations.md)
  - [`01_Domains/characters-personality-and-emotion.md`](01_Domains/characters-personality-and-emotion.md)
  - [`01_Domains/memory-and-personalization.md`](01_Domains/memory-and-personalization.md)
  - [`01_Domains/tasks-reminders-alarms-and-routines.md`](01_Domains/tasks-reminders-alarms-and-routines.md)
  - [`01_Domains/voice-and-audio.md`](01_Domains/voice-and-audio.md)
  - [`01_Domains/multimodal-and-media.md`](01_Domains/multimodal-and-media.md)
  - [`01_Domains/android-companion.md`](01_Domains/android-companion.md)
- **02 Data and Security:**
  - [`02_Data_and_Security/profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md)
  - [`02_Data_and_Security/authentication-and-secrets.md`](02_Data_and_Security/authentication-and-secrets.md)
  - [`02_Data_and_Security/tool-permissions-and-actions.md`](02_Data_and_Security/tool-permissions-and-actions.md)
  - [`02_Data_and_Security/privacy-retention-and-audit.md`](02_Data_and_Security/privacy-retention-and-audit.md)
- **03 Integrations:**
  - [`03_Integrations/web-current-information.md`](03_Integrations/web-current-information.md)
  - [`03_Integrations/health-and-wearables.md`](03_Integrations/health-and-wearables.md)
- **04 Infrastructure:**
  - [`04_Infrastructure/runtime-and-models.md`](04_Infrastructure/runtime-and-models.md)
  - [`04_Infrastructure/storage-and-assets.md`](04_Infrastructure/storage-and-assets.md)
  - [`04_Infrastructure/windows-host-and-notifications.md`](04_Infrastructure/windows-host-and-notifications.md)
  - [`04_Infrastructure/backup-recovery-and-diagnostics.md`](04_Infrastructure/backup-recovery-and-diagnostics.md)
  - [`04_Infrastructure/performance-and-capacity.md`](04_Infrastructure/performance-and-capacity.md)
  - [`04_Infrastructure/mobile-offline-and-sync.md`](04_Infrastructure/mobile-offline-and-sync.md)
  - [`04_Infrastructure/mobile-capabilities-and-runtime.md`](04_Infrastructure/mobile-capabilities-and-runtime.md)
