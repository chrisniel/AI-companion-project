# AI Companion Project

A local-first personal AI companion ecosystem centered around a Windows PC running a persistent **Local AI Core**, with a React desktop control center and a native Android companion app.

> **Development status:** Both the PC React web UI prototype (`frontend/web/`) and the native Android companion app (`android/`) are repository-verified in this workspace. The Android app features 17 screens in Jetpack Compose, the SoftGlass design system, AMOLED pitch-black theme, persistent SharedPreferences storage, fluid overscroll bounce physics, real Local AI Core Host IP/port configuration, and 110 passing unit tests. The FastAPI backend, local model runtime integration, database, voice pipeline, health synchronization, and real device integrations are planned and form the next implementation phase.

---

## Vision

The goal is to build one coherent assistant experience across PC and Android without hardcoding the system around one model, one character, one voice, one device, or one cloud provider.

The project is designed to support:

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

The central rule is simple:

```text
AI / data / scheduling / tools / canonical state
→ Local AI Core

PC configuration / detailed runtime management
→ React Web

Mobile interaction / Android capabilities
→ Android Companion

Replaceable infrastructure
→ Provider / Repository interfaces
```

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

The **Local AI Core** is intended to become the source of truth for assistant logic, memory, tools, tasks, scheduling, provider orchestration, and synchronization.

The clients remain clients:

- **React Web:** PC dashboard, configuration, detailed runtime management, logs, devices, models, memory administration
- **Android:** mobile assistant, voice, alarms, health, notifications, tasks, quick actions, offline-capable companion features

Closing the browser should eventually **not** stop the Local AI Core.

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

Actual runtime values must be benchmarked before they are treated as defaults.

---

## Repository Layout

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
├── frontend/
│   └── web/
├── android/
├── backend/
├── contracts/
├── config/
├── scripts/
└── tests/
```

Some application directories are currently empty local placeholders. Empty directories are not preserved by Git until they contain tracked files.

---

## Development Progress

### React Web Control Center

The React/TypeScript UI prototype is largely complete.

Implemented or designed:

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
- English / Filipino / Japanese UI support
- Code-switching configuration

Current state:

```text
UI/UX prototype        ✅
Multilingual UI patch  ✅ Prototype
Backend integration    ⏳
Production cleanup     ⏳
```

Before FastAPI integration, the frontend still needs a focused cleanup pass for mock-data boundaries, dependency cleanup, text selection, theme storage safety, accessibility details, and production configuration.

### Android Companion

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

During the UI phase:

```text
Compose UI
    ↓
ViewModel
    ↓
Repository Interface
    ↓
Fake Repository
```

Current Android UI/UX implementation is repository-verified in `android/`:

```text
17 Jetpack Compose screens            ✅ Repository-verified
SoftGlass neumorphic design engine    ✅ Repository-verified
OLED pitch-black battery-saver theme  ✅ Repository-verified
High-refresh rate display adaptation  ✅ Repository-verified (up to 165Hz)
Two-phase spring bounce overscroll    ✅ Repository-verified
Persistent SharedPreferences storage  ✅ Repository-verified
Real host IP/port connection card     ✅ Repository-verified
On-device hybrid failover controls    ✅ Repository-verified
110 Robolectric/unit tests passing    ✅ 110 passed (0 failures)
```

Real integrations such as FastAPI, Room, DataStore, Health Connect, AlarmManager, WorkManager, microphone capture, STT, TTS, Bluetooth APIs, remote connectivity, and authentication come later.

### Backend / Local AI Core

Planned stack:

```text
Python
FastAPI
SQLite
FTS5
llama.cpp
```

Current state:

```text
Architecture planned   ✅
Directory structure    ⏳ Empty local placeholder
Implementation         ⏳ Not started
```

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

Language capability belongs to the **system/user profile**.

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

Future avatar presentation may support formats such as:

```text
GIF
WebP
Live2D
VRM
```

The backend should expose semantic states such as:

```text
idle
listening
thinking
speaking
interrupted
error
```

The frontend decides which asset or animation represents each state.

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

The voice system should support **barge-in**, allowing the user to interrupt TTS while the assistant is speaking.

Likely candidates to benchmark later include:

```text
STT: Whisper-family / whisper.cpp-style runtime
TTS: Piper / Kokoro
```

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

FitCloudPro is a current source, not a permanent architectural dependency.

Unavailable measurements must never be represented as fake zero values.

---

## Networking

Personal V1 may use Tailscale:

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

The networking layer should remain replaceable.

---

## Git and Large-File Storage

### Canonical Source Repository

GitHub is the canonical Git repository:

```text
GitHub
chrisniel/AI-companion-project
```

GitHub stores:

- Git history
- Source code
- Documentation
- Configuration examples
- Small assets
- Git LFS pointer files

### Large LFS Objects

Large AI/ML artifacts are configured to use a **private Hugging Face repository as the Git LFS object backend**.

Current `.lfsconfig` points LFS to:

```text
Hugging Face Dataset
kwek-kwektenpesos/AI-companion-project
```

Conceptually:

```text
git push origin <branch>
        │
        ├── Git commits + LFS pointers ──→ GitHub
        │
        └── Large LFS objects ───────────→ Hugging Face
```

Tracked model formats include:

```text
*.gguf
*.ggml
*.safetensors
*.onnx
*.pt
*.pth
*.ckpt
```

Because the Hugging Face LFS backend is private, anyone cloning the public GitHub repository will need appropriate Hugging Face authorization to retrieve those private LFS objects.

---

## Security Rules

Never commit:

- `.env`
- API keys
- Access tokens
- Private certificates or keys
- Android signing keystores
- Personal SQLite databases
- Raw private health data
- Private conversation exports
- Temporary voice recordings
- Credentials
- Local-only configuration containing secrets

Cloud API keys belong only in backend-side secret configuration.

The LLM must not receive unrestricted shell or operating-system access.

Sensitive tools must pass through backend validation and permission checks.

---

## Local Model Runtime

The current preferred local inference direction is:

```text
llama.cpp
```

with:

```text
GGUF models
Vulkan where practical
Partial GPU offload
Lazy loading
Idle unloading
```

Recommended model lifecycle:

```text
Windows starts
    ↓
Local AI Core starts
    ↓
API / Scheduler / Database ready
    ↓
LLM remains unloaded
    ↓
First AI request
    ↓
Model loads
    ↓
Assistant responds
    ↓
Idle timeout
    ↓
Model unloads
```

---

## Performance Profiles

The user-facing profiles are:

```text
Eco
Balanced
Maximum
```

The backend eventually maps them to model selection, context size, GPU offload, CPU threads, idle timeout, and memory strategy.

---

## Routing Modes

Planned provider routing:

```text
Local Only
Local First
Cloud First
Cloud Only
```

Cloud providers are optional.

Cloud API keys remain backend-only.

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

The configured Vite development URL is:

```text
http://localhost:3000
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

V1 is considered operational when:

- Local AI Core starts reliably on Windows
- React connects to FastAPI
- Local LLM can load, answer, and unload
- Eco / Balanced / Maximum profiles work
- Conversation history persists
- SQLite migrations are reliable
- Tasks and reminders work
- FTS5 memory retrieval works
- Scheduler continues when the React UI is closed
- Basic PC voice interaction works
- STT handles English, Tagalog, Japanese, and reasonable code-switching
- At least one usable local TTS voice works
- Voice interruption works
- Android connects to the PC
- Android chat works
- Android tasks and schedules synchronize
- Critical Android alarms remain locally armed
- Health Connect can synchronize selected data
- Remote access is authenticated
- Secrets stay outside clients and normal Git content

---

## Documentation

Important architecture documents belong in:

```text
docs/04_Architecture/
```

Major architectural decisions are recorded as ADRs under:

```text
docs/04_Architecture/decisions/
```

---

## New-Chat / AI Handoff

For a new development session:

1. Provide `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`.
2. State the current implementation phase.
3. Provide or link the relevant project source.
4. Mention changes made since the plan was written.
5. Do not assume planned features are already implemented.

Suggested handoff:

```text
This is the master implementation plan for my AI Companion project.

Read it first and use it as the architecture source of truth unless I explicitly revise a decision.

Current implementation phase:
[PHASE]

I will provide the relevant project files or repository next.

Do not assume planned features are already implemented.
```

---

## License

**No open-source license has been selected yet.**

This repository may be publicly visible, but public visibility alone does not grant permission to use, modify, redistribute, or sublicense the project beyond rights provided by applicable law and the hosting platform.

A future license is still under consideration.

Likely candidates include:

- Apache License 2.0
- MIT License

A license will be added deliberately when the project's distribution and contribution model is decided.

---

## Project Status

This is an experimental personal AI companion project under active development.

Many screens currently use mock data.

Many capabilities described in this README are **planned architecture**, not completed functionality.

Do not treat prototype status indicators, sample device names, example model values, sample health values, or mock runtime metrics as claims about real connected hardware or implemented services.
