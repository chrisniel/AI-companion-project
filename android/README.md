# AI Companion — Android Mobile Client

> **Document Role:** Operational quickstart and subsystem orientation for Android mobile client development.
> **Status:** Active Operational Quickstart
> **Normative Architecture:** [`docs/04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md`](../docs/04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../docs/04_Architecture/SYSTEM_BASELINE.md).
> **Canonical Setup Guide:** [`docs/06_Guides/DEVELOPMENT_SETUP.md`](../docs/06_Guides/DEVELOPMENT_SETUP.md).
> **Canonical Verification Guide:** [`docs/06_Guides/TESTING_AND_CI.md`](../docs/06_Guides/TESTING_AND_CI.md).

Native Android companion client for the **Local AI Runtime** ecosystem, built with Kotlin, Jetpack Compose, and the mobile-adapted Soft Glass design language.

---

## 1. Role & Implementation Reality

### Current Prototype Reality
- **UI & Navigation:** 17 Jetpack Compose screens, Soft Glass neumorphic visual styling, pitch-black OLED power-saving theme, fluid spring-bounce physics, and Navigation Compose.
- **Dependency Injection:** Application-scoped manual `AppContainer` (`CompanionApplication.appContainer`) and Jetpack `viewModelFactory` providers.
- **Prototype Network Connection:** Bounded HTTP client (`LocalAiRuntimeClient`) using OkHttp 4 for host reachability (`/api/v1/health`), pairing token verification (`/api/v1/auth/verify`), and live two-way personal task synchronization (`HttpTasksRepository`).
- **Connection Configuration:** Host IP/hostname, port, and pairing token stored persistently in `SharedPreferences` (`SharedPreferencesConnectionRepository`).
- **Package Identity:** Currently uses template/prototype namespace (`namespace = "com.example"`, `applicationId = "com.aistudio.localcore.swbjtu"` in `app/build.gradle.kts`).

### Strategic Post-V1 Production Target
- **Package Migration (Decision D3):** Refactor namespace and application ID to canonical `com.cnl.aicompanion`.
- **Hardened Authentication (Decision D4):** Per-device revocable credentials backed by Android Keystore instead of plaintext `SharedPreferences`.
- **Durable Offline Persistence & Queue:** Room database persistence with mutation queue for full offline operation.
- **Complete State Synchronization:** Synchronization of conversations, profile state, and long-term memory with the PC Local AI Runtime.
- **Offline Inference & Deep Integrations:** Local on-device GGUF inference (tested ~0.27B–1.24B models on reference hardware), Health Connect synchronization, and voice/audio pipeline.

> [!NOTE]
> The current prototype networking layer is functional for live task synchronization and connection verification, but is **not** production-hardened multi-device sync. In V1, the primary client is the PC React Web application.

---

## 2. Subsystem Architecture

- **UI Framework:** Jetpack Compose with Material 3 foundations
- **Architecture Pattern:** Clean architecture with repository pattern and MVI/MVVM
- **State Management:** Kotlin Coroutines `StateFlow` and Compose `collectAsStateWithLifecycle`
- **Network Stack:** OkHttp 4 with coroutines dispatchers
- **Target SDK:** 36 (Minimum SDK: 24)

---

## 3. Verification & Commands

From the `android/` directory on Windows:

```powershell
# Compile debug Kotlin sources
.\gradlew.bat :app:compileDebugKotlin

# Run unit and Robolectric test suites
.\gradlew.bat :app:testDebugUnitTest
```

For authoritative test standards, baseline tracking, and CI details, consult [`docs/06_Guides/TESTING_AND_CI.md`](../docs/06_Guides/TESTING_AND_CI.md).
