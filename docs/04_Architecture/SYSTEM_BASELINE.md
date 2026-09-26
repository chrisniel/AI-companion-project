# AI Companion — Canonical System Baseline & Architecture Core

> **Document Role:** High-level normative architecture and product baseline for AI Companion PC V1, Android V1, and future capabilities.
> **Status:** Active Canonical (Decisions D1–D11 Locked)
> **Last Updated:** 2026-09-26 (Reconciliation Pass R10 Decision Relock)

---

## 1. Product Identity & Subsystems

| Subsystem | Canonical Name | Implementation Stack | Current Repository Role |
| :--- | :--- | :--- | :--- |
| **Product** | **AI Companion** | Full-ecosystem | High-level personal AI companion project. |
| **Backend / Orchestration** | **Local AI Runtime** | Python 3.11, FastAPI, SQLite (WAL), SQLAlchemy 2, Alembic, `llama.cpp` (Vulkan) | Source of truth for inference, conversations, memory, tasks, models, scheduling, and device auth. |
| **Primary PC Client** | **React Web** | React 19, TypeScript 5.8, Vite 6, Tailwind CSS 4 | Desktop control center, runtime configuration, model management, live SSE streaming conversation. |
| **Mobile Client** | **Android Companion** | Kotlin, Jetpack Compose, Material 3, SoftGlass Neumorphic Engine | Verified mobile UI prototype; future production backend client and offline companion. |

> [!IMPORTANT]
> **Canonical Terminology Invariant:** The backend/orchestration subsystem is strictly titled the **Local AI Runtime**.
> The term *"PC Core"* was audit-era shorthand and is retired. It must **not** be used in canonical documentation or new code.

---

## 2. Release Boundary (Decision D1)

AI Companion formalizes platform-specific release vocabulary to ensure unambiguous delivery boundaries:

- **AI Companion V1 (unqualified):** Refers strictly to **PC V1** (the PC-hosted release).
- **PC V1:** The first complete, stable ecosystem release. PC-hosted, Local AI Runtime, React Web primary interface.
- **Android V1:** The follow-on production mobile companion release (`com.cnl.aicompanion`). Independent milestone; does **not** block PC V1.
- **PC LATER:** Approved PC capabilities scheduled for milestones following PC V1.
- **ANDROID LATER:** Approved Android capabilities scheduled after Android V1.
- **FUTURE / UNSCHEDULED:** Evaluated or experimental capabilities without committed release scheduling.

### 2.1 In Scope for PC V1
- **Local AI Runtime:** Independent Windows host process (Decision D2).
- **React Web Primary Client:** Desktop control center, model management, and streaming conversation.
- **Local Text LLM Inference:** Provider- and hardware-portable local text generation through the Local AI Runtime (`llama.cpp` Vulkan on AMD RX 580 represents the current verified baseline implementation, not a hardware-locked release constraint).
- **Multi-Turn Conversation Management:** Live SSE streaming token completions and transactional pre-stream turn binding.
- **Memory Persistence & Retrieval:** Profile-first memory persistence and retrieval under canonical user ownership (Decision D7). The durable requirement is persistent and retrievable memory; the current verified implementation uses SQLite with FTS5 lexical search, but FTS5 itself is not a permanent architectural constraint.
- **Selective Automatic Memory:** Assistant-proposed and selective automatic memory capture under deterministic policy, user visibility, and inspect/correct/delete controls (sensitive, ambiguous, or temporary statements must not silently become permanent facts; exact extraction model, confidence logic, cadence, and schema remain open design; Decision D7).
- **Tasks, Reminders, Alarms & Bounded Routines:** Distinct entity semantics under Decision D10. Task CRUD, soft-delete, and retention thresholds are implemented and verified in the baseline; scheduled reminder execution, time-critical alarm alerts, bounded companion routines, and native Windows notification delivery represent approved PC V1 target architecture (exact scheduler engine and schemas remain open design).
- **Model Library & Runtime Management:** Schema v3 registry, GGUF binary header parsing, runtime offload profiles (Eco/Balanced/Maximum).
- **Controlled Local Model Import Pipeline:** Deterministic import flow: `inbox` → `preflight` → `staging` → `atomic install` → `library` → `registry` (Decision D6).
- **Multimodal Vision Understanding:** Phase 8B image attachment API, validated upload guards, and vision-model inference.
- **Phase 8C Integration & Polish:** ARIA keyboard accessibility, bundle optimization, UI consistency, and responsive desktop web cleanup.
- **Conversational Voice (without Wake Word):** Local audio capture, provider-independent STT, provider-independent TTS, and VAD / turn detection where required.
- **Character Persistence & Persona Separation:** Persistent Character configuration under PC host authority (Decision D11; exact database schema remains open design).
- **Separate Personality Configuration:** Behavioral traits and communication style decoupled from character lore (Decision D11).
- **Lightweight Conceptual Emotion State:** Transient mood modulation without clinical or psychological claims (Decision D11; exact state dimensions remain open design).
- **Multilingual Companion Interaction:** Interaction support across English, Tagalog, Japanese, and conversational code-switching (truthfully bounded by underlying model and speech capabilities; not a promise of full UI localization).
- **Safe Low-Risk Conversational Actions:** Low-risk Risk 0 and approved Risk 1 actions (e.g., personal reads, creating personal tasks/reminders) may auto-execute when enabled and when deterministic policy resolves ALLOW (Decision D9).
- **Read-Only Public Current Information:** Provider-independent `WebSearch`, `Fetch`, and weather/public-information capabilities.
- **Optional Cloud LLM Fallback:** Strictly opt-in with explicit user credentials and egress transparency; local inference remains default and primary.
- **Windows Host Autostart at Login:** Local AI Runtime configured to start automatically on Windows user login (exact launch mechanism remains open design; Decision D2).
- **Native Windows Notification Delivery:** Direct OS notification delivery decoupled from open browser tabs (Decisions D2 and D10; exact adapter remains open design).
- **Gaming / Low-Impact Resource Mode:** Resource throttling policy during active gaming or heavy foreground workloads.
- **Practical Backup & Recovery:** Database snapshot and asset recovery capability (exact mechanism remains open design).
- **Health-Context Ready Architecture:** Conceptual data contracts prepared for future health synchronization.
- **Release Hardening & Verification:** Secure configuration defaults, migration safety preflight, and CI gate stability.
- **Integrated Golden Journey Acceptance:** End-to-end companion verification path proving seamless operation across all PC V1 capabilities.

### 2.2 Approved for PC LATER (Post-PC-V1 Milestones)
- **Wake Word Detection:** Background wake phrase listening (`WakeWordProvider`, openWakeWord).
- **Relationship State:** Separate, opt-in, and hidden by default; strictly decoupled from Emotion and Personality (Decision D11).
- **Richer Emotion Models:** Advanced multi-dimensional emotional state dynamics.
- **Advanced Presence:** Live2D / VRM / contextual presentation state.
- **Interactive Browser Automation:** Automated form filling, authenticated navigation, and web interaction.
- **Native Desktop Shell:** Container packaging (e.g., Tauri, Electron) and system tray integration.
- **Semantic / Vector Memory Database:** Vector embeddings and hybrid retrieval (Intent: `APPROVED`; Delivery: `NOT STARTED`; Release: `PC LATER`; FTS5 remains the verified PC baseline).
- **Managed Online Model Downloading:** In-app browsing and background downloading from public model hubs (Intent: `APPROVED`; Delivery: `NOT STARTED`; Release: `PC LATER`; exact provider/downloader implementation remains open design).
- **Narrow, Typed Privileged Actions:** Separately designed, bounded, explicitly authorized, and auditable high-risk tools (if ever evaluated; distinct from generic shell).

### 2.3 Follow-On Mobile Release (Android V1)
- **Production Application Identity:** Package namespace and application ID: `com.cnl.aicompanion` (Decision D3).
- **Trusted Device Credentials:** Secure Android Keystore storage and per-device revocable credentials (Decision D4).
- **Authenticated Connected Synchronization:** Two-way sync with PC Local AI Runtime as the canonical persistent authority over trusted LAN / Tailscale.
- **Durable Mobile Persistence:** Local Room database with offline outbox queuing.
- **Practical Compact Offline Local LLM:** Roaming local text inference via a practical compact model. Model family, format (GGUF or alternative runtime), parameter size, and quantization remain **OPEN DESIGN**; reference hardware benchmarks are evidence only.
- **Mobile Scheduling:** Local Tasks, Reminders, and platform-appropriate notifications and alarms.
- **Persona Continuity:** Character and Personality continuity synchronized from the PC host.
- **Health Connect Integration:** Android Health Connect integration for wearable and biometric context summaries.
- **Reconnection & State Reconciliation:** Deterministic state reconciliation against PC host database upon reconnecting.
- *Boundary Note:* Device-local TTS is an exploratory idea only and is not a locked Android V1 or Android Later requirement (historical phrasing "where feasible" remains unscheduled; Intent: `EXPERIMENTAL`, Release: `FUTURE / UNSCHEDULED`). Android V1 does **not** block PC V1.

### 2.4 Explicitly Prohibited / Outside Supported Trust Model
- **Generic Command Shell Execution:** Arbitrary command shell / PowerShell / unrestricted filesystem or operating system administration is **PROHIBITED** as a generic assistant tool under Risk Tier 3 (DEFAULT DENY) and is permanently **REJECTED** as an ordinary capability (Decision D9).
- **Direct Public Internet Exposure / Port Forwarding:** Direct public exposure and router port forwarding are outside the supported trust model (Decision D5).
- **Unbounded Autonomous Looping:** Unconstrained recursive agent execution is prohibited.

### 2.5 Evaluated / Experimental (FUTURE / UNSCHEDULED)
- **Stable Diffusion Presence Renderer:** Intent: `EXPERIMENTAL`; Delivery: `NOT STARTED`; Release: `FUTURE / UNSCHEDULED`. Evaluated as an exploratory visual option; distinct from advanced Presence.
- **Multi-Profile Architecture:** Current architecture operates as a single-primary-user system (`owner_id` preserves the Profile boundary; Decision D8); future multi-profile capability remains a possible architectural consideration without an approved delivery commitment (Release: `FUTURE / UNSCHEDULED`).

---

## 3. Host Topology & Deployment Model (Decisions D2 & D5)

```text
┌─────────────────────────────────────────────────────────────┐
│                    Windows Host Machine                     │
│                                                             │
│  ┌───────────────────────┐       ┌───────────────────────┐  │
│  │       React Web       │       │   Local AI Runtime    │  │
│  │     (Browser Tab)     │       │ (Persistent Process)  │  │
│  │   localhost:3000      │       │    localhost:8000     │  │
│  └───────────┬───────────┘       └───────────▲───────────┘  │
│              │                               │              │
│              └──────── HTTP / SSE ───────────┤              │
│                                              │              │
└──────────────────────────────────────────────┼──────────────┘
                                               │ Authenticated API
                                               │ (LAN / Tailscale)
                                   ┌───────────▼───────────┐
                                   │   Android Companion   │
                                   │    (Paired Device)    │
                                   └───────────────────────┘
```

- **Windows Host Process (D2):** The Local AI Runtime runs as an independent Windows host process decoupled from browser tab lifetime; closing the browser does not define or terminate the backend host process. For PC V1, the host process must support automatic background startup at Windows user login (exact launch mechanism remains open design) and native Windows notification delivery (so reminders, alarms, and routines alert the user even when the browser client is closed; exact notification adapter remains open design). React Web is the primary V1 UI; native desktop shells (e.g., Tauri) are deferred post-PC-V1.
- **Remote Access Trust Boundary (D5):** Network access is restricted to `localhost`, trusted LAN bindings, and Tailscale private mesh networks. Direct public internet exposure and router port forwarding are outside the supported trust model for V1. Details: [`02_Data_and_Security/authentication-and-secrets.md`](02_Data_and_Security/authentication-and-secrets.md) (legacy reference: [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md)).

---

## 4. Locked Architectural Invariants Summary

The following major architectural invariants are locked across the ecosystem:

- **Profiles & Trusted Devices (D4 & D8):** AI Companion V1 operates as a single-primary-user system. The **Profile** owns all personal data (`owner_id`). Currently implemented using a single shared application credential; target architecture introduces per-device revocable credentials. Master secrets are never distributed to client devices. Details: [`02_Data_and_Security/profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md) (legacy reference: [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md)).
- **Memory & Personal Data Ownership (D7):** Memory adheres to a strict Profile-First model. The Profile owns user identity, memories, preferences, and personal data. Memories belong to the Profile (default `PROFILE` scope, optional `CHARACTER` scope). Conversation history belongs to the Profile but remains Character-bound as recorded. Characters define persona presentation and never own user data. Details: [`01_Domains/memory-and-personalization.md`](01_Domains/memory-and-personalization.md) (legacy reference: [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md)).
- **Model Acquisition & Installation Pipeline (D6):** Managed local model imports follow a deterministic pipeline: `inbox` → `preflight` → `staging` → `atomic install` → `library` → `registry`. Controlled local import is a V1 requirement (the execution service is currently an active implementation gap). `MODEL_LIBRARY_DIR` is the canonical storage location. Details: [`04_Infrastructure/runtime-and-models.md`](04_Infrastructure/runtime-and-models.md) and [`04_Infrastructure/storage-and-assets.md`](04_Infrastructure/storage-and-assets.md) (legacy reference: [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md)).
- **Tool & Autonomy Security Model (D9):** Tool execution enforces an immutable **DEFAULT DENY** posture and a 4-tier risk matrix (Risk 0–3). Generative models possess zero self-elevation authority. Low-risk Risk 0 and approved Risk 1 actions (e.g., personal reads, creating personal tasks/reminders) may auto-execute when enabled and when deterministic policy resolves ALLOW; deterministic policy evaluates actions across ALLOW, CONFIRM, and DENY without granting generative models self-elevation authority. Significant state changes (Risk 2 deletes, external transmissions) require explicit confirmation. Generic arbitrary shell / PowerShell / OS admin authority (Risk 3) is strictly prohibited by default. Details: [`02_Data_and_Security/tool-permissions-and-actions.md`](02_Data_and_Security/tool-permissions-and-actions.md) (legacy reference: [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md)).
- **Android Product Identity & Mobile Inference (D3):** Locked production application ID and package namespace: `com.cnl.aicompanion`. Connected Mode uses PC Local AI Runtime as the canonical persistent authority; Offline Mode targets a practical compact offline local LLM. Android V1 is an independent follow-on release and does not block PC V1. Details: [`01_Domains/android-companion.md`](01_Domains/android-companion.md) (legacy reference: [`ANDROID_COMPANION_ARCHITECTURE.md`](ANDROID_COMPANION_ARCHITECTURE.md)).
- **Scheduling & Notification Semantics (D10):** Task, Reminder, Alarm, and Routine are distinct product entities with distinct semantics, triggers, and lifecycles. Scheduler execution is deterministic, rule-based, and bounded. Native Windows notification delivery is a mandatory delivery target for PC V1. Quiet hours suppress applicable non-urgent notifications; per-item overrides exist. Reminders catch up after sleep/offline where appropriate. An Alarm is a time-critical scheduled alert with stronger delivery semantics than an ordinary Reminder; wake support is best-effort with no impossible universal ACPI/firmware wake guarantees. Detailed schemas and lifecycles remain open design. Details: [`01_Domains/tasks-reminders-alarms-and-routines.md`](01_Domains/tasks-reminders-alarms-and-routines.md).
- **Companion Persona & State Separation (D11):** Clean architectural separation across companion entities:
  - **Profile:** Owns user identity, user data, preferences, tasks, and persistent memories.
  - **Conversation:** Belongs to Profile and references Character; history remains Character-bound as recorded.
  - **Character:** Defines persona identity, lore, avatar, and presentation; may reference preferred Personality and Voice; does not own Profile data.
  - **Personality:** Separate behavioral style, traits, and communication configuration.
  - **Emotion:** Lightweight, transient conceptual state modulating tone; does not make clinical/psychological claims (exact model remains open design).
  - **Voice:** Acoustic and speech synthesis configuration (TTS provider, voice ID, pitch, speed, prosody).
  - **Presence:** Bounded contextual and presentation state (exact signals and privacy remain open design).
  - **Relationship State:** Separate, opt-in, and hidden by default; scheduled for PC LATER. Details: [`01_Domains/characters-personality-and-emotion.md`](01_Domains/characters-personality-and-emotion.md).

---

## 5. Current Repository Implementation Reality

As of current verified repository baseline:

| Subsystem | Implemented & Verified Reality | Known Non-Implemented Boundary |
| :--- | :--- | :--- |
| **Backend Core** | FastAPI application, CORS origin validation, request streaming body limiter (HTTP 413), fail-closed auth (`verify_token`), logging, and route-specific 12 MiB request body ceiling for attachment uploads. | Tool execution engine and provider adapters not implemented. |
| **Persistence** | SQLite WAL mode, Alembic migrations 001–006 (repository migration head `006_add_attachments`), Task CRUD, soft-delete, retention period calculation, and standalone purge runner. Canonical paths derived via `storage.py` (`MODEL_LIBRARY_DIR` = `library/models/llm`, `INSTALLED_REGISTRY_PATH` = `library/registry/models.json`, `ATTACHMENT_DIR` = `attachments`). | Backend character persistence table, automatic periodic lifecycle scheduling of retention purge, and automated physical attachment file retention cleanup not implemented. |
| **Local LLM Engine** | `llama.cpp` Vulkan x64 (b10936), AMD RX 580 VRAM offload profiles (Eco/Balanced/Maximum), subprocess management, router log (`database/llama_server.log`). | Multiple concurrent active models not supported. Managed router receives `LLAMA_MODELS_DIR`. |
| **Model Registry** | Schema v3 bridge, dual factory/installed discovery, GGUF binary header parser for metadata, contract drift checks. | Controlled local importer execution service is an active V1 implementation gap; automated online download manager is post-V1. |
| **Frontend Web** | React 19, TypeScript 5.8, Vite 6, Tailwind CSS 4, live SSE streaming chat, tactile VRAM controls, decomposed Assistant components, truthful registry, and Phase 8B.0–8B.6 multimodal composer upload foundation with authenticated Blob previews and staged removal. | Persistent history image rendering (Slice 8B.7), final Phase 8B closure (Slice 8B.8), and responsive mobile web layout hardening (Phase 8C) not implemented. |
| **Android Prototype** | 17 Jetpack Compose screens, SoftGlass neumorphic theme, OLED theme, OkHttp `LocalAiRuntimeClient` (health/auth/task CRUD sync), SharedPreferences connection storage, unit tests. | Production trusted-device auth, secure Keystore credentials, Room/offline persistence, full sync/reconciliation, offline inference, and D3 package rename not implemented. |
| **Testing & CI** | Verified baseline: 321 backend pytest, 185 frontend vitest across 9 files, 22-route OpenAPI parity with zero drift, TypeScript clean, Vite build clean (CI Run #23 on develop SHA `4b2f5fe`); last executed Android baseline remains 124 unit/Robolectric tests from Pass R8; GitHub Actions CI workflow on `windows-latest` with automated gates; see `TESTING_AND_CI.md`. | CI gate not yet hardened as an always-running failure aggregator (`if: always()`) or set as a required branch protection rule on GitHub. |

---

## 6. Canonical Domain Architecture Index

Following the Pass R11.4 authority transfer, the **focused specifications below are the canonical domain architecture authorities** for the AI Companion project. Each focused specification owns normative architecture for its domain. Legacy monolithic documents are retained at their existing repository paths as subordinate compatibility, implementation, and technical reference material.

### 6.1 Core Experience & Client Domains (`01_Domains/`)
| Focused Domain Specification | Domain Scope | Decision / Policy Alignment | Subordinate Legacy Reference |
| :--- | :--- | :--- | :--- |
| [`assistant-and-conversations.md`](01_Domains/assistant-and-conversations.md) | Conversational turn lifecycle, session context assembly, streaming SSE, and multilingual interaction. | Decisions D1, D7, D11 | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md) |
| [`tasks-reminders-alarms-and-routines.md`](01_Domains/tasks-reminders-alarms-and-routines.md) | Distinct Task, Reminder, Alarm, and Routine scheduling semantics, quiet hours, and best-effort wake. | Decision D10 | — |
| [`characters-personality-and-emotion.md`](01_Domains/characters-personality-and-emotion.md) | Persistent Character configuration, separate Personality traits, lightweight Emotion mood, and relationship state. | Decision D11 | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md) |
| [`memory-and-personalization.md`](01_Domains/memory-and-personalization.md) | Profile-first memory persistence/retrieval, FTS5 baseline, selective automatic memory, and vector memory. | Decision D7 | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md) |
| [`voice-and-audio.md`](01_Domains/voice-and-audio.md) | Provider-independent STT/TTS, voice resource-isolation policy, conversational voice (PC V1), and wake word (PC Later). | Decisions D1, D2, D11 | [`VOICE_AND_AUDIO_ARCHITECTURE.md`](VOICE_AND_AUDIO_ARCHITECTURE.md) |
| [`multimodal-and-media.md`](01_Domains/multimodal-and-media.md) | Vision model ingestion, upload security ceilings, and media attachment lifecycle. | Phase 8B / PC V1 | — |
| [`android-companion.md`](01_Domains/android-companion.md) | Android companion identity (`com.cnl.aicompanion`), connected sync, Keystore auth, Room outbox, and compact offline LLM. | Decisions D1, D3, D4 | [`ANDROID_COMPANION_ARCHITECTURE.md`](ANDROID_COMPANION_ARCHITECTURE.md) |

### 6.2 Data, Security & Trust Domains (`02_Data_and_Security/`)
| Focused Domain Specification | Domain Scope | Decision / Policy Alignment | Subordinate Legacy Reference |
| :--- | :--- | :--- | :--- |
| [`profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md) | User Profile data ownership boundary (`owner_id`), trusted device enrollment, and single-primary-user baseline. | Decisions D4, D8 | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) |
| [`authentication-and-secrets.md`](02_Data_and_Security/authentication-and-secrets.md) | Token verification, credential hierarchy, network boundaries (localhost/LAN/Tailscale), and secrets isolation. | Decisions D4, D5 | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) |
| [`tool-permissions-and-actions.md`](02_Data_and_Security/tool-permissions-and-actions.md) | DEFAULT DENY 4-tier risk matrix, deterministic policy resolution, safe actions, and generic shell rejection. | Decision D9, Principle P1 | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) |
| [`privacy-retention-and-audit.md`](02_Data_and_Security/privacy-retention-and-audit.md) | Data retention schedules, soft-delete lifecycles, privacy/retention lifecycles, and auditable action governance. | Phase 8 / Execution Baseline | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) |

### 6.3 External Integrations (`03_Integrations/`)
| Focused Domain Specification | Domain Scope | Decision / Policy Alignment | Subordinate Legacy Reference |
| :--- | :--- | :--- | :--- |
| [`web-current-information.md`](03_Integrations/web-current-information.md) | Provider-independent read-only WebSearch, Fetch, and weather context retrieval; SSRF containment. | PC V1 Integration | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) |
| [`health-and-wearables.md`](03_Integrations/health-and-wearables.md) | PC health-context readiness (PC V1) and Android Health Connect integration (Android V1). | PC V1 & Android V1 | [`ANDROID_COMPANION_ARCHITECTURE.md`](ANDROID_COMPANION_ARCHITECTURE.md) |

### 6.4 Host & Infrastructure Domains (`04_Infrastructure/`)
| Focused Domain Specification | Domain Scope | Decision / Policy Alignment | Subordinate Legacy Reference |
| :--- | :--- | :--- | :--- |
| [`runtime-and-models.md`](04_Infrastructure/runtime-and-models.md) | Provider-independent Local AI Runtime, model registry/artifact semantics, controlled local import pipeline, and optional cloud LLM fallback. | Decision D6 | [`LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](LLAMA_CPP_RUNTIME_ARCHITECTURE.md) & [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) |
| [`storage-and-assets.md`](04_Infrastructure/storage-and-assets.md) | Canonical filesystem storage hierarchy (`COMPANION_DATA_ROOT`), asset registry, and Phase 8P storage layout. | Phase 8P Execution Baseline | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) |
| [`windows-host-and-notifications.md`](04_Infrastructure/windows-host-and-notifications.md) | Independent Windows host process, autostart at login, and native OS notification delivery. | Decisions D2, D10 | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) |
| [`backup-recovery-and-diagnostics.md`](04_Infrastructure/backup-recovery-and-diagnostics.md) | Practical backup/recovery and restore verification, and local diagnostic logging. | PC V1 Requirement | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) |
| [`performance-and-capacity.md`](04_Infrastructure/performance-and-capacity.md) | Resource governance, performance/capacity policy, and Gaming / Low-Impact Mode. | Principle P23 | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) & [`LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](LLAMA_CPP_RUNTIME_ARCHITECTURE.md) |

---

## 7. Decision Traceability Matrix (D1–D11)

| Decision ID | Area | Status in R10 | Resolution Summary | Current Canonical Owner | Authority Transfer Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **D1** | **V1 Release Boundary** | **Refined** | PC V1 is the first complete ecosystem release (incorporates conversational voice without wake word, bounded routines, read-only web info, selective automatic memory, multilingual interaction, optional cloud fallback, autostart, and native notifications). Android V1 is an independent follow-on production release. | [`SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md) §2 | Retained top-level owner *(Milestone delivery sequencing reconciled in ROADMAP.md during Pass R12)* |
| **D2** | **Windows Host Model** | **Refined** | Independent long-running Windows host process; decoupled from browser lifetime; autostart at login required; native Windows notification delivery required; native desktop shells deferred post-PC-V1. | [`04_Infrastructure/windows-host-and-notifications.md`](04_Infrastructure/windows-host-and-notifications.md) | Transferred in R11.4 |
| **D3** | **Android Identity** | **Unchanged** | Application ID & package: `com.cnl.aicompanion`; product-oriented, character-independent, model-independent. | [`01_Domains/android-companion.md`](01_Domains/android-companion.md) | Transferred in R11.4 |
| **D4** | **Profiles & Devices** | **Unchanged** | Profile represents user identity; Device represents trusted client endpoint. Independent revocable credentials per device; master secrets never distributed. | [`02_Data_and_Security/profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md) | Transferred in R11.4 |
| **D5** | **Remote Access Trust** | **Unchanged** | Localhost, trusted LAN, and Tailscale private mesh supported for V1. Direct public internet exposure / port forwarding is outside the supported trust model. | [`02_Data_and_Security/authentication-and-secrets.md`](02_Data_and_Security/authentication-and-secrets.md) | Transferred in R11.4 |
| **D6** | **Model Acquisition** | **Unchanged** | Controlled local import pipeline (PC V1 requirement): inbox → preflight → staging → atomic install → library. `MODEL_LIBRARY_DIR` is canonical. | [`04_Infrastructure/runtime-and-models.md`](04_Infrastructure/runtime-and-models.md) | Transferred in R11.4 |
| **D7** | **Memory Scoping** | **Refined** | Profile-first ownership. Profile owns user identity, memories, preferences, and personal data. Memories belong to Profile (default `PROFILE` scope, optional `CHARACTER` scope). Conversation history belongs to Profile but is Character-bound as recorded. Characters do not own data. | [`01_Domains/memory-and-personalization.md`](01_Domains/memory-and-personalization.md) | Transferred in R11.4 |
| **D8** | **Single-User Baseline** | **Unchanged** | Single-primary-user for V1; schema uses `owner_id` representing profile boundary. Preserved in place. | [`02_Data_and_Security/profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md) | Transferred in R11.4 |
| **D9** | **Security & Permissions** | **Refined** | DEFAULT DENY. 4-tier risk matrix (Risk 0–3). Low-risk Risk 0 and approved Risk 1 actions may auto-execute when enabled and deterministic policy resolves ALLOW; deterministic policy retains ALLOW, CONFIRM, and DENY. Significant state changes require confirmation. Generic arbitrary shell / OS admin is strictly prohibited by default. | [`02_Data_and_Security/tool-permissions-and-actions.md`](02_Data_and_Security/tool-permissions-and-actions.md) | Transferred in R11.4 |
| **D10** | **Scheduling & Notifications** | **New** | Task, Reminder, Alarm, and Routine are distinct. Bounded deterministic scheduler proactivity. Native Windows notification delivery target. Quiet hours with per-item overrides. Reminder catch-up recovery. Alarm has stronger delivery semantics than an ordinary Reminder; wake support is best-effort (no universal ACPI/firmware wake guarantee). | [`01_Domains/tasks-reminders-alarms-and-routines.md`](01_Domains/tasks-reminders-alarms-and-routines.md) | Transferred in R11.4 |
| **D11** | **Persona & State Separation** | **New** | Clear separation: Profile (owns personal data/memories/tasks), Conversation (belongs to Profile, Character-bound history), Character (persona identity/lore/avatar/presentation), Personality (behavioral style/traits), Emotion (lightweight transient mood), Voice (acoustic/TTS configuration), Presence (contextual/presentation state), and Relationship State (separate, opt-in, PC LATER). | [`01_Domains/characters-personality-and-emotion.md`](01_Domains/characters-personality-and-emotion.md) | Transferred in R11.4 |

---

*Forensic reconciliation history, diagnostics, and working notes remain documented in [`REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md`](../07_Archive/audits/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md).*
