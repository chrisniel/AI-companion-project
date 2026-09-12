# Task Archive: Android UI/UX Responsiveness, Neumorphic Calibration & Responsive Badges

- Completed: 2026-09-11
- Current Sprint: Android UI/UX Responsiveness, Neumorphic Calibration & Responsive Badges
- Target: Eliminate shadow bleed, enhance authentic inset well depth and material matching, expand selection card spacing, remove touch-intercepting toast overlay (1.4s fast auto-dismiss), integrate 1.5dp glowing status border ring on model avatars (clean user avatar), and fix the 1-character-wide vertical snake badge bug on Permissions and About screens.
- Scope Guard: Approved plan in implementation_plan.md.

## Execution Summary

- Active Files:
  - `android/app/src/main/java/com/example/ui/components/SoftNeumorphic.kt`
  - `android/app/src/main/java/com/example/ui/components/SoftGlassCard.kt`
  - `android/app/src/main/java/com/example/ui/components/SoftIndicators.kt`
  - `android/app/src/main/java/com/example/ui/components/CapabilityComponents.kt`
  - `android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt`
  - `android/app/src/main/java/com/example/ui/screens/settings/SettingsViewModel.kt`
  - `android/app/src/main/java/com/example/ui/screens/PlaceholderScreen.kt`
  - `android/app/src/main/java/com/example/ui/screens/HomeScreen.kt`
  - `android/app/src/main/java/com/example/ui/screens/MoreScreen.kt`
  - `android/app/src/main/java/com/example/navigation/AppTopBar.kt`

## Completed Checklist

- [x] Neumorphic Specular Shadow Bleed Calibration: Tightened top-left specular highlight offset (`1–2.5dp`), blur radius (`1.5–4dp`), and dark-mode alpha (`0.10f`) in `SoftNeumorphic.kt`, eliminating upward foggy shadow bleed over section titles and container borders above.
- [x] Inset Neumorphic Well Accuracy: Preserved natural surface background color on inset/selected cards (`SoftTheme.colors.surface` / `actualBackgroundColor`) instead of swapping to artificial darker slab color (`surfacePressed`); expanded inner shadow blur radius up to 16dp for soft, deep concave recession.
- [x] Permissions & About Screen Responsive Badges: Repositioned `StatusBadge` cleanly below titles inside weighted columns in `CapabilityComponents.kt` and `PlaceholderScreen.kt`, eliminating the 1-character vertical snake wrapping bug.
- [x] Non-Blocking Snappy Toast UX: Removed full-screen touch-intercepting overlay in `SettingsScreen.kt` so touches register immediately; shortened auto-dismiss timer in `SettingsViewModel.kt` from 2.6s to 1.4s.
- [x] Avatar Status Border Ring: Removed redundant, clipped online status dot from Home screen user avatar (`U`); upgraded `SoftAvatar` to draw an integrated 1.5dp glowing status border ring around the circle (Green = Online, Orange = Reconnecting, Red = Offline) that is completely impervious to container clipping.
- [x] Selection Card Spacing: Expanded vertical card spacing to `10.dp` across Theme Source, Glass Visual Effects, and Ambient Presets, adding generous `8.dp` negative space below section titles.
- [x] Automated Unit Test Suite: All Gradle unit tests (`testDebugUnitTest`) pass cleanly. Debug APK built.
