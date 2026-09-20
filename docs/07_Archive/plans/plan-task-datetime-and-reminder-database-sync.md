# Implementation Plan: Task Due Date & Time Calculation and Database Persistence

Template Version: Docs_ProjectWorkflowStarterKit_v2.0
Branch: `feature/android-sync-resilience-and-task-controls`
Target: Fix SQLite database `due_date` null defect, compute concrete dates for quick options (`Today`, `Tomorrow`, `Next Week`) and custom calendar dates, format 12-hour AM/PM times to ISO-8601 for FastAPI/SQLite, and reconstruct relative labels upon retrieval.

---

## 1. Executive Summary & Architecture Scope

### Where Reminder and Category Belong in Architecture
In the Canonical Architecture Document (`docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`), full reminders, schedules, and categories are explicitly scheduled for:
- **Track B6**: *Add tasks, schedules, reminders, alarms, and tool execution* (Backend schema, schedule entities, LLM reminder tools).
- **Track A2**: *Add Android connectivity, persistence, synchronization, and alarm redundancy* (Android `AlarmManager`, notification triggers).

Therefore, **we keep `reminder` and `category` as client-side UI selections for now**, deferring backend database migrations for them to Track B6 / A2.

### The Immediate Defect
The `due_date` column **already exists** in the backend `tasks` table in `companion.db`, but it was remaining `null` because:
1. `LocalAiRuntimeClient.kt` omitted `due_date` from the JSON payload in `createTask()` and `updateTask()`.
2. `HttpTasksRepository.kt` did not forward date or time fields to the network client.
3. Android had no converter to calculate concrete timestamps from relative choices (`Today`, `Tomorrow`, `Next Week`) and 12-hour AM/PM times (`12:00 PM`, `09:30 AM`).

---

## 2. Affected Files & Layer Breakdown

| Component | Target File | Change Type | Purpose |
| :--- | :--- | :--- | :--- |
| **Date/Time Converter** | `android/app/src/main/java/com/example/data/util/TaskDateTimeConverter.kt` | New | Bidirectional conversion between relative/12-hr mobile UI format and ISO-8601 timestamps (`YYYY-MM-DDTHH:MM:SS`). |
| **Runtime Network** | `android/app/src/main/java/com/example/data/network/LocalAiRuntimeClient.kt` | Modify | Add `dueDate: String? = null` parameter to `createTask` & `updateTask`; parse `due_date` in `parseRemoteTask`. |
| **Tasks Repository** | `android/app/src/main/java/com/example/data/repository/HttpTasksRepository.kt` | Modify | Forward ISO-formatted `dueDate` in `saveTask` and `addNewTask`; map `dueDate` back to relative label & 12-hr time in `toMobileTask`. |
| **Unit Tests** | `android/app/src/test/java/com/example/TaskDateTimeConverterTest.kt` | New | Unit tests verifying date/time calculation, relative labels, and ISO-8601 formatting. |

*(Note: Zero backend files modified, preserving existing backend tests and contracts until Track B6).*

---

## 3. Step-by-Step Logic & Pseudocode

### A. Date and Time Calculation (`TaskDateTimeConverter.kt`)

```kotlin
object TaskDateTimeConverter {
    // 1. Convert mobile UI state (Today, Tomorrow, Next Week, or calendar date + 12-hr time) to ISO-8601 string
    fun toIsoLocal(dueDate: String?, dueTime: String?): String? {
        if (dueDate.isNullOrBlank()) return null
        val cal = Calendar.getInstance()
        val cleanDate = dueDate.trim()

        when {
            cleanDate.equals("Today", ignoreCase = true) -> { /* cal is today */ }
            cleanDate.equals("Tomorrow", ignoreCase = true) -> { cal.add(Calendar.DAY_OF_YEAR, 1) }
            cleanDate.equals("Next Week", ignoreCase = true) -> { cal.add(Calendar.DAY_OF_YEAR, 7) }
            cleanDate.matches(Regex("^\\d{4}-\\d{2}-\\d{2}.*")) -> {
                val tokens = cleanDate.substring(0, 10).split("-")
                cal.set(tokens[0].toInt(), tokens[1].toInt() - 1, tokens[2].toInt())
            }
            else -> parseDateString(cleanDate)?.let { cal.time = it }
        }

        var hour = 12
        var minute = 0
        if (!dueTime.isNullOrBlank()) {
            parseTimeString(dueTime.trim())?.let { (h, m) ->
                hour = h
                minute = m
            }
        }
        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, minute)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        return String.format(Locale.US, "%04d-%02d-%02dT%02d:%02d:00",
            cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
            cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
    }

    // 2. Convert backend ISO-8601 string back to user-friendly UI labels (Today, Tomorrow, 12-hour AM/PM)
    fun fromIsoToDisplay(isoString: String?): Pair<String, String?> {
        if (isoString.isNullOrBlank()) return Pair("Today", null)
        val parts = isoString.split("T", " ")
        val datePart = parts[0]
        val timePart = parts.getOrNull(1)

        val dateTokens = datePart.split("-")
        if (dateTokens.size < 3) return Pair("Today", null)
        val cal = Calendar.getInstance().apply {
            set(dateTokens[0].toInt(), dateTokens[1].toInt() - 1, dateTokens[2].toInt())
        }
        val today = Calendar.getInstance()
        val isToday = cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                      cal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
        today.add(Calendar.DAY_OF_YEAR, 1)
        val isTomorrow = cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                         cal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)

        val displayDate = when {
            isToday -> "Today"
            isTomorrow -> "Tomorrow"
            else -> SimpleDateFormat("MMM dd, yyyy", Locale.US).format(cal.time)
        }

        var displayTime: String? = null
        if (!timePart.isNullOrBlank()) {
            val timeTokens = timePart.split(":")
            if (timeTokens.size >= 2) {
                val hour = timeTokens[0].toInt()
                val minute = timeTokens[1].toInt()
                val amPm = if (hour < 12) "AM" else "PM"
                val displayHour = when {
                    hour == 0 -> 12
                    hour > 12 -> hour - 12
                    else -> hour
                }
                displayTime = String.format(Locale.US, "%02d:%02d %s", displayHour, minute, amPm)
            }
        }

        return Pair(displayDate, displayTime)
    }
}
```

### B. Network & Repository Integration
1. In `LocalAiRuntimeClient.kt`:
   - Add `dueDate: String? = null` to `createTask()` and `updateTask()`.
   - In JSON builder: `if (!dueDate.isNullOrBlank()) put("due_date", dueDate)`.
2. In `HttpTasksRepository.kt`:
   - When saving a task (`saveTask`), compute `val isoDueDate = TaskDateTimeConverter.toIsoLocal(task.dueDate, task.dueTime)`.
   - Pass `dueDate = isoDueDate` to `createTask()` and `updateTask()`.
   - In `toMobileTask()`, parse `RemoteTaskDto.dueDate` via `TaskDateTimeConverter.fromIsoToDisplay(dueDate)` so `dueDate` displays as `Today`, `Tomorrow`, or `MMM dd, yyyy` and `dueTime` displays as `hh:mm a`.

---

## 4. Verification Plan

### Automated Checks
1. `TaskDateTimeConverterTest.kt`:
   - Verify `toIsoLocal("Today", "12:00 PM")` generates today's ISO string.
   - Verify `toIsoLocal("Tomorrow", "09:00 AM")` generates tomorrow at 09:00.
   - Verify `toIsoLocal("Next Week", "06:00 PM")` generates today+7 at 18:00.
   - Verify `fromIsoToDisplay` accurately identifies "Today", "Tomorrow", and 12-hour AM/PM times.
2. Run `.\gradlew.bat testDebugUnitTest` and confirm all 115+ unit tests pass.
3. Run `.\gradlew.bat assembleDebug` and confirm APK compiles cleanly.

### Manual Verification
1. Open Android app, create task with "Tomorrow" and "09:00 AM".
2. Query `tasks` table in `companion.db`:
   - Confirm `due_date` contains `YYYY-MM-DD 09:00:00.000000` (matching tomorrow at 9:00 AM, NOT null).
3. Pull-to-refresh on Android app:
   - Confirm the task displays `Tomorrow • 09:00 AM`.
