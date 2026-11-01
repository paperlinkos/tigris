import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import '../persistence/storage_interface.dart';
import '../repositories/cloud_note_store.dart';
import '../repositories/local_note_repository.dart';
import 'cloud_sync_service.dart';

enum SyncOutcome { synced, failed, accountMismatch }

class NoteSyncEngine {
  static const _stateCollection = 'sync_state';
  static const _metaId = '_meta';
  final StorageInterface storage;
  final LocalNoteRepository localRepo;
  final CloudNoteStore cloud;
  final CloudSyncService status;
  Future<SyncOutcome>? _active;
  bool _rerun = false;

  NoteSyncEngine({
    required this.storage,
    required this.localRepo,
    required this.cloud,
    required this.status,
  });

  Future<void> markDirty(String noteId) async {
    final existing = await _state(noteId);
    await _setState(
      noteId,
      dirty: true,
      base: existing?['baseSyncedAtMillis'] as int?,
    );
  }

  Future<int> pendingChangeCount() async {
    final states = await storage.getAll(_stateCollection);
    final dirty = states
        .where((s) => s['id'] != _metaId && s['dirty'] == true)
        .length;
    return dirty + (await localRepo.getDeletedNoteIds()).length;
  }

  Future<SyncOutcome> sync(String uid) {
    if (_active != null) {
      _rerun = true;
      return _active!;
    }
    final completer = Completer<SyncOutcome>();
    _active = completer.future;
    () async {
      SyncOutcome result;
      do {
        _rerun = false;
        result = await _syncOnce(uid);
      } while (_rerun && result != SyncOutcome.accountMismatch);
      _active = null;
      completer.complete(result);
    }();
    return completer.future;
  }

  Future<void> replaceLocalWithAccount(String uid) async {
    await storage.clear(LocalNoteRepository.collection);
    await storage.clear(LocalNoteRepository.deletedCollection);
    await storage.clear(_stateCollection);
    await storage.set(_stateCollection, _metaId, {
      'id': _metaId,
      'ownerUid': uid,
    });
    await localRepo.notifyChanged();
    await sync(uid);
  }

  Future<SyncOutcome> _syncOnce(String uid) async {
    final meta = await _meta();
    final owner = meta['ownerUid'] as String?;
    if (owner == null) {
      await _setMeta(ownerUid: uid, cursor: meta['cursorMillis'] as int?);
    } else if (owner != uid) {
      status.setAccountMismatch();
      return SyncOutcome.accountMismatch;
    }
    status.setSyncing();
    try {
      final currentMeta = await _meta();
      final cursor = currentMeta['cursorMillis'] as int?;
      final records = await cloud.fetchChanged(
        uid,
        cursor == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                cursor,
              ).subtract(const Duration(minutes: 5)),
      );
      var highest = cursor ?? 0;
      final remoteNotes = <Note>[];
      final remoteDeletes = <String>[];
      // State is recorded only after the notes are written, so a failure in
      // between re-applies them on the next sync instead of skipping them.
      final afterApply = <Future<void> Function()>[];
      for (final record in records) {
        if (record.syncedAtMillis > highest) highest = record.syncedAtMillis;
        await _reconcilePull(record, remoteNotes, remoteDeletes, afterApply);
      }
      if (remoteNotes.isNotEmpty) await localRepo.applyRemoteNotes(remoteNotes);
      if (remoteDeletes.isNotEmpty) {
        await localRepo.applyRemoteDeletes(remoteDeletes);
      }
      for (final step in afterApply) {
        await step();
      }
      await _setMeta(ownerUid: uid, cursor: highest == 0 ? cursor : highest);

      final allLocal = await localRepo.getAllNotes();
      for (final note in allLocal) {
        if (await _state(note.id) == null) {
          await _setState(note.id, dirty: true, base: null);
        }
      }

      final tombstones = await localRepo.getDeletedNoteIds();
      for (final id in tombstones) {
        final stored = await cloud.markDeleted(uid, id);
        if (stored.syncedAtMillis > highest) highest = stored.syncedAtMillis;
        await localRepo.clearDeletedNoteId(id);
        await _removeState(id);
      }
      final states = await storage.getAll(_stateCollection);
      for (final state in states.where(
        (s) => s['id'] != _metaId && s['dirty'] == true,
      )) {
        final id = state['id'] as String;
        final note = await localRepo.getNote(id);
        if (note == null) continue;
        final savedUpdatedAt = note.updatedAt;
        final stored = await cloud.upsert(uid, note);
        if (stored.syncedAtMillis > highest) highest = stored.syncedAtMillis;
        final after = await localRepo.getNote(id);
        await _setState(
          id,
          dirty: after?.updatedAt != savedUpdatedAt,
          base: stored.syncedAtMillis,
        );
      }
      if (highest > (cursor ?? 0)) {
        await _setMeta(ownerUid: uid, cursor: highest);
      }
      status.setSynced();
      return SyncOutcome.synced;
    } catch (error) {
      if (_isOffline(error)) {
        status.setOffline();
      } else {
        status.setError(error.toString());
      }
      return SyncOutcome.failed;
    }
  }

  Future<void> _reconcilePull(
    CloudNoteRecord record,
    List<Note> notes,
    List<String> deletes,
    List<Future<void> Function()> afterApply,
  ) async {
    final local = await localRepo.getNote(record.id);
    final state = await _state(record.id);
    final tombstones = await localRepo.getDeletedNoteIds();
    final hasTombstone = tombstones.contains(record.id);
    final base = state?['baseSyncedAtMillis'] as int?;
    if (hasTombstone) {
      if (record.deleted) {
        await localRepo.clearDeletedNoteId(record.id);
        await _removeState(record.id);
      } else if (state != null && record.syncedAtMillis != base) {
        // With no state, the delete predates sync tracking, so it stands.
        if (record.note != null) notes.add(record.note!);
        afterApply.add(() async {
          await localRepo.clearDeletedNoteId(record.id);
          await _setState(record.id, dirty: false, base: record.syncedAtMillis);
        });
      }
      return;
    }
    if (record.deleted) {
      if (local == null) {
        await _removeState(record.id);
      } else if (state?['dirty'] == true && base != record.syncedAtMillis) {
        await _setState(record.id, dirty: true, base: record.syncedAtMillis);
      } else {
        deletes.add(record.id);
        afterApply.add(() => _removeState(record.id));
      }
      return;
    }
    final cloudNote = record.note!;
    if (local == null) {
      notes.add(cloudNote);
      afterApply.add(
        () => _setState(record.id, dirty: false, base: record.syncedAtMillis),
      );
      return;
    }
    if (state == null) {
      final cloudNewer = cloudNote.updatedAt.isAfter(local.updatedAt);
      if (cloudNewer) notes.add(cloudNote);
      afterApply.add(
        () => _setState(
          record.id,
          dirty: !cloudNewer && local.updatedAt.isAfter(cloudNote.updatedAt),
          base: record.syncedAtMillis,
        ),
      );
      return;
    }
    if (state['dirty'] != true) {
      if (record.syncedAtMillis != base) notes.add(cloudNote);
      afterApply.add(
        () => _setState(record.id, dirty: false, base: record.syncedAtMillis),
      );
      return;
    }
    if (record.syncedAtMillis == base) return;
    if (_sameContent(local, cloudNote)) {
      await _setState(record.id, dirty: false, base: record.syncedAtMillis);
      return;
    }
    final conflict = local.copyWith(
      id: 'conflict_${DateTime.now().millisecondsSinceEpoch}_${local.id}',
      title: '${local.title} (conflict copy)',
      childrenIds: const [],
      updatedAt: DateTime.now(),
    );
    await localRepo.applyRemoteNotes([conflict]);
    await _setState(conflict.id, dirty: true, base: null);
    if (local.parentId != null) {
      final parent = await localRepo.getNote(local.parentId!);
      if (parent != null && !parent.childrenIds.contains(conflict.id)) {
        await localRepo.saveNote(
          parent.copyWith(
            childrenIds: [...parent.childrenIds, conflict.id],
            updatedAt: DateTime.now(),
          ),
        );
        await markDirty(parent.id);
      }
    }
    notes.add(cloudNote);
    afterApply.add(
      () => _setState(record.id, dirty: false, base: record.syncedAtMillis),
    );
  }

  bool _sameContent(Note a, Note b) =>
      a.title == b.title &&
      a.content == b.content &&
      a.blocksJson == b.blocksJson;
  bool _isOffline(Object error) =>
      error is TimeoutException ||
      error is SocketException ||
      (error is FirebaseException && error.code == 'unavailable');
  Future<Map<String, dynamic>> _meta() async =>
      await storage.get(_stateCollection, _metaId) ?? {'id': _metaId};
  Future<Map<String, dynamic>?> _state(String id) =>
      storage.get(_stateCollection, id);
  Future<void> _setMeta({required String ownerUid, required int? cursor}) =>
      storage.set(_stateCollection, _metaId, {
        'id': _metaId,
        'ownerUid': ownerUid,
        'cursorMillis': ?cursor,
      });
  Future<void> _setState(
    String id, {
    required bool dirty,
    required int? base,
  }) => storage.set(_stateCollection, id, {
    'id': id,
    'dirty': dirty,
    'baseSyncedAtMillis': ?base,
  });
  Future<void> _removeState(String id) => storage.delete(_stateCollection, id);
}
