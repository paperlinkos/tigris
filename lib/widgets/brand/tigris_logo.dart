import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';

/// The Tigris mark is a striped T: a bar with a gold dot at one end and a stem
/// that tapers to a point like a stripe. On its own it is the app icon. In the
/// wordmark it is the "t" of "tigris".
class TigrisLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? accentColor;
  final bool showWordmark;

  const TigrisLogo({
    super.key,
    this.size = 32.0,
    this.color,
    this.accentColor,
    this.showWordmark = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? context.appTextPrimary;
    final goldAccent = accentColor ??
        (context.isDarkMode ? const Color(0xFFF59E0B) : const Color(0xFFD97706));

    Widget mark(double side) => SizedBox(
          width: side,
          height: side,
          child: CustomPaint(
            painter: TigrisLogoPainter(
              primaryColor: primaryColor,
              accentColor: goldAccent,
            ),
          ),
        );

    if (!showWordmark) {
      return Semantics(label: 'Tigris', image: true, child: mark(size));
    }

    // The mark stands in for the "t", so it is as tall as the letters and its
    // stem sits on the same baseline as "igris".
    final fontSize = size * 0.9;
    final markSide = size;
    return Semantics(
      label: 'Tigris',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Baseline(
              baseline: markSide * TigrisLogoPainter.stemTipY,
              baselineType: TextBaseline.alphabetic,
              child: mark(markSide),
            ),
            Text(
              'igris',
              style: AppTypography.display(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ).copyWith(letterSpacing: -fontSize * 0.02),
            ),
          ],
        ),
      ),
    );
  }
}

class TigrisLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  TigrisLogoPainter({
    required this.primaryColor,
    required this.accentColor,
  });

  /// Where the stem ends, as a fraction of the height.
  static const double stemTipY = 0.92;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final primary = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final accent = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Bar.
    final bar = RRect.fromLTRBR(
      w * 0.12, h * 0.12, w * 0.88, h * 0.30, Radius.circular(w * 0.09),
    );
    canvas.drawRRect(bar, primary);

    // Stem, tapering to a point.
    final stem = Path()
      ..moveTo(w * 0.42, h * 0.30)
      ..lineTo(w * 0.58, h * 0.30)
      ..quadraticBezierTo(w * 0.60, h * 0.65, w * 0.50, h * stemTipY)
      ..quadraticBezierTo(w * 0.40, h * 0.65, w * 0.42, h * 0.30)
      ..close();
    canvas.drawPath(stem, primary);

    // Gold dot on the end of the bar.
    canvas.drawCircle(Offset(w * 0.79, h * 0.21), w * 0.09, accent);
  }

  @override
  bool shouldRepaint(covariant TigrisLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
