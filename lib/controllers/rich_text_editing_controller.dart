import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/note.dart';

enum AttributeType { bold, italic, highlight }

class TextSpanAttribute {
  final int start;
  final int end;
  final AttributeType type;

  const TextSpanAttribute({
    required this.start,
    required this.end,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'type': type.name,
  };

  factory TextSpanAttribute.fromJson(Map<String, dynamic> json) {
    return TextSpanAttribute(
      start: json['start'] as int,
      end: json['end'] as int,
      type: AttributeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttributeType.bold,
      ),
    );
  }

  TextSpanAttribute copyWith({int? start, int? end, AttributeType? type}) {
    return TextSpanAttribute(
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
    );
  }
}

class RichTextEditingController extends TextEditingController {
  final Color highlightColor;
  List<TextSpanAttribute> _spans = [];

  List<TextSpanAttribute> get spans => List.unmodifiable(_spans);

  RichTextEditingController({
    super.text,
    List<TextSpanAttribute>? initialSpans,
    this.highlightColor = const Color(0xFFFFF1A8),
  }) {
    if (initialSpans != null) {
      _spans = List.from(initialSpans);
      _normalizeSpans();
    }
  }

  factory RichTextEditingController.fromNoteContent({
    required String content,
    String? formatting,
    Color highlightColor = const Color(0xFFFFF1A8),
  }) {
    if (formatting != null && formatting.isNotEmpty) {
      try {
        final decoded = jsonDecode(formatting) as List<dynamic>;
        final parsedSpans = decoded
            .map((item) => TextSpanAttribute.fromJson(item as Map<String, dynamic>))
            .toList();
        return RichTextEditingController(
          text: content,
          initialSpans: parsedSpans,
          highlightColor: highlightColor,
        );
      } catch (_) {}
    }

    // Auto-migrate legacy markdown delimiters if present
    final migrated = parseLegacyMarkdown(content);
    return RichTextEditingController(
      text: migrated.text,
      initialSpans: migrated.spans,
      highlightColor: highlightColor,
    );
  }

  void loadFromContent(String newContent, String? newFormatting) {
    if (newFormatting != null && newFormatting.isNotEmpty) {
      try {
        final decoded = jsonDecode(newFormatting) as List<dynamic>;
        _spans = decoded
            .map((item) => TextSpanAttribute.fromJson(item as Map<String, dynamic>))
            .toList();
        _normalizeSpans();
        text = newContent;
        return;
      } catch (_) {}
    }

    final migrated = parseLegacyMarkdown(newContent);
    _spans = migrated.spans;
    _normalizeSpans();
    text = migrated.text;
  }

  void loadFromNote(Note note) {
    final body = note.content.isNotEmpty ? note.content : (note.subtitle ?? '');
    loadFromContent(body, note.formatting);
  }

  String? exportFormatting() {
    if (_spans.isEmpty) return null;
    return jsonEncode(_spans.map((s) => s.toJson()).toList());
  }

  static ({String text, List<TextSpanAttribute> spans}) parseLegacyMarkdown(String raw) {
    if (raw.isEmpty) return (text: '', spans: <TextSpanAttribute>[]);
    final regExp = RegExp(
      r'(\*\*(.*?)\*\*)|(\_(.*?)\_)|(\*(.*?)\*)|(\=\=(.*?)\=\=)',
      dotAll: true,
    );
    if (!regExp.hasMatch(raw)) {
      return (text: raw, spans: <TextSpanAttribute>[]);
    }

    final sb = StringBuffer();
    final spans = <TextSpanAttribute>[];
    int lastIndex = 0;

    for (final match in regExp.allMatches(raw)) {
      if (match.start > lastIndex) {
        sb.write(raw.substring(lastIndex, match.start));
      }
      final fullMatch = match.group(0)!;
      final startPos = sb.length;

      if (fullMatch.startsWith('**') && fullMatch.endsWith('**') && fullMatch.length >= 4) {
        final inner = fullMatch.substring(2, fullMatch.length - 2);
        sb.write(inner);
        spans.add(TextSpanAttribute(start: startPos, end: sb.length, type: AttributeType.bold));
      } else if (fullMatch.startsWith('==') && fullMatch.endsWith('==') && fullMatch.length >= 4) {
        final inner = fullMatch.substring(2, fullMatch.length - 2);
        sb.write(inner);
        spans.add(TextSpanAttribute(start: startPos, end: sb.length, type: AttributeType.highlight));
      } else if (((fullMatch.startsWith('_') && fullMatch.endsWith('_')) ||
                  (fullMatch.startsWith('*') && fullMatch.endsWith('*'))) && fullMatch.length >= 2) {
        final inner = fullMatch.substring(1, fullMatch.length - 1);
        sb.write(inner);
        spans.add(TextSpanAttribute(start: startPos, end: sb.length, type: AttributeType.italic));
      } else {
        sb.write(fullMatch);
      }
      lastIndex = match.end;
    }

    if (lastIndex < raw.length) {
      sb.write(raw.substring(lastIndex));
    }

    return (text: sb.toString(), spans: spans);
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    if (oldText != newText && _spans.isNotEmpty) {
      _adjustSpansForTextChange(oldText, newText);
    }
    super.value = newValue;
    _normalizeSpans(newValue.text.length);
  }

  void _adjustSpansForTextChange(String oldText, String newText) {
    int prefix = 0;
    while (prefix < oldText.length &&
        prefix < newText.length &&
        oldText[prefix] == newText[prefix]) {
      prefix++;
    }

    int suffix = 0;
    while (suffix < (oldText.length - prefix) &&
        suffix < (newText.length - prefix) &&
        oldText[oldText.length - 1 - suffix] == newText[newText.length - 1 - suffix]) {
      suffix++;
    }

    final oldDeletedStart = prefix;
    final oldDeletedEnd = oldText.length - suffix;
    final newInsertedStart = prefix;
    final newInsertedEnd = newText.length - suffix;
    final delta = (newInsertedEnd - newInsertedStart) - (oldDeletedEnd - oldDeletedStart);

    final updatedSpans = <TextSpanAttribute>[];

    for (final span in _spans) {
      // Case 1: Span completely before edit
      if (span.end <= oldDeletedStart) {
        updatedSpans.add(span);
        continue;
      }
      // Case 2: Span completely after edit
      if (span.start >= oldDeletedEnd) {
        final newStart = span.start + delta;
        final newEnd = span.end + delta;
        if (newEnd > newStart && newStart >= 0 && newEnd <= newText.length) {
          updatedSpans.add(TextSpanAttribute(start: newStart, end: newEnd, type: span.type));
        }
        continue;
      }
      // Case 3: Span overlaps with edit
      final leftEnd = span.end < oldDeletedStart ? span.end : oldDeletedStart;
      final hasLeft = span.start < leftEnd;

      final rightStart = span.start > oldDeletedEnd ? span.start : oldDeletedEnd;
      final hasRight = rightStart < span.end;

      if (hasLeft && !hasRight) {
        updatedSpans.add(TextSpanAttribute(start: span.start, end: leftEnd, type: span.type));
      } else if (!hasLeft && hasRight) {
        final shiftedStart = rightStart + delta;
        final shiftedEnd = span.end + delta;
        if (shiftedEnd > shiftedStart && shiftedStart >= 0 && shiftedEnd <= newText.length) {
          updatedSpans.add(TextSpanAttribute(start: shiftedStart, end: shiftedEnd, type: span.type));
        }
      } else if (hasLeft && hasRight) {
        if (oldDeletedStart == oldDeletedEnd) {
          // Pure insertion inside span: expand it
          updatedSpans.add(TextSpanAttribute(start: span.start, end: span.end + delta, type: span.type));
        } else {
          // Deletion inside span: shrink it
          final newEnd = span.end + delta;
          if (newEnd > span.start) {
            updatedSpans.add(TextSpanAttribute(start: span.start, end: newEnd, type: span.type));
          }
        }
      }
    }

    _spans = updatedSpans;
  }

  void _normalizeSpans([int? maxLen]) {
    final len = maxLen ?? text.length;
    final validSpans = <TextSpanAttribute>[];
    for (final s in _spans) {
      final start = s.start.clamp(0, len);
      final end = s.end.clamp(0, len);
      if (end > start) {
        validSpans.add(TextSpanAttribute(start: start, end: end, type: s.type));
      }
    }

    validSpans.sort((a, b) {
      if (a.type != b.type) return a.type.index.compareTo(b.type.index);
      return a.start.compareTo(b.start);
    });

    final merged = <TextSpanAttribute>[];
    for (final span in validSpans) {
      if (merged.isEmpty || merged.last.type != span.type) {
        merged.add(span);
      } else {
        final last = merged.last;
        if (span.start <= last.end) {
          final maxEnd = span.end > last.end ? span.end : last.end;
          merged[merged.length - 1] = TextSpanAttribute(
            start: last.start,
            end: maxEnd,
            type: last.type,
          );
        } else {
          merged.add(span);
        }
      }
    }
    _spans = merged;
  }

  void toggleFormat(AttributeType type) {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      final pos = sel.start;
      final wordRange = _getWordRangeAt(pos);
      if (wordRange != null && wordRange.start < wordRange.end) {
        _toggleFormatRange(wordRange.start, wordRange.end, type);
        notifyListeners();
      }
      return;
    }

    final start = sel.start < sel.end ? sel.start : sel.end;
    final end = sel.start < sel.end ? sel.end : sel.start;

    _toggleFormatRange(start, end, type);
    notifyListeners();
  }

  void _toggleFormatRange(int start, int end, AttributeType type) {
    final isFullyCovered = _isRangeFullyCovered(start, end, type);

    if (isFullyCovered) {
      final newSpans = <TextSpanAttribute>[];
      for (final span in _spans) {
        if (span.type != type) {
          newSpans.add(span);
          continue;
        }
        if (span.end <= start || span.start >= end) {
          newSpans.add(span);
        } else {
          if (span.start < start) {
            newSpans.add(TextSpanAttribute(start: span.start, end: start, type: type));
          }
          if (span.end > end) {
            newSpans.add(TextSpanAttribute(start: end, end: span.end, type: type));
          }
        }
      }
      _spans = newSpans;
    } else {
      _spans.add(TextSpanAttribute(start: start, end: end, type: type));
    }
    _normalizeSpans();
  }

  bool _isRangeFullyCovered(int start, int end, AttributeType type) {
    if (start >= end) return false;
    final typeSpans = _spans.where((s) => s.type == type).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    int coveredUntil = start;
    for (final s in typeSpans) {
      if (s.start > coveredUntil) break;
      if (s.end > coveredUntil) {
        coveredUntil = s.end;
      }
      if (coveredUntil >= end) return true;
    }
    return coveredUntil >= end;
  }

  TextRange? _getWordRangeAt(int pos) {
    final t = text;
    if (t.isEmpty || pos < 0 || pos > t.length) return null;
    int start = pos > 0 && pos == t.length ? pos - 1 : pos;
    while (start > 0 && !_isWordBoundary(t[start - 1])) {
      start--;
    }
    int end = pos;
    while (end < t.length && !_isWordBoundary(t[end])) {
      end++;
    }
    return TextRange(start: start, end: end);
  }

  bool _isWordBoundary(String ch) {
    return ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r';
  }

  void toggleBold() => toggleFormat(AttributeType.bold);
  void toggleItalic() => toggleFormat(AttributeType.italic);
  void toggleHighlight() => toggleFormat(AttributeType.highlight);

  bool isBoldActive() {
    final sel = selection;
    if (!sel.isValid) return false;
    final start = sel.isCollapsed ? (sel.start > 0 ? sel.start - 1 : 0) : sel.start;
    final end = sel.isCollapsed ? (start + 1).clamp(0, text.length) : sel.end;
    return _isRangeFullyCovered(start, end, AttributeType.bold);
  }

  bool isItalicActive() {
    final sel = selection;
    if (!sel.isValid) return false;
    final start = sel.isCollapsed ? (sel.start > 0 ? sel.start - 1 : 0) : sel.start;
    final end = sel.isCollapsed ? (start + 1).clamp(0, text.length) : sel.end;
    return _isRangeFullyCovered(start, end, AttributeType.italic);
  }

  bool isHighlightActive() {
    final sel = selection;
    if (!sel.isValid) return false;
    final start = sel.isCollapsed ? (sel.start > 0 ? sel.start - 1 : 0) : sel.start;
    final end = sel.isCollapsed ? (start + 1).clamp(0, text.length) : sel.end;
    return _isRangeFullyCovered(start, end, AttributeType.highlight);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final currentText = text;
    if (currentText.isEmpty) {
      return TextSpan(style: baseStyle, text: currentText);
    }

    if (_spans.isNotEmpty) {
      final boundaries = <int>{0, currentText.length};
      for (final s in _spans) {
        if (s.start >= 0 && s.start <= currentText.length) boundaries.add(s.start);
        if (s.end >= 0 && s.end <= currentText.length) boundaries.add(s.end);
      }

      final sortedPoints = boundaries.toList()..sort();
      final children = <TextSpan>[];

      for (int i = 0; i < sortedPoints.length - 1; i++) {
        final segStart = sortedPoints[i];
        final segEnd = sortedPoints[i + 1];
        if (segEnd <= segStart) continue;

        final segmentText = currentText.substring(segStart, segEnd);
        final activeTypes = _spans
            .where((s) => s.start <= segStart && s.end >= segEnd)
            .map((s) => s.type)
            .toSet();

        TextStyle segStyle = baseStyle;
        if (activeTypes.contains(AttributeType.bold)) {
          segStyle = segStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if (activeTypes.contains(AttributeType.italic)) {
          segStyle = segStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if (activeTypes.contains(AttributeType.highlight)) {
          segStyle = segStyle.copyWith(
            backgroundColor: highlightColor,
            color: const Color(0xFF2C2523),
            fontWeight: FontWeight.w500,
          );
        }

        children.add(TextSpan(text: segmentText, style: segStyle));
      }

      return TextSpan(style: baseStyle, children: children);
    }

    // Fallback: Support legacy raw markdown if text contains markdown tokens and no explicit spans
    final regExp = RegExp(
      r'(\*\*(.*?)\*\*)|(\_(.*?)\_)|(\*(.*?)\*)|(\=\=(.*?)\=\=)',
      dotAll: true,
    );
    if (!regExp.hasMatch(currentText)) {
      return TextSpan(style: baseStyle, text: currentText);
    }

    final spans = <TextSpan>[];
    int start = 0;

    for (final match in regExp.allMatches(currentText)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: currentText.substring(start, match.start),
          style: baseStyle,
        ));
      }

      final fullMatch = match.group(0)!;

      if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        spans.add(TextSpan(
          text: fullMatch,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (fullMatch.startsWith('==') && fullMatch.endsWith('==')) {
        spans.add(TextSpan(
          text: fullMatch,
          style: baseStyle.copyWith(
            backgroundColor: highlightColor,
            color: const Color(0xFF2C2523),
            fontWeight: FontWeight.w500,
          ),
        ));
      } else if ((fullMatch.startsWith('_') && fullMatch.endsWith('_')) ||
                 (fullMatch.startsWith('*') && fullMatch.endsWith('*'))) {
        spans.add(TextSpan(
          text: fullMatch,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else {
        spans.add(TextSpan(text: fullMatch, style: baseStyle));
      }

      start = match.end;
    }

    if (start < currentText.length) {
      spans.add(TextSpan(
        text: currentText.substring(start),
        style: baseStyle,
      ));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}

class SmartListController extends RichTextEditingController {
  SmartListController({
    super.text,
    super.initialSpans,
    super.highlightColor,
  });

  factory SmartListController.fromNote(Note note, {Color? highlightColor}) {
    final initialContent = (note.content.isNotEmpty)
        ? note.content
        : (note.subtitle ?? '');

    if (note.formatting != null && note.formatting!.isNotEmpty) {
      try {
        final decoded = jsonDecode(note.formatting!) as List<dynamic>;
        final spans = decoded
            .map((item) => TextSpanAttribute.fromJson(item as Map<String, dynamic>))
            .toList();
        return SmartListController(
          text: initialContent,
          initialSpans: spans,
          highlightColor: highlightColor ?? const Color(0xFFFFF1A8),
        );
      } catch (_) {}
    }

    final migrated = RichTextEditingController.parseLegacyMarkdown(initialContent);
    return SmartListController(
      text: migrated.text,
      initialSpans: migrated.spans,
      highlightColor: highlightColor ?? const Color(0xFFFFF1A8),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final oldSel = selection;

    // Intercept single newline insertion for smart list continuations
    if (newValue.text.length == oldText.length + 1 &&
        oldSel.isCollapsed &&
        oldSel.start >= 0 &&
        oldSel.start <= oldText.length &&
        newValue.text.length > oldSel.start &&
        newValue.text[oldSel.start] == '\n') {
      
      final cursor = oldSel.start;
      final lineStart = oldText.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
      final actualLineStart = lineStart == -1 ? 0 : lineStart + 1;
      final lineBeforeEnter = oldText.substring(actualLineStart, cursor);

      // 1. Bullet list (•, -, *)
      final bulletMatch = RegExp(r'^(\s*)([•\-\*])\s*(.*)$').firstMatch(lineBeforeEnter);
      if (bulletMatch != null) {
        final indent = bulletMatch.group(1)!;
        final symbol = bulletMatch.group(2)!;
        final content = bulletMatch.group(3)!;

        if (content.trim().isEmpty) {
          final newText = oldText.substring(0, actualLineStart) + oldText.substring(cursor);
          super.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: actualLineStart),
          );
          return;
        } else {
          final prefix = '\n$indent$symbol ';
          final newText = oldText.substring(0, cursor) + prefix + oldText.substring(cursor);
          super.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: cursor + prefix.length),
          );
          return;
        }
      }

      // 2. Numbered list (1., 2., etc)
      final numMatch = RegExp(r'^(\s*)(\d+)\.\s*(.*)$').firstMatch(lineBeforeEnter);
      if (numMatch != null) {
        final indent = numMatch.group(1)!;
        final numVal = int.parse(numMatch.group(2)!);
        final content = numMatch.group(3)!;

        if (content.trim().isEmpty) {
          final newText = oldText.substring(0, actualLineStart) + oldText.substring(cursor);
          super.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: actualLineStart),
          );
          return;
        } else {
          final prefix = '\n$indent${numVal + 1}. ';
          final newText = oldText.substring(0, cursor) + prefix + oldText.substring(cursor);
          super.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: cursor + prefix.length),
          );
          return;
        }
      }
    }

    super.value = newValue;
  }

  void toggleBulletList() {
    final sel = selection;
    final t = text;
    if (!sel.isValid) return;

    final cursor = sel.start;
    final lineStart = t.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    final actualLineStart = lineStart == -1 ? 0 : lineStart + 1;
    final lineEnd = t.indexOf('\n', cursor);
    final actualLineEnd = lineEnd == -1 ? t.length : lineEnd;
    final currentLine = t.substring(actualLineStart, actualLineEnd);

    final prefixMatch = RegExp(r'^(\s*)((?:\d+\.\s*|[•\-\*]\s*)+)').firstMatch(currentLine);

    if (prefixMatch != null) {
      final fullPrefix = prefixMatch.group(0)!;
      if (RegExp(r'^\s*[•\-\*]\s*$').hasMatch(fullPrefix)) {
        final newText = t.replaceRange(actualLineStart, actualLineStart + fullPrefix.length, '');
        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: (cursor - fullPrefix.length).clamp(actualLineStart, newText.length)),
        );
      } else {
        const newPrefix = '• ';
        final newText = t.replaceRange(actualLineStart, actualLineStart + fullPrefix.length, newPrefix);
        final delta = newPrefix.length - fullPrefix.length;
        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: (cursor + delta).clamp(actualLineStart, newText.length)),
        );
      }
    } else {
      const newPrefix = '• ';
      final newText = t.replaceRange(actualLineStart, actualLineStart, newPrefix);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + newPrefix.length),
      );
    }
  }

  void toggleNumberedList() {
    final sel = selection;
    final t = text;
    if (!sel.isValid) return;

    final cursor = sel.start;
    final lineStart = t.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    final actualLineStart = lineStart == -1 ? 0 : lineStart + 1;
    final lineEnd = t.indexOf('\n', cursor);
    final actualLineEnd = lineEnd == -1 ? t.length : lineEnd;
    final currentLine = t.substring(actualLineStart, actualLineEnd);

    final prefixMatch = RegExp(r'^(\s*)((?:\d+\.\s*|[•\-\*]\s*)+)').firstMatch(currentLine);

    int nextNum = 1;
    if (actualLineStart > 0) {
      final prevLineStart = t.lastIndexOf('\n', actualLineStart - 2);
      final actualPrevStart = prevLineStart == -1 ? 0 : prevLineStart + 1;
      final prevLine = t.substring(actualPrevStart, actualLineStart - 1);
      final prevNumMatch = RegExp(r'^(\s*)(\d+)\.\s*').firstMatch(prevLine);
      if (prevNumMatch != null) {
        nextNum = int.parse(prevNumMatch.group(2)!) + 1;
      }
    }
    final numPrefix = '$nextNum. ';

    if (prefixMatch != null) {
      final fullPrefix = prefixMatch.group(0)!;
      if (RegExp(r'^\s*\d+\.\s*$').hasMatch(fullPrefix)) {
        final newText = t.replaceRange(actualLineStart, actualLineStart + fullPrefix.length, '');
        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: (cursor - fullPrefix.length).clamp(actualLineStart, newText.length)),
        );
      } else {
        final newText = t.replaceRange(actualLineStart, actualLineStart + fullPrefix.length, numPrefix);
        final delta = numPrefix.length - fullPrefix.length;
        value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: (cursor + delta).clamp(actualLineStart, newText.length)),
        );
      }
    } else {
      final newText = t.replaceRange(actualLineStart, actualLineStart, numPrefix);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + numPrefix.length),
      );
    }
  }
}
