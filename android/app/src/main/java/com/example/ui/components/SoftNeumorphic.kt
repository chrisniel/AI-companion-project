package com.example.ui.components

import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.addOutline
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * SoftNeumorphic rendering engine for Jetpack Compose.
 *
 * Simulates directional dual-light neumorphic surfaces without requiring
 * expensive runtime RenderEffect blur shaders, matching the PC web client's
 * Soft Glass visual identity:
 * - Raised surfaces: crisp top-left specular highlight + bottom-right ambient shadow.
 * - Recessed / Inset wells: inward top-left shadow + inward bottom-right specular reflection.
 */

/**
 * Applies a simulated directional dual-shadow to raised surfaces.
 */
fun Modifier.softNeumorphicRaised(
    shape: Shape,
    isDark: Boolean,
    elevation: Dp = 6.dp,
    highlightAlpha: Float = if (isDark) 0.10f else 0.60f,
    shadowAlpha: Float = if (isDark) 0.65f else 0.26f,
    highlightColor: Color = Color.White,
    shadowColor: Color = if (isDark) Color(0xFF000000) else Color(0xFF7F95AF)
): Modifier = this.drawWithCache {
    val highlightPx = 2.dp.toPx()
    val shadowPx = (elevation.toPx() * 0.5f).coerceAtLeast(2.dp.toPx())
    val strokeWidth = 0.75.dp.toPx()

    val specularBrush = Brush.linearGradient(
        colors = listOf(
            highlightColor.copy(alpha = highlightAlpha),
            highlightColor.copy(alpha = highlightAlpha * 0.35f),
            Color.Transparent,
            shadowColor.copy(alpha = shadowAlpha * 0.5f)
        ),
        start = Offset.Zero,
        end = Offset(size.width, size.height)
    )

    onDrawBehind {
        val outline = shape.createOutline(size, layoutDirection, this)

        // Directional Specular Edge (135° angle: soft highlight at top-left, fading naturally)
        drawOutline(
            outline = outline,
            brush = specularBrush,
            style = Stroke(width = strokeWidth)
        )
    }
}

/**
 * Applies a simulated inner / recessed well effect to containers such as
 * SoftWell, search fields, text inputs, and pressed buttons.
 */
fun Modifier.softInsetWell(
    shape: Shape,
    isDark: Boolean,
    depth: Dp = 4.dp,
    shadowAlpha: Float = if (isDark) 0.55f else 0.22f,
    highlightAlpha: Float = if (isDark) 0.05f else 0.70f,
    shadowColor: Color = if (isDark) Color.Black else Color(0xFF8298B3),
    highlightColor: Color = Color.White
): Modifier = this.drawWithContent {
    drawContent()

    val outline = shape.createOutline(size, layoutDirection, this)
    val path = Path().apply { addOutline(outline) }
    val depthPx = depth.toPx()

    clipPath(path) {
        // 1. Inset top inner shadow
        drawRect(
            brush = Brush.verticalGradient(
                colors = listOf(
                    shadowColor.copy(alpha = shadowAlpha),
                    Color.Transparent
                ),
                startY = 0f,
                endY = depthPx
            ),
            topLeft = Offset.Zero,
            size = Size(size.width, depthPx)
        )

        // 2. Inset left inner shadow
        drawRect(
            brush = Brush.horizontalGradient(
                colors = listOf(
                    shadowColor.copy(alpha = shadowAlpha * 0.85f),
                    Color.Transparent
                ),
                startX = 0f,
                endX = depthPx
            ),
            topLeft = Offset.Zero,
            size = Size(depthPx, size.height)
        )

        // 3. Inset bottom inner specular reflection
        drawRect(
            brush = Brush.verticalGradient(
                colors = listOf(
                    Color.Transparent,
                    highlightColor.copy(alpha = highlightAlpha)
                ),
                startY = size.height - depthPx,
                endY = size.height
            ),
            topLeft = Offset(0f, size.height - depthPx),
            size = Size(size.width, depthPx)
        )

        // 4. Inset right inner specular reflection
        drawRect(
            brush = Brush.horizontalGradient(
                colors = listOf(
                    Color.Transparent,
                    highlightColor.copy(alpha = highlightAlpha * 0.75f)
                ),
                startX = size.width - depthPx,
                endX = size.width
            ),
            topLeft = Offset(size.width - depthPx, 0f),
            size = Size(depthPx, size.height)
        )
    }
}
