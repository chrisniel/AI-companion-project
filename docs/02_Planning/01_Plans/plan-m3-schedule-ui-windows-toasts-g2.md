# Implementation Plan: M3 Batch G2 — Desktop Schedule UI, Native C++/WinRT Windows Toasts & Quiet Hours

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Implemented & Verified — Ready for Review (Draft PR on `feature/m3-schedule-ui-windows-toasts-g2`; Manual Windows GUI & Action Center Checks Pending)
- **Delivery Level:** Level B — Planned Autonomous
- **Scope Mode:** New Feature — Flutter Desktop Schedule & Routines Workspace (`PC-CLIENT-008`), Native In-Process C++/WinRT Windows Toast Notifications & Interactive Action Center Callbacks (`PC-CLIENT-012` / `PC-HOST-003` client half / `DEBT-V1-02`), Quiet Hours Settings UI, and Batch G1 Review Fold-Ins (`NIT-01`, `NIT-02`)
- **Target Files:**
  - `frontend/flutter/apps/desktop/windows/runner/windows_toast_channel.h` *(ADD)*
  - `frontend/flutter/apps/desktop/windows/runner/windows_toast_channel.cpp` *(ADD)*
  - `frontend/flutter/apps/desktop/windows/runner/CMakeLists.txt` *(MODIFY — compile `windows_toast_channel.cpp`, link `runtimeobject.lib` & `shlwapi.lib`)*
  - `frontend/flutter/apps/desktop/windows/runner/flutter_window.h` *(MODIFY — own `std::unique_ptr<WindowsToastChannel>` & handle `kWmToastActivated` in `MessageHandler`)*
  - `frontend/flutter/apps/desktop/windows/runner/flutter_window.cpp` *(MODIFY — initialize `WindowsToastChannel` on `flutter_controller_->engine()->messenger()` & `GetHandle()`)*
  - `frontend/flutter/apps/desktop/windows/runner/main.cpp` *(MODIFY — call `SetCurrentProcessExplicitAppUserModelID(L"AICompanion.Desktop")` at startup)*
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

- **Primary Objective:** Deliver the user-facing Flutter Desktop Schedule & Routines UI (`PC-CLIENT-008`), native in-process C++/WinRT Windows Action Center Toast notifications with two-way interactive button callbacks & history sync (`PC-CLIENT-012` / `PC-HOST-003` client half / `DEBT-V1-02`), in-app backlog drawer and urgent alert banner, Quiet Hours settings card, and the two non-blocking follow-up fixes from M3 Batch G1 (`NIT-01` & `NIT-02`) on top of PR `#41` (`fe1526e`).
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
  1. **Native In-Process C++/WinRT Toast Channel & Dart Adapter (`DEBT-V1-02` Resolved):** Zero-dependency C++ WRL/WinRT bridge (`WindowsToastChannel`) inside `windows/runner/` registered on `MethodChannel('ai_companion/windows_notifications')` using `ABI::Windows::UI::Notifications` + `ABI::Windows::Data::Xml::Dom` + `runtimeobject.lib` + `shlwapi.lib`:
     - Instant (<5ms) native dispatch with **zero** subprocess spawns and **zero** console-window flash.
     - Explicit process AppUserModelID (`SetCurrentProcessExplicitAppUserModelID(L"AICompanion.Desktop")`) and idempotent `HKCU\Software\Classes\AppUserModelId\AICompanion.Desktop` registration (`DisplayName = L"AI Companion"`).
     - Two-way `Activated` callbacks marshaled safely via `PostMessage` to the Flutter UI thread, routing `[ Mark Done ]`, `[ Acknowledge ]`, `[ Snooze 10m ]`, `[ Dismiss ]`, `[ Open Chat ]`, and `[ Review Backlog ]` straight into `DesktopScheduleController`, plus window restore/focus on foreground actions.
     - Action Center history synchronization (`removeToast`, `clearToasts`) so alerts handled inside the app vanish from Windows 11 Action Center immediately.
  2. **`DesktopScheduleController` & Profile-Fenced Polling Engine:** Profile-scoped, epoch-fenced controller wrapping a dynamic `CompanionClient Function()` provider and `DesktopToastAdapter`, managing Tasks (+ Trash/Restore), Reminders, Alarms, Routines, Notifications backlog, Quiet Hours settings, opt-in background polling (`unreadOnly: true`, `limit: 50`), per-session toast deduplication (`_dispatchedToastEventIds`), interactive toast callback handling, and active `unread` in-app alert banners.
  3. **Flutter Desktop Schedule Workspace (`PC-CLIENT-008`):** Option 2A two-column replacement for the placeholder `ScheduleScreen` across Tasks, Reminders, Alarms, Routines, and Notifications sections with create/edit/delete/snooze/acknowledge/dismiss/restore/run-now actions, real OpenAPI enum status pills, and per-item `bypassQuietHours` override toggle.
  4. **Shell Top Utility Strip, Backlog Drawer & Settings Quiet Hours Card (`PC-CLIENT-012`):** Non-overlapping slim top utility strip in `DesktopShell` housing the active Profile scope indicator, Notification Bell badge button opening `NotificationBacklogDrawer` (with Missed Catch-up banner, chronological timeline, distinct `[ Mark Done ]` vs `[ Dismiss ]` / `[ Clear All ]` controls), urgent In-App Alert Banner above the workspace `Stack`, removal of `'M3'` badge on `DesktopNavDestination.schedule`, and reactive **Notifications & Quiet Hours** card in `SettingsScreen`.
  5. **Batch G1 Review Fold-Ins (`NIT-01` & `NIT-02`):** Separate recurring vs non-recurring recomputation + invalid `clear_time_of_day` / `recurrence_days` `422` guard in `PATCH /api/v1/alarms/{alarm_id}`, and fix duplicate `### 3.3` -> `### 3.4` subsection numbering in `tasks-reminders-alarms-and-routines.md`.
- **Explicit Out-of-Scope:**
  - External Flutter pub dependencies in `frontend/flutter/apps/desktop/pubspec.yaml` (keeps `pubspec.yaml` unchanged by compiling directly against the Windows 10/11 SDK headers already used by `windows/runner/CMakeLists.txt`).
  - Cold-start out-of-process COM `ToastActivated` activator (`--toast-activated` process relaunch when `ai_companion_desktop.exe` is completely terminated). In-process presentation, Action Center interactive buttons, history sync, and foreground restoration while the desktop app is running are fully delivered in Batch G2; out-of-process cold-start COM activation remains linked to `PC-HOST-002` autostart / installer packaging.
  - Cross-Profile notification aggregation (`PC-IDENTITY-002` session isolation prohibits reading notifications across inactive Profiles; the drawer shows an active Profile scope chip instead).
  - Windows Task Scheduler dual autostart (`PC-HOST-002`) and MSI/self-contained installer (`PC-HOST-006`) — remain Milestone M2/M5 items.
  - D9 conversational tool-calling (`PC-ACTION-*`) and Voice pipeline (`PC-VOICE-*`) — remain Milestone M4.
  - New Alembic migrations or OpenAPI schema additions (`contracts/openapi/openapi.json` stays unchanged at `66` URL paths, `93` HTTP operations, and `82` native-covered routes).

---

## 2. Architecture & Technical Approach

- **Current Findings & Technical Baseline:**
  | Observation / Evidence | Verified Interpretation |
  | --- | --- |
  | `frontend/flutter/apps/desktop/windows/CMakeLists.txt` applies `/W4 /WX /wd"4100"`, `/EHsc`, and `_HAS_EXCEPTIONS=0` globally via `APPLY_STANDARD_SETTINGS`, and `windows/runner/CMakeLists.txt` links `dwmapi.lib` against standard Windows SDK libraries. | `WindowsToastChannel` (`windows_toast_channel.h/.cpp`) must be exception-free (using Microsoft WRL `Microsoft::WRL::ComPtr` / `ABI::Windows::*` C++ WinRT ABI interfaces and `HRESULT` error handling) and compile cleanly under `/W4 /WX` with `_HAS_EXCEPTIONS=0`, linking `runtimeobject.lib` and `shlwapi.lib` with zero third-party pub packages. |
  | PR `#41` (`fe1526e`) delivered Migration `015`, `SchedulerService`, all `/api/v1/{tasks,reminders,alarms,routines,notifications}*` + `/profiles/me/quiet-hours` endpoints, and 38 `CompanionClient` Dart SDK methods (`82/82` covered routes, `60/60` DTO schemas). | Backend runtime, persistence, REST endpoints, and typed Dart SDK already exist and are CI-verified. Zero DB migrations or OpenAPI changes are needed. |
  | Exact OpenAPI backend enums (`backend/app/schemas/scheduling.py`): `NotificationStatus` = `unread`, `read`, `acknowledged`, `dismissed`, `snoozed`, `suppressed_quiet_hours`, `missed_catchup`; `ReminderStatus` = `scheduled`, `fired`, `snoozed`, `acknowledged`, `dismissed`, `missed`, `cancelled`; `AlarmStatus` = `armed`, `ringing`, `snoozed`, `acknowledged`, `dismissed`, `missed`; `DeliveryPolicy` = `immediate`, `quiet_hours_suppressed`, `missed_catchup`. | UI badges, controller filters, toast dispatch eligibility, and alert banner filters must match these exact strings (`'unread'`, not `'pending'`, for notifications; `'scheduled'`/`'fired'` and `'armed'`/`'ringing'` for reminders/alarms). |
  | `TaskUpdate` (`task_dto.dart`) takes `clearNotes`, `clearDueDate`, `clearReminderMinutesBefore`, `clearReminderAt` as named parameters on `CompanionClient.updateTask(...)`, whereas `ReminderUpdate`, `AlarmUpdate`, and `RoutineUpdate` (`scheduling_dto.dart`) carry boolean `clear*` fields on the DTOs themselves. | `DesktopScheduleController` and `ScheduleEditDialogs` must respect that exact asymmetry instead of assuming identical DTO signatures. |
  | `DesktopChatController` connects asynchronously after `DesktopShell` mounts (`main.dart`) and may replace its `CompanionClient` in `updateConfiguration()` or switch/expire `authenticatedProfileId`; `DesktopShell._handleProfileChange` currently only listens to `profileController`. | `DesktopScheduleController` must observe **both** `chatController` (`isConnected`, `authenticatedProfileId`, `configEpoch`, `profileEpoch`, `client`) and `profileController`, resolve the current `CompanionClient` dynamically via callback/update, pause polling immediately when disconnected/switching (`!isConnected || profileId == null`), and guard default polling/toasts with `!Platform.environment.containsKey('FLUTTER_TEST')`. |
  | `DesktopShell` places child screens full-bleed inside `Expanded(child: Stack(...))`, where `ChatScreen`, `MemoryScreen`, and `StudioScreen` own top-right header controls. | Placing the Bell badge and In-App Alert Banner in a dedicated non-overlapping top strip above `Expanded` eliminates collisions across every tab. |
  | `desktop_shell_test.dart` currently checks `find.text('M3')` `findsNWidgets(2)` (line 51), `find.text('PLANNED MILESTONE M3')` (line 76), and mounts `DesktopShell(controller: ..., chatController: connectedChat, studioController: ...)` against a 404 `MockClient` (lines 114–175). | Updating `ScheduleScreen` and clearing `'M3'` on `DesktopNavDestination.schedule` requires updating lines `51` (`findsOneWidget`) and `76`, plus keeping `enableSchedulePolling` disabled in `FLUTTER_TEST` by default and `scheduleController` optional on `DesktopShell`/`SettingsScreen`. |
  | `backend/app/api/v1/endpoints/scheduling.py:510-563` only recomputes `Alarm.scheduled_at` when `(as_utc(alarm.scheduled_at) or now) <= now`, and `service.py:165-236` validates Quiet Hours timezones against `UTC`, `UTC±HH:MM`, and `_BUILTIN_IANA_ZONES` (~70 curated zones). | `NIT-01` must distinguish recurring vs non-recurring alarms on `enabled=True` and enforce `422` if `clear_time_of_day=True` leaves `recurrence_days` non-empty; Settings UI must present choices aligned with `_BUILTIN_IANA_ZONES` + `UTC` + `UTC±HH:MM` help text. |

- **Architectural Approach:**
  1. **Native In-Process C++/WinRT Toast Channel (`WindowsToastChannel` + `WindowsWinRtToastAdapter`, `DEBT-V1-02`):**
     - **AUMID & Process Identity (`main.cpp` & `windows_toast_channel.cpp`):**
       - `wWinMain` calls `::SetCurrentProcessExplicitAppUserModelID(L"AICompanion.Desktop")` right after COM initialization.
       - `WindowsToastChannel` performs idempotent Win32 registry setup under `HKCU\Software\Classes\AppUserModelId\AICompanion.Desktop` (`DisplayName = L"AI Companion"`) so unpackaged `ai_companion_desktop.exe` displays cleanly in Windows 10/11 Action Center.
     - **Dart <-> C++ `MethodChannel('ai_companion/windows_notifications')` Contract:**
       - `showToast({required String tag, required String group, required String xml, required bool suppressPopup})`:
         - Loads UTF-16 `xml` into `ABI::Windows::Data::Xml::Dom::IXmlDocument` (`IXmlDocumentIO::LoadXml`), constructs `IToastNotification` (`CreateToastNotification`), sets `Tag` (clamped/hashed to <= 64 chars via `IToastNotification2::put_Tag`) and `Group` (`"ai_companion_alerts"` via `IToastNotification2::put_Group`), sets `SuppressPopup = true` (`IToastNotification4::put_SuppressPopup`) when `suppressPopup == true`, registers an in-process WRL `Activated` handler (`IToastNotification::add_Activated`), and calls `IToastNotifier::Show`.
       - `removeToast({required String tag, required String group})`:
         - Invokes `IToastNotificationManagerStatics2::get_History` -> `RemoveGroupedTagWithId(tag, group, L"AICompanion.Desktop")` when an event is completed, acknowledged, snoozed, or dismissed inside Flutter.
       - `clearToasts({required String group})`:
         - Invokes `RemoveGroupWithId(group, L"AICompanion.Desktop")` on `[ Clear All ]` or active Profile switch/disconnect so Action Center never retains stale alerts from another Profile.
       - `onToastActivated` (Native C++ -> Dart):
         - On Windows WinRT `Activated`, the background MTA/COM thread extracts `IToastActivatedEventArgs::get_Arguments` (`action=...&event_id=...`), allocates an owned payload, and calls `::PostMessageW(hwnd_, kWmToastActivated, ...)` onto the main Win32 UI thread handled by `FlutterWindow::MessageHandler` (never calling `MethodChannel` off the UI thread).
         - On the UI thread, if the action navigates into the app (`open_chat`, `open_backlog`, `open_schedule`, or empty/body click), `WindowsToastChannel` restores (`ShowWindow(hwnd_, SW_RESTORE)` if minimized) and foregrounds `hwnd_` (`SetForegroundWindow(hwnd_)`), then sends `channel_->InvokeMethod("onToastActivated", EncodableValue(EncodableMap{{"arguments": args}}))` to Dart.
     - **Dart `DesktopToastAdapter` & Rich `buildToastXml`:**
       - `DesktopToastAdapter` exposes `showNotificationToast(NotificationEventOut event)`, `showMissedCatchupSummaryToast({required int missedCount, required List<NotificationEventOut> events})`, `removeNotificationToast(String eventId)`, `clearAllNotificationToasts()`, and `Stream<ToastActivationEvent> get activations`.
       - `WindowsWinRtToastAdapter` uses `MethodChannel('ai_companion/windows_notifications')` (injectable via `MethodChannel` or test handler in Dart unit tests; automatically selects `NoOpDesktopToastAdapter` when `!Platform.isWindows` or `Platform.environment.containsKey('FLUTTER_TEST')` unless explicitly injected for tests).
       - Sanitizes every title/body with `sanitizeXmlText(...)` (stripping invalid XML 1.0 control chars `\x00-\x08`, `\x0B-\x0C`, `\x0E-\x1F`) and `escapeXml(...)` (`&`, `<`, `>`, `"`, `'`).
       - Generates interactive `<toast>` XML:
         - **Live Active Alarm** (`(sourceType == 'alarm' || urgency == 'high') && deliveryPolicy != 'quiet_hours_suppressed' && !isMissedCatchup`): `<toast scenario="alarm" launch="action=open_schedule&amp;event_id=...">` with `<audio src="ms-winsoundevent:Notification.Looping.Alarm" loop="true"/>` and `<actions>`: `[ Acknowledge ]` (`action=acknowledge&event_id=...`), `[ Snooze 10m ]` (`action=snooze_10m&event_id=...`), `[ Dismiss ]` (`action=dismiss&event_id=...`).
         - **Task-Linked Reminder** (`taskId != null`): `<toast scenario="reminder" launch="action=open_schedule&amp;event_id=...">` with `<actions>`: `[ Mark Done ]` (`action=mark_done&event_id=...`), `[ Snooze 10m ]` (`action=snooze_10m&event_id=...`), `[ Dismiss ]` (`action=dismiss&event_id=...`).
         - **Standalone Reminder** (`sourceType == 'reminder' && taskId == null`): `<toast scenario="reminder" launch="action=open_schedule&amp;event_id=...">` with `<actions>`: `[ Acknowledge ]`, `[ Snooze 10m ]`, `[ Dismiss ]`.
         - **Routine** (`sourceType == 'routine'`): default `<toast launch="action=open_chat&amp;event_id=...">` with `<actions>`: `[ Open Chat ]` (`action=open_chat&event_id=...`), `[ Acknowledge ]`, `[ Dismiss ]`.
         - **Quiet-Hours Suppressed Reminders** (`deliveryPolicy == 'quiet_hours_suppressed'` on `reminder`/`task_reminder`): `<audio silent="true"/>` + `suppressPopup: true` (lands silently in Action Center without popup flash; suppressed `routine` events are skipped from OS toast dispatch).
         - **Consolidated Catch-up Summary** (`showMissedCatchupSummaryToast`): standard `<toast launch="action=open_backlog">` (never `scenario="alarm"`) with `<audio silent="true"/>` and `<action content="Review Backlog" arguments="action=open_backlog" activationType="foreground"/>`.
       - Every action button sets `activationType="foreground"` with URI query-encoded arguments (`Uri(queryParameters: ...).query`) so `Activated` callbacks fire deterministically in-process.
  2. **Schedule Controller, Two-Way Callback Handling & Polling Architecture (`DesktopScheduleController`):**
     - Constructed with `{required CompanionClient Function() clientProvider, DesktopToastAdapter? toastAdapter, String? profileId, Duration pollInterval = const Duration(seconds: 15), void Function(ToastNavigationTarget target)? onNavigateRequested}`.
     - Listens to `toastAdapter.activations` and dispatches incoming OS Action Center button clicks safely inside the active `_scopeEpoch` guard:
       - `mark_done` -> `acknowledgeNotification(eventId, completeTask: true)`
       - `acknowledge` -> `acknowledgeNotification(eventId)`
       - `snooze_10m` -> `snoozeNotification(eventId, minutes: 10)`
       - `dismiss` -> `dismissNotification(eventId)`
       - `open_chat` -> marks read/invokes navigation callback to `DesktopNavDestination.chat`
       - `open_backlog` / `open_schedule` -> invokes navigation callback to open `NotificationBacklogDrawer` / `DesktopNavDestination.schedule`
     - Maintains Action Center sync: whenever `acknowledgeNotification`, `snoozeNotification`, `dismissNotification`, `clearAllNotifications`, `completeTask` (linked reminders), or `updateProfileScope` / `clearForDisconnect` runs, calls `toastAdapter.removeNotificationToast(eventId)` or `clearAllNotificationToasts()` so Action Center stays clean.
     - `pollNotifications()` queries `clientProvider().listNotifications(unreadOnly: true, limit: 50)` so historical resolved items never crowd out newer unread or catch-up alerts:
       - Toast candidate statuses: `{'unread', 'suppressed_quiet_hours', 'missed_catchup'}`.
       - Filters unseen items (`!_dispatchedToastEventIds.contains(event.id)`): aggregates unseen `isMissedCatchup == true` events into one silent catch-up summary toast; dispatches live non-suppressed items individually; records IDs in `_dispatchedToastEventIds` (unresolved `unread`/`missed_catchup` items intentionally re-surface once per desktop session on app relaunch).
       - Computes `activeAlerts`: strictly `status == 'unread'` (excluding `suppressed_quiet_hours` and `missed_catchup`), sorted `high` urgency first, then newest first.
     - Polling timer (`startPolling()` / `stopPolling()`) is opt-in (started by `DesktopShell` only when connected, authenticated with a non-null `profileId`, `enableSchedulePolling != false`, and `!Platform.environment.containsKey('FLUTTER_TEST')`), and cancelled cleanly in `dispose()`.
  3. **Option 2A Schedule Workspace & Backlog UX:**
     - Follows `MemoryScreen` / `MemoryTierSidebar` visual system (`SoftGlassPanel`, `NeumorphicSurface`, `CompanionThemeExtension`, `>= 720px` side-by-side vs `< 720px` compact horizontal bar).
     - 5 workspace sections matching backend domains (**Tasks** + **Trash/Restore**, **Reminders**, **Alarms**, **Routines**, **Notifications**), respecting `CompanionClient.updateTask(...)` named clear flags vs DTO `clear*` fields, exact OpenAPI status pills, explicit re-arm (`status: 'armed'`, `clearSnoozedUntil: true`) + `clearRecurrenceDays: true` when converting Alarms to one-shot, and distinct `[ Mark Done ]` (`completeTask: true`) vs `[ Dismiss ]` / `[ Clear All ]` semantics.
  4. **Shell Top Utility Strip, Backlog Drawer & Settings Quiet Hours UI:**
     - `DesktopShell` renders a compact slim top utility strip (above `Expanded(child: Stack(...))` inside the main content `Column`) showing the active Profile scope pill (when connected) and the Notification Bell button with unread/missed badge, opening `NotificationBacklogDrawer` from the right edge (width capped safely for `1024x640` at `1.3x` text scale).
     - When `activeAlerts` (`status == 'unread'`) is non-empty, `DesktopShell` renders a dismissible `SoftGlassPanel` Active Alert Banner between the top utility strip and `Expanded(child: Stack(...))`.
     - `SettingsScreen` adds `_buildQuietHoursCard` observing `DesktopScheduleController` reactively (reloading immediately if profile changes while already in Settings), presenting `Enable Quiet Hours`, `Start`/`End` `HH:MM`, timezone selector backed by `_BUILTIN_IANA_ZONES` + `'UTC'` + `'UTC±HH:MM'`, Save `422` validation feedback, and `"Alarms bypass quiet hours by default to ensure wakefulness."`

- **Contract & Schema Impact:**
  - Zero Alembic migrations and zero new REST routes or OpenAPI schema changes (`contracts/openapi/openapi.json` stays unchanged at `66` URL paths, `93` HTTP operations, and `82` native-covered routes; `scripts/check_openapi_contract.py --check` and `scripts/check_dart_openapi_parity.py --check` remain green).
  - Existing endpoint refinement (`NIT-01`): `PATCH /api/v1/alarms/{alarm_id}` in `backend/app/api/v1/endpoints/scheduling.py` fixes recurring vs non-recurring recomputation and validates invalid `clear_time_of_day` + `recurrence_days` combinations with HTTP `422`. Response schema `AlarmOut` is unchanged.

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `frontend/flutter/apps/desktop/windows/runner/windows_toast_channel.h` & `.cpp`
- **Primary Responsibility:** Native C++ WRL/WinRT `ToastNotificationManager` bridge (`MethodChannel('ai_companion/windows_notifications')`) inside `ai_companion_desktop.exe` (`DEBT-V1-02`).
- **Planned Change:**
  - Register `HKCU\Software\Classes\AppUserModelId\AICompanion.Desktop` (`DisplayName = L"AI Companion"`) idempotently.
  - Handle `showToast`, `removeToast`, and `clearToasts` via exception-free WRL (`ABI::Windows::UI::Notifications`, `ABI::Windows::Data::Xml::Dom`, `HRESULT` checks compatible with `/W4 /WX` and `_HAS_EXCEPTIONS=0`).
  - Subscribe to `IToastNotification::add_Activated`, marshal `IToastActivatedEventArgs::get_Arguments` to the UI thread via `PostMessageW(hwnd_, kWmToastActivated, ...)`, restore/foreground `hwnd_` on foreground actions, and invoke `onToastActivated` on Dart.
- **Invariants to Preserve:** Compile cleanly under `/W4 /WX /EHsc` + `_HAS_EXCEPTIONS=0`; never invoke Flutter `MethodChannel` from a WinRT/COM background thread; clamp toast `Tag` to `<= 64` chars and safely release message-posted allocations even on window teardown.

### [MODIFY] `frontend/flutter/apps/desktop/windows/runner/{CMakeLists.txt, flutter_window.h, flutter_window.cpp, main.cpp}`
- **Primary Responsibility:** Wire `WindowsToastChannel` and process AUMID into the Windows desktop runner.
- **Planned Change:** Set process AUMID in `main.cpp`; compile `windows_toast_channel.cpp` and link `runtimeobject.lib` + `shlwapi.lib` in `runner/CMakeLists.txt`; initialize `WindowsToastChannel` in `FlutterWindow::OnCreate`, route `kWmToastActivated` in `FlutterWindow::MessageHandler`, and clean up in `FlutterWindow::OnDestroy`.
- **Invariants to Preserve:** Preserve existing window sizing, dark-mode title bar behavior, and single-instance/console attachment behavior.

### [ADD] `frontend/flutter/apps/desktop/lib/platform/windows_toast_adapter.dart`
- **Primary Responsibility:** Dart `DesktopToastAdapter` interface, `NoOpDesktopToastAdapter`, `WindowsWinRtToastAdapter(MethodChannel)`, XML sanitization/escaping, and two-way activation stream.
- **Planned Change:** Build interactive `ToastGeneric` XML payloads (`buildToastXml` with `sanitizeXmlText`, `escapeXml`, URL-encoded action arguments), invoke `showToast` / `removeToast` / `clearToasts`, parse incoming `onToastActivated` method calls into typed `ToastActivationEvent` values, and fail softly (`debugPrint` + `false`) on non-Windows/restricted environments.
- **Invariants to Preserve:** Never throw uncaught exceptions on headless/test hosts; zero PowerShell subprocesses; gate live alarm `scenario="alarm"` + looping sound strictly to non-suppressed non-catch-up alarms.

### [ADD] `frontend/flutter/apps/desktop/lib/features/schedule/desktop_schedule_controller.dart`
- **Primary Responsibility:** Profile-scoped, epoch-fenced state management, REST orchestration, two-way OS toast callback execution, opt-in polling (`unreadOnly: true`, `limit: 50`), and Action Center history cleanup.
- **Planned Change:** Wrap `CompanionClient Function()` provider and `DesktopToastAdapter`, listen to connection/profile state + `toastAdapter.activations`, sync Action Center removal on in-app actions/profile switches, expose `tasks`, `trashTasks`, `reminders`, `alarms`, `routines`, `notifications`, `unreadCount`, `missedCount`, `activeAlerts` (`status == 'unread'`), `quietHours`, full CRUD/action methods, and opt-in polling lifecycle.
- **Invariants to Preserve:** Clear cached data, `activeAlerts`, `_dispatchedToastEventIds`, and OS Action Center group immediately on profile switch or disconnect; never start periodic timers inside `FLUTTER_TEST` by default.

### [ADD] `frontend/flutter/apps/desktop/lib/features/schedule/{schedule_sidebar.dart, schedule_edit_dialogs.dart, notification_backlog_drawer.dart}`
- **Primary Responsibility:** Option 2A sub-navigation rail, validated create/edit modals, and right slide-out Notification Backlog Drawer.
- **Planned Change:** Match `MemoryTierSidebar` & `SoftGlassPanel` conventions, support all Task/Reminder/Alarm/Routine fields & `clear*` rules cleanly, display active Profile scope chip + Missed Catch-up summary + chronological timeline + distinct `[ Mark Done ]` vs `[ Dismiss ]` / `[ Clear All ]`.
- **Invariants to Preserve:** Zero layout overflow at `1024x640` minimum viewport and `1.3x` text scale factor.

### [MODIFY] `frontend/flutter/apps/desktop/lib/screens/schedule_screen.dart` & `lib/controllers/desktop_settings_controller.dart`
- **Primary Responsibility:** Live `PC-CLIENT-008` Schedule & Routines workspace and nav badge activation.
- **Planned Change:** Replace the static `'PLANNED MILESTONE M3'` placeholder with the 5-tab Option 2A workspace and remove `badge: 'M3'` from `DesktopNavDestination.schedule` (leaving `studio` and `voice` badges untouched).
- **Invariants to Preserve:** Keep `'Schedule & Routines'` heading and `'Proactive triggers, reminders, and daily habits'` subtitle; degrade gracefully when unauthenticated or disconnected.

### [MODIFY] `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` & `lib/main.dart` & `lib/screens/settings_screen.dart`
- **Primary Responsibility:** App-wide shell top utility strip, Alert Banner, Drawer hosting, navigation callback wiring (`open_chat`, `open_backlog`, `open_schedule`), reactive profile/connection lifecycle, and Settings Quiet Hours card.
- **Planned Change:** Wire `DesktopScheduleController` + `WindowsWinRtToastAdapter` cleanly (guarded by `!Platform.environment.containsKey('FLUTTER_TEST')`), render non-overlapping top strip + `unread` Alert Banner above `Expanded(child: Stack(...))`, and add `_buildQuietHoursCard` to `SettingsScreen`.
- **Invariants to Preserve:** Existing constructors calling `DesktopShell(controller: ...)` or `SettingsScreen(controller: ...)` with no `scheduleController` or `chatController` keep compiling cleanly without orphan timers or native channel failures.

### [MODIFY] `backend/app/api/v1/endpoints/scheduling.py` & `backend/tests/test_scheduling_api.py` (`NIT-01`)
- **Primary Responsibility:** Recompute `Alarm.scheduled_at` accurately on parameter updates and guard invalid recurrence combinations (`clear_time_of_day=True` with non-empty `recurrence_days` -> HTTP `422`), preserving non-recurring future alarms on disable->re-enable.
- **Invariants to Preserve:** Explicit `payload.scheduled_at` always takes precedence; disabled/dismissed/acknowledged alarms are never unexpectedly re-armed.

### [MODIFY] `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md` (`NIT-02` + Phase 3)
- **Primary Responsibility:** Fix duplicate `### 3.3` heading (`NIT-02` -> `### 3.4`) and document delivered Batch G2 Desktop UI + native C++/WinRT Toast capabilities during Phase 3.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Step 1 — Backend Review Fold-In (`NIT-01`) & Regression Tests:**
   - Write failing tests in `backend/tests/test_scheduling_api.py` covering future recurring param edits recomputing `scheduled_at`, non-recurring disable->re-enable preserving future `scheduled_at`, and `clear_time_of_day=True` with active `recurrence_days` returning `422` (RED).
   - Update `update_alarm` in `backend/app/api/v1/endpoints/scheduling.py` (GREEN) and run `backend/tests/test_scheduling_api.py` + `test_scheduler_service.py`.
2. **Step 2 — Native C++/WinRT Runner Channel & Dart Toast Adapter (`DEBT-V1-02`):**
   - Write Dart unit tests in `frontend/flutter/apps/desktop/test/windows_toast_adapter_test.dart` covering XML escaping + XML 1.0 control-char stripping, live alarm `<toast scenario="alarm">` + interactive `<actions>`, task-linked `[ Mark Done ]` vs `[ Acknowledge ]` / `[ Snooze 10m ]` / `[ Dismiss ]` / `[ Open Chat ]` actions, Quiet Hours `suppressPopup: true` + `<audio silent="true"/>`, catch-up summary toast + `[ Review Backlog ]`, `removeToast` / `clearToasts` method channel calls, incoming `onToastActivated` parsing, and soft failure resilience via `TestDefaultBinaryMessenger` (RED).
   - Implement `windows_toast_channel.h/.cpp`, runner CMake/window/main updates, and `windows_toast_adapter.dart` (GREEN), and verify native Windows compilation (`flutter build windows --debug`).
3. **Step 3 — `DesktopScheduleController` & Callback/Polling/History Tests:**
   - Write unit tests in `frontend/flutter/apps/desktop/test/desktop_schedule_controller_test.dart` covering initial load across Tasks/Trash/Reminders/Alarms/Routines/Notifications/QuietHours, `updateTask` clear flags vs DTO `clear*` fields, `unreadOnly: true` polling pagination, routine quiet-hours skip, missed catch-up consolidation, `activeAlerts` excluding `suppressed_quiet_hours` and `missed_catchup`, two-way `toastAdapter.activations` handling (`mark_done`, `acknowledge`, `snooze_10m`, `dismiss`, `open_chat`, `open_backlog`), `removeNotificationToast` / `clearAllNotificationToasts` Action Center sync, dynamic client updates + disconnect/profile-switch `_scopeEpoch` cancellation, and opt-in polling lifecycle (RED).
   - Implement `frontend/flutter/apps/desktop/lib/features/schedule/desktop_schedule_controller.dart` (GREEN).
4. **Step 4 — Schedule Screen, Sub-Components, Drawer, Shell Utility Strip & Settings Quiet Hours UI:**
   - Write/update widget tests in `schedule_screen_test.dart`, `notification_backlog_drawer_test.dart`, `desktop_shell_test.dart` (updating line `51` `findsNWidgets(2)` -> `findsOneWidget` and line `76`), `desktop_settings_test.dart`, and `desktop_layout_responsive_test.dart` (verifying `1024x640` at `1.3x` text scale with Bell strip + Alert banner active and zero overflow) (RED).
   - Implement `schedule_sidebar.dart`, `schedule_edit_dialogs.dart`, `notification_backlog_drawer.dart`, updated `schedule_screen.dart`, `desktop_settings_controller.dart`, `desktop_shell.dart`, `main.dart`, and `settings_screen.dart` Quiet Hours card (GREEN).
5. **Step 5 — Full Automated Verification Gate:**
   - Run all contract parity checks (`check_openapi_contract.py --check`, `check_dart_openapi_parity.py --check`), backend `pytest backend/tests -q`, `dart test` (`companion_api`), `flutter analyze`, full `flutter test` (`apps/desktop`), native Windows runner compile check (`flutter build windows --debug` in `frontend/flutter/apps/desktop`), and `frontend/web` lint/test/build.
6. **Step 6 — Phase 3 Documentation, Closure & Draft PR:**
   - Sync `tasks-reminders-alarms-and-routines.md` (including `NIT-02`), `windows-host-and-notifications.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md` (`DEBT-V1-02` marked resolved for presentation & in-process callbacks; optional cold-start COM server when terminated noted under `PC-HOST-002` / future polish), `DELIVERY_INDEX.md`, `docs/01_Tracking/task.md`, and `CHANGELOG.md`.
   - Author walkthrough `docs/03_Walkthroughs/walkthrough-m3-batch-g2-schedule-ui-windows-toasts.md`, archive `task-feature-m3-schedule-ui-windows-toasts-g2.md`, commit, push, and open a Draft PR against `develop`, supplying the interactive manual Windows UI checklist and plain-text squash merge summary when ready.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Contract & Dart SDK parity checks: `.\backend\.venv\Scripts\python.exe scripts/check_openapi_contract.py --check` and `.\backend\.venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check`
- [ ] Backend full suite: `.\backend\.venv\Scripts\python.exe -m pytest backend/tests -q`
- [ ] Dart SDK package tests: `dart test` in `frontend/flutter/packages/companion_api`
- [ ] Flutter workspace static analysis: `flutter analyze` in `frontend/flutter`
- [ ] Flutter Desktop full suite (unit + widget + responsive overflow): `flutter test` in `frontend/flutter/apps/desktop`
- [ ] Native Windows C++ runner compile verification (`/W4 /WX`): `flutter build windows --debug` in `frontend/flutter/apps/desktop`
- [ ] Web harness checks (regression check): `npm --prefix frontend/web run lint && npm --prefix frontend/web test -- --run && npm --prefix frontend/web run build`

### Manual & Host-Level Checks (Where Applicable — UI Implemented/Modified)
- [ ] Interactive manual Windows desktop UI & Action Center C++/WinRT Toast verification checklist (to be provided in full at Phase 3/4 handoff per user preference whenever UI changes: launching `ai_companion_desktop`, verifying Schedule 5-tab workspace, creating/editing Task/Reminder/Alarm/Routine, toggling Quiet Hours in Settings across timezones, verifying instant native Windows 11 Action Center toasts with zero console flash, clicking interactive toast buttons `[ Mark Done ]` / `[ Snooze 10m ]` / `[ Dismiss ]` / `[ Open Chat ]` / `[ Review Backlog ]` to verify backend mutation + window focus restoration, and confirming alerts handled in-app disappear cleanly from Action Center).

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *C++ `/W4 /WX` and `_HAS_EXCEPTIONS=0` compiler strictness in `windows/CMakeLists.txt`:* Implement `WindowsToastChannel` strictly with Microsoft WRL (`ComPtr`, `RoGetActivationFactory`, `WindowsCreateStringReference`) and explicit `HRESULT` checks instead of C++/WinRT throwing exceptions, verified with `flutter build windows --debug`.
  - *Cross-thread callback crash on WinRT `Activated`:* WinRT fires `Activated` on a COM worker thread; marshal arguments strictly to the Win32 UI thread via `::PostMessageW(hwnd_, kWmToastActivated, ...)` before calling `flutter::MethodChannel::InvokeMethod`, and guard destroyed/null `hwnd_` cleanly on `OnDestroy`.
  - *Widget tests hanging on `Timer.periodic` or touching Windows native channels:* Polling starts only via `startPolling()` when live connected outside `FLUTTER_TEST`, and `WindowsWinRtToastAdapter` / `DesktopShell` fall back to `NoOpDesktopToastAdapter` during `FLUTTER_TEST`.
  - *Toast spam after PC sleep/hibernate:* `pollNotifications()` queries `unreadOnly: true` (`limit: 50`), aggregates unseen `isMissedCatchup == true` events into one consolidated catch-up summary toast per poll batch, and tracks `_dispatchedToastEventIds` per desktop session.
  - *Mid-switch `401`s or cross-Profile leaks:* `DesktopScheduleController` listens dynamically to both `chatController` and `profileController`, clears state + `_dispatchedToastEventIds` + Windows Action Center toast group immediately when `!isConnected || profileId == null`, and increments `_scopeEpoch` to discard stale responses.
- **Dependencies & Assumptions:** Uses built-in Windows 10/11 SDK WRL/WinRT headers and `runtimeobject.lib` / `shlwapi.lib` already available in the Windows Flutter toolchain (`pubspec.yaml` unchanged).
- **Required Permissions:** Task-bounded feature branch (`feature/m3-schedule-ui-windows-toasts-g2`), commits, push, and Phase 3 Draft PR against `develop`. Human Owner retains exclusive merge authority.
- **Genuine Stop Conditions:** Material scope expansion beyond Batch G2, unexpected need to add external `pubspec.yaml` / `requirements.txt` dependencies, API contract mismatches requiring DB/OpenAPI breaking changes, or unresolvable C++/Flutter/CI failures.
