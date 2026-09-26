# Health and Wearables Integration Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.3).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** Focused staged specification authored during R11.3. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md`](../ANDROID_COMPANION_ARCHITECTURE.md) (§3) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, PC Health Context Readiness, Android Health Connect) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the integration architecture, data contracts, and privacy boundaries for health, wellness, and wearable biometric context:
- Phased delivery distinguishing PC V1 schema readiness from Android V1 physical integration.
- Android V1 platform integration with Android Health Connect.
- Decoupling from proprietary wearable vendors and upstream companion apps.
- Informational, non-clinical companion context boundaries.
- User consent, data minimization, and privacy invariants.

---

## 2. Durable Architecture & Invariants

### 2.1 Phased Delivery Boundaries (PC V1 vs. Android V1)

In accordance with the Feature Promotion Map:
- **PC V1: Health-Context Ready Architecture:** Classified as `APPROVED / NOT STARTED / PC V1`. PC V1 establishes conceptual data schemas, companion context injection rules, and readiness for receiving summarized wellness data. **PC V1 does NOT directly connect to physical wearables or Bluetooth biometric sensors.**
- **Android V1: Android Health Connect Integration:** Classified as `APPROVED / NOT STARTED / ANDROID V1`. Physical collection of biometric context occurs via the Android Companion device leveraging Android's platform-standard Health Connect API.

### 2.2 Vendor Decoupling & Health Connect as Standard

- **No Proprietary Vendor Lock-In:** The companion architecture explicitly avoids direct SDK or Bluetooth integration with proprietary wearable manufacturers (e.g., FitCloudPro, Garmin, Fitbit, Xiaomi). Upstream manufacturer apps write to the operating system's health store.
- **Health Connect as Single Mobile Ingress:** Android V1 integrates exclusively with the native Android Health Connect platform. The companion reads summarized data from Health Connect subject to explicit Android OS permissions, remaining completely independent of specific wearable hardware models or vendor apps.

### 2.3 Non-Clinical & Privacy Invariants

- **Informational Companion Context Only:** Health metrics serve solely to provide empathetic, contextual awareness for the companion (e.g., recognizing that the user had poor sleep, high activity, or an elevated heart rate to adjust conversational tone or suggest breaks). The companion makes **no clinical, medical, or diagnostic claims**.
- **Explicit User Authorization:** Ingestion of biometric data requires active, informed user consent. Users may selectively grant or revoke access to individual metric categories at any time.
- **Data Minimization:** Only coarse-grained, aggregated summaries (e.g., daily resting heart rate, sleep duration and stages, total steps) are ingested into conversational prompt context. High-frequency raw sensor streams (e.g., continuous per-second photoplethysmography rasters) are never requested or retained.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Android Provider Interface & UI Foundation

Verified in `android/app/src/main/java/com/example/`:
- **Interface Contract (`HealthDataProvider`):** Located at `data/health/HealthDataProvider.kt`, defines an abstract contract for querying health metrics (`getDailySummary()`, `getSourceStatus()`).
- **Mock Implementation (`MockHealthDataProvider`):** Located at `data/health/MockHealthDataProvider.kt`, supplies synthetic biometric values across selectable availability profiles (`STANDARD_DEFAULT`, `ALL_AVAILABLE`, `STALE_SYNC`, `UNSUPPORTED_SENSOR`, `NOT_SYNCHRONIZED`).
- **Health UI & ViewModel:** `ui/screens/health/HealthScreen.kt` and `HealthViewModel.kt` render biometric dashboards (heart rate, sleep, steps, SpO2) driven by the provider interface.
- **Testing Coverage:** Unit tests in `AccessibilityAndDeviceAuditTest.kt` and `HealthAndWellnessUnitTest.kt` verify UI rendering and profile switching against the mock provider.

### 3.2 Implemented Reality Boundaries

- **Mock Reality:** Current Android health screens run exclusively against **synthetic mock data**. The repository contains **zero real biometric data capture**.
- **Platform Health Connect Status:** **NOT IMPLEMENTED**. The Android codebase contains no Health Connect Client SDK integration (`androidx.health.connect`), no Health Connect permission requests, and no manifest permission declarations for health records.
- **PC Backend Health Ingress:** **NOT IMPLEMENTED**. The FastAPI backend currently has no health-specific database models, endpoints, or context injectors.

---

## 4. Approved Target Architecture / Not Yet Implemented

When implemented across target milestones:

1. **PC V1 Backend Readiness:**
   - Formalized Pydantic schemas and database models for storing ingested daily health summaries associated with a Profile.
   - Assistant context assembly hook injecting coarse health summaries (e.g., sleep score, activity level) into the prompt context when relevant.
2. **Android V1 Production Integration:**
   - Real `HealthConnectDataProvider` implementing `HealthDataProvider` using Android's official Health Connect Client API.
   - Declarative permission requests for reading sleep sessions, heart rate records, and step counts.
   - Sync service transferring aggregated daily health summaries from Android to the PC Local AI Runtime during connected synchronization sessions.

---

## 5. OPEN DESIGN

The following functional and technical mechanisms remain open design for future implementation plans:

- **Metric Set & Granularity:** Final list of supported metric types (e.g., resting heart rate, sleep duration/stages, step counts, active energy burned, SpO2) and aggregation intervals (hourly averages vs. daily rollups).
- **Sync Cadence & Thresholds:** Frequency and trigger mechanisms for syncing mobile health data to the PC host (e.g., once daily on morning companion wake, on-demand during companion check-ins, or scheduled background sync).
- **Health-Memory Interaction:** Policy governing whether notable health events (e.g., "recovered from a cold", "completed a marathon") are selectively converted into persistent memory notes.
- **Permission & Revocation UX:** User interface controls on both Android and PC for granular metric toggling, data inspection, and instant biometric history purging.
- **Upstream Source Mapping:** UI heuristics for informing the user if their proprietary wearable app is properly syncing into Health Connect.

---

## 6. Security & Ownership Boundaries

- **Local Host Authority:** Health data synchronized to the PC is owned strictly by the authenticated Profile (`owner_id`) and stored in the local encrypted/protected database. It is never transmitted to external cloud services or LLMs without explicit configuration.
- **Egress Minimization:** When conversational turns invoke cloud LLM fallbacks (if enabled), health context should be excluded or strictly sanitized to prevent medical data egress.
- **No Diagnostic Liability:** Companion responses mentioning health must maintain a supportive, non-authoritative persona and encourage professional medical advice for symptoms.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline capabilities, PC Health Context Readiness (PC V1), Android Health Connect (Android V1).
- [`docs/04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md`](../ANDROID_COMPANION_ARCHITECTURE.md) — Mobile architecture, connected sync protocol.

### Related Domain & Integration Specifications
- [`docs/04_Architecture/01_Domains/android-companion.md`](../01_Domains/android-companion.md) — Mobile companion sync loop and sensor boundaries.
- [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md) — Context assembly and companion tone modulation.
- [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../02_Data_and_Security/privacy-retention-and-audit.md) — Biometric data retention and user deletion controls.
