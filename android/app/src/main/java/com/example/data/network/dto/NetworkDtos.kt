package com.example.data.network.dto

/**
 * Health probe telemetry response from Local AI Runtime.
 */
data class HealthDto(
    val status: String,
    val latencyMs: Int
)

/**
 * Remote Task data transfer object matching OpenAPI schema for /api/v1/tasks.
 */
data class RemoteTaskDto(
    val id: String,
    val ownerId: String = "default_user",
    val title: String,
    val notes: String? = null,
    val status: String = "pending", // "pending", "in_progress", "completed", "cancelled"
    val priority: String = "medium", // "low", "medium", "high", "urgent"
    val dueDate: String? = null,
    val category: String? = "general",
    val reminderMinutesBefore: Int? = null,
    val reminderAt: String? = null,
    val isDeleted: Boolean = false,
    val createdAt: String? = null,
    val updatedAt: String? = null
)
