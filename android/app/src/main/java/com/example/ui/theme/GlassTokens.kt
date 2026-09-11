package com.example.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.domain.model.EffectsLevel

@Immutable
data class GlassCorners(
    val xs: Dp = 8.dp,
    val sm: Dp = 12.dp,
    val md: Dp = 18.dp,
    val lg: Dp = 24.dp,
    val xl: Dp = 32.dp,
    val pill: Dp = 999.dp
)

@Immutable
data class GlassElevations(
    val none: Dp = 0.dp,
    val flat: Dp = 1.dp,
    val subtle: Dp = 3.dp,
    val card: Dp = 8.dp,
    val elevated: Dp = 14.dp,
    val overlay: Dp = 24.dp
)

@Immutable
data class GlassAlphas(
    val frosted: Float = 0.72f,
    val structural: Float = 0.85f,
    val milky: Float = 0.94f,
    val navGlass: Float = 0.92f,
    val highlight: Float = 0.18f,
    val subtleHighlight: Float = 0.08f
)

@Immutable
data class GlassBorders(
    val hairline: Dp = 0.75.dp,
    val thin: Dp = 1.dp,
    val medium: Dp = 1.5.dp,
    val thick: Dp = 2.dp
)

@Immutable
data class GlassTokens(
    val corners: GlassCorners = GlassCorners(),
    val elevations: GlassElevations = GlassElevations(),
    val alphas: GlassAlphas = GlassAlphas(),
    val borders: GlassBorders = GlassBorders(),
    val effectsLevel: EffectsLevel = EffectsLevel.NORMAL
)
