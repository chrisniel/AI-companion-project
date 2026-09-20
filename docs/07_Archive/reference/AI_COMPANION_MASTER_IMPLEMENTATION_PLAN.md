# AI Companion Project — Master Implementation Plan (Historical Reference)

> [!WARNING]
> **HISTORICAL / NON-AUTHORITATIVE REFERENCE DOCUMENT — ARCHIVED IN PASS R5**  
> This document is a **historical master architecture and reference sequencing plan** reflecting mid-September 2026 project drafting. It is **non-authoritative** for active system architecture, product sequencing, or execution tracking:
> - **Normative System Architecture:** Owned strictly by [`SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) and focused domain architecture specifications in `docs/04_Architecture/`.
> - **Canonical Product & Milestone Roadmap:** Owned strictly by [`docs/02_Planning/ROADMAP.md`](../../02_Planning/ROADMAP.md).
> - **Active Sprint Execution State:** Tracked strictly in [`docs/01_Tracking/task.md`](../../01_Tracking/task.md).
> - **Feature Implementation Details:** Owned by feature-named plans under [`docs/02_Planning/`](../../02_Planning/).
> - **Disposition:** Relocated to `docs/07_Archive/reference/` in Reconciliation Pass R5 as non-authoritative historical reference material.

---

## Content Canonicalization & Decomposition Map (Pass R4)

To prevent competing sources of truth, this document's contents have been decomposed into their canonical owners:

| Category | Description | Authoritative Destination / Current Owner |
| :--- | :--- | :--- |
| **A. Core System Baseline** | Vision, hardware targets, ecosystem subsystems, V1 scope boundary, acceptance criteria. | [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) |
| **B. Domain Architecture** | Local AI Runtime, model lifecycle, VRAM offload profiles, routing, database schema, storage paths, security model, profile-first memory, voice pipeline, mobile inference evidence. | Focused domain specifications in `docs/04_Architecture/` (`LLAMA_CPP_...`, `AI_COMPANION_RUNTIME_...`, `SECURITY_...`, `MEMORY_...`, `ANDROID_...`, `VOICE_...`). |
| **C. Product Roadmap** | Delivery milestones, V1 remaining gates, post-V1 tracks, open designs, audit hardening recommendations. | [`docs/02_Planning/ROADMAP.md`](../../02_Planning/ROADMAP.md) |
| **D. Developer & Setup Guidance** | Repository prerequisites, backend/web startup, llama-server relationship, environment configuration. | [`docs/06_Guides/DEVELOPMENT_SETUP.md`](../../06_Guides/DEVELOPMENT_SETUP.md) |
| **E. Testing & CI Guidance** | Backend pytest, frontend vitest, Android gradle tests, OpenAPI verification, CI gate governance. | [`docs/06_Guides/TESTING_AND_CI.md`](../../06_Guides/TESTING_AND_CI.md) |
| **F. Historical Delivery Evidence** | Mid-September UI states, Android UI batches 1–4, point-in-time test numbers. | Preserved in place in this document as historical record. |
| **G. Unique Unresolved Details** | Exploratory health data schemas, decision test rubric. | Mapped to post-V1 consideration and PR review guidance. |
| **H. Stale / Superseded Content** | Stale port 8081 manual examples, pre-Phase 8A mock descriptions, Health as V1 path. | Superseded by canonical architecture and locked Decisions D1–D9. |

---

## Status Vocabulary

Use these labels consistently throughout project documentation:

- **Repository-verified:** Present in the current repository and confirmed by inspection or an executed check.
- **External in progress:** Reported or visible in an external working environment, but not yet inspectable in this repository.
- **Planned:** Approved architectural direction with no implementation claim.
- **Deferred:** Intentionally outside the current delivery sequence.
- **Open decision:** Requires an explicit user choice before implementation.

## Current Delivery Baseline

| Area | Status | Evidence / Boundary |
| --- | --- | --- |
| PC React control-center UI/UX | Repository-verified implementation | `frontend/web/`; tactile VRAM controls, live SSE streaming chat, TypeScript check passing (`npm run lint`) |
| PC multilingual UI/UX patch | Repository-verified prototype | Language types, mock data, Japanese renderer, settings, character editor, assistant panel, and composer in source |
| Android companion UI/UX | Repository-verified implementation | `android/`; 17 screens, Jetpack Compose, SoftGlass neumorphic engine, OLED Battery Saver theme, SharedPreferences persistence, Host IP config |
| Android on-device failover UI | Repository-verified UI/config only | Model selection and failover toggles in `ModelsScreen.kt`; on-device LLM/TTS runtime inference is planned / unverified |
| Local AI Runtime / FastAPI | Repository-verified implementation | `backend/app/`; FastAPI application, CORS, request body limits, secret sanitization, fail-closed auth, **88 passing pytest tests**, migration head `005_scope_message_constraints` |
| Database & persistence | Repository-verified implementation | `backend/app/db/`; SQLite (`companion.db`), Alembic migrations 001–005, Task models, soft-delete, automated retention purge; canonical path defined in `AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md §6` |
| Local LLM runtime | Repository-verified implementation | `runtime/llama.cpp/` (b10936 Vulkan x64); RX 580 GPU offload, subprocess execution, isolated log file (`data/llama_server.log`); see `LLAMA_CPP_RUNTIME_ARCHITECTURE.md` |
| Assistant orchestration & SSE streaming | Repository-verified implementation | Live SSE streaming chat completions; persistent conversation threads; Phase 7 verified baseline |
| API and contracts | Repository-verified implementation | `contracts/openapi/openapi.json`; typed client in `frontend/web/src/services/api/` |
| Model registry | Repository-verified implementation | `backend/app/services/model_registry.py`; scan + registry-based model discovery; Qwen3-VL verified defaults (not a whitelist) |
| Voice & speech pipeline | Planned (Tracks V0–V6) | Canonical spec in `docs/04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md`; CPU-first speech execution; persistent voice assets under `COMPANION_DATA_ROOT/library/voices/` |
| Remote access & authentication | Repository-verified local auth; remote planned | Local token/API key authentication verified; Tailscale remote networking and mutual TLS planned |
| Phase 8 (active) | In progress | 8A completed and merged; documentation hygiene completed; 8P Runtime Config is next; 8B Multimodal Attachments and 8C Polish remain later; plan in `docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md` |
| Automated test suite | Repository-verified | **88 passing backend tests** (`pytest backend/tests`), **132 passing vitest** (`npm run test`, last verified Phase 8A baseline), 110 passing Android unit tests, 0 tsc errors |

This document supersedes conflicting status claims in drafts. Drafts remain reference material until their unique content is deliberately reconciled or archived.

---

# 1. Vision

Build a local-first personal AI companion centered around a Windows PC running a persistent **Local AI Runtime**, with React and Android clients.

Core capabilities:

- local LLM inference
- optional cloud fallback
- text and voice
- English / Filipino / Japanese / code-switching
- memory
- tasks
- reminders
- schedules
- alarms
- health data
- characters/personas
- configurable voices
- local and remote access
- future tools and device integrations

The system must remain provider-independent, character-independent, and device-configurable.

---

# 2. Hardware Target

```text
CPU: AMD Ryzen 5 3600
RAM: 16 GB
GPU: Aisurix RX 580 2048SP
VRAM: 8 GB
OS: Windows 11
```

Target AI VRAM usage under ordinary conditions:

```text
Approximately 2–4 GB when practical
```

Actual runtime values must be benchmarked.

---

# 3. Architectural Principles

## Local First

Local model, local tools, and local data are the default.

## Provider Interfaces

The architecture maintains clean, swappable provider abstractions across all external integrations:

```text
LLMProvider
STTProvider
TTSProvider
VADProvider
WakeWordProvider
EmbeddingProvider
RerankerProvider
SearchProvider
HealthProvider
MemoryRetriever
NetworkGateway
AudioDeviceManager
```

### Provider Interface vs. Model Capability
Provider interfaces define subsystem boundaries (e.g. `LLMProvider`, `TTSProvider`), whereas model capabilities (e.g. `chat`, `vision`, `reasoning`, `structured_output`, `tool_calling`, `multilingual`) describe what an individual model can do within a provider. A Vision-Language model (e.g. `Qwen3-VL-4B-Instruct`) implements `LLMProvider` with both `chat` and `vision` capabilities, eliminating the need for separate disconnected vision subsystems.

## Character Independence

The backend is always the **Local AI Runtime**.

Characters are profiles/configuration, never backend identity.

## Device Independence

Do not hardcode a phone, watch, headset, GPU, IP address, model path, or voice.

## Security

Network access does not replace authentication. All non-public endpoints are fail-closed on `protected_router`.

Secrets stay backend-side; never expose them to clients or log messages.

---

# 4. Repository Layout

```text
AI-companion-project/
├── AGENTS.md
├── CHANGELOG.md
├── README.md
├── .aiignore
├── .cursorignore
├── .gitignore
├── .gitattributes
├── .lfsconfig
├── runtime/
│   ├── llama.cpp/            # Pinned b10936 Vulkan x64 binaries — gitignored
│   └── whisper.cpp/          # whisper.cpp Windows release — gitignored
├── docs/
│   ├── 00_Drafts/            # Context-ignored scratchpads
│   ├── 01_Tracking/          # task.md and per-task archive
│   ├── 02_Planning/          # Feature-named implementation plans
│   ├── 03_Walkthroughs/      # Educational walkthrough handovers
│   ├── 04_Architecture/      # Canonical system contracts & specs
│   ├── 05_Design/            # UI/UX design tokens & wireframes
│   ├── 06_Guides/            # Onboarding and setup guides
│   ├── 07_Archive/           # Superseded documentation
│   └── ProjectWorkflowStarterKit/
├── frontend/web/             # React 19 + TypeScript 5.8 + Vite 6
├── android/                  # Native Kotlin + Jetpack Compose app
├── backend/                  # FastAPI + SQLite + SQLAlchemy 2 Core
├── contracts/
│   └── openapi/              # Exported OpenAPI schemas
├── models/                   # Local GGUF models & LFS pointers
├── scripts/                  # Automation & launcher scripts
└── data/                     # Local SQLite DB and runtime logs
```

Current repository facts:

- `frontend/web/` contains the verified React PC control center with live SSE chat streaming and tactile VRAM management.
- `android/` contains the verified native Android companion app (17 screens, SoftGlass neumorphic theme engine, AMOLED OLED Battery Saver, SharedPreferences persistence, and Host configuration).
- `backend/` contains the verified FastAPI **Local AI Runtime** (Pydantic v2 settings, SQLite database with Alembic migrations 001–005, security middleware, and 88 passing pytest tests, migration head `005_scope_message_constraints`).
- `runtime/llama.cpp/` contains the pinned Vulkan b10936 runtime binaries.
- `contracts/openapi/openapi.json` contains the verified API contract.
- `docs/ProjectWorkflowStarterKit/` remains a user-owned starter reference in its current location.
- The latest master plan under `docs/04_Architecture/` is canonical. Specialized specifications exist for `LLAMA_CPP_RUNTIME_ARCHITECTURE.md` and `VOICE_AND_AUDIO_ARCHITECTURE.md`. Older drafts remain under `docs/00_Drafts/` as non-canonical reference material.

Recommended backend:

```text
backend/
├── app/
│   ├── api/
│   ├── core/
│   ├── db/
│   ├── models/
│   ├── providers/
│   ├── repositories/
│   ├── services/
│   ├── tools/
│   ├── voice/
│   ├── memory/
│   ├── health/
│   ├── scheduling/
│   ├── devices/
│   └── networking/
├── migrations/
└── tests/
```

---

# 5. System Overview

```text
React Web UI
     │
     ▼
FastAPI Local AI Runtime
     │
     ├── LLM
     ├── Memory
     ├── Tasks / Scheduler
     ├── Tools
     ├── Voice
     ├── Devices
     ├── Health
     └── Networking
     │
     ▼
Android Companion
```

React is the PC management interface.

Android is the mobile companion.

FastAPI is the orchestrator and canonical source of truth.

---

# 6. Current UI State

## PC Web

**Status: Repository-verified implementation in `frontend/web/`; Track C2 integrated.**

The React/TypeScript desktop control center connects directly to the FastAPI Local AI Runtime via typed API services in `frontend/web/src/services/api/` (`healthApi.ts`, `modelApi.ts`, `chatApi.ts`) and `BackendContext.tsx`:
- **Tactile VRAM Controls:** Single-click **[ Load to VRAM ]** and **[ Unload VRAM ]** buttons in `ModelsView.tsx` and `CurrentModelHero.tsx` allow instant release of ~5 GB GPU memory.
- **Live SSE Streaming Chat:** `AssistantView.tsx` streams completions via Server-Sent Events (`text/event-stream`) with auto-scroll and user cancellation via `AbortController`.
- **Decoupled Telemetry:** Model library selection is decoupled from active resident telemetry (accurate 0.0 GB VRAM display when unloaded).

Multilingual UI controls are verified in source:
- English, Filipino/Tagalog, Japanese, and mixed-language preference types
- Separation between user/system language preferences and character language style
- Japanese kanji, furigana, and romaji presentation modes
- Character language-style and assistant-panel language status controls

Next Web focus: Track B5 persistent conversation list and FTS5 memory inspection panel.

## Android

**Status: Repository-verified implementation in `android/`; 110 unit tests passing.**

The Android companion client is implemented as a native Kotlin and Jetpack Compose application under `android/`. It delivers a complete 17-screen user experience with the custom SoftGlass design system, authentic dual-shadow clay neumorphism, calibrated contrast across Light and Dark modes, and a specialized AMOLED "OLED Battery Saver" pure black theme.

Key Android subsystem milestones in repository:

- **17 Screens Implemented:** Home, Assistant, Voice Mode, Tasks, Schedule, Alarms, Health, Memory, Characters, Models, Devices, Connection, Settings, Permissions, and related sheets.
- **SoftGlass Neumorphic Engine:** Directional dual shadows (`softNeumorphicRaised`) and recessed wells (`softNeumorphicInset`) with zero-allocation blur masking and graceful GPU fallback.
- **OLED Battery Saver Theme:** True pitch-black (`#000000`) background, zero drop-shadow elevation (no gray halos), and luminous high-contrast borders for maximum battery conservation on AMOLED displays.
- **Persistent Storage:** `SharedPreferencesAppearanceRepository` backing all theme, preset, effects level, and appearance choices across process kills and reboots.
- **Fluid Overscroll Physics:** Two-phase momentum spring bounce (`SoftBounceOverscroll.kt`) with progressive quadratic resistance and natural rubber-band recoil.
- **Real Host Configuration:** Editable Local AI Runtime Host IP, Port, and API Token inputs with reachability validation in `ConnectionScreen.kt`.
- **On-Device Hybrid Failover UI (Provisional / UI State):** Integrated controls in `ModelsScreen.kt` for auto-failover, edge LLM selection (Gemma-2-2B / Qwen-2.5-1.5B), Kokoro-82M neural TTS toggle, SAF model file import, and RAM allocation monitoring. *Note: These represent repository-verified UI and configuration controls; on-device ARM64 model inference is planned and requires hardware benchmarking.*

Current Android Architecture:

```text
Compose UI Screens & Bottom Sheets
 ↓
Jetpack ViewModel (StateFlow)
 ↓
Repository Interfaces (AppearanceRepository, TasksRepository, ConnectionRepository)
 ↓
Implementations:
 ├── SharedPreferencesAppearanceRepository (Persistent theme & appearance)
 └── In-Memory / Fake Repositories (Tasks, Alarms, Health, Devices)
```

Next Backend Integration: Connect Android repositories directly to the FastAPI Local AI Runtime via typed REST (`/api/v1/...`) and WebSocket event streams.

---

# 7. Android Stack

```text
Kotlin
Jetpack Compose
Material 3 foundations
Navigation Compose
ViewModel
StateFlow
Coroutines
```

Later:

```text
Room
DataStore
AlarmManager
WorkManager
Health Connect
OkHttp or Ktor
Foreground Service where required
llama.cpp Android NDK / ONNX Runtime Mobile
```

---

# 7.1 Hybrid AI Architecture: Dual-Engine & Edge Node Failover

The system designs a **Hierarchical Model Routing Architecture** spanning the Windows PC and Android smartphone:

```text
               ┌──────────────────────────────────────────────┐
               │         Windows PC: Primary AI Host          │
               │   (FastAPI Core + llama.cpp on RX 580 GPU)   │
               └──────────────────────┬───────────────────────┘
                                      │ Local LAN / Tailscale
                                      │ (Dynamic Heartbeats)
                                      ▼
               ┌──────────────────────────────────────────────┐
               │       Android Companion: Client / Hub        │
               │      (Unified Chat UI, Split Compute)        │
               └──────────────────────┬───────────────────────┘
                                      │
                         PC Online? ──┴── PC Offline / Away?
                        /                                  \
                       ▼                                    ▼
       [Primary Orchestration]                    [Edge Node Failover (Planned)]
       - Remote LLM Inference (4B/8B)             - On-Device Gemma-2-2B / Qwen-1.5B
       - High-speed GPU generation                - CPU ARM64 llama.cpp NDK
       - Full Memory & Tool RAG                   - Kokoro-82M ONNX TTS
       - Phone LLM evicted from RAM               - Room DB Local Context Cache
```

### Key Subsystems (Planned / Candidate Architecture):

1. **Hierarchical Model Routing:**
   - The Windows PC Local AI Runtime is the **Primary Orchestrator**, providing high-throughput inference (Qwen3-VL-4B / 8B) with full tool execution and memory retrieval.
   - The smartphone serves as a planned **Edge Node Failover**, running lightweight quantized models (e.g. Gemma-2-2B Q4_K_M or Qwen-2.5-1.5B Q4_K_M) on the device's ARM64 CPU when the PC is powered off.

2. **Dynamic Network Heartbeats & Failover:**
   - The Android client polls the Local AI Runtime health endpoint (`/health`).
   - If the request times out or the PC is powered down, the client can divert inference to the local Edge Node.
   - A contextual status badge informs the user of active compute: `PC Online (Full Power)` vs `Local Mobile Mode (Edge Failover)`.

3. **Context & Memory Synchronization:**
   - Active chat history and memory fragments are stored in a model-agnostic schema within Android's local Room database.
   - When switching between PC and phone inference, the context window is reformatted dynamically into the active engine's prompt template.
   - When the PC returns online, bidirectional synchronization reconciles offline messages and task modifications using deterministic timestamp sorting.

4. **Zero-Dependency Private Model Storage (No APK Bloat):**
   - Model weights are **never bundled inside APK assets**.
   - Weights are acquired via two methods:
     - **In-App Downloader:** On-demand HTTPS chunked streaming download into app-private storage (`context.filesDir/models/`).
     - **SAF File Import:** User-directed Storage Access Framework picker allowing users to import pre-downloaded `.gguf` and `.onnx` models from device storage or SD card.

5. **On-Device Neural TTS Target (Kokoro-82M ONNX — Planned):**
   - Voice synthesis parity with the PC is planned via Kokoro-82M packaged in ONNX format on ARM64 CPU cores via ONNX Runtime Mobile.
   - Performance targets (<0.3x RTF, ~85 MB storage, ~120 MB RAM) are estimated engineering targets and must be verified by on-device benchmarks before release.

6. **RAM, Battery & Thermal Safeguards:**
   - **Dynamic RAM Eviction:** When the PC is online, the on-device mobile LLM is completely unloaded from RAM to preserve memory for other mobile applications.
   - **Foreground Service Loop:** Active mobile inference runs under an Android Foreground Service notification to prevent OS low-memory termination.
   - **WakeLock Management:** CPU high-performance WakeLocks are held strictly while actively generating tokens, and released immediately upon stream completion.

---

# 7.2 OLED Battery Saver Theme & Display Optimization

To maximize battery endurance on AMOLED/OLED displays (such as the 120Hz display on modern Android devices), the system includes a specialized theme engine mode:

- **True Pitch-Black (`#000000`):** Backgrounds and container roots render pure `#000000`, turning off physical display pixels entirely and reducing display power consumption by up to 40–60%.
- **Zero Drop Shadows (0 Elevation):** Eliminates directional neumorphic shadow calculations and blur filters. This removes GPU fill-rate overhead and eliminates faint gray halo artifacts on black backgrounds.
- **Luminous Hairline Borders:** Cards and inputs maintain visual hierarchy using subtle `1.dp` borders with high-contrast luminous strokes (`#262626` subtle, `#38BDF8` active).
- **Calibrated Contrast Tokens:** Muted text and icons are calibrated for high legibility:
  - Light Mode: `#334155` (Slate-700) for sharp readability against light clay.
  - Dark Mode: `#94A3B8` (Slate-400) preventing icons from fading into dark surfaces.
  - OLED Battery Saver: High-contrast `#FFFFFF` titles and vibrant cyan/amber accents.
- **Persistent Preferences:** Backed by `SharedPreferencesAppearanceRepository` ensuring theme and visual settings survive app recreation and device reboots.

---

# 8. Android Navigation

Primary bottom navigation:

```text
Home
Assistant
Tasks
Health
More
```

More:

```text
Schedule
Alarms
Characters
Models
Devices
Memory
Settings
Connection
About
```

---

# 9. Android UI Batches

```text
0    Architecture constitution             Repository-verified complete
1    Soft Glass mobile design system       Repository-verified complete
1.1  Visual calibration                    Repository-verified complete
2    Shell + navigation                    Repository-verified complete
3    Home                                  Repository-verified complete
4    Assistant                             Repository-verified complete
4.1  Voice Mode                            Repository-verified complete
5    Tasks                                 Repository-verified complete
6    Schedule + Alarms                     Repository-verified complete
7    Health                                Repository-verified complete
8    Characters                            Repository-verified complete
9    Models + Devices                      Repository-verified complete
10   Memory + More                         Repository-verified complete
11   Settings + Theme + Languages          Repository-verified complete
12   Offline + Sync + Connection           Repository-verified complete
13   Permissions UX                        Repository-verified complete
14   Accessibility/device-size audit       Repository-verified complete
15   Final polish & Neumorphic tuning      Repository-verified complete
16   OLED Battery Saver & Contrast Tuner   Repository-verified complete
17   Persistent Storage & Physics Polish   Repository-verified complete
18   Host Network & Hybrid AI Edge UI      Repository-verified complete
```

Android UI/UX is fully integrated and repository-verified in `android/`. Automated Robolectric and unit test coverage validates navigation, theming, settings persistence, and semantic connection state cycling. Next phase focuses on real Local AI Runtime backend integrations.

---

# 10. Multilingual Requirements

Support:

```text
English
Filipino / Tagalog
Japanese
mixed-language code switching
```

Examples:

```text
"Remind me bukas at seven."
"Ashita check natin yung Android UI."
"Android UIをチェック."
```

User/system language preferences are separate from character language style.

Current implementation boundary:

- Web language preference and presentation UI is repository-verified as prototype behavior.
- Android language UI is part of the external prototype and must be verified after export.
- Real multilingual LLM quality, acoustic recognition, speech synthesis, latency, and code-switching behavior require benchmark and device testing.

---

# 11. Local AI Runtime

Primary local runtime:

```text
llama.cpp b10936 (Windows x86_64, Vulkan build)
```

Target Host & GPU:

```text
AMD Ryzen 5 3600 (6C/12T)
16 GB System RAM
Aisurix AMD RX 580 2048SP (8 GB VRAM)
Windows 11
```

The runtime operates in **Persistent Router Mode** on `127.0.0.1:8080` managed by FastAPI Core (`127.0.0.1:8000`). Detailed specifications, flag matrices, and process management rules are documented in the canonical spec:
`docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`.

Ollama and cloud Gemini remain optional secondary/fallback providers.

### 11.1 Candidate Generative Model Portfolio (Provisional / Benchmark-Gated)

The project targets a coherent portfolio of local Vision-Language models. All portfolio entries are provisional candidates subject to local hardware validation on the Aisurix RX 580:

1. **Eco Candidate: `Qwen3-VL-2B-Instruct`**
   - *Role:* Low-resource text chat, lightweight companion interaction, screenshot understanding.
   - *Target Footprint:* ~1.8–2.4 GB VRAM; optimal when system RAM/VRAM is severely constrained.
2. **Reasoning Candidate 1: `Qwen3-VL-2B-Thinking`**
   - *Role:* Complex multi-step reasoning, math, and code planning in a low-resource footprint.
   - *Architecture:* Dedicated reasoning-trained checkpoint (not a temperature or prompt tweak).
3. **Balanced / Default Candidate: `Qwen3-VL-4B-Instruct`**
   - *Role:* Primary daily assistant for chat, coding help, document OCR, and UI/screenshot analysis.
   - *Target Footprint:* ~3.8–4.8 GB VRAM at Q4_K_M; fits comfortably within the 8 GB RX 580 budget.
4. **Reasoning Candidate 2: `Qwen3-VL-4B-Thinking`**
   - *Role:* Deep analytical reasoning, complex debugging, visual reasoning, and multi-step planning.
5. **High-Resource / Experimental Candidate: `Qwen3-VL-8B-Instruct`**
   - *Role:* Maximum capability multimodal synthesis and advanced reasoning.
   - *Guardrail:* **Do not hardcode as default Maximum preset.** Promotion requires local benchmark evidence proving stable generation without paging out of 8 GB VRAM.

### 11.2 Instruct vs. Thinking Architecture

The system treats `Instruct` and `Thinking` models as distinct model variants/checkpoints, not mere hyperparameter adjustments:
- **Instruct:** Direct, conversational answers, daily interaction, lower time-to-first-token, lower latency.
- **Thinking:** Extended internal reasoning tokens, multi-step problem decomposition, higher compute and token count.
- *UI Invariant:* The UI exposes reasoning as a model capability/variant dimension, never conflating `Thinking` with the `Maximum` resource profile.

### 11.3 One-Primary-Model Residency Rule (`--models-max 1`)

To prevent GPU driver crashes and out-of-memory errors on the 8 GB RX 580:
- **Installed Models ≠ Resident Models:** Multiple GGUF models may reside on disk (`models/`).
- **Residency Invariant:** Exactly **one** primary generative model (plus its required `mmproj` vision companion) may occupy GPU VRAM at any given time.
- Enforced via router configuration: `--models-max 1`.

### 11.4 Multimodal Request Routing

All candidate models are Vision-Language capable. The router handles input dynamically:
```text
Text-only request
    ↓
Active model generates response

Image + text request
    ↓
Is active model vision-capable?
    ├── Yes → Pass image tensors + mmproj to active model
    └── No  → Prompt user or dynamically load vision-capable candidate
```
A VL model handles standard text chat directly; there is no need to run a separate text-only model.

### 11.5 Semantic Runtime State Model

The Local AI Runtime tracks normalized runtime states reflecting the daemon and model status:
- `SERVER_STOPPED`: Subprocess is not running.
- `SERVER_STARTING`: Process launched, awaiting port 8080 health check.
- `MODEL_UNLOADED`: Router active on port 8080, but 0 model weights resident in VRAM.
- `MODEL_LOADING`: Reading GGUF weights from NVMe into Vulkan VRAM.
- `MODEL_READY`: Fully resident, warm, and ready for streaming inference.
- `MODEL_SLEEPING`: Native idle timeout (900s) reached; GPU allocations released until next prompt.
- `MODEL_UNLOADING`: Transitioning from resident to unloaded.
- `MODEL_ERROR` / `SERVER_ERROR`: Diagnostic failure states.

### 11.6 CPU/GPU Workload Placement Policy

To protect the 8 GB VRAM budget on the RX 580:
- **GPU / VRAM Allocation:** Reserved strictly for the active generative model (LLM/VLM) and its multimodal projector (`mmproj`).
- **CPU / System RAM Allocation:** Speech processing (VAD, STT, TTS, Wake Word), embedding extraction, and initial reranking run CPU-first using AMD Ryzen 5 3600 cores.
- The speech stack must never compete with the primary generative model for VRAM.

---

# 12. Model Lifecycle

The runtime enforces clear distinctions between automatic sleep, user unload, and process termination:

### Automatic Idle Sleep (`--sleep-idle-seconds 900`)
```text
MODEL_READY
    ↓ (15 minutes without inference)
MODEL_SLEEPING (VRAM released; router stays alive)
    ↓ (New user message arrives)
Automatic Wake & Stream (Reloads to MODEL_READY)
```

### Explicit User Unload
```text
User clicks [ Unload VRAM ] in Web/Android
    ↓
FastAPI verifies no active streaming generation
    ↓
POST /models/unload to router
    ↓
MODEL_UNLOADED (GPU VRAM instantly released to 0.0 GB; router stays alive)
```

### Scoped Process Termination (Fallback Recovery Only)
Process termination is strictly a fallback for hung or crashed daemons:
- Terminate **only** the specific PID tracked by Local AI Runtime.
- Never execute blind system-wide termination (`taskkill /IM llama-server.exe /F`).

---

# 13. Model Selection vs. Runtime Profile Decoupling

Model selection and runtime execution profiles are independent dimensions:

```text
Selected Model (e.g. Qwen3-VL-4B-Instruct)
       +
Runtime Profile (Eco / Balanced / Maximum)
       +
Optional Convenience Preset (e.g. "Default Daily Companion")
```

### Runtime Profile Technical Mappings (RX 580 8 GB):

| Technical Parameter | Eco Profile | Balanced Profile (Default) | Maximum Profile |
|---|---|---|---|
| **Context Window** | 2048 tokens | 4096 tokens | 8192 tokens |
| **GPU Offload Layers** | 20 layers | 28 layers | 33 layers (Full offload) |
| **KV Cache Type** | `q8_0` | `q8_0` | `f16` |
| **Batch / UBatch** | 256 / 128 | 512 / 256 | 512 / 512 |
| **Flash Attention** | Enabled | Enabled | Enabled |
| **CPU Threads** | 4 threads | 4 threads | 6 threads |
| **Target VRAM Range** | ~2.5–3.2 GB | ~3.8–4.8 GB | ~6.0–7.2 GB |

A convenience preset may suggest a model + profile combination, but the architecture permits running any installed model with any valid profile.

---

# 14. LLM Routing

Support:

```text
Local Only
Local First
Cloud First
Cloud Only
```

Cloud API keys are backend-only.

---

# 15. Backend Foundation

Planned V1 backend stack:

```text
Python
FastAPI
Pydantic settings and schemas
SQLAlchemy 2
Alembic migrations
SQLite with FTS5
WebSocket support for typed realtime events
```

Phase 1 endpoints:

```text
GET /api/v1/health
GET /api/v1/system/status
GET /api/v1/config/public
```

Add:

```text
configuration
logging
error contracts
service health
versioning
```

No LLM integration in the first backend step.

---

# 16. Database

Use SQLite for V1.

Store:

```text
profiles
characters
conversations
messages
memories
tasks
reminders
schedules
alarms
settings
devices
health summaries
provider metadata
```

Use migrations.

Use FTS5 for initial memory retrieval.

### 16.1 Soft Deletion, User Scoping & Retention Policy (Recycle Bin)

To prevent accidental data loss and maintain user trust across client deletions (tasks, reminders, conversations, files):

1. **Soft Deletion Mechanism**:
   - Deletions initiated from the client (Android or Web) do not issue hard `DELETE` queries.
   - Entities implement a soft-delete mixin with `deleted_at: Optional[datetime] = None`.
   - Client deletion sets `deleted_at = datetime.utcnow()`.
   - Default application queries automatically filter `WHERE deleted_at IS NULL`.
2. **Strict User Scoping (`owner_id`)**:
   - Soft-deleted items remain strictly partitioned by `owner_id`.
   - A user can only inspect, restore, or manage deleted records belonging to their own profile: `WHERE owner_id == current_user.id AND deleted_at IS NOT NULL`.
   - Prevents cross-user data leakage and accidental authorization bypass during recovery.
3. **Retention Duration & Automated Purge**:
   - Configurable retention window: 15 to 30 days (default: 30 days via `DATA_RETENTION_DAYS=30`).
   - Items remain recoverable in a client "Trash / Recently Deleted" view during the retention period.
   - A scheduled backend maintenance script / background cleanup task executes hard deletion only after retention expires:
     `DELETE FROM [table] WHERE deleted_at <= :purge_cutoff AND owner_id = :owner_id`.
   - Permanent manual purge requires explicit double-confirmation with authenticated ownership check.

### 16.2 ModelRegistry / ModelArtifactRegistry

The Local AI Runtime maintains a structured artifact registry rather than treating `models/` as an arbitrary directory of loose filenames:

```text
id:                            unique model string identifier (e.g. "qwen3-vl-4b-instruct")
display_name:                  human-readable UI title ("Qwen3-VL 4B Instruct")
artifact_type:                 generative | stt | tts | vad | wakeword | embedding | reranker
provider:                      llama_cpp | whisper_cpp | onnx | openwakeword | etc.
model_family:                  qwen3-vl | whisper | kokoro | etc.
variant:                       instruct | thinking | base | small | etc.
version:                       checkpoint/quant release tag
primary_file:                  relative path to primary GGUF/ONNX binary
companion_files:               list of companion paths (e.g. mmproj GGUF)
capabilities:                  list of ModelCapability flags
languages:                     dictionary of language code to capability status
context_limit:                 maximum tested context tokens
recommended_runtime_profiles:  list of valid profiles (eco, balanced, maximum)
estimated_ram:                 estimated host RAM footprint in bytes
estimated_vram:                estimated GPU VRAM footprint in bytes
license:                       SPDX license identifier (e.g. "Apache-2.0")
source:                        upstream Hugging Face / model repo URI
checksum:                      SHA256 hash of primary binary
enabled:                       boolean flag for UI visibility
validation_status:             verified | missing_primary | missing_companion | incompatible
```

### 16.3 Model Capabilities

Generative models in the registry advertise fine-grained capabilities:
- `chat`: Multi-turn conversational instruction following.
- `vision`: Image, screenshot, and visual document analysis.
- `reasoning`: Extended internal chain-of-thought tokens (`Thinking` variant).
- `structured_output`: Strict adherence to JSON schema / GBNF grammars.
- `tool_calling`: Autonomous tool invocation and parameter formatting.
- `multilingual`: Cross-lingual reasoning across EN, FIL, JA, and code-switching.

### 16.4 Composite Multimodal Artifacts

Vision-Language models typically require two files to function in `llama.cpp`:
1. The base model GGUF (e.g. `Qwen3-VL-4B-Instruct-Q4_K_M.gguf`)
2. The multimodal projector GGUF (e.g. `mmproj-Qwen3-VL-4B-Instruct-f16.gguf`)

The `ModelRegistry` models this as **one logical model entry** with companion files. The user selects a single model card in the UI; the backend automatically validates that both files exist before initiating load.

---

# 17. Contracts

Maintain:

```text
contracts/openapi/
contracts/event-schemas/
```

Typed realtime events may include:

```text
assistant.state.changed
assistant.message.delta
assistant.message.completed
tool.started
tool.completed
voice.listening
voice.transcribing
voice.speaking
device.connected
device.disconnected
task.updated
alarm.updated
sync.state.changed
```

---

# 18. Memory

Initial:

```text
SQLite + FTS5
```

Flow:

```text
query
 ↓
MemoryRetriever
 ↓
FTS5
 ↓
top relevant memories
 ↓
context package
 ↓
LLM
```

Retrieved memory is context, not system authority. Always frame retrieved memories inside untrusted `<retrieved_memories>` tags.

### 18.1 Embedding and Reranking Roadmap

To keep current Track B5 focused and deliverable:
- **Active V1 Baseline:** Full-text keyword search via SQLite FTS5 with sanitized tokens and soft-delete filtering.
- **Future Optional Pipeline (Deferred beyond B5):**
  ```text
  FTS5 candidates (Top 50)
         ↓
  EmbeddingProvider (Dense vector semantic similarity)
         ↓
  RerankerProvider (Cross-encoder re-scoring)
         ↓
  Top 5 Memory Context Package → LLM
  ```
- *Scope Invariant:* Vector databases, embeddings, and neural rerankers are strictly excluded from Track B5.

---

# 19. Tools

The LLM proposes actions.

FastAPI validates and executes them.

```text
User
 ↓
LLM proposes tool call
 ↓
Backend validation
 ↓
Permission/policy check
 ↓
Tool execution
 ↓
Structured result
 ↓
Assistant response
```

Never give the LLM unrestricted shell access.

---

# 20. Scheduling and Alarms

Backend owns canonical:

```text
tasks
reminders
schedules
recurrence
PC alarms
```

Critical alarms should be mirrored to Android.

If the PC is offline:

```text
Android alarm remains armed locally
```

---

# 21. Voice Pipeline & Audio Architecture

Canonical Speech Pipeline:

```text
Microphone (PC / BT Headset / Android)
 ↓
AudioDeviceManager (Device routing & buffer management)
 ↓
WakeWordProvider (openWakeWord - when enabled)
 ↓
VADProvider (Silero VAD - CPU)
 ↓
STTProvider (whisper.cpp - CPU)
 ↓
AssistantOrchestrator (Context & FTS5 memory)
 ↓
LLMProvider (llama.cpp Router - GPU)
 ↓
TTSProvider (Kokoro-82M / Piper - CPU)
 ↓
AudioDeviceManager (Barge-in cancellation & playback)
 ↓
Speaker / Headphone Output
```

Detailed provider interfaces, device selection rules, and CPU-first execution constraints are specified in:
`docs/04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md`.

### 21.1 Voice Implementation Roadmap (Tracks V0–V6)

- **Track V0 — Audio Foundation:** `AudioDeviceManager`, device enumeration, WASAPI/PortAudio capture/playback, PCM ring buffers.
- **Track V1 — Listening:** `VADProvider` (Silero VAD), `STTProvider` (`whisper.cpp`), multilingual transcription benchmark.
- **Track V2 — Speaking:** `TTSProvider` (Kokoro / Piper), voice profiles, clause chunking, language capability reporting.
- **Track V3 — Conversational Voice:** Semantic voice state machine, live token-to-speech streaming, barge-in playback cancellation.
- **Track V4 — Wake Word:** `WakeWordProvider` (openWakeWord), low-power background detection.
- **Track V5 — Android Remote Audio:** Opus audio transport over Tailscale, Android mic/speaker bridging.
- **Track V6 — Advanced Voice:** Speaker identification, noise cancellation, prosody/style controls.

---

# 22. Voice State Machine

The voice subsystem operates an unambiguous event-driven state machine:

```text
IDLE
 ↓ (Wake word / Push-to-talk)
LISTENING
 ↓ (VAD speech end)
TRANSCRIBING
 ↓ (STT complete)
THINKING
 ├─ EXECUTING_TOOL (When tool call is proposed)
 └─ SPEAKING (Token streaming to TTS)
     ↓ (User speech detected during playback)
INTERRUPTED (Barge-in: audio output flushed, TTS cancelled, return to LISTENING)
```

Additional operational states: `RECONNECTING`, `OFFLINE`, `ERROR`.

---

# 23. Characters and Avatars

Characters configure:

```text
persona
response style
language style
voice profile
avatar assets
behavior rules
```

Visual representations map from backend semantic states (`THINKING`, `SPEAKING`, `LISTENING`) to frontend assets (WebP / Live2D / VRM).

### 23.1 Language Capability Reporting

Providers explicitly declare capabilities across project languages rather than assuming uniform support:

| Language Target | STT Capability | TTS Capability | LLM Reasoning |
|---|---|---|---|
| **English (EN)** | Supported | Supported | Supported |
| **Filipino / Tagalog (FIL)** | Supported | Limited (Phonetic fallback) | Supported |
| **Japanese (JA)** | Supported | Supported | Supported |
| **Code-Switching (Taglish / EN-JA)** | Supported | Limited | Supported |

Status codes are strictly typed: `Supported`, `Limited`, `Unsupported`, `Unknown`.

---

# 24. Health & Model Metadata

### 24.1 Model Acquisition & Artifact Metadata

All models in the registry track provenance, licensing, and integrity:
- `source`: Upstream repository URI (e.g. Hugging Face repo ID).
- `upstream_model_id`: Canonical upstream model identifier.
- `license`: SPDX license identifier confirming personal and local execution rights.
- `checksum`: SHA256 checksum verifying binary integrity.
- `companion_files`: Required companion artifacts (e.g. `mmproj` for VLMs).

### 24.2 Health Integration (V1 Path)

```text
itel ISW-O11 Watch
 ↓
FitCloudPro
 ↓
Health Connect
 ↓
Android Companion
 ↓
Local AI Runtime (SQLite)
```

Avoid BLE reverse engineering in V1. Never fabricate health metrics; missing readings are recorded as `None`/unavailable, never zero.

---

# 25. Networking

Personal V1:

```text
Tailscale
```

Future:

```text
Cloudflare Tunnel / Access
```

Application authentication remains required.

---

# 26. Home and Away Mode

Home:

```text
PC mic → STT → Core → LLM → TTS → PC headset
```

Away:

```text
Android mic → remote connection → Local AI Runtime → response/audio → Android
```

Possible future network audio format:

```text
Opus
```

---

# 27. PC-Off Behavior

When PC is off:

```text
Local AI unavailable
```

Android still supports:

```text
mirrored alarms
cached tasks
cached schedules
local notifications
Health Connect
settings
selected cached data
```

Optional future cloud fallback is not required for V1.

---

# 28. Search

Current information uses:

```text
SearchProvider
```

Cloud AI and web search are separate concerns.

---

# 29. Development Workflow

## Current Repository-Verified Web Workflow

From `frontend/web/`:

```powershell
npm install
npm run dev
```

The configured development server uses:

```text
http://localhost:3000
```

Available verification and build commands:

```powershell
npm run lint   # TypeScript noEmit check; not ESLint
npm run build
```

Do not rely on `npm run clean` on Windows until its Unix-only `rm -rf` implementation is replaced.

## Google AI Studio UI/UX Workflow

Google AI Studio is the current external generation workspace for the Android UI/UX prototype and may continue to support bounded UI prototyping.

For every generation batch:

1. Provide this master plan and state the exact active batch.
2. Limit the prompt to the requested UI/UX batch unless real integration work is explicitly approved.
3. Preserve the local-first architecture, provider boundaries, character independence, and mock-versus-real distinction.
4. Use fake repositories and clearly labeled fixtures during UI-only work; never represent mock telemetry, health data, devices, model state, or synchronization as real.
5. Never place API keys, tokens, health records, personal conversations, certificates, or other secrets in prompts or generated client code.
6. Export generated work into the repository after a coherent batch, then inspect its structure, diff, build behavior, and compatibility before treating it as implemented.
7. The repository and this master plan remain the source of truth. An AI Studio session is a working environment, not the canonical project record.

## Future Multi-Service Development

After the relevant subsystems exist, development may run:

```text
Terminal 1: llama-server
Terminal 2: FastAPI
Terminal 3: React Vite
Android Studio: Android app
```

Later add:

```text
scripts/setup-dev.ps1
scripts/start-dev.ps1
scripts/stop-dev.ps1
scripts/start-core.ps1
scripts/start-model.ps1
scripts/check-health.ps1
```

## Change and Commit Handoff

- Every completed major change should form one coherent, reviewable commit.
- The AI updates tracking and documentation, runs applicable checks, and supplies a proposed Conventional Commit-style message.
- The user manually reviews, commits, and pushes.
- Do not mark work committed or published until Git confirms the user performed those actions.

### 29.1 Multi-AI Development Workflow

The user employs a collaborative multi-agent pairing workflow:

```text
1. ChatGPT
   → Initial architectural discussions, ideation, and first-pass planning
2. Claude (Planning Chat)
   → Inspects local repository, worktree, and existing docs
   → Reconciles architecture, authoring/refining implementation plans
   → Acts as post-implementation code & architecture verifier
3. Gemini (Implementation Chat - Pair Programming Coder)
   → MVP Coder executing approved, bounded implementation plans
   → Surgical code changes, migration scripts, unit tests, and walkthrough handovers
4. Claude
   → Verification against implementation plan and repository diffs
5. ChatGPT
   → High-level architecture and quality retrospective
```

**Non-Negotiable Guardrails:**
- The **local repository** is the sole authoritative ground truth; no agent treats external drafts or conversation memory as superior to tracked repository evidence.
- Gemini implements only bounded, user-approved plans.
- Claude reviews against actual repository evidence and automated test passes.
- No agent may claim Git commits or pushes occurred unless verified by `git status` / `git log`.
- The user retains manual ownership of all Git commits, staging, and remote pushes.

---

# 30. Production

React:

```text
npm run build
```

Recommended personal V1:

```text
FastAPI serves frontend/web/dist/
```

Windows startup:

```text
Core launcher
 ↓
migrations/checks
 ↓
scheduler restore
 ↓
device discovery
 ↓
network init
 ↓
FastAPI ready
 ↓
model standby
```

---

# 31. Model Storage and Hugging Face

**Decision: Accepted — GitHub source repository with a private Hugging Face LFS object backend.**

GitHub remains the canonical Git source repository. It stores source, documentation, Git history, and Git LFS pointer files. Large objects matched by the active LFS rules are uploaded to the configured private Hugging Face dataset repository.

Local model files may still be kept outside the working tree when they do not need to be shared through repository history.

Local:

```text
D:\AI\Models\
```

The configured shared-object backend is the private Hugging Face dataset named in `.lfsconfig`.

Typical LFS files:

```text
*.gguf
*.safetensors
*.onnx
*.pt
*.pth
```

Current repository configuration implements this decision:

- `.gitattributes` actively assigns common model formats to Git LFS.
- `.lfsconfig` directs LFS objects to a private Hugging Face dataset repository.
- `models/` stores local GGUF models.

Consequences and guardrails:

- A GitHub clone can retrieve source and pointer files without containing the large binary objects itself.
- Access to private LFS objects requires appropriate Hugging Face authorization.
- Contributors without that authorization may receive pointer files or LFS download failures for private objects.
- Add model artifacts only deliberately and only after confirming redistribution rights, privacy, storage cost, and repository need.
- Do not commit API tokens or Hugging Face credentials; authentication remains local/user-managed.

---

# 32. Testing

### Verified Repository Testing State:

1. **Backend Test Suite (`pytest backend/tests`):**
   - **33 / 33 passing tests (0.89s)** covering:
     - Authentication & security middleware (Bearer / X-API-Key, fail-closed router architecture)
     - Request body limits (413 Payload Too Large) & CORS whitelist validation
     - Secret sanitization in log messages
     - LLM router mock provider, sync & streaming SSE chat completions
     - Task CRUD, category filtering, auto-reminder calculation
     - Soft deletion, recycle bin restoration, permanent purge, and automated 30-day retention cleanup
2. **Android Test Suite (`gradlew.bat testDebugUnitTest`):**
   - **110 / 110 passing unit tests** covering:
     - 17 Compose screens and navigation destinations
     - `SharedPreferencesAppearanceRepository` theme and physics persistence
     - Host connection reachability state cycling
3. **Frontend Web (`npm run lint`):**
   - TypeScript 5.8 `tsc --noEmit` passing cleanly with 0 errors.

### Planned Test Coverage for Upcoming Sprints:
- **Assistant & Conversations (Track B5):** `test_conversations.py`, `test_memory_fts.py`, `test_assistant_orchestrator.py`.
- **Router Lifecycle (Track R1):** `test_llm_router_lifecycle.py` (process tracking, sleep/wake, scoped PID kill).
- **Model Registry:** Model metadata validation, companion file validation (`mmproj`).

---

# 33. V1 Acceptance Criteria

V1 is operational when:

1. Local AI Runtime starts reliably.
2. React connects to FastAPI.
3. Local LLM loads, answers, and unloads.
4. Performance profiles work.
5. Conversation history persists.
6. SQLite migrations are reliable.
7. Tasks/reminders work.
8. FTS5 memory works.
9. Scheduler survives UI closure.
10. PC voice works.
11. STT handles EN/FIL/JA/code-switching reasonably.
12. At least one usable local TTS voice works.
13. Barge-in works.
14. Android connects to PC.
15. Android chat works.
16. Android task/schedule sync works.
17. Android alarms remain locally armed.
18. Health Connect sync works.
19. Remote access is authenticated.
20. Secrets remain outside Git and clients.

---

# 34. Implementation Order & Tracks

The project executes across specialized parallel tracks:

```text
Phase 0   Documentation/workflow baseline and canonical master plan   ✅ Done
Track A0  Android UI/UX Batches 0–18 (17 screens, SoftGlass)         ✅ Done
Track B1  FastAPI foundation (middleware, CORS, auth, limits)        ✅ Done
Track B2  SQLite + SQLAlchemy 2 + Alembic (tasks, soft-delete)       ✅ Done
Track B3  OpenAPI & contracts (contracts/openapi/openapi.json)        ⚠️ Maintained
Track C1  Web productionization & typed API client                    ✅ Done
Track C2  Connect React Web to FastAPI (VRAM controls, SSE chat)      ✅ Done
Track B4  llama.cpp Vulkan provider PoC & RX 580 offload              ✅ Done
Track B5  Assistant orchestration, conversations & SQLite FTS5 memory 🔄 Planning (Claude / Gemini)
Track R1  llama.cpp persistent router lifecycle (--models-max 1)      🔄 Aligned with B5
Track R2  Runtime security hardening & API key isolation             🔲 Planned
Track R3  Resource policies (Gaming Mode / Dev Mode)                 🔲 Planned
Track B6  Tasks, schedules, reminders & tool execution engine        🔲 Planned
Track V0  Audio foundation & AudioDeviceManager                      🔲 Planned
Track V1  VAD (Silero) + Multilingual STT (whisper.cpp)               🔲 Planned
Track V2  TTS provider (Kokoro-82M / Piper) + voice profiles         🔲 Planned
Track V3  Conversational voice (streaming audio & barge-in)          🔲 Planned
Track V4  Wake word (openWakeWord)                                   🔲 Planned
Track A1  Android export, repository onboarding & clean build        🔲 Planned
Track A2  Android backend connectivity & task/conversation sync      🔲 Planned
Track A3  Health Connect integration                                 🔲 Planned
Track V5  Android remote audio over Tailscale (Opus stream)          🔲 Planned
Track D1  Remote networking & mutual authentication                  🔲 Planned
Track D2  Observability, automated E2E tests, packaging & handoff    🔲 Planned
```

### 34.1 Candidate Model Hardware Benchmark Protocol

Every candidate model must complete this benchmark on the Aisurix RX 580 before approval:

| Metric | Target / Measurement Boundary |
|---|---|
| **VRAM Baseline (Idle Router)** | < 150 MB VRAM |
| **Model Load Time** | Recorded in milliseconds from NVMe to VRAM |
| **VRAM Ready State** | Eco: < 3.2 GB; Balanced: < 4.8 GB; Maximum: < 7.2 GB |
| **Inference Generation Speed** | Tokens per second (target: > 14 tok/s on 4B Q4_K_M) |
| **Vision Inference Latency** | Time-to-First-Token on 1080p screenshot |
| **Idle Sleep VRAM Release** | VRAM drops to < 150 MB after 900s inactivity |
| **Wake-from-Sleep Latency** | Duration in ms to resume generation |
| **Explicit Unload VRAM** | VRAM instantly drops to 0.0 GB |
| **Multilingual Quality** | Qualitative scoring on EN, FIL, JA, and code-switching prompts |

---

# 35. Deferred Beyond V1

Do not let these delay the core product:

```text
always-listening wake word
smartwatch BLE reverse engineering
multi-user cloud deployment
complex vector database
large agent framework
unrestricted OS automation
computer vision
camera awareness
Live2D runtime
VRM runtime
full home automation
phone-hosted main LLM
custom ROM integration
continuous background microphone recording
```

---

# 36. New-Chat Handoff

Use this document as the architecture source of truth.

Suggested new-chat prompt:

```text
This is the master implementation plan for my AI Companion project.
Read it first and treat it as the architecture source of truth unless I explicitly revise a decision.

Current implementation phase:
[PHASE]

Working environment:
[Repository / Google AI Studio]

If Google AI Studio is being used, implement only this bounded UI/UX batch:
[BATCH]

I will provide the relevant project files next.

Do not assume planned features are already implemented.
Do not describe external or mock UI behavior as repository-verified integration.
```

---

# 37. Decision Test

When unsure where a feature belongs:

```text
AI/data/scheduling/tools/canonical state?
→ Local AI Runtime

PC runtime/configuration?
→ React Web

Android capability/mobile interaction?
→ Android

Replaceable infrastructure?
→ Provider/Repository interface

Character-specific?
→ Character profile/configuration

Hardware-specific?
→ Device/provider configuration

Private/sensitive?
→ Never hardcode; never commit
```

---

# 38. End Goal

```text
At PC
→ detailed dashboard + local voice assistant

Away
→ Android companion + remote assistant

PC unavailable
→ Android retains critical local functions

Need privacy
→ Local Only

Need stronger reasoning
→ optional cloud routing

Change character
→ no backend rewrite

Change voice
→ no assistant rewrite

Change model
→ no UI rewrite

Change network provider
→ no application rewrite
```

That is the architecture the project should grow toward.
