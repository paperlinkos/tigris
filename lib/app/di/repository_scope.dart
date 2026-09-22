import 'package:flutter/material.dart';
import '../../repositories/flashcard_repository.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/quiz_repository.dart';
import '../../repositories/review_repository.dart';
import '../../services/ai_service.dart';
import '../../services/local_ai_service.dart';
import '../../services/review_scheduler_service.dart';

class RepositoryScope extends InheritedWidget {
  final NoteRepository noteRepository;
  final ReviewRepository reviewRepository;
  final FlashcardRepository? flashcardRepository;
  final QuizRepository? quizRepository;
  final ReviewSchedulerService reviewScheduler;
  final AiService aiService;

  const RepositoryScope({
    super.key,
    required this.noteRepository,
    required this.reviewRepository,
    this.flashcardRepository,
    this.quizRepository,
    ReviewSchedulerService? reviewScheduler,
    this.aiService = const LocalAiService(),
    required super.child,
  }) : reviewScheduler = reviewScheduler ?? const _DefaultScheduler();

  static RepositoryScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'No RepositoryScope found in context');
    return scope!;
  }

  static RepositoryScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) {
    return noteRepository != oldWidget.noteRepository ||
        reviewRepository != oldWidget.reviewRepository ||
        flashcardRepository != oldWidget.flashcardRepository ||
        quizRepository != oldWidget.quizRepository ||
        reviewScheduler != oldWidget.reviewScheduler ||
        aiService != oldWidget.aiService;
  }
}

class _DefaultScheduler extends StandardReviewSchedulerService {
  const _DefaultScheduler();
}
