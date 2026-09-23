import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';

class CreateNoteSheet extends StatefulWidget {
  final String? parentId;
  final String? parentTitle;

  const CreateNoteSheet({
    super.key,
    this.parentId,
    this.parentTitle,
  });

  static Future<Note?> show(
    BuildContext context, {
    String? parentId,
    String? parentTitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<Note>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      barrierColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => CreateNoteSheet(
        parentId: parentId,
        parentTitle: parentTitle,
      ),
    );
  }

  @override
  State<CreateNoteSheet> createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends State<CreateNoteSheet> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final subtitle = _subtitleController.text.trim();
    final content = _contentController.text.trim();

    final now = DateTime.now();
    final note = Note(
      id: 'note_${now.microsecondsSinceEpoch}',
      title: title,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      content: content,
      parentId: widget.parentId,
      createdAt: now,
      updatedAt: now,
    );

    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isChild = widget.parentId != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 20.0,
        bottom: bottomInset + 24.0,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet drag handle
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: context.appBorderSubtle,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),

              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isChild ? 'NEW PAGE' : 'NEW NOTE',
                        style: AppTypography.uiLabel(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.appTextSecondary,
                        ).copyWith(letterSpacing: 1.2),
                      ),
                      if (widget.parentTitle != null) ...[
                        const SizedBox(height: 2.0),
                        Text(
                          'in ${widget.parentTitle}',
                          style: AppTypography.uiLabel(
                            fontSize: 12.0,
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20.0),
                    color: context.appTextSecondary,
                    splashRadius: 20.0,
                  ),
                ],
              ),
              const SizedBox(height: 18.0),

              // Title input
              TextFormField(
                controller: _titleController,
                autofocus: true,
                style: AppTypography.title(
                  fontSize: 20.0,
                  color: context.appTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: isChild ? 'Page title' : 'Note title',
                  hintStyle: AppTypography.title(
                    fontSize: 20.0,
                    color: context.appTextTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12.0),
              Divider(color: context.appBorderSubtle, height: 1.0),
              const SizedBox(height: 12.0),

              // Subtitle input (optional)
              TextFormField(
                controller: _subtitleController,
                style: AppTypography.subtitle(
                  fontSize: 14.5,
                  color: context.appTextSecondary,
                ),
                decoration: InputDecoration(
                  hintText: 'Subtitle (optional)',
                  hintStyle: AppTypography.subtitle(
                    fontSize: 14.5,
                    color: context.appTextTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12.0),
              Divider(color: context.appBorderSubtle, height: 1.0),
              const SizedBox(height: 12.0),

              // Content / Thought input (optional)
              TextFormField(
                controller: _contentController,
                maxLines: 4,
                minLines: 2,
                style: AppTypography.body(
                  fontSize: 15.0,
                  color: context.appTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Initial thoughts or notes (optional)...',
                  hintStyle: AppTypography.body(
                    fontSize: 15.0,
                    color: context.appTextTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24.0),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appTextSecondary,
                      minimumSize: const Size(64.0, 48.0),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTypography.uiLabel(
                        fontSize: 14.0,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appTextPrimary,
                      foregroundColor: context.appBg,
                      elevation: 0,
                      minimumSize: const Size(88.0, 48.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      'Create',
                      style: AppTypography.uiHeadline(
                        fontSize: 14.0,
                        color: context.appBg,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

