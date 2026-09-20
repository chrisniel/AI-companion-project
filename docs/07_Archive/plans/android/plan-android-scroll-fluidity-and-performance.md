# Implementation Plan: Android Scroll Fluidity, High Refresh Rate Unlock, Horizontal Swipe Fluidity, Authentic Neumorphism Restoration, Effects Level Semantics & Custom Image Picker

## Architectural Context & User Findings (from temp.txt & latest feedback)

Following the initial scroll responsiveness fix, user physical-device testing on the Infinix ZERO ULTRA (120Hz display, XOS) identified key areas requiring focused, surgical refinement:

1. **Framerate Locked at 60Hz on Device**:
   - Removing all window attributes caused the OEM display manager (XOS / Transsion) to drop the app window to the default 60Hz battery-saving mode.
   - Without a window-level display mode preference or frame-rate category signal, Android does not automatically ramp up to 120Hz/144Hz/165Hz for Compose rendering, resulting in visible judder compared to Play Store 120Hz apps.
   - **Solution**: Dynamically query `display.supportedModes` in `MainActivity.kt`, detect the device's highest supported refresh rate (`modes.maxByOrNull { it.refreshRate }`), and set `preferredDisplayModeId = maxMode.modeId` and `preferredRefreshRate = maxMode.refreshRate`. On Android 14+ (API 34+), also set `preferredFrameRateCategory = WindowManager.LayoutParams.FRAME_RATE_CATEGORY_HIGH`. This signals high-performance UI rendering to the OS window manager and unlocks whatever high refresh rate the physical panel supports (60Hz, 90Hz, 120Hz, 144Hz, or 165Hz) without hardcoding or capping.

2. **Horizontal Swipe Delay & Tab Transitions**:
   - Swiping horizontally across the primary tabs (`Home | Tasks | Assistant | Health | More`) felt delayed/hesitant because:
     a) The fling snap animation in `HorizontalPager` was enforced with a rigid `tween(200)` rather than a natural, velocity-tracking spring.
     b) `beyondViewportPageCount = 1` only pre-rendered 1 neighbor, causing on-the-fly layout and composition work as the swipe crossed page thresholds.
   - **Solution**: In `AppShell.kt`, set `beyondViewportPageCount = 2` to keep adjacent tab screens pre-warmed in memory (eliminates on-the-fly composition hitch), and replace the 200ms tween snap with a velocity-aware spring (`stiffness = Spring.StiffnessMediumLow`, `dampingRatio = 0.90f`) for instant finger tracking and settlement.

3. **Restore Authentic Dual-Light Neumorphism in Light & Dark Modes**:
   - The user noted that neumorphism in standard modes became too subtle because `isLightweight` defaulted to `true`, bypassing the authentic dual-shadow Skia engine.
   - The user specifically requested: *"I thought the only thing we will change is the OLED Battery Saver... please dont change anything that is not related to the issue... just do surgical changes if possible. the effect is still there for neumorphism just too subtle."*
   - **Solution**: Revert `isLightweight` default back to `false` in `SoftNeumorphic.kt` and keep `isLightweight = false` in `SoftGlassCard.kt` and `SoftButtons.kt`. The authentic 3D physical dual-light clay depth and specular highlights are 100% restored for `NORMAL` and `ENHANCED`. Since `BlurFilterCache` is in place, native Skia filters are cached in memory, preventing GC stutter during scroll.

4. **Fix EffectsLevel (Glass Visual Effects) Semantics**:
   - The user noted: *"Also these Glass Visual Effects doesnt do anything I notice except Reduced. But it is kinda wrong. its supposed to stops any effects of neumorphism without affecting the glass effect at all... and about Enhanced nothing happens same visual to normal option."*
   - Currently, `EffectsLevel.REDUCED` in `AppShell.kt` was incorrectly hiding the ambient glass aura (`showAura = false`).
   - **Solution**:
     - `EffectsLevel.REDUCED`: Completely disables neumorphic elevation shadows (`shadowFactor = 0f`, `elevation = 0.dp`), rendering clean flat glass cards while preserving the translucent glass surface, frosted borders, and ambient glass aura in `AppShell.kt`.
     - `EffectsLevel.NORMAL`: Standard authentic tactile dual-shadow neumorphism + glass effects (`shadowFactor = 1.0f`, `specularAlpha = 0.22f`).
     - `EffectsLevel.ENHANCED`: Visibly distinct and enhanced depth: boosted shadow contrast (`shadowFactor = 1.5f`), pronounced specular highlights (`specularAlpha = 0.40f`), and rich tactile borders so `ENHANCED` is immediately distinguishable from `NORMAL`.
     - In `AppShell.kt`, keep `showAura = true` for `REDUCED`, `NORMAL`, and `ENHANCED` (only `OLED_BATTERY_SAVER` disables ambient aura for pure pitch-black AMOLED power savings).

5. **Functional Custom UI Image Wallpaper**:
   - The user noted: *"and the custom UI image is not working too. tried to add nothing no selections."*
   - In `SettingsScreen.kt`, custom image selection was previously a placeholder with simulated buttons that did not launch the real gallery picker. Furthermore, `AppShell.kt` had no decoder or renderer for `BackgroundType.CUSTOM_IMAGE`.
   - **Solution**:
     - In `SettingsScreen.kt`: Add a real Android `ActivityResultContracts.PickVisualMedia()` launcher with a `"Choose Photo from Device"` button. When a photo is selected, persist read URI permissions and save the URI string.
     - In `AppShell.kt`: Load the image URI into an `ImageBitmap` (safely downscaled to screen resolution via standard Android `ImageDecoder` / `BitmapFactory`) and render it full-screen behind the glass scaffold with user brightness and scrim controls.

---

## User Review Required

> [!IMPORTANT]
> **Summary of Targeted Changes**:
> 1. **High Refresh Rate Hardware Unlock**: Window attributes in `MainActivity.kt` dynamically set `preferredDisplayModeId` and `preferredRefreshRate` to the device's maximum available rate (supports 60, 90, 120, 144, 165Hz) plus `FRAME_RATE_CATEGORY_HIGH` on API 34+.
> 2. **Horizontal Swipe Fluidity**: `beyondViewportPageCount = 2` pre-warms adjacent tabs in `AppShell.kt`, and `snapAnimationSpec` uses fluid spring physics (`dampingRatio = 0.90f`) instead of a 200ms fixed tween.
> 3. **Neumorphic Visual Restoration**: Restore authentic dual-light clay depth in `SoftNeumorphic.kt` for Light and Dark modes.
> 4. **Effects Level Behavior**: `REDUCED` turns off neumorphic shadows while keeping full glass aesthetics intact. `ENHANCED` delivers visibly stronger depth and specular contrast compared to `NORMAL`.
> 5. **Real Gallery Wallpaper Picker**: Native `PickVisualMedia` launcher in Settings and hardware-safe bitmap rendering in `AppShell.kt`.

---

## Proposed Changes (Surgical & In-Place)

### Component 1: Window Refresh Rate & High-Performance Display (`MainActivity.kt`)

#### [MODIFY] `android/app/src/main/java/com/example/MainActivity.kt`
- On `onCreate` / `onAttachedToWindow`, query `display?.supportedModes`.
- Identify the highest supported refresh rate mode on the device:
  ```kotlin
  val modes = display?.supportedModes ?: emptyArray()
  val maxMode = modes.maxByOrNull { it.refreshRate }
  val layoutParams = window.attributes
  if (maxMode != null) {
      layoutParams.preferredDisplayModeId = maxMode.modeId
      layoutParams.preferredRefreshRate = maxMode.refreshRate
  }
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      layoutParams.preferredFrameRateCategory = WindowManager.LayoutParams.FRAME_RATE_CATEGORY_HIGH
  }
  window.attributes = layoutParams
  ```
- This dynamically unlocks the window to whatever maximum refresh rate the hardware supports (60Hz, 90Hz, 120Hz, 144Hz, 165Hz), allowing Android's Choreographer and display subsystem to render fluidly at native speed.

---

### Component 2: Horizontal Swipe Optimization (`AppShell.kt`)

#### [MODIFY] `android/app/src/main/java/com/example/ui/shell/AppShell.kt`
- In `HorizontalPager`:
  - Increase `beyondViewportPageCount = 2` so neighbor screens are pre-composed and warm in memory.
  - Update `snapAnimationSpec` in `PagerDefaults.flingBehavior` from `tween(200)` to `spring(stiffness = Spring.StiffnessMediumLow, dampingRatio = 0.90f)`.
  - Update `navigateToDestination` to use spring animation instead of `tween(180)`.
- Keep `showAura = !colors.isOled` (ambient aura glow is shown for `REDUCED`, `NORMAL`, and `ENHANCED`).
- Under `BackgroundType.CUSTOM_IMAGE`, safely decode and render the selected wallpaper full-screen behind the glass scaffold.

---

### Component 3: Authentic Neumorphic Restoration (`SoftNeumorphic.kt`, `SoftGlassCard.kt`, `SoftButtons.kt`)

#### [MODIFY] `android/app/src/main/java/com/example/ui/components/SoftNeumorphic.kt`
- Revert `isLightweight: Boolean = false` as the default for `softNeumorphicRaised`, `softNeumorphicInset`, and `softInsetWell`.
- Ensure the authentic dual-shadow Skia engine is utilized for `NORMAL` and `ENHANCED` modes.
- Retain the static thread-safe `BlurFilterCache` (`ConcurrentHashMap<Int, BlurMaskFilter>`) so native Skia filters are cached without garbage collection stutter.

#### [MODIFY] `android/app/src/main/java/com/example/ui/components/SoftGlassCard.kt`
- In `SoftGlassCard`, `SoftWell`, and `InteractiveSoftWell`:
  - When `isOled == true`, bypass neumorphic shadows completely (flat `#000000` with hairline border).
  - When `effectsLevel == EffectsLevel.REDUCED`, set elevation/depth to `0.dp` so cards are flat glass without drop shadows.
  - When `effectsLevel == EffectsLevel.NORMAL`, render authentic dual-light neumorphic depth.
  - When `effectsLevel == EffectsLevel.ENHANCED`, render enhanced depth with higher specular alpha.

#### [MODIFY] `android/app/src/main/java/com/example/ui/components/SoftButtons.kt`
- Same logic: when `effectsLevel == EffectsLevel.REDUCED`, bypass drop shadows while keeping glass background and border. When `NORMAL` or `ENHANCED`, use authentic dual-light neumorphism.

---

### Component 4: Effects Level & Glass Calibrations (`Theme.kt`)

#### [MODIFY] `android/app/src/main/java/com/example/ui/theme/Theme.kt`
- Calibrate `shadowFactor` and `specularAlpha` for each level:
  - `REDUCED`: Glass effects are identical to `NORMAL` (`specularAlpha = 0.22f`, preserving frosted borders, translucent surfaces, and ambient aura), while neumorphic shadow depth is reduced (`shadowFactor = 0.20f` or flat).
  - `NORMAL`: Standard glass effects + standard authentic tactile neumorphism (`shadowFactor = 1.0f`, `specularAlpha = 0.22f`).
  - `ENHANCED`: Same rich glass effects + visibly deeper tactile depth (`shadowFactor = 1.5f`, `specularAlpha = 0.35f`).

---

### Component 5: Custom Image Wallpaper (`SettingsScreen.kt`)

#### [MODIFY] `android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt`
- Replace simulated buttons in `BackgroundType.CUSTOM_IMAGE` with a real `rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia())`.
- Add a `"Choose Photo from Device"` button with gallery icon, displaying the currently selected image URI/name and a quick preview thumbnail if set.
- Persist read URI permissions via `takePersistableUriPermission`.

---

## Verification Plan

### Automated Tests
- Run `.\gradlew.bat testDebugUnitTest` to verify all unit and Robolectric tests pass.
- Run `.\gradlew.bat assembleDebug` to verify compilation.

### Manual Verification on Infinix ZERO ULTRA
1. **Refresh Rate**:
   - Check with the system refresh rate overlay: verify the app runs at **120Hz** during touch and scrolling instead of 60Hz.
2. **Horizontal Swiping**:
   - Swipe horizontally between Home, Tasks, Assistant, Health, and More tabs: verify zero hitch, instant finger tracking, and smooth spring settlement.
3. **Neumorphism**:
   - Switch between Light and Dark themes: verify the rich tactile 3D neumorphic look and dual drop shadows/specular highlights are fully restored.
4. **Effects Level**:
   - Switch to **Reduced**: verify neumorphic shadows disappear (flat glass), but ambient glass aura and translucent surfaces remain.
   - Switch to **Enhanced**: verify depth and specular highlights noticeably deepen compared to **Normal**.
5. **Custom Image**:
   - Tap "Choose Photo from Device", select a wallpaper from the phone gallery, and verify it renders behind the glass UI smoothly.
