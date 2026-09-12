package com.example.data.fake

import com.example.domain.model.AccentPreset
import com.example.domain.model.AppearancePreferences
import com.example.domain.model.BackgroundType
import com.example.domain.model.BuiltInBackgroundPreset
import com.example.domain.model.BuiltInGradientPreset
import com.example.domain.model.BuiltInSolidPreset
import com.example.domain.model.EffectsLevel
import com.example.domain.model.ThemeMode
import com.example.domain.model.ThemeSource
import com.example.domain.repository.AppearanceRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class FakeAppearanceRepository(
    initialPreferences: AppearancePreferences = AppearancePreferences()
) : AppearanceRepository {

    private val _preferences = MutableStateFlow(initialPreferences)
    override val preferences: StateFlow<AppearancePreferences> = _preferences.asStateFlow()

    override fun setThemeMode(mode: ThemeMode) {
        _preferences.update { it.copy(themeMode = mode) }
    }

    override fun setThemeSource(source: ThemeSource) {
        _preferences.update { it.copy(themeSource = source) }
    }

    override fun setAccentPreset(accent: AccentPreset) {
        _preferences.update { it.copy(accentPreset = accent, customAccentHex = null) }
    }

    override fun setCustomAccentHex(hex: String?) {
        _preferences.update { it.copy(customAccentHex = hex) }
    }

    override fun setBackgroundType(type: BackgroundType) {
        _preferences.update { it.copy(backgroundType = type) }
    }

    override fun setCustomImageUri(uri: String?) {
        _preferences.update { it.copy(customImageUri = uri) }
    }

    override fun setBackgroundPreset(preset: BuiltInBackgroundPreset) {
        _preferences.update { it.copy(backgroundPreset = preset) }
    }

    override fun setGradientPreset(preset: BuiltInGradientPreset) {
        _preferences.update { it.copy(gradientPreset = preset) }
    }

    override fun setSolidPreset(preset: BuiltInSolidPreset) {
        _preferences.update { it.copy(solidPreset = preset) }
    }

    override fun setEffectsLevel(level: EffectsLevel) {
        _preferences.update { it.copy(effectsLevel = level) }
    }

    override fun setScrimOpacity(opacity: Float) {
        _preferences.update { it.copy(scrimOpacity = opacity.coerceIn(0f, 1f)) }
    }

    override fun setBackgroundBrightness(brightness: Float) {
        _preferences.update { it.copy(backgroundBrightness = brightness.coerceIn(0.5f, 1.5f)) }
    }

    override fun setRefreshRateMode(mode: com.example.domain.model.RefreshRateMode) {
        _preferences.update { it.copy(refreshRateMode = mode) }
    }
}
