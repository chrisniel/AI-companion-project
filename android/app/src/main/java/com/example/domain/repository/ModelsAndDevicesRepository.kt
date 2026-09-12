package com.example.domain.repository

import com.example.domain.model.DeviceItem
import com.example.domain.model.DeviceStatus
import com.example.domain.model.ModelInfo
import com.example.domain.model.PcResourceSummary
import com.example.domain.model.PerformanceProfile
import com.example.domain.model.RoutingPolicy
import kotlinx.coroutines.flow.StateFlow

/**
 * Repository interface for Mobile Models and Devices management (Batch 9).
 */
interface ModelsAndDevicesRepository {
    val currentModel: StateFlow<ModelInfo>
    val availableModels: StateFlow<List<ModelInfo>>
    val performanceProfile: StateFlow<PerformanceProfile>
    val routingPolicy: StateFlow<RoutingPolicy>
    val pcResources: StateFlow<PcResourceSummary>
    val devices: StateFlow<List<DeviceItem>>

    suspend fun selectModel(modelId: String)
    suspend fun setPerformanceProfile(profile: PerformanceProfile)
    suspend fun setRoutingPolicy(policy: RoutingPolicy)
    suspend fun pingDevices()
    suspend fun setDeviceStatus(deviceId: String, status: DeviceStatus)
    suspend fun toggleDeviceStatus(deviceId: String)
}
