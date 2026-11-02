import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/desktop_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/persistence/storage_interface.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/repositories/offline_first_note_repository.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/widgets/editor/block_note_editor.dart';

/// Saves are slower than deletes, so without ordering a delete requested after
/// a save finishes first, and the save then brings the note back.
class _SlowStorage implements StorageInterface {
  final _inner = InMemoryStorage();
  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<void> set(String c, String id, Map<String, dynamic> d) async { await _wait(c == LocalNoteRepository.collection ? 40 : 1); await _inner.set(c, id, d); }
  @override
  Future<Map<String, dynamic>?> get(String c, String id) => _inner.get(c, id);
  @override
  Future<List<Map<String, dynamic>>> getAll(String c) => _inner.getAll(c);
  @override
  Future<void> delete(String c, String id) async { await _wait(1); await _inner.delete(c, id); }
  @override
  Future<void> clear(String c) => _inner.clear(c);
}

Note _note(String id, String title, DateTime at, {String? parentId, String content = 'Some text'}) =>
    Note(id: id, title: title, content: content, parentId: parentId, createdAt: at, updatedAt: at);

Future<void> _size(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int ms = 1500]) async {
  for (var i = 0; i < ms / 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _lines() => find.descendant(of: find.byType(BlockNoteEditor), matching: find.byType(EditableText));
TextEditingController _line(WidgetTester tester, [int i = 0]) => tester.widget<EditableText>(_lines().at(i)).controller;

Future<void> _chord(WidgetTester tester, LogicalKeyboardKey mod, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(mod);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(mod);
  await tester.pump();
}

void main() {
  testWidgets('deleting an ancestor right after typing in its open child keeps the subtree gone', (tester) async {
    await _size(tester);
    final local = LocalNoteRepository(storage: _SlowStorage());
    final repo = OfflineFirstNoteRepository(localRepo: local);
    await tester.runAsync(() async {
      await repo.saveNote(_note('top', 'Top', DateTime(2026, 1)));
      await repo.saveNote(_note('child', 'Child', DateTime(2026, 2), parentId: 'top'));
      await repo.saveNote(_note('other', 'Other', DateTime(2020)));
    });
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: DesktopShell(noteRepository: repo)));
    await _settle(tester);

    await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('note_row_top'))) + const Offset(12, 15));
    await _settle(tester, 200);
    await tester.tap(find.byKey(const ValueKey('note_row_child')));
    await _settle(tester, 500);
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Child');

    await tester.enterText(_lines().first, 'unsaved words');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('note_row_top')), buttons: kSecondaryMouseButton);
    await _settle(tester, 400);
    await tester.tap(find.text('Delete'));
    await _settle(tester, 400);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await _settle(tester, 2000);

    expect(await local.getNote('top'), isNull);
    expect(await local.getNote('child'), isNull);
    expect((await local.getAllNotes()).map((n) => n.id), ['other']);
    expect(tester.widget<TextField>(find.byKey(const Key('note_title_field'))).controller!.text, 'Other');
  });

  testWidgets('a save followed straight away by a delete leaves the note deleted', (tester) async {
    final local = LocalNoteRepository(storage: _SlowStorage());
    final repo = OfflineFirstNoteRepository(localRepo: local);
    await tester.runAsync(() async {
      await repo.saveNote(_note('a', 'A', DateTime(2026)));
      final save = repo.saveNote(_note('a', 'A edited', DateTime(2026)));
      final delete = repo.deleteNote('a');
      await Future.wait([save, delete]);
    });
    expect(await local.getNote('a'), isNull);
  });

  testWidgets('a failed write does not block later writes', (tester) async {
    final local = LocalNoteRepository(storage: InMemoryStorage());
    final repo = OfflineFirstNoteRepository(localRepo: local);
    await tester.runAsync(() async {
      await repo.deleteNote('missing');
      await repo.saveNote(_note('a', 'A', DateTime(2026)));
    });
    expect((await local.getNote('a'))?.title, 'A');
  });

  group('Rename', () {
    testWidgets('typing in the title after renaming the open note is kept', (tester) async {
      await _size(tester);
      final local = LocalNoteRepository(storage: InMemoryStorage());
      final repo = OfflineFirstNoteRepository(localRepo: local);
      await repo.saveNote(_note('a', 'First', DateTime(2026)));
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: DesktopShell(noteRepository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('note_row_a')), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rename_field')), 'Renamed');
      await tester.tap(find.widgetWithText(TextButton, 'Rename'));
      await tester.pumpAndSettle();

      final title = find.byKey(const Key('note_title_field'));
      expect(tester.widget<TextField>(title).controller!.text, 'Renamed');

      await tester.enterText(title, 'Renamed again');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const Key('desktop_hide_sidebar')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(title).controller!.text, 'Renamed again');
      expect((await local.getNote('a'))?.title, 'Renamed again');
    });
  });

  testWidgets('Escape in search puts the cursor in the open note', (tester) async {
    await _size(tester);
    final repo = OfflineFirstNoteRepository(localRepo: LocalNoteRepository(storage: InMemoryStorage()));
    await repo.saveNote(_note('a', 'First', DateTime(2026)));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: DesktopShell(noteRepository: repo)));
    await tester.pumpAndSettle();

    await _chord(tester, LogicalKeyboardKey.control, LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(_lines().first).focusNode.hasFocus, isTrue);
  });

  group('Editor shortcuts', () {
    Future<void> pumpEditor(WidgetTester tester, {required bool embedded}) async {
      await _size(tester);
      final repo = LocalNoteRepository(storage: InMemoryStorage());
      await repo.saveNote(_note('a', 'First', DateTime(2026), content: 'Faith comes'));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: NoteDetailScreen(noteId: 'a', noteRepository: repo, onNavigateToNote: embedded ? (_) {} : null),
      ));
      await tester.pumpAndSettle();
      await tester.tap(_lines().first);
      await tester.pump();
      _line(tester).selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();
    }

    List<InlineSpanSummary> summary(WidgetTester tester) => (_line(tester) as RichTextEditingController)
        .attributes
        .map((a) => InlineSpanSummary(a.type, a.start, a.end))
        .toList();

    for (final mod in [LogicalKeyboardKey.control, LogicalKeyboardKey.meta]) {
      testWidgets('${mod.keyLabel}+B bolds and +I italicizes only the selected text', (tester) async {
        await pumpEditor(tester, embedded: true);
        await _chord(tester, mod, LogicalKeyboardKey.keyB);
        await _chord(tester, mod, LogicalKeyboardKey.keyI);
        expect(summary(tester), [InlineSpanSummary('bold', 0, 5), InlineSpanSummary('italic', 0, 5)]);
      });
    }

    testWidgets('Tab and Shift+Tab change the indent', (tester) async {
      await pumpEditor(tester, embedded: true);
      final state = tester.state<BlockNoteEditorState>(find.byType(BlockNoteEditor));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(state.blocks.first.indentLevel, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
      expect(state.blocks.first.indentLevel, 0);
    });

    testWidgets('on phones these keys change nothing', (tester) async {
      await pumpEditor(tester, embedded: false);
      final state = tester.state<BlockNoteEditorState>(find.byType(BlockNoteEditor));

      await _chord(tester, LogicalKeyboardKey.control, LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(summary(tester), isEmpty);
      expect(state.blocks.first.indentLevel, 0);
    });
  });
}

class InlineSpanSummary {
  final String type;
  final int start;
  final int end;
  const InlineSpanSummary(this.type, this.start, this.end);
  @override
  bool operator ==(Object other) => other is InlineSpanSummary && other.type == type && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(type, start, end);
  @override
  String toString() => '$type $start-$end';
}
