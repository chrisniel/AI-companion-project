# Implementation Plan: Android V1.1B UX + Visual Refinement

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Approved & In Execution
- Scope Mode: Soft Glass neumorphic dual-shadow & inset rendering engine, appearance parity (light/dark presets, scrim, brightness), bottom navigation redesign (5 tabs, center elevated action), assistant clean-chat first & compact events, sticky settings tabs, mobile density calibration, seamless 120ms transitions, and physical-device verification.
- Target Files:
  - `android/app/src/main/java/com/example/ui/theme/GlassTokens.kt`
  - `android/app/src/main/java/com/example/ui/theme/Theme.kt`
  - `android/app/src/main/java/com/example/ui/theme/Color.kt`
  - `android/app/src/main/java/com/example/ui/theme/Spacing.kt`
  - `android/app/src/main/java/com/example/ui/components/GlassSurface.kt`
  - `android/app/src/main/java/com/example/ui/components/SoftGlassCard.kt`
  - `android/app/src/main/java/com/example/ui/components/SoftButtons.kt`
  - `android/app/src/main/java/com/example/ui/components/SoftControls.kt`
  - `android/app/src/main/java/com/example/domain/model/AppearanceModels.kt`
  - `android/app/src/main/java/com/example/domain/repository/AppearanceRepository.kt`
  - `android/app/src/main/java/com/example/data/fake/FakeAppearanceRepository.kt`
  - `android/app/src/main/java/com/example/data/fake/FakeAssistantRepository.kt`
  - `android/app/src/main/java/com/example/navigation/NavRoutes.kt`
  - `android/app/src/main/java/com/example/navigation/AppBottomBar.kt`
  - `android/app/src/main/java/com/example/navigation/AppTopBar.kt`
  - `android/app/src/main/java/com/example/ui/screens/assistant/AssistantHeader.kt`
  - `android/app/src/main/java/com/example/ui/screens/assistant/AssistantMessageComponents.kt`
  - `android/app/src/main/java/com/example/ui/screens/AssistantScreen.kt`
  - `android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt`
  - `android/app/src/main/java/com/example/ui/screens/HomeScreen.kt`
  - `android/app/src/main/java/com/example/ui/shell/AppShell.kt`
  - `android/app/src/test/java/com/example/SettingsUnitTest.kt`

---

## 1. Request Understanding & Problem Statement

Following physical testing on device and comparative source audit with the React web client (`frontend/web/`):
1. **Lack of Tactile Neumorphism**: Standard `Modifier.shadow` only casts a single downward drop shadow, missing the web client's characteristic top-left specular white highlight and inset recessed well depths.
2. **Transition Lag & Stutter**: Bottom menu navigation feels laggy due to unmanaged transitions in `NavHost`, abrupt un-animated tab indicator snapping, and redraw of `AmbientGlassBackground` during route switches.
3. **Appearance Incompleteness**: Android lacked light built-in presets, light solid swatches, and overlay/scrim opacity adjustment.
4. **Deferred Mobile UX**: Bottom nav order (`Home | Tasks | Assistant | Health | More`), center elevated Assistant action, sticky settings tabs, clean-chat first launch, compact system activity pills in chat, and removal of top-bar theme toggles.

---

## 2. Phased Execution Plan

### Phase A: Soft Glass / Neumorphic Compose Rendering Engine
- Zero-allocation `Modifier.drawWithCache` dual-shadow (top-left specular highlight + bottom-right ambient shadow).
- Sunken well inner-shadow simulation for `SoftWell`, text inputs, and pressed states.
- Directional 1px border gradient (top-left highlight to bottom-right ambient).

### Phase B: Appearance Settings Parity
- Add 4 Light Presets (`Aurora Mist`, `Pearl Bloom`, `Cloud Glass`, `Lavender Flow`) and 4 Dark Presets to `BuiltInBackgroundPreset`.
- Add 4 Light Solid Swatches to `BuiltInSolidPreset`.
- Add `scrimOpacity: Float` and `backgroundBrightness: Float` to `AppearancePreferences`.
- Render environmental contrast scrim in `AppShell` and `AmbientGlassBackground`.
- Add compact live preview card to `Settings → Appearance`.

### Phase C: Bottom Navigation Redesign & Tactile Response
- Reorder items to `Home | Tasks | Assistant | Health | More`.
- Prominent floating/elevated center Assistant action: 50dp diameter, 28dp icon, no text label, elevated soft glass treatment.
- Accelerated 120ms tab indicator animation.

### Phase D: Assistant UX Refinement
- Clean-chat first experience on launch with starter prompt suggestion chips.
- History sheet remains 100% functional to resume past chats.
- Compact single-line expandable activity pills for tool calls, memory retrievals, and warnings.
- Header cleanup: remove theme toggle icon.

### Phase E: Settings Navigation UX
- Sticky horizontal `SettingsSectionTabs` pinned below top bar.
- Automatic `scrollTo(0)` whenever category tab switches.

### Phase F: Screen Density & Card Calibration
- Remove theme toggle from `AppTopBar`.
- Standardize mobile card internal padding from 20dp/24dp down to 14dp/16dp to keep metrics and task cards above the fold.

### Phase G: Seamless Navigation & Transition Performance
- Decouple `AmbientGlassBackground` from route changes to prevent Canvas redraws.
- Implement ultra-snappy 120ms `fadeIn` / 90ms `fadeOut` crossfade (`LinearOutSlowInEasing`).
- Instant 120ms bottom tab feedback.

### Phase H: Accessibility & Unit/Robolectric Tests
- Explicit accessibility semantics, roles, content descriptions.
- Verify all 108+ unit tests pass.

### Phase I: Physical Device Visual & Performance Verification
- Compile and install debug APK (`./gradlew installDebug`).
- Verify live 60/120 FPS frame rate, lack of transition latency, and visual soft-glass depth via ADB.
