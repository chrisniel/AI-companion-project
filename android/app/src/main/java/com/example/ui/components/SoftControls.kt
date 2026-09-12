package com.example.ui.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
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
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Reusable SoftGlass Toggle Switch.
 * Features smooth animated thumb translation, subtle tactile glow when active,
 * clear on/off contrast, and accessible switch semantics.
 */
@Composable
fun SoftToggle(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    contentDescription: String = "Toggle switch",
    testTag: String = "soft_toggle"
) {
    val interactionSource = remember { MutableInteractionSource() }

    val trackWidth = 56.dp
    val trackHeight = 34.dp
    val thumbSize = 26.dp
    val padding = 4.dp

    val thumbOffset by animateDpAsState(
        targetValue = if (checked) trackWidth - thumbSize - padding else padding,
        label = "toggle_thumb_offset"
    )

    val trackBrush = when {
        !enabled -> Brush.horizontalGradient(
            listOf(
                SoftTheme.colors.surfacePressed,
                SoftTheme.colors.surfacePressed
            )
        )
        checked -> SoftTheme.colors.accentGradient
        else -> Brush.horizontalGradient(
            listOf(
                SoftTheme.colors.surfacePressed,
                SoftTheme.colors.surface
            )
        )
    }

    val thumbColor = when {
        !enabled -> SoftTheme.colors.textMuted
        checked -> Color.White
        else -> SoftTheme.colors.surfaceElevated
    }

    val borderBrush = when {
        checked -> SoftTheme.colors.accentGradient
        else -> SoftTheme.colors.borderGradient
    }

    Box(
        modifier = modifier
            .testTag(testTag)
            .minimumInteractiveComponentSize()
            .size(width = trackWidth, height = trackHeight)
            .semantics {
                this.contentDescription = contentDescription
            }
            .shadow(
                elevation = if (checked) SoftTheme.tokens.elevations.subtle else SoftTheme.tokens.elevations.none,
                shape = CircleShape,
                ambientColor = SoftTheme.colors.accentBlue.copy(alpha = 0.3f),
                spotColor = SoftTheme.colors.accentCyan.copy(alpha = 0.2f)
            )
            .clip(CircleShape)
            .background(trackBrush, CircleShape)
            .border(width = SoftTheme.tokens.borders.hairline, brush = borderBrush, shape = CircleShape)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                role = Role.Switch,
                onClick = { onCheckedChange(!checked) }
            ),
        contentAlignment = Alignment.CenterStart
    ) {
        Box(
            modifier = Modifier
                .offset(x = thumbOffset)
                .size(thumbSize)
                .shadow(
                    elevation = SoftTheme.tokens.elevations.subtle,
                    shape = CircleShape,
                    ambientColor = SoftTheme.colors.shadow,
                    spotColor = SoftTheme.colors.shadow
                )
                .clip(CircleShape)
                .background(thumbColor, CircleShape)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = if (checked) Color.White.copy(alpha = 0.8f) else SoftTheme.colors.borderSubtle,
                    shape = CircleShape
                )
        )
    }
}

/**
 * Reusable SoftGlass Slider with tactile thumb, soft glass track, and value readout.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SoftSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    valueRange: ClosedFloatingPointRange<Float> = 0f..1f,
    title: String? = null,
    valueLabel: String? = null,
    testTag: String = "soft_slider"
) {
    Column(
        modifier = modifier
            .testTag(testTag)
            .fillMaxWidth()
    ) {
        if (title != null || valueLabel != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = SoftTheme.spacing.xs),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (title != null) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.labelMedium,
                        color = SoftTheme.colors.textSecondary
                    )
                }
                if (valueLabel != null) {
                    Text(
                        text = valueLabel,
                        style = MonospaceTelemetry,
                        color = SoftTheme.colors.accentBlue
                    )
                }
            }
        }

        Slider(
            value = value,
            onValueChange = onValueChange,
            enabled = enabled,
            valueRange = valueRange,
            colors = SliderDefaults.colors(
                thumbColor = Color.White,
                activeTrackColor = SoftTheme.colors.accentBlue,
                inactiveTrackColor = SoftTheme.colors.surfacePressed,
                disabledThumbColor = SoftTheme.colors.textMuted,
                disabledActiveTrackColor = SoftTheme.colors.textMuted.copy(alpha = 0.3f),
                disabledInactiveTrackColor = SoftTheme.colors.surfacePressed.copy(alpha = 0.5f)
            ),
            thumb = {
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .shadow(
                            elevation = SoftTheme.tokens.elevations.card,
                            shape = CircleShape,
                            ambientColor = SoftTheme.colors.accentBlue.copy(alpha = 0.35f),
                            spotColor = SoftTheme.colors.accentCyan.copy(alpha = 0.3f)
                        )
                        .clip(CircleShape)
                        .background(Color.White, CircleShape)
                        .border(
                            width = 2.dp,
                            color = if (enabled) SoftTheme.colors.accentBlue else SoftTheme.colors.textMuted,
                            shape = CircleShape
                        )
                )
            },
            modifier = Modifier.fillMaxWidth()
        )
    }
}

/**
 * SegmentedControl: Tactile soft glass pill container with sliding animated selection pill.
 * Used for language switching (Auto / US EN / PH FIL / JP JA / Mixed) or view mode selection.
 */
@Composable
fun <T> SoftSegmentedControl(
    items: List<T>,
    selectedItem: T,
    onItemSelected: (T) -> Unit,
    modifier: Modifier = Modifier,
    itemLabel: (T) -> String = { it.toString() },
    enabled: Boolean = true,
    testTag: String = "soft_segmented_control"
) {
    val selectedIndex = items.indexOf(selectedItem).coerceAtLeast(0)

    BoxWithConstraints(
        modifier = modifier
            .testTag(testTag)
            .height(48.dp)
            .shadow(
                elevation = SoftTheme.tokens.elevations.subtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                ambientColor = SoftTheme.colors.shadow,
                spotColor = SoftTheme.colors.shadow
            )
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(SoftTheme.colors.surfacePressed, RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .border(
                width = SoftTheme.tokens.borders.hairline,
                brush = SoftTheme.colors.borderGradient,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(4.dp)
    ) {
        val totalItems = items.size.coerceAtLeast(1)
        val segmentWidth = maxWidth / totalItems

        val animatedOffset by animateDpAsState(
            targetValue = segmentWidth * selectedIndex,
            label = "segment_pill_offset"
        )

        // Sliding selected pill
        Box(
            modifier = Modifier
                .offset(x = animatedOffset)
                .width(segmentWidth)
                .fillMaxHeight()
                .shadow(
                    elevation = SoftTheme.tokens.elevations.card,
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                    ambientColor = SoftTheme.colors.accentBlue.copy(alpha = 0.35f),
                    spotColor = SoftTheme.colors.accentCyan.copy(alpha = 0.25f)
                )
                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                .background(SoftTheme.colors.accentGradient, RoundedCornerShape(SoftTheme.tokens.corners.pill))
        )

        // Item Labels Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            items.forEachIndexed { index, item ->
                val isSelected = index == selectedIndex
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = ripple(color = Color.White.copy(alpha = 0.2f)),
                            enabled = enabled,
                            role = Role.Tab,
                            onClick = { onItemSelected(item) }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = itemLabel(item),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                        color = when {
                            !enabled -> SoftTheme.colors.textMuted
                            isSelected -> if (SoftTheme.colors.isDark) Color(0xFF070B14) else Color.White
                            else -> SoftTheme.colors.textSecondary
                        }
                    )
                }
            }
        }
    }
}

/**
 * Toggle alias for SoftToggle.
 */
@Composable
fun Toggle(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    contentDescription: String = "Toggle switch",
    testTag: String = "toggle"
) {
    SoftToggle(
        checked = checked,
        onCheckedChange = onCheckedChange,
        modifier = modifier,
        enabled = enabled,
        contentDescription = contentDescription,
        testTag = testTag
    )
}

/**
 * SegmentedControl alias for SoftSegmentedControl.
 */
@Composable
fun <T> SegmentedControl(
    items: List<T>,
    selectedItem: T,
    onItemSelected: (T) -> Unit,
    modifier: Modifier = Modifier,
    itemLabel: (T) -> String = { it.toString() },
    enabled: Boolean = true,
    testTag: String = "segmented_control"
) {
    SoftSegmentedControl(
        items = items,
        selectedItem = selectedItem,
        onItemSelected = onItemSelected,
        modifier = modifier,
        itemLabel = itemLabel,
        enabled = enabled,
        testTag = testTag
    )
}

