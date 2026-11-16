"""Read-only web information retrieval with strict SSRF containment and untrusted sanitization."""

from app.services.web.providers import fetch_web_page, search_web, weather_lookup
from app.services.web.sanitizer import sanitize_html_to_untrusted_text, wrap_untrusted_web_content
from app.services.web.ssrf_guard import SSRFBlockedError, ValidatedOutboundTarget, guarded_fetch_bytes, validate_outbound_url

__all__ = [
    "SSRFBlockedError",
    "ValidatedOutboundTarget",
    "fetch_web_page",
    "guarded_fetch_bytes",
    "sanitize_html_to_untrusted_text",
    "search_web",
    "validate_outbound_url",
    "weather_lookup",
    "wrap_untrusted_web_content",
]
