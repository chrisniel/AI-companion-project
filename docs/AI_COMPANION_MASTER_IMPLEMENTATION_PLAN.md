# AI Companion Project — Master Implementation Plan

> **Project:** AI-companion-project  
> **Purpose:** Self-contained architecture and implementation handoff for future development sessions.
>
> **Current state:** PC React UI prototype exists. Android UI prototype is in progress. Backend and real integrations are not implemented yet.

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
├── README.md
├── .gitignore
├── .gitattributes
├── docs/
├── frontend/web/
├── android/
├── backend/
├── contracts/
├── config/
├── scripts/
└── tests/
```

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

UI prototype is largely complete.

Before API integration:

- fix missing CSS tokens
- remove root `select-none`
- fix wallpaper persistence
- clean unused AI Studio dependencies
- remove frontend Gemini secret setup
- centralize mock values
- add repository/service boundary
- normalize enums
- fix Windows-specific npm scripts
- separate responsive defaults from user overrides

Freeze PC UI after the multilingual patch.

## Android

Android UI/client architecture is being implemented in batches.

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

Do not implement real integrations until UI V1 is frozen.

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
0    Architecture constitution
1    Soft Glass mobile design system
1.1  Visual calibration
2    Shell + navigation
3    Home
4    Assistant
4.1  Voice Mode
5    Tasks
6    Schedule + Alarms
7    Health
8    Characters
9    Models + Devices
10   Memory + More
11   Settings + Theme + Languages
12   Offline + Sync + Connection
13   Permissions UX
14   Accessibility/device-size audit
15   Final polish
```

Freeze Android UI after Batch 15.

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

Early development may run:

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

Keep model weights outside the main source repository.

Local:

```text
D:\AI\Models\
```

For shared model artifacts, use a separate Hugging Face repository with Git LFS.

Typical LFS files:

```text
*.gguf
*.safetensors
*.onnx
*.pt
*.pth
```

Do not combine multi-gigabyte weights with the main application source unless there is a deliberate reason.

---

# 32. Testing

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
Phase 0   Freeze PC + Android UI V1
Phase 1   Web cleanup
Phase 2   FastAPI foundation
Phase 3   SQLite + migrations
Phase 4   API/event contracts
Phase 5   React ↔ FastAPI
Phase 6   llama.cpp provider
Phase 7   Assistant pipeline
Phase 8   Memory
Phase 9   Tasks/Scheduler/Alarms
Phase 10  Voice
Phase 11  Android real integration
Phase 12  Android alarms
Phase 13  Health Connect
Phase 14  Remote networking/auth
Phase 15  Productionization/testing/docs
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

I will provide the relevant project files next.

Do not assume planned features are already implemented.
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
