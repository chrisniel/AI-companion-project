# Walkthrough: Local LLM Runtime Integration (Track B4)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Delivery of Track B4 Local LLM inference engine, supporting GGUF model execution on AMD RX 580 / CPU, OpenAI-compatible streaming completions, hardware performance profiles, and VRAM auto-unload.
- Audience: Developer, maintainer, QA
- Status: Implemented & Verified
- Last Updated: 2026-09-12

---

## 1. What Was Delivered

- **Abstract LLM Provider Architecture**:
  - `BaseLLMProvider` contract standardizing `load_model()`, `unload_model()`, `generate()`, and `generate_stream()`.
  - `MockLLMProvider` providing deterministic, high-speed simulated inference so CI and tests execute in <0.5s without requiring 5 GB model weights.
  - `LlamaCppProvider` with dual-mode execution: native integration with standalone `llama-server.exe` (with Vulkan GPU offload on AMD RX 580) and in-process `llama_cpp` bindings.
- **VRAM Lifecycle & Auto-Unload (Section 12)**:
  - Models load on-demand upon first user interaction (lazy loading).
  - Background monitor tracks activity and unloads model weights after 15 minutes of inactivity (`LLM_IDLE_TIMEOUT_SECONDS = 900`), returning VRAM to Windows for gaming and desktop applications.
- **Hardware Performance Profiles (Section 13)**:
  - `Eco`: 2048 context window, minimal CPU/VRAM load.
  - `Balanced`: 4096 context window, 28 GPU layers offloaded to RX 580 (target ~3.5–4.5 GB VRAM).
  - `Maximum`: 8192 context window, full offload of fitting layers.
- **OpenAI-Compatible Chat Completions**:
  - `POST /api/v1/chat/completions`: Supports standard message lists, synchronous JSON responses, and real-time Server-Sent Events (SSE) streaming (`stream: true`).
  - `GET /api/v1/models`: Inspects loaded status, active model, profile, and lists available `.gguf` files.
- **Auto-Detection & Fallback (`LLMManager`)**:
  - Automatically activates `LlamaCppProvider` when real `.gguf` model weights (>100 MB) exist in `models/`.
  - Gracefully falls back to `MockLLMProvider` when weights are still downloading, ensuring zero server crashes.

---

## 2. Files Changed

- `backend/app/core/config.py` — Added `MODELS_DIR`, `DEFAULT_MODEL_NAME`, `LLM_PROVIDER`, `LLM_PROFILE`, `LLM_IDLE_TIMEOUT_SECONDS`, `LLM_GPU_LAYERS`, and `LLAMA_SERVER_URL`.
- `backend/app/schemas/llm.py` — [NEW] Pydantic schemas for `ChatMessage`, `ChatCompletionRequest`, `ChatCompletionResponse`, `ChatCompletionStreamChunk`, and `ModelStatusResponse`.
- `backend/app/services/llm/base.py` — [NEW] Abstract `BaseLLMProvider` interface.
- `backend/app/services/llm/mock.py` — [NEW] Deterministic mock provider for tests and weightless CI.
- `backend/app/services/llm/llama_cpp.py` — [NEW] GGUF execution engine supporting standalone server, in-process execution, and auto-unload.
- `backend/app/services/llm/manager.py` — [NEW] Provider manager singleton with auto-detection.
- `backend/app/services/llm/__init__.py` — [NEW] Package exports.
- `backend/app/api/v1/endpoints/llm.py` — [NEW] Chat completions and model inspection routes.
- `backend/app/api/v1/router.py` — Mounted LLM endpoints under `protected_router`.
- `backend/tests/test_llm.py` — [NEW] Test suite for status, completion, SSE streaming, and auth.
- `CHANGELOG.md` — Documented Pass 6 under `## Unreleased`.
- `docs/01_Tracking/task.md` — Updated active tracking state.
- `docs/02_Planning/plan-backend-llm-runtime-integration.md` — Feature implementation plan.

---

## 3. How the Logic Works

1. **Event trigger**: Client submits a chat prompt (`POST /api/v1/chat/completions`) or checks status (`GET /api/v1/models`).
2. **Validation**:
   - Request must include a valid bearer token (`verify_token`).
   - `messages` list must contain at least one valid message (`role` and `content`).
3. **Core processing**:
   - The route requests the active provider from `LLMManager`.
   - If model is not in memory, lazy-loader initializes weights according to the active profile (`Eco`, `Balanced`, or `Maximum`).
   - If `stream == True`, an async generator yields individual token deltas formatted as Server-Sent Events (`data: {...}\n\n`).
   - If `stream == False`, the complete completion string is gathered and returned as an OpenAI-compatible JSON payload.
   - Activity timestamp is refreshed, restarting the 15-minute idle countdown.
4. **Completion**: Synchronous returns HTTP 200 JSON; streaming yields `data: [DONE]\n\n`.
5. **Recovery/cancellation**: If weights fail to load, a clear `500 Internal Server Error` with actionable instructions is returned rather than crashing the process.

---

## 4. Key Concepts

- **GGUF Format**: The universal binary format for quantized local AI models used by `llama.cpp`. Enables running 7B-parameter models in under 4.5 GB of VRAM.
- **Server-Sent Events (SSE)**: A lightweight HTTP streaming standard where the server pushes new token deltas to the client over a persistent connection (`text/event-stream`), enabling word-by-word conversational typing in the UI.
- **Lazy Loading & Idle Auto-Unload**: Preserving system memory by deferring weight allocation until the first user prompt, and discarding VRAM allocations after a period of inactivity.

---

## 5. Verification Steps

### Automated Checks

- [x] Backend Pytest Suite: `.\.venv\Scripts\python -m pytest` in `backend/` — **31/31 passed in 0.86s**.
- [x] LLM Test Suite: `.\.venv\Scripts\python -m pytest tests/test_llm.py` — **5/5 passed in 0.38s**.
- [x] Android Unit Tests: `.\gradlew.bat testDebugUnitTest` in `android/` — **124/124 passed in 1s**.
- [x] Vulkan Device Detection: `llama-server.exe --list-devices` successfully detected `Vulkan0: AMD Radeon RX 580 2048SP (8192 MiB)`.
- [x] Live Real GGUF Inference: Successfully loaded `Qwen2.5-7B-Instruct-Q4_K_M.gguf` with 28 GPU layers offloaded to Vulkan0 and generated live completions.
- [x] Real-time SSE Streaming: Verified token-by-token Server-Sent Events generation from RX 580 ending with `data: [DONE]`.

### Production Startup Helper

- [x] Created `scripts/start-model.ps1` to launch `llama-server.exe` with Vulkan GPU offload on AMD RX 580 automatically.

---

## 6. Safe Customization & Invariants

- **Tunable parameters**:
  - `LLM_IDLE_TIMEOUT_SECONDS`: Idle duration before VRAM auto-unload (default: 900s / 15 mins).
  - `LLM_PROFILE`: `"eco"`, `"balanced"`, or `"maximum"`.
  - `LLM_GPU_LAYERS`: Number of transformer layers offloaded to AMD RX 580 (default: 28).
- **Invariants**:
  - All chat completion and model endpoints must remain behind `verify_token` authentication.
  - Streaming endpoints must terminate with `data: [DONE]\n\n`.

---

## 7. Troubleshooting

- **Symptom**: Response contains `[Mock AI Companion]`.
  - **Likely cause**: No real GGUF model file (>100MB) was found in `models/` or provider is set to `mock`.
  - **Resolution**: Place `Qwen2.5-7B-Instruct-Q4_K_M.gguf` in `models/`.
- **Symptom**: `401 Unauthorized` on `/api/v1/chat/completions`.
  - **Likely cause**: Missing or invalid `Authorization: Bearer <token>` header.
  - **Resolution**: Ensure header contains the token from `.env`.
