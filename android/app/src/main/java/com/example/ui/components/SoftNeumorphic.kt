package com.example.ui.components

import android.graphics.BlurMaskFilter
import android.graphics.Paint
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
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * SoftNeumorphic rendering engine for Jetpack Compose.
 *
 * Casts physical directional dual-light neumorphic drop shadows:
 * - Raised surfaces: top-left light specular reflection + bottom-right dark ambient drop shadow.
 * - Recessed / Inset wells: inward top-left shadow + inward bottom-right specular reflection.
 *
 * Uses hardware-accelerated BlurMaskFilter for authentic 3D tactile extrusion
 * matching the reference clay and matte neumorphic identity.
 */

/**
 * Applies physical dual-direction drop shadows to raised surfaces.
 */
fun Modifier.softNeumorphicRaised(
    shape: Shape,
    isDark: Boolean = true,
    elevation: Dp = 5.dp,
    highlightAlpha: Float = if (isDark) 0.22f else 0.85f,
    shadowAlpha: Float = if (isDark) 0.70f else 0.35f,
    highlightColor: Color = if (isDark) Color(0xFF7A8A9E) else Color.White,
    shadowColor: Color = if (isDark) Color(0xFF000000) else Color(0xFF9EA3A1)
): Modifier = this.drawWithCache {
    if (elevation <= 0.dp) {
        onDrawBehind { }
    } else {
        val elevationPx = elevation.toPx()
        val offsetPx = (elevationPx * 0.75f).coerceIn(2.dp.toPx(), 7.dp.toPx())
        val blurRadiusPx = (elevationPx * 1.3f).coerceIn(3.dp.toPx(), 14.dp.toPx())

        val outline = shape.createOutline(size, layoutDirection, this)
        val path = Path().apply { addOutline(outline) }
        val androidPath = path.asAndroidPath()

        val lightPaint = Paint().apply {
            isAntiAlias = true
            color = highlightColor.copy(alpha = highlightAlpha).toArgb()
            if (blurRadiusPx > 0f) {
                maskFilter = BlurMaskFilter(blurRadiusPx, BlurMaskFilter.Blur.NORMAL)
            }
        }

        val darkPaint = Paint().apply {
            isAntiAlias = true
            color = shadowColor.copy(alpha = shadowAlpha).toArgb()
            if (blurRadiusPx > 0f) {
                maskFilter = BlurMaskFilter(blurRadiusPx, BlurMaskFilter.Blur.NORMAL)
            }
        }

        onDrawBehind {
            val nativeCanvas = drawContext.canvas.nativeCanvas

            // 1. Physical top-left light reflection (negative offset: -dx, -dy)
            nativeCanvas.save()
            nativeCanvas.translate(-offsetPx, -offsetPx)
            try {
                nativeCanvas.drawPath(androidPath, lightPaint)
            } catch (_: Throwable) {}
            nativeCanvas.restore()

            // 2. Physical bottom-right dark drop shadow (positive offset: +dx, +dy)
            nativeCanvas.save()
            nativeCanvas.translate(offsetPx, offsetPx)
            try {
                nativeCanvas.drawPath(androidPath, darkPaint)
            } catch (_: Throwable) {}
            nativeCanvas.restore()
        }
    }
}

/**
 * Applies authentic concave inner / recessed well depth to containers, pressed buttons,
 * search inputs, and selected items.
 * Uses an inverted path difference mask with BlurMaskFilter for genuine curved inner shadows.
 */
fun Modifier.softNeumorphicInset(
    shape: Shape,
    isDark: Boolean = true,
    depth: Dp = 4.dp,
    shadowAlpha: Float = if (isDark) 0.65f else 0.35f,
    highlightAlpha: Float = if (isDark) 0.18f else 0.80f,
    shadowColor: Color = if (isDark) Color(0xFF000000) else Color(0xFF9EA3A1),
    highlightColor: Color = if (isDark) Color(0xFF7A8A9E) else Color.White
): Modifier = this.drawWithCache {
    if (depth <= 0.dp) {
        onDrawWithContent { drawContent() }
    } else {
        val outline = shape.createOutline(size, layoutDirection, this)
        val shapePath = Path().apply { addOutline(outline) }
        val androidPath = shapePath.asAndroidPath()

        val depthPx = depth.toPx()
        val blurRadiusPx = (depthPx * 1.3f).coerceAtLeast(1.dp.toPx())
        val offsetPx = (depthPx * 0.75f).coerceAtLeast(1.dp.toPx())

        // Inverted path: create an outer boundary with the shape carved out
        val pad = blurRadiusPx * 3f
        val outerBounds = android.graphics.RectF(-pad, -pad, size.width + pad, size.height + pad)
        val invertedPath = android.graphics.Path().apply {
            addRect(outerBounds, android.graphics.Path.Direction.CW)
            op(androidPath, android.graphics.Path.Op.DIFFERENCE)
        }

        val darkPaint = Paint().apply {
            isAntiAlias = true
            color = shadowColor.copy(alpha = shadowAlpha).toArgb()
            maskFilter = BlurMaskFilter(blurRadiusPx, BlurMaskFilter.Blur.NORMAL)
        }

        val lightPaint = Paint().apply {
            isAntiAlias = true
            color = highlightColor.copy(alpha = highlightAlpha).toArgb()
            maskFilter = BlurMaskFilter(blurRadiusPx, BlurMaskFilter.Blur.NORMAL)
        }

        onDrawWithContent {
            drawContent()

            val nativeCanvas = drawContext.canvas.nativeCanvas
            nativeCanvas.save()
            // Restrict shadow bleed strictly to the interior of the shape
            nativeCanvas.clipPath(androidPath)

            // 1. Top-Left inner dark shadow (offset +dx, +dy into the well)
            nativeCanvas.save()
            nativeCanvas.translate(offsetPx, offsetPx)
            try {
                nativeCanvas.drawPath(invertedPath, darkPaint)
            } catch (_: Throwable) {}
            nativeCanvas.restore()

            // 2. Bottom-Right inner light highlight (offset -dx, -dy into the well)
            nativeCanvas.save()
            nativeCanvas.translate(-offsetPx, -offsetPx)
            try {
                nativeCanvas.drawPath(invertedPath, lightPaint)
            } catch (_: Throwable) {}
            nativeCanvas.restore()

            nativeCanvas.restore()
        }
    }
}

/**
 * Backward compatibility alias for softNeumorphicInset.
 */
fun Modifier.softInsetWell(
    shape: Shape,
    isDark: Boolean = true,
    depth: Dp = 4.dp,
    shadowAlpha: Float = if (isDark) 0.65f else 0.35f,
    highlightAlpha: Float = if (isDark) 0.18f else 0.80f,
    shadowColor: Color = if (isDark) Color(0xFF000000) else Color(0xFF9EA3A1),
    highlightColor: Color = if (isDark) Color(0xFF7A8A9E) else Color.White
): Modifier = this.softNeumorphicInset(
    shape = shape,
    isDark = isDark,
    depth = depth,
    shadowAlpha = shadowAlpha,
    highlightAlpha = highlightAlpha,
    shadowColor = shadowColor,
    highlightColor = highlightColor
)
