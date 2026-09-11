package com.example.domain.model

/**
 * Curated built-in atmospheric background presets.
 */
enum class BuiltInBackgroundPreset(
    val id: String,
    val label: String,
    val primaryGlowHex: Long,
    val secondaryGlowHex: Long,
    val isDarkCategory: Boolean = true
) {
    // Light Presets (Parity with Web Frontend)
    AURORA_MIST("aurora_mist", "Aurora Mist (Light)", 0x3DE0F2FE, 0x3DEDE9FE, false),
    PEARL_BLOOM("pearl_bloom", "Pearl Bloom (Light)", 0x3DFCE7F3, 0x3DF3E8FF, false),
    CLOUD_GLASS("cloud_glass", "Cloud Glass (Light)", 0x3DCFFAFE, 0x3DE0F2FE, false),
    LAVENDER_FLOW("lavender_flow", "Lavender Flow (Light)", 0x3DDD6FE0, 0x3DEDE9FE, false),

    // Dark Presets (Parity with Web Frontend)
    MIDNIGHT_AURORA("midnight_aurora", "Midnight Aurora (Dark)", 0x280E7490, 0x2E1E1B4B, true),
    GRAPHITE_WAVES("graphite_waves", "Graphite Waves (Dark)", 0x281E293B, 0x24334155, true),
    DEEP_VIOLET("deep_violet", "Deep Violet (Dark)", 0x284C1D95, 0x2E2E1065, true),
    BLUE_EMBER("blue_ember", "Blue Ember (Dark)", 0x280284C7, 0x2E1E3A8A, true),

    // Legacy / Companion Presets
    AURORA_CYAN("aurora_cyan", "Aurora Cyan", 0x2400C4DF, 0x207C4DFF, true),
    MIDNIGHT_SLATE("midnight_slate", "Midnight Slate", 0x280B2B47, 0x1A1F293D, true),
    DEEP_OCEAN("deep_ocean", "Deep Ocean", 0x280B2B47, 0x222E6FF2, true),
    EMBER_WARMTH("ember_warmth", "Ember Warmth", 0x334A1224, 0x26F59E0B, true),
    NEBULA_VIOLET("nebula_violet", "Nebula Violet", 0x207C4DFF, 0x2400C4DF, true)
}

/**
 * Curated mobile gradient background presets.
 */
enum class BuiltInGradientPreset(
    val id: String,
    val label: String,
    val startColorHex: Long,
    val endColorHex: Long
) {
    CYAN_VIOLET("cyan_violet", "Cyan-Violet Fluid Mesh", 0xFF00C4DF, 0xFF7C4DFF),
    AURORA_EMERALD("aurora_emerald", "Aurora Emerald Flow", 0xFF00C4DF, 0xFF10B981),
    DEEP_SPACE("deep_space", "Deep Space Nebula", 0xFF0D1117, 0xFF7C4DFF),
    SUNSET_AMBER("sunset_amber", "Sunset Amber Radiant", 0xFFF59E0B, 0xFFF43F5E)
}

/**
 * Minimalist solid finish background presets.
 */
enum class BuiltInSolidPreset(
    val id: String,
    val label: String,
    val colorHex: Long,
    val isDarkCategory: Boolean = true
) {
    // Dark Swatches
    MATTE_OBSIDIAN("matte_obsidian", "Deep Matte Obsidian (#0D1117)", 0xFF0D1117, true),
    CHARCOAL_GLASS("charcoal_glass", "Charcoal Glass (#161B22)", 0xFF161B22, true),
    PEARL_SLATE("pearl_slate", "Pearl Slate (#1F242C)", 0xFF1F242C, true),
    TRUE_BLACK("true_black", "OLED True Black (#000000)", 0xFF000000, true),

    // Light Swatches (Parity with Web Frontend)
    CRISP_CLOUD("crisp_cloud", "Crisp Cloud (#EAF0F8)", 0xFFEAF0F8, false),
    PALE_FROST("pale_frost", "Pale Frost (#F1F5F9)", 0xFFF1F5F9, false),
    WHISPER_SKY("whisper_sky", "Whisper Sky (#E0F2FE)", 0xFFE0F2FE, false),
    SOFT_PEARL("soft_pearl", "Soft Pearl (#F8FAFC)", 0xFFF8FAFC, false)
}

/**
 * Unified authoritative appearance preferences for the companion application.
 * Note: Runtime dark mode is derived dynamically via `isSystemInDarkTheme()` and is NOT
 * stored as persistent preference state.
 */
data class AppearancePreferences(
    val themeMode: ThemeMode = ThemeMode.DARK,
    val themeSource: ThemeSource = ThemeSource.PHONE_THEME,
    val accentPreset: AccentPreset = AccentPreset.CYAN,
    val backgroundType: BackgroundType = BackgroundType.BUILT_IN,
    val backgroundPreset: BuiltInBackgroundPreset = BuiltInBackgroundPreset.AURORA_CYAN,
    val gradientPreset: BuiltInGradientPreset = BuiltInGradientPreset.CYAN_VIOLET,
    val solidPreset: BuiltInSolidPreset = BuiltInSolidPreset.MATTE_OBSIDIAN,
    val customAccentHex: String? = null,
    val effectsLevel: EffectsLevel = EffectsLevel.NORMAL,
    val scrimOpacity: Float = 0.20f,
    val backgroundBrightness: Float = 1.0f
)
