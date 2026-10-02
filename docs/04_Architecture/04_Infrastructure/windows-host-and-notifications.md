# Windows Host and Notifications Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the host execution model, OS lifecycle integration, background persistence, and native notification presentation for the AI Companion on Windows:
- Decoupled host runtime lifecycle independent of client window or session lifetime.
- Primary production client is Flutter Desktop ([`ADR-0017`](../decisions/ADR-0017-flutter-production-windows-client.md)); React Web remains a supported developer harness; Android is prototype/reference.
- Autostart integration upon Windows user login via Windows Task Scheduler.
- System tray integration and the fundamental invariant: **"Quit UI != Stop Runtime"**.
- Native Windows desktop notification delivery for reminders, alarms, and routines.
- Post-sleep and offline reminder reconciliation semantics with durable FIFO turn queues ([`ADR-0019`](../decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md)).
- Best-effort OS wake capabilities for scheduled companion alarms.

It governs the host infrastructure that keeps the companion alive, responsive, and punctual on the user's primary workstation.

---

## 2. Durable Architecture & Invariants

### 2.1 Host Runtime & Client Lifecycle Independence (Decision D2)

In accordance with Decision D2:
- **Decoupled Lifecycle:** The Local AI Runtime operates as an independent host runtime process whose lifecycle is strictly decoupled from any client application or session.
- **Quit UI != Stop Runtime:** 
  - The primary Windows UI is Flutter Desktop. Launching the desktop app connects to the running runtime (or starts it if dormant).
  - Closing the desktop window minimizes/hides the UI to the Windows System Tray.
  - Quitting or exiting the Flutter UI process terminates only the visual shell. The Local AI Runtime continues executing in the background to service scheduled reminders, alarms, routines, and satellite devices.
  - The runtime can only be stopped explicitly by selecting "Stop Runtime" from the system tray context menu, through the companion Settings UI, or via command-line termination.
- **Client Disconnection & Durable Turn Queues (`ADR-0019`):** In-flight conversational requests are managed by a durable FIFO turn queue inside the runtime. If the client disconnects, crashes, or loses network connection during inference, the turn continues to completion and persists to the database. The client retrieves the completed state upon reconnecting.

### 2.2 Background Autostart at User Login (PC V1)

In accordance with Decision D2 and [`ADR-0003`](../decisions/ADR-0003-d2-windows-host-model.md):
- **Task Scheduler Registration:** PC V1 provisions a Windows Task Scheduler task configured to launch `companion_runtime.exe` (or startup script) `At log on` of the user.
- **Standard User Privileges:** The task executes strictly with standard user privileges without triggering User Account Control (UAC) elevation prompts.
- **Continuous Background Availability:** Autostart ensures that companion scheduling, proactive routines, and local LAN pairing endpoints are active immediately upon login, regardless of whether the user opens the Flutter UI.

### 2.3 Native Windows Notifications & Offline Catch-up (Decision D10)

In accordance with Decision D10 and [ADR-0011](../decisions/ADR-0011-d10-scheduling-and-notification-semantics.md):
- **Runtime Owns the Backlog:** The Local AI Runtime owns schedule truth, event generation, and the durable event backlog.
- **Flutter Owns Presentation:** The Flutter client consumes these events and owns native Windows Toast presentation.
- **Client Hidden vs. Quit Semantics:**
  - **Hidden (System Tray):** If the Flutter UI is merely hidden (closed to tray), it remains running and presents notifications normally.
  - **Explicit Quit:** If the user explicitly quits the Flutter client, the Runtime continues executing. The event remains durable in the backlog. Native presentation waits until the client returns. Quit Flutter != Stop Runtime.
- **Quiet-Hours & Urgency Policy:**
  - **Alarms:** Classified as high-urgency and **bypass quiet hours by default**, ringing audibly and visually.
  - **Reminders & Routines:** Respect configured quiet hours by default.
- **Offline & Sleep Catch-up:** When the host machine awakens or the client reconnects, SchedulerService evaluates missed reminder triggers, delivering aggregated catch-up notifications while expiring stale low-priority alerts.

### 2.4 Best-Effort OS Alarm Wake Invariant

Scheduled companion alarms incorporate system wake capabilities, bounded by real-world hardware and OS invariants:
- **Best-Effort Wake Guarantee:** System wake from sleep or low-power states is strictly **best-effort**.
- **Hardware & Power State Limits:** System wake depends on host hardware support, ACPI sleep states (Modern Standby S0 vs. S3), firmware (BIOS/UEFI) configurations, power source (AC power vs. battery), and Windows OS power management policies.
- **No Absolute Wake Claim:** The architecture explicitly rejects any claim that the software can unconditionally wake a PC from every arbitrary sleep, hibernation, hybrid shutdown, or firmware-locked state. Alarm wake is strictly best-effort without universal ACPI or firmware wake guarantees.

---

## 3. Current Verified Implementation

Repository source code establishes the current baseline reality:

- **Launch Model:** The FastAPI backend is currently launched as a foreground terminal process (via uvicorn / Python scripts) listening on `127.0.0.1:8000`. Diagnostic standalone model probes are launched via PowerShell scripts (e.g., `scripts/start-model.ps1` invoking `llama-server.exe` on isolated diagnostic ports).
- **Autostart Status:** Windows host autostart at login is **NOT IMPLEMENTED**. No Task Scheduler registration or startup hook exists in the repository.
- **Notification Adapter Status:** Native Windows notification presentation is **NOT IMPLEMENTED**. The codebase contains no Flutter toast bindings.
- **Client Lifetime Reality:** In current development, closing the browser tab leaves the backend uvicorn terminal process running (confirming process independence), but no OS-level alerts are generated if events occur while the browser is closed.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the Windows host infrastructure will provide:

1. **Flutter Desktop Client Integration (`ADR-0017`):** Native Windows Flutter desktop client serving as the primary desktop experience, with system tray icon, window hide-on-close, and background runtime status indicator.
2. **Task Scheduler Autostart at User Login:** Automatic startup configuration established during installer setup or settings toggle.
3. **Native WinRT Toast Presentation:** Direct platform notification delivery for reminders, alarms, and routines.
4. **Runtime Durable Turn Queue (`ADR-0019`):** Server-side turn queue persisting request processing across client disconnects.
5. **Resilient Scheduling & Wake Catch-up:** Persistent `SchedulerService` requesting OS timer wake for scheduled alarms and reconciling missed events upon wake.

---

## 5. Open Technical Details & Decision Debt

Detailed implementation choices for future planning are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Toast Interaction Actions:** Specific deep-linking buttons on Windows toast notifications (e.g., "Snooze 10m", "Mark Done", "Chat with Companion").
- **Wake Timer API Binding:** Evaluation of Windows kernel waitable timers (`CreateWaitableTimerExW` with `TIMER_ALL_ACCESS`) vs. power request APIs.
- **Notification Catch-up Aggregation Algorithm:** Precise grouping and batching heuristics for missed reminders when waking from multi-day sleep.

---

## 6. Security & Ownership Boundaries

- **Local Host Boundary (Decision D2):** The host runtime binds exclusively to loopback (`127.0.0.1`) by default, preventing unauthenticated remote LAN access to host administration endpoints.
- **User Permission Execution:** The runtime executes under the standard privileges of the logged-in Windows user account. It does **not** require elevated Windows Administrator privileges for day-to-day companion conversation or notification presentation.
- **Quiet-Hours & Notification Governance:** Native notification delivery MUST obey the D10 quiet-hours policy and authorized per-item overrides. High-frequency automated routines are bounded to avoid notification fatigue.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Decision Spine
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Host execution baseline, Decision D2 (decoupled runtime), Decision D10 (Tasks & Reminders).
- [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) — Master Decision Register (Row 22 Flutter Client, Row 25 Windows Host, Row 38 Scheduling).
- [`docs/04_Architecture/decisions/ADR-0003-d2-windows-host-model.md`](../decisions/ADR-0003-d2-windows-host-model.md) — Local AI Runtime Model.
- [`docs/04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md`](../decisions/ADR-0017-flutter-production-windows-client.md) — Flutter Production Windows Client.
- [`docs/04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md`](../decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md) — Client ↔ Runtime Contract & Work Boundaries.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md) — Scheduled reminder triggers, alarm definitions, and companion routine pacing.
- [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](runtime-and-models.md) — Local LLM inference server process management.
- [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](performance-and-capacity.md) — Resource governance, gaming mode throttling, and background execution caps.

