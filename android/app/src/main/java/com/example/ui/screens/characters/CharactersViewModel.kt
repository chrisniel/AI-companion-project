package com.example.ui.screens.characters

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeCharactersRepository
import com.example.domain.model.AvatarDisplayMode
import com.example.domain.model.AvatarStyle
import com.example.domain.model.CharacterProfile
import com.example.domain.model.CodeSwitchingStyle
import com.example.domain.model.FrequencyLevel
import com.example.domain.model.JapaneseTone
import com.example.domain.model.LanguageStyleConfig
import com.example.domain.model.VoiceProfile
import com.example.domain.repository.CharactersRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class CharactersUiState(
    val characters: List<CharacterProfile> = emptyList(),
    val activeCharacter: CharacterProfile? = null,
    val editingCharacter: CharacterProfile? = null,
    val isEditorOpen: Boolean = false,
    val auditioningVoiceId: String? = null,
    val statusMessage: String? = null,
    val availableVoices: List<VoiceProfile> = emptyList(),
    val availableAvatarStyles: List<AvatarStyle> = emptyList()
)

class CharactersViewModel(
    private val repository: CharactersRepository = FakeCharactersRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        CharactersUiState(
            characters = repository.characters.value,
            activeCharacter = repository.characters.value.firstOrNull { it.isActive } ?: repository.characters.value.firstOrNull(),
            availableVoices = repository.availableVoices,
            availableAvatarStyles = repository.availableAvatarStyles
        )
    )
    val uiState: StateFlow<CharactersUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.characters.collect { chars ->
                _uiState.update { current ->
                    current.copy(
                        characters = chars,
                        activeCharacter = chars.firstOrNull { it.isActive } ?: chars.firstOrNull()
                    )
                }
            }
        }
    }

    fun selectActive(characterId: String, onActivated: ((CharacterProfile) -> Unit)? = null) {
        viewModelScope.launch {
            repository.selectActiveCharacter(characterId)
            val active = uiState.value.characters.find { it.id == characterId }
            if (active != null) {
                onActivated?.invoke(active)
            }
            showStatus("Activated character: ${active?.displayName ?: "Profile"}")
        }
    }

    fun openEditor(character: CharacterProfile) {
        _uiState.update {
            it.copy(
                editingCharacter = character.copy(),
                isEditorOpen = true
            )
        }
    }

    fun createNewCharacter() {
        val defaultAvatar = repository.availableAvatarStyles.first()
        val defaultVoice = repository.availableVoices.first()
        val newProfile = CharacterProfile(
            id = "char_custom_${System.currentTimeMillis()}",
            displayName = "New Persona",
            persona = "Custom cognitive role and domain perspective",
            responseStyle = "Clear, pragmatic, and context-tailored",
            avatarStyle = defaultAvatar,
            avatarDisplay = AvatarDisplayMode.FULL,
            voice = defaultVoice,
            speakingStyle = "Friendly and natural",
            languageStyle = LanguageStyleConfig(),
            isActive = false,
            isCustom = true,
            sampleDialogue = "Hello! I am configured with custom personality and language style."
        )
        _uiState.update {
            it.copy(
                editingCharacter = newProfile,
                isEditorOpen = true
            )
        }
    }

    fun closeEditor() {
        _uiState.update {
            it.copy(
                isEditorOpen = false,
                editingCharacter = null
            )
        }
    }

    fun saveEditingCharacter() {
        val editing = _uiState.value.editingCharacter ?: return
        closeEditor()
        showStatus("Saved '${editing.displayName}' profile")
        viewModelScope.launch {
            repository.saveCharacter(editing)
        }
    }

    fun duplicateCharacter(characterId: String) {
        viewModelScope.launch {
            val duplicated = repository.duplicateCharacter(characterId)
            if (duplicated != null) {
                showStatus("Duplicated to '${duplicated.displayName}'")
            }
        }
    }

    fun deleteCharacter(characterId: String) {
        viewModelScope.launch {
            repository.deleteCharacter(characterId)
            showStatus("Deleted character profile")
        }
    }

    fun updateDisplayName(name: String) {
        _uiState.update { current ->
            current.copy(editingCharacter = current.editingCharacter?.copy(displayName = name))
        }
    }

    fun updatePersona(persona: String) {
        _uiState.update { current ->
            current.copy(editingCharacter = current.editingCharacter?.copy(persona = persona))
        }
    }

    fun updateResponseStyle(style: String) {
        _uiState.update { current ->
            current.copy(editingCharacter = current.editingCharacter?.copy(responseStyle = style))
        }
    }

    fun updateSpeakingStyle(style: String) {
        _uiState.update { current ->
            current.copy(editingCharacter = current.editingCharacter?.copy(speakingStyle = style))
        }
    }

    fun updateVoice(voice: VoiceProfile) {
        _uiState.update { current ->
            current.copy(editingCharacter = current.editingCharacter?.copy(voice = voice))
        }
    }

    fun updateAvatarStyle(avatarStyle: AvatarStyle) {
        _uiState.update { current ->
            current.copy(editingCharacter = current.editingCharacter?.copy(avatarStyle = avatarStyle))
        }
    }

    fun updateAvatarDisplay(mode: AvatarDisplayMode) {
        _uiState.update { current ->
            current.copy(editingCharacter = current.editingCharacter?.copy(avatarDisplay = mode))
        }
    }

    fun updateLanguageStyle(updateBlock: (LanguageStyleConfig) -> LanguageStyleConfig) {
        _uiState.update { current ->
            val editing = current.editingCharacter ?: return@update current
            current.copy(editingCharacter = editing.copy(languageStyle = updateBlock(editing.languageStyle)))
        }
    }

    fun setPrimaryLanguage(lang: String) {
        updateLanguageStyle { it.copy(primaryLanguage = lang) }
    }

    fun toggleSecondaryLanguage(lang: String) {
        updateLanguageStyle { current ->
            val list = current.secondaryLanguages.toMutableList()
            if (list.contains(lang)) {
                list.remove(lang)
            } else {
                list.add(lang)
            }
            current.copy(secondaryLanguages = list)
        }
    }

    fun setMatchUserLanguage(match: Boolean) {
        updateLanguageStyle { it.copy(matchUserLanguage = match) }
    }

    fun setCodeSwitchingStyle(style: CodeSwitchingStyle) {
        updateLanguageStyle { it.copy(codeSwitchingStyle = style) }
    }

    fun setTagalogFrequency(freq: FrequencyLevel) {
        updateLanguageStyle { it.copy(tagalogFrequency = freq) }
    }

    fun setJapaneseFrequency(freq: FrequencyLevel) {
        updateLanguageStyle { it.copy(japaneseFrequency = freq) }
    }

    fun setJapaneseTone(tone: JapaneseTone) {
        updateLanguageStyle { it.copy(japaneseTone = tone) }
    }

    fun simulateVoiceAudition(voiceId: String) {
        _uiState.update { it.copy(auditioningVoiceId = voiceId) }
        viewModelScope.launch {
            delay(2200) // Mock TTS audition duration
            _uiState.update { current ->
                if (current.auditioningVoiceId == voiceId) current.copy(auditioningVoiceId = null) else current
            }
        }
    }

    fun resetToDefaults() {
        viewModelScope.launch {
            repository.resetToDefaults()
            showStatus("Reset all character profiles to default")
        }
    }

    fun clearStatus() {
        _uiState.update { it.copy(statusMessage = null) }
    }

    private fun showStatus(message: String) {
        _uiState.update { it.copy(statusMessage = message) }
    }
}
