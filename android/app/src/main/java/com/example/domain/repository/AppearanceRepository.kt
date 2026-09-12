package com.example.domain.repository

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
import kotlinx.coroutines.flow.StateFlow

/**
 * Authoritative appearance repository interface.
 * Exposes a single unified StateFlow<AppearancePreferences> consumed by
 * MainActivity, Theme, Settings, and AppShell.
 */
interface AppearanceRepository {
    val preferences: StateFlow<AppearancePreferences>

    fun setThemeMode(mode: ThemeMode)
    fun setThemeSource(source: ThemeSource)
    fun setAccentPreset(accent: AccentPreset)
    fun setCustomAccentHex(hex: String?)
    fun setBackgroundType(type: BackgroundType)
    fun setCustomImageUri(uri: String?)
    fun setBackgroundPreset(preset: BuiltInBackgroundPreset)
    fun setGradientPreset(preset: BuiltInGradientPreset)
    fun setSolidPreset(preset: BuiltInSolidPreset)
    fun setEffectsLevel(level: EffectsLevel)
    fun setScrimOpacity(opacity: Float)
    fun setBackgroundBrightness(brightness: Float)
    fun setRefreshRateMode(mode: RefreshRateMode)
}
