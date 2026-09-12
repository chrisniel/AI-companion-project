package com.example.data.health

import com.example.domain.model.HealthDataAvailability
import com.example.domain.model.HealthMetric
import com.example.domain.model.HealthMetricType
import com.example.domain.model.HealthSourceStatus
import com.example.domain.model.HealthTimeRange
import com.example.domain.model.WellnessInsight
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Mock implementation of [HealthDataProvider].
 * Follows the replaceable provider architecture.
 *
 * Current intended source path:
 * Smartwatch → FitCloudPro → Health Connect → Android App → Local AI Core
 */
class MockHealthDataProvider : HealthDataProvider {

    override val providerId: String = "mock_health_connect_fitcloudpro"
    override val providerDisplayName: String = "Health Connect (Mocked Contract)"

    private val _sourceStatus = MutableStateFlow(
        HealthSourceStatus(
            providerName = "Health Connect",
            providerStatus = "Mock Connected",
            upstreamSource = "FitCloudPro",
            wearableDeviceName = "Smartwatch (BLE via FitCloudPro)",
            pipelineSummary = "Smartwatch → FitCloudPro → Health Connect → Android App → Local AI Core",
            lastSyncTime = "Synced 2m ago",
            isReplaceable = true
        )
    )

    // Current availability profile for demonstration and testing of all availability states
    private val _currentProfile = MutableStateFlow(AvailabilityProfile.STANDARD_DEFAULT)

    enum class AvailabilityProfile(val label: String) {
        STANDARD_DEFAULT("Default (Partial SpO2 Missing)"),
        ALL_AVAILABLE("All Available & Synced"),
        STALE_SYNC("Stale Sync Delay"),
        UNSUPPORTED_SENSOR("Unsupported SpO2 Sensor"),
        NOT_SYNCHRONIZED("Pending Health Connect Sync")
    }

    override fun getSourceStatus(): HealthSourceStatus = _sourceStatus.value

    override fun getHealthMetrics(timeRange: HealthTimeRange): List<HealthMetric> {
        return buildMetricsForRangeAndProfile(timeRange, _currentProfile.value)
    }

    override fun getWellnessInsights(timeRange: HealthTimeRange): List<WellnessInsight> {
        return buildInsightsForRangeAndProfile(timeRange, _currentProfile.value)
    }

    override fun observeSourceStatus(): Flow<HealthSourceStatus> = _sourceStatus.asStateFlow()

    override fun observeHealthMetrics(timeRange: HealthTimeRange): Flow<List<HealthMetric>> {
        return _currentProfile.map { profile ->
            buildMetricsForRangeAndProfile(timeRange, profile)
        }
    }

    override fun observeWellnessInsights(timeRange: HealthTimeRange): Flow<List<WellnessInsight>> {
        return _currentProfile.map { profile ->
            buildInsightsForRangeAndProfile(timeRange, profile)
        }
    }

    override suspend fun triggerSync() {
        val now = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date())
        _sourceStatus.value = _sourceStatus.value.copy(
            lastSyncTime = "Synced at $now",
            providerStatus = "Mock Connected"
        )
    }

    fun setAvailabilityProfile(profile: AvailabilityProfile) {
        _currentProfile.value = profile
    }

    fun getAvailabilityProfile(): AvailabilityProfile = _currentProfile.value

    private fun buildMetricsForRangeAndProfile(
        range: HealthTimeRange,
        profile: AvailabilityProfile
    ): List<HealthMetric> {
        return when (profile) {
            AvailabilityProfile.STANDARD_DEFAULT -> buildStandardMetrics(range)
            AvailabilityProfile.ALL_AVAILABLE -> buildAllAvailableMetrics(range)
            AvailabilityProfile.STALE_SYNC -> buildStaleMetrics(range)
            AvailabilityProfile.UNSUPPORTED_SENSOR -> buildUnsupportedSensorMetrics(range)
            AvailabilityProfile.NOT_SYNCHRONIZED -> buildNotSynchronizedMetrics(range)
        }
    }

    /**
     * Standard scenario:
     * - Heart Rate: Available
     * - Sleep: Available
     * - Steps: Available
     * - Activity: Available
     * - Blood Oxygen: UNAVAILABLE ("No SpO2 data available" - zero fake numbers!)
     */
    private fun buildStandardMetrics(range: HealthTimeRange): List<HealthMetric> {
        return when (range) {
            HealthTimeRange.TODAY -> listOf(
                HealthMetric(
                    type = HealthMetricType.HEART_RATE,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "71",
                    unit = "BPM",
                    secondaryText = "Resting: 62 BPM • Peak: 118 BPM",
                    lastRecordedText = "5m ago",
                    progressRatio = 0.65f
                ),
                HealthMetric(
                    type = HealthMetricType.SLEEP,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "7h 42m",
                    unit = "",
                    secondaryText = "Deep: 2h 10m • REM: 1h 45m • Light: 3h 47m",
                    lastRecordedText = "Today 6:45 AM",
                    progressRatio = 0.88f
                ),
                HealthMetric(
                    type = HealthMetricType.STEPS,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "8,420",
                    unit = "steps",
                    secondaryText = "Goal: 10,000 steps • 5.8 km",
                    targetGoal = "10,000 steps",
                    lastRecordedText = "Live sync",
                    progressRatio = 0.842f
                ),
                HealthMetric(
                    type = HealthMetricType.ACTIVITY,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "48",
                    unit = "active min",
                    secondaryText = "Calorie burn: 412 kcal • 2 brisk walks",
                    targetGoal = "30 active min",
                    lastRecordedText = "12m ago",
                    progressRatio = 1.0f
                ),
                HealthMetric(
                    type = HealthMetricType.BLOOD_OXYGEN,
                    availability = HealthDataAvailability.UNAVAILABLE,
                    value = null, // CRITICAL: NEVER display fake 0%
                    unit = null,
                    secondaryText = null,
                    unavailableMessage = "No SpO2 data available",
                    lastRecordedText = "No records today"
                )
            )

            HealthTimeRange.WEEK -> listOf(
                HealthMetric(
                    type = HealthMetricType.HEART_RATE,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "68",
                    unit = "BPM avg",
                    secondaryText = "Avg resting: 61 BPM • Weekly range: 58-132 BPM",
                    lastRecordedText = "7-day trend",
                    progressRatio = 0.60f
                ),
                HealthMetric(
                    type = HealthMetricType.SLEEP,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "7h 18m",
                    unit = "daily avg",
                    secondaryText = "Target 8h • Consistency score: 84%",
                    lastRecordedText = "7-day average",
                    progressRatio = 0.82f
                ),
                HealthMetric(
                    type = HealthMetricType.STEPS,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "58,940",
                    unit = "total steps",
                    secondaryText = "Daily average: 8,420 steps • 40.5 km total",
                    targetGoal = "70,000 weekly",
                    lastRecordedText = "7-day total",
                    progressRatio = 0.84f
                ),
                HealthMetric(
                    type = HealthMetricType.ACTIVITY,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "312",
                    unit = "active min",
                    secondaryText = "4 outdoor workouts • 2,680 total active kcal",
                    targetGoal = "210 weekly min",
                    lastRecordedText = "7-day total",
                    progressRatio = 1.0f
                ),
                HealthMetric(
                    type = HealthMetricType.BLOOD_OXYGEN,
                    availability = HealthDataAvailability.UNAVAILABLE,
                    value = null,
                    unit = null,
                    unavailableMessage = "No SpO2 data available for this week",
                    lastRecordedText = "Awaiting wearable sync"
                )
            )

            HealthTimeRange.MONTH -> listOf(
                HealthMetric(
                    type = HealthMetricType.HEART_RATE,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "69",
                    unit = "BPM avg",
                    secondaryText = "Resting baseline steady at 60-64 BPM",
                    lastRecordedText = "30-day baseline",
                    progressRatio = 0.62f
                ),
                HealthMetric(
                    type = HealthMetricType.SLEEP,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "7h 26m",
                    unit = "daily avg",
                    secondaryText = "Total recorded nights: 28 of 30",
                    lastRecordedText = "30-day average",
                    progressRatio = 0.85f
                ),
                HealthMetric(
                    type = HealthMetricType.STEPS,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "264,120",
                    unit = "total steps",
                    secondaryText = "Daily avg: 8,804 steps • Goal achieved 22 days",
                    targetGoal = "300,000 monthly",
                    lastRecordedText = "30-day total",
                    progressRatio = 0.88f
                ),
                HealthMetric(
                    type = HealthMetricType.ACTIVITY,
                    availability = HealthDataAvailability.AVAILABLE,
                    value = "1,410",
                    unit = "active min",
                    secondaryText = "Exceeded monthly movement recommendation",
                    targetGoal = "900 monthly min",
                    lastRecordedText = "30-day total",
                    progressRatio = 1.0f
                ),
                HealthMetric(
                    type = HealthMetricType.BLOOD_OXYGEN,
                    availability = HealthDataAvailability.UNAVAILABLE,
                    value = null,
                    unit = null,
                    unavailableMessage = "No SpO2 data available for this month",
                    lastRecordedText = "No historical logs"
                )
            )
        }
    }

    private fun buildAllAvailableMetrics(range: HealthTimeRange): List<HealthMetric> {
        return listOf(
            HealthMetric(
                type = HealthMetricType.HEART_RATE,
                availability = HealthDataAvailability.AVAILABLE,
                value = "72",
                unit = "BPM",
                secondaryText = "Resting: 63 BPM • Peak: 114 BPM",
                lastRecordedText = "Just now",
                progressRatio = 0.67f
            ),
            HealthMetric(
                type = HealthMetricType.SLEEP,
                availability = HealthDataAvailability.AVAILABLE,
                value = "8h 05m",
                unit = "",
                secondaryText = "Deep: 2h 25m • REM: 2h 00m",
                lastRecordedText = "Today 7:00 AM",
                progressRatio = 0.95f
            ),
            HealthMetric(
                type = HealthMetricType.STEPS,
                availability = HealthDataAvailability.AVAILABLE,
                value = "10,140",
                unit = "steps",
                secondaryText = "Goal accomplished • 7.1 km",
                targetGoal = "10,000 steps",
                lastRecordedText = "Live sync",
                progressRatio = 1.0f
            ),
            HealthMetric(
                type = HealthMetricType.ACTIVITY,
                availability = HealthDataAvailability.AVAILABLE,
                value = "55",
                unit = "active min",
                secondaryText = "Calorie burn: 480 kcal",
                targetGoal = "30 active min",
                lastRecordedText = "15m ago",
                progressRatio = 1.0f
            ),
            HealthMetric(
                type = HealthMetricType.BLOOD_OXYGEN,
                availability = HealthDataAvailability.AVAILABLE,
                value = "98",
                unit = "%",
                secondaryText = "Normal range: 95-100% • Captured during rest",
                lastRecordedText = "30m ago",
                progressRatio = 0.98f
            )
        )
    }

    private fun buildStaleMetrics(range: HealthTimeRange): List<HealthMetric> {
        return listOf(
            HealthMetric(
                type = HealthMetricType.HEART_RATE,
                availability = HealthDataAvailability.STALE,
                value = "68",
                unit = "BPM",
                secondaryText = "Stale (sync delayed 14 hours)",
                unavailableMessage = "Last captured 14h ago • Sync delayed",
                lastRecordedText = "Yesterday 7:30 PM",
                progressRatio = 0.60f
            ),
            HealthMetric(
                type = HealthMetricType.SLEEP,
                availability = HealthDataAvailability.STALE,
                value = "6h 50m",
                unit = "",
                secondaryText = "Stale (sync delayed 2 days)",
                unavailableMessage = "Last sync 2 days ago",
                lastRecordedText = "2 days ago",
                progressRatio = 0.75f
            ),
            HealthMetric(
                type = HealthMetricType.STEPS,
                availability = HealthDataAvailability.STALE,
                value = "3,200",
                unit = "steps",
                secondaryText = "Stale step cache from earlier today",
                unavailableMessage = "Wearable link paused",
                lastRecordedText = "Synced 8h ago",
                progressRatio = 0.32f
            ),
            HealthMetric(
                type = HealthMetricType.ACTIVITY,
                availability = HealthDataAvailability.STALE,
                value = "15",
                unit = "active min",
                secondaryText = "Stale session data",
                unavailableMessage = "Last refreshed yesterday",
                lastRecordedText = "Yesterday",
                progressRatio = 0.50f
            ),
            HealthMetric(
                type = HealthMetricType.BLOOD_OXYGEN,
                availability = HealthDataAvailability.UNAVAILABLE,
                value = null,
                unit = null,
                unavailableMessage = "No SpO2 data available",
                lastRecordedText = "No records"
            )
        )
    }

    private fun buildUnsupportedSensorMetrics(range: HealthTimeRange): List<HealthMetric> {
        return listOf(
            HealthMetric(
                type = HealthMetricType.HEART_RATE,
                availability = HealthDataAvailability.AVAILABLE,
                value = "70",
                unit = "BPM",
                secondaryText = "Optical PPG Sensor Active",
                lastRecordedText = "5m ago",
                progressRatio = 0.65f
            ),
            HealthMetric(
                type = HealthMetricType.SLEEP,
                availability = HealthDataAvailability.AVAILABLE,
                value = "7h 30m",
                unit = "",
                secondaryText = "Accelerometer Sleep Analysis",
                lastRecordedText = "Today 7:15 AM",
                progressRatio = 0.85f
            ),
            HealthMetric(
                type = HealthMetricType.STEPS,
                availability = HealthDataAvailability.AVAILABLE,
                value = "8,100",
                unit = "steps",
                secondaryText = "Hardware Pedometer Active",
                lastRecordedText = "Live sync",
                progressRatio = 0.81f
            ),
            HealthMetric(
                type = HealthMetricType.ACTIVITY,
                availability = HealthDataAvailability.AVAILABLE,
                value = "40",
                unit = "active min",
                secondaryText = "Active motion detected",
                lastRecordedText = "10m ago",
                progressRatio = 0.90f
            ),
            HealthMetric(
                type = HealthMetricType.BLOOD_OXYGEN,
                availability = HealthDataAvailability.UNSUPPORTED,
                value = null, // NEVER display 0%
                unit = null,
                unavailableMessage = "Sensor not supported by current wearable model",
                lastRecordedText = "Hardware unsupported"
            )
        )
    }

    private fun buildNotSynchronizedMetrics(range: HealthTimeRange): List<HealthMetric> {
        return listOf(
            HealthMetric(
                type = HealthMetricType.HEART_RATE,
                availability = HealthDataAvailability.NOT_SYNCHRONIZED,
                value = null,
                unit = null,
                unavailableMessage = "Awaiting sync from Health Connect",
                lastRecordedText = "Pending pipeline handshake"
            ),
            HealthMetric(
                type = HealthMetricType.SLEEP,
                availability = HealthDataAvailability.NOT_SYNCHRONIZED,
                value = null,
                unit = null,
                unavailableMessage = "Awaiting sync from Health Connect",
                lastRecordedText = "Pending pipeline handshake"
            ),
            HealthMetric(
                type = HealthMetricType.STEPS,
                availability = HealthDataAvailability.NOT_SYNCHRONIZED,
                value = null,
                unit = null,
                unavailableMessage = "Awaiting sync from Health Connect",
                lastRecordedText = "Pending pipeline handshake"
            ),
            HealthMetric(
                type = HealthMetricType.ACTIVITY,
                availability = HealthDataAvailability.NOT_SYNCHRONIZED,
                value = null,
                unit = null,
                unavailableMessage = "Awaiting sync from Health Connect",
                lastRecordedText = "Pending pipeline handshake"
            ),
            HealthMetric(
                type = HealthMetricType.BLOOD_OXYGEN,
                availability = HealthDataAvailability.NOT_SYNCHRONIZED,
                value = null,
                unit = null,
                unavailableMessage = "Awaiting sync from Health Connect",
                lastRecordedText = "Pending pipeline handshake"
            )
        )
    }

    private fun buildInsightsForRangeAndProfile(
        range: HealthTimeRange,
        profile: AvailabilityProfile
    ): List<WellnessInsight> {
        // NON-DIAGNOSTIC WORDING per user instructions:
        // "Your recent sleep duration has been below your weekly average."
        // "Do not provide medical diagnoses."
        val timeLabel = when (range) {
            HealthTimeRange.TODAY -> "Today"
            HealthTimeRange.WEEK -> "This Week"
            HealthTimeRange.MONTH -> "This Month"
        }

        return listOf(
            WellnessInsight(
                id = "insight_sleep",
                title = "Sleep Duration Observation",
                description = "Your recent sleep duration has been below your weekly average.",
                metricType = HealthMetricType.SLEEP,
                timestamp = timeLabel
            ),
            WellnessInsight(
                id = "insight_steps",
                title = "Step Progression Trend",
                description = "Daily step count has been trending higher over the last 3 days compared to earlier in the week.",
                metricType = HealthMetricType.STEPS,
                timestamp = timeLabel
            ),
            WellnessInsight(
                id = "insight_heart_rate",
                title = "Resting Rate Stability",
                description = "Daytime resting heart rate has remained stable and within your typical recorded boundaries.",
                metricType = HealthMetricType.HEART_RATE,
                timestamp = timeLabel
            ),
            WellnessInsight(
                id = "insight_spo2",
                title = "Sensor Data Note",
                description = "Blood oxygen recordings were not captured during your last sleep interval.",
                metricType = HealthMetricType.BLOOD_OXYGEN,
                timestamp = timeLabel
            )
        )
    }
}
