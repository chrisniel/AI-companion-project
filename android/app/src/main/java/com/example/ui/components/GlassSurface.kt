package com.example.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.ui.theme.AmbientGlowBlue
import com.example.ui.theme.AmbientGlowCyan
import com.example.ui.theme.AmbientGlowEmber
import com.example.ui.theme.AmbientGlowOcean
import com.example.ui.theme.AmbientGlowViolet
import com.example.ui.theme.SoftTheme

/**
 * Foundational structural surface with restrained soft glass styling:
 * translucent background fill, subtle gradient hairline border, and gentle diffused elevation.
 */
@Composable
fun GlassSurface(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
    elevation: Dp = SoftTheme.tokens.elevations.flat,
    backgroundColor: Color = SoftTheme.colors.surface,
    borderBrush: Brush = SoftTheme.colors.borderGradient,
    borderWidth: Dp = SoftTheme.tokens.borders.hairline,
    testTag: String = "glass_surface",
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier
            .testTag(testTag)
            .shadow(
                elevation = elevation,
                shape = shape,
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .clip(shape)
            .background(backgroundColor, shape)
            .border(width = borderWidth, brush = borderBrush, shape = shape),
        content = content
    )
}

/**
 * NavigationGlassSurface: Mobile-adapted navigation container featuring slightly stronger
 * frosted glass (higher opacity, defined elevation, and specular hairline border).
 */
@Composable
fun NavigationGlassSurface(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(SoftTheme.tokens.corners.lg),
    elevation: Dp = SoftTheme.tokens.elevations.card,
    backgroundColor: Color = SoftTheme.colors.navSurface,
    borderBrush: Brush = SoftTheme.colors.borderGradient,
    borderWidth: Dp = SoftTheme.tokens.borders.hairline,
    testTag: String = "navigation_glass_surface",
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier
            .testTag(testTag)
            .shadow(
                elevation = elevation,
                shape = shape,
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .clip(shape)
            .background(backgroundColor, shape)
            .border(width = borderWidth, brush = borderBrush, shape = shape),
        content = content
    )
}

/**
 * Restrained ambient background canvas providing subtle cyan, blue, and violet
 * luminous depth behind soft glass panels without loud or distracting gradients.
 */
@Composable
fun AmbientGlassBackground(
    modifier: Modifier = Modifier,
    showAuraGlow: Boolean = true,
    primaryGlow: Color? = null,
    secondaryGlow: Color? = null,
    scrimOpacity: Float = 0.20f,
    brightness: Float = 1.0f,
    content: @Composable BoxScope.() -> Unit
) {
    val isDark = SoftTheme.colors.isDark
    val bg = SoftTheme.colors.background

    val topGlow = primaryGlow ?: AmbientGlowCyan
    val midGlow = secondaryGlow ?: (if (isDark) AmbientGlowEmber else AmbientGlowBlue)

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(bg)
    ) {
        if (showAuraGlow) {
            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        this.alpha = brightness.coerceIn(0.5f, 1.5f)
                    }
            ) {
                val width = size.width
                val height = size.height

                if (isDark) {
                    // Dark mode: Signature oceanic cyan + center ember aura
                    // Upper right
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                topGlow,
                                Color.Transparent
                            ),
                            center = Offset(width * 0.85f, height * 0.12f),
                            radius = width * 0.75f
                        ),
                        center = Offset(width * 0.85f, height * 0.12f),
                        radius = width * 0.75f
                    )

                    // Center / Center-Right
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                midGlow,
                                Color.Transparent
                            ),
                            center = Offset(width * 0.65f, height * 0.42f),
                            radius = width * 0.70f
                        ),
                        center = Offset(width * 0.65f, height * 0.42f),
                        radius = width * 0.70f
                    )

                    // Upper left: Deep Oceanic Navy
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                AmbientGlowOcean,
                                Color.Transparent
                            ),
                            center = Offset(width * 0.10f, height * 0.25f),
                            radius = width * 0.60f
                        ),
                        center = Offset(width * 0.10f, height * 0.25f),
                        radius = width * 0.60f
                    )

                    // Lower Left: Deep Violet
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                AmbientGlowViolet,
                                Color.Transparent
                            ),
                            center = Offset(width * 0.20f, height * 0.80f),
                            radius = width * 0.65f
                        ),
                        center = Offset(width * 0.20f, height * 0.80f),
                        radius = width * 0.65f
                    )
                } else {
                    // Light mode: Soft sky cyan & lavender ribbons
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                topGlow,
                                Color.Transparent
                            ),
                            center = Offset(width * 0.85f, height * 0.15f),
                            radius = width * 0.70f
                        ),
                        center = Offset(width * 0.85f, height * 0.15f),
                        radius = width * 0.70f
                    )

                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                midGlow,
                                Color.Transparent
                            ),
                            center = Offset(width * 0.10f, height * 0.45f),
                            radius = width * 0.65f
                        ),
                        center = Offset(width * 0.10f, height * 0.45f),
                        radius = width * 0.65f
                    )

                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                AmbientGlowViolet,
                                Color.Transparent
                            ),
                            center = Offset(width * 0.70f, height * 0.85f),
                            radius = width * 0.60f
                        ),
                        center = Offset(width * 0.70f, height * 0.85f),
                        radius = width * 0.60f
                    )
                }
            }
        }

        // Environmental Scrim / Overlay Layer for Contrast & Readability
        if (scrimOpacity > 0f) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(bg.copy(alpha = scrimOpacity.coerceIn(0f, 1f)))
            )
        }

        content()
    }
}
