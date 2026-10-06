# Web and Current Information Integration Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0010)
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for read-only web information, search, fetch, and weather integrations.

---

## 1. Purpose & Scope

This specification defines the integration architecture, security constraints, provider abstractions, and data handling policies for external public information:
- Provider-independent read-only Web Search, page Fetch, and Weather context.
- SSRF prevention, IP filtering, and network isolation invariants for generic public fetching.
- Treatment of retrieved external data as untrusted input.
- Separation of read-only information retrieval from interactive browser automation.
- Phased delivery boundaries distinguishing PC V1 read-only capabilities from post-V1 browser interaction.
- Architectural decoupling of internet connectivity and web information tools from Cloud LLM authorization (`D-PHONE-13C`, `D-PHONE-01A`).

It governs all outbound network requests initiated by or on behalf of the assistant to retrieve current real-world information across PC Desktop, Web, and Mobile Companion clients.

---

## 2. Durable Architecture & Invariants

### 2.1 Read-Only Public Current Information (PC V1)

In accordance with Decision D9:
- **Approved Capability:** PC V1 includes capability-level, provider-independent access to read-only public information:
  - **Web Search:** Querying public search engines to locate relevant web resources.
  - **Webpage Fetch:** Retrieving and parsing text content from publicly accessible URLs.
  - **Weather Context:** Inquiring about current meteorological conditions and public forecasts.
  - **Public News & Bulletins:** Inquiring about general public current events via safe read-only mechanisms.
- **Provider Independence:** The architecture defines capability-level interfaces decoupling the assistant's reasoning engine from third-party vendor APIs.
- **Candidate Adapters (Non-Mandatory):** Specific external services (e.g., Tavily, SearXNG, Jina Reader, Direct HTTP, Open-Meteo, PAGASA public bulletins) are candidate adapter implementations evaluated as architectural evidence. **No single provider is a mandatory release dependency** or permanent architectural requirement. Adapters may be substituted, self-hosted, or rotated without altering core assistant contracts.

### 2.2 Generic Public Fetch & SSRF Protection Invariants

Outbound HTTP requests fetching public web resources represent an external boundary that must enforce strict Server-Side Request Forgery (SSRF) and network containment rules:
- **Loopback Blocking:** All requests targeting loopback addresses (`127.0.0.0/8`, `::1`, `localhost`) are strictly blocked.
- **Private Subnet Blocking:** All requests targeting RFC 1918 private subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) or unique local addresses (`fc00::/7`) are strictly blocked.
- **Link-Local & Cloud Metadata Blocking:** All requests targeting link-local addresses (`169.254.0.0/16`, `fe80::/10`) and known cloud instance metadata endpoints (e.g., `169.254.169.254`) are strictly blocked.
- **Unsafe Scheme Rejection:** Only standard web schemes (`http://`, `https://`) are permitted. All other URI schemes (including `file://`, `gopher://`, `ftp://`, `data:`, `blob:`, and custom OS handlers) are unconditionally rejected.
- **Redirect-Hop Revalidation:** Target IP addresses must be re-evaluated and re-validated against all blocking rules on every single HTTP redirect hop before following the redirect.
- **Network Boundary Separation:** Generic public fetch must **never** silently become or bridge into LAN/private-network access. Access to local network devices, home servers, or private subnet services requires distinct, explicitly authorized, typed integrations under user consent.

### 2.3 Untrusted Data Invariant & Prompt Injection Defense

All content ingested from external web sources is untrusted:
- **Untrusted Input Classification:** Search snippets, scraped webpage text, RSS feeds, and weather summaries are classified as external **UNTRUSTED DATA**.
- **Sanitization is Not Authorization:** Data sanitization, HTML stripping, or Markdown conversion formats data for model comprehension but does **not** establish trust or grant system authority.
- **Deterministic Policy Separation:** In accordance with Decision D9, deterministic security policies and tool execution guardrails remain external to the LLM. An LLM consuming external text cannot be granted authority to override safety boundaries, auto-execute high-risk tools, or escalate permissions through prompt injection embedded in fetched web text.

### 2.4 Browser Automation Separation (PC Later)

In accordance with Decision D9:
- **Deferred Capability:** Interactive browser automation (e.g., programmatic form submission, automated checkout, authenticated portal sessions, complex DOM traversal, headless browser orchestration via engines like Playwright or Selenium) is classified as `APPROVED / PC LATER`.
- **Strict Separation:** Interactive automation is architecturally and operationally distinct from read-only search and fetch. It is **not** part of PC V1 and must not be conflated with read-only retrieval capabilities.

### 2.5 Internet Connectivity Decoupled from Cloud AI Permission (D-PHONE-13C, D-PHONE-01A)

In accordance with Decisions `D-PHONE-13C` and `D-PHONE-01A`:
- **Architectural Decoupling:** Internet availability and public web tool execution are strictly decoupled from Cloud LLM authorization.
- **No Implicit Cloud AI Egress:** The presence of active internet connectivity, and the user's permission to execute read-only web tools (WebSearch, WebFetch, Weather), do **NOT** grant authorization to route conversational turns, prompts, or personal user context to external third-party Cloud LLMs.
- **Local Synthesis of Web Context:** A local companion (running on the PC Host or on qualified Standalone Mobile) may retrieve public web snippets or weather data over the internet and synthesize responses using its local on-device language model, without transmitting user conversation prompts to cloud generative AI providers.
- **Independent Authorization Boundary:** Cloud LLM usage remains an independent, explicit, user-opt-in capability requiring user-supplied API credentials. Enabling public internet retrieval never implicitly enables or authorizes Cloud LLM routing.

---

## 3. Current Verified Implementation

Repository source code establishes the current baseline reality:

- **Web Providers Status:** WebSearch, WebFetch, and Weather provider adapters are **NOT IMPLEMENTED** in the current codebase.
- **Backend Services:** `backend/app/services` contains local model orchestration (`llm/`), conversational turn management (`assistant/`), memory persistence (`memory/`), attachment handling, and model registry services. No external HTTP search client, web scraper, or weather connector exists in the backend runtime.
- **Candidate Status:** Provider names referenced in architecture plans (e.g., Tavily, SearXNG, Open-Meteo) represent candidate options for future implementation slices, not currently functional adapters.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the public information integration will supply:

1. **Typed Tool Contracts:** Standardized, provider-independent tool definitions exposed to the assistant turn orchestrator (e.g., candidate tool signatures such as `WebSearch`, `WebFetch`, and `WeatherLookup`).
2. **Hardened SSRF-Safe HTTP Fetcher:** Dedicated outbound HTTP client enforcing:
   - DNS resolution pre-flight validation preventing DNS rebinding.
   - Strict IP address verification against private, loopback, and link-local ranges before connection establishment.
   - Redirect chain interception revalidating every hop against IP blocklists.
   - Bounded timeouts and bounded response size limits (e.g., candidate parameters such as 10-second timeout ceiling and 2 MiB raw response ceiling).
3. **Untrusted-Content Extraction Pipeline:** Clean extraction of readable text from HTML/DOM, stripping executable scripts, styles, forms, and tracking elements, transforming payloads into bounded text or Markdown for prompt context insertion.
4. **Source Provenance Preservation:** Public information results preserve sufficient source provenance for user inspection and verification (candidate presentation patterns include source URLs, titles, domain attribution, or source cards).

---

## 5. OPEN DESIGN

The following functional and technical mechanisms remain open design for future implementation plans:

- **Exact Tool Signatures & Defaults:** Specific interface names, parameter defaults (e.g., `max_results`, `max_tokens`), and token allocation ceilings for search and page retrieval.
- **Network Boundaries & Timeouts:** Exact connection/read timeout thresholds, retry backoff algorithms, and maximum payload byte ceilings.
- **Content Extraction Pipeline:** Exact HTML parsing library, DOM cleaning heuristics, and Markdown conversion pipeline.
- **Provider Selection:** Primary and fallback provider choices for search, fetch, and weather (e.g., evaluating hosted privacy-centric search vs. self-hosted SearXNG).
- **Result Ranking & Summarization:** Specific relevance scoring, deduplication heuristics, and snippet summarization algorithms before context assembly.
- **Caching & Freshness:** Response caching strategies, time-to-live (TTL) policies per query type, and cache invalidation triggers.
- **Citation & Provenance Presentation UX:** The exact user interface conventions and presentation format for source provenance (e.g., inline citations, source cards, URLs and titles display, footnotes, or preview UI) remain OPEN DESIGN and design-owned.
- **News Integration:** Dedicated news-specific provider integrations and scheduled periodic digest generation.
- **Local Network Integrations:** Separate typed architecture for local smart-home or IoT integrations on private subnets, subject to explicit user authorization.

---

## 6. Security & Ownership Boundaries

- **Network Trust Tiers (Decision D5):** Web information retrieval operates across the boundary between the trusted Local AI Runtime and the untrusted Public Internet.
- **Tool Policy Resolution (Decision D9):** Read-only web queries represent Risk 0 (low-risk information access) operations. Under the system's `DEFAULT DENY` capability architecture, read-only web tools **MAY** auto-execute (`ALLOW`) only when the capability is explicitly enabled and deterministic profile/device policy permits it. They do not unconditionally evaluate to `ALLOW` by default.
- **Credential Isolation:** API keys required for external provider access (e.g., third-party search engine tokens) are stored in secure host configuration, never exposed to client-side code, and never injected into conversational prompt context.
- **Privacy Minimization:** Search queries generated by the assistant must minimize the transmission of identifying user personal context or sensitive profile lore to external search providers.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, Decisions D5, D9)
- **Tool Security & Deterministic Policy ADR:** [`docs/04_Architecture/decisions/ADR-0010-d9-typed-tool-security-policy.md`](../decisions/ADR-0010-d9-typed-tool-security-policy.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-WEB-001`)
- **Assistant Domain Specification:** [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md)
- **Tool Permissions & Actions Spec:** [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../02_Data_and_Security/tool-permissions-and-actions.md)
- **Authentication & Secrets Spec:** [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](../02_Data_and_Security/authentication-and-secrets.md)
- **Mobile Capabilities & Local Runtime:** [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md)
