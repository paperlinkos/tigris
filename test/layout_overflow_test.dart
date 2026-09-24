import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tigris/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final viewports = <String, Size>{
    'iPhone SE (375x667)': const Size(375, 667),
    'iPhone Standard (390x844)': const Size(390, 844),
    'iPhone Pro Max (430x932)': const Size(430, 932),
    'Android Compact (360x800)': const Size(360, 800),
  };

  for (final entry in viewports.entries) {
    testWidgets('Check for layout overflow on ${entry.key}', (WidgetTester tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const PersonalLearningApp());
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      if (exception is FlutterError) {
        debugPrint(exception.toStringDeep());
      }
      expect(exception, isNull);
      expect(find.text('NOTES'), findsWidgets);

      // Open sidebar drawer and verify no overflow
      await tester.tap(find.byKey(const Key('sidebar_toggle_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('STREAMS'), findsOneWidget);

      // Verify Settings in sidebar drawer
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('SETTINGS'), findsOneWidget);
    });
  }
}
