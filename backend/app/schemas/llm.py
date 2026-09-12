"""Pydantic schemas for LLM chat completions, streaming chunks, and model status."""

from typing import Any, Dict, List, Literal, Optional
from pydantic import Field
from app.schemas.common import BaseSchema


class ChatMessage(BaseSchema):
    """Chat message in OpenAI-compatible format."""
    role: Literal["system", "user", "assistant"]
    content: str


class ChatCompletionRequest(BaseSchema):
    """Request payload for /api/v1/chat/completions."""
    messages: List[ChatMessage] = Field(..., min_length=1)
    model: Optional[str] = None
    stream: bool = False
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    top_p: float = Field(default=0.9, ge=0.0, le=1.0)
    max_tokens: Optional[int] = Field(default=1024, ge=1, le=8192)
    profile: Optional[Literal["eco", "balanced", "maximum"]] = None


class ChatCompletionChoice(BaseSchema):
    """Individual completion choice."""
    index: int = 0
    message: ChatMessage
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
    """Runtime inspection of active models and hardware profiles."""
    provider: str
    is_loaded: bool
    active_model: Optional[str] = None
    active_profile: str
    available_models: List[str]
    context_size: int
    gpu_layers: int
    idle_timeout_seconds: int
    seconds_until_unload: Optional[int] = None
