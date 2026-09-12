package com.example.ui.screens.tasks

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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import com.example.ui.components.softBounceOverscroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Title
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.MobileTask
import com.example.domain.model.TaskCategory
import com.example.domain.model.TaskPriority
import com.example.ui.theme.SoftTheme

/**
 * Mobile Bottom Sheet for creating or editing a task.
 * Fields:
 * - title (Multilingual input)
 * - description
 * - project / category
 * - priority
 * - due date
 * - due time
 * - reminder
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TaskCreateEditSheet(
    isOpen: Boolean,
    onDismiss: () -> Unit,
    taskToEdit: MobileTask?,
    onSaveTask: (
        title: String,
        description: String,
        category: TaskCategory,
        priority: TaskPriority,
        dueDate: String,
        dueTime: String?,
        reminder: String?
    ) -> Unit,
    modifier: Modifier = Modifier
) {
    if (!isOpen) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var title by remember(taskToEdit) { mutableStateOf(taskToEdit?.title ?: "") }
    var description by remember(taskToEdit) { mutableStateOf(taskToEdit?.description ?: "") }
    var selectedCategory by remember(taskToEdit) { mutableStateOf(taskToEdit?.category ?: TaskCategory.GENERAL) }
    var selectedPriority by remember(taskToEdit) { mutableStateOf(taskToEdit?.priority ?: TaskPriority.MEDIUM) }
    var dueDate by remember(taskToEdit) { mutableStateOf(taskToEdit?.dueDate ?: "Today") }
    var dueTime by remember(taskToEdit) { mutableStateOf(taskToEdit?.dueTime ?: "12:00") }
    var reminder by remember(taskToEdit) { mutableStateOf(taskToEdit?.reminder ?: "15 mins before") }

    val isEditing = taskToEdit != null
    val scrollState = rememberScrollState()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.surfaceElevated,
        contentColor = SoftTheme.colors.textPrimary,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(vertical = 10.dp)
                    .size(width = 36.dp, height = 4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(SoftTheme.colors.borderSubtle)
            )
        },
        modifier = modifier.testTag("task_create_edit_sheet")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .imePadding()
                .softBounceOverscroll()
                .verticalScroll(scrollState)
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // SHEET HEADER
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = if (isEditing) "Edit Task" else "Create New Task",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(32.dp)
                        .testTag("task_sheet_close_button")
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = SoftTheme.colors.textSecondary,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // 1. TITLE FIELD (Multilingual prompt support)
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "Title *",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary
                )
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    placeholder = {
                        Text(
                            text = "e.g., Check backend bukas, Android UIを確認",
                            color = SoftTheme.colors.textMuted,
                            fontSize = 13.sp
                        )
                    },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = SoftTheme.colors.accentBlue,
                        unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                        focusedContainerColor = SoftTheme.colors.surfaceWell,
                        unfocusedContainerColor = SoftTheme.colors.surfaceWell,
                        focusedTextColor = SoftTheme.colors.textPrimary,
                        unfocusedTextColor = SoftTheme.colors.textPrimary
                    ),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("task_input_title")
                )
            }

            // 2. DESCRIPTION FIELD
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "Description",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary
                )
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    placeholder = {
                        Text(
                            text = "Add context, links, or sub-task notes...",
                            color = SoftTheme.colors.textMuted,
                            fontSize = 13.sp
                        )
                    },
                    minLines = 2,
                    maxLines = 3,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = SoftTheme.colors.accentBlue,
                        unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                        focusedContainerColor = SoftTheme.colors.surfaceWell,
                        unfocusedContainerColor = SoftTheme.colors.surfaceWell,
                        focusedTextColor = SoftTheme.colors.textPrimary,
                        unfocusedTextColor = SoftTheme.colors.textPrimary
                    ),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("task_input_description")
                )
            }

            // 3. PROJECT / CATEGORY SELECTOR
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "Project / Category",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    TaskCategory.entries.forEach { category ->
                        val isSelected = selectedCategory == category
                        val catIcon = getCategoryIcon(category)
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                                .background(
                                    if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.18f)
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = if (isSelected) 1.5.dp else SoftTheme.tokens.borders.hairline,
                                    color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                                )
                                .clickable { selectedCategory = category }
                                .padding(horizontal = 10.dp, vertical = 6.dp)
                                .testTag("task_category_${category.name.lowercase()}"),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            Icon(
                                imageVector = catIcon,
                                contentDescription = null,
                                tint = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary,
                                modifier = Modifier.size(13.dp)
                            )
                            Text(
                                text = category.label,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary,
                                fontSize = 11.sp
                            )
                        }
                    }
                }
            }

            // 4. PRIORITY SELECTOR
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "Priority",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    TaskPriority.entries.forEach { priority ->
                        val isSelected = selectedPriority == priority
                        val pColor = when (priority) {
                            TaskPriority.LOW -> SoftTheme.colors.textMuted
                            TaskPriority.MEDIUM -> SoftTheme.colors.accentBlue
                            TaskPriority.HIGH -> SoftTheme.colors.statusWarning
                            TaskPriority.URGENT -> SoftTheme.colors.statusError
                        }

                        Row(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .background(
                                    if (isSelected) pColor.copy(alpha = 0.16f)
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = if (isSelected) 1.5.dp else SoftTheme.tokens.borders.hairline,
                                    color = if (isSelected) pColor else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(10.dp)
                                )
                                .clickable { selectedPriority = priority }
                                .padding(vertical = 8.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Flag,
                                contentDescription = null,
                                tint = if (isSelected) pColor else SoftTheme.colors.textMuted,
                                modifier = Modifier.size(12.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = priority.label,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) pColor else SoftTheme.colors.textSecondary,
                                fontSize = 11.sp
                            )
                        }
                    }
                }
            }

            // 5. DUE DATE & DUE TIME ROW
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Due Date
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "Due Date",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.textSecondary
                    )
                    OutlinedTextField(
                        value = dueDate,
                        onValueChange = { dueDate = it },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Default.CalendarMonth,
                                contentDescription = null,
                                tint = SoftTheme.colors.accentBlue,
                                modifier = Modifier.size(16.dp)
                            )
                        },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SoftTheme.colors.accentBlue,
                            unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                            focusedContainerColor = SoftTheme.colors.surfaceWell,
                            unfocusedContainerColor = SoftTheme.colors.surfaceWell,
                            focusedTextColor = SoftTheme.colors.textPrimary,
                            unfocusedTextColor = SoftTheme.colors.textPrimary
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("task_input_due_date")
                    )
                }

                // Due Time
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "Due Time",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.textSecondary
                    )
                    OutlinedTextField(
                        value = dueTime,
                        onValueChange = { dueTime = it },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Default.Schedule,
                                contentDescription = null,
                                tint = SoftTheme.colors.accentCyan,
                                modifier = Modifier.size(16.dp)
                            )
                        },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SoftTheme.colors.accentBlue,
                            unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                            focusedContainerColor = SoftTheme.colors.surfaceWell,
                            unfocusedContainerColor = SoftTheme.colors.surfaceWell,
                            focusedTextColor = SoftTheme.colors.textPrimary,
                            unfocusedTextColor = SoftTheme.colors.textPrimary
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("task_input_due_time")
                    )
                }
            }

            // 6. REMINDER FIELD
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "Reminder",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary
                )
                OutlinedTextField(
                    value = reminder,
                    onValueChange = { reminder = it },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Notifications,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentViolet,
                            modifier = Modifier.size(16.dp)
                        )
                    },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = SoftTheme.colors.accentBlue,
                        unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                        focusedContainerColor = SoftTheme.colors.surfaceWell,
                        unfocusedContainerColor = SoftTheme.colors.surfaceWell,
                        focusedTextColor = SoftTheme.colors.textPrimary,
                        unfocusedTextColor = SoftTheme.colors.textPrimary
                    ),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("task_input_reminder")
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            // ACTION BUTTONS: Cancel & Save
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("task_sheet_cancel_button"),
                    shape = RoundedCornerShape(12.dp),
                    border = androidx.compose.foundation.BorderStroke(
                        width = SoftTheme.tokens.borders.hairline,
                        color = SoftTheme.colors.borderSubtle
                    )
                ) {
                    Text(
                        text = "Cancel",
                        color = SoftTheme.colors.textSecondary,
                        fontWeight = FontWeight.Medium
                    )
                }

                Button(
                    onClick = {
                        if (title.isNotBlank()) {
                            onSaveTask(
                                title,
                                description,
                                selectedCategory,
                                selectedPriority,
                                dueDate,
                                dueTime,
                                reminder
                            )
                        }
                    },
                    enabled = title.isNotBlank(),
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("task_sheet_save_button"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SoftTheme.colors.accentBlue,
                        disabledContainerColor = SoftTheme.colors.surfaceWell
                    )
                ) {
                    Text(
                        text = if (isEditing) "Save Changes" else "Create Task",
                        fontWeight = FontWeight.Bold,
                        color = if (title.isNotBlank()) Color.White else SoftTheme.colors.textMuted
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
