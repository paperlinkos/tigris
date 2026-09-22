import '../models/flashcard.dart';

abstract class FlashcardRepository {
  Future<List<Flashcard>> getAllFlashcards();
  Future<List<Flashcard>> getFlashcardsForNote(String noteId);
  Future<void> saveFlashcard(Flashcard flashcard);
  Future<void> saveFlashcards(List<Flashcard> flashcards);
  Future<void> deleteFlashcard(String id);
  Future<void> deleteFlashcardsForNote(String noteId);
}
