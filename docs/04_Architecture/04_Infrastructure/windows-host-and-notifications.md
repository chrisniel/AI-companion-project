# Windows Host and Notifications Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

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
- **Decoupled Lifecycle:** The Local AI Runtime operates as an independent host runtime process whose lifecycle is strictly decoupled from any web browser tab or client session.
- **Independent Existence:** Closing the React Web browser tab, refreshing the interface, or terminating the browser application does **not** stop, reset, or terminate the Local AI Runtime or its underlying model processes.
- **Client Disconnection Semantics:** Browser/client disconnection does not terminate the Local AI Runtime, its background schedulers, or its model processes. A specific active HTTP request or Server-Sent Events (SSE) token stream is **not guaranteed to survive** client disconnection; transport or framework cancellation may terminate or cancel the in-flight request or stream. Already committed persistence remains governed by database transaction boundaries, ensuring committed user messages and background processes remain intact.
- **Native Desktop Shell Phasing:** A dedicated packaged native desktop shell (e.g., Tauri container) is classified as `APPROVED / PC LATER`. For PC V1, the primary user interface is React Web, accessed via standard browsers while the host runtime executes in the background.

### 2.2 Background Autostart at User Login (PC V1)

In accordance with the Feature Promotion Map (**Windows Host Autostart at Login**):
- **Approved Capability:** PC V1 includes automatic launch of the companion host runtime upon Windows user login.
- **Continuous Availability:** Autostart ensures companion scheduling, reminders, routines, and satellite Android sync readiness are immediately active without requiring manual terminal startup or browser launching.
- **Configuration UX Boundary:** User control over installation and startup configuration is desirable, but the exact control and settings UX remains OPEN DESIGN and design-owned.

### 2.3 Native Windows Notifications & Offline Catch-up (PC V1)

In accordance with the Feature Promotion Map (**Native Windows Notifications** and **Reminder & Alarm Scheduling Foundation**):
- **Direct OS Notification Dispatch:** The Local AI Runtime dispatches notifications directly to the Windows notification system (e.g., Action Center / Toast alerts as candidate implementations).
- **Client-Closed Delivery:** Native notifications ensure urgent alerts, scheduled reminders, and proactive companion check-ins reach the user even when the browser client is completely closed.
- **Offline & Sleep Catch-up:** When the host machine awakens from sleep, hibernation, or an offline period, the scheduling engine evaluates missed reminder triggers where appropriate. Exact catch-up policies (e.g., batching, deduplication, aggregation, suppression, and stale-event expiration) remain OPEN DESIGN.
- **Policy Adherence & Overrides:** Native notification delivery MUST obey the D10 quiet-hours policy and authorized per-item overrides. It must not bypass policy outside an allowed override. While quiet hours suppress applicable nonurgent delivery, individual Reminders, Alarms, and Routines may carry authorized per-item overrides. (The baseline urgency classification for Alarms relative to quiet hours remains OPEN DESIGN.)

### 2.4 Best-Effort OS Alarm Wake Invariant

Scheduled companion alarms incorporate system wake capabilities, bounded by real-world hardware and OS invariants:
- **Best-Effort Wake Guarantee:** System wake from sleep or low-power states is strictly **best-effort**.
- **Hardware & Power State Limits:** System wake depends on host hardware support, ACPI sleep states (Modern Standby S0 vs. S3), firmware (BIOS/UEFI) configurations, power source (AC power vs. battery), and Windows OS power management policies.
- **No Absolute Wake Claim:** The architecture explicitly rejects any claim that the software can unconditionally wake a PC from every arbitrary sleep, hibernation, hybrid shutdown, or firmware-locked state. Alarm wake is strictly best-effort without universal ACPI or firmware wake guarantees. Reminder catch-up occurs where appropriate upon subsequent system wake; however, the exact resolution behavior for a missed Alarm following a failed wake (including late delivery, suppression, expiration, escalation, or user notification semantics) remains an OPEN DESIGN question and is not silently classified as standard reminder catch-up.

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

1. **Independent Host Execution:** The runtime executes as a decoupled host process. (The exact hosting/supervision mechanism remains OPEN DESIGN; candidate approaches include a native launcher, Startup entry, Task Scheduler task, or background service wrapper.)
2. **Autostart at User Login:** An automatic launch hook established during setup/installation launching the host runtime upon Windows login.
3. **Native Notification Delivery:** Direct platform-appropriate notification delivery for reminders, alarms, and routines when the browser is closed. (The exact notification library, UI adapter, and interaction controls remain OPEN DESIGN.)
4. **Resilient Scheduling & Wake Catch-up:** A persistent scheduling mechanism that checks upcoming reminders, requests system wake for scheduled alarms on a best-effort basis, and reconciles missed reminders following sleep or downtime.

---

## 5. OPEN DESIGN

The following implementation mechanisms remain open design for future technical specification:

- **Hosting & Supervision Mechanism:** Specific Windows process hosting mechanism, evaluating alternatives such as:
  - Windows User Startup folder shortcut (`shell:startup`).
  - Windows Task Scheduler task triggered `At log on`.
  - Windows Background Service wrapper.
  - Dedicated lightweight native launcher utility.
- **Notification Library & Interaction Controls:** Specific Windows notification dispatch mechanism (e.g., WinRT `Windows.UI.Notifications`, a toast wrapper library, or a background system tray helper) and notification interaction controls (e.g., dismiss or snooze actions).
- **Notification Catch-up & Suppression Heuristics:** Specific algorithms for batching, aggregating, or suppressing stale reminder notifications following system wake or prolonged offline periods.
- **Missed Alarm Resolution Policy:** Specific behavior for a missed Alarm following a failed OS wake or downtime (e.g., whether to trigger late delivery, suppress stale alarm chimes, log expiration, trigger an escalated notification, or prompt the user with missed-alarm semantics).
- **Default Alarm Urgency & Quiet-Hours Classification:** Baseline urgency classification for Alarms relative to quiet-hours suppression and emergency overrides.
- **Autostart Configuration UX:** Design-owned user interface controls and configuration options for enabling or disabling automatic startup.
- **Alarm Wake Timer Strategy:** Specific Windows kernel timer API bindings (e.g., waitable timers with resume capability) and power plan fallback policies.
- **System Tray Presence:** Inclusion and capabilities of an optional companion system tray icon for quick status, mute toggling, and manual runtime control prior to full native desktop shell adoption.

---

## 6. Security & Ownership Boundaries

- **Local Host Boundary (Decision D2):** The host runtime binds exclusively to loopback (`127.0.0.1`) by default, preventing unauthenticated remote LAN access to host administration endpoints.
- **User Permission Execution:** The runtime executes under the standard privileges of the logged-in Windows user account. It does **not** require elevated Windows Administrator privileges for day-to-day companion conversation or notification dispatch.
- **Quiet-Hours & Notification Governance:** Native notification delivery MUST obey the D10 quiet-hours policy and authorized per-item overrides. It must not bypass policy outside an allowed override. High-frequency automated routines are bounded to avoid notification fatigue.
- **Credential Storage:** In current development reality, secrets and pairing tokens are stored in user-isolated local configuration files (`backend/.env`). Durable future credential and secret storage architecture is defined in the planned `docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md` domain.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Host execution baseline, Decision D2 (decoupled runtime), Decision D10 (Tasks & Reminders).
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Host asset paths, configuration files, and runtime environment.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md) — Scheduled reminder triggers, alarm definitions, and companion routine pacing.
- `docs/04_Infrastructure/runtime-and-models.md` *(planned)* — Local LLM inference server process management and GPU offloading.
- `docs/04_Infrastructure/performance-and-capacity.md` *(planned)* — Resource governance, gaming mode throttling, and background execution caps.
