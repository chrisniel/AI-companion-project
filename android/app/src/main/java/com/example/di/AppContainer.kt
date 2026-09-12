package com.example.di

import android.content.Context
import com.example.data.fake.FakeAlarmsRepository
import com.example.data.fake.FakeAppearanceRepository
import com.example.data.fake.FakeAssistantRepository
import com.example.data.fake.FakeCharactersRepository
import com.example.data.fake.FakeDesignSystemRepository
import com.example.data.fake.FakeHomeRepository
import com.example.data.fake.FakeMemoryRepository
import com.example.data.fake.FakeModelsAndDevicesRepository
import com.example.data.fake.FakeScheduleRepository
import com.example.data.fake.FakeTasksRepository
import com.example.data.repository.HttpTasksRepository
import com.example.data.repository.SharedPreferencesConnectionRepository
import com.example.domain.repository.AlarmsRepository
import com.example.domain.repository.AppearanceRepository
import com.example.domain.repository.AssistantRepository
import com.example.domain.repository.CharactersRepository
import com.example.domain.repository.ConnectionRepository
import com.example.domain.repository.DesignSystemRepository
import com.example.domain.repository.HomeRepository
import com.example.domain.repository.MemoryRepository
import com.example.domain.repository.ModelsAndDevicesRepository
import com.example.domain.repository.ScheduleRepository
import com.example.domain.repository.TasksRepository

/**
 * Application-scoped manual dependency container interface.
 */
interface AppContainer {
    val connectionRepository: ConnectionRepository
    val tasksRepository: TasksRepository
    val scheduleRepository: ScheduleRepository
    val alarmsRepository: AlarmsRepository
    val appearanceRepository: AppearanceRepository
    val homeRepository: HomeRepository
    val assistantRepository: AssistantRepository
    val charactersRepository: CharactersRepository
    val modelsAndDevicesRepository: ModelsAndDevicesRepository
    val memoryRepository: MemoryRepository
    val designSystemRepository: DesignSystemRepository
}

/**
 * Default implementation of AppContainer wiring shared repositories.
 */
class DefaultAppContainer(private val context: Context) : AppContainer {
    override val connectionRepository: ConnectionRepository by lazy {
        SharedPreferencesConnectionRepository(context)
    }

    override val tasksRepository: TasksRepository by lazy {
        HttpTasksRepository(connectionRepository)
    }

    override val scheduleRepository: ScheduleRepository by lazy {
        FakeScheduleRepository()
    }

    override val alarmsRepository: AlarmsRepository by lazy {
        FakeAlarmsRepository()
    }

    override val appearanceRepository: AppearanceRepository by lazy {
        com.example.data.repository.SharedPreferencesAppearanceRepository(context)
    }

    override val homeRepository: HomeRepository by lazy {
        FakeHomeRepository(
            tasksRepository = tasksRepository,
            scheduleRepository = scheduleRepository,
            alarmsRepository = alarmsRepository
        )
    }

    override val assistantRepository: AssistantRepository by lazy {
        FakeAssistantRepository()
    }

    override val charactersRepository: CharactersRepository by lazy {
        FakeCharactersRepository()
    }

    override val modelsAndDevicesRepository: ModelsAndDevicesRepository by lazy {
        FakeModelsAndDevicesRepository()
    }

    override val memoryRepository: MemoryRepository by lazy {
        FakeMemoryRepository()
    }

    override val designSystemRepository: DesignSystemRepository by lazy {
        FakeDesignSystemRepository()
    }
}
