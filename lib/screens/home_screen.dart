import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../models/note.dart';
import '../models/review_item.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/memory_review_section.dart';
import '../widgets/home/continue_learning_section.dart';
import '../widgets/home/recent_notes_section.dart';

import 'note_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onCreateNote;
  final VoidCallback? onStartReview;
  final ValueChanged<Note>? onOpenNote;

  const HomeScreen({
    super.key,
    this.onCreateNote,
    this.onStartReview,
    this.onOpenNote,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<ReviewItem> _dueReviews = [];
  List<Note> _recentNotes = [];
  Note? _continueNote;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> reload() => _loadData();

  Future<void> _loadData() async {
    final repoScope = RepositoryScope.maybeOf(context);
    if (repoScope == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final due = await repoScope.reviewRepository.getDueReviews();
    final notes = await repoScope.noteRepository.getRecentNotes();

    if (mounted) {
      setState(() {
        _dueReviews = due;
        _recentNotes = notes;
        _continueNote = notes.isNotEmpty ? notes.first : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCreateNote() async {
    if (widget.onCreateNote != null) {
      widget.onCreateNote!();
      return;
    }

    final repoScope = RepositoryScope.maybeOf(context);
    if (repoScope == null) return;

    final note = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repoScope.noteRepository.saveNote(note);
    await _loadData();
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/note/${note.id}'),
          builder: (context) => NoteDetailScreen(
            noteId: note.id,
            initialNote: note,
          ),
        ),
      );
      if (mounted) {
        await _loadData();
      }
    }
  }

  Future<void> _handleOpenNote(Note note) async {
    if (widget.onOpenNote != null) {
      widget.onOpenNote!(note);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/note/${note.id}'),
        builder: (context) => NoteDetailScreen(
          noteId: note.id,
          initialNote: note,
        ),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SizedBox.shrink(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(
                onCreateNote: _handleCreateNote,
              ),
              const SizedBox(height: 40.0),
              MemoryReviewSection(
                dueReviews: _dueReviews,
                onStartReview: widget.onStartReview,
              ),
              if (_continueNote != null) ...[
                const SizedBox(height: 36.0),
                ContinueLearningSection(
                  continueNote: _continueNote,
                  onOpenNote: _handleOpenNote,
                ),
              ],
              const SizedBox(height: 36.0),
              RecentNotesSection(
                notes: _recentNotes,
                onCreateNote: _handleCreateNote,
                onOpenNote: _handleOpenNote,
              ),
              const SizedBox(height: 48.0),
            ],
          ),
        ),
      ),
    );
  }
}
