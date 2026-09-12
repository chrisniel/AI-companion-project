package com.example.ui.screens.characters

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.CharacterProfile
import com.example.ui.components.SoftGlassCard
import com.example.ui.theme.SoftTheme

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CharacterCard(
    character: CharacterProfile,
    isAuditioning: Boolean,
    onActivate: () -> Unit,
    onEdit: () -> Unit,
    onDuplicate: () -> Unit,
    onDelete: () -> Unit,
    onAuditionVoice: () -> Unit,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("character_card_${character.id}")
            .border(
                width = if (character.isActive) 1.5.dp else 1.dp,
                color = if (character.isActive) SoftTheme.colors.accentActive else SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(16.dp)
            )
            .clickable(onClick = onEdit)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            // Top Row: Avatar + Display Name + Voice + Active State Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Avatar (Respects AvatarDisplayMode)
                CharacterAvatarView(
                    avatarStyle = character.avatarStyle,
                    displayMode = character.avatarDisplay,
                    size = 56.dp,
                    isActive = character.isActive,
                    isAuditioning = isAuditioning
                )

                Spacer(modifier = Modifier.width(14.dp))

                // Identity: Display Name & Voice
                Column(
                    modifier = Modifier.weight(1f)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = character.displayName,
                            style = SoftTheme.typography.titleMedium,
                            color = SoftTheme.colors.textPrimary,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )

                        if (character.isCustom) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(SoftTheme.colors.surfaceCard)
                                    .border(1.dp, SoftTheme.colors.borderSubtle, RoundedCornerShape(4.dp))
                                    .padding(horizontal = 6.dp, vertical = 2.dp)
                            ) {
                                Text(
                                    text = "Custom",
                                    style = SoftTheme.typography.caption.copy(fontSize = 10.sp),
                                    color = SoftTheme.colors.textSecondary
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(3.dp))

                    // Voice Information
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.VolumeUp,
                            contentDescription = "Voice",
                            tint = SoftTheme.colors.accentPrimary,
                            modifier = Modifier.size(14.dp)
                        )
                        Text(
                            text = character.voice.name,
                            style = SoftTheme.typography.bodySmall,
                            color = SoftTheme.colors.textSecondary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }

                // Active State Indicator / Toggle
                if (character.isActive) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(SoftTheme.colors.success.copy(alpha = 0.15f))
                            .border(1.dp, SoftTheme.colors.success.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                            .testTag("character_active_badge_${character.id}"),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = "Active Character",
                                tint = SoftTheme.colors.success,
                                modifier = Modifier.size(14.dp)
                            )
                            Text(
                                text = "Active",
                                style = SoftTheme.typography.labelSmall,
                                color = SoftTheme.colors.success,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                } else {
                    OutlinedButton(
                        onClick = onActivate,
                        modifier = Modifier
                            .height(32.dp)
                            .testTag("character_activate_button_${character.id}"),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Text(
                            text = "Set Active",
                            style = SoftTheme.typography.labelSmall,
                            color = SoftTheme.colors.accentActive
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Persona description
            Text(
                text = character.persona,
                style = SoftTheme.typography.bodyMedium,
                color = SoftTheme.colors.textPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Behavioral & Linguistic Tags
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // Avatar Display Mode Tag
                TagChip(label = "Avatar: ${character.avatarDisplay.title}")

                // Code Switching Style Tag
                TagChip(label = character.languageStyle.codeSwitchingStyle.title)

                // Japanese Tone Tag
                TagChip(label = "Tone: ${character.languageStyle.japaneseTone.title}")

                // Tagalog Frequency Tag
                if (character.languageStyle.tagalogFrequency.percentage > 0) {
                    TagChip(label = "Tagalog: ${character.languageStyle.tagalogFrequency.title}")
                }

                // Japanese Frequency Tag
                if (character.languageStyle.japaneseFrequency.percentage > 0) {
                    TagChip(label = "Japanese: ${character.languageStyle.japaneseFrequency.title}")
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Sample dialogue bubble
            if (character.sampleDialogue.isNotBlank()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(SoftTheme.colors.surfaceCard.copy(alpha = 0.7f))
                        .border(1.dp, SoftTheme.colors.borderSubtle, RoundedCornerShape(10.dp))
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Translate,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentPrimary,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = "\"${character.sampleDialogue}\"",
                            style = SoftTheme.typography.caption.copy(fontStyle = androidx.compose.ui.text.font.FontStyle.Italic),
                            color = SoftTheme.colors.textSecondary,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))
            }

            // Bottom Actions: Voice Audition Button + Edit + Duplicate + Delete
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Mock Voice Audition Pill
                FilledTonalButton(
                    onClick = onAuditionVoice,
                    modifier = Modifier
                        .height(34.dp)
                        .testTag("voice_audition_button_${character.id}"),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = if (isAuditioning) SoftTheme.colors.accentActive.copy(alpha = 0.2f) else SoftTheme.colors.surfaceCard
                    ),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Icon(
                        imageVector = if (isAuditioning) Icons.Default.Stop else Icons.Default.PlayArrow,
                        contentDescription = "Audition Voice",
                        tint = if (isAuditioning) SoftTheme.colors.accentActive else SoftTheme.colors.textPrimary,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (isAuditioning) "Auditioning..." else "Audition Voice",
                        style = SoftTheme.typography.labelSmall,
                        color = if (isAuditioning) SoftTheme.colors.accentActive else SoftTheme.colors.textPrimary
                    )
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    // Duplicate Action
                    IconButton(
                        onClick = onDuplicate,
                        modifier = Modifier
                            .size(34.dp)
                            .testTag("character_duplicate_button_${character.id}")
                    ) {
                        Icon(
                            imageVector = Icons.Default.ContentCopy,
                            contentDescription = "Duplicate Profile",
                            tint = SoftTheme.colors.textSecondary,
                            modifier = Modifier.size(18.dp)
                        )
                    }

                    // Edit Action
                    IconButton(
                        onClick = onEdit,
                        modifier = Modifier
                            .size(34.dp)
                            .testTag("character_edit_button_${character.id}")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Edit,
                            contentDescription = "Edit Character",
                            tint = SoftTheme.colors.accentPrimary,
                            modifier = Modifier.size(18.dp)
                        )
                    }

                    // Delete Action (Only for custom characters)
                    if (character.isCustom) {
                        IconButton(
                            onClick = onDelete,
                            modifier = Modifier
                                .size(34.dp)
                                .testTag("character_delete_button_${character.id}")
                        ) {
                            Icon(
                                imageVector = Icons.Default.Delete,
                                contentDescription = "Delete Profile",
                                tint = SoftTheme.colors.error,
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
private fun TagChip(
    label: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(SoftTheme.colors.surfaceCard)
            .border(1.dp, SoftTheme.colors.borderSubtle, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(
            text = label,
            style = SoftTheme.typography.caption.copy(fontSize = 11.sp),
            color = SoftTheme.colors.textSecondary
        )
    }
}
