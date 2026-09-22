import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../models/flashcard.dart';
import '../models/note.dart';
import '../models/review_item.dart';

class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  List<ReviewItem> _dueQueue = [];
  final Map<String, Note> _notesCache = {};
  final Map<String, List<Flashcard>> _flashcardsCache = {};

  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isAnswerRevealed = false;
  bool _isCompleted = false;
  final Map<int, int> _ratings = {}; // index -> rating

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final scope = RepositoryScope.maybeOf(context);
    if (scope == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final due = await scope.reviewRepository.getDueReviews();
    final notes = <String, Note>{};
    final flashcards = <String, List<Flashcard>>{};

    for (final item in due) {
      if (!notes.containsKey(item.noteId)) {
        final note = await scope.noteRepository.getNote(item.noteId);
        if (note != null) {
          notes[item.noteId] = note;
        }
      }
      if (scope.flashcardRepository != null && !flashcards.containsKey(item.noteId)) {
        final cards = await scope.flashcardRepository!.getFlashcardsForNote(item.noteId);
        flashcards[item.noteId] = cards;
      }
    }

    if (mounted) {
      setState(() {
        _dueQueue = due;
        _notesCache.addAll(notes);
        _flashcardsCache.addAll(flashcards);
        _isLoading = false;
      });
    }
  }

  Future<void> _recordRating(int rating) async {
    _ratings[_currentIndex] = rating;

    final scope = RepositoryScope.maybeOf(context);
    if (scope != null && _currentIndex < _dueQueue.length) {
      final item = _dueQueue[_currentIndex];
      final updated = scope.reviewScheduler.scheduleNextReview(
        currentItem: item,
        rating: rating,
      );
      await scope.reviewRepository.saveReview(updated);
    }

    if (!mounted) return;

    if (_currentIndex + 1 < _dueQueue.length) {
      setState(() {
        _currentIndex++;
        _isAnswerRevealed = false;
      });
    } else {
      setState(() {
        _isCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(strokeWidth: 2.0, color: AppColors.textPrimary),
        ),
      );
    }

    if (_dueQueue.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(
                  child: Text('✦', style: TextStyle(fontSize: 32.0, color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Nothing due for review',
                  style: AppTypography.display(fontSize: 24.0),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Your spaced repetition queue is clear for today.',
                  textAlign: TextAlign.center,
                  style: AppTypography.subtitle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  key: const Key('return_home_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.background,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  child: const Text('Return Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isCompleted) {
      return _buildCompletionView();
    }

    final currentItem = _dueQueue[_currentIndex];
    final note = _notesCache[currentItem.noteId];
    final noteTitle = note?.title ?? 'Review Reflection';
    final cards = _flashcardsCache[currentItem.noteId];
    final hasFlashcards = cards != null && cards.isNotEmpty;
    final card = hasFlashcards ? cards.first : null;

    final progress = (_currentIndex + 1) / _dueQueue.length;

    final promptText = card != null
        ? card.front
        : 'In your own words, what is the core thesis of "$noteTitle"?';

    final answerText = card != null
        ? card.back
        : (note != null && note.content.isNotEmpty
            ? note.content
            : note?.subtitle ?? 'Active retrieval practice for this note.');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'REVIEW ${_currentIndex + 1} OF ${_dueQueue.length}',
              style: AppTypography.uiLabel(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ).copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: 2.0),
            Text(
              noteTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.subtitle(
                fontSize: 13.0,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.borderSubtle,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
            minHeight: 2.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RETRIEVAL PROMPT',
                          style: AppTypography.uiLabel(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ).copyWith(letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 14.0),
                        Text(
                          promptText,
                          style: AppTypography.title(
                            fontSize: 19.0,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_isAnswerRevealed) ...[
                          const SizedBox(height: 24.0),
                          const Divider(color: AppColors.borderSubtle, height: 1.0),
                          const SizedBox(height: 20.0),
                          Text(
                            'MEMORY SOURCE',
                            style: AppTypography.uiLabel(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ).copyWith(letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            answerText,
                            style: AppTypography.body(
                              fontSize: 15.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              if (!_isAnswerRevealed)
                ElevatedButton(
                  key: const Key('review_session_show_answer'),
                  onPressed: () => setState(() => _isAnswerRevealed = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.background,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text(
                    'Show answer',
                    style: AppTypography.uiHeadline(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.background,
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'HOW WELL DID YOU RECALL THIS?',
                      textAlign: TextAlign.center,
                      style: AppTypography.uiLabel(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ).copyWith(letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRateBtn('rate_again_button', 'Again', '< 1d', 1),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: _buildRateBtn('rate_hard_button', 'Hard', '1d', 2),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: _buildRateBtn('rate_good_button', 'Good', '3d', 4),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: _buildRateBtn('rate_easy_button', 'Easy', '7d', 5),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateBtn(String keyName, String label, String sublabel, int rating) {
    return OutlinedButton(
      key: Key(keyName),
      onPressed: () => _recordRating(rating),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderSubtle),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.uiHeadline(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            sublabel,
            style: AppTypography.subtitle(fontSize: 11.0, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView() {
    final again = _ratings.values.where((r) => r == 1).length;
    final hard = _ratings.values.where((r) => r == 2).length;
    final good = _ratings.values.where((r) => r == 4).length;
    final easy = _ratings.values.where((r) => r == 5).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(
                child: Text('✦', style: TextStyle(fontSize: 36.0, color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Review complete',
                textAlign: TextAlign.center,
                style: AppTypography.display(fontSize: 28.0),
              ),
              const SizedBox(height: 8.0),
              Text(
                'You reviewed ${_dueQueue.length} ${_dueQueue.length == 1 ? "item" : "items"} from your memory queue.',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle(fontSize: 14.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32.0),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Again', '$again'),
                    _buildStatCol('Hard', '$hard'),
                    _buildStatCol('Good', '$good'),
                    _buildStatCol('Easy', '$easy'),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                key: const Key('review_session_done_button'),
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.background,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                child: Text(
                  'Return Home',
                  style: AppTypography.uiHeadline(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.background,
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.title(
            fontSize: 20.0,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: AppTypography.subtitle(fontSize: 12.0, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
