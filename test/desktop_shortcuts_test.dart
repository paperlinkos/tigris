import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/desktop_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';

Future<OfflineFirstNoteRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = OfflineFirstNoteRepository(localRepo: LocalNoteRepository(storage: InMemoryStorage()));
  final now = DateTime(2026);
  await repo.saveNote(Note(id: 'a', title: 'Alpha', content: 'first', createdAt: now, updatedAt: now));
  await repo.saveNote(Note(id: 'b', title: 'Beta', content: 'second', createdAt: now.add(const Duration(seconds: 1)), updatedAt: now.add(const Duration(seconds: 1))));
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: DesktopShell(storage: InMemoryStorage(), noteRepository: repo)));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _control(WidgetTester tester, LogicalKeyboardKey key, {bool alt = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

void main() {
  testWidgets('Control+K focuses search and reveals a hidden sidebar', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('desktop_hide_sidebar')));
    await _control(tester, LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.byKey(const Key('desktop_sidebar')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('desktop_search'))).focusNode!.hasFocus, isTrue);
  });

  testWidgets('Control+N and Control+Alt+N create and open notes', (tester) async {
    final repo = await _pump(tester);
    await _control(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect((await repo.getAllNotes()).length, 3);
    await _control(tester, LogicalKeyboardKey.keyN, alt: true);
    await tester.pumpAndSettle();
    expect((await repo.getAllNotes()).length, 4);
  });

  testWidgets('Control+backslash toggles the sidebar', (tester) async {
    await _pump(tester);
    await _control(tester, LogicalKeyboardKey.backslash);
    await tester.pump();
    expect(find.byKey(const Key('desktop_sidebar')), findsNothing);
    await _control(tester, LogicalKeyboardKey.backslash);
    await tester.pump();
    expect(find.byKey(const Key('desktop_sidebar')), findsOneWidget);
  });

  testWidgets('Enter in search opens the first matching note and clears query', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('desktop_search')), 'Alpha');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('desktop_search'))).controller!.text, isEmpty);
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Alpha');
  });

  testWidgets('Escape clears search and moves focus away from it', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('desktop_search')), 'Alpha');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key('desktop_search')));
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isFalse);
  });

  testWidgets('shortcuts do nothing while a dialog is open', (tester) async {
    final repo = await _pump(tester);
    showDialog<void>(context: tester.element(find.byType(DesktopShell)), builder: (context) => const AlertDialog(title: Text('Dialog')));
    await tester.pumpAndSettle();
    await _control(tester, LogicalKeyboardKey.keyN);
    await tester.pump();
    expect((await repo.getAllNotes()).length, 2);
  });

  testWidgets('search shortcut hint hides while there is a query', (tester) async {
    await _pump(tester);
    expect(find.text('Ctrl K'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('desktop_search')), 'Alpha');
    await tester.pump();
    expect(find.text('Ctrl K'), findsNothing);
  });
}
