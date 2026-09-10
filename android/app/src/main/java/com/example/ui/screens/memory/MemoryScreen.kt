package com.example.ui.screens.memory

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
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
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Unarchive
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.domain.model.MemoryCategory
import com.example.domain.model.MemoryItem
import com.example.domain.model.StatusSeverity
import com.example.ui.components.InteractiveSoftGlassCard
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.StatusBadge
import com.example.ui.theme.SoftTheme

/**
 * Mobile Memory Screen (Batch 10).
 * Prioritizes:
 * - Search
 * - View (Readable card and detail sheet)
 * - Edit (In-place or modal editor)
 * - Archive (Active vs Archived toggle)
 * - Delete
 *
 * Categories:
 * - Profile
 * - Preference
 * - Fact
 * - Project
 * - Event
 * - Temporary
 *
 * Excludes complex vector telemetry by default to keep records immediately readable.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoryScreen(
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: MemoryViewModel = viewModel(factory = com.example.ui.AppViewModelProvider.Factory)
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.statusMessage) {
        uiState.statusMessage?.let { msg ->
            snackbarHostState.showSnackbar(msg)
            viewModel.clearStatus()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { viewModel.openNewMemoryEditor() },
                containerColor = SoftTheme.colors.accentBlue,
                contentColor = Color.White,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
                modifier = Modifier.testTag("memory_fab_add")
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Add Memory"
                )
            }
        },
        containerColor = Color.Transparent,
        modifier = modifier.fillMaxSize()
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Screen Top Header with back button & archive mode toggle
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.sm),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                ) {
                    IconButton(
                        onClick = onNavigateBack,
                        modifier = Modifier.testTag("memory_back_button")
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = SoftTheme.colors.textPrimary
                        )
                    }

                    Column {
                        Text(
                            text = "Memory",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.textPrimary
                        )
                        Text(
                            text = if (uiState.showArchivedOnly) "Archived Records" else "Persistent Facts & Context",
                            style = MaterialTheme.typography.bodySmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }

                // Archive mode toggle button
                InteractiveSoftGlassCard(
                    onClick = { viewModel.toggleShowArchived() },
                    elevation = SoftTheme.tokens.elevations.subtle,
                    testTag = "memory_archive_toggle"
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = SoftTheme.spacing.md, vertical = SoftTheme.spacing.xs),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                    ) {
                        Icon(
                            imageVector = if (uiState.showArchivedOnly) Icons.Default.Unarchive else Icons.Default.Archive,
                            contentDescription = null,
                            tint = if (uiState.showArchivedOnly) SoftTheme.colors.accentAmber else SoftTheme.colors.textSecondary,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = if (uiState.showArchivedOnly) "Archived" else "Active",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = if (uiState.showArchivedOnly) SoftTheme.colors.accentAmber else SoftTheme.colors.textPrimary
                        )
                    }
                }
            }

            // Search Bar
            SoftGlassCard(
                elevation = SoftTheme.tokens.elevations.subtle,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = SoftTheme.spacing.lg, vertical = SoftTheme.spacing.xs)
            ) {
                OutlinedTextField(
                    value = uiState.searchQuery,
                    onValueChange = { viewModel.updateSearchQuery(it) },
                    placeholder = {
                        Text(
                            text = "Search memory, tags, or facts...",
                            style = MaterialTheme.typography.bodyMedium,
                            color = SoftTheme.colors.textMuted
                        )
                    },
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = "Search",
                            tint = SoftTheme.colors.accentBlue
                        )
                    },
                    trailingIcon = {
                        if (uiState.searchQuery.isNotEmpty()) {
                            IconButton(onClick = { viewModel.updateSearchQuery("") }) {
                                Icon(
                                    imageVector = Icons.Default.Clear,
                                    contentDescription = "Clear search",
                                    tint = SoftTheme.colors.textMuted
                                )
                            }
                        }
                    },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color.Transparent,
                        unfocusedBorderColor = Color.Transparent,
                        focusedTextColor = SoftTheme.colors.textPrimary,
                        unfocusedTextColor = SoftTheme.colors.textPrimary
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("memory_search_input")
                )
            }

            // Categories Filter Carousel
            CategoryFilterCarousel(
                selectedCategory = uiState.selectedCategory,
                onCategorySelected = { viewModel.selectCategory(it) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = SoftTheme.spacing.xs)
            )

            // Memories List or Empty State
            if (uiState.memories.isEmpty()) {
                EmptyMemoryState(
                    isSearching = uiState.searchQuery.isNotEmpty() || uiState.selectedCategory != null,
                    isArchived = uiState.showArchivedOnly,
                    onClearFilters = {
                        viewModel.updateSearchQuery("")
                        viewModel.selectCategory(null)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .testTag("memory_list"),
                    contentPadding = PaddingValues(
                        start = SoftTheme.spacing.lg,
                        end = SoftTheme.spacing.lg,
                        top = SoftTheme.spacing.xs,
                        bottom = 80.dp // Leave space for FAB
                    ),
                    verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
                ) {
                    items(
                        items = uiState.memories,
                        key = { it.id }
                    ) { memory ->
                        MemoryItemCard(
                            memory = memory,
                            onClick = { viewModel.viewMemory(memory) },
                            onEdit = { viewModel.openEditMemory(memory) },
                            onToggleArchive = { viewModel.toggleArchive(memory.id) },
                            onDelete = { viewModel.deleteMemory(memory.id) }
                        )
                    }
                }
            }
        }
    }

    // Detail View Modal Sheet
    uiState.viewingMemory?.let { memory ->
        MemoryDetailSheet(
            memory = memory,
            onDismiss = { viewModel.viewMemory(null) },
            onEdit = {
                viewModel.viewMemory(null)
                viewModel.openEditMemory(memory)
            },
            onToggleArchive = {
                viewModel.toggleArchive(memory.id)
            },
            onDelete = {
                viewModel.deleteMemory(memory.id)
            }
        )
    }

    // Create / Edit Dialog
    if (uiState.isEditorOpen && uiState.editingMemory != null) {
        MemoryEditorDialog(
            memory = uiState.editingMemory!!,
            isCreatingNew = uiState.isCreatingNew,
            onDismiss = { viewModel.closeEditor() },
            onSave = { title, content, category, tags ->
                viewModel.saveMemory(title, content, category, tags)
            }
        )
    }
}

/**
 * Category Filter Carousel supporting:
 * - All
 * - Profile
 * - Preference
 * - Fact
 * - Project
 * - Event
 * - Temporary
 */
@Composable
private fun CategoryFilterCarousel(
    selectedCategory: MemoryCategory?,
    onCategorySelected: (MemoryCategory?) -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    Row(
        modifier = modifier
            .horizontalScroll(scrollState)
            .padding(horizontal = SoftTheme.spacing.lg),
        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // "All" chip
        FilterChip(
            selected = selectedCategory == null,
            onClick = { onCategorySelected(null) },
            label = { Text("All") },
            colors = FilterChipDefaults.filterChipColors(
                selectedContainerColor = SoftTheme.colors.accentBlue.copy(alpha = 0.2f),
                selectedLabelColor = SoftTheme.colors.accentBlue,
                containerColor = SoftTheme.colors.surfaceCard.copy(alpha = 0.5f),
                labelColor = SoftTheme.colors.textSecondary
            ),
            modifier = Modifier.testTag("memory_category_chip_ALL")
        )

        MemoryCategory.entries.forEach { category ->
            val isSelected = selectedCategory == category
            val icon = getCategoryIcon(category)
            val accent = getCategoryColor(category)

            FilterChip(
                selected = isSelected,
                onClick = { onCategorySelected(if (isSelected) null else category) },
                leadingIcon = {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = if (isSelected) accent else SoftTheme.colors.textMuted
                    )
                },
                label = { Text(category.displayName) },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = accent.copy(alpha = 0.2f),
                    selectedLabelColor = accent,
                    containerColor = SoftTheme.colors.surfaceCard.copy(alpha = 0.5f),
                    labelColor = SoftTheme.colors.textSecondary
                ),
                modifier = Modifier.testTag("memory_category_chip_${category.name}")
            )
        }
    }
}

/**
 * Clean readable Memory Item Card with category badge, title, excerpt, tags, and action buttons.
 */
@Composable
private fun MemoryItemCard(
    memory: MemoryItem,
    onClick: () -> Unit,
    onEdit: () -> Unit,
    onToggleArchive: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val categoryColor = getCategoryColor(memory.category)
    val categoryIcon = getCategoryIcon(memory.category)

    InteractiveSoftGlassCard(
        onClick = onClick,
        elevation = SoftTheme.tokens.elevations.card,
        testTag = "memory_card_${memory.id}",
        modifier = modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SoftTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
        ) {
            // Header Row: Category Badge + Timestamp + Action icons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .clip(CircleShape)
                            .background(categoryColor.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = categoryIcon,
                            contentDescription = null,
                            tint = categoryColor,
                            modifier = Modifier.size(14.dp)
                        )
                    }

                    Text(
                        text = memory.category.displayName.uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = categoryColor
                    )

                    if (memory.isArchived) {
                        StatusBadge(
                            text = "Archived",
                            severity = StatusSeverity.Warning,
                            hasDot = false
                        )
                    }
                }

                Text(
                    text = memory.createdAt,
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textMuted
                )
            }

            // Title
            Text(
                text = memory.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = SoftTheme.colors.textPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            // Readable Body Content
            Text(
                text = memory.content,
                style = MaterialTheme.typography.bodyMedium,
                color = SoftTheme.colors.textSecondary,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis
            )

            // Tags Row + Actions
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = SoftTheme.spacing.xs),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Tags
                Row(
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f, fill = false)
                ) {
                    memory.tags.take(3).forEach { tag ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(SoftTheme.tokens.corners.sm))
                                .background(SoftTheme.colors.surfaceCard.copy(alpha = 0.6f))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Text(
                                text = "#$tag",
                                style = MaterialTheme.typography.labelSmall,
                                color = SoftTheme.colors.textMuted
                            )
                        }
                    }
                    if (memory.tags.size > 3) {
                        Text(
                            text = "+${memory.tags.size - 3}",
                            style = MaterialTheme.typography.labelSmall,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }

                // Row of quick actions
                Row(
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xxs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = onEdit,
                        modifier = Modifier
                            .size(32.dp)
                            .testTag("memory_edit_btn_${memory.id}")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Edit,
                            contentDescription = "Edit",
                            tint = SoftTheme.colors.textSecondary,
                            modifier = Modifier.size(16.dp)
                        )
                    }

                    IconButton(
                        onClick = onToggleArchive,
                        modifier = Modifier
                            .size(32.dp)
                            .testTag("memory_archive_btn_${memory.id}")
                    ) {
                        Icon(
                            imageVector = if (memory.isArchived) Icons.Default.Unarchive else Icons.Default.Archive,
                            contentDescription = if (memory.isArchived) "Restore" else "Archive",
                            tint = SoftTheme.colors.textSecondary,
                            modifier = Modifier.size(16.dp)
                        )
                    }

                    IconButton(
                        onClick = onDelete,
                        modifier = Modifier
                            .size(32.dp)
                            .testTag("memory_delete_btn_${memory.id}")
                    ) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = "Delete",
                            tint = SoftTheme.colors.statusError.copy(alpha = 0.7f),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }
    }
}

/**
 * Readable Memory Detail View Sheet prioritizing easy reading and actions.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MemoryDetailSheet(
    memory: MemoryItem,
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onToggleArchive: () -> Unit,
    onDelete: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val categoryColor = getCategoryColor(memory.category)
    val categoryIcon = getCategoryIcon(memory.category)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.surfaceCard,
        tonalElevation = SoftTheme.tokens.elevations.overlay
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SoftTheme.spacing.xl, vertical = SoftTheme.spacing.lg)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            // Header: Category, Status, Close
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                ) {
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .clip(CircleShape)
                            .background(categoryColor.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = categoryIcon,
                            contentDescription = null,
                            tint = categoryColor,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    Text(
                        text = memory.category.displayName,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = categoryColor
                    )
                    if (memory.isArchived) {
                        StatusBadge(text = "Archived", severity = StatusSeverity.Warning, hasDot = false)
                    }
                }

                IconButton(onClick = onDismiss) {
                    Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = SoftTheme.colors.textMuted)
                }
            }

            // Title
            Text(
                text = memory.title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = SoftTheme.colors.textPrimary
            )

            // Dates & Category Description
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.lg)
            ) {
                Text(
                    text = "Created: ${memory.createdAt}",
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textMuted
                )
                if (memory.updatedAt != memory.createdAt) {
                    Text(
                        text = "Updated: ${memory.updatedAt}",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textMuted
                    )
                }
            }

            // Full Readable Content Body
            SoftGlassCard(
                elevation = SoftTheme.tokens.elevations.subtle,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = memory.content,
                    style = MaterialTheme.typography.bodyLarge,
                    color = SoftTheme.colors.textPrimary,
                    modifier = Modifier.padding(SoftTheme.spacing.lg)
                )
            }

            // Tags
            if (memory.tags.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)) {
                    Text(
                        text = "TAGS",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textMuted
                    )
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                    ) {
                        memory.tags.forEach { tag ->
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(SoftTheme.tokens.corners.sm))
                                    .background(SoftTheme.colors.surfaceCard.copy(alpha = 0.8f))
                                    .padding(horizontal = 10.dp, vertical = 4.dp)
                            ) {
                                Text(
                                    text = "#$tag",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = SoftTheme.colors.accentBlue
                                )
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.sm))

            // Action Buttons Row: Edit, Archive/Restore, Delete
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
            ) {
                Button(
                    onClick = onEdit,
                    colors = ButtonDefaults.buttonColors(containerColor = SoftTheme.colors.accentBlue),
                    modifier = Modifier.weight(1f).testTag("memory_view_edit_btn")
                ) {
                    Icon(imageVector = Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))
                    Text("Edit")
                }

                Button(
                    onClick = {
                        onToggleArchive()
                        onDismiss()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = SoftTheme.colors.surfaceCard),
                    modifier = Modifier.weight(1f).testTag("memory_view_archive_btn")
                ) {
                    Icon(
                        imageVector = if (memory.isArchived) Icons.Default.Unarchive else Icons.Default.Archive,
                        contentDescription = null,
                        tint = SoftTheme.colors.textPrimary,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))
                    Text(if (memory.isArchived) "Restore" else "Archive", color = SoftTheme.colors.textPrimary)
                }

                Button(
                    onClick = {
                        onDelete()
                        onDismiss()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = SoftTheme.colors.statusError.copy(alpha = 0.15f)),
                    modifier = Modifier.weight(1f).testTag("memory_view_delete_btn")
                ) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = null,
                        tint = SoftTheme.colors.statusError,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(SoftTheme.spacing.xs))
                    Text("Delete", color = SoftTheme.colors.statusError)
                }
            }

            Spacer(modifier = Modifier.height(SoftTheme.spacing.xl))
        }
    }
}

/**
 * Memory Editor Dialog (Create / Edit).
 */
@Composable
private fun MemoryEditorDialog(
    memory: MemoryItem,
    isCreatingNew: Boolean,
    onDismiss: () -> Unit,
    onSave: (title: String, content: String, category: MemoryCategory, tags: List<String>) -> Unit
) {
    var title by remember { mutableStateOf(memory.title) }
    var content by remember { mutableStateOf(memory.content) }
    var category by remember { mutableStateOf(memory.category) }
    var tagsInput by remember { mutableStateOf(memory.tags.joinToString(", ")) }

    Dialog(onDismissRequest = onDismiss) {
        SoftGlassCard(
            elevation = SoftTheme.tokens.elevations.overlay,
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.xl),
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (isCreatingNew) "New Memory" else "Edit Memory",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )

                    IconButton(onClick = onDismiss) {
                        Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = SoftTheme.colors.textMuted)
                    }
                }

                // Title Input
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "TITLE",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textMuted
                    )
                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        placeholder = { Text("Short descriptive summary") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SoftTheme.colors.accentBlue,
                            unfocusedBorderColor = SoftTheme.colors.surfaceCard
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("memory_title_input")
                    )
                }

                // Category Selector
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "CATEGORY",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textMuted
                    )
                    val scrollState = rememberScrollState()
                    Row(
                        modifier = Modifier
                            .horizontalScroll(scrollState)
                            .padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.xs)
                    ) {
                        MemoryCategory.entries.forEach { cat ->
                            val isSelected = category == cat
                            val color = getCategoryColor(cat)
                            FilterChip(
                                selected = isSelected,
                                onClick = { category = cat },
                                label = { Text(cat.displayName) },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = color.copy(alpha = 0.2f),
                                    selectedLabelColor = color
                                ),
                                modifier = Modifier.testTag("editor_category_chip_${cat.name}")
                            )
                        }
                    }
                }

                // Content Body Input
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "MEMORY DETAILS & FACTS",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textMuted
                    )
                    OutlinedTextField(
                        value = content,
                        onValueChange = { content = it },
                        placeholder = { Text("Write the human-readable memory content...") },
                        minLines = 4,
                        maxLines = 8,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SoftTheme.colors.accentBlue,
                            unfocusedBorderColor = SoftTheme.colors.surfaceCard
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("memory_content_input")
                    )
                }

                // Tags Input
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "TAGS (COMMA SEPARATED)",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textMuted
                    )
                    OutlinedTextField(
                        value = tagsInput,
                        onValueChange = { tagsInput = it },
                        placeholder = { Text("e.g. Identity, LAN, Sprint2026") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = SoftTheme.colors.accentBlue,
                            unfocusedBorderColor = SoftTheme.colors.surfaceCard
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("memory_tags_input")
                    )
                }

                Spacer(modifier = Modifier.height(SoftTheme.spacing.sm))

                // Buttons
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SoftTheme.spacing.sm)
                ) {
                    TextButton(
                        onClick = onDismiss,
                        modifier = Modifier
                            .weight(1f)
                            .testTag("memory_cancel_btn")
                    ) {
                        Text("Cancel", color = SoftTheme.colors.textSecondary)
                    }

                    Button(
                        onClick = {
                            val parsedTags = tagsInput.split(",")
                                .map { it.trim() }
                                .filter { it.isNotEmpty() }
                            onSave(title, content, category, parsedTags)
                        },
                        enabled = title.isNotBlank() && content.isNotBlank(),
                        colors = ButtonDefaults.buttonColors(containerColor = SoftTheme.colors.accentBlue),
                        modifier = Modifier
                            .weight(1f)
                            .testTag("memory_save_btn")
                    ) {
                        Text("Save Record")
                    }
                }
            }
        }
    }
}

/**
 * Empty memory state display.
 */
@Composable
private fun EmptyMemoryState(
    isSearching: Boolean,
    isArchived: Boolean,
    onClearFilters: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier.padding(SoftTheme.spacing.xxl),
        contentAlignment = Alignment.Center
    ) {
        SoftGlassCard(
            elevation = SoftTheme.tokens.elevations.subtle,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(SoftTheme.spacing.xxl),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
            ) {
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(SoftTheme.colors.accentBlue.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (isArchived) Icons.Default.Archive else Icons.Default.Storage,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentBlue,
                        modifier = Modifier.size(28.dp)
                    )
                }

                Text(
                    text = if (isArchived) "No Archived Memories" else if (isSearching) "No Matching Records Found" else "No Memories Recorded",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = SoftTheme.colors.textPrimary
                )

                Text(
                    text = if (isSearching) {
                        "Try adjusting your search query or selecting a different category."
                    } else if (isArchived) {
                        "Active memories you archive will appear in this long-term vault."
                    } else {
                        "Tap the + button to save facts, personal preferences, and project context."
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = SoftTheme.colors.textSecondary
                )

                if (isSearching) {
                    Button(
                        onClick = onClearFilters,
                        colors = ButtonDefaults.buttonColors(containerColor = SoftTheme.colors.accentBlue.copy(alpha = 0.2f)),
                        modifier = Modifier.padding(top = SoftTheme.spacing.sm)
                    ) {
                        Text("Clear Filters", color = SoftTheme.colors.accentBlue)
                    }
                }
            }
        }
    }
}

/**
 * Helpers for category colors and icons.
 */
@Composable
private fun getCategoryColor(category: MemoryCategory): Color {
    return when (category) {
        MemoryCategory.PROFILE -> SoftTheme.colors.accentBlue
        MemoryCategory.PREFERENCE -> SoftTheme.colors.accentAmber
        MemoryCategory.FACT -> SoftTheme.colors.accentCyan
        MemoryCategory.PROJECT -> SoftTheme.colors.accentViolet
        MemoryCategory.EVENT -> SoftTheme.colors.statusInfo
        MemoryCategory.TEMPORARY -> SoftTheme.colors.textMuted
    }
}

private fun getCategoryIcon(category: MemoryCategory): ImageVector {
    return when (category) {
        MemoryCategory.PROFILE -> Icons.Default.Person
        MemoryCategory.PREFERENCE -> Icons.Default.Tune
        MemoryCategory.FACT -> Icons.Default.Lightbulb
        MemoryCategory.PROJECT -> Icons.Default.Folder
        MemoryCategory.EVENT -> Icons.Default.Schedule
        MemoryCategory.TEMPORARY -> Icons.Default.Info
    }
}
