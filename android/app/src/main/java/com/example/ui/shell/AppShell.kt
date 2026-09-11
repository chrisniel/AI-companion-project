package com.example.ui.shell

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerDefaults
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.example.domain.model.BackgroundType
import com.example.domain.model.EffectsLevel
import com.example.domain.model.SyncStatus
import com.example.navigation.AppBottomBar
import com.example.navigation.AppTopBar
import com.example.navigation.BottomNavItem
import com.example.navigation.Routes
import kotlinx.coroutines.launch
import kotlin.math.absoluteValue
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

    val coroutineScope = rememberCoroutineScope()
    val pagerState = rememberPagerState(initialPage = 0) { 5 }

    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val navHostRoute = navBackStackEntry?.destination?.route ?: Routes.HOME

    val activePrimaryItem = BottomNavItem.fromPageIndex(pagerState.currentPage)
    val currentRoute = if (navHostRoute == Routes.HOME) activePrimaryItem.route else navHostRoute

    val isSubDestination = navHostRoute != Routes.HOME
    val canNavigateBack = isSubDestination

    // Intercept back presses on pager: return to Home tab first before system back
    BackHandler(enabled = navHostRoute == Routes.HOME && pagerState.currentPage != 0) {
        coroutineScope.launch {
            pagerState.animateScrollToPage(
                page = 0,
                animationSpec = tween(durationMillis = 280, easing = FastOutSlowInEasing)
            )
        }
    }

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
        else -> "AI Companion"
    }

    val navigateToDestination: (String) -> Unit = { targetRoute: String ->
        val targetIndex = BottomNavItem.getPageIndexForRoute(targetRoute)
        if (targetIndex != null) {
            if (navHostRoute != Routes.HOME) {
                navController.popBackStack(Routes.HOME, inclusive = false)
            }
            coroutineScope.launch {
                pagerState.animateScrollToPage(
                    page = targetIndex,
                    animationSpec = spring(
                        dampingRatio = 0.84f,
                        stiffness = Spring.StiffnessMediumLow
                    )
                )
            }
        } else {
            navController.navigate(targetRoute) {
                launchSingleTop = true
            }
        }
    }

    val onNavigateToRoute: (String) -> Unit = { route: String ->
        navigateToDestination(route)
    }

    val backgroundPreset = preferences.backgroundPreset
    val showAura = preferences.effectsLevel != EffectsLevel.REDUCED

    val renderScaffold: @Composable () -> Unit = {
        Scaffold(
            modifier = Modifier
                .fillMaxSize()
                .testTag("app_shell_scaffold"),
            topBar = {
                if (currentRoute != Routes.HOME && currentRoute != Routes.ASSISTANT && currentRoute != Routes.VOICE_MODE && currentRoute != Routes.CHARACTERS && currentRoute != Routes.SETTINGS && currentRoute != Routes.CONNECTION && currentRoute != Routes.PERMISSIONS) {
                    AppTopBar(
                        title = pageTitle,
                        canNavigateBack = canNavigateBack,
                        onNavigateBack = { navController.popBackStack() },
                        connectionInfo = uiState.connectionInfo,
                        onCycleConnectionState = { appViewModel.cycleConnectionState() },
                        isDarkTheme = SoftTheme.colors.isDark,
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
                        enterTransition = {
                            slideInHorizontally(
                                initialOffsetX = { it },
                                animationSpec = tween(durationMillis = 240, easing = FastOutSlowInEasing)
                            ) + fadeIn(animationSpec = tween(durationMillis = 240))
                        },
                        exitTransition = {
                            slideOutHorizontally(
                                targetOffsetX = { -it / 4 },
                                animationSpec = tween(durationMillis = 240, easing = FastOutSlowInEasing)
                            ) + fadeOut(animationSpec = tween(durationMillis = 200))
                        },
                        popEnterTransition = {
                            slideInHorizontally(
                                initialOffsetX = { -it / 4 },
                                animationSpec = tween(durationMillis = 240, easing = FastOutSlowInEasing)
                            ) + fadeIn(animationSpec = tween(durationMillis = 240))
                        },
                        popExitTransition = {
                            slideOutHorizontally(
                                targetOffsetX = { it },
                                animationSpec = tween(durationMillis = 240, easing = FastOutSlowInEasing)
                            ) + fadeOut(animationSpec = tween(durationMillis = 200))
                        },
                        modifier = Modifier.fillMaxSize()
                    ) {
                        // PRIMARY DESTINATIONS: Hosted inside high-performance HorizontalPager (1:1 touch swiping & pre-rendered tabs)
                        composable(Routes.HOME) {
                            HorizontalPager(
                                state = pagerState,
                                beyondViewportPageCount = 1,
                                flingBehavior = PagerDefaults.flingBehavior(
                                    state = pagerState,
                                    snapAnimationSpec = spring(
                                        dampingRatio = 0.82f,
                                        stiffness = Spring.StiffnessMediumLow
                                    )
                                ),
                                modifier = Modifier.fillMaxSize()
                            ) { page ->
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .graphicsLayer {
                                            val pageOffset = (pagerState.currentPage - page) + pagerState.currentPageOffsetFraction
                                            val absOffset = pageOffset.absoluteValue.coerceIn(0f, 1f)
                                            alpha = 1f - (absOffset * 0.18f)
                                            scaleX = 1f - (absOffset * 0.02f)
                                            scaleY = 1f - (absOffset * 0.02f)
                                        }
                                ) {
                                    when (page) {
                                        0 -> HomeScreen(
                                            homeData = homeData,
                                            connectionInfo = uiState.connectionInfo,
                                            selectedPersona = uiState.selectedPersona,
                                            onSelectPersona = { appViewModel.selectPersona(it) },
                                            onNavigateToRoute = onNavigateToRoute,
                                            onToggleTask = { taskId -> appViewModel.toggleTask(taskId) },
                                            onAddTask = { title, priority -> appViewModel.addNewTask(title, priority) }
                                        )
                                        1 -> TasksScreen()
                                        2 -> AssistantScreen(
                                            isDarkTheme = SoftTheme.colors.isDark,
                                            onOpenVoiceMode = {
                                                navController.navigate(Routes.VOICE_MODE) {
                                                    launchSingleTop = true
                                                }
                                            }
                                        )
                                        3 -> HealthScreen(
                                            healthConnectState = uiState.capabilitiesState.healthConnectState,
                                            onSetHealthConnectState = { appViewModel.setHealthConnectState(it) }
                                        )
                                        4 -> MoreScreen(
                                            onNavigateToRoute = onNavigateToRoute
                                        )
                                    }
                                }
                            }
                        }

                        // Fallback alias routes to safely handle direct route navigation if any caller uses it
                        composable(Routes.TASKS) {
                            LaunchedEffect(Unit) {
                                pagerState.scrollToPage(1)
                                navController.popBackStack(Routes.HOME, false)
                            }
                        }
                        composable(Routes.ASSISTANT) {
                            LaunchedEffect(Unit) {
                                pagerState.scrollToPage(2)
                                navController.popBackStack(Routes.HOME, false)
                            }
                        }
                        composable(Routes.HEALTH) {
                            LaunchedEffect(Unit) {
                                pagerState.scrollToPage(3)
                                navController.popBackStack(Routes.HOME, false)
                            }
                        }
                        composable(Routes.MORE) {
                            LaunchedEffect(Unit) {
                                pagerState.scrollToPage(4)
                                navController.popBackStack(Routes.HOME, false)
                            }
                        }

                        // DEDICATED VOICE MODE (Batch 4.1)
                        composable(Routes.VOICE_MODE) {
                            VoiceModeScreen(
                                onEndSession = { navController.popBackStack() },
                                microphoneState = uiState.capabilitiesState.microphoneState,
                                onSetMicrophoneState = { appViewModel.setMicrophoneState(it) }
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
                                statusText = "V1.1 Companion Prototype",
                                metrics = listOf(
                                    "Client Build" to "V1.1 (Prototype)",
                                    "Design Language" to "Soft Glass (Obsidian / Pearl)",
                                    "Target Platform" to "Android 14 / Compose M3",
                                    "Architecture Target" to "Companion to Windows PC Host",
                                    "License" to "License Not Selected"
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
                secondaryGlow = Color(backgroundPreset.secondaryGlowHex),
                scrimOpacity = preferences.scrimOpacity,
                brightness = preferences.backgroundBrightness
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
                                Color(preferences.gradientPreset.startColorHex),
                                Color(preferences.gradientPreset.endColorHex)
                            )
                        )
                    )
            ) {
                if (preferences.scrimOpacity > 0f) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                (if (SoftTheme.colors.isDark) Color.Black else Color.White)
                                    .copy(alpha = preferences.scrimOpacity)
                            )
                    )
                }
                renderScaffold()
            }
        }
        BackgroundType.SOLID -> {
            Box(
                modifier = modifier
                    .fillMaxSize()
                    .background(Color(preferences.solidPreset.colorHex))
            ) {
                if (preferences.scrimOpacity > 0f) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(
                                (if (SoftTheme.colors.isDark) Color.Black else Color.White)
                                    .copy(alpha = preferences.scrimOpacity)
                            )
                    )
                }
                renderScaffold()
            }
        }
        BackgroundType.CUSTOM_IMAGE -> {
            AmbientGlassBackground(
                modifier = modifier.fillMaxSize(),
                showAuraGlow = false,
                scrimOpacity = preferences.scrimOpacity,
                brightness = preferences.backgroundBrightness
            ) {
                renderScaffold()
            }
        }
    }
}
