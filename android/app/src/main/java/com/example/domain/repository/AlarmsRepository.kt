package com.example.domain.repository

import com.example.domain.model.AlarmRedundancyStatus
import com.example.domain.model.MobileAlarm
import kotlinx.coroutines.flow.StateFlow

/**
 * Authoritative repository interface for Mobile Alarms & Redundancy.
 */
interface AlarmsRepository {
    val alarms: StateFlow<List<MobileAlarm>>
    val redundancyStatus: StateFlow<AlarmRedundancyStatus>

    fun toggleAlarmEnabled(id: String)
    fun saveAlarm(alarm: MobileAlarm)
    fun deleteAlarm(id: String)
    fun toggleRedundancySimulation()
}
