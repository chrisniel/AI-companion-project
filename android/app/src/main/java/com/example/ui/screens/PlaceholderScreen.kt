package com.example.ui.screens

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
import com.example.ui.components.softBounceOverscroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.domain.model.StatusSeverity
import com.example.ui.components.InteractiveSoftGlassCard
import com.example.ui.components.PrimaryButton
import com.example.ui.components.SecondaryButton
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.StatusBadge
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Clean, production-grade placeholder screen adhering to the Soft Glass Design System.
 * Displays tailored domain information, telemetry tags, and functional mock controls.
 */
@Composable
fun PlaceholderScreen(
    title: String,
    category: String,
    description: String,
    icon: ImageVector,
    statusText: String = "Ready • In-Memory",
    metrics: List<Pair<String, String>> = listOf(
        "Sync State" to "Synchronized",
        "Storage Engine" to "Room SQLite",
        "Compute Node" to "Local NPU"
    ),
    actions: List<String> = listOf("Inspect", "Configure"),
    onActionClick: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .softBounceOverscroll()
            .verticalScroll(scrollState)
            .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.md),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.lg)
    ) {
        // Hero Header Card
        SoftGlassCard(
            modifier = Modifier
                .fillMaxWidth()
                .testTag("placeholder_hero_card"),
            elevation = SoftTheme.tokens.elevations.card
        ) {
            Column(
                modifier = Modifier.padding(SoftTheme.spacing.lg),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
                ) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                                .padding(2.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = icon,
                                contentDescription = null,
                                tint = SoftTheme.colors.accentBlue,
                                modifier = Modifier.size(32.dp)
                            )
                        }

                        Column(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Text(
                                text = category.uppercase(),
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = SoftTheme.colors.accentBlue
                            )
                            Text(
                                text = title,
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = SoftTheme.colors.textPrimary
                            )
                            StatusBadge(
                                text = statusText,
                                severity = StatusSeverity.Success,
                                hasDot = true
                            )
                        }
                    }

                Text(
                    text = description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = SoftTheme.colors.textSecondary,
                    lineHeight = MaterialTheme.typography.bodyMedium.lineHeight
                )
            }
        }

        // Telemetry & Metrics Section
        Text(
            text = "TELEMETRY & SPECIFICATION",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentBlue
        )

        metrics.forEach { (key, value) ->
            InteractiveSoftGlassCard(
                onClick = { onActionClick(key) },
                elevation = SoftTheme.tokens.elevations.subtle,
                contentAlignment = Alignment.CenterStart,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.md),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = key,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = SoftTheme.colors.textPrimary,
                        modifier = Modifier.padding(end = 8.dp)
                    )
                    Text(
                        text = value,
                        style = MonospaceTelemetry,
                        color = SoftTheme.colors.accentCyan,
                        textAlign = TextAlign.End,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                }
            }
        }

        // Contextual Actions
        Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            actions.forEachIndexed { index, action ->
                if (index == 0) {
                    PrimaryButton(
                        text = action,
                        onClick = { onActionClick(action) },
                        leadingIcon = Icons.Default.PlayArrow,
                        modifier = Modifier.weight(1f)
                    )
                } else {
                    SecondaryButton(
                        text = action,
                        onClick = { onActionClick(action) },
                        leadingIcon = Icons.Default.Tune,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}
