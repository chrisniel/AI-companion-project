package com.example.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Route constants for Navigation Compose.
 */
object Routes {
    // Primary 5 Bottom Navigation Destinations
    const val HOME = "home"
    const val ASSISTANT = "assistant"
    const val TASKS = "tasks"
    const val HEALTH = "health"
    const val MORE = "more"

    // Dedicated Voice Mode
    const val VOICE_MODE = "voice_mode"

    // Sub-destinations reachable from More
    const val SCHEDULE = "more/schedule"
    const val ALARMS = "more/alarms"
    const val CHARACTERS = "more/characters"
    const val MODELS = "more/models"
    const val DEVICES = "more/devices"
    const val MEMORY = "more/memory"
    const val SETTINGS = "more/settings"
    const val CONNECTION = "more/connection"
    const val ABOUT = "more/about"
    const val PERMISSIONS = "more/permissions"

    // Design System Catalog for developer review
    const val DESIGN_SYSTEM = "more/design_system"
}

/**
 * Primary navigation item definition for the bottom navigation bar.
 */
sealed class BottomNavItem(
    val route: String,
    val title: String,
    val icon: ImageVector,
    val testTag: String,
    val pageIndex: Int
) {
    data object Home : BottomNavItem(Routes.HOME, "Home", Icons.Default.Home, "nav_item_home", 0)
    data object Tasks : BottomNavItem(Routes.TASKS, "Tasks", Icons.Default.TaskAlt, "nav_item_tasks", 1)
    data object Assistant : BottomNavItem(Routes.ASSISTANT, "Assistant", Icons.Default.AutoAwesome, "nav_item_assistant", 2)
    data object Health : BottomNavItem(Routes.HEALTH, "Health", Icons.Default.Favorite, "nav_item_health", 3)
    data object More : BottomNavItem(Routes.MORE, "More", Icons.Default.MoreHoriz, "nav_item_more", 4)

    companion object {
        val items = listOf(Home, Tasks, Assistant, Health, More)

        fun fromPageIndex(index: Int): BottomNavItem =
            items.getOrElse(index.coerceIn(0, items.size - 1)) { Home }

        fun fromRoute(route: String?): BottomNavItem? =
            items.find { it.route == route }

        fun getPageIndexForRoute(route: String?): Int? =
            fromRoute(route)?.pageIndex
    }
}

/**
 * Secondary destination item for the More hub screen.
 */
data class MoreDestination(
    val route: String,
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
    val badgeText: String? = null,
    val testTag: String
)

/**
 * Logical section grouping for destinations in the More hub.
 */
data class MoreSection(
    val title: String,
    val items: List<MoreDestination>
)

object MoreDestinations {
    // 1. Time & Agenda
    val timeSection = MoreSection(
        title = "TIME & AGENDA",
        items = listOf(
            MoreDestination(
                route = Routes.SCHEDULE,
                title = "Schedule",
                subtitle = "Daily timeline, agenda, and planned local events",
                icon = Icons.Default.CalendarMonth,
                badgeText = "3 Today",
                testTag = "more_item_schedule"
            ),
            MoreDestination(
                route = Routes.ALARMS,
                title = "Alarms",
                subtitle = "Smart wake-up schedules and timers",
                icon = Icons.Default.Alarm,
                badgeText = "07:00 AM",
                testTag = "more_item_alarms"
            )
        )
    )

    // 2. AI & Agents
    val aiSection = MoreSection(
        title = "AI & AGENTS",
        items = listOf(
            MoreDestination(
                route = Routes.CHARACTERS,
                title = "Characters",
                subtitle = "Persona profiles, tones, and behavioral prompts",
                icon = Icons.Default.Psychology,
                badgeText = "5 Local",
                testTag = "more_item_characters"
            ),
            MoreDestination(
                route = Routes.MEMORY,
                title = "Memory",
                subtitle = "Personal facts, preferences, and long-term context",
                icon = Icons.Default.Storage,
                badgeText = "8 Records",
                testTag = "more_item_memory"
            )
        )
    )

    // 3. System & Hardware
    val hardwareSection = MoreSection(
        title = "SYSTEM & HARDWARE",
        items = listOf(
            MoreDestination(
                route = Routes.MODELS,
                title = "Models",
                subtitle = "Mobile runtime, performance profiles, and routing",
                icon = Icons.Default.Memory,
                badgeText = "Balanced",
                testTag = "more_item_models"
            ),
            MoreDestination(
                route = Routes.DEVICES,
                title = "Devices",
                subtitle = "Local AI Core PC, Phone, audio, and health endpoints",
                icon = Icons.Default.Devices,
                badgeText = "5 Online",
                testTag = "more_item_devices"
            ),
            MoreDestination(
                route = Routes.CONNECTION,
                title = "Connection",
                subtitle = "Local network node discovery, mTLS, and pairing",
                icon = Icons.Default.Wifi,
                badgeText = "Online",
                testTag = "more_item_connection"
            )
        )
    )

    // 4. Application & System
    val appSection = MoreSection(
        title = "APPLICATION & SYSTEM",
        items = listOf(
            MoreDestination(
                route = Routes.SETTINGS,
                title = "Settings",
                subtitle = "Theme, voice behavior, offline sync, and preferences",
                icon = Icons.Default.Settings,
                testTag = "more_item_settings"
            ),
            MoreDestination(
                route = Routes.PERMISSIONS,
                title = "Permissions & Capabilities",
                subtitle = "Microphone, notifications, Health Connect, exact alarms",
                icon = Icons.Default.Security,
                badgeText = "Audit",
                testTag = "more_item_permissions"
            ),
            MoreDestination(
                route = Routes.ABOUT,
                title = "About",
                subtitle = "Local AI Core v1.5 • Privacy architecture and build",
                icon = Icons.Default.Info,
                badgeText = "v1.5",
                testTag = "more_item_about"
            )
        )
    )

    val sections = listOf(timeSection, aiSection, hardwareSection, appSection)

    val items = sections.flatMap { it.items }
}
