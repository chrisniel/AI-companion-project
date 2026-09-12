package com.example.data.fake

import com.example.domain.model.AvatarDisplayMode
import com.example.domain.model.AvatarStyle
import com.example.domain.model.CharacterProfile
import com.example.domain.model.CodeSwitchingStyle
import com.example.domain.model.FrequencyLevel
import com.example.domain.model.JapaneseTone
import com.example.domain.model.LanguageStyleConfig
import com.example.domain.model.VoiceProfile
import com.example.domain.repository.CharactersRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class FakeCharactersRepository : CharactersRepository {

    override val availableVoices: List<VoiceProfile> = listOf(
        VoiceProfile(
            id = "voice_aura",
            name = "Aura Contralto",
            timbre = "Warm & Supportive",
            pitch = "Mid-Low",
            speed = "1.0x",
            accentTag = "Tagalog-English Native"
        ),
        VoiceProfile(
            id = "voice_chronos",
            name = "Chronos Baritone",
            timbre = "Resonant & Analytical",
            pitch = "Low",
            speed = "1.05x",
            accentTag = "Neutral International"
        ),
        VoiceProfile(
            id = "voice_nexus",
            name = "Nexus Tenor",
            timbre = "Crisp & High-Velocity",
            pitch = "Mid-High",
            speed = "1.1x",
            accentTag = "Tech Academic"
        ),
        VoiceProfile(
            id = "voice_lyra",
            name = "Lyra Soprano",
            timbre = "Harmonic & Spirited",
            pitch = "High",
            speed = "1.0x",
            accentTag = "Bilingual JP-PH Dynamic"
        ),
        VoiceProfile(
            id = "voice_zephyr",
            name = "Zephyr Ambient",
            timbre = "Quiet & Meditative",
            pitch = "Soft-Low",
            speed = "0.9x",
            accentTag = "Gentle Neutral"
        )
    )

    override val availableAvatarStyles: List<AvatarStyle> = listOf(
        AvatarStyle(
            id = "avatar_aura",
            name = "Starlight Amber",
            primaryColorHex = 0xFFE08D3CL,
            secondaryColorHex = 0xFFF3B775L,
            accentColorHex = 0xFF422208L,
            glyphSymbol = "✦"
        ),
        AvatarStyle(
            id = "avatar_chronos",
            name = "Deep Indigo",
            primaryColorHex = 0xFF4A55A2L,
            secondaryColorHex = 0xFF7895CBL,
            accentColorHex = 0xFF141738L,
            glyphSymbol = "⏳"
        ),
        AvatarStyle(
            id = "avatar_nexus",
            name = "Quantum Teal",
            primaryColorHex = 0xFF2D8E6CL,
            secondaryColorHex = 0xFF58D2A4L,
            accentColorHex = 0xFF0D2E22L,
            glyphSymbol = "⬡"
        ),
        AvatarStyle(
            id = "avatar_lyra",
            name = "Cosmic Rose",
            primaryColorHex = 0xFFD44D7DL,
            secondaryColorHex = 0xFFF48FB1L,
            accentColorHex = 0xFF3D0E20L,
            glyphSymbol = "✧"
        ),
        AvatarStyle(
            id = "avatar_zephyr",
            name = "Zenith Cyan",
            primaryColorHex = 0xFF3BA5B5L,
            secondaryColorHex = 0xFF80DEEAL,
            accentColorHex = 0xFF0F3238L,
            glyphSymbol = "☯"
        ),
        AvatarStyle(
            id = "avatar_solar",
            name = "Solar Glow",
            primaryColorHex = 0xFFF57C00L,
            secondaryColorHex = 0xFFFFB74DL,
            accentColorHex = 0xFF471C00L,
            glyphSymbol = "☀"
        )
    )

    private val defaultCharacters: List<CharacterProfile> = listOf(
        CharacterProfile(
            id = "char_aura",
            displayName = "Aura",
            persona = "Empathetic companion and cognitive synthesizer",
            responseStyle = "Warm, balanced, and contextual with proactive suggestions",
            avatarStyle = availableAvatarStyles[0],
            avatarDisplay = AvatarDisplayMode.FULL,
            voice = availableVoices[0],
            speakingStyle = "Reassuring, articulate, and conversational",
            languageStyle = LanguageStyleConfig(
                primaryLanguage = "English",
                secondaryLanguages = listOf("Tagalog", "Japanese"),
                matchUserLanguage = true,
                codeSwitchingStyle = CodeSwitchingStyle.NATURAL_BLEND,
                tagalogFrequency = FrequencyLevel.MODERATE,
                japaneseFrequency = FrequencyLevel.OCCASIONAL,
                japaneseTone = JapaneseTone.WARM_MATURE
            ),
            isActive = true,
            isCustom = false,
            sampleDialogue = "Magandang umaga! I've prepped your daily agenda. 今日も一緒に頑張りましょうね。"
        ),
        CharacterProfile(
            id = "char_chronos",
            displayName = "Chronos",
            persona = "Analytical timekeeper and executive strategist",
            responseStyle = "Strict bulleted milestones, timeline audits, and zero fluff",
            avatarStyle = availableAvatarStyles[1],
            avatarDisplay = AvatarDisplayMode.COMPACT,
            voice = availableVoices[1],
            speakingStyle = "Pragmatic, measured, and chronometrically precise",
            languageStyle = LanguageStyleConfig(
                primaryLanguage = "English",
                secondaryLanguages = listOf("Japanese"),
                matchUserLanguage = true,
                codeSwitchingStyle = CodeSwitchingStyle.CONTEXTUAL_PIVOT,
                tagalogFrequency = FrequencyLevel.OCCASIONAL,
                japaneseFrequency = FrequencyLevel.MODERATE,
                japaneseTone = JapaneseTone.FORMAL
            ),
            isActive = false,
            isCustom = false,
            sampleDialogue = "Agenda check complete. Next block starts in 18 minutes. 予定通りに進めてまいります。"
        ),
        CharacterProfile(
            id = "char_nexus",
            displayName = "Nexus",
            persona = "High-throughput systems architect and logic kernel",
            responseStyle = "Technical scaffolds, pseudocode breakdown, and architectural trade-offs",
            avatarStyle = availableAvatarStyles[2],
            avatarDisplay = AvatarDisplayMode.FULL,
            voice = availableVoices[2],
            speakingStyle = "Deterministic, algorithmic, and concise",
            languageStyle = LanguageStyleConfig(
                primaryLanguage = "English",
                secondaryLanguages = listOf("Japanese"),
                matchUserLanguage = false,
                codeSwitchingStyle = CodeSwitchingStyle.TERMINOLOGY_ONLY,
                tagalogFrequency = FrequencyLevel.NONE,
                japaneseFrequency = FrequencyLevel.OCCASIONAL,
                japaneseTone = JapaneseTone.NEUTRAL
            ),
            isActive = false,
            isCustom = false,
            sampleDialogue = "Local inference pipeline is running at 42 tok/s. システムの状態は正常です。"
        ),
        CharacterProfile(
            id = "char_lyra",
            displayName = "Lyra",
            persona = "Creative muse, writer, and spirited conversationalist",
            responseStyle = "Expressive narratives, dynamic metaphors, and lively humor",
            avatarStyle = availableAvatarStyles[3],
            avatarDisplay = AvatarDisplayMode.FULL,
            voice = availableVoices[3],
            speakingStyle = "Playful, enthusiastic, and highly energetic",
            languageStyle = LanguageStyleConfig(
                primaryLanguage = "English",
                secondaryLanguages = listOf("Tagalog", "Japanese"),
                matchUserLanguage = true,
                codeSwitchingStyle = CodeSwitchingStyle.NATURAL_BLEND,
                tagalogFrequency = FrequencyLevel.FREQUENT,
                japaneseFrequency = FrequencyLevel.FREQUENT,
                japaneseTone = JapaneseTone.PLAYFUL
            ),
            isActive = false,
            isCustom = false,
            sampleDialogue = "Uy grabe, that concept is awesome! 今日のアイデアめっちゃ面白いよ！Let's create something cool."
        ),
        CharacterProfile(
            id = "char_zephyr",
            displayName = "Zephyr",
            persona = "Mindful zen guide for deep focus and bio-restoration",
            responseStyle = "Minimalist prompts, grounding pauses, and low-cognitive load pacing",
            avatarStyle = availableAvatarStyles[4],
            avatarDisplay = AvatarDisplayMode.VOICE_MODE_ONLY,
            voice = availableVoices[4],
            speakingStyle = "Soft, grounding, and breath-paced",
            languageStyle = LanguageStyleConfig(
                primaryLanguage = "English",
                secondaryLanguages = listOf("Japanese"),
                matchUserLanguage = true,
                codeSwitchingStyle = CodeSwitchingStyle.NATURAL_BLEND,
                tagalogFrequency = FrequencyLevel.OCCASIONAL,
                japaneseFrequency = FrequencyLevel.OCCASIONAL,
                japaneseTone = JapaneseTone.WARM_MATURE
            ),
            isActive = false,
            isCustom = false,
            sampleDialogue = "Take a calm breath. Pwede kang magpahinga muna. 心を落ち着かせていきましょう。"
        )
    )

    private val _characters = MutableStateFlow(defaultCharacters)
    override val characters: StateFlow<List<CharacterProfile>> = _characters.asStateFlow()

    override suspend fun selectActiveCharacter(characterId: String) {
        _characters.update { list ->
            list.map { it.copy(isActive = it.id == characterId) }
        }
    }

    override suspend fun saveCharacter(character: CharacterProfile) {
        _characters.update { list ->
            val existingIndex = list.indexOfFirst { it.id == character.id }
            if (existingIndex >= 0) {
                list.toMutableList().apply {
                    this[existingIndex] = character
                }
            } else {
                list + character
            }
        }
    }

    override suspend fun duplicateCharacter(characterId: String): CharacterProfile? {
        val original = _characters.value.find { it.id == characterId } ?: return null
        val newId = "char_custom_${System.currentTimeMillis()}"
        val copy = original.copy(
            id = newId,
            displayName = "${original.displayName} (Custom)",
            isCustom = true,
            isActive = false
        )
        _characters.update { it + copy }
        return copy
    }

    override suspend fun deleteCharacter(characterId: String) {
        _characters.update { list ->
            // Prevent deleting active character without fallback
            val deleting = list.find { it.id == characterId }
            val remaining = list.filter { it.id != characterId }
            if (deleting?.isActive == true && remaining.isNotEmpty()) {
                remaining.mapIndexed { index, profile ->
                    if (index == 0) profile.copy(isActive = true) else profile
                }
            } else {
                remaining
            }
        }
    }

    override suspend fun updateAvatarDisplay(characterId: String, mode: AvatarDisplayMode) {
        _characters.update { list ->
            list.map {
                if (it.id == characterId) it.copy(avatarDisplay = mode) else it
            }
        }
    }

    override suspend fun resetToDefaults() {
        _characters.value = defaultCharacters
    }
}
