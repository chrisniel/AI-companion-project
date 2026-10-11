import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/chat/assistant_markdown_view.dart';
import '../features/chat/conversation_history_drawer.dart';
import '../features/chat/desktop_chat_controller.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.controller,
    this.onNavigateToSettings,
  });

  final DesktopChatController? controller;
  final VoidCallback? onNavigateToSettings;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  DesktopChatController? _internalController;
  bool _canSend = false;
  bool _isHistoryOpen = false;
  bool _isSubmitting = false;
  String? _currentConversationId;
  bool _userExplicitlySent = false;

  DesktopChatController get _effectiveController => widget.controller ?? _internalController!;

  void _toggleHistoryDrawer() {
    setState(() {
      _isHistoryOpen = !_isHistoryOpen;
    });
  }

  void _closeHistoryDrawer() {
    if (_isHistoryOpen) {
      setState(() {
        _isHistoryOpen = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = DesktopChatController(
        client: CompanionClient(
          baseUrl: 'http://127.0.0.1:8000',
          credentialStore: InMemoryCredentialStore(),
        ),
      );
    }
    _textController = TextEditingController();
    _focusNode = FocusNode(onKeyEvent: _handleFocusKeyEvent);
    _scrollController = ScrollController();

    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _effectiveController.addListener(_onChatControllerChanged);

    // Initialize current conversation state if already selected
    final activeId = _effectiveController.activeConversation?.id;
    if (activeId != null) {
      _currentConversationId = activeId;
      final draft = _effectiveController.getDraft(activeId);
      if (draft.isNotEmpty) {
        _textController.text = draft;
      }
    }

    // Initial load and first layout restoration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_effectiveController.conversations.isEmpty) {
        _effectiveController.loadConversations();
      } else if (_currentConversationId != null && _scrollController.hasClients) {
        final savedOffset = _effectiveController.getScrollOffset(_currentConversationId!);
        if (savedOffset != null) {
          _scrollController.jumpTo(
            savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        } else if (_effectiveController.messages.isNotEmpty) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onChatControllerChanged);
      widget.controller?.addListener(_onChatControllerChanged);
    }
  }

  KeyEventResult _handleFocusKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (event is KeyDownEvent) {
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        if (isShift) {
          _insertNewline();
          return KeyEventResult.handled;
        } else {
          final isBusy = _effectiveController.isGenerating ||
              _effectiveController.isAwaitingAcceptance ||
              _effectiveController.isCreatingConversation ||
              _isSubmitting;
          if (!isBusy && _canSend && _effectiveController.canSend) {
            _handleSend();
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        final isBusy = _effectiveController.isGenerating ||
            _effectiveController.isAwaitingAcceptance ||
            _effectiveController.isCreatingConversation ||
            _isSubmitting;
        if (isBusy) {
          _effectiveController.cancelGeneration();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  void _insertNewline() {
    final text = _textController.text;
    final selection = _textController.selection;
    if (selection.isValid && selection.start >= 0 && selection.end >= selection.start) {
      final newText = text.replaceRange(selection.start, selection.end, '\n');
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + 1),
      );
    } else {
      final newText = '$text\n';
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return (maxScroll - currentScroll) <= 80.0;
  }

  void _onScroll() {
    if (_scrollController.hasClients && _currentConversationId != null) {
      _effectiveController.setScrollOffset(_currentConversationId!, _scrollController.offset);
    }
    if (!_isNearBottom) {
      _userExplicitlySent = false;
    }
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _canSend) {
      setState(() {
        _canSend = hasText;
      });
    }
    if (_currentConversationId != null) {
      _effectiveController.setDraft(_currentConversationId!, _textController.text);
    }
  }

  void _onChatControllerChanged() {
    final activeId = _effectiveController.activeConversation?.id;
    if (activeId != _currentConversationId) {
      // 1. Save state of previous conversation
      if (_currentConversationId != null) {
        _effectiveController.setDraft(_currentConversationId!, _textController.text);
        if (_scrollController.hasClients) {
          _effectiveController.setScrollOffset(_currentConversationId!, _scrollController.offset);
        }
      }

      // 2. Switch to new conversation
      _currentConversationId = activeId;
      _userExplicitlySent = false;

      // 3. Restore draft for new conversation
      final draft = activeId != null ? _effectiveController.getDraft(activeId) : '';
      if (_textController.text != draft) {
        _textController.text = draft;
      }

      // 4. Restore scroll offset or scroll to bottom on first opening
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (activeId != null) {
          final savedOffset = _effectiveController.getScrollOffset(activeId);
          if (savedOffset != null) {
            _scrollController.jumpTo(
              savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            );
          } else if (_effectiveController.messages.isNotEmpty) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _effectiveController.removeListener(_onChatControllerChanged);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (_isSubmitting ||
        _effectiveController.isGenerating ||
        _effectiveController.isAwaitingAcceptance ||
        _effectiveController.isCreatingConversation ||
        !_effectiveController.canSend) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _effectiveController.sendMessage(
        text,
        onAccepted: () {
          if (mounted) {
            _userExplicitlySent = true;
            _textController.clear();
            setState(() {
              _canSend = false;
            });
            _scrollToBottom();
          }
        },
      );
    } catch (_) {
      // Pre-acceptance rejection/failure: draft remains intact in _textController!
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _canSend = _textController.text.trim().isNotEmpty;
        });
      }
    }

    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        if (animate) {
          _scrollController.animateTo(
            max,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(max);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatCtrl = _effectiveController;

    return ListenableBuilder(
      listenable: chatCtrl,
      builder: (context, _) {
        final ext = Theme.of(context).extension<CompanionThemeExtension>();
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Auto-follow generation only if near bottom or following explicit user send
        if (chatCtrl.isGenerating && (_userExplicitlySent || _isNearBottom)) {
          _scrollToBottom(animate: false);
        } else if (!chatCtrl.isGenerating) {
          _userExplicitlySent = false;
        }

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyH, control: true): _toggleHistoryDrawer,
            const SingleActivator(LogicalKeyboardKey.escape): _closeHistoryDrawer,
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(CompanionSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Bar
                      _buildHeader(context, chatCtrl, ext, isDark),
                      const SizedBox(height: CompanionSpacing.lg),

                      // Central Conversational Stage
                      Expanded(
                        child: chatCtrl.messages.isEmpty
                            ? _buildWelcomeStage(context, ext, chatCtrl)
                            : _buildMessageList(context, chatCtrl, ext, isDark),
                      ),

                      if (chatCtrl.errorMessage != null && !chatCtrl.isGenerating) ...[
                        const SizedBox(height: CompanionSpacing.sm),
                        _buildErrorBanner(context, chatCtrl.errorMessage!, ext),
                      ],

                      const SizedBox(height: CompanionSpacing.lg),

                      // Bottom Composer Bar
                      _buildComposerBar(context, chatCtrl, ext),
                    ],
                  ),
                ),

                // History Drawer Overlay
                ConversationHistoryDrawer(
                  isOpen: _isHistoryOpen,
                  onClose: _closeHistoryDrawer,
                  activeConversationId: chatCtrl.activeConversation?.id,
                  onSelectConversation: (conv) => chatCtrl.selectConversation(conv),
                  onNewConversation: () => chatCtrl.createNewConversation(),
                  onDeleteConversation: (convId) => chatCtrl.deleteConversation(convId),
                  conversations: chatCtrl.drawerConversations,
                  isLoading: chatCtrl.isLoadingConversations,
                  errorMessage: chatCtrl.conversationError,
                  onRetry: () => chatCtrl.loadConversations(),
                  isActionsDisabled: !chatCtrl.isConnected,
                  isSwitchingDisabled: chatCtrl.isGenerating,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DesktopChatController chatCtrl,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final statusColor = _statusColor(chatCtrl.connectionStatus, ext);
    final badgeColor = _modelBadgeColor(chatCtrl.modelStateCategory, ext);
    final badgeIcon = _modelBadgeIcon(chatCtrl.modelStateCategory);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      chatCtrl.activeConversation?.title ?? 'Chat',
                      style: CompanionTypography.titleLarge.copyWith(
                        color: ext?.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  NeumorphicButton(
                    size: NeumorphicButtonSize.sm,
                    icon: const Icon(Icons.history_rounded, size: 16),
                    tooltip: 'Conversation History (Ctrl+H)',
                    onPressed: _toggleHistoryDrawer,
                  ),
                  const SizedBox(width: CompanionSpacing.xs),
                  NeumorphicButton(
                    size: NeumorphicButtonSize.sm,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    tooltip: 'New Conversation',
                    onPressed: () => chatCtrl.createNewConversation(),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                'Conversational workspace',
                style: CompanionTypography.bodySmall.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: CompanionSpacing.md),
        // Model badge with truthful runtime telemetry
        if (chatCtrl.activeModelName != null || chatCtrl.modelStatus != null) ...[
          Tooltip(
            message: chatCtrl.modelStatusDescription,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CompanionSpacing.sm,
                vertical: CompanionSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: CompanionRadius.borderSm,
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badgeIcon,
                    size: 12,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    chatCtrl.modelStatusLabel,
                    style: CompanionTypography.caption.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: CompanionSpacing.sm),
        ],
        // Connection status pill
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CompanionSpacing.md,
            vertical: CompanionSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            borderRadius: CompanionRadius.borderFull,
            border: Border.all(
              color: ext?.borderSubtle ?? Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Text(
                chatCtrl.connectionStatusLabel,
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _modelBadgeColor(ModelRuntimeStateCategory category, CompanionThemeExtension? ext) {
    switch (category) {
      case ModelRuntimeStateCategory.modelReady:
        return ext?.success ?? CompanionColors.success;
      case ModelRuntimeStateCategory.modelSleeping:
        return const Color(0xFF38BDF8); // Sky blue
      case ModelRuntimeStateCategory.modelLoading:
        return ext?.warning ?? CompanionColors.warning;
      case ModelRuntimeStateCategory.modelSelectionRequired:
        return ext?.warning ?? CompanionColors.warning;
      case ModelRuntimeStateCategory.modelLoadFailed:
        return ext?.danger ?? CompanionColors.danger;
      case ModelRuntimeStateCategory.pairingRequired:
        return const Color(0xFFF97316); // Orange
      case ModelRuntimeStateCategory.modelUnloaded:
      case ModelRuntimeStateCategory.authenticatedNoModel:
      case ModelRuntimeStateCategory.unreachable:
        return ext?.textMuted ?? CompanionColors.lightTextMuted;
    }
  }

  IconData _modelBadgeIcon(ModelRuntimeStateCategory category) {
    switch (category) {
      case ModelRuntimeStateCategory.modelReady:
        return Icons.auto_awesome_rounded;
      case ModelRuntimeStateCategory.modelSleeping:
        return Icons.bedtime_rounded;
      case ModelRuntimeStateCategory.modelLoading:
        return Icons.hourglass_top_rounded;
      case ModelRuntimeStateCategory.modelSelectionRequired:
        return Icons.tune_rounded;
      case ModelRuntimeStateCategory.modelLoadFailed:
        return Icons.error_outline_rounded;
      case ModelRuntimeStateCategory.pairingRequired:
        return Icons.key_rounded;
      case ModelRuntimeStateCategory.modelUnloaded:
      case ModelRuntimeStateCategory.authenticatedNoModel:
      case ModelRuntimeStateCategory.unreachable:
        return Icons.memory_rounded;
    }
  }

  Color _statusColor(RuntimeConnectionStatus status, CompanionThemeExtension? ext) {
    switch (status) {
      case RuntimeConnectionStatus.connected:
        return ext?.success ?? CompanionColors.success;
      case RuntimeConnectionStatus.connecting:
      case RuntimeConnectionStatus.reconnecting:
        return ext?.warning ?? CompanionColors.warning;
      case RuntimeConnectionStatus.unauthorized:
      case RuntimeConnectionStatus.error:
        return ext?.danger ?? CompanionColors.danger;
      case RuntimeConnectionStatus.unconnected:
        return ext?.textMuted ?? CompanionColors.lightTextMuted;
    }
  }

  Widget _buildWelcomeStage(
    BuildContext context,
    CompanionThemeExtension? ext,
    DesktopChatController chatCtrl,
  ) {
    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 28,
                  color: ext?.accent ?? CompanionColors.lightAccent,
                ),
              ),
              const SizedBox(height: CompanionSpacing.lg),
              Text(
                'AI Companion Desktop',
                style: CompanionTypography.titleMedium.copyWith(
                  color: ext?.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CompanionSpacing.sm),
              Text(
                'Start a conversation with the local runtime below. '
                'Messages will stream live tokens and persist automatically.',
                style: CompanionTypography.bodyMedium.copyWith(
                  color: ext?.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (chatCtrl.modelStateCategory == ModelRuntimeStateCategory.modelSelectionRequired) ...[
                const SizedBox(height: CompanionSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(CompanionSpacing.md),
                  decoration: BoxDecoration(
                    color: (ext?.warning ?? CompanionColors.warning).withValues(alpha: 0.1),
                    borderRadius: CompanionRadius.borderMd,
                    border: Border.all(
                      color: (ext?.warning ?? CompanionColors.warning).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 18, color: ext?.warning ?? CompanionColors.warning),
                          const SizedBox(width: CompanionSpacing.xs),
                          Text(
                            'No Model Selected',
                            style: CompanionTypography.bodyMedium.copyWith(
                              color: ext?.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CompanionSpacing.xs),
                      Text(
                        'A local model must be selected before starting a conversation.',
                        style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.onNavigateToSettings != null) ...[
                        const SizedBox(height: CompanionSpacing.md),
                        FilledButton.tonalIcon(
                          onPressed: widget.onNavigateToSettings,
                          icon: const Icon(Icons.settings_rounded, size: 16),
                          label: const Text('Choose a Model in Settings'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    DesktopChatController chatCtrl,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    return SoftGlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: CompanionSpacing.lg,
        vertical: CompanionSpacing.md,
      ),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: chatCtrl.messages.length,
        itemBuilder: (context, index) {
          final msg = chatCtrl.messages[index];
          final isUser = msg.sender == 'user';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: CompanionSpacing.sm),
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: isUser
                    ? _buildUserBubble(context, msg, ext)
                    : _buildAssistantBubble(context, msg, ext, isDark),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _formatAttachmentSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildAttachmentCards(
    List<AttachmentRef> attachments,
    CompanionThemeExtension? ext, {
    required bool isUser,
  }) {
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: attachments.map((att) {
        final isImage = att.mimeType.startsWith('image/');
        return Container(
          margin: const EdgeInsets.only(bottom: CompanionSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: CompanionSpacing.md,
            vertical: CompanionSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: ext?.surfaceRecessed ?? Colors.black.withValues(alpha: 0.05),
            borderRadius: CompanionRadius.borderSm,
            border: Border.all(
              color: ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(CompanionRadius.sm),
                ),
                child: Icon(
                  isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                  size: 18,
                  color: ext?.accent ?? CompanionColors.lightAccent,
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      att.filenameDisplay,
                      style: CompanionTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ext?.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatAttachmentSize(att.sizeBytes),
                          style: CompanionTypography.caption.copyWith(
                            fontSize: 10.5,
                            color: ext?.textMuted,
                          ),
                        ),
                        const SizedBox(width: CompanionSpacing.xs),
                        Text(
                          '•',
                          style: TextStyle(color: ext?.textMuted, fontSize: 10),
                        ),
                        const SizedBox(width: CompanionSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: ext?.surfaceRecessed ?? Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Preview unavailable (Planned M2)',
                            style: CompanionTypography.caption.copyWith(
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                              color: ext?.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserBubble(BuildContext context, MessageOut msg, CompanionThemeExtension? ext) {
    return NeumorphicSurface(
      surfaceType: NeumorphicSurfaceType.raised,
      borderRadius: CompanionRadius.borderLg,
      padding: const EdgeInsets.symmetric(
        horizontal: CompanionSpacing.lg,
        vertical: CompanionSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (msg.attachments.isNotEmpty)
            _buildAttachmentCards(msg.attachments, ext, isUser: true),
          if (msg.content.isNotEmpty)
            AssistantMarkdownView(
              content: msg.content,
            ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(
    BuildContext context,
    MessageOut msg,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final isStreaming = msg.status == 'generating';
    final isCancelled = msg.status == 'cancelled';
    final isFailed = msg.status == 'failed';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 4, right: 10),
          decoration: BoxDecoration(
            color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.smart_toy_rounded,
            size: 18,
            color: ext?.accent ?? CompanionColors.lightAccent,
          ),
        ),
        Expanded(
          child: NeumorphicSurface(
            surfaceType: NeumorphicSurfaceType.glass,
            borderRadius: CompanionRadius.borderLg,
            padding: const EdgeInsets.symmetric(
              horizontal: CompanionSpacing.lg,
              vertical: CompanionSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CompanionSpacing.sm),
                    child: _buildAttachmentCards(msg.attachments, ext, isUser: false),
                  ),
                if (msg.content.isNotEmpty)
                  AssistantMarkdownView(
                    content: msg.content,
                  ),
                if (isStreaming) ...[
                  if (msg.content.isEmpty)
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ext?.accent ?? CompanionColors.lightAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thinking...',
                          style: CompanionTypography.bodySmall.copyWith(
                            color: ext?.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '●',
                        style: TextStyle(
                          color: ext?.accent ?? CompanionColors.lightAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
                if (isCancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '(Generation stopped)',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (isFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '(Generation failed)',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.danger ?? CompanionColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    String message,
    CompanionThemeExtension? ext,
  ) {
    final isSelectionError = message.contains('Settings') || message.contains('MODEL_SELECTION_REQUIRED');
    final bannerColor = isSelectionError
        ? (ext?.warning ?? CompanionColors.warning)
        : (ext?.danger ?? CompanionColors.danger);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CompanionSpacing.md,
        vertical: CompanionSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSelectionError ? Icons.tune_rounded : Icons.error_outline_rounded,
            size: 16,
            color: bannerColor,
          ),
          const SizedBox(width: CompanionSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: CompanionTypography.caption.copyWith(
                color: bannerColor,
              ),
            ),
          ),
          if (isSelectionError && widget.onNavigateToSettings != null) ...[
            const SizedBox(width: CompanionSpacing.sm),
            OutlinedButton.icon(
              onPressed: widget.onNavigateToSettings,
              icon: const Icon(Icons.settings_rounded, size: 14),
              label: const Text('Open Settings'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposerBar(
    BuildContext context,
    DesktopChatController chatCtrl,
    CompanionThemeExtension? ext,
  ) {
    final isBusy = chatCtrl.isGenerating ||
        chatCtrl.isAwaitingAcceptance ||
        chatCtrl.isCreatingConversation ||
        _isSubmitting;

    return NeumorphicSurface(
      surfaceType: NeumorphicSurfaceType.glassElevated,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const NeumorphicButton(
                size: NeumorphicButtonSize.sm,
                icon: Icon(Icons.attach_file_rounded),
                tooltip: 'Attach images or files (Planned M2)',
                onPressed: null,
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: NeumorphicSurface(
                  surfaceType: NeumorphicSurfaceType.recessed,
                  borderRadius: CompanionRadius.borderMd,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Message AI Companion... (Shift+Enter for newline)',
                      hintStyle: CompanionTypography.bodyMedium.copyWith(
                        color: ext?.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              const NeumorphicButton(
                size: NeumorphicButtonSize.sm,
                icon: Icon(Icons.mic_none_rounded),
                tooltip: 'Voice input (Planned M4)',
                onPressed: null,
              ),
              const SizedBox(width: CompanionSpacing.sm),
              if (isBusy)
                NeumorphicButton(
                  size: NeumorphicButtonSize.sm,
                  icon: const Icon(Icons.stop_rounded, color: Colors.amber),
                  tooltip: 'Stop generation (Esc)',
                  onPressed: () => chatCtrl.cancelGeneration(),
                )
              else
                NeumorphicButton(
                  size: NeumorphicButtonSize.sm,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  tooltip: 'Send message (Enter)',
                  onPressed: (_canSend && chatCtrl.canSend) ? _handleSend : null,
                ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CompanionSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Press Enter to send • Shift + Enter for newline',
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.textMuted,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: CompanionSpacing.sm),
                Text(
                  'Context buffer: ${chatCtrl.isConnected ? "Connected" : (chatCtrl.connectionStatus == RuntimeConnectionStatus.unauthorized ? "Unauthorized" : "Standalone")}',
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textMuted,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
