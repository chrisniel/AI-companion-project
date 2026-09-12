package com.example.data.repository

import com.example.data.network.LocalAiRuntimeClient
import com.example.data.network.dto.RemoteTaskDto
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
     * Fetch all tasks from the PC runtime.
     */
    fun refreshTasks() {
        coroutineScope.launch {
            val baseUrl = connectionRepository.getBaseUrl()
            val token = connectionRepository.getToken()

            runtimeClient.getTasks(baseUrl, token).fold(
                onSuccess = { remoteList ->
                    val mapped = remoteList.map { it.toMobileTask() }
                    _tasks.value = mapped
                    connectionRepository.setSyncStatus(SyncStatus.SYNCHRONIZED)
                },
                onFailure = {
                    // Set sync failed but preserve existing in-memory tasks
                    connectionRepository.setSyncStatus(SyncStatus.FAILED)
                }
            )
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
            ).onFailure {
                connectionRepository.setSyncStatus(SyncStatus.PENDING)
            }
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

        // Sync creation to PC
        coroutineScope.launch {
            val baseUrl = connectionRepository.getBaseUrl()
            val token = connectionRepository.getToken()

            runtimeClient.createTask(
                baseUrl = baseUrl,
                token = token,
                title = title,
                notes = "",
                priority = parsedPriority.name.lowercase()
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
        // Optimistic update
        _tasks.update { list ->
            val index = list.indexOfFirst { it.id == task.id }
            if (index >= 0) {
                list.toMutableList().apply { set(index, task) }
            } else {
                listOf(task) + list
            }
        }

        coroutineScope.launch {
            val baseUrl = connectionRepository.getBaseUrl()
            val token = connectionRepository.getToken()

            runtimeClient.updateTask(
                baseUrl = baseUrl,
                token = token,
                taskId = task.id,
                title = task.title,
                status = if (task.isCompleted) "completed" else "pending",
                priority = task.priority.name.lowercase()
            ).onFailure {
                connectionRepository.setSyncStatus(SyncStatus.PENDING)
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

        return MobileTask(
            id = id,
            title = title,
            description = notes.orEmpty(),
            category = TaskCategory.GENERAL,
            priority = parsedPriority,
            dueDate = dueDate ?: "Today",
            dueTime = null,
            reminder = null,
            isCompleted = isDone,
            completedAt = if (isDone) updatedAt ?: "Completed" else null
        )
    }
}
