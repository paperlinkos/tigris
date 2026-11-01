import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigris/models/note.dart';
import 'package:tigris/persistence/in_memory_storage.dart';
import 'package:tigris/repositories/cloud_note_store.dart';
import 'package:tigris/repositories/local_note_repository.dart';
import 'package:tigris/services/cloud_sync_service.dart';
import 'package:tigris/services/note_sync_engine.dart';

class _FakeCloudStore implements CloudNoteStore {
  final Map<String, Map<String, CloudNoteRecord>> _records = {};
  int _clock = 0;
  int upsertCount = 0;
  int fetchCount = 0;
  DateTime? lastSince;
  bool failing = false;
  void Function()? duringUpsert;

  @override
  Future<List<CloudNoteRecord>> fetchChanged(
    String uid,
    DateTime? since,
  ) async {
    fetchCount++;
    if (failing) throw TimeoutException('offline');
    lastSince = since;
    return (_records[uid]?.values ?? const <CloudNoteRecord>[])
        .where(
          (record) =>
              since == null ||
              record.syncedAtMillis >= since.millisecondsSinceEpoch,
        )
        .toList();
  }

  @override
  Future<CloudNoteRecord> upsert(String uid, Note note) async {
    if (failing) throw TimeoutException('offline');
    upsertCount++;
    final hook = duringUpsert;
    duringUpsert = null;
    hook?.call();
    final record = CloudNoteRecord(
      id: note.id,
      note: note,
      deleted: false,
      syncedAtMillis: ++_clock,
    );
    (_records[uid] ??= {})[note.id] = record;
    return record;
  }

  @override
  Future<CloudNoteRecord> markDeleted(String uid, String id) async {
    if (failing) throw TimeoutException('offline');
    final record = CloudNoteRecord(
      id: id,
      note: null,
      deleted: true,
      syncedAtMillis: ++_clock,
    );
    (_records[uid] ??= {})[id] = record;
    return record;
  }
}

Note _note(String id, String title) => Note(
  id: id,
  title: title,
  content: title,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

void main() {
  group('NoteSyncEngine', () {
    late _FakeCloudStore cloud;
    late InMemoryStorage firstStorage;
    late InMemoryStorage secondStorage;
    late LocalNoteRepository firstLocal;
    late LocalNoteRepository secondLocal;
    late NoteSyncEngine first;
    late NoteSyncEngine second;

    setUp(() {
      cloud = _FakeCloudStore();
      firstStorage = InMemoryStorage();
      secondStorage = InMemoryStorage();
      firstLocal = LocalNoteRepository(storage: firstStorage);
      secondLocal = LocalNoteRepository(storage: secondStorage);
      first = NoteSyncEngine(
        storage: firstStorage,
        localRepo: firstLocal,
        cloud: cloud,
        status: CloudSyncService(),
      );
      second = NoteSyncEngine(
        storage: secondStorage,
        localRepo: secondLocal,
        cloud: cloud,
        status: CloudSyncService(),
      );
    });

    test(
      'a local edit reaches another device and later sync is a delta',
      () async {
        await firstLocal.saveNote(_note('one', 'First'));
        await first.sync('uid');
        await second.sync('uid');
        expect((await secondLocal.getNote('one'))?.title, 'First');
        final writes = cloud.upsertCount;
        await second.sync('uid');
        expect(cloud.upsertCount, writes);
        expect(cloud.lastSince, isNotNull);
      },
    );

    test('deletes do not return after they reach another device', () async {
      await firstLocal.saveNote(_note('one', 'First'));
      await first.sync('uid');
      await second.sync('uid');
      await firstLocal.deleteNote('one');
      await first.sync('uid');
      await second.sync('uid');
      expect(await secondLocal.getNote('one'), isNull);
      await second.sync('uid');
      expect(await firstLocal.getNote('one'), isNull);
    });

    Future<void> edit(
      LocalNoteRepository local,
      NoteSyncEngine engine,
      String id,
      String title,
    ) async {
      final existing = await local.getNote(id);
      await local.saveNote(
        (existing ?? _note(id, title)).copyWith(
          title: title,
          content: title,
          updatedAt: DateTime.now(),
        ),
      );
      await engine.markDirty(id);
    }

    test('nested deletes reach another device and stay gone', () async {
      await firstLocal.saveNote(_note('parent', 'Parent'));
      await firstLocal.saveNote(
        _note('child', 'Child').copyWith(parentId: 'parent'),
      );
      await first.sync('uid');
      await second.sync('uid');
      expect(await secondLocal.getNote('child'), isNotNull);

      await firstLocal.deleteNote('parent');
      await first.sync('uid');
      await second.sync('uid');
      await first.sync('uid');

      for (final local in [firstLocal, secondLocal]) {
        expect(await local.getNote('parent'), isNull);
        expect(await local.getNote('child'), isNull);
      }
    });

    test('offline edits on two devices keep both versions', () async {
      await edit(firstLocal, first, 'one', 'Original');
      await first.sync('uid');
      await second.sync('uid');

      await edit(firstLocal, first, 'one', 'From phone');
      await edit(secondLocal, second, 'one', 'From laptop');
      await first.sync('uid');
      await second.sync('uid');
      await first.sync('uid');

      for (final local in [firstLocal, secondLocal]) {
        final titles = (await local.getAllNotes()).map((n) => n.title).toSet();
        expect(titles, {'From phone', 'From laptop (conflict copy)'});
      }
    });

    test('a conflict copy joins the same parent', () async {
      await firstLocal.saveNote(_note('parent', 'Parent'));
      await edit(firstLocal, first, 'parent', 'Parent');
      await firstLocal.saveNote(
        _note('one', 'Original').copyWith(parentId: 'parent'),
      );
      await first.sync('uid');
      await second.sync('uid');

      await edit(firstLocal, first, 'one', 'From phone');
      await edit(secondLocal, second, 'one', 'From laptop');
      await first.sync('uid');
      await second.sync('uid');

      final copy = (await secondLocal.getAllNotes()).firstWhere(
        (n) => n.title.endsWith('(conflict copy)'),
      );
      expect(copy.parentId, 'parent');
      expect((await secondLocal.getNote('parent'))!.childrenIds, contains(copy.id));
    });

    test('an edit outlives a delete from another device', () async {
      await edit(firstLocal, first, 'one', 'Original');
      await first.sync('uid');
      await second.sync('uid');

      await firstLocal.deleteNote('one');
      await edit(secondLocal, second, 'one', 'Still needed');
      await first.sync('uid');
      await second.sync('uid');
      await first.sync('uid');

      for (final local in [firstLocal, secondLocal]) {
        expect((await local.getNote('one'))?.title, 'Still needed');
      }
    });

    test('an edit made while uploading stays waiting to sync', () async {
      await edit(firstLocal, first, 'one', 'Version 1');
      Completer<void>? saved = Completer<void>();
      cloud.duringUpsert = () {
        edit(firstLocal, first, 'one', 'Version 2').then((_) => saved!.complete());
      };
      await first.sync('uid');
      await saved.future;
      saved = null;
      await first.sync('uid');
      await second.sync('uid');

      expect((await secondLocal.getNote('one'))?.title, 'Version 2');
    });

    test('a failed sync keeps pending work and finishes later', () async {
      final status = CloudSyncService();
      final engine = NoteSyncEngine(
        storage: firstStorage,
        localRepo: firstLocal,
        cloud: cloud,
        status: status,
      );
      await edit(firstLocal, engine, 'keep', 'Keep');
      await edit(firstLocal, engine, 'gone', 'Gone');
      await engine.sync('uid');
      await edit(firstLocal, engine, 'keep', 'Keep edited');
      await firstLocal.deleteNote('gone');

      cloud.failing = true;
      expect(await engine.sync('uid'), SyncOutcome.failed);
      expect(status.state, SyncState.offline);
      expect(await engine.pendingChangeCount(), 2);

      cloud.failing = false;
      expect(await engine.sync('uid'), SyncOutcome.synced);
      expect(status.state, SyncState.synced);
      expect(await engine.pendingChangeCount(), 0);

      await second.sync('uid');
      expect((await secondLocal.getNote('keep'))?.title, 'Keep edited');
      expect(await secondLocal.getNote('gone'), isNull);
    });

    test('another account is never contacted', () async {
      await edit(firstLocal, first, 'mine', 'Mine');
      await first.sync('first');
      await edit(firstLocal, first, 'mine', 'Mine, edited');
      final writes = cloud.upsertCount;
      final fetches = cloud.fetchCount;

      expect(await first.sync('second'), SyncOutcome.accountMismatch);

      expect(cloud.upsertCount, writes);
      expect(cloud.fetchCount, fetches);
      expect((await firstLocal.getNote('mine'))?.title, 'Mine, edited');
    });

    test('replacing with an account leaves only that account\'s notes', () async {
      await edit(secondLocal, second, 'theirs', 'Theirs');
      await second.sync('second');
      await edit(firstLocal, first, 'mine', 'Mine');
      await first.sync('first');

      await first.replaceLocalWithAccount('second');

      final titles = (await firstLocal.getAllNotes()).map((n) => n.title);
      expect(titles, ['Theirs']);
      await first.sync('second');
      expect(cloud.upsertCount, 2);
    });

    test('notes from before sync upload on the first sync', () async {
      await firstLocal.saveNote(_note('old', 'Old note'));
      expect(await first.sync('uid'), SyncOutcome.synced);
      await second.sync('uid');
      expect((await secondLocal.getNote('old'))?.title, 'Old note');
    });

    test('existing cloud notes merge by the newer edit', () async {
      await cloud.upsert('uid', _note('a', 'Cloud newer').copyWith(updatedAt: DateTime(2025)));
      await cloud.upsert('uid', _note('b', 'Cloud older').copyWith(updatedAt: DateTime(2023)));
      await firstLocal.saveNote(_note('a', 'Local older').copyWith(updatedAt: DateTime(2024)));
      await firstLocal.saveNote(_note('b', 'Local newer').copyWith(updatedAt: DateTime(2024)));

      await first.sync('uid');
      await second.sync('uid');

      for (final local in [firstLocal, secondLocal]) {
        expect((await local.getNote('a'))?.title, 'Cloud newer');
        expect((await local.getNote('b'))?.title, 'Local newer');
      }
    });

    test('a delete from before sync tracking is not undone', () async {
      await cloud.upsert('uid', _note('old', 'Deleted here'));
      await firstLocal.recordDeletedNoteId('old');

      await first.sync('uid');
      await second.sync('uid');

      expect(await firstLocal.getNote('old'), isNull);
      expect(await secondLocal.getNote('old'), isNull);
    });
  });
}
