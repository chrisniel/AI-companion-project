# Android Companion Architecture (Prototype & V1 Boundary)

> **Document Role:** Canonical domain architecture specification.  
> **Status:** Active Canonical (Prototype & Reference Boundary)  
> **Canonical Ownership:** Mobile Companion production architecture is canonically established in [`MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md), [`mobile-offline-and-sync.md`](../04_Infrastructure/mobile-offline-and-sync.md), and [`mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md) following approved Mobile Architecture Batches A, B, and C. This document governs the boundary and preserved role of the exploratory Kotlin/Compose prototype (`android/`).

## 1. Prototype & Reference State

The current Android repository (`android/`) contains a mobile companion prototype built in Kotlin and Jetpack Compose. This prototype serves strictly as reference implementation evidence for networking and basic interaction, rather than the final frozen production architecture.

### 1.1 Verified Current Evidence
- **Kotlin/Compose Prototype:** Real Compose UI exists for navigation, chat, and basic task lists (`android/app/src/main/java/com/example/`).
- **Package Identity:** The current prototype utilizes an interim package namespace (`com.example` / `com.aistudio.localcore.swbjtu`).
- **Network/Repository State:** Direct `OkHttp` networking is implemented to communicate with the PC FastAPI backend (`LocalAiRuntimeClient`). Some repositories use fake implementations, and device credentials use basic unencrypted `SharedPreferences`.

## 2. Frozen Cross-Platform Decisions

The following fundamental integration bounds are firmly decided under the PC V1 architecture:

- **Target Application Identity:** The final production mobile package namespace is frozen as `com.cnl.aicompanion` (Decision D3 / `ADR-0004`).
- **Development Parallelism:** Android development does **not** block the PC V1 milestone (Decision D1).
- **Profile Binding:** A single satellite device binds to **exactly one Profile** (`ADR-0018`).
- **Device Credential Isolation:** Provider and device credentials remain completely device-local and are never leaked to or synchronized with the host (`ADR-0005`).
- **Production Mobile Foundation:** Flutter is the intended cross-platform production mobile foundation for the future release.

## 3. Explicit Architecture Boundary

> [!NOTE]  
> **PRODUCTION MOBILE ARCHITECTURE CANONICALIZATION COMPLETED**  
> Detailed Mobile Companion architecture has been established across canonical infrastructure specifications:
> - **Offline Persistence & Sync:** Transactional outbox, revision checks, and per-domain replication are governed by [`mobile-offline-and-sync.md`](../04_Infrastructure/mobile-offline-and-sync.md).
> - **Inference, Voice & Hardware Tiers:** Evidence-based runtime qualification, local TTS/STT decoupling, Voice streaming, and platform security are governed by [`mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md).
> - **System Ecosystem:** Satellite authority, Flutter boundaries, and identity are governed by [`MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md).

The following boundaries govern the legacy prototype:
- The Kotlin/Compose tree (`android/`) remains non-production prototype/reference and migration evidence.
- Real Health Connect integration and biometric sync are classified as **Mobile Later (Post-V1)**; prototype mock health UI is sequestered.
- Production Mobile development will execute under the shared Flutter workspace topology (`ADR-0004`).
