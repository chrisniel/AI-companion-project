# Architecture & Design Specification: Phase 8A.3b.3 — Characters + Devices + Logs + Settings Truthfulness Sweep

**Date:** 2026-09-14  
**Author:** AI Pair Programmer & System Architect  
**Status:** Approved Design Baseline — Documentation Only (Implementation Deferred)  
**Target Milestone:** Phase 8A.3b.3  
**Canonical References:**
- `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`
- `docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`
- `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md`

---

## 1. Scope & Execution Boundary

Phase 8A.3b.3 is the final sub-batch of the Phase 8A Production Truthfulness Sweep (`8A.3b`). It encompasses four remaining view domains in the PC desktop web interface:
1. `CharactersView` (`frontend/web/src/components/workspace/CharactersView.tsx` and sub-components)
2. `DevicesView` (`frontend/web/src/components/workspace/DevicesView.tsx` and sub-components)
3. `LogsView` (`frontend/web/src/components/workspace/LogsView.tsx`)
4. `SettingsView` (`frontend/web/src/components/workspace/SettingsView.tsx` and sub-components)

### Strict Operational Boundaries
- **Documentation Only Pass**: No production source code, backend code, or Android code is modified during this design pass.
- **Zero Backend Changes**: No new backend endpoints, telemetry routes, logging sockets, or database models.
- **Zero Migrations**: No schema modifications or Alembic migration scripts.
- **Zero Android Changes**: `android/` codebase serves as architectural reference only.
- **Zero New APIs**: No synthetic REST or WebSocket APIs created to satisfy frontend mock expectations.
- **No Implementation of Future Systems**: Future capabilities (profiles, desktop overlay, TTS/STT, Tailscale, device registry) are documented exclusively as architectural targets.
- **Commit Boundary**: User owns all Git commits and pushes. The AI does not commit or push.

---

## 2. Core Truthfulness Invariant: Approach B (Hybrid Truthfulness)

The PC frontend adheres strictly to epistemic truthfulness:

$$\text{State Representation} = \begin{cases}
\mathbf{Real} & \text{if implemented and backed by an authoritative source} \\
\mathbf{Planned\ /\ Not\ Implemented} & \text{if architecture exists but implementation does not} \\
\mathbf{Preview} & \text{if UI concept or wireframe showcase only} \\
\mathbf{Unavailable} & \text{if no authoritative source exists}
\end{cases}$$

### Fundamental Ground Rules
1. **Never Simulate Operational Success**:
   - Never show fake connected phones, fabricated pings, mock log streams, or fake local database saves.
2. **Authoritative Sources Required**:
   - UI status indicators and metrics must derive exclusively from genuine backend endpoints (such as `GET /api/v1/system/status`) or genuine frontend client state (such as `ThemeContext`).
3. **No Phantom Settings**:
   - Browser `localStorage` state alone does NOT make a runtime setting implemented.
   - If toggling a control has no actual product or runtime effect, it must NOT be presented as an operational system setting.

---

## 3. Characters — Approved Future Model & Current Boundary

### 3.1 Current vs. Future Boundary
- **Current Production State (Phase 8A)**:
  - `CharactersView` is mock-backed (`mockCharacters` from `mock/characterData.ts`) and React-local only.
  - There is no character backend, no SQLite character table, and no mechanism for a character to alter system prompts or llama.cpp generation parameters.
- **8A.3b.3 Design Rule**:
  - Retain Character Studio as an interactive **UI/architecture preview**.
  - Remove mock characters as production authority.
  - Remove fake active-character state.
  - Remove fake Add/Edit/Save persistence (no false claims of saving to local database).
  - Remove production claims that a selected preview character affects assistant behavior.
  - Clearly label persistence and activation as **Planned**.

### 3.2 Canonical Future Character Architecture
When implemented in future phases (post-Phase 8), characters will follow this clean architectural decomposition:

```
Character
├── Identity
│   ├── id: string (unique stable identifier)
│   ├── display_name: string
│   ├── description: string
│   └── persona/system prompt: string (base identity / background instructions)
├── Personality
│   ├── optional archetype preset: Optional[string]
│   └── continuous trait values 0–100 (trait vector)
├── Voice
│   └── preferred voice ID: string
└── Presence
    └── presentation configuration
```

#### Archetype Presets vs. Continuous Trait Vectors
Archetypes such as:
- `tsundere`
- `dandere`
- `kuudere`
- `yandere`
- `warm`
- `playful`
- `formal`
- `custom`

are **PRESETS only**. Archetype names must **never** be the complete behavioral model.

The underlying model uses continuous trait dimensions (0–100), for example:
- `warmth` (0–100)
- `teasing` (0–100)
- `guardedness` (0–100)
- `directness` (0–100)
- `expressiveness` (0–100)
- `affection` (0–100)
- `formality` (0–100)
- `verbosity` (0–100)

*Note: The exact final schema for the trait vector is deferred to the dedicated character subsystem milestone.*

> [!IMPORTANT]
> **Safety Invariant**: Character safety and factual behavior remain governed by core AI Companion rules. A personality preset or trait vector adjustment must **never** override safety, factual constraints, airgap guarantees, or tool authorization boundaries.

---

## 4. Profile / Character Separation

Future profiles behave similarly to **Netflix profiles**:
- **Single Installation**: One AI Companion local installation.
- **Multiple Local Profiles**: Multiple user profiles on the same workstation.
- **No Cloud Accounts**: Strictly local profiles, NOT separate cloud accounts.

```
AI Companion Installation (Single Local Instance)
└── Local User Profiles (e.g., "Primary User", "Creative Profile")
    ├── Conversations (owned by Profile)
    ├── Memories (owned by Profile)
    ├── Tasks & Schedule (owned by Profile)
    ├── User Preferences (owned by Profile)
    └── preferred_character_id ──► Character Registry (Shared Catalog)
                                       ├── Character A (Tsundere Preset)
                                       ├── Character B (Calm / Warm Preset)
                                       └── Neutral Built-in Assistant (Fallback)
```

### Invariants:
1. **Ownership Separation**:
   - The **Profile** owns conversations, memories, tasks, preferences, and the future `preferred_character_id`.
   - The **Character** does **NOT** own user memories, tasks, or conversations.
2. **Resolution Pipeline**:
   $$\text{profile.preferred\_character\_id} \longrightarrow \text{Character Registry} \longrightarrow \text{Character Configuration} \longrightarrow \text{prompt / personality / voice / presence}$$
3. **Neutral Assistant Fallback (Approach B)**:
   - If a new profile has no preferred character, the system falls back to the **Neutral built-in Assistant**.
   - Do **NOT** require Lisa or any optional character pack for application boot or core runtime operation.
   - Custom or named characters may be installed later.

---

## 5. Character Packs / Public Repository Boundary

Future character data will eventually live outside hardcoded frontend mock arrays, adhering to the canonical data-root layout:

```
<COMPANION_DATA_ROOT>/characters/<character-id>/
├── character.json       (identity, traits, voice mapping)
├── avatar.png           (2D portrait / icon)
├── prompts/
│   └── system.md        (base persona prompt)
└── assets/              (visual states, audio samples)
```

### Invariants:
- **Do NOT implement this storage in 8A.3b.3**: Persistent character assets belong to later runtime and persistent-asset phases (Phase 8P / post-Phase 8).
- **Public Repository Boundary**: Do not bundle copyrighted third-party artwork, commercial game assets, or cloned actor voices into the public repository.
- **User Installation**: The system may support user-installed local character packs later, installed directly by users into `<COMPANION_DATA_ROOT>/characters/`.

---

## 6. Future Character Presence Layer (Far Future Desktop Companion)

Character Presence describes **how the companion appears**, completely decoupled from identity, personality, or voice.

> [!CAUTION]
> **Far Future Documentation Only**: Character Presence is documented exclusively as an architectural boundary. Do **NOT** implement any Presence feature in Phase 8.

### Core Architectural Decoupling Rule:
$$\begin{aligned}
\mathbf{Character} &\implies \text{Decides WHO and HOW (identity, prompt, traits)} \\
\mathbf{Voice} &\implies \text{Decides HOW IT SOUNDS (speech synthesis, pitch)} \\
\mathbf{Presence} &\implies \text{Decides HOW IT APPEARS (visual renderer, animations)} \\
\mathbf{Profile} &\implies \text{Owns USER DATA (memories, tasks, history)}
\end{aligned}$$

Changing the presentation renderer must **never** alter:
- User memory
- Tasks or schedule
- Conversation history
- Profile identity
- Personality state

### Potential Renderers (Future Evaluation):
- Static image / expression sheet
- Animated image / animated GIF / WebP sequence
- Animated 2D / Live2D-style implementation
- 3D model (glTF / VRM)

### Potential Future Desktop-Companion Behavior:
- Transparent desktop overlay
- Draggable position
- Persistent screen position
- Always-on-top option
- Click and hover interactions
- Idle animation loops
- Semantic emotion states
- Lip sync to audio playback
- Speaking animation
- Proactive notification reactions (e.g. reacting to alarms/reminders)

---

## 7. Devices — 8A.3b.3 Design

### 7.1 Real Backend Host Information (Authoritative Source)
The backend already provides an authoritative host telemetry endpoint:
`GET /api/v1/system/status`

It truthfully supplies:
- `status`: operational state (`"ok"`)
- `platform`: host operating system (`"Windows"`)
- `python_version`: runtime environment
- `hostname`: local machine identifier
- `cpu_count`: physical/logical cores
- `version`: backend application version
- `database_connected`: SQLite connection health
- `timestamp`: server-authoritative timestamp

`DevicesView` may truthfully display this real host/runtime workstation state.

### 7.2 Unsupported Subsystems (Planned / Unavailable)
Everything without an authoritative source becomes **Planned** or **Unavailable**:
1. Android device registry
2. Android sync bridge
3. Alarms synchronization
4. Health device synchronization
5. Audio-device manager
6. Microphone routing
7. Speaker routing
8. Bluetooth state
9. Smartwatch / wearable source
10. Health Connect source
11. Remote gateway
12. Tailscale connectivity
13. Remote latency
14. LAN / Tailscale runtime ingress

### 7.3 Prohibited Production Simulations to Remove
Remove all simulated operational indicators in `DevicesView`:
- Fake endpoint counts
- Fake status: `"Local Mesh Healthy"`
- Fabricated ping / latency (e.g. `"14ms"`, `"12ms"`)
- Fake connected phones (e.g. `"Pixel 9 Pro Connected"`, battery `"84%"`)
- Fake mTLS claims (`"mTLS Verified"`, `"ED25519"`)
- Fake sync timestamps (`"Synced 2s ago"`)
- Fake gateway IPs (`"192.168.1.144"`)
- Fake packet loss meters (`"0.0% Loss"`)
- Mock provider switching

*Note: Remote runtime access over LAN/Tailscale is a FUTURE architectural goal and is NOT implemented here.*

---

## 8. Logs — 8A.3b.3 Design

### 8.1 Current Reality
The backend currently has **no logs or telemetry API** (no WebSocket, no SSE, no REST endpoint for log streams).

### 8.2 Truthful Resolution
In `LogsView`:
- **Remove `initialMockLogs`** as production authority.
- **Remove `streamingEventTemplates`** from production behavior.
- **Remove random generated log stream** (cancel/remove interval timers synthesizing logs).
- **Remove fake "Live Stream" status**.
- **Remove fake average latency** metrics.
- **Remove fake error and buffer counts**.

### 8.3 Truthful UI State
- Display clear, truthful messaging:
  > **"Runtime log streaming is not implemented yet."**
- Retain the visual terminal container shell as a **Preview / Planned** affordance so the layout structure remains available for future wiring.
- Do **NOT** create a backend log API in Phase 8A.

---

## 9. Settings — 8A.3b.3 Design

### 9.1 The LocalStorage Boundary Rule
> [!IMPORTANT]
> **Browser `localStorage` state alone does NOT make a runtime setting implemented.**  
> If toggling a setting has no actual product or runtime effect, it must not be presented as an operational system setting.

### 9.2 Real vs. Planned Classification

#### REAL NOW:
- **Appearance settings** that genuinely affect `ThemeContext` and UI presentation:
  - Theme mode (Dark / Light / System)
  - Layout density / compact mode
  - Font scaling & accent styling

#### PREVIEW / PLANNED:
- **General startup behavior** not actually wired (launch on OS boot, start minimized)
- **Assistant personality behavior** not actually wired
- **Character assignment persistence**
- **Voice / TTS / STT settings** (voice selection, speech rate, transcription engine)
- **Wake word / VAD controls** ("Hey Companion", sensitivity)
- **Health settings** (sync frequency, metric thresholds)
- **Hardware / audio settings** (input mic, output speaker, noise suppression)
- **Remote network / Tailscale** (mesh keys, ingress port)
- **Privacy controls** without authoritative runtime implementation
- **Unsupported Advanced settings** (context window overrides, KV cache offload)

### 9.3 Invariants & Truthful Copy:
- **AI Runtime Configuration**: Belongs primarily to later **Phase 8P**. Do not duplicate fake runtime configuration state in Settings.
- **Remove False Persistence Claims**:
  - Eliminate the false claim: `"Persisted Locally (SQLite & Keyring)"`.
  - Use truthful wording based on the actual persistence source:
    - Appearance: *"Persisted in Browser Local Storage"*
    - Planned system/runtime settings: *"Configuration schema planned for Phase 8P"*
- **Application States Showcase**:
  - The `Application States` page must remain explicitly labeled as a **UI/UX showcase or Preview** and must not be interpreted as current runtime state.

---

## 10. Explicit Non-Goals / Out of Scope

The following are strictly out of scope for Phase 8A.3b.3:
- Do NOT implement profiles or multi-user switching.
- Do NOT implement a character registry backend or SQLite tables.
- Do NOT implement persistent character pack loaders or file storage.
- Do NOT bundle Lisa or any other named character packs.
- Do NOT implement voice engines, TTS, STT, or voice cloning.
- Do NOT implement 3D / GIF avatar runtimes or Live2D rigging.
- Do NOT implement desktop overlay windows or always-on-top daemons.
- Do NOT implement remote Tailscale runtime access or mesh routing.
- Do NOT implement device registry or Android sync bridges.
- Do NOT implement backend telemetry or log streaming endpoints.
- Do NOT implement new Settings backend endpoints.
- Do NOT modify `backend/` or `android/` code.
- Do NOT run or create database migrations.

---

## 11. Test & Acceptance Expectations for Later Implementation

When implementation of 8A.3b.3 is authorized, verification will require:
1. **CharactersView**:
   - Zero production imports of `mockCharacters` or `mockVoiceOptions`.
   - Character Studio rendered cleanly as an interactive Preview.
   - No fake active character state or claims of SQLite persistence.
2. **DevicesView**:
   - Consumes and displays real host information from `GET /api/v1/system/status`.
   - Displays truthful Planned/Unavailable states for Android, Wearables, Audio, and Tailscale Mesh.
   - Zero fabricated pings, battery percentages, or fake gateway IPs.
3. **LogsView**:
   - Zero production imports of `initialMockLogs` or `streamingEventTemplates`.
   - Zero running synthetic log timers.
   - Truthful message displayed: *"Runtime log streaming is not implemented yet."*
4. **SettingsView**:
   - Appearance settings remain functional and wired to `ThemeContext`.
   - Unwired settings marked as Planned / Preview without false Keyring/SQLite claims.
   - Clear attribution of local storage vs. planned backend configuration.
5. **Grep Absence Verification**:
   - Production bundle contains no occurrences of `Local Mesh Healthy`, `14ms`, `initialMockLogs`, `streamingEventTemplates`, `Persisted Locally (SQLite & Keyring)`.
