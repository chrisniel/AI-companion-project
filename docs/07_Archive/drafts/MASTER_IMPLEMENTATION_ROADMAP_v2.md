# Local AI Control Center
## Master Implementation Roadmap v2

> **Status:** PC Web UI/UX prototype completed; Native Android Companion App repository-verified in Kotlin/Jetpack Compose with 17 screens, SoftGlass neumorphic theme engine, AMOLED-tailored OLED Battery Saver pure pitch-black theme, persistent SharedPreferences storage, fluid momentum overscroll physics, Local AI Core Host IP configuration, and On-Device Hybrid Failover UI (Gemma-2-2B / Qwen-2.5-1.5B LLM + Kokoro-82M ONNX TTS).
> **Current scope:** Frontend UI/UX and client repositories are implemented and verified. Backend FastAPI Core, local model runtime, database, voice pipeline, authentication, and live synchronization are planned for next delivery phases.
>
> This document replaces the original batch-by-batch implementation dump with a cleaner roadmap that separates:
> 1. what already exists in the UI prototype,
> 2. what is only mocked,
> 3. what is planned for the production system,
> 4. what is optional or future work.

---

# 1. Product Vision

Build a **local-first personal AI assistant platform** whose primary runtime lives on a Windows PC while exposing:

- a React desktop-oriented web dashboard,
- a native Kotlin Android companion app,
- local AI inference,
- local STT and TTS,
- tasks, schedules, alarms, and reminders,
- long-term memory,
- health and activity summaries,
- character/persona and avatar profiles,
- configurable devices and audio routing,
- optional remote access,
- optional cloud-model fallback.

The application must **not be hardcoded to a single character, voice, AI model, device, network provider, or cloud service**.

---

# 2. Locked Architecture Decisions

## 2.1 Core Runtime

**Backend**
- Python
- FastAPI
- Pydantic
- SQLAlchemy 2
- Alembic
- SQLite
- SQLite FTS5
- WebSocket support for realtime events

**Role**
- Source of truth for application state
- Assistant orchestration
- Model routing
- Tasks and schedules
- Memory
- Tools
- device sessions
- health synchronization
- audio orchestration
- configuration
- logs and diagnostics

The frontend must never become the authoritative implementation of core business logic.

---

## 2.2 PC Frontend

**Technology**
- React
- TypeScript
- browser-based web dashboard

**Purpose**
- Local AI control center
- assistant workspace
- task and schedule management
- health overview
- model/runtime controls
- character management
- devices
- memory
- logs
- settings

The web frontend should consume a typed FastAPI API later. During prototype development it uses mock repositories/data.

---

## 2.3 Android App

**Technology**
- Kotlin
- Jetpack Compose
- ViewModel
- StateFlow
- Coroutines
- SharedPreferences (persistent appearance & connection configuration)
- Room (local context cache & message persistence)
- DataStore
- WorkManager
- AlarmManager
- OkHttp or Ktor
- llama.cpp Android NDK (on-device LLM failover: Gemma-2-2B / Qwen-2.5-1.5B)
- ONNX Runtime Mobile (on-device neural TTS: Kokoro-82M)

**Primary responsibilities**
- assistant chat and voice
- mobile alarms/reminders
- tasks and schedule
- health/wellness access (Health Connect)
- notifications
- synchronization with Local AI Core
- mobile audio routing and speech interaction
- On-Device Edge Node Failover when PC is offline/disconnected
- AMOLED-tailored OLED Battery Saver theme (`#000000` pitch black, zero shadows, luminous borders)

The mobile app is **not** a miniature copy of the PC control panel.

---

## 2.4 Local Model Runtime

Primary local inference boundary:

```text
Assistant Orchestrator
        |
    LLMProvider
        |
   +----+----------------+
   |                     |
llama.cpp             Ollama
Primary local         Optional local
runtime               runtime
   |
Vulkan/CPU
```

Optional cloud provider:

```text
Gemini
Cloud fallback / explicit cloud mode
```

The Local AI Core must communicate through a generic provider interface rather than runtime-specific application code.

### Planned routing modes

- Local Only
- Local First
- Cloud First
- Cloud Only

Default target: **Local First**.

---

## 2.5 Hardware Target

Current primary host:

- AMD Ryzen 5 3600
- 16 GB RAM
- Radeon RX 580 2048SP
- 8 GB VRAM
- Windows 11

Target behavior:

- **Eco:** minimize AI GPU/RAM usage while gaming/developing
- **Balanced:** normal assistant use
- **Maximum:** prioritize AI workloads

The system must not assume CUDA, Metal, Apple CoreAudio, NVIDIA GPUs, Linux PipeWire, or other hardware/platform-specific technologies unless a provider explicitly supports them.

---

# 3. System Design Principles

## 3.1 Replaceable Providers

Define clear abstractions for:

- `LLMProvider`
- `STTProvider`
- `TTSProvider`
- `SearchProvider`
- `HealthProvider`
- `MemoryRetriever`
- `NetworkGateway`
- `AudioDeviceManager`

No feature should require rewriting the Local AI Core simply because a provider changes.

---

## 3.2 Character Independence

Characters are configuration profiles.

A character profile may define:

- display name
- persona/system instructions
- voice provider
- voice
- avatar
- response style
- speaking behavior
- semantic-state presentation

The application itself must never be named after, or structurally depend on, a specific character.

---

## 3.3 Semantic Avatar States

Backend-facing avatar state must remain semantic:

- Idle
- Listening
- Thinking
- Executing Tool
- Speaking
- Happy
- Concerned
- Annoyed
- Interrupted
- Offline
- Error

The frontend maps these states to:

- GIF
- WebP animation
- SVG/procedural animation
- Live2D
- VRM/3D
- future presentation technologies

The backend must never emit asset filenames such as `happy.gif`.

---

## 3.4 Local-First Data

Primary persistent state should live locally on the PC unless explicitly configured otherwise.

Use SQLite for:

- users
- conversations
- messages
- tasks
- alarms
- reminders
- schedules
- memories
- devices
- health summaries
- settings
- tool executions
- model/runtime metadata
- diagnostics

JSON should be reserved primarily for portable configuration/export rather than being the primary operational database.

---

# 4. Repository Layout

Recommended repository structure:

```text
local-ai/
|
+-- README.md
+-- .gitignore
+-- .env.example
|
+-- docs/
|   +-- MASTER_IMPLEMENTATION_ROADMAP.md
|   +-- architecture/
|   +-- api/
|   +-- decisions/
|   +-- ui/
|
+-- frontend/
|   +-- web/
|       +-- React + TypeScript application
|
+-- android/
|   +-- Native Kotlin / Jetpack Compose application
|
+-- backend/
|   +-- app/
|   |   +-- api/
|   |   +-- core/
|   |   +-- models/
|   |   +-- providers/
|   |   +-- repositories/
|   |   +-- services/
|   |   +-- tools/
|   |   +-- voice/
|   |   +-- memory/
|   |   +-- health/
|   |   +-- scheduling/
|   |   +-- devices/
|   |   +-- networking/
|   +-- migrations/
|   +-- tests/
|
+-- contracts/
|   +-- openapi/
|   +-- event-schemas/
|
+-- scripts/
|
+-- config/
|   +-- examples/
|
+-- tests/
    +-- integration/
```

Do not commit:

- model weight files
- API keys
- private certificates
- local databases containing personal information
- generated health databases
- `.env`
- large user-uploaded avatar/background files unless intentionally versioned

---

# 5. PC Web UI/UX Prototype
## Status: COMPLETE FOR V1 PROTOTYPE

The current React prototype was generated iteratively in Google AI Studio Build mode.

All functionality in this section is **frontend prototype behavior** unless explicitly connected to a real backend later.

---

## Batch 0-1 — Soft Glass Design System
**Status: Complete**

Implemented:

- dual Light/Dark themes
- semantic CSS design tokens
- neumorphic raised/recessed/pressed surfaces
- glass panels
- reusable shadows and blur effects
- configurable accent tokens
- reusable Buttons
- IconButtons
- Cards
- GlassPanel
- Badges
- StatusIndicator
- Toggles
- Sliders
- Tabs
- Select
- TextInput
- SearchInput
- Tooltip
- Modal
- Dropdown
- EmptyState
- Skeleton
- MetricCard
- CircularMetric
- ProgressBar
- component interaction-state testing

### Design rule

Neumorphism is primarily used for tactile interactive surfaces.

Glassmorphism is primarily used for structural/floating surfaces.

Long-form content must prioritize readability over decorative effects.

---

## Batch 1.1 — Light Theme Calibration
**Status: Complete**

Implemented:

- cool pearl/lavender application canvas
- improved raised surface depth
- recessed controls
- pressed-state treatment
- milky glass panels
- tactile circular metrics
- light-mode sidebar selection improvements

Dark mode was intentionally preserved.

---

## Batch 2 — Desktop Application Shell
**Status: Complete**

Implemented:

### Left navigation

**Main**
- Home
- Assistant
- Tasks
- Schedule
- Health
- Memory

**AI**
- Models
- Characters

**System**
- Devices
- Logs
- Settings

### Layout

- collapsible sidebar
- compact header
- central workspace
- right Assistant Panel
- expanded/collapsed/hidden assistant states
- persistent global assistant composer
- page routing/placeholders
- desktop responsive behavior

### Important

Any current names, latency values, model names, users, characters, or hardware shown here are **mock display data**, not production configuration.

---

## Batch 3 — Home Dashboard
**Status: Complete**

Implemented prototype sections:

- contextual greeting
- Next
- Today
- AI Status
- Wellness
- quick actions
- recent activity feed

### Production rule

Dashboard values must eventually come from Local AI Core APIs.

Do not preserve fake runtime telemetry as static production values.

---

## Batch 4 — Assistant Workspace
**Status: Complete**

Implemented:

- conversation workspace
- model/provider status
- Local/Cloud indicator
- search mode UI
- New Conversation
- conversation history
- user messages
- assistant responses
- system notices
- tool cards
- memory retrieval cards
- search-result cards
- warning/error states
- attachment UI
- microphone UI
- Send/Stop controls
- synchronized Assistant Panel state

### Production rule

Tool cards must reflect **real tool execution results** from the backend rather than frontend simulation.

Memory retrieval metadata must use the actual retrieval implementation selected later.

---

## Batch 5 — Tasks & Schedule
**Status: Complete**

### Tasks prototype

- Today
- Upcoming
- Completed
- create/edit
- completion state
- filters
- search
- priority
- project/category
- due date
- delete confirmation

### Schedule prototype

- Day
- Week
- Agenda
- Alarm
- Reminder
- Task
- Calendar Event

### Alarm editor prototype

- title
- date
- time
- recurrence
- target device
- enabled state

### Production requirement

Critical alarms must eventually support PC/Android mirroring so Android can still trigger them if the host PC is offline.

---

## Batch 6 — Health & Wellness
**Status: Complete as UI prototype**

Current real device path to target:

```text
itel ISW-O11
      |
FitCloudPro
      |
Android Health Connect
      |
Kotlin App
      |
Local AI Core
```

Implemented UI concepts:

- health source
- Today/Week/Month ranges
- heart rate
- sleep
- steps/activity
- blood oxygen
- missing-data states
- non-diagnostic insights

### Production requirements

- consume only measurements actually available through Health Connect
- do not fabricate unsupported metrics
- treat smartwatch observations as wellness information
- do not present the assistant as a medical diagnostic system

Other wearable providers shown in the prototype are **future/optional integrations**, not current requirements.

---

## Batch 7 — Models & Runtime
**Status: Complete as UI prototype**

Implemented UI concepts:

- runtime/provider cards
- current model telemetry
- model library
- Eco/Balanced/Maximum profiles
- VRAM allocation controls
- Local/Cloud routing policy
- cloud fallback controls
- advanced runtime settings

### Production runtime target

Primary:
- `llama.cpp`
- Windows
- Vulkan/CPU where supported

Optional:
- Ollama
- Gemini

### Important cleanup

Prototype CUDA, cuBLAS, Metal, NVIDIA layer-offloading, or unsupported GPU-specific values must not be treated as actual implementation requirements.

Expose runtime options dynamically according to the capabilities reported by the active provider.

---

## Batch 8 — Characters & Personas
**Status: Complete as UI prototype**

Implemented:

- character library
- active character state
- add/edit character
- persona settings
- voice provider
- voice settings
- avatar selection
- semantic-state preview
- response-style controls
- avatar display modes

### Production rule

Prototype character names and voices are examples only.

No character is required by the core.

---

## Batch 9 — Devices & Memory
**Status: Complete as UI prototype**

### Devices UI

Implemented concepts for:

- host PC
- Android companion
- audio input
- audio output
- smartwatch/health source
- network gateway
- device status
- last seen
- device roles
- sync state
- test microphone/output controls

### Actual initial hardware

Do not preserve fictional prototype devices as defaults.

Use runtime discovery/configuration.

### Memory UI

Implemented:

- Profile
- Preference
- Fact
- Project
- Event
- Temporary
- search
- filtering
- Edit
- Archive/Restore
- Delete
- Add Memory

### Planned backend memory engine

Phase 1:
- SQLite
- FTS5
- structured metadata

Future:
- optional embeddings
- hybrid lexical/semantic retrieval
- reranking

---

## Batch 10 — Logs & Settings
**Status: Complete as UI prototype**

### Logs

Implemented:

- subsystem filters
- severity filtering
- search
- mock stream
- pause/resume
- Clear View
- event inspection

### Settings

Current sections:

- General
- Appearance
- Assistant
- Voice
- AI
- Health
- Devices
- Network
- Privacy
- Advanced

### Production rule

Settings options must be capability-driven.

Do not show platform-specific settings that are irrelevant to the current Windows/Android environment.

---

## Batch 10.1 — Theme, Background & Glass Customization
**Status: Complete**

Implemented:

- global background layer
- built-in light/dark presets
- custom image UI
- gradient background UI
- solid-color background UI
- brightness/saturation
- background blur
- scrim/overlay
- glass opacity
- glass blur
- glass tint
- glass saturation
- Reduced/Normal/Enhanced effects
- live appearance preview
- accent customization

### Production requirement

Persist appearance settings per user.

Custom backgrounds should be stored outside source control unless intentionally packaged as built-in assets.

---

## Batch 11 — Responsive & Application-State Audit
**Status: Complete**

Implemented/testing targets:

- 1280
- 1366
- 1440
- 1920

Collapse priority:

1. Assistant Panel
2. Sidebar
3. Preserve main workspace

Application state coverage includes:

- loading
- empty
- error
- offline
- disconnected
- model unavailable
- Core offline
- health unavailable
- device unavailable
- task synchronization state
- assistant states

Accessibility requirements include:

- keyboard navigation
- visible focus
- readable contrast
- semantic state indicators
- usable click/touch targets

---

## Batch 12 — Final UI/UX Audit
**Status: Complete**

Final prototype audit includes:

- Soft Glass balance
- visual-token consistency
- duplicate-control cleanup
- page-header consistency
- responsive desktop verification
- restrained glass/neumorphic effects
- theme harmonization

---

# 6. Prototype Data Cleanup
## Required Before Backend Integration

Several values currently present in the prototype are visual placeholders and must not become production configuration.

Remove or replace mocked assumptions such as:

- fictional users
- fictional PC specifications
- fictional Android device models
- fictional microphones/headsets
- Linux-only audio stacks
- Apple-only APIs
- NVIDIA/CUDA assumptions
- Metal assumptions
- fake latency/token-rate values
- fake model-memory usage
- fake health measurements
- fake "airgapped" status when cloud fallback is enabled
- mock network addresses
- mock certificates
- mock model paths
- mock runtime capabilities

Introduce centralized mock fixtures during frontend development so example data is clearly separated from real runtime data.

Recommended:

```text
frontend/web/src/
+-- mocks/
|   +-- user.ts
|   +-- devices.ts
|   +-- health.ts
|   +-- models.ts
|   +-- assistant.ts
|   +-- tasks.ts
|   +-- schedule.ts
```

Later replace mock repositories with API repositories.

---

# 7. PC Frontend Productionization
## Phase WEB-1

Before backend wiring:

- [ ] identify all mock-data sources
- [ ] move mock values into centralized fixtures
- [ ] remove embedded fictional hardware assumptions
- [ ] remove platform-specific labels not applicable to current hardware
- [ ] confirm every route renders without runtime errors
- [ ] confirm Light/Dark/System themes
- [ ] confirm background customization
- [ ] confirm 1280-1920 desktop layouts
- [ ] confirm accessibility baseline
- [ ] add production error boundary
- [ ] add API service/repository abstraction
- [ ] establish environment configuration
- [ ] create `.env.example`
- [ ] add frontend test strategy

---

# 8. Local AI Core Backend Roadmap

## Phase CORE-1 — Backend Foundation

- [ ] initialize Python project
- [ ] initialize FastAPI
- [ ] configure Pydantic settings
- [ ] configure structured logging
- [ ] implement `/health`
- [ ] implement versioned `/api/v1`
- [ ] configure CORS for approved local origins
- [ ] establish service/repository/provider boundaries
- [ ] create database session layer
- [ ] configure SQLAlchemy
- [ ] configure Alembic
- [ ] initialize SQLite
- [ ] enable WAL where appropriate
- [ ] create unit/integration test foundation

Suggested backend structure:

```text
backend/app/
+-- main.py
+-- api/
+-- core/
+-- db/
+-- models/
+-- schemas/
+-- repositories/
+-- services/
+-- providers/
+-- tools/
+-- voice/
+-- health/
+-- memory/
+-- scheduling/
+-- devices/
+-- networking/
```

---

## Phase CORE-2 — API Contracts

Define APIs for:

### System
- Core health/status
- capabilities
- settings
- runtime telemetry

### Assistant
- conversations
- messages
- session state
- tool activity

### Tasks
- CRUD
- completion
- filters

### Schedules
- events
- reminders
- alarms

### Memory
- search
- create
- update
- archive
- delete

### Models
- provider list
- active provider
- available models
- load/unload
- performance profile

### Characters
- profiles
- active profile
- voices
- avatar metadata

### Devices
- registered devices
- capabilities
- online status

### Health
- available metrics
- summaries
- history
- provider status

### Logs
- event query
- realtime event stream

Use OpenAPI as the source for generated client types where practical.

---

## Phase CORE-3 — Realtime Event Contract

Implement typed WebSocket events.

Example:

```json
{
  "event": "assistant.state_changed",
  "timestamp": "ISO-8601",
  "data": {
    "state": "thinking"
  }
}
```

Potential event domains:

- `assistant.*`
- `model.*`
- `tool.*`
- `task.*`
- `schedule.*`
- `alarm.*`
- `device.*`
- `health.*`
- `audio.*`
- `network.*`
- `system.*`

Avoid arbitrary untyped JSON blobs.

---

# 9. Local Model Integration Roadmap

## Phase AI-1 — Provider Interface

Define a generic provider contract for:

- text generation
- streaming
- cancellation
- structured output where supported
- tool-call representation
- context limits
- capability reporting
- health/status
- model loading/unloading where applicable

---

## Phase AI-2 — llama.cpp

Target first production local provider:

- llama.cpp / llama-server
- Windows
- Vulkan/CPU
- OpenAI-compatible HTTP endpoint where appropriate

Tasks:

- [ ] install/test runtime on actual RX 580
- [ ] benchmark small GGUF models
- [ ] test partial GPU offload
- [ ] establish Eco/Balanced/Maximum presets
- [ ] track real RAM/VRAM usage
- [ ] expose provider capabilities to UI
- [ ] implement cancellation
- [ ] measure time-to-first-token
- [ ] measure tokens/second

Do not hardcode a model until benchmarks are complete.

---

## Phase AI-3 — Optional Providers

After primary local runtime works:

- [ ] Ollama adapter
- [ ] Gemini adapter
- [ ] routing policy
- [ ] explicit cloud permission controls
- [ ] token/cost logging for cloud calls
- [ ] fallback behavior
- [ ] cloud-unavailable behavior

---

# 10. Memory System Roadmap

## Phase MEMORY-1 — Structured Memory

Database model should support:

- id
- user_id
- type
- content
- source
- confidence
- importance
- tags
- created_at
- updated_at
- expires_at
- archived_at

Initial memory types:

- Profile
- Preference
- Fact
- Project
- Event
- Temporary

---

## Phase MEMORY-2 — Retrieval

Initial retrieval:

- SQLite FTS5
- metadata filters
- recency weighting
- importance weighting
- context budget

Later optional additions:

- embeddings
- vector similarity
- hybrid lexical/semantic search
- reranking

Retrieved memories are **contextual data, not system instructions**.

---

# 11. Tasks, Schedules & Alarm Roadmap

## Phase SCHED-1 — Tasks

Implement:

- CRUD
- projects/categories
- priority
- due dates
- completion
- reminder linkage

---

## Phase SCHED-2 — Server Scheduler

Implement:

- reminders
- recurring schedules
- alarm records
- scheduler persistence
- missed-event recovery
- timezone-safe storage

Store canonical timestamps safely and preserve user timezone information.

---

## Phase SCHED-3 — Android Alarm Redundancy

Important alarms should synchronize to Android.

Goal:

```text
PC online      -> coordinated alarm
PC offline     -> Android still triggers
Phone offline  -> PC still triggers
```

Implement deduplication using stable IDs/revisions.

---

# 12. Voice System Roadmap

## Phase VOICE-1 — Audio Device Manager

Do not hardcode Bluetooth.

Support:

- input device selection
- output device selection
- preferred output
- fallback output
- device enumeration
- reconnect handling

Current expected home output:
- PC-connected Bluetooth headset

---

## Phase VOICE-2 — Local STT

Create `STTProvider`.

Requirements:

- streaming or chunked transcription
- interruption/cancellation
- confidence where available
- CPU-friendly configuration
- local execution

Exact model/provider should be selected after benchmarks.

---

## Phase VOICE-3 — VAD

Implement local VAD.

Assistant voice state machine:

```text
IDLE
 -> LISTENING
 -> TRANSCRIBING
 -> THINKING
 -> EXECUTING_TOOL (optional)
 -> SPEAKING
 -> IDLE
```

Additional states:

- INTERRUPTED
- OFFLINE
- RECONNECTING
- ERROR

---

## Phase VOICE-4 — Local TTS

Create `TTSProvider`.

Initial candidates may include local engines such as:

- Piper
- Kokoro

Do not hardcode either engine into assistant logic.

Support:

- voice selection
- speaking rate
- cancellation
- streaming/low-latency output if supported
- character-specific voice configuration

---

## Phase VOICE-5 — Barge-In

When user speech begins while TTS is playing:

- detect speech
- stop/cancel current playback
- flush queued output
- switch assistant state to Listening

---

## Phase VOICE-6 — Bluetooth Warm-Up

Do not hardcode a universal 1.5-second wake delay.

Expose configurable device behavior:

- warm-up enabled
- warm-up duration
- warm-up strategy

Profile actual headset behavior during implementation.

---

# 13. Android Companion Roadmap

## Phase ANDROID-1 — UI/UX Prototype

Build separately from the PC UI.

Primary bottom navigation target:

- Home
- Assistant
- Tasks
- Health
- More

`More` may expose:

- Schedule
- Alarms
- Models
- Characters
- Devices
- Memory
- Settings

Mobile priorities:

1. assistant
2. voice
3. alarms
4. quick tasks
5. notifications
6. health
7. connection status

Do not overload the mobile UI with detailed PC runtime telemetry.

---

## Phase ANDROID-2 — Core Connectivity

- FastAPI client
- authenticated device registration
- connection state
- offline cache
- reconnect behavior
- realtime events where needed

---

## Phase ANDROID-3 — Local Persistence

Room/DataStore for:

- local settings
- alarm mirror records
- cached tasks
- cached conversations as appropriate
- sync metadata

---

## Phase ANDROID-4 — Background Work

Use:

- WorkManager for deferrable synchronization
- AlarmManager for real alarm behavior
- Foreground Service only while actively required for user-visible voice/audio work

Do not maintain a permanent foreground service merely to keep an idle WebSocket alive.

---

# 14. Health Integration Roadmap

## Phase HEALTH-1 — Health Connect

Current target path:

```text
itel ISW-O11
 -> FitCloudPro
 -> Health Connect
 -> Android app
 -> Local AI Core
```

Read only user-approved Health Connect records.

Support only measurements actually provided.

Likely initial categories:

- activity
- vitals
- other Health Connect records available from FitCloudPro

Availability must be discovered dynamically.

---

## Phase HEALTH-2 — Local Health Storage

Store normalized records/summaries with:

- metric type
- measurement
- unit
- timestamp
- source
- availability
- optional quality/confidence metadata where supplied

---

## Phase HEALTH-3 — Wellness Rule Engine

Do not invoke an LLM for every watch reading.

Use local deterministic rules/statistics first.

Examples:

- recent sleep trend
- resting HR trend
- activity trend
- stale data
- missing data

Only surface an assistant message when relevant.

Never claim medical diagnosis.

---

# 15. Tools & Actions Roadmap

Implement tools as explicit backend functions.

Initial candidates:

- create_task
- update_task
- complete_task
- delete_task
- create_reminder
- create_alarm
- cancel_alarm
- snooze_alarm
- get_schedule
- search_memory
- store_memory
- update_memory
- get_system_status
- set_assistant_mode

Execution flow:

```text
Model proposes tool action
        |
Local AI Core validates
        |
Permission check
        |
Execute
        |
Database transaction
        |
Return structured result
        |
Assistant presents result
```

A model response saying an action occurred is not sufficient evidence that the action actually occurred.

---

# 16. Character & Avatar Runtime Roadmap

## Phase CHARACTER-1 — Character Profiles

Persist:

- character ID
- display name
- persona prompt
- voice provider
- voice ID
- avatar profile
- response style
- speaking behavior

---

## Phase CHARACTER-2 — Avatar Presentation

React and Android may render semantic states differently.

Future options:

- GIF/WebP
- SVG
- Live2D
- Spine
- VRM
- 3D

Keep presentation concerns outside the Local AI Core.

---

# 17. Networking Roadmap

Networking must remain provider-independent.

Potential deployment modes:

- Local LAN
- Tailscale
- Headscale
- WireGuard
- Cloudflare Tunnel / Access

## Initial recommendation

For a single-user V1:
- Local LAN + Tailscale is acceptable.

For future multi-user/remote deployment:
- evaluate Cloudflare Access/Tunnel plus application authentication.

Do not make network membership the sole authorization mechanism.

---

# 18. Authentication & Multi-User Roadmap

Even if V1 has one user, design database ownership boundaries early.

Entities should support `user_id` where appropriate.

Future users should have separate:

- conversations
- memories
- tasks
- alarms
- health data
- characters
- settings
- backgrounds/themes
- device permissions

Application authentication should be separate from remote-network access.

---

# 19. Security Roadmap

Before remote exposure:

- [ ] authentication
- [ ] secure session/token handling
- [ ] least-privilege tool permissions
- [ ] secret storage
- [ ] input validation
- [ ] WebSocket authorization
- [ ] CORS restrictions
- [ ] rate limiting where appropriate
- [ ] audit logs for sensitive actions
- [ ] health-data access boundaries
- [ ] encrypted backup strategy
- [ ] no API keys in React or Android builds
- [ ] no sensitive `.env` files committed

---

# 20. Observability Roadmap

Structured logs should cover:

- Assistant
- Models
- Tools
- Audio
- Health
- Devices
- Scheduler
- Network
- System

Useful metrics:

- model time-to-first-token
- total generation latency
- tokens/second
- STT latency
- TTS first-audio latency
- WebSocket reconnect count
- tool success/failure
- alarm delivery
- device sync latency
- audio underruns
- actual RAM usage
- actual VRAM usage

Do not display fabricated production telemetry.

---

# 21. Testing Strategy

## Backend

- unit tests
- repository tests
- provider contract tests
- API integration tests
- database migration tests
- scheduler tests
- tool authorization tests

## Web

- component tests
- navigation tests
- accessibility tests
- mock/API repository tests
- responsive tests

## Android

- ViewModel tests
- repository tests
- Room tests
- alarm tests
- WorkManager tests
- permission tests
- physical-device audio tests

## System

Test failure scenarios:

- PC reboot
- phone offline
- internet outage
- remote gateway unavailable
- local model crash
- cloud fallback disabled
- microphone removed
- Bluetooth disconnected
- Health Connect unavailable
- database migration
- duplicated alarm events

---

# 22. Deployment Roadmap

## PC

Eventually package the backend so Local AI Core can:

- start with Windows
- run independently of the React browser tab
- expose health/status
- restart safely
- preserve logs
- recover scheduler state

React remains a web dashboard rather than the core runtime.

---

## Android

Ship as a native app.

Validate on a physical device:

- microphone
- Bluetooth
- notifications
- alarm wake behavior
- Health Connect
- background restrictions
- battery optimization
- foreground voice service

---

# 23. Implementation Order
## Recommended Production Sequence

### Completed
- [x] PC UI/UX prototype Batch 0-12

### Next
1. [ ] Git repository cleanup and project structure
2. [ ] Web prototype mock-data cleanup
3. [ ] FastAPI backend foundation
4. [ ] SQLite + migrations
5. [ ] API/OpenAPI contract
6. [ ] Web API repository integration
7. [ ] llama.cpp local-provider proof of concept
8. [ ] real model/runtime telemetry
9. [ ] memory storage + FTS5
10. [ ] assistant conversations
11. [ ] tasks
12. [ ] schedules/reminders
13. [ ] alarms
14. [ ] tool execution system
15. [ ] local STT/VAD
16. [ ] local TTS
17. [ ] audio device manager
18. [ ] character persistence
19. [ ] Android UI/UX prototype
20. [ ] Android Core connectivity
21. [ ] Android alarm redundancy
22. [ ] Health Connect integration
23. [ ] device synchronization
24. [ ] remote networking
25. [ ] authentication/multi-user foundations
26. [ ] observability
27. [ ] end-to-end testing
28. [ ] packaging/deployment

---

# 24. Future / Optional Features

Do not block V1 on these.

- Live2D/3D avatars
- floating desktop avatar
- additional smartwatch providers
- direct wearable BLE integration
- semantic embeddings/vector store
- multi-agent workflows
- additional cloud LLM providers
- home automation
- PC automation
- calendar/email integrations
- wake-word engine
- automatic wallpaper accent extraction
- animated wallpapers
- voice cloning
- remote multi-user hosting
- optional desktop wrapper if browser UI later needs native shell features

---

# 25. V1 Definition of Done

V1 should be considered successful when:

- PC Local AI Core starts reliably on Windows
- React dashboard connects to it
- local model responds through provider abstraction
- basic assistant conversations persist locally
- local memory retrieval works
- tasks and reminders persist
- alarms work on PC
- Android app connects
- important alarms are mirrored to Android
- local STT/TTS voice conversation works
- audio devices are configurable
- character/persona is replaceable
- Health Connect metrics available from the user's actual setup can be summarized
- system handles offline/local-only operation
- cloud fallback remains optional
- logs and diagnostics expose real status
- no fictional prototype telemetry is presented as real
- no sensitive secrets are exposed in frontend code

---

# 26. Documentation Rules Going Forward

When updating this roadmap:

1. Mark items as **Planned**, **In Progress**, **Implemented**, **Verified**, or **Deferred**.
2. Do not describe mock frontend interactions as production backend implementation.
3. Do not insert invented hardware/runtime specifications.
4. Do not mark integrations verified without testing on the real target device.
5. Record architectural decisions separately under `docs/decisions/`.
6. Keep UI implementation history separate from production architecture where possible.
7. Update this document after major milestones rather than appending duplicate batch summaries indefinitely.

---

## End of Master Implementation Roadmap v2


# Last Addition need to be organize.
## Batch 12.1 - Multilingual and Language Preferences
Architectural & State Modeling
Decoupled Architecture: Strictly separated system/user speech capabilities (LanguagePreferences, VoiceLanguageCapability) from character personality nuances (CharacterLanguageStyle).

Comprehensive Language Types: Configured domain models in src/types.ts for English (en), Filipino / Tagalog (fil), Japanese (ja), and mixed-language code-switching (mixed).

Japanese Text Rendering Engine: Created JapaneseTextRenderer supporting kanji_furigana, kanji_only, romaji_subtext, and romaji_only formats with optical furigana alignment.

Settings UI Integration

Settings → Assistant → Language Preferences:

Primary Language & Understood Languages: Configurable primary dialect with multi-select secondary listening comprehension.

Code-Switching Toggle: Enables fluid handling of Taglish, Eng-Jap, Tagalog-Japanese, and trilingual dialogue.

Response & Technical Language Mode: Preserves English terminology for code, system specs, and commands while allowing natural conversational responses.

Japanese Display Format: Interactive format switcher with live Kanji, Furigana, and Romaji parsing.
Multilingual Dialogue Previews: Live preview card with interactive samples demonstrating Taglish, English-Japanese, Tagalog-Japanese, and trilingual code-switching.

Settings → Voice → Speech Recognition Language:
Acoustic Language Detection: Configurable between auto-acoustic detection, primary lock, and simultaneous multi-dialect listening.
Speech Recognition Dialect & Mixed-Language Toggle: Support for local phonetic dictionaries and acoustic models.
Engine Language Capabilities Matrix: Real-time fidelity and latency telemetry table for Whisper local and Piper/Kokoro TTS models.
Character Persona & Workspace Controls

Character Editor (Section 5: Multilingual & Persona Style):
Configurable primary speaking language (en, fil, ja, or match_user).
Secondary allowed languages multi-select chips.
Match user incoming language adaptation toggle.
Granular controls for Code-Switching Frequency (never, rare, natural, frequent), Tagalog Particles (po/opo, naman, pala), and Japanese Conversational Tone (polite_desu_masu, warm_conversational, casual_friendly, business_keigo).

Assistant Panel & Global Composer:
Assistant Panel: Added a compact Language Engine status card with active language indicators, quick-target selector pills, and code-switching status.
Global Composer: Added an interactive multilingual language cycle button (Auto, EN, Taglish, 日本語) that updates input placeholders and generates localized local loopback confirmations.

Home View Header:
Replaced hardcoded greeting with getLanguageAwareGreeting from src/mock/multilingualData.ts.
Added interactive language switcher chips (Auto, EN, FIL, JA, Mixed) in the header card for testing dynamic greetings.
