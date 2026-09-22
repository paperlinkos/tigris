import '../models/flashcard.dart';
import '../persistence/storage_interface.dart';
import 'flashcard_repository.dart';

class LocalFlashcardRepository implements FlashcardRepository {
  static const String collection = 'flashcards';
  final StorageInterface _storage;

  LocalFlashcardRepository({required StorageInterface storage}) : _storage = storage;

  @override
  Future<List<Flashcard>> getAllFlashcards() async {
    final raw = await _storage.getAll(collection);
    return raw.map((json) => Flashcard.fromJson(json)).toList();
  }

  @override
  Future<List<Flashcard>> getFlashcardsForNote(String noteId) async {
    final all = await getAllFlashcards();
    return all.where((f) => f.noteId == noteId).toList();
  }

  @override
  Future<void> saveFlashcard(Flashcard flashcard) async {
    await _storage.set(collection, flashcard.id, flashcard.toJson());
  }

  @override
  Future<void> saveFlashcards(List<Flashcard> flashcards) async {
    for (final card in flashcards) {
      await _storage.set(collection, card.id, card.toJson());
    }
  }

  @override
  Future<void> deleteFlashcard(String id) async {
    await _storage.delete(collection, id);
  }

  @override
  Future<void> deleteFlashcardsForNote(String noteId) async {
    final existing = await getFlashcardsForNote(noteId);
    for (final card in existing) {
      await _storage.delete(collection, card.id);
    }
  }
}
