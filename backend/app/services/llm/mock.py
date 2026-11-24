"""Mock LLM provider for rapid testing, CI pipelines, and weightless development."""

import asyncio
from datetime import datetime, timezone
import os
from typing import Any, AsyncGenerator, List, Optional, Union

from app.core.config import settings
from app.schemas.llm import ChatMessage, ModelStatusResponse
from app.services.llm.base import (
    BaseLLMProvider,
    GeneratedText,
    GenerationStream,
    ResourceApplyOutcome,
)
from app.services.llm.runtime_state import LLMRuntimeState
from app.services.model_registry import (
    assess_context_options_for_entry,
    build_model_list,
    find_model_registry_entry,
    resolve_context_size_for_mode,
)


from app.services.hardware_probe import probe_host_hardware
from app.services.host_config import (
    VALID_CONTEXT_MODES,
    get_saved_context_mode,
    get_saved_model_selection,
    resolve_effective_model,
    save_model_selection,
)


def _extract_text_content(content: Union[str, List[Any]]) -> str:
    """Extract plain text from string or structured ContentBlock list."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        for block in content:
            if getattr(block, "type", None) == "text":
                return getattr(block, "text", "")
            if isinstance(block, dict) and block.get("type") == "text":
                return block.get("text", "")
    return ""


class MockLLMProvider(BaseLLMProvider):
    """High-speed deterministic mock provider that simulates LLM generation and streaming."""

    def __init__(self, default_model: Optional[str] = None):
        self._is_loaded = False
        self._active_model = None
        self._default_mock_model = default_model
        self._active_profile = settings.LLM_PROFILE
        self._context_mode = get_saved_context_mode()
        self._last_active_at = datetime.now(timezone.utc)
        self._last_error: Optional[str] = None
        self.scripted_turns: List[Any] = []
        self._lock = asyncio.Lock()
        self._has_active_generation = False
        self._resource_low_impact_active = False
        self._resource_strategy = "cpu_eco"
        self._resource_lightweight_model_id: Optional[str] = None
        self._resource_degradation_reason: Optional[str] = None
        self._applied_profile: Optional[str] = None

    @property
    def has_active_generation(self) -> bool:
        return self._has_active_generation

    def _effective_profile_name(self) -> str:
        if self._resource_low_impact_active and (
            self._resource_strategy == "cpu_eco"
            or (self._resource_strategy == "lightweight_model" and self._resource_degradation_reason is not None)
        ):
            return "eco"
        return self._active_profile

    def _effective_model_name(self, explicit_model: Optional[str] = None) -> Optional[str]:
        if explicit_model:
            return explicit_model
        if (
            self._resource_low_impact_active
            and self._resource_strategy == "lightweight_model"
            and self._resource_degradation_reason is None
            and self._resource_lightweight_model_id
        ):
            return self._resource_lightweight_model_id
        return None

    async def apply_resource_policy(
        self,
        *,
        low_impact_active: bool,
        strategy: str,
        lightweight_model_id: Optional[str] = None,
    ) -> ResourceApplyOutcome:
        if self.has_active_generation:
            return ResourceApplyOutcome(applied=False, deferred_reason="deferred_active_turn")
        if self._lock.locked():
            return ResourceApplyOutcome(applied=False, deferred_reason="deferred_model_load")

        async with self._lock:
            was_active = self._resource_low_impact_active
            prev_strategy = self._resource_strategy
            prev_model = self._resource_lightweight_model_id

            degradation_reason: Optional[str] = None
            resolved_model_id: Optional[str] = None
            if low_impact_active and strategy == "lightweight_model":
                if not lightweight_model_id:
                    degradation_reason = "lightweight_model_missing"
                else:
                    entry = find_model_registry_entry(lightweight_model_id)
                    if entry is None or not entry.library_state.primary_file_exists:
                        degradation_reason = "lightweight_model_unavailable"
                    else:
                        resolved_model_id = entry.runtime_model_id or entry.manifest.id

            self._resource_low_impact_active = bool(low_impact_active)
            self._resource_strategy = strategy
            self._resource_lightweight_model_id = resolved_model_id or lightweight_model_id
            self._resource_degradation_reason = degradation_reason

            if low_impact_active:
                if not was_active or prev_strategy != strategy or prev_model != self._resource_lightweight_model_id:
                    if self._is_loaded:
                        await self.unload_model()
                elif strategy == "unload_when_idle" and self._is_loaded:
                    idle_elapsed = (datetime.now(timezone.utc) - self._last_active_at).total_seconds()
                    if idle_elapsed >= settings.RESOURCE_LOW_IMPACT_IDLE_SECONDS:
                        await self.unload_model()
            elif was_active and self._is_loaded:
                # Lazy exit: free overridden lightweight/eco session; never eagerly reload heavy model.
                await self.unload_model()

            eff_profile = self._effective_profile_name()
            return ResourceApplyOutcome(
                applied=True,
                effective_profile=eff_profile,
                degradation_reason=degradation_reason,
            )

    def get_resource_override_status(self) -> dict[str, Any]:
        return {
            "low_impact_active": self._resource_low_impact_active,
            "strategy": self._resource_strategy,
            "lightweight_model_id": self._resource_lightweight_model_id,
            "effective_profile": self._effective_profile_name(),
            "degradation_reason": self._resource_degradation_reason,
        }

    @property
    def provider_name(self) -> str:
        return "mock"

    async def load_model(self, model_name: Optional[str] = None, profile: Optional[str] = None) -> bool:
        eff_profile = profile or self._effective_profile_name()
        eff_target_hint = self._effective_model_name(model_name)
        if self._is_loaded and model_name is None and (eff_target_hint is None or eff_target_hint == self._active_model) and self._applied_profile == eff_profile:
            self._last_active_at = datetime.now(timezone.utc)
            return True

        target, source = resolve_effective_model(eff_target_hint)
        if not target and self._default_mock_model:
            target = self._default_mock_model
            source = "mock_configuration"

        if not target:
            self._is_loaded = False
            self._active_model = None
            self._last_error = "MODEL_SELECTION_REQUIRED"
            return False

        self._active_model = target
        if profile:
            self._active_profile = profile
        self._applied_profile = self._effective_profile_name()
        self._is_loaded = True
        self._last_error = None
        self._last_active_at = datetime.now(timezone.utc)
        return True

    async def unload_model(self) -> bool:
        self._is_loaded = False
        self._active_model = None
        self._applied_profile = None
        return True

    async def set_profile(
        self,
        profile: str,
        context_mode: Optional[str] = None,
    ) -> bool:
        self._active_profile = profile
        if context_mode is not None:
            normalized = context_mode.strip().lower()
            if normalized not in VALID_CONTEXT_MODES:
                return False
            self._context_mode = normalized
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

        all_entries = build_model_list()
        registry_entries = [m.manifest.primary_file for m in all_entries if m.library_state.primary_file_exists]

        saved_selection = get_saved_model_selection()
        selected_entry = find_model_registry_entry(
            self._active_model or saved_selection,
            entries=all_entries,
        )
        raw_entry_ctx = (
            getattr(getattr(selected_entry, "manifest", None), "model_max_context", None)
            if selected_entry is not None
            else None
        )
        entry_max_ctx = (
            raw_entry_ctx
            if isinstance(raw_entry_ctx, int) and not isinstance(raw_entry_ctx, bool)
            else None
        )
        is_loaded = self._is_loaded
        eff_profile = self._effective_profile_name()
        applied_ctx = resolve_context_size_for_mode(
            context_sizes.get(eff_profile, 4096),
            self._context_mode,
            model_max_context=entry_max_ctx,
        )
        applied_ngl = gpu_layers.get(eff_profile, settings.LLM_GPU_LAYERS)
        is_eco = eff_profile == "eco"
        mmproj_flag = not is_eco
        hw = probe_host_hardware()
        context_options = assess_context_options_for_entry(
            selected_entry,
            profile=self._active_profile,
            dedicated_vram_gb=hw.dedicated_vram_gb,
            total_ram_gb=hw.total_ram_gb,
        )

        if is_loaded:
            runtime_state = LLMRuntimeState.MODEL_READY
        elif self._last_error == "MODEL_SELECTION_REQUIRED":
            runtime_state = LLMRuntimeState.MODEL_SELECTION_REQUIRED
        elif self._last_error:
            runtime_state = LLMRuntimeState.MODEL_ERROR
        elif not saved_selection and not os.environ.get("COMPANION_DEV_MODEL"):
            runtime_state = LLMRuntimeState.MODEL_SELECTION_REQUIRED
        else:
            runtime_state = LLMRuntimeState.MODEL_UNLOADED

        return ModelStatusResponse(
            provider=self.provider_name,
            engine_version="mock-v1",
            router_running=True,
            managed_by_core=True,
            runtime_state=runtime_state,
            active_model=self._active_model if is_loaded else None,
            selected_model=saved_selection,
            model_resident=is_loaded,
            model_loaded=is_loaded,
            model_awake=is_loaded,
            requested_profile=self._active_profile,
            requested_context_mode=self._context_mode,
            context_options=context_options,
            applied_profile=eff_profile,
            applied_context_size=applied_ctx,
            applied_gpu_layers=applied_ngl,
            requested_mmproj_offload=mmproj_flag,
            applied_mmproj_offload=mmproj_flag,
            host_gpu_name=hw.gpu_name,
            host_vram_gb=hw.dedicated_vram_gb,
            host_ram_gb=hw.total_ram_gb,
            mmproj_offload=mmproj_flag,
            generation_active=False,
            last_runtime_error=self._last_error,
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
        target_reason = getattr(self, "configured_finish_reason", "stop") or "stop"
        self.last_finish_reason = target_reason
        raw_user_msg = next((m.content for m in reversed(messages) if m.role == "user"), "Hello!")
        last_user_msg = _extract_text_content(raw_user_msg) if raw_user_msg != "Hello!" else "Hello!"
        content = f"[Mock AI Companion]: I received your message: '{last_user_msg}'. Local AI Runtime is operational."
        return GeneratedText(content, finish_reason=target_reason)

    def generate_stream(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> GenerationStream:
        self._last_active_at = datetime.now(timezone.utc)

        reason = "stop"
        conv_id = kwargs.get("conversation_id")
        if hasattr(self, "configured_finish_reasons") and isinstance(self.configured_finish_reasons, dict):
            if conv_id and conv_id in self.configured_finish_reasons:
                reason = self.configured_finish_reasons[conv_id]
            else:
                raw_user = next((m.content for m in reversed(messages) if m.role == "user"), "")
                text_user = _extract_text_content(raw_user)
                for key, val in self.configured_finish_reasons.items():
                    if key in text_user:
                        reason = val
                        break
        elif callable(getattr(self, "configured_finish_reason", None)):
            reason = self.configured_finish_reason(messages, **kwargs)
        elif getattr(self, "configured_finish_reason", None):
            reason = self.configured_finish_reason
        elif "finish_reason" in kwargs:
            reason = kwargs["finish_reason"]

        self.last_finish_reason = reason
        stream_meta: dict[str, Any] = {"finish_reason": reason}

        scripted = self.scripted_turns.pop(0) if self.scripted_turns else None
        if isinstance(scripted, dict):
            if "tool_calls" in scripted:
                stream_meta["tool_calls"] = list(scripted["tool_calls"])
                stream_meta["finish_reason"] = scripted.get("finish_reason", "tool_calls")
                self.last_finish_reason = stream_meta["finish_reason"]

        async def _stream_generator() -> AsyncGenerator[str, None]:
            if isinstance(scripted, dict):
                text_out = str(scripted.get("text") or "")
                if text_out:
                    for i, token in enumerate(text_out.split(" ")):
                        yield token if i == 0 else f" {token}"
                        await asyncio.sleep(0.005)
                return

            if isinstance(scripted, str):
                tokens = scripted.split(" ")
                for i, token in enumerate(tokens):
                    yield token if i == 0 else f" {token}"
                    await asyncio.sleep(0.005)
                return

            raw_user_msg = next((m.content for m in reversed(messages) if m.role == "user"), "Hello!")
            last_user_msg = _extract_text_content(raw_user_msg) if raw_user_msg != "Hello!" else "Hello!"
            response_text = f"I received your message: '{last_user_msg}'. Local AI Runtime is operational."
            tokens = response_text.split(" ")

            for i, token in enumerate(tokens):
                yield token if i == 0 else f" {token}"
                await asyncio.sleep(0.01)  # Micro-delay to simulate streaming chunks

        return GenerationStream(_stream_generator(), meta=stream_meta)
