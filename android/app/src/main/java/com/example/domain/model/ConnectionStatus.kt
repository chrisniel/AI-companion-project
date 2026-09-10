package com.example.domain.model

enum class CoreConnectionState(val displayName: String) {
    Local("Local LAN"),
    Remote("Remote"),
    Connecting("Connecting"),
    Reconnecting("Reconnecting"),
    Offline("Offline");

    val isOnline: Boolean get() = this == Local || this == Remote
    val isLocalLan: Boolean get() = this == Local
    val isRemote: Boolean get() = this == Remote
    val isConnecting: Boolean get() = this == Connecting
    val isReconnecting: Boolean get() = this == Reconnecting
    val isOffline: Boolean get() = this == Offline

    // Backwards-compatible aliases for existing preview screens
    companion object {
        val Online: CoreConnectionState get() = Local
        val Standby: CoreConnectionState get() = Remote
        val Error: CoreConnectionState get() = Offline
    }
}

/**
 * Mobile synchronization states between phone cache and Local AI Core PC.
 */
enum class SyncStatus(
    val label: String,
    val description: String
) {
    SYNCHRONIZED(
        label = "Synchronized",
        description = "All local changes synchronized with Local AI Core PC."
    ),
    PENDING(
        label = "Sync Pending",
        description = "Local updates queued. Waiting for secure LAN handshake."
    ),
    CONFLICT(
        label = "Sync Conflict",
        description = "Local edits preserved. Manual resolution available."
    ),
    STALE(
        label = "Cache Stale",
        description = "Viewing cached mobile data. Last verified 4 hours ago."
    ),
    FAILED(
        label = "Sync Failed",
        description = "Synchronization interrupted. Will retry when connection resumes."
    );

    val isSynchronized: Boolean get() = this == SYNCHRONIZED
    val isPending: Boolean get() = this == PENDING
    val isConflict: Boolean get() = this == CONFLICT
    val isStale: Boolean get() = this == STALE
    val isFailed: Boolean get() = this == FAILED
}

data class ConnectionInfo(
    val state: CoreConnectionState = CoreConnectionState.Local,
    val label: String = "Core Active",
    val latencyMs: Int? = 22,
    val port: Int? = 8080,
    val host: String = "127.0.0.1",
    val syncStatus: SyncStatus = SyncStatus.SYNCHRONIZED,
    val lastSyncTimestamp: String = "Just now",
    val pendingChangesCount: Int = 0,
    val isCloudFallbackEnabled: Boolean = false // Future setting only, strictly disabled
)

/**
 * Communicates which functionality remains available locally when PC is Offline.
 */
data class OfflineCapabilityItem(
    val title: String,
    val description: String,
    val isAvailableOffline: Boolean,
    val iconKey: String
)

object OfflineFeatureMatrix {
    val availableOffline = listOf(
        OfflineCapabilityItem(
            title = "Mirrored Alarms",
            description = "Local hardware timer, wakelocks, and independent sound playback",
            isAvailableOffline = true,
            iconKey = "alarm"
        ),
        OfflineCapabilityItem(
            title = "Cached Tasks",
            description = "Browse tasks, check off items, and create and manage local cached entries",
            isAvailableOffline = true,
            iconKey = "tasks"
        ),
        OfflineCapabilityItem(
            title = "Cached Schedule",
            description = "View cached timeline events, routines, and scheduled agenda",
            isAvailableOffline = true,
            iconKey = "schedule"
        ),
        OfflineCapabilityItem(
            title = "Health Connect Data",
            description = "Step counter, heart rate telemetry, and on-device wellness logs",
            isAvailableOffline = true,
            iconKey = "health"
        ),
        OfflineCapabilityItem(
            title = "Settings & Customization",
            description = "Themes, accents, glass effects, language preferences, and mock configs",
            isAvailableOffline = true,
            iconKey = "settings"
        )
    )

    val unavailableOffline = listOf(
        OfflineCapabilityItem(
            title = "Local AI Assistant",
            description = "Conversational dialogue and real-time streaming LLM inference",
            isAvailableOffline = false,
            iconKey = "assistant"
        ),
        OfflineCapabilityItem(
            title = "PC Tools & Automation",
            description = "Desktop app launch, terminal commands, and system control",
            isAvailableOffline = false,
            iconKey = "tools"
        ),
        OfflineCapabilityItem(
            title = "Model Execution",
            description = "Host PC GPU inference (Local LLM, Whisper, Kokoro TTS)",
            isAvailableOffline = false,
            iconKey = "models"
        )
    )
}


