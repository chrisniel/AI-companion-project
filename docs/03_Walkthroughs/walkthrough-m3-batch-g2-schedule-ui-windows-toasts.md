# Delivery Walkthrough — M3 Batch G2: Desktop Schedule Workspace, Quiet Hours UI & Option B Native Windows Action Center Toasts

- **Branch:** `feature/m3-schedule-ui-windows-toasts-g2` (branched from `develop` at `fe1526e`)
- **Implementation Plan:** [plan-m3-schedule-ui-windows-toasts-g2.md](../02_Planning/01_Plans/plan-m3-schedule-ui-windows-toasts-g2.md)
- **Archived Task Tracker:** [task-feature-m3-schedule-ui-windows-toasts-g2.md](../01_Tracking/archive/task-feature-m3-schedule-ui-windows-toasts-g2.md)
- **WBS Scope:** `PC-CLIENT-008`, `PC-CLIENT-012`, `PC-HOST-003` (client presentation half), `DEBT-V1-02`, plus M3 Batch G1 review follow-ups `NIT-01` & `NIT-02`
- **Status:** Phase 2 Implemented & Verified; Phase 3 Closure Prepared (Draft PR Ready for Phase 4 Review & Manual Windows GUI / Action Center Verification)

---

## 1. Executive Summary

M3 Batch G2 completes Milestone M3's local-first scheduling and notification user experience on Windows Desktop without adding third-party Dart or Win32 plugin dependencies:

- **Option B Native In-Process C++/WRL WinRT Toast Channel (`WindowsToastChannel` + `WindowsWinRtToastAdapter`):** Communicates over `MethodChannel('ai_companion/windows_notifications')` with COM/WinRT `DesktopNotificationManagerCompat`, Start Menu `.lnk` registration under deterministic AUMID `AICompanion.Desktop`, XML-escaped toast templates with interactive action buttons (`Mark Done`, `Acknowledge`, `Snooze 10m`, `Dismiss`, `Open Chat`, `Review Backlog`), WinRT `Activated` callbacks marshaled safely back to the Win32 `FlutterWindow` UI thread (`kWmToastActivated`), foreground window restoration, Quiet Hours `suppressPopup` handling, consolidated Sleep Catch-up summary grouping, and bidirectional Action Center toast removal (`removeToast` / `clearToasts`) synchronized on Profile switch or disconnect.
- **Reactive Desktop Schedule State (`DesktopScheduleController`):** Polls Profile-scoped tasks, active + trash views, reminders, alarms, routines, notification backlog, and Quiet Hours (`companion_api`), debounces and deduplicates OS toast dispatch, prevents concurrent polling re-entrancy, cancels timers on error/disconnect, routes toast activation events back to REST lifecycle mutations (task completion, acknowledge, snooze, dismiss, mark read), and navigates to Chat or Backlog drawer views on action tap.
- **Option 2A 5-Section Schedule & Routines Workspace (`PC-CLIENT-008`):** Replaces the `ScheduleScreen` placeholder and removes the `'M3'` planned badge on `DesktopNavDestination.schedule`. Delivers tabbed views (`Tasks` with active/completed/trash 30-day restore & permanent deletion filters, `Reminders`, `Alarms` with inline recurrence labels and live toggle switch, `Routines` with deterministic `[ Run Now ]` triggering via `/api/v1/routines/{id}/run`, and `Notifications` backlog history) plus create/edit modal dialogs and offline/unavailable empty states.
- **Settings Quiet Hours & Persistent Shell Utility Strip (`QuietHoursSettingsCard`, `DesktopShell`, `NotificationBacklogDrawer`):** Adds reactive Quiet Hours configuration inside `SettingsScreen` (inline `422` validation feedback, zero framework ink/Box assertion under `SoftGlassPanel`), a persistent right-aligned top utility strip with live Notification Bell + unread/missed badge, a slide-out `NotificationBacklogDrawer`, and an urgent `unread` `shell_active_alert_banner`.
- **Batch G1 Review Follow-Ups (`NIT-01`, `NIT-02`):** Fixes `PATCH /api/v1/alarms/{alarm_id}` in `backend/app/api/v1/endpoints/scheduling.py` to recompute `scheduled_at` on `time_of_day`, `recurrence_days`, `timezone`, or re-arm `enabled` updates and return `422` when `recurrence_days` is set without `time_of_day`; fixes duplicate `### 3.3` heading numbering in `tasks-reminders-alarms-and-routines.md` (`### 3.5`).

---

## 2. Delivered Architecture & Code Changes

### 2.1 Backend `NIT-01` Alarm Update Fix
- `backend/app/api/v1/endpoints/scheduling.py`: Updated `update_alarm` to recompute `scheduled_at` when schedule fields (`time_of_day`, `recurrence_days`, `timezone`) change, or when re-arming or past-due on armed recurring alarms, and reject clearing/missing `time_of_day` while `recurrence_days` is set with `422 Unprocessable Content`.
- `backend/tests/test_scheduling_api.py`: Added regression coverage verifying alarm recurrence recomputation and `422` validation guard.

### 2.2 Option B Native C++/WRL WinRT Toast Channel & Dart Adapter
- `frontend/flutter/apps/desktop/windows/runner/windows_toast_channel.h` & `windows_toast_channel.cpp`: Implemented `WindowsToastChannel` (`ShowToast`, `RemoveToast`, `ClearToasts`, `onToastActivated` callback emission to Dart) using WRL `IToastNotificationManagerStatics`, `RoInitialize`, `IShellLinkW`/`IPropertyStore` Start Menu shortcut creation with `AICompanion.Desktop` AUMID, `PostMessageW(hwnd_, kWmToastActivated, ...)` UI-thread marshaling, and active `ComPtr<IToastNotification>` + `EventRegistrationToken` tracking for clean Action Center removal and teardown.
- `frontend/flutter/apps/desktop/windows/runner/flutter_window.h`, `flutter_window.cpp`, `main.cpp`, `CMakeLists.txt`: Wired `RoInitialize(RO_INIT_MULTITHREADED)` COM initialization, `WindowsToastChannel` ownership in `FlutterWindow::OnCreate`/`OnDestroy`, `kWmToastActivated` message dispatch, foreground restore on toast click, and MSVC `/W4 /WX` clean compilation (`runtimeobject.lib` + `propsys.lib` linked, zero C++ exceptions `_HAS_EXCEPTIONS=0` compliant).
- `frontend/flutter/apps/desktop/lib/platform/windows_toast_adapter.dart`: Implemented `DesktopToastAdapter`, `NoOpDesktopToastAdapter`, `WindowsWinRtToastAdapter`, and `ToastActivationEvent`, handling XML escaping, `suppressPopup` during Quiet Hours, Sleep Catch-up summary payload formatting, Action Center tag/group lifecycle (`ai_companion_alerts`), and incoming `onToastActivated` query parsing.
- `frontend/flutter/apps/desktop/test/windows_toast_adapter_test.dart`: Added unit tests covering XML generation, button wiring (`Mark Done`, `Acknowledge`, `Snooze 10m`, `Dismiss`, `Open Chat`, `Review Backlog`), `suppressPopup`, Sleep Catch-up batching, toast removal, and activation event parsing.

### 2.3 Desktop Schedule Controller & Workspace UI
- `frontend/flutter/apps/desktop/lib/features/schedule/desktop_schedule_controller.dart`: Profile-scoped polling & reconciliation controller handling initial load, interval timers, disconnect/profile-switch cleanup, OS toast dispatch dedup, Sleep Catch-up summary grouping, task soft-delete/restore/complete actions, reminder/alarm/routine/notification CRUD & lifecycle actions, Quiet Hours updates, and interactive toast activation routing.
- `frontend/flutter/apps/desktop/lib/features/schedule/schedule_sidebar.dart`: Option 2A section selector (`Tasks`, `Reminders`, `Alarms`, `Routines`, `Notifications`) with live section badges and filter pills.
- `frontend/flutter/apps/desktop/lib/features/schedule/schedule_edit_dialogs.dart`: Modal forms for creating/editing Tasks (category, priority, due date, reminder lead/timestamp), Reminders, Alarms (weekday recurrence toggles, Quiet Hours bypass toggle), and Routines (prompt/fallback instructions, schedule frequency, enable toggle).
- `frontend/flutter/apps/desktop/lib/features/schedule/quiet_hours_card.dart`: Extracted `QuietHoursSettingsCard` (`Switch` row avoiding Flutter `ListTile inside DecoratedBox` assertion under `SoftGlassPanel`, `HH:MM` text fields, IANA/offset `DropdownButtonFormField(initialValue: ...)` with `GlobalKey<FormFieldState<String>>`, and server `422` validation reporting).
- `frontend/flutter/apps/desktop/lib/features/schedule/notification_backlog_drawer.dart`: Slide-out drawer presenting unread/missed notification events with quick action buttons (`Mark Done`, `Acknowledge`, `Snooze 10m`, `Dismiss`, `Open Chat`, `Clear All`).
- `frontend/flutter/apps/desktop/lib/screens/schedule_screen.dart`: Rewritten Option 2A 5-section desktop schedule workspace with Tasks trash view (`Trash` 30-day restore & permanent delete), inline status/overdue chips, Alarm enable toggle, Routine `[ Run Now ]` execution, and graceful offline/disconnected fallback views.
- `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart`: Added optional `scheduleController` wiring to render `QuietHoursSettingsCard` inside Settings.
- `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`: Removed the temporary `'M3'` planned badge on `DesktopNavDestination.schedule`.
- `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart`: Added optional `scheduleController`, `toastAdapter`, and `enableSchedulePolling` constructor parameters (owning `_scheduleController` lifecycle when `chatController` is present without requiring edits to `main.dart`), right-aligned `shell_top_utility_strip` with `shell_notification_bell_button`, urgent `unread` `shell_active_alert_banner`, slide-out `NotificationBacklogDrawer`, and automatic toast clearing on disconnect or Profile switch.
- Tests (`frontend/flutter/apps/desktop/test/`): Created `desktop_schedule_controller_test.dart`, `schedule_screen_test.dart`, `notification_backlog_drawer_test.dart`; updated `desktop_shell_test.dart`, `desktop_settings_test.dart`, and `desktop_layout_responsive_test.dart`.

### 2.4 Post-Manual-QA Revision (UTC Serialization, Device Timezone, 12-Hour AM/PM UX & Windows COM/Sound)
- `backend/app/schemas/common.py` & `backend/app/api/v1/endpoints/tasks.py`: Added `@model_validator(mode="after")` on `BaseSchema` attaching `timezone.utc` when SQLite returns naive `datetime` values (emitting explicit `Z`/`+00:00` in JSON responses) and normalized Task `due_date`/`reminder_at` via `as_utc`, with regression tests in `test_tasks.py`, `test_task_update_contract.py`, and `test_scheduling_api.py`.
- `frontend/flutter/apps/desktop/windows/runner/windows_toast_channel.h/.cpp` & `CMakeLists.txt`: Provisioned Start Menu `.lnk` (`IShellLinkW` + `IPropertyStore` `PKEY_AppUserModel_ID` & `PKEY_AppUserModel_ToastActivatorCLSID`), registered `INotificationActivationCallback` via `CoRegisterClassObject` + `HKCU\Software\Classes\CLSID\...\LocalServer32` & `CustomActivator` (enabling direct action-button clicks from both floating popups and the Windows Notification Center side pane), added `PlaySoundW` (`winmm.lib`) alert chime playback with single-source `<audio silent="true"/>` coordination, and exposed `getDeviceTimezone` (`Windows.Globalization.Calendar`) + `playAlertSound` handlers.
- `frontend/flutter/apps/desktop/lib/features/schedule/desktop_schedule_controller.dart`, `schedule_edit_dialogs.dart`, `quiet_hours_card.dart`, `notification_backlog_drawer.dart`, `schedule_screen.dart`, & `windows_toast_adapter.dart`: Added `parseServerUtcDateTime`, `formatDateTime12h`/`formatHhMm12h`, automatic PC timezone defaulting with collapsed *"Custom timezone (advanced)"* toggle, graphical Date + 12h AM/PM Time pickers (`showDatePicker` / `show12HourTimePicker`) with quick-pick chips and Task *"Remind me"* offset chips, Alert Sound toggle + `Test Sound` button in `QuietHoursSettingsCard`, and immediate `_dispatchPendingToasts()` on `refreshAll()`.

### 2.5 Second Live-QA Revision (Sub-2s Adaptive Triggering, Button Copy, Tiered Alerts & Maximized Boot)
- `backend/app/core/config.py` & `backend/app/main.py`: Lowered `SCHEDULER_POLL_INTERVAL_SECONDS` default from `15.0` to `2.0`.
- `frontend/flutter/apps/desktop/lib/features/schedule/desktop_schedule_controller.dart`: Lowered baseline `pollInterval` default to `5s`, added `_nextDueTimer` adaptive wake-up targeting `earliestDue + 2s` strictly when `startPolling()` is active (cancelled on `stopPolling()`/`dispose()`), added `centerPopupForReminders` preference + `setCenterPopupForReminders(bool)` (default `true`), and added `centerPopupAlert` / `topBannerAlert` / `primaryActionLabel()` routing helpers.
- `frontend/flutter/apps/desktop/lib/platform/windows_toast_adapter.dart`, `notification_backlog_drawer.dart`, & `schedule_screen.dart`: Replaced `'Acknowledge'` with crisp non-truncated button labels (`'Stop'` for Alarms, `'Mark Done'` for Task Reminders, `'Got it'` for Standalone Reminders & Routines) across Windows WinRT XML toasts, Backlog Drawer, and Schedule cards.
- `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` & `quiet_hours_card.dart`: Split in-app alerts between `shell_center_alert_modal` (centered modal for Alarms always and Reminders when `"Center Pop-Up for Reminders"` is enabled) and compact floating top-right `shell_active_alert_banner` (`maxWidth: 420` layered above the modal scrim for Routines / non-modal Reminders), and added `"Center Pop-Up for Reminders"` toggle (`center_popup_reminders_switch`) to `QuietHoursSettingsCard`.
- `frontend/flutter/apps/desktop/lib/lifecycle/desktop_window_adapter.dart`, `live_desktop_adapters.dart`, `desktop_lifecycle_coordinator.dart`, & `main.dart`: Added `DesktopWindowAdapter.maximize()` (`windowManager.maximize()`) and `maximizeOnStart` in `DesktopLifecycleCoordinator.initialize()` enabled on standard desktop startup (omitted for explicit `--size-1024x640` / `--capture-visual-evidence` runs).
- Tests (`frontend/flutter/apps/desktop/test/`): Expanded `windows_toast_adapter_test.dart`, `desktop_schedule_controller_test.dart`, `desktop_shell_test.dart`, `desktop_settings_test.dart`, `desktop_layout_responsive_test.dart`, and `desktop_lifecycle_test.dart` (plus mock adapters across test harnesses).

### 2.6 Third Live-QA Revision (Per-Reminder Center Pop-Up, Active Bell Inbox, Click-Outside Dismissal & Focus-Aware Toast Suppression)

Following third-round Windows live QA feedback and Human Owner approval of Option A and `center_popup` default ON:
- **Migration `016_reminder_center_popup` & Per-Item Center Pop-Up (`reminders.center_popup`, `tasks.reminder_center_popup`, default `True`):** Replaced the global Settings `"Center Pop-Up for Reminders"` toggle with per-item `Center Pop-Up Alert` switches inside Create/Edit Reminder and Task dialogs (`schedule_edit_dialogs.dart`). `SchedulerService` propagates `center_popup` / `reminder_center_popup` into `NotificationEvent.urgency` (`"high"` when `True`, `"standard"` when `False`), while keeping Windows toast XML scenarios decoupled strictly on `source_type == 'alarm'`.
- **Safe `POST /api/v1/notifications/mark-all-read` & Option A Bell Active Inbox:** Added `POST /api/v1/notifications/mark-all-read` (backend + `companion_api` + parity gate `67` routes / `61` DTO schemas / `83` covered routes) to stamp `read_at` and transition non-alarm unread/suppressed/catchup rows to `read` while preserving active ringing alarms and full notification audit history. Replaced the Bell drawer and `Schedule -> Notifications` `"Clear All"` action with `Mark All Read`, scoped the Bell drawer (`bellInboxAlerts`) to unresolved alerts only, and added a `History` button jumping straight to `Schedule -> Notifications`.
- **Click-Outside & `Escape` Dismissal:** Added a modal dismiss barrier (`backlog_drawer_dismiss_barrier`) behind `NotificationBacklogDrawer`, prioritized `Escape` closing the drawer before hide-to-tray, and closed the drawer on navigation destination changes.
- **Multi-Monitor Focus-Aware OS Toast Suppression:** Added Win32 `isWindowFocused` on `WindowsToastChannel` (`::IsWindowVisible && !::IsIconic && (foreground == hwnd_ || ::IsChild)` across all monitors). When the desktop app is focused, redundant Windows OS toasts are skipped while still playing the in-app alert chime once when sound is enabled.

---

## 3. Verification Evidence

All automated verification checks ran after final code and test edits and passed with exit code `0`:

- **OpenAPI Contract Check:** `.\backend\.venv\Scripts\python.exe scripts/check_openapi_contract.py --check` -> `OpenAPI contract is up-to-date (67 routes, all required model routes present).` (exit `0`)
- **Dart–OpenAPI Parity Check:** `.\backend\.venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check` -> `[Verified DTO Schemas: 61/61]`, `[M1 + M2 + M3 Native Covered Routes: 83/83]`, `RESULT: ALL CONTRACT PARITY AND ROUTE COVERAGE CHECKS PASSED.` (exit `0`)
- **Backend Full Test Suite:** `.\backend\.venv\Scripts\python.exe -m pytest backend/tests -q` -> `820 passed, 80 warnings in 440.18s (0:07:20)` (exit `0`; warnings are pre-existing aiosqlite/Starlette deprecation notices)
- **Flutter `companion_api` Package Tests:** `dart test` in `frontend/flutter/packages/companion_api` -> `+104: All tests passed!` (exit `0`)
- **Flutter Static Analysis:** `flutter analyze --no-pub` in `frontend/flutter/apps/desktop` -> `No issues found! (ran in 5.0s)` (exit `0`)
- **Flutter Desktop Test Suite:** `flutter test` in `frontend/flutter/apps/desktop` -> `+385: All tests passed!` (exit `0`)
- **Windows Native C++ Debug Build (MSVC `/W4 /WX`):** `flutter build windows --debug` in `frontend/flutter/apps/desktop` -> `√ Built build\windows\x64\runner\Debug\ai_companion_desktop.exe` (exit `0`; `27.0s`)
- **Web Frontend Lint, Tests & Build:** `npm --prefix frontend/web run lint && npm --prefix frontend/web run build` (`✓ built in 5.73s`, exit `0`) and `npm --prefix frontend/web test -- --run --maxWorkers=2` (`Test Files 16 passed (16), Tests 248 passed (248)`, exit `0`)

---

## 4. Pending Manual Verification (Windows Desktop GUI & Action Center OS Checks)

Because automated headless widget tests cannot interact with the live Windows 10/11 Shell Action Center COM service, the following manual verification steps remain for Human Owner execution before squash merge:

- First-boot maximized desktop window launch (while retaining native Windows close-to-tray, maximize/restore toggle, and taskbar icon ergonomics).
- Sub-5s triggering accuracy (~2s–4s from due time) for upcoming Alarms, Reminders, and Routines without manual refresh.
- Visual layout, 12-hour AM/PM date/time pickers + quick chips, UTC/local round-trip consistency across Create -> Display -> Edit (no `-8h` shift), per-item `Center Pop-Up Alert` switches (default ON) in Task & Reminder dialogs, and CRUD verification across all 5 `ScheduleScreen` sections (`Tasks` + `Trash` restore/permanent delete, `Reminders`, `Alarms` (`Stop` / `Snooze 10m` / `Dismiss`) + recurrence, `Routines` `[ Run Now ]`, `Notifications` backlog history + `Mark All Read`) at maximized & narrow widths.
- `SettingsScreen` Quiet Hours 12-hour time pickers, PC timezone default (and optional `"Custom timezone (advanced)"` override), Alert Sound mute switch + `"Test Sound"` button, save persistence, and `422` validation UX.
- `DesktopShell` tiered in-app alerts (`shell_center_alert_modal` centered modal for ringing Alarms + Reminders with per-item `Center Pop-Up Alert` ON; compact floating top-right `shell_active_alert_banner` card for Routines or Reminders with `Center Pop-Up Alert` OFF), top utility strip Bell badge updates, click-outside & `Escape` dismissal of `NotificationBacklogDrawer`, Active Inbox showing unresolved alerts only, `Mark All Read` clearing badge without silencing ringing alarms or deleting history, and `History` jumping to `Schedule -> Notifications`.
- Multi-monitor focus-aware Windows toast suppression: when the desktop app is focused on any monitor, due alerts play the in-app chime without spawning redundant OS toasts; when minimized/tray/unfocused, live Windows 10/11 Action Center toasts appear with chime sound, non-truncated interactive buttons (`Stop`, `Got it`, `Mark Done`, `Open Chat`, `Snooze 10m`, `Dismiss`, `Review Backlog`) from BOTH floating popups and the right-side Windows Notification Center (`Win+N`) restoring the desktop window, two-way Action Center toast removal when acted on inside the app, Quiet Hours `suppressPopup` silence, and Sleep Catch-up summary grouping.

---

## 5. Documentation & Tracking Sync

- Updated canonical domain and infrastructure specs:
  - `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md` (added `### 3.4`, recorded `NIT-01`, fixed `NIT-02` `### 3.5` numbering, updated Section 5 Batch G2 debt items)
  - `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md` (updated Option B native WinRT toast architecture, tests, and resolved `Toast Interaction Actions` gap)
- Synchronized master planning and tracking records:
  - `docs/02_Planning/01_Plans/plan-m3-schedule-ui-windows-toasts-g2.md`
  - `docs/02_Planning/00_Master/WBS.md`
  - `docs/02_Planning/00_Master/MASTER_CHECKLIST.md`
  - `docs/02_Planning/00_Master/DECISION_DEBT.md` (`DEBT-V1-02` resolved)
  - `docs/02_Planning/00_Master/DELIVERY_INDEX.md`
  - `docs/01_Tracking/task.md`
  - `CHANGELOG.md`
- Archived branch execution tracker on the same branch to `docs/01_Tracking/archive/task-feature-m3-schedule-ui-windows-toasts-g2.md`.
