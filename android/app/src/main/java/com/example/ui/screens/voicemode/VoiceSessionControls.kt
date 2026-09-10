package com.example.ui.screens.voicemode

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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Handshake
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.VoiceSemanticState
import com.example.ui.theme.SoftTheme

import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.style.TextOverflow

/**
 * Control bar for the dedicated Voice Mode session.
 * Implements the 4 required controls:
 * 1. Mute microphone
 * 2. Interrupt
 * 3. End session
 * 4. Optional text fallback
 * Audited for large font sizes and 48dp+ accessibility touch targets.
 */
@Composable
fun VoiceSessionControls(
    isMuted: Boolean,
    onToggleMute: () -> Unit,
    onInterrupt: () -> Unit,
    onEndSession: () -> Unit,
    onOpenTextFallback: () -> Unit,
    isSpeakingOrThinking: Boolean,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .testTag("voice_session_controls")
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(SoftTheme.colors.surfaceElevated)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Control 1: Mute Microphone
        ControlButton(
            icon = if (isMuted) Icons.Default.MicOff else Icons.Default.Mic,
            label = if (isMuted) "Unmute" else "Mute",
            isActive = isMuted,
            activeColor = SoftTheme.colors.statusWarning,
            inactiveColor = SoftTheme.colors.textPrimary,
            testTag = "voice_control_mute",
            onClick = onToggleMute
        )

        // Control 2: Interrupt (User barge-in)
        ControlButton(
            icon = Icons.Default.PanTool,
            label = "Interrupt",
            isActive = isSpeakingOrThinking,
            activeColor = SoftTheme.colors.accentBlue,
            inactiveColor = SoftTheme.colors.textSecondary,
            testTag = "voice_control_interrupt",
            onClick = onInterrupt
        )

        // Control 3: End Session
        ControlButton(
            icon = Icons.Default.CallEnd,
            label = "End",
            isActive = true,
            activeColor = SoftTheme.colors.statusError,
            inactiveColor = SoftTheme.colors.statusError,
            testTag = "voice_control_end_session",
            onClick = onEndSession
        )

        // Control 4: Optional Text Fallback
        ControlButton(
            icon = Icons.Default.Keyboard,
            label = "Text",
            isActive = false,
            activeColor = SoftTheme.colors.accentBlue,
            inactiveColor = SoftTheme.colors.textPrimary,
            testTag = "voice_control_text_fallback",
            onClick = onOpenTextFallback
        )
    }
}

@Composable
private fun ControlButton(
    icon: ImageVector,
    label: String,
    isActive: Boolean,
    activeColor: Color,
    inactiveColor: Color,
    testTag: String,
    onClick: () -> Unit
) {
    val tintColor by animateColorAsState(
        targetValue = if (isActive) activeColor else inactiveColor,
        label = "control_tint"
    )

    val bgColor by animateColorAsState(
        targetValue = if (isActive) activeColor.copy(alpha = 0.14f) else SoftTheme.colors.surfaceWell,
        label = "control_bg"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier
            .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
            .clickable(onClick = onClick)
            .testTag(testTag)
            .padding(horizontal = 4.dp, vertical = 2.dp)
            .semantics {
                this.contentDescription = "$label button"
                this.role = Role.Button
            }
    ) {
        Box(
            modifier = Modifier
                .size(46.dp)
                .clip(CircleShape)
                .background(bgColor)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = if (isActive) activeColor.copy(alpha = 0.4f) else SoftTheme.colors.borderSubtle,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tintColor,
                modifier = Modifier.size(22.dp)
            )
        }

        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = if (isActive) activeColor else SoftTheme.colors.textSecondary,
            fontSize = 11.sp,
            fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
            maxLines = 1,
            softWrap = false,
            overflow = TextOverflow.Ellipsis
        )
    }
}

/**
 * Optional Text Fallback Bottom Sheet.
 * Allows user to type a query if they cannot speak or prefer text mode,
 * preserving voice session state.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceTextFallbackSheet(
    isOpen: Boolean,
    onDismiss: () -> Unit,
    inputText: String,
    onInputTextChange: (String) -> Unit,
    onSubmitText: (String) -> Unit
) {
    if (!isOpen) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.surfaceElevated,
        scrimColor = SoftTheme.colors.background.copy(alpha = 0.6f),
        dragHandle = null,
        modifier = Modifier.testTag("voice_text_fallback_sheet")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Text Fallback",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "Type your query while maintaining voice session context",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 11.sp
                    )
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close text fallback",
                        tint = SoftTheme.colors.textMuted
                    )
                }
            }

            // Text Input
            OutlinedTextField(
                value = inputText,
                onValueChange = onInputTextChange,
                placeholder = {
                    Text(
                        text = "e.g., Uy, ashita remind me at seven.",
                        color = SoftTheme.colors.textMuted,
                        fontSize = 14.sp
                    )
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("voice_text_fallback_input"),
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = SoftTheme.colors.surfaceWell,
                    unfocusedContainerColor = SoftTheme.colors.surfaceWell,
                    focusedBorderColor = SoftTheme.colors.accentBlue,
                    unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                    focusedTextColor = SoftTheme.colors.textPrimary,
                    unfocusedTextColor = SoftTheme.colors.textPrimary
                ),
                trailingIcon = {
                    IconButton(
                        onClick = {
                            if (inputText.isNotBlank()) {
                                onSubmitText(inputText)
                                onDismiss()
                            }
                        },
                        modifier = Modifier.testTag("voice_text_fallback_submit")
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.Send,
                            contentDescription = "Submit query",
                            tint = if (inputText.isNotBlank()) SoftTheme.colors.accentBlue else SoftTheme.colors.textMuted
                        )
                    }
                }
            )

            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}
