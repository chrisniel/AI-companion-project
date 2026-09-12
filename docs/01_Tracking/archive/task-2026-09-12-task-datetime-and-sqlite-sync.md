# Archived Task: Task Due Date Calculation & SQLite Database Persistence

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Archived Date: 2026-09-12
Branch: `feature/android-sync-resilience-and-task-controls`

- Status: Completed & Verified by User on Physical Device
- Sprint: Task Due Date & Time Calculation and Database Persistence
- Target: Resolve SQLite database `due_date` null defect, compute concrete dates for quick options (`Today`, `Tomorrow`, `Next Week`) and custom dates, format 12-hour AM/PM times into standard ISO-8601, reconstruct relative labels upon retrieval, and preserve local reminder and category selections.
- Verification: 122/122 Android unit tests passed. Physical device testing on Infinix ZERO ULTRA and live SQLite database verification confirmed fully operational.

## Completed Checklist

### 1. Planning & Architecture Review
- [x] Trace root cause of SQLite `due_date` null defect (omitted in `LocalAiRuntimeClient` and `HttpTasksRepository`)
- [x] Confirm `reminder` and `category` deferral to Track B6 / A2 in alignment with canonical architecture
- [x] Plan soft-deletion, ownership scoping (`owner_id`), and retention policy in `AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` Section 16.1
- [x] Create implementation plan in `docs/02_Planning/plan-task-datetime-and-reminder-database-sync.md`
- [x] User review and approval of implementation plan

### 2. Android Date/Time Converter & Network Layer
- [x] Create `TaskDateTimeConverter.kt` supporting `Today`, `Tomorrow`, `Next Week`, calendar dates, and 12-hour AM/PM times
- [x] Add unit tests in `TaskDateTimeConverterTest.kt` (7 test cases covering all paths)
- [x] Update `LocalAiRuntimeClient.kt` (`createTask` and `updateTask`) to send `due_date` in JSON payloads
- [x] Update `HttpTasksRepository.kt` to serialize date/time in `saveTask` and deserialize in `toMobileTask` (preserving local category and reminder)

### 3. Verification & Build
- [x] Run Android unit tests (`gradlew.bat testDebugUnitTest` — 122/122 passed in 1m)
- [x] Run backend unit tests (`pytest` — 18/18 passed in 0.30s)
- [x] Compile debug APK (`gradlew.bat assembleDebug` — `app-debug.apk` built)
- [x] User testing on physical phone & SQLite verification in `companion.db`: confirmed working
