package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import com.example.ui.components.softBounceOverscroll
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.ui.components.SoftGlassCard
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
    isDarkTheme: Boolean = false,
    onToggleTheme: (() -> Unit)? = null,
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
            .statusBarsPadding()
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
                .softBounceOverscroll()
                .testTag("assistant_messages_list"),
            contentPadding = PaddingValues(
                horizontal = SoftTheme.spacing.md,
                vertical = SoftTheme.spacing.sm
            ),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            if (uiState.messages.isEmpty()) {
                item {
                    AssistantCleanStatePrompt(
                        onSelectPrompt = { prompt ->
                            viewModel.updateInputText(prompt)
                        }
                    )
                }
            } else {
                items(uiState.messages, key = { it.id }) { message ->
                    AssistantMessageItem(
                        message = message,
                        onRetry = { viewModel.retryLastMessage() }
                    )
                }
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

@Composable
private fun AssistantCleanStatePrompt(
    onSelectPrompt: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = SoftTheme.spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(SoftTheme.colors.accentBlue.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.AutoAwesome,
                contentDescription = null,
                tint = SoftTheme.colors.accentBlue,
                modifier = Modifier.size(24.dp)
            )
        }

        Text(
            text = "Local Assistant Ready",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.textPrimary
        )

        Text(
            text = "Offline-first companion connected to PC Local AI Core.\nAsk anything or pick a quick starter below:",
            style = MaterialTheme.typography.bodySmall,
            color = SoftTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = SoftTheme.spacing.lg)
        )

        Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))

        listOf(
            "Check device battery and memory telemetry",
            "Schedule a reminder for tomorrow at 7 AM",
            "Help me write a concise task list for today"
        ).forEach { prompt ->
            SoftGlassCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSelectPrompt(prompt) },
                elevation = SoftTheme.tokens.elevations.subtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = prompt,
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 13.sp
                    )
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}
