package com.example.ui.screens.health

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.health.HealthDataProvider
import com.example.data.health.MockHealthDataProvider
import com.example.domain.model.HealthDataAvailability
import com.example.domain.model.HealthMetric
import com.example.domain.model.HealthMetricType
import com.example.domain.model.HealthSourceStatus
import com.example.domain.model.HealthTimeRange
import com.example.domain.model.HealthUiState
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * ViewModel for Mobile Health and Wellness (Batch 7).
 * Decoupled from concrete implementation via [HealthDataProvider].
 */
class HealthViewModel(
    private val dataProvider: HealthDataProvider = MockHealthDataProvider()
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        HealthUiState(
            sourceStatus = dataProvider.getSourceStatus(),
            metrics = dataProvider.getHealthMetrics(HealthTimeRange.TODAY),
            wellnessInsights = dataProvider.getWellnessInsights(HealthTimeRange.TODAY)
        )
    )
    val uiState: StateFlow<HealthUiState> = _uiState.asStateFlow()

    init {
        // Observe replaceable source status
        dataProvider.observeSourceStatus()
            .onEach { status ->
                _uiState.update { it.copy(sourceStatus = status) }
            }
            .launchIn(viewModelScope)

        // Initial load for default time range
        loadMetricsAndInsights(HealthTimeRange.TODAY)
    }

    fun selectTimeRange(range: HealthTimeRange) {
        if (_uiState.value.selectedTimeRange == range) return
        _uiState.update {
            it.copy(
                selectedTimeRange = range,
                metrics = dataProvider.getHealthMetrics(range),
                wellnessInsights = dataProvider.getWellnessInsights(range)
            )
        }
        loadMetricsAndInsights(range)
    }

    fun triggerSync() {
        viewModelScope.launch {
            _uiState.update { it.copy(isSyncing = true, feedbackMessage = "Syncing from FitCloudPro via Health Connect...") }
            dataProvider.triggerSync()
            _uiState.update {
                it.copy(
                    isSyncing = false,
                    sourceStatus = dataProvider.getSourceStatus(),
                    feedbackMessage = "Health Connect sync updated successfully"
                )
            }
            clearFeedbackAfterDelay()
        }
    }

    /**
     * Enables quick inspection of all 5 data availability states:
     * AVAILABLE, UNAVAILABLE, STALE, UNSUPPORTED, NOT_SYNCHRONIZED.
     */
    fun selectAvailabilityProfile(profile: MockHealthDataProvider.AvailabilityProfile) {
        if (dataProvider is MockHealthDataProvider) {
            dataProvider.setAvailabilityProfile(profile)
            val range = _uiState.value.selectedTimeRange
            val profileMsg = when (profile) {
                MockHealthDataProvider.AvailabilityProfile.STANDARD_DEFAULT -> "Default Profile (SpO2 Unavailable)"
                MockHealthDataProvider.AvailabilityProfile.ALL_AVAILABLE -> "Profile: All Metrics Available"
                MockHealthDataProvider.AvailabilityProfile.STALE_SYNC -> "Profile: Stale Sync Delay"
                MockHealthDataProvider.AvailabilityProfile.UNSUPPORTED_SENSOR -> "Profile: Unsupported SpO2 Sensor"
                MockHealthDataProvider.AvailabilityProfile.NOT_SYNCHRONIZED -> "Profile: Awaiting Health Connect Handshake"
            }
            _uiState.update {
                it.copy(
                    metrics = dataProvider.getHealthMetrics(range),
                    wellnessInsights = dataProvider.getWellnessInsights(range),
                    feedbackMessage = profileMsg
                )
            }
            loadMetricsAndInsights(range)
            clearFeedbackAfterDelay()
        }
    }

    private fun loadMetricsAndInsights(range: HealthTimeRange) {
        dataProvider.observeHealthMetrics(range)
            .onEach { metricsList ->
                _uiState.update { it.copy(metrics = metricsList) }
            }
            .launchIn(viewModelScope)

        dataProvider.observeWellnessInsights(range)
            .onEach { insightsList ->
                _uiState.update { it.copy(wellnessInsights = insightsList) }
            }
            .launchIn(viewModelScope)
    }

    private fun clearFeedbackAfterDelay() {
        viewModelScope.launch {
            delay(2600)
            _uiState.update { it.copy(feedbackMessage = null) }
        }
    }
}
