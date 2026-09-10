package com.example.ui.screens.devices

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.DeviceCategory
import com.example.domain.model.DeviceItem
import com.example.domain.model.DeviceStatus
import com.example.ui.components.InteractiveSoftGlassCard
import com.example.ui.components.SoftGlassCard
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Mobile Devices Screen (Batch 9).
 * Lightweight mobile page presenting:
 * - Mock devices: Local AI Core PC, This Phone, audio output, microphone, health provider
 * - Device Statuses: Online, Offline, Connecting
 * - Zero hardcoded commercial device brands
 * - Zero Bluetooth implementation
 * - Ping & latency refresh capability
 * - Role description, transport, and connection diagnostics
 */
@Composable
fun DevicesScreen(
    modifier: Modifier = Modifier,
    onNavigateBack: (() -> Unit)? = null,
    viewModel: DevicesViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    val onlineCount = uiState.devices.count { it.status == DeviceStatus.ONLINE }
    val totalCount = uiState.devices.size

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .testTag("devices_screen")
            .padding(horizontal = SoftTheme.spacing.lg),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
    ) {
        // Optional top navigation header
        if (onNavigateBack != null) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = SoftTheme.spacing.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                ) {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("devices_back_button")
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Navigate Back",
                            tint = SoftTheme.colors.textPrimary
                        )
                    }
                    Column {
                        Text(
                            text = "Devices",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Connected local endpoints & hardware",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }
            }
        } else {
            item {
                Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))
            }
        }

        // Section: OVERVIEW & REFRESH ACTION
        item {
            DevicesSummaryCard(
                onlineCount = onlineCount,
                totalCount = totalCount,
                isPinging = uiState.isPinging,
                onPingAll = { viewModel.pingAllDevices() }
            )
        }

        // Section: ENDPOINTS LIST
        item {
            Text(
                text = "PAIRED SYSTEM ENDPOINTS ($onlineCount/$totalCount ONLINE)",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textMuted,
                modifier = Modifier.padding(horizontal = SoftTheme.spacing.xs)
            )
        }

        items(
            items = uiState.devices,
            key = { it.id }
        ) { device ->
            DeviceRowCard(
                device = device,
                onToggleStatus = { viewModel.toggleDeviceStatus(device.id) }
            )
        }

        // Section: PRIVATE MESH & SECURITY NOTICE
        item {
            PrivateMeshNoticeCard()
        }

        item {
            Spacer(modifier = Modifier.height(SoftTheme.spacing.xl))
        }
    }
}

/**
 * Summary card presenting network status and ping/refresh control.
 */
@Composable
private fun DevicesSummaryCard(
    onlineCount: Int,
    totalCount: Int,
    isPinging: Boolean,
    onPingAll: () -> Unit,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("devices_summary_card"),
        elevation = SoftTheme.tokens.elevations.card
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Local Mesh Endpoints",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = if (onlineCount == totalCount)
                        "All $totalCount system endpoints online and synchronized"
                    else
                        "$onlineCount of $totalCount endpoints connected",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (onlineCount == totalCount)
                        SoftTheme.colors.statusSuccess
                    else
                        SoftTheme.colors.accentAmber
                )
            }

            // Ping Nodes Action Button
            Box(
                modifier = Modifier
                    .testTag("ping_devices_button")
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                    .background(SoftTheme.colors.accentBlue.copy(alpha = 0.12f))
                    .border(
                        width = 1.dp,
                        color = SoftTheme.colors.accentBlue.copy(alpha = 0.3f),
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                    )
                    .clickable(enabled = !isPinging, onClick = onPingAll)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    if (isPinging) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(14.dp),
                            strokeWidth = 2.dp,
                            color = SoftTheme.colors.accentBlue
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Ping nodes",
                            tint = SoftTheme.colors.accentBlue,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                    Text(
                        text = if (isPinging) "Pinging..." else "Ping Nodes",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.accentBlue
                    )
                }
            }
        }
    }
}

/**
 * Individual device card displaying category icon, generic name, status badge, role, and latency.
 */
@Composable
private fun DeviceRowCard(
    device: DeviceItem,
    onToggleStatus: () -> Unit,
    modifier: Modifier = Modifier
) {
    val categoryIcon = when (device.category) {
        DeviceCategory.CORE_PC -> Icons.Default.Computer
        DeviceCategory.PHONE -> Icons.Default.Smartphone
        DeviceCategory.AUDIO_OUTPUT -> Icons.AutoMirrored.Filled.VolumeUp
        DeviceCategory.MICROPHONE -> Icons.Default.Mic
        DeviceCategory.HEALTH_PROVIDER -> Icons.Default.Favorite
    }

    val iconTint = when (device.category) {
        DeviceCategory.CORE_PC -> SoftTheme.colors.accentCyan
        DeviceCategory.PHONE -> SoftTheme.colors.accentBlue
        DeviceCategory.AUDIO_OUTPUT -> SoftTheme.colors.accentAmber
        DeviceCategory.MICROPHONE -> SoftTheme.colors.accentViolet
        DeviceCategory.HEALTH_PROVIDER -> SoftTheme.colors.statusError
    }

    InteractiveSoftGlassCard(
        onClick = onToggleStatus,
        testTag = "device_item_${device.id}",
        modifier = modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.md),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.sm))
                            .background(iconTint.copy(alpha = 0.12f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = categoryIcon,
                            contentDescription = device.name,
                            tint = iconTint,
                            modifier = Modifier.size(20.dp)
                        )
                    }

                    Column {
                        Text(
                            text = device.name,
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = device.connectionType,
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }

                // Status Badge
                DeviceStatusBadge(
                    status = device.status,
                    testTag = "device_status_${device.id}"
                )
            }

            // Role Description
            Text(
                text = device.roleDescription,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textSecondary
            )

            // Diagnostic row: Details & Latency
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 2.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = device.details,
                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                    color = SoftTheme.colors.textMuted
                )

                if (device.latencyMs != null && device.status == DeviceStatus.ONLINE) {
                    Text(
                        text = "${device.latencyMs} ms",
                        style = MonospaceTelemetry.copy(fontSize = 11.sp),
                        fontWeight = FontWeight.Medium,
                        color = SoftTheme.colors.accentBlue
                    )
                }
            }
        }
    }
}

/**
 * Accessible pill badge for DeviceStatus: Online, Offline, Connecting.
 */
@Composable
private fun DeviceStatusBadge(
    status: DeviceStatus,
    testTag: String,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse_connecting")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(600),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )

    val (bgColor, textColor, borderColor) = when (status) {
        DeviceStatus.ONLINE -> Triple(
            SoftTheme.colors.statusSuccess.copy(alpha = 0.12f),
            SoftTheme.colors.statusSuccess,
            SoftTheme.colors.statusSuccess.copy(alpha = 0.35f)
        )
        DeviceStatus.CONNECTING -> Triple(
            SoftTheme.colors.accentAmber.copy(alpha = 0.15f),
            SoftTheme.colors.accentAmber,
            SoftTheme.colors.accentAmber.copy(alpha = 0.4f)
        )
        DeviceStatus.OFFLINE -> Triple(
            SoftTheme.colors.surfacePressed,
            SoftTheme.colors.textMuted,
            SoftTheme.colors.borderSubtle
        )
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(bgColor)
            .border(
                width = 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = 8.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .then(
                        if (status == DeviceStatus.CONNECTING) Modifier.scale(pulseScale) else Modifier
                    )
                    .clip(CircleShape)
                    .background(textColor)
            )
            Text(
                text = status.label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = textColor
            )
        }
    }
}

/**
 * Notice card informing about network architecture and zero cloud tracking.
 */
@Composable
private fun PrivateMeshNoticeCard(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(SoftTheme.colors.surfaceElevated.copy(alpha = 0.5f))
            .border(
                width = 1.dp,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .padding(SoftTheme.spacing.md)
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            Icon(
                imageVector = Icons.Default.Security,
                contentDescription = null,
                tint = SoftTheme.colors.statusSuccess,
                modifier = Modifier.size(18.dp)
            )
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = "Private Node Mesh",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = "Hardware endpoints and audio sinks communicate via local private subnet and native OS driver pipelines. Zero external cloud tracking or Bluetooth required.",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textMuted
                )
            }
        }
    }
}
