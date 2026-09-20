# Phase 8 Implementation Plan — PC Frontend Architecture, Runtime Config, Multimodal & Polish

> **Status:** 8A and 8P COMPLETE / VERIFIED. Repository Documentation Reconciliation (Passes R0–R8) is CURRENT GATE (blocking 8B). 8B is NEXT upon clearing the gate. 8C is PLANNED AFTER 8B.  
> **Authority Precedence:** Normative architecture is owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md). Canonical product sequencing is owned by [`docs/02_Planning/ROADMAP.md`](../ROADMAP.md). Runtime config architecture is owned by [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../../04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md).  
> **This is the single authoritative feature implementation plan for Phase 8.**

---

## Branch Strategy

develop (baseline: 88 backend pytest, 132 frontend vitest, 0 tsc, migration head 005_scope_message_constraints)
  +-- feature/phase8-ui-foundation           (8A: COMPLETE / VERIFIED — merged to develop)
  +-- feature/phase8-runtime-config          (8P: COMPLETE / VERIFIED — merged to develop)
  +-- [GATE: Documentation Reconciliation]   (R0–R8: CURRENT GATE — blocks Phase 8B)
  +-- feature/multimodal-image-attachments   (8B: NEXT — full stack image upload & vision inference)
        based on develop; merge to develop
  +-- feature/phase8-ui-integration-polish   (8C: PLANNED AFTER 8B — polish, a11y, cleanup)
        based on merged 8B

8P established canonical COMPANION_DATA_ROOT/attachments/. 8B activates image uploads to that directory upon completion of documentation reconciliation.

---

## Scope Guard

- PC-first. No Android.
- No STT/TTS. No video. No PDF. No arbitrary file types.
- No CUDA (boundary documented in 8P only).
- No new state management library.
- No import UI, auto-downloads, quantization, benchmarking (local model import capability is a locked V1 requirement under Decision D6, but execution service and import UI are out of scope for Phase 8B/8C; managed online downloads remain post-V1).
- No MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md -- deferred until dedicated Import Manager planning.
- No .gitattributes / .lfsconfig / LFS remote changes without explicit user authorization.

---

## Resolved Decisions

| Decision | Resolution |
|----------|-----------|
| OD1: Default Windows data-root | %LOCALAPPDATA%\AI Companion\Data |
| OD2: Bootstrap locator | %LOCALAPPDATA%\AI Companion\bootstrap.json |
| OD3: Dev vs installed models | Dev/bootstrap models stay under Git/LFS. Installed/user-imported models use COMPANION_DATA_ROOT/library/models/llm/ |

---

## Repository Baseline Evidence

| Finding | Location | Action |
|---------|----------|--------|
| PROJECT_NAME = "Local AI Runtime" already correct | config.py L27 | Add comment only |
| DATABASE_URL hardcoded relative path | config.py L49 | Replace with derived absolute DATABASE_PATH |
| MODELS_DIR = BASE_DIR.parent / "models" | config.py L57 | Deprecate -> MODEL_LIBRARY_DIR |
| LLAMA_MODELS_DIR uses "vision/" subdir | config.py L58 | Deprecate; vision/ was capability-labelled not family-organized |
| _get_profile_params() inline constants | llama_cpp.py L151-164 | Move to env-overridable PROFILE_*_* settings |
| _engine_version = "b10936" hardcoded | llama_cpp.py L56 | Move to settings.LLAMA_ENGINE_VERSION |
| LLAMA_SERVER_URL = "http://127.0.0.1:8085/v1" -- VERIFIED port 8085 | config.py/.env | Router is 8085, NOT 8080. Correct in all docs. |
| "Local AI Core" in frontend & backend | Decomposed frontend, mock files & test assertions | Full rename in 8P.1; include shellHomeTruthfulness.test.tsx and test_llm.py |
| ModelRegistryEntry flat struct mixes identity/state/hints | schemas/model_registry.py | Split into ModelManifest + ModelLibraryState + ModelRuntimeHints with temporary @computed_field bridge |
| variant defaults to "instruct" for unregistered scan | model_registry.py L132 | Must be ModelVariant.unknown |
| capabilities=[ModelCapability.chat] auto-assigned to discovered GGUFs | model_registry.py L132 | REMOVE. Unknown GGUFs get capabilities=[] |
| Migration head: 005_scope_message_constraints | backend/migrations/versions/ | Next: 006_add_attachments |
| registry.template.json schema v1, Qwen-only | models/registry.template.json | Update to schema v3 |
| contracts/openapi/openapi.json missing model endpoints | contracts/openapi/openapi.json | Generate and add /models and /models/registry endpoints in 8P.6 |

---

## Canonical Terminology

| Context | Canonical | Retired |
|---------|-----------|---------|
| Product | AI Companion | -- |
| Backend service | Local AI Runtime | Local AI Core (retire everywhere) |
| Runtime engine | llama.cpp (configurable) | -- |
| Acceleration | Vulkan (current) | -- |
| GGUF model | GGUF model (runtime-agnostic) | Vulkan model / CUDA model |
| Config root | COMPANION_DATA_ROOT | DATA_DIR (deprecated) |
| Router port | 8085 | 8080 (was incorrect in older docs) |

Non-conflation rules (enforce in code and UI):
- GGUF != Vulkan/CUDA model; acceleration is an engine property
- vision capability != filename contains "VL"; capability is declared not inferred
- model_max_context (manifest) != applied_context_size (runtime session state)
- ModelManifest != ModelLibraryState != ModelRuntimeHints != session state

---

## Persistent Asset Root -- Canonical Layout (OD1/OD3 resolved)

Default: %LOCALAPPDATA%\AI Companion\Data

### Two Distinct Model Roots (OD3)

  FACTORY_MODEL_ROOT = <repo-root>/models/
    - Repository-versioned development/bootstrap models (LFS-tracked)
    - Used at runtime ONLY for factory template entry resolution
    - Do NOT copy/move LFS models without separate user authorization

  MODEL_LIBRARY_DIR  = COMPANION_DATA_ROOT/library/models/llm/
    - Persistent installed/user-imported models
    - All user-initiated installs and imports go here

Path resolution per registry source:
  Factory template entries (models/registry.template.json): paths relative to FACTORY_MODEL_ROOT
  Installed registry entries (COMPANION_DATA_ROOT/library/registry/models.json): paths relative to MODEL_LIBRARY_DIR

Current development mode: factory template resolves against FACTORY_MODEL_ROOT.
Verified Qwen3-VL models remain in the repository under Git/LFS policy and are NOT moved.
Installed registry starts empty; grows only when the user explicitly imports or installs a model.

  COMPANION_DATA_ROOT/
  +-- database/companion.db
  +-- attachments/{owner-id}/{conversation-id}/{attachment-uuid}.{ext}
  +-- library/
  |   +-- models/
  |   |   +-- llm/          <- persistent installed GGUFs; family-organized; NOT vulkan/ or cuda/
  |   |   +-- embeddings/
  |   |   +-- rerankers/
  |   |   +-- stt/ tts/ vad/ wake-word/
  |   +-- voices/
  |   +-- registry/models.json   <- installed runtime registry (may be empty at first run)
  +-- characters/{character-id}/
  +-- memory/indexes/ derived/
  +-- imports/inbox/ staging/ rejected/
  +-- backups/ config/ cache/ logs/

Invariants:
- llm/ organized by model family (Qwen3-VL/, Llama-3/, etc.) -- NEVER by vulkan/ or cuda/
- vision/reasoning/code are CAPABILITIES, not filesystem categories
- Runtime binaries never inside this root
- library/registry/models.json: all writes go here (never to factory template)
- models/registry.template.json: factory bootstrap, read-only at runtime
- Registry paths are relative to their respective root (FACTORY_MODEL_ROOT or MODEL_LIBRARY_DIR)
- Per-library overrides (models on separate drive) are a future/deferred feature

Data migration (conditional -- NOT assumed absent):
  COMPANION_DATA_ROOT/database/companion.db exists? -> use it
  Exactly one valid legacy candidate found?          -> safe copy -> verify -> backup original
  Multiple differing candidates found?               -> STOP; report ambiguity; do not choose silently
  Neither exists?                                    -> create fresh at canonical path

Known legacy candidate locations (checked in order):
  backend/data/companion.db
  <repo-root>/data/companion.db

Source Immutability Invariant:
  1. companion.db: SHA-256 unchanged, size unchanged, mtime unchanged.
  2. companion.db-wal: SHA-256 unchanged, size unchanged, no checkpoint/truncate/write.
  3. companion.db-shm: SHA-256 unchanged, size unchanged, filesystem mtime MAY change due to SQLite read-lock coordination in WAL mode (Case C semantics; not considered data mutation).
  4. No source rows modified; no Alembic migrations on legacy source; no forced WAL checkpoints.
  5. Canonical destination integrity and logical row preservation verified.
  Safety: never overwrite newer DB; keep backup until verified; restart-safe; no LFS/git changes.

---

## Model Schema Design

### Three-Layer Split

  ModelManifest      -- what the artifact IS (stable identity; sourced from registry or GGUF metadata)
  ModelLibraryState  -- what the library knows (computed by validation pipeline)
  ModelRuntimeHints  -- non-authoritative hardware/profile recommendations

Runtime/session state (active model, applied context, GPU layers, threads, profile, mmproj offload,
sleep state) lives in ModelStatusResponse -- NEVER in these schemas.

---

### ModelManifest -- stable identity and artifact metadata

Fields:
  id: str                                    # stable slug e.g. "qwen3-vl-4b-instruct"
  display_name: str
  asset_type: ModelAssetType                 # gguf | mmproj | lora | embedding | tokenizer
  family: str = ""                           # "Qwen3-VL", "Llama-3", "Phi-4"
  architecture: str = ""                     # GGUF general.architecture e.g. "qwen2_vl"
  variant: ModelVariant = unknown            # instruct | thinking | base | code | unknown
  parameters: str = ""                       # "4B", "7B"
  quantization: str = ""                     # "Q4_K_M", "Q8_0"
  reasoning_mode: ReasoningMode = unknown

  # Capabilities -- declared explicitly; NEVER inferred from filename
  capabilities: List[ModelCapability] = []
  input_modalities: List[InputModality] = []
  # vision capability requires InputModality.image
  # ModelCapability.reasoning must be explicitly declared
  # IMPORTANT: For discovered/unregistered models input_modalities stays [] until declared or detected.
  # Do NOT default to [text] for unknown GGUFs.

  # Context -- model architectural maximum; NOT runtime session context_size
  # IMPORTANT: For discovered/unregistered models this stays None until detected or declared.
  # Do NOT default to 4096 for unknown GGUFs.
  model_max_context: Optional[int] = None

  # Runtime compatibility -- explicitly declared; empty for unregistered/unknown models.
  # Factory/registered entries declare this (e.g. ["llama_cpp"]). Do NOT default for unknowns.
  runtime_compatibility: List[str] = Field(default_factory=list)

  # Artifact paths (relative to the registry source root: FACTORY_MODEL_ROOT or MODEL_LIBRARY_DIR)
  primary_file: str
  companion_files: List[CompanionFile] = []

  # Chat template
  chat_template: Optional[str]
  chat_template_source: Optional[str]   # "gguf_metadata" | "registry_declared" | None

  # Source / integrity
  license: str = ""; source: str = ""; sha256_primary: Optional[str]

### ModelLibraryState -- computed by validation pipeline

Fields (updated by _validate_entry(); never stored in ModelManifest):
  discovery_state: ModelDiscoveryState   # discovered | registered | verified | incompatible
  validation_status: ValidationStatus    # verified | missing_primary | missing_companion | incompatible
  primary_file_exists: bool = False
  size_gb: Optional[float]              # measured from primary file
  companion_artifact_statuses: List[CompanionArtifactStatus] = []
  available_capabilities: List[ModelCapability] = []
  # available_capabilities may be SUBSET of manifest.capabilities
  # Missing mmproj -> vision removed; text chat still available
  capability_provenance: List[CapabilityEntry] = []

### ModelRuntimeHints -- non-authoritative recommendations

Fields:
  recommended_profiles: List[str] = ["balanced"]
  estimated_vram_gb: float = 0.0
  estimated_ram_gb: float = 0.0
  generation_defaults: Optional[GenerationDefaults]
  # GenerationDefaults: temperature, top_p, top_k, min_p, repeat_penalty -- all optional

### ModelRegistryEntry -- full API response

  manifest: ModelManifest
  library_state: ModelLibraryState
  hints: ModelRuntimeHints
  runtime_model_id: str = ""

  # IMPORTANT: Python @property does NOT serialize in Pydantic v2.
  # Use model_serializer or computed_field for flat backward-compat API fields.
  # Update: schemas/model_registry.py + registryApi.ts + openapi.json + regression tests.
  # context_limit is retired -> model_max_context

### New Enumerations

  ModelAssetType:   gguf | mmproj | lora | embedding | tokenizer
  ModelVariant:     instruct | thinking | base | code | unknown
  InputModality:    text | image | audio | video
  ModelDiscoveryState:
    discovered   -- filesystem scan found GGUF; not in registry
    registered   -- in registry.json; files not validated
    verified     -- registry entry + all files confirmed on disk
    incompatible -- file present but fails runtime compatibility
  ReasoningMode: always_on | toggleable | unsupported | unknown
  CapabilityProvenance:
    declared  -- written in registry.json
    detected  -- from GGUF metadata (best-effort; non-authoritative for gating)
    verified  -- confirmed by live runtime test (deferred)
    unknown

### Discovery and Capability Rules

Unknown GGUF discovery rule (critical):
  - capabilities = []  -- EMPTY. Do NOT auto-assign chat or any capability.
  - input_modalities = []  -- EMPTY. Do NOT default to [text].
  - model_max_context = None  -- UNKNOWN. Do NOT default to 4096.
  - runtime_compatibility = []  -- EMPTY. Do NOT default to [llama_cpp].
  - variant = ModelVariant.unknown
  - discovery_state = discovered, validation_status = unregistered
  - Model must be explicitly registered with declared capabilities before use.
  GGUF metadata extraction (best-effort, non-blocking) may populate some fields after scan,
  but only with reliably detected values -- never fabricated defaults.

Partial companion availability:
  - Missing mmproj -> vision removed from available_capabilities
  - Text capability remains usable; model continues to be loadable for text inference
  - Model is NOT globally prohibited from loading; it is NOT marked incompatible
  - Frontend gates on available_capabilities, not manifest.capabilities

Feature gating:
  - ModelCapability.reasoning in available_capabilities is authoritative
  - Never gate on variant == "thinking" alone

### Registry Locations, Merging, and Path Resolution

#### Two sources, merged effective registry

  Factory registry:   models/registry.template.json (repo, versioned) -- read-only at runtime
    Artifact paths resolve relative to FACTORY_MODEL_ROOT (<repo-root>/models/)
    source tag on each entry: "factory"

  Installed registry: COMPANION_DATA_ROOT/library/registry/models.json -- all writes go here
    Artifact paths resolve relative to MODEL_LIBRARY_DIR (COMPANION_DATA_ROOT/library/models/llm/)
    source tag on each entry: "installed"

#### Effective registry composition

  effective_registry = merge(factory_entries, installed_entries)

ID collision rule: installed entry with the same stable id shadows the factory entry.
An empty installed registry MUST NOT hide factory models.
Factory models remain visible even when the installed registry is absent or empty.

Source preservation: every ModelRegistryEntry carries a registry_source: Literal["factory", "installed"] field.
Path resolution MUST use the correct root for the source -- never mix roots.

  _build_effective_registry():
      factory = _load_factory_registry()   # always loaded; never skipped
      installed = _load_installed_registry() if INSTALLED_REGISTRY_PATH.exists() else []
      merged = {e.manifest.id: e for e in factory}   # factory first
      for e in installed:
          merged[e.manifest.id] = e                  # installed shadows factory on same id
      return list(merged.values())

### registry.template.json -- Schema v3

  _schema_version: "3"
  _note: "Qwen3-VL entries are verified factory defaults, not a whitelist. Any compatible GGUF
          may be registered. variant and capabilities must be declared explicitly -- never
          inferred from filename. Paths are relative to FACTORY_MODEL_ROOT (repo models/).
          llm/ in COMPANION_DATA_ROOT contains persistent installed models organized by family,
          not by acceleration backend."
  models: [ ...entries with asset_type, architecture, input_modalities, model_max_context,
             reasoning_mode, runtime_compatibility added to all existing entries... ]

---

## Phase 8A -- Frontend Architecture & UX Harmonization

Branch: feature/phase8-ui-foundation
Test gate: >= 88 pytest (unchanged), >= 132 vitest (last verified Phase 8A baseline), 0 tsc, clean build.
Constraint: Zero backend schema changes. Zero migrations. Zero new API endpoints.
Note: Do NOT rename "Local AI Core" strings in 8A -- that happens in 8P to avoid merge conflicts.

### 8A.1 -- Mock Data Removal

[MODIFY] HomeView.tsx
  - Remove: import { getLanguageAwareGreeting } from '../../mock/multilingualData' (L33)
  - Replace: const h = new Date().getHours(); const greeting = h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'

[MODIFY] AssistantView.tsx
  - Remove stale import { mockConversations } (L49) -- drawerConversations already uses live API

[MODIFY] HealthView.tsx
  - Replace mock imports with BackendContext.isOnline and BackendContext.modelStatus
  - Add offline/degraded banner

[MODIFY] MemoryView.tsx
  - Wire to memoryApi live data; add loading/empty states

Verification:
  grep -r "from '.*mock/" frontend/web/src --include="*.tsx" --include="*.ts" -l
  # Expected: only test files

### 8A.2 -- AssistantView Decomposition

Create frontend/web/src/components/workspace/assistant/:
  AssistantComposer.tsx     -- input, send, stop, mic stub; Paperclip DISABLED (title="Image attachments -- Phase 8B")
  AssistantMessageList.tsx  -- scrollable list, auto-scroll
  AssistantStatusBar.tsx    -- provenance-labeled telemetry: Measured/Configured/Estimated/Unavailable;
                               amber "Profile change pending restart" when applied_profile != requested_profile; no invention
  AssistantErrorDisplay.tsx -- classifyStreamError logic extracted

[MODIFY] AssistantView.tsx -- orchestrator only; composes four sub-components.

### 8A.3 -- Models Progressive Disclosure

[MODIFY] ModelsView.tsx
  - Variant badges from BackendContext.registry
  - mmproj warning badge (vision degraded, not full incompatibility)
  - Applied-vs-requested profile labels (explicit and distinct)

### 8A.3b -- Production Truthfulness Sweep

8A.3b.1 -- Shell + Home
- App.tsx
- Header.tsx
- AssistantPanel.tsx
- GlobalComposer.tsx
- HomeView.tsx
- AssistantView.tsx (only where necessary to remove shell/offline fabricated defaults while preserving streaming behavior)

8A.3b.2 -- Tasks + Schedule — Backend Task Truth + Task-Derived Schedule
- Web Tasks uses existing backend `/api/v1/tasks` (`taskApi.ts` adapter with `apiFetch`).
- Tasks backend remains authoritative: server-authoritative mutations (create, update, soft-delete, reopen).
- Schedule is a chronological projection/aggregation view of backend tasks with `due_date != null`.
- Schedule is NOT a separate datastore and does not own tasks or events.
- Tasks without `due_date` remain reachable in Tasks view tabs but are absent from Schedule.
- Task reminders remain task metadata (`reminder_minutes_before`), not separate duplicate Schedule events.
- No fake alarm, calendar, reminder, or Android-mirroring backends.
- No recurrence implementation, no Android implementation, no backend/schema changes.
- Browser-local date/time conversion rules: parse ISO-8601 to local JS Date, format to local time; send local date+time as ISO-8601 UTC.
- Real dynamic current-date logic (remove hardcoded `2026-09-09`).
- Truthful loading, error with Retry, and empty states.
- Unsupported operational controls (New Alarm, Android audio nodes, calendar sync) removed or rendered as non-interactive Planned affordances.

8A.3b.3 -- Characters + Devices + Logs + Settings Truthfulness Sweep
Status: COMPLETED & MERGED (feature/phase8-ui-foundation squashed into develop)

Core Approach: Approach B — Hybrid Truthfulness
- Implemented + authoritative source -> show real state
- Architecture exists but implementation does not -> Planned / Not Implemented
- UI concept only -> Preview
- No authoritative source -> Unavailable
- Never simulate operational success.
- Zero backend changes, zero Android changes, zero migrations, zero new APIs.

CharactersView (Character Studio):
- Retain Character Studio as an interactive UI/architecture preview.
- Remove `mockCharacters` from production authority.
- Remove fake active-character state, fake local persistence ("Saved to local database"), and fake claims that selecting a preview character steers llama.cpp inference.
- Clearly label persistence and activation as Planned.
- Future Character Architecture:
  - Decomposed into Identity (id, display name, description, persona/system prompt), Personality (archetype presets + continuous trait values 0–100), Voice (preferred voice configuration / voice ID), Presence (presentation configuration).
  - Archetypes (tsundere, dandere, kuudere, yandere, warm, playful, formal, custom) are PRESETS only, not the complete behavioral model.
  - Continuous trait vector (warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity 0–100). Exact final schema deferred.
  - Safety invariant: personality presets must never override core AI Companion safety, factual constraints, or airgap boundaries.
- Profile / Character Separation (Netflix model):
  - Single local installation, multiple local profiles (not separate cloud accounts).
  - Profile owns conversations, memories, tasks, preferences, and future `preferred_character_id`.
  - Character does NOT own user memories, tasks, or conversations.
  - Neutral built-in Assistant fallback (Approach B) when no character is selected. Lisa or other optional character packs are not required for boot. Custom/named characters may be installed later.
- Character Packs / Public Repo Boundary:
  - Future data-root layout: `<COMPANION_DATA_ROOT>/characters/<character-id>/` (character.json, avatar.png, prompts/system.md, assets/).
  - Not implemented in 8A.3b.3 (deferred to later asset foundation work).
  - Zero copyrighted third-party artwork, game assets, or cloned voices bundled in public repo.
- Character Presence Layer (Far Future only):
  - Decoupled from identity/personality/voice: Character = WHO/HOW, Voice = HOW IT SOUNDS, Presence = HOW IT APPEARS, Profile = USER DATA.
  - Changing presentation renderer must never alter memory, tasks, conversations, profile identity, or personality state.
  - Potential renderers: static image, animated image / GIF, animated 2D / Live2D-style implementation, 3D model.
  - Potential desktop companion behaviors: transparent desktop overlay, draggable position, persistent screen position, always-on-top option, click/hover interactions, idle animation loops, semantic emotion states, lip sync, speaking animations, proactive notification reactions.
  - Zero Presence runtime implemented in Phase 8.

DevicesView:
- Truthfully display real host workstation state from authoritative backend endpoint `GET /api/v1/system/status`:
  status, platform, Python version, hostname, CPU count, application version, database_connected, timestamp.
- Mark all unsupported subsystems as Planned or Unavailable:
  Android device registry, Android sync bridge, alarms synchronization, health device synchronization, audio-device manager, microphone routing, speaker routing, Bluetooth state, smartwatch/wearable source, Health Connect source, remote gateway, Tailscale connectivity, remote latency, LAN/Tailscale runtime ingress.
- Remove simulated production claims and fabricated operational metrics:
  - fake connected-phone identity/status
  - fabricated latency
  - fake gateway address
  - simulated sync timestamps
  - fake encryption/connectivity claims
  - fake endpoint counts
  - simulated network health claims
  - mock provider switching
  - fake packet loss tests
- Remote runtime access over LAN/Tailscale is FUTURE; no implementation in 8A.

LogsView:
- Current backend has no telemetry or log streaming API.
- Remove `initialMockLogs` as production authority.
- Remove `streamingEventTemplates` from production behavior.
- Remove random generated log stream and interval timers synthesizing logs.
- Remove fake "Live Stream" status, fake average latency, fake error/buffer counts.
- Display truthful messaging: "Runtime log streaming is not implemented yet."
- Retain visual log viewer terminal shell as Preview / Planned. No backend log API in 8A.

SettingsView:
- Important rule: Browser localStorage persistence alone != implemented runtime setting. If toggling a setting has no actual product/runtime effect, it must not be presented as an operational system setting.
- REAL NOW: Appearance preferences that genuinely alter `ThemeContext` and live DOM presentation:
  - Light / Dark / System preference
  - accent preset / custom accent
  - effect intensity
  - interface density
  - animation preference
  - background configuration
  - glass configuration
- PREVIEW / PLANNED: Runtime/system controls with no corresponding implementation:
  - General startup behavior not actually wired
  - Assistant personality behavior not actually wired
  - Character assignment persistence
  - Voice / TTS / STT
  - wake word / VAD
  - Health settings
  - hardware/audio settings
  - remote network/Tailscale
  - privacy controls without authoritative runtime implementation
  - unsupported Advanced settings
- AI runtime configuration belongs primarily to Phase 8P; do not duplicate fake runtime state in Settings.
- Remove false persistence claim: "Persisted Locally (SQLite & Keyring)". Use truthful wording based on actual persistence source (Browser Local Storage for appearance preferences vs. Configuration schema planned for Phase 8P for runtime settings).
- Application States page remains explicitly labeled as a UI/UX showcase or Preview and must not be interpreted as current runtime state.

Explicit Non-Goals / Out of Scope:
- Do NOT implement profiles, character registry backend, persistent character packs, Lisa or other named character packs, voice engines, voice cloning, 3D/GIF avatar runtime, Live2D, desktop overlay, remote Tailscale runtime access, device registry, backend telemetry/log streaming, new Settings backend, Android changes, backend changes, or migrations.

### 8A.4 -- Deprecation Annotations

Add /** @deprecated -- mock data for test fixtures only */ to all mock/*.ts headers.
Do not delete files yet.

### 8A Commit Message

feat(8a): frontend architecture -- mock removal, decomposition, provenance labels
- HomeView: remove mock/multilingualData; time-derived greeting
- AssistantView: remove stale mockConversations import
- AssistantView: extract Composer/MessageList/StatusBar/ErrorDisplay sub-components
- HealthView, MemoryView: wired to live BackendContext/memoryApi
- ModelsView: variant badges, mmproj warning, applied-vs-requested profile labels
- mock/*.ts: @deprecated annotations; retained as test fixtures
Tests: >= 88 pytest, >= 132 vitest, 0 tsc, clean build


---

## Phase 8P -- Runtime Configuration & Persistent Asset Foundation

Branch: feature/phase8-runtime-config (based on merged 8A)
Test gate: >= 88 pytest, >= 132 vitest (string assertions updated), 0 tsc, clean build.
Constraint: No DB migrations. Zero data loss. No new frontend pages.
Critical prereq for 8B: settings.ATTACHMENT_DIR (established in 8P.3) must exist before 8B writes files.

### Verification Gate Rules (Locked)
- Focused tests for fast RED/GREEN iteration during development.
- When backend is affected: full backend test suite is mandatory before batch approval (floor: >= 88 pytest passed).
- When frontend is affected: full frontend test suite (floor: >= 132 vitest passed), `npx tsc --noEmit` (0 errors), and `npm run build` (clean production build) are mandatory before batch approval.
- Counts are floors: backend >= 88, frontend >= 132.

---

### 8P.1 -- Terminology & Test Alignment

#### 8P.1a -- Backend Terminology
- Grep and replace remaining occurrences of "Local AI Core" with canonical "Local AI Runtime":
  - `backend/app/__init__.py` (docstring)
  - `backend/app/services/retention.py` (CLI parser description)
  - `backend/app/services/llm/mock.py` (operational message responses)
  - `backend/app/api/v1/endpoints/auth.py` (token verification confirmation message)
  - `backend/.env.example` (header comment)
- `backend/app/core/config.py`: Add canonical naming reconciliation comment explaining "Local AI Runtime" supersedes legacy "Local AI Core".
- `backend/tests/test_llm.py`: Update string assertion at line 51 from `assert "Local AI Core is operational"` to `assert "Local AI Runtime is operational"`.

#### 8P.1b -- Frontend Terminology
Rename "Local AI Core" -> "Local AI Runtime" across all current decomposed component locations:
- `frontend/web/src/components/workspace/assistant/AssistantErrorDisplay.tsx` (L45)
- `frontend/web/src/components/layout/Header.tsx` (L221 status label, L304 comment)
- `frontend/web/src/components/workspace/HomeView.tsx` (L86, L99, L103 status labels and messages)
- `frontend/web/src/components/layout/AssistantPanel.tsx` (L123 description)
- `frontend/web/src/components/workspace/ModelsView.tsx` (L314 label)
- `frontend/web/src/components/workspace/models/ModelProvidersCard.tsx` (L34 description)
- `frontend/web/src/components/workspace/states/ApplicationStatesShowcase.tsx` (L330, L346, L358 preview labels)
- `frontend/web/src/components/workspace/health/HealthPipelineCard.tsx` (L137 comment)
- `frontend/web/src/mock/healthData.ts` (L92, L337 mock strings)

#### 8P.1c -- Frontend Test Assertions (Mandatory)
Update error/status string assertions across both affected test suites:
- `frontend/web/src/test/assistantViewReliability.test.tsx` (L545, L612, L665)
- `frontend/web/src/test/shellHomeTruthfulness.test.tsx` (L132, L176, L177, L238, L429)

#### 8P.1d -- ModelsView Label & Property Correction
Fix badge/tooltip conflation in `ModelsView.tsx`:
- GGUF files are runtime-agnostic; Vulkan is an engine acceleration property.
- Clearly separate display: Format: GGUF | Engine: llama.cpp | Acceleration: Vulkan.

**Batch 8P.1 Gate:** Focused tests for RED/GREEN (`backend/tests/test_llm.py`, `frontend/web/src/test/assistantViewReliability.test.tsx`, `frontend/web/src/test/shellHomeTruthfulness.test.tsx`); full backend suite before approval (>= 88 pytest passed); full frontend suite (>= 132 vitest passed), `npx tsc --noEmit` (0 errors), `npm run build` (clean production build).

---

### 8P.2 -- Runtime Engine Configuration & Performance Profiles

#### 8P.2a -- Declarative Engine Fields & Profile Settings in config.py
[MODIFY] `backend/app/core/config.py` -- add:
```python
# Declarative runtime engine properties
LLM_ENGINE: str = "llama_cpp"
LLM_ACCELERATION: str = "vulkan"
LLAMA_ENGINE_VERSION: str = "b10936"
LLAMA_SERVER_URL: str = "http://127.0.0.1:8085/v1"  # Verified port 8085

# Performance profiles (AMD RX 580 / Vulkan b10936 verified baseline; env-overridable)
PROFILE_ECO_CTX: int = 2048
PROFILE_ECO_GPU_LAYERS: int = 0         # 0 = CPU-only offload for Eco
PROFILE_ECO_THREADS: int = 4
PROFILE_ECO_MMPROJ_OFFLOAD: bool = False

PROFILE_BALANCED_CTX: int = 4096
PROFILE_BALANCED_GPU_LAYERS: int = 28
PROFILE_BALANCED_THREADS: int = 6
PROFILE_BALANCED_MMPROJ_OFFLOAD: bool = True

PROFILE_MAXIMUM_CTX: int = 8192
PROFILE_MAXIMUM_GPU_LAYERS: int = 33
PROFILE_MAXIMUM_THREADS: int = 8
PROFILE_MAXIMUM_MMPROJ_OFFLOAD: bool = True
```

#### 8P.2b -- llama_cpp.py Profile Mapping
[MODIFY] `backend/app/services/llm/llama_cpp.py`:
- Line 56: Read `self._engine_version = settings.LLAMA_ENGINE_VERSION` (replaces hardcoded `"b10936"`).
- Lines 151–164: Rewrite `_get_profile_params(self, profile: str) -> Dict[str, Any]` to read from `settings.PROFILE_*_*` instead of inline RX 580 constants.

**Batch 8P.2 Gate:** Focused tests for RED/GREEN (`backend/tests/test_llm_router.py`, `backend/tests/test_llm_router_lifecycle.py`); full backend suite before approval (>= 88 pytest passed).

---

### 8P.3 -- Atomic Persistent Storage Foundation

> **Locked Review Decision 1:** Storage root resolution and legacy database migration MUST be atomic in one batch.
> **Locked Review Decision 2:** Multiple differing legacy database candidates MUST NOT be auto-selected.

#### 8P.3a -- COMPANION_DATA_ROOT Bootstrap & Derived Paths in config.py
Resolution order (synchronous, before Settings instantiation and engine creation):
1. Explicit environment variable: `COMPANION_DATA_ROOT` (highest priority)
2. Bootstrap locator file: `%LOCALAPPDATA%\AI Companion\bootstrap.json` (`{ "schema_version": 1, "data_root": "..." }`)
3. Built-in default: `%LOCALAPPDATA%\AI Companion\Data`

Derived absolute paths on `settings`:
- `DATABASE_DIR` -> `COMPANION_DATA_ROOT / "database"`
- `DATABASE_PATH` -> `DATABASE_DIR / "companion.db"`
- `DATABASE_URL` derived property: `f"sqlite+aiosqlite:///{settings.DATABASE_PATH.as_posix()}"`
- `LIBRARY_DIR` -> `COMPANION_DATA_ROOT / "library"`
- `MODEL_LIBRARY_DIR` -> `LIBRARY_DIR / "models" / "llm"` (family-organized; NOT vulkan/ or cuda/)
- `INSTALLED_REGISTRY_PATH` -> `LIBRARY_DIR / "registry" / "models.json"`
- `VOICE_LIBRARY_DIR` -> `LIBRARY_DIR / "voices"`
- `ATTACHMENT_DIR` -> `COMPANION_DATA_ROOT / "attachments"`
- `IMPORT_INBOX_DIR` -> `COMPANION_DATA_ROOT / "imports" / "inbox"`
- `IMPORT_STAGING_DIR` -> `COMPANION_DATA_ROOT / "imports" / "staging"`
- `CHARACTER_DIR` -> `COMPANION_DATA_ROOT / "characters"`
- `MEMORY_DIR` -> `COMPANION_DATA_ROOT / "memory"`

Deprecate: `DATA_DIR`, `MODELS_DIR`, `LLAMA_MODELS_DIR`, hardcoded `DATABASE_URL` string.

#### 8P.3b -- Engine Initialization & Startup Ordering
- Synchronous migration check runs before any SQLAlchemy connection or query is initiated.
- Application must never create or open a fresh canonical database before migration eligibility has been evaluated.
- `backend/app/db/session.py`: Re-bind engine creation to use the derived canonical `settings.DATABASE_URL`.

#### 8P.3c -- First-Run Data Migration & Multi-Candidate Safety
Known legacy candidate locations (checked in order):
1. `backend/data/companion.db` (common dev working directory)
2. `<repo-root>/data/companion.db` (repository root data directory)

Migration Rules:
- `COMPANION_DATA_ROOT/database/companion.db` already exists? -> Use canonical DB directly; zero migration needed.
- Exactly one valid legacy candidate found? -> Safe copy to canonical path -> verify Alembic migration head (`005_scope_message_constraints`) matches -> create `.pre-migration-backup.db` alongside legacy file.
- Multiple differing candidates found? -> **STOP migration immediately and raise RuntimeError reporting ambiguity with candidate paths.** Do not choose silently. Do not overwrite.
- Neither candidate exists? -> Fresh install; canonical directory created lazily.

#### 8P.3d -- Test Isolation & Unit Tests
- Pytest test fixtures in `conftest.py` must isolate storage via temporary directories (`tmp_path`) or preserve in-memory SQLite (`:memory:`). Running tests must never pollute `%LOCALAPPDATA%\AI Companion\Data`.
- [NEW] `backend/tests/test_bootstrap.py`:
  - Missing locator -> default path used
  - Valid locator with absolute path -> locator path used
  - Invalid/corrupt JSON -> warning logged; default used
  - Unavailable/unmounted drive path -> warning logged; default used
  - Explicit `COMPANION_DATA_ROOT` env var -> overrides locator and default
- [NEW] `backend/tests/test_migration_safety.py`:
  - No legacy DB -> canonical path created fresh
  - Single legacy DB -> copied, verified against Alembic head, backup created
  - Multiple differing candidates -> `RuntimeError` raised with paths listed
  - Restart-safe: existing canonical DB is never overwritten

#### 8P.3e -- Source Immutability Invariants & Acceptance Semantics (Verified & Closed)
The Phase 8P.3 source-immutability invariant is codified as:
1. `companion.db`:
   - SHA-256 MUST remain unchanged
   - size MUST remain unchanged
   - mtime MUST remain unchanged
2. `companion.db-wal`:
   - SHA-256 MUST remain unchanged
   - size MUST remain unchanged
   - no checkpoint/truncate/write may occur
3. `companion.db-shm`:
   - SHA-256 MUST remain unchanged
   - size MUST remain unchanged
   - filesystem mtime MAY change as a result of legitimate SQLite read-lock / memory-mapped WAL-index coordination
   - an mtime-only change is NOT considered source-data mutation (Case C semantics confirmed via empirical isolation testing)
4. No source database rows may be modified.
5. No Alembic migration may run against a legacy source.
6. No source WAL checkpoint may be forced.
7. Migration destination integrity and logical row preservation remain required.

**Architectural Decision on Connection Semantics:**
KEEP the current production `mode=ro` behavior. DO NOT change inspection or migration connections to `immutable=1`.
*Rationale:* The migration architecture must remain safe for a source that may have WAL state and must not assert that the underlying database can never change. `immutable=1` disables normal SQLite locking/change-detection semantics and is not appropriate as a generic production migration assumption. The observed SHM mtime change is therefore accepted as transient SQLite/OS coordination metadata, provided SHM content and size remain unchanged.

**Batch 8P.3 Gate (COMPLETED & VERIFIED):**
- 130 backend pytest tests passed; 132 frontend vitest tests passed; 0 tsc errors.
- Controlled migration rehearsal (`D:\AICompanionMigrationRehearsal`) verified non-destructive migration and destination Alembic head `005_scope_message_constraints`.
- Authoritative source `backend/data/companion.db` verified byte-identical (size 188,416, SHA-256 `80758cbff04e0436d0465f7799a9ff6a074115aef7574aa52a3cc2758f246027`, mtime unchanged).
- Local-state/Git-ignored audit completed with zero secret leakage.
- SQLite SHM investigation confirmed Case C (metadata-only update, zero content mutation).

---

### 8P.4 -- Model Registry Schema v3 & Temporary Serialization Bridge

> **Locked Review Decision 3:** Flat compatibility fields are TEMPORARY during backend transition.

#### 8P.4a -- Enumerations & Sub-schemas
[MODIFY] `backend/app/schemas/model_registry.py`:
- Enums: `ModelAssetType` (gguf, mmproj, lora, embedding, tokenizer), `ModelVariant` (instruct, thinking, base, code, unknown), `InputModality` (text, image, audio, video), `ModelDiscoveryState` (discovered, registered, verified, incompatible), `ReasoningMode` (always_on, toggleable, unsupported, unknown), `CapabilityProvenance` (declared, detected, verified, unknown).
- Update `ValidationStatus`: add `incompatible`.
- Sub-schemas: `CompanionArtifactStatus`, `CapabilityEntry`, `GenerationDefaults`, `CompanionFile` (with optional `sha256`).

#### 8P.4b -- Three-Layer Model Schema Split
- `ModelManifest`: Stable identity and artifact metadata (id, display_name, asset_type, family, architecture, variant, parameters, quantization, reasoning_mode, capabilities, input_modalities, model_max_context, runtime_compatibility: List[str] = [], primary_file, companion_files, chat_template, license, source, sha256_primary).
- `ModelLibraryState`: Computed validation state (discovery_state, validation_status, primary_file_exists, size_gb, companion_artifact_statuses, available_capabilities, capability_provenance).
- `ModelRuntimeHints`: Non-authoritative recommendations (recommended_profiles, estimated_vram_gb, estimated_ram_gb, generation_defaults).
- `ModelRegistryEntry`: Composes `manifest`, `library_state`, `hints` + `runtime_model_id: str` + `registry_source: Literal["factory", "installed"]`.

#### 8P.4c -- Temporary Serialization Bridge
- In Pydantic v2, Python `@property` does not serialize into JSON.
- Add `@computed_field` properties on `ModelRegistryEntry` for existing flat fields (`context_limit`, `estimated_vram_gb`, `estimated_ram_gb`, `variant`, `capabilities`, `validation_status`, `primary_file_exists`, `companion_files_valid`, `size_gb`) so current frontend views and test suites continue functioning without disruption.

#### 8P.4d -- models/registry.template.json Schema v3
- Update template to `_schema_version: "3"`.
- Add `asset_type`, `architecture`, `input_modalities`, `model_max_context`, `reasoning_mode`, `runtime_compatibility` to all 5 verified Qwen3-VL entries.
- Add canonical `_note` explaining factory defaults vs installed models and persistent paths.

**Batch 8P.4 Gate:** Focused tests for RED/GREEN (`backend/tests/test_model_registry.py`); full backend suite before approval (>= 88 pytest passed).

---

### 8P.5 -- Effective Registry, Validation, GGUF Metadata & Capability Availability

> **Locked Review Decision 4:** Bounded, zero-dependency, best-effort Python GGUF header reader.

#### 8P.5a -- Dual-Source Effective Registry Merging
[MODIFY] `backend/app/services/model_registry.py`:
- Factory models loaded from `models/registry.template.json`, paths resolve relative to `FACTORY_MODEL_ROOT` (`<repo-root>/models/`), tagged `registry_source="factory"`.
- Installed models loaded from `INSTALLED_REGISTRY_PATH` (`COMPANION_DATA_ROOT/library/registry/models.json`), paths resolve relative to `MODEL_LIBRARY_DIR`, tagged `registry_source="installed"`.
- Merging logic: Factory loaded always; installed shadows factory on same ID; empty or absent installed registry never hides factory models.

#### 8P.5b -- Partial Companion Graceful Degradation
- Missing `mmproj` artifact removes `vision` from `available_capabilities`.
- Text chat capability remains usable; model is NOT prohibited from loading and is NOT marked incompatible.
- Missing primary file marks `validation_status=missing_primary`; model is unavailable.

#### 8P.5c -- Unregistered Scanner Rules
- Discovered GGUF files not in registry:
  - `capabilities = []` (zero auto-assigned chat capability)
  - `input_modalities = []` (zero default to [text])
  - `model_max_context = None` (zero default to 4096)
  - `runtime_compatibility = []` (zero default to [llama_cpp])
  - `variant = ModelVariant.unknown`
  - `discovery_state = discovered`, `validation_status = unregistered`

#### 8P.5d -- Bounded Zero-Dependency GGUF Header Reader
- Lightweight pure-Python binary parser using `struct` to inspect GGUF magic (`0x46554747`), version, and metadata key-value pairs.
- Boundaries & Metadata Extraction Rules:
  - Reads metadata/header only; NEVER loads tensor payloads into memory.
  - Strict limits: max 256 KV pairs, max string length 1024 bytes, max array items 64.
  - Read `general.architecture`.
  - Derive context key dynamically as `<architecture>.context_length` (e.g. `f"{arch}.context_length"`).
  - `general.quantization_version` is NOT the quantization scheme (it denotes GGUF format quantization version, not model quantization scheme); preserve `quantization_version` separately only if useful.
  - Use `general.file_type` only when recognized to populate `quantization` (via standard GGUF file_type enum mapping); otherwise quantization remains unknown (`""`).
  - Never infer quantization from arbitrary filename text.
  - Never infer capabilities from arbitrary filename text.
  - Malformed or unsupported header safely yields unknown/empty metadata; parser failure never makes an otherwise discoverable GGUF disappear.

**Batch 8P.5 Gate:** Focused tests for RED/GREEN (`backend/tests/test_model_registry.py` with schema v3 tests); full backend suite before approval (>= 88 pytest passed).

---

### 8P.6 -- Frontend Contract & OpenAPI Reconciliation

> **Locked Review Decision 3 Cleanup:** Migrate all repository consumers to structured fields; retire flat compatibility aliases.

#### 8P.6a -- TypeScript Registry API Contract
[MODIFY] `frontend/web/src/services/api/registryApi.ts`:
- Define `ModelManifest`, `ModelLibraryState`, `ModelRuntimeHints` TypeScript interfaces matching backend schema v3.
- Update `RegistryEntry` to compose these layers while supporting transitional properties.
- Migrate consumers from `context_limit` to `model_max_context`.

#### 8P.6b -- ModelsView UI Structured Consumption
[MODIFY] `frontend/web/src/components/workspace/ModelsView.tsx`:
- Map model attributes from structured layers (`e.manifest.model_max_context ?? e.context_limit`, `e.hints.estimated_vram_gb`, `e.library_state.available_capabilities`).
- Use `available_capabilities` for UI feature gating.

#### 8P.6c -- Frontend Test Fixture Updates
- Update mock `RegistryEntry` objects in:
  - `frontend/web/src/test/modelsStateReconciliation.test.tsx`
  - `frontend/web/src/test/assistantViewReliability.test.tsx`
  - `frontend/web/src/test/shellHomeTruthfulness.test.tsx`

#### 8P.6d -- Flat Compatibility Cleanup
- Search repository-wide for remaining flat consumers of `ModelRegistryEntry`.
- Once all internal consumers are verified on structured fields, remove deprecated `@computed_field` compatibility aliases from backend schema.

#### 8P.6e -- OpenAPI Contract Regeneration & Full LLM Route Verification
- Regenerate `contracts/openapi/openapi.json` directly from the actual FastAPI application (`app.openapi()`).
- Do NOT hand-author only two endpoints.
- Verify all existing model and LLM routes are represented in the generated contract:
  - `GET /api/v1/models`
  - `GET /api/v1/models/registry`
  - `POST /api/v1/models/load`
  - `POST /api/v1/models/unload`
  - `PATCH /api/v1/models/profile`
  - `POST /api/v1/chat/completions`
- Carefully review the generated contract diff for unrelated drift before finalizing.

**Batch 8P.6 Gate:** Focused tests for RED/GREEN (`frontend/web/src/test/modelsStateReconciliation.test.tsx`, `backend/tests/test_model_registry.py`); full backend suite before approval (>= 88 pytest passed); full frontend suite (>= 132 vitest passed), `npx tsc --noEmit` (0 errors), `npm run build` (clean production build).

---

### 8P Final Integration Verification Gate

Before Phase 8P is submitted for approval:
1. `grep -r "Local AI Core" frontend/web/src --include="*.tsx" --include="*.ts"` -> empty
2. `grep -r "Local AI Core" backend/ --include="*.py"` -> empty
3. `python -c "from app.core.config import settings; print(settings.COMPANION_DATA_ROOT)"` -> displays canonical root
4. `pytest backend/tests/ -v --tb=short` -> >= 88 passed + all new bootstrap, migration, and schema v3 tests passed
5. `npm run test -- --run` -> >= 132 passed
6. `npx tsc --noEmit` -> 0 errors
7. `npm run build` -> clean production build

### 8P Commit Message

```text
feat(8p): runtime config -- atomic storage root, schema v3, merged registry, terminology

TERMINOLOGY: Reconcile "Local AI Core" -> "Local AI Runtime" across backend and frontend;
update error and status assertions in assistantViewReliability and shellHomeTruthfulness tests;
separate GGUF format, llama.cpp engine, and Vulkan acceleration in ModelsView.

CONFIG & PROFILES: Declare LLM_ENGINE, LLM_ACCELERATION, LLAMA_ENGINE_VERSION in config.py;
move RX 580 profile constants to env-overridable PROFILE_*_* settings; llama_cpp reads from settings.

STORAGE: Atomic persistent storage foundation; resolve_data_root() (env > bootstrap.json > default);
derive all 11 canonical paths; enforce synchronous migration check before engine creation;
safe first-run migration with Alembic head check (005_scope_message_constraints);
stop on multi-candidate ambiguity; strict test isolation.

REGISTRY & SCHEMA v3: Three-layer ModelManifest, ModelLibraryState, ModelRuntimeHints split;
new enums and subschemas; dual-source effective registry (factory + installed);
graceful vision degradation on missing mmproj; zero fabricated defaults on unregistered GGUFs;
bounded zero-dependency Python GGUF header reader; models/registry.template.json schema v3.

CONTRACTS: Reconcile registryApi.ts interfaces; ModelsView consumes structured layers;
update frontend test fixtures; regenerate openapi.json from FastAPI app and verify all model/LLM routes.

Tests: >= 88 backend pytest + bootstrap/migration/schema tests, >= 132 vitest, 0 tsc.
```


---

## Phase 8B -- Multimodal Image Attachment Foundation

Branch: feature/multimodal-image-attachments (based on merged 8P)
Test gate: migration 006 applies cleanly; >= 88 + attachment tests; 0 tsc; clean build.
Dependency: settings.ATTACHMENT_DIR (from 8P.3) must exist.

### Attachment Lifecycle

  selected              -- File chosen; not yet uploaded
  uploading             -- POST /attachments in progress
  staged                -- Uploaded; message_id = NULL; shown in composer; removable
  committed             -- Bound to user message on send; shown in history
  soft_deleted          -- Removed by user or parent soft-deleted; is_deleted=True
  orphan_pending_cleanup -- Staged > 24h with no send; cleaned by retention purge job (Phase 9)

Cancellation: if assistant generation cancelled mid-stream, user message + attachments remain
committed. Only partial assistant response follows Phase 5 cancellation semantics.
Frontend removal: must call DELETE endpoint -- not just clear React state.

### 8B.1 -- Migration 006

[CREATE] backend/migrations/versions/006_add_attachments.py

  revision: str = "006_add_attachments"
  down_revision = "005_scope_message_constraints"

  Table "attachments":
    id              String(36)  PK
    owner_id        String(64)  NOT NULL, index  (OwnerMixin)
    message_id      String(36)  FK messages.id CASCADE, nullable, index
    conversation_id String(36)  FK conversations.id CASCADE, NOT NULL, index
    filename_display String(255) NOT NULL  -- original user filename; display only
    storage_filename String(128) NOT NULL  -- UUID-based; never user filename
    storage_path    String(512) NOT NULL   -- relative to COMPANION_DATA_ROOT; NEVER in API response
    mime_type       String(64)  NOT NULL
    size_bytes      Integer     NOT NULL
    image_width     Integer     nullable
    image_height    Integer     nullable
    is_deleted      Boolean     NOT NULL DEFAULT false  (SoftDeleteMixin)
    deleted_at      DateTime(tz) nullable
    created_at      DateTime(tz) NOT NULL DEFAULT now()  (TimestampMixin)
    updated_at      DateTime(tz) NOT NULL DEFAULT now()
  Index: ix_attachments_staged_created on (message_id, created_at)

CASCADE fires only on SQL hard-delete. Soft-delete of parent must explicitly soft-delete children.

### 8B.2 -- Attachment ORM Model

[CREATE] backend/app/models/attachment.py

  class Attachment(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
      __tablename__ = "attachments"
      message_id      = mapped_column(FK "messages.id" CASCADE, nullable, index)
      conversation_id = mapped_column(FK "conversations.id" CASCADE, NOT NULL, index)
      filename_display = mapped_column(String(255), NOT NULL)
      storage_filename = mapped_column(String(128), NOT NULL)
      storage_path     = mapped_column(String(512), NOT NULL)   # NEVER in API response
      mime_type        = mapped_column(String(64), NOT NULL)
      size_bytes       = mapped_column(Integer, NOT NULL)
      image_width      = mapped_column(Integer, nullable)
      image_height     = mapped_column(Integer, nullable)
      message = relationship("Message", back_populates="attachments")
      conversation = relationship("Conversation", back_populates="attachments")

Mixins: UUIDPrimaryKeyMixin, TimestampMixin (created_at+updated_at), OwnerMixin (String(64)), SoftDeleteMixin (is_deleted default False).

[MODIFY] conversation.py -- add attachments relationship
[MODIFY] message.py -- add attachments relationship (lazy="selectin")
[MODIFY] models/__init__.py -- register Attachment

### 8B.3 -- Attachment Schemas

[CREATE] backend/app/schemas/attachment.py

  ALLOWED_MIME_TYPES = frozenset({"image/png", "image/jpeg"})   # WebP deferred
  MAX_SIZE_BYTES = 10 * 1024 * 1024   # 10 MB
  MAX_PIXEL_DIMENSION = 8192
  MAX_MEGAPIXELS = 32.0
  MAX_ATTACHMENTS_PER_MESSAGE = 4

  class AttachmentOut:   id, conversation_id, message_id?, filename_display, mime_type,
                         size_bytes, image_width?, image_height?, created_at
                         -- storage_path NEVER included

  class AttachmentRef:   id, filename_display, mime_type, size_bytes
                         -- lightweight reference embedded in MessageOut

[MODIFY] schemas/message.py
  MessageSend: add attachment_ids: List[str] = []
  MessageOut:  add attachments: List[AttachmentRef] = []

### 8B.4 -- Provider-Independent Multimodal Contract

[CREATE] backend/app/schemas/multimodal.py
  class TextContent:            type="text"; text: str
  class ImageAttachmentRef:     type="image_attachment"; attachment_id: str; mime_type: str
  class ResolvedImageContent:   type="image_bytes"; mime_type: str; data: bytes
  ContentBlock = Union[TextContent, ResolvedImageContent]
  # Note: ImageAttachmentRef is used in application/orchestrator layer;
  # media_resolver resolves it into ResolvedImageContent before passing ContentBlock[] to LLMProvider

[MODIFY] schemas/llm.py
  ChatMessage.content: Union[str, List[ContentBlock]]   # str preserved for backward-compat

### 8B.5 -- Image Validation Service

[CREATE] backend/app/services/attachment_validator.py

Validation order (fail-fast):
  1. Byte size limit (before any decode)
  2. MIME from file byte headers (not Content-Type) -- struct-based byte detection
  3. Decode with Pillow (PNG: 0x89PNG; JPEG: 0xFFD8FF)
  4. Max pixel dimension per side
  5. Megapixel budget
  6. Decompression bomb protection (Image.MAX_IMAGE_PIXELS)

PNG and JPEG only. WebP deferred -- not verified with pinned llama.cpp/Qwen3-VL.
Do NOT use python-magic (requires libmagic binary; complicates Windows packaging).

### 8B.6 -- Attachment Endpoints

[CREATE] backend/app/api/v1/endpoints/attachments.py

  POST   /api/v1/conversations/{conversation_id}/attachments
         Auth: Bearer. Validate ownership + MIME + size + dimensions.
         Storage: COMPANION_DATA_ROOT/attachments/{owner_id}/{conversation_id}/{attachment_uuid}.{ext}
         storage_filename = UUID (never user filename)
         Returns: AttachmentOut (no storage_path)

  GET    /api/v1/conversations/{conversation_id}/attachments/{attachment_id}/preview
         Auth: Bearer. Validate ownership + not deleted.
         Returns: image bytes + Content-Type header.
         Frontend fetches as Blob via authenticated apiFetch -- NOT plain <img src>

  DELETE /api/v1/conversations/{conversation_id}/attachments/{attachment_id}
         Auth: Bearer. Soft-delete: is_deleted=True, deleted_at=now().
         Filesystem cleanup: retention purge job (Phase 9) -- not at delete time.

Storage security invariants:
  1. storage_filename = UUID -- never user-supplied filename
  2. Resolve full path; assert inside settings.ATTACHMENT_DIR (path traversal guard)
  3. storage_path never in any API response
  4. Preview validates ownership before serving bytes

### 8B.6b -- Transactional Attachment Claiming (Concurrency-Safe)

[CREATE/MODIFY] backend/app/services/attachment_service.py (or message_service.py):

Binding must be atomic and concurrency-safe. Do NOT use session.get() + conditional assignment:
that pattern is vulnerable to TOCTOU races where two concurrent sends can both read
message_id=NULL and both proceed to bind the same attachment.

Instead, use an atomic conditional UPDATE within the same transaction as user message creation:

  async def claim_attachments_for_message(
      session, message_id, attachment_ids, owner_id, conversation_id
  ) -> None:
      """Atomically claim staged attachments for a new user message.
      Each claim is a conditional UPDATE requiring exactly 1 affected row.
      Runs inside the same transaction as user message INSERT.
      On any failure the entire transaction rolls back.
      """
      if len(attachment_ids) > MAX_ATTACHMENTS_PER_MESSAGE:
          raise ValidationError(f"Exceeds {MAX_ATTACHMENTS_PER_MESSAGE} attachment limit")

      for att_id in attachment_ids:
          # Atomic conditional UPDATE: only succeeds if attachment is staged, unbound,
          # owned by caller, belongs to correct conversation, and not deleted.
          result = await session.execute(
              update(Attachment)
              .where(
                  Attachment.id == att_id,
                  Attachment.owner_id == owner_id,
                  Attachment.conversation_id == conversation_id,
                  Attachment.message_id.is_(None),     # staged: must be unbound
                  Attachment.is_deleted.is_(False),
              )
              .values(message_id=message_id)
              .returning(Attachment.id)
          )
          claimed = result.scalar_one_or_none()
          if claimed is None:
              # The UPDATE matched zero rows: attachment missing, wrong owner,
              # wrong conversation, already committed, or deleted.
              # Distinguish the reason for a useful error message:
              att = await session.get(Attachment, att_id)
              if att is None:
                  raise NotFoundError(f"Attachment {att_id} not found")
              if att.owner_id != owner_id:
                  raise PermissionError(f"Attachment {att_id} not owned by caller")
              if att.conversation_id != conversation_id:
                  raise ValidationError(f"Attachment {att_id} belongs to a different conversation")
              if att.is_deleted:
                  raise ValidationError(f"Attachment {att_id} has been deleted")
              # message_id is not None: already claimed
              raise ValidationError(f"Attachment {att_id} is already committed to a message")
          # Exactly one row updated: claim succeeded.

Concurrency invariant:
  Two concurrent sends referencing the same attachment_id:
  Exactly one UPDATE will match (message_id IS NULL condition); the other returns 0 rows.
  The second request receives a 422 "already committed" error. No double-binding occurs.
  This is the basis of the existing concurrent duplicate-send test.

Rollback invariant:
  If any claim fails, the enclosing transaction rolls back.
  Neither partial message creation nor partial attachment bindings survive.

Cancellation invariant:
  If assistant-stream generation is cancelled AFTER the user message and attachments are committed,
  the user message and all bound attachments remain committed and visible in history.
  Only the partial/empty assistant response follows Phase 5 cancellation semantics.

### 8B.7 -- Attachment/Media Resolver & Provider Translation

Canonical type boundary:

  ImageAttachmentRef         (attachment_id: str, mime_type: str)
       ↓ media_resolver.resolve_image_content()
  ResolvedImageContent       (mime_type: str, data: bytes)
       ↓ orchestrator wraps in ContentBlock[]
  LLMProvider.chat()
       ↓ LlamaCppProvider._translate_messages()
  llama.cpp chat completions wire format

LlamaCppProvider MUST NOT:
  - Construct application attachment paths from attachment IDs directly
  - Query attachment persistence (DB) directly
  - Know about COMPANION_DATA_ROOT or settings.ATTACHMENT_DIR directly
  - Perform any filesystem IO (that is media_resolver's responsibility)
  - Use asyncio.run_in_executor for file reads (moved to media_resolver)

LlamaCppProvider MUST ONLY:
  - Receive ResolvedImageContent (bytes already loaded) from orchestrator
  - Translate ContentBlock[] -> llama.cpp chat completions wire format
  - Encode pre-loaded image bytes as data:{mime_type};base64,{b64} in image_url format

[CREATE] backend/app/schemas/multimodal.py -- add:
  @dataclass class ImageAttachmentRef: attachment_id: str; mime_type: str
  @dataclass class ResolvedImageContent: mime_type: str; data: bytes

[CREATE] backend/app/services/assistant/media_resolver.py:
  async def resolve_image_content(ref: ImageAttachmentRef) -> ResolvedImageContent:
      """Load and validate image bytes for a single attachment.
      Resolves the filesystem path from settings.ATTACHMENT_DIR.
      Validates path is inside ATTACHMENT_DIR (traversal guard).
      Raises on missing file, path traversal, or read error.
      Called by orchestrator before ContentBlock[] is passed to LLMProvider."""

[MODIFY] backend/app/services/assistant/orchestrator.py:
  # Gate on library state (available_capabilities) -- not manifest.capabilities
  has_vision = (
      active_entry is not None
      and ModelCapability.vision in active_entry.library_state.available_capabilities
  )

  if has_vision and committed_attachments:
      content_blocks: List[ContentBlock] = []
      for att in committed_attachments:
          if not att.is_deleted:
              ref = ImageAttachmentRef(attachment_id=att.id, mime_type=att.mime_type)
              resolved = await media_resolver.resolve_image_content(ref)
              content_blocks.append(ResolvedImageContent(mime_type=resolved.mime_type, data=resolved.data))
      content_blocks.append(TextContent(text=user_text))
      chat_message = ChatMessage(role="user", content=content_blocks)
  else:
      chat_message = ChatMessage(role="user", content=user_text)

[MODIFY] backend/app/services/llm/llama_cpp.py -- add _translate_messages():
  Receives ContentBlock[] where image blocks carry ResolvedImageContent (bytes already loaded).
  Does NOT access filesystem, attachment IDs, or ATTACHMENT_DIR.
  Encodes pre-loaded bytes as data:{mime_type};base64,{b64} in image_url wire format.
  No run_in_executor required: all IO was completed by media_resolver before this call.

### 8B.8 -- Frontend Attachment API

[CREATE] frontend/web/src/services/api/attachmentApi.ts

  ALLOWED_MIME_TYPES = ['image/png', 'image/jpeg']
  MAX_SIZE_BYTES = 10 * 1024 * 1024
  MAX_ATTACHMENTS_PER_MESSAGE = 4

  uploadAttachment(conversationId, file, apiKey): Promise<AttachmentOut>
  deleteAttachment(conversationId, attachmentId, apiKey): Promise<void>
  fetchAttachmentBlobUrl(conversationId, attachmentId, apiKey): Promise<string>
    -- fetch() with Bearer -> res.blob() -> URL.createObjectURL()
    -- Caller MUST revoke via URL.revokeObjectURL() on cleanup
    -- Never use plain <img src="..."> -- browser does not attach Authorization header

[MODIFY] conversationApi.ts -- add attachment_ids: string[] to streamSendMessage

### 8B.9 -- Frontend Composer & Message History

[MODIFY] AssistantComposer.tsx:
  const hasVision = currentModel?.library_state?.available_capabilities?.includes('vision') ?? false

  <input ref={fileInputRef} type="file" accept="image/png,image/jpeg" hidden onChange={handleFileSelected} />
  <button disabled={!hasVision || !conversationId || pendingAttachments.length >= 4}
          title={hasVision ? "Attach image" : "Vision not available"} onClick={...} />

  Remove staged: await deleteAttachment(...); setPendingAttachments(filtered); URL.revokeObjectURL(url)
  Previews: via fetchAttachmentBlobUrl -- NOT plain img src

[MODIFY] ConversationMessageItem.tsx:
  Render MessageOut.attachments: AttachmentRef[]
  Fetch previews via fetchAttachmentBlobUrl -- authenticated Blob; NOT plain img src
  Revoke object URLs on component unmount

[MODIFY] endpoints/conversations.py GET /{id}/messages:
  Ensure MessageOut.attachments populated from Message.attachments (already lazy="selectin")

### 8B Test Plan

backend/tests/test_attachments.py:
  - Migration 006 applies to fresh DB (all columns, indexes, FKs present)
  - Migration chain: 005 -> 006 -> downgrade -> re-upgrade
  - ORM parity: Attachment model matches migration exactly
  - All 4 mixins: TimestampMixin (created_at+updated_at), OwnerMixin (String(64)), SoftDeleteMixin (default False)
  - Upload PNG -> 201, AttachmentOut, no storage_path field
  - Upload JPEG -> 201
  - Upload WebP -> 422
  - MIME from bytes (not Content-Type header)
  - File > 10MB -> 413
  - Image > MAX_PIXEL_DIMENSION -> 422
  - Image > MAX_MEGAPIXELS -> 422
  - Decompression bomb -> 422
  - BOLA: wrong conversation_id -> 404
  - Wrong owner -> 403
  - Preview: correct auth -> 200; wrong owner -> 403
  - DELETE: 204, is_deleted=True; delete again -> 404
  - Send with valid attachment_ids -> 200, MessageOut.attachments populated
  - Send with deleted attachment_id -> 422
  - Send with other-owner attachment_id -> 422
  - Send with attachment from different conversation -> 422
  - Send with already-committed attachment_id -> 422 (reuse blocked)
  - Send with > 4 attachment_ids -> 422
  - Send + concurrent duplicate send with same attachment_id -> one succeeds, other blocked
  - Stream cancelled after commit -> user message + attachments remain in history
  - GET messages -> AttachmentRef[] present
  - F5 reload: send + GET messages -> preview loads (authenticated Blob fetch)
  - Bootstrap locator: missing -> default path; valid -> locator path; invalid -> default with warning
  - COMPANION_DATA_ROOT env var -> overrides locator and default
  - Legacy DB migration: no legacy -> fresh; one legacy -> copied + verified; two candidates -> error

frontend/web/src/test/attachmentComposer.test.tsx:
  - Paperclip disabled: no vision in available_capabilities
  - Paperclip disabled: mmproj absent (vision removed from available_capabilities)
  - Paperclip disabled: no active conversation
  - Upload: POST called; preview via authenticated Blob URL
  - Remove: DELETE called + URL.revokeObjectURL called
  - Send: attachment_ids included in payload
  - 5th image blocked client-side
  - WebP rejected client-side

### 8B Commit Message

feat(8b): multimodal image attachment foundation
- 006_add_attachments migration (006 -> 005_scope_message_constraints)
- Attachment ORM: 4 mixins; UUID storage path; conversation + message relationships
- schemas/attachment.py: AttachmentOut (no storage_path), AttachmentRef, constants
- schemas/multimodal.py: TextContent, ImageAttachmentRef, ResolvedImageContent, ContentBlock
- schemas/llm.py: ChatMessage.content Union[str, List[ContentBlock]]
- schemas/message.py: attachment_ids[] + attachments[]
- attachment_validator.py: Pillow, byte-header MIME, dimensions, megapixel, bomb
- endpoints/attachments.py: POST/preview/DELETE; path traversal guard
- media_resolver.py: resolve_image_content(); owns async filesystem IO and path validation
- orchestrator.py: vision gate via available_capabilities; calls media_resolver; provider-independent content
- llama_cpp.py: _translate_messages(); receives pre-resolved bytes; wire translation only (no filesystem IO)
- attachmentApi.ts: upload, delete, fetchAttachmentBlobUrl (createObjectURL lifecycle)
- AssistantComposer: vision gate, authenticated previews, remove->DELETE, count limit
- ConversationMessageItem: authenticated Blob previews; revokeObjectURL on unmount
- Tests: test_attachments.py + attachmentComposer.test.tsx
WebP deferred. Video/PDF/audio out of scope.

---

## Phase 8C -- Integration, Accessibility & Polish

Branch: feature/phase8-ui-integration-polish (based on merged 8B)
Test gate: 100+ pytest, 50+ vitest. Zero production mock imports. Clean build.

### 8C.1 -- Delete Deprecated Mock Files

Mandatory pre-check:
  grep -r "from '.*mock/" frontend/web/src --include="*.tsx" --include="*.ts" -l
  # Must return ONLY test files -- fix any non-test imports first

Delete after verification:
  mock/localAiData.ts
  mock/healthData.ts
  mock/deviceAndMemoryData.ts
  mock/logsData.ts
  mock/multilingualData.ts
Evaluate characterData.ts based on CharactersView import.

### 8C.2 -- Bundle Analysis

  npm run build
  npx vite-bundle-visualizer
  Expected: ~80KB reduction from mock removal.
  If any chunk > 500KB uncompressed: apply React.lazy + Suspense.
  Primary candidate: ScheduleView.tsx (~45KB source).

### 8C.3 -- Accessibility

  - Icon-only buttons: aria-label (send, stop, mic, attach, remove-attachment)
  - Keyboard: Tab through composer; Enter removes attachment chip; Esc closes drawer
  - Message bubbles: role="article"
  - Attachment previews: alt={att.filename_display}
  - After send: return focus to input field
  - Navigation sidebar: aria-label

### 8C.4 -- Final Test Suite

frontend/web/src/test/phase8Integration.test.tsx:
  - Send + F5 reload + preview visible (authenticated Blob)
  - Send + cancel mid-stream -> user message + image remain in history
  - Text-only model: button disabled; text send works
  - Remove staged: DELETE called, URL revoked, gone from composer
  - 5th image blocked
  - PNG/JPEG succeed; WebP rejected with message
  - Vision -> text-only model switch: button disables, pending cleared with warning
  - mmproj absent: vision button disabled

Backend regression:
  pytest tests/ -v --tb=short   # Target: 100+ passed

### 8C.5 -- Documentation Completion

[MODIFY] docs/02_Planning/ROADMAP.md
  - Mark Phase 8C complete / verified
  - Reconcile active delivery gates

[CREATE] docs/03_Walkthroughs/walkthrough-phase8-multimodal-attachments.md
  - Follow walkthrough-template.md (7-section format)
  - Include: lifecycle, storage security, vision gate, provider translation, test results, WebP deferral

[MODIFY] docs/01_Tracking/task.md
  - Mark all items complete
  - Archive sprint to docs/01_Tracking/archive/task-YYYY-MM-DD-phase8-ui-multimodal.md

### 8C Commit Message

feat(8c): integration polish -- mock cleanup, bundle, a11y, final tests, docs
- Delete mock files (zero production imports verified)
- Bundle analysis; lazy-load if warranted
- Accessibility: aria-labels, role=article, focus management, keyboard
- phase8Integration.test.tsx: reload/cancel/vision gate/mmproj-absent/limits
- walkthrough-phase8-multimodal-attachments.md (7-section)
- ROADMAP.md: Phase 8 complete / verified
- task.md: sprint archived

---

## Deferred / Out of Scope

  WebP support          -- deferred; not verified with pinned llama.cpp/Qwen3-VL
  Video/audio/PDF       -- out of scope
  Android multimodal    -- deferred
  CUDA implementation   -- out of scope; boundary documented only
  Model Import Manager  -- execution service & UI out of scope for Phase 8B/8C (controlled local import is a locked V1 requirement under Decision D6; managed online downloads remain post-V1)
  MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md -- deferred until dedicated Import Manager planning
  Auto HuggingFace downloads / quantization  -- deferred post-V1
  Benchmarking wizard   -- deferred
  Attachment retention purge job -- deferred to Phase 9
  OS-backed secret storage (DPAPI) -- deferred
  Per-library root override -- deferred future feature
  Voice import pipeline UI -- deferred

---

## Non-Negotiable Invariants

  1.  Backend runtime state is authoritative -- frontend never computes model state
  2.  Selected model != active model
  3.  Requested profile != applied profile -- both displayed with explicit labels
  4.  storage_path never returned in any API response
  5.  No base64 in messages.content -- bytes on filesystem; DB stores metadata only
  6.  SQL CASCADE != soft-delete -- service layer must explicitly soft-delete children
  7.  All original 88 pytest tests pass after every branch merge
  8.  No git add/commit/push by Gemini -- user commits manually
  9.  Provider independence -- orchestrator uses ContentBlock; LlamaCppProvider translates
  10. GGUF != Vulkan/CUDA -- file format and acceleration are distinct; never conflated in UI
  11. Profile portability -- RX 580 defaults in settings; _get_profile_params() reads settings
  12. COMPANION_DATA_ROOT backward-safe -- conditional migration; no silent overwrite
  13. ModelManifest fields never mutated with runtime/session state
  14. Unknown GGUF capabilities are empty; not auto-assigned
  15. available_capabilities (library state) gates frontend features; not manifest.capabilities
  16. Git/LFS policy unchanged without explicit user authorization
  17. Python @property does not serialize in Pydantic v2 -- use model_serializer/computed_field
  18. Router port is 8085 -- not 8080; LLAMA_SERVER_URL = http://127.0.0.1:8085/v1
