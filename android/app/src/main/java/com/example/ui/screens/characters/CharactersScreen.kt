package com.example.ui.screens.characters

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.CharacterProfile
import com.example.ui.components.SoftGlassCard
import com.example.ui.theme.SoftTheme
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CharactersScreen(
    onNavigateBack: () -> Unit,
    onSelectActiveCharacter: ((CharacterProfile) -> Unit)? = null,
    viewModel: CharactersViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory),
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()

    // Auto-dismiss status message after 3 seconds
    LaunchedEffect(uiState.statusMessage) {
        if (uiState.statusMessage != null) {
            delay(3000)
            viewModel.clearStatus()
        }
    }

    Scaffold(
        modifier = modifier
            .fillMaxSize()
            .testTag("characters_screen"),
        containerColor = SoftTheme.colors.background,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "Characters",
                            style = SoftTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Configurable Cognitive Profiles",
                            style = SoftTheme.typography.caption,
                            color = SoftTheme.colors.textSecondary
                        )
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("characters_back_button")
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = SoftTheme.colors.textPrimary
                        )
                    }
                },
                actions = {
                    IconButton(
                        onClick = { viewModel.resetToDefaults() },
                        modifier = Modifier.testTag("characters_reset_button")
                    ) {
                        Icon(
                            imageVector = Icons.Default.RestartAlt,
                            contentDescription = "Reset Defaults",
                            tint = SoftTheme.colors.textSecondary
                        )
                    }

                    Button(
                        onClick = { viewModel.createNewCharacter() },
                        modifier = Modifier
                            .padding(end = 8.dp)
                            .testTag("character_new_button"),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = SoftTheme.colors.accentActive
                        ),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "New",
                            style = SoftTheme.typography.labelSmall,
                            color = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = SoftTheme.colors.background
                )
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Architectural Concept Notice
                item {
                    ConceptualIdentityCard()
                }

                // Active Profile Hero Banner
                uiState.activeCharacter?.let { activeChar ->
                    item {
                        ActiveProfileHeroCard(
                            character = activeChar,
                            onEdit = { viewModel.openEditor(activeChar) }
                        )
                    }
                }

                // Section Header: Character Library
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp, bottom = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Psychology,
                                contentDescription = null,
                                tint = SoftTheme.colors.accentActive,
                                modifier = Modifier.size(20.dp)
                            )
                            Text(
                                text = "Character Library",
                                style = SoftTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = SoftTheme.colors.textPrimary
                            )
                        }

                        Text(
                            text = "${uiState.characters.size} Profiles",
                            style = SoftTheme.typography.caption,
                            color = SoftTheme.colors.textSecondary
                        )
                    }
                }

                // Character Cards
                items(uiState.characters, key = { it.id }) { character ->
                    CharacterCard(
                        character = character,
                        isAuditioning = uiState.auditioningVoiceId == character.voice.id,
                        onActivate = {
                            viewModel.selectActive(character.id) { activated ->
                                onSelectActiveCharacter?.invoke(activated)
                            }
                        },
                        onEdit = { viewModel.openEditor(character) },
                        onDuplicate = { viewModel.duplicateCharacter(character.id) },
                        onDelete = { viewModel.deleteCharacter(character.id) },
                        onAuditionVoice = { viewModel.simulateVoiceAudition(character.voice.id) }
                    )
                }
            }

            // Floating Status Pill
            AnimatedVisibility(
                visible = uiState.statusMessage != null,
                enter = fadeIn(),
                exit = fadeOut(),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 24.dp)
            ) {
                uiState.statusMessage?.let { msg ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(SoftTheme.colors.surfaceCard)
                            .border(1.dp, SoftTheme.colors.accentActive, RoundedCornerShape(20.dp))
                            .padding(horizontal = 16.dp, vertical = 10.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = SoftTheme.colors.success,
                                modifier = Modifier.size(16.dp)
                            )
                            Text(
                                text = msg,
                                style = SoftTheme.typography.bodySmall,
                                color = SoftTheme.colors.textPrimary,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }
        }

        // Character Editor Sheet
        if (uiState.isEditorOpen && uiState.editingCharacter != null) {
            val editing = uiState.editingCharacter!!
            CharacterEditorSheet(
                character = editing,
                availableVoices = uiState.availableVoices,
                availableAvatarStyles = uiState.availableAvatarStyles,
                isAuditioning = uiState.auditioningVoiceId == editing.voice.id,
                onAuditionVoice = { voiceId -> viewModel.simulateVoiceAudition(voiceId) },
                onSave = { viewModel.saveEditingCharacter() },
                onCancel = { viewModel.closeEditor() },
                onNameChange = { viewModel.updateDisplayName(it) },
                onPersonaChange = { viewModel.updatePersona(it) },
                onResponseStyleChange = { viewModel.updateResponseStyle(it) },
                onSpeakingStyleChange = { viewModel.updateSpeakingStyle(it) },
                onAvatarStyleChange = { viewModel.updateAvatarStyle(it) },
                onAvatarDisplayChange = { viewModel.updateAvatarDisplay(it) },
                onVoiceChange = { viewModel.updateVoice(it) },
                onPrimaryLanguageChange = { viewModel.setPrimaryLanguage(it) },
                onToggleSecondaryLanguage = { viewModel.toggleSecondaryLanguage(it) },
                onMatchUserLanguageChange = { viewModel.setMatchUserLanguage(it) },
                onCodeSwitchingChange = { viewModel.setCodeSwitchingStyle(it) },
                onTagalogFreqChange = { viewModel.setTagalogFrequency(it) },
                onJapaneseFreqChange = { viewModel.setJapaneseFrequency(it) },
                onJapaneseToneChange = { viewModel.setJapaneseTone(it) }
            )
        }
    }
}

@Composable
private fun ConceptualIdentityCard(
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("characters_conceptual_notice")
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.accentPrimary.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentPrimary,
                    modifier = Modifier.size(20.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Configurable Cognitive Profiles",
                    style = SoftTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "Characters are configurable cognitive profiles, not application identity. Language capability belongs to system/user settings; character language style only governs presentation.",
                    style = SoftTheme.typography.caption,
                    color = SoftTheme.colors.textSecondary,
                    lineHeight = 16.sp
                )
            }
        }
    }
}

@Composable
private fun ActiveProfileHeroCard(
    character: CharacterProfile,
    onEdit: () -> Unit,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .border(1.5.dp, SoftTheme.colors.accentActive.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
            .testTag("characters_active_hero_card")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(SoftTheme.colors.success)
                    )
                    Text(
                        text = "CURRENTLY ACTIVE PROFILE",
                        style = SoftTheme.typography.caption.copy(
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 1.sp
                        ),
                        color = SoftTheme.colors.success
                    )
                }

                OutlinedButton(
                    onClick = onEdit,
                    modifier = Modifier.height(28.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Tune,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentActive,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Customize",
                        style = SoftTheme.typography.caption.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.accentActive
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                CharacterAvatarView(
                    avatarStyle = character.avatarStyle,
                    displayMode = character.avatarDisplay,
                    size = 64.dp,
                    isActive = true
                )

                Spacer(modifier = Modifier.width(16.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = character.displayName,
                        style = SoftTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = character.persona,
                        style = SoftTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary,
                        maxLines = 2
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.VolumeUp,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentPrimary,
                            modifier = Modifier.size(14.dp)
                        )
                        Text(
                            text = "${character.voice.name} (${character.voice.timbre})",
                            style = SoftTheme.typography.caption,
                            color = SoftTheme.colors.textSecondary
                        )
                    }
                }
            }
        }
    }
}
