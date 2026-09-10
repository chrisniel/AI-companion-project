package com.example.ui.screens.models

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Route
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.ModelInfo
import com.example.domain.model.ModelLocation
import com.example.domain.model.PcResourceSummary
import com.example.domain.model.PerformanceProfile
import com.example.domain.model.RoutingPolicy
import com.example.ui.components.InteractiveSoftGlassCard
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.SoftSegmentedControl
import com.example.ui.components.StatusBadge
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Mobile Models Screen (Batch 9).
 * Lightweight mobile page presenting:
 * - Current model information with Local / Cloud badge and provider name
 * - Mobile-tailored model selector
 * - Performance profile selection (Eco, Balanced, Maximum)
 * - Routing policy selection (Local Only, Local First, Cloud First, Cloud Only)
 * - Optional expandable mock PC resource summary (CPU, RAM, GPU)
 * - Notice keeping advanced runtime configuration on PC.
 */
@Composable
fun ModelsScreen(
    modifier: Modifier = Modifier,
    onNavigateBack: (() -> Unit)? = null,
    viewModel: ModelsViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .testTag("models_screen")
            .padding(horizontal = SoftTheme.spacing.lg),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
    ) {
        // Optional top navigation header if presented standalone
        if (onNavigateBack != null) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = SoftTheme.spacing.sm),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                ) {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("models_back_button")
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Navigate Back",
                            tint = SoftTheme.colors.textPrimary
                        )
                    }
                    Column {
                        Text(
                            text = "Models",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Mobile runtime & inference routing",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }
            }
        } else {
            item {
                Spacer(modifier = Modifier.height(SoftTheme.spacing.xs))
            }
        }

        // Section: CURRENT ACTIVE MODEL
        item {
            CurrentModelHeroCard(
                model = uiState.currentModel
            )
        }

        // Section: PERFORMANCE PROFILE
        item {
            PerformanceProfileCard(
                currentProfile = uiState.performanceProfile,
                onProfileSelected = { viewModel.setPerformanceProfile(it) }
            )
        }

        // Section: ROUTING POLICY
        item {
            RoutingPolicyCard(
                currentPolicy = uiState.routingPolicy,
                onPolicySelected = { viewModel.setRoutingPolicy(it) }
            )
        }

        // Section: AVAILABLE MODELS (Quick switch)
        item {
            AvailableModelsSection(
                models = uiState.availableModels,
                selectedModelId = uiState.currentModel.id,
                onModelSelected = { viewModel.selectModel(it) }
            )
        }

        // Section: OPTIONAL EXPANDABLE PC RESOURCE SUMMARY
        item {
            PcResourceSummaryCard(
                resources = uiState.pcResourceSummary,
                isExpanded = uiState.isPcResourcesExpanded,
                onToggleExpand = { viewModel.togglePcResources() }
            )
        }

        // Section: DESKTOP ADVANCED CONFIGURATION NOTICE
        item {
            DesktopNoticeCard()
        }

        item {
            Spacer(modifier = Modifier.height(SoftTheme.spacing.xl))
        }
    }
}

/**
 * Hero card showcasing the currently active model on mobile.
 */
@Composable
private fun CurrentModelHeroCard(
    model: ModelInfo,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("current_model_card"),
        elevation = SoftTheme.tokens.elevations.card,
        borderWidth = SoftTheme.tokens.borders.medium
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    Icon(
                        imageVector = if (model.location == ModelLocation.LOCAL) Icons.Default.Memory else Icons.Default.Cloud,
                        contentDescription = null,
                        tint = if (model.location == ModelLocation.LOCAL) SoftTheme.colors.accentCyan else SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        text = "CURRENT MODEL",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textMuted
                    )
                }

                // Local vs Cloud Pill Badge
                Box(
                    modifier = Modifier
                        .testTag("model_location_badge")
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(
                            if (model.location == ModelLocation.LOCAL)
                                SoftTheme.colors.statusSuccess.copy(alpha = 0.15f)
                            else
                                SoftTheme.colors.accentBlue.copy(alpha = 0.15f)
                        )
                        .border(
                            width = 1.dp,
                            color = if (model.location == ModelLocation.LOCAL)
                                SoftTheme.colors.statusSuccess.copy(alpha = 0.5f)
                            else
                                SoftTheme.colors.accentBlue.copy(alpha = 0.5f),
                            shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                        )
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = model.location.label,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = if (model.location == ModelLocation.LOCAL)
                            SoftTheme.colors.statusSuccess
                        else
                            SoftTheme.colors.accentBlue
                    )
                }
            }

            // Model Name
            Text(
                text = model.name,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textPrimary
            )

            // Provider Info
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.testTag("model_provider_text")
            ) {
                Text(
                    text = "Provider:",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textMuted
                )
                Text(
                    text = model.provider,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Medium,
                    color = SoftTheme.colors.accentBlue
                )
            }

            // Specs Row (Context & Parameters)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = SoftTheme.spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                SpecPill(label = "Parameters", value = model.parameterSize)
                SpecPill(label = "Context", value = model.contextWindow)
            }

            Text(
                text = model.description,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textSecondary,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}

@Composable
private fun SpecPill(label: String, value: String) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.sm))
            .background(SoftTheme.colors.surfacePressed)
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Column {
            Text(
                text = label.uppercase(),
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                color = SoftTheme.colors.textMuted
            )
            Text(
                text = value,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = SoftTheme.colors.textPrimary
            )
        }
    }
}

/**
 * Performance Profile selection card: Eco, Balanced, Maximum.
 */
@Composable
private fun PerformanceProfileCard(
    currentProfile: PerformanceProfile,
    onProfileSelected: (PerformanceProfile) -> Unit,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier.fillMaxWidth(),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
            ) {
                Icon(
                    imageVector = Icons.Default.Speed,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentAmber,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = "PERFORMANCE PROFILE",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textMuted
                )
            }

            // Segmented 3-way toggle
            SoftSegmentedControl(
                items = PerformanceProfile.entries,
                selectedItem = currentProfile,
                onItemSelected = onProfileSelected,
                itemLabel = { it.displayName },
                testTag = "performance_profile_segmented"
            )

            // Dynamic descriptive explanation for the chosen profile
            Text(
                text = currentProfile.subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textSecondary
            )
        }
    }
}

/**
 * Routing Policy selection card: Local Only, Local First, Cloud First, Cloud Only.
 */
@Composable
private fun RoutingPolicyCard(
    currentPolicy: RoutingPolicy,
    onPolicySelected: (RoutingPolicy) -> Unit,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier.fillMaxWidth(),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
            ) {
                Icon(
                    imageVector = Icons.Default.Route,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentViolet,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = "ROUTING POLICY",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textMuted
                )
            }

            // 2x2 Grid of policy options
            Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    RoutingOptionPill(
                        policy = RoutingPolicy.LOCAL_ONLY,
                        isSelected = currentPolicy == RoutingPolicy.LOCAL_ONLY,
                        onClick = { onPolicySelected(RoutingPolicy.LOCAL_ONLY) },
                        testTag = "routing_local_only",
                        modifier = Modifier.weight(1f)
                    )
                    RoutingOptionPill(
                        policy = RoutingPolicy.LOCAL_FIRST,
                        isSelected = currentPolicy == RoutingPolicy.LOCAL_FIRST,
                        onClick = { onPolicySelected(RoutingPolicy.LOCAL_FIRST) },
                        testTag = "routing_local_first",
                        modifier = Modifier.weight(1f)
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    RoutingOptionPill(
                        policy = RoutingPolicy.CLOUD_FIRST,
                        isSelected = currentPolicy == RoutingPolicy.CLOUD_FIRST,
                        onClick = { onPolicySelected(RoutingPolicy.CLOUD_FIRST) },
                        testTag = "routing_cloud_first",
                        modifier = Modifier.weight(1f)
                    )
                    RoutingOptionPill(
                        policy = RoutingPolicy.CLOUD_ONLY,
                        isSelected = currentPolicy == RoutingPolicy.CLOUD_ONLY,
                        onClick = { onPolicySelected(RoutingPolicy.CLOUD_ONLY) },
                        testTag = "routing_cloud_only",
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            // Policy description
            Text(
                text = currentPolicy.subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textSecondary
            )
        }
    }
}

@Composable
private fun RoutingOptionPill(
    policy: RoutingPolicy,
    isSelected: Boolean,
    onClick: () -> Unit,
    testTag: String,
    modifier: Modifier = Modifier
) {
    val borderColor = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle
    val bgColor = if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.12f) else SoftTheme.colors.surfacePressed

    Box(
        modifier = modifier
            .testTag(testTag)
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(bgColor)
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            if (isSelected) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = SoftTheme.colors.accentBlue,
                    modifier = Modifier.size(14.dp)
                )
            }
            Text(
                text = policy.displayName,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                color = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.textPrimary
            )
        }
    }
}

/**
 * Mobile model switcher list.
 */
@Composable
private fun AvailableModelsSection(
    models: List<ModelInfo>,
    selectedModelId: String,
    onModelSelected: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
    ) {
        Text(
            text = "AVAILABLE MODELS",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = SoftTheme.colors.textMuted,
            modifier = Modifier.padding(horizontal = SoftTheme.spacing.xs)
        )

        models.forEach { model ->
            val isSelected = model.id == selectedModelId
            InteractiveSoftGlassCard(
                onClick = { onModelSelected(model.id) },
                isSelected = isSelected,
                testTag = "model_item_${model.id}",
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.sm),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(
                                text = model.name,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = SoftTheme.colors.textPrimary
                            )
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(
                                        if (model.location == ModelLocation.LOCAL)
                                            SoftTheme.colors.statusSuccess.copy(alpha = 0.12f)
                                        else
                                            SoftTheme.colors.accentBlue.copy(alpha = 0.12f)
                                    )
                                    .padding(horizontal = 6.dp, vertical = 2.dp)
                            ) {
                                Text(
                                    text = model.location.label,
                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (model.location == ModelLocation.LOCAL)
                                        SoftTheme.colors.statusSuccess
                                    else
                                        SoftTheme.colors.accentBlue
                                )
                            }
                        }
                        Text(
                            text = "${model.provider} • ${model.parameterSize}",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }

                    if (isSelected) {
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = "Selected",
                            tint = SoftTheme.colors.accentBlue,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}

/**
 * Optional expandable PC resource summary (CPU, RAM, GPU mock).
 */
@Composable
private fun PcResourceSummaryCard(
    resources: PcResourceSummary,
    isExpanded: Boolean,
    onToggleExpand: () -> Unit,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .fillMaxWidth()
            .testTag("pc_resources_card")
            .animateContentSize(),
        elevation = SoftTheme.tokens.elevations.subtle
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onToggleExpand)
                    .testTag("pc_resources_toggle"),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    Icon(
                        imageVector = Icons.Default.Computer,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentCyan,
                        modifier = Modifier.size(18.dp)
                    )
                    Column {
                        Text(
                            text = "PC Resource Summary",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = "Optional host overview • Tap to expand",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }

                Icon(
                    imageVector = if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = if (isExpanded) "Collapse summary" else "Expand summary",
                    tint = SoftTheme.colors.textSecondary
                )
            }

            AnimatedVisibility(
                visible = isExpanded,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("pc_resources_content")
                        .padding(top = SoftTheme.spacing.sm),
                    verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
                ) {
                    // CPU Resource
                    ResourceMetricBar(
                        icon = Icons.Default.Memory,
                        label = "CPU",
                        usagePercent = resources.cpuUsagePercent,
                        detail = "${resources.cpuUsagePercent}% • ${resources.cpuInfo}",
                        tint = SoftTheme.colors.accentCyan,
                        testTag = "pc_cpu_metric"
                    )

                    // RAM Resource
                    val ramPercent = ((resources.ramUsedGb / resources.ramTotalGb) * 100).toInt()
                    ResourceMetricBar(
                        icon = Icons.Default.Bolt,
                        label = "RAM",
                        usagePercent = ramPercent,
                        detail = "${resources.ramUsedGb} GB / ${resources.ramTotalGb} GB ($ramPercent%)",
                        tint = SoftTheme.colors.accentBlue,
                        testTag = "pc_ram_metric"
                    )

                    // GPU Resource
                    ResourceMetricBar(
                        icon = Icons.Default.Speed,
                        label = "GPU",
                        usagePercent = resources.gpuUsagePercent,
                        detail = "${resources.gpuModel} • ${resources.gpuUsagePercent}% Load • ${resources.vramUsedGb}/${resources.vramTotalGb} GB VRAM • ${resources.gpuTempCelsius}°C",
                        tint = SoftTheme.colors.accentViolet,
                        testTag = "pc_gpu_metric"
                    )
                }
            }
        }
    }
}

@Composable
private fun ResourceMetricBar(
    icon: ImageVector,
    label: String,
    usagePercent: Int,
    detail: String,
    tint: Color,
    testTag: String
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag(testTag),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )
            }
            Text(
                text = detail,
                style = MonospaceTelemetry.copy(fontSize = 11.sp),
                color = SoftTheme.colors.textSecondary
            )
        }

        LinearProgressIndicator(
            progress = { (usagePercent / 100f).coerceIn(0f, 1f) },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp)),
            color = tint,
            trackColor = SoftTheme.colors.surfacePressed,
            strokeCap = StrokeCap.Round
        )
    }
}

/**
 * Notice card explicitly stating that advanced runtime configurations remain on PC.
 */
@Composable
private fun DesktopNoticeCard(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(SoftTheme.colors.surfaceElevated.copy(alpha = 0.5f))
            .border(
                width = 1.dp,
                color = SoftTheme.colors.borderSubtle,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .padding(SoftTheme.spacing.md)
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            Icon(
                imageVector = Icons.Default.Info,
                contentDescription = null,
                tint = SoftTheme.colors.accentBlue,
                modifier = Modifier.size(18.dp)
            )
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = "Desktop Core Configuration",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = SoftTheme.colors.textPrimary
                )
                Text(
                    text = "Advanced runtime parameters, tensor parallel splits, context window sizing, and GGUF quantization weights are configured directly on your PC Core runtime.",
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textMuted
                )
            }
        }
    }
}
