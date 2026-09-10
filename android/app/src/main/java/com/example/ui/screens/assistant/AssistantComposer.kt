package com.example.ui.screens.assistant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.LanguageOption
import com.example.ui.components.NavigationGlassSurface
import com.example.ui.theme.SoftTheme

/**
 * Mobile Input Composer for the Assistant workspace conforming strictly to Batch 4:
 * - Attachment/add
 * - Text input
 * - Language selector (Auto, English, Filipino / Tagalog, Japanese)
 * - Microphone (speech simulation)
 * - Send
 * - Stop generation
 * - Mixed-language prompt suggestions ("Remind me bukas.", "Android UIをチェック.", "Ashita check natin ito.")
 */
@Composable
fun AssistantComposer(
    inputText: String,
    onInputTextChange: (String) -> Unit,
    selectedLanguage: LanguageOption,
    onLanguageSelect: (LanguageOption) -> Unit,
    isGenerating: Boolean,
    isMicrophoneActive: Boolean,
    onToggleMicrophone: () -> Unit,
    attachments: List<String>,
    onAddAttachment: (String) -> Unit,
    onRemoveAttachment: (String) -> Unit,
    onSendMessage: (String?) -> Unit,
    onStopGeneration: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showAttachmentMenu by remember { mutableStateOf(false) }
    var showLanguageMenu by remember { mutableStateOf(false) }

    val sampleMixedPrompts = listOf(
        "Remind me bukas.",
        "Android UIをチェック.",
        "Ashita check natin ito.",
        "What's my schedule today?"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("assistant_composer"),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        // Quick Mixed-Language Suggestion Chips
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = SoftTheme.spacing.md),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            sampleMixedPrompts.forEach { prompt ->
                Box(
                    modifier = Modifier
                        .testTag("chip_prompt_${prompt.take(10)}")
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(SoftTheme.colors.surface)
                        .border(
                            width = SoftTheme.tokens.borders.hairline,
                            color = SoftTheme.colors.borderSubtle,
                            shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                        )
                        .clickable {
                            onInputTextChange(prompt)
                        }
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = prompt,
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 11.sp
                    )
                }
            }
        }

        // Active File Attachments preview row
        AnimatedVisibility(visible = attachments.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = SoftTheme.spacing.md),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                attachments.forEach { fileName ->
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.accentBlue.copy(alpha = 0.12f))
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = SoftTheme.colors.accentBlue.copy(alpha = 0.3f),
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .padding(start = 10.dp, top = 2.dp, bottom = 2.dp, end = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = fileName,
                            style = MaterialTheme.typography.labelSmall,
                            color = SoftTheme.colors.textPrimary,
                            fontSize = 11.sp
                        )
                        IconButton(
                            onClick = { onRemoveAttachment(fileName) },
                            modifier = Modifier.size(18.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Remove attachment",
                                tint = SoftTheme.colors.textMuted,
                                modifier = Modifier.size(12.dp)
                            )
                        }
                    }
                }
            }
        }

        // Main Composer Input Bar
        NavigationGlassSurface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = 4.dp),
            elevation = SoftTheme.tokens.elevations.subtle,
            shape = RoundedCornerShape(SoftTheme.tokens.corners.lg)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // Top control row: Language selector + Attachment button
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Left: Compact Language Selector Button
                    Box {
                        Row(
                            modifier = Modifier
                                .testTag("composer_language_button")
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                                .background(SoftTheme.colors.surfaceWell)
                                .border(
                                    width = SoftTheme.tokens.borders.hairline,
                                    color = SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                                )
                                .clickable { showLanguageMenu = true }
                                .padding(horizontal = 9.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Language,
                                contentDescription = null,
                                tint = SoftTheme.colors.accentBlue,
                                modifier = Modifier.size(13.dp)
                            )
                            Text(
                                text = selectedLanguage.label,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.SemiBold,
                                color = SoftTheme.colors.textPrimary,
                                fontSize = 11.sp
                            )
                        }

                        // Compact Language Picker Dropdown Menu
                        DropdownMenu(
                            expanded = showLanguageMenu,
                            onDismissRequest = { showLanguageMenu = false },
                            modifier = Modifier.background(SoftTheme.colors.surfaceElevated)
                        ) {
                            LanguageOption.entries.forEach { option ->
                                DropdownMenuItem(
                                    text = {
                                        Column {
                                            Text(
                                                text = option.label,
                                                style = MaterialTheme.typography.bodyMedium,
                                                fontWeight = if (option == selectedLanguage) FontWeight.Bold else FontWeight.Normal,
                                                color = if (option == selectedLanguage) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary
                                            )
                                            Text(
                                                text = option.samplePhrase,
                                                style = MaterialTheme.typography.labelSmall,
                                                color = SoftTheme.colors.textMuted,
                                                fontSize = 10.sp
                                            )
                                        }
                                    },
                                    onClick = {
                                        onLanguageSelect(option)
                                        showLanguageMenu = false
                                    },
                                    modifier = Modifier.testTag("lang_option_${option.code}")
                                )
                            }
                        }
                    }

                    // Right: Attachment Chooser Trigger
                    Box {
                        IconButton(
                            onClick = { showAttachmentMenu = true },
                            modifier = Modifier
                                .size(32.dp)
                                .testTag("composer_attachment_button")
                                .semantics { contentDescription = "Attach local file or telemetry dump" }
                        ) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = "Add attachment",
                                tint = SoftTheme.colors.textSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                        }

                        DropdownMenu(
                            expanded = showAttachmentMenu,
                            onDismissRequest = { showAttachmentMenu = false },
                            modifier = Modifier.background(SoftTheme.colors.surfaceElevated)
                        ) {
                            val mockFiles = listOf(
                                "telemetry_dump.json",
                                "android_ui_spec.kt",
                                "gpu_thermals.log",
                                "screenshot_tokens.png"
                            )
                            mockFiles.forEach { file ->
                                DropdownMenuItem(
                                    text = { Text(file, style = MaterialTheme.typography.bodySmall) },
                                    onClick = {
                                        onAddAttachment(file)
                                        showAttachmentMenu = false
                                    }
                                )
                            }
                        }
                    }
                }

                // Middle & Bottom Row: Text input + Mic + Send / Stop Button
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    // Text Input
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .heightIn(min = 40.dp, max = 120.dp)
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                            .background(SoftTheme.colors.surfaceWell)
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = SoftTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
                            )
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        contentAlignment = Alignment.CenterStart
                    ) {
                        if (inputText.isEmpty()) {
                            Text(
                                text = "Message Local Core (mixed language supported)...",
                                style = MaterialTheme.typography.bodyMedium,
                                color = SoftTheme.colors.textMuted,
                                fontSize = 14.sp
                            )
                        }
                        BasicTextField(
                            value = inputText,
                            onValueChange = onInputTextChange,
                            textStyle = TextStyle(
                                color = SoftTheme.colors.textPrimary,
                                fontSize = 14.sp,
                                lineHeight = 20.sp
                            ),
                            cursorBrush = SolidColor(SoftTheme.colors.accentBlue),
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("composer_text_input")
                        )
                    }

                    // Microphone Toggle Button (Simulated voice recording)
                    MicrophoneButton(
                        isActive = isMicrophoneActive,
                        onClick = onToggleMicrophone
                    )

                    // Send or Stop Generation Button
                    if (isGenerating) {
                        // Stop Generation Button
                        IconButton(
                            onClick = onStopGeneration,
                            modifier = Modifier
                                .size(40.dp)
                                .testTag("composer_stop_button")
                                .clip(CircleShape)
                                .background(SoftTheme.colors.statusWarning.copy(alpha = 0.2f))
                                .border(
                                    width = 1.dp,
                                    color = SoftTheme.colors.statusWarning,
                                    shape = CircleShape
                                )
                                .semantics { contentDescription = "Stop generation" }
                        ) {
                            Icon(
                                imageVector = Icons.Default.Stop,
                                contentDescription = "Stop",
                                tint = SoftTheme.colors.statusWarning,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    } else {
                        // Send Button
                        val canSend = inputText.isNotBlank() || attachments.isNotEmpty()
                        IconButton(
                            onClick = { onSendMessage(null) },
                            enabled = canSend,
                            modifier = Modifier
                                .size(40.dp)
                                .testTag("composer_send_button")
                                .clip(CircleShape)
                                .background(
                                    if (canSend) SoftTheme.colors.accentBlue else SoftTheme.colors.surfaceWell
                                )
                                .semantics { contentDescription = "Send message" }
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.Send,
                                contentDescription = "Send",
                                tint = if (canSend) Color.White else SoftTheme.colors.textMuted,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun MicrophoneButton(
    isActive: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "micPulse")
    val scale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = if (isActive) 1.2f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(500),
            repeatMode = RepeatMode.Reverse
        ),
        label = "micScale"
    )

    val bgColor by animateColorAsState(
        targetValue = if (isActive) SoftTheme.colors.statusError.copy(alpha = 0.2f) else SoftTheme.colors.surfaceWell,
        label = "micBg"
    )

    val iconTint by animateColorAsState(
        targetValue = if (isActive) SoftTheme.colors.statusError else SoftTheme.colors.textSecondary,
        label = "micTint"
    )

    IconButton(
        onClick = onClick,
        modifier = modifier
            .size(40.dp)
            .testTag("composer_mic_button")
            .clip(CircleShape)
            .background(bgColor)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = if (isActive) SoftTheme.colors.statusError else SoftTheme.colors.borderSubtle,
                shape = CircleShape
            )
            .semantics { contentDescription = if (isActive) "Listening... tap to stop" else "Record voice prompt" }
    ) {
        Icon(
            imageVector = Icons.Default.Mic,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier
                .size(18.dp)
                .scale(if (isActive) scale else 1f)
        )
    }
}
