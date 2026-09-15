"""Mock LLM provider for rapid testing, CI pipelines, and weightless development."""

import asyncio
from datetime import datetime, timezone
from typing import AsyncGenerator, List, Optional

from app.core.config import settings
from app.schemas.llm import ChatMessage, ModelStatusResponse
from app.services.llm.base import BaseLLMProvider
from app.services.llm.runtime_state import LLMRuntimeState
from app.services.model_registry import build_model_list


class MockLLMProvider(BaseLLMProvider):
    """High-speed deterministic mock provider that simulates LLM generation and streaming."""

    def __init__(self):
        self._is_loaded = False
        self._active_model = None
        self._active_profile = settings.LLM_PROFILE
        self._last_active_at = datetime.now(timezone.utc)

    @property
    def provider_name(self) -> str:
        return "mock"

    async def load_model(self, model_name: Optional[str] = None, profile: Optional[str] = None) -> bool:
        if model_name:
            self._active_model = model_name
        elif not self._active_model:
            self._active_model = settings.DEFAULT_MODEL_NAME
        if profile:
            self._active_profile = profile
        self._is_loaded = True
        self._last_active_at = datetime.now(timezone.utc)
        return True

    async def unload_model(self) -> bool:
        self._is_loaded = False
        self._active_model = None
        return True

    async def set_profile(self, profile: str) -> bool:
        self._active_profile = profile
        return True

    def is_loaded(self) -> bool:
        return self._is_loaded

    async def get_status(self) -> ModelStatusResponse:
        context_sizes = {"eco": 2048, "balanced": 4096, "maximum": 8192}
        gpu_layers = {"eco": 0, "balanced": settings.LLM_GPU_LAYERS, "maximum": 33}

        # Check for any .gguf files in models directory
        available = []
        if settings.MODELS_DIR.exists():
            available = [
                f.relative_to(settings.MODELS_DIR).as_posix()
                for f in settings.MODELS_DIR.rglob("*.gguf")
                if f.is_file() and f.name != "lfs-test.gguf" and not f.name.startswith("mmproj") and f.stat().st_size > 100 * 1024 * 1024
            ]

        registry_entries = [m.primary_file for m in build_model_list() if m.primary_file_exists]

        is_loaded = self._is_loaded
        applied_ctx = context_sizes.get(self._active_profile, 4096)
        applied_ngl = gpu_layers.get(self._active_profile, settings.LLM_GPU_LAYERS)
        is_eco = self._active_profile == "eco"
        mmproj_flag = not is_eco

        return ModelStatusResponse(
            provider=self.provider_name,
            engine_version="mock-v1",
            router_running=True,
            managed_by_core=True,
            runtime_state=LLMRuntimeState.MODEL_READY if is_loaded else LLMRuntimeState.MODEL_UNLOADED,
            active_model=self._active_model if is_loaded else None,
            model_resident=is_loaded,
            model_loaded=is_loaded,
            model_awake=is_loaded,
            requested_profile=self._active_profile,
            applied_profile=self._active_profile,
            applied_context_size=applied_ctx,
            applied_gpu_layers=applied_ngl,
            requested_mmproj_offload=mmproj_flag,
            applied_mmproj_offload=mmproj_flag,
            mmproj_offload=mmproj_flag,
            generation_active=False,
            last_runtime_error=None,
            is_loaded=is_loaded,
            active_profile=self._active_profile,
            available_models=available,
            available_registry=registry_entries,
            context_size=applied_ctx,
            gpu_layers=applied_ngl,
            idle_timeout_seconds=settings.LLAMA_ROUTER_IDLE_TIMEOUT,
            seconds_until_idle=settings.LLAMA_ROUTER_IDLE_TIMEOUT if is_loaded else None,
            seconds_until_unload=None,
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
        return f"[Mock AI Companion]: I received your message: '{last_user_msg}'. Local AI Runtime is operational."

    async def generate_stream(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> AsyncGenerator[str, None]:
        self._last_active_at = datetime.now(timezone.utc)
        last_user_msg = next((m.content for m in reversed(messages) if m.role == "user"), "Hello!")
        response_text = f"I received your message: '{last_user_msg}'. Local AI Runtime is operational."
        tokens = response_text.split(" ")

        for i, token in enumerate(tokens):
            yield token if i == 0 else f" {token}"
            await asyncio.sleep(0.01)  # Micro-delay to simulate streaming chunks
