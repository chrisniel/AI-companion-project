package com.example.data.fake

import com.example.domain.model.HomeData
import com.example.domain.model.NextScheduleItem
import com.example.domain.model.ScheduleEntryType
import com.example.domain.model.ScheduleItemType
import com.example.domain.model.TaskPreviewItem
import com.example.domain.model.TaskPriority
import com.example.domain.model.TodaySummary
import com.example.domain.model.UserProfile
import com.example.domain.model.WellnessGlance
import com.example.domain.repository.AlarmsRepository
import com.example.domain.repository.HomeRepository
import com.example.domain.repository.ScheduleRepository
import com.example.domain.repository.TasksRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import java.util.UUID

class FakeHomeRepository(
    private val tasksRepository: TasksRepository = FakeTasksRepository(),
    private val scheduleRepository: ScheduleRepository = FakeScheduleRepository(),
    private val alarmsRepository: AlarmsRepository = FakeAlarmsRepository()
) : HomeRepository {

    companion object {
        val DEFAULT_PROFILE = UserProfile(
            name = "User",
            avatarInitials = "U",
            greetingTime = "Morning",
            titleRole = "Companion Workspace"
        )

        val DEFAULT_WELLNESS = WellnessGlance(
            sleepDuration = "7h 45m",
            sleepQualityScore = 88,
            sleepStatus = "Deep & Restorative",
            heartRateBpm = 71,
            heartRateRange = "62 - 78 BPM",
            heartRateStatus = "Resting • Steady",
            stepsCount = 8420,
            stepsGoal = 10000,
            distanceKm = "5.8 km",
            activeMinutes = 48
        )

        val DEFAULT_HOME_DATA = HomeData(
            profile = DEFAULT_PROFILE,
            nextItem = NextScheduleItem(
                id = "sch_1",
                title = "Primary Wakeup Alarm",
                type = ScheduleItemType.ALARM,
                scheduledTime = "07:00 AM",
                countdown = "Armed locally • Synchronized",
                isImportant = true,
                locationOrDetail = "Android Local Audio Node"
            ),
            todaySummary = TodaySummary(
                completedCount = 2,
                totalCount = 8,
                remindersCount = 2,
                openTasks = emptyList()
            ),
            wellness = DEFAULT_WELLNESS,
            assistantStateText = "Attentive & Ready",
            activeModelSummary = "Local AI Core • Windows PC (Active Model Ready)"
        )
    }

    override fun getHomeData(): Flow<HomeData> {
        return combine(
            tasksRepository.tasks,
            scheduleRepository.entries,
            alarmsRepository.alarms
        ) { tasks, entries, alarms ->
            val completedTasksCount = tasks.count { it.isCompleted }
            val openTasks = tasks.filter { !it.isCompleted }
            val previewTasks = openTasks.take(3).map { task ->
                TaskPreviewItem(
                    id = task.id,
                    title = task.title,
                    isCompleted = task.isCompleted,
                    priority = when (task.priority) {
                        TaskPriority.URGENT -> "Urgent"
                        TaskPriority.HIGH -> "High"
                        TaskPriority.MEDIUM -> "Normal"
                        TaskPriority.LOW -> "Low"
                    },
                    dueTime = task.dueTime
                )
            }

            val nextScheduleEntry = entries.firstOrNull { !it.isCompleted }
            val nextItem = if (nextScheduleEntry != null) {
                NextScheduleItem(
                    id = nextScheduleEntry.id,
                    title = nextScheduleEntry.title,
                    type = when (nextScheduleEntry.type) {
                        ScheduleEntryType.ALARM -> ScheduleItemType.ALARM
                        ScheduleEntryType.REMINDER -> ScheduleItemType.REMINDER
                        else -> ScheduleItemType.EVENT
                    },
                    scheduledTime = nextScheduleEntry.time,
                    countdown = "Upcoming",
                    isImportant = nextScheduleEntry.priority == TaskPriority.URGENT || nextScheduleEntry.type == ScheduleEntryType.ALARM,
                    locationOrDetail = nextScheduleEntry.locationOrSource ?: nextScheduleEntry.subtitle
                )
            } else {
                val nextAlarm = alarms.firstOrNull { it.isEnabled }
                if (nextAlarm != null) {
                    NextScheduleItem(
                        id = nextAlarm.id,
                        title = nextAlarm.title,
                        type = ScheduleItemType.ALARM,
                        scheduledTime = nextAlarm.time,
                        countdown = nextAlarm.nextTriggerLabel,
                        isImportant = true,
                        locationOrDetail = "Armed locally • Synchronized"
                    )
                } else {
                    NextScheduleItem(
                        id = "sch-empty",
                        title = "No upcoming items scheduled",
                        type = ScheduleItemType.EVENT,
                        scheduledTime = "All clear",
                        countdown = "Today",
                        isImportant = false,
                        locationOrDetail = "Local companion ready"
                    )
                }
            }

            HomeData(
                profile = DEFAULT_PROFILE,
                nextItem = nextItem,
                todaySummary = TodaySummary(
                    completedCount = completedTasksCount,
                    totalCount = tasks.size,
                    remindersCount = 2,
                    openTasks = previewTasks
                ),
                wellness = DEFAULT_WELLNESS,
                assistantStateText = "Attentive & Ready",
                activeModelSummary = "Local AI Core • Windows PC (Active Model Ready)"
            )
        }
    }

    override suspend fun toggleTaskCompletion(taskId: String) {
        tasksRepository.toggleTaskCompletion(taskId)
    }

    override suspend fun addNewTask(title: String, priority: String): TaskPreviewItem {
        tasksRepository.addNewTask(title, priority, "Today")
        return TaskPreviewItem(
            id = "task-${UUID.randomUUID().toString().take(6)}",
            title = title,
            isCompleted = false,
            priority = priority,
            dueTime = "Today"
        )
    }
}
