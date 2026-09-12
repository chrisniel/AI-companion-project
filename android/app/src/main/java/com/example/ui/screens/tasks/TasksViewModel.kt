package com.example.ui.screens.tasks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeTasksRepository
import com.example.domain.model.MobileTask
import com.example.domain.model.TaskCategory
import com.example.domain.model.TaskPriority
import com.example.domain.model.TaskViewTab
import com.example.domain.model.TasksUiState
import com.example.domain.repository.TasksRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * ViewModel managing fast mobile task management.
 * Injects shared TasksRepository for state synchronization with Home.
 */
class TasksViewModel(
    private val tasksRepository: TasksRepository = FakeTasksRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(TasksUiState(tasks = tasksRepository.tasks.value))
    val uiState: StateFlow<TasksUiState> = _uiState.asStateFlow()

    private var feedbackJob: Job? = null

    init {
        viewModelScope.launch {
            tasksRepository.tasks.collect { taskList ->
                _uiState.update { it.copy(tasks = taskList) }
            }
        }
    }

    fun selectTab(tab: TaskViewTab) {
        _uiState.update { it.copy(selectedTab = tab) }
    }

    fun updateSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
    }

    /**
     * Pull-to-refresh: Sync tasks with backend runtime.
     */
    fun refreshTasks() {
        _uiState.update { it.copy(isRefreshing = true) }
        viewModelScope.launch {
            if (tasksRepository is com.example.data.repository.HttpTasksRepository) {
                tasksRepository.syncAll()
            }
            delay(350)
            _uiState.update { it.copy(isRefreshing = false) }
        }
    }

    /**
     * Quick Action: Complete / Toggle Task
     */
    fun toggleTaskComplete(taskId: String) {
        tasksRepository.toggleTaskCompletion(taskId)
        _uiState.update { it.copy(tasks = tasksRepository.tasks.value) }
        showFeedback("Task status updated")
    }

    /**
     * Quick Action: Delete
     */
    fun deleteTask(taskId: String) {
        val deletedTitle = _uiState.value.tasks.find { it.id == taskId }?.title ?: "Task"
        tasksRepository.deleteTask(taskId)
        _uiState.update { it.copy(tasks = tasksRepository.tasks.value) }
        showFeedback("Deleted \"$deletedTitle\"")
    }

    /**
     * Quick Action: Snooze / Remind Later
     */
    fun snoozeTask(taskId: String) {
        val target = _uiState.value.tasks.find { it.id == taskId }
        if (target != null) {
            val snoozed = target.copy(
                isSnoozed = true,
                dueDate = "Tomorrow",
                dueTime = "09:00",
                reminder = "At 09:00 tomorrow"
            )
            tasksRepository.saveTask(snoozed)
            _uiState.update { it.copy(tasks = tasksRepository.tasks.value) }
        }
        showFeedback("Snoozed to tomorrow 09:00 AM")
    }

    // --- CREATE / EDIT SHEET ---

    fun openCreateSheet() {
        _uiState.update {
            it.copy(
                isCreateOrEditSheetOpen = true,
                editingTaskId = null
            )
        }
    }

    fun openEditSheet(taskId: String) {
        _uiState.update {
            it.copy(
                isCreateOrEditSheetOpen = true,
                editingTaskId = taskId
            )
        }
    }

    fun closeSheet() {
        _uiState.update {
            it.copy(
                isCreateOrEditSheetOpen = false,
                editingTaskId = null
            )
        }
    }

    fun saveTask(
        title: String,
        description: String,
        category: TaskCategory,
        priority: TaskPriority,
        dueDate: String,
        dueTime: String?,
        reminder: String?
    ) {
        if (title.isBlank()) return

        val editingId = _uiState.value.editingTaskId
        if (editingId == null) {
            // Create New Task
            val newTask = MobileTask(
                title = title.trim(),
                description = description.trim(),
                category = category,
                priority = priority,
                dueDate = if (dueDate.isBlank()) "Today" else dueDate.trim(),
                dueTime = dueTime?.ifBlank { null },
                reminder = reminder?.ifBlank { null }
            )
            tasksRepository.saveTask(newTask)
            _uiState.update {
                it.copy(
                    tasks = tasksRepository.tasks.value,
                    isCreateOrEditSheetOpen = false,
                    editingTaskId = null
                )
            }
            showFeedback("Created \"${title.trim()}\"")
        } else {
            // Update Existing Task
            val existing = _uiState.value.tasks.find { it.id == editingId }
            if (existing != null) {
                val updated = existing.copy(
                    title = title.trim(),
                    description = description.trim(),
                    category = category,
                    priority = priority,
                    dueDate = if (dueDate.isBlank()) "Today" else dueDate.trim(),
                    dueTime = dueTime?.ifBlank { null },
                    reminder = reminder?.ifBlank { null }
                )
                tasksRepository.saveTask(updated)
            }
            _uiState.update {
                it.copy(
                    tasks = tasksRepository.tasks.value,
                    isCreateOrEditSheetOpen = false,
                    editingTaskId = null
                )
            }
            showFeedback("Updated \"${title.trim()}\"")
        }
    }

    private fun showFeedback(message: String) {
        feedbackJob?.cancel()
        _uiState.update { it.copy(quickActionFeedbackMessage = message) }
        feedbackJob = viewModelScope.launch {
            delay(2800)
            _uiState.update { it.copy(quickActionFeedbackMessage = null) }
        }
    }
}
