# Implementation Plan: M4 Batch A — D9 Deterministic Action Engine & Read-Only Web Information

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Awaiting Approval
- **Delivery Level:** Level C — Sensitive Design
- **Scope Mode:** New Feature — D9 5-stage deterministic tool policy engine (`DEFAULT DENY`), Risk 0–2 policy persistence, persistent Global Tool Kill Switch, fingerprint-bound confirmation tokens, redacted tool audit log, bounded personal productivity + read-only SSRF-hardened Web Search / Web Fetch / Weather adapters, SSE & OpenAPI/Dart parity, and Flutter Desktop `ChatScreen` + `Settings -> Tools & Safety` UI (no Voice STT/TTS/WASAPI audio changes and no React Web UI edits).
- **Target Files:**
  - `backend/app/models/` (`tool_runtime_config.py`, `profile_tool_settings.py`, `tool_confirmation.py`, `tool_audit_log.py`, `message.py`, `__init__.py`)
  - `backend/migrations/versions/017_d9_tool_policy_and_audit.py`
  - `backend/app/schemas/` (`tools.py`, `message.py`, `llm.py`)
  - `backend/app/services/tools/` (`registry.py`, `policy.py`, `executor.py`, `adapters_productivity.py`, `audit.py`, `web_secret_store.py`)
  - `backend/app/services/web/` (`ssrf_guard.py`, `sanitizer.py`, `providers.py`)
  - `backend/app/services/llm/` (`base.py`, `llama_cpp.py`, `mock.py`)
  - `backend/app/services/assistant/orchestrator.py`
  - `backend/app/services/profile_purge_service.py`
  - `backend/app/api/v1/endpoints/tools.py` & `conversations.py` & `backend/app/api/v1/router.py`
  - `contracts/openapi/openapi.json` & `scripts/check_dart_openapi_parity.py`
  - `frontend/flutter/packages/companion_api/` (`lib/dto/tools_dto.dart`, `lib/dto/message_dto.dart`, `lib/dto/sse_event_dto.dart`, `lib/transport/sse_parser.dart`, `lib/client/companion_client.dart`, `lib/companion_api.dart`)
  - `frontend/flutter/apps/desktop/` (`lib/features/tools/`, `lib/features/chat/`, `lib/screens/chat_screen.dart`, `lib/features/settings/sections/settings_tools_section.dart`, `lib/features/settings/settings_section.dart`, `lib/screens/settings_screen.dart`, `lib/shell/desktop_shell.dart`, `lib/lifecycle/desktop_lifecycle_coordinator.dart`)
  - `backend/tests/`, `frontend/flutter/packages/companion_api/test/`, `frontend/flutter/apps/desktop/test/`
  - Phase 3 docs: canonical specs (`tool-permissions-and-actions.md`, `web-current-information.md`, `privacy-retention-and-audit.md`, `assistant-and-conversations.md`, `01_PC_Desktop_Shell_and_Tray.md`), `DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `CHANGELOG.md`, walkthrough, and archived branch tracker.
- **Branch:** `feature/m4-d9-tools-and-web-a`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m4-d9-tools-and-web-a.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m4-d9-tools-and-web-a.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:** Deliver the **M4 Batch A** security, backend, contract, and Flutter Desktop foundation for tool calling and read-only external current information:
  1. Enforce the Decision **D9** 5-stage deterministic pipeline ($\text{Model} \rightarrow \text{Typed Request} \rightarrow \text{Deterministic Policy} \rightarrow \text{Narrow Adapter} \rightarrow \text{Capability}$) under `DEFAULT DENY`, strict `profile_id` isolation, persistent Global Tool Kill Switch, fingerprint-bound `CONFIRM` gates, redacted audit logging, and zero silent tool replay on regeneration.
  2. Deliver read-only public information adapters (`weather_lookup` via zero-key Open-Meteo default, `web_search` via zero-key public search / configurable SearXNG / optional Host-protected BYO key, and `web_fetch`) protected by fail-closed SSRF IP/DNS pinning, redirect-hop revalidation, bounded `10s / 2 MiB` caps, untrusted HTML sanitization, and user-visible source provenance chips.
  3. Wire structured tool execution & confirmation cards directly into the unified Desktop **`ChatScreen`** hub (aligned with settled Option A architecture where text, tools, sources, images, and future Batch C voice converge inside Chat) plus persistent Global Kill Switch access in `DesktopShell` / tray and unlock **`Settings -> Tools & Safety`** from `PLANNED • M4` to `AVAILABLE`.
- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) — §3 Invariants #4, #5 (`D9`), #8 (`D5`), #9 (`ADR-0019`), and §5 Golden Groups G7 & G10.
  - [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md) — 5-stage pipeline, `DEFAULT DENY`, Risk 0/1/2/3 tiers, Intent Provenance tags, persistent Global Kill Switch, parameter/session/expiry/fingerprint confirmation binding, unambiguous conversational confirmation, and `D-SHARED-CONV-03A` non-replay.
  - [`docs/04_Architecture/03_Integrations/web-current-information.md`](../../04_Architecture/03_Integrations/web-current-information.md) — SSRF loopback/private/link-local/metadata blocking, unsafe scheme rejection, redirect-hop revalidation, untrusted data framing, source provenance, and internet-decoupled-from-Cloud-LLM invariant.
  - [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../../04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md) — §2.2 & §3.5 redacted metadata-only audit log invariant and permanent Profile purge ordering.
  - [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](../../04_Architecture/02_Data_and_Security/authentication-and-secrets.md) — §2.6 device-local credential isolation (never expose raw provider keys to browsers or LLM).
  - [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../../04_Architecture/01_Domains/assistant-and-conversations.md) — §2.7 & §2.8 (`D-SHARED-CONV-03A` no replay on regenerate, unified interaction surface).
  - [`docs/04_Architecture/decisions/ADR-0010-d9-typed-tool-security-policy.md`](../../04_Architecture/decisions/ADR-0010-d9-typed-tool-security-policy.md) & [`ADR-0018`](../../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md).
- **Concrete Deliverables:**
  1. Alembic Migration `017_d9_tool_policy_and_audit.py` adding `tool_runtime_config`, `profile_tool_settings`, `tool_confirmations`, `tool_audit_logs`, and nullable `messages.metadata_json` (plus `ProfilePurgeService` cascade cleanup).
  2. Backend D9 engine (`registry.py`, `policy.py`, `executor.py`, `audit.py`, `adapters_productivity.py`, `web_secret_store.py`) and SSRF-hardened web retrieval (`ssrf_guard.py`, `sanitizer.py`, `providers.py`) with zero new Python third-party wheel dependencies (keeping `backend/requirements.lock` untouched).
  3. Structured tool calling support (`tools` parameter + `delta.tool_calls` streaming + strict validated JSON fallback) across `BaseLLMProvider`, `LlamaCppProvider`, `MockLLMProvider`, and bounded `orchestrate_chat_stream` (`MAX_TOOL_ROUNDS = 3`) emitting typed SSE frames (`tool_intent`, `tool_result`, `tool_confirmation_required`).
  4. Authenticated `/api/v1/tools/*` REST endpoints with Host Admin boundary for disabling the Kill Switch and storing/clearing local Web Search API keys, regenerated `contracts/openapi/openapi.json`, and 100% matching `companion_api` Dart DTOs, SSE parser events, `CompanionClient` methods, and `check_dart_openapi_parity.py` registration.
  5. Flutter Desktop UI: `DesktopToolPolicyController`, persistent Global Tool Kill Switch in `DesktopShell` top bar and system tray menu, inline Risk 2 Confirmation Cards + Risk 0 action receipts + Web Source Provenance chips in `ChatScreen`, and real `SettingsToolsSection` unlocking `Settings -> Tools & Safety`.
- **Explicit Out-of-Scope:**
  - **M4 Batch B & Batch C Voice Pipeline:** `whisper.cpp` STT, `silero_vad.onnx`, `Kokoro-82M` TTS, WebSocket audio transport, Windows WASAPI capture/playback, Option A removal of the `Voice` rail tab, and customizable Voice shortcuts remain strictly deferred to Batches B & C (`SettingsSectionId.voice` and `DesktopNavDestination.voice` remain `PLANNED • M4` in Batch A).
  - **Prohibited / Post-V1 Capabilities:** Risk 3 arbitrary shell/OS/filesystem tools (`REJECTED`), Playwright interactive browser automation (`PC LATER`), and PC screen-snapshot button (separate post-M4 / M5 scope).
  - **React Web UI Modifications:** `frontend/web/` is unchanged in Batch A beyond existing OpenAPI type compatibility.
  - **Python Dependency Changes:** No new entries in `pyproject.toml` / `requirements.txt` / `requirements.lock` (uses stdlib `html.parser`, `ipaddress`, `socket`, `hmac`, `hashlib`, and already-locked `httpx`).

---

## 2. Architecture & Technical Approach

- **Current Findings & Technical Baseline:**

  | Observation / Evidence | Verified Interpretation |
  | --- | --- |
  | `backend/app/services/llm/llama_cpp.py` (`lines 47-78`, `1168-1299`) accepts `finish_reason == "tool_calls"` in `_decode_stream_event`, but ignores `delta.tool_calls` and omits `tools` from payloads. | `LlamaCppProvider` and `BaseLLMProvider` need non-breaking optional `tools` / `tool_choice` support plus structured `tool_calls` extraction alongside `MockLLMProvider` simulation and JSON-intent fallback for local GGUFs that omit native tool JSON. |
  | `backend/app/api/v1/router.py` mounts `protected_router` (requiring `get_current_profile_session`) and `system_router` (requiring `require_host_admin`); `CompanionClient` (`companion_client.dart:28-73`) already attaches `X-Host-Admin-Secret` when `hostAdminStore` is provided. | Enforcing `get_current_profile_session` for profile policy/audit/confirmations and `require_host_admin` for disabling `global_kill_switch` or mutating local web search API keys fits the existing trust model cleanly without weakening browser/remote isolation. |
  | `backend/app/services/profile_purge_service.py` (`lines 24-38`) deletes profile-owned child entities explicitly in FK order before deleting `Profile`; current Alembic head is `016_reminder_center_popup`. | Migration `017` and `ProfilePurgeService` must delete `tool_audit_logs`, `tool_confirmations`, and `profile_tool_settings` before removing `profiles` to preserve `PRAGMA foreign_keys = ON` purge integrity. |
  | `backend/app/api/v1/endpoints/tasks.py` and `scheduling.py` contain profile-scoped CRUD validation and task/reminder sync helpers; `backend/app/services/memory/retriever.py` provides FTS5 search. | Extracting/reusing shared helpers ensures D9 narrow adapters enforce identical validation, quiet-hours awareness, and BOLA checks without duplicating endpoint logic. |
  | `scripts/python_dependency_lock.py` enforces strict wheel-closure matching against `backend/requirements.lock`. | Implementing SSRF containment (`ipaddress`, `socket`), HTML-to-Markdown extraction (`html.parser`), and HTTP (`httpx`) avoids wheel-lock churn in Batch A. |
  | `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart` (`lines 185-215`) maps `SettingsSectionId.tools` to `SettingsPlannedSection`, and `desktop_settings_revamp_test.dart` (`lines 51-53`) asserts `tools.status == planned`. | Promoting `SettingsSectionId.tools` to `available` (`milestoneHint: null`) requires wiring `SettingsToolsSection` in `SettingsScreen` and updating that test assertion deliberately. |
  | `companion_api/lib/dto/sse_event_dto.dart` (`SseEvent` sealed class) and `sse_parser.dart` (`lines 53-80`) parse `token`, `done`, and `error` frames. | Adding `SseToolIntentEvent`, `SseToolResultEvent`, and `SseToolConfirmationRequiredEvent` (with unknown-event fallback) cleanly delivers live tool status, confirmations, and web citations over the existing chat stream. |

- **Architectural Approach:**
  1. **Typed Tool Catalog & Strict Validation (`backend/app/services/tools/registry.py`):**
     - Define immutable `ToolSpec` definitions with risk tier (`0`, `1`, `2`), JSON Schema parameters for LLM tool-calling, strict Pydantic v2 `BaseModel` (`ConfigDict(extra="forbid")`), domain tag, and adapter handler:
       - **Risk 0 (`ALLOW` default when enabled):** `weather_lookup`, `web_search`, `web_fetch`, `list_tasks`, `list_reminders`, `list_alarms`, `search_memories`.
       - **Risk 1 (explicit `ALLOW` / companion-suggested `CONFIRM` by default):** `create_task`, `update_task` *(note: soft-delete / `is_deleted` status changes stay Risk 2)*, `create_reminder`, `create_alarm`.
       - **Risk 2 (`CONFIRM` default):** `delete_task`, `delete_reminder`, `delete_alarm`.
       - **Risk 3 (`REJECTED` permanently):** Explicit `PROHIBITED_TOOL_NAMES` guard rejecting any `shell`, `bash`, `powershell`, `cmd`, `exec`, `eval`, `filesystem_*`, or `credential_*` intent unconditionally (`DEFAULT DENY`).
  2. **5-Stage Deterministic Policy & Confirmation Engine (`policy.py`, `executor.py`, `audit.py`):**
     - **Stage 1 (Model Intent Normalization):** Collect structured `tool_calls` deltas from provider OR parse strict bounded JSON tool intent block (`<tool_call>...</tool_call>` fallback for GGUFs without native template support), stripping spoofed tags from user input/external content. Track `intent_provenance` (`EXPLICIT_USER`, `COMPANION_SUGGESTED`, `APPROVED_ROUTINE`, `SYSTEM_RECOVERY`, `EXTERNAL_CONTENT`).
     - **Stage 2 (Typed Request):** Validate arguments via Pydantic (`extra="forbid"`); reject unknown/malformed intents immediately and record redacted audit entry (`DENIED`).
     - **Stage 3 (Deterministic Policy):** Outside LLM context:
       - If `ToolRuntimeConfig.global_kill_switch` is `True` -> `DENY` (`reason="KILL_SWITCH_ACTIVE"`).
       - If `intent_provenance == "EXTERNAL_CONTENT"` -> `DENY` unconditionally for any tool.
       - If Risk 3 -> `DENY` permanently.
       - Check `ProfileToolSettings` policy for Risk 0 / Risk 1 (`explicit` vs `suggested`) / Risk 2 -> resolve `ALLOW`, `CONFIRM`, or `DENY`.
       - Issue fingerprint-bound `ToolConfirmation` when outcome is `CONFIRM`: `fingerprint = sha256(canonical_json({profile_id, session_id, conversation_id, tool_name, arguments, expires_at}))`, default `TTL = 120s`, persisted with `status='pending'`.
     - **Stage 4 & 5 (Narrow Adapters + Audit + Conversational Confirmation):**
       - Execute approved Risk 0/1 adapters inside authenticated `session.profile_id` scope; record redacted `ToolAuditLog` row (metadata + source domains + duration + outcome, never raw prompts/secrets/bodies).
       - In `orchestrate_chat_stream` before invoking the LLM for a new turn: check if the conversation has **exactly one** unexpired pending `ToolConfirmation` **and** the user text is an explicit unambiguous confirmation (`confirm <tool_or_target>` / `approve <tool_or_target>`, rejecting vague `"yes"` / `"ok"`); if matched, resolve & execute deterministically first, persist confirmation receipt on the turn, and prevent ambiguity.
       - Bound tool execution inside a single user turn to `MAX_TOOL_ROUNDS = 3` and at most `4` tool calls per round; on completion/regeneration (`D-SHARED-CONV-03A`), store committed `tool_receipts` and `sources` inside `messages.metadata_json` so turn regeneration reads receipts as historical context without re-executing Risk 1/2 adapters.
  3. **SSRF-Safe Read-Only Web Info Subsystem (`backend/app/services/web/`):**
     - `ssrf_guard.py`: Enforces `http`/`https` only; rejects URLs with embedded credentials (`user:pass@`), invalid ports if disallowed, or non-global IPs. Resolves DNS with `socket.getaddrinfo`, checks every resolved address (`is_loopback`, `is_private`, `is_link_local`, `is_multicast`, `is_reserved`, `is_unspecified`, explicit `169.254.169.254` and `100.64.0.0/10`), pins the validated IP on connection (with `Host` header + SNI `server_hostname` preserved), disables auto-redirects, and re-validates every `3xx` hop (`max_hops=5`). Enforces `10.0s` timeout and `2 MiB` raw download cap.
     - Optional **SearXNG LAN exception**: Only when Host Admin explicitly sets `web_search_provider='searxng'` with a configured `searxng_base_url`, search API calls go solely to that configured origin (`fetch` still strictly blocks all loopback/private/link-local targets!).
     - `sanitizer.py`: Strips `<script>`, `<style>`, `<form>`, `<iframe>`, `<noscript>`, `<svg>`, HTML comments, and hidden elements using stdlib `HTMLParser`; extracts bounded Markdown/plain text (`<= 6000` chars) enclosed in `<untrusted_web_content url="..." domain="...">...</untrusted_web_content>` inside LLM tool results.
     - `providers.py` + `web_secret_store.py`: Weather defaults to Open-Meteo (zero-key); Web Search defaults to zero-key public HTML search (DuckDuckGo HTML) with Host Admin options for SearXNG URL or Tavily/Brave (`api_key` stored in ACL-protected Windows DPAPI/private secret file under `%LOCALAPPDATA%\AICompanion\secrets\web_search_api.secret` matching `host_admin.py` pattern, overridable via `COMPANION_WEB_SEARCH_SECRET_FILE` for tests).
  4. **Flutter Desktop Integration (`M4 Batch A`):**
     - `companion_api`: New `tools_dto.dart`, updated `message_dto.dart` (`toolReceipts`, `sources`, `pendingConfirmations` defaulting empty), updated `sse_event_dto.dart` & `sse_parser.dart`, new `CompanionClient` endpoints (`getToolCatalog`, `getToolPolicy`, `updateToolPolicy`, `getKillSwitch`, `setKillSwitch`, `updateWebConfig`, `clearWebApiKey`, `listToolAuditLogs`, `listToolConfirmations`, `resolveToolConfirmation`).
     - `DesktopToolPolicyController`: Owns Kill Switch state, Profile policy state, Web config state (non-secret), and audit logs; clears profile-scoped state on disconnect/profile switch.
     - `DesktopShell` & `DesktopLifecycleCoordinator`: Add interactive Global Kill Switch chip in top utility strip (always visible across screens even when Schedule is not mounted cleanly) + System Tray menu item (*"Emergency: Stop All Tools (Kill Switch)"*) synced to controller state.
     - `ChatScreen` & `DesktopChatController`: Render live Risk 0 execution chips during SSE streaming, collapsible **Sources** links strip on assistant bubbles, and inline **Risk 2 Confirmation Cards** (`Approve & Execute` / `Reject` buttons, expiry timer, provenance + parameter preview, disabled automatically when Kill Switch is active).
     - `SettingsToolsSection`: Replace `PLANNED • M4` placeholder on `SettingsSectionId.tools` with interactive Global Kill Switch toggle, Risk 0/1/2 policy dropdowns, locked `Risk 3 REJECTED` card, Weather/Search provider config (Host Admin secret write), and Redacted Audit Log viewer.

- **Contract & Schema Impact:**
  - **Database Migration (`017_d9_tool_policy_and_audit`):**
    - New tables: `tool_runtime_config`, `profile_tool_settings`, `tool_confirmations`, `tool_audit_logs`.
    - Altered table: `messages` adds nullable `metadata_json` (`Text`).
    - Clean `downgrade()` back to `016_reminder_center_popup`.
  - **OpenAPI Routes (`/api/v1/tools/*`) & Schemas:** Added via `tools.py` router and extended `MessageOut`; regenerated cleanly via `python scripts/check_openapi_contract.py --write` and mapped in `scripts/check_dart_openapi_parity.py`.

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/app/models/tool_runtime_config.py`, `profile_tool_settings.py`, `tool_confirmation.py`, `tool_audit_log.py`
- **Primary Responsibility:** Persistent SQLAlchemy ORM models for host-level Global Kill Switch + Web provider config (non-secret), Profile-scoped D9 Risk 0–2 policies, fingerprint-bound confirmation requests, and redacted metadata-only audit entries.
- **Planned Change:** Create ORM models adhering to `Base`, `TimestampMixin`, `UUIDPrimaryKeyMixin`, `ProfileMixin`, CheckConstraints on allowed policy/decision/risk values (`risk_tier BETWEEN 0 AND 2`), and register in `backend/app/models/__init__.py`.
- **Invariants to Preserve:** No raw API keys, prompts, or message payloads persisted in config or audit tables; `profile_id` FK cascades safely on purge.

### [MODIFY] `backend/app/models/message.py`, `backend/app/schemas/message.py`, `backend/migrations/versions/017_d9_tool_policy_and_audit.py`
- **Primary Responsibility:** Persist committed `tool_receipts` and `sources` per assistant turn for reconnect catch-up and `D-SHARED-CONV-03A` non-replay.
- **Planned Change:** Add nullable `metadata_json: Mapped[Optional[str]]` to `Message`; expose `tool_receipts`, `sources`, and `pending_confirmations` (with `default_factory=list`) on `MessageOut` via serialization helper in `conversations.py` / `orchestrator.py`; write reversible migration `017`.
- **Invariants to Preserve:** Existing messages with `NULL` `metadata_json` serialize cleanly with empty lists `[]` and zero breaking changes for Web/mobile consumers.

### [ADD] `backend/app/services/web/ssrf_guard.py`, `sanitizer.py`, `providers.py`
- **Primary Responsibility:** Fail-closed outbound HTTP containment, untrusted HTML cleaning, and read-only Weather (`Open-Meteo`) / Search (`DuckDuckGo HTML`, optional `SearXNG`, optional BYO `Tavily`/`Brave`) adapters.
- **Planned Change:** Implement DNS resolution pinning, private/loopback/link-local/CGNAT/metadata IP blocking, manual per-hop redirect revalidation, `10s` / `2 MiB` caps, stdlib `HTMLParser` text/Markdown sanitizer with `<untrusted_web_content>` tags, and normalized `WebSourceRef` + `WeatherSummary` outputs.
- **Invariants to Preserve:** No implicit Cloud LLM calls; zero access to loopback/private host services from `web_fetch`.

### [ADD] `backend/app/services/tools/registry.py`, `policy.py`, `executor.py`, `adapters_productivity.py`, `audit.py`, `web_secret_store.py`
- **Primary Responsibility:** D9 typed tool schemas, deterministic policy evaluator, fingerprint confirmation generator/resolver, Profile-scoped narrow Task/Reminder/Alarm/Memory adapters reusing existing DB models/services, redacted audit recorder, and ACL-protected search API key store.
- **Planned Change:** Extract shared task/reminder/alarm create/delete helpers from `tasks.py`/`scheduling.py` where needed so REST routes and tool adapters share one code path. Enforce permanent Risk 3 rejection, `EXTERNAL_CONTENT` zero-authority guard, unambiguous conversational confirmation check, and `Kill Switch` gating.
- **Invariants to Preserve:** Strict `profile_id == session.profile_id` ownership on every adapter; confirmation fingerprint invalidation if parameters, profile, session, or expiry change.

### [MODIFY] `backend/app/services/llm/base.py`, `llama_cpp.py`, `mock.py` & `backend/app/services/assistant/orchestrator.py`
- **Primary Responsibility:** Structured tool call plumbing inside generation streams and bounded orchestrator tool loop.
- **Planned Change:** Support optional `tools` arg + parsed `tool_calls` on `BaseLLMProvider` / `LlamaCppProvider` / `MockLLMProvider`; integrate bounded tool loop (`MAX_TOOL_ROUNDS = 3`) in `orchestrate_chat_stream`, emit `tool_intent`, `tool_result`, and `tool_confirmation_required` SSE frames, handle `tool_receipts` injection on regeneration without re-execution, and isolate background extraction/compaction turns from tools.
- **Invariants to Preserve:** Conversation lock integrity, active profile-session cancellation checks (`_authorized_tokens`), stream degeneracy guard, and SSE `[DONE]` / `done` frame semantics.

### [MODIFY] `backend/app/services/profile_purge_service.py` & `backend/app/api/v1/endpoints/tools.py` & `router.py`
- **Primary Responsibility:** Authenticated `/api/v1/tools/*` API surface and clean Profile deletion cascade.
- **Planned Change:** Mount `tools_router` in `api_v1_router` with explicit per-endpoint Profile Session vs `require_host_admin` checks; delete `tool_audit_logs`, `tool_confirmations`, and `profile_tool_settings` in `ProfilePurgeService.purge_profile`.
- **Invariants to Preserve:** Fail-closed auth boundaries; browser/remote tokens cannot disable the Host Kill Switch or configure local search API keys.

### [MODIFY] `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `frontend/flutter/packages/companion_api/`
- **Primary Responsibility:** Exact OpenAPI 3.1 contract + Dart SDK parity.
- **Planned Change:** Regenerate `openapi.json`, add `tools_dto.dart`, extend `message_dto.dart` & `sse_event_dto.dart` & `sse_parser.dart`, add `CompanionClient` tool/policy/kill-switch/audit/confirmation methods, and enforce parity in `check_dart_openapi_parity.py`.
- **Invariants to Preserve:** Zero schema/route drift; fail-closed parsing for malformed/unknown SSE frames.

### [ADD / MODIFY] Flutter Desktop UI (`desktop_tool_policy_controller.dart`, `desktop_shell.dart`, `desktop_lifecycle_coordinator.dart`, `chat_screen.dart`, `desktop_chat_controller.dart`, `settings_tools_section.dart`, `settings_section.dart`, `settings_screen.dart`)
- **Primary Responsibility:** User-visible D9 Kill Switch (top bar + tray + Settings), interactive Chat Confirmation Cards & Web Source chips, and `Settings -> Tools & Safety` policy/provider/audit management.
- **Planned Change:** Build `DesktopToolPolicyController`; wire Global Kill Switch pill in `DesktopShell` top utility strip + tray menu; render Risk 0 receipts, collapsible source provenance cards, and inline Risk 2 `Approve` / `Reject` confirmation cards inside `ChatScreen`; replace `SettingsSectionId.tools` placeholder with `SettingsToolsSection` (`status: available`); update `desktop_settings_revamp_test.dart`.
- **Invariants to Preserve:** Responsive layout across `1024x640` at `1.3x` text scale; Profile isolation clearing cached tool/audit state on switch/logout; zero duplication of Voice Batch B/C features.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Backend Migration, Models & SSRF/Sanitizer Unit Tests (RED -> GREEN -> REFACTOR):**
   - Write migration test (`test_migration_017.py`) + SSRF guard security tests (loopback, IPv4/IPv6 private ranges, CGNAT, metadata `169.254.169.254`, DNS rebinding mock, unsafe schemes `file://`/`ftp://`/`data:`, redirect-hop escalation, `> 2 MiB` truncation) + HTML sanitizer tests (`<script>`/`<form>`/`<iframe>` stripping + `<untrusted_web_content>` wrapping).
   - Implement Migration `017`, ORM models, `ProfilePurgeService` cascade update, `ssrf_guard.py`, `sanitizer.py`, and `providers.py` (with mocked HTTP fixtures — zero live network required in CI).
2. **D9 Policy Engine, Fingerprint Confirmations, Narrow Adapters & Audit Tests (RED -> GREEN -> REFACTOR):**
   - Write policy matrix & security tests (`DEFAULT DENY`, Kill Switch persistence across DB session reload, Risk 3 permanent block, `EXTERNAL_CONTENT` block, parameter/session/expiry/profile mismatch confirmation rejection, unambiguous vs ambiguous `"yes"` conversational confirmation rejection, cross-profile BOLA tests on adapters, redacted audit assertions).
   - Implement `registry.py`, `policy.py`, `executor.py`, `adapters_productivity.py`, `audit.py`, `web_secret_store.py`, and `/api/v1/tools/*` router with explicit Host Admin boundaries.
3. **LLM Tool-Call Plumbing, Bounded Orchestrator Loop & Turn Non-Replay Tests (RED -> GREEN -> REFACTOR):**
   - Write orchestrator integration tests using `MockLLMProvider` for Risk 0 auto-exec + provenance persistence, Risk 2 `CONFIRM` SSE emission + confirm resolution + audit write, `MAX_TOOL_ROUNDS = 3` cap, Kill Switch live halt, and `D-SHARED-CONV-03A` regeneration without re-running committed Risk 1/2 actions.
   - Implement `LlamaCppProvider` / `MockLLMProvider` / `orchestrator.py` tool loop and `MessageOut` enrichment.
4. **OpenAPI Contract & `companion_api` Dart SDK Parity:**
   - Regenerate `contracts/openapi/openapi.json`, implement Dart DTOs + `SseStreamParser` variants + `CompanionClient` methods + unit tests, update `scripts/check_dart_openapi_parity.py`, and run strict parity checks.
5. **Flutter Desktop UI, Shell Kill Switch, Chat Cards & `SettingsToolsSection` (RED -> GREEN -> REFACTOR):**
   - Write Flutter unit/widget tests for `DesktopToolPolicyController`, `DesktopShell` Kill Switch pill, `ChatScreen` confirmation cards (`Approve`/`Reject` + Kill Switch disable) & collapsible Web sources, and `SettingsToolsSection` policy toggles + audit log viewer; update `desktop_settings_revamp_test.dart`.
   - Implement Desktop controllers, UI components, and Tray Kill Switch action cleanly.
6. **Phase 3 Documentation, Tracking & Draft PR:**
   - Sync canonical docs (`tool-permissions-and-actions.md`, `web-current-information.md`, `privacy-retention-and-audit.md`, `assistant-and-conversations.md`, `01_PC_Desktop_Shell_and_Tray.md`), master spine (`DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`), `CHANGELOG.md`, technical walkthrough (`docs/03_Walkthroughs/`), archive branch tracker, verify markdown links, push, and open draft PR against `develop`.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Backend test suite: `venv\Scripts\python.exe -m pytest backend\tests` (all existing + new migration `017`, SSRF/sanitizer, D9 policy/security, orchestrator loop, audit redaction, Host Admin auth, and purge cascade tests passing).
- [ ] Dependency lock & OpenAPI/Dart parity: `venv\Scripts\python.exe scripts\python_dependency_lock.py --check`, `venv\Scripts\python.exe scripts\check_openapi_contract.py --check`, `venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check`.
- [ ] `companion_api` package tests & analysis: `cd frontend\flutter\packages\companion_api && dart analyze && dart test`.
- [ ] Flutter Desktop analysis, tests & Windows build: `cd frontend\flutter\apps\desktop && flutter analyze --no-pub && flutter test --no-pub && flutter build windows --debug --no-pub`.
- [ ] Web harness regression safety (unbroken contract): `cd frontend\web && npm run lint && npm test -- --run`.

### Manual & Host-Level Checks (Where Applicable)
- [ ] Launch Local AI Runtime + Flutter Desktop (`Qwen3-VL 4B Instruct` loaded): verify live Risk 0 Weather (`Open-Meteo`) + WebSearch citation chips in `ChatScreen`.
- [ ] Verify Risk 2 inline Confirmation Card (`delete_task`), confirm parameter/expiry fidelity, test Reject vs Approve, verify Global Kill Switch blocks tools in Top Strip & Tray, restart Runtime, and confirm Kill Switch state persists cleanly.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *Small local GGUFs inconsistently emit OpenAI `tool_calls` vs JSON text:* Mitigate by supporting both native OpenAI `tools`/`delta.tool_calls` parsing in `LlamaCppProvider` and a bounded, strictly typed Pydantic JSON intent fallback — never trusting prose-only claims without adapter confirmation.
  - *DNS rebinding or redirect SSRF bypasses:* Mitigate via upfront DNS validation, IP-pinned HTTP transport, disabled auto-redirects, and per-hop IP revalidation in `ssrf_guard.py`.
  - *External web search provider HTML layout changes (DuckDuckGo):* Keep `WebSearch` adapter behind an abstract interface with graceful structured unavailable/rate-limit diagnostics plus optional self-hosted `SearXNG` URL and local BYO key support.
  - *Cross-profile leakage of confirmations or secrets:* Enforce `session.profile_id` matching in confirmation resolution, bind confirmation fingerprints to `profile_id + session_id + args + expiry`, purge D9 tables on profile deletion, and store optional Search API keys strictly in Host Admin ACL secret storage.
- **Dependencies & Assumptions:**
  - Zero new Python or Flutter third-party dependencies needed in Batch A (`httpx` + Python stdlib + existing Flutter workspace packages).
  - Real `llama-server.exe` + local Qwen3-VL model used for manual host verification; mocked `httpx` / `MockLLMProvider` used for deterministic CI tests.
- **Required Permissions:** Task-bounded feature branch `feature/m4-d9-tools-and-web-a`, commits, push to `origin/feature/m4-d9-tools-and-web-a`, and Phase 3 draft PR against `develop` (Human Owner exclusively executes final squash merge).
- **Genuine Stop Conditions:**
  - Any request to weaken `DEFAULT DENY`, enable Risk 3 shell/filesystem execution, bypass Host Admin bounds for disabling the Kill Switch / storing API keys, or pull Voice Batch B/C audio engines into Batch A.
  - Any unresolvable `requirements.lock`, OpenAPI parity, or upstream `llama-server` tool-call incompatibility requiring architectural revision.
