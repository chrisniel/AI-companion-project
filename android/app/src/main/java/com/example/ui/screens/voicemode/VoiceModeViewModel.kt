package com.example.ui.screens.voicemode

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.domain.model.MessageSender
import com.example.domain.model.VoiceAvatarProfile
import com.example.domain.model.VoiceSemanticState
import com.example.domain.model.VoiceSessionUiState
import com.example.domain.model.VoiceTranscriptTurn
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * ViewModel managing the dedicated mobile Voice Mode state.
 * UI-only implementation: does not implement real mic capture, STT, TTS, VAD or audio playback.
 * Provides interactive state transitions across all 10 semantic states and mock turn simulation.
 */
class VoiceModeViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(VoiceSessionUiState())
    val uiState: StateFlow<VoiceSessionUiState> = _uiState.asStateFlow()

    private var simulationJob: Job? = null

    fun selectSemanticState(state: VoiceSemanticState) {
        simulationJob?.cancel()
        _uiState.update { current ->
            current.copy(semanticState = state)
        }
    }

    fun toggleMute() {
        _uiState.update { current ->
            val newMuted = !current.isMuted
            current.copy(
                isMuted = newMuted,
                semanticState = if (newMuted) VoiceSemanticState.IDLE else VoiceSemanticState.LISTENING
            )
        }
    }

    fun interrupt() {
        simulationJob?.cancel()
        _uiState.update { current ->
            current.copy(
                semanticState = VoiceSemanticState.INTERRUPTED
            )
        }
        // Return to listening after a brief interrupted pause
        viewModelScope.launch {
            delay(1500)
            if (_uiState.value.semanticState == VoiceSemanticState.INTERRUPTED) {
                _uiState.update { it.copy(semanticState = VoiceSemanticState.LISTENING) }
            }
        }
    }

    fun selectAvatar(avatar: VoiceAvatarProfile) {
        _uiState.update { current ->
            current.copy(avatarProfile = avatar)
        }
    }

    fun toggleTextFallback(open: Boolean) {
        _uiState.update { current ->
            current.copy(isTextFallbackOpen = open)
        }
    }

    fun updateTextFallbackInput(input: String) {
        _uiState.update { current ->
            current.copy(textFallbackInput = input)
        }
    }

    fun submitTextFallback(text: String) {
        if (text.isBlank()) return

        val userTurn = VoiceTranscriptTurn(
            sender = MessageSender.USER,
            speakerLabel = "You (Fallback)",
            text = text,
            codeSwitchingSegments = listOf("Text input submitted during voice session"),
            timestamp = "Just now"
        )

        _uiState.update { current ->
            current.copy(
                turns = current.turns + userTurn,
                textFallbackInput = "",
                isTextFallbackOpen = false,
                semanticState = VoiceSemanticState.THINKING
            )
        }

        // Simulate brief thinking then speaking response
        viewModelScope.launch {
            delay(1200)
            _uiState.update { it.copy(semanticState = VoiceSemanticState.SPEAKING) }
            delay(2500)
            _uiState.update { it.copy(semanticState = VoiceSemanticState.LISTENING) }
        }
    }

    fun toggleSimulatorTray() {
        _uiState.update { current ->
            current.copy(isSimulatorTrayExpanded = !current.isSimulatorTrayExpanded)
        }
    }

    /**
     * Auto-cycles through a realistic conversational turn:
     * Listening -> Transcribing -> Thinking -> Executing Tool -> Speaking -> Listening
     */
    fun startAutoSimulateTurn() {
        simulationJob?.cancel()
        simulationJob = viewModelScope.launch {
            // 1. Listening
            _uiState.update { it.copy(semanticState = VoiceSemanticState.LISTENING) }
            delay(1600)

            // 2. Transcribing
            _uiState.update { it.copy(semanticState = VoiceSemanticState.TRANSCRIBING) }
            delay(1400)

            // 3. Thinking
            _uiState.update { it.copy(semanticState = VoiceSemanticState.THINKING) }
            delay(1800)

            // 4. Executing Tool
            _uiState.update { it.copy(semanticState = VoiceSemanticState.EXECUTING_TOOL) }
            delay(1500)

            // 5. Speaking
            _uiState.update { it.copy(semanticState = VoiceSemanticState.SPEAKING) }
            delay(3200)

            // 6. Return to Listening
            _uiState.update { it.copy(semanticState = VoiceSemanticState.LISTENING) }
        }
    }
}
