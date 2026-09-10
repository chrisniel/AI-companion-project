package com.example.ui.screens.assistant

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AttachFile
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.domain.model.ChatMessage
import com.example.domain.model.MessagePayload
import com.example.domain.model.MessageSender
import com.example.domain.model.SearchResultItem
import com.example.domain.model.ToolExecutionStatus
import com.example.ui.components.SoftGlassCard
import com.example.ui.components.SoftWell
import com.example.ui.theme.MonospaceTelemetry
import com.example.ui.theme.SoftTheme

/**
 * Dispatches and renders individual chat items based on their typed payload:
 * User message, Assistant response, Tool action, Memory retrieval, Search result,
 * Warning, Error, and System status.
 *
 * Designed for high readability and pristine Soft Glass styling without heavy
 * neumorphic embossing on long chat text.
 */
@Composable
fun AssistantMessageItem(
    message: ChatMessage,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        contentAlignment = when (message.sender) {
            MessageSender.USER -> Alignment.CenterEnd
            MessageSender.ASSISTANT -> Alignment.CenterStart
            MessageSender.SYSTEM -> Alignment.Center
        }
    ) {
        when (val payload = message.payload) {
            is MessagePayload.User -> UserMessageBubble(
                payload = payload,
                timestamp = message.timestamp
            )

            is MessagePayload.Assistant -> AssistantMessageBubble(
                payload = payload,
                timestamp = message.timestamp
            )

            is MessagePayload.ToolAction -> ToolActionBubble(
                payload = payload,
                timestamp = message.timestamp
            )

            is MessagePayload.MemoryRetrieval -> MemoryRetrievalBubble(
                payload = payload,
                timestamp = message.timestamp
            )

            is MessagePayload.SearchResult -> SearchResultBubble(
                payload = payload,
                timestamp = message.timestamp
            )

            is MessagePayload.Warning -> WarningMessageBubble(
                payload = payload,
                timestamp = message.timestamp
            )

            is MessagePayload.Error -> ErrorMessageBubble(
                payload = payload,
                timestamp = message.timestamp,
                onRetry = onRetry
            )

            is MessagePayload.SystemStatus -> SystemStatusDivider(
                payload = payload
            )
        }
    }
}

/**
 * 1. User message bubble
 */
@Composable
fun UserMessageBubble(
    payload: MessagePayload.User,
    timestamp: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .testTag("chat_user_message")
            .widthIn(max = 320.dp),
        horizontalAlignment = Alignment.End
    ) {
        // Optional file attachments chips
        if (payload.attachments.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .padding(bottom = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                payload.attachments.forEach { file ->
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.accentBlue.copy(alpha = 0.12f))
                            .border(
                                width = SoftTheme.tokens.borders.hairline,
                                color = SoftTheme.colors.accentBlue.copy(alpha = 0.25f),
                                shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                            )
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.AttachFile,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentBlue,
                            modifier = Modifier.size(12.dp)
                        )
                        Text(
                            text = file,
                            style = MaterialTheme.typography.labelSmall,
                            color = SoftTheme.colors.textPrimary,
                            fontSize = 10.sp
                        )
                    }
                }
            }
        }

        // Clean user message container with high text contrast
        Box(
            modifier = Modifier
                .clip(
                    RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = 16.dp,
                        bottomEnd = 4.dp
                    )
                )
                .background(SoftTheme.colors.accentBlue.copy(alpha = 0.14f))
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = SoftTheme.colors.accentBlue.copy(alpha = 0.35f),
                    shape = RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = 16.dp,
                        bottomEnd = 4.dp
                    )
                )
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Text(
                text = payload.text,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontSize = 15.sp,
                    lineHeight = 21.sp
                ),
                color = SoftTheme.colors.textPrimary
            )
        }

        Text(
            text = timestamp,
            style = MaterialTheme.typography.labelSmall,
            color = SoftTheme.colors.textMuted,
            fontSize = 10.sp,
            modifier = Modifier.padding(top = 2.dp, end = 2.dp)
        )
    }
}

/**
 * 2. Assistant response card
 */
@Composable
fun AssistantMessageBubble(
    payload: MessagePayload.Assistant,
    timestamp: String,
    modifier: Modifier = Modifier
) {
    var isCopied by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .testTag("chat_assistant_message")
            .widthIn(max = 340.dp),
        horizontalAlignment = Alignment.Start
    ) {
        SoftGlassCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = SoftTheme.tokens.elevations.subtle,
            shape = RoundedCornerShape(
                topStart = 4.dp,
                topEnd = 16.dp,
                bottomStart = 16.dp,
                bottomEnd = 16.dp
            )
        ) {
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // Header: Assistant icon + Model name + Copy button
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(22.dp)
                                .clip(CircleShape)
                                .background(SoftTheme.colors.accentBlue.copy(alpha = 0.15f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.AutoAwesome,
                                contentDescription = null,
                                tint = SoftTheme.colors.accentBlue,
                                modifier = Modifier.size(13.dp)
                            )
                        }

                        Text(
                            text = payload.modelName,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.textSecondary,
                            fontSize = 11.sp
                        )

                        if (payload.isStreaming) {
                            PulsingStreamIndicator()
                        }
                    }

                    IconButton(
                        onClick = { isCopied = true },
                        modifier = Modifier.size(24.dp)
                    ) {
                        Icon(
                            imageVector = if (isCopied) Icons.Default.Check else Icons.Default.ContentCopy,
                            contentDescription = "Copy message",
                            tint = if (isCopied) SoftTheme.colors.statusSuccess else SoftTheme.colors.textMuted,
                            modifier = Modifier.size(14.dp)
                        )
                    }
                }

                // High readability text body
                Text(
                    text = payload.text,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontSize = 15.sp,
                        lineHeight = 22.sp
                    ),
                    color = SoftTheme.colors.textPrimary
                )

                // Optional Telemetry Footer
                if (!payload.isStreaming && payload.tokensCount > 0) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 2.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "${payload.tokensCount} tokens • ${payload.tokensPerSec} t/s • ${payload.latencyMs}ms",
                            style = MonospaceTelemetry,
                            fontSize = 10.sp,
                            color = SoftTheme.colors.textMuted
                        )
                        Text(
                            text = timestamp,
                            style = MaterialTheme.typography.labelSmall,
                            fontSize = 10.sp,
                            color = SoftTheme.colors.textMuted
                        )
                    }
                }
            }
        }
    }
}

/**
 * 3. Tool action card
 */
@Composable
fun ToolActionBubble(
    payload: MessagePayload.ToolAction,
    timestamp: String,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }

    SoftGlassCard(
        modifier = modifier
            .testTag("chat_tool_action")
            .widthIn(max = 340.dp),
        elevation = SoftTheme.tokens.elevations.subtle,
        shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // Header Row: Tool Icon + Tool Name + Status Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.weight(1f, fill = false)
                ) {
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .clip(RoundedCornerShape(6.dp))
                            .background(SoftTheme.colors.accentViolet.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Build,
                            contentDescription = null,
                            tint = SoftTheme.colors.accentViolet,
                            modifier = Modifier.size(13.dp)
                        )
                    }
                    Text(
                        text = "TOOL: ${payload.toolName}",
                        style = MonospaceTelemetry,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = SoftTheme.colors.textPrimary
                    )
                }

                // Status chip
                val (statusColor, statusLabel) = when (payload.status) {
                    ToolExecutionStatus.RUNNING -> SoftTheme.colors.accentCyan to "Running"
                    ToolExecutionStatus.SUCCESS -> SoftTheme.colors.statusSuccess to "Executed"
                    ToolExecutionStatus.FAILED -> SoftTheme.colors.statusError to "Failed"
                }

                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(statusColor.copy(alpha = 0.12f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = "$statusLabel • ${payload.executionTimeMs}ms",
                        style = MonospaceTelemetry,
                        fontSize = 9.sp,
                        color = statusColor
                    )
                }
            }

            // Monospace invocation snippet
            Text(
                text = payload.functionSignature,
                style = MonospaceTelemetry,
                fontSize = 12.sp,
                color = SoftTheme.colors.accentBlue
            )

            // Result snippet
            Text(
                text = payload.outputSnippet,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textSecondary,
                fontSize = 12.sp
            )

            // Expandable raw JSON arguments
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = !expanded }
                    .padding(vertical = 2.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = if (expanded) "Hide Arguments" else "View JSON Payload",
                    style = MaterialTheme.typography.labelSmall,
                    fontSize = 10.sp,
                    color = SoftTheme.colors.textMuted
                )
                Icon(
                    imageVector = if (expanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                    contentDescription = null,
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(14.dp)
                )
            }

            AnimatedVisibility(visible = expanded) {
                SoftWell(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Box(modifier = Modifier.padding(8.dp)) {
                        Text(
                            text = payload.argumentsJson,
                            style = MonospaceTelemetry,
                            fontSize = 11.sp,
                            color = SoftTheme.colors.textPrimary
                        )
                    }
                }
            }
        }
    }
}

/**
 * 4. Memory retrieval card
 */
@Composable
fun MemoryRetrievalBubble(
    payload: MessagePayload.MemoryRetrieval,
    timestamp: String,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .testTag("chat_memory_retrieval")
            .widthIn(max = 340.dp),
        elevation = SoftTheme.tokens.elevations.subtle,
        shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
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
                        imageVector = Icons.Default.Psychology,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentViolet,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "MEMORY RECALL",
                        style = MonospaceTelemetry,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = SoftTheme.colors.accentViolet
                    )
                }

                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                        .background(SoftTheme.colors.accentViolet.copy(alpha = 0.12f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = "${(payload.confidenceScore * 100).toInt()}% match",
                        style = MonospaceTelemetry,
                        fontSize = 9.sp,
                        color = SoftTheme.colors.accentViolet
                    )
                }
            }

            Text(
                text = "Key: ${payload.memoryKey} (${payload.category})",
                style = MonospaceTelemetry,
                fontSize = 10.sp,
                color = SoftTheme.colors.textMuted
            )

            SoftWell(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(8.dp)
            ) {
                Box(modifier = Modifier.padding(8.dp)) {
                    Text(
                        text = "\"${payload.retrievedFact}\"",
                        style = MaterialTheme.typography.bodySmall,
                        fontSize = 12.sp,
                        color = SoftTheme.colors.textPrimary
                    )
                }
            }
        }
    }
}

/**
 * 5. Search result card
 */
@Composable
fun SearchResultBubble(
    payload: MessagePayload.SearchResult,
    timestamp: String,
    modifier: Modifier = Modifier
) {
    SoftGlassCard(
        modifier = modifier
            .testTag("chat_search_result")
            .widthIn(max = 340.dp),
        elevation = SoftTheme.tokens.elevations.subtle,
        shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
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
                        imageVector = Icons.Default.Search,
                        contentDescription = null,
                        tint = SoftTheme.colors.accentCyan,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "LOCAL VECTOR SEARCH",
                        style = MonospaceTelemetry,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = SoftTheme.colors.accentCyan
                    )
                }

                Text(
                    text = "${payload.matchedChunksCount} matches",
                    style = MonospaceTelemetry,
                    fontSize = 10.sp,
                    color = SoftTheme.colors.textMuted
                )
            }

            Text(
                text = "Query: \"${payload.query}\"",
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium,
                fontSize = 12.sp,
                color = SoftTheme.colors.textPrimary
            )

            payload.topResults.forEach { item ->
                SoftWell(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(6.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = item.title,
                                style = MonospaceTelemetry,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 10.sp,
                                color = SoftTheme.colors.textSecondary
                            )
                            Text(
                                text = "${(item.similarityScore * 100).toInt()}%",
                                style = MonospaceTelemetry,
                                fontSize = 9.sp,
                                color = SoftTheme.colors.accentCyan
                            )
                        }
                        Text(
                            text = item.snippet,
                            style = MaterialTheme.typography.bodySmall,
                            fontSize = 11.sp,
                            color = SoftTheme.colors.textPrimary
                        )
                    }
                }
            }
        }
    }
}

/**
 * 6. Warning message card
 */
@Composable
fun WarningMessageBubble(
    payload: MessagePayload.Warning,
    timestamp: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .testTag("chat_warning_card")
            .widthIn(max = 340.dp)
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(SoftTheme.colors.statusWarning.copy(alpha = 0.12f))
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.statusWarning.copy(alpha = 0.4f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .padding(10.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
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
                        imageVector = Icons.Default.WarningAmber,
                        contentDescription = null,
                        tint = SoftTheme.colors.statusWarning,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "SYSTEM WARNING",
                        style = MonospaceTelemetry,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = SoftTheme.colors.statusWarning
                    )
                }

                Text(
                    text = payload.warningCode,
                    style = MonospaceTelemetry,
                    fontSize = 9.sp,
                    color = SoftTheme.colors.statusWarning
                )
            }

            Text(
                text = payload.message,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textPrimary,
                fontSize = 13.sp,
                lineHeight = 18.sp
            )

            if (payload.details != null) {
                Text(
                    text = payload.details,
                    style = MonospaceTelemetry,
                    fontSize = 10.sp,
                    color = SoftTheme.colors.textMuted
                )
            }
        }
    }
}

/**
 * 7. Error card
 */
@Composable
fun ErrorMessageBubble(
    payload: MessagePayload.Error,
    timestamp: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .testTag("chat_error_card")
            .widthIn(max = 340.dp)
            .clip(RoundedCornerShape(SoftTheme.tokens.corners.md))
            .background(SoftTheme.colors.statusError.copy(alpha = 0.12f))
            .border(
                width = SoftTheme.tokens.borders.hairline,
                color = SoftTheme.colors.statusError.copy(alpha = 0.4f),
                shape = RoundedCornerShape(SoftTheme.tokens.corners.md)
            )
            .padding(10.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
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
                        imageVector = Icons.Default.ErrorOutline,
                        contentDescription = null,
                        tint = SoftTheme.colors.statusError,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "EXECUTION ERROR",
                        style = MonospaceTelemetry,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = SoftTheme.colors.statusError
                    )
                }

                Text(
                    text = payload.errorCode,
                    style = MonospaceTelemetry,
                    fontSize = 9.sp,
                    color = SoftTheme.colors.statusError
                )
            }

            Text(
                text = payload.message,
                style = MaterialTheme.typography.bodySmall,
                color = SoftTheme.colors.textPrimary,
                fontSize = 13.sp,
                lineHeight = 18.sp
            )

            if (payload.canRetry) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    Row(
                        modifier = Modifier
                            .testTag("chat_error_retry_button")
                            .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                            .background(SoftTheme.colors.statusError.copy(alpha = 0.2f))
                            .clickable(onClick = onRetry)
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = null,
                            tint = SoftTheme.colors.statusError,
                            modifier = Modifier.size(13.dp)
                        )
                        Text(
                            text = "Retry Action",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = SoftTheme.colors.statusError,
                            fontSize = 11.sp
                        )
                    }
                }
            }
        }
    }
}

/**
 * 8. System status divider
 */
@Composable
fun SystemStatusDivider(
    payload: MessagePayload.SystemStatus,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .testTag("chat_system_status")
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(SoftTheme.tokens.corners.pill))
                .background(SoftTheme.colors.surfaceWell)
                .border(
                    width = SoftTheme.tokens.borders.hairline,
                    color = SoftTheme.colors.borderSubtle,
                    shape = RoundedCornerShape(SoftTheme.tokens.corners.pill)
                )
                .padding(horizontal = 12.dp, vertical = 4.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = SoftTheme.colors.textMuted,
                    modifier = Modifier.size(12.dp)
                )
                Text(
                    text = payload.text,
                    style = MaterialTheme.typography.labelSmall,
                    color = SoftTheme.colors.textSecondary,
                    fontSize = 11.sp
                )
            }
        }
    }
}

@Composable
private fun PulsingStreamIndicator() {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(600),
            repeatMode = RepeatMode.Reverse
        ),
        label = "alpha"
    )

    Row(
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        repeat(3) {
            Box(
                modifier = Modifier
                    .size(4.dp)
                    .clip(CircleShape)
                    .background(SoftTheme.colors.accentBlue)
                    .alpha(alpha)
            )
        }
    }
}
