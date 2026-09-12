package com.example.ui.screens.alarms

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.DeviceSyncState
import com.example.domain.model.MobileAlarm
import com.example.ui.theme.SoftTheme

/**
 * Mobile Alarm List Item.
 * Displays:
 * - time (large bold typography)
 * - title
 * - recurrence (e.g. Weekdays, Every day)
 * - enabled state (switch)
 * - synchronization state (Desktop / Android sync pill)
 * - vibration & sound indicator
 * - edit & delete actions
 */
@Composable
fun AlarmRowItem(
    alarm: MobileAlarm,
    onToggleEnabled: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val cardBackground = if (alarm.isEnabled) SoftTheme.colors.surfaceElevated else SoftTheme.colors.surfaceWell.copy(alpha = 0.6f)
    val cardBorder = if (alarm.isEnabled) SoftTheme.colors.accentBlue.copy(alpha = 0.35f) else SoftTheme.colors.borderSubtle

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(cardBackground)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = cardBorder,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .clickable(onClick = onEdit)
            .padding(14.dp)
            .testTag("alarm_item_${alarm.id}")
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // TOP ROW: TIME + SWITCH
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = alarm.time,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = if (alarm.isEnabled) SoftTheme.colors.textPrimary else SoftTheme.colors.textMuted,
                        fontSize = 28.sp
                    )
                    Text(
                        text = alarm.title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = if (alarm.isEnabled) SoftTheme.colors.textSecondary else SoftTheme.colors.textMuted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // ENABLED TOGGLE SWITCH
                Switch(
                    checked = alarm.isEnabled,
                    onCheckedChange = { onToggleEnabled() },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = SoftTheme.colors.accentBlue,
                        uncheckedThumbColor = SoftTheme.colors.textMuted,
                        uncheckedTrackColor = SoftTheme.colors.surfaceWell
                    ),
                    modifier = Modifier
                        .testTag("alarm_toggle_${alarm.id}")
                        .semantics {
                            contentDescription = "${alarm.title} alarm toggle, currently ${if (alarm.isEnabled) "on" else "off"}"
                        }
                )
            }

            // MIDDLE ROW: RECURRENCE, SOUND, VIBRATION PILLS
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Recurrence
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(SoftTheme.colors.surfaceWell)
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Repeat,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = alarm.recurrenceLabel,
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium
                    )
                }

                // Sound
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(SoftTheme.colors.surfaceWell)
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.MusicNote,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentCyan,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = alarm.soundName,
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textSecondary,
                        fontSize = 10.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                if (alarm.vibrate) {
                    Icon(
                        imageVector = Icons.Default.Vibration,
                        contentDescription = "Vibrate enabled",
                        tint = SoftTheme.colors.textMuted,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }

            // BOTTOM ROW: SYNCHRONIZATION STATE + ACTIONS
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // SYNCHRONIZATION STATE BADGE
                AlarmSyncBadge(
                    desktopSyncState = alarm.desktopSyncState,
                    androidArmedState = alarm.androidArmedState,
                    pcMirroring = alarm.pcMirroring
                )

                // ACTIONS (Edit & Delete)
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = onEdit,
                        modifier = Modifier
                            .size(32.dp)
                            .testTag("alarm_edit_${alarm.id}")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Edit,
                            contentDescription = "Edit Alarm",
                            tint = SoftTheme.colors.textSecondary,
                            modifier = Modifier.size(16.dp)
                        )
                    }

                    IconButton(
                        onClick = onDelete,
                        modifier = Modifier
                            .size(32.dp)
                            .testTag("alarm_delete_${alarm.id}")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = "Delete Alarm",
                            tint = SoftTheme.colors.textMuted,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }
    }
}

/**
 * Synchronization state indicator badge for each alarm row.
 */
@Composable
fun AlarmSyncBadge(
    desktopSyncState: DeviceSyncState,
    androidArmedState: DeviceSyncState,
    pcMirroring: Boolean,
    modifier: Modifier = Modifier
) {
    val isSynced = pcMirroring && desktopSyncState == DeviceSyncState.SYNCHRONIZED
    val syncColor = if (isSynced) SoftTheme.colors.statusSuccess else SoftTheme.colors.textMuted

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(syncColor.copy(alpha = 0.12f))
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = syncColor.copy(alpha = 0.3f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        // Dot indicator
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(syncColor)
        )
        Text(
            text = if (isSynced) "Desktop & Android Synced" else "Android Armed Locally",
            style = MaterialTheme.typography.labelSmall,
            color = syncColor,
            fontWeight = FontWeight.SemiBold,
            fontSize = 10.sp
        )
    }
}
