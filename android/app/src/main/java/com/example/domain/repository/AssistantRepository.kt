package com.example.domain.repository

import com.example.domain.model.AssistantUiState
import com.example.domain.model.LanguageOption
import com.example.domain.model.ProviderMode
import kotlinx.coroutines.flow.StateFlow

/**
 * Clean architecture boundary for Assistant conversation state and operations.
 */
interface AssistantRepository {
    val uiState: StateFlow<AssistantUiState>

    fun selectConversation(conversationId: String)
    fun createNewConversation(title: String = "New Conversation")
    fun deleteConversation(conversationId: String)
    fun setHistorySearchQuery(query: String)
    fun toggleHistorySheet(isOpen: Boolean)
    fun toggleProviderPicker(isOpen: Boolean)

    fun updateInputText(text: String)
    fun selectLanguage(language: LanguageOption)
    fun switchProviderMode(mode: ProviderMode)
    fun toggleMicrophone(active: Boolean? = null)
    fun addAttachment(fileName: String)
    fun removeAttachment(fileName: String)

    fun sendMessage(customText: String? = null)
    fun stopGeneration()
    fun retryLastMessage()
}
