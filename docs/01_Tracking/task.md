# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Completed (Verified via automated unit & Robolectric test suite; ready for user commit)
- Current Sprint: Android OLED Battery Saver Theme, Contrast Calibration, Persistent Storage & Navigation Fluidity
- Target: Implement OLED Battery Saver pure black theme, calibrate Light/Dark icon contrast, add SharedPreferences persistence for theme and appearance, tune overscroll and horizontal pager physics, eliminate More screen navigation jump, and add real Host IP config and Hybrid AI failover controls.
- Scope Guard: Completed components 1–4; Step 5 (Web frontend review) deferred per user instruction.

## [CURRENT EXECUTION STATE - HANDOFF]

- Active Files:
  - `android/app/src/main/java/com/example/ui/theme/Color.kt`
  - `android/app/src/main/java/com/example/ui/theme/Theme.kt`
  - `android/app/src/main/java/com/example/data/repository/SharedPreferencesAppearanceRepository.kt`
  - `android/app/src/main/java/com/example/ui/components/SoftBounceOverscroll.kt`
  - `android/app/src/main/java/com/example/ui/shell/AppShell.kt`
  - `android/app/src/main/java/com/example/ui/screens/connection/ConnectionScreen.kt`
  - `android/app/src/main/java/com/example/ui/screens/models/ModelsScreen.kt`
  - `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`
  - `docs/00_Drafts/MASTER_IMPLEMENTATION_ROADMAP_v2.md`
  - `docs/00_Drafts/LOCAL_AI_RUNTIME_AND_WORKFLOW.md`
  - `docs/00_Drafts/AI_COMPANION_MASTER_FEATURE_INVENTORY.md`
  - `CHANGELOG.md`
- Current Status: All implementations completed. Full unit and Robolectric test suite passing (`110 tests completed, 0 failed`). Canonical architecture and draft roadmap docs updated. Ready for user commit.
- Next Action: Present the user with the recommended next-phase workflow and proposed Conventional Commit message.

## Active Checklist

### 1. OLED Battery Saver Theme & Contrast Calibration
- [x] Add `ThemeMode.OLED_BATTERY_SAVER` to `SettingsModels.kt`
- [x] Implement OLED pure black (`#000000`) theme palette with zero drop-shadows, luminous borders, and glowing icons in `Theme.kt` and `Color.kt`
- [x] Elevate Light Mode muted icons/text to `#334155` (Slate-700) for sharp readability against light clay
- [x] Brighten Dark Mode muted icons to `#94A3B8` (Slate-400) so they do not blend into charcoal
- [x] Add "OLED Battery Saver" button to Theme Mode selector in `SettingsScreen.kt`

### 2. Persistent Appearance & Connection Storage
- [x] Implement `SharedPreferencesAppearanceRepository` backed by Android `SharedPreferences`
- [x] Wire `SharedPreferencesAppearanceRepository` into `DefaultAppContainer`
- [x] Verify theme (Light, Dark, OLED Battery Saver) permanently survives process kill and restart

### 3. Physics Calibration & Navigation Polish
- [x] Tighten overscroll `maxOverscrollPx` to 140f with progressive quadratic resistance
- [x] Raise fling collision velocity threshold to 650f px/s and clamp apex displacement to <=85px
- [x] Set `beyondViewportPageCount = 1` in `HorizontalPager` to eliminate horizontal swipe stutter
- [x] Normalize top bar insets to eliminate vertical layout shift when opening Settings/Permissions from More screen

### 4. Real Host Connection & Hybrid AI (LLM + Kokoro TTS) Front-End
- [x] Add editable Host URL (`http://...:8000`), Port, and API Token inputs in `ConnectionScreen.kt`
- [x] Add On-Device Edge Failover card with auto-failover toggle in `ModelsScreen.kt`
- [x] Add LLM edge model card (`Gemma-2-2B` / `Qwen-2.5-1.5B`) and Kokoro-82M TTS edge card
- [x] Add "Import Local Model (.gguf / .onnx)" SAF file picker action and In-App Downloader action
- [x] Add on-device RAM allocation gauge (e.g. `1.2 GB / 8.0 GB RAM`)

### 5. [DEFERRED] Web Frontend Review
- [x] Halted for now per user instruction.

### 6. Verification & Testing
- [x] Run `gradlew.bat testDebugUnitTest` (all 110 tests passing)
- [x] Update canonical architecture and draft roadmap documentation
- [x] Update `CHANGELOG.md` under `[Unreleased]`
- [ ] Install on Infinix X6820 and verify OLED theme, persistence, smooth swiping, and clean navigation transitions (manual device step)
