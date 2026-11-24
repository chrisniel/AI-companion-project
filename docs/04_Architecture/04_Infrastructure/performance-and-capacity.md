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
- Mobile Progressive Resource Governor, evidence-driven qualification, and truthful Out-of-Memory (OOM) resilience (Mobile V1).

---

## 2. Durable Architecture & Invariants

### 2.1 Low-Impact / Gaming Mode Governance

Low-Impact/Gaming is a separately approved PC V1 resource policy with no historical D-number, governed by [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) (Row 44):
- **Three Operational Modes:** The companion runtime provides three operational performance policies:
  1. `Normal`: Standard configured hardware profile (`eco`, `balanced`, or `maximum`).
  2. `Low-Impact`: Throttled resource footprint designed to minimize VRAM, GPU compute, and CPU thread contention with foreground workloads.
  3. `Auto`: Dynamically activates `Low-Impact` mode when a detected foreground application matches the configured **Game & Heavy Application List** (Option B); returns to `Normal` when the application closes.

- **V1 Auto Mode Scope:** Auto mode relies exclusively on the user-configured Game & Heavy App list. Generic heuristic load detection is not required for PC V1.
- **Runtime Preservation:** The core Runtime, scheduler, and security subsystems remain alive regardless of mode.
- **Foreground Usability:** Explicit foreground chat, voice, web, and import actions remain usable in Low-Impact mode.
- **Discretionary Deferral:** Background discretionary work is deferred first before impacting foreground capability.
- **Transition Safety:** Mode transitions must be safe; they do not kill active generation mid-flight.
- **Visibility:** The requested state versus the actually applied state must remain visible to the user.
- **Cloud Constraint:** Resource pressure never authorizes cloud egress.
- **Concurrency Default:** The system defaults to one generative model resident. Advanced scenarios >1 are possible but must include capacity warnings.
- **Restoration Policy:** Leaving Low-Impact mode restores the primary-model policy but does not force immediate eager loading of the heavy model until needed.
- **Host-Level Scope:** Performance mode is a machine-wide host policy. It applies globally across all profiles on the PC rather than varying per user profile.
- **Low-Impact Model Substitution Option:** When entering `Low-Impact` mode, the runtime can optionally unload the primary 7B/8B model and substitute a compatible lightweight local text model (e.g. 1B-3B) (or drop GPU offload layers to 0/CPU-only), releasing VRAM for foreground gaming or rendering.
- **Deferred Background Inference:** Non-urgent background inference jobs (such as long-term memory extraction or scheduled autonomous routines) are automatically deferred while `Low-Impact` mode is active.
- **Notification Governance Under Decision D10:** Engaging Gaming or Low-Impact Mode does **not** suppress or drop scheduled alarms or urgent reminders. Critical notifications remain strictly governed by the Decision D10 quiet-hours policy and native toast presentation.

### 2.2 Workstation Coexistence & Hardware Portability

- **Workstation Coexistence:** Resource policy minimizes material contention with foreground workloads while preserving required companion responsiveness and punctuality.
- **Hardware-Agnostic Governance:** The architecture defines policy levels (maximum performance, balanced, background throttled, paused) rather than locking specific hardware requirements. The companion scales gracefully from budget systems with integrated graphics to high-end workstations.

### 2.3 Performance & Telemetry Truthfulness

To ensure truthful operational observability and prevent misleading system diagnostics, the architecture enforces the following invariants:

- **Requested vs. Applied Policy Distinction:** The architecture requires that requested policy/profiles (e.g., user-selected profile or dynamic throttling mode) and actually applied policy/profiles (what the runtime has currently loaded or enforced) remain explicitly distinguishable wherever they diverge (e.g., during model reload transitions, engine recycling, or when hardware bounds prevent full application).
- **Categorical Telemetry Separation:** Reporting interfaces, telemetry APIs, and diagnostic logs must strictly distinguish between:
  1. *Configured Values:* Parameters declared by configuration or user policy (e.g., target context size, configured offload layers).
  2. *Measured Telemetry:* Empirical metrics obtained directly from a real supported probe, runtime metric counter, or verified OS/driver query.
  3. *Estimated Values:* Derived heuristics, theoretical approximations, or synthetic capacity estimates.
- **Prohibition of Fabricated Telemetry:** UI, API, and runtime reporting must **never** fabricate measured telemetry. When hardware probes or runtime metrics are unavailable, unsupported, uninitialized, or permission-restricted on the host machine, telemetry must be reported truthfully as unavailable or unknown (`null` / `unknown`) rather than replaced with invented, synthetic, or hardcoded values.
- **Probe & Vendor Independence:** The architecture does not permanently lock a single telemetry probing library, diagnostic utility, or GPU vendor SDK. Current AMD Radeon RX 580 and Vulkan reference metrics represent development testing evidence only.

### 2.4 Mobile Progressive Resource Governor & Hardware Qualification (Mobile V1)

In accordance with Decision `D-PHONE-05A` and the Mobile V1 hardware architecture baseline:

- **Progressive Resource Governor (`D-PHONE-05A`):** Resource governance on mobile devices operates via progressive, user-visible intervention driven by empirical thermal, battery, and memory metrics:
  - *Progressive Multi-Stage Intervention:* Rather than abrupt binary failure, the governor intervenes progressively across pressure tiers. Specific tier labels (such as illustrative examples *Normal*, *Constrained*, *High Pressure*, and *Critical / Emergency*), transition curves, and exact numerical thresholds are illustrative presentation examples and open implementation design:
    - *Early / Non-Critical Pressure:* Warns early and mitigates gracefully. Non-urgent background tasks (routine execution, sync catch-up) may be deferred first, allowing active foreground generation to complete safely where thermal/memory headroom permits.
    - *Elevated / Severe Pressure:* May pause or throttle ongoing inference. User choices may include: Continue at reduced throughput, Finish current turn then cool down, or Stop and unload model.
    - *Critical / Emergency Pressure:* Critical/emergency pressure may force cancellation and/or unload when required by platform or hardware safety policy, after durable state preservation where possible.
  - *Hardware Safety Boundary:* The user cannot override underlying hardware safety protections (OS thermal throttling, emergency shutdown).
  - *Unload Invariant:* Automatic unload never deletes or removes the installed model artifact from disk.
  - *Truthful Observability:* Resource state, requested vs. actual execution backend, model residency status, and exact degradation reasons are visible to the user. User-facing presentation labels are illustrative UI abstractions, not frozen canonical state names or replacements for underlying platform metrics (such as Android thermal status and memory info).
  - *No Runtime Quantization Dial:* The architecture does not invent "lower quantization" as an automatic online runtime transition (quantization is an immutable property of an installed artifact). Exact metric thresholds remain implementation-open.
- **Evidence-Driven Mobile Hardware Qualification:**
  - Qualification for device-local generative LLM execution is evidence-based rather than tied to arbitrary commercial hardware brackets or rigid RAM thresholds (no "minimum 6 GB RAM" mandate in canonical architecture):
    1. *Supported ABI & Execution Backend:* 64-bit ABI support and compatible runtime acceleration libraries.
    2. *Memory Headroom Preflight:* Currently available system memory meets the model's resident working set plus a validated safety margin without triggering OS low-memory killer (LMK) eviction.
    3. *Thermal Stability:* Device sustains inference without immediate thermal throttling under normal ambient conditions.
    4. *Preflight Warmup:* Clean model initialization without allocation failures.
    5. *Sustained Responsiveness:* Acceptable interactive token generation throughput without UI thread jank or frame drops.
    6. *Battery Policy Compliance:* Battery state and power-saver policies permit local inference.
- **Truthful Out-Of-Memory (OOM) and Process Death Architecture:**
  - Canonical architecture must **never** claim or promise absolute "zero crashes under Out-Of-Memory". Mobile operating systems (such as Android via LMK) terminate processes abruptly at the OS level under memory pressure without throwing catchable exceptions.
  - The architecture enforces truthful defensive measures:
    - Preflight memory headroom verification before loading models.
    - Graceful load failure handling returning structured error diagnostics.
    - Bounded context window allocation and strict single resident generative model cap (`D-PHONE-05`).
    - Preserving durable conversation turns, outbox intents, and scheduling state *before* launching heavy generative operations.
    - Safe tolerance and clean recovery from abrupt OS process death without database or state corruption.

### 2.5 Hardware-Aware GPU Memory Budgeting & Model Allocation Policy (Target Architecture — PC-CLIENT-010)

To protect workstation stability and prevent graphics driver crashes or memory thrashing, the target architecture establishes hardware-aware memory budgeting (tracked under `PC-CLIENT-010`):

- **50% Dedicated VRAM Target:** Model memory allocation recommendations target at most **50% of dedicated VRAM** for resident model weights and KV cache buffer under standard operating profiles.
- **Measured Headroom & Safety Reserve:** Allocation boundaries are bounded by real-time measured available VRAM headroom, maintaining a mandatory safety reserve for desktop window compositing, operating system displays, and concurrent user applications.
- **Fail-Closed on Capacity Failure:** When a model's resident memory requirement exceeds verified hardware limits or preflight checks detect insufficient headroom, the system fails closed with structured diagnostics rather than silently falling back, overflowing into high-latency shared system RAM, or risking GPU driver TDR (Timeout Detection and Recovery) resets.
- **Host-Level Configuration Scope:** Hardware memory constraints and active model assignments reside in persistent host configuration (`COMPANION_DATA_ROOT/config/host_config.json`), applying globally across all profiles on the PC.
- **Implementation Status:** Not currently enforced in code; tracked under `PC-CLIENT-010`. Current implementation enforces static profiles (`eco`, `balanced`, `maximum`) and fail-closed model selection precedence.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Hardware Performance Profiles (Configured in Code)

Verified in `backend/app/core/config.py`:
- **Static Configuration Profiles:** The backend defines three pre-tuned hardware profiles:
  - **`eco`:** Context window `2048`, GPU layers `0` (CPU-only execution), threads `4`, multimodal GPU offload disabled.
  - **`balanced`:** Context window `4096`, GPU layers `28`, threads `6`, multimodal GPU offload enabled.
  - **`maximum`:** Context window `8192`, GPU layers `33`, threads `8`, multimodal GPU offload enabled.
- **Profile Switching API:** The backend exposes `PATCH /api/v1/models/profile` and `BaseLLMProvider.set_profile()`. In `LlamaCppProvider`, `set_profile()` can switch between `eco`, `balanced`, and `maximum` profiles when generation is inactive, cleanly recycling a Core-managed router so the new profile applies on subsequent activation.
- **Current Development Reference Baseline:** Current testing and development is conducted on an AMD Radeon RX 580 (8 GB VRAM, Vulkan acceleration). *(This configuration represents current development test hardware reality, not a universal product requirement or permanent architectural gate).*
- **Voice Resource Strategy:** Voice synthesis and recognition CPU/RAM-first execution represents a development reference strategy, not an implemented Voice runtime and not a permanent hardware rule.

### 3.2 Implemented Reality Boundaries & M5 Batch A Delivery

- **Dynamic Gaming / Low-Impact Policy (`PC-RESOURCE-001`..`004`, `DEBT-V1-07` — Implemented & Automated-Verified in M5 Batch A):**
  - `ResourceGovernor` (`backend/app/services/resource_governor.py`) implements the three-state host policy (`normal`, `low_impact`, `auto`) in a background asyncio monitor (`RESOURCE_POLL_INTERVAL_SECONDS = 5.0`), persisting normalized lowercase `.exe` watchlists, `low_impact_strategy` (`cpu_eco`, `unload_when_idle`, `lightweight_model`), `low_impact_model_id`, and `cooldown_seconds` (`5`–`300`, default `30s`) under the `"resource_policy"` section of `host_config.json` with `threading.RLock` + unique atomic temp files (`host_config.py`).
  - Standard-user Win32 `ctypes` `CreateToolhelp32Snapshot` process scanning matches watched basenames with hysteresis cooldown (skipping active-turn transitions cleanly with `deferred_active_turn` / `deferred_model_load` and resetting cooldown immediately on explicit `PUT` mode changes).
  - Non-blocking `apply_resource_policy()` hooks (`BaseLLMProvider`, `LlamaCppProvider`, `MockLLMProvider`) support `cpu_eco` (`0` GPU layers / `eco` router profile), `unload_when_idle` (`RESOURCE_LOW_IMPACT_IDLE_SECONDS = 60.0`), and `lightweight_model` substitution with fail-closed `lightweight_model_missing` / `lightweight_model_unavailable` fallback to `cpu_eco`, plus lazy `Normal` exit (restoring requested selection/profile cleanly without eagerly reloading the heavy model until needed).
  - `should_defer_background_work` hooks defer non-explicit automatic memory extraction (`orchestrator.py`) and periodic memory sweeps + non-bypass Routines (`scheduler/service.py`) during active `Low-Impact` while strictly preserving explicit `"Remember that..."` requests, foreground chat/voice/tools, Alarms, Reminders, and Task due reminders per Decision D10.
  - `hardware_probe.py` exposes `None`-safe live RAM (`probe_live_system_memory()`) and `None` GPU telemetry (`probe_live_gpu_telemetry()` returning `None` / UI `Unavailable` until a verified live adapter is integrated, honoring §2.3 anti-fabrication rules).
  - Host-Admin `GET`/`PUT /api/v1/system/resources` (`NON_DB_GET_PATHS` read exemption; `503` write guard during shutdown), OpenAPI/`companion_api` DTOs, Desktop `Settings -> Performance & Gaming` (`SettingsPerformanceSection`), and Tray `Performance Mode` submenu synchronization are implemented and automated-verified; live Windows OS gaming/VRAM validation (`DEBT-EXP-001`) remains pending manual QA.
- **Dynamic VRAM Scaling Status:** **NOT IMPLEMENTED**. GPU layer allocation is determined at model load time and recycles cleanly via `LlamaCppProvider` transitions rather than adjusting mid-inference.
- **Hardware-Aware VRAM Budgeting & Recommendation Status:** Advisory profile/CTX recommendations (`assess_hardware_suitability()`, `assess_context_options()`) are implemented (`PC-CLIENT-010`), while strict dynamic 50% dedicated VRAM budgeting and live GPU telemetry probing (`host_vram_used_gb` / `gpu_utilization_percent`) remain open target enhancements.

---

## 4. Remaining Target Architecture / Open Verification (PC V1)

Remaining PC V1 performance & resource governance items outside M5 Batch A:

1. **Live Reference Hardware Benchmark (`DEBT-EXP-001`):** Empirical Windows desktop QA with real heavy `.exe` launches, lightweight model swap latency/VRAM measurements on AMD RX 580, and D10 alarm firing during `Low-Impact`.
2. **Real-Time Live GPU Utilization / VRAM Adapter & 50% VRAM Dynamic Gate (`PC-CLIENT-010`):** Optional Windows PDH/DXGI/WMI live GPU utilization & VRAM usage probe replacing `None` (`Unavailable`) live GPU fields, plus strict capacity fail-closed enforcement.

---

## 5. Open Technical Details & Decision Debt

Detailed implementation choices and resolved items are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Process Polling Interval & Watchlist Storage (`DEBT-V1-07` — Resolved in M5 Batch A):** `ResourceGovernor` polls every `5.0s` using standard-user Win32 `CreateToolhelp32Snapshot`, stores lowercase `.exe` basenames in `host_config.json`, and enforces configurable `5`–`300s` (default `30s`) hysteresis cooldown.
- **Model Swap Transition UX:** Desktop `Settings -> Performance & Gaming` displays explicit `Requested` vs `Applied` telemetry, cooldown countdown, and non-blocking `transitionState` (`switching` / `deferred_active_turn` / `deferred_model_load`) indicators alongside System Tray submenu checks.
- **Benchmark Tuning (`DEBT-EXP-001`):** Empirical RX 580 latency & VRAM benchmark remains open pending manual hardware runs.

---

## 6. Security & Ownership Boundaries

- **Least Privilege & Governance Authority:** Resource governance uses standard user process inspection APIs (e.g., enumerating running process names via standard Windows APIs) without requiring elevated Administrator privileges.
- **Host Administration Isolation:** Configuring the Game & Heavy App list and changing performance mode is restricted to local host sessions.
- **Safe State Recovery:** When recovering from throttled or low-impact states, the runtime gracefully resumes pending tasks without dropping scheduled alarms.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Decision Spine
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Principle P23 (Gaming / Low-Impact Resource Mode), Decision D10 (Scheduling & Quiet Hours).
- [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) — Master Decision Register (Row 44 Low-Impact / Gaming Mode).
- [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md) — Open performance technical debt.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](runtime-and-models.md) — Inference server lifecycle, idle timeouts, and hardware execution profiles.
- [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](windows-host-and-notifications.md) — Windows background execution, tray menu, and notification dispatch.
- [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md) — Decision D10 quiet hours and urgent notification overrides.
- [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](mobile-capabilities-and-runtime.md) — Mobile capability qualification, inference runtimes, and local execution policy.

