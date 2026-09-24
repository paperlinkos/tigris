import '../models/note.dart';

abstract class NoteRepository {
  Future<Note?> getNote(String id);
  Future<List<Note>> getAllNotes();
  Future<List<Note>> getRootNotes();
  Future<List<Note>> getChildNotes(String parentId);
  Future<List<Note>> getRecentNotes({int limit = 10});
  Future<List<Note>> searchNotes(String query);
  Future<List<Note>> getAncestorPath(String noteId);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
  Stream<List<Note>> watchRecentNotes({int limit = 10});
  Stream<List<Note>> watchAllNotes();
}
