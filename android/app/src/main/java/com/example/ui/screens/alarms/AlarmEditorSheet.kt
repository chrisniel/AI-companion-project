package com.example.ui.screens.alarms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material.icons.filled.Title
import androidx.compose.material.icons.filled.Vibration
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
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import com.example.domain.model.AlarmDay
import com.example.domain.model.MobileAlarm
import com.example.ui.theme.SoftTheme

/**
 * Mobile Alarm Editor (Bottom Sheet).
 * Fields specified in prompt:
 * - title
 * - time
 * - recurrence (day selector)
 * - vibration (switch)
 * - mock sound (preset selector)
 * - enabled state (switch)
 * - PC mirroring (switch)
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun AlarmEditorSheet(
    isOpen: Boolean,
    onDismiss: () -> Unit,
    alarmToEdit: MobileAlarm?,
    onSaveAlarm: (
        title: String,
        time: String,
        recurrenceDays: Set<AlarmDay>,
        vibrate: Boolean,
        soundName: String,
        isEnabled: Boolean,
        pcMirroring: Boolean
    ) -> Unit,
    modifier: Modifier = Modifier
) {
    if (!isOpen) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var title by remember(alarmToEdit) { mutableStateOf(alarmToEdit?.title ?: "Morning Alarm") }
    var time by remember(alarmToEdit) { mutableStateOf(alarmToEdit?.time ?: "07:00 AM") }
    var recurrenceDays by remember(alarmToEdit) {
        mutableStateOf(alarmToEdit?.recurrenceDays ?: setOf(AlarmDay.MON, AlarmDay.TUE, AlarmDay.WED, AlarmDay.THU, AlarmDay.FRI))
    }
    var vibrate by remember(alarmToEdit) { mutableStateOf(alarmToEdit?.vibrate ?: true) }
    var selectedSound by remember(alarmToEdit) { mutableStateOf(alarmToEdit?.soundName ?: "Soft Dawn Synthesizer") }
    var isEnabled by remember(alarmToEdit) { mutableStateOf(alarmToEdit?.isEnabled ?: true) }
    var pcMirroring by remember(alarmToEdit) { mutableStateOf(alarmToEdit?.pcMirroring ?: true) }

    val isEditing = alarmToEdit != null
    val scrollState = rememberScrollState()

    val soundPresets = listOf(
        "Soft Dawn Synthesizer",
        "Gentle Pulse",
        "Ambient Waves",
        "Twilight Harmonic",
        "Resonant Bell"
    )

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
        modifier = modifier.testTag("alarm_editor_sheet")
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
            // HEADER
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = if (isEditing) "Edit Alarm" else "New Alarm",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(32.dp)
                        .testTag("alarm_editor_close_button")
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = SoftTheme.colors.textSecondary,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // 1. TIME FIELD
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "Alarm Time",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary
                )
                OutlinedTextField(
                    value = time,
                    onValueChange = { time = it },
                    placeholder = { Text("e.g. 07:00 AM", color = SoftTheme.colors.textMuted) },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Schedule,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentBlue,
                            modifier = Modifier.size(18.dp)
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
                        .testTag("alarm_input_time")
                )
            }

            // 2. TITLE FIELD
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "Alarm Title",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary
                )
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    placeholder = { Text("e.g. Wakeup, Morning Review", color = SoftTheme.colors.textMuted) },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Title,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentCyan,
                            modifier = Modifier.size(18.dp)
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
                        .testTag("alarm_input_title")
                )
            }

            // 3. RECURRENCE (DAY SELECTOR)
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "Recurrence",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    AlarmDay.entries.forEach { day ->
                        val isDaySelected = recurrenceDays.contains(day)
                        Box(
                            modifier = Modifier
                                .size(38.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isDaySelected) SoftTheme.colors.accentBlue
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = 1.dp,
                                    color = if (isDaySelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                                    shape = CircleShape
                                )
                                .clickable {
                                    recurrenceDays = if (isDaySelected) {
                                        recurrenceDays - day
                                    } else {
                                        recurrenceDays + day
                                    }
                                }
                                .testTag("alarm_day_${day.code.lowercase()}"),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = day.shortLabel,
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                color = if (isDaySelected) Color.White else SoftTheme.colors.textSecondary,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }

            // 4. MOCK SOUND SELECTOR
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Alarm Sound (Mock)",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.textSecondary
                    )
                    Text(
                        text = selectedSound,
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.accentBlue,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    soundPresets.forEach { sound ->
                        val isSoundSelected = selectedSound == sound
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                                .background(
                                    if (isSoundSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.16f)
                                    else SoftTheme.colors.surfaceWell
                                )
                                .border(
                                    width = if (isSoundSelected) 1.5.dp else SoftTheme.tokens.borders.hairline,
                                    color = if (isSoundSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle,
                                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                                )
                                .clickable { selectedSound = sound }
                                .padding(horizontal = 10.dp, vertical = 6.dp)
                                .testTag("alarm_sound_${sound.lowercase().replace(" ", "_")}"),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.MusicNote,
                                contentDescription = null,
                                tint = if (isSoundSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary,
                                modifier = Modifier.size(13.dp)
                            )
                            Text(
                                text = sound,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = if (isSoundSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSoundSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary,
                                fontSize = 11.sp
                            )
                        }
                    }
                }
            }

            // 5. VIBRATION SWITCH
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                    .background(SoftTheme.colors.surfaceWell)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Vibration,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(20.dp)
                    )
                    Column {
                        Text(
                            text = "Vibration",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Haptic pulse pattern during alarm trigger",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textSecondary,
                            fontSize = 11.sp
                        )
                    }
                }
                Switch(
                    checked = vibrate,
                    onCheckedChange = { vibrate = it },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = SoftTheme.colors.accentBlue
                    ),
                    modifier = Modifier.testTag("alarm_switch_vibration")
                )
            }

            // 6. PC MIRRORING SWITCH
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                    .background(SoftTheme.colors.surfaceWell)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Computer,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentCyan,
                        modifier = Modifier.size(20.dp)
                    )
                    Column {
                        Text(
                            text = "PC Mirroring",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Replicate audio & dismissals to Desktop Core",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textSecondary,
                            fontSize = 11.sp
                        )
                    }
                }
                Switch(
                    checked = pcMirroring,
                    onCheckedChange = { pcMirroring = it },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = SoftTheme.colors.accentCyan
                    ),
                    modifier = Modifier.testTag("alarm_switch_pc_mirroring")
                )
            }

            // 7. ENABLED STATE SWITCH
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                    .background(SoftTheme.colors.surfaceWell)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Smartphone,
                        contentDescription = null,
                        tint = if (isEnabled) SoftTheme.colors.statusSuccess else SoftTheme.colors.textMuted,
                        modifier = Modifier.size(20.dp)
                    )
                    Column {
                        Text(
                            text = "Alarm Active / Armed",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = if (isEnabled) "Armed and ready to trigger" else "Currently inactive",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textSecondary,
                            fontSize = 11.sp
                        )
                    }
                }
                Switch(
                    checked = isEnabled,
                    onCheckedChange = { isEnabled = it },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = SoftTheme.colors.statusSuccess
                    ),
                    modifier = Modifier.testTag("alarm_switch_enabled")
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
                        .testTag("alarm_editor_cancel_button"),
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
                        if (title.isNotBlank() && time.isNotBlank()) {
                            onSaveAlarm(
                                title,
                                time,
                                recurrenceDays,
                                vibrate,
                                selectedSound,
                                isEnabled,
                                pcMirroring
                            )
                        }
                    },
                    enabled = title.isNotBlank() && time.isNotBlank(),
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("alarm_editor_save_button"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = SoftTheme.colors.accentBlue,
                        disabledContainerColor = SoftTheme.colors.surfaceWell
                    )
                ) {
                    Text(
                        text = if (isEditing) "Save Alarm" else "Set Alarm",
                        fontWeight = FontWeight.Bold,
                        color = if (title.isNotBlank() && time.isNotBlank()) Color.White else SoftTheme.colors.textMuted
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
