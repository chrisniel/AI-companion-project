# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project will use semantic versioning once releases begin.

## Unreleased

### Added

- Local AI Core Backend Bootstrapping & OWASP API Security: Initialized `backend/` using Python 3.13, FastAPI, SQLAlchemy 2.0 (asyncio + `aiosqlite`), and Alembic migrations. Implemented zero-configuration 32-byte pairing token authentication (`secrets.token_urlsafe(32)`), constant-time token verification (`secrets.compare_digest`), strict Pydantic v2 mass-assignment guards (`extra="forbid"`), and strict CORS origin whitelisting.
- First Vertical Slice (Health & Tasks CRUD): Delivered public probe (`/api/v1/health`), protected host telemetry (`/api/v1/system/status`), pairing check (`/api/v1/auth/verify`), and complete Tasks CRUD endpoints with status/priority filtering, backed by asynchronous SQLite with Write-Ahead Logging (`PRAGMA journal_mode=WAL`).
- Automated Pytest Suite & OpenAPI Contract Export: Added 12 automated unit and integration tests passing in 0.22s with in-memory SQLite fixtures (`pytest` + `httpx`), exported OpenAPI 3.1 contract to `contracts/openapi/openapi.json`, and published interactive Swagger documentation at `http://127.0.0.1:8000/docs`.

### Added & Fixed

- Assistant Tab Autoscroll Optimization: Pre-positioned `listState` at the latest message upon entering the Assistant workspace with zero animated scrolling lag; `animateScrollToItem` is now selectively triggered only when new messages are appended or during active LLM token streaming.
- Custom UI Wallpaper Frosted Blur: Added `Modifier.blur(18.dp)` to custom image background rendering in `AppShell.kt`, bringing gallery wallpapers into visual parity with built-in aura presets.
- Viewport-Level Floating Vault Popover on Home: Replaced the inline layout-expanding card in `HomeScreen.kt` with a direct trigger to the root `VaultPopoverOverlay`, ensuring the Vault displays as a floating glassmorphic popover with a dismissible scrim without shifting or pushing down feed content.
- Real-Time Horizontal Swipe Tracking: Implemented 1:1 tactile touch translation (`swipeOffset` with `graphicsLayer { translationX }`) across root destinations in `AppShell.kt`, providing immediate visual feedback during finger drag with natural spring snapping.
- Direction-Aware Bottom Navigation Slide Transitions: Aligned bottom navigation destination transitions in `AppShell.kt` with `AnimatedContent` direction-aware spring slide and fade animations (`dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow`, `slideInHorizontally(it/3) + fadeIn(220)` & `slideOutHorizontally(-it/4) + fadeOut(180)`), eliminating intermediate screen flashes when jumping between non-adjacent tabs while keeping horizontal swipe gestures responsive.
- OLED Battery Saver & Reduced Mode Button/Pill Parity: Updated `SelectablePill`, `SelectionCardItem`, and `SettingsSectionTabs` in `SettingsScreen.kt` to strictly honor `ThemeMode.OLED_BATTERY_SAVER` (flat `#121214` obsidian containers with `#1F1F23` hairline borders and zero drop shadows) and `EffectsLevel.REDUCED` (`isLightweight = true`, minimal shadow depth).
- Settings Appearance Neumorphic Naming & Scrollable Background Row: Renamed visual effects header to `"NEUMORPHIC VISUAL EFFECTS"` and added `.horizontalScroll(rememberScrollState())` to the Mobile Background row in `SettingsScreen.kt` so all 4 options (`[Built-in]`, `[Custom Image UI]`, `[Gradient]`, `[Solid]`) are fully visible and selectable.
- Decoupled Background Layer & Custom Wallpaper Photo Decoding: Fixed custom image decoding in `AppShell.kt` to decode device gallery images, rendered under glass with contrast scrim, and decoupled `AppBackgroundLayer` beneath `renderScaffold()` so selecting background types never recreates the Scaffold or resets scroll position.
- Overscroll Viewport Boundary Clipping: Added `.clipToBounds()` before the graphics layer in `SoftBounceOverscroll.kt`, ensuring bouncing content strictly stays within the scrollable viewport without rendering over top bars or tabs.
- Global Animated Vault Popover Overlay: Wired top bar avatar across all primary and secondary screens to open the floating animated glassmorphic Vault Popover overlay showing on-device SQLite vault status, host connection details, and a direct settings link.

### Fixed

- 60Hz Display Lock on High-Refresh Screens: Dynamically query `display.supportedModes` in `MainActivity.kt` to configure `preferredDisplayModeId` and `preferredRefreshRate` matching the hardware's maximum available capability (60Hz, 90Hz, 120Hz, 144Hz, 165Hz), unlocking native 120Hz fluid motion on Infinix ZERO ULTRA and modern devices instead of falling back to the 60Hz battery-saver default.
- Multi-Tab Traversal Spike on Bottom Navigation: In `AppShell.kt`, bottom navigation taps to non-adjacent destinations (e.g. Home to More) now execute a direct jump via `scrollToPage(targetIndex)`, bypassing the layout and composition spikes of traversing screens 1, 2, and 3. Physical horizontal swiping retains 1:1 finger tracking between adjacent screens.
- Horizontal Swipe Lag & Tab Hitching: Set `beyondViewportPageCount = 2` in `HorizontalPager` to keep adjacent tab screens pre-warmed in memory, and replaced fixed 200ms tweens with natural velocity-tracking spring physics (`dampingRatio = 0.90f`).
- Restored Authentic Dual-Light Neumorphism: Reverted `isLightweight` default to `false` in `SoftNeumorphic.kt`, `SoftGlassCard.kt`, and `SoftButtons.kt`, fully restoring rich 3D physical dual-light clay depth and specular highlights in Light and Dark modes. Retained thread-safe `BlurFilterCache` (`ConcurrentHashMap<Int, BlurMaskFilter>`) to eliminate native Skia object reallocations and GC stutter.
- Scroll Momentum & Fast Fling Recovery: Fixed `SoftBounceOverscroll.kt` fling velocity interception where fast downward/upward swipes bounced back instead of flinging through content; implemented direction-aware velocity filtering (`onPreFling` returns `Velocity.Zero` when flinging into content to pass 100% velocity to child scrollables while spring-animating overscroll to 0 concurrently), immediate touch-down gesture cancellation (`animJob?.cancel()`), and synchronous state updates via `mutableFloatStateOf(0f)`.

### Changed

- Effects Level Semantics (`Reduced`, `Normal`, `Enhanced`): On `Reduced`, glass visual effects (frosted border gradient, translucent surface, specular highlight, ambient aura glow) remain identical to `Normal` (`specularAlpha = 0.22f`), while only the neumorphic 3D shadow depth is reduced (`shadowFactor = 0.20f`). `Enhanced` delivers visibly deeper shadow contrast (`shadowFactor = 1.5f`) and boosted specular highlights (`specularAlpha = 0.35f`).
- Native Infinix Zero Ultra OLED Pitch-Black Theme: Refined `ThemeMode.OLED_BATTERY_SAVER` across `Theme.kt`, `Color.kt`, `AppShell.kt`, `SoftGlassCard.kt`, and `SoftButtons.kt` to pure pitch black (`#000000`) with zero glassmorphism, zero ambient glows, and zero neumorphic drop/inset shadows. Cards render as flat obsidian containers (`#121214`) with subtle hairline dividers (`#1F1F23`) and high-contrast typography (`#FFFFFF`).

### Added

- Real Android Photo Picker for Custom UI Wallpapers: Integrated `ActivityResultContracts.PickVisualMedia()` in `SettingsScreen.kt` with persistent URI permissions and safe full-screen decoding (`ImageDecoder` / `BitmapFactory`) in `AppShell.kt`.

- "OLED Battery Saver" pure pitch-black (`#000000`) theme mode for AMOLED displays in `SoftGlassTheme`: completely turns off physical screen pixels, sets drop-shadow elevation to 0 (eliminating GPU fill-rate overhead and gray halo artifacts), renders luminous hairline borders, and emphasizes high-contrast glowing accents and typography.
- Persistent appearance and theme storage via `SharedPreferencesAppearanceRepository`, ensuring user selections for theme mode (`Light`, `Dark`, `OLED Battery Saver`), built-in background presets, solid finishes, and effects level survive process recreation and device reboots.
- Contrast calibration for Light and Dark themes: elevated Light Mode muted text and icons (`TextMutedLight = #334155`, Slate-700) for sharp readability against light clay surfaces, and brightened Dark Mode muted icons (`TextMutedDark = #94A3B8`, Slate-400) preventing them from fading into charcoal backgrounds.
- Real Local AI Core Host Network Configuration card in `ConnectionScreen.kt`: editable Host IP/Hostname, Port, and API Token inputs with reachability validation and persistent state saving.
- On-Device Hybrid Failover controls in `ModelsScreen.kt`: dual-engine routing architecture featuring auto-failover toggle, on-device quantized LLM card (`Gemma-2-2B` / `Qwen-2.5-1.5B`), edge neural voice synthesis card (`Kokoro-82M ONNX` at <0.3x RTF), SAF model file import (`.gguf` / `.onnx`), in-app chunked downloader, and on-device RAM allocation gauge.
- Architectural design and canonical plan updates in `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` documenting the Hierarchical Model Routing Architecture, Dynamic Network Heartbeats, zero-dependency model storage, and AMOLED power optimization.
- Momentum-driven two-phase spring bounce overscroll physics in `SoftBounceOverscroll.kt`: absorbs fast fling inertia by smoothly translating content outside container bounds to a velocity-scaled apex before snapping back with authentic rubber-band spring recoil (`DampingRatioMediumBouncy`, `StiffnessLow`).
- Universal overscroll coverage across all primary and secondary scrollable screens, dialogs, and sheets (`AssistantHistorySheet`, `MemoryScreen`, `ConnectionAndSyncBanners`, `TasksScreen`, `HomeScreen`, `MoreScreen`, `AssistantScreen`, `CharactersScreen`, `ModelsScreen`, `DevicesScreen`, `AlarmsScreen`, `PermissionsScreen`, `ConnectionScreen`, `PlaceholderScreen`, `VoiceModeScreen`).
- Pure black (`Color.Black`) tinting for unselected bottom navigation menu items (`Home`, `Tasks`, `Health`, `More`) in Light Mode, preserving center Assistant action button styling.
- Auto-dismissing elevated status toast in `SettingsScreen` (2.6s cancellable coroutine timeout, full-screen tap-anywhere overlay dismiss, elevated 68dp above bottom navigation bar, enlarged typography and CheckCircle status icon).
- Interactive profile avatar popover on Home screen revealing user profile, host connection status indicator, and settings link.
- Compact language selection dropdown menu in Home Assistant Hero (`[ 🌐 Auto ▾ ]`) supporting English, Filipino, Japanese, and Mixed Mode.
- Subtle spring bounce physics to `HorizontalPager` fling gestures (`dampingRatio = 0.82f`) and bottom tab navigation clicks.
- Smooth animated horizontal spring transitions (`AnimatedContent`) for Settings section category switching.
- Horizontal swipe navigation across 5 primary tabs (`Home | Tasks | Assistant | Health | More`) via `HorizontalPager` with 1:1 physical finger tracking and neighbor screen pre-composition (`beyondViewportPageCount = 1`).
- Directional sliding transitions between primary tabs and animated push/pop sliding for secondary destinations in `NavHost`.
- Liquid glass transition depth transformation (`graphicsLayer` scale and alpha damping during swipe gestures) to eliminate abrupt screen content pop-in.
- Back button return-to-Home handling (`BackHandler`) ensuring secondary tabs transition back to Home before exiting the app.
- Soft Glass simulated neumorphic rendering engine (`SoftNeumorphic.kt`) implementing zero-allocation directional dual-shadows (`softNeumorphicRaised`) and recessed wells (`softInsetWell`) for battery-efficient tactility matching the React web client.
- Light and dark ambient background presets parity (4 Light: Aurora Mist, Pearl Bloom, Cloud Glass, Lavender Flow; 4 Dark: Midnight Aurora, Graphite Waves, Deep Violet, Blue Ember) and 4 light solid finishes.
- User-adjustable Contrast Scrim Opacity (0–60%) and Background Brightness (50–150%) sliders in Appearance settings.
- Floating center elevated Assistant action button in bottom navigation with 52dp circular touch target, 26dp icon, and instant 120ms feedback.
- Clean-chat initial launch state with starter prompt suggestion cards.
- Sticky Settings section tabs pinned outside the scroll container with automatic scroll-to-top on section switch.
- Windows Gradle wrapper (`gradlew.bat`, `gradlew`, `gradle-wrapper.jar`) and companion client guide in `android/README.md`.
- Application-scoped manual `AppContainer` (`CompanionApplication`) and Jetpack `AppViewModelProvider.Factory` for constructor-injected ViewModels.
- Shared in-memory `TasksRepository`, `ScheduleRepository`, and `AlarmsRepository` interfaces and fake implementations.
- Unified `AppearanceRepository` with typed `AppearancePreferences` (`ThemeMode`, `ThemeSource`, `AccentPreset`, `BuiltInBackgroundPreset`, `EffectsLevel`).
- Standardized AI-assisted documentation workflow, numbered documentation scaffold, active task tracking, and an approval-gated master-plan reconciliation plan.
- Reconciled the canonical master plan with repository-verified status, external Android Batch 12 progress, Google AI Studio workflow boundaries, current testing facts, and an explicit open model-storage decision.
- Added a major-change commit handoff rule: the AI proposes a commit message and the user manually commits and pushes.
- Organized the canonical master plan, historical drafts, current web-productionization plan, accepted LFS ADR, documentation map, project-input checklist, completed-task archive, and delivery walkthrough.
- Set AI repository access to read-only by default, with edits requiring explicit task-specific authorization.

### Fixed

- Eliminated More screen button navigation layout jump / drop-down glitch: removed conditional dynamic collapse of `Scaffold.topBar` in `AppShell.kt` which was causing abrupt 56dp viewport shifts on click, migrating top bars into authoritative, steady internal layouts inside individual screens.
- Calibrated fluid momentum overscroll physics in `SoftBounceOverscroll.kt`: reduced `maxOverscrollPx` stretch ceiling to 140f, applied quadratic progressive resistance (`(1 - dragRatio)^2 * 0.32f`) to prevent abrupt rubber-band resistance freezing, increased high-speed fling collision threshold to 650f px/s, and clamped maximum apex bounce displacement to <=85px.
- Resolved zero-height semantics clipping on Home screen user avatar popover overlay: replaced artificial 0-height custom layout placement with natural layout bounds and top padding, restoring full visibility in Robolectric accessibility tests.
- Resolved multi-node test ambiguity on `topbar_connection_indicator` in `NavigationRobolectricTest`: updated Compose test assertion to query `.onFirst().assertIsDisplayed()` to handle pre-composed adjacent screens safely.
- Suppressed native Android 12+ stretch `EdgeEffect` rendering distortion via `LocalOverscrollConfiguration provides null` in `SoftGlassTheme`.
- Calibrated physical dual-shadow neumorphic engine in `SoftNeumorphic.kt`: tightened top-left specular highlight offset and blur radius (down to 1.5–4dp) and lowered specular alpha (`0.10f` in dark mode), completely eliminating upward foggy shadow bleed over section headers and container borders above.
- Enhanced authentic neumorphic inset well accuracy in `softNeumorphicInset` and `SoftGlassCard.kt`: increased inner shadow blur radius up to 16dp for soft, deep concave recession, and preserved natural surface background color (`SoftTheme.colors.surface` / `actualBackgroundColor`) on selected cards instead of swapping to an artificial darker slab color (`surfacePressed`).
- Resolved monstrous 1-character-wide vertical letter-snake bug in `CapabilityHubCard` (`PermissionsScreen.kt`) and `PlaceholderScreen.kt` (`About` screen) caused by horizontal row crowding; repositioned `StatusBadge` cleanly below long titles inside `Column(modifier = Modifier.weight(1f))` with full horizontal clearance.
- Eliminated touch-intercepting full-screen overlay in `SettingsScreen.kt` so users can immediately interact with other controls during toast display without extra dismissal taps; reduced auto-dismiss timeout from 2.6s to a snappy 1.4 seconds with smooth fade-out.
- Streamlined Home screen user avatar by removing redundant, clipped online status dot, and upgraded `SoftAvatar` to render an integrated 1.5dp glowing status border ring around the avatar circle (Green = Online, Orange = Reconnecting, Red = Offline) that is completely impervious to container clipping.
- Expanded vertical selection card spacing in `SettingsScreen.kt` to `10.dp` across Theme Source, Glass Visual Effects, and Ambient Presets, adding generous `8.dp` negative space below section titles.
- Resolved indefinitely persisting status toast in `SettingsScreen` that required manual tapping on "X"; implemented auto-dismiss timer and smooth 240ms vertical fade transitions.
- Restored authentic physical dual-shadow `BlurMaskFilter` neumorphic rendering engine (`softNeumorphicRaised` and `softNeumorphicInset`) as default across the application, preserving physical 3D clay extrusion and concave inset depth while integrating `EffectsLevel` under Appearance settings so users can freely choose between Authentic Neumorphic (default) and Lightweight GPU fallback mode (battery saver).
- Eliminated continuous 120Hz infinite recomposition loops in `ConnectionIndicator`, `CompactConnectionIndicator`, `PulsingConnectingDot`, and `AuditioningPulseContainer` that drained battery and starved UI threads; steady states (`Local`, `Remote`, `Offline`) now render static calm dots with 0 Choreographer overhead, while active connecting animations defer properties to off-thread `Modifier.graphicsLayer`.
- Resolved motion dizziness and visual disorientation during tab swiping by removing 3D scale dips and alpha damping from `HorizontalPager` containers, establishing clean 1:1 lateral tracking.
- Eliminated jarring teleportation during bottom tab navigation clicks; unified tab transitions to smooth 180ms tween animations (`FastOutSlowInEasing`).
- Reduced memory consumption and background rendering work by setting `HorizontalPager` `beyondViewportPageCount` to 0.
- Eliminated notch, hole-punch camera, and status bar clock collisions across custom top-bar screens (`SettingsScreen`, `PermissionsScreen`, `CharactersScreen`, `ConnectionScreen`, and `AssistantScreen`) by applying explicit `statusBarsPadding()` to their root header layouts.
- Removed duplicate top navigation bars and double back buttons in System Hub sub-screens (`ModelsScreen`, `DevicesScreen`, and `MemoryScreen`) by omitting redundant local headers when embedded within `AppShell`'s authoritative `AppTopBar`.
- Fixed off-center, bottom-crowded telemetry layout in Home screen `WellnessGlanceCard` items, vertically and horizontally centering metrics (`Arrangement.Center`, `Alignment.CenterHorizontally`) with balanced breathing room.
- Eliminated multi-color neon rainbow borders on `ScheduleScreen` agenda cards, unifying them with the standard `SoftGlassTheme` subtle hairline border while enabling 2-line title wrapping (`maxLines = 2`) to prevent mid-word truncation.
- Fixed awkward vertical letter wrapping in metadata tags across `TaskRowItem` (using `FlowRow`), `DevicesScreen` latency text, `RedundancyStatusCard` failover status, and `MemoryScreen` tags via `softWrap = false` and `TextOverflow.Ellipsis`.
- Resolved asymmetrical button heights in Settings language toggles (`[English]` vs `[Filipino / Tagalog]`) by establishing a uniform `minHeight = 44.dp` touch target with centered text alignment.
- Prevented floating action buttons (FAB) from obscuring the bottom-most list items in `AlarmsScreen` and `MemoryScreen` by expanding `LazyColumn` bottom content padding to `112.dp`.
- Restored subtle hairline borders on dark mode glass cards (`SoftGlassCard.kt`) for crisp edge definition without heavy visual outlines.
- Eliminated the artificial glowing border ring around selected bottom navigation items by replacing high-opacity 1.5dp strokes and cyan gradients with delicate 0.75dp hairline borders (`rgba(255, 255, 255, 0.12)` in dark mode, `0.35` in light mode) and soft dual drop shadows matching the web client `--neu-nav-embossed` design tokens.
- Fixed transition lag and frame drops during bottom navigation switching by eliminating screen destruction and re-instantiation through pager pre-composition.
- Resolved pre-composition semantics ambiguity in Robolectric UI tests by scoping duplicate element selectors.
- Surgically anchored the root `data/` ignore rule to `/data/` in `.gitignore` so Android data source packages (`com.example.data.*`) are properly tracked.
- Eliminated parallel theme state across `AppViewModel` and `SettingsViewModel`, making `AppearanceRepository` the single authority for appearance preferences with dynamic runtime system resolution.
- Connected built-in atmospheric backgrounds, curated gradients, solid finishes, and safe custom accent hex parsing with fallback to `AppearanceRepository` and `AppShell`.
- Neutralized prototype labels and strings, establishing generic "Local AI Core (Simulated)" terminology and "License Not Selected" About metadata.

### Changed

- Renamed Android application label and fallback navigation title to "AI Companion".
- Aligned dark mode canvas and surface tokens to neutral stealth matte charcoal and obsidian graphite (`#0E1015`, `#14161C`, `#1F2229`, `#121419`) matching pure neumorphic depth references while retaining subtle translucent glass headers.
- Switched default brand accent from cyan to deep Royal Blue (`#1D4ED8` / `#60A5FA`).
- Streamlined Home screen header: removed redundant `AppTopBar`, added dynamic model status subtitle (`● Aura is online`), and nested profile telemetry inside the interactive avatar popover card.
- Refined Assistant composer layout: constrained action buttons to 36dp with 8dp spacing and explicit touch bounds to eliminate touch collision, styled Send with raised soft neumorphic elevation, and added dynamic inset-to-emboss morphing on the message text box.
- Reordered bottom navigation to `Home | Tasks | Assistant | Health | More` with floating center action button.
- Eliminated screen transition lag by replacing un-animated NavHost mount/unmount with 120ms GPU-accelerated crossfades (`fadeIn` 120ms / `fadeOut` 90ms with `LinearOutSlowInEasing`) and decoupled background canvas.
- Converted Assistant chat system events, tool actions, and memory recalls into compact single-line expandable notification pills that do not dominate the conversation.
- Removed quick theme toggle buttons from contextual top bars (`AppTopBar` and `AssistantHeader`), consolidating theme controls into Settings -> Appearance.
- Refined the Android prototype into an architecturally aligned V1.1 companion client for the Windows PC Local AI Core host.
- Unified `SoftGlassTheme` to consume authoritative appearance preferences and dynamically resolve dark mode at runtime via Compose's `isSystemInDarkTheme()`.
- Calibrated Soft Glass V1.1 visuals with translucent light mode surfaces, removed heavy dark mode card outlines, and added dynamic atmospheric glow backgrounds in `AppShell`.
- Linked `HomeViewModel` and `FakeHomeRepository` dynamically to shared task, schedule, and alarm repositories.
- Corrected top-level navigation stacking in `AppShell` for quick action navigation.

### Removed

- Pruned unused dependencies and plugins (Firebase, Retrofit, Room) and removed AI Studio export artifacts (`metadata.json`, `.env.example`).
- Purged misleading on-device LLM/NPU/GGUF claims, aligning strings and status models with the Windows PC Local AI Core host.
