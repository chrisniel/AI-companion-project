package com.example.ui.screens.memory

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeMemoryRepository
import com.example.domain.model.MemoryCategory
import com.example.domain.model.MemoryItem
import com.example.domain.repository.MemoryRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

data class MemoryUiState(
    val searchQuery: String = "",
    val selectedCategory: MemoryCategory? = null,
    val showArchivedOnly: Boolean = false,
    val memories: List<MemoryItem> = emptyList(),
    val viewingMemory: MemoryItem? = null,
    val editingMemory: MemoryItem? = null,
    val isEditorOpen: Boolean = false,
    val isCreatingNew: Boolean = false,
    val statusMessage: String? = null
)

class MemoryViewModel(
    private val repository: MemoryRepository = FakeMemoryRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        MemoryUiState(
            memories = repository.searchMemories(
                query = "",
                category = null,
                showArchived = false
            )
        )
    )
    val uiState: StateFlow<MemoryUiState> = _uiState.asStateFlow()

    private fun refreshFilteredMemories() {
        val current = _uiState.value
        val filtered = repository.searchMemories(
            query = current.searchQuery,
            category = current.selectedCategory,
            showArchived = current.showArchivedOnly
        )
        _uiState.update { it.copy(memories = filtered) }
    }

    fun updateSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        refreshFilteredMemories()
    }

    fun selectCategory(category: MemoryCategory?) {
        _uiState.update { it.copy(selectedCategory = category) }
        refreshFilteredMemories()
    }

    fun toggleShowArchived() {
        val nextArchived = !_uiState.value.showArchivedOnly
        _uiState.update { it.copy(showArchivedOnly = nextArchived) }
        refreshFilteredMemories()
        showStatus(if (nextArchived) "Viewing Archived memories" else "Viewing Active memories")
    }

    fun viewMemory(item: MemoryItem?) {
        _uiState.update { it.copy(viewingMemory = item) }
    }

    fun openNewMemoryEditor() {
        val newDraft = MemoryItem(
            id = "mem_${UUID.randomUUID().toString().take(8)}",
            title = "",
            content = "",
            category = _uiState.value.selectedCategory ?: MemoryCategory.FACT,
            tags = emptyList(),
            createdAt = "Today",
            updatedAt = "Today",
            isArchived = false
        )
        _uiState.update {
            it.copy(
                editingMemory = newDraft,
                isEditorOpen = true,
                isCreatingNew = true
            )
        }
    }

    fun openEditMemory(item: MemoryItem) {
        _uiState.update {
            it.copy(
                editingMemory = item,
                isEditorOpen = true,
                isCreatingNew = false
            )
        }
    }

    fun closeEditor() {
        _uiState.update {
            it.copy(
                editingMemory = null,
                isEditorOpen = false,
                isCreatingNew = false
            )
        }
    }

    fun saveMemory(title: String, content: String, category: MemoryCategory, tags: List<String>) {
        val currentEditing = _uiState.value.editingMemory ?: return
        val updated = currentEditing.copy(
            title = title.trim(),
            content = content.trim(),
            category = category,
            tags = tags,
            updatedAt = "Today"
        )

        closeEditor()
        showStatus("Saved '${updated.title.ifBlank { "Memory record" }}'")
        repository.saveMemory(updated)
        refreshFilteredMemories()
    }

    fun toggleArchive(memoryId: String) {
        val target = _uiState.value.memories.find { it.id == memoryId }
            ?: repository.getMemory(memoryId)
        val isNowArchived = !(target?.isArchived ?: false)

        showStatus(if (isNowArchived) "Archived '${target?.title}'" else "Restored '${target?.title}' to Active")
        repository.toggleArchive(memoryId)
        _uiState.update { it.copy(viewingMemory = null) }
        refreshFilteredMemories()
    }

    fun deleteMemory(memoryId: String) {
        val target = _uiState.value.memories.find { it.id == memoryId }
            ?: repository.getMemory(memoryId)

        showStatus("Deleted '${target?.title ?: "Memory"}'")
        repository.deleteMemory(memoryId)
        _uiState.update { it.copy(viewingMemory = null) }
        refreshFilteredMemories()
    }

    fun showStatus(message: String) {
        _uiState.update { it.copy(statusMessage = message) }
    }

    fun clearStatus() {
        _uiState.update { it.copy(statusMessage = null) }
    }
}
