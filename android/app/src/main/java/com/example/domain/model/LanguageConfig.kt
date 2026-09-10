package com.example.domain.model

enum class LanguageOption(
    val code: String,
    val label: String,
    val samplePhrase: String
) {
    AUTO("auto", "Auto", "Natural Code-Switching"),
    ENGLISH("en", "English", "What's my schedule today?"),
    FILIPINO("fil", "Filipino / Tagalog", "Remind me bukas."),
    JAPANESE("ja", "Japanese", "Android UIをチェック.");

    companion object {
        val DEFAULT = AUTO
    }
}
