# AI Companion — Security and Trust Architecture Specification

> **Document Role:** Canonical architecture specification for authentication, device trust, network boundaries, and tool security.  
> **Status:** Active Canonical (Decisions D4, D5, D9 Locked)  
> **Last Updated:** 2026-09-20 (Reconciliation Pass R3)

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
- During initial pairing (e.g., via QR code or pairing phrase exchange), each device is issued an independent, cryptographically random revocable credential.
- Revoking a single device credential immediately severs that hardware endpoint's access without invalidating credentials held by other paired devices.

### 3.3 Secure Client Storage Direction
- Client devices must persist credentials using platform-native secure credential stores:
  - Windows: Windows Credential Manager or encrypted local app state.
  - Android: Android KeyStore / EncryptedSharedPreferences.
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

### 4.3 Three-Tier Trust Model
All remote requests must satisfy three sequential, independent verification gates:
$$\text{Tier 1: Network / Transport Trust (Tailscale / TLS)} \longrightarrow \text{Tier 2: Trusted-Device Authentication (Revocable Credential)} \longrightarrow \text{Tier 3: Profile Authorization}$$

Network proximity, VPN presence, or private IP addresses never substitute for device authentication or profile authorization.

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
| **Risk 1** | **Reversible Low-Impact** | Creating personal tasks, scheduling non-alarm reminders, user notifications, harmless preference toggles. | Profile-configurable auto-approval. |
| **Risk 2** | **Significant State Change** | Deleting tasks or conversations, external message transmission, web form submission, model uninstallation, sensitive configuration changes. | **Explicit user confirmation required** by default. |
| **Risk 3** | **Privileged / Destructive** | Arbitrary shell/command execution, unrestricted filesystem mutations, credential access, OS/network configuration. | **DEFAULT DENY.** Requires explicit, narrow, time-bounded user authorization. |

### 5.3 Security & Elevation Invariants
- **No Self-Privilege:** Models cannot grant permissions or elevate risk tiers for themselves.
- **Prompt Injection Defense:** Untrusted user prompt content cannot elevate execution privileges or override system risk policies.
- **Untrusted Web Content:** External web pages, search snippets, and API responses fetched during tool execution are treated as untrusted data and sanitized before feeding into prompt contexts.
- **Interactive Shell Prohibition:** General-purpose interactive command shells (e.g., raw bash, PowerShell, cmd) are prohibited as standard assistant tools.
- **Auditable Logging:** All sensitive tool invocations (Risk 1+) produce structured, persistent diagnostic logs recording requester, parameters, confirmation status, and outcome.

---

## 6. External Web and Information Providers

External information capabilities use vendor-independent provider abstractions rather than hardcoded services.

### 6.1 Replaceable Provider Candidates

| Provider Role | Initial / Primary Candidate | Alternate / Self-Hosted Candidate | Research / Deferred Option |
| :--- | :--- | :--- | :--- |
| **`WebSearchProvider`** | **Tavily** (initial hosted candidate) | **SearXNG** (self-hosted option) | **Exa** (specialized research candidate) |
| **`FetchProvider`** | **Jina Reader** (clean markdown extraction) | **Direct HTTP** (where appropriate) | **Firecrawl** (optional crawler) |
| **`WeatherProvider`** | **Open-Meteo** (routine global forecast) | **PAGASA** (official Philippine severe weather) | — |
| **`NewsProvider`** | Composite (Search + Fetch) | Composite | — |
| **`BrowserProvider`** | **Local Playwright** (future post-V1) | **Steel** (future evaluation candidate) | — |

> [!NOTE]
> All external services listed above are **implementation candidates**, not permanent vendor dependencies. The system architecture preserves provider-independent interfaces so services can be swapped, self-hosted, or disabled.

### 6.2 SSRF Defenses & Private Network Restrictions
All web-fetch adapters must enforce strict Server-Side Request Forgery (SSRF) protections:
- **Loopback Blocking:** Strict rejection of `127.0.0.1`, `localhost`, `::1`, and equivalent loopback representations.
- **Private Subnet Blocking:** Rejection of RFC 1918 private ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`).
- **Link-Local & Cloud Metadata Blocking:** Rejection of link-local addresses (`169.254.0.0/16`, including cloud metadata endpoints like `169.254.169.254`).
- **Redirect Validation:** HTTP redirect chains must be inspected; each redirect hop re-validates the target IP against SSRF blocklists before connection.
- **Capability Separation:** Read-only web search and fetch capabilities are strictly isolated from interactive web actions (e.g., clicking, form submission, authenticated sessions).

---

## 7. Emergency Tool Controls

The system architecture reserves deterministic kill switches and execution controls:
1. **Stop Generation:** Immediate abort of current SSE inference token streaming.
2. **Stop Current Action:** Immediate cancellation of an in-flight tool or provider request.
3. **Stop All Actions:** Immediate termination of an active multi-step agent or tool loop.
4. **Global Autonomous Disable:** Master application configuration kill switch disabling all external tool execution across the runtime.
