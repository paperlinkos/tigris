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
}
