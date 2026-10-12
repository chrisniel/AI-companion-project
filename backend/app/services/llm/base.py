"""Abstract base class for LLM providers."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, AsyncGenerator, Dict, List, Optional

if TYPE_CHECKING:
    from app.schemas.llm import ChatMessage, ModelStatusResponse


class GenerationStream:
    """Request-scoped token stream carrying completion metadata."""

    def __init__(
        self,
        token_iter: AsyncGenerator[str, None],
        meta: Optional[Dict[str, Any]] = None,
    ):
        self._iter = token_iter
        self._meta = meta if meta is not None else {"finish_reason": "stop"}

    @property
    def finish_reason(self) -> str:
        return self._meta.get("finish_reason", "stop")

    @finish_reason.setter
    def finish_reason(self, value: str) -> None:
        self._meta["finish_reason"] = value

    def __aiter__(self) -> GenerationStream:
        return self

    async def __anext__(self) -> str:
        return await self._iter.__anext__()

    async def aclose(self) -> None:
        if hasattr(self._iter, "aclose"):
            await self._iter.aclose()


class GeneratedText(str):
    """String result carrying request-scoped generation metadata."""
    finish_reason: str = "stop"

    def __new__(cls, content: str, finish_reason: str = "stop"):
        obj = super().__new__(cls, content)
        obj.finish_reason = finish_reason
        return obj


class BaseLLMProvider(ABC):
    """Contract for local and fallback LLM inference engines."""

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Return the unique identifier of the provider."""
        pass

    @property
    def last_finish_reason(self) -> Optional[str]:
        """Fallback finish reason. Use request-scoped stream.finish_reason for concurrent safety."""
        return getattr(self, "_last_finish_reason", "stop")

    @last_finish_reason.setter
    def last_finish_reason(self, value: Optional[str]) -> None:
        self._last_finish_reason = value

    @abstractmethod
    async def load_model(self, model_name: Optional[str] = None, profile: Optional[str] = None) -> bool:
        """Load or initialize model into memory/VRAM."""
        pass

    @abstractmethod
    async def unload_model(self) -> bool:
        """Unload model and free memory/VRAM."""
        pass

    @abstractmethod
    def is_loaded(self) -> bool:
        """Return True if model weights are currently resident in memory."""
        pass

    @abstractmethod
    async def set_profile(self, profile: str) -> bool:
        """Update hardware performance profile."""
        pass

    @abstractmethod
    async def get_status(self) -> ModelStatusResponse:
        """Return real-time model status and profile telemetry."""
        pass

    @abstractmethod
    async def generate(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> str:
        """Generate a complete synchronous response."""
        pass

    @abstractmethod
    async def generate_stream(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> AsyncGenerator[str, None]:
        """Generate a streaming sequence of tokens for Server-Sent Events."""
        pass

    async def shutdown(self) -> None:
        """Gracefully shutdown provider and free resources."""
        await self.unload_model()
