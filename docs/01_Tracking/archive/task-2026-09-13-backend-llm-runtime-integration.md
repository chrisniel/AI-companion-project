# Archived Task: Local LLM Runtime Integration (Track B4)

- Completed Date: 2026-09-13
- Target: Build abstract LLM provider, mock provider for weightless testing, GGUF/llama.cpp runner, SSE streaming chat completions, model status endpoint, and Vulkan GPU offload on AMD RX 580.
- Verification: 31/31 backend pytest tests passing; 124/124 Android unit tests passing; live streaming verified on AMD RX 580 with `Qwen2.5-7B-Instruct-Q4_K_M.gguf`.

## Completed Checklist

### 1. Configuration & Settings (`backend/app/core/config.py`)
- [x] Added `MODELS_DIR`, `DEFAULT_MODEL_NAME`, `LLM_PROVIDER`, `LLM_PROFILE`, `LLM_IDLE_TIMEOUT_SECONDS`, `LLM_GPU_LAYERS`, `LLAMA_SERVER_URL`

### 2. Pydantic Schemas (`backend/app/schemas/llm.py`)
- [x] Defined OpenAI-compatible `ChatMessage`, `ChatCompletionRequest`, `ChatCompletionResponse`, `ChatCompletionStreamChunk`, `ModelStatusResponse`

### 3. Provider Architecture (`backend/app/services/llm/`)
- [x] Abstract interface `BaseLLMProvider` in `base.py`
- [x] High-speed deterministic `MockLLMProvider` in `mock.py` for CI and weightless testing
- [x] Dual-mode `LlamaCppProvider` in `llama_cpp.py` supporting standalone `llama-server.exe` (Vulkan) and in-process execution with 15-minute idle auto-unload
- [x] Singleton `LLMManager` in `manager.py` with automatic detection of real GGUF weights (>100MB)

### 4. API Endpoints (`backend/app/api/v1/endpoints/llm.py`)
- [x] Implemented `GET /api/v1/models` (model status, provider, GPU layers, device profile)
- [x] Implemented `POST /api/v1/chat/completions` (OpenAI-compatible synchronous completion and SSE streaming `text/event-stream`)
- [x] Mounted `llm_router` in `backend/app/api/v1/router.py`

### 5. Automated Testing & Verification (`backend/tests/test_llm.py`)
- [x] Added 5 unit/integration tests covering model status, mock completion, mock streaming, and request validation
- [x] Verified full backend suite: 31/31 tests passing in 0.86s
- [x] Verified Android test suite: 124/124 unit tests passing

### 6. Hardware Acceleration & Tooling
- [x] Downloaded Vulkan-enabled `llama-server.exe` to `bin/` (git-ignored)
- [x] Authored `scripts/start-model.ps1` for AMD RX 580 8GB offload (`-ngl 28 -c 4096 -t 6`)
- [x] Verified live inference with `Qwen2.5-7B-Instruct-Q4_K_M.gguf` (4.68 GB) on AMD RX 580 GPU: 32 tok/s prompt eval, 19 tok/s generation eval
