package com.example.ui.screens.alarms

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeAlarmsRepository
import com.example.domain.model.AlarmDay
import com.example.domain.model.AlarmsUiState
import com.example.domain.model.DeviceSyncState
import com.example.domain.model.MobileAlarm
import com.example.domain.repository.AlarmsRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * In-memory ViewModel for Alarms.
 * Manages alarm list, toggling, editor create/edit flow, sound selection, vibration,
 * PC mirroring, and Redundancy / Synchronization status toggling.
 * Injects AlarmsRepository for shared state.
 */
class AlarmsViewModel(
    private val alarmsRepository: AlarmsRepository = FakeAlarmsRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        AlarmsUiState(
            alarms = alarmsRepository.alarms.value,
            globalRedundancy = alarmsRepository.redundancyStatus.value
        )
    )
    val uiState: StateFlow<AlarmsUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            alarmsRepository.alarms.collect { alarmList ->
                _uiState.update { it.copy(alarms = alarmList) }
            }
        }
        viewModelScope.launch {
            alarmsRepository.redundancyStatus.collect { redundancy ->
                _uiState.update { it.copy(globalRedundancy = redundancy) }
            }
        }
    }

    fun toggleAlarmEnabled(id: String) {
        val target = _uiState.value.alarms.find { it.id == id }
        alarmsRepository.toggleAlarmEnabled(id)
        val feedback = if (target?.isEnabled == false) {
            "Alarm armed: ${target.time} (${target.title})"
        } else {
            "Alarm disabled: ${target?.title ?: "Alarm"}"
        }
        _uiState.update {
            it.copy(
                alarms = alarmsRepository.alarms.value,
                statusFeedbackMessage = feedback
            )
        }
        clearFeedbackAfterDelay()
    }

    fun deleteAlarm(id: String) {
        val target = _uiState.value.alarms.find { it.id == id }
        alarmsRepository.deleteAlarm(id)
        _uiState.update {
            it.copy(
                alarms = alarmsRepository.alarms.value,
                statusFeedbackMessage = "Deleted alarm: ${target?.title ?: "Alarm"}"
            )
        }
        clearFeedbackAfterDelay()
    }

    fun openCreateEditor() {
        _uiState.update { it.copy(isEditorOpen = true, editingAlarmId = null) }
    }

    fun openEditEditor(id: String) {
        _uiState.update { it.copy(isEditorOpen = true, editingAlarmId = id) }
    }

    fun closeEditor() {
        _uiState.update { it.copy(isEditorOpen = false, editingAlarmId = null) }
    }

    fun saveAlarm(
        title: String,
        time: String,
        recurrenceDays: Set<AlarmDay>,
        vibrate: Boolean,
        soundName: String,
        isEnabled: Boolean,
        pcMirroring: Boolean
    ) {
        val recurrenceLabel = computeRecurrenceLabel(recurrenceDays)
        val editingId = _uiState.value.editingAlarmId

        val alarmToSave = if (editingId != null) {
            val existing = _uiState.value.alarms.find { it.id == editingId }
            existing?.copy(
                title = title,
                time = time,
                recurrenceDays = recurrenceDays,
                recurrenceLabel = recurrenceLabel,
                vibrate = vibrate,
                soundName = soundName,
                isEnabled = isEnabled,
                pcMirroring = pcMirroring,
                desktopSyncState = if (pcMirroring) DeviceSyncState.SYNCHRONIZED else DeviceSyncState.OFFLINE,
                androidArmedState = if (isEnabled) DeviceSyncState.ARMED_LOCALLY else DeviceSyncState.OFFLINE
            ) ?: MobileAlarm(
                id = editingId,
                title = title,
                time = time,
                recurrenceDays = recurrenceDays,
                recurrenceLabel = recurrenceLabel,
                isEnabled = isEnabled,
                vibrate = vibrate,
                soundName = soundName,
                pcMirroring = pcMirroring,
                desktopSyncState = if (pcMirroring) DeviceSyncState.SYNCHRONIZED else DeviceSyncState.OFFLINE,
                androidArmedState = if (isEnabled) DeviceSyncState.ARMED_LOCALLY else DeviceSyncState.OFFLINE,
                nextTriggerLabel = "Next scheduled: $recurrenceLabel"
            )
        } else {
            MobileAlarm(
                id = "alarm_${UUID.randomUUID().toString().take(8)}",
                title = title,
                time = time,
                recurrenceDays = recurrenceDays,
                recurrenceLabel = recurrenceLabel,
                isEnabled = isEnabled,
                vibrate = vibrate,
                soundName = soundName,
                pcMirroring = pcMirroring,
                desktopSyncState = if (pcMirroring) DeviceSyncState.SYNCHRONIZED else DeviceSyncState.OFFLINE,
                androidArmedState = if (isEnabled) DeviceSyncState.ARMED_LOCALLY else DeviceSyncState.OFFLINE,
                nextTriggerLabel = "Next scheduled: $recurrenceLabel"
            )
        }

        alarmsRepository.saveAlarm(alarmToSave)
        val feedback = if (editingId != null) "Alarm updated: $title" else "New alarm created: $title"
        _uiState.update {
            it.copy(
                alarms = alarmsRepository.alarms.value,
                isEditorOpen = false,
                editingAlarmId = null,
                statusFeedbackMessage = feedback
            )
        }
        clearFeedbackAfterDelay()
    }

    fun toggleRedundancySimulation() {
        val wasSync = _uiState.value.globalRedundancy.desktopStatus == DeviceSyncState.SYNCHRONIZED
        alarmsRepository.toggleRedundancySimulation()
        val feedback = if (!wasSync) {
            "Redundancy: Desktop Synchronized • Android Armed"
        } else {
            "Redundancy: Desktop Offline • Android Armed Locally"
        }
        _uiState.update {
            it.copy(
                globalRedundancy = alarmsRepository.redundancyStatus.value,
                statusFeedbackMessage = feedback
            )
        }
        clearFeedbackAfterDelay()
    }

    private fun computeRecurrenceLabel(days: Set<AlarmDay>): String {
        return when {
            days.isEmpty() -> "Once"
            days.size == 7 -> "Every day"
            days == setOf(AlarmDay.MON, AlarmDay.TUE, AlarmDay.WED, AlarmDay.THU, AlarmDay.FRI) -> "Weekdays"
            days == setOf(AlarmDay.SAT, AlarmDay.SUN) -> "Weekends"
            else -> days.joinToString(", ") { it.code }
        }
    }

    private fun clearFeedbackAfterDelay() {
        viewModelScope.launch {
            delay(2800)
            _uiState.update { it.copy(statusFeedbackMessage = null) }
        }
    }
}
