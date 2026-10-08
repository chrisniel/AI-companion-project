# AI Companion — Android Mobile Client

> **Document Role:** Operational quickstart and subsystem orientation for Android mobile client development.
> **Status:** Active Operational Quickstart
> **Normative Architecture:** [`docs/04_Architecture/01_Domains/android-companion.md`](../docs/04_Architecture/01_Domains/android-companion.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../docs/04_Architecture/SYSTEM_BASELINE.md).
> **Canonical Setup Guide:** [`docs/06_Guides/DEVELOPMENT_SETUP.md`](../docs/06_Guides/DEVELOPMENT_SETUP.md).
> **Canonical Verification Guide:** [`docs/06_Guides/TESTING_AND_CI.md`](../docs/06_Guides/TESTING_AND_CI.md).

Kotlin/Jetpack Compose Android prototype and reference client for the **Local AI Runtime** ecosystem, using the mobile-adapted Soft Glass design language. Flutter is the Mobile V1 production target; this prototype does not establish that production implementation.

---

## 1. Role & Implementation Reality

### Current Prototype Reality
- **UI & Navigation:** 17 Jetpack Compose screens, Soft Glass neumorphic visual styling, pitch-black OLED power-saving theme, fluid spring-bounce physics, and Navigation Compose.
- **Dependency Injection:** Application-scoped manual `AppContainer` (`CompanionApplication.appContainer`) and Jetpack `viewModelFactory` providers.
- **Prototype Network Connection:** Bounded HTTP client (`LocalAiRuntimeClient`) using OkHttp 4 for host reachability (`/api/v1/health`), pairing token verification (`/api/v1/auth/verify`), and live two-way personal task synchronization (`HttpTasksRepository`).
- **Connection Configuration:** Host IP/hostname, port, and pairing token stored persistently in `SharedPreferences` (`SharedPreferencesConnectionRepository`).
- **Package Identity:** Currently uses template/prototype namespace (`namespace = "com.example"`, `applicationId = "com.aistudio.localcore.swbjtu"` in `app/build.gradle.kts`).

### Mobile V1 Production Target (Flutter; Independent of PC V1)
- **Production Identity (Decision D3):** The Flutter production target uses canonical `com.cnl.aicompanion`; the current Kotlin prototype identifiers remain reference-only.
- **Hardened Authentication (Decision D4):** Per-device revocable credentials backed by Android Keystore instead of plaintext `SharedPreferences`.
- **Durable Offline Persistence & Queue:** Production persistence and mutation-queue boundaries follow [`mobile-offline-and-sync.md`](../docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md); the Kotlin prototype is not production offline-sync evidence.
- **Complete State Synchronization:** Synchronization of conversations, profile state, and long-term memory with the PC Local AI Runtime.
- **Offline Inference & Voice:** Production device-local inference and voice/audio follow the accepted Mobile capability architecture and require hardware qualification.
- **Health Connect:** Conditional Mobile V1, read-only and consent-driven on qualified Android environments (`D-PHONE-15`). Unsupported devices or absent consent remain valid companion installations; Kotlin mock health UI remains non-production reference ([canonical owner](../docs/04_Architecture/03_Integrations/health-and-wearables.md)).

> [!NOTE]
> The current prototype networking layer is functional for live task synchronization and connection verification, but is **not** production-hardened multi-device sync. Flutter Desktop is the approved primary PC V1 production client; React remains the supported web/development harness.

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
