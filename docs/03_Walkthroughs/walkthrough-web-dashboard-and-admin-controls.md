# Walkthrough: Track C2 — React Web Dashboard & Local AI Admin Controls

## 1. What Was Delivered

1. **Web Admin Runtime Controls (Instant VRAM Release)**:
   - Added `POST /api/v1/models/load`, `POST /api/v1/models/unload`, and `PATCH /api/v1/models/profile` on the FastAPI backend.
   - Wired tactile **[ Load to VRAM ]** and **[ Unload VRAM ]** buttons directly inside `ModelsView` and `CurrentModelHero`.
   - Clicking **[ Unload VRAM ]** immediately releases the ~5 GB of GPU memory back to your AMD RX 580 without needing PowerShell or terminal commands.
2. **Real-Time SSE Streaming Chat in Assistant View**:
   - Connected `AssistantView.tsx` to the backend `/api/v1/chat/completions` endpoint with `stream: true`.
   - Incoming response tokens render progressively into the chat bubble with sub-second time-to-first-token.
   - Includes an instant **[ Stop Generation ]** button wired to `AbortController`.
   - Includes an inline Unloaded Model Notice that prompts the user to load weights or automatically warms up the GPU on submit.
3. **Windows Subprocess Reliability & Log Isolation**:
   - Switched process spawning to native `subprocess.Popen` with non-blocking `.poll()` checks, resolving the Windows `NotImplementedError` raised under Uvicorn's `SelectorEventLoop`.
   - Relocated runtime logs outside `backend/` to root `data/llama_server.log` to stop Uvicorn's `WatchFiles` reloader from aborting model load mid-flight.
4. **Model Selection & Telemetry Alignment**:
   - Decoupled model selection in `ModelsView.tsx` so selecting library models (e.g. Gemma) preserves real metadata.
   - Fixed `CurrentModelHero.tsx` to display `0.0 GB VRAM`, `0 tokens in use (0%)`, and `Vulkan Offload (AMD RX 580)` when unloaded.
   - Replaced legacy Mac mock logs in `logsData.ts` with `AMD Radeon RX 580 (Vulkan)` entries.
5. **Frontend API & Context Layer**:
   - Authored typed service modules in `frontend/web/src/services/api/` (`client.ts`, `healthApi.ts`, `modelApi.ts`, `chatApi.ts`).
   - Created `BackendContext.tsx` with automatic 5-second health heartbeat polling and model state telemetry.
6. **Top Bar Status Badges in Header**:
   - Core Status: 🟢 `Core :8000` (Online) / 🔴 `Core Offline`.
   - VRAM Status: 🟢 `Loaded` / ⚪ `Free (0 MB)`.

---

## 2. Files Changed

- `backend/app/schemas/llm.py` — Added `ModelLoadRequest` and `ModelProfileUpdateRequest` schemas.
- `backend/app/services/llm/base.py` — Added abstract `set_profile()` method.
- `backend/app/services/llm/mock.py` — Implemented `set_profile()` and `unload_model()` for mock engine.
- `backend/app/services/llm/llama_cpp.py` — Added managed server process handling via `subprocess.Popen`, VRAM release on unload, dynamic profile switching, and unallocated model state.
- `backend/app/api/v1/endpoints/llm.py` — Exposed `POST /models/load`, `POST /models/unload`, and `PATCH /models/profile`.
- `backend/tests/test_llm.py` — Added 2 test cases covering model load, unload, and profile switching (33/33 backend tests passing).
- `frontend/web/src/services/api/client.ts` [NEW] — Resilient fetch client with configurable URL and pairing key auth.
- `frontend/web/src/services/api/healthApi.ts` [NEW] — Probe for `GET /api/v1/health` and `GET /api/v1/system/status`.
- `frontend/web/src/services/api/modelApi.ts` [NEW] — Model status, load, unload, and profile update endpoints.
- `frontend/web/src/services/api/chatApi.ts` [NEW] — Server-Sent Events (SSE) streaming reader for chat completions.
- `frontend/web/src/services/api/index.ts` [NEW] — Central API export barrel.
- `frontend/web/src/context/BackendContext.tsx` [NEW] — React Context & `useBackend()` hook with periodic status polling.
- `frontend/web/src/App.tsx` — Wrapped application with `<BackendProvider>`.
- `frontend/web/src/components/workspace/models/CurrentModelHero.tsx` — Added Load to VRAM, Unload VRAM, loading spinner, and dynamic unloaded telemetry.
- `frontend/web/src/components/workspace/ModelsView.tsx` — Decoupled model selection, live backend telemetry, and action triggers.
- `frontend/web/src/components/workspace/AssistantView.tsx` — Wired live SSE streaming chat, message history context, stop generation, and unloaded model guard.
- `frontend/web/src/components/layout/Header.tsx` — Added live Core :8000 and VRAM status pills.
- `frontend/web/src/mock/logsData.ts` — Updated mock logs to AMD Radeon RX 580 Vulkan entries.

---

## 3. How the Logic Works

### Event Trigger
When the user clicks **[ Unload VRAM ]** or **[ Load to VRAM ]** in `ModelsView`, or types a message in `AssistantView` and hits Enter:
1. `useBackend().unloadModel()` or `streamChatCompletion()` is triggered.

### Validation
- For model load/unload: Checks authentication against `COMPANION_API_KEY` via `verify_token`.
- For chat completions: Validates that messages list is non-empty and formatted with valid roles (`system`, `user`, `assistant`).

### Core Processing
- **Unload**:
  - `LlamaCppProvider` terminates the managed `llama-server.exe` process (or drops in-process weights), triggers Python garbage collection, and marks `is_loaded = False`.
  - AMD RX 580 VRAM usage drops by ~5 GB.
- **Streaming Chat**:
  - `chatApi.ts` sends a POST request with `stream: true`.
  - A `ReadableStreamDefaultReader` decodes binary chunks to UTF-8, buffers line breaks, extracts JSON deltas prefixed with `data:`, and invokes `onToken(delta.content)`.

### Completion
- When the stream receives `data: [DONE]`, the stream reader closes and the assistant state switches back to `'idle'`.

### Recovery / Cancellation
- If the user clicks **[ Stop ]**, the `AbortController` aborts the HTTP fetch signal, safely halting generation without corrupting the chat history.

---

## 4. Key Concepts

1. **Server-Sent Events (SSE) Streaming**: A lightweight unidirectional HTTP streaming protocol (`text/event-stream`) allowing the FastAPI server to send generated tokens to the browser as soon as each token is calculated by the GPU, providing instant responsiveness without polling.
2. **GPU VRAM Lifecycle Management**: Models like Qwen 2.5 7B require ~5 GB of memory. Holding weights in VRAM provides instant inference, but unloading them on demand allows other GPU-intensive tasks (gaming, rendering) to use the AMD RX 580 without restarting the companion platform.
3. **AbortController**: A standard browser Web API used to abort ongoing asynchronous tasks (such as streaming HTTP fetch requests) cleanly when the user clicks the "Stop Generation" button.

---

## 5. Verification Steps

### Automated Checks
```powershell
# 1. Backend tests
cd d:\OtherProjects\AI-companion-project\backend
.\.venv\Scripts\python -m pytest -v
# Output: 33 passed in 0.84s

# 2. Frontend typecheck
cd d:\OtherProjects\AI-companion-project\frontend\web
npm run lint
# Output: tsc --noEmit (0 errors)

# 3. Frontend production build
npm run build
# Output: vite build succeeded in 4.39s

# 4. Android regression check
cd d:\OtherProjects\AI-companion-project\android
.\gradlew.bat testDebugUnitTest
# Output: 124 passed in 1s
```

### Manual / User-Owned Checks
1. Ensure the FastAPI backend is running:
   ```powershell
   cd backend
   .\.venv\Scripts\python -m uvicorn app.main:app --port 8000 --reload
   ```
2. Start the Vite dev server:
   ```powershell
   cd frontend/web
   npm run dev
   ```
3. Open `http://localhost:3000` in your browser.
4. Check the top header: observe the 🟢 `Core :8000 Online` and `VRAM: Free (0 MB)` badges.
5. Navigate to **Local AI Models & Runtime**:
   - Click **[ Load to VRAM ]**: Watch the spinner and observe the badge change to 🟢 **Pinned in VRAM**.
   - Click **[ Unload VRAM ]**: Watch the badge change to ⚪ **Standby on Disk (VRAM Free)** and observe GPU VRAM drop to 0.
6. Navigate to **Assistant**:
   - Send prompt: *"Hello Aura, introduce yourself in 2 sentences."*
   - Watch the tokens stream progressively into the response bubble.
   - Click **[ Stop ]** during response to confirm generation halts immediately.

---

## 6. Safe Customization & Invariants

- **API Base URL**: Configurable in browser `localStorage` under `companion_api_url` (defaults to `http://127.0.0.1:8000`).
- **Pairing Key**: Stored in `localStorage` under `companion_api_key`. Must match `backend/.env`'s `COMPANION_API_KEY`.
- **Idle Timeout**: Set in `backend/app/core/config.py` (`LLM_IDLE_TIMEOUT_SECONDS = 900`, 15 minutes).

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
| :--- | :--- | :--- |
| Header shows `Core :8000 Offline` | FastAPI backend is not running on port 8000. | Run `uvicorn app.main:app --port 8000` from `backend/`. |
| "Authentication required" error in banner | Pairing key is missing or does not match `backend/.env`. | Paste the `COMPANION_API_KEY` from `backend/.env` directly into the input field on the error banner, or under **Settings** &rarr; **Network & Gateway**. |
| Model fails to load | `bin/llama-server.exe` or `models/*.gguf` not found. | Verify model file exists in `models/` (>100MB). |
