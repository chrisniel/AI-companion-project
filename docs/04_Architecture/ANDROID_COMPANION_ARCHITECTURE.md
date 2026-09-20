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
> - Neither capability is part of the AI Companion V1 release, and neither is currently implemented in the repository.
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

| Model Candidate | Parameter Size | Quantization | Observed Token Speed | Suitability Assessment |
| :--- | :--- | :--- | :--- | :--- |
| **Gemma 3** | 270M (~0.3B) | Q8 | **~25.56 tok/s** | Extremely fast; ideal for responsive utility and text transforms. |
| **Qwen3.5** | 0.8B | Q4_K_M | **~14.81 tok/s** | Strong conversational fluency; very viable for daily mobile chat. |
| **Llama 3.2** | ~1B (1.2B) | Q4_K_M | **~12.37 tok/s** | Solid coherence; acceptable conversational throughput. |
| **Qwen3** | ~0.6B | Q8 | **~11.75 tok/s** | Compact footprint; reliable baseline performance. |

### 4.3 Engineering Interpretation & Invariants
1. **Viability Demonstrated:** 0.5B–1B quantized GGUF models are physically demonstrated as viable for local mobile inference on mid-range Android hardware (achieving 12–25+ tokens per second).
2. **Hardware Generalization Prohibition:** These benchmarks represent physical evidence on a specific MediaTek Dimensity 920 device. They must **not** be generalized as guaranteed performance across all Android hardware or lower-spec devices.
3. **No Premature Model Lock:** The project has **not** permanently selected a single mobile model. Model selection remains open until dedicated post-V1 mobile offline planning.
4. **Multimodal Status:** While Qwen3.5 ~0.8B is an architecturally promising multimodal candidate, mobile vision/projector execution on Android hardware remains **completely unvalidated**.

---

## 5. Current Implementation Reality

The active repository contains a well-tested, high-fidelity mobile UI prototype in `android/`:

| Subsystem | Implemented & Verified Reality | Known Non-Implemented Boundary |
| :--- | :--- | :--- |
| **Mobile UI** | 17 Jetpack Compose screens, SoftGlass Neumorphic design engine, OLED battery-saver theme. | Real HTTP/SSE network client connecting to FastAPI backend not implemented. |
| **Local State** | UI state management, Compose view models, SharedPreferences storage. | Room database and persistent sync queue not implemented. |
| **Automated Tests** | 110 passing unit tests in Gradle test suite. | Physical device integration and automated UI instrumentation tests not in CI. |
| **Inference Engine** | Architecture benchmarks recorded (Section 4). | On-device GGUF / `llama.cpp` inference engine not integrated into Android codebase. |
