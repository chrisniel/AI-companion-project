package com.example.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.minimumInteractiveComponentSize
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.example.ui.theme.SoftTheme

/**
 * Reusable SoftGlass TextField.
 * Supports normal, focused, error, and disabled states with tactile glass styling,
 * label, helper text, and leading/trailing icon slots.
 */
@Composable
fun SoftTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    helperText: String? = null,
    errorMessage: String? = null,
    isError: Boolean = errorMessage != null,
    enabled: Boolean = true,
    leadingIcon: ImageVector? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    singleLine: Boolean = true,
    testTag: String = "soft_text_field"
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()

    val shape = RoundedCornerShape(SoftTheme.tokens.corners.md)

    val borderBrush = when {
        isError -> Brush.horizontalGradient(listOf(SoftTheme.colors.statusError, SoftTheme.colors.statusError))
        isFocused -> SoftTheme.colors.accentGradient
        !enabled -> Brush.horizontalGradient(listOf(SoftTheme.colors.borderSubtle, SoftTheme.colors.borderSubtle))
        else -> SoftTheme.colors.borderGradient
    }

    val borderWidth = if (isFocused || isError) SoftTheme.tokens.borders.medium else SoftTheme.tokens.borders.thin

    val backgroundColor = when {
        !enabled -> SoftTheme.colors.surfacePressed.copy(alpha = 0.5f)
        isFocused -> SoftTheme.colors.surfaceElevated
        else -> SoftTheme.colors.surface
    }

    Column(modifier = modifier.fillMaxWidth()) {
        if (label != null) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = if (isError) SoftTheme.colors.statusError else SoftTheme.colors.textSecondary,
                modifier = Modifier.padding(bottom = SoftTheme.spacing.xs, start = SoftTheme.spacing.xs)
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = 48.dp)
                .testTag(testTag)
                .shadow(
                    elevation = if (isFocused) SoftTheme.tokens.elevations.subtle else SoftTheme.tokens.elevations.none,
                    shape = shape,
                    ambientColor = if (isFocused) SoftTheme.colors.accentBlue.copy(alpha = 0.2f) else SoftTheme.colors.shadow,
                    spotColor = if (isFocused) SoftTheme.colors.accentCyan.copy(alpha = 0.15f) else SoftTheme.colors.shadow
                )
                .clip(shape)
                .background(backgroundColor, shape)
                .border(width = borderWidth, brush = borderBrush, shape = shape)
                .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.md),
            contentAlignment = Alignment.CenterStart
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (leadingIcon != null) {
                    Icon(
                        imageVector = leadingIcon,
                        contentDescription = null,
                        tint = when {
                            isError -> SoftTheme.colors.statusError
                            isFocused -> SoftTheme.colors.accentBlue
                            else -> SoftTheme.colors.textMuted
                        },
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.md))
                }

                Box(modifier = Modifier.weight(1f)) {
                    if (value.isEmpty() && placeholder != null) {
                        Text(
                            text = placeholder,
                            style = MaterialTheme.typography.bodyMedium,
                            color = SoftTheme.colors.textMuted
                        )
                    }

                    BasicTextField(
                        value = value,
                        onValueChange = onValueChange,
                        enabled = enabled,
                        singleLine = singleLine,
                        textStyle = MaterialTheme.typography.bodyMedium.copy(
                            color = if (enabled) SoftTheme.colors.textPrimary else SoftTheme.colors.textMuted
                        ),
                        cursorBrush = SolidColor(SoftTheme.colors.accentBlue),
                        interactionSource = interactionSource,
                        keyboardOptions = keyboardOptions,
                        keyboardActions = keyboardActions,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                if (trailingIcon != null) {
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.sm))
                    trailingIcon()
                }
            }
        }

        // Helper / Error text
        if (errorMessage != null) {
            Text(
                text = errorMessage,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.statusError,
                modifier = Modifier.padding(top = SoftTheme.spacing.xs, start = SoftTheme.spacing.xs)
            )
        } else if (helperText != null) {
            Text(
                text = helperText,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textMuted,
                modifier = Modifier.padding(top = SoftTheme.spacing.xs, start = SoftTheme.spacing.xs)
            )
        }
    }
}

/**
 * Reusable SoftGlass SearchField.
 * Pill container with search glyph, placeholder, clear button, and accessible touch target.
 */
@Composable
fun SoftSearchField(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "Search commands, models, tasks...",
    onSearch: (() -> Unit)? = null,
    testTag: String = "soft_search_field"
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)

    val borderBrush = if (isFocused) SoftTheme.colors.accentGradient else SoftTheme.colors.borderGradient
    val borderWidth = if (isFocused) SoftTheme.tokens.borders.medium else SoftTheme.tokens.borders.hairline

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp)
            .testTag(testTag)
            .shadow(
                elevation = if (isFocused) SoftTheme.tokens.elevations.subtle else SoftTheme.tokens.elevations.none,
                shape = shape,
                ambientColor = SoftTheme.colors.accentBlue.copy(alpha = 0.2f),
                spotColor = SoftTheme.colors.accentCyan.copy(alpha = 0.15f)
            )
            .clip(shape)
            .background(if (isFocused) SoftTheme.colors.surfaceElevated else SoftTheme.colors.surface, shape)
            .border(width = borderWidth, brush = borderBrush, shape = shape)
            .padding(horizontal = SoftTheme.spacing.lg),
        contentAlignment = Alignment.CenterStart
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = "Search",
                tint = if (isFocused) SoftTheme.colors.accentBlue else SoftTheme.colors.textMuted,
                modifier = Modifier.size(20.dp)
            )

            Spacer(modifier = Modifier.width(SoftTheme.spacing.md))

            Box(modifier = Modifier.weight(1f)) {
                if (query.isEmpty()) {
                    Text(
                        text = placeholder,
                        style = MaterialTheme.typography.bodyMedium,
                        color = SoftTheme.colors.textMuted
                    )
                }

                BasicTextField(
                    value = query,
                    onValueChange = onQueryChange,
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodyMedium.copy(color = SoftTheme.colors.textPrimary),
                    cursorBrush = SolidColor(SoftTheme.colors.accentBlue),
                    interactionSource = interactionSource,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { onSearch?.invoke() }),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            AnimatedVisibility(
                visible = query.isNotEmpty(),
                enter = fadeIn(),
                exit = fadeOut()
            ) {
                IconButton(
                    onClick = { onQueryChange("") },
                    modifier = Modifier
                        .size(32.dp)
                        .minimumInteractiveComponentSize()
                ) {
                    Icon(
                        imageVector = Icons.Default.Clear,
                        contentDescription = "Clear search",
                        tint = SoftTheme.colors.textMuted,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}

/**
 * SearchField alias for SoftSearchField.
 */
@Composable
fun SearchField(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "Search commands, models, tasks...",
    onSearch: (() -> Unit)? = null,
    testTag: String = "search_field"
) {
    SoftSearchField(
        query = query,
        onQueryChange = onQueryChange,
        modifier = modifier,
        placeholder = placeholder,
        onSearch = onSearch,
        testTag = testTag
    )
}

