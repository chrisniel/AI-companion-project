import re
import time
import uuid
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from app.api.v1.router import api_v1_router
from app.core.config import settings
from app.core.errors import (
    CompanionAppError,
    CompanionPayloadTooLargeError,
    format_error_response,
)
from app.core.logging import logger, setup_logging
from app.core.runtime_lifecycle import runtime_lifecycle
from app.db.session import dispose_database_runtime, initialize_database_runtime

REQUEST_ID_PATTERN = re.compile(r"^[a-zA-Z0-9_-]{1,64}$")
ATTACHMENT_UPLOAD_PATH_RE = re.compile(r"^/api/v1/conversations/[^/]+/attachments/?$")


class SecurityAndTracingMiddleware(BaseHTTPMiddleware):
    """Assigns sanitized unique request IDs, measures request duration, and strips server headers."""

    async def dispatch(self, request: Request, call_next) -> Response:
        raw_request_id = request.headers.get("X-Request-ID")
        if raw_request_id and REQUEST_ID_PATTERN.match(raw_request_id):
            request_id = raw_request_id
        else:
            request_id = f"req_{uuid.uuid4().hex[:12]}"

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


class PayloadLimitMiddleware(BaseHTTPMiddleware):
    """Enforces maximum request body size on Content-Length and streaming chunks (OWASP API4)."""

    def __init__(self, app, max_bytes: int = settings.MAX_REQUEST_BODY_BYTES):
        super().__init__(app)
        self.max_bytes = max_bytes

    def _resolve_max_bytes(self, request: Request) -> int:
        if request.method == "POST" and ATTACHMENT_UPLOAD_PATH_RE.match(request.url.path):
            return settings.MAX_ATTACHMENT_REQUEST_BODY_BYTES
        return self.max_bytes

    async def dispatch(self, request: Request, call_next) -> Response:
        effective_max = self._resolve_max_bytes(request)
        request.state.effective_max_bytes = effective_max

        # 1. Fast path check on Content-Length header
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > effective_max:
                    request_id = getattr(request.state, "request_id", None) or f"req_{uuid.uuid4().hex[:12]}"
                    return format_error_response(
                        code="PAYLOAD_TOO_LARGE",
                        message=f"Request payload exceeds maximum allowed size of {effective_max} bytes.",
                        details=None,
                        request_id=request_id,
                        status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                    )
            except ValueError:
                pass

        # 2. Stream byte counter for chunked/streaming requests without Content-Length
        original_receive = request._receive
        total_received = 0

        async def streaming_counter_receive():
            nonlocal total_received
            message = await original_receive()
            if message.get("type") == "http.request":
                body_bytes = message.get("body", b"")
                total_received += len(body_bytes)
                if total_received > effective_max:
                    request.state.stream_bytes_exceeded = True
                    raise CompanionPayloadTooLargeError(
                        message=f"Request stream exceeded maximum allowed size of {effective_max} bytes."
                    )
            return message

        request._receive = streaming_counter_receive

        try:
            response = await call_next(request)
            if getattr(request.state, "stream_bytes_exceeded", False):
                request_id = getattr(request.state, "request_id", None) or f"req_{uuid.uuid4().hex[:12]}"
                return format_error_response(
                    code="PAYLOAD_TOO_LARGE",
                    message=f"Request payload exceeds maximum allowed size of {effective_max} bytes.",
                    details=None,
                    request_id=request_id,
                    status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                )
            return response
        except CompanionPayloadTooLargeError:
            request_id = getattr(request.state, "request_id", None) or f"req_{uuid.uuid4().hex[:12]}"
            return format_error_response(
                code="PAYLOAD_TOO_LARGE",
                message=f"Request payload exceeds maximum allowed size of {effective_max} bytes.",
                details=None,
                request_id=request_id,
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            )


class RuntimeAdmissionASGIMiddleware:
    """Full-ASGI lifecycle admission gate and request tracking during graceful shutdown.

    Directives:
    - Rejects new mutating requests (POST/PUT/PATCH/DELETE) and database-dependent read requests (GET)
      during shutdown with 503 RUNTIME_SHUTTING_DOWN.
    - Tracks active in-flight mutations and read-only database operations so that shutdown quiescence
      awaits their completion before database engine disposal.
    - Permits essential health, system status, model status, and shutdown endpoints without unsafe DB access.
    """

    NON_DB_PATHS = {
        "/api/v1/health",
        "/health",
        "/api/v1/system/status",
        "/api/v1/system/shutdown",
        "/docs",
        "/redoc",
        "/openapi.json",
    }

    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        method = scope.get("method", "GET")
        path = scope.get("path", "").rstrip("/")
        is_exempt = path in self.NON_DB_PATHS or path.startswith("/docs") or path.startswith("/openapi")

        if is_exempt:
            await self.app(scope, receive, send)
            return

        is_mutation = method in ("POST", "PUT", "PATCH", "DELETE")

        if is_mutation:
            if not runtime_lifecycle.acquire_mutation_admission():
                state = scope.get("state", {})
                req_id = state.get("request_id") if isinstance(state, dict) else None
                request_id = req_id or f"req_{uuid.uuid4().hex[:12]}"
                response = format_error_response(
                    code="RUNTIME_SHUTTING_DOWN",
                    message="Runtime is currently shutting down. Mutations are rejected.",
                    details=None,
                    request_id=request_id,
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
                await response(scope, receive, send)
                return

            try:
                await self.app(scope, receive, send)
            finally:
                runtime_lifecycle.release_mutation_admission()
        else:
            if not runtime_lifecycle.acquire_read_admission():
                state = scope.get("state", {})
                req_id = state.get("request_id") if isinstance(state, dict) else None
                request_id = req_id or f"req_{uuid.uuid4().hex[:12]}"
                response = format_error_response(
                    code="RUNTIME_SHUTTING_DOWN",
                    message="Runtime is currently shutting down. Database operations are rejected.",
                    details=None,
                    request_id=request_id,
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
                await response(scope, receive, send)
                return

            try:
                await self.app(scope, receive, send)
            finally:
                runtime_lifecycle.release_read_admission()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Lifespan context manager for startup and shutdown routines."""
    setup_logging(debug=settings.DEBUG)
    logger.info("Initializing Local AI Runtime...")

    # Step 1: Storage preflight & safe migration (Batch 8P.3)
    from app.core.storage import (
        assess_migration_preflight,
        execute_migration,
        prepare_database_schema,
    )

    legacy_candidates = [
        settings.BASE_DIR / "data" / "companion.db",           # backend/data/companion.db
        settings.BASE_DIR.parent / "data" / "companion.db",    # data/companion.db
    ]
    preflight_decision = assess_migration_preflight(
        canonical_db_path=settings.DATABASE_PATH,
        legacy_candidates=legacy_candidates,
    )
    execute_migration(
        decision=preflight_decision,
        canonical_db_path=settings.DATABASE_PATH,
        backup_dir=settings.BACKUP_DIR,
    )

    # Step 2: Ensure schema is at Alembic head BEFORE initializing runtime engine
    settings.DATABASE_DIR.mkdir(parents=True, exist_ok=True)
    prepare_database_schema(canonical_db_path=settings.DATABASE_PATH)
    from app.core.host_admin import initialize_host_admin_secret
    initialize_host_admin_secret()
    initialize_database_runtime(database_url=settings.DATABASE_URL, debug=settings.DEBUG)

    # Step 3: Ensure pairing key exists
    settings.ensure_pairing_token()
    logger.info("==================================================================")
    logger.info(f"Local AI Runtime Ready on http://{settings.HOST}:{settings.PORT}")
    if settings.ENVIRONMENT == "development":
        logger.info(f"Interactive Swagger Docs: http://{settings.HOST}:{settings.PORT}/docs")
    logger.info("Pairing credential verified successfully.")
    logger.info("Pairing credential initialized using selected local configuration.")
    logger.info("==================================================================")

    yield

    logger.info("Shutting down Local AI Runtime, draining LLM and disposing database...")
    try:
        from app.services.llm.manager import llm_manager
        await llm_manager.get_provider().shutdown()
    except Exception as exc:
        logger.warning(f"Error during LLM provider shutdown: {exc}")

    if not runtime_lifecycle.has_active_database_work:
        await dispose_database_runtime()
    else:
        logger.error(
            "Active database work remains at lifespan exit; database engine NOT disposed "
            "to prevent corruption of active transactions."
        )


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    is_dev = settings.ENVIRONMENT == "development"
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        description="Local AI Runtime backend for AI Companion Project.",
        lifespan=lifespan,
        docs_url="/docs" if is_dev else None,
        redoc_url=None,
        openapi_url="/openapi.json" if is_dev else None,
    )

    # Admission control middleware for graceful shutdown
    app.add_middleware(RuntimeAdmissionASGIMiddleware)

    # Security: Request payload limit middleware (OWASP API4)
    app.add_middleware(PayloadLimitMiddleware)

    # Tracing and security middleware
    app.add_middleware(SecurityAndTracingMiddleware)

    # CORS Middleware (OWASP API7) - Explicit methods and headers, no wildcards
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS if isinstance(settings.CORS_ORIGINS, list) else [settings.CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-API-Key", "X-Request-ID", "X-Companion-Bootstrap"],
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

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException):
        request_id = getattr(request.state, "request_id", None)
        if getattr(request.state, "stream_bytes_exceeded", False):
            limit = getattr(request.state, "effective_max_bytes", settings.MAX_REQUEST_BODY_BYTES)
            return format_error_response(
                code="PAYLOAD_TOO_LARGE",
                message=f"Request payload exceeds maximum allowed size of {limit} bytes.",
                details=None,
                request_id=request_id,
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            )
        return format_error_response(
            code="AUTHENTICATION_REQUIRED" if exc.status_code == 401 else "HTTP_ERROR",
            message=str(exc.detail),
            details=None,
            request_id=request_id,
            status_code=exc.status_code,
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
