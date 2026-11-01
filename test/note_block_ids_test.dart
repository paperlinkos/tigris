import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/models/note_block.dart';

void main() {
  Note note({String content = '', String? blocksJson}) {
    final now = DateTime(2026);
    return Note(id: 'n', title: 'T', content: content, blocksJson: blocksJson, createdAt: now, updatedAt: now);
  }

  Set<String> idsOf(List<NoteBlock> blocks) => blocks.map((b) => b.id).toSet();

  test('new lines always get different ids', () {
    final blocks = List.generate(1000, (_) => NoteBlock(type: BlockType.text));
    expect(idsOf(blocks), hasLength(1000));
  });

  test('a multi-line note with no saved blocks gets different line ids', () {
    final blocks = note(content: 'one\ntwo\nthree\nfour').blocks;
    expect(blocks, hasLength(4));
    expect(idsOf(blocks), hasLength(4));
  });

  test('repeated ids in a saved note are repaired, keeping the text', () {
    final saved = jsonEncode([
      {'id': 'same', 'type': 'text', 'content': 'first'},
      {'id': 'same', 'type': 'text', 'content': 'second'},
    ]);
    final blocks = note(blocksJson: saved).blocks;
    expect(blocks.map((b) => b.content), ['first', 'second']);
    expect(idsOf(blocks), hasLength(2));
    expect(blocks.first.id, 'same');
  });
}
