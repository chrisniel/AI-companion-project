package com.example.ui.screens.health

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.data.health.MockHealthDataProvider
import com.example.domain.model.CapabilityType
import com.example.domain.model.HealthConnectCapabilityState
import com.example.domain.model.HealthTimeRange
import com.example.domain.model.HealthUiState
import com.example.domain.model.MockPermissionAction
import com.example.ui.components.CapabilityAlertBanner
import com.example.ui.components.MockActionDetailsSheet
import com.example.ui.components.softBounceOverscroll
import com.example.ui.theme.SoftTheme

/**
 * Mobile Health and Wellness Screen (Batch 7).
 *
 * Requirements addressed:
 * - Replaceable provider architecture (Health Connect contract abstraction)
 * - Source status display:
 *     Health Connect: Mock Connected
 *     Source: FitCloudPro
 * - Time Range selection: Today, Week, Month
 * - Metrics: heart rate, sleep, steps, activity, blood oxygen
 * - Data Availability states: available, unavailable, stale, unsupported, not synchronized
 * - Core mandate: Never display fake zero values for unavailable health data (e.g. "No SpO2 data available")
 * - Wellness Insights with strictly non-diagnostic wording
 */
@Composable
fun HealthScreen(
    modifier: Modifier = Modifier,
    healthConnectState: HealthConnectCapabilityState = HealthConnectCapabilityState.ACCESS_GRANTED,
    onSetHealthConnectState: (HealthConnectCapabilityState) -> Unit = {},
    viewModel: HealthViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showScenarioFilter by remember { mutableStateOf(false) }
    var activeMockAction by remember { mutableStateOf<MockPermissionAction?>(null) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .testTag("health_screen")
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .softBounceOverscroll()
                .testTag("health_content_list"),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 80.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 1. TIME RANGE SELECTOR (Today / Week / Month)
            item(key = "health_time_range_selector") {
                HealthTimeRangeBar(
                    selectedRange = uiState.selectedTimeRange,
                    onSelectRange = { viewModel.selectTimeRange(it) }
                )
            }

            // BATCH 13: Never silently fail on Health Connect capability restrictions
            if (healthConnectState != HealthConnectCapabilityState.ACCESS_GRANTED && healthConnectState != HealthConnectCapabilityState.AVAILABLE) {
                item(key = "health_connect_capability_alert") {
                    CapabilityAlertBanner(
                        title = "Health Connect: ${healthConnectState.displayName}",
                        explanation = healthConnectState.explanation,
                        onActionClick = { action ->
                            activeMockAction = action
                        },
                        testTag = "health_connect_capability_banner"
                    )
                }
            }

            // 2. SOURCE STATUS CARD (Health Connect: Mock Connected / Source: FitCloudPro)
            item(key = "health_source_card") {
                HealthSourceCard(
                    sourceStatus = uiState.sourceStatus,
                    isSyncing = uiState.isSyncing,
                    onSyncClick = { viewModel.triggerSync() }
                )
            }

            // 3. DATA AVAILABILITY SCENARIO SIMULATOR (Demonstrates all 5 availability states)
            item(key = "health_availability_simulator_chip") {
                AvailabilitySimulationBar(
                    isExpanded = showScenarioFilter,
                    onToggleExpand = { showScenarioFilter = !showScenarioFilter },
                    onSelectProfile = { profile ->
                        viewModel.selectAvailabilityProfile(profile)
                    }
                )
            }

            // 4. SECTION: METRICS
            item(key = "health_metrics_section_header") {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp, bottom = 2.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Biometric Telemetry",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "${uiState.metrics.count { it.value != null }} of ${uiState.metrics.size} active",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.accentBlue,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // 5. METRIC CARDS (Heart Rate, Sleep, Steps, Activity, Blood Oxygen SpO2)
            items(
                items = uiState.metrics,
                key = { it.type.name }
            ) { metric ->
                HealthMetricCard(metric = metric)
            }

            // 6. WELLNESS INSIGHTS SECTION (Non-Diagnostic Wording)
            item(key = "wellness_insights_section") {
                WellnessInsightsCard(insights = uiState.wellnessInsights)
            }
        }

        // FEEDBACK NOTIFICATION BANNER
        AnimatedVisibility(
            visible = uiState.feedbackMessage != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 20.dp, start = 20.dp, end = 20.dp)
        ) {
            uiState.feedbackMessage?.let { msg ->
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(SoftTheme.colors.surfaceElevated)
                        .border(
                            width = SoftTheme.tokens.borders.hairline,
                            color = SoftTheme.colors.accentBlue.copy(alpha = 0.4f),
                            shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                        )
                        .padding(horizontal = 16.dp, vertical = 10.dp)
                        .testTag("health_feedback_toast"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = msg,
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                        color = SoftTheme.colors.textPrimary,
                        fontSize = 12.sp
                    )
                }
            }
        }

        // MOCK ACTION DETAILS SHEET
        MockActionDetailsSheet(
            isOpen = activeMockAction != null,
            action = activeMockAction,
            capabilityType = CapabilityType.HEALTH_CONNECT,
            onDismiss = { activeMockAction = null },
            onSimulateGrant = {
                onSetHealthConnectState(HealthConnectCapabilityState.ACCESS_GRANTED)
                activeMockAction = null
            }
        )
    }
}

/**
 * Segmented bar for TIME RANGE: Today, Week, Month.
 */
@Composable
private fun HealthTimeRangeBar(
    selectedRange: HealthTimeRange,
    onSelectRange: (HealthTimeRange) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
            .background(SoftTheme.colors.surfaceElevated)
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
            )
            .padding(4.dp)
            .testTag("health_time_range_bar"),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        HealthTimeRange.entries.forEach { range ->
            val isSelected = range == selectedRange
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                    .background(
                        if (isSelected) SoftTheme.colors.accentBlue
                        else Color.Transparent
                    )
                    .clickable { onSelectRange(range) }
                    .testTag("health_range_${range.name.lowercase()}")
                    .semantics {
                        this.contentDescription = "${range.label} range, ${if (isSelected) "selected" else "not selected"}"
                    },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = range.label,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                    color = if (isSelected) Color.White else SoftTheme.colors.textSecondary,
                    fontSize = 13.sp
                )
            }
        }
    }
}

/**
 * Simulator bar for testing all 5 Data Availability states.
 */
@Composable
private fun AvailabilitySimulationBar(
    isExpanded: Boolean,
    onToggleExpand: () -> Unit,
    onSelectProfile: (MockHealthDataProvider.AvailabilityProfile) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(SoftTheme.colors.surfaceWell.copy(alpha = 0.7f))
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .padding(10.dp)
            .testTag("health_availability_simulator_bar"),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onToggleExpand() },
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Tune,
                    contentDescription = null,
                    tint = SoftTheme.colors.textSecondary,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = "Data Availability Scenarios",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 11.sp
                )
            }

            Text(
                text = if (isExpanded) "Hide Options" else "Test Availability States",
                style = MaterialTheme.typography.labelSmall,
                color = SoftTheme.colors.accentBlue,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium
            )
        }

        AnimatedVisibility(visible = isExpanded) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                MockHealthDataProvider.AvailabilityProfile.entries.forEach { profile ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.surfaceElevated)
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = SoftTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .clickable { onSelectProfile(profile) }
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                            .testTag("profile_${profile.name.lowercase()}"),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = profile.label,
                            style = MaterialTheme.typography.labelSmall,
                            color = SoftTheme.colors.textPrimary,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }
    }
}
