import 'dart:math';
import 'package:flutter/material.dart';
import '../app/navigation/breakpoints.dart';
import '../app/theme/context_theme_extensions.dart';

class DesktopPanelScope extends InheritedWidget {
  const DesktopPanelScope({super.key, required super.child});
  static bool maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopPanelScope>() != null;
  @override
  bool updateShouldNotify(DesktopPanelScope oldWidget) => false;
}

Future<T?> openScreen<T>(
  BuildContext context,
  WidgetBuilder builder, {
  double width = 560,
  double height = 720,
}) {
  final size = MediaQuery.sizeOf(context);
  if (size.width < desktopBreakpoint) {
    return Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: dialogContext.appRaised,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dialogContext.appBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const Key('desktop_panel'),
        width: min(width, size.width - 48),
        height: min(height, size.height * .85),
        child: DesktopPanelScope(
          child: Theme(
            data: Theme.of(
              context,
            ).copyWith(scaffoldBackgroundColor: dialogContext.appRaised),
            child: builder(dialogContext),
          ),
        ),
      ),
    ),
  );
}
