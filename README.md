# AI Companion Project

A local-first personal AI companion ecosystem centered around a Windows PC running a persistent **Local AI Runtime**, with a React desktop control center and a native Android companion app.

> **Development status:** The PC React web UI (`frontend/web/`), the native Android companion app (`android/`), and the FastAPI **Local AI Runtime** backend are repository-verified. The Android app features 17 screens in Jetpack Compose, the SoftGlass design system, AMOLED pitch-black theme, persistent SharedPreferences storage, fluid overscroll physics, real Local AI Runtime Host IP/port configuration, and 110 passing unit tests. The FastAPI backend, SQLite database, Alembic migrations (head: `005_scope_message_constraints`), and local llama.cpp model runtime integration are **implemented and verified** (Phase 7 baseline: 88 pytest, 38 vitest, 0 tsc errors). Voice pipeline, health synchronization, and native device integrations are planned. **Phase 8** (frontend architecture, runtime configuration, multimodal attachments) is the active delivery.

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
→ Local AI Runtime

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
│                  Local AI Runtime                      │
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

The **Local AI Runtime** is intended to become the source of truth for assistant logic, memory, tools, tasks, scheduling, provider orchestration, and synchronization.

The clients remain clients:

- **React Web:** PC dashboard, configuration, detailed runtime management, logs, devices, models, memory administration
- **Android:** mobile assistant, voice, alarms, health, notifications, tasks, quick actions, offline-capable companion features

Closing the browser should eventually **not** stop the Local AI Runtime.

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

### Backend / Local AI Runtime

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

The Local AI Runtime must remain generic regardless of which character is active.

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
Local AI Runtime
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
Local AI Runtime
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
Local AI Runtime starts
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

### Backend (FastAPI Local AI Runtime)

From `backend/`:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
alembic upgrade head
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

The interactive API documentation is available at `http://127.0.0.1:8000/docs`.

### Local AI Runtime (llama.cpp)

The backend manages `llama-server.exe` as an independent multi-model router daemon on port **8085** with Vulkan GPU acceleration for the AMD Radeon RX 580.

A standalone diagnostic probe is available via:

```powershell
.\scripts\start-model.ps1 -GpuLayers 28 -ContextSize 4096
```

*(Runs on isolated port 8086 to prevent collision with the production router on port 8085).*

For comprehensive prerequisites, environment configuration, storage bootstrap, and multi-process development guidance, see [docs/06_Guides/DEVELOPMENT_SETUP.md](docs/06_Guides/DEVELOPMENT_SETUP.md).

For automated test commands and CI pipeline standards, see [docs/06_Guides/TESTING_AND_CI.md](docs/06_Guides/TESTING_AND_CI.md).

---

## Delivery Roadmap & Active Tracking

The product delivery sequence, milestone gates, and post-V1 roadmap tracks are maintained in:

```text
docs/02_Planning/ROADMAP.md
```

Active sprint execution, immediate blockers, and invariants are tracked in:

```text
docs/01_Tracking/task.md
```

Detailed feature plans reside in `docs/02_Planning/` (cataloged in [docs/02_Planning/README.md](docs/02_Planning/README.md)).


---

## V1 Success Criteria (PC-Hosted Release Boundary)

Per canonical Decision D1 ([SYSTEM_BASELINE.md](docs/04_Architecture/SYSTEM_BASELINE.md)), V1 is defined as the first complete, stable, PC-hosted release.

V1 is operational when:

- Local AI Runtime starts and runs reliably as an independent Windows host process
- React Web desktop control center connects to Local AI Runtime
- Local LLM loads, generates streaming responses via SSE, and unloads reliably
- Eco / Balanced / Maximum performance profiles switch runtime parameters
- Conversation threads persist and restore accurately
- SQLite migrations (Alembic) execute safely without data loss
- Task and reminder lifecycle works (create, complete, soft-delete, automated retention purge)
- SQLite FTS5 lexical memory retrieval accurately returns relevant context
- Background scheduler operates independently of browser tab lifetime
- Phase 8B multimodal image/vision attachments can be uploaded, resolved, and inferred
- Phase 8C accessibility, UI polish, and responsive web adaptations are complete
- Remote access over Tailscale/private mesh is authenticated with revocable credentials
- Master secrets remain outside clients, logs, and normal Git content

*(Note: Production Android backend sync, Android offline inference, voice/audio pipeline, and Health Connect are strategic post-V1 roadmap capabilities; see [SYSTEM_BASELINE.md](docs/04_Architecture/SYSTEM_BASELINE.md)).*

---

## Documentation & Architecture Authority

New contributors and AI agents navigate the project starting from the canonical documentation map:

```text
docs/06_Guides/DOCUMENTATION_MAP.md
```

Canonical system baseline, locked architectural decisions (D1–D9), and current boundaries are defined in:

```text
docs/04_Architecture/SYSTEM_BASELINE.md
```

Major architectural decisions are recorded as ADRs under:

```text
docs/04_Architecture/decisions/
```

---

## New-Chat / AI Handoff

For a new development session:

1. Follow the canonical documentation hierarchy starting with `AGENTS.md` and `docs/06_Guides/DOCUMENTATION_MAP.md`.
2. Consult `docs/04_Architecture/SYSTEM_BASELINE.md` for current system baseline and locked decisions D1–D9.
3. Check `docs/01_Tracking/task.md` for current execution state and immediate blockers.
4. Do not assume planned features are already implemented; verify via source code and tests.

Suggested handoff:

```text
I am resuming work on AI Companion.

Please inspect:
1. AGENTS.md and docs/06_Guides/DOCUMENTATION_MAP.md for process and documentation authority.
2. docs/04_Architecture/SYSTEM_BASELINE.md for system baseline and locked decisions D1-D9.
3. docs/01_Tracking/task.md for active sprint status and immediate blockers.

Do not assume planned features are already implemented. Verify with source code and tests.
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
