"""Programmatic entrypoint for the AI Companion local runtime server.

Replaces blind process introspections and non-deterministic SIGINT signals by explicitly
instantiating and owning the uvicorn.Server instance and registering it with the
RuntimeLifecycleCoordinator.
"""

from __future__ import annotations

import argparse
import logging
import sys
from typing import Optional

import uvicorn

from app.core.runtime_lifecycle import runtime_lifecycle

logger = logging.getLogger("app.runtime_server")


def serve_runtime(
    app: str = "app.main:app",
    host: str = "127.0.0.1",
    port: int = 8000,
    log_level: str = "info",
    use_colors: bool = False,
    timeout_graceful_shutdown: int = 4,
) -> None:
    """Launch programmatic Uvicorn runtime server and register with lifecycle coordinator."""
    config = uvicorn.Config(
        app=app,
        host=host,
        port=port,
        log_level=log_level,
        use_colors=use_colors,
        timeout_graceful_shutdown=timeout_graceful_shutdown,
        lifespan="on",
    )
    server = uvicorn.Server(config)
    runtime_lifecycle.register_server(server)
    try:
        logger.info(f"Starting companion runtime server on {host}:{port} (timeout_graceful_shutdown={timeout_graceful_shutdown}s)...")
        server.run()
    finally:
        runtime_lifecycle.unregister_server()
        logger.info("Companion runtime server run loop exited cleanly.")


def main(args: Optional[list[str]] = None) -> None:
    parser = argparse.ArgumentParser(description="AI Companion Runtime Server Entrypoint")
    parser.add_argument("--app", default="app.main:app", help="Application import path (default: app.main:app)")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8000, help="Bind port (default: 8000)")
    parser.add_argument("--log-level", default="info", help="Log level (default: info)")
    parser.add_argument("--use-colors", action=argparse.BooleanOptionalAction, default=False, help="Colorize logs")
    parser.add_argument(
        "--timeout-graceful-shutdown",
        type=int,
        default=4,
        help="Uvicorn graceful shutdown timeout seconds (default: 4)",
    )

    parsed = parser.parse_args(args)
    serve_runtime(
        app=parsed.app,
        host=parsed.host,
        port=parsed.port,
        log_level=parsed.log_level,
        use_colors=parsed.use_colors,
        timeout_graceful_shutdown=parsed.timeout_graceful_shutdown,
    )


if __name__ == "__main__":
    main()
