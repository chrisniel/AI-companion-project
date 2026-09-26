# Tasks, Reminders, Alarms, and Routines Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.1).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** This document is authored as part of the staged documentation reconciliation. Primary canonical authority remains in [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§4 / §7, Decision D10) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

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
   - A time-critical, scheduled alert demanding immediate user awareness.
   - Possesses stronger delivery semantics than an ordinary informational Reminder.
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

Verified in `backend/app/api/v1/endpoints/tasks.py`:
- `GET /api/v1/tasks`: Lists active (non-deleted) tasks for the authenticated owner with optional status, priority, and category filters.
- `POST /api/v1/tasks`: Creates a new task.
- `GET /api/v1/tasks/trash`: Lists soft-deleted tasks residing in the Recycle Bin with dynamic `expires_in_days` calculation based on `DATA_RETENTION_DAYS = 30`.
- `GET /api/v1/tasks/{task_id}`: Retrieves a single active task by ID.
- `PATCH /api/v1/tasks/{task_id}`: Partially updates an active task.
- `DELETE /api/v1/tasks/{task_id}`: Soft-deletes a task (`is_deleted = True`, `deleted_at = now()`).
- `POST /api/v1/tasks/{task_id}/restore`: Restores a soft-deleted task back to active status.
- `DELETE /api/v1/tasks/{task_id}/permanent`: Permanently deletes a single soft-deleted task from the database.
- **Retention Purge Runner:** A standalone purge runner exists in `backend/app/services/retention.py` (`run_retention_purge_job` / `purge_expired_trash` callable via script or CLI); it is not automatically periodically scheduled by the application runtime.

### 3.3 Explicitly Unimplemented Capabilities

The following features have zero codebase runtime implementation:
- **Standalone Reminder Model & Runtime:** `NOT IMPLEMENTED` (reminders currently exist only as optional fields on `Task`).
- **Alarm Runtime & Acoustic Alert Engine:** `NOT IMPLEMENTED`.
- **Routine Scheduler & Bounded Proactive Triggers:** `NOT IMPLEMENTED`.
- **Native Windows Notification Adapter:** `NOT IMPLEMENTED` (alerts do not yet dispatch to Windows OS notification infrastructure).

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Decision D10 and scheduled for PC V1:

1. **Independent Scheduling Primitives (PC V1):**
   - Persistence must support the distinct Task, Reminder, Alarm, and Routine semantics, including standalone Reminders/Alarms where required.
   - Association mapping permitting Reminders to reference Task entities without requiring Tasks to own reminders. Exact table, model, and schema structures remain OPEN DESIGN.
2. **Native Windows OS Notification Adapter (PC V1):**
   - Native Windows notification delivery ensuring alerts trigger even when the browser client is closed. (Action Center / toast notifications represent an implementation candidate, not a permanent adapter contract.)
3. **Bounded Companion Routines (PC V1):**
   - Configurable routine schedules (morning greeting, daily check-in) triggered by the host supervisor.
   - Persona-directed phrasing generation respecting user activity context and quiet hours.
4. **Offline Missed-Event Catch-Up (PC V1):**
   - Upon system wake or backend restart, the scheduler evaluates missed reminders for catch-up and recovery. (Batching, deduplication, aggregation, suppression, and stale-event expiration policies remain OPEN DESIGN.)

---

## 5. OPEN DESIGN

The following implementation choices are intentionally left open for subsequent technical design:

- **Entity Persistence Schemas:** Relational table structures, foreign keys, or unified scheduling models for independent Reminders, Alarms, and Routines.
- **Lifecycle State Machines:** Exact transition graphs, event triggers, and states for acknowledgment, dismissal, snooze, and re-arm.
- **Scheduler Engine Selection:** Choice between lightweight in-process scheduler (`APScheduler`, asyncio task loop) versus OS-native timers.
- **Audio & Escalation Patterns:** Alarm ringtone selection, acoustic playback mechanisms, volume ramping, and visual alert overlays.
- **Quiet-Hour Alarm Policy:** Exact default handling when an Alarm falls inside quiet hours without explicit override flags.
- **Host Sleep & Wake Primitives:** Feasibility and mechanism of Windows waitable timers (`CreateWaitableTimerEx`) for best-effort wake.
- **Catch-Up & Stale Event Mechanics:** Batching, deduplication, summary aggregation, suppression windows, and expiration thresholds for missed events.

---

## 6. Security & Ownership Boundaries

- **Profile Ownership:** All Tasks, Reminders, Alarms, and Routines are strictly owned by the primary Profile (`owner_id`).
- **Cross-Character Invariant:** Characters do not own productivity data. Switching active character personas does not alter, hide, or reattribute task or schedule records.
- **Tool Execution Boundary:** LLM assistant access to task modification tools operates under deterministic profile policy; destructive permanent deletes require explicit user confirmation.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§4 / §7, Decision D10)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Task CRUD & Lifecycle Foundation, Reminder & Alarm Scheduling Foundation, Bounded Companion Routines)
- **Windows Host Infrastructure:** Planned R11.2 target `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`
- **UI Presentation Guidance:** [`docs/05_Design/README.md`](../../05_Design/README.md) (Schedule UI rendering rules)
