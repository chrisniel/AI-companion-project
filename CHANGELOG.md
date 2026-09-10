# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project will use semantic versioning once releases begin.

## Unreleased

### Added

- Windows Gradle wrapper (`gradlew.bat`, `gradlew`, `gradle-wrapper.jar`) and companion client guide in `android/README.md`.
- Application-scoped manual `AppContainer` (`CompanionApplication`) and Jetpack `AppViewModelProvider.Factory` for constructor-injected ViewModels.
- Shared in-memory `TasksRepository`, `ScheduleRepository`, and `AlarmsRepository` interfaces and fake implementations.
- Unified `AppearanceRepository` with typed `AppearancePreferences` (`ThemeMode`, `ThemeSource`, `AccentPreset`, `BuiltInBackgroundPreset`, `EffectsLevel`).
- Standardized AI-assisted documentation workflow, numbered documentation scaffold, active task tracking, and an approval-gated master-plan reconciliation plan.
- Reconciled the canonical master plan with repository-verified status, external Android Batch 12 progress, Google AI Studio workflow boundaries, current testing facts, and an explicit open model-storage decision.
- Added a major-change commit handoff rule: the AI proposes a commit message and the user manually commits and pushes.
- Organized the canonical master plan, historical drafts, current web-productionization plan, accepted LFS ADR, documentation map, project-input checklist, completed-task archive, and delivery walkthrough.
- Set AI repository access to read-only by default, with edits requiring explicit task-specific authorization.

### Changed

- Refined the Android prototype into an architecturally aligned V1.1 companion client for the Windows PC Local AI Core host.
- Unified `SoftGlassTheme` to consume authoritative appearance preferences and dynamically resolve dark mode at runtime via Compose's `isSystemInDarkTheme()`.
- Calibrated Soft Glass V1.1 visuals with translucent light mode surfaces, removed heavy dark mode card outlines, and added dynamic atmospheric glow backgrounds in `AppShell`.
- Linked `HomeViewModel` and `FakeHomeRepository` dynamically to shared task, schedule, and alarm repositories.
- Corrected top-level navigation stacking in `AppShell` for quick action navigation.

### Removed

- Pruned unused dependencies and plugins (Firebase, Retrofit, Room) and removed AI Studio export artifacts (`metadata.json`, `.env.example`).
- Purged misleading on-device LLM/NPU/GGUF claims, aligning strings and status models with the Windows PC Local AI Core host.
