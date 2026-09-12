# Walkthrough: Android Scroll Fluidity, Direction-Aware Transitions, Neumorphic Depth, OLED Parity & Vault Popover

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Implement direction-aware spring slide transitions on bottom navigation tabs matching Settings, rename and tune Neumorphic Visual Effects, enforce OLED Battery Saver and Reduced mode parity on buttons/pills, make Mobile Background options horizontally scrollable, decouple background layer from Scaffold to prevent scroll resets, fix custom gallery image decoding, clip overscroll motion strictly within viewports, and wire the floating animated Vault popover overlay across all screens.
- Audience: User, developer, Android maintainer, QA
- Status: Implemented & Automated Verification Passed (Manual device verification ready on Infinix ZERO ULTRA)
- Last Updated: 2026-09-12

---

## 1. What Was Delivered

- **Assistant Tab Autoscroll Elimination**: In `AssistantScreen.kt`, initialized `listState` with `initialFirstVisibleItemIndex = maxOf(0, uiState.messages.size - 1)` so entering or swiping into the Assistant workspace is instantly positioned at the latest message with zero animated scrolling lag. `animateScrollToItem` is now selectively triggered only when new messages are appended or during active LLM token generation.
- **Custom UI Wallpaper Frosted Blur**: In `AppShell.kt`, added `Modifier.blur(18.dp, BlurredEdgeTreatment.Unbounded)` to custom photo wallpapers, giving user gallery backgrounds the authentic frosted glass aesthetic matching built-in aura presets.
- **Viewport-Level Floating Vault Popover on Home**: Replaced the inline column layout expansion in `HomeScreen.kt` with a direct trigger to the root `VaultPopoverOverlay`, ensuring the Vault displays as a floating glassmorphic popover with a dismissible scrim without shifting or pushing down home feed content.
- **Real-Time 1:1 Swipe Tracking**: Implemented dynamic touch translation (`swipeOffset` with `graphicsLayer { translationX }`) across root destinations in `AppShell.kt`, providing immediate visual feedback as the user drags their finger horizontally, with natural spring snapping to destination.
- **Direction-Aware Spring Slide Bottom Nav Transitions**: Aligned bottom navigation transitions in `AppShell.kt` with `AnimatedContent` direction-aware spring physics (`dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow`, `slideInHorizontally(it/3) + fadeIn(220)` & `slideOutHorizontally(-it/4) + fadeOut(180)`), matching the fluid physics of `SettingsSectionTabs`.
- **"NEUMORPHIC VISUAL EFFECTS" Header & Semantic Depth**: Renamed the visual effects header in Settings Appearance from `"GLASS VISUAL EFFECTS"` to `"NEUMORPHIC VISUAL EFFECTS"`. In `Reduced` mode, cards, buttons, and pills reduce shadow depth (`depth = 1.dp`, `isLightweight = true`) while preserving glass specular highlights and ambient aura glow.
- **OLED Battery Saver & Reduced Button/Pill Parity**: `SelectablePill`, `SelectionCardItem`, and `SettingsSectionTabs` in `SettingsScreen.kt` now strictly honor `SoftTheme.colors.isOled` (rendering as flat obsidian `#121214` containers with subtle hairline `#1F1F23` borders and zero drop shadows) and `EffectsLevel.REDUCED` (`isLightweight = true`).
- **Horizontally Scrollable Mobile Background Pills**: Added `.horizontalScroll(rememberScrollState())` to the Mobile Background row in `SettingsScreen.kt` so the 4th option (`[Solid]`) is no longer cut off at the right edge and can be smoothly swiped and selected.
- **Decoupled Background Layer & Custom Image Decoding**: Decoupled `AppBackgroundLayer` beneath `renderScaffold()` in a unified root `Box`. Switching background types or themes never recreates the Scaffold, preserving scroll state completely. Fixed custom wallpaper decoding by removing invalid `.jpg`/`.png` rejection, decoding gallery photos into software bitmaps, and rendering beneath transparent glass with user contrast scrim.
- **Strict Overscroll Viewport Boundary Clipping**: Added `.clipToBounds()` before `.graphicsLayer` in `SoftBounceOverscroll.kt`, ensuring overscroll bounce motion strictly stays within its scrollable viewport without rendering over top bars or tabs.

## 2. Files Changed

- `android/app/src/main/java/com/example/ui/screens/AssistantScreen.kt` — Pre-positioned `listState` at latest message on initial load; selectively animated scroll only for new messages or token generation.
- `android/app/src/main/java/com/example/ui/screens/HomeScreen.kt` — Removed inline layout expansion card; wired avatar click to trigger root floating Vault overlay.
- `android/app/src/main/java/com/example/ui/shell/AppShell.kt` — Added 1:1 real-time horizontal drag tracking (`swipeOffset`); wired `HomeScreen(..., onAvatarClick = ...)`; added `Modifier.blur(18.dp)` to custom wallpaper; aligned bottom nav transitions.
- `android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt` — Renamed header to `"NEUMORPHIC VISUAL EFFECTS"`; added `.horizontalScroll(rememberScrollState())` to Mobile Background row; updated `SelectablePill`, `SelectionCardItem`, and `SettingsSectionTabs` to honor `isOled` and `isLightweight`.
- `android/app/src/main/java/com/example/ui/components/SoftBounceOverscroll.kt` — Added `.clipToBounds()` to ensure overscroll translations never bleed over top navigation bars or headers.
- `android/app/src/main/java/com/example/navigation/AppTopBar.kt` — Added accessibility click label `"Open Vault and Profile"` to avatar button.
- `docs/01_Tracking/task.md` — Updated active sprint checklist in-place.
- `CHANGELOG.md` — Appended release entries under `[Unreleased]`.

## 3. How the Logic Works

1. **Event trigger**:
   - Tapping bottom navigation tabs, swiping horizontally, scrolling lists with overscroll bounce, tapping background pills, or tapping the top bar avatar.
2. **Validation**:
   - Direction detection: `targetState > initialState` calculates the animation direction forward or backward for horizontal slide and fade.
   - Background stability: `AppBackgroundLayer` observes `preferences` independently from `renderScaffold()`, preventing composable hierarchy recreation.
   - Gallery photo decoding: Validates URI, resizes to a maximum dimension of 1920px with software allocation, and gracefully handles missing/corrupt files.
3. **Core processing**:
   - **Direction-Aware Transition**: `slideInHorizontally(if (forward) it/3 else -it/3) + fadeIn(220)` together with `slideOutHorizontally(if (forward) -it/4 else it/4) + fadeOut(180)` using spring physics (`dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow`).
   - **OLED Surface Parity**: In `OLED_BATTERY_SAVER`, neumorphic modifier returns `Modifier` (zero shadows), background becomes `#121214` obsidian, and borders use `#1F1F23` hairline strokes.
   - **Viewport Clipping**: `.clipToBounds()` applies viewport boundaries so `translationY` in `graphicsLayer` never draws past the component container bounds.
   - **Vault Popover Overlay**: `VaultPopoverOverlay` enters via spring scale (`0.85f -> 1.0f`) + fade and exits via spring scale (`1.0f -> 0.88f`) + fade, overlaying a dimming scrim and card with on-device SQLite encryption status.
4. **Completion**:
   - Bottom navigation switches smoothly and instantly with the exact physics of Settings tabs. Background changes preserve scroll position. Custom gallery images show under glass. Overscroll never bleeds into headers.
5. **Recovery/cancellation**:
   - Tapping outside the Vault Popover immediately dismisses the overlay. Overscroll momentum animations cancel immediately upon finger touch-down.

## 4. Key Concepts

- **Direction-Aware AnimatedContent vs. Linear Paging**: `HorizontalPager` is designed for document-like carousels where all intervening pages must be physically paged through. `AnimatedContent` allows any destination index to transition directly to any other with direction-aware slide and fade physics, eliminating intermediate layout spikes.
- **Decoupled Background Substrate**: When composables that manage local scroll state (e.g. `rememberScrollState()`) are wrapped inside conditional blocks (`when (backgroundType)`), every condition change triggers a full disposal and recreation of the inner composables, resetting scroll state to zero. Decoupling the background into an independent peer substrate preserves the entire foreground composition and state.
- **Overscroll Viewport Clipping**: `graphicsLayer` operations in Android Compose translate the drawing layer without clipping to container bounds by default. Applying `.clipToBounds()` enforces a hardware clip rect that prevents translated pixels from drawing over sticky headers or navigation bars.

## 5. Verification Steps

### Automated Checks

- [x] `.\gradlew.bat testDebugUnitTest` — Passed (all unit and Robolectric tests executed and succeeded with zero failures in 1m 26s).
- [x] `.\gradlew.bat assembleDebug` — Passed (fresh debug APK assembled in `android/app/build/outputs/apk/debug/app-debug.apk` in 5s).

### Manual / User-Owned Checks

- [ ] Step 1: Install the fresh debug APK on the physical Infinix ZERO ULTRA (`adb install -r android/app/build/outputs/apk/debug/app-debug.apk` or run command below).
- [ ] Step 2: Test Assistant Tab Entry (No Autoscroll Lag):
  - Tap or swipe into **Assistant**: verify the conversation is immediately sitting at the bottom without any visible downward scrolling animation. Type a message; verify it smoothly auto-scrolls down only when a new message is sent.
- [ ] Step 3: Test Real-Time 1:1 Horizontal Swiping:
  - Drag your finger slowly left or right across the screen: verify the current screen immediately follows your finger in real time (`translationX = swipeOffset`). If dragged past threshold, it smoothly snaps to the next screen; if released early, it springs back to center.
- [ ] Step 4: Test Bottom Navigation Direct Spring Transitions:
  - From **Home** (tab 0), tap **More** (tab 4): verify smooth, direction-aware spring slide & fade directly into More without flashing intermediate tabs.
  - From **More**, tap **Home**: verify smooth slide in reverse direction.
- [ ] Step 5: Test Floating Vault Overlay from Home:
  - On the **Home** screen, tap the user avatar: verify the floating `VaultPopoverOverlay` appears above the entire viewport with a darkened scrim, without pushing down or shifting any feed cards. Tap the scrim to dismiss.
- [ ] Step 6: Test Custom Photo Wallpaper Frosted Blur:
  - In Settings -> Appearance, select **Custom Image UI**, tap **"Choose Photo from Device"**, pick a photo: verify the photo loads with an authentic frosted blur (`18.dp`) beneath the glass UI cards.
- [ ] Step 7: Test Settings Header & Scrollable Background Row:
  - In Settings -> Appearance, verify the section header reads **"NEUMORPHIC VISUAL EFFECTS"**.
  - In Mobile Background row, swipe horizontally: verify **`[Solid]`** is fully visible and selectable.
- [ ] Step 8: Test Scroll State Preservation:
  - Scroll halfway down Settings, tap background options: verify the screen does **NOT** reset to the top.
- [ ] Step 9: Test OLED Mode Button Parity:
  - Select **OLED Battery Saver** theme: verify all buttons and pills (`SelectablePill`, `SelectionCardItem`, `SettingsSectionTabs`) are flat obsidian with zero drop shadows.
- [ ] Step 10: Test Overscroll Clipping:
  - Scroll rapidly at the top or bottom of Settings or Tasks: verify content bounces smoothly without drawing over the top bar or tabs.

## 6. Safe Customization & Invariants

- **Tunable Parameters**:
  - Transition Physics: In `AppShell.kt`, adjust `stiffness = Spring.StiffnessMediumLow` or `dampingRatio = 0.82f` in `AnimatedContent` if you wish to tune transition snappiness.
  - Scrim Opacity: In Settings -> Appearance, the background scrim slider tunes wallpaper opacity for maximum contrast.
- **Invariants**:
  - Changing background types or theme modes must never dispose of `renderScaffold()` or reset scroll positions.
  - Tapping top bar avatar buttons across all screens must always open the Vault Popover.
  - Overscroll translations must always be clipped within their scrollable containers.

## 7. Troubleshooting

- Symptom: Custom image does not display after picking.
  - Likely cause: The file URI returned by the device photo picker was not granted persistable read permissions or the file format is unsupported.
  - Resolution: The app automatically executes `takePersistableUriPermission` and uses `ImageDecoder` for hardware-accelerated decoding. If an issue occurs, the fallback `AmbientGlassBackground` displays safely without crashing.
- Symptom: Bottom navigation tabs flash during rapid tapping.
  - Likely cause: Multiple destination taps within a few milliseconds.
  - Resolution: `AnimatedContent` gracefully cancels and retargets animations with spring physics.
