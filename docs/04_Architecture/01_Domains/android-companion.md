# Android Companion Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.2).  
> **Authority Precedence:** Focused staged specification authored during R11.2. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md`](../ANDROID_COMPANION_ARCHITECTURE.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decisions D1, D3, D4) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the mobile architecture, synchronization protocol, security boundaries, and offline capabilities for the Android Companion client:
- Identity, package namespaces, and application boundaries.
- Client synchronization model with the PC Local AI Runtime as the canonical authority.
- Trusted device credentials and secure hardware storage.
- Compact offline local LLM execution boundaries.
- Android Health Connect integration for biometric companion context.
- Phased delivery boundaries distinguishing PC V1 from Android V1.

It governs the boundary between the desktop host runtime and the satellite mobile companion.

---

## 2. Durable Architecture & Invariants

### 2.1 Release Phasing & Non-Blocking Invariant

In accordance with Decision D1:
- **Independent Follow-on Release:** Android V1 is an independent, follow-on production mobile release.
- **Non-Blocking Invariant:** Development, verification, or staging of the Android Companion does **not** block the delivery, feature freeze, or release of the PC V1 ecosystem milestone.
- **Canonical Authority:** The PC Local AI Runtime owns persistent canonical authority over user data, conversation histories, memories, and task state. Android operates as a connected satellite client with offline caching capabilities.

### 2.2 Application Identity & Package Target (Decision D3)

- **Target Production Identifier:** In accordance with Decision D3, the official application ID and package namespace for production release is:
  ```text
  com.cnl.aicompanion
  ```
- **Product-Oriented Identity:** The package name is permanently product-oriented, model-independent, and companion-persona-independent.

### 2.3 Device Credential Isolation (Decision D4)

- In accordance with Decision D4, device authentication tokens are strictly separated from Profile-owned personal data.
- The mobile device stores an independently revocable device credential. Master secrets, root database encryption keys, and desktop administration credentials are **never** distributed to the mobile client.

### 2.4 Speech Synthesis Release Boundary

- **Device-Local TTS Status:** Classified in the Feature Promotion Map as `EXPERIMENTAL / NOT STARTED / FUTURE / UNSCHEDULED`.
- Local on-device TTS is **not** an Android V1 requirement and is **not** a committed Android Later milestone scope. Historical exploratory notes ("local STT/TTS where feasible") are non-normative and do not form a delivery gate.

---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Codebase & Prototype Package State

Verified in `android/app/build.gradle.kts`:
- **Prototype Namespace:** The current codebase prototype uses:
  ```kotlin
  namespace = "com.example"
  applicationId = "com.aistudio.localcore.swbjtu"
  minSdk = 24
  targetSdk = 36
  ```
- **Migration Requirement:** Transitioning to `com.cnl.aicompanion` is scheduled for the Android V1 production track.

### 3.2 Implemented Components

Verified in `android/app/src/main/java/com/example/`:
- **Compose UI Foundation:** Jetpack Compose navigation, home view, conversation chat interface, and task list screens.
- **Network Client:** Uses `OkHttp` directly (configured in `LocalAiRuntimeClient`) for communication with the FastAPI backend over LAN or Tailscale.
- **Repository Wiring:** Real HTTP repository wiring exists for `SharedPreferencesConnectionRepository`, `HttpTasksRepository`, and `LocalAiRuntimeClient`. Other major domains—including Assistant conversations, Characters, Memory, Schedule, Alarms, and Models/Devices—remain wired to Fake repositories in `DefaultAppContainer`. General conversation synchronization is not implemented.
- **Credential Storage (Current):** Device pairing token is stored in ordinary, unencrypted `SharedPreferences`.
- **Health Foundation (Current):** The codebase contains the `HealthDataProvider` abstraction, a `MockHealthDataProvider` stub, and Health UI/view-model structures. No real Health Connect client or platform API integration is implemented (mock/provider contract and UI foundation only).
- **Test Baseline:** 124 passing unit, repository, and Robolectric UI tests verified during reconciliation Pass R8.

### 3.3 Explicitly Unimplemented Capabilities

The following target capabilities have zero operational implementation in the current Android prototype:
- **Hardware Keystore Integration:** `NOT IMPLEMENTED` (credentials currently use basic `SharedPreferences`).
- **Durable Room Outbox:** `NOT IMPLEMENTED` (no SQLite/Room local persistence database or offline mutation outbox).
- **General Conversation Synchronization:** `NOT IMPLEMENTED` (conversations use in-memory mock repositories; sync is not implemented).
- **Offline Local LLM Inference:** `NOT IMPLEMENTED` (zero on-device inference runtime).
- **Local Alarms & Push Notifications:** `NOT IMPLEMENTED` (no Android notification channels or exact AlarmManager scheduling).
- **Real Health Connect Integration:** `NOT IMPLEMENTED` (Android V1 capability remains APPROVED / NOT STARTED; current code provides mock contract and UI foundation only).

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Decision D1 and scheduled for Android V1:

1. **Production Identity & Secure Keystore (Android V1):**
   - Migration to `com.cnl.aicompanion`.
   - Device credentials protected via platform-secure facilities backed by the Android Keystore system (e.g., `EncryptedSharedPreferences` as an implementation candidate; exact mechanism remains open design).
2. **Durable Room Outbox & Connected Synchronization (Android V1):**
   - Local Room database caching active tasks, memories, and conversations.
   - Offline mutation queue (outbox) synchronizing with PC Local AI Runtime upon reconnect.
3. **Practical Compact Offline Local LLM (Android V1):**
   - On-device local LLM execution for basic conversational continuity when disconnected from the PC host.
   - Model family, format (e.g., GGUF, ONNX), parameter size, and quantization remain OPEN DESIGN. Existing benchmarks on Dimensity / Infinix hardware are historical proof-of-concept evidence, not locked hardware constraints.
4. **Health Connect Biometric Context (Android V1):**
   - Ingests aggregated biometric summaries from Android Health Connect with explicit user permission, synchronizing approved summaries to the PC Local AI Runtime. (Exact metric list, aggregation formulas, and synchronization cadence remain OPEN DESIGN and belong to `health-and-wearables.md`.)

---

## 5. OPEN DESIGN

The following implementation choices are intentionally left open for subsequent technical design:

- **Secure Credential Storage Mechanism:** Choice of Android Keystore wrapper or library (e.g., `EncryptedSharedPreferences`, Jetpack Security, or custom Keystore provider).
- **Offline LLM Runtime & Format:** Choice of mobile inference engine (e.g., `llama.cpp` Android NDK build, ONNX Runtime Mobile, or MediaPipe), model architecture, and quantization level.
- **Sync Protocol & Conflict Resolution:** Exact transport (WebSocket streaming vs. gRPC vs. HTTPS REST polling) and conflict resolution rules (e.g., last-write-wins with server timestamp authority).
- **Background Synchronization Schedule:** WorkManager constraints, battery optimization exemptions, and Wi-Fi-only sync preferences.
- **Health Connect Metrics & Aggregation:** Initial metric selection, aggregation windows, sync cadence, and privacy filters (governed under `health-and-wearables.md`).

---

## 6. Security & Ownership Boundaries

- **Subordinate Authority:** The mobile client cannot unilaterally override canonical PC state. All sync operations resolve against the PC Local AI Runtime as the single source of truth.
- **Network Boundaries:** Operates over trusted LAN or Tailscale private mesh in accordance with Decision D5. Direct public internet port exposure is outside the supported trust model.
- **Biometric Privacy:** Raw biometric sensor streams are never collected. Only aggregated, user-approved summaries (e.g., total sleep hours) are processed into context.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical Architecture Source:** [`docs/04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md`](../ANDROID_COMPANION_ARCHITECTURE.md) (Retains primary authority until R11.4)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decisions D1, D3, D4)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Android Connected Sync, Android Practical Offline LLM, Android Device-Local TTS, Android Health Connect)
- **Health & Wearables Integration:** Planned R11.3 target `docs/04_Architecture/03_Integrations/health-and-wearables.md`
