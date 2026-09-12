package com.example.data.fake

import com.example.domain.model.AlarmDay
import com.example.domain.model.AlarmRedundancyStatus
import com.example.domain.model.DeviceSyncState
import com.example.domain.model.MobileAlarm
import com.example.domain.repository.AlarmsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class FakeAlarmsRepository : AlarmsRepository {

    private val _alarms = MutableStateFlow(initialAlarms())
    override val alarms: StateFlow<List<MobileAlarm>> = _alarms.asStateFlow()

    private val _redundancyStatus = MutableStateFlow(
        AlarmRedundancyStatus(
            desktopNodeName = "Desktop Core (Workstation)",
            desktopStatus = DeviceSyncState.SYNCHRONIZED,
            androidNodeName = "Android Local (Device)",
            androidStatus = DeviceSyncState.ARMED_LOCALLY,
            lastHeartbeat = "Synced 2m ago"
        )
    )
    override val redundancyStatus: StateFlow<AlarmRedundancyStatus> = _redundancyStatus.asStateFlow()

    override fun toggleAlarmEnabled(id: String) {
        _alarms.update { list ->
            list.map { alarm ->
                if (alarm.id == id) {
                    val next = !alarm.isEnabled
                    alarm.copy(
                        isEnabled = next,
                        androidArmedState = if (next) DeviceSyncState.ARMED_LOCALLY else DeviceSyncState.OFFLINE
                    )
                } else alarm
            }
        }
    }

    override fun saveAlarm(alarm: MobileAlarm) {
        _alarms.update { list ->
            val index = list.indexOfFirst { it.id == alarm.id }
            if (index >= 0) {
                list.toMutableList().apply { set(index, alarm) }
            } else {
                listOf(alarm) + list
            }
        }
    }

    override fun deleteAlarm(id: String) {
        _alarms.update { list -> list.filterNot { it.id == id } }
    }

    override fun toggleRedundancySimulation() {
        _redundancyStatus.update { current ->
            val isCurrentlySync = current.desktopStatus == DeviceSyncState.SYNCHRONIZED
            val newDesktop = if (isCurrentlySync) DeviceSyncState.OFFLINE else DeviceSyncState.SYNCHRONIZED
            val newAndroid = DeviceSyncState.ARMED_LOCALLY

            current.copy(
                desktopStatus = newDesktop,
                androidStatus = newAndroid,
                lastHeartbeat = if (isCurrentlySync) "Desktop link offline" else "Synchronized just now"
            )
        }
    }

    companion object {
        fun initialAlarms(): List<MobileAlarm> = listOf(
            MobileAlarm(
                id = "alarm_1",
                title = "Primary Wakeup",
                time = "07:00 AM",
                recurrenceDays = setOf(AlarmDay.MON, AlarmDay.TUE, AlarmDay.WED, AlarmDay.THU, AlarmDay.FRI),
                recurrenceLabel = "Weekdays",
                isEnabled = true,
                vibrate = true,
                soundName = "Soft Dawn Synthesizer",
                pcMirroring = true,
                desktopSyncState = DeviceSyncState.SYNCHRONIZED,
                androidArmedState = DeviceSyncState.ARMED_LOCALLY,
                nextTriggerLabel = "Tomorrow at 07:00 AM"
            ),
            MobileAlarm(
                id = "alarm_2",
                title = "Deep Focus Sprint",
                time = "09:30 AM",
                recurrenceDays = setOf(AlarmDay.MON, AlarmDay.WED, AlarmDay.FRI),
                recurrenceLabel = "Mon, Wed, Fri",
                isEnabled = true,
                vibrate = false,
                soundName = "Gentle Pulse",
                pcMirroring = true,
                desktopSyncState = DeviceSyncState.SYNCHRONIZED,
                androidArmedState = DeviceSyncState.ARMED_LOCALLY,
                nextTriggerLabel = "Friday at 09:30 AM"
            ),
            MobileAlarm(
                id = "alarm_3",
                title = "Weekend Sunrise Awakening",
                time = "08:30 AM",
                recurrenceDays = setOf(AlarmDay.SAT, AlarmDay.SUN),
                recurrenceLabel = "Weekends",
                isEnabled = false,
                vibrate = true,
                soundName = "Ambient Waves",
                pcMirroring = false,
                desktopSyncState = DeviceSyncState.OFFLINE,
                androidArmedState = DeviceSyncState.OFFLINE,
                nextTriggerLabel = "Disabled"
            ),
            MobileAlarm(
                id = "alarm_4",
                title = "Evening Wind-down",
                time = "10:30 PM",
                recurrenceDays = AlarmDay.entries.toSet(),
                recurrenceLabel = "Every day",
                isEnabled = true,
                vibrate = true,
                soundName = "Twilight Harmonic",
                pcMirroring = true,
                desktopSyncState = DeviceSyncState.SYNCHRONIZED,
                androidArmedState = DeviceSyncState.ARMED_LOCALLY,
                nextTriggerLabel = "Tonight at 10:30 PM"
            )
        )
    }
}
