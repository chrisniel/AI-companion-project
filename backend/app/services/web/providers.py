"""Read-only Web Search, Webpage Fetch, and Weather providers routed through SSRF guard."""

from __future__ import annotations

from html import unescape
import json
import re
from typing import Any, Callable, Optional
from urllib.parse import parse_qs, quote_plus, unquote, urlparse
import httpx

from app.services.web.sanitizer import (
    sanitize_html_to_untrusted_text,
    wrap_untrusted_web_content,
)
from app.services.web.ssrf_guard import SSRFBlockedError, guarded_fetch_bytes

_WEATHER_CODE_DESCRIPTIONS = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Depositing rime fog",
    51: "Light drizzle",
    53: "Moderate drizzle",
    55: "Dense drizzle",
    61: "Slight rain",
    63: "Moderate rain",
    65: "Heavy rain",
    80: "Slight rain showers",
    81: "Moderate rain showers",
    82: "Violent rain showers",
    95: "Thunderstorm",
}


def _extract_domain(url: str) -> str:
    parsed = urlparse(url)
    return (parsed.hostname or "").lower()


def _unwrap_ddg_redirect(href: str) -> str:
    parsed = urlparse(href)
    if "duckduckgo.com" in (parsed.hostname or "") and parsed.path.startswith("/l/"):
        qs = parse_qs(parsed.query)
        if "uddg" in qs and qs["uddg"]:
            return unquote(qs["uddg"][0])
    if href.startswith("//"):
        return "https:" + href
    return href


def _parse_duckduckgo_html(html_text: str, max_results: int) -> list[dict[str, str]]:
    anchors = re.findall(
        r'<a[^>]*class=["\'][^"\']*result__a[^"\']*["\'][^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',
        html_text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    snippets = [
        m[1]
        for m in re.findall(
            r'<([a-z]+)[^>]*class=["\'][^"\']*result__snippet[^"\']*["\'][^>]*>(.*?)</\1>',
            html_text,
            flags=re.IGNORECASE | re.DOTALL,
        )
    ]
    results: list[dict[str, str]] = []
    for idx, (raw_href, raw_title) in enumerate(anchors[:max_results]):
        target_url = _unwrap_ddg_redirect(unescape(raw_href).strip())
        if not (target_url.startswith("http://") or target_url.startswith("https://")):
            continue
        clean_title = re.sub(r"<[^>]+>", "", unescape(raw_title)).strip()
        raw_snip = snippets[idx] if idx < len(snippets) else ""
        clean_snip = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", unescape(raw_snip))).strip()
        results.append(
            {
                "title": clean_title or _extract_domain(target_url),
                "url": target_url,
                "domain": _extract_domain(target_url),
                "snippet": clean_snip[:300],
            }
        )
    return results


async def weather_lookup(
    *,
    location: str,
    provider_name: str = "open_meteo",
    resolver: Optional[Callable[..., list]] = None,
    transport: Optional[httpx.AsyncBaseTransport] = None,
) -> dict[str, Any]:
    """Look up current weather via zero-key Open-Meteo API guarded by SSRF checks."""
    if provider_name == "disabled":
        raise RuntimeError("Weather provider is disabled by policy.")

    query = location.strip()
    if not query:
        raise ValueError("Location cannot be empty.")

    geo_url = f"https://geocoding-api.open-meteo.com/v1/search?name={quote_plus(query)}&count=1&language=en&format=json"
    geo_bytes, final_geo_url, _, geo_status = await guarded_fetch_bytes(
        geo_url,
        resolver=resolver,
        transport=transport,
    )
    if geo_status >= 400:
        raise RuntimeError(f"Weather geocoding failed with HTTP {geo_status}.")

    geo_data = json.loads(geo_bytes.decode("utf-8", errors="replace"))
    geo_results = geo_data.get("results") or []
    if not geo_results:
        fallback_query = re.sub(
            r"\bcity\b",
            "",
            query.split(",")[0],
            flags=re.IGNORECASE,
        ).strip()
        if fallback_query and fallback_query.lower() != query.lower():
            fb_url = f"https://geocoding-api.open-meteo.com/v1/search?name={quote_plus(fallback_query)}&count=1&language=en&format=json"
            fb_bytes, _, _, fb_status = await guarded_fetch_bytes(
                fb_url,
                resolver=resolver,
                transport=transport,
            )
            if fb_status < 400:
                fb_data = json.loads(fb_bytes.decode("utf-8", errors="replace"))
                geo_results = fb_data.get("results") or []
    if not geo_results:
        raise RuntimeError(f"No matching location found for '{query}'.")

    place = geo_results[0]
    lat = place["latitude"]
    lon = place["longitude"]
    display_loc = ", ".join(p for p in [place.get("name"), place.get("country")] if p)

    forecast_url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
        "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
        "&forecast_days=7&timezone=auto"
    )
    wx_bytes, final_wx_url, _, wx_status = await guarded_fetch_bytes(
        forecast_url,
        resolver=resolver,
        transport=transport,
    )
    if wx_status >= 400:
        raise RuntimeError(f"Weather forecast failed with HTTP {wx_status}.")

    wx_data = json.loads(wx_bytes.decode("utf-8", errors="replace"))
    current = wx_data.get("current") or {}
    code = current.get("weather_code")
    condition = _WEATHER_CODE_DESCRIPTIONS.get(code, "Current conditions")

    daily_raw = wx_data.get("daily") or {}
    daily_dates = daily_raw.get("time") or []
    daily_codes = daily_raw.get("weather_code") or []
    daily_max = daily_raw.get("temperature_2m_max") or []
    daily_min = daily_raw.get("temperature_2m_min") or []
    daily_pop = daily_raw.get("precipitation_probability_max") or []
    daily_forecast: list[dict[str, Any]] = []
    for idx, day_str in enumerate(daily_dates):
        d_code = daily_codes[idx] if idx < len(daily_codes) else None
        daily_forecast.append(
            {
                "date": day_str,
                "condition": _WEATHER_CODE_DESCRIPTIONS.get(d_code, "Forecast conditions"),
                "temp_max_c": daily_max[idx] if idx < len(daily_max) else None,
                "temp_min_c": daily_min[idx] if idx < len(daily_min) else None,
                "precipitation_prob_pct": daily_pop[idx] if idx < len(daily_pop) else None,
            }
        )

    loc_label = display_loc or query
    temp_val = current.get("temperature_2m")
    summary_parts = [f"Weather in {loc_label}: {condition}, {temp_val}°C now."]
    if daily_forecast:
        days_slice = daily_forecast[:7]
        preview = "; ".join(
            f"{d['date']}: {d['condition']} ({d['temp_min_c']}–{d['temp_max_c']}°C, rain {d['precipitation_prob_pct']}%)"
            for d in days_slice
        )
        summary_parts.append(f"{len(days_slice)}-day forecast: {preview}.")

    return {
        "location": loc_label,
        "temperature_c": temp_val,
        "humidity_pct": current.get("relative_humidity_2m"),
        "wind_speed_kmh": current.get("wind_speed_10m"),
        "condition": condition,
        "daily_forecast": daily_forecast,
        "summary": " ".join(summary_parts),
        "sources": [
            {
                "title": f"Open-Meteo Forecast ({loc_label})",
                "url": final_wx_url,
                "domain": _extract_domain(final_wx_url),
            }
        ],
    }


async def search_web(
    *,
    query: str,
    max_results: int = 5,
    provider_name: str = "public_search",
    searxng_base_url: Optional[str] = None,
    api_key: Optional[str] = None,
    resolver: Optional[Callable[..., list]] = None,
    transport: Optional[httpx.AsyncBaseTransport] = None,
) -> dict[str, Any]:
    """Execute read-only public web search returning bounded sanitized snippets and sources."""
    if provider_name == "disabled":
        raise RuntimeError("Web search provider is disabled by policy.")

    cleaned = query.strip()
    if not cleaned:
        raise ValueError("Search query cannot be empty.")
    bounded_max = max(1, min(int(max_results), 8))

    results: list[dict[str, str]] = []
    if provider_name == "searxng":
        if not searxng_base_url:
            raise RuntimeError("SearXNG base URL is not configured.")
        base = searxng_base_url.rstrip("/")
        raw_bytes, _, _, status_code = await guarded_fetch_bytes(
            f"{base}/search?q={quote_plus(cleaned)}&format=json",
            resolver=resolver,
            transport=transport,
            allow_configured_local_origin=base,
        )
        if status_code >= 400:
            raise RuntimeError(f"SearXNG failed with HTTP {status_code}.")
        payload = json.loads(raw_bytes.decode("utf-8", errors="replace"))
        for item in (payload.get("results") or [])[:bounded_max]:
            url = item.get("url", "")
            if url.startswith("http://") or url.startswith("https://"):
                results.append(
                    {
                        "title": str(item.get("title") or _extract_domain(url))[:160],
                        "url": url,
                        "domain": _extract_domain(url),
                        "snippet": str(item.get("content") or "")[:300],
                    }
                )
    elif provider_name == "tavily":
        if not api_key:
            raise RuntimeError("Tavily API key is not configured on host.")
        raw_bytes, _, _, status_code = await guarded_fetch_bytes(
            "https://api.tavily.com/search",
            method="POST",
            json_body={
                "api_key": api_key,
                "query": cleaned,
                "max_results": bounded_max,
                "include_raw_content": False,
            },
            resolver=resolver,
            transport=transport,
        )
        if status_code >= 400:
            raise RuntimeError(f"Tavily failed with HTTP {status_code}.")
        payload = json.loads(raw_bytes.decode("utf-8", errors="replace"))
        for item in (payload.get("results") or [])[:bounded_max]:
            url = item.get("url", "")
            if url.startswith("http://") or url.startswith("https://"):
                results.append(
                    {
                        "title": str(item.get("title") or _extract_domain(url))[:160],
                        "url": url,
                        "domain": _extract_domain(url),
                        "snippet": str(item.get("content") or "")[:300],
                    }
                )
    elif provider_name == "brave":
        if not api_key:
            raise RuntimeError("Brave Search API key is not configured on host.")
        raw_bytes, _, _, status_code = await guarded_fetch_bytes(
            f"https://api.search.brave.com/res/v1/web/search?q={quote_plus(cleaned)}&count={bounded_max}",
            headers={"X-Subscription-Token": api_key, "Accept": "application/json"},
            resolver=resolver,
            transport=transport,
        )
        if status_code >= 400:
            raise RuntimeError(f"Brave Search failed with HTTP {status_code}.")
        payload = json.loads(raw_bytes.decode("utf-8", errors="replace"))
        for item in (payload.get("web", {}).get("results") or [])[:bounded_max]:
            url = item.get("url", "")
            if url.startswith("http://") or url.startswith("https://"):
                results.append(
                    {
                        "title": str(item.get("title") or _extract_domain(url))[:160],
                        "url": url,
                        "domain": _extract_domain(url),
                        "snippet": str(item.get("description") or "")[:300],
                    }
                )
    else:
        raw_bytes, _, _, status_code = await guarded_fetch_bytes(
            f"https://html.duckduckgo.com/html/?q={quote_plus(cleaned)}",
            resolver=resolver,
            transport=transport,
        )
        if status_code >= 400:
            raise RuntimeError(f"Public search failed with HTTP {status_code}.")
        html_text = raw_bytes.decode("utf-8", errors="replace")
        results = _parse_duckduckgo_html(html_text, bounded_max)

    sources = [
        {
            "title": r["title"],
            "url": r["url"],
            "domain": r["domain"],
            "snippet": r["snippet"],
        }
        for r in results
    ]
    lines = [f"- [{r['title']}]({r['url']}) — {r['snippet']}" for r in results]
    wrapped = wrap_untrusted_web_content(
        url=f"search://{provider_name}",
        domain="web-search",
        content="\n".join(lines) if lines else "No matching public search results.",
    )
    return {"provider": provider_name, "results": results, "sources": sources, "content": wrapped}


async def fetch_web_page(
    *,
    url: str,
    resolver: Optional[Callable[..., list]] = None,
    transport: Optional[httpx.AsyncBaseTransport] = None,
) -> dict[str, Any]:
    """Fetch a single public webpage through strict SSRF checks and sanitize HTML into bounded text."""
    raw_bytes, final_url, content_type, status_code = await guarded_fetch_bytes(
        url,
        resolver=resolver,
        transport=transport,
    )
    if status_code >= 400:
        raise RuntimeError(f"Page fetch failed with HTTP {status_code}.")

    decoded = raw_bytes.decode("utf-8", errors="replace")
    lower_ct = content_type.lower()
    if "html" in lower_ct or "<html" in decoded[:512].lower():
        title, clean_text = sanitize_html_to_untrusted_text(decoded)
    elif "json" in lower_ct or "text/" in lower_ct or lower_ct == "":
        title = ""
        clean_text = decoded[:6000]
    else:
        raise SSRFBlockedError(f"Unsupported binary or non-text Content-Type '{content_type}'.")

    domain = _extract_domain(final_url)
    wrapped = wrap_untrusted_web_content(url=final_url, domain=domain, content=clean_text)
    return {
        "title": title or domain,
        "url": final_url,
        "domain": domain,
        "content": wrapped,
        "sources": [{"title": title or domain, "url": final_url, "domain": domain}],
    }
