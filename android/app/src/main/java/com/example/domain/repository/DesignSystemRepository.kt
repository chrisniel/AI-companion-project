package com.example.domain.repository

import com.example.domain.model.ControlCenterConfig
import com.example.domain.model.LanguageOption
import com.example.domain.model.MetricItem
import kotlinx.coroutines.flow.Flow

interface DesignSystemRepository {
    fun getConfig(): Flow<ControlCenterConfig>
    fun getMetrics(): Flow<List<MetricItem>>
    fun getSupportedLanguages(): List<LanguageOption>
}
