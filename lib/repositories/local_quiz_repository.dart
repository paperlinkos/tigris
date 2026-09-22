import '../models/quiz.dart';
import '../persistence/storage_interface.dart';
import 'quiz_repository.dart';

class LocalQuizRepository implements QuizRepository {
  static const String collection = 'quizzes';
  final StorageInterface _storage;

  LocalQuizRepository({required StorageInterface storage}) : _storage = storage;

  @override
  Future<List<QuizQuestion>> getAllQuizQuestions() async {
    final raw = await _storage.getAll(collection);
    return raw.map((json) => QuizQuestion.fromJson(json)).toList();
  }

  @override
  Future<List<QuizQuestion>> getQuizQuestionsForNote(String noteId) async {
    final all = await getAllQuizQuestions();
    return all.where((q) => q.noteId == noteId).toList();
  }

  @override
  Future<void> saveQuizQuestion(QuizQuestion question) async {
    await _storage.set(collection, question.id, question.toJson());
  }

  @override
  Future<void> saveQuizQuestions(List<QuizQuestion> questions) async {
    for (final q in questions) {
      await _storage.set(collection, q.id, q.toJson());
    }
  }

  @override
  Future<void> deleteQuizQuestion(String id) async {
    await _storage.delete(collection, id);
  }

  @override
  Future<void> deleteQuizQuestionsForNote(String noteId) async {
    final existing = await getQuizQuestionsForNote(noteId);
    for (final q in existing) {
      await _storage.delete(collection, q.id);
    }
  }
}
