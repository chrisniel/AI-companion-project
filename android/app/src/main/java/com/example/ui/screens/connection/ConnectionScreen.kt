package com.example.ui.screens.connection

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
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
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.OfflineCapabilityItem
import com.example.domain.model.OfflineFeatureMatrix
import com.example.domain.model.SyncStatus
import com.example.ui.components.CalmConnectionBanner
import com.example.ui.components.CalmSyncBanner
import com.example.ui.components.SoftGlassButton
import com.example.ui.components.SoftGlassCard
import com.example.ui.theme.SoftTheme

/**
 * Dedicated Connection & Offline Synchronization Hub (Batch 12).
 *
 * Implements:
 * - Connection Modes: Local LAN, Remote, Connecting, Reconnecting, Offline
 * - PC Online (Everything available) vs PC Offline (Functionality breakdown)
 * - Available Offline: Mirrored alarms, cached tasks, cached schedule, Health Connect data, settings
 * - Unavailable Offline: Local AI assistant, PC tools, model execution
 * - Sync Status: Synchronized, Pending, Conflict, Stale, Failed
 * - Clear but calm banners with dismiss and resolution actions
 * - Optional Cloud Fallback shown strictly as a future setting only (disabled, air-gapped)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConnectionScreen(
    connectionInfo: ConnectionInfo,
    onSetConnectionState: (CoreConnectionState) -> Unit,
    onSetSyncStatus: (SyncStatus) -> Unit,
    onResolveConflict: (keepLocal: Boolean) -> Unit,
    onRetrySync: () -> Unit,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()
    var statusMessage by remember { mutableStateOf<String?>(null) }
    var isCloudFallbackMockEnabled by remember { mutableStateOf(false) }

    Scaffold(
        modifier = modifier
            .fillMaxSize()
            .testTag("connection_screen"),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Connection & Sync",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("connection_back_button")
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = SoftTheme.colors.textPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = SoftTheme.colors.background
                )
            )
        },
        containerColor = SoftTheme.colors.background
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(scrollState)
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.sm),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            // Live Calm Banners
            CalmSyncBanner(
                syncStatus = connectionInfo.syncStatus,
                onActionClick = {
                    when (connectionInfo.syncStatus) {
                        SyncStatus.CONFLICT -> onResolveConflict(true)
                        SyncStatus.FAILED, SyncStatus.PENDING -> onRetrySync()
                        SyncStatus.STALE -> onRetrySync()
                        SyncStatus.SYNCHRONIZED -> {}
                    }
                },
                onDismiss = { onSetSyncStatus(SyncStatus.SYNCHRONIZED) }
            )

            CalmConnectionBanner(
                connectionState = connectionInfo.state,
                onOpenOfflineDetails = { /* Already on connection screen */ },
                onDismiss = { /* calm dismiss */ }
            )

            // Status message toast card if triggered
            if (statusMessage != null) {
                Surface(
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.sm),
                    color = SoftTheme.colors.accentCyan.copy(alpha = 0.15f),
                    border = BorderStroke(1.dp, SoftTheme.colors.accentCyan.copy(alpha = 0.4f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(SoftTheme.spacing.sm),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = statusMessage ?: "",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textPrimary,
                            modifier = Modifier.weight(1f)
                        )
                        IconButton(
                            onClick = { statusMessage = null },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = "Dismiss message",
                                tint = SoftTheme.colors.accentCyan,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }

            // SECTION: CONNECTION MODES
            SoftGlassCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("connection_modes_card"),
                elevation = SoftTheme.tokens.elevations.subtle
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(SoftTheme.spacing.md),
                    verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "CONNECTION MODE",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.accentBlue
                        )

                        Surface(
                            shape = CircleShape,
                            color = if (connectionInfo.state.isOnline) SoftTheme.colors.statusSuccess.copy(alpha = 0.15f)
                            else SoftTheme.colors.statusWarning.copy(alpha = 0.15f),
                            border = BorderStroke(
                                1.dp,
                                if (connectionInfo.state.isOnline) SoftTheme.colors.statusSuccess
                                else SoftTheme.colors.statusWarning
                            )
                        ) {
                            Text(
                                text = connectionInfo.state.displayName,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = if (connectionInfo.state.isOnline) SoftTheme.colors.statusSuccess
                                else SoftTheme.colors.statusWarning,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                            )
                        }
                    }

                    Text(
                        text = "Simulate Local AI Core connectivity mode:",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textMuted
                    )

                    // 5 Mock Mode Buttons
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
                                    .testTag("mode_btn_${mode.name}")
                            ) {
                                Box(
                                    modifier = Modifier.padding(vertical = 7.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = when (mode) {
                                            CoreConnectionState.Local -> "Local LAN"
                                            CoreConnectionState.Remote -> "Remote"
                                            CoreConnectionState.Connecting -> "Connect"
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

                    // Telemetry & Security specs
                    Spacer(modifier = Modifier.height(2.dp))
                    MetricItem(label = "Node Topology", value = "Private Air-Gapped Mesh (Direct LAN)")
                    MetricItem(label = "Hardware Channel", value = "Hardware-bound mTLS 1.3")
                    MetricItem(
                        label = "PC Node Status",
                        value = if (connectionInfo.state.isOnline) "ONLINE (Everything Available)" else "OFFLINE (Local Mobile Mode Active)"
                    )
                }
            }

            // SECTION: PC ONLINE VS PC OFFLINE FUNCTIONALITY
            SoftGlassCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("offline_capabilities_card"),
                elevation = SoftTheme.tokens.elevations.subtle
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(SoftTheme.spacing.md),
                    verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                ) {
                    Text(
                        text = if (connectionInfo.state.isOnline) "PC ONLINE • EVERYTHING AVAILABLE"
                        else "PC OFFLINE • LOCAL FUNCTIONALITY BREAKDOWN",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = if (connectionInfo.state.isOnline) SoftTheme.colors.statusSuccess else SoftTheme.colors.accentAmber
                    )

                    Text(
                        text = if (connectionInfo.state.isOnline)
                            "Local AI Core PC is fully reachable. Direct hardware model execution, live assistant streaming, and PC tools are operational."
                        else
                            "Local AI Core PC is currently unreachable. The following services remain fully active locally on device:",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )

                    // AVAILABLE OFFLINE
                    Text(
                        text = "AVAILABLE OFFLINE",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.statusSuccess
                    )

                    OfflineFeatureMatrix.availableOffline.forEach { item ->
                        FeatureItemRow(item = item, isAvailable = true)
                    }

                    Spacer(modifier = Modifier.height(4.dp))

                    // UNAVAILABLE WITHOUT PC
                    Text(
                        text = "UNAVAILABLE WITHOUT PC",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.statusWarning
                    )

                    OfflineFeatureMatrix.unavailableOffline.forEach { item ->
                        FeatureItemRow(item = item, isAvailable = false)
                    }
                }
            }

            // SECTION: SYNCHRONIZATION STATUS
            SoftGlassCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("sync_status_card"),
                elevation = SoftTheme.tokens.elevations.subtle
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(SoftTheme.spacing.md),
                    verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "SYNC STATUS",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.accentCyan
                        )

                        Surface(
                            shape = CircleShape,
                            color = when (connectionInfo.syncStatus) {
                                SyncStatus.SYNCHRONIZED -> SoftTheme.colors.statusSuccess.copy(alpha = 0.15f)
                                SyncStatus.PENDING -> SoftTheme.colors.accentCyan.copy(alpha = 0.15f)
                                SyncStatus.CONFLICT -> SoftTheme.colors.statusWarning.copy(alpha = 0.15f)
                                SyncStatus.STALE -> SoftTheme.colors.textMuted.copy(alpha = 0.15f)
                                SyncStatus.FAILED -> SoftTheme.colors.statusError.copy(alpha = 0.15f)
                            },
                            border = BorderStroke(
                                1.dp,
                                when (connectionInfo.syncStatus) {
                                    SyncStatus.SYNCHRONIZED -> SoftTheme.colors.statusSuccess
                                    SyncStatus.PENDING -> SoftTheme.colors.accentCyan
                                    SyncStatus.CONFLICT -> SoftTheme.colors.statusWarning
                                    SyncStatus.STALE -> SoftTheme.colors.textMuted
                                    SyncStatus.FAILED -> SoftTheme.colors.statusError
                                }
                            )
                        ) {
                            Text(
                                text = connectionInfo.syncStatus.label,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = when (connectionInfo.syncStatus) {
                                    SyncStatus.SYNCHRONIZED -> SoftTheme.colors.statusSuccess
                                    SyncStatus.PENDING -> SoftTheme.colors.accentCyan
                                    SyncStatus.CONFLICT -> SoftTheme.colors.statusWarning
                                    SyncStatus.STALE -> SoftTheme.colors.textMuted
                                    SyncStatus.FAILED -> SoftTheme.colors.statusError
                                },
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                            )
                        }
                    }

                    Text(
                        text = "Test all 5 mobile sync conditions:",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textMuted
                    )

                    // 5 Sync Status Buttons
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
                                    .testTag("sync_btn_${status.name}")
                            ) {
                                Box(
                                    modifier = Modifier.padding(vertical = 7.dp),
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

                    // Conflict resolution buttons if conflict
                    if (connectionInfo.syncStatus == SyncStatus.CONFLICT) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                        ) {
                            SoftGlassButton(
                                text = "Keep Local Changes",
                                onClick = { onResolveConflict(true) },
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("btn_resolve_keep_local")
                            )
                            SoftGlassButton(
                                text = "Accept PC State",
                                onClick = { onResolveConflict(false) },
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("btn_resolve_accept_pc")
                            )
                        }
                    }
                }
            }

            // SECTION: OPTIONAL CLOUD FALLBACK (FUTURE SETTING ONLY)
            SoftGlassCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("future_cloud_fallback_section"),
                elevation = SoftTheme.tokens.elevations.flat
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(SoftTheme.spacing.md),
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
                                modifier = Modifier.size(22.dp)
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
                            checked = isCloudFallbackMockEnabled,
                            onCheckedChange = { isCloudFallbackMockEnabled = it },
                            enabled = false, // Disabled to strictly obey "Do not implement networking. Do not invent automatic cloud fallback."
                            colors = SwitchDefaults.colors(
                                disabledCheckedThumbColor = SoftTheme.colors.textMuted,
                                disabledUncheckedThumbColor = SoftTheme.colors.textMuted
                            ),
                            modifier = Modifier.testTag("switch_future_cloud_fallback")
                        )
                    }

                    Text(
                        text = "Do not implement networking. Direct air-gapped on-premise execution is enforced. Automatic cloud fallback is not enabled. Optional cloud fallback may be shown as a future setting only.",
                        style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.textMuted
                    )
                }
            }

            // Quick Diagnostic Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                SoftGlassButton(
                    text = "Ping Local Node",
                    onClick = { statusMessage = "Local loopback ping: 12ms. Zero packet drops." },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("btn_ping_local_node")
                )
                SoftGlassButton(
                    text = "Force Re-Sync",
                    onClick = {
                        onRetrySync()
                        statusMessage = "Synchronization triggered."
                    },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("btn_force_sync")
                )
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.lg))
        }
    }
}

@Composable
private fun MetricItem(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = SoftTheme.colors.textSecondary
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = SoftTheme.colors.textPrimary
        )
    }
}

@Composable
private fun FeatureItemRow(item: OfflineCapabilityItem, isAvailable: Boolean) {
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
            .testTag("feature_row_${item.iconKey}")
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
                        imageVector = if (isAvailable) Icons.Default.Check else Icons.Default.WifiOff,
                        contentDescription = null,
                        tint = if (isAvailable) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = if (isAvailable) "Available" else "Offline",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        fontWeight = FontWeight.Bold,
                        color = if (isAvailable) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning
                    )
                }
            }
        }
    }
}
