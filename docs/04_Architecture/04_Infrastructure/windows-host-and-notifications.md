# Windows Host and Notifications Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.2).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** Focused staged specification authored during R11.2. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Execution Baseline, Decisions D2, D10) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the host execution model, OS lifecycle integration, background persistence, and native notification dispatch for the AI Companion on Windows:
- Decoupled host runtime lifecycle independent of web browser tab lifetime.
- Autostart integration upon Windows user login.
- Native Windows desktop notification delivery for reminders, alarms, and routines.
- Post-sleep and offline reminder reconciliation semantics.
- Best-effort OS wake capabilities for scheduled companion alarms.
- Architectural boundary distinguishing PC V1 browser-based interaction from future post-V1 native desktop shells.

It governs the host infrastructure that keeps the companion alive, responsive, and punctual on the user's primary workstation.

---

## 2. Durable Architecture & Invariants

### 2.1 Host Runtime & Browser Lifecycle Independence (Decision D2)

In accordance with Decision D2:
- **Decoupled Lifecycle:** The Local AI Runtime operates as an independent background host service whose lifecycle is strictly decoupled from any web browser tab or client session.
- **Independent Existence:** Closing the React Web browser tab, refreshing the interface, or terminating the browser application does **not** stop, reset, or terminate the Local AI Runtime or its underlying model processes.
- **Client Disconnection Semantics:** While background timers, schedulers, and database state persist independently of the client, **active Server-Sent Events (SSE) token streams or HTTP requests terminate upon client disconnection**. A disconnected browser tab forfeits the in-flight display stream; however, backend transaction boundaries ensure committed user messages and background processes remain intact.
- **Native Desktop Shell Phasing:** A dedicated packaged native desktop shell (e.g., Tauri container) is classified as `APPROVED / PC LATER`. For PC V1, the primary user interface is React Web, accessed via standard browsers while the host runtime executes in the background.

### 2.2 Background Autostart at User Login (PC V1)

In accordance with the Feature Promotion Map (**Windows Host Autostart at Login**):
- **Approved Capability:** PC V1 includes automatic launch of the companion host runtime upon Windows user login.
- **Continuous Availability:** Autostart ensures companion scheduling, reminders, routines, and satellite Android sync readiness are immediately active without requiring manual terminal startup or browser launching.
- **User-Owned Control:** Autostart must remain user-configurable, allowing users to toggle automatic startup on or off via host configuration or desktop settings.

### 2.3 Native Windows Notifications & Offline Catch-up (PC V1)

In accordance with the Feature Promotion Map (**Native Windows Notifications** and **Reminder & Alarm Scheduling Foundation**):
- **Direct OS Notification Dispatch:** The Local AI Runtime dispatches notifications directly to the Windows notification system (e.g., Action Center / Toast alerts).
- **Client-Closed Delivery:** Native notifications ensure urgent alerts, scheduled reminders, and proactive companion check-ins reach the user even when the browser client is completely closed.
- **Offline & Sleep Catch-up:** When the host machine awakens from sleep, hibernation, or an offline period, the scheduling engine evaluates missed reminder triggers. Past-due reminders are presented in an intentional catch-up summary rather than generating an uncoordinated burst of overlapping alert chimes.
- **Policy Adherence:** Native notification delivery must strictly respect configured companion quiet hours, user mute preferences, and Windows Focus Assist / Do Not Disturb settings.

### 2.4 Best-Effort OS Alarm Wake Invariant

Scheduled companion alarms incorporate system wake capabilities, bounded by real-world hardware and OS invariants:
- **Best-Effort Wake Guarantee:** System wake from sleep or low-power states is strictly **best-effort**.
- **Hardware & Power State Limits:** System wake depends on host hardware support, ACPI sleep states (Modern Standby S0 vs. S3), firmware (BIOS/UEFI) configurations, power source (AC power vs. battery), and Windows OS power management policies.
- **No Absolute Wake Claim:** The architecture explicitly rejects any claim that the software can unconditionally wake a PC from every arbitrary sleep, hibernation, hybrid shutdown, or firmware-locked state. Where the OS denies or fails to execute a wake timer, the missed alarm triggers immediately upon subsequent user-initiated wake during catch-up evaluation.

---

## 3. Current Verified Implementation

Repository source code establishes the current baseline reality:

- **Launch Model:** The FastAPI backend is currently launched as a foreground terminal process (via uvicorn / Python scripts) listening on `127.0.0.1:8000`. Diagnostic standalone model probes are launched via PowerShell scripts (e.g., `scripts/start-model.ps1` invoking `llama-server.exe` on isolated diagnostic ports).
- **Autostart Status:** Windows host autostart at login is **NOT IMPLEMENTED**. No Windows Startup shortcut, Task Scheduler registration, native service wrapper, or registry Run key exists in the repository.
- **Notification Adapter Status:** Native Windows notification dispatch is **NOT IMPLEMENTED**. The current codebase contains no WinRT toast bindings, Win32 notification helpers, or system tray background dispatchers.
- **Client Lifetime Reality:** In current development, closing the browser tab leaves the backend uvicorn terminal process running (confirming process independence), but no OS-level alerts are generated if events occur while the browser is closed.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the Windows host infrastructure will provide:

1. **Host Supervisor Process:** A lightweight host supervisor managing Local AI Runtime startup, health monitoring, and graceful teardown during system shutdown.
2. **Autostart Registration:** A configurable installer/setup routine establishing an autostart hook at user login (e.g., Windows Startup folder entry or Task Scheduler trigger) targeting the host supervisor.
3. **Native Notification Dispatcher:** A platform-specific notification adapter in the backend or host helper that consumes scheduling events from the Tasks/Reminders domain and dispatches standard Windows Toast notifications with actionable dismiss/snooze controls.
4. **Resilient Scheduling Engine:** A persistent background clock checking for upcoming reminders, requesting Windows waitable timers (e.g., `CreateWaitableTimer` with resume capability) for alarms, and handling wake catch-up.

---

## 5. OPEN DESIGN

The following implementation mechanisms remain open design for future technical specification:

- **Autostart Mechanism Selection:** Specific Windows startup entry mechanism, evaluating alternatives such as:
  - Windows User Startup folder shortcut (`shell:startup`).
  - Windows Task Scheduler task triggered `At log on`.
  - Windows Background Service wrapper.
  - Dedicated lightweight native launcher utility.
- **Notification Library / Adapter:** Specific Windows notification dispatch mechanism, evaluating alternatives such as:
  - Windows Runtime (WinRT) Toast Notification APIs (`Windows.UI.Notifications`).
  - Native Python/C++ toast notification wrapper library.
  - Dedicated background system tray helper application mediating toast generation.
- **Alarm Wake Timer APIs:** Specific Windows kernel timer API binding (e.g., `SetWaitableTimer` with `fResume = TRUE`) and fallback policies across different Windows power plans.
- **System Tray Presence:** Inclusion and capabilities of a companion system tray icon for quick status, mute toggling, and manual runtime control prior to full native desktop shell adoption.

---

## 6. Security & Ownership Boundaries

- **Local Host Boundary (Decision D2):** The host supervisor and runtime bind exclusively to loopback (`127.0.0.1`) by default, preventing unauthenticated remote LAN access to host administration endpoints.
- **User Permission Execution:** The runtime executes under the standard privileges of the logged-in Windows user account. It does **not** require elevated Windows Administrator privileges for day-to-day companion conversation or notification dispatch.
- **Quiet-Hours & Notification Governance:** Native notifications must not bypass user-defined quiet hours or notification preferences. High-frequency automated routines are bounded to avoid notification fatigue.
- **Credential Storage:** Host runtime secrets, pairing tokens, and API credentials are kept in user-isolated configuration files (`backend/.env`) with restricted filesystem permissions.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Host execution baseline, Decision D2 (decoupled runtime), Decision D10 (Tasks & Reminders).
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Host asset paths, configuration files, and runtime environment.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md) — Scheduled reminder triggers, alarm definitions, and companion routine pacing.
- `docs/04_Infrastructure/runtime-and-models.md` *(planned)* — Local LLM inference server process management and GPU offloading.
- `docs/04_Infrastructure/performance-and-capacity.md` *(planned)* — Resource governance, gaming mode throttling, and background execution caps.
