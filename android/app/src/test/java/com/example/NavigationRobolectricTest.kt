package com.example

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.compose.ui.test.swipeRight
import com.example.domain.model.CoreConnectionState
import com.example.navigation.Routes
import com.example.ui.preview.DesignSystemViewModel
import com.example.ui.shell.AppShell
import com.example.ui.shell.AppViewModel
import com.example.ui.theme.SoftGlassTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel8, sdk = [36])
class NavigationRobolectricTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun `connection state cycles through mock semantic states`() {
        val viewModel = AppViewModel()
        assertEquals(CoreConnectionState.Local, viewModel.uiState.value.connectionInfo.state)

        viewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Remote, viewModel.uiState.value.connectionInfo.state)

        viewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Connecting, viewModel.uiState.value.connectionInfo.state)

        viewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Reconnecting, viewModel.uiState.value.connectionInfo.state)

        viewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Offline, viewModel.uiState.value.connectionInfo.state)

        viewModel.cycleConnectionState()
        assertEquals(CoreConnectionState.Local, viewModel.uiState.value.connectionInfo.state)
    }

    @Test
    fun `app shell renders primary navigation and switches destinations`() {
        val appViewModel = AppViewModel()
        val designSystemViewModel = DesignSystemViewModel()

        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                AppShell(
                    appViewModel = appViewModel,
                    designSystemViewModel = designSystemViewModel
                )
            }
        }

        // Initially on Home
        composeTestRule.onNodeWithTag("nav_item_home").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_user_avatar").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_user_avatar").performClick()
        composeTestRule.onAllNodesWithTag("topbar_connection_indicator")
            .onFirst()
            .assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_user_avatar").performClick()

        // Navigate to Assistant
        composeTestRule.onNodeWithTag("nav_item_assistant").performClick()
        composeTestRule.onNodeWithText("Local Assistant").assertIsDisplayed()

        // Navigate to Tasks
        composeTestRule.onNodeWithTag("nav_item_tasks").performClick()
        composeTestRule.onNodeWithTag("tasks_screen").assertIsDisplayed()

        // Navigate to Health
        composeTestRule.onNodeWithTag("nav_item_health").performClick()
        composeTestRule.onNodeWithTag("health_screen").assertIsDisplayed()

        // Navigate to More
        composeTestRule.onNodeWithTag("nav_item_more").performClick()
        composeTestRule.onNodeWithText("TIME & AGENDA").assertIsDisplayed()
        composeTestRule.onNodeWithTag("more_item_schedule").assertIsDisplayed()
        composeTestRule.onNodeWithTag("more_item_settings").assertIsDisplayed()

        // Navigate from More to Schedule
        composeTestRule.onNodeWithTag("more_item_schedule").performClick()
        composeTestRule.onNodeWithTag("schedule_screen").assertIsDisplayed()
        composeTestRule.onNodeWithTag("topbar_back_button").assertIsDisplayed()

        // Navigate back to More
        composeTestRule.onNodeWithTag("topbar_back_button").performClick()
        composeTestRule.onNodeWithText("TIME & AGENDA").assertIsDisplayed()

        // Return to Home
        composeTestRule.onNodeWithTag("nav_item_home").performClick()
        composeTestRule.onNodeWithText("NEXT UP").assertIsDisplayed()
    }

    @Test
    fun `horizontal swipe gestures smoothly navigate across primary tabs`() {
        val appViewModel = AppViewModel()
        val designSystemViewModel = DesignSystemViewModel()

        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                AppShell(
                    appViewModel = appViewModel,
                    designSystemViewModel = designSystemViewModel
                )
            }
        }

        // Initially on Home
        composeTestRule.onNodeWithTag("home_screen").assertIsDisplayed()

        // Swipe left from Home to Tasks
        composeTestRule.onNodeWithTag("home_screen").performTouchInput {
            swipeLeft()
        }
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithTag("tasks_screen").assertIsDisplayed()

        // Swipe left from Tasks to Assistant
        composeTestRule.onNodeWithTag("tasks_screen").performTouchInput {
            swipeLeft()
        }
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Local Assistant").assertIsDisplayed()

        // Swipe right from Assistant back to Tasks
        composeTestRule.onNodeWithTag("assistant_screen").performTouchInput {
            swipeRight()
        }
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithTag("tasks_screen").assertIsDisplayed()
    }
}
