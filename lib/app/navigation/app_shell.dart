import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../di/repository_scope.dart';
import '../../models/note.dart';
import '../../persistence/storage_interface.dart';
import '../../persistence/preferences_storage.dart';
import '../../repositories/flashcard_repository.dart';
import '../../repositories/local_flashcard_repository.dart';
import '../../repositories/local_note_repository.dart';
import '../../repositories/local_quiz_repository.dart';
import '../../repositories/local_review_repository.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/quiz_repository.dart';
import '../../repositories/review_repository.dart';
import '../../screens/home_screen.dart';
import '../../screens/note_detail_screen.dart';
import '../../screens/review_session_screen.dart';

class AppShell extends StatefulWidget {
  final StorageInterface? storage;
  final NoteRepository? noteRepository;
  final ReviewRepository? reviewRepository;
  final FlashcardRepository? flashcardRepository;
  final QuizRepository? quizRepository;

  const AppShell({
    super.key,
    this.storage,
    this.noteRepository,
    this.reviewRepository,
    this.flashcardRepository,
    this.quizRepository,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final NoteRepository _noteRepository;
  late final ReviewRepository _reviewRepository;
  late final FlashcardRepository _flashcardRepository;
  late final QuizRepository _quizRepository;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    final storage = widget.storage ?? PreferencesStorage();
    _noteRepository = widget.noteRepository ?? LocalNoteRepository(storage: storage);
    _reviewRepository = widget.reviewRepository ?? LocalReviewRepository(storage: storage);
    _flashcardRepository = widget.flashcardRepository ?? LocalFlashcardRepository(storage: storage);
    _quizRepository = widget.quizRepository ?? LocalQuizRepository(storage: storage);
  }

  Future<void> _handleCreateNote() async {
    final newNote = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _noteRepository.saveNote(newNote);
    _homeKey.currentState?.reload();

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/note/${newNote.id}'),
          builder: (context) => RepositoryScope(
            noteRepository: _noteRepository,
            reviewRepository: _reviewRepository,
            flashcardRepository: _flashcardRepository,
            quizRepository: _quizRepository,
            child: NoteDetailScreen(
              noteId: newNote.id,
              initialNote: newNote,
            ),
          ),
        ),
      );
      _homeKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      noteRepository: _noteRepository,
      reviewRepository: _reviewRepository,
      flashcardRepository: _flashcardRepository,
      quizRepository: _quizRepository,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: HomeScreen(
          key: _homeKey,
          onCreateNote: _handleCreateNote,
          onStartReview: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RepositoryScope(
                  noteRepository: _noteRepository,
                  reviewRepository: _reviewRepository,
                  flashcardRepository: _flashcardRepository,
                  quizRepository: _quizRepository,
                  child: const ReviewSessionScreen(),
                ),
              ),
            );
            _homeKey.currentState?.reload();
          },
        ),
      ),
    );
  }
}
