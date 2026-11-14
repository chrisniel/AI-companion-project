# Implementation Plan: M3 Batch G2 — Desktop Schedule UI, Native Windows WinRT Toasts & Quiet Hours

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Phase 1 Plan Revised (Independent Review Findings Resolved) — Awaiting Human Owner Approval
- **Delivery Level:** Level B — Planned Autonomous
- **Scope Mode:** New Feature — Flutter Desktop Schedule & Routines Workspace (`PC-CLIENT-008`), Native Windows WinRT Toast Notifications & In-App Alerting (`PC-CLIENT-012` / `PC-HOST-003` client half / `DEBT-V1-02` presentation resolution), Quiet Hours Settings UI, and Batch G1 Review Fold-Ins (`NIT-01`, `NIT-02`)
- **Target Files:**
  - `frontend/flutter/apps/desktop/lib/platform/windows_toast_adapter.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/lib/features/schedule/desktop_schedule_controller.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/lib/features/schedule/schedule_sidebar.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/lib/features/schedule/schedule_edit_dialogs.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/lib/features/schedule/notification_backlog_drawer.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/lib/screens/schedule_screen.dart` *(MODIFY)*
  - `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart` *(MODIFY)*
  - `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart` *(MODIFY)*
  - `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` *(MODIFY)*
  - `frontend/flutter/apps/desktop/lib/main.dart` *(MODIFY)*
  - `frontend/flutter/apps/desktop/test/windows_toast_adapter_test.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/test/desktop_schedule_controller_test.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/test/schedule_screen_test.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/test/notification_backlog_drawer_test.dart` *(ADD)*
  - `frontend/flutter/apps/desktop/test/desktop_shell_test.dart` *(MODIFY)*
  - `frontend/flutter/apps/desktop/test/desktop_settings_test.dart` *(MODIFY)*
  - `frontend/flutter/apps/desktop/test/desktop_layout_responsive_test.dart` *(MODIFY)*
  - `backend/app/api/v1/endpoints/scheduling.py` *(MODIFY — `NIT-01`)*
  - `backend/tests/test_scheduling_api.py` *(MODIFY — `NIT-01` regression tests)*
  - `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md` *(MODIFY — `NIT-02` + Phase 3 sync)*
- **Branch:** `feature/m3-schedule-ui-windows-toasts-g2`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m3-schedule-ui-windows-toasts-g2.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m3-schedule-ui-windows-toasts-g2.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:** Deliver the user-facing Flutter Desktop Schedule & Routines UI (`PC-CLIENT-008`), native Windows Action Center Toast notification adapter (`PC-CLIENT-012` / `PC-HOST-003` client half / `DEBT-V1-02` presentation resolved), in-app backlog drawer and urgent alert banner, Quiet Hours settings card, and the two non-blocking follow-up fixes from M3 Batch G1 (`NIT-01` & `NIT-02`) on top of PR `#41` (`fe1526e`).
- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) (Decision D2 decoupled runtime, Decision D10 scheduling & notifications)
  - [`docs/04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md`](../../04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md)
  - [`docs/04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md`](../../04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md)
  - [`docs/04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md`](../../04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md)
  - [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md)
  - [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md)
  - [`docs/05_Design/06_Notifications_and_Backlog_Activity.md`](../../05_Design/06_Notifications_and_Backlog_Activity.md)
  - [`docs/05_Design/01_PC_Desktop_Shell_and_Tray.md`](../../05_Design/01_PC_Desktop_Shell_and_Tray.md)
  - [`docs/02_Planning/00_Master/WBS.md`](../00_Master/WBS.md) & [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../00_Master/DECISION_DEBT.md)
- **Concrete Deliverables:**
  1. **Native Windows WinRT Toast Adapter (`DEBT-V1-02` Presentation Resolved):** Dependency-free `WindowsWinRtToastAdapter` invoking Windows 10/11 WinRT `ToastNotificationManager` via `ProcessLauncherAdapter` with idempotent `HKCU` AUMID registration (`AICompanion.Desktop`), pure Dart UTF-16LE byte emission for PowerShell `-EncodedCommand` wrapping UTF-8 Base64 toast XML, strict XML entity + XML 1.0 control-character sanitization, payload length guard, native OS `<actions>` (`snooze`/`dismiss`) on live alarms so Windows Action Center can silence looping alarm audio without a COM server, urgency-specific styling, Quiet Hours suppression, and consolidated sleep/offline catch-up summary toasts.
  2. **`DesktopScheduleController` & Profile-Fenced Polling Engine:** Profile-scoped, epoch-fenced controller wrapping a live `CompanionClient Function()` resolver and `DesktopToastAdapter`, managing Tasks (+ Trash/Restore), Reminders, Alarms, Routines, Notifications backlog, Quiet Hours settings, opt-in background polling (`unreadOnly: true`, `limit: 50`), per-session toast deduplication (`_dispatchedToastEventIds`), and active `unread` in-app alert banners.
  3. **Flutter Desktop Schedule Workspace (`PC-CLIENT-008`):** Option 2A two-column replacement for the placeholder `ScheduleScreen` across Tasks, Reminders, Alarms, Routines, and Notifications sections with create/edit/delete/snooze/acknowledge/dismiss/restore/run-now actions, real OpenAPI enum status pills, and per-item `bypassQuietHours` override toggle.
  4. **Shell Top Utility Strip, Backlog Drawer & Settings Quiet Hours Card (`PC-CLIENT-012`):** Non-overlapping slim top utility strip in `DesktopShell` housing the active Profile scope indicator, Notification Bell badge button opening `NotificationBacklogDrawer` (with Missed Catch-up banner, chronological timeline, distinct `[ Mark Done ]` vs `[ Dismiss ]` / `[ Clear All ]` controls), urgent In-App Alert Banner above the workspace `Stack`, removal of `'M3'` badge on `DesktopNavDestination.schedule`, and reactive **Notifications & Quiet Hours** card in `SettingsScreen`.
  5. **Batch G1 Review Fold-Ins (`NIT-01` & `NIT-02`):** Separate recurring vs non-recurring recomputation + invalid `clear_time_of_day` / `recurrence_days` `422` guard in `PATCH /api/v1/alarms/{alarm_id}`, and fix duplicate `### 3.3` -> `### 3.4` subsection numbering in `tasks-reminders-alarms-and-routines.md`.
- **Explicit Out-of-Scope:**
  - External Flutter pub dependencies in `frontend/flutter/apps/desktop/pubspec.yaml` (keeps pub dependencies unchanged by using `ProcessLauncherAdapter` / Windows built-in WinRT bridge rather than adding WinRT NuGet/CMake plugins).
  - Native C++ WinRT COM `ToastActivated` IPC callback server (`--toast-activated` deep-link invocation when the Flutter desktop app is closed or backgrounded). Batch G2 resolves `DEBT-V1-02` toast presentation + Windows Action Center OS system controls (`snooze` / `dismiss` on alarms) and delivers full `[ Mark Done ]` / `[ Snooze 10m ]` / `[ Dismiss ]` / `[ Open Chat ]` buttons inside the In-App Alert Banner and Backlog Drawer; custom C++ COM `ToastActivated` IPC remains explicitly documented as deferred optional post-G2 polish.
  - Cross-Profile notification aggregation (`PC-IDENTITY-002` session isolation prohibits reading notifications from inactive Profiles; the drawer shows an active Profile scope chip instead).
  - Windows Task Scheduler dual autostart (`PC-HOST-002`) and MSI/self-contained installer (`PC-HOST-006`) — remain Milestone M2/M5 items.
  - D9 conversational tool-calling (`PC-ACTION-*`) and Voice pipeline (`PC-VOICE-*`) — remain Milestone M4.
  - New Alembic migrations or OpenAPI schema additions (`contracts/openapi/openapi.json` stays unchanged at `66` URL paths, `93` HTTP operations, and `82` native-covered routes).

---

## 2. Architecture & Technical Approach

- **Current Findings & Technical Baseline:**
  | Observation / Evidence | Verified Interpretation |
  | --- | --- |
  | PR `#41` (`fe1526e`) delivered Migration `015`, `SchedulerService`, all `/api/v1/{tasks,reminders,alarms,routines,notifications}*` + `/profiles/me/quiet-hours` endpoints, and 38 `CompanionClient` Dart SDK methods (`82/82` covered routes, `60/60` DTO schemas). | Backend runtime, persistence, REST endpoints, and typed Dart SDK already exist and are CI-verified. Zero DB migrations or OpenAPI changes are needed. |
  | Exact OpenAPI backend enums (`backend/app/schemas/scheduling.py`): `NotificationStatus` = `unread`, `read`, `acknowledged`, `dismissed`, `snoozed`, `suppressed_quiet_hours`, `missed_catchup`; `ReminderStatus` = `scheduled`, `fired`, `snoozed`, `acknowledged`, `dismissed`, `missed`, `cancelled`; `AlarmStatus` = `armed`, `ringing`, `snoozed`, `acknowledged`, `dismissed`, `missed`; `DeliveryPolicy` = `immediate`, `quiet_hours_suppressed`, `missed_catchup`. | UI badges, controller filters, toast dispatch eligibility, and alert banner filters must match these exact strings (`'unread'`, not `'pending'`, for notifications; `'scheduled'`/`'fired'` and `'armed'`/`'ringing'` for reminders/alarms). |
  | `TaskUpdate` (`task_dto.dart`) takes `clearNotes`, `clearDueDate`, `clearReminderMinutesBefore`, `clearReminderAt` as named parameters on `CompanionClient.updateTask(...)`, whereas `ReminderUpdate`, `AlarmUpdate`, and `RoutineUpdate` (`scheduling_dto.dart`) carry boolean `clear*` fields on the DTOs themselves. | `DesktopScheduleController` and `ScheduleEditDialogs` must respect that exact asymmetry instead of assuming identical DTO signatures. |
  | `DesktopChatController` connects asynchronously after `DesktopShell` mounts (`main.dart`) and may replace its `CompanionClient` in `updateConfiguration()` or switch/expire `authenticatedProfileId`; `DesktopShell._handleProfileChange` currently only listens to `profileController`. | `DesktopScheduleController` must observe **both** `chatController` (`isConnected`, `authenticatedProfileId`, `configEpoch`, `profileEpoch`, `client`) and `profileController`, resolve the current `CompanionClient` dynamically via callback/update, pause polling immediately when disconnected/switching (`!isConnected || profileId == null`), and guard default polling/toasts with `!Platform.environment.containsKey('FLUTTER_TEST')`. |
  | `DesktopShell` places child screens full-bleed inside `Expanded(child: Stack(...))`, where `ChatScreen`, `MemoryScreen`, and `StudioScreen` own top-right header controls. | Overlaying a `Positioned` top-right Bell button inside `Stack` would collide with child headers. Placing the Bell badge and In-App Alert Banner in a dedicated non-overlapping top strip above `Expanded` eliminates collisions across every tab. |
  | `desktop_shell_test.dart` currently checks `find.text('M3')` `findsNWidgets(2)` (line 51), `find.text('PLANNED MILESTONE M3')` (line 76), and mounts `DesktopShell(controller: ..., chatController: connectedChat, studioController: ...)` against a 404 `MockClient` (lines 114–175). | Updating `ScheduleScreen` and clearing `'M3'` on `DesktopNavDestination.schedule` requires updating lines `51` (`findsOneWidget`) and `76`, plus keeping `enableSchedulePolling` disabled in `FLUTTER_TEST` by default and `scheduleController` optional on `DesktopShell`/`SettingsScreen`. |
  | `backend/app/api/v1/endpoints/scheduling.py:510-563` only recomputes `Alarm.scheduled_at` when `(as_utc(alarm.scheduled_at) or now) <= now`, and `service.py:165-236` validates Quiet Hours timezones against `UTC`, `UTC±HH:MM`, and `_BUILTIN_IANA_ZONES` (~70 curated zones). | `NIT-01` must distinguish recurring vs non-recurring alarms on `enabled=True` and enforce `422` if `clear_time_of_day=True` leaves `recurrence_days` non-empty; Settings UI must present choices aligned with `_BUILTIN_IANA_ZONES` + `UTC` + `UTC±HH:MM` help text. |

- **Architectural Approach:**
  1. **WinRT Toast Presentation (`DEBT-V1-02` Presentation Resolved):**
     - `DesktopToastAdapter` defines:
       - `Future<bool> showNotificationToast(NotificationEventOut event)`
       - `Future<bool> showMissedCatchupSummaryToast({required int missedCount, required List<NotificationEventOut> events})`
     - `WindowsWinRtToastAdapter` checks `Platform.isWindows` (or injectable `isWindowsOverride` for headless cross-platform tests), sanitizes text with `sanitizeXmlText(...)` (stripping invalid XML 1.0 control chars `\x00-\x08`, `\x0B-\x0C`, `\x0E-\x1F`) and `escapeXml(...)` (`&`, `<`, `>`, `"`, `'`), and builds WinRT `ToastGeneric` XML via pure `buildToastXml(...)`:
       - **Live Active Alarm** (`(event.sourceType == 'alarm' || event.urgency == 'high') && event.deliveryPolicy != 'quiet_hours_suppressed' && !event.isMissedCatchup`): emits `<toast scenario="alarm">` with `<audio src="ms-winsoundevent:Notification.Looping.Alarm" loop="true"/>` AND `<actions><action activationType="system" arguments="snooze" content=""/><action activationType="system" arguments="dismiss" content=""/></actions>` so Windows Action Center provides native OS snooze/dismiss controls to silence looping audio cleanly without requiring a COM server.
       - **Reminder / Task Reminder** (`event.sourceType == 'reminder' || event.sourceType == 'task_reminder'`): emits `<toast scenario="reminder">` with `<audio src="ms-winsoundevent:Notification.Reminder"/>` when live active.
       - **Routine** (`event.sourceType == 'routine'`): emits default `<toast>` with `<audio src="ms-winsoundevent:Notification.Default"/>` when live active.
       - **Quiet-Hours Suppressed Reminders** (`deliveryPolicy == 'quiet_hours_suppressed'` on `reminder`/`task_reminder`): sets `<audio silent="true"/>` and PowerShell `$toast.SuppressPopup = $true` so it lands silently in Action Center without disturbing Quiet Hours. (Suppressed `routine` events are skipped completely from Windows toast dispatch.)
       - **Consolidated Catch-up Summary** (`showMissedCatchupSummaryToast`): uses standard `<toast>` (never `scenario="alarm"`) and `<audio silent="true"/>` summarizing the missed count cleanly.
     - **AUMID Registration, Encoding & Headless Invocation:**
       - Inside the generated PowerShell script, performs an idempotent per-user HKCU registration for `HKCU:\Software\Classes\AppUserModelId\AICompanion.Desktop` (`DisplayName = "AI Companion"`) before calling `ToastNotificationManager::CreateToastNotifier('AICompanion.Desktop')` so unpackaged `ai_companion_desktop.exe` displays reliably on Windows 10/11.
       - Emits UTF-16LE bytes manually from Dart string code units (`cu & 0xff`, `(cu >> 8) & 0xff`) for `-EncodedCommand` and embeds the toast XML as UTF-8 Base64 decoded inside a pure-ASCII outer PowerShell script (preserving Unicode emojis / surrogate pairs without Windows `powershell.exe` codepage corruption). Enforces an explicit payload length guard against the Windows `32,767`-char process command-line limit.
       - Evaluates suppressing any `powershell.exe` console window flash on Windows desktop (`-WindowStyle Hidden` vs non-console headless Win32 `CREATE_NO_WINDOW` invocation in `WindowsWinRtToastAdapter` without adding external pub dependencies), and explicitly verifies zero visible console flash in the Phase 4 manual Windows UI checklist.
       - Never throws out of `showNotificationToast` — logs failures via `debugPrint` and returns `false`.
  2. **Schedule Controller & Polling Architecture (`DesktopScheduleController`):**
     - Constructed with `{required CompanionClient Function() clientProvider, DesktopToastAdapter? toastAdapter, String? profileId, Duration pollInterval = const Duration(seconds: 15)}` (with convenience factory/named constructor for fixed `CompanionClient` in unit tests).
     - Maintains `_scopeEpoch` integer incremented on `updateProfileScope(...)` / `clearForDisconnect()` so stale in-flight HTTP responses are discarded before mutating state. Also cancels/skips polling immediately when `!isConnected || profileId == null` (preventing mid-profile-switch or session-expiry `401` errors).
     - `refreshAll()` loads `listTasks()`, `listReminders()`, `listAlarms()`, `listRoutines()`, `listNotifications()`, and `getQuietHours()` safely, exposing actionable `errorMessage` feedback without wiping healthy collections on transient partial errors.
     - `pollNotifications()` queries `clientProvider().listNotifications(unreadOnly: true, limit: 50)` so historical resolved items never crowd out newer unread or catch-up alerts:
       - Toast candidate statuses: `{'unread', 'suppressed_quiet_hours', 'missed_catchup'}`.
       - Filters unseen items (`!_dispatchedToastEventIds.contains(event.id)`):
         - Newly seen `isMissedCatchup == true` items (one or more in a poll batch) trigger **one** consolidated `showMissedCatchupSummaryToast(...)` and record their IDs in `_dispatchedToastEventIds`.
         - Live unseen items: skips `sourceType == 'routine' && deliveryPolicy == 'quiet_hours_suppressed'`; dispatches `showNotificationToast(event)` for all remaining live candidates and records IDs in `_dispatchedToastEventIds`.
         - Note on persistence across app restarts: unresolved notifications that still have status `unread` or `missed_catchup` intentionally re-surface once per desktop session on relaunch until acknowledged or dismissed.
       - Computes `activeAlerts`: strictly items with `status == 'unread'` (never `suppressed_quiet_hours`, and leaving `missed_catchup` in the grouped Sleep Catch-up banner/drawer), sorted by urgency (`high` first, then newest first).
     - Polling timer (`startPolling()` / `stopPolling()`): explicitly opt-in (started by `DesktopShell` only when connected, authenticated with a non-null `profileId`, `enableSchedulePolling != false`, and `!Platform.environment.containsKey('FLUTTER_TEST')`), and always cancelled cleanly in `dispose()`.
  3. **Option 2A Schedule Workspace & Backlog UX:**
     - Follows `MemoryScreen` / `MemoryTierSidebar` visual system (`SoftGlassPanel`, `NeumorphicSurface`, `CompanionThemeExtension`, `>= 720px` side-by-side vs `< 720px` compact horizontal bar).
     - 5 workspace sections matching backend domains:
       - **Tasks:** Priority badge (`low`/`medium`/`high`/`urgent`), category chip, due date / reminder indicator, checkbox toggle (`completed` <-> `pending` automatically triggering backend linked-reminder cancellation), edit/delete, and `"Trash"` view toggle with `Restore` and `Delete Forever`. Uses `CompanionClient.updateTask(...)` named clear flags (`clearNotes`, `clearDueDate`, `clearReminderMinutesBefore`, `clearReminderAt`) when clearing optional fields.
       - **Reminders:** Local/UTC schedule display, linked Task indicator when `taskId != null`, `Quiet Hours Override` chip (`bypassQuietHours == true`), exact status pill (`scheduled`, `fired`, `snoozed`, `acknowledged`, `dismissed`, `missed`, `cancelled`), actions (`Snooze 10m`, `Acknowledge`, `Dismiss`, `Edit`, `Delete`).
       - **Alarms:** Prominent `timeOfDay` / `scheduledAt` readout, weekday chips (`Mon..Sun`), `Enabled` toggle switch, Quiet Hours bypass badge, exact status pill (`armed`, `ringing`, `snoozed`, `acknowledged`, `dismissed`, `missed`), actions (`Snooze 10m`, `Acknowledge`, `Dismiss`, `Edit`, `Delete`). Editing schedule parameters on a `ringing`/`snoozed`/`missed` alarm in `ScheduleEditDialogs` explicitly passes `status: 'armed'` + `clearSnoozedUntil: true`. Switching from recurring to one-shot passes `clearRecurrenceDays: true`.
       - **Routines:** Time + weekday recurrence chips, `fallbackMessage` preview, `Enabled` switch, `[ Run Now ]` button (`runRoutineNow()` + immediate poll refresh), `Edit`/`Delete`.
       - **Notifications:** Full chronological backlog list (`Unread Only` filter), active Profile scope indicator chip, grouped **Missed Catch-up** callout banner, distinct `[ Mark Done ]` (`acknowledgeNotification(..., completeTask: true)`) vs `[ Acknowledge ]`, `[ Snooze 10m ]`, `[ Dismiss ]` (does **not** complete linked Tasks), `[ Mark Read ]`, `[ Open Chat ]` (navigates to `DesktopNavDestination.chat`), and `[ Clear All ]` (dismisses notifications without marking Tasks done).
  4. **Shell Top Utility Strip, Backlog Drawer & Settings Quiet Hours UI:**
     - `DesktopShell` places a compact slim top utility strip (above `Expanded(child: Stack(...))` inside the main content `Column`) showing the active Profile scope pill (when connected) and the Notification Bell button with unread/missed badge, opening `NotificationBacklogDrawer` from the right edge (width capped safely to `min(420, viewportWidth * 0.92)` for `1024x640` safety).
     - When `activeAlerts` (`status == 'unread'`) is non-empty, `DesktopShell` renders a compact `SoftGlassPanel` Active Alert Banner cleanly between the top utility strip and `Expanded(child: Stack(...))`, offering `[ Mark Done ]` (only when `taskId != null` or label `[ Acknowledge ]` otherwise), `[ Snooze 10m ]`, `[ Dismiss ]`, and `[ Open Chat ]`.
     - `SettingsScreen` adds `_buildQuietHoursCard` observing `DesktopScheduleController` reactively (reloading immediately if profile changes while already in Settings), providing:
       - `Enable Quiet Hours` switch
       - `Start` & `End` `HH:MM` selectors/inputs
       - `Timezone` selector curated directly from `_BUILTIN_IANA_ZONES` + `'UTC'` + `'UTC±HH:MM'` custom offset helper
       - Save button surfacing inline validation / `422` errors (e.g., identical `start == end`)
       - Required canonical notice: *"Alarms bypass quiet hours by default to ensure wakefulness."*

- **Contract & Schema Impact:**
  - Zero Alembic migrations and zero new REST routes or OpenAPI schema changes (`contracts/openapi/openapi.json` stays unchanged at `66` URL paths, `93` HTTP operations, and `82` native-covered routes; `scripts/check_openapi_contract.py --check` and `scripts/check_dart_openapi_parity.py --check` remain green).
  - Existing endpoint refinement (`NIT-01`): `PATCH /api/v1/alarms/{alarm_id}` in `backend/app/api/v1/endpoints/scheduling.py` fixes recurring vs non-recurring recomputation and validates invalid `clear_time_of_day` + `recurrence_days` combinations with HTTP `422`. Response schema `AlarmOut` is unchanged.

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `frontend/flutter/apps/desktop/lib/platform/windows_toast_adapter.dart`
- **Primary Responsibility:** Abstraction and Windows WinRT implementation for Action Center toast notifications (`DEBT-V1-02` presentation resolution).
- **Planned Change:** Implement `DesktopToastAdapter`, `NoOpDesktopToastAdapter`, and `WindowsWinRtToastAdapter(ProcessLauncherAdapter)` with `sanitizeXmlText`, `escapeXml`, `buildToastXml` (`scenario="alarm"` + system `<actions>` only for live active alarms, silent/SuppressPopup Quiet Hours handling, consolidated silent catch-up summary toast), pure Dart UTF-16LE PowerShell `-EncodedCommand` encoding over UTF-8 Base64 XML, idempotent `HKCU` AUMID registration, payload-length bounding, and headless invocation safeguards.
- **Invariants to Preserve:** Never throw uncaught exceptions on headless/restricted hosts; never shell-interpolate untrusted user strings unescaped; respect Quiet Hours suppression and catch-up aggregation rules.

### [ADD] `frontend/flutter/apps/desktop/lib/features/schedule/desktop_schedule_controller.dart`
- **Primary Responsibility:** Profile-scoped, epoch-fenced state management, REST orchestration, opt-in notification polling (`unreadOnly: true`, `limit: 50`), and per-session toast deduplication.
- **Planned Change:** Add `DesktopScheduleController` wrapping a dynamic `CompanionClient Function()` provider and `DesktopToastAdapter`, listening to connection/profile state, exposing `tasks`, `trashTasks`, `reminders`, `alarms`, `routines`, `notifications`, `unreadCount`, `missedCount`, `activeAlerts` (`status == 'unread'`), `quietHours`, full CRUD/action methods (using `CompanionClient.updateTask` named clear flags vs DTO `clear*` fields accurately), and opt-in polling lifecycle.
- **Invariants to Preserve:** Clear cached data, `activeAlerts`, and `_dispatchedToastEventIds` immediately on profile switch or disconnect; never start periodic timers inside `FLUTTER_TEST` by default.

### [ADD] `frontend/flutter/apps/desktop/lib/features/schedule/schedule_sidebar.dart`
- **Primary Responsibility:** Option 2A inner sub-navigation rail (`>= 720px` sidebar and `< 720px` compact horizontal bar) matching `MemoryTierSidebar`.
- **Planned Change:** Render the 5 Schedule sub-sections (`Tasks`, `Reminders`, `Alarms`, `Routines`, `Notifications`) with counts, unread/missed notification badge, and Quiet Hours status indicator.
- **Invariants to Preserve:** Zero layout overflow at `1024x640` minimum viewport and `1.3x` text scale factor.

### [ADD] `frontend/flutter/apps/desktop/lib/features/schedule/schedule_edit_dialogs.dart`
- **Primary Responsibility:** Validated modal dialogs for creating and editing Tasks, Reminders, Alarms, and Routines.
- **Planned Change:** Convert local `DateTime` / `HH:MM` selections to ISO-8601 UTC (`toUtc().toIso8601String()`) and valid `HH:MM` + timezone strings; pass `clearRecurrenceDays: true` alongside `clearTimeOfDay: true` when converting Alarms to one-shot; explicitly re-arm (`status: 'armed'`, `clearSnoozedUntil: true`) when editing schedule timing on a `ringing`/`snoozed`/`missed` alarm; clearly surface `bypassQuietHours` controls and Quiet Hours alarm wakefulness note.
- **Invariants to Preserve:** Never send ambiguous mixed `clearTimeOfDay` + non-empty `recurrenceDays`; display actionable validation errors cleanly.

### [ADD] `frontend/flutter/apps/desktop/lib/features/schedule/notification_backlog_drawer.dart`
- **Primary Responsibility:** In-app Notification Center & Backlog Activity slide-out drawer (`docs/05_Design/06_Notifications_and_Backlog_Activity.md` §3).
- **Planned Change:** Render active Profile scope indicator chip, grouped **Missed Reminders (Sleep Catch-up)** summary banner when `missedCount > 0`, chronological timeline of events (`high`/alarm, `reminder`/`task_reminder`, `routine`), distinct action chips (`Mark Done` when linked task exists vs `Acknowledge`, `Snooze 10m`, `Dismiss`, `Open Chat`, `Mark Read`), and `Clear All` (dismiss-only semantic).
- **Invariants to Preserve:** Safe responsive width capping on `1024x640` windows; no cross-Profile reads or stale state across profile switches.

### [MODIFY] `frontend/flutter/apps/desktop/lib/screens/schedule_screen.dart`
- **Primary Responsibility:** Main `PC-CLIENT-008` Schedule & Routines screen in `DesktopShell`.
- **Planned Change:** Replace the static `'PLANNED MILESTONE M3'` placeholder with the live Option 2A two-column Schedule workspace backed by `DesktopScheduleController`, showing an informative offline/initializing fallback if `controller == null`, Trash toggle for Tasks, contextual `+ New` primary button, and domain-accurate status pills/cards.
- **Invariants to Preserve:** Keep `'Schedule & Routines'` heading and `'Proactive triggers, reminders, and daily habits'` subtitle; degrade gracefully when unauthenticated or disconnected.

### [MODIFY] `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`
- **Primary Responsibility:** Navigation destinations enum and UI settings controller.
- **Planned Change:** Remove `badge: 'M3'` from `DesktopNavDestination.schedule` so `schedule.isPlanned` becomes `false`, leaving `studio` and `voice` badges untouched.
- **Invariants to Preserve:** Preserve existing enum ordering, icons, shortcuts (`Ctrl+,`, `Esc`), and settings controller API.

### [MODIFY] `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` & `frontend/flutter/apps/desktop/lib/main.dart`
- **Primary Responsibility:** App-wide shell integration, top utility strip with Notification Bell badge, `NotificationBacklogDrawer`, In-App Active Alert Banner, and reactive connection/profile lifecycle orchestration.
- **Planned Change:**
  - Add optional `scheduleController` and `enableSchedulePolling` parameters to `DesktopShell` (plus `WindowsWinRtToastAdapter` when `!Platform.environment.containsKey('FLUTTER_TEST')`, else `NoOpDesktopToastAdapter`).
  - Listen to **both** `chatController` and `profileController` so async startup connection, `updateConfiguration()` client replacements, `selectProfile()` transitions, and `_sessionExpiryTimer` expirations update or pause/clear `DesktopScheduleController` cleanly with zero mid-switch `401` races.
  - Render the non-overlapping top utility strip (active Profile chip + Notification Bell badge) and urgent `unread` Active Alert Banner above `Expanded(child: Stack(...))`, wire `[ Open Chat ]` to `DesktopNavDestination.chat`, and pass `scheduleController` into `SettingsScreen`.
- **Invariants to Preserve:** Existing constructors calling `DesktopShell(controller: ...)` or `SettingsScreen(controller: ...)` with no `scheduleController` or `chatController` keep compiling cleanly without starting orphan timers or spawning `powershell.exe`.

### [MODIFY] `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart`
- **Primary Responsibility:** Add reactive **Notifications & Quiet Hours** card under Settings.
- **Planned Change:** Add `_buildQuietHoursCard` accepting optional `DesktopScheduleController? scheduleController`, listening reactively so in-Settings profile switches refresh immediately, presenting `Enable Quiet Hours`, `Start`/`End` `HH:MM`, timezone selector backed by `_BUILTIN_IANA_ZONES` + `UTC` + `UTC±HH:MM` custom offset guidance, Save validation feedback, and the notice `"Alarms bypass quiet hours by default to ensure wakefulness."`
- **Invariants to Preserve:** Standalone tests constructing `SettingsScreen(controller: ...)` without `scheduleController` render a clean disconnected/unavailable card state without network calls or exceptions.

### [MODIFY] `backend/app/api/v1/endpoints/scheduling.py` & `backend/tests/test_scheduling_api.py` (`NIT-01`)
- **Primary Responsibility:** Recompute `Alarm.scheduled_at` accurately on parameter updates and guard invalid recurrence combinations.
- **Planned Change:**
  - Distinguish recurring (`bool(days)`) vs non-recurring (`not days`) alarms when `enabled` transitions to `True` so a still-future non-recurring alarm's `scheduled_at` is NOT overwritten on disable -> re-enable unless `(as_utc(alarm.scheduled_at) or now) <= now` or `time_of_day`/`timezone`/`recurrence_days` explicitly changed.
  - Recompute `alarm.scheduled_at = compute_next_occurrence(...)` when `alarm.enabled and alarm.time_of_day and payload.scheduled_at is None and alarm.status == AlarmStatus.armed.value` and schedule fields changed (or `(as_utc(alarm.scheduled_at) or now) <= now`).
  - Raise HTTP `422` if `payload.clear_time_of_day` leaves `recurrence_days` non-empty without `clear_recurrence_days` / empty `recurrence_days`.
  - Add regression tests in `backend/tests/test_scheduling_api.py` for recurring param edits, non-recurring re-enable preservation, and `clear_time_of_day` + `recurrence_days` `422`.
- **Invariants to Preserve:** Explicit `payload.scheduled_at` always takes precedence; disabled/dismissed/acknowledged alarms are never unexpectedly re-armed.

### [MODIFY] `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md` (`NIT-02` + Phase 3)
- **Primary Responsibility:** Canonical domain spec alignment.
- **Planned Change:** Fix duplicate `### 3.3` heading (`NIT-02` -> `### 3.4`) and document delivered Batch G2 Desktop UI + WinRT Toast presentation scope during Phase 3.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Step 1 — Backend Review Fold-In (`NIT-01`) & Regression Tests:**
   - Write failing tests in `backend/tests/test_scheduling_api.py` covering future recurring param edits recomputing `scheduled_at`, non-recurring disable->re-enable preserving future `scheduled_at`, and `clear_time_of_day=True` with active `recurrence_days` returning `422` (RED).
   - Update `update_alarm` in `backend/app/api/v1/endpoints/scheduling.py` (GREEN) and run `backend/tests/test_scheduling_api.py` + `test_scheduler_service.py`.
2. **Step 2 — Native Windows WinRT Toast Adapter (`DEBT-V1-02`) & Tests:**
   - Write unit tests in `frontend/flutter/apps/desktop/test/windows_toast_adapter_test.dart` covering XML escaping + XML 1.0 control-char stripping, live alarm `<toast scenario="alarm">` + system `<actions>` (`snooze`/`dismiss`), quiet-hours `<audio silent="true"/>` + `SuppressPopup`, catch-up summary toast (non-alarm), HKCU AUMID registration script generation, UTF-16LE `-EncodedCommand` + Unicode preservation, payload length guard, and error resilience via mock `ProcessLauncherAdapter` (RED).
   - Implement `frontend/flutter/apps/desktop/lib/platform/windows_toast_adapter.dart` (GREEN), evaluating headless Windows invocation (`-WindowStyle Hidden` vs non-console Win32 `CREATE_NO_WINDOW`) so live toasts do not flash console windows.
3. **Step 3 — `DesktopScheduleController` & Polling/Deduplication Tests:**
   - Write unit tests in `frontend/flutter/apps/desktop/test/desktop_schedule_controller_test.dart` covering initial load across Tasks/Trash/Reminders/Alarms/Routines/Notifications/QuietHours, `updateTask` clear flags vs DTO `clear*` fields, `unreadOnly: true` polling pagination, routine quiet-hours skip, missed catch-up consolidation, `activeAlerts` excluding `suppressed_quiet_hours` and `missed_catchup`, dynamic client updates + disconnect/profile-switch `_scopeEpoch` cancellation, and opt-in polling lifecycle (RED).
   - Implement `frontend/flutter/apps/desktop/lib/features/schedule/desktop_schedule_controller.dart` (GREEN).
4. **Step 4 — Schedule Screen, Sub-Components, Drawer, Shell Utility Strip & Settings Quiet Hours UI:**
   - Write/update widget tests in `schedule_screen_test.dart`, `notification_backlog_drawer_test.dart`, `desktop_shell_test.dart` (updating line `51` `findsNWidgets(2)` -> `findsOneWidget` and line `76`), `desktop_settings_test.dart`, and `desktop_layout_responsive_test.dart` (verifying `1024x640` at `1.3x` text scale with Bell strip + Alert banner active and zero overflow) (RED).
   - Implement `schedule_sidebar.dart`, `schedule_edit_dialogs.dart`, `notification_backlog_drawer.dart`, updated `schedule_screen.dart`, `desktop_settings_controller.dart`, `desktop_shell.dart`, `main.dart`, and `settings_screen.dart` Quiet Hours card (GREEN).
5. **Step 5 — Full Automated Verification Gate:**
   - Run all contract parity checks (`check_openapi_contract.py --check`, `check_dart_openapi_parity.py --check`), backend `pytest backend/tests -q`, `dart test` (`companion_api`), `flutter analyze`, full `flutter test` (`apps/desktop`), and `frontend/web` lint/test/build.
6. **Step 6 — Phase 3 Documentation, Closure & Draft PR:**
   - Sync `tasks-reminders-alarms-and-routines.md` (including `NIT-02`), `windows-host-and-notifications.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md` (`DEBT-V1-02` presentation resolved, optional COM activation deep-link polish documented), `DELIVERY_INDEX.md`, `docs/01_Tracking/task.md`, and `CHANGELOG.md`.
   - Author walkthrough `docs/03_Walkthroughs/walkthrough-m3-batch-g2-schedule-ui-windows-toasts.md`, archive `task-feature-m3-schedule-ui-windows-toasts-g2.md`, commit, push, and open a Draft PR against `develop`, supplying the interactive manual Windows UI checklist and plain-text squash merge summary when ready.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Contract & Dart SDK parity checks: `.\backend\.venv\Scripts\python.exe scripts/check_openapi_contract.py --check` and `.\backend\.venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check`
- [ ] Backend full suite: `.\backend\.venv\Scripts\python.exe -m pytest backend/tests -q`
- [ ] Dart SDK package tests: `dart test` in `frontend/flutter/packages/companion_api`
- [ ] Flutter workspace static analysis: `flutter analyze` in `frontend/flutter`
- [ ] Flutter Desktop full suite (unit + widget + responsive overflow): `flutter test` in `frontend/flutter/apps/desktop`
- [ ] Web harness checks (regression check): `npm --prefix frontend/web run lint && npm --prefix frontend/web test -- --run && npm --prefix frontend/web run build`

### Manual & Host-Level Checks (Where Applicable — UI Implemented/Modified)
- [ ] Interactive manual Windows desktop UI & Action Center WinRT Toast verification checklist (to be provided in full at Phase 3/4 handoff per user preference whenever UI changes: launching `ai_companion_desktop`, verifying Schedule 5-tab workspace, creating/editing Task/Reminder/Alarm/Routine, toggling Quiet Hours in Settings across timezones, verifying zero console-window flash on WinRT toast dispatch, verifying native OS `snooze`/`dismiss` buttons on live alarm toasts, and testing In-App Alert Banner + Bell Drawer `[ Mark Done ]` vs `[ Dismiss ]` / `[ Clear All ]` / `[ Open Chat ]`).

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *Widget tests hanging on background `Timer.periodic` or spawning `powershell.exe`:* Polling only starts when `startPolling()` is explicitly invoked, `DesktopShell` suppresses auto-polling + native PowerShell dispatch whenever `Platform.environment.containsKey('FLUTTER_TEST')` or `!isConnected || profileId == null`, and timers always cancel in `dispose()`.
  - *Toast spam or console-window flash on Windows:* `pollNotifications()` queries `unreadOnly: true` (`limit: 50`), aggregates unseen `isMissedCatchup == true` events into a single silent catch-up summary toast per poll batch, tracks `_dispatchedToastEventIds` per desktop session, and evaluates headless windowless invocation + manual visual check for zero PowerShell console flash.
  - *PowerShell / XML injection or encoding corruption:* All toast strings pass through XML 1.0 control-char stripping + `escapeXml()`, are UTF-8 Base64-encoded inside a pure-ASCII outer script, and dispatched via pure Dart UTF-16LE `-EncodedCommand` with payload-length bounds.
  - *Mid-switch `401`s or cross-Profile leaks:* `DesktopScheduleController` listens dynamically to both `chatController` and `profileController`, clears state + `_dispatchedToastEventIds` immediately when `!isConnected || profileId == null`, and increments `_scopeEpoch` to discard stale responses.
- **Dependencies & Assumptions:** Assumes Windows 10/11 built-in PowerShell and WinRT `ToastNotificationManager` assemblies are present on target PCs without adding pub dependencies (`pubspec.yaml` unchanged).
- **Required Permissions:** Task-bounded feature branch (`feature/m3-schedule-ui-windows-toasts-g2`), commits, push, and Phase 3 Draft PR against `develop`. Human Owner retains exclusive merge authority.
- **Genuine Stop Conditions:** Material scope expansion beyond Batch G2, unexpected need to add new external dependencies in `pubspec.yaml` / `requirements.txt`, API contract mismatches requiring DB/OpenAPI breaking changes, or unresolvable CI/test failures.
