import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/app_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/note_block.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';

Note _note(String id, String title, DateTime updated, {String content = '', String? parentId, String? blocksJson}) => Note(id: id, title: title, content: content, parentId: parentId, blocksJson: blocksJson, createdAt: updated, updatedAt: updated);

Future<void> _size(WidgetTester tester, double width, double height) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<LocalNoteRepository> _app(WidgetTester tester, {List<Note> notes = const []}) async {
  final storage = InMemoryStorage();
  final repo = LocalNoteRepository(storage: storage);
  for (final note in notes) {
    await repo.saveNote(note);
  }
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: AppShell(storage: storage, noteRepository: repo)));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('at 1280x800 AppShell shows sidebar and pane, not phone new note button', (tester) async {
    await _size(tester, 1280, 800); await _app(tester, notes: [_note('one', 'One', DateTime(2026, 1, 1))]);
    expect(find.text('Tigris'), findsOneWidget); expect(find.byKey(const Key('desktop_new_note')), findsOneWidget); expect(find.byKey(const Key('new_note_button')), findsNothing);
  });
  testWidgets('at 800x800 AppShell shows phone layout', (tester) async {
    await _size(tester, 800, 800); await _app(tester);
    expect(find.byKey(const Key('new_note_button')), findsOneWidget); expect(find.byKey(const Key('desktop_new_note')), findsNothing);
  });
  testWidgets('900 is desktop and 899 is phone', (tester) async {
    await _size(tester, 900, 800); await _app(tester); expect(find.byKey(const Key('desktop_new_note')), findsOneWidget);
    tester.view.physicalSize = const Size(899, 800); await tester.pumpAndSettle(); expect(find.byKey(const Key('new_note_button')), findsOneWidget);
  });
  testWidgets('opens the most recently updated note on start', (tester) async {
    await _size(tester, 1280, 800); await _app(tester, notes: [_note('old', 'Old', DateTime(2026, 1)), _note('new', 'Newest', DateTime(2026, 2))]);
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Newest');
  });
  testWidgets('empty state creates and opens a note', (tester) async {
    await _size(tester, 1280, 800); await _app(tester);
    expect(find.text('Your notes will appear here.'), findsNWidgets(2)); await tester.tap(find.text('Create your first note')); await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop_new_note')), findsOneWidget); expect(find.byType(TextField), findsWidgets);
  });
  testWidgets('clicking sidebar row changes pane without a Navigator route', (tester) async {
    await _size(tester, 1280, 800); await _app(tester, notes: [_note('one', 'One', DateTime(2026, 1)), _note('two', 'Two', DateTime(2026, 2))]);
    await tester.tap(find.byKey(const ValueKey('note_row_one'))); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'One'); expect(Navigator.of(tester.element(find.byType(AppShell))).canPop(), isFalse);
  });
  testWidgets('switching notes saves typed title text', (tester) async {
    await _size(tester, 1280, 800); final repo = await _app(tester, notes: [_note('one', 'One', DateTime(2026, 1)), _note('two', 'Two', DateTime(2026, 2))]);
    await tester.enterText(find.byKey(const Key('note_title_field')), 'Changed'); await tester.tap(find.byKey(const ValueKey('note_row_one'))); await tester.pumpAndSettle();
    expect((await repo.getNote('two'))!.title, 'Changed');
  });
  testWidgets('divider resizes and clamps sidebar', (tester) async {
    await _size(tester, 1280, 800); await _app(tester, notes: [_note('one', 'One', DateTime(2026))]);
    final divider = find.byKey(const Key('desktop_divider')); await tester.drag(divider, const Offset(100, 0)); await tester.pump();
    expect(tester.getSize(find.byKey(const Key('desktop_sidebar'))).width, anyOf(380, closeTo(380, 1)));
    await tester.drag(divider, const Offset(1000, 0)); await tester.pump(); expect(tester.getSize(find.byKey(const Key('desktop_sidebar'))).width, lessThanOrEqualTo(421));
    await tester.drag(divider, const Offset(-1000, 0)); await tester.pump(); expect(tester.getSize(find.byKey(const Key('desktop_sidebar'))).width, greaterThanOrEqualTo(219));
  });
  testWidgets('sidebar hide and show buttons work', (tester) async {
    await _size(tester, 1280, 800); await _app(tester); await tester.tap(find.byKey(const Key('desktop_hide_sidebar'))); await tester.pump();
    expect(find.byKey(const Key('desktop_new_note')), findsNothing); await tester.tap(find.byKey(const Key('desktop_show_sidebar'))); await tester.pump(); expect(find.byKey(const Key('desktop_new_note')), findsOneWidget);
  });
  testWidgets('desktop new note creates an empty focused title', (tester) async {
    await _size(tester, 1280, 800); await _app(tester); await tester.tap(find.byKey(const Key('desktop_new_note'))); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).focusNode!.hasFocus, isTrue);
  });
  testWidgets('search filters then clears when opening a result', (tester) async {
    await _size(tester, 1280, 800); await _app(tester, notes: [_note('one', 'Alpha', DateTime(2026, 1)), _note('two', 'Beta', DateTime(2026, 2))]);
    await tester.enterText(find.byKey(const Key('desktop_search')), 'Alpha'); await tester.pump(); expect(find.byKey(const ValueKey('note_row_two')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('note_row_one'))); await tester.pumpAndSettle(); expect(tester.widget<TextField>(find.byKey(const Key('desktop_search'))).controller!.text, '');
  });
  testWidgets('opening page block changes pane without route', (tester) async {
    await _size(tester, 1280, 800); final blocks = jsonEncode([NoteBlock(type: BlockType.page, targetNoteId: 'child').toJson()]);
    await _app(tester, notes: [_note('root', 'Root', DateTime(2026, 2), blocksJson: blocks), _note('child', 'Child', DateTime(2026, 1), parentId: 'root')]);
    await tester.tap(find.text('Child').last); await tester.pumpAndSettle(); expect(Navigator.of(tester.element(find.byType(AppShell))).canPop(), isFalse);
  });
  testWidgets('deleting nested note chooses parent and top level chooses next recent', (tester) async {
    await _size(tester, 1280, 800); await _app(tester, notes: [_note('parent', 'Parent', DateTime(2026, 1)), _note('child', 'Child', DateTime(2026, 3), parentId: 'parent'), _note('other', 'Other', DateTime(2026, 2))]);
    await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('note_row_parent'))) + const Offset(12, 15)); await tester.pumpAndSettle(); await tester.tap(find.byKey(const ValueKey('note_row_child'))); await tester.pumpAndSettle(); await tester.tap(find.byKey(const Key('note_more_menu'))); await tester.pumpAndSettle(); await tester.tap(find.text('Delete note')); await tester.pumpAndSettle(); await tester.tap(find.text('Delete')); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Parent');
    await tester.tap(find.byKey(const Key('note_more_menu'))); await tester.pumpAndSettle(); await tester.tap(find.text('Delete note')); await tester.pumpAndSettle(); await tester.tap(find.text('Delete')); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Other');
  });
  testWidgets('desktop layouts do not overflow', (tester) async {
    for (final size in [const Size(900, 600), const Size(1280, 800), const Size(1920, 1080)]) { await _size(tester, size.width, size.height); await _app(tester, notes: [_note('one', 'One', DateTime(2026))]); expect(tester.takeException(), isNull); }
  });
  testWidgets('deleting through the syncing repository opens the parent, not its parent', (tester) async {
    await _size(tester, 1280, 800);
    final storage = InMemoryStorage();
    final repo = OfflineFirstNoteRepository(localRepo: LocalNoteRepository(storage: storage));
    await repo.saveNote(_note('top', 'Top', DateTime(2026, 1)));
    await repo.saveNote(_note('middle', 'Middle', DateTime(2026, 2), parentId: 'top'));
    await repo.saveNote(_note('deep', 'Deep', DateTime(2026, 3), parentId: 'middle'));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: AppShell(storage: storage, noteRepository: repo)));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('note_row_middle'))) + const Offset(27, 15));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_row_deep')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Deep');

    await tester.tap(find.byKey(const Key('note_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Middle');
  });
}
