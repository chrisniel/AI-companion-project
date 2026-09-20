# Walkthrough: llama.cpp Router Discovery, Port 8085 Migration & Model Registry Fix


> [!NOTE]
> **Historical Delivery Evidence**  
> This walkthrough records repository state and verification at the time of delivery. It is non-authoritative for current architecture or product scope. Verify current implementation against source code and automated tests, and consult [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) and canonical domain specifications for active architectural truth.

---

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

## 1. What Was Delivered

This sprint diagnosed and resolved the real-world runtime failures where models failed to load in `llama-server.exe`, port 8080 conflicted with another local development project, and the Web UI falsely indicated that models were loaded in VRAM.

Key accomplishments:
1. **Model Discovery Depth**: Pointed `llama-server` `--models-dir` directly to `models/vision` (`LLAMA_MODELS_DIR`), enabling pinned llama.cpp b10936 to automatically discover all 5 Qwen3-VL models (`2b-instruct`, `2b-thinking`, `4b-instruct`, `4b-thinking`, `8b-instruct`) and pair each GGUF with its `mmproj` multimodal projector.
2. **Port 8085 Migration**: Changed default `LLAMA_ROUTER_PORT` from `8080` to `8085` (`LLAMA_SERVER_URL = "http://127.0.0.1:8085/v1"`), permanently eliminating port collisions with external development projects.
3. **Model ID Routing**: Added `runtime_model_id` to `ModelRegistryEntry` and added `resolve_runtime_model_id()` to map logical IDs, filenames, or paths to the router model ID. Ensured `POST /v1/chat/completions` passes `"model": "<model_id>"` in its payload.
4. **Provider Auto-Detection**: Replaced `MODELS_DIR.glob("*.gguf")` with recursive `MODELS_DIR.rglob("*.gguf")` (excluding `mmproj*` and `lfs-test*`) in `manager.py`, ensuring real models in subdirectories properly engage `LlamaCppProvider`.
5. **Cold Boot & Residency Truthfulness**: Corrected `MockLLMProvider` to initialize with `_is_loaded = False` and `_active_model = None`. Updated `LlamaCppProvider.get_status()` to parse router `/models` data array for verified `status.value == "loaded"` residency rather than guessing from disk.
6. **Frontend Exact ID Matching**: Replaced fuzzy `includes('Qwen')` matching in `ModelsView.tsx` with exact ID matching and connected `liveModels` with per-model residency state to `ModelLibraryGrid`.

---

## 2. Files Changed

| File | Purpose of Change |
| --- | --- |
| `backend/app/core/config.py` | Added `LLAMA_MODELS_DIR = MODELS_DIR / "vision"`, migrated `LLAMA_ROUTER_PORT` to `8085`, updated `LLAMA_SERVER_URL`. |
| `backend/app/schemas/model_registry.py` | Added `runtime_model_id: str = ""` to `ModelRegistryEntry`. |
| `backend/app/services/model_registry.py` | Populated `runtime_model_id` during scan/load; added `resolve_runtime_model_id()` helper; added `registry.template.json` fallback. |
| `backend/app/services/llm/manager.py` | Changed `glob` to `rglob` (excluding `mmproj*` and `lfs-test*`) so weights in subdirectories engage `LlamaCppProvider`. |
| `backend/app/services/llm/mock.py` | Initialized `_is_loaded = False` and `_active_model = None` on cold boot. |
| `backend/app/services/llm/llama_cpp.py` | Updated launch args to use `LLAMA_MODELS_DIR` and port `8085`; updated `_router_load_model` and `_router_unload_model` to use runtime IDs and poll `/models`; updated `get_status` to report true router residency; included `"model"` in chat completions payload. |
| `frontend/web/src/components/workspace/ModelsView.tsx` | Replaced fuzzy matching with exact identity checks; computed `liveModels` with per-model residency state and passed to `ModelLibraryGrid`. |
| `backend/tests/conftest.py` | Added `default_mock_llm_provider` global autouse fixture for fast, deterministic unit testing. |
| `backend/tests/test_llm.py` | Removed redundant local fixture. |
| `backend/tests/test_model_registry.py` | Added unit tests for `resolve_runtime_model_id`, mock cold boot truthfulness, and router port 8085. |
| `docs/01_Tracking/task.md` | Maintained active execution sprint, checklist, and state in place. |
| `CHANGELOG.md` | Appended Pass 10 entry under `## Unreleased`. |

---

## 3. How the Logic Works

### Event Trigger
When an admin user clicks "Load Model" or switches the active model in the Web UI:
1. The UI sends `POST /api/v1/models/load` with `{"model_name": "qwen3-vl-4b-instruct", "profile": "balanced"}`.

### Validation
2. `LlamaCppProvider.load_model()` checks for path traversal escapes (`..`, absolute paths) and rejects malicious inputs with `MODEL_PATH_TRAVERSAL`.
3. `resolve_runtime_model_id("qwen3-vl-4b-instruct")` queries the registry and resolves the router model ID (`"qwen3-vl-4b-instruct"`).

### Core Processing
4. If a router is already running on port 8085, it sends `POST http://127.0.0.1:8085/models/load` with `{"model": "qwen3-vl-4b-instruct"}`.
5. If no router is running, it spawns `llama-server.exe` with `--models-dir .../models/vision --port 8085 --models-max 1 -ngl 28`. The router discovers all 5 model directories and automatically pairs projector weights.
6. The backend polls `GET http://127.0.0.1:8085/models` up to 30s until the model's `status.value == "loaded"`.

### Completion
7. `LlamaCppProvider` sets `self._runtime_state = LLMRuntimeState.MODEL_READY` and `self._active_model_name = "qwen3-vl-4b-instruct"`.
8. `get_status()` returns `is_loaded: true`, `active_model: "qwen3-vl-4b-instruct"`.
9. The Web UI updates the hero card and lights up the active model card in the library grid with a glowing green badge; all other model cards display `Unloaded`.

### Recovery / Cancellation
10. If the router rejects the model or times out, `_last_error` is recorded, `runtime_state` transitions to `MODEL_ERROR`, `is_loaded` remains `False`, and FastAPI raises HTTP 500 with the exact error details.

---

## 4. Key Concepts

- **Multi-Model Router Directory Depth**: `llama-server.exe` in router mode (`--models-dir`) expects each subdirectory within the directory to represent one distinct model containing its GGUF weights and companion projector. Pointing `--models-dir` directly to `models/vision` (depth 1) allows it to auto-discover model presets and match `mmproj-*.gguf` files automatically.
- **Dynamic Model ID vs. Filesystem Path**: The router API (`/models/load` and `/models/unload`) operates on logical model identifiers (e.g. `qwen3-vl-4b-instruct`), not relative or absolute file paths. Decoupling the application model ID from the disk path ensures portability across platforms.
- **Truthful Hardware Residency**: Displaying a model as loaded in VRAM must be derived strictly from live hardware residency (e.g., `status.value == "loaded"` from the router probe) rather than assumptions or static fallback values.

---

## 5. Verification Steps

### Automated Checks
Run the full backend test suite:
```powershell
cd d:\OtherProjects\AI-companion-project\backend
.\.venv\Scripts\pytest tests/ -v
```
Result: **56 passed in ~3s** (including new tests for `resolve_runtime_model_id`, mock cold boot, and router port 8085).

Run the frontend production build:
```powershell
cd d:\OtherProjects\AI-companion-project\frontend\web
npm run build
```
Result: **0 TypeScript errors, build passed cleanly in 4.59s**.

### Live / User-Owned Smoke Test
Run the live smoke test script:
```powershell
cd d:\OtherProjects\AI-companion-project\backend
.\.venv\Scripts\python -c "import httpx; print(httpx.get('http://127.0.0.1:8085/models').json())"
```
Confirmed results on AMD RX 580:
- Router launches on port 8085 in <1s.
- Discovers all 5 Qwen3-VL models in `models/vision`.
- `POST /models/load` loads `qwen3-vl-4b-instruct` into VRAM.
- `POST /v1/chat/completions` generates streaming inference via Vulkan offload.
- `POST /models/unload` unloads model from VRAM while keeping the router alive.

---

## 6. Safe Customization & Invariants

- **Router Port**: `LLAMA_ROUTER_PORT` defaults to `8085`. It can be customized in `.env` if 8085 is ever needed by another tool.
- **Single Primary Residency Invariant**: `--models-max 1` enforces that only one generative model occupies VRAM at a time, preserving RX 580's 8GB budget.
- **Process Isolation Invariant**: The router binds exclusively to `127.0.0.1` and process cleanup is strictly scoped by PID; `taskkill /IM llama-server.exe` remains strictly forbidden.

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| `POST /models/load` returns 404 `"File Not Found"` | The request passed a file path instead of the router model ID. | Use `resolve_runtime_model_id()` or pass `"qwen3-vl-4b-instruct"`. |
| `llama-server` logs `Available models (0)` | `--models-dir` was pointed to `models/` instead of `models/vision`. | Check `LLAMA_MODELS_DIR` in `config.py` is `MODELS_DIR / "vision"`. |
| Port conflict on 8085 | An orphaned test process is holding the port. | Run `powershell -Command "Get-NetTCPConnection -LocalPort 8085 \| Select-Object OwningProcess"` and terminate the PID. |
