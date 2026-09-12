package com.example.domain.repository

import com.example.domain.model.ScheduleEntry
import kotlinx.coroutines.flow.StateFlow

/**
 * Authoritative repository interface for Schedule & Agenda entries.
 */
interface ScheduleRepository {
    val entries: StateFlow<List<ScheduleEntry>>

    fun toggleEntryCompletion(id: String)
    fun dismissEntry(id: String)
    fun addEntry(entry: ScheduleEntry)
}
