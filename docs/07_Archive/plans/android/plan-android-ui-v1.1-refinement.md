# Implementation Plan: Android UI V1.1 Refinement

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Completed & Verified
- Scope Mode: Architecture Realignment, Appearance Unification, Tri-State Shared State (Tasks, Schedule, Alarms), Manual ViewModel Factories, Soft Glass Calibration, and Navigation Bug Fix — strictly preserves the companion client role without introducing on-device LLM inference or premature permissions
- Target Files:
  - `android/build.gradle.kts`
  - `android/app/build.gradle.kts`
  - `android/gradle/libs.versions.toml`
  - `android/gradle/wrapper/gradle-wrapper.properties`
  - `android/gradlew.bat` [NEW/RESTORED]
  - `android/gradlew` [NEW/RESTORED]
  - `android/README.md`
  - `android/app/src/main/java/com/example/CompanionApplication.kt` [NEW]
  - `android/app/src/main/java/com/example/di/AppContainer.kt` [NEW]
  - `android/app/src/main/java/com/example/ui/AppViewModelProvider.kt` [NEW]
  - `android/app/src/main/java/com/example/MainActivity.kt`
  - `android/app/src/main/java/com/example/ui/theme/*`
  - `android/app/src/main/java/com/example/domain/*`
  - `android/app/src/main/java/com/example/data/*`
  - `android/app/src/main/java/com/example/ui/components/*`
  - `android/app/src/main/java/com/example/ui/screens/*`
  - `android/app/src/main/java/com/example/ui/shell/*`

Notice: Update this plan in place during planning. After approval, switch live execution tracking to `docs/01_Tracking/task.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### Primary Objective
Transform the exported Google AI Studio Android prototype into an architecturally aligned, clean, performant, and visually calibrated **V1.1 Android Companion Client**. Android strictly serves as the mobile companion client to the Windows PC Local AI Core (the primary AI host in V1).

This refinement pass:
1. De-bloats build configurations, strips unused AI Studio boilerplate, establishes working Windows Gradle wrapper scripts (`gradlew.bat`), and replaces the export README with a clean Android companion guide.
2. Implements an application-scoped manual `AppContainer` and standard Jetpack `AppViewModelProvider.Factory` (no global object singletons, no Hilt/Koin).
3. Establishes shared in-memory repositories across **Tasks, Schedule, and Alarms** so Home and dedicated screens share a unified source of truth.
4. Unifies appearance architecture under an authoritative `AppearanceRepository` holding user `AppearancePreferences` (`ThemeMode`, `ThemeSource`, `AccentPreset`, `BackgroundType`, `BuiltInBackgroundPreset`, `EffectsLevel`) while deriving dark mode at runtime via `isSystemInDarkTheme()`.
5. Ensures every appearance control produces an observable rendering effect, while clearly marking un-synced remote sources (`ACCOUNT_THEME`, `SYNC_PC_THEME`) as future/unavailable in V1.1.
6. Replaces specific hardware literals (RX 580, companion.local, fixed IPs) with generic architecture terminology (`"Local AI Core • Windows PC"`, `"Connected over local network"`).
7. Calibrates Soft Glass V1.1 aesthetics for both Light and Dark modes (substantially reducing persistent gray outlines, introducing soft translucency and atmospheric depth, without heavy runtime backdrop blur).
8. Wires atmospheric backgrounds into `AppShell` so translucent surfaces visually interact with background depth across all screens.
9. Fixes the known primary-navigation regression (`Home` &rarr; `Ask` &rarr; `Assistant` &rarr; `Home bottom-nav`).

### Explicit Exclusions (Deferred to Subsequent Phases)
- Center-emphasized Assistant bottom-nav redesign.
- Sticky Settings category tabs.
- New-chat-first Assistant redesign.
- Warning/error presentation redesign.
- Runtime Android permissions (`INTERNET`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, Health Connect) — deferred until their active native implementation phases.
- Package rename (`com.example` / `com.aistudio`) — deferred to a dedicated migration step prior to native backend integration to prevent unrelated diff churn.
- Real network calls to FastAPI — deferred until backend contracts under `contracts/` are finalized.
- Furigana/Ruby Japanese layout — standard Japanese Unicode glyphs and mixed code-switching remain supported.
- Runtime RenderEffect/backdrop blur — performant simulated glass only.
- On-device Android LLM/NPU inference — prohibited in V1.

---

## 2. Current Findings & Technical Root Cause

| Area | Current Observation / Repository Evidence | Root Cause & Resolution |
| :--- | :--- | :--- |
| **Gradle Wrapper** | `android/gradle/wrapper/gradle-wrapper.properties` exists, but `gradlew.bat`, `gradlew`, and `gradle-wrapper.jar` are missing from the export. | AI Studio export omitted wrapper binaries. Generate wrapper files using system/cached Gradle so `.\gradlew.bat` functions reliably on Windows. |
| **Scaffold & Build** | `app/build.gradle.kts` imports Firebase AI, AppCheck, Retrofit, OkHttp, Moshi, Room, KSP, Secrets plugin, and references missing `${rootDir}/debug.keystore`. | AI Studio export injected full Google AI starter bundle and unused libraries. Prune unused dependencies, remove invalid debug signing config, and delete export metadata. |
| **Subproject Docs** | `android/README.md` contains AI Studio export instructions and links to Google AI Studio console. | Subproject README should describe the Android companion client and local build/testing instructions. Replace with clean project-specific README. |
| **Client/Host Role** | `AssistantModels.kt` and `FakeHomeRepository.kt` define `LocalLlama` as "On-Device GGUF (4.9 GB) • NPU execution", and tasks mention "Verify NPU quantization". | Hallucinated on-phone LLM architecture. Re-align to canonical V1: Windows PC is the AI host; Android is an off-device companion. |
| **Hardware Literals** | Hardcoded strings reference specific GPU models (RX 580) and hostname assumptions (companion.local). | Product architecture should remain hardware-generic. Replace with generic terminology (`"Local AI Core • Windows PC"`, `"Connected over local network"`). Sample task becomes `"Benchmark Vulkan offload on PC Core"`. |
| **ViewModel Construction** | ViewModels instantiate default repositories or have parameterless constructors with isolated state. `AppContainer` alone cannot inject them into Compose without factories. | Add a standard manual `AppViewModelProvider.Factory` using the lifecycle `viewModelFactory` DSL to supply repositories from `AppContainer`. |
| **Appearance State Coupling** | `AppViewModel` owns `isDarkTheme: Boolean`, while `SettingsViewModel` owns appearance controls in isolation, with `resolvedDarkTheme` previously planned as persistent repository state. | Separate user preferences (`AppearancePreferences`) from runtime environmental resolution (`isSystemInDarkTheme()`). Unify under `AppearanceRepository`. |
| **Untyped Background Presets** | `selectedBuiltInBackground` was a raw string in `SettingsViewModel`. | Introduce typed enum `BuiltInBackgroundPreset` with concrete atmospheric color palettes. |
| **Tri-State Data Disconnection** | `HomeScreen` updates tasks in `FakeHomeRepository`, while `TasksScreen`, `ScheduleScreen`, and `AlarmsScreen` each maintain isolated in-memory stores in their ViewModels. | Lack of shared repository instances. Create `TasksRepository`, `ScheduleRepository`, and `AlarmsRepository` in `AppContainer`, delegating from `HomeRepository` to keep Home and dedicated tabs in sync. |
| **Dark Mode Over-Bordering** | In Dark mode, every `SoftGlassCard` renders a persistent gray outline via `BorderDark` / `borderGradient`, flattening the UI and cluttering screens. | Hardcoded default border on all cards. Remove persistent gray outlines; make borders optional and restrained, relying on tonal depth, surface hierarchy, and soft elevation. |
| **Light Mode Card Occlusion** | `MilkySurfaceBase = Color(0xFFFFFFFF)` in `Color.kt`. Cards in light mode are 100% opaque solid white. | Mobile calibration used flat white, hiding atmospheric glow beneath cards. Calibrate translucency visually against web references while preserving text contrast. |
| **Atmosphere Isolation** | `AmbientGlassBackground` is only used on preview/design-system screens. `AppShell` has a flat background color. | Translucent surfaces have nothing behind them to interact with. Wire root atmospheric backgrounds into `AppShell`. |
| **Primary Navigation Regression** | Tapping "Ask" on Home navigates to Assistant using a push navigation call without top-level graph pop/save/restore options. Tapping "Home" on the bottom bar leaves a duplicate or stacked route. | Inconsistent navigation options between quick actions and bottom bar destinations. Unify top-level destination switching policy so Home returns immediately without back gestures. |

---

## 3. Proposed File Changes & In-Place Logic

### Phase 1: Build & Scaffold De-Bloat

#### [NEW] [android/gradlew.bat](file:///d:/OtherProjects/AI-companion-project/android/gradlew.bat) & [android/gradlew](file:///d:/OtherProjects/AI-companion-project/android/gradlew) & `android/gradle/wrapper/gradle-wrapper.jar`
- Generate standard Gradle 9.3.1 wrapper files using the existing cached distribution so Windows commands run cleanly via `.\gradlew.bat`.

#### [MODIFY] [android/gradle/libs.versions.toml](file:///d:/OtherProjects/AI-companion-project/android/gradle/libs.versions.toml)
- Remove unused library definitions: `firebase-ai`, `firebase-appcheck-*`, `firebase-bom`, `retrofit`, `converter-moshi`, `okhttp`, `logging-interceptor`, `moshi-*`, `room-*`, `camera-*`, `play-services-location`, `credentials`, `googleid`.
- Remove unused plugins: `google-services`, `secrets`, `google-devtools-ksp`.
- Keep: Compose BOM, Navigation Compose, Lifecycle Runtime/ViewModel Compose, Coroutines, Core-KTX, JUnit, Robolectric, Roborazzi.

#### [MODIFY] [android/build.gradle.kts](file:///d:/OtherProjects/AI-companion-project/android/build.gradle.kts)
- Remove unused plugins: `alias(libs.plugins.google.devtools.ksp)`, `alias(libs.plugins.secrets)`, `alias(libs.plugins.google.services)`.

#### [MODIFY] [android/app/build.gradle.kts](file:///d:/OtherProjects/AI-companion-project/android/app/build.gradle.kts)
- Remove plugins: `google.devtools.ksp`, `secrets`, `google.services`.
- Remove `secrets { ... }` block and `googleServices { ... }` block.
- Remove invalid `debug` signing config referencing `${rootDir}/debug.keystore`.
- Prune `dependencies { ... }` down to actively used Compose, Lifecycle, Navigation, Coroutines, and test libraries.

#### [DELETE] [android/metadata.json](file:///d:/OtherProjects/AI-companion-project/android/metadata.json)
- Remove AI Studio export deployment artifact.

#### [DELETE] [android/.env.example](file:///d:/OtherProjects/AI-companion-project/android/.env.example)
- Remove Gemini API key placeholder.

#### [MODIFY] [android/README.md](file:///d:/OtherProjects/AI-companion-project/android/README.md)
- Replace AI Studio export instructions with a concise Android Companion subproject README:
  - Role: Companion client to Windows PC Local AI Core.
  - Tech stack: Kotlin, Jetpack Compose, Material 3, Navigation Compose, Coroutines.
  - Verification commands: `.\gradlew.bat :app:compileDebugKotlin`, `.\gradlew.bat :app:testDebugUnitTest`.
  - Architecture note: Local inference is PC-hosted; Android client operates in companion mode.

---

### Phase 2: Core Architecture, DI Container & Shared State Completeness

#### [NEW] [CompanionApplication.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/CompanionApplication.kt)
- Subclass `android.app.Application`.
- Instantiate and hold `val appContainer: AppContainer`.
- Register in `AndroidManifest.xml` via `android:name=".CompanionApplication"`.

#### [NEW] [di/AppContainer.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/di/AppContainer.kt)
- Define `interface AppContainer`:
  - `val appearanceRepository: AppearanceRepository`
  - `val tasksRepository: TasksRepository`
  - `val scheduleRepository: ScheduleRepository`
  - `val alarmsRepository: AlarmsRepository`
  - `val homeRepository: HomeRepository`
  - `val assistantRepository: AssistantRepository`
  - `val charactersRepository: CharactersRepository`
  - `val modelsAndDevicesRepository: ModelsAndDevicesRepository`
  - `val memoryRepository: MemoryRepository`
  - `val healthDataProvider: HealthDataProvider`
- Implement `class DefaultAppContainer(private val context: Context) : AppContainer`:
  - Holds single instances of `FakeTasksRepository`, `FakeScheduleRepository`, and `FakeAlarmsRepository`.
  - Constructs `FakeHomeRepository` by injecting the shared `tasksRepository`, `scheduleRepository`, and `alarmsRepository`.

#### [NEW] [ui/AppViewModelProvider.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/AppViewModelProvider.kt)
- Implement manual `ViewModelProvider.Factory` using the Jetpack Compose `viewModelFactory` DSL:
  - Initializers for `AppViewModel`, `TasksViewModel`, `ScheduleViewModel`, `AlarmsViewModel`, `AssistantViewModel`, `SettingsViewModel`, `CharactersViewModel`, `ModelsViewModel`, `DevicesViewModel`, `MemoryViewModel`, and `HealthViewModel`.
  - Pulls repository instances from `(this[APPLICATION_KEY] as CompanionApplication).appContainer`.
  - Eliminates parameterless constructors that construct isolated duplicate repositories.

#### [NEW] [domain/repository/TasksRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/repository/TasksRepository.kt) & [NEW] [data/fake/FakeTasksRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/fake/FakeTasksRepository.kt)
- Manage tasks: `getTasks(): StateFlow<List<MobileTask>>`, `toggleTaskCompletion(id: String)`, `addNewTask(title: String, priority: String, dueTime: String?)`, `deleteTask(id: String)`.
- Seeded with current task definitions from `TasksViewModel.initialMockTasks()`.

#### [NEW] [domain/repository/ScheduleRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/repository/ScheduleRepository.kt) & [NEW] [data/fake/FakeScheduleRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/fake/FakeScheduleRepository.kt)
- Manage schedule: `getScheduleEntries(): StateFlow<List<ScheduleEntry>>`, `toggleEntryCompletion(id: String)`, `dismissEntry(id: String)`, `addEntry(entry: ScheduleEntry)`.
- Seeded with current schedule definitions from `ScheduleViewModel.initialScheduleEntries()`.

#### [NEW] [domain/repository/AlarmsRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/repository/AlarmsRepository.kt) & [NEW] [data/fake/FakeAlarmsRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/fake/FakeAlarmsRepository.kt)
- Manage alarms: `getAlarms(): StateFlow<List<MobileAlarm>>`, `getRedundancyStatus(): StateFlow<AlarmRedundancyStatus>`, `toggleAlarmEnabled(id: String)`, `saveAlarm(alarm: MobileAlarm)`, `deleteAlarm(id: String)`.
- Seeded with current alarm definitions from `AlarmsViewModel.initialAlarms()`.

#### [MODIFY] [data/fake/FakeHomeRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/fake/FakeHomeRepository.kt)
- Inject `tasksRepository`, `scheduleRepository`, and `alarmsRepository`.
- Derive `todaySummary.openTasks` dynamically from `tasksRepository.getTasks()`.
- Derive `nextItem` dynamically from `scheduleRepository.getScheduleEntries()`.
- Delegate `toggleTaskCompletion` and `addNewTask` to `tasksRepository`.
- Generic hardware terminology: task description is `"Benchmark Vulkan offload on PC Core"`, model summary is `"Local AI Core • Windows PC (Active Model Ready)"`.

#### [MODIFY] [ui/screens/tasks/TasksViewModel.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/tasks/TasksViewModel.kt)
- Inject `tasksRepository: TasksRepository`.
- Read tasks from and apply mutations to the shared repository.

#### [MODIFY] [ui/screens/schedule/ScheduleViewModel.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/schedule/ScheduleViewModel.kt)
- Inject `scheduleRepository: ScheduleRepository`.
- Read entries from and apply mutations to the shared repository.

#### [MODIFY] [ui/screens/alarms/AlarmsViewModel.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/alarms/AlarmsViewModel.kt)
- Inject `alarmsRepository: AlarmsRepository`.
- Read alarms from and apply mutations to the shared repository.

#### [MODIFY] [domain/model/AssistantModels.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/AssistantModels.kt)
- Purge all claims of on-device LLM/NPU inference and replace with generic architecture literals:
  - `LocalLlama`: `name = "Local AI Core (PC)"`, `nodeHost = "Local Network (PC Host)"`, `state = CoreConnectionState.Local`, `description = "Primary Local AI Core running on Windows PC over local network."`
  - `RemoteTunnel`: `name = "Remote AI Core (PC)"`, `nodeHost = "Encrypted Remote Tunnel"`, `state = CoreConnectionState.Remote`, `description = "Windows PC Local AI Core reached via encrypted remote tunnel."`
  - `OfflineFallback`: `name = "Companion Standby"`, `nodeHost = "Standalone Android Client"`, `state = CoreConnectionState.Offline`, `description = "Offline companion client mode. Mirrored alarms, cached tasks, schedules, and health remain armed locally."`

#### [MODIFY] [domain/model/ConnectionStatus.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/ConnectionStatus.kt)
- In `OfflineFeatureMatrix.kt`: Remove false claim `"create new entries in Room DB"`; update to `"create and manage local cached entries"`.

---

### Phase 3: Appearance State Unification & Engine

#### [NEW] [domain/model/AppearanceModels.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/AppearanceModels.kt)
- Define canonical `AppearancePreferences`:
  ```kotlin
  data class AppearancePreferences(
      val themeMode: ThemeMode = ThemeMode.SYSTEM,
      val themeSource: ThemeSource = ThemeSource.PHONE_THEME,
      val accentPreset: AccentPreset = AccentPreset.BLUE,
      val backgroundType: BackgroundType = BackgroundType.BUILT_IN,
      val backgroundPreset: BuiltInBackgroundPreset = BuiltInBackgroundPreset.AURORA_CYAN,
      val effectsLevel: EffectsLevel = EffectsLevel.NORMAL
  )
  ```
- Normalize `AccentPreset`:
  ```kotlin
  enum class AccentPreset(val label: String, val colorHex: Long) {
      CYAN("Cyan Neon", 0xFF00E5FF),
      BLUE("Electric Blue", 0xFF2563EB),
      VIOLET("Soft Violet", 0xFF7C3AED),
      AMBER("Amber Glow", 0xFFF59E0B),
      EMERALD("Emerald Mint", 0xFF10B981)
  }
  ```
  *(Default is `BLUE`. `OBSIDIAN` is retained strictly as a theme/background option, not an accent).*
- Define typed `BuiltInBackgroundPreset`:
  ```kotlin
  enum class BuiltInBackgroundPreset(
      val id: String,
      val label: String,
      val primaryGlowHex: Long,
      val secondaryGlowHex: Long
  ) {
      AURORA_CYAN("aurora_cyan", "Aurora Cyan", 0x2400C4DF, 0x207C4DFF),
      MIDNIGHT_SLATE("midnight_slate", "Midnight Slate", 0x280B2B47, 0x1A1F293D),
      DEEP_OCEAN("deep_ocean", "Deep Ocean", 0x280B2B47, 0x222E6FF2),
      EMBER_WARMTH("ember_warmth", "Ember Warmth", 0x334A1224, 0x26F59E0B),
      NEBULA_VIOLET("nebula_violet", "Nebula Violet", 0x207C4DFF, 0x2400C4DF)
  }
  ```

#### [NEW] [domain/repository/AppearanceRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/repository/AppearanceRepository.kt) & [NEW] [data/fake/FakeAppearanceRepository.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/fake/FakeAppearanceRepository.kt)
- Expose `preferences: StateFlow<AppearancePreferences>`.
- Mutation functions: `setThemeMode`, `setThemeSource`, `setAccentPreset`, `setBackgroundType`, `setBackgroundPreset`, `setEffectsLevel`.
- Does NOT store `resolvedDarkTheme` in repository state; runtime dark theme is derived in the presentation layer.

#### [MODIFY] [MainActivity.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/MainActivity.kt)
- Clean leftover template code (`Greeting`, `GreetingPreview`, `MyApplicationTheme`).
- Obtain `appContainer = (application as CompanionApplication).appContainer`.
- Observe `appContainer.appearanceRepository.preferences`.
- Pass preferences into `SoftGlassTheme`.

#### [MODIFY] [ui/theme/Theme.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/theme/Theme.kt)
- Update `SoftGlassTheme` signature:
  ```kotlin
  @Composable
  fun SoftGlassTheme(
      preferences: AppearancePreferences,
      isSystemDark: Boolean = isSystemInDarkTheme(),
      content: @Composable () -> Unit
  )
  ```
- Derive `isDark = when (preferences.themeMode) { ThemeMode.LIGHT -> false; ThemeMode.DARK -> true; ThemeMode.SYSTEM -> isSystemDark }`.
- Dynamically build `SoftGlassColors` using `preferences.accentPreset` (mapping Cyan, Blue, Violet, Amber, Emerald), `preferences.effectsLevel` (modulating alpha/shadows), and `isDark`.
- Provide `LocalAppearancePreferences provides preferences`.
- Remove deprecated `MyApplicationTheme`.

#### [MODIFY] [ui/screens/settings/SettingsViewModel.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/settings/SettingsViewModel.kt)
- Inject `appearanceRepository: AppearanceRepository`.
- Forward `setThemeMode`, `setThemeSource`, `setAccentPreset`, `setBackgroundType`, `setBackgroundPreset`, and `setEffectsLevel` directly to `appearanceRepository`.
- In `SettingsScreen`, clearly render badges/markers indicating `ThemeSource.ACCOUNT_THEME` and `ThemeSource.SYNC_PC_THEME` as `"Future • Requires PC Sync"` / `"Future • Requires Account"` to be completely transparent about current V1.1 capabilities.

---

### Phase 4: Soft Glass V1.1 Mobile Visual Calibration & Atmosphere Wiring

#### [MODIFY] [ui/theme/Color.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/theme/Color.kt)
- **Light Mode Translucency:**
  - Replace solid opaque `MilkySurfaceBase = Color(0xFFFFFFFF)` with calibrated translucent milky surface. Final alpha will be visually calibrated against the web prototype to achieve visible softness and backdrop interaction without sacrificing text contrast.
  - Calibrate `TranslucentPanelLight` and `NavSurfaceLight`.
- **Dark Mode Depth & Border Calibration:**
  - Standard cards must not be outlined with harsh persistent gray borders.
  - Update `BorderDark` to subtle/restrained level (`Color(0x0AFFFFFF)` to `Color(0x14FFFFFF)`).
  - Tonal hierarchy: `BackgroundCharcoal` (deepest) &rarr; `BackgroundGraphite` &rarr; `DarkSurfaceBase` &rarr; `DarkSurfaceElevated` (raised card).
  - Sunken wells (`DarkSurfaceWell`) use tactile recessed shading, distinct from raised cards.
  - Restrained hairline borders: Make borders optional on content cards (`borderWidth = 0.dp` by default for standard content cards in dark mode), reserving accent borders (`accentGradient`) for selected/focused states.
  - Separately calibrate `NavSurfaceDark` and `NavSurfaceLight` for top and bottom navigation bars.

#### [MODIFY] [ui/components/SoftGlassCard.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/components/SoftGlassCard.kt) & [ui/components/GlassSurface.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/components/GlassSurface.kt)
- Update default parameters:
  - In Dark mode, normal cards do not draw high-contrast white/gray borders unless `isSelected = true` or explicitly requested.
  - Neumorphic depth is conveyed via surface fill contrast, tonal hierarchy, and soft ambient elevation shadows, not outline strokes.
- Modulate elevation and highlights based on `EffectsLevel` (`FULL`, `NORMAL`, `REDUCED`).

#### [MODIFY] [ui/shell/AppShell.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppShell.kt)
- Wire atmospheric backgrounds at the application root:
  - In `AppShell`, render the background canvas behind screen content based on `preferences.backgroundType`:
    - `BUILT_IN`: render `AmbientGlassBackground` with primary and secondary aura glows dynamically supplied by `preferences.backgroundPreset`.
    - `GRADIENT`: render multi-stop linear gradient.
    - `SOLID`: render clean matte background canvas without aura glows.
    - `CUSTOM_IMAGE`: render subtle matte pattern / fallback background.
  - Allows translucent `SoftGlassCard` and `GlassSurface` components across all screens to visually interact with root atmospheric depth.

---

### Phase 5: Primary Navigation Bug Fix

#### [MODIFY] [ui/shell/AppShell.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppShell.kt)
- Resolve the navigation stacking regression:
  - In `HomeScreen.kt` line 194, `onNavigateToRoute` currently calls `navController.navigate(route) { launchSingleTop = true }`.
  - When navigating to any primary destination (e.g., `Routes.ASSISTANT`, `Routes.TASKS`, `Routes.HEALTH`, `Routes.MORE`, `Routes.HOME`), route switching must follow the standard bottom-bar policy:
    ```kotlin
    val navigateToPrimaryDestination = { targetRoute: String ->
        navController.navigate(targetRoute) {
            popUpTo(navController.graph.findStartDestination().id) {
                saveState = true
            }
            launchSingleTop = true
            restoreState = true
        }
    }
    ```
  - Pass this policy to `HomeScreen`'s `onNavigateToRoute` for top-level routes (e.g. `Routes.ASSISTANT` from "Ask", `Routes.TASKS` from "Add Task").
  - Result: Navigating Home &rarr; Ask &rarr; Assistant &rarr; Home bottom-nav item returns immediately to Home without requiring back gestures, and does not leave duplicate stacked destinations.

---

## 4. Step-by-Step Implementation Sequence

```text
Step 1: Scaffold & Gradle De-Bloat
  ├── Generate missing gradlew.bat, gradlew, and gradle-wrapper.jar using local cached Gradle
  ├── Remove unused dependencies & plugins from gradle/libs.versions.toml
  ├── Remove KSP, Secrets, and Google Services plugins from root & app build.gradle.kts
  ├── Remove invalid debug signingConfig from app/build.gradle.kts
  ├── Delete metadata.json and .env.example
  └── Replace android/README.md with clean companion client documentation

Step 2: Core DI Architecture, ViewModel Factories & Shared State Completeness
  ├── Create CompanionApplication holding AppContainer
  ├── Create AppContainer interface and DefaultAppContainer implementation
  ├── Register CompanionApplication in AndroidManifest.xml
  ├── Implement TasksRepository, ScheduleRepository, and AlarmsRepository interfaces & fake implementations
  ├── Refactor FakeHomeRepository to derive state from and delegate to shared repositories
  ├── Implement AppViewModelProvider.Factory for lifecycle ViewModel instantiation
  ├── Update ViewModels to be constructed via AppViewModelProvider.Factory
  └── Purge on-device LLM/NPU claims and replace with generic architecture literals

Step 3: Appearance State Unification
  ├── Define AppearanceModels (AppearancePreferences, normalized AccentPreset, BuiltInBackgroundPreset)
  ├── Create AppearanceRepository interface & FakeAppearanceRepository implementation
  ├── Refactor SoftGlassTheme to consume AppearancePreferences and runtime isSystemInDarkTheme()
  ├── Wire MainActivity to observe AppearanceRepository and pass state to SoftGlassTheme
  └── Connect SettingsViewModel to AppearanceRepository and mark un-synced theme sources as future

Step 4: Soft Glass V1.1 Visual Calibration & Atmosphere Wiring
  ├── Calibrate Light mode card translucency in Color.kt
  ├── Calibrate Dark mode card surfaces in Color.kt and SoftGlassCard.kt:
  │     ├── Remove persistent gray card borders
  │     ├── Restrain hairline borders; rely on tonal depth and soft shadows
  │     └── Calibrate nav surfaces separately
  └── Wire atmospheric background rendering into AppShell using preferences.backgroundPreset and backgroundType

Step 5: Primary Navigation Bug Fix
  ├── Standardize destination navigation policy in AppShell
  └── Ensure quick-action route changes to primary destinations pop back cleanly

Step 6: Verification & Test Suite Alignment
  ├── Verify Windows gradlew.bat works from command line
  ├── Update existing unit & Robolectric tests for AppContainer, AppearanceRepository, and navigation
  ├── Run .\gradlew.bat :app:compileDebugKotlin
  └── Run .\gradlew.bat :app:testDebugUnitTest
```

---

## 5. Acceptance Criteria & Verification Plan

### Automated Repository Checks
- [ ] Gradle wrapper files (`gradlew.bat`, `gradlew`, `gradle/wrapper/gradle-wrapper.jar`) exist in the repository.
- [ ] `.\gradlew.bat :app:compileDebugKotlin` succeeds using the repository wrapper on Windows.
- [ ] `.\gradlew.bat :app:testDebugUnitTest` passes all test suites using the repository wrapper.
- [ ] Zero references to Firebase (`firebase-ai`, `firebase-appcheck`, `firebase-bom`), Google Services, or Secrets plugins in build files.
- [ ] Zero references to on-device NPU / on-device LLM inference in Android source files.

### Manual & Visual Acceptance Criteria
1. **Appearance State & Observable Rendering:**
   - Changing `ThemeMode` in Settings (`LIGHT`, `DARK`, `SYSTEM`) immediately changes the entire application and `MainActivity`; `SYSTEM` correctly resolves through Android's `isSystemInDarkTheme()`.
   - Changing `AccentPreset` (`CYAN`, `BLUE`, `VIOLET`, `AMBER`, `EMERALD`) immediately updates active tab indicators, button fills, slider thumbs, and selection pills across all screens.
   - Changing `BackgroundPreset` (`Aurora Cyan`, `Midnight Slate`, `Deep Ocean`, `Ember Warmth`, `Nebula Violet`) immediately updates the underlying atmospheric glow colors rendered in `AppShell`.
   - Changing `EffectsLevel` (`FULL`, `NORMAL`, `REDUCED`) produces an observable visual change in surface translucency, elevation shadows, and specular highlights.
   - Appearance selections survive normal screen navigation for the current in-memory app session.
   - Theme sources `ACCOUNT_THEME` and `SYNC_PC_THEME` are clearly labeled as `"Future • Requires PC Sync"` / `"Future • Requires Account"` to prevent false sync claims.
2. **Visual & Aesthetic Parity:**
   - In Light mode, cards appear visibly softer and translucent rather than flat 100% opaque white blocks, revealing ambient canvas glow while maintaining strict WCAG AA primary text contrast.
   - In Dark mode, standard cards do not display persistent harsh gray outline borders. Surface hierarchy between background, base surfaces, and elevated cards is distinct and readable without relying on outline strokes.
   - Sunken wells (`InteractiveSoftWell`) appear recessed via surface tint and soft shadow rather than flat borders.
   - Top bar and bottom navigation surfaces render with restrained, separately calibrated elevation and borders.
   - Home and Settings visual appearance reflects the Soft Glass styling of the PC Web control center reference in both Light and Dark modes.
3. **Shared State Synchronization (Tasks, Schedule, Alarms):**
   - Completing a task on `HomeScreen` immediately reflects as completed on `TasksScreen`.
   - Adding a task from `HomeScreen` immediately appears on `TasksScreen`.
   - Schedule entries on `ScheduleScreen` remain in sync with the `HomeScreen` next-item summary.
   - Alarm state changes on `AlarmsScreen` synchronize through the shared container.
4. **Primary Navigation Flow:**
   - Path: `Home` &rarr; tap "Ask" quick action &rarr; navigates to `Assistant` &rarr; tap "Home" bottom-nav item:
     - Returns immediately to Home.
     - System back gesture is not required.
     - No duplicate Assistant destination remains stacked on the backstack.
     - Tab state is preserved.
5. **Canonical V1 Architecture:**
   - Home, Assistant, and Models screens consistently identify the Windows PC Local AI Core as the primary host over local network, and Android as the companion client.
   - Hardware literals are generic (e.g. `"Benchmark Vulkan offload on PC Core"`, `"Local AI Core • Windows PC"`).

---

## 6. Risks, Recovery & Rollback

- **Risk:** Gradle wrapper generation could fail if offline or without local Java/Gradle distribution.
  - *Mitigation:* Verified local cached Gradle 9.3.1 distribution exists in `C:\Users\Admin\.gradle\wrapper\dists\gradle-9.3.1-all\9ot9r568e8zfvvd4mn8rbu1j0\gradle-9.3.1\bin\gradle.bat` and can be used to generate wrapper files offline.
- **Risk:** Removing unused networking/persistence dependencies could leave broken references if unexpected files imported them.
  - *Mitigation:* Audited all imports across `src/main/` and `src/test/`; confirmed zero imports of Retrofit, Moshi, or Room.
- **Risk:** Unifying tasks/schedule/alarms repositories could alter initial mock data expected by Robolectric screenshot or unit tests.
  - *Mitigation:* Initial data in `FakeTasksRepository`, `FakeScheduleRepository`, and `FakeAlarmsRepository` is cloned directly from the existing ViewModel initializers.
- **Rollback Plan:** All modifications are isolated to the `android/` working tree. If any phase introduces unexpected regressions, the Git working tree can be reverted to the baseline import commit.
