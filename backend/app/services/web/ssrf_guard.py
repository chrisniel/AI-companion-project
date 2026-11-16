"""Fail-closed SSRF guard with DNS resolution pinning, redirect revalidation, and size limits."""

from __future__ import annotations

from dataclasses import dataclass
import ipaddress
import socket
from typing import Any, Callable, Mapping, Optional
from urllib.parse import urljoin, urlsplit, urlunsplit

import httpx

MAX_RESPONSE_BYTES = 2 * 1024 * 1024  # 2 MiB ceiling per spec
DEFAULT_TIMEOUT_SECONDS = 10.0
MAX_REDIRECT_HOPS = 5

_CGNAT_NETWORK = ipaddress.IPv4Network("100.64.0.0/10")
_ULA_NETWORK = ipaddress.IPv6Network("fc00::/7")
_LINK_LOCAL_V6 = ipaddress.IPv6Network("fe80::/10")


class SSRFBlockedError(ValueError):
    """Raised when an outbound URL or redirect violates SSRF containment rules."""


@dataclass(frozen=True)
class ValidatedOutboundTarget:
    """Validated HTTP/HTTPS target pinned to an inspected IP address."""

    url: str
    scheme: str
    hostname: str
    port: int
    pinned_ip: str
    path_and_query: str


def _unwrap_ip(raw_ip: str) -> ipaddress.IPv4Address | ipaddress.IPv6Address:
    """Parse an IP string (stripping zone suffix) and unwrap IPv4-mapped IPv6 addresses."""
    cleaned = raw_ip.split("%", 1)[0].strip()
    addr = ipaddress.ip_address(cleaned)
    if isinstance(addr, ipaddress.IPv6Address) and addr.ipv4_mapped is not None:
        return addr.ipv4_mapped
    return addr


def _is_forbidden_ip(
    addr: ipaddress.IPv4Address | ipaddress.IPv6Address,
    *,
    allow_configured_local: bool = False,
) -> bool:
    """Return True if an IP address belongs to a blocked range."""
    # Always forbidden even for SearXNG exception: metadata, link-local, multicast, reserved, unspecified.
    if str(addr) == "169.254.169.254":
        return True
    if addr.is_link_local or addr.is_multicast or addr.is_reserved or addr.is_unspecified:
        return True
    if isinstance(addr, ipaddress.IPv6Address) and addr in _LINK_LOCAL_V6:
        return True

    if allow_configured_local:
        return False

    if addr.is_loopback or addr.is_private or not addr.is_global:
        return True
    if isinstance(addr, ipaddress.IPv4Address) and addr in _CGNAT_NETWORK:
        return True
    if isinstance(addr, ipaddress.IPv6Address) and addr in _ULA_NETWORK:
        return True
    return False


def _origin_tuple(url: str) -> tuple[str, str, int]:
    parts = urlsplit(url.strip())
    scheme = parts.scheme.lower()
    host = (parts.hostname or "").lower()
    port = parts.port or (443 if scheme == "https" else 80)
    return scheme, host, port


def validate_outbound_url(
    url: str,
    *,
    resolver: Optional[Callable[..., list]] = None,
    allow_configured_local_origin: Optional[str] = None,
) -> ValidatedOutboundTarget:
    """Validate URL scheme, credentials, port, and resolved IPs before outbound connection."""
    if not isinstance(url, str) or not url.strip():
        raise SSRFBlockedError("Outbound URL is empty.")

    parts = urlsplit(url.strip())
    scheme = parts.scheme.lower()
    if scheme not in ("http", "https"):
        raise SSRFBlockedError(f"Unsupported URL scheme '{parts.scheme}'.")
    if parts.username is not None or parts.password is not None:
        raise SSRFBlockedError("Embedded URL credentials are forbidden.")
    if not parts.hostname:
        raise SSRFBlockedError("URL hostname is missing.")

    hostname = parts.hostname.strip().lower()
    if hostname in ("localhost", "localhost.localdomain") or hostname.endswith(".localhost"):
        if not allow_configured_local_origin:
            raise SSRFBlockedError("Loopback hostname access is blocked.")

    try:
        port = parts.port or (443 if scheme == "https" else 80)
    except ValueError:
        raise SSRFBlockedError("Malformed URL port.") from None

    is_searxng_match = False
    if allow_configured_local_origin:
        origin_parts = urlsplit(allow_configured_local_origin.strip())
        if not origin_parts.scheme or not origin_parts.hostname or origin_parts.username or origin_parts.password:
            raise SSRFBlockedError("Configured local search origin is invalid.")
        is_searxng_match = _origin_tuple(url) == _origin_tuple(allow_configured_local_origin)
        if not is_searxng_match:
            raise SSRFBlockedError("Request origin does not match configured search origin.")
    elif port not in (80, 443):
        raise SSRFBlockedError(f"Port {port} is blocked for generic public fetch.")

    resolve_fn = resolver or socket.getaddrinfo
    try:
        infos = resolve_fn(hostname, port, type=socket.SOCK_STREAM)
    except OSError as exc:
        raise SSRFBlockedError(f"DNS resolution failed for '{hostname}': {exc}") from exc

    if not infos:
        raise SSRFBlockedError(f"DNS returned no addresses for '{hostname}'.")

    chosen_ip: Optional[str] = None
    for info in infos:
        sockaddr = info[4]
        raw_ip = sockaddr[0]
        try:
            addr = _unwrap_ip(raw_ip)
        except ValueError as exc:
            raise SSRFBlockedError(f"Invalid resolved IP address: {exc}") from exc
        if _is_forbidden_ip(addr, allow_configured_local=is_searxng_match):
            raise SSRFBlockedError(f"Blocked non-public or restricted IP address: {addr}")
        if chosen_ip is None:
            chosen_ip = str(addr)

    assert chosen_ip is not None
    path = parts.path or "/"
    path_and_query = f"{path}?{parts.query}" if parts.query else path
    canonical_url = urlunsplit((scheme, parts.netloc, path, parts.query, ""))
    return ValidatedOutboundTarget(
        url=canonical_url,
        scheme=scheme,
        hostname=hostname,
        port=port,
        pinned_ip=chosen_ip,
        path_and_query=path_and_query,
    )


def _build_pinned_request_url(target: ValidatedOutboundTarget) -> tuple[str, dict[str, str], dict[str, Any]]:
    ip_host = f"[{target.pinned_ip}]" if ":" in target.pinned_ip else target.pinned_ip
    default_port = 443 if target.scheme == "https" else 80
    netloc = ip_host if target.port == default_port else f"{ip_host}:{target.port}"
    host_header = target.hostname if target.port == default_port else f"{target.hostname}:{target.port}"
    pinned_url = f"{target.scheme}://{netloc}{target.path_and_query}"
    headers = {
        "Host": host_header,
        "User-Agent": "AICompanion-LocalRuntime/0.1 (ReadOnly-SSRF-Safe)",
        "Accept": "text/html,application/json,application/xhtml+xml;q=0.9,*/*;q=0.8",
    }
    extensions: dict[str, Any] = {}
    if target.scheme == "https":
        extensions["sni_hostname"] = target.hostname
    return pinned_url, headers, extensions


async def guarded_fetch_bytes(
    url: str,
    *,
    method: str = "GET",
    headers: Optional[Mapping[str, str]] = None,
    params: Optional[Mapping[str, Any]] = None,
    json_body: Optional[Any] = None,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
    max_bytes: int = MAX_RESPONSE_BYTES,
    resolver: Optional[Callable[..., list]] = None,
    transport: Optional[httpx.AsyncBaseTransport] = None,
    allow_configured_local_origin: Optional[str] = None,
) -> tuple[bytes, str, str, int]:
    """Fetch a public HTTP/HTTPS resource with DNS pinning, hop-by-hop redirect validation, and byte ceiling.

    Returns ``(body_bytes, final_url, content_type, status_code)``.
    """
    current_url = url
    max_hops = 0 if allow_configured_local_origin else MAX_REDIRECT_HOPS
    client_kwargs: dict[str, Any] = {
        "timeout": httpx.Timeout(timeout_seconds),
        "follow_redirects": False,
        "trust_env": False,
    }
    if transport is not None:
        client_kwargs["transport"] = transport

    async with httpx.AsyncClient(**client_kwargs) as client:
        for hop in range(max_hops + 1):
            target = validate_outbound_url(
                current_url,
                resolver=resolver,
                allow_configured_local_origin=allow_configured_local_origin,
            )
            pinned_url, base_headers, extensions = _build_pinned_request_url(target)
            merged_headers = dict(base_headers)
            if headers:
                for k, v in headers.items():
                    if k.lower() != "host":
                        merged_headers[k] = v

            async with client.stream(
                method,
                pinned_url,
                headers=merged_headers,
                params=params if hop == 0 else None,
                json=json_body if hop == 0 else None,
                extensions=extensions,
            ) as response:
                if response.status_code in (301, 302, 303, 307, 308):
                    if allow_configured_local_origin:
                        raise SSRFBlockedError("Redirects are blocked for configured local search origin.")
                    location = response.headers.get("location")
                    if not location or hop >= max_hops:
                        raise SSRFBlockedError("Redirect limit exceeded or Location header missing.")
                    current_url = urljoin(target.url, location)
                    continue

                content_len_hdr = response.headers.get("content-length")
                if content_len_hdr:
                    try:
                        if int(content_len_hdr) > max_bytes:
                            raise SSRFBlockedError(f"Response Content-Length exceeds {max_bytes} byte ceiling.")
                    except ValueError:
                        pass

                buf = bytearray()
                async for chunk in response.aiter_bytes():
                    buf.extend(chunk)
                    if len(buf) > max_bytes:
                        raise SSRFBlockedError(f"Response stream exceeded {max_bytes} byte ceiling.")

                content_type = response.headers.get("content-type", "")
                return bytes(buf), target.url, content_type, response.status_code

    raise SSRFBlockedError("Exceeded maximum redirect hops.")
