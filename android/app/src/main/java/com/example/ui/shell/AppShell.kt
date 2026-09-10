package com.example.ui.shell

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.example.domain.model.BackgroundType
import com.example.domain.model.EffectsLevel
import com.example.domain.model.SyncStatus
import com.example.navigation.AppBottomBar
import com.example.navigation.AppTopBar
import com.example.navigation.Routes
import com.example.ui.AppViewModelProvider
import com.example.ui.components.AmbientGlassBackground
import com.example.ui.components.CalmConnectionBanner
import com.example.ui.components.CalmSyncBanner
import com.example.ui.components.OfflineCapabilitiesSheet
import com.example.ui.preview.DesignSystemPreviewScreen
import com.example.ui.preview.DesignSystemViewModel
import com.example.ui.screens.AssistantScreen
import com.example.ui.screens.HomeScreen
import com.example.ui.screens.MoreScreen
import com.example.ui.screens.PlaceholderScreen
import com.example.ui.screens.alarms.AlarmsScreen
import com.example.ui.screens.characters.CharactersScreen
import com.example.ui.screens.connection.ConnectionScreen
import com.example.ui.screens.devices.DevicesScreen
import com.example.ui.screens.health.HealthScreen
import com.example.ui.screens.memory.MemoryScreen
import com.example.ui.screens.models.ModelsScreen
import com.example.ui.screens.permissions.PermissionsScreen
import com.example.ui.screens.schedule.ScheduleScreen
import com.example.ui.screens.settings.SettingsScreen
import com.example.ui.screens.tasks.TasksScreen
import com.example.ui.screens.voicemode.VoiceModeScreen
import com.example.ui.theme.LocalAppearancePreferences
import com.example.ui.theme.SoftTheme

/**
 * Mobile Application Shell for Local AI Core.
 * Hosts the Scaffold, contextual AppTopBar, 5-destination AppBottomBar,
 * NavHost for all routes, and root atmospheric background rendering.
 */
@Composable
fun AppShell(
    modifier: Modifier = Modifier,
    appViewModel: AppViewModel = viewModel(factory = AppViewModelProvider.Factory),
    designSystemViewModel: DesignSystemViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val uiState by appViewModel.uiState.collectAsStateWithLifecycle()
    val homeData by appViewModel.homeData.collectAsStateWithLifecycle()
    val preferences = LocalAppearancePreferences.current

    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route ?: Routes.HOME

    val isSubDestination = currentRoute.startsWith("more/")
    val canNavigateBack = isSubDestination

    val pageTitle = when (currentRoute) {
        Routes.HOME -> "Local AI Core"
        Routes.ASSISTANT -> "Local Assistant"
        Routes.TASKS -> "Tasks"
        Routes.HEALTH -> "Biometric Health"
        Routes.MORE -> "System Hub"
        Routes.SCHEDULE -> "Schedule"
        Routes.ALARMS -> "Alarms"
        Routes.CHARACTERS -> "Characters"
        Routes.MODELS -> "Local Models"
        Routes.DEVICES -> "Devices"
        Routes.MEMORY -> "Memory & Cache"
        Routes.SETTINGS -> "Settings"
        Routes.DESIGN_SYSTEM -> "Design System"
        else -> "Local AI Core"
    }

    val navigateToDestination = { targetRoute: String ->
        navController.navigate(targetRoute) {
            popUpTo(navController.graph.findStartDestination().id) {
                saveState = true
            }
            launchSingleTop = true
            restoreState = true
        }
    }

    val isPrimaryDestination = { route: String ->
        route == Routes.HOME || route == Routes.ASSISTANT || route == Routes.TASKS ||
        route == Routes.HEALTH || route == Routes.MORE
    }

    val onNavigateToRoute = { route: String ->
        if (isPrimaryDestination(route)) {
            navigateToDestination(route)
        } else {
            navController.navigate(route) {
                launchSingleTop = true
            }
        }
    }

    val backgroundPreset = preferences.backgroundPreset
    val showAura = preferences.effectsLevel != EffectsLevel.REDUCED

    val renderScaffold: @Composable () -> Unit = {
        Scaffold(
            modifier = Modifier
                .fillMaxSize()
                .testTag("app_shell_scaffold"),
            topBar = {
                if (currentRoute != Routes.ASSISTANT && currentRoute != Routes.VOICE_MODE && currentRoute != Routes.CHARACTERS && currentRoute != Routes.SETTINGS && currentRoute != Routes.CONNECTION && currentRoute != Routes.PERMISSIONS) {
                    AppTopBar(
                        title = pageTitle,
                        canNavigateBack = canNavigateBack,
                        onNavigateBack = { navController.popBackStack() },
                        connectionInfo = uiState.connectionInfo,
                        onCycleConnectionState = { appViewModel.cycleConnectionState() },
                        isDarkTheme = uiState.isDarkTheme,
                        onToggleTheme = { appViewModel.toggleTheme() },
                        userName = uiState.userName,
                        onAvatarClick = {
                            if (currentRoute != Routes.SETTINGS) {
                                navController.navigate(Routes.SETTINGS) {
                                    launchSingleTop = true
                                }
                            }
                        }
                    )
                }
            },
            bottomBar = {
                if (currentRoute != Routes.VOICE_MODE) {
                    AppBottomBar(
                        currentRoute = currentRoute,
                        onNavigateToDestination = { item ->
                            navigateToDestination(item.route)
                        }
                    )
                }
            },
            containerColor = Color.Transparent
        ) { paddingValues ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                // Calm Connection Banner across screens when active and enabled
                if (uiState.showConnectionBanner) {
                    CalmConnectionBanner(
                        connectionState = uiState.connectionInfo.state,
                        onOpenOfflineDetails = { appViewModel.toggleOfflineCapabilitiesSheet(true) },
                        onDismiss = { appViewModel.dismissConnectionBanner() }
                    )
                }

                // Calm Sync Status Banner across screens when active and enabled
                if (uiState.showSyncBanner) {
                    CalmSyncBanner(
                        syncStatus = uiState.connectionInfo.syncStatus,
                        onActionClick = {
                            when (uiState.connectionInfo.syncStatus) {
                                SyncStatus.CONFLICT -> appViewModel.resolveSyncConflict(keepLocal = true)
                                SyncStatus.FAILED, SyncStatus.PENDING, SyncStatus.STALE -> appViewModel.retrySync()
                                SyncStatus.SYNCHRONIZED -> {}
                            }
                        },
                        onDismiss = { appViewModel.dismissSyncBanner() }
                    )
                }

                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                ) {
                    NavHost(
                        navController = navController,
                        startDestination = Routes.HOME,
                        enterTransition = { EnterTransition.None },
                        exitTransition = { ExitTransition.None },
                        modifier = Modifier.fillMaxSize()
                    ) {
                        // PRIMARY DESTINATION 1: HOME
                        composable(Routes.HOME) {
                            HomeScreen(
                                homeData = homeData,
                                connectionInfo = uiState.connectionInfo,
                                selectedPersona = uiState.selectedPersona,
                                onSelectPersona = { appViewModel.selectPersona(it) },
                                onNavigateToRoute = onNavigateToRoute,
                                onToggleTask = { taskId -> appViewModel.toggleTask(taskId) },
                                onAddTask = { title, priority -> appViewModel.addNewTask(title, priority) }
                            )
                        }

                        // PRIMARY DESTINATION 2: ASSISTANT
                        composable(Routes.ASSISTANT) {
                            AssistantScreen(
                                isDarkTheme = uiState.isDarkTheme,
                                onToggleTheme = { appViewModel.toggleTheme() },
                                onOpenVoiceMode = {
                                    navController.navigate(Routes.VOICE_MODE) {
                                        launchSingleTop = true
                                    }
                                }
                            )
                        }

                        // DEDICATED VOICE MODE (Batch 4.1)
                        composable(Routes.VOICE_MODE) {
                            VoiceModeScreen(
                                onEndSession = { navController.popBackStack() },
                                microphoneState = uiState.capabilitiesState.microphoneState,
                                onSetMicrophoneState = { appViewModel.setMicrophoneState(it) }
                            )
                        }

                        // PRIMARY DESTINATION 3: TASKS (Batch 5: Mobile Tasks)
                        composable(Routes.TASKS) {
                            TasksScreen()
                        }

                        // PRIMARY DESTINATION 4: HEALTH (Batch 7: Mobile Health and Wellness)
                        composable(Routes.HEALTH) {
                            HealthScreen(
                                healthConnectState = uiState.capabilitiesState.healthConnectState,
                                onSetHealthConnectState = { appViewModel.setHealthConnectState(it) }
                            )
                        }

                        // PRIMARY DESTINATION 5: MORE
                        composable(Routes.MORE) {
                            MoreScreen(
                                onNavigateToRoute = onNavigateToRoute
                            )
                        }

                        // SECONDARY DESTINATION: SCHEDULE (Batch 6)
                        composable(Routes.SCHEDULE) {
                            ScheduleScreen()
                        }

                        // SECONDARY DESTINATION: ALARMS (Batch 6)
                        composable(Routes.ALARMS) {
                            AlarmsScreen(
                                alarmCapabilityState = uiState.capabilitiesState.alarmCapabilityState,
                                onSetAlarmCapabilityState = { appViewModel.setAlarmCapabilityState(it) }
                            )
                        }

                        // SECONDARY DESTINATION: CHARACTERS (Batch 8)
                        composable(Routes.CHARACTERS) {
                            CharactersScreen(
                                onNavigateBack = { navController.popBackStack() },
                                onSelectActiveCharacter = { char ->
                                    appViewModel.selectPersona(char.displayName)
                                }
                            )
                        }

                        // SECONDARY DESTINATION: MODELS (Batch 9)
                        composable(Routes.MODELS) {
                            ModelsScreen(
                                onNavigateBack = { navController.popBackStack() }
                            )
                        }

                        // SECONDARY DESTINATION: DEVICES (Batch 9)
                        composable(Routes.DEVICES) {
                            DevicesScreen(
                                onNavigateBack = { navController.popBackStack() }
                            )
                        }

                        // SECONDARY DESTINATION: MEMORY (Batch 10)
                        composable(Routes.MEMORY) {
                            MemoryScreen(
                                onNavigateBack = { navController.popBackStack() }
                            )
                        }

                        // SECONDARY DESTINATION: CONNECTION & OFFLINE SYNC (Batch 12)
                        composable(Routes.CONNECTION) {
                            ConnectionScreen(
                                connectionInfo = uiState.connectionInfo,
                                onSetConnectionState = { appViewModel.setConnectionState(it) },
                                onSetSyncStatus = { appViewModel.setSyncStatus(it) },
                                onResolveConflict = { appViewModel.resolveSyncConflict(it) },
                                onRetrySync = { appViewModel.retrySync() },
                                onNavigateBack = { navController.popBackStack() }
                            )
                        }

                        // SECONDARY DESTINATION: SETTINGS (Batch 11: Settings, Appearance & Language)
                        composable(Routes.SETTINGS) {
                            SettingsScreen(
                                onNavigateBack = { navController.popBackStack() },
                                onLiveThemeChanged = { isDark -> appViewModel.setTheme(isDark) },
                                onNavigateToPermissions = {
                                    navController.navigate(Routes.PERMISSIONS) {
                                        launchSingleTop = true
                                    }
                                }
                            )
                        }

                        // SECONDARY DESTINATION: PERMISSIONS & CAPABILITIES (Batch 13)
                        composable(Routes.PERMISSIONS) {
                            PermissionsScreen(
                                capabilitiesState = uiState.capabilitiesState,
                                onSetMicrophoneState = { appViewModel.setMicrophoneState(it) },
                                onSetNotificationState = { appViewModel.setNotificationState(it) },
                                onSetHealthConnectState = { appViewModel.setHealthConnectState(it) },
                                onSetAlarmCapabilityState = { appViewModel.setAlarmCapabilityState(it) },
                                onSetBluetoothAudioRequired = { appViewModel.setBluetoothAudioRequired(it) },
                                onSetBluetoothAudioState = { appViewModel.setBluetoothAudioState(it) },
                                onResetDefaults = { appViewModel.resetCapabilitiesToDefaults() },
                                onNavigateBack = { navController.popBackStack() }
                            )
                        }

                        // SECONDARY DESTINATION: ABOUT (Batch 10)
                        composable(Routes.ABOUT) {
                            PlaceholderScreen(
                                title = "Local AI Core Companion",
                                category = "Privacy-First Architecture",
                                description = "Offline-first companion application engineered with Jetpack Compose and Soft Glass design.",
                                icon = Icons.Default.Info,
                                statusText = "v1.5.0 Production Build",
                                metrics = listOf(
                                    "Client Build" to "v1.5.0-alpha02",
                                    "Design Language" to "Soft Glass (Obsidian / Pearl)",
                                    "Target Platform" to "Android 14 / Compose M3",
                                    "Privacy Standard" to "100% On-Premises Compute",
                                    "License" to "Open Hardware & Edge Intelligence"
                                ),
                                actions = listOf("View Release Notes", "Verify Build Hash")
                            )
                        }

                        // SECONDARY DESTINATION: DESIGN SYSTEM CATALOG
                        composable(Routes.DESIGN_SYSTEM) {
                            DesignSystemPreviewScreen(
                                modifier = Modifier.fillMaxSize(),
                                viewModel = designSystemViewModel
                            )
                        }
                    }
                }
            }
        }

        // Modal sheet communicating offline capabilities and mock state controls
        OfflineCapabilitiesSheet(
            isOpen = uiState.showOfflineCapabilitiesSheet,
            onDismiss = { appViewModel.toggleOfflineCapabilitiesSheet(false) },
            connectionInfo = uiState.connectionInfo,
            onSetConnectionState = { appViewModel.setConnectionState(it) },
            onSetSyncStatus = { appViewModel.setSyncStatus(it) }
        )
    }

    when (preferences.backgroundType) {
        BackgroundType.BUILT_IN -> {
            AmbientGlassBackground(
                modifier = modifier.fillMaxSize(),
                showAuraGlow = showAura,
                primaryGlow = Color(backgroundPreset.primaryGlowHex),
                secondaryGlow = Color(backgroundPreset.secondaryGlowHex)
            ) {
                renderScaffold()
            }
        }
        BackgroundType.GRADIENT -> {
            Box(
                modifier = modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                SoftTheme.colors.backgroundSecondary,
                                SoftTheme.colors.background
                            )
                        )
                    )
            ) {
                renderScaffold()
            }
        }
        BackgroundType.SOLID -> {
            Box(
                modifier = modifier
                    .fillMaxSize()
                    .background(SoftTheme.colors.background)
            ) {
                renderScaffold()
            }
        }
        BackgroundType.CUSTOM_IMAGE -> {
            AmbientGlassBackground(
                modifier = modifier.fillMaxSize(),
                showAuraGlow = false
            ) {
                renderScaffold()
            }
        }
    }
}
