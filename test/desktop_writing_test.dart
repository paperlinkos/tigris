import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/navigation/desktop_shell.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/widgets/editor/block_note_editor.dart';

Note _note(String id, String title, {String? parentId, String content = 'First line\nSecond line'}) {
  final now = DateTime(2026);
  return Note(id: id, title: title, content: content, parentId: parentId, createdAt: now, updatedAt: now);
}

Future<LocalNoteRepository> _pump(WidgetTester tester, List<Note> notes, String openId, {bool embedded = true}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = LocalNoteRepository(storage: InMemoryStorage());
  for (final note in notes) {
    await repo.saveNote(note);
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: NoteDetailScreen(
      noteId: openId,
      noteRepository: repo,
      onNavigateToNote: embedded ? (_) {} : null,
    ),
  ));
  await tester.pumpAndSettle();
  return repo;
}

Finder _line(int index) => find.descendant(of: find.byType(BlockNoteEditor), matching: find.byType(EditableText)).at(index);

TextEditingController _controller(WidgetTester tester, int index) => tester.widget<EditableText>(_line(index)).controller;

Future<void> _select(WidgetTester tester, int line, int start, int end) async {
  await tester.tap(_line(line));
  await tester.pump();
  _controller(tester, line).selection = TextSelection(baseOffset: start, extentOffset: end);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, int line, String text) async {
  await tester.tap(_line(line));
  await tester.pump();
  await tester.enterText(_line(line), text);
  await tester.pumpAndSettle();
}

void main() {
  group('Breadcrumb', () {
    testWidgets('shows the path and is hidden on a top-level note', (tester) async {
      await _pump(tester, [_note('a', 'Alpha'), _note('b', 'Beta', parentId: 'a')], 'b');
      expect(find.descendant(of: find.byKey(const Key('note_breadcrumb')), matching: find.text('Alpha')), findsOneWidget);

      await _pump(tester, [_note('a', 'Alpha')], 'a');
      expect(find.descendant(of: find.byKey(const Key('note_breadcrumb')), matching: find.byType(InkWell)), findsNothing);
    });

    testWidgets('collapses the middle of a deep path', (tester) async {
      await _pump(tester, [
        _note('a', 'One'),
        _note('b', 'Two', parentId: 'a'),
        _note('c', 'Three', parentId: 'b'),
        _note('d', 'Four', parentId: 'c'),
        _note('e', 'Five', parentId: 'd'),
      ], 'e');
      final crumb = find.byKey(const Key('note_breadcrumb'));
      expect(find.descendant(of: crumb, matching: find.text('One')), findsOneWidget);
      expect(find.descendant(of: crumb, matching: find.text('...')), findsOneWidget);
      expect(find.descendant(of: crumb, matching: find.text('Two')), findsNothing);
      expect(find.descendant(of: crumb, matching: find.text('Four')), findsOneWidget);
    });
  });

  group('Selection toolbar', () {
    testWidgets('appears only over selected text', (tester) async {
      await _pump(tester, [_note('a', 'Alpha')], 'a');
      await tester.tap(_line(0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('format_bold')), findsNothing);

      await _select(tester, 0, 0, 5);
      expect(find.byKey(const Key('format_bold')), findsOneWidget);

      _controller(tester, 0).selection = const TextSelection.collapsed(offset: 2);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('format_bold')), findsNothing);
    });

    testWidgets('bold applies to the selected words only and keeps focus', (tester) async {
      await _pump(tester, [_note('a', 'Alpha')], 'a');
      await _select(tester, 0, 0, 5);

      await tester.tap(find.byKey(const Key('format_bold')));
      await tester.pumpAndSettle();

      final attrs = (_controller(tester, 0) as RichTextEditingController).attributes;
      expect(attrs.single.start, 0);
      expect(attrs.single.end, 5);
      expect(attrs.single.type, 'bold');
      expect(tester.widget<EditableText>(_line(0)).focusNode.hasFocus, isTrue);
      expect(find.byKey(const Key('format_bold')), findsOneWidget);
    });

    testWidgets('list buttons change the line type', (tester) async {
      await _pump(tester, [_note('a', 'Alpha')], 'a');
      await _select(tester, 0, 0, 5);

      await tester.tap(find.byKey(const Key('format_bullet_list')));
      await tester.pumpAndSettle();

      expect(find.text('•'), findsOneWidget);
    });

    testWidgets('the bottom bar stays away on big screens and stays on phones', (tester) async {
      await _pump(tester, [_note('a', 'Alpha')], 'a');
      await tester.tap(_line(0));
      await tester.pumpAndSettle();
      expect(find.text('+'), findsNothing);

      await _pump(tester, [_note('a', 'Alpha')], 'a', embedded: false);
      await tester.tap(_line(0));
      await tester.pumpAndSettle();
      expect(find.text('+'), findsOneWidget);
      expect(find.byKey(const Key('format_bold')), findsNothing);
    });
  });

  group('Slash menu', () {
    testWidgets('opens on /, filters and closes', (tester) async {
      await _pump(tester, [_note('a', 'Alpha', content: '')], 'a');
      await _type(tester, 0, '/');
      expect(find.byKey(const Key('slash_menu')), findsOneWidget);
      expect(find.text('Divider'), findsOneWidget);

      await _type(tester, 0, '/hea');
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('Divider'), findsNothing);

      await _type(tester, 0, '/zzz');
      expect(find.text('No matching type.'), findsOneWidget);

      await _type(tester, 0, 'plain');
      expect(find.byKey(const Key('slash_menu')), findsNothing);
    });

    testWidgets('arrow keys and Enter pick a type and clear the slash', (tester) async {
      await _pump(tester, [_note('a', 'Alpha', content: '')], 'a');
      await _type(tester, 0, '/');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slash_menu')), findsNothing);
      expect(_controller(tester, 0).text, '');
      expect(find.text('•'), findsOneWidget);
    });

    testWidgets('Escape closes it and keeps what was typed', (tester) async {
      await _pump(tester, [_note('a', 'Alpha', content: '')], 'a');
      await _type(tester, 0, '/note');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slash_menu')), findsNothing);
      expect(_controller(tester, 0).text, '/note');
    });

    testWidgets('Divider adds a divider and a line to keep writing on', (tester) async {
      await _pump(tester, [_note('a', 'Alpha', content: '')], 'a');
      await _type(tester, 0, '/div');
      await tester.tap(find.text('Divider'));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
      expect(_line(0), findsOneWidget);
    });

    testWidgets('Page inside asks for a name and creates a nested note', (tester) async {
      final repo = await _pump(tester, [_note('a', 'Alpha', content: '')], 'a');
      await _type(tester, 0, '/page');
      await tester.tap(find.text('Page inside'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('new_page_name_field')), 'Chapter one');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final children = await repo.getChildNotes('a');
      expect(children.single.title, 'Chapter one');
    });

    testWidgets('typing / has no menu on phones', (tester) async {
      await _pump(tester, [_note('a', 'Alpha', content: '')], 'a', embedded: false);
      await _type(tester, 0, '/');
      expect(find.byKey(const Key('slash_menu')), findsNothing);
    });
  });

  testWidgets('hiding the sidebar moves the breadcrumb clear of the show button', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = LocalNoteRepository(storage: InMemoryStorage());
    await repo.saveNote(_note('a', 'Alpha'));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: DesktopShell(noteRepository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('desktop_hide_sidebar')));
    await tester.pumpAndSettle();

    final button = tester.getRect(find.byKey(const Key('desktop_show_sidebar')));
    final crumb = tester.getRect(find.byKey(const Key('note_breadcrumb')));
    expect(crumb.left, greaterThanOrEqualTo(button.right));
  });

  for (final embedded in [true, false]) {
    testWidgets('Enter in the title moves to the body and typing lands there (embedded: $embedded)', (tester) async {
      await _pump(tester, [_note('a', 'Alpha', content: '')], 'a', embedded: embedded);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      final body = tester.widget<EditableText>(_line(0));
      expect(body.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      tester.testTextInput.enterText('typed after enter');
      await tester.pumpAndSettle();
      expect(body.controller.text, 'typed after enter');
    });
  }
}
