package com.example.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeAssistantRepository
import com.example.domain.model.AssistantUiState
import com.example.domain.model.LanguageOption
import com.example.domain.model.ProviderMode
import com.example.domain.repository.AssistantRepository
import kotlinx.coroutines.flow.StateFlow

/**
 * ViewModel managing Assistant conversation state, input composition,
 * provider modes, language selection, and history drawer.
 */
class AssistantViewModel(
    private val repository: AssistantRepository = FakeAssistantRepository()
) : ViewModel() {

    val uiState: StateFlow<AssistantUiState> = repository.uiState

    fun updateInputText(text: String) {
        repository.updateInputText(text)
    }

    fun selectLanguage(language: LanguageOption) {
        repository.selectLanguage(language)
    }

    fun switchProviderMode(mode: ProviderMode) {
        repository.switchProviderMode(mode)
    }

    fun toggleMicrophone(active: Boolean? = null) {
        repository.toggleMicrophone(active)
    }

    fun addAttachment(fileName: String) {
        repository.addAttachment(fileName)
    }

    fun removeAttachment(fileName: String) {
        repository.removeAttachment(fileName)
    }

    fun sendMessage(customText: String? = null) {
        repository.sendMessage(customText)
    }

    fun stopGeneration() {
        repository.stopGeneration()
    }

    fun retryLastMessage() {
        repository.retryLastMessage()
    }

    fun selectConversation(conversationId: String) {
        repository.selectConversation(conversationId)
    }

    fun createNewConversation(title: String = "New Conversation") {
        repository.createNewConversation(title)
    }

    fun deleteConversation(conversationId: String) {
        repository.deleteConversation(conversationId)
    }

    fun setHistorySearchQuery(query: String) {
        repository.setHistorySearchQuery(query)
    }

    fun toggleHistorySheet(isOpen: Boolean) {
        repository.toggleHistorySheet(isOpen)
    }

    fun toggleProviderPicker(isOpen: Boolean) {
        repository.toggleProviderPicker(isOpen)
    }
}
