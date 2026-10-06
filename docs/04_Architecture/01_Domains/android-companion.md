# Android Platform Adapter Architecture (Flutter Production & Prototype Boundary)

> **Document Role:** Canonical Android platform adapter architecture specification.
> **Status:** Active Canonical (Aligned with Batches A, B, C, and D2)
> **Canonical Ownership:** Mobile Companion production architecture is canonically established in [`MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md), [`mobile-offline-and-sync.md`](../04_Infrastructure/mobile-offline-and-sync.md), and [`mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md). This specification governs the Android platform adapter boundaries under the shared Flutter workspace topology (`D-SHARED-FLUTTER-01..08`) and preserves the reference role of the legacy Kotlin/Compose prototype (`android/`).

---

## 1. Prototype & Reference Boundary (`D-PHONE-FLUTTER-01`)

The exploratory Kotlin and Jetpack Compose codebase under `android/` serves strictly as prototype/UX/research and migration evidence:
- **Reference Evidence Only:** Source code in `android/` demonstrates exploratory Android UI, OkHttp networking, and basic task management. It does NOT represent canonical production architecture or production code.
- **No Mechanical Translation:** Production Flutter architecture recovers approved product behavior and intent, designing cleanly against canonical specifications rather than mechanically translating Kotlin code to Dart (`D-PHONE-FLUTTER-01`).
- **Interim vs. Production Identity:** The exploratory prototype uses interim namespaces (`com.example` / `com.aistudio.localcore.swbjtu`), whereas the target production application identity is frozen as `com.cnl.aicompanion` (Decision D3 / `ADR-0004`).

## 2. Flutter Android Platform Adapter Boundaries (`D-SHARED-FLUTTER-05`)

Under the shared monorepo workspace topology (`D-SHARED-FLUTTER-01`), shared Flutter packages define abstract service contracts, while concrete Android platform adapters interact with native OS APIs:

```text
+-------------------------------------------------------------+
|              Shared Flutter Domain & UI Layer               |
|   (Contracts, DTOs, State Logic, Design Tokens, Golden Tests)|
+-------------------------------------------------------------+
                              │
                              ▼ (Platform Service Contracts)
+-------------------------------------------------------------+
|             Android Platform Adapter Layer                  |
|  - Secure Storage (Keystore)    - Alarm Scheduling          |
|  - Background Sync (WorkManager)- OS Notifications          |
|  - Audio Focus & Capture        - Lifecycle / System Events |
+-------------------------------------------------------------+
                              │
                              ▼ (Native Android Platform APIs)
+-------------------------------------------------------------+
|               Android OS (API 26+ / Target API 34+)         |
+-------------------------------------------------------------+
```

### 2.1 Secure Storage Adapter (Android Keystore)
- **Security Invariant:** Device credentials (pairing tokens, device tokens) and user-configured third-party provider API keys MUST be stored via platform-protected secure storage backed by the **Android Keystore** (or a vetted Flutter secure storage abstraction utilizing Keystore).
- **Prohibition:** Storing credentials or tokens in unencrypted `SharedPreferences` or world-readable files is strictly prohibited.

### 2.2 Alarm Scheduling & Exact-Time Delivery Adapter
- **Exact Alarms (`AlarmManager.setAlarmClock()`):** Used for time-critical, user-facing Alarms requiring exact wall-clock triggering even in deep Doze.
- **Permission Lifecycle:** On Android 12+ (API 31+), `SCHEDULE_EXACT_ALARM` is user-revocable. The adapter MUST actively check `AlarmManager.canScheduleExactAlarms()` before arming or re-arming exact alarms.
- **Truthful Degradation:** If `canScheduleExactAlarms()` is false, the app flags Alarms as degraded/unarmed locally and warns the user; it does NOT falsely claim WorkManager provides alarm-fidelity scheduling.
- **Reboot & Timezone Rescheduling:** The adapter registers BroadcastReceivers for:
  - `ACTION_BOOT_COMPLETED`: Reschedules all active alarms from the local database.
  - `ACTION_TIMEZONE_CHANGED`: Recalculates floating-time alarms and re-registers intents.
  - `ACTION_TIME_CHANGED`: Re-evaluates pending alarm triggers against the updated clock.

### 2.3 Notification Delivery & Runtime Permissions
- **Runtime Notification Permission (`POST_NOTIFICATIONS`):** Required on Android 13+ (API 33+). If denied, status bar notifications and alert heads-up displays are suppressed by the OS.
- **Notification Channels:** Dedicated channels partition alert urgency (e.g., Alarms, Reminders, Routine Check-ins, System Status) with appropriate importance and acoustic behaviors.
- **Full-Screen Intents (`USE_FULL_SCREEN_INTENT`):** On Android 14+, full-screen intents are restricted by Google Play policy; the adapter cannot rely on full-screen intent as an unconditional bypass for missing notification permissions.

### 2.4 Background Synchronization Adapter (WorkManager)
- **Opportunistic Execution:** Deferrable background tasks (outbox mutation flushing, periodic delta synchronization) use Android `WorkManager` with network constraints (`NetworkType.CONNECTED`).
- **Foreground Service Prohibition:** Continuous foreground services for ordinary background data synchronization or polling are strictly prohibited to protect battery life and adhere to Android background execution limits.

## 3. Explicit Subsystem Boundaries

- **Health & Biometrics:** Real Health Connect integration and biometric synchronization are classified as **Mobile Later (Post-V1)**; prototype mock health UI in `android/` is sequestered. Real health sync must not be implemented until explicitly scheduled ([`health-and-wearables.md`](../03_Integrations/health-and-wearables.md)).
- **Voice Platform Adapters:** Voice foreground service lifecycles (`FOREGROUND_SERVICE_MICROPHONE`), audio focus arbitration, and microphone streaming operate under the dedicated Voice architecture defined in [`mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md) §3.4.
- **Autonomous Local Routines:** Autonomous recurrence generation and routine execution on the phone are deferred post-V1; Mobile presents bounded Host-authorized occurrences replicated from the PC Host (`D-PHONE-12`).
