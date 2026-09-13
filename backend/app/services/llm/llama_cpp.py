"""Llama.cpp / GGUF local model execution provider with VRAM lifecycle management."""

import asyncio
from datetime import datetime, timezone
import gc
import importlib
import json
import logging
from pathlib import Path
import subprocess
from typing import Any, AsyncGenerator, Dict, List, Optional

import httpx

from app.core.config import settings
from app.schemas.llm import ChatMessage, ModelStatusResponse
from app.services.llm.base import BaseLLMProvider
from app.services.llm.runtime_state import LLMRuntimeState
from app.services.model_registry import build_model_list, resolve_runtime_model_id

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
        self._server_process: Optional[subprocess.Popen] = None
        self._server_pid: Optional[int] = None
        self._server_launch_args: list = []
        self._server_started_at: Optional[datetime] = None
        self._managed_by_core: bool = False
        self._server_is_active: bool = False
        self._active_model_name: Optional[str] = None
        self._active_profile: str = settings.LLM_PROFILE
        self._last_active_at: Optional[datetime] = None
        self._idle_check_task: Optional[asyncio.Task] = None
        self._lock = asyncio.Lock()
        self._runtime_state: LLMRuntimeState = LLMRuntimeState.SERVER_STOPPED
        self._generation_active: bool = False
        self._engine_version: str = "b10936"

    @property
    def provider_name(self) -> str:
        return "llama_cpp"

    async def _router_load_model(self, model_name: str) -> bool:
        """Load model into VRAM via router API — LLAMA_CPP_RUNTIME_ARCHITECTURE.md §5."""
        runtime_id = resolve_runtime_model_id(model_name)
        url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models/load"
        try:
            async with httpx.AsyncClient(timeout=45.0) as c:
                r = await c.post(url, json={"model": runtime_id})
                if r.status_code not in (200, 201):
                    logger.error(f"Router load rejected {r.status_code}: {r.text[:200]}")
                    return False
                
                # Poll router /models to verify status.value == 'loaded'
                models_url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models"
                for _ in range(60):
                    await asyncio.sleep(0.5)
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
                return True
        except Exception as exc:
            logger.error(f"Router load failed: {exc}")
            return False

    async def _router_unload_model(self, model_name: str) -> bool:
        """Unload model from VRAM — router stays alive (runtime arch §5 Explicit Unload)."""
        runtime_id = resolve_runtime_model_id(model_name)
        url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models/unload"
        try:
            async with httpx.AsyncClient(timeout=15.0) as c:
                r = await c.post(url, json={"model": runtime_id})
                if r.status_code not in (200, 204):
                    return False
                
                # Poll router /models to verify status.value == 'unloaded'
                models_url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models"
                for _ in range(20):
                    await asyncio.sleep(0.25)
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
                return True
        except Exception as exc:
            logger.error(f"Router unload failed: {exc}")
            return False

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
            f for f in models_dir.rglob("*.gguf")
            if f.is_file() and f.name != "lfs-test.gguf" and not f.name.startswith("mmproj") and f.stat().st_size > 100 * 1024 * 1024
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
        """Check if a local standalone llama-server is active on port 8080."""
        try:
            async with httpx.AsyncClient(timeout=0.3) as client:
                base_health_url = settings.LLAMA_SERVER_URL.replace("/v1", "") + "/health"
                resp = await client.get(base_health_url)
                if resp.status_code == 200:
                    self._server_is_active = True
                    return True
        except Exception:
            pass
        self._server_is_active = False
        return False

    async def load_model(self, model_name: Optional[str] = None, profile: Optional[str] = None) -> bool:
        async with self._lock:
            self._last_error = None
            if profile:
                self._active_profile = profile

            if model_name:
                if ".." in model_name or model_name.startswith("/") or model_name.startswith("\\"):
                    self._last_error = "MODEL_PATH_TRAVERSAL"
                    return False

            runtime_id = resolve_runtime_model_id(model_name)
            if not runtime_id:
                runtime_id = resolve_runtime_model_id(settings.DEFAULT_MODEL_NAME) or "qwen3-vl-4b-instruct"

            target_model_name = runtime_id

            # Mode 1: Check if standalone llama-server router is already running
            if await self._check_external_server():
                logger.info(f"Connected to active external llama-server at {settings.LLAMA_SERVER_URL}")
                self._runtime_state = LLMRuntimeState.MODEL_LOADING
                if await self._router_load_model(target_model_name):
                    self._runtime_state = LLMRuntimeState.MODEL_READY
                    self._active_model_name = target_model_name
                    self._last_active_at = datetime.now(timezone.utc)
                    self._start_idle_monitor()
                    return True
                else:
                    self._last_error = f"MODEL_LOAD_FAILED: {target_model_name}"
                    self._runtime_state = LLMRuntimeState.MODEL_ERROR
                    return False

            # Mode 2: Launch standalone llama-server.exe router
            server_exe = settings.LLAMA_CPP_BIN_DIR / "llama-server.exe"
            if not server_exe.exists():
                self._last_error = f"ENGINE_NOT_FOUND: {server_exe}"
                logger.error(self._last_error)
                self._runtime_state = LLMRuntimeState.SERVER_ERROR
                return False

            if not settings.LLAMA_MODELS_DIR.exists():
                self._last_error = f"MODELS_DIR_NOT_FOUND: {settings.LLAMA_MODELS_DIR}"
                logger.error(self._last_error)
                self._runtime_state = LLMRuntimeState.MODEL_ERROR
                return False

            params = self._get_profile_params(self._active_profile)
            logger.info(
                f"Launching standalone llama-server router with Vulkan offload "
                f"({params['n_gpu_layers']} GPU layers, model={target_model_name})..."
            )
            settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
            log_file_path = (settings.DATA_DIR / "llama_server.log").resolve()
            try:
                if log_file_path.exists():
                    log_file_path.write_text("", encoding="utf-8")
            except Exception:
                pass

            launch_args = [
                str(server_exe.resolve()),
                "--models-dir", str(settings.LLAMA_MODELS_DIR.resolve()),
                "--host", settings.LLAMA_ROUTER_HOST,
                "--port", str(settings.LLAMA_ROUTER_PORT),
                "--sleep-idle-seconds", str(settings.LLAMA_ROUTER_IDLE_TIMEOUT),
                "--models-max", str(settings.LLAMA_ROUTER_MODELS_MAX),
                "--parallel", "1",
                "--no-webui",
                "--metrics",
                "--n-gpu-layers", str(params["n_gpu_layers"]),
                "--threads", str(params["n_threads"]),
                "--log-file", str(log_file_path),
                "--log-timestamps",
            ]

            self._runtime_state = LLMRuntimeState.SERVER_STARTING
            try:
                proc = subprocess.Popen(
                    launch_args,
                    cwd=str(settings.LLAMA_CPP_BIN_DIR.resolve()),
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                self._server_process = proc
                self._server_pid = proc.pid
                self._managed_by_core = True
                self._server_launch_args = launch_args
                self._server_started_at = datetime.now(timezone.utc)
                logger.info(f"Router spawned PID={proc.pid}")
            except Exception as e:
                self._last_error = f"LAUNCH_FAILED: {e}"
                logger.error(self._last_error)
                self._runtime_state = LLMRuntimeState.SERVER_ERROR
                return False

            # Poll for readiness up to 45 seconds
            healthy = False
            for _ in range(90):
                await asyncio.sleep(0.5)
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
                    return False
                if await self._check_external_server():
                    healthy = True
                    self._runtime_state = LLMRuntimeState.MODEL_UNLOADED
                    logger.info(f"Router healthy on port {settings.LLAMA_ROUTER_PORT}")
                    break

            if not healthy:
                self._last_error = "ROUTER_TIMEOUT: not healthy within 45s"
                self._runtime_state = LLMRuntimeState.SERVER_ERROR
                return False

            # Load model into VRAM via router API
            self._runtime_state = LLMRuntimeState.MODEL_LOADING
            if await self._router_load_model(target_model_name):
                self._runtime_state = LLMRuntimeState.MODEL_READY
                self._active_model_name = target_model_name
                self._last_active_at = datetime.now(timezone.utc)
                self._start_idle_monitor()
                logger.info(f"Model loaded: {target_model_name}")
                return True
            else:
                self._last_error = f"MODEL_LOAD_FAILED: {target_model_name}"
                self._runtime_state = LLMRuntimeState.MODEL_ERROR
                return False

    async def unload_model(self) -> bool:
        async with self._lock:
            if self._generation_active:
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
                    logger.info("Model unloaded via router API; router alive")
                    return True
                logger.warning("Router API unload failed; escalating to scoped PID termination")

            # 3. Fallback: scoped PID termination — runtime arch §5 invariant: NEVER taskkill /IM
            if self._managed_by_core and self._server_process:
                logger.info(f"Terminating Core-owned router PID={self._server_pid}")
                try:
                    self._server_process.terminate()
                    try:
                        self._server_process.wait(timeout=5.0)
                    except subprocess.TimeoutExpired:
                        self._server_process.kill()
                except Exception as exc:
                    logger.error(f"PID termination failed: {exc}")

            self._server_process = None
            self._server_pid = None
            self._managed_by_core = False
            self._server_is_active = False
            self._active_model_name = None
            self._generation_active = False
            self._runtime_state = LLMRuntimeState.SERVER_STOPPED
            if self._server_client:
                await self._server_client.aclose()
                self._server_client = None
            logger.info("Model unloaded successfully. Scoped termination complete.")
            return True

    async def set_profile(self, profile: str) -> bool:
        async with self._lock:
            p = profile.lower()
            if p not in ("eco", "balanced", "maximum"):
                return False
            self._active_profile = p
            logger.info(f"LLM hardware profile set to '{p}'")
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
        # Live probe external llama-server process if not in-process
        if self._llm is None:
            if await self._check_external_server():
                router_models_url = f"http://{settings.LLAMA_ROUTER_HOST}:{settings.LLAMA_ROUTER_PORT}/models"
                loaded_model_id = None
                try:
                    async with httpx.AsyncClient(timeout=1.0) as client:
                        resp = await client.get(router_models_url)
                        if resp.status_code == 200:
                            data = resp.json()
                            models = data.get("data") or data.get("models") or []
                            for m in models:
                                if m.get("status", {}).get("value") == "loaded":
                                    loaded_model_id = m.get("id")
                                    break
                except Exception:
                    pass

                if loaded_model_id:
                    self._active_model_name = loaded_model_id
                    self._runtime_state = LLMRuntimeState.MODEL_READY
                    if not self._last_active_at:
                        self._last_active_at = datetime.now(timezone.utc)
                else:
                    self._active_model_name = None
                    self._runtime_state = LLMRuntimeState.MODEL_UNLOADED
            else:
                self._server_is_active = False
                self._active_model_name = None
                if self._runtime_state not in (LLMRuntimeState.MODEL_ERROR, LLMRuntimeState.SERVER_ERROR):
                    self._runtime_state = LLMRuntimeState.SERVER_STOPPED

        params = self._get_profile_params(self._active_profile)
        available = []
        if settings.MODELS_DIR.exists():
            for f in settings.MODELS_DIR.rglob("*.gguf"):
                if (
                    f.is_file()
                    and f.name != "lfs-test.gguf"
                    and not f.name.startswith("mmproj")
                    and f.stat().st_size > 100 * 1024 * 1024
                ):
                    available.append(f.relative_to(settings.MODELS_DIR).as_posix())

        registry_entries = [m.primary_file for m in build_model_list() if m.primary_file_exists]

        seconds_left = None
        if self.is_loaded() and self._last_active_at:
            elapsed = (datetime.now(timezone.utc) - self._last_active_at).total_seconds()
            seconds_left = max(0, int(settings.LLM_IDLE_TIMEOUT_SECONDS - elapsed))

        is_loaded = self.is_loaded()

        return ModelStatusResponse(
            provider=self.provider_name,
            is_loaded=is_loaded,
            active_model=self._active_model_name if is_loaded else None,
            active_profile=self._active_profile,
            available_models=available,
            available_registry=registry_entries,
            context_size=params["n_ctx"],
            gpu_layers=params["n_gpu_layers"],
            idle_timeout_seconds=settings.LLM_IDLE_TIMEOUT_SECONDS,
            seconds_until_unload=seconds_left,
            seconds_until_idle=seconds_left,
            runtime_state=self._runtime_state,
            generation_active=self._generation_active,
            managed_by_core=self._managed_by_core,
            engine_version=self._engine_version,
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
        self._generation_active = True
        formatted_messages = [{"role": m.role, "content": m.content} for m in messages]

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
        finally:
            self._generation_active = False

    async def generate_stream(
        self,
        messages: List[ChatMessage],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        **kwargs
    ) -> AsyncGenerator[str, None]:
        await self._ensure_loaded()
        self._last_active_at = datetime.now(timezone.utc)
        self._generation_active = True
        formatted_messages = [{"role": m.role, "content": m.content} for m in messages]

        try:
            # Route A: Standalone llama-server streaming
            if self._server_is_active:
                payload = {
                    "model": self._active_model_name or "default",
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
        finally:
            self._generation_active = False

    async def shutdown(self) -> None:
        """Drain in-flight generation, unload model, stop router."""
        self._generation_active = False
        await self.unload_model()
