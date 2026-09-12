package com.example.domain.model

/**
 * Health Time Range selector.
 */
enum class HealthTimeRange(val label: String) {
    TODAY("Today"),
    WEEK("Week"),
    MONTH("Month")
}

/**
 * Data Availability states per user specification.
 * - AVAILABLE: metric is successfully captured and fresh
 * - UNAVAILABLE: metric is missing, no data recorded (MUST NOT display fake zero values)
 * - STALE: data exists but last sync was delayed / hours ago
 * - UNSUPPORTED: hardware wearable or provider does not have this sensor
 * - NOT_SYNCHRONIZED: pending synchronization from Health Connect
 */
enum class HealthDataAvailability(val displayName: String) {
    AVAILABLE("Available"),
    UNAVAILABLE("Unavailable"),
    STALE("Stale"),
    UNSUPPORTED("Unsupported"),
    NOT_SYNCHRONIZED("Not Synchronized")
}

/**
 * Supported health metric types.
 */
enum class HealthMetricType(val displayName: String) {
    HEART_RATE("Heart Rate"),
    SLEEP("Sleep"),
    STEPS("Steps"),
    ACTIVITY("Activity"),
    BLOOD_OXYGEN("Blood Oxygen (SpO2)")
}

/**
 * Health Metric data point.
 */
data class HealthMetric(
    val type: HealthMetricType,
    val availability: HealthDataAvailability,
    val value: String? = null,              // e.g. "71", "7h 42m", "8,420", "42m", "98%"
    val unit: String? = null,               // e.g. "BPM", "", "steps", "active min", "%"
    val secondaryText: String? = null,      // e.g. "Resting 62 • Max 118", "Deep 2h 10m • REM 1h 45m"
    val lastRecordedText: String? = null,   // e.g. "12m ago", "Yesterday 11:30 PM"
    val unavailableMessage: String? = null, // e.g. "No SpO2 data available", "Awaiting sync from Health Connect"
    val targetGoal: String? = null,         // e.g. "Goal: 10,000 steps"
    val progressRatio: Float? = null        // 0f to 1f for progress bars/rings if applicable
)

/**
 * Non-diagnostic wellness insight.
 * Strictly uses observational, non-diagnostic wording (e.g. "Your recent sleep duration has been below your weekly average.")
 */
data class WellnessInsight(
    val id: String,
    val title: String,
    val description: String,
    val metricType: HealthMetricType,
    val timestamp: String = "Today"
)

/**
 * Replaceable Source Status model.
 * Pipeline: Smartwatch → FitCloudPro → Health Connect → Android App → Local AI Core
 */
data class HealthSourceStatus(
    val providerName: String = "Health Connect",
    val providerStatus: String = "Mock Connected",
    val upstreamSource: String = "FitCloudPro",
    val wearableDeviceName: String = "Smartwatch (BLE)",
    val pipelineSummary: String = "Smartwatch → FitCloudPro → Health Connect → Android App → Local AI Core",
    val lastSyncTime: String = "Just now",
    val isReplaceable: Boolean = true
)

/**
 * Overall Health UI State.
 */
data class HealthUiState(
    val selectedTimeRange: HealthTimeRange = HealthTimeRange.TODAY,
    val sourceStatus: HealthSourceStatus = HealthSourceStatus(),
    val metrics: List<HealthMetric> = emptyList(),
    val wellnessInsights: List<WellnessInsight> = emptyList(),
    val isSyncing: Boolean = false,
    val feedbackMessage: String? = null
)
