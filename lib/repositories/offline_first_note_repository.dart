import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../services/cloud_sync_service.dart';
import 'firestore_note_repository.dart';
import 'local_note_repository.dart';
import 'note_repository.dart';

class OfflineFirstNoteRepository implements NoteRepository {
  final LocalNoteRepository localRepo;
  final FirestoreNoteRepository? firestoreRepo;
  final CloudSyncService? syncService;

  OfflineFirstNoteRepository({
    required this.localRepo,
    this.firestoreRepo,
    this.syncService,
  });

  @override
  Future<Note?> getNote(String id) async {
    return await localRepo.getNote(id);
  }

  @override
  Future<List<Note>> getAllNotes() async {
    return await localRepo.getAllNotes();
  }

  @override
  Future<List<Note>> getRootNotes() async {
    return await localRepo.getRootNotes();
  }

  @override
  Future<List<Note>> getChildNotes(String parentId) async {
    return await localRepo.getChildNotes(parentId);
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 10}) async {
    return await localRepo.getRecentNotes(limit: limit);
  }

  @override
  Stream<List<Note>> watchRecentNotes({int limit = 10}) {
    return localRepo.watchRecentNotes(limit: limit);
  }

  @override
  Stream<List<Note>> watchAllNotes() {
    return localRepo.watchAllNotes();
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    return await localRepo.searchNotes(query);
  }

  @override
  Future<List<Note>> getAncestorPath(String noteId) async {
    return await localRepo.getAncestorPath(noteId);
  }

  @override
  Future<void> saveNote(Note note) async {
    // 1. ALWAYS save locally first (0ms latency, works 100% offline)
    await localRepo.saveNote(note);
    syncService?.setSavedLocally();

    // 2. Background sync to Firestore if cloud repo is available
    if (firestoreRepo != null) {
      unawaited(_syncNoteToCloud(note));
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    // 1. Delete locally first
    await localRepo.deleteNote(id);
    syncService?.setSavedLocally();

    // 2. Background delete from Firestore
    if (firestoreRepo != null) {
      unawaited(_deleteNoteFromCloud(id));
    }
  }

  Future<void> _syncNoteToCloud(Note note) async {
    if (firestoreRepo == null) return;
    try {
      syncService?.setSyncing();
      await firestoreRepo!.saveNote(note);
      syncService?.setSynced();
    } catch (e) {
      debugPrint('Cloud sync background error: $e');
      syncService?.setError('Cloud sync deferred (offline)');
    }
  }

  Future<void> _deleteNoteFromCloud(String id) async {
    if (firestoreRepo == null) return;
    try {
      syncService?.setSyncing();
      await firestoreRepo!.deleteNote(id);
      syncService?.setSynced();
    } catch (e) {
      debugPrint('Cloud delete background error: $e');
      syncService?.setError('Cloud sync deferred (offline)');
    }
  }

  /// Full bidirectional delta sync between local storage and Cloud Firestore
  Future<void> syncWithCloud() async {
    if (firestoreRepo == null) return;

    try {
      syncService?.setSyncing();

      final deletedIds = await localRepo.getDeletedNoteIds();
      // 1. Purge tombstones from Firestore first
      for (final deletedId in deletedIds) {
        try {
          await firestoreRepo!.deleteNote(deletedId);
          await localRepo.clearDeletedNoteId(deletedId);
        } catch (_) {}
      }

      final localNotes = await localRepo.getAllNotes();
      final cloudNotes = await firestoreRepo!.getAllNotes();

      final localMap = {for (final n in localNotes) n.id: n};
      final cloudMap = {for (final n in cloudNotes) n.id: n};

      // 2. Push local notes to cloud if missing or newer locally
      for (final localNote in localNotes) {
        if (deletedIds.contains(localNote.id)) continue;
        final cloudNote = cloudMap[localNote.id];
        if (cloudNote == null || localNote.updatedAt.isAfter(cloudNote.updatedAt)) {
          await firestoreRepo!.saveNote(localNote);
        }
      }

      // 3. Pull cloud notes to local if missing or newer in cloud (skipping deleted tombstones)
      for (final cloudNote in cloudNotes) {
        if (deletedIds.contains(cloudNote.id)) {
          try {
            await firestoreRepo!.deleteNote(cloudNote.id);
            await localRepo.clearDeletedNoteId(cloudNote.id);
          } catch (_) {}
          continue;
        }

        final localNote = localMap[cloudNote.id];
        if (localNote == null || cloudNote.updatedAt.isAfter(localNote.updatedAt)) {
          await localRepo.saveNote(cloudNote);
        }
      }

      syncService?.setSynced();
    } catch (e) {
      debugPrint('Bidirectional cloud sync error: $e');
      syncService?.setError('Sync offline');
    }
  }
}
