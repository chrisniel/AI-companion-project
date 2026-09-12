# Implementation Plan: Android 120Hz Refresh Rate, Light Palette, Neumorphic Depth, Vault Popover & Spring Physics

## Executive Summary

Based on the feedback in `temp.txt` and user requests, this plan addresses six core visual, interaction, physics, and display performance items in the Android client:

1. **120Hz High Refresh Rate Synchronization & Window Unlocking**:
   - **Diagnosis**: Physical device inspection via `adb shell dumpsys display` confirmed that the display has `modeId 1 (120Hz)` and `modeId 2 (60Hz)`. The app was running locked in `modeId 2 (60.0 fps)` because the window did not request dynamic display modes or high-refresh-rate capability, causing the Infinix XOS display manager to cap it at 60Hz.
   - **Solution**: Implement `RefreshRateMode` in `AppearanceRepository` and `MainActivity` (`System Dynamic`, `Force High 120Hz`, `Battery Saver 60Hz`). In Dynamic/High mode, unlock `window.attributes.preferredDisplayModeId` to match the display's 120Hz mode and clear minimum/maximum constraints so the phone system dictates 120Hz fluidity.
   - **Industry Standards**: Implement lambda-based drawing (`graphicsLayer`), zero-allocation canvas caching, immutable models, and edge-to-edge hardware acceleration to maintain a rock-solid 8.33ms frame budget at 120fps.
2. **Neumorphic Treatment for Tasks & Health**:
   - Upgrade `TaskRowItem`, `ScheduleEntryCard`, `HealthMetricCard`, `HealthSourceCard`, and `WellnessInsightsCard` from flat containers to authentic neumorphic clay cards (`SoftGlassCard` with directional dual shadows and tactile elevations).
3. **Light Mode Matte Off-White Palette & Contrast Calibration**:
   - Rework `Color.kt` and `Theme.kt` for Light Mode so containers are a tactile matte off-white/clay (not blinding `#FFFFFF`), drop shadows and specular highlights are balanced without washout, and typography (`TextPrimaryLight`, `TextSecondaryLight`, `TextMutedLight`) achieves crisp WCAG readability across all Settings tabs and screens.
4. **User Profile "Vault-Like" Popover Overlay**:
   - Replace the in-line accordion dropdown on `HomeScreen` (which pushed down home content) with an animated, floating glassmorphic "Vault" overlay dialog with subtle frosted glass, hairline borders, zero muddy shadows, and bouncy scale/fade pop-in animations.
5. **Elastic Spring Bounce Physics (Overscroll & Micro-interactions)**:
   - Implement `Modifier.softBounceOverscroll()` using Compose `NestedScrollConnection` and `Animatable` spring physics (`dampingRatio = Spring.DampingRatioMediumBouncy`) inspired by [Jitter UI elements](https://jitter.video/templates/ui-elements/), where list contents pull outside container limits and spring back like a ball.
6. **Incremental Code-Push / Live Color Tweaking Strategy**:
   - Add an interactive "Live Theme Color Inspector" sheet in the Design System Catalog for zero-compile-time palette experimentation directly on the device.

---

## 1. Skill Routing & Execution Architecture

- **Primary Skill**: `feature-implementation` (coordinates multi-file frontend architecture, tokens, components, and screen updates).
- **Supporting Skills**:
  - `performance-optimization` (unlocks 120Hz display modes, eliminates 8.33ms frame drops, defers state reads via `graphicsLayer`, and caches canvas paints).
  - `responsive-ui` (guarantees safe margins, zero clipping, and clean wrapping across display aspect ratios).
  - `state-management` (clean overlay state management, overscroll delta tracking, and theme preference propagation).
  - `acceptance-criteria` (defines observable pass/fail criteria for 120Hz rendering, Light Mode, and animation behaviors).

---

## 2. Proposed Changes & Affected Files

### Component 1: 120Hz High Refresh Rate Windowing & Industry Performance Standards
#### [MODIFY] [`SettingsModels.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/SettingsModels.kt)
- Add `RefreshRateMode` enum:
  - `SYSTEM_DEFAULT`: "System Dynamic" (lets phone system display settings dictate 120Hz/60Hz adaptively).
  - `FORCE_HIGH`: "Force High (120Hz / 90Hz)" (explicitly requests highest available `Display.Mode` from display hardware).
  - `POWER_SAVER`: "Standard (60Hz)" (locks to 60Hz for battery conservation).
- Add `refreshRateMode: RefreshRateMode = RefreshRateMode.SYSTEM_DEFAULT` to `AppearancePreferences`.

#### [MODIFY] [`MainActivity.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/MainActivity.kt)
- Implement display mode synchronizer:
  - Query `display.supportedModes`.
  - When `FORCE_HIGH` or `SYSTEM_DEFAULT`, configure `window.attributes.preferredDisplayModeId` with the 120Hz mode ID (mode 1 on Infinix X6820) and clear `preferredMinDisplayRefreshRate` / `preferredMaxDisplayRefreshRate`.
  - Ensure `android:hardwareAccelerated="true"` is declared on Activity/Application in `AndroidManifest.xml`.

#### [MODIFY] [`SettingsScreen.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt)
- Add "DISPLAY REFRESH RATE" selection section under Appearance tab with `SelectionCardItem` choices.

---

### Component 2: Light Theme Foundations & Color Tokens
#### [MODIFY] [`Color.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/theme/Color.kt)
- Retune Light Mode foundations:
  - `BackgroundPearl` = `#E6E9E5` (warm matte clay canvas).
  - `MilkySurfaceElevated` = `#EDF0EB` (matte clay card container—restrained off-white, not blinding pure white).
  - `MilkySurfaceBase` = `#E2E5E0` (structural container base).
  - `MilkySurfaceWell` = `#D6DAD3` (sunken tactile well for input fields and selected chips).
  - `BorderLight` = `0x40FFFFFF` (delicate specular top rim).
  - `BorderSubtleLight` = `0x1F000000` (subtle dark hairline for crisp edge definition on light surfaces).
  - `ShadowLight` = `0x38737A75` (rich ambient slate shadow with depth).
  - `ShadowLightSpecular` = `0xB3FFFFFF` (controlled 70% specular highlight that doesn't bleed into haze).
  - `TextPrimaryLight` = `#0F172A` (deep slate obsidian, high contrast).
  - `TextSecondaryLight` = `#334155` (strong charcoal slate).
  - `TextMutedLight` = `#64748B` (readable medium slate).

#### [MODIFY] [`Theme.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/theme/Theme.kt)
- Calibrate Light Mode shadow and specular alphas in `SoftGlassColors` when scaling across `EffectsLevel` options.

---

### Component 3: Authentic Neumorphism on Tasks & Health
#### [MODIFY] [`TaskRowItem.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/tasks/TaskRowItem.kt)
- Replace flat `Box` container with `SoftGlassCard(elevation = SoftTheme.tokens.elevations.card)` or `softNeumorphicRaised` modifier.
- Apply `softNeumorphicInset` when task is completed.

#### [MODIFY] [`ScheduleScreen.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/schedule/ScheduleScreen.kt)
- Upgrade `ScheduleEntryCard` to use `SoftGlassCard(elevation = SoftTheme.tokens.elevations.card)`.
- Apply neumorphic pill styling to `FilterChip` items (raised unselected, sunken well when selected).

#### [MODIFY] [`HealthMetricCard.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/health/HealthMetricCard.kt), [`HealthSourceCard.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/health/HealthSourceCard.kt), [`WellnessInsightsCard.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/health/WellnessInsightsCard.kt)
- Upgrade card containers to use `SoftGlassCard` with physical dual-shadow depth.

---

### Component 4: User Avatar "Vault-Like" Popover Overlay
#### [MODIFY] [`HomeScreen.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/HomeScreen.kt)
- Remove in-line `AnimatedVisibility` expansion from `HomeHeaderGreeting`.
- Introduce `VaultProfilePopoverDialog`:
  - Renders as a true overlay floating over Home contents with a subtle dimmed backdrop scrim.
  - Plain glassmorphism: frosted translucent surface, delicate hairline border, zero heavy muddy shadows.
  - Bouncy pop-in animation: scale `0.82f` -> `1.0f` with `Spring.DampingRatioMediumBouncy` + fade.
  - Displays user profile, encrypted on-device SQLite vault status, connection telemetry, and quick settings link.

---

### Component 5: Elastic Overscroll Bounce Physics
#### [NEW] [`SoftBounceOverscroll.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/components/SoftBounceOverscroll.kt)
- Create `Modifier.softBounceOverscroll()` using `NestedScrollConnection`:
  - Tracks overscroll when pulling past top/bottom list limits.
  - Translates list contents with rubber-band resistance (`delta * 0.35f`).
  - Releases with an elastic spring animation (`dampingRatio = Spring.DampingRatioMediumBouncy`) so content visibly pulls outside its container bounds and bounces back like a ball (Jitter UI style).
  - Executed via `Modifier.graphicsLayer { translationY = ... }` to ensure locked 120fps rendering with zero recompositions.
- Wire into `HomeScreen`, `ScheduleScreen`, `HealthScreen`, and `SettingsScreen`.

---

### Component 6: Live Color Tweaker in Design Catalog
#### [MODIFY] [`DesignSystemPreviewScreen.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/design/DesignSystemPreviewScreen.kt)
- Add an interactive "Live Palette & Shadow Inspector" panel allowing on-device adjustments of surface color lightness, shadow opacity, and specular intensity with instant real-time feedback.

---

## 3. Verification Plan

### Automated Tests
- `.\gradlew.bat testDebugUnitTest`: Verify all 30 unit tests pass with 0 errors.
- `.\gradlew.bat assembleDebug`: Verify APK builds cleanly without compilation issues.
- `git diff --check`: Verify zero whitespace or formatting conflicts.

### Physical Device Verification (Infinix X6820)
1. **120Hz Refresh Rate Verification**:
   - Check `adb shell dumpsys display | grep -E "mBaseDisplayInfo"` to verify active mode switched from `modeId 2 (60Hz)` to `modeId 1 (120Hz)`.
   - Confirm buttery 120fps fluid scrolling across all tabs.
2. **Light Mode Palette Verification**:
   - Switch to Light Mode in Settings. Confirm containers are matte off-white with readable text and distinct card edges.
3. **Tasks & Health Neumorphic Depth**:
   - Inspect Schedule and Health cards; confirm 3D tactile dual shadows.
4. **Vault Popover Overlay**:
   - Tap Home avatar; verify pop-out spring animation, glassmorphic styling, and zero layout shift on Home screen.
5. **Elastic Bounce Video Recording**:
   - Capture video using `adb shell screenrecord /sdcard/bounce_demo.mp4` to confirm rubber-band overscroll and bounce back.
