import 'package:flutter/material.dart';
import '../../app/di/repository_scope.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../controllers/theme_controller.dart';
import '../../models/note.dart';
import '../../repositories/offline_first_note_repository.dart';
import '../brand/tigris_logo.dart';

class AppSidebarDrawer extends StatelessWidget {
  final List<Note> streams;
  final ValueChanged<Note> onOpenNote;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenReview;

  const AppSidebarDrawer({
    super.key,
    required this.streams,
    required this.onOpenNote,
    required this.onOpenSettings,
    required this.onOpenReview,
  });

  @override
  Widget build(BuildContext context) {
    final drawerBg = context.appSurface;
    final textPrimary = context.appTextPrimary;
    final textSecondary = context.appTextSecondary;
    final textTertiary = context.appTextTertiary;
    final borderCol = context.appBorderSubtle;

    return Drawer(
      backgroundColor: drawerBg,
      elevation: 8.0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(24.0),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Tigris Logo Branding & Close Button
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 16.0, right: 16.0, bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TigrisLogo(
                    size: 26.0,
                    showWordmark: true,
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20.0, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  // --- STREAMS SECTION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Streams',
                        style: AppTypography.uiLabel(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ).copyWith(letterSpacing: 0.8),
                      ),
                      if (streams.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: context.isDarkMode ? Colors.white10 : context.appBg,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            '${streams.length}',
                            style: AppTypography.uiLabel(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  if (streams.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                      child: Text(
                        'No nested streams yet. Add subpages to a note to create a stream.',
                        style: AppTypography.subtitle(
                          fontSize: 13.0,
                          color: textTertiary,
                        ),
                      ),
                    ),
                  ] else ...[
                    ...streams.map((streamNote) {
                      final childCount = streamNote.childrenIds.length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop(); // Close drawer
                              onOpenNote(streamNote);
                            },
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder_open_rounded,
                                    size: 20.0,
                                    color: context.isDarkMode ? const Color(0xFFFFC107) : context.appTextPrimary,
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Text(
                                      streamNote.title.isNotEmpty ? streamNote.title : 'Untitled Stream',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.uiHeadline(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w500,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    '$childCount',
                                    style: AppTypography.uiLabel(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                      color: textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 28.0),
                  Divider(color: borderCol, height: 1.0),
                  const SizedBox(height: 24.0),

                  // --- NAVIGATION & ACTIONS SECTION ---
                  Text(
                    'Navigation',
                    style: AppTypography.uiLabel(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 12.0),

                  // Memory Review Link
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    leading: Icon(Icons.refresh_rounded, size: 20.0, color: textPrimary),
                    title: Text(
                      'Memory Review',
                      style: AppTypography.uiHeadline(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpenReview();
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    leading: Icon(Icons.sync_rounded, size: 20.0, color: textPrimary),
                    title: Text(
                      'Sync Notes',
                      style: AppTypography.uiHeadline(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final repo = RepositoryScope.maybeOf(context)?.noteRepository;
                      if (repo is OfflineFirstNoteRepository) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Syncing notes across devices...')),
                        );
                        await repo.syncWithCloud();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notes synced successfully!')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),

            Divider(color: borderCol, height: 1.0),

            // Bottom Footer Row (Settings & Theme Toggle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpenSettings();
                    },
                    borderRadius: BorderRadius.circular(10.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 20.0, color: textPrimary),
                          const SizedBox(width: 8.0),
                          Text(
                            'Settings',
                            style: AppTypography.uiHeadline(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      context.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 20.0,
                      color: textPrimary,
                    ),
                    onPressed: () {
                      final themeController = ThemeControllerScope.maybeOf(context);
                      themeController?.toggleDarkMode();
                    },
                    tooltip: context.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
