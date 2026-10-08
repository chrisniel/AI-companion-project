"""Automated verification suite for Security Hardening V1.1 controls."""

import os
from pathlib import Path
import subprocess
import sys
import textwrap

import pytest
from httpx import AsyncClient

from app.core.config import Settings, settings
from app.core.logging import sanitize_message
from app.main import create_app


@pytest.mark.asyncio
async def test_payload_size_limit_rejects_oversized_body(client: AsyncClient, auth_headers: dict):
    """OWASP API4: Requests with body exceeding MAX_REQUEST_BODY_BYTES must be rejected with 413."""
    # Create an oversized payload exceeding 2 MB limit
    oversized_content = "x" * (settings.MAX_REQUEST_BODY_BYTES + 1024)
    headers = {
        **auth_headers,
        "Content-Length": str(len(oversized_content)),
        "Content-Type": "application/json",
    }

    response = await client.post(
        "/api/v1/tasks",
        content=oversized_content,
        headers=headers,
    )
    assert response.status_code == 413
    data = response.json()
    assert "error" in data
    assert data["error"]["code"] == "PAYLOAD_TOO_LARGE"
    assert "exceeds maximum allowed size" in data["error"]["message"]


@pytest.mark.asyncio
async def test_default_deny_blocks_unauthenticated_tasks_access(client: AsyncClient):
    """Security Hardening: Router boundary enforces default-deny authentication on /tasks."""
    response = await client.get("/api/v1/tasks")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTHENTICATION_REQUIRED"


@pytest.mark.asyncio
async def test_public_health_probe_remains_accessible_without_auth(client: AsyncClient):
    """Public health probe must remain reachable for LAN discovery while other routes are default-deny."""
    response = await client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


@pytest.mark.asyncio
async def test_cors_preflight_allows_configured_methods_and_headers(client: AsyncClient):
    """OWASP API7: CORS preflight must allow only explicit methods and headers, no wildcards."""
    headers = {
        "Origin": "http://localhost:5173",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "Authorization,Content-Type",
    }
    response = await client.options("/api/v1/tasks", headers=headers)
    assert response.status_code == 200
    allow_methods = response.headers.get("access-control-allow-methods", "")
    assert "POST" in allow_methods
    assert "GET" in allow_methods
    assert "PATCH" in allow_methods
    assert "DELETE" in allow_methods


@pytest.mark.asyncio
async def test_secret_sanitizer_redacts_tokens_from_log_messages():
    """Rule 12 & Sec 11.1: Log sanitizer must redact pairing tokens and Bearer strings."""
    test_secret = "companion_sec_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
    test_msg = f"Connecting to runtime with token {test_secret} for session"
    sanitized = sanitize_message(test_msg)

    assert test_secret not in sanitized
    assert "***REDACTED_TOKEN***" in sanitized


def test_docs_disabled_outside_development_environment(monkeypatch):
    """Sec 11.6: Swagger UI and OpenAPI schemas must be disabled when ENVIRONMENT is not development."""
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    prod_app = create_app()

    assert prod_app.docs_url is None
    assert prod_app.redoc_url is None
    assert prod_app.openapi_url is None


@pytest.mark.asyncio
async def test_streaming_payload_exceeding_limit_rejected_413(client: AsyncClient, auth_headers: dict):
    """OWASP API4: Streaming chunks exceeding MAX_REQUEST_BODY_BYTES must be aborted with 413 even without Content-Length."""
    chunk_size = 512 * 1024  # 512 KB
    total_chunks = (settings.MAX_REQUEST_BODY_BYTES // chunk_size) + 2

    async def streaming_generator():
        for _ in range(total_chunks):
            yield b"0" * chunk_size

    headers = {
        **auth_headers,
        "Content-Type": "application/octet-stream",
    }
    response = await client.post(
        "/api/v1/tasks",
        content=streaming_generator(),
        headers=headers,
    )
    assert response.status_code == 413
    assert response.json()["error"]["code"] == "PAYLOAD_TOO_LARGE"


def test_cors_configuration_rejects_wildcards_and_schemeless_origins():
    """Item 4 / CORS: Setting wildcard '*' or schemeless origins must raise a fatal configuration error."""
    from pydantic import ValidationError

    # Wildcard rejection
    with pytest.raises(ValidationError) as exc1:
        Settings(CORS_ORIGINS="*", COMPANION_API_KEY="companion_sec_testtoken123456789012")
    assert "strictly forbidden" in str(exc1.value)

    # Schemeless origin rejection
    with pytest.raises(ValidationError) as exc2:
        Settings(CORS_ORIGINS="localhost:3000", COMPANION_API_KEY="companion_sec_testtoken123456789012")
    assert "Explicit scheme" in str(exc2.value)


@pytest.mark.asyncio
async def test_request_id_sanitizer_discards_malicious_header(client: AsyncClient):
    """Item 5: Malicious or oversized X-Request-ID headers must be discarded and replaced with safe req_<hex>."""
    # Malicious injection header
    response = await client.get("/api/v1/health", headers={"X-Request-ID": "../../attack\r\nInjected: True"})
    req_id = response.headers.get("X-Request-ID", "")
    assert req_id.startswith("req_")
    assert "attack" not in req_id

    # Valid header is preserved
    response_valid = await client.get("/api/v1/health", headers={"X-Request-ID": "safe-trace_id-123"})
    assert response_valid.headers.get("X-Request-ID") == "safe-trace_id-123"


def test_router_architecture_is_fail_closed():
    """Item 2: Verify public_router contains only /health and protected_router enforces verify_token."""
    from app.api.v1.router import public_router, protected_router
    from app.api.deps import verify_token

    def extract_paths(router):
        paths = []
        for route in router.routes:
            if hasattr(route, "path"):
                paths.append(route.path)
            elif hasattr(route, "original_router"):
                for sub_route in route.original_router.routes:
                    if hasattr(sub_route, "path"):
                        paths.append(sub_route.path)
        return paths

    # Public router must only contain /health
    public_paths = extract_paths(public_router)
    assert public_paths == ["/health"]

    # Protected router must have verify_token dependency
    assert any(dep.dependency == verify_token for dep in protected_router.dependencies)


def _run_disposable_startup_boundary(tmp_path: Path, body: str) -> None:
    """Exercise actual startup modules in a child isolated from auth/data/log state."""
    backend = Path(__file__).resolve().parents[1]
    configuration = tmp_path / "selected-configuration.env"
    configuration.write_text("DEBUG=false\n", encoding="utf-8")
    temporary = tmp_path / "tmp"
    temporary.mkdir()
    environment = {
        name: os.environ[name]
        for name in ("SystemRoot", "WINDIR", "PATH", "PATHEXT", "COMSPEC")
        if name in os.environ
    }
    environment.update({
        "COMPANION_ENV_FILE": str(configuration),
        "COMPANION_DATA_ROOT": str(tmp_path / "data"),
        "LOCALAPPDATA": str(tmp_path / "localappdata"),
        "BASE_DIR": str(tmp_path / "workspace" / "backend"),
        "LLM_PROVIDER": "mock",
        "TMP": str(temporary),
        "TEMP": str(temporary),
        "TMPDIR": str(temporary),
    })
    guard = textwrap.dedent(f"""
        import os
        from pathlib import Path
        import platform
        import socket
        import sys

        sandbox = Path({str(tmp_path)!r}).resolve()
        backend = Path({str(backend)!r}).resolve()
        configuration = Path({str(configuration)!r}).resolve()

        # Cache CPython 3.11's read-only Windows version query before the guard.
        # Application startup retains the full subprocess/auth/data restrictions.
        platform.uname()

        class ForbiddenLocalState(BaseException):
            pass

        def disposable(path):
            return path == sandbox or sandbox in path.parents

        def guard_local_state(event, arguments):
            # Windows asyncio uses a stdlib loopback socketpair for its internal
            # wake-up pipe. Permit that precise boundary, never inference/network.
            if event == "socket.connect":
                caller = sys._getframe(1).f_code
                address = arguments[1]
                if (caller.co_name in ("socketpair", "_fallback_socketpair")
                        and caller.co_filename == socket.__file__
                        and address[0] in ("127.0.0.1", "::1")):
                    return
                raise ForbiddenLocalState("External activity during synthetic startup")
            if event == "subprocess.Popen":
                raise ForbiddenLocalState("External activity during synthetic startup")
            if event == "sqlite3.connect":
                target = arguments[0]
                if target != ":memory:" and not disposable(Path(target).resolve()):
                    raise ForbiddenLocalState("Non-disposable database access")
            if event != "open" or not isinstance(arguments[0], (str, bytes, os.PathLike)):
                return
            target = Path(os.fsdecode(arguments[0])).resolve()
            mode, flags = arguments[1:3]
            writing = bool(flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND))
            authentication = target.name == ".env" or target.name.startswith(".env.")
            database = target.suffix.lower() in (".db", ".sqlite", ".sqlite3")
            if not disposable(target) and (writing or authentication or database):
                raise ForbiddenLocalState("Non-disposable authentication/data/file access")

        sys.addaudithook(guard_local_state)
        sys.path.insert(0, str(backend))
    """)
    result = subprocess.run(
        [sys.executable, "-I", "-B", "-c", guard + "\n" + textwrap.dedent(body)],
        cwd=tmp_path,
        env=environment,
        capture_output=True,
        text=True,
        timeout=90,
    )
    # Child assertions avoid printing generated credentials; redact captured output
    # as a second boundary if a migration/startup failure includes a log message.
    assert result.returncode == 0, sanitize_message(result.stdout[-3000:] + result.stderr[-5000:])


def test_startup_guard_rejects_application_network_and_subprocess(tmp_path):
    _run_disposable_startup_boundary(tmp_path, """
        import subprocess
        with socket.socket() as probe:
            try:
                probe.connect(("127.0.0.1", 9))
            except ForbiddenLocalState:
                pass
            else:
                raise AssertionError("Startup guard permitted application network access")
        try:
            subprocess.run([sys.executable, "-c", "pass"], check=True)
        except ForbiddenLocalState:
            pass
        else:
            raise AssertionError("Startup guard permitted application subprocess execution")
    """)


def test_programmatic_schema_preparation_preserves_logging_ownership(tmp_path):
    _run_disposable_startup_boundary(tmp_path, """
        import io
        import logging
        from app.core.logging import SanitizingFormatter, logger, setup_logging
        from app.core.storage import prepare_database_schema

        sink = io.StringIO()
        sys.stdout = sink
        setup_logging()
        root = logging.getLogger()
        handler = root.handlers[0]
        assert isinstance(handler.formatter, SanitizingFormatter)
        logger.disabled = False
        synthetic_secret = "companion_sec_logging_boundary_1234567890123456"
        synthetic_bearer = "Bearer synthetic_startup_auth_1234567890123456"
        database = sandbox / "schema" / "companion.db"
        revision = prepare_database_schema(database)
        assert revision
        for iteration in range(2):
            assert not logger.disabled, "Schema preparation disabled the application logger"
            assert root.handlers == [handler], "Schema preparation replaced application handlers"
            assert isinstance(handler.formatter, SanitizingFormatter), "Sanitizing formatter lost"
            logger.info("synthetic %s %s", synthetic_secret, synthetic_bearer)
            try:
                raise RuntimeError(synthetic_secret)
            except RuntimeError:
                logger.exception("Synthetic startup exception")
            rendered = sink.getvalue()
            assert synthetic_secret not in rendered and synthetic_bearer not in rendered
            assert "***REDACTED_TOKEN***" in rendered, "Application redaction stopped working"
            assert prepare_database_schema(database) == revision
    """)


def test_standalone_alembic_cli_retains_its_logging_configuration(tmp_path):
    _run_disposable_startup_boundary(tmp_path, """
        import io
        import logging
        import runpy
        from app.core.logging import SanitizingFormatter, logger, setup_logging

        source_ini = (backend / "alembic.ini").read_text(encoding="utf-8")
        migrations = (backend / "migrations").resolve().as_posix()
        database = (sandbox / "cli.db").resolve().as_posix()
        selected_ini = sandbox / "standalone-alembic.ini"
        selected_ini.write_text(
            source_ini.replace("script_location = migrations", "script_location = " + migrations)
            .replace("sqlite+aiosqlite:///./data/companion.db", "sqlite+aiosqlite:///" + database),
            encoding="utf-8",
        )
        sys.stdout = io.StringIO()
        setup_logging()
        assert isinstance(logging.getLogger().handlers[0].formatter, SanitizingFormatter)
        sys.argv = ["alembic", "-c", str(selected_ini), "upgrade", "head"]
        try:
            runpy.run_module("alembic", run_name="__main__")
        except SystemExit as exc:
            assert exc.code in (None, 0), "Standalone Alembic failed"
        handlers = logging.getLogger().handlers
        assert len(handlers) == 1
        assert not isinstance(handlers[0].formatter, SanitizingFormatter), "CLI logging was suppressed"
        assert handlers[0].formatter._fmt == "%(levelname)-5.5s [%(name)s] %(message)s"
        assert Path(database).exists()
    """)


def test_disposable_lifespan_initializes_selected_credential_and_preserves_logging(tmp_path):
    _run_disposable_startup_boundary(tmp_path, """
        import asyncio
        import io
        import logging
        from app.core.config import Settings, settings
        from app.core.logging import SanitizingFormatter, logger
        from app.db import session as database_runtime
        from app.main import create_app

        original_configuration = configuration.read_text(encoding="utf-8")
        assert settings.COMPANION_API_KEY == "", "Import generated a credential"
        assert configuration.read_text(encoding="utf-8") == original_configuration
        assert database_runtime._engine is None
        sink = io.StringIO()
        sys.stdout = sink
        application = create_app()

        async def exercise_startup():
            async with application.router.lifespan_context(application):
                assert settings.COMPANION_API_KEY, "Explicit startup did not initialize a credential"
                assert Settings().COMPANION_API_KEY == settings.COMPANION_API_KEY
                assert database_runtime.get_engine() is not None
                assert settings.DATABASE_PATH.exists()
                assert not logger.disabled, "Startup disabled the application logger"
                assert isinstance(logging.getLogger().handlers[0].formatter, SanitizingFormatter)
                logger.info("Synthetic startup secret %s", settings.COMPANION_API_KEY)
                assert settings.COMPANION_API_KEY not in sink.getvalue()
            assert database_runtime._engine is None, "Shutdown did not dispose the database"

        asyncio.run(exercise_startup())
        persisted = configuration.read_text(encoding="utf-8")
        credential = settings.COMPANION_API_KEY
        asyncio.run(exercise_startup())
        assert settings.COMPANION_API_KEY == credential, "Repeated startup replaced credential"
        assert configuration.read_text(encoding="utf-8") == persisted
        output = sink.getvalue()
        assert "Pairing credential initialized using selected local configuration." in output
        assert "Credential stored in backend/.env" not in output
        assert str(configuration) not in output, "Startup disclosed selected credential path"
        assert credential not in output, "Startup disclosed credential"
    """)
