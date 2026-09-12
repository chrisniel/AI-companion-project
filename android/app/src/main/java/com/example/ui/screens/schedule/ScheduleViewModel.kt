package com.example.ui.screens.schedule

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeScheduleRepository
import com.example.domain.model.ScheduleEntryType
import com.example.domain.model.ScheduleUiState
import com.example.domain.model.ScheduleViewMode
import com.example.domain.repository.ScheduleRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * In-memory ViewModel for Schedule.
 * Manages views (Day, Agenda, Week), filtering, and quick completions/dismissals.
 * Injects ScheduleRepository for synchronization with Home.
 */
class ScheduleViewModel(
    private val scheduleRepository: ScheduleRepository = FakeScheduleRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        ScheduleUiState(
            selectedViewMode = ScheduleViewMode.DAY,
            entries = scheduleRepository.entries.value
        )
    )
    val uiState: StateFlow<ScheduleUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            scheduleRepository.entries.collect { entryList ->
                _uiState.update { it.copy(entries = entryList) }
            }
        }
    }

    fun selectViewMode(mode: ScheduleViewMode) {
        _uiState.update { it.copy(selectedViewMode = mode) }
    }

    fun setFilterType(type: ScheduleEntryType?) {
        _uiState.update { it.copy(filterType = type) }
    }

    fun toggleComplete(id: String) {
        val target = _uiState.value.entries.find { it.id == id }
        scheduleRepository.toggleEntryCompletion(id)
        val feedback = if (target?.isCompleted == false) {
            "Completed: ${target.title}"
        } else {
            "Marked active: ${target?.title}"
        }
        _uiState.update {
            it.copy(
                entries = scheduleRepository.entries.value,
                quickActionFeedback = feedback
            )
        }
        clearFeedbackAfterDelay()
    }

    fun dismissEntry(id: String) {
        val target = _uiState.value.entries.find { it.id == id }
        scheduleRepository.dismissEntry(id)
        _uiState.update {
            it.copy(
                entries = scheduleRepository.entries.value,
                quickActionFeedback = "Dismissed: ${target?.title ?: "Item"}"
            )
        }
        clearFeedbackAfterDelay()
    }

    private fun clearFeedbackAfterDelay() {
        viewModelScope.launch {
            delay(2800)
            _uiState.update { it.copy(quickActionFeedback = null) }
        }
    }
}
