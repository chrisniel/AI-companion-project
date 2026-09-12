package com.example.ui.screens.tasks

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import com.example.ui.components.softBounceOverscroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.EventNote
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Today
import androidx.compose.material.icons.filled.Upcoming
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.MobileTask
import com.example.domain.model.TaskViewTab
import com.example.domain.model.TasksUiState
import com.example.ui.theme.SoftTheme

/**
 * Mobile Tasks Screen (Batch 5).
 * Primary Views:
 * - Today
 * - Upcoming
 * - Completed
 *
 * Provides:
 * - Tab switcher (Today, Upcoming, Completed)
 * - Search filter for multilingual tasks
 * - Task list with interactive TaskRowItems
 * - Quick Actions: complete, edit, delete, snooze/remind later
 * - Create / Edit bottom sheet with full fields (no persistence)
 * - Floating Action Button to quickly add tasks
 * - In-app snackbar/feedback banner
 */
@Composable
fun TasksScreen(
    modifier: Modifier = Modifier,
    viewModel: TasksViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    // Filter tasks based on selected tab and search query
    val filteredTasks = when (uiState.selectedTab) {
        TaskViewTab.TODAY -> uiState.tasks.filter {
            !it.isCompleted && (it.dueDate.equals("Today", ignoreCase = true) || it.dueDate.contains("Today", ignoreCase = true))
        }
        TaskViewTab.UPCOMING -> uiState.tasks.filter {
            !it.isCompleted && !it.dueDate.equals("Today", ignoreCase = true) && !it.dueDate.contains("Today", ignoreCase = true)
        }
        TaskViewTab.COMPLETED -> uiState.tasks.filter { it.isCompleted }
    }.filter { task ->
        if (uiState.searchQuery.isBlank()) true
        else {
            task.title.contains(uiState.searchQuery, ignoreCase = true) ||
                task.description.contains(uiState.searchQuery, ignoreCase = true) ||
                task.category.label.contains(uiState.searchQuery, ignoreCase = true)
        }
    }

    val taskToEdit = uiState.tasks.find { it.id == uiState.editingTaskId }

    Box(
        modifier = modifier
            .fillMaxSize()
            .testTag("tasks_screen")
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // HEADER & SEARCH BAR
            TasksTopBar(
                searchQuery = uiState.searchQuery,
                onSearchQueryChange = { viewModel.updateSearchQuery(it) }
            )

            // PRIMARY VIEWS TAB SELECTOR: Today, Upcoming, Completed
            TasksTabRow(
                selectedTab = uiState.selectedTab,
                onTabSelect = { viewModel.selectTab(it) },
                todayCount = uiState.tasks.count { !it.isCompleted && it.dueDate.contains("Today", ignoreCase = true) },
                upcomingCount = uiState.tasks.count { !it.isCompleted && !it.dueDate.contains("Today", ignoreCase = true) },
                completedCount = uiState.tasks.count { it.isCompleted }
            )

            // TASKS LIST OR EMPTY STATE
            if (filteredTasks.isEmpty()) {
                EmptyTasksView(
                    tab = uiState.selectedTab,
                    searchQuery = uiState.searchQuery,
                    onAddNewTask = { viewModel.openCreateSheet() },
                    modifier = Modifier.weight(1f)
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .softBounceOverscroll()
                        .testTag("tasks_list"),
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 88.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(
                        items = filteredTasks,
                        key = { it.id }
                    ) { task ->
                        TaskRowItem(
                            task = task,
                            onToggleComplete = { viewModel.toggleTaskComplete(task.id) },
                            onEdit = { viewModel.openEditSheet(task.id) },
                            onDelete = { viewModel.deleteTask(task.id) },
                            onSnooze = { viewModel.snoozeTask(task.id) }
                        )
                    }
                }
            }
        }

        // QUICK ACTION FEEDBACK TOAST / BANNER
        AnimatedVisibility(
            visible = uiState.quickActionFeedbackMessage != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 84.dp, start = 20.dp, end = 20.dp)
        ) {
            uiState.quickActionFeedbackMessage?.let { msg ->
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(SoftTheme.colors.surfaceElevated)
                        .border(
                            width = SoftTheme.tokens.borders.hairline,
                            color = SoftTheme.colors.accentBlue.copy(alpha = 0.4f),
                            shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                        )
                        .padding(horizontal = 16.dp, vertical = 10.dp)
                        .testTag("quick_action_feedback_toast"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = msg,
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 12.sp
                    )
                }
            }
        }

        // FLOATING ACTION BUTTON: CREATE TASK
        FloatingActionButton(
            onClick = { viewModel.openCreateSheet() },
            containerColor = SoftTheme.colors.accentBlue,
            contentColor = Color.White,
            shape = CircleShape,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(bottom = 24.dp, end = 20.dp)
                .testTag("add_task_fab")
                .semantics { contentDescription = "Create New Task" }
        ) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = null,
                modifier = Modifier.size(24.dp)
            )
        }

        // CREATE / EDIT BOTTOM SHEET
        TaskCreateEditSheet(
            isOpen = uiState.isCreateOrEditSheetOpen,
            onDismiss = { viewModel.closeSheet() },
            taskToEdit = taskToEdit,
            onSaveTask = { title, desc, cat, prio, dueD, dueT, rem ->
                viewModel.saveTask(title, desc, cat, prio, dueD, dueT, rem)
            }
        )
    }
}

/**
 * Top bar with title and searchable query field.
 */
@Composable
private fun TasksTopBar(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Search bar
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchQueryChange,
            placeholder = {
                Text(
                    text = "Search tasks (EN / FIL / JA)...",
                    color = SoftTheme.colors.textMuted,
                    fontSize = 13.sp
                )
            },
            leadingIcon = {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = null,
                    tint = SoftTheme.colors.textSecondary,
                    modifier = Modifier.size(18.dp)
                )
            },
            trailingIcon = {
                if (searchQuery.isNotBlank()) {
                    IconButton(
                        onClick = { onSearchQueryChange("") },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Clear,
                            contentDescription = "Clear search",
                            tint = SoftTheme.colors.textSecondary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            },
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = SoftTheme.colors.accentBlue,
                unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                focusedContainerColor = SoftTheme.colors.surfaceElevated,
                unfocusedContainerColor = SoftTheme.colors.surfaceElevated,
                focusedTextColor = SoftTheme.colors.textPrimary,
                unfocusedTextColor = SoftTheme.colors.textPrimary
            ),
            shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
            modifier = Modifier
                .fillMaxWidth()
                .testTag("tasks_search_input")
        )
    }
}

/**
 * Tab Row for the 3 Primary Views (Today, Upcoming, Completed).
 */
@Composable
private fun TasksTabRow(
    selectedTab: TaskViewTab,
    onTabSelect: (TaskViewTab) -> Unit,
    todayCount: Int,
    upcomingCount: Int,
    completedCount: Int,
    modifier: Modifier = Modifier
) {
    val tabs = TaskViewTab.entries

    TabRow(
        selectedTabIndex = selectedTab.ordinal,
        containerColor = Color.Transparent,
        contentColor = SoftTheme.colors.accentBlue,
        indicator = { tabPositions ->
            if (selectedTab.ordinal < tabPositions.size) {
                TabRowDefaults.SecondaryIndicator(
                    modifier = Modifier.tabIndicatorOffset(tabPositions[selectedTab.ordinal]),
                    color = SoftTheme.colors.accentBlue,
                    height = 2.5.dp
                )
            }
        },
        divider = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(SoftTheme.tokens.borders.hairline)
                    .background(SoftTheme.colors.borderSubtle)
            )
        },
        modifier = modifier.fillMaxWidth()
    ) {
        tabs.forEach { tab ->
            val isSelected = selectedTab == tab
            val count = when (tab) {
                TaskViewTab.TODAY -> todayCount
                TaskViewTab.UPCOMING -> upcomingCount
                TaskViewTab.COMPLETED -> completedCount
            }

            Tab(
                selected = isSelected,
                onClick = { onTabSelect(tab) },
                modifier = Modifier
                    .testTag(tab.testTag)
                    .semantics { contentDescription = "${tab.label} tasks tab, $count items" }
            ) {
                Row(
                    modifier = Modifier.padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = tab.label,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                        color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary,
                        fontSize = 13.sp
                    )

                    // Badge Count
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(
                                if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.15f)
                                else SoftTheme.colors.surfaceWell
                            )
                            .padding(horizontal = 6.dp, vertical = 1.dp)
                    ) {
                        Text(
                            text = count.toString(),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textMuted,
                            fontSize = 10.sp
                        )
                    }
                }
            }
        }
    }
}

/**
 * Empty view state when no tasks match tab / search.
 */
@Composable
private fun EmptyTasksView(
    tab: TaskViewTab,
    searchQuery: String,
    onAddNewTask: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        val icon = when (tab) {
            TaskViewTab.TODAY -> Icons.Default.Today
            TaskViewTab.UPCOMING -> Icons.Default.Upcoming
            TaskViewTab.COMPLETED -> Icons.Default.CheckCircle
        }

        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(SoftTheme.colors.surfaceElevated)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = SoftTheme.colors.borderSubtle,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = SoftTheme.colors.accentBlue.copy(alpha = 0.7f),
                modifier = Modifier.size(28.dp)
            )
        }

        Spacer(modifier = Modifier.height(14.dp))

        Text(
            text = if (searchQuery.isNotBlank()) "No tasks matching \"$searchQuery\""
            else when (tab) {
                TaskViewTab.TODAY -> "All caught up for Today!"
                TaskViewTab.UPCOMING -> "No upcoming scheduled tasks"
                TaskViewTab.COMPLETED -> "No completed tasks yet"
            },
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = SoftTheme.colors.textPrimary
        )

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = when (tab) {
                TaskViewTab.TODAY -> "Tap the + button to capture something for today."
                TaskViewTab.UPCOMING -> "Schedule future workflows or reminders."
                TaskViewTab.COMPLETED -> "Completed tasks will appear here for reference."
            },
            style = MaterialTheme.typography.bodySmall,
            color = SoftTheme.colors.textSecondary,
            fontSize = 12.sp
        )
    }
}
