package com.example.domain.repository

import com.example.domain.model.AvatarDisplayMode
import com.example.domain.model.AvatarStyle
import com.example.domain.model.CharacterProfile
import com.example.domain.model.VoiceProfile
import kotlinx.coroutines.flow.StateFlow

interface CharactersRepository {
    val characters: StateFlow<List<CharacterProfile>>
    val availableVoices: List<VoiceProfile>
    val availableAvatarStyles: List<AvatarStyle>

    suspend fun selectActiveCharacter(characterId: String)
    suspend fun saveCharacter(character: CharacterProfile)
    suspend fun duplicateCharacter(characterId: String): CharacterProfile?
    suspend fun deleteCharacter(characterId: String)
    suspend fun updateAvatarDisplay(characterId: String, mode: AvatarDisplayMode)
    suspend fun resetToDefaults()
}
