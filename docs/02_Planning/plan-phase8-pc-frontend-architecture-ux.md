# Phase 8 Implementation Plan — PC Frontend Architecture, Runtime Config, Multimodal & Polish

> **Status:** Final planning baseline — awaiting user APPROVED signal
> **This is the single authoritative version. No supplements. No pass references.**
> **Canonical reference:** `docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`

---

## Branch Strategy

develop (baseline: 88 pytest, 38 vitest, 0 tsc, migration head 005_scope_message_constraints)
  +-- feature/phase8-ui-foundation           (8A: frontend-only, zero backend schema changes)
        merge to develop
  +-- feature/phase8-runtime-config          (8P: config, terminology, schema v3, data root)
        based on merged 8A; merge to develop
  +-- feature/multimodal-image-attachments   (8B: full stack, depends on 8P ATTACHMENT_DIR)
        based on merged 8P; merge to develop
  +-- feature/phase8-ui-integration-polish   (8C: polish, cleanup, final tests)
        based on merged 8B

8P precedes 8B: 8B writes to COMPANION_DATA_ROOT/attachments/ -- 8P must establish that path first.

---

## Scope Guard

- PC-first. No Android.
- No STT/TTS. No video. No PDF. No arbitrary file types.
- No CUDA (boundary documented in 8P only).
- No new state management library.
- No import UI, auto-downloads, quantization, benchmarking.
- No MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md -- deferred until Import Manager phase.
- No .gitattributes / .lfsconfig / LFS remote changes without explicit user authorization.

---

## Resolved Decisions

| Decision | Resolution |
|----------|-----------|
| OD1: Default Windows data-root | %LOCALAPPDATA%\AI Companion\Data |
| OD2: Bootstrap locator | %LOCALAPPDATA%\AI Companion\bootstrap.json |
| OD3: Dev vs installed models | Dev/bootstrap models stay under Git/LFS. Installed/user-imported models use COMPANION_DATA_ROOT/library/models/ |

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
| "Local AI Core" in 19 frontend locations | Various .tsx/.ts | Full rename in 8P.1b |
| ModelRegistryEntry flat struct mixes identity/state/hints | schemas/model_registry.py | Split into ModelManifest + ModelLibraryState + ModelRuntimeHints |
| variant defaults to "instruct" for unregistered scan | model_registry.py L132 | Must be ModelVariant.unknown |
| capabilities=[ModelCapability.chat] auto-assigned to discovered GGUFs | model_registry.py L132 | REMOVE. Unknown GGUFs get capabilities=[] |
| Migration head: 005_scope_message_constraints | backend/migrations/versions/ | Next: 006_add_attachments |
| registry.template.json schema v1, Qwen-only | models/registry.template.json | Update to schema v3 |

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

  # Runtime compatibility -- do NOT default to [llama_cpp] for unknown GGUFs.
  # Stays [] until declared or verified.
  runtime_compatibility: List[str] = Field(default_factory=list)

  # Artifact paths (relative to the registry source root: FACTORY_MODEL_ROOT or MODEL_LIBRARY_DIR)
  primary_file: str
  companion_files: List[CompanionFile] = []

  # Chat template
  chat_template: Optional[str]
  chat_template_source: Optional[str]   # "gguf_metadata" | "registry_declared" | None

  # Runtime compatibility (declarative, not acceleration-specific)
  runtime_compatibility: List[str] = ["llama_cpp"]

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

### Registry Locations and Path Resolution

  Factory template: models/registry.template.json (repo, versioned) -- read-only at runtime
    Artifact paths in this file resolve relative to FACTORY_MODEL_ROOT (<repo-root>/models/)

  Installed runtime: COMPANION_DATA_ROOT/library/registry/models.json -- all writes go here
    Artifact paths in this file resolve relative to MODEL_LIBRARY_DIR (COMPANION_DATA_ROOT/library/models/llm/)

_load_registry_json(): check installed first; fall back to template if absent.
Path resolution MUST use the correct root for the source registry -- never mix roots.

### registry.template.json -- Schema v3

  _schema_version: "3"
  _note: "Qwen3-VL entries are verified factory defaults, not a whitelist. Any compatible GGUF
          may be registered. variant and capabilities must be declared explicitly -- never
          inferred from filename. Paths are relative to FACTORY_MODEL_ROOT (repo models/).
          llm/ in COMPANION_DATA_ROOT contains persistent installed models organized by family,
          not by acceleration backend."
  models: [ ...entries with asset_type, architecture, input_modalities, model_max_context,
             reasoning_mode added to all existing entries... ]

---

## Phase 8A -- Frontend Architecture & UX Harmonization

Branch: feature/phase8-ui-foundation
Test gate: >= 88 pytest (unchanged), >= 38 vitest, 0 tsc, clean build.
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
Tests: >= 88 pytest, >= 38 vitest, 0 tsc, clean build


---

## Phase 8P -- Runtime Configuration & Persistent Asset Foundation

Branch: feature/phase8-runtime-config (based on merged 8A)
Test gate: >= 88 pytest, >= 38 vitest (string assertions updated), 0 tsc, clean build.
Constraint: No DB migrations. No new API endpoints. No new frontend pages.
Critical prereq for 8B: settings.ATTACHMENT_DIR must exist before 8B writes files.

### 8P.1 -- Terminology Reconciliation

#### 8P.1a -- Backend

  grep -r "Local AI Core" backend/ --include="*.py" -l
  # Fix each occurrence -- replace with "Local AI Runtime"

[MODIFY] backend/app/core/config.py
  PROJECT_NAME: str = "Local AI Runtime"  # Canonical. Previously "Local AI Core" in legacy docs.

[MODIFY] backend/app/main.py -- ensure title=settings.PROJECT_NAME (not hardcoded string)

#### 8P.1b -- Frontend (19 confirmed locations)

  AssistantView.tsx L93   "Local AI Core is offline..." -> "Local AI Runtime is offline..."
  AssistantView.tsx L241  "Local AI Core session initialized..." -> "Local AI Runtime session initialized..."
  AssistantView.tsx L248  "Connect to Local AI Core on port 8000" -> "Connect to Local AI Runtime on port 8000"
  Header.tsx L254         Local AI Core (label) -> Local AI Runtime
  Header.tsx L343         comment -> update
  HomeView.tsx L168       "Local AI Core Online" -> "Local AI Runtime Online"
  HealthView.tsx L121,L180  description/comment -> update
  ModelsView.tsx L337     Local AI Core: -> Local AI Runtime:
  ModelProvidersCard.tsx L34  description -> "Local AI Runtime orchestrates..."
  ApplicationStatesShowcase.tsx L330,L346,L358  state labels -> "Local AI Runtime Offline" etc.
  HealthPipelineCard.tsx L138  comment/diagram -> update
  mock/healthData.ts L91,L336  mock strings -> update for consistency

#### 8P.1c -- Frontend Tests (mandatory -- tests fail without this)

[MODIFY] frontend/web/src/test/assistantViewReliability.test.tsx
  L544, L613, L666: update assertions "Local AI Core" -> "Local AI Runtime"

#### 8P.1d -- GGUF/Vulkan Label Correction in ModelsView

Fix any badge/tooltip implying models are "Vulkan models":
  - GGUF files are runtime-agnostic; Vulkan is an engine property
  - Display: GGUF (file format) | Engine: llama.cpp | Acceleration: Vulkan

### 8P.2 -- COMPANION_DATA_ROOT Configuration

[MODIFY] backend/app/core/config.py -- add:

  COMPANION_DATA_ROOT: Path = Field(
      default_factory=lambda: Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local")))
          / "AI Companion" / "Data"
  )

  @property DATABASE_DIR -> COMPANION_DATA_ROOT / "database"
  @property DATABASE_PATH -> DATABASE_DIR / "companion.db"
  # Remove hardcoded DATABASE_URL field; derive from: f"sqlite+aiosqlite:///{settings.DATABASE_PATH.as_posix()}"

  @property LIBRARY_DIR -> COMPANION_DATA_ROOT / "library"
  @property MODEL_LIBRARY_DIR -> LIBRARY_DIR / "models" / "llm"    # NOT vulkan/ or cuda/
  @property INSTALLED_REGISTRY_PATH -> LIBRARY_DIR / "registry" / "models.json"
  @property VOICE_LIBRARY_DIR -> LIBRARY_DIR / "voices"
  @property ATTACHMENT_DIR -> COMPANION_DATA_ROOT / "attachments"
  @property IMPORT_INBOX_DIR -> COMPANION_DATA_ROOT / "imports" / "inbox"
  @property IMPORT_STAGING_DIR -> COMPANION_DATA_ROOT / "imports" / "staging"
  @property CHARACTER_DIR -> COMPANION_DATA_ROOT / "characters"
  @property MEMORY_DIR -> COMPANION_DATA_ROOT / "memory"

Deprecate: DATA_DIR, MODELS_DIR, LLAMA_MODELS_DIR, hardcoded DATABASE_URL string.

### 8P.3 -- Runtime Engine Configuration

[MODIFY] backend/app/core/config.py -- add:

  LLM_ENGINE: str = "llama_cpp"
  LLM_ACCELERATION: str = "vulkan"
  LLAMA_ENGINE_VERSION: str = "b10936"
  LLAMA_SERVER_URL: str = "http://127.0.0.1:8085/v1"  # Verified port 8085

[MODIFY] llama_cpp.py L56:
  self._engine_version: str = settings.LLAMA_ENGINE_VERSION

### 8P.4 -- Performance Profile Portability

[MODIFY] backend/app/core/config.py -- add:

  # Verified for RX 580 / Vulkan (llama.cpp b10936). Override via env vars.
  PROFILE_ECO_CTX: int = 2048
  PROFILE_ECO_GPU_LAYERS: int = 0         # 0 = CPU-only for Eco
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

[MODIFY] llama_cpp.py _get_profile_params():
  def _get_profile_params(self, profile: str) -> dict:
      p = profile.lower()
      if p == "eco":
          return {n_ctx: ECO_CTX, n_gpu_layers: ECO_GPU, n_threads: ECO_THREADS, mmproj_offload: False}
      elif p == "maximum":
          return {n_ctx: MAX_CTX, n_gpu_layers: MAX_GPU, n_threads: MAX_THREADS, mmproj_offload: True}
      else:  # balanced
          return {n_ctx: BAL_CTX, n_gpu_layers: BAL_GPU, n_threads: BAL_THREADS, mmproj_offload: True}
  (reads from settings.PROFILE_*_* -- removes inline RX 580 constants)

### 8P.5 -- Model Registry Schema (Final -- Schema v3 directly; no v2 intermediate)

[MODIFY] backend/app/schemas/model_registry.py -- complete replacement
  New enums: ModelAssetType, ModelVariant, InputModality, ModelDiscoveryState, ReasoningMode, CapabilityProvenance
  ValidationStatus: add incompatible
  New sub-schemas: CompanionFile (add optional sha256), CompanionArtifactStatus, CapabilityEntry, GenerationDefaults
  ModelManifest / ModelLibraryState / ModelRuntimeHints / ModelRegistryEntry per design above
  Use model_serializer or computed_field for backward-compat flat fields -- NOT @property

[MODIFY] backend/app/services/model_registry.py
  _load_registry_json(): INSTALLED_REGISTRY_PATH first; template fallback
    Path resolution: installed entries -> MODEL_LIBRARY_DIR; factory template entries -> FACTORY_MODEL_ROOT
    Add FACTORY_MODEL_ROOT: Path = settings.BASE_DIR.parent / "models" (or env-overridable)
  _validate_entry(): populate ModelLibraryState
    - missing mmproj: vision removed from available_capabilities; text usable; model NOT prohibited
    - missing primary file: validation_status=missing_primary; model unavailable
  Unregistered scanner: discovery_state=discovered, validation_status=unregistered
    capabilities=[]  (NO auto-assignment)
    input_modalities=[]  (NO default [text])
    model_max_context=None  (NO default 4096)
    runtime_compatibility=[]  (NO default [llama_cpp])
    variant=ModelVariant.unknown
  GGUF metadata extraction (best-effort, non-blocking): populate only fields that are reliably detected
    (architecture, model_max_context, quantization, chat_template) -- never fabricate defaults

[MODIFY] models/registry.template.json -> schema v3; add asset_type, architecture, input_modalities,
  model_max_context, reasoning_mode on all entries; update _note

[MODIFY] frontend/web/src/services/api/registryApi.ts
  Add ModelManifest, ModelLibraryState, ModelRuntimeHints interfaces
  Update RegistryEntry; migrate context_limit -> model_max_context in all consumers

[MODIFY] contracts/openapi/openapi.json -- update /api/v1/models/registry response schema

### 8P.6 -- Canonical Documentation Updates

[MODIFY] AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md
  - Local AI Core -> Local AI Runtime (canonical sections; preserve historical walkthrough wording)
  - Test baseline: 88 pytest, 38 vitest, migration head 005_scope_message_constraints
  - Phase 8 sequence (8A -> 8P -> 8B -> 8C) in delivery roadmap
  - Cross-reference to AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md
  - Model invariants: Qwen = verified defaults not whitelist; capability provenance rules

[MODIFY] LLAMA_CPP_RUNTIME_ARCHITECTURE.md
  - Local AI Core -> Local AI Runtime
  - Correct port 8080 -> 8085 throughout
  - Eco profile: GPU layers = 0 (not 20 as in old table)
  - Remove/label as planned/unverified: flash attention, KV cache quantization, batch/ubatch values
    (these are not currently applied by _get_profile_params())
  - Scope note: general config/storage/manifest rules defer to AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md

[MODIFY] VOICE_AND_AUDIO_ARCHITECTURE.md
  - Local AI Core -> Local AI Runtime
  - Add note: voice/model asset locations defer to AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md section 6.2

[MODIFY] AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md
  - Section 33: rename "Open Decisions" -> "Resolved Decisions"; record OD1/OD2/OD3 resolutions
  - Note: per-library override is a future/deferred feature

[MODIFY] README.md
  - Local AI Core -> Local AI Runtime
  - Backend/database/local runtime: implemented (Phase 7 verified baseline); not "planned"
  - Reflect 88 pytest / 38 vitest; Phase 8 = active delivery

### 8P.2b -- Bootstrap Locator

[CREATE/MODIFY] backend/app/core/startup.py (or config_loader.py):

Bootstrap resolution order (highest priority first):
  1. Explicit env var: COMPANION_DATA_ROOT (if set, use directly -- skip locator)
  2. Bootstrap file: %LOCALAPPDATA%\AI Companion\bootstrap.json
     { "schema_version": 1, "data_root": "D:\\CustomPath\\AI Companion\\Data" }
  3. Default: %LOCALAPPDATA%\AI Companion\Data

Bootstrap file invariants:
  - Contains only schema_version (int) and data_root (str).
  - No user content, secrets, or preferences.
  - If data_root in bootstrap.json is unavailable/invalid: log warning; fall back to default.
  - The bootstrap.json itself is always at the fixed OS path (%LOCALAPPDATA%\AI Companion\bootstrap.json).

  async def resolve_data_root() -> Path:
      if os.environ.get("COMPANION_DATA_ROOT"):              # 1. explicit env override
          return Path(os.environ["COMPANION_DATA_ROOT"])
      bootstrap_path = Path(os.environ.get("LOCALAPPDATA", ...)) / "AI Companion" / "bootstrap.json"
      if bootstrap_path.exists():
          try:
              data = json.loads(bootstrap_path.read_text())
              candidate = Path(data["data_root"])
              if candidate.is_absolute():
                  return candidate                            # 2. bootstrap locator
          except Exception:
              logger.warning("Invalid bootstrap.json; using default data root")
      return default_data_root()                             # 3. default

Tests:
  - Missing locator -> default path used
  - Valid locator with valid absolute path -> locator path used
  - Invalid/corrupt bootstrap.json -> warning logged; default used
  - Unavailable path in bootstrap.json (drive not mounted) -> warning; default used
  - Explicit COMPANION_DATA_ROOT env var -> env var takes precedence over locator and default

### 8P.7 -- First-Run Data Migration

[MODIFY] backend/app/core/startup.py (or equivalent startup hook):

Known legacy candidate locations (check both):
  backend/data/companion.db          (most common: dev server working directory)
  <repo-root>/data/companion.db      (alternative: repo root data/ dir)

  async def ensure_data_root() -> None:
      canonical = settings.DATABASE_PATH
      if canonical.exists():
          return

      repo_root = Path(__file__).resolve().parents[3]       # adjust depth to actual layout
      candidates = [
          repo_root / "backend" / "data" / "companion.db",
          repo_root / "data" / "companion.db",
      ]
      found = [c for c in candidates if c.exists()]

      if len(found) == 0:
          canonical.parent.mkdir(parents=True, exist_ok=True)   # fresh install
      elif len(found) == 1:
          legacy = found[0]
          canonical.parent.mkdir(parents=True, exist_ok=True)
          backup = legacy.with_suffix(".pre-migration-backup.db")
          shutil.copy2(legacy, backup)
          shutil.copy2(legacy, canonical)
          _verify_migrated_db(canonical)                        # verify Alembic head matches
          logger.info(f"Migrated legacy DB from {legacy} -> {canonical}")
      else:
          # Multiple candidates: STOP and report ambiguity; do not choose silently
          raise RuntimeError(
              f"Multiple legacy database candidates found: {found}. "
              "Resolve manually before starting the server."
          )

  _verify_migrated_db(): connect to canonical; run Alembic check to confirm migration head is correct
    (current head: 005_scope_message_constraints; after 8B: 006_add_attachments).
    Alembic DATABASE_URL must derive from settings.DATABASE_PATH -- not from env DATABASE_URL.

Tests:
  - No legacy -> canonical created fresh
  - Exactly one legacy -> copied, verified, backup preserved, restart-safe
  - Multiple differing candidates -> RuntimeError raised with paths listed
  - After migration: Alembic uses settings.DATABASE_PATH (canonical); not the legacy path

### 8P Verification Gate

  grep -r "Local AI Core" frontend/web/src --include="*.tsx" --include="*.ts"  # expected: empty
  grep -r "Local AI Core" backend/ --include="*.py"                             # expected: empty
  python -c "from app.core.config import settings; print(settings.COMPANION_DATA_ROOT)"
  pytest tests/ -v --tb=short   # >= 88 passed
  npm run test                   # >= 38 passed (updated strings)
  npx tsc --noEmit               # 0 errors

### 8P Commit Message

feat(8p): runtime config -- COMPANION_DATA_ROOT, terminology, model schema v3, profile portability

TERMINOLOGY: "Local AI Core" -> "Local AI Runtime" (19 frontend + backend); test assertions updated;
GGUF/Vulkan label fixed; LLAMA_CPP doc port corrected (8085) + profile table corrected;
AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md section 33 -> Resolved Decisions;
README.md implementation status corrected.

CONFIG: COMPANION_DATA_ROOT; DATABASE_PATH derived; LLAMA_SERVER_URL port 8085;
PROFILE_*_* env-overridable (RX 580 defaults preserved); _get_profile_params() reads settings.

SCHEMA v3: ModelManifest + ModelLibraryState + ModelRuntimeHints; new enums; unknown GGUFs capabilities=[];
partial mmproj handling; model_serializer for backward-compat; registryApi.ts updated; openapi.json updated.

MIGRATION: first-run conditional; backup preserved; restart-safe; no LFS changes.

Tests: >= 88 pytest + migration test, >= 38 vitest, 0 tsc.


---

## Phase 8B -- Multimodal Image Attachment Foundation

Branch: feature/multimodal-image-attachments (based on merged 8P)
Test gate: migration 006 applies cleanly; >= 88 + attachment tests; 0 tsc; clean build.
Dependency: settings.ATTACHMENT_DIR (from 8P.2) must exist.

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
  class ImageAttachmentContent: type="image_attachment"; attachment_id: str; mime_type: str
  ContentBlock = Union[TextContent, ImageAttachmentContent]

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

### 8B.6b -- Transactional Attachment Binding

[CREATE/MODIFY] backend/app/services/attachment_service.py (or message_service.py):

When a user message is sent with attachment_ids[], binding must be atomic:

  async def bind_attachments_to_message(
      session, message_id, attachment_ids, owner_id, conversation_id
  ) -> None:
      """Atomically validate and bind staged attachment_ids to a persisted user message.
      Runs inside the same transaction as user message creation.
      """
      if len(attachment_ids) > MAX_ATTACHMENTS_PER_MESSAGE:
          raise ValidationError(f"Exceeds {MAX_ATTACHMENTS_PER_MESSAGE} attachment limit")

      for att_id in attachment_ids:
          att = await session.get(Attachment, att_id)
          # Validation order (all inside the transaction):
          # 1. Exists
          if att is None:
              raise ValidationError(f"Attachment {att_id} not found")
          # 2. Ownership
          if att.owner_id != owner_id:
              raise PermissionError(f"Attachment {att_id} not owned by caller")
          # 3. Same conversation
          if att.conversation_id != conversation_id:
              raise ValidationError(f"Attachment {att_id} belongs to a different conversation")
          # 4. Not deleted
          if att.is_deleted:
              raise ValidationError(f"Attachment {att_id} has been deleted")
          # 5. Staged (unbound): message_id must be NULL
          if att.message_id is not None:
              raise ValidationError(f"Attachment {att_id} is already committed to another message")
          # Bind
          att.message_id = message_id

Rollback invariant: if any validation fails, the transaction rolls back.
Neither partial message creation nor partial attachment bindings survive a failed transaction.

Cancellation invariant: if the assistant-stream generation is cancelled AFTER the user message
and attachments are committed, the user message and all bound attachments remain committed and
visible in history. Only the partial/empty assistant response follows cancellation semantics.

### 8B.7 -- Attachment/Media Resolver & Provider Translation

Canonical boundary:

  Orchestrator
    -> Attachment/Media Resolver (service layer)
       resolves attachment_ids to validated, provider-neutral image resources
    -> LLMProvider interface (ContentBlock[])
       -> LlamaCppProvider._translate_messages() (llama.cpp-specific wire format)

LlamaCppProvider MUST NOT:
  - Construct application attachment paths from attachment IDs directly
  - Query attachment persistence (DB) directly
  - Know about COMPANION_DATA_ROOT or settings.ATTACHMENT_DIR directly
  - Make any assumption about where bytes come from

LlamaCppProvider MUST ONLY:
  - Receive pre-resolved image bytes (or a coroutine that provides them)
  - Translate ContentBlock[] -> llama.cpp chat completions wire format
  - Run file IO via asyncio.run_in_executor (never blocking the event loop)

[CREATE] backend/app/services/assistant/media_resolver.py:
  async def resolve_image_content(block: ImageAttachmentContent) -> bytes:
      """Load and validate image bytes for a single attachment.
      Raises on missing file, path traversal, or oversized read.
      Called by orchestrator before passing ContentBlocks to LLMProvider."""

[MODIFY] backend/app/services/assistant/orchestrator.py:
  # Gate on library state (available_capabilities) -- not manifest.capabilities
  has_vision = (
      active_entry is not None
      and ModelCapability.vision in active_entry.library_state.available_capabilities
  )

  if has_vision and committed_attachments:
      # Resolve image bytes via media_resolver (before calling provider)
      content_blocks: List[ContentBlock] = []
      for att in committed_attachments:
          if not att.is_deleted:
              content_blocks.append(ImageAttachmentContent(att.id, att.mime_type))
      content_blocks.append(TextContent(text=user_text))
      chat_message = ChatMessage(role="user", content=content_blocks)
  else:
      chat_message = ChatMessage(role="user", content=user_text)

[MODIFY] backend/app/services/llm/llama_cpp.py -- add _translate_messages():
  Receives ContentBlock[] from orchestrator (bytes already resolved by media_resolver).
  Does NOT access filesystem paths or attachment IDs directly.
  Encodes image bytes as data:{mime_type};base64,{b64} in image_url wire format.
  All IO (if any) via run_in_executor (non-blocking).

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
- schemas/multimodal.py: TextContent, ImageAttachmentContent, ContentBlock
- schemas/llm.py: ChatMessage.content Union[str, List[ContentBlock]]
- schemas/message.py: attachment_ids[] + attachments[]
- attachment_validator.py: Pillow, byte-header MIME, dimensions, megapixel, bomb
- endpoints/attachments.py: POST/preview/DELETE; path traversal guard
- orchestrator.py: vision gate via available_capabilities; provider-independent content
- llama_cpp.py: _translate_messages(); file IO via run_in_executor
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

[MODIFY] AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md
  - Test totals: 100+ pytest, 50+ vitest
  - Mark Phase 8 complete

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
- AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md: 100+/50+ counts; Phase 8 complete
- task.md: sprint archived

---

## Deferred / Out of Scope

  WebP support          -- deferred; not verified with pinned llama.cpp/Qwen3-VL
  Video/audio/PDF       -- out of scope
  Android multimodal    -- deferred
  CUDA implementation   -- out of scope; boundary documented only
  Model Import Manager  -- deferred (separate planning phase)
  MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md -- deferred until Import Manager planned
  Auto HuggingFace downloads / quantization  -- deferred
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
