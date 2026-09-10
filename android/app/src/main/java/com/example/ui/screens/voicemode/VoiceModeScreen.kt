package com.example.ui.screens.voicemode

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.CapabilityType
import com.example.domain.model.MicrophoneCapabilityState
import com.example.domain.model.MockPermissionAction
import com.example.domain.model.VoiceSemanticState
import com.example.ui.components.CapabilityAlertBanner
import com.example.ui.components.MockActionDetailsSheet
import com.example.ui.theme.SoftTheme

/**
 * Mobile Assistant Voice Mode (Batch 4.1):
 * Dedicated immersive Voice Mode UI.
 *
 * UI-only implementation: does not implement microphone capture, STT, TTS, VAD or audio playback.
 *
 * Prioritizes:
 * - Character/avatar reacting visually to semantic states
 * - Assistant semantic states (Idle, Listening, Transcribing, Thinking, Executing Tool, Speaking, Interrupted, Reconnecting, Offline, Error)
 * - Waveform visualization
 * - Live transcript placeholder with code-switching demonstration: "Uy, ashita remind me at seven."
 * - Active language: "Auto • EN / FIL / JA"
 * - Connection status: "Local NPU • 14ms"
 * - Session controls: Mute, Interrupt, End session, Text fallback
 */
@Composable
fun VoiceModeScreen(
    onEndSession: () -> Unit,
    modifier: Modifier = Modifier,
    microphoneState: MicrophoneCapabilityState = MicrophoneCapabilityState.AVAILABLE,
    onSetMicrophoneState: (MicrophoneCapabilityState) -> Unit = {},
    viewModel: VoiceModeViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val scrollState = rememberScrollState()

    var activeMockAction by remember { mutableStateOf<MockPermissionAction?>(null) }

    val isSpeakingOrThinking = uiState.semanticState in listOf(
        VoiceSemanticState.SPEAKING,
        VoiceSemanticState.THINKING,
        VoiceSemanticState.EXECUTING_TOOL
    )

    // Background gradient tint matching state
    val stateAccentColor by animateColorAsState(
        targetValue = when (uiState.semanticState) {
            VoiceSemanticState.IDLE -> SoftTheme.colors.accentBlue.copy(alpha = 0.08f)
            VoiceSemanticState.LISTENING -> SoftTheme.colors.accentCyan.copy(alpha = 0.12f)
            VoiceSemanticState.TRANSCRIBING -> SoftTheme.colors.accentViolet.copy(alpha = 0.12f)
            VoiceSemanticState.THINKING -> SoftTheme.colors.accentBlue.copy(alpha = 0.12f)
            VoiceSemanticState.EXECUTING_TOOL -> SoftTheme.colors.accentCyan.copy(alpha = 0.12f)
            VoiceSemanticState.SPEAKING -> SoftTheme.colors.accentBlue.copy(alpha = 0.14f)
            VoiceSemanticState.INTERRUPTED -> SoftTheme.colors.statusWarning.copy(alpha = 0.14f)
            VoiceSemanticState.RECONNECTING -> SoftTheme.colors.statusWarning.copy(alpha = 0.12f)
            VoiceSemanticState.OFFLINE -> SoftTheme.colors.surfaceWell
            VoiceSemanticState.ERROR -> SoftTheme.colors.statusError.copy(alpha = 0.12f)
        },
        label = "stateAccentColor"
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(SoftTheme.colors.background)
            .testTag("voice_mode_screen")
    ) {
        // Ambient background subtle glow
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            stateAccentColor,
                            Color.Transparent,
                            stateAccentColor.copy(alpha = 0.05f)
                        )
                    )
                )
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .verticalScroll(scrollState),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // TOP BAR: End Session Action + Language Display + Connection Status
            VoiceModeTopBar(
                activeLanguage = uiState.activeLanguage,
                connectionStatus = uiState.connectionStatus,
                onClose = onEndSession
            )

            // BATCH 13: Never silently fail on microphone restrictions
            if (microphoneState != MicrophoneCapabilityState.AVAILABLE) {
                CapabilityAlertBanner(
                    title = "Microphone: ${microphoneState.displayName}",
                    explanation = microphoneState.explanation,
                    onActionClick = { action ->
                        activeMockAction = action
                    },
                    testTag = "voice_microphone_capability_banner"
                )
            }

            // SEMANTIC STATE INDICATOR BANNER
            VoiceSemanticStateBanner(
                semanticState = uiState.semanticState,
                isMuted = uiState.isMuted
            )

            Spacer(modifier = Modifier.height(2.dp))

            // CHARACTER / AVATAR
            VoiceAvatarComponent(
                semanticState = uiState.semanticState,
                avatarProfile = uiState.avatarProfile,
                availableAvatars = uiState.availableAvatars,
                onSelectAvatar = { viewModel.selectAvatar(it) }
            )

            Spacer(modifier = Modifier.height(2.dp))

            // WAVEFORM VISUALIZATION
            VoiceWaveformVisualizer(
                semanticState = uiState.semanticState,
                isMuted = uiState.isMuted
            )

            // LIVE TRANSCRIPT PLACEHOLDER (Code-Switching Demonstration)
            VoiceTranscriptView(
                semanticState = uiState.semanticState,
                turns = uiState.turns,
                interimText = uiState.interimSpeechSnippet,
                activeToolName = uiState.activeToolName
            )

            // INTERACTIVE STATE SIMULATOR TRAY (Supports all 10 states)
            VoiceStateSimulatorTray(
                currentState = uiState.semanticState,
                onSelectState = { viewModel.selectSemanticState(it) },
                onAutoSimulateTurn = { viewModel.startAutoSimulateTurn() },
                isExpanded = uiState.isSimulatorTrayExpanded,
                onToggleExpand = { viewModel.toggleSimulatorTray() }
            )

            Spacer(modifier = Modifier.height(4.dp))

            // SESSION CONTROLS: Mute, Interrupt, End Session, Text Fallback
            VoiceSessionControls(
                isMuted = uiState.isMuted,
                onToggleMute = { viewModel.toggleMute() },
                onInterrupt = { viewModel.interrupt() },
                onEndSession = onEndSession,
                onOpenTextFallback = { viewModel.toggleTextFallback(true) },
                isSpeakingOrThinking = isSpeakingOrThinking
            )

            Spacer(modifier = Modifier.height(16.dp))
        }

        // TEXT FALLBACK SHEET
        VoiceTextFallbackSheet(
            isOpen = uiState.isTextFallbackOpen,
            onDismiss = { viewModel.toggleTextFallback(false) },
            inputText = uiState.textFallbackInput,
            onInputTextChange = { viewModel.updateTextFallbackInput(it) },
            onSubmitText = { viewModel.submitTextFallback(it) }
        )

        // MOCK ACTION DETAILS SHEET
        MockActionDetailsSheet(
            isOpen = activeMockAction != null,
            action = activeMockAction,
            capabilityType = CapabilityType.MICROPHONE,
            onDismiss = { activeMockAction = null },
            onSimulateGrant = {
                onSetMicrophoneState(MicrophoneCapabilityState.AVAILABLE)
                activeMockAction = null
            }
        )
    }
}

/**
 * Top Bar showing connection status, compact active language, and close button.
 */
@Composable
private fun VoiceModeTopBar(
    activeLanguage: String,
    connectionStatus: String,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .testTag("voice_mode_top_bar"),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Back / Close action
        IconButton(
            onClick = onClose,
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(SoftTheme.colors.surfaceElevated)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = SoftTheme.colors.borderSubtle,
                    shape = CircleShape
                )
                .testTag("voice_back_button")
                .semantics { contentDescription = "Exit Voice Mode" }
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Close",
                tint = SoftTheme.colors.textPrimary,
                modifier = Modifier.size(20.dp)
            )
        }

        // Center: Compact Language Display (Auto • EN / FIL / JA)
        Row(
            modifier = Modifier
                .testTag("voice_language_display_pill")
                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                .background(SoftTheme.colors.surfaceElevated)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = SoftTheme.colors.borderSubtle,
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                )
                .padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Language,
                contentDescription = null,
                tint = SoftTheme.colors.accentBlue,
                modifier = Modifier.size(13.dp)
            )
            Text(
                text = activeLanguage,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textPrimary,
                fontSize = 11.sp
            )
        }

        // Right: Connection Status
        Row(
            modifier = Modifier
                .testTag("voice_connection_status_pill")
                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                .background(SoftTheme.colors.surfaceElevated)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = SoftTheme.colors.borderSubtle,
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                )
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.statusSuccess)
            )
            Text(
                text = connectionStatus,
                style = MaterialTheme.typography.labelSmall,
                color = SoftTheme.colors.textSecondary,
                fontSize = 10.sp
            )
        }
    }
}

/**
 * Assistant Semantic State Banner.
 * Prominently displays the current state label and contextual descriptive subtitle.
 */
@Composable
private fun VoiceSemanticStateBanner(
    semanticState: VoiceSemanticState,
    isMuted: Boolean,
    modifier: Modifier = Modifier
) {
    val stateColor = when {
        isMuted -> SoftTheme.colors.statusWarning
        semanticState == VoiceSemanticState.IDLE -> SoftTheme.colors.textMuted
        semanticState == VoiceSemanticState.LISTENING -> SoftTheme.colors.accentCyan
        semanticState == VoiceSemanticState.TRANSCRIBING -> SoftTheme.colors.accentViolet
        semanticState == VoiceSemanticState.THINKING -> SoftTheme.colors.accentBlue
        semanticState == VoiceSemanticState.EXECUTING_TOOL -> SoftTheme.colors.accentCyan
        semanticState == VoiceSemanticState.SPEAKING -> SoftTheme.colors.accentBlue
        semanticState == VoiceSemanticState.INTERRUPTED -> SoftTheme.colors.statusWarning
        semanticState == VoiceSemanticState.RECONNECTING -> SoftTheme.colors.statusWarning
        semanticState == VoiceSemanticState.OFFLINE -> SoftTheme.colors.textMuted
        semanticState == VoiceSemanticState.ERROR -> SoftTheme.colors.statusError
        else -> SoftTheme.colors.accentBlue
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .testTag("voice_semantic_state_banner"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        // State Pill
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                .background(stateColor.copy(alpha = 0.14f))
                .border(
                    width = 1.dp,
                    color = stateColor.copy(alpha = 0.35f),
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                )
                .padding(horizontal = 14.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(stateColor)
            )
            Text(
                text = if (isMuted) "MIC MUTED" else semanticState.label.uppercase(),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = stateColor,
                letterSpacing = 1.sp,
                modifier = Modifier.testTag("voice_semantic_state_label")
            )
        }

        // Subtitle Context
        Text(
            text = if (isMuted) "Microphone muted. Tap unmute or use text fallback." else semanticState.subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = SoftTheme.colors.textSecondary,
            fontSize = 12.sp,
            modifier = Modifier.testTag("voice_semantic_state_subtitle")
        )
    }
}
