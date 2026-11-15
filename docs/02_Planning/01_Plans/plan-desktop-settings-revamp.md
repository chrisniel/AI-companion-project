# Implementation Plan: Desktop Settings Revamp & Rail Power Menu (Batch 1)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Approved
- **Delivery Level:** Level B — Planned Autonomous
- **Scope Mode:** New Feature / UI Refactor — Categorized two-column Desktop Settings workspace, truthful Planned M4+ tabs, modular `features/settings/` decomposition, and Navigation Rail `⏻` Power/Tray menu (no backend/schema changes; Appearance Batch 2 sliders/wallpapers deferred).
- **Target Files:**
  - `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`
  - `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart`
  - `frontend/flutter/apps/desktop/lib/features/settings/` *(new modular section/sidebar files)*
  - `frontend/flutter/apps/desktop/lib/features/profiles/profile_access_card.dart` *(wrap safeguard if needed at `1024x640` `1.3x`)*
  - `frontend/flutter/apps/desktop/lib/features/schedule/quiet_hours_card.dart` *(wrap safeguard if needed at `1024x640` `1.3x`)*
  - `frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart`
  - `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart`
  - `frontend/flutter/apps/desktop/test/` *(Settings, Rail, Shell, Responsive, and widget tests)*
  - `docs/05_Design/01_PC_Desktop_Shell_and_Tray.md` & `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md` *(Phase 3 doc sync after verification)*
- **Branch:** `feat/desktop-settings-revamp`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feat-desktop-settings-revamp.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feat-desktop-settings-revamp.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:** Revamp the overloaded 1,848-line single-column Flutter Desktop `SettingsScreen` into a categorized two-column workspace matching the React Web reference (`SettingsView.tsx`) and Desktop Option 2A sub-navigation screens (`MemoryScreen` / `ScheduleScreen`), introduce truthful `Planned` category tabs for upcoming M4+ / M2+ domains (`Voice & Audio`, `Tools & Safety`, `Health & Context`, `Network & Mesh`), and move `Minimize to System Tray` and `Exit Companion` out of Settings into a clean `⏻` Power popover menu at the bottom of `DesktopNavigationRail` so actions are reachable from any screen without button duplication.
- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) — Section 3 Invariants #2 (D2 Refined Desktop/Tray/Exit lifecycle) & #5 (D9 Deterministic Action Policy).
  - [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md) — Tray lifecycle separation (`Hide to Tray` vs `Exit Companion`) and startup slot (`PC-HOST-002`).
  - [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../../04_Architecture/01_Domains/voice-and-audio.md) & [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](../../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md) — Truthful M4 planned slots in Settings.
  - [`docs/05_Design/01_PC_Desktop_Shell_and_Tray.md`](../../05_Design/01_PC_Desktop_Shell_and_Tray.md) — Visual parity with `frontend/web/`, SoftGlass/Neumorphism tokens, and left navigation rail + tray affordances.
- **Concrete Deliverables:**
  1. Two-column responsive Desktop `SettingsScreen` (`>= 720px` sticky/scrollable category sidebar + right active panel; `< 720px` compact horizontal chip strip + search input) refactored cleanly out of the 1,848-line monolith into `lib/features/settings/`.
  2. Complete categorized navigation with live search filtering, `AVAILABLE` active sections (`Appearance`, `General & Lifecycle`, `Notifications & Quiet Hours`, `Profiles & Privacy`, `AI Runtime & Models`, `Storage & Diagnostics`), and truthful `PLANNED` sections (`Voice & Audio` `M4`, `Tools & Safety` `M4`, `Health & Context` `M5+`, `Network & Mesh` `M5+`) with `scrollToDiagnostics` / `openSettingsSection` deep-link support.
  3. Zero duplicate lifecycle action buttons inside Settings: `Hide to Tray` and `Exit Companion` buttons removed from `SettingsScreen` (both header and body) and consolidated into a bottom-of-rail `⏻` Power / Shutdown popover menu in `DesktopNavigationRail` (`Minimize to System Tray`, `Close & Startup Settings...`, `Exit Companion`), reusing `DesktopShell`'s existing shutdown flow cleanly.
  4. Automated unit/widget tests covering sidebar switching, search filtering, planned vs active rendering, `scrollToDiagnostics` deep-link to Storage, `DesktopNavigationRail` `⏻` popover actions in both expanded and collapsed rail states, and clean `flutter analyze` + Windows release/debug compilation verification.
- **Explicit Out-of-Scope:**
  - **Batch 2 Appearance Parity Controls** (`Live Appearance Preview`, background wallpaper presets/custom image/gradient/solid, glass opacity/blur/tint/saturation sliders, custom accent hex input, tactile shadow intensity, animation motion dynamics, and interface density toggles) — explicitly deferred until after M4.
  - **M4 Feature Implementations** (actual STT/TTS WebSocket audio settings or D9 tool execution engines) — represented strictly as truthful `PLANNED` informational tabs in Batch 1.
  - **Open M2 Functional Implementations** (`PC-HOST-002` Windows autostart registry/Task Scheduler writer, `PC-HOST-004` storage root mover, `PC-IDENTITY-003` PIN/enrollment) — represented cleanly in existing cards or truthful planned notes without modifying backend/host logic.
  - **Backend Python API, OpenAPI contracts, or Alembic schema changes** — none required.

---

## 2. Architecture & Technical Approach

- **Current Findings & Technical Baseline:**

  | Observation / Evidence | Verified Interpretation |
  | --- | --- |
  | `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart` is 1,848 lines stacking all 8 cards in one `SingleChildScrollView`, placing `Hide to Tray` and `Exit Companion` at the bottom (`lines 538–600`). | Forces excessive scrolling before reaching everyday controls and blocks clean insertion of M4 Voice/Tool settings. Also currently relies on ancestor `ListenableBuilder` (`desktop_shell.dart:406`), so standalone `SettingsScreen` must wrap its own `build` in `ListenableBuilder(listenable: widget.controller)`. |
  | `frontend/web/src/components/workspace/SettingsView.tsx` uses a top header banner + sticky left category sidebar (`lg:col-span-4`, Search input + `AVAILABLE`/`PLANNED` badges) + right active section pane (`lg:col-span-8`). | Provides the canonical visual and structural reference for Desktop parity. Keeps right pane showing active section even if search returns 0 matches (`SettingsView.tsx:155`). |
  | Desktop `MemoryScreen` (`memory_screen.dart:120-157`) and `ScheduleScreen` (`schedule_screen.dart:84-116`) use the Option 2A two-column sidebar (`>= 720px` sidebar vs compact horizontal chips below `720px`). | Gives an established project-native responsive Flutter Desktop pattern to mirror. At `1024x640` + expanded rail (`240px`) + `1.3x` text scale, right pane width is `~428px` and height `< 640px`, requiring `Expanded(child: ListView)` in `SettingsSidebar` and `Wrap` instead of `Row` in `_buildModelEntryCard` (`settings_screen.dart:1743`). |
  | `DesktopShell` (`desktop_shell.dart:142-237`) and `SettingsScreen` (`settings_screen.dart:602-690`) duplicate the `_handleExitCompanion` confirmation -> `shutdownLocalRuntime` -> recovery dialog -> `handleExitRequested` state machine. | Consolidating exit orchestration via `DesktopShell` when removing `Hide to Tray` / `Exit Companion` from Settings eliminates both UI button duplication and code duplication. |
  | `DesktopSettingsController.scrollToDiagnostics` is used by `main.dart` and `visual_evidence_runner.dart` (`04_dark_settings_diagnostics_1280x800.png`) to jump straight to diagnostics. | Updating `DesktopSettingsController` so `initialScrollToDiagnostics: true` / `setScrollToDiagnostics(true)` selects `SettingsSectionId.storage` preserves all existing harness & CLI entry points. |
  | `widget_test.dart` (`lines 31-138`), `desktop_settings_test.dart` (`lines 66-630`), `desktop_layout_responsive_test.dart` (`lines 113-166`), and `desktop_app_runtime_wiring_test.dart` (`lines 280-347`) assert against single-scroll Settings layout, `TextField.first`, and `Hide to Tray` / `Exit Companion` inside `SettingsScreen`. | Must be updated deliberately under TDD to test the new rail `⏻` power menu, keyed inputs, and section-based `SettingsScreen` interactions. |

- **Architectural Approach:**
  1. **Settings Category State (`DesktopSettingsController` + `SettingsSectionMeta`):**
     - Define `enum SettingsSectionId { appearance, general, notifications, profiles, runtime, storage, voice, tools, health, network }` and immutable metadata (`label`, `description`, `icon`, `status` [`available` | `planned`], `milestoneHint`, `plannedSummary`, `keywords`).
     - Add `SettingsSectionId selectedSettingsSection` (default `SettingsSectionId.appearance`; overridden to `SettingsSectionId.storage` when `initialScrollToDiagnostics == true` or `setScrollToDiagnostics(true)`).
     - Add `setSettingsSection(SettingsSectionId)` and `openSettingsSection(SettingsSectionId)` (updates active tab AND switches `currentDestination` to `DesktopNavDestination.settings`, notifying listeners once).
  2. **Clean Two-Column Layout & Modular Decomposition (`lib/features/settings/`):**
     - `SettingsScreen` wraps its `build` in `ListenableBuilder(listenable: widget.controller, ...)` so standalone mounts rebuild reliably on section changes. Holds a persistent search `TextEditingController` across layout transitions (`>= 720px` <-> `< 720px`).
     - `SettingsScreen` renders a compact header banner (`Preferences & System Configuration`, Desktop truth badges — **no** `Hide to Tray` / `Exit` buttons) above a responsive `LayoutBuilder` (`>= 720px` Row with `SettingsSidebar(width: 244)` + expanded right scroll pane; `< 720px` Column with compact search/chips + expanded right scroll pane).
     - **State Preservation Across Tab Switches:** Keep `SettingsRuntimeSection` (and its `_urlController`, `_tokenController`, `_registryEntries`, `_modelStatus`, `_selectedModelId`, `_isStillLoading`, `_modelActionMessage`, and DPAPI async state) preserved via `IndexedStack` so switching tabs mid-edit or during `MODEL_LOADING` polling (`_pollModelStatusUntilReady`) never drops state or cancels timers, and `_loadModelData()` runs on Settings entry and Runtime tab entry.
     - Extract existing sections cleanly out of `settings_screen.dart` while keeping all existing controller/API/DPAPI/model/supervision/quiet-hours logic intact:
       - `SettingsAppearanceSection` (Color Mode + Accent Preset + truthful Batch 2 note)
       - `SettingsGeneralSection` (Window Bounds `1280x800 (1024x640 min)`, System Tray active/unavailable status, helpful guidance pointing to `⏻` in the bottom navigation rail for `Minimize to Tray` / `Exit Companion` without repeating buttons, plus truthful `PC-HOST-002` Startup slot)
       - Notifications section (`QuietHoursSettingsCard` when `scheduleController != null`, plus clean standalone fallback message if unwired, with responsive `Wrap` safeguard for narrow panes)
       - Profiles section (`ProfileAccessCard` when `profileController != null`, plus standalone fallback note when `profileController == null`, responsive `Wrap` safeguard for deleted-profile actions, and truthful `PC-IDENTITY-003` PIN/Enrollment planned card)
       - `SettingsRuntimeSection` (Local LLM Model Selection/Load/Unload with `Wrap` action buttons, Runtime Process Supervision, Runtime Connection & DPAPI Pairing with explicit Keys `runtime_host_url_input` and `runtime_pairing_token_input`; preserves `updateConfiguration(...)` calls, `MODEL_LOADING` polling, `isGenerating` unload guard, and truthful `Model unloaded successfully.` feedback)
       - `SettingsStorageSection` (Storage Diagnostics inspection + truthful `PC-HOST-004` Storage Roots Relocation note)
       - `SettingsPlannedSection` (Shared parameterized widget for `Voice & Audio` [`M4`], `Tools & Safety` [`M4`], `Health & Context` [`M5+`], and `Network & Mesh` [`M5+`])
  3. **Navigation Rail `⏻` Power Menu (`DesktopNavigationRail` + `DesktopShell`):**
     - Add optional callbacks to `DesktopNavigationRail`:
       - `VoidCallback? onHideToTrayRequested`
       - `VoidCallback? onExitRequested`
       - `VoidCallback? onOpenLifecycleSettings`
     - Render a `⏻` (`Icons.power_settings_new_rounded`, key `Key('rail_power_menu_button')`) `PopupMenuButton<_RailPowerAction>` in the rail footer:
       - Expanded rail (`240px`): alongside the existing runtime status container (`Expanded` status label + `⏻` button on the trailing edge).
       - Collapsed rail (`72px`): stacked neatly above/below the status dot inside the `72px` footer with zero overflow.
     - Menu items:
       - `Minimize to System Tray` (enabled only when `coordinator?.isTrayAvailable == true`; otherwise disabled with `'Tray unavailable'` hint).
       - `Close & Startup Settings...` (navigates to `Settings -> General & Lifecycle`).
       - Divider + `Exit Companion` (triggers `onExitRequested` -> `DesktopShell._handleExitCompanion()`).
     - If `DesktopNavigationRail` is used standalone in tests without callbacks, default `onHideToTrayRequested` falls back cleanly to `coordinator?.hideToTray()`, `onOpenLifecycleSettings` falls back to `controller.openSettingsSection(SettingsSectionId.general)`, and `onExitRequested` triggers confirmation dialog -> `coordinator?.handleExitRequested()` if needed (or shared helper).
- **Contract & Schema Impact:** None (pure Flutter Desktop client refactor & UX enhancement; zero backend/OpenAPI/Alembic changes).

---

## 3. Proposed File Changes & In-Place Logic

### [MODIFY] `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`
- **Primary Responsibility:** Manage Settings active category selection and `openSettingsSection` / `scrollToDiagnostics` navigation mapping alongside theme/accent/rail/destination state.
- **Planned Change:** Import `SettingsSectionId` (from `features/settings/settings_section.dart`), add `initialSettingsSection` constructor param (default `SettingsSectionId.appearance`, overridden to `SettingsSectionId.storage` when `initialScrollToDiagnostics` is `true`), `setSettingsSection(SettingsSectionId)`, and `openSettingsSection(SettingsSectionId)`.
- **Invariants to Preserve:** Existing `themeMode`, `accentPreset`, `isRailCollapsed`, `currentDestination`, `navigationGuard`, `diagnosticReader`, `runtimeProcessState`, and `runtimeLockfileData` APIs and notification behavior remain backwards-compatible.

### [ADD] `frontend/flutter/apps/desktop/lib/features/settings/settings_section.dart`
- **Primary Responsibility:** Canonical metadata catalog for Desktop Settings categories matching Web's section architecture.
- **Planned Change:** Define `SettingsSectionId`, `SettingsSectionStatus`, `SettingsSectionMeta`, `kSettingsSections`, and pure search-filtering helper `filterSettingsSections(String query)`.
- **Invariants to Preserve:** Truthful distinction between `available` and `planned` sections with accurate milestone tags (`M4`, `M5+`).

### [ADD] `frontend/flutter/apps/desktop/lib/features/settings/settings_sidebar.dart`
- **Primary Responsibility:** Left Settings sub-navigation sidebar with search input and compact responsive chip strip.
- **Planned Change:** Implement `SettingsSidebar` supporting expanded (`width: 244`) SoftGlass panel mode with search field (`Key('settings_search_input')`) + internally scrollable (`Expanded(child: ListView(...))`) vertical category tiles (icon, title, subtitle, `AVAILABLE` / `M4` / `PLANNED` badge) + empty-search state with Reset/Clear button, and compact (`< 720px`) horizontal chip bar + search input.
- **Invariants to Preserve:** Full keyboard/mouse accessibility, clear active highlight, non-clipping text truncation, and right pane continuing to show active section even if search filters out sidebar tiles.

### [ADD] `frontend/flutter/apps/desktop/lib/features/settings/sections/settings_appearance_section.dart`
- **Primary Responsibility:** Render Color Mode (`System`/`Light`/`Dark`), Accent Color Presets, and truthful Batch 2 deferral note.
- **Planned Change:** Extract `_buildAppearanceCard` cleanly into a stateless widget taking `DesktopSettingsController`.
- **Invariants to Preserve:** Exact visible labels (`Appearance & Theme`, `Color Mode`, `Accent Color Preset`, `Light`, `Dark`, `System`, `Ocean Sky`, `Cobalt Indigo`, etc.) and live theme switching behavior.

### [ADD] `frontend/flutter/apps/desktop/lib/features/settings/sections/settings_general_section.dart`
- **Primary Responsibility:** Render Window Constraints (`1280x800 (1024x640 min)`), live System Tray status (`System Tray: Active (Close-to-Tray Active)` / `Unavailable (Close Exits App)`), non-duplicative guidance noting `⏻` rail power actions, and truthful `PC-HOST-002` Startup Planned card.
- **Planned Change:** Replace `_buildLifecycleCard` without any repeated `Hide to Tray` or `Exit Companion` action buttons.
- **Invariants to Preserve:** Accurate reflection of `coordinator?.isTrayAvailable` state.

### [ADD] `frontend/flutter/apps/desktop/lib/features/settings/sections/settings_runtime_section.dart`
- **Primary Responsibility:** Encapsulate Local LLM Model Selection/Unload/Status, Runtime Process Supervision diagnostics, and Runtime Connection / DPAPI Pairing into modular stateful/stateless section widgets.
- **Planned Change:** Move runtime/model/connection state & HTTP calls cleanly out of `settings_screen.dart` while keeping state alive across Settings tab switches (via `IndexedStack` or lifted state) and refreshing model status on Settings/Runtime entry. Convert `_buildModelEntryCard` 3-button `Row` (`settings_screen.dart:1743`) to `Wrap` so `1024x640` `1.3x` never overflows, and add explicit Keys on host URL & token inputs.
- **Invariants to Preserve:** All DPAPI token storage, URL persistence (`DesktopClientSettings`), `runtimeCoordinator.updateConfiguration(...)` & `chatController.updateConfiguration(...)` calls, `MODEL_LOADING` background polling & `Refresh Model Status`, `isGenerating` unload guard, and truthful `Model unloaded successfully.` feedback.

### [ADD] `frontend/flutter/apps/desktop/lib/features/settings/sections/settings_storage_section.dart` & `settings_planned_section.dart`
- **Primary Responsibility:** Storage diagnostics panel (`WindowsStorageDiagnosticReader` inspect cards + `PC-HOST-004` planned note) and unified parameterized `SettingsPlannedSection` card for `Voice & Audio` (`M4`), `Tools & Safety` (`M4`), `Health & Context`, and `Network & Mesh`.
- **Planned Change:** Move diagnostic root rendering & path sanitization out of `settings_screen.dart`; build one reusable `SettingsPlannedSection` widget driven by `SettingsSectionMeta`.
- **Invariants to Preserve:** Exact diagnostic labels (`Storage Diagnostics`, `Client Fail-Closed Inspection`, `Bootstrap Locator`, `Absent (Default OS Path)`, `%LOCALAPPDATA%` / `%USERPROFILE%` path sanitization).

### [MODIFY] `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart`
- **Primary Responsibility:** Top-level responsive two-column Settings container routing to the active section widget.
- **Planned Change:** Refactor from 1,848 lines down to a concise container combining the header banner (without `Hide to Tray` / `Exit` buttons), `LayoutBuilder` (`>= 720px` Row vs `< 720px` Column), `SettingsSidebar`, and active section switch (`appearance`, `general`, `notifications`, `profiles`, `runtime`, `storage`, and `planned`). Automatically handle `controller.scrollToDiagnostics` by ensuring `SettingsSectionId.storage` is active.
- **Invariants to Preserve:** Existing constructor signature (`controller`, `coordinator`, `chatController`, `profileController`, `runtimeCoordinator`, `clientSettings`, `credentialStore`, `client`, `scheduleController`) remains backward-compatible for all callers and tests.

### [MODIFY] `frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart` & `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart`
- **Primary Responsibility:** Add the `⏻` Power / Shutdown popover menu in the rail footer and wire it to `DesktopShell` lifecycle handlers.
- **Planned Change:**
  - In `DesktopNavigationRail`: add `onHideToTrayRequested`, `onExitRequested`, `onOpenLifecycleSettings`; update `_buildFooter` in both expanded (`240px`) and collapsed (`72px`) states to include the `⏻` `PopupMenuButton` (`Key('rail_power_menu_button')`) with `Minimize to System Tray`, `Close & Startup Settings...`, and `Exit Companion`.
  - In `DesktopShell`: pass `onHideToTrayRequested: () => widget.coordinator?.hideToTray()`, `onExitRequested: _handleExitCompanion`, and `onOpenLifecycleSettings: () => widget.controller.openSettingsSection(SettingsSectionId.general)` to `DesktopNavigationRail`, reusing `_handleExitCompanion` cleanly (eliminating duplicate shutdown logic).
- **Invariants to Preserve:** Zero RenderFlex overflows in both `72px` collapsed and `240px` expanded rail modes; `Minimize to System Tray` respects `coordinator?.isTrayAvailable == true`; `Exit Companion` preserves full `DesktopShutdownDialogs` confirmation + local runtime graceful/emergency shutdown guarantees.

### [MODIFY / ADD] Desktop Test Suite (`frontend/flutter/apps/desktop/test/`)
- **Primary Responsibility:** Update tests for removed Settings action buttons and categorized section navigation, and add comprehensive new unit & widget coverage.
- **Planned Change:**
  - Update `widget_test.dart`, `desktop_settings_test.dart`, `desktop_settings_runtime_supervision_test.dart`, `desktop_app_runtime_wiring_test.dart`, and `desktop_layout_responsive_test.dart` to interact with the categorized Settings sidebar, use explicit input Keys (`runtime_host_url_input`, etc.), verify responsive `1024x640` `1.2x`/`1.3x` layout across tabs & rail `⏻` footer, and test the new `⏻` rail power menu (including tray active/unavailable disabling, `Exit Companion` confirmation + runtime emergency failure handling via Shell, `Close & Startup Settings...` jump).
  - Add dedicated unit/widget tests (`test/desktop_settings_revamp_test.dart`) covering category search filtering (including empty search preserving active pane), `PLANNED` vs `AVAILABLE` badges/panels (`Voice & Audio`, `Tools & Safety`), `scrollToDiagnostics` opening `Storage & Diagnostics`, preserved runtime/model edits across tab switches, responsive `< 720px` compact mode, zero duplicate `Hide to Tray` / `Exit Companion` buttons inside Settings, and collapsed `72px` rail `⏻` footer layout (`no overflow`).

### [MODIFY] `docs/05_Design/01_PC_Desktop_Shell_and_Tray.md` & `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md` *(Phase 3)*
- **Primary Responsibility:** Keep desktop shell UX and host lifecycle documentation synchronized after implementation & verification pass.
- **Planned Change:** Update Section 2.2 / Visual Parity in `01_PC_Desktop_Shell_and_Tray.md` for the categorized Settings layout and bottom-of-rail `⏻` Power / Tray popover menu, and update `windows-host-and-notifications.md` (`lines 32, 89`) where `"Exit Companion"` moved from Settings screen into the Navigation Rail `⏻` menu alongside System Tray.
- **Invariants to Preserve:** Historical and normative D2 / PC-HOST-005 lifecycle invariants remain intact.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Phase 2 Implementation Steps:**
   - **Step 1 (RED):** Add unit tests for `DesktopSettingsController` section state / `openSettingsSection` / `scrollToDiagnostics -> storage` mapping and `filterSettingsSections` search, plus widget tests for the new `DesktopNavigationRail` `⏻` Power menu (`Minimize to System Tray`, `Close & Startup Settings...`, `Exit Companion` enabled/disabled & collapsed rail layout). Run `flutter test` to confirm expected failures.
   - **Step 2 (GREEN — Core State & Metadata):** Implement `settings_section.dart` and extend `DesktopSettingsController`.
   - **Step 3 (GREEN — Rail Footer `⏻` & Shell Wiring):** Implement `_buildFooter` `⏻` popover menu in `DesktopNavigationRail` and wire callbacks to `DesktopShell._handleExitCompanion` & `hideToTray` & `openSettingsSection`. Verify rail & shell widget tests pass.
   - **Step 4 (RED — Categorized Settings Screen):** Write widget tests for two-column `SettingsScreen` layout (`>= 720px` sidebar + `< 720px` compact mode), search filtering, `PLANNED` (`M4`) tabs, non-duplication of `Hide to Tray`/`Exit Companion` inside Settings, and each extracted section (`Appearance`, `General & Lifecycle`, `Notifications & Quiet Hours`, `Profiles & Privacy`, `AI Runtime & Models`, `Storage & Diagnostics`).
   - **Step 5 (GREEN — Modular Settings Extraction):** Create `settings_sidebar.dart` and `features/settings/sections/*`, refactor `settings_screen.dart`, and align existing tests (`desktop_settings_test.dart`, `desktop_settings_runtime_supervision_test.dart`, `desktop_app_runtime_wiring_test.dart`, `widget_test.dart`) to target the active categorized tabs cleanly and route UI exit/tray flows through the rail `⏻` menu.
   - **Step 6 (REFACTOR & CHECK):** Inspect all diffs for zero code duplication, clean early returns, docstrings, zero unused imports, zero layout overflows (`1280x800` & `1024x640`), and full green test suite + `flutter analyze`.
2. **Integration & Wiring:**
   - Verify `VisualEvidenceViewSpec` (`visual_evidence_runner.dart`), `main.dart` shortcuts (`Ctrl+,`), and tray menu + rail `⏻` menu + `DesktopShell._handleExitCompanion` integration work seamlessly together.
3. **Phase 3 Documentation & Packaging:**
   - Update `docs/05_Design/01_PC_Desktop_Shell_and_Tray.md`, `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`, and `CHANGELOG.md`, archive `docs/01_Tracking/active/task-feat-desktop-settings-revamp.md` to `docs/01_Tracking/archive/`, then push and open a Ready-for-Review PR (non-draft, as explicitly requested by Human Owner) against `develop` and await CI pass.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Flutter static analysis: `flutter analyze` inside `frontend/flutter/apps/desktop` exits with 0 issues.
- [ ] Desktop test suite: `flutter test` inside `frontend/flutter/apps/desktop` (including new Settings revamp & Rail `⏻` tests + existing Shell/Schedule/Chat/Memory/Studio tests) passes 100% with 0 failures or skipped assertions.
- [ ] Windows native build check: `flutter build windows --debug` (or release check as appropriate on CI/local) succeeds cleanly.

### Manual & Host-Level Checks (Where Applicable)
- [ ] Launch desktop app (`1280x800` and resized to `1024x640`), toggle rail expanded/collapsed, open `⏻` footer menu, verify `Minimize to System Tray`, `Close & Startup Settings...`, and `Exit Companion` work reliably.
- [ ] Navigate all active and planned Settings categories + type in `"Search settings..."`, verifying clean layout and zero duplicate `Hide to Tray` / `Exit Companion` buttons inside Settings.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *Risk:* Extracting `SettingsScreen` sub-widgets alters widget keys, init timings, or `TextField`/`Button` finders expected by runtime/model tests (`desktop_app_runtime_wiring_test.dart`, `desktop_settings_test.dart`).
    - *Mitigation:* Preserve existing explicit Keys (e.g., `alert_sound_enabled_switch`, `save_quiet_hours_button`), test labels (`Apply & Save`, `Unload Model / Free VRAM`, `Refresh Model Status`), and eager model-status/URL/DPAPI loading when switching to `Runtime` or mounting `SettingsRuntimeSection`.
  - *Risk:* `PopupMenuButton` inside collapsed `72px` `DesktopNavigationRail` overflows horizontally or vertically on smaller screens (`1024x640`).
    - *Mitigation:* Wrap footer items with compact padding/constraints (`ConstrainedBox` / `SizedBox`) and test `DesktopShell` explicitly at both `1280x800` and `1024x640` with `railCollapsed: true` and `false`.
  - *Risk:* Removing `Hide to Tray` & `Exit Companion` from `SettingsScreen` breaks legacy test expectations in `widget_test.dart` / `desktop_settings_test.dart`.
    - *Mitigation:* Migrate those assertions to test the new canonical owner (`DesktopNavigationRail` `⏻` menu wired via `DesktopShell`) and keep an explicit test asserting Settings has no duplicate `Hide to Tray` / `Exit Companion` buttons.
- **Dependencies & Assumptions:** Existing Flutter desktop workspace packages (`companion_api`, `companion_core`, `companion_design`) require no breaking changes. Batch 2 Appearance visual controls (background wallpapers, glass sliders, custom hex, density/motion) are assumed out-of-scope for this plan.
- **Required Permissions:**
  - Phase 1: Branch creation (`feat/desktop-settings-revamp`), planning commit & push to remote feature branch (already authorized by Human Owner).
  - Phase 2–3: Requires explicit Human Owner plan approval before editing production Dart files, committing/pushing Phase 2–3 work, and opening a Draft PR against `develop`.
- **Genuine Stop Conditions:** Halt immediately and consult the Human Owner on: (a) any scope expansion pulling Batch 2 Appearance sliders/wallpapers or backend M4 work into Batch 1; (b) unexpected breakage in Windows native Win32/tray channels; or (c) unresolvable test/build failures outside Desktop UI scope.
