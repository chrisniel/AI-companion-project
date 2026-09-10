package com.example.domain.model

/**
 * Visual and operational states for design system components.
 */
enum class ComponentVisualState {
    Normal,
    Pressed,
    Selected,
    Disabled,
    Loading,
    Success,
    Warning,
    Error
}

/**
 * Semantic severity levels for feedback and indicators.
 */
enum class StatusSeverity {
    Normal,
    Info,
    Success,
    Warning,
    Error
}
