package com.example.data.fake

import com.example.domain.model.ConnectionInfo
import com.example.domain.model.ControlCenterConfig
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.LanguageOption
import com.example.domain.model.MetricItem
import com.example.domain.model.StatusSeverity
import com.example.domain.repository.DesignSystemRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class FakeDesignSystemRepository : DesignSystemRepository {

    private val _config = MutableStateFlow(
        ControlCenterConfig(
            assistantName = "Aura",
            assistantSubtitle = "Cognitive Core Assistant",
            userName = "Chris",
            activeModel = "Llama-3.1-8B-Instruct",
            runtimeProvider = "llama.cpp (CUDA/Metal)",
            connection = ConnectionInfo(
                state = CoreConnectionState.Online,
                label = "Core Active",
                latencyMs = 22,
                port = 8000
            )
        )
    )

    private val _metrics = MutableStateFlow(
        listOf(
            MetricItem(
                id = "model_latency",
                title = "Core Latency",
                value = "22",
                unit = "ms",
                subtitle = "Loopback RPC",
                progress = 0.22f,
                trendPercentage = -14.2f,
                isPositiveTrend = true,
                severity = StatusSeverity.Success
            ),
            MetricItem(
                id = "model_speed",
                title = "Inference Speed",
                value = "42.8",
                unit = "t/s",
                subtitle = "GPU Offloaded (33 layers)",
                progress = 0.72f,
                trendPercentage = 8.5f,
                isPositiveTrend = true,
                severity = StatusSeverity.Normal
            ),
            MetricItem(
                id = "vram_usage",
                title = "VRAM Allocation",
                value = "6.4",
                unit = "GB",
                subtitle = "Pinned 8B Q4_K_M",
                progress = 0.64f,
                trendPercentage = 0.0f,
                severity = StatusSeverity.Info
            ),
            MetricItem(
                id = "daily_tasks",
                title = "Today's Routine",
                value = "5/8",
                unit = "tasks",
                subtitle = "63% complete",
                progress = 0.63f,
                severity = StatusSeverity.Normal
            )
        )
    )

    override fun getConfig(): Flow<ControlCenterConfig> = _config.asStateFlow()

    override fun getMetrics(): Flow<List<MetricItem>> = _metrics.asStateFlow()

    override fun getSupportedLanguages(): List<LanguageOption> = LanguageOption.entries
}
