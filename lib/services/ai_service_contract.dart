import '../models/flashcard.dart';
import '../models/quiz.dart';

abstract class AiServiceContract {
  Future<String> generateSummary({required String noteContent});
  Future<List<Flashcard>> generateFlashcards({required String noteId, required String noteContent});
  Future<List<QuizQuestion>> generateQuiz({required String noteId, required String noteContent});
  Future<String> sendTeachMeMessage({required String sessionId, required String userMessage});
}
