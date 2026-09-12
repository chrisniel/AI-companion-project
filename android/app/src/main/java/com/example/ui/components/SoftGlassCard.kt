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
import com.example.domain.model.EffectsLevel
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
        borderWidth != null -> borderWidth
        else -> SoftTheme.tokens.borders.hairline
    }

    val finalBorderBrush = when {
        border != null -> border.brush
        borderBrush != null -> borderBrush
        else -> Brush.horizontalGradient(listOf(SoftTheme.colors.borderSubtle, SoftTheme.colors.borderSubtle))
    }

    val finalElevation = if (isSelected) {
        SoftTheme.tokens.elevations.subtle
    } else {
        elevation
    }

    val isOled = SoftTheme.colors.isOled
    val isLightweight = SoftTheme.tokens.effectsLevel == EffectsLevel.REDUCED

    val neumorphicModifier = when {
        isOled -> Modifier
        isSelected -> Modifier.softNeumorphicInset(
            shape = shape,
            isDark = isDark,
            depth = 3.dp,
            isLightweight = isLightweight
        )
        else -> Modifier.softNeumorphicRaised(
            shape = shape,
            isDark = isDark,
            elevation = finalElevation,
            isLightweight = isLightweight
        )
    }

    val cardBg = when {
        isOled -> Color(0xFF000000)
        isLightweight && isSelected -> SoftTheme.colors.surfacePressed
        else -> actualBackgroundColor
    }

    val borderModifier = if (finalBorderWidth > 0.dp) {
        Modifier.border(width = finalBorderWidth, brush = finalBorderBrush, shape = shape)
    } else {
        Modifier
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .then(neumorphicModifier)
            .clip(shape)
            .background(cardBg, shape)
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
    val isOled = SoftTheme.colors.isOled
    val isLightweight = SoftTheme.tokens.effectsLevel == EffectsLevel.REDUCED

    val animatedElevation by animateDpAsState(
        targetValue = when {
            !enabled || isOled -> SoftTheme.tokens.elevations.none
            isPressed -> SoftTheme.tokens.elevations.none
            isSelected -> SoftTheme.tokens.elevations.subtle
            else -> elevation
        },
        label = "card_elevation"
    )

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) 0.985f else 1f,
        label = "card_scale"
    )

    val borderWidth = SoftTheme.tokens.borders.hairline

    val surfaceColor = when {
        !enabled -> if (isOled) Color(0xFF000000).copy(alpha = 0.5f) else SoftTheme.colors.surface.copy(alpha = 0.5f)
        isOled -> if (isPressed) Color(0xFF18181B) else Color(0xFF000000)
        isLightweight && (isPressed || isSelected) -> SoftTheme.colors.surfacePressed
        else -> backgroundColor
    }

    val neumorphicModifier = when {
        isOled -> Modifier
        isPressed || isSelected -> Modifier.softNeumorphicInset(
            shape = shape,
            isDark = isDark,
            depth = 3.dp,
            isLightweight = isLightweight
        )
        else -> Modifier.softNeumorphicRaised(
            shape = shape,
            isDark = isDark,
            elevation = animatedElevation,
            isLightweight = isLightweight
        )
    }

    val borderModifier = if (borderWidth > 0.dp) {
        Modifier.border(
            width = borderWidth,
            color = SoftTheme.colors.borderSubtle,
            shape = shape
        )
    } else {
        Modifier
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .scale(scale)
            .defaultMinSize(minHeight = 48.dp, minWidth = 48.dp)
            .then(neumorphicModifier)
            .clip(shape)
            .background(surfaceColor, shape)
            .then(borderModifier)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(color = SoftTheme.colors.accentPrimaryColor),
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
    val isOled = SoftTheme.colors.isOled
    val isLightweight = SoftTheme.tokens.effectsLevel == EffectsLevel.REDUCED

    val insetModifier = if (isOled) Modifier else Modifier.softInsetWell(
        shape = shape,
        isDark = SoftTheme.colors.isDark,
        isLightweight = isLightweight
    )

    Box(
        modifier = modifier
            .testTag(testTag)
            .clip(shape)
            .background(if (isOled) Color(0xFF121214) else backgroundColor, shape)
            .border(width = borderWidth, color = borderColor, shape = shape)
            .then(insetModifier),
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
    val isOled = SoftTheme.colors.isOled
    val isLightweight = SoftTheme.tokens.effectsLevel == EffectsLevel.REDUCED

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) 0.985f else 1f,
        label = "well_scale"
    )

    val insetModifier = if (isOled) Modifier else Modifier.softInsetWell(
        shape = shape,
        isDark = SoftTheme.colors.isDark,
        shadowAlpha = if (isPressed) 0.70f else 0.45f,
        isLightweight = isLightweight
    )

    val wellBg = when {
        isOled -> if (isPressed) Color(0xFF18181B) else Color(0xFF121214)
        isPressed -> SoftTheme.colors.surfacePressed
        else -> backgroundColor
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .scale(scale)
            .clip(shape)
            .background(wellBg, shape)
            .border(
                width = borderWidth,
                color = if (isPressed) SoftTheme.colors.accentPrimary.copy(alpha = 0.5f) else borderColor,
                shape = shape
            )
            .then(insetModifier)
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
