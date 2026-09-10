package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.example.ui.theme.SoftTheme

/**
 * BottomSheet foundation: Reusable SoftGlass ModalBottomSheet.
 * Features frosted milky/graphite container, tactile drag handle, soft border,
 * and high-contrast content slots.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SoftGlassBottomSheet(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    sheetState: SheetState = rememberModalBottomSheetState(),
    title: String? = null,
    testTag: String = "soft_glass_bottom_sheet",
    content: @Composable () -> Unit
) {
    val topCorners = RoundedCornerShape(
        topStart = SoftTheme.tokens.corners.xl,
        topEnd = SoftTheme.tokens.corners.xl
    )

    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.surfaceElevated,
        contentColor = SoftTheme.colors.textPrimary,
        shape = topCorners,
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(vertical = SoftTheme.spacing.md)
                    .size(width = 40.dp, height = 4.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.borderSubtle)
            )
        },
        modifier = modifier.testTag(testTag)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.xl)
                .padding(bottom = SoftTheme.spacing.xxxl)
        ) {
            if (title != null) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    color = SoftTheme.colors.textPrimary,
                    modifier = Modifier.padding(bottom = SoftTheme.spacing.lg)
                )
            }
            content()
        }
    }
}

/**
 * Dialog foundation: Reusable SoftGlass Modal Dialog.
 * Provides soft glass container, dual highlight borders, title, description,
 * and action button slots with accessible touch targets.
 */
@Composable
fun SoftGlassDialog(
    onDismissRequest: () -> Unit,
    title: String,
    modifier: Modifier = Modifier,
    description: String? = null,
    confirmButtonText: String = "Confirm",
    onConfirm: () -> Unit,
    dismissButtonText: String? = "Cancel",
    onDismiss: (() -> Unit)? = null,
    testTag: String = "soft_glass_dialog",
    content: (@Composable () -> Unit)? = null
) {
    val shape = RoundedCornerShape(SoftTheme.tokens.corners.xl)

    Dialog(
        onDismissRequest = onDismissRequest,
        properties = DialogProperties(usePlatformDefaultWidth = true)
    ) {
        Box(
            modifier = modifier
                .testTag(testTag)
                .shadow(
                    elevation = SoftTheme.tokens.elevations.overlay,
                    shape = shape,
                    ambientColor = SoftTheme.colors.shadow,
                    spotColor = SoftTheme.colors.shadow
                )
                .clip(shape)
                .background(SoftTheme.colors.surfaceElevated, shape)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    brush = SoftTheme.colors.borderGradient,
                    shape = shape
                )
                .padding(SoftTheme.spacing.xxl)
        ) {
            Column(
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    color = SoftTheme.colors.textPrimary
                )

                if (description != null) {
                    Spacer(modifier = Modifier.height(SoftTheme.spacing.sm))
                    Text(
                        text = description,
                        style = MaterialTheme.typography.bodyMedium,
                        color = SoftTheme.colors.textSecondary
                    )
                }

                if (content != null) {
                    Spacer(modifier = Modifier.height(SoftTheme.spacing.md))
                    content()
                }

                Spacer(modifier = Modifier.height(SoftTheme.spacing.xl))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (dismissButtonText != null) {
                        SecondaryButton(
                            text = dismissButtonText,
                            onClick = {
                                onDismiss?.invoke()
                                onDismissRequest()
                            },
                            modifier = Modifier.padding(end = SoftTheme.spacing.sm)
                        )
                    }

                    PrimaryButton(
                        text = confirmButtonText,
                        onClick = onConfirm
                    )
                }
            }
        }
    }
}

/**
 * BottomSheet foundation alias.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BottomSheetFoundation(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    sheetState: SheetState = rememberModalBottomSheetState(),
    title: String? = null,
    testTag: String = "bottom_sheet_foundation",
    content: @Composable () -> Unit
) {
    SoftGlassBottomSheet(
        onDismissRequest = onDismissRequest,
        modifier = modifier,
        sheetState = sheetState,
        title = title,
        testTag = testTag,
        content = content
    )
}

/**
 * Dialog foundation alias.
 */
@Composable
fun DialogFoundation(
    onDismissRequest: () -> Unit,
    title: String,
    modifier: Modifier = Modifier,
    description: String? = null,
    confirmButtonText: String = "Confirm",
    onConfirm: () -> Unit,
    dismissButtonText: String? = "Cancel",
    onDismiss: (() -> Unit)? = null,
    testTag: String = "dialog_foundation",
    content: (@Composable () -> Unit)? = null
) {
    SoftGlassDialog(
        onDismissRequest = onDismissRequest,
        title = title,
        modifier = modifier,
        description = description,
        confirmButtonText = confirmButtonText,
        onConfirm = onConfirm,
        dismissButtonText = dismissButtonText,
        onDismiss = onDismiss,
        testTag = testTag,
        content = content
    )
}

