package com.example.data.fake

import com.example.domain.model.MobileTask
import com.example.domain.model.TaskCategory
import com.example.domain.model.TaskPriority
import com.example.domain.repository.TasksRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.util.UUID

class FakeTasksRepository : TasksRepository {

    private val _tasks = MutableStateFlow(initialMockTasks())
    override val tasks: StateFlow<List<MobileTask>> = _tasks.asStateFlow()

    override fun toggleTaskCompletion(taskId: String) {
        _tasks.update { list ->
            list.map { task ->
                if (task.id == taskId) {
                    val nextCompleted = !task.isCompleted
                    task.copy(
                        isCompleted = nextCompleted,
                        completedAt = if (nextCompleted) "Today, 09:25" else null
                    )
                } else task
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
        val newTask = MobileTask(
            id = "task-${UUID.randomUUID().toString().take(6)}",
            title = title,
            description = "Quick task created locally on companion",
            category = TaskCategory.PERSONAL,
            priority = parsedPriority,
            dueDate = "Today",
            dueTime = dueTime ?: "Today",
            reminder = "At due time",
            isCompleted = false
        )
        _tasks.update { listOf(newTask) + it }
    }

    override fun saveTask(task: MobileTask) {
        _tasks.update { list ->
            val index = list.indexOfFirst { it.id == task.id }
            if (index >= 0) {
                list.toMutableList().apply { set(index, task) }
            } else {
                listOf(task) + list
            }
        }
    }

    override fun deleteTask(taskId: String) {
        _tasks.update { list -> list.filterNot { it.id == taskId } }
    }

    companion object {
        fun initialMockTasks(): List<MobileTask> {
            return listOf(
                MobileTask(
                    id = "task-1",
                    title = "Check backend bukas",
                    description = "Verify local SQLite synchronization & token rate before morning standup",
                    category = TaskCategory.DEV,
                    priority = TaskPriority.HIGH,
                    dueDate = "Today",
                    dueTime = "14:00",
                    reminder = "15 mins before",
                    isCompleted = false
                ),
                MobileTask(
                    id = "task-2",
                    title = "Android UIを確認",
                    description = "Compose adaptive navigation rail & status pill padding on foldable screen",
                    category = TaskCategory.DEV,
                    priority = TaskPriority.URGENT,
                    dueDate = "Today",
                    dueTime = "16:30",
                    reminder = "10 mins before",
                    isCompleted = false
                ),
                MobileTask(
                    id = "task-3",
                    title = "Review quarterly memory compaction stats",
                    description = "Validate local Vector Store compaction metrics and cache clearance",
                    category = TaskCategory.WORK,
                    priority = TaskPriority.MEDIUM,
                    dueDate = "Today",
                    dueTime = "18:00",
                    reminder = "At due time",
                    isCompleted = false
                ),
                MobileTask(
                    id = "task-4",
                    title = "Team sync sa Google Meet",
                    description = "Discuss voice fallback & multi-turn streaming latency with PC core",
                    category = TaskCategory.WORK,
                    priority = TaskPriority.HIGH,
                    dueDate = "Tomorrow",
                    dueTime = "10:00",
                    reminder = "30 mins before",
                    isCompleted = false
                ),
                MobileTask(
                    id = "task-5",
                    title = "新機能のドキュメント作成",
                    description = "Write API docs for PC Core tool calling and telemetry schemas",
                    category = TaskCategory.DEV,
                    priority = TaskPriority.MEDIUM,
                    dueDate = "Sep 12, 2026",
                    dueTime = "15:00",
                    reminder = "1 hour before",
                    isCompleted = false
                ),
                MobileTask(
                    id = "task-6",
                    title = "Groceries & organic green tea",
                    description = "Pick up matcha, almond milk, and electrolyte drinks",
                    category = TaskCategory.SHOPPING,
                    priority = TaskPriority.LOW,
                    dueDate = "Sep 13, 2026",
                    dueTime = "19:00",
                    reminder = "At due time",
                    isCompleted = false
                ),
                MobileTask(
                    id = "task-7",
                    title = "Morning 5km endurance run",
                    description = "Keep heart rate in Aerobic Zone 3 (135 - 150 bpm)",
                    category = TaskCategory.HEALTH,
                    priority = TaskPriority.MEDIUM,
                    dueDate = "Today",
                    dueTime = "06:30",
                    reminder = "15 mins before",
                    isCompleted = true,
                    completedAt = "Today, 07:15"
                ),
                MobileTask(
                    id = "task-8",
                    title = "Benchmark Vulkan offload on PC Core",
                    description = "Quantize model weights for efficient local speech recognition on PC Core",
                    category = TaskCategory.DEV,
                    priority = TaskPriority.HIGH,
                    dueDate = "Yesterday",
                    dueTime = "17:00",
                    reminder = "At due time",
                    isCompleted = true,
                    completedAt = "Yesterday, 18:30"
                )
            )
        }
    }
}
