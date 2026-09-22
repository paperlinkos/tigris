import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
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
import '../../screens/notes_screen.dart';
import '../../screens/note_detail_screen.dart';
import '../../screens/review_session_screen.dart';
import '../../screens/settings_screen.dart';

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
  int _currentIndex = 0;
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
    final screens = [
      HomeScreen(
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
      const NotesScreen(),
      const SettingsScreen(),
    ];

    return RepositoryScope(
      noteRepository: _noteRepository,
      reviewRepository: _reviewRepository,
      flashcardRepository: _flashcardRepository,
      quizRepository: _quizRepository,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(color: AppColors.borderSubtle, width: 1.0),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64.0, // Large touch target height
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    label: 'Review',
                    icon: Icons.refresh_rounded,
                  ),
                  _buildNavItem(
                    index: 1,
                    label: 'Notes',
                    icon: Icons.edit_note_rounded,
                  ),
                  _buildNavItem(
                    index: 2,
                    label: 'Settings',
                    icon: Icons.tune_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.textPrimary : AppColors.textTertiary;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        if (index == 0) {
          _homeKey.currentState?.reload();
        }
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 80.0, minHeight: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22.0,
              color: color,
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: AppTypography.uiLabel(
                color: color,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
