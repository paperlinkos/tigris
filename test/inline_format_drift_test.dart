import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note_block.dart';
import 'package:tigris/widgets/editor/block_note_editor.dart';

void main() {
  const bold = 'bold';

  RichTextEditingController withBold(String text, int start, int end) => RichTextEditingController(
        text: text,
        attributes: [InlineAttribute(start: start, end: end, type: bold)],
      );

  String boldText(RichTextEditingController c) {
    final a = c.attributes.single;
    return c.text.substring(a.start, a.end);
  }

  test('typing before bold text moves the bold with the word', () {
    final c = withBold('Faith comes', 6, 11);
    c.text = 'My Faith comes';
    expect(boldText(c), 'comes');
  });

  test('typing after bold text leaves it alone', () {
    final c = withBold('Faith comes', 0, 5);
    c.text = 'Faith comes by hearing';
    expect(boldText(c), 'Faith');
  });

  test('typing right after a bold word does not extend the bold', () {
    final c = withBold('Faith', 0, 5);
    c.text = 'Faith!';
    expect(boldText(c), 'Faith');
  });

  test('typing right before a bold word does not extend the bold', () {
    final c = withBold('Faith', 0, 5);
    c.text = 'Faith'.replaceRange(0, 0, 'x');
    expect(boldText(c), 'Faith');
  });

  test('typing inside bold text extends it', () {
    final c = withBold('Faith comes', 0, 5);
    c.text = 'Faiith comes';
    expect(boldText(c), 'Faiith');
  });

  test('deleting before bold text moves the bold back', () {
    final c = withBold('My Faith', 3, 8);
    c.text = 'Faith';
    expect(boldText(c), 'Faith');
  });

  test('deleting part of bold text shrinks it', () {
    final c = withBold('Faith comes', 0, 5);
    c.text = 'Fa comes';
    expect(boldText(c), 'Fa');
  });

  test('deleting all of the bold text removes the formatting', () {
    final c = withBold('Faith comes', 0, 6);
    c.text = 'comes';
    expect(c.attributes, isEmpty);
  });

  test('a repeated letter is handled at the point of the change', () {
    final c = withBold('aaa bbb', 4, 7);
    c.text = 'aaaa bbb';
    expect(boldText(c), 'bbb');
  });

  test('moving the cursor changes nothing', () {
    final c = withBold('Faith comes', 6, 11);
    c.selection = const TextSelection.collapsed(offset: 2);
    expect(boldText(c), 'comes');
  });

  test('replacing selected text before bold text moves the bold', () {
    final c = withBold('one two three', 8, 13);
    c.text = 'x two three';
    expect(boldText(c), 'three');
  });

  testWidgets('saved formatting follows typing in the editor', (tester) async {
    late List<NoteBlock> latest;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlockNoteEditor(
          blocks: [
            NoteBlock(
              id: 'a',
              type: BlockType.text,
              content: 'Faith comes',
              inlineAttributes: const [InlineAttribute(start: 6, end: 11, type: bold)],
            ),
          ],
          onChanged: (blocks) => latest = blocks,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'My Faith comes');
    await tester.pumpAndSettle();

    final saved = latest.single;
    final attr = saved.inlineAttributes.single;
    expect(saved.content.substring(attr.start, attr.end), 'comes');
  });

  testWidgets('merging lines keeps the second line formatting in place', (tester) async {
    late List<NoteBlock> latest;
    final key = GlobalKey<BlockNoteEditorState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlockNoteEditor(
          key: key,
          blocks: [
            NoteBlock(id: 'a', type: BlockType.text, content: 'First '),
            NoteBlock(
              id: 'b',
              type: BlockType.text,
              content: 'second',
              inlineAttributes: const [InlineAttribute(start: 0, end: 6, type: bold)],
            ),
          ],
          onChanged: (blocks) => latest = blocks,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextFormField).last);
    await tester.pump();
    final field = tester.widget<EditableText>(
      find.descendant(of: find.byType(TextFormField).last, matching: find.byType(EditableText)),
    );
    field.controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    key.currentState!.mergeLineIntoPrevious(1);
    await tester.pumpAndSettle();

    final merged = latest.single;
    final attr = merged.inlineAttributes.single;
    expect(merged.content, 'First second');
    expect(merged.content.substring(attr.start, attr.end), 'second');
  });
}
