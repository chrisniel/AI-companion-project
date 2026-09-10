package com.example.domain.model

import androidx.compose.ui.graphics.Color

/**
 * Avatar display mode options for character profiles.
 */
enum class AvatarDisplayMode(
    val title: String,
    val description: String
) {
    FULL("Full", "Render full avatar illustration across all app surfaces"),
    COMPACT("Compact", "Render minimal compact badge avatar"),
    VOICE_MODE_ONLY("Voice Mode Only", "Display avatar exclusively during active voice mode sessions"),
    HIDDEN("Hidden", "Suppress avatar graphics for a clean, text-centric interface")
}

/**
 * Japanese conversational tone options.
 */
enum class JapaneseTone(
    val title: String,
    val description: String,
    val sampleSuffix: String
) {
    NEUTRAL("Neutral", "Balanced, polite standard Japanese (Desu/Masu phrasing)", "〜ですね。確認しました。"),
    WARM_MATURE("Warm / Mature", "Gentle, reassuring, supportive intonation", "〜ですよ。ゆっくり進めましょうね。"),
    PLAYFUL("Playful", "Energetic, casual, expressive phrasing", "〜だよ！今日も一緒に頑張ろう！"),
    FORMAL("Formal", "Keigo, structured, business-level precision", "〜でございます。承知いたしました。")
}

/**
 * Code-switching presentation style.
 */
enum class CodeSwitchingStyle(
    val title: String,
    val description: String
) {
    NATURAL_BLEND("Natural Blend", "Fluid Taglish / Japanese loanwords naturally integrated into conversation"),
    CONTEXTUAL_PIVOT("Contextual Pivot", "Switches phrasing depending on task type, urgency, or topic domain"),
    TERMINOLOGY_ONLY("Terminology Only", "Retains domain-specific technical jargon in its original tongue"),
    NONE_STRICT("None / Strict", "Maintains pure, unmixed single-language responses")
}

/**
 * Granular frequency level for language mixing.
 */
enum class FrequencyLevel(
    val title: String,
    val percentage: Int
) {
    NONE("None", 0),
    OCCASIONAL("Occasional", 25),
    MODERATE("Moderate", 50),
    FREQUENT("Frequent", 75),
    FULL("Full", 100)
}

/**
 * Language style configuration for persona presentation.
 * Note: Language capability belongs to system/user settings.
 * Character language style only affects personality and presentation.
 */
data class LanguageStyleConfig(
    val primaryLanguage: String = "English",
    val secondaryLanguages: List<String> = listOf("Tagalog", "Japanese"),
    val matchUserLanguage: Boolean = true,
    val codeSwitchingStyle: CodeSwitchingStyle = CodeSwitchingStyle.NATURAL_BLEND,
    val tagalogFrequency: FrequencyLevel = FrequencyLevel.MODERATE,
    val japaneseFrequency: FrequencyLevel = FrequencyLevel.OCCASIONAL,
    val japaneseTone: JapaneseTone = JapaneseTone.WARM_MATURE
)

/**
 * Mock voice profile definition.
 */
data class VoiceProfile(
    val id: String,
    val name: String,
    val timbre: String,
    val pitch: String,
    val speed: String,
    val accentTag: String
)

/**
 * Visual styling token for avatar rendering.
 */
data class AvatarStyle(
    val id: String,
    val name: String,
    val primaryColorHex: Long,
    val secondaryColorHex: Long,
    val accentColorHex: Long,
    val glyphSymbol: String
)

/**
 * Configurable character profile representing persona, voice, and speaking style.
 * Distinct from application user identity.
 */
data class CharacterProfile(
    val id: String,
    val displayName: String,
    val persona: String,
    val responseStyle: String,
    val avatarStyle: AvatarStyle,
    val avatarDisplay: AvatarDisplayMode = AvatarDisplayMode.FULL,
    val voice: VoiceProfile,
    val speakingStyle: String,
    val languageStyle: LanguageStyleConfig = LanguageStyleConfig(),
    val isActive: Boolean = false,
    val isCustom: Boolean = false,
    val sampleDialogue: String = ""
)
