package com.example.ui.screens.tasks

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.BusinessCenter
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Snooze
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.MobileTask
import com.example.domain.model.TaskCategory
import com.example.domain.model.TaskPriority
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.softNeumorphicInset
import com.example.ui.theme.SoftTheme

/**
 * Task Row component displaying:
 * - completion control (accessible checkbox target)
 * - title (with multilingual support & strikethrough when completed)
 * - project/category pill badge with icon
 * - priority flag indicator
 * - due date/time indicator
 * - Quick Actions: complete, edit, delete, snooze/remind later
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TaskRowItem(
    task: MobileTask,
    onToggleComplete: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onSnooze: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isMenuExpanded by remember { mutableStateOf(false) }

    val priorityColor = when (task.priority) {
        TaskPriority.LOW -> SoftTheme.colors.textMuted
        TaskPriority.MEDIUM -> SoftTheme.colors.accentBlue
        TaskPriority.HIGH -> SoftTheme.colors.statusWarning
        TaskPriority.URGENT -> SoftTheme.colors.statusError
    }

    val categoryIcon = getCategoryIcon(task.category)

    val cardBackground by animateColorAsState(
        targetValue = if (task.isCompleted) {
            SoftTheme.colors.surfaceWell.copy(alpha = 0.60f)
        } else {
            SoftTheme.colors.surfaceElevated
        },
        label = "cardBg"
    )

    val contentAlpha by animateFloatAsState(
        targetValue = if (task.isCompleted) 0.60f else 1.0f,
        label = "contentAlpha"
    )

    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("task_item_${task.id}")
            .clickable(onClick = onEdit),
        elevation = if (task.isCompleted) SoftTheme.tokens.elevations.flat else SoftTheme.tokens.elevations.card,
        containerColor = cardBackground,
        shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
        border = BorderStroke(
            SoftTheme.tokens.borders.hairline,
            if (task.isCompleted) SoftTheme.colors.borderSubtle.copy(alpha = 0.5f) else SoftTheme.colors.borderSubtle
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (task.isCompleted) {
                        Modifier.softNeumorphicInset(
                            shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
                            isDark = SoftTheme.colors.isDark,
                            depth = 2.dp
                        )
                    } else Modifier
                )
                .padding(14.dp),
            verticalAlignment = Alignment.Top
        ) {
            // 1. COMPLETION CONTROL (Touch target 48dp friendly)
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onToggleComplete)
                    .testTag("task_complete_button_${task.id}")
                    .semantics {
                        contentDescription = if (task.isCompleted) "Mark task incomplete" else "Mark task complete"
                    },
                contentAlignment = Alignment.Center
            ) {
                if (task.isCompleted) {
                    Box(
                        modifier = Modifier
                            .size(26.dp)
                            .clip(CircleShape)
                            .background(SoftTheme.colors.statusSuccess),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                } else {
                    Box(
                        modifier = Modifier
                            .size(26.dp)
                            .clip(CircleShape)
                            .border(
                                width = 2.dp,
                                color = priorityColor.copy(alpha = 0.8f),
                                shape = CircleShape
                            )
                    )
                }
            }

            Spacer(modifier = Modifier.width(10.dp))

            // 2. MAIN CONTENT (Title, Project/Category, Priority, Due Date/Time)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(top = 2.dp)
            ) {
                // Title (Multilingual text support, e.g. "Check backend bukas", "Android UIを確認")
                Text(
                    text = task.title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = if (task.isCompleted) SoftTheme.colors.textMuted else SoftTheme.colors.textPrimary,
                    textDecoration = if (task.isCompleted) TextDecoration.LineThrough else TextDecoration.None,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    lineHeight = 20.sp,
                    modifier = Modifier.testTag("task_title_${task.id}")
                )

                if (task.description.isNotBlank()) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = task.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary.copy(alpha = contentAlpha),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 12.sp,
                        lineHeight = 16.sp
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                // METADATA CHIPS: Category/Project, Priority, Due Date/Time, Reminder
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    // Category / Project Pill
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.surfaceWell)
                            .padding(horizontal = 7.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = categoryIcon,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentCyan,
                            modifier = Modifier.size(11.dp)
                        )
                        Text(
                            text = task.category.label,
                            style = MaterialTheme.typography.labelSmall,
                            color = SoftTheme.colors.textSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                            softWrap = false
                        )
                    }

                    // Priority Flag Pill
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(priorityColor.copy(alpha = 0.12f))
                            .padding(horizontal = 6.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Flag,
                            contentDescription = null,
                            tint = priorityColor,
                            modifier = Modifier.size(10.dp)
                        )
                        Text(
                            text = task.priority.label,
                            style = MaterialTheme.typography.labelSmall,
                            color = priorityColor,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            softWrap = false
                        )
                    }

                    // Due Date / Time Pill
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(
                                if (task.isSnoozed) SoftTheme.colors.statusWarning.copy(alpha = 0.12f)
                                else SoftTheme.colors.surfaceWell
                            )
                            .padding(horizontal = 6.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp)
                    ) {
                        Icon(
                            imageVector = if (task.isSnoozed) Icons.Default.Snooze else Icons.Default.Schedule,
                            contentDescription = null,
                            tint = if (task.isSnoozed) SoftTheme.colors.statusWarning else SoftTheme.colors.textSecondary,
                            modifier = Modifier.size(10.dp)
                        )
                        val dueString = buildString {
                            append(task.dueDate)
                            if (!task.dueTime.isNullOrBlank()) {
                                append(" • ${task.dueTime}")
                            }
                        }
                        Text(
                            text = dueString,
                            style = MaterialTheme.typography.labelSmall,
                            color = if (task.isSnoozed) SoftTheme.colors.statusWarning else SoftTheme.colors.textSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                            softWrap = false
                        )
                    }
                }
            }

            // 3. QUICK ACTIONS OVERFLOW MENU
            Box(
                modifier = Modifier.padding(start = 4.dp)
            ) {
                IconButton(
                    onClick = { isMenuExpanded = true },
                    modifier = Modifier
                        .size(36.dp)
                        .testTag("task_menu_button_${task.id}")
                        .semantics { contentDescription = "Task Quick Actions" }
                ) {
                    Icon(
                        imageVector = Icons.Default.MoreVert,
                        contentDescription = "Actions",
                        tint = SoftTheme.colors.textSecondary,
                        modifier = Modifier.size(18.dp)
                    )
                }

                DropdownMenu(
                    expanded = isMenuExpanded,
                    onDismissRequest = { isMenuExpanded = false },
                    modifier = Modifier
                        .background(SoftTheme.colors.surfaceElevated)
                        .border(
                            width = SoftTheme.tokens.borders.hairline,
                            color = SoftTheme.colors.borderSubtle,
                            shape = RoundedCornerShape(12.dp)
                        )
                ) {
                    // Action 1: Complete / Mark Incomplete
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = if (task.isCompleted) "Mark Incomplete" else "Mark Complete",
                                color = SoftTheme.colors.textPrimary,
                                fontSize = 13.sp
                            )
                        },
                        leadingIcon = {
                            Icon(
                                imageVector = if (task.isCompleted) Icons.Default.RadioButtonUnchecked else Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = SoftTheme.colors.statusSuccess,
                                modifier = Modifier.size(16.dp)
                            )
                        },
                        onClick = {
                            isMenuExpanded = false
                            onToggleComplete()
                        },
                        modifier = Modifier.testTag("action_toggle_${task.id}")
                    )

                    // Action 2: Edit
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = "Edit Task",
                                color = SoftTheme.colors.textPrimary,
                                fontSize = 13.sp
                            )
                        },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Default.Edit,
                                contentDescription = null,
                                tint = SoftTheme.colors.accentBlue,
                                modifier = Modifier.size(16.dp)
                            )
                        },
                        onClick = {
                            isMenuExpanded = false
                            onEdit()
                        },
                        modifier = Modifier.testTag("action_edit_${task.id}")
                    )

                    // Action 3: Snooze / Remind Later
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = "Snooze to Tomorrow",
                                color = SoftTheme.colors.textPrimary,
                                fontSize = 13.sp
                            )
                        },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Default.Snooze,
                                contentDescription = null,
                                tint = SoftTheme.colors.statusWarning,
                                modifier = Modifier.size(16.dp)
                            )
                        },
                        onClick = {
                            isMenuExpanded = false
                            onSnooze()
                        },
                        modifier = Modifier.testTag("action_snooze_${task.id}")
                    )

                    // Action 4: Delete
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = "Delete Task",
                                color = SoftTheme.colors.statusError,
                                fontSize = 13.sp
                            )
                        },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Default.Delete,
                                contentDescription = null,
                                tint = SoftTheme.colors.statusError,
                                modifier = Modifier.size(16.dp)
                            )
                        },
                        onClick = {
                            isMenuExpanded = false
                            onDelete()
                        },
                        modifier = Modifier.testTag("action_delete_${task.id}")
                    )
                }
            }
        }
    }
}

fun getCategoryIcon(category: TaskCategory): ImageVector {
    return when (category) {
        TaskCategory.WORK -> Icons.Default.BusinessCenter
        TaskCategory.PERSONAL -> Icons.Default.Person
        TaskCategory.DEV -> Icons.Default.Code
        TaskCategory.SHOPPING -> Icons.Default.ShoppingCart
        TaskCategory.HEALTH -> Icons.Default.Favorite
        TaskCategory.GENERAL -> Icons.Default.Folder
    }
}
