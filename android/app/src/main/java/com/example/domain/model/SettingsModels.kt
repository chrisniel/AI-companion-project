package com.example.domain.model

/**
 * Navigation and organization sections for Mobile Settings.
 */
enum class SettingsSection(val id: String, val title: String, val description: String) {
    GENERAL("general", "General", "Language, notifications, and startup behaviors"),
    APPEARANCE("appearance", "Appearance", "Themes, mobile backgrounds, accents, and visual effects"),
    ASSISTANT("assistant", "Assistant", "Personality, response speed, and reasoning parameters"),
    VOICE("voice", "Voice", "Speech recognition languages, mixed voice, and capabilities"),
    CONNECTION("connection", "Connection", "Local AI Core configuration and air-gapped node status"),
    ALARMS("alarms", "Alarms", "Default tones, snooze intervals, and smart wake curves"),
    HEALTH("health", "Health", "Step telemetry, sleep cycles, and local retention policies"),
    PRIVACY("privacy", "Privacy", "Zero cloud telemetry, local audit logs, and cache controls"),
    ADVANCED("advanced", "Advanced", "Developer options, database compaction, and diagnostic toggles")
}

/**
 * Startup and resume behaviors.
 */
enum class StartupBehavior(val label: String, val description: String) {
    RESUME_LAST("Resume Last Screen", "Pick up right where you left off"),
    HOME_DASHBOARD("Home Dashboard", "Always start on the central home screen"),
    VOICE_ASSISTANT("Voice Assistant", "Immediately launch hands-free voice mode")
}

/**
 * Theme selection modes.
 */
enum class ThemeMode(val label: String) {
    LIGHT("Light"),
    DARK("Dark"),
    SYSTEM("System")
}

/**
 * Theme source inheritance.
 */
enum class ThemeSource(val label: String, val description: String) {
    PHONE_THEME("Phone Theme", "Follow device native appearance schedule"),
    ACCOUNT_THEME("Account Theme", "Persist across companion user profiles"),
    SYNC_PC_THEME("Sync with PC Theme", "Mirror active Local AI Core PC theme")
}

/**
 * Background styling categories.
 */
enum class BackgroundType(val label: String, val description: String) {
    BUILT_IN("Built-in", "Curated Soft Glass gradients & textured obsidian"),
    CUSTOM_IMAGE("Custom Image UI", "Device-specific wallpaper. Never forces PC wallpaper onto mobile."),
    GRADIENT("Gradient", "Dynamic multi-stop ambient light gradients"),
    SOLID("Solid", "Minimalist matte dark/pearl single-tone background")
}

/**
 * Curated preset accent colors for Soft Glass UI.
 */
enum class AccentPreset(val label: String, val colorHex: Long) {
    CYAN("Cyan Neon", 0xFF00E5FF),
    BLUE("Electric Blue", 0xFF3B82F6),
    EMERALD("Emerald Mint", 0xFF10B981),
    AMBER("Amber Glow", 0xFFF59E0B),
    VIOLET("Soft Violet", 0xFF8B5CF6)
}

/**
 * Visual effects level for mobile performance and battery efficiency.
 */
enum class EffectsLevel(val label: String, val description: String) {
    REDUCED("Reduced", "Disable specular highlights and blurs for maximum battery"),
    NORMAL("Normal", "Balanced translucent glass with soft rim illumination"),
    ENHANCED("Enhanced", "Full specular gloss, responsive glow, and fluid physics")
}

/**
 * Language selection options for companion UI and AI reasoning.
 */
enum class AppLanguage(val code: String, val label: String, val nativeName: String) {
    ENGLISH("en", "English", "English"),
    FILIPINO("fil", "Filipino / Tagalog", "Tagalog"),
    JAPANESE("ja", "Japanese", "日本語")
}

/**
 * Conversational response language modes.
 */
enum class ResponseLanguageChoice(val label: String, val description: String) {
    MATCH_USER("Match User", "Dynamically reply in the language spoken by the user"),
    ENGLISH("English", "Always formulate assistant responses in English"),
    FILIPINO("Filipino / Tagalog", "Always formulate assistant responses in Tagalog/Filipino"),
    JAPANESE("Japanese", "Always formulate assistant responses in Japanese (日本語)")
}

/**
 * Japanese text display formatting.
 */
enum class JapaneseDisplay(val label: String, val sampleText: String) {
    JAPANESE_ONLY("Japanese Only", "了解しました。タスクをスケジュールに追加しました。"),
    JAPANESE_ROMAJI("Japanese + Romaji", "了解しました (Ryoukai shimashita) • タスクをスケジュールに追加しました"),
    JAPANESE_ENGLISH("Japanese + English Translation", "了解しました • Understood. Added the task to schedule.")
}

/**
 * Voice speech recognition languages.
 */
enum class VoiceRecognitionLanguage(val label: String, val tag: String) {
    AUTO("Auto", "auto"),
    ENGLISH("English", "en"),
    FILIPINO("Filipino / Tagalog", "fil"),
    JAPANESE("Japanese", "ja")
}

/**
 * Mock voice language model capabilities.
 */
enum class VoiceCapability(val label: String, val colorHex: Long) {
    SUPPORTED("Supported", 0xFF10B981),
    LIMITED("Limited", 0xFFF59E0B),
    UNSUPPORTED("Unsupported", 0xFFEF4444),
    UNKNOWN("Unknown", 0xFF6B7280)
}

/**
 * Detailed capability entry for mock voice language recognition model status.
 */
data class VoiceCapabilityItem(
    val language: String,
    val description: String,
    val capability: VoiceCapability
)

/**
 * Data state holding all user preferences for the application.
 */
data class SettingsState(
    // Section navigation
    val selectedSection: SettingsSection = SettingsSection.GENERAL,

    // General
    val startupBehavior: StartupBehavior = StartupBehavior.HOME_DASHBOARD,
    val notificationsEnabled: Boolean = true,
    val quietHoursEnabled: Boolean = false,
    val soundAlertsEnabled: Boolean = true,
    val hapticFeedbackEnabled: Boolean = true,

    // Appearance
    val themeMode: ThemeMode = ThemeMode.DARK,
    val themeSource: ThemeSource = ThemeSource.PHONE_THEME,
    val backgroundType: BackgroundType = BackgroundType.BUILT_IN,
    val selectedBuiltInBackground: String = "Obsidian Deep Glass",
    val selectedGradientBackground: String = "Cyan-Violet Fluid Mesh",
    val selectedSolidBackground: String = "Deep Matte Obsidian (#0D1117)",
    val customImageName: String = "mobile_aurora_custom.jpg",
    val accentPreset: AccentPreset = AccentPreset.CYAN,
    val customAccentHex: String = "#00D4FF",
    val isCustomAccentEnabled: Boolean = false,
    val effectsLevel: EffectsLevel = EffectsLevel.NORMAL,
    val scrimOpacity: Float = 0.20f,
    val backgroundBrightness: Float = 1.0f,

    // Language Preferences
    val primaryLanguage: AppLanguage = AppLanguage.ENGLISH,
    val understandsLanguages: Set<AppLanguage> = setOf(
        AppLanguage.ENGLISH,
        AppLanguage.FILIPINO,
        AppLanguage.JAPANESE
    ),
    val mixedLanguageConversation: Boolean = true,
    val responseLanguage: ResponseLanguageChoice = ResponseLanguageChoice.MATCH_USER,
    val technicalLanguage: ResponseLanguageChoice = ResponseLanguageChoice.MATCH_USER,
    val japaneseDisplay: JapaneseDisplay = JapaneseDisplay.JAPANESE_ENGLISH,

    // Voice
    val voiceRecognitionLanguage: VoiceRecognitionLanguage = VoiceRecognitionLanguage.AUTO,
    val mixedLanguageRecognition: Boolean = true,

    // Assistant
    val responseDetailLevel: String = "Balanced",
    val proactiveSuggestions: Boolean = true,
    val chainOfThoughtVisible: Boolean = true,

    // Alarms
    val defaultAlarmTone: String = "Soft Chime",
    val defaultSnoozeMinutes: Int = 10,
    val gradualVolumeRamp: Boolean = true,

    // Health
    val backgroundStepTracking: Boolean = true,
    val sleepCycleSync: Boolean = true,
    val healthDataRetentionDays: String = "90 Days",

    // Privacy
    val auditLoggingEnabled: Boolean = true,
    val ephemeralSessions: Boolean = false,

    // Advanced
    val developerMode: Boolean = false,
    val diagnosticsOverlay: Boolean = false,
    val lastCompactionTimestamp: String = "Never",

    // User feedback banner / snackbar
    val statusMessage: String? = null
)
