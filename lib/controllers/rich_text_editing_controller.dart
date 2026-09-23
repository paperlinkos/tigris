import 'package:flutter/material.dart';

class RichTextEditingController extends TextEditingController {
  final Color highlightColor;

  RichTextEditingController({
    super.text,
    this.highlightColor = const Color(0xFFFFF1A8),
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final textContent = text;
    if (textContent.isEmpty) {
      return TextSpan(style: baseStyle, text: textContent);
    }

    final spans = <TextSpan>[];
    int start = 0;

    final regExp = RegExp(
      r'(\*\*(.*?)\*\*)|(\_(.*?)\_)|(\*(.*?)\*)|(\=\=(.*?)\=\=)',
      dotAll: true,
    );

    for (final match in regExp.allMatches(textContent)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: textContent.substring(start, match.start),
          style: baseStyle,
        ));
      }

      final fullMatch = match.group(0)!;

      if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        spans.add(TextSpan(
          text: fullMatch,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else {
        spans.add(TextSpan(text: fullMatch, style: baseStyle));
      }

      start = match.end;
    }

    if (start < textContent.length) {
      spans.add(TextSpan(
        text: textContent.substring(start),
        style: baseStyle,
      ));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  void toggleFormat(String delimiter) {
    final val = value;
    final sel = val.selection;
    final currentText = val.text;
    if (!sel.isValid) return;

    final dLen = delimiter.length;

    if (sel.isCollapsed) {
      final pos = sel.start;
      // Check if cursor is inside delimiter (e.g. **|**)
      if (pos >= dLen && pos + dLen <= currentText.length) {
        final before = currentText.substring(pos - dLen, pos);
        final after = currentText.substring(pos, pos + dLen);
        if (before == delimiter && after == delimiter) {
          // Remove surrounding delimiters
          final newText = currentText.replaceRange(pos - dLen, pos + dLen, '');
          value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: pos - dLen),
          );
          return;
        }
      }
      // Insert empty delimiters and place cursor inside (**|**)
      final newText = currentText.replaceRange(pos, pos, delimiter + delimiter);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + dLen),
      );
    } else {
      final selectedText = currentText.substring(sel.start, sel.end);

      // 1. Check if selection itself includes delimiters: **text**
      if (selectedText.length >= dLen * 2 &&
          selectedText.startsWith(delimiter) &&
          selectedText.endsWith(delimiter)) {
        final innerText = selectedText.substring(dLen, selectedText.length - dLen);
        final newText = currentText.replaceRange(sel.start, sel.end, innerText);
        value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: sel.start,
            extentOffset: sel.start + innerText.length,
          ),
        );
        return;
      }

      // 2. Check if text outside selection has delimiters: **|text|**
      if (sel.start >= dLen && sel.end + dLen <= currentText.length) {
        final before = currentText.substring(sel.start - dLen, sel.start);
        final after = currentText.substring(sel.end, sel.end + dLen);
        if (before == delimiter && after == delimiter) {
          final newText = currentText.replaceRange(sel.end, sel.end + dLen, '');
          final newText2 = newText.replaceRange(sel.start - dLen, sel.start, '');
          value = TextEditingValue(
            text: newText2,
            selection: TextSelection(
              baseOffset: sel.start - dLen,
              extentOffset: sel.end - dLen,
            ),
          );
          return;
        }
      }

      // 3. Otherwise wrap selection in delimiters
      final wrappedText = '$delimiter$selectedText$delimiter';
      final newText = currentText.replaceRange(sel.start, sel.end, wrappedText);
      value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start,
          extentOffset: sel.start + wrappedText.length,
        ),
      );
    }
  }
}
