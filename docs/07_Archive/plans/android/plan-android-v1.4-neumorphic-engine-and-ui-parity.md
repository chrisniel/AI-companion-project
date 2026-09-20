# Implementation Plan: Android V1.4 Neumorphic Engine, Glass Parity & Tactile Polish

## 1. Context & User Evidence

The user identified 10 key UI/UX issues and tactile inconsistencies across both Light and Dark modes in `temp.txt` and attached screenshots:
1. **Glass effects missing on Tasks, Assistant, and More sub-screens**: Solid `background` or `containerColor` covers up `AmbientGlassBackground`.
2. **Top area spacing inconsistency**: Double status bar padding on Home, Assistant, Settings, and Connection screens.
3. **Flat buttons and "fake border" neumorphism**: Compose `softNeumorphicRaised` only drew outline strokes instead of real dual-direction blurred drop shadows (top-left light + bottom-right dark).
4. **Far-jump navigation delay on Helio G99 / mid-range SOCs**: `animateScrollToPage` across 4 tabs forces intermediate page composition.
5. **Settings screen ignores active accent color**: Hardcoded `accentCyan` throughout `SettingsScreen.kt` rather than dynamic `accentPrimaryColor`.
6. **No custom HEX text input**: Appearance settings only provides 6 preset swatches with no input field to type or paste a custom hex code.
7. **Health / Wellness glance cards typography**: Text is too small and squeezed in the bottom left; icons need enlargement and balanced alignment.
8. **Home Quick Actions typography hero**: Remove circular icons from Ask, Add Task, Alarm, Reminder and make the text itself prominent and hero-sized.
9. **Language dropdown resets to Auto**: Home language selection is stored in a local `remember` state instead of app-level state in `AppViewModel`.
10. **Light theme neumorphic parity**: Light theme lacks the tactile clay soft dual-shadow look present in the reference banking app (`D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile`).

---

## 2. Technical Scope & Architecture

### Component 1: Authentic Dual-Shadow Neumorphic Rendering Engine (`SoftNeumorphic.kt`)
- Reference: `D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile\lib\core\theme\kk_theme.dart`.
- Replace single outline strokes with real dual drop shadows using Android hardware-accelerated `Paint` and `BlurMaskFilter` inside `drawBehind { drawIntoCanvas { ... } }`:
  - **Raised surfaces (`softNeumorphicRaised`)**:
    - Top-left light shadow: offset `(-dx, -dy)` with light specular blur (`#FFFFFF` in light mode; `#56606B` in dark mode).
    - Bottom-right dark shadow: offset `(+dx, +dy)` with dark ambient blur (`#9EA3A1` in light mode; `#000000` / `#0E1115` in dark mode).
    - Face gradient: subtle directional gradient from top-left to bottom-right.
    - Floating Assistant action button receives boosted elevation (8dp blur, 5dp offset).
  - **Recessed wells (`softInsetWell`)**:
    - Top-left inward dark shadow + bottom-right inward light reflection.
  - **Eliminate artificial glowing borders**: Replace high-contrast solid borders with subtle 0.5dp specular hairlines.

### Component 2: Translucent Glass Parity Across All Screens
- Remove opaque `.background(SoftTheme.colors.background)` and `containerColor = SoftTheme.colors.background` from `TasksScreen.kt`, `AssistantScreen.kt`, `ScheduleScreen.kt`, `AlarmsScreen.kt`, `SettingsScreen.kt`, `ConnectionScreen.kt`, `CharactersScreen.kt`, and `PermissionsScreen.kt`.
- Ensure all screens allow `AmbientGlassBackground` to shine through consistently.

### Component 3: Single-Source Top Inset & Spacing Normalization
- Configure outer `Scaffold` in `AppShell.kt` with `contentWindowInsets = WindowInsets(0, 0, 0, 0)` so top bars and screens control their own padding without double status bar accumulation.
- Normalize top padding across Home, Assistant, Tasks, Health, and More so all headers align at the exact same vertical baseline.

### Component 4: Persistent Language State & Synchronization
- Lift `selectedLanguage: LanguageOption` into `AppViewModel` (or `AppearanceRepository`).
- Wire Home dropdown pill and Assistant composer to read and update this single source of truth, persisting across tab navigation.

### Component 5: Dynamic Accent Color in Settings & Custom Hex Input
- Replace all instances of `SoftTheme.colors.accentCyan` in `SettingsScreen.kt` with `SoftTheme.colors.accentPrimaryColor`.
- Add an `OutlinedTextField` with hex validation and live color preview swatch in Settings -> Appearance -> Custom Accent Hex.

### Component 6: Home Screen Typography & Quick Actions
- Remove circular icon buttons from `HomeQuickActionsGrid` (Ask, Add Task, Alarm, Reminder) and style them as large, bold, tactile text hero cards.
- Restructure `WellnessGlanceCard`: enlarge main telemetry numbers (24sp bold), center data vertically and horizontally within the card, and enlarge header icons.

### Component 7: Helio G99 Performance & Far-Jump Tab Navigation
- In `AppShell.kt`: For tab jumps with `abs(currentPage - targetIndex) > 1`, invoke `pagerState.scrollToPage(targetIndex)` directly, avoiding expensive multi-page flyby composition.
- Retain spring fling for 1:1 finger swipe gestures.

---

## 3. Affected Files

1. `android/app/src/main/java/com/example/ui/components/SoftNeumorphic.kt` — Real dual drop shadow engine with `BlurMaskFilter`.
2. `android/app/src/main/java/com/example/ui/shell/AppShell.kt` — Inset normalization, far-jump tab logic.
3. `android/app/src/main/java/com/example/ui/shell/AppViewModel.kt` — App-wide persistent `selectedLanguage`.
4. `android/app/src/main/java/com/example/ui/screens/HomeScreen.kt` — Hero text quick actions, balanced wellness cards, persistent language dropdown.
5. `android/app/src/main/java/com/example/ui/screens/tasks/TasksScreen.kt` — Remove opaque background fill.
6. `android/app/src/main/java/com/example/ui/screens/AssistantScreen.kt` — Remove opaque background fill.
7. `android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt` — Dynamic `accentPrimaryColor`, custom hex input field.
8. `android/app/src/main/java/com/example/ui/theme/Color.kt` — Calibrated light theme clay canvas tokens (`#ECEDE9` / `#E5E6E2`).
9. `android/app/src/main/java/com/example/ui/screens/schedule/ScheduleScreen.kt`, `AlarmsScreen.kt`, `ConnectionScreen.kt` — Transparent containers.
10. `android/app/src/test/java/com/example/*` — Test suite updates.

---

## 4. Acceptance Criteria & Verification Plan

### Automated Tests:
- Run `./gradlew.bat testDebugUnitTest` — All 109 tests must pass.
- Add/update unit tests for custom hex input validation and persistent language selection.

### Physical Device Verification (Infinix X6820):
1. Verify dual-shadow depth on buttons and floating Assistant button in both dark and light modes.
2. Verify glass ambient background is visible on Tasks, Assistant, and More screens.
3. Verify top spacing is uniform across Home, Tasks, Assistant, and sub-screens.
4. Verify tapping More from Home jumps immediately without intermediate page stutter.
5. Verify changing accent color immediately recolors Settings switches and selections.
6. Verify typing `#10B981` in custom hex input applies Emerald green immediately.
7. Verify Home Quick Actions have bold hero text without icons.
8. Verify Wellness cards have larger, centered typography.
9. Verify selecting Filipino/Japanese in Home dropdown remains selected after navigating away.
