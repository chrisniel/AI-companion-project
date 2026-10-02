# Architecture Decision Records (ADR)

> **Authority Statement:** ADRs record accepted decisions, context, consequences, and change control. **Focused domain specifications remain the primary normative domain owners.** ADRs do not become competing domain owners. Superseding an accepted ADR requires explicit user approval and a superseding decision record.

---

## 1. Active & Historical ADR Index

| ADR ID | Title | Status | Release | Primary Canonical Owner | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **[`ADR-0001`](ADR-0001-github-source-hugging-face-lfs.md)** | GitHub Source & Hugging Face LFS | `Accepted` | Repo Baseline | [AGENTS.md](../../../AGENTS.md) | Git source on GitHub; LFS objects on Hugging Face. |
| **[`ADR-0002`](ADR-0002-d1-pc-v1-release-boundary.md)** | D1 - PC V1 Release Boundary | `Accepted (Refined)` | PC V1 | [`SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) | PC V1 is primary; Android V1 is follow-on. Refined by ADR-0017. |
| **[`ADR-0003`](ADR-0003-d2-windows-host-model.md)** | D2 - Windows Host Model | `Accepted (Refined)` | PC V1 | [`windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md) | Decoupled runtime; autostart at login. Refined by ADR-0017. |
| **[`ADR-0004`](ADR-0004-d3-android-application-identity.md)** | D3 - Android Application Identity | `Accepted` | Android V1 | [`android-companion.md`](../01_Domains/android-companion.md) | Single Android companion application identity. |
| **[`ADR-0005`](ADR-0005-d4-profile-device-credential-boundary.md)** | D4 - Profile & Device Credential Boundary | `Accepted (Refined)` | PC V1 | [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md) | Profile vs Device distinction. Refined by ADR-0018 (satellite binds to 1 profile). |
| **[`ADR-0006`](ADR-0006-d5-remote-access-trust-boundary.md)** | D5 - Remote Access Trust Boundary | `Accepted (Refined)` | PC V1 | [`authentication-and-secrets.md`](../02_Data_and_Security/authentication-and-secrets.md) | Loopback default + Tailscale + Cloudflare Tunnel; port forwarding rejected. |
| **[`ADR-0007`](ADR-0007-d6-controlled-model-acquisition.md)** | D6 - Controlled Model Acquisition | `Accepted (Refined)` | PC V1 | [`runtime-and-models.md`](../04_Infrastructure/runtime-and-models.md) | Manual user scan (no watcher); atomic multi-file bundles (`.gguf` + `mmproj`). |
| **[`ADR-0008`](ADR-0008-d7-profile-first-memory-ownership.md)** | D7 - Profile-First Memory Ownership | `Accepted (Refined)` | PC V1 | [`memory-and-personalization.md`](../01_Domains/memory-and-personalization.md) | Profile owns memories; temporary validity lifecycle; local extraction default. |
| **[`ADR-0009`](ADR-0009-d8-single-primary-user-baseline.md)** | D8 - Single Primary User Baseline | **`Superseded`** | PC V1 | [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md) | **Superseded by ADR-0018.** Replaced with multi-profile PC V1 model. |
| **[`ADR-0010`](ADR-0010-d9-typed-tool-security-policy.md)** | D9 - Typed Tool Security Policy | `Accepted (Refined)` | PC V1 | [`tool-permissions-and-actions.md`](../02_Data_and_Security/tool-permissions-and-actions.md) | DEFAULT DENY, 4-tier risk matrix; arbitrary shell rejected; emergency kill switch. |
| **[`ADR-0011`](ADR-0011-d10-scheduling-and-notification-semantics.md)** | D10 - Scheduling and Notification Semantics | `Accepted (Refined)` | PC V1 | [`tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md) | Task, Reminder, Alarm, Routine distinct; runtime SchedulerService; alarms bypass quiet hours. |
| **[`ADR-0012`](ADR-0012-d11-persona-and-state-separation.md)** | D11 - Persona and State Separation | `Accepted (Refined)` | PC V1 | [`characters-personality-and-emotion.md`](../01_Domains/characters-personality-and-emotion.md) | Template vs Instance; 8 continuous traits; persistent bounded mood; Neutral Assistant fallback. |
| **[`ADR-0017`](ADR-0017-flutter-production-windows-client.md)** | Flutter Production Windows Client | `Accepted` | PC V1 | [`windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md) | Flutter Desktop is approved primary Windows client for PC V1; React Web remains supported dev harness. |
| **[`ADR-0018`](ADR-0018-multi-profile-pc-v1-ownership-model.md)** | Multi-Profile PC V1 Ownership Model | `Accepted` | PC V1 | [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md) | 1 Local Account, Multiple Isolated Profiles. Supersedes ADR-0009. 7-day soft delete. |
| **[`ADR-0019`](ADR-0019-client-runtime-contract-and-work-boundaries.md)** | Client ↔ Runtime Contract & Work Boundaries | `Accepted` | PC V1 | [`assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md) | REST (commands), SSE (tokens/events), WebSocket (voice); durable FIFO turn queues. |

---

## 2. Historical Guardrail: ADR-0013 through ADR-0016

> [!WARNING] Guardrail on ADR-0013 through ADR-0016
> The identifiers `ADR-0013`, `ADR-0014`, `ADR-0015`, and `ADR-0016` correspond to historical drafts, unaccepted proposals, or superseded reconciliation notes from earlier planning iterations.
>
> In accordance with [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) §3:
> - These numbers must **never** be casually resurrected, treated as accepted authority, or reused for unrelated topics.
> - Accepted new architectural records begin permanently at **`ADR-0017`** to ensure immutable traceability.
