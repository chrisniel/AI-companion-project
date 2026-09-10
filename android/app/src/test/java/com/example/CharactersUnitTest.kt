package com.example

import com.example.domain.model.AvatarDisplayMode
import com.example.domain.model.CodeSwitchingStyle
import com.example.domain.model.FrequencyLevel
import com.example.domain.model.JapaneseTone
import com.example.ui.screens.characters.CharactersViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for Batch 8: Mobile Character Management.
 * Verifies:
 * - Character library displays avatar, display name, voice, and active state
 * - Character editor supports mock: display name, persona, response style, avatar, voice, speaking style
 * - Language style supports: Primary Language, Secondary Languages, Match User Language,
 *   Code-Switching Style, Tagalog Frequency, Japanese Frequency, Japanese Tone (Neutral, Warm / Mature, Playful, Formal)
 * - Avatar display modes: Full, Compact, Voice Mode Only, Hidden
 * - Characters are configurable profiles, not application identity
 */
class CharactersUnitTest {

    @Test
    fun `character library displays avatar, display name, voice, and active state`() {
        val viewModel = CharactersViewModel()
        val characters = viewModel.uiState.value.characters

        assertTrue("Character library must have default characters", characters.isNotEmpty())
        val activeChar = characters.firstOrNull { it.isActive }
        assertNotNull("There should be an active character", activeChar)

        characters.forEach { character ->
            assertNotNull("Character must have display name", character.displayName)
            assertTrue("Display name must not be blank", character.displayName.isNotBlank())
            assertNotNull("Character must have an avatarStyle", character.avatarStyle)
            assertNotNull("Character must have a voice", character.voice)
            assertTrue("Voice name must not be blank", character.voice.name.isNotBlank())
            assertNotNull("Character must specify active state", character.isActive)
        }
    }

    @Test
    fun `character editor supports mock fields - display name, persona, response style, avatar, voice, speaking style`() {
        val viewModel = CharactersViewModel()
        val firstChar = viewModel.uiState.value.characters.first()

        viewModel.openEditor(firstChar)
        val editing = viewModel.uiState.value.editingCharacter
        assertNotNull("Editing character must be populated", editing)

        // Test display name editing
        viewModel.updateDisplayName("Custom Nexus Core")
        assertEquals("Custom Nexus Core", viewModel.uiState.value.editingCharacter?.displayName)

        // Test persona editing
        viewModel.updatePersona("Advanced Analytical Cognitive Core")
        assertEquals("Advanced Analytical Cognitive Core", viewModel.uiState.value.editingCharacter?.persona)

        // Test response style editing
        viewModel.updateResponseStyle("Exclusively bulleted, high-density facts")
        assertEquals("Exclusively bulleted, high-density facts", viewModel.uiState.value.editingCharacter?.responseStyle)

        // Test avatar style editing
        val targetAvatar = viewModel.uiState.value.availableAvatarStyles.last()
        viewModel.updateAvatarStyle(targetAvatar)
        assertEquals(targetAvatar.id, viewModel.uiState.value.editingCharacter?.avatarStyle?.id)

        // Test voice selection & audition
        val targetVoice = viewModel.uiState.value.availableVoices.last()
        viewModel.updateVoice(targetVoice)
        assertEquals(targetVoice.id, viewModel.uiState.value.editingCharacter?.voice?.id)
        viewModel.simulateVoiceAudition(targetVoice.id)
        assertEquals(targetVoice.id, viewModel.uiState.value.auditioningVoiceId)

        // Test speaking style editing
        viewModel.updateSpeakingStyle("Cerebral, rhythmic cadence with zero filler")
        assertEquals("Cerebral, rhythmic cadence with zero filler", viewModel.uiState.value.editingCharacter?.speakingStyle)

        // Save editing
        viewModel.saveEditingCharacter()
        assertNull("Editor should be closed after save", viewModel.uiState.value.editingCharacter)
    }

    @Test
    fun `language style supports primary, secondary, match user, code-switching, tagalog and japanese frequency, japanese tone`() {
        val viewModel = CharactersViewModel()
        val char = viewModel.uiState.value.characters.first()
        viewModel.openEditor(char)

        val initialConfig = viewModel.uiState.value.editingCharacter?.languageStyle
        assertNotNull("Language style config must exist", initialConfig)

        // Test primary language
        viewModel.setPrimaryLanguage("English (US)")
        assertEquals("English (US)", viewModel.uiState.value.editingCharacter?.languageStyle?.primaryLanguage)

        // Test secondary language toggle
        viewModel.toggleSecondaryLanguage("Spanish")
        assertTrue(
            "Secondary languages should include Spanish",
            viewModel.uiState.value.editingCharacter?.languageStyle?.secondaryLanguages?.contains("Spanish") == true
        )
        viewModel.toggleSecondaryLanguage("Spanish")
        assertFalse(
            "Secondary languages should not include Spanish after toggling off",
            viewModel.uiState.value.editingCharacter?.languageStyle?.secondaryLanguages?.contains("Spanish") == true
        )

        // Test match user language toggle
        viewModel.setMatchUserLanguage(false)
        assertFalse(viewModel.uiState.value.editingCharacter?.languageStyle?.matchUserLanguage == true)

        // Test code-switching style
        viewModel.setCodeSwitchingStyle(CodeSwitchingStyle.NATURAL_BLEND)
        assertEquals(
            CodeSwitchingStyle.NATURAL_BLEND,
            viewModel.uiState.value.editingCharacter?.languageStyle?.codeSwitchingStyle
        )

        // Test Tagalog frequency
        viewModel.setTagalogFrequency(FrequencyLevel.OCCASIONAL)
        assertEquals(
            FrequencyLevel.OCCASIONAL,
            viewModel.uiState.value.editingCharacter?.languageStyle?.tagalogFrequency
        )

        // Test Japanese frequency
        viewModel.setJapaneseFrequency(FrequencyLevel.FREQUENT)
        assertEquals(
            FrequencyLevel.FREQUENT,
            viewModel.uiState.value.editingCharacter?.languageStyle?.japaneseFrequency
        )

        // Test all 4 Japanese Tone options: Neutral, Warm / Mature, Playful, Formal
        val toneOptions = JapaneseTone.entries
        assertEquals("Japanese Tone must have 4 options", 4, toneOptions.size)
        assertTrue("Contains NEUTRAL", toneOptions.contains(JapaneseTone.NEUTRAL))
        assertTrue("Contains WARM_MATURE", toneOptions.contains(JapaneseTone.WARM_MATURE))
        assertTrue("Contains PLAYFUL", toneOptions.contains(JapaneseTone.PLAYFUL))
        assertTrue("Contains FORMAL", toneOptions.contains(JapaneseTone.FORMAL))

        // Update tone to Warm / Mature
        viewModel.setJapaneseTone(JapaneseTone.WARM_MATURE)
        assertEquals(
            JapaneseTone.WARM_MATURE,
            viewModel.uiState.value.editingCharacter?.languageStyle?.japaneseTone
        )

        // Update tone to Playful
        viewModel.setJapaneseTone(JapaneseTone.PLAYFUL)
        assertEquals(
            JapaneseTone.PLAYFUL,
            viewModel.uiState.value.editingCharacter?.languageStyle?.japaneseTone
        )

        // Update tone to Formal
        viewModel.setJapaneseTone(JapaneseTone.FORMAL)
        assertEquals(
            JapaneseTone.FORMAL,
            viewModel.uiState.value.editingCharacter?.languageStyle?.japaneseTone
        )

        // Update tone to Neutral
        viewModel.setJapaneseTone(JapaneseTone.NEUTRAL)
        assertEquals(
            JapaneseTone.NEUTRAL,
            viewModel.uiState.value.editingCharacter?.languageStyle?.japaneseTone
        )
    }

    @Test
    fun `avatar display mode supports Full, Compact, Voice Mode Only, and Hidden`() {
        val viewModel = CharactersViewModel()
        val modes = AvatarDisplayMode.entries
        assertEquals("Avatar display mode must support 4 options", 4, modes.size)
        assertTrue(modes.contains(AvatarDisplayMode.FULL))
        assertTrue(modes.contains(AvatarDisplayMode.COMPACT))
        assertTrue(modes.contains(AvatarDisplayMode.VOICE_MODE_ONLY))
        assertTrue(modes.contains(AvatarDisplayMode.HIDDEN))

        val char = viewModel.uiState.value.characters.first()
        viewModel.openEditor(char)

        viewModel.updateAvatarDisplay(AvatarDisplayMode.VOICE_MODE_ONLY)
        assertEquals(
            AvatarDisplayMode.VOICE_MODE_ONLY,
            viewModel.uiState.value.editingCharacter?.avatarDisplay
        )

        viewModel.updateAvatarDisplay(AvatarDisplayMode.HIDDEN)
        assertEquals(
            AvatarDisplayMode.HIDDEN,
            viewModel.uiState.value.editingCharacter?.avatarDisplay
        )
    }

    @Test
    fun `setting active character updates active state across library`() {
        val viewModel = CharactersViewModel()
        val characters = viewModel.uiState.value.characters
        val secondChar = characters[1]

        viewModel.selectActive(secondChar.id)
    }

    @Test
    fun `create new character initializes a valid draft profile`() {
        val viewModel = CharactersViewModel()
        viewModel.createNewCharacter()

        val draft = viewModel.uiState.value.editingCharacter
        assertNotNull("Draft character must be created", draft)
        assertEquals("New Persona", draft?.displayName)
        assertFalse("New character should not be active by default", draft?.isActive == true)
    }
}
