import '../models/ai_responses.dart';
import '../models/flashcard.dart';
import '../models/quiz.dart';

abstract class AiService {
  Future<AiSummaryResponse> summarizeNote({required String noteContent});
  Future<List<Flashcard>> generateFlashcards({required String noteId, required String noteContent});
  Future<List<QuizQuestion>> generateQuiz({required String noteId, required String noteContent});
  Future<AiExplainResponse> explainNote({required String noteContent});
  Future<TeachMeSession> generateTeachMeSession({
    required String noteId,
    required String noteTitle,
    required String noteContent,
  });
  Future<TeachMeSession> submitTeachMeAnswer({
    required TeachMeSession session,
    required String userAnswer,
  });
}
