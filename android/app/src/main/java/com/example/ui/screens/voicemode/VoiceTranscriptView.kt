package com.example.ui.screens.voicemode

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.MessageSender
import com.example.domain.model.VoiceSemanticState
import com.example.domain.model.VoiceTranscriptTurn
import com.example.ui.theme.SoftTheme

/**
 * Live Transcript View for Voice Mode.
 * Demonstrates the code-switching mock transcript:
 * "Uy, ashita remind me at seven."
 * Preserves the exact verbatim utterance without automatic translation.
 */
@Composable
fun VoiceTranscriptView(
    semanticState: VoiceSemanticState,
    turns: List<VoiceTranscriptTurn>,
    interimText: String,
    activeToolName: String?,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("voice_transcript_container"),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Section Label & Multilingual Preservation Tag
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Translate,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentBlue,
                    modifier = Modifier.size(13.dp)
                )
                Text(
                    text = "LIVE TRANSCRIPT",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textSecondary,
                    letterSpacing = 0.8.sp
                )
            }

            // Preservation Note
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                    .background(SoftTheme.colors.accentCyan.copy(alpha = 0.12f))
                    .border(
                        width = SoftTheme.tokens.borders.hairline,
                        color = SoftTheme.colors.accentCyan.copy(alpha = 0.3f),
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                    )
                    .padding(horizontal = 8.dp, vertical = 2.dp)
            ) {
                Text(
                    text = "Verbatim Code-Switching",
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.accentBlue,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        // Main Transcript Bubble / Card
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(SoftTheme.tokens.corners.lg))
                .background(SoftTheme.colors.surfaceElevated)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = SoftTheme.colors.borderSubtle,
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.lg)
                )
                .padding(14.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                // User Turn: Multilingual Code-Switching
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(16.dp)
                                    .clip(CircleShape)
                                    .background(SoftTheme.colors.accentBlue.copy(alpha = 0.15f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Person,
                                    contentDescription = null,
                                    tint = SoftTheme.colors.accentBlue,
                                    modifier = Modifier.size(11.dp)
                                )
                            }
                            Text(
                                text = "You (User)",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = SoftTheme.colors.textPrimary
                            )
                        }

                        Text(
                            text = "98% Acoustic Match",
                            style = MaterialTheme.typography.labelSmall,
                            color = SoftTheme.colors.statusSuccess,
                            fontSize = 10.sp
                        )
                    }

                    // The exact required code-switching mock transcript:
                    Text(
                        text = "\"Uy, ashita remind me at seven.\"",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.textPrimary,
                        lineHeight = 22.sp,
                        modifier = Modifier.testTag("code_switching_transcript_text")
                    )

                    // Phoneme breakdown chips demonstrating multilingual comprehension without auto-translating
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        LanguageTagPill(tag = "FIL", phrase = "Uy (Hey)")
                        LanguageTagPill(tag = "JA", phrase = "明日 (Tomorrow)")
                        LanguageTagPill(tag = "EN", phrase = "remind me at seven")
                    }
                }

                // Assistant Response Stream (if in Thinking, Executing Tool, or Speaking)
                val showAssistantResponse = semanticState in listOf(
                    VoiceSemanticState.THINKING,
                    VoiceSemanticState.EXECUTING_TOOL,
                    VoiceSemanticState.SPEAKING,
                    VoiceSemanticState.INTERRUPTED
                )

                AnimatedVisibility(
                    visible = showAssistantResponse,
                    enter = fadeIn(),
                    exit = fadeOut()
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(SoftTheme.colors.surfaceWell)
                            .padding(10.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(5.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(16.dp)
                                        .clip(CircleShape)
                                        .background(SoftTheme.colors.accentCyan.copy(alpha = 0.15f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.AutoAwesome,
                                        contentDescription = null,
                                        tint = SoftTheme.colors.accentCyan,
                                        modifier = Modifier.size(10.dp)
                                    )
                                }
                                Text(
                                    text = "Assistant (Aria)",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = SoftTheme.colors.textPrimary
                                )
                            }

                            if (semanticState == VoiceSemanticState.SPEAKING) {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                                        .background(SoftTheme.colors.accentBlue.copy(alpha = 0.15f))
                                        .padding(horizontal = 6.dp, vertical = 2.dp)
                                ) {
                                    Text(
                                        text = "STREAMING TTS",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = SoftTheme.colors.accentBlue,
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }

                        // Multilingual contextual response
                        Text(
                            text = if (semanticState == VoiceSemanticState.INTERRUPTED) {
                                "Sige! I've set a rem— [Interrupted by user]"
                            } else {
                                "Sige! I've set a reminder for tomorrow (明日) at 7:00 AM."
                            },
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (semanticState == VoiceSemanticState.INTERRUPTED) SoftTheme.colors.statusWarning else SoftTheme.colors.textPrimary,
                            lineHeight = 19.sp,
                            modifier = Modifier.testTag("assistant_voice_response_text")
                        )

                        // If executing tool, show slot pill
                        if (semanticState == VoiceSemanticState.EXECUTING_TOOL || semanticState == VoiceSemanticState.SPEAKING) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.padding(top = 2.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = SoftTheme.colors.statusSuccess,
                                    modifier = Modifier.size(12.dp)
                                )
                                Text(
                                    text = "slot: calendar_reminder.create(time=\"07:00\", date=\"tomorrow\")",
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 10.sp,
                                    color = SoftTheme.colors.accentBlue
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LanguageTagPill(tag: String, phrase: String) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(SoftTheme.colors.surfaceWell)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = 6.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        Text(
            text = tag,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentBlue,
            fontSize = 9.sp
        )
        Text(
            text = phrase,
            style = MaterialTheme.typography.labelSmall,
            color = SoftTheme.colors.textSecondary,
            fontSize = 10.sp
        )
    }
}
