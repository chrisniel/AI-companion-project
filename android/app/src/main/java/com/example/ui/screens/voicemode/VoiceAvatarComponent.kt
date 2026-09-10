package com.example.ui.screens.voicemode

import androidx.compose.animation.animateColorAsState
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
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Cached
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.VoiceAvatarProfile
import com.example.domain.model.VoiceSemanticState
import com.example.ui.theme.SoftTheme
import kotlin.math.cos
import kotlin.math.sin

/**
 * Procedural state-reactive Avatar Component for Voice Mode.
 * Reacts visually to all 10 semantic states without hardcoding character-specific files.
 */
@Composable
fun VoiceAvatarComponent(
    semanticState: VoiceSemanticState,
    avatarProfile: VoiceAvatarProfile,
    availableAvatars: List<VoiceAvatarProfile>,
    onSelectAvatar: (VoiceAvatarProfile) -> Unit,
    modifier: Modifier = Modifier
) {
    var showAvatarMenu by remember { mutableStateOf(false) }

    // Semantic Color mapping based on current state
    val primaryAuraColor by animateColorAsState(
        targetValue = when (semanticState) {
            VoiceSemanticState.IDLE -> SoftTheme.colors.accentBlue.copy(alpha = 0.55f)
            VoiceSemanticState.LISTENING -> SoftTheme.colors.accentCyan
            VoiceSemanticState.TRANSCRIBING -> SoftTheme.colors.accentViolet
            VoiceSemanticState.THINKING -> SoftTheme.colors.accentBlue
            VoiceSemanticState.EXECUTING_TOOL -> SoftTheme.colors.accentCyan
            VoiceSemanticState.SPEAKING -> SoftTheme.colors.accentBlue
            VoiceSemanticState.INTERRUPTED -> SoftTheme.colors.statusWarning
            VoiceSemanticState.RECONNECTING -> SoftTheme.colors.statusWarning
            VoiceSemanticState.OFFLINE -> SoftTheme.colors.textMuted
            VoiceSemanticState.ERROR -> SoftTheme.colors.statusError
        },
        animationSpec = tween(durationMillis = 350),
        label = "primaryAuraColor"
    )

    val secondaryAuraColor by animateColorAsState(
        targetValue = when (semanticState) {
            VoiceSemanticState.IDLE -> SoftTheme.colors.accentCyan.copy(alpha = 0.35f)
            VoiceSemanticState.LISTENING -> SoftTheme.colors.statusSuccess
            VoiceSemanticState.TRANSCRIBING -> SoftTheme.colors.accentBlue
            VoiceSemanticState.THINKING -> SoftTheme.colors.accentViolet
            VoiceSemanticState.EXECUTING_TOOL -> SoftTheme.colors.accentViolet
            VoiceSemanticState.SPEAKING -> SoftTheme.colors.accentCyan
            VoiceSemanticState.INTERRUPTED -> SoftTheme.colors.statusWarning.copy(alpha = 0.4f)
            VoiceSemanticState.RECONNECTING -> SoftTheme.colors.accentAmber.copy(alpha = 0.4f)
            VoiceSemanticState.OFFLINE -> SoftTheme.colors.borderSubtle
            VoiceSemanticState.ERROR -> SoftTheme.colors.statusError.copy(alpha = 0.4f)
        },
        animationSpec = tween(durationMillis = 350),
        label = "secondaryAuraColor"
    )

    // Infinite transition for continuous state-driven motion
    val infiniteTransition = rememberInfiniteTransition(label = "avatar_motion")

    // Rhythmic respiration / pulse scale
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = when (semanticState) {
            VoiceSemanticState.IDLE -> 1.05f
            VoiceSemanticState.LISTENING -> 1.14f
            VoiceSemanticState.SPEAKING -> 1.20f
            VoiceSemanticState.THINKING -> 1.10f
            VoiceSemanticState.TRANSCRIBING -> 1.08f
            VoiceSemanticState.INTERRUPTED -> 0.98f
            VoiceSemanticState.RECONNECTING -> 1.06f
            VoiceSemanticState.OFFLINE -> 1.00f
            VoiceSemanticState.ERROR -> 1.08f
            VoiceSemanticState.EXECUTING_TOOL -> 1.12f
        },
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = when (semanticState) {
                    VoiceSemanticState.IDLE -> 2400
                    VoiceSemanticState.LISTENING -> 900
                    VoiceSemanticState.SPEAKING -> 600
                    VoiceSemanticState.THINKING -> 1200
                    VoiceSemanticState.TRANSCRIBING -> 800
                    VoiceSemanticState.INTERRUPTED -> 300
                    VoiceSemanticState.RECONNECTING -> 1500
                    VoiceSemanticState.OFFLINE -> 4000
                    VoiceSemanticState.ERROR -> 500
                    VoiceSemanticState.EXECUTING_TOOL -> 1000
                },
                easing = FastOutSlowInEasing
            ),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    // Continuous orbital rotation angle
    val rotationAngle by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = when (semanticState) {
                    VoiceSemanticState.THINKING -> 3500
                    VoiceSemanticState.TRANSCRIBING -> 2400
                    VoiceSemanticState.EXECUTING_TOOL -> 2800
                    VoiceSemanticState.SPEAKING -> 5000
                    VoiceSemanticState.LISTENING -> 6000
                    VoiceSemanticState.RECONNECTING -> 4000
                    else -> 12000
                },
                easing = LinearEasing
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotationAngle"
    )

    // Wave ripple progress for expanding rings
    val waveRipple by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = if (semanticState == VoiceSemanticState.SPEAKING || semanticState == VoiceSemanticState.LISTENING) 1200 else 2500,
                easing = LinearEasing
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "waveRipple"
    )

    Column(
        modifier = modifier
            .testTag("voice_avatar_container")
            .semantics { contentDescription = "Voice Avatar ${avatarProfile.name} in state ${semanticState.label}" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Main Avatar Canvas & Visualizer
        val accentCyan = SoftTheme.colors.accentCyan
        val statusWarning = SoftTheme.colors.statusWarning
        val statusError = SoftTheme.colors.statusError

        Box(
            modifier = Modifier
                .size(190.dp)
                .testTag("voice_avatar_visualizer"),
            contentAlignment = Alignment.Center
        ) {
            // Background Canvas: Multi-layer Orbital Rings & State-driven Shockwaves
            Canvas(modifier = Modifier.size(190.dp)) {
                val centerOffset = Offset(size.width / 2f, size.height / 2f)
                val baseRadius = size.minDimension / 2f - 14.dp.toPx()

                // Outer ambient glow ring
                drawCircle(
                    color = primaryAuraColor.copy(alpha = 0.12f * pulseScale),
                    radius = baseRadius * pulseScale + 12.dp.toPx()
                )

                // Dynamic Ripple Wave (expanding outward)
                if (semanticState == VoiceSemanticState.LISTENING || semanticState == VoiceSemanticState.SPEAKING) {
                    val rippleRadius = (baseRadius * 0.7f) + ((baseRadius * 0.55f) * waveRipple)
                    val rippleAlpha = (1f - waveRipple).coerceIn(0f, 0.45f)
                    drawCircle(
                        color = primaryAuraColor.copy(alpha = rippleAlpha),
                        radius = rippleRadius,
                        style = Stroke(width = 2.dp.toPx())
                    )
                }

                // Intermediate orbital or segmented ring
                val orbitRadius = baseRadius * 0.85f
                when (semanticState) {
                    VoiceSemanticState.THINKING, VoiceSemanticState.TRANSCRIBING -> {
                        // Double rotating dashed orbital tracks
                        val pathEffect = PathEffect.dashPathEffect(floatArrayOf(24f, 16f), rotationAngle)
                        drawCircle(
                            color = primaryAuraColor.copy(alpha = 0.6f),
                            radius = orbitRadius,
                            style = Stroke(width = 2.5.dp.toPx(), pathEffect = pathEffect)
                        )

                        // Orbiting satellite dots
                        val angleRad1 = Math.toRadians(rotationAngle.toDouble())
                        val angleRad2 = Math.toRadians((rotationAngle + 180).toDouble())
                        val dot1 = Offset(
                            x = centerOffset.x + (orbitRadius * cos(angleRad1)).toFloat(),
                            y = centerOffset.y + (orbitRadius * sin(angleRad1)).toFloat()
                        )
                        val dot2 = Offset(
                            x = centerOffset.x + (orbitRadius * cos(angleRad2)).toFloat(),
                            y = centerOffset.y + (orbitRadius * sin(angleRad2)).toFloat()
                        )
                        drawCircle(color = secondaryAuraColor, radius = 4.dp.toPx(), center = dot1)
                        drawCircle(color = primaryAuraColor, radius = 4.dp.toPx(), center = dot2)
                    }
                    VoiceSemanticState.EXECUTING_TOOL -> {
                        // Segmented precision technical ring
                        val pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 8f), -rotationAngle)
                        drawCircle(
                            color = accentCyan,
                            radius = orbitRadius,
                            style = Stroke(width = 2.dp.toPx(), pathEffect = pathEffect)
                        )
                    }
                    VoiceSemanticState.RECONNECTING -> {
                        // Pulsing searching arc
                        drawArc(
                            color = statusWarning,
                            startAngle = rotationAngle,
                            sweepAngle = 100f,
                            useCenter = false,
                            topLeft = Offset(centerOffset.x - orbitRadius, centerOffset.y - orbitRadius),
                            size = androidx.compose.ui.geometry.Size(orbitRadius * 2, orbitRadius * 2),
                            style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
                        )
                    }
                    VoiceSemanticState.ERROR -> {
                        // Jitter warning ring
                        drawCircle(
                            color = statusError.copy(alpha = 0.7f),
                            radius = orbitRadius * (if (pulseScale > 1.0f) 1.03f else 0.97f),
                            style = Stroke(width = 3.dp.toPx())
                        )
                    }
                    else -> {
                        // Smooth delicate baseline ring
                        drawCircle(
                            color = primaryAuraColor.copy(alpha = 0.35f),
                            radius = orbitRadius,
                            style = Stroke(width = 1.5.dp.toPx())
                        )
                    }
                }

                // Core inner aperture halo
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            primaryAuraColor.copy(alpha = 0.45f),
                            secondaryAuraColor.copy(alpha = 0.15f),
                            Color.Transparent
                        ),
                        center = centerOffset,
                        radius = baseRadius * 0.65f
                    ),
                    radius = baseRadius * 0.65f
                )
            }

            // Core Avatar Disc & Center Glyph
            Box(
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(
                                SoftTheme.colors.surfaceElevated,
                                SoftTheme.colors.surface
                            )
                        )
                    )
                    .border(
                        width = 2.dp,
                        brush = Brush.sweepGradient(
                            colors = listOf(
                                primaryAuraColor,
                                secondaryAuraColor,
                                primaryAuraColor
                            )
                        ),
                        shape = CircleShape
                    )
                    .testTag("avatar_core_disc"),
                contentAlignment = Alignment.Center
            ) {
                // State-reactive Center Icon / Visage Glyph
                val icon: ImageVector = when (semanticState) {
                    VoiceSemanticState.IDLE -> Icons.Default.AutoAwesome
                    VoiceSemanticState.LISTENING -> Icons.Default.Mic
                    VoiceSemanticState.TRANSCRIBING -> Icons.Default.GraphicEq
                    VoiceSemanticState.THINKING -> Icons.Default.Psychology
                    VoiceSemanticState.EXECUTING_TOOL -> Icons.Default.Tune
                    VoiceSemanticState.SPEAKING -> Icons.Default.GraphicEq
                    VoiceSemanticState.INTERRUPTED -> Icons.Default.Pause
                    VoiceSemanticState.RECONNECTING -> Icons.Default.Cached
                    VoiceSemanticState.OFFLINE -> Icons.Default.WifiOff
                    VoiceSemanticState.ERROR -> Icons.Default.ErrorOutline
                }

                Icon(
                    imageVector = icon,
                    contentDescription = "Avatar State ${semanticState.label}",
                    tint = primaryAuraColor,
                    modifier = Modifier
                        .size(42.dp)
                        .testTag("avatar_glyph")
                )
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // Avatar Identity Pill with Archetype switch menu
        Box {
            Row(
                modifier = Modifier
                    .testTag("avatar_profile_pill")
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                    .background(SoftTheme.colors.surfaceElevated)
                    .border(
                        width = SoftTheme.tokens.borders.hairline,
                        color = SoftTheme.colors.borderSubtle,
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                    )
                    .clickable { showAvatarMenu = true }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(primaryAuraColor)
                )

                Text(
                    text = avatarProfile.name,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )

                Text(
                    text = "• ${avatarProfile.title}",
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 11.sp
                )
            }

            // Dropdown Menu to switch active avatar profile without touching business logic
            DropdownMenu(
                expanded = showAvatarMenu,
                onDismissRequest = { showAvatarMenu = false },
                modifier = Modifier.background(SoftTheme.colors.surfaceElevated)
            ) {
                availableAvatars.forEach { profile ->
                    val isSelected = profile.id == avatarProfile.id
                    DropdownMenuItem(
                        text = {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Column {
                                    Text(
                                        text = "${profile.name} — ${profile.title}",
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                        color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary
                                    )
                                    Text(
                                        text = "${profile.archetype} • ${profile.accentTag}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = SoftTheme.colors.textMuted,
                                        fontSize = 11.sp
                                    )
                                }
                            }
                        },
                        trailingIcon = {
                            if (isSelected) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = "Selected",
                                    tint = SoftTheme.colors.accentBlue,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        },
                        onClick = {
                            onSelectAvatar(profile)
                            showAvatarMenu = false
                        },
                        modifier = Modifier.testTag("avatar_option_${profile.id}")
                    )
                }
            }
        }
    }
}
