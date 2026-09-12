# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Completed & Verified
- Current Sprint: Track B4 — Local LLM Runtime Integration (`llama.cpp`, GGUF, Streaming Completions, Profiles, Auto-Unload)
- Target: Build abstract LLM provider, mock provider for weightless testing, GGUF/llama.cpp runner, SSE streaming chat completions, model status endpoint, and idle VRAM auto-unload.
- Scope Guard: `backend/`, `docs/`. Zero breaking changes; 100% backward compatible with existing endpoints.

## [CURRENT EXECUTION STATE - VERIFIED]

- Active Files: None
- Current Status: All Track B4 components implemented and verified. Full test suite passing (31/31 backend tests, 124/124 Android tests). Live SSE streaming verified on Uvicorn dev server. Ready for user verification with downloaded model.
- Next Action: Await user return from model download to test live GGUF inference on AMD RX 580.

## Active Checklist

- [x] Step 1: Configuration (`MODELS_DIR`, `LLM_PROVIDER`, `LLM_PROFILE`, `LLM_IDLE_TIMEOUT_SECONDS`) in `config.py`
- [x] Step 2: OpenAI-compatible Pydantic schemas (`ChatMessage`, `ChatCompletionRequest`, `ModelStatusResponse`)
- [x] Step 3: Base LLM provider interface (`BaseLLMProvider`)
- [x] Step 4: Mock LLM provider (`MockLLMProvider`) for instant testing & weightless CI
- [x] Step 5: Llama.cpp / GGUF provider (`LlamaCppProvider`) with GPU offload profiles and idle timer auto-unload
- [x] Step 6: Provider manager singleton (`LLMManager`) with auto-detection of models >100MB
- [x] Step 7: API endpoints (`GET /api/v1/models` and `POST /api/v1/chat/completions`)
- [x] Step 8: Mount under `protected_router` in `router.py`
- [x] Step 9: Author test suite in `tests/test_llm.py` and verify all tests pass (31/31 backend, 124/124 Android)





