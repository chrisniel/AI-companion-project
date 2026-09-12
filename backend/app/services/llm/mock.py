"""Mock LLM provider for rapid testing, CI pipelines, and weightless development."""

import asyncio
from datetime import datetime, timezone
from typing import AsyncGenerator, List, Optional

from app.core.config import settings
from app.schemas.llm import ChatMessage, ModelStatusResponse
from app.services.llm.base import BaseLLMProvider


class MockLLMProvider(BaseLLMProvider):
    """High-speed deterministic mock provider that simulates LLM generation and streaming."""

    def __init__(self):
        self._is_loaded = True
        self._active_model = settings.DEFAULT_MODEL_NAME
        self._active_profile = settings.LLM_PROFILE
        self._last_active_at = datetime.now(timezone.utc)

    @property
    def provider_name(self) -> str:
        return "mock"

    async def load_model(self, model_name: Optional[str] = None, profile: Optional[str] = None) -> bool:
        if model_name:
            self._active_model = model_name
        if profile:
            self._active_profile = profile
        self._is_loaded = True
        self._last_active_at = datetime.now(timezone.utc)
        return True

    async def unload_model(self) -> bool:
        self._is_loaded = False
        return True

    def is_loaded(self) -> bool:
        return self._is_loaded

    async def get_status(self) -> ModelStatusResponse:
        context_sizes = {"eco": 2048, "balanced": 4096, "maximum": 8192}
        gpu_layers = {"eco": 0, "balanced": settings.LLM_GPU_LAYERS, "maximum": 33}

        # Check for any .gguf files in models directory
        available = []
        if settings.MODELS_DIR.exists():
            available = [f.name for f in settings.MODELS_DIR.glob("*.gguf")]

        return ModelStatusResponse(
            provider=self.provider_name,
            is_loaded=self._is_loaded,
            active_model=self._active_model if self._is_loaded else None,
            active_profile=self._active_profile,
            available_models=available,
            context_size=context_sizes.get(self._active_profile, 4096),
            gpu_layers=gpu_layers.get(self._active_profile, settings.LLM_GPU_LAYERS),
            idle_timeout_seconds=settings.LLM_IDLE_TIMEOUT_SECONDS,
            seconds_until_unload=settings.LLM_IDLE_TIMEOUT_SECONDS if self._is_loaded else None,
        )

    async def generate(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> str:
        self._last_active_at = datetime.now(timezone.utc)
        last_user_msg = next((m.content for m in reversed(messages) if m.role == "user"), "Hello!")
        return f"[Mock AI Companion]: I received your message: '{last_user_msg}'. Local AI Core is operational."

    async def generate_stream(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> AsyncGenerator[str, None]:
        self._last_active_at = datetime.now(timezone.utc)
        last_user_msg = next((m.content for m in reversed(messages) if m.role == "user"), "Hello!")
        response_text = f"I received your message: '{last_user_msg}'. Local AI Core is operational."
        tokens = response_text.split(" ")

        for i, token in enumerate(tokens):
            yield token if i == 0 else f" {token}"
            await asyncio.sleep(0.01)  # Micro-delay to simulate streaming chunks
