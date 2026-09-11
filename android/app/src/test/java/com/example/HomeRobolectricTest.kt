package com.example

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import com.example.domain.model.CoreConnectionState
import com.example.ui.shell.AppShell
import com.example.ui.shell.AppViewModel
import com.example.ui.theme.SoftGlassTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = RobolectricDeviceQualifiers.Pixel8, sdk = [36])
class HomeRobolectricTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun `home screen answers all 5 core questions and renders all key sections`() {
        val appViewModel = AppViewModel()

        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                AppShell(appViewModel = appViewModel)
            }
        }

        // 1. Header: Contextual greeting with profile name (never hardcoded)
        composeTestRule.onNodeWithTag("home_header_greeting").assertIsDisplayed()
        composeTestRule.onNodeWithText("Aura is online").assertIsDisplayed()

        // 2. Assistant Hero: Reachability, active character, assistant state, model summary
        composeTestRule.onNodeWithTag("home_assistant_hero").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_reachability_status", useUnmergedTree = true).assertIsDisplayed()
        composeTestRule.onNodeWithText("Aura").assertIsDisplayed()
        composeTestRule.onNodeWithText("Assistant: Attentive & Ready").assertIsDisplayed()
        composeTestRule.onNodeWithText("Local AI Core • Windows PC (Active Model Ready)").assertIsDisplayed()

        // 3. Quick Actions: 4 large tactile mobile-friendly actions
        composeTestRule.onNodeWithTag("home_quick_action_ask").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_quick_action_add_task").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_quick_action_alarm").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_quick_action_reminder").assertIsDisplayed()

        // 4. Next Up: Scheduled time, countdown, important event flag
        composeTestRule.onNodeWithTag("home_next_section").assertIsDisplayed()
        composeTestRule.onNodeWithText("Primary Wakeup Alarm").assertIsDisplayed()
        composeTestRule.onAllNodesWithText("Upcoming")[0].assertIsDisplayed()
        composeTestRule.onNodeWithText("Important Event").assertIsDisplayed()

        // 5. Today's Workflow: Completed count, active reminders, open tasks
        composeTestRule.onNodeWithTag("home_today_section").assertIsDisplayed()
        composeTestRule.onNodeWithText("2 of 8 completed").assertIsDisplayed()
        composeTestRule.onNodeWithText("2 active reminders").assertIsDisplayed()
        composeTestRule.onAllNodesWithText("Check backend bukas")[0].assertIsDisplayed()

        // 6. Wellness Glance: Sleep, Heart Rate, Steps / Activity
        composeTestRule.onNodeWithTag("home_wellness_section").performScrollTo().assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_wellness_sleep").performScrollTo().assertIsDisplayed()
        composeTestRule.onNodeWithText("7h 45m").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_wellness_heart").assertIsDisplayed()
        composeTestRule.onNodeWithText("71 BPM").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_wellness_steps").assertIsDisplayed()
        composeTestRule.onNodeWithText("8420").assertIsDisplayed()
    }

    @Test
    fun `quick action ask navigates to Assistant`() {
        val appViewModel = AppViewModel()

        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                AppShell(appViewModel = appViewModel)
            }
        }

        // Tap Ask quick action
        composeTestRule.onNodeWithTag("home_quick_action_ask").performClick()
        composeTestRule.onNodeWithText("Local Assistant").assertIsDisplayed()
    }

    @Test
    fun `quick action alarm navigates to Alarms`() {
        val appViewModel = AppViewModel()

        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                AppShell(appViewModel = appViewModel)
            }
        }

        // Tap Alarm quick action
        composeTestRule.onNodeWithTag("home_quick_action_alarm").performClick()
        composeTestRule.onNodeWithTag("alarms_screen").assertIsDisplayed()
    }

    @Test
    fun `quick action reminder navigates to Schedule`() {
        val appViewModel = AppViewModel()

        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                AppShell(appViewModel = appViewModel)
            }
        }

        // Tap Reminder quick action
        composeTestRule.onNodeWithTag("home_quick_action_reminder").performClick()
        composeTestRule.onNodeWithTag("schedule_screen").assertIsDisplayed()
    }

    @Test
    fun `task item can be checked off interactively`() {
        val appViewModel = AppViewModel()

        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                AppShell(appViewModel = appViewModel)
            }
        }

        // Check off task-1
        composeTestRule.onNodeWithTag("home_task_item_task-1").performClick()

        // Completed count should increase to 3 of 8
        composeTestRule.onNodeWithText("3 of 8 completed").assertIsDisplayed()
    }
}
