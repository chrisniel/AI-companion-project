package com.example.domain.model

import java.util.UUID

/**
 * Origin of a conversational message.
 */
enum class MessageSender {
    USER,
    ASSISTANT,
    SYSTEM
}

/**
 * Execution state for autonomous tool invocations.
 */
enum class ToolExecutionStatus {
    RUNNING,
    SUCCESS,
    FAILED
}

/**
 * Individual vector match in a local semantic search.
 */
data class SearchResultItem(
    val title: String,
    val snippet: String,
    val similarityScore: Float,
    val sourcePath: String
)

/**
 * Sealed payload representing all supported conversation item types:
 * - User message
 * - Assistant response
 * - Tool action
 * - Memory retrieval
 * - Search result
 * - Warning
 * - Error
 * - System status
 */
sealed interface MessagePayload {
    data class User(
        val text: String,
        val attachments: List<String> = emptyList()
    ) : MessagePayload

    data class Assistant(
        val text: String,
        val modelName: String = "Llama-3.2-3B",
        val tokensCount: Int = 142,
        val tokensPerSec: Float = 32.4f,
        val latencyMs: Long = 18,
        val isStreaming: Boolean = false
    ) : MessagePayload

    data class ToolAction(
        val toolName: String,
        val functionSignature: String,
        val argumentsJson: String,
        val outputSnippet: String,
        val status: ToolExecutionStatus = ToolExecutionStatus.SUCCESS,
        val executionTimeMs: Long = 24
    ) : MessagePayload

    data class MemoryRetrieval(
        val query: String,
        val memoryKey: String,
        val retrievedFact: String,
        val confidenceScore: Float = 0.94f,
        val category: String = "Semantic Recall"
    ) : MessagePayload

    data class SearchResult(
        val query: String,
        val matchedChunksCount: Int = 3,
        val topResults: List<SearchResultItem> = emptyList()
    ) : MessagePayload

    data class Warning(
        val message: String,
        val warningCode: String = "GPU_THERMAL_82C",
        val details: String? = null
    ) : MessagePayload

    data class Error(
        val message: String,
        val errorCode: String = "TIMEOUT_504",
        val canRetry: Boolean = true
    ) : MessagePayload

    data class SystemStatus(
        val text: String,
        val category: String = "TELEMETRY",
        val timestamp: String = "Now"
    ) : MessagePayload
}

/**
 * Full chat item model stored per conversation.
 */
data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val conversationId: String,
    val timestamp: String,
    val sender: MessageSender,
    val payload: MessagePayload,
    val languageOption: LanguageOption = LanguageOption.AUTO
)

/**
 * Local AI Core provider routing modes (Local / Remote / Offline).
 */
data class ProviderMode(
    val id: String,
    val name: String,
    val nodeHost: String,
    val state: CoreConnectionState,
    val description: String
) {
    companion object {
        val LocalLlama = ProviderMode(
            id = "llama_local",
            name = "Local AI Core (PC)",
            nodeHost = "Local Network (PC Host)",
            state = CoreConnectionState.Local,
            description = "Primary Local AI Core running on Windows PC over local network."
        )

        val OllamaLan = ProviderMode(
            id = "ollama_lan",
            name = "Workstation LAN Core",
            nodeHost = "Direct LAN (PC Host)",
            state = CoreConnectionState.Local,
            description = "High-throughput PC host over low-latency local Wi-Fi."
        )

        val RemoteTunnel = ProviderMode(
            id = "remote_core",
            name = "Remote AI Core (PC)",
            nodeHost = "Encrypted Remote Tunnel",
            state = CoreConnectionState.Remote,
            description = "Windows PC Local AI Core reached via encrypted remote tunnel."
        )

        val OfflineFallback = ProviderMode(
            id = "offline_mode",
            name = "Companion Standby",
            nodeHost = "Standalone Android Client",
            state = CoreConnectionState.Offline,
            description = "Offline companion client mode. Mirrored alarms, cached tasks, schedules, and health remain armed locally."
        )

        val ALL_MODES = listOf(LocalLlama, OllamaLan, RemoteTunnel, OfflineFallback)
    }
}

/**
 * Summary record for recent conversation history.
 */
data class Conversation(
    val id: String,
    val title: String,
    val previewSnippet: String,
    val updatedAt: String,
    val messageCount: Int,
    val providerMode: ProviderMode = ProviderMode.LocalLlama
)

/**
 * Immutable UI State for the Assistant Workspace.
 */
data class AssistantUiState(
    val currentConversation: Conversation,
    val conversations: List<Conversation> = emptyList(),
    val messages: List<ChatMessage> = emptyList(),
    val isGenerating: Boolean = false,
    val inputText: String = "",
    val selectedLanguage: LanguageOption = LanguageOption.AUTO,
    val providerMode: ProviderMode = ProviderMode.LocalLlama,
    val isHistorySheetOpen: Boolean = false,
    val isProviderPickerOpen: Boolean = false,
    val historySearchQuery: String = "",
    val attachments: List<String> = emptyList(),
    val isMicrophoneActive: Boolean = false,
    val availableLanguages: List<LanguageOption> = listOf(
        LanguageOption.AUTO,
        LanguageOption.ENGLISH,
        LanguageOption.FILIPINO,
        LanguageOption.JAPANESE
    ),
    val availableProviderModes: List<ProviderMode> = ProviderMode.ALL_MODES
)
