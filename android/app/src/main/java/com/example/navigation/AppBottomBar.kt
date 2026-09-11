package com.example.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.components.NavigationGlassSurface
import com.example.ui.components.softNeumorphicRaised
import com.example.ui.theme.SoftTheme

/**
 * Mobile-first Bottom Navigation Bar for the 5 primary destinations:
 * Home (1), Tasks (2), Assistant (3 - Center Action), Health (4), More (5).
 * Built using the calibrated Soft Glass design system.
 * Audited for compact/normal/large phones and large font scaling.
 */
@Composable
fun AppBottomBar(
    currentRoute: String?,
    onNavigateToDestination: (BottomNavItem) -> Unit,
    modifier: Modifier = Modifier
) {
    NavigationGlassSurface(
        modifier = modifier
            .fillMaxWidth()
            .testTag("app_bottom_bar")
            .navigationBarsPadding(),
        elevation = SoftTheme.tokens.elevations.card
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = 64.dp)
                .padding(horizontal = SoftTheme.spacing.xs, vertical = 6.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically
        ) {
            BottomNavItem.items.forEach { item ->
                val isSelected = currentRoute == item.route

                if (item == BottomNavItem.Assistant) {
                    CenterAssistantNavItemView(
                        item = item,
                        isSelected = isSelected,
                        onClick = { onNavigateToDestination(item) },
                        modifier = Modifier.weight(1.1f)
                    )
                } else {
                    BottomNavItemView(
                        item = item,
                        isSelected = isSelected,
                        onClick = { onNavigateToDestination(item) },
                        modifier = Modifier
                            .weight(1f)
                            .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                    )
                }
            }
        }
    }
}

/**
 * Center emphasized Assistant action button:
 * Prominent elevated circular soft-glass button, larger icon, label-free,
 * floating above the bar edge without clipping insets.
 */
@Composable
private fun CenterAssistantNavItemView(
    item: BottomNavItem,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }

    val iconColor by animateColorAsState(
        targetValue = if (isSelected) Color.White else SoftTheme.colors.accentPrimaryColor,
        animationSpec = tween(durationMillis = 120),
        label = "assistant_icon_color"
    )

    val surfaceColor by animateColorAsState(
        targetValue = if (isSelected) {
            SoftTheme.colors.accentPrimaryColor
        } else {
            SoftTheme.colors.surfaceElevated
        },
        animationSpec = tween(durationMillis = 120),
        label = "assistant_surface_color"
    )

    val elevation by animateDpAsState(
        targetValue = if (isSelected) 8.dp else 4.dp,
        animationSpec = tween(durationMillis = 120),
        label = "assistant_elevation"
    )

    Box(
        modifier = modifier
            .testTag(item.testTag)
            .semantics {
                this.selected = isSelected
                this.contentDescription = "${item.title} tab, ${if (isSelected) "selected" else "not selected"}"
            }
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(bounded = false, radius = 28.dp, color = SoftTheme.colors.accentCyan),
                role = Role.Tab,
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .offset(y = (-6).dp)
                .size(52.dp)
                .shadow(
                    elevation = elevation,
                    shape = CircleShape,
                    ambientColor = SoftTheme.colors.shadow,
                    spotColor = if (isSelected) SoftTheme.colors.accentPrimaryColor.copy(alpha = 0.25f) else SoftTheme.colors.shadow
                )
                .softNeumorphicRaised(
                    shape = CircleShape,
                    isDark = SoftTheme.colors.isDark,
                    elevation = elevation,
                    highlightAlpha = if (isSelected) 0.12f else (if (SoftTheme.colors.isDark) 0.10f else 0.60f)
                )
                .clip(CircleShape)
                .background(surfaceColor, CircleShape)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    brush = if (SoftTheme.colors.isDark) {
                        SolidColor(Color.White.copy(alpha = 0.15f))
                    } else {
                        SolidColor(Color.White.copy(alpha = 0.70f))
                    },
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = item.icon,
                contentDescription = null,
                tint = iconColor,
                modifier = Modifier.size(26.dp)
            )
        }
    }
}

@Composable
private fun BottomNavItemView(
    item: BottomNavItem,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }

    val iconColor by animateColorAsState(
        targetValue = if (isSelected) SoftTheme.colors.accentPrimaryColor else SoftTheme.colors.textMuted,
        animationSpec = tween(durationMillis = 120),
        label = "nav_icon_color"
    )

    val textColor by animateColorAsState(
        targetValue = if (isSelected) SoftTheme.colors.accentPrimaryColor else SoftTheme.colors.textMuted,
        animationSpec = tween(durationMillis = 120),
        label = "nav_text_color"
    )

    val pillAlpha by animateFloatAsState(
        targetValue = if (isSelected) 1f else 0f,
        animationSpec = tween(durationMillis = 120),
        label = "nav_pill_alpha"
    )

    val pillShape = RoundedCornerShape(SoftTheme.tokens.corners.pill)

    Box(
        modifier = modifier
            .testTag(item.testTag)
            .semantics {
                this.selected = isSelected
                this.contentDescription = "${item.title} tab, ${if (isSelected) "selected" else "not selected"}"
            }
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .clickable(
                interactionSource = interactionSource,
                indication = ripple(bounded = true, color = SoftTheme.colors.accentPrimaryColor),
                role = Role.Tab,
                onClick = onClick
            )
            .padding(vertical = 2.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            // Selected indicator pill: smooth alpha fade without layout popping
            Box(
                contentAlignment = Alignment.Center
            ) {
                // Animated indicator background (web client --neu-nav-embossed parity)
                if (pillAlpha > 0f) {
                    val indicatorBg = if (SoftTheme.colors.isDark) {
                        SoftTheme.colors.surfaceElevated
                    } else {
                        Color.White
                    }
                    val indicatorBorder = if (SoftTheme.colors.isDark) {
                        SolidColor(Color.White.copy(alpha = 0.12f))
                    } else {
                        SolidColor(Color(0x388298B3).copy(alpha = 0.35f))
                    }

                    Box(
                        modifier = Modifier
                            .graphicsLayer { alpha = pillAlpha }
                            .shadow(
                                elevation = if (isSelected) 2.dp else 0.dp,
                                shape = pillShape,
                                ambientColor = SoftTheme.colors.shadow,
                                spotColor = SoftTheme.colors.shadow
                            )
                            .softNeumorphicRaised(
                                shape = pillShape,
                                isDark = SoftTheme.colors.isDark,
                                elevation = 2.dp,
                                highlightAlpha = if (SoftTheme.colors.isDark) 0.08f else 0.65f
                            )
                            .clip(pillShape)
                            .background(indicatorBg, pillShape)
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                brush = indicatorBorder,
                                shape = pillShape
                            )
                            .matchParentSize()
                    )
                }

                Box(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = item.icon,
                        contentDescription = null,
                        tint = iconColor,
                        modifier = Modifier.size(22.dp)
                    )
                }
            }

            Text(
                text = item.title,
                fontSize = 11.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                color = textColor,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
