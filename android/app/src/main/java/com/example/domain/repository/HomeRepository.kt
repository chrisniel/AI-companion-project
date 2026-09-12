package com.example.domain.repository

import com.example.domain.model.HomeData
import com.example.domain.model.TaskPreviewItem
import kotlinx.coroutines.flow.Flow

interface HomeRepository {
    fun getHomeData(): Flow<HomeData>
    suspend fun toggleTaskCompletion(taskId: String)
    suspend fun addNewTask(title: String, priority: String): TaskPreviewItem
}
