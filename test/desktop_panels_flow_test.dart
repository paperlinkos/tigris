import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/app_shell.dart';
import 'package:tigris/app/navigation/desktop_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/app/theme/context_theme_extensions.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _mount(WidgetTester tester, {bool app = false, ThemeData? theme}) async {
  final storage = InMemoryStorage();
  final repo = OfflineFirstNoteRepository(localRepo: LocalNoteRepository(storage: storage));
  final now = DateTime(2026);
  await repo.saveNote(Note(id: 'a', title: 'Alpha', content: 'text', createdAt: now, updatedAt: now));
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: app
        ? AppShell(storage: storage, noteRepository: repo)
        : DesktopShell(storage: storage, noteRepository: repo),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openFromMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byKey(const Key('home_more_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings from the sidebar menu opens as a panel over the app', (tester) async {
    await _size(tester, const Size(1280, 800));
    await _mount(tester);
    await _openFromMenu(tester, 'Settings');

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('desktop_panel')), findsOneWidget);
    expect(find.byKey(const Key('desktop_sidebar')), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone, Settings is still a full page', (tester) async {
    await _size(tester, const Size(800, 800));
    await _mount(tester, app: true);
    await _openFromMenu(tester, 'Settings');

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('Sign in from Settings opens a narrower second panel, and Escape closes only that one', (tester) async {
    await _size(tester, const Size(1280, 800));
    await _mount(tester);
    await _openFromMenu(tester, 'Settings');

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    // Test fonts are far wider than the real ones, so the Login screen's longest
    // button overflows here. Its real layout is checked in a browser instead.
    final overflow = tester.takeException();
    expect(overflow == null || overflow.toString().contains('overflowed'), isTrue, reason: '$overflow');
    expect(find.byType(Dialog), findsNWidgets(2));
    expect(tester.getSize(find.byKey(const Key('desktop_panel')).last).width, 420);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
  });

  testWidgets('the close button and a tap outside both close the panel', (tester) async {
    await _size(tester, const Size(1280, 800));
    await _mount(tester);

    await _openFromMenu(tester, 'Settings');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await _openFromMenu(tester, 'Settings');
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('shortcuts do nothing while a panel is open, and work again after', (tester) async {
    await _size(tester, const Size(1280, 800));
    await _mount(tester);
    bool searchFocused() => tester.widget<TextField>(find.byKey(const Key('desktop_search'))).focusNode!.hasFocus;

    await _openFromMenu(tester, 'Settings');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(searchFocused(), isFalse);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(searchFocused(), isTrue);
  });

  testWidgets('in dark mode the panel and its page use the raised colour', (tester) async {
    await _size(tester, const Size(1280, 800));
    await _mount(tester, theme: AppTheme.darkTheme);
    await _openFromMenu(tester, 'Settings');

    final raised = tester.element(find.byKey(const Key('desktop_panel'))).appRaised;
    expect(tester.widget<Dialog>(find.byType(Dialog)).backgroundColor, raised);
    final scaffold = tester.widget<Scaffold>(find.descendant(of: find.byKey(const Key('desktop_panel')), matching: find.byType(Scaffold)).first);
    expect(scaffold.backgroundColor ?? Theme.of(tester.element(find.byKey(const Key('desktop_panel')))).scaffoldBackgroundColor, raised);
  });

  testWidgets('a panel works in the smallest desktop window', (tester) async {
    await _size(tester, const Size(900, 600));
    await _mount(tester);
    await _openFromMenu(tester, 'Settings');

    final panel = tester.getSize(find.byKey(const Key('desktop_panel')));
    expect(panel.height, lessThanOrEqualTo(600 * 0.85));
    expect(panel.width, lessThanOrEqualTo(560));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_row_a')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
