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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
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
    var dueTime by remember(taskToEdit) { mutableStateOf(taskToEdit?.dueTime ?: "12:00 PM") }
    var reminder by remember(taskToEdit) { mutableStateOf(taskToEdit?.reminder ?: "15m before") }

    var showDatePickerDialog by remember { mutableStateOf(false) }
    var showTimePickerDialog by remember { mutableStateOf(false) }

    val datePickerState = rememberDatePickerState()
    val timePickerState = rememberTimePickerState(is24Hour = false)

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
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "Title *",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary,
                    fontSize = 15.sp
                )
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    textStyle = androidx.compose.ui.text.TextStyle(
                        fontSize = 16.sp,
                        color = SoftTheme.colors.textPrimary,
                        fontWeight = FontWeight.Normal
                    ),
                    placeholder = {
                        Text(
                            text = "e.g., Check backend bukas, Android UIを確認",
                            color = SoftTheme.colors.textMuted,
                            fontSize = 14.sp
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
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "Description",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary,
                    fontSize = 15.sp
                )
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    textStyle = androidx.compose.ui.text.TextStyle(
                        fontSize = 15.sp,
                        color = SoftTheme.colors.textPrimary,
                        fontWeight = FontWeight.Normal
                    ),
                    placeholder = {
                        Text(
                            text = "Add context, links, or sub-task notes...",
                            color = SoftTheme.colors.textMuted,
                            fontSize = 14.sp
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

            // 3. PROJECT / CATEGORY SELECTOR (Enlarged for senior readability)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Project / Category",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary,
                    fontSize = 15.sp
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    TaskCategory.entries.forEach { category ->
                        val isSelected = selectedCategory == category
                        val catIcon = getCategoryIcon(category)
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                                .background(
                                    if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.22f)
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = if (isSelected) 2.dp else SoftTheme.tokens.borders.hairline,
                                    color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                                )
                                .clickable { selectedCategory = category }
                                .padding(horizontal = 14.dp, vertical = 10.dp)
                                .testTag("task_category_${category.name.lowercase()}"),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = catIcon,
                                contentDescription = null,
                                tint = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                            Text(
                                text = category.label,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
            }

            // 4. PRIORITY SELECTOR (Accessible large buttons)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Priority",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary,
                    fontSize = 15.sp
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
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (isSelected) pColor.copy(alpha = 0.22f)
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = if (isSelected) 2.dp else SoftTheme.tokens.borders.hairline,
                                    color = if (isSelected) pColor else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .clickable { selectedPriority = priority }
                                .padding(vertical = 12.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Flag,
                                contentDescription = null,
                                tint = if (isSelected) pColor else SoftTheme.colors.textMuted,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(5.dp))
                            Text(
                                text = priority.label,
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isSelected) pColor else SoftTheme.colors.textSecondary,
                                fontSize = 13.sp
                            )
                        }
                    }
                }
            }

            // 5. DUE DATE SELECTOR (3 Large Quick Options + Dedicated Calendar Picker Button)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Due Date",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 15.sp
                    )
                    Text(
                        text = dueDate,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.accentBlue,
                        fontSize = 15.sp
                    )
                }

                // 3 Large Quick Chips (limit to 3 options for high readability)
                val datePresets = listOf("Today", "Tomorrow", "Next Week")
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    datePresets.forEach { preset ->
                        val isSelected = dueDate == preset
                        Row(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.22f)
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = if (isSelected) 2.dp else SoftTheme.tokens.borders.hairline,
                                    color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .clickable { dueDate = preset }
                                .padding(vertical = 12.dp)
                                .testTag("task_date_preset_${preset.lowercase().replace(" ", "_")}"),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = preset,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary,
                                fontSize = 14.sp
                            )
                        }
                    }
                }

                // Dedicated Prominent Calendar Picker Button
                val isCustomDate = !datePresets.contains(dueDate)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (isCustomDate) SoftTheme.colors.accentBlue.copy(alpha = 0.18f)
                            else SoftTheme.colors.surfaceElevated
                        )
                        .border(
                            width = if (isCustomDate) 2.dp else SoftTheme.tokens.borders.hairline,
                            color = if (isCustomDate) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                            shape = RoundedCornerShape(12.dp)
                        )
                        .clickable { showDatePickerDialog = true }
                        .padding(horizontal = 16.dp, vertical = 13.dp)
                        .testTag("task_date_pick_calendar_button"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.CalendarMonth,
                        contentDescription = null,
                        tint = if (isCustomDate) SoftTheme.colors.accentBlue else SoftTheme.colors.accentCyan,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = if (isCustomDate) "📅 Date: $dueDate (Tap to change)" else "📅 Pick Specific Date from Calendar...",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isCustomDate) FontWeight.Bold else FontWeight.SemiBold,
                        color = if (isCustomDate) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary,
                        fontSize = 14.sp
                    )
                }
            }

            // 6. DUE TIME SELECTOR (12-Hour AM/PM: 3 Large Quick Options + Dedicated Time Picker Button)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Due Time (12-Hour AM/PM)",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 15.sp
                    )
                    Text(
                        text = dueTime,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.accentCyan,
                        fontSize = 15.sp
                    )
                }

                // 3 Large Quick Time Chips
                val timePresets = listOf("09:00 AM", "12:00 PM", "06:00 PM")
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    timePresets.forEach { preset ->
                        val isSelected = dueTime == preset
                        Row(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .background(
                                    if (isSelected) SoftTheme.colors.accentCyan.copy(alpha = 0.22f)
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = if (isSelected) 2.dp else SoftTheme.tokens.borders.hairline,
                                    color = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(12.dp)
                                )
                                .clickable { dueTime = preset }
                                .padding(vertical = 12.dp)
                                .testTag("task_time_preset_${preset.lowercase().replace(" ", "_").replace(":", "_")}"),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = preset,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.textPrimary,
                                fontSize = 14.sp
                            )
                        }
                    }
                }

                // Dedicated Prominent Time Picker Button
                val isCustomTime = !timePresets.contains(dueTime)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (isCustomTime) SoftTheme.colors.accentCyan.copy(alpha = 0.18f)
                            else SoftTheme.colors.surfaceElevated
                        )
                        .border(
                            width = if (isCustomTime) 2.dp else SoftTheme.tokens.borders.hairline,
                            color = if (isCustomTime) SoftTheme.colors.accentCyan else SoftTheme.colors.borderSubtle,
                            shape = RoundedCornerShape(12.dp)
                        )
                        .clickable { showTimePickerDialog = true }
                        .padding(horizontal = 16.dp, vertical = 13.dp)
                        .testTag("task_time_pick_clock_button"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Schedule,
                        contentDescription = null,
                        tint = if (isCustomTime) SoftTheme.colors.accentCyan else SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = if (isCustomTime) "⏰ Time: $dueTime (Tap to change)" else "⏰ Pick Exact Time (AM/PM)...",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isCustomTime) FontWeight.Bold else FontWeight.SemiBold,
                        color = if (isCustomTime) SoftTheme.colors.accentCyan else SoftTheme.colors.textPrimary,
                        fontSize = 14.sp
                    )
                }
            }

            // 7. REMINDER SELECTOR (Structured Large Presets)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Reminder Notification",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 15.sp
                    )
                    Text(
                        text = reminder,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.accentViolet,
                        fontSize = 15.sp
                    )
                }

                val reminderOptions = listOf(
                    "None",
                    "At due time",
                    "15m before",
                    "1h before",
                    "1d before"
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    reminderOptions.forEach { option ->
                        val isSelected = reminder == option || (option == "15m before" && reminder.contains("15"))
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                                .background(
                                    if (isSelected) SoftTheme.colors.accentViolet.copy(alpha = 0.22f)
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = if (isSelected) 2.dp else SoftTheme.tokens.borders.hairline,
                                    color = if (isSelected) SoftTheme.colors.accentViolet else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                                )
                                .clickable { reminder = option }
                                .padding(horizontal = 14.dp, vertical = 10.dp)
                                .testTag("task_reminder_${option.lowercase().replace(" ", "_")}"),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Notifications,
                                contentDescription = null,
                                tint = if (isSelected) SoftTheme.colors.accentViolet else SoftTheme.colors.textSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                            Text(
                                text = option,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isSelected) SoftTheme.colors.accentViolet else SoftTheme.colors.textPrimary,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
            }

            // DATE PICKER DIALOG
            if (showDatePickerDialog) {
                DatePickerDialog(
                    onDismissRequest = { showDatePickerDialog = false },
                    confirmButton = {
                        TextButton(onClick = {
                            datePickerState.selectedDateMillis?.let { millis ->
                                val calendar = Calendar.getInstance().apply { timeInMillis = millis }
                                val today = Calendar.getInstance()
                                val isToday = calendar.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                                        calendar.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
                                today.add(Calendar.DAY_OF_YEAR, 1)
                                val isTomorrow = calendar.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                                        calendar.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
                                dueDate = when {
                                    isToday -> "Today"
                                    isTomorrow -> "Tomorrow"
                                    else -> SimpleDateFormat("MMM dd, yyyy", Locale.getDefault()).format(calendar.time)
                                }
                            }
                            showDatePickerDialog = false
                        }) {
                            Text("Select", color = SoftTheme.colors.accentBlue)
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { showDatePickerDialog = false }) {
                            Text("Cancel", color = SoftTheme.colors.textSecondary)
                        }
                    },
                    colors = DatePickerDefaults.colors(
                        containerColor = SoftTheme.colors.surfaceElevated
                    )
                ) {
                    DatePicker(state = datePickerState)
                }
            }

            // 12-HOUR TIME PICKER DIALOG
            if (showTimePickerDialog) {
                AlertDialog(
                    onDismissRequest = { showTimePickerDialog = false },
                    confirmButton = {
                        TextButton(onClick = {
                            val hour = timePickerState.hour
                            val minute = timePickerState.minute
                            val amPm = if (hour < 12) "AM" else "PM"
                            val displayHour = when {
                                hour == 0 -> 12
                                hour > 12 -> hour - 12
                                else -> hour
                            }
                            dueTime = String.format(Locale.getDefault(), "%02d:%02d %s", displayHour, minute, amPm)
                            showTimePickerDialog = false
                        }) {
                            Text("Select", color = SoftTheme.colors.accentCyan)
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { showTimePickerDialog = false }) {
                            Text("Cancel", color = SoftTheme.colors.textSecondary)
                        }
                    },
                    text = {
                        TimePicker(
                            state = timePickerState,
                            colors = TimePickerDefaults.colors(
                                clockDialColor = SoftTheme.colors.surfaceWell,
                                selectorColor = SoftTheme.colors.accentCyan
                            )
                        )
                    },
                    containerColor = SoftTheme.colors.surfaceElevated
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
                        .height(54.dp)
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
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 15.sp
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
                        .height(54.dp)
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
                        fontSize = 16.sp,
                        color = if (title.isNotBlank()) Color.White else SoftTheme.colors.textMuted
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
