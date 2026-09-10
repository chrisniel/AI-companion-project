package com.example.ui.screens.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.ProviderMode
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Bottom sheet for switching the active Local AI Core provider routing mode:
 * Local, LAN Core, Remote mesh tunnel, or Offline standalone.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProviderModePickerSheet(
    isOpen: Boolean,
    onDismiss: () -> Unit,
    currentMode: ProviderMode,
    availableModes: List<ProviderMode>,
    onSelectMode: (ProviderMode) -> Unit,
    modifier: Modifier = Modifier
) {
    if (!isOpen) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.surfaceElevated,
        scrimColor = SoftTheme.colors.background.copy(alpha = 0.6f),
        dragHandle = null,
        modifier = modifier.testTag("provider_mode_sheet")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Core Provider Routing",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "Select execution node and privacy boundary",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textMuted,
                        fontSize = 11.sp
                    )
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close provider sheet",
                        tint = SoftTheme.colors.textSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                availableModes.forEach { mode ->
                    val isSelected = mode.id == currentMode.id
                    val icon = when (mode.state) {
                        CoreConnectionState.Local -> Icons.Default.Memory
                        CoreConnectionState.Remote -> Icons.Default.Public
                        CoreConnectionState.Connecting -> Icons.Default.Public
                        CoreConnectionState.Reconnecting -> Icons.Default.Public
                        CoreConnectionState.Offline -> Icons.Default.WifiOff
                    }
                    val stateColor = when (mode.state) {
                        CoreConnectionState.Local -> SoftTheme.colors.statusSuccess
                        CoreConnectionState.Remote -> SoftTheme.colors.accentCyan
                        CoreConnectionState.Connecting -> SoftTheme.colors.accentCyan
                        CoreConnectionState.Reconnecting -> SoftTheme.colors.statusWarning
                        CoreConnectionState.Offline -> SoftTheme.colors.textMuted
                    }

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("provider_option_${mode.id}")
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                            .background(
                                if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.08f) else SoftTheme.colors.surface
                            )
                            .border(
                                width = if (isSelected) SoftTheme.tokens.borders.medium else SoftTheme.tokens.borders.hairline,
                                color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
                            )
                            .clickable(
                                role = Role.RadioButton,
                                onClick = { onSelectMode(mode) }
                            )
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(stateColor.copy(alpha = 0.15f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = icon,
                                    contentDescription = null,
                                    tint = stateColor,
                                    modifier = Modifier.size(18.dp)
                                )
                            }

                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(
                                    text = mode.name,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = SoftTheme.colors.textPrimary
                                )
                                Text(
                                    text = mode.nodeHost,
                                    style = MonospaceTelemetry,
                                    fontSize = 11.sp,
                                    color = stateColor
                                )
                                Text(
                                    text = mode.description,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = SoftTheme.colors.textSecondary,
                                    fontSize = 11.sp
                                )
                            }
                        }

                        if (isSelected) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = "Active provider",
                                tint = SoftTheme.colors.accentBlue,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
