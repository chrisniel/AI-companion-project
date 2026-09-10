package com.example

import com.example.domain.model.AlarmCapabilityState
import com.example.domain.model.BluetoothAudioCapabilityState
import com.example.domain.model.CapabilitiesState
import com.example.domain.model.HealthConnectCapabilityState
import com.example.domain.model.MicrophoneCapabilityState
import com.example.domain.model.MockPermissionAction
import com.example.domain.model.NotificationCapabilityState
import com.example.domain.model.StatusSeverity
import com.example.ui.shell.AppViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for Batch 13: Android Permission and Capability UX.
 *
 * Verifies:
 * 1. All capability states and the UX Rule ("Never silently fail"):
 *    - What is unavailable
 *    - Why it matters
 *    - What the user can do
 * 2. Mock actions: Review Access, Open Settings, Try Again
 * 3. Microphone states (Available, Permission Needed, Denied, Unavailable)
 * 4. Notification states (Enabled, Disabled, Permission Needed)
 * 5. Health Connect states (Available, Access Granted, Partial Access, Access Required, Unavailable)
 * 6. Alarm states (Ready, Exact Alarm Capability Unavailable, Android Settings Action Required)
 * 7. Bluetooth / Audio rule: "Only show permission UX if future functionality requires it.
 *    Do not assume Bluetooth permission is always required."
 * 8. AppViewModel state mutations and reset behavior.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CapabilityAndPermissionUnitTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var viewModel: AppViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        viewModel = AppViewModel()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `default capabilities state has core operational and bluetooth not required`() {
        val defaultState = CapabilitiesState()
        assertEquals(MicrophoneCapabilityState.AVAILABLE, defaultState.microphoneState)
        assertEquals(NotificationCapabilityState.ENABLED, defaultState.notificationState)
        assertEquals(HealthConnectCapabilityState.ACCESS_GRANTED, defaultState.healthConnectState)
        assertEquals(AlarmCapabilityState.READY, defaultState.alarmCapabilityState)
        assertEquals(BluetoothAudioCapabilityState.NOT_REQUIRED, defaultState.bluetoothAudioState)
        assertFalse("Bluetooth should not be required by default", defaultState.isBluetoothAudioRequired)
        assertFalse("No issues should exist by default", defaultState.anyIssues)
        assertEquals(0, defaultState.issueCount)
    }

    @Test
    fun `microphone states verify never silently fail UX rule`() {
        // Check every microphone state has what/why/action populated
        MicrophoneCapabilityState.entries.forEach { state ->
            val explanation = state.explanation
            assertNotNull(explanation.whatIsUnavailable)
            assertNotNull(explanation.whyItMatters)
            assertNotNull(explanation.whatUserCanDo)
            assertTrue("Actions must not be empty", explanation.availableActions.isNotEmpty())
        }

        // Test Denied state specifically requires Open Settings and Try Again
        val deniedExplanation = MicrophoneCapabilityState.DENIED.explanation
        assertEquals(StatusSeverity.Error, deniedExplanation.severity)
        assertTrue(deniedExplanation.availableActions.contains(MockPermissionAction.OPEN_SETTINGS))
        assertTrue(deniedExplanation.availableActions.contains(MockPermissionAction.TRY_AGAIN))

        // Test Permission Needed state offers Review Access
        val neededExplanation = MicrophoneCapabilityState.PERMISSION_NEEDED.explanation
        assertEquals(StatusSeverity.Warning, neededExplanation.severity)
        assertTrue(neededExplanation.availableActions.contains(MockPermissionAction.REVIEW_ACCESS))
    }

    @Test
    fun `notification states verify clear guidance on alerts`() {
        NotificationCapabilityState.entries.forEach { state ->
            val explanation = state.explanation
            assertNotNull(explanation.whatIsUnavailable)
            assertNotNull(explanation.whyItMatters)
            assertNotNull(explanation.whatUserCanDo)
        }

        val disabledExplanation = NotificationCapabilityState.DISABLED.explanation
        assertEquals(StatusSeverity.Warning, disabledExplanation.severity)
        assertTrue(disabledExplanation.availableActions.contains(MockPermissionAction.OPEN_SETTINGS))

        val neededExplanation = NotificationCapabilityState.PERMISSION_NEEDED.explanation
        assertTrue(neededExplanation.availableActions.contains(MockPermissionAction.REVIEW_ACCESS))
    }

    @Test
    fun `health connect states verify partial access and required states`() {
        HealthConnectCapabilityState.entries.forEach { state ->
            val explanation = state.explanation
            assertNotNull(explanation.whatIsUnavailable)
            assertNotNull(explanation.whyItMatters)
            assertNotNull(explanation.whatUserCanDo)
        }

        val partialExplanation = HealthConnectCapabilityState.PARTIAL_ACCESS.explanation
        assertEquals(StatusSeverity.Warning, partialExplanation.severity)
        assertTrue(partialExplanation.availableActions.contains(MockPermissionAction.REVIEW_ACCESS))

        val unavailableExplanation = HealthConnectCapabilityState.UNAVAILABLE.explanation
        assertEquals(StatusSeverity.Error, unavailableExplanation.severity)
        assertTrue(unavailableExplanation.availableActions.contains(MockPermissionAction.TRY_AGAIN))
    }

    @Test
    fun `alarm states address Android exact alarm restrictions without silent failure`() {
        AlarmCapabilityState.entries.forEach { state ->
            val explanation = state.explanation
            assertNotNull(explanation.whatIsUnavailable)
            assertNotNull(explanation.whyItMatters)
            assertNotNull(explanation.whatUserCanDo)
        }

        val exactAlarmUnavailable = AlarmCapabilityState.EXACT_ALARM_UNAVAILABLE.explanation
        assertEquals(StatusSeverity.Warning, exactAlarmUnavailable.severity)
        assertTrue(exactAlarmUnavailable.availableActions.contains(MockPermissionAction.OPEN_SETTINGS))
        assertTrue(exactAlarmUnavailable.availableActions.contains(MockPermissionAction.REVIEW_ACCESS))

        val settingsRequired = AlarmCapabilityState.SETTINGS_ACTION_REQUIRED.explanation
        assertEquals(StatusSeverity.Error, settingsRequired.severity)
        assertTrue(settingsRequired.availableActions.contains(MockPermissionAction.OPEN_SETTINGS))
    }

    @Test
    fun `bluetooth audio permission UX is only shown when required by future functionality`() {
        // Initially, bluetooth is NOT required
        val initialCapabilities = viewModel.uiState.value.capabilitiesState
        assertFalse(initialCapabilities.isBluetoothAudioRequired)
        assertEquals(BluetoothAudioCapabilityState.NOT_REQUIRED, initialCapabilities.bluetoothAudioState)
        assertEquals(StatusSeverity.Normal, initialCapabilities.bluetoothAudioState.explanation.severity)

        // When user enables future bluetooth accessory requirement
        viewModel.setBluetoothAudioRequired(true)
        val requiredCapabilities = viewModel.uiState.value.capabilitiesState
        assertTrue(requiredCapabilities.isBluetoothAudioRequired)
        assertEquals(BluetoothAudioCapabilityState.PERMISSION_NEEDED, requiredCapabilities.bluetoothAudioState)

        // Now change bluetooth state to READY
        viewModel.setBluetoothAudioState(BluetoothAudioCapabilityState.READY)
        assertEquals(BluetoothAudioCapabilityState.READY, viewModel.uiState.value.capabilitiesState.bluetoothAudioState)

        // When disabled again, reverts to NOT_REQUIRED
        viewModel.setBluetoothAudioRequired(false)
        assertFalse(viewModel.uiState.value.capabilitiesState.isBluetoothAudioRequired)
        assertEquals(BluetoothAudioCapabilityState.NOT_REQUIRED, viewModel.uiState.value.capabilitiesState.bluetoothAudioState)
    }

    @Test
    fun `viewModel mutates capability states and computes issue count accurately`() = runTest {
        // Start: 0 issues
        assertEquals(0, viewModel.uiState.value.capabilitiesState.issueCount)
        assertFalse(viewModel.uiState.value.capabilitiesState.anyIssues)

        // Set Microphone to DENIED -> 1 issue
        viewModel.setMicrophoneState(MicrophoneCapabilityState.DENIED)
        assertEquals(1, viewModel.uiState.value.capabilitiesState.issueCount)
        assertTrue(viewModel.uiState.value.capabilitiesState.anyIssues)

        // Set Alarms to EXACT_ALARM_UNAVAILABLE -> 2 issues
        viewModel.setAlarmCapabilityState(AlarmCapabilityState.EXACT_ALARM_UNAVAILABLE)
        assertEquals(2, viewModel.uiState.value.capabilitiesState.issueCount)

        // Set Health Connect to ACCESS_REQUIRED -> 3 issues
        viewModel.setHealthConnectState(HealthConnectCapabilityState.ACCESS_REQUIRED)
        assertEquals(3, viewModel.uiState.value.capabilitiesState.issueCount)

        // Set Notifications to DISABLED -> 4 issues
        viewModel.setNotificationState(NotificationCapabilityState.DISABLED)
        assertEquals(4, viewModel.uiState.value.capabilitiesState.issueCount)

        // Reset to defaults -> 0 issues
        viewModel.resetCapabilitiesToDefaults()
        assertEquals(0, viewModel.uiState.value.capabilitiesState.issueCount)
        assertFalse(viewModel.uiState.value.capabilitiesState.anyIssues)
        assertEquals(MicrophoneCapabilityState.AVAILABLE, viewModel.uiState.value.capabilitiesState.microphoneState)
    }

    @Test
    fun `mock permission actions provide human readable labels`() {
        assertEquals("Review Access", MockPermissionAction.REVIEW_ACCESS.label)
        assertEquals("Open Settings", MockPermissionAction.OPEN_SETTINGS.label)
        assertEquals("Try Again", MockPermissionAction.TRY_AGAIN.label)
    }
}
