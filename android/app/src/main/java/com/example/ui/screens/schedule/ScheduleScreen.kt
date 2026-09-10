package com.example.ui.screens.schedule

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material.icons.filled.ViewAgenda
import androidx.compose.material.icons.filled.ViewDay
import androidx.compose.material.icons.filled.ViewWeek
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.ScheduleEntry
import com.example.domain.model.ScheduleEntryType
import com.example.domain.model.ScheduleViewMode
import com.example.ui.theme.SoftTheme

/**
 * Mobile-friendly Schedule Screen.
 * Views:
 * - Day (Hourly / timeline representation of today's commitments)
 * - Agenda (Chronological stream grouped by date)
 * - Week (Compact, ergonomic 7-day strip and daily breakdown)
 *
 * Supported items:
 * - task
 * - reminder
 * - alarm
 * - calendar event
 */
@Composable
fun ScheduleScreen(
    modifier: Modifier = Modifier,
    viewModel: ScheduleViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    val filteredEntries = uiState.entries.filter { entry ->
        if (uiState.filterType == null) true
        else entry.type == uiState.filterType
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(SoftTheme.colors.background)
            .testTag("schedule_screen")
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // VIEW MODE TABS: Day, Agenda, Week
            ScheduleViewModeTabRow(
                currentMode = uiState.selectedViewMode,
                onModeSelected = { viewModel.selectViewMode(it) }
            )

            // CATEGORY FILTER CHIPS: All, Tasks, Reminders, Alarms, Calendar Events
            ScheduleFilterChipsRow(
                selectedType = uiState.filterType,
                onTypeSelected = { viewModel.setFilterType(it) }
            )

            // MAIN VIEW CONTENT
            when (uiState.selectedViewMode) {
                ScheduleViewMode.DAY -> DayTimelineView(
                    entries = filteredEntries.filter { it.date.contains("Today", ignoreCase = true) },
                    onToggleComplete = { viewModel.toggleComplete(it) },
                    onDismiss = { viewModel.dismissEntry(it) }
                )
                ScheduleViewMode.AGENDA -> AgendaListView(
                    entries = filteredEntries,
                    onToggleComplete = { viewModel.toggleComplete(it) },
                    onDismiss = { viewModel.dismissEntry(it) }
                )
                ScheduleViewMode.WEEK -> CompactWeekView(
                    entries = filteredEntries,
                    onToggleComplete = { viewModel.toggleComplete(it) },
                    onDismiss = { viewModel.dismissEntry(it) }
                )
            }
        }

        // FEEDBACK TOAST / BANNER
        AnimatedVisibility(
            visible = uiState.quickActionFeedback != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 20.dp, start = 20.dp, end = 20.dp)
        ) {
            uiState.quickActionFeedback?.let { msg ->
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
                        .testTag("schedule_feedback_toast"),
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
    }
}

/**
 * Top Tab Row to switch between Day, Agenda, and compact Week.
 */
@Composable
private fun ScheduleViewModeTabRow(
    currentMode: ScheduleViewMode,
    onModeSelected: (ScheduleViewMode) -> Unit,
    modifier: Modifier = Modifier
) {
    val modes = ScheduleViewMode.entries

    TabRow(
        selectedTabIndex = currentMode.ordinal,
        containerColor = SoftTheme.colors.surfaceElevated,
        contentColor = SoftTheme.colors.accentBlue,
        indicator = { tabPositions ->
            if (currentMode.ordinal < tabPositions.size) {
                TabRowDefaults.SecondaryIndicator(
                    modifier = Modifier.tabIndicatorOffset(tabPositions[currentMode.ordinal]),
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
        modes.forEach { mode ->
            val isSelected = currentMode == mode
            val icon = when (mode) {
                ScheduleViewMode.DAY -> Icons.Default.ViewDay
                ScheduleViewMode.AGENDA -> Icons.Default.ViewAgenda
                ScheduleViewMode.WEEK -> Icons.Default.ViewWeek
            }

            Tab(
                selected = isSelected,
                onClick = { onModeSelected(mode) },
                modifier = Modifier
                    .testTag(mode.testTag)
                    .semantics { contentDescription = "${mode.label} View" }
            ) {
                Row(
                    modifier = Modifier.padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = mode.label,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                        color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary,
                        fontSize = 13.sp
                    )
                }
            }
        }
    }
}

/**
 * Filter Chips to inspect specific entry types: All, Task, Reminder, Alarm, Calendar Event.
 */
@Composable
private fun ScheduleFilterChipsRow(
    selectedType: ScheduleEntryType?,
    onTypeSelected: (ScheduleEntryType?) -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(scrollState)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // "All" chip
        FilterChip(
            label = "All Items",
            isSelected = selectedType == null,
            onClick = { onTypeSelected(null) },
            testTag = "filter_chip_all"
        )

        ScheduleEntryType.entries.forEach { type ->
            FilterChip(
                label = type.label,
                icon = getEntryTypeIcon(type),
                isSelected = selectedType == type,
                onClick = { onTypeSelected(if (selectedType == type) null else type) },
                testTag = "filter_chip_${type.name.lowercase()}"
            )
        }
    }
}

@Composable
private fun FilterChip(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    testTag: String,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(
                if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.16f)
                else SoftTheme.colors.surfaceElevated
            )
            .border(
                width = if (isSelected) 1.5.dp else SoftTheme.tokens.borders.hairline,
                color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .testTag(testTag),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary,
                modifier = Modifier.size(13.dp)
            )
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
            color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary,
            fontSize = 11.sp
        )
    }
}

/**
 * Day View: Visual hourly timeline of today's tasks, reminders, alarms, and calendar events.
 */
@Composable
private fun DayTimelineView(
    entries: List<ScheduleEntry>,
    onToggleComplete: (String) -> Unit,
    onDismiss: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (entries.isEmpty()) {
        EmptyScheduleState(
            message = "No items scheduled for today",
            subtitle = "Enjoy a calm schedule or add a new task or alarm.",
            modifier = modifier
        )
        return
    }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .testTag("schedule_day_timeline"),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item {
            // Day header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Today • Wednesday, Sep 9",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = "${entries.size} items",
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.accentBlue,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        items(
            items = entries,
            key = { it.id }
        ) { entry ->
            ScheduleEntryCard(
                entry = entry,
                onToggleComplete = { onToggleComplete(entry.id) },
                onDismiss = { onDismiss(entry.id) },
                showTimelineIndicator = true
            )
        }
    }
}

/**
 * Agenda View: Chronological list grouped seamlessly across days.
 */
@Composable
private fun AgendaListView(
    entries: List<ScheduleEntry>,
    onToggleComplete: (String) -> Unit,
    onDismiss: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (entries.isEmpty()) {
        EmptyScheduleState(
            message = "Agenda is empty",
            subtitle = "No upcoming tasks, reminders, or alarms scheduled.",
            modifier = modifier
        )
        return
    }

    // Group entries by date
    val grouped = entries.groupBy { it.date }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .testTag("schedule_agenda_list"),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        grouped.forEach { (date, dateEntries) ->
            item(key = "header_$date") {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 6.dp, bottom = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = date,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.accentBlue
                    )
                    Text(
                        text = "${dateEntries.size} scheduled",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textMuted
                    )
                }
            }

            items(
                items = dateEntries,
                key = { it.id }
            ) { entry ->
                ScheduleEntryCard(
                    entry = entry,
                    onToggleComplete = { onToggleComplete(entry.id) },
                    onDismiss = { onDismiss(entry.id) },
                    showTimelineIndicator = false
                )
            }
        }
    }
}

/**
 * Compact Week View: 7-day strip header with day-by-day scannable schedule blocks.
 */
@Composable
private fun CompactWeekView(
    entries: List<ScheduleEntry>,
    onToggleComplete: (String) -> Unit,
    onDismiss: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val weekDays = listOf(
        Triple("Mon", "7", false),
        Triple("Tue", "8", false),
        Triple("Wed", "9", true),   // Today
        Triple("Thu", "10", false),
        Triple("Fri", "11", false),
        Triple("Sat", "12", false),
        Triple("Sun", "13", false)
    )

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .testTag("schedule_week_view"),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Compact 7-Day Strip
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                    .background(SoftTheme.colors.surfaceElevated)
                    .border(
                        width = SoftTheme.tokens.borders.hairline,
                        color = SoftTheme.colors.borderSubtle,
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
                    )
                    .padding(vertical = 10.dp, horizontal = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                weekDays.forEach { (day, num, isToday) ->
                    val dayEntriesCount = entries.count { it.dayOfWeek.equals(day, ignoreCase = true) }
                    Column(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(
                                if (isToday) SoftTheme.colors.accentBlue
                                else Color.Transparent
                            )
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = day,
                            style = MaterialTheme.typography.labelSmall,
                            color = if (isToday) Color.White else SoftTheme.colors.textMuted,
                            fontSize = 11.sp,
                            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = num,
                            style = MaterialTheme.typography.titleSmall,
                            color = if (isToday) Color.White else SoftTheme.colors.textPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                        Spacer(modifier = Modifier.height(3.dp))
                        // Dot indicator if items exist
                        Box(
                            modifier = Modifier
                                .size(4.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isToday) Color.White.copy(alpha = 0.8f)
                                    else if (dayEntriesCount > 0) SoftTheme.colors.accentBlue
                                    else Color.Transparent
                                )
                        )
                    }
                }
            }
        }

        // List of entries organized chronologically
        items(
            items = entries,
            key = { it.id }
        ) { entry ->
            ScheduleEntryCard(
                entry = entry,
                onToggleComplete = { onToggleComplete(entry.id) },
                onDismiss = { onDismiss(entry.id) },
                showTimelineIndicator = true
            )
        }
    }
}

/**
 * Individual Schedule Item Card representing task, reminder, alarm, or calendar event.
 */
@Composable
private fun ScheduleEntryCard(
    entry: ScheduleEntry,
    onToggleComplete: () -> Unit,
    onDismiss: () -> Unit,
    showTimelineIndicator: Boolean,
    modifier: Modifier = Modifier
) {
    val typeColor = when (entry.type) {
        ScheduleEntryType.TASK -> SoftTheme.colors.accentBlue
        ScheduleEntryType.REMINDER -> SoftTheme.colors.accentCyan
        ScheduleEntryType.ALARM -> SoftTheme.colors.statusWarning
        ScheduleEntryType.CALENDAR_EVENT -> SoftTheme.colors.accentViolet
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(
                if (entry.isCompleted) SoftTheme.colors.surfaceWell.copy(alpha = 0.6f)
                else SoftTheme.colors.surfaceElevated
            )
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = if (entry.isCompleted) SoftTheme.colors.borderSubtle
                else typeColor.copy(alpha = 0.35f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .padding(12.dp)
            .testTag("schedule_item_${entry.id}"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Time & Timeline Pill
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.width(62.dp)
        ) {
            Text(
                text = entry.time,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textPrimary,
                fontSize = 11.sp
            )
            Spacer(modifier = Modifier.height(4.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                    .background(typeColor.copy(alpha = 0.16f))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text(
                    text = entry.type.label,
                    style = MaterialTheme.typography.labelSmall,
                    color = typeColor,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        // Vertical divider accent
        Box(
            modifier = Modifier
                .width(2.dp)
                .height(36.dp)
                .clip(RoundedCornerShape(1.dp))
                .background(typeColor.copy(alpha = 0.5f))
        )

        // Middle: Title & Subtitle / source
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = entry.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (entry.isCompleted) SoftTheme.colors.textMuted else SoftTheme.colors.textPrimary,
                textDecoration = if (entry.isCompleted) TextDecoration.LineThrough else null,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            if (entry.subtitle != null) {
                Text(
                    text = entry.subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 11.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            if (entry.locationOrSource != null) {
                Text(
                    text = entry.locationOrSource,
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 10.sp
                )
            }
        }

        // Action button: Toggle complete or dismiss
        if (entry.type == ScheduleEntryType.TASK || entry.type == ScheduleEntryType.REMINDER) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(
                        if (entry.isCompleted) SoftTheme.colors.statusSuccess.copy(alpha = 0.18f)
                        else SoftTheme.colors.surfaceWell
                    )
                    .border(
                        width = 1.dp,
                        color = if (entry.isCompleted) SoftTheme.colors.statusSuccess else SoftTheme.colors.borderSubtle,
                        shape = CircleShape
                    )
                    .clickable(onClick = onToggleComplete)
                    .semantics {
                        contentDescription = if (entry.isCompleted) "Mark active" else "Mark complete"
                    },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = if (entry.isCompleted) SoftTheme.colors.statusSuccess else SoftTheme.colors.textMuted,
                    modifier = Modifier.size(16.dp)
                )
            }
        } else {
            // Dismiss or view action for alarm / calendar event
            IconButton(
                onClick = onDismiss,
                modifier = Modifier
                    .size(36.dp)
                    .testTag("dismiss_schedule_${entry.id}")
            ) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Dismiss item",
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

private fun getEntryTypeIcon(type: ScheduleEntryType): ImageVector {
    return when (type) {
        ScheduleEntryType.TASK -> Icons.Default.TaskAlt
        ScheduleEntryType.REMINDER -> Icons.Default.Notifications
        ScheduleEntryType.ALARM -> Icons.Default.Alarm
        ScheduleEntryType.CALENDAR_EVENT -> Icons.Default.CalendarMonth
    }
}

@Composable
private fun EmptyScheduleState(
    message: String,
    subtitle: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(60.dp)
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
                imageVector = Icons.Default.Event,
                contentDescription = null,
                tint = SoftTheme.colors.accentBlue.copy(alpha = 0.7f),
                modifier = Modifier.size(28.dp)
            )
        }

        Spacer(modifier = Modifier.height(14.dp))

        Text(
            text = message,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = SoftTheme.colors.textPrimary
        )

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = SoftTheme.colors.textSecondary,
            fontSize = 12.sp
        )
    }
}
