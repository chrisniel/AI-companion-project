# Implementation Plan: Fix llama.cpp Router & Dynamic Model Registry Integration

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Awaiting Approval
- Scope Mode: Surgical Fix & Real Integration — Repair router model discovery, model ID routing, provider detection, and live status synchronization between FastAPI, llama.cpp, and React Web UI.
- Target Files:
  - `backend/app/core/config.py`
  - `backend/app/services/llm/manager.py`
  - `backend/app/services/llm/mock.py`
  - `backend/app/services/llm/llama_cpp.py`
  - `backend/app/schemas/model_registry.py`
  - `backend/app/services/model_registry.py`
  - `frontend/web/src/components/workspace/ModelsView.tsx`
  - `backend/tests/test_llm_router_lifecycle.py`
  - `backend/tests/test_model_registry.py`

Notice: Update this plan in place during planning. After approval, switch live execution tracking to `docs/01_Tracking/task.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective**:
  Resolve the real-world runtime failures where models fail to load in `llama-server.exe`, port 8080 conflicts with another project, and the Web UI falsely indicates that models are loaded in VRAM. Establish robust, verified end-to-end integration between FastAPI, llama.cpp b10936 router, and the Web UI.

- **Concrete Deliverables**:
  1. Fix `LLAMA_MODELS_DIR`: Point `llama-server` `--models-dir` directly to `models/vision` (where per-model directories live) so b10936 automatically discovers all 5 Qwen3-VL models and pairs each GGUF with its `mmproj` projector.
  2. Router Model ID Separation: Update `ModelRegistryEntry` to expose `runtime_model_id` (e.g. `qwen3-vl-4b-instruct`), and ensure `POST /models/load` sends the router model ID rather than the physical file path.
  3. Change Router Port to Non-Conflicting `8085`: Change default `LLAMA_ROUTER_PORT` from `8080` to `8085` to eliminate conflicts with the user's other local web project.
  4. Provider Auto-Detection: Update `manager.py` to recursively detect GGUFs in subdirectories (`rglob`), preventing incorrect fallback to `MockLLMProvider`.
  5. Cold Startup Truthfulness: Fix `MockLLMProvider` so it initializes with `_is_loaded = False`, eliminating false "Loaded on VRAM" UI states.
  6. Router Status Truthfulness: In `LlamaCppProvider.get_status()`, query the live router `/models` endpoint to determine true residency; never invent an active model from disk when nothing is resident.
  7. Exact UI Identity Matching: Fix `ModelsView.tsx` to match `currentModel.id === modelStatus.active_model` instead of fuzzy `includes('Qwen')` matching.
  8. Automated & Manual Smoke Testing: Verify all 53+ automated tests pass and perform live inference verification with `llama-server.exe` on RX 580 Vulkan.

- **Explicit Out-of-Scope**:
  - No STT, TTS, Kokoro, or Silero changes.
  - No database schema migrations.
  - No Git LFS policy changes or remote pushes.
  - No image upload transport or camera wiring.

---

## 2. Current Findings & Technical Root Cause

| Observation / Evidence | Verified Interpretation |
| --- | --- |
| `data/llama_server.log` logged `Available models (0)` when launched with `--models-dir models/` | Pinned llama.cpp b10936 only scans 1 directory level deep for models. With `models/vision/qwen...`, it found 0 models. |
| Direct test with `--models-dir models/vision` discovered all 5 models (`qwen3-vl-2b-instruct`, `4b-instruct`, etc.) | When `--models-dir` points directly to the folder containing model subdirectories, b10936 discovers all models, assigns model IDs from folder names, and automatically pairs `mmproj` files. |
| `POST /models/load` failed with 404 when given `"vision/qwen...gguf"` | llama.cpp router expects the model ID (e.g. `"qwen3-vl-4b-instruct"`), not the physical filesystem path. |
| `GET /api/v1/models` returned `"provider": "mock"`, `"is_loaded": true`, `"active_model": "Qwen2.5-7B..."` | `manager.py` used `MODELS_DIR.glob("*.gguf")` which found 0 top-level models, falling back to `MockLLMProvider`. `MockLLMProvider` hardcoded `_is_loaded = True` on startup. |
| Web UI displayed "Loaded on VRAM" for Qwen models even when no model was running | `ModelsView.tsx` checked `(isQwenModel && modelStatus.active_model.includes('Qwen'))` against Mock's fabricated status. |
| Stale PIDs 12780 and 10508 were bound to port 8080, and user's other web project also uses 8080 | Lingering test processes intercepted health checks, and port 8080 overlaps with user's external workspace. |

---

## 3. Proposed File Changes & In-Place Logic

### [MODIFY] `backend/app/core/config.py`
- Change `LLAMA_ROUTER_PORT` default from `8080` to `8085` (avoiding user project conflict).
- Add `LLAMA_MODELS_DIR: Path = MODELS_DIR / "vision"` pointing directly to the directory containing model subdirectories.
- Update `LLAMA_SERVER_URL` to `http://127.0.0.1:8085/v1`.

### [MODIFY] `backend/app/schemas/model_registry.py`
- Add `runtime_model_id: str = ""` to `ModelRegistryEntry` (defaults to `id`).

### [MODIFY] `backend/app/services/model_registry.py`
- Populate `runtime_model_id` during registry loading and auto-discovery.
- Add helper `resolve_runtime_model_id(identifier: str) -> str` to map application ID, primary path, or filename to the router model ID.

### [MODIFY] `backend/app/services/llm/manager.py`
- In `get_provider()`, change `MODELS_DIR.glob("*.gguf")` to `MODELS_DIR.rglob("*.gguf")` (excluding `mmproj*` and `lfs-test*`) so real GGUF weights in subdirectories engage `LlamaCppProvider`.

### [MODIFY] `backend/app/services/llm/mock.py`
- Initialize `_is_loaded = False` and `_active_model = None` in `__init__`.

### [MODIFY] `backend/app/services/llm/llama_cpp.py`
- Launch router with `--models-dir str(settings.LLAMA_MODELS_DIR.resolve())` and `--port str(settings.LLAMA_ROUTER_PORT)`.
- In `_router_load_model(model_name)`:
  - Resolve `model_name` to `runtime_model_id`.
  - Send `{"model": runtime_model_id}` to `http://127.0.0.1:8085/models/load`.
  - Poll `/models` up to 30s for `status.value == "loaded"` before confirming readiness.
  - Return `False` if router load fails (do NOT report `MODEL_READY` on failure).
- In `_router_unload_model(model_name)`:
  - Send `{"model": runtime_model_id}` to `/models/unload`.
- In `get_status()`:
  - When router is active on port 8085, query `GET http://127.0.0.1:8085/models`.
  - If a model has `status.value == "loaded"`, set `active_model = model.id` and `runtime_state = MODEL_READY`.
  - If no model is loaded in the router, set `active_model = None`, `runtime_state = MODEL_UNLOADED`, `is_loaded = False`.
- In `generate()` and `generate_stream()`:
  - Include `"model": self._active_model_name` in the payload to `/chat/completions`.
- In `_idle_monitor_loop()`:
  - Rely on native llama.cpp `--sleep-idle-seconds 900` for automatic sleep; do not trigger Python process-level unload.

### [MODIFY] `frontend/web/src/components/workspace/ModelsView.tsx`
- Replace fuzzy `includes('Qwen')` matching:
  ```typescript
  const isSelectedModelLoaded = Boolean(
    modelStatus?.is_loaded &&
    modelStatus?.active_model &&
    (currentModel.id === modelStatus.active_model || currentModel.filePath === modelStatus.active_model)
  );
  ```
- In `handleActivateModel`:
  Pass `selected.id` (application model ID) to `loadModel()`.

### [MODIFY] `backend/tests/test_llm_router_lifecycle.py` & `backend/tests/test_model_registry.py`
- Update unit tests to verify:
  1. `LLAMA_MODELS_DIR` usage.
  2. Router load failure does not set `MODEL_READY`.
  3. `is_loaded` is `False` when router is idle with no loaded model.
  4. Exact model identity mapping.

---

## 4. Step-by-Step Implementation Sequence

1. **Step 1 (Port & Config)**: Update `config.py` with port 8085 and `LLAMA_MODELS_DIR`.
2. **Step 2 (Provider Detection & Mock Truthfulness)**: Fix `manager.py` (`rglob`) and `mock.py` (`_is_loaded = False`).
3. **Step 3 (Schema & Registry)**: Add `runtime_model_id` to schema and service.
4. **Step 4 (LlamaCppProvider Core)**:
   - Update `launch_args` to `--models-dir LLAMA_MODELS_DIR`.
   - Update `load_model`, `_router_load_model`, and `_router_unload_model` to use runtime model IDs and poll status.
   - Update `get_status` to query router `/models` and report true residency.
   - Pass `"model"` in chat completion payloads.
5. **Step 5 (Frontend Identity Match)**: Update `ModelsView.tsx` to match exact model IDs.
6. **Step 6 (Automated Tests)**: Run full pytest test suite (target: all 53+ passing).
7. **Step 7 (Real Smoke Test)**: Run live verification of router spawning, loading Qwen3-VL, streaming completion, and unloading on port 8085.

---

## 5. Acceptance Criteria & Verification Plan

### Automated Repository Checks
- [ ] `.venv\Scripts\pytest tests/ -v --tb=short` — 53+ tests passing.
- [ ] `npm run build` in `frontend/web/` — 0 TypeScript or Vite build errors.

### Manual / Real Smoke Test Checks
- [ ] Direct probe: `http://127.0.0.1:8085/models` returns all 5 discovered models with `status.value == "unloaded"`.
- [ ] Backend status probe: `GET /api/v1/models` returns `provider: "llama_cpp"`, `is_loaded: false`, `active_model: null`, `runtime_state: "MODEL_UNLOADED"`.
- [ ] Load probe: `POST /api/v1/models/load` with `model_name: "qwen3-vl-4b-instruct"` returns `is_loaded: true`, `active_model: "qwen3-vl-4b-instruct"`.
- [ ] Completion probe: `POST /api/v1/chat/completions` generates conversational text streamed via Vulkan offload on RX 580.
- [ ] Unload probe: `POST /api/v1/models/unload` unloads model from VRAM, router stays alive on 8085.
- [ ] Web UI check: ModelsView displays all real models; only the active model shows "Loaded".

---

## 6. Risks, Recovery & Rollback

- **Risk**: Port 8085 might be blocked by local firewall.
  - **Mitigation**: Binds strictly to `127.0.0.1`.
- **Risk**: A future text-only model in `models/text/` wouldn't be in `models/vision/`.
  - **Mitigation**: `LLAMA_MODELS_DIR` can be set via env var or unified under `models/generative/` when text models are added.
- **Rollback**: All changes are tracked in Git on `feature/assistant-orchestration-and-memory`. Reversible with `git checkout`.
