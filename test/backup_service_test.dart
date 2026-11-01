import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/backup_store.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/services/backup_format.dart';
import 'package:tigris/services/backup_service.dart';

class Store implements BackupStore {
  final files = <BackupFile>[]; final data = <String, String>{}; bool fail = false; bool failDelete = false; bool failUpload = false; int counter = 0;
  @override Future<void> delete(BackupFile file) async { if (failDelete) throw Exception(); files.removeWhere((x) => x.id == file.id); }
  @override Future<String> download(BackupFile file) async => data[file.id]!;
  @override Future<List<BackupFile>> listBackups() async { if (fail) throw Exception(); return List.of(files)..sort((a,b) => b.createdAt.compareTo(a.createdAt)); }
  @override Future<BackupFile> upload({required String baseName, required String json, required String readable}) async { if (fail || failUpload) throw Exception(); final file = BackupFile(id: 'f${counter++}', name: '$baseName.json', createdAt: DateTime.now()); files.add(file); data[file.id] = json; return file; }
}
Note n(String id, String title) => Note(id:id,title:title,content:title,createdAt:DateTime(2024),updatedAt:DateTime(2024));
void main() {
  test('backup writes contents and state; zero notes writes nothing', () async {
    final storage = InMemoryStorage(); final local = LocalNoteRepository(storage: storage); final store = Store(); final service = BackupService(notes: local, localRepo: local, storage: storage, store: store);
    expect(await service.backupNow(), isNull);
    await local.saveNote(n('one', 'One'));
    expect(await service.backupNow(), isNotNull);
    expect(store.data.values.single, contains('tigris-backup'));
    expect(await storage.get('backup_state', 'state'), isNotNull);
  });
  test('retention keeps ten and failure does not fail backup', () async {
    final storage = InMemoryStorage(); final local = LocalNoteRepository(storage: storage); final store = Store(); final service = BackupService(notes: local, localRepo: local, storage: storage, store: store);
    await local.saveNote(n('one', 'One'));
    for (var i = 0; i < 11; i++) { await service.backupNow(suffix: '-$i'); }
    expect(store.files.length, 10);
    store.failDelete = true;
    expect(await service.backupNow(), isNotNull);
  });

  group('automatic backup', () {
    late InMemoryStorage storage;
    late LocalNoteRepository local;
    late Store store;
    late DateTime clock;
    late BackupService service;

    setUp(() async {
      storage = InMemoryStorage();
      local = LocalNoteRepository(storage: storage);
      store = Store();
      clock = DateTime(2026, 1, 1, 9);
      service = BackupService(notes: local, localRepo: local, storage: storage, store: store, now: () => clock);
      await local.saveNote(n('one', 'One'));
    });

    test('runs the first time, then waits at least 24 hours', () async {
      expect(await service.maybeAutoBackup(), isTrue);
      await local.saveNote(n('two', 'Two'));
      clock = clock.add(const Duration(hours: 23));
      expect(await service.maybeAutoBackup(), isFalse);
      clock = clock.add(const Duration(hours: 2));
      expect(await service.maybeAutoBackup(), isTrue);
      expect(store.files, hasLength(2));
    });

    test('skips when nothing changed, so old backups are not rotated away', () async {
      expect(await service.maybeAutoBackup(), isTrue);
      clock = clock.add(const Duration(days: 3));
      expect(await service.maybeAutoBackup(), isFalse);
      expect(store.files, hasLength(1));
    });

    test('skips with no notes and swallows store failures', () async {
      await local.deleteNote('one');
      expect(await service.maybeAutoBackup(), isFalse);
      await local.saveNote(n('one', 'One'));
      store.fail = true;
      expect(await service.maybeAutoBackup(), isFalse);
    });
  });

  group('restore', () {
    late InMemoryStorage storage;
    late LocalNoteRepository local;
    late Store store;
    late BackupService service;

    setUp(() {
      storage = InMemoryStorage();
      local = LocalNoteRepository(storage: storage);
      store = Store();
      service = BackupService(notes: local, localRepo: local, storage: storage, store: store);
    });

    test('replaces matching notes, keeps others, revives deleted notes', () async {
      await local.saveNote(n('edited', 'Original'));
      await local.saveNote(n('deleted', 'Deleted later'));
      final backup = (await service.backupNow())!;

      await local.saveNote(n('edited', 'Changed'));
      await local.deleteNote('deleted');
      await local.saveNote(n('newer', 'Written after the backup'));
      final uploadsBefore = store.files.length;

      expect(await service.restore(backup), 2);

      expect((await local.getNote('edited'))?.title, 'Original');
      expect((await local.getNote('deleted'))?.title, 'Deleted later');
      expect((await local.getNote('newer'))?.title, 'Written after the backup');
      expect(await local.getDeletedNoteIds(), isEmpty);
      expect(store.files, hasLength(uploadsBefore + 1));
      expect(store.files.last.name, contains('-before-restore'));
    });

    test('a corrupt file changes nothing and uploads nothing', () async {
      await local.saveNote(n('one', 'One'));
      final backup = (await service.backupNow())!;
      store.data[backup.id] = '{broken';
      await local.saveNote(n('one', 'Current'));
      final uploadsBefore = store.files.length;

      await expectLater(service.restore(backup), throwsA(isA<BackupFormatException>()));

      expect((await local.getNote('one'))?.title, 'Current');
      expect(store.files, hasLength(uploadsBefore));
    });

    test('stops with nothing changed if the safety backup fails', () async {
      await local.saveNote(n('one', 'One'));
      final backup = (await service.backupNow())!;
      await local.saveNote(n('one', 'Current'));
      store.failUpload = true;

      await expectLater(service.restore(backup), throwsA(anything));

      expect((await local.getNote('one'))?.title, 'Current');
    });

    test('works with no local notes and makes no safety backup', () async {
      await local.saveNote(n('one', 'One'));
      final backup = (await service.backupNow())!;
      await local.deleteNote('one');
      final uploadsBefore = store.files.length;

      expect(await service.restore(backup), 1);

      expect((await local.getNote('one'))?.title, 'One');
      expect(store.files, hasLength(uploadsBefore));
    });
  });
}
