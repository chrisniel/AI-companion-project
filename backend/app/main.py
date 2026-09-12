"""FastAPI application factory, lifespan management, CORS, and error interceptors."""

import time
import uuid
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from app.api.v1.router import api_v1_router
from app.core.config import settings
from app.core.errors import CompanionAppError, format_error_response
from app.core.logging import logger, setup_logging
from app.db.session import engine


class SecurityAndTracingMiddleware(BaseHTTPMiddleware):
    """Assigns unique request IDs, measures request duration, and strips server headers."""

    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("X-Request-ID") or f"req_{uuid.uuid4().hex[:12]}"
        request.state.request_id = request_id

        start_time = time.perf_counter()
        response: Response = await call_next(request)
        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)

        # Attach tracing headers and strip server banner
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time-Ms"] = str(duration_ms)
        if "server" in response.headers:
            del response.headers["server"]

        logger.info(
            f"{request.method} {request.url.path} -> {response.status_code} ({duration_ms}ms) [req_id={request_id}]"
        )
        return response


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Lifespan context manager for startup and shutdown routines."""
    setup_logging(debug=settings.DEBUG)
    logger.info("Initializing Local AI Core...")

    # Ensure data directory and pairing key exist
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
    token = settings.ensure_pairing_token()
    logger.info("==================================================================")
    logger.info(f"Local AI Core Ready on http://{settings.HOST}:{settings.PORT}")
    logger.info(f"Interactive Swagger Docs: http://{settings.HOST}:{settings.PORT}/docs")
    logger.info(f"Pairing Token (keep secret): {token}")
    logger.info("==================================================================")

    yield

    logger.info("Shutting down Local AI Core, disposing database connections...")
    await engine.dispose()


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        description="Local AI Core backend for AI Companion Project.",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )

    # Tracing and security middleware
    app.add_middleware(SecurityAndTracingMiddleware)

    # CORS Middleware (OWASP API7)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS if isinstance(settings.CORS_ORIGINS, list) else [settings.CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Global Exception Handlers (Error-Handling skill standard)
    @app.exception_handler(CompanionAppError)
    async def companion_error_handler(request: Request, exc: CompanionAppError):
        request_id = getattr(request.state, "request_id", None)
        return format_error_response(
            code=exc.code,
            message=exc.message,
            details=exc.details,
            request_id=request_id,
            status_code=exc.status_code,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, exc: RequestValidationError):
        request_id = getattr(request.state, "request_id", None)
        # Format field validation errors cleanly
        formatted_details = []
        for err in exc.errors():
            loc = " -> ".join(str(l) for l in err.get("loc", []))
            formatted_details.append({"location": loc, "issue": err.get("msg"), "type": err.get("type")})

        return format_error_response(
            code="VALIDATION_FAILED",
            message="Request body or parameter validation failed.",
            details=formatted_details,
            request_id=request_id,
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        )

    @app.exception_handler(Exception)
    async def unhandled_error_handler(request: Request, exc: Exception):
        request_id = getattr(request.state, "request_id", None)
        logger.exception(f"Unhandled internal server error on {request.url.path} [req_id={request_id}]")
        return format_error_response(
            code="INTERNAL_SERVER_ERROR",
            message="An unexpected error occurred on the host server.",
            details=None,
            request_id=request_id,
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    # Mount V1 API
    app.include_router(api_v1_router, prefix=settings.API_V1_STR)

    return app


app = create_app()
