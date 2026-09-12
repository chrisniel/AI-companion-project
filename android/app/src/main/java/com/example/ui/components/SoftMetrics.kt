package com.example.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.StatusSeverity
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * MetricCard: Soft glass card displaying a primary metric (e.g. Model Latency, Inference Speed, VRAM).
 * Includes title, value, unit, trend percentage badge, and optional animated progress bar.
 */
@Composable
fun MetricCard(
    title: String,
    value: String,
    modifier: Modifier = Modifier,
    unit: String = "",
    subtitle: String? = null,
    progress: Float? = null,
    trendPercentage: Float? = null,
    isPositiveTrend: Boolean? = true,
    severity: StatusSeverity = StatusSeverity.Normal,
    testTag: String = "metric_card"
) {
    SoftGlassCard(
        modifier = modifier.testTag(testTag),
        elevation = SoftTheme.tokens.elevations.card
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg)
        ) {
            // Header: Title + Trend
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelMedium,
                    color = SoftTheme.colors.textSecondary
                )

                if (trendPercentage != null && isPositiveTrend != null) {
                    val isGood = isPositiveTrend
                    val trendColor = if (isGood) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning
                    val icon = if (isGood) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward

                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(trendColor.copy(alpha = 0.15f))
                            .padding(horizontal = SoftTheme.spacing.xs, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = icon,
                            contentDescription = null,
                            tint = trendColor,
                            modifier = Modifier.size(12.dp)
                        )
                        Spacer(modifier = Modifier.width(2.dp))
                        Text(
                            text = "${if (trendPercentage > 0) "+" else ""}${trendPercentage}%",
                            style = MonospaceTelemetry.copy(fontSize = 10.sp),
                            color = trendColor
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.sm))

            // Value + Unit
            Row(
                verticalAlignment = Alignment.Bottom
            ) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                if (unit.isNotEmpty()) {
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))
                    Text(
                        text = unit,
                        style = MaterialTheme.typography.titleSmall,
                        color = SoftTheme.colors.textMuted,
                        modifier = Modifier.padding(bottom = 4.dp)
                    )
                }
            }

            if (subtitle != null) {
                Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textMuted
                )
            }

            if (progress != null) {
                Spacer(modifier = Modifier.height(SoftTheme.spacing.md))
                val animatedProgress by animateFloatAsState(
                    targetValue = progress.coerceIn(0f, 1f),
                    animationSpec = tween(durationMillis = 800, easing = FastOutSlowInEasing),
                    label = "metric_progress"
                )

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(SoftTheme.colors.surfacePressed)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(animatedProgress)
                            .height(6.dp)
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.accentGradient)
                    )
                }
            }
        }
    }
}

/**
 * CircularMetric: Tactile soft glass circular gauge (inspired by the PC/mobile visual identity reference).
 * Renders a circular track with smooth animated cyan-violet gradient stroke and a raised central milky disc.
 */
@Composable
fun CircularMetric(
    percentage: Float,
    label: String,
    modifier: Modifier = Modifier,
    size: Dp = 176.dp,
    strokeWidth: Dp = 14.dp,
    subtitle: String? = null,
    testTag: String = "circular_metric"
) {
    val animatedProgress by animateFloatAsState(
        targetValue = percentage.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 1000, easing = FastOutSlowInEasing),
        label = "circular_progress"
    )

    val trackColor = SoftTheme.colors.surfacePressed
    val accentBrush = SoftTheme.colors.accentGradient

    Box(
        modifier = modifier
            .testTag(testTag)
            .size(size),
        contentAlignment = Alignment.Center
    ) {
        // Outer arc drawing
        Canvas(modifier = Modifier.size(size)) {
            val strokePx = strokeWidth.toPx()
            val arcSize = Size(this.size.width - strokePx, this.size.height - strokePx)
            val topLeft = Offset(strokePx / 2f, strokePx / 2f)

            // Background Track
            drawArc(
                color = trackColor,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokePx, cap = StrokeCap.Round)
            )

            // Progress Arc
            drawArc(
                brush = accentBrush,
                startAngle = -90f,
                sweepAngle = 360f * animatedProgress,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokePx, cap = StrokeCap.Round)
            )
        }

        // Tactile Inner Disc with dual-shadow depth
        val innerDiscSize = size - (strokeWidth * 3)
        Box(
            modifier = Modifier
                .size(innerDiscSize)
                .shadow(
                    elevation = SoftTheme.tokens.elevations.card,
                    shape = CircleShape,
                    ambientColor = SoftTheme.colors.shadow,
                    spotColor = SoftTheme.colors.specularHighlight
                )
                .clip(CircleShape)
                .background(SoftTheme.colors.surfaceElevated, CircleShape)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    brush = SoftTheme.colors.borderGradient,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = "${(animatedProgress * 100).toInt()}%",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                if (label.isNotEmpty()) {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }
                if (subtitle != null) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textMuted
                    )
                }
            }
        }
    }
}
