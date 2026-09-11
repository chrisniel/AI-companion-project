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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForwardIos
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.domain.model.StatusSeverity
import com.example.navigation.MoreDestination
import com.example.navigation.MoreDestinations
import com.example.navigation.Routes
import com.example.ui.components.InteractiveSoftGlassCard
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.StatusBadge
import com.example.ui.theme.SoftTheme

/**
 * More Hub screen presenting the secondary navigation destinations:
 * - Schedule
 * - Alarms
 * - Characters
 * - Models
 * - Devices
 * - Memory
 * - Settings
 *
 * Plus developer access to the calibrated Design System catalog.
 */
@Composable
fun MoreScreen(
    onNavigateToRoute: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.md),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
    ) {
        // Logical Navigation Sections
        MoreDestinations.sections.forEach { section ->
            Text(
                text = section.title,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.accentBlue
            )

            section.items.forEach { destination ->
                MoreDestinationCard(
                    destination = destination,
                    onClick = { onNavigateToRoute(destination.route) }
                )
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))
        }

        // Developer tools section
        Text(
            text = "DEVELOPER & DESIGN SYSTEM",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        InteractiveSoftGlassCard(
            onClick = { onNavigateToRoute(Routes.DESIGN_SYSTEM) },
            elevation = SoftTheme.tokens.elevations.subtle,
            contentAlignment = Alignment.CenterStart,
            testTag = "more_item_design_system",
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.md),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md),
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(42.dp)
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Palette,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentCyan,
                            modifier = Modifier.size(24.dp)
                        )
                    }

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Design System Catalog",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Inspect all soft glass cards, gauges, inputs, and states",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }

                StatusBadge(
                    text = "v1.1 Catalog",
                    severity = StatusSeverity.Info,
                    hasDot = false
                )
            }
        }

        Spacer(modifier = Modifier.height(SoftTheme.spacing.lg))
    }
}

@Composable
private fun MoreDestinationCard(
    destination: MoreDestination,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    InteractiveSoftGlassCard(
        onClick = onClick,
        elevation = SoftTheme.tokens.elevations.card,
        contentAlignment = Alignment.CenterStart,
        testTag = destination.testTag,
        modifier = modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.md),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md),
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.md)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = destination.icon,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(24.dp)
                    )
                }

                Column {
                    Text(
                        text = destination.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = destination.subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                if (destination.badgeText != null) {
                    StatusBadge(
                        text = destination.badgeText,
                        severity = StatusSeverity.Normal,
                        hasDot = false
                    )
                }

                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForwardIos,
                    contentDescription = null,
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}
