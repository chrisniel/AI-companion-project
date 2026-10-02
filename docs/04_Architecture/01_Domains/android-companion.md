# Android Companion Architecture

> **Document Role:** Canonical domain architecture specification.  
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0003, ADR-0018)  
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for the mobile Android companion domain.

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
- **Canonical Authority:** The Windows Host Runtime owns persistent canonical authority over user data, conversation histories, memories, and task state. Android operates as a connected satellite client with offline caching capabilities.
- **Profile Binding (`ADR-0018`):** A normal mobile satellite device binds to a single user Profile (`profile_id`). The PC desktop administrator manages profiles, while the mobile client operates within its bound profile context.

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
- **Test Baseline:** Passing unit, repository, and Robolectric UI test baselines exist in the repository (`android/app/src/test/`).

### 3.3 Explicitly Unimplemented Capabilities

The following target capabilities have zero operational implementation in the current Android prototype:
- **Hardware Keystore Integration:** `NOT IMPLEMENTED` (credentials currently use basic `SharedPreferences`).
- **Durable Room Outbox:** `NOT IMPLEMENTED` (no SQLite/Room local persistence database or offline mutation outbox).
- **General Conversation Synchronization:** `NOT IMPLEMENTED` (conversations use in-memory mock repositories; sync is not implemented).
- **Offline Local LLM Inference:** `NOT IMPLEMENTED` (zero on-device inference runtime).
- **Local Alarms & Push Notifications:** `NOT IMPLEMENTED` (no Android notification channels or exact AlarmManager scheduling).
- **Real Health Connect Integration:** `NOT IMPLEMENTED` (Android V1 capability remains APPROVED / NOT STARTED; current code provides mock contract and UI foundation only).

---

## 4. Future Mobile Architecture (DEFERRED)

Detailed Android V1 production architecture (including offline outbox/sync design, local mobile LLM selection, exact Keystore implementations, Health integration design, and future production topologies) is DEFERRED TO SEPARATE MOBILE ARCHITECTURE PASS.

Do not design or lock these implementation details during the PC V1 phase.

**Preserved Strategic Directives:**
- The current Kotlin implementation serves strictly as prototype/reference evidence.
- The intended production mobile foundation is Flutter.
- The target package identity remains com.cnl.aicompanion.
- Android V1 development does not block PC V1 delivery.
- One satellite device binds to exactly one Profile (ADR-0018).
- Device credentials remain strictly device-local (ADR-0004).

## 6. Security & Ownership Boundaries

---

- **Health Connect Metrics & Aggregation:** Initial metric selection, aggregation windows, sync cadence, and privacy filters (governed under `health-and-wearables.md`).
- **Background Synchronization Schedule:** WorkManager constraints, battery optimization exemptions, and Wi-Fi-only sync preferences.
- **Sync Protocol & Conflict Resolution:** Exact transport (WebSocket streaming vs. gRPC vs. HTTPS REST polling) and conflict resolution rules (e.g., last-write-wins with server timestamp authority).
- **Offline LLM Runtime & Format:** Choice of mobile inference engine (e.g., `llama.cpp` Android NDK build or MediaPipe), model architecture, and quantization level.
- **Secure Credential Storage Mechanism:** Choice of Android Keystore wrapper or library (e.g., `EncryptedSharedPreferences`, Jetpack Security, or custom Keystore provider).

The following implementation choices are intentionally left open for subsequent technical design:

## 5. OPEN DESIGN

---

   - Ingests aggregated biometric summaries from Android Health Connect with explicit user permission, synchronizing approved summaries to the PC Windows Host Runtime.
4. **Health Connect Biometric Context (Android V1):**
   - Model family, format (e.g., GGUF), parameter size, and quantization remain OPEN DESIGN. Existing benchmarks on Dimensity / Infinix hardware are historical proof-of-concept evidence, not locked hardware constraints.
   - On-device local LLM execution for basic conversational continuity when disconnected from the PC host.
3. **Practical Compact Offline Local LLM (Android V1):**
   - Offline mutation queue (outbox) synchronizing with PC Windows Host Runtime upon reconnect.
   - Local Room database caching active tasks, memories, and conversations.
2. **Durable Room Outbox & Connected Synchronization (Android V1):**
   - Device credentials protected via platform-secure facilities backed by the Android Keystore system (e.g., `EncryptedSharedPreferences` as an implementation candidate; exact mechanism remains open design).
   - Migration to `com.cnl.aicompanion`.
1. **Production Identity & Secure Keystore (Android V1):**

The following target capabilities are approved under Decision D1 and scheduled for Android V1:

## 4. Approved Target Architecture / Not Yet Implemented

---

- **Real Health Connect Integration:** `NOT IMPLEMENTED` (Android V1 capability remains APPROVED / NOT STARTED; current code provides mock contract and UI foundation only).
- **Local Alarms & Push Notifications:** `NOT IMPLEMENTED` (no Android notification channels or exact AlarmManager scheduling).
- **Offline Local LLM Inference:** `NOT IMPLEMENTED` (zero on-device inference runtime).
- **General Conversation Synchronization:** `NOT IMPLEMENTED` (conversations use in-memory mock repositories; sync is not implemented).
- **Durable Room Outbox:** `NOT IMPLEMENTED` (no SQLite/Room local persistence database or offline mutation outbox).
- **Hardware Keystore Integration:** `NOT IMPLEMENTED` (credentials currently use basic `SharedPreferences`).
The following target capabilities have zero operational implementation in the current Android prototype:

### 3.3 Explicitly Unimplemented Capabilities

- **Test Baseline:** Passing unit, repository, and Robolectric UI test baselines exist in the repository (`android/app/src/test/`).
- **Health Foundation (Current):** The codebase contains the `HealthDataProvider` abstraction, a `MockHealthDataProvider` stub, and Health UI/view-model structures. No real Health Connect client or platform API integration is implemented (mock/provider contract and UI foundation only).
- **Credential Storage (Current):** Device pairing token is stored in ordinary, unencrypted `SharedPreferences`.
- **Repository Wiring:** Real HTTP repository wiring exists for `SharedPreferencesConnectionRepository`, `HttpTasksRepository`, and `LocalAiRuntimeClient`. Other major domains—including Assistant conversations, Characters, Memory, Schedule, Alarms, and Models/Devices—remain wired to Fake repositories in `DefaultAppContainer`. General conversation synchronization is not implemented.
- **Network Client:** Uses `OkHttp` directly (configured in `LocalAiRuntimeClient`) for communication with the FastAPI backend over LAN or Tailscale.
- **Compose UI Foundation:** Jetpack Compose navigation, home view, conversation chat interface, and task list screens.
Verified in `android/app/src/main/java/com/example/`:

### 3.2 Implemented Components

- **Migration Requirement:** Transitioning to `com.cnl.aicompanion` is scheduled for the Android V1 production track.
  ```
  targetSdk = 36
  minSdk = 24
  applicationId = "com.aistudio.localcore.swbjtu"
  namespace = "com.example"
  ```kotlin
- **Prototype Namespace:** The current codebase prototype uses:
Verified in `android/app/build.gradle.kts`:

### 3.1 Codebase & Prototype Package State

Repository source code and test suites verify the following baseline reality:

## 3. Current Verified Implementation

---

- Local on-device TTS is **not** an Android V1 requirement and is **not** a committed Android Later milestone scope. Historical exploratory notes ("local STT/TTS where feasible") are non-normative and do not form a delivery gate.
- **Device-Local TTS Status:** Classified in the Feature Promotion Map as `EXPERIMENTAL / NOT STARTED / FUTURE / UNSCHEDULED`.

### 2.4 Speech Synthesis Release Boundary

- The mobile device stores an independently revocable device credential. Master secrets, root database encryption keys, and desktop administration credentials are **never** distributed to the mobile client.
- In accordance with Decision D4, device authentication tokens are strictly separated from Profile-owned personal data.

### 2.3 Device Credential Isolation (Decision D4)

- **Product-Oriented Identity:** The package name is permanently product-oriented, model-independent, and companion-persona-independent.
  ```
  com.cnl.aicompanion
  ```text
- **Target Production Identifier:** In accordance with Decision D3, the official application ID and package namespace for production release is:

### 2.2 Application Identity & Package Target (Decision D3)

- **Profile Binding (`ADR-0018`):** A normal mobile satellite device binds to a single user Profile (`profile_id`). The PC desktop administrator manages profiles, while the mobile client operates within its bound profile context.
- **Canonical Authority:** The Windows Host Runtime owns persistent canonical authority over user data, conversation histories, memories, and task state. Android operates as a connected satellite client with offline caching capabilities.
- **Non-Blocking Invariant:** Development, verification, or staging of the Android Companion does **not** block the delivery, feature freeze, or release of the PC V1 ecosystem milestone.
- **Independent Follow-on Release:** Android V1 is an independent, follow-on production mobile release.
In accordance with Decision D1:

### 2.1 Release Phasing & Non-Blocking Invariant

## 2. Durable Architecture & Invariants

---

It governs the boundary between the desktop host runtime and the satellite mobile companion.

- Phased delivery boundaries distinguishing PC V1 from Android V1.
- Android Health Connect integration for biometric companion context.
- Compact offline local LLM execution boundaries.
- Trusted device credentials and secure hardware storage.
- Client synchronization model with the PC Local AI Runtime as the canonical authority.
- Identity, package namespaces, and application boundaries.
This specification defines the mobile architecture, synchronization protocol, security boundaries, and offline capabilities for the Android Companion client:

## 1. Purpose & Scope

---

> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for the mobile Android companion domain.
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0003, ADR-0018)  
> **Document Role:** Canonical domain architecture specification.  

# Android Companion Architecture
- **Health & Wearables Integration:** [`docs/04_Architecture/03_Integrations/health-and-wearables.md`](../03_Integrations/health-and-wearables.md)
