import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';

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
    final goldAccent = accentColor ?? (context.isDarkMode ? const Color(0xFFF59E0B) : const Color(0xFFD97706));

    final logoWidget = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: TigrisLogoPainter(
          primaryColor: primaryColor,
          accentColor: goldAccent,
        ),
      ),
    );

    if (!showWordmark) return logoWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoWidget,
        SizedBox(width: size * 0.35),
        Text(
          'TIGRIS',
          style: AppTypography.display(
            fontSize: size * 0.65,
            fontWeight: FontWeight.w700,
            color: primaryColor,
          ).copyWith(letterSpacing: 2.0),
        ),
      ],
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

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = w * 0.085;

    final paintPrimary = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintAccent = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Draw stylized 'T' stream & page fold
    final topBar = Path()
      ..moveTo(w * 0.15, h * 0.22)
      ..lineTo(w * 0.85, h * 0.22);
    canvas.drawPath(topBar, paintPrimary);

    // Stem curve
    final stem = Path()
      ..moveTo(w * 0.5, h * 0.22)
      ..cubicTo(
        w * 0.5, h * 0.55,
        w * 0.35, h * 0.82,
        w * 0.8, h * 0.82,
      );
    canvas.drawPath(stem, paintPrimary);

    // Complementary page leaf curve
    final leaf = Path()
      ..moveTo(w * 0.2, h * 0.5)
      ..cubicTo(
        w * 0.2, h * 0.75,
        w * 0.35, h * 0.85,
        w * 0.48, h * 0.85,
      );
    final paintLeaf = Paint()
      ..color = primaryColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(leaf, paintLeaf);

    // Accent amber gold dot
    canvas.drawCircle(Offset(w * 0.85, h * 0.22), strokeWidth * 0.75, paintAccent);
  }

  @override
  bool shouldRepaint(covariant TigrisLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor || oldDelegate.accentColor != accentColor;
  }
}
