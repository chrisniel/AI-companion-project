package com.example.data.health

import com.example.domain.model.HealthMetric
import com.example.domain.model.HealthSourceStatus
import com.example.domain.model.HealthTimeRange
import com.example.domain.model.WellnessInsight
import kotlinx.coroutines.flow.Flow

/**
 * Replaceable abstraction interface for health data ingestion.
 *
 * Current Architecture:
 * Smartwatch → FitCloudPro → Health Connect → Android App → Local AI Core
 *
 * Future Migration:
 * This interface decouples the UI and business logic from the concrete provider,
 * allowing effortless replacement of [MockHealthDataProvider] with a real
 * Health Connect Client API implementation without rewriting composables.
 */
interface HealthDataProvider {
    val providerId: String
    val providerDisplayName: String

    fun getSourceStatus(): HealthSourceStatus
    fun getHealthMetrics(timeRange: HealthTimeRange): List<HealthMetric>
    fun getWellnessInsights(timeRange: HealthTimeRange): List<WellnessInsight>

    fun observeSourceStatus(): Flow<HealthSourceStatus>
    fun observeHealthMetrics(timeRange: HealthTimeRange): Flow<List<HealthMetric>>
    fun observeWellnessInsights(timeRange: HealthTimeRange): Flow<List<WellnessInsight>>
    suspend fun triggerSync()
}
