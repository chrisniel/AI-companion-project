package com.example.ui.screens.alarms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.AlarmRedundancyStatus
import com.example.domain.model.DeviceSyncState
import com.example.ui.theme.SoftTheme

/**
 * REDUNDANCY STATUS CARD
 *
 * Displays mock redundancy and synchronization states per user request:
 *
 * Desktop  ● Synchronized
 * Android  ● Armed
 *
 * and:
 *
 * Desktop  ○ Offline
 * Android  ● Armed Locally
 *
 * Also supports interactive tap to toggle/simulate desktop link redundancy.
 */
@Composable
fun RedundancyStatusCard(
    redundancy: AlarmRedundancyStatus,
    onSimulateToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isDesktopSynced = redundancy.desktopStatus == DeviceSyncState.SYNCHRONIZED

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(SoftTheme.colors.surfaceElevated)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .clickable(onClick = onSimulateToggle)
            .padding(14.dp)
            .testTag("redundancy_status_card"),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // HEADER
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.weight(1f, fill = false)
            ) {
                Icon(
                    imageVector = Icons.Default.Security,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentBlue,
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = "Alarm Redundancy Engine",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }

            // Interactive simulation helper hint
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Sync,
                    contentDescription = null,
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(12.dp)
                )
                Text(
                    text = "Tap to test failover",
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 11.sp,
                    softWrap = false
                )
            }
        }

        // REDUNDANCY PAIR ROWS
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(SoftTheme.colors.surfaceWell)
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // 1. DESKTOP ROW
            // Formats requested:
            // "Desktop  ● Synchronized" OR "Desktop  ○ Offline"
            RedundancyNodeRow(
                icon = Icons.Default.Computer,
                nodeLabel = "Desktop",
                statusLabel = if (isDesktopSynced) "Synchronized" else "Offline",
                isArmedOrSynced = isDesktopSynced,
                activeColor = SoftTheme.colors.statusSuccess,
                inactiveColor = SoftTheme.colors.textMuted,
                testTag = "redundancy_node_desktop"
            )

            // Divider
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(SoftTheme.tokens.borders.hairline)
                    .background(SoftTheme.colors.borderSubtle.copy(alpha = 0.5f))
            )

            // 2. ANDROID ROW
            // Formats requested:
            // "Android  ● Armed" OR "Android  ● Armed Locally"
            RedundancyNodeRow(
                icon = Icons.Default.Smartphone,
                nodeLabel = "Android",
                statusLabel = if (isDesktopSynced) "Armed" else "Armed Locally",
                isArmedOrSynced = true, // Android always armed locally
                activeColor = SoftTheme.colors.accentBlue,
                inactiveColor = SoftTheme.colors.textMuted,
                testTag = "redundancy_node_android"
            )
        }

        // HEARTBEAT FOOTNOTE
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = if (isDesktopSynced) "Failover: Dual node acoustic replication active"
                else "Failover: Standalone mode active • Zero alarm misses guaranteed",
                modifier = Modifier
                    .weight(1f)
                    .padding(end = 8.dp),
                style = MaterialTheme.typography.labelSmall,
                color = SoftTheme.colors.textSecondary,
                fontSize = 11.sp
            )
            Text(
                text = redundancy.lastHeartbeat,
                style = MaterialTheme.typography.labelSmall,
                color = SoftTheme.colors.textMuted,
                fontSize = 11.sp,
                softWrap = false
            )
        }
    }
}

/**
 * Individual Node Row inside Redundancy Card.
 * Renders the explicit bullet format:
 * NodeName   ● Status (or ○ Offline)
 */
@Composable
private fun RedundancyNodeRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    nodeLabel: String,
    statusLabel: String,
    isArmedOrSynced: Boolean,
    activeColor: Color,
    inactiveColor: Color,
    testTag: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .testTag(testTag),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Node identifier with device icon
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isArmedOrSynced) activeColor else inactiveColor,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = nodeLabel,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = SoftTheme.colors.textPrimary
            )
        }

        // Status with Bullet ● or ○
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = if (isArmedOrSynced) "●" else "○",
                color = if (isArmedOrSynced) activeColor else inactiveColor,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp
            )
            Text(
                text = statusLabel,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium,
                color = if (isArmedOrSynced) activeColor else inactiveColor,
                fontSize = 12.sp
            )
        }
    }
}
