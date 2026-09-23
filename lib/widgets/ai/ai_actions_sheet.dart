import 'package:flutter/material.dart';
import '../../app/di/repository_scope.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../models/ai_responses.dart';
import '../../models/flashcard.dart';
import '../../models/quiz.dart';
import '../../screens/flashcard_review_screen.dart';
import '../../screens/quiz_screen.dart';
import '../../screens/teach_me_screen.dart';
import '../../services/ai_service.dart';

enum AiActionType {
  summarize,
  flashcards,
  quiz,
  explain,
}

class AiActionsSheet extends StatefulWidget {
  final String noteId;
  final String noteTitle;
  final String noteContent;
  final AiService aiService;
  final void Function(List<Flashcard>)? onFlashcardsGenerated;
  final void Function(List<QuizQuestion>)? onQuizGenerated;

  const AiActionsSheet({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.noteContent,
    required this.aiService,
    this.onFlashcardsGenerated,
    this.onQuizGenerated,
  });

  static Future<void> show(
    BuildContext context, {
    required String noteId,
    required String noteTitle,
    required String noteContent,
    required AiService aiService,
    void Function(List<Flashcard>)? onFlashcardsGenerated,
    void Function(List<QuizQuestion>)? onQuizGenerated,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      barrierColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => AiActionsSheet(
        noteId: noteId,
        noteTitle: noteTitle,
        noteContent: noteContent,
        aiService: aiService,
        onFlashcardsGenerated: onFlashcardsGenerated,
        onQuizGenerated: onQuizGenerated,
      ),
    );
  }

  @override
  State<AiActionsSheet> createState() => _AiActionsSheetState();
}

class _AiActionsSheetState extends State<AiActionsSheet> {
  AiActionType? _selectedAction;
  bool _isLoading = false;
  String? _errorMessage;

  AiSummaryResponse? _summaryResult;
  AiExplainResponse? _explainResult;
  List<Flashcard>? _existingFlashcards;
  List<Flashcard>? _flashcardsResult;
  List<QuizQuestion>? _existingQuizQuestions;
  List<QuizQuestion>? _quizResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadExistingSavedContent();
  }

  Future<void> _loadExistingSavedContent() async {
    final scope = RepositoryScope.maybeOf(context);
    if (scope != null) {
      if (scope.flashcardRepository != null) {
        final savedCards = await scope.flashcardRepository!.getFlashcardsForNote(widget.noteId);
        if (mounted && savedCards.isNotEmpty) {
          setState(() => _existingFlashcards = savedCards);
        }
      }
      if (scope.quizRepository != null) {
        final savedQuizzes = await scope.quizRepository!.getQuizQuestionsForNote(widget.noteId);
        if (mounted && savedQuizzes.isNotEmpty) {
          setState(() => _existingQuizQuestions = savedQuizzes);
        }
      }
    }
  }

  Future<void> _runAction(AiActionType action) async {
    setState(() {
      _selectedAction = action;
      _isLoading = true;
      _errorMessage = null;
    });

    final content = widget.noteContent.trim();
    if (content.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Add some content to this note before running AI reflection.';
      });
      return;
    }

    try {
      switch (action) {
        case AiActionType.summarize:
          final res = await widget.aiService.summarizeNote(noteContent: content);
          if (mounted) setState(() => _summaryResult = res);
          break;
        case AiActionType.explain:
          final res = await widget.aiService.explainNote(noteContent: content);
          if (mounted) setState(() => _explainResult = res);
          break;
        case AiActionType.flashcards:
          final repo = RepositoryScope.maybeOf(context)?.flashcardRepository;
          final res = await widget.aiService.generateFlashcards(
            noteId: widget.noteId,
            noteContent: content,
          );
          if (repo != null) {
            await repo.saveFlashcards(res);
          }
          if (mounted) {
            setState(() {
              _flashcardsResult = res;
              _existingFlashcards = res;
            });
            widget.onFlashcardsGenerated?.call(res);
          }
          break;
        case AiActionType.quiz:
          final repo = RepositoryScope.maybeOf(context)?.quizRepository;
          final res = await widget.aiService.generateQuiz(
            noteId: widget.noteId,
            noteContent: content,
          );
          if (repo != null) {
            await repo.saveQuizQuestions(res);
          }
          if (mounted) {
            setState(() {
              _quizResult = res;
              _existingQuizQuestions = res;
            });
            widget.onQuizGenerated?.call(res);
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetToMenu() {
    setState(() {
      _selectedAction = null;
      _isLoading = false;
      _errorMessage = null;
      _summaryResult = null;
      _explainResult = null;
      _flashcardsResult = null;
      _quizResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36.0,
              height: 4.0,
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (_selectedAction != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16.0),
                      color: AppColors.textPrimary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
                      onPressed: _resetToMenu,
                    ),
                  Text(
                    _selectedAction == null ? '✦ AI REFLECTION' : _actionTitle(_selectedAction!),
                    style: AppTypography.uiLabel(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ).copyWith(letterSpacing: 1.1),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20.0),
                color: AppColors.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Body
          Flexible(
            child: SingleChildScrollView(
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  String _actionTitle(AiActionType action) {
    switch (action) {
      case AiActionType.summarize:
        return '✦ SUMMARY';
      case AiActionType.flashcards:
        return '✦ FLASHCARDS';
      case AiActionType.quiz:
        return '✦ QUIZ';
      case AiActionType.explain:
        return '✦ EXPLAIN';
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Reflecting on your note...',
                style: AppTypography.subtitle(
                  fontSize: 14.0,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reflection issue',
              style: AppTypography.title(fontSize: 18.0, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8.0),
            Text(
              _errorMessage!,
              style: AppTypography.body(fontSize: 14.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20.0),
            if (_selectedAction != null)
              OutlinedButton(
                onPressed: () => _runAction(_selectedAction!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 16.0),
                    const SizedBox(width: 6.0),
                    Text(
                      'Retry',
                      style: AppTypography.uiHeadline(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (_selectedAction == null) {
      return _buildMenu();
    }

    switch (_selectedAction!) {
      case AiActionType.summarize:
        return _buildSummaryView();
      case AiActionType.explain:
        return _buildExplainView();
      case AiActionType.flashcards:
        return _buildFlashcardsView();
      case AiActionType.quiz:
        return _buildQuizView();
    }
  }

  Widget _buildMenu() {
    return Column(
      children: [
        if (_existingFlashcards != null && _existingFlashcards!.isNotEmpty) ...[
          _buildMenuItem(
            icon: Icons.play_circle_outline_rounded,
            title: 'Review flashcards (${_existingFlashcards!.length})',
            description: 'Start active recall session with saved cards.',
            onTap: () {
              final cards = _existingFlashcards!;
              final nId = widget.noteId;
              final nTitle = widget.noteTitle;
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FlashcardReviewScreen(
                    flashcards: cards,
                    noteId: nId,
                    noteTitle: nTitle,
                  ),
                ),
              );
            },
          ),
          const Divider(color: AppColors.borderSubtle, height: 1.0),
        ],
        if (_existingQuizQuestions != null && _existingQuizQuestions!.isNotEmpty) ...[
          _buildMenuItem(
            icon: Icons.assignment_outlined,
            title: 'Take quiz (${_existingQuizQuestions!.length})',
            description: 'Test retention with saved quiz questions.',
            onTap: () {
              final questions = _existingQuizQuestions!;
              final nId = widget.noteId;
              final nTitle = widget.noteTitle;
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    questions: questions,
                    noteId: nId,
                    noteTitle: nTitle,
                  ),
                ),
              );
            },
          ),
          const Divider(color: AppColors.borderSubtle, height: 1.0),
        ],
        _buildMenuItem(
          icon: Icons.notes_rounded,
          title: 'Summarize',
          description: 'Synthesize core takeaways and main ideas.',
          onTap: () => _runAction(AiActionType.summarize),
        ),
        const Divider(color: AppColors.borderSubtle, height: 1.0),
        _buildMenuItem(
          icon: Icons.style_outlined,
          title: 'Create flashcards',
          description: 'Extract question & answer active recall pairs.',
          onTap: () => _runAction(AiActionType.flashcards),
        ),
        const Divider(color: AppColors.borderSubtle, height: 1.0),
        _buildMenuItem(
          icon: Icons.quiz_outlined,
          title: 'Create quiz',
          description: 'Generate multiple-choice retention questions.',
          onTap: () => _runAction(AiActionType.quiz),
        ),
        const Divider(color: AppColors.borderSubtle, height: 1.0),
        _buildMenuItem(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Explain simply',
          description: 'Deconstruct complex thoughts into clear concepts.',
          onTap: () => _runAction(AiActionType.explain),
        ),
        const Divider(color: AppColors.borderSubtle, height: 1.0),
        _buildMenuItem(
          icon: Icons.psychology_outlined,
          title: 'Teach Me',
          description: 'Conversational retrieval dialogue grounded in your note.',
          onTap: () {
            final nId = widget.noteId;
            final nTitle = widget.noteTitle;
            final nContent = widget.noteContent;
            final ai = widget.aiService;
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TeachMeScreen(
                  noteId: nId,
                  noteTitle: nTitle,
                  noteContent: nContent,
                  aiService: ai,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 20.0, color: AppColors.textPrimary),
            const SizedBox(width: 14.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.uiHeadline(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    description,
                    style: AppTypography.subtitle(
                      fontSize: 13.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12.0,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    if (_summaryResult == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _summaryResult!.summary,
          style: AppTypography.body(fontSize: 15.5, color: AppColors.textPrimary),
        ),
        if (_summaryResult!.keyPoints.isNotEmpty) ...[
          const SizedBox(height: 20.0),
          Text(
            'KEY POINTS',
            style: AppTypography.uiLabel(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ).copyWith(letterSpacing: 1.1),
          ),
          const SizedBox(height: 8.0),
          ..._summaryResult!.keyPoints.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('— ', style: TextStyle(color: AppColors.textTertiary)),
                  Expanded(
                    child: Text(
                      p,
                      style: AppTypography.body(fontSize: 14.5, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildExplainView() {
    if (_explainResult == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _explainResult!.explanation,
          style: AppTypography.body(fontSize: 15.5, color: AppColors.textPrimary),
        ),
        if (_explainResult!.simplifiedConcepts.isNotEmpty) ...[
          const SizedBox(height: 20.0),
          Text(
            'CONCEPTS',
            style: AppTypography.uiLabel(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ).copyWith(letterSpacing: 1.1),
          ),
          const SizedBox(height: 8.0),
          ..._explainResult!.simplifiedConcepts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                c,
                style: AppTypography.body(fontSize: 14.5, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildFlashcardsView() {
    if (_flashcardsResult == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_flashcardsResult!.length} cards generated from this note.',
          style: AppTypography.subtitle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14.0),
        ElevatedButton(
          key: const Key('start_flashcard_review_button'),
          onPressed: () {
            final cards = _flashcardsResult!;
            final nId = widget.noteId;
            final nTitle = widget.noteTitle;
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FlashcardReviewScreen(
                  flashcards: cards,
                  noteId: nId,
                  noteTitle: nTitle,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 18.0),
              const SizedBox(width: 6.0),
              Text(
                'Start Review (${_flashcardsResult!.length} cards)',
                style: AppTypography.uiHeadline(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.background,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        ..._flashcardsResult!.map(
          (card) => Container(
            margin: const EdgeInsets.only(bottom: 12.0),
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
                  'Q: ${card.front}',
                  style: AppTypography.uiHeadline(fontSize: 14.0, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6.0),
                Text(
                  'A: ${card.back}',
                  style: AppTypography.body(fontSize: 14.0, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20.0),
      ],
    );
  }

  Widget _buildQuizView() {
    if (_quizResult == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_quizResult!.length} questions generated from this note.',
          style: AppTypography.subtitle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14.0),
        ElevatedButton(
          key: const Key('start_quiz_button'),
          onPressed: () {
            final questions = _quizResult!;
            final nId = widget.noteId;
            final nTitle = widget.noteTitle;
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuizScreen(
                  questions: questions,
                  noteId: nId,
                  noteTitle: nTitle,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.background,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 18.0),
              const SizedBox(width: 6.0),
              Text(
                'Take Quiz (${_quizResult!.length} questions)',
                style: AppTypography.uiHeadline(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.background,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        ..._quizResult!.map(
          (q) => Container(
            margin: const EdgeInsets.only(bottom: 14.0),
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
                  style: AppTypography.uiHeadline(fontSize: 14.0, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8.0),
                ...q.options.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      '${entry.key == q.correctOptionIndex ? "✓" : "•"} ${entry.value}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: entry.key == q.correctOptionIndex
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: entry.key == q.correctOptionIndex
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20.0),
      ],
    );
  }
}
