# Implementation Plan: Track C2 — React Web Dashboard & Local AI Admin Controls

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Proposed for User Approval
- Target: Connect the React desktop web dashboard (`frontend/web/`) to the FastAPI backend (`backend/`), wire live SSE streaming chat completions, add Web Admin controls for model loading/unloading (VRAM release), hardware performance profiles (Eco/Balanced/Maximum), and live host status.
- Primary Skill: `frontend-screen-builder`
- Supporting Skills: `api-contract-review`, `state-management`, `design-system-consistency`, `test-creation`
- Target Files:
  - `backend/app/api/v1/endpoints/llm.py`
  - `backend/app/schemas/llm.py`
  - `backend/app/services/llm/base.py`
  - `backend/app/services/llm/llama_cpp.py`
  - `backend/tests/test_llm.py`
  - `frontend/web/src/services/api/` (new API client layer)
  - `frontend/web/src/context/BackendContext.tsx` (new connection & model state)
  - `frontend/web/src/components/workspace/ModelsView.tsx` (wire load/unload/profile)
  - `frontend/web/src/components/workspace/models/CurrentModelHero.tsx`
  - `frontend/web/src/components/workspace/AssistantView.tsx` (wire live SSE chat)
  - `frontend/web/src/components/layout/Header.tsx` (live backend & VRAM pill)

---

## 1. Skill Router Analysis

| Category | Finding |
| :--- | :--- |
| **Primary Skill** | `frontend-screen-builder` — Building and wiring real-time UI screens, reactive state, SSE streaming, and error boundaries. |
| **Supporting Skills** | `api-contract-review` (aligning HTTP/SSE contracts with backend), `state-management` (backend connectivity, model status, active chat streaming), `design-system-consistency` (preserving SoftGlass dark mode & micro-interactions), `test-creation` (backend tests for new endpoints, TypeScript verification). |
| **Considered but Excluded** | `component-refactor` (existing UI components are well structured and should not be unnecessarily rewritten), `security-audit` (using existing constant-time token verification). |
| **Execution Order** | 1. Backend Admin Endpoints (`/models/load`, `/models/unload`, `/models/profile`) -> 2. Frontend API Service Layer -> 3. BackendContext & Status Hook -> 4. ModelsView Web Admin Controls -> 5. AssistantView Live Streaming Chat -> 6. Verification. |

---

## 2. Architecture & Contract Alignment

### A. Backend Endpoints (`backend/app/api/v1/endpoints/llm.py`)
1. `GET /api/v1/models` (Existing)
   - Returns: `ModelStatusResponse` (`provider`, `is_loaded`, `active_model`, `active_profile`, `gpu_layers`, `idle_timeout_seconds`, `seconds_until_idle_unload`, `available_models`, `device_profile`).
2. `POST /api/v1/models/load` (New)
   - Request Body (Optional): `ModelLoadRequest(model_name: Optional[str], profile: Optional[str])`.
   - Behavior: If `llama-server.exe` is configured or in-process mode is active, triggers loading into VRAM and updates profile.
   - Returns: Updated `ModelStatusResponse` (`is_loaded=True`).
3. `POST /api/v1/models/unload` (New)
   - Request Body: None.
   - Behavior: Terminates `llama-server.exe` / frees in-process memory and calls `gc.collect()`. Immediately releases ~5 GB VRAM back to the GPU.
   - Returns: Updated `ModelStatusResponse` (`is_loaded=False`).
4. `PATCH /api/v1/models/profile` (New)
   - Request Body: `ModelProfileUpdateRequest(profile: str)` ("eco", "balanced", "maximum").
   - Behavior: Updates active profile settings and GPU layer allocations.

### B. Frontend Service Layer (`frontend/web/src/services/api/`)
- `client.ts`: Typed fetch wrapper with default base URL `http://127.0.0.1:8000`, reading pairing key from `localStorage` (`companion_api_key`) and injecting `Authorization: Bearer <token>`.
- `modelApi.ts`:
  - `fetchModelStatus()`
  - `loadModel(modelName?, profile?)`
  - `unloadModel()`
  - `updateProfile(profile)`
- `chatApi.ts`:
  - `streamChatCompletion(messages, options: { onToken, onDone, onError, signal })`:
    - Performs `fetch("/api/v1/chat/completions", { method: "POST", body: { stream: true, messages } })`.
    - Parses `text/event-stream` chunks line by line (`data: {...}`).
    - Handles `data: [DONE]`.

---

## 3. UI/UX & Admin Control Specification

### A. `ModelsView` & `CurrentModelHero` (Web Admin Control)
- **Real-Time Telemetry**:
  - Live indicator: 🟢 **VRAM Loaded** (e.g. Qwen 2.5 7B, 28 GPU Layers) vs ⚪ **VRAM Released** (0 MB used).
  - Idle Countdown: Shows seconds remaining before auto-unload, or indicates standby.
- **Admin Action Buttons**:
  - **[ Unload Model (Release VRAM) ]**: Single-click button that calls `POST /api/v1/models/unload`. UI reflects instant unloaded state.
  - **[ Load Model to VRAM ]**: Single-click button that calls `POST /api/v1/models/load`. Shows subtle loading spinner until weights are verified in memory.
- **Performance Profiles**:
  - Clicking **Eco** (0 GPU layers / CPU), **Balanced** (28 layers on RX 580), or **Maximum** (33 layers) sends `PATCH /api/v1/models/profile` and refreshes the allocation.

### B. `AssistantView` (Live Streaming Chat)
- When user submits a prompt in the composer:
  1. Creates user message bubble immediately.
  2. Appends an empty assistant message bubble with blinking cursor.
  3. Begins streaming from `POST /api/v1/chat/completions`.
  4. Appends each incoming token smoothly to the bubble.
  5. If user presses **Stop**, fires `AbortController.abort()`.
- **Unloaded Model Handling**:
  - If user sends a prompt while the model is unloaded:
    - Displays an inline prompt/banner: *"Model is currently unloaded to save VRAM. [Load & Send]"* or automatically triggers load before streaming.

### C. `Header.tsx` Global Host & VRAM Pill
- Displays two small status badges in the top bar:
  - Host: 🟢 `Core :8000` (Online) / 🔴 `Core Offline`
  - Model: 🟢 `Qwen 2.5 (VRAM Active)` / ⚪ `VRAM Free`

---

## 4. Verification Plan

### Automated Checks
1. Backend Unit Tests (`pytest tests/test_llm.py`):
   - Test `POST /api/v1/models/load` returns `is_loaded: true`.
   - Test `POST /api/v1/models/unload` returns `is_loaded: false`.
   - Test `PATCH /api/v1/models/profile` successfully sets profile.
   - Run full backend suite (all 31+ tests pass).
2. Frontend Verification:
   - `npm run lint` (`tsc --noEmit`) passes with 0 errors.
   - `npm run build` succeeds without bundle errors.

### Manual Verification
1. Launch backend and open web UI at `http://localhost:3000`.
2. Verify Header shows `Core :8000` (Online).
3. Navigate to **Models & Runtime**:
   - Verify status reflects unloaded (VRAM Free).
   - Click **Load Model**: Verify status changes to 🟢 Loaded.
   - Click **Unload Model**: Verify status changes to ⚪ Unloaded and VRAM drops to 0.
4. Navigate to **Assistant**:
   - Send prompt: *"Hello Aura, introduce yourself in 2 sentences."*
   - Verify real-time SSE streaming tokens appear progressively in the chat bubble.

---

## 5. Corrective Pass: WatchFiles Log Isolation & Port Architecture

### A. Port 8000 vs 8080 Architecture Alignment
- **Port 8000 (`http://127.0.0.1:8000`)**: FastAPI Companion Core. All external and browser requests flow strictly through Port 8000.
- **Port 8080 (`http://127.0.0.1:8080`)**: Standalone `llama-server.exe` native engine port. Used strictly for backend-internal subprocess proxying. Never exposed directly to the browser.

### B. WatchFiles Auto-Reload Prevention
- **Problem**: Writing `llama_server.log` to `backend/data/` triggered uvicorn's `WatchFiles` reload loop during model load, dropping the active connection and surfacing `"Failed to load model into memory"`.
- **Solution**:
  1. Move `log_file_path` in `backend/app/services/llm/llama_cpp.py` outside `backend/` to root `data/llama_server.log`.
  2. Launch uvicorn with `--reload-dir app` so file watchers restrict attention strictly to python source code.
  3. Clear transient error state in `BackendContext.tsx` on successful model status fetch.

---

## 6. Corrective Pass 2: Windows Subprocess Popen & Frontend Model Library Parity

### A. Windows `asyncio.create_subprocess_exec` NotImplementedError
- **Root Cause**: On Windows, Uvicorn's default event loop does not implement `asyncio.create_subprocess_exec`, instantly raising `NotImplementedError` and causing `load_model` to return 500 without spawning `llama-server.exe`.
- **Fix**: Use `subprocess.Popen(cmd, cwd=str(bin_dir), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)` with non-blocking `proc.poll()`.

### B. Frontend Model Selection Overwrite Bug
- **Root Cause**: `ModelsView.tsx` forced `liveActiveModel.name = detectedModelName || currentModel.name`. When user clicked Gemma or any other model in the grid, it locked the title to Qwen.
- **Fix**: Show `currentModel.name`, `currentModel.quantization`, and `currentModel.sizeGb` for the selected model. Only overlay live backend telemetry if the selected model is active/loaded.
- **Parity**: Mark models that exist in `backend/models` as `Ready on Disk` and mock library entries as `Download Required` or sync them dynamically with `available_models`.

### C. Remove Hardcoded Metrics & Legacy Mac Telemetry
- **Root Cause**: `CurrentModelHero.tsx` had hardcoded `CUDA Offload`, 4.9 GB VRAM usage when unloaded, and 3,840 context tokens when unloaded. `logsData.ts` contained `Apple M-Series Metal` mock logs.
- **Fix**:
  1. In `CurrentModelHero.tsx`: Set unloaded VRAM to `0.0 GB`, unloaded context tokens to `0`, and runtime to `llama.cpp (Vulkan AMD RX 580)`.
  2. In `logsData.ts`: Update mock logs to `AMD Radeon RX 580 (Vulkan)` and `Qwen2.5-7B-Instruct-Q4_K_M.gguf`.

