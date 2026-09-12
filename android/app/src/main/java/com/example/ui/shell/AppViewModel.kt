package com.example.ui.shell

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeHomeRepository
import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.HomeData
import com.example.domain.model.LanguageOption
import com.example.domain.model.SyncStatus
import com.example.domain.repository.HomeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

import com.example.data.fake.FakeAppearanceRepository
import com.example.domain.model.ThemeMode
import com.example.domain.repository.AppearanceRepository

data class AppUiState(
    val connectionInfo: ConnectionInfo = ConnectionInfo(
        state = CoreConnectionState.Local,
        label = "Core Active",
        latencyMs = 22,
        host = "Local AI Core (Simulated)",
        port = 8080,
        syncStatus = SyncStatus.SYNCHRONIZED,
        lastSyncTimestamp = "Just now",
        pendingChangesCount = 0,
        isCloudFallbackEnabled = false
    ),
    val selectedPersona: String = "Aura",
    val userName: String = "Chris",
    val language: LanguageOption = LanguageOption.AUTO,
    val showOfflineCapabilitiesSheet: Boolean = false,
    val showSyncBanner: Boolean = true,
    val showConnectionBanner: Boolean = true,
    val capabilitiesState: com.example.domain.model.CapabilitiesState = com.example.domain.model.CapabilitiesState()
)

class AppViewModel(
    private val homeRepository: HomeRepository = FakeHomeRepository(),
    private val appearanceRepository: AppearanceRepository = FakeAppearanceRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(AppUiState())
    val uiState: StateFlow<AppUiState> = _uiState.asStateFlow()

    val homeData: StateFlow<HomeData> = homeRepository.getHomeData()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.Eagerly,
            initialValue = FakeHomeRepository.DEFAULT_HOME_DATA
        )

    init {
        // Authoritative appearance preferences are consumed directly from AppearanceRepository
    }

    fun toggleTask(taskId: String) {
        viewModelScope.launch {
            homeRepository.toggleTaskCompletion(taskId)
        }
    }

    fun addNewTask(title: String, priority: String = "Normal") {
        viewModelScope.launch {
            homeRepository.addNewTask(title, priority)
        }
    }

    fun toggleTheme() {
        val currentMode = appearanceRepository.preferences.value.themeMode
        val nextMode = if (currentMode == ThemeMode.DARK) ThemeMode.LIGHT else ThemeMode.DARK
        appearanceRepository.setThemeMode(nextMode)
    }

    fun setTheme(isDark: Boolean) {
        appearanceRepository.setThemeMode(if (isDark) ThemeMode.DARK else ThemeMode.LIGHT)
    }

    fun selectPersona(persona: String) {
        _uiState.update { it.copy(selectedPersona = persona) }
    }

    fun setLanguage(language: LanguageOption) {
        _uiState.update { it.copy(language = language) }
    }

    fun cycleLanguage() {
        _uiState.update { current ->
            val options = LanguageOption.entries
            val nextIndex = (options.indexOf(current.language) + 1) % options.size
            current.copy(language = options[nextIndex])
        }
    }

    /**
     * Cycles through the 5 mock connection states (Batch 12):
     * Local LAN -> Remote -> Connecting -> Reconnecting -> Offline -> Local LAN
     */
    fun cycleConnectionState() {
        _uiState.update { current ->
            val nextState = when (current.connectionInfo.state) {
                CoreConnectionState.Local -> ConnectionInfo(
                    state = CoreConnectionState.Remote,
                    label = "Remote Node",
                    latencyMs = 45,
                    host = "remote-node (Simulated)",
                    port = 8080,
                    syncStatus = current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = current.connectionInfo.pendingChangesCount
                )
                CoreConnectionState.Remote -> ConnectionInfo(
                    state = CoreConnectionState.Connecting,
                    label = "Connecting",
                    latencyMs = null,
                    host = "remote-node (Simulated)",
                    port = 8080,
                    syncStatus = current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = current.connectionInfo.pendingChangesCount
                )
                CoreConnectionState.Connecting -> ConnectionInfo(
                    state = CoreConnectionState.Reconnecting,
                    label = "Reconnecting",
                    latencyMs = null,
                    host = "remote-node (Simulated)",
                    port = 8080,
                    syncStatus = current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = current.connectionInfo.pendingChangesCount
                )
                CoreConnectionState.Reconnecting -> ConnectionInfo(
                    state = CoreConnectionState.Offline,
                    label = "PC Offline",
                    latencyMs = null,
                    host = "offline (Disconnected)",
                    port = null,
                    syncStatus = if (current.connectionInfo.syncStatus == SyncStatus.SYNCHRONIZED) SyncStatus.PENDING else current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = 3
                )
                CoreConnectionState.Offline -> ConnectionInfo(
                    state = CoreConnectionState.Local,
                    label = "Core Active",
                    latencyMs = 22,
                    host = "Local AI Core (Simulated)",
                    port = 8080,
                    syncStatus = SyncStatus.SYNCHRONIZED,
                    lastSyncTimestamp = "Just now",
                    pendingChangesCount = 0
                )
            }
            current.copy(
                connectionInfo = nextState,
                showConnectionBanner = true,
                showSyncBanner = true
            )
        }
    }

    fun setConnectionState(state: CoreConnectionState) {
        _uiState.update { current ->
            val info = when (state) {
                CoreConnectionState.Local -> ConnectionInfo(
                    state = CoreConnectionState.Local,
                    label = "Core Active",
                    latencyMs = 22,
                    host = "Local AI Core (Simulated)",
                    port = 8080,
                    syncStatus = current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = current.connectionInfo.pendingChangesCount
                )
                CoreConnectionState.Remote -> ConnectionInfo(
                    state = CoreConnectionState.Remote,
                    label = "Remote Node",
                    latencyMs = 45,
                    host = "remote-node (Simulated)",
                    port = 8080,
                    syncStatus = current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = current.connectionInfo.pendingChangesCount
                )
                CoreConnectionState.Connecting -> ConnectionInfo(
                    state = CoreConnectionState.Connecting,
                    label = "Connecting",
                    latencyMs = null,
                    host = "remote-node (Simulated)",
                    port = 8080,
                    syncStatus = current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = current.connectionInfo.pendingChangesCount
                )
                CoreConnectionState.Reconnecting -> ConnectionInfo(
                    state = CoreConnectionState.Reconnecting,
                    label = "Reconnecting",
                    latencyMs = null,
                    host = "remote-node (Simulated)",
                    port = 8080,
                    syncStatus = current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = current.connectionInfo.pendingChangesCount
                )
                CoreConnectionState.Offline -> ConnectionInfo(
                    state = CoreConnectionState.Offline,
                    label = "PC Offline",
                    latencyMs = null,
                    host = "offline (Disconnected)",
                    port = null,
                    syncStatus = if (current.connectionInfo.syncStatus == SyncStatus.SYNCHRONIZED) SyncStatus.PENDING else current.connectionInfo.syncStatus,
                    lastSyncTimestamp = current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = 3
                )
            }
            current.copy(
                connectionInfo = info,
                showConnectionBanner = true,
                showSyncBanner = true
            )
        }
    }

    fun setSyncStatus(status: SyncStatus) {
        _uiState.update { current ->
            current.copy(
                connectionInfo = current.connectionInfo.copy(
                    syncStatus = status,
                    lastSyncTimestamp = if (status == SyncStatus.SYNCHRONIZED) "Just now" else current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = if (status == SyncStatus.PENDING) 3 else 0
                ),
                showSyncBanner = true
            )
        }
    }

    fun cycleSyncStatus() {
        _uiState.update { current ->
            val statuses = SyncStatus.entries
            val nextIndex = (statuses.indexOf(current.connectionInfo.syncStatus) + 1) % statuses.size
            val nextStatus = statuses[nextIndex]
            current.copy(
                connectionInfo = current.connectionInfo.copy(
                    syncStatus = nextStatus,
                    lastSyncTimestamp = if (nextStatus == SyncStatus.SYNCHRONIZED) "Just now" else current.connectionInfo.lastSyncTimestamp,
                    pendingChangesCount = if (nextStatus == SyncStatus.PENDING) 3 else 0
                ),
                showSyncBanner = true
            )
        }
    }

    fun resolveSyncConflict(keepLocal: Boolean = true) {
        _uiState.update { current ->
            current.copy(
                connectionInfo = current.connectionInfo.copy(
                    syncStatus = SyncStatus.SYNCHRONIZED,
                    lastSyncTimestamp = "Just now",
                    pendingChangesCount = 0
                )
            )
        }
    }

    fun retrySync() {
        _uiState.update { current ->
            val newStatus = if (current.connectionInfo.state.isOnline) SyncStatus.SYNCHRONIZED else SyncStatus.FAILED
            current.copy(
                connectionInfo = current.connectionInfo.copy(
                    syncStatus = newStatus,
                    lastSyncTimestamp = if (newStatus == SyncStatus.SYNCHRONIZED) "Just now" else current.connectionInfo.lastSyncTimestamp
                )
            )
        }
    }

    fun toggleOfflineCapabilitiesSheet(show: Boolean) {
        _uiState.update { it.copy(showOfflineCapabilitiesSheet = show) }
    }

    fun dismissSyncBanner() {
        _uiState.update { it.copy(showSyncBanner = false) }
    }

    fun dismissConnectionBanner() {
        _uiState.update { it.copy(showConnectionBanner = false) }
    }

    // ==========================================
    // BATCH 13: CAPABILITIES & PERMISSION STATES
    // ==========================================

    fun setMicrophoneState(state: com.example.domain.model.MicrophoneCapabilityState) {
        _uiState.update { current ->
            current.copy(
                capabilitiesState = current.capabilitiesState.copy(microphoneState = state)
            )
        }
    }

    fun setNotificationState(state: com.example.domain.model.NotificationCapabilityState) {
        _uiState.update { current ->
            current.copy(
                capabilitiesState = current.capabilitiesState.copy(notificationState = state)
            )
        }
    }

    fun setHealthConnectState(state: com.example.domain.model.HealthConnectCapabilityState) {
        _uiState.update { current ->
            current.copy(
                capabilitiesState = current.capabilitiesState.copy(healthConnectState = state)
            )
        }
    }

    fun setAlarmCapabilityState(state: com.example.domain.model.AlarmCapabilityState) {
        _uiState.update { current ->
            current.copy(
                capabilitiesState = current.capabilitiesState.copy(alarmCapabilityState = state)
            )
        }
    }

    fun setBluetoothAudioRequired(required: Boolean) {
        _uiState.update { current ->
            current.copy(
                capabilitiesState = current.capabilitiesState.copy(
                    isBluetoothAudioRequired = required,
                    bluetoothAudioState = if (required && current.capabilitiesState.bluetoothAudioState == com.example.domain.model.BluetoothAudioCapabilityState.NOT_REQUIRED) {
                        com.example.domain.model.BluetoothAudioCapabilityState.PERMISSION_NEEDED
                    } else if (!required) {
                        com.example.domain.model.BluetoothAudioCapabilityState.NOT_REQUIRED
                    } else {
                        current.capabilitiesState.bluetoothAudioState
                    }
                )
            )
        }
    }

    fun setBluetoothAudioState(state: com.example.domain.model.BluetoothAudioCapabilityState) {
        _uiState.update { current ->
            current.copy(
                capabilitiesState = current.capabilitiesState.copy(bluetoothAudioState = state)
            )
        }
    }

    fun resetCapabilitiesToDefaults() {
        _uiState.update { current ->
            current.copy(
                capabilitiesState = com.example.domain.model.CapabilitiesState()
            )
        }
    }
}

