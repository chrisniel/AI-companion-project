package com.example.domain.repository

import com.example.domain.model.MobileTask
import kotlinx.coroutines.flow.StateFlow

/**
 * Authoritative repository interface for Mobile Tasks.
 */
interface TasksRepository {
    val tasks: StateFlow<List<MobileTask>>

    fun toggleTaskCompletion(taskId: String)
    fun addNewTask(title: String, priority: String = "Normal", dueTime: String? = null)
    fun saveTask(task: MobileTask)
    fun deleteTask(taskId: String)
}
