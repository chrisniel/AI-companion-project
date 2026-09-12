package com.example.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.ui.theme.SoftTheme

/**
 * EmptyState: Reusable soft glass card communicating empty or uninitialized state
 * with an icon glyph, title, helpful explanation, and optional action button.
 */
@Composable
fun SoftEmptyState(
    title: String,
    description: String,
    modifier: Modifier = Modifier,
    icon: ImageVector = Icons.Default.Info,
    actionButtonText: String? = null,
    onActionClick: (() -> Unit)? = null,
    testTag: String = "soft_empty_state"
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag(testTag),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.xxl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.surfacePressed)
                    .border(
                        width = SoftTheme.tokens.borders.hairline,
                        brush = SoftTheme.colors.borderGradient,
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentBlue,
                    modifier = Modifier.size(28.dp)
                )
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.lg))

            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = SoftTheme.colors.textPrimary,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))

            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = SoftTheme.colors.textSecondary,
                textAlign = TextAlign.Center
            )

            if (actionButtonText != null && onActionClick != null) {
                Spacer(modifier = Modifier.height(SoftTheme.spacing.lg))
                PrimaryButton(
                    text = actionButtonText,
                    onClick = onActionClick
                )
            }
        }
    }
}

/**
 * LoadingState: Elegant ambient soft glass loading indicator with a glowing pulse effect
 * and informative status message.
 */
@Composable
fun SoftLoadingState(
    message: String = "Connecting to Local AI Core...",
    modifier: Modifier = Modifier,
    testTag: String = "soft_loading_state"
) {
    val infiniteTransition = rememberInfiniteTransition(label = "loader_pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )

    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag(testTag),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.xxl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier.size(64.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(54.dp)
                        .scale(pulseScale)
                        .clip(CircleShape)
                        .background(SoftTheme.colors.accentCyan.copy(alpha = 0.15f))
                )
                CircularProgressIndicator(
                    modifier = Modifier.size(36.dp),
                    color = SoftTheme.colors.accentBlue,
                    strokeWidth = 3.dp
                )
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.lg))

            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = SoftTheme.colors.textSecondary,
                textAlign = TextAlign.Center
            )
        }
    }
}

/**
 * ErrorState: Soft glass error feedback component with warning/error icon,
 * clear message, and optional retry action button.
 */
@Composable
fun SoftErrorState(
    title: String = "Connection Error",
    message: String,
    modifier: Modifier = Modifier,
    icon: ImageVector = Icons.Default.WarningAmber,
    retryButtonText: String? = "Retry Connection",
    onRetry: (() -> Unit)? = null,
    testTag: String = "soft_error_state"
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag(testTag),
        elevation = SoftTheme.tokens.elevations.card,
        borderBrush = androidx.compose.ui.graphics.SolidColor(SoftTheme.colors.statusError.copy(alpha = 0.45f))
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.xxl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.statusErrorSubtle)
                    .border(
                        width = SoftTheme.tokens.borders.hairline,
                        color = SoftTheme.colors.statusError.copy(alpha = 0.35f),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = SoftTheme.colors.statusError,
                    modifier = Modifier.size(28.dp)
                )
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.md))

            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = SoftTheme.colors.textPrimary,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))

            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = SoftTheme.colors.textSecondary,
                textAlign = TextAlign.Center
            )

            if (retryButtonText != null && onRetry != null) {
                Spacer(modifier = Modifier.height(SoftTheme.spacing.lg))
                PrimaryButton(
                    text = retryButtonText,
                    onClick = onRetry,
                    leadingIcon = Icons.Default.Refresh
                )
            }
        }
    }
}

/**
 * EmptyState alias for SoftEmptyState.
 */
@Composable
fun EmptyState(
    title: String,
    description: String,
    modifier: Modifier = Modifier,
    icon: ImageVector = Icons.Default.Info,
    actionButtonText: String? = null,
    onActionClick: (() -> Unit)? = null,
    testTag: String = "empty_state"
) {
    SoftEmptyState(
        title = title,
        description = description,
        modifier = modifier,
        icon = icon,
        actionButtonText = actionButtonText,
        onActionClick = onActionClick,
        testTag = testTag
    )
}

/**
 * LoadingState alias for SoftLoadingState.
 */
@Composable
fun LoadingState(
    message: String = "Connecting to Local AI Core...",
    modifier: Modifier = Modifier,
    testTag: String = "loading_state"
) {
    SoftLoadingState(
        message = message,
        modifier = modifier,
        testTag = testTag
    )
}

/**
 * ErrorState alias for SoftErrorState.
 */
@Composable
fun ErrorState(
    title: String = "Connection Error",
    message: String,
    modifier: Modifier = Modifier,
    icon: ImageVector = Icons.Default.WarningAmber,
    retryButtonText: String? = "Retry Connection",
    onRetry: (() -> Unit)? = null,
    testTag: String = "error_state"
) {
    SoftErrorState(
        title = title,
        message = message,
        modifier = modifier,
        icon = icon,
        retryButtonText = retryButtonText,
        onRetry = onRetry,
        testTag = testTag
    )
}

