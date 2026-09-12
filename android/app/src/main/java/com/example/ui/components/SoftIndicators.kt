package com.example.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.StatusSeverity
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * StatusBadge: Accessible pill indicator communicating status states
 * (Normal, Info, Success, Warning, Error) with both color and text label.
 */
@Composable
fun StatusBadge(
    text: String,
    severity: StatusSeverity,
    modifier: Modifier = Modifier,
    hasDot: Boolean = true,
    testTag: String = "status_badge"
) {
    val (dotColor, bgTint, textColor) = when (severity) {
        StatusSeverity.Normal -> Triple(
            SoftTheme.colors.textMuted,
            SoftTheme.colors.surfacePressed,
            SoftTheme.colors.textSecondary
        )
        StatusSeverity.Info -> Triple(
            SoftTheme.colors.statusInfo,
            SoftTheme.colors.statusInfoSubtle,
            SoftTheme.colors.statusInfo
        )
        StatusSeverity.Success -> Triple(
            SoftTheme.colors.statusSuccess,
            SoftTheme.colors.statusSuccessSubtle,
            SoftTheme.colors.statusSuccess
        )
        StatusSeverity.Warning -> Triple(
            SoftTheme.colors.statusWarning,
            SoftTheme.colors.statusWarningSubtle,
            SoftTheme.colors.statusWarning
        )
        StatusSeverity.Error -> Triple(
            SoftTheme.colors.statusError,
            SoftTheme.colors.statusErrorSubtle,
            SoftTheme.colors.statusError
        )
    }

    Row(
        modifier = modifier
            .testTag(testTag)
            .semantics {
                this.contentDescription = "Status: $text, severity $severity"
            }
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(bgTint)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = dotColor.copy(alpha = 0.35f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        if (hasDot) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(dotColor)
            )
            Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))
        }
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = textColor
        )
    }
}

/**
 * Restrained aura dot animation activated ONLY during transient connecting/reconnecting states.
 * Deferring values to graphicsLayer bypasses composition & layout passes entirely.
 */
@Composable
private fun PulsingConnectionAura(
    color: Color,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse_transition")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.35f,
        animationSpec = infiniteRepeatable(
            animation = tween(1400, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.45f,
        targetValue = 0.05f,
        animationSpec = infiniteRepeatable(
            animation = tween(1400, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_alpha"
    )

    Box(
        modifier = modifier
            .graphicsLayer {
                scaleX = pulseScale
                scaleY = pulseScale
                alpha = pulseAlpha
            }
            .clip(CircleShape)
            .background(color)
    )
}

/**
 * ConnectionIndicator: Displays core connection status with restrained pulsing aura dot
 * and latency telemetry tag (e.g. "Core Active 22ms").
 */
@Composable
fun ConnectionIndicator(
    state: CoreConnectionState,
    label: String,
    modifier: Modifier = Modifier,
    latencyMs: Int? = null,
    testTag: String = "connection_indicator"
) {
    val stateColor = when (state) {
        CoreConnectionState.Local -> SoftTheme.colors.statusSuccess
        CoreConnectionState.Remote -> SoftTheme.colors.accentCyan
        CoreConnectionState.Connecting -> SoftTheme.colors.accentCyan
        CoreConnectionState.Reconnecting -> SoftTheme.colors.statusWarning
        CoreConnectionState.Offline -> SoftTheme.colors.textMuted
    }

    Row(
        modifier = modifier
            .testTag(testTag)
            .semantics {
                this.contentDescription = "Connection: $label, state $state"
            }
            .shadow(
                elevation = SoftTheme.tokens.elevations.flat,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(SoftTheme.colors.surface)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                brush = SoftTheme.colors.borderGradient,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Glowing dot: static on normal local/remote/offline, gentle pulse only when connecting
        Box(
            modifier = Modifier.size(16.dp),
            contentAlignment = Alignment.Center
        ) {
            if (state == CoreConnectionState.Connecting || state == CoreConnectionState.Reconnecting) {
                PulsingConnectionAura(
                    color = stateColor,
                    modifier = Modifier.size(12.dp)
                )
            }
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .clip(CircleShape)
                    .background(stateColor)
            )
        }

        Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))

        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = SoftTheme.colors.textPrimary
        )

        if (latencyMs != null) {
            Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.xs))
                    .background(SoftTheme.colors.surfacePressed)
                    .padding(horizontal = SoftTheme.spacing.xs, vertical = 1.dp)
            ) {
                Text(
                    text = "${latencyMs}ms",
                    style = MonospaceTelemetry,
                    color = SoftTheme.colors.accentBlue
                )
            }
        }
    }
}

/**
 * CompactConnectionIndicator: Space-efficient top bar indicator.
 * Renders glowing status dot, semantic label (Local, Remote, Reconnecting, Offline),
 * and compact latency tag.
 */
@Composable
fun CompactConnectionIndicator(
    state: CoreConnectionState,
    label: String,
    modifier: Modifier = Modifier,
    latencyMs: Int? = null,
    testTag: String = "connection_indicator"
) {
    val stateColor = when (state) {
        CoreConnectionState.Local -> SoftTheme.colors.statusSuccess
        CoreConnectionState.Remote -> SoftTheme.colors.accentCyan
        CoreConnectionState.Connecting -> SoftTheme.colors.accentCyan
        CoreConnectionState.Reconnecting -> SoftTheme.colors.statusWarning
        CoreConnectionState.Offline -> SoftTheme.colors.textMuted
    }

    Row(
        modifier = modifier
            .testTag(testTag)
            .semantics {
                this.contentDescription = "Connection: $label, state $state"
            }
            .shadow(
                elevation = SoftTheme.tokens.elevations.flat,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(SoftTheme.colors.surface)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                brush = SoftTheme.colors.borderGradient,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = SoftTheme.spacing.sm, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.size(12.dp),
            contentAlignment = Alignment.Center
        ) {
            if (state == CoreConnectionState.Connecting || state == CoreConnectionState.Reconnecting) {
                PulsingConnectionAura(
                    color = stateColor,
                    modifier = Modifier.size(10.dp)
                )
            }
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(stateColor)
            )
        }

        Spacer(modifier = Modifier.width(4.dp))

        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Medium,
            color = SoftTheme.colors.textPrimary
        )

        if (latencyMs != null) {
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = "${latencyMs}ms",
                style = MonospaceTelemetry.copy(fontSize = 9.sp),
                color = SoftTheme.colors.accentBlue
            )
        }
    }
}

/**
 * SoftAvatar: Calibrated mobile avatar presentation supporting prominent 48dp - 56dp sizing,
 * soft glass elevation, specular border, initials or vector icon, and optional status dot.
 */
@Composable
fun SoftAvatar(
    name: String,
    modifier: Modifier = Modifier,
    size: Dp = 52.dp,
    icon: ImageVector? = null,
    statusColor: Color? = null,
    brush: Brush = SoftTheme.colors.accentGradient,
    testTag: String = "soft_avatar"
) {
    Box(
        modifier = modifier
            .testTag(testTag)
            .size(size)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .shadow(
                    elevation = SoftTheme.tokens.elevations.subtle,
                    shape = CircleShape,
                    ambientColor = SoftTheme.colors.shadow,
                    spotColor = SoftTheme.colors.specularHighlight
                )
                .clip(CircleShape)
                .background(brush)
                .border(
                    width = if (statusColor != null) 1.5.dp else SoftTheme.tokens.borders.hairline,
                    brush = if (statusColor != null) androidx.compose.ui.graphics.SolidColor(statusColor) else SoftTheme.colors.borderGradient,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            val avatarContentColor = if (brush == SoftTheme.colors.accentGradient && SoftTheme.colors.isDark) {
                Color(0xFF070B14)
            } else {
                Color.White
            }

            if (icon != null) {
                Icon(
                    imageVector = icon,
                    contentDescription = name,
                    tint = avatarContentColor,
                    modifier = Modifier.size(size * 0.5f)
                )
            } else {
                Text(
                    text = name.take(1).uppercase(),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = avatarContentColor
                )
            }
        }
    }
}

/**
 * AuraIdentityCard: Prominent mobile presentation of the Local AI persona
 * directly matching the PC Local AI Control Center identity with larger avatar presentation,
 * airgapped model badge, and persona selection strip.
 */
@Composable
fun AuraIdentityCard(
    modifier: Modifier = Modifier,
    personaName: String = "Aura",
    statusText: String = "Active & Airgapped",
    modelName: String = "Llama-3.1-8B-Instruct (Q4_K_M)",
    selectedPersona: String = "Aura",
    onSelectPersona: (String) -> Unit = {},
    testTag: String = "aura_identity_card"
) {
    val personas = listOf("Aura", "Chronos", "Nexus", "Lyra", "Zephyr")

    SoftGlassCard(
        modifier = modifier.testTag(testTag),
        elevation = SoftTheme.tokens.elevations.card
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg)
        ) {
            // Header Row with 56dp Cognitive Core Avatar & Identity
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                SoftAvatar(
                    name = personaName,
                    size = 56.dp,
                    icon = Icons.Default.AutoAwesome,
                    statusColor = SoftTheme.colors.statusSuccess,
                    testTag = "aura_core_avatar"
                )

                Spacer(modifier = Modifier.width(SoftTheme.spacing.md))

                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                    ) {
                        Text(
                            text = personaName,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                        StatusBadge(
                            text = "100% LOCAL",
                            severity = StatusSeverity.Success,
                            hasDot = false
                        )
                    }

                    Spacer(modifier = Modifier.height(2.dp))

                    Text(
                        text = statusText,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )

                    Text(
                        text = modelName,
                        style = MonospaceTelemetry.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.accentBlue
                    )
                }
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.md))

            // Persona selection pills (inspired by desktop control center assistant tab)
            Text(
                text = "Assistant Persona",
                style = MaterialTheme.typography.labelSmall,
                color = SoftTheme.colors.textMuted
            )

            Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
            ) {
                personas.forEach { persona ->
                    val isSelected = persona == selectedPersona
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(
                                if (isSelected) SoftTheme.colors.accentCyan.copy(alpha = 0.18f)
                                else SoftTheme.colors.surfacePressed
                            )
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .clickable { onSelectPersona(persona) }
                            .padding(horizontal = SoftTheme.spacing.md, vertical = 6.dp)
                    ) {
                        Text(
                            text = persona,
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                            color = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.textSecondary
                        )
                    }
                }
            }
        }
    }
}
