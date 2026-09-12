package com.example.domain.model

import java.util.UUID

/**
 * Mobile Assistant Voice Mode (Batch 4.1):
 * Semantic operational states for the real-time voice assistant experience.
 */
enum class VoiceSemanticState(
    val label: String,
    val subtitle: String
) {
    IDLE(
        label = "Idle",
        subtitle = "Awaiting wake word or user speech..."
    ),
    LISTENING(
        label = "Listening",
        subtitle = "Receiving real-time acoustic stream..."
    ),
    TRANSCRIBING(
        label = "Transcribing",
        subtitle = "Decoding multilingual phonemes to text tokens..."
    ),
    THINKING(
        label = "Thinking",
        subtitle = "Local LLM inferencing on NPU..."
    ),
    EXECUTING_TOOL(
        label = "Executing Tool",
        subtitle = "Running local slot action: calendar_reminder.create()"
    ),
    SPEAKING(
        label = "Speaking",
        subtitle = "Synthesizing vocal response via on-device TTS..."
    ),
    INTERRUPTED(
        label = "Interrupted",
        subtitle = "User barge-in detected. Flushed synthesis buffer."
    ),
    RECONNECTING(
        label = "Reconnecting",
        subtitle = "Re-establishing connection with local node..."
    ),
    OFFLINE(
        label = "Offline",
        subtitle = "Core disconnected. Operating in offline intent parser."
    ),
    ERROR(
        label = "Error",
        subtitle = "Acoustic buffer overflow or inference failure."
    )
}

/**
 * Character/Avatar profile configuration.
 * Business logic references this abstract profile without coupling to
 * hardcoded character-specific file assets.
 */
data class VoiceAvatarProfile(
    val id: String,
    val name: String,
    val title: String,
    val archetype: String,
    val accentTag: String = "Neural"
) {
    companion object {
        val Aria = VoiceAvatarProfile(
            id = "aria",
            name = "Aria",
            title = "Neural Companion",
            archetype = "Adaptive & Attentive",
            accentTag = "Multilingual Specialist"
        )

        val Kage = VoiceAvatarProfile(
            id = "kage",
            name = "Kage",
            title = "Tactical Operator",
            archetype = "Deterministic & Precise",
            accentTag = "System Core"
        )

        val Lumina = VoiceAvatarProfile(
            id = "lumina",
            name = "Lumina",
            title = "Ambient Core",
            archetype = "Gentle & Exploratory",
            accentTag = "Knowledge Base"
        )

        val ALL = listOf(Aria, Kage, Lumina)
    }
}

/**
 * Individual turn in the voice conversation transcript.
 */
data class VoiceTranscriptTurn(
    val id: String = UUID.randomUUID().toString(),
    val sender: MessageSender,
    val speakerLabel: String,
    val text: String,
    val codeSwitchingSegments: List<String> = emptyList(),
    val confidence: Float = 0.96f,
    val timestamp: String = "Just now"
)

/**
 * Immutable UI State for the dedicated Voice Mode experience.
 */
data class VoiceSessionUiState(
    val semanticState: VoiceSemanticState = VoiceSemanticState.LISTENING,
    val isMuted: Boolean = false,
    val avatarProfile: VoiceAvatarProfile = VoiceAvatarProfile.Aria,
    val availableAvatars: List<VoiceAvatarProfile> = VoiceAvatarProfile.ALL,
    val connectionStatus: String = "Local NPU • 14ms",
    val connectionDetail: String = "Orin NPU (INT4 Runtime)",
    val activeLanguage: String = "Auto • EN / FIL / JA",
    val turns: List<VoiceTranscriptTurn> = listOf(
        VoiceTranscriptTurn(
            sender = MessageSender.USER,
            speakerLabel = "You",
            text = "Uy, ashita remind me at seven.",
            codeSwitchingSegments = listOf("Tagalog: Uy", "Japanese: 明日 (ashita)", "English: remind me at seven."),
            confidence = 0.98f,
            timestamp = "10:42 AM"
        ),
        VoiceTranscriptTurn(
            sender = MessageSender.ASSISTANT,
            speakerLabel = "Aria",
            text = "Sige! I've set a reminder for tomorrow (明日) at 7:00 AM.",
            codeSwitchingSegments = listOf("Tagalog: Sige", "English: I've set a reminder for tomorrow", "Japanese: 明日"),
            confidence = 0.99f,
            timestamp = "10:42 AM"
        )
    ),
    val interimSpeechSnippet: String = "Uy, ashita remind me at seven.",
    val activeToolName: String? = "calendar_reminder.create()",
    val isTextFallbackOpen: Boolean = false,
    val textFallbackInput: String = "",
    val isSimulatorTrayExpanded: Boolean = true
)
