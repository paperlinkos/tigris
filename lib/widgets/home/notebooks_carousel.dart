import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../models/note.dart';

class NotebooksCarousel extends StatelessWidget {
  final List<Note> rootNotes;
  final VoidCallback onCreateNotebook;
  final ValueChanged<Note> onOpenNotebook;

  const NotebooksCarousel({
    super.key,
    required this.rootNotes,
    required this.onCreateNotebook,
    required this.onOpenNotebook,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STREAMS',
              style: AppTypography.uiLabel(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ).copyWith(letterSpacing: 1.2),
            ),
            const Spacer(),
            InkWell(
              onTap: onCreateNotebook,
              borderRadius: BorderRadius.circular(4.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 15.0,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2.0),
                    Text(
                      'New Stream',
                      style: AppTypography.uiLabel(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14.0),
        SizedBox(
          height: 124.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: rootNotes.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12.0),
            itemBuilder: (context, index) {
              if (index == rootNotes.length) {
                // Add Stream card at the end
                return _buildAddStreamCard();
              }
              final notebook = rootNotes[index];
              return _buildStreamCard(notebook);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStreamCard(Note notebook) {
    final pageCount = notebook.childrenIds.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOpenNotebook(notebook),
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: 165.0,
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: AppColors.borderSubtle, width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: const Icon(
                      Icons.folder_open_outlined,
                      size: 16.0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (pageCount > 0)
                    Text(
                      '$pageCount ${pageCount == 1 ? 'page' : 'pages'}',
                      style: AppTypography.uiLabel(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 10.0),
              Text(
                notebook.title.isNotEmpty ? notebook.title : 'Untitled Stream',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddStreamCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCreateNotebook,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: 130.0,
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 24.0,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 8.0),
              Text(
                'New Stream',
                textAlign: TextAlign.center,
                style: AppTypography.uiLabel(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
