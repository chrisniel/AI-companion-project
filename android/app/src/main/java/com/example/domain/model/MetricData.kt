package com.example.domain.model

data class MetricItem(
    val id: String,
    val title: String,
    val value: String,
    val unit: String = "",
    val subtitle: String? = null,
    val progress: Float? = null,
    val trendPercentage: Float? = null,
    val isPositiveTrend: Boolean? = true,
    val severity: StatusSeverity = StatusSeverity.Normal
)
