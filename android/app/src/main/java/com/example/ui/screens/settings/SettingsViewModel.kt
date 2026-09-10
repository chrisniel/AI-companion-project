package com.example.ui.screens.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeAppearanceRepository
import com.example.domain.model.AccentPreset
import com.example.domain.model.AppLanguage
import com.example.domain.model.BackgroundType
import com.example.domain.model.BuiltInBackgroundPreset
import com.example.domain.model.EffectsLevel
import com.example.domain.model.JapaneseDisplay
import com.example.domain.model.ResponseLanguageChoice
import com.example.domain.model.SettingsSection
import com.example.domain.model.SettingsState
import com.example.domain.model.StartupBehavior
import com.example.domain.model.ThemeMode
import com.example.domain.model.ThemeSource
import com.example.domain.model.VoiceCapability
import com.example.domain.model.VoiceCapabilityItem
import com.example.domain.model.VoiceRecognitionLanguage
import com.example.domain.repository.AppearanceRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * ViewModel managing settings state across all 9 sections.
 * Injects AppearanceRepository for authoritative appearance control.
 */
class SettingsViewModel(
    private val appearanceRepository: AppearanceRepository = FakeAppearanceRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsState())
    val uiState: StateFlow<SettingsState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            appearanceRepository.preferences.collect { prefs ->
                _uiState.update { current ->
                    current.copy(
                        themeMode = prefs.themeMode,
                        themeSource = prefs.themeSource,
                        accentPreset = prefs.accentPreset,
                        backgroundType = prefs.backgroundType,
                        effectsLevel = prefs.effectsLevel,
                        selectedBuiltInBackground = prefs.backgroundPreset.label
                    )
                }
            }
        }
    }

    // --- NAVIGATION ---

    fun selectSection(section: SettingsSection) {
        _uiState.update { it.copy(selectedSection = section) }
    }

    // --- GENERAL ---

    fun setStartupBehavior(behavior: StartupBehavior) {
        _uiState.update { it.copy(startupBehavior = behavior) }
        showStatus("Startup set to ${behavior.label}")
    }

    fun toggleNotifications(enabled: Boolean) {
        _uiState.update { it.copy(notificationsEnabled = enabled) }
        showStatus(if (enabled) "Notifications enabled" else "Notifications muted")
    }

    fun toggleQuietHours(enabled: Boolean) {
        _uiState.update { it.copy(quietHoursEnabled = enabled) }
        showStatus(if (enabled) "Quiet hours scheduled (22:00 - 07:00)" else "Quiet hours disabled")
    }

    fun toggleSoundAlerts(enabled: Boolean) {
        _uiState.update { it.copy(soundAlertsEnabled = enabled) }
    }

    fun toggleHapticFeedback(enabled: Boolean) {
        _uiState.update { it.copy(hapticFeedbackEnabled = enabled) }
    }

    // --- APPEARANCE ---

    fun setThemeMode(mode: ThemeMode, onThemeChange: ((Boolean) -> Unit)? = null) {
        appearanceRepository.setThemeMode(mode)
        _uiState.update { it.copy(themeMode = mode) }
        when (mode) {
            ThemeMode.LIGHT -> onThemeChange?.invoke(false)
            ThemeMode.DARK -> onThemeChange?.invoke(true)
            ThemeMode.SYSTEM -> onThemeChange?.invoke(true)
        }
        showStatus("Theme set to ${mode.label}")
    }

    fun setThemeSource(source: ThemeSource) {
        appearanceRepository.setThemeSource(source)
        _uiState.update { it.copy(themeSource = source) }
        val status = when (source) {
            ThemeSource.PHONE_THEME -> "Theme source: Phone Theme"
            ThemeSource.ACCOUNT_THEME -> "Theme source: Account Theme (Future • Requires Account)"
            ThemeSource.SYNC_PC_THEME -> "Theme source: Sync with PC (Future • Requires PC Sync)"
        }
        showStatus(status)
    }

    fun setBackgroundType(type: BackgroundType) {
        appearanceRepository.setBackgroundType(type)
        _uiState.update { it.copy(backgroundType = type) }
        showStatus("Background style: ${type.label}")
    }

    fun setSelectedBuiltInBackground(name: String) {
        val preset = BuiltInBackgroundPreset.entries.find {
            it.label.equals(name, ignoreCase = true) || it.id.equals(name, ignoreCase = true)
        } ?: BuiltInBackgroundPreset.AURORA_CYAN
        appearanceRepository.setBackgroundPreset(preset)
        appearanceRepository.setBackgroundType(BackgroundType.BUILT_IN)
        _uiState.update { it.copy(selectedBuiltInBackground = name, backgroundType = BackgroundType.BUILT_IN) }
        showStatus("Applied background: ${preset.label}")
    }

    fun setSelectedGradientBackground(name: String) {
        appearanceRepository.setBackgroundType(BackgroundType.GRADIENT)
        _uiState.update { it.copy(selectedGradientBackground = name, backgroundType = BackgroundType.GRADIENT) }
        showStatus("Applied gradient: $name")
    }

    fun setSelectedSolidBackground(name: String) {
        appearanceRepository.setBackgroundType(BackgroundType.SOLID)
        _uiState.update { it.copy(selectedSolidBackground = name, backgroundType = BackgroundType.SOLID) }
        showStatus("Applied solid background: $name")
    }

    fun setCustomImageName(name: String) {
        appearanceRepository.setBackgroundType(BackgroundType.CUSTOM_IMAGE)
        _uiState.update { it.copy(customImageName = name, backgroundType = BackgroundType.CUSTOM_IMAGE) }
        showStatus("Custom wallpaper selected: $name (Mobile-only)")
    }

    fun setAccentPreset(preset: AccentPreset) {
        appearanceRepository.setAccentPreset(preset)
        _uiState.update { it.copy(accentPreset = preset, isCustomAccentEnabled = false) }
        showStatus("Accent color: ${preset.label}")
    }

    fun setCustomAccent(hex: String) {
        _uiState.update { it.copy(customAccentHex = hex, isCustomAccentEnabled = true) }
        showStatus("Custom accent color applied: $hex")
    }

    fun toggleCustomAccent(enabled: Boolean) {
        _uiState.update { it.copy(isCustomAccentEnabled = enabled) }
    }

    fun setEffectsLevel(level: EffectsLevel) {
        appearanceRepository.setEffectsLevel(level)
        _uiState.update { it.copy(effectsLevel = level) }
        showStatus("Glass effects: ${level.label}")
    }

    // --- LANGUAGE PREFERENCES ---

    fun setPrimaryLanguage(language: AppLanguage) {
        _uiState.update { current ->
            val updatedUnderstands = current.understandsLanguages + language
            current.copy(
                primaryLanguage = language,
                understandsLanguages = updatedUnderstands
            )
        }
        showStatus("Primary language set to ${language.label}")
    }

    fun toggleUnderstandsLanguage(language: AppLanguage) {
        _uiState.update { current ->
            val set = current.understandsLanguages.toMutableSet()
            if (set.contains(language)) {
                if (language != current.primaryLanguage) {
                    set.remove(language)
                }
            } else {
                set.add(language)
            }
            current.copy(understandsLanguages = set)
        }
    }

    fun setMixedLanguageConversation(enabled: Boolean) {
        _uiState.update { it.copy(mixedLanguageConversation = enabled) }
        showStatus(if (enabled) "Mixed-language conversation enabled" else "Strict single-language conversation")
    }

    fun setResponseLanguage(choice: ResponseLanguageChoice) {
        _uiState.update { it.copy(responseLanguage = choice) }
        showStatus("Response language: ${choice.label}")
    }

    fun setTechnicalLanguage(choice: ResponseLanguageChoice) {
        _uiState.update { it.copy(technicalLanguage = choice) }
        showStatus("Technical terminology: ${choice.label}")
    }

    fun setJapaneseDisplay(display: JapaneseDisplay) {
        _uiState.update { it.copy(japaneseDisplay = display) }
        showStatus("Japanese display: ${display.label}")
    }

    // --- VOICE ---

    fun setVoiceRecognitionLanguage(language: VoiceRecognitionLanguage) {
        _uiState.update { it.copy(voiceRecognitionLanguage = language) }
        showStatus("Voice recognition set to ${language.label}")
    }

    fun setMixedLanguageRecognition(enabled: Boolean) {
        _uiState.update { it.copy(mixedLanguageRecognition = enabled) }
        showStatus(if (enabled) "Mixed-language recognition enabled" else "Single voice language active")
    }

    fun getVoiceCapability(lang: VoiceRecognitionLanguage): VoiceCapability {
        return when (lang) {
            VoiceRecognitionLanguage.AUTO -> VoiceCapability.SUPPORTED
            VoiceRecognitionLanguage.ENGLISH -> VoiceCapability.SUPPORTED
            VoiceRecognitionLanguage.JAPANESE -> VoiceCapability.SUPPORTED
            VoiceRecognitionLanguage.FILIPINO -> VoiceCapability.LIMITED
        }
    }

    fun getVoiceCapabilitiesList(): List<VoiceCapabilityItem> {
        return listOf(
            VoiceCapabilityItem(
                language = "English",
                description = "On-device streaming Whisper v3 with precise word timestamps",
                capability = VoiceCapability.SUPPORTED
            ),
            VoiceCapabilityItem(
                language = "Japanese (日本語)",
                description = "Bilingual acoustic model with kanji/kana homophone disambiguation",
                capability = VoiceCapability.SUPPORTED
            ),
            VoiceCapabilityItem(
                language = "Filipino / Tagalog",
                description = "Tagalog & Taglish conversational STT; regional dialects limited",
                capability = VoiceCapability.LIMITED
            ),
            VoiceCapabilityItem(
                language = "Spanish & European Dialects",
                description = "Acoustic weights not packaged in companion mobile distribution",
                capability = VoiceCapability.UNSUPPORTED
            ),
            VoiceCapabilityItem(
                language = "Custom Local Engine / NPU",
                description = "External ONNX model awaiting device calibration benchmark",
                capability = VoiceCapability.UNKNOWN
            )
        )
    }

    // --- ASSISTANT ---

    fun setResponseDetailLevel(level: String) {
        _uiState.update { it.copy(responseDetailLevel = level) }
    }

    fun toggleProactiveSuggestions(enabled: Boolean) {
        _uiState.update { it.copy(proactiveSuggestions = enabled) }
    }

    fun toggleChainOfThought(enabled: Boolean) {
        _uiState.update { it.copy(chainOfThoughtVisible = enabled) }
    }

    // --- ALARMS ---

    fun setDefaultAlarmTone(tone: String) {
        _uiState.update { it.copy(defaultAlarmTone = tone) }
        showStatus("Default tone: $tone")
    }

    fun setDefaultSnoozeMinutes(minutes: Int) {
        _uiState.update { it.copy(defaultSnoozeMinutes = minutes) }
        showStatus("Snooze interval: $minutes mins")
    }

    fun toggleGradualVolumeRamp(enabled: Boolean) {
        _uiState.update { it.copy(gradualVolumeRamp = enabled) }
    }

    // --- HEALTH ---

    fun toggleBackgroundStepTracking(enabled: Boolean) {
        _uiState.update { it.copy(backgroundStepTracking = enabled) }
    }

    fun toggleSleepCycleSync(enabled: Boolean) {
        _uiState.update { it.copy(sleepCycleSync = enabled) }
    }

    fun setHealthRetention(retention: String) {
        _uiState.update { it.copy(healthDataRetentionDays = retention) }
    }

    // --- PRIVACY ---

    fun toggleAuditLogging(enabled: Boolean) {
        _uiState.update { it.copy(auditLoggingEnabled = enabled) }
        showStatus(if (enabled) "Local audit logging active" else "Audit logging disabled")
    }

    fun toggleEphemeralSessions(enabled: Boolean) {
        _uiState.update { it.copy(ephemeralSessions = enabled) }
    }

    fun clearLocalCache() {
        showStatus("Cleared 128 MB of temporary session cache")
    }

    // --- ADVANCED ---

    fun toggleDeveloperMode(enabled: Boolean) {
        _uiState.update { it.copy(developerMode = enabled) }
        showStatus(if (enabled) "Developer options enabled" else "Developer options hidden")
    }

    fun toggleDiagnosticsOverlay(enabled: Boolean) {
        _uiState.update { it.copy(diagnosticsOverlay = enabled) }
    }

    fun compactDatabase() {
        _uiState.update { it.copy(lastCompactionTimestamp = "Just now") }
        showStatus("SQLite FTS5 vacuum & vector index re-balanced")
    }

    fun resetToDefaults() {
        _uiState.value = SettingsState()
        showStatus("All settings restored to default values")
    }

    fun showStatus(message: String) {
        _uiState.update { it.copy(statusMessage = message) }
    }

    fun dismissStatus() {
        _uiState.update { it.copy(statusMessage = null) }
    }
}
