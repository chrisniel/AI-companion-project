import 'dart:async';

import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/chat/assistant_markdown_view.dart';
import '../features/chat/conversation_history_drawer.dart';
import '../features/chat/desktop_chat_controller.dart';
import '../features/tools/desktop_tool_policy_controller.dart';
import '../features/voice/desktop_voice_controller.dart';
import '../features/voice/live_voice_stage_panel.dart';
import '../features/voice/voice_shortcut_recorder.dart';
import '../platform/desktop_client_settings.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.controller,
    this.toolPolicyController,
    this.voiceController,
    this.clientSettings,
    this.isActiveTab = true,
    this.onRegisterCloseHistoryDrawer,
    this.onRegisterToggleHistoryDrawer,
    this.onNavigateToSettings,
  });

  final DesktopChatController? controller;
  final DesktopToolPolicyController? toolPolicyController;
  final DesktopVoiceController? voiceController;
  final DesktopClientSettings? clientSettings;
  final bool isActiveTab;
  final void Function(bool Function()? closer)? onRegisterCloseHistoryDrawer;
  final void Function(VoidCallback? toggleDrawer)? onRegisterToggleHistoryDrawer;
  final VoidCallback? onNavigateToSettings;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _textController;
  late final FocusNode _screenFocusNode;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  DesktopChatController? _internalController;
  DesktopClientSettings? _internalClientSettings;
  DesktopClientSettings get _effectiveClientSettings =>
      widget.clientSettings ?? (_internalClientSettings ??= DesktopClientSettings());

  double _zoomLevel = 1.0;
  bool _canSend = false;
  bool _isHistoryOpen = false;
  bool _isSubmitting = false;
  String? _currentConversationId;
  int _profileEpoch = 0;
  String? _restoredConversationId;
  bool _isRestorationScheduled = false;
  bool _userExplicitlySent = false;
  bool _wasGenerating = false;
  bool _pttHolding = false;
  final Set<String> _expandedSourcesMessageIds = <String>{};
  final Set<String> _resolvingConfirmationIds = <String>{};

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

  bool _closeHistoryDrawerIfOpen() {
    if (!_isHistoryOpen) return false;
    setState(() {
      _isHistoryOpen = false;
    });
    return true;
  }

  bool _isEditableTextFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _handleChatHardwareKey(KeyEvent event) {
    if (!mounted ||
        !widget.isActiveTab ||
        VoiceShortcutKeyMapper.isCaptureModalOpen) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }

    final hw = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        event is! KeyRepeatEvent &&
        hw.isControlPressed &&
        !hw.isAltPressed &&
        !hw.isShiftPressed &&
        !hw.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyH &&
          widget.onRegisterToggleHistoryDrawer == null) {
        _toggleHistoryDrawer();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.equal ||
          event.logicalKey == LogicalKeyboardKey.add ||
          event.logicalKey == LogicalKeyboardKey.numpadAdd) {
        _updateZoom(_zoomLevel + 0.1);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.minus ||
          event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
        _updateZoom(_zoomLevel - 0.1);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit0 ||
          event.logicalKey == LogicalKeyboardKey.numpad0) {
        _updateZoom(1.0);
        return true;
      }
    }

    final voiceCtrl = widget.voiceController;
    if (voiceCtrl == null) return false;

    if (event is KeyDownEvent &&
        event is! KeyRepeatEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        voiceCtrl.isLiveVoiceActive &&
        !_isEditableTextFocused()) {
      final hw = HardwareKeyboard.instance;
      if (!hw.isControlPressed &&
          !hw.isAltPressed &&
          !hw.isShiftPressed &&
          !hw.isMetaPressed) {
        unawaited(voiceCtrl.interruptBargeIn());
        return true;
      }
    }

    if (VoiceShortcutKeyMapper.matchesKeyEvent(
      event,
      voiceCtrl.shortcuts.pushToTalk,
    )) {
      if (event is KeyDownEvent && !_pttHolding) {
        _pttHolding = true;
        if (!voiceCtrl.isLiveVoiceActive &&
            !voiceCtrl.isDictating &&
            !voiceCtrl.isTranscribing) {
          unawaited(voiceCtrl.startDictation());
        }
        return true;
      } else if (event is KeyUpEvent && _pttHolding) {
        _pttHolding = false;
        if (voiceCtrl.isDictating) {
          unawaited(() async {
            final text = await voiceCtrl.stopDictationAndTranscribe();
            _insertDictatedText(text);
          }());
        } else if (voiceCtrl.isLiveVoiceActive) {
          unawaited(voiceCtrl.commitLiveUtterance());
        }
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadZoomLevel();
    if (widget.controller == null) {
      _internalController = DesktopChatController(
        client: CompanionClient(
          baseUrl: 'http://127.0.0.1:8000',
          credentialStore: InMemoryCredentialStore(),
        ),
      );
    }
    _textController = TextEditingController();
    _screenFocusNode = FocusNode(debugLabel: 'chat_screen_focus');
    _focusNode = FocusNode(onKeyEvent: _handleFocusKeyEvent);
    _scrollController = ScrollController();

    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _effectiveController.addListener(_onChatControllerChanged);
    _profileEpoch = _effectiveController.profileEpoch;
    _wasGenerating = _effectiveController.isGenerating;
    widget.onRegisterCloseHistoryDrawer?.call(_closeHistoryDrawerIfOpen);
    widget.onRegisterToggleHistoryDrawer?.call(_toggleHistoryDrawer);
    HardwareKeyboard.instance.addHandler(_handleChatHardwareKey);

    // Initialize current conversation state if already selected
    final activeId = _effectiveController.activeConversation?.id;
    if (activeId != null) {
      _currentConversationId = activeId;
      final draft = _effectiveController.getDraft(activeId);
      if (draft.isNotEmpty) {
        _textController.text = draft;
      }
    }

    // Initial load of conversation list if needed and scroll check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_effectiveController.conversations.isEmpty) {
        _effectiveController.loadConversations();
      }
      _checkAndRestoreScroll();
    });
  }

  Future<void> _loadZoomLevel() async {
    final zoom = await _effectiveClientSettings.readChatZoomLevel();
    if (mounted) {
      setState(() {
        _zoomLevel = zoom;
      });
    }
  }

  void _updateZoom(double newZoom) {
    final clamped = double.parse((newZoom.clamp(0.8, 1.6)).toStringAsFixed(2));
    if (clamped == _zoomLevel) return;
    setState(() {
      _zoomLevel = clamped;
    });
    _effectiveClientSettings.writeChatZoomLevel(clamped);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final isControl = HardwareKeyboard.instance.isControlPressed;
      if (isControl) {
        if (event.scrollDelta.dy < 0) {
          _updateZoom(_zoomLevel + 0.1);
        } else if (event.scrollDelta.dy > 0) {
          _updateZoom(_zoomLevel - 0.1);
        }
      }
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveTab && !widget.isActiveTab && _pttHolding) {
      _pttHolding = false;
      final vc = widget.voiceController;
      if (vc != null && vc.isDictating) {
        unawaited(() async {
          final text = await vc.stopDictationAndTranscribe();
          _insertDictatedText(text);
        }());
      } else if (vc != null && vc.isLiveVoiceActive) {
        unawaited(vc.commitLiveUtterance());
      }
    }
    if (oldWidget.onRegisterCloseHistoryDrawer != widget.onRegisterCloseHistoryDrawer) {
      oldWidget.onRegisterCloseHistoryDrawer?.call(null);
      widget.onRegisterCloseHistoryDrawer?.call(_closeHistoryDrawerIfOpen);
    }
    if (oldWidget.onRegisterToggleHistoryDrawer != widget.onRegisterToggleHistoryDrawer) {
      oldWidget.onRegisterToggleHistoryDrawer?.call(null);
      widget.onRegisterToggleHistoryDrawer?.call(_toggleHistoryDrawer);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onChatControllerChanged);
      widget.controller?.addListener(_onChatControllerChanged);
      _restoredConversationId = null;
      _isRestorationScheduled = false;
      _wasGenerating = _effectiveController.isGenerating;
    }
    _checkAndRestoreScroll();
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
    if (_profileEpoch != _effectiveController.profileEpoch) {
      _profileEpoch = _effectiveController.profileEpoch;
      _currentConversationId = null;
      _restoredConversationId = null;
      _isHistoryOpen = false;
      _isSubmitting = false;
      _textController.clear();
    }
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
      _restoredConversationId = null;
      _isRestorationScheduled = false;
      _userExplicitlySent = false;

      // 3. Restore draft for new conversation
      final draft = activeId != null ? _effectiveController.getDraft(activeId) : '';
      if (_textController.text != draft) {
        _textController.text = draft;
      }
    }

    _checkAndRestoreScroll();

    final isGeneratingNow = _effectiveController.isGenerating;
    final completedCleanly = _wasGenerating &&
        !isGeneratingNow &&
        _effectiveController.errorMessage == null;
    _wasGenerating = isGeneratingNow;

    if (completedCleanly && widget.voiceController != null) {
      MessageOut? latestAssistant;
      for (final msg in _effectiveController.messages.reversed) {
        if (msg.sender == 'assistant') {
          latestAssistant = msg;
          break;
        }
      }
      unawaited(
        widget.voiceController!.handleChatCompletionForAutoRead(latestAssistant),
      );
    }
  }

  void _insertDictatedText(String? transcribed) {
    final clean = transcribed?.trim();
    if (!mounted || clean == null || clean.isEmpty) return;
    final existing = _textController.text;
    final nextText = existing.trim().isEmpty
        ? clean
        : existing.endsWith(' ') || existing.endsWith('\n')
            ? '$existing$clean'
            : '$existing $clean';
    _textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  Future<void> _toggleDictation(DesktopVoiceController voiceCtrl) async {
    if (voiceCtrl.isDictating) {
      final text = await voiceCtrl.stopDictationAndTranscribe();
      _insertDictatedText(text);
    } else if (!voiceCtrl.isTranscribing) {
      await voiceCtrl.startDictation();
    }
  }

  void _checkAndRestoreScroll() {
    final activeId = _effectiveController.activeConversation?.id;
    if (activeId == null) return;
    if (_restoredConversationId == activeId) return;

    final messages = _effectiveController.messages;
    if (messages.isEmpty) return;

    if (_isRestorationScheduled) return;
    _isRestorationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isRestorationScheduled = false;
      if (!mounted) return;
      if (_effectiveController.activeConversation?.id != activeId) return;
      if (_restoredConversationId == activeId) return;

      if (!_scrollController.hasClients) {
        if (_effectiveController.messages.isNotEmpty) {
          _checkAndRestoreScroll();
        }
        return;
      }

      final savedOffset = _effectiveController.getScrollOffset(activeId);
      if (savedOffset != null) {
        _scrollController.jumpTo(
          savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      _restoredConversationId = activeId;
    });
  }

  @override
  void dispose() {
    widget.onRegisterCloseHistoryDrawer?.call(null);
    widget.onRegisterToggleHistoryDrawer?.call(null);
    HardwareKeyboard.instance.removeHandler(_handleChatHardwareKey);
    _textController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _effectiveController.removeListener(_onChatControllerChanged);
    _textController.dispose();
    _screenFocusNode.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final epoch = _effectiveController.profileEpoch;
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
          if (mounted && epoch == _effectiveController.profileEpoch) {
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
      if (mounted && epoch == _effectiveController.profileEpoch) {
        setState(() {
          _isSubmitting = false;
          _canSend = _textController.text.trim().isNotEmpty;
        });
      }
    }

    if (mounted && epoch == _effectiveController.profileEpoch) {
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
    _checkAndRestoreScroll();

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
            if (_isHistoryOpen)
              const SingleActivator(LogicalKeyboardKey.escape): _closeHistoryDrawer,
          },
          child: Focus(
            focusNode: _screenFocusNode,
            autofocus: true,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_focusNode.hasFocus) {
                  _screenFocusNode.requestFocus();
                }
              },
              child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(CompanionSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Bar
                      _buildHeader(context, chatCtrl, ext, isDark),
                      if (widget.voiceController != null)
                        ListenableBuilder(
                          listenable: widget.voiceController!,
                          builder: (context, _) {
                            final vc = widget.voiceController!;
                            if (!vc.isLiveVoiceActive) {
                              return const SizedBox.shrink();
                            }
                            return LiveVoiceStagePanel(
                              controller: vc,
                              companionName: chatCtrl.getConversationCharacterName(
                                chatCtrl.activeConversation,
                              ),
                            );
                          },
                        ),
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
                      if (widget.voiceController != null)
                        ListenableBuilder(
                          listenable: widget.voiceController!,
                          builder: (context, _) {
                            final vc = widget.voiceController!;
                            if (vc.isLiveVoiceActive || vc.errorMessage == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: CompanionSpacing.sm),
                              child: _buildVoiceErrorBanner(context, vc, ext),
                            );
                          },
                        ),

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
                  characterNameResolver: (conv) => chatCtrl.getConversationCharacterName(conv),
                  isActionsDisabled: !chatCtrl.isConnected,
                  isSwitchingDisabled: chatCtrl.isGenerating,
                ),
              ],
            ),
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
    final thisConvName = chatCtrl.getConversationCharacterName(chatCtrl.activeConversation);
    final thisConvMoodBadge = chatCtrl.getConversationCharacterMoodBadge(chatCtrl.activeConversation);
    final newConvName = chatCtrl.getActiveProfileCharacterName();
    final bool sameCharacter = (thisConvName == newConvName);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideHeader = constraints.maxWidth >= 900;
        final Widget compactIcon = chatCtrl.isCompacting
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.compress_rounded, size: 14);
        final List<Widget> compactionControls = [
          const SizedBox(width: CompanionSpacing.xs),
          Tooltip(
            message: 'Compact older conversation turns into a rolling episode digest.',
            child: OutlinedButton(
              key: const Key('compact_context_button'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(
                  horizontal: isWideHeader ? 8 : 6,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: (!chatCtrl.isGenerating &&
                      !chatCtrl.isCompacting &&
                      chatCtrl.messages.length >= 3)
                  ? () async {
                      final res = await chatCtrl.compactActiveConversation();
                      if (!context.mounted) return;
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger == null) return;
                      if (res == null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              chatCtrl.errorMessage ?? 'Could not compact context.',
                            ),
                          ),
                        );
                      } else if (res.compacted && res.summary != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Compacted turns ${res.summary!.fromSequenceNo}–${res.summary!.toSequenceNo} '
                              '(${res.summary!.compactedMessageCount} messages).',
                            ),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Conversation is already within the recent-turn window.',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
              child: isWideHeader
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        compactIcon,
                        const SizedBox(width: 4),
                        Text(
                          chatCtrl.isCompacting ? 'Compacting...' : 'Compact Context',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : compactIcon,
            ),
          ),
          if (chatCtrl.activeSummary != null) ...[
            const SizedBox(width: CompanionSpacing.sm),
            Tooltip(
              message:
                  'Inspect episode digest (${chatCtrl.activeSummary!.compactedMessageCount} messages, '
                  '~${chatCtrl.activeSummary!.tokenEstimate} tokens)',
              child: InkWell(
                key: const Key('episode_digest_badge'),
                borderRadius: CompanionRadius.borderSm,
                onTap: () => _showSummaryDialog(context, chatCtrl.activeSummary!, ext),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CompanionSpacing.sm,
                    vertical: CompanionSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.12),
                    borderRadius: CompanionRadius.borderSm,
                    border: Border.all(
                      color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.summarize_outlined,
                        size: 12,
                        color: ext?.accent ?? CompanionColors.lightAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Digest: Turns ${chatCtrl.activeSummary!.fromSequenceNo}–${chatCtrl.activeSummary!.toSequenceNo}',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.accent ?? CompanionColors.lightAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ];

        final Widget connectionPill = Container(
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
        );

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
                  if (chatCtrl.activeConversation != null) ...compactionControls,
                ],
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: CompanionSpacing.sm,
                runSpacing: 4,
                children: [
                  Text(
                    'Conversational workspace',
                    style: CompanionTypography.bodySmall.copyWith(
                      color: ext?.textSecondary,
                    ),
                  ),
                  if (chatCtrl.authenticatedProfileName != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: CompanionRadius.borderSm,
                          border: Border.all(
                            color: ext?.borderSubtle ?? Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: ext?.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Profile: ${chatCtrl.authenticatedProfileName}',
                                style: CompanionTypography.caption.copyWith(
                                  color: ext?.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.1),
                        borderRadius: CompanionRadius.borderSm,
                        border: Border.all(
                          color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.face_rounded,
                            size: 12,
                            color: ext?.accent ?? CompanionColors.lightAccent,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'This Conversation: $thisConvName',
                              style: CompanionTypography.caption.copyWith(
                                color: ext?.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (thisConvMoodBadge != null)
                    Container(
                      key: const Key('chat-header-mood-badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: CompanionRadius.borderSm,
                        border: Border.all(
                          color: ext?.borderSubtle ?? Colors.transparent,
                        ),
                      ),
                      child: Text(
                        'Mood: $thisConvMoodBadge',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (!sameCharacter)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: CompanionRadius.borderSm,
                          border: Border.all(
                            color: ext?.borderSubtle ?? Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 12,
                              color: ext?.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'New Conversations: $newConvName',
                                style: CompanionTypography.caption.copyWith(
                                  color: ext?.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
        if ((_zoomLevel - 1.0).abs() > 0.01) ...[
          Tooltip(
            message: 'Conversation zoom level (${(_zoomLevel * 100).round()}%). Click or Ctrl+0 to reset.',
            child: InkWell(
              borderRadius: CompanionRadius.borderSm,
              onTap: () => _updateZoom(1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CompanionSpacing.sm,
                  vertical: CompanionSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: CompanionRadius.borderSm,
                  border: Border.all(
                    color: ext?.borderSubtle ?? Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.zoom_in_rounded,
                      size: 12,
                      color: ext?.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(_zoomLevel * 100).round()}%',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: CompanionSpacing.sm),
        ],
        if (widget.voiceController != null) ...[
          ListenableBuilder(
            listenable: widget.voiceController!,
            builder: (context, _) {
              final vc = widget.voiceController!;
              final isLive = vc.isLiveVoiceActive;
              final autoRead = vc.voiceSettings?.autoReadReplies ?? false;
              final showVoiceLabels = constraints.maxWidth >= 1060;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeumorphicButton(
                    key: const Key('chat_voice_mode_toggle'),
                    size: NeumorphicButtonSize.sm,
                    selected: isLive,
                    accentOnSelected: false,
                    icon: Icon(
                      isLive
                          ? Icons.call_end_rounded
                          : Icons.record_voice_over_rounded,
                      size: 16,
                      color: isLive
                          ? (ext?.danger ?? CompanionColors.danger)
                          : null,
                    ),
                    tooltip: isLive
                        ? 'End Live Voice (${vc.shortcuts.inAppToggle.label})'
                        : 'Start Live Voice (${vc.shortcuts.inAppToggle.label})',
                    onPressed: isLive ? vc.stopLiveVoice : vc.startLiveVoice,
                    child: showVoiceLabels
                        ? Text(
                            isLive ? 'End Voice' : 'Live Voice',
                            style: TextStyle(
                              color: isLive
                                  ? (ext?.danger ?? CompanionColors.danger)
                                  : null,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: CompanionSpacing.xs),
                  NeumorphicButton(
                    key: const Key('chat_auto_read_toggle'),
                    size: NeumorphicButtonSize.sm,
                    selected: autoRead,
                    icon: Icon(
                      autoRead
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      size: 16,
                      color: autoRead ? ext?.accent : null,
                    ),
                    tooltip: autoRead
                        ? 'Auto-Read replies enabled (click to disable)'
                        : 'Enable Auto-Read replies',
                    onPressed: vc.voiceSettings == null || vc.isSaving
                        ? null
                        : () => vc.updateBackendSettings(
                              VoiceSettingsUpdate(autoReadReplies: !autoRead),
                            ),
                    child: showVoiceLabels ? const Text('Auto-Read') : null,
                  ),
                  const SizedBox(width: CompanionSpacing.xs),
                  NeumorphicButton(
                    key: const Key('chat_header_mute_toggle'),
                    size: NeumorphicButtonSize.sm,
                    selected: vc.isAudioMuted,
                    icon: Icon(
                      vc.isAudioMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_none_rounded,
                      size: 16,
                      color: vc.isAudioMuted
                          ? (ext?.warning ?? CompanionColors.warning)
                          : null,
                    ),
                    tooltip: vc.isAudioMuted
                        ? 'Unmute mic & audio (${vc.shortcuts.muteToggle.label})'
                        : 'Mute mic & audio (${vc.shortcuts.muteToggle.label})',
                    onPressed: () => vc.setMuted(!vc.isAudioMuted),
                    child: (showVoiceLabels && vc.isAudioMuted)
                        ? const Text('Muted')
                        : null,
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: CompanionSpacing.sm),
        ],
        connectionPill,
          ],
        );
      },
    );
  }

  void _showSummaryDialog(
    BuildContext context,
    ConversationSummaryOut summary,
    CompanionThemeExtension? ext,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.summarize_outlined,
                size: 20,
                color: ext?.accent ?? CompanionColors.lightAccent,
              ),
              const SizedBox(width: 8),
              const Text('Episode Digest'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    summary.summaryText,
                    style: CompanionTypography.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Turns ${summary.fromSequenceNo}–${summary.toSequenceNo} • '
                    '${summary.compactedMessageCount} messages • '
                    '~${summary.tokenEstimate} tokens • Source: ${summary.source}',
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
    final thisConvName = chatCtrl.getConversationCharacterName(chatCtrl.activeConversation);
    final thisConvMoodBadge = chatCtrl.getConversationCharacterMoodBadge(chatCtrl.activeConversation);
    final newConvName = chatCtrl.getActiveProfileCharacterName();
    final bool sameCharacter = (thisConvName == newConvName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
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
              const SizedBox(height: CompanionSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CompanionSpacing.md,
                  vertical: CompanionSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: CompanionRadius.borderMd,
                  border: Border.all(
                    color: ext?.borderSubtle ?? Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.face_rounded,
                          size: 14,
                          color: ext?.accent ?? CompanionColors.lightAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Character: $thisConvName',
                          style: CompanionTypography.bodySmall.copyWith(
                            color: ext?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (thisConvMoodBadge != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Current Mood: $thisConvMoodBadge',
                        key: const Key('chat-welcome-mood-badge'),
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (!sameCharacter) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Profile active Character for new chats: $newConvName',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
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
    ),
  );
  }

  Widget _buildMessageList(
    BuildContext context,
    DesktopChatController chatCtrl,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_zoomLevel),
        ),
        child: SoftGlassPanel(
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
        ),
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

  Widget _buildBookmarkMenu(
    BuildContext context,
    MessageOut msg,
    CompanionThemeExtension? ext,
  ) {
    return PopupMenuButton<String>(
      key: Key('bookmark_message_${msg.id}'),
      tooltip: 'Bookmark to Memory',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      iconSize: 16,
      icon: Icon(
        Icons.bookmark_add_outlined,
        size: 16,
        color: ext?.textMuted ?? CompanionColors.lightTextMuted,
      ),
      onSelected: (value) async {
        final asKnowledge = value == 'knowledge';
        final saved = await _effectiveController.bookmarkMessageToMemory(
          msg.content,
          asKnowledge: asKnowledge,
        );
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? (asKnowledge
                      ? 'Pinned to Fixed Knowledge.'
                      : 'Saved to Long-Term Memory.')
                  : (_effectiveController.errorMessage ?? 'Could not save bookmark.'),
            ),
          ),
        );
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'long_term',
          child: Text('Save to Long-Term Memory'),
        ),
        PopupMenuItem<String>(
          value: 'knowledge',
          child: Text('Pin to Fixed Knowledge'),
        ),
      ],
    );
  }

  Widget _buildUserBubble(BuildContext context, MessageOut msg, CompanionThemeExtension? ext) {
    final canBookmark = msg.status == 'completed' && msg.content.trim().isNotEmpty;
    final bubble = NeumorphicSurface(
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
    if (!canBookmark) return bubble;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        Positioned(
          top: 2,
          right: 4,
          child: SizedBox(
            width: 24,
            height: 24,
            child: _buildBookmarkMenu(context, msg, ext),
          ),
        ),
      ],
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

    final canBookmark = msg.status == 'completed' && msg.content.trim().isNotEmpty;
    final bubble = NeumorphicSurface(
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
                if (isStreaming && _effectiveController.activeToolStatus != null) ...[
                  const SizedBox(height: CompanionSpacing.xs),
                  _buildToolProgressChip(_effectiveController.activeToolStatus!, ext),
                ],
                if (msg.toolReceipts.isNotEmpty)
                  _buildToolReceiptsStrip(msg, ext, isDark),
                if (msg.sources.isNotEmpty) ...[
                  const SizedBox(height: CompanionSpacing.sm),
                  _buildSourcesStrip(msg, ext),
                ],
                if (msg.pendingConfirmations.isNotEmpty) ...[
                  const SizedBox(height: CompanionSpacing.sm),
                  _buildPendingConfirmations(msg, ext),
                ],
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
                if (msg.status == 'length')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (ext?.warning ?? CompanionColors.warning).withValues(alpha: 0.12),
                        borderRadius: CompanionRadius.borderSm,
                        border: Border.all(
                          color: (ext?.warning ?? CompanionColors.warning).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: ext?.warning ?? CompanionColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Response reached generation limit',
                                style: CompanionTypography.bodySmall.copyWith(
                                  color: ext?.warning ?? CompanionColors.warning,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          FilledButton.tonalIcon(
                            key: const Key('continue_response_button'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                            label: const Text('Continue response', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              _effectiveController.sendMessage('Continue');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                if (msg.status == 'interrupted')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '(Generation interrupted)',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.danger ?? CompanionColors.danger,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (widget.voiceController != null &&
                    !isStreaming &&
                    (msg.status == 'completed' || msg.status == 'length') &&
                    msg.content.trim().isNotEmpty) ...[
                  const SizedBox(height: CompanionSpacing.xs),
                  ListenableBuilder(
                    listenable: widget.voiceController!,
                    builder: (context, _) {
                      final vc = widget.voiceController!;
                      final isSpeakingThis = vc.speakingMessageId == msg.id;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            key: Key('message_speak_${msg.id}'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              isSpeakingThis
                                  ? Icons.stop_rounded
                                  : Icons.volume_up_rounded,
                              size: 14,
                            ),
                            label: Text(
                              isSpeakingThis ? 'Stop' : 'Read Aloud',
                              style: CompanionTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: isSpeakingThis
                                ? vc.stopSpeaking
                                : () => vc.speakMessage(
                                      messageId: msg.id,
                                      text: msg.content,
                                    ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
    );

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
          child: canBookmark
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    bubble,
                    Positioned(
                      top: 2,
                      right: 4,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: _buildBookmarkMenu(context, msg, ext),
                      ),
                    ),
                  ],
                )
              : bubble,
        ),
      ],
    );
  }

  Widget _buildToolProgressChip(String statusText, CompanionThemeExtension? ext) {
    return Container(
      key: const Key('chat_live_tool_status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.10),
        borderRadius: CompanionRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: ext?.accent ?? CompanionColors.lightAccent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: CompanionTypography.caption.copyWith(
              color: ext?.accent ?? CompanionColors.lightAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolReceiptsStrip(
    MessageOut msg,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final cards = <Widget>[];
    for (final r in msg.toolReceipts) {
      final isBlocked = r.outcomeStatus == 'killed' ||
          r.decision == 'DENY' ||
          r.outcomeStatus == 'denied' ||
          r.outcomeStatus == 'rejected_by_user' ||
          r.outcomeStatus == 'failed';
      if (isBlocked) {
        cards.add(_buildBlockedToolCard(r, ext));
        continue;
      }
      if (r.outcomeStatus == 'pending_confirmation') {
        if (msg.pendingConfirmations.isEmpty) {
          cards.add(_buildBlockedToolCard(r, ext, isWarning: true));
        }
        continue;
      }
      if (r.toolName == 'weather_lookup') {
        cards.add(_buildWeatherWidgetCard(r, ext, isDark));
        continue;
      }
      if (r.toolName == 'web_search' || r.toolName == 'web_fetch') {
        // Executed web tools surface cleanly via the collapsible Sources strip below.
        continue;
      }
      cards.add(_buildAssistantActionCard(r, ext, isDark));
    }
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: CompanionSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: CompanionSpacing.xs),
            cards[i],
          ],
        ],
      ),
    );
  }

  ({IconData icon, Color color}) _weatherVisualForCondition(
    String condition,
    CompanionThemeExtension? ext,
  ) {
    final low = condition.toLowerCase();
    if (low.contains('thunder') || low.contains('storm')) {
      return (icon: Icons.thunderstorm_rounded, color: Colors.amberAccent);
    }
    if (low.contains('drizzle') || low.contains('rain') || low.contains('shower')) {
      return (icon: Icons.water_drop_rounded, color: Colors.lightBlueAccent);
    }
    if (low.contains('partly')) {
      return (icon: Icons.wb_cloudy_rounded, color: ext?.accent ?? CompanionColors.lightAccent);
    }
    if (low.contains('overcast') || low.contains('cloud') || low.contains('fog')) {
      return (icon: Icons.cloud_rounded, color: ext?.textSecondary ?? Colors.blueGrey);
    }
    return (icon: Icons.wb_sunny_rounded, color: Colors.orangeAccent);
  }

  String _formatShortDateLabel(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    final now = DateTime.now();
    if (parsed.year == now.year && parsed.month == now.month && parsed.day == now.day) {
      return 'Today';
    }
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[parsed.weekday - 1]}, ${months[parsed.month - 1]} ${parsed.day}';
  }

  Widget _buildWeatherWidgetCard(
    ToolReceiptOut receipt,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final summary = receipt.summary;
    final headerMatch = RegExp(
      r'^Weather in ([^:]+):\s*([^,]+),\s*([-\d.]+)\s*°?C(?:\s*now)?\.',
    ).firstMatch(summary);
    final location = headerMatch?.group(1)?.trim();
    final nowCondition = headerMatch?.group(2)?.trim() ?? '';
    final nowTemp = headerMatch?.group(3)?.trim();

    final dayMatches = RegExp(
      r'(\d{4}-\d{2}-\d{2}):\s*([^(]+?)\s*\(([-\d.]+)\s*[–\-]\s*([-\d.]+)\s*°?C,\s*rain\s*(\d+)%\)',
    ).allMatches(summary).toList();

    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = ext?.borderSubtle ?? (isDark ? Colors.white12 : Colors.black12);
    final visual = _weatherVisualForCondition(nowCondition, ext);

    return Container(
      key: const Key('weather_widget_card'),
      padding: const EdgeInsets.all(CompanionSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (location != null && nowTemp != null) ...[
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.16),
                    borderRadius: CompanionRadius.borderSm,
                  ),
                  child: Icon(visual.icon, size: 18, color: visual.color),
                ),
                const SizedBox(width: CompanionSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location,
                        style: CompanionTypography.bodySmall.copyWith(
                          color: ext?.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        nowCondition,
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.14),
                    borderRadius: CompanionRadius.borderFull,
                  ),
                  child: Text(
                    '$nowTemp°C',
                    style: CompanionTypography.bodySmall.copyWith(
                      color: ext?.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (dayMatches.isNotEmpty) ...[
              const SizedBox(height: CompanionSpacing.sm),
              _WeatherForecastScrollStrip(
                key: const Key('weather_forecast_scroll_strip'),
                children: [
                  for (var i = 0; i < dayMatches.length; i++) ...[
                    if (i > 0) const SizedBox(width: CompanionSpacing.xs),
                    _buildWeatherDayTile(dayMatches[i], ext, isDark),
                  ],
                ],
              ),
            ],
          ] else
            Text(
              summary,
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherDayTile(
    RegExpMatch match,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final dateIso = match.group(1) ?? '';
    final cond = (match.group(2) ?? '').trim();
    final minT = match.group(3) ?? '';
    final maxT = match.group(4) ?? '';
    final rainPct = match.group(5) ?? '0';
    final label = _formatShortDateLabel(dateIso);
    final isToday = label == 'Today';
    final visual = _weatherVisualForCondition(cond, ext);
    final accent = ext?.accent ?? CompanionColors.lightAccent;

    return Container(
      width: 114,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isToday
            ? accent.withValues(alpha: 0.10)
            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
        borderRadius: CompanionRadius.borderSm,
        border: Border.all(
          color: isToday
              ? accent.withValues(alpha: 0.45)
              : (ext?.borderSubtle ?? Colors.transparent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: CompanionTypography.caption.copyWith(
              color: isToday ? accent : ext?.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(visual.icon, size: 15, color: visual.color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$minT°–$maxT°',
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            cond,
            style: CompanionTypography.caption.copyWith(
              color: ext?.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.water_drop_outlined,
                size: 11,
                color: Colors.lightBlueAccent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 2),
              Text(
                '$rainPct%',
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantActionCard(
    ToolReceiptOut receipt,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final (IconData icon, String title) = switch (receipt.toolName) {
      'create_reminder' => (Icons.alarm_add_rounded, 'Reminder Set'),
      'list_reminders' => (Icons.event_note_rounded, 'Reminders Checked'),
      'delete_reminder' => (Icons.event_busy_rounded, 'Reminder Removed'),
      'create_task' => (Icons.task_alt_rounded, 'Task Added'),
      'update_task' => (Icons.check_circle_outline_rounded, 'Task Updated'),
      'list_tasks' => (Icons.checklist_rounded, 'Tasks Checked'),
      'delete_task' => (Icons.delete_outline_rounded, 'Task Removed'),
      'create_alarm' => (Icons.alarm_rounded, 'Alarm Set'),
      'list_alarms' => (Icons.access_alarms_rounded, 'Alarms Checked'),
      'delete_alarm' => (Icons.alarm_off_rounded, 'Alarm Removed'),
      'search_memories' => (Icons.psychology_alt_rounded, 'Memories Checked'),
      _ => (Icons.auto_awesome_rounded, 'Assistant Action'),
    };
    final accent = ext?.accent ?? CompanionColors.lightAccent;
    return Container(
      key: Key('assistant_action_card_${receipt.toolName}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.025),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: CompanionRadius.borderSm,
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: CompanionSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  receipt.summary,
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedToolCard(
    ToolReceiptOut receipt,
    CompanionThemeExtension? ext, {
    bool isWarning = false,
  }) {
    final color = isWarning
        ? (ext?.warning ?? CompanionColors.warning)
        : (ext?.danger ?? CompanionColors.danger);
    final label = switch (receipt.outcomeStatus) {
      'killed' => 'Actions Paused',
      'denied' => 'Action Blocked',
      'rejected_by_user' => 'Action Cancelled',
      'failed' => 'Action Failed',
      'pending_confirmation' => 'Awaiting Confirmation',
      _ => 'Notice',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: CompanionRadius.borderSm,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.hourglass_bottom_rounded : Icons.shield_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: CompanionTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  receipt.summary,
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displaySourceUrl(WebSourceRefOut src) {
    final parsed = Uri.tryParse(src.url);
    if (parsed == null || parsed.host.isEmpty) return src.domain;
    final path = parsed.path;
    if (path.isEmpty || path == '/') return src.domain;
    return '${src.domain}$path';
  }

  Widget _buildSourcesStrip(MessageOut msg, CompanionThemeExtension? ext) {
    final expanded = _expandedSourcesMessageIds.contains(msg.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: Key('sources_toggle_${msg.id}'),
          borderRadius: CompanionRadius.borderSm,
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedSourcesMessageIds.remove(msg.id);
              } else {
                _expandedSourcesMessageIds.add(msg.id);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (ext?.textMuted ?? CompanionColors.lightTextMuted)
                  .withValues(alpha: 0.10),
              borderRadius: CompanionRadius.borderSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.public_rounded, size: 14, color: ext?.accent),
                const SizedBox(width: 6),
                Text(
                  'Sources (${msg.sources.length})',
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 16,
                  color: ext?.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: CompanionSpacing.xs),
          ...msg.sources.map((src) {
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (ext?.textMuted ?? CompanionColors.lightTextMuted)
                    .withValues(alpha: 0.06),
                borderRadius: CompanionRadius.borderSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          src.title,
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _displaySourceUrl(src),
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy source URL',
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: src.url));
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildPendingConfirmations(
    MessageOut msg,
    CompanionThemeExtension? ext,
  ) {
    final policyCtrl = widget.toolPolicyController;
    Widget buildCards(bool killed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: msg.pendingConfirmations.map((conf) {
          final isBusy = _resolvingConfirmationIds.contains(conf.id);
          return Container(
            key: Key('confirmation_card_${conf.id}'),
            margin: const EdgeInsets.only(bottom: CompanionSpacing.xs),
            padding: const EdgeInsets.all(CompanionSpacing.sm),
            decoration: BoxDecoration(
              color: (ext?.warning ?? CompanionColors.warning).withValues(alpha: 0.10),
              borderRadius: CompanionRadius.borderSm,
              border: Border.all(
                color: (ext?.warning ?? CompanionColors.warning).withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm Risk ${conf.riskTier}: ${conf.toolName}',
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.warning ?? CompanionColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target: ${conf.targetSummary}',
                  style: CompanionTypography.bodySmall.copyWith(color: ext?.textPrimary),
                ),
                if (killed) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Approve disabled: Global Kill Switch is active.',
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.danger ?? CompanionColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: CompanionSpacing.xs),
                Row(
                  children: [
                    FilledButton(
                      key: Key('confirm_approve_${conf.id}'),
                      onPressed: isBusy || killed
                          ? null
                          : () async {
                              setState(() => _resolvingConfirmationIds.add(conf.id));
                              try {
                                await _effectiveController.resolveConfirmation(conf.id, 'approve');
                              } finally {
                                if (mounted) {
                                  setState(() => _resolvingConfirmationIds.remove(conf.id));
                                }
                              }
                            },
                      child: const Text('Approve'),
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    OutlinedButton(
                      key: Key('confirm_reject_${conf.id}'),
                      onPressed: isBusy
                          ? null
                          : () async {
                              setState(() => _resolvingConfirmationIds.add(conf.id));
                              try {
                                await _effectiveController.resolveConfirmation(conf.id, 'reject');
                              } finally {
                                if (mounted) {
                                  setState(() => _resolvingConfirmationIds.remove(conf.id));
                                }
                              }
                            },
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (policyCtrl == null) {
      return buildCards(false);
    }
    return ListenableBuilder(
      listenable: policyCtrl,
      builder: (_, __) => buildCards(policyCtrl.globalKillSwitch),
    );
  }

  Widget _buildVoiceErrorBanner(
    BuildContext context,
    DesktopVoiceController vc,
    CompanionThemeExtension? ext,
  ) {
    final bannerColor = vc.isAudioMuted
        ? (ext?.warning ?? CompanionColors.warning)
        : (ext?.danger ?? CompanionColors.danger);
    return Container(
      key: const Key('chat_voice_error_banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: CompanionSpacing.md,
        vertical: CompanionSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(color: bannerColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            vc.isAudioMuted ? Icons.mic_off_rounded : Icons.error_outline_rounded,
            size: 16,
            color: bannerColor,
          ),
          const SizedBox(width: CompanionSpacing.sm),
          Expanded(
            child: Text(
              vc.errorMessage ?? '',
              style: CompanionTypography.bodySmall.copyWith(color: ext?.textPrimary),
            ),
          ),
          if (vc.isAudioMuted) ...[
            const SizedBox(width: CompanionSpacing.sm),
            TextButton(
              key: const Key('chat_voice_error_unmute'),
              onPressed: () => unawaited(vc.setMuted(false)),
              child: const Text('Unmute'),
            ),
          ],
          IconButton(
            tooltip: 'Dismiss voice notice',
            icon: Icon(Icons.close_rounded, size: 16, color: ext?.textSecondary),
            onPressed: vc.clearError,
          ),
        ],
      ),
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
              if (widget.voiceController != null)
                ListenableBuilder(
                  listenable: widget.voiceController!,
                  builder: (context, _) {
                    final vc = widget.voiceController!;
                    final dictating = vc.isDictating;
                    final transcribing = vc.isTranscribing;
                    return NeumorphicButton(
                      key: const Key('chat_dictate_button'),
                      size: NeumorphicButtonSize.sm,
                      selected: dictating,
                      accentOnSelected: false,
                      icon: transcribing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              dictating
                                  ? Icons.stop_circle_rounded
                                  : Icons.mic_none_rounded,
                              color: dictating
                                  ? (ext?.danger ?? CompanionColors.danger)
                                  : null,
                            ),
                      tooltip: dictating
                          ? 'Stop dictation & transcribe into message'
                          : transcribing
                              ? 'Transcribing speech...'
                              : 'Dictate message (speech to text)',
                      onPressed: transcribing ? null : () => _toggleDictation(vc),
                    );
                  },
                )
              else
                const NeumorphicButton(
                  key: Key('chat_dictate_button'),
                  size: NeumorphicButtonSize.sm,
                  icon: Icon(Icons.mic_none_rounded),
                  tooltip: 'Dictation unavailable (voice controller disconnected)',
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

class _WeatherForecastScrollStrip extends StatefulWidget {
  const _WeatherForecastScrollStrip({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  State<_WeatherForecastScrollStrip> createState() =>
      _WeatherForecastScrollStripState();
}

class _WeatherForecastScrollStripState
    extends State<_WeatherForecastScrollStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) {
      return;
    }
    final pos = _scrollController.position;
    final delta = event.scrollDelta.dx != 0
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (pos.maxScrollExtent <= 0 || delta == 0) {
      return;
    }
    final target = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
    if ((target - pos.pixels).abs() <= 0.5) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
            scrollbars: false,
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: widget.children),
          ),
        ),
      ),
    );
  }
}
