# Health and Wearables Integration Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0018)
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for health, wellness, and wearable biometric integrations.

---

> **Mobile Architecture Disposition:** Health Connect integration is classified as **Conditional Mobile V1** (`D-PHONE-15`), intentionally superseding the prior Batch C `Mobile Later (Deferred Post-V1)` deferral. Real Health Connect ingestion is supported on qualified Android devices where the platform API is available and user consent is granted. A device, platform, or user configuration without usable Health Connect remains a fully valid Mobile V1 installation. The existing Android Kotlin health prototype and mock providers remain preserved strictly as non-production reference evidence.

## 1. Purpose & Scope

This specification documents the canonical integration architecture, data contracts, and privacy boundaries for health, wellness, and wearable biometric context:
- Reconcile Mobile V1 Health Connect disposition (`D-PHONE-15`).
- Define granular metric authorization, read-only ingestion, and Health Connect aggregation boundary (`D-PHONE-15A`, `D-PHONE-15B`, `D-PHONE-15E`).
- Establish strict separation between Health Context and D7 Memory (`D-PHONE-15C`).
- Specify shared normalized PC/Mobile health context and provenance (`D-PHONE-15D`, `D-SHARED-HEALTH-01`).
- Enforce non-clinical wellness boundaries and health-aware check-in behavior (`D-SHARED-HEALTH-02`, `D-SHARED-HEALTH-03`).
- Enforce strict health egress isolation across network boundaries (`D-SHARED-HEALTH-04`).
- Preserve current implementation truth and non-production reference evidence.

---

## 2. Durable Architecture & Invariants

### 2.1 Formal Release Disposition: Conditional Mobile V1 (`D-PHONE-15`)

- **Conditional Scope:** Health Connect integration (`androidx.health.connect`) is classified as **Conditional Mobile V1** (`D-PHONE-15`). It is an optional, read-only, consent-driven capability for qualified Android environments.
- **Graceful Absence:** A mobile device, Android version, or user setup lacking Health Connect support or user consent is fully supported and remains a valid Mobile V1 companion device. Health features degrade gracefully to unavailable without impeding core companion functionality.
- **Aggregation Boundary (`D-PHONE-15E`):** Android Health Connect serves as the canonical V1 mobile aggregation boundary for wearable and biometric sources. Direct vendor-specific wearable SDK integrations (e.g., proprietary watch protocols) are not required in Mobile V1 unless an essential source is inaccessible via Health Connect.

### 2.2 Ingestion & Authority Boundaries (`D-PHONE-15A`, `D-PHONE-15B`)

- **Granular Metric Authorization (`D-PHONE-15A`):** Permissions are strictly partitioned by metric type. Users grant or revoke consent independently across candidate categories:
  - Active calories / energy expenditure
  - Blood pressure
  - Body temperature
  - Distance
  - Heart rate / resting heart rate
  - Oxygen saturation / SpO₂
  - Sleep stages and duration
  - Steps and daily physical activity
- **Truthful Ingestion:** The companion claims and surfaces only metrics that the underlying source actually measures and supplies. It must never fabricate, extrapolate, or estimate missing biometric readings.
- **Read-Only Ingestion Boundary (`D-PHONE-15B`):** Mobile V1 health integration is strictly read-only. The Companion ingests approved records from Health Connect into its local context but does not write, modify, or insert health records into Health Connect in Mobile V1.

### 2.3 Health Context vs Memory Decoupling (`D-PHONE-15C`)

- **Strict Domain Boundary:** Sensor readings, biometric metrics, trends, and time-window summaries belong exclusively to the **Health Context domain**. Biometric data is **not** canonical D7 Memory.
- **No Autonomous Memory Creation:** Routine health readings, daily steps, sleep statistics, and heart rates must never be automatically promoted into long-term canonical Memory records.
- **Explicit User Preferences Distinct:** Explicit user statements regarding health (e.g., *"Remember that I am training for a marathon"* or *"Keep in mind I try to sleep before 11 PM"*) are processed through standard D7 explicit Memory flows and may become canonical Profile Memory.

### 2.4 Shared Normalized Health Context & Provenance (`D-PHONE-15D`, `D-SHARED-HEALTH-01`)

- **Normalized Schema Contract:** PC Host and Mobile runtime consume a unified, normalized health contract. Mobile acts as the primary Health Connect ingestion point.
- **Durable Provenance:** All normalized health context records must preserve:
  - Metric type and unit
  - Measurement timestamp and observation interval
  - Ingestion timestamp (`last_updated`)
  - Freshness status (stale threshold evaluation)
  - Source provenance (e.g., specific Health Connect source app/device)
- **Host Sync:** When connected, bounded useful normalized health context may synchronize to the PC Host to enrich companion interactions across client surfaces. Arbitrary unlimited high-frequency raw telemetry is not synchronized by default. Exact aggregation/raw-window policy, sync cadence, retention, and protected transport binding remain implementation-open within approved shared transport and security architecture.

### 2.5 Non-Clinical Wellness Guardrails (`D-SHARED-HEALTH-02`, `D-SHARED-HEALTH-03`)

- **Non-Clinical Boundary (`D-SHARED-HEALTH-02`):** The Companion is strictly an informational and lifestyle wellness companion:
  - It provides empathetic, context-aware conversational support, general wellness suggestions, sleep schedule awareness, and gentle encouragement.
  - It **must never** diagnose medical conditions, prescribe medication, recommend medical treatments, claim clinical certainty, or present itself as an emergency response system.
- **Enriched Check-Ins (`D-SHARED-HEALTH-03`):** Authorized health context may inform scheduled Routines, proactive check-ins, home widgets, and conversation greetings (e.g., acknowledging low sleep when greeting the user).
- **Separation of Fact and Presentation:** The underlying biometric fact (e.g., sleep duration: 5.5 hours) remains deterministic and verifiable. Character personality and mood modulate only the conversational framing and empathetic tone, never the underlying health data.

### 2.6 Health Egress Isolation (`D-SHARED-HEALTH-04`)

- **Permission Orthogonality:** Network and AI permissions are strictly decoupled:
  $$\text{Public Internet} \neq \text{Cloud LLM} \neq \text{Cloud STT/TTS} \neq \text{Health-to-Cloud}$$
- **Strict Isolation:** Permitting Cloud LLM or Cloud Voice inference does **not** authorize transmitting health data off-device. Including health context in cloud LLM prompts requires separate, explicit, user-confirmed authorization.
- **Local-First Default:** By default, health-aware reasoning and summarization execute on local models (PC Host or qualified Mobile local model).

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Android Provider Interface & UI Foundation

Verified in `android/app/src/main/java/com/example/`:
- **Interface Contract (`HealthDataProvider`):** Located at `data/health/HealthDataProvider.kt`, defines an abstract contract with exact properties and methods.
- **Mock Implementation (`MockHealthDataProvider`):** Located at `data/health/MockHealthDataProvider.kt`, supplies synthetic biometric values across selectable availability profiles.
- **Health UI & ViewModel:** `ui/screens/health/HealthScreen.kt` and `HealthViewModel.kt` render biometric dashboards (heart rate, sleep, steps, SpO2) driven by the provider interface.
- **Testing Coverage:** Unit tests in `AccessibilityAndDeviceAuditTest.kt` and `HealthAndWellnessUnitTest.kt` verify UI rendering and profile switching against the mock provider.

### 3.2 Implemented Reality Boundaries

- **Mock Reality:** Current Android health screens run exclusively against **synthetic mock data**. The repository contains **zero real biometric data capture**.
- **Platform Health Connect Status:** **NOT IMPLEMENTED**. The Android codebase contains no Health Connect Client SDK integration (`androidx.health.connect`), no Health Connect permission requests, and no manifest permission declarations for health records.
- **Flutter Mobile Status:** **NOT IMPLEMENTED**. No Flutter mobile health integration exists in the repository.
- **PC Backend Health Ingress:** **NOT IMPLEMENTED**. The FastAPI backend currently has no health-specific database models, endpoints, or context injectors.

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved in Mobile V1 architecture but are not yet implemented in source code:
- **Mobile V1 Health Connect Ingestion (`D-PHONE-15`, `D-PHONE-15A`, `D-PHONE-15B`):** Android Health Connect client adapter, permission flow, and read-only record polling.
- **Health Context Store & Normalizer (`D-SHARED-HEALTH-01`):** In-memory and local SQLite persistence for bounded normalized metric records.
- **Host Sync Pipeline (`D-PHONE-15D`):** Protected transfer of bounded useful normalized health context between Mobile and PC Host (exact transport binding implementation-open).
- **Health-Aware Prompt Injector (`D-SHARED-HEALTH-03`):** Bounded context injector supplying recent wellness summaries to local conversation and routine assembly.
- **Health Cloud Egress Guard (`D-SHARED-HEALTH-04`):** Policy filter enforcing strict stripping of health data from prompts destined for cloud LLM providers unless explicitly authorized.

---

## 5. Open Design & Implementation Notes

The following technical details remain open design for future implementation milestones:
- **Aggregation & Raw-Window Policy:** Exact sliding windows, aggregation functions, raw observation retention windows, and background sync polling frequencies.
- **Database Schema & Retention:** Specific table schemas for local SQLite storage of health events, normalized context, and retention/pruning thresholds.
- **Transport Binding:** Concrete protocol binding (e.g. secure REST or WebSocket frames) within approved shared transport and encryption architecture.
- **UI Management Controls:** Detailed settings screens for granular metric toggle switches and data retention periods.

---

## 6. Security & Ownership Boundaries

- **Application Trust Boundary:** Health context is Profile-owned (`profile_id`) sensitive data protected by the OS private application sandbox as the baseline. Full database encryption (e.g. SQLCipher) remains an optional, threat-model-dependent mitigation.
- **Cloud Egress Guard:** Health data is never transmitted to cloud endpoints without explicit, standalone user authorization (`D-SHARED-HEALTH-04`).
- **Purge Rights Boundary:** Users retain absolute authority to inspect, export, or permanently erase all Companion-retained and synchronized health data copies. The Companion does not claim automatic deletion authority over external source records residing in Android Health Connect unless created by the Companion and explicitly authorized by future architecture.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Release Vocabulary, §3 Cross-Cutting Invariants)
- **Mobile System Baseline:** [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md)
- **Mobile Capabilities & Runtime Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md)
- **Mobile Offline & Sync Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`](../04_Infrastructure/mobile-offline-and-sync.md)
- **Memory & Personalization Spec:** [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](../01_Domains/memory-and-personalization.md)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **Privacy & Audit Specification:** [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../02_Data_and_Security/privacy-retention-and-audit.md)
