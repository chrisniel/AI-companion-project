package com.example.ui

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.example.CompanionApplication
import com.example.ui.preview.DesignSystemViewModel
import com.example.ui.screens.AssistantViewModel
import com.example.ui.screens.alarms.AlarmsViewModel
import com.example.ui.screens.characters.CharactersViewModel
import com.example.ui.screens.devices.DevicesViewModel
import com.example.ui.screens.health.HealthViewModel
import com.example.ui.screens.memory.MemoryViewModel
import com.example.ui.screens.models.ModelsViewModel
import com.example.ui.screens.schedule.ScheduleViewModel
import com.example.ui.screens.settings.SettingsViewModel
import com.example.ui.screens.tasks.TasksViewModel
import com.example.ui.screens.voicemode.VoiceModeViewModel
import com.example.ui.shell.AppViewModel

/**
 * Provides Factory to create instances of ViewModel with AppContainer dependencies.
 */
object AppViewModelProvider {
    val Factory: ViewModelProvider.Factory = viewModelFactory {
        initializer {
            val app = companionApplication()
            AppViewModel(
                homeRepository = app.appContainer.homeRepository,
                appearanceRepository = app.appContainer.appearanceRepository
            )
        }
        initializer {
            val app = companionApplication()
            TasksViewModel(
                tasksRepository = app.appContainer.tasksRepository
            )
        }
        initializer {
            val app = companionApplication()
            ScheduleViewModel(
                scheduleRepository = app.appContainer.scheduleRepository
            )
        }
        initializer {
            val app = companionApplication()
            AlarmsViewModel(
                alarmsRepository = app.appContainer.alarmsRepository
            )
        }
        initializer {
            val app = companionApplication()
            AssistantViewModel(
                repository = app.appContainer.assistantRepository
            )
        }
        initializer {
            val app = companionApplication()
            SettingsViewModel(
                appearanceRepository = app.appContainer.appearanceRepository
            )
        }
        initializer {
            val app = companionApplication()
            CharactersViewModel(
                repository = app.appContainer.charactersRepository
            )
        }
        initializer {
            val app = companionApplication()
            ModelsViewModel(
                repository = app.appContainer.modelsAndDevicesRepository
            )
        }
        initializer {
            val app = companionApplication()
            DevicesViewModel(
                repository = app.appContainer.modelsAndDevicesRepository
            )
        }
        initializer {
            val app = companionApplication()
            MemoryViewModel(
                repository = app.appContainer.memoryRepository
            )
        }
        initializer {
            HealthViewModel()
        }
        initializer {
            VoiceModeViewModel()
        }
        initializer {
            val app = companionApplication()
            DesignSystemViewModel(
                repository = app.appContainer.designSystemRepository
            )
        }
    }
}

/**
 * Extension function to queries for [CompanionApplication] object and returns it.
 */
fun CreationExtras.companionApplication(): CompanionApplication =
    (this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as CompanionApplication)
