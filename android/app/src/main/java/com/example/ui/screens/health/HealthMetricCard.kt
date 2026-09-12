package com.example.ui.screens.health

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.InvertColors
import androidx.compose.material.icons.filled.SensorsOff
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.HealthDataAvailability
import com.example.domain.model.HealthMetric
import com.example.domain.model.HealthMetricType
import com.example.ui.components.SoftGlassCard
import com.example.ui.theme.SoftTheme

/**
 * HEALTH METRIC CARD
 *
 * Supports metrics:
 * - Heart Rate
 * - Sleep
 * - Steps
 * - Activity
 * - Blood Oxygen (SpO2)
 *
 * Supports availability states:
 * - available
 * - unavailable
 * - stale
 * - unsupported
 * - not synchronized
 *
 * CRITICAL DIRECTIVE:
 * Never display fake zero values for unavailable health data.
 * For example: "No SpO2 data available" rather than "SpO2: 0%"
 */
@Composable
fun HealthMetricCard(
    metric: HealthMetric,
    modifier: Modifier = Modifier
) {
    val metricIcon = getMetricIcon(metric.type)
    val accentColor = getMetricAccentColor(metric.type)

    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("health_metric_${metric.type.name.lowercase()}")
            .semantics {
                this.contentDescription = if (metric.availability == HealthDataAvailability.AVAILABLE) {
                    "${metric.type.displayName}: ${metric.value} ${metric.unit.orEmpty()}, ${metric.availability.displayName}"
                } else {
                    "${metric.type.displayName}: ${metric.availability.displayName}. ${metric.unavailableMessage ?: "No data recorded, not zero."}"
                }
            },
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
        // TOP ROW: ICON + TITLE + AVAILABILITY BADGE
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(accentColor.copy(alpha = 0.14f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = metricIcon,
                        contentDescription = null,
                        tint = accentColor,
                        modifier = Modifier.size(15.dp)
                    )
                }

                Text(
                    text = metric.type.displayName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }

            // Availability Badge
            AvailabilityStatusBadge(availability = metric.availability)
        }

        // BODY CONTENT BASED ON AVAILABILITY STATE
        when (metric.availability) {
            HealthDataAvailability.AVAILABLE -> {
                AvailableMetricBody(metric = metric, accentColor = accentColor)
            }

            HealthDataAvailability.UNAVAILABLE -> {
                // NEVER DISPLAY FAKE ZERO VALUES!
                UnavailableMetricBody(
                    message = metric.unavailableMessage ?: "No ${metric.type.displayName} data available",
                    subtext = "No readings recorded for the selected time range.",
                    icon = Icons.Default.Info,
                    testTagSuffix = "unavailable"
                )
            }

            HealthDataAvailability.STALE -> {
                StaleMetricBody(metric = metric, accentColor = accentColor)
            }

            HealthDataAvailability.UNSUPPORTED -> {
                // NEVER DISPLAY FAKE ZERO VALUES!
                UnavailableMetricBody(
                    message = metric.unavailableMessage ?: "Sensor not supported by current wearable model",
                    subtext = "This biometric metric requires additional wearable hardware capabilities.",
                    icon = Icons.Default.SensorsOff,
                    testTagSuffix = "unsupported"
                )
            }

            HealthDataAvailability.NOT_SYNCHRONIZED -> {
                // NEVER DISPLAY FAKE ZERO VALUES!
                UnavailableMetricBody(
                    message = metric.unavailableMessage ?: "Awaiting sync from Health Connect",
                    subtext = "Pending data exchange between upstream provider and local store.",
                    icon = Icons.Default.Sync,
                    testTagSuffix = "not_synced"
                )
            }
        }
    }
    }
}

/**
 * Normal Available State Display
 */
@Composable
private fun AvailableMetricBody(
    metric: HealthMetric,
    accentColor: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = metric.value.orEmpty(),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textPrimary,
                fontSize = 28.sp
            )
            if (!metric.unit.isNullOrEmpty()) {
                Text(
                    text = metric.unit,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary,
                    modifier = Modifier.padding(bottom = 3.dp)
                )
            }
        }

        // Progress bar if present
        if (metric.progressRatio != null) {
            LinearProgressIndicator(
                progress = { metric.progressRatio.coerceIn(0f, 1f) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(5.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = accentColor,
                trackColor = SoftTheme.colors.surfaceWell
            )
        }

        // Subtext and timestamp
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = metric.secondaryText.orEmpty(),
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textSecondary,
                fontSize = 11.sp
            )

            metric.lastRecordedText?.let { lastRecorded ->
                Text(
                    text = lastRecorded,
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 10.sp
                )
            }
        }
    }
}

/**
 * Stale State Display: Shows last known data but clearly indicates stale sync
 */
@Composable
private fun StaleMetricBody(
    metric: HealthMetric,
    accentColor: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = metric.value.orEmpty(),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textSecondary.copy(alpha = 0.8f),
                fontSize = 26.sp
            )
            if (!metric.unit.isNullOrEmpty()) {
                Text(
                    text = metric.unit,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Normal,
                    color = SoftTheme.colors.textMuted,
                    modifier = Modifier.padding(bottom = 3.dp)
                )
            }
        }

        // Warning banner
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(6.dp))
                .background(Color(0xFFE5A93C).copy(alpha = 0.12f))
                .padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                imageVector = Icons.Default.WarningAmber,
                contentDescription = null,
                tint = Color(0xFFE5A93C),
                modifier = Modifier.size(14.dp)
            )
            Text(
                text = metric.unavailableMessage ?: "Stale telemetry: sync delayed",
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFFE5A93C),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium
            )
        }

        // Subtext and timestamp
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = metric.secondaryText.orEmpty(),
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textMuted,
                fontSize = 10.sp
            )

            metric.lastRecordedText?.let { lastRecorded ->
                Text(
                    text = lastRecorded,
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 10.sp
                )
            }
        }
    }
}

/**
 * Notice box for UNAVAILABLE, UNSUPPORTED, and NOT_SYNCHRONIZED states.
 * Guarantees zero fake values are displayed.
 */
@Composable
private fun UnavailableMetricBody(
    message: String,
    subtext: String,
    icon: ImageVector,
    testTagSuffix: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(SoftTheme.colors.surfaceWell)
            .padding(12.dp)
            .testTag("health_unavailable_notice_$testTagSuffix"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(SoftTheme.colors.borderSubtle.copy(alpha = 0.3f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = SoftTheme.colors.textSecondary,
                modifier = Modifier.size(16.dp)
            )
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = SoftTheme.colors.textPrimary,
                fontSize = 13.sp
            )
            Text(
                text = subtext,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textMuted,
                fontSize = 11.sp
            )
        }
    }
}

/**
 * Availability state indicator pill.
 */
@Composable
private fun AvailabilityStatusBadge(
    availability: HealthDataAvailability,
    modifier: Modifier = Modifier
) {
    val (color, label) = when (availability) {
        HealthDataAvailability.AVAILABLE -> SoftTheme.colors.statusSuccess to "Available"
        HealthDataAvailability.UNAVAILABLE -> SoftTheme.colors.textMuted to "Unavailable"
        HealthDataAvailability.STALE -> Color(0xFFE5A93C) to "Stale (sync delayed)"
        HealthDataAvailability.UNSUPPORTED -> SoftTheme.colors.textSecondary to "Unsupported"
        HealthDataAvailability.NOT_SYNCHRONIZED -> SoftTheme.colors.accentBlue to "Not Synchronized"
    }

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(color.copy(alpha = 0.12f))
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = color.copy(alpha = 0.3f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        Box(
            modifier = Modifier
                .size(5.dp)
                .clip(CircleShape)
                .background(color)
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = color,
            fontWeight = FontWeight.SemiBold,
            fontSize = 10.sp
        )
    }
}

private fun getMetricIcon(type: HealthMetricType): ImageVector = when (type) {
    HealthMetricType.HEART_RATE -> Icons.Default.Favorite
    HealthMetricType.SLEEP -> Icons.Default.Bedtime
    HealthMetricType.STEPS -> Icons.AutoMirrored.Filled.DirectionsWalk
    HealthMetricType.ACTIVITY -> Icons.Default.FitnessCenter
    HealthMetricType.BLOOD_OXYGEN -> Icons.Default.InvertColors
}

private fun getMetricAccentColor(type: HealthMetricType): Color = when (type) {
    HealthMetricType.HEART_RATE -> Color(0xFFE05263)
    HealthMetricType.SLEEP -> Color(0xFF7C6FF0)
    HealthMetricType.STEPS -> Color(0xFF38B2AC)
    HealthMetricType.ACTIVITY -> Color(0xFFE5983C)
    HealthMetricType.BLOOD_OXYGEN -> Color(0xFF3182CE)
}
