# AI Companion — Android Companion Architecture Specification

> **Document Role:** Canonical architecture specification for Android Companion product identity, connected/offline modes, and mobile inference evidence.  
> **Status:** Active Canonical Future-Domain Architecture (Decision D3 Locked; Post-V1 Milestone)  
> **Last Updated:** 2026-09-20 (Reconciliation Pass R3)

---

## 1. Executive Summary & Release Boundary

The **Android Companion** is the mobile client for the AI Companion ecosystem.

> [!IMPORTANT]
> **Release Boundary Notice (Decision D1):**
> - Production Android backend synchronization is **strictly POST-V1**.
> - Android offline on-device inference is **strictly POST-V1**.
> - An initial prototype HTTP client and Task synchronization foundation is implemented in `android/`, but production-grade connected hardening, Keystore credential security (D4), durable offline queuing, and offline inference are deferred beyond V1.
> - This document defines the canonical architecture for future mobile development without creating delivery blockers for V1.

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
| **Network Security** | `network_security_config.xml` permits cleartext HTTP on private RFC 1918 LAN (`192.168.x.x`) and Tailscale (`100.x.x.x`) subnets for developer prototype convenience. | Production security architecture (D5 / TLS verification / pinned certs / hardened pairing) not implemented for mobile. |
| **Automated Tests** | Comprehensive unit test suite (historically 110–122 passing tests across development passes; 124 `@Test` methods in active test tree). | Physical device integration, automated UI instrumentation tests, and CI test runner not configured. |
| **Inference Engine** | Reference hardware mobile inference envelope benchmarks recorded on Infinix ZERO ULTRA (Section 4). | On-device GGUF / `llama.cpp` mobile inference engine not integrated into Android codebase. |
