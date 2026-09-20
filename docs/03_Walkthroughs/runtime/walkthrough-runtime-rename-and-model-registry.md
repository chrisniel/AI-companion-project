# Walkthrough: Track R2-lite — Runtime Folder Separation & Dynamic Model Registry


> [!NOTE]
> **Historical Delivery Evidence**  
> This walkthrough records repository state and verification at the time of delivery. It is non-authoritative for current architecture or product scope. Verify current implementation against source code and automated tests, and consult [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) and canonical domain specifications for active architectural truth.

---

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Document the architectural separation of runtime engine binaries into `runtime/`, the reorganization of models into per-model subdirectories, and the hybrid dynamic Model Registry service and UI.
- Audience: User, developer, maintainer, QA
- Status: Implemented & Automated Verification Passing (Manual verification pending)
- Last Updated: 2026-09-13

---

## 1. What Was Delivered

- **Runtime Folder Separation**: Moved external inference binaries (`llama.cpp` and `whisper.cpp`) from `provider/` into `runtime/`. Updated `backend/app/core/config.py` (`RUNTIME_DIR`, `LLAMA_CPP_BIN_DIR`) and `.gitignore`.
- **Per-Model Subdirectories**: Reorganized `models/vision/` into 5 clean directories (`qwen3-vl-2b-instruct`, `qwen3-vl-2b-thinking`, `qwen3-vl-4b-instruct`, `qwen3-vl-4b-thinking`, `qwen3-vl-8b-instruct`), pairing primary GGUF models with their corresponding `mmproj` vision projectors.
- **Model Registry Service & Schema**: Implemented `ModelRegistryEntry` schema (`backend/app/schemas/model_registry.py`) and read-only `model_registry` service (`backend/app/services/model_registry.py`).
- **Registry Template & Gitignore**: Committed `models/registry.template.json` containing metadata for all 5 installed Qwen3-VL models. Added gitignore exception for template while ignoring local `models/registry.json`.
- **Protected Registry API**: Added `GET /api/v1/models/registry` endpoint and `available_registry` field to `ModelStatusResponse`.
- **Safe Path Traversal & Model Loading**: Refined `LlamaCppProvider.load_model` to allow valid relative subdirectories within `MODELS_DIR` while strictly rejecting directory-escape attempts (`..`, absolute paths).
- **Web UI Live Discovery**: Added `fetchModelRegistry()` in `frontend/web/src/services/api/registryApi.ts`, wired `ModelsView.tsx` to populate library cards on mount, added variant badges (`Instruct`, `Thinking 🧠`, `⚠ mmproj missing`), and eliminated hardcoded fallback model names.

## 2. Files Changed

- `backend/app/core/config.py` — Updated `RUNTIME_DIR = BASE_DIR.parent / "runtime"` and `LLAMA_CPP_BIN_DIR = RUNTIME_DIR / "llama.cpp"`.
- `backend/app/schemas/model_registry.py` [NEW] — Defined `ModelCapability`, `ValidationStatus`, `CompanionFile`, and `ModelRegistryEntry`.
- `backend/app/schemas/llm.py` — Added `available_registry: Optional[List[str]] = None` to `ModelStatusResponse`.
- `backend/app/services/model_registry.py` [NEW] — Implemented `build_model_list()`, `_load_registry_json()`, `_scan_models_dir()`, and `_validate_entry()`.
- `backend/app/services/llm/llama_cpp.py` — Integrated recursive model discovery (`rglob`), safe path traversal check, and `available_registry` reporting.
- `backend/app/services/llm/mock.py` — Added `rglob` scanning and `available_registry` mock reporting.
- `backend/app/api/v1/endpoints/llm.py` — Added `GET /models/registry` endpoint.
- `backend/app/api/v1/endpoints/conversations.py` — Fixed pre-flight check to inspect `runtime_state` directly.
- `backend/tests/test_model_registry.py` [NEW] — Authored 4 unit/integration tests for registry loading, disk validation, and auth enforcement.
- `backend/tests/test_llm_router_lifecycle.py` — Updated path traversal test to verify root escape rejection while allowing subpath models.
- `frontend/web/src/types.ts` — Added `ModelVariant`, `ModelCapability`, `ValidationStatus`, and optional registry fields to `LocalModel`.
- `frontend/web/src/services/api/registryApi.ts` [NEW] — Added typed client for `GET /api/v1/models/registry`.
- `frontend/web/src/services/api/index.ts` — Re-exported `registryApi`.
- `frontend/web/src/components/workspace/ModelsView.tsx` — Wired `fetchModelRegistry()` on mount, removed hardcoded fallback names.
- `frontend/web/src/components/workspace/models/ModelLibraryGrid.tsx` — Added variant badges, capability icons, and mmproj missing warning.
- `models/registry.template.json` [NEW] — Committed relative template cataloging installed Qwen3-VL models.
- `.gitignore` — Removed `provider/`, added `!models/registry.template.json` exception, kept `runtime/` and `models/registry.json` ignored.
- `docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md` — Updated paths from `provider/` to `runtime/`.
- `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` — Updated paths and directory tree to reflect `runtime/`.
- `docs/02_Planning/plan-assistant-orchestration-and-memory.md` — Updated references to `runtime/`.
- `docs/01_Tracking/task.md` — Checked off R2-lite tasks and updated current execution state.
- `CHANGELOG.md` — Appended Pass 9 entry under `## Unreleased`.

## 3. How the Logic Works

1. **Event trigger**: Frontend `ModelsView` mounts or user loads models view.
2. **Validation**: Frontend calls `fetchModelRegistry(apiKey)` passing the session Bearer / API key. FastAPI `protected_router` verifies the token.
3. **Core processing**:
   - `build_model_list()` loads `models/registry.json` (or falls back to `{}` if absent).
   - For each entry, it checks whether `primary_file` exists and verifies that required `companion_files` (such as `mmproj`) exist on disk.
   - It performs an `rglob("*.gguf")` scan of `models/` for files `> 100 MB` (excluding `mmproj-*` and `lfs-test*`). Any uncatalogued models are appended as `unregistered`.
   - Results are sorted with registered models first (instruct < thinking < base) followed by unregistered.
4. **Completion**: Endpoint returns `List[ModelRegistryEntry]`. Frontend transforms entries to `LocalModel[]`, rendering cards with variant badges (`Instruct`, `Thinking 🧠`), capabilities, and VRAM estimates.
5. **Recovery/cancellation**: If the backend is offline or unauthenticated, `ModelsView` catches the error and cleanly falls back to `mockLocalModels` without blanking the screen.

## 4. Key Concepts

- **Runtime Engine vs Provider Adapter**: A runtime engine (e.g. `llama-server.exe`) is an external compiled binary daemon executing inference. A provider adapter (e.g. `LlamaCppProvider`) is internal application Python code translating app requests into native engine commands.
- **Multimodal Projector (`mmproj`)**: In multimodal vision-language models, the vision projector maps image patch embeddings into the language model's embedding space. The main GGUF and projector GGUF constitute a single logical model.
- **Hybrid Registry Auto-Discovery**: Combining disk scanning with JSON metadata enrichment so known models receive rich metadata (VRAM, capabilities, companion pairing) while newly dropped GGUF files are immediately surfaced as unregistered models rather than remaining invisible.

## 5. Verification Steps

### Automated Checks

- [x] `.venv\Scripts\pytest tests/ -v --tb=short` — All 53 tests passed (49 baseline + 4 registry tests).
- [x] `npm run build` in `frontend/web/` — Successfully built production bundle (2,166 modules transformed, 0 errors).

### Manual / User-Owned Checks

- [ ] Step 1: Start FastAPI backend (`uvicorn app.main:app --port 8000 --reload`).
- [ ] Step 2: Open Web UI in browser (`http://localhost:5173`) and navigate to Models tab.
- [ ] Step 3: Verify Model Library Grid renders real discovered models: `Qwen3-VL 2B Instruct`, `Qwen3-VL 2B Thinking`, `Qwen3-VL 4B Instruct`, `Qwen3-VL 4B Thinking`, `Qwen3-VL 8B Instruct`.
- [ ] Step 4: Verify variant pills display accurately: blue "Instruct", purple "Thinking 🧠".
- [ ] Step 5: Click **[ Load to VRAM ]** on `Qwen3-VL 4B Instruct` and confirm `vision/qwen3-vl-4b-instruct/Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf` is loaded into VRAM.

## 6. Safe Customization & Invariants

- **Tunable parameters**:
  - `models/registry.json`: Add new models by copying from `models/registry.template.json` and editing `id`, `display_name`, `variant`, `estimated_vram_gb`, etc.
  - `LLAMA_ROUTER_IDLE_TIMEOUT` in `config.py`: Adjust automatic idle sleep threshold (default: 900s).
- **Invariants**:
  - `runtime/` must NEVER be committed to Git (strictly gitignored).
  - `models/registry.json` is local-only; only `models/registry.template.json` is committed.
  - `build_model_list()` is strictly read-only and never writes to disk.
  - All native engine execution paths must resolve to normalized absolute paths.

## 7. Troubleshooting

- **Symptom**: Model Library Grid displays static mock models instead of real models.
  - Likely cause: Backend is offline or API key is invalid/missing in the web UI.
  - Resolution: Verify backend is running on `http://127.0.0.1:8000` and API key is set in workspace settings.
- **Symptom**: Model load fails with `MODEL_PATH_TRAVERSAL`.
  - Likely cause: The model path contains `..` or leading slashes attempting to navigate outside `models/`.
  - Resolution: Ensure paths are relative to `models/` (e.g. `vision/qwen3-vl-4b-instruct/Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf`).
