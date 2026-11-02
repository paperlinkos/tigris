import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/desktop_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';

Note _note(String id, String title, int day, {String? parentId, String content = ''}) {
  final date = DateTime(2026, 1, day);
  return Note(id: id, title: title, content: content, parentId: parentId, createdAt: date, updatedAt: date);
}

Future<OfflineFirstNoteRepository> _pump(WidgetTester tester, List<Note> notes) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = OfflineFirstNoteRepository(localRepo: LocalNoteRepository(storage: InMemoryStorage()));
  for (final note in notes) { await repo.saveNote(note); }
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: DesktopShell(storage: InMemoryStorage(), noteRepository: repo)));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _menu(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('note_row_$id')), buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('right-clicking a row opens all note menu items', (tester) async {
    await _pump(tester, [_note('a', 'Alpha', 1)]);
    await _menu(tester, 'a');
    for (final label in ['Add page inside', 'Rename', 'Duplicate', 'Delete']) { expect(find.text(label), findsOneWidget); }
  });

  testWidgets('More button opens the note menu on hover', (tester) async {
    await _pump(tester, [_note('a', 'Alpha', 1)]);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byKey(const ValueKey('note_row_a'))));
    await tester.pump();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('note_row_a')), matching: find.byTooltip('More')));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
  });

  testWidgets('Add page inside creates and opens a focused nested note', (tester) async {
    final repo = await _pump(tester, [_note('a', 'Alpha', 1)]);
    await _menu(tester, 'a');
    await tester.tap(find.text('Add page inside'));
    await tester.pumpAndSettle();
    final child = (await repo.getAllNotes()).singleWhere((note) => note.parentId == 'a');
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).focusNode!.hasFocus, isTrue);
    expect(find.byKey(ValueKey('note_row_${child.id}')), findsOneWidget);
  });

  testWidgets('renaming a closed note saves its title and sidebar row', (tester) async {
    final repo = await _pump(tester, [_note('a', 'Open', 2), _note('b', 'Old', 1)]);
    await _menu(tester, 'b');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rename_field')), 'New');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect((await repo.getNote('b'))!.title, 'New');
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('renaming the open note updates and autosaves its title', (tester) async {
    final repo = await _pump(tester, [_note('a', 'Open', 2)]);
    await _menu(tester, 'a');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rename_field')), 'Changed');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Changed');
    expect((await repo.getNote('a'))!.title, 'Changed');
  });

  testWidgets('an empty rename changes nothing and closes cleanly', (tester) async {
    final repo = await _pump(tester, [_note('a', 'Alpha', 1)]);
    await _menu(tester, 'a');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rename_field')), '');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect((await repo.getNote('a'))!.title, 'Alpha');
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate copies text but not descendants', (tester) async {
    final repo = await _pump(tester, [_note('a', 'Alpha', 2, content: 'hello'), _note('child', 'Child', 1, parentId: 'a')]);
    await _menu(tester, 'a');
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    final copy = (await repo.getAllNotes()).singleWhere((note) => note.title == 'Alpha copy');
    expect(copy.content, 'hello');
    expect(copy.childrenIds, isEmpty);
    expect(copy.blocks.every((block) => block.type.name != 'page'), isTrue);
  });

  testWidgets('delete dialog counts all nested pages and Cancel preserves notes', (tester) async {
    final repo = await _pump(tester, [_note('a', 'Alpha', 3), _note('b', 'Beta', 2, parentId: 'a'), _note('c', 'Gamma', 1, parentId: 'b')]);
    await _menu(tester, 'a');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('This also deletes the 2 pages inside it.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await repo.getNote('a'), isNotNull);
  });

  testWidgets('deleting a closed note leaves the current note open', (tester) async {
    await _pump(tester, [_note('a', 'Open', 2), _note('b', 'Delete', 1)]);
    await _menu(tester, 'b');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Open');
  });

  testWidgets('deleting an open nested note opens its parent', (tester) async {
    await _pump(tester, [_note('a', 'Parent', 1), _note('b', 'Child', 2, parentId: 'a')]);
    await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('note_row_a'))) + const Offset(20, 15));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_row_b')));
    await tester.pumpAndSettle();
    await _menu(tester, 'b');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Parent');
  });

  testWidgets('deleting the only note shows the empty state', (tester) async {
    await _pump(tester, [_note('a', 'Only', 1)]);
    await _menu(tester, 'a');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Your notes will appear here.'), findsNWidgets(2));
  });
}
