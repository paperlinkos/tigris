import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../models/ai_responses.dart';
import '../models/review_item.dart';
import '../services/ai_service.dart';
import '../services/local_ai_service.dart';

class TeachMeScreen extends StatefulWidget {
  final String noteId;
  final String noteTitle;
  final String noteContent;
  final AiService? aiService;

  const TeachMeScreen({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.noteContent,
    this.aiService,
  });

  @override
  State<TeachMeScreen> createState() => _TeachMeScreenState();
}

class _TeachMeScreenState extends State<TeachMeScreen> {
  TeachMeSession? _session;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AiService get _aiService =>
      widget.aiService ??
      RepositoryScope.maybeOf(context)?.aiService ??
      const LocalAiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _aiService.generateTeachMeSession(
        noteId: widget.noteId,
        noteTitle: widget.noteTitle,
        noteContent: widget.noteContent,
      );
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty || _session == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updated = await _aiService.submitTeachMeAnswer(
        session: _session!,
        userAnswer: text,
      );

      _answerController.clear();

      if (mounted) {
        setState(() {
          _session = updated;
          _isSubmitting = false;
        });

        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        if (updated.isCompleted) {
          _recordSessionCompletion(updated);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _recordSessionCompletion(TeachMeSession session) async {
    final scope = RepositoryScope.maybeOf(context);
    if (scope != null) {
      final reviewRepo = scope.reviewRepository;
      final scheduler = scope.reviewScheduler;

      final existingReview = await reviewRepo.getReviewForNote(widget.noteId);
      final baseItem = existingReview ??
          ReviewItem(
            id: 'rev_teach_${session.sessionId}',
            noteId: widget.noteId,
            dueAt: DateTime.now(),
            intervalDays: 1,
            repetitionCount: 0,
            easeFactor: 2.5,
          );

      final nextReview = scheduler.scheduleNextReview(
        currentItem: baseItem,
        rating: 4, // Successful conversational retrieval
      );

      await reviewRepo.saveReview(nextReview);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'TEACH ME',
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
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24.0,
              height: 24.0,
              child: CircularProgressIndicator(strokeWidth: 2.0, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16.0),
            Text(
              'Preparing your retrieval session...',
              style: AppTypography.subtitle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not begin session',
                style: AppTypography.title(fontSize: 18.0),
              ),
              const SizedBox(height: 8.0),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.subtitle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16.0),
              OutlinedButton(
                key: const Key('retry_teach_me_button'),
                onPressed: _startSession,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_session == null) {
      return const SizedBox.shrink();
    }

    if (_session!.isCompleted) {
      return _buildCompletionSummary();
    }

    return Column(
      children: [
        // Conversational Exchanges
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            itemCount: _session!.exchanges.length,
            itemBuilder: (context, index) {
              final exchange = _session!.exchanges[index];
              return _buildExchangeView(exchange, index);
            },
          ),
        ),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
          ),

        // User Answer Input Box
        _buildInputBar(),
      ],
    );
  }

  Widget _buildExchangeView(TeachMeExchange exchange, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AI Question
          Container(
            padding: const EdgeInsets.all(16.0),
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
                    Text(
                      '✦ AI QUESTION ${index + 1}',
                      style: AppTypography.uiLabel(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ).copyWith(letterSpacing: 1.1),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Text(
                  exchange.question,
                  style: AppTypography.body(fontSize: 16.0, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),

          // User Answer
          if (exchange.userAnswer != null) ...[
            const SizedBox(height: 12.0),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'YOU',
                      style: AppTypography.uiLabel(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.background.withValues(alpha: 0.7),
                      ).copyWith(letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      exchange.userAnswer!,
                      style: AppTypography.body(fontSize: 14.5, color: AppColors.background),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // AI Evaluation Feedback
          if (exchange.feedback != null) ...[
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(14.0),
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
                        exchange.isUnderstood == true
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 16.0,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        exchange.isUnderstood == true ? 'Understood' : 'Gaps noted',
                        style: AppTypography.uiHeadline(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    exchange.feedback!,
                    style: AppTypography.subtitle(fontSize: 13.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('teach_me_input_field'),
              controller: _answerController,
              maxLines: 4,
              minLines: 1,
              style: AppTypography.body(fontSize: 15.0),
              decoration: InputDecoration(
                hintText: 'Explain in your own words...',
                hintStyle: AppTypography.subtitle(fontSize: 14.0, color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: AppColors.textPrimary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          ElevatedButton(
            key: const Key('submit_teach_me_answer_button'),
            onPressed: _isSubmitting ? null : _submitAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.background,
              disabledBackgroundColor: AppColors.borderSubtle,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0, color: AppColors.background),
                  )
                : const Icon(Icons.arrow_upward_rounded, size: 20.0),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionSummary() {
    final understood = _session!.exchanges.where((e) => e.isUnderstood == true).length;
    final total = _session!.exchanges.length;

    return Padding(
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
            'Session complete',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              fontSize: 28.0,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'You actively recalled concepts from\n"${widget.noteTitle}".',
            textAlign: TextAlign.center,
            style: AppTypography.subtitle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28.0),
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
                _buildStatItem('Questions', '$total'),
                _buildStatItem('Understood', '$understood'),
                _buildStatItem('Review', '${total - understood}'),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            key: const Key('teach_me_done_button'),
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
    );
  }

  Widget _buildStatItem(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
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
