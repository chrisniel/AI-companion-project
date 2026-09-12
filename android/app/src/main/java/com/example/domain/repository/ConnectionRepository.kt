package com.example.domain.repository

import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.SyncStatus
import kotlinx.coroutines.flow.StateFlow

/**
 * Repository interface for managing host connection configuration,
 * reachability state, and pairing credentials.
 */
interface ConnectionRepository {
    val connectionInfo: StateFlow<ConnectionInfo>

    fun saveHostConfig(host: String, port: Int, token: String?)
    fun setConnectionState(state: CoreConnectionState)
    fun setSyncStatus(status: SyncStatus)
    fun updateLatency(latencyMs: Int?)
    fun getBaseUrl(): String
    fun getToken(): String?
}
