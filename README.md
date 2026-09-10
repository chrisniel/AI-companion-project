# AI Companion Project

A local-first personal AI companion ecosystem centered around a Windows PC running a persistent **Local AI Core**, with a React desktop control center and a native Android companion app.

> **Current status:** The React web UI prototype is largely complete. The Android UI prototype is still in progress. The FastAPI backend, local model runtime integration, voice pipeline, health sync, and real device integrations are planned but not yet implemented.

---

## Vision

The goal is to build one coherent assistant experience across PC and Android without hardcoding the project around one model, one character, one voice, one device, or one cloud provider.

The system is designed to support:

- Local LLM inference
- Optional cloud fallback
- Text chat
- Voice conversations
- English, Filipino / Tagalog, Japanese, and code-switching
- Tasks, reminders, schedules, and alarms
- Long-term memory
- Health Connect integration
- Configurable characters and voices
- PC and Android clients
- Local and remote access
- Replaceable AI, speech, search, health, and networking providers

---

## Core Architecture

```text
                  React Web Control Center
                            │
                            │ HTTP / WebSocket
                            ▼
┌─────────────────────────────────────────────────────┐
│                  Local AI Core                      │
│                     FastAPI                         │
│                                                     │
│  Assistant • Memory • Tasks • Scheduling • Tools   │
│  Voice • Devices • Health • Networking • Security  │
│                                                     │
│       ┌────────────┬────────────┬────────────┐       │
│       ▼            ▼            ▼            ▼       │
│     Local LLM     STT          TTS         SQLite   │
│    llama.cpp     Provider     Provider      + FTS5  │
└──────────────────────┬──────────────────────────────┘
                       │
                       │ Local / Remote API
                       ▼
                Android Companion App
```

The **Local AI Core** is the source of truth for assistant logic, memory, tools, tasks, scheduling, and provider orchestration.

The clients remain clients:

- **React Web:** PC dashboard, configuration, detailed runtime management
- **Android:** mobile assistant, voice, alarms, health, notifications, and offline-capable companion features

---

## Target PC

Current development target:

```text
CPU:  AMD Ryzen 5 3600
RAM:  16 GB
GPU:  Aisurix RX 580 2048SP
VRAM: 8 GB
OS:   Windows 11
```

The local inference stack should remain usable alongside gaming and development workloads.

The initial runtime strategy is:

- `llama.cpp`
- GGUF models
- Vulkan / partial GPU offload where practical
- Lazy model loading
- Idle model unloading
- Eco / Balanced / Maximum performance profiles

Actual model size, context size, offload parameters, and VRAM allocation must be determined through benchmarking.

---

## Repository Layout

```text
AI-companion-project/
├── README.md
├── .gitignore
├── .gitattributes
│
├── docs/
│   ├── MASTER_IMPLEMENTATION_PLAN.md
│   ├── WEB_FRONTEND_STATIC_REVIEW.md
│   ├── LOCAL_AI_RUNTIME_AND_WORKFLOW.md
│   ├── architecture/
│   ├── api/
│   ├── decisions/
│   └── ui/
│
├── frontend/
│   └── web/
│
├── android/
│
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── db/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── repositories/
│   │   ├── services/
│   │   ├── tools/
│   │   ├── voice/
│   │   ├── memory/
│   │   ├── health/
│   │   ├── scheduling/
│   │   ├── devices/
│   │   └── networking/
│   ├── migrations/
│   └── tests/
│
├── contracts/
│   ├── openapi/
│   └── event-schemas/
│
├── config/
│   └── examples/
│
├── scripts/
│
└── tests/
    └── integration/
```

---

## Current Development State

### React Web

Implemented as a UI/UX prototype:

- Soft Glass desktop interface
- Light / Dark / System themes
- Customizable backgrounds
- Home
- Assistant
- Tasks
- Schedule
- Health
- Memory
- Models
- Characters
- Devices
- Logs
- Settings
- Multilingual preferences

The frontend still uses mock data and requires a cleanup/productionization pass before FastAPI integration.

### Android

Planned stack:

```text
Kotlin
Jetpack Compose
Material 3 foundations
Navigation Compose
ViewModel
StateFlow
Coroutines
```

During the UI phase Android should use:

```text
Compose UI
    ↓
ViewModel
    ↓
Repository Interface
    ↓
Fake Repository
```

Real integrations such as FastAPI, Room, Health Connect, AlarmManager, WorkManager, microphone capture, STT, TTS, and Bluetooth should be added later.

### Backend

Planned stack:

```text
Python
FastAPI
SQLite
FTS5
llama.cpp
```

The backend has not yet been implemented.

---

## Multilingual Support

The companion is intended to understand and respond to:

- English
- Filipino / Tagalog
- Japanese
- Mixed-language / code-switched speech

Examples:

```text
"Remind me bukas at seven."
"Ashita check natin yung Android UI."
"What's my schedule today?"
"Android UIをチェック."
```

Language capability belongs to the system/user profile.

Character language style is configured separately.

---

## Character System

Characters are configuration, not architecture.

A character may define:

- Name
- Persona
- Response style
- Voice
- Avatar
- Language style
- Code-switching frequency
- Japanese tone
- Tagalog frequency
- Speaking behavior

The Local AI Core must remain generic regardless of which character is active.

---

## Voice Architecture

Planned local voice pipeline:

```text
Microphone
    ↓
Audio Device Manager
    ↓
VAD
    ↓
STT Provider
    ↓
Local AI Core
    ↓
LLM / Tools
    ↓
TTS Provider
    ↓
Audio Device Manager
    ↓
Speaker / Bluetooth Headset
```

Planned semantic voice states:

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

Barge-in should allow the user to interrupt TTS while the assistant is speaking.

---

## Health Architecture

Current practical V1 path:

```text
itel ISW-O11
    ↓
FitCloudPro
    ↓
Android Health Connect
    ↓
Android Companion
    ↓
Local AI Core
    ↓
SQLite
```

FitCloudPro is a current data source, not a permanent architectural dependency.

The health layer should remain provider-based.

Unavailable data must never be presented as fake zero values.

---

## Networking

Personal V1 may use Tailscale for private connectivity:

```text
Android
    ↓
Tailscale
    ↓
Windows PC
    ↓
FastAPI
```

Tailscale does **not** replace application-level authentication.

Future networking may use another `NetworkGateway`, including Cloudflare-based options.

---

## Development Workflow

### React Web

From:

```text
frontend/web/
```

run:

```powershell
npm install
npm run dev
```

Commit `package-lock.json`.

Do not commit `node_modules/`.

### Future Backend

Conceptually:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000
```

### Future Local Model

Conceptually:

```powershell
llama-server.exe `
  -m "D:\AI\Models\model.gguf" `
  --host 127.0.0.1 `
  --port 8081
```

Actual runtime arguments must be benchmarked before being treated as defaults.

### Future Combined Development Startup

Planned helper scripts:

```text
scripts/
├── setup-dev.ps1
├── start-dev.ps1
├── stop-dev.ps1
├── start-core.ps1
├── start-model.ps1
└── check-health.ps1
```

---

## Model Storage

Do **not** store model weights in the main application repository.

Recommended local path:

```text
D:\AI\Models\
```

For public or shared model artifacts, use a dedicated model registry/repository such as Hugging Face.

The application repository should contain configuration and model metadata, not multi-gigabyte weights.

---

## Git / Git LFS Strategy

The main source repository should normally ignore model weights.

A separate Hugging Face model repository can use Git LFS for files such as:

```text
*.gguf
*.safetensors
*.onnx
*.pt
*.pth
```

The `.gitattributes` file in this repository includes safe text-normalization rules and commented example LFS patterns that can be enabled in a dedicated model repository.

Git LFS configuration does not itself select Hugging Face. The repository's Git remote determines where LFS objects are uploaded.

---

## Security Rules

Never commit:

- `.env`
- API keys
- access tokens
- certificates/private keys
- Android keystores
- personal SQLite databases
- health data
- model weights
- private conversation exports
- temporary voice recordings

Cloud API keys belong only in backend-side secret configuration.

The LLM must not receive unrestricted operating-system or shell access.

Sensitive tool calls must pass through backend validation and permission checks.

---

## Documentation

Important architecture documents belong in:

```text
docs/
```

Major architecture decisions should later use ADRs:

```text
docs/decisions/
├── ADR-001-fastapi-core.md
├── ADR-002-llama-cpp-runtime.md
├── ADR-003-sqlite-v1.md
├── ADR-004-android-companion-not-core.md
├── ADR-005-health-connect-provider-path.md
└── ADR-006-network-auth-separation.md
```

---

## Recommended Implementation Order

```text
1. Finish / freeze PC UI V1
2. Finish / freeze Android UI V1
3. Clean React frontend
4. Build FastAPI foundation
5. Add SQLite + migrations
6. Establish API / event contracts
7. Connect React to FastAPI
8. Add llama.cpp provider
9. Build assistant pipeline
10. Add memory retrieval
11. Add tasks / scheduler / alarms
12. Add local voice pipeline
13. Connect Android to FastAPI
14. Add Android local cache
15. Add Android alarm redundancy
16. Add Health Connect
17. Add remote networking + authentication
18. Productionize Windows startup / scripts / testing
```

---

## V1 Success Criteria

V1 is operational when:

- Local AI Core starts reliably on Windows
- React connects to FastAPI
- Local LLM can load, answer, and unload
- Eco / Balanced / Maximum profiles work
- Conversation history persists
- Tasks and reminders work
- SQLite migrations are reliable
- FTS5 memory retrieval works
- Scheduler continues when React is closed
- Basic PC voice works
- STT handles English, Tagalog, Japanese, and reasonable code-switching
- At least one local TTS voice is usable
- Voice interruption works
- Android connects to the PC
- Android chat works
- Android task/schedule sync works
- Critical Android alarms stay locally armed
- Health Connect can sync selected data
- Remote access is authenticated
- Secrets remain outside clients and Git

---

## New-Chat Handoff

When continuing development in a new AI session:

1. Provide `docs/MASTER_IMPLEMENTATION_PLAN.md`.
2. State the current implementation phase.
3. Provide the relevant source files or repository snapshot.
4. Mention changes made since the plan was written.
5. Treat planned features as planned, not already implemented.

Suggested handoff:

```text
This is the master implementation plan for my AI Companion project.
Read it first and use it as the architecture source of truth unless I explicitly revise a decision.

Current implementation phase:
[PHASE]

I will provide the relevant source files next.

Do not assume planned features are already implemented.
```

---

## License

A license has not yet been selected.

Do not assume the repository is open source merely because source code is hosted remotely.

If the repository will remain private, a license is optional.

If it later becomes public, explicitly choose an appropriate license before accepting external contributions.
