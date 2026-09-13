"""LLM services package exporting provider base, implementations, and manager."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.services.llm.base import BaseLLMProvider
    from app.services.llm.llama_cpp import LlamaCppProvider
    from app.services.llm.manager import LLMManager, get_llm_provider, llm_manager
    from app.services.llm.mock import MockLLMProvider
    from app.services.llm.runtime_state import LLMRuntimeState

__all__ = [
    "BaseLLMProvider",
    "MockLLMProvider",
    "LlamaCppProvider",
    "LLMManager",
    "llm_manager",
    "get_llm_provider",
    "LLMRuntimeState",
]


def __getattr__(name: str):
    if name == "BaseLLMProvider":
        from app.services.llm.base import BaseLLMProvider
        return BaseLLMProvider
    if name == "LlamaCppProvider":
        from app.services.llm.llama_cpp import LlamaCppProvider
        return LlamaCppProvider
    if name in ("LLMManager", "get_llm_provider", "llm_manager"):
        from app.services.llm import manager
        return getattr(manager, name)
    if name == "MockLLMProvider":
        from app.services.llm.mock import MockLLMProvider
        return MockLLMProvider
    if name == "LLMRuntimeState":
        from app.services.llm.runtime_state import LLMRuntimeState
        return LLMRuntimeState
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
