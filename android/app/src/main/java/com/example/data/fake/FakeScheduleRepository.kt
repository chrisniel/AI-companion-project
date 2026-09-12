package com.example.data.fake

import com.example.domain.model.ScheduleEntry
import com.example.domain.model.ScheduleEntryType
import com.example.domain.model.TaskPriority
import com.example.domain.repository.ScheduleRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class FakeScheduleRepository : ScheduleRepository {

    private val _entries = MutableStateFlow(initialScheduleEntries())
    override val entries: StateFlow<List<ScheduleEntry>> = _entries.asStateFlow()

    override fun toggleEntryCompletion(id: String) {
        _entries.update { list ->
            list.map { entry ->
                if (entry.id == id) {
                    entry.copy(isCompleted = !entry.isCompleted)
                } else entry
            }
        }
    }

    override fun dismissEntry(id: String) {
        _entries.update { list -> list.filterNot { it.id == id } }
    }

    override fun addEntry(entry: ScheduleEntry) {
        _entries.update { listOf(entry) + it }
    }

    companion object {
        fun initialScheduleEntries(): List<ScheduleEntry> {
            return listOf(
                ScheduleEntry(
                    id = "sch_1",
                    title = "Primary Wakeup Alarm",
                    subtitle = "Gentle Dawn Synthesizer • Armed",
                    type = ScheduleEntryType.ALARM,
                    time = "07:00 AM",
                    date = "Today, Sep 9",
                    dayOfWeek = "Wed",
                    durationMinutes = 15,
                    isAlarmActive = true,
                    locationOrSource = "Android Local Audio Node"
                ),
                ScheduleEntry(
                    id = "sch_2",
                    title = "Daily Biometric & Task Review",
                    subtitle = "Morning alignment with PC assistant",
                    type = ScheduleEntryType.REMINDER,
                    time = "08:15 AM",
                    date = "Today, Sep 9",
                    dayOfWeek = "Wed",
                    durationMinutes = 30,
                    locationOrSource = "Local Voice Core"
                ),
                ScheduleEntry(
                    id = "sch_3",
                    title = "AI Architecture Team Sync",
                    subtitle = "Review PC Core model benchmarks",
                    type = ScheduleEntryType.CALENDAR_EVENT,
                    time = "10:30 AM",
                    date = "Today, Sep 9",
                    dayOfWeek = "Wed",
                    durationMinutes = 45,
                    locationOrSource = "Calendar Sync (Workstation)"
                ),
                ScheduleEntry(
                    id = "sch_4",
                    title = "Android UIを確認",
                    subtitle = "Verify Material 3 M3 styling & touch targets",
                    type = ScheduleEntryType.TASK,
                    time = "12:00 PM",
                    date = "Today, Sep 9",
                    dayOfWeek = "Wed",
                    durationMinutes = 60,
                    priority = TaskPriority.URGENT,
                    locationOrSource = "Tasks Module"
                ),
                ScheduleEntry(
                    id = "sch_5",
                    title = "Hydration & Posture Reset",
                    subtitle = "Biometric check-in reminder",
                    type = ScheduleEntryType.REMINDER,
                    time = "02:30 PM",
                    date = "Today, Sep 9",
                    dayOfWeek = "Wed",
                    durationMinutes = 15,
                    locationOrSource = "Health Engine"
                ),
                ScheduleEntry(
                    id = "sch_6",
                    title = "Check backend bukas",
                    subtitle = "Autonomous inference pipeline status check",
                    type = ScheduleEntryType.TASK,
                    time = "05:00 PM",
                    date = "Today, Sep 9",
                    dayOfWeek = "Wed",
                    durationMinutes = 45,
                    priority = TaskPriority.HIGH,
                    locationOrSource = "Tasks Module"
                ),
                ScheduleEntry(
                    id = "sch_7",
                    title = "Evening Wind-down Alarm",
                    subtitle = "Low-blue light reminder & sleep prep",
                    type = ScheduleEntryType.ALARM,
                    time = "10:30 PM",
                    date = "Today, Sep 9",
                    dayOfWeek = "Wed",
                    durationMinutes = 15,
                    isAlarmActive = true,
                    locationOrSource = "Android Local Audio Node"
                ),
                ScheduleEntry(
                    id = "sch_8",
                    title = "Benchmark Vulkan offload on PC Core",
                    subtitle = "Test GGUF offload on host GPU",
                    type = ScheduleEntryType.CALENDAR_EVENT,
                    time = "09:00 AM",
                    date = "Tomorrow, Sep 10",
                    dayOfWeek = "Thu",
                    durationMinutes = 60,
                    locationOrSource = "Calendar Sync"
                ),
                ScheduleEntry(
                    id = "sch_9",
                    title = "Mobile Performance Profiling",
                    subtitle = "Verify Robolectric and Compose rendering speed",
                    type = ScheduleEntryType.TASK,
                    time = "02:00 PM",
                    date = "Tomorrow, Sep 10",
                    dayOfWeek = "Thu",
                    durationMinutes = 90,
                    priority = TaskPriority.MEDIUM,
                    locationOrSource = "Tasks Module"
                ),
                ScheduleEntry(
                    id = "sch_10",
                    title = "Weekly System Autonomy Retrospective",
                    subtitle = "Audit local device logs & zero-leakage storage",
                    type = ScheduleEntryType.CALENDAR_EVENT,
                    time = "11:00 AM",
                    date = "Friday, Sep 11",
                    dayOfWeek = "Fri",
                    durationMinutes = 45,
                    locationOrSource = "Calendar Sync"
                )
            )
        }
    }
}
