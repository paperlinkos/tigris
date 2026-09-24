import '../models/ai_responses.dart';
import '../models/flashcard.dart';
import '../models/note_analysis.dart';
import '../models/quiz.dart';

abstract class AiService {
  Future<NoteAnalysis> analyzeNote({
    required String noteId,
    required String content,
  });

  Future<AiSummaryResponse> summarizeNote({
    String? noteTitle,
    required String noteContent,
  });

  Future<List<Flashcard>> generateFlashcards({
    required String noteId,
    String? noteTitle,
    required String noteContent,
  });

  Future<List<QuizQuestion>> generateQuiz({
    required String noteId,
    String? noteTitle,
    required String noteContent,
  });

  Future<AiExplainResponse> explainNote({
    String? noteTitle,
    required String noteContent,
  });

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
