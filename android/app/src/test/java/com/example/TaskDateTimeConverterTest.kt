package com.example

import com.example.data.util.TaskDateTimeConverter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.Locale

class TaskDateTimeConverterTest {

    @Test
    fun `toIsoLocal converts Today and 12-00 PM correctly`() {
        val iso = TaskDateTimeConverter.toIsoLocal("Today", "12:00 PM")
        assertNotNull(iso)
        assertTrue(iso!!.endsWith("T12:00:00"))

        val today = Calendar.getInstance()
        val expectedPrefix = String.format(
            Locale.US,
            "%04d-%02d-%02d",
            today.get(Calendar.YEAR),
            today.get(Calendar.MONTH) + 1,
            today.get(Calendar.DAY_OF_MONTH)
        )
        assertTrue(iso.startsWith(expectedPrefix))
    }

    @Test
    fun `toIsoLocal converts Tomorrow and 09-30 AM correctly`() {
        val iso = TaskDateTimeConverter.toIsoLocal("Tomorrow", "09:30 AM")
        assertNotNull(iso)
        assertTrue(iso!!.endsWith("T09:30:00"))

        val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        val expectedPrefix = String.format(
            Locale.US,
            "%04d-%02d-%02d",
            tomorrow.get(Calendar.YEAR),
            tomorrow.get(Calendar.MONTH) + 1,
            tomorrow.get(Calendar.DAY_OF_MONTH)
        )
        assertTrue(iso.startsWith(expectedPrefix))
    }

    @Test
    fun `toIsoLocal converts Next Week and 06-00 PM correctly`() {
        val iso = TaskDateTimeConverter.toIsoLocal("Next Week", "06:00 PM")
        assertNotNull(iso)
        assertTrue(iso!!.endsWith("T18:00:00"))

        val nextWeek = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 7) }
        val expectedPrefix = String.format(
            Locale.US,
            "%04d-%02d-%02d",
            nextWeek.get(Calendar.YEAR),
            nextWeek.get(Calendar.MONTH) + 1,
            nextWeek.get(Calendar.DAY_OF_MONTH)
        )
        assertTrue(iso.startsWith(expectedPrefix))
    }

    @Test
    fun `toIsoLocal converts calendar date and 02-15 PM correctly`() {
        val iso = TaskDateTimeConverter.toIsoLocal("Dec 25, 2026", "02:15 PM")
        assertEquals("2026-12-25T14:15:00", iso)
    }

    @Test
    fun `toIsoLocal returns null on blank or null input`() {
        assertNull(TaskDateTimeConverter.toIsoLocal(null, "12:00 PM"))
        assertNull(TaskDateTimeConverter.toIsoLocal("", "12:00 PM"))
        assertNull(TaskDateTimeConverter.toIsoLocal("   ", "12:00 PM"))
    }

    @Test
    fun `fromIsoToDisplay identifies Today and Tomorrow accurately`() {
        val today = Calendar.getInstance()
        val todayIso = String.format(
            Locale.US,
            "%04d-%02d-%02dT14:30:00",
            today.get(Calendar.YEAR),
            today.get(Calendar.MONTH) + 1,
            today.get(Calendar.DAY_OF_MONTH)
        )
        val (todayDisplay, todayTime) = TaskDateTimeConverter.fromIsoToDisplay(todayIso)
        assertEquals("Today", todayDisplay)
        assertEquals("02:30 PM", todayTime)

        val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        val tomorrowIso = String.format(
            Locale.US,
            "%04d-%02d-%02dT08:15:00Z",
            tomorrow.get(Calendar.YEAR),
            tomorrow.get(Calendar.MONTH) + 1,
            tomorrow.get(Calendar.DAY_OF_MONTH)
        )
        val (tomorrowDisplay, tomorrowTime) = TaskDateTimeConverter.fromIsoToDisplay(tomorrowIso)
        assertEquals("Tomorrow", tomorrowDisplay)
        assertEquals("08:15 AM", tomorrowTime)
    }

    @Test
    fun `fromIsoToDisplay parses distant calendar dates and SQLite format`() {
        val (displayDate, displayTime) = TaskDateTimeConverter.fromIsoToDisplay("2028-11-20 18:45:00.000000")
        assertEquals("Nov 20, 2028", displayDate)
        assertEquals("06:45 PM", displayTime)
    }

    @Test
    fun `reminderToMinutes converts user-facing reminder labels correctly`() {
        assertEquals(0, TaskDateTimeConverter.reminderToMinutes("At due time"))
        assertEquals(15, TaskDateTimeConverter.reminderToMinutes("15m before"))
        assertEquals(60, TaskDateTimeConverter.reminderToMinutes("1h before"))
        assertEquals(1440, TaskDateTimeConverter.reminderToMinutes("1d before"))
        assertNull(TaskDateTimeConverter.reminderToMinutes("None"))
        assertNull(TaskDateTimeConverter.reminderToMinutes(null))
        assertNull(TaskDateTimeConverter.reminderToMinutes(""))
    }

    @Test
    fun `minutesToReminder converts backend minutes into user-facing labels correctly`() {
        assertEquals("At due time", TaskDateTimeConverter.minutesToReminder(0))
        assertEquals("15m before", TaskDateTimeConverter.minutesToReminder(15))
        assertEquals("1h before", TaskDateTimeConverter.minutesToReminder(60))
        assertEquals("1d before", TaskDateTimeConverter.minutesToReminder(1440))
        assertNull(TaskDateTimeConverter.minutesToReminder(null))
    }
}
