package com.example.domain.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Tune
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Memory Category classifications according to Batch 10 specifications:
 * - Profile
 * - Preference
 * - Fact
 * - Project
 * - Event
 * - Temporary
 */
enum class MemoryCategory(
    val displayName: String,
    val description: String
) {
    PROFILE(
        displayName = "Profile",
        description = "Personal identity, background, and core user profile details"
    ),
    PREFERENCE(
        displayName = "Preference",
        description = "Interaction habits, UI styling choices, and response guidelines"
    ),
    FACT(
        displayName = "Fact",
        description = "Verified knowledge, network topology, and factual references"
    ),
    PROJECT(
        displayName = "Project",
        description = "Ongoing workspaces, development codebases, and project objectives"
    ),
    EVENT(
        displayName = "Event",
        description = "Milestones, calendar commitments, and notable timelines"
    ),
    TEMPORARY(
        displayName = "Temporary",
        description = "Transient context, scratchpad items, and short-lived facts"
    )
}

/**
 * Mobile Memory Item entity designed for high readability without raw vector telemetry.
 */
data class MemoryItem(
    val id: String,
    val title: String,
    val content: String,
    val category: MemoryCategory,
    val tags: List<String> = emptyList(),
    val createdAt: String,
    val updatedAt: String = createdAt,
    val isArchived: Boolean = false
)
