package com.example.ui.screens.characters

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import com.example.ui.components.softBounceOverscroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.RecordVoiceOver
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Style
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.AvatarDisplayMode
import com.example.domain.model.AvatarStyle
import com.example.domain.model.CharacterProfile
import com.example.domain.model.CodeSwitchingStyle
import com.example.domain.model.FrequencyLevel
import com.example.domain.model.JapaneseTone
import com.example.domain.model.VoiceProfile
import com.example.ui.theme.SoftTheme

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun CharacterEditorSheet(
    character: CharacterProfile,
    availableVoices: List<VoiceProfile>,
    availableAvatarStyles: List<AvatarStyle>,
    isAuditioning: Boolean,
    onAuditionVoice: (String) -> Unit,
    onSave: () -> Unit,
    onCancel: () -> Unit,
    onNameChange: (String) -> Unit,
    onPersonaChange: (String) -> Unit,
    onResponseStyleChange: (String) -> Unit,
    onSpeakingStyleChange: (String) -> Unit,
    onAvatarStyleChange: (AvatarStyle) -> Unit,
    onAvatarDisplayChange: (AvatarDisplayMode) -> Unit,
    onVoiceChange: (VoiceProfile) -> Unit,
    onPrimaryLanguageChange: (String) -> Unit,
    onToggleSecondaryLanguage: (String) -> Unit,
    onMatchUserLanguageChange: (Boolean) -> Unit,
    onCodeSwitchingChange: (CodeSwitchingStyle) -> Unit,
    onTagalogFreqChange: (FrequencyLevel) -> Unit,
    onJapaneseFreqChange: (FrequencyLevel) -> Unit,
    onJapaneseToneChange: (JapaneseTone) -> Unit,
    modifier: Modifier = Modifier
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scrollState = rememberScrollState()

    ModalBottomSheet(
        onDismissRequest = onCancel,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.background,
        contentColor = SoftTheme.colors.textPrimary,
        modifier = modifier.testTag("character_editor_sheet")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .padding(horizontal = 20.dp)
        ) {
            // Top Bar: Title & Action Buttons
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = onCancel,
                        modifier = Modifier.testTag("character_editor_cancel_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Cancel",
                            tint = SoftTheme.colors.textSecondary
                        )
                    }
                    Spacer(modifier = Modifier.width(6.dp))
                    Column {
                        Text(
                            text = if (character.isCustom && character.displayName.startsWith("New")) "New Character Profile" else "Edit ${character.displayName}",
                            style = SoftTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Configurable Persona & Presentation",
                            style = SoftTheme.typography.caption,
                            color = SoftTheme.colors.textSecondary
                        )
                    }
                }

                Button(
                    onClick = onSave,
                    modifier = Modifier.testTag("character_editor_save_button"),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SoftTheme.colors.accentActive
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(
                        text = "Save Profile",
                        style = SoftTheme.typography.labelMedium,
                        color = Color.White
                    )
                }
            }

            // Scrollable Content
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .softBounceOverscroll()
                    .verticalScroll(scrollState)
                    .padding(bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                // Section 1: Visual Identity & Avatar Display
                EditorSectionCard(
                    title = "Visual Avatar & Display Mode",
                    icon = Icons.Default.Style
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        // Live Avatar Preview
                        CharacterAvatarView(
                            avatarStyle = character.avatarStyle,
                            displayMode = character.avatarDisplay,
                            size = 72.dp,
                            isActive = character.isActive,
                            isAuditioning = isAuditioning
                        )

                        Spacer(modifier = Modifier.height(14.dp))

                        // Avatar Style Selector (Palette)
                        Text(
                            text = "Avatar Style Palette",
                            style = SoftTheme.typography.labelSmall,
                            color = SoftTheme.colors.textSecondary,
                            modifier = Modifier.align(Alignment.Start)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            availableAvatarStyles.forEach { style ->
                                val isSelected = style.id == character.avatarStyle.id
                                Box(
                                    modifier = Modifier
                                        .size(38.dp)
                                        .clip(CircleShape)
                                        .background(Color(style.primaryColorHex))
                                        .border(
                                            width = if (isSelected) 3.dp else 1.dp,
                                            color = if (isSelected) Color.White else SoftTheme.colors.borderSubtle,
                                            shape = CircleShape
                                        )
                                        .clickable { onAvatarStyleChange(style) }
                                        .testTag("avatar_style_${style.id}"),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = style.glyphSymbol,
                                        color = Color.White,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(18.dp))

                        // Avatar Display Mode (Full, Compact, Voice Mode Only, Hidden)
                        Text(
                            text = "Avatar Display Options",
                            style = SoftTheme.typography.labelSmall,
                            color = SoftTheme.colors.textSecondary,
                            modifier = Modifier.align(Alignment.Start)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            AvatarDisplayMode.entries.forEach { mode ->
                                val isSelected = character.avatarDisplay == mode
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(
                                            if (isSelected) SoftTheme.colors.accentActive.copy(alpha = 0.12f)
                                            else SoftTheme.colors.surfaceCard
                                        )
                                        .border(
                                            width = if (isSelected) 1.5.dp else 1.dp,
                                            color = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.borderSubtle,
                                            shape = RoundedCornerShape(10.dp)
                                        )
                                        .clickable { onAvatarDisplayChange(mode) }
                                        .padding(horizontal = 12.dp, vertical = 10.dp)
                                        .testTag("avatar_display_mode_${mode.name.lowercase()}"),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = mode.title,
                                            style = SoftTheme.typography.bodyMedium,
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                            color = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.textPrimary
                                        )
                                        Text(
                                            text = mode.description,
                                            style = SoftTheme.typography.caption,
                                            color = SoftTheme.colors.textSecondary
                                        )
                                    }
                                    if (isSelected) {
                                        Icon(
                                            imageVector = Icons.Default.Check,
                                            contentDescription = "Selected",
                                            tint = SoftTheme.colors.accentActive,
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // Section 2: Persona, Response Style & Speaking Style
                EditorSectionCard(
                    title = "Persona & Speaking Style",
                    icon = Icons.Default.Psychology
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        // Display Name
                        OutlinedTextField(
                            value = character.displayName,
                            onValueChange = onNameChange,
                            label = { Text("Display Name") },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("character_editor_name_input"),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = SoftTheme.colors.accentActive,
                                unfocusedBorderColor = SoftTheme.colors.borderSubtle
                            ),
                            singleLine = true
                        )

                        // Persona
                        OutlinedTextField(
                            value = character.persona,
                            onValueChange = onPersonaChange,
                            label = { Text("Persona / Role Description") },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("character_editor_persona_input"),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = SoftTheme.colors.accentActive,
                                unfocusedBorderColor = SoftTheme.colors.borderSubtle
                            ),
                            minLines = 2,
                            maxLines = 4
                        )

                        // Response Style
                        OutlinedTextField(
                            value = character.responseStyle,
                            onValueChange = onResponseStyleChange,
                            label = { Text("Response Style") },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("character_editor_response_style_input"),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = SoftTheme.colors.accentActive,
                                unfocusedBorderColor = SoftTheme.colors.borderSubtle
                            ),
                            singleLine = true
                        )

                        // Speaking Style
                        OutlinedTextField(
                            value = character.speakingStyle,
                            onValueChange = onSpeakingStyleChange,
                            label = { Text("Speaking Style") },
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("character_editor_speaking_style_input"),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = SoftTheme.colors.accentActive,
                                unfocusedBorderColor = SoftTheme.colors.borderSubtle
                            ),
                            singleLine = true
                        )
                    }
                }

                // Section 3: Voice Profile Selector
                EditorSectionCard(
                    title = "Voice Profile",
                    icon = Icons.Default.RecordVoiceOver
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        availableVoices.forEach { voice ->
                            val isSelected = voice.id == character.voice.id
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(
                                        if (isSelected) SoftTheme.colors.accentActive.copy(alpha = 0.12f)
                                        else SoftTheme.colors.surfaceCard
                                    )
                                    .border(
                                        width = if (isSelected) 1.5.dp else 1.dp,
                                        color = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.borderSubtle,
                                        shape = RoundedCornerShape(10.dp)
                                    )
                                    .clickable { onVoiceChange(voice) }
                                    .padding(horizontal = 12.dp, vertical = 10.dp)
                                    .testTag("voice_option_${voice.id}"),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = voice.name,
                                        style = SoftTheme.typography.bodyMedium,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                        color = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.textPrimary
                                    )
                                    Text(
                                        text = "${voice.timbre} • ${voice.accentTag}",
                                        style = SoftTheme.typography.caption,
                                        color = SoftTheme.colors.textSecondary
                                    )
                                }

                                IconButton(
                                    onClick = { onAuditionVoice(voice.id) },
                                    modifier = Modifier.size(32.dp)
                                ) {
                                    Icon(
                                        imageVector = if (isAuditioning && isSelected) Icons.Default.Stop else Icons.Default.PlayArrow,
                                        contentDescription = "Audition",
                                        tint = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.textSecondary,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }
                        }
                    }
                }

                // Section 4: Language Style (CRITICAL SECTION)
                EditorSectionCard(
                    title = "Language Style & Presentation",
                    icon = Icons.Default.Language
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        // MANDATORY SYSTEM NOTICE
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(SoftTheme.colors.accentPrimary.copy(alpha = 0.1f))
                                .border(1.dp, SoftTheme.colors.accentPrimary.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
                                .padding(12.dp)
                                .testTag("language_style_system_notice")
                        ) {
                            Row(
                                verticalAlignment = Alignment.Top,
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Info,
                                    contentDescription = "Notice",
                                    tint = SoftTheme.colors.accentPrimary,
                                    modifier = Modifier.size(20.dp)
                                )
                                Column {
                                    Text(
                                        text = "Language Capability Boundary",
                                        style = SoftTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = SoftTheme.colors.textPrimary
                                    )
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = "Language capability belongs to system/user settings. Character language style only affects personality and presentation.",
                                        style = SoftTheme.typography.caption,
                                        color = SoftTheme.colors.textSecondary,
                                        lineHeight = 16.sp
                                    )
                                }
                            }
                        }

                        // Primary Language
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "Primary Language",
                                style = SoftTheme.typography.labelSmall,
                                color = SoftTheme.colors.textSecondary
                            )
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                listOf("English", "Tagalog", "Japanese").forEach { lang ->
                                    val isSelected = character.languageStyle.primaryLanguage == lang
                                    FilterChip(
                                        selected = isSelected,
                                        onClick = { onPrimaryLanguageChange(lang) },
                                        label = { Text(lang) },
                                        modifier = Modifier.testTag("primary_language_$lang"),
                                        colors = FilterChipDefaults.filterChipColors(
                                            selectedContainerColor = SoftTheme.colors.accentActive,
                                            selectedLabelColor = Color.White
                                        )
                                    )
                                }
                            }
                        }

                        // Secondary Languages (Multi-select)
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "Secondary Languages",
                                style = SoftTheme.typography.labelSmall,
                                color = SoftTheme.colors.textSecondary
                            )
                            FlowRow(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                listOf("Tagalog", "Japanese", "Spanish", "German").forEach { lang ->
                                    val isSelected = character.languageStyle.secondaryLanguages.contains(lang)
                                    FilterChip(
                                        selected = isSelected,
                                        onClick = { onToggleSecondaryLanguage(lang) },
                                        label = { Text(lang) },
                                        modifier = Modifier.testTag("secondary_language_$lang"),
                                        colors = FilterChipDefaults.filterChipColors(
                                            selectedContainerColor = SoftTheme.colors.accentPrimary.copy(alpha = 0.3f),
                                            selectedLabelColor = SoftTheme.colors.textPrimary
                                        )
                                    )
                                }
                            }
                        }

                        // Match User Language Switch
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(SoftTheme.colors.surfaceCard)
                                .border(1.dp, SoftTheme.colors.borderSubtle, RoundedCornerShape(10.dp))
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Match User Language",
                                    style = SoftTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    color = SoftTheme.colors.textPrimary
                                )
                                Text(
                                    text = "Mirror user's conversational language while keeping tone",
                                    style = SoftTheme.typography.caption,
                                    color = SoftTheme.colors.textSecondary
                                )
                            }
                            Switch(
                                checked = character.languageStyle.matchUserLanguage,
                                onCheckedChange = onMatchUserLanguageChange,
                                modifier = Modifier.testTag("match_user_language_switch"),
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = Color.White,
                                    checkedTrackColor = SoftTheme.colors.accentActive
                                )
                            )
                        }

                        // Code-Switching Style
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(
                                text = "Code-Switching Style",
                                style = SoftTheme.typography.labelSmall,
                                color = SoftTheme.colors.textSecondary
                            )
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                CodeSwitchingStyle.entries.forEach { style ->
                                    val isSelected = character.languageStyle.codeSwitchingStyle == style
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(
                                                if (isSelected) SoftTheme.colors.accentActive.copy(alpha = 0.12f)
                                                else SoftTheme.colors.surfaceCard
                                            )
                                            .border(
                                                width = if (isSelected) 1.5.dp else 1.dp,
                                                color = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.borderSubtle,
                                                shape = RoundedCornerShape(8.dp)
                                            )
                                            .clickable { onCodeSwitchingChange(style) }
                                            .padding(horizontal = 10.dp, vertical = 8.dp)
                                            .testTag("code_switching_${style.name.lowercase()}"),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(
                                                text = style.title,
                                                style = SoftTheme.typography.bodySmall,
                                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                                color = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.textPrimary
                                            )
                                            Text(
                                                text = style.description,
                                                style = SoftTheme.typography.caption.copy(fontSize = 10.sp),
                                                color = SoftTheme.colors.textSecondary
                                            )
                                        }
                                        if (isSelected) {
                                            Icon(
                                                imageVector = Icons.Default.Check,
                                                contentDescription = null,
                                                tint = SoftTheme.colors.accentActive,
                                                modifier = Modifier.size(16.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Tagalog Frequency
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "Tagalog Frequency",
                                    style = SoftTheme.typography.labelSmall,
                                    color = SoftTheme.colors.textSecondary
                                )
                                Text(
                                    text = character.languageStyle.tagalogFrequency.title,
                                    style = SoftTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = SoftTheme.colors.accentActive
                                )
                            }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                FrequencyLevel.entries.forEach { freq ->
                                    val isSelected = character.languageStyle.tagalogFrequency == freq
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clip(RoundedCornerShape(6.dp))
                                            .background(
                                                if (isSelected) SoftTheme.colors.accentActive
                                                else SoftTheme.colors.surfaceCard
                                            )
                                            .border(
                                                1.dp,
                                                if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.borderSubtle,
                                                RoundedCornerShape(6.dp)
                                            )
                                            .clickable { onTagalogFreqChange(freq) }
                                            .padding(vertical = 8.dp)
                                            .testTag("tagalog_frequency_${freq.name.lowercase()}"),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = freq.title.take(3),
                                            style = SoftTheme.typography.caption.copy(fontSize = 10.sp),
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                            color = if (isSelected) Color.White else SoftTheme.colors.textSecondary
                                        )
                                    }
                                }
                            }
                        }

                        // Japanese Frequency
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "Japanese Frequency",
                                    style = SoftTheme.typography.labelSmall,
                                    color = SoftTheme.colors.textSecondary
                                )
                                Text(
                                    text = character.languageStyle.japaneseFrequency.title,
                                    style = SoftTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = SoftTheme.colors.accentActive
                                )
                            }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                FrequencyLevel.entries.forEach { freq ->
                                    val isSelected = character.languageStyle.japaneseFrequency == freq
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clip(RoundedCornerShape(6.dp))
                                            .background(
                                                if (isSelected) SoftTheme.colors.accentActive
                                                else SoftTheme.colors.surfaceCard
                                            )
                                            .border(
                                                1.dp,
                                                if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.borderSubtle,
                                                RoundedCornerShape(6.dp)
                                            )
                                            .clickable { onJapaneseFreqChange(freq) }
                                            .padding(vertical = 8.dp)
                                            .testTag("japanese_frequency_${freq.name.lowercase()}"),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = freq.title.take(3),
                                            style = SoftTheme.typography.caption.copy(fontSize = 10.sp),
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                            color = if (isSelected) Color.White else SoftTheme.colors.textSecondary
                                        )
                                    }
                                }
                            }
                        }

                        // Japanese Tone (Strict 4 options: Neutral, Warm / Mature, Playful, Formal)
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(
                                text = "Japanese Tone",
                                style = SoftTheme.typography.labelSmall,
                                color = SoftTheme.colors.textSecondary
                            )
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                JapaneseTone.entries.forEach { tone ->
                                    val isSelected = character.languageStyle.japaneseTone == tone
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(
                                                if (isSelected) SoftTheme.colors.accentActive.copy(alpha = 0.12f)
                                                else SoftTheme.colors.surfaceCard
                                            )
                                            .border(
                                                width = if (isSelected) 1.5.dp else 1.dp,
                                                color = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.borderSubtle,
                                                shape = RoundedCornerShape(8.dp)
                                            )
                                            .clickable { onJapaneseToneChange(tone) }
                                            .padding(horizontal = 10.dp, vertical = 8.dp)
                                            .testTag("japanese_tone_${tone.name.lowercase()}"),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(
                                                text = tone.title,
                                                style = SoftTheme.typography.bodySmall,
                                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                                color = if (isSelected) SoftTheme.colors.accentActive else SoftTheme.colors.textPrimary
                                            )
                                            Text(
                                                text = "${tone.description} (${tone.sampleSuffix})",
                                                style = SoftTheme.typography.caption.copy(fontSize = 10.sp),
                                                color = SoftTheme.colors.textSecondary
                                            )
                                        }
                                        if (isSelected) {
                                            Icon(
                                                imageVector = Icons.Default.Check,
                                                contentDescription = null,
                                                tint = SoftTheme.colors.accentActive,
                                                modifier = Modifier.size(16.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EditorSectionCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    content: @Composable () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(SoftTheme.colors.surfaceCard)
            .border(1.dp, SoftTheme.colors.borderSubtle, RoundedCornerShape(14.dp))
            .padding(16.dp)
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentActive,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = title,
                    style = SoftTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }
            Spacer(modifier = Modifier.height(14.dp))
            content()
        }
    }
}
