# Implementation Plan: Android Sync Resilience, Form Pickers & Global Pull-to-Refresh

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Branch: `feature/android-sync-resilience-and-task-controls`
Target: Fix Android Companion connection configuration persistence, live Tasks CRUD database synchronization, 12-hour AM/PM Time & Calendar Date pickers, structured reminder presets, and pull-to-refresh on Home and Tasks.

---

## 1. Executive Summary & Goals

This sprint addresses the four critical mobile UX and synchronization defects identified during live physical device testing on the Infinix ZERO ULTRA:
1. **Connection & Sync Value Persistence**: Prevent host IP, port, and pairing key from resetting or disappearing when navigating between screens.
2. **Authoritative Real-Time Tasks Sync**: Fix `saveTask()` and `toggleTaskCompletion()` in `HttpTasksRepository` so task creation issues `POST /api/v1/tasks` and completion toggles issue `PATCH /api/v1/tasks/{id}`, immediately writing to the PC's SQLite database (`data/companion.db`).
3. **Form Controls Overhaul (12-Hour AM/PM + Calendar Picker + Structured Reminders)**: Replace free-text date/time/reminder fields with Material 3 DatePicker, 12-hour TimePicker with AM/PM toggle, and structured reminder interval chips.
4. **Pull-to-Refresh on Home & Tasks**: Provide intuitive swipe-to-refresh gestures across Home and Tasks that query the PC backend, refresh local caches, and update the synchronization status.

Immediately following this pass, the backend security V1.1.1 corrective pass will be executed.

---

## 2. Affected Files & Layer Breakdown

| Component | Target File | Change Type | Purpose |
| :--- | :--- | :--- | :--- |
| **Connection Repo** | `android/app/src/main/java/com/example/data/repository/SharedPreferencesConnectionRepository.kt` | Modify | Ensure synchronous commit of host config and fallback cleanliness. |
| **App State** | `android/app/src/main/java/com/example/ui/shell/AppViewModel.kt` | Modify | Initialize `_uiState` with real connection info; add `refreshAll()` full-sync method. |
| **Connection UI** | `android/app/src/main/java/com/example/ui/screens/connection/ConnectionScreen.kt` | Modify | Bind `HostConfigurationCard` text fields to live state with `LaunchedEffect` and keyed `remember`. |
| **Tasks Sync** | `android/app/src/main/java/com/example/data/repository/HttpTasksRepository.kt` | Modify | Fix `saveTask` (POST new vs PATCH existing) and `toggleTaskCompletion` host routing. |
| **Tasks VM** | `android/app/src/main/java/com/example/ui/screens/tasks/TasksViewModel.kt` | Modify | Add `refreshTasks()` and loading state for pull-to-refresh. |
| **Form Pickers** | `android/app/src/main/java/com/example/ui/screens/tasks/TaskCreateEditSheet.kt` | Modify | Replace raw text inputs with DatePicker, 12-hour TimePicker dialogs, and preset reminder chips. |
| **Tasks UI** | `android/app/src/main/java/com/example/ui/screens/tasks/TasksScreen.kt` | Modify | Wrap list with `PullToRefreshBox` for swipe-to-refresh. |
| **Home UI** | `android/app/src/main/java/com/example/ui/screens/HomeScreen.kt` | Modify | Wrap feed with `PullToRefreshBox` calling `appViewModel.refreshAll()`. |
| **Tests** | `android/app/src/test/java/com/example/NetworkIntegrationUnitTest.kt` | Modify | Expand tests to verify new-task POST vs update PATCH and refresh flows. |

---

## 3. Step-by-Step Logic

### A. Connection State Binding (Fixing the Reset Bug)
1. In `HostConfigurationCard`, bind `hostText`, `portText`, and `tokenText` with `LaunchedEffect(initialHost, initialPort, initialToken)` and `remember(initialHost, initialPort, initialToken)`.
2. When the user navigates into Connection & Sync, if `initialHost` is non-empty, it immediately fills `hostText` with the saved host (e.g. `192.168.254.100`), `portText` with `8000`, and `tokenText` with the saved pairing token.
3. In `AppViewModel`, ensure `_uiState` initializes with `connectionRepository.connectionInfo.value` immediately rather than waiting for collector invocation.

### B. Tasks Database Synchronization (Fixing "Pending in DB" Bug)
1. In `HttpTasksRepository.saveTask(task)`:
   - Check if `task.id` is currently present in `_tasks.value` AND originated from a server response.
   - If it is a new task created on mobile:
     - Optimistically insert into `_tasks`.
     - Issue `runtimeClient.createTask(baseUrl, token, title, description, priority)`.
     - On 201 Created response, replace the temporary local UUID with the server's UUID.
   - If it is an existing task being edited:
     - Optimistically update `_tasks`.
     - Issue `runtimeClient.updateTask(baseUrl, token, taskId = task.id, ...)`.
2. In `HttpTasksRepository.toggleTaskCompletion(taskId)`:
   - Ensure `connectionRepository.getBaseUrl()` and `token` are retrieved from the active repository instance.
   - Dispatch `runtimeClient.updateTask(..., taskId, status = nextStatus)`.
   - On success, mark `connectionRepository.setSyncStatus(SyncStatus.SYNCHRONIZED)`.

### C. 12-Hour AM/PM Time & Calendar Date Pickers
1. In `TaskCreateEditSheet`:
   - Replace the `dueDate` text field with:
     - Quick chips: `[Today]`, `[Tomorrow]`, `[Next Week]`, `[Pick Date...]`.
     - Clicking `[Pick Date...]` triggers Material 3 `DatePickerDialog`.
   - Replace the `dueTime` text field with:
     - Quick chips: `[9:00 AM]`, `[12:00 PM]`, `[6:00 PM]`, `[Pick Time...]`.
     - Clicking `[Pick Time...]` triggers Material 3 `TimePickerDialog` with `is24Hour = false`.
     - Display time with 12-hour format and AM/PM tag.
   - Replace the `reminder` text field with:
     - Selectable chip group: `None`, `At due time`, `15 mins before`, `30 mins before`, `1 hour before`, `1 day before`.

### D. Pull-to-Refresh on Home and Tasks
1. Wrap `TasksScreen` in `PullToRefreshBox(isRefreshing = isRefreshing, onRefresh = { viewModel.refreshTasks() })`.
2. Wrap `HomeScreen` in `PullToRefreshBox(isRefreshing = isRefreshing, onRefresh = { appViewModel.refreshAll() })`.
3. Swiping down on either screen queries the PC backend and updates the live data with zero crashes if offline.

---

## 4. Verification Plan

### Automated Checks
- Run `./gradlew.bat testDebugUnitTest` in `android/` (target: all 115+ tests passing).
- Run `.\.venv\Scripts\pytest` in `backend/` (target: 18/18 tests passing).
- Build and install debug APK:
  ```powershell
  cd android
  .\gradlew.bat installDebug
  ```

### Manual Verification
1. Open Connection & Sync on phone: confirm IP and token are pre-populated.
2. Create a new task with DatePicker and 12-hour TimePicker: confirm it persists to PC SQLite database.
3. Toggle task completion on phone: verify SQLite database updates `status` to `"completed"`.
4. Pull to refresh on Tasks and Home: verify smooth refresh indicator.
