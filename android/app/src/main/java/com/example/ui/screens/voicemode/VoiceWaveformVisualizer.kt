package com.example.ui.screens.voicemode

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.example.domain.model.VoiceSemanticState
import com.example.ui.theme.SoftTheme
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

/**
 * Animated real-time Waveform Visualizer for Voice Mode.
 * Renders 28 symmetric audio spectrum bars that dynamically adapt their
 * frequency, amplitude, and phase based on the current VoiceSemanticState.
 */
@Composable
fun VoiceWaveformVisualizer(
    semanticState: VoiceSemanticState,
    isMuted: Boolean,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "waveform_motion")

    // Continuous time variable driving phase oscillation
    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = when (semanticState) {
                    VoiceSemanticState.SPEAKING -> 850
                    VoiceSemanticState.LISTENING -> 1200
                    VoiceSemanticState.TRANSCRIBING -> 900
                    VoiceSemanticState.THINKING -> 1500
                    VoiceSemanticState.EXECUTING_TOOL -> 1100
                    VoiceSemanticState.IDLE -> 3200
                    VoiceSemanticState.INTERRUPTED -> 500
                    VoiceSemanticState.RECONNECTING -> 1800
                    VoiceSemanticState.OFFLINE -> 5000
                    VoiceSemanticState.ERROR -> 700
                },
                easing = LinearEasing
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "phase"
    )

    // Secondary pulse for amplitude modulation
    val ampMod by infiniteTransition.animateFloat(
        initialValue = 0.7f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = 600,
                easing = FastOutSlowInEasing
            ),
            repeatMode = RepeatMode.Reverse
        ),
        label = "ampMod"
    )

    // Waveform Accent Colors based on state
    val barColorStart = when {
        isMuted -> SoftTheme.colors.statusWarning
        semanticState == VoiceSemanticState.LISTENING -> SoftTheme.colors.accentCyan
        semanticState == VoiceSemanticState.SPEAKING -> SoftTheme.colors.accentBlue
        semanticState == VoiceSemanticState.TRANSCRIBING -> SoftTheme.colors.accentViolet
        semanticState == VoiceSemanticState.THINKING -> SoftTheme.colors.accentBlue
        semanticState == VoiceSemanticState.EXECUTING_TOOL -> SoftTheme.colors.accentCyan
        semanticState == VoiceSemanticState.INTERRUPTED -> SoftTheme.colors.statusWarning
        semanticState == VoiceSemanticState.RECONNECTING -> SoftTheme.colors.accentAmber
        semanticState == VoiceSemanticState.OFFLINE -> SoftTheme.colors.textMuted
        semanticState == VoiceSemanticState.ERROR -> SoftTheme.colors.statusError
        else -> SoftTheme.colors.accentBlue.copy(alpha = 0.6f)
    }

    val barColorEnd = when {
        isMuted -> SoftTheme.colors.statusWarning.copy(alpha = 0.4f)
        semanticState == VoiceSemanticState.LISTENING -> SoftTheme.colors.statusSuccess
        semanticState == VoiceSemanticState.SPEAKING -> SoftTheme.colors.accentCyan
        semanticState == VoiceSemanticState.TRANSCRIBING -> SoftTheme.colors.accentBlue
        semanticState == VoiceSemanticState.THINKING -> SoftTheme.colors.accentViolet
        semanticState == VoiceSemanticState.EXECUTING_TOOL -> SoftTheme.colors.accentViolet
        semanticState == VoiceSemanticState.INTERRUPTED -> SoftTheme.colors.textMuted
        semanticState == VoiceSemanticState.RECONNECTING -> SoftTheme.colors.statusWarning
        semanticState == VoiceSemanticState.OFFLINE -> SoftTheme.colors.borderSubtle
        semanticState == VoiceSemanticState.ERROR -> SoftTheme.colors.statusError.copy(alpha = 0.3f)
        else -> SoftTheme.colors.accentCyan.copy(alpha = 0.4f)
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(58.dp)
            .testTag("voice_waveform_visualizer")
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(SoftTheme.colors.surfaceWell)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .padding(horizontal = 14.dp, vertical = 6.dp)
            .semantics {
                contentDescription = "Waveform visualizer representing $semanticState audio signal"
            }
    ) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val barCount = 28
            val totalWidth = size.width
            val availableHeight = size.height
            val centerY = availableHeight / 2f

            val barSpacing = 4.dp.toPx()
            val totalSpacing = barSpacing * (barCount - 1)
            val barWidth = ((totalWidth - totalSpacing) / barCount).coerceAtLeast(2.dp.toPx())

            val brush = Brush.verticalGradient(
                colors = listOf(barColorStart, barColorEnd),
                startY = 0f,
                endY = availableHeight
            )

            // Calculate heights for each bar using composite sine waves
            for (i in 0 until barCount) {
                // Normalized position across bars (-1.0 to 1.0)
                val normX = (i - (barCount - 1) / 2f) / ((barCount - 1) / 2f)
                // Gaussian envelope to keep center bars taller and taper off gently at edges
                val envelope = (1f - (normX * normX * 0.65f)).coerceIn(0.15f, 1.0f)

                val baseHeightFraction = when {
                    isMuted -> 0.08f
                    semanticState == VoiceSemanticState.SPEAKING -> {
                        // High-amplitude harmonic resonance
                        val w1 = sin((normX * 4f) + phase).toFloat()
                        val w2 = sin((normX * 8f) - (phase * 1.4f)).toFloat()
                        (0.35f + abs(w1 * 0.4f + w2 * 0.25f) * ampMod) * envelope
                    }
                    semanticState == VoiceSemanticState.LISTENING -> {
                        // Responsive acoustic pickup
                        val w = sin((normX * 5f) + phase).toFloat()
                        (0.25f + abs(w * 0.5f) * ampMod) * envelope
                    }
                    semanticState == VoiceSemanticState.TRANSCRIBING || semanticState == VoiceSemanticState.THINKING -> {
                        // Computational rhythmic scanning ripple
                        val scanPos = ((phase / (2 * PI)) * barCount).toInt() % barCount
                        val dist = abs(i - scanPos)
                        val scanBoost = if (dist <= 3) (1f - dist / 3f) * 0.6f else 0.05f
                        (0.2f + scanBoost) * envelope
                    }
                    semanticState == VoiceSemanticState.EXECUTING_TOOL -> {
                        // Symmetric stepped cadence
                        val step = (i % 4) * 0.15f
                        (0.25f + step) * envelope
                    }
                    semanticState == VoiceSemanticState.INTERRUPTED -> {
                        // Flatline with subtle damped wobble
                        0.08f + abs(sin(phase * 2f)) * 0.04f
                    }
                    semanticState == VoiceSemanticState.RECONNECTING -> {
                        // Periodic heartbeat ping
                        val ping = abs(sin(phase))
                        if (normX in -0.3f..0.3f) (0.1f + ping * 0.4f) else 0.08f
                    }
                    semanticState == VoiceSemanticState.OFFLINE -> 0.06f
                    semanticState == VoiceSemanticState.ERROR -> {
                        // Jagged chaotic jitter
                        val jitter = ((i * 17) % 10) / 20f
                        0.15f + jitter * 0.35f
                    }
                    else -> {
                        // IDLE: Tranquil slow respiration ripple
                        val w = sin((normX * 2.5f) + phase).toFloat()
                        (0.15f + abs(w * 0.15f)) * envelope
                    }
                }.coerceIn(0.06f, 0.95f)

                val barHeight = (availableHeight * baseHeightFraction).coerceAtLeast(3.dp.toPx())
                val left = i * (barWidth + barSpacing)
                val top = centerY - (barHeight / 2f)

                drawRoundRect(
                    brush = brush,
                    topLeft = Offset(left, top),
                    size = Size(barWidth, barHeight),
                    cornerRadius = CornerRadius(barWidth / 2f, barWidth / 2f)
                )
            }
        }
    }
}
