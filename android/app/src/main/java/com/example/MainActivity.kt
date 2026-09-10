package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.ui.AppViewModelProvider
import com.example.ui.preview.DesignSystemViewModel
import com.example.ui.shell.AppShell
import com.example.ui.shell.AppViewModel
import com.example.ui.theme.SoftGlassTheme

class MainActivity : ComponentActivity() {
    private val appViewModel: AppViewModel by viewModels { AppViewModelProvider.Factory }
    private val designSystemViewModel: DesignSystemViewModel by viewModels { AppViewModelProvider.Factory }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val appContainer = (application as CompanionApplication).appContainer

        setContent {
            val preferences by appContainer.appearanceRepository.preferences.collectAsStateWithLifecycle()

            SoftGlassTheme(preferences = preferences) {
                AppShell(
                    modifier = Modifier.fillMaxSize(),
                    appViewModel = appViewModel,
                    designSystemViewModel = designSystemViewModel
                )
            }
        }
    }
}
