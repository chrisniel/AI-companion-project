# AI Companion — Canonical System Baseline & Architecture Core

> **Document Role:** High-level normative system architecture, ecosystem topology, release boundaries, cross-cutting invariants, and decision index for the AI Companion project.  
> **Status:** Active Canonical (Decisions D1–D16 Aligned)  
> **Last Updated:** 2026-10-02 (PC V1 Canonicalization Pass)  
> **Authority Precedence:** Normative cross-cutting anchor. Detailed technical domain standards are owned by the 18 focused specifications under [`docs/04_Architecture/`](./README.md). Milestone delivery tracking is owned by [`docs/02_Planning/00_Master/`](../02_Planning/00_Master/). Active sprint state is tracked in [`docs/01_Tracking/task.md`](../01_Tracking/task.md).

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
│                      Windows Host Runtime                       │
│             FastAPI • Python 3.13 • SQLite (WAL/FTS5)           │
│                                                                 │
│  Assistant • Turn Queue • Memory • Schedulers • Actions • Voice │
│                   Single Resident Model Default                 │
└─────────────────────────────────┬───────────────────────────────┘
                                  ▲
                                  │ Local LAN / Tailscale
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                Android Companion App (Prototype)                │
│         Kotlin • Jetpack Compose • Follow-on Milestone          │
└─────────────────────────────────────────────────────────────────┘
```

### Subsystem Summary
- **Windows Host Runtime:** Persistent FastAPI background process (`backend/`). The single authority for state, multi-turn queue, SQLite+FTS5 persistence, model execution, deterministic action policies, and speech engines.
- **Flutter Desktop (Windows):** Primary production client for PC V1 (`ADR-0017`). Owns desktop window lifecycle, system tray integration, native Windows notifications, and physical audio capture/playback.
- **React Web Client:** Supported web client and development / regression harness (`frontend/web/`). Provides full feature parity for browser-based testing, debugging, and administration.
- **Android Companion:** Dedicated mobile companion prototype (`android/`, `com.cnl.aicompanion`). Scheduled for production delivery in an independent follow-on milestone (`Android V1`).

---

## 2. Release Vocabulary & Boundaries

- **`PC V1` (unqualified "AI Companion V1"):** Mandatory delivery milestone for the PC-hosted ecosystem release.
- **`PC LATER`:** Approved PC capabilities postponed beyond PC V1 (e.g., wake word, vector memory, Live2D/VRM, managed model downloader).
- **`ANDROID V1`:** Independent follow-on mobile companion release. Does **not** block PC V1.
- **`ANDROID LATER` / `FUTURE`:** Post-Android-V1 mobile features and exploratory research.
- **`REJECTED`:** Explicitly excluded capabilities (e.g., generic shell execution, direct router port forwarding).

---

## 3. Cross-Cutting Architectural Invariants

1. **Local-First Default:** All core intelligence runs locally on user hardware. Cloud LLM fallback is strictly opt-in, disabled by default, and transparent.
2. **Runtime Independence:** Closing the UI (Flutter or browser) hides to system tray and never terminates the Windows Host Runtime (`ADR-0002`). Quit UI != Stop Runtime.
3. **Multi-Profile PC V1 Identity:** Operates under a single installation Account with multiple isolated Profiles (`ADR-0018`). Normal satellite devices bind to a single profile; PC desktop admin can manage and switch profiles.
4. **Transparent, User-Controlled Memory:** Selective auto-extraction under deterministic policy (`ADR-0007`). Memories are scoped to `PROFILE` or `CHARACTER`, inspectable, and user-correctable.
5. **Deterministic Action Policy & DEFAULT DENY:** Model requests are typed intents evaluated against deterministic policy (`ADR-0009`). Risk 0/1/2 configurable; Risk 3 generic shell execution is permanently rejected (`REJECTED`). Emergency kill switch provided.
6. **Single Resident Model Default:** Runtime defaults to `--models-max 1` to preserve resources for concurrent desktop workloads (`ADR-0006`). Multi-model concurrency requires explicit opt-in in Advanced Settings.
7. **Storage Layout:** Standardized across 5 discrete directory roots: `APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT` (relocatable), `CACHE_ROOT`, and `LOG_ROOT` (`ADR-0015`).
8. **Network Boundary:** Loopback default + Tailscale private mesh + Cloudflare Tunnel/Access (`ADR-0005`). Direct port forwarding is outside the supported trust model.
9. **Clean Client-Runtime Contract:** REST for commands/queries, SSE for token streams and typed events, WebSocket for full-duplex voice (`ADR-0019`). Durable FIFO turn queue survives transient client disconnects.
10. **Native Voice Architecture:** Flutter desktop owns physical audio hardware; Windows Host Runtime owns STT (`whisper.cpp`) and TTS (`Kokoro-82M`) speech engines over WebSocket. Voice barge-in is mandatory.

---

## 4. Master Decision Register & ADR Index

The system baseline codifies the 16 core architectural decisions approved for PC V1:

| Decision | Topic | Canonical Policy & Chosen Architecture | Key Spec / ADR |
| :--- | :--- | :--- | :--- |
| **D1** | Scope Boundary | PC V1 mandatory milestone; Android V1 independent follow-on | `SYSTEM_BASELINE.md`, [`ADR-0001`](decisions/ADR-0001-two-tier-release-boundary.md) |
| **D2** | Host Lifecycle | Windows Host Runtime independent background service; Task Scheduler at login | `windows-host-and-notifications.md`, [`ADR-0002`](decisions/ADR-0002-windows-background-runtime-and-browser-independence.md) |
| **D3** | Android Identity | Package `com.cnl.aicompanion`; Android V1 follow-on milestone | `android-companion.md`, [`ADR-0003`](decisions/ADR-0003-android-application-identity-and-lifecycle.md) |
| **D4** | Device Auth | Device tokens, Android Keystore, mutual handshake, revocable access | `authentication-and-secrets.md`, [`ADR-0004`](decisions/ADR-0004-device-authentication-and-trust-model.md) |
| **D5** | Remote Access | Loopback default + Tailscale private mesh + Cloudflare Tunnel; no port forwarding | `authentication-and-secrets.md`, [`ADR-0005`](decisions/ADR-0005-tailscale-preferred-remote-transport.md) |
| **D6** | Model Import | Controlled scan import: inbox → preflight → staging → atomic install → registry | `runtime-and-models.md`, [`ADR-0006`](decisions/ADR-0006-controlled-local-model-import-pipeline.md) |
| **D7** | Memory Model | Profile-first, selective extraction, user-visible & correctable, FTS5 lexical baseline | `memory-and-personalization.md`, [`ADR-0007`](decisions/ADR-0007-profile-first-memory-and-selective-automatic-persistence.md) |
| **D8** | Multi-Profile | Single Account, multiple isolated Profiles; satellite device binds to 1 Profile | `profiles-and-devices.md`, [`ADR-0018`](decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md) |
| **D9** | Tool Security | Deterministic policy, DEFAULT DENY; Risk 0/1/2 configurable; Risk 3 shell rejected | `tool-permissions-and-actions.md`, [`ADR-0009`](decisions/ADR-0009-tool-security-and-deterministic-policy.md) |
| **D10** | Productivity | Distinct Task / Reminder / Alarm / Routine semantics; native Windows notifications | `tasks-reminders-alarms-and-routines.md`, [`ADR-0010`](decisions/ADR-0010-productivity-entity-semantics-and-scheduler-architecture.md) |
| **D11** | Persona/Emotion | Character Template vs. Instance; 8 continuous traits; bounded mood survives restart | `characters-personality-and-emotion.md`, [`ADR-0011`](decisions/ADR-0011-character-persona-and-emotion-state-architecture.md) |
| **D12** | Storage Layout | 5 storage roots; relocatable `LIBRARY_ROOT`; atomic migrations and snapshots | `storage-and-assets.md`, [`ADR-0015`](decisions/ADR-0015-storage-roots-and-asset-hierarchy.md) |
| **D13** | Client Target | Flutter Desktop (Win) primary PC V1 UI; React Web supported dev/test harness | `windows-host-and-notifications.md`, [`ADR-0017`](decisions/ADR-0017-flutter-production-windows-client.md) |
| **D14** | Contract Boundary | REST commands/queries, SSE token stream, WebSocket voice; durable turn queue | `assistant-and-conversations.md`, [`ADR-0019`](decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md) |
| **D15** | Voice Pipeline | Audio hardware on client; local STT (`whisper.cpp`) & TTS (`Kokoro-82M`) on runtime | `voice-and-audio.md`, [`ADR-0014`](decisions/ADR-0014-voice-and-audio-subsystem-architecture.md) |
| **D16** | Gaming Profile | Normal / Low Impact / Auto (app list); 1B–3B text model substitution option | `performance-and-capacity.md`, [`ADR-0016`](decisions/ADR-0016-gaming-and-low-impact-resource-profiles.md) |

---

## 5. Golden PC V1 Acceptance Gate (14 Verification Groups)

Full PC V1 release readiness requires end-to-end evidence across 14 verification groups:

1. **Host Lifecycle & Packaging:** Silent autostart at login, tray minimization, crash recovery.
2. **Client Shell Parity:** Flutter desktop primary UI, tray menu, window persistence, React Web dev parity.
3. **Turn Queue & Streaming:** Multi-turn queuing, token streaming via SSE, disconnect recovery.
4. **Local Text & Vision Models:** Single resident model offload on RX 580 baseline, multimodal image attachment comprehension.
5. **Model Import Pipeline:** Controlled inbox scan, preflight validation, atomic installation.
6. **Multi-Profile Isolation:** Profile switching, per-profile memory and chat partitioning.
7. **Persona, Traits & Mood:** 8 continuous traits, persistent bounded mood decay, neutral fallback.
8. **Memory Lifecycle:** FTS5 lexical recall, selective extraction under policy, user edit/delete.
9. **Productivity Scheduling:** Distinct Task/Reminder/Alarm/Routine execution, native Windows notifications.
10. **Deterministic Actions:** DEFAULT DENY, Risk 0 auto-run, Risk 1 prompt, Risk 3 block, emergency kill switch.
11. **Duplex Voice Pipeline:** Local STT + TTS over WebSocket, voice barge-in interruption.
12. **Web Information & Safety:** Web search/fetch/weather with SSRF containment and untrusted rendering.
13. **Resilience & Storage:** Coordinated SQLite+asset backup, staged restore verification, factory reset.
14. **Gaming & Resource Throttling:** Low-Impact mode switching and resource preservation under load.

---

## 6. Canonical Domain Specifications Index

Detailed normative requirements are defined in the 18 focused specifications:

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
