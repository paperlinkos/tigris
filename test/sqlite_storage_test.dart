import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/preferences_storage.dart';
import 'package:tigris/persistence/sqlite_storage.dart';
import 'package:tigris/repositories/local_note_repository.dart';

void main() {
  sqfliteFfiInit();

  SqliteStorage newStorage({String path = inMemoryDatabasePath}) => SqliteStorage(
        factory: databaseFactoryFfiNoIsolate,
        path: path,
      );

  Note note(String id, {String? parentId}) {
    final now = DateTime(2026, 1, 1);
    return Note(id: id, title: 'Title $id', content: 'Body $id', parentId: parentId, createdAt: now, updatedAt: now);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await databaseFactoryFfiNoIsolate.deleteDatabase(inMemoryDatabasePath);
  });

  group('SqliteStorage documents', () {
    test('sets, gets, lists, deletes and clears within a collection', () async {
      final storage = newStorage();

      await storage.set('notes', 'a', {'title': 'A'});
      await storage.set('notes', 'b', {'title': 'B'});
      await storage.set('tasks', 'a', {'title': 'Task'});

      expect((await storage.get('notes', 'a'))!['title'], 'A');
      expect(await storage.get('notes', 'missing'), isNull);
      expect(await storage.getAll('notes'), hasLength(2));

      await storage.set('notes', 'a', {'title': 'A2'});
      expect((await storage.get('notes', 'a'))!['title'], 'A2');
      expect(await storage.getAll('notes'), hasLength(2));

      await storage.delete('notes', 'a');
      expect(await storage.get('notes', 'a'), isNull);

      await storage.clear('notes');
      expect(await storage.getAll('notes'), isEmpty);
      expect(await storage.getAll('tasks'), hasLength(1));
    });

    test('keeps nested notes through the note repository', () async {
      final repo = LocalNoteRepository(storage: newStorage());

      await repo.saveNote(note('parent'));
      await repo.saveNote(note('child', parentId: 'parent'));
      await repo.saveNote(note('grandchild', parentId: 'child'));

      expect((await repo.getRootNotes()).map((n) => n.id), ['parent']);
      expect((await repo.getChildNotes('child')).map((n) => n.id), ['grandchild']);
      expect((await repo.getNote('parent'))!.childrenIds, ['child']);
    });
  });

  group('Migration from SharedPreferences', () {
    String legacyKey(String collection) => '${PreferencesStorage.keyPrefix}$collection';

    test('copies every collection and leaves the original in place', () async {
      final notes = jsonEncode({'n1': note('n1').toJson(), 'n2': note('n2').toJson()});
      final tasks = jsonEncode({'t1': {'id': 't1', 'title': 'Pray'}});
      SharedPreferences.setMockInitialValues({legacyKey('notes'): notes, legacyKey('tasks'): tasks, 'unrelated': 'x'});

      final storage = newStorage();

      expect(await storage.getAll('notes'), hasLength(2));
      expect(Note.fromJson((await storage.get('notes', 'n1'))!).title, 'Title n1');
      expect((await storage.get('tasks', 't1'))!['title'], 'Pray');
      expect(await storage.getAll('unrelated'), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(legacyKey('notes')), notes);
    });

    test('runs once, so later edits and deletes are not undone', () async {
      final path = '${(await databaseFactoryFfiNoIsolate.getDatabasesPath())}/migrate_once_test.db';
      await databaseFactoryFfiNoIsolate.deleteDatabase(path);
      SharedPreferences.setMockInitialValues({
        legacyKey('notes'): jsonEncode({'n1': note('n1').toJson()}),
      });

      final first = newStorage(path: path);
      await first.delete('notes', 'n1');

      final reopened = newStorage(path: path);
      expect(await reopened.get('notes', 'n1'), isNull);

      await databaseFactoryFfiNoIsolate.deleteDatabase(path);
    });

    test('skips an unreadable collection without losing it or the others', () async {
      SharedPreferences.setMockInitialValues({
        legacyKey('notes'): '{broken',
        legacyKey('tasks'): jsonEncode({'t1': {'id': 't1'}}),
      });

      final storage = newStorage();

      expect(await storage.getAll('notes'), isEmpty);
      expect(await storage.getAll('tasks'), hasLength(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(legacyKey('notes')), '{broken');
    });
  });

  group('PreferencesStorage on web', () {
    test('refuses to overwrite data it cannot read', () async {
      const key = '${PreferencesStorage.keyPrefix}notes';
      SharedPreferences.setMockInitialValues({key: '{broken'});
      final storage = PreferencesStorage();

      await expectLater(storage.set('notes', 'new', {'title': 'New'}), throwsA(isA<StorageCorruptedException>()));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), '{broken');
    });
  });
}
