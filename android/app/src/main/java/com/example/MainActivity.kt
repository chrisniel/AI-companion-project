package com.example

import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.domain.model.RefreshRateMode
import com.example.ui.AppViewModelProvider
import com.example.ui.preview.DesignSystemViewModel
import com.example.ui.shell.AppShell
import com.example.ui.shell.AppViewModel
import com.example.ui.theme.SoftGlassTheme
import kotlin.math.abs

class MainActivity : ComponentActivity() {
    private val appViewModel: AppViewModel by viewModels { AppViewModelProvider.Factory }
    private val designSystemViewModel: DesignSystemViewModel by viewModels { AppViewModelProvider.Factory }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val appContainer = (application as CompanionApplication).appContainer

        setContent {
            val preferences by appContainer.appearanceRepository.preferences.collectAsStateWithLifecycle()

            LaunchedEffect(preferences.refreshRateMode) {
                applyRefreshRateMode(preferences.refreshRateMode)
            }

            SoftGlassTheme(preferences = preferences) {
                AppShell(
                    modifier = Modifier.fillMaxSize(),
                    appViewModel = appViewModel,
                    designSystemViewModel = designSystemViewModel
                )
            }
        }
    }

    private fun applyRefreshRateMode(mode: RefreshRateMode) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
            val modes = display?.supportedModes ?: emptyArray()
            val layoutParams = window.attributes

            when (mode) {
                RefreshRateMode.FORCE_HIGH -> {
                    val highMode = modes.maxByOrNull { it.refreshRate }
                    if (highMode != null) {
                        layoutParams.preferredDisplayModeId = highMode.modeId
                    }
                    val maxRate = modes.maxOfOrNull { it.refreshRate } ?: 120f
                    layoutParams.preferredRefreshRate = maxRate
                }
                RefreshRateMode.POWER_SAVER -> {
                    val powerSaverMode = modes.filter { it.refreshRate in 59.0f..61.0f }
                        .minByOrNull { abs(it.refreshRate - 60f) }
                        ?: modes.minByOrNull { it.refreshRate }
                    if (powerSaverMode != null) {
                        layoutParams.preferredDisplayModeId = powerSaverMode.modeId
                    }
                    layoutParams.preferredRefreshRate = 60f
                }
                RefreshRateMode.SYSTEM_DEFAULT -> {
                    val highMode = modes.firstOrNull { it.refreshRate >= 119.0f }
                    if (highMode != null) {
                        layoutParams.preferredDisplayModeId = highMode.modeId
                    } else {
                        layoutParams.preferredDisplayModeId = 0
                    }
                    layoutParams.preferredRefreshRate = 0f
                }
            }
            window.attributes = layoutParams
        }
    }
}
