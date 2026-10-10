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

### 2.1 Host Runtime & Client Lifecycle Independence (Decision D2 Refined — 2026-10-11 Option A)

In accordance with Decision D2 and the human-approved PC V1 Option A refinement (Chris, October 11, 2026):
- **Decoupled Lifecycle & Process Independence:** The Local AI Runtime operates as an independent host runtime process whose execution is strictly decoupled from Flutter Desktop UI lifetime.
- **Window Close (`×`) Hides to Tray:** Closing the desktop window minimizes/hides the visual UI to the Windows System Tray. The Local AI Runtime and all essential background services continue executing uninterrupted.
- **Unexpected UI Exit / Crash Survival:** If the Flutter UI crashes or terminates unexpectedly, the Local AI Runtime remains independent and alive. Relaunching or restarting Flutter attaches cleanly to the authenticated existing runtime (or safely starts it if absent).
- **Approved Full Exit ("Exit Companion" via System Tray):** The system tray menu provides an explicit "Exit Companion" action. Selecting this action triggers an explicit confirmation dialog warning that PC-hosted reminders, alarms, background work, and connected services will become unavailable. Upon user confirmation, it gracefully stops the verified local runtime, its owned model/provider processes, and the Flutter client. This capability is owned by `PC-HOST-005` (Host Administration Separation & Secure Lifecycle Authority) and requires secure local lifecycle authorization rather than an ordinary client bearer token.
- **Intentional-Exit Restart Suppression:** An intentional full exit must not be immediately undone by automatic restart loops or watchdog scripts. Normal startup at the next Windows user login or deliberate manual relaunch remains supported (`PC-HOST-002`).
- **Remote Host Protection:** A Flutter client connected to a remote host runtime has zero implicit authority to stop the remote host. It must clearly disclose that the remote runtime remains running.
- **Pause Companion Semantics:** A "Pause Companion" action suspends optional AI/proactive background tasks without stopping the core application. Essential alarms and scheduled reminders remain active in accordance with Decision D10. Detailed pause implementation belongs to dedicated follow-on work.
- **Client Disconnection & Durable Turn Queues (`ADR-0019`):** In-flight conversational requests are managed by a durable FIFO turn queue inside the runtime. If the client disconnects, crashes, or loses network connection during inference, the turn continues to completion and persists to the database. The client retrieves the completed state upon reconnecting.

### 2.2 Background Autostart at User Login (PC V1 — `PC-HOST-002`)

In accordance with Decision D2, [`ADR-0003`](../decisions/ADR-0003-d2-windows-host-model.md), and the October 11, 2026 Option A refinement:
- **Task Scheduler Registration (`PC-HOST-002`):** PC V1 provisions Windows Task Scheduler registration configured `At log on` of the user.
- **Dual Component Autostart:** Autostart at login launches both the Local AI Runtime (background host service) and the Flutter Desktop client (started minimized to the Windows System Tray).
- **Standard User Privileges:** The task executes strictly with standard user privileges without triggering User Account Control (UAC) elevation prompts.
- **Continuous Background Availability:** Autostart ensures that companion scheduling, proactive routines, and local LAN pairing endpoints are active immediately upon login, while the Flutter tray icon provides instant ambient access.
- **Intentional-Exit Restart Suppression:** If the user explicitly performs an intentional full exit via tray "Exit Companion", the application stays stopped until the next Windows user login or explicit manual relaunch.

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

1. **Flutter Desktop Client Integration (`ADR-0017` / `PC-CLIENT-002`):** Native Windows Flutter desktop client serving as the primary desktop experience, with system tray icon, window hide-on-close (`×` hides to tray), and background runtime status indicator.
2. **Task Scheduler Autostart at User Login (`PC-HOST-002`):** Dual startup of Local AI Runtime and Flutter Desktop (minimized to system tray) at user login via Windows Task Scheduler, respecting intentional-exit suppression.
3. **Host Administration Separation & Secure Lifecycle Authority (`PC-HOST-005`):** Dedicated local host administration mechanism providing secure lifecycle control, confirmed full runtime shutdown, owned model process draining, and tray "Exit Companion" execution without exposing shutdown authority over ordinary client API tokens.
4. **Native WinRT Toast Presentation (`PC-HOST-003` / `PC-CLIENT-012`):** Direct platform notification delivery for reminders, alarms, and routines.
5. **Runtime Durable Turn Queue (`ADR-0019` / `PC-API-004`):** Server-side turn queue persisting request processing across client disconnects.
6. **Resilient Scheduling & Wake Catch-up:** Persistent `SchedulerService` requesting OS timer wake for scheduled alarms and reconciling missed events upon wake.

---

## 5. Open Technical Details & Decision Debt

Detailed implementation choices for future planning are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Toast Interaction Actions:** Specific deep-linking buttons on Windows toast notifications (e.g., "Snooze 10m", "Mark Done", "Chat with Companion").
- **Wake Timer API Binding:** Evaluation of Windows kernel waitable timers (`CreateWaitableTimerExW` with `TIMER_ALL_ACCESS`) vs. power request APIs.
- **Notification Catch-up Aggregation Algorithm:** Precise grouping and batching heuristics for missed reminders when waking from multi-day sleep.
- **Pause Companion Mechanism:** Detailed state machine for pausing proactive/optional AI routines while keeping essential alarms active.

---

## 6. Security & Ownership Boundaries

- **Local Host Boundary (Decision D2):** The host runtime binds exclusively to loopback (`127.0.0.1`) by default, preventing unauthenticated remote LAN access to host administration endpoints.
- **Host Administration Separation (`PC-HOST-005`):** Ordinary client API pairing tokens authorize conversational and data endpoints, NOT host process termination. Host termination requires dedicated local OS administration authority.
- **User Permission Execution:** The runtime executes under the standard privileges of the logged-in Windows user account. It does **not** require elevated Windows Administrator privileges for day-to-day companion conversation, notification presentation, or autostart.
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

