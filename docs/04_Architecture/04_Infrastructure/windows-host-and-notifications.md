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
- **Window Close (`×`) / Hide to Tray:** Closing the desktop window or selecting "Hide to System Tray" minimizes/hides the visual UI to the Windows System Tray. Both the Flutter UI process and the Local AI Runtime host continue executing uninterrupted.
- **Unexpected UI Exit / Developer Quit UI Only:** If the Flutter UI crashes or the developer-only "Quit UI (Test Only)" action is invoked, the Flutter UI process exits while the Local AI Runtime remains independent, healthy, and executing. Relaunching or restarting Flutter attaches cleanly to the authenticated existing runtime (or safely starts it if absent).
- **Approved Full Exit ("Exit Companion" via System Tray — `PC-HOST-005` Planned):** The system tray menu provides an explicit "Exit Companion" action. Selecting this action triggers an explicit confirmation dialog warning that PC-hosted reminders, alarms, background work, and connected services will become unavailable. Upon user confirmation, it gracefully and securely stops the Flutter UI, the verified local runtime host, and its verified owned local inference engine processes (`llama-server.exe`). This capability is owned by `PC-HOST-005` (Host Administration Separation & Secure Lifecycle Authority) and requires secure local lifecycle authorization rather than an ordinary client bearer token.
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

Repository source code and test suites establish the verified baseline reality:

- **Runtime Supervision & Launch Coordinator (`PC-HOST-001` Delivered):**
  - **Supervisor & Coordinator Implementation:** Delivered via `WindowsRuntimeProcessSupervisor` (`frontend/flutter/apps/desktop/lib/platform/windows_runtime_process_supervisor.dart`) and `DesktopRuntimeCoordinator` (`frontend/flutter/apps/desktop/lib/coordinator/desktop_runtime_coordinator.dart`).
  - **Atomic Single-Instance Synchronization:** Cross-process synchronization is enforced by atomic kernel file locking on `%LOCALAPPDATA%\AI Companion\runtime.lock` using `FileMode.append` and `RandomAccessFile.lock(FileLock.exclusive)` with in-handle write-through (`setPosition(0)`, `truncate(0)`, `writeString(...)`, `flush()`), completely preventing truncation races. Double-checked locking re-verifies loopback port responsiveness immediately after acquiring the lock guard to eliminate duplicate process spawn races.
  - **Windowless Detached Process Execution:** Launches the Local AI Runtime detached via `ProcessStartMode.detached` using `pythonw.exe` from the active virtual environment. Windows runtime startup validates `pythonw.exe` availability and fails closed with an actionable diagnostic rather than silently falling back to console-visible `python.exe`.
  - **Rotating File Logging with Independent Secret Redaction:** Runtime process logging (`backend/app/core/logging.py`) writes directly to `%LOCALAPPDATA%\AI Companion\Logs\runtime.log` (via `COMPANION_LOG_FILE`) using `RotatingFileHandler` with `SanitizingFormatter`. `SanitizingFormatter` initializes independently of `sys.stdout`/`sys.stderr` presence, guaranteeing that authorization headers, tokens, and sensitive secrets are redacted under windowless execution.
  - **Windowless Inference Subprocess:** Inference engine (`backend/app/services/llm/llama_cpp.py`) launches `llama-server.exe` with `creationflags=subprocess.CREATE_NO_WINDOW` on Windows, preserving direct process invocation, exact PID ownership, single-resident model policy, model load/unload lifecycle, and crash isolation without popping up a console window.
  - **Authenticated Attach & Identity Separation:** Public `GET /api/v1/health` (HTTP 200) proves loopback reachability; authenticated attachment is completed only after `POST /api/v1/auth/verify` validates DPAPI pairing credentials and runtime identity. Supervision modes (`localLoopback` vs `remoteHost`) remain orthogonal to authentication status (`RuntimeStatus`).
  - **Process Safety & Untrusted PID Invariant:** Strictly avoids killing unverified PIDs; safe stale lock recovery detects dead PID descriptors and reclaims stale lockfiles; alien port conflicts fail closed (`RuntimeStatus.alienPortConflict`) without terminating foreign processes.
  - **Client Lifetime & System Tray Integration:** Flutter Desktop intercepts window close (`×`) via `window_manager` and hides to the Windows System Tray (`tray_manager`), keeping both UI and runtime alive and active ("Hide to Tray"). The developer-only test action `Quit UI Only (Test Only)` terminates the Flutter UI process only, leaving the Local AI Runtime alive and independent ("Quit UI != Stop Runtime"). System tray menu provides `Open AI Companion`, dynamic `Runtime Status` label (e.g. `Runtime: Active (PID 12345)`), `Hide to System Tray`, developer test `Quit UI Only (Test Only)`, and explicitly disabled `Exit Companion (Full Shutdown - Planned PC-HOST-005)` disclosing that confirmed full host shutdown of UI, host runtime, and owned inference engine requires dedicated local host administration authority.
  - **Settings Supervision Diagnostics:** Settings Diagnostics screen renders a dedicated "Runtime Process Supervision" card displaying supervision mode, status chip, PID, and lockfile path.
  - **Empirical Verification Evidence:** Automated PowerShell acceptance harness (`scripts/verify_windows_runtime_supervision.ps1`) verifies all 6 core lifecycle scenarios (dormant spawn, concurrent attach, UI exit survival, stale lock recovery, alien port conflict, lock contention) in isolated `$env:TEMP` environments on non-default ports; isolated inference validation (`scripts/verify_llama_windowless.py`) confirms windowless `llama-server.exe` execution and health; full Flutter desktop and backend test suites pass.

- **Current Implementation Gaps & Planned Boundaries:**
  - **Autostart Status (`PC-HOST-002`):** Windows host autostart at login is **NOT IMPLEMENTED / PLANNED**. Task Scheduler registration has not been provisioned in the repository.
  - **Host Administration Separation (`PC-HOST-005`):** Full host exit and runtime termination is **NOT IMPLEMENTED / PLANNED**. The tray menu action remains disabled with the planned label, and ordinary client API bearer tokens possess zero host termination authority.
  - **Self-Contained Installer & Bundled Runtime (`PC-HOST-006`):** Self-contained packaging of `AI Companion.exe`, `AI Companion Runtime.exe`, and `AI Companion Inference.exe` is **OPEN DESIGN / PLANNED** for PC V1 release preparation (`DEBT-V1-09`). The developer virtual environment remains the development baseline.
  - **Notification Adapter Status (`PC-HOST-003` / `PC-CLIENT-012`):** Native Windows notification presentation is **NOT IMPLEMENTED**. The codebase contains no WinRT Toast bindings.
  - **Native User Acceptance:** **PARTIALLY VERIFIED**. Generation-limit UI has been observed working on real Windows. LaTeX rendering has not yet been independently confirmed by Chris. Remaining interactive GUI checklist items must not be assumed passed until Chris confirms the manual checks.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the remaining Windows host infrastructure will provide:

1. **Task Scheduler Autostart at User Login (`PC-HOST-002`):** Dual startup of Local AI Runtime and Flutter Desktop (minimized to system tray) at user login via Windows Task Scheduler, respecting intentional-exit suppression.
2. **Host Administration Separation & Secure Lifecycle Authority (`PC-HOST-005`):** Dedicated local host administration mechanism providing secure lifecycle control, confirmed full runtime shutdown, owned model process draining, and tray "Exit Companion" execution without exposing shutdown authority over ordinary client API tokens.
3. **Self-Contained Windows Installer & Bundled Runtime (`PC-HOST-006` / `DEBT-V1-09`):** Bundled private Python execution environment, dependencies, Flutter Desktop, and native inference binaries (`AI Companion.exe`, `AI Companion Runtime.exe`, `AI Companion Inference.exe`) with transparent Task Manager visibility and zero console windows.
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

