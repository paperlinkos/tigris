import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../models/note_analysis.dart';
import '../../services/ai_service.dart';

class NoteAnalysisSheet extends StatefulWidget {
  final String noteId;
  final String noteTitle;
  final String noteContent;
  final AiService aiService;

  const NoteAnalysisSheet({
    super.key,
    required this.noteId,
    required this.noteTitle,
    required this.noteContent,
    required this.aiService,
  });

  static Future<void> show(
    BuildContext context, {
    required String noteId,
    required String noteTitle,
    required String noteContent,
    required AiService aiService,
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
      builder: (context) => NoteAnalysisSheet(
        noteId: noteId,
        noteTitle: noteTitle,
        noteContent: noteContent,
        aiService: aiService,
      ),
    );
  }

  @override
  State<NoteAnalysisSheet> createState() => _NoteAnalysisSheetState();
}

class _NoteAnalysisSheetState extends State<NoteAnalysisSheet> {
  bool _isLoading = false;
  String? _errorMessage;
  NoteAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    final cleanContent = widget.noteContent.trim();
    if (cleanContent.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Add some content to this note before analyzing.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.aiService.analyzeNote(
        noteId: widget.noteId,
        content: cleanContent,
      );
      if (mounted) {
        setState(() {
          _analysis = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderSubtle = isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.accent;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                  width: 36.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: borderSubtle,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 18.0,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNDERSTAND NOTE',
                            style: AppTypography.uiHeadline(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1.0),
                          Text(
                            'Structured AI extraction via Gemini',
                            style: AppTypography.uiLabel(
                              fontSize: 11.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20.0, color: textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(color: borderSubtle, height: 1.0),

              // Content Area
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  children: [
                    if (_isLoading) ...[
                      const SizedBox(height: 48.0),
                      Center(
                        child: SizedBox(
                          width: 32.0,
                          height: 32.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Center(
                        child: Text(
                          'Understanding note structure...',
                          style: AppTypography.uiLabel(
                            fontSize: 13.5,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ] else if (_errorMessage != null) ...[
                      const SizedBox(height: 24.0),
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.red.shade900 : Colors.red.shade50)
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 18.0,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  'Analysis Notice',
                                  style: AppTypography.uiHeadline(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              _errorMessage!,
                              style: AppTypography.uiLabel(
                                fontSize: 13.0,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14.0),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _analyze,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: const Text('Retry Analysis'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_analysis != null) ...[
                      _buildAnalysisView(
                        analysis: _analysis!,
                        surfaceColor: surfaceColor,
                        borderSubtle: borderSubtle,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textTertiary: textTertiary,
                        accentColor: accentColor,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalysisView({
    required NoteAnalysis analysis,
    required Color surfaceColor,
    required Color borderSubtle,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color accentColor,
    required bool isDark,
  }) {
    final hasMetadata = analysis.title.isNotEmpty ||
        analysis.date.isNotEmpty ||
        analysis.service.isNotEmpty ||
        analysis.speaker.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Metadata Block
        if (hasMetadata) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (analysis.title.isNotEmpty) ...[
                  Text(
                    analysis.title,
                    style: AppTypography.title(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                ],
                Wrap(
                  spacing: 12.0,
                  runSpacing: 6.0,
                  children: [
                    if (analysis.date.isNotEmpty)
                      _metaBadge(Icons.calendar_today_rounded, analysis.date, textSecondary),
                    if (analysis.service.isNotEmpty)
                      _metaBadge(Icons.church_rounded, analysis.service, textSecondary),
                    if (analysis.speaker.isNotEmpty)
                      _metaBadge(Icons.person_outline_rounded, analysis.speaker, textSecondary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
        ],

        // 2. Topics
        if (analysis.topics.isNotEmpty) ...[
          Text(
            'TOPICS',
            style: AppTypography.uiLabel(
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
              color: textTertiary,
            ),
          ),
          const SizedBox(height: 8.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: analysis.topics.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: borderSubtle),
                ),
                child: Text(
                  t,
                  style: AppTypography.uiLabel(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20.0),
        ],

        // 3. Key Points
        if (analysis.keyPoints.isNotEmpty) ...[
          Text(
            'KEY POINTS',
            style: AppTypography.uiLabel(
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
              color: textTertiary,
            ),
          ),
          const SizedBox(height: 8.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: analysis.keyPoints.map((point) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0, right: 10.0),
                        child: Container(
                          width: 6.0,
                          height: 6.0,
                          decoration: BoxDecoration(
                            color: textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          point,
                          style: AppTypography.body(
                            fontSize: 14.5,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20.0),
        ],

        // 4. Unknown Terms Section
        Text(
          'UNKNOWN TERMS & ABBREVIATIONS',
          style: AppTypography.uiLabel(
            fontSize: 11.0,
            fontWeight: FontWeight.w700,
            color: textTertiary,
          ),
        ),
        const SizedBox(height: 8.0),
        if (analysis.unknownTerms.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18.0,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'No ambiguous abbreviations or undefined terms detected.',
                    style: AppTypography.uiLabel(
                      fontSize: 12.5,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...analysis.unknownTerms.map((term) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          term.term,
                          style: AppTypography.uiHeadline(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'Needs Context / Undefined',
                        style: AppTypography.uiLabel(
                          fontSize: 11.0,
                          color: textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    term.reason,
                    style: AppTypography.body(
                      fontSize: 13.0,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _metaBadge(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.0, color: color),
        const SizedBox(width: 4.0),
        Text(
          text,
          style: AppTypography.uiLabel(
            fontSize: 12.0,
            color: color,
          ),
        ),
      ],
    );
  }
}
