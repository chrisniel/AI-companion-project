package com.example.data.repository

import android.content.Context
import android.content.SharedPreferences
import com.example.domain.model.AccentPreset
import com.example.domain.model.AppearancePreferences
import com.example.domain.model.BackgroundType
import com.example.domain.model.BuiltInBackgroundPreset
import com.example.domain.model.BuiltInGradientPreset
import com.example.domain.model.BuiltInSolidPreset
import com.example.domain.model.EffectsLevel
import com.example.domain.model.RefreshRateMode
import com.example.domain.model.ThemeMode
import com.example.domain.model.ThemeSource
import com.example.domain.repository.AppearanceRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Production-ready AppearanceRepository backed by Android SharedPreferences.
 *
 * Guarantees that all user appearance configurations (theme mode, accent presets,
 * background styles, display refresh rate, and effect levels) persist across
 * process recreation, system memory kills, and device reboots.
 *
 * Performance guarantee:
 * State changes are instantly dispatched in-memory via StateFlow and persisted
 * asynchronously via SharedPreferences.Editor.apply() without blocking the UI thread.
 */
class SharedPreferencesAppearanceRepository(
    context: Context,
    prefsName: String = PREFS_NAME
) : AppearanceRepository {

    private val sharedPreferences: SharedPreferences =
        context.applicationContext.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

    private val _preferences = MutableStateFlow(loadPreferences())
    override val preferences: StateFlow<AppearancePreferences> = _preferences.asStateFlow()

    private fun loadPreferences(): AppearancePreferences {
        val themeModeStr = sharedPreferences.getString(KEY_THEME_MODE, ThemeMode.DARK.name)
        val themeMode = runCatching { ThemeMode.valueOf(themeModeStr ?: ThemeMode.DARK.name) }
            .getOrDefault(ThemeMode.DARK)

        val themeSourceStr = sharedPreferences.getString(KEY_THEME_SOURCE, ThemeSource.PHONE_THEME.name)
        val themeSource = runCatching { ThemeSource.valueOf(themeSourceStr ?: ThemeSource.PHONE_THEME.name) }
            .getOrDefault(ThemeSource.PHONE_THEME)

        val accentPresetStr = sharedPreferences.getString(KEY_ACCENT_PRESET, AccentPreset.BLUE.name)
        val accentPreset = runCatching { AccentPreset.valueOf(accentPresetStr ?: AccentPreset.BLUE.name) }
            .getOrDefault(AccentPreset.BLUE)

        val customAccentHex = sharedPreferences.getString(KEY_CUSTOM_ACCENT_HEX, null)

        val backgroundTypeStr = sharedPreferences.getString(KEY_BACKGROUND_TYPE, BackgroundType.BUILT_IN.name)
        val backgroundType = runCatching { BackgroundType.valueOf(backgroundTypeStr ?: BackgroundType.BUILT_IN.name) }
            .getOrDefault(BackgroundType.BUILT_IN)

        val backgroundPresetStr = sharedPreferences.getString(KEY_BACKGROUND_PRESET, BuiltInBackgroundPreset.AURORA_CYAN.name)
        val backgroundPreset = runCatching { BuiltInBackgroundPreset.valueOf(backgroundPresetStr ?: BuiltInBackgroundPreset.AURORA_CYAN.name) }
            .getOrDefault(BuiltInBackgroundPreset.AURORA_CYAN)

        val gradientPresetStr = sharedPreferences.getString(KEY_GRADIENT_PRESET, BuiltInGradientPreset.CYAN_VIOLET.name)
        val gradientPreset = runCatching { BuiltInGradientPreset.valueOf(gradientPresetStr ?: BuiltInGradientPreset.CYAN_VIOLET.name) }
            .getOrDefault(BuiltInGradientPreset.CYAN_VIOLET)

        val solidPresetStr = sharedPreferences.getString(KEY_SOLID_PRESET, BuiltInSolidPreset.MATTE_OBSIDIAN.name)
        val solidPreset = runCatching { BuiltInSolidPreset.valueOf(solidPresetStr ?: BuiltInSolidPreset.MATTE_OBSIDIAN.name) }
            .getOrDefault(BuiltInSolidPreset.MATTE_OBSIDIAN)

        val effectsLevelStr = sharedPreferences.getString(KEY_EFFECTS_LEVEL, EffectsLevel.NORMAL.name)
        val effectsLevel = runCatching { EffectsLevel.valueOf(effectsLevelStr ?: EffectsLevel.NORMAL.name) }
            .getOrDefault(EffectsLevel.NORMAL)

        val scrimOpacity = sharedPreferences.getFloat(KEY_SCRIM_OPACITY, 0.20f)
        val backgroundBrightness = sharedPreferences.getFloat(KEY_BACKGROUND_BRIGHTNESS, 1.0f)

        val refreshRateStr = sharedPreferences.getString(KEY_REFRESH_RATE, RefreshRateMode.SYSTEM_DEFAULT.name)
        val refreshRate = runCatching { RefreshRateMode.valueOf(refreshRateStr ?: RefreshRateMode.SYSTEM_DEFAULT.name) }
            .getOrDefault(RefreshRateMode.SYSTEM_DEFAULT)

        val customImageUri = sharedPreferences.getString(KEY_CUSTOM_IMAGE_URI, null)

        return AppearancePreferences(
            themeMode = themeMode,
            themeSource = themeSource,
            accentPreset = accentPreset,
            backgroundType = backgroundType,
            backgroundPreset = backgroundPreset,
            gradientPreset = gradientPreset,
            solidPreset = solidPreset,
            customAccentHex = customAccentHex,
            customImageUri = customImageUri,
            effectsLevel = effectsLevel,
            scrimOpacity = scrimOpacity,
            backgroundBrightness = backgroundBrightness,
            refreshRateMode = refreshRate
        )
    }

    override fun setThemeMode(mode: ThemeMode) {
        _preferences.update { it.copy(themeMode = mode) }
        sharedPreferences.edit().putString(KEY_THEME_MODE, mode.name).apply()
    }

    override fun setThemeSource(source: ThemeSource) {
        _preferences.update { it.copy(themeSource = source) }
        sharedPreferences.edit().putString(KEY_THEME_SOURCE, source.name).apply()
    }

    override fun setAccentPreset(accent: AccentPreset) {
        _preferences.update { it.copy(accentPreset = accent, customAccentHex = null) }
        sharedPreferences.edit()
            .putString(KEY_ACCENT_PRESET, accent.name)
            .remove(KEY_CUSTOM_ACCENT_HEX)
            .apply()
    }

    override fun setCustomAccentHex(hex: String?) {
        _preferences.update { it.copy(customAccentHex = hex) }
        val editor = sharedPreferences.edit()
        if (hex != null) {
            editor.putString(KEY_CUSTOM_ACCENT_HEX, hex)
        } else {
            editor.remove(KEY_CUSTOM_ACCENT_HEX)
        }
        editor.apply()
    }

    override fun setBackgroundType(type: BackgroundType) {
        _preferences.update { it.copy(backgroundType = type) }
        sharedPreferences.edit().putString(KEY_BACKGROUND_TYPE, type.name).apply()
    }

    override fun setCustomImageUri(uri: String?) {
        _preferences.update { it.copy(customImageUri = uri) }
        if (uri != null) {
            sharedPreferences.edit().putString(KEY_CUSTOM_IMAGE_URI, uri).apply()
        } else {
            sharedPreferences.edit().remove(KEY_CUSTOM_IMAGE_URI).apply()
        }
    }

    override fun setBackgroundPreset(preset: BuiltInBackgroundPreset) {
        _preferences.update { it.copy(backgroundPreset = preset) }
        sharedPreferences.edit().putString(KEY_BACKGROUND_PRESET, preset.name).apply()
    }

    override fun setGradientPreset(preset: BuiltInGradientPreset) {
        _preferences.update { it.copy(gradientPreset = preset) }
        sharedPreferences.edit().putString(KEY_GRADIENT_PRESET, preset.name).apply()
    }

    override fun setSolidPreset(preset: BuiltInSolidPreset) {
        _preferences.update { it.copy(solidPreset = preset) }
        sharedPreferences.edit().putString(KEY_SOLID_PRESET, preset.name).apply()
    }

    override fun setEffectsLevel(level: EffectsLevel) {
        _preferences.update { it.copy(effectsLevel = level) }
        sharedPreferences.edit().putString(KEY_EFFECTS_LEVEL, level.name).apply()
    }

    override fun setScrimOpacity(opacity: Float) {
        val clamped = opacity.coerceIn(0f, 1f)
        _preferences.update { it.copy(scrimOpacity = clamped) }
        sharedPreferences.edit().putFloat(KEY_SCRIM_OPACITY, clamped).apply()
    }

    override fun setBackgroundBrightness(brightness: Float) {
        val clamped = brightness.coerceIn(0.5f, 1.5f)
        _preferences.update { it.copy(backgroundBrightness = clamped) }
        sharedPreferences.edit().putFloat(KEY_BACKGROUND_BRIGHTNESS, clamped).apply()
    }

    override fun setRefreshRateMode(mode: RefreshRateMode) {
        _preferences.update { it.copy(refreshRateMode = mode) }
        sharedPreferences.edit().putString(KEY_REFRESH_RATE, mode.name).apply()
    }

    companion object {
        const val PREFS_NAME = "app_appearance_prefs"
        private const val KEY_THEME_MODE = "theme_mode"
        private const val KEY_THEME_SOURCE = "theme_source"
        private const val KEY_ACCENT_PRESET = "accent_preset"
        private const val KEY_CUSTOM_ACCENT_HEX = "custom_accent_hex"
        private const val KEY_BACKGROUND_TYPE = "background_type"
        private const val KEY_CUSTOM_IMAGE_URI = "custom_image_uri"
        private const val KEY_BACKGROUND_PRESET = "background_preset"
        private const val KEY_GRADIENT_PRESET = "gradient_preset"
        private const val KEY_SOLID_PRESET = "solid_preset"
        private const val KEY_EFFECTS_LEVEL = "effects_level"
        private const val KEY_SCRIM_OPACITY = "scrim_opacity"
        private const val KEY_BACKGROUND_BRIGHTNESS = "background_brightness"
        private const val KEY_REFRESH_RATE = "refresh_rate_mode"
    }
}
