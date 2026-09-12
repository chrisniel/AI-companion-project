package com.example.domain.model

import java.util.UUID

/**
 * Task Priority levels.
 */
enum class TaskPriority(val label: String, val level: Int) {
    LOW("Low", 1),
    MEDIUM("Medium", 2),
    HIGH("High", 3),
    URGENT("Urgent", 4);

    companion object {
        fun fromString(value: String): TaskPriority {
            return entries.find { it.name.equals(value, ignoreCase = true) || it.label.equals(value, ignoreCase = true) }
                ?: MEDIUM
        }
    }
}

/**
 * Project / Category classification for tasks.
 */
enum class TaskCategory(val label: String, val iconName: String) {
    WORK("Work", "BusinessCenter"),
    PERSONAL("Personal", "Person"),
    DEV("Development", "Code"),
    SHOPPING("Shopping", "ShoppingCart"),
    HEALTH("Health", "Favorite"),
    GENERAL("General", "Folder");

    companion object {
        fun fromString(value: String): TaskCategory {
            return entries.find { it.name.equals(value, ignoreCase = true) || it.label.equals(value, ignoreCase = true) }
                ?: GENERAL
        }
    }
}

/**
 * Primary Mobile Task Model supporting multilingual text and quick actions.
 */
data class MobileTask(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val description: String = "",
    val category: TaskCategory = TaskCategory.GENERAL,
    val priority: TaskPriority = TaskPriority.MEDIUM,
    val dueDate: String, // e.g. "Today", "Tomorrow", "Sep 12, 2026"
    val dueTime: String? = null, // e.g. "14:00", "09:30"
    val reminder: String? = null, // e.g. "15 mins before", "At due time", "1 hour before"
    val isCompleted: Boolean = false,
    val isSnoozed: Boolean = false,
    val completedAt: String? = null,
    val createdAtMillis: Long = System.currentTimeMillis()
)

/**
 * Filter tabs for the 3 primary views.
 */
enum class TaskViewTab(val label: String, val testTag: String) {
    TODAY("Today", "task_tab_today"),
    UPCOMING("Upcoming", "task_tab_upcoming"),
    COMPLETED("Completed", "task_tab_completed")
}

/**
 * UI State for Mobile Tasks Screen.
 */
data class TasksUiState(
    val selectedTab: TaskViewTab = TaskViewTab.TODAY,
    val tasks: List<MobileTask> = emptyList(),
    val searchQuery: String = "",
    val isCreateOrEditSheetOpen: Boolean = false,
    val editingTaskId: String? = null, // null means creating new
    val quickActionFeedbackMessage: String? = null,
    val isRefreshing: Boolean = false
)
