# AI Companion Project

A local-first, privacy-focused personal AI companion ecosystem centered around a persistent **Local AI Runtime**, a dedicated **Flutter Desktop** companion application, a supported **React Web** development harness, and a future **Android Companion** mobile client.

---

## 1. Project Overview & Core Philosophy

The AI Companion is built on the belief that a truly personal assistant must run locally, respect user privacy, and operate independently of third-party cloud services while remaining modular, extensible, and performant.

### Core Principles
- **Local-First Execution:** Large language models, speech engines, and personalization data execute locally on consumer PC hardware. Cloud fallback is strictly opt-in and transparent.
- **Persistent Windows Host:** Assistant state, scheduling, memory, and model inference reside in an independent Windows background runtime that survives UI closure.
- **Multi-Profile Identity:** Supports multiple isolated user profiles under a single installation account, with strict profile data partitioning.
- **Deterministic Action Policy:** The language model produces typed action requests evaluated against deterministic, configurable security policies (Default Deny). The model never possesses raw shell authority.
- **Privacy & User Control:** Personal memories, schedules, and conversation histories are transparent, inspectable, and user-correctable.

---

## 2. Architecture & System Topology

The ecosystem separates the long-running host runtime from client presentation interfaces:

```text
┌─────────────────────────────────────────────────────────────┐
│                       Client Layer                          │
│                                                             │
│   ┌──────────────────────────┐   ┌──────────────────────┐   │
│   │  Flutter Desktop (Win)   │   │   React Web Client   │   │
│   │  • Primary PC V1 Target  │   │   • Supported Browser/Remote + Dev/Regression │   │
│   │  • System Tray & Shell   │   │   • Web Dashboard    │   │
│   │  • Hardware Audio Owner  │   │   • Diagnostic Tools │   │
│   └────────────┬─────────────┘   └──────────┬───────────┘   │
│                │ REST / SSE / WS            │ REST / SSE    │
└────────────────┼────────────────────────────┼───────────────┘
                 │                            │
                 ▼                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Local AI Runtime                     │
│               FastAPI • Python 3.11 • asyncio               │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Assistant Engine • Turn Queue • Token Stream (SSE)    │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ Memory Engine (FTS5 Lexical Search & Retention)       │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ Scheduler Service (Tasks, Reminders, Alarms)          │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ Action Dispatcher & Deterministic Security Policy     │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ Speech Engines (Local STT & TTS over WebSocket)       │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ Storage & DB (SQLite with Alembic Migrations)         │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│                              ▼                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Model Execution Layer (llama.cpp / Vulkan)     │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                               ▲
                               │ Local LAN / Tailscale
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              Android Companion App (Prototype)              │
│       Kotlin • Jetpack Compose • Follow-on Milestone        │
└─────────────────────────────────────────────────────────────┘
```

### Component Roles
- **Local AI Runtime (`backend/`):** Long-running FastAPI daemon owning conversation turn queues, SQLite+FTS5 persistence, model execution, deterministic action policies, and speech engines.
- **Flutter Desktop (`frontend/flutter/apps/desktop/`):** The approved PC V1 target primary production client (M1 foundation implemented, verified locally, PR candidate), providing the desktop shell, system tray integration, fail-closed auth, and chat with streaming/Markdown.
- **React Web Client (`frontend/web/`):** Supported browser/remote client + dev/regression oracle providing rich inspection dashboards.
- **Android Companion (`android/`):** Dedicated mobile companion prototype. The Kotlin/Compose repository is reference implementation evidence for V1 boundaries; detailed mobile architecture is a follow-on pass.

---

## 3. Reference Hardware Baseline

The PC V1 release is tuned and benchmarked against standard consumer hardware:

- **CPU:** AMD Ryzen 5 3600 (6 cores, 12 threads)
- **RAM:** 16 GB DDR4
- **GPU:** AMD Radeon RX 580 2048SP (8 GB VRAM, Vulkan offload)
- **OS:** Windows 11 (64-bit)

*Resource Profile:* The runtime operates with a single resident LLM by default (`--models-max 1`) to preserve system resources and allow concurrent gaming or desktop workloads.

---

## 4. Repository Structure

```text
AI-companion-project/
├── backend/                # FastAPI Local AI Runtime
│   ├── app/                # Core logic, domain services, API routes, models
│   ├── alembic/            # SQLite database schema migrations
│   └── tests/              # Backend test suites (pytest)
├── frontend/
│   ├── flutter/            # Flutter monorepo pub workspace (packages & apps/desktop)
│   └── web/                # React 19 / Vite / Tailwind web client
├── android/                # Native Android companion application (prototype)
├── contracts/
│   └── openapi/            # Canonical OpenAPI specifications
├── docs/                   # Strict numbered documentation hierarchy
│   ├── 01_Tracking/        # Active task.md and delivery archives
│   ├── 02_Planning/        # Master Planning Spine (00_Master), active plans, templates
│   ├── 03_Walkthroughs/    # Educational delivery walkthroughs
│   ├── 04_Architecture/    # System Baseline, ADRs, and 18 focused domain specs
│   ├── 05_Design/          # UI/UX design specifications
│   ├── 06_Guides/          # Contributor guides, setup instructions, workflows
│   └── 07_Archive/         # Historical plans and superseded audits
├── AGENTS.md               # AI agent working rules and project profile
├── CHANGELOG.md            # Append-only release changelog
└── CONTRIBUTING.md         # Git branching and contributor guidelines
```

*Target Note:* Flutter Desktop is the approved PC V1 client target; M1 foundation is implemented under `frontend/flutter/` (packages and `apps/desktop`) with local verification complete and hosted PR CI pending.

---

## 5. Documentation & Getting Started

Contributors and developers should consult canonical documentation via the entry-point guides:

- **Global Navigation & Authority:** [`docs/06_Guides/DOCUMENTATION_MAP.md`](docs/06_Guides/DOCUMENTATION_MAP.md)
- **System Baseline Architecture:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](docs/04_Architecture/SYSTEM_BASELINE.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](docs/02_Planning/00_Master/DELIVERY_INDEX.md)
- **Developer Setup Guide:** [`docs/06_Guides/DEVELOPMENT_SETUP.md`](docs/06_Guides/DEVELOPMENT_SETUP.md)
- **Engineering Delivery Workflow:** [`docs/06_Guides/DELIVERY_WORKFLOW.md`](docs/06_Guides/DELIVERY_WORKFLOW.md)
- **Testing & Verification Standards:** [`docs/06_Guides/TESTING_AND_CI.md`](docs/06_Guides/TESTING_AND_CI.md)
