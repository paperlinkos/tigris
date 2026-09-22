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
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PersonalLearningApp());
      await tester.pumpAndSettle();

      // Verify Home Review tab has no overflow
      expect(tester.takeException(), isNull);
      expect(find.text('YOUR MEMORY'), findsOneWidget);
      expect(find.text('RECENT NOTES'), findsOneWidget);

      // Verify Notes tab has no overflow
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('NOTES'), findsOneWidget);

      // Verify Settings tab has no overflow
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('SETTINGS'), findsOneWidget);
    });
  }
}
