package com.example.domain.model

/**
 * Supported item types in the unified Schedule:
 * - TASK
 * - REMINDER
 * - ALARM
 * - CALENDAR_EVENT
 */
enum class ScheduleEntryType(val label: String) {
    TASK("Task"),
    REMINDER("Reminder"),
    ALARM("Alarm"),
    CALENDAR_EVENT("Calendar Event")
}

/**
 * Schedule view modes.
 */
enum class ScheduleViewMode(val label: String, val testTag: String) {
    DAY("Day", "schedule_tab_day"),
    AGENDA("Agenda", "schedule_tab_agenda"),
    WEEK("Week", "schedule_tab_week")
}

/**
 * A unified entry shown across Day, Agenda, and Week views.
 */
data class ScheduleEntry(
    val id: String,
    val title: String,
    val subtitle: String? = null,
    val type: ScheduleEntryType,
    val time: String,               // e.g. "07:00 AM", "09:30 AM"
    val date: String,               // e.g. "Today, Sep 9", "Tomorrow, Sep 10"
    val dayOfWeek: String,          // e.g. "Wed", "Thu"
    val durationMinutes: Int = 30,  // for day timeline blocks
    val isCompleted: Boolean = false,
    val locationOrSource: String? = null,
    val priority: TaskPriority = TaskPriority.MEDIUM,
    val isAlarmActive: Boolean = false
)

/**
 * Days of the week for recurring alarms.
 */
enum class AlarmDay(val shortLabel: String, val code: String) {
    MON("M", "Mon"),
    TUE("T", "Tue"),
    WED("W", "Wed"),
    THU("T", "Thu"),
    FRI("F", "Fri"),
    SAT("S", "Sat"),
    SUN("S", "Sun")
}

/**
 * Sync & Redundancy state between PC / Desktop and Mobile Android.
 */
enum class DeviceSyncState(val label: String) {
    SYNCHRONIZED("Synchronized"),
    ARMED_LOCALLY("Armed Locally"),
    OFFLINE("Offline"),
    PENDING("Syncing")
}

/**
 * Redundancy pair status reflecting multi-device alarm readiness.
 * Supports states such as:
 * - Desktop: Synchronized, Android: Armed
 * - Desktop: Offline, Android: Armed Locally
 */
data class AlarmRedundancyStatus(
    val desktopNodeName: String = "Desktop Core (Workstation)",
    val desktopStatus: DeviceSyncState = DeviceSyncState.SYNCHRONIZED,
    val androidNodeName: String = "Android Local (Device)",
    val androidStatus: DeviceSyncState = DeviceSyncState.ARMED_LOCALLY,
    val lastHeartbeat: String = "Just now"
)

/**
 * Full Alarm specification for Android.
 * Fields:
 * - title
 * - time (e.g. "07:00", "AM/PM")
 * - recurrence (Set of days or 'Once', 'Weekdays', 'Weekends', 'Every day')
 * - vibration (true/false)
 * - mock sound (e.g. "Soft Dawn Synthesizer", "Gentle Ripple", "System Bell")
 * - enabled state (true/false)
 * - PC mirroring (true/false)
 * - redundancyStatus (synchronization state)
 */
data class MobileAlarm(
    val id: String,
    val title: String,
    val time: String, // 24h or 12h representation e.g. "07:00 AM"
    val recurrenceDays: Set<AlarmDay> = setOf(AlarmDay.MON, AlarmDay.TUE, AlarmDay.WED, AlarmDay.THU, AlarmDay.FRI),
    val recurrenceLabel: String = "Weekdays",
    val isEnabled: Boolean = true,
    val vibrate: Boolean = true,
    val soundName: String = "Soft Dawn Synthesizer",
    val pcMirroring: Boolean = true,
    val desktopSyncState: DeviceSyncState = DeviceSyncState.SYNCHRONIZED,
    val androidArmedState: DeviceSyncState = DeviceSyncState.ARMED_LOCALLY,
    val nextTriggerLabel: String = "Tomorrow morning"
)

/**
 * Schedule UI State.
 */
data class ScheduleUiState(
    val selectedViewMode: ScheduleViewMode = ScheduleViewMode.DAY,
    val selectedDate: String = "Today, Sep 9",
    val selectedDayOfWeek: String = "Wed",
    val filterType: ScheduleEntryType? = null,
    val entries: List<ScheduleEntry> = emptyList(),
    val quickActionFeedback: String? = null
)

/**
 * Alarms UI State.
 */
data class AlarmsUiState(
    val alarms: List<MobileAlarm> = emptyList(),
    val isEditorOpen: Boolean = false,
    val editingAlarmId: String? = null,
    val globalRedundancy: AlarmRedundancyStatus = AlarmRedundancyStatus(),
    val statusFeedbackMessage: String? = null
)
