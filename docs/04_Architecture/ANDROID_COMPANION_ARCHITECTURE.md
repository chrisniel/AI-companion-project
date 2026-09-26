# AI Companion — Android Companion Architecture Specification

> **Document Role:** Legacy Android technical and benchmark reference (non-normative after R11.4).
> **Status:** Subordinate Reference — primary normative authority transferred to `01_Domains/android-companion.md` and `03_Integrations/health-and-wearables.md`.
> **Authority Precedence:** Non-normative reference material. See [`SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md) and focused domain specifications for canonical requirements.

---

## 1. Executive Summary & Release Boundary

The **Android Companion** is the mobile client for the AI Companion ecosystem.

> [!WARNING]
> **Authority Transfer & Legacy Status Notice (Pass R11.4):**
> This document is no longer the primary normative architecture specification for the Android Companion or mobile integrations. Primary normative authority has transferred to:
> - [`docs/04_Architecture/01_Domains/android-companion.md`](01_Domains/android-companion.md) (Decisions D1, D3, D4: Mobile Architecture & Sync)
> - [`docs/04_Architecture/03_Integrations/health-and-wearables.md`](03_Integrations/health-and-wearables.md) (Health Connect & Wearables Integration)
>
> **Release Boundary Notice (Supersession):** Current Android release boundary is governed exclusively by [`docs/04_Architecture/SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md) and [`docs/04_Architecture/01_Domains/android-companion.md`](01_Domains/android-companion.md). **Android V1 is an independent follow-on production release that does not block PC V1.** Android V1 includes connected sync, secure device credentials (Keystore), Room/outbox, practical compact offline LLM, Health Connect, scheduling, persona continuity, and bidirectional reconciliation. Exact offline model, format, and quantization remain **Open Design**. Device-local TTS remains **Experimental / Future Unscheduled** (neither Android V1 nor committed Android Later). Historical benchmark data in this document represents point-in-time exploratory evidence only.
>
> Implemented reality remains authoritative in source code and test suites. The retained content below serves as legacy Android technical and benchmark reference.

---

## 2. Product Identity & Application Namespace (Decision D3)

- **Application Name:** Android Companion
- **Package / Namespace:** `com.cnl.aicompanion`
- **Application ID:** `com.cnl.aicompanion`
- **Design Philosophy:**
  - Product-oriented and ecosystem-aligned.
  - Completely character-independent and model-independent.
  - The Android app represents the client endpoint, never a specific character persona or LLM provider.

---

## 3. Operational Modes: Connected vs. Offline

The Android Companion architecture defines two primary operational states:

```text
┌────────────────────────────────────────────────────────┐
│                   Connected Mode                       │
│  (Connected via Local LAN or Tailscale Private Mesh)   │
│                                                        │
│  Android Client ──────── Authenticated API ──────────► │
│  (Thin Client)                                         │
│                                                        │
│  • Primary inference runs on PC Local AI Runtime       │
│  • Canonical storage in PC SQLite database             │
│  • Full model capabilities (2B / 4B / 8B / Vision)     │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│                    Offline Mode                        │
│               (Roaming / Disconnected)                 │
│                                                        │
│  Android Client (Self-Contained)                       │
│                                                        │
│  • Local mobile inference (~0.5B–1B quantized GGUF)    │
│  • Local cached memory and task state                  │
│  • Device-local STT / TTS fallback                     │
│                                                        │
│  Reconnection ──────── Sync & Reconcile ─────────────► │
│  (PC Local AI Runtime remains canonical authority)     │
└────────────────────────────────────────────────────────┘
```

### 3.1 Connected Mode
- When within reach of the primary host (via home LAN or Tailscale private mesh network):
  - The PC **Local AI Runtime** is the single source of truth for conversation state, memory persistence, task lifecycle, and model execution.
  - The Android client operates as an authenticated remote interface displaying SSE streaming responses and syncing state in real time.
  - The full compute capacity of the PC host (e.g., AMD RX 580 VRAM offload, larger multimodal models) is available.

### 3.2 Offline Mode (Future Architecture)
- When roaming without connectivity to the PC host:
  - The Android client may switch to a local on-device inference engine running an ultra-compact quantized model.
  - Local cached memories and tasks remain viewable and editable in device-local storage.
  - Device-local speech synthesis (e.g., KittenTTS or Android System TTS) provides basic voice interaction.

### 3.3 Reconnection & Synchronization Requirements
- When the mobile client re-establishes connectivity with the PC Local AI Runtime:
  - Device-local creations, edits, and conversations synchronize back to the PC host.
  - The PC Local AI Runtime remains the **permanent canonical authority**; any conflicting revisions are reconciled against the host database.

---

## 4. Reference Mobile Inference Evidence Baseline

To ground future mobile local-inference planning in physical evidence rather than theoretical assumptions, local benchmarks were conducted on a physical reference Android device:

### 4.1 Reference Hardware Profile
- **Device Model:** Infinix ZERO ULTRA (X6820)
- **SoC:** MediaTek Dimensity 920 (6nm, 2× Cortex-A78 @ 2.5 GHz, 6× Cortex-A55 @ 2.0 GHz)
- **RAM:** 8 GB physical LPDDR4X RAM
- **OS:** Android 13 (XOS)
- **Execution Engine:** `llama.cpp`-class mobile runtime (PocketPal Android integration)

### 4.2 Observed Generation Speeds

| Model Candidate | Parameter Size | Quantization | Observed Token Speed | Benchmark Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Gemma 3** | 270M (~0.27B) | Q8 | **~25.56 tok/s** | Throughput tested; chat/instruction quality NOT meaningfully tested. |
| **Qwen3.5** | ~0.8B | Q4_K_M | **~14.81 tok/s** | Throughput tested; no formal quality benchmark recorded. |
| **Llama 3.2** | ~1.24B | Q4_K_M | **~12.37 tok/s** | Throughput tested; user observed phone UI/framerate degradation during execution. |
| **Qwen3** | ~0.6B | Q8 | **~11.75 tok/s** | Throughput tested; no formal quality benchmark recorded. |

### 4.3 Engineering Interpretation & Invariants
1. **Physical Envelope Evidence:** The tested envelope from approximately 0.27B through 1.24B produced roughly 11.75–25.56 tok/s on this reference device. Within the approximately 0.6B–1.24B tested models, observed generation was roughly 11.75–14.81 tok/s.
2. **Reference Hardware Context Only:** These numbers represent physical evidence on a specific MediaTek Dimensity 920 reference device. They do not establish minimum supported hardware, nor are they guaranteed performance across other Android devices.
3. **No Premature Model Lock:** The project has **not** permanently selected a single mobile model. Model selection remains open until dedicated post-V1 mobile offline planning.
4. **Multimodal Status:** Qwen3.5 ~0.8B remains a candidate worth evaluating for future mobile multimodal use, but the exact model packaging, matching projector/`mmproj` artifacts, mobile runtime support, and Android vision path must be independently verified. Mobile VL capability is not an established fact.

---

## 5. Current Implementation Reality

The active repository contains a well-tested mobile UI and connectivity prototype in `android/`:

| Subsystem | Implemented & Verified Reality (Prototype) | Known Non-Implemented Boundary (Post-V1) |
| :--- | :--- | :--- |
| **Mobile UI** | 17 Jetpack Compose screens, SoftGlass Neumorphic design engine, OLED battery-saver theme. Wired via `DefaultAppContainer`. | Production package namespace migration (D3 `com.example` -> `com.cnl.aicompanion`) deferred to post-V1 milestone. |
| **Connected Client** | OkHttp `LocalAiRuntimeClient` for Local AI Runtime REST API; `/api/v1/health` and `/api/v1/auth/verify` reachability; `HttpTasksRepository` with optimistic updates and live task synchronization. | SSE streaming for chat responses, full profile/conversation/memory sync, and production connected-mode resilience hardening not implemented. |
| **Credential & Local State** | `SharedPreferencesConnectionRepository` stores host, port, and token in standard Android SharedPreferences (`allowBackup="true"`). In-memory optimistic task state. | Secure Keystore-backed credential storage (D4), durable Room persistence, durable offline mutation queue, and formal conflict reconciliation not implemented. |
| **Network Security** | Current prototype `network_security_config.xml` uses a global `cleartextTrafficPermitted="true"` base configuration. This was introduced for prototype LAN/Tailscale development but is broader than the intended trusted network boundary and must not be treated as production transport policy. | Production transport and authentication hardening under D4/D5 is not yet implemented. Productionization must replace or constrain the global cleartext prototype configuration according to final trusted transport design (e.g., scoped transport policy, Tailscale private transport, or HTTPS/TLS where applicable; exact app-layer TLS/certificate strategy remains future implementation design). Application authentication remains mandatory regardless of transport. |
| **Automated Tests** | Comprehensive unit test suite (historically 110–122 passing tests across development passes; 124 `@Test` methods in active test tree). | Physical device integration, automated UI instrumentation tests, and CI test runner not configured. |
| **Inference Engine** | Reference hardware mobile inference envelope benchmarks recorded on Infinix ZERO ULTRA (Section 4). | On-device GGUF / `llama.cpp` mobile inference engine not integrated into Android codebase. |
