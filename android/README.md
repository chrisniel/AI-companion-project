# AI Companion — Android Mobile Client

Native Android companion client for the **Local AI Core** ecosystem, built with Kotlin, Jetpack Compose, and the mobile-adapted Soft Glass design language.

## Role & System Boundary

- **Host Role:** The Windows PC Local AI Core is the primary host orchestrating models, databases, and scheduling.
- **Companion Role:** This Android application serves as a mobile companion client providing conversational interaction, biometric wellness summaries, tasks, and locally armed alarms.
- **Network Boundaries:** Connects to the PC Local AI Core over direct private local network (LAN / Wi-Fi) or secure encrypted remote mesh (Tailscale). No on-device LLM/NPU inference is hosted on the phone in V1.

## Architecture

- **UI Framework:** Jetpack Compose with Material 3 foundations
- **Architecture Pattern:** Clean architecture with repository pattern and MVI/MVVM
- **State Management:** Kotlin Coroutines `StateFlow` and Compose `collectAsStateWithLifecycle`
- **Navigation:** Navigation Compose (`NavHost`)
- **Dependency Strategy:** Application-scoped manual `AppContainer` (`CompanionApplication.appContainer`) and Jetpack `viewModelFactory` providers

## Verification & Commands

From the `android/` directory on Windows:

```powershell
# Compile debug Kotlin sources
.\gradlew.bat :app:compileDebugKotlin

# Run unit and Robolectric test suites
.\gradlew.bat :app:testDebugUnitTest
```
