import '../models/note.dart';

class CloudNoteRecord {
  final String id;
  final Note? note;
  final bool deleted;
  final int syncedAtMillis;

  const CloudNoteRecord({
    required this.id,
    required this.note,
    required this.deleted,
    required this.syncedAtMillis,
  });
}

abstract class CloudNoteStore {
  Future<List<CloudNoteRecord>> fetchChanged(String uid, DateTime? since);
  Future<CloudNoteRecord> upsert(String uid, Note note);
  Future<CloudNoteRecord> markDeleted(String uid, String id);
}
