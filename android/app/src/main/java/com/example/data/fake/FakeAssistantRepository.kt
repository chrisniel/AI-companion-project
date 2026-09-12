package com.example.data.fake

import com.example.domain.model.AssistantUiState
import com.example.domain.model.ChatMessage
import com.example.domain.model.Conversation
import com.example.domain.model.LanguageOption
import com.example.domain.model.MessagePayload
import com.example.domain.model.MessageSender
import com.example.domain.model.ProviderMode
import com.example.domain.model.SearchResultItem
import com.example.domain.model.ToolExecutionStatus
import com.example.domain.repository.AssistantRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * Fake implementation of AssistantRepository providing rich mock interactions
 * for all 8 conversation types, mixed-language code-switching, history drawers,
 * and generation states without external network dependencies.
 */
class FakeAssistantRepository(
    private val coroutineScope: CoroutineScope = CoroutineScope(Dispatchers.Main)
) : AssistantRepository {

    private var activeGenerationJob: Job? = null

    private val defaultConversations = listOf(
        Conversation(
            id = "conv_1",
            title = "Local Assistant",
            previewSnippet = "Android UIをチェックしました！ All Soft Glass tokens conform to PC specs...",
            updatedAt = "Just now",
            messageCount = 10,
            providerMode = ProviderMode.LocalLlama
        ),
        Conversation(
            id = "conv_2",
            title = "Daily Standup & Schedule",
            previewSnippet = "Ashita check natin ito before the team review...",
            updatedAt = "10:15 AM",
            messageCount = 4,
            providerMode = ProviderMode.OllamaLan
        ),
        Conversation(
            id = "conv_3",
            title = "Mixed Code-Switching QA",
            previewSnippet = "Remind me bukas at seven to run battery diagnostics...",
            updatedAt = "Yesterday",
            messageCount = 6,
            providerMode = ProviderMode.LocalLlama
        ),
        Conversation(
            id = "conv_4",
            title = "Local Travel & Weather Prep",
            previewSnippet = "Naka-set na yung reminder for your umbrella bukas, cloudy sky expected...",
            updatedAt = "2 days ago",
            messageCount = 5,
            providerMode = ProviderMode.RemoteTunnel
        ),
        Conversation(
            id = "conv_5",
            title = "Offline Slot Commands",
            previewSnippet = "Standby rule parser handled timer and local alarms...",
            updatedAt = "Sep 3",
            messageCount = 3,
            providerMode = ProviderMode.OfflineFallback
        )
    )

    private val conversationMessageStore = mutableMapOf<String, MutableList<ChatMessage>>(
        "conv_1" to createInitialMessagesForConv1(),
        "conv_2" to mutableListOf(
            ChatMessage(
                id = "m_2_1",
                conversationId = "conv_2",
                timestamp = "10:10 AM",
                sender = MessageSender.SYSTEM,
                payload = MessagePayload.SystemStatus("Session connected to LAN Node via Direct Private LAN", category = "LAN")
            ),
            ChatMessage(
                id = "m_2_2",
                conversationId = "conv_2",
                timestamp = "10:12 AM",
                sender = MessageSender.USER,
                payload = MessagePayload.User("Ashita check natin ito before the team review.")
            ),
            ChatMessage(
                id = "m_2_3",
                conversationId = "conv_2",
                timestamp = "10:13 AM",
                sender = MessageSender.ASSISTANT,
                payload = MessagePayload.Assistant(
                    text = "Roger that! Ashita umaga natin i-review yung summary deck. Naglagay ako ng 15-minute buffer sa schedule mo at 9:15 AM.",
                    modelName = "Qwen-2.5-14B",
                    tokensCount = 38,
                    tokensPerSec = 45.2f,
                    latencyMs = 12
                )
            )
        )
    )

    private val _uiState = MutableStateFlow(
        AssistantUiState(
            currentConversation = defaultConversations.first(),
            conversations = defaultConversations,
            messages = conversationMessageStore["conv_1"] ?: emptyList(),
            providerMode = defaultConversations.first().providerMode
        )
    )
    override val uiState: StateFlow<AssistantUiState> = _uiState.asStateFlow()

    override fun selectConversation(conversationId: String) {
        val selected = _uiState.value.conversations.find { it.id == conversationId }
            ?: return
        val messages = conversationMessageStore[conversationId] ?: mutableListOf()

        _uiState.update { current ->
            current.copy(
                currentConversation = selected,
                messages = messages.toList(),
                providerMode = selected.providerMode,
                isHistorySheetOpen = false,
                isGenerating = false
            )
        }
    }

    override fun createNewConversation(title: String) {
        val newId = "conv_${System.currentTimeMillis()}"
        val newConv = Conversation(
            id = newId,
            title = if (title.isBlank()) "Local Assistant" else title,
            previewSnippet = "New session started...",
            updatedAt = "Just now",
            messageCount = 1,
            providerMode = _uiState.value.providerMode
        )
        val initialMessages = mutableListOf(
            ChatMessage(
                id = UUID.randomUUID().toString(),
                conversationId = newId,
                timestamp = getCurrentTimeFormatted(),
                sender = MessageSender.SYSTEM,
                payload = MessagePayload.SystemStatus(
                    text = "Session initialized with ${_uiState.value.providerMode.name} • Zero cloud telemetry",
                    category = "ISOLATION"
                )
            )
        )
        conversationMessageStore[newId] = initialMessages

        _uiState.update { current ->
            current.copy(
                currentConversation = newConv,
                conversations = listOf(newConv) + current.conversations,
                messages = initialMessages.toList(),
                inputText = "",
                attachments = emptyList(),
                isHistorySheetOpen = false,
                isGenerating = false
            )
        }
    }

    override fun deleteConversation(conversationId: String) {
        conversationMessageStore.remove(conversationId)
        _uiState.update { current ->
            val updatedList = current.conversations.filterNot { it.id == conversationId }
            val nextConv = if (current.currentConversation.id == conversationId) {
                updatedList.firstOrNull() ?: Conversation(
                    id = "conv_default",
                    title = "Local Assistant",
                    previewSnippet = "Empty session",
                    updatedAt = "Now",
                    messageCount = 0
                )
            } else {
                current.currentConversation
            }
            current.copy(
                conversations = updatedList,
                currentConversation = nextConv,
                messages = (conversationMessageStore[nextConv.id] ?: emptyList()).toList()
            )
        }
    }

    override fun setHistorySearchQuery(query: String) {
        _uiState.update { it.copy(historySearchQuery = query) }
    }

    override fun toggleHistorySheet(isOpen: Boolean) {
        _uiState.update { it.copy(isHistorySheetOpen = isOpen) }
    }

    override fun toggleProviderPicker(isOpen: Boolean) {
        _uiState.update { it.copy(isProviderPickerOpen = isOpen) }
    }

    override fun updateInputText(text: String) {
        _uiState.update { it.copy(inputText = text) }
    }

    override fun selectLanguage(language: LanguageOption) {
        _uiState.update { it.copy(selectedLanguage = language) }
    }

    override fun switchProviderMode(mode: ProviderMode) {
        _uiState.update { current ->
            current.copy(
                providerMode = mode,
                currentConversation = current.currentConversation.copy(providerMode = mode),
                isProviderPickerOpen = false
            )
        }
    }

    override fun toggleMicrophone(active: Boolean?) {
        _uiState.update { current ->
            val newActive = active ?: !current.isMicrophoneActive
            // If turning mic on, optionally populate with a realistic sample speech text
            val newText = if (newActive && current.inputText.isBlank()) {
                "Remind me bukas."
            } else {
                current.inputText
            }
            current.copy(
                isMicrophoneActive = newActive,
                inputText = newText
            )
        }
    }

    override fun addAttachment(fileName: String) {
        _uiState.update { current ->
            if (!current.attachments.contains(fileName)) {
                current.copy(attachments = current.attachments + fileName)
            } else {
                current
            }
        }
    }

    override fun removeAttachment(fileName: String) {
        _uiState.update { current ->
            current.copy(attachments = current.attachments.filterNot { it == fileName })
        }
    }

    override fun sendMessage(customText: String?) {
        val textToSend = customText ?: _uiState.value.inputText
        if (textToSend.isBlank() && _uiState.value.attachments.isEmpty()) return

        val convId = _uiState.value.currentConversation.id
        val userAttachments = _uiState.value.attachments
        val timeNow = getCurrentTimeFormatted()

        val userMessage = ChatMessage(
            id = UUID.randomUUID().toString(),
            conversationId = convId,
            timestamp = timeNow,
            sender = MessageSender.USER,
            payload = MessagePayload.User(
                text = textToSend,
                attachments = userAttachments
            ),
            languageOption = _uiState.value.selectedLanguage
        )

        // Append to store
        val convMessages = conversationMessageStore.getOrPut(convId) { mutableListOf() }
        convMessages.add(userMessage)

        // Clear composer state & set isGenerating
        _uiState.update { current ->
            current.copy(
                inputText = "",
                attachments = emptyList(),
                isMicrophoneActive = false,
                isGenerating = true,
                messages = convMessages.toList()
            )
        }

        // Trigger simulated local assistant generation
        simulateAssistantResponse(convId, textToSend, _uiState.value.selectedLanguage)
    }

    override fun stopGeneration() {
        activeGenerationJob?.cancel()
        activeGenerationJob = null

        val convId = _uiState.value.currentConversation.id
        val convMessages = conversationMessageStore[convId] ?: return

        val lastIndex = convMessages.indexOfLast { it.sender == MessageSender.ASSISTANT }
        if (lastIndex >= 0) {
            val lastMsg = convMessages[lastIndex]
            val payload = lastMsg.payload
            if (payload is MessagePayload.Assistant && payload.isStreaming) {
                convMessages[lastIndex] = lastMsg.copy(
                    payload = payload.copy(
                        text = payload.text + " [Generation halted by user]",
                        isStreaming = false
                    )
                )
            }
        }

        _uiState.update { current ->
            current.copy(
                isGenerating = false,
                messages = convMessages.toList()
            )
        }
    }

    override fun retryLastMessage() {
        val convId = _uiState.value.currentConversation.id
        val convMessages = conversationMessageStore[convId] ?: return

        // Find last user message
        val lastUserMsg = convMessages.findLast { it.sender == MessageSender.USER }
        val promptText = if (lastUserMsg?.payload is MessagePayload.User) {
            (lastUserMsg.payload as MessagePayload.User).text
        } else {
            "Retry local operation"
        }

        _uiState.update { it.copy(isGenerating = true) }
        simulateAssistantResponse(convId, promptText, _uiState.value.selectedLanguage)
    }

    private fun simulateAssistantResponse(
        convId: String,
        prompt: String,
        language: LanguageOption
    ) {
        activeGenerationJob?.cancel()
        activeGenerationJob = coroutineScope.launch {
            val lowerPrompt = prompt.lowercase()

            // Construct contextual response based on prompt & language
            val responseText = when {
                lowerPrompt.contains("bukas") || lowerPrompt.contains("remind") -> {
                    "Nakatala na yung paalala mo bukas. In-index ko na ito sa local scheduler para walang makaligtaan bago ang araw."
                }
                lowerPrompt.contains("ui") || lowerPrompt.contains("チェック") || lowerPrompt.contains("check") -> {
                    "Android UIをチェックしました！ All Soft Glass components, spacing tokens, and contrasts comply with the PC Control Center guidelines."
                }
                lowerPrompt.contains("ashita") -> {
                    "Roger that! Ashita umaga natin i-review ito. Naka-save na sa local memory log."
                }
                language == LanguageOption.FILIPINO -> {
                    "Sige, na-process na ng Local Core ang iyong request. Nananatiling pribado ang lahat ng data sa iyong device."
                }
                language == LanguageOption.JAPANESE -> {
                    "了解しました。ローカルモデルで処理を実行しました。すべてのデータはデバイス内に保持されています。"
                }
                else -> {
                    "Processed successfully via ${_uiState.value.providerMode.name}. Zero token leakage occurred outside this device."
                }
            }

            // Create streaming assistant message
            val assistantMsgId = UUID.randomUUID().toString()
            val convMessages = conversationMessageStore.getOrPut(convId) { mutableListOf() }

            val streamingMessage = ChatMessage(
                id = assistantMsgId,
                conversationId = convId,
                timestamp = getCurrentTimeFormatted(),
                sender = MessageSender.ASSISTANT,
                payload = MessagePayload.Assistant(
                    text = "",
                    modelName = _uiState.value.providerMode.name.substringBefore(" "),
                    isStreaming = true
                ),
                languageOption = language
            )
            convMessages.add(streamingMessage)

            _uiState.update { current ->
                current.copy(messages = convMessages.toList())
            }

            // Simulate stream chunks
            val words = responseText.split(" ")
            val accumulated = StringBuilder()

            for (i in words.indices) {
                delay(40) // Smooth mock token streaming
                accumulated.append(words[i]).append(" ")
                val currentText = accumulated.toString().trimEnd()

                val msgIndex = convMessages.indexOfFirst { it.id == assistantMsgId }
                if (msgIndex >= 0) {
                    convMessages[msgIndex] = streamingMessage.copy(
                        payload = MessagePayload.Assistant(
                            text = currentText,
                            modelName = _uiState.value.providerMode.name.substringBefore(" "),
                            tokensCount = (i + 1) * 3,
                            tokensPerSec = 34.2f,
                            latencyMs = 18,
                            isStreaming = i < words.size - 1
                        )
                    )
                }

                _uiState.update { current ->
                    current.copy(messages = convMessages.toList())
                }
            }

            // Completed streaming
            _uiState.update { current ->
                current.copy(
                    isGenerating = false,
                    messages = convMessages.toList()
                )
            }
        }
    }

    private fun getCurrentTimeFormatted(): String {
        return SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date())
    }

    companion object {
        private fun createInitialMessagesForConv1(): MutableList<ChatMessage> {
            return mutableListOf(
                // 1. SYSTEM STATUS
                ChatMessage(
                    id = "msg_01",
                    conversationId = "conv_1",
                    timestamp = "10:38 AM",
                    sender = MessageSender.SYSTEM,
                    payload = MessagePayload.SystemStatus(
                        text = "Local Core engine initialized • Model: Llama-3.2-3B Q4_K_M (4.9 GB) • Zero external telemetry",
                        category = "SYSTEM READY",
                        timestamp = "10:38 AM"
                    )
                ),
                // 2. USER MESSAGE
                ChatMessage(
                    id = "msg_02",
                    conversationId = "conv_1",
                    timestamp = "10:39 AM",
                    sender = MessageSender.USER,
                    payload = MessagePayload.User(
                        text = "Remind me bukas at 7am to check the battery telemetry."
                    ),
                    languageOption = LanguageOption.AUTO
                ),
                // 3. MEMORY RETRIEVAL
                ChatMessage(
                    id = "msg_03",
                    conversationId = "conv_1",
                    timestamp = "10:39 AM",
                    sender = MessageSender.SYSTEM,
                    payload = MessagePayload.MemoryRetrieval(
                        query = "user_preference_language",
                        memoryKey = "code_switch_profile",
                        retrievedFact = "User communicates in mixed English-Tagalog for daily scheduling routines",
                        confidenceScore = 0.96f,
                        category = "Semantic Profile"
                    )
                ),
                // 4. TOOL ACTION
                ChatMessage(
                    id = "msg_04",
                    conversationId = "conv_1",
                    timestamp = "10:39 AM",
                    sender = MessageSender.SYSTEM,
                    payload = MessagePayload.ToolAction(
                        toolName = "LocalCore.Scheduler",
                        functionSignature = "schedule_alarm(time=\"07:00\", label=\"Battery Telemetry Check\", repeat=\"none\")",
                        argumentsJson = "{\n  \"time\": \"07:00\",\n  \"label\": \"Battery Telemetry Check\",\n  \"source\": \"local_device\"\n}",
                        outputSnippet = "SUCCESS: Alarm scheduled for tomorrow at 07:00 AM (Job ID: sched_4920)",
                        status = ToolExecutionStatus.SUCCESS,
                        executionTimeMs = 18
                    )
                ),
                // 5. ASSISTANT RESPONSE
                ChatMessage(
                    id = "msg_05",
                    conversationId = "conv_1",
                    timestamp = "10:40 AM",
                    sender = MessageSender.ASSISTANT,
                    payload = MessagePayload.Assistant(
                        text = "Nakatala na yung alarm mo bukas ng 7:00 AM para sa battery telemetry check. Naka-link na rin ito sa morning status log.",
                        modelName = "Llama-3.2-3B",
                        tokensCount = 42,
                        tokensPerSec = 34.1f,
                        latencyMs = 18
                    ),
                    languageOption = LanguageOption.FILIPINO
                ),
                // 6. USER MESSAGE
                ChatMessage(
                    id = "msg_06",
                    conversationId = "conv_1",
                    timestamp = "10:41 AM",
                    sender = MessageSender.USER,
                    payload = MessagePayload.User(
                        text = "Android UIをチェック. Make sure the Soft Glass tokens align with the PC version."
                    ),
                    languageOption = LanguageOption.JAPANESE
                ),
                // 7. SEARCH RESULT
                ChatMessage(
                    id = "msg_07",
                    conversationId = "conv_1",
                    timestamp = "10:41 AM",
                    sender = MessageSender.SYSTEM,
                    payload = MessagePayload.SearchResult(
                        query = "Soft Glass tokens PC specification",
                        matchedChunksCount = 2,
                        topResults = listOf(
                            SearchResultItem(
                                title = "tokens/glass_spec.json",
                                snippet = "Card background #1E2235 (18% alpha), blurRadius: 20dp, border: #3B82F6 (15% alpha)",
                                similarityScore = 0.94f,
                                sourcePath = "local_core/docs/tokens.json"
                            ),
                            SearchResultItem(
                                title = "ui/surfaces.kt",
                                snippet = "Elevations: flat=0dp, subtle=2dp, raised=4dp with inset highlights",
                                similarityScore = 0.89f,
                                sourcePath = "src/ui/surfaces.kt"
                            )
                        )
                    )
                ),
                // 8. ASSISTANT RESPONSE
                ChatMessage(
                    id = "msg_08",
                    conversationId = "conv_1",
                    timestamp = "10:41 AM",
                    sender = MessageSender.ASSISTANT,
                    payload = MessagePayload.Assistant(
                        text = "Android UIをチェックしました！ All Soft Glass tokens conform to the PC Control Center specification: 16dp corner radiuses, translucent border highlights, and subtle depth elevation. Ready for production.",
                        modelName = "Llama-3.2-3B",
                        tokensCount = 54,
                        tokensPerSec = 31.8f,
                        latencyMs = 22
                    ),
                    languageOption = LanguageOption.AUTO
                ),
                // 9. WARNING
                ChatMessage(
                    id = "msg_09",
                    conversationId = "conv_1",
                    timestamp = "10:42 AM",
                    sender = MessageSender.SYSTEM,
                    payload = MessagePayload.Warning(
                        message = "Local AI Core PC is running on battery power. Background indexing paused to preserve power.",
                        warningCode = "CORE_POWER_SAVER",
                        details = "Compute node switching to balanced power profile"
                    )
                ),
                // 10. ERROR
                ChatMessage(
                    id = "msg_10",
                    conversationId = "conv_1",
                    timestamp = "10:43 AM",
                    sender = MessageSender.SYSTEM,
                    payload = MessagePayload.Error(
                        message = "Connection timed out to desktop LAN node. Local mobile offline mode active with on-device memory.",
                        errorCode = "TIMEOUT_504",
                        canRetry = true
                    )
                )
            )
        }
    }
}
