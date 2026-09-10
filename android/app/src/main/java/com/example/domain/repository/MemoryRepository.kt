package com.example.domain.repository

import com.example.domain.model.MemoryCategory
import com.example.domain.model.MemoryItem
import kotlinx.coroutines.flow.StateFlow

/**
 * Repository interface for Mobile Memory Management (Batch 10).
 * Prioritizes: search, view, edit, archive, delete across 6 categories.
 */
interface MemoryRepository {
    val memories: StateFlow<List<MemoryItem>>

    fun searchMemories(query: String, category: MemoryCategory?, showArchived: Boolean): List<MemoryItem>
    fun getMemory(id: String): MemoryItem?
    fun saveMemory(item: MemoryItem)
    fun toggleArchive(id: String)
    fun deleteMemory(id: String)
}
