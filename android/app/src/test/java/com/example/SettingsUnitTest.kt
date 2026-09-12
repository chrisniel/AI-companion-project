package com.example

import com.example.domain.model.AccentPreset
import com.example.domain.model.AppLanguage
import com.example.domain.model.BackgroundType
import com.example.domain.model.BuiltInBackgroundPreset
import com.example.domain.model.EffectsLevel
import com.example.domain.model.JapaneseDisplay
import com.example.domain.model.RefreshRateMode
import com.example.domain.model.ResponseLanguageChoice
import com.example.domain.model.SettingsSection
import com.example.domain.model.StartupBehavior
import com.example.domain.model.ThemeMode
import com.example.domain.model.ThemeSource
import com.example.domain.model.VoiceCapability
import com.example.domain.model.VoiceRecognitionLanguage
import com.example.ui.screens.settings.SettingsViewModel
import com.example.ui.theme.parseSafeHexColor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Comprehensive unit test suite for Batch 11: Mobile Settings, Appearance and Language.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class SettingsUnitTest {

    private val testDispatcher = UnconfinedTestDispatcher()
    private lateinit var viewModel: SettingsViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        viewModel = SettingsViewModel()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ==========================================
    // 1. SECTIONS NAVIGATION (9 REQUIRED SECTIONS)
    // ==========================================

    @Test
    fun `settings supports all 9 required sections`() {
        val expectedSections = setOf(
            SettingsSection.GENERAL,
            SettingsSection.APPEARANCE,
            SettingsSection.ASSISTANT,
            SettingsSection.VOICE,
            SettingsSection.CONNECTION,
            SettingsSection.ALARMS,
            SettingsSection.HEALTH,
            SettingsSection.PRIVACY,
            SettingsSection.ADVANCED
        )
        assertEquals(9, SettingsSection.entries.size)
        assertEquals(expectedSections, SettingsSection.entries.toSet())
    }

    @Test
    fun `navigation updates active section`() {
        assertEquals(SettingsSection.GENERAL, viewModel.uiState.value.selectedSection)

        viewModel.selectSection(SettingsSection.APPEARANCE)
        assertEquals(SettingsSection.APPEARANCE, viewModel.uiState.value.selectedSection)

        viewModel.selectSection(SettingsSection.VOICE)
        assertEquals(SettingsSection.VOICE, viewModel.uiState.value.selectedSection)

        viewModel.selectSection(SettingsSection.CONNECTION)
        assertEquals(SettingsSection.CONNECTION, viewModel.uiState.value.selectedSection)
    }

    // ==========================================
    // 2. GENERAL SETTINGS
    // ==========================================

    @Test
    fun `general mock preferences can be updated`() {
        viewModel.setStartupBehavior(StartupBehavior.VOICE_ASSISTANT)
        assertEquals(StartupBehavior.VOICE_ASSISTANT, viewModel.uiState.value.startupBehavior)

        viewModel.toggleNotifications(false)
        assertFalse(viewModel.uiState.value.notificationsEnabled)

        viewModel.toggleQuietHours(true)
        assertTrue(viewModel.uiState.value.quietHoursEnabled)

        viewModel.toggleSoundAlerts(false)
        assertFalse(viewModel.uiState.value.soundAlertsEnabled)

        viewModel.toggleHapticFeedback(false)
        assertFalse(viewModel.uiState.value.hapticFeedbackEnabled)
    }

    // ==========================================
    // 3. APPEARANCE SETTINGS
    // ==========================================

    @Test
    fun `theme mode supports Light, Dark, OLED Battery Saver, System`() {
        val expectedModes = setOf(ThemeMode.LIGHT, ThemeMode.DARK, ThemeMode.OLED_BATTERY_SAVER, ThemeMode.SYSTEM)
        assertEquals(expectedModes, ThemeMode.entries.toSet())

        viewModel.setThemeMode(ThemeMode.LIGHT)
        assertEquals(ThemeMode.LIGHT, viewModel.uiState.value.themeMode)

        viewModel.setThemeMode(ThemeMode.DARK)
        assertEquals(ThemeMode.DARK, viewModel.uiState.value.themeMode)

        viewModel.setThemeMode(ThemeMode.OLED_BATTERY_SAVER)
        assertEquals(ThemeMode.OLED_BATTERY_SAVER, viewModel.uiState.value.themeMode)

        viewModel.setThemeMode(ThemeMode.SYSTEM)
        assertEquals(ThemeMode.SYSTEM, viewModel.uiState.value.themeMode)
    }

    @Test
    fun `theme source supports Phone Theme, Account Theme, Sync with PC Theme`() {
        val expectedSources = setOf(
            ThemeSource.PHONE_THEME,
            ThemeSource.ACCOUNT_THEME,
            ThemeSource.SYNC_PC_THEME
        )
        assertEquals(expectedSources, ThemeSource.entries.toSet())

        viewModel.setThemeSource(ThemeSource.SYNC_PC_THEME)
        assertEquals(ThemeSource.SYNC_PC_THEME, viewModel.uiState.value.themeSource)

        viewModel.setThemeSource(ThemeSource.ACCOUNT_THEME)
        assertEquals(ThemeSource.ACCOUNT_THEME, viewModel.uiState.value.themeSource)

        viewModel.setThemeSource(ThemeSource.PHONE_THEME)
        assertEquals(ThemeSource.PHONE_THEME, viewModel.uiState.value.themeSource)
    }

    @Test
    fun `background supports Built-in, Custom Image UI, Gradient, Solid`() {
        val expectedTypes = setOf(
            BackgroundType.BUILT_IN,
            BackgroundType.CUSTOM_IMAGE,
            BackgroundType.GRADIENT,
            BackgroundType.SOLID
        )
        assertEquals(expectedTypes, BackgroundType.entries.toSet())

        viewModel.setSelectedBuiltInBackground("Aurora Glass")
        assertEquals(BackgroundType.BUILT_IN, viewModel.uiState.value.backgroundType)
        assertEquals("Aurora Glass", viewModel.uiState.value.selectedBuiltInBackground)

        viewModel.setCustomImageName("mobile_aurora_custom.jpg")
        assertEquals(BackgroundType.CUSTOM_IMAGE, viewModel.uiState.value.backgroundType)
        assertEquals("mobile_aurora_custom.jpg", viewModel.uiState.value.customImageName)

        viewModel.setSelectedGradientBackground("Cyan-Violet Fluid Mesh")
        assertEquals(BackgroundType.GRADIENT, viewModel.uiState.value.backgroundType)
        assertEquals("Cyan-Violet Fluid Mesh", viewModel.uiState.value.selectedGradientBackground)

        viewModel.setSelectedSolidBackground("Deep Matte Obsidian (#0D1117)")
        assertEquals(BackgroundType.SOLID, viewModel.uiState.value.backgroundType)
        assertEquals("Deep Matte Obsidian (#0D1117)", viewModel.uiState.value.selectedSolidBackground)
    }

    @Test
    fun `built-in background presets match domain entries and apply cleanly`() {
        BuiltInBackgroundPreset.entries.forEach { preset ->
            viewModel.setSelectedBuiltInBackground(preset.label)
            assertEquals(preset.label, viewModel.uiState.value.selectedBuiltInBackground)
            assertEquals(BackgroundType.BUILT_IN, viewModel.uiState.value.backgroundType)
        }
    }

    @Test
    fun `accent supports presets and custom hex`() {
        viewModel.setAccentPreset(AccentPreset.EMERALD)
        assertEquals(AccentPreset.EMERALD, viewModel.uiState.value.accentPreset)
        assertFalse(viewModel.uiState.value.isCustomAccentEnabled)

        viewModel.setCustomAccent("#FF0055")
        assertEquals("#FF0055", viewModel.uiState.value.customAccentHex)
        assertTrue(viewModel.uiState.value.isCustomAccentEnabled)

        viewModel.toggleCustomAccent(false)
        assertFalse(viewModel.uiState.value.isCustomAccentEnabled)
    }

    @Test
    fun `custom accent hex parsing is safe and rejects malformed values`() {
        // Valid 6-digit hex
        assertNotNull(parseSafeHexColor("#FF0055"))
        assertNotNull(parseSafeHexColor("FF0055"))

        // Valid 8-digit hex (ARGB)
        assertNotNull(parseSafeHexColor("#80FF0055"))
        assertNotNull(parseSafeHexColor("80FF0055"))

        // Malformed / invalid values must safely return null without throwing
        assertNull(parseSafeHexColor("invalid"))
        assertNull(parseSafeHexColor("#123"))
        assertNull(parseSafeHexColor("#GGGGGG"))
        assertNull(parseSafeHexColor("ZZZZZZ"))
        assertNull(parseSafeHexColor(""))
        assertNull(parseSafeHexColor("   "))
        assertNull(parseSafeHexColor(null))
    }

    @Test
    fun `effects supports Reduced, Normal, Enhanced`() {
        val expectedEffects = setOf(
            EffectsLevel.REDUCED,
            EffectsLevel.NORMAL,
            EffectsLevel.ENHANCED
        )
        assertEquals(expectedEffects, EffectsLevel.entries.toSet())

        viewModel.setEffectsLevel(EffectsLevel.REDUCED)
        assertEquals(EffectsLevel.REDUCED, viewModel.uiState.value.effectsLevel)

        viewModel.setEffectsLevel(EffectsLevel.ENHANCED)
        assertEquals(EffectsLevel.ENHANCED, viewModel.uiState.value.effectsLevel)
    }

    @Test
    fun `refresh rate mode supports System Dynamic, Force High 120Hz, and Battery Saver 60Hz`() {
        val expectedModes = setOf(
            RefreshRateMode.SYSTEM_DEFAULT,
            RefreshRateMode.FORCE_HIGH,
            RefreshRateMode.POWER_SAVER
        )
        assertEquals(expectedModes, RefreshRateMode.entries.toSet())

        // Default should be SYSTEM_DEFAULT
        assertEquals(RefreshRateMode.SYSTEM_DEFAULT, viewModel.uiState.value.refreshRateMode)

        viewModel.setRefreshRateMode(RefreshRateMode.FORCE_HIGH)
        assertEquals(RefreshRateMode.FORCE_HIGH, viewModel.uiState.value.refreshRateMode)

        viewModel.setRefreshRateMode(RefreshRateMode.POWER_SAVER)
        assertEquals(RefreshRateMode.POWER_SAVER, viewModel.uiState.value.refreshRateMode)
    }

    // ==========================================
    // 4. LANGUAGE PREFERENCES
    // ==========================================

    @Test
    fun `primary language supports English, Filipino, Japanese`() {
        val expectedLanguages = setOf(
            AppLanguage.ENGLISH,
            AppLanguage.FILIPINO,
            AppLanguage.JAPANESE
        )
        assertEquals(expectedLanguages, AppLanguage.entries.toSet())

        viewModel.setPrimaryLanguage(AppLanguage.FILIPINO)
        assertEquals(AppLanguage.FILIPINO, viewModel.uiState.value.primaryLanguage)
        assertTrue(viewModel.uiState.value.understandsLanguages.contains(AppLanguage.FILIPINO))

        viewModel.setPrimaryLanguage(AppLanguage.JAPANESE)
        assertEquals(AppLanguage.JAPANESE, viewModel.uiState.value.primaryLanguage)
        assertTrue(viewModel.uiState.value.understandsLanguages.contains(AppLanguage.JAPANESE))
    }

    @Test
    fun `understands languages multi-selection works and retains primary language`() {
        viewModel.setPrimaryLanguage(AppLanguage.ENGLISH)
        assertTrue(viewModel.uiState.value.understandsLanguages.contains(AppLanguage.ENGLISH))

        // Toggle Filipino off and on
        viewModel.toggleUnderstandsLanguage(AppLanguage.FILIPINO)
        assertFalse(viewModel.uiState.value.understandsLanguages.contains(AppLanguage.FILIPINO))

        viewModel.toggleUnderstandsLanguage(AppLanguage.FILIPINO)
        assertTrue(viewModel.uiState.value.understandsLanguages.contains(AppLanguage.FILIPINO))

        // Toggling primary language off is guarded
        viewModel.toggleUnderstandsLanguage(AppLanguage.ENGLISH)
        assertTrue(viewModel.uiState.value.understandsLanguages.contains(AppLanguage.ENGLISH))
    }

    @Test
    fun `mixed language conversation toggle works`() {
        viewModel.setMixedLanguageConversation(false)
        assertFalse(viewModel.uiState.value.mixedLanguageConversation)

        viewModel.setMixedLanguageConversation(true)
        assertTrue(viewModel.uiState.value.mixedLanguageConversation)
    }

    @Test
    fun `response language and technical language support Match User, English, Filipino, Japanese`() {
        val expectedChoices = setOf(
            ResponseLanguageChoice.MATCH_USER,
            ResponseLanguageChoice.ENGLISH,
            ResponseLanguageChoice.FILIPINO,
            ResponseLanguageChoice.JAPANESE
        )
        assertEquals(expectedChoices, ResponseLanguageChoice.entries.toSet())

        viewModel.setResponseLanguage(ResponseLanguageChoice.FILIPINO)
        assertEquals(ResponseLanguageChoice.FILIPINO, viewModel.uiState.value.responseLanguage)

        viewModel.setTechnicalLanguage(ResponseLanguageChoice.JAPANESE)
        assertEquals(ResponseLanguageChoice.JAPANESE, viewModel.uiState.value.technicalLanguage)
    }

    @Test
    fun `japanese display supports 3 formats`() {
        val expectedDisplays = setOf(
            JapaneseDisplay.JAPANESE_ONLY,
            JapaneseDisplay.JAPANESE_ROMAJI,
            JapaneseDisplay.JAPANESE_ENGLISH
        )
        assertEquals(expectedDisplays, JapaneseDisplay.entries.toSet())

        viewModel.setJapaneseDisplay(JapaneseDisplay.JAPANESE_ROMAJI)
        assertEquals(JapaneseDisplay.JAPANESE_ROMAJI, viewModel.uiState.value.japaneseDisplay)

        viewModel.setJapaneseDisplay(JapaneseDisplay.JAPANESE_ONLY)
        assertEquals(JapaneseDisplay.JAPANESE_ONLY, viewModel.uiState.value.japaneseDisplay)
    }

    // ==========================================
    // 5. VOICE SETTINGS
    // ==========================================

    @Test
    fun `voice recognition language supports Auto, English, Filipino, Japanese`() {
        val expectedLanguages = setOf(
            VoiceRecognitionLanguage.AUTO,
            VoiceRecognitionLanguage.ENGLISH,
            VoiceRecognitionLanguage.FILIPINO,
            VoiceRecognitionLanguage.JAPANESE
        )
        assertEquals(expectedLanguages, VoiceRecognitionLanguage.entries.toSet())

        viewModel.setVoiceRecognitionLanguage(VoiceRecognitionLanguage.JAPANESE)
        assertEquals(VoiceRecognitionLanguage.JAPANESE, viewModel.uiState.value.voiceRecognitionLanguage)
    }

    @Test
    fun `mixed language voice recognition toggle works`() {
        viewModel.setMixedLanguageRecognition(false)
        assertFalse(viewModel.uiState.value.mixedLanguageRecognition)

        viewModel.setMixedLanguageRecognition(true)
        assertTrue(viewModel.uiState.value.mixedLanguageRecognition)
    }

    @Test
    fun `voice capabilities list displays Supported, Limited, Unsupported, and Unknown`() {
        val capabilities = viewModel.getVoiceCapabilitiesList()
        assertNotNull(capabilities)
        assertTrue(capabilities.isNotEmpty())

        val capabilityTypes = capabilities.map { it.capability }.toSet()
        assertTrue("Must contain SUPPORTED", capabilityTypes.contains(VoiceCapability.SUPPORTED))
        assertTrue("Must contain LIMITED", capabilityTypes.contains(VoiceCapability.LIMITED))
        assertTrue("Must contain UNSUPPORTED", capabilityTypes.contains(VoiceCapability.UNSUPPORTED))
        assertTrue("Must contain UNKNOWN", capabilityTypes.contains(VoiceCapability.UNKNOWN))
    }

    // ==========================================
    // 6. RESET DEFAULTS
    // ==========================================

    @Test
    fun `reset to defaults restores baseline configuration`() {
        viewModel.setPrimaryLanguage(AppLanguage.JAPANESE)
        viewModel.setThemeMode(ThemeMode.LIGHT)
        viewModel.toggleNotifications(false)

        viewModel.resetToDefaults()

        assertEquals(AppLanguage.ENGLISH, viewModel.uiState.value.primaryLanguage)
        assertEquals(ThemeMode.DARK, viewModel.uiState.value.themeMode)
        assertTrue(viewModel.uiState.value.notificationsEnabled)
    }
}
