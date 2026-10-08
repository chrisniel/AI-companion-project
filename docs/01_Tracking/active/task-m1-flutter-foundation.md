# Branch Task: M1 Flutter Desktop Client Foundation

- **Branch:** `feature/m1-flutter-foundation` (human-prepared).
- **Starting Baseline:** `55c6f621a4a931dbac32ecc7f919f608ad2bb669`.
- **Milestone:** M1 — Flutter Desktop Client Foundation.
- **Active Work Item:** `PC-CLIENT-003` (SoftGlass Desktop Design System, Navigation Shell & Read-Only Storage Awareness).
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m1-flutter-desktop-client-foundation.md`](../../02_Planning/01_Plans/plan-m1-flutter-desktop-client-foundation.md).
- **Current Stage:** Batch 3 Implementation & Verification.

---

## Batch Execution State

| Batch | Work Item | Status | Verification & Deliverables |
| :--- | :--- | :--- | :--- |
| **B1** | `PC-CLIENT-001` | `VERIFIED` | Pub Workspace (`frontend/flutter/`), `companion_core`, `companion_api`, `companion_design`, `apps/desktop` Windows runner, CI policy and workflow integration. |
| **B2** | `PC-CLIENT-002` | `VERIFIED` | Window framing (1280×800 / 1024×640), close-to-tray lifecycle, native tray menu, clean shutdown, 23 workspace tests, native WM_CLOSE interception verified. |
| **B3** | `PC-CLIENT-003` | **VERIFIED / AWAITING REVIEW** | SoftGlass tokens, 4 accent presets, typography/spacing/shadows scale, `SoftGlassPanel`, collapsible navigation rail, 6 screens (Chat, Voice, Schedule, Memory, Studio, Settings), shortcuts (`Ctrl+,`, conditional `Esc`), read-only fail-closed storage diagnostics, 51 workspace tests. |
| **B4** | `PC-CLIENT-004` | `PLANNED` | Typed REST client, real-world SSE parser, live conversation UI, contract parity tests, React Web parity. |

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
- [x] Implement pure-Dart `evaluateBootstrapLocatorContent` and `isAbsolutePath` in `companion_core`.
- [x] Implement `WindowsStorageDiagnosticReader` inspecting `%LOCALAPPDATA%\AI Companion\bootstrap.json` in a fail-closed, read-only manner.
- [x] Implement `DesktopSettingsController` for theme mode, accent preset, rail state, navigation, and storage diagnostics.
- [x] Implement `DesktopNavigationRail` (collapsible 240px / 72px) with Chat, Voice (Planned M4), Schedule (Planned M3), Memory (Planned M3), Studio (Planned M3), Settings.
- [x] Truthful runtime status: "Runtime: Standalone (Unconnected)".
- [x] Implement destination screens: `ChatScreen`, `VoiceScreen`, `ScheduleScreen`, `MemoryScreen`, `StudioScreen`, `SettingsScreen`.
- [x] Implement keyboard shortcuts: `Ctrl+,` (open settings), `Esc` (hide to tray only if tray available).
- [x] Implement automated test suites: `desktop_shell_test.dart`, `desktop_settings_test.dart`, `desktop_shortcuts_test.dart`, `windows_storage_diagnostic_reader_test.dart`, `typography_and_theme_test.dart`, `soft_glass_panel_test.dart`, updated `widget_test.dart`.
- [x] Verify complete workspace test suite (51/51 tests pass across all 4 packages: 28 desktop + 10 core + 10 design + 3 api).
- [x] Verify `dart analyze .` (0 issues).
- [x] Verify `flutter build windows --debug` (clean build).
- [x] Verify native Windows lifecycle harness (`scripts/verify_native_windows_lifecycle.ps1` all 3 tests pass).
- [x] Verify Python CI policy regression suite (`test_ci_policy.py` 23 tests pass).
- [x] Stop at independent review gate before Batch 4.
