import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/widgets/calm_scaffold.dart';
import 'package:tigris/widgets/desktop_panel.dart';

Widget _app() => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => openScreen(
            context,
            (_) =>
                const CalmScaffold(title: 'Settings', body: Text('Panel body')),
          ),
          child: const Text('Open settings'),
        ),
      ),
    ),
  ),
);

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('desktop opens a centered dialog and keeps its page behind it', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('phone opens a normal route instead of a dialog', (tester) async {
    await _size(tester, const Size(800, 800));
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(
      Navigator.of(tester.element(find.text('Panel body'))).canPop(),
      isTrue,
    );
  });

  testWidgets('panel fits each supported desktop window', (tester) async {
    for (final size in [
      const Size(900, 600),
      const Size(1280, 800),
      const Size(1920, 1080),
    ]) {
      await _size(tester, size);
      await tester.pumpWidget(_app());
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      final panel = tester.getSize(find.byKey(const Key('desktop_panel')));
      expect(panel.width, lessThanOrEqualTo(560));
      expect(panel.width, lessThanOrEqualTo(size.width - 48));
      expect(panel.height, lessThanOrEqualTo(size.height * 0.85));
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('panel close button, escape, and barrier all close the panel', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 800));
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calm_scaffold_back_button')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
