# Tasks, Reminders, Alarms, and Routines Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.1).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** This document is authored as part of the staged documentation reconciliation. Primary canonical authority remains in [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) and [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the domain semantics, lifecycle models, scheduling rules, and delivery invariants for companion-managed productivity and scheduling primitives:
- Personal action items and tasks
- Standalone and task-associated notifications (Reminders)
- Time-critical scheduled acoustic/visual alerts (Alarms)
- Recurring proactive companion check-ins (Routines)

It governs the boundary between personal productivity state and autonomous scheduler behaviors under the PC Local AI Runtime.

---

## 2. Durable Architecture & Invariants

### 2.1 Distinct Conceptual Entities

Tasks, Reminders, Alarms, and Routines are architecturally distinct concepts governed by Decision D10:

1. **Task:**
   - A personal work, action, or tracking item owned by the user profile.
   - Owns a stateful completion lifecycle (e.g., progression from creation toward completion or cancellation).
   - May exist completely independently without any scheduled reminder or due date.
2. **Reminder:**
   - A notification intent scheduled for delivery at or before a specified timestamp.
   - May exist standalone (e.g., "remind me to stretch in 20 minutes") without an underlying Task.
   - May be associated with a Task to provide advance or deadline-driven alerting.
   - Supports offline catch-up and missed-event recovery when the host system wakes or resumes.
3. **Alarm:**
   - A time-critical, scheduled acoustic/visual alert demanding immediate user awareness.
   - Possesses stronger delivery semantics than an ordinary informational Reminder (e.g., persistent audio playback until explicit user acknowledgment).
   - Wake behavior from host sleep is strictly best-effort; architecture acknowledges there is no universal ACPI, OS, or firmware wake guarantee across all PC hardware.
4. **Routine:**
   - A bounded, recurring companion check-in or interaction pattern (e.g., morning overview, evening wind-down).
   - Governed by a deterministic scheduler that decides *when* and *what* intent triggers.
   - Companion character persona modulates *how* the resulting proactive check-in is phrased; the generative LLM does **not** possess unrestricted self-scheduling authority.

### 2.2 Quiet Hours Governance

- Quiet hours establish user-configured time windows that suppress non-urgent notification delivery.
- Reminders, Alarms, and Routines support per-item override configuration (e.g., an urgent medical reminder or morning alarm can bypass quiet hours).
- Architecture does **not** lock a universal automatic bypass default for all alarms; explicit configuration or item-level policy governs quiet-hour behavior.

### 2.3 Tool Execution & Policy Resolution (Decision D9)

When productivity tools are invoked via conversational or autonomous flows:
- Low-risk personal reads, creates, and updates **MAY** auto-execute when deterministic profile policy resolves to `ALLOW`.
- Policy outcomes evaluate deterministically to:
  - **`ALLOW`**: Execute automatically without interrupting the user.
  - **`CONFIRM`**: Require explicit user confirmation before state mutation.
  - **`DENY`**: Prohibit execution.
- Irreversible deletions, bulk modifications, or external communication actions mandate explicit confirmation.

---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Implemented Data Model & Storage

Tasks are persisted in SQLite via SQLAlchemy ORM (`app.models.task.Task`) and exposed via Pydantic v2 schemas (`app.schemas.task`):
- **Core Entity Fields:** `id` (UUIDv4), `owner_id` (String), `title` (String(255)), `notes` (Text, optional), `category` (String(32), indexed), `status` (String(32), indexed), `priority` (String(32), indexed), `due_date` (DateTime, optional), `reminder_minutes_before` (Integer, optional), `reminder_at` (DateTime, optional).
- **Audit & Soft-Delete Mixins:** `created_at`, `updated_at`, `is_deleted` (Boolean), `deleted_at` (DateTime, optional).
- **Current Verified Status Strings:**
  - `pending`
  - `in_progress`
  - `completed`
  - `cancelled`  
  *(Implementation fact: These status strings represent current database enum values. Durable architecture requires only a stateful completion lifecycle; these specific strings are not locked as permanent invariants.)*
- **Current Priority Ratings:** `low`, `medium`, `high`, `urgent`.
- **Current Categories:** `general`, `work`, `personal`, `dev`, `shopping`, `health`.

### 3.2 Implemented Endpoints & Operations

Verified in `app.api.v1.endpoints.tasks`:
- **CRUD Operations:** `GET /api/v1/tasks` (paginated, filtered by status/priority/category), `POST /api/v1/tasks`, `GET /api/v1/tasks/{id}`, `PATCH /api/v1/tasks/{id}`.
- **Soft-Delete Lifecycle:** `DELETE /api/v1/tasks/{id}` marks `is_deleted = True` and sets `deleted_at`.
- **Trash Management:** `GET /api/v1/tasks/trash` lists soft-deleted tasks with dynamic `days_remaining` retention calculation (default 30-day retention threshold).
- **Restoration & Purge:** `POST /api/v1/tasks/trash/{id}/restore`, `DELETE /api/v1/tasks/trash/{id}/purge` (permanent hard delete), and `DELETE /api/v1/tasks/trash` (empty trash).

### 3.3 Explicitly Unimplemented Capabilities

The following features have zero codebase runtime implementation:
- **Standalone Reminder Model & Runtime:** `NOT IMPLEMENTED` (reminders currently exist only as optional fields on `Task`).
- **Alarm Runtime & Acoustic Alert Engine:** `NOT IMPLEMENTED`.
- **Routine Scheduler & Bounded Proactive Triggers:** `NOT IMPLEMENTED`.
- **Native Windows Notification Adapter:** `NOT IMPLEMENTED` (alerts do not yet dispatch to Windows OS notification center).

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Decision D10 and scheduled for PC V1:

1. **Independent Scheduling Primitives (PC V1):**
   - Distinct persistence models for standalone Reminders and Alarms.
   - Association mapping permitting Reminders to reference Task entities without requiring Tasks to own reminders.
2. **Native Windows OS Notification Adapter (PC V1):**
   - Direct integration with Windows Action Center / toast notifications via background host runtime, ensuring alerts trigger even when browser client is closed.
3. **Bounded Companion Routines (PC V1):**
   - Configurable routine schedules (morning greeting, daily check-in) triggered by the host supervisor.
   - Persona-directed phrasing generation respecting user activity context and quiet hours.
4. **Offline Missed-Event Catch-Up (PC V1):**
   - Upon system wake or backend restart, the scheduler evaluates missed reminders and delivers an aggregated summary rather than firing bursts of obsolete notifications.

---

## 5. OPEN DESIGN

The following implementation choices are intentionally left open for subsequent technical design:

- **Entity Persistence Schemas:** Relational table structures for independent Reminders, Alarms, and Routines.
- **Lifecycle State Machines:** Exact transition graphs and event triggers for snooze, re-arm, and acknowledgment.
- **Scheduler Engine Selection:** Choice between lightweight in-process scheduler (`APScheduler`, asyncio task loop) versus OS-native timers.
- **Audio & Escalation Patterns:** Alarm ringtone playback mechanism, volume ramping, and multi-monitor visual alert overlays.
- **Quiet-Hour Alarm Policy:** Exact default handling when an Alarm falls inside quiet hours without explicit override flags.
- **Host Sleep & Wake Primitives:** Feasibility of Windows waitable timers (`CreateWaitableTimerEx`) for best-effort wake.

---

## 6. Security & Ownership Boundaries

- **Profile Ownership:** All Tasks, Reminders, Alarms, and Routines are strictly owned by the primary Profile (`owner_id`).
- **Cross-Character Invariant:** Characters do not own productivity data. Switching active character personas does not alter, hide, or reattribute task or schedule records.
- **Tool Execution Boundary:** LLM assistant access to task modification tools operates under deterministic profile policy; destructive purges require explicit user confirmation.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decision D10)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Rows 58, 59, 60)
- **Windows Host Infrastructure:** [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md) (Target destination for OS toast delivery)
- **UI Presentation Guidance:** [`docs/05_Design/README.md`](../../05_Design/README.md) (Schedule UI rendering rules)
