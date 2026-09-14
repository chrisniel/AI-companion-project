# Implementation Plan: Android Bottom Navigation Slide Transitions, Neumorphic Effects, Button Theming, Vault Popover & Viewport Clipping

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Feature Name: Android Visual Effects, Vault Popover, Button Theming & Smooth Transitions
- Status: Planned (Awaiting User Review)
- Scope Guard: Touch physics, overscroll clipping, background persistence, appearance settings, button components, and vault popover overlay.

---

## 1. Skill Routing Summary (via `skill-router-execution-planner`)
- **Primary Skill**: `bug-investigation` (evidence-based root-cause diagnosis of the reported UI/UX regressions and transitions).
- **Supporting Skill**: `acceptance-criteria` (explicit testable criteria for all 7 reported items before code changes).

---

## 2. Bug Investigation & Evidence Analysis

### Issue 1: Bottom Navigation Traversal vs. Settings Smooth Slide Transition
- **Symptom**: Bottom navigation tabs do not have the smooth, flawless slide transition seen in Settings sections (`SettingsSectionTabs`). When tapping non-adjacent tabs, it snaps with `scrollToPage(targetIndex)`.
- **Root Cause**: In `SettingsScreen.kt`, switching sections uses `AnimatedContent` with `slideInHorizontally` + `slideOutHorizontally` + `fadeIn`/`fadeOut` with spring physics (`dampingRatio = 0.82f`, `stiffness = Spring.StiffnessMediumLow`). In contrast, `AppShell.kt` relied on `HorizontalPager`, where `scrollToPage` has zero transition, while `animateScrollToPage` forced physical camera traversal through intermediate screens 1, 2, 3.
- **Solution**: Implement the same direction-aware `AnimatedContent` slide/fade transition for root destination switching, or synchronize the bottom navigation transition with a smooth slide transition matching the exact formula of `SettingsSectionTabs`, while keeping gesture swiping intact.

### Issue 2: "GLASS VISUAL EFFECTS" Naming & Effects Semantics
- **Symptom**: The header in Settings still reads "GLASS VISUAL EFFECTS".
- **Root Cause**: Hardcoded string `"GLASS VISUAL EFFECTS"` in `SettingsScreen.kt:703`.
- **Solution**: Change header text to `"NEUMORPHIC VISUAL EFFECTS"`.

### Issue 3: Buttons and Pills Not Respecting `Reduced` or `OLED Battery Saver`
- **Symptom**: Buttons and pills (e.g. `SelectablePill`, `SelectionCardItem`, `SettingsSectionTabs`) maintain full 3D neumorphic drop shadows even in `Reduced` and `OLED Battery Saver` modes.
- **Root Cause**: In `SettingsScreen.kt`, `SelectablePill` (lines 2068–2078), `SelectionCardItem` (lines 2115–2125), and `SettingsSectionTabs` (lines 334–342) directly call `Modifier.softNeumorphicRaised` and `Modifier.softNeumorphicInset` without checking `SoftTheme.colors.isOled` and without passing `isLightweight = (SoftTheme.tokens.effectsLevel == EffectsLevel.REDUCED)`.
- **Solution**:
  - In `OLED` mode: Remove drop shadows and inset shadows completely. Render flat obsidian containers (`#121214`) with subtle hairline borders (`#1F1F23`).
  - In `Reduced` mode: Pass `isLightweight = true` to `softNeumorphicRaised` and `softNeumorphicInset`, reducing shadow factor to flat minimal depth.

### Issue 4: Background Selection Cut Off on Right Edge (`[Solid]`)
- **Symptom**: In Settings -> Appearance -> Mobile Background, the buttons show `[Built-in]`, `[Custom Image UI]`, `[Gradient]`, but the 4th option is partially cut off and cannot be scrolled horizontally.
- **Root Cause**: In `SettingsScreen.kt:736`, the `Row` holding `BackgroundType.entries` is rendered with `fillMaxWidth()` but lacks `.horizontalScroll(rememberScrollState())`.
- **Solution**: Add `.horizontalScroll(rememberScrollState())` to the `Row`, allowing smooth horizontal swiping across all background types including `[Solid]`.

### Issue 5: Custom Image Not Displaying & Screen Resetting/Scrolling to Top on Click
- **Symptoms**:
  1. Selecting a custom image from gallery does nothing (blank or doesn't show).
  2. Clicking on background options resets the screen scroll position back to top.
- **Root Causes**:
  1. In `AppShell.kt:660`, `if (customImageUri.isNullOrBlank() || customImageUri.endsWith(".jpg") || customImageUri.endsWith(".png")) null` explicitly returns `null` for any image filename ending in `.jpg` or `.png`!
  2. In `AppShell.kt:700`, `AmbientGlassBackground` was rendered over the image and draws an opaque background color `SoftTheme.colors.background`, covering the custom photo.
  3. In `AppShell.kt`, the root layout evaluated `when (preferences.backgroundType) { ... }` wrapping `renderScaffold()`. Every time the user clicked a background type, the entire Scaffold, NavHost, and SettingsScreen were destroyed and recreated, resetting `rememberScrollState()` to 0.
- **Solution**:
  - Fix URI decoding logic to decode all valid content/file URIs safely.
  - Render the custom photo with user brightness/scrim directly beneath the transparent scaffold.
  - Decouple the background layer from `renderScaffold()` so changing background type does NOT recreate the composable tree or reset scroll position.

### Issue 6: Overscroll Translating Above Navigation Bars / Headers
- **Symptom**: When scrolling or flinging, the content translates up and overlays above `SettingsSectionTabs` and the top bar instead of remaining clipped within the scroll viewport.
- **Root Cause**: `SoftBounceOverscroll.kt:185` applied `graphicsLayer { translationY = offsetState }` to the scrollable container without applying `.clipToBounds()`, and `SettingsSectionTabs` had no opaque backing.
- **Solution**: Add `.clipToBounds()` before the graphics layer in `SoftBounceOverscroll.kt` and ensure the scroll container clips strictly within its bounds.

### Issue 7: User Avatar Reversion to Vault Popover Overlay
- **Symptom**: The top bar avatar was navigating to Settings or displaying as a plain User icon instead of acting as the Vault trigger.
- **Root Cause**: In `AppTopBar.kt` and `AppShell.kt`, clicking `onAvatarClick` navigated directly to `Routes.SETTINGS`. In `HomeScreen.kt`, the Vault popover was rendered inside the `HomeHeaderGreeting` column.
- **Solution**: Connect the top bar avatar to open the floating animated glassmorphic Vault Popover overlay across all screens, displaying encrypted on-device SQLite vault status, host connection status, and a quick settings link.

---

## 3. Acceptance Criteria (via `acceptance-criteria`)

### AC-1: Bottom Navigation Transitions
- [ ] Tapping non-adjacent bottom navigation items (e.g. Home -> More) transitions smoothly with direction-aware horizontal slide and fade matching the responsiveness and physics of the Settings tabs.
- [ ] 1:1 physical touch swiping between adjacent screens remains functional.

### AC-2: Neumorphic Visual Effects Naming & Depth
- [ ] Section title in Settings -> Appearance displays "NEUMORPHIC VISUAL EFFECTS".
- [ ] `Reduced (Lightweight)` reduces dual-shadow depth across all cards, pills, and buttons while preserving glass specular highlights and ambient aura.
- [ ] `Normal` retains tactile 3D clay depth; `Enhanced` provides deep contrast shadows.

### AC-3: OLED Mode Button & Card Parity
- [ ] In `ThemeMode.OLED_BATTERY_SAVER`, all buttons (`SelectablePill`, `SelectionCardItem`, `SettingsSectionTabs`, `PrimaryButton`, `SoftGlassButton`) render as flat obsidian surfaces with zero drop shadows.

### AC-4: Horizontal Scroll for Background Options
- [ ] The Mobile Background pill row in Settings supports horizontal scrolling so all 4 options (`[Built-in]`, `[Custom Image UI]`, `[Gradient]`, `[Solid]`) are fully visible, readable, and selectable.

### AC-5: Custom Wallpaper Decoding & Scroll State Preservation
- [ ] Choosing an image via "Choose Photo from Device" decodes correctly and displays full-screen behind the glass scaffold.
- [ ] Clicking any background option (`Built-in`, `Custom Image UI`, `Gradient`, `Solid`) does NOT reset the scroll position of SettingsScreen.

### AC-6: Viewport Clipping on Overscroll
- [ ] Content during scroll and bounce overscroll never draws over or behind `SettingsTopBar` or `SettingsSectionTabs`. All motion is clipped strictly within the scrollable viewport.

### AC-7: Vault Popover Overlay
- [ ] Tapping the top bar Avatar/Vault button opens the animated floating glassmorphic Vault Popover overlay.

---

## 4. Proposed Changes

### [Component: UI Navigation & Shell]
#### [MODIFY] [AppShell.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppShell.kt)
- Decouple background layer from `renderScaffold()` so switching backgrounds does not destroy the Scaffold / NavHost / scroll state.
- Render custom wallpaper photo with proper contrast scrim.
- Connect global Vault popover overlay triggered by the top bar avatar.
- Align bottom navigation transitions with direction-aware slide/fade.

### [Component: Overscroll Physics]
#### [MODIFY] [SoftBounceOverscroll.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/components/SoftBounceOverscroll.kt)
- Add `.clipToBounds()` to ensure translated/bounced content never bleeds outside viewport bounds.

### [Component: Settings UI & Theming]
#### [MODIFY] [SettingsScreen.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt)
- Rename header to "NEUMORPHIC VISUAL EFFECTS".
- Add `.horizontalScroll(rememberScrollState())` to the Mobile Background row.
- Update `SelectablePill`, `SelectionCardItem`, and `SettingsSectionTabs` to honor `isOled` (zero shadows) and `EffectsLevel.REDUCED` (lightweight shadows).

### [Component: Top Bar & Vault Popover]
#### [MODIFY] [AppTopBar.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/navigation/AppTopBar.kt)
- Update avatar button to represent the Vault and trigger the Vault Popover.

---

## 5. Verification Plan

### Automated Checks
- `.\gradlew.bat testDebugUnitTest` to verify all 110+ Robolectric unit tests pass.
- `.\gradlew.bat assembleDebug` to verify compilation and produce fresh debug APK.

### Manual Device Verification
1. Install fresh APK on Infinix ZERO ULTRA (`adb install -r android/app/build/outputs/apk/debug/app-debug.apk`).
2. Test bottom nav tabs: verify smooth slide transition without intermediate screen flashes.
3. Test Settings Appearance: verify "NEUMORPHIC VISUAL EFFECTS" title, horizontally scrollable background pills showing `[Solid]`, and selecting options without page scrolling to top.
4. Test Custom Wallpaper: pick gallery photo and verify it displays full-screen under glass.
5. Test Overscroll: scroll up and down rapidly; verify content never bleeds over top bar.
6. Test Vault: tap Avatar in top bar; verify floating Vault popover appears.
