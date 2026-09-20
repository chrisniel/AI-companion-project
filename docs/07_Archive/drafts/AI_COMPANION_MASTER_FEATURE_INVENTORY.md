# AI Companion Project — Master Feature Inventory

> **Purpose:** Consolidated inventory of features that have been requested, planned, discussed, or recommended for the AI Companion project.
>
> **Important:** This is a **feature inventory**, not a claim that every item is implemented. Some features exist only as UI/mock prototypes, some are planned, and some are deliberately deferred.

## Legend

- **[Requested]** Explicitly asked for or proposed by you.
- **[Recommended]** Recommended during our architecture/design discussions.
- **[Both]** Your direction plus architectural refinement/recommendation.
- **[Prototype]** Represented in current UI/mock work.
- **[Future]** Intended for later phases.
- **[Deferred]** Intentionally postponed.
- **[Guardrail]** Architectural/security constraint that should remain true.

---

# 1. Product Vision and Core Principles

- **[Both]** Local-first personal AI companion.
- **[Both]** Windows PC as the persistent **Local AI Core** and primary AI host.
- **[Both]** Android as companion client, not the main LLM host in V1.
- **[Both]** Provider-independent architecture for LLM, STT, TTS, search, health, memory, networking, and audio.
- **[Both]** Character-independent core architecture.
- **[Both]** Device-configurable architecture instead of hardcoding specific hardware into product logic.
- **[Requested]** Text interaction.
- **[Requested]** Voice interaction.
- **[Requested]** English, Filipino/Tagalog, and Japanese.
- **[Requested]** Natural multilingual code-switching.
- **[Requested]** Long-term memory.
- **[Requested]** Tasks, reminders, schedules, and alarms.
- **[Requested]** Health / wellness integration.
- **[Requested]** Configurable characters/personas and voices.
- **[Requested]** Local and remote access.
- **[Recommended]** Android retains useful offline features when the PC is unavailable.
- **[Guardrail]** Models propose actions; trusted backend code validates and executes them.
- **[Guardrail]** The LLM never gets unrestricted shell/filesystem/database/device/network authority.
- **[Guardrail]** Secrets/API keys stay backend-side.
- **[Guardrail]** Retrieved memory is context, never system authority.

---

# 2. Local AI Core / Backend

## 2.1 Core Service

- **[Both]** FastAPI Local AI Core.
- **[Recommended]** Core orchestrates clients, models, tools, memory, scheduler, health, and devices.
- **[Recommended]** REST API for standard operations.
- **[Recommended]** Typed WebSocket events for streaming assistant/voice/runtime activity.
- **[Recommended]** OpenAPI-defined contracts.
- **[Recommended]** Versioned endpoints such as `/api/v1/...`.
- **[Recommended]** Health/status endpoint.
- **[Recommended]** Explicit semantic runtime states rather than clients guessing backend state.

## 2.2 Replaceable Provider Interfaces

- **[Recommended]** `LLMProvider`
- **[Recommended]** `STTProvider`
- **[Recommended]** `TTSProvider`
- **[Recommended]** `SearchProvider`
- **[Recommended]** `HealthProvider`
- **[Recommended]** `MemoryRetriever`
- **[Recommended]** `NetworkGateway`
- **[Recommended]** `AudioDeviceManager`

## 2.3 Trusted Tools / Actions

- **[Requested]** Tool/function calling.
- **[Guardrail]** Model emits structured tool proposals instead of directly running commands.
- **[Recommended]** Schema validation and permission checks.
- **[Recommended]** Explicit execution success/failure result.
- **[Recommended]** Tool execution events visible in assistant activity UI.
- **[Recommended]** Local audit trail.
- **[Recommended]** Confirmation for destructive/high-impact actions.
- **[Recommended]** Per-tool permissions.
- **[Future]** More capable OS/computer automation after security boundaries are proven.

---

# 3. Local LLM / Model Runtime

## 3.1 Runtime

- **[Both]** `llama.cpp` / `llama-server` preferred local runtime.
- **[Both]** GGUF model format.
- **[Recommended]** Vulkan / partial GPU offload for Windows AMD RX 580-class hardware.
- **[Recommended]** CPU+GPU mixed inference where useful.
- **[Recommended]** Benchmark before hardcoding layer counts or memory limits.
- **[Recommended]** Lazy model loading.
- **[Recommended]** Configurable idle model unloading, initially around 15–30 minutes as a tunable idea.
- **[Requested]** Keep AI resource use modest enough to leave room for gaming/dev work.
- **[Requested]** Rough target of about 2–4 GB VRAM where practical.

## 3.2 Compute Profiles

- **Eco**
- **Balanced**
- **Maximum**
- **[Guardrail]** No Turbo profile.

Possible profile controls:

- CPU threads.
- GPU offload.
- context-window target.
- generation limits.
- model residency.
- latency vs resource-use balance.

## 3.3 Routing Policies

- **Local Only**
- **Local First**
- **Cloud First**
- **Cloud Only**

## 3.4 Model Management

- Current model.
- Local/cloud/provider indicator.
- quantization.
- context window.
- model availability.
- loading/unloading state.
- basic latency/performance.
- available model catalog.
- switch/activate model.
- optional compact Android PC-resource summary.
- detailed runtime telemetry primarily on desktop.

## 3.5 Optional Cloud Fallback

- **[Requested]** Optional Gemini or other cloud provider fallback.
- **[Guardrail]** Cloud is optional, not foundational.
- **[Guardrail]** Cloud keys stay in Local AI Core/backend.
- **[Recommended]** Explicit routing UI.
- **[Recommended]** No silent cloud routing of private local data.

---

# 4. Memory System

## 4.1 User-Facing Memory

- Search.
- View.
- Edit.
- Archive / restore.
- Delete.
- tags.
- timestamps.
- human-readable records.

Memory categories discussed:

- Profile
- Preference
- Fact
- Project
- Event
- Temporary

## 4.2 Retrieval / Storage

- **[Both]** SQLite first.
- **[Both]** SQLite FTS5.
- **[Recommended]** Start simple before a dedicated vector database.
- **[Future]** Embeddings.
- **[Future]** Hybrid lexical + semantic search.
- **[Future]** Reranking.
- **[Recommended]** Optional retrieval confidence/category in developer activity UI.
- **[Guardrail]** Memory never overrides trusted instructions.

---

# 5. Tasks

- Today view.
- Upcoming view.
- Completed view.
- create.
- edit.
- delete.
- complete/incomplete.
- snooze.
- multilingual titles/descriptions.
- project/category.
- priority.
- due date/time.
- reminder.
- progress summary on Home.
- Quick Add from Home.
- shared repository/state so Home and Tasks stay synchronized.
- future persistent storage.
- future PC↔Android synchronization.

Prior priority ideas:

- Low
- Medium
- High
- Urgent

Prior category ideas:

- Work
- Personal
- Development
- Shopping
- Health
- General

---

# 6. Schedule / Calendar

- Day timeline.
- Agenda view.
- compact week view.
- filters.
- task items.
- reminder items.
- alarm items.
- calendar-event items.
- completion/dismiss actions.
- source/location metadata where available.
- Home “Next Up” card.
- countdowns.
- priority indicator.
- **[Recommended]** Scheduler runs independently of React/browser lifetime.
- **[Recommended]** Server-side recurring scheduler in Local AI Core.
- **[Future]** External calendar integrations.
- **[Future]** Android mirrored schedule cache.

---

# 7. Alarms and Reminders

## 7.1 Alarm Features

- list alarms.
- create/edit/delete.
- enable/disable.
- time/title.
- recurrence/day selection.
- vibration.
- sound.
- default snooze.
- gradual volume ramp.
- PC mirroring toggle.
- redundancy status.
- Desktop synchronized / Android armed state.
- offline/local failover state.

## 7.2 Android Native Alarm Redundancy

- **[Future]** AlarmManager.
- **[Future]** Exact alarm capability handling.
- **[Future]** Local alarm firing when PC is off.
- **[Future]** Mirrored alarm cache.
- **[Future]** Native notification/sound fallback.
- **[Future]** WorkManager for suitable non-exact background tasks.

---

# 8. Voice System

## 8.1 Voice Pipeline

`Audio Input → VAD → STT → Local AI Core → LLM/Tools/Memory → TTS → Audio Device Manager → Output`

Features:

- configurable microphone/input.
- configurable speaker/output.
- VAD.
- multilingual STT.
- mixed-language recognition.
- preserve code-switched transcription instead of translating it.
- local TTS where practical.
- candidate TTS: Piper / Kokoro.
- candidate STT: Whisper-family / whisper.cpp-style implementation.
- benchmark STT/TTS before final defaults.
- barge-in/interruption.
- configurable Bluetooth warmup.
- PC-paired headset in Home Mode.

## 8.2 Voice Semantic States

- Idle
- Listening
- Transcribing
- Thinking
- Executing Tool
- Speaking
- Interrupted
- Reconnecting
- Offline
- Error

## 8.3 Mobile Voice Mode

- immersive full-screen mode.
- normal nav hidden while active.
- state-reactive avatar.
- waveform/visualizer.
- transcript.
- multilingual/code-switch transcript.
- mute.
- interrupt.
- end session.
- text fallback.
- prototype semantic-state simulator.

## 8.4 Future Voice Features

- wake word.
- continuous background microphone after privacy/battery review.
- more advanced audio routing.
- low-latency Android↔PC streaming audio.

---

# 9. Multilingual Features

Supported languages:

- English
- Filipino / Tagalog
- Japanese

Conversation behavior:

- automatic detection.
- match user language.
- natural code-switching.
- preserve mixed input.
- primary language.
- understood-languages multi-select.
- response language preference.
- technical terminology language preference.

Japanese display:

- Japanese only.
- Japanese + Romaji.
- Japanese + English translation.
- **[Deferred]** Furigana/ruby rendering.

Voice recognition modes:

- Auto
- English
- Filipino / Tagalog
- Japanese

Capability labels:

- Supported
- Limited
- Unsupported
- Unknown

---

# 10. Characters / Personas

## 10.1 Character Library

- multiple personas.
- active persona.
- display name.
- avatar.
- voice specification.
- sample dialogue.
- create.
- duplicate.
- edit.
- reset to defaults.

## 10.2 Persona Controls

- persona definition.
- response style.
- cadence/speaking style.
- voice/timbre.
- visual avatar styling.
- primary/secondary language.
- match-user-language.
- code-switch style.
- Tagalog frequency.
- Japanese frequency.
- Japanese tone.

Code-switch styles:

- Natural Blend
- Contextual Pivot
- Terminology Only
- None / Strict

Frequency levels:

- None
- Occasional
- Moderate
- Frequent
- Full

Japanese tone:

- Neutral
- Warm / Mature
- Playful
- Formal

Avatar display modes:

- Full
- Compact
- Voice Mode Only
- Hidden

Future avatar formats:

- GIF
- WebP
- Live2D
- VRM / 3D

- **[Recommended]** Backend emits semantic state; frontend chooses actual avatar asset/animation.

---

# 11. Desktop React Web Control Center

## 11.1 Layout

- desktop-first left sidebar.
- central workspace.
- optional right Assistant panel.
- compact header.
- global assistant composer.
- right panel expandable/collapsible/hidden.

## 11.2 Main Screens

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

## 11.3 Home

- Today overview.
- Next item.
- attention-needed items.
- system/runtime status.
- assistant status.
- tasks summary.
- schedule summary.
- wellness glance.
- quick actions.

## 11.4 Assistant Workspace

- normal chat.
- user messages.
- assistant messages.
- tool events.
- search events.
- memory events.
- system events.
- warnings/errors.
- streaming indicator.
- stop generation.
- copy.
- attachments.
- language selector.
- mic.
- conversation history.
- new conversation.
- provider/routing indicator.
- model metadata.
- developer telemetry where useful.

## 11.5 Right Assistant Panel

- persona/avatar.
- semantic state.
- current model.
- mic state.
- connection/runtime state.
- quick controls.

## 11.6 Runtime Management

- Local AI Core status.
- model status.
- model loading/unloading.
- performance profile.
- routing policy.
- logs.
- devices.
- audio devices.
- memory.
- provider configuration.
- runtime diagnostics.

---

# 12. Android Companion App

## 12.1 Bottom Navigation

Original prototype:

- Home
- Assistant
- Tasks
- Health
- More

Later requested redesign:

- **Home**
- **Tasks**
- **Assistant center action**
- **Health**
- **More**

Center Assistant concept:

- larger center icon.
- icon-only.
- emphasized/elevated/floating.
- Soft Glass treatment.
- inspired by center-action hierarchy, not a direct clone of another app.

## 12.2 More Hub

### Time & Agenda
- Schedule
- Alarms

### AI & Agents
- Characters
- Memory

### System & Hardware
- Models
- Devices
- Connection

### Application & System
- Settings
- About
- Permissions / Capabilities

## 12.3 Android Home

- dynamic greeting.
- core connection/reachability.
- assistant hero.
- active character.
- readiness state.
- PC core/model summary.
- Next Up.
- countdown.
- priority alert.
- today tasks.
- completion ratio.
- reminder count.
- Quick Add.
- quick actions: Ask, Add Task, Alarm, Reminder.
- compact wellness: sleep, resting HR, steps/activity.

## 12.4 Android Assistant

- mobile chat.
- header/title.
- rename conversation.
- provider/routing state.
- local/remote/offline state.
- attachments.
- multilingual input.
- language selector.
- microphone.
- send.
- stop generation.
- history.
- new conversation.

Later UX requests:

- new-chat-first experience.
- do not automatically open old conversation content.
- history accessible separately.
- resume an old session only when selected.
- warnings/errors/tool/system events should not dominate chat.
- compact activity/notification treatment with expandable details.
- remove Light/Dark quick toggles from normal top bars.
- Appearance belongs in Settings.

## 12.5 Android Tasks

All task features above, adapted for touch/mobile.

## 12.6 Android Schedule

- day.
- agenda.
- week strip.
- filters.
- item actions.

## 12.7 Android Alarms

- alarm cards.
- editor sheet.
- recurrence.
- vibration.
- sound.
- enabled state.
- PC mirror.
- redundancy/offline status.

## 12.8 Android Health

- source status.
- Health Connect status.
- Today/Week/Month.
- HR.
- Sleep.
- Steps.
- Activity.
- SpO2 if supported.
- trends.
- non-diagnostic insights.
- explicit missing-data states.
- prototype scenario switcher.

## 12.9 Android Memory

- search/view/edit/archive/delete.
- tags/categories.
- detail sheet.

## 12.10 Android Models

- current model.
- Local/Cloud badge.
- compute provider.
- context/quantization.
- Eco/Balanced/Maximum.
- routing policy.
- optional compact PC resources.
- model catalog.

## 12.11 Android Devices

- Local AI Core PC.
- this phone.
- audio output.
- microphone.
- health provider.
- online/offline/connecting.
- latency.
- diagnostics.
- generic naming instead of hardcoded brands.

## 12.12 Connection / Sync

Connection states:

- Local LAN
- Remote
- Connecting
- Reconnecting
- Offline

Sync states:

- Synchronized
- Pending
- Conflict
- Stale
- Failed

Features:

- status indicator.
- offline-capabilities sheet.
- retry.
- conflict resolution.
- Keep Local.
- Merge with Core.
- pending changes.
- calm connection banner.
- calm sync banner.

## 12.13 Android Offline Behavior

Available while PC is off:

- mirrored alarms.
- cached tasks.
- cached schedule.
- Health Connect data.
- local settings.
- local notifications.
- basic cache.

On-Device Edge Failover Mode (Hybrid AI Architecture):

- On-device local LLM failover inference (Gemma-2-2B / Qwen-2.5-1.5B via llama.cpp NDK).
- On-device neural voice synthesis (Kokoro-82M ONNX at <0.3x RTF).
- Zero-dependency private storage (SAF model import & in-app chunked downloader; no APK weight bloat).
- Model-agnostic universal chat history in local Room DB.
- Dynamic RAM clearing (mobile LLM unloaded when PC is online).
- AMOLED OLED Battery Saver mode (`#000000` pure black, zero drop-shadow calculations) for extended battery endurance.

Requires PC Core to be online:

- PC-hosted heavy model inference (8B+ models with full FP16/Vulkan GPU offload).
- PC system tools, file access, and OS automation.

## 12.14 Permissions / Capability UX

Capability UX for:

- Microphone
- Notifications
- Health Connect
- Exact alarms/scheduling
- Bluetooth audio only when actually needed

States include:

- Available
- Permission Needed
- Granted
- Denied
- Disabled
- Partial Access
- Unavailable
- Settings Action Required

Actions:

- Review Access
- Open Settings
- Try Again
- reset simulation

- **[Guardrail]** No unnecessary Bluetooth permission prompts.

---

# 13. Health and Wellness Architecture

Planned data path:

`Smartwatch → FitCloudPro → Android Health Connect → Android App → Local AI Core → SQLite`

Metrics:

- Heart Rate
- Resting HR
- Sleep duration
- Sleep score where available
- Steps
- Activity
- SpO2 where available

Availability states:

- Available
- Unavailable
- Stale
- Unsupported
- Not Synchronized

- **[Guardrail]** Missing health data must not be displayed as `0`.
- trend-based, observational wellness insights.
- non-diagnostic wording.
- informational disclaimer.
- **[Future]** Real Health Connect client.
- **[Future]** permission flow.
- **[Future]** background sync.
- **[Future]** PC synchronization.
- **[Deferred]** Direct watch BLE reverse engineering.

---

# 14. Appearance / Theme System

## 14.1 Design Language

**Minimalism + Glassmorphism + Neumorphism / Soft UI**

Working design name: **Soft Glass**.

## 14.2 Theme Modes

- Light (calibrated #334155 high-contrast muted text and icons)
- Dark (calibrated #94A3B8 readable muted icons)
- System
- OLED Battery Saver (AMOLED-tailored pure #000000 pitch black, zero drop-shadow calculations, luminous borders, high-contrast glowing accents)

## 14.3 Theme Source

- Phone Theme
- Account Theme
- Sync with PC Theme

Account/PC theme sources should remain visibly future/mock until real synchronization exists.

## 14.4 Background Types

- built-in preset.
- custom image.
- gradient.
- solid.

## 14.5 Background Atmospheres Discussed

- Aurora Cyan
- Midnight Slate
- Deep Ocean
- Ember Warmth
- Nebula Violet
- future curated mobile backgrounds.

## 14.6 Accent Colors

- Blue
- Cyan
- Violet
- Amber
- Emerald
- custom hex.
- quick swatches.

- **[Both]** Blue/cobalt/azure is the main product accent family.
- **[Recommended]** Cyan should be selective/secondary rather than dominate Settings.

## 14.7 Appearance Controls Requested/Discussed

- glass opacity.
- glass blur/intensity.
- tint.
- saturation.
- background brightness.
- background saturation.
- background blur.
- scrim/overlay.
- effects/depth level.
- neumorphic depth.
- reduced effects.
- reduced motion.
- live preview.
- reset/restore defaults.

## 14.8 Neumorphism Requirements

- raised surfaces.
- recessed wells.
- top-left subtle highlight.
- bottom-right soft shadow.
- pressed state.
- selected state.
- efficient fake dual-shadow in Compose.
- restrained outlines.
- avoid a border around every card.

## 14.9 Glassmorphism Requirements

- translucent surfaces.
- atmospheric canvas visible behind cards.
- specular highlights.
- tonal layering.
- restrained borders.
- no mandatory expensive live backdrop blur.
- real blur only after performance testing.

## 14.10 Dark Mode

- graphite/charcoal base.
- raised surfaces.
- recessed surfaces.
- remove harsh persistent gray outlines.
- selected controls may use accent boundaries.
- distinct top/bottom navigation treatment.
- readable without becoming flat black.

## 14.11 Light Mode

- pearl/gray-white background instead of harsh pure white.
- translucent milky cards.
- visible ambient background.
- subtle shadow/highlight.
- strong text contrast.

## 14.12 Effects Levels

- Reduced
- Normal
- Enhanced

May control:

- shadow strength.
- highlight strength.
- translucency.
- aura/background intensity.
- animation intensity.

---

# 15. Settings

Sections:

- General
- Appearance
- Assistant
- Voice
- Connection
- Alarms
- Health
- Privacy
- Advanced

## 15.1 General

- startup behavior.
- notifications.
- quiet hours.
- sound alerts.
- haptic feedback.
- language settings.

Startup ideas:

- Home Dashboard
- Resume Last Screen
- Voice Assistant

## 15.2 Appearance

All appearance controls above.

Requested UX changes:

- sticky/persistent Settings category strip.
- content scrolls separately.
- switching category starts at top unless per-section restoration is deliberately added.

## 15.3 Assistant Settings

- response detail level.
- proactive suggestions.
- assistant activity/debug visibility.
- **[Recommended]** Replace raw “show chain of thought” with safe tool/reasoning summaries.
- **[Guardrail]** Never expose private/raw chain-of-thought.

## 15.4 Voice Settings

- recognition language.
- mixed-language recognition.
- capability matrix.
- later input/output selection.
- later provider selection.

## 15.5 Connection Settings

- connection status.
- LAN/remote configuration later.
- diagnostics.
- discovery later.
- authentication/certificate state later.

## 15.6 Alarm Settings

- default tone.
- snooze.
- gradual volume.
- sync/mirror behavior.

## 15.7 Health Settings

- health sync.
- retention.
- source state.
- future Health Connect configuration.

## 15.8 Privacy

- local audit logging.
- ephemeral sessions.
- local cache controls.
- permissions link.
- clear cache.

## 15.9 Advanced

- developer mode.
- diagnostics overlay.
- DB maintenance later.
- debug info.
- design system preview during development.

---

# 16. Navigation and UX

- mobile-first navigation.
- no desktop sidebar on Android.
- preserve state across top-level destinations.
- clean back stack.
- consistent primary-destination navigation policy.

Explicit flow requirement:

`Home → Ask → Assistant → Home`

Must return immediately without requiring system-back gesture.

Top bars:

- contextual title.
- back button on subpages.
- connection state where appropriate.
- avatar/user access.
- remove Light/Dark quick switch from normal top bars.

Bottom-nav redesign:

`Home | Tasks | [Assistant] | Health | More`

Assistant is center, larger, icon-only, emphasized.

---

# 17. Notifications and Feedback

- connection banner.
- sync banner.
- task confirmation.
- alarm feedback.
- warning/error feedback.
- offline state.
- permission/capability state.

Assistant-event redesign:

- warnings should not be huge chat cards.
- errors should not dominate transcript.
- compact notification/activity presentation.
- expandable technical detail.
- verbose diagnostics remain secondary.

---

# 18. Networking and Remote Access

## 18.1 Home / LAN

- Android reaches PC Local AI Core over private LAN/Wi-Fi.
- web client uses local core.
- local discovery later.

## 18.2 Remote

- **[Both]** Tailscale is acceptable for single-user V1 remote access.
- Android remote mode reaches the same PC Core.
- remote voice can stream audio to PC.

## 18.3 Security

- networking does not replace app auth.
- authenticated sessions.
- future Cloudflare Tunnel/Access if multi-user/hosted needs grow.
- do not display fictional TLS/mTLS security claims before implementation.
- no fixed pseudo-hostnames/IPs as product architecture.
- endpoint/discovery config comes from settings/runtime.

## 18.4 Away Mode

Concept:

`Android mic → secure network → PC FastAPI/Core → STT/LLM/TTS → compressed audio → Android`

Potential codec: Opus.

If PC is off:

- V1 AI unavailable.
- local Android functions remain.
- **[Future]** optional Android→cloud fallback could be considered separately.

---

# 19. Audio Device Management

- selectable microphone.
- selectable speaker/output.
- Bluetooth headset support.
- connection status.
- warmup handling.
- reconnect.
- fallback device.
- device-change events.
- PC headset in Home Mode.
- Android mic in Away Mode.

---

# 20. Device Management

- PC node.
- Android node.
- microphone.
- audio output.
- health provider/source.
- connection state.
- latency.
- capability/availability.
- diagnostics.
- future device discovery.
- no hardcoded commercial device assumptions in core architecture.

---

# 21. Logs / Diagnostics / Developer Tools

- runtime logs.
- assistant/tool events.
- connection state.
- sync state.
- model runtime state.
- memory retrieval activity.
- device state.
- scheduler state.
- developer mode.
- diagnostics overlay.
- design-system preview.
- mock-state switchers during UI development.
- warning/error codes.
- expandable tool payloads in developer UI.
- build/version info.
- do not label prototype as production.

---

# 22. Data / Persistence

## 22.1 Core

- SQLite.
- migrations.
- FTS5.
- tasks.
- reminders.
- schedules.
- alarms.
- memories.
- settings where appropriate.
- health metadata/snapshots where appropriate.
- provider/runtime configuration.

## 22.2 Android Local Persistence

- **[Future]** Room or another deliberate local DB layer.
- **[Future]** DataStore for small preferences.
- **[Future]** offline cache.
- **[Future]** sync queue.
- **[Future]** conflict resolution.
- **[Recommended]** Do not add persistence libraries before actual persistence work begins.

---

# 23. Synchronization

Potential synchronized domains:

- tasks.
- reminders.
- schedule.
- alarms.
- health.
- settings.
- memory where appropriate.

States:

- synchronized.
- pending.
- conflict.
- stale.
- failed.

Conflict actions:

- Keep Local.
- Merge with Core.

- **[Recommended]** Define canonical ownership per data type before implementing sync.
- **[Recommended]** Core becomes canonical source for AI/data/scheduling/tools while Android owns native mobile capability execution.

---

# 24. Security and Privacy

- local-first architecture.
- backend-side API keys.
- no secrets in frontend/Android APK.
- no unrestricted LLM system authority.
- validated tool calls.
- application authentication.
- secure remote transport.
- local audit logging.
- careful health-data handling.
- cache controls.
- ephemeral sessions.
- no fabricated encryption/security claims.
- credentials/certificates excluded from Git.
- release signing keys excluded from source.
- permissions only when features require them.

---

# 25. Desktop Runtime / Windows Integration

## 25.1 Development Processes

- `llama-server`
- FastAPI / Uvicorn
- React / Vite
- Android Studio

Recommended PowerShell scripts:

- `setup-dev.ps1`
- `start-dev.ps1`
- `stop-dev.ps1`
- `start-core.ps1`
- `start-model.ps1`
- `check-health.ps1`

## 25.2 Production

- React production build.
- possibly FastAPI serving React static build for personal V1.
- Local AI Core starts on Windows login.
- startup checks for DB/scheduler/network/audio.
- lazy model load.
- idle unload.
- browser closing must not stop scheduler/core.
- **[Future]** tray app.
- **[Future]** stronger service/background-host model if needed.

---

# 26. Repository / Development Workflow

- root `AGENTS.md`.
- AI read-only by default.
- explicit approval before nontrivial code changes.
- feature plans under `docs/02_Planning/`.
- active execution tracking in `docs/01_Tracking/task.md`.
- walkthroughs under `docs/03_Walkthroughs/`.
- canonical architecture docs in `docs/04_Architecture/`.
- archive old/completed work.
- preserve user-owned starter kit.
- Conventional Commit suggestions.
- user owns commits/pushes by default.
- status taxonomy:
  - Planned
  - In Progress
  - Implemented
  - Verified
  - Deferred
  - Unverified
- preserve unrelated working-tree changes.
- do not silently decide architecture/security/data/cost tradeoffs.
- do not change LFS/model-storage policy without approval.
- unit tests.
- Robolectric tests.
- physical-device visual testing.
- clean-checkout reproducibility checks.
- Gradle wrapper committed.
- `git diff --check`.
- source tracking checks.
- develop-before-master workflow.

---

# 27. Git / Model Storage Architecture

- GitHub stores normal source/history.
- GitHub stores LFS pointer files.
- private Hugging Face Dataset stores the actual large LFS objects.
- `.lfsconfig` points Git LFS to that HF dataset.
- model extensions intended for LFS include:
  - `.gguf`
  - `.ggml`
  - `.safetensors`
  - `.onnx`
  - `.pt`
  - `.pth`
  - `.ckpt`
- private HF authentication required to fetch private objects.
- **[Guardrail]** Hugging Face is not a full Git mirror unless architecture is deliberately changed.

---

# 28. Accessibility

- minimum 48dp touch targets.
- large text support.
- TalkBack semantics.
- content descriptions.
- correct roles.
- visible selected states not dependent on shadow alone.
- contrast.
- compact/normal/large phone widths.
- landscape scrollability.
- multilingual wrapping.
- no clipped critical labels.
- accessible Voice Mode controls.
- explicit health missing-data states.
- **[Recommended]** reduced-motion support.
- **[Recommended]** reduced-effects mode.

---

# 29. Performance

- lightweight Android animations.
- simulated glass instead of mandatory expensive backdrop blur.
- benchmark true blur before adoption.
- avoid excessive mobile GPU effects.
- lazy-load heavy PC models.
- unload idle models.
- benchmark model profiles.
- no phone-hosted main LLM in V1.
- efficient remote audio.
- compressed audio.
- keep full desktop telemetry off Android unless needed.

---

# 30. Deferred / Future Major Features

- wake word.
- continuous background microphone.
- direct smartwatch BLE reverse engineering.
- complex dedicated vector database.
- large autonomous agent framework.
- unrestricted desktop automation.
- computer vision / camera awareness.
- Live2D avatar.
- VRM / 3D avatar.
- richer avatar packs.
- home automation.
- smart-home bridges.
- multi-user hosted cloud service.
- Cloudflare remote gateway.
- phone-hosted main LLM.
- Android cloud AI fallback.
- advanced device discovery.
- full sync/conflict engine.
- Android Room/DataStore persistence.
- real Health Connect ingestion.
- external calendar integrations.
- richer native notifications.
- desktop tray app.
- furigana/ruby Japanese display.
- broader provider/plugin ecosystem.
- richer web/search providers.

---

# 31. Android V1.1B UX / Visual Refinement Wishlist

## 31.1 Web UI as Read-Only Visual Source of Truth

Android should study the React frontend design system but **not copy desktop layout**.

Match:

- color language.
- glass behavior.
- neumorphic depth.
- typography character.
- spacing rhythm.
- selected/pressed states.
- border restraint.
- surface hierarchy.
- atmospheric backgrounds.

Preserve mobile-native:

- navigation.
- density.
- ergonomics.
- vertical flow.

## 31.2 Neumorphic Rendering Engine

- fake dual-shadow.
- top-left highlight.
- bottom-right shadow.
- raised card.
- recessed well.
- pressed state.
- selected state.
- dark/light specific depth.
- possible `drawBehind` / `drawWithCache` implementation.
- do not rely only on standard elevation.
- no mandatory expensive blur.

## 31.3 Appearance Settings Parity

Audit web vs Android for:

- Light/Dark/System.
- theme source.
- background type.
- built-in backgrounds.
- custom image.
- gradient.
- solid.
- accent preset.
- custom accent.
- glass opacity.
- blur/intensity.
- tint.
- saturation.
- background brightness.
- background saturation.
- background blur.
- scrim/overlay.
- effects/depth.
- neumorphic depth.
- reduced effects.
- reduced motion.
- live preview.
- reset behavior.

## 31.4 Bottom Navigation

- Home.
- Tasks.
- large center Assistant action.
- Health.
- More.

## 31.5 Settings UX

- sticky category strip/menu.
- content scrolls under/after persistent category area.
- new section starts at top.
- complete Appearance options.
- no redundant theme toggle in top bar.

## 31.6 Assistant UX

- new-chat-first.
- history behind a dedicated control.
- resume old conversation on selection.
- compact warning/error/tool/system activity.
- expandable technical details.
- cleaner mobile density.
- less telemetry clutter.

## 31.7 Global Density

- reduce giant empty spaces.
- reduce oversized hero cards where unnecessary.
- reduce excessive card padding.
- keep 48dp touch targets without making every visible object huge.
- reduce unnecessary borders.
- improve small-screen hierarchy.

---

# 32. Recommended Practical V1 Freeze

## Core

- Windows Local AI Core.
- FastAPI.
- llama.cpp.
- GGUF local model.
- SQLite/FTS5.
- memory.
- tasks/reminders/schedule/alarms.
- trusted tool execution.
- persistent scheduler.
- provider interfaces.
- local authentication.

## Desktop

- control center.
- assistant.
- model/runtime configuration.
- memory.
- tasks/schedule.
- characters.
- devices.
- logs.
- settings.
- Soft Glass theming.

## Android

- Home.
- Assistant.
- Voice Mode.
- Tasks.
- Schedule.
- Alarms.
- Health.
- Memory.
- Characters.
- Models.
- Devices.
- Connection.
- Settings.
- Permissions UX.
- offline cached capabilities.
- native alarms/notifications.
- remote PC connection.
- Health Connect.

## Voice

- VAD.
- multilingual STT.
- local TTS.
- interruption.
- input/output routing.
- Home/Away modes.

## Networking

- LAN.
- Tailscale.
- app authentication.
- typed REST/WebSocket contracts.

## Production

- Windows startup.
- scheduler independent from browser.
- React production build.
- diagnostics.
- reproducible builds.

---

# 33. Non-Goals / Things to Avoid

- Do not make Android the main LLM server in V1.
- Do not embed Gemini/API keys into Android.
- Do not give the LLM unrestricted system access.
- Do not display missing health data as `0`.
- Do not hardcode current hardware as permanent product architecture.
- Do not hardcode pseudo-hostnames as production endpoints.
- Do not claim production/security/license status that has not been established.
- Do not add Hilt/Koin just for fashion when manual DI is sufficient.
- Do not add networking/persistence dependencies before their implementation phase.
- Do not copy desktop layout directly to Android.
- Do not use borders as the primary depth mechanism on every card.
- Do not make true backdrop blur a V1 requirement.
- Do not expose private/raw chain-of-thought.
- Do not let browser closure stop scheduler/core in final architecture.
- Do not silently send private data to cloud providers.
- Do not change Git LFS / Hugging Face storage architecture without approval.

---

# 34. Suggested High-Level Implementation Order

1. Finish Android V1.1B UX/visual refinement.
2. Freeze React + Android UI architecture.
3. Clean/normalize frontend service abstractions.
4. Build FastAPI Local AI Core foundation.
5. Add SQLite schema, migrations, and FTS5.
6. Define REST/OpenAPI/WebSocket contracts.
7. Integrate llama.cpp runtime.
8. Connect React to FastAPI.
9. Implement tasks/scheduler/reminders.
10. Implement memory retrieval.
11. Implement trusted tools.
12. Implement voice pipeline.
13. Connect Android to FastAPI.
14. Implement Android persistence/offline cache.
15. Implement native Android alarms/notifications.
16. Implement Health Connect.
17. Add remote access + authentication.
18. Productionize Windows startup/runtime.
19. Benchmark and tune Eco/Balanced/Maximum.
20. Revisit deferred features after V1 is stable.

---

# 35. One-Sentence Project Definition

> **AI Companion** is a local-first personal AI system centered on a persistent Windows **Local AI Core**, with a React desktop control center and native Android companion, combining local LLM inference, multilingual text/voice interaction, long-term memory, tasks and scheduling, resilient alarms, health integration, configurable characters, remote access, and a customizable Soft Glass interface while keeping models, tools, memory, and sensitive operations behind trusted backend boundaries.
