# Walkthrough: Android Backend Connection & Live Tasks Integration

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Branch: `feature/android-backend-connection-and-tasks`

---

## 1. What Was Delivered

This delivery establishes the first live vertical slice connecting the Android Companion app directly to the Local AI Runtime (PC FastAPI backend):
- **Network Permissions & Security**: Added `INTERNET` and `ACCESS_NETWORK_STATE` permissions, and configured `network_security_config.xml` to permit cleartext HTTP across private RFC 1918 subnets (`192.168.x.x`, `10.x.x.x`, `172.16.x.x`, Tailscale `100.x.x.x`, and local emulator loopbacks).
- **Persistent Connection Configuration**: Implemented `SharedPreferencesConnectionRepository` ensuring PC host IP, port, and pairing key persist across process recreation and device reboots.
- **Reachability & Token Handshake**: Wired `ConnectionScreen`'s "Save & Test Reachability" action to probe `GET /api/v1/health` and verify `POST /api/v1/auth/verify`, dynamically measuring round-trip latency and transitioning status badges between "Local LAN" (Green) and "PC Offline" (Muted).
- **Live Tasks Synchronization**: Implemented `HttpTasksRepository` with optimistic local UI updates and asynchronous synchronization with the PC's SQLite database (`companion.db`), featuring graceful offline fallback so the app never crashes when the host PC is unreachable.
- **Dependency & Build Pipeline**: Integrated OkHttp 4.12.0 into Gradle catalog without adding heavy annotation processors or reflection libraries.
- **Zero Regressions & 100% Pass Rate**: Added 5 new integration tests in `NetworkIntegrationUnitTest.kt`, expanding the Android test suite to **115 passing tests** in 1m 42s, and successfully compiled `app-debug.apk` (19.89 MB).

---

## 2. Files Changed

| File | Change Type | Purpose |
| :--- | :--- | :--- |
| [`android/app/src/main/AndroidManifest.xml`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/AndroidManifest.xml) | Modify | Added INTERNET permissions and linked `network_security_config`. |
| [`android/app/src/main/res/xml/network_security_config.xml`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/res/xml/network_security_config.xml) | New | Security policy allowing cleartext HTTP on local private LAN subnets and user certs. |
| [`android/gradle/libs.versions.toml`](file:///d:/OtherProjects/AI-companion-project/android/gradle/libs.versions.toml) | Modify | Added OkHttp 4.12.0 catalog entries. |
| [`android/app/build.gradle.kts`](file:///d:/OtherProjects/AI-companion-project/android/app/build.gradle.kts) | Modify | Included `libs.okhttp` dependency. |
| [`android/app/src/main/java/com/example/domain/model/ConnectionStatus.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/ConnectionStatus.kt) | Modify | Added optional `token` field to `ConnectionInfo`. |
| [`android/app/src/main/java/com/example/domain/repository/ConnectionRepository.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/repository/ConnectionRepository.kt) | New | Domain repository interface for connection settings and reachability state. |
| [`android/app/src/main/java/com/example/data/repository/SharedPreferencesConnectionRepository.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/repository/SharedPreferencesConnectionRepository.kt) | New | Production persistent storage for host IP, port, and pairing key. |
| [`android/app/src/main/java/com/example/data/network/dto/NetworkDtos.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/network/dto/NetworkDtos.kt) | New | DTOs matching OpenAPI schemas for health telemetry and remote tasks. |
| [`android/app/src/main/java/com/example/data/network/LocalAiRuntimeClient.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/network/LocalAiRuntimeClient.kt) | New | OkHttp client executing health probes, pairing verification, and tasks CRUD. |
| [`android/app/src/main/java/com/example/data/repository/HttpTasksRepository.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/data/repository/HttpTasksRepository.kt) | New | Synchronizes mobile tasks with PC SQLite database with local cache fallback. |
| [`android/app/src/main/java/com/example/di/AppContainer.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/di/AppContainer.kt) | Modify | Exposed `connectionRepository` and wired `HttpTasksRepository` as authoritative tasks repository. |
| [`android/app/src/main/java/com/example/ui/AppViewModelProvider.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/AppViewModelProvider.kt) | Modify | Injected `connectionRepository` into `AppViewModel`. |
| [`android/app/src/main/java/com/example/ui/shell/AppViewModel.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppViewModel.kt) | Modify | Added `saveHostConfig` and `testConnectionReachability` methods. |
| [`android/app/src/main/java/com/example/ui/screens/connection/ConnectionScreen.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/connection/ConnectionScreen.kt) | Modify | Connected `HostConfigurationCard` to live save and reachability testing callback. |
| [`android/app/src/main/java/com/example/ui/shell/AppShell.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppShell.kt) | Modify | Wired navigation route for `ConnectionScreen` to `AppViewModel.saveHostConfig`. |
| [`android/app/src/test/java/com/example/NetworkIntegrationUnitTest.kt`](file:///d:/OtherProjects/AI-companion-project/android/app/src/test/java/com/example/NetworkIntegrationUnitTest.kt) | New | Automated unit tests for configuration persistence, reachability, and optimistic mutations. |
| [`docs/01_Tracking/task.md`](file:///d:/OtherProjects/AI-companion-project/docs/01_Tracking/task.md) | Modify | Updated active tracking checklist to completed status. |

---

## 3. How the Logic Works

### Event Trigger
The user navigates to **Connection & Sync** on their phone, enters the host PC's Wi-Fi IP address (e.g. `192.168.1.15`), port `8000`, and the pairing token, then taps **Save & Test Reachability**.

### Validation & Reachability Probe
1. `AppViewModel.saveHostConfig()` persists the settings into `SharedPreferencesConnectionRepository`.
2. The UI state updates to `CoreConnectionState.Connecting` ("Connecting...").
3. In a background IO coroutine, `LocalAiRuntimeClient.checkHealth()` issues `GET /api/v1/health`.
4. If successful, round-trip latency is calculated and state transitions to `CoreConnectionState.Local` with the latency in milliseconds.
5. If a token was provided, `verifyToken()` immediately tests `POST /api/v1/auth/verify` with `Authorization: Bearer <token>`.

### Tasks Synchronization Flow
1. When visiting the **Tasks** screen, `HttpTasksRepository` invokes `getTasks(baseUrl, token)`.
2. On 200 OK response, the backend JSON array is parsed into `RemoteTaskDto` and mapped to `MobileTask` items in `_tasks: StateFlow`.
3. If the host database is empty, the screen renders its empty state (*"No tasks yet"*).
4. When the user taps **+** to add a task, `addNewTask()` immediately inserts the item into `_tasks` optimistically (zero UI lag) and launches a background POST to `/api/v1/tasks`.
5. Upon 201 Created from FastAPI, the temporary local UUID is swapped with the authoritative database UUID.

### Recovery & Offline Handling
If the PC is turned off, Wi-Fi drops, or connection fails:
- The health probe transitions `connectionInfo.state` to `CoreConnectionState.Offline` and sets `syncStatus = SyncStatus.FAILED`.
- The top connection banner calmly displays *"PC Offline • Local mobile mode active"*.
- `HttpTasksRepository` retains all cached in-memory tasks without throwing unhandled exceptions or crashing the app.

---

## 4. Key Concepts

1. **Optimistic UI Updates**: A pattern where user interface state is updated immediately upon user input before the network request completes. If the network call fails later, the sync status is updated to Pending or Failed without freezing the UI.
2. **Network Security Config**: An Android XML file introduced in Android 7 (API 24) and enforced by default in Android 9 (API 28) that customizes network security settings without modifying application code, used here to permit cleartext HTTP over local Wi-Fi.
3. **Graceful Degradation / Air-Gapped Fallback**: An architectural resilience pattern where client applications continue operating using local caches and capabilities when backend dependencies are unreachable, preventing the app from locking up or crashing.

---

## 5. Verification Steps

### Automated Checks
1. **Unit & Integration Tests**:
   ```bash
   cd android
   .\gradlew testDebugUnitTest
   ```
   **Result**: 115 tests passed in 1m 42s (0 failures, 100% pass rate).
2. **APK Compilation Check**:
   ```bash
   .\gradlew assembleDebug
   ```
   **Result**: `app-debug.apk` (19.89 MB) built successfully in `app/build/outputs/apk/debug/`.
3. **Backend Security Suite**:
   ```bash
   cd ../backend
   .\.venv\Scripts\pytest -v
   ```
   **Result**: 18 tests passed in 0.38s (0 failures, 100% pass rate).

### Manual Verification (User-Owned Physical Device Check)
1. **Find Host PC Wi-Fi IP**: In terminal run `ipconfig` (e.g. `192.168.1.X`).
2. **Ensure Backend is Listening**: Run uvicorn bound to `0.0.0.0`:
   ```bash
   cd backend
   .\.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
3. **Install APK on Phone**: Copy `app-debug.apk` to your phone or install via ADB:
   ```bash
   adb install -r android/app/build/outputs/apk/debug/app-debug.apk
   ```
4. **Configure Connection**:
   - Open Companion on phone -> tap top-bar connection badge or go to **Connection & Sync**.
   - Input your PC's IP, port `8000`, and the token from `backend/.env`.
   - Tap **Save & Test Reachability**.
   - Verify badge turns Green ("Local LAN Active") with measured latency in ms.
5. **Verify Live Tasks CRUD**:
   - Navigate to **Tasks** screen.
   - Tap **+** to add a task (e.g. "Test from Infinix phone").
   - Open `http://127.0.0.1:8000/docs` in your browser on PC and execute `GET /api/v1/tasks` -> Verify the task is stored in SQLite!

---

## 6. Safe Customization & Invariants

- **Host Address**: Any local LAN IP (`192.168.X.X`), Tailscale IP (`100.X.X.X`), or hostname can be entered into the settings UI.
- **Timeout Values**: In `LocalAiRuntimeClient.kt`, connect and read timeouts are set to 5s and 8s respectively to prevent hanging on unreachable hosts.
- **Invariant**: The app must never crash if the host PC is offline or uncontactable.
- **Invariant**: The 110 existing UI and screen tests must continue running against `FakeTasksRepository` without network dependencies.

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
| :--- | :--- | :--- |
| `Cannot reach Local AI Runtime (Connection refused)` | Backend is listening on `127.0.0.1` instead of `0.0.0.0` | Launch Uvicorn with `--host 0.0.0.0`. |
| `CLEARTEXT_COMMUNICATION_NOT_PERMITTED` | Missing or disabled `networkSecurityConfig` | Verify `network_security_config.xml` exists in `res/xml/`. |
| Status says `Token was rejected (401)` | Pairing token mismatch between phone and `.env` | Copy exact `COMPANION_API_KEY` from `backend/.env`. |
| Tasks screen remains empty after connecting | Backend SQLite DB is freshly initialized with 0 tasks | Create a task using the `+` button or via Swagger docs. |
