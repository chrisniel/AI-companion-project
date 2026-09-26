# AI Companion — Security and Trust Architecture Specification

> **Document Role:** Legacy cross-domain security and trust reference (non-normative after R11.4).
> **Status:** Subordinate Reference — primary normative authority transferred to `02_Data_and_Security/` and `03_Integrations/web-current-information.md`.
> **Authority Precedence:** Non-normative reference material. See [`SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md) and focused domain specifications for canonical requirements.

> [!WARNING]
> **Authority Transfer & Legacy Status Notice (Pass R11.4):**
> This document is no longer the primary normative architecture specification for security, trust, authentication, device management, or tool execution. Primary normative authority has transferred to focused canonical specifications:
> - [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md) (Decisions D4, D8)
> - [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](02_Data_and_Security/authentication-and-secrets.md) (Decisions D4, D5)
> - [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](02_Data_and_Security/tool-permissions-and-actions.md) (Decision D9)
> - [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](02_Data_and_Security/privacy-retention-and-audit.md)
> - [`docs/04_Architecture/03_Integrations/web-current-information.md`](03_Integrations/web-current-information.md)
>
> In accordance with current canonical policy: arbitrary/generic command shell execution remains **REJECTED**; read-only current information retrieval is **PC V1**; interactive browser automation is **PC Later**.
>
> Top-level cross-cutting product decisions and release boundaries are governed by [`docs/04_Architecture/SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md). Implemented reality remains authoritative in source code and test suites. The retained content below serves as a cross-domain security reference and historical implementation baseline.

---

## 1. Executive Summary & Principles

The AI Companion security and trust model enforces defense-in-depth across every layer of the ecosystem:
1. **True Fail-Closed Gateways:** Public endpoints require explicit opt-in; all other routes reject unauthenticated requests by construction.
2. **Profile vs. Device Separation:** User identity (Profile) is decoupled from hardware endpoints (Devices).
3. **Three-Tier Trust Boundary:** Network security, device identity, and profile permissions form independent verification stages.
4. **Default Deny Tool Execution:** Generative models operate in an untrusted context and possess zero intrinsic operating system or network authority.
5. **Prompt Injection & SSRF Isolation:** User prompts and untrusted web contents cannot elevate execution privileges, access private networks, or bypass deterministic policy filters.

---

## 2. Current Authentication Boundary (Implemented Reality)

The current repository implementation (`backend/app/core/security.py`, `backend/app/api/v1/router.py`) enforces an authenticated perimeter:

### 2.1 Public vs. Protected Router Architecture
- **Whitelisted Public Router:** Only the minimal health check endpoint (`GET /api/v1/health` returning `{"status": "healthy"}`) is mounted without authentication.
- **Fail-Closed Protected Router:** All other API routes (`/api/v1/system`, `/api/v1/auth`, `/api/v1/tasks`, `/api/v1/models`, `/api/v1/conversations`, `/api/v1/memories`) are mounted under a router dependency requiring token verification (`Depends(verify_token)`).

### 2.2 Shared Application Credential Reality
- Current authentication validates incoming requests against a single configured application credential: `settings.COMPANION_API_KEY` (or an auto-generated pairing token via `ensure_pairing_token()`).
- Clients must present credentials via:
  - `Authorization: Bearer <token>` header, or
  - `X-API-Key: <token>` header.
- Token comparison uses constant-time validation (`hmac.compare_digest`) to eliminate timing-side-channel attacks.
- **Implementation State:** A single shared pairing token is the **current repository reality**. Future per-device revocable credentials (Section 3) are an approved architectural direction for subsequent milestones, but are **not** currently implemented in the codebase.

---

## 3. Profiles & Trusted Devices Architecture (Decision D4)

Future multi-device milestones separate human user identity from physical client endpoints:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Local AI Runtime Database                       │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                     Profile (User Identity)                    │   │
│   │  id: default-profile                                           │   │
│   │  owns: Conversations, Memories, Tasks, Preferences             │   │
│   └───────────────▲───────────────────────────────▲────────────────┘   │
│                   │ 1                             │ 1                  │
│                   │                               │                    │
│                   │ N                             │ N                  │
│   ┌───────────────┴──────────────┐ ┌──────────────┴────────────────┐   │
│   │         Device: PC           │ │        Device: Phone          │   │
│   │ device_id: win-desktop-01    │ │ device_id: infinix-zero-01    │   │
│   │ credential: hash(secret_a)   │ │ credential: hash(secret_b)    │   │
│   │ capabilities: [web, admin]   │ │ capabilities: [mobile_client] │   │
│   └──────────────────────────────┘ └───────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Architectural Separation
- **Profile:** Represents a human user identity and canonically owns all personal data (conversations, persistent memories, task records, and character persona selection). V1 operates as a single-primary-user system (`owner_id` preserves this boundary in DB schemas, Decision D8).
- **Device:** Represents a paired hardware client instance with a unique `device_id`, friendly name, bound `profile_id`, revocable credential, capability set, and last-seen timestamp.
- **Cardinality:** Profiles and Devices are **not permanently 1:1**. A single profile may pair multiple trusted client endpoints (e.g., PC desktop browser, Android mobile client).

### 3.2 Revocable Device Credentials
- Master PC application secrets are **never** distributed directly to client devices.
- During initial device enrollment, each client is issued an independent, cryptographically random revocable credential. (Specific pairing exchange mechanisms—such as QR code scanning or pairing phrase entry—are illustrative UX possibilities; the exact enrollment UX, cryptographic exchange protocol, credential/token format, and rotation/expiration interval remain open implementation design under Decision D4).
- Revoking a single device credential immediately severs that hardware endpoint's access without invalidating credentials held by other paired devices.

### 3.3 Secure Client Storage Direction
- Client devices must persist credentials using platform-native secure credential stores:
  - Windows Packaged Application: OS-protected secret storage such as DPAPI or Windows Credential Manager.
  - Android: Keystore-backed secure storage. Production credentials must **not** remain in ordinary `SharedPreferences`. Credentials and encryption keys should be excluded from auto-backup and device transfer where applicable. (Do not lock `EncryptedSharedPreferences` as the permanent implementation; the exact secure-storage library/mechanism remains future implementation design).
- Plaintext API tokens must never be committed to source control or logged in telemetry.

---

## 4. Network and Transport Trust (Decision D5)

```text
┌─────────────────────────────────────────────────────────────┐
│                    Windows Host Machine                     │
│                                                             │
│  ┌───────────────────────┐       ┌───────────────────────┐  │
│  │       React Web       │       │   Local AI Runtime    │  │
│  │     (Browser Tab)     │       │ (Persistent Process)  │  │
│  │   localhost:3000      │       │    localhost:8000     │  │
│  └───────────┬───────────┘       └───────────▲───────────┘  │
│              │                               │              │
│              └──────── HTTP / SSE ───────────┤              │
│                                              │              │
└──────────────────────────────────────────────┼──────────────┘
                                               │ Authenticated API
                                               │ (LAN / Tailscale)
                                   ┌───────────▼───────────┐
                                   │   Android Companion   │
                                   │    (Paired Device)    │
                                   └───────────────────────┘
```

### 4.1 Supported Network Boundaries
V1 network connectivity is strictly bounded to three trusted topologies:
1. **Localhost / Loopback (`127.0.0.1`):** Primary local PC execution.
2. **Trusted Local Area Network (LAN):** Explicitly configured local subnet bindings.
3. **Tailscale / Private Mesh Networks:** The approved mechanism for remote connectivity across devices.

### 4.2 Public Ingress Policy
- AI Companion V1 does **not** support or require direct public internet exposure or router port forwarding.
- Direct UPnP or unsolicited public port binding is prohibited.
- Future controlled public access may evaluate Cloudflare HTTPS / edge services, but transport encryption never replaces application-level authentication.

### 4.3 Three-Tier Trust Model (Target Architecture vs. Current Reality)
In the target multi-device architecture (Decisions D4 & D5), all remote requests must satisfy three sequential, independent verification gates:
$$\text{Tier 1: Network / Transport Trust (trusted LAN / Tailscale mesh; app-layer TLS where applicable)} \longrightarrow \text{Tier 2: Trusted-Device Auth (Revocable Credential)} \longrightarrow \text{Tier 3: Profile Auth}$$

> [!IMPORTANT]
> **Current vs. Target Implementation State:**
> - **Current Repository Reality:** The active codebase uses a single shared application pairing token (`COMPANION_API_KEY`) across all clients.
> - **Target D4/D5 Model:** Independent revocable per-device credentials, client Keystore storage, and multi-device identity separation are planned future targets.
> - **Transport Boundary:** Network proximity, VPN/Tailscale presence, or private IP addresses never substitute for application-level authentication. Exact application-layer TLS and certificate enrollment mechanisms remain an open implementation design where applicable; direct public exposure is excluded from V1.

---

## 5. Tool, Web & Autonomy Security Model (Decision D9)

Generative models and autonomous agent workflows **never** receive unrestricted operating system, device, network, or filesystem authority.

### 5.1 Execution Pipeline
All tool operations pass through a deterministic, typed validation chain:
$$\text{Model} \longrightarrow \text{Typed Tool Request} \longrightarrow \text{Deterministic Policy Engine} \longrightarrow \text{Narrow Adapter} \longrightarrow \text{Capability}$$

The policy engine operates under an immutable **DEFAULT DENY** posture.

### 5.2 4-Tier Risk Classification Matrix

| Tier | Classification | Description & Scope | Execution Policy |
| :--- | :--- | :--- | :--- |
| **Risk 0** | **Read-Only / Information** | Public web search, weather queries, permitted webpage text reading, internal memory/task inspection, runtime telemetry. | May auto-execute when enabled by profile and device policy. |
| **Risk 1** | **Reversible Low-Impact** | Creating personal tasks, scheduling non-alarm reminders, user notifications, harmless preference toggles. | Profile-configurable policy (ALLOW, CONFIRM, or DENY; initial implementation may default to confirmation). Does not imply auto-approval only. |
| **Risk 2** | **Significant State Change** | Deleting tasks or conversations, external message transmission, web form submission, model uninstallation, sensitive configuration changes. | **Explicit user confirmation required** by default. |
| **Risk 3** | **Privileged / Destructive (Prohibited Generic Capabilities)** | Arbitrary shell/command execution, unrestricted filesystem access, credential access, raw root/device administration, network/security configuration. | **PROHIBITED BY DEFAULT.** Not exposed as generic assistant tools. Any future elevated capability requires a separately designed narrow interface, explicit authorization, bounded scope, and appropriate expiration/revocation; never unlocked merely by ordinary one-time confirmation. |

### 5.3 Security & Elevation Invariants
- **No Self-Privilege:** Models cannot grant permissions or elevate risk tiers for themselves.
- **Prompt Injection Defense:** Untrusted user prompt content cannot elevate execution privileges or override system risk policies.
- **Untrusted Web Content & Prompt Injection Isolation:** External web pages, search snippets, and API responses fetched during tool execution are explicitly framed and isolated outside the model loop as **UNTRUSTED DATA**. Sanitization may be applied for parsing, HTML stripping, or rendering safety, but sanitization is **not** the prompt-injection defense boundary. The deterministic permission and policy engine exists completely outside model-generated text and remains authoritative even if the model is manipulated or injected.
- **Prohibited Generic Capabilities (Risk 3):** Generic privileged, destructive, or security-sensitive capabilities (such as arbitrary shell execution, unrestricted filesystem mutations, credential access, raw OS/device administration, or network reconfiguration) are strictly **prohibited by default** and are never exposed as generic assistant tools. A generic command shell does not become available merely because the user confirms a prompt. Any future elevated action requires a separately designed narrow interface, explicit user authorization, strictly bounded scope, and appropriate expiration/revocation.
- **Auditable Logging & Privacy:** Security-sensitive and state-changing actions (Risk 1+) must be auditable by construction, recording appropriate metadata (action type, profile, device origin, risk level, confirmation state, outcome, timestamp/request ID). The permanent retention duration, exact database table/schema, exact persisted fields, and whether all Risk 1 events use identical persistence mechanics remain open future implementation designs. To protect user privacy, audit logging must **not** indiscriminately record raw parameter blobs, sensitive user payloads, credentials, or private message bodies unless an explicit future security policy requires it.

---

## 6. External Web and Information Providers

External information capabilities use vendor-independent provider abstractions rather than hardcoded services.

### 6.1 Replaceable Provider Candidates

| Provider Role | Initial / Primary Candidate | Alternate / Self-Hosted Candidate | Research / Deferred Option |
| :--- | :--- | :--- | :--- |
| **`WebSearchProvider`** | **Tavily** (initial candidate) | **SearXNG** (optional / self-hosted) | **Exa** (optional research candidate) |
| **`FetchProvider`** | **Jina Reader** (initial candidate) | **Direct HTTP** (where appropriate) | **Firecrawl** (optional crawler) |
| **`WeatherProvider`** | **Open-Meteo** (routine forecasts) | **PAGASA** (official public bulletins/pages for severe weather) | — |
| **News / Current Info** | **Web Search + Fetch** (initial capability) | — | Dedicated **`NewsProvider`** (deferred until feeds/digests justify it) |
| **`BrowserProvider`** | **Local Playwright** (future candidate) | — | **Steel** (future evaluation candidate) |

> [!NOTE]
> All external services listed above are **implementation candidates**, not permanent vendor dependencies:
> - **Provider Independence:** The system architecture preserves provider-independent interfaces so services can be swapped, self-hosted, or disabled.
> - **Philippine Severe Weather:** PAGASA reference relies on official public bulletins and public advisory web pages; no private or authenticated API integration is currently available, implemented, or required.
> - **News / Current Information:** The initial capability is fulfilled via existing Web Search + Fetch tools. A standalone dedicated `NewsProvider` abstraction is **deferred** until scheduled news digests, RSS/Atom feeds, or structured news monitoring requirements justify a specialized provider interface.

### 6.2 SSRF Defenses & Private Network Restrictions
Generic public `FetchProvider` implementations must enforce strict Server-Side Request Forgery (SSRF) protections:
- **Loopback Blocking:** Strict rejection of `127.0.0.1`, `localhost`, `::1`, and equivalent loopback representations.
- **Private Subnet Blocking:** Rejection of RFC 1918 private network ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`).
- **Link-Local & Cloud Metadata Blocking:** Rejection of link-local addresses (`169.254.0.0/16`, including cloud metadata endpoints like `169.254.169.254`).
- **Unsafe Protocols & Redirect Validation:** Rejection of non-HTTP(S) schemes (e.g., `file://`, `gopher://`); each HTTP redirect hop re-validates the destination IP against SSRF blocklists before connecting.
- **LAN Boundary Isolation:** Generic web fetch must never silently gain internal LAN or localhost access. If the product later requires communication with trusted local-network resources (e.g., local home automation or local servers), that must be architected as a **separate, explicitly authorized local-network capability**, completely decoupled from public web fetching.
- **Capability Separation:** Read-only web search and fetch capabilities are strictly isolated from interactive web actions (e.g., clicking, form submission, authenticated sessions).

---

## 7. Emergency Tool Controls & Cancellation Semantics

The system architecture reserves deterministic execution controls and kill switches:
1. **Stop Generation:** Immediate abort of current SSE inference token streaming.
2. **Stop Current Action:** Request cancellation of the active in-flight tool or provider request where cancellation is supported by the transport/runtime.
3. **Stop All Actions:** Termination of an active multi-step agent or tool loop, halting any queued, not-yet-started actions.
4. **Global Autonomous Disable:** Master application configuration kill switch disabling all external tool execution across the runtime.

> [!IMPORTANT]
> **Cancellation vs. Rollback Boundaries:**
> - Cancellation reliably stops queued, pending, or not-yet-started tool operations and halts further steps in a multi-action agent sequence.
> - For in-flight network or provider operations, cancellation requests termination where underlying libraries/transports support cooperative cancellation.
> - The architecture does **not** promise impossible rollback: already-committed external side effects (e.g., an external HTTP mutation or a completed external action) cannot always be undone. The exact handling and user notification semantics for non-cancellable external side effects remain future implementation design.
