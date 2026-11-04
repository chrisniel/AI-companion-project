"""Runtime lifecycle coordinator: programmatic server control, whole-runtime admission control, and DB quiescence."""

from __future__ import annotations

import asyncio
import logging
from typing import TYPE_CHECKING, Coroutine, Optional, Set

from app.services.llm.base import BaseLLMProvider
from app.services.llm.manager import llm_manager

if TYPE_CHECKING:
    import uvicorn

logger = logging.getLogger("app.core.runtime_lifecycle")


def get_llm_provider() -> BaseLLMProvider:
    """Resolve active LLM provider from manager."""
    return llm_manager.get_provider()


class RuntimeLifecycleCoordinator:
    """Coordinates graceful runtime termination, request admission, and database quiescence."""

    def __init__(self) -> None:
        self._server: Optional[uvicorn.Server] = None
        self._is_shutting_down: bool = False
        self._shutdown_phase: Optional[str] = None
        self._shutdown_quiescence_status: Optional[str] = None
        self._active_asgi_mutations: int = 0
        self._active_stream_tasks: Set[asyncio.Task] = set()
        self._pending_persistence_tasks: Set[asyncio.Task] = set()
        self._managed_llm_pid: Optional[int] = None
        self._managed_by_core: bool = False
        self._shutdown_task: Optional[asyncio.Task] = None
        self._lock = asyncio.Lock()

    def reset(self) -> None:
        """Reset coordinator state (for testing)."""
        self._server = None
        self._is_shutting_down = False
        self._shutdown_phase = None
        self._shutdown_quiescence_status = None
        self._active_asgi_mutations = 0
        self._active_stream_tasks.clear()
        self._pending_persistence_tasks.clear()
        self._managed_llm_pid = None
        self._managed_by_core = False
        if self._shutdown_task and not self._shutdown_task.done():
            self._shutdown_task.cancel()
        self._shutdown_task = None

    @property
    def is_shutting_down(self) -> bool:
        return self._is_shutting_down

    @property
    def shutdown_phase(self) -> Optional[str]:
        return self._shutdown_phase

    @property
    def shutdown_quiescence_status(self) -> Optional[str]:
        return self._shutdown_quiescence_status

    @property
    def managed_llm_pid(self) -> Optional[int]:
        return self._managed_llm_pid

    @property
    def managed_by_core(self) -> bool:
        return self._managed_by_core

    @property
    def has_active_database_work(self) -> bool:
        """Truthful indicator of active DB work: in-flight mutations or incomplete persistence tasks."""
        active_tasks = any(not t.done() for t in self._pending_persistence_tasks)
        return self._active_asgi_mutations > 0 or active_tasks

    def register_server(self, server: uvicorn.Server) -> None:
        """Register the exact running uvicorn.Server instance for programmatic shutdown."""
        self._server = server

    def unregister_server(self) -> None:
        """Clear reference when server exits."""
        self._server = None

    def acquire_mutation_admission(self) -> bool:
        """Acquire admission for a mutating ASGI request (POST/PUT/PATCH/DELETE).

        Returns False if runtime is shutting down (503 RUNTIME_SHUTTING_DOWN).
        """
        if self._is_shutting_down:
            return False
        self._active_asgi_mutations += 1
        return True

    def release_mutation_admission(self) -> None:
        """Release admission for a mutating ASGI request."""
        self._active_asgi_mutations = max(0, self._active_asgi_mutations - 1)

    def register_stream_task(self, task: asyncio.Task) -> None:
        """Track active SSE / inference streaming tasks."""
        self._active_stream_tasks.add(task)
        task.add_done_callback(lambda t: self._active_stream_tasks.discard(t))

    def spawn_terminal_persistence_task(self, coro: Coroutine) -> asyncio.Task:
        """Spawn and track a background persistence task that must complete before DB disposal."""
        task = asyncio.create_task(coro)
        self._pending_persistence_tasks.add(task)
        task.add_done_callback(lambda t: self._pending_persistence_tasks.discard(t))
        return task

    async def wait_for_database_quiescence(self, timeout: float = 6.0) -> bool:
        """Wait until all active ASGI mutations and pending persistence tasks complete.

        CRITICAL SAFEGUARD (Correction 2):
        Clean shutdown requires confirmed completion (all(t.done()) and _active_asgi_mutations == 0).
        Returns True if quiescent before deadline, False if timeout expired with active work.
        """
        deadline = asyncio.get_running_loop().time() + timeout
        while self.has_active_database_work:
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                logger.warning(
                    f"Quiescence timeout ({timeout}s) expired with active DB work: "
                    f"active_mutations={self._active_asgi_mutations}, "
                    f"pending_persistence={len([t for t in self._pending_persistence_tasks if not t.done()])}"
                )
                return False
            await asyncio.sleep(min(0.05, remaining))
        return True

    async def initiate_shutdown(
        self,
        reason: str = "user_exit_companion",
        drain_timeout_seconds: float = 6.0,
    ) -> tuple[bool, str]:
        """Initiate cooperative runtime shutdown sequence.

        Returns (already_shutting_down, message).
        """
        async with self._lock:
            if self._is_shutting_down:
                return True, "already_shutting_down"

            self._is_shutting_down = True
            self._shutdown_phase = "closing_admission"
            logger.info(f"Initiated runtime shutdown (reason={reason}, drain_timeout={drain_timeout_seconds}s)")

            self._shutdown_task = asyncio.create_task(
                self._execute_shutdown_sequence(drain_timeout_seconds)
            )
            return False, "shutdown_initiated"

    async def _execute_shutdown_sequence(self, drain_timeout: float) -> None:
        """Execute the coordinated 5-phase backend teardown sequence."""
        try:
            # Phase 2: Cancel active streams and signal provider immediate shutdown
            logger.info("Shutdown Phase 2: Signalling cancellation of active streams and model load")
            for task in list(self._active_stream_tasks):
                if not task.done():
                    task.cancel()

            try:
                provider = get_llm_provider()
                provider.signal_shutdown_immediately()
            except Exception as e:
                logger.warning(f"Error signalling provider shutdown: {e}")

            # Phase 3: Await real database quiescence
            logger.info("Shutdown Phase 3: Awaiting database quiescence barrier")
            self._shutdown_phase = "draining_work"
            quiescent = await self.wait_for_database_quiescence(timeout=drain_timeout)
            if not quiescent:
                self._shutdown_quiescence_status = "incomplete_db_quiescence_timeout"
                logger.error(
                    "Database quiescence barrier timeout; halting shutdown sequence "
                    "to prevent engine disposal and data corruption while writes remain active"
                )
                return

            # Phase 4: Synchronized provider & router shutdown
            logger.info("Shutdown Phase 4: Synchronized provider and router shutdown under provider lock")
            self._shutdown_phase = "stopping_provider"
            try:
                res = await provider.shutdown(drain_timeout=4.0, lock_timeout=2.0)
                self._managed_llm_pid = res.managed_llm_pid
                self._managed_by_core = res.managed_by_core

                if not res.lock_acquired:
                    self._shutdown_quiescence_status = "incomplete_provider_lock_timeout"
                    logger.error("Provider lock timeout; halting shutdown to keep runtime observable")
                    return

                if not res.completed_cleanly:
                    self._shutdown_quiescence_status = f"incomplete_provider_{res.reason or 'unknown'}"
                    logger.warning(f"Provider shutdown incomplete: {res.reason}")
                    return
            except Exception as e:
                logger.error(f"Error during provider shutdown: {e}")
                self._shutdown_quiescence_status = "incomplete_provider_exception"
                return

            # Phase 5: Lifespan exit & safe Uvicorn shutdown
            logger.info("Shutdown Phase 5: Reached clean quiescence; signalling uvicorn.Server exit")
            self._shutdown_quiescence_status = "clean"
            self._shutdown_phase = "shutting_down_server"
            if self._server:
                self._server.should_exit = True
                logger.info("Server exit signaled (server.should_exit = True)")
        except Exception as exc:
            logger.critical(f"Unhandled exception in shutdown sequence: {exc}", exc_info=True)
            self._shutdown_quiescence_status = "incomplete_unhandled_exception"


# Global singleton coordinator
runtime_lifecycle = RuntimeLifecycleCoordinator()
