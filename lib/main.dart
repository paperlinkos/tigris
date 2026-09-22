import 'package:flutter/material.dart';
import 'app/di/repository_scope.dart';
import 'app/theme/app_theme.dart';
import 'app/navigation/app_shell.dart';
import 'persistence/preferences_storage.dart';
import 'persistence/storage_interface.dart';
import 'repositories/flashcard_repository.dart';
import 'repositories/local_flashcard_repository.dart';
import 'repositories/local_note_repository.dart';
import 'repositories/local_quiz_repository.dart';
import 'repositories/local_review_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/quiz_repository.dart';
import 'repositories/review_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PersonalLearningApp());
}

class PersonalLearningApp extends StatefulWidget {
  final StorageInterface? storage;
  final NoteRepository? noteRepository;
  final ReviewRepository? reviewRepository;
  final FlashcardRepository? flashcardRepository;
  final QuizRepository? quizRepository;

  const PersonalLearningApp({
    super.key,
    this.storage,
    this.noteRepository,
    this.reviewRepository,
    this.flashcardRepository,
    this.quizRepository,
  });

  @override
  State<PersonalLearningApp> createState() => _PersonalLearningAppState();
}

class _PersonalLearningAppState extends State<PersonalLearningApp> {
  late final NoteRepository _noteRepository;
  late final ReviewRepository _reviewRepository;
  late final FlashcardRepository _flashcardRepository;
  late final QuizRepository _quizRepository;

  @override
  void initState() {
    super.initState();
    final storage = widget.storage ?? PreferencesStorage();
    _noteRepository = widget.noteRepository ?? LocalNoteRepository(storage: storage);
    _reviewRepository = widget.reviewRepository ?? LocalReviewRepository(storage: storage);
    _flashcardRepository = widget.flashcardRepository ?? LocalFlashcardRepository(storage: storage);
    _quizRepository = widget.quizRepository ?? LocalQuizRepository(storage: storage);
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      noteRepository: _noteRepository,
      reviewRepository: _reviewRepository,
      flashcardRepository: _flashcardRepository,
      quizRepository: _quizRepository,
      child: MaterialApp(
        title: 'Active Learning',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: AppShell(
          storage: widget.storage,
          noteRepository: _noteRepository,
          reviewRepository: _reviewRepository,
        ),
      ),
    );
  }
}
