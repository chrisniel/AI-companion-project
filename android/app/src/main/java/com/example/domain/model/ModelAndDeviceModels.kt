package com.example.domain.model

/**
 * Execution location for an AI model.
 */
enum class ModelLocation(val label: String) {
    LOCAL("Local"),
    CLOUD("Cloud")
}

/**
 * Mobile performance profile targets.
 */
enum class PerformanceProfile(val displayName: String, val subtitle: String) {
    ECO("Eco", "Low power draw, conservative context batching for thermal efficiency"),
    BALANCED("Balanced", "Optimal blend of latency, energy consumption, and token rate"),
    MAXIMUM("Maximum", "Full compute utilization, maximum throughput and parallel inference")
}

/**
 * Mobile request routing policy.
 */
enum class RoutingPolicy(val displayName: String, val subtitle: String) {
    LOCAL_ONLY("Local Only", "Strict privacy: Zero queries leave your private network."),
    LOCAL_FIRST("Local First", "Prioritizes local compute node; falls back to cloud if unreachable."),
    CLOUD_FIRST("Cloud First", "Routes to cloud endpoints first for max speed; falls back to local."),
    CLOUD_ONLY("Cloud Only", "Direct cloud provider execution only.")
}

/**
 * Lightweight mobile model descriptor.
 */
data class ModelInfo(
    val id: String,
    val name: String,
    val location: ModelLocation,
    val provider: String,
    val contextWindow: String,
    val parameterSize: String,
    val description: String,
    val isCurrent: Boolean = false
)

/**
 * Optional mock PC resource summary.
 */
data class PcResourceSummary(
    val cpuUsagePercent: Int = 18,
    val cpuInfo: String = "8 Cores / 16 Threads",
    val ramUsedGb: Float = 14.2f,
    val ramTotalGb: Float = 32.0f,
    val gpuUsagePercent: Int = 36,
    val gpuModel: String = "Dedicated AI Accelerator",
    val vramUsedGb: Float = 6.4f,
    val vramTotalGb: Float = 16.0f,
    val gpuTempCelsius: Int = 41
)

/**
 * UI state for the mobile Models page.
 */
data class ModelsUiState(
    val currentModel: ModelInfo,
    val availableModels: List<ModelInfo> = emptyList(),
    val performanceProfile: PerformanceProfile = PerformanceProfile.BALANCED,
    val routingPolicy: RoutingPolicy = RoutingPolicy.LOCAL_FIRST,
    val pcResourceSummary: PcResourceSummary = PcResourceSummary(),
    val isPcResourcesExpanded: Boolean = false,
    val statusMessage: String? = null
)

/**
 * Status indicator for paired nodes and devices.
 */
enum class DeviceStatus(val label: String) {
    ONLINE("Online"),
    OFFLINE("Offline"),
    CONNECTING("Connecting")
}

/**
 * Generic functional device category.
 */
enum class DeviceCategory(val displayName: String) {
    CORE_PC("AI Core PC"),
    PHONE("Mobile Phone"),
    AUDIO_OUTPUT("Audio Output"),
    MICROPHONE("Microphone"),
    HEALTH_PROVIDER("Health Provider")
}

/**
 * Generic mock device representation without hardcoded commercial brand names.
 */
data class DeviceItem(
    val id: String,
    val name: String,
    val category: DeviceCategory,
    val status: DeviceStatus,
    val roleDescription: String,
    val connectionType: String,
    val latencyMs: Int? = null,
    val details: String
)

/**
 * UI state for the mobile Devices page.
 */
data class DevicesUiState(
    val devices: List<DeviceItem> = emptyList(),
    val isPinging: Boolean = false,
    val statusMessage: String? = null
)
