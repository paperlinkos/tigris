import '../models/quiz.dart';

abstract class QuizRepository {
  Future<List<QuizQuestion>> getAllQuizQuestions();
  Future<List<QuizQuestion>> getQuizQuestionsForNote(String noteId);
  Future<void> saveQuizQuestion(QuizQuestion question);
  Future<void> saveQuizQuestions(List<QuizQuestion> questions);
  Future<void> deleteQuizQuestion(String id);
  Future<void> deleteQuizQuestionsForNote(String noteId);
}
