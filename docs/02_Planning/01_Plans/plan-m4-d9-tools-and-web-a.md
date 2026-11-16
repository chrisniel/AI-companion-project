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
  - `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, & `scripts/tests/test_check_dart_openapi_parity.py`
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
  - **No `regenerate` Route Invented in Batch A:** Regeneration endpoint/UI does not yet exist in `conversations.py` or `desktop_chat_controller.dart` and is not added here; Batch A satisfies `D-SHARED-CONV-03A` at the orchestrator/persistence boundary as specified in Section 2.
  - **Python Dependency Changes:** No new entries in `pyproject.toml` / `requirements.txt` / `requirements.lock` (uses stdlib `html.parser`, `ipaddress`, `socket`, `hmac`, `hashlib`, and already-locked `httpx`).

---

## 2. Architecture & Technical Approach

- **Current Findings & Technical Baseline:**

  | Observation / Evidence | Verified Interpretation |
  | --- | --- |
  | `backend/app/services/llm/llama_cpp.py` (`lines 47-78`, `1168-1299`) accepts `finish_reason == "tool_calls"` in `_decode_stream_event` (also carrying stale annotation `-> tuple[str, bool]`), but ignores `delta.tool_calls` and omits `tools` from payloads. | `LlamaCppProvider` and `BaseLLMProvider`/`GenerationStream` need non-breaking optional `tools` support, delta accumulation by `tool_call` index across Route A (`llama-server`) and Route B (`llama-cpp-python`), clean 3-tuple typing, and `<tool_call>` fallback buffering. |
  | `backend/app/api/v1/router.py` mounts `protected_router` (`get_current_profile_session`), `system_router` (`require_host_admin`), and mixed-authority routers directly on `api_v1_router` (`profiles_router`, `llm_router`). `CompanionClient` (`companion_client.dart:28-73`) injects `X-Host-Admin-Secret` when `hostAdminStore` is supplied and on loopback. | Mounting `tools_router` directly on `api_v1_router` with explicit per-endpoint `Depends(get_current_profile_session)` vs `Depends(require_host_admin)` allows Profile Sessions to read policy/audit/confirmations or engage emergency Kill Switch (`enabled=true`), while restricting `enabled=false` and Web provider/secret writes strictly to native Host Admin. |
  | `backend/app/services/profile_purge_service.py` (`lines 24-38`, `267-287`) deletes profile-owned child entities explicitly in FK order before deleting `Profile`; current Alembic head is `016_reminder_center_popup`. | Migration `017` and `ProfilePurgeService` must delete `tool_audit_logs`, `tool_confirmations`, and `profile_tool_settings` before `Message`/`Conversation`/`ProfileSession`/`Profile` (avoiding `RESTRICT` FK on `session_id`) so `PRAGMA foreign_keys = ON` purges succeed cleanly. |
  | `backend/app/api/v1/endpoints/tasks.py` and `scheduling.py` enforce ownership, reminder/alarm sync, and `bypass_quiet_hours` defaults; `backend/app/core/host_admin.py` + `windows_security.py` provide Windows SID ACL + reparse-path secret storage, and `test_import_isolation.py` forbids import-time file/socket I/O. | Reusing shared helpers in tasks/scheduling/memory adapters prevents duplicated logic, deterministic quiet-hours evaluation in `policy.py` follows `Profile.quiet_hours_*` + `bypass_quiet_hours`, and `web_secret_store.py` performs lazy ACL-checked file reads/writes only at request time. |
  | `scripts/python_dependency_lock.py` enforces strict wheel closure (`python_dependency_lock.py verify`), and `scripts/check_dart_openapi_parity.py:293` parses Dart DTO types using single-token `[A-Za-z0-9_<>?]+` (no commas/spaces), while `scripts/tests/test_check_dart_openapi_parity.py:84` asserts exact verified route count (`83`). | Implementing SSRF containment (`ipaddress`, `socket`), HTML-to-Markdown extraction (`html.parser`), and HTTP (`httpx`) keeps `requirements.lock` untouched; `tools_dto.dart` uses strongly typed nested DTOs (zero `Map<String, dynamic>`), and `test_check_dart_openapi_parity.py` updates the expected route count cleanly. |
  | `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` (`lines 489-499, 684-688`) gates `_buildTopUtilityStrip` on `_scheduleController != null`, `settings_screen.dart` maps `SettingsSectionId.tools` to `SettingsPlannedSection`, and `desktop_settings_revamp_test.dart` (`lines 51-53, 298-303`) asserts `tools.status == planned` and standalone `'D9 action policy'` text. | Decoupling `_buildTopUtilityStrip` to render when `_scheduleController != null || _toolPolicyController != null`, supporting nullable `toolPolicyController` in `SettingsToolsSection` and `DesktopShell`, wiring `hostAdminStore` cleanly (degrading gracefully in non-Host-Admin test harnesses), and updating both test regions in `desktop_settings_revamp_test.dart` prevents UI & test regressions. |
  | `companion_api/lib/dto/sse_event_dto.dart` (`SseEvent` sealed class) and `sse_parser.dart` (`lines 53-80`) parse `token`, `done`, and `error` frames. | Adding `SseToolIntentEvent`, `SseToolResultEvent`, and `SseToolConfirmationRequiredEvent` (with unknown-event fallback) delivers live tool telemetry cleanly; Phase 3 will sync `assistant-and-conversations.md` §2.2 SSE event list accordingly. |

- **Architectural Approach:**
  1. **Typed Tool Catalog & Strict Validation (`backend/app/services/tools/registry.py`):**
     - Define immutable `ToolSpec` definitions with risk tier (`0`, `1`, `2`), JSON Schema parameters for LLM tool-calling, strict Pydantic v2 `BaseModel` (`ConfigDict(extra="forbid")`), domain tag, and adapter handler:
       - **Risk 0 (`ALLOW` default when enabled):** `weather_lookup`, `web_search`, `web_fetch`, `list_tasks`, `list_reminders`, `list_alarms`, `search_memories`.
       - **Risk 1 (explicit `ALLOW` / companion-suggested `CONFIRM` by default):** `create_task`, `update_task` *(note: `TaskUpdate` has no `is_deleted`; setting `status='cancelled'` cancels linked reminders cleanly while `delete_task` soft-delete remains Risk 2)*, `create_reminder`, `create_alarm`.
       - **Risk 2 (`CONFIRM` default):** `delete_task` *(soft-delete to 30-day trash only — `permanent_delete_task` is excluded from assistant tools)*, `delete_reminder`, `delete_alarm`.
       - **Risk 3 (`REJECTED` permanently):** Explicit `PROHIBITED_TOOL_NAMES` guard rejecting any `shell`, `bash`, `powershell`, `cmd`, `exec`, `eval`, `filesystem_*`, or `credential_*` intent unconditionally (`DEFAULT DENY`).
  2. **5-Stage Deterministic Policy, Quiet-Hours Gate, Atomic Confirmations & Orchestrator Loop (`policy.py`, `executor.py`, `audit.py`, `llama_cpp.py`, `orchestrator.py`):**
     - **Stage 1 (Model Intent Normalization & Stream Buffering):** Extend `GenerationStream` / `LlamaCppProvider` (`_decode_stream_event` returning fixed 3-tuple + accumulating `delta.tool_calls` chunks by `index` in `stream_meta["tool_calls"]` for Route A `llama-server` and Route B `llama-cpp-python`). For local GGUFs without native OpenAI `tool_calls`, run a small stream prefix buffer in `_stream_guarded_sse_pass` when tools are enabled so `<tool_call>...</tool_call>` fallback tags are intercepted before emitting user-visible SSE `token` frames; strip any user-injected `<tool_call>` tags during prompt sanitization. Tag every intent with `intent_provenance` (`EXPLICIT_USER`, `COMPANION_SUGGESTED`, `APPROVED_ROUTINE`, `SYSTEM_RECOVERY`, `EXTERNAL_CONTENT`).
     - **Stage 2 (Typed Request):** Validate arguments via Pydantic (`extra="forbid"`); reject unknown/malformed intents immediately and record redacted audit entry (`DENIED`).
     - **Stage 3 (Deterministic Policy + Quiet Hours Gate):** Evaluated strictly outside LLM context:
       - If `ToolRuntimeConfig.global_kill_switch` is `True` -> `DENY` (`reason="KILL_SWITCH_ACTIVE"`).
       - If `intent_provenance == "EXTERNAL_CONTENT"` -> `DENY` unconditionally for any tool.
       - If Risk 3 -> `DENY` permanently.
       - **Scheduling Quiet-Hours Check (`tool-permissions-and-actions.md` §2.1):** For scheduling/notification domain mutations (`create_reminder`, `create_alarm`), deterministically evaluate `Profile.quiet_hours_*` via `SchedulerService` timezone/window rules. Force `CONFIRM` if an agent-proposed silent reminder would bypass quiet hours (`bypass_quiet_hours=True`) or trigger immediately inside active quiet hours unless explicitly authorized by user intent; `create_alarm` preserves D10 alarm default bypass (`bypass_quiet_hours=True`) with quiet-hours status surfaced cleanly in tool receipts.
       - Evaluate `ProfileToolSettings` policy for Risk 0 / Risk 1 (`explicit` vs `suggested`) / Risk 2 -> resolve `ALLOW`, `CONFIRM`, or `DENY`.
       - When outcome is `CONFIRM`, persist `ToolConfirmation` bound to authenticated `ProfileSession.id` with `fingerprint = sha256(canonical_json({profile_id, session_id: profile_session.id, conversation_id, tool_name, arguments, expires_at}))`, `TTL = 120s`, and `status='pending'`.
     - **Stage 4 & 5 (Atomic Confirmation Claim, Narrow Adapters, Audit & Non-Replay):**
       - Execute approved Risk 0/1 adapters inside authenticated `session.profile_id` scope; record redacted `ToolAuditLog` row (metadata + source domains + duration + outcome, never raw prompts/secrets/bodies).
       - **Atomic Confirmation Resolution (No Double-Execution Race):** Both `POST /api/v1/tools/confirmations/{id}/resolve` and conversational confirmation execute an atomic SQL conditional transition (`UPDATE tool_confirmations SET status='approved', resolved_at=:now WHERE id=:id AND profile_id=:pid AND session_id=:sid AND status='pending' AND expires_at > :now`), verify `rowcount == 1`, verify Kill Switch OFF + computed SHA-256 fingerprint match, execute the narrow adapter once, and transition to `'executed'` (or `'failed'`) while logging audit metadata.
       - **Conversational Confirmation Flow (`conversations.py` / `orchestrator.py`):** In `orchestrate_chat_stream` before LLM invocation (and ensuring model-readiness checks don't silently drop a deterministic confirmation request), inspect active unexpired pending `ToolConfirmation` rows for `(conversation_id, profile_id, profile_session.id)`. If **exactly one** exists and `user_text` matches an unambiguous confirmation phrase naming the `tool_name` or primary target title (rejecting bare `"yes"` / `"ok"` / `"sure"`), atomically resolve and execute it first, persist the confirmed receipt onto `asst_msg.metadata_json`, and emit `tool_result` + confirmation summary cleanly.
       - **Bounded Multi-Step Loop & `D-SHARED-CONV-03` / `D-SHARED-CONV-03A`:** Limit execution to `MAX_TOOL_ROUNDS = 3` and max `4` calls per round; omit `tools` on 1-hop length auto-continuation (`orchestrator.py:901-936`) and background memory extraction/compaction turns; persist accumulated `tool_receipts` and `sources` into `asst_msg.metadata_json` **both** after each committed tool round and inside `_persist_terminal_assistant_status` on cancellation/failure so committed side effects survive interrupts and future prompt context sees historical receipts without re-running Risk 1/2 adapters. `MessageOut.pending_confirmations` is populated dynamically from live unexpired `pending` `ToolConfirmation` rows for that conversation rather than static JSON.
  3. **SSRF-Safe Read-Only Web Info Subsystem (`backend/app/services/web/`):**
     - `ssrf_guard.py`: Enforces `http`/`https` only; rejects URLs with embedded credentials (`user:pass@`), non-standard ports outside `80/443` for generic `web_fetch`, and non-global IPs. Resolves DNS with `socket.getaddrinfo`, **unwraps IPv4-mapped IPv6 addresses (`ip.ipv4_mapped`) before IPv4 checks**, blocks all non-global addresses (`is_loopback`, `is_private`, `is_link_local`, `is_multicast`, `is_reserved`, `is_unspecified`, explicit `169.254.169.254`, `100.64.0.0/10` CGNAT, `fc00::/7`, `fe80::/10`), pins the validated target IP cleanly using `httpx.AsyncHTTPTransport` + `request.extensions["sni_hostname"]` for TLS SNI/certificate hostname verification, disables auto-redirects (`follow_redirects=False`), re-validates every `3xx` `Location` (`max_hops=5`), and enforces `10.0s` timeout + `2 MiB` streaming byte cap.
     - **Host-Admin SearXNG Exception:** Only Host Admin (`require_host_admin`) can set `searxng_base_url` (`http`/`https`, zero embedded credentials); requests strictly set `follow_redirects=False` and still block cloud metadata (`169.254.169.254`), link-local (`169.254.0.0/16`, `fe80::/10`), multicast, reserved, and unspecified IPs while permitting explicit localhost/LAN SearXNG origin only, whereas `web_fetch` on returned search result URLs always runs strict public-only SSRF blocking.
     - `sanitizer.py`: Strips `<script>`, `<style>`, `<form>`, `<iframe>`, `<noscript>`, `<svg>`, HTML comments, and hidden elements using stdlib `HTMLParser`; extracts bounded Markdown/plain text (`<= 6000` chars) enclosed in `<untrusted_web_content url="..." domain="...">...</untrusted_web_content>` inside LLM tool results.
     - `providers.py` + `web_secret_store.py`: Weather defaults to Open-Meteo (zero-key); Web Search defaults to zero-key public HTML search (DuckDuckGo HTML) with Host Admin options for SearXNG URL or Tavily/Brave (`api_key` stored lazily via `windows_security.py` SID DACL + reparse rejection under `%LOCALAPPDATA%\AICompanion\secrets\web_search_api.secret`, overridable via `COMPANION_WEB_SEARCH_SECRET_FILE`, zero import-time I/O).
  4. **Flutter Desktop Integration (`M4 Batch A`):**
     - `companion_api`: New typed `tools_dto.dart` (strict single-token field types — zero `Map<String, dynamic>` properties so `check_dart_openapi_parity.py` parses cleanly), updated `message_dto.dart` (`toolReceipts`, `sources`, `pendingConfirmations` defaulting empty), updated `sse_event_dto.dart` & `sse_parser.dart`, new `CompanionClient` endpoints (`getToolCatalog`, `getToolPolicy`, `updateToolPolicy`, `getKillSwitch`, `setKillSwitch`, `updateWebConfig`, `clearWebApiKey`, `listToolAuditLogs`, `listToolConfirmations`, `resolveToolConfirmation`).
     - `DesktopToolPolicyController`: Owns Kill Switch state, Profile policy state, Web config state (`hasHostAdminAuthority` checked cleanly without throwing unhandled `StateError` when `hostAdminStore == null` in standalone tests or remote contexts), and audit logs; clears profile-scoped state on disconnect or `_handleProfileChange()`. Passes `hostAdminStore` cleanly if `DesktopChatController` reconstructs clients.
     - `DesktopShell` & `DesktopLifecycleCoordinator`: Decouple `_buildTopUtilityStrip` (`scheduleController` made nullable; rendered whenever `_scheduleController != null || _toolPolicyController != null`) with interactive Global Kill Switch chip always visible across screens, plus optional named Kill Switch properties on `DesktopLifecycleCoordinator` preserving existing `buildTrayMenuItems` positional test signatures.
     - `ChatScreen` & `DesktopChatController`: Render live Risk 0 execution chips during SSE streaming, collapsible **Sources** links strip on assistant bubbles, and inline **Risk 2 Confirmation Cards** (`Approve & Execute` / `Reject` buttons, expiry timer, provenance + parameter preview, disabled automatically when Kill Switch is active).
     - `SettingsToolsSection`: Replace `PLANNED • M4` placeholder on `SettingsSectionId.tools` (`status: available`, `milestoneHint: null`) with standalone fallback when `toolPolicyController == null` and interactive Kill Switch, Risk 0/1/2 dropdowns, locked `Risk 3 REJECTED` card, Weather/Search provider config, and Redacted Audit Log viewer when connected; update `desktop_settings_revamp_test.dart` lines `51-53` and `298-303`.

- **Contract & Schema Impact:**
  - **Database Migration (`017_d9_tool_policy_and_audit`):**
    - New tables: `tool_runtime_config`, `profile_tool_settings`, `tool_confirmations` (with `session_id` plain indexed string, no `RESTRICT` FK on `profile_sessions`), `tool_audit_logs`.
    - Altered table: `messages` adds nullable `metadata_json` (`Text`).
    - Clean `downgrade()` back to `016_reminder_center_popup`.
  - **OpenAPI Routes (`/api/v1/tools/*`) & Schemas:** Added via `tools_router` directly mounted on `api_v1_router` with explicit per-route auth (`get_current_profile_session` vs `require_host_admin` for Kill Switch disengage & Web provider/secret writes) and extended `MessageOut`; regenerated cleanly via `python scripts/check_openapi_contract.py --write` and mapped in `scripts/check_dart_openapi_parity.py` + `scripts/tests/test_check_dart_openapi_parity.py`.

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
- **Invariants to Preserve:** Strict `profile_id == session.profile_id` ownership on every adapter; atomic pending->approved/executed confirmation claim; parameter/profile/session/expiry fingerprint mismatch rejection.

### [MODIFY] `backend/app/services/llm/base.py`, `llama_cpp.py`, `mock.py` & `backend/app/services/assistant/orchestrator.py`
- **Primary Responsibility:** Structured tool call plumbing inside generation streams and bounded orchestrator tool loop.
- **Planned Change:** Support optional `tools` arg, fix `_decode_stream_event` annotation, accumulate `delta.tool_calls` in `GenerationStream.meta` across Route A & B, buffer `<tool_call>` fallback prefixes before streaming user tokens, integrate bounded tool loop (`MAX_TOOL_ROUNDS = 3`) in `orchestrate_chat_stream`, handle unambiguous conversational confirmations, emit `tool_intent`/`tool_result`/`tool_confirmation_required` SSE frames, persist `metadata_json` per committed round + in `_persist_terminal_assistant_status` on cancel/failure, omit tools on continuation/compaction/extraction, and dynamically populate `MessageOut.pending_confirmations`.
- **Invariants to Preserve:** Conversation lock integrity, active profile-session cancellation checks (`_authorized_tokens`), stream degeneracy guard, `D-SHARED-CONV-03A` historical receipt non-replay, and SSE `[DONE]` / `done` frame semantics.

### [MODIFY] `backend/app/services/profile_purge_service.py` & `backend/app/api/v1/endpoints/tools.py` & `router.py`
- **Primary Responsibility:** Authenticated `/api/v1/tools/*` API surface and clean Profile deletion cascade.
- **Planned Change:** Mount `tools_router` directly on `api_v1_router` with explicit per-endpoint `Depends(get_current_profile_session)` vs `Depends(require_host_admin)` (`enabled=True` allowed for Profile Session or Host Admin; `enabled=False` and `/web-config*` require Host Admin); delete `tool_audit_logs`, `tool_confirmations`, and `profile_tool_settings` before `Message`/`Conversation`/`ProfileSession`/`Profile` in `ProfilePurgeService.purge_profile`.
- **Invariants to Preserve:** Fail-closed auth boundaries; browser/remote tokens cannot disable the Host Kill Switch or configure local search API keys.

### [MODIFY] `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`, `frontend/flutter/packages/companion_api/`
- **Primary Responsibility:** Exact OpenAPI 3.1 contract + Dart SDK parity.
- **Planned Change:** Regenerate `openapi.json`, add typed single-token `tools_dto.dart`, extend `message_dto.dart` & `sse_event_dto.dart` & `sse_parser.dart`, add `CompanionClient` tool/policy/kill-switch/audit/confirmation methods, and update `check_dart_openapi_parity.py` + `test_check_dart_openapi_parity.py` (`len(verified)`).
- **Invariants to Preserve:** Zero schema/route drift; fail-closed parsing for malformed/unknown SSE frames.

### [ADD / MODIFY] Flutter Desktop UI (`desktop_tool_policy_controller.dart`, `desktop_shell.dart`, `desktop_lifecycle_coordinator.dart`, `chat_screen.dart`, `desktop_chat_controller.dart`, `settings_tools_section.dart`, `settings_section.dart`, `settings_screen.dart`)
- **Primary Responsibility:** User-visible D9 Kill Switch (top bar + tray + Settings), interactive Chat Confirmation Cards & Web Source chips, and `Settings -> Tools & Safety` policy/provider/audit management.
- **Planned Change:** Build `DesktopToolPolicyController` (graceful when `hostAdminStore == null` in tests); decouple `DesktopShell._buildTopUtilityStrip` from non-null `_scheduleController`, wire Kill Switch + profile-switch cleanup in `_handleProfileChange()`, expose optional Kill Switch properties on `DesktopLifecycleCoordinator` preserving positional test compatibility; render Risk 0 receipts, collapsible sources, and inline Risk 2 confirmation cards in `ChatScreen`; replace `SettingsSectionId.tools` placeholder with `SettingsToolsSection` (`status: available`, nullable controller fallback); update `desktop_settings_revamp_test.dart` (`lines 51-53, 298-303`).
- **Invariants to Preserve:** Responsive layout across `1024x640` at `1.3x` text scale; Profile isolation clearing cached tool/audit state on switch/logout; zero duplication of Voice Batch B/C features.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Backend Migration, Models & SSRF/Sanitizer Unit Tests (RED -> GREEN -> REFACTOR):**
   - Write migration test (`test_migration_017.py`) + SSRF guard security tests (loopback, IPv4-mapped IPv6 `::ffff:127.0.0.1`/`::ffff:100.64.0.1`, private IPv4/IPv6 ranges, CGNAT, metadata `169.254.169.254`, DNS rebinding mock, `sni_hostname` HTTPS IP pinning, unsafe schemes `file://`/`ftp://`/`data:`, redirect-hop escalation, SearXNG non-redirect / Host Admin origin lock, `> 2 MiB` truncation) + HTML sanitizer tests (`<script>`/`<form>`/`<iframe>` stripping + `<untrusted_web_content>` wrapping).
   - Implement Migration `017`, ORM models, `ProfilePurgeService` cascade update, `ssrf_guard.py`, `sanitizer.py`, and `providers.py` (with mocked HTTP fixtures — zero live network required in CI).
2. **D9 Policy Engine, Fingerprint Confirmations, Narrow Adapters & Audit Tests (RED -> GREEN -> REFACTOR):**
   - Write policy matrix & security tests (`DEFAULT DENY`, Kill Switch persistence across DB session reload, Risk 3 permanent block, `EXTERNAL_CONTENT` block, scheduling quiet-hours policy gating, atomic single-winner confirmation concurrency test + parameter/`ProfileSession.id`/expiry/profile mismatch rejection, unambiguous vs ambiguous `"yes"` conversational confirmation rejection, cross-profile BOLA tests on adapters, redacted audit assertions, `test_import_isolation.py` lazy secret check).
   - Implement `registry.py`, `policy.py`, `executor.py`, `adapters_productivity.py`, `audit.py`, `web_secret_store.py`, and `/api/v1/tools/*` router with explicit Host Admin boundaries.
3. **LLM Tool-Call Plumbing, Bounded Orchestrator Loop & Turn Non-Replay Tests (RED -> GREEN -> REFACTOR):**
   - Write orchestrator integration tests using `MockLLMProvider` + `LlamaCppProvider` `delta.tool_calls` & `<tool_call>` buffer unit tests for Risk 0 auto-exec + provenance persistence, Risk 2 `CONFIRM` SSE emission + confirm resolution + audit write, `MAX_TOOL_ROUNDS = 3` cap, Kill Switch live halt, cancellation mid-Round-2 preserving Round-1 `metadata_json`, and `D-SHARED-CONV-03A` historical receipt injection without re-running committed Risk 1/2 actions.
   - Implement `LlamaCppProvider` / `MockLLMProvider` / `orchestrator.py` tool loop and `MessageOut` enrichment.
4. **OpenAPI Contract & `companion_api` Dart SDK Parity:**
   - Regenerate `contracts/openapi/openapi.json`, implement Dart DTOs + `SseStreamParser` variants + `CompanionClient` methods + unit tests, update `scripts/check_dart_openapi_parity.py` & `scripts/tests/test_check_dart_openapi_parity.py`, and run strict parity checks.
5. **Flutter Desktop UI, Shell Kill Switch, Chat Cards & `SettingsToolsSection` (RED -> GREEN -> REFACTOR):**
   - Write Flutter unit/widget tests for `DesktopToolPolicyController`, `DesktopShell` Kill Switch pill (mounted both with and without `_scheduleController`), `ChatScreen` confirmation cards (`Approve`/`Reject` + Kill Switch disable) & collapsible Web sources, and `SettingsToolsSection` policy toggles + standalone null fallback + audit log viewer; update `desktop_settings_revamp_test.dart`.
   - Implement Desktop controllers, UI components, and Tray Kill Switch action cleanly.
6. **Phase 3 Documentation, Tracking & Draft PR:**
   - Sync canonical docs (`tool-permissions-and-actions.md`, `web-current-information.md`, `privacy-retention-and-audit.md`, `assistant-and-conversations.md` SSE event list, `01_PC_Desktop_Shell_and_Tray.md`), master spine (`DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`), `CHANGELOG.md`, technical walkthrough (`docs/03_Walkthroughs/`), archive branch tracker, verify markdown links, push, and open draft PR against `develop`.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Backend test suite: `venv\Scripts\python.exe -m pytest backend\tests` (all existing + new migration `017`, import isolation, SSRF/sanitizer, D9 policy/security, quiet-hours gate, atomic confirmation, orchestrator loop, audit redaction, Host Admin auth, and purge cascade tests passing).
- [ ] Dependency lock, contract parity suite & OpenAPI/Dart parity: `venv\Scripts\python.exe scripts\python_dependency_lock.py verify`, `venv\Scripts\python.exe -m unittest scripts\tests\test_check_dart_openapi_parity.py`, `venv\Scripts\python.exe scripts\check_openapi_contract.py --check`, `venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check`.
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
