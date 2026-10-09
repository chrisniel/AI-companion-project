import 'dart:ui';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop drawer overlay for listing, searching, switching, and deleting conversation threads.
///
/// Follows the established AI Companion Web ConversationHistoryDrawer design identity:
/// Neumorphism + Glassmorphism + Minimalism with backdrop blur scrim and keyboard navigation.
class ConversationHistoryDrawer extends StatefulWidget {
  const ConversationHistoryDrawer({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.activeConversationId,
    required this.onSelectConversation,
    required this.onNewConversation,
    this.onDeleteConversation,
    this.conversations = const [],
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.isActionsDisabled = false,
    this.isSwitchingDisabled = false,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final String? activeConversationId;
  final ValueChanged<ConversationOut> onSelectConversation;
  final VoidCallback onNewConversation;
  final Future<void> Function(String conversationId)? onDeleteConversation;
  final List<ConversationOut> conversations;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isActionsDisabled;
  final bool isSwitchingDisabled;

  @override
  State<ConversationHistoryDrawer> createState() => _ConversationHistoryDrawerState();
}

class _ConversationHistoryDrawerState extends State<ConversationHistoryDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _formatDate(String isoString) {
    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return isoString;
    final local = parsed.toLocal();
    final now = DateTime.now();

    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final isYesterday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day - 1;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Today, $hour:$minute';
    } else if (isYesterday) {
      return 'Yesterday, $hour:$minute';
    }
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) {
      return const SizedBox.shrink();
    }

    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = widget.conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.title.toLowerCase().contains(_searchQuery);
    }).toList();

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            // Backdrop Scrim with Blur
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 180),
                  builder: (context, val, child) {
                    return BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4.0 * val, sigmaY: 4.0 * val),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35 * val),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Left Drawer Panel
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 360,
              child: Container(
                decoration: BoxDecoration(
                  color: ext?.surfaceGlass ??
                      (isDark ? CompanionColors.darkSurfaceGlass : CompanionColors.lightSurfaceGlass),
                  border: Border(
                    right: BorderSide(
                      color: ext?.surfaceGlassBorder ??
                          (isDark
                              ? CompanionColors.darkSurfaceGlassBorder
                              : CompanionColors.lightSurfaceGlassBorder),
                      width: 1.0,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                      blurRadius: 28,
                      offset: const Offset(6, 0),
                    ),
                  ],
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: ext?.glassBlur ?? CompanionColors.glassBlur,
                      sigmaY: ext?.glassBlur ?? CompanionColors.glassBlur,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        _buildHeader(context, ext, isDark),

                        // Action and Search
                        _buildActionAndSearch(context, ext, isDark),

                        // Conversation List
                        Expanded(
                          child: _buildConversationList(context, filtered, ext, isDark),
                        ),

                        // Footer
                        _buildFooter(context, ext),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: CompanionSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ext?.borderSubtle ?? Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.15),
                    borderRadius: CompanionRadius.borderSm,
                    border: Border.all(
                      color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: ext?.accent ?? CompanionColors.lightAccent,
                  ),
                ),
                const SizedBox(width: CompanionSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conversation History',
                        style: CompanionTypography.titleMedium.copyWith(
                          color: ext?.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.conversations.length} Local Sessions',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textMuted,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: CompanionSpacing.xs),
          NeumorphicButton(
            size: NeumorphicButtonSize.sm,
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Close (Esc)',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildActionAndSearch(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(CompanionSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ext?.borderSubtle ?? Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: NeumorphicButton(
              size: NeumorphicButtonSize.md,
              icon: const Icon(Icons.add_rounded, size: 16),
              tooltip: 'Start a new conversation',
              onPressed: widget.isActionsDisabled
                  ? null
                  : () {
                      widget.onNewConversation();
                      widget.onClose();
                    },
              child: const Text('New Conversation'),
            ),
          ),
          const SizedBox(height: CompanionSpacing.sm),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: ext?.surfaceRecessed ??
                  (isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.5)),
              borderRadius: CompanionRadius.borderSm,
              border: Border.all(
                color: ext?.borderSubtle ?? Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textPrimary,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'Search past conversations...',
                hintStyle: CompanionTypography.bodySmall.copyWith(
                  color: ext?.textMuted,
                  fontSize: 12,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: ext?.textMuted,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: CompanionSpacing.sm,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    List<ConversationOut> items,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    if (widget.isLoading && items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(ext?.accent ?? CompanionColors.lightAccent),
        ),
      );
    }

    if (widget.errorMessage != null && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CompanionSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: ext?.textMuted,
              ),
              const SizedBox(height: CompanionSpacing.sm),
              Text(
                widget.errorMessage!,
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: CompanionSpacing.sm),
                NeumorphicButton(
                  size: NeumorphicButtonSize.sm,
                  onPressed: widget.onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CompanionSpacing.lg),
          child: Text(
            _searchQuery.isNotEmpty
                ? 'No conversations found matching "$_searchQuery"'
                : 'No conversations yet',
            style: CompanionTypography.caption.copyWith(
              color: ext?.textMuted,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(CompanionSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: CompanionSpacing.sm),
      itemBuilder: (context, index) {
        final conv = items[index];
        final isActive = conv.id == widget.activeConversationId;
        final isSwitchingBlocked = widget.isSwitchingDisabled || widget.isActionsDisabled;

        final cardBg = isActive
            ? (ext?.surfaceElevated ??
                (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04)))
            : (ext?.surfaceRecessed ??
                (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)));

        final cardBorderColor = isActive
            ? (ext?.accent ?? CompanionColors.lightAccent)
            : (ext?.borderSubtle ?? Colors.white.withValues(alpha: 0.08));

        return Opacity(
          opacity: isSwitchingBlocked ? 0.5 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSwitchingBlocked
                  ? null
                  : () {
                      widget.onSelectConversation(conv);
                      widget.onClose();
                    },
              borderRadius: CompanionRadius.borderMd,
              child: Container(
                padding: const EdgeInsets.all(CompanionSpacing.sm),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: CompanionRadius.borderMd,
                  border: Border.all(
                    color: cardBorderColor,
                    width: isActive ? 1.5 : 1.0,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            conv.title,
                            style: CompanionTypography.bodySmall.copyWith(
                              color: ext?.textPrimary,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conv.messageCount > 0) ...[
                          const SizedBox(width: CompanionSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.18)
                                  : (ext?.textMuted ?? Colors.grey).withValues(alpha: 0.1),
                              borderRadius: CompanionRadius.borderSm,
                            ),
                            child: Text(
                              '${conv.messageCount} msgs',
                              style: CompanionTypography.caption.copyWith(
                                color: isActive
                                    ? (ext?.accent ?? CompanionColors.lightAccent)
                                    : ext?.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: CompanionSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: ext?.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(conv.createdAt),
                              style: CompanionTypography.caption.copyWith(
                                color: ext?.textMuted,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        if (widget.onDeleteConversation != null)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 14,
                              color: ext?.textMuted,
                            ),
                            tooltip: 'Delete thread',
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: isSwitchingBlocked
                                ? null
                                : () async {
                                    await widget.onDeleteConversation!(conv.id);
                                  },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, CompanionThemeExtension? ext) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: CompanionSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: ext?.borderSubtle ?? Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Text(
        'Local conversation storage',
        style: CompanionTypography.caption.copyWith(
          color: ext?.textMuted,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
