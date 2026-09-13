# Phase 8 Implementation Plan — PC Frontend Architecture, Multimodal & Polish

> **Implementer:** Gemini
> **Planner:** Antigravity (evidence-backed, correction passes 1 + 2 applied)
> **Status:** Draft — awaiting final architecture review
> **Branch Strategy:** 4 sequential feature branches (see Section 1)
> **Do not implement until user issues APPROVED signal**

---

## Correction Summary — Pass 2 (applied over Pass 1 — do not revert either pass)

| # | Issue | Correction |
|---|-------|-----------|
| 17 | 8A–8B plan did not include terminology reconciliation | Phase 8P inserted between 8A and 8B |
| 18 | No configurable data root — paths hardcoded in `config.py` | 8P defines `COMPANION_DATA_ROOT` as configurable persistent root |
| 19 | Profiles hardcoded as RX 580 constants in `_get_profile_params()` | 8P establishes profiles as machine-configurable presets; current values remain as `rx580_vulkan` defaults |
| 20 | `MODELS_DIR` uses `vision/` subdirectory — implied "vision model" organization | 8P renames model storage to family-based layout, not capability-based |
| 21 | Registry template has no model from other families — implied Qwen-only | 8P clarifies Qwen entries are factory defaults, not a whitelist; scan/discovery preserved |
| 22 | `Local AI Core` used in 19+ frontend locations | 8P reconciles to `Local AI Runtime` in code/UI; canonical docs updated |
| 23 | No runtime engine configuration boundary | 8P defines runtime engine config conceptually (engine, acceleration, build, binary, capabilities) |
| 24 | Configuration domains undocumented | 8P formalizes config classification per domain |
| 25 | No attachment storage under `COMPANION_DATA_ROOT` yet | 8B storage path updated to reference `COMPANION_DATA_ROOT/attachments/` established in 8P |
| 26 | Voice assets have no architectural home | 8P defines voice library under `COMPANION_DATA_ROOT` |

---

## Section 1 — Branch Strategy (Revised)

### Execution Order

```
develop  (baseline: 88 pytest, 38 vitest, 0 tsc, migration head 005_scope_message_constraints)
    │
    ├── feature/phase8-ui-foundation       (8A — frontend only, zero backend schema changes)
    │       ↓ merge to develop
    ├── feature/phase8-runtime-config      (8P — config, terminology, data root, registry template)
    │       Based on merged 8A
    │       ↓ merge to develop
    ├── feature/multimodal-image-attachments  (8B — full stack, based on merged 8P)
    │       ↓ merge to develop
    └── feature/phase8-ui-integration-polish  (8C — polish, cleanup, final tests)
            Based on merged 8B
```

> **Why 8P is between 8A and 8B:** 8B introduces `COMPANION_DATA_ROOT/attachments/` for attachment storage. 8P must first establish and verify `COMPANION_DATA_ROOT` in config before 8B writes files relative to it. 8A is frontend-only and unaffected by 8P's backend config changes.

### Why 4 Branches is Better Than 3

| Addition | Risk type | Isolation value |
|----------|-----------|----------------|
| 8P terminolology changes | Wide surface (19+ files) but low logic risk | Isolates bulk renaming from attachment logic in 8B |
| 8P config restructure | Backend config touches everything | Verified independently before 8B's migration 006 relies on it |

---

## Section 2 — Repository Evidence

*(unchanged from Pass 1 — supplemented below)*

| Additional Finding | File | Classification |
|-------------------|------|----------------|
| `PROJECT_NAME = "Local AI Runtime"` in backend | `config.py` L27 | Correct — canonical backend term |
| `Local AI Core` in 19 frontend locations | `AssistantView.tsx`, `Header.tsx`, `HomeView.tsx`, `ModelsView.tsx`, `HealthView.tsx`, others | **Technical Debt / Terminology Inconsistency** |
| Profile params hardcoded: eco=(0 layers), balanced=(28 layers), maximum=(33 layers) | `llama_cpp.py` L151–164 | **Technical Debt — RX 580 constants, not portable** |
| `MODELS_DIR = BASE_DIR.parent / "models"` with `vision/` subdirectory | `config.py` L57–58 | **Technical Debt — capability-based dir naming** |
| `registry.template.json` Qwen-only but `_resolve_model_path` already scans all `.gguf` | `llama_cpp.py` L141–147 | Scan exists; registry template implied whitelist — clarify |
| `DATA_DIR = BASE_DIR.parent / "data"` — not user-configurable root | `config.py` L48 | **Product Improvement — needs `COMPANION_DATA_ROOT`** |
| No `COMPANION_DATA_ROOT` env var in `.env.example` or `config.py` | Repository-wide | **Confirmed Gap** |


---

## Section 3 — Phase 8A: Frontend Architecture & UX Harmonization

*(unchanged from Pass 1 correction — reproduced in full for completeness)*

**Branch:** `feature/phase8-ui-foundation`
**Test gate:** >= 88 pytest (unchanged), >= 38 vitest, 0 tsc errors, clean build.
**Constraint:** Zero backend schema changes. Zero DB migrations. Zero new API endpoints.

> **Terminology note:** 8A does NOT rename "Local AI Core" strings — that happens in 8P, after 8A merges.
> Gemini must not pre-emptively rename terminology in 8A. Doing so would create merge conflicts with 8P.

### Disposition Review

| Area | Disposition | Evidence |
|------|-------------|---------|
| HomeView mock greeting | **Implement in 8A** | `HomeView.tsx` L33 imports `mock/multilingualData.ts` |
| AssistantView mockConversations | **Implement in 8A** | Stale import L49; `drawerConversations` already real |
| HealthView mock data | **Implement in 8A** | Wire to `BackendContext.isOnline` + `modelStatus` |
| MemoryView mock data | **Implement in 8A** | Wire to `memoryApi` live data |
| Models progressive disclosure | **Implement in 8A** | Variant badges, applied-vs-requested labels, mmproj warning |
| AssistantView decomposition | **Implement in 8A** | 927-line monolith → 4 sub-components |
| Navigation / info hierarchy | **Keep as-is** | Functional and Phase 7 verified |
| Settings organization | **Keep as-is** | No mock data found; no redesign justified |
| Responsive PC layout | **Keep as-is** | PC-first scope; Phase 7 verified |
| State ownership | **Keep as-is** | BackendContext + hooks adequate |
| Accessibility baseline | **Defer to 8C** | Tracked in 8C.3 |

### Batch 8A.1 — Mock Data Removal from Production Views

**[MODIFY]** `frontend/web/src/components/workspace/HomeView.tsx`
- Remove `import { getLanguageAwareGreeting } from '../../mock/multilingualData'` (L33)
- Replace with time-derived greeting (e.g. `const h = new Date().getHours(); const greeting = h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'`)

**[MODIFY]** `frontend/web/src/components/workspace/AssistantView.tsx`
- Remove `import { mockConversations } from './ConversationHistoryDrawer'` (L49)

**[MODIFY]** `frontend/web/src/components/workspace/HealthView.tsx`
- Replace mock imports with `BackendContext.isOnline`, `BackendContext.modelStatus`
- Add explicit offline/degraded banner

**[MODIFY]** `frontend/web/src/components/workspace/MemoryView.tsx`
- Wire to `memoryApi` live data; show loading/empty states

**Verification:**
```powershell
grep -r "from '.*mock/" frontend/web/src --include="*.tsx" --include="*.ts" -l
# Expected: only test files
```

### Batch 8A.2 — AssistantView Decomposition

**New files (`workspace/assistant/`):**
- `AssistantComposer.tsx` — input, send, stop, mic stub; Paperclip **disabled** with `title="Image attachments enabled in Phase 8B"` (removes fake `doc_spec_v1.md` behavior)
- `AssistantMessageList.tsx` — scrollable messages + auto-scroll
- `AssistantStatusBar.tsx` — provenance-labeled telemetry only (measured/configured/estimated/unavailable); amber "Profile change pending restart" when `applied_profile !== requested_profile`
- `AssistantErrorDisplay.tsx` — `classifyStreamError` logic extracted

**[MODIFY]** `AssistantView.tsx` → orchestrator: state + callbacks; composes the four sub-components.

### Batch 8A.3 — Models Progressive Disclosure

**[MODIFY]** `ModelsView.tsx`
- Variant badges from `BackendContext.registry`
- Missing companion file (mmproj) warning badge
- Applied-vs-requested profile labels

### Batch 8A.4 — Deprecation Annotations

Add `@deprecated` JSDoc to mock file headers; do not delete files.

### 8A Proposed Commit Message

```
feat(8a): frontend architecture — mock removal, view decomposition, provenance labels

- HomeView: remove mock/multilingualData; time-derived greeting
- AssistantView: remove stale mockConversations import
- AssistantView: extract Composer (stub attach), MessageList, StatusBar (provenance), ErrorDisplay
- HealthView, MemoryView: wired to live BackendContext / memoryApi
- ModelsView: variant badges, mmproj warning, applied-vs-requested profile labels
- mock/*.ts: @deprecated annotations; retained as test fixtures
- Terminology: NOT renamed in 8A — rename happens in 8P

Tests: >= 88 pytest, >= 38 vitest, 0 tsc, clean build
```


---

## Section 4 — Phase 8P: Runtime Configuration & Persistent Asset Foundation

**Branch:** `feature/phase8-runtime-config` (based on merged 8A)
**Test gate:** >= 88 pytest (all still pass after config changes), >= 38 vitest, 0 tsc errors, clean build.
**Constraint:** No DB migrations. No new API endpoints. No new frontend pages. Backend and frontend naming/config changes only.

> **Critical prerequisite for 8B:** 8B writes attachment files to `COMPANION_DATA_ROOT/attachments/`. 8P must establish and verify that path before 8B begins.

---

### Batch 8P.1 — Canonical Terminology Reconciliation

**Canonical term map (enforce across code, UI, docs):**

| Context | Canonical term | Retired term |
|---------|---------------|-------------|
| Product / ecosystem | AI Companion | — |
| Backend service / process | Local AI Runtime | Local AI Core |
| Runtime engine | llama.cpp (configurable) | — |
| Acceleration backend | Vulkan (current) / CUDA (future) | — |
| Character/persona | Configurable name (e.g. Lisa) | Aura (do not use as product identity) |
| Model library | GGUF model library | — |
| Config root | COMPANION_DATA_ROOT | — |

**Important non-conflation rules (must be surfaced in UI labels):**
- `GGUF model` ≠ `Vulkan model` (Vulkan is a runtime acceleration property, not a model property)
- `GGUF model` ≠ `CUDA model` (same — CUDA remains future/unverified)
- Capability (`vision`, `reasoning`) ≠ acceleration backend

---

#### 8P.1a — Backend Terminology

**[MODIFY]** `backend/app/core/config.py`
- `PROJECT_NAME` is already `"Local AI Runtime"` ✓ — no change needed
- Add code comment: `# Canonical term: "Local AI Runtime" (previously "Local AI Core" in docs — reconciled in Phase 8P)`

**[MODIFY]** `backend/app/main.py` (or wherever FastAPI app title is set)
- Ensure `title="Local AI Runtime"` matches `settings.PROJECT_NAME`

**Grep and fix remaining backend occurrences:**
```powershell
grep -r "Local AI Core" backend/ --include="*.py" -l
# Fix each occurrence — replace with "Local AI Runtime"
```

---

#### 8P.1b — Frontend Terminology

**Known occurrences (from repository evidence — 19 locations):**

| File | Lines | Current text | Replace with |
|------|-------|-------------|-------------|
| `AssistantView.tsx` | L93 | `"Local AI Core is offline. Ensure Local AI Core is running on :8000"` | `"Local AI Runtime is offline. Ensure Local AI Runtime is running on :8000"` |
| `AssistantView.tsx` | L241 | `"Local AI Core session initialized..."` | `"Local AI Runtime session initialized..."` |
| `AssistantView.tsx` | L248 | `"Connect to Local AI Core on port 8000"` | `"Connect to Local AI Runtime on port 8000"` |
| `Header.tsx` | L254 | `Local AI Core` (label) | `Local AI Runtime` |
| `Header.tsx` | L343 | comment `Local AI Core & VRAM Status Badges` | update comment |
| `HomeView.tsx` | L168 | `"Local AI Core Online"` | `"Local AI Runtime Online"` |
| `HealthView.tsx` | L121 | description text | `"Local AI Runtime"` |
| `HealthView.tsx` | L180 | comment | update comment |
| `ModelsView.tsx` | L337 | label `Local AI Core:` | `Local AI Runtime:` |
| `ModelProvidersCard.tsx` | L34 | description | `"Local AI Runtime orchestrates..."` |
| `ApplicationStatesShowcase.tsx` | L330, L346, L358 | state labels | `"Local AI Runtime Offline"` / `"Local AI Runtime Inactive"` / `"Start Local AI Runtime"` |
| `HealthPipelineCard.tsx` | L138 | comment/diagram | update |
| `mock/healthData.ts` | L91, L336 | mock strings | update for consistency |

**[MODIFY]** `frontend/web/src/test/assistantViewReliability.test.tsx`
- L544, L613, L666: update test string assertions to match new `"Local AI Runtime"` message text

> **Test update is mandatory** — these tests assert on the exact error message string. After rename, tests will fail if not updated.

**GGUF/Vulkan label correction in ModelsView:**
- Any badge, tooltip, or label that currently implies models are "Vulkan models" must be corrected
- GGUF files are runtime-agnostic; Vulkan is a property of the running engine binary
- Labels should read: `GGUF` (file format), `Engine: llama.cpp`, `Acceleration: Vulkan` (separate fields in the runtime info panel)

---

### Batch 8P.2 — COMPANION_DATA_ROOT Configuration

**Design intent:** One configurable persistent root that owns all user/machine assets. Application binaries and runtime engines remain outside this root. The root can be moved without rewriting application code.

**Configuration classification for every field in `config.py`:**

| Setting | Domain | Class |
|---------|--------|-------|
| `PROJECT_NAME` | Application | Built-in default |
| `HOST`, `PORT` | Network | Machine config |
| `ENVIRONMENT`, `DEBUG` | Application | Environment/developer override |
| `COMPANION_API_KEY` | Security | Secret (OS-backed storage in future) |
| `CORS_ORIGINS` | Network/Security | Machine config |
| `COMPANION_DATA_ROOT` | Storage | **NEW** — Persistent machine config |
| `DATABASE_URL` | Storage | Derived from `COMPANION_DATA_ROOT` |
| `DATA_RETENTION_DAYS` | Storage | Persistent user config |
| `RUNTIME_DIR` | Runtime | Machine config |
| `LLAMA_CPP_BIN_DIR` | Runtime | Machine config |
| `LLM_PROVIDER` | Runtime | Machine config |
| `LLM_PROFILE` | Performance | Persistent user config |
| `LLM_IDLE_TIMEOUT_SECONDS` | Performance | Persistent user config |
| `LLAMA_ROUTER_PORT` | Runtime/Network | Machine config |
| `CONVERSATION_HISTORY_LIMIT` | Application | Persistent user config |
| `MEMORY_SEARCH_LIMIT` | Application | Persistent user config |

**Rule:** Secrets (`COMPANION_API_KEY`) must remain separate from portable config. Design for future OS-backed secure storage (Windows DPAPI / Credential Manager), but keep `.env` for Phase 8 implementation.

---

**[MODIFY]** `backend/app/core/config.py`

Replace current scattered path constants with `COMPANION_DATA_ROOT`-relative layout:

```python
# Persistent asset root — all user/machine data lives here.
# Configurable via COMPANION_DATA_ROOT env var.
# Default: sibling of repository root (preserves current behavior).
# Application binaries and runtime engines are NOT stored here.
COMPANION_DATA_ROOT: Path = Field(
    default=BASE_DIR.parent / "data",
    description="Root directory for all persistent companion data and assets."
)

# Derived paths — relative to COMPANION_DATA_ROOT
# Override individually via env var only when per-library path isolation is needed
# (e.g. model library on a separate drive)
@property
def DATA_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT

@property
def MODEL_LIBRARY_DIR(self) -> Path:
    """GGUF model library root. Not named 'vulkan' or 'cuda' — runtime-agnostic."""
    return self.COMPANION_DATA_ROOT / "models"

@property
def VOICE_LIBRARY_DIR(self) -> Path:
    """Voice/TTS/STT asset library. Binaries remain in RUNTIME_DIR."""
    return self.COMPANION_DATA_ROOT / "voices"

@property
def CHARACTER_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "characters"

@property
def ATTACHMENT_DIR(self) -> Path:
    """Used by Phase 8B attachment storage."""
    return self.COMPANION_DATA_ROOT / "attachments"

@property
def MEMORY_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "memory"

@property
def IMPORT_STAGING_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "staging"
```

> **Backward-compatibility:** `DATA_DIR` property continues to resolve to `COMPANION_DATA_ROOT`, so all existing code using `settings.DATA_DIR` continues to work unchanged.

> **MODELS_DIR migration:** `settings.MODELS_DIR` and `settings.LLAMA_MODELS_DIR` must be deprecated in favor of `settings.MODEL_LIBRARY_DIR`. Audit all usages and update.

---

### Batch 8P.3 — Model Library Path Reconciliation

**Current problem:** `LLAMA_MODELS_DIR = BASE_DIR.parent / "models" / "vision"` — the `vision/` subdirectory implies the model library is organized by capability. Models should be organized by family, not capability.

**Registry template path pattern:** `"primary_file": "vision/qwen3-vl-2b-instruct/..."` — this `vision/` prefix is a family-based subdirectory that happens to be named `vision` (Qwen3-VL is a vision model family). This is acceptable only if we are clear it is family-based, not capability-based.

**Proposed clarification (document, not immediately rename filesystem):**
- Document in `registry.template.json` `_note` field: paths are relative to `MODEL_LIBRARY_DIR`; the `vision/` directory is a model family grouping, not an acceleration or capability filter
- New GGUF imports for non-vision models use a different family directory (e.g. `text/`, `code/`, or the model family name)
- Update `config.py`: deprecate `LLAMA_MODELS_DIR`; use `settings.MODEL_LIBRARY_DIR` everywhere

**[MODIFY]** `models/registry.template.json`
```json
{
  "_schema_version": "2",
  "_note": "Copy to models/registry.json (gitignored). Paths are relative to MODEL_LIBRARY_DIR (COMPANION_DATA_ROOT/models/). The 'vision/' subdirectory is a model family grouping, not an acceleration backend label. GGUF files are runtime-engine-agnostic — the same file works with Vulkan or future CUDA llama.cpp builds. Qwen3-VL entries are factory defaults, not a whitelist. Add any compatible GGUF model here.",
  "models": [ ... existing entries unchanged ... ]
}
```

**Clarify scan/discovery behavior in `llama_cpp.py` docstring:**
- `_resolve_model_path()` (L141–147) already scans all `.gguf` files > 100MB — this is correct
- Add docstring note: scan is intentional; user-imported GGUFs not in `registry.json` can still be loaded by path; capabilities must be explicitly declared in registry — never inferred from filename

---

### Batch 8P.4 — Runtime Engine Configuration Boundary

**Define conceptually (document, not yet implement):**

A runtime engine configuration object should eventually describe:
```
engine:          llama.cpp           (configurable: future Ollama, vLLM, etc.)
acceleration:    vulkan              (vulkan | cuda | cpu | future)
build_version:   b10936              (pinned llama-server binary version)
binary_path:     runtime/llama.cpp/  (RUNTIME_DIR / engine)
capabilities:    [text, vision, ...]  (derived from engine + acceleration combo)
platform:        windows             (windows | linux | macos)
```

**Phase 8P implementation scope (document + config only, not new API):**
- Add `LLM_ENGINE: str = "llama_cpp"` to `config.py` (future extensibility hook)
- Add `LLM_ACCELERATION: str = "vulkan"` to `config.py` as a declarative property
- Add `LLAMA_ENGINE_VERSION: str = "b10936"` — pinned build version, currently hardcoded in `llama_cpp.py` L56

**CUDA is OUT OF SCOPE for Phase 8.** Only the conceptual boundary and documentation are added here. The `LLM_ACCELERATION` field is a declaration, not an implementation.

---

### Batch 8P.5 — Performance Profile Portability

**Current problem:** `_get_profile_params()` hardcodes:
- eco: `n_gpu_layers=0, n_ctx=2048, n_threads=4`
- balanced: `n_gpu_layers=28, n_ctx=4096, n_threads=6`
- maximum: `n_gpu_layers=33, n_ctx=8192, n_threads=8`

These are RX 580 / Vulkan-specific constants, but are presented as universal profile definitions.

**Correction — Phase 8P design (document + config only):**

The profiles should be interpreted as machine-configured presets that map to technical parameters for the current machine/runtime. The current values are correct and verified for the RX 580 / Vulkan machine — they should remain as the machine defaults.

**[MODIFY]** `backend/app/core/config.py` — add profile override hooks:
```python
# Performance profiles — current values verified for RX 580 / Vulkan (llama.cpp b10936)
# Override via env vars for different hardware
PROFILE_ECO_CTX: int = 2048
PROFILE_ECO_GPU_LAYERS: int = 0
PROFILE_ECO_THREADS: int = 4
PROFILE_BALANCED_CTX: int = 4096
PROFILE_BALANCED_GPU_LAYERS: int = 28    # RX 580 default; override for other GPUs
PROFILE_BALANCED_THREADS: int = 6
PROFILE_MAXIMUM_CTX: int = 8192
PROFILE_MAXIMUM_GPU_LAYERS: int = 33     # RX 580 max; override for other GPUs
PROFILE_MAXIMUM_THREADS: int = 8
```

**[MODIFY]** `backend/app/services/llm/llama_cpp.py` — `_get_profile_params()`:
```python
def _get_profile_params(self, profile: str) -> Dict[str, Any]:
    """
    Map named profile to runtime parameters.
    Current defaults are verified for RX 580 / Vulkan (llama.cpp b10936).
    Override via PROFILE_*_* environment variables for other hardware.
    Eco/Balanced/Maximum are execution presets, not universal hardware constants.
    """
    p = profile.lower()
    if p == "eco":
        return {
            "n_ctx": settings.PROFILE_ECO_CTX,
            "n_gpu_layers": settings.PROFILE_ECO_GPU_LAYERS,
            "n_threads": settings.PROFILE_ECO_THREADS,
            "mmproj_offload": False,
        }
    elif p == "maximum":
        return {
            "n_ctx": settings.PROFILE_MAXIMUM_CTX,
            "n_gpu_layers": settings.PROFILE_MAXIMUM_GPU_LAYERS,
            "n_threads": settings.PROFILE_MAXIMUM_THREADS,
            "mmproj_offload": True,
        }
    else:  # balanced
        return {
            "n_ctx": settings.PROFILE_BALANCED_CTX,
            "n_gpu_layers": settings.PROFILE_BALANCED_GPU_LAYERS,
            "n_threads": settings.PROFILE_BALANCED_THREADS,
            "mmproj_offload": True,
        }
```

> **Behavioral invariant:** Verified RX 580 values remain the defaults. No behavior change for existing hardware.

---

### Batch 8P.6 — Canonical Architecture Document Update

**[MODIFY]** `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`
- Replace all `Local AI Core` with `Local AI Runtime` where referring to the backend service
- Add terminology glossary section: AI Companion / Local AI Runtime / llama.cpp engine / Vulkan acceleration / GGUF model / COMPANION_DATA_ROOT
- Update config section to reflect `COMPANION_DATA_ROOT` and profile overrides
- Do NOT rewrite historical walkthrough evidence — update architecture/current-state sections only

**[MODIFY]** `docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`
- Replace stale `Local AI Core` references
- Add section: "Runtime Engine Configuration Boundary" — conceptual description per 8P.4
- Clarify GGUF files are runtime-agnostic (same file works on Vulkan or future CUDA build)

**[MODIFY]** `README.md` (L5 — "development status")
- Remove stale "FastAPI backend... are planned" — backend is already implemented through Phase 7
- Update development status to reflect verified Phase 7 state

---

### 8P Test Gate

```powershell
# Confirm terminology replacement is complete:
grep -r "Local AI Core" frontend/web/src --include="*.tsx" --include="*.ts" -l
# Expected: empty (or only historical comments clearly marked)

grep -r "Local AI Core" backend/ --include="*.py" -l
# Expected: empty

# Config sanity check — COMPANION_DATA_ROOT resolves correctly:
cd backend
.venv\Scripts\python -c "from app.core.config import settings; print(settings.COMPANION_DATA_ROOT); print(settings.MODEL_LIBRARY_DIR); print(settings.ATTACHMENT_DIR)"

# All tests still pass:
.venv\Scripts\pytest tests/ -v --tb=short
# Expected: >= 88 passed

cd frontend/web
npm run test          # >= 38 passed (updated test strings for renamed error messages)
npx tsc --noEmit      # 0 errors
```

---

### 8P Proposed Commit Message

```
feat(8p): runtime config foundation — COMPANION_DATA_ROOT, terminology, profile portability

TERMINOLOGY:
- Rename "Local AI Core" → "Local AI Runtime" across all frontend files (19 locations)
- AssistantView, Header, HomeView, HealthView, ModelsView, AppStatesShowcase, HealthPipelineCard, etc.
- Update assistantViewReliability.test.tsx string assertions to match
- Backend: config.py already has PROJECT_NAME = "Local AI Runtime" — add reconciliation comment
- GGUF/Vulkan labels corrected in ModelsView: GGUF is file format, Vulkan is engine acceleration

CONFIG:
- config.py: add COMPANION_DATA_ROOT (default: backward-compatible BASE_DIR.parent/data)
- config.py: DATA_DIR, MODEL_LIBRARY_DIR, VOICE_LIBRARY_DIR, CHARACTER_DIR, ATTACHMENT_DIR,
  MEMORY_DIR, IMPORT_STAGING_DIR as COMPANION_DATA_ROOT-relative properties
- config.py: LLM_ENGINE="llama_cpp", LLM_ACCELERATION="vulkan", LLAMA_ENGINE_VERSION="b10936"
- config.py: PROFILE_ECO/BALANCED/MAXIMUM_* env-overridable constants (RX 580 defaults preserved)
- llama_cpp.py: _get_profile_params() reads from settings.PROFILE_* (behavior unchanged)
- Deprecate LLAMA_MODELS_DIR → MODEL_LIBRARY_DIR

REGISTRY:
- registry.template.json: _schema_version 2, clarifying _note (family dirs, GGUF runtime-agnostic,
  Qwen entries are factory defaults not whitelist)

DOCS:
- AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md: terminology + COMPANION_DATA_ROOT + glossary
- LLAMA_CPP_RUNTIME_ARCHITECTURE.md: terminology + runtime engine config boundary section
- README.md: update development status to reflect Phase 7 verified state

Tests: >= 88 pytest, >= 38 vitest (updated strings), 0 tsc, clean build
```


---

## Section 5 — Phase 8B: Multimodal Image Attachment Foundation

*(unchanged from Pass 1 correction except: attachment storage path now uses `settings.ATTACHMENT_DIR` from COMPANION_DATA_ROOT, established in 8P)*

**Branch:** `feature/multimodal-image-attachments` (based on merged 8P)
**Test gate:** Migration 006 applies cleanly; >= 88 + new tests pass; 0 tsc; clean build.
**Dependency on 8P:** `settings.ATTACHMENT_DIR` must exist (established in 8P.2) before 8B writes files.

**Storage path update from 8P:**
```python
# 8B endpoint writes to:
settings.ATTACHMENT_DIR / owner_id / conversation_id / attachment_id
# i.e. COMPANION_DATA_ROOT/attachments/{owner_id}/{conversation_id}/{attachment_id}
# (not DATA_DIR/attachments/ as written in Pass 1 — DATA_DIR is now an alias for COMPANION_DATA_ROOT)
```

All other 8B content (migration 006, ORM model, schemas, validator, endpoints, orchestrator, provider translation, frontend) is unchanged from Pass 1 correction. Refer to the Pass 1 correction summary for full 8B details.

> **Full 8B batch list (8B.1 through 8B.15) is unchanged — see task.md checklist.**

### 8B Proposed Commit Message (updated)

```
feat(8b): multimodal image attachment foundation

(Same as Pass 1 correction commit message, with storage path updated:)
- Attachment storage: COMPANION_DATA_ROOT/attachments/{owner_id}/{conversation_id}/{id}/
  (COMPANION_DATA_ROOT established in 8P; settings.ATTACHMENT_DIR used throughout)
- All other 8B changes per Pass 1 correction

Track: Phase 8B — Multimodal Image Attachment Foundation
```

---

## Section 6 — Phase 8C: Integration, Accessibility & Polish

*(unchanged from Pass 1 correction)*

**Branch:** `feature/phase8-ui-integration-polish` (based on merged 8B)
**Test gate:** Final targets: 100+ pytest, 50+ vitest. All mock imports gone. Clean build.

Full 8C batch list (8C.1 through 8C.5) is unchanged from Pass 1 correction.

---

## Section 7 — Deferred / Out of Scope (Updated)

| Item | Classification | Evidence |
|------|---------------|---------|
| WebP image support | Deferred until live Qwen3-VL verification | Not yet tested in pinned llama.cpp path |
| Video input | Deferred | Phase 2 image only; video requires frame extraction |
| PDF / OCR | Out of scope | temp.txt constraint |
| Audio upload / STT / TTS | Out of scope | temp.txt constraint |
| Android multimodal UI | Deferred | PC-first scope constraint |
| CUDA acceleration backend | Out of scope for Phase 8 | Conceptual boundary defined in 8P; no implementation |
| Model import service (full pipeline) | Deferred | 8P defines architecture; staging→validation→install is future sprint |
| Voice import pipeline | Deferred | 8P defines voice library root; import service is future sprint |
| OS-backed secret storage (DPAPI) | Deferred | API key stays in `.env` for Phase 8; DPAPI design documented |
| Per-library path override (model on second drive) | Deferred | COMPANION_DATA_ROOT established; per-override is future config |

---

## Section 8 — Non-Negotiable Invariants (Updated)

1. **Backend runtime authority** — frontend never computes model state
2. **selected model ≠ active model** — preserved throughout
3. **requested profile ≠ applied profile** — both displayed with explicit labels
4. **MODEL_SLEEPING semantics** — correctly shown in AssistantStatusBar
5. **storage_path never returned** — `AttachmentOut` / `AttachmentRef` have no storage path field
6. **No base64 in messages.content** — attachment bytes in filesystem; DB stores metadata only
7. **CASCADE ≠ soft-delete** — service layer explicitly soft-deletes attachments when parent soft-deleted
8. **All original 88 pytest tests pass** after every branch merge
9. **No git add / commit / push by Gemini** — user commits manually
10. **Provider independence** — orchestrator uses `ContentBlock` types; provider translates
11. **GGUF ≠ Vulkan/CUDA** — file format and acceleration are distinct; never conflate in UI labels
12. **Profile portability** — RX 580 defaults preserved; `_get_profile_params()` reads from settings
13. **COMPANION_DATA_ROOT backward-compatible** — default equals current `data/` path; no migration needed

---

## Section 9 — Updated task.md Checklist

```markdown
## Active Checklist — Phase 8

### 8A — Frontend Architecture & UX Harmonization
- [ ] 8A.1: Mock removal — HomeView, AssistantView, HealthView, MemoryView
- [ ] 8A.2: AssistantView decomposition — Composer (stub), MessageList, StatusBar (provenance), ErrorDisplay
- [ ] 8A.3: Models progressive disclosure — variant badges, mmproj warning, profile labels
- [ ] 8A.4: @deprecated annotations on mock/*.ts

### 8P — Runtime Configuration & Persistent Asset Foundation
- [ ] 8P.1a: Backend — grep and fix remaining "Local AI Core" in .py files; add reconciliation comment to config.py
- [ ] 8P.1b: Frontend — rename "Local AI Core" → "Local AI Runtime" in all 19 locations
- [ ] 8P.1c: Frontend tests — update assistantViewReliability.test.tsx string assertions
- [ ] 8P.1d: ModelsView — fix GGUF/Vulkan label conflation; separate GGUF / Engine / Acceleration fields
- [ ] 8P.2: config.py — COMPANION_DATA_ROOT + derived path properties (DATA_DIR, MODEL_LIBRARY_DIR, ATTACHMENT_DIR, etc.)
- [ ] 8P.3: registry.template.json — _schema_version 2, clarifying _note; deprecate LLAMA_MODELS_DIR usages
- [ ] 8P.4: config.py — LLM_ENGINE, LLM_ACCELERATION, LLAMA_ENGINE_VERSION declarative fields
- [ ] 8P.5: config.py + llama_cpp.py — PROFILE_*_* env-overridable constants; _get_profile_params() reads from settings
- [ ] 8P.6: Canonical docs update — AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md, LLAMA_CPP_RUNTIME_ARCHITECTURE.md, README.md

### 8B — Multimodal Image Attachment Foundation
- [ ] 8B.1: Migration 006_add_attachments.py
- [ ] 8B.2: Attachment ORM — 4 mixins, UUID storage path
- [ ] 8B.3: Conversation + Message models — back_populates="attachments"
- [ ] 8B.4: schemas/attachment.py — AttachmentOut (no storage_path), AttachmentRef
- [ ] 8B.5: schemas/multimodal.py — TextContent, ImageAttachmentContent (provider-independent)
- [ ] 8B.6: schemas/llm.py — ChatMessage.content Union[str, List[ContentBlock]]
- [ ] 8B.7: services/attachment_validator.py — Pillow, byte-header MIME, dims, megapixel, decompression bomb
- [ ] 8B.8: endpoints/attachments.py — upload, authenticated preview, soft-delete; ATTACHMENT_DIR security
- [ ] 8B.9: Orchestrator — provider-independent content_blocks + vision gate
- [ ] 8B.10: LlamaCppProvider — _translate_messages(), file IO via run_in_executor
- [ ] 8B.11: conversationApi.ts — attachment_ids[] in streamSendMessage
- [ ] 8B.12: attachmentApi.ts — uploadAttachment, deleteAttachment, fetchAttachmentBlobUrl
- [ ] 8B.13: AssistantComposer — real file input, Blob previews, vision gate, remove→DELETE
- [ ] 8B.14: ConversationMessageItem — authenticated Blob previews for history
- [ ] 8B.15: GET messages — AttachmentRef[] returned; F5 reload restores previews

### 8C — Integration, Accessibility & Polish
- [ ] 8C.1: Delete deprecated mock files (grep first)
- [ ] 8C.2: Bundle analysis + lazy-load if warranted
- [ ] 8C.3: Accessibility — aria-labels, role=article, focus, keyboard
- [ ] 8C.4: Final test suite — 100+ pytest, 50+ vitest
- [ ] 8C.5: Walkthrough + MASTER_IMPLEMENTATION_PLAN + archive
```

---

### Batch 8P.7 — Model Library & Manifest Contract

**Canonical architecture document:** Create `docs/04_Architecture/MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md`
**Backend schema changes:** Evolve `backend/app/schemas/model_registry.py` and `backend/app/services/model_registry.py`
**Registry template:** Update `models/registry.template.json` to schema version 3

---

#### Evidence — Current Schema Problems

The existing `ModelRegistryEntry` (`schemas/model_registry.py`) is a single flat struct that conflates three distinct concerns:

| Field | Problem |
|-------|---------|
| `validation_status`, `primary_file_exists`, `companion_files_valid`, `size_gb` | Runtime-computed; mutated by `_validate_entry()` — should not be immutable metadata |
| `runtime_model_id` | Router-specific identifier — belongs to runtime config, not model identity |
| `recommended_profiles` | Performance hint — belongs to runtime configuration layer |
| `estimated_vram_gb`, `estimated_ram_gb` | Resource estimates — mix of identity and runtime concerns |
| No `architecture` field | GGUF metadata contains architecture (e.g. `llama`, `qwen2_vl`) — not captured |
| No `input_modalities` field | Distinct from capabilities; `vision` capability derives from `image` input modality |
| No `asset_type` field | Cannot distinguish GGUF, LoRA, embedding, tokenizer-only entries |
| No `chat_template` field | Available in GGUF metadata; needed for correct prompt formatting |
| No `discovered` state | Scanner finds files not in registry — currently forced into `unregistered` without distinguishing "seen but unvalidated" |
| No `incompatible` state | No way to mark a GGUF that fails compatibility check |
| `variant` hardcoded to `"instruct"` for unregistered scans | Incorrect default; variant must be unknown until declared or extracted |
| Capabilities inferred from name (not declared) | `reasoning` must be explicitly declared — never inferred from filename alone |

---

#### Model Manifest Contract Design

**Principle:** Immutable model identity/metadata is separated from mutable runtime configuration and session state. Runtime/session fields (active model, context size, GPU layers, threads, profile, mmproj offload, sleep/residency state) must NEVER appear inside the model manifest.

---

**Enumeration additions to `schemas/model_registry.py`:**

```python
class ModelAssetType(str, Enum):
    """What kind of artifact this entry represents."""
    gguf = "gguf"                   # Standard GGUF inference model
    mmproj = "mmproj"               # Multimodal projector companion
    lora = "lora"                   # LoRA adapter (future)
    embedding = "embedding"          # Embedding model (future)
    tokenizer = "tokenizer"         # Tokenizer-only (future)


class ModelVariant(str, Enum):
    """
    Declared model variant. Optional — unknown until explicitly set.
    Capability metadata (e.g. reasoning) is authoritative for feature gating,
    not variant label alone.
    """
    instruct = "instruct"
    thinking = "thinking"       # Extended reasoning (chain-of-thought)
    base = "base"               # Base pretrained, not instruction-tuned
    code = "code"               # Code-specialized variant
    unknown = "unknown"         # Unregistered / not yet declared


class InputModality(str, Enum):
    """What input types the model accepts at inference time."""
    text = "text"
    image = "image"             # Vision input — image/png, image/jpeg
    audio = "audio"             # Future / unverified
    video = "video"             # Future / unverified


class ModelDiscoveryState(str, Enum):
    """
    Lifecycle state of a model in the library.
    Separate from ValidationStatus (which is about file integrity).
    """
    discovered = "discovered"           # Found by filesystem scan; not yet in registry
    registered = "registered"           # Present in registry.json; files not yet validated
    verified = "verified"               # In registry; primary + companion files confirmed on disk
    incompatible = "incompatible"       # File present but failed GGUF/runtime compatibility check


class ValidationStatus(str, Enum):
    """File integrity/completeness status (replaces current enum — additive)."""
    verified = "verified"
    missing_primary = "missing_primary"
    missing_companion = "missing_companion"
    unregistered = "unregistered"       # Retained for backward-compatibility
    incompatible = "incompatible"       # NEW: file present but failed compat check
```

---

**Companion file — expanded:**

```python
class CompanionFile(BaseSchema):
    role: str           # "mmproj" | "tokenizer" | "lora" | future roles
    path: str           # Relative to MODEL_LIBRARY_DIR (COMPANION_DATA_ROOT/models/)
    # Optional: hash for integrity verification (future)
    sha256: Optional[str] = None
```

---

**Split schema — immutable manifest vs. computed state:**

```python
class ModelManifest(BaseSchema):
    """
    Immutable model identity and metadata.
    Sourced from registry.json (user-declared) or GGUF metadata extraction (auto).
    Runtime fields (context_size, gpu_layers, profile, sleep state) are NOT here.
    Qwen3-VL entries in registry.template.json are verified defaults, not a whitelist.
    Any compatible GGUF may be added.
    """
    # === Identity ===
    id: str                             # Stable slug: family-params-variant-quant (e.g. "qwen3-vl-2b-instruct")
    display_name: str                   # Human-readable (e.g. "Qwen3-VL 2B Instruct")
    asset_type: ModelAssetType = ModelAssetType.gguf

    # === Classification ===
    family: str = ""                    # Model family (e.g. "Qwen3-VL", "Llama-3", "Phi-4")
    architecture: str = ""              # GGUF architecture field (e.g. "qwen2_vl", "llama")
                                        # Prefer auto-extraction from GGUF metadata
    variant: ModelVariant = ModelVariant.unknown
    parameters: str = ""                # Human label: "2.0B", "7B", "70B"
    quantization: str = ""              # GGUF quantization: "Q4_K_M", "Q8_0", "F16"

    # === Capabilities & Modalities ===
    capabilities: List[ModelCapability] = Field(default_factory=list)
    # ModelCapability.reasoning must be explicitly declared — never inferred from name alone
    input_modalities: List[InputModality] = Field(default_factory=lambda: [InputModality.text])
    # vision capability requires InputModality.image

    # === Context ===
    model_max_context: int = 4096       # From GGUF metadata or registry declaration
                                        # This is the MODEL's maximum, not the runtime context_size
                                        # Runtime context_size <= model_max_context

    # === Artifacts ===
    primary_file: str                   # Relative path from MODEL_LIBRARY_DIR
    companion_files: List[CompanionFile] = Field(default_factory=list)

    # === Chat Template ===
    chat_template: Optional[str] = None     # Jinja2 template string if extractable from GGUF
    chat_template_source: Optional[str] = None  # "gguf_metadata" | "registry_declared" | None

    # === Runtime Compatibility ===
    runtime_compatibility: List[str] = Field(default_factory=lambda: ["llama_cpp"])
    # e.g. ["llama_cpp"] — future: ["llama_cpp", "ollama"]
    recommended_profiles: List[str] = Field(default_factory=lambda: ["balanced"])
    # Hint only — does not override user/machine profile selection

    # === Resource Estimates ===
    estimated_vram_gb: float = 0.0      # At recommended quantization
    estimated_ram_gb: float = 0.0
    size_gb: Optional[float] = None     # Measured from primary file on disk; null if not validated

    # === Source & Integrity ===
    license: str = ""
    source: str = ""                    # HuggingFace URL or "local"
    sha256_primary: Optional[str] = None  # Future: integrity verification on import


class ModelRegistryEntry(BaseSchema):
    """
    Full registry entry = manifest + runtime-computed state.
    Returned by GET /api/v1/models/registry.
    Runtime/session fields (active model, context_size, gpu_layers,
    profile, mmproj offload, sleep state) are NOT here — they live in ModelStatusResponse.
    """
    manifest: ModelManifest

    # === Runtime identity (router-specific, not part of manifest) ===
    runtime_model_id: str = ""          # Router's identifier for load/unload calls

    # === Library state (computed, not declared) ===
    discovery_state: ModelDiscoveryState = ModelDiscoveryState.discovered
    validation_status: ValidationStatus = ValidationStatus.unregistered
    primary_file_exists: bool = False
    companion_files_valid: bool = True

    # --- Convenience flat accessors (for API backward-compatibility) ---
    # These delegate to manifest fields; do not add new data here
    @property
    def id(self) -> str: return self.manifest.id
    @property
    def display_name(self) -> str: return self.manifest.display_name
    @property
    def capabilities(self) -> List[ModelCapability]: return self.manifest.capabilities
```

> **Backward-compatibility note:** The existing `/api/v1/models/registry` API response currently serializes `ModelRegistryEntry` flat. Phase 8P must update the endpoint to serialize the new nested `manifest` + computed state structure, OR flatten via `model_validator`. Evaluate which approach breaks fewer downstream consumers (frontend `RegistryEntry` interface). Either way, the frontend `RegistryEntry` TypeScript type must be updated to match.

---

#### GGUF Metadata Auto-Extraction

Prefer extracting the following from GGUF file headers rather than requiring manual registry declaration:

| Field | GGUF metadata key | Fallback |
|-------|------------------|---------|
| `architecture` | `general.architecture` | empty string |
| `model_max_context` | `llama.context_length` (or arch-specific) | registry-declared or 4096 |
| `parameters` | `general.parameter_count` | registry-declared |
| `chat_template` | `tokenizer.chat_template` | None |
| `quantization` | `general.quantization_version` / file name | registry-declared |
| `family` | `general.name` | registry-declared |

**Implementation note:** Use `gguf` Python package (`pip install gguf`) for metadata reading, OR implement a lightweight struct-based header reader for Windows packaging safety. Do NOT infer `capabilities` or `variant` from GGUF metadata — these must remain explicitly declared, because model names and GGUF metadata strings are unreliable capability signals.

**Phase 8P scope:** Define the extraction strategy and wire it into the `_validate_entry()` / scan pipeline. Full automatic extraction is a best-effort enhancement; registry-declared values always win when present.

---

#### model_registry.py Service Changes

```python
# _validate_entry() expanded:
def _validate_entry(entry: ModelRegistryEntry) -> ModelRegistryEntry:
    # 1. Check primary file exists
    primary = settings.MODEL_LIBRARY_DIR / entry.manifest.primary_file
    entry.primary_file_exists = primary.exists()
    if not entry.primary_file_exists:
        entry.validation_status = ValidationStatus.missing_primary
        entry.discovery_state = ModelDiscoveryState.registered  # in registry, file absent
        return entry

    # 2. Measure size
    entry.manifest.size_gb = round(primary.stat().st_size / (1024 ** 3), 2)

    # 3. Check companion files
    for companion in entry.manifest.companion_files:
        if not (settings.MODEL_LIBRARY_DIR / companion.path).exists():
            entry.companion_files_valid = False
            entry.validation_status = ValidationStatus.missing_companion
            entry.discovery_state = ModelDiscoveryState.registered
            return entry

    # 4. Optional: GGUF metadata extraction (best-effort, non-blocking)
    try:
        _enrich_from_gguf_metadata(primary, entry.manifest)
    except Exception as exc:
        logger.debug(f"GGUF metadata extraction failed for {primary.name}: {exc}")

    entry.validation_status = ValidationStatus.verified
    entry.discovery_state = ModelDiscoveryState.verified
    return entry


# Unregistered scanner: use ModelDiscoveryState.discovered
unregistered.append(ModelRegistryEntry(
    manifest=ModelManifest(
        id=...,
        display_name=path.stem,
        primary_file=relative,
        variant=ModelVariant.unknown,   # NOT defaulted to "instruct"
        capabilities=[ModelCapability.chat],  # Minimum safe default
        # reasoning NOT assumed — must be declared
    ),
    discovery_state=ModelDiscoveryState.discovered,
    validation_status=ValidationStatus.unregistered,
    primary_file_exists=True,
))
```

---

#### registry.template.json — Schema Version 3

```json
{
  "_schema_version": "3",
  "_note": "Paths relative to MODEL_LIBRARY_DIR (COMPANION_DATA_ROOT/models/). Qwen3-VL entries are verified factory defaults, not a whitelist. Any compatible GGUF may be added. variant and capabilities must be declared explicitly — never inferred from filename. reasoning capability is authoritative for feature gating.",
  "models": [
    {
      "id": "qwen3-vl-2b-instruct",
      "display_name": "Qwen3-VL 2B Instruct",
      "asset_type": "gguf",
      "family": "Qwen3-VL",
      "architecture": "qwen2_vl",
      "variant": "instruct",
      "parameters": "2.0B",
      "quantization": "Q4_K_M",
      "model_max_context": 32768,
      "capabilities": ["chat", "vision", "multilingual"],
      "input_modalities": ["text", "image"],
      "primary_file": "vision/qwen3-vl-2b-instruct/Qwen_Qwen3-VL-2B-Instruct-Q4_K_M.gguf",
      "companion_files": [
        { "role": "mmproj", "path": "vision/qwen3-vl-2b-instruct/mmproj-Qwen_Qwen3-VL-2B-Instruct-f16.gguf" }
      ],
      "runtime_compatibility": ["llama_cpp"],
      "recommended_profiles": ["eco", "balanced"],
      "estimated_vram_gb": 2.4,
      "estimated_ram_gb": 0.6,
      "license": "Apache-2.0",
      "source": "https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF"
    }
  ]
}
```

*(remaining 4 Qwen3-VL entries follow same pattern — add `asset_type`, `architecture`, `input_modalities`, `model_max_context` to each)*

---

#### Frontend RegistryEntry TypeScript Update

**[MODIFY]** `frontend/web/src/services/api/registryApi.ts`

```typescript
// New enums
export type ModelAssetType = 'gguf' | 'mmproj' | 'lora' | 'embedding' | 'tokenizer';
export type ModelVariant = 'instruct' | 'thinking' | 'base' | 'code' | 'unknown';
export type InputModality = 'text' | 'image' | 'audio' | 'video';
export type ModelDiscoveryState = 'discovered' | 'registered' | 'verified' | 'incompatible';

export interface ModelManifest {
  id: string;
  display_name: string;
  asset_type: ModelAssetType;
  family: string;
  architecture: string;
  variant: ModelVariant;
  parameters: string;
  quantization: string;
  model_max_context: number;  // model's maximum — not runtime context_size
  capabilities: ModelCapability[];
  input_modalities: InputModality[];
  primary_file: string;
  companion_files: CompanionFile[];
  chat_template: string | null;
  chat_template_source: string | null;
  runtime_compatibility: string[];
  recommended_profiles: string[];
  estimated_vram_gb: number;
  estimated_ram_gb: number;
  size_gb: number | null;
  license: string;
  source: string;
}

export interface RegistryEntry {
  manifest: ModelManifest;
  runtime_model_id: string;
  discovery_state: ModelDiscoveryState;
  validation_status: ValidationStatus;
  primary_file_exists: boolean;
  companion_files_valid: boolean;
  // Convenience flat accessors (mirrors backend properties):
  id: string;
  display_name: string;
  capabilities: ModelCapability[];
}
```

> **Impact on AssistantStatusBar, ModelsView:** All code that accesses `entry.capabilities`, `entry.display_name`, `entry.id` via flat properties continues to work (convenience accessors). Code that accesses `entry.context_limit` must migrate to `entry.manifest.model_max_context`.

---

#### Canonical Architecture Document

**[CREATE]** `docs/04_Architecture/MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md`

Contents:
1. **Purpose** — single source of truth for model library design
2. **Terminology** — GGUF model, model library, model manifest, registry, discovery state, validation status
3. **COMPANION_DATA_ROOT layout** — `models/` subdirectory structure (family-based, not capability-based)
4. **ModelManifest contract** — all fields, sources, and what is prohibited (runtime state)
5. **ModelRegistryEntry** — manifest + computed state; runtime identity
6. **Discovery states** — discovered → registered → verified | incompatible lifecycle
7. **GGUF metadata extraction** — what is auto-extracted vs. declared
8. **Capability authoritativeness** — reasoning, vision, etc. are declared, never inferred from name
9. **Invariant rules** (summary for master plan)
10. **Deferred** — import UI, quantization, CUDA, benchmarking wizard, Android import

**Invariant rules (also added to AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md):**
- Model manifest is immutable at runtime; runtime/session state is separate
- `reasoning` capability is explicitly declared — never inferred from model name or filename
- `GGUF model` ≠ `Vulkan model` / `CUDA model`; runtime acceleration is an engine property
- `model_max_context` (manifest) is distinct from `applied_context_size` (runtime)
- `variant = unknown` is the correct default for unregistered/discovered files — not `instruct`
- Registry entries are GGUF compatibility declarations — unknown compatible GGUFs may be added

---

#### 8P.7 Deferred Items

| Item | Reason |
|------|--------|
| Web/Android Import Model UI | Dedicated model-library/import phase |
| Automatic GGUF download pipeline | Dedicated phase |
| Quantization / conversion tooling | Dedicated phase |
| CUDA runtime support | Out of scope for Phase 8 |
| Benchmarking wizard | Dedicated phase |
| Full GGUF metadata extraction library | Best-effort in 8P.7; full implementation deferred |

---

### 8P.7 Task Additions

```
- [ ] 8P.7a: schemas/model_registry.py — ModelManifest, ModelAssetType, ModelVariant,
              InputModality, ModelDiscoveryState added; ModelRegistryEntry split into
              manifest + computed state; backward-compat flat accessors
- [ ] 8P.7b: services/model_registry.py — _validate_entry() updated; unregistered scanner
              uses ModelDiscoveryState.discovered, variant=unknown; GGUF metadata extraction (best-effort)
- [ ] 8P.7c: models/registry.template.json — _schema_version 3; add asset_type, architecture,
              input_modalities, model_max_context to all entries
- [ ] 8P.7d: registryApi.ts — ModelManifest interface, RegistryEntry split, new enums;
              context_limit → model_max_context migration in consumers
- [ ] 8P.7e: CREATE docs/04_Architecture/MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md
- [ ] 8P.7f: AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md — model library invariant rules summary
```

---

## Supplement — Architecture Alignment with AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md

> **Source:** `docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md` (1771 lines)
> The following additions reconcile the Phase 8P plan against that canonical document.
> Items already covered in Phase 8P batches above are not repeated.

---

### Gap 1 — Canonical Directory Layout (§6.2)

The architecture document specifies a richer persistent root layout than the plan currently defines.

**Canonical `COMPANION_DATA_ROOT` layout (replaces simpler layout in Batch 8P.2):**

```text
<COMPANION_DATA_ROOT>/
│
├── database/
│   └── companion.db
│
├── attachments/
│   └── <owner-id>/<conversation-id>/<attachment-id>.<verified-ext>
│
├── library/
│   ├── models/
│   │   ├── llm/           ← text-only GGUF models
│   │   ├── embeddings/
│   │   ├── rerankers/
│   │   ├── stt/
│   │   ├── tts/
│   │   ├── vad/
│   │   └── wake-word/
│   ├── voices/            ← TTS/STT asset weights
│   └── registry/
│       └── models.json    ← installed user/runtime registry (distinct from repo template)
│
├── characters/
│   └── <character-id>/
│
├── memory/
│   ├── indexes/
│   └── derived/
│
├── imports/
│   ├── inbox/             ← user drops large GGUFs here for offline import
│   ├── staging/
│   └── rejected/
│
├── backups/
│
├── config/
│   └── (non-secret persistent configuration)
│
├── cache/
│
└── logs/
```

**Key clarifications:**
- Directories are created lazily — the architecture does not require empty dirs before their feature is active
- `library/models/llm/` is family-organized (e.g. `llm/qwen3-vl-4b-instruct/`) — NOT `vulkan/` or `cuda/`
- Runtime binaries (`llama.cpp`, Python env, frontend bundle) stay outside this root always
- `library/registry/models.json` is the **installed runtime registry** (machine state); `models/registry.template.json` in the repository remains the **factory example/bootstrap source**

**Config property update (8P.2 revised):**

```python
# Canonical derived paths — all relative to COMPANION_DATA_ROOT:
@property
def DATABASE_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "database"

@property
def DATABASE_PATH(self) -> Path:
    return self.DATABASE_DIR / "companion.db"

# DATABASE_URL must be derived from absolute DATABASE_PATH — not a hardcoded relative string
# Current: DATABASE_URL = "sqlite+aiosqlite:///./data/companion.db"  ← MUST BE FIXED
# Corrected: derived from settings.DATABASE_PATH.as_posix()

@property
def LIBRARY_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "library"

@property
def MODEL_LIBRARY_DIR(self) -> Path:
    """LLM-family GGUF model library. Not organized by acceleration backend."""
    return self.LIBRARY_DIR / "models" / "llm"

@property
def INSTALLED_REGISTRY_PATH(self) -> Path:
    """Installed runtime registry — distinct from repository factory template."""
    return self.LIBRARY_DIR / "registry" / "models.json"

@property
def VOICE_LIBRARY_DIR(self) -> Path:
    return self.LIBRARY_DIR / "voices"

@property
def ATTACHMENT_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "attachments"

@property
def IMPORT_INBOX_DIR(self) -> Path:
    """User drops large GGUF files here for offline/side-load import."""
    return self.COMPANION_DATA_ROOT / "imports" / "inbox"

@property
def IMPORT_STAGING_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "imports" / "staging"

@property
def CHARACTER_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "characters"

@property
def MEMORY_DIR(self) -> Path:
    return self.COMPANION_DATA_ROOT / "memory"
```

> **DATABASE_URL fix (Phase 8P.2):** Remove the hardcoded `DATABASE_URL = "sqlite+aiosqlite:///./data/companion.db"` field and derive it from `settings.DATABASE_PATH`. This must be backward-safe — on first run the resolved path equals the current `data/companion.db` location.

---

### Gap 2 — Bootstrap Locator (§7)

The architecture defines a platform bootstrap locator to solve the "where is the data root" problem before the application can read config from the root.

**Phase 8P scope: document only — no implementation required.**

Windows implementation options (decide in §33.3 open decision):
```text
A. %LOCALAPPDATA%\AI Companion\bootstrap.json
B. Windows registry (HKCU\Software\AI Companion)
C. Installer-managed per-user locator
```

Bootstrap locator contents (minimal):
```json
{
  "schema_version": 1,
  "data_root": "D:\\AICompanionData"
}
```

Invariants:
- Contains ONLY bootstrap location info — no conversation history, attachments, model files, memory, secrets
- Normal uninstall preserves the locator if persistent data is preserved
- On reinstall with missing locator, application offers: `Use default / Locate existing folder / Create new`

**Add to 8P.6 documentation scope.**

---

### Gap 3 — Existing Data Migration Strategy (§9)

8P must define (and implement enough of) a migration strategy for users who already have data in the current project-relative location.

**Conceptual first-run logic:**
```text
Is there an existing COMPANION_DATA_ROOT with companion.db at the canonical path?
│
├── yes → open it directly
│
└── no
    ├── Is there a legacy companion.db at backend/data/companion.db?
    │    └── yes → offer safe migration:
    │         ├── create COMPANION_DATA_ROOT/database/
    │         ├── copy (not move) legacy DB to new path
    │         ├── verify schema revision + row integrity
    │         ├── preserve backup of original
    │         └── on success → set new path as active
    └── no → create fresh DB at canonical path
```

**Migration safety rules (from §9):**
- Never overwrite a newer persistent database automatically
- Never delete the legacy database before the migrated copy is verified
- Verify schema revision and row count integrity
- Keep a backup during migration
- Migration must be restart-safe (idempotent)
- Path migration must not alter unrelated repository files or LFS policy

**Add as Batch 8P.8:**
```
- [ ] 8P.8: config.py — DATABASE_URL derived from settings.DATABASE_PATH (absolute); backward-safe default
- [ ] 8P.8b: First-run data migration — legacy DB detection + safe copy + verification + backup
- [ ] 8P.8c: Add migration test: legacy DB present → migrated to COMPANION_DATA_ROOT → verified → backup preserved
```

---

### Gap 4 — Repository Model-Storage Policy Protection (§10)

**Explicit constraint to add to plan:**

8P must NOT silently change `.gitattributes`, `.lfsconfig`, LFS remotes, or repository model tracking.

The implementation distinguishes:
```text
Repository development/bootstrap model assets
→ existing Git/LFS policy (protected — no change without explicit authorization)

Installed application / user-imported runtime model library
→ COMPANION_DATA_ROOT/library/models/
```

A future transition of existing development models into the installed persistent library requires an explicit migration plan and user authorization — it is NOT assumed to be part of Phase 8P.

**Add as an explicit constraint note in Batch 8P.2 and Batch 8P.3.**

---

### Gap 5 — Companion Artifact Partial Availability (§12.6)

The architecture defines that a model with a missing mmproj should still be usable for text chat:

```text
primary artifact present + companion (mmproj) missing:
→ text chat: available
→ vision: unavailable until mmproj is installed
```

**Phase 8P.7b update:** `_validate_entry()` must not mark the entire model `incompatible` or `missing_companion` as a binary outcome. Add a per-capability availability map:

```python
class CompanionArtifactStatus(BaseSchema):
    role: str
    present: bool
    path: str

# In ModelRegistryEntry:
companion_artifact_statuses: List[CompanionArtifactStatus] = Field(default_factory=list)
# derived: which capabilities are reduced/unavailable due to missing companions
available_capabilities: List[ModelCapability] = Field(default_factory=list)
# available_capabilities may be a subset of manifest.capabilities
```

Expose `available_capabilities` in the API response so the frontend can accurately gate features (e.g. disable vision upload even for a verified entry when mmproj is absent).

---

### Gap 6 — Reasoning Mode Architecture (§13)

`reasoning_mode` is a distinct field from `capabilities`:

```python
class ReasoningMode(str, Enum):
    always_on = "always_on"       # Thinking weights, always emits CoT
    toggleable = "toggleable"     # Can be enabled/disabled per-request
    unsupported = "unsupported"   # Model does not support reasoning
    unknown = "unknown"           # Not yet determined

# Add to ModelManifest:
reasoning_mode: ReasoningMode = ReasoningMode.unknown
```

Feature gating rule: `ModelCapability.reasoning` in `capabilities` is authoritative. `reasoning_mode` provides finer control of how that capability is expressed. Never gate on `variant == "thinking"` alone.

**Add to Batch 8P.7a.**

---

### Gap 7 — Capability Confidence/Provenance (§15)

The architecture requires room for capability provenance tracking even if the initial implementation simplifies it.

```python
class CapabilityProvenance(str, Enum):
    declared = "declared"     # Explicitly written in registry.json by user/admin
    detected = "detected"     # Extracted from GGUF metadata
    verified = "verified"     # Confirmed by a live runtime test
    unknown = "unknown"       # Source not tracked

class CapabilityEntry(BaseSchema):
    capability: ModelCapability
    supported: bool
    provenance: CapabilityProvenance = CapabilityProvenance.unknown
```

**Phase 8P scope:** Define the schema structure and use `declared` for all registry-sourced capabilities and `detected` for GGUF-extracted. Full `verified` provenance (runtime live test) is deferred to a future model-import validation phase.

**Add to Batch 8P.7a.**

---

### Gap 8 — Installed Registry vs Factory Registry (§18)

**Current plan uses:** `models/registry.json` (in repo, gitignored)  
**Architecture requires:** Two distinct registries:

| Registry | Location | Purpose |
|----------|----------|---------|
| Factory/template | `models/registry.template.json` (in repo) | Development bootstrap examples, not a whitelist |
| Installed/runtime | `COMPANION_DATA_ROOT/library/registry/models.json` | Machine's actual installed model state |

**Phase 8P migration:**
- `_load_registry_json()` must check `settings.INSTALLED_REGISTRY_PATH` first
- Fall back to `models/registry.template.json` if installed registry absent
- On first run with only template: offer to initialize installed registry from template (copy + validate)
- Do not write to repository `models/registry.json` — all runtime writes go to installed registry

**Add to Batch 8P.3 and 8P.7b.**

---

### Gap 9 — Generation Recommendations in Manifest (§12.9)

The architecture allows optional generation parameter hints in the registry:

```python
class GenerationDefaults(BaseSchema):
    """
    Optional generation parameter recommendations stored in model manifest.
    These are hints only — runtime/user/character config may override.
    Not immutable model identity metadata.
    """
    temperature: Optional[float] = None
    top_p: Optional[float] = None
    top_k: Optional[int] = None
    min_p: Optional[float] = None
    repeat_penalty: Optional[float] = None

# Add to ModelManifest (optional):
generation_defaults: Optional[GenerationDefaults] = None
```

**Phase 8P.7a:** Add `GenerationDefaults` class and optional field to `ModelManifest`. Leave null for all existing Qwen3-VL entries unless known good values exist.

---

### Gap 10 — Open Decisions (§33)

The architecture document identifies open decisions that must be resolved before implementation. Add these explicitly to the Phase 8P plan as pre-implementation blockers:

**[OPEN DECISION 8P-OD1]** Default Windows data-root location — choose before 8P.2 implementation:
```
A. %LOCALAPPDATA%\AI Companion\Data   ← standard Windows user-local, no elevation needed
B. %USERPROFILE%\Documents\AI Companion  ← visible in Explorer, easier for users to find
C. Ask user during first-run setup
```

**[OPEN DECISION 8P-OD2]** Bootstrap locator implementation — choose before 8P implementation:
```
A. %LOCALAPPDATA%\AI Companion\bootstrap.json
B. Windows registry (HKCU\Software\AI Companion)
C. Installer-managed
```

**[OPEN DECISION 8P-OD3]** Development models vs installed-library migration:
```
A. Development keeps repo-managed model assets (Git/LFS); installed builds use persistent library
B. An explicit migration is desired (requires separate plan + user authorization)
```
> **Constraint:** Whatever is decided, LFS policy must not be silently changed.

**These open decisions should be answered by the user before Gemini begins 8P implementation.**

---

### Supplement Checklist Additions (add to task.md 8P section)

```
- [ ] 8P.2b: config.py — canonical directory layout per §6.2 (database/, library/models/llm/, library/registry/, imports/inbox/)
- [ ] 8P.2c: config.py — DATABASE_URL removed as hardcoded field; derived from settings.DATABASE_PATH (absolute)
- [ ] 8P.3b: model_registry.py — INSTALLED_REGISTRY_PATH check first; fall back to template; writes go to installed registry only
- [ ] 8P.7a-ext: ModelManifest — ReasoningMode, CapabilityEntry+Provenance, GenerationDefaults, CompanionArtifactStatus
- [ ] 8P.7b-ext: _validate_entry() — per-capability availability (available_capabilities); partial companion handling
- [ ] 8P.8: First-run migration — legacy DB → COMPANION_DATA_ROOT/database/companion.db (safe copy, verify, backup)
- [ ] 8P.OD: Resolve open decisions (OD1 default data root, OD2 bootstrap locator, OD3 dev-vs-installed models) BEFORE implementation
```
