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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.InvertColors
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import com.example.domain.model.HealthMetricType
import com.example.domain.model.WellnessInsight
import com.example.ui.theme.SoftTheme

/**
 * WELLNESS INSIGHTS CARD
 *
 * Strict Non-Diagnostic Guidelines:
 * - Uses strictly observational trend wording
 * - Examples: "Your recent sleep duration has been below your weekly average."
 * - Strictly avoids clinical/medical diagnoses
 * - Displays clear informational disclaimer
 */
@Composable
fun WellnessInsightsCard(
    insights: List<WellnessInsight>,
    modifier: Modifier = Modifier
) {
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
            .padding(14.dp)
            .testTag("wellness_insights_card"),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // HEADER
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
                    imageVector = Icons.Default.AutoAwesome,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentBlue,
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = "Wellness Insights",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }

            // Non-Diagnostic Badge
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                    .background(SoftTheme.colors.surfaceWell)
                    .border(
                        width = SoftTheme.tokens.borders.hairline,
                        color = SoftTheme.colors.borderSubtle,
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                    )
                    .padding(horizontal = 8.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Shield,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentCyan,
                    modifier = Modifier.size(10.dp)
                )
                Text(
                    text = "Non-Diagnostic",
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.accentCyan,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 10.sp
                )
            }
        }

        // INSIGHTS LIST
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            insights.forEach { insight ->
                WellnessInsightRow(insight = insight)
            }
        }

        // DISCLAIMER FOOTNOTE (Non-Diagnostic Wording Mandate)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(SoftTheme.colors.surfaceWell.copy(alpha = 0.6f))
                .padding(horizontal = 10.dp, vertical = 8.dp)
        ) {
            Text(
                text = "Notice: Wellness observations reflect behavioral activity trends calculated on-device. They are not medical diagnoses and should not be used for clinical judgment.",
                style = MaterialTheme.typography.labelSmall,
                color = SoftTheme.colors.textMuted,
                fontSize = 10.sp,
                lineHeight = 14.sp
            )
        }
    }
}

@Composable
private fun WellnessInsightRow(
    insight: WellnessInsight,
    modifier: Modifier = Modifier
) {
    val icon = when (insight.metricType) {
        HealthMetricType.HEART_RATE -> Icons.Default.Favorite
        HealthMetricType.SLEEP -> Icons.Default.Bedtime
        HealthMetricType.STEPS -> Icons.AutoMirrored.Filled.DirectionsWalk
        HealthMetricType.ACTIVITY -> Icons.Default.AutoAwesome
        HealthMetricType.BLOOD_OXYGEN -> Icons.Default.InvertColors
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(SoftTheme.colors.surfaceWell)
            .padding(10.dp)
            .testTag("wellness_insight_${insight.id}"),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(SoftTheme.colors.accentBlue.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = SoftTheme.colors.accentBlue,
                modifier = Modifier.size(13.dp)
            )
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = insight.title,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textPrimary,
                    fontSize = 12.sp
                )
                Text(
                    text = insight.timestamp,
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 10.sp
                )
            }

            Text(
                text = insight.description,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textSecondary,
                fontSize = 12.sp,
                lineHeight = 16.sp
            )
        }
    }
}
