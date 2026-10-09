# Branch Task: M1 Flutter Desktop Client Foundation

- **Branch:** `feature/m1-flutter-foundation` (human-prepared).
- **Starting Baseline:** `55c6f621a4a931dbac32ecc7f919f608ad2bb669`.
- **Milestone:** M1 — Flutter Desktop Client Foundation.
- **Active Work Item:** `PC-CLIENT-004` (Typed Runtime Client, REST/SSE Integration and Functional Desktop Conversation).
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m1-flutter-desktop-client-foundation.md`](../../02_Planning/01_Plans/plan-m1-flutter-desktop-client-foundation.md).
- **Current Stage:** Batch 4 Implementation Complete — Awaiting Independent Review.

---

## Batch Execution State

| Batch | Work Item | Status | Verification & Deliverables |
| :--- | :--- | :--- | :--- |
| **B1** | `PC-CLIENT-001` | `VERIFIED` | Pub Workspace (`frontend/flutter/`), `companion_core`, `companion_api`, `companion_design`, `apps/desktop` Windows runner, CI policy and workflow integration. |
| **B2** | `PC-CLIENT-002` | `VERIFIED` | Window framing (1280×800 / 1024×640), close-to-tray lifecycle, native tray menu, clean shutdown, 23 workspace tests, native WM_CLOSE interception verified. |
| **B3** | `PC-CLIENT-003` | `VERIFIED` | SoftGlass tokens, 4 accent presets, neumorphic surface & inner shadow system (`NeumorphicSurface`, `_InnerShadowPainter`), interactive component parity (`DesktopNavigationRail`, `NeumorphicButton`, `NeumorphicSegmentedControl`, recessed chat composer well, recessed diagnostic cards), shortcuts (`Ctrl+,`, conditional `Esc`), read-only fail-closed storage diagnostics, 73 workspace tests, Windows startup fix. |
| **B4** | `PC-CLIENT-004` | **VERIFIED / AWAITING INDEPENDENT REVIEW** | Typed OpenAPI DTOs in `companion_api`, pure-Dart RFC 4122 v4 UUID generator in `companion_core`, robust SSE streaming parser (multibyte UTF-8 chunking, CRLF splitting, terminal deduping, cancellation), Windows DPAPI credential store (`dart:ffi` `CryptProtectData`/`CryptUnprotectData`), `DesktopChatController` with optimistic local turns, live `ChatScreen` UI (conversation title, connection pill, model badge, streaming bubbles, Enter to send, Shift+Enter newline, stop generation), `SettingsScreen` Runtime Connection & Pairing controls, contract parity checker (`scripts/check_dart_openapi_parity.py`), root desktop runner (`scripts/run-desktop.ps1`), desktop README, 136 workspace tests passing, 0 lints. |

---

## Batch 1 Checkpoints & Boundaries

- [x] Preflight checks verified (`feature/m1-flutter-foundation`, clean working tree).
- [x] Authoritative implementation plan persisted.
- [x] Create `frontend/flutter/pubspec.yaml` (root workspace) & `analysis_options.yaml`.
- [x] Create member packages: `companion_core`, `companion_api`, `companion_design`.
- [x] Scaffold `apps/desktop` via `flutter create --platforms=windows`.
- [x] Implement initial smoke-test application in `apps/desktop/lib/main.dart`.
- [x] Verify `dart pub get`, `dart pub workspace list`, `dart analyze`, and member tests.
- [x] Verify native Windows debug build: `flutter build windows --debug`.
- [x] Update `scripts/ci_policy.py`, `scripts/tests/test_ci_policy.py`, and `.github/workflows/ci.yml`.
- [x] Verify CI policy regression test suite.
- [x] Batch 1 independent review handoff.

---

## Batch 2 Checkpoints & Boundaries

- [x] Pin vetted `window_manager ^0.4.3` and `tray_manager ^0.2.4` in `apps/desktop/pubspec.yaml`.
- [x] Define platform-abstracted `DesktopWindowAdapter` and `DesktopTrayAdapter` contracts.
- [x] Implement `DesktopLifecycleCoordinator` enforcing 1280x800 default, 1024x640 min, and centering.
- [x] Implement close interception (`setPreventClose(true)`) and hide-to-tray behavior.
- [x] Implement tray restore/focus and context menu with M1 actions and disabled M2 items.
- [x] Implement safe controlled shutdown disposing listeners and tray/window native resources while leaving Python backend running.
- [x] Implement automated test suite covering initialization, close interception, tray routing, repeated cycles, cleanup, missing tray fallback, partial initialization teardown, and UI controls (15 tests in `apps/desktop`).
- [x] Verify full workspace test suite (23/23 tests pass across all packages: 15 desktop + 3 core + 3 api + 2 design).
- [x] Verify `dart analyze .` (0 issues).
- [x] Verify `flutter build windows --debug` and execute native empirical live HWND `WM_CLOSE` interception, window restore, and tray termination harness (`scripts/verify_native_windows_lifecycle.ps1`).
- [x] Batch 2 independent review handoff.

---

## Batch 3 Checkpoints & Boundaries

- [x] Expand `companion_design` tokens: light/dark palettes, glass opacity & blur (16px), 4 accent presets (Ocean Sky, Cobalt Indigo, Emerald Teal, Amethyst Violet), typography scale, spacing/radius/shadows.
- [x] Implement `SoftGlassPanel` widget with backdrop blur and physical borders/shadows.
- [x] Implement `CompanionThemeExtension` and theme factory (`CompanionTheme.light`, `CompanionTheme.dark`).
- [x] Implement pure-Dart `evaluateBootstrapLocatorContent` and `isAbsolutePath` in `companion_core` with strict fail-closed semantics (unreadable file fails closed as corrupt, POSIX paths rejected on Windows).
- [x] Implement `WindowsStorageDiagnosticReader` inspecting `%LOCALAPPDATA%\AI Companion\bootstrap.json` in a fail-closed, read-only manner with full root awareness (`APP_INSTALL`, `DATA`, `LIBRARY` marked "Not reported by backend").
- [x] Implement `DesktopSettingsController` for theme mode, accent preset, rail state, navigation, diagnostic scroll, and storage diagnostics.
- [x] Implement `DesktopNavigationRail` (collapsible 240px / 72px) with Chat, Voice (Planned M4), Schedule (Planned M3), Memory (Planned M3), Studio (Planned M3), Settings.
- [x] Truthful runtime status: "Runtime: Standalone (Unconnected)".
- [x] Implement destination screens: `ChatScreen`, `VoiceScreen`, `ScheduleScreen`, `MemoryScreen`, `StudioScreen`, `SettingsScreen`.
- [x] Implement keyboard shortcuts: `Ctrl+,` (open settings), `Esc` (hide to tray only if tray available).
- [x] Implement responsive layout verification test suite: `desktop_layout_responsive_test.dart` verifying 1280×800 and 1024×640 viewports across Chat (expanded/collapsed), Settings appearance, Settings diagnostics, and text scaling (1.2x/1.3x) with zero RenderFlex overflows.
- [x] Implement automated test suites: `desktop_shell_test.dart`, `desktop_settings_test.dart`, `desktop_shortcuts_test.dart`, `desktop_layout_responsive_test.dart`, `windows_storage_diagnostic_reader_test.dart`, `storage_diagnostic_test.dart`, `soft_glass_panel_test.dart`, `widget_test.dart`.
- [x] Correct visual foundation to Web design identity: Neumorphism + Glassmorphism / Liquid Glass + Minimalism (`frontend/web` reference).
- [x] Implement `NeumorphicSurface` with directional light/dark outer shadow pairs and custom `_InnerShadowPainter` (evenOdd donut mask + blur filter) for authentic physical inset depth.
- [x] Implement `NeumorphicButton` with raised, hover, pressed inset, and disabled states.
- [x] Implement `NeumorphicSegmentedControl` matching Web segmented controls without Material styling conflicts.
- [x] Align `DesktopNavigationRail` tiles with Web interaction states (embossed selected, inset hover/pressed).
- [x] Align `ChatScreen` composer with recessed input well and responsive hint layout (`TextOverflow.ellipsis`).
- [x] Align `SettingsScreen` controls with `NeumorphicSegmentedControl` and recessed diagnostic cards.
- [x] Verify complete workspace test suite (74/74 tests pass: 39 desktop + 14 core + 18 design + 3 api).
- [x] Verify `dart analyze .` (0 issues).
- [x] Verify `flutter build windows --debug` (clean build).
- [x] Verify native Windows lifecycle harness (`scripts/verify_native_windows_lifecycle.ps1` all 3 tests pass).
- [x] Verify Python CI policy regression suite (`test_ci_policy.py` 29 tests pass).
- [x] Capture visual evidence: Web reference UI and Flutter Desktop UI across 8 required comparisons (A–H) saved in `%LOCALAPPDATA%\Temp\ai_companion_visual_review` outside Git.
- [x] Resolve Windows interactive startup defect: unblock runApp() ahead of asynchronous coordinator initialization, adopt supported window_manager waitUntilReadyToShow lifecycle with explicit 'AI Companion' title, align native Win32 main.cpp window creation title to 'AI Companion', and harden LiveDesktopTrayAdapter against silent native tray LoadImage failures.
- [x] Independent human visual review completed and accepted.

---

## Batch 4 Checkpoints & Boundaries

- [x] Implement cryptographically secure RFC 4122 v4 UUID generator in `companion_core` (`uuid_utils.dart`) and unit test (`uuid_utils_test.dart`).
- [x] Implement typed DTOs in `companion_api` matching `contracts/openapi/openapi.json`:
  - `HealthResponse` (`health_dto.dart`)
  - `AuthVerifyResponse` (`auth_dto.dart`)
  - `SystemStatusResponse` (`system_status_dto.dart`)
  - `ModelStatusResponse` (`model_status_dto.dart` — complete 27-field Phase 3 Truthful Telemetry Contract)
  - `ConversationCreate`, `ConversationOut`, `ConversationListOut` (`conversation_dto.dart`)
  - `MessageSend`, `MessageOut`, `MessageListOut`, `AttachmentRef` (`message_dto.dart` — strictly enforces `MessageSend.attachment_ids` optional array, NOT nullable; never serializes null)
  - `SseTokenEvent`, `SseDoneEvent`, `SseErrorEvent`, `SseUnknownEvent` (`sse_event_dto.dart`)
- [x] Implement `CredentialStore` interface and `InMemoryCredentialStore` in `companion_api`.
- [x] Implement `SseStreamParser` in `companion_api`:
  - Multibyte UTF-8 chunk fragmentation handling via `byteStream.cast<List<int>>().transform(utf8.decoder)`.
  - Split CRLF boundaries (`\r\n\r\n` and `\n\n`).
  - Terminal event deduping (`type: done` and `data: [DONE]`).
  - Unexpected EOF and unparsed trailing buffer error handling.
- [x] Implement `CompanionClient` and `CompanionApiException` in `companion_api`:
  - Base URL validation restricting non-loopback plaintext HTTP when credentials are used.
  - Endpoints: `getHealth`, `getSystemStatus`, `verifyAuth`, `getModelStatus`, `createConversation`, `listConversations`, `getConversation`, `deleteConversation`, `listMessages`, `sendMessageStream`.
  - Active turn cancellation via stream subscription cancellation.
- [x] Implement `WindowsDpapiCredentialStore` in `apps/desktop` using `dart:ffi` calling `Crypt32.dll` (`CryptProtectData`, `CryptUnprotectData`) and `kernel32.dll` (`LocalAlloc`, `LocalFree`) to ensure zero-plaintext disk persistence.
- [x] Implement `DesktopChatController` in `apps/desktop`:
  - Conversation management (creation, listing, active conversation selection).
  - Optimistic local turn creation with rollback on network/server error.
  - Live SSE streaming state accumulation (`streamingText`).
  - Active turn generation cancellation (`stopGeneration`).
  - Periodic and on-demand connection status probing (`online`, `offline`, `unauthorized`, `connecting`).
- [x] Upgrade `ChatScreen` from static disabled placeholder to interactive chat UI:
  - Header: conversation title, live connection status pill, active model badge.
  - Scrollable message history with distinct user and assistant bubble styling.
  - Assistant typing / streaming indicator with live token rendering.
  - Recessed neumorphic composer: multiline TextField, Enter to send, Shift+Enter for newline.
  - Send button (submits turn) and Stop button (cancels active turn).
  - Clean disabled states for attachments (paperclip) and voice (microphone).
- [x] Update `SettingsScreen` with Runtime Connection & Pairing controls:
  - Backend host URL input with `COMPANION_HOST_URL` environment fallback.
  - DPAPI-secured pairing token input with obscure toggle.
  - Live "Test Connection" button providing verified backend feedback.
- [x] Wire `DesktopChatController` into `DesktopShell` and `main.dart`.
- [x] Implement `scripts/check_dart_openapi_parity.py` and `scripts/tests/test_check_dart_openapi_parity.py`:
  - Verifies 11 DTO schemas against OpenAPI components.
  - Verifies 10 M1 routes and registers 22 unmapped future M2-M4 routes.
  - Strictly verifies `MessageSend` non-null `attachment_ids` semantics.
- [x] Implement `scripts/run-desktop.ps1` repository root launcher script.
- [x] Update `frontend/flutter/apps/desktop/README.md`.
- [x] Implement `ConversationHistoryDrawer` and chat history lifecycle:
  - Left-anchored SoftGlass drawer with backdrop blur scrim and keyboard accessibility (Esc/Ctrl+H).
  - Search filtering, session count, active conversation highlight, message count badge, and thread deletion.
  - Startup synchronization: `checkConnection()` auto-loads conversation history upon verified authentication.
  - Truthful model status telemetry and semantic badges (`modelReady`, `modelSleeping`, `modelLoading`, `modelUnloaded`, `modelLoadFailed`).
  - Actionable error explanation for HTTP 503 `LLM_UNAVAILABLE` runtime state.
- [x] Run full verification suite (152 workspace Flutter tests pass, 0 lints, clean Windows debug build, native lifecycle verification pass, OpenAPI parity pass, 37 Python tests pass).
- [ ] M1 Final Integration independent human review handoff and verification sign-off. Stop at gate.

---

## Web-to-Flutter Appearance & Feature Parity Checklist

The established product design identity is: **Neumorphism + Glassmorphism / Liquid Glass + Minimalism**.
The reference implementation is `frontend/web/`.

| Component / Feature | Web Reference (`frontend/web/`) | Flutter Desktop (`apps/desktop` / `companion_design`) | Status | Parity Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Conversation History Drawer** | `ConversationHistoryDrawer.tsx` | `ConversationHistoryDrawer` in `apps/desktop` | `IMPLEMENTED` | Left-anchored glass drawer with blur scrim, search filter, active highlight, Esc/Ctrl+H. |
| **Neumorphic Raised Surfaces** | `NeumorphicButton`, `Card` (`shadow-*-raised`) | `NeumorphicSurface` (convex/flat bevel, paired outer shadows) | `IMPLEMENTED` | Directional light/dark outer shadows adapt to light and dark theme modes. |
| **Neumorphic Recessed Wells** | `TextInput`, Recessed Cards (`shadow-*-inset`) | `NeumorphicSurface(isRecessed: true)` via `_InnerShadowPainter` | `IMPLEMENTED` | Physical donut-mask inner shadow for composer input and diagnostic cards. |
| **Neumorphic Buttons** | `NeumorphicButton.tsx` (primary, accent, ghost, icon) | `NeumorphicButton` (raised, pressed inset, hover, disabled) | `IMPLEMENTED` | Authentic press animation and state transitions. |
| **Segmented Controls** | `NeumorphicSegmentedControl` (recessed rail, raised thumb) | `NeumorphicSegmentedControl` | `IMPLEMENTED` | Used in Settings for Theme Mode and Accent Preset selection. |
| **Navigation Rail** | `DesktopNavigationRail` (72px collapsed / 240px expanded) | `DesktopNavigationRail` (72px collapsed / 240px expanded) | `IMPLEMENTED` | Embossed active tile, inset hover, smooth width transition, persistent footer. |
| **Color Palettes & Accents** | Ocean Sky, Cobalt Indigo, Emerald Teal, Amethyst Violet | `AccentPreset` (Ocean Sky, Cobalt Indigo, Emerald Teal, Amethyst Violet) | `IMPLEMENTED` | Dynamic primary/accent token derivation matching Web tokens. |
| **Theme Modes** | Dark, Light, System themes in `ThemeContext.tsx` | `CompanionTheme.dark`, `CompanionTheme.light`, `ThemeMode.system` | `IMPLEMENTED` | Seamless switching via Settings and keyboard shortcuts. |
| **Keyboard Shortcuts** | Desktop Web navigation shortcuts | `DesktopShortcuts` (`Ctrl+,` for Settings, `Esc` for hide-to-tray) | `IMPLEMENTED` | Shortcuts wired into Root FocusScope. |
| **Recessed Chat Composer** | Recessed input card with action buttons | `ChatScreen` recessed composer well | `IMPLEMENTED` | Inset shadow well, responsive hint text with ellipsis, multiline support. |
| **Chat Keyboard Handling** | Enter submits, Shift+Enter newline | `HardwareKeyboard` & `RawKeyboardListener` in `ChatScreen` | `IMPLEMENTED` | Enter sends message, Shift+Enter inserts newline without sending. |
| **Message Bubble Styling** | User (accent-tinted raised) vs Assistant (glass/neutral) | `_MessageBubble` in `ChatScreen` | `IMPLEMENTED` | User message right-aligned with accent styling; Assistant left-aligned with glass surface. |
| **Streaming Indicator & Stop** | Animated typing pulse & Stop generation button | Assistant typing indicator & `NeumorphicButton` Stop control | `IMPLEMENTED` | Displays live token stream and allows immediate turn interruption. |
| **Runtime Connection Controls** | Settings pairing input & test connection | Settings "Runtime Connection & Pairing" card | `IMPLEMENTED` | DPAPI-encrypted token input, URL config, live connection test probe. |
| **Storage Diagnostics** | Storage diagnostic cards in Settings | Recessed diagnostic cards with fail-closed evaluator | `IMPLEMENTED` | Read-only inspection of bootstrap locator; POSIX paths rejected on Windows. |
| **Attachment Input Control** | Paperclip button opening file picker | Recessed paperclip icon button in `ChatScreen` | `PARTIAL` | Visual UI present in composer; file picker & ingestion deferred to M2. |
| **Voice Input Control** | Microphone button opening audio capture | Recessed microphone icon button in `ChatScreen` | `PARTIAL` | Visual UI present in composer; audio recording deferred to M4. |
| **Rich Markdown in Bubbles** | `react-markdown` with syntax highlighting | Plain text with line break preservation in `_MessageBubble` | `PARTIAL` | Full markdown and syntax-highlighted code blocks deferred to M2. |
| **Model Selection Dropdown** | Dropdown menu in chat header | Status badge showing active model in chat header | `PARTIAL` | Displays truthful active model; interactive dropdown model switching deferred to M2. |
| **Notification Toast Banner** | Floating toast notification overlay | In-card connection status pill and inline error banners | `PARTIAL` | Floating toast overlay system deferred to M2. |
| **Background Presets** | Multi-gradient wallpaper presets (`ThemeContext.tsx`) | Ambient radial glow matching active accent | `DEFERRED` | M1 uses calibrated ambient backdrop; multi-palette wallpaper presets deferred. |
| **Custom Backgrounds** | Custom image upload and background tinting | Fixed SoftGlass backdrop system | `DEFERRED` | User-uploaded background imagery and custom tints deferred. |
| **Glass & Effect Controls** | Sliders for blur strength, glass opacity, border intensity | Calibrated design tokens in `companion_design` | `DEFERRED` | Interactive slider tuning for glass opacity and blur deferred. |
| **UI Density Settings** | Compact vs Spacious density modes | Responsive desktop layout (1280×800 / 1024×640) | `DEFERRED` | Fixed responsive desktop layout; user density toggle deferred. |
| **Animation Preferences** | In-app reduced motion preference toggle | Smooth AnimatedSwitcher & Flutter animations | `DEFERRED` | Respects platform defaults; explicit in-app animation control deferred. |
| **Live Appearance Preview** | Dedicated live theme preview card in Settings | Direct live updates across shell upon selection | `DEFERRED` | Settings controls update active UI live; isolated preview canvas deferred. |
| **Secondary App Destinations** | Voice, Schedule, Memory, Studio modules | Navigation rail stubs with "Planned M3/M4" badge | `DEFERRED` | Shell navigation functional; full screen implementations scheduled for M3/M4. |
