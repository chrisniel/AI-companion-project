import 'dart:io';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callback invoked when a sanitized link is tapped.
typedef MarkdownLinkTapCallback = void Function(String url);

/// A streaming-stable, secure Markdown presentation layer for Assistant messages.
///
/// Mirrors Web `AssistantMarkdownRenderer.tsx`:
/// - Headings (H1–H4)
/// - Bold, Italic, Bold-Italic
/// - Inline code with background highlight
/// - Fenced code blocks with language header and Copy to Clipboard button
/// - Blockquotes with accent border
/// - Unordered and ordered lists
/// - Links with strict URL sanitization (only `http:`, `https:`, `mailto:` allowed)
/// - Blocks raw HTML execution and dangerous schemes (`javascript:`, `file:`)
class AssistantMarkdownView extends StatefulWidget {
  final String content;
  final TextStyle? baseStyle;
  final MarkdownLinkTapCallback? onLinkTap;

  const AssistantMarkdownView({
    super.key,
    required this.content,
    this.baseStyle,
    this.onLinkTap,
  });

  @override
  State<AssistantMarkdownView> createState() => _AssistantMarkdownViewState();
}

class _AssistantMarkdownViewState extends State<AssistantMarkdownView> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.content.isEmpty) return const SizedBox.shrink();

    // Clean up previously allocated recognizers from earlier streaming builds
    _disposeRecognizers();

    final themeExt = Theme.of(context).extension<CompanionThemeExtension>();
    final defaultStyle = widget.baseStyle ??
        CompanionTypography.bodyMedium.copyWith(
          color: themeExt?.textPrimary,
        );

    final blocks = _parseBlocks(widget.content, defaultStyle, themeExt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<Widget> _parseBlocks(
    String markdown,
    TextStyle defaultStyle,
    CompanionThemeExtension? themeExt,
  ) {
    final lines = markdown.split('\n');
    final widgets = <Widget>[];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // 1. Fenced Code Block: ```lang
      if (line.trim().startsWith('```')) {
        final language = line.trim().substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length) {
          if (lines[i].trim().startsWith('```')) {
            i++;
            break;
          }
          codeLines.push(lines[i]);
          i++;
        }
        widgets.add(
          _CodeBlockWidget(
            language: language.isEmpty ? 'text' : language,
            code: codeLines.join('\n'),
            themeExt: themeExt,
          ),
        );
        continue;
      }

      // 2. Horizontal Rule: ---, ***, ___
      if (RegExp(r'^(\s*[-*_]\s*){3,}$').hasMatch(line)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CompanionSpacing.sm),
            child: Divider(
              color: themeExt?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2),
              height: 1,
              thickness: 1,
            ),
          ),
        );
        i++;
        continue;
      }

      // 3. Headings: #, ##, ###, ####
      final headingMatch = RegExp(r'^(#{1,4})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final headingText = headingMatch.group(2)!;
        final inlineSpans = _renderInline(headingText, defaultStyle, themeExt);

        TextStyle headingStyle;
        double topPadding = CompanionSpacing.sm;
        double bottomPadding = CompanionSpacing.xs;

        if (level == 1) {
          headingStyle = CompanionTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: themeExt?.textPrimary,
          );
          topPadding = CompanionSpacing.md;
        } else if (level == 2) {
          headingStyle = CompanionTypography.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: themeExt?.textPrimary,
          );
          topPadding = CompanionSpacing.sm;
        } else if (level == 3) {
          headingStyle = CompanionTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: themeExt?.textPrimary,
          );
        } else {
          headingStyle = CompanionTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: themeExt?.textPrimary,
          );
        }

        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            child: SelectableText.rich(
              TextSpan(
                style: headingStyle,
                children: inlineSpans,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // 4. Blockquotes: > quote
      if (line.trim().startsWith('>')) {
        final quoteLines = <String>[line.trim().replaceFirst(RegExp(r'^>\s?'), '')];
        i++;
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quoteLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }

        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: CompanionSpacing.xs),
            padding: const EdgeInsets.only(
              left: CompanionSpacing.md,
              top: CompanionSpacing.xs,
              bottom: CompanionSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: themeExt?.accent ?? CompanionColors.lightAccent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: quoteLines.map((ql) {
                return SelectableText.rich(
                  TextSpan(
                    style: defaultStyle.copyWith(
                      color: themeExt?.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    children: _renderInline(ql, defaultStyle, themeExt),
                  ),
                );
              }).toList(),
            ),
          ),
        );
        continue;
      }

      // 5. Unordered List: - item or * item
      if (RegExp(r'^\s*[-*]\s+').hasMatch(line)) {
        final listItems = <String>[];
        while (i < lines.length && RegExp(r'^\s*[-*]\s+').hasMatch(lines[i])) {
          listItems.add(lines[i].replaceFirst(RegExp(r'^\s*[-*]\s+'), ''));
          i++;
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CompanionSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: CompanionSpacing.sm, top: 1),
                        child: Text(
                          '•',
                          style: defaultStyle.copyWith(
                            color: themeExt?.accent ?? CompanionColors.lightAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText.rich(
                          TextSpan(
                            style: defaultStyle,
                            children: _renderInline(item, defaultStyle, themeExt),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
        continue;
      }

      // 6. Ordered List: 1. item
      if (RegExp(r'^\s*(\d+)\.\s+').hasMatch(line)) {
        final listItems = <MapEntry<String, String>>[];
        while (i < lines.length && RegExp(r'^\s*(\d+)\.\s+').hasMatch(lines[i])) {
          final m = RegExp(r'^\s*(\d+)\.\s+(.*)$').firstMatch(lines[i]);
          if (m != null) {
            listItems.add(MapEntry(m.group(1)!, m.group(2)!));
          }
          i++;
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CompanionSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: CompanionSpacing.sm),
                        child: Text(
                          '${entry.key}.',
                          style: defaultStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: themeExt?.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText.rich(
                          TextSpan(
                            style: defaultStyle,
                            children: _renderInline(entry.value, defaultStyle, themeExt),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
        continue;
      }

      // 7. Table Block
      if (line.contains('|') && i + 1 < lines.length) {
        final headerCells = _splitTableRow(line);
        final sepCells = _splitTableRow(lines[i + 1]);
        if (headerCells.isNotEmpty &&
            _isSeparatorRow(sepCells) &&
            sepCells.length >= headerCells.length) {
          final alignments = sepCells.map(_parseCellAlignment).toList();
          final colCount = headerCells.length;
          final normalizedAlignments = List<TextAlign>.generate(
            colCount,
            (idx) => idx < alignments.length ? alignments[idx] : TextAlign.left,
          );

          final rows = <List<String>>[];
          i += 2;

          while (i < lines.length) {
            final curLine = lines[i];
            if (curLine.trim().isEmpty) {
              break;
            }
            if (curLine.trim().startsWith('```') ||
                RegExp(r'^(#{1,4})\s+').hasMatch(curLine) ||
                curLine.trim().startsWith('>') ||
                RegExp(r'^\s*[-*]\s+').hasMatch(curLine) ||
                RegExp(r'^\s*\d+\.\s+').hasMatch(curLine) ||
                RegExp(r'^(\s*[-*_]\s*){3,}$').hasMatch(curLine)) {
              break;
            }
            if (!curLine.contains('|')) {
              break;
            }
            var rowCells = _splitTableRow(curLine);
            if (rowCells.length < colCount) {
              rowCells = [
                ...rowCells,
                ...List.filled(colCount - rowCells.length, ''),
              ];
            } else if (rowCells.length > colCount) {
              rowCells = rowCells.sublist(0, colCount);
            }
            rows.add(rowCells);
            i++;
          }

          widgets.add(
            _MarkdownTableWidget(
              headers: headerCells,
              rows: rows,
              alignments: normalizedAlignments,
              defaultStyle: defaultStyle,
              themeExt: themeExt,
              renderInline: (text, style) => _renderInline(text, style, themeExt),
            ),
          );
          continue;
        }
      }

      // 8. Empty line
      if (line.trim().isEmpty) {
        i++;
        continue;
      }

      // 9. Normal Paragraph
      final paragraphLines = <String>[line];
      i++;
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !lines[i].trim().startsWith('```') &&
          !RegExp(r'^(#{1,4})\s+').hasMatch(lines[i]) &&
          !lines[i].trim().startsWith('>') &&
          !RegExp(r'^\s*[-*]\s+').hasMatch(lines[i]) &&
          !RegExp(r'^\s*\d+\.\s+').hasMatch(lines[i]) &&
          !RegExp(r'^(\s*[-*_]\s*){3,}$').hasMatch(lines[i]) &&
          !(i + 1 < lines.length && _isPossibleTableStart(lines[i], lines[i + 1]))) {
        paragraphLines.add(lines[i]);
        i++;
      }

      final paragraphText = paragraphLines.join('\n');
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CompanionSpacing.xs),
          child: SelectableText.rich(
            TextSpan(
              style: defaultStyle,
              children: _renderInline(paragraphText, defaultStyle, themeExt),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<InlineSpan> _renderInline(
    String text,
    TextStyle defaultStyle,
    CompanionThemeExtension? themeExt,
  ) {
    final spans = <InlineSpan>[];
    final tokenRegex = RegExp(
      r'(`[^`]+`|\*\*\*[^*]+\*\*\*|\*\*[^*]+\*\*|\*[^*]+\*|\[[^\]]+\]\((?:[^()]+|\([^()]*\))*\))',
    );

    int lastIndex = 0;
    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: defaultStyle,
          ),
        );
      }

      final token = match.group(0)!;

      // Inline code: `code`
      if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
        final code = token.substring(1, token.length - 1);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: themeExt?.surfaceRecessed ?? Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(CompanionRadius.sm),
                border: Border.all(
                  color: themeExt?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontFamily: 'Consolas, monospace',
                  fontSize: (defaultStyle.fontSize ?? 14) * 0.88,
                  fontWeight: FontWeight.w600,
                  color: themeExt?.accent ?? CompanionColors.lightAccent,
                ),
              ),
            ),
          ),
        );
      }
      // Bold-Italic: ***text***
      else if (token.startsWith('***') && token.endsWith('***') && token.length >= 6) {
        spans.add(
          TextSpan(
            text: token.substring(3, token.length - 3),
            style: defaultStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      // Bold: **text**
      else if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      }
      // Italic: *text*
      else if (token.startsWith('*') && token.endsWith('*') && token.length >= 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: defaultStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      // Links: [label](url)
      else if (token.startsWith('[') && token.contains('](') && token.endsWith(')')) {
        final linkMatch = RegExp(r'^\[([^\]]+)\]\((.*)\)$').firstMatch(token);
        if (linkMatch != null) {
          final label = linkMatch.group(1)!;
          final href = linkMatch.group(2)!.trim();

          // Strict URL Sanitization: Only allow http:, https:, mailto:
          final isSafe = _isSafeUrl(href);

          if (isSafe) {
            final recognizer = TapGestureRecognizer()
              ..onTap = () {
                if (widget.onLinkTap != null) {
                  widget.onLinkTap!(href);
                } else {
                  _launchSafeUrl(href);
                }
              };
            _recognizers.add(recognizer);

            spans.add(
              TextSpan(
                text: label,
                style: defaultStyle.copyWith(
                  color: themeExt?.accent ?? CompanionColors.lightAccent,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
                recognizer: recognizer,
              ),
            );
          } else {
            // Unsafe URL scheme (javascript:, file:, data:) -> render inert plain text label
            spans.add(
              TextSpan(
                text: label,
                style: defaultStyle,
              ),
            );
          }
        } else {
          spans.add(TextSpan(text: token, style: defaultStyle));
        }
      } else {
        spans.add(TextSpan(text: token, style: defaultStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: defaultStyle,
        ),
      );
    }

    return spans.isNotEmpty ? spans : [TextSpan(text: text, style: defaultStyle)];
  }

  static bool _isSafeUrl(String url) {
    final trimmed = url.trim().toLowerCase();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:')) {
      return true;
    }
    return false;
  }

  static void _launchSafeUrl(String url) {
    if (!_isSafeUrl(url)) return;
    try {
      if (Platform.isWindows) {
        Process.run('rundll32.exe', ['url.dll,FileProtocolHandler', url]);
      }
    } catch (_) {
      // Non-critical background failure
    }
  }

  static List<String> _splitTableRow(String rawLine) {
    var line = rawLine.trim();
    if (line.isEmpty) return [];

    if (line.startsWith('|')) {
      line = line.substring(1);
    }
    if (line.endsWith('|') && !line.endsWith(r'\|')) {
      line = line.substring(0, line.length - 1);
    }

    final cells = <String>[];
    final current = StringBuffer();
    bool inCode = false;
    bool isEscaped = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (isEscaped) {
        if (char == '|') {
          current.write('|');
        } else {
          current.write('\\');
          current.write(char);
        }
        isEscaped = false;
        continue;
      }

      if (char == '\\') {
        isEscaped = true;
        continue;
      }

      if (char == '`') {
        inCode = !inCode;
        current.write('`');
        continue;
      }

      if (char == '|' && !inCode) {
        cells.add(current.toString().trim());
        current.clear();
        continue;
      }

      current.write(char);
    }

    if (isEscaped) {
      current.write('\\');
    }
    cells.add(current.toString().trim());
    return cells;
  }

  static bool _isSeparatorRow(List<String> cells) {
    if (cells.isEmpty) return false;
    final separatorPattern = RegExp(r'^\s*:?-{1,}:?\s*$');
    for (final cell in cells) {
      if (!separatorPattern.hasMatch(cell)) {
        return false;
      }
    }
    return true;
  }

  static TextAlign _parseCellAlignment(String sepCell) {
    final trimmed = sepCell.trim();
    final startsWithColon = trimmed.startsWith(':');
    final endsWithColon = trimmed.endsWith(':');
    if (startsWithColon && endsWithColon) {
      return TextAlign.center;
    } else if (endsWithColon) {
      return TextAlign.right;
    } else {
      return TextAlign.left;
    }
  }

  static bool _isPossibleTableStart(String line, String nextLine) {
    if (!line.contains('|')) return false;
    final headers = _splitTableRow(line);
    final seps = _splitTableRow(nextLine);
    return headers.isNotEmpty && _isSeparatorRow(seps) && seps.length >= headers.length;
  }
}

/// Styled Code Block with syntax header and Copy button mirroring Web CodeBlock
class _CodeBlockWidget extends StatefulWidget {
  final String language;
  final String code;
  final CompanionThemeExtension? themeExt;

  const _CodeBlockWidget({
    required this.language,
    required this.code,
    required this.themeExt,
  });

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;

  void _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.themeExt;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: CompanionSpacing.sm),
      decoration: BoxDecoration(
        color: ext?.surfaceRecessed ?? Colors.black.withValues(alpha: 0.08),
        borderRadius: CompanionRadius.borderLg,
        border: Border.all(
          color: ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CompanionSpacing.md,
              vertical: CompanionSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: ext?.surfaceElevated ?? Colors.white.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.terminal_rounded,
                      size: 14,
                      color: ext?.accent ?? CompanionColors.lightAccent,
                    ),
                    const SizedBox(width: CompanionSpacing.xs),
                    Text(
                      widget.language.toUpperCase(),
                      style: CompanionTypography.caption.copyWith(
                        fontFamily: 'Consolas, monospace',
                        fontWeight: FontWeight.bold,
                        color: ext?.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _handleCopy,
                  borderRadius: BorderRadius.circular(CompanionRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CompanionSpacing.xs,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 12,
                          color: _copied
                              ? (ext?.success ?? CompanionColors.success)
                              : (ext?.textSecondary ?? Colors.grey),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: CompanionTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _copied
                                ? (ext?.success ?? CompanionColors.success)
                                : (ext?.textSecondary ?? Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code Content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(CompanionSpacing.md),
            child: SelectableText(
              widget.code,
              style: TextStyle(
                fontFamily: 'Consolas, monospace',
                fontSize: 12.5,
                height: 1.5,
                color: ext?.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownTableWidget extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final List<TextAlign> alignments;
  final TextStyle defaultStyle;
  final CompanionThemeExtension? themeExt;
  final List<InlineSpan> Function(String text, TextStyle style) renderInline;

  const _MarkdownTableWidget({
    required this.headers,
    required this.rows,
    required this.alignments,
    required this.defaultStyle,
    required this.themeExt,
    required this.renderInline,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = themeExt?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2);
    final headerBg = themeExt?.surfaceElevated ?? Colors.black.withValues(alpha: 0.05);
    final stripeBg = themeExt?.surfaceRecessed ?? Colors.black.withValues(alpha: 0.02);

    final headerStyle = defaultStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: themeExt?.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CompanionSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CompanionRadius.sm),
          border: Border.all(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(color: borderColor, width: 1),
              verticalInside: BorderSide(color: borderColor, width: 1),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerBg),
                children: List.generate(headers.length, (colIdx) {
                  final alignment = colIdx < alignments.length ? alignments[colIdx] : TextAlign.left;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CompanionSpacing.md,
                      vertical: CompanionSpacing.sm,
                    ),
                    child: SelectableText.rich(
                      TextSpan(
                        style: headerStyle,
                        children: renderInline(headers[colIdx], headerStyle),
                      ),
                      textAlign: alignment,
                    ),
                  );
                }),
              ),
              ...rows.asMap().entries.map((entry) {
                final rowIdx = entry.key;
                final row = entry.value;
                final isEven = rowIdx % 2 == 1;
                return TableRow(
                  decoration: isEven ? BoxDecoration(color: stripeBg) : null,
                  children: List.generate(headers.length, (colIdx) {
                    final cellText = colIdx < row.length ? row[colIdx] : '';
                    final alignment = colIdx < alignments.length ? alignments[colIdx] : TextAlign.left;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CompanionSpacing.md,
                        vertical: CompanionSpacing.sm,
                      ),
                      child: SelectableText.rich(
                        TextSpan(
                          style: defaultStyle,
                          children: renderInline(cellText, defaultStyle),
                        ),
                        textAlign: alignment,
                      ),
                    );
                  }),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

extension on List<String> {
  void push(String element) => add(element);
}
