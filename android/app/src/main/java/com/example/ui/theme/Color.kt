package com.example.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor

// Light Mode Foundations: Authentic Soft Clay Canvas + Tactile Off-White Wells (Banking Reference Parity)
val BackgroundPearl = Color(0xFFE6E9E5)          // Warm matte off-white clay canvas (KK Theme Parity)
val BackgroundPearlSubtle = Color(0xFFDFE2DE)    // Subtle clay canvas
val MilkySurfaceBase = Color(0xFFE2E5E0)         // Soft clay surface base (~95% opacity)
val MilkySurfaceElevated = Color(0xFFEDF0EB)     // Raised tactile clay card surface
val MilkySurfacePressed = Color(0xFFCDD2CA)      // Pressed tactile clay
val MilkySurfaceWell = Color(0xFFD6DAD3)         // Recessed sunken clay well
val TranslucentPanelLight = Color(0xECE2E5E0)    // Translucent clay panel
val NavSurfaceLight = Color(0xF2EDF0EB)          // Floating clay navigation surface
val BorderLight = Color(0x40FFFFFF)              // Soft specular edge (40% alpha)
val BorderSubtleLight = Color(0x1F000000)        // Subdued hairline clay edge (12% black alpha)
val ShadowLight = Color(0x38737A75)              // Physical soft slate clay shadow (22% alpha)
val ShadowLightSpecular = Color(0xB3FFFFFF)      // Crisp white specular drop shadow (70% alpha)

// Dark Mode Foundations: Stealth Matte Charcoal / Obsidian Graphite (Reference Image Parity)
val BackgroundCharcoal = Color(0xFF0E1015)
val BackgroundGraphite = Color(0xFF14161C)
val DarkSurfaceBase = Color(0xF0181A22)
val DarkSurfaceElevated = Color(0xF81F2229)          // Neutral matte dark charcoal (Raised Element)
val DarkSurfacePressed = Color(0xFF0F1115)
val DarkSurfaceWell = Color(0xFF121419)              // Recessed matte well (Sunken Element / Input Field)
val TranslucentPanelDark = Color(0xEB1A1D24)         // Matte glass panel
val NavSurfaceDark = Color(0xF2181B22)               // Floating navigation surface
val BorderDark = Color(0x14FFFFFF)                   // Restrained subtle hairline border (8% alpha)
val BorderSubtleDark = Color(0x0AFFFFFF)             // Subdued border (4% alpha)
val ShadowDark = Color(0xCC000000)                   // Deep soft ambient drop shadow
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
val TextSecondaryLight = Color(0xFF334155)
val TextMutedLight = Color(0xFF334155) // Slate-700 for high-contrast crisp readability on light clay

val TextPrimaryDark = Color(0xFFF8FAFC)
val TextSecondaryDark = Color(0xFFCBD5E1)
val TextMutedDark = Color(0xFF94A3B8) // Slate-400 so icons illuminate clearly against charcoal

// OLED Battery Saver Foundations: Pure Pitch Black (#000000) for AMOLED Subpixel Power-Off
val OledBackground = Color(0xFF000000)
val OledBackgroundSecondary = Color(0xFF000000)
val OledSurfaceBase = Color(0xFF050505)
val OledSurfaceElevated = Color(0xFF0A0A0A)
val OledSurfacePressed = Color(0xFF000000)
val OledSurfaceWell = Color(0xFF000000)
val TranslucentPanelOled = Color(0xCC050505)
val NavSurfaceOled = Color(0xFF000000)
val BorderOled = Color(0x33FFFFFF)       // Crisp luminous hairline border (20% white)
val BorderSubtleOled = Color(0x1AFFFFFF) // Subdued luminous hairline (10% white)
val ShadowOled = Color(0x00000000)       // Zero elevation drop-shadows on OLED black
val ShadowOledSpecular = Color(0x00000000)
val TextPrimaryOled = Color(0xFFFFFFFF)
val TextSecondaryOled = Color(0xFFCBD5E1)
val TextMutedOled = Color(0xFF94A3B8)
val AccentBlueOled = Color(0xFF38BDF8)   // Vibrant glowing azure
val AccentBlueOledSubtle = Color(0x2638BDF8)


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
