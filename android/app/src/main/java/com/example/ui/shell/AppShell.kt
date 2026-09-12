package com.example.ui.shell

import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.example.domain.model.AppearancePreferences
import com.example.domain.model.BackgroundType
import com.example.domain.model.ConnectionInfo
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.EffectsLevel
import com.example.domain.model.SyncStatus
import com.example.domain.model.ThemeMode
import com.example.navigation.AppBottomBar
import com.example.navigation.AppTopBar
import com.example.navigation.BottomNavItem
import com.example.navigation.Routes
import kotlin.math.abs
import kotlinx.coroutines.launch
import com.example.ui.AppViewModelProvider
import com.example.ui.components.AmbientGlassBackground
import com.example.ui.components.CalmConnectionBanner
import com.example.ui.components.CalmSyncBanner
import com.example.ui.components.CompactConnectionIndicator
import com.example.ui.components.OfflineCapabilitiesSheet
import com.example.ui.components.SoftAvatar
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
    var isVaultExpanded by remember { mutableStateOf(false) }
    var selectedPageIndex by rememberSaveable { mutableIntStateOf(0) }
    var previousPageIndex by rememberSaveable { mutableIntStateOf(0) }

    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val navHostRoute = navBackStackEntry?.destination?.route ?: Routes.HOME

    val activePrimaryItem = BottomNavItem.fromPageIndex(selectedPageIndex)
    val currentRoute = if (navHostRoute == Routes.HOME) activePrimaryItem.route else navHostRoute

    val isSubDestination = navHostRoute != Routes.HOME
    val canNavigateBack = isSubDestination

    // Intercept back presses on primary tabs: return to Home tab first before system back
    BackHandler(enabled = navHostRoute == Routes.HOME && selectedPageIndex != 0) {
        previousPageIndex = selectedPageIndex
        selectedPageIndex = 0
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
            if (selectedPageIndex != targetIndex) {
                previousPageIndex = selectedPageIndex
                selectedPageIndex = targetIndex
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
    val showAura = !SoftTheme.colors.isOled

    val renderScaffold: @Composable () -> Unit = {
        Scaffold(
            modifier = Modifier
                .fillMaxSize()
                .testTag("app_shell_scaffold"),
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
            topBar = {},
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
                    .padding(bottom = paddingValues.calculateBottomPadding())
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
                                animationSpec = tween(durationMillis = 180, easing = FastOutSlowInEasing)
                            ) + fadeIn(animationSpec = tween(durationMillis = 180))
                        },
                        exitTransition = {
                            slideOutHorizontally(
                                targetOffsetX = { -it / 4 },
                                animationSpec = tween(durationMillis = 180, easing = FastOutSlowInEasing)
                            ) + fadeOut(animationSpec = tween(durationMillis = 150))
                        },
                        popEnterTransition = {
                            slideInHorizontally(
                                initialOffsetX = { -it / 4 },
                                animationSpec = tween(durationMillis = 180, easing = FastOutSlowInEasing)
                            ) + fadeIn(animationSpec = tween(durationMillis = 180))
                        },
                        popExitTransition = {
                            slideOutHorizontally(
                                targetOffsetX = { it },
                                animationSpec = tween(durationMillis = 180, easing = FastOutSlowInEasing)
                            ) + fadeOut(animationSpec = tween(durationMillis = 150))
                        },
                        modifier = Modifier.fillMaxSize()
                    ) {
                        // PRIMARY DESTINATIONS: Hosted with smooth direction-aware spring slide transitions
                        composable(Routes.HOME) {
                            val swipeOffset = remember { Animatable(0f) }
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .pointerInput(selectedPageIndex) {
                                        detectHorizontalDragGestures(
                                            onDragStart = {},
                                            onDragEnd = {
                                                val currentOffset = swipeOffset.value
                                                if (currentOffset < -80f && selectedPageIndex < 4) {
                                                    previousPageIndex = selectedPageIndex
                                                    selectedPageIndex++
                                                } else if (currentOffset > 80f && selectedPageIndex > 0) {
                                                    previousPageIndex = selectedPageIndex
                                                    selectedPageIndex--
                                                }
                                                coroutineScope.launch {
                                                    swipeOffset.animateTo(
                                                        0f,
                                                        animationSpec = spring(dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow)
                                                    )
                                                }
                                            },
                                            onHorizontalDrag = { change, dragAmount ->
                                                if (kotlin.math.abs(swipeOffset.value + dragAmount) > 4f) {
                                                    change.consume()
                                                    coroutineScope.launch {
                                                        swipeOffset.snapTo(
                                                            (swipeOffset.value + dragAmount * 0.75f).coerceIn(-300f, 300f)
                                                        )
                                                    }
                                                }
                                            }
                                        )
                                    }
                            ) {
                                AnimatedContent(
                                    targetState = selectedPageIndex,
                                    transitionSpec = {
                                        val forward = targetState > initialState
                                        (slideInHorizontally(
                                            initialOffsetX = { if (forward) it / 3 else -it / 3 },
                                            animationSpec = spring(dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow)
                                        ) + fadeIn(animationSpec = tween(220)))
                                        .togetherWith(
                                            slideOutHorizontally(
                                                targetOffsetX = { if (forward) -it / 4 else it / 4 },
                                                animationSpec = tween(180)
                                            ) + fadeOut(animationSpec = tween(180))
                                        )
                                    },
                                    label = "primaryBottomNavTransition",
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .graphicsLayer {
                                            translationX = swipeOffset.value
                                        }
                                ) { page ->
                                    Box(
                                        modifier = Modifier.fillMaxSize()
                                    ) {
                                        when (page) {
                                            0 -> HomeScreen(
                                                homeData = homeData,
                                                connectionInfo = uiState.connectionInfo,
                                                selectedPersona = uiState.selectedPersona,
                                                selectedLanguage = uiState.language,
                                                onSelectLanguage = { appViewModel.setLanguage(it) },
                                                onSelectPersona = { appViewModel.selectPersona(it) },
                                                onNavigateToRoute = onNavigateToRoute,
                                                onToggleTask = { taskId -> appViewModel.toggleTask(taskId) },
                                                onAddTask = { title, priority -> appViewModel.addNewTask(title, priority) },
                                                onAvatarClick = { isVaultExpanded = !isVaultExpanded }
                                            )
                                            1 -> Column(modifier = Modifier.fillMaxSize()) {
                                                AppTopBar(
                                                    title = "Tasks",
                                                    canNavigateBack = false,
                                                    onNavigateBack = {},
                                                    connectionInfo = uiState.connectionInfo,
                                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                                    isDarkTheme = SoftTheme.colors.isDark,
                                                    userName = uiState.userName,
                                                    onAvatarClick = { isVaultExpanded = true }
                                                )
                                                TasksScreen()
                                            }
                                            2 -> AssistantScreen(
                                                isDarkTheme = SoftTheme.colors.isDark,
                                                onOpenVoiceMode = {
                                                    navController.navigate(Routes.VOICE_MODE) {
                                                        launchSingleTop = true
                                                    }
                                                }
                                            )
                                            3 -> Column(modifier = Modifier.fillMaxSize()) {
                                                AppTopBar(
                                                    title = "Biometric Health",
                                                    canNavigateBack = false,
                                                    onNavigateBack = {},
                                                    connectionInfo = uiState.connectionInfo,
                                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                                    isDarkTheme = SoftTheme.colors.isDark,
                                                    userName = uiState.userName,
                                                    onAvatarClick = { isVaultExpanded = true }
                                                )
                                                HealthScreen(
                                                    healthConnectState = uiState.capabilitiesState.healthConnectState,
                                                    onSetHealthConnectState = { appViewModel.setHealthConnectState(it) }
                                                )
                                            }
                                            4 -> Column(modifier = Modifier.fillMaxSize()) {
                                                AppTopBar(
                                                    title = "System Hub",
                                                    canNavigateBack = false,
                                                    onNavigateBack = {},
                                                    connectionInfo = uiState.connectionInfo,
                                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                                    isDarkTheme = SoftTheme.colors.isDark,
                                                    userName = uiState.userName,
                                                    onAvatarClick = { isVaultExpanded = true }
                                                )
                                                MoreScreen(
                                                    onNavigateToRoute = onNavigateToRoute
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Fallback alias routes to safely handle direct route navigation if any caller uses it
                        composable(Routes.TASKS) {
                            LaunchedEffect(Unit) {
                                previousPageIndex = selectedPageIndex
                                selectedPageIndex = 1
                                navController.popBackStack(Routes.HOME, false)
                            }
                        }
                        composable(Routes.ASSISTANT) {
                            LaunchedEffect(Unit) {
                                previousPageIndex = selectedPageIndex
                                selectedPageIndex = 2
                                navController.popBackStack(Routes.HOME, false)
                            }
                        }
                        composable(Routes.HEALTH) {
                            LaunchedEffect(Unit) {
                                previousPageIndex = selectedPageIndex
                                selectedPageIndex = 3
                                navController.popBackStack(Routes.HOME, false)
                            }
                        }
                        composable(Routes.MORE) {
                            LaunchedEffect(Unit) {
                                previousPageIndex = selectedPageIndex
                                selectedPageIndex = 4
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
                            Column(modifier = Modifier.fillMaxSize()) {
                                AppTopBar(
                                    title = "Schedule",
                                    canNavigateBack = true,
                                    onNavigateBack = { navController.popBackStack() },
                                    connectionInfo = uiState.connectionInfo,
                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                    isDarkTheme = SoftTheme.colors.isDark,
                                    userName = uiState.userName,
                                    onAvatarClick = { isVaultExpanded = true }
                                )
                                ScheduleScreen()
                            }
                        }

                        // SECONDARY DESTINATION: ALARMS (Batch 6)
                        composable(Routes.ALARMS) {
                            Column(modifier = Modifier.fillMaxSize()) {
                                AppTopBar(
                                    title = "Alarms",
                                    canNavigateBack = true,
                                    onNavigateBack = { navController.popBackStack() },
                                    connectionInfo = uiState.connectionInfo,
                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                    isDarkTheme = SoftTheme.colors.isDark,
                                    userName = uiState.userName,
                                    onAvatarClick = { isVaultExpanded = true }
                                )
                                AlarmsScreen(
                                    alarmCapabilityState = uiState.capabilitiesState.alarmCapabilityState,
                                    onSetAlarmCapabilityState = { appViewModel.setAlarmCapabilityState(it) }
                                )
                            }
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
                            Column(modifier = Modifier.fillMaxSize()) {
                                AppTopBar(
                                    title = "Local Models",
                                    canNavigateBack = true,
                                    onNavigateBack = { navController.popBackStack() },
                                    connectionInfo = uiState.connectionInfo,
                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                    isDarkTheme = SoftTheme.colors.isDark,
                                    userName = uiState.userName,
                                    onAvatarClick = { isVaultExpanded = true }
                                )
                                ModelsScreen()
                            }
                        }

                        // SECONDARY DESTINATION: DEVICES (Batch 9)
                        composable(Routes.DEVICES) {
                            Column(modifier = Modifier.fillMaxSize()) {
                                AppTopBar(
                                    title = "Devices",
                                    canNavigateBack = true,
                                    onNavigateBack = { navController.popBackStack() },
                                    connectionInfo = uiState.connectionInfo,
                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                    isDarkTheme = SoftTheme.colors.isDark,
                                    userName = uiState.userName,
                                    onAvatarClick = { isVaultExpanded = true }
                                )
                                DevicesScreen()
                            }
                        }

                        // SECONDARY DESTINATION: MEMORY (Batch 10)
                        composable(Routes.MEMORY) {
                            Column(modifier = Modifier.fillMaxSize()) {
                                AppTopBar(
                                    title = "Memory & Cache",
                                    canNavigateBack = true,
                                    onNavigateBack = { navController.popBackStack() },
                                    connectionInfo = uiState.connectionInfo,
                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                    isDarkTheme = SoftTheme.colors.isDark,
                                    userName = uiState.userName,
                                    onAvatarClick = { isVaultExpanded = true }
                                )
                                MemoryScreen()
                            }
                        }

                        // SECONDARY DESTINATION: CONNECTION & OFFLINE SYNC (Batch 12)
                        composable(Routes.CONNECTION) {
                            ConnectionScreen(
                                connectionInfo = uiState.connectionInfo,
                                onSetConnectionState = { appViewModel.setConnectionState(it) },
                                onSetSyncStatus = { appViewModel.setSyncStatus(it) },
                                onResolveConflict = { appViewModel.resolveSyncConflict(it) },
                                onRetrySync = { appViewModel.retrySync() },
                                onNavigateBack = { navController.popBackStack() },
                                onSaveHostConfig = { host, port, token ->
                                    appViewModel.saveHostConfig(host, port, token)
                                }
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
                            Column(modifier = Modifier.fillMaxSize()) {
                                AppTopBar(
                                    title = "Design System",
                                    canNavigateBack = true,
                                    onNavigateBack = { navController.popBackStack() },
                                    connectionInfo = uiState.connectionInfo,
                                    onCycleConnectionState = { appViewModel.cycleConnectionState() },
                                    isDarkTheme = SoftTheme.colors.isDark,
                                    userName = uiState.userName,
                                    onAvatarClick = { isVaultExpanded = true }
                                )
                                DesignSystemPreviewScreen(
                                    modifier = Modifier.fillMaxSize(),
                                    viewModel = designSystemViewModel
                                )
                            }
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

    Box(modifier = modifier.fillMaxSize()) {
        // Unified persistent background layer (never causes Scaffold recreation on background/theme switches)
        AppBackgroundLayer(
            preferences = preferences,
            showAura = showAura
        )

        // Main app scaffold (STABLE: retains all internal scroll states and backstack)
        renderScaffold()

        // Floating Animated Vault Popover Overlay (Accessible across all screens)
        VaultPopoverOverlay(
            visible = isVaultExpanded,
            onDismiss = { isVaultExpanded = false },
            profileName = uiState.userName,
            connectionInfo = uiState.connectionInfo,
            onNavigateToSettings = {
                if (navHostRoute != Routes.SETTINGS) {
                    navController.navigate(Routes.SETTINGS) { launchSingleTop = true }
                }
            }
        )
    }
}

@Composable
private fun AppBackgroundLayer(
    preferences: AppearancePreferences,
    showAura: Boolean
) {
    if (preferences.themeMode == ThemeMode.OLED_BATTERY_SAVER) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        )
        return
    }

    when (preferences.backgroundType) {
        BackgroundType.BUILT_IN -> {
            val backgroundPreset = preferences.backgroundPreset
            AmbientGlassBackground(
                modifier = Modifier.fillMaxSize(),
                showAuraGlow = showAura,
                primaryGlow = Color(backgroundPreset.primaryGlowHex),
                secondaryGlow = Color(backgroundPreset.secondaryGlowHex),
                scrimOpacity = preferences.scrimOpacity,
                brightness = preferences.backgroundBrightness
            ) {}
        }
        BackgroundType.GRADIENT -> {
            Box(
                modifier = Modifier
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
            }
        }
        BackgroundType.SOLID -> {
            Box(
                modifier = Modifier
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
            }
        }
        BackgroundType.CUSTOM_IMAGE -> {
            val context = LocalContext.current
            val customImageUri = preferences.customImageUri
            val customBitmap = remember(customImageUri) {
                if (customImageUri.isNullOrBlank()) {
                    null
                } else {
                    runCatching {
                        val uri = Uri.parse(customImageUri)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            val source = ImageDecoder.createSource(context.contentResolver, uri)
                            ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                                val maxDim = 1920
                                if (info.size.width > maxDim || info.size.height > maxDim) {
                                    val scale = maxDim.toFloat() / maxOf(info.size.width, info.size.height)
                                    decoder.setTargetSize(
                                        (info.size.width * scale).toInt(),
                                        (info.size.height * scale).toInt()
                                    )
                                }
                            }.asImageBitmap()
                        } else {
                            context.contentResolver.openInputStream(uri)?.use { stream ->
                                BitmapFactory.decodeStream(stream)?.asImageBitmap()
                            }
                        }
                    }.getOrNull()
                }
            }

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(if (SoftTheme.colors.isDark) Color.Black else Color.White)
            ) {
                if (customBitmap != null) {
                    Image(
                        bitmap = customBitmap,
                        contentDescription = "Custom background",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxSize()
                            .blur(
                                radius = if (preferences.effectsLevel == EffectsLevel.REDUCED) 10.dp else 20.dp,
                                edgeTreatment = BlurredEdgeTreatment.Unbounded
                            )
                            .graphicsLayer {
                                alpha = preferences.backgroundBrightness.coerceIn(0.2f, 1.0f)
                            }
                    )
                }
                // Contrast scrim over photo so glass cards remain readable
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            (if (SoftTheme.colors.isDark) Color.Black else Color.White)
                                .copy(alpha = preferences.scrimOpacity.coerceIn(0.1f, 0.7f))
                        )
                )
            }
        }
    }
}

@Composable
private fun VaultPopoverOverlay(
    visible: Boolean,
    onDismiss: () -> Unit,
    profileName: String,
    connectionInfo: ConnectionInfo,
    onNavigateToSettings: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (visible) {
        // Scrim backdrop
        Box(
            modifier = Modifier
                .fillMaxSize()
                .zIndex(90f)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = onDismiss
                )
        )
    }

    androidx.compose.animation.AnimatedVisibility(
        visible = visible,
        modifier = modifier
            .fillMaxWidth()
            .zIndex(100f)
            .statusBarsPadding()
            .padding(top = 56.dp, start = 16.dp, end = 16.dp),
        enter = scaleIn(
            initialScale = 0.85f,
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessMediumLow
            )
        ) + fadeIn(),
        exit = scaleOut(
            targetScale = 0.88f,
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioNoBouncy,
                stiffness = Spring.StiffnessMediumLow
            )
        ) + fadeOut()
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(
                    if (SoftTheme.colors.isDark) Color(0xF2181B22)
                    else Color(0xF5EDF0EB)
                )
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = if (SoftTheme.colors.isDark) Color(0x2EFFFFFF) else Color(0x28000000),
                    shape = RoundedCornerShape(22.dp)
                )
                .padding(20.dp)
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                // Vault Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        SoftAvatar(
                            name = profileName,
                            size = 46.dp,
                            statusColor = when (connectionInfo.state) {
                                CoreConnectionState.Local -> SoftTheme.colors.statusSuccess
                                CoreConnectionState.Remote -> SoftTheme.colors.accentCyan
                                CoreConnectionState.Connecting, CoreConnectionState.Reconnecting -> SoftTheme.colors.statusWarning
                                CoreConnectionState.Offline -> SoftTheme.colors.statusError
                            }
                        )
                        Column {
                            Text(
                                text = profileName.ifBlank { "Companion User" },
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = SoftTheme.colors.textPrimary
                            )
                            Text(
                                text = if (connectionInfo.state == CoreConnectionState.Local || connectionInfo.state == CoreConnectionState.Remote)
                                    "Encrypted Vault Online"
                                else "Local SQLite Vault (Offline)",
                                style = MaterialTheme.typography.bodySmall,
                                color = SoftTheme.colors.textSecondary
                            )
                        }
                    }

                    Box(modifier = Modifier.testTag("topbar_connection_indicator")) {
                        CompactConnectionIndicator(
                            state = connectionInfo.state,
                            label = connectionInfo.label,
                            latencyMs = connectionInfo.latencyMs
                        )
                    }
                }

                HorizontalDivider(color = SoftTheme.colors.borderSubtle)

                // Quick Action: Settings
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.sm))
                        .clickable {
                            onDismiss()
                            onNavigateToSettings()
                        }
                        .padding(vertical = SoftTheme.spacing.xs),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentPrimaryColor,
                        modifier = Modifier.size(20.dp)
                    )
                    Text(
                        text = "Open Settings & Preferences",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = SoftTheme.colors.accentPrimaryColor
                    )
                }
            }
        }
    }
}
