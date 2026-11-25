"""Llama.cpp / GGUF local model execution provider with VRAM lifecycle management."""

import asyncio
import base64
from datetime import datetime, timezone
import gc
import importlib
import inspect
import json
import logging
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, AsyncGenerator, Callable, Dict, List, Optional

import httpx

from app.core.config import settings
from app.schemas.llm import ChatMessage, ModelStatusResponse
from app.schemas.multimodal import ContentBlock, ResolvedImageContent, TextContent
from app.services.hardware_probe import probe_host_hardware
from app.services.host_config import (
    VALID_CONTEXT_MODES,
    get_saved_context_mode,
    get_saved_hardware_profile,
    get_saved_model_selection,
    resolve_effective_model,
    save_context_mode,
    save_hardware_profile,
    save_model_selection,
)
from app.services.llm.base import (
    BaseLLMProvider,
    GeneratedText,
    GenerationStream,
    ProviderShutdownResult,
    ResourceApplyOutcome,
)
from app.services.llm.runtime_state import LLMRuntimeState
from app.services.model_registry import (
    assess_context_options_for_entry,
    build_model_list,
    find_model_registry_entry,
    resolve_context_size_for_mode,
    resolve_runtime_model_id,
)

logger = logging.getLogger("app.services.llm.llama_cpp")


class ProviderGenerationError(RuntimeError):
    """Internal generation failure with a safe diagnostic code, never upstream data."""


def _accumulate_tool_call_deltas(
    acc: dict[int, dict[str, Any]],
    deltas: list[Any],
) -> None:
    """Assemble OpenAI streaming tool_calls chunks indexed by tool slot index."""
    for entry in deltas:
        if not isinstance(entry, dict):
            continue
        idx = int(entry.get("index", 0))
        slot = acc.setdefault(
            idx,
            {
                "id": "",
                "type": "function",
                "function": {"name": "", "arguments": ""},
            },
        )
        if isinstance(entry.get("id"), str) and entry["id"]:
            slot["id"] = entry["id"]
        if isinstance(entry.get("type"), str) and entry["type"]:
            slot["type"] = entry["type"]
        fn = entry.get("function")
        if isinstance(fn, dict):
            if isinstance(fn.get("name"), str):
                slot["function"]["name"] += fn["name"]
            if isinstance(fn.get("arguments"), str):
                slot["function"]["arguments"] += fn["arguments"]


def _decode_stream_event(event: str, data: str) -> tuple[str, bool, Optional[str]]:
    token, done, reason, _ = _decode_stream_payload(event, data)
    return token, done, reason


def _decode_stream_payload(
    event: str,
    data: str,
) -> tuple[str, bool, Optional[str], Optional[list[Any]]]:
    """Decode llama-server's OpenAI-compatible SSE payload and explicit errors."""
    if event == "error":
        raise ProviderGenerationError("UPSTREAM_GENERATION_ERROR")
    if data == "[DONE]":
        return "", True, None, None
    try:
        chunk = json.loads(data)
    except (ValueError, TypeError):
        raise ProviderGenerationError("UPSTREAM_PROTOCOL_ERROR") from None
    if not isinstance(chunk, dict):
        raise ProviderGenerationError("UPSTREAM_PROTOCOL_ERROR")
    if "error" in chunk:
        raise ProviderGenerationError("UPSTREAM_GENERATION_ERROR")
    choices = chunk.get("choices")
    # Usage-only frames and role-only deltas carry no text, but are valid protocol.
    if choices == [] and isinstance(chunk.get("usage"), dict):
        return "", False, None, None
    if not isinstance(choices, list) or len(choices) != 1 or not isinstance(choices[0], dict):
        raise ProviderGenerationError("UPSTREAM_PROTOCOL_ERROR")
    choice = choices[0]
    delta = choice.get("delta")
    reason = choice.get("finish_reason")
    if reason is not None and reason not in ("stop", "length", "tool_calls", "function_call", "content_filter"):
        raise ProviderGenerationError("UPSTREAM_PROTOCOL_ERROR")
    if not isinstance(delta, dict):
        raise ProviderGenerationError("UPSTREAM_PROTOCOL_ERROR")
    token = delta.get("content")
    if token is not None and not isinstance(token, str):
        raise ProviderGenerationError("UPSTREAM_PROTOCOL_ERROR")
    raw_tool_calls = delta.get("tool_calls")
    if raw_tool_calls is not None and not isinstance(raw_tool_calls, list):
        raise ProviderGenerationError("UPSTREAM_PROTOCOL_ERROR")
    return token or "", False, reason, raw_tool_calls


async def _server_stream_tokens(
    response: httpx.Response,
    on_finish: Optional[Callable[[str], None]] = None,
    on_tool_calls: Optional[Callable[[list[Any]], None]] = None,
) -> AsyncGenerator[str, None]:
    if not response.is_success:
        raise ProviderGenerationError("UPSTREAM_HTTP_ERROR")
    event = ""
    data: list[str] = []
    async for line in response.aiter_lines():
        if not line:
            if data or event == "error":
                token, done, finish_reason, raw_tc = _decode_stream_payload(event, "\n".join(data))
                if raw_tc and on_tool_calls:
                    on_tool_calls(raw_tc)
                if finish_reason and on_finish:
                    on_finish(finish_reason)
                if token:
                    yield token
                if done:
                    return
            event, data = "", []
        elif line.startswith("data:"):
            data.append(line[5:].removeprefix(" "))
        elif line.startswith("event:"):
            event = line[6:].strip()
        # SSE comments, id and retry fields are non-terminal metadata.
    if data or event == "error":
        token, done, finish_reason, raw_tc = _decode_stream_payload(event, "\n".join(data))
        if raw_tc and on_tool_calls:
            on_tool_calls(raw_tc)
        if finish_reason and on_finish:
            on_finish(finish_reason)
        if token:
            yield token
        if done:
            return
    # EOF without the protocol completion marker is truncation, even after tokens.
    raise ProviderGenerationError("UPSTREAM_PROTOCOL_ERROR")


def _translate_messages(messages: List[ChatMessage]) -> list[dict[str, Any]]:
    """Translate internal ChatMessage objects to llama.cpp OpenAI-compatible wire payload.

    Fails closed on unexpected content types or unsupported MIME types.
    Pure translator: no DB access, no filesystem access, no attachment IDs or paths.
    """
    wire_messages = []
    for m in messages:
        if m.content is None or isinstance(m.content, str):
            msg_dict: dict[str, Any] = {"role": m.role, "content": m.content or ""}
            if getattr(m, "tool_calls", None):
                msg_dict["tool_calls"] = m.tool_calls
            if getattr(m, "tool_call_id", None):
                msg_dict["tool_call_id"] = m.tool_call_id
            if getattr(m, "name", None):
                msg_dict["name"] = m.name
            wire_messages.append(msg_dict)
        elif isinstance(m.content, list):
            wire_parts = []
            for block in m.content:
                block_type = getattr(block, "type", None)
                if block_type == "text":
                    wire_parts.append({"type": "text", "text": block.text})
                elif block_type == "image_bytes":
                    if block.mime_type not in ("image/png", "image/jpeg"):
                        raise ValueError(f"Unsupported image MIME type for wire translation: {block.mime_type}")
                    b64_str = base64.b64encode(block.data).decode("ascii")
                    wire_parts.append({
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{block.mime_type};base64,{b64_str}",
                        },
                    })
                else:
                    raise TypeError(f"Unsupported content block type: {type(block)}")
            wire_messages.append({"role": m.role, "content": wire_parts})
        else:
            raise TypeError(f"Unsupported message content type: {type(m.content)}")
    return wire_messages


def _merge_wire_content(existing: Any, extra_text: str) -> Any:
    """Append text safely onto either string or multimodal list wire content."""
    addition = extra_text.strip()
    if not addition:
        return existing
    if isinstance(existing, list):
        return [*existing, {"type": "text", "text": addition}]
    base = str(existing or "").strip()
    return f"{base}\n\n{addition}" if base else addition


def _flatten_tool_messages_for_strict_template(
    wire_messages: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Collapse OpenAI tool_calls/tool messages into strictly alternating user/assistant turns.

    Models whose GGUF Jinja templates enforce strict user/assistant alternation without
    native `role: "tool"` support (such as Gemma 3) reject raw OpenAI tool histories with HTTP 400.
    """
    system_parts: list[str] = []
    turns: list[dict[str, Any]] = []
    folded_any_tool = False

    def _append_turn(role: str, content: Any) -> None:
        if turns and turns[-1]["role"] == role:
            if isinstance(content, list):
                existing = turns[-1]["content"]
                if isinstance(existing, list):
                    turns[-1]["content"] = [*existing, *content]
                else:
                    turns[-1]["content"] = [
                        {"type": "text", "text": str(existing or "")},
                        *content,
                    ] if str(existing or "").strip() else list(content)
            else:
                turns[-1]["content"] = _merge_wire_content(
                    turns[-1]["content"], str(content or "")
                )
        else:
            turns.append({"role": role, "content": content})

    for m in wire_messages:
        role = str(m.get("role") or "user").strip().lower()
        content = m.get("content")
        if role == "system":
            if isinstance(content, str) and content.strip():
                system_parts.append(content.strip())
            continue
        if role == "tool":
            folded_any_tool = True
            tool_name = str(m.get("name") or "tool")
            tool_text = f"[Verified Tool Result ({tool_name})]: {content or ''}"
            _append_turn("user", tool_text)
            continue
        if role == "assistant":
            has_text = (
                bool(content.strip())
                if isinstance(content, str)
                else bool(content)
            )
            if m.get("tool_calls") and not has_text:
                # Drop empty assistant tool_calls stub before appending folded user tool results.
                continue
            _append_turn("assistant", content if content is not None else "")
            continue
        _append_turn("user", content if content is not None else "")

    if folded_any_tool and turns and turns[-1]["role"] == "user":
        turns[-1]["content"] = _merge_wire_content(
            turns[-1]["content"],
            "Use only the verified tool results above to answer the user's request naturally in plain local language.",
        )

    out: list[dict[str, Any]] = []
    if system_parts:
        out.append({"role": "system", "content": "\n\n".join(system_parts)})
    out.extend(turns)
    return out


class LlamaCppProvider(BaseLLMProvider):
    """Local GGUF model execution engine powered by llama.cpp.
    
    Supports dual execution modes:
    1. Standalone `llama-server.exe` (with Vulkan GPU offload on AMD RX 580).
    2. Direct in-process `llama-cpp-python` bindings.
    
    Includes lazy loading, hardware profile mapping (Section 13),
    and idle timeout auto-unloading to preserve VRAM (Section 12).
    """

    def __init__(self):
        self._llm = None
        self._server_client: Optional[httpx.AsyncClient] = None
        self._server_process: Optional[subprocess.Popen] = None
        self._server_pid: Optional[int] = None
        self._server_launch_args: list = []
        self._server_started_at: Optional[datetime] = None
        self._managed_by_core: bool = False
        self._server_is_active: bool = False
        self._active_model_name: Optional[str] = None
        self._active_models_dir: Optional[Path] = None
        self._active_profile: str = get_saved_hardware_profile() or settings.LLM_PROFILE  # Requested profile
        self._context_mode: str = get_saved_context_mode()
        self._applied_profile: Optional[str] = None       # Verified applied launch profile
        self._applied_context_size: Optional[int] = None
        self._applied_gpu_layers: Optional[int] = None
        self._applied_mmproj_offload: Optional[bool] = None
        self._last_active_at: Optional[datetime] = None
        self._last_error: Optional[str] = None
        self._idle_check_task: Optional[asyncio.Task] = None
        self._lock = asyncio.Lock()
        self._runtime_state: LLMRuntimeState = LLMRuntimeState.SERVER_STOPPED
        self._active_generations: set[object] = set()
        self._active_work_drained = asyncio.Event()
        self._active_work_drained.set()
        self._worker_tasks: set[asyncio.Task] = set()
        self._closing = False
        self._shutdown_event = asyncio.Event()
        self._active_load_task: Optional[asyncio.Task] = None
        self._active_router_clients: set[httpx.AsyncClient] = set()
        self._shutdown_drain_timeout = 120.0
        self._custom_engine_version: Optional[str] = None
        self._resource_low_impact_active: bool = False
        self._resource_strategy: str = "cpu_eco"
        self._resource_lightweight_model_id: Optional[str] = None
        self._resource_resolved_lightweight_id: Optional[str] = None
        self._resource_degradation_reason: Optional[str] = None
        self._resource_using_temporary_model: bool = False

    def _effective_strategy(self) -> str:
        if not self._resource_low_impact_active:
            return "normal"
        if self._resource_strategy == "lightweight_model" and self._resource_degradation_reason is not None:
            return "cpu_eco"
        return self._resource_strategy

    def _effective_profile_name(self) -> str:
        if self._resource_low_impact_active and self._effective_strategy() == "cpu_eco":
            return "eco"
        return self._active_profile

    def _effective_model_name(self, explicit_model: Optional[str] = None) -> Optional[str]:
        if explicit_model:
            return explicit_model
        if (
            self._resource_low_impact_active
            and self._effective_strategy() == "lightweight_model"
            and self._resource_resolved_lightweight_id
        ):
            return self._resource_resolved_lightweight_id
        return None

    def get_resource_override_status(self) -> dict[str, Any]:
        return {
            "low_impact_active": self._resource_low_impact_active,
            "strategy": self._resource_strategy,
            "lightweight_model_id": self._resource_lightweight_model_id,
            "effective_profile": self._effective_profile_name(),
            "degradation_reason": self._resource_degradation_reason,
        }

    async def apply_resource_policy(
        self,
        *,
        low_impact_active: bool,
        strategy: str,
        lightweight_model_id: Optional[str] = None,
    ) -> ResourceApplyOutcome:
        if self._closing or self._shutdown_event.is_set():
            return ResourceApplyOutcome(applied=False, deferred_reason="provider_shutting_down")
        if self.has_active_generation:
            return ResourceApplyOutcome(applied=False, deferred_reason="deferred_active_turn")
        if self._lock.locked() or self._runtime_state in (
            LLMRuntimeState.SERVER_STARTING,
            LLMRuntimeState.MODEL_LOADING,
            LLMRuntimeState.MODEL_UNLOADING,
        ):
            return ResourceApplyOutcome(applied=False, deferred_reason="deferred_model_load")

        async with self._lock:
            if self._closing or self._shutdown_event.is_set():
                return ResourceApplyOutcome(applied=False, deferred_reason="provider_shutting_down")
            if self.has_active_generation:
                return ResourceApplyOutcome(applied=False, deferred_reason="deferred_active_turn")

            was_active = self._resource_low_impact_active
            prev_strategy = self._resource_strategy
            prev_resolved_model = self._resource_resolved_lightweight_id

            degradation_reason: Optional[str] = None
            resolved_lightweight: Optional[str] = None
            if low_impact_active and strategy == "lightweight_model":
                if not lightweight_model_id:
                    degradation_reason = "lightweight_model_missing"
                else:
                    entry = find_model_registry_entry(lightweight_model_id)
                    if entry is None or not entry.library_state.primary_file_exists:
                        degradation_reason = "lightweight_model_unavailable"
                    else:
                        resolved_lightweight = entry.runtime_model_id or entry.manifest.id

            self._resource_low_impact_active = bool(low_impact_active)
            self._resource_strategy = strategy
            self._resource_lightweight_model_id = lightweight_model_id
            self._resource_resolved_lightweight_id = resolved_lightweight
            self._resource_degradation_reason = degradation_reason

            eff_strategy = self._effective_strategy()
            eff_profile = self._effective_profile_name()
            eff_model = self._effective_model_name()

            router_alive = (
                self._managed_by_core
                and self._server_process is not None
                and self._server_process.poll() is None
            )

            if low_impact_active:
                policy_changed = (
                    not was_active
                    or prev_strategy != strategy
                    or prev_resolved_model != resolved_lightweight
                )
                if eff_strategy == "unload_when_idle":
                    if (not was_active or prev_strategy != strategy) and self.is_loaded():
                        await self._unload_model_locked()
                    elif self.is_loaded() and self._last_active_at is not None:
                        idle_elapsed = (datetime.now(timezone.utc) - self._last_active_at).total_seconds()
                        if idle_elapsed >= settings.RESOURCE_LOW_IMPACT_IDLE_SECONDS:
                            await self._unload_model_locked()
                else:
                    need_model_reset = self.is_loaded() and (
                        policy_changed
                        or (eff_model is not None and eff_model != self._active_model_name)
                        or (router_alive and self._applied_profile != eff_profile)
                    )
                    if need_model_reset:
                        await self._unload_model_locked()
                    if router_alive and not self.is_loaded() and (
                        self._applied_profile != eff_profile or eff_strategy == "lightweight_model"
                    ):
                        await self._stop_idle_managed_router_locked()
            elif was_active:
                # Exiting Low-Impact -> Normal: never eagerly reload heavy models.
                # Unload temporary/overridden session and stop overridden eco router.
                if self.is_loaded() and (
                    self._resource_using_temporary_model
                    or (self._applied_profile is not None and self._applied_profile != self._active_profile)
                ):
                    await self._unload_model_locked()
                if router_alive and not self.is_loaded() and (
                    self._applied_profile != self._active_profile or self._resource_using_temporary_model
                ):
                    await self._stop_idle_managed_router_locked()
                self._resource_using_temporary_model = False

            return ResourceApplyOutcome(
                applied=True,
                effective_profile=eff_profile,
                degradation_reason=degradation_reason,
            )

    @property
    def active_generation_count(self) -> int:
        return len(self._active_generations)

    @property
    def has_active_generation(self) -> bool:
        return bool(self._active_generations)

    async def _acquire_generation(self) -> object:
        if self._closing:
            raise ProviderGenerationError("PROVIDER_SHUTTING_DOWN")
        await self._ensure_loaded()
        async with self._lock:
            if self._closing:
                raise ProviderGenerationError("PROVIDER_SHUTTING_DOWN")
            if not self.is_loaded():
                raise ProviderGenerationError("MODEL_NOT_READY")
            lease = object()
            self._active_generations.add(lease)
            self._active_work_drained.clear()
            self._last_active_at = datetime.now(timezone.utc)
            return lease

    def _release_generation(self, lease: object) -> None:
        # All accounting runs on the event loop. A worker schedules its release
        # only from its actual completion, independently of awaiting-task lifetime.
        self._active_generations.discard(lease)
        if not self._active_generations:
            self._last_active_at = datetime.now(timezone.utc)
            self._active_work_drained.set()

    def _start_owned_worker(self, worker, lease: object) -> asyncio.Task:
        loop = asyncio.get_running_loop()

        def owned_worker():
            try:
                return worker()
            finally:
                loop.call_soon_threadsafe(self._release_generation, lease)

        task = asyncio.create_task(asyncio.to_thread(owned_worker))
        self._worker_tasks.add(task)

        def completed(task):
            self._worker_tasks.discard(task)
            if not task.cancelled():
                task.exception()  # Retrieve failures even after the caller disconnects.

        task.add_done_callback(completed)
        return task

    @property
    def _engine_version(self) -> str:
        return self._custom_engine_version or settings.LLAMA_ENGINE_VERSION

    @_engine_version.setter
    def _engine_version(self, val: Optional[str]) -> None:
        self._custom_engine_version = val

    @property
    def provider_name(self) -> str:
        return "llama_cpp"

    async def _safe_aclose_client(self, client: Any) -> None:
        if client is None:
            return
        aclose_fn = getattr(client, "aclose", None)
        if callable(aclose_fn):
            try:
                res = aclose_fn()
                if inspect.isawaitable(res):
                    await res
            except Exception:
                pass

    def signal_shutdown_immediately(self) -> None:
        """Cooperative lock-free signal to abort in-flight load and generation.

        CRITICAL SAFEGUARD (Correction 1): Strictly lock-free. Sets cancellation
        flags and signals in-flight tasks/clients, but NEVER mutates shared
        provider state (_server_process, _server_client, _runtime_state) without
        holding self._lock.
        """
        self._closing = True
        self._shutdown_event.set()
        if self._active_load_task and not self._active_load_task.done():
            self._active_load_task.cancel()
        for client in list(self._active_router_clients):
            try:
                aclose_fn = getattr(client, "aclose", None)
                if callable(aclose_fn):
                    res = aclose_fn()
                    if inspect.isawaitable(res):
                        asyncio.create_task(res)
            except Exception:
                pass

    async def _sleep_or_abort(self, seconds: float) -> bool:
        """Interruptible sleep that aborts immediately if shutdown is signaled.

        Returns True if the sleep completed without interruption, False if aborted.
        """
        if self._shutdown_event.is_set():
            return False
        try:
            await asyncio.wait_for(self._shutdown_event.wait(), timeout=seconds)
            return False
        except asyncio.TimeoutError:
            return True

    def _stop_managed_router_locked(self) -> bool:
        """Stop Core-managed llama-server.exe process under self._lock.

        MUST only be called while holding self._lock.
        Returns True if a Core-managed process was stopped and verified dead, False otherwise.
        Never touches external routers (_managed_by_core == False).
        """
        if not self._managed_by_core or not self._server_process:
            return False

        logger.info(f"Terminating Core-owned router PID={self._server_pid}")
        try:
            self._server_process.terminate()
            try:
                self._server_process.wait(timeout=3.0)
            except subprocess.TimeoutExpired:
                self._server_process.kill()
                self._server_process.wait(timeout=1.0)
        except Exception as exc:
            logger.error(f"PID termination failed: {exc}")

        # TRUTHFUL VERIFICATION: verify process is actually dead
        is_dead = False
        try:
            is_dead = (self._server_process.poll() is not None)
        except Exception as exc:
            logger.error(f"Error checking router process exit: {exc}")
            is_dead = False

        if not is_dead:
            logger.error(
                f"Failed to terminate Core-owned router PID={self._server_pid}; process still running. "
                "Retaining process and ownership reference."
            )
            self._last_error = "ROUTER_TERMINATION_FAILED"
            self._runtime_state = LLMRuntimeState.SERVER_ERROR
            return False

        self._server_process = None
        self._server_pid = None
        self._managed_by_core = False
        self._server_is_active = False
        self._active_model_name = None
        self._applied_profile = None
        self._applied_context_size = None
        self._applied_gpu_layers = None
        self._applied_mmproj_offload = None
        self._runtime_state = LLMRuntimeState.SERVER_STOPPED
        return True

    async def _router_load_model(self, model_name: str) -> bool:
        """Load model into VRAM via router API — LLAMA_CPP_RUNTIME_ARCHITECTURE.md §5."""
        if self._shutdown_event.is_set():
            return False
        runtime_id = resolve_runtime_model_id(model_name)
        url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models/load"
        c = httpx.AsyncClient(timeout=45.0)
        self._active_router_clients.add(c)
        try:
            r = await c.post(url, json={"model": runtime_id})
            if r.status_code not in (200, 201):
                if r.status_code == 400 and "already running" in r.text.lower():
                    logger.info(f"Model {runtime_id} is already running in router")
                    return True
                logger.error(f"Router load rejected {r.status_code}: {r.text[:200]}")
                return False
            
            # Poll router /models to verify status.value == 'loaded'
            models_url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models"
            for _ in range(60):
                if not await self._sleep_or_abort(0.5):
                    logger.info("load_model aborted by shutdown event during router status poll")
                    self._last_error = "LOAD_ABORTED_BY_SHUTDOWN"
                    return False
                try:
                    m_resp = await c.get(models_url)
                    if m_resp.status_code == 200:
                        data = m_resp.json()
                        models = data.get("data") or data.get("models") or []
                        for m in models:
                            if m.get("id") == runtime_id and m.get("status", {}).get("value") == "loaded":
                                return True
                except Exception:
                    pass
            logger.warning(f"Router load polling timed out after 30s for {runtime_id}")
            return False
        except (Exception, asyncio.CancelledError) as exc:
            logger.info(f"Router load aborted or failed: {exc}")
            return False
        finally:
            self._active_router_clients.discard(c)
            await self._safe_aclose_client(c)

    async def _router_unload_model(self, model_name: str) -> bool:
        """Unload model from VRAM — router stays alive (runtime arch §5 Explicit Unload)."""
        runtime_id = resolve_runtime_model_id(model_name)
        url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models/unload"
        c = httpx.AsyncClient(timeout=15.0)
        self._active_router_clients.add(c)
        try:
            r = await c.post(url, json={"model": runtime_id})
            if r.status_code not in (200, 204):
                return False
            
            # Poll router /models to verify status.value == 'unloaded'
            models_url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models"
            for _ in range(20):
                if not await self._sleep_or_abort(0.25):
                    return False
                try:
                    m_resp = await c.get(models_url)
                    if m_resp.status_code == 200:
                        data = m_resp.json()
                        models = data.get("data") or data.get("models") or []
                        for m in models:
                            if m.get("id") == runtime_id and m.get("status", {}).get("value") == "unloaded":
                                return True
                except Exception:
                    pass
            logger.warning(f"Router unload polling timed out after 5s for {runtime_id}")
            return False
        except Exception as exc:
            logger.error(f"Router unload failed: {exc}")
            return False
        finally:
            self._active_router_clients.discard(c)
            await self._safe_aclose_client(c)

    def _models_dir_for_entry(self, registry_entry: Any) -> Path:
        """Select MODEL_LIBRARY_DIR strictly for installed D6 entries, else LLAMA_MODELS_DIR."""
        if getattr(registry_entry, "registry_source", "factory") == "installed":
            return settings.MODEL_LIBRARY_DIR
        return settings.LLAMA_MODELS_DIR

    def _resolve_model_path(self, model_name: Optional[str] = None) -> Path:
        target, _ = resolve_effective_model(model_name)
        if not target:
            target = "model_not_selected"
        search_roots = [settings.MODELS_DIR, settings.MODEL_LIBRARY_DIR]

        for models_dir in search_roots:
            candidate = models_dir / target
            if candidate.exists():
                return candidate
            if not target.endswith(".gguf"):
                candidate_gguf = models_dir / f"{target}.gguf"
                if candidate_gguf.exists():
                    return candidate_gguf

        return settings.MODELS_DIR / target

    def _get_profile_params(
        self,
        profile: str,
        *,
        model_max_context: Optional[int] = None,
        context_mode: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Map performance profiles (Section 13) + optional experimental >8K context override."""
        p = profile.lower()
        if p == "eco":
            params = {
                "n_ctx": settings.PROFILE_ECO_CTX,
                "n_gpu_layers": settings.PROFILE_ECO_GPU_LAYERS,
                "n_threads": settings.PROFILE_ECO_THREADS,
                "mmproj_offload": settings.PROFILE_ECO_MMPROJ_OFFLOAD,
            }
        elif p == "maximum":
            params = {
                "n_ctx": settings.PROFILE_MAXIMUM_CTX,
                "n_gpu_layers": settings.PROFILE_MAXIMUM_GPU_LAYERS,
                "n_threads": settings.PROFILE_MAXIMUM_THREADS,
                "mmproj_offload": settings.PROFILE_MAXIMUM_MMPROJ_OFFLOAD,
            }
        else:  # balanced or fallback
            params = {
                "n_ctx": settings.PROFILE_BALANCED_CTX,
                "n_gpu_layers": settings.PROFILE_BALANCED_GPU_LAYERS,
                "n_threads": settings.PROFILE_BALANCED_THREADS,
                "mmproj_offload": settings.PROFILE_BALANCED_MMPROJ_OFFLOAD,
            }

        mode = (context_mode if context_mode is not None else getattr(self, "_context_mode", "profile")) or "profile"
        params["n_ctx"] = resolve_context_size_for_mode(
            params["n_ctx"],
            mode,
            model_max_context=model_max_context,
        )
        return params

    def _check_port_listening(self, host: str, port: int) -> bool:
        """Check whether a TCP port is currently open and accepting connections."""
        import socket
        try:
            with socket.create_connection((host, port), timeout=0.5):
                return True
        except (OSError, ConnectionRefusedError):
            return False

    async def _check_external_server(self) -> bool:
        """Check if a local standalone llama-server is active on router port."""
        c = httpx.AsyncClient(timeout=2.0)
        self._active_router_clients.add(c)
        try:
            base_health_url = settings.LLAMA_SERVER_URL.replace("/v1", "") + "/health"
            resp = await c.get(base_health_url)
            if resp.status_code == 200:
                self._server_is_active = True
                return True
        except Exception:
            pass
        finally:
            self._active_router_clients.discard(c)
            await self._safe_aclose_client(c)
        self._server_is_active = False
        return False

    async def load_model(self, model_name: Optional[str] = None, profile: Optional[str] = None) -> bool:
        curr_task = asyncio.current_task()
        if curr_task is not None:
            self._active_load_task = curr_task
        try:
            async with self._lock:
                try:
                    self._last_error = None
                    if self._closing or self._shutdown_event.is_set() or self.has_active_generation:
                        self._last_error = (
                            "CANNOT_CHANGE_PROFILE_DURING_GENERATION"
                            if profile and profile.lower() != self._active_profile and self.has_active_generation
                            else "MODEL_BUSY"
                        )
                        return False

                    if profile and profile.lower() in ("eco", "balanced", "maximum"):
                        requested_p = profile.lower()
                        if requested_p != self._active_profile:
                            logger.info(f"Switching profile from {self._active_profile} to {requested_p} during load_model")
                            if self._managed_by_core and self._server_process and self._server_process.poll() is None:
                                if self._active_model_name and self._server_is_active:
                                    try:
                                        runtime_id_old = resolve_runtime_model_id(self._active_model_name)
                                        await self._router_unload_model(runtime_id_old)
                                    except Exception:
                                        pass
                                stopped = self._stop_managed_router_locked()
                                if not stopped:
                                    logger.error(f"Failed to terminate router PID={self._server_pid} during profile switch; retaining ownership")
                                    return False
                                if self._server_client:
                                    await self._server_client.aclose()
                                    self._server_client = None
                            self._active_profile = requested_p

                    if model_name:
                        if ".." in model_name or model_name.startswith("/") or model_name.startswith("\\"):
                            self._last_error = "MODEL_PATH_TRAVERSAL"
                            return False

                    eff_profile = self._effective_profile_name()
                    eff_model_override = self._effective_model_name(explicit_model=model_name)

                    # Active model reuse (Master Plan / Review requirements):
                    # Reuse only when model and effective hardware profile match.
                    if self.is_loaded():
                        if model_name is None and eff_model_override is None:
                            if not self._managed_by_core or self._applied_profile in (None, eff_profile):
                                logger.info(f"Reusing active model '{self._active_model_name}' without reload")
                                self._last_active_at = datetime.now(timezone.utc)
                                return True

                        reuse_probe = eff_model_override or model_name
                        if reuse_probe:
                            matched_active = find_model_registry_entry(reuse_probe)
                            req_runtime_id = (
                                (matched_active.runtime_model_id or matched_active.manifest.id)
                                if matched_active
                                else resolve_runtime_model_id(reuse_probe)
                            )
                            if (
                                req_runtime_id
                                and req_runtime_id == self._active_model_name
                                and (not self._managed_by_core or self._applied_profile in (None, eff_profile))
                            ):
                                logger.info(
                                    f"Requested model '{reuse_probe}' matches active model '{self._active_model_name}'; reusing without reload"
                                )
                                self._last_active_at = datetime.now(timezone.utc)
                                return True

                    # Resolve target model according to precedence:
                    # 1. Explicitly requested model or temporary lightweight override
                    # 2. Saved host-level model selection
                    # 3. Explicit development environment override, if present
                    # 4. Otherwise MODEL_SELECTION_REQUIRED
                    candidate_identifier, source = resolve_effective_model(eff_model_override)
                    if not candidate_identifier:
                        self._last_error = "MODEL_SELECTION_REQUIRED"
                        self._runtime_state = LLMRuntimeState.MODEL_SELECTION_REQUIRED
                        return False

                    # Enforce verified registry matching - never silently fall back
                    registry_entry = find_model_registry_entry(candidate_identifier)
                    if not registry_entry or not registry_entry.library_state.primary_file_exists:
                        self._last_error = f"CONFIGURED_MODEL_NOT_FOUND: {candidate_identifier}"
                        logger.error(self._last_error)
                        self._runtime_state = LLMRuntimeState.MODEL_ERROR
                        return False

                    target_model_name = registry_entry.runtime_model_id or registry_entry.manifest.id
                    target_models_dir = self._models_dir_for_entry(registry_entry)

                    # Mode 0: If Core-managed process is already alive, check root and effective profile parity before reusing it
                    if self._server_process is not None and self._server_process.poll() is None:
                        need_root_restart = (
                            self._managed_by_core
                            and (
                                (self._active_models_dir is not None and str(self._active_models_dir) != str(target_models_dir.resolve()))
                                or (self._applied_profile is not None and self._applied_profile != eff_profile)
                            )
                        )
                        if need_root_restart:
                            logger.info(
                                f"Switching router models root from '{self._active_models_dir}' to '{target_models_dir}'"
                            )
                            if self._active_model_name and self._server_is_active:
                                try:
                                    cur_runtime = resolve_runtime_model_id(self._active_model_name)
                                    await self._router_unload_model(cur_runtime)
                                except Exception:
                                    pass
                            stopped = self._stop_managed_router_locked()
                            if not stopped:
                                self._last_error = "ROUTER_TERMINATION_FAILED"
                                self._runtime_state = LLMRuntimeState.SERVER_ERROR
                                return False
                            if self._server_client:
                                await self._server_client.aclose()
                                self._server_client = None
                            self._server_is_active = False
                            self._active_model_name = None
                            self._active_models_dir = None
                        else:
                            if not self._server_is_active:
                                for _ in range(10):
                                    if await self._check_external_server():
                                        break
                                    await asyncio.sleep(0.5)

                            if await self._check_external_server():
                                self._runtime_state = LLMRuntimeState.MODEL_LOADING
                                if await self._router_load_model(target_model_name):
                                    self._runtime_state = LLMRuntimeState.MODEL_READY
                                    self._active_model_name = target_model_name
                                    self._resource_using_temporary_model = bool(
                                        self._resource_low_impact_active
                                        and self._effective_strategy() == "lightweight_model"
                                        and model_name is None
                                    )
                                    self._last_active_at = datetime.now(timezone.utc)
                                    self._start_idle_monitor()
                                    return True
                                else:
                                    if self._shutdown_event.is_set() or self._last_error == "LOAD_ABORTED_BY_SHUTDOWN":
                                        self._last_error = "LOAD_ABORTED_BY_SHUTDOWN"
                                        self._runtime_state = LLMRuntimeState.SERVER_STOPPED if self._managed_by_core else LLMRuntimeState.MODEL_UNLOADED
                                    else:
                                        self._last_error = f"MODEL_LOAD_FAILED: {target_model_name}"
                                        self._runtime_state = LLMRuntimeState.MODEL_ERROR
                                    return False
                            else:
                                self._last_error = "ROUTER_UNRESPONSIVE: existing router process is not responding to health checks"
                                self._runtime_state = LLMRuntimeState.SERVER_ERROR
                                return False

                    # Mode 1: Check if port is already listening before spawning
                    if self._check_port_listening(settings.LLAMA_ROUTER_HOST, settings.LLAMA_ROUTER_PORT):
                        if await self._check_external_server():
                            self._server_is_active = True
                            logger.info(f"Connected to active external llama-server at {settings.LLAMA_SERVER_URL}")
                            self._runtime_state = LLMRuntimeState.MODEL_LOADING
                            if await self._router_load_model(target_model_name):
                                self._runtime_state = LLMRuntimeState.MODEL_READY
                                self._active_model_name = target_model_name
                                self._resource_using_temporary_model = bool(
                                    self._resource_low_impact_active
                                    and self._effective_strategy() == "lightweight_model"
                                    and model_name is None
                                )
                                self._last_active_at = datetime.now(timezone.utc)
                                self._start_idle_monitor()
                                return True
                            else:
                                if self._shutdown_event.is_set() or self._last_error == "LOAD_ABORTED_BY_SHUTDOWN":
                                    self._last_error = "LOAD_ABORTED_BY_SHUTDOWN"
                                    self._runtime_state = LLMRuntimeState.SERVER_STOPPED if self._managed_by_core else LLMRuntimeState.MODEL_UNLOADED
                                else:
                                    self._last_error = f"MODEL_LOAD_FAILED: {target_model_name}"
                                    self._runtime_state = LLMRuntimeState.MODEL_ERROR
                                return False
                        else:
                            self._last_error = f"PORT_CONFLICT: Port {settings.LLAMA_ROUTER_PORT} is in use by an unrecognized process"
                            logger.error(self._last_error)
                            self._runtime_state = LLMRuntimeState.SERVER_ERROR
                            return False

                    # Mode 2: Launch standalone llama-server.exe router
                    server_exe = settings.LLAMA_CPP_BIN_DIR / "llama-server.exe"
                    if not server_exe.exists():
                        self._last_error = f"ENGINE_NOT_FOUND: {server_exe}"
                        logger.error(self._last_error)
                        self._runtime_state = LLMRuntimeState.SERVER_ERROR
                        return False

                    if not target_models_dir.exists():
                        self._last_error = f"MODELS_DIR_NOT_FOUND: {target_models_dir}"
                        logger.error(self._last_error)
                        self._runtime_state = LLMRuntimeState.MODEL_ERROR
                        return False

                    manifest_obj = getattr(registry_entry, "manifest", None)
                    raw_max_ctx = getattr(manifest_obj, "model_max_context", None) if manifest_obj is not None else None
                    model_max_ctx = raw_max_ctx if isinstance(raw_max_ctx, int) and not isinstance(raw_max_ctx, bool) else None
                    params = self._get_profile_params(
                        eff_profile,
                        model_max_context=model_max_ctx,
                    )
                    logger.info(
                        f"Launching standalone llama-server router with Vulkan offload "
                        f"({params['n_gpu_layers']} GPU layers, ctx={params['n_ctx']}, threads={params['n_threads']}, model={target_model_name})..."
                    )
                    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
                    log_file_path = (settings.DATA_DIR / "llama_server.log").resolve()
                    try:
                        if log_file_path.exists():
                            log_file_path.write_text("", encoding="utf-8")
                    except Exception:
                        pass

                    resolved_models_root = target_models_dir.resolve()
                    launch_args = [
                        str(server_exe.resolve()),
                        "--models-dir", str(resolved_models_root),
                        "--host", settings.LLAMA_ROUTER_HOST,
                        "--port", str(settings.LLAMA_ROUTER_PORT),
                        "--sleep-idle-seconds", str(settings.LLAMA_ROUTER_IDLE_TIMEOUT),
                        "--models-max", str(settings.LLAMA_ROUTER_MODELS_MAX),
                        "--parallel", "1",
                        "--no-webui",
                        "--metrics",
                        "--ctx-size", str(params["n_ctx"]),
                        "--n-gpu-layers", str(params["n_gpu_layers"]),
                        "--threads", str(params["n_threads"]),
                        "--log-file", str(log_file_path),
                        "--log-timestamps",
                    ]

                    if not params.get("mmproj_offload", True):
                        launch_args.append("--no-mmproj-offload")

                    self._runtime_state = LLMRuntimeState.SERVER_STARTING
                    popen_kwargs: Dict[str, Any] = {
                        "cwd": str(settings.LLAMA_CPP_BIN_DIR.resolve()),
                        "stdout": subprocess.DEVNULL,
                        "stderr": subprocess.DEVNULL,
                    }
                    if sys.platform == "win32":
                        popen_kwargs["creationflags"] = getattr(
                            subprocess, "CREATE_NO_WINDOW", 0x08000000
                        )
                    try:
                        proc = subprocess.Popen(
                            launch_args,
                            **popen_kwargs,
                        )
                        self._server_process = proc
                        self._server_pid = proc.pid
                        self._managed_by_core = True
                        self._active_models_dir = resolved_models_root
                        self._server_launch_args = launch_args
                        self._server_started_at = datetime.now(timezone.utc)
                        self._applied_profile = eff_profile
                        self._resource_using_temporary_model = bool(
                            self._resource_low_impact_active
                            and self._effective_strategy() == "lightweight_model"
                            and model_name is None
                        )
                        self._applied_context_size = params["n_ctx"]
                        self._applied_gpu_layers = params["n_gpu_layers"]
                        self._applied_mmproj_offload = params.get("mmproj_offload", True)
                        logger.info(f"Router spawned PID={proc.pid} with applied profile '{self._applied_profile}' (ctx={self._applied_context_size}, ngl={self._applied_gpu_layers}, mmproj_offload={self._applied_mmproj_offload})")
                    except Exception as e:
                        self._last_error = f"LAUNCH_FAILED: {e}"
                        logger.error(self._last_error)
                        self._runtime_state = LLMRuntimeState.SERVER_ERROR
                        return False

                    def _cleanup_failed_proc(child_proc: subprocess.Popen) -> bool:
                        stopped = self._stop_managed_router_locked()
                        if not stopped:
                            logger.error(f"Failed to terminate router PID={self._server_pid} during startup failure; retaining ownership")
                            self._last_error = "ROUTER_TERMINATION_FAILED"
                            self._runtime_state = LLMRuntimeState.SERVER_ERROR
                        return stopped

                    # Poll for readiness up to 45 seconds
                    healthy = False
                    for _ in range(90):
                        if not await self._sleep_or_abort(0.5):
                            logger.info("load_model aborted by shutdown event during router startup")
                            self._last_error = "LOAD_ABORTED_BY_SHUTDOWN"
                            self._runtime_state = LLMRuntimeState.SERVER_STOPPED
                            _cleanup_failed_proc(proc)
                            return False
                        poll_res = self._server_process.poll()
                        if poll_res is not None:
                            err_snippet = ""
                            try:
                                with open(log_file_path, "r", encoding="utf-8", errors="ignore") as rf:
                                    err_snippet = "".join(rf.readlines()[-10:])
                            except Exception:
                                pass
                            self._last_error = f"llama-server exited with code {poll_res}: {err_snippet.strip()}"
                            logger.error(self._last_error)
                            self._runtime_state = LLMRuntimeState.SERVER_ERROR
                            _cleanup_failed_proc(proc)
                            return False
                        if await self._check_external_server():
                            healthy = True
                            self._runtime_state = LLMRuntimeState.MODEL_UNLOADED
                            logger.info(f"Router healthy on port {settings.LLAMA_ROUTER_PORT}")
                            break

                    if not healthy:
                        self._last_error = "ROUTER_TIMEOUT: not healthy within 45s"
                        logger.error(self._last_error)
                        self._runtime_state = LLMRuntimeState.SERVER_ERROR
                        _cleanup_failed_proc(proc)
                        return False

                    if self._shutdown_event.is_set():
                        logger.info("load_model aborted by shutdown event before router load")
                        self._last_error = "LOAD_ABORTED_BY_SHUTDOWN"
                        self._runtime_state = LLMRuntimeState.SERVER_STOPPED
                        _cleanup_failed_proc(proc)
                        return False

                    # Load model into VRAM via router API
                    self._runtime_state = LLMRuntimeState.MODEL_LOADING
                    if await self._router_load_model(target_model_name):
                        if self._shutdown_event.is_set():
                            logger.info("load_model completed router load but shutdown is signaled; cleaning up under lock")
                            self._runtime_state = LLMRuntimeState.SERVER_STOPPED
                            _cleanup_failed_proc(proc)
                            return False
                        self._runtime_state = LLMRuntimeState.MODEL_READY
                        self._active_model_name = target_model_name
                        self._last_active_at = datetime.now(timezone.utc)
                        self._start_idle_monitor()
                        logger.info(f"Model loaded: {target_model_name}")
                        return True
                    else:
                        if self._shutdown_event.is_set() or self._last_error == "LOAD_ABORTED_BY_SHUTDOWN":
                            self._last_error = "LOAD_ABORTED_BY_SHUTDOWN"
                            self._runtime_state = LLMRuntimeState.SERVER_STOPPED if self._managed_by_core else LLMRuntimeState.MODEL_UNLOADED
                        else:
                            self._last_error = f"MODEL_LOAD_FAILED: {target_model_name}"
                            self._runtime_state = LLMRuntimeState.MODEL_ERROR
                        return False
                except asyncio.CancelledError:
                    logger.info("load_model cancelled by shutdown event; performing synchronized cleanup")
                    was_managed = self._managed_by_core
                    if was_managed and self._server_process:
                        stopped = self._stop_managed_router_locked()
                        if not stopped:
                            self._last_error = "ROUTER_TERMINATION_FAILED"
                            self._runtime_state = LLMRuntimeState.SERVER_ERROR
                            return False
                    self._last_error = "LOAD_ABORTED_BY_SHUTDOWN"
                    self._runtime_state = LLMRuntimeState.SERVER_STOPPED if was_managed else LLMRuntimeState.MODEL_UNLOADED
                    return False
        finally:
            if self._active_load_task is curr_task:
                self._active_load_task = None

    async def _stop_idle_managed_router_locked(self) -> bool:
        """Stop an idle Core-managed router process while holding self._lock."""
        if not (self._managed_by_core and self._server_process and self._server_process.poll() is None):
            return True
        stopped = self._stop_managed_router_locked()
        if not stopped:
            return False
        if self._server_client:
            await self._server_client.aclose()
            self._server_client = None
        self._server_is_active = False
        self._active_model_name = None
        self._active_models_dir = None
        self._applied_profile = None
        self._applied_context_size = None
        self._applied_gpu_layers = None
        self._applied_mmproj_offload = None
        self._runtime_state = LLMRuntimeState.SERVER_STOPPED
        return True

    async def _unload_model_locked(self) -> bool:
        """Unload model resources while caller already holds self._lock."""
        if self.has_active_generation:
            self._last_error = "MODEL_BUSY: active generation"
            return False

        if self._idle_check_task and not self._idle_check_task.done():
            self._idle_check_task.cancel()

        # 1. Free in-process model
        if self._llm is not None:
            logger.info(f"Unloading in-process model '{self._active_model_name}' to free VRAM...")
            del self._llm
            self._llm = None
            gc.collect()

        # 2. Preferred: router API — router stays alive (runtime arch §5 Explicit Unload)
        if self._active_model_name and self._server_is_active:
            self._runtime_state = LLMRuntimeState.MODEL_UNLOADING
            runtime_id = resolve_runtime_model_id(self._active_model_name)
            if await self._router_unload_model(runtime_id):
                self._runtime_state = LLMRuntimeState.MODEL_UNLOADED
                self._active_model_name = None
                self._resource_using_temporary_model = False
                logger.info("Model unloaded via router API; router alive")
                return True
            logger.warning("Router API unload failed; escalating to scoped PID termination")

        # 3. Fallback: scoped PID termination — runtime arch §5 invariant: NEVER taskkill /IM
        if self._managed_by_core and self._server_process:
            stopped = self._stop_managed_router_locked()
            if not stopped:
                logger.error(f"Failed to terminate router PID={self._server_pid} during unload fallback; retaining ownership")
                return False
            if self._server_client:
                await self._server_client.aclose()
                self._server_client = None
            self._resource_using_temporary_model = False
            logger.info("Model unloaded successfully. Scoped termination complete.")
            return True

        self._runtime_state = LLMRuntimeState.MODEL_UNLOADED
        self._active_model_name = None
        self._resource_using_temporary_model = False
        return True

    async def unload_model(self) -> bool:
        async with self._lock:
            return await self._unload_model_locked()

    async def set_profile(
        self,
        profile: str,
        context_mode: Optional[str] = None,
    ) -> bool:
        async with self._lock:
            p = profile.lower()
            if p not in ("eco", "balanced", "maximum"):
                return False
            next_ctx_mode = self._context_mode
            if context_mode is not None:
                normalized_ctx = context_mode.strip().lower()
                if normalized_ctx not in VALID_CONTEXT_MODES:
                    return False
                next_ctx_mode = normalized_ctx
            if self.has_active_generation or self._closing:
                logger.warning(f"Cannot change profile to '{p}' while generation is active")
                return False

            old_eff_profile = self._effective_profile_name()
            old_ctx_mode = self._context_mode
            self._active_profile = p
            self._context_mode = next_ctx_mode
            save_hardware_profile(p)
            if context_mode is not None:
                save_context_mode(next_ctx_mode)
            new_eff_profile = self._effective_profile_name()
            logger.info(
                f"LLM hardware profile saved as '{p}' (ctx={next_ctx_mode}; active effective={new_eff_profile})"
            )

            # Evidence-gated profile reconfiguration:
            # Restart Core-managed router only if effective profile/context actually changed
            # (preserves active Low-Impact cpu_eco override while updating saved Normal preference).
            if (old_eff_profile != new_eff_profile or old_ctx_mode != next_ctx_mode) and self._managed_by_core and self._server_process and self._server_process.poll() is None:
                logger.info(f"Terminating Core-managed router PID={self._server_pid} to apply profile '{p}' on next activation")
                if self._active_model_name and self._server_is_active:
                    try:
                        runtime_id = resolve_runtime_model_id(self._active_model_name)
                        await self._router_unload_model(runtime_id)
                    except Exception:
                        pass
                stopped = self._stop_managed_router_locked()
                if not stopped:
                    logger.error(f"Failed to terminate router PID={self._server_pid} during profile change; retaining ownership")
                    self._last_error = "ROUTER_TERMINATION_FAILED"
                    self._runtime_state = LLMRuntimeState.SERVER_ERROR
                    return False
                if self._server_client:
                    await self._server_client.aclose()
                    self._server_client = None
                self._server_is_active = False
                self._active_model_name = None
                self._active_models_dir = None
                self._applied_profile = None
                self._applied_context_size = None
                self._applied_gpu_layers = None
                self._applied_mmproj_offload = None
                self._runtime_state = LLMRuntimeState.SERVER_STOPPED

            return True

    async def stop_managed_router_if_idle(self) -> bool:
        """Stop an idle Core-managed router process cleanly (used before LIBRARY_ROOT relocation)."""
        async with self._lock:
            if self.has_active_generation or self.is_loaded():
                return False
            if self._managed_by_core and self._server_process and self._server_process.poll() is None:
                stopped = self._stop_managed_router_locked()
                if not stopped:
                    return False
                if self._server_client:
                    await self._server_client.aclose()
                    self._server_client = None
                self._server_is_active = False
                self._active_model_name = None
                self._active_models_dir = None
                self._runtime_state = LLMRuntimeState.SERVER_STOPPED
            return True

    def is_loaded(self) -> bool:
        return self._llm is not None or (
            self._server_is_active
            and self._runtime_state in (LLMRuntimeState.MODEL_READY, LLMRuntimeState.MODEL_SLEEPING)
            and bool(self._active_model_name)
        )

    def _start_idle_monitor(self) -> None:
        if self._idle_check_task and not self._idle_check_task.done():
            return
        self._idle_check_task = asyncio.create_task(self._idle_monitor_loop())

    async def _idle_monitor_loop(self) -> None:
        """Periodic background monitor checking for idle timeout auto-unload."""
        while self.is_loaded():
            unload_when_idle_active = (
                self._resource_low_impact_active
                and self._effective_strategy() == "unload_when_idle"
            )
            if self._server_is_active and settings.LLAMA_ROUTER_IDLE_TIMEOUT > 0 and not unload_when_idle_active:
                logger.info("Native --sleep-idle-seconds is active on router; Python auto-unload monitor neutralized.")
                return

            sleep_seconds = (
                min(30.0, float(settings.RESOURCE_LOW_IMPACT_IDLE_SECONDS))
                if unload_when_idle_active
                else 30.0
            )
            await asyncio.sleep(max(0.1, sleep_seconds))
            if not self.is_loaded():
                break

            unload_when_idle_active = (
                self._resource_low_impact_active
                and self._effective_strategy() == "unload_when_idle"
            )
            if self._server_is_active and settings.LLAMA_ROUTER_IDLE_TIMEOUT > 0 and not unload_when_idle_active:
                break

            if self._last_active_at:
                elapsed = (datetime.now(timezone.utc) - self._last_active_at).total_seconds()
                threshold = (
                    float(settings.RESOURCE_LOW_IMPACT_IDLE_SECONDS)
                    if unload_when_idle_active
                    else float(settings.LLM_IDLE_TIMEOUT_SECONDS)
                )
                if elapsed >= threshold:
                    logger.info(
                        f"Model idle for {int(elapsed)}s (threshold: {int(threshold)}s). Triggering auto-unload."
                    )
                    await self.unload_model()
                    break

    async def get_status(self) -> ModelStatusResponse:
        # M5: Lock-free snapshot during transitional states (SERVER_STARTING, MODEL_LOADING, MODEL_UNLOADING)
        if self._runtime_state in (
            LLMRuntimeState.SERVER_STARTING,
            LLMRuntimeState.MODEL_LOADING,
            LLMRuntimeState.MODEL_UNLOADING,
        ):
            saved_selection = get_saved_model_selection()
            selected_entry = None
            entry_max_ctx: Optional[int] = None
            try:
                selected_entry = find_model_registry_entry(
                    self._active_model_name or saved_selection,
                )
                raw_entry_ctx = (
                    getattr(getattr(selected_entry, "manifest", None), "model_max_context", None)
                    if selected_entry is not None
                    else None
                )
                if isinstance(raw_entry_ctx, int) and not isinstance(raw_entry_ctx, bool):
                    entry_max_ctx = raw_entry_ctx
            except Exception:
                selected_entry = None
            req_params = self._get_profile_params(
                self._active_profile,
                model_max_context=entry_max_ctx,
            )
            effective_router_running = (
                (self._server_process is not None and self._server_process.poll() is None)
                or self._server_is_active
            )
            hw = probe_host_hardware()
            context_options = assess_context_options_for_entry(
                selected_entry,
                profile=self._active_profile,
                dedicated_vram_gb=hw.dedicated_vram_gb,
                total_ram_gb=hw.total_ram_gb,
            )
            return ModelStatusResponse(
                provider=self.provider_name,
                engine_version=self._engine_version,
                router_running=effective_router_running,
                managed_by_core=self._managed_by_core and effective_router_running,
                runtime_state=self._runtime_state,
                active_model=self._active_model_name,
                selected_model=saved_selection,
                model_resident=False,
                model_loaded=False,
                model_awake=False,
                requested_profile=self._active_profile,
                requested_context_mode=getattr(self, "_context_mode", "profile"),
                context_options=context_options,
                applied_profile=self._applied_profile,
                applied_context_size=self._applied_context_size,
                applied_gpu_layers=self._applied_gpu_layers,
                requested_mmproj_offload=req_params.get("mmproj_offload", True),
                applied_mmproj_offload=self._applied_mmproj_offload,
                host_gpu_name=hw.gpu_name,
                host_vram_gb=hw.dedicated_vram_gb,
                host_ram_gb=hw.total_ram_gb,
                mmproj_offload=self._applied_mmproj_offload if self._applied_mmproj_offload is not None else req_params.get("mmproj_offload", True),
                generation_active=self.has_active_generation,
                last_runtime_error=self._last_error,
                is_loaded=False,
                active_profile=self._active_profile,
                context_size=self._applied_context_size if self._applied_context_size is not None else req_params["n_ctx"],
                gpu_layers=self._applied_gpu_layers if self._applied_gpu_layers is not None else req_params["n_gpu_layers"],
                idle_timeout_seconds=settings.LLAMA_ROUTER_IDLE_TIMEOUT,
                seconds_until_idle=None,
                seconds_until_unload=None,
                available_models=[],
                available_registry=[],
            )

        router_running = False
        loaded_model_id = None
        model_status_val = None

        # Live probe external llama-server process if not in-process
        if self._llm is None:
            if await self._check_external_server():
                router_running = True
                router_models_url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models"
                try:
                    async with httpx.AsyncClient(timeout=1.0) as client:
                        resp = await client.get(router_models_url)
                        if resp.status_code == 200:
                            data = resp.json()
                            models = data.get("data") or data.get("models") or []
                            for m in models:
                                s = m.get("status", {}).get("value")
                                if s == "loaded":
                                    loaded_model_id = m.get("id")
                                    model_status_val = "loaded"
                                    break
                                elif s == "sleeping":
                                    loaded_model_id = m.get("id")
                                    model_status_val = "sleeping"
                                    break
                except Exception:
                    pass

                if loaded_model_id:
                    matched_entry = find_model_registry_entry(loaded_model_id)
                    canonical_id = (
                        (matched_entry.manifest.id or matched_entry.runtime_model_id)
                        if matched_entry
                        else loaded_model_id
                    )
                    self._active_model_name = canonical_id
                    if model_status_val == "sleeping":
                        self._runtime_state = LLMRuntimeState.MODEL_SLEEPING
                    else:
                        self._runtime_state = LLMRuntimeState.MODEL_READY
                    if not self._last_active_at:
                        self._last_active_at = datetime.now(timezone.utc)
                else:
                    self._active_model_name = None
                    if self._runtime_state in (
                        LLMRuntimeState.MODEL_ERROR,
                        LLMRuntimeState.SERVER_ERROR,
                        LLMRuntimeState.MODEL_LOADING,
                        LLMRuntimeState.MODEL_UNLOADING,
                    ):
                        pass
                    elif self._last_error == "MODEL_SELECTION_REQUIRED" or self._runtime_state == LLMRuntimeState.MODEL_SELECTION_REQUIRED:
                        self._runtime_state = LLMRuntimeState.MODEL_SELECTION_REQUIRED
                    else:
                        self._runtime_state = LLMRuntimeState.MODEL_UNLOADED
            else:
                router_running = False
                self._server_is_active = False
                self._active_model_name = None
                self._applied_profile = None
                self._applied_context_size = None
                self._applied_gpu_layers = None
                self._applied_mmproj_offload = None
                if self._runtime_state not in (
                    LLMRuntimeState.MODEL_ERROR,
                    LLMRuntimeState.SERVER_ERROR,
                    LLMRuntimeState.SERVER_STARTING,
                    LLMRuntimeState.MODEL_LOADING,
                    LLMRuntimeState.MODEL_UNLOADING,
                    LLMRuntimeState.MODEL_SELECTION_REQUIRED,
                ):
                    self._runtime_state = LLMRuntimeState.SERVER_STOPPED
        else:
            router_running = False
            if self._active_model_name:
                self._runtime_state = LLMRuntimeState.MODEL_READY
            elif self._last_error == "MODEL_SELECTION_REQUIRED" or self._runtime_state == LLMRuntimeState.MODEL_SELECTION_REQUIRED:
                self._runtime_state = LLMRuntimeState.MODEL_SELECTION_REQUIRED
            else:
                self._runtime_state = LLMRuntimeState.MODEL_UNLOADED

        entries_list = build_model_list()
        saved_selection = get_saved_model_selection()
        selected_entry = find_model_registry_entry(
            self._active_model_name or saved_selection,
            entries=entries_list,
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
        req_params = self._get_profile_params(
            self._active_profile,
            model_max_context=entry_max_ctx,
        )
        available = []
        for root_dir in (settings.MODELS_DIR, settings.MODEL_LIBRARY_DIR):
            if root_dir.exists():
                for f in root_dir.rglob("*.gguf"):
                    if (
                        f.is_file()
                        and f.name != "lfs-test.gguf"
                        and not f.name.startswith("mmproj")
                        and f.stat().st_size > 100 * 1024 * 1024
                    ):
                        rel = f.relative_to(root_dir).as_posix()
                        if rel not in available:
                            available.append(rel)

        registry_entries = [m.manifest.primary_file for m in entries_list if m.library_state.primary_file_exists]

        # Determine residency & readiness booleans
        model_resident = (self._runtime_state == LLMRuntimeState.MODEL_READY and bool(self._active_model_name))
        model_loaded = (self._runtime_state in (LLMRuntimeState.MODEL_READY, LLMRuntimeState.MODEL_SLEEPING) and bool(self._active_model_name))
        model_awake = (self._runtime_state == LLMRuntimeState.MODEL_READY and bool(self._active_model_name))
        is_loaded = model_loaded

        # Idle / Sleep countdown semantics (Phase 3 correction pass):
        # Native llama.cpp sleep handles resource preservation.
        # Python auto-unload is neutralized, so seconds_until_unload is strictly None.
        seconds_until_idle = None
        if self._runtime_state == LLMRuntimeState.MODEL_SLEEPING:
            seconds_until_idle = 0
        elif self._runtime_state == LLMRuntimeState.MODEL_READY:
            if self._last_active_at:
                elapsed = (datetime.now(timezone.utc) - self._last_active_at).total_seconds()
                seconds_until_idle = max(0, int(settings.LLAMA_ROUTER_IDLE_TIMEOUT - elapsed))
            else:
                seconds_until_idle = settings.LLAMA_ROUTER_IDLE_TIMEOUT
        seconds_until_unload = None

        # Truthful applied profile & mmproj: only reported if router is actually running
        effective_applied_profile = self._applied_profile if router_running else None
        effective_applied_ctx = self._applied_context_size if router_running else None
        effective_applied_ngl = self._applied_gpu_layers if router_running else None
        requested_mmproj_offload = req_params.get("mmproj_offload", True)
        effective_applied_mmproj = self._applied_mmproj_offload if router_running else None
        compat_mmproj_offload = effective_applied_mmproj if effective_applied_mmproj is not None else requested_mmproj_offload


        hw = probe_host_hardware()
        context_options = assess_context_options_for_entry(
            selected_entry,
            profile=self._active_profile,
            dedicated_vram_gb=hw.dedicated_vram_gb,
            total_ram_gb=hw.total_ram_gb,
        )

        return ModelStatusResponse(
            provider=self.provider_name,
            engine_version=self._engine_version,
            router_running=router_running,
            managed_by_core=self._managed_by_core and router_running,
            runtime_state=self._runtime_state,
            active_model=self._active_model_name if is_loaded else None,
            selected_model=saved_selection,
            model_resident=model_resident,
            model_loaded=model_loaded,
            model_awake=model_awake,
            requested_profile=self._active_profile,
            requested_context_mode=getattr(self, "_context_mode", "profile"),
            context_options=context_options,
            applied_profile=effective_applied_profile,
            applied_context_size=effective_applied_ctx,
            applied_gpu_layers=effective_applied_ngl,
            requested_mmproj_offload=requested_mmproj_offload,
            applied_mmproj_offload=effective_applied_mmproj,
            host_gpu_name=hw.gpu_name,
            host_vram_gb=hw.dedicated_vram_gb,
            host_ram_gb=hw.total_ram_gb,
            mmproj_offload=compat_mmproj_offload,
            generation_active=self.has_active_generation,
            last_runtime_error=self._last_error,
            # Backward-compatibility fields
            is_loaded=is_loaded,
            active_profile=self._active_profile,
            context_size=effective_applied_ctx if effective_applied_ctx is not None else req_params["n_ctx"],
            gpu_layers=effective_applied_ngl if effective_applied_ngl is not None else req_params["n_gpu_layers"],
            idle_timeout_seconds=settings.LLAMA_ROUTER_IDLE_TIMEOUT,
            seconds_until_idle=seconds_until_idle,
            seconds_until_unload=seconds_until_unload,
            available_models=available,
            available_registry=registry_entries,
        )

    async def _ensure_loaded(self) -> None:
        """Lazy loader: loads model or server connection on demand."""
        if not self.is_loaded():
            loaded = await self.load_model()
            if not loaded:
                if self._last_error == "MODEL_SELECTION_REQUIRED":
                    raise RuntimeError("MODEL_SELECTION_REQUIRED")
                raise RuntimeError(
                    f"Failed to load local model ({self._last_error or 'unknown error'}). "
                    f"Ensure GGUF weights exist in '{settings.MODELS_DIR}' "
                    f"or start llama-server at '{settings.LLAMA_SERVER_URL}'."
                )

    async def generate(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> str:
        formatted_messages = _translate_messages(messages)
        lease = await self._acquire_generation()
        worker_owns_lease = False
        repeat_penalty = kwargs.get("repeat_penalty", 1.15)
        min_p = kwargs.get("min_p", 0.05)
        dry_multiplier = kwargs.get("dry_multiplier", 0.8)
        dry_base = kwargs.get("dry_base", 1.75)
        dry_allowed_length = kwargs.get("dry_allowed_length", 2)
        dry_penalty_last_n = kwargs.get("dry_penalty_last_n", 128)
        stop_sequences = kwargs.get("stop", ["<|im_end|>", "<|endoftext|>", "\nUser:"])

        try:
            # Route A: Standalone llama-server via HTTP
            if self._server_is_active:
                async with httpx.AsyncClient(timeout=120.0) as client:
                    payload = {
                        "model": self._active_model_name or "default",
                        "messages": formatted_messages,
                        "temperature": temperature,
                        "max_tokens": max_tokens,
                        "stream": False,
                        "repeat_penalty": repeat_penalty,
                        "min_p": min_p,
                        "dry_multiplier": dry_multiplier,
                        "dry_base": dry_base,
                        "dry_allowed_length": dry_allowed_length,
                        "dry_penalty_last_n": dry_penalty_last_n,
                        "stop": stop_sequences,
                    }
                    resp = await client.post(f"{settings.LLAMA_SERVER_URL}/chat/completions", json=payload)
                    if not resp.is_success:
                        raise ProviderGenerationError("UPSTREAM_HTTP_ERROR")
                    data = resp.json()
                    choice = data["choices"][0]
                    reason = choice.get("finish_reason") or "stop"
                    self.last_finish_reason = reason
                    return GeneratedText(choice["message"]["content"], finish_reason=reason)

            # Route B: In-process llama_cpp
            native_model = self._llm

            def _infer():
                infer_kwargs = {
                    "messages": formatted_messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                    "stream": False,
                    "repeat_penalty": repeat_penalty,
                    "stop": stop_sequences,
                }
                return native_model.create_chat_completion(**infer_kwargs)

            worker = self._start_owned_worker(_infer, lease)
            worker_owns_lease = True
            output = await asyncio.shield(worker)
            choice = output["choices"][0]
            reason = choice.get("finish_reason") or "stop"
            self.last_finish_reason = reason
            return GeneratedText(choice["message"]["content"], finish_reason=reason)
        except httpx.HTTPError:
            raise ProviderGenerationError("UPSTREAM_TRANSPORT_ERROR") from None
        finally:
            if not worker_owns_lease:
                self._release_generation(lease)

    def generate_stream(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> GenerationStream:
        stream_meta: dict[str, Any] = {"finish_reason": "stop", "tool_calls": []}
        tool_call_acc: dict[int, dict[str, Any]] = {}

        def _record_finish(reason: str) -> None:
            stream_meta["finish_reason"] = reason
            self.last_finish_reason = reason

        def _record_tool_calls(deltas: list[Any]) -> None:
            _accumulate_tool_call_deltas(tool_call_acc, deltas)
            stream_meta["tool_calls"] = [tool_call_acc[k] for k in sorted(tool_call_acc)]

        async def _stream_generator() -> AsyncGenerator[str, None]:
            formatted_messages = _translate_messages(messages)
            lease = await self._acquire_generation()
            worker_owns_lease = False
            repeat_penalty = kwargs.get("repeat_penalty", 1.15)
            min_p = kwargs.get("min_p", 0.05)
            dry_multiplier = kwargs.get("dry_multiplier", 0.8)
            dry_base = kwargs.get("dry_base", 1.75)
            dry_allowed_length = kwargs.get("dry_allowed_length", 2)
            dry_penalty_last_n = kwargs.get("dry_penalty_last_n", 128)
            stop_sequences = kwargs.get("stop", ["<|im_end|>", "<|endoftext|>", "\nUser:"])
            tools = kwargs.get("tools")

            try:
                # Route A: Standalone llama-server streaming
                if self._server_is_active:
                    payload = {
                        "model": self._active_model_name or "default",
                        "messages": formatted_messages,
                        "temperature": temperature,
                        "max_tokens": max_tokens,
                        "stream": True,
                        "repeat_penalty": repeat_penalty,
                        "min_p": min_p,
                        "dry_multiplier": dry_multiplier,
                        "dry_base": dry_base,
                        "dry_allowed_length": dry_allowed_length,
                        "dry_penalty_last_n": dry_penalty_last_n,
                        "stop": stop_sequences,
                    }
                    if tools:
                        payload["tools"] = tools
                    has_tool_context = bool(tools) or any(
                        m.get("role") == "tool" or bool(m.get("tool_calls"))
                        for m in formatted_messages
                    )
                    retry_payload: Optional[dict[str, Any]] = None
                    async with httpx.AsyncClient(timeout=120.0) as client:
                        async with client.stream("POST", f"{settings.LLAMA_SERVER_URL}/chat/completions", json=payload) as response:
                            if (
                                not response.is_success
                                and getattr(response, "status_code", None) == 400
                                and has_tool_context
                            ):
                                try:
                                    err_body = (await response.aread()).decode("utf-8", errors="replace")[:400]
                                except Exception:
                                    err_body = ""
                                logger.warning(
                                    f"llama-server returned HTTP 400 with tool payload ({err_body}); "
                                    "retrying once with strict alternating-role messages."
                                )
                                retry_payload = dict(payload)
                                retry_payload.pop("tools", None)
                                retry_payload["messages"] = _flatten_tool_messages_for_strict_template(
                                    formatted_messages
                                )
                            else:
                                async for token in _server_stream_tokens(
                                    response,
                                    on_finish=_record_finish,
                                    on_tool_calls=_record_tool_calls,
                                ):
                                    yield token
                                return
                        if retry_payload is not None:
                            async with client.stream("POST", f"{settings.LLAMA_SERVER_URL}/chat/completions", json=retry_payload) as retry_resp:
                                async for token in _server_stream_tokens(
                                    retry_resp,
                                    on_finish=_record_finish,
                                    on_tool_calls=_record_tool_calls,
                                ):
                                    yield token
                    return

                # Route B: In-process llama_cpp streaming
                queue: asyncio.Queue = asyncio.Queue()
                loop = asyncio.get_running_loop()
                native_model = self._llm

                def _worker():
                    try:
                        infer_kwargs = {
                            "messages": formatted_messages,
                            "temperature": temperature,
                            "max_tokens": max_tokens,
                            "stream": True,
                            "repeat_penalty": repeat_penalty,
                            "stop": stop_sequences,
                        }
                        if tools:
                            infer_kwargs["tools"] = tools
                        stream = native_model.create_chat_completion(**infer_kwargs)
                        for chunk in stream:
                            choices = chunk.get("choices", [])
                            if choices:
                                choice = choices[0]
                                reason = choice.get("finish_reason")
                                if reason:
                                    _record_finish(reason)
                                delta = choice.get("delta", {})
                                raw_tc = delta.get("tool_calls")
                                if isinstance(raw_tc, list) and raw_tc:
                                    _record_tool_calls(raw_tc)
                                token = delta.get("content")
                                if token:
                                    loop.call_soon_threadsafe(queue.put_nowait, token)
                    except Exception as e:
                        loop.call_soon_threadsafe(queue.put_nowait, e)
                    finally:
                        loop.call_soon_threadsafe(queue.put_nowait, None)

                self._start_owned_worker(_worker, lease)
                worker_owns_lease = True

                while True:
                    item = await queue.get()
                    if item is None:
                        break
                    if isinstance(item, Exception):
                        raise item
                    yield item
            except httpx.HTTPError:
                raise ProviderGenerationError("UPSTREAM_TRANSPORT_ERROR") from None
            finally:
                if not worker_owns_lease:
                    self._release_generation(lease)

        return GenerationStream(_stream_generator(), meta=stream_meta)

    async def shutdown(
        self,
        drain_timeout: Optional[float] = None,
        lock_timeout: float = 2.0,
    ) -> ProviderShutdownResult:
        """Drain in-flight generation, acquire lock, unload model, and stop Core router.

        CRITICAL SAFEGUARD (Correction 1 & Safeguard A):
        1. Emits lock-free signal_shutdown_immediately().
        2. Drains active generation up to drain_timeout.
        3. Attempts to acquire self._lock up to lock_timeout.
        4. If lock acquisition fails, DOES NOT touch shared state unlocked; returns
           ProviderShutdownResult(completed_cleanly=False, lock_acquired=False, reason="PROVIDER_LOCK_TIMEOUT").
        5. Inside acquired lock, unloads model, calls _stop_managed_router_locked(),
           and guards against freeing native Route B model while generation lease is held (Safeguard D).
        """
        effective_drain = drain_timeout if drain_timeout is not None else getattr(self, "_shutdown_drain_timeout", 4.0)
        self.signal_shutdown_immediately()

        if self.has_active_generation:
            try:
                await asyncio.wait_for(self._active_work_drained.wait(), timeout=effective_drain)
            except asyncio.TimeoutError:
                self._last_error = "DRAIN_TIMEOUT"
                logger.warning(f"Shutdown drain deadline ({effective_drain}s) reached with active generation")

        # Strict lock acquisition with timeout
        managed_pid = self._server_pid
        managed_core = self._managed_by_core
        try:
            await asyncio.wait_for(self._lock.acquire(), timeout=lock_timeout)
        except asyncio.TimeoutError:
            logger.error(f"Provider shutdown lock acquisition timed out after {lock_timeout}s")
            self._last_error = "PROVIDER_LOCK_TIMEOUT"
            return ProviderShutdownResult(
                completed_cleanly=False,
                lock_acquired=False,
                reason="PROVIDER_LOCK_TIMEOUT",
                managed_llm_pid=managed_pid,
                managed_by_core=managed_core,
            )

        try:
            if self._idle_check_task and not self._idle_check_task.done():
                self._idle_check_task.cancel()

            # Safeguards: Route B native model and Route A router must NOT be freed/stopped while generation active
            if not self.has_active_generation:
                if self._llm is not None:
                    logger.info("Unloading in-process native model on clean shutdown")
                    del self._llm
                    self._llm = None
                    gc.collect()

                # Route A: Core router vs external router
                if self._managed_by_core:
                    stopped = self._stop_managed_router_locked()
                    if not stopped:
                        logger.error("Core-managed router termination failed; reporting incomplete cleanup")
                        return ProviderShutdownResult(
                            completed_cleanly=False,
                            lock_acquired=True,
                            reason="ROUTER_TERMINATION_FAILED",
                            managed_llm_pid=managed_pid,
                            managed_by_core=True,
                        )
                else:
                    # External router: unload model weights via router API if active, but DO NOT terminate router!
                    if self._active_model_name and self._server_is_active:
                        try:
                            runtime_id = resolve_runtime_model_id(self._active_model_name)
                            await self._router_unload_model(runtime_id)
                        except Exception:
                            pass
                    self._active_model_name = None
                    self._runtime_state = LLMRuntimeState.MODEL_UNLOADED

                if self._server_client:
                    try:
                        await self._server_client.aclose()
                    except Exception:
                        pass
                    self._server_client = None
            else:
                logger.warning("Active generation remains; retaining model weights, router, and client leases")

            if self.has_active_generation:
                return ProviderShutdownResult(
                    completed_cleanly=False,
                    lock_acquired=True,
                    reason="DRAIN_TIMEOUT",
                    managed_llm_pid=managed_pid,
                    managed_by_core=managed_core,
                )

            return ProviderShutdownResult(
                completed_cleanly=True,
                lock_acquired=True,
                managed_llm_pid=managed_pid,
                managed_by_core=managed_core,
            )
        finally:
            self._lock.release()
