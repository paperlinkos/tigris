import '../models/note.dart';
import '../persistence/storage_interface.dart';
import 'note_repository.dart';

class LocalNoteRepository implements NoteRepository {
  static const String collection = 'notes';
  final StorageInterface _storage;

  LocalNoteRepository({required StorageInterface storage}) : _storage = storage;

  @override
  Future<Note?> getNote(String id) async {
    final data = await _storage.get(collection, id);
    if (data == null) return null;
    return Note.fromJson(data);
  }

  @override
  Future<List<Note>> getAllNotes() async {
    final items = await _storage.getAll(collection);
    return items.map((item) => Note.fromJson(item)).toList();
  }

  @override
  Future<List<Note>> getRootNotes() async {
    final all = await getAllNotes();
    return all.where((n) => n.isRoot).toList();
  }

  @override
  Future<List<Note>> getChildNotes(String parentId) async {
    final all = await getAllNotes();
    return all.where((n) => n.parentId == parentId).toList();
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 10}) async {
    final all = await getAllNotes();
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all.take(limit).toList();
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final all = await getAllNotes();
    final matches = all.where((n) {
      final inTitle = n.title.toLowerCase().contains(clean);
      final inSubtitle = n.subtitle != null && n.subtitle!.toLowerCase().contains(clean);
      final inContent = n.content.toLowerCase().contains(clean);
      return inTitle || inSubtitle || inContent;
    }).toList();

    // Sort by relevance: title match first, then subtitle match, then updatedAt desc
    matches.sort((a, b) {
      final aTitle = a.title.toLowerCase().contains(clean);
      final bTitle = b.title.toLowerCase().contains(clean);
      if (aTitle && !bTitle) return -1;
      if (!aTitle && bTitle) return 1;

      final aSub = a.subtitle != null && a.subtitle!.toLowerCase().contains(clean);
      final bSub = b.subtitle != null && b.subtitle!.toLowerCase().contains(clean);
      if (aSub && !bSub) return -1;
      if (!aSub && bSub) return 1;

      return b.updatedAt.compareTo(a.updatedAt);
    });

    return matches;
  }

  @override
  Future<List<Note>> getAncestorPath(String noteId) async {
    final note = await getNote(noteId);
    if (note == null || note.parentId == null) return [];

    final ancestors = <Note>[];
    final visited = <String>{note.id};
    String? currentParentId = note.parentId;

    while (currentParentId != null && !visited.contains(currentParentId)) {
      visited.add(currentParentId);
      final parent = await getNote(currentParentId);
      if (parent == null) break;
      ancestors.insert(0, parent);
      currentParentId = parent.parentId;
    }

    return ancestors;
  }

  @override
  Future<void> saveNote(Note note) async {
    // If note has a parent, ensure child ID is present in parent's childrenIds list
    if (note.parentId != null) {
      final parentData = await _storage.get(collection, note.parentId!);
      if (parentData != null) {
        final parent = Note.fromJson(parentData);
        if (!parent.childrenIds.contains(note.id)) {
          final updatedParent = parent.copyWith(
            childrenIds: [...parent.childrenIds, note.id],
            updatedAt: DateTime.now(),
          );
          await _storage.set(collection, parent.id, updatedParent.toJson());
        }
      }
    }

    await _storage.set(collection, note.id, note.toJson());
  }

  @override
  Future<void> deleteNote(String id) async {
    final noteData = await _storage.get(collection, id);
    if (noteData == null) return;
    final note = Note.fromJson(noteData);

    // If note has a parent, unlink it from the parent's childrenIds list
    if (note.parentId != null) {
      final parentData = await _storage.get(collection, note.parentId!);
      if (parentData != null) {
        final parent = Note.fromJson(parentData);
        if (parent.childrenIds.contains(id)) {
          final updatedParent = parent.copyWith(
            childrenIds: parent.childrenIds.where((childId) => childId != id).toList(),
            updatedAt: DateTime.now(),
          );
          await _storage.set(collection, parent.id, updatedParent.toJson());
        }
      }
    }

    // Safely delete subtree recursively
    await _deleteSubtree(id);
  }

  Future<void> _deleteSubtree(String targetId) async {
    final data = await _storage.get(collection, targetId);
    if (data != null) {
      final note = Note.fromJson(data);
      // Delete children listed in childrenIds
      for (final childId in note.childrenIds) {
        await _deleteSubtree(childId);
      }
      // Also delete any other notes pointing to targetId as parentId
      final all = await getAllNotes();
      for (final candidate in all) {
        if (candidate.parentId == targetId && !note.childrenIds.contains(candidate.id)) {
          await _deleteSubtree(candidate.id);
        }
      }
    }
    await _storage.delete(collection, targetId);
  }
}

