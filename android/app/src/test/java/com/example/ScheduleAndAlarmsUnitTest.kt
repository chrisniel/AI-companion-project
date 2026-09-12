package com.example

import com.example.domain.model.AlarmDay
import com.example.domain.model.DeviceSyncState
import com.example.domain.model.ScheduleEntryType
import com.example.domain.model.ScheduleViewMode
import com.example.ui.screens.alarms.AlarmsViewModel
import com.example.ui.screens.schedule.ScheduleViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for Batch 6: Mobile Schedule and Alarms.
 * Verifies:
 * - Schedule views (Day, Agenda, Week)
 * - Schedule supported items (task, reminder, alarm, calendar event)
 * - Alarm list fields (time, title, recurrence, enabled state, synchronization state)
 * - Alarm editor fields (title, time, recurrence, vibration, mock sound, enabled state, PC mirroring)
 * - Redundancy status display ("Desktop ● Synchronized", "Android ● Armed", "Desktop ○ Offline", "Android ● Armed Locally")
 */
class ScheduleAndAlarmsUnitTest {

    @Test
    fun `schedule view supports Day, Agenda, and Week views`() {
        val viewModel = ScheduleViewModel()
        assertEquals(ScheduleViewMode.DAY, viewModel.uiState.value.selectedViewMode)

        viewModel.selectViewMode(ScheduleViewMode.AGENDA)
        assertEquals(ScheduleViewMode.AGENDA, viewModel.uiState.value.selectedViewMode)

        viewModel.selectViewMode(ScheduleViewMode.WEEK)
        assertEquals(ScheduleViewMode.WEEK, viewModel.uiState.value.selectedViewMode)
    }

    @Test
    fun `schedule entries support task, reminder, alarm, and calendar event`() {
        val viewModel = ScheduleViewModel()
        val entries = viewModel.uiState.value.entries

        val hasTask = entries.any { it.type == ScheduleEntryType.TASK }
        val hasReminder = entries.any { it.type == ScheduleEntryType.REMINDER }
        val hasAlarm = entries.any { it.type == ScheduleEntryType.ALARM }
        val hasCalendarEvent = entries.any { it.type == ScheduleEntryType.CALENDAR_EVENT }

        assertTrue("Schedule must include task items", hasTask)
        assertTrue("Schedule must include reminder items", hasReminder)
        assertTrue("Schedule must include alarm items", hasAlarm)
        assertTrue("Schedule must include calendar event items", hasCalendarEvent)
    }

    @Test
    fun `schedule toggle complete and dismiss updates entry state`() {
        val viewModel = ScheduleViewModel()
        val targetTask = viewModel.uiState.value.entries.first { it.type == ScheduleEntryType.TASK }
        val targetId = targetTask.id

        assertFalse(targetTask.isCompleted)
        viewModel.toggleComplete(targetId)

        val completed = viewModel.uiState.value.entries.first { it.id == targetId }
        assertTrue(completed.isCompleted)

        // Dismiss
        viewModel.dismissEntry(targetId)
        assertNull(viewModel.uiState.value.entries.find { it.id == targetId })
    }

    @Test
    fun `alarms list shows time, title, recurrence, enabled state, and sync state`() {
        val viewModel = AlarmsViewModel()
        val alarms = viewModel.uiState.value.alarms
        assertTrue(alarms.isNotEmpty())

        val primaryAlarm = alarms.first { it.title == "Primary Wakeup" }
        assertEquals("07:00 AM", primaryAlarm.time)
        assertEquals("Weekdays", primaryAlarm.recurrenceLabel)
        assertTrue(primaryAlarm.isEnabled)
        assertTrue(primaryAlarm.pcMirroring)
        assertEquals(DeviceSyncState.SYNCHRONIZED, primaryAlarm.desktopSyncState)
        assertEquals(DeviceSyncState.ARMED_LOCALLY, primaryAlarm.androidArmedState)
        assertEquals("Soft Dawn Synthesizer", primaryAlarm.soundName)
        assertTrue(primaryAlarm.vibrate)
    }

    @Test
    fun `alarm editor creates new alarm with all required fields`() {
        val viewModel = AlarmsViewModel()
        val initialCount = viewModel.uiState.value.alarms.size

        viewModel.openCreateEditor()
        assertTrue(viewModel.uiState.value.isEditorOpen)
        assertNull(viewModel.uiState.value.editingAlarmId)

        viewModel.saveAlarm(
            title = "Autonomous Sync Alarm",
            time = "06:15 AM",
            recurrenceDays = setOf(AlarmDay.MON, AlarmDay.WED, AlarmDay.FRI),
            vibrate = true,
            soundName = "Gentle Pulse",
            isEnabled = true,
            pcMirroring = true
        )

        assertFalse(viewModel.uiState.value.isEditorOpen)
        assertEquals(initialCount + 1, viewModel.uiState.value.alarms.size)

        val created = viewModel.uiState.value.alarms.first()
        assertEquals("Autonomous Sync Alarm", created.title)
        assertEquals("06:15 AM", created.time)
        assertEquals("Mon, Wed, Fri", created.recurrenceLabel)
        assertTrue(created.isEnabled)
        assertTrue(created.vibrate)
        assertEquals("Gentle Pulse", created.soundName)
        assertTrue(created.pcMirroring)
        assertEquals(DeviceSyncState.SYNCHRONIZED, created.desktopSyncState)
        assertEquals(DeviceSyncState.ARMED_LOCALLY, created.androidArmedState)
    }

    @Test
    fun `alarm editor updates existing alarm`() {
        val viewModel = AlarmsViewModel()
        val target = viewModel.uiState.value.alarms.first()

        viewModel.openEditEditor(target.id)
        assertTrue(viewModel.uiState.value.isEditorOpen)
        assertEquals(target.id, viewModel.uiState.value.editingAlarmId)

        viewModel.saveAlarm(
            title = "Updated Alarm Title",
            time = "08:00 AM",
            recurrenceDays = setOf(AlarmDay.SAT, AlarmDay.SUN),
            vibrate = false,
            soundName = "Ambient Waves",
            isEnabled = false,
            pcMirroring = false
        )

        assertFalse(viewModel.uiState.value.isEditorOpen)
        val edited = viewModel.uiState.value.alarms.first { it.id == target.id }
        assertEquals("Updated Alarm Title", edited.title)
        assertEquals("08:00 AM", edited.time)
        assertEquals("Weekends", edited.recurrenceLabel)
        assertFalse(edited.isEnabled)
        assertFalse(edited.vibrate)
        assertEquals("Ambient Waves", edited.soundName)
        assertFalse(edited.pcMirroring)
        assertEquals(DeviceSyncState.OFFLINE, edited.desktopSyncState)
    }

    @Test
    fun `redundancy status card toggles between Synchronized and Offline states`() {
        val viewModel = AlarmsViewModel()
        val initialRedundancy = viewModel.uiState.value.globalRedundancy

        // State 1: Desktop Synchronized, Android Armed Locally
        assertEquals(DeviceSyncState.SYNCHRONIZED, initialRedundancy.desktopStatus)
        assertEquals(DeviceSyncState.ARMED_LOCALLY, initialRedundancy.androidStatus)

        // Toggle failover / simulation
        viewModel.toggleRedundancySimulation()
        val failoverRedundancy = viewModel.uiState.value.globalRedundancy

        // State 2: Desktop Offline, Android Armed Locally
        assertEquals(DeviceSyncState.OFFLINE, failoverRedundancy.desktopStatus)
        assertEquals(DeviceSyncState.ARMED_LOCALLY, failoverRedundancy.androidStatus)

        // Toggle back
        viewModel.toggleRedundancySimulation()
        val restoredRedundancy = viewModel.uiState.value.globalRedundancy
        assertEquals(DeviceSyncState.SYNCHRONIZED, restoredRedundancy.desktopStatus)
    }
}
