# Tasks, Reminders, Alarms, and Routines Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0011, ADR-0018)
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for tasks, reminders, alarms, and routines.

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

### 2.1 Distinct Conceptual Entities (Decision D10 & ADR-0011)

Tasks, Reminders, Alarms, and Routines are architecturally distinct concepts governed by Decision D10:

1. **Task:**
   - A personal work, action, or tracking item owned by the user profile (`profile_id`).
   - Owns a stateful completion lifecycle (e.g., progression from creation toward completion or cancellation).
   - May exist completely independently without any scheduled reminder or due date.
2. **Reminder:**
   - A notification intent scheduled for delivery at or before a specified timestamp.
   - May exist standalone (e.g., "remind me to stretch in 20 minutes") without an underlying Task.
   - May be associated with a Task to provide advance or deadline-driven alerting.
   - Supports offline catch-up and missed-event recovery when the host system wakes or resumes.
   - Respects quiet hours by default, with per-item override configuration.
3. **Alarm:**
   - A time-critical, scheduled alert demanding immediate user awareness (visual and acoustic).
   - Possesses stronger delivery semantics than an ordinary informational Reminder.
   - **Quiet Hours Default:** Alarms **bypass quiet hours by default** due to their urgent nature, unless explicitly configured to respect quiet hours.
   - Wake behavior from host sleep is strictly best-effort; architecture acknowledges there is no universal ACPI, OS, or firmware wake guarantee across all PC hardware.
4. **Routine:**
   - A bounded, recurring companion check-in or interaction pattern (e.g., morning overview, evening wind-down).
   - Governed by a deterministic `SchedulerService` in the Local AI Runtime that decides *when* and *what* intent triggers.
   - Companion character persona modulates *how* the resulting proactive check-in is phrased; the generative LLM does **not** possess unrestricted self-scheduling authority.
   - Respects quiet hours by default.

### 2.2 Quiet Hours Governance

- Quiet hours establish user-configured time windows that suppress non-urgent notification delivery.
- Reminders and Routines respect quiet hours by default; Alarms bypass quiet hours by default.
- Per-item explicit override flags allow users to customize quiet-hour behavior for any individual alert.

### 2.3 Tool Execution & Policy Resolution (Decision D9)

When productivity tools are invoked via conversational or autonomous flows:
- Low-risk personal reads, creates, and updates **MAY** auto-execute when deterministic profile policy resolves to `ALLOW`.
- Policy outcomes evaluate deterministically to:
  - **`ALLOW`**: Execute automatically without interrupting the user.
  - **`CONFIRM`**: Require explicit user confirmation before state mutation.
  - **`DENY`**: Prohibit execution.
- Irreversible deletions, bulk modifications, or external communication actions mandate explicit confirmation.

---

### 2.4 Shared Scheduling Authority & Stable Client Identity (`D-SHARED-SCHED-01`)

The separation of scheduling truth, entity identity, and presentation is strictly defined across PC Host and Mobile clients:

- **Synchronized Scheduling Authority:** The owning Profile owns synchronized scheduling entities. The PC Host and its background Local AI Runtime `SchedulerService` act as the canonical synchronized scheduler authority for the Profile, owning the central notification backlog and canonical Routine definitions/recurrence truth. Mobile maintains durable locally authoritative provisional state within its approved offline mutation authority for Mobile-origin Reminders and Alarms. On reconnection, Host revision and reconciliation semantics apply. Host-origin definitions remain read-only on Mobile while disconnected.
- **Stable UUID Identity (`D-SHARED-SCHED-01`):** Every synchronizable scheduling entity (Tasks, Reminders, Alarms, Routines, and alert occurrences) possesses a stable UUID identity. Mobile-created entities use stable client-generated UUIDs (UUIDv4) accepted by the Host upon reconciliation, without temporary or client-provisional IDs that require re-keying upon sync. Host-created entities retain stable Host-issued UUID identities.
- **Profile Ownership vs. Device Provenance:** Entities belong strictly to the owning Profile (`profile_id`), never to client devices. Device origin is recorded as provenance metadata determining offline authoring and mutation privileges (e.g. Mobile-origin vs. Host-origin). Synced Mobile-created Reminders and Alarms survive client device revocation as durable Profile data.
- **Mutation Idempotency:** Operational mutations in the local outbox use an independent UUID `mutation_id` (Idempotency Key) to ensure network retry idempotency without duplicate executions.

### 2.5 Offline Mobile-Origin Reminders & Alarms (`D-PHONE-10`, `D-PHONE-11`)

The Mobile Companion provides robust standalone scheduling functionality when disconnected from the PC Host:

- **Mobile-Origin Reminders (`D-PHONE-10`):** Reminders authored on the mobile device may be fully created, edited, canceled, locally scheduled, delivered, dismissed, or snoozed while offline.
- **Mobile-Origin Alarms (`D-PHONE-11`):** Alarms authored on the mobile device may be fully created, edited (including recurrence schedules), armed locally with `AlarmManager`, delivered, dismissed, or snoozed while offline.
- **Host-Origin Definition Protection:** Scheduled definitions created on the PC Host remain strictly **read-only** on Mobile while disconnected. Mobile may receive and present bounded replicated occurrences, and record occurrence dismissals or snoozes, but cannot alter recurrence rules or definitions of Host-origin items while offline. Connected Mobile may manage Host-origin definitions via Host APIs under Decision D9 tool governance.
- **Reconciliation & Duplicate Prevention:** Upon reconnection, offline mutations flush via the outbox journal. The Host detects and reconciles deliveries, preventing duplicate alerts from firing on previously silent devices.

### 2.6 Cross-Device Alert Presentation Arbitration (`D-SHARED-SCHED-02`)

When the PC Host and Mobile device are connected, the Host arbitrates alert presentation across endpoints:

- **Reminders (Duplicate Suppression Priority):** Reminders favor duplicate suppression. A designated primary device presents the notification; secondary devices remain silent or retain a synchronized passive entry. If the primary device fails to present or becomes unreachable, the secondary device takes over presentation.
- **Alarms (Reliability & Waking Awareness Priority):** Alarms prioritize delivery reliability over duplicate suppression:
  1. The primary device rings and presents first.
  2. The standby device remains locally armed.
  3. Explicit user acknowledgment, dismissal, or snooze commits an immediate mutation that propagates across devices to dismiss or re-arm the standby device.
  4. **Passive Display != Acknowledgment:** Passive display on one device (e.g. an unattended PC displaying a toast notification) does NOT count as user acknowledgment and MUST NOT silence or cancel a ringing alarm on Mobile.
  5. **Standby Escalation:** If the primary alarm is not explicitly acknowledged within a bounded grace window, the standby device escalates into active ringing.
- **Arbitration Policies:** Default automatic arbitration evaluates client reachability, active client focus, recent user interaction, and device permissions. Policy directions conceptually include:
  - *Reminders (Duplicate Suppression Priority):* `Automatic`, `Prefer PC`, `Prefer Phone`, `Both`.
  - *Alarms (Reliability Priority):* `Automatic with fallback`, `Prefer PC`, `Prefer Phone`, `Ring all available devices`.
  (Exact final UI labels remain design-open; policies reflect distinct underlying architectural priorities).
- **Disconnected Fallback Rule:** When cross-device coordination is severed due to network disruption or Host unavailability, **a duplicate Alarm is explicitly preferred over a missed Alarm**.

### 2.7 Companion Alert Enrichment & Deterministic Fallback (`D-SHARED-SCHED-03`)

- **Occurrence Authority:** Scheduled occurrence triggering is authoritative and strictly deterministic. Ringing, chime, and native notification display are deterministic platform events.
- **Optional Presentation Enrichment:** Companion personality, character speech, and TTS are optional presentation enrichments.
- **Zero Trigger Delay:** Generative language model execution or TTS synthesis MUST NEVER delay, reschedule, or suppress the physical alarm trigger. If enrichment generation is slow, uninitialized, or fails, immediate deterministic acoustic and visual alert presentation proceeds without delay.
- **Enrichment Ownership:** The primary presenter delivers companion voice/enrichment by default; standby devices deliver vocal enrichment only upon escalation. Active Character persona and Mood affect alert tone and phrasing, never schedule timing or delivery invariants.

### 2.8 Replicated Routine Occurrences & Offline Constraints (`D-PHONE-12`, `12A`, `12B`, `12C`)

Routines represent proactive companion check-ins governed by strict capability envelopes:

- **Host Scheduling Authority (`D-PHONE-12`):** The PC Runtime `SchedulerService` owns canonical Routine definitions and recurrence rules. While disconnected, Mobile caches and presents a bounded horizon of Host-authorized occurrences (exact horizon remains implementation-open). Mobile does NOT autonomously extend recurrence rules once cached occurrences elapse.
- **Routine Presentation Enrichment (`D-PHONE-12A`):** Qualified local model or TTS capabilities may personalize the proactive Routine greeting using permitted cached context and active Character persona. Deterministic template fallback is mandatory; generation never owns the trigger.
- **Connected Authoring Only (`D-PHONE-12B`):** Connected Mobile may manage Routines via Host APIs under Decision D9 Risk-2 confirmation policy. Offline Mobile V1 CANNOT create canonical Routines, materially edit recurrence rules, expand capability envelopes, or alter permissions.
- **Device-Local Suppression & Disable Request (`D-PHONE-12C`):** A user may pause or suppress Routine presentation locally on Mobile while offline without silently rewriting the Host's canonical Routine definition. A user request to disable or cancel the Routine everywhere is enqueued as a pending Host mutation in the outbox for reconciliation upon reconnect.
- **Missed Routine Policy:** Stale Routine occurrences skip, collapse, or catch up once upon reconnect or resume; the scheduler never replays an avalanche of stale missed routines.

### 2.9 Temporal Intent Resolution & Parity (`D-SHARED-SCHED-04..04E`)

Natural language scheduling is processed through a structured pipeline to prevent generative model hallucination:

1. **Structured Pipeline (`D-SHARED-SCHED-04`):**
   ```text
   User Natural Language
   → Model Extracts Typed Temporal Intent
   → Deterministic Resolver Parses & Validates
   → D9 Policy Evaluates
   → Committed Schedule Entity
   ```
   The language model proposes typed intent; the deterministic resolver and runtime scheduler own calendar truth.
2. **Field-Level Ambiguity & Clarification (`D-SHARED-SCHED-04A`):** The system clarifies only material unresolved fields. Exact low-risk requests execute under D9 `ALLOW` without redundant confirmation. Vague phrases (e.g. "later", "in a bit") require clarification unless a deterministic user preference exists.
3. **Timezone & Recurrence Semantics (`D-SHARED-SCHED-04B`):**
   - *Fixed-Instant Events:* Invariant UTC timestamps (e.g., "meeting at 3 PM UTC").
   - *Floating Local-Time Recurrence:* Bound to local wall-clock time wherever the user is (e.g., "wake me at 7 AM every weekday"). Reconciles locally when timezones change.
   - *Fixed-Timezone Recurrence:* Bound to a specific timezone regardless of user travel (e.g., "team sync at 9 AM EST").
4. **Alarm Strictness (`D-SHARED-SCHED-04C`):** Alarms mandate stricter resolution than reminders. Material ambiguity in date, time, AM/PM, recurrence, or timezone must be resolved before an Alarm is armed.
5. **Cross-Platform Temporal Parity (`D-SHARED-SCHED-04D`):** The identical scheduling phrase and timezone context must produce equivalent structured schedules on both PC and Mobile. Parity is enforced via machine-readable Golden test vectors.
6. **Context Clarification Priority Hierarchy (`D-SHARED-SCHED-04E`):**
   ```text
   1. Explicit current instruction
   2. Current conversation context
   3. Configured scheduling preferences
   4. Verified Profile Memory
   5. Repeated historical patterns (suggestions only; not automatic memory)
   6. Relevant summaries / history
   7. Explicit clarification with the user
   ```

### 2.10 Missed Events & Snooze Semantics

- **Reminders:** Missed reminders evaluate against a bounded useful catch-up window; stale events expire gracefully without cluttering the user with obsolete notifications.
- **Alarms:** Missed alarms surface an explicit "Missed Alarm" status; configurable grace may trigger immediate alerting if within the active wake window.
- **Snooze Semantics:** Snoozing mutates the active occurrence state to `SNOOZED`, computes a new trigger time, and re-arms a one-shot timer/alarm. It does NOT duplicate the parent entity.

### 2.11 Scheduler & OS Presentation Boundaries

- **Windows Desktop:** Local AI Runtime persists due events and backlog; the Flutter desktop client owns Windows Toast notification presentation. If the desktop app is closed, the Runtime continues tracking events and presents catch-up toasts upon next launch.
- **Android Mobile:** Replicated occurrences schedule native Android alerts via `AlarmManager.setAlarmClock()` (exact alarms) or `AlarmManager.setAndAllowWhileIdle()` / WorkManager (inexact reminders), respecting Doze modes and `canScheduleExactAlarms()` permission state (`mobile-offline-and-sync.md` §5, §6).

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

### 3.2 Implemented Task Endpoints & Operations

Verified in `backend/app/api/v1/endpoints/tasks.py`:
- `GET /api/v1/tasks`: Lists active (non-deleted) tasks for the authenticated profile with optional status, priority, and category filters.
- `POST /api/v1/tasks`: Creates a new task.
- `GET /api/v1/tasks/trash`: Lists soft-deleted tasks residing in the Recycle Bin with dynamic `expires_in_days` calculation based on `DATA_RETENTION_DAYS = 30`.
- `GET /api/v1/tasks/{task_id}`: Retrieves a single active task by ID.
- `PATCH /api/v1/tasks/{task_id}`: Partially updates an active task (cancels open linked Reminders and active task/reminder notifications when transitioned to `completed` or `cancelled`).
- `DELETE /api/v1/tasks/{task_id}`: Soft-deletes a task (`is_deleted = True`, `deleted_at = now()`) and cancels open linked Reminders and active task/reminder notifications.
- `POST /api/v1/tasks/{task_id}/restore`: Restores a soft-deleted task back to active status.
- `DELETE /api/v1/tasks/{task_id}/permanent`: Permanently deletes a single soft-deleted task from the database.
- **Retention & Memory Expiration Sweeps:** `backend/app/services/retention.py` (`run_retention_purge_job` / `purge_expired_trash`) provides standalone retention purging, while `SchedulerService.sweep_expired_memories()` periodically soft-deletes expired temporary memories (`DEBT-V1-08`).

### 3.3 Implemented Reminders, Alarms, Routines, Quiet Hours & `SchedulerService` (M3 Batch G1)

Delivered on branch `feature/m3-scheduler-notifications-g1` (Alembic Migration `015_scheduler_notifications_and_routines`):
- **ORM Persistence & Profile Purge:** `Reminder` (`app.models.reminder`), `Alarm` (`app.models.alarm`), `Routine` (`app.models.routine`), `NotificationEvent` (`app.models.notification_event`), and per-Profile Quiet Hours columns (`quiet_hours_enabled`, `quiet_hours_start`, `quiet_hours_end`, `quiet_hours_timezone`) on `Profile` (`app.models.profile`). `ProfilePurgeService` deletes all scheduling and notification entities in FK dependency order and applies `DATA_RETENTION_DAYS` retention cleanup.
- **Deterministic Runtime Engine (`app.services.scheduler.service.SchedulerService`):**
  - Zero-dependency `resolve_timezone()` / `_RuleBasedTzInfo` fallback supporting standard IANA timezones (e.g., `UTC`, `Asia/Manila`, `America/*`, `Europe/*`) on Windows Python builds lacking the optional `tzdata` package.
  - Half-open `[start, end)` Quiet Hours evaluation (supporting both same-day and overnight spans): Reminders and Routines suppress delivery notifications (`suppressed_quiet_hours`) unless `bypass_quiet_hours=True`, while Alarms bypass quiet hours by default (`bypass_quiet_hours=True`).
  - Startup missed-event catch-up reconciliation (`reconcile_missed_events`) distinguishing bounded grace windows from expired missed items (`missed` / `missed_catchup`), recurring Alarm next-occurrence auto-re-arming (`compute_next_occurrence`), Snooze re-triggering (`snoozed_until`), deterministic Routine `fallback_message` emission with zero LLM trigger delay, `Task.reminder_at` due-reminder notification bridging with deduplication (`ix_notification_events_dedup`), and `DEBT-V1-08` expired temporary memory soft-deletion sweeps wired into FastAPI `lifespan` (`app/main.py`).
- **Profile-Scoped REST API & Task Synchronization (`app/api/v1/endpoints/scheduling.py`, `profiles.py`, `tasks.py`):**
  - `GET`/`PATCH /api/v1/profiles/me/quiet-hours`
  - Reminders CRUD + lifecycle (`/api/v1/reminders`, `/{id}`, `/{id}/snooze`, `/{id}/acknowledge`, `/{id}/dismiss`), supporting explicit client-generated UUIDv4 IDs (`409 Conflict` on duplicate ID) and `[ Mark Done ]` (`complete_task=True`) Task completion sync.
  - Alarms CRUD + lifecycle (`/api/v1/alarms`, `/{id}`, `/{id}/snooze`, `/{id}/acknowledge`, `/{id}/dismiss`), re-arming enabled recurring weekday alarms after acknowledge/dismiss.
  - Routines CRUD + immediate manual trigger (`/api/v1/routines`, `/{id}`, `/{id}/run`).
  - Notification Backlog CRUD + lifecycle (`/api/v1/notifications`, `/clear-all`, `/{event_id}/read`, `/{event_id}/acknowledge`, `/{event_id}/dismiss`, `/{event_id}/snooze`) syncing action resolution back to source Reminders, Alarms, and Task reminders.
  - Updating a `Task` to `completed`/`cancelled` or soft-deleting it cancels open linked `Reminder` rows and resolves active task/reminder `NotificationEvent` backlog entries.
- **OpenAPI & `companion_api` Dart SDK Parity:** All 38 Task, Quiet Hours, Reminder, Alarm, Routine, and Notification Backlog routes plus 25 Dart DTO schemas (`task_dto.dart`, `scheduling_dto.dart`) are verified against `contracts/openapi/openapi.json` via `scripts/check_dart_openapi_parity.py`.

- **Batch G1 Review Follow-Up Folded Into M3 Batch G2:** `update_alarm` in `backend/app/api/v1/endpoints/scheduling.py` recomputes `scheduled_at` on `time_of_day`, `recurrence_days`, `timezone`, or re-arm `enabled` updates for armed recurring alarms and enforces `422 Unprocessable Content` when `recurrence_days` is non-empty without `time_of_day` (`NIT-01`).

### 3.4 Implemented Desktop Schedule Workspace & Native Windows Toasts (M3 Batch G2)

Implemented and verified on branch `feature/m3-schedule-ui-windows-toasts-g2`:
- **Flutter Desktop Schedule & Routines Workspace (`PC-CLIENT-008`):** Replaced the `ScheduleScreen` placeholder and removed the `'M3'` planned badge on `DesktopNavDestination.schedule`. Implemented the responsive Option 2A 5-section workspace (`Tasks` + `Trash` 30-day restore/permanent delete view with overdue indicators & quick offset chips, `Reminders`, `Alarms` with live toggle switch & recurrence labels, `Routines` with deterministic `[ Run Now ]`, and `Notifications` backlog history with safe `Mark All Read`) backed by `DesktopScheduleController`, `ScheduleSidebar`, `ScheduleEditDialogs`, and `QuietHoursSettingsCard` inside `SettingsScreen`.
- **Per-Item Center Pop-Up Control & Safe `Mark All Read` (`016_reminder_center_popup`):** Added Alembic Migration `016_reminder_center_popup` introducing `reminders.center_popup` and `tasks.reminder_center_popup` (both defaulting to `True`). `SchedulerService` propagates these flags to `NotificationEvent.urgency` (`"high"` when `True`, `"standard"` when `False`), replacing any global Settings switch with per-reminder / per-task `Center Pop-Up Alert` switches in `ScheduleEditDialogs` (while Alarms always stay modal). Added `POST /api/v1/notifications/mark-all-read` to set `read_at` across unread rows and transition non-alarm unresolved rows to `read` while keeping ringing alarms in `unread` and preserving all audit/backlog history.
- **Native In-Process C++/WRL WinRT Toast Channel & Two-Way Interactive Sync (`PC-CLIENT-012` / `DEBT-V1-02`):** Implemented `WindowsToastChannel` (`frontend/flutter/apps/desktop/windows/runner/windows_toast_channel.h/.cpp`, explicit AUMID `AICompanion.Desktop`) wired into `FlutterWindow` (`MethodChannel('ai_companion/windows_notifications')`) and `WindowsWinRtToastAdapter` (`windows_toast_adapter.dart`). Dispatches interactive Windows Action Center toasts (`Stop` / `Mark Done` / `Got it`, `Snooze 10m`, `Dismiss`, `Open Chat`, `Review Backlog`) with UI-thread `Activated` message handling, `PlaySoundW` chimes, window foreground restore, Win32 `isWindowFocused` multi-monitor focus detection (skipping redundant OS toasts while focused and falling back to in-app chimes), `suppressPopup` Quiet Hours compliance, consolidated Sleep Catch-up summary toast, and bidirectional Action Center toast removal (`removeToast`/`clearToasts`) synchronized with `DesktopShell`'s click-outside/`Escape`-dismissible Bell Active Inbox (`NotificationBacklogDrawer` + `History` shortcut) and tiered in-app alerts (`shell_center_alert_modal` vs. floating top-right `shell_active_alert_banner`).
- **M5 Batch A Scheduling Tool Localization & D10 Low-Impact Deferral (`adapters_productivity.py`, `scheduler/service.py`):** Scheduler D9 tools (`list_tasks`, `list_reminders`, `list_alarms`, `create_reminder`, `create_alarm`) format natural localized `*_local` summaries in the user's Profile timezone while preserving raw ISO-8601 fields (`scheduled_at`, `due_at`), with `run_create_alarm` passing `tz_name=tz_name` to `compute_next_occurrence`. During `ResourceGovernor` `Low-Impact` mode, `SchedulerService` defers periodic memory expiration sweeps and non-bypass `Routine` execution (`bypass_quiet_hours=False`) while strictly preserving Alarms, Reminders, and Task due-reminder notifications per Decision D10.

### 3.5 Explicitly Unimplemented Capabilities (Remaining M4+)

The following capabilities remain outside Batch G1/G2 runtime and desktop implementation:
- **Alarm Acoustic Playback Ramping & Windows Waitable Wake Timers (`CreateWaitableTimerExW`):** **NOT IMPLEMENTED** (best-effort timer wake remains future host enhancement).
- **LLM Conversational Scheduling Tool-Calling (Decision D9 Pipeline):** **NOT IMPLEMENTED** (Milestone M4).
- **Mobile Offline Outbox & Cross-Device Alert Arbitration (`D-SHARED-SCHED-02`):** **NOT IMPLEMENTED** (Mobile V1 follow-on track).

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved across PC V1 and Mobile Companion architecture:

1. **Independent Scheduling Primitives (PC V1):**
   - Persistence must support distinct Task, Reminder, Alarm, and Routine semantics, including standalone Reminders/Alarms where required.
   - Association mapping permitting Reminders to reference Task entities without requiring Tasks to own reminders. Exact table, model, and schema structures remain OPEN DESIGN.
2. **Native Windows OS Notification Adapter (PC V1):**
   - Native Windows notification delivery ensuring alerts trigger even when the browser client is closed. (Action Center / toast notifications represent an implementation candidate, not a permanent adapter contract.)
3. **Bounded Companion Routines (PC V1 & Mobile):**
   - Configurable routine schedules (morning greeting, daily check-in) triggered by the host supervisor.
   - Persona-directed phrasing generation respecting user activity context and quiet hours.
   - Bounded Host-authorized future occurrence replication and caching on Mobile (`D-PHONE-12`, `D-PHONE-12A`).
4. **Offline Missed-Event Catch-Up (PC V1):**
   - Upon system wake or backend restart, the scheduler evaluates missed reminders for catch-up and recovery. (Batching, deduplication, aggregation, suppression, and stale-event expiration policies remain OPEN DESIGN.)
5. **Offline Mobile-Origin Reminders & Alarms (`D-PHONE-10`, `D-PHONE-11`):**
   - Client-generated stable UUID identities for offline-created Reminders and Alarms (`D-SHARED-SCHED-01`).
   - Local scheduling, delivery, and management on Mobile while disconnected; outbox flush and duplicate-free reconciliation on reconnect.
6. **Cross-Device Alert Presentation Arbitration (`D-SHARED-SCHED-02`):**
   - Primary/secondary arbitration coordinator on PC Host.
   - Reminder duplicate suppression across devices; Alarm reliability-first delivery with armed standby and bounded escalation.
7. **Companion Alert Enrichment (`D-SHARED-SCHED-03`):**
   - Deterministic trigger authority decoupled from optional generative speech enrichment; immediate fallback on generation delay.
8. **Temporal Intent Resolution Pipeline (`D-SHARED-SCHED-04..04E`):**
   - Natural language temporal intent parsing, field-level ambiguity clarification, and deterministic resolution.
   - Parity across PC Python and Mobile Dart verified via shared Golden test vectors.

---

## 5. Implementation-Open Details (Decision Debt)

The normative architecture for D10 is frozen. The following implementation-level details are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Scheduler Engine Selection (`DEBT-V1-009`):** Batch G1 implemented the lightweight in-process `asyncio` `SchedulerService` in `backend/app/services/scheduler/service.py` wired into FastAPI `lifespan` (OS wake waitable timers remain unimplemented).
- **Catch-Up & Stale Event Mechanics (`DEBT-V1-010`):** Batch G1 implemented configurable startup missed-event reconciliation (`SCHEDULER_MISSED_GRACE_SECONDS`), `[start, end)` Quiet Hours suppression tracking, and dedup-indexed `notification_events` persistence; Batch G2 added consolidated Sleep Catch-up summary toast grouping (`WindowsToastAdapter`) and the slide-out `NotificationBacklogDrawer`.
- **Entity Persistence Schemas & Lifecycle State Machines:** Batch G1 delivered Alembic Migration `015_scheduler_notifications_and_routines` (`reminders`, `alarms`, `routines`, `notification_events`, and `profiles.quiet_hours_*`) plus snooze/acknowledge/dismiss/re-arm REST state transitions, and Batch G2 added Migration `016_reminder_center_popup` (`reminders.center_popup` and `tasks.reminder_center_popup`) plus `POST /api/v1/notifications/mark-all-read`.
- **Audio & Escalation Patterns:** Batch G2 delivered urgent `unread` in-app alert banners (`DesktopShell`) and interactive Action Center toast cards (`WindowsToastChannel`), while custom alarm ringtone selection, acoustic playback mechanisms, and volume ramping remain open.
- **Host Sleep & Wake Primitives:** Feasibility and mechanism of Windows waitable timers (`CreateWaitableTimerEx`) for best-effort wake remain open.

---

## 6. Security & Ownership Boundaries

- **Profile Ownership:** All Tasks, Reminders, Alarms, and Routines are strictly owned by the owning/authenticated Profile (`profile_id`, migrated from `owner_id`).
- **Cross-Character Invariant:** Characters do not own productivity data. Switching active character personas does not alter, hide, or reattribute task or schedule records.
- **Tool Execution Boundary:** LLM assistant access to task modification tools operates under deterministic profile policy; destructive permanent deletes require explicit user confirmation.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, Decision D10)
- **Mobile System Baseline:** [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md) (§5 Capability Matrix, §7 Decision Ledger)
- **Mobile Offline & Sync Specification:** [`docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`](../04_Infrastructure/mobile-offline-and-sync.md) (§3 Sync Matrix, §5 Background Responsibilities, §6 Scheduling & Delivery)
- **Productivity & Scheduler ADR:** [`docs/04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md`](../decisions/ADR-0011-d10-scheduling-and-notification-semantics.md)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) (Decision D10), [`WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-SCHED-001`, `PC-SCHED-002`)
- **Windows Host Infrastructure:** [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md)
- **UI Design Presentation:** [`docs/05_Design/06_Notifications_and_Backlog_Activity.md`](../../05_Design/06_Notifications_and_Backlog_Activity.md)
