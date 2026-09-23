import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/widgets/brand/tigris_logo.dart';

void main() {
  testWidgets('TigrisLogo renders CustomPaint emblem correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TigrisLogo(size: 40.0),
        ),
      ),
    );

    expect(find.byType(TigrisLogo), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('TIGRIS'), findsNothing);
  });

  testWidgets('TigrisLogo with showWordmark displays TIGRIS title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TigrisLogo(
            size: 32.0,
            showWordmark: true,
          ),
        ),
      ),
    );

    expect(find.byType(TigrisLogo), findsOneWidget);
    expect(find.text('TIGRIS'), findsOneWidget);
  });
}
