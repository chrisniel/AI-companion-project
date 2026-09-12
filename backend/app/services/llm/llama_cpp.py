"""Llama.cpp / GGUF local model execution provider with VRAM lifecycle management."""

import asyncio
from datetime import datetime, timezone
import gc
import json
import logging
from pathlib import Path
from typing import Any, AsyncGenerator, Dict, List, Optional

import httpx

from app.core.config import settings
from app.schemas.llm import ChatMessage, ModelStatusResponse
from app.services.llm.base import BaseLLMProvider

logger = logging.getLogger("app.services.llm.llama_cpp")


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
        self._server_is_active: bool = False
        self._active_model_name: Optional[str] = None
        self._active_profile: str = settings.LLM_PROFILE
        self._last_active_at: Optional[datetime] = None
        self._idle_check_task: Optional[asyncio.Task] = None
        self._lock = asyncio.Lock()

    @property
    def provider_name(self) -> str:
        return "llama_cpp"

    def _resolve_model_path(self, model_name: Optional[str] = None) -> Path:
        target = model_name or settings.DEFAULT_MODEL_NAME
        models_dir = settings.MODELS_DIR

        # Check in configured models directory
        candidate = models_dir / target
        if candidate.exists():
            return candidate

        # Check if target is a bare name without .gguf
        if not target.endswith(".gguf"):
            candidate_gguf = models_dir / f"{target}.gguf"
            if candidate_gguf.exists():
                return candidate_gguf

        # Fallback to any real .gguf in directory (>100MB)
        all_ggufs = [
            f for f in models_dir.glob("*.gguf")
            if f.is_file() and f.name != "lfs-test.gguf" and f.stat().st_size > 100 * 1024 * 1024
        ]
        if all_ggufs:
            return all_ggufs[0]

        return candidate

    def _get_profile_params(self, profile: str) -> Dict[str, Any]:
        """Map performance profiles (Section 13) to technical context and VRAM layers."""
        p = profile.lower()
        if p == "eco":
            return {"n_ctx": 2048, "n_gpu_layers": 0, "n_threads": 4}
        elif p == "maximum":
            return {"n_ctx": 8192, "n_gpu_layers": 33, "n_threads": 8}
        else:  # balanced
            return {
                "n_ctx": 4096,
                "n_gpu_layers": settings.LLM_GPU_LAYERS,
                "n_threads": 6,
            }

    async def _check_external_server(self) -> bool:
        """Check if a local standalone llama-server or OpenAI-compatible server is running."""
        try:
            async with httpx.AsyncClient(timeout=1.0) as client:
                # Most llama-server builds provide /health or /v1/models
                resp = await client.get(f"{settings.LLAMA_SERVER_URL}/models")
                if resp.status_code == 200:
                    self._server_is_active = True
                    return True
        except Exception:
            pass
        self._server_is_active = False
        return False

    async def load_model(self, model_name: Optional[str] = None, profile: Optional[str] = None) -> bool:
        async with self._lock:
            if profile:
                self._active_profile = profile

            # Mode 1: Check if standalone llama-server is running
            if await self._check_external_server():
                logger.info(f"Connected to active external llama-server at {settings.LLAMA_SERVER_URL}")
                self._active_model_name = model_name or settings.DEFAULT_MODEL_NAME
                self._last_active_at = datetime.now(timezone.utc)
                self._start_idle_monitor()
                return True

            # Mode 2: In-process llama_cpp
            model_path = self._resolve_model_path(model_name)
            if not model_path.exists():
                logger.warning(f"Model file '{model_path}' not found on disk.")
                return False

            try:
                import llama_cpp
            except ImportError:
                logger.info(
                    f"llama-cpp-python not installed in-process. "
                    f"Start llama-server at {settings.LLAMA_SERVER_URL} or use Mock provider."
                )
                return False

            params = self._get_profile_params(self._active_profile)
            logger.info(
                f"Loading model '{model_path.name}' with profile '{self._active_profile}' "
                f"(ctx={params['n_ctx']}, gpu_layers={params['n_gpu_layers']})..."
            )

            def _load():
                return llama_cpp.Llama(
                    model_path=str(model_path),
                    n_ctx=params["n_ctx"],
                    n_gpu_layers=params["n_gpu_layers"],
                    n_threads=params["n_threads"],
                    verbose=settings.DEBUG,
                )

            self._llm = await asyncio.to_thread(_load)
            self._active_model_name = model_path.name
            self._last_active_at = datetime.now(timezone.utc)
            self._start_idle_monitor()
            logger.info(f"Model '{model_path.name}' successfully loaded into memory.")
            return True

    async def unload_model(self) -> bool:
        async with self._lock:
            if self._llm is not None:
                logger.info(f"Unloading in-process model '{self._active_model_name}' to free VRAM (Section 12)...")
                del self._llm
                self._llm = None
                self._active_model_name = None
                gc.collect()
                logger.info("Model unloaded successfully.")
            self._server_is_active = False
            return True

    def is_loaded(self) -> bool:
        return self._llm is not None or self._server_is_active

    def _start_idle_monitor(self) -> None:
        if self._idle_check_task and not self._idle_check_task.done():
            return
        self._idle_check_task = asyncio.create_task(self._idle_monitor_loop())

    async def _idle_monitor_loop(self) -> None:
        """Periodic background monitor checking for idle timeout auto-unload."""
        while self.is_loaded():
            await asyncio.sleep(30)
            if not self.is_loaded():
                break

            if self._last_active_at:
                elapsed = (datetime.now(timezone.utc) - self._last_active_at).total_seconds()
                if elapsed >= settings.LLM_IDLE_TIMEOUT_SECONDS:
                    logger.info(f"Model idle for {int(elapsed)}s (threshold: {settings.LLM_IDLE_TIMEOUT_SECONDS}s). Triggering auto-unload.")
                    await self.unload_model()
                    break

    async def get_status(self) -> ModelStatusResponse:
        params = self._get_profile_params(self._active_profile)
        available = []
        if settings.MODELS_DIR.exists():
            available = [
                f.name for f in settings.MODELS_DIR.glob("*.gguf")
                if f.is_file() and f.name != "lfs-test.gguf" and f.stat().st_size > 100 * 1024 * 1024
            ]

        seconds_left = None
        if self.is_loaded() and self._last_active_at:
            elapsed = (datetime.now(timezone.utc) - self._last_active_at).total_seconds()
            seconds_left = max(0, int(settings.LLM_IDLE_TIMEOUT_SECONDS - elapsed))

        return ModelStatusResponse(
            provider=self.provider_name,
            is_loaded=self.is_loaded(),
            active_model=self._active_model_name,
            active_profile=self._active_profile,
            available_models=available,
            context_size=params["n_ctx"],
            gpu_layers=params["n_gpu_layers"],
            idle_timeout_seconds=settings.LLM_IDLE_TIMEOUT_SECONDS,
            seconds_until_unload=seconds_left,
        )

    async def _ensure_loaded(self) -> None:
        """Lazy loader: loads model or server connection on demand."""
        if not self.is_loaded():
            loaded = await self.load_model()
            if not loaded:
                raise RuntimeError(
                    f"Failed to load local model. Ensure GGUF weights exist in '{settings.MODELS_DIR}' "
                    f"or start llama-server at '{settings.LLAMA_SERVER_URL}'."
                )

    async def generate(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> str:
        await self._ensure_loaded()
        self._last_active_at = datetime.now(timezone.utc)
        formatted_messages = [{"role": m.role, "content": m.content} for m in messages]

        # Route A: Standalone llama-server via HTTP
        if self._server_is_active:
            async with httpx.AsyncClient(timeout=120.0) as client:
                payload = {
                    "messages": formatted_messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                    "stream": False,
                }
                resp = await client.post(f"{settings.LLAMA_SERVER_URL}/chat/completions", json=payload)
                resp.raise_for_status()
                data = resp.json()
                return data["choices"][0]["message"]["content"]

        # Route B: In-process llama_cpp
        def _infer():
            return self._llm.create_chat_completion(
                messages=formatted_messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=False,
            )

        output = await asyncio.to_thread(_infer)
        return output["choices"][0]["message"]["content"]

    async def generate_stream(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> AsyncGenerator[str, None]:
        await self._ensure_loaded()
        self._last_active_at = datetime.now(timezone.utc)
        formatted_messages = [{"role": m.role, "content": m.content} for m in messages]

        # Route A: Standalone llama-server streaming
        if self._server_is_active:
            payload = {
                "messages": formatted_messages,
                "temperature": temperature,
                "max_tokens": max_tokens,
                "stream": True,
            }
            async with httpx.AsyncClient(timeout=120.0) as client:
                async with client.stream("POST", f"{settings.LLAMA_SERVER_URL}/chat/completions", json=payload) as response:
                    async for line in response.aiter_lines():
                        if not line or not line.startswith("data: "):
                            continue
                        raw = line[6:].strip()
                        if raw == "[DONE]":
                            break
                        try:
                            chunk = json.loads(raw)
                            delta = chunk["choices"][0].get("delta", {})
                            token = delta.get("content")
                            if token:
                                yield token
                        except Exception:
                            continue
            return

        # Route B: In-process llama_cpp streaming
        queue: asyncio.Queue = asyncio.Queue()
        loop = asyncio.get_running_loop()

        def _worker():
            try:
                stream = self._llm.create_chat_completion(
                    messages=formatted_messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    stream=True,
                )
                for chunk in stream:
                    delta = chunk["choices"][0].get("delta", {})
                    token = delta.get("content")
                    if token:
                        loop.call_soon_threadsafe(queue.put_nowait, token)
            except Exception as e:
                loop.call_soon_threadsafe(queue.put_nowait, e)
            finally:
                loop.call_soon_threadsafe(queue.put_nowait, None)

        asyncio.create_task(asyncio.to_thread(_worker))

        while True:
            item = await queue.get()
            if item is None:
                break
            if isinstance(item, Exception):
                raise item
            yield item
