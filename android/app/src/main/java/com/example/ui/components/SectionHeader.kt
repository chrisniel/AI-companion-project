package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Reusable SectionHeader component from the Soft Glass design system.
 * Displays category title, optional subtitle/caption, telemetry badge,
 * and optional actionable text/icon with minimum touch target size.
 */
@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    badgeText: String? = null,
    actionText: String? = null,
    actionIcon: ImageVector? = null,
    onActionClick: (() -> Unit)? = null,
    testTag: String = "section_header"
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .testTag(testTag)
            .padding(vertical = SoftTheme.spacing.sm),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier.weight(1f, fill = false)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title.uppercase(),
                    style = MaterialTheme.typography.titleSmall,
                    color = SoftTheme.colors.accentBlue
                )

                if (badgeText != null) {
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.sm))
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.xs))
                            .background(SoftTheme.colors.surfacePressed)
                            .padding(horizontal = SoftTheme.spacing.xs, vertical = 2.dp)
                    ) {
                        Text(
                            text = badgeText,
                            style = MonospaceTelemetry,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }
            }

            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }
        }

        if (actionText != null || actionIcon != null) {
            val interactionSource = remember { MutableInteractionSource() }
            Row(
                modifier = Modifier
                    .minimumInteractiveComponentSize()
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                    .clickable(
                        interactionSource = interactionSource,
                        indication = ripple(color = SoftTheme.colors.accentCyan),
                        enabled = onActionClick != null,
                        role = Role.Button,
                        onClick = { onActionClick?.invoke() }
                    )
                    .padding(horizontal = SoftTheme.spacing.sm, vertical = SoftTheme.spacing.xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (actionText != null) {
                    Text(
                        text = actionText,
                        style = MaterialTheme.typography.labelMedium,
                        color = SoftTheme.colors.accentCyan
                    )
                }
                if (actionIcon != null) {
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))
                    Icon(
                        imageVector = actionIcon,
                        contentDescription = actionText,
                        tint = SoftTheme.colors.accentCyan,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}

/**
 * SoftSectionHeader alias for SectionHeader.
 */
@Composable
fun SoftSectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    badgeText: String? = null,
    actionText: String? = null,
    actionIcon: ImageVector? = null,
    onActionClick: (() -> Unit)? = null,
    testTag: String = "soft_section_header"
) {
    SectionHeader(
        title = title,
        modifier = modifier,
        subtitle = subtitle,
        badgeText = badgeText,
        actionText = actionText,
        actionIcon = actionIcon,
        onActionClick = onActionClick,
        testTag = testTag
    )
}
