package com.example.ui.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.ui.theme.SoftTheme

/**
 * Reusable SoftGlassCard combining soft neumorphic elevation and restrained glassmorphism.
 * In Dark mode, standard content cards rely on tonal surface elevation without harsh persistent outline strokes.
 * In Light mode, cards have a delicate translucent surface and subtle hairline edge.
 */
@Composable
fun SoftGlassCard(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.lg),
    elevation: Dp = SoftTheme.tokens.elevations.card,
    backgroundColor: Color = SoftTheme.colors.surface,
    containerColor: Color? = null,
    border: BorderStroke? = null,
    borderBrush: Brush? = null,
    borderWidth: Dp? = null,
    isSelected: Boolean = false,
    contentAlignment: Alignment = Alignment.TopStart,
    testTag: String = "soft_glass_card",
    content: @Composable BoxScope.() -> Unit
) {
    val actualBackgroundColor = containerColor ?: backgroundColor
    val isDark = SoftTheme.colors.isDark

    val finalBorderWidth = when {
        border != null -> border.width
        isSelected -> SoftTheme.tokens.borders.medium
        borderWidth != null -> borderWidth
        isDark -> 0.dp
        else -> SoftTheme.tokens.borders.hairline
    }

    val finalBorderBrush = when {
        border != null -> border.brush
        isSelected -> SoftTheme.colors.accentGradient
        borderBrush != null -> borderBrush
        else -> SoftTheme.colors.borderGradient
    }

    val finalElevation = if (isSelected) {
        SoftTheme.tokens.elevations.elevated
    } else {
        elevation
    }

    val borderModifier = if (finalBorderWidth > 0.dp) {
        Modifier.border(width = finalBorderWidth, brush = finalBorderBrush, shape = shape)
    } else {
        Modifier
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .shadow(
                elevation = finalElevation,
                shape = shape,
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .softNeumorphicRaised(
                shape = shape,
                isDark = isDark,
                elevation = finalElevation
            )
            .clip(shape)
            .background(actualBackgroundColor, shape)
            .then(borderModifier),
        contentAlignment = contentAlignment,
        content = content
    )
}

/**
 * Interactive SoftGlassCard supporting tactile pressed animations, ripple feedback,
 * accessible selection states, and minimum touch target size.
 */
@Composable
fun InteractiveSoftGlassCard(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isSelected: Boolean = false,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.lg),
    elevation: Dp = SoftTheme.tokens.elevations.card,
    backgroundColor: Color = SoftTheme.colors.surface,
    contentAlignment: Alignment = Alignment.Center,
    testTag: String = "interactive_soft_glass_card",
    content: @Composable BoxScope.() -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val isDark = SoftTheme.colors.isDark

    val animatedElevation by animateDpAsState(
        targetValue = when {
            !enabled -> SoftTheme.tokens.elevations.none
            isPressed -> SoftTheme.tokens.elevations.subtle
            isSelected -> SoftTheme.tokens.elevations.elevated
            else -> elevation
        },
        label = "card_elevation"
    )

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) 0.985f else 1f,
        label = "card_scale"
    )

    val borderBrush = when {
        !enabled -> Brush.horizontalGradient(listOf(SoftTheme.colors.borderSubtle, SoftTheme.colors.borderSubtle))
        isSelected -> SoftTheme.colors.accentGradient
        isPressed -> SoftTheme.colors.accentGradient
        else -> SoftTheme.colors.borderGradient
    }

    val borderWidth = when {
        isSelected -> SoftTheme.tokens.borders.medium
        isPressed -> SoftTheme.tokens.borders.thin
        isDark -> 0.dp
        else -> SoftTheme.tokens.borders.hairline
    }

    val surfaceColor = when {
        !enabled -> SoftTheme.colors.surface.copy(alpha = 0.5f)
        isPressed -> SoftTheme.colors.surfacePressed
        isSelected -> SoftTheme.colors.surfaceElevated
        else -> backgroundColor
    }

    val borderModifier = if (borderWidth > 0.dp) {
        Modifier.border(width = borderWidth, brush = borderBrush, shape = shape)
    } else {
        Modifier
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .scale(scale)
            .defaultMinSize(minHeight = 48.dp, minWidth = 48.dp)
            .shadow(
                elevation = animatedElevation,
                shape = shape,
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .softNeumorphicRaised(
                shape = shape,
                isDark = isDark,
                elevation = animatedElevation
            )
            .clip(shape)
            .background(surfaceColor, shape)
            .then(borderModifier)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(color = SoftTheme.colors.accentCyan),
                enabled = enabled,
                role = Role.Button,
                onClick = onClick
            ),
        contentAlignment = contentAlignment,
        content = content
    )
}

/**
 * SoftWell: Sunken / debossed neumorphic surface for nested metrics, stat cards,
 * and secondary containers as seen in the Local AI Core desktop design.
 */
@Composable
fun SoftWell(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
    backgroundColor: Color = SoftTheme.colors.surfaceWell,
    borderColor: Color = SoftTheme.colors.borderSubtle,
    borderWidth: Dp = SoftTheme.tokens.borders.hairline,
    contentAlignment: Alignment = Alignment.TopStart,
    testTag: String = "soft_well",
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier
            .testTag(testTag)
            .clip(shape)
            .background(backgroundColor, shape)
            .border(width = borderWidth, color = borderColor, shape = shape)
            .softInsetWell(shape = shape, isDark = SoftTheme.colors.isDark),
        contentAlignment = contentAlignment,
        content = content
    )
}

/**
 * InteractiveSoftWell: Clickable sunken well with subtle press animation and ripple feedback.
 */
@Composable
fun InteractiveSoftWell(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
    backgroundColor: Color = SoftTheme.colors.surfaceWell,
    borderColor: Color = SoftTheme.colors.borderSubtle,
    borderWidth: Dp = SoftTheme.tokens.borders.hairline,
    contentAlignment: Alignment = Alignment.TopStart,
    testTag: String = "interactive_soft_well",
    content: @Composable BoxScope.() -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) 0.985f else 1f,
        label = "well_scale"
    )

    Box(
        modifier = modifier
            .testTag(testTag)
            .scale(scale)
            .clip(shape)
            .background(
                if (isPressed) SoftTheme.colors.surfacePressed else backgroundColor,
                shape
            )
            .border(
                width = borderWidth,
                color = if (isPressed) SoftTheme.colors.accentPrimary.copy(alpha = 0.5f) else borderColor,
                shape = shape
            )
            .softInsetWell(
                shape = shape,
                isDark = SoftTheme.colors.isDark,
                shadowAlpha = if (isPressed) 0.70f else 0.45f
            )
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(color = SoftTheme.colors.accentPrimary),
                enabled = enabled,
                role = Role.Button,
                onClick = onClick
            ),
        contentAlignment = contentAlignment,
        content = content
    )
}
