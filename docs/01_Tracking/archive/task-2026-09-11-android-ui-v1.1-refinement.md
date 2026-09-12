# Archived Task: Android UI V1.1 Refinement

- Status: Complete
- Completed: 2026-09-11
- Scope: Android application refinement and alignment (`android/`), documentation, tracking, and changelog updates.

## Delivered

- Restored missing Gradle wrapper (`gradlew.bat`, `gradlew`, `gradle-wrapper.jar`), pruned unused dependencies (Firebase, Retrofit, Room), fixed debug signing config, and replaced export README with an accurate companion guide.
- Implemented application-scoped manual dependency injection via `CompanionApplication` and `AppContainer` (`DefaultAppContainer`).
- Implemented standard Jetpack `AppViewModelProvider.Factory` via `viewModelFactory` DSL for all 13 ViewModels.
- Implemented shared in-memory repositories (`TasksRepository`, `ScheduleRepository`, `AlarmsRepository`) dynamically bound to `FakeHomeRepository`.
- Implemented authoritative appearance unification (`AppearanceRepository`, `AppearancePreferences`, `BuiltInBackgroundPreset`, dynamic dark mode resolution via `isSystemInDarkTheme()`).
- Calibrated Soft Glass V1.1 visuals (translucent light mode surfaces, dark mode gray border removal, root atmospheric background canvas in `AppShell`).
- Fixed primary navigation stacking regression in `AppShell`.
- Purged misleading on-device LLM/NPU/GGUF claims, aligning with Windows PC Local AI Core companion architecture.

## Verification Checklist

- [x] `./gradlew.bat :app:compileDebugKotlin` succeeds without errors.
- [x] `./gradlew.bat :app:testDebugUnitTest` passes (106 unit and Robolectric tests pass, 0 failures).
- [x] `git diff --check` passes cleanly.
- [x] No unauthorized modifications to `frontend/`, `backend/`, `contracts/`, or Git/LFS configurations.
