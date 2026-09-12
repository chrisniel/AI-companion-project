package com.example.data.util

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Utility for converting mobile task dates & times between user-friendly display labels
 * ("Today", "Tomorrow", "Next Week", "12:00 PM") and ISO-8601 strings ("YYYY-MM-DDTHH:MM:SS")
 * required by the backend and SQLite database.
 */
object TaskDateTimeConverter {

    private val DATE_FORMATS = listOf(
        "MMM dd, yyyy",
        "MMMM dd, yyyy",
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "dd/MM/yyyy"
    )

    /**
     * Converts a mobile dueDate label and optional dueTime into an ISO-8601 string ("YYYY-MM-DDTHH:MM:SS").
     * Returns null if dueDate is null or blank.
     */
    fun toIsoLocal(dueDate: String?, dueTime: String?): String? {
        if (dueDate.isNullOrBlank()) return null
        val cleanDate = dueDate.trim()
        val cal = Calendar.getInstance()

        when {
            cleanDate.equals("Today", ignoreCase = true) -> {
                // cal is already today
            }
            cleanDate.equals("Tomorrow", ignoreCase = true) -> {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            cleanDate.equals("Next Week", ignoreCase = true) -> {
                cal.add(Calendar.DAY_OF_YEAR, 7)
            }
            cleanDate.matches(Regex("^\\d{4}-\\d{2}-\\d{2}.*")) -> {
                val tokens = cleanDate.substring(0, 10).split("-")
                cal.set(Calendar.YEAR, tokens[0].toInt())
                cal.set(Calendar.MONTH, tokens[1].toInt() - 1)
                cal.set(Calendar.DAY_OF_MONTH, tokens[2].toInt())
            }
            else -> {
                parseDate(cleanDate)?.let { parsedDate ->
                    val pCal = Calendar.getInstance().apply { time = parsedDate }
                    cal.set(Calendar.YEAR, pCal.get(Calendar.YEAR))
                    cal.set(Calendar.MONTH, pCal.get(Calendar.MONTH))
                    cal.set(Calendar.DAY_OF_MONTH, pCal.get(Calendar.DAY_OF_MONTH))
                }
            }
        }

        var hour = 12
        var minute = 0
        if (!dueTime.isNullOrBlank()) {
            parseTime(dueTime.trim())?.let { (h, m) ->
                hour = h
                minute = m
            }
        }

        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, minute)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        return String.format(
            Locale.US,
            "%04d-%02d-%02dT%02d:%02d:00",
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
            cal.get(Calendar.HOUR_OF_DAY),
            cal.get(Calendar.MINUTE)
        )
    }

    /**
     * Converts a backend ISO-8601 string ("2026-09-13T09:00:00" or "2026-09-13 09:00:00")
     * into a Pair of (displayDate, displayTime).
     *
     * Example:
     * - If tomorrow at 09:00:00 -> Pair("Tomorrow", "09:00 AM")
     * - If today at 14:30:00 -> Pair("Today", "02:30 PM")
     * - If future date -> Pair("Sep 20, 2026", "12:00 PM")
     */
    fun fromIsoToDisplay(isoString: String?): Pair<String, String?> {
        if (isoString.isNullOrBlank()) return Pair("Today", null)
        val clean = isoString.trim()

        val parts = clean.split("T", " ")
        val datePart = parts[0]
        val timePart = if (parts.size > 1) parts[1] else null

        val dateTokens = datePart.split("-")
        if (dateTokens.size < 3) return Pair(clean, null)

        val year = dateTokens[0].toIntOrNull() ?: return Pair(clean, null)
        val month = dateTokens[1].toIntOrNull() ?: return Pair(clean, null)
        val day = dateTokens[2].substringBefore("Z").substringBefore("+").toIntOrNull() ?: return Pair(clean, null)

        val cal = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month - 1)
            set(Calendar.DAY_OF_MONTH, day)
        }

        val today = Calendar.getInstance()
        val isToday = cal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                cal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)

        val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        val isTomorrow = cal.get(Calendar.YEAR) == tomorrow.get(Calendar.YEAR) &&
                cal.get(Calendar.DAY_OF_YEAR) == tomorrow.get(Calendar.DAY_OF_YEAR)

        val displayDate = when {
            isToday -> "Today"
            isTomorrow -> "Tomorrow"
            else -> SimpleDateFormat("MMM dd, yyyy", Locale.US).format(cal.time)
        }

        var displayTime: String? = null
        if (!timePart.isNullOrBlank()) {
            val cleanTime = timePart.substringBefore("Z").substringBefore("+")
            val timeTokens = cleanTime.split(":")
            if (timeTokens.size >= 2) {
                val h = timeTokens[0].toIntOrNull()
                val m = timeTokens[1].toIntOrNull()
                if (h != null && m != null) {
                    val amPm = if (h < 12) "AM" else "PM"
                    val displayHour = when {
                        h == 0 -> 12
                        h > 12 -> h - 12
                        else -> h
                    }
                    displayTime = String.format(Locale.US, "%02d:%02d %s", displayHour, m, amPm)
                }
            }
        }

        return Pair(displayDate, displayTime)
    }

    private fun parseDate(dateStr: String): Date? {
        for (pattern in DATE_FORMATS) {
            try {
                val format = SimpleDateFormat(pattern, Locale.US).apply { isLenient = false }
                val parsed = format.parse(dateStr)
                if (parsed != null) return parsed
            } catch (_: Exception) {
                // Try next
            }
            try {
                val format = SimpleDateFormat(pattern, Locale.getDefault()).apply { isLenient = false }
                val parsed = format.parse(dateStr)
                if (parsed != null) return parsed
            } catch (_: Exception) {
                // Try next
            }
        }
        return null
    }

    private fun parseTime(timeStr: String): Pair<Int, Int>? {
        // Match 12-hour AM/PM: e.g. "12:00 PM", "9:30 am", "06:15 PM"
        val amPmRegex = Regex("^(\\d{1,2}):(\\d{2})\\s*([AaPp][Mm])$")
        val amPmMatch = amPmRegex.find(timeStr)
        if (amPmMatch != null) {
            var hour = amPmMatch.groupValues[1].toInt()
            val minute = amPmMatch.groupValues[2].toInt()
            val period = amPmMatch.groupValues[3].uppercase()
            if (period == "PM" && hour < 12) hour += 12
            if (period == "AM" && hour == 12) hour = 0
            return Pair(hour, minute)
        }

        // Match 24-hour: e.g. "14:30", "09:00", "14:30:00"
        val militaryRegex = Regex("^(\\d{1,2}):(\\d{2})(:\\d{2})?$")
        val militaryMatch = militaryRegex.find(timeStr)
        if (militaryMatch != null) {
            val hour = militaryMatch.groupValues[1].toInt()
            val minute = militaryMatch.groupValues[2].toInt()
            return Pair(hour, minute)
        }

        return null
    }

    /**
     * Converts a user-facing reminder label (e.g. "None", "At due time", "15m before", "1h before", "1d before")
     * into integer minutes before the due date, matching the backend Task schema.
     */
    fun reminderToMinutes(reminder: String?): Int? {
        if (reminder.isNullOrBlank() || reminder.equals("None", ignoreCase = true)) return null
        val clean = reminder.trim().lowercase()
        return when {
            clean.contains("at due") || clean == "due" -> 0
            clean.contains("15") -> 15
            clean.contains("1h") || clean.contains("1 hour") || clean.contains("60") -> 60
            clean.contains("1d") || clean.contains("1 day") -> 1440
            else -> {
                val num = Regex("\\d+").find(clean)?.value?.toIntOrNull()
                if (num != null) {
                    if (clean.contains("h")) num * 60
                    else if (clean.contains("d")) num * 1440
                    else num
                } else 15
            }
        }
    }

    /**
     * Converts integer minutes before due date from the backend into a friendly mobile display label.
     */
    fun minutesToReminder(minutes: Int?): String? {
        if (minutes == null) return null
        return when (minutes) {
            0 -> "At due time"
            15 -> "15m before"
            60 -> "1h before"
            1440 -> "1d before"
            else -> {
                if (minutes % 1440 == 0) "${minutes / 1440}d before"
                else if (minutes % 60 == 0) "${minutes / 60}h before"
                else "${minutes}m before"
            }
        }
    }
}
