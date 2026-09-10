# AI Companion Project — Master Implementation Plan

> **Project:** AI-companion-project
>
> **Document role:** Canonical product architecture and implementation-sequencing source of truth.
>
> **Last updated:** 2026-09-10
>
> **Purpose:** Self-contained architecture and implementation handoff for repository work and Google AI Studio UI/UX generation.
>
> **Current state:** The PC React UI/UX prototype is present in this repository. Its multilingual UI patch is also present. The Android UI/UX prototype is being created externally in Google AI Studio and is currently at Batch 12; it is not yet available in this repository. The FastAPI backend, local model runtime, database, voice pipeline, authentication, health synchronization, and real device integrations are planned and are not implemented.

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
| PC React control-center UI/UX | Repository-verified prototype | `frontend/web/`; TypeScript check passed on 2026-09-10 |
| PC multilingual UI/UX patch | Repository-verified prototype | Language types, mock data, Japanese renderer, settings, character editor, assistant panel, composer, and home greeting exist in source |
| Android companion UI/UX | External in progress — Batch 12 | Being created in Google AI Studio; no Android source is currently available in this repository |
| Local AI Core / FastAPI | Planned | `backend/` is an empty local placeholder |
| Database / persistence | Planned | No schema, models, migrations, or database implementation exists |
| Local LLM, STT, TTS, and VAD | Planned | No runtime integration exists |
| API and realtime contracts | Planned | `contracts/` is an empty local placeholder |
| Authentication and remote access | Planned | No application authentication implementation exists |
| Automated tests, CI, and deployment | Planned | No tracked test suite, CI workflow, or deployment configuration exists |

This document supersedes conflicting status claims in drafts. Drafts remain reference material until their unique content is deliberately reconciled or archived.

---

# 1. Vision

Build a local-first personal AI companion centered around a Windows PC running a persistent **Local AI Core**, with React and Android clients.

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

```text
LLMProvider
STTProvider
TTSProvider
SearchProvider
HealthProvider
MemoryRetriever
NetworkGateway
AudioDeviceManager
```

## Character Independence

The backend is always the **Local AI Core**.

Characters are profiles/configuration, never backend identity.

## Device Independence

Do not hardcode a phone, watch, headset, GPU, IP address, model path, or voice.

## Security

Network access does not replace authentication.

Secrets stay backend-side.

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
├── docs/
│   ├── 00_Drafts/
│   ├── 01_Tracking/
│   ├── 02_Planning/
│   ├── 03_Walkthroughs/
│   ├── 04_Architecture/
│   ├── 05_Design/
│   ├── 06_Guides/
│   ├── 07_Archive/
│   └── ProjectWorkflowStarterKit/
├── frontend/web/
├── android/
├── backend/
├── contracts/
├── config/
├── scripts/
└── tests/
```

Current repository facts:

- `frontend/web/` is the only application area containing tracked implementation source.
- `android/`, `backend/`, `contracts/`, `config/`, `scripts/`, and `tests/` are currently empty local placeholders. Git does not preserve empty directories in a fresh clone.
- `docs/ProjectWorkflowStarterKit/` remains a user-owned starter reference in its current location.
- The latest master plan under `docs/04_Architecture/` is canonical. Older roadmap, runtime, and static-review files remain under `docs/00_Drafts/` as non-canonical reference material.

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
FastAPI Local AI Core
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

**Status: Repository-verified UI/UX prototype; production cleanup pending.**

The current application is a React/TypeScript prototype driven by component state, `localStorage`, and mock data. It has no real API client, WebSocket integration, backend persistence, authentication, scheduler, device control, health ingestion, or AI runtime.

The multilingual UI patch is present in repository source and includes:

- English, Filipino/Tagalog, Japanese, and mixed-language preference types
- separation between user/system language preferences and character language style
- Japanese kanji, furigana, and romaji presentation modes
- multilingual settings and preview data
- character language-style controls
- assistant-panel language status
- global-composer language mode controls
- language-aware home greeting behavior

These are prototype UI/configuration behaviors. They do not prove real multilingual STT, TTS, LLM, or persistence support.

Before API integration:

- fix missing CSS tokens
- remove root `select-none`
- fix wallpaper persistence
- review and remove unused AI Studio/server dependencies
- remove frontend Gemini secret setup
- centralize mock values
- add repository/service boundary
- normalize enums
- replace the Unix-only `clean` script before relying on it on Windows
- separate responsive defaults from user overrides
- add automated frontend tests and a production error boundary

Keep the PC UI feature-frozen while completing the focused productionization plan. Do not add real integrations directly to individual components; introduce repository/service boundaries first.

## Android

**Status: External in progress — Batch 12 UI/UX in Google AI Studio; not repository-verifiable yet.**

Batches 0 through 11 are user-reported as completed in the external UI/UX prototype. Batch 12, Offline + Sync + Connection, is the current external working batch. Treat this as project status, not repository implementation, until the exported Android project is added and inspected.

During UI phase:

```text
Compose UI
 ↓
ViewModel
 ↓
Repository Interface
 ↓
FakeRepository
```

Do not claim repository implementation, build success, device behavior, or real integration until the Android export is available and verified. Real integrations should begin only after UI V1 is frozen through Batch 15 and the exported project passes repository onboarding.

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
```

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
0    Architecture constitution             External prototype complete (user-reported)
1    Soft Glass mobile design system       External prototype complete (user-reported)
1.1  Visual calibration                    External prototype complete (user-reported)
2    Shell + navigation                    External prototype complete (user-reported)
3    Home                                  External prototype complete (user-reported)
4    Assistant                             External prototype complete (user-reported)
4.1  Voice Mode                            External prototype complete (user-reported)
5    Tasks                                 External prototype complete (user-reported)
6    Schedule + Alarms                     External prototype complete (user-reported)
7    Health                                External prototype complete (user-reported)
8    Characters                            External prototype complete (user-reported)
9    Models + Devices                      External prototype complete (user-reported)
10   Memory + More                         External prototype complete (user-reported)
11   Settings + Theme + Languages          External prototype complete (user-reported)
12   Offline + Sync + Connection           External prototype in progress (current)
13   Permissions UX                        Planned
14   Accessibility/device-size audit       Planned
15   Final polish                          Planned
```

Freeze Android UI after Batch 15, export it from Google AI Studio, and inspect the actual project before planning production integration.

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

Primary recommended local runtime:

```text
llama.cpp
```

Target:

```text
GGUF
Vulkan where practical
partial GPU offload
Windows
AMD RX 580
```

Ollama may remain an optional provider.

Gemini may remain an optional cloud provider.

---

# 12. Model Lifecycle

Recommended:

```text
Windows starts
 ↓
Local AI Core starts
 ↓
Database / Scheduler / API ready
 ↓
Model remains unloaded
 ↓
First AI request
 ↓
llama.cpp/model loads
 ↓
assistant responds
 ↓
idle timeout
 ↓
model unloads
```

This preserves PC resources.

---

# 13. Performance Profiles

Expose:

```text
Eco
Balanced
Maximum
```

Backend maps profiles to technical values:

```text
model selection
context size
GPU offload
threads
idle timeout
memory strategy
```

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

Later optional:

```text
embeddings + hybrid reranking
```

Retrieved memory is context, not system authority.

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

# 21. Voice

Pipeline:

```text
Microphone
 ↓
Audio Device Manager
 ↓
VAD
 ↓
STT
 ↓
Local AI Core
 ↓
LLM / Tools
 ↓
TTS
 ↓
Audio Device Manager
 ↓
Speaker / Bluetooth Headset
```

Possible providers:

```text
STT: Whisper-family / whisper.cpp-style
TTS: Piper / Kokoro
```

Provider choice should be benchmarked.

---

# 22. Voice State Machine

```text
IDLE
LISTENING
TRANSCRIBING
THINKING
EXECUTING_TOOL
SPEAKING
INTERRUPTED
RECONNECTING
OFFLINE
ERROR
```

Support barge-in by stopping TTS when user speech is detected.

---

# 23. Characters and Avatars

Characters may configure:

```text
persona
response style
language style
voice
avatar
behavior
```

Future visual formats may include:

```text
GIF
WebP
Live2D
VRM
```

Backend emits semantic state.

Frontend maps semantic state to assets.

---

# 24. Health

V1 path:

```text
itel ISW-O11
 ↓
FitCloudPro
 ↓
Health Connect
 ↓
Android
 ↓
Local AI Core
 ↓
SQLite
```

Avoid BLE reverse engineering in V1.

Health provider remains replaceable.

Never present unavailable health data as zero.

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
Android mic → remote connection → PC Core → response/audio → Android
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
- `models/lfs-test.gguf` is a tracked LFS verification object.

Consequences and guardrails:

- A GitHub clone can retrieve source and pointer files without containing the large binary objects itself.
- Access to private LFS objects requires appropriate Hugging Face authorization.
- Contributors without that authorization may receive pointer files or LFS download failures for private objects.
- Add model artifacts only deliberately and only after confirming redistribution rights, privacy, storage cost, and repository need.
- Do not commit API tokens or Hugging Face credentials; authentication remains local/user-managed.
- `models/lfs-test.gguf` remains configuration evidence, not a production model.

---

# 32. Testing

Current verified testing state:

- `npm run lint` currently performs `tsc --noEmit` and passed on 2026-09-10.
- No tracked unit, component, integration, end-to-end, Android, backend, migration, or contract test suite exists yet.
- No tracked CI/CD workflow exists.
- The web production build and browser/device behavior have not been verified as part of this documentation update.

Planned test coverage:

Unit:

```text
backend services
repositories
scheduler
memory
routing
Android ViewModels
React repository adapters
```

Integration:

```text
FastAPI + SQLite
FastAPI + mocked llama.cpp
task/reminder flow
memory retrieval
Android sync
web API contracts
```

Contract tests:

```text
React
Android
FastAPI
WebSocket events
```

---

# 33. V1 Acceptance Criteria

V1 is operational when:

1. Local AI Core starts reliably.
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

# 34. Recommended Implementation Order

```text
Phase 0   Documentation/workflow baseline and canonical master plan
Track A0  Complete Android UI/UX Batches 12-15 in Google AI Studio
Track B1  Plan and implement the FastAPI foundation in the repository
Track B2  Add SQLite + SQLAlchemy + Alembic migrations
Track B3  Define OpenAPI and typed realtime event contracts
Track C1  Perform web productionization cleanup and add repository/service boundaries
Track C2  Connect React to FastAPI after contracts stabilize
Track B4  Add the llama.cpp provider proof of concept and real hardware benchmarks
Track B5  Build assistant orchestration, conversations, and memory/FTS5
Track B6  Add tasks, schedules, reminders, alarms, and tool execution
Track B7  Add local audio device management, VAD, STT, TTS, and barge-in
Track A1  Export/import the Android project and perform repository onboarding
Track A2  Add Android connectivity, persistence, synchronization, and alarm redundancy
Track A3  Add Health Connect integration
Track D1  Add remote networking and application authentication
Track D2  Add observability, end-to-end testing, Windows packaging, and handoff docs
```

Tracks A and B may progress in parallel while Android remains an external UI/UX prototype. Integration work waits for exported source and stable API contracts.

Immediate active phase:

```text
Android UI/UX Batch 12 — external in progress in Google AI Studio
Documentation baseline — reconciled and organized
Backend foundation — next user-owned implementation track; assistant remains read-only unless explicitly authorized
```

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
→ Local AI Core

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
