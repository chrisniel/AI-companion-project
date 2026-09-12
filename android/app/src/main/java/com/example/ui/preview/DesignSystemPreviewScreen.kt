package com.example.ui.preview

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import com.example.ui.components.softBounceOverscroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.ComponentVisualState
import com.example.domain.model.CoreConnectionState
import com.example.domain.model.StatusSeverity
import com.example.ui.components.AmbientGlassBackground
import com.example.ui.components.AuraIdentityCard
import com.example.ui.components.CircularMetric
import com.example.ui.components.ConnectionIndicator
import com.example.ui.components.EmptyState
import com.example.ui.components.ErrorState
import com.example.ui.components.GlassSurface
import com.example.ui.components.IconButton
import com.example.ui.components.InteractiveSoftGlassCard
import com.example.ui.components.LoadingState
import com.example.ui.components.MetricCard
import com.example.ui.components.NavigationGlassSurface
import com.example.ui.components.NeumorphicButton
import com.example.ui.components.PrimaryButton
import com.example.ui.components.SearchField
import com.example.ui.components.SecondaryButton
import com.example.ui.components.SectionHeader
import com.example.ui.components.SegmentedControl
import com.example.ui.components.SoftAvatar
import com.example.ui.components.SoftGlassBottomSheet
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.SoftGlassDialog
import com.example.ui.components.SoftIconButton
import com.example.ui.components.SoftSlider
import com.example.ui.components.SoftTextField
import com.example.ui.components.StatusBadge
import com.example.ui.components.Toggle
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Design-system preview screen showcasing all foundational components,
 * tactile depth tokens, component states, and responsive mobile architecture.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DesignSystemPreviewScreen(
    modifier: Modifier = Modifier,
    viewModel: DesignSystemViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val scrollState = rememberLazyListState()

    var interactiveCardSelected by remember { mutableStateOf(false) }
    var showPaletteTweaker by remember { mutableStateOf(false) }

    AmbientGlassBackground(modifier = modifier) {
        Scaffold(
            containerColor = Color.Transparent,
            contentWindowInsets = WindowInsets.safeDrawing,
            modifier = Modifier.fillMaxSize()
        ) { innerPadding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.TopCenter
            ) {
                LazyColumn(
                    state = scrollState,
                    contentPadding = PaddingValues(
                        start = SoftTheme.spacing.lg,
                        end = SoftTheme.spacing.lg,
                        top = SoftTheme.spacing.md,
                        bottom = SoftTheme.spacing.huge
                    ),
                    verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xl),
                    modifier = Modifier
                        .fillMaxWidth()
                        .widthIn(max = 640.dp)
                        .softBounceOverscroll()
                        .testTag("design_system_preview_scroll")
                ) {
                    // Header Bar: Brand, Theme Switcher & Connection Indicator
                    item {
                        PreviewTopBar(
                            isDark = uiState.isDarkTheme,
                            onToggleTheme = { viewModel.toggleDarkTheme() },
                            onTuneClick = { showPaletteTweaker = true },
                            connection = uiState.config.connection
                        )
                    }

                    // Mobile Avatar & Local AI Identity Presentation
                    item {
                        AuraIdentityCard(
                            personaName = uiState.selectedPersona,
                            statusText = "Active & Nominal • 22ms loopback",
                            modelName = "Llama-3.1-8B-Instruct (Q4_K_M)",
                            selectedPersona = uiState.selectedPersona,
                            onSelectPersona = { viewModel.selectPersona(it) }
                        )
                    }

                    // Component States Selector
                    item {
                        StateSelectionStrip(
                            selectedState = uiState.selectedVisualState,
                            onSelectState = { viewModel.selectVisualState(it) }
                        )
                    }

                    // Section 1: Surfaces & Depth
                    item {
                        SurfacesSection(
                            interactiveCardSelected = interactiveCardSelected,
                            onInteractiveCardClick = { interactiveCardSelected = !interactiveCardSelected }
                        )
                    }

                    // Section 2: Tactile Buttons
                    item {
                        ButtonsSection(
                            isPrimaryLoading = uiState.isPrimaryLoading,
                            isPrimarySuccess = uiState.isPrimarySuccess,
                            onPrimaryClick = { viewModel.triggerPrimaryAction() },
                            isNeumorphicPressedSimulated = uiState.isNeumorphicPressedSimulated,
                            onNeumorphicClick = { viewModel.toggleNeumorphicSimulatedPress() },
                            visualState = uiState.selectedVisualState
                        )
                    }

                    // Section 3: Tactile Controls
                    item {
                        ControlsSection(
                            toggleChecked = uiState.toggleChecked,
                            onToggleChange = { viewModel.setToggleChecked(it) },
                            sliderValue = uiState.sliderValue,
                            onSliderChange = { viewModel.setSliderValue(it) },
                            supportedLanguages = uiState.supportedLanguages,
                            selectedLanguage = uiState.selectedLanguage,
                            onLanguageChange = { viewModel.selectLanguage(it) },
                            visualState = uiState.selectedVisualState
                        )
                    }

                    // Section 4: Indicators & Telemetry
                    item {
                        IndicatorsSection(
                            connectionState = uiState.config.connection.state
                        )
                    }

                    // Section 5: Metrics & Gauges
                    item {
                        MetricsSection(
                            metrics = uiState.metrics,
                            circularPercentage = uiState.circularMetricPercentage,
                            onCircularPercentageChange = { viewModel.setCircularMetricPercentage(it) }
                        )
                    }

                    // Section 6: Form Inputs
                    item {
                        InputsSection(
                            searchQuery = uiState.searchQuery,
                            onSearchQueryChange = { viewModel.setSearchQuery(it) },
                            textFieldInput = uiState.textFieldInput,
                            onTextFieldInputChange = { viewModel.setTextFieldInput(it) },
                            errorMessage = uiState.textFieldError,
                            visualState = uiState.selectedVisualState
                        )
                    }

                    // Section 7: Overlays & Modals Foundation
                    item {
                        OverlaysSection(
                            onOpenBottomSheet = { viewModel.setShowBottomSheet(true) },
                            onOpenDialog = { viewModel.setShowDialog(true) }
                        )
                    }

                    // Section 8: Feedback & States
                    item {
                        FeedbackSection(
                            feedbackMode = uiState.feedbackMode,
                            onModeSelect = { viewModel.setFeedbackMode(it) }
                        )
                    }
                }
            }

            // BottomSheet Foundation
            if (uiState.showBottomSheet) {
                SoftGlassBottomSheet(
                    onDismissRequest = { viewModel.setShowBottomSheet(false) },
                    title = "Control Center BottomSheet"
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
                    ) {
                        Text(
                            text = "Translucent structural container with milky/graphite elevation, tactile drag handle, and high contrast typography.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = SoftTheme.colors.textSecondary
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End
                        ) {
                            PrimaryButton(
                                text = "Close Sheet",
                                onClick = { viewModel.setShowBottomSheet(false) }
                            )
                        }
                    }
                }
            }

            // Dialog Foundation
            if (uiState.showDialog) {
                SoftGlassDialog(
                    onDismissRequest = { viewModel.setShowDialog(false) },
                    title = "System Dialog Foundation",
                    description = "Demonstrates soft neumorphic elevation, specular highlight borders, and accessible action targets.",
                    confirmButtonText = "Confirm",
                    onConfirm = { viewModel.setShowDialog(false) },
                    dismissButtonText = "Dismiss",
                    onDismiss = { viewModel.setShowDialog(false) }
                )
            }

            // Live Palette & Shadow Inspector BottomSheet
            if (showPaletteTweaker) {
                PaletteTweakerBottomSheet(
                    onDismissRequest = { showPaletteTweaker = false }
                )
            }
        }
    }
}

@Composable
private fun PreviewTopBar(
    isDark: Boolean,
    onToggleTheme: () -> Unit,
    onTuneClick: () -> Unit,
    connection: com.example.domain.model.ConnectionInfo
) {
    NavigationGlassSurface(
        modifier = Modifier.fillMaxWidth(),
        elevation = SoftTheme.tokens.elevations.card
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.md),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                SoftAvatar(
                    name = "Chris",
                    size = 42.dp,
                    statusColor = SoftTheme.colors.statusSuccess,
                    testTag = "topbar_user_avatar"
                )

                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "Local AI Core",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))
                        Text(
                            text = "v1.1",
                            style = MonospaceTelemetry,
                            color = SoftTheme.colors.accentBlue
                        )
                    }
                    Text(
                        text = "Calibrated Soft Glass System",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textMuted
                    )
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
            ) {
                ConnectionIndicator(
                    state = connection.state,
                    label = connection.label,
                    latencyMs = connection.latencyMs
                )

                SoftIconButton(
                    icon = Icons.Default.Tune,
                    contentDescription = "Tune Palette & Shadows",
                    onClick = onTuneClick,
                    testTag = "palette_tweaker_button"
                )

                SoftIconButton(
                    icon = if (isDark) Icons.Default.LightMode else Icons.Default.DarkMode,
                    contentDescription = if (isDark) "Switch to Light Mode" else "Switch to Dark Mode",
                    onClick = onToggleTheme,
                    testTag = "theme_toggle_button"
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PaletteTweakerBottomSheet(
    onDismissRequest: () -> Unit
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    var selectedFoundation by remember { mutableStateOf("#EDF0EB") }
    var shadowAlpha by remember { mutableStateOf(0.24f) }
    var specularAlpha by remember { mutableStateOf(0.70f) }
    var selectedTextMode by remember { mutableStateOf("#0F172A") }

    val foundations = listOf(
        "#EDF0EB" to "Matte Clay",
        "#E6E9E5" to "Warm Pearl",
        "#EAF0F8" to "Crisp Frost",
        "#D6DAD3" to "Sunken Well"
    )

    SoftGlassBottomSheet(
        onDismissRequest = onDismissRequest,
        title = "Live Palette & Shadow Inspector"
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = SoftTheme.spacing.sm),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            Text(
                text = "SURFACE FOUNDATION PRESET",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.accentPrimaryColor
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                foundations.forEach { (hex, label) ->
                    val isSelected = selectedFoundation.equals(hex, ignoreCase = true)
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(
                                if (isSelected) SoftTheme.colors.accentPrimaryColor.copy(alpha = 0.15f)
                                else SoftTheme.colors.surfaceWell
                            )
                            .border(
                                width = if (isSelected) 1.5.dp else SoftTheme.tokens.borders.hairline,
                                color = if (isSelected) SoftTheme.colors.accentPrimaryColor else SoftTheme.colors.borderSubtle,
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .clickable { selectedFoundation = hex }
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Text(
                            text = "$label ($hex)",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                            color = if (isSelected) SoftTheme.colors.accentPrimaryColor else SoftTheme.colors.textPrimary
                        )
                    }
                }
            }

            // Shadow Alpha Slider
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "SLATE SHADOW ALPHA",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.accentPrimaryColor
                )
                Text(
                    text = "${(shadowAlpha * 100).toInt()}%",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }
            SoftSlider(
                value = shadowAlpha,
                onValueChange = { shadowAlpha = it },
                valueRange = 0.10f..0.50f
            )

            // Specular Alpha Slider
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "SPECULAR HIGHLIGHT ALPHA",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.accentPrimaryColor
                )
                Text(
                    text = "${(specularAlpha * 100).toInt()}%",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }
            SoftSlider(
                value = specularAlpha,
                onValueChange = { specularAlpha = it },
                valueRange = 0.30f..1.0f
            )

            // Live Preview Card Swatch
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
                    .background(Color(android.graphics.Color.parseColor(selectedFoundation)))
                    .border(
                        width = 1.dp,
                        color = Color.White.copy(alpha = specularAlpha),
                        shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
                    )
                    .padding(16.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "Live Surface Preview: $selectedFoundation",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(android.graphics.Color.parseColor(selectedTextMode))
                    )
                    Text(
                        text = "Dual-light tactile neumorphic depth • Shadow alpha ${(shadowAlpha * 100).toInt()}%",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(android.graphics.Color.parseColor(selectedTextMode)).copy(alpha = 0.75f)
                    )
                }
            }

            // Export Code & Actions
            val exportSnippet = buildString {
                appendLine("// Exported Calibrated Tokens")
                appendLine("val MilkySurfaceElevated = Color(0xFF${selectedFoundation.removePrefix("#")})")
                appendLine("val ShadowLight = Color(0x${((shadowAlpha * 255).toInt()).toString(16).uppercase().padStart(2, '0')}737A75)")
                appendLine("val ShadowLightSpecular = Color(0x${((specularAlpha * 255).toInt()).toString(16).uppercase().padStart(2, '0')}FFFFFF)")
                appendLine("val TextPrimaryLight = Color(0xFF${selectedTextMode.removePrefix("#")})")
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                SecondaryButton(
                    text = "Reset Defaults",
                    onClick = {
                        selectedFoundation = "#EDF0EB"
                        shadowAlpha = 0.24f
                        specularAlpha = 0.70f
                        selectedTextMode = "#0F172A"
                        Toast.makeText(context, "Reset to defaults", Toast.LENGTH_SHORT).show()
                    },
                    modifier = Modifier.weight(1f)
                )

                PrimaryButton(
                    text = "Copy Tokens",
                    onClick = {
                        clipboardManager.setText(AnnotatedString(exportSnippet))
                        Toast.makeText(context, "Copied tokens to clipboard!", Toast.LENGTH_SHORT).show()
                    },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun StateSelectionStrip(
    selectedState: ComponentVisualState,
    onSelectState: (ComponentVisualState) -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "Component States",
            badgeText = "8 states supported",
            subtitle = "Test components under all required visual conditions"
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
        ) {
            ComponentVisualState.entries.forEach { state ->
                val isSelected = state == selectedState
                val (badgeSeverity, label) = when (state) {
                    ComponentVisualState.Normal -> StatusSeverity.Normal to "Normal"
                    ComponentVisualState.Pressed -> StatusSeverity.Info to "Pressed"
                    ComponentVisualState.Selected -> StatusSeverity.Info to "Selected"
                    ComponentVisualState.Disabled -> StatusSeverity.Normal to "Disabled"
                    ComponentVisualState.Loading -> StatusSeverity.Warning to "Loading"
                    ComponentVisualState.Success -> StatusSeverity.Success to "Success"
                    ComponentVisualState.Warning -> StatusSeverity.Warning to "Warning"
                    ComponentVisualState.Error -> StatusSeverity.Error to "Error"
                }

                InteractiveSoftGlassCard(
                    onClick = { onSelectState(state) },
                    isSelected = isSelected,
                    elevation = if (isSelected) SoftTheme.tokens.elevations.subtle else SoftTheme.tokens.elevations.none,
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill),
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.padding(vertical = SoftTheme.spacing.xs)
                ) {
                    StatusBadge(
                        text = label,
                        severity = if (isSelected) StatusSeverity.Info else badgeSeverity,
                        hasDot = true,
                        modifier = Modifier.padding(horizontal = 6.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun SurfacesSection(
    interactiveCardSelected: Boolean,
    onInteractiveCardClick: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "Surfaces & Depth",
            subtitle = "Milky/graphite elevated surfaces with specular hairline borders"
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            // SoftGlassCard
            SoftGlassCard(
                modifier = Modifier.weight(1f),
                elevation = SoftTheme.tokens.elevations.card
            ) {
                Column(modifier = Modifier.padding(SoftTheme.spacing.md)) {
                    Text(
                        text = "SoftGlassCard",
                        style = MaterialTheme.typography.titleSmall,
                        color = SoftTheme.colors.textPrimary
                    )
                    Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))
                    Text(
                        text = "Translucent structural surface with soft diffused shadow.",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                }
            }

            // InteractiveSoftGlassCard
            InteractiveSoftGlassCard(
                onClick = onInteractiveCardClick,
                isSelected = interactiveCardSelected,
                contentAlignment = Alignment.TopStart,
                modifier = Modifier.weight(1f)
            ) {
                Column(modifier = Modifier.padding(SoftTheme.spacing.md)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "InteractiveCard",
                            style = MaterialTheme.typography.titleSmall,
                            color = SoftTheme.colors.textPrimary
                        )
                        if (interactiveCardSelected) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = "Selected",
                                tint = SoftTheme.colors.accentBlue,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))
                    Text(
                        text = if (interactiveCardSelected) "Selected State Active" else "Tap for tactile ripple & depth shift.",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (interactiveCardSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textSecondary
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(SoftTheme.spacing.sm))

        // GlassSurface
        GlassSurface(
            modifier = Modifier.fillMaxWidth(),
            elevation = SoftTheme.tokens.elevations.flat
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.md),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Layers,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentCyan,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(SoftTheme.spacing.md))
                Column {
                    Text(
                        text = "GlassSurface Foundation",
                        style = MaterialTheme.typography.labelMedium,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "Flat structural layer for cards, banners, and panel groupings",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textMuted
                    )
                }
            }
        }
    }
}

@Composable
private fun ButtonsSection(
    isPrimaryLoading: Boolean,
    isPrimarySuccess: Boolean,
    onPrimaryClick: () -> Unit,
    isNeumorphicPressedSimulated: Boolean,
    onNeumorphicClick: () -> Unit,
    visualState: ComponentVisualState
) {
    val isDisabled = visualState == ComponentVisualState.Disabled

    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "Tactile Buttons",
            subtitle = "Primary gradient, frosted secondary, and neumorphic dual-highlight depth"
        )

        // Row of Primary & Secondary Buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            PrimaryButton(
                text = "Primary Action",
                onClick = onPrimaryClick,
                isLoading = isPrimaryLoading || visualState == ComponentVisualState.Loading,
                isSuccess = isPrimarySuccess || visualState == ComponentVisualState.Success,
                enabled = !isDisabled,
                leadingIcon = Icons.Default.PlayArrow,
                modifier = Modifier.weight(1f)
            )

            SecondaryButton(
                text = "Secondary",
                onClick = { /* Test click */ },
                enabled = !isDisabled,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(modifier = Modifier.height(SoftTheme.spacing.md))

        // Row of Neumorphic Button & IconButtons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            NeumorphicButton(
                text = if (isNeumorphicPressedSimulated) "Recessed State" else "Neumorphic Depth",
                onClick = onNeumorphicClick,
                isPressedSimulated = isNeumorphicPressedSimulated || visualState == ComponentVisualState.Pressed,
                enabled = !isDisabled,
                icon = Icons.Default.Tune,
                modifier = Modifier.weight(1f)
            )

            Row(horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)) {
                IconButton(
                    icon = Icons.Default.Notifications,
                    contentDescription = "Notifications",
                    onClick = { /* Test */ },
                    hasBadge = true,
                    enabled = !isDisabled
                )
                IconButton(
                    icon = Icons.Default.Bolt,
                    contentDescription = "Quick Inference",
                    onClick = { /* Test */ },
                    isSelected = visualState == ComponentVisualState.Selected,
                    enabled = !isDisabled
                )
            }
        }
    }
}

@Composable
private fun ControlsSection(
    toggleChecked: Boolean,
    onToggleChange: (Boolean) -> Unit,
    sliderValue: Float,
    onSliderChange: (Float) -> Unit,
    supportedLanguages: List<com.example.domain.model.LanguageOption>,
    selectedLanguage: com.example.domain.model.LanguageOption,
    onLanguageChange: (com.example.domain.model.LanguageOption) -> Unit,
    visualState: ComponentVisualState
) {
    val isDisabled = visualState == ComponentVisualState.Disabled

    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "Tactile Controls",
            subtitle = "Toggle switches, precision sliders, and segmented pills"
        )

        SoftGlassCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.lg),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.lg)
            ) {
                // Toggle Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Ambient Audio VAD Gate",
                            style = MaterialTheme.typography.titleSmall,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = if (toggleChecked) "Listening for voice activity" else "Aura microphone muted",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                    Toggle(
                        checked = toggleChecked,
                        onCheckedChange = onToggleChange,
                        enabled = !isDisabled
                    )
                }

                // Slider Row
                SoftSlider(
                    value = sliderValue,
                    onValueChange = onSliderChange,
                    enabled = !isDisabled,
                    title = "Input Sensitivity",
                    valueLabel = "${(sliderValue * 100).toInt()}%"
                )

                // SegmentedControl for Languages (Batch 0 multilingual feature model)
                Column(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Language Engine",
                            style = MaterialTheme.typography.labelMedium,
                            color = SoftTheme.colors.textSecondary
                        )
                        Text(
                            text = selectedLanguage.samplePhrase,
                            style = MonospaceTelemetry,
                            color = SoftTheme.colors.accentBlue
                        )
                    }
                    Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))
                    SegmentedControl(
                        items = supportedLanguages,
                        selectedItem = selectedLanguage,
                        onItemSelected = onLanguageChange,
                        itemLabel = { it.label },
                        enabled = !isDisabled
                    )
                }
            }
        }
    }
}

@Composable
private fun IndicatorsSection(
    connectionState: CoreConnectionState
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "Status & Indicators",
            subtitle = "Accessible badges with clear text labels and glowing aura indicators"
        )

        SoftGlassCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.lg),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                Text(
                    text = "StatusBadges",
                    style = MaterialTheme.typography.labelMedium,
                    color = SoftTheme.colors.textSecondary
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    StatusBadge(text = "Nominal", severity = StatusSeverity.Normal)
                    StatusBadge(text = "Ready", severity = StatusSeverity.Success)
                    StatusBadge(text = "Syncing", severity = StatusSeverity.Info)
                    StatusBadge(text = "Degraded", severity = StatusSeverity.Warning)
                    StatusBadge(text = "Failed", severity = StatusSeverity.Error)
                }

                Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))

                Text(
                    text = "Connection Indicators (Core RPC)",
                    style = MaterialTheme.typography.labelMedium,
                    color = SoftTheme.colors.textSecondary
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                ) {
                    ConnectionIndicator(
                        state = CoreConnectionState.Online,
                        label = "Online",
                        latencyMs = 22
                    )
                    ConnectionIndicator(
                        state = CoreConnectionState.Connecting,
                        label = "Handshake"
                    )
                    ConnectionIndicator(
                        state = CoreConnectionState.Offline,
                        label = "Offline"
                    )
                }
            }
        }
    }
}

@Composable
private fun MetricsSection(
    metrics: List<com.example.domain.model.MetricItem>,
    circularPercentage: Float,
    onCircularPercentageChange: (Float) -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "Metrics & Visualizers",
            subtitle = "Tactile telemetry cards with animated progress and circular gauge"
        )

        // 2x2 MetricCard Grid
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            metrics.getOrNull(0)?.let { item ->
                MetricCard(
                    title = item.title,
                    value = item.value,
                    unit = item.unit,
                    subtitle = item.subtitle,
                    progress = item.progress,
                    trendPercentage = item.trendPercentage,
                    isPositiveTrend = item.isPositiveTrend,
                    modifier = Modifier.weight(1f)
                )
            }
            metrics.getOrNull(1)?.let { item ->
                MetricCard(
                    title = item.title,
                    value = item.value,
                    unit = item.unit,
                    subtitle = item.subtitle,
                    progress = item.progress,
                    trendPercentage = item.trendPercentage,
                    isPositiveTrend = item.isPositiveTrend,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Spacer(modifier = Modifier.height(SoftTheme.spacing.md))

        // Circular Metric Showcase
        SoftGlassCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.lg),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "VRAM Allocation",
                        style = MaterialTheme.typography.titleMedium,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "6.4 GB / 8.0 GB (Pinned Q4_K_M)",
                        style = MaterialTheme.typography.bodySmall,
                        color = SoftTheme.colors.textSecondary
                    )
                    Spacer(modifier = Modifier.height(SoftTheme.spacing.md))
                    Row(horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
                        SecondaryButton(
                            text = "50%",
                            onClick = { onCircularPercentageChange(0.50f) }
                        )
                        SecondaryButton(
                            text = "75%",
                            onClick = { onCircularPercentageChange(0.75f) }
                        )
                        SecondaryButton(
                            text = "90%",
                            onClick = { onCircularPercentageChange(0.90f) }
                        )
                    }
                }

                CircularMetric(
                    percentage = circularPercentage,
                    label = "ALLOCATED",
                    size = 140.dp,
                    strokeWidth = 10.dp
                )
            }
        }
    }
}

@Composable
private fun InputsSection(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    textFieldInput: String,
    onTextFieldInputChange: (String) -> Unit,
    errorMessage: String?,
    visualState: ComponentVisualState
) {
    val isDisabled = visualState == ComponentVisualState.Disabled

    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "Form Inputs",
            subtitle = "SearchField and TextField supporting normal, error, and disabled states"
        )

        SearchField(
            query = searchQuery,
            onQueryChange = onSearchQueryChange,
            placeholder = "Search commands, models, tasks..."
        )

        Spacer(modifier = Modifier.height(SoftTheme.spacing.md))

        SoftTextField(
            value = textFieldInput,
            onValueChange = onTextFieldInputChange,
            label = "Active Model Checkpoint",
            placeholder = "e.g. Llama-3.1-8B-Instruct",
            helperText = if (errorMessage == null) "Stored in local GGUF cache directory" else null,
            errorMessage = errorMessage,
            enabled = !isDisabled
        )
    }
}

@Composable
private fun OverlaysSection(
    onOpenBottomSheet: () -> Unit,
    onOpenDialog: () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "Overlays Foundation",
            subtitle = "Modal bottom sheets and dialogs with frosted translucent depth"
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            SecondaryButton(
                text = "Preview BottomSheet",
                onClick = onOpenBottomSheet,
                modifier = Modifier.weight(1f)
            )

            SecondaryButton(
                text = "Preview Dialog",
                onClick = onOpenDialog,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun FeedbackSection(
    feedbackMode: FeedbackMode,
    onModeSelect: (FeedbackMode) -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionHeader(
            title = "System Feedback & States",
            subtitle = "Ambient loading pulse, empty state guidance, and error recovery"
        )

        // Mode Switcher
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
        ) {
            FeedbackMode.entries.forEach { mode ->
                val isSelected = mode == feedbackMode
                SecondaryButton(
                    text = mode.name,
                    onClick = { onModeSelect(mode) },
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Spacer(modifier = Modifier.height(SoftTheme.spacing.md))

        when (feedbackMode) {
            FeedbackMode.Loading -> {
                LoadingState(message = "Streaming weights from Local AI Core...")
            }
            FeedbackMode.Empty -> {
                EmptyState(
                    title = "No Tasks Scheduled",
                    description = "Aura's autonomous scheduler is standing by. All pending local pipeline routines completed.",
                    actionButtonText = "Schedule Focus Block",
                    onActionClick = { /* Action */ }
                )
            }
            FeedbackMode.Error -> {
                ErrorState(
                    title = "Loopback Port 8000 Unreachable",
                    message = "Could not establish HTTP/WebSocket connection to Local AI Core service on 127.0.0.1:8000.",
                    retryButtonText = "Retry RPC Connection",
                    onRetry = { onModeSelect(FeedbackMode.Loading) }
                )
            }
        }
    }
}
