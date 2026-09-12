package com.example.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.spring
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.Velocity
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.sign

/**
 * High-performance elastic spring bounce overscroll modifier for Jetpack Compose.
 *
 * Implements physical rubber-band drag resistance past scroll bounds and snaps back
 * with an authentic, lively spring bounce (matching Jitter UI / iOS physical dynamics).
 *
 * Performance guarantee:
 * Mutates layout strictly via [Modifier.graphicsLayer] translation, eliminating recomposition
 * passes and guaranteeing full high-refresh-rate (60Hz, 90Hz, 120Hz, 144Hz, 165Hz) frame budget execution.
 */
@Composable
fun Modifier.softBounceOverscroll(
    enabled: Boolean = true,
    maxOverscrollPx: Float = 140f
): Modifier {
    if (!enabled) return this

    val coroutineScope = rememberCoroutineScope()
    var offsetState by remember { mutableFloatStateOf(0f) }
    var animJob by remember { mutableStateOf<Job?>(null) }

    fun animateToZero(initialVelocity: Float = 0f) {
        animJob?.cancel()
        animJob = coroutineScope.launch {
            try {
                animate(
                    initialValue = offsetState,
                    targetValue = 0f,
                    initialVelocity = initialVelocity.coerceIn(-1500f, 1500f),
                    animationSpec = spring(
                        dampingRatio = Spring.DampingRatioMediumBouncy,
                        stiffness = Spring.StiffnessLow
                    )
                ) { value, _ ->
                    offsetState = value
                }
            } finally {
                offsetState = 0f
            }
        }
    }

    val nestedScrollConnection = remember(coroutineScope, maxOverscrollPx) {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                // If an animation is active and user touches down, stop animation immediately
                if (source == NestedScrollSource.UserInput) {
                    animJob?.cancel()
                    animJob = null
                }

                // If we are currently stretched past bounds, consume movement towards center synchronously
                val current = offsetState
                if (abs(current) > 0.01f && source == NestedScrollSource.UserInput) {
                    val isPullingBack = (current > 0f && available.y < 0f) || (current < 0f && available.y > 0f)
                    if (isPullingBack) {
                        val newOffset = current + available.y
                        return if (sign(newOffset) != sign(current)) {
                            // Crossed zero: snap to zero synchronously and pass remaining delta to list
                            offsetState = 0f
                            Offset(0f, -current)
                        } else {
                            offsetState = newOffset
                            Offset(0f, available.y)
                        }
                    }
                }
                return Offset.Zero
            }

            override fun onPostScroll(
                consumed: Offset,
                available: Offset,
                source: NestedScrollSource
            ): Offset {
                // If user pulls down (available.y > 0f) at the top, let PullToRefreshBox handle it!
                // Only absorb upward overscroll (available.y < 0f) at the bottom content boundary.
                if (source == NestedScrollSource.UserInput && available.y < 0f) {
                    val current = offsetState
                    // Authentic progressive quadratic rubber-band resistance curve
                    val dragRatio = (abs(current) / maxOverscrollPx).coerceIn(0f, 1f)
                    val friction = ((1f - dragRatio) * (1f - dragRatio)) * 0.32f
                    val delta = available.y * friction
                    offsetState = (current + delta).coerceIn(-maxOverscrollPx, maxOverscrollPx)
                    return Offset(0f, available.y)
                }
                return Offset.Zero
            }

            override suspend fun onPreFling(available: Velocity): Velocity {
                val current = offsetState

                // CRITICAL FIX: If stretched, but user flings back into content (e.g. swiping up to scroll down):
                // NEVER intercept fling! Let 100% of velocity flow to the LazyColumn or verticalScroll!
                if (current > 1f && available.y < 0f) {
                    animateToZero()
                    return Velocity.Zero
                }
                if (current < -1f && available.y > 0f) {
                    animateToZero()
                    return Velocity.Zero
                }

                // If resting or sub-pixel, never touch fling
                if (abs(current) <= 1f) {
                    offsetState = 0f
                    return Velocity.Zero
                }

                // Only consume if flinging further outward past the boundary
                animateToZero(initialVelocity = available.y)
                return available
            }

            override suspend fun onPostFling(consumed: Velocity, available: Velocity): Velocity {
                val current = offsetState
                if (abs(current) > 1f) {
                    animateToZero()
                    return available
                } else if (abs(available.y) > 650f) {
                    // High-velocity fling collision against boundary (absorb inertia and spring recoil)
                    val momentumDistance = (available.y * 0.045f).coerceIn(-85f, 85f)
                    if (abs(momentumDistance) > 8f) {
                        animJob?.cancel()
                        animJob = coroutineScope.launch {
                            try {
                                // Phase 1: Smooth deceleration to momentum apex
                                animate(
                                    initialValue = 0f,
                                    targetValue = momentumDistance,
                                    animationSpec = spring(
                                        dampingRatio = Spring.DampingRatioNoBouncy,
                                        stiffness = Spring.StiffnessMedium
                                    )
                                ) { value, _ ->
                                    offsetState = value
                                }
                                // Phase 2: Authentic rubber-band spring recoil back to resting center
                                animate(
                                    initialValue = momentumDistance,
                                    targetValue = 0f,
                                    animationSpec = spring(
                                        dampingRatio = Spring.DampingRatioMediumBouncy,
                                        stiffness = Spring.StiffnessLow
                                    )
                                ) { value, _ ->
                                    offsetState = value
                                }
                            } finally {
                                offsetState = 0f
                            }
                        }
                        return available
                    }
                }
                return Velocity.Zero
            }
        }
    }

    return this
        .clipToBounds()
        .nestedScroll(nestedScrollConnection)
        .graphicsLayer {
            translationY = offsetState
        }
}

