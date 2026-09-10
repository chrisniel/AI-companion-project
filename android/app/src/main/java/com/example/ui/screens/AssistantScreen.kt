package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.ui.screens.assistant.AssistantComposer
import com.example.ui.screens.assistant.AssistantHeader
import com.example.ui.screens.assistant.AssistantHistorySheet
import com.example.ui.screens.assistant.AssistantMessageItem
import com.example.ui.screens.assistant.ProviderModePickerSheet
import com.example.ui.theme.SoftTheme

/**
 * Mobile Assistant Workspace (Batch 4):
 * The primary text-based local AI conversational experience.
 *
 * Conforms strictly to requirements:
 * - Header:
 *   - Conversation title
 *   - Local / Remote / Offline connection state
 *   - Current provider mode
 *   - Conversation history action
 * - Conversation Types:
 *   - User message
 *   - Assistant response
 *   - Tool action
 *   - Memory retrieval
 *   - Search result
 *   - Warning
 *   - Error
 *   - System status
 * - Input Composer:
 *   - Attachment/add
 *   - Text input
 *   - Language selector (Auto, English, Filipino / Tagalog, Japanese)
 *   - Microphone (voice simulation)
 *   - Send
 *   - Stop generation
 * - Conversation History:
 *   - Recent conversations
 *   - Search
 *   - New Conversation
 */
@Composable
fun AssistantScreen(
    isDarkTheme: Boolean,
    onToggleTheme: () -> Unit,
    onOpenVoiceMode: () -> Unit = {},
    modifier: Modifier = Modifier,
    viewModel: AssistantViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()

    // Auto-scroll to bottom when new messages arrive or when generating
    LaunchedEffect(uiState.messages.size, uiState.isGenerating) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(uiState.messages.size - 1)
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(SoftTheme.colors.background)
            .testTag("assistant_screen")
    ) {
        // Pinned Header
        AssistantHeader(
            conversationTitle = uiState.currentConversation.title,
            providerMode = uiState.providerMode,
            onOpenHistory = { viewModel.toggleHistorySheet(true) },
            onOpenProviderPicker = { viewModel.toggleProviderPicker(true) },
            isDarkTheme = isDarkTheme,
            onToggleTheme = onToggleTheme,
            onOpenVoiceMode = onOpenVoiceMode
        )

        // Scrollable Messages List
        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .testTag("assistant_messages_list"),
            contentPadding = PaddingValues(
                horizontal = SoftTheme.spacing.md,
                vertical = SoftTheme.spacing.sm
            ),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(uiState.messages, key = { it.id }) { message ->
                AssistantMessageItem(
                    message = message,
                    onRetry = { viewModel.retryLastMessage() }
                )
            }
        }

        // Pinned Composer
        AssistantComposer(
            inputText = uiState.inputText,
            onInputTextChange = { viewModel.updateInputText(it) },
            selectedLanguage = uiState.selectedLanguage,
            onLanguageSelect = { viewModel.selectLanguage(it) },
            isGenerating = uiState.isGenerating,
            isMicrophoneActive = uiState.isMicrophoneActive,
            onToggleMicrophone = {
                onOpenVoiceMode()
            },
            attachments = uiState.attachments,
            onAddAttachment = { viewModel.addAttachment(it) },
            onRemoveAttachment = { viewModel.removeAttachment(it) },
            onSendMessage = { viewModel.sendMessage(it) },
            onStopGeneration = { viewModel.stopGeneration() }
        )
    }

    // Modal Sheet for Conversation History
    AssistantHistorySheet(
        isOpen = uiState.isHistorySheetOpen,
        onDismiss = { viewModel.toggleHistorySheet(false) },
        conversations = uiState.conversations,
        currentConversationId = uiState.currentConversation.id,
        searchQuery = uiState.historySearchQuery,
        onSearchQueryChange = { viewModel.setHistorySearchQuery(it) },
        onSelectConversation = { viewModel.selectConversation(it) },
        onNewConversation = { viewModel.createNewConversation() },
        onDeleteConversation = { viewModel.deleteConversation(it) }
    )

    // Modal Sheet for Provider Mode Switching
    ProviderModePickerSheet(
        isOpen = uiState.isProviderPickerOpen,
        onDismiss = { viewModel.toggleProviderPicker(false) },
        currentMode = uiState.providerMode,
        availableModes = uiState.availableProviderModes,
        onSelectMode = { viewModel.switchProviderMode(it) }
    )
}
