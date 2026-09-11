# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project will use semantic versioning once releases begin.

## Unreleased

### Added

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
