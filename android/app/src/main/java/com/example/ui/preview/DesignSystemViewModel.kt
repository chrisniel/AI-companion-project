package com.example.ui.preview

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.fake.FakeDesignSystemRepository
import com.example.domain.model.ComponentVisualState
import com.example.domain.model.ControlCenterConfig
import com.example.domain.model.LanguageOption
import com.example.domain.model.MetricItem
import com.example.domain.repository.DesignSystemRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class FeedbackMode {
    Loading,
    Empty,
    Error
}

data class DesignSystemUiState(
    val isDarkTheme: Boolean = false,
    val selectedVisualState: ComponentVisualState = ComponentVisualState.Normal,
    val config: ControlCenterConfig = ControlCenterConfig(),
    val metrics: List<MetricItem> = emptyList(),
    val supportedLanguages: List<LanguageOption> = LanguageOption.entries,
    val selectedLanguage: LanguageOption = LanguageOption.AUTO,
    val toggleChecked: Boolean = true,
    val sliderValue: Float = 0.72f,
    val searchQuery: String = "",
    val textFieldInput: String = "Llama-3.1-8B-Instruct",
    val textFieldError: String? = null,
    val circularMetricPercentage: Float = 0.75f,
    val selectedPersona: String = "Aura",
    val isPrimaryLoading: Boolean = false,
    val isPrimarySuccess: Boolean = false,
    val isNeumorphicPressedSimulated: Boolean = false,
    val showBottomSheet: Boolean = false,
    val showDialog: Boolean = false,
    val feedbackMode: FeedbackMode = FeedbackMode.Loading
)

class DesignSystemViewModel(
    private val repository: DesignSystemRepository = FakeDesignSystemRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(DesignSystemUiState())
    val uiState: StateFlow<DesignSystemUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.getConfig().collect { config ->
                _uiState.update { it.copy(config = config) }
            }
        }
        viewModelScope.launch {
            repository.getMetrics().collect { metrics ->
                _uiState.update { it.copy(metrics = metrics) }
            }
        }
        _uiState.update {
            it.copy(supportedLanguages = repository.getSupportedLanguages())
        }
    }

    fun toggleDarkTheme() {
        _uiState.update { it.copy(isDarkTheme = !it.isDarkTheme) }
    }

    fun selectVisualState(state: ComponentVisualState) {
        _uiState.update { currentState ->
            currentState.copy(
                selectedVisualState = state,
                isPrimaryLoading = state == ComponentVisualState.Loading,
                isPrimarySuccess = state == ComponentVisualState.Success,
                isNeumorphicPressedSimulated = state == ComponentVisualState.Pressed,
                textFieldError = if (state == ComponentVisualState.Error) "Invalid model checkpoint format" else null
            )
        }
    }

    fun selectLanguage(lang: LanguageOption) {
        _uiState.update { it.copy(selectedLanguage = lang) }
    }

    fun setToggleChecked(checked: Boolean) {
        _uiState.update { it.copy(toggleChecked = checked) }
    }

    fun setSliderValue(value: Float) {
        _uiState.update { it.copy(sliderValue = value) }
    }

    fun setSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
    }

    fun setTextFieldInput(input: String) {
        _uiState.update { it.copy(textFieldInput = input) }
    }

    fun setCircularMetricPercentage(pct: Float) {
        _uiState.update { it.copy(circularMetricPercentage = pct) }
    }

    fun selectPersona(persona: String) {
        _uiState.update { it.copy(selectedPersona = persona) }
    }

    fun triggerPrimaryAction() {
        viewModelScope.launch {
            _uiState.update { it.copy(isPrimaryLoading = true, isPrimarySuccess = false) }
            delay(1200)
            _uiState.update { it.copy(isPrimaryLoading = false, isPrimarySuccess = true) }
            delay(1400)
            _uiState.update { it.copy(isPrimarySuccess = false) }
        }
    }

    fun toggleNeumorphicSimulatedPress() {
        _uiState.update { it.copy(isNeumorphicPressedSimulated = !it.isNeumorphicPressedSimulated) }
    }

    fun setShowBottomSheet(show: Boolean) {
        _uiState.update { it.copy(showBottomSheet = show) }
    }

    fun setShowDialog(show: Boolean) {
        _uiState.update { it.copy(showDialog = show) }
    }

    fun setFeedbackMode(mode: FeedbackMode) {
        _uiState.update { it.copy(feedbackMode = mode) }
    }
}
