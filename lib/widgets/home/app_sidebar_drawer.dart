import 'package:flutter/material.dart';
import '../../app/di/repository_scope.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../controllers/theme_controller.dart';
import '../../models/note.dart';
import '../../repositories/offline_first_note_repository.dart';
import '../brand/tigris_logo.dart';

class AppSidebarDrawer extends StatefulWidget {
  final List<Note> streams;
  final List<Note> notes;
  final ValueChanged<Note> onOpenNote;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenReview;

  const AppSidebarDrawer({
    super.key,
    required this.streams,
    required this.notes,
    required this.onOpenNote,
    required this.onOpenSettings,
    required this.onOpenReview,
  });

  @override
  State<AppSidebarDrawer> createState() => _AppSidebarDrawerState();
}

class _AppSidebarDrawerState extends State<AppSidebarDrawer> {
  bool _streamsExpanded = true;
  bool _notesExpanded = true;

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
            // Top Bar: Branding & Close Button
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 16.0, right: 16.0, bottom: 16.0),
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

            // Scrollable Content
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  // --- 1. STREAMS SECTION (Notes with subpages) ---
                  _buildSectionHeader(
                    title: 'STREAMS',
                    count: widget.streams.length,
                    isExpanded: _streamsExpanded,
                    onToggle: () {
                      setState(() {
                        _streamsExpanded = !_streamsExpanded;
                      });
                    },
                    textSecondary: textSecondary,
                    badgeBg: context.isDarkMode ? Colors.white10 : context.appBg,
                  ),
                  const SizedBox(height: 8.0),

                  if (_streamsExpanded) ...[
                    if (widget.streams.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                        child: Text(
                          'No streams yet. Add subpages to a note to create a stream.',
                          style: AppTypography.subtitle(
                            fontSize: 13.0,
                            color: textTertiary,
                          ),
                        ),
                      )
                    else
                      ...widget.streams.map((streamNote) {
                        final childCount = streamNote.childrenIds.length;
                        return _buildNoteItem(
                          context,
                          note: streamNote,
                          icon: Icons.folder_open_rounded,
                          iconColor: context.isDarkMode ? const Color(0xFFFFC107) : context.appTextPrimary,
                          trailingText: '$childCount',
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onOpenNote(streamNote);
                          },
                        );
                      }),
                  ],

                  const SizedBox(height: 20.0),
                  Divider(color: borderCol, height: 1.0),
                  const SizedBox(height: 20.0),

                  // --- 2. NOTES SECTION (Standalone notes without subpages) ---
                  _buildSectionHeader(
                    title: 'NOTES',
                    count: widget.notes.length,
                    isExpanded: _notesExpanded,
                    onToggle: () {
                      setState(() {
                        _notesExpanded = !_notesExpanded;
                      });
                    },
                    textSecondary: textSecondary,
                    badgeBg: context.isDarkMode ? Colors.white10 : context.appBg,
                  ),
                  const SizedBox(height: 8.0),

                  if (_notesExpanded) ...[
                    if (widget.notes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                        child: Text(
                          'No standalone notes yet.',
                          style: AppTypography.subtitle(
                            fontSize: 13.0,
                            color: textTertiary,
                          ),
                        ),
                      )
                    else
                      ...widget.notes.map((note) {
                        return _buildNoteItem(
                          context,
                          note: note,
                          icon: Icons.description_outlined,
                          iconColor: textSecondary,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onOpenNote(note);
                          },
                        );
                      }),
                  ],

                  const SizedBox(height: 20.0),
                  Divider(color: borderCol, height: 1.0),
                  const SizedBox(height: 20.0),

                  // --- 3. NAVIGATION & ACTIONS SECTION ---
                  Text(
                    'NAVIGATION',
                    style: AppTypography.uiLabel(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10.0),

                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                      widget.onOpenReview();
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                  const SizedBox(height: 20.0),
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
                      widget.onOpenSettings();
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

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Color textSecondary,
    required Color badgeBg,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
              size: 20.0,
              color: textSecondary,
            ),
            const SizedBox(width: 6.0),
            Text(
              title,
              style: AppTypography.uiLabel(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ).copyWith(letterSpacing: 0.8),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Text(
                '$count',
                style: AppTypography.uiLabel(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(
    BuildContext context, {
    required Note note,
    required IconData icon,
    required Color iconColor,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    final titleText = note.title.trim().isNotEmpty ? note.title.trim() : 'Untitled';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18.0,
                  color: iconColor,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.uiHeadline(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                if (trailingText != null) ...[
                  const SizedBox(width: 6.0),
                  Text(
                    trailingText,
                    style: AppTypography.uiLabel(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.appTextTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
