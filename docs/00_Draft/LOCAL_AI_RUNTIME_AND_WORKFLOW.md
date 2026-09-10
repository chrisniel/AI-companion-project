# Local AI Control Center — Runtime, Workflow, and Technical Architecture

> **Purpose:** Explain how the current repository is intended to run, what each directory is for, how the local AI model will operate on the PC, how TTS/STT/audio fit into the system, and what the development and production workflows should look like.
>
> **Current state:** Only the React web frontend is implemented and runnable. The other top-level folders are placeholders for planned subsystems.

---

# 1. Current Repository Structure

Current project root:

```text
companion-ai-project/
├── android/
├── backend/
├── config/
├── contracts/
├── docs/
├── frontend/
│   └── web/
├── scripts/
└── tests/
```

## Folder Responsibilities

| Folder | Purpose | Current State |
|---|---|---|
| `frontend/web/` | React PC Control Center | Implemented and runnable |
| `android/` | Kotlin / Jetpack Compose companion app | Planned / empty |
| `backend/` | Python FastAPI Local AI Core | Planned / empty |
| `config/` | Runtime/provider configuration examples | Planned / empty |
| `contracts/` | OpenAPI + realtime event schemas | Planned / empty |
| `docs/` | Master roadmap, architecture, decisions | Ready for documentation |
| `scripts/` | Start/stop/install/dev helper scripts | Planned / empty |
| `tests/` | Cross-system and integration tests | Planned / empty |

The empty folders are not broken exports. They are placeholders for the planned architecture.

---

# 2. What Can Run Right Now

At the moment, only the React frontend is runnable.

From:

```text
D:\Anything\OtherProjects\companion-ai-project\frontend\web
```

run:

```powershell
npm install
npm run dev
```

Vite will usually expose a local development URL such as:

```text
http://localhost:5173/
```

After `npm install`, the following will normally appear:

```text
node_modules/
package-lock.json
```

Commit:

```text
package-lock.json
```

Do not commit:

```text
node_modules/
```

The current TypeScript check can also be run with:

```powershell
npm run lint
```

Note: the current script is effectively a TypeScript typecheck, not a full lint configuration.

---

# 3. Eventually, Multiple Processes Will Run

The finished system will consist of several cooperating local processes.

Conceptually:

```text
                         YOUR PC

┌──────────────────────────────────────────────────────┐
│                                                      │
│  React UI                                            │
│  localhost:5173 during development                   │
│        │                                             │
│        ▼                                             │
│  FastAPI Local AI Core                              │
│  localhost:8000                                     │
│        │                                             │
│        ├──────── llama.cpp server                    │
│        │         localhost:8081                     │
│        │                                             │
│        ├──────── STT Provider                        │
│        │                                             │
│        ├──────── TTS Provider                        │
│        │                                             │
│        ├──────── SQLite                             │
│        │                                             │
│        ├──────── Scheduler                           │
│        │                                             │
│        └──────── Audio Device Manager                │
│                                                      │
└──────────────────────────────────────────────────────┘
```

During development, these may run in separate terminals.

Later, helper scripts should start them together.

---

# 4. The React UI Is Not the AI

The React application is the dashboard and control surface.

It should not contain the actual AI runtime, database logic, scheduling engine, or device-control logic.

Conceptually:

```text
React
"Hey, what should I do today?"
          │
          ▼
FastAPI Local AI Core
          │
          ▼
Local AI Model
          │
          ▼
FastAPI
          │
          ▼
React
"Here are your priorities..."
```

Closing the browser should eventually **not** stop the Local AI Core.

---

# 5. How the Local AI Model Runs

The intended initial local inference runtime is `llama.cpp`, likely using `llama-server`.

A local model will normally be stored as a GGUF file.

Conceptually:

```text
D:\AI\Models\
└── assistant-model-q4.gguf
```

Model files should generally stay outside Git.

A local model server could be started conceptually like:

```powershell
llama-server.exe `
  -m "D:\AI\Models\model.gguf" `
  --host 127.0.0.1 `
  --port 8081
```

The actual GPU/offload arguments should be chosen only after benchmarking the real RX 580 setup.

FastAPI then communicates with:

```text
http://127.0.0.1:8081
```

The intended flow is:

```text
React
  ↓
FastAPI
  ↓
llama.cpp
  ↓
GGUF model
```

The React frontend should never directly access the model file.

---

# 6. Will the AI Model Start Automatically?

Eventually, the answer should be **yes**, but not necessarily by permanently reserving VRAM.

Recommended behavior:

## Local AI Core

The Local AI Core should start automatically with Windows.

Example startup sequence:

```text
Windows login
     ↓
Local AI Core starts
     ↓
Scheduler active
Database active
Device monitoring active
API active
```

## AI Model

The AI model should support **lazy loading**.

Example:

```text
No AI activity
      ↓
Model unloaded / standby

User sends message
      ↓
Core starts llama.cpp
      ↓
Loads model
      ↓
Assistant responds
```

After an idle timeout:

```text
Idle for 15–30 minutes
      ↓
Unload model
      ↓
Free VRAM
```

This is especially useful on a PC that is also used for gaming and development.

---

# 7. Performance Profiles

The backend should translate simple user-facing performance modes into technical runtime settings.

## Eco

Goal:

```text
small model
lower GPU allocation
more CPU/RAM usage
shorter context
aggressive idle unload
```

Useful while:

```text
gaming
Android Studio
Unity
heavy development
```

## Balanced

Goal:

```text
normal GPU allocation
normal context
moderate idle timeout
```

Recommended default.

## Maximum

Goal:

```text
larger AI allocation
more GPU offload
longer model residency
```

Useful when AI is the main workload.

The UI should only expose:

```text
Eco
Balanced
Maximum
```

The backend/provider layer decides the actual runtime flags.

---

# 8. FastAPI Is the Orchestrator

FastAPI is the central manager between all subsystems.

Conceptually:

```text
                    Local AI Core
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
      LLM              Memory            Tools
       │                 │                 │
   llama.cpp           SQLite          Tasks
   Gemini              FTS5            Alarms
   Ollama                              Search
                                       Devices
```

The model itself should not directly modify the database, scheduler, files, or devices.

---

# 9. Tool Execution Flow

Example user request:

```text
Remind me tomorrow at 8 AM to check the Android UI.
```

The model may propose:

```text
create_reminder(
    title="Check Android UI",
    time="tomorrow 08:00"
)
```

The real action flow should be:

```text
LLM proposes action
       ↓
FastAPI validates
       ↓
Permission check
       ↓
Scheduler creates it
       ↓
SQLite stores it
       ↓
FastAPI returns success
       ↓
LLM presents the result
```

A model saying an action succeeded is not enough. The backend must actually execute and confirm it.

---

# 10. TTS Architecture

TTS means:

```text
text → spoken audio
```

Example pipeline:

```text
LLM
 ↓
text response
 ↓
TTSProvider
 ↓
local TTS engine
 ↓
Audio Device Manager
 ↓
Bluetooth headset / speaker
```

Possible local TTS providers later may include:

```text
Piper
Kokoro
```

The assistant logic should only know about a generic interface such as:

```text
TTSProvider.speak(...)
```

That allows providers to change without rewriting the assistant.

---

# 11. STT Architecture

STT means:

```text
speech → text
```

Example:

```text
User says:
"What's on my schedule today?"

Microphone audio
      ↓
STT
      ↓
"What's on my schedule today?"
```

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
text
    ↓
Assistant
```

The exact STT provider/model should be chosen after benchmarking local options.

---

# 12. VAD

VAD means **Voice Activity Detection**.

Its role is to determine when the user actually starts and stops speaking.

Conceptually:

```text
silence
silence
silence
speech starts
████████████
speech ends
silence
```

Without VAD, the system would have to continuously process microphone audio.

VAD helps reduce unnecessary STT work and improves interaction timing.

---

# 13. Full Home Voice Interaction

The intended Home Mode flow is:

```text
User speaks
    ↓
PC microphone
    ↓
VAD detects speech
    ↓
STT
    ↓
"What do I have tomorrow?"
    ↓
Local AI Core
    ↓
Memory / Schedule tool
    ↓
Local LLM
    ↓
"You have..."
    ↓
Local TTS
    ↓
Bluetooth headset
```

The current expected Home Mode output is a Bluetooth headset connected directly to the PC.

Audio routing must remain configurable rather than hardcoded.

Example UI:

```text
Input:
[ USB Mic ▼ ]

Output:
[ Bluetooth Headset ▼ ]
```

Later the devices can change without changing the assistant architecture.

---

# 14. Voice Interruption / Barge-In

The user should be able to interrupt TTS playback.

Example:

Assistant is speaking:

```text
"Tomorrow you have a meeting at nine and then at..."
```

User interrupts:

```text
"Wait, what meeting?"
```

Desired behavior:

```text
TTS Speaking
     ↓
VAD detects user speech
     ↓
Cancel current TTS
     ↓
Flush remaining audio
     ↓
LISTENING
     ↓
STT new question
```

This is commonly called **barge-in**.

---

# 15. Voice State Machine

Recommended voice state flow:

```text
IDLE
 ↓
LISTENING
 ↓
TRANSCRIBING
 ↓
THINKING
 ↓
EXECUTING TOOL
 ↓
SPEAKING
 ↓
IDLE
```

Additional states:

```text
INTERRUPTED
OFFLINE
RECONNECTING
ERROR
```

The frontend avatar/UI should react to these semantic states.

---

# 16. Away Mode

When the user is away from the PC, the Android app becomes the audio endpoint.

Conceptually:

```text
Android microphone
       ↓
Internet / Tailscale / Remote Gateway
       ↓
FastAPI on PC
       ↓
STT
       ↓
LLM
       ↓
TTS
       ↓
audio stream
       ↓
Android speaker/headset
```

For network audio, a compressed format such as Opus may be considered later instead of raw PCM for all transport.

The internal STT/TTS pipeline may still operate on PCM.

---

# 17. What Happens if the PC Is Off

In V1:

```text
PC OFF
 ↓
Local AI unavailable
```

However, the Android app should still retain selected local functions:

```text
mirrored alarms
cached tasks
cached schedules
local notifications
Health Connect
basic cached data
```

Example:

If the PC is unavailable when a 7:00 AM alarm is due, Android should still trigger the mirrored alarm.

Optional future behavior:

```text
Android → Gemini
```

as a cloud fallback when the PC is unavailable.

This is not required for V1.

---

# 18. Memory Architecture

Long-term memory should not mean loading all historical data into every prompt.

Instead:

```text
SQLite

preferences
projects
events
facts
profile data
temporary context
```

Example query:

```text
"What were we planning for the Android app?"
```

Retrieval flow:

```text
query
 ↓
MemoryRetriever
 ↓
SQLite FTS5
 ↓
top relevant memories
 ↓
small context package
 ↓
LLM
```

Future enhancement:

```text
FTS5
+
embeddings
```

Only if semantic retrieval is actually needed.

---

# 19. Search and Current Information

The local model itself does not automatically know current web information.

Future architecture:

```text
Question
 ↓
Assistant determines current information is needed
 ↓
SearchProvider
 ↓
web results
 ↓
local LLM summarizes
```

Web retrieval and cloud AI are separate concerns.

Gemini is not required merely because web search is needed.

---

# 20. Scheduler

The scheduler is part of the Local AI Core and continues working even when the React UI is closed.

Conceptually:

```text
Local AI Core
    ↓
Scheduler
    ↓
SQLite
```

It manages:

```text
Tasks
Reminders
Schedules
Recurring events
PC alarms
```

---

# 21. Development Workflow

During early development, multiple terminals may be used.

## Terminal 1 — Local Model

Conceptually:

```powershell
llama-server ...
```

## Terminal 2 — FastAPI

Conceptually:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000
```

## Terminal 3 — React

```powershell
cd frontend\web
npm run dev
```

## Android Studio

Run the Android app separately.

---

# 22. Development Helper Scripts

Later, create helper scripts such as:

```text
scripts/
├── start-dev.ps1
├── stop-dev.ps1
├── start-core.ps1
└── start-model.ps1
```

Then development startup can become:

```powershell
.\scripts\start-dev.ps1
```

instead of manually launching every process.

---

# 23. Production Web Workflow

Vite is only needed for development.

For production:

```powershell
npm run build
```

This generates a production bundle such as:

```text
frontend/web/dist/
```

Two options exist.

## Option A — FastAPI Serves React

Recommended for a personal V1.

Conceptually:

```text
localhost:8000
├── /
├── /assistant
└── /api/v1/...
```

Then production mainly needs:

```text
FastAPI
+
llama.cpp
```

No separate permanent Vite server is needed.

## Option B — Separate Static Web Server

Possible, but likely unnecessary for the initial local-first version.

---

# 24. Eventual Windows Startup

A polished Local AI Core startup could look like:

```text
Windows starts
     ↓
Local AI Core launcher
     ↓
Database migration/check
     ↓
Scheduler restored
     ↓
Audio devices discovered
     ↓
Network initialized
     ↓
FastAPI starts
     ↓
Model remains on standby
```

Opening:

```text
http://localhost:8000
```

loads the dashboard.

The model can lazy-load on first assistant use.

---

# 25. Optional Windows Tray App

A future tray interface could provide:

```text
Local AI Core ● Running

Open Dashboard
Performance: Balanced
Unload Model
Restart Core
Exit
```

This is optional but useful for local desktop management.

---

# 26. Planned Backend Structure

The `backend/` directory may eventually become:

```text
backend/
├── app/
│   ├── main.py
│   ├── api/
│   ├── core/
│   ├── db/
│   ├── schemas/
│   ├── repositories/
│   ├── services/
│   ├── providers/
│   │   ├── llm/
│   │   ├── stt/
│   │   └── tts/
│   ├── memory/
│   ├── scheduling/
│   ├── health/
│   ├── voice/
│   ├── devices/
│   └── networking/
├── migrations/
├── tests/
└── pyproject.toml
```

---

# 27. Planned Contracts Structure

```text
contracts/
├── openapi/
└── events/
```

Purpose:

- generated API contracts
- event schemas
- shared protocol definitions

---

# 28. Planned Config Structure

```text
config/
├── examples/
│   ├── core.example.yaml
│   ├── models.example.yaml
│   └── audio.example.yaml
```

Purpose:

- example runtime configuration
- provider settings
- audio/device preferences
- non-secret defaults

Do not commit real secrets.

---

# 29. Planned Docs Structure

```text
docs/
├── MASTER_IMPLEMENTATION_ROADMAP.md
├── WEB_FRONTEND_STATIC_REVIEW.md
├── LOCAL_AI_RUNTIME_AND_WORKFLOW.md
├── architecture/
└── decisions/
```

---

# 30. Android Architecture Still Holds

The clarified runtime model confirms the Android direction rather than changing it.

Conceptually:

```text
                    LOCAL AI CORE
                         PC
                          │
          ┌───────────────┴──────────────┐
          │                              │
     React Dashboard                Android App
     Management UI                  Companion UI
```

## React Specializes In

```text
models
runtime
settings
logs
memory management
device management
detailed configuration
```

## Android Specializes In

```text
assistant
voice
alarms
tasks
health
notifications
quick actions
mobile connectivity
```

Android also owns direct access to:

```text
Health Connect
AlarmManager
Android notifications
phone microphone
phone audio
```

---

# 31. Recommended Development Sequence

Recommended order from the current state:

```text
PC React UI
     ✓

Static frontend review
     ✓

Android UI/UX design
     ↓
Android Build batches
     ↓
PC frontend cleanup
     ↓
FastAPI foundation
     ↓
SQLite
     ↓
llama.cpp
     ↓
React ↔ FastAPI
     ↓
Memory / Tasks / Schedule
     ↓
Voice stack
     ↓
Android ↔ FastAPI
     ↓
Health Connect
     ↓
Alarm redundancy
     ↓
Networking
```

The empty folders should be filled gradually according to implementation milestones.

They do not all need to be populated immediately.

---

# 32. Summary

The intended finished system is:

```text
React Web Dashboard
        │
        ▼
FastAPI Local AI Core
        │
        ├── llama.cpp / local LLM
        ├── SQLite / Memory
        ├── Scheduler
        ├── Tools
        ├── STT
        ├── TTS
        ├── Audio Device Manager
        ├── Health integration
        └── Remote connectivity
        │
        ▼
Android Companion
```

The Local AI Core is the persistent system service.

The React UI is the PC management interface.

The Android app is the mobile companion.

The local model can lazy-load and unload based on usage.

Voice is handled through separate VAD, STT, TTS, and audio-routing subsystems.

Tasks, schedules, memory, and alarms belong to the Local AI Core, with important alarms mirrored to Android for redundancy.

The project should remain local-first, provider-independent, character-independent, device-configurable, and capable of optional cloud fallback later.
