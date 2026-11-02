import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/backup_store.dart';
import 'package:tigris/repositories/cloud_note_store.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/services/backup_service.dart';
import 'package:tigris/services/cloud_sync_service.dart';
import 'package:tigris/services/note_sync_engine.dart';

class _BackupStore implements BackupStore {
  String? json;

  @override
  Future<void> delete(BackupFile file) async {}

  @override
  Future<String> download(BackupFile file) async => json!;

  @override
  Future<List<BackupFile>> listBackups() async => const [];

  @override
  Future<BackupFile> upload({
    required String baseName,
    required String json,
    required String readable,
  }) async {
    this.json = json;
    return BackupFile(id: 'backup', name: '$baseName.json', createdAt: DateTime(2026));
  }
}

class _Cloud implements CloudNoteStore {
  final Map<String, CloudNoteRecord> records = {};
  int tick = 0;

  @override
  Future<List<CloudNoteRecord>> fetchChanged(String uid, DateTime? since) async => records.values.toList();

  @override
  Future<CloudNoteRecord> markDeleted(String uid, String id) async {
    final record = CloudNoteRecord(id: id, note: null, deleted: true, syncedAtMillis: ++tick);
    records[id] = record;
    return record;
  }

  @override
  Future<CloudNoteRecord> upsert(String uid, Note note) async {
    final record = CloudNoteRecord(id: note.id, note: note, deleted: false, syncedAtMillis: ++tick);
    records[note.id] = record;
    return record;
  }
}

Note _idea(String id) => Note(
  id: id,
  title: 'Idea',
  content: 'Text',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  workspace: Note.ideasWorkspace,
  ideaStatus: 'Ready',
  handedOffTo: 'Codex',
  handedOffAt: DateTime(2026, 2, 3),
);

void main() {
  test('missing workspace loads as notes and notes JSON omits workspace', () {
    final json = _idea('one').toJson()..remove('workspace');
    final notes = Note.fromJson(json);

    expect(notes.workspace, Note.notesWorkspace);
    expect(notes.toJson().containsKey('workspace'), isFalse);
    expect(_idea('two').toJson()['workspace'], Note.ideasWorkspace);
  });

  test('unknown workspace and status are discarded', () {
    final note = Note.fromJson({
      ..._idea('one').toJson(),
      'workspace': 'archive',
      'ideaStatus': 'Unknown',
    });

    expect(note.workspace, Note.notesWorkspace);
    expect(note.ideaStatus, isNull);
  });

  test('idea fields round trip through JSON and copyWith', () {
    final original = _idea('one');
    final restored = Note.fromJson(jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
    final copied = restored.copyWith(title: 'Changed');

    expect(copied.workspace, Note.ideasWorkspace);
    expect(copied.ideaStatus, 'Ready');
    expect(copied.handedOffTo, 'Codex');
    expect(copied.handedOffAt, DateTime(2026, 2, 3));
  });

  test('backup export and import retain idea workspace metadata', () async {
    final storage = InMemoryStorage();
    final local = LocalNoteRepository(storage: storage);
    final store = _BackupStore();
    final service = BackupService(notes: local, localRepo: local, storage: storage, store: store);
    await local.saveNote(_idea('idea'));

    final file = await service.backupNow();
    await local.deleteNote('idea');
    await service.restore(file!);
    final restored = (await local.getNote('idea'))!;

    expect(restored.workspace, Note.ideasWorkspace);
    expect(restored.ideaStatus, 'Ready');
    expect(restored.handedOffTo, 'Codex');
  });

  test('sync conflict copy keeps the original workspace', () async {
    final cloud = _Cloud();
    final firstStorage = InMemoryStorage();
    final secondStorage = InMemoryStorage();
    final firstLocal = LocalNoteRepository(storage: firstStorage);
    final secondLocal = LocalNoteRepository(storage: secondStorage);
    final first = NoteSyncEngine(storage: firstStorage, localRepo: firstLocal, cloud: cloud, status: CloudSyncService());
    final second = NoteSyncEngine(storage: secondStorage, localRepo: secondLocal, cloud: cloud, status: CloudSyncService());
    await firstLocal.saveNote(_idea('idea'));
    await first.sync('user');
    await second.sync('user');

    await firstLocal.saveNote(_idea('idea').copyWith(title: 'Phone', updatedAt: DateTime(2026, 1, 2)));
    await first.markDirty('idea');
    await secondLocal.saveNote(_idea('idea').copyWith(title: 'Desktop', updatedAt: DateTime(2026, 1, 3)));
    await second.markDirty('idea');
    await first.sync('user');
    await second.sync('user');

    final conflict = (await secondLocal.getAllNotes()).firstWhere((note) => note.title.endsWith('(conflict copy)'));
    expect(conflict.workspace, Note.ideasWorkspace);
  });
}
