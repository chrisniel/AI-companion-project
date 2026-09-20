# AI Companion — Canonical System Baseline & Architecture Core

> **Document Role:** High-level normative architecture and product baseline for AI Companion V1 and future capabilities.  
> **Status:** Active Canonical (Decisions D1–D9 Locked)  
> **Last Updated:** 2026-09-21 (Reconciliation Pass R3.2)

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

AI Companion **V1** is defined as the first complete, stable, **PC-hosted release**.

### In Scope for V1
- **Local AI Runtime** independent Windows host process
- **React Web** primary desktop interface
- **Local text LLM inference** via `llama.cpp` (GGUF, Vulkan offload on AMD RX 580)
- **Multi-turn conversation management** with live SSE streaming completions
- **Memory persistence & retrieval** (SQLite with FTS5 lexical search)
- **Task and reminder lifecycle** (CRUD, soft-delete, retention threshold calculation; automated periodic lifecycle scheduling and reminder execution are remaining V1 wiring concerns)
- **Model library & runtime management** (Schema v3 registry, GGUF metadata parsing, runtime profiles)
- **Controlled local model import pipeline** (inbox → preflight → staging → atomic install → library; execution service is an active V1 implementation gap)
- **Phase 8B Multimodal Vision** (image attachment API, client composer, and vision-model inference)
- **Phase 8C Integration & Polish** (accessibility, bundle optimization, UI consistency, responsive web cleanup)
- **Release Hardening** (migration safety preflight, secure configuration defaults, and release hardening as approved through dedicated implementation plans)

### Explicitly Excluded from V1 (Post-V1 Milestones)
- Production Android backend synchronization
- Android offline on-device inference
- Voice & audio pipeline (VAD, Whisper STT, Kokoro TTS, wake word)
- Health Connect and wearable device synchronization
- Proactive companion routines / scheduled autonomous check-ins
- Autonomous external tools and general web-action agents
- Direct public internet exposure or port forwarding
- Managed online model downloading (in-app Hugging Face browsing / remote downloaders)
- Vector / semantic embedding database

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

- **Windows Host Process (D2):** The Local AI Runtime runs as an independent Windows host process decoupled from browser tab lifetime. Closing the React Web tab never terminates backend inference, database transactions, or tasks. React Web is the primary V1 UI; native desktop shells (e.g., Tauri) are deferred post-V1.
- **Remote Access Trust Boundary (D5):** Network access is restricted to `localhost`, trusted LAN bindings, and Tailscale private mesh networks. Public internet exposure and port forwarding are not supported for V1. Details: [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md).

---

## 4. Locked Architectural Invariants Summary

The following major architectural invariants are locked across the ecosystem. Detailed domain specifications reside in their respective canonical documents:

- **Profiles & Trusted Devices (D4 & D8):** AI Companion V1 operates as a single-primary-user system. The **Profile** owns all personal data (`owner_id`). Currently implemented using a single shared application credential; future architecture introduces per-device revocable credentials. Master secrets are never distributed to client devices. Details: [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md).
- **Memory & Character Scoping (D7):** Memory adheres to a strict Profile-First model. Memories belong to the Profile (default `PROFILE` scope, optional `CHARACTER` scope). Characters define persona presentation (system prompt, avatar, voice profile) and never own the user's canonical identity. Persona switching alters perspective, never user data. Details: [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md).
- **Model Acquisition & Installation Pipeline (D6):** Managed local model imports follow a deterministic pipeline: `inbox` → `preflight` → `staging` → `atomic install` → `library` → `registry`. Controlled local import is a V1 requirement (the execution service is currently an active implementation gap). `MODEL_LIBRARY_DIR` (`<COMPANION_DATA_ROOT>/library/models/llm`, resolving by default on Windows to `%LOCALAPPDATA%\AI Companion\Data\library\models\llm`) is the canonical storage location. Direct placement may remain available as an advanced/developer fallback. Details: [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md).
- **Tool & Autonomy Security Model (D9):** Tool execution enforces an immutable **DEFAULT DENY** posture and a 4-tier risk matrix (Risk 0–3). Generative models possess zero self-elevation authority. Prompt injection cannot elevate permissions, and fetched web content is isolated as untrusted data. Deterministic emergency stop controls are reserved. Details: [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md).
- **Android Product Identity & Mobile Inference (D3):** Application ID and package namespace: `com.cnl.aicompanion`. Connected Mode uses PC Local AI Runtime as the canonical authority; future Offline Mode targets local compact quantized models (tested envelope of ~0.27B–1.24B produced ~11.75–25.56 tok/s on reference hardware). Android sync and offline inference are strictly post-V1. Details: [`ANDROID_COMPANION_ARCHITECTURE.md`](ANDROID_COMPANION_ARCHITECTURE.md).
- **Voice & Audio Pipeline:** CPU-first speech execution; vendor-independent `TTSProvider` abstraction (candidate engines: Kokoro, Piper, KittenTTS, Android System TTS; no universal default locked). Voice capabilities are strictly post-V1. Details: [`VOICE_AND_AUDIO_ARCHITECTURE.md`](VOICE_AND_AUDIO_ARCHITECTURE.md).

---

## 5. Current Repository Implementation Reality

As of active reconciliation on branch `chore/repository-documentation-reconciliation`:

| Subsystem | Implemented & Verified Reality | Known Non-Implemented Boundary |
| :--- | :--- | :--- |
| **Backend Core** | FastAPI application, CORS origin validation, request streaming body limiter (HTTP 413), fail-closed auth (`verify_token`), logging. | Tool execution engine and provider adapters not implemented. |
| **Persistence** | SQLite WAL mode, Alembic migrations 001–005 (`005_scope_message_constraints`), Task CRUD, soft-delete, retention period calculation, and standalone purge runner. Canonical paths derived via `storage.py` (`MODEL_LIBRARY_DIR` = `library/models/llm`, `INSTALLED_REGISTRY_PATH` = `library/registry/models.json`). | Attachment table (006), backend character persistence table, and automatic periodic lifecycle scheduling of retention purge not implemented. |
| **Local LLM Engine** | `llama.cpp` Vulkan x64 (b10936), AMD RX 580 VRAM offload profiles (Eco/Balanced/Maximum), subprocess management, router log (`database/llama_server.log`). | Multiple concurrent active models not supported. Managed router receives `LLAMA_MODELS_DIR`. |
| **Model Registry** | Schema v3 bridge, dual factory/installed discovery, GGUF binary header parser for metadata, contract drift checks. | Controlled local importer execution service is an active V1 implementation gap; automated online download manager is post-V1. |
| **Frontend Web** | React 19, TypeScript 5.8, Vite 6, Tailwind CSS 4, live SSE streaming chat, tactile VRAM controls, decomposed Assistant components, truthful registry. | Full attachment uploading (Phase 8B) and responsive mobile web layout hardening (Phase 8C) not implemented. |
| **Android Prototype** | 17 Jetpack Compose screens, SoftGlass neumorphic theme, OLED battery-saver theme, SharedPreferences storage, 110 passing unit tests. | Real FastAPI network client, Room persistence, and on-device offline inference not implemented. |
| **Testing & CI** | 88 passing backend pytest tests, 132 passing frontend vitest tests, GitHub Actions CI workflow on `windows-latest` with automated gates. | CI gate not yet set as a required branch protection rule on GitHub. |

---

## 6. Canonical Domain Architecture Index

For detailed architectural contracts, refer to the authoritative domain specifications:

| Domain | Canonical Specification Document | Primary Questions Answered |
| :--- | :--- | :--- |
| **Runtime Config & Storage** | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) | Where do data, models, and configs live? How does the D6 import pipeline work? How are migrations handled? |
| **LLM Inference Engine** | [`LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](LLAMA_CPP_RUNTIME_ARCHITECTURE.md) | How does `llama-server.exe` execute? How do VRAM offload profiles, idle sleep, and process lifecycle operate? |
| **Security & Trust** | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) | How does authentication work? How are devices paired? What is the D9 tool risk policy and SSRF defense model? |
| **Memory & Characters** | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md) | Who owns user data? How does profile-first scoping operate? What are the character persona boundaries? |
| **Android Mobile Client** | [`ANDROID_COMPANION_ARCHITECTURE.md`](ANDROID_COMPANION_ARCHITECTURE.md) | What is the mobile identity? How do Connected and Offline modes operate? What are the reference mobile benchmarks? |
| **Voice & Speech Processing** | [`VOICE_AND_AUDIO_ARCHITECTURE.md`](VOICE_AND_AUDIO_ARCHITECTURE.md) | How is speech processing architected? Which TTS/STT providers are planned? Why is speech CPU-first? |

---

## 7. R2/R3 Decision Traceability Matrix (D1–D9)

| Decision ID | Area | Resolution Summary | Canonical Owner |
| :--- | :--- | :--- | :--- |
| **D1** | **V1 Release Boundary** | AI Companion V1 is defined strictly as the PC-hosted release. Android sync and voice are deferred post-V1. "PC Core" retired. | `SYSTEM_BASELINE.md` §2 |
| **D2** | **Windows Host Model** | Independent long-running Windows host process; decoupled from browser lifetime; native desktop shell deferred post-V1. | `SYSTEM_BASELINE.md` §3, `LLAMA_CPP_RUNTIME_ARCHITECTURE.md` |
| **D3** | **Android Identity** | Application ID & package: `com.cnl.aicompanion`; product-oriented, character-independent. | `ANDROID_COMPANION_ARCHITECTURE.md` |
| **D4** | **Profiles & Devices** | Profile represents user identity; Device represents trusted client endpoint. Independent revocable credentials per device. | `SECURITY_AND_TRUST_ARCHITECTURE.md` |
| **D5** | **Remote Access Trust** | Localhost, trusted LAN, and Tailscale private mesh supported for V1. Public exposure not required. Multi-tier trust model. | `SECURITY_AND_TRUST_ARCHITECTURE.md` |
| **D6** | **Model Acquisition** | Controlled local import pipeline (V1 requirement): inbox → preflight → staging → atomic install → library. `MODEL_LIBRARY_DIR` is canonical. | `AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md` |
| **D7** | **Memory Scoping** | Profile-first ownership. Memories belong to profile (default `PROFILE` scope, optional `CHARACTER` scope). Characters do not own data. | `MEMORY_AND_CHARACTER_ARCHITECTURE.md` |
| **D8** | **Single-User Baseline** | Single-primary-user for V1; schema uses `owner_id` representing profile boundary. Preserved in place. | `SECURITY_AND_TRUST_ARCHITECTURE.md`, `MEMORY_AND_CHARACTER_ARCHITECTURE.md` |
| **D9** | **Security & Permissions** | DEFAULT DENY. 4-tier risk matrix (Risk 0–3). Typed requests through deterministic policy engine. Emergency stop controls. | `SECURITY_AND_TRUST_ARCHITECTURE.md` |

---

*Forensic reconciliation history, diagnostics, and working notes remain documented in [`REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md`](../00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md).*


