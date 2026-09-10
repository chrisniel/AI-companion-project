package com.example.ui.screens.assistant

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.ProviderMode
import com.example.ui.components.NavigationGlassSurface
import com.example.ui.theme.SoftTheme

/**
 * Mobile Assistant Header conforming strictly to Batch 4 specifications:
 * - Conversation title
 * - Local / Remote / Offline connection state
 * - Current provider mode
 * - Conversation history action
 */
@Composable
fun AssistantHeader(
    conversationTitle: String,
    providerMode: ProviderMode,
    onOpenHistory: () -> Unit,
    onOpenProviderPicker: () -> Unit,
    isDarkTheme: Boolean,
    onToggleTheme: () -> Unit,
    onOpenVoiceMode: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    NavigationGlassSurface(
        modifier = modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .testTag("assistant_header"),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            // Main row: History button + Conversation Title + Theme Toggle
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Left: History drawer button + Title
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs),
                    modifier = Modifier.weight(1f, fill = false)
                ) {
                    IconButton(
                        onClick = onOpenHistory,
                        modifier = Modifier
                            .size(38.dp)
                            .testTag("assistant_history_button")
                            .semantics { contentDescription = "Open conversation history" }
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.Chat,
                            contentDescription = "History",
                            tint = SoftTheme.colors.accentBlue,
                            modifier = Modifier.size(20.dp)
                        )
                    }

                    Column {
                        Text(
                            text = conversationTitle,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.testTag("conversation_title")
                        )
                    }
                }

                Spacer(modifier = Modifier.width(8.dp))

                // Right: Voice Mode Button + Theme Toggle
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    // Dedicated Voice Mode Pill Button
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.accentBlue.copy(alpha = 0.12f))
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = SoftTheme.colors.accentBlue.copy(alpha = 0.3f),
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .clickable(onClick = onOpenVoiceMode)
                            .padding(horizontal = 9.dp, vertical = 5.dp)
                            .testTag("assistant_open_voice_mode_button")
                            .semantics { contentDescription = "Open Dedicated Voice Mode" },
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.GraphicEq,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentBlue,
                            modifier = Modifier.size(15.dp)
                        )
                        Text(
                            text = "Voice",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.accentBlue,
                            fontSize = 11.sp
                        )
                    }

                    // Theme Toggle
                    IconButton(
                        onClick = onToggleTheme,
                        modifier = Modifier
                            .size(36.dp)
                            .testTag("assistant_theme_toggle")
                            .semantics {
                                contentDescription = if (isDarkTheme) "Switch to Light theme" else "Switch to Dark theme"
                            }
                    ) {
                        Icon(
                            imageVector = if (isDarkTheme) Icons.Default.LightMode else Icons.Default.DarkMode,
                            contentDescription = null,
                            tint = SoftTheme.colors.textSecondary,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            }

            // Secondary metadata row: Local/Remote/Offline State + Current Provider Mode
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 6.dp, end = 4.dp, bottom = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Connection State Badge (Local / Remote / Offline)
                AssistantConnectionBadge(state = providerMode.state)

                // Current Provider Mode Pill (Tap to switch provider)
                AssistantProviderModePill(
                    providerMode = providerMode,
                    onClick = onOpenProviderPicker
                )
            }
        }
    }
}

@Composable
fun AssistantConnectionBadge(
    state: CoreConnectionState,
    modifier: Modifier = Modifier
) {
    val (color, label, icon) = when (state) {
        CoreConnectionState.Local -> Triple(SoftTheme.colors.statusSuccess, "Local Core", Icons.Default.Memory)
        CoreConnectionState.Remote -> Triple(SoftTheme.colors.accentCyan, "Remote Mesh", Icons.Default.Public)
        CoreConnectionState.Connecting -> Triple(SoftTheme.colors.accentCyan, "Connecting...", Icons.Default.Public)
        CoreConnectionState.Reconnecting -> Triple(SoftTheme.colors.statusWarning, "Reconnecting", Icons.Default.Public)
        CoreConnectionState.Offline -> Triple(SoftTheme.colors.textMuted, "Offline Standalone", Icons.Default.WifiOff)
    }

    val animatedDotColor by animateColorAsState(targetValue = color, label = "dotColor")

    Row(
        modifier = modifier
            .testTag("assistant_connection_badge")
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(color.copy(alpha = 0.12f))
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = color.copy(alpha = 0.35f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(animatedDotColor)
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = color,
            fontSize = 11.sp
        )
    }
}

@Composable
fun AssistantProviderModePill(
    providerMode: ProviderMode,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .testTag("assistant_provider_mode_pill")
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(SoftTheme.colors.surface)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .clickable(
                role = Role.Button,
                onClickLabel = "Change AI Provider Mode",
                onClick = onClick
            )
            .padding(horizontal = 9.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = providerMode.name,
            style = MaterialTheme.typography.labelSmall,
            color = SoftTheme.colors.textPrimary,
            fontWeight = FontWeight.Medium,
            fontSize = 11.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = SoftTheme.colors.textMuted,
            modifier = Modifier.size(12.dp)
        )
    }
}
