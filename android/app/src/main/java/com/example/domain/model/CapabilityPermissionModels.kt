package com.example.domain.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Bluetooth
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Mock actions for Android Permission and Capability UX (Batch 13).
 * No real permission APIs are invoked; all interactions provide rich simulated feedback.
 */
enum class MockPermissionAction(val label: String) {
    REVIEW_ACCESS("Review Access"),
    OPEN_SETTINGS("Open Settings"),
    TRY_AGAIN("Try Again")
}

/**
 * Capability explanation following the UX Rule:
 * Never silently fail. Always explain:
 * 1. What is unavailable
 * 2. Why it matters
 * 3. What the user can do
 */
data class CapabilityExplanation(
    val whatIsUnavailable: String,
    val whyItMatters: String,
    val whatUserCanDo: String,
    val availableActions: List<MockPermissionAction> = listOf(
        MockPermissionAction.REVIEW_ACCESS,
        MockPermissionAction.OPEN_SETTINGS,
        MockPermissionAction.TRY_AGAIN
    ),
    val severity: StatusSeverity = StatusSeverity.Warning
)

// ==========================================
// 1. MICROPHONE CAPABILITY
// ==========================================
enum class MicrophoneCapabilityState(
    val displayName: String,
    val isFunctional: Boolean
) {
    AVAILABLE("Available", true),
    PERMISSION_NEEDED("Permission Needed", false),
    DENIED("Denied", false),
    UNAVAILABLE("Unavailable", false);

    val explanation: CapabilityExplanation
        get() = when (this) {
            AVAILABLE -> CapabilityExplanation(
                whatIsUnavailable = "Nothing is restricted. Microphone input is active.",
                whyItMatters = "Voice Mode can stream real-time conversational audio to Local AI Core.",
                whatUserCanDo = "Speak normally during Voice Mode sessions.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS),
                severity = StatusSeverity.Success
            )
            PERMISSION_NEEDED -> CapabilityExplanation(
                whatIsUnavailable = "Microphone recording permission (RECORD_AUDIO) not yet granted.",
                whyItMatters = "Aura cannot capture your speech or transcribe voice prompts in real time.",
                whatUserCanDo = "Tap 'Review Access' or 'Try Again' to approve microphone recording.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS, MockPermissionAction.TRY_AGAIN),
                severity = StatusSeverity.Warning
            )
            DENIED -> CapabilityExplanation(
                whatIsUnavailable = "Microphone access is permanently denied in Android permission manager.",
                whyItMatters = "Android security blocks all background and foreground audio capture until authorized.",
                whatUserCanDo = "Tap 'Open Settings', navigate to Permissions, and select 'Allow while using the app'.",
                availableActions = listOf(MockPermissionAction.OPEN_SETTINGS, MockPermissionAction.TRY_AGAIN),
                severity = StatusSeverity.Error
            )
            UNAVAILABLE -> CapabilityExplanation(
                whatIsUnavailable = "No microphone hardware detected, or input is exclusively locked by another app.",
                whyItMatters = "Voice Mode cannot initialize an audio input stream without operational hardware.",
                whatUserCanDo = "Disconnect conflicting audio peripherals, restart the device, or use text chat.",
                availableActions = listOf(MockPermissionAction.TRY_AGAIN, MockPermissionAction.OPEN_SETTINGS),
                severity = StatusSeverity.Error
            )
        }
}

// ==========================================
// 2. NOTIFICATIONS CAPABILITY
// ==========================================
enum class NotificationCapabilityState(
    val displayName: String,
    val isFunctional: Boolean
) {
    ENABLED("Enabled", true),
    DISABLED("Disabled", false),
    PERMISSION_NEEDED("Permission Needed", false);

    val explanation: CapabilityExplanation
        get() = when (this) {
            ENABLED -> CapabilityExplanation(
                whatIsUnavailable = "Nothing is restricted. Notifications are fully armed.",
                whyItMatters = "Time-sensitive reminders, countdown alarms, and PC disconnect alerts arrive instantly.",
                whatUserCanDo = "Manage notification channels in Android settings if desired.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS),
                severity = StatusSeverity.Success
            )
            DISABLED -> CapabilityExplanation(
                whatIsUnavailable = "App notifications have been silenced in Android system settings.",
                whyItMatters = "Task reminders, timer completions, and background sync alerts won't appear on your lock screen.",
                whatUserCanDo = "Tap 'Open Settings' and enable notifications for this app.",
                availableActions = listOf(MockPermissionAction.OPEN_SETTINGS, MockPermissionAction.REVIEW_ACCESS),
                severity = StatusSeverity.Warning
            )
            PERMISSION_NEEDED -> CapabilityExplanation(
                whatIsUnavailable = "Android 13+ runtime notification permission (POST_NOTIFICATIONS) is not granted.",
                whyItMatters = "The app cannot post heads-up alerts or background synchronization notices.",
                whatUserCanDo = "Tap 'Review Access' to allow notification alerts.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS, MockPermissionAction.TRY_AGAIN),
                severity = StatusSeverity.Warning
            )
        }
}

// ==========================================
// 3. HEALTH CONNECT CAPABILITY
// ==========================================
enum class HealthConnectCapabilityState(
    val displayName: String,
    val isFunctional: Boolean
) {
    AVAILABLE("Available", true),
    ACCESS_GRANTED("Access Granted", true),
    PARTIAL_ACCESS("Partial Access", true),
    ACCESS_REQUIRED("Access Required", false),
    UNAVAILABLE("Unavailable", false);

    val explanation: CapabilityExplanation
        get() = when (this) {
            AVAILABLE -> CapabilityExplanation(
                whatIsUnavailable = "Health Connect framework is installed but pairing is pending.",
                whyItMatters = "Allows biometric and wellness telemetry to sync securely to Local AI Core.",
                whatUserCanDo = "Tap 'Review Access' to grant data permissions for desired health metrics.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS),
                severity = StatusSeverity.Info
            )
            ACCESS_GRANTED -> CapabilityExplanation(
                whatIsUnavailable = "Nothing restricted. Complete read access granted for all health metrics.",
                whyItMatters = "Heart rate, steps, sleep stages, and activity history sync smoothly with zero external cloud leak.",
                whatUserCanDo = "View your live daily wellness metrics on the Health tab.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS),
                severity = StatusSeverity.Success
            )
            PARTIAL_ACCESS -> CapabilityExplanation(
                whatIsUnavailable = "Sleep and SpO2 access restricted (only Steps and Heart Rate granted).",
                whyItMatters = "Sleep recovery scores and overnight oxygen metrics will remain empty on daily cards.",
                whatUserCanDo = "Tap 'Review Access' or 'Open Settings' to authorize the missing sleep categories.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS, MockPermissionAction.OPEN_SETTINGS),
                severity = StatusSeverity.Warning
            )
            ACCESS_REQUIRED -> CapabilityExplanation(
                whatIsUnavailable = "All Health Connect data access is currently blocked.",
                whyItMatters = "The Health tab cannot display any fitness or recovery data without authorization.",
                whatUserCanDo = "Tap 'Review Access' to approve health record sharing.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS, MockPermissionAction.TRY_AGAIN),
                severity = StatusSeverity.Warning
            )
            UNAVAILABLE -> CapabilityExplanation(
                whatIsUnavailable = "Health Connect system provider is not installed on this Android version.",
                whyItMatters = "Without Health Connect, on-device health aggregation is not supported by Android OS.",
                whatUserCanDo = "Install Health Connect from Google Play or update to Android 14+.",
                availableActions = listOf(MockPermissionAction.OPEN_SETTINGS, MockPermissionAction.TRY_AGAIN),
                severity = StatusSeverity.Error
            )
        }
}

// ==========================================
// 4. ALARMS CAPABILITY
// ==========================================
enum class AlarmCapabilityState(
    val displayName: String,
    val isFunctional: Boolean
) {
    READY("Ready", true),
    EXACT_ALARM_UNAVAILABLE("Exact Alarm Unavailable", false),
    SETTINGS_ACTION_REQUIRED("Settings Action Required", false);

    val explanation: CapabilityExplanation
        get() = when (this) {
            READY -> CapabilityExplanation(
                whatIsUnavailable = "Nothing is restricted. Exact alarm authorization is armed.",
                whyItMatters = "Alarms trigger at the exact second, even when the device enters deep Doze battery mode.",
                whatUserCanDo = "Your alarms will ring precisely as scheduled.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS),
                severity = StatusSeverity.Success
            )
            EXACT_ALARM_UNAVAILABLE -> CapabilityExplanation(
                whatIsUnavailable = "Exact Alarm scheduling permission (SCHEDULE_EXACT_ALARM) is inactive.",
                whyItMatters = "Android battery management will batch alarms, causing unpredictable delays of 10 to 30 minutes.",
                whatUserCanDo = "Tap 'Open Settings' to grant 'Alarms & Reminders' special access.",
                availableActions = listOf(MockPermissionAction.OPEN_SETTINGS, MockPermissionAction.REVIEW_ACCESS),
                severity = StatusSeverity.Warning
            )
            SETTINGS_ACTION_REQUIRED -> CapabilityExplanation(
                whatIsUnavailable = "Special app access 'Alarms & Reminders' requires manual user switch in Android Settings.",
                whyItMatters = "Android 12+ strictly prohibits background precise scheduling until toggled by the user.",
                whatUserCanDo = "Tap 'Open Settings' and enable the toggle for this app under Alarms & Reminders.",
                availableActions = listOf(MockPermissionAction.OPEN_SETTINGS, MockPermissionAction.TRY_AGAIN),
                severity = StatusSeverity.Error
            )
        }
}

// ==========================================
// 5. BLUETOOTH / AUDIO CAPABILITY
// ==========================================
enum class BluetoothAudioCapabilityState(
    val displayName: String,
    val isFunctional: Boolean
) {
    NOT_REQUIRED("Not Required", true),
    READY("Connected & Ready", true),
    PERMISSION_NEEDED("Permission Needed", false),
    UNAVAILABLE("Unavailable", false);

    val explanation: CapabilityExplanation
        get() = when (this) {
            NOT_REQUIRED -> CapabilityExplanation(
                whatIsUnavailable = "No Bluetooth features requested.",
                whyItMatters = "Standard on-device audio, speakers, and wired mics operate without Bluetooth permission.",
                whatUserCanDo = "Only enable Bluetooth if pairing low-latency wireless wearable microphones.",
                availableActions = emptyList(),
                severity = StatusSeverity.Normal
            )
            READY -> CapabilityExplanation(
                whatIsUnavailable = "Nothing is restricted. Low-latency BLE audio peripheral paired.",
                whyItMatters = "Wearable wireless microphone input streams directly to Voice Mode.",
                whatUserCanDo = "Use your Bluetooth wireless mic seamlessly.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS),
                severity = StatusSeverity.Success
            )
            PERMISSION_NEEDED -> CapabilityExplanation(
                whatIsUnavailable = "Android Nearby Devices permission (BLUETOOTH_CONNECT) is not approved.",
                whyItMatters = "The app cannot scan for or bind to your wireless audio headset.",
                whatUserCanDo = "Tap 'Review Access' or 'Try Again' to grant Nearby Devices permission.",
                availableActions = listOf(MockPermissionAction.REVIEW_ACCESS, MockPermissionAction.TRY_AGAIN),
                severity = StatusSeverity.Warning
            )
            UNAVAILABLE -> CapabilityExplanation(
                whatIsUnavailable = "Bluetooth adapter is powered off or not supported on this device.",
                whyItMatters = "Wireless peripheral streaming cannot establish a radio link.",
                whatUserCanDo = "Turn on Bluetooth in Android Quick Settings or reconnect audio cable.",
                availableActions = listOf(MockPermissionAction.OPEN_SETTINGS, MockPermissionAction.TRY_AGAIN),
                severity = StatusSeverity.Error
            )
        }
}

/**
 * Composite container of all permission capability states.
 */
data class CapabilitiesState(
    val microphoneState: MicrophoneCapabilityState = MicrophoneCapabilityState.AVAILABLE,
    val notificationState: NotificationCapabilityState = NotificationCapabilityState.ENABLED,
    val healthConnectState: HealthConnectCapabilityState = HealthConnectCapabilityState.ACCESS_GRANTED,
    val alarmCapabilityState: AlarmCapabilityState = AlarmCapabilityState.READY,
    val isBluetoothAudioRequired: Boolean = false,
    val bluetoothAudioState: BluetoothAudioCapabilityState = BluetoothAudioCapabilityState.NOT_REQUIRED,
    val lastMockActionResult: String? = null
) {
    val anyIssues: Boolean
        get() = !microphoneState.isFunctional ||
                !notificationState.isFunctional ||
                (healthConnectState != HealthConnectCapabilityState.ACCESS_GRANTED && healthConnectState != HealthConnectCapabilityState.AVAILABLE) ||
                !alarmCapabilityState.isFunctional ||
                (isBluetoothAudioRequired && !bluetoothAudioState.isFunctional)

    val issueCount: Int
        get() {
            var count = 0
            if (!microphoneState.isFunctional) count++
            if (!notificationState.isFunctional) count++
            if (healthConnectState == HealthConnectCapabilityState.ACCESS_REQUIRED || healthConnectState == HealthConnectCapabilityState.UNAVAILABLE || healthConnectState == HealthConnectCapabilityState.PARTIAL_ACCESS) count++
            if (!alarmCapabilityState.isFunctional) count++
            if (isBluetoothAudioRequired && !bluetoothAudioState.isFunctional) count++
            return count
        }
}

/**
 * Capability Type enumeration for targeting actions.
 */
enum class CapabilityType(val title: String, val icon: ImageVector) {
    MICROPHONE("Microphone", Icons.Default.Mic),
    NOTIFICATIONS("Notifications", Icons.Default.Notifications),
    HEALTH_CONNECT("Health Connect", Icons.Default.Favorite),
    ALARMS("Alarms & Scheduling", Icons.Default.Alarm),
    BLUETOOTH_AUDIO("Bluetooth / Wireless Audio", Icons.Default.Bluetooth)
}
