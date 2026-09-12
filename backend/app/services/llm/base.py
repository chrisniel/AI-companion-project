"""Abstract base class for LLM providers."""

from abc import ABC, abstractmethod
from typing import AsyncGenerator, Dict, List, Optional
from app.schemas.llm import ChatMessage, ModelStatusResponse


class BaseLLMProvider(ABC):
    """Contract for local and fallback LLM inference engines."""

    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Return the unique identifier of the provider."""
        pass

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
