package com.example.ui.screens.models

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeModelsAndDevicesRepository
import com.example.domain.model.ModelInfo
import com.example.domain.model.ModelsUiState
import com.example.domain.model.PerformanceProfile
import com.example.domain.model.RoutingPolicy
import com.example.domain.repository.ModelsAndDevicesRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * ViewModel for the Mobile Models page (Batch 9).
 * Presents lightweight mobile model information, performance profile toggling,
 * routing policy selection, and an optional expandable mock PC resource summary.
 */
class ModelsViewModel(
    private val repository: ModelsAndDevicesRepository = FakeModelsAndDevicesRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        ModelsUiState(
            currentModel = repository.currentModel.value,
            availableModels = repository.availableModels.value,
            performanceProfile = repository.performanceProfile.value,
            routingPolicy = repository.routingPolicy.value,
            pcResourceSummary = repository.pcResources.value,
            isPcResourcesExpanded = false
        )
    )
    val uiState: StateFlow<ModelsUiState> = _uiState.asStateFlow()

    fun selectModel(modelId: String) {
        val selected = _uiState.value.availableModels.firstOrNull { it.id == modelId }
        if (selected != null) {
            _uiState.update { it.copy(currentModel = selected) }
        }
        showStatus("Active model switched to: ${selected?.name ?: modelId}")
        viewModelScope.launch {
            repository.selectModel(modelId)
        }
    }

    fun setPerformanceProfile(profile: PerformanceProfile) {
        _uiState.update { it.copy(performanceProfile = profile) }
        showStatus("Performance profile set to ${profile.displayName}")
        viewModelScope.launch {
            repository.setPerformanceProfile(profile)
        }
    }

    fun setRoutingPolicy(policy: RoutingPolicy) {
        _uiState.update { it.copy(routingPolicy = policy) }
        showStatus("Routing policy updated to ${policy.displayName}")
        viewModelScope.launch {
            repository.setRoutingPolicy(policy)
        }
    }

    fun togglePcResources() {
        _uiState.update { it.copy(isPcResourcesExpanded = !it.isPcResourcesExpanded) }
    }

    fun clearStatus() {
        _uiState.update { it.copy(statusMessage = null) }
    }

    private fun showStatus(message: String) {
        _uiState.update { it.copy(statusMessage = message) }
    }
}
