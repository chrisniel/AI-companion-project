"""Pydantic schemas for LLM chat completions, streaming chunks, and model status."""

from typing import Any, Dict, List, Literal, Optional, Union
from pydantic import Field
from app.schemas.common import BaseSchema
from app.schemas.multimodal import (
    ContentBlock,
    ImageAttachmentRef,
    ResolvedImageContent,
    TextContent,
)
from app.services.llm.runtime_state import LLMRuntimeState


class ChatMessage(BaseSchema):
    """Internal chat message used by orchestrator and provider layers."""
    role: Literal["system", "user", "assistant"]
    content: Union[str, List[ContentBlock]]


class ChatCompletionMessage(BaseSchema):
    """Public text-only chat message in OpenAI-compatible format."""
    role: Literal["system", "user", "assistant"]
    content: str


class ChatCompletionRequest(BaseSchema):
    """Request payload for /api/v1/chat/completions."""
    messages: List[ChatCompletionMessage] = Field(..., min_length=1)
    model: Optional[str] = None
    stream: bool = False
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    top_p: float = Field(default=0.9, ge=0.0, le=1.0)
    max_tokens: Optional[int] = Field(default=1024, ge=1, le=8192)
    profile: Optional[Literal["eco", "balanced", "maximum"]] = None


class ChatCompletionChoice(BaseSchema):
    """Individual completion choice."""
    index: int = 0
    message: ChatCompletionMessage
    finish_reason: Optional[str] = "stop"


class ChatCompletionUsage(BaseSchema):
    """Token usage counters."""
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0


class ChatCompletionResponse(BaseSchema):
    """OpenAI-compatible synchronous chat completion response."""
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[ChatCompletionChoice]
    usage: ChatCompletionUsage = Field(default_factory=ChatCompletionUsage)


class ChatCompletionDelta(BaseSchema):
    """Delta payload for streaming SSE responses."""
    role: Optional[str] = None
    content: Optional[str] = None


class ChatCompletionStreamChoice(BaseSchema):
    """Streaming choice container."""
    index: int = 0
    delta: ChatCompletionDelta
    finish_reason: Optional[str] = None


class ChatCompletionStreamChunk(BaseSchema):
    """Individual SSE chunk for streaming completions."""
    id: str
    object: str = "chat.completion.chunk"
    created: int
    model: str
    choices: List[ChatCompletionStreamChoice]


class ModelStatusResponse(BaseSchema):
    """
    Runtime inspection of active models, router lifecycle, and truthful applied hardware profiles.
    Phase 3 Truthful Telemetry Contract:
    - Distinguishes router process liveness (`router_running`) from model residency (`model_resident`).
    - Distinguishes requested profile configuration (`requested_profile`) from actually verified
      applied launch parameters (`applied_profile`, `applied_context_size`, `applied_gpu_layers`, `mmproj_offload`).
    - Expressive MODEL_SLEEPING semantics via dual fields:
        `model_loaded = True` (Logical model residency: worker process exists, model registered in router)
        `model_awake = False` (VRAM/Compute readiness: allocations unmapped while sleeping)
        `model_resident = False` (VRAM residency: GPU memory released while sleeping)
    """
    provider: str
    engine_version: Optional[str] = "b10936"

    # Router process state
    router_running: bool = False
    managed_by_core: bool = False
    runtime_state: LLMRuntimeState = LLMRuntimeState.SERVER_STOPPED

    # Model status & residency
    active_model: Optional[str] = None
    model_resident: bool = False   # Physical VRAM compute residency (True ONLY when MODEL_READY)
    model_loaded: bool = False     # Logical residency: worker exists, model registered in router (READY or SLEEPING)
    model_awake: bool = False      # GPU/RAM compute readiness (True for READY, False for SLEEPING)

    # Hardware profile & configurations: requested vs verified applied
    requested_profile: str = "balanced"
    applied_profile: Optional[str] = None
    applied_context_size: Optional[int] = None
    applied_gpu_layers: Optional[int] = None
    requested_mmproj_offload: bool = True           # True if requested profile config offloads mmproj to GPU; False if CPU
    applied_mmproj_offload: Optional[bool] = None   # Verified applied projector device on running router; null when stopped/pending

    # Activity & diagnostics
    generation_active: bool = False
    last_runtime_error: Optional[str] = None

    # Backward-compatibility fields (preserved for existing Web UI clients until Phase 4 reconciliation)
    mmproj_offload: bool = True             # Compatibility fallback: applied_mmproj_offload if applied else requested_mmproj_offload
    is_loaded: bool = False                 # Semantics: equivalent to model_loaded (True for READY or SLEEPING)
    active_profile: str = "balanced"        # Semantics: equivalent to requested_profile
    context_size: int = 4096                # Semantics: applied_context_size if applied, else requested profile default
    gpu_layers: int = 28                    # Semantics: applied_gpu_layers if applied, else requested profile default
    idle_timeout_seconds: int = 900         # Native sleep idle timeout in seconds
    seconds_until_idle: Optional[int] = None   # Native llama.cpp sleep countdown; 0 when MODEL_SLEEPING; null when unloaded/stopped
    seconds_until_unload: Optional[int] = None # Strictly null: auto-unload is disabled; native idle sleeps rather than unloads
    available_models: List[str] = []
    available_registry: Optional[List[str]] = None


class ModelLoadRequest(BaseSchema):
    """Payload to trigger loading a model into memory/VRAM."""
    model_name: Optional[str] = None
    profile: Optional[Literal["eco", "balanced", "maximum"]] = None


class ModelProfileUpdateRequest(BaseSchema):
    """Payload to update hardware profile."""
    profile: Literal["eco", "balanced", "maximum"]

