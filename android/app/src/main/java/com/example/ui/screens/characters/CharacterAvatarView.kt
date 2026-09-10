package com.example.ui.screens.characters

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.AvatarDisplayMode
import com.example.domain.model.AvatarStyle
import com.example.ui.theme.SoftTheme

@Composable
fun CharacterAvatarView(
    avatarStyle: AvatarStyle,
    displayMode: AvatarDisplayMode,
    size: Dp = 56.dp,
    isActive: Boolean = false,
    isAuditioning: Boolean = false,
    modifier: Modifier = Modifier
) {
    val primaryColor = Color(avatarStyle.primaryColorHex)
    val secondaryColor = Color(avatarStyle.secondaryColorHex)
    val accentColor = Color(avatarStyle.accentColorHex)

    val infiniteTransition = rememberInfiniteTransition(label = "pulse_avatar")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = if (isAuditioning) 1.08f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "avatar_scale"
    )

    when (displayMode) {
        AvatarDisplayMode.HIDDEN -> {
            // Text-only mode, minimalistic glyph token
            Box(
                modifier = modifier
                    .size(size)
                    .clip(RoundedCornerShape(size / 4))
                    .background(SoftTheme.colors.surfaceCard)
                    .border(1.dp, SoftTheme.colors.borderSubtle, RoundedCornerShape(size / 4))
                    .testTag("avatar_display_hidden"),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.VisibilityOff,
                        contentDescription = "Hidden Avatar",
                        tint = SoftTheme.colors.textSecondary,
                        modifier = Modifier.size(size * 0.4f)
                    )
                    if (size >= 56.dp) {
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = "Hidden",
                            style = SoftTheme.typography.caption.copy(fontSize = 9.sp),
                            color = SoftTheme.colors.textSecondary
                        )
                    }
                }
            }
        }

        AvatarDisplayMode.VOICE_MODE_ONLY -> {
            // Voice mode dedicated token
            Box(
                modifier = modifier
                    .size(size)
                    .clip(CircleShape)
                    .background(
                        Brush.radialGradient(
                            colors = listOf(
                                primaryColor.copy(alpha = 0.25f),
                                SoftTheme.colors.surfaceCard
                            )
                        )
                    )
                    .border(
                        width = if (isActive) 2.dp else 1.dp,
                        color = if (isActive) primaryColor else SoftTheme.colors.borderSubtle,
                        shape = CircleShape
                    )
                    .testTag("avatar_display_voice_only"),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Mic,
                    contentDescription = "Voice Mode Only Avatar",
                    tint = if (isActive) primaryColor else SoftTheme.colors.textSecondary,
                    modifier = Modifier.size(size * 0.45f)
                )
            }
        }

        AvatarDisplayMode.COMPACT -> {
            // Sleek circular badge
            Box(
                modifier = modifier
                    .size(size)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(primaryColor, secondaryColor)
                        )
                    )
                    .border(
                        width = if (isActive) 2.dp else 1.dp,
                        color = if (isActive) SoftTheme.colors.accentActive else SoftTheme.colors.borderSubtle,
                        shape = CircleShape
                    )
                    .testTag("avatar_display_compact"),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = avatarStyle.glyphSymbol,
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = (size.value * 0.45f).sp
                )
            }
        }

        AvatarDisplayMode.FULL -> {
            // Rich multi-layered glowing avatar
            Box(
                modifier = modifier
                    .size(size)
                    .scale(pulseScale)
                    .testTag("avatar_display_full"),
                contentAlignment = Alignment.Center
            ) {
                // Outer ambient glow ring
                Box(
                    modifier = Modifier
                        .size(size)
                        .clip(RoundedCornerShape(size / 3))
                        .background(
                            Brush.radialGradient(
                                colors = listOf(
                                    primaryColor.copy(alpha = if (isActive) 0.35f else 0.15f),
                                    Color.Transparent
                                )
                            )
                        )
                )

                // Inner gradient core
                Box(
                    modifier = Modifier
                        .size(size * 0.85f)
                        .clip(RoundedCornerShape((size * 0.85f) / 3))
                        .background(
                            Brush.linearGradient(
                                colors = listOf(
                                    primaryColor,
                                    secondaryColor,
                                    accentColor
                                )
                            )
                        )
                        .border(
                            width = if (isActive) 2.dp else 1.dp,
                            color = if (isActive) Color.White.copy(alpha = 0.8f) else SoftTheme.colors.borderSubtle,
                            shape = RoundedCornerShape((size * 0.85f) / 3)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = avatarStyle.glyphSymbol,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = (size.value * 0.38f).sp
                    )
                }

                // Active status beacon badge
                if (isActive) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .size(size * 0.28f)
                            .clip(CircleShape)
                            .background(SoftTheme.colors.success)
                            .border(1.5.dp, SoftTheme.colors.surfaceCard, CircleShape)
                    )
                }
            }
        }
    }
}
