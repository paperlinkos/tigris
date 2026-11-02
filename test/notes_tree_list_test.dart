import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/app/theme/app_theme.dart';
import 'package:tigris/app/theme/context_theme_extensions.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/widgets/home/notes_tree_list.dart';

Note _note(String id, String title, {String content = '', String? parentId}) => Note(id: id, title: title, content: content, parentId: parentId, createdAt: DateTime(2026), updatedAt: DateTime(2026));

Widget _tree(List<Note> notes, {bool compact = false, String? selected}) => MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: NotesTreeList(notes: notes, searchQuery: '', compact: compact, selectedNoteId: selected, onCreateNote: () {}, onOpenNote: (_) {}, onNoteMenu: (note, position) {})));

void main() {
  testWidgets('initial expanded ids show nested rows and report expansion changes', (tester) async {
    final notes = [_note('root', 'Root'), _note('child', 'Child', parentId: 'root'), _note('deep', 'Deep', parentId: 'child')];
    final changes = <Set<String>>[];
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: NotesTreeList(notes: notes, searchQuery: '', compact: true, selectedNoteId: null, initialExpandedIds: const {'root'}, onExpandedChanged: changes.add, onCreateNote: () {}, onOpenNote: (_) {}))));
    expect(find.text('Child'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    expect(changes.last, containsAll(<String>['root', 'child']));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: NotesTreeList(notes: notes, searchQuery: '', compact: true, selectedNoteId: 'deep', onExpandedChanged: changes.add, onCreateNote: () {}, onOpenNote: (_) {}))));
    await tester.pump();
    expect(changes.last, containsAll(<String>['root', 'child']));
  });

  testWidgets('compact hides dates and previews, and non-compact shows them', (tester) async {
    final note = _note('one', 'Title', content: 'Preview text');
    await tester.pumpWidget(_tree([note], compact: true));
    expect(find.text('Title'), findsOneWidget);
    expect(find.textContaining('Preview text'), findsNothing);
    await tester.pumpWidget(_tree([note]));
    expect(find.textContaining('Preview text'), findsOneWidget);
  });

  testWidgets('the selected compact row uses appRowSelected', (tester) async {
    await tester.pumpWidget(_tree([_note('one', 'Title')], compact: true, selected: 'one'));
    final container = tester.widget<Container>(find.descendant(of: find.byKey(const ValueKey('note_row_one')), matching: find.byType(Container)).first);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, tester.element(find.text('Title')).appRowSelected);
  });

  testWidgets('the More button is hidden until hover', (tester) async {
    await tester.pumpWidget(_tree([_note('one', 'Title')], compact: true));
    expect(find.byTooltip('More'), findsNothing);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byKey(const ValueKey('note_row_one'))));
    await tester.pump();
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('changing selectedNoteId to a deep note expands its ancestors', (tester) async {
    final notes = [_note('root', 'Root'), _note('child', 'Child', parentId: 'root'), _note('deep', 'Deep', parentId: 'child')];
    await tester.pumpWidget(_tree(notes, compact: true));
    expect(find.text('Deep'), findsNothing);
    await tester.pumpWidget(_tree(notes, compact: true, selected: 'deep'));
    await tester.pump();
    expect(find.text('Deep'), findsOneWidget);
  });
}
