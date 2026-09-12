package com.example.data.repository

import android.content.Context
import android.content.SharedPreferences
import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.SyncStatus
import com.example.domain.repository.ConnectionRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Production-ready ConnectionRepository backed by Android SharedPreferences.
 *
 * Persists PC host address, port, and pairing key across app lifecycles.
 */
class SharedPreferencesConnectionRepository(
    context: Context,
    prefsName: String = PREFS_NAME
) : ConnectionRepository {

    private val sharedPreferences: SharedPreferences =
        context.applicationContext.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

    private val _connectionInfo = MutableStateFlow(loadConnectionInfo())
    override val connectionInfo: StateFlow<ConnectionInfo> = _connectionInfo.asStateFlow()

    private fun loadConnectionInfo(): ConnectionInfo {
        val host = sharedPreferences.getString(KEY_HOST, DEFAULT_HOST) ?: DEFAULT_HOST
        val port = sharedPreferences.getInt(KEY_PORT, DEFAULT_PORT)
        val token = sharedPreferences.getString(KEY_TOKEN, null)

        val stateStr = sharedPreferences.getString(KEY_STATE, CoreConnectionState.Offline.name)
        val state = runCatching { CoreConnectionState.valueOf(stateStr ?: CoreConnectionState.Offline.name) }
            .getOrDefault(CoreConnectionState.Offline)

        val syncStatusStr = sharedPreferences.getString(KEY_SYNC_STATUS, SyncStatus.SYNCHRONIZED.name)
        val syncStatus = runCatching { SyncStatus.valueOf(syncStatusStr ?: SyncStatus.SYNCHRONIZED.name) }
            .getOrDefault(SyncStatus.SYNCHRONIZED)

        val latency = if (sharedPreferences.contains(KEY_LATENCY)) sharedPreferences.getInt(KEY_LATENCY, 0) else null

        return ConnectionInfo(
            state = state,
            label = if (state.isOnline) "Core Active" else "PC Offline",
            latencyMs = latency,
            port = port,
            host = host,
            syncStatus = syncStatus,
            token = token
        )
    }

    override fun saveHostConfig(host: String, port: Int, token: String?) {
        val cleanHost = host.trim().removePrefix("http://").removePrefix("https://").trimEnd('/')
        val cleanToken = token?.trim()?.ifEmpty { null }

        _connectionInfo.update { current ->
            current.copy(
                host = cleanHost,
                port = port,
                token = cleanToken
            )
        }

        sharedPreferences.edit()
            .putString(KEY_HOST, cleanHost)
            .putInt(KEY_PORT, port)
            .apply {
                if (cleanToken != null) putString(KEY_TOKEN, cleanToken)
                else remove(KEY_TOKEN)
            }
            .apply()
    }

    override fun setConnectionState(state: CoreConnectionState) {
        _connectionInfo.update { current ->
            current.copy(
                state = state,
                label = when (state) {
                    CoreConnectionState.Local -> "Local LAN Active"
                    CoreConnectionState.Remote -> "Remote Active"
                    CoreConnectionState.Connecting -> "Connecting..."
                    CoreConnectionState.Reconnecting -> "Reconnecting..."
                    CoreConnectionState.Offline -> "PC Offline"
                }
            )
        }
        sharedPreferences.edit().putString(KEY_STATE, state.name).apply()
    }

    override fun setSyncStatus(status: SyncStatus) {
        _connectionInfo.update { it.copy(syncStatus = status) }
        sharedPreferences.edit().putString(KEY_SYNC_STATUS, status.name).apply()
    }

    override fun updateLatency(latencyMs: Int?) {
        _connectionInfo.update { it.copy(latencyMs = latencyMs) }
        val editor = sharedPreferences.edit()
        if (latencyMs != null) editor.putInt(KEY_LATENCY, latencyMs)
        else editor.remove(KEY_LATENCY)
        editor.apply()
    }

    override fun getBaseUrl(): String {
        val current = _connectionInfo.value
        val host = current.host.ifEmpty { DEFAULT_HOST }
        val port = current.port ?: DEFAULT_PORT
        return "http://$host:$port"
    }

    override fun getToken(): String? {
        return _connectionInfo.value.token
    }

    companion object {
        const val PREFS_NAME = "app_connection_prefs"
        const val DEFAULT_HOST = "192.168.1.15"
        const val DEFAULT_PORT = 8000

        private const val KEY_HOST = "host_address"
        private const val KEY_PORT = "host_port"
        private const val KEY_TOKEN = "pairing_token"
        private const val KEY_STATE = "connection_state"
        private const val KEY_SYNC_STATUS = "sync_status"
        private const val KEY_LATENCY = "latency_ms"
    }
}
