import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';

void main() {
  group('FirestoreNoteRepository Data Contract Tests', () {
    test('Note JSON serialization maps correctly for Firestore schema', () {
      final note = Note(
        id: 'fs_note_1',
        parentId: 'fs_root',
        title: 'Firestore Sync Note',
        subtitle: 'Cloud notes test',
        content: 'Testing Cloud Firestore data model',
        childrenIds: ['fs_child_1', 'fs_child_2'],
        createdAt: DateTime(2026, 9, 22, 12, 0),
        updatedAt: DateTime(2026, 9, 22, 12, 30),
      );

      final json = note.toJson();
      expect(json['id'], equals('fs_note_1'));
      expect(json['parentId'], equals('fs_root'));
      expect(json['title'], equals('Firestore Sync Note'));
      expect(json['childrenIds'], equals(['fs_child_1', 'fs_child_2']));

      final restored = Note.fromJson(json);
      expect(restored.id, equals(note.id));
      expect(restored.parentId, equals(note.parentId));
      expect(restored.title, equals(note.title));
      expect(restored.childrenIds, equals(note.childrenIds));
      expect(restored.updatedAt, equals(note.updatedAt));
    });
  });
}
