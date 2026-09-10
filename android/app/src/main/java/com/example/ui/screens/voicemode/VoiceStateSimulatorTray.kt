package com.example.ui.screens.voicemode

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.VoiceSemanticState
import com.example.ui.theme.SoftTheme

/**
 * Interactive Semantic State Selector & Simulation Tray.
 * Enables direct verification and inspection of all 10 required semantic states:
 * 1. Idle
 * 2. Listening
 * 3. Transcribing
 * 4. Thinking
 * 5. Executing Tool
 * 6. Speaking
 * 7. Interrupted
 * 8. Reconnecting
 * 9. Offline
 * 10. Error
 */
@Composable
fun VoiceStateSimulatorTray(
    currentState: VoiceSemanticState,
    onSelectState: (VoiceSemanticState) -> Unit,
    onAutoSimulateTurn: () -> Unit,
    isExpanded: Boolean,
    onToggleExpand: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("voice_state_simulator_tray")
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(SoftTheme.colors.surfaceElevated)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        // Tray Header: Title + Current State + Collapse Toggle
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onToggleExpand)
                .padding(horizontal = 6.dp, vertical = 2.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Tune,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentBlue,
                    modifier = Modifier.size(13.dp)
                )
                Text(
                    text = "SEMANTIC STATE SIMULATOR (10 STATES)",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textSecondary,
                    letterSpacing = 0.6.sp
                )
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                // Auto simulate button
                Box(
                    modifier = Modifier
                        .testTag("voice_simulate_cycle_button")
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(SoftTheme.colors.accentBlue.copy(alpha = 0.12f))
                        .clickable(onClick = onAutoSimulateTurn)
                        .padding(horizontal = 8.dp, vertical = 2.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.PlayArrow,
                            contentDescription = "Simulate Turn",
                            tint = SoftTheme.colors.accentBlue,
                            modifier = Modifier.size(11.dp)
                        )
                        Text(
                            text = "Auto-Cycle Turn",
                            style = MaterialTheme.typography.labelSmall,
                            color = SoftTheme.colors.accentBlue,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                Icon(
                    imageVector = if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = if (isExpanded) "Collapse state simulator" else "Expand state simulator",
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        // Horizontal scrollable state chips
        AnimatedVisibility(visible = isExpanded) {
            val scrollState = rememberScrollState()
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(scrollState)
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                VoiceSemanticState.entries.forEach { state ->
                    val isSelected = state == currentState
                    val stateColor = when (state) {
                        VoiceSemanticState.IDLE -> SoftTheme.colors.textMuted
                        VoiceSemanticState.LISTENING -> SoftTheme.colors.accentCyan
                        VoiceSemanticState.TRANSCRIBING -> SoftTheme.colors.accentViolet
                        VoiceSemanticState.THINKING -> SoftTheme.colors.accentBlue
                        VoiceSemanticState.EXECUTING_TOOL -> SoftTheme.colors.accentCyan
                        VoiceSemanticState.SPEAKING -> SoftTheme.colors.accentBlue
                        VoiceSemanticState.INTERRUPTED -> SoftTheme.colors.statusWarning
                        VoiceSemanticState.RECONNECTING -> SoftTheme.colors.accentAmber
                        VoiceSemanticState.OFFLINE -> SoftTheme.colors.textMuted
                        VoiceSemanticState.ERROR -> SoftTheme.colors.statusError
                    }

                    Box(
                        modifier = Modifier
                            .testTag("state_pill_${state.name.lowercase()}")
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(
                                if (isSelected) stateColor.copy(alpha = 0.16f) else SoftTheme.colors.surfaceWell
                            )
                            .border(
                                width = if (isSelected) 1.5.dp else SoftTheme.tokens.borders.hairline,
                                color = if (isSelected) stateColor else SoftTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .clickable { onSelectState(state) }
                            .padding(horizontal = 10.dp, vertical = 5.dp)
                            .semantics { contentDescription = "Select semantic state ${state.label}" },
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(if (isSelected) stateColor else SoftTheme.colors.textMuted)
                            )
                            Text(
                                text = state.label,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) SoftTheme.colors.textPrimary else SoftTheme.colors.textSecondary,
                                fontSize = 11.sp
                            )
                        }
                    }
                }
            }
        }
    }
}
