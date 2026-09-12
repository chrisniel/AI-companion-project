package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.CapabilityExplanation
import com.example.domain.model.CapabilityType
import com.example.domain.model.MockPermissionAction
import com.example.domain.model.StatusSeverity
import com.example.ui.theme.SoftTheme

/**
 * In-Context Capability Alert Banner adhering to the UX Rule:
 * Never silently fail. Always show:
 * - What is unavailable
 * - Why it matters
 * - What the user can do
 * With mock actions: Review Access, Open Settings, Try Again.
 */
@Composable
fun CapabilityAlertBanner(
    title: String,
    explanation: CapabilityExplanation,
    onActionClick: (MockPermissionAction) -> Unit,
    modifier: Modifier = Modifier,
    onDismiss: (() -> Unit)? = null,
    testTag: String = "capability_alert_banner"
) {
    val borderColor = when (explanation.severity) {
        StatusSeverity.Success -> SoftTheme.colors.statusSuccess.copy(alpha = 0.5f)
        StatusSeverity.Warning -> SoftTheme.colors.statusWarning.copy(alpha = 0.5f)
        StatusSeverity.Error -> SoftTheme.colors.statusError.copy(alpha = 0.5f)
        StatusSeverity.Info -> SoftTheme.colors.accentCyan.copy(alpha = 0.5f)
        StatusSeverity.Normal -> SoftTheme.colors.borderSubtle
    }

    val iconColor = when (explanation.severity) {
        StatusSeverity.Success -> SoftTheme.colors.statusSuccess
        StatusSeverity.Warning -> SoftTheme.colors.statusWarning
        StatusSeverity.Error -> SoftTheme.colors.statusError
        StatusSeverity.Info -> SoftTheme.colors.accentCyan
        StatusSeverity.Normal -> SoftTheme.colors.textSecondary
    }

    val iconVector = when (explanation.severity) {
        StatusSeverity.Success -> Icons.Default.CheckCircle
        StatusSeverity.Warning -> Icons.Default.Warning
        StatusSeverity.Error -> Icons.Default.ErrorOutline
        else -> Icons.Default.Info
    }

    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag(testTag)
            .border(
                width = 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            ),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // Header Row: Icon + Title + (Optional Dismiss)
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(iconColor.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = iconVector,
                            contentDescription = null,
                            tint = iconColor,
                            modifier = Modifier.size(16.dp)
                        )
                    }

                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                }

                if (onDismiss != null) {
                    IconButton(
                        onClick = onDismiss,
                        modifier = Modifier.size(28.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Dismiss",
                            tint = SoftTheme.colors.textMuted,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }

            // Structured 3-part UX explanation: What / Why / What can do
            Column(
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                // 1. What is unavailable
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Text(
                        text = "UNAVAILABLE:",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = iconColor,
                        fontSize = 10.sp
                    )
                    Text(
                        text = explanation.whatIsUnavailable,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 12.sp,
                        modifier = Modifier.weight(1f)
                    )
                }

                // 2. Why it matters
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Text(
                        text = "IMPACT:",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.accentBlue,
                        fontSize = 10.sp
                    )
                    Text(
                        text = explanation.whyItMatters,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 12.sp,
                        modifier = Modifier.weight(1f)
                    )
                }

                // 3. What the user can do
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Text(
                        text = "ACTION:",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.statusSuccess,
                        fontSize = 10.sp
                    )
                    Text(
                        text = explanation.whatUserCanDo,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            // Action Buttons
            if (explanation.availableActions.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    explanation.availableActions.forEach { action ->
                        ActionChipButton(
                            action = action,
                            onClick = { onActionClick(action) }
                        )
                    }
                }
            }
        }
    }
}

/**
 * Compact, tactile action chip button for mock permissions.
 */
@Composable
fun ActionChipButton(
    action: MockPermissionAction,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val icon = when (action) {
        MockPermissionAction.REVIEW_ACCESS -> Icons.Default.Info
        MockPermissionAction.OPEN_SETTINGS -> Icons.Default.Settings
        MockPermissionAction.TRY_AGAIN -> Icons.Default.Refresh
    }

    val buttonBg = when (action) {
        MockPermissionAction.OPEN_SETTINGS -> SoftTheme.colors.accentBlue.copy(alpha = 0.15f)
        MockPermissionAction.REVIEW_ACCESS -> SoftTheme.colors.accentCyan.copy(alpha = 0.15f)
        MockPermissionAction.TRY_AGAIN -> SoftTheme.colors.statusSuccess.copy(alpha = 0.15f)
    }

    val buttonTint = when (action) {
        MockPermissionAction.OPEN_SETTINGS -> SoftTheme.colors.accentBlue
        MockPermissionAction.REVIEW_ACCESS -> SoftTheme.colors.accentCyan
        MockPermissionAction.TRY_AGAIN -> SoftTheme.colors.statusSuccess
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(buttonBg)
            .border(
                width = 1.dp,
                color = buttonTint.copy(alpha = 0.3f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = buttonTint,
                modifier = Modifier.size(13.dp)
            )
            Text(
                text = action.label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = buttonTint,
                fontSize = 11.sp
            )
        }
    }
}

/**
 * Detailed capability card for the Android Permissions and Capability Hub.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CapabilityHubCard(
    capabilityType: CapabilityType,
    statusText: String,
    explanation: CapabilityExplanation,
    stateOptions: List<String>,
    selectedStateIndex: Int,
    onSelectStateIndex: (Int) -> Unit,
    onActionClick: (MockPermissionAction) -> Unit,
    modifier: Modifier = Modifier,
    isOptionalEnabled: Boolean? = null,
    onToggleOptional: ((Boolean) -> Unit)? = null
) {
    val borderColor = when (explanation.severity) {
        StatusSeverity.Success -> SoftTheme.colors.statusSuccess.copy(alpha = 0.4f)
        StatusSeverity.Warning -> SoftTheme.colors.statusWarning.copy(alpha = 0.4f)
        StatusSeverity.Error -> SoftTheme.colors.statusError.copy(alpha = 0.4f)
        StatusSeverity.Info -> SoftTheme.colors.accentCyan.copy(alpha = 0.4f)
        StatusSeverity.Normal -> SoftTheme.colors.borderSubtle
    }

    val statusBadgeColor = when (explanation.severity) {
        StatusSeverity.Success -> SoftTheme.colors.statusSuccess
        StatusSeverity.Warning -> SoftTheme.colors.statusWarning
        StatusSeverity.Error -> SoftTheme.colors.statusError
        StatusSeverity.Info -> SoftTheme.colors.accentCyan
        StatusSeverity.Normal -> SoftTheme.colors.textMuted
    }

    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .border(
                width = 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .testTag("capability_card_${capabilityType.name.lowercase()}"),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Header Row: Icon + Title/Subtitle Column (with Status Badge below)
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(statusBadgeColor.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = capabilityType.icon,
                        contentDescription = null,
                        tint = statusBadgeColor,
                        modifier = Modifier.size(20.dp)
                    )
                }

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = capabilityType.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "Android System Capability",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textMuted,
                        fontSize = 11.sp
                    )

                    StatusBadge(
                        text = statusText,
                        severity = explanation.severity
                    )
                }
            }

            // Optional future toggle (e.g. for Bluetooth peripheral integration)
            if (isOptionalEnabled != null && onToggleOptional != null) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(SoftTheme.colors.surfaceElevated.copy(alpha = 0.5f))
                        .padding(horizontal = 10.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Require Bluetooth Peripheral Link",
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Only requests Bluetooth if pairing low-latency wireless hardware",
                            style = MaterialTheme.typography.labelSmall,
                            color = SoftTheme.colors.textSecondary,
                            fontSize = 10.sp
                        )
                    }

                    androidx.compose.material3.Switch(
                        checked = isOptionalEnabled,
                        onCheckedChange = onToggleOptional,
                        modifier = Modifier.testTag("bluetooth_required_switch")
                    )
                }
            }

            // Never Silently Fail Breakdown
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(SoftTheme.colors.surfaceElevated.copy(alpha = 0.4f))
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // 1. What is unavailable
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Text(
                        text = "WHAT'S UNAVAILABLE:",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = statusBadgeColor,
                        fontSize = 10.sp
                    )
                    Text(
                        text = explanation.whatIsUnavailable,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 12.sp,
                        modifier = Modifier.weight(1f)
                    )
                }

                // 2. Why it matters
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Text(
                        text = "WHY IT MATTERS:",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.accentBlue,
                        fontSize = 10.sp
                    )
                    Text(
                        text = explanation.whyItMatters,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 12.sp,
                        modifier = Modifier.weight(1f)
                    )
                }

                // 3. What the user can do
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Text(
                        text = "WHAT YOU CAN DO:",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.statusSuccess,
                        fontSize = 10.sp
                    )
                    Text(
                        text = explanation.whatUserCanDo,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 12.sp,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            // Action Buttons
            if (explanation.availableActions.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    explanation.availableActions.forEach { action ->
                        ActionChipButton(
                            action = action,
                            onClick = { onActionClick(action) }
                        )
                    }
                }
            }

            // Interactive State Simulator (allows reviewing every requested state)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = "SIMULATE OS STATE (NO REAL PERMISSIONS REQUESTED)",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 9.sp
                )

                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    stateOptions.forEachIndexed { index, optionName ->
                        val isSelected = index == selectedStateIndex
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                                .background(
                                    if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.2f)
                                    else SoftTheme.colors.surfaceElevated
                                )
                                .border(
                                    width = 1.dp,
                                    color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                                )
                                .clickable { onSelectStateIndex(index) }
                                .padding(horizontal = 10.dp, vertical = 5.dp)
                                .testTag("simulate_${capabilityType.name.lowercase()}_$index")
                        ) {
                            Text(
                                text = optionName,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary,
                                fontSize = 11.sp
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Bottom sheet dialog explaining the mock action results without invoking real permission APIs.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MockActionDetailsSheet(
    isOpen: Boolean,
    action: MockPermissionAction?,
    capabilityType: CapabilityType?,
    onDismiss: () -> Unit,
    onSimulateGrant: () -> Unit
) {
    if (!isOpen || action == null || capabilityType == null) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val actionDescription = when (action) {
        MockPermissionAction.OPEN_SETTINGS -> when (capabilityType) {
            CapabilityType.MICROPHONE -> "Simulated Android Intent: android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS targeting package com.example."
            CapabilityType.NOTIFICATIONS -> "Simulated Android Intent: android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS targeting app notification channels."
            CapabilityType.HEALTH_CONNECT -> "Simulated Health Connect Intent: androidx.health.connect.client.HealthConnectClient.getHealthConnectSettingsAction."
            CapabilityType.ALARMS -> "Simulated Android 12+ Special Access: android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM."
            CapabilityType.BLUETOOTH_AUDIO -> "Simulated Bluetooth Intent: android.provider.Settings.ACTION_BLUETOOTH_SETTINGS."
        }
        MockPermissionAction.REVIEW_ACCESS -> when (capabilityType) {
            CapabilityType.MICROPHONE -> "Simulated Android Permission Dialog: Prompting runtime RECORD_AUDIO permission."
            CapabilityType.NOTIFICATIONS -> "Simulated Android Permission Dialog: Prompting runtime POST_NOTIFICATIONS permission."
            CapabilityType.HEALTH_CONNECT -> "Simulated Health Connect Sheet: Granular permission consent sheet for Heart Rate, Steps, Sleep, and SpO2."
            CapabilityType.ALARMS -> "Simulated Policy Check: Verifying SCHEDULE_EXACT_ALARM and USE_EXACT_ALARM manifest declarations."
            CapabilityType.BLUETOOTH_AUDIO -> "Simulated Android Permission Dialog: Prompting BLUETOOTH_CONNECT runtime permission."
        }
        MockPermissionAction.TRY_AGAIN -> "Simulated Retry: Checking on-device hardware buffers, sensor drivers, and current permission grants."
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.surfaceElevated,
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(vertical = 12.dp)
                    .width(36.dp)
                    .height(4.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.borderSubtle)
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .padding(bottom = 36.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(SoftTheme.colors.accentBlue.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = capabilityType.icon,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(20.dp)
                    )
                }

                Column {
                    Text(
                        text = "${action.label}: ${capabilityType.title}",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "Android System Capability Action",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textMuted
                    )
                }
            }

            // Informational Box
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(SoftTheme.colors.background)
                    .border(
                        width = 1.dp,
                        color = SoftTheme.colors.borderSubtle,
                        shape = RoundedCornerShape(12.dp)
                    )
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "ACTION INTENT DETAILS",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.accentCyan,
                    fontSize = 10.sp
                )

                Text(
                    text = actionDescription,
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textPrimary,
                    fontSize = 12.sp
                )

                Text(
                    text = "Per Batch 13 instructions: Real Android permission dialogs and system intents are not triggered in this environment. All actions operate within design simulation mode.",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 11.sp
                )
            }

            // Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                SoftGlassButton(
                    text = "Simulate Grant",
                    onClick = {
                        onSimulateGrant()
                        onDismiss()
                    },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("dialog_simulate_grant_button")
                )

                SoftGlassButton(
                    text = "Close",
                    onClick = onDismiss,
                    modifier = Modifier
                        .weight(1f)
                        .testTag("dialog_close_button")
                )
            }
        }
    }
}
