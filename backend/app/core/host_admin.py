"""Independent native Desktop authority. Pairing and Profile tokens never elevate."""

import ipaddress
import os
from pathlib import Path
import secrets

from fastapi import Header, HTTPException, Request

from app.core.errors import CompanionSecurityError
from app.core.windows_security import reject_reparse_path, secure_private_path, validate_private_path


def host_admin_secret_path() -> Path:
    root = os.environ.get("LOCALAPPDATA")
    if not root:
        raise RuntimeError("LOCALAPPDATA is required for the Host Admin credential")
    return Path(root) / "AICompanion" / "secrets" / "desktop_admin.secret"


def read_host_admin_secret() -> str:
    path = host_admin_secret_path()
    validate_private_path(path.parent)
    validate_private_path(path)
    value = path.read_text(encoding="utf-8").strip()
    if len(value) < 40 or len(value) > 256 or not value.isascii():
        raise RuntimeError("Invalid Host Admin credential store")
    return value


def initialize_host_admin_secret() -> str:
    path = host_admin_secret_path()
    reject_reparse_path(path)
    reject_reparse_path(path.parent)
    if path.exists():
        return read_host_admin_secret()
    if path.parent.exists():
        validate_private_path(path.parent)
    else:
        path.parent.mkdir(parents=True, exist_ok=False)
        secure_private_path(path.parent)
    value = "hsk_" + secrets.token_urlsafe(48)
    # Secure parent before exclusive creation; fail closed if another process won creation.
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        return read_host_admin_secret()
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        stream.write(value)
    secure_private_path(path)
    return read_host_admin_secret()


def require_loopback(request: Request) -> None:
    try:
        if request.client is None or not ipaddress.ip_address(request.client.host).is_loopback:
            raise ValueError
    except ValueError:
        raise HTTPException(403, "Local host transport required") from None
    # Reject DNS-rebinding Host names even when the peer happens to be loopback.
    if request.url.hostname not in {"127.0.0.1", "localhost", "::1"}:
        raise HTTPException(403, "Local host address required")


async def require_host_admin(request: Request, x_host_admin_secret: str | None = Header(None)) -> str:
    require_loopback(request)
    if "origin" in request.headers or request.headers.get("sec-fetch-site") is not None:
        raise HTTPException(403, "Host Admin is available only to the native Desktop")
    if not x_host_admin_secret or not x_host_admin_secret.isascii():
        raise CompanionSecurityError(message="Independent Host Admin credentials required")
    try:
        expected = read_host_admin_secret()
    except (RuntimeError, OSError):
        raise HTTPException(503, "Host Admin credential store unavailable") from None
    if not secrets.compare_digest(x_host_admin_secret, expected):
        raise CompanionSecurityError(message="Invalid Host Admin credentials")
    return x_host_admin_secret
