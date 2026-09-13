# Implementation Plan: Local LLM Runtime Integration (Track B4)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Branch: `feature/backend-llm-runtime-integration`
Reference Architecture: `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` (Sections 11–14 & Track B4)

---

## 1. Executive Summary & Goals

This plan delivers the foundational local AI inference engine for the companion backend (Track B4):
1. **Abstract LLM Provider System**: Define a clean, decoupled provider interface (`BaseLLMProvider`) with `MockLLMProvider` (for lightning-fast headless tests and CI without requiring 5 GB weights) and `LlamaCppProvider` (for executing real quantized GGUF models on AMD RX 580 and CPU).
2. **Model Lifecycle & Auto-Unload (Section 12)**: Implement lazy loading (model loads on first prompt) and idle timeout auto-unloading (frees RX 580 VRAM after inactivity).
3. **Performance Profiles (Section 13)**: Expose `Eco`, `Balanced`, and `Maximum` configurations mapping context size (2048 to 8192) and GPU offload layers.
4. **Chat Completions API**: Provide OpenAI-compatible `POST /api/v1/chat/completions` with streaming Server-Sent Events (`text/event-stream`) and synchronous JSON fallback, alongside `GET /api/v1/models` for status inspection.

---

## 2. Scope & Acceptance Criteria

### LLM Provider Architecture
- **Provider Interface (`backend/app/services/llm/base.py`)**:
  - `generate(messages, options) -> ChatCompletionResponse`
  - `generate_stream(messages, options) -> AsyncGenerator[str, None]`
  - `load_model(model_name_or_path, profile) -> bool`
  - `unload_model() -> bool`
  - `get_status() -> ModelStatusResponse`
- **Mock Provider (`backend/app/services/llm/mock.py`)**:
  - Echoes simulated tokens with configurable delay; enables 100% of API endpoints and streaming pipelines to be verified without requiring physical GGUF weights.
- **Llama.cpp Provider (`backend/app/services/llm/llama_cpp.py`)**:
  - Loads GGUF models from `models/` directory.
  - Supports configurable GPU offload layers (`n_gpu_layers`) for Polaris RX 580 (Vulkan / OpenCL / CPU fallback).
  - Handles auto-unload after `IDLE_TIMEOUT_SECONDS` (default: 15 minutes).

### API Endpoints
- `GET /api/v1/models`:
  - Returns current model status (`is_loaded`, `active_model`, `profile`, `vram_usage_mb`), supported profiles, and available `.gguf` files found in `models/`.
- `POST /api/v1/chat/completions`:
  - Accepts standard chat messages `[{"role": "system|user|assistant", "content": "..."}]`.
  - Accepts `stream: bool = False`, `temperature: float = 0.7`, `max_tokens: int = 1024`.
  - When `stream: true`, yields `data: {"id": "...", "choices": [{"delta": {"content": "..."}}]}\n\n` ending with `data: [DONE]\n\n`.
  - Requires valid bearer authentication (`verify_token`).

### Hardware Profiles (RX 580 & CPU)
- `Eco`: Context 2048, low CPU threads, minimal VRAM reservation.
- `Balanced`: Context 4096, 24-28 GPU layers on RX 580 (8GB VRAM).
- `Maximum`: Context 8192, full offload of fitting layers.

---

## 3. Step-by-Step Implementation Flow & Pseudocode

### Step 1: Configuration & Schemas
```python
# backend/app/core/config.py
class Settings:
    MODELS_DIR: str = "models"
    DEFAULT_MODEL_NAME: str = "qwen2.5-7b-instruct-q4_k_m.gguf"
    LLM_PROVIDER: str = "mock"  # "mock" | "llama_cpp"
    LLM_PROFILE: str = "balanced"  # "eco" | "balanced" | "maximum"
    LLM_IDLE_TIMEOUT_SECONDS: int = 900  # 15 minutes
```

```python
# backend/app/schemas/llm.py
class ChatMessage(BaseSchema):
    role: Literal["system", "user", "assistant"]
    content: str

class ChatCompletionRequest(BaseSchema):
    messages: List[ChatMessage]
    stream: bool = False
    temperature: float = 0.7
    max_tokens: Optional[int] = 1024
    profile: Optional[str] = None

class ModelStatusResponse(BaseSchema):
    is_loaded: bool
    active_model: Optional[str]
    active_profile: str
    available_models: List[str]
    idle_timeout_seconds: int
```

### Step 2: Base Provider & Mock Implementation
```python
# backend/app/services/llm/base.py
class BaseLLMProvider(ABC):
    @abstractmethod
    async def generate(self, messages: List[ChatMessage], **kwargs) -> str: ...
    @abstractmethod
    async def generate_stream(self, messages: List[ChatMessage], **kwargs) -> AsyncGenerator[str, None]: ...
    @abstractmethod
    async def load(self, model_path: str, profile: str) -> bool: ...
    @abstractmethod
    async def unload(self) -> bool: ...
    @abstractmethod
    def status(self) -> dict: ...
```

### Step 3: Llama.cpp Provider with Auto-Unload Timer
- Safe dynamic import of `llama_cpp`. If library is not installed or model file does not exist, provide clear diagnostics without crashing FastAPI startup.
- Background idle timer: resets on every generation request; schedules `unload()` when timer reaches expiration.

### Step 4: Endpoints & Router Mounting
- Mount in `backend/app/api/v1/endpoints/llm.py` under `protected_router` (`/models` and `/chat/completions`).

### Step 5: Unit & Streaming Integration Tests
- Verify `GET /api/v1/models` returns model status.
- Verify `POST /api/v1/chat/completions` returns JSON when `stream=False`.
- Verify `POST /api/v1/chat/completions` yields valid SSE lines when `stream=True`.
- Verify 401 Unauthorized without bearer token.

---

## 4. Affected Files

- `backend/app/core/config.py` — Add model directory, provider, and profile settings.
- `backend/app/schemas/llm.py` — [NEW] OpenAI-compatible chat request/response schemas.
- `backend/app/services/llm/base.py` — [NEW] Abstract LLM provider interface.
- `backend/app/services/llm/mock.py` — [NEW] Mock provider for test/CI and weightless development.
- `backend/app/services/llm/llama_cpp.py` — [NEW] GGUF / llama.cpp provider with lifecycle management.
- `backend/app/services/llm/__init__.py` — [NEW] Provider factory and singleton manager.
- `backend/app/api/v1/endpoints/llm.py` — [NEW] Chat completion and model status endpoints.
- `backend/app/api/v1/router.py` — Mount LLM routes to `protected_router`.
- `backend/tests/test_llm.py` — [NEW] Test suite for status, completion, streaming, and auth.
- `docs/01_Tracking/task.md` — Active task tracking for Track B4.

---

## 5. Verification Plan

### Automated Tests
- `.\.venv\Scripts\python -m pytest tests/test_llm.py` — Verify all completion, streaming, status, and auth tests pass.
- `.\.venv\Scripts\python -m pytest` — Ensure all 26 existing tests remain green (total > 32 tests).
- `.\gradlew.bat testDebugUnitTest` in `android/` — Verify zero regression on mobile test suite.

### Manual Verification
- Test non-streaming completion via curl / PowerShell.
- Test SSE streaming token reception via curl.
- Verify model auto-unload timer triggers after idle timeout.
