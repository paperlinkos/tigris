import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../services/cloud_sync_service.dart';
import 'local_note_repository.dart';
import 'note_repository.dart';
import '../services/note_sync_engine.dart';

class OfflineFirstNoteRepository implements NoteRepository {
  final LocalNoteRepository localRepo;
  final CloudSyncService? syncService;
  final NoteSyncEngine? syncEngine;
  final VoidCallback? onLocalChange;
  final Future<void> Function()? onSyncRequested;

  // Writes run strictly in order, so a note's final save on closing can't land
  // after a delete that was requested later and bring the note back.
  Future<void>? _lastWrite;

  Future<void> _inOrder(Future<void> Function() write) {
    final previous = _lastWrite;
    final result = previous == null ? write() : previous.then((_) => write());
    late final Future<void> tracked;
    tracked = result.catchError((Object _) {}).whenComplete(() {
      if (identical(_lastWrite, tracked)) _lastWrite = null;
    });
    _lastWrite = tracked;
    return result;
  }

  OfflineFirstNoteRepository({
    required this.localRepo,
    this.syncService,
    this.syncEngine,
    this.onLocalChange,
    this.onSyncRequested,
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
  Future<void> saveNote(Note note) => _inOrder(() => _saveNote(note));

  Future<void> _saveNote(Note note) async {
    final noteWithRetention = note.offlineUntil == null
        ? note.copyWith(
            offlineUntil: DateTime.now().add(const Duration(days: 5)),
          )
        : note;

    await localRepo.saveNote(noteWithRetention);
    syncService?.setSavedLocally();
    await syncEngine?.markDirty(noteWithRetention.id);
    if (noteWithRetention.parentId != null) {
      await syncEngine?.markDirty(noteWithRetention.parentId!);
    }
    onLocalChange?.call();
  }

  @override
  Future<void> deleteNote(String id) => _inOrder(() => _deleteNote(id));

  Future<void> _deleteNote(String id) async {
    final note = await localRepo.getNote(id);
    await localRepo.deleteNote(id);
    syncService?.setSavedLocally();
    if (note?.parentId != null) await syncEngine?.markDirty(note!.parentId!);
    onLocalChange?.call();
  }

  Future<void> syncWithCloud() async {
    await onSyncRequested?.call();
  }
}
