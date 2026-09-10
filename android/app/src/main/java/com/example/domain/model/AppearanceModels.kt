package com.example.domain.model

/**
 * Curated built-in atmospheric background presets.
 */
enum class BuiltInBackgroundPreset(
    val id: String,
    val label: String,
    val primaryGlowHex: Long,
    val secondaryGlowHex: Long
) {
    AURORA_CYAN("aurora_cyan", "Aurora Cyan", 0x2400C4DF, 0x207C4DFF),
    MIDNIGHT_SLATE("midnight_slate", "Midnight Slate", 0x280B2B47, 0x1A1F293D),
    DEEP_OCEAN("deep_ocean", "Deep Ocean", 0x280B2B47, 0x222E6FF2),
    EMBER_WARMTH("ember_warmth", "Ember Warmth", 0x334A1224, 0x26F59E0B),
    NEBULA_VIOLET("nebula_violet", "Nebula Violet", 0x207C4DFF, 0x2400C4DF)
}

/**
 * Unified authoritative appearance preferences for the companion application.
 * Note: Runtime dark mode is derived dynamically via `isSystemInDarkTheme()` and is NOT
 * stored as persistent preference state.
 */
data class AppearancePreferences(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val themeSource: ThemeSource = ThemeSource.PHONE_THEME,
    val accentPreset: AccentPreset = AccentPreset.BLUE,
    val backgroundType: BackgroundType = BackgroundType.BUILT_IN,
    val backgroundPreset: BuiltInBackgroundPreset = BuiltInBackgroundPreset.AURORA_CYAN,
    val effectsLevel: EffectsLevel = EffectsLevel.NORMAL
)
