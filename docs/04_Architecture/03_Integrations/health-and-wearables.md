# Health and Wearables Integration Architecture

> **Document Role:** Canonical domain architecture specification.  
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0018)  
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for health, wellness, and wearable biometric integrations.

---

> **Mobile Architecture Disposition:** Detailed health integration is formally classified as **Mobile Later (Deferred Post-V1)** in the Mobile Architecture Pass (Batch C). The Kotlin health prototype and mock providers remain preserved strictly as non-production reference evidence.

## 1. Purpose & Scope

This specification documents the candidate integration architecture, data contracts, and privacy boundaries for future health, wellness, and wearable biometric context:
- Preservation of current Kotlin mock/prototype evidence.
- Establishment of health/privacy/non-clinical guardrails as candidate future principles.
- Explicit deferral to a separate Mobile Architecture Pass.

---

## 2. Durable Architecture & Invariants

### 2.1 Formal Release Disposition: Mobile Later (Deferred Post-V1)

- **Release Boundary:** Health, wellness, and wearable biometric integrations are formally classified as **`Mobile Later` (Deferred Post-V1)** under Mobile Architecture Batch C (see [`04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md)).
- **Mobile V1 Exclusion:** Real Health Connect integration (`androidx.health.connect`), health manifest permissions, and biometric synchronization are **strictly excluded** from the Mobile V1 release scope.
- **Prototype Sequestration:** The existing Android Kotlin UI screens (`HealthScreen.kt`) and `MockHealthDataProvider` represent non-production exploratory mock/reference code only. They must remain sequestered or disabled behind developer flags in production release builds.

### 2.2 Candidate Privacy & Non-Clinical Invariants

If health integration is pursued in the future, it must follow these candidate principles:
- **Informational Companion Context Only:** Health metrics serve solely to provide empathetic, contextual awareness for the companion. The companion makes **no clinical, medical, or diagnostic claims**.
- **Explicit User Authorization:** Ingestion of biometric data requires active, informed user consent. Users may selectively grant or revoke access to individual metric categories at any time.
- **Data Minimization:** Health-context processing follows data minimization: the companion should request, process, and retain no more health data or granularity than required for the approved companion capability and user authorization. Raw or high-frequency health data must not be silently persisted or used without a separately approved need and explicit user authorization.

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
- **PC Backend Health Ingress:** **NOT IMPLEMENTED**. The FastAPI backend currently has no health-specific database models, endpoints, or context injectors.

---

## 4. Approved Target Architecture / Not Yet Implemented
 
Health and wearable integration is formally scheduled as **Mobile Later (Deferred Post-V1)**. There are no approved health integration targets for PC V1 or Mobile V1. 

---

## 5. OPEN DESIGN

All functional and technical mechanisms for real health integration remain open design for future post-V1 mobile phases, including:

- **Persistence & Injection Mechanisms:** Storage schema and prompt-injection hooks on the PC host.
- **Provider & Aggregation Design:** Exact provider class names, metric sets, aggregation cadences, and sync protocol details.
- **Permission & Revocation UX:** User interface controls for granular metric toggling, data inspection, and biometric history purging.

---

## 6. Security & Ownership Boundaries

- **Application Trust Boundary:** If health context is synchronized to PC in the future, it must remain Profile-owned (`profile_id`) local data protected by the application trust boundary.
- **Cloud Fallback Privacy Rule:** When optional Cloud LLM fallback is used, health data must not be included in cloud egress without explicit user authorization and applicable privacy policy.
- **Informational / Non-Clinical Use:** Health metrics serve solely to provide empathetic, contextual awareness for the companion without making medical or diagnostic claims.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Release Vocabulary, §3 Cross-Cutting Invariants)
- **Mobile System Baseline:** [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md)
- **Mobile Capabilities & Runtime Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../../02_Planning/00_Master/SPRINT_ROADMAP.md) (Milestone Track M-Android)
- **Android Companion Domain Spec:** [`docs/04_Architecture/01_Domains/android-companion.md`](../01_Domains/android-companion.md)
- **Privacy & Audit Specification:** [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../02_Data_and_Security/privacy-retention-and-audit.md)
