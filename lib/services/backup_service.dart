import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../persistence/storage_interface.dart';
import '../repositories/backup_store.dart';
import '../repositories/local_note_repository.dart';
import '../repositories/note_repository.dart';
import 'backup_format.dart';

class BackupService {
  final NoteRepository notes;
  final LocalNoteRepository localRepo;
  final StorageInterface storage;
  final BackupStore store;
  final DateTime Function() now;
  static const _collection = 'backup_state';

  BackupService({required this.notes, required this.localRepo, required this.storage, required this.store, DateTime Function()? now}) : now = now ?? DateTime.now;

  String _stamp(List<Note> notes) {
    final latest = notes.map((note) => note.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    return '${notes.length}:${latest.toIso8601String()}';
  }

  Future<BackupFile?> backupNow({String suffix = ''}) async {
    final all = await notes.getAllNotes();
    if (all.isEmpty) return null;
    final createdAt = now();
    String two(int value) => value.toString().padLeft(2, '0');
    final baseName = 'tigris-backup-${createdAt.year}-${two(createdAt.month)}-${two(createdAt.day)}-${two(createdAt.hour)}${two(createdAt.minute)}${two(createdAt.second)}$suffix';
    final file = await store.upload(baseName: baseName, json: encodeBackup(all, createdAt), readable: renderReadable(all, createdAt));
    await storage.set(_collection, 'state', {'id': 'state', 'lastBackupAtMillis': createdAt.millisecondsSinceEpoch, 'lastBackupNoteStamp': _stamp(all)});
    try {
      final backups = await store.listBackups();
      for (final backup in backups.skip(10)) {
        await store.delete(backup);
      }
    } catch (error) {
      debugPrint('Drive backup retention failed: $error');
    }
    return file;
  }

  Future<bool> maybeAutoBackup() async {
    try {
      final all = await notes.getAllNotes();
      if (all.isEmpty) return false;
      final state = await storage.get(_collection, 'state');
      final last = state?['lastBackupAtMillis'] as int?;
      if (last != null && now().difference(DateTime.fromMillisecondsSinceEpoch(last)).inHours < 24) return false;
      if (state?['lastBackupNoteStamp'] == _stamp(all)) return false;
      return await backupNow() != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<BackupFile>> listBackups() => store.listBackups();

  Future<int> restore(BackupFile file) async {
    final restored = decodeBackup(await store.download(file));
    if ((await notes.getAllNotes()).isNotEmpty) await backupNow(suffix: '-before-restore');
    for (final note in restored) {
      await localRepo.clearDeletedNoteId(note.id);
      await notes.saveNote(note.copyWith(updatedAt: now()));
    }
    return restored.length;
  }
}
