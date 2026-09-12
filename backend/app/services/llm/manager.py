"""LLM Provider Manager singleton with auto-detection and fallback."""

import logging
from typing import Optional

from app.core.config import settings
from app.services.llm.base import BaseLLMProvider
from app.services.llm.llama_cpp import LlamaCppProvider
from app.services.llm.mock import MockLLMProvider

logger = logging.getLogger("app.services.llm.manager")


class LLMManager:
    """Manages active LLM provider singleton lifecycle."""

    _instance: Optional["LLMManager"] = None
    _provider: Optional[BaseLLMProvider] = None

    def __new__(cls) -> "LLMManager":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def get_provider(self) -> BaseLLMProvider:
        """Resolve and return active provider based on settings and available models."""
        if self._provider is not None:
            return self._provider

        provider_mode = settings.LLM_PROVIDER.lower().strip()

        if provider_mode == "mock":
            logger.info("Explicit 'mock' LLM provider selected.")
            self._provider = MockLLMProvider()
        elif provider_mode == "llama_cpp":
            logger.info("Explicit 'llama_cpp' LLM provider selected.")
            self._provider = LlamaCppProvider()
        else:  # "auto"
            real_models = []
            if settings.MODELS_DIR.exists():
                real_models = [
                    f for f in settings.MODELS_DIR.glob("*.gguf")
                    if f.is_file() and f.name != "lfs-test.gguf" and f.stat().st_size > 100 * 1024 * 1024
                ]
            if real_models:
                logger.info(f"Real GGUF model detected ({real_models[0].name}). Engaging LlamaCppProvider.")
                self._provider = LlamaCppProvider()
            else:
                logger.info("No real GGUF weights detected (>100MB). Engaging MockLLMProvider.")
                self._provider = MockLLMProvider()

        return self._provider

    def set_provider(self, provider: BaseLLMProvider) -> None:
        """Override active provider (useful for testing or manual provider switching)."""
        self._provider = provider

    def reset(self) -> None:
        """Reset singleton provider instance."""
        self._provider = None


llm_manager = LLMManager()


def get_llm_provider() -> BaseLLMProvider:
    """FastAPI dependency yielding the active LLM provider."""
    return llm_manager.get_provider()
