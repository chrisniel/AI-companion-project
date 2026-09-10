package com.example.ui.screens.devices

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeModelsAndDevicesRepository
import com.example.domain.model.DeviceStatus
import com.example.domain.model.DevicesUiState
import com.example.domain.repository.ModelsAndDevicesRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * ViewModel for the Mobile Devices page (Batch 9).
 * Displays mock local nodes (AI Core PC, This Phone, audio output, microphone, health provider)
 * with status indicators (Online, Offline, Connecting), ping testing, and status toggles.
 */
class DevicesViewModel(
    private val repository: ModelsAndDevicesRepository = FakeModelsAndDevicesRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        DevicesUiState(
            devices = repository.devices.value,
            isPinging = false
        )
    )
    val uiState: StateFlow<DevicesUiState> = _uiState.asStateFlow()

    fun pingAllDevices() {
        if (_uiState.value.isPinging) return
        _uiState.update { it.copy(isPinging = true) }
        viewModelScope.launch {
            repository.pingDevices()
            _uiState.update { it.copy(isPinging = false) }
            showStatus("Pinging mesh nodes complete • All latencies refreshed")
        }
    }

    fun toggleDeviceStatus(deviceId: String) {
        _uiState.update { state ->
            val updated = state.devices.map { dev ->
                if (dev.id == deviceId) {
                    val nextStatus = when (dev.status) {
                        DeviceStatus.ONLINE -> DeviceStatus.OFFLINE
                        DeviceStatus.OFFLINE -> DeviceStatus.CONNECTING
                        DeviceStatus.CONNECTING -> DeviceStatus.ONLINE
                    }
                    dev.copy(status = nextStatus)
                } else dev
            }
            state.copy(devices = updated)
        }
        val dev = _uiState.value.devices.firstOrNull { it.id == deviceId }
        showStatus("Updated ${dev?.name ?: "device"} status")
        viewModelScope.launch {
            repository.toggleDeviceStatus(deviceId)
        }
    }

    fun setDeviceStatus(deviceId: String, status: DeviceStatus) {
        _uiState.update { state ->
            val updated = state.devices.map { dev ->
                if (dev.id == deviceId) dev.copy(status = status) else dev
            }
            state.copy(devices = updated)
        }
        viewModelScope.launch {
            repository.setDeviceStatus(deviceId, status)
        }
    }

    fun clearStatus() {
        _uiState.update { it.copy(statusMessage = null) }
    }

    private fun showStatus(message: String) {
        _uiState.update { it.copy(statusMessage = message) }
    }
}
