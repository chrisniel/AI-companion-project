package com.example.ui.components

import android.graphics.BlurMaskFilter
import android.graphics.Paint
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.addOutline
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * SoftNeumorphic rendering engine for Jetpack Compose.
 *
 * Supports two distinct rendering tiers:
 * 1. Authentic Neumorphic (Default / Normal & Enhanced):
 *    Dual-light physical drop shadows using Android's native BlurMaskFilter:
 *    - Raised surfaces: top-left light specular reflection + bottom-right dark ambient drop shadow.
 *    - Recessed / Inset wells: concave inward top-left shadow + inward bottom-right specular reflection.
 * 2. Lightweight (Reduced / Battery Saver):
 *    GPU-accelerated RenderNode shadow + directional specular gradient stroke for minimal overhead.
 */

private object BlurFilterCache {
    private val cache = java.util.concurrent.ConcurrentHashMap<Int, BlurMaskFilter>()

    fun get(radiusPx: Float): BlurMaskFilter {
        val key = (radiusPx * 10f).toInt()
        return cache.computeIfAbsent(key) {
            BlurMaskFilter(radiusPx.coerceAtLeast(0.1f), BlurMaskFilter.Blur.NORMAL)
        }
    }
}

/**
 * Applies physical dual-direction drop shadows to raised surfaces.
 */
fun Modifier.softNeumorphicRaised(
    shape: Shape,
    isDark: Boolean = true,
    elevation: Dp = 5.dp,
    highlightAlpha: Float = if (isDark) 0.10f else 0.55f,
    shadowAlpha: Float = if (isDark) 0.60f else 0.30f,
    highlightColor: Color = if (isDark) Color(0xFF7A8A9E) else Color.White,
    shadowColor: Color = if (isDark) Color(0xFF000000) else Color(0xFF9EA3A1),
    isLightweight: Boolean = false
): Modifier {
    if (elevation <= 0.dp) return this

    if (isLightweight) {
        val shadowModifier = Modifier.shadow(
            elevation = elevation,
            shape = shape,
            clip = false,
            ambientColor = shadowColor.copy(alpha = shadowAlpha * 0.75f),
            spotColor = shadowColor.copy(alpha = shadowAlpha)
        )

        val specularHighlightModifier = Modifier.drawWithCache {
            val outline = shape.createOutline(size, layoutDirection, this)
            val specularBrush = Brush.linearGradient(
                colors = listOf(
                    highlightColor.copy(alpha = highlightAlpha),
                    highlightColor.copy(alpha = highlightAlpha * 0.3f),
                    Color.Transparent,
                    shadowColor.copy(alpha = shadowAlpha * 0.25f)
                ),
                start = Offset.Zero,
                end = Offset(size.width, size.height)
            )

            onDrawWithContent {
                drawContent()
                drawOutline(
                    outline = outline,
                    brush = specularBrush,
                    style = Stroke(width = 1.dp.toPx())
                )
            }
        }

        return this
            .then(shadowModifier)
            .then(specularHighlightModifier)
    }

    // Authentic Dual-Shadow Neumorphic Engine (BlurMaskFilter with static Skia cache)
    return this.drawWithCache {
        val elevationPx = elevation.toPx()
        // Calibrated specular highlight: tight offset & blur to eliminate upward fog bleed over containers above
        val lightOffsetPx = (elevationPx * 0.35f).coerceIn(1.dp.toPx(), 2.5.dp.toPx())
        val lightBlurRadiusPx = (elevationPx * 0.5f).coerceIn(1.5.dp.toPx(), 4.dp.toPx())

        // Bottom-right dark ambient drop shadow
        val darkOffsetPx = (elevationPx * 0.55f).coerceIn(1.5.dp.toPx(), 4.5.dp.toPx())
        val darkBlurRadiusPx = (elevationPx * 0.85f).coerceIn(2.dp.toPx(), 6.5.dp.toPx())

        val outline = shape.createOutline(size, layoutDirection, this)
        val path = Path().apply { addOutline(outline) }
        val androidPath = path.asAndroidPath()

        val lightPaint = Paint().apply {
            isAntiAlias = true
            color = highlightColor.copy(alpha = highlightAlpha).toArgb()
            if (lightBlurRadiusPx > 0f) {
                maskFilter = BlurFilterCache.get(lightBlurRadiusPx)
            }
        }

        val darkPaint = Paint().apply {
            isAntiAlias = true
            color = shadowColor.copy(alpha = shadowAlpha).toArgb()
            if (darkBlurRadiusPx > 0f) {
                maskFilter = BlurFilterCache.get(darkBlurRadiusPx)
            }
        }

        onDrawBehind {
            val nativeCanvas = drawContext.canvas.nativeCanvas

            // 1. Physical top-left light reflection (negative offset: -dx, -dy)
            nativeCanvas.save()
            nativeCanvas.translate(-lightOffsetPx, -lightOffsetPx)
            try {
                nativeCanvas.drawPath(androidPath, lightPaint)
            } catch (_: Throwable) {}
            nativeCanvas.restore()

            // 2. Physical bottom-right dark drop shadow (positive offset: +dx, +dy)
            nativeCanvas.save()
            nativeCanvas.translate(darkOffsetPx, darkOffsetPx)
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
 * Uses an inverted path difference mask with BlurMaskFilter for genuine curved inner shadows,
 * or GPU inner gradient shaders when in lightweight mode.
 */
fun Modifier.softNeumorphicInset(
    shape: Shape,
    isDark: Boolean = true,
    depth: Dp = 4.dp,
    shadowAlpha: Float = if (isDark) 0.65f else 0.35f,
    highlightAlpha: Float = if (isDark) 0.15f else 0.70f,
    shadowColor: Color = if (isDark) Color(0xFF000000) else Color(0xFF9EA3A1),
    highlightColor: Color = if (isDark) Color(0xFF7A8A9E) else Color.White,
    isLightweight: Boolean = false
): Modifier {
    if (depth <= 0.dp) return this

    if (isLightweight) {
        return this.drawWithCache {
            val outline = shape.createOutline(size, layoutDirection, this)
            val depthPx = depth.toPx()

            val insetBorderBrush = Brush.linearGradient(
                colors = listOf(
                    shadowColor.copy(alpha = shadowAlpha * 0.6f),
                    shadowColor.copy(alpha = shadowAlpha * 0.2f),
                    Color.Transparent,
                    highlightColor.copy(alpha = highlightAlpha * 0.5f)
                ),
                start = Offset.Zero,
                end = Offset(size.width, size.height)
            )

            onDrawWithContent {
                drawContent()
                drawOutline(
                    outline = outline,
                    brush = insetBorderBrush,
                    style = Stroke(width = depthPx.coerceAtMost(2.dp.toPx()))
                )
            }
        }
    }

    // Authentic Concave Inset Well Engine (BlurMaskFilter with difference path and static Skia cache)
    return this.drawWithCache {
        val outline = shape.createOutline(size, layoutDirection, this)
        val shapePath = Path().apply { addOutline(outline) }
        val androidPath = shapePath.asAndroidPath()

        val depthPx = depth.toPx()
        // Calibrated inner shadow spread: higher blur radius for soft, deep concave recession
        val blurRadiusPx = (depthPx * 2.5f).coerceIn(6.dp.toPx(), 16.dp.toPx())
        val offsetPx = (depthPx * 0.85f).coerceIn(2.dp.toPx(), 5.dp.toPx())

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
            maskFilter = BlurFilterCache.get(blurRadiusPx)
        }

        val lightPaint = Paint().apply {
            isAntiAlias = true
            color = highlightColor.copy(alpha = highlightAlpha).toArgb()
            maskFilter = BlurFilterCache.get(blurRadiusPx)
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
    highlightColor: Color = if (isDark) Color(0xFF7A8A9E) else Color.White,
    isLightweight: Boolean = false
): Modifier = this.softNeumorphicInset(
    shape = shape,
    isDark = isDark,
    depth = depth,
    shadowAlpha = shadowAlpha,
    highlightAlpha = highlightAlpha,
    shadowColor = shadowColor,
    highlightColor = highlightColor,
    isLightweight = isLightweight
)
