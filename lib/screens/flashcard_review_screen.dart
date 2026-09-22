import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../models/flashcard.dart';
import '../models/review_item.dart';

class FlashcardReviewScreen extends StatefulWidget {
  final List<Flashcard> flashcards;
  final String noteId;
  final String noteTitle;

  const FlashcardReviewScreen({
    super.key,
    required this.flashcards,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen> {
  int _currentIndex = 0;
  bool _isAnswerRevealed = false;
  final Map<int, int> _ratings = {}; // index -> rating (1: again, 2: hard, 4: good, 5: easy)
  bool _isCompleted = false;

  Future<void> _recordRating(int rating) async {
    _ratings[_currentIndex] = rating;

    // Use existing ReviewItem & ReviewRepository architecture
    final scope = RepositoryScope.maybeOf(context);
    if (scope != null) {
      final currentCard = widget.flashcards[_currentIndex];
      // Lookup existing review for this card or note
      final reviewRepo = scope.reviewRepository;
      final scheduler = scope.reviewScheduler;

      final existingReview = await reviewRepo.getReviewForNote(currentCard.id) ??
          await reviewRepo.getReviewForNote(widget.noteId);

      final baseItem = existingReview ??
          ReviewItem(
            id: 'rev_card_${currentCard.id}',
            noteId: widget.noteId,
            dueAt: DateTime.now(),
            intervalDays: 1,
            repetitionCount: 0,
            easeFactor: 2.5,
          );

      final nextReview = scheduler.scheduleNextReview(
        currentItem: baseItem,
        rating: rating,
      );

      await reviewRepo.saveReview(nextReview);
    }

    if (!mounted) return;

    if (_currentIndex + 1 < widget.flashcards.length) {
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
    if (widget.flashcards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Review', style: AppTypography.uiHeadline()),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'No flashcards available for this note.',
            style: AppTypography.subtitle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (_isCompleted) {
      return _buildCompletionView();
    }

    final card = widget.flashcards[_currentIndex];
    final progress = (_currentIndex + 1) / widget.flashcards.length;

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
              'CARD ${_currentIndex + 1} OF ${widget.flashcards.length}',
              style: AppTypography.uiLabel(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ).copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: 2.0),
            Text(
              widget.noteTitle,
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
                          'QUESTION',
                          style: AppTypography.uiLabel(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ).copyWith(letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 14.0),
                        Text(
                          card.front,
                          style: AppTypography.title(
                            fontSize: 20.0,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_isAnswerRevealed) ...[
                          const SizedBox(height: 24.0),
                          const Divider(color: AppColors.borderSubtle, height: 1.0),
                          const SizedBox(height: 20.0),
                          Text(
                            'ANSWER',
                            style: AppTypography.uiLabel(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ).copyWith(letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            card.back,
                            style: AppTypography.body(
                              fontSize: 16.0,
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
                  key: const Key('show_answer_button'),
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
                      'HOW WELL DID YOU REMEMBER?',
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
                          child: _buildRatingButton(
                            keyName: 'rate_again_button',
                            label: 'Again',
                            sublabel: '< 1d',
                            rating: 1,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: _buildRatingButton(
                            keyName: 'rate_hard_button',
                            label: 'Hard',
                            sublabel: '1d',
                            rating: 2,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: _buildRatingButton(
                            keyName: 'rate_good_button',
                            label: 'Good',
                            sublabel: '3d',
                            rating: 4,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: _buildRatingButton(
                            keyName: 'rate_easy_button',
                            label: 'Easy',
                            sublabel: '7d',
                            rating: 5,
                          ),
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

  Widget _buildRatingButton({
    required String keyName,
    required String label,
    required String sublabel,
    required int rating,
  }) {
    return OutlinedButton(
      key: Key(keyName),
      onPressed: () => _recordRating(rating),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderSubtle),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
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
            style: AppTypography.subtitle(
              fontSize: 11.0,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView() {
    final againCount = _ratings.values.where((r) => r == 1).length;
    final hardCount = _ratings.values.where((r) => r == 2).length;
    final goodCount = _ratings.values.where((r) => r == 4).length;
    final easyCount = _ratings.values.where((r) => r == 5).length;

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
                child: Text(
                  '✦',
                  style: TextStyle(
                    fontSize: 36.0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Review complete',
                textAlign: TextAlign.center,
                style: AppTypography.display(
                  fontSize: 28.0,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'You recalled ${widget.flashcards.length} cards from\n"${widget.noteTitle}".',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle(
                  fontSize: 14.5,
                  color: AppColors.textSecondary,
                ),
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
                    _buildStatItem('Again', againCount),
                    _buildStatItem('Hard', hardCount),
                    _buildStatItem('Good', goodCount),
                    _buildStatItem('Easy', easyCount),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                key: const Key('review_done_button'),
                onPressed: () => Navigator.of(context).pop(),
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
                  'Done',
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

  Widget _buildStatItem(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: AppTypography.title(
            fontSize: 20.0,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: AppTypography.subtitle(
            fontSize: 12.0,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
