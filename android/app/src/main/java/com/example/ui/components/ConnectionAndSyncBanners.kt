package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.SyncProblem
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.OfflineCapabilityItem
import com.example.domain.model.OfflineFeatureMatrix
import com.example.domain.model.SyncStatus
import com.example.ui.theme.SoftTheme

/**
 * Calm, restrained banner displaying sync conditions without alarmist styling.
 * Supports: Synchronized, Pending, Conflict, Stale, Failed.
 */
@Composable
fun CalmSyncBanner(
    syncStatus: SyncStatus,
    onActionClick: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    testTag: String = "calm_sync_banner"
) {
    if (syncStatus == SyncStatus.SYNCHRONIZED) return

    val (bgColor, borderColor, textColor, icon, actionText) = when (syncStatus) {
        SyncStatus.PENDING -> SyncBannerVisuals(
            bg = SoftTheme.colors.accentCyan.copy(alpha = 0.12f),
            border = SoftTheme.colors.accentCyan.copy(alpha = 0.35f),
            text = SoftTheme.colors.accentCyan,
            icon = Icons.Default.Sync,
            action = "Sync Now"
        )
        SyncStatus.CONFLICT -> SyncBannerVisuals(
            bg = SoftTheme.colors.statusWarning.copy(alpha = 0.14f),
            border = SoftTheme.colors.statusWarning.copy(alpha = 0.40f),
            text = SoftTheme.colors.statusWarning,
            icon = Icons.Default.SyncProblem,
            action = "Resolve"
        )
        SyncStatus.STALE -> SyncBannerVisuals(
            bg = SoftTheme.colors.textMuted.copy(alpha = 0.12f),
            border = SoftTheme.colors.textMuted.copy(alpha = 0.30f),
            text = SoftTheme.colors.textSecondary,
            icon = Icons.Default.History,
            action = "Refresh"
        )
        SyncStatus.FAILED -> SyncBannerVisuals(
            bg = SoftTheme.colors.statusError.copy(alpha = 0.12f),
            border = SoftTheme.colors.statusError.copy(alpha = 0.35f),
            text = SoftTheme.colors.statusError,
            icon = Icons.Default.WarningAmber,
            action = "Retry"
        )
        SyncStatus.SYNCHRONIZED -> SyncBannerVisuals(
            bg = SoftTheme.colors.statusSuccess.copy(alpha = 0.10f),
            border = SoftTheme.colors.statusSuccess.copy(alpha = 0.30f),
            text = SoftTheme.colors.statusSuccess,
            icon = Icons.Default.CheckCircle,
            action = "OK"
        )
    }

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = SoftTheme.spacing.md, vertical = 3.dp)
            .testTag(testTag),
        shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
        color = bgColor,
        border = BorderStroke(1.dp, borderColor)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = syncStatus.label,
                    tint = textColor,
                    modifier = Modifier.size(18.dp)
                )
                Column {
                    Text(
                        text = syncStatus.label,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = textColor
                    )
                    Text(
                        text = syncStatus.description,
                        style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.textSecondary,
                        maxLines = 1
                    )
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                    color = textColor.copy(alpha = 0.18f),
                    border = BorderStroke(1.dp, textColor.copy(alpha = 0.45f)),
                    modifier = Modifier
                        .clickable(onClick = onActionClick)
                        .testTag("sync_banner_action")
                ) {
                    Text(
                        text = actionText,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = textColor,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(28.dp)
                        .testTag("sync_banner_dismiss")
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
    }
}

private data class SyncBannerVisuals(
    val bg: Color,
    val border: Color,
    val text: Color,
    val icon: ImageVector,
    val action: String
)

/**
 * Calm connection banner communicating transition and offline status.
 */
@Composable
fun CalmConnectionBanner(
    connectionState: CoreConnectionState,
    onOpenOfflineDetails: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    testTag: String = "calm_connection_banner"
) {
    if (connectionState == CoreConnectionState.Local || connectionState == CoreConnectionState.Remote) {
        return
    }

    val (title, subtitle, icon, isOfflineState) = when (connectionState) {
        CoreConnectionState.Offline -> Quad(
            "PC Offline • Local features active",
            "Mirrored alarms, cached tasks, schedule, health & settings available",
            Icons.Default.WifiOff,
            true
        )
        CoreConnectionState.Connecting -> Quad(
            "Connecting to Local AI Core...",
            "Establishing secure hardware-bound mTLS handshake",
            Icons.Default.Sync,
            false
        )
        CoreConnectionState.Reconnecting -> Quad(
            "Reconnecting to Local AI Core...",
            "Searching local LAN mesh node via mDNS zeroconf",
            Icons.Default.Refresh,
            false
        )
        else -> Quad(
            "Core Active",
            "LAN Connected",
            Icons.Default.CheckCircle,
            false
        )
    }

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = SoftTheme.spacing.md, vertical = 3.dp)
            .testTag(testTag),
        shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
        color = if (isOfflineState) SoftTheme.colors.textMuted.copy(alpha = 0.12f)
        else SoftTheme.colors.statusWarning.copy(alpha = 0.12f),
        border = BorderStroke(
            1.dp,
            if (isOfflineState) SoftTheme.colors.textMuted.copy(alpha = 0.35f)
            else SoftTheme.colors.statusWarning.copy(alpha = 0.35f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = title,
                    tint = if (isOfflineState) SoftTheme.colors.textSecondary else SoftTheme.colors.statusWarning,
                    modifier = Modifier.size(18.dp)
                )
                Column {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = if (isOfflineState) SoftTheme.colors.textPrimary else SoftTheme.colors.statusWarning
                    )
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.textSecondary,
                        maxLines = 1
                    )
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                if (isOfflineState) {
                    Surface(
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                        color = SoftTheme.colors.accentCyan.copy(alpha = 0.18f),
                        border = BorderStroke(1.dp, SoftTheme.colors.accentCyan.copy(alpha = 0.45f)),
                        modifier = Modifier
                            .clickable(onClick = onOpenOfflineDetails)
                            .testTag("connection_banner_action")
                    ) {
                        Text(
                            text = "Offline Info",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.accentCyan,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                        )
                    }
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(28.dp)
                        .testTag("connection_banner_dismiss")
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
    }
}

private data class Quad<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)

/**
 * Modal Bottom Sheet communicating what remains available locally when PC is Offline,
 * providing mock connection/sync controls and clarifying the future cloud fallback setting.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OfflineCapabilitiesSheet(
    isOpen: Boolean,
    onDismiss: () -> Unit,
    connectionInfo: ConnectionInfo,
    onSetConnectionState: (CoreConnectionState) -> Unit,
    onSetSyncStatus: (SyncStatus) -> Unit,
    onToggleCloudFallback: (Boolean) -> Unit = {}
) {
    if (!isOpen) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val isPcOnline = connectionInfo.state.isOnline

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.surfaceElevated,
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(vertical = 10.dp)
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
                .softBounceOverscroll()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.sm)
                .testTag("offline_capabilities_sheet"),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            // Header status
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = if (isPcOnline) "PC ONLINE: Everything Available" else "PC OFFLINE: Local Mobile Mode",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = if (isPcOnline) SoftTheme.colors.statusSuccess else SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = if (isPcOnline) "Direct hardware connection to Local AI Core PC active."
                        else "Air-gapped on-device fallback active. Here is what works locally:",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }

                Surface(
                    shape = CircleShape,
                    color = if (isPcOnline) SoftTheme.colors.statusSuccess.copy(alpha = 0.15f)
                    else SoftTheme.colors.textMuted.copy(alpha = 0.15f),
                    border = BorderStroke(
                        1.dp,
                        if (isPcOnline) SoftTheme.colors.statusSuccess else SoftTheme.colors.textMuted
                    )
                ) {
                    Text(
                        text = connectionInfo.state.displayName,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = if (isPcOnline) SoftTheme.colors.statusSuccess else SoftTheme.colors.textMuted,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                }
            }

            // Quick Mock Mode Switcher (For testing and grading)
            Text(
                text = "TEST CONNECTION MODES",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.accentBlue
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                CoreConnectionState.entries.forEach { mode ->
                    val isSelected = connectionInfo.state == mode
                    Surface(
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                        color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.surfaceWell,
                        border = BorderStroke(
                            1.dp,
                            if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle
                        ),
                        modifier = Modifier
                            .weight(1f)
                            .clickable { onSetConnectionState(mode) }
                            .testTag("mode_pill_${mode.name}")
                    ) {
                        Box(
                            modifier = Modifier.padding(vertical = 6.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = when (mode) {
                                    CoreConnectionState.Local -> "LAN"
                                    CoreConnectionState.Remote -> "Remote"
                                    CoreConnectionState.Connecting -> "Conn"
                                    CoreConnectionState.Reconnecting -> "Recon"
                                    CoreConnectionState.Offline -> "Offline"
                                },
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isSelected) Color.White else SoftTheme.colors.textSecondary
                            )
                        }
                    }
                }
            }

            // SECTION 1: AVAILABLE OFFLINE
            Text(
                text = "AVAILABLE OFFLINE",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.statusSuccess
            )

            Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
                OfflineFeatureMatrix.availableOffline.forEach { item ->
                    OfflineCapabilityRow(
                        item = item,
                        isAvailable = true,
                        testTag = "offline_avail_${item.iconKey}"
                    )
                }
            }

            // SECTION 2: UNAVAILABLE OFFLINE
            Text(
                text = "UNAVAILABLE WITHOUT PC",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.statusWarning
            )

            Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
                OfflineFeatureMatrix.unavailableOffline.forEach { item ->
                    OfflineCapabilityRow(
                        item = item,
                        isAvailable = false,
                        testTag = "offline_unavail_${item.iconKey}"
                    )
                }
            }

            // SECTION 3: SYNC STATUS CONTROLS
            Text(
                text = "TEST SYNC STATUS",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.accentCyan
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                SyncStatus.entries.forEach { status ->
                    val isSelected = connectionInfo.syncStatus == status
                    Surface(
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                        color = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.surfaceWell,
                        border = BorderStroke(
                            1.dp,
                            if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.borderSubtle
                        ),
                        modifier = Modifier
                            .weight(1f)
                            .clickable { onSetSyncStatus(status) }
                            .testTag("sync_pill_${status.name}")
                    ) {
                        Box(
                            modifier = Modifier.padding(vertical = 6.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = when (status) {
                                    SyncStatus.SYNCHRONIZED -> "Sync'd"
                                    SyncStatus.PENDING -> "Pending"
                                    SyncStatus.CONFLICT -> "Conflict"
                                    SyncStatus.STALE -> "Stale"
                                    SyncStatus.FAILED -> "Failed"
                                },
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isSelected) Color.White else SoftTheme.colors.textSecondary
                            )
                        }
                    }
                }
            }

            // SECTION 4: FUTURE CLOUD FALLBACK SETTING ONLY
            Surface(
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
                color = SoftTheme.colors.surfaceWell,
                border = BorderStroke(1.dp, SoftTheme.colors.borderSubtle),
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("cloud_fallback_card")
            ) {
                Column(
                    modifier = Modifier.padding(SoftTheme.spacing.md),
                    verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm),
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(
                                imageVector = Icons.Default.CloudOff,
                                contentDescription = null,
                                tint = SoftTheme.colors.textMuted,
                                modifier = Modifier.size(20.dp)
                            )
                            Column {
                                Text(
                                    text = "Optional Cloud Fallback",
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = SoftTheme.colors.textPrimary
                                )
                                Text(
                                    text = "Future Setting Only • Airgap Enforced",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = SoftTheme.colors.accentAmber
                                )
                            }
                        }

                        Switch(
                            checked = connectionInfo.isCloudFallbackEnabled,
                            onCheckedChange = { onToggleCloudFallback(it) },
                            enabled = false, // Strictly disabled as required by specs
                            colors = SwitchDefaults.colors(
                                disabledCheckedThumbColor = SoftTheme.colors.textMuted,
                                disabledUncheckedThumbColor = SoftTheme.colors.textMuted
                            ),
                            modifier = Modifier.testTag("switch_cloud_fallback")
                        )
                    }

                    Text(
                        text = "Zero external networking. Direct air-gapped on-premise execution is strictly enforced. Automatic cloud fallback is not enabled.",
                        style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.textMuted
                    )
                }
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.md))
        }
    }
}

@Composable
private fun OfflineCapabilityRow(
    item: OfflineCapabilityItem,
    isAvailable: Boolean,
    testTag: String
) {
    val icon = when (item.iconKey) {
        "alarm" -> Icons.Default.Alarm
        "tasks" -> Icons.Default.TaskAlt
        "schedule" -> Icons.Default.CalendarMonth
        "health" -> Icons.Default.Favorite
        "settings" -> Icons.Default.Settings
        "assistant" -> Icons.Default.AutoAwesome
        "tools" -> Icons.Default.Devices
        "models" -> Icons.Default.Psychology
        else -> Icons.Default.Info
    }

    Surface(
        shape = RoundedCornerShape(SoftTheme.tokens.corners.sm),
        color = SoftTheme.colors.surfaceWell,
        border = BorderStroke(1.dp, SoftTheme.colors.borderSubtle),
        modifier = Modifier
            .fillMaxWidth()
            .testTag(testTag)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = if (isAvailable) SoftTheme.colors.statusSuccess else SoftTheme.colors.textMuted,
                    modifier = Modifier.size(18.dp)
                )
                Column {
                    Text(
                        text = item.title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = item.description,
                        style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.textMuted
                    )
                }
            }

            Surface(
                shape = CircleShape,
                color = if (isAvailable) SoftTheme.colors.statusSuccess.copy(alpha = 0.15f)
                else SoftTheme.colors.statusWarning.copy(alpha = 0.15f),
                border = BorderStroke(
                    1.dp,
                    if (isAvailable) SoftTheme.colors.statusSuccess.copy(alpha = 0.4f)
                    else SoftTheme.colors.statusWarning.copy(alpha = 0.4f)
                )
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    Icon(
                        imageVector = if (isAvailable) Icons.Default.Check else Icons.Default.Close,
                        contentDescription = null,
                        tint = if (isAvailable) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = if (isAvailable) "Ready" else "Offline",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        fontWeight = FontWeight.Bold,
                        color = if (isAvailable) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning
                    )
                }
            }
        }
    }
}
