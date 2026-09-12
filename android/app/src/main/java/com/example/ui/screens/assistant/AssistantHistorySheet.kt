package com.example.ui.screens.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import com.example.ui.components.softBounceOverscroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.Conversation
import com.example.ui.components.PrimaryButton
import com.example.ui.components.SoftGlassCard
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Mobile-friendly modal sheet for conversation history:
 * - Recent conversations
 * - Real-time search filter
 * - New Conversation action button
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AssistantHistorySheet(
    isOpen: Boolean,
    onDismiss: () -> Unit,
    conversations: List<Conversation>,
    currentConversationId: String,
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    onSelectConversation: (String) -> Unit,
    onNewConversation: () -> Unit,
    onDeleteConversation: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (!isOpen) return

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val filteredConversations = if (searchQuery.isBlank()) {
        conversations
    } else {
        conversations.filter {
            it.title.contains(searchQuery, ignoreCase = true) ||
                it.previewSnippet.contains(searchQuery, ignoreCase = true)
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SoftTheme.colors.surfaceElevated,
        scrimColor = SoftTheme.colors.background.copy(alpha = 0.6f),
        dragHandle = null,
        modifier = modifier.testTag("assistant_history_sheet")
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.85f)
                .padding(SoftTheme.spacing.lg),
            verticalArrangement = Arrangement.spacedBy(SoftTheme.spacing.md)
        ) {
            // Header Row: Title + Session count + Close button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Conversations",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = SoftTheme.colors.textPrimary
                    )
                    Text(
                        text = "${conversations.size} local on-device sessions",
                        style = MaterialTheme.typography.labelSmall,
                        color = SoftTheme.colors.textMuted,
                        fontSize = 11.sp
                    )
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(36.dp)
                        .testTag("btn_close_history_sheet")
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close history",
                        tint = SoftTheme.colors.textSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            // "New Conversation" Button
            PrimaryButton(
                text = "New Conversation",
                leadingIcon = Icons.Default.Add,
                onClick = onNewConversation,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("history_new_conversation_button")
            )

            // Search input field
            OutlinedTextField(
                value = searchQuery,
                onValueChange = onSearchQueryChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("history_search_input"),
                placeholder = {
                    Text(
                        text = "Search conversations by topic...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = SoftTheme.colors.textMuted
                    )
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Search",
                        tint = SoftTheme.colors.textMuted,
                        modifier = Modifier.size(18.dp)
                    )
                },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { onSearchQueryChange("") }) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Clear search",
                                tint = SoftTheme.colors.textMuted,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = SoftTheme.colors.surfaceWell,
                    unfocusedContainerColor = SoftTheme.colors.surfaceWell,
                    focusedBorderColor = SoftTheme.colors.accentBlue,
                    unfocusedBorderColor = SoftTheme.colors.borderSubtle,
                    focusedTextColor = SoftTheme.colors.textPrimary,
                    unfocusedTextColor = SoftTheme.colors.textPrimary
                )
            )

            // Recent Conversations List
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .softBounceOverscroll()
                    .testTag("history_conversations_list"),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (filteredConversations.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = if (searchQuery.isBlank()) "No conversation history yet." else "No conversations match \"$searchQuery\"",
                                style = MaterialTheme.typography.bodyMedium,
                                color = SoftTheme.colors.textMuted
                            )
                        }
                    }
                } else {
                    items(filteredConversations, key = { it.id }) { conv ->
                        HistoryConversationItem(
                            conversation = conv,
                            isSelected = conv.id == currentConversationId,
                            onClick = { onSelectConversation(conv.id) },
                            onDelete = { onDeleteConversation(conv.id) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun HistoryConversationItem(
    conversation: Conversation,
    isSelected: Boolean,
    onClick: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val borderColor = if (isSelected) SoftTheme.colors.accentBlue else SoftTheme.colors.borderSubtle
    val bgColor = if (isSelected) SoftTheme.colors.accentBlue.copy(alpha = 0.08f) else SoftTheme.colors.surface

    Row(
        modifier = modifier
            .fillMaxWidth()
            .testTag("item_conv_${conversation.id}")
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(bgColor)
            .border(
                width = if (isSelected) SoftTheme.tokens.borders.medium else SoftTheme.tokens.borders.hairline,
                color = borderColor,
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .clickable(
                role = Role.Button,
                onClickLabel = "Select conversation ${conversation.title}",
                onClick = onClick
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = conversation.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.SemiBold,
                    color = SoftTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                if (isSelected) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.accentBlue.copy(alpha = 0.15f))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "Active",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = SoftTheme.colors.accentBlue,
                            fontSize = 9.sp
                        )
                    }
                }
            }

            Text(
                text = conversation.previewSnippet,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                fontSize = 12.sp
            )

            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 2.dp)
            ) {
                Text(
                    text = conversation.updatedAt,
                    style = MonospaceTelemetry,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 10.sp
                )
                Text(
                    text = "•",
                    style = MonospaceTelemetry,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 10.sp
                )
                Text(
                    text = "${conversation.messageCount} messages",
                    style = MonospaceTelemetry,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 10.sp
                )
                Text(
                    text = "•",
                    style = MonospaceTelemetry,
                    color = SoftTheme.colors.textMuted,
                    fontSize = 10.sp
                )
                Text(
                    text = conversation.providerMode.name.substringBefore(" "),
                    style = MonospaceTelemetry,
                    color = SoftTheme.colors.accentBlue,
                    fontSize = 10.sp
                )
            }
        }

        IconButton(
            onClick = onDelete,
            modifier = Modifier
                .size(32.dp)
                .testTag("btn_delete_conv_${conversation.id}")
                .semantics { contentDescription = "Delete conversation ${conversation.title}" }
        ) {
            Icon(
                imageVector = Icons.Default.DeleteOutline,
                contentDescription = null,
                tint = SoftTheme.colors.textMuted,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}
