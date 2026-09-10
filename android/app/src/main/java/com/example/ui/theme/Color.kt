package com.example.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor

// Light Mode Foundations: Soft Icy Pearl Canvas + Tactile White/Debossed Wells
val BackgroundPearl = Color(0xFFE8EEF6)
val BackgroundPearlSubtle = Color(0xFFDFE7F2)
val MilkySurfaceBase = Color(0xF2FFFFFF)         // Calibrated soft translucency (~95%)
val MilkySurfaceElevated = Color(0xF8FFFFFF)     // Raised card surface
val MilkySurfacePressed = Color(0xFFDFE6F1)
val MilkySurfaceWell = Color(0xFFE2E9F4)
val TranslucentPanelLight = Color(0xE6FFFFFF)    // Calibrated panel (~90%)
val NavSurfaceLight = Color(0xF0FFFFFF)          // Calibrated floating navigation surface
val BorderLight = Color(0xD9FFFFFF)
val BorderSubtleLight = Color(0x388298B3)
val ShadowLight = Color(0x3D7F95AF)
val ShadowLightSpecular = Color(0xF5FFFFFF)

// Dark Mode Foundations: Deep Obsidian Midnight Slate + Restrained Specular Accents
val BackgroundCharcoal = Color(0xFF0A0E17)
val BackgroundGraphite = Color(0xFF0F1422)
val DarkSurfaceBase = Color(0xF0121726)
val DarkSurfaceElevated = Color(0xF8162034)
val DarkSurfacePressed = Color(0xFF0A0D15)
val DarkSurfaceWell = Color(0xFF0D121E)
val TranslucentPanelDark = Color(0xEB111624)
val NavSurfaceDark = Color(0xF2111624)
val BorderDark = Color(0x14FFFFFF)               // Restrained subtle hairline border (8% alpha)
val BorderSubtleDark = Color(0x0AFFFFFF)         // Subdued border (4% alpha)
val ShadowDark = Color(0xB8000000)
val ShadowDarkSpecular = Color(0x14FFFFFF)

// Accent Blue Foundations: Darker shade of blue for light mode, Light shade of blue for dark mode
val AccentBlueLight = Color(0xFF1D4ED8)          // Dark cobalt/royal blue (Blue 700) for light mode
val AccentBlueLightSubtle = Color(0x1F1D4ED8)

val AccentBlueDark = Color(0xFF60A5FA)           // Luminous azure sky blue (Blue 400) for dark mode
val AccentBlueDarkSubtle = Color(0x2660A5FA)

// Base reference (defaults to light mode accent)
val AccentBlue = AccentBlueLight
val AccentBlueSubtle = AccentBlueLightSubtle

// Restrained secondary accents
val AccentCyan = Color(0xFF00E5FF)
val AccentCyanSubtle = Color(0x2600E5FF)
val AccentViolet = Color(0xFF7C3AED)
val AccentVioletSubtle = Color(0x267C3AED)
val AccentAmber = Color(0xFFF59E0B)
val AccentAmberSubtle = Color(0x26F59E0B)
val AccentEmerald = Color(0xFF10B981)
val AccentEmeraldSubtle = Color(0x2610B981)

// Solid Color Brushes replacing multi-color gradients
val AccentGradientLight: Brush = SolidColor(AccentBlueLight)
val AccentGradientDark: Brush = SolidColor(AccentBlueDark)

// Ambient Canvas Mesh Accents (Restrained Aura Glow)
val AmbientGlowCyan = Color(0x2400C4DF)
val AmbientGlowViolet = Color(0x207C4DFF)
val AmbientGlowBlue = Color(0x222E6FF2)
val AmbientGlowEmber = Color(0x334A1224)
val AmbientGlowOcean = Color(0x280B2B47)

// Semantic Status Colors
val StatusSuccess = Color(0xFF10B981)
val StatusSuccessSubtle = Color(0x1F10B981)
val StatusWarning = Color(0xFFF59E0B)
val StatusWarningSubtle = Color(0x1FF59E0B)
val StatusError = Color(0xFFEF4444)
val StatusErrorSubtle = Color(0x1FEF4444)
val StatusInfo = Color(0xFF0284C7)
val StatusInfoSubtle = Color(0x1F0284C7)

// Accessible Typography Text Colors
val TextPrimaryLight = Color(0xFF0F172A)
val TextSecondaryLight = Color(0xFF475569)
val TextMutedLight = Color(0xFF818FA3)

val TextPrimaryDark = Color(0xFFF8FAFC)
val TextSecondaryDark = Color(0xFF94A3B8)
val TextMutedDark = Color(0xFF5E6D82)

@Immutable
data class SoftGlassColors(
    val isDark: Boolean,
    val background: Color,
    val backgroundSecondary: Color,
    val surface: Color,
    val surfaceElevated: Color,
    val surfacePressed: Color,
    val surfaceWell: Color,
    val panelTranslucent: Color,
    val navSurface: Color = surfaceElevated,
    val border: Color,
    val borderSubtle: Color,
    val borderGradient: Brush,
    val textPrimary: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val accentCyan: Color,
    val accentBlue: Color,
    val accentViolet: Color,
    val accentAmber: Color = AccentAmber,
    val accentAmberSubtle: Color = AccentAmberSubtle,
    val accentPrimaryColor: Color = accentBlue,
    val accentGradient: Brush,
    val shadow: Color,
    val specularHighlight: Color,
    val statusSuccess: Color,
    val statusSuccessSubtle: Color,
    val statusWarning: Color,
    val statusWarningSubtle: Color,
    val statusError: Color,
    val statusErrorSubtle: Color,
    val statusInfo: Color,
    val statusInfoSubtle: Color
) {
    val surfaceCard: Color get() = surfaceElevated
    val accentActive: Color get() = accentPrimaryColor
    val accentPrimary: Color get() = accentPrimaryColor
    val success: Color get() = statusSuccess
    val error: Color get() = statusError
}
