package com.example.data.repository

import com.example.data.network.LocalAiRuntimeClient
import com.example.data.network.dto.RemoteTaskDto
import com.example.data.util.TaskDateTimeConverter
import com.example.domain.model.MobileTask
import com.example.domain.model.SyncStatus
import com.example.domain.model.TaskCategory
import com.example.domain.model.TaskPriority
import com.example.domain.repository.ConnectionRepository
import com.example.domain.repository.TasksRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * TasksRepository that synchronizes with the host PC Local AI Runtime.
 *
 * Implements optimistic local updates for zero UI latency, with background
 * synchronization and graceful offline fallback to in-memory state.
 */
class HttpTasksRepository(
    private val connectionRepository: ConnectionRepository,
    private val runtimeClient: LocalAiRuntimeClient = LocalAiRuntimeClient(),
    private val coroutineScope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
    initialTasks: List<MobileTask> = emptyList()
) : TasksRepository {

    private val _tasks = MutableStateFlow(initialTasks)
    override val tasks: StateFlow<List<MobileTask>> = _tasks.asStateFlow()

    init {
        // Attempt initial sync on creation
        refreshTasks()
    }

    /**
     * Fetch all tasks from the PC runtime with result.
     */
    suspend fun syncAll(): Result<List<MobileTask>> {
        val baseUrl = connectionRepository.getBaseUrl()
        val token = connectionRepository.getToken()

        return runtimeClient.getTasks(baseUrl, token).fold(
            onSuccess = { remoteList ->
                val mapped = remoteList.map { it.toMobileTask() }
                _tasks.value = mapped
                connectionRepository.setSyncStatus(SyncStatus.SYNCHRONIZED)
                Result.success(mapped)
            },
            onFailure = { error ->
                connectionRepository.setSyncStatus(SyncStatus.FAILED)
                Result.failure(error)
            }
        )
    }

    /**
     * Trigger background refresh of tasks from runtime.
     */
    fun refreshTasks() {
        coroutineScope.launch {
            syncAll()
        }
    }

    override fun toggleTaskCompletion(taskId: String) {
        var targetTask: MobileTask? = null
        _tasks.update { list ->
            list.map { task ->
                if (task.id == taskId) {
                    val nextCompleted = !task.isCompleted
                    val updated = task.copy(
                        isCompleted = nextCompleted,
                        completedAt = if (nextCompleted) "Just now" else null
                    )
                    targetTask = updated
                    updated
                } else task
            }
        }

        // Sync change to PC
        val taskToSync = targetTask ?: return
        coroutineScope.launch {
            val baseUrl = connectionRepository.getBaseUrl()
            val token = connectionRepository.getToken()
            val nextStatus = if (taskToSync.isCompleted) "completed" else "pending"

            runtimeClient.updateTask(
                baseUrl = baseUrl,
                token = token,
                taskId = taskToSync.id,
                status = nextStatus
            ).fold(
                onSuccess = {
                    connectionRepository.setSyncStatus(SyncStatus.SYNCHRONIZED)
                },
                onFailure = {
                    connectionRepository.setSyncStatus(SyncStatus.PENDING)
                }
            )
        }
    }

    override fun addNewTask(title: String, priority: String, dueTime: String?) {
        val parsedPriority = when (priority.lowercase()) {
            "urgent" -> TaskPriority.URGENT
            "high" -> TaskPriority.HIGH
            "medium" -> TaskPriority.MEDIUM
            else -> TaskPriority.LOW
        }

        val localId = UUID.randomUUID().toString()
        val newTask = MobileTask(
            id = localId,
            title = title,
            description = "",
            category = TaskCategory.GENERAL,
            priority = parsedPriority,
            dueDate = "Today",
            dueTime = dueTime,
            isCompleted = false
        )

        // Optimistic local add
        _tasks.update { listOf(newTask) + it }

        val isoDueDate = TaskDateTimeConverter.toIsoLocal("Today", dueTime)

        // Sync creation to PC
        coroutineScope.launch {
            val baseUrl = connectionRepository.getBaseUrl()
            val token = connectionRepository.getToken()

            runtimeClient.createTask(
                baseUrl = baseUrl,
                token = token,
                title = title,
                notes = "",
                priority = parsedPriority.name.lowercase(),
                dueDate = isoDueDate
            ).fold(
                onSuccess = { created ->
                    // Replace temporary local UUID with authoritative backend UUID
                    _tasks.update { list ->
                        list.map { if (it.id == localId) created.toMobileTask() else it }
                    }
                    connectionRepository.setSyncStatus(SyncStatus.SYNCHRONIZED)
                },
                onFailure = {
                    connectionRepository.setSyncStatus(SyncStatus.PENDING)
                }
            )
        }
    }

    override fun saveTask(task: MobileTask) {
        val isNew = !_tasks.value.any { it.id == task.id }

        // Optimistic update
        _tasks.update { list ->
            val index = list.indexOfFirst { it.id == task.id }
            if (index >= 0) {
                list.toMutableList().apply { set(index, task) }
            } else {
                listOf(task) + list
            }
        }

        val isoDueDate = TaskDateTimeConverter.toIsoLocal(task.dueDate, task.dueTime)

        coroutineScope.launch {
            val baseUrl = connectionRepository.getBaseUrl()
            val token = connectionRepository.getToken()

            val reminderMinutes = TaskDateTimeConverter.reminderToMinutes(task.reminder)

            if (isNew) {
                runtimeClient.createTask(
                    baseUrl = baseUrl,
                    token = token,
                    title = task.title,
                    notes = task.description.ifBlank { null },
                    priority = task.priority.name.lowercase(),
                    dueDate = isoDueDate,
                    category = task.category.name.lowercase(),
                    reminderMinutesBefore = reminderMinutes
                ).fold(
                    onSuccess = { created ->
                        _tasks.update { list ->
                            list.map { if (it.id == task.id) created.toMobileTask() else it }
                        }
                        connectionRepository.setSyncStatus(SyncStatus.SYNCHRONIZED)
                    },
                    onFailure = {
                        connectionRepository.setSyncStatus(SyncStatus.PENDING)
                    }
                )
            } else {
                runtimeClient.updateTask(
                    baseUrl = baseUrl,
                    token = token,
                    taskId = task.id,
                    title = task.title,
                    status = if (task.isCompleted) "completed" else "pending",
                    priority = task.priority.name.lowercase(),
                    dueDate = isoDueDate,
                    category = task.category.name.lowercase(),
                    reminderMinutesBefore = reminderMinutes
                ).fold(
                    onSuccess = {
                        connectionRepository.setSyncStatus(SyncStatus.SYNCHRONIZED)
                    },
                    onFailure = {
                        connectionRepository.setSyncStatus(SyncStatus.PENDING)
                    }
                )
            }
        }
    }

    override fun deleteTask(taskId: String) {
        _tasks.update { list -> list.filterNot { it.id == taskId } }

        coroutineScope.launch {
            val baseUrl = connectionRepository.getBaseUrl()
            val token = connectionRepository.getToken()

            runtimeClient.deleteTask(baseUrl, token, taskId).onFailure {
                connectionRepository.setSyncStatus(SyncStatus.PENDING)
            }
        }
    }

    private fun RemoteTaskDto.toMobileTask(): MobileTask {
        val parsedPriority = when (priority.lowercase()) {
            "urgent" -> TaskPriority.URGENT
            "high" -> TaskPriority.HIGH
            "medium" -> TaskPriority.MEDIUM
            else -> TaskPriority.LOW
        }
        val isDone = status.lowercase() == "completed"
        val (displayDate, displayTime) = TaskDateTimeConverter.fromIsoToDisplay(dueDate)
        val mappedCategory = TaskCategory.fromString(category.orEmpty())
        val mappedReminder = TaskDateTimeConverter.minutesToReminder(reminderMinutesBefore)

        return MobileTask(
            id = id,
            title = title,
            description = notes.orEmpty(),
            category = mappedCategory,
            priority = parsedPriority,
            dueDate = displayDate,
            dueTime = displayTime,
            reminder = mappedReminder,
            isCompleted = isDone,
            completedAt = if (isDone) updatedAt ?: "Completed" else null
        )
    }
}
