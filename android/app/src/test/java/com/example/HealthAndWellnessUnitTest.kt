package com.example

import com.example.data.health.MockHealthDataProvider
import com.example.domain.model.HealthDataAvailability
import com.example.domain.model.HealthMetricType
import com.example.domain.model.HealthTimeRange
import com.example.ui.screens.health.HealthViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for Batch 7: Mobile Health and Wellness.
 * Verifies:
 * - Replaceable provider architecture
 * - Source status display: "Health Connect: Mock Connected", "Source: FitCloudPro"
 * - Time range support: Today, Week, Month
 * - Metrics support: heart rate, sleep, steps, activity, blood oxygen
 * - Data availability states: available, unavailable, stale, unsupported, not synchronized
 * - CRITICAL: Never display fake zero values for unavailable health data (e.g. "No SpO2 data available" instead of "SpO2: 0%")
 * - Wellness insights: strictly non-diagnostic wording
 */
@OptIn(ExperimentalCoroutinesApi::class)
class HealthAndWellnessUnitTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `source status displays Health Connect Mock Connected and Source FitCloudPro`() = runTest {
        val dataProvider = MockHealthDataProvider()
        val viewModel = HealthViewModel(dataProvider)
        advanceUntilIdle()

        val sourceStatus = viewModel.uiState.value.sourceStatus
        assertEquals("Health Connect", sourceStatus.providerName)
        assertEquals("Mock Connected", sourceStatus.providerStatus)
        assertEquals("FitCloudPro", sourceStatus.upstreamSource)
        assertTrue("Provider architecture must be marked replaceable", sourceStatus.isReplaceable)
        assertTrue(
            "Pipeline summary must document ingestion flow",
            sourceStatus.pipelineSummary.contains("Smartwatch → FitCloudPro → Health Connect → Android App → Local AI Core")
        )
    }

    @Test
    fun `time range selector supports Today, Week, and Month`() = runTest {
        val dataProvider = MockHealthDataProvider()
        val viewModel = HealthViewModel(dataProvider)
        advanceUntilIdle()

        assertEquals(HealthTimeRange.TODAY, viewModel.uiState.value.selectedTimeRange)

        // Switch to Week
        viewModel.selectTimeRange(HealthTimeRange.WEEK)
        advanceUntilIdle()
        assertEquals(HealthTimeRange.WEEK, viewModel.uiState.value.selectedTimeRange)

        // Switch to Month
        viewModel.selectTimeRange(HealthTimeRange.MONTH)
        advanceUntilIdle()
        assertEquals(HealthTimeRange.MONTH, viewModel.uiState.value.selectedTimeRange)
    }

    @Test
    fun `metrics support heart rate, sleep, steps, activity, and blood oxygen`() = runTest {
        val dataProvider = MockHealthDataProvider()
        val viewModel = HealthViewModel(dataProvider)
        advanceUntilIdle()

        val metrics = viewModel.uiState.value.metrics
        val supportedTypes = metrics.map { it.type }.toSet()

        assertTrue(supportedTypes.contains(HealthMetricType.HEART_RATE))
        assertTrue(supportedTypes.contains(HealthMetricType.SLEEP))
        assertTrue(supportedTypes.contains(HealthMetricType.STEPS))
        assertTrue(supportedTypes.contains(HealthMetricType.ACTIVITY))
        assertTrue(supportedTypes.contains(HealthMetricType.BLOOD_OXYGEN))
    }

    @Test
    fun `unavailable blood oxygen never displays fake zero value`() = runTest {
        val dataProvider = MockHealthDataProvider()
        val viewModel = HealthViewModel(dataProvider)
        advanceUntilIdle()

        val spo2 = viewModel.uiState.value.metrics.first { it.type == HealthMetricType.BLOOD_OXYGEN }

        // Must be UNAVAILABLE in standard profile
        assertEquals(HealthDataAvailability.UNAVAILABLE, spo2.availability)

        // MANDATORY RULE: Never display fake zero values (e.g. "0%", "0 BPM")
        assertNull("Unavailable SpO2 value MUST be null, not 0%", spo2.value)
        assertNull("Unavailable SpO2 unit MUST be null, not %", spo2.unit)
        assertNotNull(spo2.unavailableMessage)
        assertEquals("No SpO2 data available", spo2.unavailableMessage)
        assertFalse(
            "Message must never contain fake zero value",
            spo2.unavailableMessage.orEmpty().contains("0%")
        )
    }

    @Test
    fun `all 5 data availability states are supported and formatted appropriately`() = runTest {
        val dataProvider = MockHealthDataProvider()
        val viewModel = HealthViewModel(dataProvider)
        advanceUntilIdle()

        // 1. AVAILABLE & UNAVAILABLE (in default profile)
        val defaultMetrics = viewModel.uiState.value.metrics
        assertTrue(defaultMetrics.any { it.availability == HealthDataAvailability.AVAILABLE })
        assertTrue(defaultMetrics.any { it.availability == HealthDataAvailability.UNAVAILABLE })

        // 2. STALE
        viewModel.selectAvailabilityProfile(MockHealthDataProvider.AvailabilityProfile.STALE_SYNC)
        advanceUntilIdle()
        val staleMetrics = viewModel.uiState.value.metrics
        assertTrue(staleMetrics.any { it.availability == HealthDataAvailability.STALE })
        val staleItem = staleMetrics.first { it.availability == HealthDataAvailability.STALE }
        assertNotNull(staleItem.value) // Stale preserves last known reading
        assertTrue(staleItem.secondaryText?.contains("Stale") == true)

        // 3. UNSUPPORTED
        viewModel.selectAvailabilityProfile(MockHealthDataProvider.AvailabilityProfile.UNSUPPORTED_SENSOR)
        advanceUntilIdle()
        val unsupportedMetrics = viewModel.uiState.value.metrics
        val unsupportedItem = unsupportedMetrics.first { it.type == HealthMetricType.BLOOD_OXYGEN }
        assertEquals(HealthDataAvailability.UNSUPPORTED, unsupportedItem.availability)
        assertNull("Unsupported sensor MUST NOT display 0%", unsupportedItem.value)
        assertEquals("Sensor not supported by current wearable model", unsupportedItem.unavailableMessage)

        // 4. NOT_SYNCHRONIZED
        viewModel.selectAvailabilityProfile(MockHealthDataProvider.AvailabilityProfile.NOT_SYNCHRONIZED)
        advanceUntilIdle()
        val notSyncedMetrics = viewModel.uiState.value.metrics
        assertTrue(notSyncedMetrics.all { it.availability == HealthDataAvailability.NOT_SYNCHRONIZED })
        assertTrue(notSyncedMetrics.all { it.value == null }) // No fake zeros
        assertTrue(notSyncedMetrics.all { it.unavailableMessage == "Awaiting sync from Health Connect" })
    }

    @Test
    fun `wellness insights strictly use non-diagnostic wording`() = runTest {
        val dataProvider = MockHealthDataProvider()
        val viewModel = HealthViewModel(dataProvider)
        advanceUntilIdle()

        val insights = viewModel.uiState.value.wellnessInsights
        assertTrue("Must provide wellness insights", insights.isNotEmpty())

        val sleepInsight = insights.first { it.metricType == HealthMetricType.SLEEP }
        assertEquals(
            "Your recent sleep duration has been below your weekly average.",
            sleepInsight.description
        )

        // Non-diagnostic assertion: ensure absence of diagnostic claims
        val diagnosticTerms = listOf("diagnosis", "disease", "disorder", "syndrome", "prescribe", "pathology")
        for (insight in insights) {
            val lowerDesc = insight.description.lowercase()
            for (term in diagnosticTerms) {
                assertFalse("Insight must not contain diagnostic terminology '$term'", lowerDesc.contains(term))
            }
        }
    }

    @Test
    fun `triggering sync simulates provider handshake and updates status`() = runTest {
        val dataProvider = MockHealthDataProvider()
        val viewModel = HealthViewModel(dataProvider)
        advanceUntilIdle()

        viewModel.triggerSync()
        advanceUntilIdle()

        val status = viewModel.uiState.value.sourceStatus
        assertEquals("Mock Connected", status.providerStatus)
        assertTrue(status.lastSyncTime.contains("Synced at"))
    }
}
