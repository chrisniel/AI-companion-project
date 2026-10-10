# Walkthrough: Milestone M1 — Flutter Desktop Client Foundation

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Document completed implementation, architectural alignment, and local verification of Milestone M1 (Flutter Desktop Client Foundation) across Batches 1–4, establishing the Windows desktop shell, system tray lifecycle, SoftGlass/Neumorphic design system, fail-closed authentication, chat conversation management, SSE streaming, GFM Markdown tables, and post-turn AI titling parity.
- **Audience:** Developer, maintainer, reviewer, QA
- **Status:** Implemented & Locally Verified (PR Candidate; Hosted PR CI Pending)
- **Last Updated:** 2026-10-10

---

## 1. What Was Delivered

- **Monorepo Pub Workspace (`frontend/flutter/`):**
  - Configured native Dart/Flutter monorepo pub workspace linking root `pubspec.yaml`, `analysis_options.yaml`, and member packages with `resolution: workspace`.
  - Pinned toolchain baseline: Flutter `3.47.1` (channel stable), Dart `3.13.1`, Windows x64 with Visual Studio 2022 C++ desktop toolchain.
  - Three platform-neutral shared packages: `companion_core` (utilities, pure-Dart RFC 4122 v4 UUID, diagnostic DTOs), `companion_api` (typed OpenAPI DTOs, SSE streaming parser, REST client), and `companion_design` (tokens, themes, Neumorphic surfaces, inner shadow painter, SoftGlass decorations).
  - Standalone Windows desktop runner application: `frontend/flutter/apps/desktop/` (`ai_companion_desktop`).

- **Native Windows Desktop Shell & System Tray Lifecycle (`PC-CLIENT-002`):**
  - Enforced window framing: 1280×800 default viewport, 1024×640 minimum size, centered on active screen.
  - System tray persistence implementing the core lifecycle invariant: **"Quit UI != Stop Runtime"**.
  - Title bar close interception (`setPreventClose(true)`) minimizing/hiding the window to the Windows System Tray rather than killing the process.
  - Native system tray context menu providing: *Open AI Companion* (default action), *Runtime Status*, disabled *Stop Runtime (Planned M2)*, and *Exit Companion*.
  - Safe native teardown: *Exit Companion* disposes window listeners, native tray hooks, and UI state without stopping the independent background Python runtime service.
  - Native Win32 lifecycle verification harness (`scripts/verify_native_windows_lifecycle.ps1`) verifying empirical live HWND `WM_CLOSE` interception, window restore, and tray exit.

- **SoftGlass & Neumorphic Design System (`PC-CLIENT-003`):**
  - Aligned desktop visual presentation with the approved design identity: **Neumorphism + Glassmorphism / Liquid Glass + Minimalism**, matching `frontend/web/` reference design.
  - Directional dual light/dark outer shadow pairs (`NeumorphicSurface`) adapting to Dark and Light theme modes.
  - Physical inset depth for composer wells and diagnostic cards via custom `_InnerShadowPainter` utilizing an even-odd donut clip mask and blur filter.
  - Interactive components: `NeumorphicButton` (raised, hover, pressed inset, disabled), `NeumorphicSegmentedControl` (recessed rail, raised thumb), `DesktopNavigationRail` (collapsible 240px / 72px with embossed active states).
  - Four curated accent presets: *Ocean Sky*, *Cobalt Indigo*, *Emerald Teal*, and *Amethyst Violet*.
  - Keyboard shortcuts wired to `FocusScope`: `Ctrl+,` (open Settings), `Esc` (hide to tray when tray is available; close history drawer).

- **Read-Only Storage Root Diagnostics (`PC-CLIENT-003`):**
  - Platform adapter (`apps/desktop/lib/platform/storage_diagnostic_adapter.dart`) performing fail-closed, read-only inspection of `%LOCALAPPDATA%\AI Companion\bootstrap.json`.
  - Rejection of relative paths and POSIX paths on Windows.
  - Telemetry model truthfully distinguishes local diagnostic candidate paths from authoritative backend-reported storage roots (`APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`).

- **Typed REST & Real-World SSE Client (`PC-CLIENT-004`):**
  - 13 typed Dart DTOs matching `contracts/openapi/openapi.json`: `HealthResponse`, `AuthVerifyResponse`, `SystemStatusResponse`, `ModelStatusResponse` (complete 27-field telemetry contract), `ConversationCreate`, `ConversationOut`, `ConversationListOut`, `ConversationUpdate`, `GenerateTitleRequest`, `MessageSend`, `MessageOut`, `MessageListOut`, `AttachmentRef`.
  - Strict contract adherence: `MessageSend.attachment_ids` is an optional array (never serializes `null`).
  - Streaming SSE parser (`SseStreamParser`) handling multi-byte UTF-8 boundary chunking, split CRLF/LF line endings, duplicate terminal event suppression (`type: done` and `data: [DONE]`), and per-request stream cancellation.
  - Windows DPAPI credential store (`WindowsDpapiCredentialStore`) using `dart:ffi` calling `Crypt32.dll` (`CryptProtectData`, `CryptUnprotectData`) for zero-plaintext token persistence in `%LOCALAPPDATA%\AI Companion\credentials.bin`.

- **Interactive Chat, History Drawer & Parity Hardening (`PC-CLIENT-004`):**
  - Fail-closed connection management: unauthenticated reachable backends remain strictly disconnected with sending disabled.
  - Asynchronous send with draft preservation: composer text is preserved in the input well if a request is rejected before server acceptance (e.g., HTTP 503 `LLM_UNAVAILABLE`, auth failure, or conversation creation failure).
  - Unused empty conversation filtering: inactive untouched empty drafts are hidden from the history drawer without deleting database records, matching React Web `AssistantView.tsx` logic.
  - Safe Markdown renderer (`AssistantMarkdownView`): supports H1–H4, bold/italic, lists, blockquotes, code blocks with language badge and clipboard copy, safe link sanitization with disposed gesture recognizers, and GitHub-Flavored Markdown (GFM) tables with column alignments and horizontal scroll.
  - Attachment metadata chips: historical message attachments render metadata cards with filename, formatted size, and explicit badge `"Preview unavailable (Planned M2)"`.
  - First-turn auto-titling parity: first accepted turn creates a deterministic 6-word title fallback; persists via `PATCH /api/v1/conversations/{id}`; and asynchronously triggers AI title refinement via `POST /api/v1/conversations/{id}/generate-title` when local model is ready.
  - First-message deadlock resolution: eliminated premature awaiting-acceptance locks before conversation creation, enabling seamless first-turn execution.

- **Backend Model Selection Hardening (Surgical Fix):**
  - Corrected model loader in `backend/app/routers/models.py` and `backend/app/services/llm_runtime.py`.
  - Eliminated obsolete hardcoded default model fallback and arbitrary `all_ggufs[0]` selection.
  - Implemented fail-closed registry lookup (`find_model_registry_entry`) that verifies configured and requested model entries against disk GGUF files, returning typed `CONFIGURED_MODEL_NOT_FOUND` / HTTP 503 when absent.

- **Automated CI Integration:**
  - Added dedicated `flutter` job lane on `windows-latest` running `dart analyze .` and `flutter test` across the monorepo workspace.
  - Updated path-aware classification rules in `scripts/ci_policy.py` to trigger `needs_flutter` on `frontend/flutter/**`.

---

## 2. Files Changed

### Flutter Workspace & Packages
- `frontend/flutter/pubspec.yaml` — Root workspace manifest linking member packages.
- `frontend/flutter/analysis_options.yaml` — Static analysis configuration.
- `frontend/flutter/packages/companion_core/` — Domain entities, RFC 4122 v4 UUID generator, locator validator, unit tests.
- `frontend/flutter/packages/companion_api/` — Typed OpenAPI DTOs, SSE streaming parser, REST client, unit tests.
- `frontend/flutter/packages/companion_design/` — Neumorphic tokens, dual shadow pairs, `_InnerShadowPainter`, SoftGlass panels, theme extension.

### Desktop Application (`frontend/flutter/apps/desktop/`)
- `lib/main.dart` — Desktop entrypoint with Windows coordinator lifecycle.
- `lib/shell/desktop_shell.dart` — Desktop navigation rail, header bar, and content switching.
- `lib/lifecycle/desktop_lifecycle_coordinator.dart` — Native window framing, close-to-tray interception, and system tray menu.
- `lib/platform/windows_dpapi_credential_store.dart` — FFI Win32 DPAPI credential persistence (`Crypt32.dll`).
- `lib/platform/storage_diagnostic_adapter.dart` — Fail-closed read-only locator reader.
- `lib/features/chat/desktop_chat_controller.dart` — Conversation state, SSE streaming, draft preservation, auto-titling.
- `lib/features/chat/chat_screen.dart` — Chat composer, message bubbles, streaming indicator, drawer overlay.
- `lib/features/chat/conversation_history_drawer.dart` — Left-anchored history drawer with search and active highlights.
- `lib/features/chat/assistant_markdown_view.dart` — Safe Markdown renderer with GFM tables and code block copy.
- `lib/screens/settings_screen.dart` — Theme, accent presets, runtime connection & pairing, storage diagnostics.
- `windows/runner/` — Native C++ runner entrypoint, CMakeLists, and resource definitions.
- `assets/icons/tray_icon.ico` — System tray icon asset.
- `README.md` — Desktop developer guide, commands, and prerequisites.

### Backend Surgical Corrections
- `backend/app/routers/models.py` — Fail-closed model registry matching via `find_model_registry_entry`.
- `backend/app/services/llm_runtime.py` — Removed hardcoded model fallbacks; reuse active in-memory models.
- `backend/tests/test_model_selection_regression.py` — Regression tests for model selection and registry validation.

### Scripts, Contracts & CI
- `scripts/check_dart_openapi_parity.py` — Parity checker validating 13 DTOs and 12 M1 routes against OpenAPI.
- `scripts/tests/test_check_dart_openapi_parity.py` — Parity checker regression tests.
- `scripts/verify_native_windows_lifecycle.ps1` — Empirical Win32 HWND close-to-tray verification harness.
- `scripts/run-desktop.ps1` — Root launcher script for debug and release desktop execution.
- `scripts/ci_policy.py` & `scripts/tests/test_ci_policy.py` — Scoped CI policy rules mapping `frontend/flutter/**` to `needs_flutter`.
- `.github/workflows/ci.yml` — Automated GitHub Actions workflow adding the `flutter` Windows verification lane.

### Documentation & Tracking
- `README.md` — Updated component roles and directory tree with `frontend/flutter/`.
- `docs/06_Guides/DEVELOPMENT_SETUP.md` — Pinned Flutter 3.47.1, updated directory layout, and added external GUI notice.
- `docs/06_Guides/TESTING_AND_CI.md` — Added Flutter workspace commands, updated CI job lane description, and mapped path rules.
- `docs/06_Guides/DOCUMENTATION_MAP.md` — Added `frontend/flutter/` to Implemented Reality authority tier.
- `docs/02_Planning/00_Master/DELIVERY_INDEX.md` — Updated M1 milestone status to Implemented PR Candidate.
- `docs/02_Planning/00_Master/SPRINT_ROADMAP.md` — Updated M1 roadmap status and exit criteria summary.
- `docs/02_Planning/00_Master/MASTER_CHECKLIST.md` — Updated PC Client Flutter row and M1 blocker status.
- `docs/01_Tracking/task.md` — Reconciled shared milestone tracking with verified M1 delivery.
- `docs/01_Tracking/active/task-m1-flutter-foundation.md` — Reconciled active tracking, batch statuses, test numbers, and closure gate prerequisites.
- `docs/02_Planning/01_Plans/plan-m1-flutter-desktop-client-foundation.md` — Updated batch statuses and documented Correction F.
- `docs/05_Design/01_PC_Desktop_Shell_and_Tray.md` — Reinforced Neumorphism + Glassmorphism / Liquid Glass + Minimalism design identity.
- `docs/03_Walkthroughs/README.md` — Updated delivery walkthrough catalog.

---

## 3. How the Logic Works

### 3.1 Startup & Window Lifecycle
```text
main()
  │
  ├─► DesktopLifecycleCoordinator.initialize()
  │     ├─► windowManager.ensureInitialized()
  │     ├─► Enforce 1280x800 size, 1024x640 min, center on screen
  │     ├─► windowManager.setPreventClose(true)   (intercept WM_CLOSE)
  │     └─► Initialize tray_manager with tray_icon.ico and context menu
  │
  └─► runApp(AiCompanionDesktopApp)
```
- When the user clicks the title bar close button (`×`), the coordinator's `onWindowClose()` listener intercepts the event and executes `windowManager.hide()`, preserving the running UI state in the system tray.
- Double-clicking the tray icon or selecting *Open AI Companion* invokes `windowManager.show()` and `windowManager.focus()`.
- Selecting *Exit Companion* executes `safeShutdown()`, which cleans up native hooks and calls `exit(0)` on the Flutter process while leaving the background Python runtime intact.

### 3.2 Authentication & Connection Probing
- On application launch, `DesktopChatController.checkConnection()` triggers a fail-closed connection check:
  1. Requests `GET /api/v1/health` (unauthenticated reachability probe).
  2. If reachable, loads the DPAPI-encrypted pairing token from `credentials.bin`.
  3. If token is present, requests `GET /api/v1/auth/verify`.
  4. If auth verification succeeds, marks connection state `online`, fetches model readiness telemetry (`GET /api/v1/models/status`), and loads conversation history (`GET /api/v1/conversations`).
  5. If health succeeds but auth fails (401 or missing token), state is set to `unauthorized` or `offline`; sending remains disabled.

### 3.3 Message Submission, Streaming & Draft Preservation
```text
User Submits Turn (Enter or Send Button)
  │
  ├─► Composer retains text in controller
  ├─► If zero conversations exist: create conversation FIRST, select it cleanly
  ├─► Mark _isSubmitting = true, show Stop button
  ├─► Initiate SSE stream: POST /api/v1/assistant/chat (stream: true)
  │
  ├───► On Transport/Server Rejection (HTTP 503, 401, Connection Error):
  │       ├─► Preserve draft text in composer
  │       ├─► Display inline error explanation
  │       └─► Revert submit state; allow user to edit and retry
  │
  └───► On Server Acceptance (HTTP 200 Received):
          ├─► Clear draft from composer
          ├─► Append optimistic user message and assistant placeholder
          ├─► SseStreamParser streams incoming TokenChunks into UI
          ├─► Receive [DONE] or type: done
          └─► Commit completed turn to active conversation state
```

### 3.4 Post-Turn Titling & Parity
- Following a completed first turn in a newly created conversation:
  1. Derives deterministic title (`deriveDeterministicTitle`, max 6 words / 42 chars) from the initial user prompt.
  2. Awaits persistent backend rename via `PATCH /api/v1/conversations/{id}`.
  3. Evaluates model readiness. If model status is unloaded, performs a fresh `getModelStatus()` probe.
  4. If local model is ready, asynchronously requests `POST /api/v1/conversations/{id}/generate-title`.
  5. Updates UI with refined title while respecting manual renames and guarding against duplicate generation.

---

## 4. Key Concepts

- **"Quit UI != Stop Runtime":** The desktop application and background Local AI Runtime possess decoupled lifecycles. Minimizing or closing the desktop UI window hides the application to the system tray, allowing background scheduled alarms and notifications to operate uninterrupted.
- **Neumorphism + Glassmorphism / Liquid Glass + Minimalism:** Tactile physical depth rendered through soft directional outer shadows (`NeumorphicSurface`), deep inset inner shadows (`_InnerShadowPainter`), frosted glass translucent surfaces (16px backdrop blur), ambient radial accents, and uncluttered layouts.
- **Fail-Closed Authentication:** A reachable backend liveness probe (200 OK) does not authenticate a client. Without a valid, verified pairing token, the client remains unauthorized, and messaging capabilities remain disabled.
- **Windows DPAPI Credential Isolation:** Pairing tokens are encrypted under the user's Windows login credential session using native Win32 `CryptProtectData`. Raw plaintext tokens are never written to disk or recorded in logs.
- **SSE Chunk Boundary Safety:** Server-Sent Events transmitted over TCP can fragment multi-byte UTF-8 character sequences across arbitrary chunk boundaries. The stream decoder buffers byte streams before UTF-8 decoding to guarantee character integrity.
- **Draft Preservation Invariant:** A user's input draft must never be cleared from the composer until the backend server confirms receipt and acceptance (HTTP 200). Unhandled exceptions or 503 rejections preserve user text.

---

## 5. Verification Steps

### Automated Checks

All automated verification commands executed locally and verified passing:

1. **Flutter Monorepo Workspace Tests:**
   ```powershell
   cd frontend/flutter
   flutter test
   ```
   *Result:* **193 tests passed** across all packages and apps:
   - `apps/desktop`: 107 passed
   - `packages/companion_api`: 52 passed
   - `packages/companion_core`: 16 passed
   - `packages/companion_design`: 18 passed

2. **Dart Static Analysis:**
   ```powershell
   cd frontend/flutter
   dart analyze .
   ```
   *Result:* **No issues found!** (0 errors, 0 warnings, 0 lints).

3. **Windows Desktop Debug Compilation:**
   ```powershell
   cd frontend/flutter/apps/desktop
   flutter build windows --debug
   ```
   *Result:* Clean build; executable produced at `build/windows/x64/runner/Debug/ai_companion_desktop.exe`.

4. **Native Windows Lifecycle Verification:**
   ```powershell
   .\scripts\verify_native_windows_lifecycle.ps1
   ```
   *Result:* **3/3 passed** (Live Win32 HWND `WM_CLOSE` close-to-tray interception, window restore, and tray exit).

5. **OpenAPI Contract Parity Checker:**
   ```powershell
   python scripts/check_dart_openapi_parity.py --check
   ```
   *Result:* **13/13 DTOs and 12/12 M1 routes verified** in complete parity with `contracts/openapi/openapi.json`.

6. **Python CI & Parity Script Unit Tests:**
   ```powershell
   python -m unittest discover -s scripts/tests
   ```
   *Result:* **37 tests passed** (including CI policy mapping and OpenAPI checker tests).

7. **React Web Test Oracle (Regression Check):**
   ```powershell
   npm --prefix frontend/web test -- --run
   ```
   *Result:* **13 test files passed, 234 tests passed** (100% green).

8. **Git Tree Cleanliness:**
   ```powershell
   git diff --check
   ```
   *Result:* Clean; zero whitespace errors or formatting defects.

---

### Manual / User-Owned Checks

> [!NOTE]
> **Interactive GUI Testing Requirement:**
> Running the desktop application for interactive visual testing requires launching the command from an **external Windows PowerShell or Windows Terminal window**.

1. **Launch Desktop Application:**
   Open an external Windows PowerShell window:
   ```powershell
   cd frontend/flutter/apps/desktop
   flutter run -d windows
   ```
   *Expected Result:* Native 1280×800 window appears centered on screen titled "AI Companion", with Neumorphic navigation rail and SoftGlass theme styling.

2. **Close-to-Tray Verification:**
   Click the title bar close button (`×`).
   *Expected Result:* Window disappears from screen and taskbar; AI Companion tray icon remains active in the Windows notification area.

3. **Tray Restore & Context Menu:**
   - Double-click the tray icon $\rightarrow$ Window restores and regains focus.
   - Right-click the tray icon $\rightarrow$ Menu displays *Open AI Companion*, *Runtime Status*, disabled *Stop Runtime*, and *Exit Companion*.
   - Click *Exit Companion* $\rightarrow$ UI process terminates cleanly.

4. **Chat & GFM Markdown Table Display:**
   With local backend running (`uvicorn app.main:app`), authenticate via Settings and enter a prompt in Chat requesting a Markdown table (e.g., *"Show a comparison table with 3 columns"*).
   *Expected Result:* Tokens stream in real time; completed response formats table with clear header styling, column alignments, borders, and smooth horizontal scrolling.

5. **Theme Switching:**
   Navigate to Settings > Appearance. Switch theme between Dark and Light mode, and toggle accent presets.
   *Expected Result:* All surfaces, shadows, buttons, and accents update dynamically without layout glitches or restart.

---

## 6. Safe Customization & Invariants

### Safe Customization
- **Accent Presets:** Four presets supported out-of-the-box (`Ocean Sky`, `Cobalt Indigo`, `Emerald Teal`, `Amethyst Violet`). Additional presets can be declared in `AccentPreset` in `companion_design`.
- **Backend Host Configuration:** Defaults to `http://127.0.0.1:8000`. Can be overridden via Settings UI or compile-time flag `--dart-define=COMPANION_HOST_URL=...`.
- **Window Sizing:** Minimum constrained to 1024×640; default set to 1280×800 in `desktop_lifecycle_coordinator.dart`.

### Strict Architectural Invariants
- **Quit UI != Stop Runtime:** The desktop UI must never unilaterally terminate the background Python runtime upon normal exit.
- **Fail-Closed Authentication:** Health reachability must never be equated with authentication. Sending must be disabled unless token verification succeeds.
- **Zero Plaintext Tokens:** Pairing credentials must never be committed to disk in plaintext. All tokens must pass through Win32 DPAPI.
- **No Scope Expansion:** M1 delivers foundational desktop shell, window lifecycle, and conversational streaming. Windows Action Center toasts (M2), background Task Scheduler autostart (M2), D6 model importing (M2), full Character Studio (M3), and voice hardware audio capture (M4) are strictly deferred.

---

## 7. Troubleshooting

- **Symptom: Headless or blank window when running `flutter run -d windows`**
  - *Likely cause:* Attempting to launch the graphical Flutter application from an integrated or headless terminal environment that lacks access to the active desktop session.
  - *Resolution:* Launch `flutter run -d windows` from an external Windows PowerShell or Windows Terminal window.

- **Symptom: System tray icon is missing or falls back to taskbar minimize**
  - *Likely cause:* Missing `.ico` asset or uninitialized Win32 shell notification icon.
  - *Resolution:* Ensure `frontend/flutter/apps/desktop/assets/icons/tray_icon.ico` exists and is declared under `flutter.assets` in `pubspec.yaml`.

- **Symptom: HTTP 503 `LLM_UNAVAILABLE` on message send**
  - *Likely cause:* Local LLM engine is unloaded or configured model file is not staged in `<DATA_ROOT>/models/llm`.
  - *Resolution:* Inspect backend log; stage the required GGUF model; verify model status via Settings > Runtime Connection. The composer preserves your draft.

- **Symptom: DPAPI Decryption Failure Across User Profiles**
  - *Likely cause:* Stored credentials in `%LOCALAPPDATA%\AI Companion\credentials.bin` were encrypted by a different Windows user account.
  - *Resolution:* Re-enter the pairing token in Settings > Runtime Connection & Pairing to encrypt under the active Windows user context.
