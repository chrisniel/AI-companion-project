package com.example.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.ui.text.style.TextOverflow
import com.example.ui.components.NavigationGlassSurface
import com.example.ui.theme.SoftTheme

/**
 * Mobile-first Bottom Navigation Bar for the 5 primary destinations:
 * Home, Assistant, Tasks, Health, More.
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

@Composable
private fun BottomNavItemView(
    item: BottomNavItem,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }

    val iconColor by animateColorAsState(
        targetValue = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textMuted,
        animationSpec = tween(durationMillis = 200),
        label = "nav_icon_color"
    )

    val textColor by animateColorAsState(
        targetValue = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textMuted,
        animationSpec = tween(durationMillis = 200),
        label = "nav_text_color"
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
                indication = ripple(bounded = true, color = SoftTheme.colors.accentBlue),
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
            // Selected indicator pill: not relying solely on shadow; includes distinct tinted background & border
            Box(
                modifier = Modifier
                    .then(
                        if (isSelected) {
                            Modifier
                                .shadow(
                                    elevation = SoftTheme.tokens.elevations.subtle,
                                    shape = pillShape,
                                    ambientColor = SoftTheme.colors.shadow,
                                    spotColor = SoftTheme.colors.shadow
                                )
                                .clip(pillShape)
                                .background(
                                    if (SoftTheme.colors.isDark) {
                                        SoftTheme.colors.accentBlue.copy(alpha = 0.22f)
                                    } else {
                                        SoftTheme.colors.accentBlue.copy(alpha = 0.12f)
                                    },
                                    pillShape
                                )
                                .border(
                                    width = 1.dp,
                                    brush = if (SoftTheme.colors.isDark) {
                                        Brush.verticalGradient(
                                            listOf(
                                                Color.White.copy(alpha = 0.35f),
                                                SoftTheme.colors.accentBlue.copy(alpha = 0.55f)
                                            )
                                        )
                                    } else {
                                        SoftTheme.colors.borderGradient
                                    },
                                    shape = pillShape
                                )
                        } else {
                            Modifier
                                .clip(pillShape)
                                .background(Color.Transparent)
                        }
                    )
                    .padding(horizontal = 12.dp, vertical = 4.dp),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = item.icon,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(22.dp)
                )
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
