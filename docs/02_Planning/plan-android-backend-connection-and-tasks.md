# Implementation Plan: Android Backend Connection & Live Tasks Integration

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Primary Skill: `end-to-end-user-flow`
Supporting Skills: `api-contract-review`, `authentication-flow`, `error-handling`, `test-creation`

---

## 1. Executive Summary & Problem Context

The Local AI Runtime (FastAPI + SQLite WAL backend) is fully operational with OWASP API Top 10 security, token-based pairing, and Tasks CRUD endpoints (`/api/v1/health`, `/api/v1/auth/verify`, `/api/v1/tasks`).
The Android Companion currently runs in a simulated offline state with mock repositories (`FakeTasksRepository`).

This sprint delivers the first live vertical slice connecting the Android Companion app to the host PC Local AI Runtime over local Wi-Fi:
1. **Network Infrastructure**: Configure Android network permissions and network security policy allowing cleartext HTTP communication over local LAN (`192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`, `10.0.2.2`, `localhost`).
2. **Persistent Host Configuration**: Store host IP, port, and pairing token in SharedPreferences (`ConnectionPreferencesRepository`), populated via the existing `ConnectionScreen` UI.
3. **Live Health & Token Handshake**: Implement reachability probing (`GET /api/v1/health`) and token verification (`POST /api/v1/auth/verify`) that updates `AppViewModel`'s connection state (`CoreConnectionState.Local` vs `Offline`).
4. **Live Tasks CRUD**: Implement `HttpTasksRepository` using OkHttp that synchronizes mobile tasks with the host PC's SQLite database, with graceful fallback to cached/local data when the PC is unreachable.
5. **Zero Regression**: Preserve all 110 existing Android unit tests.

---

## 2. API Contract Parity Review

| Operation | Method & Route | Request Body | Response Body / Status | Auth Header |
| :--- | :--- | :--- | :--- | :--- |
| **Health Probe** | `GET /api/v1/health` | None | `HealthResponse(status="ok", service=...)` (200) | Public (None) |
| **Token Verification** | `POST /api/v1/auth/verify` | None | `TokenVerifyResponse(verified=true, owner_id=...)` (200 / 401) | `Bearer companion_sec_...` |
| **List Tasks** | `GET /api/v1/tasks` | None | `TaskListResponse(items=[...], total=N)` (200) | `Bearer companion_sec_...` |
| **Create Task** | `POST /api/v1/tasks` | `TaskCreate(title, notes, priority, due_date)` | `TaskResponse` (201) | `Bearer companion_sec_...` |
| **Update Task** | `PATCH /api/v1/tasks/{id}` | `TaskUpdate(status, priority, ...)` | `TaskResponse` (200) | `Bearer companion_sec_...` |
| **Delete Task** | `DELETE /api/v1/tasks/{id}` | None | 204 No Content | `Bearer companion_sec_...` |

### Model Translation Matrix (`MobileTask` <-> `TaskResponse`)

| Android `MobileTask` Field | Backend `TaskResponse` / `TaskCreate` Field | Mapping Rule |
| :--- | :--- | :--- |
| `id: String` | `id: str` (UUID) | Direct pass-through |
| `title: String` | `title: str` | Direct pass-through |
| `description: String` | `notes: Optional[str]` | Bi-directional mapping |
| `priority: TaskPriority` | `priority: TaskPriority` | `TaskPriority.HIGH` <-> `"high"`, `URGENT` <-> `"urgent"`, etc. |
| `isCompleted: Boolean` | `status: TaskStatus` | `isCompleted == true` -> `"completed"`; else `"pending"` |
| `dueDate: String` | `due_date: Optional[datetime]` | Format as ISO-8601 when valid date; fallback to null on freeform strings |
| `dueTime: String?` | `notes` or extra payload | Stored with task |
| `completedAt: String?` | `updated_at: datetime` | Displayed when status is completed |

---

## 3. Architecture & Data Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Android Companion App                        │
├───────────────────────────────┬─────────────────────────────────┤
│        UI Layer               │ ConnectionScreen / TasksScreen  │
├───────────────────────────────┼─────────────────────────────────┤
│       ViewModel               │ AppViewModel / TasksViewModel   │
├───────────────────────────────┼─────────────────────────────────┤
│      Domain Layer             │ TasksRepository / ConnectionRepo│
├───────────────────────────────┼─────────────────────────────────┤
│       Data Layer              │ HttpTasksRepository             │
│                               │ ├── OkHttpClient (Auth Header)  │
│                               │ └── Fallback: In-Memory / Cache │
└───────────────┬───────────────┴─────────────────────────────────┘
                │
                │ HTTP / REST over Wi-Fi (192.168.x.x:8000)
                ▼
┌─────────────────────────────────────────────────────────────────┐
│              Windows Host PC: Local AI Runtime                  │
│       FastAPI + SQLite WAL Database (companion.db)              │
│       Active Token: companion_sec_JB6py...                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Implementation Steps in Plain Pseudocode

### Step 1: Android Network Configuration & Permissions
- Add permissions in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
  ```
- Create `android/app/src/main/res/xml/network_security_config.xml`:
  ```xml
  <network-security-config>
      <base-config cleartextTrafficPermitted="false" />
      <domain-config cleartextTrafficPermitted="true">
          <domain includeSubdomains="true">192.168.0.0/16</domain>
          <domain includeSubdomains="true">10.0.0.0/8</domain>
          <domain includeSubdomains="true">172.16.0.0/12</domain>
          <domain includeSubdomains="true">10.0.2.2</domain>
          <domain includeSubdomains="true">localhost</domain>
          <domain includeSubdomains="true">127.0.0.1</domain>
      </domain-config>
  </network-security-config>
  ```
- Link `android:networkSecurityConfig="@xml/network_security_config"` in `<application>`.

### Step 2: Dependencies
- Add OkHttp 4.12.0 to `android/gradle/libs.versions.toml` and `android/app/build.gradle.kts`.

### Step 3: Connection & Pairing Preferences Repository
- Create `ConnectionPreferencesRepository`:
  - Reads & writes: `host` (default: `"192.168.1.15"`), `port` (default: `8000`), `token` (empty/saved string).
  - Emits `StateFlow<ConnectionConfig>` for reactive consumers.

### Step 4: Local AI Runtime Network Client (`LocalAiRuntimeClient`)
- Encapsulates OkHttp calls:
  - `checkHealth(baseUrl): Result<HealthDto>`
  - `verifyToken(baseUrl, token): Result<Boolean>`
  - `getTasks(baseUrl, token): Result<List<TaskDto>>`
  - `createTask(baseUrl, token, task): Result<TaskDto>`
  - `updateTask(baseUrl, token, id, update): Result<TaskDto>`
  - `deleteTask(baseUrl, token, id): Result<Unit>`

### Step 5: `HttpTasksRepository` with Offline Fallback
- Implements `TasksRepository`:
  - `tasks: StateFlow<List<MobileTask>>`
  - `fetchRemoteTasks()`: on success, updates `_tasks` and sets `SyncStatus.SYNCHRONIZED`. On failure, logs warning, sets `SyncStatus.FAILED`, and retains current in-memory cache without crashing.
  - `addNewTask(...)`: executes optimistic in-memory update, then launches coroutine to POST to backend; updates task ID upon 201 response.
  - `toggleTaskCompletion(...)`: executes optimistic toggle, then PATCHes `status: "completed"` / `"pending"`.
  - `deleteTask(...)`: removes locally, then DELETEs on backend.

### Step 6: AppContainer & ViewModel Wiring
- Update `DefaultAppContainer`:
  - Initializes `ConnectionPreferencesRepository` and `LocalAiRuntimeClient`.
  - Initializes `HttpTasksRepository` (injecting connection preferences and runtime client).
- Update `AppViewModel`:
  - Exposes `saveHostConfig(host, port, token)` and `testConnection()`.
  - Probes health and updates `connectionInfo.state` (`Local` vs `Offline`).

---

## 5. Acceptance Criteria

1. **AC-1 (LAN HTTP Allowed)**: App can make HTTP calls to `http://192.168.x.x:8000` without `CLEARTEXT_COMMUNICATION_NOT_PERMITTED` exceptions.
2. **AC-2 (Persistent Settings)**: Host IP, port, and pairing token entered in `ConnectionScreen` persist across app restarts.
3. **AC-3 (Live Reachability Probe)**: Clicking "Save & Test Reachability" with correct PC IP and token transitions connection badge to "Local LAN" (Green) with real latency measurement.
4. **AC-4 (Token Verification)**: An invalid token returns 401 and marks sync status as failed or unverified; a valid token confirms pairing.
5. **AC-5 (Live Tasks Sync)**: Tasks created on Android appear in the PC SQLite database (`companion.db`); tasks created via FastAPI Swagger appear on the Android Tasks screen.
6. **AC-6 (Graceful Offline Handling)**: If PC is shut down or unreachable, Android Companion does not crash; it preserves cached tasks and displays "PC OFFLINE" banner.
7. **AC-7 (Test Suite Continuity)**: 100% of existing 110 Android unit tests pass with zero regressions.

---

## 6. Verification Plan

### Automated Checks
- `./gradlew testDebugUnitTest` (all existing tests + new connection/repository tests pass)
- `./gradlew assembleDebug` (APK builds cleanly without manifest or resource errors)

### Manual Verification (Physical Device - Infinix ZERO ULTRA)
1. Find host PC LAN IP (`ipconfig` e.g. `192.168.1.X`).
2. Verify Uvicorn is listening on `0.0.0.0:8000`.
3. Open Android Companion -> Navigate to Connection & Sync screen.
4. Input Host IP, Port 8000, and pairing key from `backend/.env`.
5. Tap "Save & Test Reachability" -> Observe connection status badge turns Green ("Local LAN").
6. Navigate to Tasks screen -> Observe live tasks fetched from backend.
7. Create a new task "Test task from phone" -> Verify in browser `http://127.0.0.1:8000/docs` (`GET /api/v1/tasks`).
