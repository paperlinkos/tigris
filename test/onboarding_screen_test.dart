import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/screens/onboarding_screen.dart';

void main() {
  testWidgets('OnboardingScreen renders slide 1 and navigates to next slide', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );

    expect(find.text('Offline-First & Lightning Fast'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Nested Streams & Subpages'), findsOneWidget);
  });

  testWidgets('OnboardingScreen trigger onComplete callback when Skip is pressed', (WidgetTester tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onComplete: () {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });
}
