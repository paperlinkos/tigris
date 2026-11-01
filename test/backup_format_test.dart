import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/services/backup_format.dart';

Note note(String id, {String title = 'Title', String? parentId, String? blocksJson}) => Note(id: id, title: title, content: 'body', parentId: parentId, blocksJson: blocksJson, createdAt: DateTime(2024), updatedAt: DateTime(2024));

void main() {
  test('round trip keeps note fields and non-English text', () {
    final original = note('1', title: 'Àlàáfíà', blocksJson: '[{"id":"b","type":"text","content":"你好","indentLevel":0}]');
    final decoded = decodeBackup(encodeBackup([original], DateTime.utc(2025)));
    expect(decoded.single.toJson(), original.toJson());
  });

  test('decode rejects invalid backup shapes', () {
    expect(() => decodeBackup('no'), throwsA(isA<BackupFormatException>()));
    expect(() => decodeBackup('{"format":"other","version":1,"noteCount":0,"notes":[]}'), throwsA(isA<BackupFormatException>()));
    expect(() => decodeBackup('{"format":"tigris-backup","version":2,"noteCount":0,"notes":[]}'), throwsA(isA<BackupFormatException>()));
    expect(() => decodeBackup('{"format":"tigris-backup","version":1,"noteCount":1,"notes":[]}'), throwsA(isA<BackupFormatException>()));
    expect(() => decodeBackup('{"format":"tigris-backup","version":1,"noteCount":1,"notes":[{}]}'), throwsA(isA<BackupFormatException>()));
  });

  test('readable backup nests, renders blocks, and handles cycles and orphans', () {
    final rendered = renderReadable([note('parent', title: 'Parent', blocksJson: '[{"id":"h","type":"heading","content":"H","indentLevel":0},{"id":"b","type":"bullet","content":"B","indentLevel":1},{"id":"n","type":"number","content":"N","indentLevel":0},{"id":"d","type":"divider","content":"","indentLevel":0},{"id":"p","type":"page","content":"skip","indentLevel":0}]'), note('child', title: 'Child', parentId: 'parent'), note('a', title: 'a', parentId: 'b'), note('b', title: 'b', parentId: 'a'), note('orphan', title: 'Orphan', parentId: 'gone')], DateTime.utc(2025));
    expect(rendered, contains('## Parent'));
    expect(rendered, contains('### Child'));
    expect(rendered, contains('**H**'));
    expect(rendered, contains('  - B'));
    expect(rendered, contains('1. N'));
    expect(rendered, contains('---'));
    expect(rendered, isNot(contains('skip')));
    expect(rendered, contains('## a'));
    expect(rendered, contains('## Orphan'));
  });
}
