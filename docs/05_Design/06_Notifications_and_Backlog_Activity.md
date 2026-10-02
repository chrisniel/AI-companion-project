# Notifications & Backlog Activity Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md), [`windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md), [`ADR-0011`](../04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md).

---

## 1. Overview & Notification Philosophy

Notifications ensure that companion alerts, scheduled reminders, urgent alarms, and proactive daily check-ins reach the user reliably on Windows, even when the desktop client window is minimized or closed. The interaction design enforces a clear visual hierarchy based on urgency and respects quiet-hours boundaries.

---

## 2. Notification Urgency Hierarchy & Native Toasts

In accordance with Decision D10, notifications are categorized into three distinct presentation styles:

### 2.1 Alarms (High Urgency)
- **Visual Presentation:** Persistent Windows Toast alert featuring a high-contrast red/amber accent, companion avatar, and prominent title (e.g., *"Alarm: Morning Medication"*).
- **Audible Behavior:** Loops a distinct, polite audio chime until dismissed or snoozed.
- **Quiet-Hours Bypass:** **Bypasses quiet hours by default**, ringing audibly and visually unless explicitly silenced by hardware mute.
- **Interactive Actions:**
  - `[ Snooze 10m ]` (Secondary button)
  - `[ Dismiss ]` (Primary button)

### 2.2 Reminders (Standard Urgency)
- **Visual Presentation:** Standard Windows Toast alert featuring theme accent color and task description (e.g., *"Reminder: Call Dentist at 2:00 PM"*).
- **Audible Behavior:** Single subtle notification chime.
- **Quiet-Hours Policy:** Respects quiet hours by default (delivered silently to Action Center without banner or chime during quiet hours).
- **Interactive Actions:**
  - `[ Mark Done ]` (Completes the associated task in SQLite)
  - `[ Snooze 10m ]` (Reschedules trigger)

### 2.3 Routines & Proactive Check-Ins (Informational Urgency)
- **Visual Presentation:** Subtle, non-intrusive toast alert (e.g., *"Good morning! You have 3 tasks scheduled for today."*).
- **Audible Behavior:** Silent or soft audio cue.
- **Quiet-Hours Policy:** Strictly suppressed during quiet hours.
- **Interactive Actions:**
  - `[ Open Chat ]` (Restores main window to conversational view)

---

## 3. In-App Notification Center & Backlog Activity Drawer

Located via a bell icon in the top header of the desktop shell:
- **Badge Counter:** Shows unread/missed alerts count.
- **Flyout Drawer:** Slides out from the right margin:
  - **Missed Reminders (Sleep Catch-up):** Grouped summary banner of events that occurred while the PC was asleep or offline (e.g., *"3 reminders caught up from sleep"*).
  - **Today's Timeline:** Chronological list of completed, pending, and snoozed items.
  - **"Clear All" & "Filter by Profile":** Controls allowing quick pruning and profile-specific scoping.

---

## 4. Quiet-Hours Settings UI

Located in Settings $\rightarrow$ Notifications:
- **Quiet-Hours Range:** Visual time picker (default: `10:00 PM` to `7:00 AM`).
- **Emergency Overrides:** Per-item toggle on individual Reminders allowing specific critical tasks to break through quiet hours.
- **Alarm Default Notice:** Explanatory banner confirming: *"Alarms bypass quiet hours by default to ensure wakefulness."*
