package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.ui.theme.SoftTheme

/**
 * PrimaryButton: Prominent tactile call-to-action featuring cyan-blue-violet gradient styling,
 * soft diffused elevation, responsive scale animation, and integrated loading/success states.
 */
@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    isSuccess: Boolean = false,
    leadingIcon: ImageVector? = null,
    trailingIcon: ImageVector? = null,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
    elevation: Dp = SoftTheme.tokens.elevations.card,
    testTag: String = "primary_button"
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled && !isLoading) 0.97f else 1f,
        label = "primary_btn_scale"
    )

    val animatedElevation by animateDpAsState(
        targetValue = when {
            !enabled -> SoftTheme.tokens.elevations.none
            isPressed -> SoftTheme.tokens.elevations.subtle
            else -> elevation
        },
        label = "primary_btn_elevation"
    )

    val backgroundBrush = when {
        !enabled -> Brush.horizontalGradient(
            listOf(
                SoftTheme.colors.textMuted.copy(alpha = 0.35f),
                SoftTheme.colors.textMuted.copy(alpha = 0.35f)
            )
        )
        isSuccess -> Brush.horizontalGradient(
            listOf(
                SoftTheme.colors.statusSuccess,
                SoftTheme.colors.statusSuccess
            )
        )
        else -> SoftTheme.colors.accentGradient
    }

    val contentColor = when {
        isSuccess -> Color.White
        SoftTheme.colors.isDark -> Color(0xFF070B14)
        else -> Color.White
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .scale(scale)
            .defaultMinSize(minWidth = 128.dp, minHeight = 52.dp)
            .minimumInteractiveComponentSize()
            .shadow(
                elevation = animatedElevation,
                shape = shape,
                ambientColor = if (enabled) SoftTheme.colors.accentBlue.copy(alpha = 0.40f) else Color.Transparent,
                spotColor = if (enabled) SoftTheme.colors.accentBlue.copy(alpha = 0.30f) else Color.Transparent
            )
            .clip(shape)
            .background(backgroundBrush, shape)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(color = if (SoftTheme.colors.isDark) Color.Black.copy(alpha = 0.2f) else Color.White.copy(alpha = 0.3f)),
                enabled = enabled && !isLoading,
                role = Role.Button,
                onClick = onClick
            )
            .padding(horizontal = SoftTheme.spacing.xl, vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier
                    .size(20.dp)
                    .testTag("${testTag}_loader"),
                color = contentColor,
                strokeWidth = 2.dp
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                if (isSuccess) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = "Success",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.sm))
                } else if (leadingIcon != null) {
                    Icon(
                        imageVector = leadingIcon,
                        contentDescription = null,
                        tint = contentColor,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.sm))
                }

                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge,
                    color = contentColor
                )

                if (trailingIcon != null && !isSuccess) {
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.sm))
                    Icon(
                        imageVector = trailingIcon,
                        contentDescription = null,
                        tint = contentColor,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }
}

/**
 * SecondaryButton: Frosted glass button with subtle translucent backdrop,
 * hairline specular border, and high-contrast readable typography.
 */
@Composable
fun SecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    leadingIcon: ImageVector? = null,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
    testTag: String = "secondary_button"
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled && !isLoading) 0.97f else 1f,
        label = "secondary_btn_scale"
    )

    val surfaceColor = when {
        !enabled -> SoftTheme.colors.surface.copy(alpha = 0.4f)
        isPressed -> SoftTheme.colors.surfacePressed
        else -> SoftTheme.colors.surface
    }

    val textColor = when {
        !enabled -> SoftTheme.colors.textMuted
        else -> SoftTheme.colors.textPrimary
    }

    val borderBrush = when {
        !enabled -> Brush.horizontalGradient(listOf(SoftTheme.colors.borderSubtle, SoftTheme.colors.borderSubtle))
        isPressed -> SoftTheme.colors.accentGradient
        else -> SoftTheme.colors.borderGradient
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .scale(scale)
            .defaultMinSize(minWidth = 100.dp, minHeight = 52.dp)
            .minimumInteractiveComponentSize()
            .shadow(
                elevation = if (enabled) SoftTheme.tokens.elevations.subtle else SoftTheme.tokens.elevations.none,
                shape = shape,
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .clip(shape)
            .background(surfaceColor, shape)
            .border(width = SoftTheme.tokens.borders.thin, brush = borderBrush, shape = shape)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(color = SoftTheme.colors.accentCyan),
                enabled = enabled && !isLoading,
                role = Role.Button,
                onClick = onClick
            )
            .padding(horizontal = SoftTheme.spacing.lg, vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = SoftTheme.colors.accentBlue,
                strokeWidth = 2.dp
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                if (leadingIcon != null) {
                    Icon(
                        imageVector = leadingIcon,
                        contentDescription = null,
                        tint = textColor,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.sm))
                }
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge,
                    color = textColor
                )
            }
        }
    }
}

/**
 * NeumorphicButton: Dual-highlight tactile button delivering soft raised depth
 * in default state and recessed/inset tactile feedback upon interaction.
 */
@Composable
fun NeumorphicButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isPressedSimulated: Boolean = false,
    icon: ImageVector? = null,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
    testTag: String = "neumorphic_button"
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isRealPressed by interactionSource.collectIsPressedAsState()
    val isPressed = isRealPressed || isPressedSimulated

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) 0.96f else 1f,
        label = "neu_scale"
    )

    val elevation by animateDpAsState(
        targetValue = when {
            !enabled -> SoftTheme.tokens.elevations.none
            isPressed -> SoftTheme.tokens.elevations.flat
            else -> SoftTheme.tokens.elevations.card
        },
        label = "neu_elevation"
    )

    val surfaceColor = when {
        !enabled -> SoftTheme.colors.surface.copy(alpha = 0.5f)
        isPressed -> SoftTheme.colors.surfacePressed
        else -> SoftTheme.colors.surfaceElevated
    }

    val borderBrush = when {
        !enabled -> Brush.horizontalGradient(listOf(SoftTheme.colors.borderSubtle, SoftTheme.colors.borderSubtle))
        isPressed -> Brush.horizontalGradient(listOf(SoftTheme.colors.borderSubtle, SoftTheme.colors.border))
        else -> SoftTheme.colors.borderGradient
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .scale(scale)
            .defaultMinSize(minWidth = 110.dp, minHeight = 52.dp)
            .minimumInteractiveComponentSize()
            .shadow(
                elevation = elevation,
                shape = shape,
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .clip(shape)
            .background(surfaceColor, shape)
            .border(width = SoftTheme.tokens.borders.thin, brush = borderBrush, shape = shape)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(color = SoftTheme.colors.accentCyan),
                enabled = enabled,
                role = Role.Button,
                onClick = onClick
            )
            .padding(horizontal = SoftTheme.spacing.lg, vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            if (icon != null) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = if (enabled) SoftTheme.colors.textPrimary else SoftTheme.colors.textMuted,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(SoftTheme.spacing.sm))
            }
            Text(
                text = text,
                style = MaterialTheme.typography.labelLarge,
                color = if (enabled) SoftTheme.colors.textPrimary else SoftTheme.colors.textMuted
            )
        }
    }
}

/**
 * IconButton: Circular or rounded tactile glass button with accessible
 * 48dp touch target, semantic content descriptions, and optional status dot.
 */
@Composable
fun SoftIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isSelected: Boolean = false,
    hasBadge: Boolean = false,
    shape: Shape = CircleShape,
    testTag: String = "soft_icon_button"
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) 0.92f else 1f,
        label = "icon_btn_scale"
    )

    val surfaceColor = when {
        !enabled -> SoftTheme.colors.surface.copy(alpha = 0.4f)
        isSelected -> SoftTheme.colors.surfaceElevated
        isPressed -> SoftTheme.colors.surfacePressed
        else -> SoftTheme.colors.surface
    }

    val iconTint = when {
        !enabled -> SoftTheme.colors.textMuted
        isSelected -> SoftTheme.colors.accentBlue
        else -> SoftTheme.colors.textPrimary
    }

    val borderBrush = when {
        isSelected -> SoftTheme.colors.accentGradient
        isPressed -> SoftTheme.colors.accentGradient
        else -> SoftTheme.colors.borderGradient
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .scale(scale)
            .size(48.dp)
            .minimumInteractiveComponentSize()
            .shadow(
                elevation = if (enabled) SoftTheme.tokens.elevations.subtle else SoftTheme.tokens.elevations.none,
                shape = shape,
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .clip(shape)
            .background(surfaceColor, shape)
            .border(width = SoftTheme.tokens.borders.hairline, brush = borderBrush, shape = shape)
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(color = SoftTheme.colors.accentCyan),
                enabled = enabled,
                role = Role.Button,
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = iconTint,
            modifier = Modifier.size(22.dp)
        )

        if (hasBadge) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .align(Alignment.TopEnd)
                    .offset(x = (-8).dp, y = 8.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.accentCyan)
                    .border(1.dp, SoftTheme.colors.surfaceElevated, CircleShape)
            )
        }
    }
}

/**
 * IconButton alias for SoftIconButton fulfilling the requested composable name.
 */
@Composable
fun IconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isSelected: Boolean = false,
    hasBadge: Boolean = false,
    shape: Shape = CircleShape,
    testTag: String = "icon_button"
) {
    SoftIconButton(
        icon = icon,
        contentDescription = contentDescription,
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        isSelected = isSelected,
        hasBadge = hasBadge,
        shape = shape,
        testTag = testTag
    )
}

/**
 * SoftGlassButton: Styled secondary glass button with frosted surface,
 * subtle tactile depth, and accessible touch target.
 */
@Composable
fun SoftGlassButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    leadingIcon: ImageVector? = null,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
    testTag: String = "soft_glass_button"
) {
    SecondaryButton(
        text = text,
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        isLoading = isLoading,
        leadingIcon = leadingIcon,
        shape = shape,
        testTag = testTag
    )
}

