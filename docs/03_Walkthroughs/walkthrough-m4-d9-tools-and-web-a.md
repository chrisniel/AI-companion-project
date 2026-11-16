# Walkthrough: M4 Batch A — D9 Deterministic Action Engine & Read-Only Web Information

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Deliver Milestone M4 Batch A (D9 5-stage deterministic tool execution, hardened SSRF-safe read-only Web & Weather retrieval, persistent Global Tool Kill Switch, redacted audit logging, OpenAPI/`companion_api` SDK parity, and Flutter Desktop Settings + Chat tool UX) on branch `feature/m4-d9-tools-and-web-a`.
- Audience: Maintainers, independent reviewers, security reviewers, and QA engineers.
- Status: Implemented & Automated-Verified on `feature/m4-d9-tools-and-web-a` (Awaiting Phase 4 Review; live external/GUI smoke checks pending).
- Last Updated: 2026-11-16

---

## 1. What Was Delivered

- Implemented Decision D9's 5-stage execution pipeline (`Model -> Typed Request -> Deterministic Policy -> Narrow Adapter -> Capability`) with `DEFAULT DENY`, Risk 0/1/2 typed schemas (`extra="forbid"`), and permanent rejection of Risk 3 capabilities (`arbitrary_shell_execution`, `arbitrary_filesystem_write`, `credential_exfiltration`, `os_security_reconfiguration`).
- Added Alembic Migration `017_d9_tool_policy_and_audit` introducing `tool_runtime_config`, `profile_tool_settings`, `tool_confirmations`, `tool_audit_logs`, and `messages.metadata_json`, plus cascade cleanup inside `ProfilePurgeService.purge_profile`.
- Implemented SSRF containment (`ssrf_guard.py`) with DNS pre-flight resolution checks, IPv6-mapped IPv4 unwrapping, loopback/RFC1918/CGNAT/link-local blocking across initial requests and redirects, TLS `sni_hostname` IP-pinning, 2 MiB streaming cap, and `<untrusted_web_content>` HTML sanitization.
- Added zero-key Open-Meteo Weather (`weather_lookup`), zero-key Public Search (`public_search`), Host-Admin-configurable SearXNG URL, and optional ACL-protected local-file API key storage for Tavily/Brave (`web_secret_store.py`).
- Extended `LlamaCppProvider` and `orchestrator.py` for OpenAI `delta.tool_calls` + `<tool_call>` fallback tag buffering (`MAX_TOOL_ROUNDS = 3`), conversational confirmation gating (blocking vague `"yes"`), progressive `Message.metadata_json` receipts (`D-SHARED-CONV-03A`), and `tools` omission on 1-hop length-continuation.
- Regenerated OpenAPI 3.1, extended `companion_api` (`tools_dto.dart`, `MessageOut`, `SseStreamParser`, `CompanionClient`), updated `check_dart_openapi_parity.py` (`93` covered routes, `78` schemas), promoted `Settings -> Tools & Safety` (`SettingsToolsSection`), added decoupled Global Kill Switch controls in the Desktop Shell top bar & tray, and rendered receipts, collapsible Sources, and Risk 2 confirmation cards in `ChatScreen`.

## 2. Files Changed

- `backend/migrations/versions/017_d9_tool_policy_and_audit.py` — Migration `017` adding D9 tables and `messages.metadata_json`.
- `backend/app/models/tool_runtime_config.py`, `profile_tool_settings.py`, `tool_confirmation.py`, `tool_audit_log.py`, `message.py`, `__init__.py` — D9 ORM entities and assistant turn metadata column.
- `backend/app/services/profile_purge_service.py` — FK-safe deletion of D9 profile settings, confirmations, and audit logs on permanent Profile purge.
- `backend/app/services/web/{__init__.py,ssrf_guard.py,sanitizer.py,providers.py}` — Hardened SSRF transport, `<untrusted_web_content>` sanitizer, and Open-Meteo / Web Search / Web Fetch adapters.
- `backend/app/services/tools/{__init__.py,registry.py,policy.py,audit.py,adapters_productivity.py,executor.py,web_secret_store.py}` — D9 registry, policy evaluator, fingerprint CAS confirmation resolution, redacted audit logger, narrow productivity/memory adapters, and ACL-protected search API key store.
- `backend/app/schemas/tools.py`, `message.py`, `llm.py` & `backend/app/api/v1/endpoints/tools.py`, `conversations.py`, `backend/app/api/v1/router.py` — D9 schemas and `/api/v1/tools/*` control-plane routes plus `MessageOut` deserialization.
- `backend/app/services/llm/{base.py,mock.py,llama_cpp.py}` & `backend/app/services/assistant/orchestrator.py` — Streaming `delta.tool_calls`, `<tool_call>` fallback buffering, bounded loop, and `D-SHARED-CONV-03A` prompt history injection.
- `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py` — Contract regeneration and M4 Batch A parity coverage.
- `frontend/flutter/packages/companion_api/**` — `tools_dto.dart`, `MessageOut` / `SseStreamParser` / `CompanionClient` D9 extensions & unit tests.
- `frontend/flutter/apps/desktop/**` — `DesktopToolPolicyController`, `SettingsToolsSection`, `DesktopShell` decoupled top Kill Switch, `DesktopLifecycleCoordinator` tray Emergency Stop item, `ChatScreen` receipts/sources/confirmations, and updated desktop tests.
- `backend/tests/test_migration_017.py`, `test_web_ssrf_and_sanitizer.py`, `test_d9_tools_and_policy.py`, `test_orchestrator_d9_tools.py`, `test_prepare_database_schema_backup.py`, `test_schema_lifecycle.py` — Full TDD coverage + updated `017` head revision constant.
- Canonical documentation (`docs/04_Architecture/**`, `docs/05_Design/01_PC_Desktop_Shell_and_Tray.md`, `docs/02_Planning/00_Master/**`, `CHANGELOG.md`, archived branch tracker).

## 3. How the Logic Works

1. Event trigger: User submits a prompt in Desktop Chat (or triggers Kill Switch / Policy / Web config UI).
2. Validation: `orchestrate_chat_stream` checks pending confirmations first (`is_unambiguous_confirmation_text` rejects vague `"yes"`). During tool rounds, `TOOL_REGISTRY` validates arguments strictly (`extra="forbid"`) and classifies caller provenance (`EXPLICIT_USER`, `COMPANION_SUGGESTED`, or `EXTERNAL_CONTENT`).
3. Core processing: `evaluate_tool_policy` checks Global Kill Switch, rejects `EXTERNAL_CONTENT` and Risk 3, evaluates Risk 0/1/2 profile policy and Quiet Hours, and either returns `DENY`, mints a session- and SHA-256-fingerprint-bound `ToolConfirmation` (`CONFIRM`), or executes a narrow adapter (`ALLOW`). Outbound web calls pass through `ssrf_guard.py` + `sanitizer.py`.
4. Completion: `execute_tool_intent` logs a redacted row in `tool_audit_logs`, `orchestrator.py` emits SSE `tool_intent`/`tool_confirmation_required`/`tool_result` frames and commits `Message.metadata_json`, and `DesktopChatController` / `ChatScreen` render receipts, collapsible `Sources`, and inline Risk 2 confirmation buttons.
5. Recovery/cancellation: Engaging Global Kill Switch halts all further tool executions immediately and disables inline Approve buttons; disengaging strictly requires loopback Host Admin authority. Mid-round stream cancellation preserves Round 1 `metadata_json` via `_persist_terminal_assistant_status`.

## 4. Key Concepts

- **D9 5-Stage Pipeline:** Generative models only emit intents; schemas, policy, Kill Switch, and narrow adapters remain outside model control.
- **Persistent Global Kill Switch:** Stored in SQLite `tool_runtime_config`; any authenticated session can engage it immediately from top bar, tray, or Settings, while disengaging requires native Host Admin over loopback.
- **`D-SHARED-CONV-03A` Receipts:** Assistant turns record executed action receipts (`tool_receipts`) and `sources` in `messages.metadata_json` so follow-up turns see `[Prior action: ...]` history context without silently re-executing past side effects.

## 5. Verification Steps

### Automated Checks

- [x] `venv\Scripts\python.exe -m pytest backend\tests -q` — `861 passed` (0 failed, 0 skipped, including `test_migration_017.py`, `test_web_ssrf_and_sanitizer.py`, `test_d9_tools_and_policy.py`, `test_orchestrator_d9_tools.py`, `test_import_isolation.py`, `test_prepare_database_schema_backup.py`, `test_schema_lifecycle.py`).
- [x] `venv\Scripts\python.exe scripts\check_openapi_contract.py --check` — Passed (`75` OpenAPI routes up-to-date).
- [x] `venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check` — Passed (`78/78` DTO schemas, `93/93` covered M1–M4A routes).
- [x] `venv\Scripts\python.exe -m unittest scripts/tests/test_check_dart_openapi_parity.py -v` — `8/8` tests passed.
- [x] `dart analyze && dart test` (`frontend/flutter/packages/companion_api`) — `0` issues found; `107/107` tests passed.
- [x] `flutter analyze --no-pub && flutter test --no-pub` (`frontend/flutter/apps/desktop`) — `0` issues found; `409/409` tests passed.
- [x] `flutter build windows --debug --no-pub` (`frontend/flutter/apps/desktop`) — Built `build\windows\x64\runner\Debug\ai_companion_desktop.exe` (`26.7s`).
- [x] `npm run lint && npm test -- --run` (`frontend/web`) — `tsc --noEmit` exit `0`; `16/16` Vitest files / `248/248` tests passed.
- [ ] `venv\Scripts\python.exe scripts\python_dependency_lock.py verify` — Blocked locally on CPython 3.13.14 (`ValueError: Lock requires Windows x64 / CPython 3.11`); `git diff -- backend/requirements.lock backend/requirements.txt backend/pyproject.toml` confirmed empty (CI validates under Python 3.11).

### Manual / User-Owned Checks

- [ ] Step 1: Launch Flutter Desktop (`ai_companion_desktop.exe`) alongside live local LLM runtime with a tool-capable GGUF model.
- [ ] Step 2: Ask a weather/search question, verify live tool status chip + collapsible `Sources` strip, trigger a Risk 2 delete action, verify vague `"yes"` is refused and inline **Approve** executes it once, then engage/disengage the Global Kill Switch via top bar, tray, and `Settings -> Tools & Safety`.
- [ ] Expected result: All D9 gates, source attributions, Host Admin Kill Switch reset, and redacted audit ledger entries operate cleanly end-to-end.

## 6. Safe Customization & Invariants

- Tunable parameters: `MAX_TOOL_ROUNDS = 3`, `CONFIRMATION_TTL_SECONDS = 120`, `Settings -> Tools & Safety` Risk 0/1/2 dropdowns, and Host-Admin Web provider routing (`open_meteo`, `public_search`, `searxng`, `tavily`, `brave`).
- Invariants: Generic Risk 3 shell/filesystem write classes cannot be registered or unlocked; `EXTERNAL_CONTENT` never gains authorization authority; `tools` schema must remain omitted on compaction, extraction, and 1-hop length-continuation; `Host-Admin` secret must never be transmitted off loopback.

## 7. Troubleshooting

- Symptom: `Disengage` button in Kill Switch or Web Search API key Save shows Host Admin error.
  - Likely cause: Running in a standalone profile-only session without local `HostAdminSecretStore` / loopback `X-Host-Admin-Secret`.
  - Resolution: Run natively on the local Windows host where `HostAdminSecretStore` provisions ACL-protected Host Admin authority.
- Symptom: Confirm button inside an inline Chat card is disabled.
  - Likely cause: Persistent Global Tool Kill Switch is engaged.
  - Resolution: Click `Tools KILLED` in the top utility strip to open `Settings -> Tools & Safety` and disengage under Host Admin authority.
