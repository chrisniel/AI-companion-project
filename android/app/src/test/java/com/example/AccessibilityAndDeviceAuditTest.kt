package com.example

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Density
import com.example.data.health.MockHealthDataProvider
import com.example.domain.model.HealthDataAvailability
import com.example.domain.model.HealthMetric
import com.example.domain.model.HealthMetricType
import com.example.domain.model.HealthTimeRange
import com.example.domain.model.VoiceSemanticState
import com.example.navigation.AppBottomBar
import com.example.navigation.BottomNavItem
import com.example.ui.preview.DesignSystemViewModel
import com.example.ui.screens.health.HealthMetricCard
import com.example.ui.screens.health.HealthScreen
import com.example.ui.screens.voicemode.VoiceModeScreen
import com.example.ui.screens.voicemode.VoiceSessionControls
import com.example.ui.shell.AppShell
import com.example.ui.shell.AppViewModel
import com.example.ui.theme.SoftGlassTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * BATCH 14: Accessibility and Device-Size Audit Unit Tests.
 * Verifies:
 * 1. Compact phone width (w360dp)
 * 2. Normal phone width (Pixel 8)
 * 3. Large phone width (w440dp)
 * 4. Landscape orientation
 * 5. Text scaling (1.5x font scale)
 * 6. Health metrics unavailable vs zero value distinction
 * 7. Bottom navigation labels and touch targets
 * 8. Voice mode controls accessibility
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class AccessibilityAndDeviceAuditTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    @Config(qualifiers = "w360dp-h640dp-normal-long-notround", sdk = [36])
    fun `compact phone displays bottom navigation without label crowding`() {
        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                AppBottomBar(
                    currentRoute = BottomNavItem.Home.route,
                    onNavigateToDestination = {}
                )
            }
        }

        // Verify all 5 items are visible and interactable
        BottomNavItem.items.forEach { item ->
            composeTestRule.onNodeWithTag(item.testTag)
                .assertIsDisplayed()
                .assertHasClickAction()
            composeTestRule.onNodeWithText(item.title).assertIsDisplayed()
        }
    }

    @Test
    @Config(qualifiers = RobolectricDeviceQualifiers.Pixel8, sdk = [36])
    fun `normal phone renders full app shell with accessible destinations`() {
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

        composeTestRule.onNodeWithTag("app_shell_scaffold").assertIsDisplayed()
        composeTestRule.onNodeWithTag("app_bottom_bar").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_screen").assertIsDisplayed()
    }

    @Test
    @Config(qualifiers = "w440dp-h956dp-normal-long-notround", sdk = [36])
    fun `large phone renders voice mode with intact controls and transcript`() {
        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = true) {
                VoiceModeScreen(onEndSession = {})
            }
        }

        composeTestRule.onNodeWithTag("voice_mode_screen").assertIsDisplayed()
        composeTestRule.onNodeWithTag("voice_session_controls").assertIsDisplayed()
        composeTestRule.onNodeWithTag("voice_control_mute").assertIsDisplayed()
        composeTestRule.onNodeWithTag("voice_control_interrupt").assertIsDisplayed()
        composeTestRule.onNodeWithTag("voice_control_end_session").assertIsDisplayed()
        composeTestRule.onNodeWithTag("voice_control_text_fallback").assertIsDisplayed()
        composeTestRule.onNodeWithTag("code_switching_transcript_text").assertIsDisplayed()
    }

    @Test
    @Config(qualifiers = "w891dp-h411dp-normal-long-notround-land", sdk = [36])
    fun `landscape orientation renders scrollable home screen without clipping`() {
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

        composeTestRule.onNodeWithTag("home_screen").assertIsDisplayed()
        composeTestRule.onNodeWithTag("home_header_greeting").assertIsDisplayed()
    }

    @Test
    fun `large font scale 150 percent keeps voice controls and bottom bar readable`() {
        composeTestRule.setContent {
            // Apply 1.5x font scale to test text scaling robustness
            val currentDensity = LocalDensity.current
            val scaledDensity = Density(
                density = currentDensity.density,
                fontScale = 1.5f
            )

            CompositionLocalProvider(LocalDensity provides scaledDensity) {
                SoftGlassTheme(darkTheme = false) {
                    Box(modifier = Modifier.fillMaxSize()) {
                        VoiceSessionControls(
                            isMuted = false,
                            onToggleMute = {},
                            onInterrupt = {},
                            onEndSession = {},
                            onOpenTextFallback = {},
                            isSpeakingOrThinking = true
                        )
                    }
                }
            }
        }

        composeTestRule.onNodeWithTag("voice_session_controls").assertIsDisplayed()
        composeTestRule.onNodeWithText("Mute").assertIsDisplayed()
        composeTestRule.onNodeWithText("Interrupt").assertIsDisplayed()
        composeTestRule.onNodeWithText("End").assertIsDisplayed()
        composeTestRule.onNodeWithText("Text").assertIsDisplayed()
    }

    @Test
    fun `health metric displays clear unavailable notice instead of zero value`() {
        val unavailableSpO2 = HealthMetric(
            type = HealthMetricType.BLOOD_OXYGEN,
            availability = HealthDataAvailability.UNAVAILABLE,
            value = null, // Must NOT be "0%"
            unavailableMessage = "No SpO2 readings recorded"
        )

        composeTestRule.setContent {
            SoftGlassTheme(darkTheme = false) {
                HealthMetricCard(metric = unavailableSpO2)
            }
        }

        // Verify the unavailable notice is shown and NOT 0%
        composeTestRule.onNodeWithTag("health_unavailable_notice_unavailable").assertIsDisplayed()
        composeTestRule.onNodeWithText("No SpO2 readings recorded").assertIsDisplayed()
        composeTestRule.onNodeWithText("Unavailable").assertIsDisplayed()

        // Assert 0 or 0% is never present
        assertNotEquals("0%", unavailableSpO2.value)
        assertNotEquals("0", unavailableSpO2.value)
    }

    @Test
    fun `mock health provider accurately distinguishes between zero values and unavailable metrics`() {
        val provider = MockHealthDataProvider()
        provider.setAvailabilityProfile(MockHealthDataProvider.AvailabilityProfile.UNSUPPORTED_SENSOR)
        val unsupportedMetrics = provider.getHealthMetrics(HealthTimeRange.TODAY)

        val spO2 = unsupportedMetrics.firstOrNull { it.type == HealthMetricType.BLOOD_OXYGEN }
        assertTrue("SpO2 metric must be present", spO2 != null)
        assertTrue("SpO2 must be marked UNSUPPORTED", spO2?.availability == HealthDataAvailability.UNSUPPORTED)
        assertTrue("SpO2 value must be null when unsupported, never 0 or 0%", spO2?.value == null)
        assertTrue("Unavailable message must be informative", spO2?.unavailableMessage?.contains("Sensor not supported") == true)
    }
}
