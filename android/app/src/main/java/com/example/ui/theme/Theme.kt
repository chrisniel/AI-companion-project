package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import com.example.domain.model.AccentPreset
import com.example.domain.model.AppearancePreferences
import com.example.domain.model.EffectsLevel
import com.example.domain.model.ThemeMode

val LocalSoftGlassColors = staticCompositionLocalOf<SoftGlassColors> {
    error("No SoftGlassColors provided")
}

val LocalGlassTokens = staticCompositionLocalOf { GlassTokens() }

val LocalSpacing = staticCompositionLocalOf { SoftSpacing() }

val LocalAppearancePreferences = staticCompositionLocalOf { AppearancePreferences() }

@Composable
fun SoftGlassTheme(
    preferences: AppearancePreferences = AppearancePreferences(),
    isSystemDark: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val isDark = when (preferences.themeMode) {
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
        ThemeMode.SYSTEM -> isSystemDark
    }

    val fallbackBlueAccent = if (isDark) AccentBlueDark else AccentBlueLight
    val fallbackBlueSubtle = if (isDark) AccentBlueDarkSubtle else AccentBlueLightSubtle

    val (activeAccentColor, activeAccentSubtle) = if (preferences.customAccentHex != null) {
        val parsed = parseSafeHexColor(preferences.customAccentHex)
        if (parsed != null) {
            parsed to parsed.copy(alpha = 0.16f)
        } else {
            // Malformed/invalid hex safely falls back to default BLUE accent
            fallbackBlueAccent to fallbackBlueSubtle
        }
    } else {
        when (preferences.accentPreset) {
            AccentPreset.CYAN -> AccentCyan to AccentCyanSubtle
            AccentPreset.BLUE -> fallbackBlueAccent to fallbackBlueSubtle
            AccentPreset.VIOLET -> AccentViolet to AccentVioletSubtle
            AccentPreset.AMBER -> AccentAmber to AccentAmberSubtle
            AccentPreset.EMERALD -> AccentEmerald to AccentEmeraldSubtle
        }
    }

    val (shadowFactor, specularAlpha) = when (preferences.effectsLevel) {
        EffectsLevel.REDUCED -> 0.4f to 0.05f
        EffectsLevel.NORMAL -> 1.0f to 0.18f
        EffectsLevel.ENHANCED -> 1.3f to 0.30f
    }

    val colors = if (isDark) {
        SoftGlassColors(
            isDark = true,
            background = BackgroundCharcoal,
            backgroundSecondary = BackgroundGraphite,
            surface = DarkSurfaceBase,
            surfaceElevated = DarkSurfaceElevated,
            surfacePressed = DarkSurfacePressed,
            surfaceWell = DarkSurfaceWell,
            panelTranslucent = TranslucentPanelDark,
            navSurface = NavSurfaceDark,
            border = BorderDark,
            borderSubtle = BorderSubtleDark,
            borderGradient = Brush.verticalGradient(
                listOf(
                    Color.White.copy(alpha = 0.14f * specularAlpha),
                    Color.White.copy(alpha = 0.04f * specularAlpha),
                    Color.Transparent
                )
            ),
            textPrimary = TextPrimaryDark,
            textSecondary = TextSecondaryDark,
            textMuted = TextMutedDark,
            accentCyan = AccentCyan,
            accentBlue = AccentBlueDark,
            accentViolet = AccentViolet,
            accentAmber = AccentAmber,
            accentAmberSubtle = AccentAmberSubtle,
            accentPrimaryColor = activeAccentColor,
            accentGradient = SolidColor(activeAccentColor),
            shadow = ShadowDark.copy(alpha = (0.72f * shadowFactor).coerceIn(0f, 1f)),
            specularHighlight = ShadowDarkSpecular.copy(alpha = specularAlpha),
            statusSuccess = StatusSuccess,
            statusSuccessSubtle = StatusSuccessSubtle,
            statusWarning = StatusWarning,
            statusWarningSubtle = StatusWarningSubtle,
            statusError = StatusError,
            statusErrorSubtle = StatusErrorSubtle,
            statusInfo = StatusInfo,
            statusInfoSubtle = StatusInfoSubtle
        )
    } else {
        SoftGlassColors(
            isDark = false,
            background = BackgroundPearl,
            backgroundSecondary = BackgroundPearlSubtle,
            surface = MilkySurfaceBase,
            surfaceElevated = MilkySurfaceElevated,
            surfacePressed = MilkySurfacePressed,
            surfaceWell = MilkySurfaceWell,
            panelTranslucent = TranslucentPanelLight,
            navSurface = NavSurfaceLight,
            border = BorderLight,
            borderSubtle = BorderSubtleLight,
            borderGradient = Brush.verticalGradient(
                listOf(
                    Color.White.copy(alpha = 0.95f),
                    Color.White.copy(alpha = 0.50f),
                    Color(0x288298B3)
                )
            ),
            textPrimary = TextPrimaryLight,
            textSecondary = TextSecondaryLight,
            textMuted = TextMutedLight,
            accentCyan = AccentCyan,
            accentBlue = AccentBlueLight,
            accentViolet = AccentViolet,
            accentAmber = AccentAmber,
            accentAmberSubtle = AccentAmberSubtle,
            accentPrimaryColor = activeAccentColor,
            accentGradient = SolidColor(activeAccentColor),
            shadow = ShadowLight.copy(alpha = (0.24f * shadowFactor).coerceIn(0f, 1f)),
            specularHighlight = ShadowLightSpecular,
            statusSuccess = StatusSuccess,
            statusSuccessSubtle = StatusSuccessSubtle,
            statusWarning = StatusWarning,
            statusWarningSubtle = StatusWarningSubtle,
            statusError = StatusError,
            statusErrorSubtle = StatusErrorSubtle,
            statusInfo = StatusInfo,
            statusInfoSubtle = StatusInfoSubtle
        )
    }

    val m3Colors = if (isDark) {
        darkColorScheme(
            primary = activeAccentColor,
            onPrimary = Color(0xFF070B14),
            primaryContainer = activeAccentSubtle,
            onPrimaryContainer = activeAccentColor,
            secondary = AccentCyan,
            onSecondary = Color.Black,
            tertiary = AccentViolet,
            onTertiary = Color.White,
            background = BackgroundCharcoal,
            onBackground = TextPrimaryDark,
            surface = DarkSurfaceBase,
            onSurface = TextPrimaryDark,
            surfaceVariant = DarkSurfaceElevated,
            onSurfaceVariant = TextSecondaryDark,
            outline = BorderSubtleDark
        )
    } else {
        lightColorScheme(
            primary = activeAccentColor,
            onPrimary = Color.White,
            primaryContainer = activeAccentSubtle,
            onPrimaryContainer = activeAccentColor,
            secondary = AccentCyan,
            onSecondary = Color.White,
            tertiary = AccentViolet,
            onTertiary = Color.White,
            background = BackgroundPearl,
            onBackground = TextPrimaryLight,
            surface = MilkySurfaceBase,
            onSurface = TextPrimaryLight,
            surfaceVariant = MilkySurfaceElevated,
            onSurfaceVariant = TextSecondaryLight,
            outline = BorderSubtleLight
        )
    }

    val tokens = GlassTokens(effectsLevel = preferences.effectsLevel)
    val spacing = SoftSpacing()

    CompositionLocalProvider(
        LocalAppearancePreferences provides preferences,
        LocalSoftGlassColors provides colors,
        LocalGlassTokens provides tokens,
        LocalSpacing provides spacing
    ) {
        MaterialTheme(
            colorScheme = m3Colors,
            typography = SoftTypography,
            content = content
        )
    }
}

// Backward compatibility overload
@Composable
fun SoftGlassTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    SoftGlassTheme(
        preferences = AppearancePreferences(
            themeMode = if (darkTheme) ThemeMode.DARK else ThemeMode.LIGHT
        ),
        isSystemDark = darkTheme,
        content = content
    )
}

class SoftTypographyTokens(private val m3: androidx.compose.material3.Typography) {
    val displayLarge get() = m3.displayLarge
    val displayMedium get() = m3.displayMedium
    val displaySmall get() = m3.displaySmall
    val headlineLarge get() = m3.headlineLarge
    val headlineMedium get() = m3.headlineMedium
    val headlineSmall get() = m3.headlineSmall
    val titleLarge get() = m3.titleLarge
    val titleMedium get() = m3.titleMedium
    val titleSmall get() = m3.titleSmall
    val bodyLarge get() = m3.bodyLarge
    val bodyMedium get() = m3.bodyMedium
    val bodySmall get() = m3.bodySmall
    val labelLarge get() = m3.labelLarge
    val labelMedium get() = m3.labelMedium
    val labelSmall get() = m3.labelSmall
    val caption get() = m3.bodySmall
}

object SoftTheme {
    val colors: SoftGlassColors
        @Composable
        @ReadOnlyComposable
        get() = LocalSoftGlassColors.current

    val tokens: GlassTokens
        @Composable
        @ReadOnlyComposable
        get() = LocalGlassTokens.current

    val spacing: SoftSpacing
        @Composable
        @ReadOnlyComposable
        get() = LocalSpacing.current

    val typography: SoftTypographyTokens
        @Composable
        @ReadOnlyComposable
        get() = SoftTypographyTokens(MaterialTheme.typography)
}

/**
 * Safely parses a hex color string (e.g. "#RRGGBB", "#AARRGGBB", "RRGGBB", or "AARRGGBB").
 * Validates the format and returns null if malformed or invalid.
 */
fun parseSafeHexColor(hexString: String?): Color? {
    if (hexString.isNullOrBlank()) return null
    val cleanHex = hexString.trim().removePrefix("#")
    if (cleanHex.length != 6 && cleanHex.length != 8) return null
    return try {
        val parsedLong = cleanHex.toLong(16)
        if (cleanHex.length == 6) {
            Color(0xFF000000 or parsedLong)
        } else {
            Color(parsedLong)
        }
    } catch (_: Exception) {
        null
    }
}
