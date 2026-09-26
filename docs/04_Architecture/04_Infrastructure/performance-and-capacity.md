# Performance and Capacity Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.3).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** Focused staged specification authored during R11.3. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) (§13, §14), [`docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../LLAMA_CPP_RUNTIME_ARCHITECTURE.md) (§3), and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Principle P23 Gaming / Low-Impact Resource Mode) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the hardware resource governance, performance profiles, memory budgeting, and dynamic low-impact execution modes for the AI Companion on Windows workstations:
- Static and dynamic resource throttling profiles.
- Decoupled **Gaming / Low-Impact Resource Mode** (PC V1).
- Independence of resource policy from inference engine internals and companion persona.
- Preservation of notification delivery under Decision D10 during low-impact modes.
- Distinguishing current development test hardware (RX 580) from universal performance architecture.

---

## 2. Durable Architecture & Invariants

### 2.1 Dynamic Resource Governance & Independence (Principle P23)

In accordance with Principle P23:
- **Gaming / Low-Impact Mode Approved:** PC V1 includes an approved capability to dynamically throttle companion background resource utilization when the user engages in heavy interactive workloads (such as gaming, video editing, or 3D rendering).
- **Domain Independence Invariant:** Resource governance operates as an independent system policy. It coordinates CPU thread affinity, GPU offload throttling, and background task deferral **without redefining or mutating** the underlying model implementation, inference runtime architecture, character lore, or conversation state.
- **Notification Governance Under Decision D10:** Engaging Gaming or Low-Impact Mode does **not** unconditionally suppress or discard notifications. Critical notifications (such as urgent alarms or time-sensitive reminders) remain strictly governed by the Decision D10 quiet-hours policy and authorized per-item overrides. Nonurgent proactive chatter or routine check-ins may be deferred, but important reminders must not be silently dropped.

### 2.2 Workstation Coexistence & Hardware Portability

- **Non-Intrusive Background Execution:** The companion host runtime executes in the background without causing frame drops, audio stuttering, or severe memory contention for foreground applications.
- **Hardware-Agnostic Governance:** The architecture defines policy levels (e.g., maximum performance, balanced, background throttled, paused) rather than locking specific hardware requirements. The companion must scale gracefully from budget systems with integrated graphics to high-end multi-GPU workstations.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Hardware Performance Profiles (Configured in Code)

Verified in `backend/app/core/config.py`:
- **Static Configuration Profiles:** The backend defines three pre-tuned hardware profiles:
  - **`eco`:** Context window `2048`, GPU layers `0` (CPU-only execution), threads `4`, multimodal GPU offload disabled.
  - **`balanced`:** Context window `4096`, GPU layers `28`, threads `6`, multimodal GPU offload enabled.
  - **`maximum`:** Context window `8192`, GPU layers `33`, threads `8`, multimodal GPU offload enabled.
- **Current Development Reference Baseline:** Current testing and development is conducted on an AMD Radeon RX 580 (8 GB VRAM, Vulkan acceleration). *(This configuration represents current development test hardware reality, not a universal product requirement or permanent architectural gate).*
- **Voice Resource Strategy:** Voice synthesis and recognition are currently designed around CPU/RAM execution to preserve GPU VRAM for the primary conversational LLM. *(This is an engineering reference strategy, not a permanent hardware lock).*

### 3.2 Implemented Reality Boundaries

- **Dynamic Gaming / Low-Impact Mode Status:** **NOT IMPLEMENTED**. The current codebase contains no background process monitor, no fullscreen DirectX/Vulkan game detection hooks, and no dynamic runtime throttler. Switching profiles currently requires editing configuration or restarting the backend with different environment variables.
- **Dynamic VRAM Scaling Status:** **NOT IMPLEMENTED**. GPU layer allocation is statically determined at server launch and cannot dynamically adjust to foreground GPU pressure without restarting the inference server process.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1:

1. **Automated Foreground Activity Detection:** A lightweight host monitor that detects when demanding 3D or gaming processes enter the foreground.
2. **Dynamic Inference Deprioritization:** When Gaming / Low-Impact Mode is active:
   - Non-critical background scheduling and periodic proactive routines are paused or stretched.
   - LLM idle auto-unload timeout is shortened to release VRAM promptly after a turn completes.
   - Background batch operations (e.g., memory indexing or database vacuuming) are deferred until the host returns to normal load.
3. **User Mode Overrides:** Manual user controls in the UI allowing the user to force "Performance", "Balanced", or "Gaming / Low-Impact" mode on demand.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future implementation plans:

- **Detection Strategy:** Specific Windows APIs or heuristics for detecting heavy interactive loads (e.g., Windows Gaming Mode API, foreground fullscreen window queries, GPU load telemetry via DXGI, or simple process name whitelists).
- **Throttling Mechanisms:** Evaluation of whether to pause local LLM inference entirely during gaming, offload temporarily to CPU, or route active user queries to optional Cloud LLM fallback.
- **Memory Pressure Thresholds:** Specific RAM and VRAM utilization percentages used to trigger emergency memory release or model unloading.
- **Thermal & Power Signals:** Integration with Windows battery and power plan events (e.g., automatically entering Eco mode when running on battery power).
- **Profile Transition Hysteresis:** Delay timers and smoothing heuristics preventing rapid thrashing between normal and low-impact modes during brief foreground window switches.

---

## 6. Security & Ownership Boundaries

- **Privilege Separation:** Process monitoring and resource throttling must operate under standard user permissions without requiring Windows administrative privileges or installing kernel-level filter drivers.
- **Deterministic Override Precedence:** Explicit user settings (e.g., "Never throttle while I am talking") take absolute precedence over automated background heuristics.
- **Safe State Recovery:** When recovering from throttled or suspended states, the runtime must gracefully resume internal clocks and schedulers without dropping pending alarms or corrupting state.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Principle P23 (Gaming / Low-Impact Resource Mode), Decision D10 (Scheduling & Quiet Hours).
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Hardware profiles, memory limits, and configuration defaults.
- [`docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../LLAMA_CPP_RUNTIME_ARCHITECTURE.md) — llama.cpp thread counts, context limits, and VRAM management.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](runtime-and-models.md) — Inference server lifecycle, idle timeouts, and hardware execution profiles.
- [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](windows-host-and-notifications.md) — Windows background execution and notification dispatch.
- [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md) — Decision D10 quiet hours and urgent notification overrides.
