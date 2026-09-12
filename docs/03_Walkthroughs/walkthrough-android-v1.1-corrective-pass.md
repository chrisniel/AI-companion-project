# Walkthrough: Android V1.1 Corrective Pass

- Purpose: Document the verification and corrective changes addressing the root gitignore source tracking, clean-checkout reproducibility, theme authority purification, background preset alignment, appearance control audit, safe hex parsing, and false mock claim neutralization.
- Audience: Developer, Maintainer, User
- Status: Verified
- Date: 2026-09-11

---

## 1. What Was Fixed & Delivered

1. **Surgical Root Gitignore Correction & Verified Source Tracking**:
   - Fixed the offending root `data/` rule by surgically anchoring it to `/data/` in `.gitignore`.
   - Preserved global ignore behavior for `secrets/`, `credentials/`, `cache/`, `runtime/`, `generated/`, `outputs/`, `downloads/`, and audio artifacts so nested directories remain protected.
   - Verified that `git check-ignore` confirms Android data files are unignored.
   - Staged all 12 intended Kotlin source files under `android/app/src/main/java/com/example/data/` (fake repositories and mock health providers).
   - Confirmed tracking via `git ls-files android/app/src/main/java/com/example/data/` and `git status --short --untracked-files=all` (zero untracked or ignored Android source files).

2. **Clean-Checkout Reproducibility Verification**:
   - Created a clean temporary checkout from the staged Git tree object (free of any dirty working directory files, untracked sources, or local build caches).
   - Successfully ran:
     ```cmd
     .\gradlew.bat :app:compileDebugKotlin
     .\gradlew.bat :app:testDebugUnitTest
     ```
   - Confirmed that a fresh checkout from Git builds and passes all tests completely.

3. **Single Authority for Appearance**:
   - Removed duplicate `isDarkTheme` property from `AppUiState` and `AppViewModel`.
   - Removed the `appearanceRepository.preferences.collect` block in `AppViewModel` that previously mapped `ThemeMode.SYSTEM` to `false`.
   - Removed legacy `onLiveThemeChanged` callbacks and non-existent `setTheme` hooks from `SettingsScreen`, `SettingsViewModel`, and `AppShell`.
   - `ThemeMode.SYSTEM` remains `SYSTEM` and resolves strictly through Android system appearance at Compose rendering time via `SoftTheme.colors.isDark`.

4. **Built-in Background Presets Synchronization**:
   - Replaced hardcoded preset strings in `SettingsScreen` with direct iteration over `BuiltInBackgroundPreset.entries`.
   - Selecting any built-in preset applies distinct primary and secondary glow hex colors to `AmbientGlassBackground` in `AppShell`.
   - Added unit test in `SettingsUnitTest` verifying that all preset entries apply cleanly.

5. **Appearance Controls Audited & Connected**:
   - Added `BuiltInGradientPreset` (4 presets) and `BuiltInSolidPreset` (4 finishes) to `AppearanceModels.kt`.
   - Added `gradientPreset`, `solidPreset`, and `customAccentHex` to `AppearancePreferences` and `AppearanceRepository`.
   - Connected `AppShell` to render distinct vertical gradients and solid colors for `BackgroundType.GRADIENT` and `BackgroundType.SOLID`.
   - Connected `SettingsViewModel` methods (`setSelectedGradientBackground`, `setSelectedSolidBackground`, `setCustomAccent`, `toggleCustomAccent`) directly to `AppearanceRepository`.

6. **Safe Custom Accent Hex Parsing & Fallback**:
   - Implemented `parseSafeHexColor` in `Theme.kt` with pure Kotlin parsing supporting 6-digit (`#RRGGBB` / `RRGGBB`) and 8-digit (`#AARRGGBB` / `AARRGGBB`) hex codes.
   - Validates hex format and safely returns `null` for malformed, empty, or non-hex input without crashing Compose or throwing JVM stub exceptions.
   - In `SoftGlassTheme`, invalid or malformed custom hex values safely fall back to the default `BLUE` accent (`AccentBlueDark` / `AccentBlueLight`).
   - Added unit test in `SettingsUnitTest` validating valid hex formats and testing rejection of invalid strings (`"invalid"`, `"#123"`, `"#GGGGGG"`, `"ZZZZZZ"`, `""`, `"   "`, `null`).

7. **False Mock Claims Neutralized & Host Terminology Genericized**:
   - Replaced `127.0.0.1` and pseudo-hostnames with generic simulated host terminology: `"Local AI Core (Simulated)"`, `"remote-node (Simulated)"`, and `"offline (Disconnected)"`.
   - Avoided establishing `pc-core.local` as an architectural hostname.
   - Updated technical rows in Settings connection metrics to generic mock terminology (`"Local Network / Companion Link (Mock)"`, `"Local Pairing Protocol (Planned mTLS)"`, `"Local Discovery (Planned mDNS)"`).
   - In PlaceholderScreen (About), set license to neutral `"License Not Selected"` and updated build metadata to `"V1.1 Companion Prototype"`.
   - Replaced `"100% On-Device & On-Premises"` banner with `"Local Companion Architecture"`.

---

## 2. Key Code Artifacts Changed

- **Ignore Policy**:
  - [`.gitignore`](file:///d:/OtherProjects/AI-companion-project/.gitignore) (surgical `data/` -> `/data/`)
- **Domain Models & Repositories**:
  - [`AppearanceModels.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/AppearanceModels.kt)
  - [`AppearanceRepository.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/repository/AppearanceRepository.kt)
  - [`FakeAppearanceRepository.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/fake/FakeAppearanceRepository.kt)
  - [`SettingsModels.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/SettingsModels.kt)
  - [`ConnectionStatus.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/ConnectionStatus.kt)
- **UI Shell & Themes**:
  - [`Theme.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/theme/Theme.kt)
  - [`AppShell.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppShell.kt)
  - [`AppTopBar.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/navigation/AppTopBar.kt)
  - [`AppViewModel.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppViewModel.kt)
- **Screens**:
  - [`AssistantScreen.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/AssistantScreen.kt)
  - [`AssistantHeader.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/assistant/AssistantHeader.kt)
  - [`SettingsViewModel.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/settings/SettingsViewModel.kt)
  - [`SettingsScreen.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt)
  - [`DesignSystemPreviewScreen.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/preview/DesignSystemPreviewScreen.kt)
- **Tests**:
  - [`SettingsUnitTest.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/test/java/com/example/SettingsUnitTest.kt)

---

## 3. Verification Evidence

- [x] **Surgical Git Ignore**: `git diff .gitignore` shows only `data/` -> `/data/`.
- [x] **Source Tracking**:
  - `git ls-files android/app/src/main/java/com/example/data/` outputs all 12 expected Kotlin source files.
  - `git status --short --untracked-files=all` confirms 0 untracked or ignored source files.
- [x] **Clean-Checkout Reproducibility**:
  - Staged tree archived to fresh clean directory without repository build caches or local uncommitted files.
  - `.\gradlew.bat :app:compileDebugKotlin` passed in 36s.
  - `.\gradlew.bat :app:testDebugUnitTest` passed all test suites in 30s.
- [x] **Safe Custom Accent Hex Parsing**:
  - Tested `#FF0055`, `FF0055`, `#80FF0055`, `80FF0055` (valid).
  - Tested `"invalid"`, `"#123"`, `"#GGGGGG"`, `"ZZZZZZ"`, `""`, `"   "`, `null` (safe fallback, no crash).
- [x] **Neutral Terminology**:
  - About license verified as `"License Not Selected"`.
  - Host verified as `"Local AI Core (Simulated)"`.
- [x] **Git Cleanliness**: `git diff --check` and `git diff --cached --check` returned 0 whitespace or formatting issues.
