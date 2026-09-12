# Implementation Plan: Android V1.1 Corrective Pass

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Completed & Verified
- Scope Mode: Gitignore policy correction, appearance state unification, background preset alignment, appearance control audit & connection, false mock claim neutralization, and reproducibility verification.
- Target Files:
  - `.gitignore`
  - `docs/01_Tracking/task.md`
  - `android/app/src/main/java/com/example/domain/model/AppearanceModels.kt`
  - `android/app/src/main/java/com/example/domain/repository/AppearanceRepository.kt`
  - `android/app/src/main/java/com/example/data/fake/FakeAppearanceRepository.kt`
  - `android/app/src/main/java/com/example/ui/theme/Theme.kt`
  - `android/app/src/main/java/com/example/ui/shell/AppViewModel.kt`
  - `android/app/src/main/java/com/example/ui/shell/AppShell.kt`
  - `android/app/src/main/java/com/example/navigation/AppTopBar.kt`
  - `android/app/src/main/java/com/example/ui/screens/AssistantScreen.kt`
  - `android/app/src/main/java/com/example/ui/screens/assistant/AssistantHeader.kt`
  - `android/app/src/main/java/com/example/domain/model/ConnectionStatus.kt`
  - `android/app/src/main/java/com/example/ui/preview/DesignSystemPreviewScreen.kt`
  - `android/app/src/main/java/com/example/ui/screens/settings/SettingsViewModel.kt`
  - `android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt`
  - `android/app/src/test/java/com/example/SettingsUnitTest.kt`

---

## 1. Request Understanding & Problem Statement

Following the commit of the Android V1.1 refinement on the `develop` branch, inspection revealed 6 critical issues:
1. **Critical Gitignore Issue**: Root `.gitignore` line 109 contained an unanchored `data/`, which inadvertently ignored `android/app/src/main/java/com/example/data/` (12 Kotlin source files). As a result, a fresh clone fails because `com.example.data.fake` classes are missing from Git.
2. **Duplicate Theme State**: `AppViewModel` maintained a duplicate `isDarkTheme` boolean mapping `ThemeMode.SYSTEM` to `false`. `SettingsViewModel` and `SettingsScreen` used a legacy `onLiveThemeChanged` callback. `AppearanceRepository` must be the sole authority, and `ThemeMode.SYSTEM` must resolve dynamically at Compose rendering time via `SoftTheme.colors.isDark`.
3. **Built-in Background Presets Mismatch**: `SettingsScreen` hardcoded background names (`"Obsidian Deep Glass"`, `"Pearl Frost"`, etc.) that did not match `BuiltInBackgroundPreset`, causing fallback to `AURORA_CYAN`. Choices must render directly from `BuiltInBackgroundPreset.entries` and produce distinct visual atmospheres.
4. **Appearance Control Audit & Connection**: Audit whether gradient selection, solid background selection, custom accent hex, and effects level actually affect rendered appearance. If functional, connect them to `AppearanceRepository`; if mock/future-only, label them clearly.
5. **False Mock Claims**: Prototype strings contained misleading endpoints (`127.0.0.1`, `mesh.local`), production claims (`"v1.5.0 Production Build"`), architecture overstatements (`"100% On-Premises Compute"`), and license claims (`"Open Hardware & Edge Intelligence"`). Neutralize these to reflect a V1.1 companion client prototype.
6. **Reproducibility Verification**: Confirm Android data source files are tracked, Gradle builds succeed, unit tests pass, and git cleanliness passes.

---

## 2. Step-by-Step Implementation

### Step 1: Gitignore Correction & Source Tracking Verification
- Modify root `.gitignore` line 109 from `data/` to `/data/`.
- Anchor root runtime paths (`/cache/`, `/runtime/`, `/generated/`, `/outputs/`, `/downloads/`, `/recordings/`, `/transcripts/`, `/audio-cache/`, `/secrets/`, `/credentials/`).
- Execute `git check-ignore -v android/app/src/main/java/com/example/data/fake/FakeTasksRepository.kt` &rarr; verify exit code 1 (no longer ignored).
- Verify `git status` shows all 12 source files in `android/app/src/main/java/com/example/data/**` as untracked source files.

### Step 2: Appearance Models & Repository Extension
- In `AppearanceModels.kt`:
  - Define `BuiltInGradientPreset` enum with 4 presets: `CYAN_VIOLET`, `AURORA_EMERALD`, `DEEP_SPACE`, `SUNSET_AMBER`.
  - Define `BuiltInSolidPreset` enum with 4 finishes: `MATTE_OBSIDIAN`, `CHARCOAL_GLASS`, `PEARL_SLATE`, `TRUE_BLACK`.
  - Add `gradientPreset: BuiltInGradientPreset`, `solidPreset: BuiltInSolidPreset`, and `customAccentHex: String?` to `AppearancePreferences`.
- In `AppearanceRepository.kt` & `FakeAppearanceRepository.kt`:
  - Add `setGradientPreset(preset: BuiltInGradientPreset)`.
  - Add `setSolidPreset(preset: BuiltInSolidPreset)`.
  - Add `setCustomAccentHex(hex: String?)`.

### Step 3: Single Theme Authority & SoftGlass Theme Wiring
- In `Theme.kt`:
  - Update `activeAccentColor` resolution: if `preferences.customAccentHex` is present and valid, parse and apply; otherwise use `preferences.accentPreset`.
- In `AppViewModel.kt`:
  - Remove `isDarkTheme` from `AppUiState`.
  - Remove coroutine collecting `appearanceRepository.preferences` to map `ThemeMode.SYSTEM` to `false`.
  - Remove `setTheme(isDark: Boolean)`.
  - Simplify `toggleTheme()` to delegate directly to `appearanceRepository.setThemeMode(...)`.
- In `AppTopBar.kt`:
  - Use `SoftTheme.colors.isDark` directly for the theme icon and content description.
- In `AssistantScreen.kt` & `AssistantHeader.kt`:
  - Use `SoftTheme.colors.isDark` directly.
- In `SettingsViewModel.kt`:
  - Remove `onThemeChange` lambda callback from `setThemeMode(mode: ThemeMode)`.
- In `SettingsScreen.kt`:
  - Remove `onLiveThemeChanged` parameter.
- In `AppShell.kt`:
  - Remove `onLiveThemeChanged` argument passed to `SettingsScreen`.

### Step 4: Background Presets & Atmosphere Wiring
- In `SettingsScreen.kt`:
  - Render built-in backgrounds directly from `BuiltInBackgroundPreset.entries.forEach { ... }`.
  - Render gradient backgrounds from `BuiltInGradientPreset.entries.forEach { ... }`.
  - Render solid backgrounds from `BuiltInSolidPreset.entries.forEach { ... }`.
  - Connect custom accent toggle and swatch picks to `SettingsViewModel.setCustomAccent`.
- In `AppShell.kt`:
  - `BUILT_IN`: Render `AmbientGlassBackground` with `Color(preferences.backgroundPreset.primaryGlowHex)` and `secondaryGlowHex`.
  - `GRADIENT`: Render `Brush.verticalGradient` with `Color(preferences.gradientPreset.startColorHex)` and `endColorHex`.
  - `SOLID`: Render `Color(preferences.solidPreset.colorHex)`.
  - `CUSTOM_IMAGE`: Render `AmbientGlassBackground(..., showAuraGlow = false)`.

### Step 5: False Mock Claim Neutralization
- In `AppViewModel.kt`:
  - Change default `host = "pc-core.local (Simulated)"`.
  - State cycling: `"remote-node (Simulated)"`, `"offline (Disconnected)"`, `"pc-core.local (Simulated)"`.
- In `ConnectionStatus.kt`:
  - Default `host = "pc-core.local (Simulated)"`.
- In `DesignSystemPreviewScreen.kt`:
  - Update error banner message to `"Could not establish connection to Local AI Core service (Mock Mode)."`.
- In `SettingsScreen.kt`:
  - Replace `"Private Air-Gapped Mesh"` &rarr; `"Local Network / Companion Link (Mock)"`.
  - Replace `"Hardware-bound mTLS 1.3"` &rarr; `"Local Pairing Protocol (Planned mTLS)"`.
  - Replace `"mDNS / Zeroconf (Zero-Config)"` &rarr; `"Local Discovery (Planned mDNS)"`.
  - Replace `"[Hidden Local Core Socket]"` &rarr; `"Simulated Local Socket"`.
  - Replace `"Strict Air-Gap (Zero Outbound Traffic)"` &rarr; `"Local Area Network Only (Planned)"`.
  - Replace `"12 ms (Direct WiFi 6)"` &rarr; `"Simulated Latency (12 ms)"`.
  - Replace `"Local ping returned in 11 ms. Zero dropped packets."` &rarr; `"Simulated ping response: 11 ms (Mock)"`.
  - Replace `"100% On-Device & On-Premises"` &rarr; `"Local Companion Architecture"`.
- In `AppShell.kt` PlaceholderScreen (About):
  - Replace `"v1.5.0 Production Build"` &rarr; `"V1.1 Companion Prototype"`.
  - Replace `"v1.5.0-alpha02"` &rarr; `"V1.1 (Prototype)"`.
  - Replace `"100% On-Premises Compute"` &rarr; `"Companion to Windows PC Host"`.
  - Replace `"Open Hardware & Edge Intelligence"` &rarr; `"Project Proprietary / Unspecified"`.

### Step 6: Test Suite Alignment & Verification
- In `SettingsUnitTest.kt`:
  - Update `theme mode supports Light, Dark, System` test to invoke `viewModel.setThemeMode(mode)` without the lambda.
  - Add test verifying `BuiltInBackgroundPreset` selection updates `AppearancePreferences`.
  - Add test verifying `customAccentHex` updates `AppearancePreferences`.
- Run:
  1. `git check-ignore -v android/app/src/main/java/com/example/data/fake/FakeTasksRepository.kt`
  2. `git status -s android/app/src/main/java/com/example/data/`
  3. `.\gradlew.bat :app:compileDebugKotlin`
  4. `.\gradlew.bat :app:testDebugUnitTest`
  5. `git diff --check`
  6. `git status -s`

---

## 3. Risks & Rollback

- **Risk**: Touching `.gitignore` might accidentally unignore unwanted temporary files.
  - **Mitigation**: Anchoring with leading slashes (`/data/`, `/cache/`, `/runtime/`) guarantees only top-level root data directories are ignored, while preserving ignore rules for Android build outputs and SDK paths.
- **Rollback**: `git checkout -- .gitignore` and revert modified Kotlin files.
