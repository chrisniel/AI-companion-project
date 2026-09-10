package com.example.ui.screens.permissions

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.AlarmCapabilityState
import com.example.domain.model.BluetoothAudioCapabilityState
import com.example.domain.model.CapabilitiesState
import com.example.domain.model.CapabilityType
import com.example.domain.model.HealthConnectCapabilityState
import com.example.domain.model.MicrophoneCapabilityState
import com.example.domain.model.MockPermissionAction
import com.example.domain.model.NotificationCapabilityState
import com.example.domain.model.StatusSeverity
import com.example.ui.components.CapabilityHubCard
import com.example.ui.components.MockActionDetailsSheet
import com.example.ui.components.SoftGlassButton
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.StatusBadge
import com.example.ui.theme.SoftTheme

/**
 * Android Permissions & Capabilities Hub (Batch 13).
 *
 * Implements Android-specific permission states without requesting real permissions:
 * - Microphone: Available, Permission Needed, Denied, Unavailable
 * - Notifications: Enabled, Disabled, Permission Needed
 * - Health Connect: Available, Access Granted, Partial Access, Access Required, Unavailable
 * - Alarms: Ready, Exact Alarm Capability Unavailable, Android Settings Action Required
 * - Bluetooth / Audio: Only shows permission UX if functionality requires it (toggleable)
 *
 * Adheres strictly to the UX Rule:
 * Never silently fail. Shows:
 * 1. What is unavailable
 * 2. Why it matters
 * 3. What the user can do
 *
 * Interactive state controls let reviewers switch and verify all states instantly.
 */
@Composable
fun PermissionsScreen(
    capabilitiesState: CapabilitiesState,
    onSetMicrophoneState: (MicrophoneCapabilityState) -> Unit,
    onSetNotificationState: (NotificationCapabilityState) -> Unit,
    onSetHealthConnectState: (HealthConnectCapabilityState) -> Unit,
    onSetAlarmCapabilityState: (AlarmCapabilityState) -> Unit,
    onSetBluetoothAudioRequired: (Boolean) -> Unit,
    onSetBluetoothAudioState: (BluetoothAudioCapabilityState) -> Unit,
    onResetDefaults: () -> Unit,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    var activeSheetAction by remember { mutableStateOf<MockPermissionAction?>(null) }
    var activeSheetCapability by remember { mutableStateOf<CapabilityType?>(null) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(SoftTheme.colors.background)
            .testTag("permissions_screen")
    ) {
        // Top Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            IconButton(
                onClick = onNavigateBack,
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.surfaceElevated)
                    .border(
                        width = SoftTheme.tokens.borders.hairline,
                        color = SoftTheme.colors.borderSubtle,
                        shape = CircleShape
                    )
                    .testTag("permissions_back_button")
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = SoftTheme.colors.textPrimary,
                    modifier = Modifier.size(18.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Permissions & Capabilities",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = "Android System Access & Hardware Governance",
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 11.sp
                )
            }

            // Quick reset to defaults
            IconButton(
                onClick = onResetDefaults,
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.surfaceElevated)
                    .border(
                        width = SoftTheme.tokens.borders.hairline,
                        color = SoftTheme.colors.borderSubtle,
                        shape = CircleShape
                    )
                    .testTag("permissions_reset_button")
            ) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Reset to Defaults",
                    tint = SoftTheme.colors.textSecondary,
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        // Scrollable content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Summary Card
            SystemHealthSummaryCard(
                capabilitiesState = capabilitiesState
            )

            // Section Label
            Text(
                text = "SYSTEM CAPABILITY AUDIT",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.accentBlue,
                fontSize = 10.sp
            )

            // 1. MICROPHONE
            val micOptions = listOf("Available", "Permission Needed", "Denied", "Unavailable")
            val selectedMicIndex = when (capabilitiesState.microphoneState) {
                MicrophoneCapabilityState.AVAILABLE -> 0
                MicrophoneCapabilityState.PERMISSION_NEEDED -> 1
                MicrophoneCapabilityState.DENIED -> 2
                MicrophoneCapabilityState.UNAVAILABLE -> 3
            }
            CapabilityHubCard(
                capabilityType = CapabilityType.MICROPHONE,
                statusText = capabilitiesState.microphoneState.displayName,
                explanation = capabilitiesState.microphoneState.explanation,
                stateOptions = micOptions,
                selectedStateIndex = selectedMicIndex,
                onSelectStateIndex = { index ->
                    when (index) {
                        0 -> onSetMicrophoneState(MicrophoneCapabilityState.AVAILABLE)
                        1 -> onSetMicrophoneState(MicrophoneCapabilityState.PERMISSION_NEEDED)
                        2 -> onSetMicrophoneState(MicrophoneCapabilityState.DENIED)
                        3 -> onSetMicrophoneState(MicrophoneCapabilityState.UNAVAILABLE)
                    }
                },
                onActionClick = { action ->
                    activeSheetAction = action
                    activeSheetCapability = CapabilityType.MICROPHONE
                }
            )

            // 2. NOTIFICATIONS
            val notifOptions = listOf("Enabled", "Disabled", "Permission Needed")
            val selectedNotifIndex = when (capabilitiesState.notificationState) {
                NotificationCapabilityState.ENABLED -> 0
                NotificationCapabilityState.DISABLED -> 1
                NotificationCapabilityState.PERMISSION_NEEDED -> 2
            }
            CapabilityHubCard(
                capabilityType = CapabilityType.NOTIFICATIONS,
                statusText = capabilitiesState.notificationState.displayName,
                explanation = capabilitiesState.notificationState.explanation,
                stateOptions = notifOptions,
                selectedStateIndex = selectedNotifIndex,
                onSelectStateIndex = { index ->
                    when (index) {
                        0 -> onSetNotificationState(NotificationCapabilityState.ENABLED)
                        1 -> onSetNotificationState(NotificationCapabilityState.DISABLED)
                        2 -> onSetNotificationState(NotificationCapabilityState.PERMISSION_NEEDED)
                    }
                },
                onActionClick = { action ->
                    activeSheetAction = action
                    activeSheetCapability = CapabilityType.NOTIFICATIONS
                }
            )

            // 3. HEALTH CONNECT
            val healthOptions = listOf("Available", "Access Granted", "Partial Access", "Access Required", "Unavailable")
            val selectedHealthIndex = when (capabilitiesState.healthConnectState) {
                HealthConnectCapabilityState.AVAILABLE -> 0
                HealthConnectCapabilityState.ACCESS_GRANTED -> 1
                HealthConnectCapabilityState.PARTIAL_ACCESS -> 2
                HealthConnectCapabilityState.ACCESS_REQUIRED -> 3
                HealthConnectCapabilityState.UNAVAILABLE -> 4
            }
            CapabilityHubCard(
                capabilityType = CapabilityType.HEALTH_CONNECT,
                statusText = capabilitiesState.healthConnectState.displayName,
                explanation = capabilitiesState.healthConnectState.explanation,
                stateOptions = healthOptions,
                selectedStateIndex = selectedHealthIndex,
                onSelectStateIndex = { index ->
                    when (index) {
                        0 -> onSetHealthConnectState(HealthConnectCapabilityState.AVAILABLE)
                        1 -> onSetHealthConnectState(HealthConnectCapabilityState.ACCESS_GRANTED)
                        2 -> onSetHealthConnectState(HealthConnectCapabilityState.PARTIAL_ACCESS)
                        3 -> onSetHealthConnectState(HealthConnectCapabilityState.ACCESS_REQUIRED)
                        4 -> onSetHealthConnectState(HealthConnectCapabilityState.UNAVAILABLE)
                    }
                },
                onActionClick = { action ->
                    activeSheetAction = action
                    activeSheetCapability = CapabilityType.HEALTH_CONNECT
                }
            )

            // 4. ALARMS
            val alarmOptions = listOf("Ready", "Exact Alarm Unavailable", "Settings Action Required")
            val selectedAlarmIndex = when (capabilitiesState.alarmCapabilityState) {
                AlarmCapabilityState.READY -> 0
                AlarmCapabilityState.EXACT_ALARM_UNAVAILABLE -> 1
                AlarmCapabilityState.SETTINGS_ACTION_REQUIRED -> 2
            }
            CapabilityHubCard(
                capabilityType = CapabilityType.ALARMS,
                statusText = capabilitiesState.alarmCapabilityState.displayName,
                explanation = capabilitiesState.alarmCapabilityState.explanation,
                stateOptions = alarmOptions,
                selectedStateIndex = selectedAlarmIndex,
                onSelectStateIndex = { index ->
                    when (index) {
                        0 -> onSetAlarmCapabilityState(AlarmCapabilityState.READY)
                        1 -> onSetAlarmCapabilityState(AlarmCapabilityState.EXACT_ALARM_UNAVAILABLE)
                        2 -> onSetAlarmCapabilityState(AlarmCapabilityState.SETTINGS_ACTION_REQUIRED)
                    }
                },
                onActionClick = { action ->
                    activeSheetAction = action
                    activeSheetCapability = CapabilityType.ALARMS
                }
            )

            // 5. BLUETOOTH / AUDIO
            // UX Rule: Only show permission UX if future functionality requires it.
            // Do not assume Bluetooth permission is always required.
            val btOptions = listOf("Not Required", "Connected & Ready", "Permission Needed", "Unavailable")
            val selectedBtIndex = when (capabilitiesState.bluetoothAudioState) {
                BluetoothAudioCapabilityState.NOT_REQUIRED -> 0
                BluetoothAudioCapabilityState.READY -> 1
                BluetoothAudioCapabilityState.PERMISSION_NEEDED -> 2
                BluetoothAudioCapabilityState.UNAVAILABLE -> 3
            }
            CapabilityHubCard(
                capabilityType = CapabilityType.BLUETOOTH_AUDIO,
                statusText = if (!capabilitiesState.isBluetoothAudioRequired) "Standard Audio (No BT Needed)" else capabilitiesState.bluetoothAudioState.displayName,
                explanation = if (!capabilitiesState.isBluetoothAudioRequired) BluetoothAudioCapabilityState.NOT_REQUIRED.explanation else capabilitiesState.bluetoothAudioState.explanation,
                stateOptions = if (capabilitiesState.isBluetoothAudioRequired) btOptions else listOf("Not Required (Toggle Above)"),
                selectedStateIndex = if (capabilitiesState.isBluetoothAudioRequired) selectedBtIndex else 0,
                onSelectStateIndex = { index ->
                    if (capabilitiesState.isBluetoothAudioRequired) {
                        when (index) {
                            0 -> onSetBluetoothAudioState(BluetoothAudioCapabilityState.NOT_REQUIRED)
                            1 -> onSetBluetoothAudioState(BluetoothAudioCapabilityState.READY)
                            2 -> onSetBluetoothAudioState(BluetoothAudioCapabilityState.PERMISSION_NEEDED)
                            3 -> onSetBluetoothAudioState(BluetoothAudioCapabilityState.UNAVAILABLE)
                        }
                    }
                },
                isOptionalEnabled = capabilitiesState.isBluetoothAudioRequired,
                onToggleOptional = { enabled ->
                    onSetBluetoothAudioRequired(enabled)
                    if (enabled && capabilitiesState.bluetoothAudioState == BluetoothAudioCapabilityState.NOT_REQUIRED) {
                        onSetBluetoothAudioState(BluetoothAudioCapabilityState.PERMISSION_NEEDED)
                    } else if (!enabled) {
                        onSetBluetoothAudioState(BluetoothAudioCapabilityState.NOT_REQUIRED)
                    }
                },
                onActionClick = { action ->
                    activeSheetAction = action
                    activeSheetCapability = CapabilityType.BLUETOOTH_AUDIO
                }
            )

            Spacer(modifier = Modifier.height(24.dp))
        }
    }

    // Interactive Action Details Bottom Sheet
    MockActionDetailsSheet(
        isOpen = activeSheetAction != null && activeSheetCapability != null,
        action = activeSheetAction,
        capabilityType = activeSheetCapability,
        onDismiss = {
            activeSheetAction = null
            activeSheetCapability = null
        },
        onSimulateGrant = {
            when (activeSheetCapability) {
                CapabilityType.MICROPHONE -> onSetMicrophoneState(MicrophoneCapabilityState.AVAILABLE)
                CapabilityType.NOTIFICATIONS -> onSetNotificationState(NotificationCapabilityState.ENABLED)
                CapabilityType.HEALTH_CONNECT -> onSetHealthConnectState(HealthConnectCapabilityState.ACCESS_GRANTED)
                CapabilityType.ALARMS -> onSetAlarmCapabilityState(AlarmCapabilityState.READY)
                CapabilityType.BLUETOOTH_AUDIO -> onSetBluetoothAudioState(BluetoothAudioCapabilityState.READY)
                null -> {}
            }
        }
    )
}

/**
 * Top system health summary banner.
 */
@Composable
private fun SystemHealthSummaryCard(
    capabilitiesState: CapabilitiesState,
    modifier: Modifier = Modifier
) {
    val anyIssues = capabilitiesState.anyIssues
    val issueCount = capabilitiesState.issueCount

    val bgGradient = if (anyIssues) {
        SoftTheme.colors.statusWarning.copy(alpha = 0.12f)
    } else {
        SoftTheme.colors.statusSuccess.copy(alpha = 0.12f)
    }

    val iconColor = if (anyIssues) SoftTheme.colors.statusWarning else SoftTheme.colors.statusSuccess
    val icon = if (anyIssues) Icons.Default.Warning else Icons.Default.CheckCircle
    val title = if (anyIssues) "$issueCount Capability Issues Detected" else "All Android Capabilities Operational"
    val subtitle = if (anyIssues) {
        "Review affected subsystems below to ensure full voice, alert, and biometric functionality."
    } else {
        "Microphone, notifications, Health Connect, and exact alarms are fully authorized."
    }

    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .border(
                width = 1.dp,
                color = iconColor.copy(alpha = 0.35f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            ),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(bgGradient),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(20.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 12.sp
                )
            }
        }
    }
}
