package com.example.ui.screens.health

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Hub
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Sensors
import androidx.compose.material.icons.filled.Watch
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.HealthSourceStatus
import com.example.ui.components.SoftGlassCard
import com.example.ui.theme.SoftTheme

/**
 * SOURCE STATUS CARD
 *
 * Explicitly displays:
 * Health Connect
 * Mock Connected
 *
 * Source
 * FitCloudPro
 *
 * Current Intended Pipeline:
 * Smartwatch → FitCloudPro → Health Connect → Android App → Local AI Core
 *
 * While keeping the source architecture completely replaceable.
 */
@Composable
fun HealthSourceCard(
    sourceStatus: HealthSourceStatus,
    isSyncing: Boolean,
    onSyncClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isPipelineExpanded by remember { mutableStateOf(false) }

    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("health_source_status_card"),
        elevation = SoftTheme.tokens.elevations.card,
        containerColor = SoftTheme.colors.surfaceElevated,
        shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
        // TOP HEADER: TITLE + REFRESH BUTTON
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Sensors,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentCyan,
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = "Telemetry Ingestion Pipeline",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }

            // Sync button
            IconButton(
                onClick = onSyncClick,
                enabled = !isSyncing,
                modifier = Modifier
                    .size(28.dp)
                    .testTag("health_sync_button")
            ) {
                if (isSyncing) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = SoftTheme.colors.accentBlue
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = "Sync Health Connect",
                        tint = SoftTheme.colors.textSecondary,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }

        // REQUIRED TWO-COLUMN / DUAL-SECTION DISPLAY:
        // Section 1: Health Connect / Mock Connected
        // Section 2: Source / FitCloudPro
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(SoftTheme.colors.surfaceWell)
                .padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // HEALTH CONNECT / MOCK CONNECTED
            Column(
                modifier = Modifier
                    .weight(1f)
                    .testTag("health_connect_status_block"),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = "Health Connect",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 11.sp
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(SoftTheme.colors.statusSuccess)
                    )
                    Text(
                        text = sourceStatus.providerStatus,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 14.sp
                    )
                }
            }

            // VERTICAL SEPARATOR
            Box(
                modifier = Modifier
                    .height(28.dp)
                    .width(SoftTheme.tokens.borders.hairline)
                    .background(SoftTheme.colors.borderSubtle)
            )

            Spacer(modifier = Modifier.width(14.dp))

            // SOURCE / FITCLOUDPRO
            Column(
                modifier = Modifier
                    .weight(1f)
                    .testTag("upstream_source_status_block"),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = "Source",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 11.sp
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Watch,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = sourceStatus.upstreamSource,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 14.sp
                    )
                }
            }
        }

        // PIPELINE DETAILS ACCORDION
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(SoftTheme.colors.surfaceElevated)
                .clickable { isPipelineExpanded = !isPipelineExpanded }
                .padding(vertical = 4.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Hub,
                        contentDescription = null,
                        tint = SoftTheme.colors.textMuted,
                        modifier = Modifier.size(13.dp)
                    )
                    Text(
                        text = "Replaceable Pipeline Architecture",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 11.sp
                    )
                }

                Icon(
                    imageVector = if (isPipelineExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = if (isPipelineExpanded) "Collapse" else "Expand",
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(16.dp)
                )
            }

            AnimatedVisibility(visible = isPipelineExpanded) {
                Column(
                    modifier = Modifier
                        .padding(top = 8.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(SoftTheme.colors.surfaceWell)
                        .padding(10.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = "Intended Ingestion Flow:",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.accentCyan,
                        fontSize = 10.sp
                    )
                    Text(
                        text = sourceStatus.pipelineSummary,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 11.sp,
                        lineHeight = 16.sp
                    )
                    Text(
                        text = "• Provider decoupled via HealthDataProvider interface\n• Zero SDK lock-in; ready for native Health Connect Client\n• Last heartbeat: ${sourceStatus.lastSyncTime}",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textMuted,
                        fontSize = 10.sp,
                        lineHeight = 14.sp
                    )
                }
            }
        }
    }
    }
}
