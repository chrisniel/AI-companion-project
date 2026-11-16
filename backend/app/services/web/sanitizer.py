"""Standard-library HTML sanitization and untrusted web content delimiters."""

from __future__ import annotations

from html.parser import HTMLParser
import re
from typing import Tuple

MAX_EXTRACTED_CHARS = 6000
_SKIP_TAGS = frozenset({"script", "style", "form", "iframe", "noscript", "object", "embed", "svg", "template"})
_BLOCK_BREAK_TAGS = frozenset({"p", "div", "li", "h1", "h2", "h3", "h4", "h5", "h6", "tr", "br", "blockquote", "section", "article"})


class _CleanTextHTMLParser(HTMLParser):
    """Strip executable/active HTML elements and extract clean readable text."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._skip_depth = 0
        self._in_title = False
        self.title_parts: list[str] = []
        self.text_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        t = tag.lower()
        if t in _SKIP_TAGS:
            self._skip_depth += 1
            return
        if self._skip_depth > 0:
            return
        if t == "title":
            self._in_title = True
        elif t in _BLOCK_BREAK_TAGS:
            self.text_parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        t = tag.lower()
        if t in _SKIP_TAGS:
            if self._skip_depth > 0:
                self._skip_depth -= 1
            return
        if self._skip_depth > 0:
            return
        if t == "title":
            self._in_title = False
        elif t in _BLOCK_BREAK_TAGS:
            self.text_parts.append("\n")

    def handle_data(self, data: str) -> None:
        if self._skip_depth > 0:
            return
        if self._in_title:
            self.title_parts.append(data)
            return
        self.text_parts.append(data)


def sanitize_html_to_untrusted_text(
    raw_html: str,
    *,
    max_chars: int = MAX_EXTRACTED_CHARS,
) -> Tuple[str, str]:
    """Strip unsafe HTML tags and collapse whitespace into bounded plain text.

    Returns ``(title, clean_text)``.
    """
    parser = _CleanTextHTMLParser()
    parser.feed(raw_html or "")
    parser.close()

    title = re.sub(r"\s+", " ", "".join(parser.title_parts)).strip()[:200]
    raw_text = "".join(parser.text_parts)
    lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in raw_text.splitlines()]
    compact = "\n".join(ln for ln in lines if ln)
    if len(compact) > max_chars:
        compact = compact[: max_chars - 3].rstrip() + "..."
    return title, compact


def _escape_attr(val: str) -> str:
    return (
        val.replace("&", "&amp;")
        .replace('"', "&quot;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def wrap_untrusted_web_content(*, url: str, domain: str, content: str) -> str:
    """Wrap sanitized web content in explicit untrusted delimiters stripping nested closing tags."""
    safe_body = content.replace("</untrusted_web_content>", "[/untrusted_web_content]")
    safe_body = safe_body.replace("<untrusted_web_content", "[untrusted_web_content")
    return (
        f'<untrusted_web_content url="{_escape_attr(url)}" domain="{_escape_attr(domain)}">\n'
        f"{safe_body}\n"
        "</untrusted_web_content>"
    )
