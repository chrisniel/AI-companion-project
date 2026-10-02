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

### 2.1 Low-Impact / Gaming Mode Governance (Decisions D2, D16)

In accordance with Decision D16 and [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) (Row 44):
- **Three Operational Modes:** The companion runtime provides three operational performance policies:
  1. `Normal`: Standard configured hardware profile (`eco`, `balanced`, or `maximum`).
  2. `Low-Impact`: Throttled resource footprint designed to minimize VRAM, GPU compute, and CPU thread contention with foreground workloads.
  3. `Auto`: Dynamically activates `Low-Impact` mode when a detected foreground application matches the configured **Game & Heavy Application List** (Option B); returns to `Normal` when the application closes.
- **Host-Level Scope:** Performance mode is a machine-wide host policy. It applies globally across all profiles on the PC rather than varying per user profile.
- **Low-Impact Model Substitution Option:** When entering `Low-Impact` mode, the runtime can optionally unload the primary 7B/8B model and substitute a lightweight 1B–3B text model (or drop GPU offload layers to 0/CPU-only), releasing VRAM for foreground gaming or rendering.
- **Deferred Background Inference:** Non-urgent background inference jobs (such as long-term memory extraction or scheduled autonomous routines) are automatically deferred while `Low-Impact` mode is active.
- **Notification Governance Under Decision D10:** Engaging Gaming or Low-Impact Mode does **not** suppress or drop scheduled alarms or urgent reminders. Critical notifications remain strictly governed by the Decision D10 quiet-hours policy and native toast dispatch.

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

### 3.2 Implemented Reality Boundaries

- **Dynamic Gaming / Low-Impact Automatic Policy:** **NOT IMPLEMENTED**. The current codebase contains no automatic process monitor or dynamic policy throttler.
- **Dynamic VRAM Scaling Status:** **NOT IMPLEMENTED**. GPU layer allocation is determined at model load time and cannot dynamically adjust to foreground GPU pressure without reloading or recycling the provider process.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the resource governance capability provides:

1. **Three-State Performance Policy (`Normal`, `Low-Impact`, `Auto`):** User-selectable performance state accessible via Flutter Settings and the System Tray menu.
2. **Option B Game & Heavy App Detection:** In `Auto` mode, an OS process monitor checks against a user-configurable list of executable names (e.g. games, 3D software) to engage `Low-Impact` mode automatically.
3. **Low-Impact Model Substitution:** Optional automatic swap to a lightweight 1B–3B text model to free VRAM for heavy foreground graphics tasks.
4. **Deferred Background Tasks:** Pauses non-critical background jobs during `Low-Impact` mode while preserving alarm and reminder firing.

---

## 5. Open Technical Details & Decision Debt

Detailed implementation choices for future planning are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Process Polling Interval:** Polling frequency and CPU cost of scanning running process names in `Auto` mode (e.g., 5-second tick).
- **Hysteresis & Cooldown Delay:** Cooldown timer (e.g., 30–60 seconds) after a game exits before swapping back to the heavy model to avoid thrashing during restarts.
- **Model Swap Transition UX:** Visual indicator in the Flutter client showing when a model swap or low-impact throttle is currently in progress.

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

