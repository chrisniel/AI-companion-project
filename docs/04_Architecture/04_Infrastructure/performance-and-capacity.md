# Performance and Capacity Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the hardware resource governance, performance profiles, memory budgeting, and dynamic low-impact execution modes for the AI Companion on Windows workstations:
- Static and dynamic resource throttling profiles.
- Decoupled **Gaming / Low-Impact Resource Mode** (PC V1).
- Independence of resource policy from inference engine internals and companion persona.
- Preservation of notification delivery under Decision D10 during low-impact modes.
- Distinguishing current development test hardware (RX 580) from universal performance architecture.
- Telemetry truthfulness, distinguishing configured, measured, and estimated values, and prohibiting fabricated metrics.

---

## 2. Durable Architecture & Invariants

### 2.1 Dynamic Resource Governance & Independence (Principle P23)

In accordance with Principle P23:
- **Gaming / Low-Impact Mode Approved:** PC V1 includes an approved capability to enter a lower-impact resource policy when the user engages in heavy interactive workloads (such as gaming, video editing, or 3D rendering).
- **Domain Independence Invariant:** Resource governance operates as an independent system policy. It coordinates host resource contention **without redefining or mutating** the underlying model implementation, inference runtime architecture, character lore, or conversation state.
- **Notification Governance Under Decision D10:** Engaging Gaming or Low-Impact Mode does **not** unconditionally suppress or discard notifications. Critical notifications (such as urgent alarms or time-sensitive reminders) remain strictly governed by the Decision D10 quiet-hours policy and authorized per-item overrides. Important scheduled reminders must not be silently dropped.

### 2.2 Workstation Coexistence & Hardware Portability

- **Workstation Coexistence:** Resource policy should minimize material contention with foreground workloads while preserving required companion behavior.
- **Hardware-Agnostic Governance:** The architecture defines policy levels (e.g., maximum performance, balanced, background throttled, paused) rather than locking specific hardware requirements. The companion must scale gracefully from budget systems with integrated graphics to high-end workstations.

### 2.3 Performance & Telemetry Truthfulness

To ensure truthful operational observability and prevent misleading system diagnostics, the architecture enforces the following invariants:

- **Requested vs. Applied Policy Distinction:** The architecture requires that requested policy/profiles (e.g., user-selected profile or dynamic throttling mode) and actually applied policy/profiles (what the runtime has currently loaded or enforced) remain explicitly distinguishable wherever they diverge (e.g., during model reload transitions, engine recycling, or when hardware bounds prevent full application).
- **Categorical Telemetry Separation:** Reporting interfaces, telemetry APIs, and diagnostic logs must strictly distinguish between:
  1. *Configured Values:* Parameters declared by configuration or user policy (e.g., target context size, configured offload layers).
  2. *Measured Telemetry:* Empirical metrics obtained directly from a real supported probe, runtime metric counter, or verified OS/driver query.
  3. *Estimated Values:* Derived heuristics, theoretical approximations, or synthetic capacity estimates.
- **Prohibition of Fabricated Telemetry:** UI, API, and runtime reporting must **never** fabricate measured telemetry. When hardware probes or runtime metrics are unavailable, unsupported, uninitialized, or permission-restricted on the host machine, telemetry must be reported truthfully as unavailable or unknown (`null` / `unknown`) rather than replaced with invented, synthetic, or hardcoded values.
- **Probe & Vendor Independence:** The architecture does not permanently lock a single telemetry probing library, diagnostic utility, or GPU vendor SDK (such as `psutil`, AMD ADL, GPU-Z, NVML, or DirectX-specific hooks). Exact probing mechanisms and monitoring libraries remain open design. Current AMD Radeon RX 580 and Vulkan reference metrics represent development testing evidence only.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Hardware Performance Profiles (Configured in Code)

Verified in `backend/app/core/config.py`:
- **Static Configuration Profiles:** The backend defines three pre-tuned hardware profiles:
  - **`eco`:** Context window `2048`, GPU layers `0` (CPU-only execution), threads `4`, multimodal GPU offload disabled.
  - **`balanced`:** Context window `4096`, GPU layers `28`, threads `6`, multimodal GPU offload enabled.
  - **`maximum`:** Context window `8192`, GPU layers `33`, threads `8`, multimodal GPU offload enabled.
- **Profile Switching API:** The backend exposes `PATCH /api/v1/models/profile` and `BaseLLMProvider.set_profile()`. In `LlamaCppProvider`, `set_profile()` can switch between `eco`, `balanced`, and `maximum` profiles when generation is inactive, cleanly recycling a Core-managed router so the new profile applies on subsequent activation. (Profile switching does not require manual config editing only).
- **Current Development Reference Baseline:** Current testing and development is conducted on an AMD Radeon RX 580 (8 GB VRAM, Vulkan acceleration). *(This configuration represents current development test hardware reality, not a universal product requirement or permanent architectural gate).*
- **Voice Resource Strategy:** Voice synthesis and recognition CPU/RAM-first execution represents a development reference strategy, not an implemented Voice runtime and not a permanent hardware rule.

### 3.2 Implemented Reality Boundaries

- **Dynamic Gaming / Low-Impact Automatic Policy:** **NOT IMPLEMENTED**. The current codebase contains no automatic background process monitor, no fullscreen DirectX/Vulkan game detection hooks, and no dynamic policy throttler.
- **Dynamic VRAM Scaling Status:** **NOT IMPLEMENTED**. GPU layer allocation is determined at model load time and cannot dynamically adjust to foreground GPU pressure without reloading or recycling the provider process.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the resource governance capability provides:

1. **Lower-Impact Resource Policy:** Ability for the companion runtime to enter a lower-impact resource policy during heavy foreground activity.
2. **Bounded Resource Usage:** Bounded resource utilization under foreground system pressure to minimize contention with user applications.
3. **Preserved Notification Integrity:** Ensuring scheduled alarms and notifications are not silently dropped when low-impact mode is engaged.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future implementation plans:

- **User Controls & Overrides:** Manual user toggles, forced modes, override precedence, automatic vs. manual activation heuristics, and settings/tray controls.
- **Detection Strategy:** Specific detection heuristics (e.g., Windows Gaming Mode API, foreground fullscreen window queries, GPU load telemetry via DXGI, process whitelists, or purely manual user toggling).
- **Throttling Mechanisms:** Concrete throttling techniques (e.g., GPU-layer offload adjustments, CPU thread limits, idle timeout adjustments, or deferral of non-critical background batch jobs like database vacuuming).
- **Profile Transition & Hysteresis:** Smoothing delays and threshold timers preventing rapid thrashing between normal and low-impact modes.
- **Cloud Fallback Interaction:** Whether and how low-impact mode interacts with optional cloud LLM fallback.
- **Mode Taxonomy & UI Surface:** Exact mode names, settings switches, and tray menu controls.
- **Hardware Telemetry Probing Mechanism:** Evaluation of portable, low-overhead hardware and runtime metric probes (e.g., OS performance counters, vendor-neutral query interfaces, or driver APIs) for measuring CPU, RAM, and VRAM utilization without imposing heavy background polling costs.

---

## 6. Security & Ownership Boundaries

- **Least Privilege & Governance Authority:** Resource governance should use the least privilege necessary and must not grant generic unrestricted OS-administration authority. Exact OS privilege requirements for a selected monitoring/throttling mechanism remain open design and require security review.
- **Deterministic Override Precedence:** User-configured policy preferences participate in deterministic resource governance. Exact precedence between user overrides, resource-safety limits, and automated heuristics remains open design.
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
