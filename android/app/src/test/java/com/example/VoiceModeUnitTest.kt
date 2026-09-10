package com.example

import com.example.domain.model.VoiceAvatarProfile
import com.example.domain.model.VoiceSemanticState
import com.example.ui.screens.voicemode.VoiceModeViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for Voice Mode ViewModel and state machine (Batch 4.1).
 */
class VoiceModeUnitTest {

    @Test
    fun `default state has 10 supported semantic states and contains verbatim code-switching`() {
        val viewModel = VoiceModeViewModel()
        val state = viewModel.uiState.value

        assertEquals(VoiceSemanticState.LISTENING, state.semanticState)
        assertFalse(state.isMuted)
        assertEquals("Auto • EN / FIL / JA", state.activeLanguage)

        // Verbatim code-switching test: "Uy, ashita remind me at seven."
        val userTurn = state.turns.first { it.sender.name == "USER" }
        assertEquals("Uy, ashita remind me at seven.", userTurn.text)

        // Verify all 10 semantic states exist in enum
        assertEquals(10, VoiceSemanticState.entries.size)
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.IDLE))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.LISTENING))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.TRANSCRIBING))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.THINKING))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.EXECUTING_TOOL))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.SPEAKING))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.INTERRUPTED))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.RECONNECTING))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.OFFLINE))
        assertTrue(VoiceSemanticState.entries.contains(VoiceSemanticState.ERROR))
    }

    @Test
    fun `toggle mute switches state between muted idle and listening`() {
        val viewModel = VoiceModeViewModel()

        viewModel.toggleMute()
        assertTrue(viewModel.uiState.value.isMuted)
        assertEquals(VoiceSemanticState.IDLE, viewModel.uiState.value.semanticState)

        viewModel.toggleMute()
        assertFalse(viewModel.uiState.value.isMuted)
        assertEquals(VoiceSemanticState.LISTENING, viewModel.uiState.value.semanticState)
    }

    @Test
    fun `interrupt transitions to INTERRUPTED state`() {
        val viewModel = VoiceModeViewModel()

        viewModel.selectSemanticState(VoiceSemanticState.SPEAKING)
        assertEquals(VoiceSemanticState.SPEAKING, viewModel.uiState.value.semanticState)

        viewModel.interrupt()
        assertEquals(VoiceSemanticState.INTERRUPTED, viewModel.uiState.value.semanticState)
    }

    @Test
    fun `avatar switching updates active profile`() {
        val viewModel = VoiceModeViewModel()

        assertEquals("aria", viewModel.uiState.value.avatarProfile.id)

        viewModel.selectAvatar(VoiceAvatarProfile.Kage)
        assertEquals("kage", viewModel.uiState.value.avatarProfile.id)
        assertEquals("Kage", viewModel.uiState.value.avatarProfile.name)

        viewModel.selectAvatar(VoiceAvatarProfile.Lumina)
        assertEquals("lumina", viewModel.uiState.value.avatarProfile.id)
    }

    @Test
    fun `text fallback preserves session and adds user turn`() {
        val viewModel = VoiceModeViewModel()

        viewModel.toggleTextFallback(true)
        assertTrue(viewModel.uiState.value.isTextFallbackOpen)

        val query = "Uy, ashita remind me at seven."
        viewModel.submitTextFallback(query)

        assertFalse(viewModel.uiState.value.isTextFallbackOpen)
        val lastTurn = viewModel.uiState.value.turns.last()
        assertEquals(query, lastTurn.text)
        assertEquals(VoiceSemanticState.THINKING, viewModel.uiState.value.semanticState)
    }
}
