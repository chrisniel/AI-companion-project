package com.example.ui.screens.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material.icons.filled.Wallpaper
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.AccentPreset
import com.example.domain.model.AppLanguage
import com.example.domain.model.BackgroundType
import com.example.domain.model.EffectsLevel
import com.example.domain.model.JapaneseDisplay
import com.example.domain.model.ResponseLanguageChoice
import com.example.domain.model.SettingsSection
import com.example.domain.model.SettingsState
import com.example.domain.model.StartupBehavior
import com.example.domain.model.ThemeMode
import com.example.domain.model.ThemeSource
import com.example.domain.model.VoiceCapability
import com.example.domain.model.VoiceRecognitionLanguage
import com.example.ui.components.SoftGlassButton
import com.example.ui.components.SoftGlassCard
import com.example.ui.theme.SoftTheme

/**
 * Complete Mobile Settings Screen supporting all 9 sections:
 * General, Appearance, Assistant, Voice, Connection, Alarms, Health, Privacy, Advanced.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    settingsViewModel: SettingsViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory),
    onLiveThemeChanged: ((Boolean) -> Unit)? = null,
    onNavigateToPermissions: () -> Unit = {}
) {
    val uiState by settingsViewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier
            .fillMaxSize()
            .testTag("screen_settings"),
        containerColor = SoftTheme.colors.background,
        topBar = {
            SettingsTopBar(
                onNavigateBack = onNavigateBack,
                onResetDefaults = { settingsViewModel.resetToDefaults() }
            )
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.lg)
            ) {
                // Section Tabs
                SettingsSectionTabs(
                    selectedSection = uiState.selectedSection,
                    onSelectSection = { settingsViewModel.selectSection(it) }
                )

                // Section Content
                when (uiState.selectedSection) {
                    SettingsSection.GENERAL -> GeneralSectionContent(uiState, settingsViewModel)
                    SettingsSection.APPEARANCE -> AppearanceSectionContent(uiState, settingsViewModel, onLiveThemeChanged)
                    SettingsSection.ASSISTANT -> AssistantSectionContent(uiState, settingsViewModel)
                    SettingsSection.VOICE -> VoiceSectionContent(uiState, settingsViewModel)
                    SettingsSection.CONNECTION -> ConnectionSectionContent(uiState, settingsViewModel)
                    SettingsSection.ALARMS -> AlarmsSectionContent(uiState, settingsViewModel)
                    SettingsSection.HEALTH -> HealthSectionContent(uiState, settingsViewModel)
                    SettingsSection.PRIVACY -> PrivacySectionContent(uiState, settingsViewModel, onNavigateToPermissions)
                    SettingsSection.ADVANCED -> AdvancedSectionContent(uiState, settingsViewModel)
                }

                Spacer(modifier = Modifier.height(SoftTheme.spacing.xxl))
            }

            // Status message toast
            uiState.statusMessage?.let { msg ->
                StatusFeedbackBanner(
                    message = msg,
                    onDismiss = { settingsViewModel.dismissStatus() },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(SoftTheme.spacing.lg)
                )
            }
        }
    }
}

// ==========================================
// TOP BAR & NAVIGATION TABS
// ==========================================

@Composable
private fun SettingsTopBar(
    onNavigateBack: () -> Unit,
    onResetDefaults: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            IconButton(
                onClick = onNavigateBack,
                modifier = Modifier.testTag("topbar_back_button")
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Navigate Back",
                    tint = SoftTheme.colors.textPrimary
                )
            }

            Column {
                Text(
                    text = "Settings",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = "Preferences & Local Core Setup",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textMuted
                )
            }
        }

        IconButton(
            onClick = onResetDefaults,
            modifier = Modifier.testTag("settings_reset_button")
        ) {
            Icon(
                imageVector = Icons.Default.RestartAlt,
                contentDescription = "Reset Settings to Default",
                tint = SoftTheme.colors.textSecondary
            )
        }
    }
}

@Composable
private fun SettingsSectionTabs(
    selectedSection: SettingsSection,
    onSelectSection: (SettingsSection) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
    ) {
        SettingsSection.entries.forEach { section ->
            val isSelected = section == selectedSection
            val icon = getSectionIcon(section)

            FilterChip(
                selected = isSelected,
                onClick = { onSelectSection(section) },
                leadingIcon = {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.textMuted
                    )
                },
                label = {
                    Text(
                        text = section.title,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = SoftTheme.colors.accentCyan.copy(alpha = 0.15f),
                    selectedLabelColor = SoftTheme.colors.accentCyan,
                    containerColor = SoftTheme.colors.surface,
                    labelColor = SoftTheme.colors.textSecondary
                ),
                border = FilterChipDefaults.filterChipBorder(
                    enabled = true,
                    selected = isSelected,
                    borderColor = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.borderSubtle
                ),
                modifier = Modifier.testTag("settings_tab_${section.id}")
            )
        }
    }
}

private fun getSectionIcon(section: SettingsSection): ImageVector {
    return when (section) {
        SettingsSection.GENERAL -> Icons.Default.Tune
        SettingsSection.APPEARANCE -> Icons.Default.Palette
        SettingsSection.ASSISTANT -> Icons.Default.Psychology
        SettingsSection.VOICE -> Icons.Default.Mic
        SettingsSection.CONNECTION -> Icons.Default.Wifi
        SettingsSection.ALARMS -> Icons.Default.Alarm
        SettingsSection.HEALTH -> Icons.Default.Favorite
        SettingsSection.PRIVACY -> Icons.Default.Security
        SettingsSection.ADVANCED -> Icons.Default.Build
    }
}

// ==========================================
// 1. GENERAL SECTION (with LANGUAGE PREFERENCES)
// ==========================================

@Composable
private fun GeneralSectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel
) {
    SectionCard(
        title = "General Settings",
        description = "Language preferences, notification rules, and application startup behavior.",
        icon = Icons.Default.Tune
    ) {
        // Full Language Preferences Card
        LanguagePreferencesCard(uiState, viewModel)

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        // Notifications
        Text(
            text = "NOTIFICATIONS",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        SettingSwitchRow(
            title = "Push Notifications",
            description = "Receive task deadlines and companion reminders",
            icon = Icons.Default.Notifications,
            checked = uiState.notificationsEnabled,
            onCheckedChange = { viewModel.toggleNotifications(it) },
            testTag = "switch_notifications"
        )

        SettingSwitchRow(
            title = "Quiet Hours (22:00 - 07:00)",
            description = "Silence all non-critical notifications overnight",
            icon = Icons.Default.Alarm,
            checked = uiState.quietHoursEnabled,
            onCheckedChange = { viewModel.toggleQuietHours(it) },
            testTag = "switch_quiet_hours"
        )

        SettingSwitchRow(
            title = "Sound Alerts",
            description = "Play subtle acoustic feedback for notifications",
            icon = Icons.AutoMirrored.Filled.VolumeUp,
            checked = uiState.soundAlertsEnabled,
            onCheckedChange = { viewModel.toggleSoundAlerts(it) },
            testTag = "switch_sound_alerts"
        )

        SettingSwitchRow(
            title = "Haptic Alerts",
            description = "Gentle haptic vibration pulses for alarm triggers",
            icon = Icons.Default.Vibration,
            checked = uiState.hapticFeedbackEnabled,
            onCheckedChange = { viewModel.toggleHapticFeedback(it) },
            testTag = "switch_haptic_feedback"
        )

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        // Startup & Resume Behavior
        Text(
            text = "STARTUP & RESUME BEHAVIOR",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
            StartupBehavior.entries.forEach { behavior ->
                val isSelected = uiState.startupBehavior == behavior
                SelectionCardItem(
                    title = behavior.label,
                    subtitle = behavior.description,
                    selected = isSelected,
                    onClick = { viewModel.setStartupBehavior(behavior) },
                    testTag = "startup_${behavior.name}"
                )
            }
        }
    }
}

@Composable
private fun LanguagePreferencesCard(
    uiState: SettingsState,
    viewModel: SettingsViewModel
) {
    SoftGlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("language_preferences_card"),
        containerColor = SoftTheme.colors.surfaceElevated
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.md),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Icon(
                    imageVector = Icons.Default.Translate,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentCyan
                )
                Text(
                    text = "Language Preferences",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }

            // Primary Language
            Text(
                text = "PRIMARY LANGUAGE",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textMuted
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                AppLanguage.entries.forEach { lang ->
                    val isSelected = uiState.primaryLanguage == lang
                    SelectablePill(
                        label = lang.label,
                        selected = isSelected,
                        onClick = { viewModel.setPrimaryLanguage(lang) },
                        modifier = Modifier
                            .weight(1f)
                            .testTag("primary_lang_${lang.code}")
                    )
                }
            }

            // Understands (Multi-select)
            Text(
                text = "UNDERSTANDS (CAN PROCESS INPUT IN)",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textMuted
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                AppLanguage.entries.forEach { lang ->
                    val isChecked = uiState.understandsLanguages.contains(lang)
                    SelectablePill(
                        label = if (isChecked) "✓ ${lang.label}" else lang.label,
                        selected = isChecked,
                        onClick = { viewModel.toggleUnderstandsLanguage(lang) },
                        modifier = Modifier
                            .weight(1f)
                            .testTag("understands_lang_${lang.code}")
                    )
                }
            }

            // Mixed-Language Conversation
            SettingSwitchRow(
                title = "Mixed-Language Conversation",
                description = "Seamlessly switch between English, Filipino, and Japanese mid-dialogue",
                icon = Icons.Default.Language,
                checked = uiState.mixedLanguageConversation,
                onCheckedChange = { viewModel.setMixedLanguageConversation(it) },
                testTag = "switch_mixed_lang_conversation"
            )

            HorizontalDivider(color = SoftTheme.colors.borderSubtle)

            // Response Language
            Text(
                text = "RESPONSE LANGUAGE",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textMuted
            )

            Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
                ResponseLanguageChoice.entries.chunked(2).forEach { rowChoices ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                    ) {
                        rowChoices.forEach { choice ->
                            val isSelected = uiState.responseLanguage == choice
                            SelectablePill(
                                label = choice.label,
                                selected = isSelected,
                                onClick = { viewModel.setResponseLanguage(choice) },
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("response_lang_${choice.name}")
                            )
                        }
                    }
                }
            }

            // Technical Language
            Text(
                text = "TECHNICAL TERMINOLOGY LANGUAGE",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textMuted
            )

            Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
                ResponseLanguageChoice.entries.chunked(2).forEach { rowChoices ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                    ) {
                        rowChoices.forEach { choice ->
                            val isSelected = uiState.technicalLanguage == choice
                            SelectablePill(
                                label = choice.label,
                                selected = isSelected,
                                onClick = { viewModel.setTechnicalLanguage(choice) },
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("tech_lang_${choice.name}")
                            )
                        }
                    }
                }
            }

            HorizontalDivider(color = SoftTheme.colors.borderSubtle)

            // Japanese Display
            Text(
                text = "JAPANESE TEXT FORMATTING",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textMuted
            )

            Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
                JapaneseDisplay.entries.forEach { display ->
                    val isSelected = uiState.japaneseDisplay == display
                    SelectionCardItem(
                        title = display.label,
                        subtitle = display.sampleText,
                        selected = isSelected,
                        onClick = { viewModel.setJapaneseDisplay(display) },
                        testTag = "jp_display_${display.name}"
                    )
                }
            }
        }
    }
}

// ==========================================
// 2. APPEARANCE SECTION
// ==========================================

@Composable
private fun AppearanceSectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel,
    onLiveThemeChanged: ((Boolean) -> Unit)?
) {
    SectionCard(
        title = "Appearance & Visual Styling",
        description = "Customize dark/light theme modes, independent mobile backgrounds, accent tints, and glass effect rendering.",
        icon = Icons.Default.Palette
    ) {
        // Theme Mode
        Text(
            text = "THEME MODE",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            ThemeMode.entries.forEach { mode ->
                val isSelected = uiState.themeMode == mode
                SelectablePill(
                    label = mode.label,
                    selected = isSelected,
                    onClick = { viewModel.setThemeMode(mode, onLiveThemeChanged) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("theme_mode_${mode.name}")
                )
            }
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        // Theme Source
        Text(
            text = "THEME SOURCE",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
            ThemeSource.entries.forEach { source ->
                val isSelected = uiState.themeSource == source
                SelectionCardItem(
                    title = source.label,
                    subtitle = source.description,
                    selected = isSelected,
                    onClick = { viewModel.setThemeSource(source) },
                    testTag = "theme_source_${source.name}"
                )
            }
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        // Background
        Text(
            text = "MOBILE BACKGROUND",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            BackgroundType.entries.forEach { type ->
                val isSelected = uiState.backgroundType == type
                SelectablePill(
                    label = type.label,
                    selected = isSelected,
                    onClick = { viewModel.setBackgroundType(type) },
                    modifier = Modifier.testTag("bg_type_${type.name}")
                )
            }
        }

        // Mobile background independence banner
        SoftGlassCard(
            modifier = Modifier
                .fillMaxWidth()
                .testTag("bg_mobile_notice"),
            containerColor = SoftTheme.colors.accentCyan.copy(alpha = 0.08f),
            elevation = SoftTheme.tokens.elevations.flat
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.md),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                Icon(
                    imageVector = Icons.Default.Wallpaper,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentCyan,
                    modifier = Modifier.size(24.dp)
                )
                Column {
                    Text(
                        text = "Independent Mobile Wallpaper",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "Do not force the PC wallpaper onto mobile. Handheld displays retain custom mobile-optimized aspect ratio and textures.",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }
            }
        }

        // Preset built-in choices or Custom Image UI
        when (uiState.backgroundType) {
            BackgroundType.BUILT_IN -> {
                Text(
                    text = "Built-in Presets",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary
                )
                listOf("Obsidian Deep Glass", "Pearl Frost", "Aurora Glass", "Midnight Cyan").forEach { bgName ->
                    val isSelected = uiState.selectedBuiltInBackground == bgName
                    SelectionCardItem(
                        title = bgName,
                        subtitle = "Curated ambient glass background for OLED and LCD",
                        selected = isSelected,
                        onClick = { viewModel.setSelectedBuiltInBackground(bgName) },
                        testTag = "bg_preset_${bgName.replace(" ", "_")}"
                    )
                }
            }
            BackgroundType.CUSTOM_IMAGE -> {
                SoftGlassCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("custom_image_ui_card")
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(SoftTheme.spacing.md),
                        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                        ) {
                            Icon(Icons.Default.Image, contentDescription = null, tint = SoftTheme.colors.accentCyan)
                            Text(
                                text = "Current: ${uiState.customImageName}",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = SoftTheme.colors.textPrimary
                            )
                        }
                        Text(
                            text = "Simulate picking a mobile photo or custom rendered graphic:",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textSecondary
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                        ) {
                            SoftGlassButton(
                                text = "Select Mobile Aurora",
                                onClick = { viewModel.setCustomImageName("mobile_aurora_custom.jpg") },
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("btn_pick_aurora")
                            )
                            SoftGlassButton(
                                text = "Select Cyber Glass",
                                onClick = { viewModel.setCustomImageName("cyber_glass_mobile.png") },
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("btn_pick_cyber")
                            )
                        }
                    }
                }
            }
            BackgroundType.GRADIENT -> {
                Text(
                    text = "Curated Mobile Gradients",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary
                )
                listOf(
                    "Cyan-Violet Fluid Mesh",
                    "Aurora Emerald Flow",
                    "Deep Space Nebula",
                    "Sunset Amber Radiant"
                ).forEach { gradientName ->
                    val isSelected = uiState.selectedGradientBackground == gradientName
                    SelectionCardItem(
                        title = gradientName,
                        subtitle = "Multi-stop CSS shader gradient tuned for low handheld power draw",
                        selected = isSelected,
                        onClick = { viewModel.setSelectedGradientBackground(gradientName) },
                        testTag = "bg_gradient_${gradientName.replace(" ", "_")}"
                    )
                }
            }
            BackgroundType.SOLID -> {
                Text(
                    text = "Minimalist Solid Finishes",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary
                )
                listOf(
                    "Deep Matte Obsidian (#0D1117)",
                    "Charcoal Glass (#161B22)",
                    "Pearl Slate (#1F242C)",
                    "OLED True Black (#000000)"
                ).forEach { solidName ->
                    val isSelected = uiState.selectedSolidBackground == solidName
                    SelectionCardItem(
                        title = solidName,
                        subtitle = "Untextured flat surface maximizing battery life on OLED displays",
                        selected = isSelected,
                        onClick = { viewModel.setSelectedSolidBackground(solidName) },
                        testTag = "bg_solid_${solidName.replace(" ", "_").replace("(", "").replace(")", "").replace("#", "")}"
                    )
                }
            }
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        // Accent Colors
        Text(
            text = "ACCENT COLOR",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            AccentPreset.entries.forEach { preset ->
                val isSelected = uiState.accentPreset == preset && !uiState.isCustomAccentEnabled
                AccentColorDot(
                    color = Color(preset.colorHex),
                    label = preset.label,
                    selected = isSelected,
                    onClick = { viewModel.setAccentPreset(preset) },
                    testTag = "accent_preset_${preset.name}"
                )
            }
        }

        // Custom accent toggle
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = SoftTheme.spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(
                    text = "Custom Accent Hex",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = "Apply custom hex color value (${uiState.customAccentHex})",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary
                )
            }

            Switch(
                checked = uiState.isCustomAccentEnabled,
                onCheckedChange = { viewModel.toggleCustomAccent(it) },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = SoftTheme.colors.accentCyan,
                    checkedTrackColor = SoftTheme.colors.accentCyan.copy(alpha = 0.3f)
                ),
                modifier = Modifier.testTag("custom_accent_toggle")
            )
        }

        if (uiState.isCustomAccentEnabled) {
            Text(
                text = "Quick Custom Swatches",
                style = MaterialTheme.typography.labelSmall,
                color = SoftTheme.colors.textMuted
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                listOf(
                    "#F43F5E" to "Rose",
                    "#84CC16" to "Lime",
                    "#FF5722" to "Orange",
                    "#8B5CF6" to "Violet",
                    "#F59E0B" to "Gold",
                    "#00E5FF" to "Cyan"
                ).forEach { (hex, label) ->
                    val isSelected = uiState.customAccentHex.equals(hex, ignoreCase = true)
                    AccentColorDot(
                        color = Color(android.graphics.Color.parseColor(hex)),
                        label = label,
                        selected = isSelected,
                        onClick = { viewModel.setCustomAccent(hex) },
                        testTag = "custom_swatch_$label"
                    )
                }
            }
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        // Effects Level
        Text(
            text = "GLASS VISUAL EFFECTS",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
            EffectsLevel.entries.forEach { level ->
                val isSelected = uiState.effectsLevel == level
                SelectionCardItem(
                    title = level.label,
                    subtitle = level.description,
                    selected = isSelected,
                    onClick = { viewModel.setEffectsLevel(level) },
                    testTag = "effects_level_${level.name}"
                )
            }
        }
    }
}

// ==========================================
// 3. ASSISTANT SECTION
// ==========================================

@Composable
private fun AssistantSectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel
) {
    SectionCard(
        title = "Assistant Intelligence",
        description = "Adjust personality depth, autonomous suggestions, and chain-of-thought visibility.",
        icon = Icons.Default.Psychology
    ) {
        Text(
            text = "RESPONSE DETAIL LEVEL",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            listOf("Concise", "Balanced", "Detailed").forEach { level ->
                val isSelected = uiState.responseDetailLevel == level
                SelectablePill(
                    label = level,
                    selected = isSelected,
                    onClick = { viewModel.setResponseDetailLevel(level) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("assistant_detail_$level")
                )
            }
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        SettingSwitchRow(
            title = "Proactive Suggestions",
            description = "Suggest upcoming calendar items and wellness breaks based on context",
            icon = Icons.Default.AutoAwesome,
            checked = uiState.proactiveSuggestions,
            onCheckedChange = { viewModel.toggleProactiveSuggestions(it) },
            testTag = "switch_proactive_suggestions"
        )

        SettingSwitchRow(
            title = "Chain-of-Thought Visibility",
            description = "Display step-by-step local reasoning collapsible cards in Assistant chat",
            icon = Icons.Default.Psychology,
            checked = uiState.chainOfThoughtVisible,
            onCheckedChange = { viewModel.toggleChainOfThought(it) },
            testTag = "switch_chain_of_thought"
        )
    }
}

// ==========================================
// 4. VOICE SECTION & CAPABILITIES
// ==========================================

@Composable
private fun VoiceSectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel
) {
    SectionCard(
        title = "Voice & Speech Recognition",
        description = "Manage speech recognition language, multilingual speech detection, and on-device whisper models.",
        icon = Icons.Default.Mic
    ) {
        // Recognition Language
        Text(
            text = "SPEECH RECOGNITION LANGUAGE",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            VoiceRecognitionLanguage.entries.forEach { lang ->
                val isSelected = uiState.voiceRecognitionLanguage == lang
                SelectablePill(
                    label = lang.label,
                    selected = isSelected,
                    onClick = { viewModel.setVoiceRecognitionLanguage(lang) },
                    modifier = Modifier.testTag("voice_lang_${lang.name}")
                )
            }
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        // Mixed-Language Recognition
        SettingSwitchRow(
            title = "Mixed-Language Recognition",
            description = "Enable seamless code-switching during voice interaction without changing settings",
            icon = Icons.Default.GraphicEq,
            checked = uiState.mixedLanguageRecognition,
            onCheckedChange = { viewModel.setMixedLanguageRecognition(it) },
            testTag = "switch_mixed_voice_recognition"
        )

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        // Voice-Language Capability Matrix
        Text(
            text = "VOICE-LANGUAGE CAPABILITY",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        // Capability Status Legend (Supported, Limited, Unsupported, Unknown)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
        ) {
            VoiceCapability.entries.forEach { cap ->
                Surface(
                    shape = CircleShape,
                    color = Color(cap.colorHex).copy(alpha = 0.15f),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(cap.colorHex).copy(alpha = 0.4f)),
                    modifier = Modifier
                        .weight(1f)
                        .testTag("cap_legend_${cap.name}")
                ) {
                    Box(
                        modifier = Modifier.padding(vertical = 4.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = cap.label,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color(cap.colorHex)
                        )
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
            viewModel.getVoiceCapabilitiesList().forEach { item ->
                VoiceCapabilityCard(
                    language = item.language,
                    description = item.description,
                    capability = item.capability,
                    testTag = "voice_capability_${item.language.replace(" ", "_").replace("/", "_").replace("(", "").replace(")", "")}"
                )
            }
        }
    }
}

@Composable
private fun VoiceCapabilityCard(
    language: String,
    description: String? = null,
    capability: VoiceCapability,
    testTag: String
) {
    SoftGlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .testTag(testTag),
        elevation = SoftTheme.tokens.elevations.flat
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Icon(
                    imageVector = Icons.Default.Mic,
                    contentDescription = null,
                    tint = SoftTheme.colors.textSecondary,
                    modifier = Modifier.size(18.dp)
                )
                Column {
                    Text(
                        text = language,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.textPrimary
                    )
                    if (description != null) {
                        Text(
                            text = description,
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }
            }

            Surface(
                shape = CircleShape,
                color = Color(capability.colorHex).copy(alpha = 0.15f),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color(capability.colorHex).copy(alpha = 0.4f))
            ) {
                Text(
                    text = capability.label,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color(capability.colorHex),
                    modifier = Modifier.padding(horizontal = SoftTheme.spacing.sm, vertical = 2.dp)
                )
            }
        }
    }
}

// ==========================================
// 5. CONNECTION SECTION (MOCK - NO REAL IP/ENDPOINTS)
// ==========================================

@Composable
private fun ConnectionSectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel
) {
    SectionCard(
        title = "Local AI Core Node",
        description = "Direct private mTLS channel configuration. Operates strictly on your internal network with zero cloud transmission.",
        icon = Icons.Default.Wifi
    ) {
        SoftGlassCard(
            modifier = Modifier
                .fillMaxWidth()
                .testTag("connection_core_card"),
            containerColor = SoftTheme.colors.surfaceElevated
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Devices,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentCyan
                        )
                        Text(
                            text = "Local AI Core Studio",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                    }

                    Surface(
                        shape = CircleShape,
                        color = SoftTheme.colors.statusSuccess.copy(alpha = 0.15f),
                        border = androidx.compose.foundation.BorderStroke(1.dp, SoftTheme.colors.statusSuccess)
                    ) {
                        Text(
                            text = "LAN Paired",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.statusSuccess,
                            modifier = Modifier.padding(horizontal = SoftTheme.spacing.sm, vertical = 2.dp)
                        )
                    }
                }

                Text(
                    text = "Direct peer-to-peer pairing parameters for on-premises companion link:",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textMuted
                )

                ConnectionMetricRow(label = "Node Topology", value = "Private Air-Gapped Mesh")
                ConnectionMetricRow(label = "Security Protocol", value = "Hardware-bound mTLS 1.3")
                ConnectionMetricRow(label = "Local Discovery", value = "mDNS / Zeroconf (Zero-Config)")
                ConnectionMetricRow(label = "Socket Endpoint", value = "[Hidden Local Core Socket]")
                ConnectionMetricRow(label = "Egress Control", value = "Strict Air-Gap (Zero Outbound Traffic)")
                ConnectionMetricRow(label = "Internal Latency", value = "12 ms (Direct WiFi 6)")
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            SoftGlassButton(
                text = "Ping Local Node",
                onClick = { viewModel.showStatus("Local ping returned in 11 ms. Zero dropped packets.") },
                modifier = Modifier
                    .weight(1f)
                    .testTag("btn_ping_node")
            )
            SoftGlassButton(
                text = "Renew Certificate",
                onClick = { viewModel.showStatus("Self-signed mTLS 1.3 certificate renewed successfully.") },
                modifier = Modifier
                    .weight(1f)
                    .testTag("btn_renew_cert")
            )
        }

        SoftGlassButton(
            text = "Re-Scan Local Mesh (mDNS)",
            onClick = { viewModel.showStatus("mDNS discovery completed: 1 desktop node verified.") },
            modifier = Modifier
                .fillMaxWidth()
                .testTag("btn_rescan_mesh")
        )
    }
}

@Composable
private fun ConnectionMetricRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = SoftTheme.colors.textSecondary
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = SoftTheme.colors.accentCyan
        )
    }
}

// ==========================================
// 6. ALARMS SECTION
// ==========================================

@Composable
private fun AlarmsSectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel
) {
    SectionCard(
        title = "Alarm & Schedule Preferences",
        description = "Configure default wake melodies, snooze buffers, and gradual volume curves.",
        icon = Icons.Default.Alarm
    ) {
        Text(
            text = "DEFAULT ALARM MELODY",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            listOf("Soft Chime", "Solar Wake", "Pulse Breeze", "Crystal Rise").forEach { tone ->
                val isSelected = uiState.defaultAlarmTone == tone
                SelectablePill(
                    label = tone,
                    selected = isSelected,
                    onClick = { viewModel.setDefaultAlarmTone(tone) },
                    modifier = Modifier.testTag("alarm_tone_${tone.replace(" ", "_")}")
                )
            }
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        Text(
            text = "DEFAULT SNOOZE INTERVAL",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            listOf(5, 10, 15).forEach { mins ->
                val isSelected = uiState.defaultSnoozeMinutes == mins
                SelectablePill(
                    label = "$mins Mins",
                    selected = isSelected,
                    onClick = { viewModel.setDefaultSnoozeMinutes(mins) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("alarm_snooze_$mins")
                )
            }
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        SettingSwitchRow(
            title = "Gradual Volume Ramp-Up",
            description = "Gently ease acoustic volume over 60 seconds for comfortable waking",
            icon = Icons.AutoMirrored.Filled.VolumeUp,
            checked = uiState.gradualVolumeRamp,
            onCheckedChange = { viewModel.toggleGradualVolumeRamp(it) },
            testTag = "switch_alarm_ramp"
        )
    }
}

// ==========================================
// 7. HEALTH SECTION
// ==========================================

@Composable
private fun HealthSectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel
) {
    SectionCard(
        title = "Health & Wellness Glance",
        description = "On-device step counters, sleep cycle telemetry, and local storage retention policies.",
        icon = Icons.Default.Favorite
    ) {
        SettingSwitchRow(
            title = "Background Step Tracking",
            description = "Count active footsteps continuously using the hardware pedometer sensor",
            icon = Icons.Default.Favorite,
            checked = uiState.backgroundStepTracking,
            onCheckedChange = { viewModel.toggleBackgroundStepTracking(it) },
            testTag = "switch_health_steps"
        )

        SettingSwitchRow(
            title = "Sleep Cycle Telemetry Sync",
            description = "Synthesize sleep duration and resting score into morning dashboard card",
            icon = Icons.Default.Alarm,
            checked = uiState.sleepCycleSync,
            onCheckedChange = { viewModel.toggleSleepCycleSync(it) },
            testTag = "switch_health_sleep"
        )

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        Text(
            text = "LOCAL DATA RETENTION",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            listOf("30 Days", "90 Days", "Indefinite").forEach { retention ->
                val isSelected = uiState.healthDataRetentionDays == retention
                SelectablePill(
                    label = retention,
                    selected = isSelected,
                    onClick = { viewModel.setHealthRetention(retention) },
                    modifier = Modifier
                        .weight(1f)
                        .testTag("health_retention_${retention.replace(" ", "_")}")
                )
            }
        }
    }
}

// ==========================================
// 8. PRIVACY SECTION
// ==========================================

@Composable
private fun PrivacySectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel,
    onNavigateToPermissions: () -> Unit = {}
) {
    SectionCard(
        title = "Privacy & Zero Telemetry",
        description = "Verification guarantees for offline edge computing and zero outbound analytics.",
        icon = Icons.Default.Security
    ) {
        // Zero Cloud Telemetry Badge
        SoftGlassCard(
            modifier = Modifier
                .fillMaxWidth()
                .testTag("privacy_shield_card"),
            containerColor = SoftTheme.colors.statusSuccess.copy(alpha = 0.08f)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.md),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                Icon(
                    imageVector = Icons.Default.Shield,
                    contentDescription = null,
                    tint = SoftTheme.colors.statusSuccess,
                    modifier = Modifier.size(28.dp)
                )
                Column {
                    Text(
                        text = "100% On-Device & On-Premises",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "No analytics, advertising trackers, or external cloud telemetry are compiled or transmitted.",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }
            }
        }

        SettingSwitchRow(
            title = "Local Audit Logging",
            description = "Maintain encrypted local log of all autonomous assistant actions and tool executions",
            icon = Icons.Default.Security,
            checked = uiState.auditLoggingEnabled,
            onCheckedChange = { viewModel.toggleAuditLogging(it) },
            testTag = "switch_audit_logging"
        )

        SettingSwitchRow(
            title = "Ephemeral Sessions Mode",
            description = "Discard conversational tokens immediately upon closing the application",
            icon = Icons.Default.Refresh,
            checked = uiState.ephemeralSessions,
            onCheckedChange = { viewModel.toggleEphemeralSessions(it) },
            testTag = "switch_ephemeral_sessions"
        )

        SoftGlassButton(
            text = "Clear Local Caches & Sessions",
            onClick = { viewModel.clearLocalCache() },
            modifier = Modifier
                .fillMaxWidth()
                .testTag("btn_clear_cache")
        )

        // BATCH 13: Android Permissions & Capabilities Audit Navigation
        SoftGlassCard(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onNavigateToPermissions() }
                .testTag("settings_permissions_audit_card"),
            containerColor = SoftTheme.colors.surfaceElevated
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.md),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                Icon(
                    imageVector = Icons.Default.Security,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentBlue,
                    modifier = Modifier.size(24.dp)
                )
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Android Permissions & Capabilities Hub",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "Audit Microphone, Notifications, Health Connect, Alarms & Audio states",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 12.sp
                    )
                }
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null,
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

// ==========================================
// 9. ADVANCED SECTION
// ==========================================

@Composable
private fun AdvancedSectionContent(
    uiState: SettingsState,
    viewModel: SettingsViewModel
) {
    SectionCard(
        title = "Advanced & Diagnostics",
        description = "Developer switches, database SQLite vacuum maintenance, and system diagnostics.",
        icon = Icons.Default.Build
    ) {
        SettingSwitchRow(
            title = "Developer Mode",
            description = "Expose raw inference tokens, model quantization tags, and low-level NPU stats",
            icon = Icons.Default.Build,
            checked = uiState.developerMode,
            onCheckedChange = { viewModel.toggleDeveloperMode(it) },
            testTag = "switch_developer_mode"
        )

        SettingSwitchRow(
            title = "Performance Diagnostics Overlay",
            description = "Display floating real-time FPS, memory usage, and frame render times",
            icon = Icons.Default.Tune,
            checked = uiState.diagnosticsOverlay,
            onCheckedChange = { viewModel.toggleDiagnosticsOverlay(it) },
            testTag = "switch_diagnostics_overlay"
        )

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        Text(
            text = "DATABASE MAINTENANCE",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.accentCyan
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(
                    text = "Vacuum SQLite FTS5 Index",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = "Last maintenance: ${uiState.lastCompactionTimestamp}",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textMuted
                )
            }

            SoftGlassButton(
                text = "Compact DB",
                onClick = { viewModel.compactDatabase() },
                modifier = Modifier.testTag("btn_compact_db")
            )
        }

        HorizontalDivider(color = SoftTheme.colors.borderSubtle)

        SoftGlassButton(
            text = "Reset All Settings to Defaults",
            onClick = { viewModel.resetToDefaults() },
            modifier = Modifier
                .fillMaxWidth()
                .testTag("btn_reset_defaults")
        )
    }
}

// ==========================================
// REUSABLE SETTINGS COMPONENTS
// ==========================================

@Composable
private fun SectionCard(
    title: String,
    description: String,
    icon: ImageVector,
    content: @Composable () -> Unit
) {
    SoftGlassCard(
        modifier = Modifier.fillMaxWidth(),
        containerColor = SoftTheme.colors.surfaceCard
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentCyan,
                    modifier = Modifier.size(24.dp)
                )
                Column {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = description,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }
            }

            HorizontalDivider(color = SoftTheme.colors.borderSubtle)

            content()
        }
    }
}

@Composable
private fun SettingSwitchRow(
    title: String,
    description: String,
    icon: ImageVector,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    testTag: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = SoftTheme.spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = SoftTheme.colors.textMuted,
                modifier = Modifier.size(20.dp)
            )
            Column {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary
                )
            }
        }

        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = SoftTheme.colors.accentCyan,
                checkedTrackColor = SoftTheme.colors.accentCyan.copy(alpha = 0.3f)
            ),
            modifier = Modifier.testTag(testTag)
        )
    }
}

@Composable
private fun SelectablePill(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(8.dp),
        color = if (selected) SoftTheme.colors.accentCyan.copy(alpha = 0.15f) else SoftTheme.colors.surfaceElevated,
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (selected) SoftTheme.colors.accentCyan else SoftTheme.colors.borderSubtle
        )
    ) {
        Box(
            modifier = Modifier.padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.sm),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                color = if (selected) SoftTheme.colors.accentCyan else SoftTheme.colors.textSecondary
            )
        }
    }
}

@Composable
private fun SelectionCardItem(
    title: String,
    subtitle: String,
    selected: Boolean,
    onClick: () -> Unit,
    testTag: String
) {
    SoftGlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .testTag(testTag),
        containerColor = if (selected) SoftTheme.colors.accentCyan.copy(alpha = 0.10f) else SoftTheme.colors.surfaceElevated,
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (selected) SoftTheme.colors.accentCyan else SoftTheme.colors.borderSubtle
        ),
        elevation = SoftTheme.tokens.elevations.flat
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary
                )
            }

            if (selected) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = "Selected",
                    tint = SoftTheme.colors.accentCyan,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}

@Composable
private fun AccentColorDot(
    color: Color,
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    testTag: String
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier
            .clickable(onClick = onClick)
            .testTag(testTag)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(color)
                .border(
                    width = if (selected) 3.dp else 1.dp,
                    color = if (selected) Color.White else Color.Transparent,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            if (selected) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.Black,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        Text(
            text = label.split(" ").first(),
            style = MaterialTheme.typography.labelSmall,
            color = if (selected) SoftTheme.colors.accentCyan else SoftTheme.colors.textMuted
        )
    }
}

@Composable
private fun StatusFeedbackBanner(
    message: String,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("status_feedback_banner"),
        containerColor = SoftTheme.colors.surfaceElevated,
        border = androidx.compose.foundation.BorderStroke(1.dp, SoftTheme.colors.accentCyan.copy(alpha = 0.5f))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = message,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textPrimary,
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = onDismiss, modifier = Modifier.size(24.dp)) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Dismiss",
                    tint = SoftTheme.colors.textSecondary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}
