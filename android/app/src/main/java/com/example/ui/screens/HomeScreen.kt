package com.example.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material3.HorizontalDivider
import androidx.compose.ui.layout.layout
import androidx.compose.ui.zIndex
import com.example.ui.components.softBounceOverscroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.automirrored.filled.EventNote
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PriorityHigh
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.HomeData
import com.example.domain.model.LanguageOption
import com.example.domain.model.NextScheduleItem
import com.example.domain.model.ScheduleItemType
import com.example.domain.model.StatusSeverity
import com.example.domain.model.TaskPreviewItem
import com.example.domain.model.TodaySummary
import com.example.domain.model.UserProfile
import com.example.domain.model.WellnessGlance
import com.example.navigation.Routes
import com.example.ui.components.CompactConnectionIndicator
import com.example.ui.components.InteractiveSoftGlassCard
import com.example.ui.components.InteractiveSoftWell
import com.example.ui.components.PrimaryButton
import com.example.ui.components.SecondaryButton
import com.example.ui.components.SoftAvatar
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.SoftWell
import com.example.ui.components.StatusBadge
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme
import kotlinx.coroutines.launch
import java.util.Calendar

/**
 * Mobile Home Screen (Batch 3):
 * Immediately answers:
 * 1. Is the Local AI Core reachable?
 * 2. What is next?
 * 3. What do I need to do today?
 * 4. Is anything important happening?
 * 5. What is my current wellness summary?
 *
 * Adheres strictly to Soft Glass styling, tactile controls, contextual greeting,
 * prominent but calm assistant hero, next event/alarm with countdown, today focus,
 * compact wellness glance, and 4 large mobile-friendly quick actions.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    homeData: HomeData,
    connectionInfo: ConnectionInfo,
    selectedPersona: String,
    onSelectPersona: (String) -> Unit,
    onNavigateToRoute: (String) -> Unit,
    onToggleTask: (String) -> Unit,
    onAddTask: (title: String, priority: String) -> Unit,
    onAvatarClick: () -> Unit = {},
    selectedLanguage: LanguageOption = LanguageOption.AUTO,
    onSelectLanguage: (LanguageOption) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()
    var showAddTaskSheet by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .testTag("home_screen")
            .softBounceOverscroll()
            .verticalScroll(scrollState)
            .statusBarsPadding()
            .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.sm),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.lg)
    ) {
        // 1. CONTEXTUAL PROFILE GREETING HEADER (Never hardcoded)
        HomeHeaderGreeting(
            profile = homeData.profile,
            isReachable = connectionInfo.state == CoreConnectionState.Local || connectionInfo.state == CoreConnectionState.Remote,
            activeModelName = selectedPersona,
            onAvatarClick = onAvatarClick,
            modifier = Modifier.fillMaxWidth()
        )

        // 2. ASSISTANT HERO (Calm, prominent, active character, reachability, model summary, no loud telemetry)
        HomeAssistantHero(
            personaName = selectedPersona,
            assistantState = homeData.assistantStateText,
            connectionInfo = connectionInfo,
            modelSummary = homeData.activeModelSummary,
            selectedLanguage = selectedLanguage,
            onSelectLanguage = onSelectLanguage,
            onSelectPersona = onSelectPersona,
            onCardClick = { onNavigateToRoute(Routes.ASSISTANT) }
        )

        // 3. QUICK ACTIONS (Four large tactile mobile-friendly actions)
        HomeQuickActionsGrid(
            onAskClick = { onNavigateToRoute(Routes.ASSISTANT) },
            onAddTaskClick = { showAddTaskSheet = true },
            onAlarmClick = { onNavigateToRoute(Routes.ALARMS) },
            onReminderClick = { onNavigateToRoute(Routes.SCHEDULE) }
        )

        // 4. NEXT UP (Next reminder/event/alarm with scheduled time & countdown)
        HomeNextSection(
            nextItem = homeData.nextItem,
            onClick = {
                when (homeData.nextItem.type) {
                    ScheduleItemType.ALARM -> onNavigateToRoute(Routes.ALARMS)
                    ScheduleItemType.EVENT, ScheduleItemType.REMINDER -> onNavigateToRoute(Routes.SCHEDULE)
                }
            }
        )

        // 5. TODAY (Open tasks, completed count, active reminders, interactive checks)
        HomeTodaySection(
            todaySummary = homeData.todaySummary,
            onToggleTask = onToggleTask,
            onViewAllTasks = { onNavigateToRoute(Routes.TASKS) },
            onAddNewTask = { showAddTaskSheet = true }
        )

        // 6. WELLNESS (Compact summaries: sleep, heart rate, steps/activity)
        HomeWellnessSection(
            wellness = homeData.wellness,
            onClick = { onNavigateToRoute(Routes.HEALTH) }
        )

        Spacer(modifier = Modifier.height(SoftTheme.spacing.md))
    }

    // Modal Bottom Sheet for Quick Add Task
    if (showAddTaskSheet) {
        QuickAddTaskBottomSheet(
            onDismiss = { showAddTaskSheet = false },
            onAddTask = { title, priority ->
                onAddTask(title, priority)
                showAddTaskSheet = false
            },
            onNavigateToTasks = {
                showAddTaskSheet = false
                onNavigateToRoute(Routes.TASKS)
            }
        )
    }
}

/**
 * 1. Contextual Greeting Header:
 * Computes greeting time (Morning, Afternoon, Evening) and greets user by profile name.
 */
@Composable
private fun HomeHeaderGreeting(
    profile: UserProfile,
    isReachable: Boolean,
    activeModelName: String = "Aura",
    onAvatarClick: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val greetingTime = remember {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        when (hour) {
            in 5..11 -> "Good morning"
            in 12..16 -> "Good afternoon"
            else -> "Good evening"
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .testTag("home_header_greeting")
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (profile.name.isNotBlank() && profile.name != "User") "$greetingTime, ${profile.name}" else greetingTime,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                Spacer(modifier = Modifier.height(2.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(
                                if (isReachable) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning
                            )
                    )
                    Text(
                        text = if (isReachable) "$activeModelName is online" else "Offline Mode active",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }
            }

            Box(
                modifier = Modifier
                    .testTag("home_user_avatar")
                    .clip(CircleShape)
                    .clickable(
                        role = Role.Button,
                        onClickLabel = "Open Profile and Vault Status"
                    ) {
                        onAvatarClick()
                    }
            ) {
                SoftAvatar(
                    name = profile.name,
                    size = 40.dp,
                    statusColor = null
                )
            }
        }
    }
}

/**
 * 2. Assistant Hero Area:
 * Calm, elegant soft glass hero with active character avatar, assistant status,
 * reachability badge, and current model summary.
 */
@Composable
private fun HomeAssistantHero(
    personaName: String,
    assistantState: String,
    connectionInfo: ConnectionInfo,
    modelSummary: String,
    selectedLanguage: LanguageOption,
    onSelectLanguage: (LanguageOption) -> Unit,
    onSelectPersona: (String) -> Unit,
    onCardClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isReachable = connectionInfo.state == CoreConnectionState.Local || connectionInfo.state == CoreConnectionState.Remote
    var isLangDropdownOpen by remember { mutableStateOf(false) }

    InteractiveSoftGlassCard(
        onClick = onCardClick,
        elevation = SoftTheme.tokens.elevations.card,
        testTag = "home_assistant_hero",
        modifier = modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.md),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            // Top Meta Row: Core status + Language selector dropdown
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Online core status indicator
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(
                            if (isReachable) SoftTheme.colors.statusSuccess.copy(alpha = 0.12f)
                            else SoftTheme.colors.statusWarning.copy(alpha = 0.12f)
                        )
                        .border(
                            width = SoftTheme.tokens.borders.hairline,
                            color = if (isReachable) SoftTheme.colors.statusSuccess.copy(alpha = 0.35f)
                            else SoftTheme.colors.statusWarning.copy(alpha = 0.35f),
                            shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(
                                if (isReachable) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning
                            )
                    )
                    Text(
                        text = if (isReachable) "Core Online • Direct LAN" else "Core Offline • Local Only",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        fontWeight = FontWeight.Bold,
                        color = if (isReachable) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning
                    )
                }

                // Compact Language Dropdown Pill
                Box {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.surfaceElevated)
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = SoftTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .clickable { isLangDropdownOpen = true }
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            val flagLabel = when (selectedLanguage) {
                                LanguageOption.AUTO -> "🌐 Auto"
                                LanguageOption.ENGLISH -> "🇺🇸 English"
                                LanguageOption.FILIPINO -> "🇵🇭 Filipino"
                                LanguageOption.JAPANESE -> "🇯🇵 Japanese"
                            }
                            Text(
                                text = flagLabel,
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                                fontWeight = FontWeight.Bold,
                                color = SoftTheme.colors.accentPrimaryColor
                            )
                            Icon(
                                imageVector = Icons.Default.ArrowDropDown,
                                contentDescription = "Select language",
                                tint = SoftTheme.colors.textMuted,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }

                    DropdownMenu(
                        expanded = isLangDropdownOpen,
                        onDismissRequest = { isLangDropdownOpen = false },
                        modifier = Modifier.background(SoftTheme.colors.surfaceElevated)
                    ) {
                        listOf(
                            LanguageOption.AUTO to "🌐 Auto (Detect)",
                            LanguageOption.ENGLISH to "🇺🇸 English (US)",
                            LanguageOption.FILIPINO to "🇵🇭 Filipino (Tagalog)",
                            LanguageOption.JAPANESE to "🇯🇵 Japanese (日本語)"
                        ).forEach { (opt, label) ->
                            val isCurrent = selectedLanguage == opt
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        text = label,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal,
                                        color = if (isCurrent) SoftTheme.colors.accentPrimaryColor else SoftTheme.colors.textPrimary
                                    )
                                },
                                onClick = {
                                    onSelectLanguage(opt)
                                    isLangDropdownOpen = false
                                }
                            )
                        }
                    }
                }
            }

            // Character Info & Reachability Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Calm glowing avatar
                SoftAvatar(
                    name = personaName,
                    size = 52.dp,
                    icon = Icons.Default.AutoAwesome,
                    statusColor = if (isReachable) SoftTheme.colors.statusSuccess else SoftTheme.colors.statusWarning,
                    testTag = "home_assistant_avatar"
                )

                Spacer(modifier = Modifier.width(SoftTheme.spacing.md))

                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                    ) {
                        Text(
                            text = personaName,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )

                        // Reachability Status Badge
                        StatusBadge(
                            text = when (connectionInfo.state) {
                                CoreConnectionState.Local -> "LOCAL"
                                CoreConnectionState.Remote -> "REMOTE"
                                CoreConnectionState.Connecting -> "CONNECTING"
                                CoreConnectionState.Reconnecting -> "RECONNECTING"
                                CoreConnectionState.Offline -> "OFFLINE"
                            },
                            severity = when (connectionInfo.state) {
                                CoreConnectionState.Local -> StatusSeverity.Success
                                CoreConnectionState.Remote -> StatusSeverity.Info
                                CoreConnectionState.Connecting -> StatusSeverity.Warning
                                CoreConnectionState.Reconnecting -> StatusSeverity.Warning
                                CoreConnectionState.Offline -> StatusSeverity.Normal
                            },
                            hasDot = true,
                            testTag = "home_reachability_status"
                        )
                    }

                    Spacer(modifier = Modifier.height(2.dp))

                    Text(
                        text = "Assistant: $assistantState",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }

                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = "Open dialogue",
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(20.dp)
                )
            }

            // Sunken Neumorphic Well for Model Summary
            SoftWell(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.CenterStart
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = SoftTheme.spacing.sm, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(SoftTheme.colors.accentBlue)
                    )
                    Text(
                        text = modelSummary,
                        style = MonospaceTelemetry.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.accentBlue,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}

/**
 * 3. Quick Actions:
 * Four large tactile mobile-friendly action buttons with hero text typography.
 */
@Composable
private fun HomeQuickActionsGrid(
    onAskClick: () -> Unit,
    onAddTaskClick: () -> Unit,
    onAlarmClick: () -> Unit,
    onReminderClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            QuickActionButton(
                title = "Ask",
                subtitle = "Local AI Chat",
                accentColor = SoftTheme.colors.accentBlue,
                testTag = "home_quick_action_ask",
                onClick = onAskClick,
                modifier = Modifier.weight(1f)
            )

            QuickActionButton(
                title = "Add Task",
                subtitle = "New To-Do",
                accentColor = SoftTheme.colors.accentCyan,
                testTag = "home_quick_action_add_task",
                onClick = onAddTaskClick,
                modifier = Modifier.weight(1f)
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            QuickActionButton(
                title = "Alarm",
                subtitle = "Smart Circadian",
                accentColor = SoftTheme.colors.accentAmber,
                testTag = "home_quick_action_alarm",
                onClick = onAlarmClick,
                modifier = Modifier.weight(1f)
            )

            QuickActionButton(
                title = "Reminder",
                subtitle = "Schedule & Alert",
                accentColor = SoftTheme.colors.accentViolet,
                testTag = "home_quick_action_reminder",
                onClick = onReminderClick,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun QuickActionButton(
    title: String,
    subtitle: String,
    accentColor: Color,
    testTag: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    InteractiveSoftGlassCard(
        onClick = onClick,
        elevation = SoftTheme.tokens.elevations.subtle,
        testTag = testTag,
        modifier = modifier.height(72.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.Start
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium.copy(fontSize = 17.sp),
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textPrimary,
                maxLines = 1
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                color = SoftTheme.colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

/**
 * 4. Next Up Section:
 * Answers "What is next?" and "Is anything important happening?"
 * Displays next reminder/event/alarm, scheduled time, and countdown.
 */
@Composable
private fun HomeNextSection(
    nextItem: NextScheduleItem,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("home_next_section"),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "NEXT UP",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.accentBlue
            )

            if (nextItem.isImportant) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.PriorityHigh,
                        contentDescription = "Important",
                        tint = SoftTheme.colors.statusWarning,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = "Important Event",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.statusWarning
                    )
                }
            }
        }

        InteractiveSoftGlassCard(
            onClick = onClick,
            elevation = SoftTheme.tokens.elevations.card,
            testTag = "home_next_card",
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                // Top row with item countdown and status
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = when (nextItem.type) {
                            ScheduleItemType.EVENT -> "CALENDAR SYNC"
                            ScheduleItemType.ALARM -> "CIRCADIAN ALARM"
                            ScheduleItemType.REMINDER -> "SCHEDULED ACTION"
                        },
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontSize = 10.sp,
                            letterSpacing = 1.sp
                        ),
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.accentBlue
                    )

                    // Countdown Pill
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.accentBlue.copy(alpha = 0.12f))
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = SoftTheme.colors.accentBlue.copy(alpha = 0.35f),
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = nextItem.countdown,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.accentBlue
                        )
                    }
                }

                // Sunken Debossed Container for the Focus Block
                SoftWell(
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(SoftTheme.spacing.md),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
                    ) {
                        // Type icon
                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                                .background(
                                    when (nextItem.type) {
                                        ScheduleItemType.EVENT -> SoftTheme.colors.accentBlue.copy(alpha = 0.15f)
                                        ScheduleItemType.ALARM -> SoftTheme.colors.accentAmber.copy(alpha = 0.15f)
                                        ScheduleItemType.REMINDER -> SoftTheme.colors.accentViolet.copy(alpha = 0.15f)
                                    }
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = when (nextItem.type) {
                                    ScheduleItemType.EVENT -> Icons.Default.Event
                                    ScheduleItemType.ALARM -> Icons.Default.Alarm
                                    ScheduleItemType.REMINDER -> Icons.Default.Notifications
                                },
                                contentDescription = null,
                                tint = when (nextItem.type) {
                                    ScheduleItemType.EVENT -> SoftTheme.colors.accentBlue
                                    ScheduleItemType.ALARM -> SoftTheme.colors.accentAmber
                                    ScheduleItemType.REMINDER -> SoftTheme.colors.accentViolet
                                },
                                modifier = Modifier.size(24.dp)
                            )
                        }

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = nextItem.title,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = SoftTheme.colors.textPrimary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.AccessTime,
                                    contentDescription = null,
                                    tint = SoftTheme.colors.textMuted,
                                    modifier = Modifier.size(13.dp)
                                )
                                Text(
                                    text = "${nextItem.scheduledTime} • ${nextItem.locationOrDetail ?: "Scheduled"}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = SoftTheme.colors.textSecondary
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 5. Today Section:
 * Answers "What do I need to do today?"
 * Displays open tasks with interactive checkboxes, completed count, and reminder tally.
 */
@Composable
private fun HomeTodaySection(
    todaySummary: TodaySummary,
    onToggleTask: (String) -> Unit,
    onViewAllTasks: () -> Unit,
    onAddNewTask: () -> Unit,
    modifier: Modifier = Modifier
) {
    val progress = if (todaySummary.totalCount > 0) {
        todaySummary.completedCount.toFloat() / todaySummary.totalCount.toFloat()
    } else 0f

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("home_today_section"),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "TODAY'S WORKFLOW",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.accentBlue
            )

            Text(
                text = "${todaySummary.remindersCount} active reminders",
                style = MaterialTheme.typography.labelSmall,
                color = SoftTheme.colors.textMuted
            )
        }

        SoftGlassCard(
            elevation = SoftTheme.tokens.elevations.card,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.md),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                // Header row: Tasks status & progress
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "${todaySummary.completedCount} of ${todaySummary.totalCount} completed",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "${todaySummary.openTasks.size} tasks pending local action",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textSecondary
                        )
                    }

                    StatusBadge(
                        text = "${(progress * 100).toInt()}% Done",
                        severity = if (progress >= 0.8f) StatusSeverity.Success else StatusSeverity.Info,
                        hasDot = false
                    )
                }

                // Progress Bar
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill)),
                    color = SoftTheme.colors.accentCyan,
                    trackColor = SoftTheme.colors.surfacePressed
                )

                Spacer(modifier = Modifier.height(2.dp))

                // Open Task Items Preview with Interactive Checkboxes
                if (todaySummary.openTasks.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = SoftTheme.spacing.md),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                        ) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = SoftTheme.colors.statusSuccess,
                                modifier = Modifier.size(18.dp)
                            )
                            Text(
                                text = "All tasks completed for today!",
                                style = MaterialTheme.typography.bodyMedium,
                                color = SoftTheme.colors.textSecondary
                            )
                        }
                    }
                } else {
                    todaySummary.openTasks.take(3).forEach { task ->
                        HomeTaskItemRow(
                            task = task,
                            onToggle = { onToggleTask(task.id) }
                        )
                    }
                }

                // Bottom actions: View All Tasks & Quick Add
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Open full tasks manager",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.accentBlue,
                        modifier = Modifier
                            .clickable(role = Role.Button, onClick = onViewAllTasks)
                            .padding(vertical = 4.dp)
                    )

                    IconButton(
                        onClick = onAddNewTask,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "Add Task",
                            tint = SoftTheme.colors.accentCyan,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeTaskItemRow(
    task: TaskPreviewItem,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    InteractiveSoftWell(
        onClick = onToggle,
        shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
        modifier = modifier
            .fillMaxWidth()
            .testTag("home_task_item_${task.id}")
            .semantics {
                this.role = Role.Checkbox
            }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.md, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            Icon(
                imageVector = if (task.isCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                contentDescription = if (task.isCompleted) "Completed" else "Incomplete",
                tint = if (task.isCompleted) SoftTheme.colors.statusSuccess else SoftTheme.colors.textMuted,
                modifier = Modifier.size(22.dp)
            )

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = task.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = if (task.isCompleted) SoftTheme.colors.textMuted else SoftTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                if (task.dueTime != null) {
                    Text(
                        text = "Due ${task.dueTime}",
                        style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                        color = SoftTheme.colors.textMuted
                    )
                }
            }

            if (task.priority == "High") {
                StatusBadge(
                    text = "HIGH",
                    severity = StatusSeverity.Warning,
                    hasDot = false
                )
            }
        }
    }
}

/**
 * 6. Wellness Section:
 * Answers "What is my current wellness summary?"
 * Displays compact summaries for sleep, heart rate, and steps/activity.
 * Never overloads Home with multi-series charts.
 */
@Composable
private fun HomeWellnessSection(
    wellness: WellnessGlance,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("home_wellness_section"),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "WELLNESS SUMMARY",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.accentBlue
            )

            Text(
                text = "Sync: Biometric Ring",
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                color = SoftTheme.colors.textMuted
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            // Sleep Card
            WellnessGlanceCard(
                icon = Icons.Default.Bedtime,
                title = "Sleep",
                mainValue = wellness.sleepDuration,
                subtitle = "${wellness.sleepQualityScore} score",
                accentColor = SoftTheme.colors.accentViolet,
                testTag = "home_wellness_sleep",
                onClick = onClick,
                modifier = Modifier.weight(1f)
            )

            // Heart Rate Card
            WellnessGlanceCard(
                icon = Icons.Default.Favorite,
                title = "Heart Rate",
                mainValue = "${wellness.heartRateBpm} BPM",
                subtitle = "Resting",
                accentColor = SoftTheme.colors.accentAmber,
                testTag = "home_wellness_heart",
                onClick = onClick,
                modifier = Modifier.weight(1f)
            )

            // Steps / Activity Card
            WellnessGlanceCard(
                icon = Icons.AutoMirrored.Filled.DirectionsWalk,
                title = "Activity",
                mainValue = "${wellness.stepsCount}",
                subtitle = "${((wellness.stepsCount.toFloat() / wellness.stepsGoal) * 100).toInt()}% goal",
                accentColor = SoftTheme.colors.accentCyan,
                testTag = "home_wellness_steps",
                onClick = onClick,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun WellnessGlanceCard(
    icon: ImageVector,
    title: String,
    mainValue: String,
    subtitle: String,
    accentColor: Color,
    testTag: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    InteractiveSoftGlassCard(
        onClick = onClick,
        elevation = SoftTheme.tokens.elevations.subtle,
        testTag = testTag,
        modifier = modifier.height(110.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(SoftTheme.spacing.sm),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textMuted,
                    maxLines = 1
                )
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = accentColor,
                    modifier = Modifier.size(20.dp)
                )
            }

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = mainValue,
                    style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp),
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary,
                    maxLines = 1
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 11.sp),
                    color = SoftTheme.colors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/**
 * Quick Add Task Modal Bottom Sheet:
 * Tactile Soft UI bottom sheet for creating local tasks on the fly.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun QuickAddTaskBottomSheet(
    onDismiss: () -> Unit,
    onAddTask: (title: String, priority: String) -> Unit,
    onNavigateToTasks: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val coroutineScope = rememberCoroutineScope()
    var taskTitle by remember { mutableStateOf("") }
    var selectedPriority by remember { mutableStateOf("Normal") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.navSurface,
        shape = RoundedCornerShape(topStart = SoftTheme.tokens.corners.xl, topEnd = SoftTheme.tokens.corners.xl)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.lg)
                .padding(bottom = SoftTheme.spacing.xl),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            Text(
                text = "Add Local Task",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textPrimary
            )

            OutlinedTextField(
                value = taskTitle,
                onValueChange = { taskTitle = it },
                label = { Text("Task description") },
                placeholder = { Text("e.g. Review morning agenda") },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("quick_add_task_input"),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = SoftTheme.colors.accentCyan,
                    unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                    focusedTextColor = SoftTheme.colors.textPrimary,
                    unfocusedTextColor = SoftTheme.colors.textPrimary
                ),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )

            // Priority Selector
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Text(
                    text = "Priority:",
                    style = MaterialTheme.typography.bodyMedium,
                    color = SoftTheme.colors.textSecondary
                )
                listOf("Normal", "High").forEach { priority ->
                    val isSelected = selectedPriority == priority
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(
                                if (isSelected) SoftTheme.colors.accentCyan.copy(alpha = 0.2f)
                                else SoftTheme.colors.surfacePressed
                            )
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .clickable { selectedPriority = priority }
                            .padding(horizontal = SoftTheme.spacing.md, vertical = 6.dp)
                    ) {
                        Text(
                            text = priority,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                            color = if (isSelected) SoftTheme.colors.accentCyan else SoftTheme.colors.textSecondary
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))

            PrimaryButton(
                text = "Save Task",
                onClick = {
                    if (taskTitle.isNotBlank()) {
                        coroutineScope.launch {
                            sheetState.hide()
                            onAddTask(taskTitle.trim(), selectedPriority)
                        }
                    }
                },
                enabled = taskTitle.isNotBlank(),
                leadingIcon = Icons.Default.Check,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("quick_add_task_submit")
            )

            SecondaryButton(
                text = "Open Full Tasks Hub",
                onClick = {
                    coroutineScope.launch {
                        sheetState.hide()
                        onNavigateToTasks()
                    }
                },
                leadingIcon = Icons.Default.TaskAlt,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
