package com.example.data.fake

import com.example.domain.model.DeviceCategory
import com.example.domain.model.DeviceItem
import com.example.domain.model.DeviceStatus
import com.example.domain.model.ModelInfo
import com.example.domain.model.ModelLocation
import com.example.domain.model.PcResourceSummary
import com.example.domain.model.PerformanceProfile
import com.example.domain.model.RoutingPolicy
import com.example.domain.repository.ModelsAndDevicesRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Fake in-memory repository implementing ModelsAndDevicesRepository for mobile preview and testing.
 */
class FakeModelsAndDevicesRepository : ModelsAndDevicesRepository {

    private val defaultModels = listOf(
        ModelInfo(
            id = "llama_3_2_3b",
            name = "Llama-3.2-3B Instruct",
            location = ModelLocation.LOCAL,
            provider = "llama.cpp on Local PC",
            contextWindow = "128k tokens",
            parameterSize = "3.2B parameters (Q4_K_M)",
            description = "High efficiency on-device lightweight core for fast everyday responses.",
            isCurrent = true
        ),
        ModelInfo(
            id = "qwen_2_5_7b",
            name = "Qwen-2.5-7B Coder",
            location = ModelLocation.LOCAL,
            provider = "Ollama LAN Node",
            contextWindow = "32k tokens",
            parameterSize = "7.6B parameters (Q5_K_M)",
            description = "Specialized code synthesis and reasoning model hosted on private LAN.",
            isCurrent = false
        ),
        ModelInfo(
            id = "deepseek_r1_distill_8b",
            name = "DeepSeek-R1-Distill-8B",
            location = ModelLocation.LOCAL,
            provider = "Local AI Core PC",
            contextWindow = "64k tokens",
            parameterSize = "8.0B parameters (Q4_K_M)",
            description = "High-depth chain-of-thought distillation for analytical problem solving.",
            isCurrent = false
        ),
        ModelInfo(
            id = "cloud_flash_1_5",
            name = "Gemini 1.5 Flash",
            location = ModelLocation.CLOUD,
            provider = "Google Cloud AI Gateway",
            contextWindow = "1,000k tokens",
            parameterSize = "Cloud Managed API",
            description = "Ultra-low latency cloud model with massive context window capabilities.",
            isCurrent = false
        ),
        ModelInfo(
            id = "cloud_haiku_3_5",
            name = "Cloud Fast Reasoning Haiku",
            location = ModelLocation.CLOUD,
            provider = "Secure Cloud Gateway",
            contextWindow = "200k tokens",
            parameterSize = "Cloud Managed API",
            description = "General-purpose cloud reasoning backup when local node is offline.",
            isCurrent = false
        )
    )

    private val defaultDevices = listOf(
        DeviceItem(
            id = "dev_pc_core",
            name = "Local AI Core PC",
            category = DeviceCategory.CORE_PC,
            status = DeviceStatus.ONLINE,
            roleDescription = "Primary LLM inference host and cognitive coordinator",
            connectionType = "Local LAN / Wi-Fi Mesh",
            latencyMs = 18,
            details = "Direct Private Mesh • Host Active • High-Throughput Node"
        ),
        DeviceItem(
            id = "dev_phone",
            name = "This Phone",
            category = DeviceCategory.PHONE,
            status = DeviceStatus.ONLINE,
            roleDescription = "Mobile client, edge sensor hub, and voice interface",
            connectionType = "Local On-Device System",
            latencyMs = 1,
            details = "Android Client • Sensor Telemetry Stream Active"
        ),
        DeviceItem(
            id = "dev_audio_output",
            name = "Audio Output",
            category = DeviceCategory.AUDIO_OUTPUT,
            status = DeviceStatus.ONLINE,
            roleDescription = "Assistant synthesized speech and audible alarm output",
            connectionType = "System Audio Sink",
            latencyMs = 4,
            details = "48 kHz PCM Stream • Low-latency output sink"
        ),
        DeviceItem(
            id = "dev_microphone",
            name = "Microphone",
            category = DeviceCategory.MICROPHONE,
            status = DeviceStatus.ONLINE,
            roleDescription = "Voice command input and wake-word streaming buffer",
            connectionType = "Hardware Audio Ingest",
            latencyMs = 2,
            details = "16 kHz Mono Ingest • VAD Hardware Filter Active"
        ),
        DeviceItem(
            id = "dev_health_provider",
            name = "Health Provider",
            category = DeviceCategory.HEALTH_PROVIDER,
            status = DeviceStatus.ONLINE,
            roleDescription = "Biometric telemetry and daily activity data synchronizer",
            connectionType = "Local Health Connect Pipeline",
            latencyMs = 42,
            details = "Periodic Sync • Heart rate, steps, sleep stage telemetry"
        )
    )

    private val _availableModels = MutableStateFlow(defaultModels)
    override val availableModels: StateFlow<List<ModelInfo>> = _availableModels.asStateFlow()

    private val _currentModel = MutableStateFlow(defaultModels.first { it.isCurrent })
    override val currentModel: StateFlow<ModelInfo> = _currentModel.asStateFlow()

    private val _performanceProfile = MutableStateFlow(PerformanceProfile.BALANCED)
    override val performanceProfile: StateFlow<PerformanceProfile> = _performanceProfile.asStateFlow()

    private val _routingPolicy = MutableStateFlow(RoutingPolicy.LOCAL_FIRST)
    override val routingPolicy: StateFlow<RoutingPolicy> = _routingPolicy.asStateFlow()

    private val _pcResources = MutableStateFlow(PcResourceSummary())
    override val pcResources: StateFlow<PcResourceSummary> = _pcResources.asStateFlow()

    private val _devices = MutableStateFlow(defaultDevices)
    override val devices: StateFlow<List<DeviceItem>> = _devices.asStateFlow()

    override suspend fun selectModel(modelId: String) {
        _availableModels.update { list ->
            list.map { it.copy(isCurrent = (it.id == modelId)) }
        }
        val selected = _availableModels.value.firstOrNull { it.id == modelId }
        if (selected != null) {
            _currentModel.value = selected
        }
    }

    override suspend fun setPerformanceProfile(profile: PerformanceProfile) {
        _performanceProfile.value = profile
    }

    override suspend fun setRoutingPolicy(policy: RoutingPolicy) {
        _routingPolicy.value = policy
    }

    override suspend fun pingDevices() {
        // Temporarily set online devices to connecting, then restore with updated latency
        _devices.update { list ->
            list.map { dev ->
                if (dev.status == DeviceStatus.ONLINE) {
                    dev.copy(status = DeviceStatus.CONNECTING)
                } else dev
            }
        }
        delay(600)
        _devices.update { list ->
            list.map { dev ->
                if (dev.status == DeviceStatus.CONNECTING) {
                    dev.copy(
                        status = DeviceStatus.ONLINE,
                        latencyMs = when (dev.category) {
                            DeviceCategory.CORE_PC -> (15..25).random()
                            DeviceCategory.PHONE -> 1
                            DeviceCategory.AUDIO_OUTPUT -> (2..6).random()
                            DeviceCategory.MICROPHONE -> (1..4).random()
                            DeviceCategory.HEALTH_PROVIDER -> (35..55).random()
                        }
                    )
                } else dev
            }
        }
    }

    override suspend fun setDeviceStatus(deviceId: String, status: DeviceStatus) {
        _devices.update { list ->
            list.map { dev ->
                if (dev.id == deviceId) dev.copy(status = status) else dev
            }
        }
    }

    override suspend fun toggleDeviceStatus(deviceId: String) {
        _devices.update { list ->
            list.map { dev ->
                if (dev.id == deviceId) {
                    val nextStatus = when (dev.status) {
                        DeviceStatus.ONLINE -> DeviceStatus.OFFLINE
                        DeviceStatus.OFFLINE -> DeviceStatus.CONNECTING
                        DeviceStatus.CONNECTING -> DeviceStatus.ONLINE
                    }
                    dev.copy(status = nextStatus)
                } else dev
            }
        }
    }
}
