package com.example.domain.model

enum class ScheduleItemType {
    EVENT,
    ALARM,
    REMINDER
}

data class NextScheduleItem(
    val id: String,
    val title: String,
    val type: ScheduleItemType,
    val scheduledTime: String,
    val countdown: String,
    val isImportant: Boolean = false,
    val locationOrDetail: String? = null
)

data class TaskPreviewItem(
    val id: String,
    val title: String,
    val isCompleted: Boolean = false,
    val priority: String = "Normal", // "High", "Normal", "Low"
    val dueTime: String? = null
)

data class TodaySummary(
    val completedCount: Int,
    val totalCount: Int,
    val remindersCount: Int,
    val openTasks: List<TaskPreviewItem>
)

data class WellnessGlance(
    val sleepDuration: String,
    val sleepQualityScore: Int,
    val sleepStatus: String,
    val heartRateBpm: Int,
    val heartRateRange: String,
    val heartRateStatus: String,
    val stepsCount: Int,
    val stepsGoal: Int,
    val distanceKm: String,
    val activeMinutes: Int
)

data class UserProfile(
    val name: String,
    val avatarInitials: String = "CD",
    val greetingTime: String = "Morning",
    val titleRole: String = "Autonomous Operator"
)

data class HomeData(
    val profile: UserProfile,
    val nextItem: NextScheduleItem,
    val todaySummary: TodaySummary,
    val wellness: WellnessGlance,
    val assistantStateText: String = "Attentive & Ready",
    val activeModelSummary: String = "Local AI Core • Windows PC (Active Model Ready)"
)
