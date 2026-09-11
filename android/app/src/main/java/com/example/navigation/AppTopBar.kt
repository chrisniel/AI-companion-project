package com.example.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.ui.components.CompactConnectionIndicator
import com.example.ui.components.NavigationGlassSurface
import com.example.ui.components.SoftAvatar
import com.example.ui.theme.SoftTheme

/**
 * Compact contextual top bar adhering to the Soft Glass design system.
 * Displays:
 *  - Page title (or back button for sub-destinations)
 *  - Local AI Core connection status with interactive cycle
 *  - Optional contextual action (e.g., theme toggle)
 *  - User profile avatar
 */
@Composable
fun AppTopBar(
    title: String,
    canNavigateBack: Boolean,
    onNavigateBack: () -> Unit,
    connectionInfo: ConnectionInfo,
    onCycleConnectionState: () -> Unit,
    isDarkTheme: Boolean = false,
    onToggleTheme: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    userName: String = "Chris",
    onAvatarClick: () -> Unit = {}
) {
    NavigationGlassSurface(
        modifier = modifier
            .fillMaxWidth()
            .statusBarsPadding(),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Left area: Back button or User Avatar + Title
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs),
                modifier = Modifier.weight(1f, fill = false)
            ) {
                if (canNavigateBack) {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier
                            .size(36.dp)
                            .testTag("topbar_back_button")
                            .semantics { contentDescription = "Navigate back" }
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = SoftTheme.colors.textPrimary,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                } else {
                    Box(
                        modifier = Modifier
                            .clip(CircleShape)
                            .clickable(
                                role = Role.Button,
                                onClick = onAvatarClick
                            )
                    ) {
                        SoftAvatar(
                            name = userName,
                            size = 32.dp,
                            statusColor = when (connectionInfo.state) {
                                CoreConnectionState.Local -> SoftTheme.colors.statusSuccess
                                CoreConnectionState.Remote -> SoftTheme.colors.accentCyan
                                CoreConnectionState.Connecting -> SoftTheme.colors.statusWarning
                                CoreConnectionState.Reconnecting -> SoftTheme.colors.statusWarning
                                CoreConnectionState.Offline -> SoftTheme.colors.statusError
                            },
                            testTag = "topbar_user_avatar"
                        )
                    }
                }

                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))

            // Right area: Compact Connection Status Indicator + Theme toggle
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
            ) {
                // Interactive Connection Indicator (tap to cycle mock states)
                Box(
                    modifier = Modifier
                        .testTag("topbar_connection_indicator")
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .clickable(
                            role = Role.Button,
                            onClickLabel = "Cycle connection state",
                            onClick = onCycleConnectionState
                        )
                ) {
                    CompactConnectionIndicator(
                        state = connectionInfo.state,
                        label = connectionInfo.label,
                        latencyMs = connectionInfo.latencyMs
                    )
                }

                // Theme switch button (only rendered if onToggleTheme handler provided)
                if (onToggleTheme != null) {
                    IconButton(
                        onClick = onToggleTheme,
                        modifier = Modifier
                            .size(36.dp)
                            .testTag("topbar_theme_toggle")
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
        }
    }
}
