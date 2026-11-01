import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/note_block.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/screens/note_detail_screen.dart';
import 'package:tigris/widgets/editor/block_note_editor.dart';

void main() {
  List<NoteBlock> threeLines() => [
        NoteBlock(id: 'a', type: BlockType.text, content: 'Line A'),
        NoteBlock(id: 'b', type: BlockType.text, content: 'Line B'),
        NoteBlock(id: 'c', type: BlockType.text, content: 'Line C'),
      ];

  Future<ValueGetter<List<String>>> pumpEditor(WidgetTester tester) async {
    var latest = threeLines();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlockNoteEditor(
              blocks: latest,
              onChanged: (blocks) => latest = blocks,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => latest.map((b) => b.content).toList();
  }

  Offset handleOf(WidgetTester tester, int index) =>
      tester.getCenter(find.byIcon(Icons.drag_indicator_rounded).at(index));

  testWidgets('A mouse can drag a line straight away, without holding still', (tester) async {
    final order = await pumpEditor(tester);
    final start = handleOf(tester, 0);
    final below = tester.getBottomLeft(find.byType(TextFormField).at(2)) + const Offset(0, -2);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: start);
    await mouse.moveTo(start);
    await tester.pump();

    await mouse.down(start);
    await tester.pump(const Duration(milliseconds: 20));
    for (var i = 1; i <= 10; i++) {
      await mouse.moveTo(Offset.lerp(start, Offset(start.dx, below.dy), i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    await mouse.removePointer();

    expect(order(), ['Line B', 'Line C', 'Line A']);
  });

  testWidgets('A finger drags a line after a short press', (tester) async {
    final order = await pumpEditor(tester);
    final start = handleOf(tester, 2);
    final above = tester.getCenter(find.text('Line A')) + const Offset(0, -6);

    final finger = await tester.startGesture(start, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 1; i <= 10; i++) {
      await finger.moveTo(Offset.lerp(start, Offset(start.dx, above.dy), i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();

    expect(order(), ['Line C', 'Line A', 'Line B']);
  });

  testWidgets('A quick finger swipe on a handle does not move the line', (tester) async {
    final order = await pumpEditor(tester);
    final start = handleOf(tester, 0);

    final finger = await tester.startGesture(start, kind: PointerDeviceKind.touch);
    await finger.moveBy(const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 16));
    await finger.up();
    await tester.pumpAndSettle();

    expect(order(), ['Line A', 'Line B', 'Line C']);
  });

  group('On the real note page', () {
    Future<LocalNoteRepository> pumpNotePage(WidgetTester tester) async {
      final repo = LocalNoteRepository(storage: InMemoryStorage());
      final now = DateTime(2026, 1, 1);
      final note = Note(
        id: 'n',
        title: 'Drag test',
        content: '',
        blocksJson: '''[
          {"id":"a","type":"text","content":"Line A"},
          {"id":"b","type":"text","content":"Line B"},
          {"id":"c","type":"text","content":"Line C"}
        ]''',
        createdAt: now,
        updatedAt: now,
      );
      await repo.saveNote(note);
      await tester.pumpWidget(MaterialApp(
        home: NoteDetailScreen(noteId: 'n', initialNote: note, noteRepository: repo),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    List<String> shown(WidgetTester tester) => tester
        .widgetList<TextFormField>(find.descendant(of: find.byType(BlockNoteEditor), matching: find.byType(TextFormField)))
        .map((f) => f.controller!.text)
        .toList();

    for (final steps in [1, 10]) {
      testWidgets('a mouse drag in $steps step(s) moves the line', (tester) async {
        await pumpNotePage(tester);
        final start = handleOf(tester, 0);
        final target = tester.getBottomLeft(find.byType(TextFormField).at(2)) + const Offset(0, -2);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: start);
        await mouse.moveTo(start);
        await tester.pump();
        await mouse.down(start);
        await tester.pump(const Duration(milliseconds: 20));
        for (var i = 1; i <= steps; i++) {
          await mouse.moveTo(Offset.lerp(start, Offset(start.dx + 60, target.dy), i / steps)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 700));
        await mouse.removePointer();
        await tester.pumpAndSettle();

        expect(shown(tester), ['Line B', 'Line C', 'Line A']);
      });
    }

    testWidgets('a mouse drag with no frame drawn between events moves the line', (tester) async {
      await pumpNotePage(tester);
      final start = handleOf(tester, 0);
      final target = tester.getBottomLeft(find.byType(TextFormField).at(2)) + const Offset(0, -2);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: start);
      await mouse.moveTo(start);
      await tester.pump();
      await mouse.down(start);
      await mouse.moveTo(Offset(start.dx + 60, target.dy));
      await mouse.up();
      await tester.pumpAndSettle();
      await mouse.removePointer();
      await tester.pumpAndSettle();

      expect(shown(tester), ['Line B', 'Line C', 'Line A']);
    });
  });
}
