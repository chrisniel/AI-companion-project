# AI Companion — Canonical System Baseline & Architecture Core

> **Document Role:** Normative architecture and product baseline for AI Companion V1 and future capabilities.  
> **Status:** Active Canonical (Decisions D1–D9 Locked)  
> **Last Updated:** 2026-09-20 (Reconciliation Pass R2)

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
- **Memory persistence & retrieval** (SQLite with FTS5 lexical/keyword search)
- **Task and reminder lifecycle** (CRUD, soft-delete, automated retention purge)
- **Model library & runtime management** (Schema v3 registry, GGUF metadata parsing, runtime profile switching)
- **Phase 8B Multimodal Vision** (image attachment API, client composer, and vision-model inference)
- **Phase 8C Integration & Polish** (accessibility, bundle optimization, UI consistency, responsive web cleanup)
- **Release Hardening** (automated SQLite backup, migration safety preflight, secure configuration)

### Explicitly Excluded from V1 (Preserved for Future Milestones)
- Production Android backend synchronization
- Android offline on-device inference
- Voice & audio pipeline (VAD, Whisper STT, Kokoro TTS, wake word)
- Health Connect and wearable device synchronization
- Proactive companion routines / scheduled autonomous check-ins
- Autonomous external tools and general web-action agents
- Direct public internet exposure or port forwarding
- Managed online model downloading (in-app Hugging Face downloaders)
- Vector / semantic embedding database

---

## 3. Windows Host Model & Remote Access (Decisions D2 & D5)

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

### Windows Host Process (D2)
- The V1 Local AI Runtime runs as an **independent, long-running Windows host process**.
- It does **not** depend on browser tab lifetime.
- Closing or reloading the React Web browser interface must **never** terminate backend execution, cancel active inference, disrupt database transactions, or abort scheduled background tasks.
- React Web is the primary V1 PC UI. A native desktop shell (e.g., Tauri, Electron, or WinUI) is **not** part of V1.
- Any future native shell will wrap or launch the stable Local AI Runtime API; it must never absorb backend business logic.
- Exact Windows startup mechanism (startup app, Scheduled Task, service, or launcher) remains intentionally decoupled and open.

### Remote Access Trust Boundary (D5)
- V1 network access is restricted to:
  1. `localhost` / loopback
  2. Explicitly configured, trusted local area network (LAN) bindings
  3. **Tailscale / private mesh networks** as the approved mechanism for remote connectivity
- V1 does **not** support or require direct public internet exposure or router port forwarding.
- Future controlled public ingress may use Cloudflare HTTPS / edge services, but transport encryption never replaces application-level authentication.
- **Three-Tier Trust Boundary:**
  $$\text{Network / Transport Trust (Tailscale / TLS)} \longrightarrow \text{Trusted-Device Authentication (Revocable Credential)} \longrightarrow \text{Profile Authorization}$$

---

## 4. Profiles & Trusted Devices (Decisions D4 & D8)

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Local AI Runtime Database                       │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                     Profile (User Identity)                    │   │
│   │  id: default-profile                                           │   │
│   │  owns: Conversations, Memories, Tasks, Preferences             │   │
│   └───────────────▲───────────────────────────────▲────────────────┘   │
│                   │ 1                             │ 1                  │
│                   │                               │                    │
│                   │ N                             │ N                  │
│   ┌───────────────┴──────────────┐ ┌──────────────┴────────────────┐   │
│   │         Device: PC           │ │        Device: Phone          │   │
│   │ device_id: win-desktop-01    │ │ device_id: infinix-zero-01    │   │
│   │ credential: hash(secret_a)   │ │ credential: hash(secret_b)    │   │
│   │ capabilities: [web, admin]   │ │ capabilities: [mobile_client] │   │
│   └──────────────────────────────┘ └───────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

### Profile vs. Device Separation (D4)
- A **Profile** represents a human user identity and owns all personal data: conversations, memories, tasks, reminders, user preferences, and selected character persona.
- A **Device** represents a paired, trusted client endpoint (hardware instance) with its own `device_id`, friendly name, associated `profile_id`, revocable credential, capability set, and last-seen timestamp.
- Profiles and Devices are **not permanently 1:1**. A single profile may pair multiple trusted client devices.
- Master PC application secrets are **never** distributed directly to client devices. Each device receives an independently revocable credential upon pairing.
- Network proximity or private IP presence never substitutes for application-level device authentication.

### Single-Primary-User Baseline (D8)
- AI Companion V1 operates as a **single-primary-user system**.
- A single default profile is sufficient for V1; multi-profile management UI is not required for the initial release.
- However, persistent storage schemas preserve the explicit owning-profile boundary (`owner_id` represents the owning profile).
- Existing `owner_id` fields are preserved in place without disruptive database migrations. Multi-profile capabilities in later milestones will activate this boundary rather than requiring a persistence redesign.

---

## 5. Memory & Character Ownership Scoping (Decision D7)

Memory and personal identity adhere to a strict **Profile-First** ownership model:

```text
Profile (User Identity)
  ├── Canonical Personal Data (Conversations, Tasks, Reminders, Profile Preferences)
  └── Memories (Persistent Facts)
        ├── Scope: PROFILE (Default — available across all characters/personas)
        └── Scope: CHARACTER (Optional — associated with character_id, retrieved only in context)

Character (Persona Configuration)
  ├── Persona Definition (System prompt, personality traits, background lore)
  ├── Presentation (Avatar image/GIF, Live2D/VRM configuration, theme cues)
  └── Voice Profile (TTS voice ID, speed, prosody, style hints)
```

> [!IMPORTANT]
> **Ownership Invariant:** Characters do **not** own the user's fundamental identity, conversation history, task items, or canonical memory records.  
> Switching from one character/persona to another alters the *perspective and presentation* of the assistant, but **never** deletes, truncates, or resets the user's memories or tasks.

---

## 6. Model Acquisition & Installation Pipeline (Decision D6)

Primary user-facing local model imports enter the ecosystem through a deterministic, validated pipeline:

```text
User / Import Source
         │
         ▼
┌──────────────────┐
│ IMPORT_INBOX_DIR │  (Landing zone for raw model files)
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Preflight Check  │  (Validate GGUF format, header metadata, architecture, path/capacity safety)
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ IMPORT_STAGING   │  (Quarantine staging while validating integrity)
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Atomic Install   │  (Atomic file move / promotion into library)
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ MODEL_LIBRARY_DIR│  (COMPANION_DATA_ROOT/library/models/ — canonical storage)
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Model Registry   │  (Updated in INSTALLED_REGISTRY_PATH; discoverable in UI)
└──────────────────┘
```

- `MODEL_LIBRARY_DIR` (`%LOCALAPPDATA%\AI Companion\Data\library\models`) is the canonical storage location for all user-installed model files.
- The managed import pipeline provides the primary user-facing path (`inbox` → `preflight` → `staging` → `atomic install` → `library` → `registry`). Preflight includes format checks, capacity/path safety, and integrity/checksum validation as defined by the eventual importer contract.
- Direct manual placement into `MODEL_LIBRARY_DIR` remains supported as an advanced developer fallback, recognized by runtime preflight scans and discovery.
- Future automated acquisition sources (e.g., Hugging Face, network downloads, mobile-driven acquisition) feed into this same validated pipeline rather than introducing disjoint installation logic.

---

## 7. Tool, Web & Autonomy Security Model (Decision D9)

Inference models and agent workflows **never** receive unrestricted operating system, device, network, or filesystem authority.

### Execution Pipeline
$$\text{Model} \longrightarrow \text{Typed Tool Request} \longrightarrow \text{Deterministic Policy Engine} \longrightarrow \text{Narrow Adapter} \longrightarrow \text{Capability}$$

The policy engine operates under an immutable **DEFAULT DENY** posture.

### 4-Tier Risk Classification Matrix

| Tier | Classification | Description & Examples | Execution Policy |
| :--- | :--- | :--- | :--- |
| **Risk 0** | **Read-Only / Information** | Public web search, weather queries, permitted webpage reading, internal memory/task inspection, runtime telemetry. | May auto-execute when enabled by profile/device policy. |
| **Risk 1** | **Reversible Low-Impact** | Creating personal tasks, scheduling non-alarm reminders, user notifications, harmless preference toggles. | Profile-configurable auto-approval. |
| **Risk 2** | **Significant State Change** | Deleting tasks/conversations, external message transmission, web form submission, model uninstallation, sensitive configuration updates. | **Explicit user confirmation required** by default. |
| **Risk 3** | **Privileged / Destructive** | Arbitrary shell/command execution, unrestricted filesystem mutations, credential access, OS/network configuration. | **DEFAULT DENY.** Requires explicit, narrow, time-bounded user authorization. |

### Security Invariants
- Models cannot grant permissions to themselves.
- Untrusted user prompt content cannot elevate privileges (prompt injection defense).
- External web content fetched during tool execution is treated as untrusted data.
- Search/fetch capabilities are strictly isolated from interactive web actions (e.g., form submissions, clicking).
- General-purpose interactive command shells are prohibited as standard assistant tools.
- All sensitive tool invocations produce persistent, auditable diagnostic logs.

### Emergency Control Invariants
The system architecture reserves the following deterministic controls:
1. **Stop Generation:** Immediate abort of current inference streaming.
2. **Stop Current Action:** Immediate cancellation of an in-flight tool request.
3. **Stop All Actions:** Termination of an active multi-step agent loop.
4. **Global Autonomous Disable:** Master application configuration kill switch disabling all tool execution.

---

## 8. Preserved Future Architecture (Post-V1 Milestones)

The following capabilities are approved strategic directions for future milestones. They are **not** requirements for V1 and must not be treated as active delivery blockers:

### Android Application Identity (D3)
- Future Package / Namespace: `com.cnl.aicompanion`
- Future Application ID: `com.cnl.aicompanion`
- Identity principle: Character-independent, provider-independent, and product-oriented.

### Android Offline Mode & Synchronization
- **Connected Mode:** When connected to the PC host (via LAN or Tailscale), the PC Local AI Runtime serves as the primary inference, storage, and orchestration authority.
- **Offline Mode:** When disconnected, the Android client may switch to a local on-device engine running a small quantized model, utilizing local cache and device-local STT/TTS.
- **Reconnection:** On reconnecting to the PC host, device-local changes synchronize and reconcile back to the Local AI Runtime, which remains the permanent source of truth.

### Reference Mobile Benchmark (Evidence Baseline)
- Hardware Reference: Infinix ZERO ULTRA X6820 (MediaTek Dimensity 920, 8 GB RAM, Android 13).
- Observed local llama.cpp / PocketPal inference generation speeds:
  - **Gemma 3 270M Q8:** ~25.56 tok/s
  - **Qwen3.5 0.8B Q4_K_M:** ~14.81 tok/s
  - **Llama 3.2 1B Q4_K_M:** ~12.37 tok/s
  - **Qwen3 0.6B Q8:** ~11.75 tok/s
- *Conclusion:* 0.5B–1B quantized local models are viable offline candidates on mid-range Android hardware. Qwen3.5 0.8B is also a promising future multimodal candidate, though mobile vision inference remains unvalidated.

### Mobile Speech & TTS Provider Direction
- Speech synthesis and recognition use provider abstractions rather than hardcoded engines.
- Future mobile TTS candidates: **KittenTTS** (lightweight on-device candidate), **Kokoro** (high quality, but observed slower on reference phone), and **Android System TTS** (universal fallback).
- Final mobile TTS defaults remain deferred to the dedicated Voice implementation phase.

### Web & Information Provider Direction
- External information integrations must adhere to vendor-independent provider interfaces:
  - `WebSearchProvider`: Initial candidates: Tavily (primary), SearXNG (self-hosted option), Exa (research option).
  - `FetchProvider`: Initial candidates: Jina Reader (primary), direct HTTP, Firecrawl.
  - `WeatherProvider`: Open-Meteo (routine global forecast), PAGASA official bulletins (authoritative Philippine severe weather).
  - `BrowserProvider`: Local Playwright (deferred future option; browser automation is not in V1).
- All fetch implementations must enforce defenses against Server-Side Request Forgery (SSRF), internal network scanning, loopback access, and redirect-to-private-IP vulnerabilities.

---

## 9. Current Repository Implementation Reality (Verified Baseline)

As of commit `ded8c1a` on `develop` (and active branch `chore/repository-documentation-reconciliation`):

| Component | Implemented & Verified Reality | Known Non-Implemented Boundary |
| :--- | :--- | :--- |
| **Backend Core** | FastAPI application, CORS, request body limiters, fail-closed auth, dependency injection, logging. | Tool execution engine and provider adapters not implemented. |
| **Persistence** | SQLite WAL mode, Alembic migrations 001–005 (`005_scope_message_constraints`), Task CRUD, soft-delete, automated retention purge. Canonical paths resolved via `COMPANION_DATA_ROOT`. | Attachment table (006) and character persistence not implemented. |
| **Local LLM Engine** | `llama.cpp` Vulkan x64 (build b10936), AMD RX 580 VRAM offload profiles (Eco/Balanced/Maximum), subprocess management, isolated log. | Multiple concurrent active models not supported. |
| **Model Registry** | Schema v3 bridge, dual factory/installed discovery, GGUF binary header parser for metadata, `contracts/openapi/openapi.json` contract drift checks. | Automated background download manager and import staging pipeline service not implemented. |
| **Frontend Web** | React 19, TypeScript 5.8, Vite 6, Tailwind CSS 4, live SSE streaming chat, tactile VRAM controls, decomposed Assistant components, truthful registry. | Full attachment uploading (Phase 8B) and responsive mobile web layout hardening (Phase 8C) not implemented. |
| **Android Prototype** | 17 Jetpack Compose screens, SoftGlass neumorphic theme, OLED battery-saver theme, SharedPreferences storage, 110 passing unit tests. | Real FastAPI network client, Room persistence, and on-device offline inference not implemented. |
| **Testing & CI** | 88 passing backend pytest tests, 132 passing frontend vitest tests, GitHub Actions CI workflow on `windows-latest` with automated gates. | CI gate not yet set as a required branch protection rule on GitHub. |

---

## 10. R2 Decision Traceability Matrix

Decisions D1 through D9 were formally resolved during the documentation reconciliation audit (Passes R0–R1) and are codified canonically in this document:

| Decision ID | Area | Resolution Summary | Audit Reference |
| :--- | :--- | :--- | :--- |
| **D1** | **V1 Release Boundary** | AI Companion V1 is defined strictly as the PC-hosted release. Android sync and voice are deferred post-V1. "PC Core" retired. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D1 |
| **D2** | **Windows Host Model** | Independent long-running Windows host process; decoupled from browser lifetime; native desktop shell deferred post-V1. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D2 |
| **D3** | **Android Identity** | Application ID & package: `com.cnl.aicompanion`; product-oriented, character-independent. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D3 |
| **D4** | **Profiles & Devices** | Profile represents user identity; Device represents trusted client endpoint. Independent revocable credentials per device. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D4 |
| **D5** | **Remote Access Trust** | Localhost, trusted LAN, and Tailscale private mesh supported for V1. Public exposure not required. Multi-tier trust model. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D5 |
| **D6** | **Model Acquisition** | Controlled local import pipeline: inbox → preflight → staging → atomic install → library. `MODEL_LIBRARY_DIR` is canonical. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D6 |
| **D7** | **Memory Scoping** | Profile-first ownership. Memories belong to profile (default `PROFILE` scope, optional `CHARACTER` scope). Characters do not own data. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D7 |
| **D8** | **Single-User Baseline** | Single-primary-user for V1; schema uses `owner_id` representing profile boundary. No gratuitous renames. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D8 |
| **D9** | **Security & Permissions** | DEFAULT DENY. 4-tier risk matrix (Risk 0–3). Typed requests through deterministic policy engine. Emergency stop controls. | `docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md` §D9 |

*Forensic reconciliation history, diagnostics, and working notes remain documented in [REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md](../00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md).*
