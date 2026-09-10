package com.example.ui.screens.alarms

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.AlarmOff
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.AlarmCapabilityState
import com.example.domain.model.AlarmsUiState
import com.example.domain.model.CapabilityType
import com.example.domain.model.MockPermissionAction
import com.example.ui.components.CapabilityAlertBanner
import com.example.ui.components.MockActionDetailsSheet
import com.example.ui.theme.SoftTheme

/**
 * Mobile Alarms Screen (Batch 6).
 *
 * Major Android feature presenting:
 * - Redundancy Status Card:
 *     Desktop  ● Synchronized
 *     Android  ● Armed
 *     and:
 *     Desktop  ○ Offline
 *     Android  ● Armed Locally
 * - Full Alarm List: time, title, recurrence, enabled state, synchronization state
 * - Alarm Editor (Bottom Sheet) with title, time, recurrence, vibration, mock sound, enabled, PC mirroring
 * - Quick FAB to create alarms
 * - Interactive redundancy failover simulation
 */
@Composable
fun AlarmsScreen(
    modifier: Modifier = Modifier,
    alarmCapabilityState: AlarmCapabilityState = AlarmCapabilityState.READY,
    onSetAlarmCapabilityState: (AlarmCapabilityState) -> Unit = {},
    viewModel: AlarmsViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val alarmToEdit = uiState.alarms.find { it.id == uiState.editingAlarmId }

    var activeMockAction by remember { mutableStateOf<MockPermissionAction?>(null) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(SoftTheme.colors.background)
            .testTag("alarms_screen")
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .testTag("alarms_list"),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 88.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 1. REDUNDANCY & SYNCHRONIZATION STATUS CARD
            item(key = "redundancy_status_card") {
                RedundancyStatusCard(
                    redundancy = uiState.globalRedundancy,
                    onSimulateToggle = { viewModel.toggleRedundancySimulation() }
                )
            }

            // BATCH 13: Never silently fail on Exact Alarm capability restriction
            if (alarmCapabilityState != AlarmCapabilityState.READY) {
                item(key = "alarm_capability_alert") {
                    CapabilityAlertBanner(
                        title = "Alarm Capability: ${alarmCapabilityState.displayName}",
                        explanation = alarmCapabilityState.explanation,
                        onActionClick = { action ->
                            activeMockAction = action
                        },
                        testTag = "alarms_capability_banner"
                    )
                }
            }

            // 2. SECTION HEADER
            item(key = "alarms_section_header") {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp, bottom = 2.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Configured Alarms",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )

                    val armedCount = uiState.alarms.count { it.isEnabled }
                    Text(
                        text = "$armedCount active / ${uiState.alarms.size} total",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.accentBlue,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // 3. ALARMS LIST ITEMS
            if (uiState.alarms.isEmpty()) {
                item(key = "empty_alarms_view") {
                    EmptyAlarmsView()
                }
            } else {
                items(
                    items = uiState.alarms,
                    key = { it.id }
                ) { alarm ->
                    AlarmRowItem(
                        alarm = alarm,
                        onToggleEnabled = { viewModel.toggleAlarmEnabled(alarm.id) },
                        onEdit = { viewModel.openEditEditor(alarm.id) },
                        onDelete = { viewModel.deleteAlarm(alarm.id) }
                    )
                }
            }
        }

        // QUICK ACTION FEEDBACK TOAST / BANNER
        AnimatedVisibility(
            visible = uiState.statusFeedbackMessage != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 84.dp, start = 20.dp, end = 20.dp)
        ) {
            uiState.statusFeedbackMessage?.let { msg ->
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
                        .testTag("alarms_feedback_toast"),
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

        // FLOATING ACTION BUTTON: CREATE ALARM
        FloatingActionButton(
            onClick = { viewModel.openCreateEditor() },
            containerColor = SoftTheme.colors.accentBlue,
            contentColor = Color.White,
            shape = CircleShape,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(bottom = 24.dp, end = 20.dp)
                .testTag("add_alarm_fab")
                .semantics { contentDescription = "Add New Alarm" }
        ) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = null,
                modifier = Modifier.size(24.dp)
            )
        }

        // ALARM EDITOR BOTTOM SHEET
        AlarmEditorSheet(
            isOpen = uiState.isEditorOpen,
            onDismiss = { viewModel.closeEditor() },
            alarmToEdit = alarmToEdit,
            onSaveAlarm = { title, time, recDays, vib, sound, enabled, pcMirror ->
                viewModel.saveAlarm(title, time, recDays, vib, sound, enabled, pcMirror)
            }
        )

        // MOCK ACTION DETAILS SHEET
        MockActionDetailsSheet(
            isOpen = activeMockAction != null,
            action = activeMockAction,
            capabilityType = CapabilityType.ALARMS,
            onDismiss = { activeMockAction = null },
            onSimulateGrant = {
                onSetAlarmCapabilityState(AlarmCapabilityState.READY)
                activeMockAction = null
            }
        )
    }
}

@Composable
private fun EmptyAlarmsView(modifier: Modifier = Modifier) {
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
                imageVector = Icons.Default.AlarmOff,
                contentDescription = null,
                tint = SoftTheme.colors.accentBlue.copy(alpha = 0.7f),
                modifier = Modifier.size(28.dp)
            )
        }

        Spacer(modifier = Modifier.height(14.dp))

        Text(
            text = "No Alarms Configured",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = SoftTheme.colors.textPrimary
        )

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = "Tap the + button to create a resilient synchronized alarm.",
            style = MaterialTheme.typography.bodySmall,
            color = SoftTheme.colors.textSecondary,
            fontSize = 12.sp
        )
    }
}
