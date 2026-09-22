import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../models/quiz.dart';
import '../models/review_item.dart';

class QuizScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String noteId;
  final String noteTitle;

  const QuizScreen({
    super.key,
    required this.questions,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _hasSubmittedAnswer = false;
  int _correctCount = 0;
  final List<QuizQuestion> _conceptsNeedingReview = [];
  bool _isCompleted = false;

  Future<void> _submitAnswer() async {
    if (_selectedOptionIndex == null || _hasSubmittedAnswer) return;

    final currentQuestion = widget.questions[_currentIndex];
    final isCorrect = _selectedOptionIndex == currentQuestion.correctOptionIndex;

    setState(() {
      _hasSubmittedAnswer = true;
      if (isCorrect) {
        _correctCount++;
      } else {
        _conceptsNeedingReview.add(currentQuestion);
      }
    });

    // Record performance for spaced review scheduling
    final scope = RepositoryScope.maybeOf(context);
    if (scope != null) {
      final reviewRepo = scope.reviewRepository;
      final scheduler = scope.reviewScheduler;

      final existingReview = await reviewRepo.getReviewForNote(currentQuestion.id) ??
          await reviewRepo.getReviewForNote(widget.noteId);

      final baseItem = existingReview ??
          ReviewItem(
            id: 'rev_quiz_${currentQuestion.id}',
            noteId: widget.noteId,
            dueAt: DateTime.now(),
            intervalDays: 1,
            repetitionCount: 0,
            easeFactor: 2.5,
          );

      final rating = isCorrect ? 4 : 2;
      final nextReview = scheduler.scheduleNextReview(
        currentItem: baseItem,
        rating: rating,
      );

      await reviewRepo.saveReview(nextReview);
    }
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < widget.questions.length) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _hasSubmittedAnswer = false;
      });
    } else {
      setState(() {
        _isCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Quiz', style: AppTypography.uiHeadline()),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'No quiz questions available for this note.',
            style: AppTypography.subtitle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (_isCompleted) {
      return _buildCompletionView();
    }

    final question = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;
    final isCorrect = _hasSubmittedAnswer && _selectedOptionIndex == question.correctOptionIndex;

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
              'QUESTION ${_currentIndex + 1} OF ${widget.questions.length}',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Question Prompt Card
              Container(
                padding: const EdgeInsets.all(22.0),
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
                    const SizedBox(height: 12.0),
                    Text(
                      question.prompt,
                      style: AppTypography.title(
                        fontSize: 18.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),

              // Options
              ...question.options.asMap().entries.map((entry) {
                final index = entry.key;
                final text = entry.value;
                final isSelected = _selectedOptionIndex == index;
                final isCorrectOption = index == question.correctOptionIndex;

                Color borderColor = AppColors.borderSubtle;
                Color bgColor = AppColors.surface;

                if (_hasSubmittedAnswer) {
                  if (isCorrectOption) {
                    borderColor = AppColors.textPrimary;
                    bgColor = AppColors.surface;
                  } else if (isSelected) {
                    borderColor = AppColors.borderSubtle;
                    bgColor = AppColors.borderSubtle.withValues(alpha: 0.3);
                  }
                } else if (isSelected) {
                  borderColor = AppColors.textPrimary;
                  bgColor = AppColors.borderSubtle.withValues(alpha: 0.2);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    key: Key('quiz_option_$index'),
                    onTap: _hasSubmittedAnswer
                        ? null
                        : () => setState(() => _selectedOptionIndex = index),
                    borderRadius: BorderRadius.circular(10.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26.0,
                            height: 26.0,
                            margin: const EdgeInsets.only(right: 12.0, top: 2.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected || (_hasSubmittedAnswer && isCorrectOption)
                                    ? AppColors.textPrimary
                                    : AppColors.borderSubtle,
                                width: 1.2,
                              ),
                              color: (_hasSubmittedAnswer && isCorrectOption)
                                  ? AppColors.textPrimary
                                  : Colors.transparent,
                            ),
                            child: Center(
                              child: _hasSubmittedAnswer && isCorrectOption
                                  ? const Icon(Icons.check, size: 16.0, color: AppColors.background)
                                  : Text(
                                      String.fromCharCode(65 + index), // A, B, C, D
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                      ),
                                    ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              text,
                              style: AppTypography.body(
                                fontSize: 15.0,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12.0),

              // Feedback & Actions
              if (!_hasSubmittedAnswer)
                ElevatedButton(
                  key: const Key('submit_quiz_answer_button'),
                  onPressed: _selectedOptionIndex == null ? null : _submitAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.background,
                    disabledBackgroundColor: AppColors.borderSubtle,
                    disabledForegroundColor: AppColors.textTertiary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Text(
                    'Submit answer',
                    style: AppTypography.uiHeadline(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: _selectedOptionIndex == null ? AppColors.textTertiary : AppColors.background,
                    ),
                  ),
                )
              else ...[
                // Feedback container
                Container(
                  padding: const EdgeInsets.all(16.0),
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 18.0,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            isCorrect ? 'Correct' : 'Needs review',
                            style: AppTypography.uiHeadline(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                        const SizedBox(height: 8.0),
                        Text(
                          question.explanation!,
                          style: AppTypography.subtitle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ElevatedButton(
                  key: const Key('next_quiz_question_button'),
                  onPressed: _nextQuestion,
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
                    _currentIndex + 1 < widget.questions.length ? 'Next question' : 'Complete quiz',
                    style: AppTypography.uiHeadline(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.background,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionView() {
    final total = widget.questions.length;
    final percentage = total > 0 ? ((_correctCount / total) * 100).round() : 0;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12.0),
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
                'Quiz complete',
                textAlign: TextAlign.center,
                style: AppTypography.display(
                  fontSize: 28.0,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Retained from "${widget.noteTitle}"',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle(
                  fontSize: 14.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28.0),

              // Score Breakdown
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Score', '$percentage%'),
                    _buildStatCol('Answered', '$total'),
                    _buildStatCol('Correct', '$_correctCount'),
                  ],
                ),
              ),

              if (_conceptsNeedingReview.isNotEmpty) ...[
                const SizedBox(height: 28.0),
                Text(
                  'CONCEPTS NEEDING MORE REVIEW',
                  style: AppTypography.uiLabel(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ).copyWith(letterSpacing: 1.1),
                ),
                const SizedBox(height: 12.0),
                ..._conceptsNeedingReview.map(
                  (q) => Container(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.prompt,
                          style: AppTypography.uiHeadline(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        if (q.explanation != null) ...[
                          const SizedBox(height: 6.0),
                          Text(
                            q.explanation!,
                            style: AppTypography.subtitle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32.0),
              ElevatedButton(
                key: const Key('quiz_done_button'),
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

  Widget _buildStatCol(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.title(
            fontSize: 22.0,
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
